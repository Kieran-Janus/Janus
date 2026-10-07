-- Round motion (VoteUI, RoundJuiceUI, ResultsUI): the extra animation never gets in the way.
-- Votes are sent the moment a card is tapped (even while the cards pop in), counts end on the
-- exact numbers, the winner pops once the server has picked it, the 3-2-1 and "GO!" show for
-- players about to play, "+1" arcs up, results rows all appear with the exact coins, your row
-- is highlighted and gets the "You got X coins!" moment, the panels still close on time, and
-- with the Animate switches off everything shows at once. Then a whole round's worth of
-- updates with all three mounted, without errors.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local REMOTE_EVENTS = { "CastVote", "VoteUpdate", "RoundResults", "SpectateFocus" }

local function client(width: number?, height: number?)
	local rt = Runtime.new({ client = true })
	local remotes = rt:create("Folder", { Name = "Remotes" }, rt:find("ReplicatedStorage"))
	for _, name in REMOTE_EVENTS do
		rt:create("RemoteEvent", { Name = name }, remotes)
	end
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	Dom.rawSet(gui, "AbsoluteSize", rt.env.Vector2.new(width or 1280, height or 760))
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	return {
		rt = rt,
		gui = gui,
		player = player,
		remotes = remotes,
		Client = Client,
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		storage = rt:find("ReplicatedStorage"),
	}
end

local function voteState(open: boolean, a: number, b: number, c: number)
	return {
		Open = open,
		ReadyOnly = false,
		Maps = {
			{ Id = "KingHuntPatch", Name = "King Hunt: Patch", Votes = a, Mode = "KingHunt" },
			{ Id = "HideSeekFarm", Name = "Hide & Seek: Farm", Votes = b, Mode = "HideSeek" },
			{ Id = "ScareMaze", Name = "ScareMaze", Votes = c, Mode = "ScareMaze" },
		},
		Difficulties = {
			{ Id = "Easy", Name = "Easy", Votes = 0 },
			{ Id = "Hard", Name = "Hard", Votes = 0 },
		},
	}
end

local function rows(me: number)
	local list = {}
	for i = 1, 6 do
		table.insert(list, {
			UserId = if i == 4 then me else 1000 + i,
			Name = "Player" .. i,
			Score = 20 - i,
			Pumpkins = 20 - i,
			Coins = 13 * i + 7,
			Survived = i % 2 == 0,
			Top = i == 1,
		})
	end
	return list
end

local function card(c, id: string)
	return c.gui.Vote:FindFirstChild("Card_" .. id, true)
end

local function votesSent(c): { { any } }
	local sent = {}
	for _, call in c.rt:calls("RemoteEvent", "FireServer") do
		if call.instance.Name == "CastVote" then
			table.insert(sent, { call.args[1], call.args[2] })
		end
	end
	return sent
end

