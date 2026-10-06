--!strict
--[[
	Skin head pieces: the heads a skin can swap yours for (a skin's Style.Head names one of the
	builders below), plus the little pieces that orbit CRAZY skins. Built from Parts, so the
	server can dress characters and the shop / crate previews draw exactly the same thing.
	Used by src/shared/Cosmetics.luau; skins are listed in src/shared/Config/Skins/.

	Every head piece is built around the centre of your head (front = -Z) and reads these
	Style colours (each has a default, so you can leave them out):
	  HeadColor    the main colour (the pumpkin, the fur, the candle wax...)
	  HeadColor2   the second colour (the hat, the wrapper, the inner ears...)
	  GlowColor    glowing bits (carved faces, eyes, flames, potions)
	  Face         carved pumpkin faces only: "Happy", "Spooky", "Surprised", "Sleepy",
	               "Wink" or "Toothy"
	Parts with the attribute Rainbow = true cycle through the rainbow on CRAZY skins
	(src/client/SkinFx.luau).

	New head piece: add a builder here (function builders.MyHead(m, style): BasePart, returning
	the main part), then use Head = "MyHead" in a skin. Or skip the code: a model named after
	the skin's Id in ReplicatedStorage.Custom.Cosmetics replaces the head piece.

	HeadPieces.Part(model, props) -> Part        the anchored, non-colliding part every
	                                             cosmetic is built from
	HeadPieces.Builders                          name -> builder
	HeadPieces.Has(name) -> boolean
	HeadPieces.Orbit(kind, color?) -> Model      one orbiting piece ("Pumpkins", "Candies",
	                                             "Ghosts", "Bones", "Eyes", "Stars", "Bats")
	HeadPieces.OrbitKinds                        the list of orbit kinds
]]

local HeadPieces = {}

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYLINDER = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(30, 22, 38) -- eyes, stitches and mouths
local BLUSH = Color3.fromRGB(255, 150, 170)
local STEM = Color3.fromRGB(90, 160, 60)

-- The part every cosmetic is made of: anchored, no collisions, no shadows. A "Ball" that
-- isn't perfectly round becomes a block with a sphere mesh (Roblox balls are always round).
local function part(m: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	local size: Vector3 = props.Size or p.Size -- p.Size may already be forced round
	if p.Shape == BALL and (size.X ~= size.Y or size.Y ~= size.Z) then
		p.Shape = BLOCK
		p.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = m
	return p
end
HeadPieces.Part = part

-- A cylinder standing up (Roblox cylinders lie along X).
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- A cylinder facing forward (its round face toward -Z), like a button or a coin.
local function facing(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, math.rad(90), 0)
end

local function color(style: any, key: string, default: Color3): Color3
	local value = style[key]
	return if typeof(value) == "Color3" then value else default
end

local function darker(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(c: Color3, amount: number): Color3
	return c:Lerp(WHITE, amount)
end

local function rainbow(p: BasePart): BasePart
	p:SetAttribute("Rainbow", true)
	return p
end

-- How far forward (-Z) the surface of an ellipsoid of `size` is at (x, y) from its centre.
local function front(size: Vector3, x: number, y: number): number
	local nx, ny = 2 * x / size.X, 2 * y / size.Y
	return -(size.Z / 2) * math.sqrt(math.max(0, 1 - nx * nx - ny * ny))
end

-- Two round cartoon eyes with a white shine, on a head of `size` centred at `centre`.
local function cuteEyes(
	m: Model,
	centre: Vector3,
	size: Vector3,
	y: number,
	spacing: number,
	eye: number,
	eyeColor: Color3
)
	for _, side in { -1, 1 } do
		local x = side * spacing
		local z = front(size, x, y) + eye * 0.12
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(eye, eye * 1.2, eye * 0.5),
			CFrame = CFrame.new(centre + Vector3.new(x, y, z)),
			Color = eyeColor,
		})
		part(m, {
			Name = "EyeShine",
			Shape = BALL,
			Size = Vector3.one * eye * 0.36,
			CFrame = CFrame.new(
				centre + Vector3.new(x + eye * 0.15, y + eye * 0.22, z - eye * 0.2)
			),
			Color = WHITE,
			Material = NEON,
		})
	end
end

-- A small smile (three short bars bending up at the ends).
local function smile(m: Model, centre: Vector3, size: Vector3, y: number, width: number, c: Color3)
	local z = front(size, 0, y) + 0.02
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(width * 0.45, 0.08, 0.08),
		CFrame = CFrame.new(centre + Vector3.new(0, y, z)),
		Color = c,
	})
	for _, side in { -1, 1 } do
		local x = side * width * 0.36
		part(m, {
			Name = "Mouth",
			Size = Vector3.new(width * 0.32, 0.08, 0.08),
			CFrame = CFrame.new(
				centre + Vector3.new(x, y + width * 0.07, front(size, x, y) + 0.03)
			) * CFrame.Angles(0, 0, math.rad(side * 28)),
			Color = c,
		})
	end
end

local function cheeks(m: Model, centre: Vector3, size: Vector3, y: number, spacing: number)
	for _, side in { -1, 1 } do
		local x = side * spacing
		part(m, {
			Name = "Cheek",
			Shape = BALL,
			Size = Vector3.new(0.28, 0.16, 0.06),
			CFrame = CFrame.new(centre + Vector3.new(x, y, front(size, x, y) + 0.01)),
			Color = BLUSH,
		})
	end
end

-- A round head (ball) with cute eyes and a smile: the base of the hat-style head pieces.
local function cuteHead(m: Model, size: Vector3, skin: Color3, eyeColor: Color3?): Part
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = skin })
	cuteEyes(m, Vector3.zero, size, size.Y * 0.06, size.X * 0.2, size.X * 0.16, eyeColor or INK)
	smile(m, Vector3.zero, size, -size.Y * 0.22, size.X * 0.3, INK)
	cheeks(m, Vector3.zero, size, -size.Y * 0.12, size.X * 0.32)
	return handle
end

-- A pointy ear: a square turned 45 degrees, half sunk into the head.
local function ear(m: Model, at: CFrame, s: number, outer: Color3, inner: Color3?)
	local base = at * CFrame.Angles(0, 0, math.rad(45))
	part(m, { Name = "Ear", Size = Vector3.new(s, s, 0.16), CFrame = base, Color = outer })
	if inner then
		part(m, {
			Name = "EarInside",
			Size = Vector3.new(s * 0.6, s * 0.6, 0.06),
			CFrame = base * CFrame.new(s * 0.08, s * 0.08, -0.09),
			Color = inner,
		})
	end
end

-- A four-pointed star made of two thin squares.
local function star(m: Model, at: CFrame, s: number, c: Color3, name: string?): Part
	local first = part(m, {
		Name = name or "Star",
		Size = Vector3.new(s * 0.35, s, 0.08),
		CFrame = at,
		Color = c,
		Material = NEON,
	})
	part(m, {
		Name = name or "Star",
		Size = Vector3.new(s, s * 0.35, 0.08),
		CFrame = at,
		Color = c,
		Material = NEON,
	})
	return first
end

local builders: { [string]: (Model, any) -> BasePart } = {}
HeadPieces.Builders = builders

function HeadPieces.Has(name: unknown): boolean
	return type(name) == "string" and builders[name] ~= nil
end

-- Carved pumpkin faces ------------------------------------------------------------------------

local FACES = { "Happy", "Spooky", "Surprised", "Sleepy", "Wink", "Toothy" }
HeadPieces.Faces = FACES

local function carved(m: Model, props: { [string]: any }): Part
	props.Material = NEON
	return part(m, props)
end

-- A glowing carved face on a pumpkin of `size` (centred at `centre`).
local function carvedFace(
	m: Model,
	centre: Vector3,
	size: Vector3,
	face: string,
	glow: Color3,
	skin: Color3
)
	local s = size.X / 2.5 -- the faces were drawn on a 2.5 stud pumpkin
	local eyeY, mouthY = 0.25 * s, -0.38 * s
	local function at(x: number, y: number): CFrame
		return CFrame.new(centre + Vector3.new(x, y, front(size, x, y) + 0.02))
	end
	local function triangleEye(side: number, tilt: number)
		carved(m, {
			Name = "Eye",
			Size = Vector3.new(0.45, 0.4, 0.1) * s,
			CFrame = at(side * 0.42 * s, eyeY) * CFrame.Angles(0, 0, math.rad(side * tilt)),
			Color = glow,
		})
	end
	local function roundEye(side: number, d: number)
		carved(m, {
			Name = "Eye",
			Shape = CYLINDER,
			Size = Vector3.new(0.1, d * s, d * s),
			CFrame = facing(at(side * 0.42 * s, eyeY)),
			Color = glow,
		})
	end
	local function lineEye(side: number)
		carved(m, {
			Name = "Eye",
			Size = Vector3.new(0.45 * s, 0.1 * s, 0.1),
			CFrame = at(side * 0.42 * s, eyeY - 0.05 * s),
			Color = glow,
		})
	end
	if face == "Spooky" then
		triangleEye(-1, -25)
		triangleEye(1, -25)
		for i = 1, 5 do
			local x = (i - 3) * 0.22 * s
			carved(m, {
				Name = "Mouth",
				Size = Vector3.new(0.26, 0.22, 0.1) * s,
				CFrame = at(x, mouthY + (if i % 2 == 0 then 0.08 else -0.04) * s)
					* CFrame.Angles(0, 0, math.rad(45)),
				Color = glow,
			})
		end
	elseif face == "Surprised" then
		roundEye(-1, 0.42)
		roundEye(1, 0.42)
		carved(m, {
			Name = "Mouth",
			Shape = CYLINDER,
			Size = Vector3.new(0.1, 0.42 * s, 0.36 * s),
			CFrame = facing(at(0, mouthY)),
			Color = glow,
		})
	elseif face == "Sleepy" then
		lineEye(-1)
		lineEye(1)
		carved(m, {
			Name = "Mouth",
			Size = Vector3.new(0.4, 0.14, 0.1) * s,
			CFrame = at(0, mouthY),
			Color = glow,
		})
	elseif face == "Wink" then
		roundEye(-1, 0.4)
		lineEye(1)
		smile(m, centre, size, mouthY, 1.0 * s, glow)
		for _, child in m:GetChildren() do
			if child.Name == "Mouth" and child:IsA("BasePart") then
				child.Material = NEON
				child.Size = Vector3.new(child.Size.X, 0.14 * s, child.Size.Z)
			end
		end
	else -- Happy and Toothy
		triangleEye(-1, 12)
		triangleEye(1, 12)
		carved(m, {
			Name = "Mouth",
			Size = Vector3.new(1.1, if face == "Toothy" then 0.36 else 0.28, 0.1) * s,
			CFrame = at(0, mouthY),
			Color = glow,
		})
		if face == "Toothy" then
			for _, x in { -0.22, 0.22 } do
				part(m, {
					Name = "Tooth",
					Size = Vector3.new(0.16, 0.16, 0.12) * s,
					CFrame = at(x * s, mouthY + 0.1 * s) * CFrame.new(0, 0, -0.02),
					Color = skin,
				})
			end
		end
	end
end

