-- The Tormented Tower in the game (the course maths is in tower.spec): the built, hollow tower
-- and its tagged pieces, a custom ClockTower model, the exclusive skin, TowerService (start,
-- checkpoints in order, falls, slime, anti-teleport, the minimum time, the skin given once,
-- the server-wide announcement, F8 buttons, vanishing platforms) and TowerUI.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("The tower in the lobby (Sections/TowerParkour)", function()
	local rt = Runtime.new()
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local Logic = rt:require("ReplicatedStorage.Shared.TowerLogic")
	local C = rt:require("ReplicatedStorage.Shared.Config")
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local Section = rt:require("ServerScriptService.Server.Hub.Sections.TowerParkour")
	local CollectionService = rt.game:GetService("CollectionService")
	local course = C.TowerParkour.Course

	local function count(kind: string): number
		local n = 0
		for _, step in course do
			if step.Kind == kind then
				n += 1
			end
		end
		return n
	end

	it("builds a hollow clock tower with every piece inside, tagged", function()
		local hub = HubBuilder.Build()
		local area = hub:FindFirstChild("TowerParkour")
		expect(area).toBeTruthy()
		for i, step in course do
			local m = area.Course:FindFirstChild(("Step%02d_%s"):format(i, step.Kind))
			if not m then
				error("no piece " .. i)
			end
			expect(m.PrimaryPart).toBeTruthy()
		end
		expect(#CollectionService:GetTagged(Tags.TowerStart)).toBe(1)
		expect(#CollectionService:GetTagged(Tags.TowerFinish)).toBe(1)
		expect(#CollectionService:GetTagged(Tags.TowerVanish)).toBe(count("Vanish"))
		expect(#CollectionService:GetTagged(Tags.TowerSpinner)).toBe(count("Spinner"))
		expect(#CollectionService:GetTagged(Tags.TowerGear)).toBe(count("Gear"))
		expect(#CollectionService:GetTagged(Tags.TowerHazard)).toBe(count("Hazard"))
		local indexes = {}
		for _, pad in CollectionService:GetTagged(Tags.TowerCheckpoint) do
			indexes[pad:GetAttribute("Index")] = true
		end
		expect(indexes[1] and indexes[2] and indexes[3]).toBe(true)
		-- Spinning bars and cogs turn on a motor.
		for _, tag in { Tags.TowerSpinner, Tags.TowerGear } do
			for _, part in CollectionService:GetTagged(tag) do
				expect(part.Anchored).toBe(false)
				local motor = part:FindFirstChild("Motor")
				expect(motor).toBeTruthy()
				expect(motor.ActuatorType).toBe(rt.env.Enum.ActuatorType.Motor)
			end
		end
		-- Hollow: walls, no solid block floors, and nothing solid in the way inside.
		local tower = hub.Decor:FindFirstChild("ClockTower")
		expect(tower:FindFirstChild("TowerFloor1")).toBeNil()
		expect(tower:FindFirstChild("TowerFloor1Back")).toBeTruthy()
		-- Even after the solid lobby pass (HubSolid), nothing of the built tower is in the way.
		rt:require("ServerScriptService.Server.Hub.HubSolid").Apply(hub)
		expect(Section.Fit(hub)).toBe(0)
		-- The glowing sign at the door, and the lanterns inside.
		expect(hub:FindFirstChild("TowerParkourFloorSign", true)).toBeTruthy()
		expect(#area.Lanterns:GetChildren()).toBe(#C.TowerParkour.Walls.Lights.Heights)
		-- The start pad is on the tower's inside floor.
		local start = CollectionService:GetTagged(Tags.TowerStart)[1]
		local floor1 = Logic.Floors()[1].CFrame
		expect(start.Position.Y + start.Size.Y / 2).toBeNear(
			floor1.Position.Y + course[1].Offset.Y,
			0.05
		)
		hub:Destroy()
	end)

	it("keeps working with your own ClockTower model (even a solid one)", function()
		local custom =
			rt:create("Model", { Name = "ClockTower" }, rt:find("ReplicatedStorage.Custom.Props"))
		rt:create("Part", {
			Name = "Block",
			Size = rt.env.Vector3.new(22, 80, 22),
			CFrame = rt.env.CFrame.new(0, 40, 0),
			Anchored = true,
		}, custom)
		local hub = HubBuilder.Build()
		local tower
		for _, d in hub:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") == "ClockTower" then
				tower = d
			end
		end
		expect(tower:GetAttribute("CustomProp")).toBe(true)
		expect(Section.Fit(hub)).toBeGreaterThan(0) -- the solid block stops being solid
		expect(tower.Block.CanCollide).toBe(false)
		expect(hub.TowerParkour:FindFirstChild("Shell")).toBeTruthy() -- inner walls instead
		expect(#CollectionService:GetTagged(Tags.TowerStart)).toBe(1)
		custom:Destroy()
		hub:Destroy()
	end)

	it("builds nothing when the feature is off", function()
		local hub = rt:create("Model", { Name = "Hub2" })
		C.Features.TowerParkour = false
		local ok, area = pcall(Section.Build, hub, nil)
		C.Features.TowerParkour = true
		expect(ok).toBe(true)
		expect(#area:GetChildren()).toBe(0)
	end)
end)

describe("The Tormented Soul skin", function()
	local rt = Runtime.new()
	local C = rt:require("ReplicatedStorage.Shared.Config")
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
	local skin = Items.Get(C.TowerParkour.Reward.SkinId)

	it("is a CRAZY skin with its own effect, never sold and in no crate", function()
		expect(skin).toBeTruthy()
		expect(skin.Slot).toBe("Skin")
		expect(Items.Rarity(skin)).toBe("Crazy")
		expect(skin.Exclusive).toBe("TowerParkour")
		expect(Items.Price(skin)).toBeNil()
		expect(Items.CanBuyDirect(skin)).toBe(false)
		expect(skin.Crate).toBeNil()
		for _, crate in C.Crates.List do
			for _, item in Items.ByCrate(crate.Id) do
				expect(item.Id).never.toBe(skin.Id)
			end
		end
		expect(skin.Style.Crazy.Effect).toBe("Torment")
	end)

	it("previews and goes on a character", function()
		local model = Cosmetics.Preview(skin)
		expect(model.PrimaryPart).toBeTruthy()
		expect(model:FindFirstChild("Cosmetic_Skin")).toBeTruthy()
		model:Destroy()
	end)
end)

-- A server with the hub, saves, the shop, announcements and the tower running.
local function server()
	local rt = Runtime.new({ studio = true })
	local services = "ServerScriptService.Server.Services."
	for _, name in
		{
			"HubService",
			"DataService",
			"ShopService",
			"AdminService",
			"AnnounceService",
			"TowerService",
		}
	do
		rt:require(services .. name).Start()
	end
	return rt
end

describe("TowerService", function()
	local rt = server()
	local C = rt:require("ReplicatedStorage.Shared.Config")
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local ParkourL = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local Tower = rt:require("ServerScriptService.Server.Services.TowerService")
	local DataService = rt:require("ServerScriptService.Server.Services.DataService")
	local CollectionService = rt.game:GetService("CollectionService")
	local ReplicatedStorage = rt.game:GetService("ReplicatedStorage")
	local Vector3, CFrame = rt.env.Vector3, rt.env.CFrame
	local tcfg = C.TowerParkour
	local pcfg = C.Parkour
	local player = rt:addPlayer({ Name = "Brave" })
	player.Character.Humanoid.HipHeight = 2
	rt:advance(1)

	local function first(tag: string): any
		return CollectionService:GetTagged(tag)[1]
	end
	local function checkpoint(index: number): any
		for _, pad in CollectionService:GetTagged(Tags.TowerCheckpoint) do
			if pad:GetAttribute("Index") == index then
				return pad
			end
		end
		return nil
	end
	local function spotOn(part: any): any
		local top = ParkourL.TopY(part.CFrame, part.Size)
		return Vector3.new(part.Position.X, top + 3, part.Position.Z)
	end
	local function root(): any
		return player.Character.HumanoidRootPart
	end
	-- Moves the character to `target` a little per check, like climbing (never faster up than a
	-- person can climb).
	local function travel(target: any)
		local from = root().Position
		local d = target - from
		local flat = Vector3.new(d.X, 0, d.Z).Magnitude
		local steps = math.max(1, math.ceil(flat / 2.5), math.ceil(math.abs(d.Y) / 1.2))
		for s = 1, steps do
			player.Character:PivotTo(CFrame.new(from:Lerp(target, s / steps)))
			rt:advance(pcfg.CheckSeconds)
		end
		rt:advance(pcfg.CheckSeconds * 2)
	end
	local function events(kind: string): { any }
		local list = {}
		for _, call in rt:calls("RemoteEvent", "FireClient") do
			if
				call.instance.Name == "TowerEvent"
				and call.args[1] == player
				and call.args[2] == kind
			then
				table.insert(list, call.args[3])
			end
		end
		return list
	end
	local function announcements(): { any }
		local list = {}
		for _, call in rt:calls("RemoteEvent", "FireAllClients") do
			if call.instance.Name == "Announce" then
				table.insert(list, call.args[1])
			end
		end
		return list
	end
	-- The piece right after the start pad.
	local function firstPiece(): any
		for _, m in rt.workspace.Hub.TowerParkour.Course:GetChildren() do
			if m.Name:match("^Step02_") then
				return m.PrimaryPart
			end
		end
		return nil
	end

	it("makes its remotes and gets you ready on the start pad", function()
		expect(rt:find("ReplicatedStorage.Remotes.TowerEvent")).toBeTruthy()
		expect(rt:find("ReplicatedStorage.Remotes.TowerRequest")).toBeTruthy()
		player.Character:PivotTo(CFrame.new(spotOn(first(Tags.TowerStart))))
		rt:advance(0.3)
		expect(player:GetAttribute("TowerRun")).toBe("Ready")
		expect(ReplicatedStorage:GetAttribute("TowerCheckpoints")).toBe(3)
		travel(spotOn(firstPiece()))
		expect(player:GetAttribute("TowerRun")).toBe("Running")
		expect(#events("Start")).toBe(1)
	end)

	it(
		"only counts checkpoints in order and sends you back when you fall or touch slime",
		function()
			-- Straight up first, then across high above checkpoint 1, so only checkpoint 2 is
			-- touched.
			local high = spotOn(checkpoint(2)).Y
			travel(Vector3.new(root().Position.X, high, root().Position.Z))
			travel(spotOn(checkpoint(2)))
			expect(player:GetAttribute("TowerReached")).toBe(0)
			expect(#events("Missed")).toBe(1)
			travel(spotOn(checkpoint(1)))
			expect(player:GetAttribute("TowerReached")).toBe(1)
			-- Fall well below checkpoint 1: back on it.
			rt:advance(pcfg.TeleportGraceSeconds)
			local pad = checkpoint(1)
			player.Character:PivotTo(
				CFrame.new(spotOn(pad) - Vector3.new(0, pcfg.FallBelowCheckpoint + 2, 0))
			)
			rt:advance(0.3)
			local back = events("Back")
			expect(back[#back].Reason).toBe("Fall")
			expect((root().Position - spotOn(pad)).Magnitude).toBeLessThan(1)
			-- Slime: back too.
			rt:advance(pcfg.TeleportGraceSeconds)
			-- A slime patch higher up than checkpoint 1 (lower down would be a fall).
			local slime
			for _, s in CollectionService:GetTagged(Tags.TowerHazard) do
				if
					s.Position.Y > pad.Position.Y and (not slime or s.Position.Y < slime.Position.Y)
				then
					slime = s
				end
			end
			local inSlime = slime.Position + Vector3.new(0, 3, 0)
			travel(Vector3.new(root().Position.X, inSlime.Y + 2, root().Position.Z))
			travel(inSlime + Vector3.new(0, 2, 0) + slime.CFrame.RightVector * 3) -- beside it
			player.Character:PivotTo(CFrame.new(inSlime)) -- one step into the slime
			rt:advance(0.3)
			back = events("Back")
			expect(back[#back].Reason).toBe("Hazard")
			expect(player:GetAttribute("TowerReached")).toBe(1)
		end
	)

	it("stops a run that teleports", function()
		rt:advance(pcfg.TeleportGraceSeconds)
		player.Character:PivotTo(CFrame.new(root().Position + Vector3.new(0, 30, 0)))
		rt:advance(0.3)
		local cancels = events("Cancel")
		expect(cancels[#cancels].Reason).toBe("TooFast")
		expect(player:GetAttribute("TowerRun")).toBe("")
	end)

	local function climb()
		travel(spotOn(first(Tags.TowerStart)))
		travel(spotOn(firstPiece()))
		rt:advance(tcfg.MinSeconds)
		for index = 1, 3 do
			travel(spotOn(checkpoint(index)))
		end
		travel(spotOn(first(Tags.TowerFinish)))
	end

	it("gives the skin once, tells the whole server, and saves the best time", function()
		local data = DataService.Get(player)
		expect(data.Owned[tcfg.Reward.SkinId]).toBeFalsy()
		climb()
		local finishes = events("Finish")
		expect(#finishes).toBe(1)
		expect(finishes[1].Skin).toBe(tcfg.Skin.Name)
		expect(data.Owned[tcfg.Reward.SkinId]).toBe(true)
		expect(data.TowerParkour.Conquered).toBe(true)
		expect(data.TowerParkour.Runs).toBe(1)
		expect(data.TowerParkour.Best).toBe(finishes[1].Time)
		expect(player:GetAttribute("TowerConquered")).toBe(true)
		expect(player:GetAttribute("TowerBest")).toBe(finishes[1].Time)
		local said = announcements()
		expect(#said).toBe(1)
		expect(said[1].Text).toBe(tcfg.Text.Announce:format(player.DisplayName))
		-- Again: a finish and an announcement, but no second skin.
		climb()
		finishes = events("Finish")
		expect(#finishes).toBe(2)
		expect(finishes[2].Skin).toBeNil()
		expect(data.TowerParkour.Runs).toBe(2)
		expect(#announcements()).toBe(2)
	end)

	it("doesn't count a finish that is too fast", function()
		local before = #events("Finish")
		travel(spotOn(first(Tags.TowerStart)))
		travel(spotOn(firstPiece()))
		for index = 1, 3 do
			travel(spotOn(checkpoint(index)))
		end
		travel(spotOn(first(Tags.TowerFinish)))
		local cancels = events("Cancel")
		expect(cancels[#cancels].Reason).toBe("Cheat")
		expect(#events("Finish")).toBe(before)
	end)

	it("has F8 buttons: each checkpoint, reset my progress, the start", function()
		local admin = rt:find("ReplicatedStorage.Remotes.AdminCommand")
		rt:invokeServer(admin, player, "TowerCheckpoint2")
		expect(player:GetAttribute("TowerRun")).toBe("Running")
		expect(player:GetAttribute("TowerReached")).toBe(2)
		expect((root().Position - spotOn(checkpoint(2))).Magnitude).toBeLessThan(1)
		rt:advance(0.5) -- (the admin panel's throttle)
		rt:invokeServer(admin, player, "TowerReset")
		local data = DataService.Get(player)
		expect(data.Owned[tcfg.Reward.SkinId]).toBeFalsy()
		expect(data.TowerParkour.Conquered).toBe(false)
		expect(player:GetAttribute("TowerConquered")).toBe(false)
		rt:advance(0.5)
		rt:invokeServer(admin, player, "TowerToStart")
		expect((root().Position - spotOn(first(Tags.TowerStart))).Magnitude).toBeLessThan(1)
	end)

	it("makes vanishing platforms vanish on their timer", function()
		local v = tcfg.Vanish
		local part = first(Tags.TowerVanish)
		local phase = part:GetAttribute("Phase")
		Tower.UpdateVanish(-phase + 0.1)
		expect(part.CanCollide).toBe(true)
		Tower.UpdateVanish(-phase + v.Visible - v.Warn / 2)
		expect(part.CanCollide).toBe(true)
		expect(part.Color).toBe(tcfg.Look.Colors.VanishWarn)
		Tower.UpdateVanish(-phase + v.Visible + v.Gone / 2)
		expect(part.CanCollide).toBe(false)
		expect(part.Transparency).toBe(1)
	end)
end)

describe("TowerUI", function()
	local srv = server()
	local client = Runtime.new({ client = true })
	client:replicateFrom(srv)
	local C = client:require("ReplicatedStorage.Shared.Config")
	local text = C.TowerParkour.Text
	local Client = client:find("StarterPlayer.StarterPlayerScripts.Client")
	local player = client.game:GetService("Players").LocalPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
	client:require(Client.Layout).Mount(gui)
	client:require(Client.PanelManager).Mount(gui)
	client:require(Client.MenuUI).Mount(gui)
	client:require(Client.MenuTiles).Mount(gui)
	client:require(Client.TowerUI).Mount(gui)
	client:advance(0.5)

	it("has a Menu tile that opens the tower panel", function()
		local tile
		for _, child in gui.Menu.Tiles:GetChildren() do
			if child:GetAttribute("MenuTile") == "TowerParkour" then
				tile = child
			end
		end
		expect(tile).toBeTruthy()
		client:fire(tile, "Activated")
		expect(gui.TowerPanel.Visible).toBe(true)
		expect(gui.TowerPanel.Best.Text).toBe(text.NoBest)
		expect(gui.TowerPanel.Reward.Text).toBe(text.RewardReady)
		player:SetAttribute("TowerConquered", true)
		client:advance(0.1)
		expect(gui.TowerPanel.Reward.Text).toBe(text.RewardWait)
	end)

	it("shows the timer and the skin you won", function()
		player:SetAttribute("TowerRun", "Ready")
		client:advance(0.1)
		expect(gui.TowerTimer.Visible).toBe(true)
		expect(gui.TowerTimer.Time.Text).toBe(text.Ready)
		local event = client:find("ReplicatedStorage.Remotes.TowerEvent")
		client:fire(
			event,
			"OnClientEvent",
			"Finish",
			{ Time = 300, Best = 300, NewBest = true, Skin = "Tormented Soul" }
		)
		expect(gui.TowerFinish.Visible).toBe(true)
		expect(gui.TowerFinish.Title.Text).toBe(text.Finished)
		expect(gui.TowerFinish.Coins.Text).toBe(text.SkinWon:format("Tormented Soul"))
	end)
end)
