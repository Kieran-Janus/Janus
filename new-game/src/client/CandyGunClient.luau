--!strict
--[[
	Pumpkin Hide & Seek, the world side on this player's screen (settings: Config.HideSeek):
	  - aiming and shooting the candy gun: PC clicks where the mouse is (a crosshair replaces
	    the mouse while the gun is out), phones and tablets tap where to throw, gamepads use the
	    crosshair in the middle of the screen (right trigger). Only says WHERE you aimed: the
	    server decides what the candy hits (src/server/Modes/HideSeek.luau).
	  - every candy flying, splatting and the "TAGGED!" burst where it lands, for everyone nearby
	  - hiders' giggles (3D sound) and sparkle puffs
	Not a screen of its own (not in Main.client.luau's ORDER): HideSeekUI mounts it once the
	first Hide & Seek round starts and passes it the server's events.

	CandyGunClient.Mount(shoot: RemoteEvent)
	CandyGunClient.OnEvent(kind: string, data: { [string]: any })
	CandyGunClient.Equipped() -> boolean   the local player has the candy gun out
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local CandyGunClient = {}

local AIM_DISTANCE = 1000 -- studs the aiming ray looks for something to hit
local SHOW_DISTANCE = 450 -- effects further than this from the camera are skipped
local SEND_MARGIN = 0.05 -- seconds of slack so a click never reaches the server too early

local player = Players.LocalPlayer
local shootRemote: RemoteEvent? = nil
local mounted = false
local readyAt = 0 -- os.clock() when the gun can fire again (the server checks too)
local lastSentAt = 0

local effectsFolder: Folder? = nil
local splats: { Instance } = {}

-- Crosshair (set in Mount)
local crosshair: Frame? = nil
local reload: Frame? = nil
local reloadFill: Frame? = nil
local tapHint: TextLabel? = nil
local hidMouse = false

local function folder(): Folder
	local existing = effectsFolder
	if existing and existing.Parent then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "CandyEffects" -- only on this player's screen
	f.Parent = workspace
	effectsFolder = f
	return f
end

local function effectsGroup(): SoundGroup?
	local group = SoundService:FindFirstChild("Effects")
	return if group and group:IsA("SoundGroup") then group else nil
end

-- A 3D sound from `part` (Config.HideSeek.Sounds spec), in the Effects group.
local function play3D(spec: any, part: BasePart)
	if type(spec) ~= "table" or type(spec.SoundId) ~= "string" or spec.SoundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.SoundId
	sound.Volume = spec.Volume or 0.5
	local low = spec.PitchMin or 1
	local high = spec.PitchMax or low
	sound.PlaybackSpeed = low + math.random() * (high - low)
	sound.RollOffMinDistance = spec.RollOffMin or 10
	sound.RollOffMaxDistance = spec.RollOffMax or 80
	sound.SoundGroup = effectsGroup()
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 8)
end

-- A little invisible part to hang sounds, particles and labels on.
local function anchor(position: Vector3, seconds: number): Part
	local p = Instance.new("Part")
	p.Name = "CandyFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = folder()
	Debris:AddItem(p, seconds)
	return p
end

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= SHOW_DISTANCE
end

local function candyColor(index: unknown): Color3
	local colors = Config.HideSeek.Gun.CandyColors
	local i = if typeof(index) == "number" then math.clamp(math.floor(index), 1, #colors) else 1
	return colors[i]
end

local function piece(
	name: string,
	size: Vector3,
	color: Color3,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Candy splat --------------------------------------------------------------------------------

local function splat(position: Vector3, normal: Vector3, color: Color3)
	local cfg = Config.HideSeek.Gun
	local m = Instance.new("Model")
	m.Name = "CandySplat"
	local side = normal:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = normal:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local other = normal:Cross(side)
	local function disc(offset: Vector3, diameter: number)
		local p =
			piece("Splat", Vector3.new(0.08, diameter, diameter), color, m, Enum.PartType.Cylinder)
		-- A cylinder's round faces point along its X axis: X = the surface's normal.
		p.CFrame = CFrame.fromMatrix(position + normal * 0.05 + offset, normal, side)
	end
	disc(Vector3.zero, math.random(20, 28) / 10)
	for _ = 1, 4 do
		local angle = math.random() * math.pi * 2
		local distance = 1.3 + math.random() * 1
		disc(
			(side * math.cos(angle) + other * math.sin(angle)) * distance,
			0.4 + math.random() * 0.5
		)
	end
	m.Parent = folder()
	table.insert(splats, m)
	while #splats > cfg.MaxSplats do
		local oldest = table.remove(splats, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(cfg.SplatSeconds, function()
		if not m.Parent then
			return
		end
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
		end
		task.wait(1.1)
		local index = table.find(splats, m)
		if index then
			table.remove(splats, index)
		end
		m:Destroy()
	end)
end

-- "TAGGED!" over a found pumpkin, with a candy confetti burst.
local function taggedBurst(position: Vector3)
	local cfg = Config.HideSeek
	local holder = anchor(position, 3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	local colors = cfg.Gun.CandyColors
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[math.min(3, #colors)]),
		ColorSequenceKeypoint.new(1, colors[#colors]),
	})
	emitter.Size = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(0.9, 1.5)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.LightEmission = 0.4
	emitter.Parent = holder
	emitter:Emit(40)

	local board = Instance.new("BillboardGui")
	board.Name = "TaggedPop"
	board.Size = UDim2.fromOffset(220, 60)
	board.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = cfg.Text.Tagged
	label.TextColor3 = cfg.Colors.Tagged
	label.TextStrokeTransparency = 0.1
	label.Parent = board
	board.Parent = holder
	TweenService:Create(
		board,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }
	):Play()
	task.delay(0.8, function()
		TweenService
			:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end)
end

-- Flying candy -------------------------------------------------------------------------------

local function muzzleOf(shooter: unknown): Vector3?
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return nil
	end
	local character = shooter.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	return nil
end

local function fly(from: Vector3, to: Vector3, color: Color3, arrive: () -> ())
	local cfg = Config.HideSeek.Gun
	local m = Instance.new("Model")
	m.Name = "Candy"
	local ball = piece("Sweet", Vector3.new(0.7, 0.7, 0.7), color, m, Enum.PartType.Ball)
	-- The wrapper's two twists, either side of the sweet.
	local left = piece("Wrapper", Vector3.new(0.35, 0.5, 0.5), Color3.new(1, 1, 1), m)
	local right = piece("Wrapper", Vector3.new(0.35, 0.5, 0.5), Color3.new(1, 1, 1), m)
	m.Parent = folder()
	local distance = (to - from).Magnitude
	local duration = math.clamp(distance / cfg.ProjectileSpeed, 0.06, cfg.MaxFlightSeconds)
	local arc = math.min(distance * 0.06, 3)
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local a = math.min((os.clock() - started) / duration, 1)
		local position = from:Lerp(to, a) + Vector3.new(0, arc * 4 * a * (1 - a), 0)
		local spin = CFrame.Angles(0, 0, a * 12)
		local cf = CFrame.lookAt(position, position + (to - from)) * spin
		ball.CFrame = cf
		left.CFrame = cf * CFrame.new(-0.5, 0, 0)
		right.CFrame = cf * CFrame.new(0.5, 0, 0)
		if a >= 1 then
			if connection then
				connection:Disconnect()
			end
			m:Destroy()
			arrive()
		end
	end)
end

-- Events from the server ---------------------------------------------------------------------

local function onShot(data: { [string]: any })
	local cfg = Config.HideSeek
	local from, to = data.From, data.To
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local mine = data.Shooter == player
	if mine and typeof(data.Cooldown) == "number" then
		readyAt = math.max(readyAt, lastSentAt + data.Cooldown + SEND_MARGIN)
	end
	if not mine and not near(to) and not near(from) then
		return
	end
	local start = muzzleOf(data.Shooter) or from
	local color = candyColor(data.Candy)
	if mine then
		Sounds.PlaySpec(cfg.Sounds.Shoot :: any)
	end
	fly(start, to, color, function()
		local normal = data.Normal
		if data.Result == "Hider" then
			taggedBurst(to)
		elseif typeof(normal) == "Vector3" then
			splat(to, normal, color)
		end
		play3D(cfg.Sounds.Splat, anchor(to, 4))
	end)
end

local function onTagged(data: { [string]: any })
	if data.Seeker == player or data.Hider == player then
		Sounds.PlaySpec(Config.HideSeek.Sounds.Tagged :: any)
	end
end

local function onGiggle(data: { [string]: any })
	local pumpkin = data.Pumpkin
	if typeof(pumpkin) ~= "Instance" or not pumpkin:IsA("Model") then
		return -- not streamed in here, or already gone
	end
	local body = pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart", true)
	if not body or not near(body.Position) then
		return
	end
	play3D(Config.HideSeek.Sounds.Giggle, body)
	local sparkles = pumpkin:FindFirstChild("GiggleSparkles", true)
	if sparkles and sparkles:IsA("ParticleEmitter") then
		sparkles:Emit(Config.HideSeek.Effects.SparkleCount)
	end
end

function CandyGunClient.OnEvent(kind: string, data: { [string]: any })
	if kind == "Shot" then
		onShot(data)
	elseif kind == "Tagged" then
		onTagged(data)
	elseif kind == "Giggle" then
		onGiggle(data)
	end
end

-- Aiming and shooting ------------------------------------------------------------------------

function CandyGunClient.Equipped(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("CandyGun") == true
end

-- What the player is pointing at: the first thing along the camera ray through `point`.
local function aimAt(point: Vector2): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local ignore: { Instance } = { folder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

-- `point` is in viewport pixels (what the mouse location and the camera use).
local function shoot(point: Vector2)
	local remote = shootRemote
	if not remote or not CandyGunClient.Equipped() then
		return
	end
	local now = os.clock()
	if now < readyAt then
		return
	end
	local target = aimAt(point)
	if not target then
		return
	end
	lastSentAt = now
	readyAt = now + Config.HideSeek.Gun.FireCooldown + SEND_MARGIN
	remote:FireServer(target)
end

local function viewportCenter(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize / 2 else Vector2.zero
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

local function buildCrosshair()
	local color = Config.HideSeek.Colors.Seeker
	local gui = Instance.new("ScreenGui")
	gui.Name = "CandyGunAim"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- so the crosshair sits exactly where the mouse is
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Size = UDim2.fromOffset(34, 34)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.Parent = gui
	for _, bar in
		{
			{ UDim2.fromOffset(4, 10), UDim2.new(0.5, 0, 0, 5) },
			{ UDim2.fromOffset(4, 10), UDim2.new(0.5, 0, 1, -5) },
			{ UDim2.fromOffset(10, 4), UDim2.new(0, 5, 0.5, 0) },
			{ UDim2.fromOffset(10, 4), UDim2.new(1, -5, 0.5, 0) },
		}
	do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = bar[1]
		f.Position = bar[2]
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.4
		stroke.Parent = f
		f.Parent = cross
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = dot
	dot.Parent = cross
	crosshair = cross

	-- Reload bar under the crosshair (under the tap hint on touch screens).
	local bar = Instance.new("Frame")
	bar.Name = "Reload"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Size = UDim2.fromOffset(44, 6)
	bar.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
	bar.BackgroundTransparency = 0.3
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bar
	reload = bar
	reloadFill = fill

	local hint = Instance.new("TextLabel")
	hint.Name = "TapHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.fromOffset(320, 30)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 18
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.3
	hint.Text = Config.HideSeek.Text.TapHint
	hint.Visible = false
	hint.Parent = gui
	tapHint = hint
end

-- Every frame: crosshair on the mouse (or the middle for gamepads), reload bar, mouse icon.
local function updateAim()
	local cross, bar, fill, hint = crosshair, reload, reloadFill, tapHint
	if not cross or not bar or not fill or not hint then
		return
	end
	local equipped = CandyGunClient.Equipped()
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local showCross = equipped and not touch
	local wantHidden = showCross and not usingGamepad()
	if wantHidden ~= hidMouse then
		hidMouse = wantHidden
		UserInputService.MouseIconEnabled = not wantHidden
	end
	cross.Visible = showCross
	hint.Visible = equipped and touch
	local cooling = equipped and os.clock() < readyAt
	bar.Visible = cooling
	if showCross then
		local point = if usingGamepad()
			then viewportCenter()
			else UserInputService:GetMouseLocation()
		cross.Position = UDim2.fromOffset(point.X, point.Y)
		bar.Position = UDim2.fromOffset(point.X, point.Y + 22)
	else
		bar.Position = UDim2.new(0.5, 0, 1, -64)
	end
	if cooling then
		local left = readyAt - os.clock()
		local total = math.max(Config.HideSeek.Gun.FireCooldown, 0.01)
		fill.Size = UDim2.fromScale(1 - math.clamp(left / total, 0, 1), 1)
	end
end

function CandyGunClient.Mount(shoot_: RemoteEvent)
	shootRemote = shoot_
	if mounted then
		return
	end
	mounted = true
	buildCrosshair()
	RunService.RenderStepped:Connect(updateAim)

	-- PC mouse and gamepad trigger (clicks on buttons are ignored).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			shoot(UserInputService:GetMouseLocation())
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			shoot(viewportCenter())
		end
	end)
	-- Phones and tablets: tap where to throw (taps on buttons and the thumbstick don't count).
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			shoot(position)
		end
	end)
end

return CandyGunClient
