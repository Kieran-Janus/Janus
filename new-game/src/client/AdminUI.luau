--!strict
--[[
	Owner-only test panel (server: AdminService). Press Config.Admin.OpenKey (F8) in a Studio
	playtest. Only shows for players the server marked with the "Admin" attribute; every
	button is re-checked on the server.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local AdminUI = {}

local COMMANDS = {
	{ Name = "AddCoins", Label = "+ Coins" },
	{ Name = "UnlockAll", Label = "Unlock all items" },
	{ Name = "ResetDaily", Label = "Reset daily reward" },
	{ Name = "RebuildHub", Label = "Rebuild hub" },
	{ Name = "ResetSave", Label = "Reset my save" },
}

local function build(gui: ScreenGui): Frame
	local adminCommand = Remotes.Function("AdminCommand")
	local panel = Theme.panel(gui)
	panel.Name = "Admin"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(220, 60 + #COMMANDS * 44 + 40)
	panel.Visible = false
	Layout.Fit(panel)
	local title = Theme.label(("Admin (%s)"):format(Config.Admin.OpenKey.Name), 18, panel)
	title.Size = UDim2.new(1, 0, 0, 40)
	local status = Theme.label("", 13, panel)
	status.TextColor3 = Theme.Muted
	status.TextWrapped = true
	status.Position = UDim2.new(0, 10, 1, -42)
	status.Size = UDim2.new(1, -20, 0, 36)
	for i, command in COMMANDS do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(12, 44 + (i - 1) * 44)
		b.Size = UDim2.new(1, -24, 0, 36)
		b.BackgroundColor3 = if command.Name == "ResetSave"
			then Color3.fromRGB(140, 40, 40)
			else Theme.Button
		b.TextColor3 = Theme.Text
		b.Font = Theme.Font
		b.TextSize = 15
		b.Text = command.Label
		b.Parent = panel
		Theme.round(b, 8)
		local armed = false
		b.Activated:Connect(function()
			if command.Name == "ResetSave" and not armed then
				armed = true
				b.Text = "Click again to reset"
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
	return panel
end

function AdminUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local panel: Frame? = nil
	local function ensure(): Frame?
		if not player:GetAttribute("Admin") then
			return nil
		end
		if not panel then
			panel = build(gui)
		end
		return panel
	end
	local function toggle()
		local p = ensure()
		if p then
			p.Visible = not p.Visible
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
