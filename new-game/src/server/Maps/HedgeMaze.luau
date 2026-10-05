--!strict
--[[
	"Hedge Maze" map builder (settings: src/shared/Config/Maps/HedgeMaze.luau).
	For now this is a plain placeholder: a floor, the walls around the edge and the spawn
	ring from MapBase, so the game never breaks if this map is picked.
	TODO(hide & seek agent): build the real layout here.
]]

local MapBase = require(script.Parent.MapBase)

local HedgeMaze = {}

function HedgeMaze.Build(def: any): Model
	local colors = def.Colors
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Pebble,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.LeafyGrass,
	})
	return ctx.Model
end

return HedgeMaze
