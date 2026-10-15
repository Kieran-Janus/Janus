--!strict
--[[
	Crumbling Crypt screen (mode id TileFall; settings and every text: Config.TileFall). Shows
	only for players in a Crumbling Crypt round (the ReplicatedStorage attribute Mode is
	"TileFall" and the player attribute InRound is true).
	On/off: Config.Features.TileFall (off = Mount does nothing and nothing shows).

	  - a pill under the top bar: "Players left: 3" and the clock
	  - "Get ready!" with the hint, then GO!
	  - "SUDDEN DEATH!" when random slabs start cracking by themselves
	  - "You fell in!" and, while you watch as a ghost, "Watching..." at the bottom
	  - the winner's "LAST ONE STANDING!" (alone: "YOU SURVIVED!") with confetti
	  - the slabs, for everyone near the crypt (in the round or watching): a cracking slab shakes
	    and a dropped one falls into the goo as a piece that fades away. Only a look on this
	    screen: the server already made the real slab crack and stop being solid. With
	    Config.TileFall.Effects.On (or Config.ScreenMotion.On) off they just change colour and
	    vanish.
	It reads attributes only (src/server/Modes/TileFall.luau lists them): this mode has no
	remotes, so there is nothing to wait for.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local TileFallUI = {}

local MODE = "TileFall"
local STATE = "TileFallState" -- player attribute (In / Out / Winner)
local SOLO = "TileFallSolo"
local SUDDEN = "TileFallSuddenDeath"
local TILE_STATE = "TileState"
local CRUMBLE_AT = "CrumbleAt"

-- A big outlined label for messages in the middle of the screen (shrinks on narrow phones).
local function shout(name: string, size: number, parent: Instance): TextLabel
	local label = Theme.label("", size, parent)
	label.Name = name
	label.Font = Enum.Font.GothamBlack
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Visible = false
	label.TextScaled = true
	label.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = math.min(size, Config.UI.MinTextSize)
	limit.Parent = label
	return label
end

-- The slabs: shaking while they crack, falling pieces when they drop ---------------------------

type Shake = { Base: CFrame, Until: number }

local function startSlabEffects()
	local cfg = Config.TileFall
	local fx = cfg.Effects
	local shaking: { [BasePart]: Shake } = {}
	local watched: { [Instance]: RBXScriptConnection } = {}
	local stepper: RBXScriptConnection? = nil
	local falling = 0
	local rng = Random.new()

	local function on(): boolean
		return fx.On == true and ScreenFx.On()
	end

	local function near(part: BasePart): boolean
		local camera = workspace.CurrentCamera
		if not camera then
			return false
		end
		return (camera.CFrame.Position - part.Position).Magnitude <= fx.Range
	end

	local function stopShake(part: BasePart)
		local s = shaking[part]
		if s then
			shaking[part] = nil
			if part.Parent then
				part.CFrame = s.Base
			end
		end
	end

	-- Only runs while something shakes (nothing per frame otherwise).
	local function step()
		local t = workspace:GetServerTimeNow()
		for part, s in shaking do
			if t >= s.Until or not part.Parent or part:GetAttribute(TILE_STATE) ~= "Cracking" then
				stopShake(part)
			else
				local a = fx.ShakeStuds
				part.CFrame = s.Base * CFrame.new(rng:NextNumber(-a, a), 0, rng:NextNumber(-a, a))
			end
		end
		if next(shaking) == nil and stepper then
			stepper:Disconnect()
			stepper = nil
		end
	end

	local function shake(part: BasePart)
		if shaking[part] or not on() or not near(part) then
			return
		end
		local at = part:GetAttribute(CRUMBLE_AT)
		local untilAt = if typeof(at) == "number" then at else workspace:GetServerTimeNow() + 1
		shaking[part] = { Base = part.CFrame, Until = untilAt }
		if not stepper then
			stepper = RunService.Heartbeat:Connect(step)
		end
	end

	local function fall(part: BasePart)
		stopShake(part)
		local most = if Layout.IsPhone() then fx.PhoneMaxFalling else fx.MaxFalling
		if not on() or not near(part) or falling >= most then
			return
		end
		local piece = part:Clone()
		-- A look only: not a slab (no tag), never in anyone's way.
		for _, tag in CollectionService:GetTags(piece) do
			CollectionService:RemoveTag(piece, tag)
		end
		for name in piece:GetAttributes() do
			piece:SetAttribute(name, nil)
		end
		piece:ClearAllChildren()
		piece.Name = "FallingSlab"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Transparency = 0
		piece.Parent = workspace.CurrentCamera or workspace
		falling += 1
		local goal = piece.CFrame
			* CFrame.new(0, -fx.FallStuds, 0)
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(fx.FallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = goal, Transparency = 1 }
		)
		local done = false
		local function finish()
			if done then
				return
			end
			done = true
			falling -= 1
			piece:Destroy()
			tween:Destroy()
		end
		tween.Completed:Once(finish)
		tween:Play()
		task.delay(fx.FallSeconds + 0.5, finish)
	end

	local function watch(instance: Instance)
		if watched[instance] or not instance:IsA("BasePart") then
			return
		end
		local part = instance :: BasePart
		watched[part] = part:GetAttributeChangedSignal(TILE_STATE):Connect(function()
			local state = part:GetAttribute(TILE_STATE)
			if state == "Cracking" then
				shake(part)
			elseif state == "Gone" then
				fall(part)
			end
		end)
	end

	local function unwatch(instance: Instance)
		local connection = watched[instance]
		if connection then
			connection:Disconnect()
			watched[instance] = nil
		end
		if instance:IsA("BasePart") then
			shaking[instance] = nil
		end
	end

	CollectionService:GetInstanceAddedSignal(Tags.TileFallTile):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(Tags.TileFallTile):Connect(unwatch)
	for _, instance in CollectionService:GetTagged(Tags.TileFallTile) do
		watch(instance)
	end
end

-- The screen ----------------------------------------------------------------------------------

function TileFallUI.Mount(gui: ScreenGui)
	if not Config.Features.TileFall then
		return
	end
	local cfg = Config.TileFall
	local text = cfg.Text
	local colors = cfg.Colors
	local player = Players.LocalPlayer

	local root = Instance.new("Frame")
	root.Name = "TileFall"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui

	-- Players left and the clock, under the top bar.
	local pill = Theme.panel(root)
	pill.Name = "Info"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0.02, 72)
	pill.Size = UDim2.fromOffset(if Layout.IsPhone() then 260 else 320, 32)
	local pillText = Theme.label("", 18, pill)
	pillText.Name = "Text"
	pillText.Size = UDim2.fromScale(1, 1)
	pillText.TextColor3 = colors.Info
	pillText.TextScaled = true
	local pillLimit = Instance.new("UITextSizeConstraint")
	pillLimit.MaxTextSize = 18
	pillLimit.MinTextSize = Config.UI.MinTextSize
	pillLimit.Parent = pillText
	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 10)
	pillPadding.PaddingRight = UDim.new(0, 10)
	pillPadding.PaddingTop = UDim.new(0, 5)
	pillPadding.PaddingBottom = UDim.new(0, 5)
	pillPadding.Parent = pillText

	-- Big messages in the middle.
	local message = shout("Message", 46, root)
	message.Position = UDim2.fromScale(0.5, 0.32)
	message.Size = UDim2.new(0.92, 0, 0, 56)
	local subMessage = shout("SubMessage", 22, root)
	subMessage.Position = UDim2.new(0.5, 0, 0.32, 46)
	subMessage.Size = UDim2.new(0.92, 0, 0, 30)
	Layout.KeepBelowHud({ message, subMessage }, pill)

	-- "Watching..." at the bottom while you're a ghost.
	local watching = Theme.panel(root)
	watching.Name = "Watching"
	watching.AnchorPoint = Vector2.new(0.5, 1)
	watching.Position = UDim2.new(0.5, 0, 1, -24)
	watching.Size = UDim2.fromOffset(if Layout.IsPhone() then 280 else 360, 36)
	watching.Visible = false
	local watchingText = Theme.label(text.Watching, 18, watching)
	watchingText.Name = "Text"
	watchingText.Size = UDim2.fromScale(1, 1)
	watchingText.TextScaled = true
	local watchLimit = Instance.new("UITextSizeConstraint")
	watchLimit.MaxTextSize = 18
	watchLimit.MinTextSize = Config.UI.MinTextSize
	watchLimit.Parent = watchingText

	local function roundState(): string
		local state = ReplicatedStorage:GetAttribute("State")
		return if typeof(state) == "string" then state else ""
	end
	local function inRound(): boolean
		return ReplicatedStorage:GetAttribute("Mode") == MODE
			and player:GetAttribute("InRound") == true
	end
	local function solo(): boolean
		return ReplicatedStorage:GetAttribute(SOLO) == true
	end

	local token = 0
	local function showMessage(main: string, color: Color3, seconds: number, sub: string?)
		token += 1
		local mine = token
		message.Text = main
		message.TextColor3 = color
		message.Visible = true
		subMessage.Text = sub or ""
		subMessage.Visible = sub ~= nil
		ScreenFx.Punch(message, 1.6, 0.35)
		if sub then
			ScreenFx.FadeText(subMessage, 1, 0.4, 0.15)
		end
		task.delay(seconds, function()
			if mine == token then
				message.Visible = false
				subMessage.Visible = false
			end
		end)
	end

	local function refreshPill()
		local left = ReplicatedStorage:GetAttribute("TimeLeft")
		local seconds = if typeof(left) == "number" then math.max(0, left) else 0
		local clock = text.Time:format(seconds // 60, seconds % 60)
		if solo() then
			pillText.Text = clock
		else
			local alive = ReplicatedStorage:GetAttribute("Alive")
			pillText.Text = ("%s  |  %s"):format(
				text.PlayersLeft:format(if typeof(alive) == "number" then alive else 0),
				clock
			)
		end
	end

	local function refresh()
		local state = roundState()
		local show = inRound() and (state == "Get ready" or state == "Playing")
		root.Visible = show
		watching.Visible = show and player:GetAttribute(STATE) == "Out"
		if show then
			refreshPill()
		end
	end

	local lastState = roundState()
	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(function()
		local state = roundState()
		if inRound() then
			if state == "Get ready" and lastState ~= "Get ready" then
				showMessage(
					text.GetReady,
					colors.Info,
					cfg.IntroSeconds,
					if solo() then text.SoloHint else text.Hint
				)
			elseif state == "Playing" and lastState == "Get ready" then
				showMessage(text.Go, colors.Info, 1.2)
			end
		end
		lastState = state
		refresh()
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SUDDEN):Connect(function()
		if ReplicatedStorage:GetAttribute(SUDDEN) == true and inRound() then
			showMessage(text.SuddenDeath, colors.SuddenDeath, 2.5)
			Sounds.Play("CountdownTick")
		end
	end)
	player:GetAttributeChangedSignal(STATE):Connect(function()
		local state = player:GetAttribute(STATE)
		if state == "Out" and inRound() then
			showMessage(text.Out, colors.Out, 3, text.Watching)
			Sounds.PlaySpec(cfg.Sounds.Out :: any)
		elseif state == "Winner" and inRound() then
			showMessage(
				if solo() then text.SoloWinner else text.Winner,
				colors.Winner,
				cfg.CelebrateSeconds + 0.5,
				text.WinnerHint
			)
			Sounds.PlaySpec(cfg.Sounds.Winner :: any)
			if ScreenFx.On() then
				MinigameFx.Confetti(gui, ScreenFx.Count(cfg.WinnerConfetti))
			end
		end
		refresh()
	end)
	for _, name in { "Mode", "TimeLeft", "Alive", SOLO } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("InRound"):Connect(refresh)

	startSlabEffects()
	refresh()
end

return TileFallUI
