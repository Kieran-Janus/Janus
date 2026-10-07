--!strict
--[[
	Candy Rush screen (words, sounds and numbers: Config.Minigames.CandyRush; on/off:
	Config.Features.CandyRush; the race itself: src/server/Services/CandyRushService.luau).

	While you stand on a Candy Rush pad the server sends CandyRushState, and this shows:
	  - a panel on the left: your candies (7/10), every lane's progress bar, a status line
	    ("Waiting for 1 more player...", "Solo run in 4...", your time) and your best time
	  - the big 3-2-1 / GO! in the middle of the screen
	  - the winner banner when the race ends, with the coins you got
	It also makes candies bounce in when they pop up, outlines YOUR candy, and plays the
	countdown, GO, win and lose sounds (the pop sound comes from the server, for everyone near).
	Nothing shows while you are not at the stand.

	Celebrations (Config.Minigames.CandyRush.Effects, all off with its On = false or
	Config.Minigames.Effects.On = false; src/client/MinigameFx.luau): a sparkle burst where your
	candy was and a "+1" by your count each time the server counts a grab, lane bars that slide
	to their new length, a 3-2-1-GO that punches in, and confetti when you win. Your click is
	sent the moment you press: nothing here waits for an effect.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local CandyRushUI = {}

local cfg = Config.Minigames.CandyRush
local text = cfg.Text
local fx = cfg.Effects

local function effectsOn(): boolean
	return MinigameFx.Enabled(fx)
end

type LaneRow = {
	Lane: number,
	UserId: number,
	Name: string,
	Popped: number,
	Out: boolean,
	Color: Color3,
}

-- The same shape as CandyRushService.State.
type State = {
	Phase: string,
	Count: number?,
	Total: number,
	Solo: boolean,
	Lanes: { LaneRow },
	Needed: number,
	SoloIn: number?,
	Winner: { UserId: number, Name: string }?,
	Reason: string?,
	StartedAt: number?,
	EndsAt: number?,
	YourLane: number?,
	InRace: boolean,
	Out: boolean?,
	Time: number?,
	Best: number?,
	NewBest: boolean?,
	Coins: number?,
	Note: string?,
}

type Row = { Frame: Frame, Dot: Frame, Name: TextLabel, Fill: Frame, Count: TextLabel }

local NOTES: { [string]: string } = {
	TooFew = text.TooFew,
	Cooldown = text.Cooldown,
	DailyCap = text.DailyCap,
}

local GOLD = Color3.fromRGB(255, 210, 60)
local GRAB_REACH = 400 -- studs a click's ray looks for your candy (the server checks the distance)

-- A sound from Config.Minigames.CandyRush.Sounds (their tables differ a little, hence any).
local function play(spec: any)
	Sounds.PlaySpec(spec)
end

-- Candies bounce in (a quick grow with a little overshoot) and yours gets a white outline.
local function animateCandy(candy: Instance, me: Player)
	if not candy:IsA("Model") or candy:GetAttribute("Lane") == nil then
		return
	end
	if candy:GetAttribute("OwnerUserId") == me.UserId then
		local outline = Instance.new("Highlight")
		outline.Name = "YourCandy"
		outline.FillTransparency = 1
		outline.OutlineColor = Color3.new(1, 1, 1)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Adornee = candy
		outline.Parent = candy
	end
	if not pcall(function()
		candy:ScaleTo(0.2)
	end) then
		return
	end
	local size = Instance.new("NumberValue")
	size.Value = 0.2
	size:GetPropertyChangedSignal("Value"):Connect(function()
		if candy.Parent then
			pcall(function()
				candy:ScaleTo(math.max(size.Value, 0.05))
			end)
		end
	end)
	local tween = TweenService:Create(
		size,
		TweenInfo.new(fx.BounceSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		size:Destroy()
	end)
	tween:Play()
end

-- Where (and what colour) one of your candies was: the sparkles go there when the server
-- counts the grab.
type Spot = { Position: Vector3, Color: Color3, At: number }

local function candySpot(candy: Instance): Spot?
	if not candy:IsA("Model") then
		return nil
	end
	local color: Color3? = nil
	for _, d in candy:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			color = d.Color
			break
		end
	end
	local ok, pivot = pcall(function()
		return candy:GetPivot()
	end)
	if not ok then
		return nil
	end
	return { Position = pivot.Position, Color = color or Color3.new(1, 1, 1), At = os.clock() }
end

local function watchCandies(me: Player, onMineGone: (Spot) -> ())
	local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function watchFolder(folder: Instance)
		if watched[folder] then
			return
		end
		watched[folder] = true
		folder.ChildAdded:Connect(function(child)
			animateCandy(child, me)
		end)
		folder.ChildRemoved:Connect(function(child)
			if child:GetAttribute("OwnerUserId") == me.UserId then
				local spot = candySpot(child)
				if spot then
					onMineGone(spot)
				end
			end
		end)
	end
	local function watchStation(station: Instance)
		local folder = station:FindFirstChild("Candies")
		if folder then
			watchFolder(folder)
		end
		station.ChildAdded:Connect(function(child)
			if child.Name == "Candies" then
				watchFolder(child)
			end
		end)
	end
	for _, station in CollectionService:GetTagged(Tags.CandyRushStation) do
		watchStation(station)
	end
	CollectionService:GetInstanceAddedSignal(Tags.CandyRushStation):Connect(watchStation)
end

-- Your own candies on every stand (usually one at a time).
local function myCandies(me: Player): { Instance }
	local list = {}
	for _, station in CollectionService:GetTagged(Tags.CandyRushStation) do
		local folder = station:FindFirstChild("Candies")
		if folder then
			for _, candy in folder:GetChildren() do
				if candy:IsA("Model") and candy:GetAttribute("OwnerUserId") == me.UserId then
					table.insert(list, candy)
				end
			end
		end
	end
	return list
end

-- Turns whatever arrived over the network into a State (or nil to hide everything).
local function readState(value: unknown): State?
	if type(value) ~= "table" then
		return nil
	end
	local state = value :: any
	if
		type(state.Phase) ~= "string"
		or type(state.Total) ~= "number"
		or type(state.Lanes) ~= "table"
	then
		return nil
	end
	return state :: State
end

function CandyRushUI.Mount(gui: ScreenGui)
	if not Config.Features.CandyRush then
		return
	end
	local me = Players.LocalPlayer
	local phone = Layout.IsPhone()
	local width = if phone then 220 else 250
	local rowHeight = if phone then 22 else 24

	-- The panel on the left -------------------------------------------------------------------
	local panel = Theme.panel(gui)
	panel.Name = "CandyRush"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 12, 0.5, 0)
	panel.Size = UDim2.fromOffset(width, 120)
	panel.Visible = false
	panel.Active = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 105, 180)
	stroke.Thickness = 2
	stroke.Parent = panel
	Layout.Fit(panel)

	local title = Theme.label(text.Title, 18, panel)
	title.Name = "Title"
	title.Font = Enum.Font.FredokaOne
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -90, 0, 26)

	local mine = Theme.label("", 24, panel)
	mine.Name = "YourCandies"
	mine.Font = Enum.Font.FredokaOne
	mine.TextColor3 = GOLD
	mine.TextXAlignment = Enum.TextXAlignment.Right
	mine.AnchorPoint = Vector2.new(1, 0)
	mine.Position = UDim2.new(1, -12, 0, 4)
	mine.Size = UDim2.fromOffset(80, 30)

	local status = Theme.label("", 14, panel)
	status.Name = "Status"
	status.TextColor3 = Theme.Muted
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextWrapped = true
	status.Position = UDim2.fromOffset(12, 32)
	status.Size = UDim2.new(1, -24, 0, 20)

	local list = Instance.new("Frame")
	list.Name = "Lanes"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 56)
	list.Size = UDim2.new(1, -24, 0, 0)
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = list

	local footer = Theme.label("", 14, panel)
	footer.Name = "Footer"
	footer.TextColor3 = GOLD
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 12, 1, -6)
	footer.Size = UDim2.new(1, -24, 0, 18)

	local rows: { [number]: Row } = {}
	-- The length each lane's bar is going to: it slides there when effects are on (shrinking,
	-- e.g. back to 0 for a new race, is instant).
	local fillTarget: { [Frame]: number } = {}
	local function setFill(row: Row, fraction: number)
		local fill = row.Fill
		local before = fillTarget[fill]
		if before == fraction then
			return
		end
		fillTarget[fill] = fraction
		if effectsOn() and before ~= nil and fraction > before and fx.BarSeconds > 0 then
			TweenService:Create(
				fill,
				TweenInfo.new(fx.BarSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(fraction, 1) }
			):Play()
		else
			fill.Size = UDim2.fromScale(fraction, 1)
		end
	end
	local function rowFor(lane: number): Row
		local row = rows[lane]
		if row then
			return row
		end
		local frame = Instance.new("Frame")
		frame.Name = "Lane" .. lane
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = lane
		frame.Size = UDim2.new(1, 0, 0, rowHeight)
		frame.Parent = list
		local dot = Instance.new("Frame")
		dot.Name = "Colour"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.fromScale(0, 0.5)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.Parent = frame
		Theme.round(dot, 6)
		local name = Theme.label("", 14, frame)
		name.Name = "PlayerName"
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Position = UDim2.fromOffset(18, 0)
		name.Size = UDim2.new(0.42, -18, 1, 0)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0.42, 4, 0.5, 0)
		bar.Size = UDim2.new(0.58, -42, 0, 10)
		bar.BackgroundColor3 = Theme.Button
		bar.Parent = frame
		Theme.round(bar, 5)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = bar
		Theme.round(fill, 5)
		local countLabel = Theme.label("", 14, frame)
		countLabel.Name = "Count"
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.AnchorPoint = Vector2.new(1, 0)
		countLabel.Position = UDim2.fromScale(1, 0)
		countLabel.Size = UDim2.new(0, 34, 1, 0)
		local made: Row = { Frame = frame, Dot = dot, Name = name, Fill = fill, Count = countLabel }
		rows[lane] = made
		return made
	end

	-- The big countdown -------------------------------------------------------------------------
	local countdown = Instance.new("TextLabel")
	countdown.Name = "CandyRushCountdown"
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.3)
	countdown.Size = UDim2.fromOffset(if phone then 220 else 300, if phone then 100 else 140)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextScaled = true
	countdown.TextColor3 = GOLD
	countdown.Text = ""
	countdown.Visible = false
	countdown.Active = false
	countdown.ZIndex = 12
	countdown.Parent = gui
	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Thickness = 4
	countdownStroke.Color = Color3.fromRGB(60, 20, 80)
	countdownStroke.Parent = countdown
	local countdownScale = Instance.new("UIScale")
	countdownScale.Parent = countdown
	Layout.KeepBelowHud({ countdown }) -- (on short phone screens 0.3 is on the bar at the top)

	local tiltSide = 1
	local function popText(value: string, seconds: number?)
		countdown.Text = value
		countdown.Visible = true
		local on = effectsOn()
		countdownScale.Scale = if on then fx.CountdownScale else 1.6
		TweenService:Create(
			countdownScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		if on and fx.CountdownTilt ~= 0 then
			-- (each number leans the other way, so 3-2-1 rocks side to side)
			tiltSide = -tiltSide
			countdown.Rotation = tiltSide * fx.CountdownTilt
			TweenService:Create(
				countdown,
				TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Rotation = 0 }
			):Play()
		end
		if seconds then
			task.delay(seconds, function()
				if countdown.Text == value then
					countdown.Visible = false
				end
			end)
		end
	end

	-- The winner banner -------------------------------------------------------------------------
	local banner = Theme.panel(gui)
	banner.Name = "CandyRushBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.26)
	banner.Size = UDim2.fromOffset(if phone then 320 else 420, if phone then 96 else 110)
	banner.Visible = false
	banner.Active = false
	banner.ZIndex = 11
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = GOLD
	bannerStroke.Thickness = 3
	bannerStroke.Parent = banner
	Layout.Fit(banner)
	local bannerTitle = Theme.label("", 34, banner)
	bannerTitle.Name = "Title"
	bannerTitle.Font = Enum.Font.FredokaOne
	bannerTitle.TextScaled = true
	bannerTitle.TextColor3 = GOLD
	bannerTitle.Position = UDim2.fromOffset(12, 8)
	bannerTitle.Size = UDim2.new(1, -24, 0.55, -8)
	local bannerLine = Theme.label("", 16, banner)
	bannerLine.Name = "Details"
	bannerLine.TextWrapped = true
	bannerLine.Position = UDim2.new(0, 12, 0.55, 0)
	bannerLine.Size = UDim2.new(1, -24, 0.45, -8)
	Layout.KeepBelowHud({ banner })

	-- Showing a state ---------------------------------------------------------------------------
	local current: State? = nil
	local lastCount: number? = nil
	local lastPhase = ""
	local shownResult = false

	local function resultLines(state: State): (string, string, boolean)
		local winner = state.Winner
		local won = winner ~= nil and winner.UserId == me.UserId
		local headline: string
		if state.Solo and won and state.Time then
			headline = text.SoloFinish:format(state.Time)
		elseif won then
			headline = text.YouWin
		elseif winner then
			headline = text.YouLose:format(winner.Name)
		elseif state.Reason == "TimeUp" then
			headline = text.TimeUp
		else
			headline = text.NoWinner
		end
		local details = {}
		if state.Out then
			table.insert(details, text.Out)
		end
		if state.Solo and won then
			if state.NewBest then
				table.insert(details, text.NewBest)
			elseif state.Best then
				table.insert(details, text.Best:format(state.Best))
			end
		end
		if state.Coins and state.Coins > 0 then
			table.insert(details, text.CoinsGot:format(state.Coins))
		end
		local note = state.Note and NOTES[state.Note]
		if note then
			table.insert(details, note)
		end
		return headline, table.concat(details, "  "), won
	end

	local function showBanner(state: State)
		local headline, details, won = resultLines(state)
		bannerTitle.Text = headline
		bannerLine.Text = details
		bannerStroke.Color = if won then GOLD else Theme.Muted
		banner.Visible = true
		-- (through Layout.Fit's MotionScale: a second UIScale on the banner would fight its fit)
		MinigameFx.PopFit(banner, 0.6, 0.35)
		play(if won then cfg.Sounds.Win else cfg.Sounds.Lose)
		if won and effectsOn() then
			MinigameFx.Confetti(gui, MinigameFx.Count(fx.WinConfetti))
		end
		task.delay(cfg.ResultsSeconds, function()
			if bannerTitle.Text == headline then
				banner.Visible = false
			end
		end)
	end

	local function elapsed(state: State): number?
		local started = state.StartedAt
		if not started then
			return nil
		end
		return math.max(0, workspace:GetServerTimeNow() - started)
	end

	local function statusLine(state: State): string
		local phase = state.Phase
		if not state.InRace then
			if phase == "Live" or phase == "Results" then
				return text.NextRace
			elseif phase == "Waiting" then
				if state.SoloIn then
					return text.SoloSoon:format(state.SoloIn)
				elseif state.Needed > 0 then
					return text.NeedMore:format(state.Needed)
				end
			end
			return ""
		end
		if state.Out then
			return text.Out
		elseif phase == "Live" then
			local seconds = elapsed(state)
			if state.Solo and seconds then
				return ("%.1fs"):format(seconds)
			end
			return text.RaceOn
		end
		return ""
	end

	local function render(state: State)
		local racing = state.InRace and (state.Phase == "Live" or state.Phase == "Results")
		local myRow: LaneRow? = nil
		local seen: { [number]: boolean } = {}
		for _, info in state.Lanes do
			if type(info) ~= "table" or type(info.Lane) ~= "number" then
				continue
			end
			seen[info.Lane] = true
			local row = rowFor(info.Lane)
			local isMe = info.UserId == me.UserId
			if isMe then
				myRow = info
			end
			row.Frame.Visible = true
			row.Dot.BackgroundColor3 = info.Color
			row.Fill.BackgroundColor3 = info.Color
			row.Name.Text = if isMe then text.You else info.Name
			row.Name.TextColor3 = if isMe then GOLD else Theme.Text
			local shown = state.Phase == "Live" or state.Phase == "Results"
			local fraction = if shown
				then math.clamp(info.Popped / math.max(state.Total, 1), 0, 1)
				else 0
			setFill(row, fraction)
			row.Count.Text = if info.Out
				then text.OutTag
				elseif shown then tostring(info.Popped)
				else ""
			row.Name.TextTransparency = if info.Out then 0.5 else 0
		end
		for lane, row in rows do
			if not seen[lane] then
				row.Frame.Visible = false
			end
		end
		local shownRows = 0
		for _ in seen do
			shownRows += 1
		end
		list.Size = UDim2.new(1, -24, 0, shownRows * (rowHeight + 4))
		panel.Size = UDim2.fromOffset(width, 56 + shownRows * (rowHeight + 4) + 28)
		mine.Text = if racing and myRow then ("%d/%d"):format(myRow.Popped, state.Total) else ""
		status.Text = statusLine(state)
		if state.Solo and state.Best and state.InRace then
			footer.Text = text.Best:format(state.Best)
		else
			footer.Text = ""
		end
		panel.Visible = true
	end

	-- A grab the server counted: sparkles where the candy was, "+1" by your count.
	local lastSpot: Spot? = nil
	local lastPopped: number? = nil
	local function rememberSpot(spot: Spot)
		lastSpot = spot
	end
	local function celebrateGrab()
		local spot = lastSpot
		if spot and os.clock() - spot.At < 1.5 then
			lastSpot = nil
			MinigameFx.Burst(
				spot.Position,
				{ spot.Color, Color3.new(1, 1, 1), GOLD },
				MinigameFx.Count(fx.GrabSparkles)
			)
		end
		MinigameFx.FloatText(panel, fx.PlusText, GOLD, UDim2.new(1, -40, 0, 34))
		MinigameFx.Punch(mine, 1.35)
	end
	local function checkGrab(state: State?)
		local popped: number? = nil
		if state and state.InRace and state.Phase == "Live" and not state.Out then
			for _, info in state.Lanes do
				if type(info) == "table" and info.UserId == me.UserId then
					popped = info.Popped
				end
			end
		end
		local before = lastPopped
		lastPopped = popped
		if popped and before and popped > before and effectsOn() then
			celebrateGrab()
		end
	end

	local function onState(value: unknown)
		local state = readState(value)
		current = state
		checkGrab(state)
		if not state then
			panel.Visible = false
			countdown.Visible = false
			lastCount = nil
			lastPhase = ""
			return
		end
		render(state)
		local phase = state.Phase
		if phase == "Countdown" and state.Count and state.Count ~= lastCount then
			popText(tostring(state.Count))
			play(cfg.Sounds.Tick)
		elseif phase ~= "Countdown" and lastPhase == "Countdown" then
			countdown.Visible = false
		end
		lastCount = if phase == "Countdown" then state.Count else nil
		if phase == "Live" and lastPhase ~= "Live" and state.InRace then
			popText(text.Go, 0.8)
			play(cfg.Sounds.Go)
			shownResult = false
		end
		if phase == "Results" and state.InRace and not shownResult then
			shownResult = true
			showBanner(state)
		elseif phase ~= "Results" then
			shownResult = false
		end
		lastPhase = phase
	end

	-- The solo timer ticks while the race is on.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local state = current
			if
				state
				and state.Phase == "Live"
				and state.InRace
				and state.Solo
				and not state.Out
			then
				status.Text = statusLine(state)
			end
		end
	end)

	task.spawn(watchCandies, me, rememberSpot)
	task.spawn(function()
		-- Required here, not at the top: the remote folder may not exist yet, and nothing above
		-- should wait for it.
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		Remotes.Event("CandyRushState").OnClientEvent:Connect(onState)
		local grab = Remotes.Event("CandyRushGrab")

		-- Clicks and taps: a ray that only sees your own candy, so your character (or a big
		-- hat) between the camera and your lane can't block it. The candies' click detectors
		-- still work too; the server counts whichever arrives first, once.
		local function tryGrab(point: Vector2)
			local state = current
			if not (state and state.InRace and state.Phase == "Live" and not state.Out) then
				return
			end
			local yours = myCandies(me)
			local camera = workspace.CurrentCamera
			if #yours == 0 or not camera then
				return
			end
			local ray = camera:ViewportPointToRay(point.X, point.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = yours
			local hit = workspace:Raycast(ray.Origin, ray.Direction * GRAB_REACH, params)
			local node: Instance? = hit and hit.Instance
			while node and not table.find(yours, node) do
				node = node.Parent
			end
			if node then
				grab:FireServer(node) -- sent right away; the sparkles wait for the server's count
				local spot = candySpot(node)
				if spot then
					rememberSpot(spot)
				end
			end
		end
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
				tryGrab(UserInputService:GetMouseLocation())
			end
		end)
		UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
			if not processedByUI then
				tryGrab(position)
			end
		end)
	end)
end

return CandyRushUI