-- A pumpkin with two darker side lobes, so the ribs show.
local function pumpkin(m: Model, size: Vector3, skin: Color3, centre: Vector3?, name: string?): Part
	local at = centre or Vector3.zero
	local body = part(m, {
		Name = name or "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(at),
		Color = skin,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Lobe",
			Shape = BALL,
			Size = Vector3.new(size.X * 0.62, size.Y * 0.95, size.Z * 0.9),
			CFrame = CFrame.new(at + Vector3.new(side * size.X * 0.21, 0, 0)),
			Color = darker(skin, 0.1),
		})
	end
	part(m, {
		Name = "Stem",
		Size = Vector3.new(0.12, 0.2, 0.12) * size.X,
		CFrame = CFrame.new(at + Vector3.new(0, size.Y * 0.52, 0))
			* CFrame.Angles(0, 0, math.rad(10)),
		Color = STEM,
	})
	return body
end

-- Pumpkins and skulls (the first skins' heads) ------------------------------------------------

-- A carved jack-o'-lantern (Face picks the carving).
function builders.SkinPumpkin(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(255, 130, 20))
	local size = Vector3.new(2.5, 2.1, 2.5)
	local handle = pumpkin(m, size, skin)
	part(m, {
		Name = "Leaf",
		Size = Vector3.new(0.5, 0.06, 0.3),
		CFrame = CFrame.new(0.3, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Color = STEM,
	})
	local face = if type(style.Face) == "string" then style.Face else "Happy"
	carvedFace(
		m,
		Vector3.zero,
		size,
		face,
		color(style, "GlowColor", Color3.fromRGB(255, 220, 90)),
		skin
	)
	return handle
end

function builders.SkinSkull(m: Model, style: any): BasePart
	local bone = color(style, "HeadColor", Color3.fromRGB(235, 228, 210))
	local size = Vector3.new(1.7, 1.6, 1.7)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(0, 0.1, 0),
		Color = bone,
	})
	part(m, {
		Name = "Jaw",
		Size = Vector3.new(1, 0.4, 0.9),
		CFrame = CFrame.new(0, -0.65, -0.25),
		Color = bone,
	})
	local glow = color(style, "GlowColor", Color3.fromRGB(120, 255, 110))
	for _, side in { -1, 1 } do
		part(m, {
			Name = "EyeHole",
			Shape = BALL,
			Size = Vector3.new(0.42, 0.42, 0.2),
			CFrame = CFrame.new(side * 0.32, 0.2, -0.72),
			Color = Color3.fromRGB(20, 20, 25),
		})
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.one * 0.14,
			CFrame = CFrame.new(side * 0.32, 0.2, -0.8),
			Color = glow,
			Material = NEON,
		})
	end
	part(m, {
		Name = "Nose",
		Size = Vector3.new(0.14, 0.18, 0.1),
		CFrame = CFrame.new(0, -0.08, -0.82) * CFrame.Angles(0, 0, math.rad(45)),
		Color = Color3.fromRGB(20, 20, 25),
	})
	return handle
end

function builders.SkinKing(m: Model, style: any): BasePart
	local handle = builders.SkinPumpkin(m, style)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(m, {
			Name = "CrownSpike",
			Size = Vector3.new(0.3, 0.6, 0.3),
			CFrame = CFrame.new(math.cos(a) * 0.55, 1.35, math.sin(a) * 0.55)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = color(style, "GlowColor", Color3.fromRGB(255, 210, 60)),
			Material = NEON,
		})
	end
	return handle
end

-- A sweet sugar skull: flower eyes, a heart nose and a toothy grin.
function builders.CandySkull(m: Model, style: any): BasePart
	local bone = color(style, "HeadColor", Color3.fromRGB(250, 246, 240))
	local deco = color(style, "HeadColor2", Color3.fromRGB(255, 110, 190))
	local glow = color(style, "GlowColor", Color3.fromRGB(90, 220, 255))
	local size = Vector3.new(1.7, 1.6, 1.7)
	local centre = Vector3.new(0, 0.1, 0)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(centre),
		Color = bone,
	})
	part(m, {
		Name = "Jaw",
		Size = Vector3.new(1, 0.4, 0.9),
		CFrame = CFrame.new(0, -0.65, -0.25),
		Color = bone,
	})
	for _, side in { -1, 1 } do
		local x, y = side * 0.33, 0.12
		local z = front(size, x, y) + 0.02
		part(m, {
			Name = "EyeRing",
			Shape = CYLINDER,
			Size = Vector3.new(0.06, 0.5, 0.5),
			CFrame = facing(CFrame.new(centre + Vector3.new(x, y, z + 0.01))),
			Color = deco,
		})
		part(m, {
			Name = "Eye",
			Shape = CYLINDER,
			Size = Vector3.new(0.06, 0.26, 0.26),
			CFrame = facing(CFrame.new(centre + Vector3.new(x, y, z - 0.02))),
			Color = glow,
			Material = NEON,
		})
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			part(m, {
				Name = "Petal",
				Shape = BALL,
				Size = Vector3.new(0.13, 0.13, 0.05),
				CFrame = CFrame.new(
					centre + Vector3.new(x + math.cos(a) * 0.33, y + math.sin(a) * 0.33, z + 0.02)
				),
				Color = if i % 2 == 0 then deco else glow,
			})
		end
	end
	-- heart nose
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Nose",
			Shape = BALL,
			Size = Vector3.new(0.13, 0.13, 0.06),
			CFrame = CFrame.new(side * 0.055, -0.12, front(size, 0, -0.22) + 0.02),
			Color = deco,
		})
	end
	part(m, {
		Name = "Nose",
		Size = Vector3.new(0.12, 0.12, 0.06),
		CFrame = CFrame.new(0, -0.19, front(size, 0, -0.29) + 0.02)
			* CFrame.Angles(0, 0, math.rad(45)),
		Color = deco,
	})
	for i = -2, 2 do
		part(m, {
			Name = "Tooth",
			Size = Vector3.new(0.12, 0.14, 0.06),
			CFrame = CFrame.new(i * 0.15, -0.6, -0.71),
			Color = WHITE,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.8, 0.05, 0.05),
		CFrame = CFrame.new(0, -0.6, -0.74),
		Color = INK,
	})
	for i = -1, 1 do
		part(m, {
			Name = "Dot",
			Shape = BALL,
			Size = Vector3.new(0.12, 0.12, 0.05),
			CFrame = CFrame.new(i * 0.2, 0.62, front(size, i * 0.2, 0.52) + 0.04),
			Color = if i == 0 then glow else deco,
		})
	end
	return handle
end

-- Candy ----------------------------------------------------------------------------------------

-- A wrapped sweet: a striped candy with twisted wrapper ends.
function builders.CandyWrapper(m: Model, style: any): BasePart
	local candy = color(style, "HeadColor", Color3.fromRGB(255, 90, 150))
	local stripe = color(style, "HeadColor2", WHITE)
	local size = Vector3.new(2.0, 1.7, 1.7)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = candy })
	for _, x in { -0.55, 0, 0.55 } do
		local section = math.sqrt(1 - (2 * x / size.X) ^ 2)
		part(m, {
			Name = "Stripe",
			Shape = CYLINDER,
			Size = Vector3.new(0.16, size.Y * section + 0.05, size.Z * section + 0.05),
			CFrame = CFrame.new(x, 0, 0),
			Color = stripe,
		})
	end
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Twist",
			Shape = CYLINDER,
			Size = Vector3.new(0.35, 0.4, 0.4),
			CFrame = CFrame.new(side * 1.1, 0, 0),
			Color = candy,
		})
		for i, tilt in { -28, 0, 28 } do
			part(m, {
				Name = "Wrapper",
				Size = Vector3.new(0.55, 0.95 - math.abs(tilt) / 100, 0.1),
				CFrame = CFrame.new(side * 1.5, 0, 0)
					* CFrame.Angles(math.rad(tilt), math.rad(side * 15 * (i - 2)), 0),
				Color = if i == 2 then stripe else candy,
			})
		end
	end
	cuteEyes(m, Vector3.zero, size, 0.12, 0.32, 0.26, INK)
	smile(m, Vector3.zero, size, -0.3, 0.45, INK)
	cheeks(m, Vector3.zero, size, -0.18, 0.55)
	return handle
end

-- A cupcake: frilly wrapper, swirly frosting, sprinkles and a cherry on top.
function builders.CupcakeHead(m: Model, style: any): BasePart
	local frosting = color(style, "HeadColor", Color3.fromRGB(255, 190, 220))
	local wrapper = color(style, "HeadColor2", Color3.fromRGB(90, 200, 220))
	local cherry = color(style, "GlowColor", Color3.fromRGB(235, 40, 70))
	local handle = part(m, {
		Name = "Handle",
		Shape = CYLINDER,
		Size = Vector3.new(1.0, 1.55, 1.55),
		CFrame = upright(CFrame.new(0, -0.35, 0)),
		Color = wrapper,
	})
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		part(m, {
			Name = "Fold",
			Size = Vector3.new(0.14, 1.0, 0.1),
			CFrame = CFrame.new(math.cos(a) * 0.76, -0.35, math.sin(a) * 0.76)
				* CFrame.Angles(0, -a, 0),
			Color = lighter(wrapper, 0.3),
		})
	end
	part(m, {
		Name = "Frosting",
		Shape = BALL,
		Size = Vector3.new(1.95, 1.0, 1.95),
		CFrame = CFrame.new(0, 0.3, 0),
		Color = frosting,
	})
	part(m, {
		Name = "Frosting",
		Shape = BALL,
		Size = Vector3.new(1.3, 0.75, 1.3),
		CFrame = CFrame.new(0, 0.75, 0),
		Color = lighter(frosting, 0.15),
	})
	part(m, {
		Name = "Frosting",
		Shape = BALL,
		Size = Vector3.new(0.6, 0.55, 0.6),
		CFrame = CFrame.new(0, 1.1, 0),
		Color = frosting,
	})
	part(m, {
		Name = "Cherry",
		Shape = BALL,
		Size = Vector3.one * 0.45,
		CFrame = CFrame.new(0, 1.45, 0),
		Color = cherry,
	})
	part(m, {
		Name = "CherryStem",
		Size = Vector3.new(0.05, 0.35, 0.05),
		CFrame = CFrame.new(0.06, 1.75, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Color = STEM,
	})
	local sprinkles = {
		Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(120, 230, 255),
		Color3.fromRGB(150, 255, 120),
		Color3.fromRGB(255, 120, 200),
	}
	for i = 1, 10 do
		local a = i * 2.4
		local r = 0.55 + (i % 3) * 0.12
		part(m, {
			Name = "Sprinkle",
			Size = Vector3.new(0.2, 0.06, 0.06),
			CFrame = CFrame.new(math.cos(a) * r, 0.55 + (i % 2) * 0.12, math.sin(a) * r)
				* CFrame.Angles(0, a * 1.7, math.rad(20)),
			Color = sprinkles[i % #sprinkles + 1],
			Material = NEON,
		})
	end
	local face = Vector3.new(1.55, 1.0, 1.55)
	local at = Vector3.new(0, -0.35, 0)
	cuteEyes(m, at, face, 0.12, 0.3, 0.24, INK)
	smile(m, at, face, -0.22, 0.4, INK)
	return handle
end

-- A sugary gumdrop with a sparkly coat.
function builders.GumdropHead(m: Model, style: any): BasePart
	local sweet = color(style, "HeadColor", Color3.fromRGB(140, 230, 110))
	local size = Vector3.new(1.9, 2.1, 1.9)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(0, 0.05, 0),
		Color = sweet,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
	})
	part(m, {
		Name = "Base",
		Shape = CYLINDER,
		Size = Vector3.new(0.6, 1.9, 1.9),
		CFrame = upright(CFrame.new(0, -0.55, 0)),
		Color = sweet,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
	})
	local sugar = color(style, "HeadColor2", WHITE)
	for i = 1, 14 do
		local a = i * 2.39996
		local y = -0.3 + (i % 5) * 0.28
		local r = math.sqrt(math.max(0.05, 1 - (y / 1.05) ^ 2)) * 0.95
		part(m, {
			Name = "Sugar",
			Size = Vector3.one * 0.09,
			CFrame = CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(a, a, 0),
			Color = sugar,
			Material = NEON,
		})
	end
	cuteEyes(m, Vector3.new(0, 0.05, 0), size, 0.0, 0.33, 0.27, INK)
	smile(m, Vector3.new(0, 0.05, 0), size, -0.4, 0.45, INK)
	return handle
