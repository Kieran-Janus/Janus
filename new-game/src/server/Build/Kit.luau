--!strict
--[[
	Part-kitbashing helpers shared by the hub builder and the map builders.
	Everything here is placeholder art built from Parts; colours are always passed in so
	each place keeps its own palette from Config.

	Client animation hooks (src/client/HubAmbience.luau), used by the hub and the maps:
	  tag "HubFloat"   on Models that bob (attributes BobHeight, Phase)
	  tag "HubFlicker" on PointLights that flicker
]]

local CollectionService = game:GetService("CollectionService")

local Kit = {}

function Kit.part(props: { [string]: any }, parent: Instance): Part
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

function Kit.wedge(props: { [string]: any }, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(w :: any)[key] = value
	end
	w.Parent = parent
	return w
end

function Kit.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Upright cylinder (Roblox cylinders point along X, so rotate onto Y).
function Kit.upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- A decoration: no collision, never hit by raycasts (King sight, pumpkin spawns), no touch.
function Kit.decor(props: { [string]: any }, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- An invisible, non-colliding part used to hold lights, particles and prompts.
function Kit.holder(name: string, cf: CFrame, size: Vector3, parent: Instance): Part
	return Kit.decor({ Name = name, CFrame = cf, Size = size, Transparency = 1 }, parent)
end

function Kit.light(
	parent: BasePart,
	color: Color3,
	range: number,
	brightness: number,
	flicker: boolean
): PointLight
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

function Kit.particles(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

function Kit.float(m: Model, bob: number, rng: Random)
	m:SetAttribute("BobHeight", bob)
	m:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	CollectionService:AddTag(m, "HubFloat")
end

-- Glowing carved face on the front of a ball of diameter `size` (front = cf.LookVector).
function Kit.carvedFace(cf: CFrame, size: number, glow: Color3, parent: Instance)
	local r = size / 2
	local function onSurface(x: number, y: number): CFrame
		local z = math.sqrt(math.max(r * r - x * x - y * y, 0))
		return cf * CFrame.new(x, y, -z + 0.05)
	end
	for _, side in { -1, 1 } do
		-- Triangle eyes: a wedge turned so its triangle faces forward.
		Kit.wedge({
			Name = "Eye",
			Size = Vector3.new(0.1, size * 0.18, size * 0.16),
			CFrame = onSurface(side * r * 0.35, r * 0.25)
				* CFrame.Angles(0, math.rad(90 * side), 0),
			Color = glow,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, parent)
	end
	Kit.part({
		Name = "Mouth",
		Size = Vector3.new(size * 0.45, size * 0.1, 0.1),
		CFrame = onSurface(0, -r * 0.3),
		Color = glow,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
end

export type Palette = { Orange: Color3, Green: Color3, Glow: Color3 }

-- A carved, glowing pumpkin sitting on `cf` (front = cf.LookVector).
function Kit.jackOLantern(cf: CFrame, size: number, colors: Palette, parent: Instance): Model
	local m = Kit.model("JackOLantern", parent)
	local body = Kit.part({
		Name = "Pumpkin",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size * 1.15, size, size * 1.15),
		CFrame = cf * CFrame.new(0, size / 2, 0),
		Color = colors.Orange,
	}, m)
	Kit.part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size * 0.3, size * 0.18, size * 0.18),
		CFrame = Kit.upright(cf * CFrame.new(0, size + size * 0.1, 0)),
		Color = colors.Green,
	}, m)
	Kit.carvedFace(cf * CFrame.new(0, size / 2, 0), size, colors.Glow, m)
	Kit.light(body, colors.Glow, size * 4, 1.2, true)
	m.PrimaryPart = body
	return m
end

-- A flat spider web facing cf.LookVector.
function Kit.cobweb(cf: CFrame, size: number, color: Color3, parent: Instance)
	local m = Kit.model("Cobweb", parent)
	local spokes = 6
	local points: { { Vector3 } } = {}
	for i = 1, spokes do
		local a = (i / spokes) * math.pi * 2
		local dir = (cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a))
		Kit.decor({
			Name = "Strand",
			Size = Vector3.new(0.06, 0.06, size),
			CFrame = CFrame.lookAt(cf.Position + dir * size / 2, cf.Position + dir * size),
			Color = color,
			Transparency = 0.35,
		}, m)
		points[i] = { cf.Position + dir * size * 0.45, cf.Position + dir * size * 0.85 }
	end
	for ring = 1, 2 do
		for i = 1, spokes do
			local a = points[i][ring]
			local b = points[i % spokes + 1][ring]
			Kit.decor({
				Name = "Strand",
				Size = Vector3.new(0.05, 0.05, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = color,
				Transparency = 0.35,
			}, m)
		end
	end
end

-- A bare spooky tree standing on `base`.
function Kit.deadTree(base: CFrame, height: number, color: Color3, rng: Random, parent: Instance)
	local m = Kit.model("DeadTree", parent)
	Kit.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.2, 2.2),
		CFrame = Kit.upright(base * CFrame.new(0, height / 2, 0)),
		Color = color,
		Material = Enum.Material.Wood,
	}, m)
	for b = 1, 5 do
		local y = height * rng:NextNumber(0.45, 0.95)
		local yaw = (b / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local length = rng:NextNumber(4, 8)
		Kit.decor({
			Name = "Branch",
			Size = Vector3.new(0.6, 0.6, length),
			CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(
				math.rad(rng:NextNumber(30, 55)),
				0,
				0
			) * CFrame.new(0, 0, -length / 2),
			Color = color,
			Material = Enum.Material.Wood,
		}, m)
	end
	return m
end

--[[
	A walk-in hiding spot: players pass through it, but it blocks the King's line of sight
	(CanQuery stays on) so someone standing inside can't be seen. Tagged "HidingSpot".
]]
function Kit.hidingSpot(props: { [string]: any }, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	CollectionService:AddTag(p, "HidingSpot")
	return p
end

--[[
	Map-wide ambient particles. `kinds` maps a kind name to { Rate, Color }:
	  Fireflies, Wisps - glowing dots drifting in the air
	  Mist             - big soft puffs low over the floor
	  Leaves, Dust     - small flakes drifting down
	The area is centred on `center` (floor top) with footprint `size`.
]]
function Kit.ambientParticles(
	center: Vector3,
	size: Vector3,
	kinds: { [string]: any },
	parent: Instance
)
	local folder = Kit.model("Ambience", parent)
	for kind, cfg in kinds do
		if kind == "Fireflies" or kind == "Wisps" then
			local air = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 6, 0)),
				Vector3.new(size.X, 8, size.Z),
				folder
			)
			Kit.particles(air, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
				LightEmission = 1,
				Size = NumberSequence.new(if kind == "Wisps" then 0.6 else 0.25),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, if kind == "Wisps" then 0.4 else 0),
					NumberSequenceKeypoint.new(0.7, if kind == "Wisps" then 0.4 else 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(4, 7),
				Speed = NumberRange.new(0.3, 1.2),
				SpreadAngle = Vector2.new(180, 180),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
		elseif kind == "Mist" then
			local ground = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 1.5, 0)),
				Vector3.new(size.X, 1, size.Z),
				folder
			)
			Kit.particles(ground, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
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
			})
		elseif kind == "Leaves" or kind == "Dust" then
			local sky = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 18, 0)),
				Vector3.new(size.X, 1, size.Z),
				folder
			)
			Kit.particles(sky, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
				Size = NumberSequence.new(if kind == "Dust" then 0.15 else 0.35),
				LightEmission = if kind == "Dust" then 0.6 else 0,
				Lifetime = NumberRange.new(8, 12),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0.5, if kind == "Dust" then -0.3 else -1.2, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
				EmissionDirection = Enum.NormalId.Bottom,
				Shape = Enum.ParticleEmitterShape.Box,
			})
		end
	end
	return folder
end

return Kit
