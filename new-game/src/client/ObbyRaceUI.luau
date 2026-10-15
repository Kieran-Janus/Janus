--!strict
--[[
	Spooky Obby screen (settings and every text: Config.ObbyRace). Shows only for players in a
	Spooky Obby round (the ReplicatedStorage attribute Mode is "ObbyRace" and the player
	attribute InRound is true). On/off: Config.Features.ObbyRace (off = Mount does nothing).

	  - a pill under the top bar: "Checkpoint 3/5 | 1:23 | 2nd place"
	  - "Get ready..." with a big 3-2-1, then GO!
	  - "Checkpoint 2/5!" with sparkles, "Whoops! Back to checkpoint 2" when sent back
	  - a "Back to checkpoint" button (key R, gamepad Y; on phones above the jump button) for
	    when you are stuck. The server decides: the button only asks (remote ObbyRaceBack).
	  - FINISHED! "2nd place!" with confetti, and "<name> finished! Hurry up!" for the others
	  - the ghost sweeper bars turn on this screen (the server judges hits with the same maths,
	    src/shared/ObbyRaceRules.luau), only while you race and only near your camera
	Everything here is a look: what counts is decided on the server
	(src/server/Modes/ObbyRace.luau). The remote is only looked up once a Spooky Obby round is
	on: the server makes it when it loads the mode, before it tells clients the mode.
]]
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Rules = require(ReplicatedStorage.Shared.ObbyRaceRules)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local ObbyRaceUI = {}

local MODE = "ObbyRace"
local ACTION = "ObbyRaceBack"
local ATTR = Rules.Attributes
local SHARED = Rules.Shared
local PARTS = Rules.Parts

-- A big outlined label that shrinks to fit narrow phone screens.
local function shout(name: string, size: number, parent: Instance): TextLabel
	local label = Theme.label("", size, parent)
	label.Name = name
	label.Font = Enum.Font.GothamBlack
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Visible = false
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = math.min(size, Config.UI.MinTextSize)
	limit.Parent = label
	return label
end

local function number(value: unknown): number?
	return if typeof(value) == "number" then value else nil
end

