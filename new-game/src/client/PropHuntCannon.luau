--!strict
--[[
	Prop Hunt, the world side on this player's screen (settings: Config.PropHunt):
	  - aiming and firing the Pumpkin Cannon: PC clicks where the mouse is (a crosshair replaces
	    the mouse while the cannon is out), phones and tablets tap a thing (or press the FIRE
	    button: it fires at the crosshair in the middle of the screen), gamepads use the
	    crosshair in the middle (right trigger). Only says WHERE you aimed: the server decides
	    what the pumpkin hits (src/server/Modes/PropHunt.luau).
	  - every pumpkin flying, its orange splat and the "FOUND!" pop where it lands
	  - hiders' giggles and taunts (3D sound and a sparkle puff from their thing) and a puff of
	    smoke where a hider turns into something
	Not a screen of its own (not in Main.client.luau's ORDER): PropHuntUI mounts it once the
	first Prop Hunt round starts and passes it the server's events.

	PropHuntCannon.Mount(shoot: RemoteEvent)
	PropHuntCannon.OnEvent(kind: string, data: { [string]: any })
	PropHuntCannon.Equipped() -> boolean   the local player has the cannon out
	PropHuntCannon.Fire()                  fires at the middle of the screen (the FIRE button)
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)

local PropHuntCannon = {}

local AIM_DISTANCE = 1000 -- studs the aiming ray looks for something to hit
local SHOW_DISTANCE = 450 -- effects further than this from the camera are skipped
local SEND_MARGIN = 0.05 -- seconds of slack so a shot never reaches the server too early

local player = Players.LocalPlayer
local shootRemote: RemoteEvent? = nil
local mounted = false
local readyAt = 0
local lastSentAt = 0

local effectsFolder: Folder? = nil
local splats: { Instance } = {}

local crosshair: Frame? = nil
local reload: Frame? = nil
local reloadFill: Frame? = nil
local hidMouse = false

local function folder(): Folder
	local existing = effectsFolder
	if existing and existing.Parent then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "PumpkinEffects" -- only on this player's screen
	f.Parent = workspace
	effectsFolder = f
	return f
end

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= SHOW_DISTANCE
end

-- A little invisible part to hang sounds, particles and labels on.
local function anchor(position: Vector3, seconds: number): Part
	local p = Instance.new("Part")
	p.Name = "PumpkinFx"
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

local function piece(
	name: string,
	size: Vector3,
	color: Color3,
	parent: Instance,
	ball: boolean?
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
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = parent
	return p
end

-- A burst of particles at `position` (sparkles, smoke).
local function puff(position: Vector3, color: Color3, count: number, smoke: boolean?)
	local holder = anchor(position, 3)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(color)
	e.LightEmission = if smoke then 0 else 1
	e.Size = if smoke
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 3),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
	e.Transparency = NumberSequence.new(if smoke then 0.4 else 0, 1)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(if smoke then 2 else 5, if smoke then 4 else 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = holder
	e:Emit(ScreenFx.Count(count))
end

-- Splat ---------------------------------------------------------------------------------------

local function splat(position: Vector3, normal: Vector3)
	local cfg = Config.PropHunt.Cannon
	local m = Instance.new("Model")
	m.Name = "PumpkinSplat"
	local side = normal:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = normal:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local other = normal:Cross(side)
	local function disc(offset: Vector3, diameter: number)
		local p = piece("Splat", Vector3.new(0.08, diameter, diameter), cfg.Colors.Splat, m)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.fromMatrix(position + normal * 0.05 + offset, normal, side)
	end
	disc(Vector3.zero, math.random(24, 32) / 10)
	for _ = 1, 4 do
		local angle = math.random() * math.pi * 2
		disc(
			(side * math.cos(angle) + other * math.sin(angle)) * (1.5 + math.random()),
			0.5 + math.random() * 0.5
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

-- "FOUND!" over a found hider, with an orange burst.
local function foundPop(position: Vector3)
	local cfg = Config.PropHunt
	puff(position, cfg.Colors.Found, 40)
	local holder = anchor(position, 3)
	local board = Instance.new("BillboardGui")
	board.Name = "FoundPop"
	board.Size = UDim2.fromOffset(220, 60)
	board.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = cfg.Text.Found
	label.TextColor3 = cfg.Colors.Found
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

-- Flying pumpkin --------------------------------------------------------------------------------

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

local function fly(from: Vector3, to: Vector3, arrive: () -> ())
	local cfg = Config.PropHunt.Cannon
	local m = Instance.new("Model")
	m.Name = "FlyingPumpkin"
	local ball = piece("Pumpkin", Vector3.new(1.2, 1, 1.2), cfg.Colors.Pumpkin, m, true)
	local stem = piece("Stem", Vector3.new(0.2, 0.4, 0.2), Color3.fromRGB(90, 120, 50), m)
	m.Parent = folder()
	local distance = (to - from).Magnitude
	local duration = math.clamp(distance / cfg.ProjectileSpeed, 0.08, cfg.MaxFlightSeconds)
	local arc = math.min(distance * 0.08, 4)
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local a = math.min((os.clock() - started) / duration, 1)
		local position = from:Lerp(to, a) + Vector3.new(0, arc * 4 * a * (1 - a), 0)
		local spin = CFrame.Angles(a * 10, 0, 0)
		ball.CFrame = CFrame.new(position) * spin
		stem.CFrame = CFrame.new(position) * spin * CFrame.new(0, 0.6, 0)
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
	local cfg = Config.PropHunt
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
	if mine then
		Sounds.PlaySpec(cfg.Sounds.Fire :: any)
	end
	fly(muzzleOf(data.Shooter) or from, to, function()
		if data.Result == "Hider" then
			foundPop(to)
		elseif typeof(data.Normal) == "Vector3" then
			splat(to, data.Normal)
		end
		if ScreenFx.On() then
			puff(to, cfg.Cannon.Colors.Splat, 12)
		end
		Sounds.PlaySpec(cfg.Sounds.Splat :: any, anchor(to, 4))
	end)
end

local function bodyOf(prop: unknown): BasePart?
	if typeof(prop) ~= "Instance" or not prop:IsA("Model") then
		return nil -- not streamed in here, or already gone
	end
	return prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true)
end

local function onGiggle(data: { [string]: any })
	local body = bodyOf(data.Prop)
	if not body or not near(body.Position) then
		return
	end
	Sounds.PlaySpec(Config.PropHunt.Sounds.Giggle :: any, body)
	local sparkles = (data.Prop :: Model):FindFirstChild("GiggleSparkles", true)
	if sparkles and sparkles:IsA("ParticleEmitter") then
		sparkles:Emit(ScreenFx.Count(Config.PropHunt.Effects.SparkleCount))
	end
end

local function onBecame(data: { [string]: any })
	local body = bodyOf(data.Prop)
	if not body or not near(body.Position) then
		return
	end
	puff(body.Position, Color3.fromRGB(200, 190, 220), 14, true)
	if data.Hider == player then
		Sounds.PlaySpec(Config.PropHunt.Sounds.Become :: any)
	end
end

function PropHuntCannon.OnEvent(kind: string, data: { [string]: any })
	if kind == "Shot" then
		onShot(data)
	elseif kind == "Found" then
		if data.Seeker == player or data.Hider == player then
			Sounds.PlaySpec(Config.PropHunt.Sounds.Found :: any)
		end
	elseif kind == "Giggle" then
		onGiggle(data)
	elseif kind == "Became" then
		onBecame(data)
	end
end

-- Aiming and firing ------------------------------------------------------------------------------

function PropHuntCannon.Equipped(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("PumpkinCannon") == true
end

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

local function viewportCenter(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize / 2 else Vector2.zero
end

-- `point` is in viewport pixels. Returns true when a shot was sent.
local function shoot(point: Vector2): boolean
	local remote = shootRemote
	if not remote or not PropHuntCannon.Equipped() then
		return false
	end
	local now = os.clock()
	if now < readyAt then
		return false
	end
	local target = aimAt(point)
	if not target then
		return false
	end
	lastSentAt = now
	readyAt = now + Config.PropHunt.Cannon.FireCooldown + SEND_MARGIN
	remote:FireServer(target)
	local cross = crosshair
	if cross and ScreenFx.On() then
		ScreenFx.Punch(cross, 1.4, 0.2, 8)
	end
	return true
end

function PropHuntCannon.Fire()
	shoot(viewportCenter())
end

-- Seconds until the cannon can fire again (0 = ready), and the whole wait.
function PropHuntCannon.Cooldown(): (number, number)
	return math.max(0, readyAt - os.clock()), math.max(Config.PropHunt.Cannon.FireCooldown, 0.01)
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function buildCrosshair()
	local color = Config.PropHunt.Colors.Seeker
	local gui = Instance.new("ScreenGui")
	gui.Name = "PumpkinCannonAim"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Size = UDim2.fromOffset(36, 36)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.Parent = gui
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = cross
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = color
	stroke.Parent = ring
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	dot.Parent = cross
	crosshair = cross

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
end

-- Every frame while the cannon is out: crosshair (mouse, or the middle for gamepads and
-- touch screens), reload bar, mouse icon.
local function updateAim()
	local cross, bar, fill = crosshair, reload, reloadFill
	if not cross or not bar or not fill then
		return
	end
	local equipped = PropHuntCannon.Equipped()
	if not equipped and not hidMouse and not (cross.Visible or bar.Visible) then
		return
	end
	local middle = usingGamepad() or touchOnly()
	local wantHidden = equipped and not middle
	if wantHidden ~= hidMouse then
		hidMouse = wantHidden
		UserInputService.MouseIconEnabled = not wantHidden
	end
	cross.Visible = equipped
	local cooling = equipped and os.clock() < readyAt
	bar.Visible = cooling
	if equipped then
		local point = if middle then viewportCenter() else UserInputService:GetMouseLocation()
		cross.Position = UDim2.fromOffset(point.X, point.Y)
		bar.Position = UDim2.fromOffset(point.X, point.Y + 24)
	end
	if cooling then
		local left, total = PropHuntCannon.Cooldown()
		fill.Size = UDim2.fromScale(1 - math.clamp(left / total, 0, 1), 1)
	end
end

function PropHuntCannon.Mount(shoot_: RemoteEvent)
	shootRemote = shoot_
	if mounted then
		return
	end
	mounted = true
	buildCrosshair()
	RunService.RenderStepped:Connect(updateAim)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			shoot(UserInputService:GetMouseLocation())
		elseif table.find(Config.PropHunt.Keys.Fire, input.KeyCode) then
			shoot(viewportCenter())
		end
	end)
	-- Phones and tablets: tap a thing (taps on buttons and the thumbstick don't count).
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			shoot(position)
		end
	end)
end

return PropHuntCannon
