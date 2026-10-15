--!strict
--[[
	Builds the Crumbling Crypt's slab floor (used by the map builder
	src/server/Maps/CrumblingCrypt.luau and, for a Hard round, by src/server/Modes/TileFall.luau).

	TileFallBoard.Build(parent, gooTop, board, layers, tileSize, colors) -> Folder "Tiles"
	  gooTop    the middle of the goo's top surface (the slabs are centred over it)
	  board     the map's Board settings (Config/Maps/CrumblingCrypt.luau): Size, TopHeight,
	            LayerSpacing, Thickness, Gap
	  layers    how many layers (1 = only the top one)
	  tileSize  roughly how wide one slab is: Board.Size is split into whole slabs
	  colors    the map's Colors (Slab = one colour per layer)
	Folder "Tiles" holds one Folder per layer ("Layer1" = the top) of Parts named "Slab", each
	tagged TileFallTile with the attribute Layer. The folder remembers how it was built
	(attributes BoardBuilt, Layers, TileSize, GooTop) so the mode can rebuild it for another
	difficulty. Every layer's top is at the same height whatever the difficulty: the top layer
	is always Board.TopHeight above the goo, the next one LayerSpacing lower, and so on.

	TileFallBoard.LayerTop(gooTopY, board, layer) -> number   the top surface of a layer
	TileFallBoard.Count(board, tileSize) -> number            slabs along one side
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)

local TileFallBoard = {}

export type Board = {
	Size: number,
	TopHeight: number,
	LayerSpacing: number,
	Thickness: number,
	Gap: number,
}

TileFallBoard.FolderName = "Tiles"

function TileFallBoard.LayerTop(gooTopY: number, board: Board, layer: number): number
	return gooTopY + board.TopHeight - (layer - 1) * board.LayerSpacing
end

function TileFallBoard.Count(board: Board, tileSize: number): number
	return math.max(2, math.floor(board.Size / math.max(tileSize, 1) + 0.5))
end

function TileFallBoard.Build(
	parent: Instance,
	gooTop: Vector3,
	board: Board,
	layers: number,
	tileSize: number,
	colors: any
): Folder
	local folder = Kit.group(TileFallBoard.FolderName, parent)
	folder:SetAttribute("BoardBuilt", true)
	folder:SetAttribute("Layers", layers)
	folder:SetAttribute("TileSize", tileSize)
	folder:SetAttribute("GooTop", gooTop)
	local count = TileFallBoard.Count(board, tileSize)
	local pitch = board.Size / count
	local width = math.max(pitch - board.Gap, 1)
	local slabColors: { Color3 } = colors.Slab
	for layer = 1, math.max(1, layers) do
		local layerFolder = Kit.group("Layer" .. layer, folder)
		local top = TileFallBoard.LayerTop(gooTop.Y, board, layer)
		local base = slabColors[math.min(layer, #slabColors)] or Color3.fromRGB(120, 115, 125)
		for ix = 1, count do
			for iz = 1, count do
				local x = -board.Size / 2 + (ix - 0.5) * pitch
				local z = -board.Size / 2 + (iz - 0.5) * pitch
				-- A checker of slightly lighter and darker slabs (worked out, not random, so
				-- every build is the same).
				local shade = (((ix * 7 + iz * 13 + layer * 3) % 5) - 2) * 0.035
				local slab = Kit.part({
					Name = "Slab",
					Size = Vector3.new(width, board.Thickness, width),
					Position = Vector3.new(gooTop.X + x, top - board.Thickness / 2, gooTop.Z + z),
					Color = Kit.shade(base, shade),
					Material = Enum.Material.Slate,
				}, layerFolder)
				slab:SetAttribute("Layer", layer)
				CollectionService:AddTag(slab, Tags.TileFallTile)
			end
		end
	end
	return folder
end

return TileFallBoard