describe("Vote panel motion", function()
	it("sends a vote the moment a card is tapped, even while the cards pop in", function()
		local c = client()
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 0, 0))
		local hide = card(c, "HideSeekFarm")
		expect(hide).toBeTruthy()
		expect(hide.UIScale.Scale).toBe(0) -- still popping in
		c.rt:fire(hide, "Activated")
		expect(votesSent(c)).toEqual({ { "Map", "HideSeekFarm" } }) -- no waiting
		c.rt:advance(1)
		expect(hide.UIScale.Scale).toBe(1)
		expect(hide.UIStroke.Transparency).toBe(0) -- the highlight
		expect(card(c, "ScareMaze").UIStroke.Transparency).toBe(1)
		expect(hide.BackgroundColor3).toEqual(c.rt:require(c.Client.Theme).Selected)
		-- A second tap on another card goes out at once too.
		c.rt:fire(card(c, "ScareMaze"), "Activated")
		expect(#votesSent(c)).toBe(2)
	end)

	it("steps counts to the exact numbers on the same cards", function()
		local c = client()
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 1, 0))
		c.rt:advance(1)
		local king = card(c, "KingHuntPatch")
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 9, 1, 0))
		c.rt:advance(2)
		expect(card(c, "KingHuntPatch")).toBe(king) -- updated in place, not rebuilt
		expect(king.Text).toBe("King Hunt: Patch\n9 votes")
		expect(card(c, "HideSeekFarm").Text).toBe("Hide & Seek: Farm\n1 vote")
		expect(king.UIScale.Scale).toBe(1) -- the pulse settles
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 4, 1, 0))
		c.rt:advance(2)
		expect(king.Text).toBe("King Hunt: Patch\n4 votes")
	end)

	it("shows the seconds left quietly beside the heading", function()
		local c = client()
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.storage:SetAttribute("State", "Voting")
		c.storage:SetAttribute("TimeLeft", 12)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 0, 0))
		local timer = c.gui.Vote:FindFirstChild("Timer", true)
		expect(timer.Text).toBe("12s")
		c.storage:SetAttribute("TimeLeft", 11)
		expect(timer.Text).toBe("11s")
		expect(timer.TextSize).toBeGreaterThanOrEqual(c.Config.UI.MinTextSize)
	end)

	it("pops the winner once the server has picked it, then closes", function()
		local c = client()
		local motion = c.Config.Voting.Motion
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.storage:SetAttribute("State", "Voting")
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 1, 3, 0))
		c.rt:advance(1)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(false, 1, 3, 0))
		expect(c.gui.Vote.Visible).toBe(true) -- waiting for the server's pick
		-- Taps after the vote closed send nothing.
		c.rt:fire(card(c, "KingHuntPatch"), "Activated")
		expect(#votesSent(c)).toBe(0)
		c.storage:SetAttribute("Mode", "HideSeek")
		c.storage:SetAttribute("State", "Intermission")
		local winner = card(c, "HideSeekFarm")
		expect(winner.BackgroundColor3).toEqual(motion.WinnerColor)
		expect(card(c, "KingHuntPatch").BackgroundTransparency).toBeGreaterThan(0)
		c.rt:advance(motion.WinnerSeconds + 0.1)
		expect(c.gui.Vote.Visible).toBe(false)
		-- The next vote pops fresh cards in.
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 0, 0))
		expect(c.gui.Vote.Visible).toBe(true)
		expect(card(c, "HideSeekFarm").BackgroundTransparency).toBe(0)
		expect(card(c, "KingHuntPatch").TextTransparency).toBe(0)
	end)

	it("closes without a winner when it can't tell (a cancelled vote)", function()
		local c = client()
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 2, 2, 0))
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(false, 2, 2, 0))
		c.storage:SetAttribute("State", "Waiting for players")
		c.rt:advance(c.Config.Voting.Motion.WinnerWaitSeconds + 0.1)
		expect(c.gui.Vote.Visible).toBe(false)
	end)

	it("is instant with Config.Voting.Animate off", function()
		local c = client()
		c.Config.Voting.Animate = false
		c.rt:require(c.Client.VoteUI).Mount(c.gui)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 0, 0))
		local king = card(c, "KingHuntPatch")
		expect(king.UIScale.Scale).toBe(1)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 5, 0, 0))
		expect(king.Text).toBe("King Hunt: Patch\n5 votes") -- no stepping
		c.rt:fire(king, "Activated")
		expect(#votesSent(c)).toBe(1)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(false, 5, 0, 0))
		expect(c.gui.Vote.Visible).toBe(false) -- closes right away
	end)
end)

