--!strict
--[[
	ScareMaze screen (settings and every text: Config.ScareMaze). Shows only for players in a
	ScareMaze round (the ReplicatedStorage attribute Mode is "ScareMaze" and the player
	attribute InRound is true).
	On/off: Config.Features.ScareMaze (off = Mount does nothing and nothing shows).

	  - a pill under the top bar: your team, Survivors still in the maze, Survivors escaped
	  - "You're a SURVIVOR / HAUNTER!" when the round starts
	  - Survivors: the KEEP MOVING meter at the bottom. It drains while you stand still and
	    fills up when you move; a big red 3-2-1 when you're about to be out. (It works out the
	    same thing the server does, with src/shared/ScareMazeRules.luau; the server decides.)
	  - Haunters: a big BOO! button (key E or gamepad X, Config.ScareMaze.Boo.Keys) with its
	    cooldown, and the Survivors outlined through the walls (src/client/ScareMazeXRay.luau)
	  - ESCAPED! / "You stopped!" / "Now you're a Haunter" / "+1 catch!" messages
	  - the full-screen jumpscare when the server says so (src/client/ScareMazeJumpscare.luau)
	Motion (Config.ScreenMotion.ScareMaze): the team banner pops in with a little shake, each
	3-2-1 number punches in (never too big to read), BOO squashes when pressed and bumps when
	ready, a ring round it fills up with the real cooldown, escaping throws confetti. BOO is
	sent the moment you press: the animation only follows.
	The remotes (ScareMazeBoo, ScareMazeScare) are only looked up once a ScareMaze round is on:
	the server makes them when it loads the mode, before it tells clients the mode.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.ScareMazeRules)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local ScareMazeJumpscare = require(script.Parent.ScareMazeJumpscare)
local ScareMazeXRay = require(script.Parent.ScareMazeXRay)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local ScareMazeUI = {}

local ACTION = "ScareMazeBoo"
local ATTR = Rules.Attributes
local MODE = "ScareMaze"

-- A big outlined label for messages in the middle of the screen.
local function shout(name: string, size: number, parent: Instance): TextLabel
	local label = Theme.label("", size, parent)
	label.Name = name
	label.Font = Enum.Font.GothamBlack
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Visible = false
	-- Shrinks to fit narrow phone screens, never bigger than `size`.
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = math.min(size, Config.UI.MinTextSize)
	limit.Parent = label
	return label
end

