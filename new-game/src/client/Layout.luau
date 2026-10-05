--!strict
--[[
	Screen layout for phones, tablets and PC (tunables in Config.UI).

	Layout.Mount(gui)          call once with the game's ScreenGui, before anything else
	Layout.SideButton(text, order) -> TextButton
	                           a button for a panel (Shop, Codes, Settings...). It is a tile in
	                           the top-left Menu (src/client/MenuUI.luau): its first word is the
	                           tile id, so Config.Menu.Tiles sets its words, icon and place.
	                           With the Menu switched off (Config.Features.Menu = false) it goes
	                           in the old side column instead: bottom-left on PC, top-left on
	                           touch screens. Lower order = higher.
	Layout.Tile(label, icon?, color?) -> TextButton
	                           a Menu tile: an emoji picture on top, the words underneath
	Layout.SetMenuHost(host)   MenuUI calls this once: SideButton tiles are handed to `host`
	                           (tiles made before that wait until it is called)
	Layout.Fit(panel, bottom?) shrinks a panel (UIScale) only when it doesn't fit the screen.
	                           bottom = true for panels along the bottom edge: on touch screens
	                           they also keep clear of the thumbstick (left) and jump button (right).
	Layout.Screen()            usable screen size in UI units
	Layout.IsTouch()           touch screen (phone or tablet)
	Layout.IsPhone()           touch screen shorter than Config.UI.PhoneMaxHeight (smaller buttons)

	The ScreenGui keeps Roblox's default ScreenInsets (CoreUISafeInsets), so nothing is drawn
	under the top bar. On big screens the whole UI scales up (never down: phones keep
	full-size, readable text). Testing: set the attribute ForceTouch = true on the gui to get
	the phone layout on a PC.
]]
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MenuLogic = require(script.Parent.MenuLogic)
local Theme = require(script.Parent.Theme)

local Layout = {}

-- Receives each SideButton tile: the tile, its id (first word of its text) and its order.
export type MenuHost = (tile: TextButton, id: string, order: number) -> ()

local root: GuiBase2d? = nil
local globalScale: UIScale? = nil
local sidebar: Frame? = nil
local sideList: UIListLayout? = nil
local sideButtons: { TextButton } = {}
local fitters: { () -> () } = {}
local menuHost: MenuHost? = nil
local waitingTiles: { { Tile: TextButton, Id: string, Order: number } } = {}

local function scaleValue(): number
	return if globalScale then globalScale.Scale else 1
end

-- How many screen pixels one UI unit is right now (the big-screen scale-up).
function Layout.Scale(): number
	return scaleValue()
end

function Layout.Screen(): Vector2
	if not root then
		return workspace.CurrentCamera.ViewportSize
	end
	return root.AbsoluteSize / scaleValue()
end

function Layout.IsTouch(): boolean
	return UserInputService.TouchEnabled
		or (root ~= nil and root:GetAttribute("ForceTouch") == true)
end

function Layout.IsPhone(): boolean
	return root ~= nil and Layout.IsTouch() and root.AbsoluteSize.Y < Config.UI.PhoneMaxHeight
end

local function styleSideButton(b: TextButton)
	local cfg = Config.UI.SideButton
	local phone = Layout.IsPhone()
	b.Size = UDim2.fromOffset(
		if phone then cfg.PhoneWidth else cfg.Width,
		if phone then cfg.PhoneHeight else cfg.Height
	)
end

local function placeSidebar()
	if not sidebar or not sideList then
		return
	end
	local ui = Config.UI
	if Layout.IsTouch() then
		sidebar.AnchorPoint = Vector2.new(0, 0)
		sidebar.Position = UDim2.fromOffset(ui.EdgeMargin, ui.PhoneSideTop)
		sideList.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		sidebar.AnchorPoint = Vector2.new(0, 1)
		sidebar.Position = UDim2.new(0, 16, 1, -90)
		sideList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	for _, b in sideButtons do
		styleSideButton(b)
	end
end

local function update()
	if not root or not globalScale then
		return
	end
	local height = root.AbsoluteSize.Y
	globalScale.Scale = math.clamp(height / Config.UI.ReferenceHeight, 1, Config.UI.MaxScale)
	placeSidebar()
	for _, fit in fitters do
		fit()
	end