end

-- Ghosts and spooky things ----------------------------------------------------------------------

-- A friendly bedsheet ghost.
function builders.GhostSheet(m: Model, style: any): BasePart
	local sheet = color(style, "HeadColor", Color3.fromRGB(245, 245, 255))
	local size = Vector3.new(1.95, 1.95, 1.95)
	local centre = Vector3.new(0, 0.2, 0)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(centre),
		Color = sheet,
	})
	part(m, {
		Name = "Sheet",
		Shape = CYLINDER,
		Size = Vector3.new(1.05, 2.05, 2.05),
		CFrame = upright(CFrame.new(0, -0.45, 0)),
		Color = sheet,
	})
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(m, {
			Name = "Hem",
			Shape = BALL,
			Size = Vector3.new(0.7, 0.55, 0.7),
			CFrame = CFrame.new(math.cos(a) * 0.82, -0.98, math.sin(a) * 0.82),
			Color = sheet,
		})
	end
	local eye = color(style, "GlowColor", INK)
	for _, side in { -1, 1 } do
		local x, y = side * 0.36, 0.32
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.3, 0.46, 0.12),
			CFrame = CFrame.new(centre + Vector3.new(x, y, front(size, x, y) + 0.03)),
			Color = eye,
		})
	end
	part(m, {
		Name = "Mouth",
		Shape = BALL,
		Size = Vector3.new(0.26, 0.3, 0.1),
		CFrame = CFrame.new(centre + Vector3.new(0, -0.18, front(size, 0, -0.18) + 0.02)),
		Color = eye,
	})
	cheeks(m, centre, size, 0.02, 0.6)
	return handle
end

-- A bat: big pointy ears, little wings at the sides and two tiny fangs.
function builders.BatHead(m: Model, style: any): BasePart
	local fur = color(style, "HeadColor", Color3.fromRGB(70, 50, 95))
	local inner = color(style, "HeadColor2", Color3.fromRGB(255, 150, 190))
	local size = Vector3.new(1.65, 1.55, 1.55)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = fur })
	for _, side in { -1, 1 } do
		ear(
			m,
			CFrame.new(side * 0.5, 0.75, 0.05) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			0.7,
			fur,
			inner
		)
		for i, s in { Vector3.new(0.85, 0.5, 0.06), Vector3.new(0.6, 0.36, 0.06) } do
			part(m, {
				Name = "Wing",
				Size = s,
				CFrame = CFrame.new(side * (0.95 + i * 0.32), 0.05 + i * 0.1, 0.25)
					* CFrame.Angles(0, math.rad(side * 25), math.rad(side * (15 + i * 18))),
				Color = darker(fur, 0.15),
			})
		end
	end
	cuteEyes(m, Vector3.zero, size, 0.1, 0.3, 0.27, color(style, "GlowColor", INK))
	smile(m, Vector3.zero, size, -0.28, 0.4, INK)
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Fang",
			Size = Vector3.new(0.07, 0.12, 0.05),
			CFrame = CFrame.new(side * 0.1, -0.36, front(size, side * 0.1, -0.36) + 0.02),
			Color = WHITE,
		})
	end
	return handle
end

-- A cat: pointy ears, glowing eyes with slit pupils, a pink nose and whiskers.
function builders.CatHead(m: Model, style: any): BasePart
	local fur = color(style, "HeadColor", Color3.fromRGB(40, 35, 50))
	local inner = color(style, "HeadColor2", Color3.fromRGB(255, 150, 190))
	local glow = color(style, "GlowColor", Color3.fromRGB(190, 255, 90))
	local size = Vector3.new(1.75, 1.55, 1.6)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = fur })
	for _, side in { -1, 1 } do
		ear(
			m,
			CFrame.new(side * 0.52, 0.7, 0) * CFrame.Angles(0, 0, math.rad(-side * 10)),
			0.62,
			fur,
			inner
		)
		local x, y = side * 0.34, 0.12
		local z = front(size, x, y) + 0.03
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.34, 0.4, 0.12),
			CFrame = CFrame.new(x, y, z),
			Color = glow,
			Material = NEON,
		})
		part(m, {
			Name = "Pupil",
			Size = Vector3.new(0.07, 0.3, 0.06),
			CFrame = CFrame.new(x, y, z - 0.05),
			Color = INK,
		})
		for i = -1, 1 do
			part(m, {
				Name = "Whisker",
				Size = Vector3.new(0.55, 0.03, 0.03),
				CFrame = CFrame.new(
					side * 0.62,
					-0.2 + i * 0.07,
					front(size, side * 0.45, -0.2) + 0.05
				) * CFrame.Angles(0, 0, math.rad(side * i * 10)),
				Color = WHITE,
			})
		end
	end
	part(m, {
		Name = "Nose",
		Size = Vector3.new(0.14, 0.14, 0.08),
		CFrame = CFrame.new(0, -0.12, front(size, 0, -0.12) + 0.02)
			* CFrame.Angles(0, 0, math.rad(45)),
		Color = inner,
	})
	return handle
end

-- A friendly cyclops-style eyeball.
function builders.EyeballHead(m: Model, style: any): BasePart
	local white = color(style, "HeadColor", Color3.fromRGB(248, 246, 240))
	local iris = color(style, "HeadColor2", Color3.fromRGB(80, 200, 120))
	local size = Vector3.one * 1.95
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = white })
	part(m, {
		Name = "Iris",
		Shape = BALL,
		Size = Vector3.new(1.0, 1.0, 0.24),
		CFrame = CFrame.new(0, 0.05, -0.9),
		Color = iris,
	})
	part(m, {
		Name = "Pupil",
		Shape = BALL,
		Size = Vector3.new(0.48, 0.48, 0.14),
		CFrame = CFrame.new(0, 0.05, -0.99),
		Color = INK,
	})
	part(m, {
		Name = "Shine",
		Shape = BALL,
		Size = Vector3.one * 0.16,
		CFrame = CFrame.new(0.17, 0.24, -1.04),
		Color = color(style, "GlowColor", WHITE),
		Material = NEON,
	})
	for i = -1, 1 do
		part(m, {
			Name = "Lash",
			Size = Vector3.new(0.06, 0.35, 0.06),
			CFrame = CFrame.new(i * 0.3, 0.98, -0.25)
				* CFrame.Angles(math.rad(-25), 0, math.rad(-i * 25)),
			Color = INK,
		})
	end
	return handle
end

-- A cute zombie: green skin, messy hair, a stitch and one big eye.
function builders.ZombieHead(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(140, 195, 110))
	local hair = color(style, "HeadColor2", Color3.fromRGB(60, 45, 70))
	local size = Vector3.new(1.6, 1.6, 1.5)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = skin })
	local tufts = {
		{ -0.45, 0.62, 25 },
		{ -0.15, 0.75, -10 },
		{ 0.18, 0.74, 15 },
		{ 0.45, 0.6, -30 },
		{ 0.0, 0.68, 40 },
	}
	for _, t in tufts do
		part(m, {
			Name = "Hair",
			Size = Vector3.new(0.32, 0.5, 0.5),
			CFrame = CFrame.new(t[1], t[2], 0.05)
				* CFrame.Angles(math.rad(t[3]), 0, math.rad(t[3])),
			Color = hair,
		})
	end
	local eye = color(style, "GlowColor", Color3.fromRGB(255, 240, 150))
	for _, spec in { { -0.33, 0.36 }, { 0.33, 0.26 } } do
		local x, d = spec[1], spec[2]
		local z = front(size, x, 0.1) + 0.04
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(d, d, 0.1),
			CFrame = CFrame.new(x, 0.1, z),
			Color = eye,
		})
		part(m, {
			Name = "Pupil",
			Shape = BALL,
			Size = Vector3.new(d * 0.4, d * 0.4, 0.06),
			CFrame = CFrame.new(x + 0.03, 0.08, z - 0.04),
			Color = INK,
		})
	end
	local sx, sy = 0.25, 0.5
	part(m, {
		Name = "Stitch",
		Size = Vector3.new(0.5, 0.05, 0.05),
		CFrame = CFrame.new(sx, sy, front(size, sx, sy) + 0.02)
			* CFrame.Angles(0, 0, math.rad(-12)),
		Color = INK,
	})
	for i = -1, 1 do
		part(m, {
			Name = "Stitch",
			Size = Vector3.new(0.04, 0.16, 0.05),
			CFrame = CFrame.new(
				sx + i * 0.15,
				sy + 0.03 - i * 0.03,
				front(size, sx + i * 0.15, sy) + 0.02
			),
			Color = INK,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.45, 0.07, 0.06),
		CFrame = CFrame.new(0, -0.35, front(size, 0, -0.35) + 0.02)
			* CFrame.Angles(0, 0, math.rad(6)),
		Color = INK,
	})
	part(m, {
		Name = "Tooth",
		Size = Vector3.new(0.09, 0.09, 0.05),
		CFrame = CFrame.new(0.08, -0.4, front(size, 0.08, -0.4) + 0.02),
		Color = WHITE,
	})
	return handle
end

-- Wrapped up like a mummy, with one glowing eye peeking out.
function builders.MummyHead(m: Model, style: any): BasePart
	local wrap = color(style, "HeadColor", Color3.fromRGB(228, 218, 192))
	local size = Vector3.new(1.65, 1.65, 1.6)
	local handle =
		part(m, { Name = "Handle", Shape = BALL, Size = size, Color = darker(wrap, 0.12) })
	for i, y in { 0.5, 0.2, -0.12, -0.42 } do
		local section = math.sqrt(math.max(0.1, 1 - (2 * y / size.Y) ^ 2))
		part(m, {
			Name = "Wrap",
			Shape = CYLINDER,
			Size = Vector3.new(0.24, size.X * section + 0.07, size.Z * section + 0.07),
			CFrame = upright(CFrame.new(0, y, 0))
				* CFrame.Angles(math.rad(if i % 2 == 0 then 9 else -9), 0, 0),
			Color = if i % 2 == 0 then wrap else lighter(wrap, 0.2),
		})
	end
	local glow = color(style, "GlowColor", Color3.fromRGB(120, 255, 140))
	part(m, {
		Name = "Eye",
		Shape = BALL,
		Size = Vector3.new(0.3, 0.26, 0.1),
		CFrame = CFrame.new(-0.3, 0.06, front(size, -0.3, 0.06) - 0.01),
		Color = glow,
		Material = NEON,
	})
	part(m, {
		Name = "Eye",
		Shape = BALL,
		Size = Vector3.new(0.18, 0.16, 0.08),
		CFrame = CFrame.new(0.32, 0.06, front(size, 0.32, 0.06) - 0.01),
		Color = INK,
	})
	part(m, {
		Name = "LooseEnd",
		Size = Vector3.new(0.18, 0.6, 0.06),
		CFrame = CFrame.new(0.7, -0.45, -0.45) * CFrame.Angles(0, math.rad(-40), math.rad(15)),
		Color = wrap,
	})
	return handle
end

