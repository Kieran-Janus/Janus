-- Builds the hub and every map in a fake DataModel and checks the parts that come out.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Enum = require("@lune/roblox").Enum

local describe, it, expect = T.describe, T.it, T.expect

-- Every BasePart under `root` has a real, positive size and a finite position.
local function checkParts(root: any): number
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			local size, position = d.Size, d.Position
			if not (size.X > 0 and size.Y > 0 and size.Z > 0) then
				error(("%s has size %s"):format(d:GetFullName(), tostring(size)))
			end
			expect(size).toBeFinite()
			expect(position).toBeFinite()
			expect(d.CFrame).toBeFinite()
		end
	end
	return parts
end

--[[
	Ball parts with unequal sides. Roblox forces a Ball's Size to be uniform, so these show up
	as plain spheres in game (Cosmetics.luau swaps such balls for a Block + sphere
	SpecialMesh). Reported as a note, not a failure.
]]
local function squashedBalls(root: any): number
	local count = 0
	for _, d in root:GetDescendants() do
		if
			d:IsA("Part")
			and d.Shape == Enum.PartType.Ball
			and not d:FindFirstChildOfClass("SpecialMesh")
		then
			local s = d.Size
			if math.abs(s.X - s.Y) > 1e-6 or math.abs(s.Y - s.Z) > 1e-6 then
				count += 1
			end
		end
	end
	return count
end

local function noteSquashedBalls(root: any)
	local count = squashedBalls(root)
	if count > 0 then
		T.note(("%d Ball parts have unequal sides (Roblox renders them as spheres)"):format(count))
	end
end

