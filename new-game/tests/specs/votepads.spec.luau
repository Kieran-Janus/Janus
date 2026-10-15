-- The vote pads (Config.VotePads, Features.VotePads): the lobby section that builds them, the
-- pad vote on the real server (game, then difficulty, by standing on pads; games that need more
-- players; the on-screen vote buttons ignored) and the floating signs' words on the client.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("The vote pads section", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local CS = rt.game:GetService("CollectionService")

	it("builds one pad per slot in a row, each a Ready pad too, inside its zone", function()
		local hub = HubBuilder.Build()
		local folder = hub:FindFirstChild("VotePads")
		expect(folder).toBeInstanceOf("Folder")
		local pads = CS:GetTagged("VotePad")
		expect(#pads).toBe(Config.VotePads.Pads)
		local bySlot = {}
		for _, pad in pads do
			expect(pad:IsDescendantOf(folder)).toBe(true)
			expect(CS:HasTag(pad, "ReadyPad")).toBe(true)
			expect(pad.Parent:IsA("Model")).toBe(true) -- one Model per pad (Studio selects it whole)
			expect(pad.Parent:FindFirstChild("Rim")).toBeTruthy()
			expect(Lobby.InZone(pad.Position, "VotePads")).toBe(true)
			bySlot[pad:GetAttribute("VoteSlot")] = pad
		end
		-- Slot 1 on the left as you look from the Ready circle towards the middle of the lobby.
		local zone = Lobby.ZoneCFrame("VotePads")
		for slot = 2, Config.VotePads.Pads do
			local a, b = bySlot[slot - 1], bySlot[slot]
			expect(zone:PointToObjectSpace(b.Position).X).toBeGreaterThan(
				zone:PointToObjectSpace(a.Position).X
			)
			-- Never overlapping, and close enough that the row reads as one.
			local apart = (b.Position - a.Position).Magnitude
			expect(apart).toBeGreaterThanOrEqual(Config.VotePads.PadSize)
			expect(apart).toBeLessThanOrEqual(Config.VotePads.PadSize + Config.VotePads.Gap + 0.01)
		end
		-- The Ready circle is still there, apart from the pads.
		local circles = 0
		for _, pad in CS:GetTagged("ReadyPad") do
			if not CS:HasTag(pad, "VotePad") then
				circles += 1
			end
		end
		expect(circles).toBe(1)
		hub:Destroy()
	end)

	it("builds no pads while switched off", function()
		Config.Features.VotePads = false
		local hub = HubBuilder.Build()
		Config.Features.VotePads = true
		expect(#CS:GetTagged("VotePad")).toBe(0)
		expect(hub:FindFirstChild("VotePads")).toBeTruthy() -- (an empty folder)
		hub:Destroy()
	end)

	it("has its settings and a look for every game", function()
		local cfg = Config.VotePads
		for _, key in { "ModeSeconds", "DifficultySeconds", "Pads", "PadSize", "Gap", "PadHeight" } do
			expect(cfg[key]).toBeA("number")
			expect(cfg[key]).toBeGreaterThan(0)
		end
		expect(cfg.Pads).toBeGreaterThanOrEqual(#Config.Modes.Order)
		for _, id in Config.Modes.Order do
			expect(cfg.Looks[id]).toBeTruthy()
		end
		for _, id in Config.Difficulty.Order do
			expect(cfg.Looks[id]).toBeTruthy()
			expect(#cfg.DifficultySlots[id]).toBeGreaterThan(0)
		end
		for _, key in { "Votes", "NeedsPlayers", "ModeHint", "DifficultyHint", "YourVote", "Board" } do
			expect(cfg.Text[key]).toBeA("string")
		end
	end)
end)

describe("Voting on the pads (the real server)", function()
	local server = Runtime.new()
	local Config = server:require("ReplicatedStorage.Shared.Config")
	local RS = server.game:GetService("ReplicatedStorage")
	local CS = server.game:GetService("CollectionService")
	local Vector3 = server.env.Vector3
	local players = {}

	local function pad(slot: number): any
		for _, p in CS:GetTagged("VotePad") do
			if p:GetAttribute("VoteSlot") == slot then
				return p
			end
		end
		error("no vote pad " .. slot)
	end
	local function stand(player: any, slot: number)
		local p = pad(slot)
		player.Character:PivotTo(server.env.CFrame.new(p.Position + Vector3.new(0, p.Size.X / 2 + 3, 0)))
	end
	local function slotOf(mode: string): number
		for i, id in Config.Modes.Order do
			if id == mode then
				return i
			end
		end
		error(mode)
	end
	local function waitFor(check: () -> boolean, seconds: number): boolean
		local waited = 0
		while not check() and waited < seconds do
			server:advance(0.25)
			waited += 0.25
		end
		return check()
	end

	it("shows every game on its pad before the vote", function()
		local ok, err = server:runScript("ServerScriptService.Server.Main")
		if not ok then
			error(err, 0)
		end
		server:advance(1)
		for i, id in Config.Modes.Order do
			local p = pad(i)
			expect(p:GetAttribute("VoteOption")).toBe(id)
			expect(p:GetAttribute("VoteName")).toBe(Config.Modes.List[id].Name)
			expect(p:GetAttribute("VotePhase")).toBe("")
		end
	end)

	it("counts who stands where, and a game needing more players gets no votes", function()
		local solo = server:addPlayer({ Name = "Solo" })
		table.insert(players, solo)
		server:advance(2)
		-- One player on the Hide & Seek pad (it needs 2): ready, but no vote counts.
		stand(solo, slotOf("HideSeek"))
		expect(waitFor(function()
			return pad(1):GetAttribute("VotePhase") == "Mode"
		end, 10)).toBe(true)
		server:advance(1)
		local hideSeek = pad(slotOf("HideSeek"))
		expect(solo:GetAttribute("Ready")).toBe(true)
		expect(hideSeek:GetAttribute("VoteNeeds")).toBe(2)
		expect(hideSeek:GetAttribute("VoteVotes")).toBe(0)
		expect(pad(slotOf("KingHunt")):GetAttribute("VoteNeeds")).toBe(0)
		-- On the King Hunt pad it counts.
		stand(solo, slotOf("KingHunt"))
		server:advance(1)
		expect(pad(slotOf("KingHunt")):GetAttribute("VoteVotes")).toBe(1)
		-- The vote buttons on the screen do nothing while the pads decide.
		server:fireServer(server:find("ReplicatedStorage.Remotes.CastVote"), solo, "Map", "ScareMaze")
		server:advance(0.5)
		expect(pad(slotOf("ScareMaze")):GetAttribute("VoteVotes")).toBe(0)
	end)

	it("then asks EASY or HARD on the same pads, and plays the winner", function()
		local solo = players[1]
		-- King Hunt wins (the only vote); it has difficulty, so the pads turn into EASY / HARD.
		expect(waitFor(function()
			return pad(1):GetAttribute("VotePhase") == "Difficulty"
		end, Config.VotePads.ModeSeconds + 5)).toBe(true)
		expect(RS:GetAttribute("VoteMode")).toBe(Config.Modes.List.KingHunt.Name)
		local hardSlot = Config.VotePads.DifficultySlots.Hard[1]
		local easySlot = Config.VotePads.DifficultySlots.Easy[1]
		expect(pad(hardSlot):GetAttribute("VoteOption")).toBe("Hard")
		expect(pad(easySlot):GetAttribute("VoteOption")).toBe("Easy")
		stand(solo, hardSlot)
		server:advance(1)
		expect(pad(hardSlot):GetAttribute("VoteVotes")).toBe(1)
		expect(waitFor(function()
			return RS:GetAttribute("State") == "Intermission" or RS:GetAttribute("State") == "Playing"
		end, Config.VotePads.DifficultySeconds + 5)).toBe(true)
		expect(RS:GetAttribute("Mode")).toBe("KingHunt")
		expect(RS:GetAttribute("Difficulty")).toBe(Config.Difficulty.Levels.Hard.Name)
		expect(RS:GetAttribute("VoteMode")).toBeNil()
		-- The pads show their games again.
		expect(pad(1):GetAttribute("VotePhase")).toBe("")
		expect(pad(1):GetAttribute("VoteOption")).toBe(Config.Modes.Order[1])
	end)
end)

describe("The vote pads' signs (client)", function()
	local rt = Runtime.new({ client = true })
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local RS = rt.game:GetService("ReplicatedStorage")
	local VotePadsUI = rt:require(rt:find("StarterPlayer.StarterPlayerScripts.Client.VotePadsUI"))

	it("says what each pad offers, how many stand on it and who can't play yet", function()
		local part = rt:create("Part", { Name = "Pad" }, rt.workspace)
		part:SetAttribute("VoteName", "King Hunt")
		part:SetAttribute("VoteIcon", "K")
		part:SetAttribute("VoteVotes", 3)
		part:SetAttribute("VotePhase", "Mode")
		part:SetAttribute("VoteNeeds", 0)
		local icon, title, count, note = VotePadsUI.Words(part, true)
		expect(icon).toBe("K")
		expect(title).toBe("King Hunt")
		expect(count).toBe(Config.VotePads.Text.Votes:format(3))
		expect(note).toBe(Config.VotePads.Text.YourVote)
		part:SetAttribute("VoteNeeds", 2)
		local _, _, _, needs = VotePadsUI.Words(part, true)
		expect(needs).toBe(Config.VotePads.Text.NeedsPlayers:format(2))
		-- Between votes: the game's name, no count.
		part:SetAttribute("VotePhase", "")
		local _, _, idleCount = VotePadsUI.Words(part, false)
		expect(idleCount).toBe("")
	end)

	it("tells you what to do during the vote, and nothing otherwise", function()
		RS:SetAttribute("State", "Waiting for players")
		expect(VotePadsUI.Hint()).toBe("")
		RS:SetAttribute("State", "Voting")
		RS:SetAttribute("TimeLeft", 12)
		expect(VotePadsUI.Hint()).toBe(Config.VotePads.Text.ModeHint:format(12))
		RS:SetAttribute("VoteMode", "King Hunt")
		expect(VotePadsUI.Hint()).toBe(Config.VotePads.Text.DifficultyHint:format("King Hunt", 12))
	end)

	it("knows when you stand on a pad", function()
		local Vector3 = rt.env.Vector3
		local part = rt:create("Part", {
			Name = "Round",
			Shape = rt.env.Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 7, 7),
			Position = Vector3.new(0, 0.25, 0),
		}, rt.workspace)
		expect(VotePadsUI.StandingOn(part, Vector3.new(2, 3, 2))).toBe(true)
		expect(VotePadsUI.StandingOn(part, Vector3.new(5, 3, 0))).toBe(false)
		expect(VotePadsUI.StandingOn(part, Vector3.new(0, 30, 0))).toBe(false)
	end)
end)