-- A vampire: slicked-back hair, a tall cape collar and two tiny fangs.
function builders.VampireHead(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(225, 225, 240))
	local collar = color(style, "HeadColor2", Color3.fromRGB(35, 25, 45))
	local lining = color(style, "GlowColor", Color3.fromRGB(200, 30, 60))
	local hairColor = Color3.fromRGB(30, 22, 40)
	local size = Vector3.new(1.5, 1.65, 1.5)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = skin })
	part(m, {
		Name = "Hair",
		Shape = BALL,
		Size = Vector3.new(1.6, 0.95, 1.62),
		CFrame = CFrame.new(0, 0.48, 0.06),
		Color = hairColor,
	})
	part(m, {
		Name = "HairPeak",
		Size = Vector3.new(0.3, 0.3, 0.12),
		CFrame = CFrame.new(0, 0.38, front(size, 0, 0.38) + 0.04)
			* CFrame.Angles(0, 0, math.rad(45)),
		Color = hairColor,
	})
	for _, side in { -1, 1 } do
		local at = CFrame.new(side * 0.62, -0.25, 0.42)
			* CFrame.Angles(math.rad(-12), math.rad(side * 35), math.rad(side * -18))
		part(
			m,
			{ Name = "Collar", Size = Vector3.new(0.95, 1.5, 0.08), CFrame = at, Color = collar }
		)
		part(m, {
			Name = "CollarLining",
			Size = Vector3.new(0.8, 1.35, 0.04),
			CFrame = at * CFrame.new(0, 0, -0.06),
			Color = lining,
		})
	end
	cuteEyes(m, Vector3.zero, size, 0.05, 0.28, 0.24, INK)
	smile(m, Vector3.zero, size, -0.32, 0.36, INK)
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Fang",
			Size = Vector3.new(0.07, 0.13, 0.05),
			CFrame = CFrame.new(side * 0.09, -0.4, front(size, side * 0.09, -0.4) + 0.02),
			Color = WHITE,
		})
	end
	return handle
end

-- A candle with wax drips and a little flame on top.
function builders.CandleHead(m: Model, style: any): BasePart
	local wax = color(style, "HeadColor", Color3.fromRGB(250, 235, 200))
	local flame = color(style, "GlowColor", Color3.fromRGB(255, 190, 60))
	local handle = part(m, {
		Name = "Handle",
		Shape = CYLINDER,
		Size = Vector3.new(1.9, 1.45, 1.45),
		CFrame = upright(CFrame.new(0, 0.05, 0)),
		Color = wax,
	})
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.4
		local long = 0.3 + (i % 3) * 0.18
		part(m, {
			Name = "Drip",
			Shape = BALL,
			Size = Vector3.new(0.26, long, 0.26),
			CFrame = CFrame.new(math.cos(a) * 0.7, 1.0 - long / 2, math.sin(a) * 0.7),
			Color = lighter(wax, 0.25),
		})
	end
	part(m, {
		Name = "Wick",
		Size = Vector3.new(0.07, 0.3, 0.07),
		CFrame = CFrame.new(0, 1.12, 0),
		Color = INK,
	})
	part(m, {
		Name = "Flame",
		Shape = BALL,
		Size = Vector3.new(0.36, 0.62, 0.36),
		CFrame = CFrame.new(0, 1.5, 0),
		Color = flame,
		Material = NEON,
	})
	part(m, {
		Name = "FlameCore",
		Shape = BALL,
		Size = Vector3.new(0.16, 0.28, 0.16),
		CFrame = CFrame.new(0, 1.4, -0.12),
		Color = Color3.fromRGB(255, 250, 220),
		Material = NEON,
	})
	-- the face sits on the round side of the candle (a very tall "ellipsoid" = a cylinder)
	local side = Vector3.new(1.45, 40, 1.45)
	cuteEyes(m, Vector3.zero, side, 0.2, 0.28, 0.24, INK)
	smile(m, Vector3.zero, side, -0.15, 0.38, INK)
	cheeks(m, Vector3.zero, side, -0.02, 0.46)
	return handle
end

-- A burlap scarecrow with a straw hat and a stitched smile.
function builders.ScarecrowHead(m: Model, style: any): BasePart
	local burlap = color(style, "HeadColor", Color3.fromRGB(205, 175, 120))
	local hat = color(style, "HeadColor2", Color3.fromRGB(215, 180, 90))
	local band = color(style, "GlowColor", Color3.fromRGB(200, 60, 50))
	local size = Vector3.new(1.7, 1.75, 1.6)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		Color = burlap,
		Material = Enum.Material.Fabric,
	})
	part(m, {
		Name = "HatBrim",
		Shape = CYLINDER,
		Size = Vector3.new(0.12, 2.7, 2.7),
		CFrame = upright(CFrame.new(0, 0.62, 0)) * CFrame.Angles(math.rad(6), 0, 0),
		Color = hat,
	})
	part(m, {
		Name = "HatTop",
		Shape = CYLINDER,
		Size = Vector3.new(0.7, 1.35, 1.35),
		CFrame = upright(CFrame.new(0, 1.0, 0)),
		Color = hat,
	})
	part(m, {
		Name = "HatBand",
		Shape = CYLINDER,
		Size = Vector3.new(0.18, 1.4, 1.4),
		CFrame = upright(CFrame.new(0, 0.78, 0)),
		Color = band,
	})
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + 0.3
		part(m, {
			Name = "Straw",
			Size = Vector3.new(0.06, 0.45, 0.06),
			CFrame = CFrame.new(math.cos(a) * 0.65, -0.75, math.sin(a) * 0.65)
				* CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6),
			Color = hat,
		})
	end
	for _, side in { -1, 1 } do
		local x, y = side * 0.33, 0.12
		part(m, {
			Name = "ButtonEye",
			Shape = CYLINDER,
			Size = Vector3.new(0.08, 0.3, 0.3),
			CFrame = facing(CFrame.new(x, y, front(size, x, y) + 0.02)),
			Color = INK,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.75, 0.05, 0.05),
		CFrame = CFrame.new(0, -0.32, front(size, 0, -0.32) + 0.02),
		Color = INK,
	})
	for i = -2, 2 do
		local x = i * 0.15
		part(m, {
			Name = "Stitch",
			Size = Vector3.new(0.04, 0.17, 0.05),
			CFrame = CFrame.new(x, -0.32, front(size, x, -0.32) + 0.02),
			Color = INK,
		})
	end
	return handle
end

-- A round little face under a tall pointy witch hat.
function builders.WitchHood(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(160, 215, 130))
	local hat = color(style, "HeadColor2", Color3.fromRGB(70, 35, 100))
	local band = color(style, "GlowColor", Color3.fromRGB(255, 140, 30))
	local handle = cuteHead(m, Vector3.new(1.55, 1.5, 1.5), skin)
	local tilt = CFrame.new(0, 0.62, 0) * CFrame.Angles(math.rad(-6), 0, math.rad(8))
	part(m, {
		Name = "HatBrim",
		Shape = CYLINDER,
		Size = Vector3.new(0.12, 2.6, 2.6),
		CFrame = upright(tilt),
		Color = hat,
	})
	part(m, {
		Name = "HatBand",
		Shape = CYLINDER,
		Size = Vector3.new(0.22, 1.5, 1.5),
		CFrame = upright(tilt * CFrame.new(0, 0.14, 0)),
		Color = band,
	})
	part(m, {
		Name = "Buckle",
		Size = Vector3.new(0.26, 0.2, 0.06),
		CFrame = tilt * CFrame.new(0, 0.14, -0.75),
		Color = Color3.fromRGB(255, 215, 80),
		Material = NEON,
	})
	for i = 0, 4 do
		local r = 0.68 * (1 - i / 5) + 0.06
		part(m, {
			Name = "HatCone",
			Shape = CYLINDER,
			Size = Vector3.new(0.4, r * 2, r * 2),
			CFrame = upright(tilt * CFrame.new(i * 0.07, 0.3 + i * 0.36, i * 0.03)),
			Color = hat,
		})
	end
	return handle
end

-- A little bubbling cauldron worn as a hat.
function builders.CauldronHat(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(255, 205, 160))
	local pot = color(style, "HeadColor2", Color3.fromRGB(45, 42, 55))
	local brew = color(style, "GlowColor", Color3.fromRGB(120, 255, 90))
	local handle = cuteHead(m, Vector3.new(1.55, 1.5, 1.5), skin)
	part(m, {
		Name = "Cauldron",
		Shape = BALL,
		Size = Vector3.new(1.45, 1.05, 1.45),
		CFrame = CFrame.new(0, 0.95, 0),
		Color = pot,
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Rim",
		Shape = CYLINDER,
		Size = Vector3.new(0.16, 1.35, 1.35),
		CFrame = upright(CFrame.new(0, 1.35, 0)),
		Color = pot,
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Brew",
		Shape = CYLINDER,
		Size = Vector3.new(0.06, 1.15, 1.15),
		CFrame = upright(CFrame.new(0, 1.4, 0)),
		Color = brew,
		Material = NEON,
	})
	for i, offset in
		{
			Vector3.new(0.22, 1.55, 0.1),
			Vector3.new(-0.2, 1.65, -0.18),
			Vector3.new(0.05, 1.8, 0.2),
		}
	do
		part(m, {
			Name = "Bubble",
			Shape = BALL,
			Size = Vector3.one * (0.26 - i * 0.05),
			CFrame = CFrame.new(offset),
			Color = brew,
			Material = NEON,
		})
	end
	return handle
end

-- A crown of spider legs with a friendly spider sitting on top.
function builders.SpiderCrown(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(200, 190, 230))
	local spider = color(style, "HeadColor2", Color3.fromRGB(35, 30, 45))
	local eyes = color(style, "GlowColor", Color3.fromRGB(255, 80, 80))
	local handle = cuteHead(m, Vector3.new(1.55, 1.5, 1.5), skin)
	part(m, {
		Name = "CrownRing",
		Shape = CYLINDER,
		Size = Vector3.new(0.22, 1.5, 1.5),
		CFrame = upright(CFrame.new(0, 0.58, 0)),
		Color = spider,
	})
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local base = CFrame.new(math.cos(a) * 0.72, 0.62, math.sin(a) * 0.72)
			* CFrame.Angles(0, -a, 0)
		part(m, {
			Name = "Leg",
			Size = Vector3.new(0.07, 0.5, 0.07),
			CFrame = base * CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(-15)),
			Color = spider,
		})
		part(m, {
			Name = "LegTip",
			Size = Vector3.new(0.35, 0.07, 0.07),
			CFrame = base * CFrame.new(0.2, 0.47, 0) * CFrame.Angles(0, 0, math.rad(-35)),
			Color = spider,
		})
	end
	part(m, {
		Name = "Spider",
		Shape = BALL,
		Size = Vector3.new(0.6, 0.48, 0.65),
		CFrame = CFrame.new(0, 0.98, 0.1),
		Color = spider,
	})
	part(m, {
		Name = "SpiderHead",
		Shape = BALL,
		Size = Vector3.one * 0.34,
		CFrame = CFrame.new(0, 0.95, -0.28),
		Color = spider,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "SpiderEye",
			Shape = BALL,
			Size = Vector3.one * 0.1,
			CFrame = CFrame.new(side * 0.07, 0.99, -0.43),
			Color = eyes,
			Material = NEON,
		})
	end
	return handle
end

-- Monsters --------------------------------------------------------------------------------------

