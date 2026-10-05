--!strict
--[[
	The top-left Menu (settings in Config.Menu; on/off: Config.Features.Menu).
	One big Menu button (or the M key) opens a grid of tiles: Skins, Shop, Crates, Vote,
	Spectate, Invite, Codes, Settings, VIP & Packs and the Parkour / secret pumpkin progress.
	Clicking a tile closes the menu and opens what it names. Only one big panel shows at a
	time (src/client/PanelManager.luau), and Escape closes it.

	MenuUI.Mount(gui)
	MenuUI.AddTile(def)        adds a tile, or replaces the tile with the same Id. Safe to call
	                           before Mount. def = {
	    Id = "CandyRush",                -- also its line in Config.Menu.Tiles, if it has one
	    Label = "Candy Rush",            -- the words (a Config.Menu.Tiles line's Text wins)
	    Order = 20,                      -- its place, when Config.Menu.Tiles doesn't list it
	    Icon = "🍬", Color = Color3,      -- optional (Config.Menu.Tiles wins here too)
	    Visible = function() return true end,      -- optional: shown only while this says true
	    Status = function() return "3/10" end,     -- optional: a small badge on the tile
	    DynamicLabel = function() return nil end,  -- optional: other words for now (nil = Label)
	    KeepOpen = true,                 -- optional: the menu stays open; OnClick decides
	    OnClick = function() ... end,
	}
	MenuUI.Open()  MenuUI.Close()  MenuUI.Toggle()  MenuUI.IsOpen() -> boolean
	MenuUI.ShowMessage(text)   a line of text at the bottom of the open menu

	Panels that call Layout.SideButton (Shop, Settings, Codes, Invite) arrive here as tiles
	with no change to their own code: their click opens their panel and the menu closes.
	The other default tiles (Skins, Crates, Vote, Spectate, VIP...) are in MenuTiles.luau.
	This module requires no feature screen, so any screen can require it to add a tile.
	The Menu button never covers the bar at the top middle (the Hud): on narrow screens it
	shows just its icon, or sits below the Hud (src/client/MenuLogic.luau).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local MenuLogic = require(script.Parent.MenuLogic)
local PanelManager = require(script.Parent.PanelManager)
local Theme = require(script.Parent.Theme)

local MenuUI = {}

export type TileDef = {
	Id: string,
	Label: string,
	Order: number?,
	Icon: string?,
	Color: Color3?,
	Visible: (() -> boolean)?,
	Status: (() -> string?)?,
	DynamicLabel: (() -> string?)?,
	KeepOpen: boolean?,
	OnClick: () -> (),
}

type Tile = {
	Id: string,
	Button: TextButton,
	Def: TileDef?, -- nil for Layout.SideButton tiles (their own code handles the click)
	Info: MenuLogic.Resolved,
	Badge: TextLabel?,
}

type Ui = {
	Panel: Frame,
	Tiles: ScrollingFrame,
	Grid: UIGridLayout,
	Message: TextLabel,
}

local tiles: { [string]: Tile } = {}
local waitingDefs: { TileDef } = {} -- AddTile calls made before Mount
local ui: Ui? = nil

local function isShown(tile: Tile): boolean
	local info = tile.Info
	if info.Hidden then
		return false
	end
	if info.Feature and (Config.Features :: any)[info.Feature] ~= true then
		return false
	end
	local def = tile.Def
	if def and def.Visible then
		local ok, result = pcall(def.Visible)
		return ok and result == true
	end
	return true
end

local function makeBadge(tile: Tile): TextLabel
	local label = Theme.label("", 14, tile.Button)
	label.Name = "Badge"
	label.ZIndex = 2 -- above the icon
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, 0, 0, -2)
	label.Size = UDim2.fromOffset(0, 20)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundColor3 = Theme.Selected
	label.BackgroundTransparency = 0
	Theme.round(label, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = label
	tile.Badge = label
	return label
end

-- Small coloured badge in the tile's top-right corner ("3/10"); nil or "" hides it.
local function setBadge(tile: Tile, text: string?)
	if text == nil or text == "" then
		if tile.Badge then
			tile.Badge.Visible = false
		end
		return
	end
	local badge = tile.Badge or makeBadge(tile)
	badge.Text = text
	badge.Visible = true
end

-- Re-checks which tiles show (and their words and badges), then sizes the grid and panel.
local function refresh()
	local current = ui
	if not current then
		return
	end
	local count = 0
	for _, tile in tiles do
		local show = isShown(tile)
		tile.Button.Visible = show
		tile.Button.LayoutOrder = tile.Info.Order
		local def = tile.Def
		if not (show and def) then
			continue
		end
		if def.DynamicLabel then
			local ok, text = pcall(def.DynamicLabel)
			local now = if ok and type(text) == "string" and text ~= "" then text else nil
			tile.Button.Text = now or tile.Info.Label
		end
		if def.Status then
			local ok, text = pcall(def.Status)
			setBadge(tile, if ok and type(text) == "string" then text else nil)
		end
	end
	for _, tile in tiles do
		if tile.Button.Visible then
			count += 1
		end
	end
	local grid = MenuLogic.Grid(Layout.Screen(), count)
	current.Grid.CellSize = UDim2.fromOffset(grid.Cell, Config.Menu.Panel.TileHeight)
	current.Panel.Size = UDim2.fromOffset(grid.Width, grid.Height)
end

local function keyHint(): string
	if Layout.IsTouch() then
		return ""
	end
	return Config.Menu.Text.KeyHint:format(Config.Menu.Key.Name, Config.Shop.OpenKey.Name)
end

function MenuUI.Open()
	local current = ui
	if not current then
		return
	end
	current.Message.Text = keyHint()
	refresh()
	current.Panel.Visible = true
end

function MenuUI.Close()
	local current = ui
	if current then
		current.Panel.Visible = false
	end
end

function MenuUI.IsOpen(): boolean
	local current = ui
	return current ~= nil and current.Panel.Visible
end

function MenuUI.Toggle()
	if MenuUI.IsOpen() then
		MenuUI.Close()
	else
		MenuUI.Open()
	end
end

function MenuUI.ShowMessage(text: string)
	local current = ui
	if current then
		current.Message.Text = text
	end
end

-- Puts a tile in the grid (replacing an older tile with the same Id) and wires its click.
local function adopt(tile: Tile)
	local current = ui
	if not current then
		return
	end
	local old = tiles[tile.Id]
	if old and old.Button ~= tile.Button then
		old.Button:Destroy()
	end
	tiles[tile.Id] = tile
	tile.Button:SetAttribute("MenuTile", tile.Id)
	tile.Button.LayoutOrder = tile.Info.Order
	tile.Button.Activated:Connect(function()
		local def = tile.Def
		if not (def and def.KeepOpen) then
			MenuUI.Close()
		end
		if def then
			def.OnClick() -- an error here shows in Output and leaves the menu working
		end
	end)
	tile.Button.Parent = current.Tiles
	if current.Panel.Visible then
		refresh()
	end
end

local function build(def: TileDef)
	local info = MenuLogic.Resolve(def.Id, def.Label, def.Order, def.Icon, def.Color)
	local button = Layout.Tile(info.Label, info.Icon, info.Color)
	button.Name = def.Id .. "Tile"
	adopt({ Id = def.Id, Button = button, Def = def, Info = info, Badge = nil })
end

function MenuUI.AddTile(def: TileDef)
	if not Config.Features.Menu then
		return
	end
	if ui then
		build(def)
	else
		table.insert(waitingDefs, def)
	end
end

-- The big Menu button: a ☰ icon (three bars, so it draws whatever the font) and the word.
local function buildButton(gui: ScreenGui)
	local cfg = Config.Menu.Button
	local button = Theme.button("", gui, cfg.Color)
	button.Name = "MenuButton"
	button.ZIndex = 3 -- above the Hud and toasts, below every panel
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 12)
	end
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Color3.fromRGB(60, 25, 0)
	border.Thickness = 2
	border.Parent = button

	local bars = Instance.new("Frame")
	bars.Name = "Icon"
	bars.BackgroundTransparency = 1
	bars.AnchorPoint = Vector2.new(0.5, 0.5)
	bars.Size = UDim2.fromOffset(24, 18)
	bars.Parent = button
	for i = 0, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Theme.Text
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromOffset(0, i * 7)
		bar.Size = UDim2.new(1, 0, 0, 4)
		bar.Parent = bars
		Theme.round(bar, 2)
	end

	local label = Theme.label(Config.Menu.ButtonText, cfg.TextSize, button)
	label.Name = "Label"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeTransparency = 0.5
	label.Position = UDim2.fromOffset(46, 0)
	label.Size = UDim2.new(1, -50, 1, 0)

	-- Where the Hud's left and bottom edges are, in UI units (nil = no Hud showing).
	local function hudEdges(): (number?, number?)
		local hud = gui:FindFirstChild("Hud")
		if not (hud and hud:IsA("GuiObject") and hud.Visible and hud.AbsoluteSize.X > 0) then
			return nil, nil
		end
		local scale = Layout.Scale()
		local offset = hud.AbsolutePosition - gui.AbsolutePosition
		return offset.X / scale, (offset.Y + hud.AbsoluteSize.Y) / scale
	end

	local function place()
		local spot = MenuLogic.ButtonPlace(hudEdges())
		button.Position = UDim2.fromOffset(spot.X, spot.Y)
		button.Size = UDim2.fromOffset(spot.Width, spot.Height)
		local full = spot.Mode == "Full"
		label.Visible = full
		bars.Position = if full then UDim2.new(0, 26, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
	end

	local watched: Instance? = nil
	local function watchHud(child: Instance)
		if child == watched or child.Name ~= "Hud" or not child:IsA("GuiObject") then
			return
		end
		watched = child
		child:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		child:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		child:GetPropertyChangedSignal("Visible"):Connect(place)
		place()
	end
	local existing = gui:FindFirstChild("Hud")
	if existing then
		watchHud(existing)
	end
	gui.ChildAdded:Connect(function(child)
		-- Theme.panel parents the Hud before naming it: look once that code has finished.
		task.defer(watchHud, child)
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	button.Activated:Connect(MenuUI.Toggle)
end

function MenuUI.Mount(gui: ScreenGui)
	if not Config.Features.Menu then
		return
	end
	local player = Players.LocalPlayer
	local p = Config.Menu.Panel

	-- Panel -----------------------------------------------------------------------------------
	local panel = Theme.panel(gui)
	panel.Name = "Menu"
	panel.ZIndex = 11 -- above the Shop and Settings, below the round banners (12)
	panel.BackgroundTransparency = 0.03
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(p.MaxWidth, p.MaxHeight) -- set to fit the tiles on open
	panel.Visible = false
	Layout.Fit(panel)
	PanelManager.Register(panel)

	local title = Theme.label(p.Title, 22, panel)
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(p.Padding + 4, 8)
	title.Size = UDim2.new(1, -(p.Padding * 2 + 56), 0, p.HeaderHeight - 16)

	local close = Theme.button("X", panel)
	close.Name = "Close"
	close.TextSize = 18
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -p.Padding, 0, 8)
	close.Size = UDim2.fromOffset(44, p.HeaderHeight - 16)
	close.Activated:Connect(MenuUI.Close)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Tiles"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(p.Padding, p.HeaderHeight)
	list.Size = UDim2.new(1, -2 * p.Padding, 1, -(p.HeaderHeight + p.FooterHeight))
	list.ScrollBarThickness = p.ScrollBar
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local inset = Instance.new("UIPadding") -- room for the tiles' borders at the edges
	inset.PaddingTop = UDim.new(0, MenuLogic.TileInset)
	inset.PaddingBottom = UDim.new(0, MenuLogic.TileInset)
	inset.PaddingLeft = UDim.new(0, MenuLogic.TileInset)
	inset.PaddingRight = UDim.new(0, MenuLogic.TileInset)
	inset.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(p.TileMaxWidth, p.TileHeight)
	grid.CellPadding = UDim2.fromOffset(p.TileGap, p.TileGap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local message = Theme.label("", 15, panel)
	message.Name = "Message"
	message.TextColor3 = Theme.Muted
	message.TextWrapped = true
	message.AnchorPoint = Vector2.new(0, 1)
	message.Position = UDim2.new(0, p.Padding, 1, -6)
	message.Size = UDim2.new(1, -2 * p.Padding, 0, p.FooterHeight - 10)

	ui = { Panel = panel, Tiles = list, Grid = grid, Message = message }

	-- Tiles -----------------------------------------------------------------------------------
	Layout.SetMenuHost(function(tile: TextButton, id: string, order: number)
		local info = MenuLogic.Resolve(id, tile.Text, order)
		adopt({ Id = id, Button = tile, Def = nil, Info = info, Badge = nil })
	end)
	local waiting = waitingDefs
	waitingDefs = {}
	for _, def in waiting do
		build(def)
	end

	-- Button and keys -------------------------------------------------------------------------
	buildButton(gui)
	ContextActionService:BindAction("ToggleMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			MenuUI.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Config.Menu.Key)

	-- Keep the open menu right when the round or the screen changes.
	local function refreshIfOpen()
		if panel.Visible then
			refresh()
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(refreshIfOpen)
	player:GetAttributeChangedSignal("InRound"):Connect(refreshIfOpen)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshIfOpen)
end

return MenuUI
