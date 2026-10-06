--!strict
--[[
	Parkour screen bits ("Spooky Sky Climb", settings in Config.Parkour; on/off:
	Config.Features.Parkour, off = Mount does nothing and nothing shows).
	ParkourUI.MountCourse(gui, spec) shows the same bits for another course (the Tormented
	Tower, client TowerUI), with its own attributes, remotes and words.

	  ParkourTimer   a small timer just below the bar at the top while you climb, with the
	                 checkpoints you have and a Stop button
	  ParkourPop     short messages: "Checkpoint 2/3!", "Whoops! Back to checkpoint 1"...
	  ParkourFinish  the finish banner: your time, "New best!" and the coins you won
	  ParkourPanel   Menu > Parkour: your best time, finishes, when coins can be won again and
	                 a "Go to start" button (the server checks you are in the lobby)
	Everything it shows comes from the server: the player attributes ParkourRun,
	ParkourStarted, ParkourReached, ParkourBest, ParkourRuns, ParkourRewardAt, the
	ReplicatedStorage attribute ParkourCheckpoints and the ParkourEvent remote. The only thing
	it asks the server is ParkourRequest("GoToStart" | "Stop").
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Layout = require(script.Parent.Layout)
local MenuUI = require(script.Parent.MenuUI)
local PanelManager = require(script.Parent.PanelManager)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local ParkourUI = {}

local cfg = Config.Parkour -- the look, sounds and timings (shared by every course)
local screen = cfg.Screen
local colors = screen.Colors

-- One course's screen: its switch, player attributes (<Prefix>Run...), remotes and words.
export type CourseSpec = {
	Feature: string, -- its Config.Features switch
	Prefix: string, -- player attributes and UI names: <Prefix>Run, <Prefix>Timer...
	CountAttribute: string, -- ReplicatedStorage attribute: how many checkpoints
	Event: string, -- remote names
	Request: string,
	Text: { [string]: string },
	TileId: string, -- its Menu tile
	TileOrder: number,
	Watch: { string }, -- player attributes that change the panel
	FinishLine: (info: { [string]: any }) -> (string, Color3), -- under the finish time
	RewardLine: () -> (string, Color3), -- the prize line in the panel
}

-- A Config.Parkour.Sounds entry ({ SoundId, Volume?, PitchMin?, PitchMax? }).
local function play(spec: any)
	Sounds.PlaySpec(spec)
end

local function number(value: unknown): number
	return if type(value) == "number" and value == value then value else 0
end

local function textSize(label: TextLabel, max: number)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.MinTextSize = Config.UI.MinTextSize
	limit.Parent = label
end

-- Asks the server; returns its answer (never errors, never waits forever on a missing remote).
local function request(name: string, action: string): (boolean, string)
	-- (The remote is made by the course's service on the server, see shared/Remotes.luau.)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if not (remote and remote:IsA("RemoteFunction")) then
		return false, ""
	end
	local ok, done, message = pcall(function()
		return remote:InvokeServer(action)
	end)
	if not ok then
		return false, ""
	end
	return done == true, if type(message) == "string" then message else ""
end

function ParkourUI.MountCourse(gui: ScreenGui, spec: CourseSpec)
	local features = Config.Features :: any
	if not features[spec.Feature] then
		return
	end
	local player = Players.LocalPlayer
	local text = spec.Text
	local prefix = spec.Prefix
	local function attr(name: string): any
		return player:GetAttribute(prefix .. name)
	end

	local function checkpointCount(): number
		return number(ReplicatedStorage:GetAttribute(spec.CountAttribute))
	end

	-- Timer ------------------------------------------------------------------------------------
	local timer = Theme.panel(gui)
	timer.Name = prefix .. "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 80)
	timer.Size = UDim2.fromOffset(230, 54)
	timer.Visible = false
	local time = Theme.label("", 26, timer)
	time.Name = "Time"
	time.Font = Enum.Font.GothamBlack
	time.TextColor3 = colors.Timer
	time.TextXAlignment = Enum.TextXAlignment.Left
	time.Position = UDim2.fromOffset(12, 4)
	time.Size = UDim2.new(1, -84, 0, 30)
	textSize(time, 26)
	local detail = Theme.label("", 14, timer)
	detail.Name = "Detail"
	detail.TextColor3 = Theme.Muted
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Position = UDim2.fromOffset(12, 32)
	detail.Size = UDim2.new(1, -84, 0, 18)
	local stopButton = Theme.button(text.Stop, timer)
	stopButton.Name = "Stop"
	stopButton.TextSize = 15
	stopButton.AnchorPoint = Vector2.new(1, 0.5)
	stopButton.Position = UDim2.new(1, -8, 0.5, 0)
	stopButton.Size = UDim2.fromOffset(62, 36)
	stopButton.Activated:Connect(function()
		task.spawn(request, spec.Request, "Stop")
	end)

	-- Keep the timer just below the bar at the top (the Hud), wherever that is.
	local function place()
		local hud = gui:FindFirstChild("Hud")
		local y = 80
		if hud and hud:IsA("GuiObject") and hud.Visible and hud.AbsoluteSize.Y > 0 then
			local scale = math.max(Layout.Scale(), 0.01)
			local bottom = hud.AbsolutePosition.Y + hud.AbsoluteSize.Y - gui.AbsolutePosition.Y
			y = bottom / scale + screen.TimerGap
		end
		timer.Position = UDim2.new(0.5, 0, 0, y)
	end
	local watched: Instance? = nil
	local function watchHud(child: Instance)
		if child == watched or child.Name ~= "Hud" or not child:IsA("GuiObject") then
			return
		end
		watched = child
		child:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		child:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		child:GetPropertyChangedSignal("Visible"):Connect(place)
		place()
	end
	local hud = gui:FindFirstChild("Hud")
	if hud then
		watchHud(hud)
	end
	gui.ChildAdded:Connect(function(child)
		task.defer(watchHud, child) -- the Hud is named right after it is parented
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	local function refreshTimer()
		local state = attr("Run")
		local running = state == "Running"
		timer.Visible = state == "Ready" or running
		if not timer.Visible then
			return
		end
		local count = checkpointCount()
		local reached = number(attr("Reached"))
		if running then
			local elapsed = workspace:GetServerTimeNow() - number(attr("Started"))
			time.Text = text.Timer:format(ParkourLogic.FormatTime(elapsed))
		else
			time.Text = text.Ready
		end
		detail.Text = if count > 0 then text.CheckpointCount:format(reached, count) else ""
	end
	player:GetAttributeChangedSignal(prefix .. "Run"):Connect(refreshTimer)
	player:GetAttributeChangedSignal(prefix .. "Reached"):Connect(refreshTimer)
	RunService.Heartbeat:Connect(function()
		if timer.Visible and attr("Run") == "Running" then
			refreshTimer()
		end
	end)
	refreshTimer()

	-- Short messages ---------------------------------------------------------------------------
	local popLabel = Theme.label("", 34, gui)
	popLabel.Name = prefix .. "Pop"
	popLabel.Font = Enum.Font.GothamBlack
	popLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	popLabel.Position = UDim2.fromScale(0.5, 0.34)
	popLabel.Size = UDim2.new(0.9, 0, 0, 52) -- the words shrink to fit narrow phones
	local widest = Instance.new("UISizeConstraint")
	widest.MaxSize = Vector2.new(560, 52)
	widest.Parent = popLabel
	popLabel.TextStrokeTransparency = 0.2
	popLabel.Visible = false
	popLabel.ZIndex = 6
	textSize(popLabel, 34)
	-- On short phone screens 0.34 of the height is where the timer is: the messages go just
	-- below the timer instead, so the clock stays readable.
	Layout.KeepBelowHud({ popLabel }, timer)
	local popId = 0
	local function pop(message: string, color: Color3)
		popId += 1
		local id = popId
		popLabel.Text = message
		popLabel.TextColor3 = color
		popLabel.TextTransparency = 0
		popLabel.TextStrokeTransparency = 0.2
		popLabel.Visible = true
		task.delay(screen.PopSeconds, function()
			if popId ~= id then
				return
			end
			local fade = TweenService:Create(
				popLabel,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fade:Play()
			fade.Completed:Once(function()
				if popId == id then
					popLabel.Visible = false
				end
			end)
		end)
	end

	-- Finish banner ----------------------------------------------------------------------------
	local banner = Theme.panel(gui)
	banner.Name = prefix .. "Finish"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.42)
	banner.Size = UDim2.fromOffset(380, 176)
	banner.BackgroundTransparency = 0.05
	banner.ZIndex = 7 -- under the round results (8)
	banner.Visible = false
	Layout.Fit(banner)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.Finish
	stroke.Thickness = 3
	stroke.Parent = banner
	local function bannerLine(name: string, y: number, height: number, size: number): TextLabel
		local label = Theme.label("", size, banner)
		label.Name = name
		label.Position = UDim2.fromOffset(16, y)
		label.Size = UDim2.new(1, -32, 0, height)
		textSize(label, size)
		return label
	end
	local bannerTitle = bannerLine("Title", 10, 40, 32)
	bannerTitle.Font = Enum.Font.Creepster
	bannerTitle.TextColor3 = colors.Finish
	local bannerTime = bannerLine("Time", 54, 32, 26)
	bannerTime.Font = Enum.Font.GothamBlack
	local bannerBest = bannerLine("Best", 90, 26, 20)
	local bannerCoins = bannerLine("Coins", 122, 26, 20)
	local closeBanner = Theme.button("X", banner)
	closeBanner.Name = "Close"
	closeBanner.AnchorPoint = Vector2.new(1, 0)
	closeBanner.Position = UDim2.new(1, -8, 0, 8)
	closeBanner.Size = UDim2.fromOffset(32, 32)
	local bannerId = 0
	closeBanner.Activated:Connect(function()
		bannerId += 1
		banner.Visible = false
	end)
	local function showFinish(info: { [string]: any })
		local finishTime = number(info.Time)
		local best = number(info.Best)
		bannerTitle.Text = text.Finished
		bannerTime.Text = text.FinishTime:format(ParkourLogic.FormatTime(finishTime))
		if info.NewBest == true then
			bannerBest.Text = text.NewBest
			bannerBest.TextColor3 = colors.NewBest
		else
			bannerBest.Text = text.Best:format(ParkourLogic.FormatTime(best))
			bannerBest.TextColor3 = Theme.Muted
		end
		local line, lineColor = spec.FinishLine(info)
		bannerCoins.Text = line
		bannerCoins.TextColor3 = lineColor
		bannerId += 1
		local id = bannerId
		banner.Visible = true
		task.delay(screen.FinishSeconds, function()
			if bannerId == id then
				banner.Visible = false
			end
		end)
	end

	-- Panel (Menu > Parkour) -------------------------------------------------------------------
	local panel = Theme.panel(gui)
	panel.Name = prefix .. "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 280)
	panel.ZIndex = 10
	panel.BackgroundTransparency = 0.03
	panel.Visible = false
	Layout.Fit(panel)
	PanelManager.Register(panel)
	local panelTitle = Theme.label(text.PanelTitle, 26, panel)
	panelTitle.Name = "Title"
	panelTitle.Font = Enum.Font.Creepster
	panelTitle.TextColor3 = colors.Timer
	panelTitle.Position = UDim2.fromOffset(16, 8)
	panelTitle.Size = UDim2.new(1, -72, 0, 40)
	panelTitle.TextXAlignment = Enum.TextXAlignment.Left
	local closePanel = Theme.button("X", panel)
	closePanel.Name = "Close"
	closePanel.AnchorPoint = Vector2.new(1, 0)
	closePanel.Position = UDim2.new(1, -12, 0, 10)
	closePanel.Size = UDim2.fromOffset(40, 36)
	closePanel.Activated:Connect(function()
		panel.Visible = false
	end)
	local function panelLine(name: string, y: number, height: number): TextLabel
		local label = Theme.label("", 16, panel)
		label.Name = name
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Position = UDim2.fromOffset(18, y)
		label.Size = UDim2.new(1, -36, 0, height)
		return label
	end
	local bestLine = panelLine("Best", 54, 26)
	bestLine.TextSize = 20
	local runsLine = panelLine("Runs", 82, 22)
	runsLine.TextColor3 = Theme.Muted
	local rewardLine = panelLine("Reward", 106, 44)
	local messageLine = panelLine("Message", 152, 40)
	messageLine.TextColor3 = colors.Checkpoint
	local goButton = Theme.button(text.GoToStart, panel, Theme.Selected)
	goButton.Name = "GoToStart"
	goButton.TextSize = 18
	goButton.AnchorPoint = Vector2.new(0, 1)
	goButton.Position = UDim2.new(0, 18, 1, -16)
	goButton.Size = UDim2.new(0.6, -24, 0, 46)
	local closeButton = Theme.button(text.Close, panel)
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.new(1, -18, 1, -16)
	closeButton.Size = UDim2.new(0.4, -12, 0, 46)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local function refreshPanel()
		local best = number(attr("Best"))
		bestLine.Text = if best > 0
			then text.Best:format(ParkourLogic.FormatTime(best))
			else text.NoBest
		runsLine.Text = text.Runs:format(number(attr("Runs")))
		local line, lineColor = spec.RewardLine()
		rewardLine.Text = line
		rewardLine.TextColor3 = lineColor
	end
	for _, name in spec.Watch do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				refreshPanel()
			end
		end)
	end
	local busy = false
	goButton.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local done, message = request(spec.Request, "GoToStart")
			busy = false
			if done then
				panel.Visible = false
				pop(message, colors.Checkpoint)
			else
				messageLine.Text = message
			end
		end)
	end)
	local ticking = false -- the 1-second refresh below is running (only ever one)
	local function openPanel()
		messageLine.Text = ""
		refreshPanel()
		panel.Visible = true
		if ticking then
			return -- closed and opened again within a second: the running loop carries on
		end
		ticking = true
		-- Keep the reward countdown ticking while it is open.
		task.spawn(function()
			while panel.Visible do
				task.wait(1)
				if panel.Visible then
					refreshPanel()
				end
			end
			ticking = false
		end)
	end

	if Config.Features.Menu then
		MenuUI.AddTile({
			Id = spec.TileId,
			Label = text.Tile,
			Order = spec.TileOrder,
			Visible = function()
				return features[spec.Feature] == true
			end,
			Status = function(): string?
				local best = number(attr("Best"))
				return if best > 0 then ParkourLogic.FormatTime(best) else nil
			end,
			OnClick = openPanel,
		})
	else
		local button = Layout.SideButton(text.Tile, spec.TileOrder)
		button.Name = prefix .. "Button"
		button.Activated:Connect(function()
			if panel.Visible then
				panel.Visible = false
			else
				openPanel()
			end
		end)
	end

	-- What the server tells us ------------------------------------------------------------------
	task.spawn(function()
		-- Required here, not at the top: it waits for the server's Remotes folder.
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		local event = Remotes.Event(spec.Event)
		event.OnClientEvent:Connect(function(kind: unknown, info: unknown)
			if type(kind) ~= "string" then
				return
			end
			local data: { [string]: any } = if type(info) == "table" then info :: any else {}
			if kind == "Start" then
				play(cfg.Sounds.Start)
			elseif kind == "Checkpoint" then
				pop(
					text.Checkpoint:format(number(data.Index), number(data.Count)),
					colors.Checkpoint
				)
				play(cfg.Sounds.Checkpoint)
			elseif kind == "Back" then
				local checkpoint = number(data.Checkpoint)
				local message
				if data.Reason == "Hazard" then
					message = if checkpoint > 0
						then text.Slimed:format(checkpoint)
						else text.SlimedStart
				else
					message = if checkpoint > 0
						then text.Fell:format(checkpoint)
						else text.FellStart
				end
				pop(message, colors.Back)
				play(cfg.Sounds.Back)
			elseif kind == "Missed" then
				pop(text.Missed:format(number(data.Next)), colors.Back)
			elseif kind == "NeedCheckpoints" then
				pop(text.NeedCheckpoints, colors.Back)
			elseif kind == "NeedStart" then
				pop(text.NeedStart, colors.Timer)
			elseif kind == "Finish" then
				showFinish(data)
				play(cfg.Sounds.Finish)
				if data.NewBest == true then
					task.delay(0.6, play, cfg.Sounds.NewBest)
				end
			elseif kind == "Cancel" then
				local reasons: { [string]: string } = {
					Stopped = text.Stopped,
					TooFast = text.TooFast,
					Cheat = text.TooFast,
					Left = text.Left,
					TimeUp = text.TimeUp,
				}
				local message = reasons[tostring(data.Reason)]
				if message then
					pop(message, colors.Back)
				end
			end
		end)
	end)
end

-- The lobby parkour ("Spooky Sky Climb"): coins once every Reward.CooldownHours.
function ParkourUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local text = cfg.Text
	ParkourUI.MountCourse(gui, {
		Feature = "Parkour",
		Prefix = "Parkour",
		CountAttribute = "ParkourCheckpoints",
		Event = "ParkourEvent",
		Request = "ParkourRequest",
		Text = text,
		TileId = "Parkour",
		TileOrder = 10,
		Watch = { "ParkourBest", "ParkourRuns", "ParkourRewardAt" },
		FinishLine = function(info: { [string]: any }): (string, Color3)
			local coins = number(info.Coins)
			if coins > 0 then
				return text.Coins:format(coins, Config.Economy.CurrencyName), colors.Finish
			end
			return text.CoinsLater:format(ParkourLogic.FormatWait(number(info.Wait))), Theme.Muted
		end,
		RewardLine = function(): (string, Color3)
			local wait = number(player:GetAttribute("ParkourRewardAt"))
				- workspace:GetServerTimeNow()
			if wait > 0 then
				return text.RewardWait:format(ParkourLogic.FormatWait(wait)), Theme.Muted
			end
			return text.RewardReady:format(cfg.Reward.Coins, Config.Economy.CurrencyName),
				colors.Finish
		end,
	})
end

return ParkourUI
