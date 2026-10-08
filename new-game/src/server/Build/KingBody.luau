--!strict
--[[
	The Pumpkin King's placeholder body, built from parts (used when there is no custom
	PumpkinKing model in ReplicatedStorage.Custom.Characters).

	A coat to the knees over two striding legs with pointy boots, a cape, gold shoulders, vine
	arms reaching forward with claws, a ribbed pumpkin head with an angry glowing carved face,
	a gold crown with gems on top, and embers rising off the head.

	Colours, sizes, the face glow and the embers are in Config.King (BodyColor, HeadColor,
	CrownColor, CapeColor, VineColor, FaceColor, GemColor, HeadSize, FaceGlow, Embers).
	Everything above the legs is welded to a hidden Pelvis, jointed (Motor6D "Waist") to the
	HumanoidRootPart that KingService moves; the legs hang from the Pelvis on Hip and Knee
	joints. Players' screens animate those joints (src/client/KingStride.luau): the server
	never moves them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local KingBody = {}

-- The root's centre sits HipHeight + 1 above the floor (the root is 2 studs tall).
local function floorOffset(): number
	return Config.King.HipHeight + 1
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

type Builder = {
	model: Model,
	root: BasePart,
	anchor: BasePart, -- what new parts are welded to (the Pelvis, or a shin for the boots)
	-- y is measured from the floor; the King faces -Z.
	part: (
		self: Builder,
		name: string,
		size: Vector3,
		at: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?,
		decor: boolean?
	) -> BasePart,
	wedge: (
		self: Builder,
		name: string,
		size: Vector3,
		at: CFrame,
		color: Color3,
		material: Enum.Material
	) -> BasePart,
}

local function attach(b: Builder, p: BasePart, at: CFrame, decor: boolean?)
	p.CFrame = b.root.CFrame * CFrame.new(0, -floorOffset(), 0) * at
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if decor then
		-- Small details don't catch on touch (CatchRange does that) and don't block rays.
		p.CanTouch = false
		p.CanQuery = false
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = b.anchor
	w.Part1 = p
	w.Parent = p
	p.Parent = b.model
end

local function newBuilder(model: Model, root: BasePart, anchor: BasePart): Builder
	local b = { model = model, root = root, anchor = anchor } :: any
	function b.part(self: Builder, name, size, at, color, material, shape, decor)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.Material = material
		attach(self, p, at, decor)
		return p
	end
	function b.wedge(self: Builder, name, size, at, color, material)
		local p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		attach(self, p, at, true)
		return p
	end
	return b :: Builder
end

-- A cylinder standing upright (Roblox cylinders lie along X).
local function upright(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
end

-- How the legs are laid out (studs from the floor). LegLength = the hip's height.
local HIP_Y, THIGH, SHIN, BOOT = 3.5, 1.65, 1.35, 0.5
local LEG_X = 0.8 -- each leg's distance from the middle

local function coat(b: Builder)
	local cfg = Config.King
	-- A coat skirt flaring from the waist to the knees, so the legs show below it.
	local tiers, bottom, top = 5, 2.3, 4.1
	local step = (top - bottom) / tiers
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1) -- 0 at the hem, 1 at the waist
		local width = 4.0 - 0.7 * t
		b:part(
			"Coat" .. i,
			Vector3.new(step + 0.02, width, width),
			upright(0, bottom + step * (i - 0.5), 0),
			cfg.BodyColor,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
	end
	-- Gold trim around the hem and down the front.
	b:part(
		"Hem",
		Vector3.new(0.3, 4.1, 4.1),
		upright(0, bottom + 0.1, 0),
		cfg.CrownColor,
		Enum.Material.Metal,
		Enum.PartType.Cylinder,
		true
	)
	b:part(
		"CoatStripe",
		Vector3.new(0.45, top - bottom, 0.2),
		CFrame.new(0, (top + bottom) / 2, -1.88) * CFrame.Angles(math.rad(11), 0, 0),
		cfg.CrownColor,
		Enum.Material.Metal,
		nil,
		true
	)
end

--[[
	Two legs on joints (Motor6D) so players' screens can make him stride (client KingStride):
	Pelvis -> LeftHip/RightHip -> thigh -> LeftKnee/RightKnee -> shin (+ a pointy boot).
]]
local function legs(b: Builder, pelvis: BasePart)
	local cfg = Config.King
	local trousers = darker(cfg.BodyColor, 0.35)
	for side = -1, 1, 2 do
		local name = if side < 0 then "Left" else "Right"
		local function joint(
			jointName: string,
			part0: BasePart,
			part1: BasePart,
			c0: CFrame,
			c1: CFrame
		)
			part1.CFrame = part0.CFrame * c0 * c1:Inverse()
			local motor = Instance.new("Motor6D")
			motor.Name = jointName
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = c0
			motor.C1 = c1
			motor.Parent = part0
		end
		local function limb(limbName: string, size: Vector3, color: Color3): BasePart
			local p = Instance.new("Part")
			p.Name = limbName
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.Fabric
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CastShadow = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = b.model
			return p
		end
		local thigh = limb(name .. "Thigh", Vector3.new(0.95, THIGH, 0.95), trousers)
		joint(
			name .. "Hip",
			pelvis,
			thigh,
			CFrame.new(side * LEG_X, 0, 0),
			CFrame.new(0, THIGH / 2, 0)
		)
		local shin = limb(name .. "Shin", Vector3.new(0.8, SHIN, 0.8), trousers)
		joint(name .. "Knee", thigh, shin, CFrame.new(0, -THIGH / 2, 0), CFrame.new(0, SHIN / 2, 0))

		-- The boot and its curled toe go along with the shin (welded to it).
		local anchor = b.anchor
		b.anchor = shin
		local x = side * LEG_X
		b:part(
			"Boot",
			Vector3.new(0.95, BOOT, 1.5),
			CFrame.new(x, BOOT / 2, -0.25),
			Color3.fromRGB(25, 18, 22),
			Enum.Material.Leather,
			nil,
			true
		)
		b:part(
			"Toe",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(x, BOOT * 0.7, -1.05) * CFrame.Angles(math.rad(45), 0, 0),
			Color3.fromRGB(25, 18, 22),
			Enum.Material.Leather,
			nil,
			true
		)
		b:part(
			"Buckle",
			Vector3.new(0.45, 0.3, 0.1),
			CFrame.new(x, BOOT * 0.6, -1.0),
			cfg.CrownColor,
			Enum.Material.Metal,
			nil,
			true
		)
		b.anchor = anchor
	end
end

local function torso(b: Builder)
	local cfg = Config.King
	b:part(
		"Body",
		Vector3.new(3.2, 3.2, 2.1),
		CFrame.new(0, 5.5, 0),
		cfg.BodyColor,
		Enum.Material.Fabric
	)
	b:part(
		"Belt",
		Vector3.new(3.3, 0.5, 2.2),
		CFrame.new(0, 4.3, 0),
		darker(cfg.BodyColor, 0.5),
		Enum.Material.Leather,
		nil,
		true
	)
	b:part(
		"Buckle",
		Vector3.new(0.9, 0.7, 0.2),
		CFrame.new(0, 4.3, -1.12),
		cfg.CrownColor,
		Enum.Material.Metal,
		nil,
		true
	)
	-- A gold V down the chest and a little pumpkin brooch.
	for side = -1, 1, 2 do
		b:part(
			"Lapel",
			Vector3.new(0.3, 2.4, 0.15),
			CFrame.new(side * 0.55, 5.85, -1.07) * CFrame.Angles(0, 0, math.rad(side * -20)),
			cfg.CrownColor,
			Enum.Material.Metal,
			nil,
			true
		)
	end
	b:part(
		"Brooch",
		Vector3.one * 0.6,
		CFrame.new(0, 5.05, -1.05),
		cfg.HeadColor,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball,
		true
	)
	b:part(
		"Neck",
		Vector3.new(0.8, 1.1, 1.1),
		upright(0, 7.3, 0),
		cfg.VineColor,
		Enum.Material.Grass,
		Enum.PartType.Cylinder,
		true
	)

	-- Cape from the shoulders, flaring out behind.
	b:part(
		"Cape",
		Vector3.new(4.4, 6, 0.2),
		CFrame.new(0, 7, 1.15) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, -3, 0),
		cfg.CapeColor,
		Enum.Material.Fabric
	)
	b:part(
		"CapeLining",
		Vector3.new(4.0, 5.8, 0.1),
		CFrame.new(0, 7, 1.0) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, -2.9, 0),
		darker(cfg.BodyColor, 0.2),
		Enum.Material.Fabric,
		nil,
		true
	)
	-- A gold edge along the bottom of the cape.
	b:part(
		"CapeTrim",
		Vector3.new(4.5, 0.3, 0.25),
		CFrame.new(0, 7, 1.15) * CFrame.Angles(math.rad(-16), 0, 0) * CFrame.new(0, -5.95, 0),
		cfg.CrownColor,
		Enum.Material.Metal,
		nil,
		true
	)
