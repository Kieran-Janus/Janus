--!strict
--[[
	Builds "Spooky Town Square", the spawn hub, out of Parts from Config.Hub and Config.Npcs.
	Everything is kitbashed placeholder art: swap pieces for Creator Store models later
	(HubService only builds when Workspace.Hub is missing, so Studio edits are kept).

	HubBuilder.Build() -> Model   (also callable from the Studio command bar)
	HubBuilder.ApplyLighting()

	Client-side animation hooks (see src/client/HubAmbience.luau):
	  tag "HubFloat"   on Models that bob (attributes BobHeight, Phase)
	  tag "HubFlicker" on PointLights that flicker
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HubBuilder = {}

local hubCfg = Config.Hub
local colors = hubCfg.Colors
local rng = Random.new(hubCfg.Seed)

-- Helpers ------------------------------------------------------------------------------

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function wedge(props: { [string]: any }, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(w :: any)[key] = value
	end
	w.Parent = parent
	return w
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function at(offset: Vector3): Vector3
	return hubCfg.Center + offset
end

-- A CFrame at `position` turned to face the hub centre (flat).
local function facingCenter(position: Vector3): CFrame
	local target = Vector3.new(hubCfg.Center.X, position.Y, hubCfg.Center.Z)
	if (target - position).Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, target)
end

-- Upright cylinder (Roblox cylinders point along X, so rotate onto Y).
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- Rough cone from stacked discs: bottom radius r1 to top radius r2 over `height`.
local function cone(
	base: CFrame,
	r1: number,
	r2: number,
	height: number,
	layers: number,
	color: Color3,
	parent: Instance
)
	local h = height / layers
	for i = 0, layers - 1 do
		local r = r1 + (r2 - r1) * (i / math.max(layers - 1, 1))
		part({
			Name = "Cone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, r * 2, r * 2),
			CFrame = upright(base * CFrame.new(0, h * (i + 0.5), 0)),
			Color = color,
		}, parent)
	end
end

local function light(
	parent: BasePart,
	color: Color3,
	range: number,
	brightness: number,
	flicker: boolean
)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(l, "HubFlicker")
	end
	return l
end

local function nameTag(text: string, adornee: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = colors.Glow
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

local function surfaceText(target: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = target
end

local function particles(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- An invisible, non-colliding part used to hold lights, particles and prompts.
local function holder(name: string, cf: CFrame, size: Vector3, parent: Instance): Part
	return part({
		Name = name,
		CFrame = cf,
		Size = size,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

local function float(m: Model, bob: number)
	m:SetAttribute("BobHeight", bob)
	m:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	CollectionService:AddTag(m, "HubFloat")
end

-- Decorations --------------------------------------------------------------------------

-- Glowing carved face on the front of a ball of diameter `size` (front = cf.LookVector).
local function carvedFace(cf: CFrame, size: number, parent: Instance)
	local r = size / 2
	local function onSurface(x: number, y: number): CFrame
		local z = math.sqrt(math.max(r * r - x * x - y * y, 0))
		return cf * CFrame.new(x, y, -z + 0.05)
	end
	for _, side in { -1, 1 } do
		-- Triangle eyes: a wedge turned so its triangle faces forward.
		wedge({
			Name = "Eye",
			Size = Vector3.new(0.1, size * 0.18, size * 0.16),
			CFrame = onSurface(side * r * 0.35, r * 0.25)
				* CFrame.Angles(0, math.rad(90 * side), 0),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, parent)
	end
	part({
		Name = "Mouth",
		Size = Vector3.new(size * 0.45, size * 0.1, 0.1),
		CFrame = onSurface(0, -r * 0.3),
		Color = colors.Glow,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
end

local function jackOLantern(cf: CFrame, size: number, parent: Instance): Model
	local m = model("JackOLantern", parent)
	local body = part({
		Name = "Pumpkin",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size * 1.15, size, size * 1.15),
		CFrame = cf * CFrame.new(0, size / 2, 0),
		Color = colors.Orange,
	}, m)
	part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size * 0.3, size * 0.18, size * 0.18),
		CFrame = upright(cf * CFrame.new(0, size + size * 0.1, 0)),
		Color = colors.Green,
	}, m)
	carvedFace(cf * CFrame.new(0, size / 2, 0), size, m)
	light(body, colors.Glow, size * 4, 1.2, true)
	m.PrimaryPart = body
	return m
end

local function cobweb(cf: CFrame, size: number, parent: Instance)
	local m = model("Cobweb", parent)
	local spokes = 6
	local points: { { Vector3 } } = {}
	for i = 1, spokes do
		local a = (i / spokes) * math.pi * 2
		local dir = (cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a))
		part({
			Name = "Strand",
			Size = Vector3.new(0.06, 0.06, size),
			CFrame = CFrame.lookAt(cf.Position + dir * size / 2, cf.Position + dir * size),
			Color = colors.Bone,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
		}, m)
		points[i] = { cf.Position + dir * size * 0.45, cf.Position + dir * size * 0.85 }
	end
	for ring = 1, 2 do
		for i = 1, spokes do
			local a = points[i][ring]
			local b = points[i % spokes + 1][ring]
			part({
				Name = "Strand",
				Size = Vector3.new(0.05, 0.05, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = colors.Bone,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
			}, m)
		end
	end
end

local function buildGround(hub: Model): BasePart
	local radius = hubCfg.Radius
	local ground = part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		Color = hubCfg.GroundColor,
		Material = hubCfg.GroundMaterial,
	}, hub)
	-- A darker ring path around the square.
	part({
		Name = "Path",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.05, radius * 1.45, radius * 1.45),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		Color = hubCfg.GroundColor:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.Slate,
	}, hub)
	part({
		Name = "Inner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, radius * 1.3, radius * 1.3),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		Color = hubCfg.GroundColor,
		Material = hubCfg.GroundMaterial,
	}, hub)
	return ground
end

local function buildSpawn(hub: Model)
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn"
	s.Anchored = true
	s.Neutral = true
	s.Duration = 0
	s.Size = hubCfg.Spawn.Size
	s.CFrame = facingCenter(at(hubCfg.Spawn.Offset + Vector3.new(0, 1.1, 0)))
	s.Color = colors.Purple
	s.Material = Enum.Material.SmoothPlastic
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = hub
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	surfaceText(s, "BOO!", colors.Orange, Enum.NormalId.Top)
end

local function buildClockTower(hub: Model)
	local cfg = hubCfg.ClockTower
	local tower = model("ClockTower", hub)
	local cf = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	local faceFloor: CFrame = cf
	local width: number = cfg.Width
	for i = 1, cfg.Floors do
		width = cfg.Width * (1 - 0.06 * (i - 1))
		local floorCf = cf * CFrame.new(0, cfg.FloorHeight / 2, 0)
		part({
			Name = "Floor" .. i,
			Size = Vector3.new(width, cfg.FloorHeight, width),
			CFrame = floorCf,
			Color = if i % 2 == 0 then colors.Stone else colors.Stone:Lerp(colors.Purple, 0.25),
			Material = Enum.Material.Brick,
		}, tower)
		-- A glowing window on each side of the floor.
		for _, side in { 0, 90, 180, 270 } do
			part({
				Name = "Window",
				Size = Vector3.new(width * 0.25, cfg.FloorHeight * 0.4, 0.2),
				CFrame = floorCf
					* CFrame.Angles(0, math.rad(side), 0)
					* CFrame.new(0, 0, -width / 2 - 0.05),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, tower)
		end
		if i == cfg.Floors - 1 then
			faceFloor = floorCf
		end
		cf = cf * CFrame.new(0, cfg.FloorHeight, 0) * CFrame.Angles(0, 0, math.rad(cfg.Lean))
	end
	-- Pointy roof from shrinking slabs, with a glowing tip.
	for i = 0, 5 do
		local w = width * (1.1 - i * 0.18)
		part({
			Name = "Roof",
			Size = Vector3.new(w, 2, w),
			CFrame = cf * CFrame.new(0, 1 + i * 2, 0),
			Color = colors.Purple:Lerp(Color3.new(0, 0, 0), 0.4),
			Material = Enum.Material.Slate,
		}, tower)
	end
	local tip = part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		CFrame = cf * CFrame.new(0, 14, 0),
		Color = colors.Orange,
		Material = Enum.Material.Neon,
	}, tower)
	light(tip, colors.Orange, 30, 2, true)

	-- Clock face just outside the front of the second-to-top floor.
	local faceWidth = cfg.Width * (1 - 0.06 * (cfg.Floors - 2))
	local faceCf = faceFloor * CFrame.new(0, 0, -faceWidth / 2 - 0.3)
	local diameter = faceWidth * 0.75
	part({
		Name = "ClockFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, diameter, diameter),
		CFrame = faceCf * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Bone,
		Material = Enum.Material.Neon,
	}, tower)
	local function hand(name: string, angle: number, length: number, thickness: number)
		part({
			Name = name,
			Size = Vector3.new(thickness, length, 0.2),
			CFrame = faceCf * CFrame.Angles(0, 0, -angle) * CFrame.new(0, length / 2, -0.35),
			Color = colors.Iron,
		}, tower)
	end
	local t = cfg.ClockTime
	hand("HourHand", ((t.Hour % 12) + t.Minute / 60) / 12 * math.pi * 2, diameter * 0.28, 0.5)
	hand("MinuteHand", t.Minute / 60 * math.pi * 2, diameter * 0.42, 0.3)
	for i = 0, 3 do
		part({
			Name = "Mark",
			Size = Vector3.new(0.4, 0.9, 0.2),
			CFrame = faceCf
				* CFrame.Angles(0, 0, math.rad(i * 90))
				* CFrame.new(0, diameter * 0.4, -0.3),
			Color = colors.Iron,
		}, tower)
	end

	-- Cobwebs in the bottom front corners.
	local base = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	for _, side in { -1, 1 } do
		cobweb(
			base
				* CFrame.new(
					side * (cfg.Width / 2 - 0.2),
					cfg.FloorHeight - 1.5,
					-cfg.Width / 2 - 0.15
				)
				* CFrame.Angles(0, 0, math.rad(side * 45)),
			hubCfg.Cobwebs.Size,
			tower
		)
	end
end

local function buildCauldron(hub: Model)
	local cfg = hubCfg.Cauldron
	local m = model("Cauldron", hub)
	local base = CFrame.new(at(cfg.Offset + Vector3.new(0, 1, 0)))
	local r = cfg.Radius
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		part({
			Name = "Leg",
			Size = Vector3.new(0.8, 2, 0.8),
			CFrame = base * CFrame.new(math.cos(a) * r * 0.6, 1, math.sin(a) * r * 0.6),
			Color = colors.Iron,
		}, m)
	end
	part({
		Name = "Pot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(r * 2, r * 1.6, r * 2),
		CFrame = base * CFrame.new(0, r * 0.9 + 1, 0),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, m)
	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, r * 1.8, r * 1.8),
		CFrame = upright(base * CFrame.new(0, r * 1.55 + 1, 0)),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, m)
	local brew = part({
		Name = "Brew",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, r * 1.6, r * 1.6),
		CFrame = upright(base * CFrame.new(0, r * 1.65 + 1, 0)),
		Color = colors.Green,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, m)
	light(brew, colors.Green, 20, 2, true)
	local p = hubCfg.Particles.Bubbles
	particles(brew, {
		Rate = p.Rate,
		Color = ColorSequence.new(p.Color),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Right, -- the disc is rotated, so +X points up
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 2
	fire.Color = colors.Orange
	fire.SecondaryColor = colors.Glow
	fire.Parent = holder("Embers", base * CFrame.new(0, 0.5, 0), Vector3.one, m)
end

local function buildLampsAndBunting(hub: Model)
	local cfg = hubCfg.Lampposts
	local folder = model("Lampposts", hub)
	local tops: { Vector3 } = {}
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2
		local pos = at(Vector3.new(math.cos(a) * cfg.Radius, 1, math.sin(a) * cfg.Radius))
		part({
			Name = "Pole",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(cfg.Height, 0.7, 0.7),
			CFrame = upright(CFrame.new(pos + Vector3.new(0, cfg.Height / 2, 0))),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, folder)
		local lantern = part({
			Name = "Lantern",
			Size = Vector3.new(1.6, 2, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, cfg.Height + 1, 0)),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, folder)
		part({
			Name = "Cap",
			Size = Vector3.new(2.2, 0.5, 2.2),
			CFrame = CFrame.new(pos + Vector3.new(0, cfg.Height + 2.25, 0)),
			Color = colors.Iron,
		}, folder)
		light(lantern, colors.Glow, 22, 1.5, true)
		tops[i] = pos + Vector3.new(0, cfg.Height - 0.5, 0)
		if i % 3 == 0 then
			cobweb(
				CFrame.lookAt(
					pos + Vector3.new(0, cfg.Height - 2, 0),
					at(Vector3.zero) + Vector3.new(0, cfg.Height - 2, 0)
				) * CFrame.new(0, 0, -0.5),
				hubCfg.Cobwebs.Size * 0.6,
				folder
			)
		end
	end

	-- Bunting: a sagging rope between neighbouring lamps with diamond flags.
	local bunting = model("Bunting", hub)
	local b = hubCfg.Bunting
	for i = 1, #tops do
		local a, c = tops[i], tops[i % #tops + 1]
		local function point(t: number): Vector3
			return a:Lerp(c, t) - Vector3.new(0, b.Sag * 4 * t * (1 - t), 0)
		end
		local segments = b.FlagsPerSpan + 1
		for s = 0, segments - 1 do
			local p1, p2 = point(s / segments), point((s + 1) / segments)
			part({
				Name = "Rope",
				Size = Vector3.new(0.12, 0.12, (p2 - p1).Magnitude),
				CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
				Color = colors.Bone,
				CanCollide = false,
				CanQuery = false,
			}, bunting)
		end
		local along = (c - a).Unit
		local normal = along:Cross(Vector3.yAxis).Unit
		for f = 1, b.FlagsPerSpan do
			local p = point(f / segments)
			local colorName = b.Colors[(f - 1) % #b.Colors + 1]
			-- A square turned 45 degrees hangs as a diamond from the rope.
			part({
				Name = "Flag",
				Size = Vector3.new(0.1, 1.4, 1.4),
				CFrame = CFrame.fromMatrix(p - Vector3.new(0, 1, 0), normal, Vector3.yAxis)
					* CFrame.Angles(math.rad(45), 0, 0),
				Color = colors[colorName],
				CanCollide = false,
				CanQuery = false,
			}, bunting)
		end
	end
end

local function buildJackOLanterns(hub: Model)
	local cfg = hubCfg.JackOLanterns
	local folder = model("JackOLanterns", hub)
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2 + math.pi / cfg.Count
		local pos = at(Vector3.new(math.cos(a) * cfg.Radius, 1, math.sin(a) * cfg.Radius))
		local size = cfg.Size * rng:NextNumber(0.75, 1.25)
		jackOLantern(
			facingCenter(pos) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			size,
			folder
		)
	end
end

local function buildCandles(hub: Model)
	local cfg = hubCfg.Candles
	local folder = model("FloatingCandles", hub)
	for _ = 1, cfg.Count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(cfg.MinRadius, cfg.MaxRadius)
		local pos = at(
			Vector3.new(
				math.cos(a) * r,
				rng:NextNumber(cfg.MinHeight, cfg.MaxHeight),
				math.sin(a) * r
			)
		)
		local m = model("Candle", folder)
		local height = rng:NextNumber(1.2, 2.2)
		local stick = part({
			Name = "Wax",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 0.6, 0.6),
			CFrame = upright(CFrame.new(pos)),
			Color = colors.Bone,
			CanCollide = false,
			CanQuery = false,
		}, m)
		local flame = part({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.6, 0.35),
			CFrame = CFrame.new(pos + Vector3.new(0, height / 2 + 0.3, 0)),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		}, m)
		light(flame, colors.Glow, 8, 0.8, true)
		m.PrimaryPart = stick
		float(m, cfg.BobHeight)
	end
end

local function buildGraveyard(hub: Model)
	local cfg = hubCfg.Graveyard
	local folder = model("Graveyard", hub)
	local origin = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	for i, epitaph in cfg.Epitaphs do
		local row = (i - 1) // 3
		local col = (i - 1) % 3
		local cf = origin
			* CFrame.new((col - 1) * 7, 0, row * 7)
			* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-8, 8)))
		local slab = part({
			Name = "Tombstone",
			Size = Vector3.new(3.4, 3.6, 0.8),
			CFrame = cf * CFrame.new(0, 1.8, 0),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, folder)
		part({
			Name = "Top",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 3.4, 3.4),
			CFrame = cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, folder)
		surfaceText(slab, epitaph, colors.Bone)
		-- Little mound of dirt in front.
		part({
			Name = "Mound",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 0.8, 4.5),
			CFrame = cf * CFrame.new(0, 0, -2.8),
			Color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = Enum.Material.Ground,
		}, folder)
	end
	-- Iron fence on three sides, open towards the plaza.
	local fence = model("Fence", folder)
	local corners = {
		origin * CFrame.new(-12, 0, -5),
		origin * CFrame.new(-12, 0, 18),
		origin * CFrame.new(12, 0, 18),
		origin * CFrame.new(12, 0, -5),
	}
	for c = 1, 3 do
		local a, b = corners[c].Position, corners[c + 1].Position
		local posts = math.floor((b - a).Magnitude / 3)
		for p = 0, posts do
			local pos = a:Lerp(b, p / posts)
			part({
				Name = "Post",
				Size = Vector3.new(0.4, 4, 0.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)),
				Color = colors.Iron,
			}, fence)
		end
		for _, y in { 1.2, 3.4 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.25, 0.25, (b - a).Magnitude),
				CFrame = CFrame.lookAt(
					(a + b) / 2 + Vector3.new(0, y, 0),
					b + Vector3.new(0, y, 0)
				),
				Color = colors.Iron,
			}, fence)
		end
	end