-- A flat-top monster head with neck bolts.
function builders.FrankenHead(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(125, 185, 105))
	local hair = color(style, "HeadColor2", Color3.fromRGB(30, 28, 35))
	local size = Vector3.new(1.5, 1.7, 1.45)
	local handle = part(m, { Name = "Handle", Size = size, Color = skin })
	part(m, {
		Name = "Hair",
		Size = Vector3.new(1.56, 0.3, 1.52),
		CFrame = CFrame.new(0, 0.86, 0.02),
		Color = hair,
	})
	for i = -2, 2 do
		part(m, {
			Name = "Fringe",
			Size = Vector3.new(0.3, 0.22, 0.08),
			CFrame = CFrame.new(i * 0.3, 0.66 - (i % 2) * 0.06, -0.74),
			Color = hair,
		})
	end
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Bolt",
			Shape = CYLINDER,
			Size = Vector3.new(0.5, 0.2, 0.2),
			CFrame = CFrame.new(side * 0.82, -0.55, 0.1),
			Color = Color3.fromRGB(150, 150, 160),
			Material = Enum.Material.Metal,
		})
		part(m, {
			Name = "Eye",
			Size = Vector3.new(0.3, 0.26, 0.06),
			CFrame = CFrame.new(side * 0.33, 0.12, -0.74),
			Color = WHITE,
		})
		part(m, {
			Name = "Pupil",
			Size = Vector3.new(0.13, 0.13, 0.04),
			CFrame = CFrame.new(side * 0.33, 0.1, -0.78),
			Color = INK,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.6, 0.07, 0.04),
		CFrame = CFrame.new(0, -0.38, -0.74),
		Color = INK,
	})
	part(m, {
		Name = "Stitch",
		Size = Vector3.new(0.6, 0.05, 0.04),
		CFrame = CFrame.new(-0.2, 0.42, -0.74),
		Color = INK,
	})
	for i = -1, 1 do
		part(m, {
			Name = "Stitch",
			Size = Vector3.new(0.04, 0.16, 0.04),
			CFrame = CFrame.new(-0.2 + i * 0.18, 0.42, -0.75),
			Color = INK,
		})
	end
	local glow = color(style, "GlowColor", Color3.fromRGB(150, 255, 120))
	for _, side in { -1, 1 } do
		part(m, {
			Name = "BoltSpark",
			Shape = BALL,
			Size = Vector3.one * 0.14,
			CFrame = CFrame.new(side * 1.1, -0.55, 0.1),
			Color = glow,
			Material = NEON,
		})
	end
	return handle
end

-- A fluffy werewolf: pointy ears, a snout and glowing eyes.
function builders.WolfHead(m: Model, style: any): BasePart
	local fur = color(style, "HeadColor", Color3.fromRGB(125, 115, 130))
	local light = color(style, "HeadColor2", Color3.fromRGB(215, 205, 210))
	local glow = color(style, "GlowColor", Color3.fromRGB(255, 220, 80))
	local size = Vector3.new(1.7, 1.6, 1.6)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = fur })
	for _, side in { -1, 1 } do
		ear(
			m,
			CFrame.new(side * 0.5, 0.78, 0.1) * CFrame.Angles(0, 0, math.rad(-side * 8)),
			0.62,
			fur,
			light
		)
		ear(
			m,
			CFrame.new(side * 0.78, -0.15, -0.1) * CFrame.Angles(0, math.rad(side * 30), 0),
			0.4,
			fur,
			nil
		)
		local x, y = side * 0.34, 0.22
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.3, 0.26, 0.1),
			CFrame = CFrame.new(x, y, front(size, x, y) + 0.03)
				* CFrame.Angles(0, 0, math.rad(side * -12)),
			Color = glow,
			Material = NEON,
		})
	end
	part(m, {
		Name = "Snout",
		Shape = BALL,
		Size = Vector3.new(0.85, 0.62, 0.8),
		CFrame = CFrame.new(0, -0.25, -0.7),
		Color = light,
	})
	part(m, {
		Name = "Nose",
		Shape = BALL,
		Size = Vector3.new(0.3, 0.2, 0.2),
		CFrame = CFrame.new(0, -0.12, -1.08),
		Color = INK,
	})
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.3, 0.05, 0.05),
		CFrame = CFrame.new(0, -0.42, -1.0),
		Color = INK,
	})
	return handle
end

-- A wise owl: a pale face disc, huge glowing eyes and a little beak.
function builders.OwlHead(m: Model, style: any): BasePart
	local feathers = color(style, "HeadColor", Color3.fromRGB(140, 100, 70))
	local face = color(style, "HeadColor2", Color3.fromRGB(240, 225, 195))
	local glow = color(style, "GlowColor", Color3.fromRGB(255, 200, 50))
	local size = Vector3.new(1.8, 1.6, 1.6)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = feathers })
	part(m, {
		Name = "FaceDisc",
		Shape = BALL,
		Size = Vector3.new(1.45, 1.1, 0.3),
		CFrame = CFrame.new(0, 0.02, -0.68),
		Color = face,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.5, 0.5, 0.16),
			CFrame = CFrame.new(side * 0.33, 0.1, -0.82),
			Color = glow,
			Material = NEON,
		})
		part(m, {
			Name = "Pupil",
			Shape = BALL,
			Size = Vector3.new(0.24, 0.24, 0.08),
			CFrame = CFrame.new(side * 0.33, 0.1, -0.9),
			Color = INK,
		})
		part(m, {
			Name = "EarTuft",
			Size = Vector3.new(0.3, 0.55, 0.12),
			CFrame = CFrame.new(side * 0.55, 0.72, -0.05)
				* CFrame.Angles(0, 0, math.rad(-side * 30)),
			Color = darker(feathers, 0.2),
		})
	end
	part(m, {
		Name = "Beak",
		Size = Vector3.new(0.2, 0.2, 0.12),
		CFrame = CFrame.new(0, -0.18, -0.85) * CFrame.Angles(0, 0, math.rad(45)),
		Color = Color3.fromRGB(255, 170, 40),
	})
	return handle
end

-- A potion bottle with bubbling, glowing brew inside.
function builders.PotionHead(m: Model, style: any): BasePart
	local glass = color(style, "HeadColor", Color3.fromRGB(200, 230, 255))
	local label = color(style, "HeadColor2", Color3.fromRGB(240, 220, 170))
	local brew = color(style, "GlowColor", Color3.fromRGB(190, 90, 255))
	local size = Vector3.new(1.65, 1.55, 1.65)
	part(m, {
		Name = "Brew",
		Shape = BALL,
		Size = Vector3.new(1.45, 1.05, 1.45),
		CFrame = CFrame.new(0, -0.18, 0),
		Color = brew,
		Material = NEON,
	})
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		Color = glass,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	part(m, {
		Name = "Neck",
		Shape = CYLINDER,
		Size = Vector3.new(0.55, 0.6, 0.6),
		CFrame = upright(CFrame.new(0, 0.95, 0)),
		Color = glass,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	part(m, {
		Name = "Cork",
		Shape = CYLINDER,
		Size = Vector3.new(0.38, 0.56, 0.56),
		CFrame = upright(CFrame.new(0, 1.35, 0)),
		Color = Color3.fromRGB(160, 110, 70),
		Material = Enum.Material.Wood,
	})
	part(m, {
		Name = "Label",
		Size = Vector3.new(0.85, 0.42, 0.05),
		CFrame = CFrame.new(0, -0.3, front(size, 0, -0.3) - 0.01),
		Color = label,
	})
	for i, offset in
		{ Vector3.new(0.25, 0.35, -0.1), Vector3.new(-0.2, 0.5, 0.15), Vector3.new(0.05, 0.62, 0) }
	do
		part(m, {
			Name = "Bubble",
			Shape = BALL,
			Size = Vector3.one * (0.22 - i * 0.04),
			CFrame = CFrame.new(offset),
			Color = brew,
			Material = NEON,
		})
	end
	cuteEyes(m, Vector3.zero, size, 0.18, 0.32, 0.24, INK)
	return handle
end

-- A toadstool: a big spotty cap over a friendly face.
function builders.ToadstoolHead(m: Model, style: any): BasePart
	local cap = color(style, "HeadColor", Color3.fromRGB(220, 50, 60))
	local stem = color(style, "HeadColor2", Color3.fromRGB(245, 235, 215))
	local size = Vector3.new(1.45, 1.4, 1.4)
	local centre = Vector3.new(0, -0.2, 0)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(centre),
		Color = stem,
	})
	part(m, {
		Name = "Cap",
		Shape = BALL,
		Size = Vector3.new(2.6, 1.35, 2.6),
		CFrame = CFrame.new(0, 0.6, 0),
		Color = cap,
	})
	part(m, {
		Name = "Gills",
		Shape = CYLINDER,
		Size = Vector3.new(0.08, 2.3, 2.3),
		CFrame = upright(CFrame.new(0, 0.28, 0)),
		Color = lighter(stem, 0.1),
	})
	local spots = color(style, "GlowColor", WHITE)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.5
		local r = if i % 2 == 0 then 0.75 else 0.45
		local y = 0.6 + 0.67 * math.sqrt(math.max(0, 1 - (r / 1.3) ^ 2))
		part(m, {
			Name = "Spot",
			Shape = BALL,
			Size = Vector3.new(0.36, 0.12, 0.36),
			CFrame = CFrame.new(math.cos(a) * r, y - 0.02, math.sin(a) * r),
			Color = spots,
		})
	end
	cuteEyes(m, centre, size, -0.02, 0.27, 0.24, INK)
	smile(m, centre, size, -0.32, 0.36, INK)
	cheeks(m, centre, size, -0.2, 0.42)
	return handle
end

-- Graveyard and moonlight ------------------------------------------------------------------------

-- A round full moon with craters, a sleepy smile and a nightcap.
function builders.MoonHead(m: Model, style: any): BasePart
	local moon = color(style, "HeadColor", Color3.fromRGB(250, 238, 180))
	local cap = color(style, "HeadColor2", Color3.fromRGB(60, 70, 150))
	local size = Vector3.one * 1.9
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		Color = moon,
		Material = Enum.Material.SmoothPlastic,
	})
	for _, c in
		{ { -0.55, 0.45, 0.32 }, { 0.6, -0.35, 0.26 }, { 0.3, 0.65, 0.2 }, { -0.62, -0.42, 0.18 } }
	do
		local x, y, d = c[1], c[2], c[3]
		part(m, {
			Name = "Crater",
			Shape = BALL,
			Size = Vector3.new(d, d, 0.08),
			CFrame = CFrame.new(x, y, front(size, x, y) + 0.02),
			Color = darker(moon, 0.18),
		})
	end
	for _, side in { -1, 1 } do
		local x, y = side * 0.33, 0.08
		part(m, {
			Name = "SleepyEye",
			Size = Vector3.new(0.3, 0.07, 0.06),
			CFrame = CFrame.new(x, y, front(size, x, y) + 0.01)
				* CFrame.Angles(0, 0, math.rad(side * -10)),
			Color = INK,
		})
	end
	smile(m, Vector3.zero, size, -0.32, 0.4, INK)
	cheeks(m, Vector3.zero, size, -0.15, 0.55)
	local base = CFrame.new(0.05, 0.7, 0.05) * CFrame.Angles(math.rad(-10), 0, math.rad(-14))
	for i = 0, 4 do
		local r = 0.8 * (1 - i / 5) + 0.08
		part(m, {
			Name = "Nightcap",
			Shape = CYLINDER,
			Size = Vector3.new(0.38, r * 2, r * 2),
			CFrame = upright(base * CFrame.new(i * 0.1, i * 0.3, 0)),
			Color = cap,
		})
	end
	part(m, {
		Name = "CapTrim",
		Shape = CYLINDER,
		Size = Vector3.new(0.22, 1.85, 1.85),
		CFrame = upright(base * CFrame.new(0, -0.08, 0)),
		Color = WHITE,
	})
	part(m, {
		Name = "Pompom",
		Shape = BALL,
		Size = Vector3.one * 0.38,
		CFrame = base * CFrame.new(0.62, 1.4, 0),
		Color = WHITE,
	})
	return handle
