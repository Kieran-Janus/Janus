--!strict
--[[
	Settings (a tile in the Menu) with Music and Sounds on/off toggles.
	The choice is saved on the server (SfxService, SetSetting) and comes back as the player
	attributes SettingMusic / SettingSounds, which src/client/Sounds.luau applies.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local SettingsUI = {}

local TOGGLES = {
	{ Key = "Music", Label = "Music" },
	{ Key = "Sounds", Label = "Sounds" },
}

local function button(text: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Button
	b.TextColor3 = Theme.Text
	b.Font = Theme.Font
	b.TextSize = 16
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.round(b)
	return b
end

function SettingsUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local setSetting = Remotes.Event("SetSetting")

	local open = Layout.SideButton("Settings", 1)
	open.Name = "SettingsButton"

	local panel = Theme.panel(gui)
	panel.Name = "Settings"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 190)
	panel.ZIndex = 10
	panel.BackgroundTransparency = 0.03
	panel.Visible = false
	Layout.Fit(panel)

	local title = Theme.label("Settings", 22, panel)
	title.Size = UDim2.new(1, 0, 0, 44)

	local function isOn(key: string): boolean
		return player:GetAttribute("Setting" .. key) ~= false
	end

	local toggles: { [string]: TextButton } = {}
	local function refresh()
		for key, b in toggles do
			local on = isOn(key)
			local label = ""
			for _, t in TOGGLES do
				if t.Key == key then
					label = t.Label
				end
			end
			b.Text = ("%s: %s"):format(label, if on then "On" else "Off")
			b.BackgroundColor3 = if on then Theme.Selected else Theme.Button
		end
	end

	for i, t in TOGGLES do
		local b = button("", panel)
		b.Position = UDim2.new(0, 20, 0, 44 + (i - 1) * 50)
		b.Size = UDim2.new(1, -40, 0, 42)
		b.Activated:Connect(function()
			local on = not isOn(t.Key)
			-- Apply right away; the server saves it and confirms with the same attribute.
			player:SetAttribute("Setting" .. t.Key, on)
			setSetting:FireServer(t.Key, on)
			refresh()
		end)
		toggles[t.Key] = b
		player:GetAttributeChangedSignal("Setting" .. t.Key):Connect(refresh)
	end

	local close = button("Close", panel)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -12)
	close.Size = UDim2.fromOffset(120, 34)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	refresh()
end

return SettingsUI
