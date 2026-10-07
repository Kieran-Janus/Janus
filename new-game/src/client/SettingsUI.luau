--!strict
--[[
	Settings (a tile in the Menu) with Music and Sounds on/off toggles.
	The choice is saved on the server (SfxService, SetSetting) and comes back as the player
	attributes SettingMusic / SettingSounds, which src/client/Sounds.luau applies.
	Each toggle is a row with a sliding On/Off switch; buttons squash when pressed and the
	switch springs across (src/client/ShopJuice.luau, Config.Shop.Juice; Animate = false there
	makes it change instantly).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local ShopJuice = require(script.Parent.ShopJuice)
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
	ShopJuice.Press(b)
	return b
end

local ON_COLOUR = Color3.fromRGB(60, 160, 70)
local OFF_COLOUR = Color3.fromRGB(90, 85, 105)

function SettingsUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local setSetting = Remotes.Event("SetSetting")

	local open = Layout.SideButton("Settings", 1)
	open.Name = "SettingsButton"

	local panel = Theme.panel(gui)
	panel.Name = "Settings"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 200)
	panel.ZIndex = 10
	panel.BackgroundTransparency = 0.03
	panel.Visible = false
	Layout.Fit(panel)

	local title = Theme.label("Settings", 22, panel)
	title.Size = UDim2.new(1, 0, 0, 44)

	local function isOn(key: string): boolean
		return player:GetAttribute("Setting" .. key) ~= false
	end

	-- Each row: the setting's name on the left, an On/Off switch on the right.
	type Row = { Key: string, Button: TextButton, Track: Frame, Knob: TextLabel, Label: string }
	local toggles: { [string]: Row } = {}
	local function refresh()
		local animate = ShopJuice.On() and panel.Visible
		local time = Config.Shop.Juice.BounceTime
		for _, row in toggles do
			local on = isOn(row.Key)
			row.Button.Text = "  " .. row.Label
			row.Knob.Text = if on then "On" else "Off"
			local spot = if on then UDim2.new(1, -48, 0.5, 0) else UDim2.new(0, 2, 0.5, 0)
			local colour = if on then ON_COLOUR else OFF_COLOUR
			if animate and row.Knob.Position ~= spot then
				ShopJuice.Tween(row.Knob, time, { Position = spot }, Enum.EasingStyle.Back)
				ShopJuice.Tween(row.Track, time, { BackgroundColor3 = colour })
			else
				row.Knob.Position = spot
				row.Track.BackgroundColor3 = colour
			end
		end
	end

	for i, t in TOGGLES do
		local b = button("", panel)
		b.Name = t.Key .. "Toggle"
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Position = UDim2.fromOffset(20, 50 + (i - 1) * 50)
		b.Size = UDim2.new(1, -40, 0, 42)
		local track = Instance.new("Frame")
		track.Name = "Switch"
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, -8, 0.5, 0)
		track.Size = UDim2.fromOffset(84, 30)
		track.BorderSizePixel = 0
		track.Parent = b
		Theme.round(track, 15)
		local knob = Theme.label("", 14, track)
		knob.Name = "Knob"
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Size = UDim2.fromOffset(46, 26)
		knob.BackgroundTransparency = 0
		knob.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
		knob.TextColor3 = Theme.Background
		Theme.round(knob, 13)
		toggles[t.Key] = { Key = t.Key, Button = b, Track = track, Knob = knob, Label = t.Label }
		b.Activated:Connect(function()
			local on = not isOn(t.Key)
			-- Apply right away; the server saves it and confirms with the same attribute.
			player:SetAttribute("Setting" .. t.Key, on)
			setSetting:FireServer(t.Key, on)
			refresh()
		end)
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
