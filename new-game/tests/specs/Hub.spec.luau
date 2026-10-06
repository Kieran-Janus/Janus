-- The lobby: HubBuilder builds every section, tag and readable group; decorations stay out of
-- the zones; HubService keeps/rebuilds/repairs saved hubs; the custom shopkeeper checks; prop
-- overrides; palette sync; Bake; the Ready sign text.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

-- A fresh fake game with the lobby modules loaded (each HubService test starts clean).
local function world()
	local rt = Runtime.new()
	local w = {
		rt = rt,
		Vector3 = rt.env.Vector3,
		CFrame = rt.env.CFrame,
		Color3 = rt.env.Color3,
		CollectionService = rt.game:GetService("CollectionService"),
		ServerStorage = rt.game:GetService("ServerStorage"),
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		Tags = rt:require("ReplicatedStorage.Shared.Tags"),
		Lobby = rt:require("ReplicatedStorage.Shared.Lobby"),
		Kit = rt:require("ServerScriptService.Server.Build.Kit"),
		HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder"),
		HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout"),
		HubPalette = rt:require("ServerScriptService.Server.Hub.HubPalette"),
		Npcs = rt:require("ServerScriptService.Server.Hub.Npcs"),
		HubService = rt:require("ServerScriptService.Server.Services.HubService"),
		MapService = rt:require("ServerScriptService.Server.Services.MapService"),
		Bake = rt:require("ServerScriptService.Server.Tools.Bake"),
	}
	-- Everything under `root` with `tag`.
	function w.tagged(tag: string, root: any): { any }
		local list = {}
		for _, instance in w.CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(root) then
				table.insert(list, instance)
			end
		end
		return list
	end
	function w.hub(): any
		return rt.workspace:FindFirstChild("Hub")
	end
	function w.clear()
		for _, child in rt.workspace:GetChildren() do
			if not child:IsA("Terrain") and not child:IsA("Camera") then
				child:Destroy()
			end
		end
	end
	-- A shop prompt (NpcId of an NPC that opens the shop) under one of the ShopKeeper parts.
	function w.shopPrompt(hub: any): any
		for _, keeper in w.tagged(w.Tags.ShopKeeper, hub) do
			local list = keeper:GetDescendants()
			table.insert(list, keeper)
			for _, d in list do
				if d:IsA("ProximityPrompt") and d:GetAttribute("NpcId") == "PumpkinVendor" then
					return d
				end
			end
		end
		return nil
	end
	-- Puts `model` into ReplicatedStorage.Custom.<category>; returns a function that takes it out.
	function w.custom(category: string, model: any): () -> ()
		local folder = rt:find("ReplicatedStorage.Custom." .. category)
		model.Parent = folder
		return function()
			model:Destroy()
		end
	end
	return w
end

local function colorNear(a: any, b: any): boolean
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

