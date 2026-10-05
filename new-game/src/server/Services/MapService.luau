--!strict
--[[
	Loads the round map and unloads it afterwards.
	Uses ServerStorage.Maps.<Id> if a hand-made map exists, otherwise builds one with
	src/server/Maps/<Builder>.luau from Config.Maps.List[i].
	The loaded model is Workspace.Map with attribute MapId; the client uses it to switch to
	the map's lighting and ambient sound (src/client/ZoneLighting.luau).

	A map must have a part named "Floor" and a folder named after its SpawnFolder with spawn
	parts in it. If a map is broken (missing those, or its builder errors), the Output window
	says what is wrong and the game carries on with the next thing that works: the same map
	built from code, then the first map made for Config.Modes.FallbackMode. So the returned
	map's Id can differ from the one asked for.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builders = script.Parent.Parent.Maps

export type LoadedMap = {
	Id: string,
	Name: string,
	Model: Model,
	Floor: BasePart,
	Spawns: { BasePart },
	Hotspots: { BasePart }, -- areas where extra (risky) pumpkins spawn; may be empty
}

local MapService = {}

local current: LoadedMap? = nil

function MapService.Get(id: string): any
	for _, def in Config.Maps.List do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- The hand-made copy of a map in ServerStorage.Maps, if there is one.
local function handMade(id: string): Model?
	local folder = ServerStorage:FindFirstChild("Maps")
	local source = folder and folder:FindFirstChild(id)
	return if source and source:IsA("Model") then source else nil
end

local function partsIn(folder: Instance?): { BasePart }
	local parts: { BasePart } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
	end
	return parts
end

--[[
	Makes one map (cloned from ServerStorage.Maps when `useHandMade`, else built from code) and
	checks it has a Floor and spawns before it goes into Workspace. Errors with a short
	reason if anything is wrong; a broken map never stays in Workspace.
]]
local function make(def: any, useHandMade: boolean): LoadedMap
	local id: string = def.Id
	local source = if useHandMade then handMade(id) else nil
	local model: Model
	if source then
		model = source:Clone()
		model:PivotTo(CFrame.new(Config.Maps.Origin))
	else
		local builder = Builders:FindFirstChild(tostring(def.Builder or ""))
		if not (builder and builder:IsA("ModuleScript")) then
			error(("no builder src/server/Maps/%s.luau"):format(tostring(def.Builder)), 0)
		end
		local built = (require :: any)(builder).Build(def)
		if typeof(built) ~= "Instance" or not built:IsA("Model") then
			error("its builder's Build(def) didn't return a Model", 0)
		end
		model = built
	end

	local floor = model:FindFirstChild("Floor", true)
	local spawnFolder = model:FindFirstChild(tostring(def.SpawnFolder))
		or model:FindFirstChild(tostring(def.SpawnFolder), true)
	local spawns = partsIn(spawnFolder)
	local problem = if not (floor and floor:IsA("BasePart"))
		then "it has no part named Floor"
		elseif #spawns == 0 then ("its %s folder has no spawn parts"):format(
			tostring(def.SpawnFolder)
		)
		else nil
	if problem or not (floor and floor:IsA("BasePart")) then
		model:Destroy()
		error(problem or "it has no part named Floor", 0)
	end

	model.Name = "Map"
	model:SetAttribute("MapId", id)
	model.Parent = workspace
	return {
		Id = id,
		Name = def.Name,
		Model = model,
		Floor = floor,
		Spawns = spawns,
		Hotspots = partsIn(model:FindFirstChild("Hotspots")),
	}
end

-- Loads map `id` (unloading the current one). Never leaves the game without a map: see the
-- header for what happens when a map is broken. Errors only if no map at all can be made.
function MapService.Load(id: string): LoadedMap
	MapService.Unload()
	type Attempt = { Def: any, HandMade: boolean }
	local attempts: { Attempt } = {}
	local def = MapService.Get(id)
	if def then
		if handMade(id) then
			table.insert(attempts, { Def = def, HandMade = true })
		end
		table.insert(attempts, { Def = def, HandMade = false })
	else
		warn(("[MapService] There is no map %q in Config.Maps.List."):format(tostring(id)))
	end
	-- Last resort: the maps made for the fallback mode (King Hunt), hand-made or from code.
	local fallbackMode = Config.Modes.FallbackMode
	for _, other in Config.Maps.List do
		if other ~= def and (other.Modes == nil or table.find(other.Modes, fallbackMode)) then
			if handMade(other.Id) then
				table.insert(attempts, { Def = other, HandMade = true })
			end
			table.insert(attempts, { Def = other, HandMade = false })
		end
	end

	for _, attempt in attempts do
		local ok, result = pcall(make, attempt.Def, attempt.HandMade)
		if ok then
			if attempt.Def ~= def then
				warn(
					("[MapService] Loaded %s instead of %s so the round can still be played."):format(
						attempt.Def.Id,
						tostring(id)
					)
				)
			end
			current = result
			return result
		end
		warn(
			("[MapService] Map %s (%s) is broken: %s"):format(
				tostring(attempt.Def.Id),
				if attempt.HandMade then "hand-made, ServerStorage.Maps" else "built from code",
				tostring(result)
			)
		)
	end
	error("[MapService] No map could be loaded: check Config.Maps.List and src/server/Maps/.")
end

function MapService.Unload()
	if current then
		current.Model:Destroy()
		current = nil
	end
end

function MapService.Current(): LoadedMap?
	return current
end

-- A random point on open floor (not on top of an obstacle), `height` studs above it.
function MapService.RandomFloorPoint(
	map: LoadedMap,
	edgeMargin: number,
	attempts: number,
	height: number
): Vector3?
	local floor = map.Floor
	local halfX = floor.Size.X / 2 - edgeMargin
	local halfZ = floor.Size.Z / 2 - edgeMargin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }

	for _ = 1, attempts do
		local point = floor.CFrame
			* Vector3.new(
				math.random() * halfX * 2 - halfX,
				floor.Size.Y / 2,
				math.random() * halfZ * 2 - halfZ
			)
		-- Cast down from high above; only accept spots where the first thing hit is the floor.
		local result =
			workspace:Raycast(point + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
		if result and result.Instance == floor then
			return result.Position + Vector3.new(0, height, 0)
		end
	end
	return nil
end

-- Like RandomFloorPoint, but inside one of the map's hotspot areas. nil if it has none.
function MapService.RandomHotspotPoint(map: LoadedMap, attempts: number, height: number): Vector3?
	if #map.Hotspots == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }
	for _ = 1, attempts do
		local area = map.Hotspots[math.random(1, #map.Hotspots)]
		local point = area.CFrame
			* Vector3.new(
				(math.random() - 0.5) * area.Size.X,
				0,
				(math.random() - 0.5) * area.Size.Z
			)
		local result =
			workspace:Raycast(point + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
		if result and result.Instance == map.Floor then
			return result.Position + Vector3.new(0, height, 0)
		end
	end
	return nil
end

-- Where players stand between rounds: a part tagged HubSpawn, else the hub's Spawn pad (or
-- any SpawnLocation as a fallback).
function MapService.LobbyCFrame(): CFrame
	local spawn: Instance? = nil
	for _, tagged in CollectionService:GetTagged(Tags.HubSpawn) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(workspace) then
			spawn = tagged
			break
		end
	end
	local hub = workspace:FindFirstChild("Hub")
	spawn = spawn
		or (hub and hub:FindFirstChild("Spawn"))
		or workspace:FindFirstChildOfClass("SpawnLocation")
	local position = if spawn and spawn:IsA("BasePart") then spawn.Position else Vector3.zero
	return CFrame.new(position + Vector3.new(0, Config.Maps.SpawnHeight, 0))
end

function MapService.Start()
	assert(#Config.Maps.List > 0, "Config.Maps.List is empty")
end

return MapService
