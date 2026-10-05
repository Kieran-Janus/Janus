--!strict
-- Vote panel: one row of game buttons (a mode on a map) and, when an offered mode uses it, a
-- row of difficulty buttons, with live counts. Shown while the server's vote is open; sends
-- intent only (the server validates). When only Ready players can vote and you aren't on the
-- Ready pad, the buttons are greyed out with a hint (Config.Lobby.Ready.Text.VoteHint).
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

local SECTION_HEIGHT = 24 + 52 + 12 -- heading + row + the gaps between them
local HINT_HEIGHT = 22
local PADDING = 8

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
	panel.Size = UDim2.fromOffset(560, 200)
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
		heading.Size = UDim2.new(1, 0, 0, 24)

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = order + 1
		row.Size = UDim2.new(1, -24, 0, 52)
		row.Parent = panel
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = row
		return heading, row
	end

	local _, mapRow = section("Vote for the next game", 1)
	local difficultyHeading, difficultyRow = section("Vote for the difficulty", 3)

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
			button.TextSize = 17 -- stays >= 14 px when the panel shrinks to fit a phone
			button.TextWrapped = true
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
		local hasDifficulty = #state.Difficulties > 0
		hint.Visible = not enabled
		difficultyHeading.Visible = hasDifficulty
		difficultyRow.Visible = hasDifficulty
		fill(mapRow, "Map", state.Maps, enabled)
		fill(difficultyRow, "Difficulty", state.Difficulties, enabled)
		-- Height from what's showing: one or two sections, plus the hint.
		local height = PADDING * 2
			+ SECTION_HEIGHT * (if hasDifficulty then 2 else 1)
			+ (if hint.Visible then HINT_HEIGHT + 6 else 0)
		panel.Size = UDim2.fromOffset(560, height)
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