end

-- An old lantern with a warm light (and a shy face) inside.
function builders.LanternHead(m: Model, style: any): BasePart
	local iron = color(style, "HeadColor", Color3.fromRGB(45, 40, 50))
	local light = color(style, "GlowColor", Color3.fromRGB(255, 200, 90))
	part(m, {
		Name = "Light",
		Shape = BALL,
		Size = Vector3.new(0.8, 1.0, 0.8),
		CFrame = CFrame.new(0, 0, 0.1),
		Color = light,
		Material = NEON,
	})
	local handle = part(m, {
		Name = "Handle",
		Size = Vector3.new(1.3, 1.4, 1.3),
		Color = lighter(light, 0.4),
		Material = Enum.Material.Glass,
		Transparency = 0.5,
	})
	for _, y in { 0.78, -0.78 } do
		part(m, {
			Name = "Frame",
			Size = Vector3.new(1.5, 0.18, 1.5),
			CFrame = CFrame.new(0, y, 0),
			Color = iron,
			Material = Enum.Material.Metal,
		})
	end
	for _, x in { -0.68, 0.68 } do
		for _, z in { -0.68, 0.68 } do
			part(m, {
				Name = "Post",
				Size = Vector3.new(0.12, 1.4, 0.12),
				CFrame = CFrame.new(x, 0, z),
				Color = iron,
				Material = Enum.Material.Metal,
			})
		end
	end
	part(m, {
		Name = "Roof",
		Shape = CYLINDER,
		Size = Vector3.new(0.4, 1.1, 1.1),
		CFrame = upright(CFrame.new(0, 1.05, 0)),
		Color = iron,
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Roof",
		Shape = CYLINDER,
		Size = Vector3.new(0.25, 0.55, 0.55),
		CFrame = upright(CFrame.new(0, 1.35, 0)),
		Color = iron,
		Material = Enum.Material.Metal,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Ring",
			Size = Vector3.new(0.1, 0.5, 0.1),
			CFrame = CFrame.new(side * 0.18, 1.62, 0) * CFrame.Angles(0, 0, math.rad(side * -35)),
			Color = iron,
			Material = Enum.Material.Metal,
		})
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.18, 0.24, 0.06),
			CFrame = CFrame.new(side * 0.22, 0.12, -0.67),
			Color = INK,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.26, 0.06, 0.04),
		CFrame = CFrame.new(0, -0.15, -0.67),
		Color = INK,
	})
	return handle
end

-- A little tombstone with a mossy top and a sleepy ghost face.
function builders.TombstoneHead(m: Model, style: any): BasePart
	local stone = color(style, "HeadColor", Color3.fromRGB(150, 150, 165))
	local moss = color(style, "HeadColor2", Color3.fromRGB(110, 170, 80))
	local glow = color(style, "GlowColor", Color3.fromRGB(150, 255, 220))
	local handle = part(m, {
		Name = "Handle",
		Size = Vector3.new(1.6, 1.3, 0.75),
		CFrame = CFrame.new(0, -0.2, 0),
		Color = stone,
		Material = Enum.Material.Slate,
	})
	part(m, {
		Name = "Top",
		Shape = CYLINDER,
		Size = Vector3.new(0.75, 1.6, 1.6),
		CFrame = facing(CFrame.new(0, 0.45, 0)),
		Color = stone,
		Material = Enum.Material.Slate,
	})
	part(m, {
		Name = "Base",
		Size = Vector3.new(1.85, 0.3, 1.0),
		CFrame = CFrame.new(0, -0.9, 0),
		Color = darker(stone, 0.15),
		Material = Enum.Material.Slate,
	})
	for i = 1, 4 do
		local a = math.rad(25 + i * 30)
		part(m, {
			Name = "Moss",
			Shape = BALL,
			Size = Vector3.new(0.45, 0.2, 0.85),
			CFrame = CFrame.new(math.cos(a) * 0.78, 0.45 + math.sin(a) * 0.78, 0),
			Color = moss,
		})
	end
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.22, 0.3, 0.06),
			CFrame = CFrame.new(side * 0.3, 0.15, -0.39),
			Color = glow,
			Material = NEON,
		})
	end
	part(m, {
		Name = "Mouth",
		Shape = BALL,
		Size = Vector3.new(0.2, 0.16, 0.06),
		CFrame = CFrame.new(0, -0.2, -0.39),
		Color = glow,
		Material = NEON,
	})
	part(m, {
		Name = "Crack",
		Size = Vector3.new(0.04, 0.4, 0.04),
		CFrame = CFrame.new(0.55, -0.45, -0.39) * CFrame.Angles(0, 0, math.rad(20)),
		Color = darker(stone, 0.4),
	})
	return handle
end

-- More heads ---------------------------------------------------------------------------------------

-- A very proper pumpkin: top hat, monocle and a curly moustache.
function builders.GentlemanGourd(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(255, 130, 20))
	local hat = color(style, "HeadColor2", Color3.fromRGB(35, 28, 45))
	local glow = color(style, "GlowColor", Color3.fromRGB(255, 220, 90))
	local size = Vector3.new(2.4, 2.0, 2.4)
	local handle = pumpkin(m, size, skin)
	local face = if type(style.Face) == "string" then style.Face else "Happy"
	carvedFace(m, Vector3.zero, size, face, glow, skin)
	local tilt = CFrame.new(0.15, 0.95, 0.05) * CFrame.Angles(math.rad(-6), 0, math.rad(-8))
	part(m, {
		Name = "HatBrim",
		Shape = CYLINDER,
		Size = Vector3.new(0.1, 1.8, 1.8),
		CFrame = upright(tilt),
		Color = hat,
	})
	part(m, {
		Name = "HatTop",
		Shape = CYLINDER,
		Size = Vector3.new(1.15, 1.2, 1.2),
		CFrame = upright(tilt * CFrame.new(0, 0.6, 0)),
		Color = hat,
	})
	part(m, {
		Name = "HatBand",
		Shape = CYLINDER,
		Size = Vector3.new(0.22, 1.24, 1.24),
		CFrame = upright(tilt * CFrame.new(0, 0.18, 0)),
		Color = color(style, "HeadColor3", Color3.fromRGB(150, 60, 200)),
	})
	local gold = Color3.fromRGB(255, 210, 80)
	local ex, ey = 0.42, 0.25
	local monocle = CFrame.new(ex, ey, front(size, ex, ey) - 0.06)
	part(m, {
		Name = "Monocle",
		Shape = CYLINDER,
		Size = Vector3.new(0.05, 0.62, 0.62),
		CFrame = facing(monocle),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	part(m, {
		Name = "MonocleGlass",
		Shape = CYLINDER,
		Size = Vector3.new(0.06, 0.5, 0.5),
		CFrame = facing(monocle * CFrame.new(0, 0, -0.01)),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.5,
	})
	part(m, {
		Name = "MonocleChain",
		Size = Vector3.new(0.04, 0.7, 0.04),
		CFrame = monocle * CFrame.new(0.28, -0.4, 0.05) * CFrame.Angles(0, 0, math.rad(20)),
		Color = gold,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Moustache",
			Shape = BALL,
			Size = Vector3.new(0.5, 0.18, 0.12),
			CFrame = CFrame.new(side * 0.24, -0.12, front(size, side * 0.24, -0.12) - 0.04)
				* CFrame.Angles(0, 0, math.rad(side * -15)),
			Color = Color3.fromRGB(60, 40, 30),
		})
		part(m, {
			Name = "MoustacheCurl",
			Shape = BALL,
			Size = Vector3.new(0.16, 0.16, 0.1),
			CFrame = CFrame.new(side * 0.5, -0.02, front(size, side * 0.5, -0.02) - 0.04),
			Color = Color3.fromRGB(60, 40, 30),
		})
	end
	return handle
end

-- A candy corn: yellow, orange and a white tip, with a sweet face.
function builders.CandyCornHead(m: Model, style: any): BasePart
	local base = color(style, "HeadColor", Color3.fromRGB(255, 205, 40))
	local middle = color(style, "HeadColor2", Color3.fromRGB(255, 130, 20))
	local tip = color(style, "GlowColor", Color3.fromRGB(255, 250, 240))
	local size = Vector3.new(1.95, 1.05, 1.95)
	local centre = Vector3.new(0, -0.35, 0)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(centre),
		Color = base,
	})
	part(m, {
		Name = "Middle",
		Shape = BALL,
		Size = Vector3.new(1.5, 0.85, 1.5),
		CFrame = CFrame.new(0, 0.3, 0),
		Color = middle,
	})
	part(m, {
		Name = "Tip",
		Shape = BALL,
		Size = Vector3.new(0.95, 0.95, 0.95),
		CFrame = CFrame.new(0, 0.85, 0),
		Color = tip,
	})
	cuteEyes(m, centre, size, 0.08, 0.34, 0.26, INK)
	smile(m, centre, size, -0.22, 0.42, INK)
	cheeks(m, centre, size, -0.12, 0.58)
	return handle
end

-- A wobbly jelly blob with drips and big happy eyes.
function builders.BlobHead(m: Model, style: any): BasePart
	local jelly = color(style, "HeadColor", Color3.fromRGB(120, 230, 120))
	local size = Vector3.new(2.0, 1.65, 1.9)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		Color = jelly,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	part(m, {
		Name = "Inside",
		Shape = BALL,
		Size = size * 0.75,
		Color = darker(jelly, 0.15),
		Transparency = 0.3,
	})
	for i, spec in { { -0.6, 0.45 }, { 0.15, 0.6 }, { 0.65, 0.35 } } do
		local x, long = spec[1], spec[2]
		part(m, {
			Name = "Drip",
			Shape = BALL,
			Size = Vector3.new(0.3, long, 0.3),
			CFrame = CFrame.new(x, -0.62 - long / 2 + 0.15, -0.35 + i * 0.1),
			Color = jelly,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
	cuteEyes(m, Vector3.zero, size, 0.12, 0.4, 0.34, INK)
	smile(m, Vector3.zero, size, -0.28, 0.5, INK)
	part(m, {
		Name = "Shine",
		Shape = BALL,
		Size = Vector3.new(0.4, 0.2, 0.1),
		CFrame = CFrame.new(-0.5, 0.55, front(size, -0.5, 0.55) + 0.02)
			* CFrame.Angles(0, 0, math.rad(25)),
		Color = WHITE,
		Material = NEON,
		Transparency = 0.3,
	})
	return handle
end

-- A fluffy monster: fur tufts, two horns, one big eye and a toothy grin.
function builders.FuzzyHead(m: Model, style: any): BasePart
	local fur = color(style, "HeadColor", Color3.fromRGB(110, 90, 200))
	local horn = color(style, "HeadColor2", Color3.fromRGB(250, 235, 200))
	local eyeColor = color(style, "GlowColor", Color3.fromRGB(120, 220, 255))
	local size = Vector3.one * 1.85
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = fur })
	for i = 1, 14 do
		local a = i * 2.39996
		local y = -0.75 + (i % 7) * 0.24
		local r = math.sqrt(math.max(0.05, 1 - (y / 0.92) ^ 2)) * 0.9
		part(m, {
			Name = "Tuft",
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = CFrame.new(math.cos(a) * r, y, math.sin(a) * r * 0.9 + 0.08)
				* CFrame.Angles(a, a * 0.7, math.rad(45)),
			Color = if i % 2 == 0 then darker(fur, 0.12) else lighter(fur, 0.1),
		})
	end
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local r = 0.22 * (1 - i / 4) + 0.04
			part(m, {
				Name = "Horn",
				Shape = CYLINDER,
				Size = Vector3.new(0.24, r * 2, r * 2),
				CFrame = upright(
					CFrame.new(side * (0.55 + i * 0.08), 0.75 + i * 0.18, 0.05)
						* CFrame.Angles(0, 0, math.rad(-side * 25))
				),
				Color = horn,
			})
		end
	end
	local ey = 0.2
	local ez = front(size, 0, ey)
	part(m, {
		Name = "Eye",
		Shape = BALL,
		Size = Vector3.new(0.75, 0.75, 0.24),
		CFrame = CFrame.new(0, ey, ez + 0.05),
		Color = WHITE,
	})
	part(m, {
		Name = "Iris",
		Shape = BALL,
		Size = Vector3.new(0.42, 0.42, 0.1),
		CFrame = CFrame.new(0, ey, ez - 0.06),
		Color = eyeColor,
	})
	part(m, {
		Name = "Pupil",
		Shape = BALL,
		Size = Vector3.new(0.2, 0.2, 0.06),
		CFrame = CFrame.new(0, ey, ez - 0.1),
		Color = INK,
	})
	part(m, {
		Name = "Mouth",
		Shape = BALL,
		Size = Vector3.new(0.9, 0.35, 0.14),
		CFrame = CFrame.new(0, -0.38, front(size, 0, -0.38) + 0.04),
		Color = INK,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Tooth",
			Size = Vector3.new(0.14, 0.16, 0.06),
			CFrame = CFrame.new(side * 0.2, -0.27, front(size, side * 0.2, -0.27) - 0.02),
			Color = WHITE,
		})
	end
	return handle