end

local function buildDeadTrees(hub: Model)
	local folder = model("DeadTrees", hub)
	for _, offset in hubCfg.DeadTrees.Offsets do
		local base = CFrame.new(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local height = rng:NextNumber(14, 20)
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 2.2, 2.2),
			CFrame = upright(base * CFrame.new(0, height / 2, 0)),
			Color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.35),
			Material = Enum.Material.Wood,
		}, folder)
		for b = 1, 5 do
			local y = height * rng:NextNumber(0.45, 0.95)
			local yaw = (b / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local length = rng:NextNumber(4, 8)
			local branchCf = base
				* CFrame.new(0, y, 0)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(rng:NextNumber(30, 55)), 0, 0)
				* CFrame.new(0, 0, -length / 2)
			part({
				Name = "Branch",
				Size = Vector3.new(0.6, 0.6, length),
				CFrame = branchCf,
				Color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.35),
				Material = Enum.Material.Wood,
			}, folder)
		end
		local canopy =
			holder("Leaves", base * CFrame.new(0, height, 0), Vector3.new(10, 1, 10), folder)
		local p = hubCfg.Particles.Leaves
		particles(canopy, {
			Rate = p.Rate,
			Color = ColorSequence.new(p.Color),
			Size = NumberSequence.new(0.35),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0.5, -1.2, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			EmissionDirection = Enum.NormalId.Bottom,
			Shape = Enum.ParticleEmitterShape.Box,
		})
		cobweb(base * CFrame.new(0, height * 0.6, -1.15), hubCfg.Cobwebs.Size * 0.7, folder)
	end
