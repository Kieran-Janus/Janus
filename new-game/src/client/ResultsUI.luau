--!strict
--[[
	Results screen after each round (timings, text and colours in Config.Results):
	  - slides in, rows appear one after another, sorted by pumpkins
	  - the top collector gets an MVP spotlight with their avatar headshot
	  - everyone's coins count up; your own count plays the coin sound
	  - survivors get a "Survived!" badge, caught players "Caught"
	  - your own row is highlighted (and always shown, even outside the top N)
	  - "Next round in X" counts down with the server's Results timer
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
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

local WIDTH = 560
local ROW_HEIGHT = 34

-- Fixed columns so the header and every row line up.
local COLUMNS: { { Header: string, X: number, Width: number, Align: Enum.TextXAlignment } } = {
	{ Header = "Player", X = 0.02, Width = 0.44, Align = Enum.TextXAlignment.Left },
	{ Header = "Pumpkins", X = 0.46, Width = 0.16, Align = Enum.TextXAlignment.Right },
	{ Header = "Coins", X = 0.63, Width = 0.14, Align = Enum.TextXAlignment.Right },
	{ Header = "", X = 0.79, Width = 0.2, Align = Enum.TextXAlignment.Center },
}

local function corner(instance: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

-- A small rounded pill ("Survived!", "Caught", "MVP").
local function badge(text: string, color: Color3, parent: Instance): TextLabel
	local label = Theme.label(text, 14, parent)
	label.BackgroundTransparency = 0.15
	label.BackgroundColor3 = color
	label.TextColor3 = Theme.Background
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -6, 0, 22)
	corner(label, 11)
	return label
end

function ResultsUI.Mount(gui: ScreenGui)
	local cfg = Config.Results
	local text = cfg.Text
	local roundResults = Remotes.Event("RoundResults")
	local me = Players.LocalPlayer.UserId

	local panel = Theme.panel(gui)
	panel.Name = "Results"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(WIDTH, 200)
	panel.Visible = false
	panel.ZIndex = 8
	Layout.Fit(panel) -- (that UIScale is the panel's only one, so the pop-in is a slide)

	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.Padding = UDim.new(0, 6)
	stack.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = panel

	local hideToken = 0
	local spin: RBXScriptConnection? = nil
	local countdown: RBXScriptConnection? = nil

	local function clear()
		if spin then
			spin:Disconnect()
			spin = nil
		end
		if countdown then
			countdown:Disconnect()
			countdown = nil
		end
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function mvpSpotlight(result: ResultRow, order: number)
		local box = Instance.new("Frame")
		box.Name = "Mvp"
		box.BackgroundTransparency = 1
		box.LayoutOrder = order
		box.Size = UDim2.new(1, -24, 0, 112)
		box.Parent = panel

		-- A slowly turning glow behind the headshot.
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.new(0, 60, 0.5, 0)
		glow.Size = UDim2.fromOffset(118, 118)
		glow.BackgroundColor3 = cfg.Colors.Mvp
		glow.Parent = box
		corner(glow, 59)
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		gradient.Parent = glow
		local started = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			gradient.Rotation = ((os.clock() - started) / cfg.SpotlightSpinSeconds * 360) % 360
		end)

		local head = Instance.new("ImageLabel")
		head.Name = "Headshot"
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		head.Position = glow.Position
		head.Size = UDim2.fromOffset(100, 100)
		head.BackgroundColor3 = Theme.Button
		head.Image = ""
		head.Parent = box
		corner(head, 50)
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					result.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and typeof(image) == "string" and head.Parent then
				head.Image = image
			end
		end)

		local title = Theme.label(text.Mvp, 28, box)
		title.Font = Enum.Font.GothamBlack
		title.TextColor3 = cfg.Colors.Mvp
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Position = UDim2.fromOffset(130, 18)
		title.Size = UDim2.new(1, -140, 0, 34)
		local line = Theme.label(text.MvpLine:format(result.Name, result.Pumpkins), 18, box)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextWrapped = true
		line.Position = UDim2.fromOffset(130, 54)
		line.Size = UDim2.new(1, -140, 0, 44)
	end

	local function row(parent: Instance, order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		frame.Parent = parent
		corner(frame, 8)
		return frame
	end

	local function cell(
		frame: Frame,
		column: number,
		value: string,
		color: Color3,
		size: number
	): TextLabel
		local c = COLUMNS[column]
		local label = Theme.label(value, size, frame)
		label.Position = UDim2.fromScale(c.X, 0)
		label.Size = UDim2.fromScale(c.Width, 1)
		label.TextXAlignment = c.Align
		label.TextColor3 = color
		label.TextTruncate = Enum.TextTruncate.AtEnd
		return label
	end

	-- Coins labels to count up: { label, total, isMine }
	type Counter = { Label: TextLabel, Total: number, Mine: boolean }

	local function playerRow(
		list: Instance,
		rank: number,
		result: ResultRow,
		order: number
	): Counter
		local mine = result.UserId == me
		local frame = row(list, order)
		frame.Name = if mine then "MyRow" else "Row"
		if mine then
			frame.BackgroundTransparency = 0.6
			frame.BackgroundColor3 = cfg.Colors.MyRow
		end
		cell(frame, 1, ("%d. %s"):format(rank, result.Name), Theme.Text, 17)
		cell(frame, 2, tostring(result.Pumpkins), Theme.Text, 17)
		local coins = cell(frame, 3, "+0", Theme.Selected, 17)
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.Position = UDim2.fromScale(COLUMNS[4].X, 0)
		slot.Size = UDim2.fromScale(COLUMNS[4].Width, 1)
		slot.Parent = frame
		if result.Top and result.Pumpkins > 0 then
			badge(text.Mvp, cfg.Colors.Mvp, slot)
		elseif result.Survived then
			badge(text.Survived, cfg.Colors.Survived, slot)
		else
			badge(text.Caught, cfg.Colors.Caught, slot)
		end
		frame.Visible = false
		return { Label = coins, Total = result.Coins, Mine = mine }
	end

	roundResults.OnClientEvent:Connect(function(rows: { ResultRow })
		if typeof(rows) ~= "table" then
			return
		end
		clear()
		hideToken += 1
		local token = hideToken

		local title = Theme.label(text.Title, 26, panel)
		title.Font = Enum.Font.GothamBlack
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, -24, 0, 34)

		local top = rows[1]
		if top and top.Top and top.Pumpkins > 0 then
			mvpSpotlight(top, 1)
		end

		local header = row(panel, 2)
		header.Size = UDim2.new(1, -24, 0, 22)
		for i, column in COLUMNS do
			cell(header, i, column.Header, Theme.Muted, 14)
		end

		local list = Instance.new("ScrollingFrame")
		list.Name = "Rows"
		list.LayoutOrder = 3
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 5
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = panel
		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 4)
		listLayout.Parent = list

		local counters: { Counter } = {}
		local rowFrames: { GuiObject } = {}
		local shown = math.min(#rows, Config.Round.ResultsShowTop)
		for i = 1, shown do
			table.insert(counters, playerRow(list, i, rows[i], i))
		end
		-- Always show your own line, even outside the top N.
		for i = shown + 1, #rows do
			if rows[i].UserId == me then
				table.insert(counters, playerRow(list, i, rows[i], shown + 1))
			end
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				table.insert(rowFrames, child)
			end
		end
		table.sort(rowFrames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		if #rows == 0 then
			local nobody = row(list, 1)
			nobody.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			cell(nobody, 1, text.Nobody, Theme.Text, 17).Size = UDim2.fromScale(0.96, 1)
		end
		local rowsHeight = math.max(#rowFrames, 1) * (ROW_HEIGHT + 4)
		list.Size = UDim2.new(1, -24, 0, math.min(rowsHeight, cfg.MaxListHeight))

		local footer = Theme.label("", 16, panel)
		footer.Name = "NextRound"
		footer.LayoutOrder = 4
		footer.TextColor3 = Theme.Muted
		footer.Size = UDim2.new(1, -24, 0, 22)
		local function updateFooter()
			local left = ReplicatedStorage:GetAttribute("TimeLeft")
			if
				ReplicatedStorage:GetAttribute("State") == "Results"
				and typeof(left) == "number"
			then
				footer.Text = text.NextRound:format(left)
			end
		end
		countdown = ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(updateFooter)
		updateFooter()

		-- Size the panel to its contents, then pop it in.
		local contentHeight = 22
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				contentHeight += child.Size.Y.Offset + stack.Padding.Offset
			end
		end
		panel.Size = UDim2.fromOffset(WIDTH, contentHeight)
		panel.Position = UDim2.fromScale(0.5, 0.62)
		panel.Visible = true
		TweenService:Create(
			panel,
			TweenInfo.new(cfg.PopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.5) }
		):Play()

		-- Rows one after another, then the coins count up.
		task.spawn(function()
			for _, frame in rowFrames do
				if token ~= hideToken then
					return
				end
				frame.Visible = true
				task.wait(cfg.RowDelay)
			end
			-- Your own row is always the last one; scroll down to it if it's out of view.
			local mine = list:FindFirstChild("MyRow")
			if mine and mine:IsA("GuiObject") then
				local viewBottom = list.AbsolutePosition.Y + list.AbsoluteSize.Y
				if mine.AbsolutePosition.Y + mine.AbsoluteSize.Y > viewBottom then
					list.CanvasPosition = Vector2.new(
						0,
						math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
					)
				end
			end
			task.wait(cfg.CountUpDelay)
			local started = os.clock()
			local lastSound = 0
			local myLast = 0
			while token == hideToken do
				local t = math.clamp((os.clock() - started) / cfg.CountUpSeconds, 0, 1)
				for _, counter in counters do
					local value = math.floor(counter.Total * t + 0.5)
					counter.Label.Text = "+" .. value
					if
						counter.Mine
						and value > myLast
						and os.clock() - lastSound >= cfg.CoinSoundEvery
					then
						Sounds.Play("Coins")
						lastSound = os.clock()
					end
					if counter.Mine then
						myLast = value
					end
				end
				if t >= 1 then
					break
				end
				task.wait()
			end
		end)

		task.delay(Config.Round.ResultsSeconds, function()
			if token == hideToken then
				panel.Visible = false
				clear()
			end
		end)
	end)
end

return ResultsUI
