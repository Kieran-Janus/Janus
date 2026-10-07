--!strict
--[[
	One big panel at a time. Opening one of the centred panels (Menu, Shop, Settings,
	Codes, Crates...) closes whichever of them was open, and Escape (or B on a gamepad)
	closes the open one. Panels still open and close the normal way (Visible = true/false);
	this only watches them.

	PanelManager.Mount(gui)        Main.client.luau calls this once, right after Layout.
	PanelManager.Register(panel)   add a panel (safe to call twice, or before Mount).
	PanelManager.CloseTop() -> boolean
	                               closes the panel opened last (false if none is open)
	PanelManager.CloseAll()
	PanelManager.Top() -> GuiObject?   the open panel, if any

	Direct children of the game UI named in AUTO_NAMES are added automatically, so a module
	only has to give its panel one of these names. Small panels along the edges (Vote, Ghost,
	NpcDialog, EmoteBar, Hud, Admin) are left alone on purpose.

	Escape: Roblox keeps the Escape key for its own menu, so when that menu opens (Escape or
	its top-bar button) the open panel closes too; in Studio the key itself also works.

	Motion (src/client/UIMotion.luau, Config.UI.Motion): a registered panel pops in whenever it
	becomes visible. Closing (Escape, CloseTop, CloseAll, another panel opening, or the panel's
	own code setting Visible = false) still hides it AT ONCE, so every `Visible` check stays
	true to what the player can use; what shrinks away is a short-lived copy of it (a "ghost",
	in the ScreenGui PanelGhosts beside the game UI, no clicks) that removes itself.
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIMotion = require(script.Parent.UIMotion)

local PanelManager = {}

local AUTO_NAMES = { "Menu", "Shop", "Settings", "Codes", "Crates" }
local CLOSE_ACTION = "CloseTopPanel"
local ESCAPE_REPEAT = 0.3 -- one Escape press can arrive twice (key + Roblox menu): close once

local registered: { [GuiObject]: boolean } = {}
local openOrder: { GuiObject } = {} -- the open managed panels, last opened at the end
local bound = false
local lastEscape = 0
-- An invisible Modal button, shown while a panel is open: it frees the mouse when the camera
-- is zoomed into first person (where Roblox locks it to the middle of the screen).
local cursor: TextButton? = nil

local function forget(panel: GuiObject)
	local index = table.find(openOrder, panel)
	if index then
		table.remove(openOrder, index)
	end
end

-- Gamepad B closes the open panel, only while one is open (B does other things otherwise).
local function updateBinding()
	local want = #openOrder > 0
	if cursor then
		cursor.Visible = want
	end
	-- Touch screens: Roblox's round action buttons (Run, HEY!) draw over panels; hide them
	-- while one is open (nobody runs or shouts from a menu).
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local actions = playerGui and playerGui:FindFirstChild("ContextActionGui")
	if actions and actions:IsA("ScreenGui") then
		actions.Enabled = not want
	end
	if want and not bound then
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				PanelManager.CloseTop()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
		bound = true
	elseif not want and bound then
		ContextActionService:UnbindAction(CLOSE_ACTION)
		bound = false
	end
end

local ghostGui: ScreenGui? = nil
local ghosts: { [GuiObject]: GuiObject } = {}

-- The ScreenGui the ghosts shrink in: a twin of the panel's ScreenGui (same insets and scale),
-- drawn just under it, so a test or module looking through the game UI never finds a ghost.
local function ghostLayer(panel: GuiObject): ScreenGui?
	local screen = panel:FindFirstAncestorOfClass("ScreenGui")
	if not (screen and screen.Parent and panel.Parent == screen) then
		return nil
	end
	local layer = ghostGui
	if not layer or layer.Parent ~= screen.Parent then
		if layer then
			layer:Destroy()
		end
		local made = Instance.new("ScreenGui")
		made.Name = "PanelGhosts"
		made.ResetOnSpawn = false
		made.Parent = screen.Parent
		Instance.new("UIScale").Parent = made
		ghostGui = made
		layer = made
	end
	assert(layer, "a layer was just made")
	layer.ScreenInsets = screen.ScreenInsets
	layer.IgnoreGuiInset = screen.IgnoreGuiInset
	layer.ZIndexBehavior = screen.ZIndexBehavior
	layer.DisplayOrder = screen.DisplayOrder - 1
	local scale = layer:FindFirstChildOfClass("UIScale")
	local screenScale = screen:FindFirstChild("ScreenScale")
	if scale then
		scale.Scale = if screenScale and screenScale:IsA("UIScale") then screenScale.Scale else 1
	end
	return layer
end

local function clearGhost(panel: GuiObject)
	local ghost = ghosts[panel]
	ghosts[panel] = nil
	if ghost then
		ghost:Destroy()
	end
end

local function animateVisible(panel: GuiObject)
	if panel.Visible then
		clearGhost(panel)
		UIMotion.PopIn(panel)
		return
	end
	clearGhost(panel)
	local layer = ghostLayer(panel)
	local ghost = layer and UIMotion.Ghost(panel, layer)
	if ghost then
		ghosts[panel] = ghost
		ghost.Destroying:Once(function()
			if ghosts[panel] == ghost then
				ghosts[panel] = nil
			end
		end)
	end
end

local function onVisibleChanged(panel: GuiObject, animate: boolean)
	if animate then
		animateVisible(panel)
	end
	if panel.Visible then
		-- Close the panels that were already open. A panel opened in this same moment isn't
		-- in the list yet: it closes this one when its own turn comes, so the last one wins.
		for _, other in table.clone(openOrder) do
			if other ~= panel then
				forget(other)
				other.Visible = false
			end
		end
		forget(panel)
		table.insert(openOrder, panel)
	else
		forget(panel)
	end
	updateBinding()
end

function PanelManager.Register(panel: GuiObject)
	if registered[panel] then
		return
	end
	registered[panel] = true
	local changed = panel:GetPropertyChangedSignal("Visible"):Connect(function()
		onVisibleChanged(panel, true)
	end)
	panel.Destroying:Once(function()
		changed:Disconnect()
		registered[panel] = nil
		clearGhost(panel)
		forget(panel)
		updateBinding()
	end)
	if panel.Visible then
		onVisibleChanged(panel, false) -- already open: no pop
	end
end

function PanelManager.Top(): GuiObject?
	return openOrder[#openOrder]
end

function PanelManager.CloseTop(): boolean
	local top = openOrder[#openOrder]
	if not top then
		return false
	end
	forget(top)
	top.Visible = false
	updateBinding()
	return true
end

function PanelManager.CloseAll()
	while #openOrder > 0 do
		PanelManager.CloseTop()
	end
end

local function escape()
	local now = os.clock()
	if now - lastEscape < ESCAPE_REPEAT then
		return
	end
	lastEscape = now
	PanelManager.CloseTop()
end

function PanelManager.Mount(gui: ScreenGui)
	local free = Instance.new("TextButton")
	free.Name = "PanelCursor"
	free.Modal = true
	free.Text = ""
	free.BackgroundTransparency = 1
	free.Size = UDim2.fromOffset(0, 0)
	free.Visible = #openOrder > 0
	free.Parent = gui
	cursor = free

	local function consider(child: Instance)
		if child:IsA("GuiObject") and table.find(AUTO_NAMES, child.Name) then
			PanelManager.Register(child)
		end
	end
	for _, child in gui:GetChildren() do
		consider(child)
	end
	gui.ChildAdded:Connect(function(child)
		consider(child)
		-- Theme.panel(gui) parents the panel before its module names it: look again once
		-- that code has finished.
		task.defer(function()
			if child.Parent == gui then
				consider(child)
			end
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- processed = Escape only left a text box (chat, the Codes box): keep the panel
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			escape()
		end
	end)
	GuiService.MenuOpened:Connect(escape)
end

return PanelManager
