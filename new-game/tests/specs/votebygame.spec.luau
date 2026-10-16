-- The vote by game (Config.Voting.ByMode): stand on the Ready pad and the choices come up on
-- the screen, one card per game that fits the ready players (two lines of up to
-- Config.Voting.MaxPerRow), then the difficulty; the map is one of the winner's playlists.
-- Players not on the pad only see the hint. And a whole vote on the real server.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local MODES = { "KingHunt", "HideSeek", "ScareMaze", "PropHunt", "ObbyRace", "TileFall" }

local function client()
	local rt = Runtime.new({ client = true })
	local remotes = rt:create("Folder", { Name = "Remotes" }, rt:find("ReplicatedStorage"))
	for _, name in { "CastVote", "VoteUpdate" } do
		rt:create("RemoteEvent", { Name = name }, remotes)
	end
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	Dom.rawSet(gui, "AbsoluteSize", rt.env.Vector2.new(1280, 760))
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	rt:require(Client.VoteUI).Mount(gui)
	return { rt = rt, gui = gui, player = player, remotes = remotes, Config = Config }
end

local function state(Config: any, count: number)
	local maps = {}
	for i = 1, count do
		local id = MODES[i]
		table.insert(maps, { Id = id, Name = Config.Modes.List[id].Name, Votes = 0, Mode = id })
	end
	return {
		Open = true,
		ReadyOnly = true,
		Pads = false,
		Maps = maps,
		Difficulties = {
			{ Id = "Easy", Name = "Easy", Votes = 0 },
			{ Id = "Hard", Name = "Hard", Votes = 0 },
		},
	}
end

describe("The vote panel by game", function()
	it("shows only the hint until you stand on the Ready pad, then every game", function()
		local c = client()
		c.player:SetAttribute("Ready", false)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(c.Config, 6))
		c.rt:advance(1)
		local panel = c.gui.Vote
		expect(panel.Visible).toBe(true)
		expect(panel.Hint.Visible).toBe(true)
		local cardRow = panel:FindFirstChild("Card_KingHunt", true).Parent
		expect(cardRow.Visible).toBe(false)
		-- On the pad: the choices come up.
		c.player:SetAttribute("Ready", true)
		c.rt:advance(1)
		expect(panel.Hint.Visible).toBe(false)
		expect(cardRow.Visible).toBe(true)
		-- Six games: two lines of three, each card inside the row.
		local lines = {}
		for _, id in MODES do
			local card = panel:FindFirstChild("Card_" .. id, true)
			expect(card).toBeTruthy()
			lines[card.Position.Y.Scale] = (lines[card.Position.Y.Scale] or 0) + 1
			expect(card.Position.X.Scale + card.Size.X.Scale).toBeLessThanOrEqual(1.0001)
			expect(card.Position.Y.Scale + card.Size.Y.Scale).toBeLessThanOrEqual(1.0001)
		end
		expect(lines[0]).toBe(c.Config.Voting.MaxPerRow)
		expect(lines[0.5]).toBe(6 - c.Config.Voting.MaxPerRow)
		-- Tapping a game votes for it; Easy / Hard sit underneath.
		c.rt:fire(panel:FindFirstChild("Card_ObbyRace", true), "Activated")
		c.rt:fire(panel:FindFirstChild("Card_Hard", true), "Activated")
		local sent = {}
		for _, call in c.rt:calls("RemoteEvent", "FireServer") do
			if call.instance.Name == "CastVote" then
				table.insert(sent, call.args[1] .. ":" .. call.args[2])
			end
		end
		expect(table.concat(sent, ",")).toBe("Map:ObbyRace,Difficulty:Hard")
		expect(#c.rt.errors).toBe(0)
	end)

	it("greys out a game that needs more players: no vote, and it says why", function()
		local c = client()
		c.player:SetAttribute("Ready", true)
		local s = state(c.Config, 6)
		s.Maps[4].Needs = 2 -- Prop Hunt
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", s)
		c.rt:advance(1)
		local card = c.gui.Vote:FindFirstChild("Card_PropHunt", true)
		expect(card.Text).toBe(
			c.Config.Modes.List.PropHunt.Name .. "\n" .. c.Config.Voting.Text.NeedsPlayers:format(2)
		)
		expect(card.Active).toBe(false)
		c.rt:fire(card, "Activated")
		for _, call in c.rt:calls("RemoteEvent", "FireServer") do
			expect(call.instance.Name).never.toBe("CastVote")
		end
		-- A second player steps on the pad: it unlocks.
		local open = state(c.Config, 6)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", open)
		c.rt:advance(0.5)
		expect(card.Text).toBe(c.Config.Modes.List.PropHunt.Name .. "\n0 votes")
		expect(card.Active).toBe(true)
	end)

	it("centres a shorter last line", function()
		local c = client()
		c.player:SetAttribute("Ready", true)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(c.Config, 4))
		c.rt:advance(1)
		local last = c.gui.Vote:FindFirstChild("Card_PropHunt", true)
		expect(last.Position.Y.Scale).toBe(0.5)
		-- One card on a line of three: it starts a third of the way in.
		expect(math.abs(last.Position.X.Scale - 1 / 3) < 0.001).toBe(true)
	end)
