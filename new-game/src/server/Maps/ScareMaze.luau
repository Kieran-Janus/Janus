--!strict
--[[
	"ScareMaze" map builder (settings: src/shared/Config/Maps/ScareMaze.luau).
	For now this is a plain placeholder: a floor, the walls around the edge and the spawn
	ring from MapBase, so the game never breaks if this map is picked.
	TODO(scaremaze agent): build the real layout here.
]]

local MapBase = require(script.Parent.MapBase)

local ScareMaze = {}

function ScareMaze.Build(def: any): Model
	local colors = def.Colors
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Slate,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.Brick,
	})
	return ctx.Model
end

return ScareMaze