describe("HubBuilder", function()
	local rt = Runtime.new()
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local hub

	it("builds the hub into Workspace", function()
		hub = HubBuilder.Build()
		expect(hub).toBeInstanceOf("Model")
		expect(hub.Parent).toBe(rt.workspace)
		expect(hub.Name).toBe("Hub")
		expect(hub.PrimaryPart).toBeInstanceOf("BasePart")
		local parts = checkParts(hub)
		expect(parts).toBeGreaterThan(0)
		T.note(("%d parts, %d instances"):format(parts, #hub:GetDescendants()))
		noteSquashedBalls(hub)
	end)

	it("has a spawn pad and every NPC with a prompt", function()
		-- The spawn and NPCs are found the way the game finds them: by tag / NpcId, wherever
		-- they sit in the hub (an NPC with a Zone stands in that section, e.g. Hub.Shop).
		local CollectionService = rt.game:GetService("CollectionService")
		local spawns = CollectionService:GetTagged("HubSpawn")
		expect(#spawns).toBe(1)
		expect(spawns[1]).toBeInstanceOf("SpawnLocation")
		expect(spawns[1]:IsDescendantOf(hub)).toBe(true)
		expect(hub:FindFirstChild("Npcs")).toBeInstanceOf("Folder")
		local Npcs = rt:require("ServerScriptService.Server.Hub.Npcs")
		for _, def in Config.Npcs.List do
			local npc = Npcs.Find(hub, def.Id)
			expect(npc).toBeInstanceOf("Model")
			local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
			expect(prompt).toBeTruthy()
			expect(prompt:GetAttribute("NpcId")).toBe(def.Id)
		end
	end)

	it("tags every top-level piece as a hub piece", function()
		for _, child in hub:GetChildren() do
			expect(child:GetAttribute(HubBuilder.PieceAttribute)).toBe(true)
		end
	end)

	it("tags animated decorations for the client", function()
		local CollectionService = rt.game:GetService("CollectionService")
		expect(#CollectionService:GetTagged("HubFlicker")).toBeGreaterThan(0)
		expect(#CollectionService:GetTagged("HubFloat")).toBeGreaterThan(0)
	end)

	it("shapes the terrain around the plaza", function()
		local calls = #rt:calls("Terrain", "FillCylinder") + #rt:calls("Terrain", "FillBall")
		if Config.Hub.Polish.Terrain.Enabled then
			expect(calls).toBeGreaterThan(0)
		end
		T.note(calls, "terrain fill calls (recorded, not simulated)")
	end)

	it("rebuilds deterministically and replaces the old hub", function()
		local count = #rt:parts(hub)
		local again = HubBuilder.Build()
		expect(#HubBuilder.FindHubs()).toBe(1)
		expect(#rt:parts(again)).toBe(count)
		hub = again
	end)

	it("applies the hub lighting", function()
		HubBuilder.ApplyLighting()
		local Lighting = rt.game:GetService("Lighting")
		expect(Lighting.ClockTime).toBeNear(Config.Hub.Lighting.ClockTime, 1e-3)
		expect(Lighting:FindFirstChild("HubAtmosphere")).toBeInstanceOf("Atmosphere")
	end)
end)

describe("HubBuilder with custom NPC models (ReplicatedStorage.Custom.Characters)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CFrame, Vector3 = rt.env.CFrame, rt.env.Vector3

	it("swaps them in, scaled to Config.Custom.Heights, feet on the plaza", function()
		local folder = rt:find("ReplicatedStorage.Custom.Characters")
		local swapped = 0
		for _, def in Config.Npcs.List do
			if Config.Custom.Heights[def.Id] then
				-- Built at the wrong size, far away: the game must fit and place it.
				local model = rt:create("Model", { Name = def.Id })
				rt:create("Part", {
					Name = "Body",
					Size = Vector3.new(4, 14, 4),
					CFrame = CFrame.new(500, 107, 0),
				}, model)
				rt:create("Part", {
					Name = "Head",
					Size = Vector3.new(6, 6, 6),
					CFrame = CFrame.new(500, 117, 0),
				}, model)
				model.Parent = folder
			end
		end
		local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
		local Npcs = rt:require("ServerScriptService.Server.Hub.Npcs")
		local hub = HubBuilder.Build()
		-- HubService does this on every start (also on a hub saved in the place).
		HubBuilder.ApplyCustomNpcs(hub)
		for _, def in Config.Npcs.List do
			local height = Config.Custom.Heights[def.Id]
			local npc = Npcs.Find(hub, def.Id)
			local look = npc:FindFirstChild("Look")
			-- Only people can be swapped (the shopkeeper); boards and screens keep their look.
			if height and def.Kind == "Vendor" then
				swapped += 1
				expect(look).toBeInstanceOf("Model")
				expect(npc:FindFirstChild("Keeper")).toBeNil()
				local box, size = look:GetBoundingBox()
				expect(size.Y).toBeNear(height, 1e-3)
				-- Feet on the KeeperSpot, behind the stall's counter.
				local spot = npc:FindFirstChild("KeeperSpot").Position
				expect(box.Position.Y - size.Y / 2).toBeNear(spot.Y, 1e-3)
				local flat = Vector3.new(box.Position.X - spot.X, 0, box.Position.Z - spot.Z)
				expect(flat.Magnitude).toBeLessThan(1)
				expect(npc:FindFirstChild("PromptAnchor")).toBeInstanceOf("BasePart")
				expect(npc:FindFirstChild("TagAnchor")).toBeInstanceOf("BasePart")
			else
				expect(look).toBeNil()
			end
		end
		expect(swapped).toBeGreaterThan(0)
		T.note(swapped, "NPCs swapped for custom models")
	end)
end)

describe("Map builders", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local maps = rt:find("ServerScriptService.Server.Maps")

	for _, def in Config.Maps.List do
		it(("builds %s with %s.Build"):format(def.Id, def.Builder), function()
			local builder = rt:require(maps:FindFirstChild(def.Builder))
			local model = builder.Build(def)
			expect(model).toBeInstanceOf("Model")
			local parts = checkParts(model)
			expect(parts).toBeGreaterThan(0)
			expect(model:FindFirstChild("Floor")).toBeInstanceOf("BasePart")
			local spawns = model:FindFirstChild(def.SpawnFolder)
			expect(#spawns:GetChildren()).toBe(def.Spawns)
			local _, size = model:GetBoundingBox()
			T.note(
				("%d parts, %d hiding spots, bounds %.0f x %.0f x %.0f studs"):format(
					parts,
					#(function()
							local list = {}
							for _, d in model:GetDescendants() do
								if d:HasTag("HidingSpot") then
									table.insert(list, d)
								end
							end
							return list
						end)(),
					size.X,
					size.Y,
					size.Z
				)
			)
			noteSquashedBalls(model)
			-- Seeded, so a second build is identical.
			local again = builder.Build(def)
			expect(#rt:parts(again)).toBe(parts)
			model:Destroy()
			again:Destroy()
		end)
	end
end)

describe("MapService", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")

	for _, def in Config.Maps.List do
		it(("loads %s into Workspace and finds floor points"):format(def.Id), function()
			local map = MapService.Load(def.Id)
			expect(map.Model.Parent).toBe(rt.workspace)
			expect(map.Model.Name).toBe("Map")
			expect(map.Model:GetAttribute("MapId")).toBe(def.Id)
			expect(#map.Spawns).toBe(def.Spawns)
			-- Raycasts hit real part geometry in the harness, so random floor points work.
			local point = MapService.RandomFloorPoint(map, 6, 40, 3)
			expect(point).toBeA("Vector3")
			local floorTop = map.Floor.Position.Y + map.Floor.Size.Y / 2
			expect(point.Y).toBeNear(floorTop + 3, 1e-3)
			if #map.Hotspots > 0 then
				expect(MapService.RandomHotspotPoint(map, 40, 3)).toBeA("Vector3")
			end
			T.note(("%d spawns, %d hotspots"):format(#map.Spawns, #map.Hotspots))
		end)
	end

	it("unloads the previous map", function()
		MapService.Load(Config.Maps.List[1].Id)
		MapService.Unload()
		expect(rt.workspace:FindFirstChild("Map")).toBeNil()
		expect(MapService.Current()).toBeNil()
	end)
end)
