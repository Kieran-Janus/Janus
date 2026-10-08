--!strict
--[[
	What every built map shares: the floor, the walls around the edge, the spawn ring, the
	"Hotspots" folder (where PumpkinService puts extra pumpkins) and map-wide ambient particles.
	A map builder calls MapBase.new, adds its own layout to ctx.Model, and returns the Model.
]]

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)
local MapScenery = require(script.Parent.MapScenery)

export type Ctx = {
	Def: any,
	Model: Model,
	Rng: Random,
	Origin: Vector3, -- centre of the floor's top surface
	Half: Vector2, -- half the floor size (x, z)
	Hotspots: Folder,
}

export type Style = {
	FloorColor: Color3,
	FloorMaterial: Enum.Material,
	WallColor: Color3,
	WallMaterial: Enum.Material,
}

local MapBase = {}

function MapBase.new(def: any, style: Style): Ctx
	local origin: Vector3 = Config.Maps.Origin
	local size: Vector3 = def.Size
	local model = Instance.new("Model")
	model.Name = def.Id

	Kit.part({
		Name = "Floor",
		Size = size,
		Position = origin,
		Color = style.FloorColor,
		Material = style.FloorMaterial,
	}, model)

	-- Perimeter walls so nobody walks off the edge.
	local top = origin.Y + size.Y / 2
	local height: number = def.WallHeight
	local walls = Kit.model("Walls", model)
	for _, w in
		{
			{ Vector3.new(size.X + 4, height, 2), Vector3.new(0, 0, size.Z / 2 + 1) },
			{ Vector3.new(size.X + 4, height, 2), Vector3.new(0, 0, -size.Z / 2 - 1) },
			{ Vector3.new(2, height, size.Z), Vector3.new(size.X / 2 + 1, 0, 0) },
			{ Vector3.new(2, height, size.Z), Vector3.new(-size.X / 2 - 1, 0, 0) },
		}
	do
		Kit.part({
			Name = "Wall",
			Size = w[1],
			Position = Vector3.new(origin.X, top + height / 2, origin.Z) + w[2],
			Color = style.WallColor,
			Material = style.WallMaterial,
		}, walls)
	end

	local spawns = Instance.new("Folder")
	spawns.Name = def.SpawnFolder
	spawns.Parent = model
	for i = 1, def.Spawns do
		local angle = (i / def.Spawns) * math.pi * 2
		Kit.holder(
			"Spawn",
			CFrame.new(
				origin
					+ Vector3.new(
						math.cos(angle) * def.SpawnRadius,
						size.Y,
						math.sin(angle) * def.SpawnRadius
					)
			),
			Vector3.new(4, 1, 4),
			spawns
		)
	end

	local hotspots = Instance.new("Folder")
	hotspots.Name = "Hotspots"
	hotspots.Parent = model

	-- The world outside the walls (ground to the horizon, hills, trees, wall posts).
	MapScenery.Build(def, style, Vector3.new(origin.X, top, origin.Z), size, model)

	Kit.ambientParticles(
		Vector3.new(origin.X, top, origin.Z),
		Vector3.new(size.X, 0, size.Z),
		def.Particles,
		model
	)

	return {
		Def = def,
		Model = model,
		Rng = Random.new(def.Seed),
		Origin = Vector3.new(origin.X, top, origin.Z),
		Half = Vector2.new(size.X / 2, size.Z / 2),
		Hotspots = hotspots,
	}
end

-- A point on the floor top at map offset (x, z).
function MapBase.at(ctx: Ctx, x: number, z: number, y: number?): Vector3
	return ctx.Origin + Vector3.new(x, y or 0, z)
end

-- Marks an area (centre offset, footprint) where extra pumpkins spawn.
function MapBase.hotspot(ctx: Ctx, offset: Vector3, size: Vector3)
	Kit.holder(
		"Hotspot",
		CFrame.new(MapBase.at(ctx, offset.X, offset.Z, 0.5)),
		Vector3.new(size.X, 1, size.Z),
		ctx.Hotspots
	)
end

return MapBase