describe("Round moments (RoundJuiceUI)", function()
	it("pops 3-2-1 for a ready player, then GO! when the round starts", function()
		local c = client()
		c.rt:require(c.Client.RoundJuiceUI).Mount(c.gui)
		c.storage:SetAttribute("ReadyPads", 1)
		c.player:SetAttribute("Ready", true)
		c.storage:SetAttribute("State", "Intermission")
		c.storage:SetAttribute("TimeLeft", 5)
		local count = c.gui.JuiceCountdown
		expect(count.Visible).toBe(false) -- only the last 3 seconds
		for n = 3, 1, -1 do
			c.storage:SetAttribute("TimeLeft", n)
			expect(count.Visible).toBe(true)
			expect(count.Text).toBe(tostring(n))
			expect(count.UIScale.Scale).toBe(c.Config.Juice.Countdown.PopScale)
			c.rt:advance(1)
			expect(count.Visible).toBe(false) -- shrank away before the next one
		end
		c.player:SetAttribute("InRound", true)
		c.storage:SetAttribute("State", "Playing")
		c.storage:SetAttribute("TimeLeft", 300)
		local banner = c.gui.JuiceBanner
		expect(banner.Visible).toBe(true)
		expect(banner.Text).toBe(c.Config.Juice.Start.Text)
		expect(banner.Rotation).never.toBe(0) -- punched in with a wobble
		c.rt:advance(0.6)
		expect(banner.Rotation).toBe(0)
		expect(banner.UIScale.Scale).toBe(1)
		c.rt:advance(c.Config.Juice.Start.Seconds + 0.5)
		expect(banner.Visible).toBe(false)
	end)

	it("shows no countdown to someone who isn't playing", function()
		local c = client()
		c.rt:require(c.Client.RoundJuiceUI).Mount(c.gui)
		c.storage:SetAttribute("ReadyPads", 1)
		c.player:SetAttribute("Ready", false)
		c.storage:SetAttribute("State", "Intermission")
		c.storage:SetAttribute("TimeLeft", 3)
		expect(c.gui.JuiceCountdown.Visible).toBe(false)
	end)

	it("arcs the +1 up and cleans it up", function()
		local c = client()
		c.rt:require(c.Client.RoundJuiceUI).Mount(c.gui)
		c.player:SetAttribute("Pumpkins", 0)
		c.player:SetAttribute("Pumpkins", 1)
		local pop = c.gui:FindFirstChild("PickupPop")
		expect(pop).toBeTruthy()
		local label = pop:FindFirstChildOfClass("TextLabel")
		expect(label.Text).toBe("+1")
		local scale = label:FindFirstChildOfClass("UIScale")
		expect(scale.Scale).toBeLessThan(1) -- pops out small...
		c.rt:advance(c.Config.Juice.Motion.PickupPopSeconds + 0.01)
		expect(scale.Scale).toBe(1) -- ...to full size, readable
		c.rt:advance(c.Config.Juice.Pickup.Seconds)
		expect(c.gui:FindFirstChild("PickupPop")).toBeNil()
	end)

	it("shows the same messages still with Config.Juice.Animate off", function()
		local c = client()
		c.Config.Juice.Animate = false
		c.rt:require(c.Client.RoundJuiceUI).Mount(c.gui)
		c.storage:SetAttribute("State", "Intermission")
		c.storage:SetAttribute("TimeLeft", 3)
		expect(c.gui.JuiceCountdown.Visible).toBe(true)
		expect(c.gui.JuiceCountdown.UIScale.Scale).toBe(1)
		c.player:SetAttribute("InRound", true)
		c.storage:SetAttribute("State", "Playing")
		expect(c.gui.JuiceBanner.Visible).toBe(true)
		expect(c.gui.JuiceBanner.Rotation).toBe(0)
		expect(c.gui.JuiceBanner.UIScale.Scale).toBe(1)
		expect(c.gui.JuiceCountdown.Visible).toBe(false)
	end)
end)