end

-- A bright five-pointed star with a sleepy smile.
function builders.StarHead(m: Model, style: any): BasePart
	local gold = color(style, "HeadColor", Color3.fromRGB(255, 220, 70))
	local size = Vector3.new(1.4, 1.4, 0.9)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = gold })
	for i = 0, 4 do
		local a = math.rad(90 + i * 72)
		part(m, {
			Name = "Point",
			Size = Vector3.new(0.5, 0.5, 0.55),
			CFrame = CFrame.new(math.cos(a) * 0.82, math.sin(a) * 0.82, 0)
				* CFrame.Angles(0, 0, a - math.rad(90))
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = gold,
		})
	end
	for _, side in { -1, 1 } do
		part(m, {
			Name = "SleepyEye",
			Size = Vector3.new(0.22, 0.06, 0.05),
			CFrame = CFrame.new(side * 0.22, 0.1, front(size, side * 0.22, 0.1) + 0.01),
			Color = INK,
		})
	end
	smile(m, Vector3.zero, size, -0.18, 0.32, INK)
	cheeks(m, Vector3.zero, size, -0.06, 0.38)
	local sparkle = color(style, "GlowColor", WHITE)
	for i, at in { Vector3.new(0.75, 0.7, -0.2), Vector3.new(-0.8, -0.55, -0.1) } do
		star(m, CFrame.new(at), 0.3 - i * 0.05, sparkle, "Sparkle")
	end
	return handle
end

-- A fluffy moth: feathery antennae, big shiny eyes and a fuzzy collar.
function builders.MothHead(m: Model, style: any): BasePart
	local fluff = color(style, "HeadColor", Color3.fromRGB(235, 225, 250))
	local trim = color(style, "HeadColor2", Color3.fromRGB(170, 150, 230))
	local eyeColor = color(style, "GlowColor", Color3.fromRGB(40, 30, 70))
	local size = Vector3.new(1.65, 1.55, 1.55)
	local handle = part(m, { Name = "Handle", Shape = BALL, Size = size, Color = fluff })
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		part(m, {
			Name = "Ruff",
			Shape = BALL,
			Size = Vector3.new(0.6, 0.45, 0.6),
			CFrame = CFrame.new(math.cos(a) * 0.72, -0.68, math.sin(a) * 0.72),
			Color = if i % 2 == 0 then fluff else trim,
		})
	end
	for _, side in { -1, 1 } do
		local x, y = side * 0.42, 0.05
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.52, 0.62, 0.3),
			CFrame = CFrame.new(x, y, front(size, x, y) + 0.1),
			Color = eyeColor,
		})
		part(m, {
			Name = "EyeShine",
			Shape = BALL,
			Size = Vector3.one * 0.15,
			CFrame = CFrame.new(x + side * -0.08, y + 0.14, front(size, x, y) - 0.05),
			Color = WHITE,
			Material = NEON,
		})
		local base = CFrame.new(side * 0.3, 0.7, -0.1)
			* CFrame.Angles(math.rad(-20), 0, math.rad(-side * 25))
		part(m, {
			Name = "Antenna",
			Size = Vector3.new(0.06, 0.9, 0.06),
			CFrame = base * CFrame.new(0, 0.45, 0),
			Color = trim,
		})
		for i = 1, 4 do
			part(m, {
				Name = "Feather",
				Size = Vector3.new(0.34 - i * 0.04, 0.05, 0.04),
				CFrame = base
					* CFrame.new(side * 0.12, 0.2 + i * 0.17, 0)
					* CFrame.Angles(0, 0, math.rad(side * 30)),
				Color = trim,
			})
		end
	end
	smile(m, Vector3.zero, size, -0.3, 0.3, INK)
	return handle
end

-- CRAZY heads (one per crate, never reused) ---------------------------------------------------

-- Pumpkin Crate: a huge toothy pumpkin with a crown of tiny pumpkins and rainbow gems.
function builders.MegaGourd(m: Model, style: any): BasePart
	local skin = color(style, "HeadColor", Color3.fromRGB(255, 120, 10))
	local glow = color(style, "GlowColor", Color3.fromRGB(255, 240, 120))
	local size = Vector3.new(2.9, 2.35, 2.9)
	local handle = pumpkin(m, size, skin)
	carvedFace(m, Vector3.zero, size, "Toothy", glow, skin)
	local gold = Color3.fromRGB(255, 205, 60)
	part(m, {
		Name = "Crown",
		Shape = CYLINDER,
		Size = Vector3.new(0.35, 1.9, 1.9),
		CFrame = upright(CFrame.new(0, 1.15, 0)),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + math.pi / 2
		pumpkin(
			m,
			Vector3.new(0.75, 0.62, 0.75),
			skin,
			Vector3.new(math.cos(a) * 0.55, 1.62, math.sin(a) * 0.55),
			"MiniPumpkin"
		)
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		rainbow(part(m, {
			Name = "Gem",
			Size = Vector3.one * 0.24,
			CFrame = CFrame.new(math.cos(a) * 0.97, 1.15, math.sin(a) * 0.97)
				* CFrame.Angles(0, -a, math.rad(45)),
			Color = Color3.fromHSV(i / 8, 0.7, 1),
			Material = NEON,
		}))
	end
	for _, side in { -1, 1 } do
		for i = 1, 3 do
			part(m, {
				Name = "Vine",
				Size = Vector3.new(0.08, 0.5, 0.08),
				CFrame = CFrame.new(side * (1.15 + i * 0.12), 0.6 + i * 0.28, 0.2)
					* CFrame.Angles(0, 0, math.rad(side * (20 + i * 25))),
				Color = STEM,
			})
		end
	end
	return handle
end

-- Candy Crate: a giant rainbow swirl lollipop with a wrapper bow.
function builders.SugarStorm(m: Model, style: any): BasePart
	local base = color(style, "HeadColor", WHITE)
	local bow = color(style, "HeadColor2", Color3.fromRGB(255, 120, 200))
	local handle = part(m, {
		Name = "Handle",
		Shape = CYLINDER,
		Size = Vector3.new(0.45, 2.5, 2.5),
		CFrame = facing(CFrame.new(0, 0.15, 0)),
		Color = base,
	})
	for i = 1, 5 do
		local d = 2.35 - i * 0.4
		rainbow(part(m, {
			Name = "Swirl",
			Shape = CYLINDER,
			Size = Vector3.new(0.47 + i * 0.01, d, d),
			CFrame = facing(CFrame.new(0, 0.15, -0.005 * i)),
			Color = if i % 2 == 1 then Color3.fromHSV(i / 5, 0.7, 1) else base,
			Material = if i % 2 == 1 then NEON else Enum.Material.SmoothPlastic,
		}))
	end
	for _, side in { -1, 1 } do
		for i, tilt in { -25, 25 } do
			part(m, {
				Name = "Bow",
				Size = Vector3.new(0.7, 0.45, 0.1),
				CFrame = CFrame.new(side * 0.42, 1.55, 0.05)
					* CFrame.Angles(0, 0, math.rad(side * (tilt + 10 * i))),
				Color = bow,
			})
		end
	end
	part(m, {
		Name = "Knot",
		Shape = BALL,
		Size = Vector3.one * 0.3,
		CFrame = CFrame.new(0, 1.5, 0.02),
		Color = bow,
	})
	local face = Vector3.new(2.5, 2.5, 0.48)
	cuteEyes(m, Vector3.new(0, 0.15, 0), face, 0.15, 0.4, 0.3, INK)
	smile(m, Vector3.new(0, 0.15, 0), face, -0.3, 0.5, INK)
	return handle
end

-- Spooky Crate: a glowing ghost king with a crown and a rainbow halo.
function builders.PhantomKing(m: Model, style: any): BasePart
	local handle = builders.GhostSheet(m, style)
	-- a see-through sheet that glows from the inside
	for _, child in m:GetChildren() do
		if
			(child == handle or child.Name == "Sheet" or child.Name == "Hem")
			and child:IsA("BasePart")
		then
			child.Material = Enum.Material.Glass
			child.Transparency = 0.2
		end
	end
	part(m, {
		Name = "Core",
		Shape = BALL,
		Size = Vector3.new(1.3, 1.5, 1.3),
		CFrame = CFrame.new(0, -0.05, 0.15),
		Color = color(style, "HeadColor", WHITE),
		Material = NEON,
		Transparency = 0.75,
	})
	local gold = Color3.fromRGB(255, 210, 70)
	part(m, {
		Name = "Crown",
		Shape = CYLINDER,
		Size = Vector3.new(0.3, 1.1, 1.1),
		CFrame = upright(CFrame.new(0, 1.2, 0)),
		Color = gold,
		Material = Enum.Material.Foil,
	})
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(m, {
			Name = "CrownSpike",
			Size = Vector3.new(0.22, 0.42, 0.22),
			CFrame = CFrame.new(math.cos(a) * 0.45, 1.45, math.sin(a) * 0.45)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = gold,
			Material = Enum.Material.Foil,
		})
		rainbow(part(m, {
			Name = "Gem",
			Shape = BALL,
			Size = Vector3.one * 0.16,
			CFrame = CFrame.new(math.cos(a) * 0.56, 1.2, math.sin(a) * 0.56),
			Color = Color3.fromHSV(i / 5, 0.7, 1),
			Material = NEON,
		}))
	end
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		rainbow(part(m, {
			Name = "Halo",
			Size = Vector3.new(0.34, 0.1, 0.16),
			CFrame = CFrame.new(math.cos(a) * 0.85, 1.95, math.sin(a) * 0.85)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromHSV(i / 12, 0.7, 1),
			Material = NEON,
		}))
	end
	return handle
end

-- Graveyard Crate: a superstar skull with rainbow star eyes and a shiny top hat.
function builders.StarSkull(m: Model, style: any): BasePart
	local bone = color(style, "HeadColor", Color3.fromRGB(245, 240, 225))
	local hat = color(style, "HeadColor2", Color3.fromRGB(30, 25, 40))
	local size = Vector3.new(1.75, 1.65, 1.75)
	local centre = Vector3.new(0, 0.1, 0)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(centre),
		Color = bone,
	})
	part(m, {
		Name = "Jaw",
		Size = Vector3.new(1.05, 0.42, 0.92),
		CFrame = CFrame.new(0, -0.66, -0.25),
		Color = bone,
	})
	for _, side in { -1, 1 } do
		local x, y = side * 0.34, 0.18
		local at = CFrame.new(centre + Vector3.new(x, y, front(size, x, y) - 0.02))
		part(m, {
			Name = "EyeHole",
			Shape = BALL,
			Size = Vector3.new(0.5, 0.5, 0.16),
			CFrame = at,
			Color = INK,
		})
		rainbow(
			star(
				m,
				at * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, math.rad(45)),
				0.5,
				Color3.fromHSV(if side < 0 then 0.1 else 0.6, 0.7, 1),
				"StarEye"
			)
		)
	end
	for i = -2, 2 do
		part(m, {
			Name = "Tooth",
			Size = Vector3.new(0.13, 0.15, 0.06),
			CFrame = CFrame.new(i * 0.16, -0.62, -0.72),
			Color = WHITE,
		})
	end
	part(m, {
		Name = "HatBrim",
		Shape = CYLINDER,
		Size = Vector3.new(0.12, 2.1, 2.1),
		CFrame = upright(CFrame.new(0, 0.85, 0)) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = hat,
	})
	part(m, {
		Name = "HatTop",
		Shape = CYLINDER,
		Size = Vector3.new(1.1, 1.25, 1.25),
		CFrame = upright(CFrame.new(0, 1.45, 0.04)),
		Color = hat,
		Material = Enum.Material.Foil,
	})
	rainbow(part(m, {
		Name = "HatBand",
		Shape = CYLINDER,
		Size = Vector3.new(0.24, 1.3, 1.3),
		CFrame = upright(CFrame.new(0, 1.05, 0.04)),
		Color = Color3.fromHSV(0.85, 0.7, 1),
		Material = NEON,
	}))
	return handle