function ObbyRaceUI.Mount(gui: ScreenGui)
	if not Config.Features.ObbyRace then
		return
	end
	local cfg = Config.ObbyRace
	local text = cfg.Text
	local colors = cfg.Colors
	local effects = cfg.Effects
	local player = Players.LocalPlayer

	local root = Instance.new("Frame")
	root.Name = "ObbyRace"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui

	-- Checkpoint / time / place, under the top bar.
	local pill = Theme.panel(root)
	pill.Name = "Info"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0.02, 72)
	pill.Size = UDim2.fromOffset(if Layout.IsPhone() then 340 else 420, 34)
	local pillText = Theme.label("", 17, pill)
	pillText.Name = "Text"
	pillText.Size = UDim2.fromScale(1, 1)
	pillText.RichText = true
	pillText.TextScaled = true
	local pillLimit = Instance.new("UITextSizeConstraint")
	pillLimit.MaxTextSize = 17
	pillLimit.MinTextSize = Config.UI.MinTextSize
	pillLimit.Parent = pillText
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = pillText

	-- Big messages in the middle.
	local message = shout("Message", 48, root)
	message.Position = UDim2.fromScale(0.5, 0.36)
	message.Size = UDim2.new(0.92, 0, 0, 58)
	local subMessage = shout("SubMessage", 24, root)
	subMessage.Position = UDim2.new(0.5, 0, 0.36, 48)
	subMessage.Size = UDim2.new(0.92, 0, 0, 32)
	subMessage.TextWrapped = true
	Layout.KeepBelowHud({ message, subMessage }, pill)
	local countdown = shout("Countdown", 100, root)
	countdown.TextColor3 = colors.Timer
	countdown.Position = UDim2.fromScale(0.5, 0.58)
	countdown.Size = UDim2.fromOffset(200, 120)

	-- Back to checkpoint.
	local touch = Layout.IsTouch()
	local back = Theme.button(text.BackButton, root, colors.Button)
	back.Name = "BackButton"
	back.Font = Enum.Font.GothamBlack
	back.TextScaled = true
	local backLimit = Instance.new("UITextSizeConstraint")
	backLimit.MaxTextSize = 18
	backLimit.MinTextSize = Config.UI.MinTextSize
	backLimit.Parent = back
	back.AnchorPoint = Vector2.new(1, 1)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local bigJump = math.min(viewport.X, viewport.Y) > 500
	back.Position = if touch
		then UDim2.new(1, -20, 1, if bigJump then -235 else -170)
		else UDim2.new(1, -30, 1, -30)
	back.Size = UDim2.fromOffset(if touch then 120 else 180, if touch then 56 else 50)
	back.Visible = false
	local backPad = Instance.new("UIPadding")
	backPad.PaddingLeft = UDim.new(0, 8)
	backPad.PaddingRight = UDim.new(0, 8)
	backPad.PaddingTop = UDim.new(0, 4)
	backPad.PaddingBottom = UDim.new(0, if touch then 4 else 14)
	backPad.Parent = back
	local backKey = Theme.label(text.BackKey, 12, back)
	backKey.Name = "Key"
	backKey.AnchorPoint = Vector2.new(0.5, 1)
	backKey.Position = UDim2.new(0.5, 0, 1, 12)
	backKey.Size = UDim2.new(1, 0, 0, 12)
	backKey.TextColor3 = Theme.Muted
	backKey.Visible = not touch

	-- State ---------------------------------------------------------------------------------------
	local function roundState(): string
		local state = ReplicatedStorage:GetAttribute("State")
		return if typeof(state) == "string" then state else ""
	end
	local function inRound(): boolean
		return ReplicatedStorage:GetAttribute("Mode") == MODE
			and player:GetAttribute("InRound") == true
			and player:GetAttribute(ATTR.Total) ~= nil
	end
	local function finished(): boolean
		return number(player:GetAttribute(ATTR.Place)) ~= nil
	end

	local messageToken = 0
	local function showMessage(main: string, color: Color3, seconds: number, sub: string?)
		messageToken += 1
		local token = messageToken
		message.Text = main
		message.TextColor3 = color
		message.Visible = true
		subMessage.Text = sub or ""
		subMessage.Visible = sub ~= nil
		if ScreenFx.On() then
			ScreenFx.Punch(message, 1.4, 0.25)
		end
		task.delay(seconds, function()
			if token == messageToken then
				message.Visible = false
				subMessage.Visible = false
			end
		end)
	end

	local function refreshPill()
		local reached = number(player:GetAttribute(ATTR.Checkpoint)) or 0
		local total = number(player:GetAttribute(ATTR.Total)) or 0
		local left = number(ReplicatedStorage:GetAttribute("TimeLeft")) or 0
		local place = number(player:GetAttribute(ATTR.Place))
			or number(player:GetAttribute(ATTR.Rank))
		local parts = {
			('<font color="#%s">%s</font>'):format(
				colors.Checkpoint:ToHex(),
				text.Checkpoint:format(reached, total)
			),
			('<font color="#%s">%d:%02d</font>'):format(
				colors.Timer:ToHex(),
				left // 60,
				left % 60
			),
		}
		if place then
			table.insert(parts, text.Place:format(Rules.Ordinal(place)))
		end
		pillText.Text = table.concat(parts, "  |  ")
	end

	-- Back to checkpoint -------------------------------------------------------------------------
	local backRemote: RemoteEvent? = nil
	local function doBack()
		if not back.Visible then
			return
		end
		local readyAt = number(player:GetAttribute(ATTR.BackReadyAt)) or 0
		if workspace:GetServerTimeNow() < readyAt then
			return
		end
		local remote = backRemote
		if remote then
			remote:FireServer()
		end
	end
	back.Activated:Connect(doBack)
	local bound = false
	local function bindBack(on: boolean)
		if on == bound then
			return
		end
		bound = on
		if on then
			ContextActionService:BindAction(ACTION, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					doBack()
				end
				return Enum.ContextActionResult.Sink
			end, false, table.unpack(cfg.BackKeys))
		else
			ContextActionService:UnbindAction(ACTION)
		end
	end

	local hooked = false
	local function hookRemotes()
		if hooked then
			return
		end
		hooked = true
		task.spawn(function()
			-- Required here, not at the top: on the client, Remotes waits for the server's
			-- Remotes folder, and this screen must mount without a server (feature tests).
			local Remotes = require(ReplicatedStorage.Shared.Remotes)
			backRemote = Remotes.Event(Rules.Remotes.Back)
		end)
	end

	-- Ghost sweepers turn on this screen while the race is on --------------------------------------
	type Bar = { Part: BasePart, Center: Vector3, Phase: number }
	local bars: { Bar } = {}
	local spin: RBXScriptConnection? = nil
	local function collectBars()
		table.clear(bars)
		local map = workspace:FindFirstChild("Map")
		for _, instance in CollectionService:GetTagged(Tags.ObbySweeper) do
			if instance:IsA("BasePart") and map and instance:IsDescendantOf(map) then
				local center = instance:GetAttribute(PARTS.Center)
				table.insert(bars, {
					Part = instance,
					Center = if typeof(center) == "Vector3" then center else instance.Position,
					Phase = number(instance:GetAttribute(PARTS.Phase)) or 0,
				})
			end
		end
	end
	local function turnBars()
		local started = number(ReplicatedStorage:GetAttribute(SHARED.StartedAt))
		if not started then
			return
		end
		local cam = workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else nil
		local elapsed = workspace:GetServerTimeNow() - started
		for _, bar in bars do
			local part = bar.Part
			if
				part.Parent and (not eye or (bar.Center - eye).Magnitude <= effects.SweeperRange)
			then
				local speed = number(part:GetAttribute(PARTS.Speed)) or 0
				part.CFrame =
					Rules.SweeperCFrame(bar.Center, Rules.SweeperAngle(bar.Phase, speed, elapsed))
			end
		end
	end
	local function setSpinning(on: boolean)
		if on then
			collectBars() -- (again on every refresh: the map may have changed)
			if not spin then
				spin = RunService.RenderStepped:Connect(turnBars)
			end
		elseif not on and spin then
			spin:Disconnect()
			spin = nil
			table.clear(bars)
		end
	end

	-- What shows when ---------------------------------------------------------------------------
	local lastState = roundState()
	local function refresh()
		if ReplicatedStorage:GetAttribute("Mode") == MODE then
			hookRemotes()
		end
		local state = roundState()
		local show = inRound() and (state == "Playing" or state == "Get ready")
		root.Visible = show
		local racing = show and state == "Playing" and not finished()
		back.Visible = racing
		bindBack(racing)
		setSpinning(show and state == "Playing")
		if show then
			refreshPill()
		end
		if not show then
			countdown.Visible = false
		end
	end

	local function onState()
		local state = roundState()
		if inRound() then
			if state == "Get ready" and lastState ~= "Get ready" then
				showMessage(text.GetReady, colors.Timer, cfg.IntroSeconds, text.Hint)
			elseif state == "Playing" and lastState == "Get ready" then
				countdown.Visible = false
				showMessage(text.Go, colors.Checkpoint, 1.2)
			end
		end
		lastState = state
		refresh()
	end

	local function onTimeLeft()
		local left = number(ReplicatedStorage:GetAttribute("TimeLeft"))
		if inRound() and roundState() == "Get ready" and left and left <= 3 and left > 0 then
			countdown.Text = tostring(left)
			countdown.Visible = true
			if ScreenFx.On() then
				ScreenFx.Punch(countdown, 1.6, 0.3)
			end
			Sounds.Play("CountdownTick")
		end
		if root.Visible then
			refreshPill()
		end
	end

	local lastCheckpoint = number(player:GetAttribute(ATTR.Checkpoint)) or 0
	player:GetAttributeChangedSignal(ATTR.Checkpoint):Connect(function()
		local now = number(player:GetAttribute(ATTR.Checkpoint)) or 0
		if now > lastCheckpoint and inRound() then
			local total = number(player:GetAttribute(ATTR.Total)) or now
			showMessage(
				text.CheckpointReached:format(now, total),
				colors.Checkpoint,
				effects.PopSeconds
			)
			Sounds.PlaySpec(cfg.Sounds.Checkpoint :: any)
			if MinigameFx.Enabled(effects) then
				ScreenFx.Burst(
					gui,
					message.Position,
					effects.CheckpointColors,
					ScreenFx.Count(effects.CheckpointSparkles)
				)
			end
		end
		lastCheckpoint = now
		refresh()
	end)

	player:GetAttributeChangedSignal(ATTR.Back):Connect(function()
		local count = number(player:GetAttribute(ATTR.Back)) or 0
		if count <= 0 or not inRound() then
			return
		end
		local reason = player:GetAttribute(ATTR.BackReason)
		local at = number(player:GetAttribute(ATTR.Checkpoint)) or 0
		local pick: { [string]: { string } } = {
			Fell = { text.Fell, text.FellStart },
			Button = { text.Fell, text.FellStart },
			Goo = { text.Goo, text.GooStart },
			Swept = { text.Swept, text.SweptStart },
			TooFast = { text.TooFast, text.TooFastStart },
		}
		local words = pick[if typeof(reason) == "string" then reason else "Fell"] or pick.Fell
		local line = if at > 0 then words[1]:format(at) else words[2]
		showMessage(line, colors.Back, effects.PopSeconds)
		Sounds.PlaySpec(cfg.Sounds.Back :: any)
	end)

	player:GetAttributeChangedSignal(ATTR.Place):Connect(function()
		local place = number(player:GetAttribute(ATTR.Place))
		if place and inRound() then
			local seconds = number(player:GetAttribute(ATTR.Time)) or 0
			showMessage(
				text.Finished,
				colors.Finish,
				effects.FinishSeconds,
				text.FinishedPlace:format(Rules.Ordinal(place))
					.. "  "
					.. text.FinishTime:format(ParkourLogic.FormatTime(seconds))
			)
			Sounds.PlaySpec(cfg.Sounds.Finish :: any)
			if MinigameFx.Enabled(effects) then
				MinigameFx.Confetti(
					gui,
					ScreenFx.Count(
						if place == 1 then effects.WinnerConfetti else effects.FinishConfetti
					)
				)
				ScreenFx.Burst(gui, message.Position, effects.CheckpointColors, ScreenFx.Count(30))
			end
		end
		refresh()
	end)

	ReplicatedStorage:GetAttributeChangedSignal(SHARED.Leader):Connect(function()
		local leader = ReplicatedStorage:GetAttribute(SHARED.Leader)
		if typeof(leader) == "string" and inRound() and not finished() then
			showMessage(text.Hurry:format(leader), colors.Hurry, 2.5)
		end
	end)

	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(onState)
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(onTimeLeft)
	ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(SHARED.StartedAt):Connect(refresh)
	for _, name in { "InRound", ATTR.Total, ATTR.Rank } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return ObbyRaceUI
