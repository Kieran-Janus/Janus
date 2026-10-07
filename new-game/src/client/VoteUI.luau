--!strict
-- Vote panel: one row of game buttons (a mode on a map) and, when an offered mode uses it, a
-- row of difficulty buttons, with live counts. Shown while the server's vote is open; sends
-- intent only (the server validates). When only Ready players can vote and you aren't on the
-- Ready pad, the buttons are greyed out with a hint (Config.Lobby.Ready.Text.VoteHint); on
-- phones you only see the hint then, so the greyed buttons don't cover the middle of a small
-- screen (and the Candy Rush lanes) for the whole vote.
-- On touch screens the panel is only as wide as the gap between the thumbstick and the jump
-- button, with taller game buttons, so it never has to shrink (text stays readable).
-- Motion (Config.Voting.Motion, off with Config.Voting.Animate = false): the cards pop in one
-- after another, the card you tap bounces and gets an outline, counts step up to their new
-- number and pulse, and once the server picks the game the winning card pops before the
-- panel closes (only when the client can tell which one won). The seconds left show quietly
-- beside the heading. The vote is always sent the moment you tap; motion never delays it.
-- VoteUI.Open() -> boolean   shows the panel again if a vote is open (Menu > Vote); false
--                            when no vote is open right now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

type Option = { Id: string, Name: string, Votes: number, Mode: string? }
type VoteState = {
	Open: boolean,
	Maps: { Option },
	Difficulties: { Option },
	ReadyOnly: boolean?,
}
-- One button and what it shows right now (Shown steps towards Target).
type Card = {
	Button: TextButton,
	Scale: UIScale,
	Stroke: UIStroke,
	Option: Option,
	Shown: number,
	Target: number,
	Tick: number, -- bumped to stop an older count animation
}

local VoteUI = {}

local HEADING_HEIGHT = 24
local ROW_HEIGHT = 52
local TALL_ROW_HEIGHT = 64 -- game buttons on a narrow panel (long names wrap onto more lines)
local SECTION_GAPS = 12 -- the gaps around a heading and its row
local HINT_HEIGHT = 22
local PADDING = 8
local WIDTH = 560
local MIN_WIDTH = 340
local NARROW = 500 -- narrower than this uses TALL_ROW_HEIGHT
local BUTTON_TEXT = 17

local votePanel: Frame? = nil
local voteOpen = false

function VoteUI.Open(): boolean
	if votePanel and voteOpen then
		votePanel.Visible = true
		return true
	end
	return false
end

local function cardText(option: Option, votes: number): string
	return ("%s\n%d vote%s"):format(option.Name, votes, if votes == 1 then "" else "s")
end

function VoteUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local castVote = Remotes.Event("CastVote")
	local voteUpdate = Remotes.Event("VoteUpdate")
	local cfg = Config.Voting
	local motion = cfg.Motion
	local mine: { [string]: string } = {}
	local current: VoteState? = nil
	local cards: { [string]: { Card } } = { Map = {}, Difficulty = {} }
	local cardIds: { [string]: string } = { Map = "", Difficulty = "" } -- which options they show
	local closing = 0 -- > 0 (a token) while the panel stays up after the vote to show the winner
	local closeSerial = 0

	local panel = Theme.panel(gui)
	panel.Name = "Vote"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(WIDTH, 200)
	panel.Visible = false
	Layout.Fit(panel, true)
	votePanel = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.Parent = panel

	local hint = Theme.label(Config.Lobby.Ready.Text.VoteHint, 16, panel)
	hint.Name = "Hint"
	hint.LayoutOrder = 0
	hint.Size = UDim2.new(1, -24, 0, HINT_HEIGHT)
	hint.TextColor3 = Theme.Selected
	hint.Visible = false

	local function section(title: string, order: number): (TextLabel, Frame)
		local heading = Theme.label(title, 18, panel)
		heading.LayoutOrder = order
		heading.Size = UDim2.new(1, 0, 0, HEADING_HEIGHT)

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = order + 1
		row.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
		row.Parent = panel
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = row
		return heading, row
	end

	local mapHeading, mapRow = section(cfg.Text.Heading, 1)
	local difficultyHeading, difficultyRow = section(cfg.Text.Difficulty, 3)

	-- The seconds left, small and quiet at the right of the heading (the real timer only).
	local timer = Theme.label("", 16, mapHeading)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -14, 0.5, 0)
	timer.Size = UDim2.fromOffset(60, HEADING_HEIGHT)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.TextColor3 = Theme.Muted
	local function updateTimer()
		local left = ReplicatedStorage:GetAttribute("TimeLeft")
		if
			voteOpen
			and ReplicatedStorage:GetAttribute("State") == "Voting"
			and typeof(left) == "number"
			and left > 0
		then
			timer.Text = cfg.Text.TimeLeft:format(left)
		else
			timer.Text = ""
		end
	end

	-- As wide as the screen allows, up to WIDTH. On touch screens it sits between the
	-- thumbstick and the jump button's group of round buttons (HEY!, Run), which reach further
	-- in, so it moves left of the middle.
	local function placePanel(): number
		local screen = Layout.Screen()
		if screen.X <= 0 then
			return WIDTH -- (not laid out yet)
		end
		if not Layout.IsTouch() then
			panel.Position = UDim2.new(0.5, 0, 1, -24)
			return math.clamp(screen.X - 2 * Config.UI.EdgeMargin, MIN_WIDTH, WIDTH)
		end
		local left = Config.UI.TouchBottomSideClear
		local width = math.clamp(screen.X - left - Config.UI.TouchActionsClear, MIN_WIDTH, WIDTH)
		panel.Position = UDim2.new(0, left + width / 2, 1, -24)
		return width
	end

	-- Only Ready players can vote (when the server says so).
	local function canVote(): boolean
		local state = current
		return not (state and state.ReadyOnly) or player:GetAttribute("Ready") == true
	end

	-- A quick squash-and-grow on a card (taps, count changes, the winner).
	local function bounce(card: Card, from: number, to: number, seconds: number)
		if not Config.Voting.Animate then
			card.Scale.Scale = to
			return
		end
		card.Scale.Scale = from
		TweenService:Create(
			card.Scale,
			TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = to }
		):Play()
	end

	-- Steps a card's count to its new number (a few steps at most), then pulses.
	local function countTo(card: Card, votes: number)
		if votes == card.Target then
			return
		end
		card.Target = votes
		card.Tick += 1
		local tick = card.Tick
		if not Config.Voting.Animate then
			card.Shown = votes
			card.Button.Text = cardText(card.Option, votes)
			return
		end
		local step = math.max(1, math.ceil(math.abs(votes - card.Shown) / motion.MaxTicks))
		task.spawn(function()
			while card.Tick == tick and card.Shown ~= votes and card.Button.Parent do
				if card.Shown < votes then
					card.Shown = math.min(card.Shown + step, votes)
				else
					card.Shown = math.max(card.Shown - step, votes)
				end
				card.Button.Text = cardText(card.Option, card.Shown)
				if card.Shown ~= votes then
					task.wait(motion.TickSeconds)
				end
			end
			if card.Tick == tick and card.Button.Parent then
				bounce(card, motion.PulseScale, 1, motion.PulseSeconds)
			end
		end)
	end

	local function paint(kind: string)
		for _, card in cards[kind] do
			local chosen = mine[kind] == card.Option.Id
			card.Button.BackgroundColor3 = if chosen then Theme.Selected else Theme.Button
			card.Stroke.Transparency = if chosen then 0 else 1
		end
	end

	local function build(row: Frame, kind: string, options: { Option })
		for _, card in cards[kind] do
			card.Button:Destroy()
		end
		local list: { Card } = {}
		cards[kind] = list
		local appear = Config.Voting.Animate and not panel.Visible
		for i, option in options do
			local button = Instance.new("TextButton")
			button.Name = "Card_" .. option.Id
			button.Size = UDim2.new(1 / #options, -8, 1, 0)
			button.BackgroundColor3 = Theme.Button
			button.Font = Theme.Font
			button.TextSize = BUTTON_TEXT
			button.TextWrapped = true
			-- Long names shrink a little on narrow panels, never below Config.UI.MinTextSize.
			button.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = BUTTON_TEXT
			limit.MinTextSize = Config.UI.MinTextSize
			limit.Parent = button
			button.Text = cardText(option, option.Votes)
			local scale = Instance.new("UIScale")
			scale.Parent = button
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = motion.HighlightColor
			stroke.Thickness = motion.HighlightThickness
			stroke.Transparency = 1
			stroke.Parent = button
			button.Parent = row
			Theme.round(button, 8)
			local card: Card = {
				Button = button,
				Scale = scale,
				Stroke = stroke,
				Option = option,
				Shown = option.Votes,
				Target = option.Votes,
				Tick = 0,
			}
			table.insert(list, card)
			button.Activated:Connect(function()
				if not canVote() or not voteOpen then
					return
				end
				-- The vote goes first; the bounce is only for show.
				mine[kind] = card.Option.Id
				castVote:FireServer(kind, card.Option.Id)
				paint(kind)
				bounce(card, motion.PressScale, 1, motion.BounceSeconds)
			end)
			-- Pop in one after another when the panel first shows.
			if appear then
				scale.Scale = 0
				TweenService:Create(
					scale,
					TweenInfo.new(
						motion.CardInSeconds,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out,
						0,
						false,
						(i - 1) * motion.CardStagger
					),
					{ Scale = 1 }
				):Play()
			end
		end
	end

	-- New options = new cards; the same options = update them in place (counts, colours).
	local function fill(row: Frame, kind: string, options: { Option }, enabled: boolean)
		local ids = {}
		for _, option in options do
			table.insert(ids, option.Id)
		end
		local key = table.concat(ids, "|")
		if key ~= cardIds[kind] or #cards[kind] ~= #options then
			cardIds[kind] = key
			build(row, kind, options)
		else
			for i, card in cards[kind] do
				card.Option = options[i]
				countTo(card, options[i].Votes)
			end
		end
		for _, card in cards[kind] do
			local button = card.Button
			button.TextColor3 = if enabled then Theme.Text else Theme.Muted
			button.BackgroundTransparency = if enabled then 0 else 0.4
			button.AutoButtonColor = enabled
			button.Active = enabled
		end
		paint(kind)
	end

	local function render()
		local state = current
		if not state or not state.Open then
			if closing == 0 then
				panel.Visible = false
			end
			return
		end
		local enabled = canVote()
		-- Phones: someone who can't vote yet only sees the hint.
		local hintOnly = not enabled and Layout.IsPhone()
		local hasDifficulty = #state.Difficulties > 0 and not hintOnly
		local width = placePanel()
		local mapHeight = if width < NARROW then TALL_ROW_HEIGHT else ROW_HEIGHT
		hint.Visible = not enabled
		mapHeading.Visible = not hintOnly
		mapRow.Visible = not hintOnly
		mapRow.Size = UDim2.new(1, -24, 0, mapHeight)
		difficultyHeading.Visible = hasDifficulty
		difficultyRow.Visible = hasDifficulty
		fill(mapRow, "Map", state.Maps, enabled)
		fill(difficultyRow, "Difficulty", state.Difficulties, enabled)
		-- Height from what's showing: the game row, the difficulty row, the hint.
		local height = PADDING * 2
		if not hintOnly then
			height += HEADING_HEIGHT + mapHeight + SECTION_GAPS
		end
		if hasDifficulty then
			height += HEADING_HEIGHT + ROW_HEIGHT + SECTION_GAPS
		end
		if hint.Visible then
			height += HINT_HEIGHT + (if hintOnly then 0 else 6)
		end
		panel.Size = UDim2.fromOffset(width, height)
		panel.Visible = true
		updateTimer()
	end

	-- The winner, once the server has picked it: the game goes to its intermission with the
	-- winning playlist's mode in ReplicatedStorage.Mode. Among the most-voted cards, the one
	-- with that mode won; when that still leaves two (a tie between two maps of one mode), the
	-- client can't tell, so nothing is celebrated.
	local function winnerCard(): Card?
		local mode = ReplicatedStorage:GetAttribute("Mode")
		local best = -1
		for _, card in cards.Map do
			best = math.max(best, card.Target)
		end
		local found: Card? = nil
		for _, card in cards.Map do
			if card.Target == best and card.Option.Mode == mode then
				if found then
					return nil
				end
				found = card
			end
		end
		return found
	end

	local function finishClosing(token: number)
		if closing == token then
			closing = 0
			panel.Visible = false
			-- The next vote builds fresh cards (and pops them in again).
			cardIds.Map = ""
			cardIds.Difficulty = ""
		end
	end

	-- The vote just closed: keep the panel (cards no longer tappable) until the server says
	-- what won, pop the winner, then close. Gives up after WinnerWaitSeconds.
	local function celebrate()
		closeSerial += 1
		closing = closeSerial
		local token = closing
		timer.Text = ""
		for _, list in cards do
			for _, card in list do
				card.Button.Active = false
				card.Button.AutoButtonColor = false
			end
		end
		local done = false
		local connection: RBXScriptConnection? = nil
		local function check()
			if done or closing ~= token then
				return
			end
			if ReplicatedStorage:GetAttribute("State") ~= "Intermission" then
				return
			end
			done = true
			if connection then
				connection:Disconnect()
			end
			local winner = winnerCard()
			if not winner then
				finishClosing(token)
				return
			end
			for _, card in cards.Map do
				if card ~= winner then
					card.Button.BackgroundTransparency = 0.6
					card.Button.TextTransparency = 0.5
				end
			end
			winner.Button.BackgroundColor3 = motion.WinnerColor
			winner.Button.TextColor3 = Theme.Background
			winner.Stroke.Transparency = 0
			bounce(winner, motion.WinnerScale * 1.15, motion.WinnerScale, motion.BounceSeconds)
			task.delay(motion.WinnerSeconds, finishClosing, token)
		end
		connection = ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(check)
		check()
		task.delay(motion.WinnerWaitSeconds, function()
			if not done then
				done = true
				if connection then
					connection:Disconnect()
				end
				finishClosing(token)
			end
		end)
	end

	voteUpdate.OnClientEvent:Connect(function(state: VoteState)
		if typeof(state) ~= "table" then
			return
		end
		local wasOpen = voteOpen
		current = state
		voteOpen = state.Open == true
		if voteOpen and closing > 0 then
			finishClosing(closing) -- a new vote: drop the old one's winner
		end
		if not voteOpen then
			table.clear(mine)
			if
				wasOpen
				and panel.Visible
				and mapRow.Visible
				and Config.Voting.Animate
				and #cards.Map > 0
			then
				-- (the closing update carries the final counts)
				for i, card in cards.Map do
					local option = state.Maps and state.Maps[i]
					if option and option.Id == card.Option.Id then
						card.Option = option
						countTo(card, option.Votes)
					end
				end
				celebrate()
				return
			end
			cardIds.Map = ""
			cardIds.Difficulty = ""
		end
		render()
	end)
	player:GetAttributeChangedSignal("Ready"):Connect(render)
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(updateTimer)
end

return VoteUI
