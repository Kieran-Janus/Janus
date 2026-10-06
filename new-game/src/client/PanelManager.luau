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
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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

local function onVisibleChanged(panel: GuiObject)
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
		onVisibleChanged(panel)
	end)
	panel.Destroying:Once(function()
		changed:Disconnect()
		registered[panel] = nil
		forget(panel)
		updateBinding()
	end)
	if panel.Visible then
		onVisibleChanged(panel)
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
