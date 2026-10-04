--!strict
--[[
	Loads the round map and unloads it afterwards.
	Uses ServerStorage.Maps.<Id> if a real map exists, otherwise builds a placeholder
	from Config.Maps.List[i].Placeholder so every map is playable before art is done.
]]

local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type LoadedMap = {
	Id: string,
	Name: string,
	Model: Model,
	Floor: BasePart,
	Spawns: { BasePart },
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

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function buildPlaceholder(def: any): Model
	local cfg = def.Placeholder
	local origin: Vector3 = Config.Maps.Origin
	local size: Vector3 = cfg.Size
	local rng = Random.new(cfg.Seed)

	local model = Instance.new("Model")
	model.Name = def.Id

	part({
		Name = "Floor",
		Size = size,
		Position = origin,
		Color = cfg.FloorColor,
		Material = Enum.Material.Grass,
	}, model)

	-- Perimeter walls so nobody walks off the edge.
	local top = origin.Y + size.Y / 2
	local wallY = top + cfg.WallHeight / 2
	for _, w in
		{
			{ Vector3.new(size.X, cfg.WallHeight, 2), Vector3.new(0, 0, size.Z / 2) },
			{ Vector3.new(size.X, cfg.WallHeight, 2), Vector3.new(0, 0, -size.Z / 2) },
			{ Vector3.new(2, cfg.WallHeight, size.Z), Vector3.new(size.X / 2, 0, 0) },
			{ Vector3.new(2, cfg.WallHeight, size.Z), Vector3.new(-size.X / 2, 0, 0) },
		}
	do
		part({
			Name = "Wall",
			Size = w[1],
			Position = Vector3.new(origin.X, wallY, origin.Z) + w[2],
			Color = cfg.WallColor,
			Material = Enum.Material.WoodPlanks,
		}, model)
	end

	-- Obstacles stand in for props/rooms; kept out of the spawn ring.
	local minS: Vector3, maxS: Vector3 = cfg.ObstacleMinSize, cfg.ObstacleMaxSize
	local halfX, halfZ = size.X / 2 - maxS.X, size.Z / 2 - maxS.Z
	local placed = 0
	local tries = 0
	while placed < cfg.Obstacles and tries < cfg.Obstacles * 10 do
		tries += 1
		local offset = Vector3.new(rng:NextNumber(-halfX, halfX), 0, rng:NextNumber(-halfZ, halfZ))
		if offset.Magnitude >= cfg.ObstacleClearRadius then
			local s = Vector3.new(
				rng:NextNumber(minS.X, maxS.X),
				rng:NextNumber(minS.Y, maxS.Y),
				rng:NextNumber(minS.Z, maxS.Z)
			)
			part({
				Name = "Obstacle",
				Size = s,
				CFrame = CFrame.new(origin + offset + Vector3.new(0, size.Y / 2 + s.Y / 2, 0))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color = cfg.ObstacleColor,
				Material = Enum.Material.Slate,
			}, model)
			placed += 1
		end
	end

	local spawns = Instance.new("Folder")
	spawns.Name = def.SpawnFolder
	spawns.Parent = model
	for i = 1, cfg.Spawns do
		local angle = (i / cfg.Spawns) * math.pi * 2
		part({
			Name = "Spawn",
			Size = Vector3.new(4, 1, 4),
			Position = origin + Vector3.new(
				math.cos(angle) * cfg.SpawnRadius,
				size.Y,
				math.sin(angle) * cfg.SpawnRadius
			),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, spawns)
	end

	return model
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
		model = buildPlaceholder(def)
	end
	model.Name = "Map"
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

	local loaded: LoadedMap =
		{ Id = id, Name = def.Name, Model = model, Floor = floor, Spawns = spawns }
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

-- Where players stand between rounds: the lobby SpawnLocation in the place.
function MapService.LobbyCFrame(): CFrame
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	local position = if spawn then spawn.Position else Vector3.zero
	return CFrame.new(position + Vector3.new(0, Config.Maps.SpawnHeight, 0))
end

function MapService.Start()
	assert(#Config.Maps.List > 0, "Config.Maps.List is empty")
end

return MapService
