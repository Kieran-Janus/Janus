--!strict
-- Minimal HUD: round state + timer. Reads attributes the server sets, no remotes needed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.02)
label.Size = UDim2.fromOffset(360, 44)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 22
label.Text = Config.Game.Name
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label

local function refresh()
	local state = ReplicatedStorage:GetAttribute("State") or "Loading"
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	label.Text = if timeLeft > 0 then ("%s  %ds"):format(state, timeLeft) else tostring(state)
end

ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(refresh)
refresh()
