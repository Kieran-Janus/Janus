--!strict
--[[
	Loads the round map and unloads it afterwards.
	Uses ServerStorage.Maps.<Id> if a hand-made map exists, otherwise builds one with
	src/server/Maps/<Builder>.luau from Config.Maps.List[i]. Bake a built map into
	ServerStorage.Maps to edit it by hand: src/server/Tools/Bake.luau (Bake.Map("<Id>")).
	ServerStorage.Maps is synced from the maps/ folder (default.project.json), so a map saved
	there as <Id>.rbxm is in git too.
	The loaded model is Workspace.Map with attribute MapId; the client uses it to switch to
	the map's lighting and ambient sound (src/client/ZoneLighting.luau).
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

function MapService.Load(id: string): LoadedMap
	MapService.Unload()
	local def = MapService.Get(id)
	assert(def, "unknown map " .. id)

	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	local source = mapsFolder and mapsFolder:FindFirstChild(id)
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
		model:PivotTo(CFrame.new(Config.Maps.Origin))
	else
		local builder = Builders:FindFirstChild(def.Builder or "")
		assert(
			builder and builder:IsA("ModuleScript"),
			id .. " has no ServerStorage map or Builder"
		)
		model = (require :: any)(builder).Build(def)
	end
	model.Name = "Map"
	model:SetAttribute("MapId", id)
	model.Parent = workspace

	local floor = model:FindFirstChild("Floor", true)
	assert(floor and floor:IsA("BasePart"), id .. " has no Floor part")
	local spawns: { BasePart } = {}
	local spawnFolder = model:FindFirstChild(def.SpawnFolder)
	if spawnFolder then
		for _, child in spawnFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end
	assert(#spawns > 0, id .. " has no spawns")
	local hotspots: { BasePart } = {}
	local hotspotFolder = model:FindFirstChild("Hotspots")
	if hotspotFolder then
		for _, child in hotspotFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(hotspots, child)
			end
		end
	end

	local loaded: LoadedMap = {
		Id = id,
		Name = def.Name,
		Model = model,
		Floor = floor,
		Spawns = spawns,
		Hotspots = hotspots,
	}
	current = loaded
	return loaded
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

-- Where players stand between rounds: a part tagged HubSpawn in the lobby (or the hub's
-- "Spawn", or any SpawnLocation, as fallbacks).
function MapService.LobbyCFrame(): CFrame
	local spawn: BasePart? = nil
	for _, tagged in CollectionService:GetTagged(Tags.HubSpawn) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(workspace) then
			spawn = tagged
			break
		end
	end
	if not spawn then
		local hub = workspace:FindFirstChild("Hub")
		local named = hub and hub:FindFirstChild("Spawn")
		spawn = if named and named:IsA("BasePart")
			then named
			else workspace:FindFirstChildOfClass("SpawnLocation")
	end
	local position = if spawn then spawn.CFrame.Position else Vector3.zero
	return CFrame.new(position + Vector3.new(0, Config.Maps.SpawnHeight, 0))
end

function MapService.Start()
	assert(#Config.Maps.List > 0, "Config.Maps.List is empty")
end

return MapService
