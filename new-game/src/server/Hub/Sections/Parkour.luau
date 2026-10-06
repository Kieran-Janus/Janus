--!strict
--[[
	Lobby section: "Spooky Sky Climb", the parkour course behind the clock tower.
	Where: Config.Lobby.Zones.Parkour (it has a Height); the pieces: Config.Parkour.Course.

	Workspace.Hub.Parkour
	  Course
	    Step01_Start       the start pad (part "Pad", tag ParkourStart) with the arch and the
	                       board of fastest climbers (part "Screen", tag ParkourBoard)
	    Step02_Pumpkin...  one Model per line of Config.Parkour.Course, named Step<number>_<Kind>.
	                       The part you stand on is the first child ("Top", "Stone", "Handle",
	                       "Disc", "Wings", "Slab"); everything else is decoration.
	    StepNN_Checkpoint  part "Pad", tag ParkourCheckpoint, attribute Index (1, 2, 3...)
	    StepNN_Hazard      part "Slime", tag ParkourHazard
	    StepNN_Finish      part "Pad", tag ParkourFinish, the trophy pumpkin (prop "ParkourTrophy")
	  Decor                bats and lanterns, only for looks
	ParkourService finds the working parts by tag, so pieces can be moved, resized, copied or
	replaced in Studio. Props you can swap for your own model (ReplicatedStorage.Custom.Props):
	ParkourPumpkin (the pumpkins you jump on: only their look, the Top lid you stand on stays),
	ParkourArch, ParkourTrophy, Bat, JackOLantern.

	Parkour.Build(hub, zone) -> Model    the whole course (an empty model when the feature is off)
	Parkour.Repair(hub, zone) -> Model   builds what is missing in a saved hub: the whole course
	                                     when it has no parkour parts, else only a missing start pad
	Parkour.BoardGui(screen) -> SurfaceGui   the board's sign (made if the part has none; a
	                                         saved one gets its title and reward line from
	                                         Config again)
	Parkour.WorldCFrame(zone, i) -> CFrame   where the top of Course[i] is in the world
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone
type Step = ParkourLogic.Step

local Parkour = {}

local cfg = Config.Parkour
local look = cfg.Look
local colors = look.Colors

-- Helpers ------------------------------------------------------------------------------------

local function solid(props: Kit.Props, parent: Instance): Part
	return Kit.part(props, parent)
end

local function decor(props: Kit.Props, parent: Instance): Part
	return Kit.decor(props, parent)
end

-- A decoration shaped like an egg / squashed ball that fills `size` (a Ball part is always a
-- perfect sphere, so this is a block with a sphere mesh).
local function oval(
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local p = decor({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A round slab whose middle is at `cf` (lying flat in cf's frame).
local function disc(
	name: string,
	cf: CFrame,
	diameter: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	collide: boolean,
	material: Enum.Material?
): Part
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = Kit.upright(cf),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}
	return if collide then solid(props, parent) else decor(props, parent)
end

local function glow(target: BasePart, color: Color3, range: number, brightness: number)
	if look.Lights then
		Kit.light(target, color, range, brightness, false)
	end
end

local function sparkles(target: BasePart, color: Color3, rate: number)
	Kit.particles(target, {
		Rate = rate,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box,
	})
end

-- Words on one face of a part.
local function lettering(
	target: BasePart,
	text: string,
	color: Color3,
	face: Enum.NormalId,
	font: Enum.Font?
): SurfaceGui
	local gui = Kit.surfaceText(target, text, color, face)
	local label = gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Font = font or Enum.Font.Creepster
		label.TextStrokeTransparency = 0.4
	end
	return gui
end

--[[
	A glowing carved face on the front (+Z) of an egg shape centred at `center` with radii
	a (across), b (up) and c (front), so it always sits on the surface.
]]
local function carveFace(center: CFrame, a: number, b: number, c: number, parent: Instance)
	local function onSurface(x: number, y: number): CFrame
		local k = 1 - (x / a) ^ 2 - (y / b) ^ 2
		local z = c * math.sqrt(math.max(k, 0)) - 0.05
		local p = center * Vector3.new(x, y, z)
		local n = center:VectorToWorldSpace(Vector3.new(x / (a * a), y / (b * b), z / (c * c))).Unit
		return CFrame.lookAt(p, p + n)
	end
	local size = math.min(a, b) * 2
	for _, side in { -1, 1 } do
		Kit.wedge({
			Name = "Eye",
			Size = Vector3.new(0.12, size * 0.2, size * 0.18),
			CFrame = onSurface(side * a * 0.36, b * 0.22)
				* CFrame.Angles(0, math.rad(90 * side), 0),
			Color = colors.Face,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, parent)
	end
	decor({
		Name = "Mouth",
		Size = Vector3.new(a * 0.75, size * 0.11, 0.12),
		CFrame = onSurface(0, -b * 0.28),
		Color = colors.Face,
		Material = Enum.Material.Neon,
	}, parent)
	for _, side in { -1, 1 } do
		decor({
			Name = "Tooth",
			Size = Vector3.new(size * 0.07, size * 0.06, 0.14),
			CFrame = onSurface(side * a * 0.14, -b * 0.24) * CFrame.new(0, 0, -0.03),
			Color = colors.Pumpkin,
		}, parent)
	end
end

local function jackOLantern(cf: CFrame, size: number, parent: Instance): Model
	return Kit.jackOLantern(cf, size, Config.Hub.Palette :: any, parent) -- the lobby's own colours
end

-- Where things are -----------------------------------------------------------------------------

local function courseFrame(zone: Zone): CFrame
	return ParkourLogic.CourseFrame(zone.CFrame)
end

function Parkour.WorldCFrame(zone: Zone, i: number): CFrame
	return courseFrame(zone) * ParkourLogic.StepCFrame(cfg.Course :: { Step }, i)
end

-- Each piece --------------------------------------------------------------------------------
-- Every builder gets the top middle of the piece (`top`, its front is -Z and the plaza side
-- +Z when it isn't turned), its size and the line from Config, and returns the part you
-- stand on. The first child of the step's model is always that part.

type Builder = (top: CFrame, size: Vector3, step: Step, m: Model, index: number) -> BasePart

local builders: { [string]: Builder } = {}

-- A pumpkin to jump on. You stand on "Top", a flat lid that always does the work; the round
-- body is its look, prop "ParkourPumpkin" (Kit.look): with your own model in
-- ReplicatedStorage.Custom.Props, Top turns invisible and your pumpkin stands under it, its top
-- where you stand, `size.Y` studs tall.
builders.Pumpkin = function(top, size, _step, m, index)
	local width = math.min(size.X, size.Z)
	local lid = disc(
		"Top",
		top * CFrame.new(0, -0.3, 0),
		width * look.PumpkinTop,
		0.6,
		colors.Pumpkin:Lerp(Color3.new(0, 0, 0), 0.08),
		m,
		true
	)
	local lit = index % 2 == 0 -- every other pumpkin is a glowing jack-o-lantern
	local light: Kit.PropLight? = if lit and look.Lights
		then { Color = colors.Face, Range = 12, Brightness = 1.2, Flicker = false, Height = 0.5 }
		else nil
	Kit.look("ParkourPumpkin", lid, top * CFrame.new(0, -size.Y, 0), size.Y, function()
		local body = Kit.model("ParkourPumpkin", lid)
		-- The round body is lobes around the middle (ribs), a little above the lid's edge.
		local center = top * CFrame.new(0, -size.Y / 2 + 0.25, 0)
		local core = oval(
			"Body",
			center,
			Vector3.new(size.X * 0.92, size.Y, size.Z * 0.92),
			colors.Pumpkin,
			body
		)
		for i = 0, 3 do
			oval(
				"Rib",
				center * CFrame.Angles(0, math.rad(i * 45), 0),
				Vector3.new(size.X, size.Y * 0.97, size.Z * 0.55),
				colors.Pumpkin:Lerp(Color3.new(0, 0, 0), if i % 2 == 0 then 0.12 else 0.04),
				body
			)
		end
		-- A curly stem at the back edge of the lid (no collision: you can stand through it).
		decor({
			Name = "Stem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 0.7, 0.7),
			CFrame = Kit.upright(top * CFrame.new(0, 0.5, -width * look.PumpkinTop / 2 + 0.6))
				* CFrame.Angles(0, 0, math.rad(-20)),
			Color = colors.PumpkinStem,
		}, body)
		-- A jack-o-lantern faces the plaza.
		if lit then
			carveFace(center, size.X / 2 * 0.98, size.Y / 2, size.Z / 2 * 0.98, body)
			local inside = Kit.holder("Glow", center, Vector3.one, body)
			glow(inside, colors.Face, 12, 1.2)
		end
		body.PrimaryPart = core
		return body
	end, { Light = light })
	return lid
end

-- A rounded headstone (you stand on its rounded top) on a clump of earth.
builders.Grave = function(top, size, step, m, index)
	local radius = size.X / 2
	local bodyHeight = math.max(size.Y - radius, 1)
	local stoneColor = colors.Stone
	local cap = solid({
		Name = "Stone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size.Z, size.X, size.X),
		CFrame = top * CFrame.new(0, -radius, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = stoneColor,
		Material = Enum.Material.Slate,
	}, m)
	solid({
		Name = "Body",
		Size = Vector3.new(size.X, bodyHeight, size.Z),
		CFrame = top * CFrame.new(0, -radius - bodyHeight / 2, 0),
		Color = stoneColor,
		Material = Enum.Material.Slate,
	}, m)
	-- A darker plaque with the words, on the side facing the plaza.
	local plaque = decor({
		Name = "Plaque",
		Size = Vector3.new(size.X * 0.66, math.min(radius * 1.1, size.Y * 0.45), 0.1),
		CFrame = top * CFrame.new(0, -radius - 0.2, size.Z / 2 + 0.04),
		Color = stoneColor:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Slate,
	}, m)
	lettering(plaque, step.Text or "RIP", colors.Text, Enum.NormalId.Back)
	-- A wider foot, with moss creeping up the front corners.
	local bottom = top * CFrame.new(0, -size.Y, 0)
	decor({
		Name = "Foot",
		Size = Vector3.new(size.X + 1, 0.9, size.Z + 0.8),
		CFrame = bottom * CFrame.new(0, 0.45, 0),
		Color = stoneColor:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.Slate,
	}, m)
	for _, side in { -1, 1 } do
		decor({
			Name = "Moss",
			Size = Vector3.new(1.4, 1.6, 0.15),
			CFrame = bottom * CFrame.new(side * (size.X / 2 - 0.7), 1.6, size.Z / 2 + 0.06),
			Color = colors.Moss,
			Material = Enum.Material.Grass,
		}, m)
	end
	-- The clump of earth it was pulled up with, and dangling roots.
	oval(
		"Dirt",
		bottom * CFrame.new(0, -0.6, 0),
		Vector3.new(size.X * 1.4, 3.2, size.Z * 1.8),
		colors.Dirt,
		m,
		Enum.Material.Ground
	)
	oval(
		"Grass",
		bottom * CFrame.new(0, 0.2, 0),
		Vector3.new(size.X * 1.3, 1, size.Z * 1.65),
		colors.Moss,
		m,
		Enum.Material.Grass
	)
	for r = 0, 2 do
		local angle = math.rad(r * 120 + index * 17)
		decor({
			Name = "Root",
			Size = Vector3.new(0.3, 2.4, 0.3),
			CFrame = bottom
				* CFrame.new(math.cos(angle) * size.X * 0.3, -2.4, math.sin(angle) * size.Z * 0.35)
				* CFrame.Angles(math.rad(12), angle, 0),
			Color = colors.Dirt,
		}, m)
	end
	if index % 2 == 0 then
		-- A ghostly green candle on the foot.
		local flame = decor({
			Name = "Candle",
			Size = Vector3.new(0.5, 1.1, 0.5),
			CFrame = bottom * CFrame.new(size.X / 2 + 0.1, 1.45, size.Z / 2),
			Color = colors.Slime,
			Material = Enum.Material.Neon,
		}, m)
		glow(flame, colors.Slime, 10, 1)
	end
	return cap
end

builders.Broom = function(top, size, _step, m, index)
	local bristleLength = math.min(3, size.Z * 0.3)
	local handleLength = size.Z - bristleLength
	-- The handle: a box to stand on, drawn round by a cylinder mesh.
	local handle = solid({
		Name = "Handle",
		Size = Vector3.new(handleLength, size.Y, size.X),
		CFrame = top
			* CFrame.new(0, -size.Y / 2, -bristleLength / 2)
			* CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, m)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = handle
	-- The bristles at the back end: also solid (a wide landing spot), drawn as a round bundle.
	local bundle = Vector3.new(size.X * 1.6, size.Y * 1.3, bristleLength + 0.8)
	local tail = top * CFrame.new(0, -bundle.Y / 2, size.Z / 2 - bristleLength / 2)
	local bristles = solid({
		Name = "Bristles",
		Size = bundle,
		CFrame = tail,
		Color = colors.Straw,
		Material = Enum.Material.Grass,
	}, m)
	local bundleMesh = Instance.new("SpecialMesh")
	bundleMesh.MeshType = Enum.MeshType.Sphere
	bundleMesh.Parent = bristles
	-- Loose straws fanning out of the end.
	for i = 0, 5 do
		local angle = (i / 6) * math.pi * 2 + index
		local spread = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local from = tail
			* CFrame.new(spread.X * size.X * 0.45, spread.Y * size.Y * 0.4, bundle.Z * 0.35)
		local to = from * CFrame.new(spread.X * 0.8, spread.Y * 0.8, 2.2)
		decor({
			Name = "Straw",
			Size = Vector3.new(0.25, 0.25, (to.Position - from.Position).Magnitude),
			CFrame = CFrame.lookAt(from.Position:Lerp(to.Position, 0.5), to.Position),
			Color = colors.Straw:Lerp(Color3.new(0, 0, 0), 0.12),
		}, m)
	end
	disc(
		"Band",
		top
			* CFrame.new(0, -size.Y / 2, size.Z / 2 - bristleLength - 0.2)
			* CFrame.Angles(math.rad(90), 0, 0),
		size.Y * 1.2,
		0.6,
		colors.Bat,
		m,
		false
	)
	oval(
		"Knob",
		top * CFrame.new(0, -size.Y / 2, -size.Z / 2 + 0.2),
		Vector3.new(size.X * 1.1, size.Y * 1.1, size.X * 1.1),
		colors.Wood:Lerp(Color3.new(0, 0, 0), 0.2),
		m
	)
	local magic = Kit.holder("Magic", tail, Vector3.new(size.X, 1, bristleLength), m)
	sparkles(magic, colors.Finish, 6)
	return handle
end

builders.Candy = function(top, size, _step, m, _index)
	local diameter = math.min(size.X, size.Z)
	local candy =
		disc("Disc", top * CFrame.new(0, -size.Y / 2, 0), diameter, size.Y, colors.Candy, m, true)
	-- Peppermint swirl on top and a red stripe round the edge.
	for i = 0, 5 do
		decor({
			Name = "Swirl",
			Size = Vector3.new(diameter * 0.16, 0.06, diameter * 0.44),
			CFrame = top
				* CFrame.Angles(0, math.rad(i * 60), 0)
				* CFrame.new(0, 0.02, -diameter * 0.24)
				* CFrame.Angles(0, math.rad(18), 0),
			Color = colors.CandyStripe,
		}, m)
	end
	disc(
		"Stripe",
		top * CFrame.new(0, -size.Y / 2, 0),
		diameter + 0.1,
		size.Y * 0.35,
		colors.CandyStripe,
		m,
		false
	)
	-- The see-through wrapper twisted at both sides.
	for _, side in { -1, 1 } do
		local edge = top * CFrame.new(side * (diameter / 2 + 0.6), -size.Y / 2, 0)
		for _, flip in { -1, 1 } do
			Kit.wedge({
				Name = "Wrapper",
				Size = Vector3.new(0.3, diameter * 0.32, 1.6),
				CFrame = edge
					* CFrame.Angles(0, math.rad(-90 * side), 0)
					* CFrame.new(0, flip * diameter * 0.08, 0)
					* CFrame.Angles(math.rad(90 + flip * 90), 0, 0),
				Color = colors.Wrapper,
				Material = Enum.Material.Glass,
				Transparency = 0.25,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}, m)
		end
	end
	local under = Kit.holder("Glow", top * CFrame.new(0, -size.Y - 1, 0), Vector3.one, m)
	glow(under, colors.Wrapper, 10, 0.8)
	return candy
end

-- A big friendly bat carrying you on its wings: its head pokes up at the front edge.
builders.Bat = function(top, size, _step, m, _index)
	local wings = solid({
		Name = "Wings",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Bat,
		Material = Enum.Material.SmoothPlastic,
	}, m)
	local under = top * CFrame.new(0, -size.Y, 0)
	local bone = colors.Bat:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, side in { -1, 1 } do
		-- Pointy wing tips.
		Kit.wedge({
			Name = "WingTip",
			Size = Vector3.new(size.Y, size.Z * 0.9, 2.4),
			CFrame = top
				* CFrame.new(side * (size.X / 2 + 1.2), -size.Y / 2, 0)
				* CFrame.Angles(0, math.rad(90 * side), 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = colors.Bat,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, m)
		-- Wing bones fanning out from the shoulders (flat on top, only for looks).
		local shoulder = Vector3.new(side * 1.3, 0.04, size.Z / 2 - 1)
		for b = 0, 2 do
			local tip =
				Vector3.new(side * (size.X / 2 - 0.3) * (0.45 + b * 0.27), 0.04, -size.Z / 2 + 0.3)
			local a = (top * CFrame.new(shoulder)).Position
			local c = (top * CFrame.new(tip)).Position
			decor({
				Name = "WingBone",
				Size = Vector3.new(0.25, 0.1, (c - a).Magnitude),
				CFrame = CFrame.lookAt(a:Lerp(c, 0.5), c, top.UpVector),
				Color = bone,
			}, m)
		end
		-- Scalloped back edge.
		for s = 0, 1 do
			decor({
				Name = "Scallop",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(size.Y * 0.9, size.Z * 0.45, size.Z * 0.45),
				CFrame = under
					* CFrame.new(side * (size.X * (0.18 + s * 0.2)), 0.1, -size.Z * 0.35),
				Color = bone,
			}, m)
		end
	end
	-- The little body underneath and the head at the front (the plaza side when not turned).
	oval(
		"Body",
		under * CFrame.new(0, -0.6, 0),
		Vector3.new(2.6, 2.4, size.Z * 0.75),
		colors.Bat,
		m
	)
	local head = top * CFrame.new(0, 0.45, size.Z / 2 - 0.5)
	oval("Head", head, Vector3.new(2.4, 2.1, 2), colors.Bat, m)
	for _, side in { -1, 1 } do
		Kit.wedge({
			Name = "Ear",
			Size = Vector3.new(0.3, 1.2, 0.9),
			CFrame = head * CFrame.new(side * 0.7, 1.3, 0),
			Color = colors.Bat,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, m)
		decor({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.55,
			CFrame = head * CFrame.new(side * 0.45, 0.25, 0.85),
			Color = colors.BatEyes,
			Material = Enum.Material.Neon,
		}, m)
		Kit.wedge({
			Name = "Fang",
			Size = Vector3.new(0.18, 0.4, 0.2),
			CFrame = head * CFrame.new(side * 0.3, -0.6, 0.9) * CFrame.Angles(math.rad(180), 0, 0),
			Color = colors.Candy,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, m)
	end
	return wings
end

builders.Platform = function(top, size, _step, m, _index)
	local slab = solid({
		Name = "Slab",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.1),
		Material = Enum.Material.Slate,
	}, m)
	-- A crypt lid: a raised border and a clump of earth underneath.
	for _, side in { -1, 1 } do
		decor({
			Name = "Trim",
			Size = Vector3.new(0.4, size.Y + 0.2, size.Z + 0.2),
			CFrame = top * CFrame.new(side * (size.X / 2 - 0.1), -size.Y / 2, 0),
			Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = Enum.Material.Slate,
		}, m)
	end
	oval(
		"Dirt",
		top * CFrame.new(0, -size.Y - 0.6, 0),
		Vector3.new(size.X * 1.2, 2.6, size.Z * 1.05),
		colors.Dirt,
		m,
		Enum.Material.Ground
	)
	return slab
end

-- Green slime: no collision (you walk into it), touching it sends you back. Offset is the
-- middle of its bottom, so it sits on whatever is below it.
builders.Hazard = function(top, size, _step, m, _index)
	local slime = decor({
		Name = "Slime",
		Size = size,
		CFrame = top * CFrame.new(0, size.Y / 2 + 0.02, 0),
		Color = colors.Slime,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}, m)
	slime.CanTouch = true
	slime.CanQuery = true
	CollectionService:AddTag(slime, Tags.ParkourHazard)
	for i = 0, 2 do
		oval(
			"Blob",
			top * CFrame.new((i - 1) * size.X * 0.3, size.Y, (i % 2 - 0.5) * size.Z * 0.3),
			Vector3.new(1.2, 0.6, 1.2),
			colors.Slime,
			m,
			Enum.Material.Neon
		)
	end
	Kit.particles(slime, {
		Rate = 6,
		Color = ColorSequence.new(colors.Slime),
		LightEmission = 0.6,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.5),
		}),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top,
	})
	glow(slime, colors.Slime, 10, 1)
	return slime
end

-- A round stone pad with a glowing ring, like the Ready pad. Returns the pad.
local function ringPad(top: CFrame, size: Vector3, ring: Color3, stone: Color3, m: Model): BasePart
	local diameter = math.min(size.X, size.Z)
	local pad = disc(
		"Pad",
		top * CFrame.new(0, -size.Y / 2, 0),
		diameter,
		size.Y,
		stone,
		m,
		true,
		Enum.Material.Slate
	)
	local glowRing = disc(
		"GlowRing",
		top * CFrame.new(0, 0.03, 0),
		diameter - 0.8,
		0.08,
		ring,
		m,
		false,
		Enum.Material.Neon
	)
	disc(
		"PadCentre",
		top * CFrame.new(0, 0.05, 0),
		diameter - 2.2,
		0.1,
		stone:Lerp(Color3.new(0, 0, 0), 0.15),
		m,
		false,
		Enum.Material.Slate
	)
	glow(glowRing, ring, 16, 1.3)
	return pad
end

-- A signpost on the edge of a pad, facing `facing` (a flat direction), with two lines.
local function signpost(base: CFrame, facing: Vector3, title: string, text: string?, m: Model)
	local cf = CFrame.lookAt(base.Position, base.Position + facing)
	decor({ -- (no collision, so it never blocks a jump onto the pad)
		Name = "SignPost",
		Size = Vector3.new(0.5, 6, 0.5),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, m)
	local board = decor({
		Name = "Sign",
		Size = Vector3.new(5, if text then 2.4 else 1.4, 0.3),
		CFrame = cf * CFrame.new(0, 5.2, -0.4),
		Color = colors.Wood,
		Material = Enum.Material.WoodPlanks,
	}, m)
	local words = if text then title .. "\n" .. text else title
	lettering(board, words, colors.Text, Enum.NormalId.Front, Enum.Font.GothamBlack)
	local lantern = decor({
		Name = "Lantern",
		Size = Vector3.new(0.9, 1.2, 0.9),
		CFrame = cf * CFrame.new(0, 6.6, 0),
		Color = colors.Face,
		Material = Enum.Material.Neon,
	}, m)
	glow(lantern, colors.Face, 14, 1)
end

-- The flat direction (world) from step i to the piece you jump on next (dir = 1) or before
-- it (dir = -1); nil when there is none. Used to turn signs towards arriving players.
local function neighbourDirection(zone: Zone, i: number, dir: number): Vector3?
	local course = cfg.Course :: { Step }
	local j = i + dir
	while course[j] and not ParkourLogic.IsJumpStep(course[j]) do
		j += dir
	end
	if not course[j] then
		return nil
	end
	local d = Parkour.WorldCFrame(zone, j).Position - Parkour.WorldCFrame(zone, i).Position
	local flat = Vector3.new(d.X, 0, d.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else nil
end

local function checkpointCount(index: number): number
	local course = cfg.Course :: { Step }
	local n = 0
	for i = 1, index do
		if course[i].Kind == "Checkpoint" then
			n += 1
		end
	end
	return n
end

local function buildCheckpoint(
	zone: Zone,
	top: CFrame,
	size: Vector3,
	step: Step,
	m: Model,
	index: number
): BasePart
	local pad = ringPad(top, size, colors.Checkpoint, colors.Stone, m)
	local number = checkpointCount(index)
	CollectionService:AddTag(pad, Tags.ParkourCheckpoint)
	pad:SetAttribute("Index", number)
	-- The sign faces the way players arrive from.
	local from = neighbourDirection(zone, index, -1) or -top.LookVector
	local radius = math.min(size.X, size.Z) / 2
	local spot = top.Position + top.RightVector * (radius - 0.7)
	signpost(CFrame.new(spot), from, ("CHECKPOINT %d"):format(number), step.Label, m)
	return pad
end

-- The start pad, its arch and the board of fastest climbers.
local function buildStart(top: CFrame, size: Vector3, m: Model): BasePart
	local pad = solid({
		Name = "Pad",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	CollectionService:AddTag(pad, Tags.ParkourStart)
	-- A glowing orange border and START written on top.
	for i = 0, 3 do
		local edge = top * CFrame.Angles(0, math.rad(i * 90), 0)
		local along = if i % 2 == 0 then size.X else size.Z -- (works for long pads too)
		local across = if i % 2 == 0 then size.Z else size.X
		decor({
			Name = "GlowEdge",
			Size = Vector3.new(along - 0.6, 0.08, 0.5),
			CFrame = edge * CFrame.new(0, 0.03, -across / 2 + 0.6),
			Color = colors.Start,
			Material = Enum.Material.Neon,
		}, m)
	end
	local label = decor({
		Name = "StartLabel",
		Size = Vector3.new(size.X * 0.7, 0.05, size.Z * 0.35),
		CFrame = top * CFrame.new(0, 0.02, 0),
		Transparency = 1,
	}, m)
	lettering(label, "START", colors.Start, Enum.NormalId.Top, Enum.Font.GothamBlack)
	local light = Kit.holder("Glow", top * CFrame.new(0, 2, 0), Vector3.one, m)
	glow(light, colors.Start, 18, 1.2)

	-- The arch over the side of the pad facing the plaza (players walk in under it). The
	-- pad's front (-Z) points into the course, so its back (+Z) is the plaza side.
	local front = top * CFrame.new(0, 0, size.Z / 2 - 0.4) * CFrame.Angles(0, math.pi, 0)
	local archHeight = 11
	Kit.prop("ParkourArch", front, m, archHeight + 2, function()
		local arch = Kit.model("ParkourArch", m)
		for _, side in { -1, 1 } do
			solid({
				Name = "Pillar",
				Size = Vector3.new(1.4, archHeight, 1.4),
				CFrame = front * CFrame.new(side * (size.X / 2 - 0.4), archHeight / 2, 0),
				Color = colors.Stone,
				Material = Enum.Material.Slate,
			}, arch)
			jackOLantern(
				front * CFrame.new(side * (size.X / 2 - 0.4), archHeight + 0.6, 0),
				1.8,
				arch
			)
		end
		local beam = decor({
			Name = "NameBoard",
			Size = Vector3.new(size.X + 0.6, 2.4, 0.5),
			CFrame = front * CFrame.new(0, archHeight - 0.6, 0),
			Color = colors.Wood,
			Material = Enum.Material.WoodPlanks,
		}, arch)
		lettering(beam, cfg.Name, colors.Start, Enum.NormalId.Front)
		lettering(beam, cfg.Name, colors.Start, Enum.NormalId.Back)
		return arch
	end)

	-- The board, beside the pad, facing the plaza.
	local boardCf = top
		* CFrame.new(size.X / 2 + 3.6, 0, size.Z / 2 - 1.5)
		* CFrame.Angles(0, math.pi, 0)
	local board = Kit.model("ParkourBoard", m)
	for _, side in { -1, 1 } do
		solid({
			Name = "Post",
			Size = Vector3.new(0.6, 8, 0.6),
			CFrame = boardCf * CFrame.new(side * 3.2, 4 - size.Y, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, board)
	end
	local screen = solid({
		Name = "Screen",
		Size = Vector3.new(7, 5.4, 0.4),
		CFrame = boardCf * CFrame.new(0, 5.2 - size.Y, 0),
		Color = colors.Board,
		Material = Enum.Material.WoodPlanks,
	}, board)
	CollectionService:AddTag(screen, Tags.ParkourBoard)
	Parkour.BoardGui(screen)
	jackOLantern(boardCf * CFrame.new(0, 7.9 - size.Y, 0), 1.6, board)
	return pad
end

-- The finish: a floating island with the golden trophy pumpkin wearing a witch hat.
local function buildFinish(top: CFrame, size: Vector3, m: Model): BasePart
	local pad = ringPad(top, size, colors.Finish, colors.Stone:Lerp(colors.Finish, 0.25), m)
	CollectionService:AddTag(pad, Tags.ParkourFinish)
	local diameter = math.min(size.X, size.Z)
	-- The island under it: rocky rings getting smaller, with a glowing tip.
	local y = -size.Y
	for tier = 1, 5 do
		local d = diameter * (1 - tier * 0.17)
		local h = 2.2
		disc(
			"Island",
			top * CFrame.new(0, y - h / 2, 0) * CFrame.Angles(0, math.rad(tier * 23), 0),
			d,
			h,
			colors.Dirt:Lerp(colors.Bat, tier / 6),
			m,
			false,
			Enum.Material.Rock
		)
		y -= h
	end
	local tip = oval(
		"Tip",
		top * CFrame.new(0, y - 0.4, 0),
		Vector3.new(1.4, 1.4, 1.4),
		colors.Finish,
		m,
		Enum.Material.Neon
	)
	glow(tip, colors.Finish, 16, 1.5)

	-- The trophy at the back of the platform, facing the front (the plaza when not turned).
	local trophySpot = top
		* CFrame.new(0, 0, -diameter / 2 + 3.4)
		* CFrame.Angles(0, math.rad(180), 0)
	Kit.prop("ParkourTrophy", trophySpot, m, 12, function()
		local trophy = Kit.model("ParkourTrophy", m)
		solid({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 4.6, 4.6),
			CFrame = Kit.upright(trophySpot * CFrame.new(0, 0.7, 0)),
			Color = colors.Stone,
			Material = Enum.Material.Marble,
		}, trophy)
		local center = trophySpot * CFrame.new(0, 1.4 + 2.2, 0)
		local pumpkin = oval(
			"TrophyPumpkin",
			center,
			Vector3.new(5.6, 4.4, 5.6),
			colors.Trophy,
			trophy,
			Enum.Material.Foil
		)
		for i = 0, 3 do
			oval(
				"TrophyRib",
				center * CFrame.Angles(0, math.rad(i * 45), 0),
				Vector3.new(5.9, 4.3, 3.2),
				colors.Trophy:Lerp(Color3.new(0, 0, 0), if i % 2 == 0 then 0.12 else 0.04),
				trophy,
				Enum.Material.Foil
			)
		end
		carveFace(center * CFrame.Angles(0, math.rad(180), 0), 2.9, 2.2, 2.9, trophy)
		glow(pumpkin, colors.Trophy, 24, 2)
		sparkles(pumpkin, colors.Trophy, 10)
		-- The witch hat: a wide brim, a band with a buckle and a bent point.
		local hat = center * CFrame.new(0, 2.1, 0)
		disc("HatBrim", hat, 7, 0.3, colors.Hat, trophy, false)
		disc("HatBand", hat * CFrame.new(0, 0.55, 0), 3.9, 0.7, colors.HatBand, trophy, false)
		decor({
			Name = "HatBuckle",
			Size = Vector3.new(0.9, 0.7, 0.15),
			CFrame = hat * CFrame.new(0, 0.55, 1.98),
			Color = colors.Trophy,
			Material = Enum.Material.Neon,
		}, trophy)
		local tierY = 0.3
		for tier = 0, 4 do
			local d = 3.7 * (1 - tier * 0.19)
			disc(
				"HatCone",
				hat
					* CFrame.new(-tier * 0.18, tierY + 0.5, 0)
					* CFrame.Angles(0, 0, math.rad(tier * 3)),
				d,
				1,
				colors.Hat,
				trophy,
				false
			)
			tierY += 0.95
		end
		oval(
			"HatTip",
			hat * CFrame.new(-1.2, tierY + 0.4, 0),
			Vector3.new(0.9, 0.9, 0.9),
			colors.Hat,
			trophy
		)
		return trophy
	end)

	-- "FINISH" floating over it.
	local tag =
		Kit.holder("FinishSign", top * CFrame.new(0, 13, -diameter / 2 + 3.4), Vector3.one, m)
	Kit.nameTag("FINISH!", tag, 0, colors.Trophy, 400)
	return pad
end

-- Decorations around the course (bats flying about, a few lanterns).
local function buildDecor(zone: Zone, area: Model)
	local folder = Kit.model("Decor", area)
	local frame = courseFrame(zone)
	local rng = Random.new(Config.Hub.Seed + 7)
	local spots = {
		Vector3.new(-4, 30, 4),
		Vector3.new(8, 40, 2),
		Vector3.new(-26, 50, 0),
		Vector3.new(26, 36, 8),
		Vector3.new(0, 24, -6),
	}
	for i, spot in spots do
		local cf = frame
			* CFrame.new(spot.X, spot.Y, -spot.Z)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local bat = Kit.prop("Bat", cf, folder, 2, function()
			local m = Kit.model("Bat", folder)
			local body =
				oval("Body", cf * CFrame.new(0, 0.8, 0), Vector3.new(0.9, 1.2, 0.8), colors.Bat, m)
			for _, side in { -1, 1 } do
				Kit.wedge({
					Name = "Wing",
					Size = Vector3.new(0.1, 1, 1.8),
					CFrame = cf
						* CFrame.new(side * 1.2, 1, 0)
						* CFrame.Angles(0, math.rad(90 * side), math.rad(15 * side)),
					Color = colors.Bat,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
				}, m)
				decor({
					Name = "Eye",
					Size = Vector3.new(0.15, 0.15, 0.1),
					CFrame = cf * CFrame.new(side * 0.2, 1.05, -0.42),
					Color = colors.BatEyes,
					Material = Enum.Material.Neon,
				}, m)
			end
			m.PrimaryPart = body
			return m
		end, { Visual = true })
		Kit.float(bat, 1.2 + (i % 3) * 0.4, rng)
	end
end

-- Builds one line of the course into its own Model. Returns the model and the part you stand on.
local function buildStep(zone: Zone, parent: Instance, index: number): (Model, BasePart?)
	local course = cfg.Course :: { Step }
	local step = course[index]
	local m = Kit.model(ParkourLogic.StepName(course, index), parent)
	local top = Parkour.WorldCFrame(zone, index)
	local size = ParkourLogic.SizeOf(step)
	local main: BasePart? = nil
	if step.Kind == "Start" then
		main = buildStart(top, size, m)
	elseif step.Kind == "Checkpoint" then
		main = buildCheckpoint(zone, top, size, step, m, index)
	elseif step.Kind == "Finish" then
		main = buildFinish(top, size, m)
	else
		local builder = builders[step.Kind]
		if builder then
			main = builder(top, size, step, m, index)
		end
	end
	if main then
		m.PrimaryPart = main
	end
	return m, main
end

-- Building -------------------------------------------------------------------------------------

function Parkour.Build(hub: Model, zone: Zone): Model
	local area = Kit.model("Parkour", hub)
	if not Config.Features.Parkour then
		return area
	end
	for _, problem in ParkourLogic.Check(cfg.Course :: { Step }, zone.Size) do
		warn("[Parkour] " .. problem)
	end
	local course = Kit.model("Course", area)
	for i, step in cfg.Course :: { Step } do
		if type(step) ~= "table" or typeof(step.Offset) ~= "Vector3" then
			continue -- Check() above already explained what is wrong with this line
		end
		local ok, err = pcall(buildStep :: any, zone, course, i)
		if not ok then
			warn(
				("[Parkour] Couldn't build %s: %s"):format(
					ParkourLogic.StepName(cfg.Course :: { Step }, i),
					tostring(err)
				)
			)
		end
	end
	buildDecor(zone, area)
	return area
end

local function hasTagged(root: Instance, tag: string): boolean
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

function Parkour.Repair(hub: Model, zone: Zone): Model
	local existing = hub:FindFirstChild("Parkour")
	if not Config.Features.Parkour then
		return if existing and existing:IsA("Model") then existing else Kit.model("Parkour", hub)
	end
	if existing and existing:IsA("Model") then
		local others = hasTagged(existing, Tags.ParkourCheckpoint)
			or hasTagged(existing, Tags.ParkourFinish)
		if others then
			-- Keep the hand-made course, only put a start pad back.
			for i, step in cfg.Course :: { Step } do
				if step.Kind == "Start" then
					buildStep(zone, existing, i)
					break
				end
			end
			return existing
		end
		existing:Destroy()
	end
	return Parkour.Build(hub, zone)
end

-- The board's fixed lines, from Config (the reward can change after the hub was saved).
local function boardWords(): { [string]: string }
	return {
		Title = cfg.Name,
		Subtitle = cfg.Text.BoardTitle,
		Footer = cfg.Text.BoardReward:format(cfg.Reward.Coins, Config.Economy.CurrencyName),
	}
end

-- The board's sign: title, BoardRows rows (Row1, Row2...) and a footer line. A board saved in
-- the place keeps its sign, but its title and footer are written again from Config.
function Parkour.BoardGui(screen: BasePart): SurfaceGui
	local existing = screen:FindFirstChild("Board")
	if existing and existing:IsA("SurfaceGui") then
		for name, words in boardWords() do
			local label = existing:FindFirstChild(name)
			if label and label:IsA("TextLabel") and label.Text ~= words then
				label.Text = words
			end
		end
		return existing
	end
	local text = cfg.Text
	local fixed = boardWords()
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local function line(
		name: string,
		y: number,
		height: number,
		words: string,
		color: Color3,
		font: Enum.Font
	)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, height)
		label.Font = font
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Text = words
		label.Parent = gui
		return label
	end
	line("Title", 0.03, 0.17, fixed.Title, colors.Start, Enum.Font.Creepster)
	line("Subtitle", 0.2, 0.1, fixed.Subtitle, colors.Text, Enum.Font.GothamBold)
	local rows = math.max(cfg.BoardRows, 1)
	local rowHeight = 0.56 / rows
	for i = 1, rows do
		local row = line(
			"Row" .. i,
			0.32 + (i - 1) * rowHeight,
			rowHeight * 0.9,
			if i == 1 then text.BoardEmpty else "",
			Color3.new(1, 1, 1),
			Enum.Font.GothamBold
		)
		row.TextXAlignment = Enum.TextXAlignment.Left
	end
	line("Footer", 0.89, 0.09, fixed.Footer, colors.Trophy, Enum.Font.GothamBold)
	gui.Parent = screen
	return gui
end

return Parkour
