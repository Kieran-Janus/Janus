--!strict
--[[
	Web Scour minigame on this player's screen (Config.Minigames.WebScour; on/off:
	Config.Features.WebScour, off = Mount does nothing and nothing shows).

	  WebScour         the small bar under the top bar while you hunt: time left, "4/6 found"
	                   and a Stop button
	  WebScourBanner   the finish banner: all found / time's up, your time, a new best, coins
	  WebScourNote     short messages ("Get closer!", "You're already scouring the webs!")
	  Workspace.WebScourCritters   the glowing critters: made on THIS computer only, so
	                   nobody else sees your critters (each player hunts their own)

	Catching: click or tap a critter (a ray from the camera through where you pressed), or
	walk up to one and use its "Catch!" button (gamepads). The server checks every catch
	(src/server/Services/WebScourService.luau); a critter that was too far away comes back.
	In the last HintLastSeconds the critters glow through the webs and trees, to help.
	Remotes: WebScourRun (server -> client), WebScourAction (client -> server).

	Celebrations (Config.Minigames.WebScour.Effects, all off with its On = false or
	Config.Minigames.Effects.On = false; src/client/MinigameFx.luau): critters hop now and
	then while they wait, a catch puff, a "+1" when the server counts a catch, a bar under the
	clock that drains with the REAL time left (and calmly pulses once a second in the last
	HintLastSeconds), and a finish banner that pops, counts its coins up to the real number
	and throws confetti when you found them all. Catches are sent the moment you click.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local WebScourRules = require(ReplicatedStorage.Shared.WebScourRules)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local WebScourUI = {}

local cfg = Config.Minigames.WebScour
local text = cfg.Text
local fx = cfg.Effects

local function effectsOn(): boolean
	return MinigameFx.Enabled(fx)
end

local PENDING_SECONDS = 1.5 -- a caught critter comes back if the server hasn't answered by then

type Critter = {
	Id: number,
	Kind: string,
	Model: Model,
	Hitbox: Part,
	Base: CFrame,
	Phase: number,
	Glow: PointLight?,
	Highlight: Highlight,
	Parts: { BasePart },
	Pending: number?, -- os.clock() when we asked the server, nil = not waiting
	Caught: boolean,
	HopAt: number, -- os.clock() of its next little hop (effects)
}

local function number(value: unknown): number
	return if type(value) == "number" and value == value then value else 0
end

local function vector(value: unknown): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

-- Critter looks -------------------------------------------------------------------------------------

local function piece(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p:SetAttribute("Offset", offset) -- where it sits on the critter (for the animation)
	p.Parent = parent
	return p
end

-- An oval (a block with a sphere mesh: a Ball part is always round).
local function ovalPiece(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	neon: boolean?
): Part
	local p = piece(parent, name, Enum.PartType.Block, size, offset, color, neon)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function eyes(parent: Instance, s: number, y: number, z: number, spread: number)
	for _, side in { -1, 1 } do
		piece(
			parent,
			"Eye",
			Enum.PartType.Ball,
			Vector3.one * (0.34 * s),
			CFrame.new(side * spread * s, y * s, z * s),
			Color3.new(1, 1, 1)
		)
		piece(
			parent,
			"Pupil",
			Enum.PartType.Ball,
			Vector3.one * (0.17 * s),
			CFrame.new(side * spread * s, (y - 0.02) * s, (z - 0.14) * s),
			Color3.fromRGB(20, 14, 26)
		)
	end
end

-- Builds a cute cartoon spider (s = its size in studs, colour = its bright body), front = -Z.
local function buildLook(m: Model, s: number, colour: Color3)
	local dark = colour:Lerp(Color3.new(0, 0, 0), 0.45)
	ovalPiece(m, "Body", Vector3.new(0.8, 0.7, 0.85) * s, CFrame.new(0, 0.05 * s, 0.18 * s), colour)
	ovalPiece(
		m,
		"Stripe",
		Vector3.new(0.5, 0.2, 0.6) * s,
		CFrame.new(0, 0.33 * s, 0.2 * s),
		colour:Lerp(Color3.new(1, 1, 1), 0.55)
	)
	ovalPiece(
		m,
		"Head",
		Vector3.new(0.62, 0.56, 0.5) * s,
		CFrame.new(0, 0.02 * s, -0.3 * s),
		colour
	)
	eyes(m, s, 0.12, -0.5, 0.13)
	piece(
		m,
		"Smile",
		Enum.PartType.Block,
		Vector3.new(0.2, 0.04, 0.04) * s,
		CFrame.new(0, -0.12 * s, -0.54 * s),
		Color3.fromRGB(20, 14, 26)
	)
	for _, side in { -1, 1 } do
		piece(
			m,
			"Fang",
			Enum.PartType.Block,
			Vector3.new(0.05, 0.09, 0.04) * s,
			CFrame.new(side * 0.06 * s, -0.17 * s, -0.53 * s),
			Color3.new(1, 1, 1)
		)
		-- Four bendy legs a side: up and out at the knee, then down to the web.
		for i = 1, 4 do
			local z = (i - 2.5) * 0.2 * s
			piece(
				m,
				"Leg",
				Enum.PartType.Block,
				Vector3.new(0.4, 0.08, 0.08) * s,
				CFrame.new(side * 0.42 * s, 0.1 * s, z) * CFrame.Angles(0, 0, math.rad(side * 30)),
				dark
			)
			piece(
				m,
				"Leg",
				Enum.PartType.Block,
				Vector3.new(0.45, 0.08, 0.08) * s,
				CFrame.new(side * 0.71 * s, 0.005 * s, z)
					* CFrame.Angles(0, 0, math.rad(side * -60)),
				dark
			)
		end
	end
	-- A soft glowing bubble around every spider so it can be spotted in the webs.
	local aura =
		piece(m, "Aura", Enum.PartType.Ball, Vector3.one * (1.25 * s), CFrame.new(), colour, true)
	aura.Transparency = 0.82
end

-- Mount ------------------------------------------------------------------------------------------------

function WebScourUI.Mount(gui: ScreenGui)
	if not Config.Features.WebScour then
		return
	end
	local player = Players.LocalPlayer

	local function textSize(label: TextLabel, max: number)
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = max
		limit.MinTextSize = Config.UI.MinTextSize
		limit.Parent = label
	end

	-- The hunt bar ---------------------------------------------------------------------------------
	local bar = Theme.panel(gui)
	bar.Name = "WebScour"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 80)
	bar.Size = UDim2.fromOffset(300, 62)
	bar.Visible = false
	Layout.Fit(bar)
	local title = Theme.label(text.Title, 14, bar)
	title.Name = "Title"
	title.TextColor3 = cfg.Grove.Colors.Lantern
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -90, 0, 18)
	local clock = Theme.label("", 26, bar)
	clock.Name = "Time"
	clock.Font = Enum.Font.GothamBlack
	clock.TextXAlignment = Enum.TextXAlignment.Left
	clock.Position = UDim2.fromOffset(12, 22)
	clock.Size = UDim2.fromOffset(80, 34)
	textSize(clock, 26)
	local progress = Theme.label("", 18, bar)
	progress.Name = "Progress"
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Position = UDim2.fromOffset(96, 22)
	progress.Size = UDim2.new(1, -176, 0, 34)
	textSize(progress, 18)
	local stopButton = Theme.button(text.Stop, bar)
	stopButton.Name = "Stop"
	stopButton.TextSize = 15
	stopButton.AnchorPoint = Vector2.new(1, 0.5)
	stopButton.Position = UDim2.new(1, -8, 0.5, 0)
	stopButton.Size = UDim2.fromOffset(64, 40)
	-- The time bar: drains with the real time left (effects).
	local timeBar = Instance.new("Frame")
	timeBar.Name = "TimeBar"
	timeBar.AnchorPoint = Vector2.new(0, 1)
	timeBar.Position = UDim2.new(0, 12, 1, -4)
	timeBar.Size = UDim2.new(1, -90, 0, 4)
	timeBar.BackgroundColor3 = Theme.Button
	timeBar.BorderSizePixel = 0
	timeBar.Visible = false
	timeBar.Parent = bar
	Theme.round(timeBar, 2)
	local timeFill = Instance.new("Frame")
	timeFill.Name = "Fill"
	timeFill.BorderSizePixel = 0
	timeFill.BackgroundColor3 = fx.TimeBarColor
	timeFill.Size = UDim2.fromScale(1, 1)
	timeFill.Parent = timeBar
	Theme.round(timeFill, 2)
	local clockPulse = Instance.new("UIScale")
	clockPulse.Name = "Pulse"
	clockPulse.Parent = clock

	-- Keep the bar just below the bar at the top (the Hud), wherever that is.
	local function place()
		local hud = gui:FindFirstChild("Hud")
		local y = 80
		if hud and hud:IsA("GuiObject") and hud.Visible and hud.AbsoluteSize.Y > 0 then
			local scale = math.max(Layout.Scale(), 0.01)
			y = (hud.AbsolutePosition.Y + hud.AbsoluteSize.Y - gui.AbsolutePosition.Y) / scale + 8
		end
		bar.Position = UDim2.new(0.5, 0, 0, y)
	end

	-- Short messages under the bar ------------------------------------------------------------------
	local noteLabel = Theme.label("", 16, gui)
	noteLabel.Name = "WebScourNote"
	noteLabel.AnchorPoint = Vector2.new(0.5, 0)
	noteLabel.Position = UDim2.new(0.5, 0, 0, 150)
	noteLabel.Size = UDim2.fromOffset(340, 36)
	noteLabel.BackgroundColor3 = Theme.Background
	noteLabel.BackgroundTransparency = 0.25
	noteLabel.TextWrapped = true
	noteLabel.Visible = false
	Theme.round(noteLabel, 10)
	local noteToken = 0
	local function note(words: string, seconds: number?)
		if words == "" then
			return
		end
		place()
		local top = bar.Position.Y.Offset + (if bar.Visible then 70 else 0)
		noteLabel.Position = UDim2.new(0.5, 0, 0, top)
		noteLabel.Text = words
		noteLabel.Visible = true
		noteToken += 1
		local mine = noteToken
		task.delay(seconds or 2.5, function()
			if noteToken == mine then
				noteLabel.Visible = false
			end
		end)
	end

	-- The finish banner -----------------------------------------------------------------------------
	local banner = Theme.panel(gui)
	banner.Name = "WebScourBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.34)
	banner.Size = UDim2.fromOffset(420, 128)
	banner.Visible = false
	banner.ZIndex = 6
	Layout.Fit(banner)
	local bannerTitle = Theme.label("", 30, banner)
	bannerTitle.Name = "Title"
	bannerTitle.Font = Enum.Font.GothamBlack
	bannerTitle.TextColor3 = cfg.Grove.Colors.Lantern
	bannerTitle.Position = UDim2.fromOffset(10, 8)
	bannerTitle.Size = UDim2.new(1, -20, 0, 40)
	textSize(bannerTitle, 30)
	local bannerLine = Theme.label("", 18, banner)
	bannerLine.Name = "Detail"
	bannerLine.Position = UDim2.fromOffset(10, 50)
	bannerLine.Size = UDim2.new(1, -20, 0, 28)
	textSize(bannerLine, 18)
	local bannerCoins = Theme.label("", 22, banner)
	bannerCoins.Name = "Coins"
	bannerCoins.TextColor3 = Color3.fromRGB(255, 215, 80)
	bannerCoins.Position = UDim2.fromOffset(10, 82)
	bannerCoins.Size = UDim2.new(1, -20, 0, 34)
	textSize(bannerCoins, 22)
	local bannerToken = 0

	-- Critters -----------------------------------------------------------------------------------------
	local folder: Folder? = nil
	local critters: { [number]: Critter } = {}
	local hitboxes: { Instance } = {}
	local runId = 0
	local deadline = 0
	local total = 0
	local found = 0
	local hinting = false
	local lastTick = -1
	local timeLimit = 0
	local hopRng = Random.new()
	local function nextHop(now: number): number
		return now + hopRng:NextNumber(fx.HopEvery.Min, math.max(fx.HopEvery.Max, fx.HopEvery.Min))
	end
	local action: RemoteEvent? = nil
	local loop: RBXScriptConnection? = nil

	local function send(...: any)
		local remote = action
		if remote then
			remote:FireServer(...)
		end
	end

	local function setVisible(critter: Critter, visible: boolean)
		for _, p in critter.Parts do
			p.LocalTransparencyModifier = if visible then 0 else 1
		end
		local glow = critter.Glow
		if glow then
			glow.Enabled = visible
		end
		local prompt = critter.Hitbox:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = visible
		end
		critter.Highlight.Enabled = visible and hinting
	end

	local function poof(position: Vector3, color: Color3)
		local container = folder
		if not container then
			return
		end
		local holder = Instance.new("Part")
		holder.Name = "Poof"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.CFrame = CFrame.new(position)
		holder.Parent = container
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(color)
		burst.LightEmission = 1
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		burst.Lifetime = NumberRange.new(0.4, 0.8)
		burst.Speed = NumberRange.new(6, 10)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rate = 0
		burst.Parent = holder
		burst:Emit(if effectsOn() then MinigameFx.Count(fx.CatchSparkles) else 18)
		task.delay(1.2, function()
			holder:Destroy()
		end)
	end

	local function updateProgress()
		progress.Text = text.Progress:format(found, total)
	end

	local function clear()
		local loopConnection = loop
		if loopConnection then
			loopConnection:Disconnect()
			loop = nil
		end
		local container = folder
		if container then
			-- Leave a moment for the last poofs, then tidy up.
			for _, critter in critters do
				critter.Model:Destroy()
			end
			task.delay(1.5, function()
				container:Destroy()
			end)
		end
		folder = nil
		critters = {}
		hitboxes = {}
		hinting = false
		bar.Visible = false
	end

	local function catch(critter: Critter)
		if critter.Caught or critter.Pending then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and (root.Position - critter.Base.Position).Magnitude > cfg.MaxReach
		then
			Sounds.PlaySpec(cfg.Sounds.Miss)
			note(text.TooFar, 1.5)
			return
		end
		critter.Pending = os.clock()
		setVisible(critter, false)
		poof(critter.Base.Position, cfg.CritterColors[critter.Kind] or Color3.new(1, 1, 1))
		Sounds.PlaySpec(cfg.Sounds.Catch)
		send("Catch", runId, critter.Id)
	end

	local function makeCritter(
		id: number,
		kind: string,
		position: Vector3,
		container: Instance
	): Critter
		local size = cfg.CritterSize
		local glowColor = cfg.CritterColors[kind] or Color3.new(1, 1, 1)
		local m = Instance.new("Model")
		m.Name = kind .. id
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Shape = Enum.PartType.Ball
		hitbox.Size = Vector3.one * (size * 1.7) -- bigger than the critter: easy to tap
		hitbox.Transparency = 1
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = true -- the click ray looks for these
		hitbox:SetAttribute("Offset", CFrame.new())
		hitbox.Parent = m
		buildLook(m, size, glowColor)
		local parts: { BasePart } = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= hitbox then
				table.insert(parts, d)
			end
		end
		local glow: PointLight? = nil
		if cfg.CritterLight > 0 then
			local light = Instance.new("PointLight")
			light.Color = glowColor
			light.Range = cfg.CritterLight
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = hitbox
			glow = light
		end
		local highlight = Instance.new("Highlight")
		highlight.FillColor = glowColor
		highlight.FillTransparency = 0.45
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Enabled = false
		highlight.Adornee = m
		highlight.Parent = m
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = text.Catch
		prompt.ObjectText = ""
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = cfg.CatchPromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = hitbox
		m.PrimaryPart = hitbox
		local critter: Critter = {
			Id = id,
			Kind = kind,
			Model = m,
			Hitbox = hitbox,
			Base = CFrame.new(position),
			Phase = (id * 1.7) % (math.pi * 2),
			Glow = glow,
			Highlight = highlight,
			Parts = parts,
			Pending = nil,
			Caught = false,
			HopAt = nextHop(os.clock()),
		}
		prompt.Triggered:Connect(function()
			catch(critter)
		end)
		m.Parent = container
		table.insert(hitboxes, hitbox)
		return critter
	end

	-- Bob, spin and flap; the clock; hints in the last seconds; give back unanswered catches.
	local function step()
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local on = effectsOn()
		for _, critter in critters do
			if critter.Caught then
				continue
			end
			local pending = critter.Pending
			if pending and now - pending > PENDING_SECONDS then
				critter.Pending = nil
				setVisible(critter, true)
			end
			local t = now * 2 + critter.Phase
			local bob = math.sin(t) * 0.25
			-- Now and then a little hop with a wiggle (effects).
			local wiggle = 0
			if on and now >= critter.HopAt then
				local hopDone = (now - critter.HopAt) / math.max(fx.HopSeconds, 0.05)
				if hopDone >= 1 then
					critter.HopAt = nextHop(now)
				else
					bob += math.sin(math.pi * hopDone) * fx.HopHeight
					wiggle = math.sin(hopDone * math.pi * 2) * 0.35
				end
			end
			local turn: CFrame
			if camera then -- face the player, with a little wiggle
				local to = camera.CFrame.Position - critter.Base.Position
				local yaw = math.atan2(-to.X, -to.Z) + math.pi
				turn = CFrame.Angles(0, yaw + math.sin(t * 0.7) * 0.3, 0)
			else
				turn = CFrame.Angles(0, now * 0.8 + critter.Phase, 0)
			end
			local pivot = critter.Base * CFrame.new(0, bob, 0) * turn * CFrame.Angles(0, 0, wiggle)
			for _, p in critter.Model:GetChildren() do
				if p:IsA("BasePart") then
					local offset = p:GetAttribute("Offset")
					local seat = if typeof(offset) == "CFrame" then offset else CFrame.new()
					local side = p:GetAttribute("Wing")
					if type(side) == "number" then
						seat *= CFrame.Angles(0, 0, math.sin(now * 14) * 0.5 * side) -- flap
					end
					p.CFrame = pivot * seat
				end
			end
		end
		local left = math.max(deadline - now, 0)
		local wholeLeft = math.ceil(left)
		clock.Text = string.format("%d:%02d", wholeLeft // 60, wholeLeft % 60)
		-- The bar drains with the real time left; in the last seconds the clock swells once a
		-- second, right as the number changes, and settles (calm, never faster than real time).
		local lastSeconds = left <= cfg.HintLastSeconds and left > 0
		timeBar.Visible = on and timeLimit > 0
		if on and timeLimit > 0 then
			timeFill.Size = UDim2.fromScale(math.clamp(left / timeLimit, 0, 1), 1)
			timeFill.BackgroundColor3 = if lastSeconds then fx.TimeBarLowColor else fx.TimeBarColor
		end
		if on and lastSeconds then
			local fraction = left - math.floor(left)
			clockPulse.Scale = 1 + fx.Pulse * fraction * fraction
		elseif clockPulse.Scale ~= 1 then
			clockPulse.Scale = 1
		end
		if lastSeconds then
			local whole = math.ceil(left)
			if whole ~= lastTick then
				lastTick = whole
				Sounds.PlaySpec(cfg.Sounds.Tick)
			end
			if not hinting then
				hinting = true
				for _, critter in critters do
					if not critter.Caught and not critter.Pending then
						critter.Highlight.Enabled = true
					end
					local glow = critter.Glow
					if glow then
						glow.Brightness = 2.5
					end
				end
				clock.TextColor3 = Color3.fromRGB(255, 120, 90)
			end
		end
	end

	local function onStart(message: { [string]: any })
		clear()
		runId = number(message.RunId)
		total = 0
		found = 0
		lastTick = -1
		timeLimit = number(message.TimeLimit)
		deadline = os.clock() + timeLimit
		clockPulse.Scale = 1
		clock.TextColor3 = Theme.Text
		local container = Instance.new("Folder")
		container.Name = "WebScourCritters"
		container.Parent = workspace
		folder = container
		local list = message.Critters
		if type(list) == "table" then
			for _, entry in list do
				local position: Vector3? = if type(entry) == "table"
					then vector(entry.Position)
					else nil
				local id = if type(entry) == "table" then number(entry.Id) else 0
				if position and id > 0 then
					local kind = if type(entry.Kind) == "string" then entry.Kind else "Spider"
					critters[id] = makeCritter(id, kind, position, container)
					total += 1
				end
			end
		end
		updateProgress()
		place()
		bar.Visible = true
		banner.Visible = false
		Sounds.PlaySpec(cfg.Sounds.Start)
		local hint = if Layout.IsTouch()
			then text.HintTouch
			elseif
				UserInputService.GamepadEnabled and not UserInputService.MouseEnabled
			then text.HintGamepad
			else text.HintMouse
		local wait = number(message.CooldownLeft)
		if wait > 0 then
			hint ..= "\n" .. text.JustForFun:format(WebScourRules.FormatWait(wait))
		end
		note(hint, 4)
		step()
		loop = RunService.Heartbeat:Connect(step)
	end

	local function onFound(message: { [string]: any })
		local critter = critters[number(message.Id)]
		if critter and not critter.Caught then
			critter.Caught = true
			critter.Pending = nil
			setVisible(critter, false)
			critter.Highlight.Enabled = false
		end
		local before = found
		found = number(message.Found)
		total = math.max(number(message.Total), total)
		updateProgress()
		if found > before and effectsOn() then
			MinigameFx.FloatText(
				bar,
				fx.PlusText,
				Color3.fromRGB(255, 215, 80),
				UDim2.fromOffset(150, 20)
			)
			MinigameFx.Punch(progress, 1.25)
		end
	end

	local function onMiss(message: { [string]: any })
		local critter = critters[number(message.Id)]
		if critter and not critter.Caught then
			critter.Pending = nil
			setVisible(critter, true)
		end
		Sounds.PlaySpec(cfg.Sounds.Miss)
		if message.Reason == "TooFar" then
			note(text.TooFar, 1.5)
		end
	end

	local function onEnd(message: { [string]: any })
		for _, critter in critters do
			if not critter.Caught then
				poof(critter.Base.Position, cfg.CritterColors[critter.Kind] or Color3.new(1, 1, 1))
			end
		end
		clear()
		local reason = message.Reason
		local caught, all = number(message.Found), number(message.Total)
		local titleText = if reason == "AllFound"
			then text.AllFound
			elseif reason == "TimeUp" then text.TimeUp
			elseif reason == "Left" then text.Left
			elseif reason == "Round" then text.Round
			else text.Stopped
		local details = { text.Found:format(caught, all) }
		local time = message.Time
		if reason == "AllFound" and type(time) == "number" then
			table.insert(details, text.Time:format(WebScourRules.FormatTime(time)))
		end
		if message.NewBest == true then
			table.insert(details, text.NewBest)
		elseif number(message.Best) > 0 then
			table.insert(details, text.Best:format(WebScourRules.FormatTime(number(message.Best))))
		end
		local coins = number(message.Coins)
		local wait = number(message.CooldownLeft)
		bannerTitle.Text = titleText
		bannerLine.Text = table.concat(details, "  ·  ")
		local on = effectsOn()
		if coins > 0 then
			-- (counts up to the real number when effects are on; always ends on it)
			MinigameFx.CountUp(
				bannerCoins,
				coins,
				if on then fx.CoinsCountSeconds else 0,
				function(n: number): string
					return text.Coins:format(n, Config.Economy.CurrencyName)
				end
			)
		else
			MinigameFx.CountUp(bannerCoins, 0, 0, function(_: number): string
				return if wait > 0
					then text.JustForFun:format(WebScourRules.FormatWait(wait))
					else ""
			end)
		end
		Sounds.PlaySpec(if reason == "AllFound" then cfg.Sounds.AllFound else cfg.Sounds.TimeUp)
		banner.Visible = true
		bannerToken += 1
		local mine = bannerToken
		-- (through Layout.Fit's MotionScale: a second UIScale on the banner would fight its fit)
		MinigameFx.PopFit(banner, 0.6, 0.35)
		if on then
			MinigameFx.Punch(bannerTitle, 1.3)
			if reason == "AllFound" then
				MinigameFx.Confetti(gui, MinigameFx.Count(fx.AllFoundConfetti))
			end
		end
		task.delay(cfg.BannerSeconds, function()
			if bannerToken == mine then
				banner.Visible = false
			end
		end)
	end

	-- Clicks and taps: a ray from the camera through the point that was pressed.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or next(critters) == nil then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		rayParams.FilterDescendantsInstances = hitboxes
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
		local part = hit and hit.Instance
		if not part then
			return
		end
		for _, critter in critters do
			if critter.Hitbox == part then
				catch(critter)
				return
			end
		end
	end)

	stopButton.Activated:Connect(function()
		send("Stop", runId)
	end)

	-- The remotes (the server makes them even while Web Scour is off, so this never waits forever
	-- in a real game).
	task.spawn(function()
		-- (What Remotes.Event does on a client, without requiring Remotes here: requiring it
		-- waits for the Remotes folder, and this module must load without waiting.)
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		action = remotes:WaitForChild("WebScourAction") :: RemoteEvent
		local run = remotes:WaitForChild("WebScourRun") :: RemoteEvent
		run.OnClientEvent:Connect(function(message: unknown)
			if type(message) ~= "table" then
				return
			end
			local m = message :: { [string]: any }
			local op = m.Op
			local sameRun = number(m.RunId) == runId
			if op == "Start" then
				onStart(m)
			elseif op == "Found" and sameRun then
				onFound(m)
			elseif op == "Miss" and sameRun then
				onMiss(m)
			elseif op == "End" and sameRun then
				onEnd(m)
			elseif op == "Note" and type(m.Text) == "string" then
				note(m.Text)
			end
		end)
	end)
end

return WebScourUI