end

local function buildAmbientParticles(hub: Model)
	local radius = hubCfg.Radius
	local f = hubCfg.Particles.Fireflies
	local air = holder(
		"Fireflies",
		CFrame.new(at(Vector3.new(0, 6, 0))),
		Vector3.new(radius * 1.6, 8, radius * 1.6),
		hub
	)
	particles(air, {
		Rate = f.Rate,
		Color = ColorSequence.new(f.Color),
		LightEmission = 1,
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local m = hubCfg.Particles.Mist
	local ground = holder(
		"Mist",
		CFrame.new(at(Vector3.new(0, 1.5, 0))),
		Vector3.new(radius * 2, 1, radius * 2),
		hub
	)
	particles(ground, {
		Rate = m.Rate,
		Color = ColorSequence.new(m.Color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 8),
			NumberSequenceKeypoint.new(1, 14),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 10),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.FacingCamera,
	})
end

-- NPCs ----------------------------------------------------------------------------------

local function prompt(def: any, anchor: BasePart)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Interact"
	p.ActionText = def.Prompt.ActionText
	p.ObjectText = def.Prompt.ObjectText
	p.HoldDuration = Config.Npcs.Prompt.HoldDuration
	p.MaxActivationDistance = Config.Npcs.Prompt.MaxActivationDistance
	p.RequiresLineOfSight = false
	p:SetAttribute("NpcId", def.Id)
	p.Parent = anchor
end

local function eyes(cf: CFrame, spacing: number, size: number, parent: Instance)
	for _, side in { -1, 1 } do
		part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 1.3, size * 0.5),
			CFrame = cf * CFrame.new(side * spacing, 0, 0),
			Color = colors.Iron,
			CanCollide = false,
		}, parent)
	end