end

function Layout.Mount(gui: GuiBase2d)
	root = gui
	local scale = Instance.new("UIScale")
	scale.Name = "ScreenScale"
	scale.Parent = gui
	globalScale = scale

	-- The old side column, only when the Menu is switched off (otherwise the buttons are
	-- tiles in the Menu).
	if not Config.Features.Menu then
		local column = Instance.new("Frame")
		column.Name = "SideButtons"
		column.BackgroundTransparency = 1
		column.Size = UDim2.fromOffset(Config.UI.SideButton.Width, 0)
		column.AutomaticSize = Enum.AutomaticSize.Y
		column.Parent = gui
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, Config.UI.SideButton.Gap)
		list.Parent = column
		sidebar = column
		sideList = list
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	gui:GetAttributeChangedSignal("ForceTouch"):Connect(update)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update)
	update()
end

-- A Menu tile: an emoji picture on top and the words underneath. Its size comes from the
-- Menu's grid.
function Layout.Tile(label: string, icon: string?, color: Color3?): TextButton
	local cfg = Config.Menu.Panel
	local tile = Theme.button(label, nil, color)
	tile.TextSize = cfg.TileTextSize
	tile.TextWrapped = true
	tile.TextYAlignment = Enum.TextYAlignment.Bottom
	tile.TextStrokeTransparency = 0.6
	local corner = tile:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 12)
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = tile
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Color3.new(1, 1, 1)
	border.Transparency = 0.8
	border.Thickness = 1.5
	border.Parent = tile
	if icon and icon ~= "" then
		local picture = Theme.label(icon, cfg.IconSize, tile)
		picture.Name = "Icon"
		-- Above the words (one line of text plus a little room).
		picture.Size = UDim2.new(1, 0, 1, -(cfg.TileTextSize + 10))
	end
	return tile
end

function Layout.SetMenuHost(host: MenuHost)
	menuHost = host
	local waiting = waitingTiles
	waitingTiles = {}
	for _, entry in waiting do
		host(entry.Tile, entry.Id, entry.Order)
	end
end

function Layout.SideButton(text: string, order: number): TextButton
	if Config.Features.Menu then
		local id = MenuLogic.TileId(text)
		local info = MenuLogic.Resolve(id, text, order)
		local tile = Layout.Tile(info.Label, info.Icon, info.Color)
		tile.Name = id .. "Button"
		if menuHost then
			menuHost(tile, id, order)
		else
			table.insert(waitingTiles, { Tile = tile, Id = id, Order = order })
		end
		return tile
	end
	local b = Instance.new("TextButton")
	b.Name = text:gsub("%W", "") .. "Button"
	b.LayoutOrder = order
	b.BackgroundColor3 = Theme.Button
	b.TextColor3 = Theme.Text
	b.Font = Theme.Font
	b.TextSize = 16
	b.Text = text
	b.AutoButtonColor = true
	Theme.round(b)
	styleSideButton(b)
	b.Parent = sidebar
	table.insert(sideButtons, b)
	return b
end

function Layout.Fit(panel: GuiObject, bottom: boolean?)
	local fitScale = Instance.new("UIScale")
	fitScale.Name = "FitScale"
	fitScale.Parent = panel
	local function fit()
		local screen = Layout.Screen()
		local total = scaleValue() * fitScale.Scale
		if total <= 0 then
			return
		end
		-- The panel's own (unscaled) size in UI units.
		local size = panel.AbsoluteSize / total
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local margin = Config.UI.EdgeMargin
		local sideClear = if bottom and Layout.IsTouch()
			then Config.UI.TouchBottomSideClear
			else margin
		local s = math.min(1, (screen.X - 2 * sideClear) / size.X, (screen.Y - 2 * margin) / size.Y)
		s = math.max(s, 0.3)
		if math.abs(fitScale.Scale - s) > 0.005 then
			fitScale.Scale = s
		end
	end
	table.insert(fitters, fit)
	panel.Destroying:Once(function()
		local index = table.find(fitters, fit)
		if index then
			table.remove(fitters, index)
		end
	end)
	panel:GetPropertyChangedSignal("Size"):Connect(fit)
	panel:GetPropertyChangedSignal("Visible"):Connect(fit)
	fit()
end

return Layout
