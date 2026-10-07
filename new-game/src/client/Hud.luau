--!strict
-- Top bar: round state + timer, then the details: the mode, map and difficulty, the Ready pad
-- count while waiting, and King Hunt's pumpkins / survivors while playing. Your coins sit in
-- the top-right corner: the number rolls to its new value and a "+50" drifts away on gains.
-- Reads attributes the server sets and leaderstats; no remotes needed.
-- Sizes in Config.UI.Hud: the bar grows with its words up to MaxWidth (never wider than the
-- screen) and the details wrap onto a second line instead of being cut off ("...").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local Hud = {}

local TITLE_FONT = Theme.Font
local DETAIL_FONT = Theme.Font
local DETAIL_TOP = 34 -- where the details start, under the title row

export type Measured = {
	Width: number,
	Height: number,
	TitleSize: number,
	TitleCentred: boolean, -- false: the title sits left of the coins (narrow bars)
	DetailSize: number,
	DetailLines: number,
	DetailHeight: number,
	Fits: boolean, -- false: even the smallest text on the most lines doesn't fit (ends in "...")
}

local function textWidth(text: string, size: number, font: Enum.Font): number
	return TextService:GetTextSize(text, size, font, Vector2.new(math.huge, math.huge)).X
end

local function linesAt(text: string, size: number, width: number): number
	local height = TextService:GetTextSize(text, size, DETAIL_FONT, Vector2.new(width, math.huge)).Y
	return math.max(1, math.ceil(height / size - 0.01))
end

local function lineHeight(size: number): number
	return math.ceil(size * 1.25)
end

-- Where everything goes for these words on a screen `screenWidth` UI units wide (0 = unknown).
function Hud.Measure(title: string, detail: string, screenWidth: number): Measured
	local cfg = Config.UI.Hud
	local minText = Config.UI.MinTextSize
	local pad = cfg.Padding
	local avail = if screenWidth > 0 then screenWidth - 2 * Config.UI.EdgeMargin else math.huge
	local maxWidth = math.min(cfg.MaxWidth, avail)
	local minWidth = math.min(cfg.MinWidth, maxWidth)
	local coinsRoom = cfg.CoinsWidth + pad

	-- As wide as the words want (title centred clear of the coins, details on one line).
	local titleNeed = textWidth(title, cfg.TitleSize, TITLE_FONT) + 2 * coinsRoom
	local detailNeed = textWidth(detail, cfg.DetailSize, DETAIL_FONT) + 2 * pad
	-- (in steps of 20, so the bar doesn't twitch as the timer's digits change)
	local want = math.ceil(math.max(titleNeed, detailNeed) / 20) * 20
	local width = math.floor(math.clamp(want, minWidth, maxWidth))

	-- Title: centred if it fits that way, otherwise in the room left of the coins.
	local centred = true
	local titleSize = cfg.TitleSize
	local area = width - 2 * coinsRoom
	local function titleFits(size: number): boolean
		return textWidth(title, size, TITLE_FONT) <= area
	end
	while titleSize > minText and not titleFits(titleSize) do
		titleSize -= 1
	end
	if not titleFits(titleSize) then
		centred = false
		area = width - coinsRoom - pad
		titleSize = cfg.TitleSize
		while titleSize > minText and not titleFits(titleSize) do
			titleSize -= 1
		end
	end

	-- Details: the biggest size that fits on one line, else wrap onto more lines.
	local inner = width - 2 * pad
	local size = cfg.DetailSize
	local lines = 1
	local fits = true
	local found = false
	for lineCount = 1, math.max(1, cfg.DetailMaxLines) do
		for s = cfg.DetailSize, minText, -1 do
			local n = if lineCount == 1
				then (if textWidth(detail, s, DETAIL_FONT) <= inner then 1 else 2)
				else linesAt(detail, s, inner)
			if n <= lineCount then
				size, lines, found = s, n, true
				break
			end
		end
		if found then
			break
		end
	end
	if not found then
		size, lines, fits = minText, math.max(1, cfg.DetailMaxLines), false
	end
	local detailHeight = lines * lineHeight(size) + 5
	return {
		Width = width,
		Height = DETAIL_TOP + detailHeight + 6,
		TitleSize = titleSize,
		TitleCentred = centred,
		DetailSize = size,
		DetailLines = lines,
		DetailHeight = detailHeight,
		Fits = fits,
	}
end

