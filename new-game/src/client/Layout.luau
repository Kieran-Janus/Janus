--!strict
--[[
	Screen layout for phones, tablets and PC (tunables in Config.UI).

	Layout.Mount(gui)          call once with the game's ScreenGui, before anything else
	Layout.SideButton(text, order) -> TextButton
	                           a button in the shared side column: bottom-left on PC, top-left
	                           on touch screens (above Roblox's thumbstick). Lower order = higher.
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
local Theme = require(script.Parent.Theme)

local Layout = {}

local root: GuiBase2d? = nil
local globalScale: UIScale? = nil
local sidebar: Frame? = nil
local sideList: UIListLayout? = nil
local sideButtons: { TextButton } = {}
local fitters: { () -> () } = {}

local function scaleValue(): number
	return if globalScale then globalScale.Scale else 1
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

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	gui:GetAttributeChangedSignal("ForceTouch"):Connect(update)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update)
	update()
end

function Layout.SideButton(text: string, order: number): TextButton
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
