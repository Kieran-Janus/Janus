--!strict
-- Top bar: round state + timer, map/difficulty, and this round's pumpkin count.
-- Reads attributes the server sets; no remotes needed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Hud = {}

function Hud.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer

	local bar = Theme.panel(gui)
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.02)
	bar.Size = UDim2.fromOffset(380, 64)

	local title = Theme.label(Config.Game.Name, 22, bar)
	title.Size = UDim2.new(1, 0, 0, 36)

	local detail = Theme.label("", 15, bar)
	detail.TextColor3 = Theme.Muted
	detail.Position = UDim2.fromOffset(0, 34)
	detail.Size = UDim2.new(1, 0, 0, 24)

	local function refresh()
		local state = ReplicatedStorage:GetAttribute("State") or "Loading"
		local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
		if timeLeft > 0 then
			title.Text = ("%s  %d:%02d"):format(state, timeLeft // 60, timeLeft % 60)
		else
			title.Text = tostring(state)
		end

		local mapName = ReplicatedStorage:GetAttribute("MapName")
		local difficulty = ReplicatedStorage:GetAttribute("Difficulty")
		local parts = {}
		if mapName then
			table.insert(parts, mapName)
		end
		if difficulty then
			table.insert(parts, difficulty)
		end
		if state == "Playing" then
			table.insert(parts, ("Pumpkins: %d"):format(player:GetAttribute("Pumpkins") or 0))
		end
		detail.Text = if #parts > 0 then table.concat(parts, "  |  ") else Config.Game.Name
	end

	for _, name in { "State", "TimeLeft", "MapName", "Difficulty" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Pumpkins"):Connect(refresh)
	refresh()
end

return Hud