end

-- Monster Crate: a wobbly slime monster with three eyes on stalks.
function builders.GloopMonster(m: Model, style: any): BasePart
	local slime = color(style, "HeadColor", Color3.fromRGB(110, 240, 120))
	local size = Vector3.new(2.3, 1.9, 2.2)
	local handle = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = size,
		CFrame = CFrame.new(0, -0.05, 0),
		Color = slime,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	part(m, {
		Name = "Core",
		Shape = BALL,
		Size = size * 0.7,
		CFrame = CFrame.new(0, -0.05, 0.1),
		Color = darker(slime, 0.2),
		Material = NEON,
		Transparency = 0.4,
	})
	for i, spec in { { -0.6, 1.3, -20 }, { 0, 1.55, 0 }, { 0.6, 1.3, 20 } } do
		local x, y, tilt = spec[1], spec[2], spec[3]
		part(m, {
			Name = "Stalk",
			Size = Vector3.new(0.14, 0.75, 0.14),
			CFrame = CFrame.new(x * 0.7, y - 0.45, -0.1) * CFrame.Angles(0, 0, math.rad(-tilt)),
			Color = slime,
		})
		part(m, {
			Name = "Eyeball",
			Shape = BALL,
			Size = Vector3.one * (if i == 2 then 0.62 else 0.48),
			CFrame = CFrame.new(x, y, -0.15),
			Color = WHITE,
		})
		part(m, {
			Name = "Pupil",
			Shape = BALL,
			Size = Vector3.new(0.22, 0.22, 0.08),
			CFrame = CFrame.new(x, y, -0.15 - (if i == 2 then 0.3 else 0.23)),
			Color = INK,
		})
	end
	part(m, {
		Name = "Mouth",
		Shape = BALL,
		Size = Vector3.new(1.0, 0.45, 0.2),
		CFrame = CFrame.new(0, -0.25, -1.0),
		Color = INK,
	})
	part(m, {
		Name = "Tongue",
		Shape = BALL,
		Size = Vector3.new(0.45, 0.22, 0.12),
		CFrame = CFrame.new(0.1, -0.38, -1.08),
		Color = Color3.fromRGB(255, 120, 160),
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		rainbow(part(m, {
			Name = "Spot",
			Shape = BALL,
			Size = Vector3.new(0.3, 0.3, 0.1),
			CFrame = CFrame.new(
				math.cos(a) * 1.1,
				-0.05 + math.sin(a) * 0.55,
				0.2 + math.sin(a * 2) * 0.3
			) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromHSV(i / 6, 0.7, 1),
			Material = NEON,
		}))
	end
	return handle
end

-- Moonlight Crate: the moon itself, crowned with stars and a crescent moon above.
function builders.MoonCrown(m: Model, style: any): BasePart
	local handle = builders.MoonHead(m, style)
	for _, child in m:GetChildren() do
		if child.Name == "Nightcap" or child.Name == "CapTrim" or child.Name == "Pompom" then
			child:Destroy()
		end
	end
	-- a ring of little lights behind the moon
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		part(m, {
			Name = "MoonGlow",
			Shape = BALL,
			Size = Vector3.one * 0.18,
			CFrame = CFrame.new(math.cos(a) * 1.25, math.sin(a) * 1.25, 0.35),
			Color = color(style, "GlowColor", Color3.fromRGB(255, 240, 150)),
			Material = NEON,
		})
	end
	local glow = color(style, "GlowColor", Color3.fromRGB(255, 240, 150))
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		rainbow(
			star(
				m,
				CFrame.new(math.cos(a) * 0.72, 1.0 + (i % 2) * 0.15, math.sin(a) * 0.72)
					* CFrame.Angles(0, -a + math.pi / 2, math.rad(45)),
				0.42,
				Color3.fromHSV(i / 7, 0.6, 1),
				"CrownStar"
			)
		)
	end
	-- a crescent: balls shrinking along an arc
	for i = -4, 4 do
		local a = math.rad(i * 17)
		local s = 0.42 * (1 - math.abs(i) / 6)
		part(m, {
			Name = "Crescent",
			Shape = BALL,
			Size = Vector3.one * s,
			CFrame = CFrame.new(math.sin(a) * 0.75, 2.0 + math.cos(a) * 0.4 - 0.4, 0.1),
			Color = glow,
			Material = NEON,
		})
	end
	return handle
end

-- Orbiting pieces (CRAZY skins) -----------------------------------------------------------------

local ORBIT_KINDS = { "Pumpkins", "Candies", "Ghosts", "Bones", "Eyes", "Stars", "Bats" }
HeadPieces.OrbitKinds = ORBIT_KINDS

local orbits: { [string]: (Model, Color3?) -> BasePart } = {}

function orbits.Pumpkins(m: Model, c: Color3?): BasePart
	local body = pumpkin(m, Vector3.new(0.7, 0.58, 0.7), c or Color3.fromRGB(255, 130, 20))
	part(m, {
		Name = "Face",
		Size = Vector3.new(0.3, 0.08, 0.04),
		CFrame = CFrame.new(0, -0.08, -0.34),
		Color = Color3.fromRGB(255, 230, 120),
		Material = NEON,
	})
	return body
end

function orbits.Candies(m: Model, c: Color3?): BasePart
	local tint = c or Color3.fromRGB(255, 90, 170)
	local body = part(
		m,
		{ Name = "Handle", Shape = BALL, Size = Vector3.new(0.6, 0.42, 0.42), Color = tint }
	)
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Wrapper",
			Size = Vector3.new(0.25, 0.4, 0.06),
			CFrame = CFrame.new(side * 0.4, 0, 0),
			Color = WHITE,
		})
	end
	return body
end

function orbits.Ghosts(m: Model, c: Color3?): BasePart
	local tint = c or Color3.fromRGB(240, 245, 255)
	local body = part(m, {
		Name = "Handle",
		Shape = BALL,
		Size = Vector3.one * 0.6,
		Color = tint,
		Material = NEON,
		Transparency = 0.2,
	})
	part(m, {
		Name = "Tail",
		Shape = BALL,
		Size = Vector3.new(0.4, 0.5, 0.4),
		CFrame = CFrame.new(0, -0.35, 0.08),
		Color = tint,
		Material = NEON,
		Transparency = 0.3,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(0.09, 0.13, 0.05),
			CFrame = CFrame.new(side * 0.1, 0.05, -0.29),
			Color = INK,
		})
	end
	return body
end

function orbits.Bones(m: Model, c: Color3?): BasePart
	local tint = c or Color3.fromRGB(245, 240, 225)
	local body = part(m, { Name = "Handle", Size = Vector3.new(0.7, 0.13, 0.13), Color = tint })
	for _, x in { -0.35, 0.35 } do
		for _, y in { -0.07, 0.07 } do
			part(m, {
				Name = "Knob",
				Shape = BALL,
				Size = Vector3.one * 0.17,
				CFrame = CFrame.new(x, y, 0),
				Color = tint,
			})
		end
	end
	return body
end

function orbits.Eyes(m: Model, c: Color3?): BasePart
	local body = part(m, { Name = "Handle", Shape = BALL, Size = Vector3.one * 0.5, Color = WHITE })
	part(m, {
		Name = "Iris",
		Shape = BALL,
		Size = Vector3.new(0.26, 0.26, 0.08),
		CFrame = CFrame.new(0, 0, -0.23),
		Color = c or Color3.fromRGB(80, 200, 120),
	})
	part(m, {
		Name = "Pupil",
		Shape = BALL,
		Size = Vector3.new(0.12, 0.12, 0.05),
		CFrame = CFrame.new(0, 0, -0.27),
		Color = INK,
	})
	return body
end

function orbits.Stars(m: Model, c: Color3?): BasePart
	return star(
		m,
		CFrame.Angles(0, 0, math.rad(45)),
		0.55,
		c or Color3.fromRGB(255, 235, 120),
		"Handle"
	)
end

function orbits.Bats(m: Model, c: Color3?): BasePart
	local tint = c or Color3.fromRGB(60, 45, 80)
	local body = part(m, { Name = "Handle", Shape = BALL, Size = Vector3.one * 0.4, Color = tint })
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Wing",
			Size = Vector3.new(0.45, 0.25, 0.04),
			CFrame = CFrame.new(side * 0.36, 0.05, 0) * CFrame.Angles(0, 0, math.rad(side * 20)),
			Color = tint,
		})
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.one * 0.07,
			CFrame = CFrame.new(side * 0.07, 0.04, -0.18),
			Color = Color3.fromRGB(255, 220, 90),
			Material = NEON,
		})
	end
	return body
end

-- One small orbiting piece (anchored, pivot at its centre), `scale` times its built size.
-- Unknown kinds become stars.
function HeadPieces.Orbit(kind: string, tint: Color3?, scale: number?): Model
	local m = Instance.new("Model")
	m.Name = "Orbit_" .. kind
	local build = orbits[kind] or orbits.Stars
	local handle = build(m, tint)
	m.PrimaryPart = handle
	handle.PivotOffset = handle.CFrame:Inverse()
	if scale and scale > 0 and scale ~= 1 then
		m:ScaleTo(scale)
	end
	return m
end

return HeadPieces