function Hud.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local readyText = Config.Lobby.Ready.Text
	local cfg = Config.UI.Hud

	local bar = Theme.panel(gui)
	bar.Name = "Hud"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.02)
	bar.Size = UDim2.fromOffset(cfg.MinWidth, 64)
	Layout.Fit(bar)

	local title = Theme.label(Config.Game.Name, cfg.TitleSize, bar)
	title.Name = "Title"
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local detail = Theme.label("", cfg.DetailSize, bar)
	detail.Name = "Detail"
	detail.TextColor3 = Theme.Muted
	detail.TextWrapped = true
	detail.TextTruncate = Enum.TextTruncate.AtEnd -- a last resort only (Measure wraps first)
	detail.Position = UDim2.fromOffset(cfg.Padding, DETAIL_TOP)

	-- Coins ---------------------------------------------------------------------------------
	local coinsPill = Instance.new("Frame")
	coinsPill.Name = "Coins"
	coinsPill.BackgroundColor3 = Color3.new(0, 0, 0)
	coinsPill.BackgroundTransparency = 0.55
	coinsPill.AnchorPoint = Vector2.new(1, 0)
	coinsPill.Position = UDim2.new(1, -6, 0, 6)
	coinsPill.Size = UDim2.fromOffset(cfg.CoinsWidth, cfg.TitleHeight - 12)
	coinsPill.Visible = false -- until leaderstats arrive
	coinsPill.Parent = bar
	Theme.round(coinsPill, 12)
	local coinsLabel = Theme.label("", 16, coinsPill)
	coinsLabel.Name = "Amount"
	coinsLabel.Size = UDim2.fromScale(1, 1)
	coinsLabel.TextColor3 = cfg.CoinsGain

	local function coinText(n: number): string
		return ("%s %s"):format(cfg.CoinsIcon, UIMotion.Commas(n))
	end
	local shown: number? = nil
	local function setCoins(value: number)
		coinsPill.Visible = true
		local before = shown
		shown = value
		if before == nil then
			coinsLabel.Text = coinText(value)
			return
		end
		if value == before then
			return
		end
		UIMotion.CountTo(coinsLabel, before, value, coinText)
		if value > before then
			UIMotion.Bump(coinsPill)
			UIMotion.FloatText(
				coinsPill,
				("+%s"):format(UIMotion.Commas(value - before)),
				cfg.CoinsGain
			)
		end
	end
	local watchedCoins: Instance? = nil
	local function watchCoins(value: Instance)
		if value.Name ~= "Coins" or not value:IsA("IntValue") or value == watchedCoins then
			return
		end
		watchedCoins = value
		setCoins(value.Value)
		value.Changed:Connect(function()
			setCoins(value.Value)
		end)
	end
	local function watchStats(stats: Instance)
		if stats.Name ~= "leaderstats" then
			return
		end
		local existing = stats:FindFirstChild("Coins")
		if existing then
			watchCoins(existing)
		end
		stats.ChildAdded:Connect(watchCoins)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		watchStats(stats)
	end
	player.ChildAdded:Connect(watchStats)

	-- Size and place everything for the current words and screen.
	local function relayout()
		local m = Hud.Measure(title.Text, detail.Text, Layout.Screen().X)
		local want = UDim2.fromOffset(m.Width, m.Height)
		if bar.Size ~= want then
			bar.Size = want
		end
		local coinsRoom = cfg.CoinsWidth + cfg.Padding
		title.TextSize = m.TitleSize
		if m.TitleCentred then
			title.Position = UDim2.fromOffset(coinsRoom, 0)
			title.Size = UDim2.new(1, -2 * coinsRoom, 0, cfg.TitleHeight)
		else
			title.Position = UDim2.fromOffset(cfg.Padding, 0)
			title.Size = UDim2.new(1, -(coinsRoom + cfg.Padding), 0, cfg.TitleHeight)
		end
		detail.TextSize = m.DetailSize
		detail.Size = UDim2.new(1, -2 * cfg.Padding, 0, m.DetailHeight - 5)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

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
			-- Lobby players: the Ready pad hint goes first so it is always read first.
			if padsActive() and not inRound then
				if state == "Voting" or state == "Intermission" then
					if not ready then
						table.insert(parts, 1, readyText.StandOnPad)
					end
				elseif
					state == "Playing"
					or state == "Results"
					or table.find(Config.Menu.RoundStates, state) ~= nil -- a mode's own states
				then
					table.insert(
						parts,
						1,
						if ready then readyText.ReadyNextRound else readyText.NextRound
					)
				end
			end
		end
		detail.Text = if #parts > 0 then table.concat(parts, "  |  ") else Config.Game.Name
		relayout()
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
