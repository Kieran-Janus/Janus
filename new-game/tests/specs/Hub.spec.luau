--!strict
-- The lobby: HubBuilder builds every section, tag and readable group; decorations stay out of
-- the zones; HubService keeps/rebuilds/repairs saved hubs; the custom shopkeeper checks; prop
-- overrides; palette sync; Bake; the Ready sign text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

return function(t: any)
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local Tags = require(ReplicatedStorage.Shared.Tags) :: any
	local Lobby = require(ReplicatedStorage.Shared.Lobby) :: any
	local Kit = require(t.Server.Build.Kit) :: any
	local HubBuilder = require(t.Server.Hub.HubBuilder) :: any
	local HubLayout = require(t.Server.Hub.HubLayout) :: any
	local HubPalette = require(t.Server.Hub.HubPalette) :: any
	local Npcs = require(t.Server.Hub.Npcs) :: any
	local HubService = require(t.Server.Services.HubService) :: any
	local MapService = require(t.Server.Services.MapService) :: any
	local Bake = require(t.Server.Tools.Bake) :: any
	local ReadySign = require(t.Client.ReadySign) :: any

	local function tagged(tag: string, root: any): { any }
		local list = {}
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(root) then
				table.insert(list, instance)
			end
		end
		return list
	end

	local function currentHub(): any
		return t.workspace:FindFirstChild("Hub")
	end

	local function clearWorkspace()
		for _, child in t.workspace:GetChildren() do
			if not child:IsA("Terrain") then
				child:Destroy()
			end
		end
	end

	-- A shop prompt (NpcId of an NPC that opens the shop) under one of the ShopKeeper parts.
	local function shopPromptIn(hub: any): any
		for _, keeper in tagged(Tags.ShopKeeper, hub) do
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

	local function colorNear(a: Color3, b: Color3): boolean
		return math.abs(a.R - b.R) < 0.01
			and math.abs(a.G - b.G) < 0.01
			and math.abs(a.B - b.B) < 0.01
	end

	t.test("the hub builds with every section, tag and readable group", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
		t.eq(hub.Parent, t.workspace)
		t.eq(hub.Name, "Hub")
		t.eq(hub:GetAttribute("BuildVersion"), Config.Hub.BuildVersion)
		t.eq(hub:GetAttribute("Locked"), nil, "a built hub is not locked")
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
			t.ok(hub:FindFirstChild(name), "Hub." .. name)
		end
		local decor = hub.Decor
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
			t.ok(decor:FindFirstChild(name), "Hub.Decor." .. name)
		end
		t.eq(#tagged(Tags.HubSpawn, hub), 1, "one HubSpawn")
		t.ok(tagged(Tags.HubSpawn, hub)[1]:IsA("SpawnLocation"), "the spawn is a SpawnLocation")
		local pads = tagged(Tags.ReadyPad, hub)
		t.eq(#pads, 1, "one ReadyPad")
		t.ok(pads[1]:IsA("BasePart"))
		t.ok(Lobby.InZone(pads[1].CFrame.Position, "ReadyArea"), "the pad is in its zone")
		t.near(pads[1].CFrame.UpVector, Vector3.yAxis, 1e-4, "the pad lies flat (Y up)")
		t.eq(#tagged(Tags.ReadySign, hub), 1, "one ReadySign")
		local sign = tagged(Tags.ReadySign, hub)[1]
		t.ok(sign:FindFirstChild("Title", true), "the sign has a Title label")
		t.ok(sign:FindFirstChild("Status", true), "the sign has a Status label")
		t.ok(shopPromptIn(hub), "a ShopKeeper with a working shop prompt")
		local vendor = hub.Shop:FindFirstChild("PumpkinVendor")
		t.ok(vendor, "the shopkeeper stands in the Shop section")
		t.ok(vendor:HasTag(Tags.ShopKeeper), "the vendor model is tagged ShopKeeper")
		t.ok(
			Lobby.InZone(vendor.KeeperSpot.CFrame.Position, "Shop"),
			"the keeper is in the Shop zone"
		)
		t.ok(vendor:FindFirstChild("Keeper"), "built keeper")
		t.ok(vendor:FindFirstChild("Stall"), "stall")
		local tag = vendor.TagAnchor
		t.ok(
			tag.CFrame.Y > vendor.Stall.AwningStripe.CFrame.Y + 1,
			"the name floats above the awning"
		)
		t.ok(Npcs.Find(hub, "VotingBoard"), "voting board")
		t.ok(hub.Npcs:FindFirstChild("VotingBoard"), "the voting board stays in Hub.Npcs")
		for _, d in hub:GetDescendants() do
			t.ok(d.Name ~= "WitchWanda" and d.Name ~= "BooGuide", "no retired NPC: " .. d.Name)
		end
	end)

	t.test("decorations stay out of the lobby zones", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
		local checked = 0
		for _, d in hub.Decor:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") then
				local name = d:GetAttribute("PropName")
				if name == "Cobweb" then
					continue -- hung on a lamp, tree or tower that was already checked
				end
				t.ok(not HubLayout.Blocked(d:GetPivot().Position, 0), name .. " inside a zone")
				checked += 1
			elseif d:IsA("BasePart") and d.Name == "PathStone" then
				t.ok(not HubLayout.Blocked(d.CFrame.Position, 0), "path stone inside a zone")
			end
		end
		t.ok(checked > 50, "props were checked")
		local lamps = 0
		for _, child in hub.Decor.Lamps:GetChildren() do
			if child:GetAttribute("PropName") == "Lamppost" then
				lamps += 1
			end
		end
		t.ok(lamps < Config.Hub.Lampposts.Count, "the lamp in the Parkour zone was left out")
		t.ok(lamps > Config.Hub.Lampposts.Count / 2, "most lamps are there")
	end)

	t.test("every PaletteRole names a palette colour and the part has that colour", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
		local roles = 0
		for _, d in hub:GetDescendants() do
			local role = d:GetAttribute("PaletteRole")
			if role == nil then
				continue
			end
			roles += 1
			t.ok(
				Config.Hub.Palette[role],
				"unknown PaletteRole " .. tostring(role) .. " on " .. d.Name
			)
			local expected = Kit.roleColor(Config.Hub.Palette, role, d:GetAttribute("PaletteShade"))
			t.ok(colorNear(d.Color, expected), d:GetFullName() .. " has its palette colour")
		end
		t.ok(roles > 200, "parts carry roles")
		t.eq(Config.Hub.Colors, Config.Hub.Palette, "Colors is the old name for Palette")
	end)

	t.test("palette sync repaints only the roles that changed", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
		t.eq(HubPalette.Sync(hub), 0, "nothing changed yet")
		local stone = hub.ReadyArea.ReadyPad
		local handPainted = Color3.new(1, 0, 0)
		stone.Color = handPainted
		local wood = hub.Shop.PumpkinVendor.Stall.Counter
		local old = Config.Hub.Palette.Wood
		Config.Hub.Palette.Wood = Color3.fromRGB(10, 200, 10)
		local changed = HubPalette.Sync(hub)
		t.ok(changed > 10, "the wood parts were repainted")
		t.ok(colorNear(wood.Color, Config.Hub.Palette.Wood), "the counter is the new wood colour")
		t.ok(colorNear(stone.Color, handPainted), "a hand-painted stone part keeps its colour")
		t.eq(HubPalette.Sync(hub), 0, "a second sync changes nothing")
		Config.Hub.Palette.Wood = old
		t.ok(HubPalette.Repaint(hub) > 0, "Repaint brings everything back")
		t.ok(colorNear(stone.Color, Kit.roleColor(Config.Hub.Palette, "Stone", 0.35)))
	end)

	t.test("HubService builds a hub when there is none and the spawn is found by tag", function()
		clearWorkspace()
		HubService.Start()
		local hub = currentHub()
		t.ok(hub, "a hub was built")
		t.eq(hub:GetAttribute("BuildVersion"), Config.Hub.BuildVersion)
		local spawn = tagged(Tags.HubSpawn, hub)[1]
		t.near(
			MapService.LobbyCFrame().Position,
			spawn.CFrame.Position + Vector3.new(0, Config.Maps.SpawnHeight, 0),
			1e-3,
			"the lobby spot is the tagged spawn"
		)
		t.ok(HubService.Screen("Leaderboard"), "the leaderboard screen is found")
		t.ok(HubService.Screen("VotingBoard"), "the voting board screen is found")
	end)

	t.test("an old unlocked hub is rebuilt; an old Locked hub is kept and repaired", function()
		clearWorkspace()
		local old = Instance.new("Model")
		old.Name = "Hub"
		old:SetAttribute("Marker", "old")
		old:SetAttribute("BuildVersion", 1)
		old.Parent = t.workspace
		HubService.Start()
		local hub = currentHub()
		t.eq(hub:GetAttribute("Marker"), nil, "rebuilt")
		t.eq(hub:GetAttribute("BuildVersion"), Config.Hub.BuildVersion)

		clearWorkspace()
		local locked = Instance.new("Model")
		locked.Name = "Hub"
		locked:SetAttribute("Locked", true)
		local ground = Instance.new("Part")
		ground.Name = "Ground"
		ground.Parent = locked
		local oldSpawn = Instance.new("SpawnLocation")
		oldSpawn.Name = "Spawn"
		oldSpawn.CFrame = CFrame.new(5, 2, 5)
		oldSpawn.Parent = locked
		local npcs = Instance.new("Folder")
		npcs.Name = "Npcs"
		npcs.Parent = locked
		for _, id in { "WitchWanda", "BooGuide" } do
			local m = Instance.new("Model")
			m.Name = id
			m.Parent = npcs
		end
		locked.Parent = t.workspace
		HubService.Start()
		hub = currentHub()
		t.eq(hub:GetAttribute("Locked"), true, "the Locked hub was kept")
		t.eq(hub:GetAttribute("BuildVersion"), nil, "and not rebuilt")
		t.eq(npcs:FindFirstChild("WitchWanda"), nil, "Witch Wanda removed")
		t.eq(npcs:FindFirstChild("BooGuide"), nil, "Boo Guide removed")
		t.ok(oldSpawn:HasTag(Tags.HubSpawn), "the old spawn was tagged, not replaced")
		t.eq(#tagged(Tags.HubSpawn, hub), 1, "still one spawn")
		t.eq(#tagged(Tags.ReadyPad, hub), 1, "the Ready pad was put back")
		t.ok(shopPromptIn(hub), "the shopkeeper was put back")
		t.ok(Lobby.InZone(tagged(Tags.ReadyPad, hub)[1].CFrame.Position, "ReadyArea"))
	end)

	t.test("a Locked current hub gets a deleted pad, spawn and shop prompt back", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
		hub:SetAttribute("Locked", true)
		tagged(Tags.ReadyPad, hub)[1]:Destroy()
		tagged(Tags.HubSpawn, hub)[1]:Destroy()
		local vendor = hub.Shop.PumpkinVendor
		vendor.PromptAnchor:Destroy()
		HubService.Start()
		t.eq(currentHub():GetAttribute("Locked"), true)
		t.eq(#tagged(Tags.ReadyPad, hub), 1, "pad back")
		t.eq(#tagged(Tags.ReadySign, hub), 1, "the sign was still there, so only one")
		t.eq(#tagged(Tags.HubSpawn, hub), 1, "spawn back")
		t.ok(shopPromptIn(hub), "shop prompt back")
		t.ok(vendor:FindFirstChild("PromptAnchor"), "on the existing stall, not a second one")
		local vendors = 0
		for _, d in hub:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("NpcId") == "PumpkinVendor" then
				vendors += 1
			end
		end
		t.eq(vendors, 1, "one vendor")
	end)

	t.test("any part tagged ShopKeeper becomes a shop entrance", function()
		clearWorkspace()
		local hub = Instance.new("Model")
		hub.Name = "Hub"
		hub:SetAttribute("Locked", true)
		local sign = Instance.new("Part")
		sign.Name = "MyShopSign"
		sign:AddTag(Tags.ShopKeeper)
		sign.Parent = hub
		hub.Parent = t.workspace
		HubService.EnsureRequired(hub)
		local prompt = sign:FindFirstChildWhichIsA("ProximityPrompt")
		t.ok(prompt, "the tagged part got a prompt")
		t.eq(prompt:GetAttribute("NpcId"), "PumpkinVendor")
		t.eq(Npcs.Find(hub, "PumpkinVendor"), nil, "no second shop was built")
	end)

	t.test("the fallback hub has a spawn and a Ready pad", function()
		clearWorkspace()
		local hub = HubBuilder.BuildFallback()
		t.eq(hub:GetAttribute("Fallback"), true)
		t.eq(hub:GetAttribute("BuildVersion"), nil, "the next start tries the full hub again")
		t.eq(#tagged(Tags.HubSpawn, hub), 1)
		t.eq(#tagged(Tags.ReadyPad, hub), 1)
		HubService.EnsureRequired(hub)
		t.ok(shopPromptIn(hub), "EnsureRequired adds the shop")
	end)

	-- Custom models in a fake ReplicatedStorage.Custom.
	local function customFolder(category: string, model: any): any
		local root = Instance.new("Folder")
		root.Name = "Custom"
		local folder = Instance.new("Folder")
		folder.Name = category
		folder.Parent = root
		model.Parent = folder
		return root
	end

	local function block(size: Vector3, transparency: number?): any
		local m = Instance.new("Model")
		m.Name = "PumpkinVendor"
		local p = Instance.new("Part")
		p.Name = "Body"
		p.Size = size
		p.CFrame = CFrame.new(0, size.Y / 2, 0)
		p.Transparency = transparency or 0
		p.Parent = m
		return m
	end

	t.test("a custom shopkeeper is only used when it passes the checks", function()
		local cases = {
			{
				Name = "too small (KeepSize)",
				Model = block(Vector3.new(1, 1, 1)),
				Keep = true,
				Used = false,
			},
			{
				Name = "invisible",
				Model = block(Vector3.new(2, 6, 2), 1),
				Keep = false,
				Used = false,
			},
			{ Name = "a good one", Model = block(Vector3.new(2, 6, 2)), Keep = false, Used = true },
		}
		for _, case in cases do
			clearWorkspace()
			if case.Keep then
				case.Model:SetAttribute("KeepSize", true)
			end
			t.setCustom(customFolder("Characters", case.Model))
			local hub = HubBuilder.Build()
			local vendor = Npcs.Find(hub, "PumpkinVendor")
			Npcs.ApplyCustom(hub)
			t.eq(vendor:FindFirstChild("Look") ~= nil, case.Used, case.Name .. ": custom used")
			t.eq(
				vendor:FindFirstChild("Keeper") ~= nil,
				not case.Used,
				case.Name .. ": built keeper"
			)
			if case.Used then
				local look = vendor.Look
				local body = look.Body
				local spot = vendor.KeeperSpot.CFrame
				t.near(body.CFrame.Y - body.Size.Y / 2, spot.Y, 0.05, "feet on the KeeperSpot")
				t.near(
					body.Size.Y,
					Config.Custom.Heights.PumpkinVendor,
					0.05,
					"scaled to its height"
				)
				t.ok(vendor:FindFirstChild("TagAnchor"), "the name anchor stays above the awning")
			end
		end

		-- Only the stall was moved in Studio: the custom keeper still stands behind its counter.
		clearWorkspace()
		t.setCustom(customFolder("Characters", block(Vector3.new(2, 6, 2))))
		local hub = HubBuilder.Build()
		local vendor = Npcs.Find(hub, "PumpkinVendor")
		local stall = vendor.Stall
		stall:PivotTo(stall:GetPivot() * CFrame.new(6, 0, 0))
		Npcs.ApplyCustom(hub)
		local behindCounter = stall:GetPivot() * CFrame.new(0, 0, 0.5)
		local body = vendor.Look.Body
		t.near(body.CFrame.X, behindCounter.X, 0.05, "the keeper followed the stall (x)")
		t.near(body.CFrame.Z, behindCounter.Z, 0.05, "the keeper followed the stall (z)")
		t.setCustom(nil)
	end)

	t.test("custom props replace every copy, at build time and in a saved hub", function()
		clearWorkspace()
		local hub = HubBuilder.Build()
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
		t.ok(total > 20, "jack-o-lanterns everywhere")
		local lantern = Instance.new("Model")
		lantern.Name = "JackOLantern"
		local ball = Instance.new("Part")
		ball.Name = "Ball"
		ball.Size = Vector3.new(4, 4, 4)
		ball.Parent = lantern
		t.setCustom(customFolder("Props", lantern))
		local swapped = Kit.applyCustomProps(hub)
		t.eq(swapped, total, "every built jack-o-lantern was swapped")
		t.eq(count(true), total, "and they are all custom now")
		t.eq(Kit.applyCustomProps(hub), 0, "running it again changes nothing")

		clearWorkspace()
		hub = HubBuilder.Build()
		t.eq(count(true), count(false), "a fresh build uses the custom one straight away")
		t.setCustom(nil)
	end)

	t.test("Bake builds the hub and maps for hand editing", function()
		clearWorkspace()
		local hub = Bake.Hub()
		t.ok(hub and hub.Parent == t.workspace, "baked hub in Workspace")
		t.eq(hub:GetAttribute("BuildVersion"), Config.Hub.BuildVersion)
		Bake.Lock()
		t.eq(hub:GetAttribute("Locked"), true)
		t.eq(Bake.Hub(), nil, "a Locked hub is not replaced")
		local replaced = Bake.Hub(true)
		t.ok(replaced, "Hub(true) replaces it")
		t.ok(ServerStorage:FindFirstChild("HubBackup"), "the old hub is kept as a backup")
		t.eq(#Bake.Repair(), 0, "nothing to repair on a fresh hub")
		t.ok(Bake.Repaint() >= 0)

		local map = Bake.Map("PumpkinFarm")
		t.ok(map, "baked map")
		t.eq(map.Parent, ServerStorage.Maps)
		t.near(map.WorldPivot.Position, Config.Maps.Origin, 1e-4, "pivot at the map origin")
		t.ok(map:FindFirstChild("Floor"), "it has its Floor")
		Bake.Map("PumpkinFarm")
		t.ok(ServerStorage.Maps:FindFirstChild("PumpkinFarm_Backup"), "the older copy is kept")
		t.eq(Bake.Map("NoSuchMap"), nil)
	end)

	t.test("the Ready sign text", function()
		local sign = Config.Hub.ReadyArea.Sign
		local title, status = ReadySign.Text(nil, nil, nil, false)
		t.eq(title, sign.TitleWaiting)
		t.eq(status, Config.Lobby.Ready.PadText)
		title, status = ReadySign.Text(1, 2, "Voting", false)
		t.eq(title, "READY 1 / 2")
		t.eq(status, sign.States.Voting)
		title = ReadySign.Text(3, 2, "Playing", false)
		t.eq(title, "READY 3", "enough players: just the count")
		local _, mine = ReadySign.Text(1, 2, "Voting", true)
		t.eq(mine, sign.YouAreReady)
		local _, other = ReadySign.Text(0, 1, "Some New State", false)
		t.eq(other, "Some New State", "unknown states are shown as they are")
	end)
end