end

local function buildWitch(cf: CFrame, m: Model): BasePart
	local dress = colors.Purple
	cone(cf, 2.4, 1.1, 4.5, 6, dress, m)
	local head = part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.6,
		CFrame = cf * CFrame.new(0, 5.6, 0),
		Color = Color3.fromRGB(170, 225, 140),
	}, m)
	eyes(cf * CFrame.new(0, 5.8, -1.15), 0.5, 0.4, m)
	part({
		Name = "Brim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 4.6, 4.6),
		CFrame = upright(cf * CFrame.new(0, 6.7, 0)),
		Color = colors.Iron,
	}, m)
	cone(
		cf * CFrame.new(0, 6.8, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		1.3,
		0.15,
		4,
		7,
		colors.Iron,
		m
	)
	part({
		Name = "HatBand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.7, 2.7),
		CFrame = upright(cf * CFrame.new(0, 7.05, 0)),
		Color = colors.Orange,
	}, m)
	-- Broom leaning beside her and a counter of glowing potions.
	part({
		Name = "Broomstick",
		Size = Vector3.new(0.3, 7, 0.3),
		CFrame = cf * CFrame.new(3, 3.2, 0.5) * CFrame.Angles(0, 0, math.rad(-12)),
		Color = colors.Wood,
	}, m)
	part({
		Name = "Bristles",
		Size = Vector3.new(1.2, 1.6, 1.2),
		CFrame = cf * CFrame.new(3.6, 0.6, 0.5),
		Color = Color3.fromRGB(210, 170, 90),
		Material = Enum.Material.Fabric,
	}, m)
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(8, 3, 2.5),
		CFrame = cf * CFrame.new(0, 1.5, -3.5),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, m)
	for i, c in { colors.Green, colors.Purple, colors.Orange, colors.Glow } do
		local potion = part({
			Name = "Potion",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = cf * CFrame.new(-3 + i * 1.3, 3.5, -3.5),
			Color = c,
			Material = Enum.Material.Neon,
		}, m)
		if i == 1 then
			light(potion, c, 10, 1, true)
		end
	end
	nameTag(m.Name, head, 4.5)
	return counter