end)

describe("A vote by game on the real server", function()
	local server = Runtime.new()
	local Config = server:require("ReplicatedStorage.Shared.Config")
	local RS = server.game:GetService("ReplicatedStorage")
	local Vector3 = server.env.Vector3

	it("offers every game that fits, plays the winner on one of its maps and difficulty", function()
		expect(Config.Voting.ByMode).toBe(true)
		local ok, err = server:runScript("ServerScriptService.Server.Main")
		if not ok then
			error(err, 0)
		end
		server:advance(1)
		local solo = server:addPlayer({ Name = "Solo" })
		server:advance(2)
		local CS = server.game:GetService("CollectionService")
		local pad
		for _, p in CS:GetTagged("ReadyPad") do
			if not CS:HasTag(p, "VotePad") then
				pad = p
			end
		end
		solo.Character:PivotTo(pad.CFrame + Vector3.new(0, 3.5, 0))
		local captured
		local remote = server:find("ReplicatedStorage.Remotes.VoteUpdate")
		local waited = 0
		while RS:GetAttribute("State") ~= "Voting" and waited < 20 do
			server:advance(0.5)
			waited += 0.5
		end
		expect(RS:GetAttribute("State")).toBe("Voting")
		server:advance(1)
		for _, call in server:calls("RemoteEvent", "FireAllClients") do
			if call.instance == remote and call.args[1].Open then
				captured = call.args[1]
			end
		end
		-- One card per game in Config.Modes.Order, every one of them: the ones a single player
		-- can't play (Prop Hunt, Hide & Seek, ScareMaze need 2) are locked, "Needs 2 players".
		local ids, locked = {}, {}
		for _, option in captured.Maps do
			table.insert(ids, option.Id)
			if option.Needs then
				expect(option.Needs).toBe(2)
				table.insert(locked, option.Id)
			end
		end
		expect(table.concat(ids, ",")).toBe(table.concat(Config.Modes.Order, ","))
		expect(table.concat(locked, ",")).toBe("HideSeek,ScareMaze,PropHunt")
		-- A vote for a locked game doesn't count.
		server:fireServer(
			server:find("ReplicatedStorage.Remotes.CastVote"),
			solo,
			"Map",
			"PropHunt"
		)
		server:advance(1.2)
		expect(#captured.Difficulties).toBe(#Config.Difficulty.Order)
		local cast = server:find("ReplicatedStorage.Remotes.CastVote")
		server:fireServer(cast, solo, "Map", "TileFall")
		server:advance(1)
		server:fireServer(cast, solo, "Difficulty", "Hard")
		waited = 0
		while RS:GetAttribute("State") == "Voting" and waited < Config.Voting.Seconds + 5 do
			server:advance(0.5)
			waited += 0.5
		end
		expect(RS:GetAttribute("Mode")).toBe("TileFall")
		expect(RS:GetAttribute("MapName")).toBe("Crumbling Crypt")
		expect(RS:GetAttribute("Difficulty")).toBe(Config.Difficulty.Levels.Hard.Name)
	end)
end)