end

local function arms(b: Builder)
	local cfg = Config.King
	for side = -1, 1, 2 do
		local shoulder = CFrame.new(side * 1.95, 6.6, 0)
		b:part(
			"Shoulder",
			Vector3.one * 1.5,
			shoulder,
			cfg.CrownColor,
			Enum.Material.Metal,
			Enum.PartType.Ball,
			true
		)
		-- Arms reach forward and a little out, like he's about to grab you.
		local arm = shoulder * CFrame.Angles(math.rad(68), 0, math.rad(side * 8))
		local upper = b:part(
			"Arm",
			Vector3.new(0.95, 2.8, 0.95),
			arm * CFrame.new(0, -1.4, 0),
			cfg.BodyColor,
			Enum.Material.Fabric
		)
		-- The arm hangs on a shoulder joint (LeftShoulder / RightShoulder) instead of a weld, so
		-- players' screens can swing it as he walks and stretch it out when he chases you.
		local pelvis = b.anchor
		local weld = upper:FindFirstChildOfClass("WeldConstraint")
		if weld then
			weld:Destroy()
		end
		local motor = Instance.new("Motor6D")
		motor.Name = if side < 0 then "LeftShoulder" else "RightShoulder"
		motor.Part0 = pelvis
		motor.Part1 = upper
		motor.C0 = pelvis.CFrame:ToObjectSpace(upper.CFrame * CFrame.new(0, 1.4, 0))
		motor.C1 = CFrame.new(0, 1.4, 0)
		motor.Parent = pelvis
		-- The cuff, hand and claws go along with the arm.
		b.anchor = upper
		b:part(
			"Cuff",
			Vector3.new(0.35, 1.25, 1.25),
			arm * CFrame.new(0, -2.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
			cfg.CrownColor,
			Enum.Material.Metal,
			Enum.PartType.Cylinder,
			true
		)
		local hand = arm * CFrame.new(0, -3.2, 0)
		b:part(
			"Hand",
			Vector3.one * 0.95,
			hand,
			cfg.VineColor,
			Enum.Material.Grass,
			Enum.PartType.Ball,
			true
		)
		-- Three curled claws.
		for finger = -1, 1 do
			b:part(
				"Claw",
				Vector3.new(0.18, 0.9, 0.18),
				hand
					* CFrame.Angles(0, 0, math.rad(finger * 18))
					* CFrame.new(0, -0.7, 0)
					* CFrame.Angles(math.rad(-25), 0, 0),
				darker(cfg.VineColor, 0.45),
				Enum.Material.SmoothPlastic,
				nil,
				true
			)
		end
		b.anchor = pelvis
	end
end

-- The pumpkin: a centre ball with six ribs around it, so it's wide and round.
type Ball = { center: Vector3, radius: number }

local function head(b: Builder)
	local cfg = Config.King
	local s = cfg.HeadSize / 4.5
	local center = Vector3.new(0, 7.3 + 1.8 * s, 0)
	local ribRadius, ribOffset = 1.7 * s, 1.0 * s
	local balls: { Ball } = { { center = center, radius = 1.85 * s } }

	local main = b:part(
		"Head",
		Vector3.one * 3.7 * s,
		CFrame.new(center),
		cfg.HeadColor,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local at = center
			+ Vector3.new(math.sin(angle) * ribOffset, 0, -math.cos(angle) * ribOffset)
		table.insert(balls, { center = at, radius = ribRadius })
		b:part(
			"Rib",
			Vector3.one * ribRadius * 2,
			CFrame.new(at),
			if i % 2 == 0 then cfg.HeadColor else darker(cfg.HeadColor, 0.12),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end

	-- How far forward (-Z) the pumpkin's surface is at (x, y), so the face sits on it.
	local function front(x: number, y: number): number
		local best = math.huge
		for _, ball in balls do
			local dx, dy = x - ball.center.X, y - ball.center.Y
			local inside = ball.radius * ball.radius - dx * dx - dy * dy
			if inside > 0 then
				best = math.min(best, ball.center.Z - math.sqrt(inside))
			end
		end
		return if best == math.huge then center.Z else best
	end

	local depth = 0.4
	local function onFace(x: number, y: number): CFrame
		local fy = center.Y + y
		return CFrame.new(x, fy, front(x, fy) + depth * 0.3)
	end

	-- Angry eyes: right triangles, high at the outside, sloping down to the nose.
	for side = -1, 1, 2 do
		local x = side * 0.85 * s
		b:wedge(
			"Eye",
			Vector3.new(depth, 0.95 * s, 1.15 * s),
			onFace(x, 0.45 * s) * CFrame.Angles(0, math.rad(side * 90), 0),
			cfg.FaceColor,
			Enum.Material.Neon
		)
	end
	b:part(
		"Nose",
		Vector3.new(0.45 * s, 0.45 * s, depth),
		onFace(0, -0.15 * s) * CFrame.Angles(0, 0, math.rad(45)),
		cfg.FaceColor,
		Enum.Material.Neon,
		nil,
		true
	)
	-- A wide grin that curls up at the ends, with pumpkin teeth biting into the glow.
	local segments = 9
	local function mouthAt(t: number): (number, number)
		return t * 1.45 * s, (-0.85 + 0.45 * t * t) * s
	end
	for i = 1, segments do
		local t = (i - 1) / (segments - 1) * 2 - 1 -- -1 .. 1
		local x, y = mouthAt(t)
		b:part(
			"Grin",
			Vector3.new(0.5 * s, (0.55 - 0.15 * math.abs(t)) * s, depth),
			onFace(x, y) * CFrame.Angles(0, math.rad(-t * 25), math.rad(t * 22)),
			cfg.FaceColor,
			Enum.Material.Neon,
			nil,
			true
		)
	end
	for _, tooth in { { -0.45, 1 }, { 0.45, 1 }, { 0, -1 } } do
		local x, y = mouthAt(tooth[1])
		b:part(
			"Tooth",
			Vector3.new(0.3 * s, 0.3 * s, depth),
			onFace(x, y + tooth[2] * 0.26 * s)
				* CFrame.new(0, 0, -0.06)
				* CFrame.Angles(0, 0, math.rad(45)),
			cfg.HeadColor,
			Enum.Material.SmoothPlastic,
			nil,
			true
		)
	end

	local glow = Instance.new("PointLight")
	glow.Color = cfg.FaceColor
	glow.Brightness = cfg.FaceGlow.Brightness
	glow.Range = cfg.FaceGlow.Range
	glow.Shadows = false
	glow.Parent = main

	if cfg.Embers > 0 then
		local embers = Instance.new("ParticleEmitter")
		embers.Name = "Embers"
		embers.Rate = cfg.Embers
		embers.Lifetime = NumberRange.new(1.2, 2)
		embers.Speed = NumberRange.new(2, 4)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.Acceleration = Vector3.new(0, 2, 0)
		embers.LightEmission = 1
		embers.Color = ColorSequence.new(cfg.FaceColor, cfg.HeadColor)
		embers.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		embers.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Parent = main
	end

	-- Stem and crown on top.
	local top = center.Y + ribRadius
	b:part(
		"Stem",
		Vector3.new(1.3 * s, 0.6 * s, 0.6 * s),
		upright(0, top + 0.35 * s, 0) * CFrame.Angles(0, 0, math.rad(-12)),
		darker(cfg.VineColor, 0.2),
		Enum.Material.Wood,
		Enum.PartType.Cylinder,
		true
	)
	local crownY = top - 0.05 * s
	local crownRadius = 1.45 * s
	b:part(
		"Crown",
		Vector3.new(0.7 * s, crownRadius * 2 + 0.2, crownRadius * 2 + 0.2),
		upright(0, crownY, 0),
		cfg.CrownColor,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		-- A thin diamond half-sunk into the band: the top half shows as a crown point.
		local size = (if i == 0 then 0.95 else 0.75) * s
		local base = Vector3.new(0, crownY + 0.35 * s, 0) + dir * crownRadius
		b:part(
			"CrownSpike",
			Vector3.new(size, size, 0.2 * s),
			CFrame.lookAt(base, base + dir) * CFrame.Angles(0, 0, math.rad(45)),
			cfg.CrownColor,
			Enum.Material.Metal,
			nil,
			true
		)
		local gem = Vector3.new(0, crownY, 0) + dir * (crownRadius + 0.12)
		b:part(
			"Gem",
			Vector3.one * 0.38 * s,
			CFrame.new(gem),
			cfg.GemColor,
			Enum.Material.Neon,
			Enum.PartType.Ball,
			true
		)
	end
end

--[[
	Builds the body standing on the floor below `position` (the root's centre). Returns the
	model (named PumpkinKing, not parented), its Humanoid and its HumanoidRootPart.
]]
function KingBody.Build(position: Vector3): (Model, Humanoid, BasePart)
	local cfg = Config.King
	local model = Instance.new("Model")
	model.Name = "PumpkinKing"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root

	-- The hidden Pelvis carries everything above the legs; its joint (Waist) lets players'
	-- screens bob and sway him as he walks. LegLength tells them how long his strides are.
	local pelvis = Instance.new("Part")
	pelvis.Name = "Pelvis"
	pelvis.Size = Vector3.new(1, 1, 1)
	pelvis.Transparency = 1
	pelvis.CanCollide = false
	pelvis.CanTouch = false
	pelvis.CanQuery = false
	pelvis.Massless = true
	local waist = Instance.new("Motor6D")
	waist.Name = "Waist"
	waist.Part0 = root
	waist.Part1 = pelvis
	waist.C0 = CFrame.new(0, HIP_Y - floorOffset(), 0)
	pelvis.CFrame = root.CFrame * waist.C0
	waist.Parent = root
	pelvis.Parent = model
	model:SetAttribute("LegLength", HIP_Y)

	local b = newBuilder(model, root, pelvis)
	legs(b, pelvis)
	coat(b)
	torso(b)
	arms(b)
	head(b)

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = cfg.HipHeight
	humanoid.DisplayName = cfg.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.RequiresNeck = false -- no real neck joint on the placeholder body
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	return model, humanoid, root
end

return KingBody
