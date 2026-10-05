--!strict
-- Top bar: round state + timer, then one line of details: the mode, map and difficulty, the
-- Ready pad count while waiting, and King Hunt's pumpkins / survivors while playing.
-- Reads attributes the server sets; no remotes needed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local Hud = {}

local DETAIL_MAX_SIZE = 15
local DETAIL_MIN_SIZE = 14 -- readable on phones; longer lines end in "..."

function Hud.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local readyText = Config.Lobby.Ready.Text

	local bar = Theme.panel(gui)
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.02)
	bar.Size = UDim2.fromOffset(520, 64)
	Layout.Fit(bar)

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

	-- The Ready pad decides who plays (feature on and a pad exists in the lobby).
	local function padsActive(): boolean
		return Config.Features.ReadyPad and (ReplicatedStorage:GetAttribute("ReadyPads") or 0) > 0
	end

	local function refresh()
		local state = ReplicatedStorage:GetAttribute("State") or "Loading"
		local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
		local modeName = ReplicatedStorage:GetAttribute("ModeName")
		local inRound = player:GetAttribute("InRound") == true
		local ready = player:GetAttribute("Ready") == true
		-- While playing, the title names the mode ("King Hunt  4:59").
		local heading = if state == "Playing" and modeName then modeName else state
		if timeLeft > 0 then
			title.Text = ("%s  %d:%02d"):format(tostring(heading), timeLeft // 60, timeLeft % 60)
		else
			title.Text = tostring(heading)
		end

		local parts = {}
		if state == "Waiting for players" and padsActive() then
			table.insert(
				parts,
				readyText.Count:format(
					ReplicatedStorage:GetAttribute("ReadyCount") or 0,
					ReplicatedStorage:GetAttribute("ReadyNeeded") or Config.Lobby.Ready.MinReady
				)
			)
			table.insert(parts, if ready then readyText.YoureReady else readyText.StandOnPad)
		else
			if modeName and state ~= "Playing" then
				table.insert(parts, modeName)
			end
			local mapName = ReplicatedStorage:GetAttribute("MapName")
			local difficulty = ReplicatedStorage:GetAttribute("Difficulty")
			if mapName then
				table.insert(parts, mapName)
			end
			if difficulty then
				table.insert(parts, difficulty)
			end
			if state == "Playing" and ReplicatedStorage:GetAttribute("Mode") == "KingHunt" then
				if inRound then
					table.insert(
						parts,
						("Pumpkins: %d"):format(player:GetAttribute("Pumpkins") or 0)
					)
				end
				table.insert(
					parts,
					("Survivors: %d"):format(ReplicatedStorage:GetAttribute("Alive") or 0)
				)
				if (ReplicatedStorage:GetAttribute("KingCount") or 0) == 0 then
					table.insert(parts, "The King is coming...")
				end
			end
			-- Lobby players: the Ready pad hint goes first so it never gets cut off.
			if padsActive() and not inRound then
				if state == "Voting" or state == "Intermission" then
					if not ready then
						table.insert(parts, 1, readyText.StandOnPad)
					end
				elseif state == "Playing" or state == "Results" then
					table.insert(
						parts,
						1,
						if ready then readyText.ReadyNextRound else readyText.NextRound
					)
				end
			end
		end
		detail.Text = if #parts > 0 then table.concat(parts, "  |  ") else Config.Game.Name
		fitDetail()
	end

	for _, name in
		{
			"State",
			"TimeLeft",
			"MapName",
			"Difficulty",
			"Alive",
			"KingCount",
			"Mode",
			"ModeName",
			"ReadyCount",
			"ReadyNeeded",
			"ReadyPads",
		}
	do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, name in { "Pumpkins", "InRound", "Ready" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return Hud
