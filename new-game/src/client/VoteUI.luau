--!strict
-- Vote panel: one row of game buttons (a mode on a map) and, when an offered mode uses it, a
-- row of difficulty buttons, with live counts. Shown while the server's vote is open; sends
-- intent only (the server validates). When only Ready players can vote and you aren't on the
-- Ready pad, the buttons are greyed out with a hint (Config.Lobby.Ready.Text.VoteHint); on
-- phones you only see the hint then, so the greyed buttons don't cover the middle of a small
-- screen (and the Candy Rush lanes) for the whole vote.
-- On touch screens the panel is only as wide as the gap between the thumbstick and the jump
-- button, with taller game buttons, so it never has to shrink (text stays readable).
-- VoteUI.Open() -> boolean   shows the panel again if a vote is open (Menu > Vote); false
--                            when no vote is open right now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

type Option = { Id: string, Name: string, Votes: number }
type VoteState = {
	Open: boolean,
	Maps: { Option },
	Difficulties: { Option },
	ReadyOnly: boolean?,
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

function VoteUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local castVote = Remotes.Event("CastVote")
	local voteUpdate = Remotes.Event("VoteUpdate")
	local mine: { [string]: string } = {}
	local current: VoteState? = nil

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

	local mapHeading, mapRow = section("Vote for the next game", 1)
	local difficultyHeading, difficultyRow = section("Vote for the difficulty", 3)

	-- As wide as the screen allows (on touch screens: between the thumbstick and the jump
	-- button), up to WIDTH.
	local function panelWidth(): number
		local screen = Layout.Screen()
		if screen.X <= 0 then
			return WIDTH -- (not laid out yet)
		end
		local clear = if Layout.IsTouch()
			then Config.UI.TouchBottomSideClear
			else Config.UI.EdgeMargin
		return math.clamp(screen.X - 2 * clear, MIN_WIDTH, WIDTH)
	end

	-- Only Ready players can vote (when the server says so).
	local function canVote(): boolean
		local state = current
		return not (state and state.ReadyOnly) or player:GetAttribute("Ready") == true
	end

	local function fill(row: Frame, kind: string, options: { Option }, enabled: boolean)
		for _, child in row:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for _, option in options do
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1 / #options, -8, 1, 0)
			button.BackgroundColor3 = if mine[kind] == option.Id
				then Theme.Selected
				else Theme.Button
			button.TextColor3 = if enabled then Theme.Text else Theme.Muted
			button.BackgroundTransparency = if enabled then 0 else 0.4
			button.AutoButtonColor = enabled
			button.Active = enabled
			button.Font = Theme.Font
			button.TextSize = BUTTON_TEXT
			button.TextWrapped = true
			-- Long names shrink a little on narrow panels, never below Config.UI.MinTextSize.
			button.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = BUTTON_TEXT
			limit.MinTextSize = Config.UI.MinTextSize
			limit.Parent = button
			button.Text = ("%s\n%d vote%s"):format(
				option.Name,
				option.Votes,
				if option.Votes == 1 then "" else "s"
			)
			button.Parent = row
			Theme.round(button, 8)
			button.Activated:Connect(function()
				if not canVote() then
					return
				end
				mine[kind] = option.Id
				castVote:FireServer(kind, option.Id)
				for _, other in row:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = if other == button
							then Theme.Selected
							else Theme.Button
					end
				end
			end)
		end
	end

	local function render()
		local state = current
		if not state or not state.Open then
			panel.Visible = false
			return
		end
		local enabled = canVote()
		-- Phones: someone who can't vote yet only sees the hint.
		local hintOnly = not enabled and Layout.IsPhone()
		local hasDifficulty = #state.Difficulties > 0 and not hintOnly
		local width = panelWidth()
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
	end

	voteUpdate.OnClientEvent:Connect(function(state: VoteState)
		if typeof(state) ~= "table" then
			return
		end
		current = state
		voteOpen = state.Open == true
		if not voteOpen then
			table.clear(mine)
		end
		render()
	end)
	player:GetAttributeChangedSignal("Ready"):Connect(render)
end

return VoteUI