end

local function buildGhost(cf: CFrame, m: Model): BasePart
	local white = Color3.fromRGB(245, 245, 255)
	local base = cf * CFrame.new(0, 1.5, 0)
	cone(base, 2.2, 1.6, 3, 4, white, m)
	local head = part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.6,
		CFrame = base * CFrame.new(0, 3.6, 0),
		Color = white,
	}, m)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part({
			Name = "Wisp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2,
			CFrame = base * CFrame.new(math.cos(a) * 1.7, -0.1, math.sin(a) * 1.7),
			Color = white,
		}, m)
	end
	eyes(base * CFrame.new(0, 3.9, -1.6), 0.65, 0.55, m)
	for _, side in { -1, 1 } do
		part({
			Name = "Blush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.35, 0.2),
			CFrame = base * CFrame.new(side * 1.05, 3.3, -1.6),
			Color = Color3.fromRGB(255, 160, 190),
		}, m)
		part({
			Name = "Arm",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 1.6, 0.9),
			CFrame = base * CFrame.new(side * 2.1, 2, 0) * CFrame.Angles(0, 0, math.rad(side * 35)),
			Color = white,
		}, m)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0.08
			p.CanCollide = false
		end
	end
	light(head, Color3.fromRGB(200, 220, 255), 12, 0.8, false)
	nameTag(m.Name, head, 3.5)
	m.PrimaryPart = head
	float(m, 0.8)
	return head