describe("Results motion", function()
	local function coinsOf(row): string
		for _, child in row:GetChildren() do
			if child:IsA("TextLabel") and string.sub(child.Text, 1, 1) == "+" then
				return child.Text
			end
		end
		return ""
	end

	it("shows every row with the exact coins, highlights yours and pops your coins", function()
		local c = client()
		local cfg = c.Config.Results
		c.rt:require(c.Client.ResultsUI).Mount(c.gui)
		c.storage:SetAttribute("State", "Results")
		c.storage:SetAttribute("TimeLeft", 10)
		local data = rows(c.player.UserId)
		c.rt:fire(c.remotes.RoundResults, "OnClientEvent", data, {})
		local panel = c.gui.Results
		expect(panel.Visible).toBe(true)
		local list = panel.Rows
		c.rt:advance(0.05)
		-- The rows come one after another.
		local shown = 0
		for _, row in list:GetChildren() do
			if row:IsA("Frame") and row.Visible then
				shown += 1
			end
		end
		expect(shown).toBeLessThan(#data)
		local done = cfg.PopSeconds
			+ #data * cfg.RowDelay
			+ cfg.CountUpDelay
			+ cfg.CountUpSeconds
			+ cfg.CoinPulseSeconds
			+ 0.3
		c.rt:advance(done)
		local frames = {}
		for _, row in list:GetChildren() do
			if row:IsA("Frame") then
				expect(row.Visible).toBe(true)
				table.insert(frames, row)
			end
		end
		expect(#frames).toBe(#data)
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i, row in frames do
			expect(coinsOf(row)).toBe("+" .. data[i].Coins)
			expect(row.UIScale.Scale).toBe(1)
		end
		local mine = list.MyRow
		expect(mine.BackgroundTransparency).toBeLessThan(1)
		expect(frames[1].BackgroundTransparency).toBeLessThan(1) -- the top player too
		expect(mine:FindFirstChild("Shine")).toBeNil() -- the sweep ran and cleaned up
		local pill = panel.NextRound:FindFirstChild("YouGot")
		expect(pill).toBeTruthy()
		expect(pill.Text).toBe(cfg.Text.YouGot:format(data[4].Coins))
		expect(pill.TextSize).toBeGreaterThanOrEqual(c.Config.UI.MinTextSize)
		-- Still closes on time.
		c.rt:advance(c.Config.Round.ResultsSeconds - done + 0.1)
		expect(panel.Visible).toBe(false)
	end)

	it("sweeps a shine across the top row and yours while they appear", function()
		local c = client()
		c.rt:require(c.Client.ResultsUI).Mount(c.gui)
		c.rt:fire(c.remotes.RoundResults, "OnClientEvent", rows(c.player.UserId), {})
		c.rt:advance(0.6)
		local list = c.gui.Results.Rows
		local shines = 0
		for _, row in list:GetChildren() do
			if row:IsA("Frame") and row:FindFirstChild("Shine") then
				shines += 1
			end
		end
		expect(shines).toBe(2)
	end)

	it("shows everything at once with Config.Results.Animate off", function()
		local c = client()
		c.Config.Results.Animate = false
		c.rt:require(c.Client.ResultsUI).Mount(c.gui)
		local data = rows(c.player.UserId)
		c.rt:fire(c.remotes.RoundResults, "OnClientEvent", data, {})
		local panel = c.gui.Results
		for _, row in panel.Rows:GetChildren() do
			if row:IsA("Frame") then
				expect(row.Visible).toBe(true)
			end
		end
		expect(coinsOf(panel.Rows.MyRow)).toBe("+" .. data[4].Coins)
		local position = panel.Position
		c.rt:advance(1)
		expect(panel.Position).toEqual(position) -- no slide
		c.rt:advance(c.Config.Round.ResultsSeconds)
		expect(panel.Visible).toBe(false)
	end)
end)

describe("A whole round with all three mounted", function()
	it("runs vote -> countdown -> play -> results without errors", function()
		local c = client(640, 302)
		c.gui:SetAttribute("ForceTouch", true)
		for _, name in { "VoteUI", "RoundJuiceUI", "ResultsUI" } do
			c.rt:require(c.Client[name]).Mount(c.gui)
		end
		local s = c.storage
		c.player:SetAttribute("Ready", true)
		s:SetAttribute("ReadyPads", 1)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 0, 0, 0))
		for left = 20, 1, -1 do
			s:SetAttribute("State", "Voting")
			s:SetAttribute("TimeLeft", left)
			if left == 15 then
				c.rt:fire(card(c, "KingHuntPatch"), "Activated")
				c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(true, 1, 0, 0))
			end
			c.rt:advance(1)
		end
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", voteState(false, 1, 0, 0))
		s:SetAttribute("Mode", "KingHunt")
		for left = 5, 1, -1 do
			s:SetAttribute("State", "Intermission")
			s:SetAttribute("TimeLeft", left)
			c.rt:advance(1)
		end
		expect(c.gui.Vote.Visible).toBe(false)
		c.player:SetAttribute("InRound", true)
		for left = 40, 1, -1 do
			s:SetAttribute("State", "Playing")
			s:SetAttribute("TimeLeft", left)
			if left % 7 == 0 then
				c.player:SetAttribute("Pumpkins", (c.player:GetAttribute("Pumpkins") or 0) + 1)
			end
			if left == 30 then
				s:SetAttribute("KingCount", 1)
			end
			c.rt:advance(1)
		end
		c.player:SetAttribute("InRound", false)
		c.rt:fire(c.remotes.RoundResults, "OnClientEvent", rows(c.player.UserId), {})
		for left = 10, 1, -1 do
			s:SetAttribute("State", "Results")
			s:SetAttribute("TimeLeft", left)
			c.rt:advance(1)
		end
		s:SetAttribute("State", "Waiting for players")
		c.rt:advance(2)
		expect(c.gui.Results.Visible).toBe(false)
		expect(c.gui.JuiceBanner.Visible).toBe(false)
		expect(c.gui:FindFirstChild("PickupPop")).toBeNil()
		expect(#votesSent(c)).toBe(1)
		expect(#c.rt.errors).toBe(0)
	end)
end)