function ScareMazeUI.Mount(gui: ScreenGui)
	if not Config.Features.ScareMaze then
		return
	end
	local cfg = Config.ScareMaze
	local text = cfg.Text
	local colors = cfg.Colors
	local motion = Config.ScreenMotion.ScareMaze
	local player = Players.LocalPlayer

	local root = Instance.new("Frame")
	root.Name = "ScareMaze"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui

	-- Team / Survivors left / escaped, under the top bar.
	local pill = Theme.panel(root)
	pill.Name = "Info"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0.02, 72)
	pill.Size = UDim2.fromOffset(440, 32)
	local pillText = Theme.label("", 16, pill)
	pillText.Name = "Text"
	pillText.Size = UDim2.fromScale(1, 1)
	pillText.RichText = true
	pillText.TextScaled = true -- long counts shrink a little instead of spilling out
	local pillLimit = Instance.new("UITextSizeConstraint")
	pillLimit.MaxTextSize = 16
	pillLimit.MinTextSize = Config.UI.MinTextSize
	pillLimit.Parent = pillText
	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 10)
	pillPadding.PaddingRight = UDim.new(0, 10)
	pillPadding.PaddingTop = UDim.new(0, 6)
	pillPadding.PaddingBottom = UDim.new(0, 6)
	pillPadding.Parent = pillText

	-- "You're a SURVIVOR!" at the start.
	local teamTitle = shout("TeamTitle", 40, root)
	teamTitle.Position = UDim2.fromScale(0.5, 0.28)
	teamTitle.Size = UDim2.new(0.92, 0, 0, 50)
	local teamHint = shout("TeamHint", 22, root)
	teamHint.Position = UDim2.new(0.5, 0, 0.28, 44)
	teamHint.Size = UDim2.new(0.92, 0, 0, 30)
	teamHint.TextWrapped = true
	-- On short phone screens they move down together, clear of the top bar and the pill.
	Layout.KeepBelowHud({ teamTitle, teamHint }, pill)

	-- ESCAPED! / You stopped! / +1 catch!
	local message = shout("Message", 46, root)
	message.Position = UDim2.fromScale(0.5, 0.4)
	message.Size = UDim2.new(0.92, 0, 0, 56)
	local subMessage = shout("SubMessage", 22, root)
	subMessage.Position = UDim2.new(0.5, 0, 0.4, 46)
	subMessage.Size = UDim2.new(0.92, 0, 0, 30)

	-- The red 3-2-1.
	local countdown = shout("Countdown", 100, root)
	countdown.TextColor3 = colors.MeterEmpty
	countdown.Position = UDim2.fromScale(0.5, 0.6)
	countdown.Size = UDim2.fromOffset(200, 120)

	-- KEEP MOVING meter.
	local meter = Theme.panel(root)
	meter.Name = "KeepMoving"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -24)
	meter.Size = UDim2.fromOffset(if Layout.IsPhone() then 300 else 380, 60)
	meter.Visible = false
	local meterLabel = Theme.label(text.KeepMoving, 20, meter)
	meterLabel.Name = "Label"
	meterLabel.Font = Enum.Font.GothamBlack
	meterLabel.Position = UDim2.fromOffset(0, 4)
	meterLabel.Size = UDim2.new(1, 0, 0, 26)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromOffset(12, 34)
	bar.Size = UDim2.new(1, -24, 0, 16)
	bar.Parent = meter
	Theme.round(bar, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colors.MeterFull
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar
	Theme.round(fill, 8)

	-- BOO! button (Haunters).
	local touch = Layout.IsTouch()
	local boo = Theme.button(text.BooButton, root, colors.Haunters)
	boo.Name = "BooButton"
	boo.Font = Enum.Font.GothamBlack
	boo.TextSize = 30
	boo.AnchorPoint = Vector2.new(1, 1)
	-- On phones it sits above the jump button. Roblox's jump button is bigger and higher on
	-- screens whose short side is over 500 pixels (tablets, big phones), so BOO goes higher there.
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local bigJump = math.min(viewport.X, viewport.Y) > 500
	boo.Position = if touch
		then UDim2.new(1, -20, 1, if bigJump then -235 else -170)
		else UDim2.new(1, -30, 1, -30)
	boo.Size = UDim2.fromOffset(if touch then 100 else 116, if touch then 100 else 116)
	boo.Visible = false
	-- Round: Theme.button already gave it a UICorner, make that one a circle.
	local booCorner = boo:FindFirstChildOfClass("UICorner")
	if booCorner then
		booCorner.CornerRadius = UDim.new(0.5, 0)
	end
	local booStroke = Instance.new("UIStroke")
	booStroke.Thickness = 3
	booStroke.Color = Color3.new(1, 1, 1)
	booStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	booStroke.Parent = boo
	if ScreenFx.On() then
		UIMotion.Press(boo) -- squashes under your finger
	end
	local booKey = Theme.label(text.BooKey, 14, boo)
	booKey.Name = "Key"
	booKey.AnchorPoint = Vector2.new(0.5, 1)
	booKey.Position = UDim2.new(0.5, 0, 1, -10)
	booKey.Size = UDim2.new(1, 0, 0, 16)
	booKey.Visible = not touch
	local booShade = Instance.new("TextLabel")
	booShade.Name = "Cooldown"
	booShade.BackgroundColor3 = Color3.new(0, 0, 0)
	booShade.BackgroundTransparency = 0.4
	booShade.Size = UDim2.fromScale(1, 1)
	booShade.Font = Enum.Font.GothamBlack
	booShade.TextSize = 34
	booShade.TextColor3 = Theme.Text
	booShade.Visible = false
	booShade.Parent = boo
	local shadeCorner = Instance.new("UICorner")
	shadeCorner.CornerRadius = UDim.new(0.5, 0)
	shadeCorner.Parent = booShade

	-- The cooldown ring round the button: two half circles, each a clipped ring whose
	-- UIGradient hides part of it; turning the gradients sweeps the ring round clockwise from
	-- the top. Set every frame from the real cooldown, so it fills smoothly.
	local ring = Instance.new("Frame")
	ring.Name = "CooldownRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, motion.RingGap * 2, 1, motion.RingGap * 2)
	ring.Visible = false
	ring.Parent = boo
	local halves: { UIGradient } = {}
	for i, side in { "Right", "Left" } do
		local clip = Instance.new("Frame")
		clip.Name = side
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = UDim2.fromScale(if i == 1 then 0.5 else 0, 0)
		clip.Parent = ring
		local circle = Instance.new("Frame")
		circle.Name = "Circle"
		circle.BackgroundTransparency = 1
		circle.Size = UDim2.fromScale(2, 1)
		circle.Position = UDim2.fromScale(if i == 1 then -1 else 0, 0)
		circle.Parent = clip
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = motion.RingThickness
		stroke.Color = motion.RingColor
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = circle
		-- Right half: the left side of the gradient shows; left half: the right side.
		local shown, hidden = if i == 1 then 0 else 1, if i == 1 then 1 else 0
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, shown),
			NumberSequenceKeypoint.new(0.499, shown),
			NumberSequenceKeypoint.new(0.5, hidden),
			NumberSequenceKeypoint.new(1, hidden),
		})
		gradient.Parent = stroke
		halves[i] = gradient
	end
	-- 0 = empty, 1 = a full ring.
	local function setRing(progress: number)
		local angle = math.clamp(progress, 0, 1) * 360
		halves[1].Rotation = math.clamp(angle, 0, 180)
		halves[2].Rotation = math.clamp(angle - 180, 0, 180)
		ring:SetAttribute("Progress", math.clamp(progress, 0, 1))
	end
	setRing(0)

	-- State ---------------------------------------------------------------------------------------
	local function roundState(): string
		local state = ReplicatedStorage:GetAttribute("State")
		return if typeof(state) == "string" then state else ""
	end
	local function inRound(): boolean
		return ReplicatedStorage:GetAttribute("Mode") == MODE
			and player:GetAttribute("InRound") == true
	end
	local function team(): string?
		local value = player:GetAttribute(ATTR.Team)
		return if typeof(value) == "string" then value else nil
	end
	local function running(): boolean
		return team() == "Survivors" and player:GetAttribute(ATTR.State) == "Running"
	end

	-- Messages ------------------------------------------------------------------------------------
	local messageToken = 0
	local function showMessage(main: string, color: Color3, seconds: number, sub: string?)
		messageToken += 1
		local token = messageToken
		message.Text = main
		message.TextColor3 = color
		message.Visible = true
		subMessage.Text = sub or ""
		subMessage.Visible = sub ~= nil
		ScreenFx.Punch(message, motion.MessagePopScale, motion.MessagePopSeconds)
		if sub then
			ScreenFx.FadeText(subMessage, 1, motion.HintFadeSeconds, motion.HintFadeDelay)
		end
		task.delay(seconds, function()
			if token == messageToken then
				message.Visible = false
				subMessage.Visible = false
			end
		end)
	end

	local teamToken = 0
	local function showTeam(which: string)
		teamToken += 1
		local token = teamToken
		local haunter = which == "Haunters"
		teamTitle.Text = if haunter then text.YouAreHaunter else text.YouAreSurvivor
		teamTitle.TextColor3 = if haunter then colors.Haunters else colors.Survivors
		teamHint.Text = if haunter
			then text.HaunterHint
			else text.SurvivorHint:format(cfg.StopSeconds)
		teamTitle.Visible = true
		teamHint.Visible = true
		ScreenFx.Punch(
			teamTitle,
			motion.TeamPopScale,
			motion.TeamPopSeconds,
			motion.TeamShakeDegrees
		)
		ScreenFx.FadeText(teamHint, 1, motion.HintFadeSeconds, motion.HintFadeDelay)
		task.delay(cfg.IntroSeconds + 1.5, function()
			if token == teamToken then
				teamTitle.Visible = false
				teamHint.Visible = false
			end
		end)
	end

	local function refreshPill()
		local which = team()
		local name = if which == "Haunters" then text.Haunters else text.Survivors
		local color = if which == "Haunters" then colors.Haunters else colors.Survivors
		local alive = ReplicatedStorage:GetAttribute("Alive")
		local escaped = ReplicatedStorage:GetAttribute("ScareEscaped")
		pillText.Text = ('<font color="#%s">%s</font>  |  %s  |  %s'):format(
			color:ToHex(),
			name,
			text.SurvivorsLeft:format(if typeof(alive) == "number" then alive else 0),
			text.Escapes:format(if typeof(escaped) == "number" then escaped else 0)
		)
	end

	-- BOO -------------------------------------------------------------------------------------------
	local booRemote: RemoteEvent? = nil
	local function doBoo()
		if not boo.Visible then
			return
		end
		local readyAt = player:GetAttribute(ATTR.BooReadyAt)
		if typeof(readyAt) == "number" and workspace:GetServerTimeNow() < readyAt then
			return
		end
		local remote = booRemote
		if remote then
			remote:FireServer()
		end
		if ScreenFx.On() then
			UIMotion.Bump(boo) -- after the BOO has gone out: the look never delays it
		end
	end
	boo.Activated:Connect(doBoo)
	local bound = false
	local function bindBoo(on: boolean)
		if on == bound then
			return
		end
		bound = on
		if on then
			ContextActionService:BindAction(ACTION, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					doBoo()
				end
				return Enum.ContextActionResult.Sink
			end, false, table.unpack(cfg.Boo.Keys))
		else
			ContextActionService:UnbindAction(ACTION)
		end
	end

	-- Remotes: only once a ScareMaze round is on (the server has made them by then).
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
			Remotes.Event(Rules.Remotes.Scare).OnClientEvent:Connect(function(kind: unknown)
				if typeof(kind) == "string" and inRound() then
					ScareMazeJumpscare.Play(kind)
				end
			end)
			booRemote = Remotes.Event(Rules.Remotes.Boo)
		end)
	end

	-- What shows when ---------------------------------------------------------------------------
	local function refresh()
		if ReplicatedStorage:GetAttribute("Mode") == MODE then
			hookRemotes()
		end
		local state = roundState()
		local which = team()
		local show = inRound() and which ~= nil and (state == "Playing" or state == "Get ready")
		root.Visible = show
		meter.Visible = show and running()
		local haunting = show and which == "Haunters" and state == "Playing"
		boo.Visible = haunting
		bindBoo(haunting)
		ScareMazeXRay.SetEnabled(haunting)
		if show then
			refreshPill()
		else
			countdown.Visible = false
		end
	end

	local lastTeam = team()
	player:GetAttributeChangedSignal(ATTR.Team):Connect(function()
		local now = team()
		if now and not lastTeam then
			showTeam(now)
		elseif now == "Haunters" and lastTeam == "Survivors" then
			showMessage(text.NowHaunter, colors.Haunters, 3)
		end
		lastTeam = now
		refresh()
	end)
	player:GetAttributeChangedSignal(ATTR.State):Connect(function()
		local state = player:GetAttribute(ATTR.State)
		if state == "Escaped" then
			showMessage(text.Escaped, colors.Escaped, 3, text.EscapedHint)
			Sounds.PlaySpec(cfg.Sounds.Escaped :: any)
			if ScreenFx.On() then
				MinigameFx.Confetti(gui, ScreenFx.Count(motion.EscapeConfetti))
				ScreenFx.Burst(
					gui,
					message.Position,
					motion.EscapeColors,
					ScreenFx.Count(motion.EscapeSparkles)
				)
			end
		elseif state == "Out" and inRound() then
			local left = ReplicatedStorage:GetAttribute("TimeLeft")
			local timeUp = typeof(left) == "number" and left <= 1
			showMessage(
				if timeUp then text.TimeUp else text.Out,
				colors.Out,
				cfg.OutToHaunterDelay + 0.5
			)
			Sounds.PlaySpec(cfg.Sounds.Out :: any)
		end
		refresh()
	end)
	local lastCatches = player:GetAttribute(ATTR.Catches)
	player:GetAttributeChangedSignal(ATTR.Catches):Connect(function()
		local now = player:GetAttribute(ATTR.Catches)
		if typeof(now) == "number" and typeof(lastCatches) == "number" and now > lastCatches then
			showMessage(text.Catch, colors.Haunters, 1.5)
			Sounds.PlaySpec(cfg.Sounds.Catch :: any)
		end
		lastCatches = now
	end)
	for _, name in { "Mode", "State", "Alive", "ScareEscaped" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("InRound"):Connect(refresh)

	-- Every frame: the meter and the BOO cooldown ---------------------------------------------------
	local tracker: Rules.Tracker? = nil
	local shown = 0 -- the number the 3-2-1 shows
	local tilt = 1 -- the 3-2-1 tilts left, then right
	local cooling = false -- BOO is recharging
	RunService.RenderStepped:Connect(function()
		if not root.Visible then
			tracker = nil
			return
		end
		local t = workspace:GetServerTimeNow()
		if boo.Visible then
			local readyAt = player:GetAttribute(ATTR.BooReadyAt)
			local left = if typeof(readyAt) == "number" then readyAt - t else 0
			local now = left > 0
			booShade.Visible = now
			booShade.Text = if now then tostring(math.ceil(left)) else ""
			ring.Visible = now
			if now then
				setRing(1 - left / math.max(cfg.Boo.Cooldown, 0.01))
			elseif cooling and ScreenFx.On() then
				UIMotion.Bump(boo) -- ready again
			end
			cooling = now
		else
			cooling = false
		end
		if not meter.Visible then
			countdown.Visible = false
			tracker = nil
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) then
			return
		end
		if roundState() ~= "Playing" then
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = colors.MeterFull
			meterLabel.Text = text.GetReady
			countdown.Visible = false
			tracker = nil
			return
		end
		local current = tracker or Rules.NewTracker(t)
		tracker = current
		local grace = player:GetAttribute(ATTR.GraceUntil)
		if typeof(grace) == "number" then
			Rules.Grace(current, grace)
		end
		local still = Rules.Update(current, hrp.Position, t, cfg.MinMoveStuds)
		local amount = Rules.Meter(still, cfg.StopSeconds)
		fill.Size = UDim2.fromScale(amount, 1)
		fill.BackgroundColor3 = if amount > 0.5
			then colors.MeterHalf:Lerp(colors.MeterFull, (amount - 0.5) * 2)
			else colors.MeterEmpty:Lerp(colors.MeterHalf, amount * 2)
		local safe = t < current.GraceUntil
		local warning = not safe and still >= cfg.CountdownAfter
		meterLabel.Text = if safe then text.Safe elseif warning then text.Move else text.KeepMoving
		meterLabel.TextColor3 = if warning then colors.MeterEmpty else Theme.Text
		if warning then
			local n = Rules.SecondsLeft(still, cfg.StopSeconds)
			countdown.Visible = n > 0
			if n ~= shown and n > 0 then
				shown = n
				countdown.Text = tostring(n)
				tilt = -tilt
				ScreenFx.Punch(
					countdown,
					motion.CountdownPopScale,
					motion.CountdownPopSeconds,
					motion.CountdownTilt * tilt
				)
				Sounds.Play("CountdownTick")
			end
		else
			countdown.Visible = false
			shown = 0
		end
	end)

	refresh()
end

return ScareMazeUI
