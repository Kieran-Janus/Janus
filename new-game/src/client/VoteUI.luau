--!strict
-- Vote panel: one row of map buttons and one row of difficulty buttons with live counts.
-- Shown while the server's vote is open; sends intent only (the server validates).
-- VoteUI.Open() -> boolean   shows the panel again if a vote is open (Menu > Vote); false
--                            when no vote is open right now.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

type Option = { Id: string, Name: string, Votes: number }
type VoteState = { Open: boolean, Maps: { Option }, Difficulties: { Option } }

local VoteUI = {}

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
	local castVote = Remotes.Event("CastVote")
	local voteUpdate = Remotes.Event("VoteUpdate")
	local mine: { [string]: string } = {}

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
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = panel

	local function section(title: string, order: number): Frame
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
		return row
	end

	local mapRow = section("Vote for the map", 1)
	local difficultyRow = section("Vote for the difficulty", 3)

	local function fill(row: Frame, kind: string, options: { Option })
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
			button.TextColor3 = Theme.Text
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

	voteUpdate.OnClientEvent:Connect(function(state: VoteState)
		if typeof(state) ~= "table" then
			return
		end
		voteOpen = state.Open == true
		panel.Visible = voteOpen
		if not voteOpen then
			table.clear(mine)
			return
		end
		fill(mapRow, "Map", state.Maps)
		fill(difficultyRow, "Difficulty", state.Difficulties)
	end)
end

return VoteUI