end

local function buildVendor(cf: CFrame, m: Model): BasePart
	-- Stall: counter, posts and a striped awning.
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(10, 3, 3),
		CFrame = cf * CFrame.new(0, 1.5, -2.5),
		Color = colors.Wood,
		Material = Enum.Material.WoodPlanks,
	}, m)
	for _, x in { -4.6, 4.6 } do
		for _, z in { -3.8, 2.5 } do
			part({
				Name = "Post",
				Size = Vector3.new(0.5, 8, 0.5),
				CFrame = cf * CFrame.new(x, 4, z),
				Color = colors.Wood,
			}, m)
		end
	end
	for i = 0, 6 do
		part({
			Name = "Awning",
			Size = Vector3.new(1.45, 0.3, 7.5),
			CFrame = cf
				* CFrame.new(-4.35 + i * 1.45, 8.4, -0.6)
				* CFrame.Angles(math.rad(-14), 0, 0),
			Color = if i % 2 == 0 then colors.Orange else colors.Purple,
			Material = Enum.Material.Fabric,
		}, m)
	end
	for i = 0, 2 do
		jackOLantern(cf * CFrame.new(-3 + i * 3, 3, -2.5), 1.3, m)
	end
	-- The vendor: a pumpkin-headed farmer behind the counter.
	part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 2.4, 2.4),
		CFrame = upright(cf * CFrame.new(0, 2.5, 0.5)),
		Color = Color3.fromRGB(70, 110, 160),
		Material = Enum.Material.Fabric,
	}, m)
	local headCf = cf * CFrame.new(0, 6, 0.5)
	local head = part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3, 3.4),
		CFrame = headCf,
		Color = colors.Orange,
	}, m)
	carvedFace(headCf, 3, m)
	part({
		Name = "Hat",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 4.4, 4.4),
		CFrame = upright(cf * CFrame.new(0, 7.4, 0.5)),
		Color = Color3.fromRGB(200, 170, 90),
		Material = Enum.Material.Fabric,
	}, m)
	nameTag(m.Name, head, 6)
	return counter