describe("HubBuilder", function()
	local w = world()
	local Config, Tags, Lobby = w.Config, w.Tags, w.Lobby

	it("builds every section, tag and readable group", function()
		local hub = w.HubBuilder.Build()
		expect(hub.Parent).toBe(w.rt.workspace)
		expect(hub.Name).toBe("Hub")
		expect(hub:GetAttribute("BuildVersion")).toBe(Config.Hub.BuildVersion)
		expect(hub:GetAttribute("Locked")).toBeNil() -- a built hub is not locked
		for _, name in
			{
				"Plaza",
				"Spawn",
				"ReadyArea",
				"Shop",
				"Parkour",
				"CandyRush",
				"WebScour",
				"EasterEggs",
				"Npcs",
				"Decor",
			}
		do
			if not hub:FindFirstChild(name) then
				error("no Hub." .. name)
			end
		end
		for _, name in
			{
				"ClockTower",
				"Cauldron",
				"Lamps",
				"Bunting",
				"JackOLanterns",
				"Candles",
				"Graveyard",
				"Trees",
				"Ambience",
				"Forest",
				"HauntedMansion",
				"KingStatue",
				"PumpkinPatch",
				"OldGraves",
				"Fence",
				"Paths",
			}
		do
			if not hub.Decor:FindFirstChild(name) then
				error("no Hub.Decor." .. name)
			end
		end
		local spawns = w.tagged(Tags.HubSpawn, hub)
		expect(#spawns).toBe(1)
		expect(spawns[1]).toBeInstanceOf("SpawnLocation")
		local pads = w.tagged(Tags.ReadyPad, hub)
		expect(#pads).toBe(1)
		expect(pads[1]).toBeInstanceOf("BasePart")
		expect(Lobby.InZone(pads[1].Position, "ReadyArea")).toBe(true)
		-- Lies flat: a square pad's Y axis points up, a round pad (a Cylinder) stands on its X axis.
		local padUp = if pads[1].Shape.Name == "Cylinder"
			then pads[1].CFrame.RightVector
			else pads[1].CFrame.UpVector
		expect(math.abs(padUp.Y)).toBeNear(1, 1e-4)
		local signs = w.tagged(Tags.ReadySign, hub)
		expect(#signs).toBe(1)
		expect(signs[1]:FindFirstChild("Title", true)).toBeInstanceOf("TextLabel")
		expect(signs[1]:FindFirstChild("Status", true)).toBeInstanceOf("TextLabel")
		expect(w.shopPrompt(hub)).toBeInstanceOf("ProximityPrompt")
		local vendor = hub.Shop:FindFirstChild("PumpkinVendor") -- in the Shop section
		expect(vendor).toBeInstanceOf("Model")
		expect(vendor:HasTag(Tags.ShopKeeper)).toBe(true)
		expect(Lobby.InZone(vendor.KeeperSpot.Position, "Shop")).toBe(true)
		expect(vendor:FindFirstChild("Keeper")).toBeInstanceOf("Model")
		expect(vendor:FindFirstChild("Stall")).toBeInstanceOf("Model")
		-- The name floats above the awning.
		expect(vendor.TagAnchor.Position.Y).toBeGreaterThan(
			vendor.Stall.AwningStripe.Position.Y + 1
		)
		expect(w.Npcs.Find(hub, "VotingBoard")).toBeInstanceOf("Model")
		expect(hub.Npcs:FindFirstChild("VotingBoard")).toBeInstanceOf("Model")
		for _, d in hub:GetDescendants() do
			if d.Name == "WitchWanda" or d.Name == "BooGuide" then
				error("retired NPC in the hub: " .. d:GetFullName())
			end
		end
	end)

	it("keeps decorations out of the lobby zones", function()
		local hub = w.HubBuilder.Build()
		local checked = 0
		for _, d in hub.Decor:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") then
				local name = d:GetAttribute("PropName")
				if name == "Cobweb" then
					continue -- hung on a lamp, tree or tower that was already checked
				end
				if w.HubLayout.Blocked(d:GetPivot().Position, 0) then
					error(name .. " is inside a zone: " .. d:GetFullName())
				end
				checked += 1
			elseif d:IsA("BasePart") and d.Name == "PathStone" then
				if w.HubLayout.Blocked(d.Position, 0) then
					error("a path stone is inside a zone")
				end
			end
		end
		expect(checked).toBeGreaterThan(50)
		local lamps = 0
		for _, child in hub.Decor.Lamps:GetChildren() do
			if child:GetAttribute("PropName") == "Lamppost" then
				lamps += 1
			end
		end
		-- The lamp in the Parkour zone was left out; most lamps are there.
		expect(lamps).toBeLessThan(Config.Hub.Lampposts.Count)
		expect(lamps).toBeGreaterThan(Config.Hub.Lampposts.Count / 2)
	end)

	it("gives every PaletteRole part its palette colour", function()
		local hub = w.HubBuilder.Build()
		local roles = 0
		for _, d in hub:GetDescendants() do
			local role = d:GetAttribute("PaletteRole")
			if role == nil then
				continue
			end
			roles += 1
			if not Config.Hub.Palette[role] then
				error(("unknown PaletteRole %s on %s"):format(tostring(role), d:GetFullName()))
			end
			local expected =
				w.Kit.roleColor(Config.Hub.Palette, role, d:GetAttribute("PaletteShade"))
			if not colorNear(d.Color, expected) then
				error(d:GetFullName() .. " doesn't have its palette colour")
			end
		end
		expect(roles).toBeGreaterThan(200)
		expect(Config.Hub.Colors).toBe(Config.Hub.Palette) -- Colors is the old name
	end)

	it("repaints only the palette roles that changed", function()
		local hub = w.HubBuilder.Build()
		expect(w.HubPalette.Sync(hub)).toBe(0) -- nothing changed yet
		local stone = hub.ReadyArea.ReadyPad
		local handPainted = w.Color3.new(1, 0, 0)
		stone.Color = handPainted
		local wood = hub.Shop.PumpkinVendor.Stall.Counter
		local old = Config.Hub.Palette.Wood
		Config.Hub.Palette.Wood = w.Color3.fromRGB(10, 200, 10)
		local ok, err = pcall(function()
			expect(w.HubPalette.Sync(hub)).toBeGreaterThan(10) -- the wood parts
			expect(colorNear(wood.Color, Config.Hub.Palette.Wood)).toBe(true)
			expect(colorNear(stone.Color, handPainted)).toBe(true) -- hand-painted stone kept
			expect(w.HubPalette.Sync(hub)).toBe(0) -- a second sync changes nothing
		end)
		Config.Hub.Palette.Wood = old
		if not ok then
			error(err, 0)
		end
		expect(w.HubPalette.Repaint(hub)).toBeGreaterThan(0) -- Repaint brings everything back
		expect(colorNear(stone.Color, w.Kit.roleColor(Config.Hub.Palette, "Stone", 0.35))).toBe(
			true
		)
	end)

	it("builds a fallback hub with a spawn and a Ready pad", function()
		w.clear()
		local hub = w.HubBuilder.BuildFallback()
		expect(hub:GetAttribute("Fallback")).toBe(true)
		expect(hub:GetAttribute("BuildVersion")).toBeNil() -- the next start tries again
		expect(#w.tagged(Tags.HubSpawn, hub)).toBe(1)
		expect(#w.tagged(Tags.ReadyPad, hub)).toBe(1)
		w.HubService.EnsureRequired(hub)
		expect(w.shopPrompt(hub)).toBeInstanceOf("ProximityPrompt") -- EnsureRequired adds it
	end)
end)

describe("HubService", function()
	it("builds a hub when there is none, and the spawn is found by tag", function()
		local w = world()
		w.HubService.Start()
		local hub = w.hub()
		expect(hub).toBeInstanceOf("Folder")
		expect(hub:GetAttribute("BuildVersion")).toBe(w.Config.Hub.BuildVersion)
		local spawn = w.tagged(w.Tags.HubSpawn, hub)[1]
		expect(w.MapService.LobbyCFrame().Position).toBeNear(
			spawn.Position + w.Vector3.new(0, w.Config.Maps.SpawnHeight, 0),
			1e-3
		)
		expect(w.HubService.Screen("Leaderboard")).toBeTruthy()
		expect(w.HubService.Screen("VotingBoard")).toBeTruthy()
	end)

	it("rebuilds an old unlocked hub", function()
		local w = world()
		local old = w.rt:create("Model", { Name = "Hub" })
		old:SetAttribute("Marker", "old")
		old:SetAttribute("BuildVersion", 1)
		old.Parent = w.rt.workspace
		w.HubService.Start()
		local hub = w.hub()
		expect(hub:GetAttribute("Marker")).toBeNil()
		expect(hub:GetAttribute("BuildVersion")).toBe(w.Config.Hub.BuildVersion)
	end)

	it("keeps an old Locked hub and repairs it", function()
		local w = world()
		local Tags = w.Tags
		local locked = w.rt:create("Model", { Name = "Hub" })
		locked:SetAttribute("Locked", true)
		w.rt:create("Part", { Name = "Ground" }, locked)
		local oldSpawn =
			w.rt:create("SpawnLocation", { Name = "Spawn", CFrame = w.CFrame.new(5, 2, 5) }, locked)
		local npcs = w.rt:create("Folder", { Name = "Npcs" }, locked)
		for _, id in { "WitchWanda", "BooGuide" } do
			w.rt:create("Model", { Name = id }, npcs)
		end
		locked.Parent = w.rt.workspace
		w.HubService.Start()
		local hub = w.hub()
		expect(hub).toBe(locked)
		expect(hub:GetAttribute("Locked")).toBe(true)
		expect(hub:GetAttribute("BuildVersion")).toBeNil() -- not rebuilt
		expect(npcs:FindFirstChild("WitchWanda")).toBeNil()
		expect(npcs:FindFirstChild("BooGuide")).toBeNil()
		expect(oldSpawn:HasTag(Tags.HubSpawn)).toBe(true) -- tagged, not replaced
		expect(#w.tagged(Tags.HubSpawn, hub)).toBe(1)
		expect(#w.tagged(Tags.ReadyPad, hub)).toBe(1) -- the Ready pad was put back
		expect(w.shopPrompt(hub)).toBeInstanceOf("ProximityPrompt") -- and the shopkeeper
		expect(w.Lobby.InZone(w.tagged(Tags.ReadyPad, hub)[1].Position, "ReadyArea")).toBe(true)
	end)

	it("gives a Locked current hub its deleted pad, spawn and shop prompt back", function()
		local w = world()
		local Tags = w.Tags
		local hub = w.HubBuilder.Build()
		hub:SetAttribute("Locked", true)
		w.tagged(Tags.ReadyPad, hub)[1]:Destroy()
		w.tagged(Tags.HubSpawn, hub)[1]:Destroy()
		local vendor = hub.Shop.PumpkinVendor
		vendor.PromptAnchor:Destroy()
		w.HubService.Start()
		expect(w.hub():GetAttribute("Locked")).toBe(true)
		expect(#w.tagged(Tags.ReadyPad, hub)).toBe(1)
		expect(#w.tagged(Tags.ReadySign, hub)).toBe(1) -- the sign was still there: only one
		expect(#w.tagged(Tags.HubSpawn, hub)).toBe(1)
		expect(w.shopPrompt(hub)).toBeInstanceOf("ProximityPrompt")
		expect(vendor:FindFirstChild("PromptAnchor")).toBeInstanceOf("BasePart") -- same stall
		local vendors = 0
		for _, d in hub:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("NpcId") == "PumpkinVendor" then
				vendors += 1
			end
		end
		expect(vendors).toBe(1)
	end)

	it("makes any part tagged ShopKeeper a shop entrance", function()
		local w = world()
		local hub = w.rt:create("Model", { Name = "Hub" })
		hub:SetAttribute("Locked", true)
		local sign = w.rt:create("Part", { Name = "MyShopSign" }, hub)
		sign:AddTag(w.Tags.ShopKeeper)
		hub.Parent = w.rt.workspace
		w.HubService.EnsureRequired(hub)
		local prompt = sign:FindFirstChildWhichIsA("ProximityPrompt")
		expect(prompt).toBeInstanceOf("ProximityPrompt")
		expect(prompt:GetAttribute("NpcId")).toBe("PumpkinVendor")
		expect(w.Npcs.Find(hub, "PumpkinVendor")).toBeNil() -- no second shop was built
	end)
end)

describe("Custom models", function()
	-- A one-part model standing on the origin.
	local function block(w, size: any, transparency: number?): any
		local m = w.rt:create("Model", { Name = "PumpkinVendor" })
		w.rt:create("Part", {
			Name = "Body",
			Size = size,
			CFrame = w.CFrame.new(0, size.Y / 2, 0),
			Transparency = transparency or 0,
		}, m)
		return m
	end

	it("only uses a custom shopkeeper that passes the checks", function()
		local w = world()
		local Config, Vector3 = w.Config, w.Vector3
		local cases = {
			{
				Name = "too small (KeepSize)",
				Size = Vector3.new(1, 1, 1),
				Keep = true,
				Used = false,
			},
			{ Name = "invisible", Size = Vector3.new(2, 6, 2), Transparency = 1, Used = false },
			{ Name = "a good one", Size = Vector3.new(2, 6, 2), Used = true },
		}
		for _, case in cases do
			w.clear()
			local model = block(w, case.Size, case.Transparency)
			if case.Keep then
				model:SetAttribute("KeepSize", true)
			end
			local remove = w.custom("Characters", model)
			local hub = w.HubBuilder.Build()
			local vendor = w.Npcs.Find(hub, "PumpkinVendor")
			w.Npcs.ApplyCustom(hub)
			remove()
			local used = vendor:FindFirstChild("Look") ~= nil
			if used ~= case.Used then
				error(("%s: custom used = %s"):format(case.Name, tostring(used)))
			end
			expect(vendor:FindFirstChild("Keeper") ~= nil).toBe(not case.Used)
			if case.Used then
				local body = vendor.Look.Body
				local spot = vendor.KeeperSpot.Position
				expect(body.Position.Y - body.Size.Y / 2).toBeNear(spot.Y, 0.05) -- feet on the spot
				expect(body.Size.Y).toBeNear(Config.Custom.Heights.PumpkinVendor, 0.05)
				expect(vendor:FindFirstChild("TagAnchor")).toBeInstanceOf("BasePart")
			end
		end
	end)

	it("keeps the custom shopkeeper behind the counter when only the stall was moved", function()
		local w = world()
		local remove = w.custom("Characters", block(w, w.Vector3.new(2, 6, 2)))
		local hub = w.HubBuilder.Build()
		local vendor = w.Npcs.Find(hub, "PumpkinVendor")
		local stall = vendor.Stall
		stall:PivotTo(stall:GetPivot() * w.CFrame.new(6, 0, 0))
		w.Npcs.ApplyCustom(hub)
		remove()
		local behindCounter = stall:GetPivot() * w.CFrame.new(0, 0, 0.5)
		local body = vendor.Look.Body
		expect(body.Position.X).toBeNear(behindCounter.X, 0.05)
		expect(body.Position.Z).toBeNear(behindCounter.Z, 0.05)
	end)

	it("replaces every copy of a custom prop, at build time and in a saved hub", function()
		local w = world()
		local hub = w.HubBuilder.Build()
		local function count(customOnly: boolean): number
			local n = 0
			for _, d in hub:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("PropName") == "JackOLantern" then
					if not customOnly or d:GetAttribute("CustomProp") then
						n += 1
					end
				end
			end
			return n
		end
		local total = count(false)
		expect(total).toBeGreaterThan(20)
		local lantern = w.rt:create("Model", { Name = "JackOLantern" })
		w.rt:create("Part", { Name = "Ball", Size = w.Vector3.new(4, 4, 4) }, lantern)
		local remove = w.custom("Props", lantern)
		expect(w.Kit.applyCustomProps(hub)).toBe(total) -- every built one was swapped
		expect(count(true)).toBe(total)
		expect(w.Kit.applyCustomProps(hub)).toBe(0) -- running it again changes nothing
		hub = w.HubBuilder.Build()
		expect(count(true)).toBe(count(false)) -- a fresh build uses it straight away
		remove()
	end)
end)

describe("Bake", function()
	it("builds the hub and maps for hand editing", function()
		local w = world()
		local Bake, Config, ServerStorage = w.Bake, w.Config, w.ServerStorage
		local hub = Bake.Hub()
		expect(hub).toBeInstanceOf("Folder")
		expect(hub.Parent).toBe(w.rt.workspace)
		expect(hub:GetAttribute("BuildVersion")).toBe(Config.Hub.BuildVersion)
		Bake.Lock()
		expect(hub:GetAttribute("Locked")).toBe(true)
		expect(Bake.Hub()).toBeNil() -- a Locked hub is not replaced
		expect(Bake.Hub(true)).toBeInstanceOf("Folder") -- Hub(true) replaces it
		expect(ServerStorage:FindFirstChild("HubBackup")).toBeInstanceOf("Folder") -- old one kept
		expect(#Bake.Repair()).toBe(0) -- nothing to repair on a fresh hub
		expect(Bake.Repaint()).toBeGreaterThanOrEqual(0)

		local map = Bake.Map("PumpkinFarm")
		expect(map).toBeInstanceOf("Model")
		expect(map.Parent).toBe(ServerStorage.Maps)
		expect(map.WorldPivot.Position).toBeNear(Config.Maps.Origin, 1e-4) -- pivot at the origin
		expect(map:FindFirstChild("Floor")).toBeInstanceOf("BasePart")
		Bake.Map("PumpkinFarm")
		expect(ServerStorage.Maps:FindFirstChild("PumpkinFarm_Backup")).toBeInstanceOf("Model")
		expect(Bake.Map("NoSuchMap")).toBeNil()
	end)

	it("loads a baked map in the same place as the built one", function()
		local w = world()
		local built = w.MapService.Load("PumpkinPatch")
		local builtFloor = built.Floor.CFrame
		local builtSpawns = #built.Spawns
		w.MapService.Unload()
		w.Bake.Map("PumpkinPatch")
		local baked = w.MapService.Load("PumpkinPatch")
		expect(baked.Id).toBe("PumpkinPatch")
		expect(baked.Model:GetAttribute("BakedFrom")).toBeA("string") -- the ServerStorage copy
		expect(baked.Floor.CFrame).toBeNear(builtFloor, 1e-3)
		expect(#baked.Spawns).toBe(builtSpawns)
		w.MapService.Unload()
	end)
end)

describe("ReadySign", function()
	local client = Runtime.new({ client = true })
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local ReadySign = client:require("StarterPlayer.StarterPlayerScripts.Client.ReadySign")

	it("shows the count and the round state", function()
		local sign = Config.Hub.ReadyArea.Sign
		local title, status = ReadySign.Text(nil, nil, nil, false)
		expect(title).toBe(sign.TitleWaiting)
		expect(status).toBe(Config.Lobby.Ready.PadText)
		title, status = ReadySign.Text(1, 2, "Voting", false)
		expect(title).toBe("READY 1 / 2")
		expect(status).toBe(sign.States.Voting)
		title = ReadySign.Text(3, 2, "Playing", false)
		expect(title).toBe("READY 3") -- enough players: just the count
		local _, mine = ReadySign.Text(1, 2, "Voting", true)
		expect(mine).toBe(sign.YouAreReady)
		local _, other = ReadySign.Text(0, 1, "Some New State", false)
		expect(other).toBe("Some New State") -- unknown states are shown as they are
		-- Every state GameService sets has its own line.
		for _, state in { "Waiting for players", "Voting", "Intermission", "Playing", "Results" } do
			expect(sign.States[state]).toBeA("string")
		end
	end)
end)
