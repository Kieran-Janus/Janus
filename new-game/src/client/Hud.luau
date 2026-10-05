--!strict
-- Top bar: round state + timer, map/difficulty, and this round's pumpkin count.
-- Reads attributes the server sets; no remotes needed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Hud = {}

local DETAIL_MAX_SIZE = 15
local DETAIL_MIN_SIZE = 10

function Hud.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer

	local bar = Theme.panel(gui)
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.02)
	bar.Size = UDim2.fromOffset(500, 64)

	local title = Theme.label(Config.Game.Name, 22, bar)
	title.Size = UDim2.new(1, 0, 0, 36)

	local detail = Theme.label("", 15, bar)
	detail.TextColor3 = Theme.Muted
	detail.Position = UDim2.fromOffset(10, 34)
	detail.Size = UDim2.new(1, -20, 0, 24)
	-- One line only: long lines (map + difficulty + counters) shrink to fit, and anything
	-- still too wide ends in "..." (TextScaled wrapped onto a second, cut-off line instead).
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	local function fitDetail()
		local width = detail.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local size = DETAIL_MAX_SIZE
		while
			size > DETAIL_MIN_SIZE
			and TextService:GetTextSize(
					detail.Text,
					size,
					detail.Font,
					Vector2.new(math.huge, math.huge)
				).X
				> width
		do
			size -= 1
		end
		detail.TextSize = size
	end
	detail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitDetail)

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
			table.insert(
				parts,
				("Survivors: %d"):format(ReplicatedStorage:GetAttribute("Alive") or 0)
			)
			if (ReplicatedStorage:GetAttribute("KingCount") or 0) == 0 then
				table.insert(parts, "The King is coming...")
			end
		end
		detail.Text = if #parts > 0 then table.concat(parts, "  |  ") else Config.Game.Name
		fitDetail()
	end

	for _, name in { "State", "TimeLeft", "MapName", "Difficulty", "Alive", "KingCount" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Pumpkins"):Connect(refresh)
	refresh()
end

return Hud
