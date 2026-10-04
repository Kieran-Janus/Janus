--!strict
-- Results screen shown after each round, sorted by pumpkins. Your own row is highlighted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

type ResultRow = {
	UserId: number,
	Name: string,
	Pumpkins: number,
	Coins: number,
	Survived: boolean,
	Top: boolean,
}

local ResultsUI = {}

function ResultsUI.Mount(gui: ScreenGui)
	local roundResults = Remotes.Event("RoundResults")
	local rowHeight = 30

	local panel = Theme.panel(gui)
	panel.Name = "Results"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Visible = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	-- Fixed column positions so the header and every row line up.
	local columns: { { Header: string, X: number, Width: number, Align: Enum.TextXAlignment } } = {
		{ Header = "Player", X = 0, Width = 0.48, Align = Enum.TextXAlignment.Left },
		{ Header = "Pumpkins", X = 0.48, Width = 0.18, Align = Enum.TextXAlignment.Right },
		{ Header = "Coins", X = 0.66, Width = 0.16, Align = Enum.TextXAlignment.Right },
		{ Header = "", X = 0.84, Width = 0.16, Align = Enum.TextXAlignment.Right },
	}

	local function row(cells: { string }, order: number, color: Color3, size: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -24, 0, rowHeight)
		frame.Parent = panel
		for i, column in columns do
			local label = Theme.label(cells[i] or "", size, frame)
			label.Position = UDim2.fromScale(column.X, 0)
			label.Size = UDim2.fromScale(column.Width, 1)
			label.TextXAlignment = column.Align
			label.TextColor3 = color
			label.TextTruncate = Enum.TextTruncate.AtEnd
		end
		return frame
	end

	local hideToken = 0
	roundResults.OnClientEvent:Connect(function(rows: { ResultRow })
		if typeof(rows) ~= "table" then
			return
		end
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local title = Theme.label("Round over!", 24, panel)
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, -24, 0, rowHeight + 6)
		local headers = {}
		for _, column in columns do
			table.insert(headers, column.Header)
		end
		row(headers, 1, Theme.Muted, 15)

		local me = Players.LocalPlayer.UserId
		local function playerRow(rank: number, result: ResultRow, order: number)
			local tag = if result.Top then "Top" elseif not result.Survived then "Out" else ""
			row({
				("%d. %s"):format(rank, result.Name),
				tostring(result.Pumpkins),
				"+" .. result.Coins,
				tag,
			}, order, if result.UserId == me then Theme.Selected else Theme.Text, 17)
		end

		local shown = math.min(#rows, Config.Round.ResultsShowTop)
		for i = 1, shown do
			playerRow(i, rows[i], i + 1)
		end
		-- Always show your own line, even outside the top N.
		for i = shown + 1, #rows do
			if rows[i].UserId == me then
				playerRow(i, rows[i], shown + 2)
			end
		end
		if #rows == 0 then
			row({ "Nobody finished this round." }, 2, Theme.Text, 17)
		end

		local lines = 0
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				lines += 1
			end
		end
		panel.Size = UDim2.fromOffset(460, lines * rowHeight + 6 + 16)
		panel.Visible = true

		hideToken += 1
		local token = hideToken
		task.delay(Config.Round.ResultsSeconds, function()
			if token == hideToken then
				panel.Visible = false
			end
		end)
	end)
end

return ResultsUI
