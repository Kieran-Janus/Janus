--!strict
--[[
	The Menu's sums (settings in Config.Menu), kept apart from the screen code so they can
	be tested without Studio (tests/specs/Menu.spec.luau). Nothing here touches the screen.

	MenuLogic.TileId(text) -> string
	    the tile id for a Layout.SideButton: its first word ("Shop (B)" -> "Shop")
	MenuLogic.Resolve(id, label, order?, icon?, color?) -> Resolved
	    a tile's words, icon, colour and position. A tile listed in Config.Menu.Tiles takes
	    its Text, Icon, Color and place from there; any other tile goes after the listed ones.
	MenuLogic.Grid(screen, tileCount) -> Grid
	    how many tiles per row, how wide each is, and the panel size, for a screen size in
	    UI units (Layout.Screen())
	MenuLogic.ButtonPlace(hudLeft?, hudBottom?) -> Place
	    where the Menu button goes so it never covers the bar at the top middle (the Hud):
	    the whole button if it fits beside the Hud, else just its icon, else the whole
	    button just below the Hud. hudLeft/hudBottom are the Hud's left and bottom edges in
	    UI units (nil = no Hud on screen yet)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MenuLogic = {}

export type Resolved = {
	Label: string,
	Icon: string,
	Color: Color3?,
	Order: number,
	Feature: string?,
	Hidden: boolean,
}

export type Grid = {
	Columns: number,
	Cell: number,
	TileHeight: number,
	Width: number,
	Height: number,
}

export type Place = { Mode: string, X: number, Y: number, Width: number, Height: number }

-- Tiles that aren't listed in Config.Menu.Tiles come after the listed ones.
local UNLISTED = 1000

-- Room left around the tiles inside their scrolling area, so their borders aren't cut off.
MenuLogic.TileInset = 3

function MenuLogic.TileId(text: string): string
	return text:match("%w+") or text
end

function MenuLogic.Resolve(
	id: string,
	label: string,
	order: number?,
	icon: string?,
	color: Color3?
): Resolved
	for index, entry in Config.Menu.Tiles do
		if entry.Id == id then
			return {
				Label = if entry.Text ~= "" then entry.Text else label,
				Icon = entry.Icon,
				Color = entry.Color or color,
				Order = index,
				Feature = entry.Feature,
				Hidden = entry.Hidden == true,
			}
		end
	end
	return {
		Label = label,
		Icon = icon or "",
		Color = color,
		Order = UNLISTED + (order or 0),
		Feature = nil,
		Hidden = false,
	}
end

function MenuLogic.Grid(screen: Vector2, tileCount: number): Grid
	local p = Config.Menu.Panel
	local margin = Config.UI.EdgeMargin
	local inset = MenuLogic.TileInset
	local function layout(maxWidth: number, maxColumns: number): (number, number, number, number)
		local widest = math.min(screen.X - 2 * margin, maxWidth)
		local inner = widest - 2 * p.Padding - p.ScrollBar - 2 * inset
		local columns = math.floor((inner + p.TileGap) / (p.TileMinWidth + p.TileGap))
		columns = math.clamp(columns, 1, maxColumns)
		local cell = math.floor((inner - p.TileGap * (columns - 1)) / columns)
		cell = math.clamp(cell, 1, p.TileMaxWidth)
		local width = columns * cell
			+ (columns - 1) * p.TileGap
			+ 2 * (p.Padding + inset)
			+ p.ScrollBar
		return columns, cell, width, math.max(1, math.ceil(tileCount / columns))
	end
	local function rowsHeight(rows: number, tileHeight: number): number
		return rows * tileHeight + (rows - 1) * p.TileGap
	end
	local tallest = math.min(p.MaxHeight, screen.Y - 2 * margin)
	local room = tallest - p.HeaderHeight - p.FooterHeight - 2 * inset -- for the rows of tiles
	local columns, cell, width, rows = layout(p.MaxWidth, p.MaxColumns)
	-- A short screen: more tiles per row (the whole screen width) if that saves a row...
	if rowsHeight(rows, p.TileHeight) > room then
		local wideColumns, wideCell, wideWidth, wideRows =
			layout(math.huge, p.ShortScreenMaxColumns)
		if wideRows < rows then
			columns, cell, width, rows = wideColumns, wideCell, wideWidth, wideRows
		end
	end
	-- ...then shorter tiles. Still too many: the tiles scroll.
	local tileHeight = p.TileHeight
	if rowsHeight(rows, tileHeight) > room then
		local fit = math.floor((room - (rows - 1) * p.TileGap) / rows)
		tileHeight = math.clamp(fit, p.TileMinHeight, p.TileHeight)
	end
	local tilesHeight = rowsHeight(rows, tileHeight) + 2 * inset
	local height = math.min(p.HeaderHeight + tilesHeight + p.FooterHeight, tallest)
	return {
		Columns = columns,
		Cell = cell,
		TileHeight = tileHeight,
		Width = width,
		Height = math.max(height, 1),
	}
end

function MenuLogic.ButtonPlace(hudLeft: number?, hudBottom: number?): Place
	local b = Config.Menu.Button
	local full = { Mode = "Full", X = b.Left, Y = b.Top, Width = b.Width, Height = b.Height }
	if hudLeft == nil or b.Left + b.Width + b.Gap <= hudLeft then
		return full
	end
	if b.Left + b.IconWidth + b.Gap <= hudLeft then
		return { Mode = "Icon", X = b.Left, Y = b.Top, Width = b.IconWidth, Height = b.Height }
	end
	full.Y = math.max(b.Top, (hudBottom or 0) + b.Gap)
	return full
end

return MenuLogic