end

local function buildBoard(cf: CFrame, m: Model): BasePart
	for _, x in { -5.5, 5.5 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.8, 12, 0.8),
			CFrame = cf * CFrame.new(x, 6, 0.3),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
	end
	part({
		Name = "Backing",
		Size = Vector3.new(11.5, 8, 0.6),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = colors.Wood,
		Material = Enum.Material.WoodPlanks,
	}, m)
	-- The Screen's front face carries the live vote SurfaceGui (rendered by each client).
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(10.5, 7, 0.2),
		CFrame = cf * CFrame.new(0, 7, -0.4),
		Color = Color3.fromRGB(30, 22, 40),
	}, m)
	local roof = wedge({
		Name = "Roof",
		Size = Vector3.new(13, 1.5, 1.5),
		CFrame = cf * CFrame.new(0, 11.8, -0.3),
		Color = colors.Purple,
	}, m)
	jackOLantern(cf * CFrame.new(-6.5, 0, -1), 1.8, m)
	jackOLantern(cf * CFrame.new(6.5, 0, -1), 1.8, m)
	nameTag(m.Name, roof, 2.5)
	return screen
end

local function buildGravestone(cf: CFrame, m: Model): BasePart
	local slab = part({
		Name = "Slab",
		Size = Vector3.new(10, 9, 1.6),
		CFrame = cf * CFrame.new(0, 5.5, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	part({
		Name = "Arch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 10, 10),
		CFrame = cf * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	part({
		Name = "Plinth",
		Size = Vector3.new(12, 1, 3.5),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.3),
		Material = Enum.Material.Slate,
	}, m)
	-- The Screen's front face carries the top-collectors SurfaceGui (filled by the server).
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(8.6, 10.5, 0.2),
		CFrame = cf * CFrame.new(0, 7.2, -0.85),
		Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.45),
		Material = Enum.Material.Slate,
	}, m)
	for _, x in { -6, 6 } do
		part({
			Name = "Candle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 0.8, 0.8),
			CFrame = upright(cf * CFrame.new(x, 1.8, -1.2)),
			Color = colors.Bone,
		}, m)
		local flame = part({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.4, 0.7, 0.4),
			CFrame = cf * CFrame.new(x, 3, -1.2),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, m)
		light(flame, colors.Glow, 10, 1, true)
	end
	cobweb(cf * CFrame.new(-4.4, 13, -0.85), hubCfg.Cobwebs.Size * 0.6, m)
	nameTag(m.Name, slab, 9.5)
	return screen
end

local function buildPhotoSpot(cf: CFrame, m: Model): BasePart
	local cfg = hubCfg.PhotoSpot
	local stage = part({
		Name = "Stage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = upright(cf * CFrame.new(0, 1.5, 0)),
		Color = colors.Purple,
	}, m)
	local backdrop = part({
		Name = "Backdrop",
		Size = Vector3.new(16, 10, 0.6),
		CFrame = cf * CFrame.new(0, 6, 6.5),
		Color = Color3.fromRGB(40, 25, 60),
	}, m)
	surfaceText(backdrop, cfg.Sign, colors.Orange, Enum.NormalId.Front)
	-- Arch of little jack-o-lanterns over the front of the stage.
	local count = 11
	for i = 0, count - 1 do
		local a = math.pi * (i / (count - 1))
		jackOLantern(cf * CFrame.new(math.cos(a) * 7.5, 1 + math.sin(a) * 9, -6), 1.4, m)
	end
	return stage
end

local builders: { [string]: (CFrame, Model) -> BasePart } = {
	Witch = buildWitch,
	Ghost = buildGhost,
	Vendor = buildVendor,
	Board = buildBoard,
	Gravestone = buildGravestone,
	PhotoSpot = buildPhotoSpot,
}

local function buildNpcs(hub: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = hub
	for _, def in Config.Npcs.List do
		local build = builders[def.Kind]
		if build then
			local m = model(def.Id, folder)
			m:SetAttribute("DisplayName", def.DisplayName)
			local cf = facingCenter(at(def.Offset + Vector3.new(0, 1, 0)))
			local anchor = build(cf, m)
			if not m.PrimaryPart then
				m.PrimaryPart = anchor
			end
			-- Rename so nametags read nicely.
			local tag = m:FindFirstChild("NameTag", true)
			if tag then
				local label = tag:FindFirstChildOfClass("TextLabel")
				if label then
					label.Text = def.DisplayName
				end
			end
			-- The prompt sits on its own invisible part in front of the NPC: a prompt on a part
			-- that also carries a SurfaceGui (board, gravestone) hides itself and never triggers.
			local p = Config.Npcs.Prompt
			prompt(
				def,
				holder("PromptAnchor", cf * CFrame.new(0, p.Height, -p.Forward), Vector3.one, m)
			)
		else
			warn("[HubBuilder] unknown NPC kind " .. tostring(def.Kind))
		end
	end
end

local function buildMusic(hub: Model)
	local cfg = hubCfg.Music
	if cfg.SoundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = cfg.SoundId
	sound.Volume = cfg.Volume
	sound.Looped = true
	sound.Playing = true
	sound.Parent = hub
end

-- Public ---------------------------------------------------------------------------------

function HubBuilder.ApplyLighting()
	local cfg = hubCfg.Lighting
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing and existing.ClassName == className then
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end
	local atmosphere = ensure("Atmosphere", "HubAtmosphere") :: Atmosphere
	for key, value in cfg.Atmosphere do
		(atmosphere :: any)[key] = value
	end
	local cc = ensure("ColorCorrectionEffect", "HubColorCorrection") :: ColorCorrectionEffect
	for key, value in cfg.ColorCorrection do
		(cc :: any)[key] = value
	end
	local bloom = ensure("BloomEffect", "HubBloom") :: BloomEffect
	for key, value in cfg.Bloom do
		(bloom :: any)[key] = value
	end
	-- Only one Atmosphere is used by the engine; drop any other one.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= atmosphere then
			child:Destroy()
		end
	end
end

-- The default baseplate SpawnLocation would compete with the hub spawn; switch it off.
function HubBuilder.DisableDefaultSpawn()
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child.Enabled = false
			child.Transparency = 1
			child.CanCollide = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		end
	end
end

function HubBuilder.Build(): Model
	rng = Random.new(hubCfg.Seed)
	local existing = workspace:FindFirstChild("Hub")
	if existing then
		existing:Destroy()
	end
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub:SetAttribute("HubName", hubCfg.Name)

	local ground = buildGround(hub)
	buildSpawn(hub)
	buildClockTower(hub)
	buildCauldron(hub)
	buildLampsAndBunting(hub)
	buildJackOLanterns(hub)
	buildCandles(hub)
	buildGraveyard(hub)
	buildDeadTrees(hub)
	buildAmbientParticles(hub)
	buildNpcs(hub)
	buildMusic(hub)
	hub.PrimaryPart = ground

	hub.Parent = workspace
	HubBuilder.DisableDefaultSpawn()
	return hub
end

return HubBuilder
