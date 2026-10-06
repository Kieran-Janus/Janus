--!strict
--[[
	Owner-only test panel (server: AdminService). Press Config.Admin.OpenKey (F8) in a Studio
	playtest. Only shows for players the server marked with the "Admin" attribute; every
	button is re-checked on the server. The buttons come from the server's command list
	(GetAdminCommands), so a service that registers a command gets a button automatically;
	the list scrolls when there are many.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local AdminUI = {}

type CommandInfo = { Name: string, Label: string, Danger: boolean }
type Panel = { Frame: Frame, Reload: () -> () }

local BUTTON_HEIGHT = 36
local BUTTON_GAP = 8
local MAX_LIST_HEIGHT = 360 -- more buttons than fit here scroll

local function build(gui: ScreenGui): Panel
	local adminCommand = Remotes.Function("AdminCommand")
	local getCommands = Remotes.Function("GetAdminCommands")
	local panel = Theme.panel(gui)
	panel.Name = "Admin"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(220, 140)
	panel.Visible = false
	Layout.Fit(panel)
	local title = Theme.label(("Admin (%s)"):format(Config.Admin.OpenKey.Name), 18, panel)
	title.Size = UDim2.new(1, 0, 0, 40)
	local status = Theme.label("", 13, panel)
	status.TextColor3 = Theme.Muted
	status.TextWrapped = true
	status.Position = UDim2.new(0, 10, 1, -42)
	status.Size = UDim2.new(1, -20, 0, 36)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Commands"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 44)
	list.Size = UDim2.new(1, -24, 1, -92)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, BUTTON_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local function addButton(command: CommandInfo, index: number)
		local b = Instance.new("TextButton")
		b.Name = command.Name
		b.LayoutOrder = index
		b.Size = UDim2.new(1, -8, 0, BUTTON_HEIGHT) -- room for the scroll bar
		b.BackgroundColor3 = if command.Danger then Color3.fromRGB(140, 40, 40) else Theme.Button
		b.TextColor3 = Theme.Text
		b.Font = Theme.Font
		b.TextSize = 15
		b.TextScaled = true -- long labels shrink a little instead of running off both edges
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 15
		fit.MinTextSize = 11
		fit.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = b
		b.Text = command.Label
		b.Parent = list
		Theme.round(b, 8)
		local armed = false
		b.Activated:Connect(function()
			if command.Danger and not armed then
				armed = true
				b.Text = "Click again to confirm"
				task.delay(3, function()
					armed = false
					b.Text = command.Label
				end)
				return
			end
			armed = false
			b.Text = command.Label
			local ok, done, message = pcall(function()
				return adminCommand:InvokeServer(command.Name)
			end)
			status.Text = if ok then tostring(message) else "Request failed."
			status.TextColor3 = if ok and done then Theme.Selected else Theme.Muted
		end)
	end

	-- Asks the server for the current command list and rebuilds the buttons.
	local loading = false
	local function reload()
		if loading then
			return
		end
		loading = true
		task.spawn(function()
			local ok, result = pcall(function()
				return getCommands:InvokeServer()
			end)
			loading = false
			if not ok or typeof(result) ~= "table" then
				status.Text = "Couldn't load the commands."
				return
			end
			for _, child in list:GetChildren() do
				if child:IsA("GuiButton") then
					child:Destroy()
				end
			end
			local count = 0
			for _, command in result do
				if
					typeof(command) == "table"
					and typeof(command.Name) == "string"
					and typeof(command.Label) == "string"
				then
					count += 1
					addButton({
						Name = command.Name,
						Label = command.Label,
						Danger = command.Danger == true,
					}, count)
				end
			end
			local listHeight = math.min(count * (BUTTON_HEIGHT + BUTTON_GAP), MAX_LIST_HEIGHT)
			panel.Size = UDim2.fromOffset(220, 44 + listHeight + 48)
		end)
	end
	return { Frame = panel, Reload = reload }
end

function AdminUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local built: Panel? = nil
	local function toggle()
		if not player:GetAttribute("Admin") then
			return
		end
		local p = built or build(gui)
		built = p
		p.Frame.Visible = not p.Frame.Visible
		if p.Frame.Visible then
			p.Reload() -- commands can be registered at any time, so fetch the list each open
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Config.Admin.OpenKey then
			return
		end
		toggle()
	end)
	-- Touch screens have no F8: admins also get a small button in the top-right corner.
	local function addButton()
		if not player:GetAttribute("Admin") or gui:FindFirstChild("AdminButton") then
			return
		end
		local b = Instance.new("TextButton")
		b.Name = "AdminButton"
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -Config.UI.EdgeMargin, 0, Config.UI.PhoneSideTop)
		b.Size = UDim2.fromOffset(80, 34)
		b.BackgroundColor3 = Theme.Button
		b.TextColor3 = Theme.Text
		b.Font = Theme.Font
		b.TextSize = 15
		b.Text = "Admin"
		b.Visible = Layout.IsTouch()
		Theme.round(b)
		b.Parent = gui
		b.Activated:Connect(toggle)
	end
	player:GetAttributeChangedSignal("Admin"):Connect(addButton)
	addButton()
end

return AdminUI
