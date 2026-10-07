--!strict
--[[
	The look of a mystery crate, built from Parts: a chunky cartoon chest whose shape comes from
	the crate's Look.Style (Config.Crates.List, resolved by src/shared/CrateLook.luau):
	  "Pumpkin"  a ribbed carved pumpkin with a glowing face; its lid is the top cap, with a
	             stem and two leaves (Accent)
	  "Candy"    a striped candy box wrapped like a sweet (twisted wrapper ends on both sides)
	             with a big bow on the lid (Accent)
	  "Coffin"   a coffin crate with a cute ghost (Accent) peeking out from under the lid
	  "Tomb"     a mossy stone chest with a rounded headstone rising from the lid (moss: Accent)
	  "Monster"  a furry chest with two googly eyes ("Eye" + "Pupil" parts, the pupils follow
	             players: src/client/CrateIdle.luau) and a row of teeth (Accent) on the lid
	  "Moon"     a starry chest with a glowing crescent moon on the front
	  "Chest"    a chunky wooden chest with its Emblem on a badge on the front: a head piece
	             (src/shared/HeadPieces.luau), "Gem", or "" for a glowing "?"
	Chests (and Moon) also carry the crate's Topper on the lid. Colours: Color = body, Trim =
	bands and edges, Glow = glowing bits and the light inside, Look.Accent = the extra colour.
	Every built crate has a part named "Lid" (plus lid pieces with the attribute LidPiece)
	and a glowing "Inside" part under it, so the lid can open (CrateLook.Lid / LidPose).
	The lobby crate stand (server) and the crate panel's 3D previews (client) both use it, so
	they always match.

	Your own crate model: put a Model named after the crate's Id (e.g. "PumpkinCrate") in
	ReplicatedStorage.Custom.Props. The stand and the panel use it instead, scaled to the
	height of the built crate (front = the model's pivot front, -Z).

	CrateArt.Build(crate, size?) -> Model    the Part-built crate. Pivot: bottom centre of the
	                                         box, front faces -Z. size = box width in studs
	                                         (default Config.Crates.Stand.CrateSize)
	CrateArt.Preview(crate, size?) -> Model  your custom model if there is one, else Build
	CrateArt.Height(size?) -> number         about how tall a built crate is (box, lid and
	                                         what sits on the lid)
	CrateArt.AddPrompt(holder, crate) -> ProximityPrompt
	                                         the "Open <crate>" prompt (attribute CrateId) the
	                                         crate panel opens on (src/client/CrateUI.luau)
	CrateArt.MaxParts                        the most parts one built crate may have
]]

local Config = require(script.Parent.Config)
local CrateLook = require(script.Parent.CrateLook)
local CustomAssets = require(script.Parent.CustomAssets)
local HeadPieces = require(script.Parent.HeadPieces)

local CrateArt = {}

local WOOD = Enum.Material.WoodPlanks
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic
local SLATE = Enum.Material.Slate
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local GRASS = Enum.Material.Grass
local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYLINDER = Enum.PartType.Cylinder
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(28, 22, 36)

local HEIGHT = 1.17 -- a built crate's height, as a share of its width (every style is close)
local TOPPER = 0.28 -- how tall the topper on a chest is, as a share of the width
local TOPPER_WIDE = 0.55 -- ...but never wider than this (bones, bats)
local MAX_PARTS = 45 -- the lobby has a part budget, and the crate panel shows up to 8 at once
CrateArt.MaxParts = MAX_PARTS

-- Cylinders in Roblox lie along X: these turn one to stand up / to face the front.
local UP = CFrame.Angles(0, 0, math.rad(90))
local FACING = CFrame.Angles(0, math.rad(90), 0)

-- The part every crate is made of: anchored, never collides, never blocks raycasts or touches
-- (the stand puts a separate prompt part next to it). A "Ball" with unequal sides becomes a
-- real oval (a Block with a Sphere mesh: Roblox balls are always round).
local function part(m: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	local size: Vector3 = props.Size or p.Size
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

-- Marks a part as part of the lid: it opens with it (CrateLook.Lid).
local function lid(p: BasePart): BasePart
	p:SetAttribute("LidPiece", true)
	return p
end

local function glow(p: BasePart): BasePart
	p.Material = NEON
	p.CastShadow = false
	return p
end

local function lighter(c: Color3, amount: number): Color3
	return c:Lerp(WHITE, amount)
end

local function darker(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

local function countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

function CrateArt.Height(size: number?): number
	local s = size or Config.Crates.Stand.CrateSize
	return s * HEIGHT
end

-- Moving a group of parts --------------------------------------------------------------------

-- The box round every part of `root` (along the model's own axes).
local function bounds(root: Instance): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = d.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	return lo, hi
end

-- Scales `root` so its biggest side (only width and height when `flat`) is `fit` studs and
-- centres it on the origin. Returns its new size.
local function fitTo(root: Instance, fit: number, flat: boolean): Vector3
	local lo, hi = bounds(root)
	local extent = hi - lo
	local biggest = if flat
		then math.max(extent.X, extent.Y)
		else math.max(extent.X, extent.Y, extent.Z)
	local k = if biggest > 1e-3 then fit / biggest else 1
	local centre = (lo + hi) / 2
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local rotation = d.CFrame.Rotation
			local at = (d.Position - centre) * k
			d.Size = d.Size * k
			d.CFrame = CFrame.new(at) * rotation
		elseif d:IsA("SpecialMesh") then
			d.Offset = d.Offset * k
			if d.MeshType == Enum.MeshType.FileMesh then
				d.Scale = d.Scale * k
			end
		end
	end
	return extent * k
end

-- Moves every part of `root` by `cf` (it was built around the origin).
local function moveTo(root: Instance, cf: CFrame)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * d.CFrame
		end
	end
end

-- Little pieces ------------------------------------------------------------------------------

-- The "?" on the front face, made of glowing blocks. `front` is the centre of the front face
-- (its -Z points out of the crate); c is one "pixel" of the glyph.
local function questionMark(m: Model, front: CFrame, c: number, color: Color3)
	local depth = math.max(c * 0.3, 0.05)
	type Piece = { Name: string, W: number, H: number, X: number, Y: number }
	local pieces: { Piece } = {
		{ Name = "Top", W = 2.4, H = 0.8, X = 0, Y = 2.4 },
		{ Name = "Hook", W = 0.8, H = 0.8, X = -1.2, Y = 1.7 },
		{ Name = "Right", W = 0.8, H = 1.8, X = 1.2, Y = 1.5 },
		{ Name = "Middle", W = 1.6, H = 0.8, X = 0.4, Y = 0.6 },
		{ Name = "Stem", W = 0.8, H = 1.2, X = 0, Y = -0.3 },
		{ Name = "Dot", W = 0.8, H = 0.8, X = 0, Y = -1.9 },
	}
	for _, piece in pieces do
		glow(part(m, {
			Name = "Mark" .. piece.Name,
			Size = Vector3.new(piece.W * c, piece.H * c, depth),
			-- x is mirrored: the crate's front faces -Z, so the viewer's right is the crate's -X.
			CFrame = front * CFrame.new(-piece.X * c, (piece.Y - 0.25) * c, -depth / 2),
			Color = color,
		}))
	end
end

-- A cut gem standing on one corner, with a glowing heart (the rarity crates' emblem).
local function gem(color: Color3, heart: Color3): Model
	local g = Instance.new("Model")
	g.Name = "Gem"
	local tilt = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local shell = part(g, {
		Name = "Gem",
		Size = Vector3.one * 0.6,
		CFrame = tilt,
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.15,
	})
	glow(part(g, {
		Name = "GemCore",
		Size = Vector3.one * 0.36,
		CFrame = tilt,
		Color = heart,
	}))
	g.PrimaryPart = shell
	return g
end

-- A little four-pointed twinkle (a block on its corner).
local function twinkle(m: Model, at: CFrame, size: number, color: Color3): BasePart
	return glow(part(m, {
		Name = "Star",
		Size = Vector3.new(size, size, size * 0.4),
		CFrame = at * CFrame.Angles(0, 0, math.rad(45)),
		Color = color,
	}))
end

-- The glowing part under the lid: a thin line of light round the seam while it is shut, the
-- light pouring out when it opens.
local function inside(
	m: Model,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): BasePart
	return glow(
		part(
			m,
			{ Name = "Inside", Shape = shape or BLOCK, Size = size, CFrame = cf, Color = color }
		)
	)
end

-- The crate's Topper (an orbit piece, or a Gem) on the lid at height `top`; a single glowing
-- gem instead when it would take the crate over MAX_PARTS.
local function topper(m: Model, crate: any, look: CrateLook.Look, s: number, top: number)
	local ok, piece = pcall(function(): Model
		if crate.Topper == "Gem" then
			return gem(lighter(look.Body, 0.2), look.Glow)
		end
		return HeadPieces.Orbit(tostring(crate.Topper), nil)
	end)
	if not (ok and piece) or countParts(m) + countParts(piece) > MAX_PARTS then
		-- (no room: a single glowing gem instead)
		if ok and piece then
			piece:Destroy()
		end
		local size = s * TOPPER * 0.62
		lid(glow(part(m, {
			Name = "TopGem",
			Size = Vector3.one * size,
			CFrame = CFrame.new(0, top + size * 0.82, 0)
				* CFrame.Angles(math.rad(45), 0, math.rad(35.26)),
			Color = look.Glow,
		})))
		return
	end
	piece.Name = "Topper"
	-- A star stands on a point (a sparkle), not on its side (it would read as an "X").
	if crate.Topper == "Stars" then
		moveTo(piece, CFrame.Angles(0, 0, math.rad(45)))
	end
	-- As tall as TOPPER, unless that makes it wider than TOPPER_WIDE (bones, bats).
	local lo, hi = bounds(piece)
	local extent = hi - lo
	local k = math.min(
		s * TOPPER / math.max(extent.Y, 1e-3),
		s * TOPPER_WIDE / math.max(extent.X, extent.Z, 1e-3)
	)
	local scaled = fitTo(piece, math.max(extent.X, extent.Y, extent.Z) * k, false)
	moveTo(
		piece,
		CFrame.new(0, top + scaled.Y / 2 - s * 0.01, 0) * CFrame.Angles(0, math.rad(-20), 0)
	)
	for _, d in piece:GetDescendants() do
		if d:IsA("BasePart") then
			lid(d)
		end
	end
	piece.Parent = m
end

-- Styles -------------------------------------------------------------------------------------
-- Each builds into `m` around the origin (bottom centre, front -Z) and returns its main body
-- part (the model's PrimaryPart, never part of the lid).

type Builder = (m: Model, crate: any, look: CrateLook.Look, s: number) -> BasePart

-- The chunky wooden chest the "Chest" and "Moon" styles share: a box with two straps, a
-- stepped lid and a clasp. Returns the box, the box height, its depth and the lid's top.
local function chestBase(
	m: Model,
	look: CrateLook.Look,
	s: number
): (BasePart, number, number, number)
	local h, d = s * 0.62, s * 0.82
	local trim = look.Trim
	part(m, {
		Name = "Base",
		Size = Vector3.new(s * 1.05, s * 0.09, d + s * 0.06),
		CFrame = CFrame.new(0, s * 0.045, 0),
		Color = trim,
		Material = WOOD,
	})
	local box = part(m, {
		Name = "Box",
		Size = Vector3.new(s, h, d),
		CFrame = CFrame.new(0, h / 2, 0),
		Color = look.Body,
		Material = WOOD,
		CastShadow = true,
	})
	for _, x in { -1, 1 } do
		part(m, {
			Name = "Strap",
			Size = Vector3.new(s * 0.12, h + s * 0.01, d + s * 0.04),
			CFrame = CFrame.new(x * s * 0.33, h / 2, 0),
			Color = trim,
			Material = WOOD,
		})
	end
	inside(m, Vector3.new(s * 0.98, s * 0.06, d * 0.98), CFrame.new(0, h, 0), look.Glow)
	local lidH = s * 0.17
	local lidBottom = h + s * 0.03
	part(m, {
		Name = "Lid",
		Size = Vector3.new(s * 1.03, lidH, d + s * 0.05),
		CFrame = CFrame.new(0, lidBottom + lidH / 2, 0),
		Color = lighter(look.Body, 0.08),
		Material = WOOD,
		CastShadow = true,
	})
	local crown = s * 0.1
	lid(part(m, {
		Name = "LidTop",
		Size = Vector3.new(s * 0.86, crown, d * 0.78),
		CFrame = CFrame.new(0, lidBottom + lidH + crown / 2, 0),
		Color = lighter(look.Body, 0.14),
		Material = WOOD,
	}))
	local top = lidBottom + lidH + crown
	for _, x in { -1, 1 } do
		lid(part(m, {
			Name = "LidStrap",
			Size = Vector3.new(s * 0.13, top - lidBottom + s * 0.01, d + s * 0.08),
			CFrame = CFrame.new(x * s * 0.33, (lidBottom + top) / 2, 0),
			Color = trim,
			Material = WOOD,
		}))
	end
	lid(part(m, {
		Name = "Clasp",
		Size = Vector3.new(s * 0.17, s * 0.2, s * 0.05),
		CFrame = CFrame.new(0, lidBottom + s * 0.01, -(d + s * 0.05) / 2 - s * 0.02),
		Color = lighter(trim, 0.3),
		Material = METAL,
	}))
	return box, h, d, top + s * 0.005
end

-- Puts a head piece from HeadPieces on the chest's front badge, or nothing if it fails.
local function headEmblem(m: Model, name: string, s: number, front: CFrame): Model?
	local e = Instance.new("Model")
	e.Name = "Emblem"
	local ok = pcall(function()
		HeadPieces.Builders[name](e, {})
	end)
	if not ok or countParts(e) == 0 then
		e:Destroy()
		return nil
	end
	-- (its names must not be mistaken for the crate's own lid or eyes)
	for _, d in e:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Lid" or d.Name == "Inside" or d.Name == "Pupil" then
				d.Name = "Emblem" .. d.Name
			end
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local extent = fitTo(e, s * 0.5, true)
	moveTo(e, front * CFrame.new(0, 0, -extent.Z * 0.3))
	e.Parent = m
	return e
end

local function buildChest(m: Model, crate: any, look: CrateLook.Look, s: number): BasePart
	local box, h, d, top = chestBase(m, look, s)
	-- The badge on the front, with the emblem on it.
	local badgeY = h * 0.47
	local badgeZ = -d / 2 - s * 0.025
	part(m, {
		Name = "Badge",
		Shape = CYLINDER,
		Size = Vector3.new(s * 0.05, s * 0.48, s * 0.48),
		CFrame = CFrame.new(0, badgeY, badgeZ) * FACING,
		Color = lighter(look.Trim, 0.25),
		Material = METAL,
	})
	local front = CFrame.new(0, badgeY, badgeZ - s * 0.025)
	local emblem = look.Emblem
	local placed = false
	if emblem == "Gem" then
		local g = gem(lighter(look.Body, 0.25), look.Glow)
		g.Name = "Emblem"
		local extent = fitTo(g, s * 0.36, true)
		moveTo(g, front * CFrame.new(0, 0, -extent.Z * 0.3))
		g.Parent = m
		placed = true
	elseif HeadPieces.Has(emblem) then
		placed = headEmblem(m, emblem, s, front) ~= nil
	end
	if not placed then
		questionMark(m, front, s * 0.06, look.Glow)
	end
	topper(m, crate, look, s, top)
	return box
end

local function buildMoon(m: Model, crate: any, look: CrateLook.Look, s: number): BasePart
	local box, h, d, top = chestBase(m, look, s)
	local faceZ = -d / 2
	-- The crescent: a glowing moon with a body-coloured disc over one side.
	local moonY = h * 0.48
	glow(part(m, {
		Name = "Moon",
		Shape = CYLINDER,
		Size = Vector3.new(s * 0.05, s * 0.44, s * 0.44),
		CFrame = CFrame.new(0, moonY, faceZ - s * 0.025) * FACING,
		Color = look.Accent,
	}))
	part(m, {
		Name = "MoonShade",
		Shape = CYLINDER,
		Size = Vector3.new(s * 0.05, s * 0.38, s * 0.38),
		CFrame = CFrame.new(-s * 0.11, moonY + s * 0.05, faceZ - s * 0.045) * FACING,
		Color = look.Body,
		Material = WOOD,
	})
	-- Stars on the box (x mirrored: the viewer's right is the crate's -X).
	-- (beside the straps: the moon fills the middle)
	local starsOnBox =
		{ Vector2.new(0.445, 0.44), Vector2.new(-0.445, 0.2), Vector2.new(-0.445, 0.48) }
	for i, at in starsOnBox do
		twinkle(
			m,
			CFrame.new(-at.X * s, at.Y * s, faceZ - s * 0.01),
			s * (if i == 1 then 0.09 else 0.07),
			if i % 2 == 0 then look.Glow else look.Accent
		)
	end
	-- Stars on the lid's front.
	local lidFront = -(d + s * 0.05) / 2 - s * 0.01
	for i, x in { -0.18, 0.18 } do
		lid(
			twinkle(
				m,
				CFrame.new(x * s, h + s * 0.13, lidFront),
				s * 0.07,
				if i == 1 then look.Glow else look.Accent
			)
		)
	end
	lid(
		twinkle(
			m,
			CFrame.new(s * 0.02, top - s * 0.06, -d * 0.39 - s * 0.01),
			s * 0.06,
			look.Accent
		)
	)
	topper(m, crate, look, s, top)
	return box
end

-- How far forward (-Z) the front of a group of ovals is at (x, y).
type Oval = { Centre: Vector3, Semi: Vector3 }
local function frontOf(ovals: { Oval }, x: number, y: number): number
	local z = 0
	for _, o in ovals do
		local nx = (x - o.Centre.X) / o.Semi.X
		local ny = (y - o.Centre.Y) / o.Semi.Y
		local k = 1 - nx * nx - ny * ny
		if k > 0 then
			z = math.min(z, o.Centre.Z - o.Semi.Z * math.sqrt(k))
		end
	end
	return z
end

local function buildPumpkin(m: Model, _crate: any, look: CrateLook.Look, s: number): BasePart
	local height = s * 0.86
	local cy = height / 2
	local ovals: { Oval } = {}
	local body = part(m, {
		Name = "Pumpkin",
		Shape = BALL,
		Size = Vector3.new(s * 0.82, height, s * 0.8),
		CFrame = CFrame.new(0, cy, 0),
		Color = look.Body,
		CastShadow = true,
	})
	table.insert(ovals, { Centre = body.Position, Semi = body.Size / 2 })
	-- Six ribs round the middle: one straight at the front (the face goes on it).
	for i = 0, 5 do
		local a = math.rad(270 + i * 60)
		local at = Vector3.new(math.cos(a) * s * 0.21, cy, math.sin(a) * s * 0.22)
		local rib = part(m, {
			Name = "PumpkinRib",
			Shape = BALL,
			Size = Vector3.new(s * 0.52, height * 0.95, s * 0.52),
			CFrame = CFrame.new(at),
			Color = if i % 2 == 0 then look.Body else darker(look.Body, 0.07),
		})
		table.insert(ovals, { Centre = rib.Position, Semi = rib.Size / 2 })
	end
	-- The carved face, glowing, on the surface (x mirrored: the viewer's right is -X).
	local function carve(name: string, w: number, hgt: number, x: number, y: number, roll: number)
		local depth = s * 0.06
		local z = 0
		for _, cx in { -w / 2, 0, w / 2 } do
			for _, cyy in { -hgt / 2, 0, hgt / 2 } do
				z = math.min(z, frontOf(ovals, x + cx, y + cyy))
			end
		end
		glow(part(m, {
			Name = name,
			Size = Vector3.new(w, hgt, depth),
			CFrame = CFrame.new(x, y, z + depth * 0.25) * CFrame.Angles(0, 0, math.rad(roll)),
			Color = look.Glow,
		}))
	end
	for _, side in { -1, 1 } do
		carve("CarvedEye", s * 0.13, s * 0.13, side * s * 0.14, cy + s * 0.12, 45)
		carve("CarvedMouth", s * 0.11, s * 0.065, side * s * 0.15, cy - s * 0.1, side * -28)
	end
	carve("CarvedNose", s * 0.06, s * 0.06, 0, cy + s * 0.01, 45)
	carve("CarvedMouth", s * 0.2, s * 0.08, 0, cy - s * 0.14, 0)
	-- The cut round the top glows; the cap is the lid.
	local capY = height + s * 0.02
	inside(
		m,
		Vector3.new(s * 0.04, s * 0.5, s * 0.5),
		CFrame.new(0, capY - s * 0.07, 0) * UP,
		look.Glow,
		CYLINDER
	)
	part(m, {
		Name = "Lid",
		Shape = BALL,
		Size = Vector3.new(s * 0.6, s * 0.2, s * 0.58),
		CFrame = CFrame.new(0, capY, 0),
		Color = lighter(look.Body, 0.05),
		CastShadow = true,
	})
	lid(part(m, {
		Name = "Stem",
		Shape = CYLINDER,
		Size = Vector3.new(s * 0.26, s * 0.11, s * 0.11),
		CFrame = CFrame.new(s * 0.02, capY + s * 0.17, 0) * CFrame.Angles(0, 0, math.rad(-12)) * UP,
		Color = look.Trim,
		Material = WOOD,
	}))
	for _, side in { -1, 1 } do
		lid(part(m, {
			Name = "Leaf",
			Shape = BALL,
			Size = Vector3.new(s * 0.34, s * 0.05, s * 0.18),
			CFrame = CFrame.new(side * s * 0.15, capY + s * 0.1, side * s * 0.03)
				* CFrame.Angles(0, math.rad(side * 25), math.rad(side * 18)),
			Color = look.Accent,
			Material = GRASS,
		}))
	end
	return body
end

local function buildCandy(m: Model, _crate: any, look: CrateLook.Look, s: number): BasePart
	local w, h, d = s * 0.76, s * 0.64, s * 0.8
	local box = part(m, {
		Name = "CandyBox",
		Size = Vector3.new(w, h, d),
		CFrame = CFrame.new(0, h / 2, 0),
		Color = look.Body,
		CastShadow = true,
	})
	-- Stripes round the box.
	for _, x in { -0.25, 0, 0.25 } do
		part(m, {
			Name = "Stripe",
			Size = Vector3.new(s * 0.08, h + s * 0.01, d + s * 0.02),
			CFrame = CFrame.new(x * s, h / 2, 0),
			Color = look.Trim,
		})
	end
	-- Sprinkles on the front.
	local sprinkles = {
		Vector2.new(-0.12, 0.42),
		Vector2.new(0.13, 0.2),
		Vector2.new(-0.13, 0.15),
		Vector2.new(0.12, 0.47),
	}
	for _, at in sprinkles do
		glow(part(m, {
			Name = "Sprinkle",
			Shape = BALL,
			Size = Vector3.new(s * 0.07, s * 0.07, s * 0.035),
			CFrame = CFrame.new(at.X * s, at.Y * s, -d / 2),
			Color = look.Glow,
		}))
	end
	-- The twisted wrapper ends.
	for _, side in { -1, 1 } do
		part(m, {
			Name = "WrapperTwist",
			Shape = CYLINDER,
			Size = Vector3.new(s * 0.14, s * 0.2, s * 0.2),
			CFrame = CFrame.new(side * (w / 2 + s * 0.05), h * 0.5, 0),
			Color = darker(look.Body, 0.12),
		})
		part(m, {
			Name = "WrapperEnd",
			Shape = BALL,
			Size = Vector3.new(s * 0.12, s * 0.52, s * 0.56),
			CFrame = CFrame.new(side * (w / 2 + s * 0.16), h * 0.5, 0)
				* CFrame.Angles(math.rad(side * 12), 0, math.rad(side * 10)),
			Color = look.Body,
		})
	end
	inside(m, Vector3.new(w * 0.98, s * 0.06, d * 0.98), CFrame.new(0, h, 0), look.Glow)
	local lidH = s * 0.16
	local lidBottom = h + s * 0.03
	local lidY = lidBottom + lidH / 2
	part(m, {
		Name = "Lid",
		Size = Vector3.new(w + s * 0.04, lidH, d + s * 0.04),
		CFrame = CFrame.new(0, lidY, 0),
		Color = lighter(look.Body, 0.1),
		CastShadow = true,
	})
	-- The ribbon round the lid and the big bow.
	lid(part(m, {
		Name = "Ribbon",
		Size = Vector3.new(w + s * 0.06, lidH + s * 0.02, s * 0.13),
		CFrame = CFrame.new(0, lidY, 0),
		Color = look.Accent,
	}))
	lid(part(m, {
		Name = "Ribbon",
		Size = Vector3.new(s * 0.13, lidH + s * 0.02, d + s * 0.06),
		CFrame = CFrame.new(0, lidY, 0),
		Color = look.Accent,
	}))
	local top = lidBottom + lidH
	for _, side in { -1, 1 } do
		lid(part(m, {
			Name = "BowLoop",
			Shape = BALL,
			Size = Vector3.new(s * 0.36, s * 0.26, s * 0.13),
			CFrame = CFrame.new(side * s * 0.15, top + s * 0.16, 0)
				* CFrame.Angles(0, 0, math.rad(side * 32)),
			Color = look.Accent,
		}))
		lid(part(m, {
			Name = "BowTail",
			Size = Vector3.new(s * 0.08, s * 0.03, s * 0.3),
			CFrame = CFrame.new(side * s * 0.07, top + s * 0.015, -s * 0.14)
				* CFrame.Angles(0, math.rad(side * 20), 0),
			Color = darker(look.Accent, 0.1),
		}))
	end
	lid(part(m, {
		Name = "BowKnot",
		Shape = BALL,
		Size = Vector3.one * s * 0.15,
		CFrame = CFrame.new(0, top + s * 0.07, 0),
		Color = darker(look.Accent, 0.05),
	}))
	return box
end

local function buildCoffin(m: Model, _crate: any, look: CrateLook.Look, s: number): BasePart
	-- A six-sided coffin: a middle block and a diamond (a block turned 45 degrees) at each end.
	local half = s * 0.31 -- half the depth
	local mid = s * 0.3 -- half the middle block's width
	local endX = s * 0.2
	local side = half * math.sqrt(2)
	local turned = CFrame.Angles(0, math.rad(45), 0)
	local baseH, h = s * 0.12, s * 0.8
	local top = baseH + h
	local function hexagon(
		name: string,
		y: number,
		height: number,
		grow: number,
		color: Color3,
		material: Enum.Material
	): BasePart
		local middle = part(m, {
			Name = name,
			Size = Vector3.new(mid * 2 + grow, height, half * 2 + grow),
			CFrame = CFrame.new(0, y, 0),
			Color = color,
			Material = material,
			CastShadow = true,
		})
		for _, x in { -1, 1 } do
			part(m, {
				Name = name .. "End",
				Size = Vector3.new(side + grow * 0.7, height, side + grow * 0.7),
				CFrame = CFrame.new(x * endX, y, 0) * turned,
				Color = color,
				Material = material,
			})
		end
		return middle
	end
	hexagon("CoffinBase", baseH / 2, baseH, s * 0.05, look.Trim, WOOD)
	local body = hexagon("Coffin", baseH + h / 2, h, 0, look.Body, WOOD)
	-- Two handles on the front.
	for _, x in { -1, 1 } do
		part(m, {
			Name = "Handle",
			Size = Vector3.new(s * 0.2, s * 0.06, s * 0.05),
			CFrame = CFrame.new(x * s * 0.2, baseH + h * 0.4, -half - s * 0.025),
			Color = lighter(look.Trim, 0.35),
			Material = METAL,
		})
	end
	inside(
		m,
		Vector3.new(mid * 2 - s * 0.02, s * 0.06, half * 2 - s * 0.02),
		CFrame.new(0, top, 0),
		look.Glow
	)
	-- The lid: the same six-sided shape, a raised panel and a glowing cross.
	local lidH = s * 0.13
	local lidY = top + s * 0.03 + lidH / 2
	local lidPart = part(m, {
		Name = "Lid",
		Size = Vector3.new(mid * 2 + s * 0.03, lidH, half * 2 + s * 0.03),
		CFrame = CFrame.new(0, lidY, 0),
		Color = lighter(look.Body, 0.1),
		Material = WOOD,
		CastShadow = true,
	})
	for _, x in { -1, 1 } do
		lid(part(m, {
			Name = "LidEnd",
			Size = Vector3.new(side + s * 0.02, lidH, side + s * 0.02),
			CFrame = CFrame.new(x * endX, lidY, 0) * turned,
			Color = lidPart.Color,
			Material = WOOD,
		}))
	end
	local panelTop = lidY + lidH / 2 + s * 0.05
	lid(part(m, {
		Name = "LidPanel",
		Size = Vector3.new(s * 0.62, s * 0.05, s * 0.42),
		CFrame = CFrame.new(0, panelTop - s * 0.025, 0),
		Color = look.Trim,
		Material = WOOD,
	}))
	lid(glow(part(m, {
		Name = "Cross",
		Size = Vector3.new(s * 0.38, s * 0.02, s * 0.07),
		CFrame = CFrame.new(0, panelTop + s * 0.005, 0),
		Color = look.Glow,
	})))
	lid(glow(part(m, {
		Name = "Cross",
		Size = Vector3.new(s * 0.07, s * 0.02, s * 0.28),
		CFrame = CFrame.new(s * 0.08, panelTop + s * 0.005, 0),
		Color = look.Glow,
	})))
	-- The ghost peeking out from under the front of the lid, holding on to the edge.
	local r = s * 0.18
	local ghostAt = Vector3.new(0, top - s * 0.02, -half - s * 0.04)
	lid(part(m, {
		Name = "Ghost",
		Shape = BALL,
		Size = Vector3.new(r * 2, r * 2, r * 1.8),
		CFrame = CFrame.new(ghostAt),
		Color = look.Accent,
	}))
	local function onGhost(x: number, y: number): number
		local k = 1 - (x / r) ^ 2 - (y / r) ^ 2
		return ghostAt.Z - r * 0.9 * math.sqrt(math.max(k, 0))
	end
	for _, x in { -1, 1 } do
		local ex, ey = x * r * 0.38, -r * 0.18
		lid(part(m, {
			Name = "GhostEye",
			Shape = BALL,
			Size = Vector3.new(s * 0.065, s * 0.1, s * 0.04),
			CFrame = CFrame.new(ghostAt.X + ex, ghostAt.Y + ey, onGhost(ex, ey) + s * 0.01),
			Color = INK,
		}))
		lid(part(m, {
			Name = "GhostHand",
			Shape = BALL,
			Size = Vector3.new(s * 0.11, s * 0.09, s * 0.11),
			CFrame = CFrame.new(x * s * 0.24, top + s * 0.01, -half - s * 0.02),
			Color = look.Accent,
		}))
	end
	lid(part(m, {
		Name = "GhostMouth",
		Shape = BALL,
		Size = Vector3.new(s * 0.06, s * 0.07, s * 0.03),
		CFrame = CFrame.new(ghostAt.X, ghostAt.Y - r * 0.55, onGhost(0, -r * 0.55) + s * 0.012),
		Color = INK,
	}))
	return body
end

local function buildTomb(m: Model, _crate: any, look: CrateLook.Look, s: number): BasePart
	local baseH = s * 0.1
	local w, h, d = s * 0.94, s * 0.58, s * 0.78
	local stone = look.Body
	part(m, {
		Name = "TombBase",
		Size = Vector3.new(s * 1.03, baseH, d + s * 0.1),
		CFrame = CFrame.new(0, baseH / 2, 0),
		Color = look.Trim,
		Material = SLATE,
	})
	local box = part(m, {
		Name = "Tomb",
		Size = Vector3.new(w, h, d),
		CFrame = CFrame.new(0, baseH + h / 2, 0),
		Color = stone,
		Material = SLATE,
		CastShadow = true,
	})
	local faceZ = -d / 2
	for _, x in { -1, 1 } do
		part(m, {
			Name = "Pillar",
			Size = Vector3.new(s * 0.15, h, s * 0.15),
			CFrame = CFrame.new(x * (w / 2 - s * 0.05), baseH + h / 2, faceZ + s * 0.05),
			Color = lighter(look.Trim, 0.15),
			Material = SLATE,
		})
	end
	part(m, {
		Name = "Panel",
		Size = Vector3.new(s * 0.56, h * 0.62, s * 0.03),
		CFrame = CFrame.new(0, baseH + h * 0.48, faceZ - s * 0.01),
		Color = darker(stone, 0.18),
		Material = SLATE,
	})
	-- Two glowing cracks on the panel.
	glow(part(m, {
		Name = "Crack",
		Size = Vector3.new(s * 0.035, s * 0.18, s * 0.02),
		CFrame = CFrame.new(-s * 0.1, baseH + h * 0.55, faceZ - s * 0.03)
			* CFrame.Angles(0, 0, math.rad(25)),
		Color = look.Glow,
	}))
	glow(part(m, {
		Name = "Crack",
		Size = Vector3.new(s * 0.035, s * 0.14, s * 0.02),
		CFrame = CFrame.new(-s * 0.075, baseH + h * 0.33, faceZ - s * 0.03)
			* CFrame.Angles(0, 0, math.rad(-20)),
		Color = look.Glow,
	}))
	-- Moss on the box.
	part(m, {
		Name = "Moss",
		Shape = BALL,
		Size = Vector3.new(s * 0.22, s * 0.08, s * 0.2),
		CFrame = CFrame.new(-(w / 2 - s * 0.05), baseH + h, faceZ + s * 0.06),
		Color = look.Accent,
		Material = GRASS,
	})
	part(m, {
		Name = "Moss",
		Shape = BALL,
		Size = Vector3.new(s * 0.3, s * 0.12, s * 0.06),
		CFrame = CFrame.new(w * 0.3, baseH + s * 0.04, faceZ - s * 0.01),
		Color = look.Accent,
		Material = GRASS,
	})
	local top = baseH + h
	inside(m, Vector3.new(w * 0.97, s * 0.06, d * 0.97), CFrame.new(0, top, 0), look.Glow)
	-- The lid with a headstone rising from its back.
	local lidH = s * 0.13
	local lidY = top + s * 0.03 + lidH / 2
	part(m, {
		Name = "Lid",
		Size = Vector3.new(s, lidH, d + s * 0.06),
		CFrame = CFrame.new(0, lidY, 0),
		Color = lighter(stone, 0.06),
		Material = SLATE,
		CastShadow = true,
	})
	local lidTop = lidY + lidH / 2
	local stoneW, stoneD, stoneZ = s * 0.52, s * 0.15, d * 0.26
	local shoulder = s * 0.1
	lid(part(m, {
		Name = "Headstone",
		Size = Vector3.new(stoneW, shoulder, stoneD),
		CFrame = CFrame.new(0, lidTop + shoulder / 2, stoneZ),
		Color = lighter(stone, 0.12),
		Material = SLATE,
	}))
	local archY = lidTop + shoulder
	lid(part(m, {
		Name = "HeadstoneTop",
		Shape = CYLINDER,
		Size = Vector3.new(stoneD, stoneW, stoneW),
		CFrame = CFrame.new(0, archY, stoneZ) * FACING,
		Color = lighter(stone, 0.12),
		Material = SLATE,
	}))
	local stoneFront = stoneZ - stoneD / 2 - s * 0.01
	lid(glow(part(m, {
		Name = "Cross",
		Size = Vector3.new(s * 0.05, s * 0.22, s * 0.02),
		CFrame = CFrame.new(0, archY, stoneFront),
		Color = look.Glow,
	})))
	lid(glow(part(m, {
		Name = "Cross",
		Size = Vector3.new(s * 0.16, s * 0.05, s * 0.02),
		CFrame = CFrame.new(0, archY + s * 0.04, stoneFront),
		Color = look.Glow,
	})))
	lid(part(m, {
		Name = "Moss",
		Shape = BALL,
		Size = Vector3.new(s * 0.26, s * 0.08, s * 0.17),
		CFrame = CFrame.new(-s * 0.08, archY + stoneW / 2 - s * 0.02, stoneZ)
			* CFrame.Angles(0, 0, math.rad(12)),
		Color = look.Accent,
		Material = GRASS,
	}))
	lid(part(m, {
		Name = "Moss",
		Shape = BALL,
		Size = Vector3.new(s * 0.3, s * 0.06, s * 0.24),
		CFrame = CFrame.new(s * 0.3, lidTop, -d * 0.28),
		Color = look.Accent,
		Material = GRASS,
	}))
	return box
end

local function buildMonster(m: Model, _crate: any, look: CrateLook.Look, s: number): BasePart
	local footH = s * 0.08
	local w, h, d = s * 0.96, s * 0.62, s * 0.82
	-- Four stubby feet.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(m, {
				Name = "Foot",
				Shape = BALL,
				Size = Vector3.new(s * 0.26, s * 0.16, s * 0.3),
				CFrame = CFrame.new(x * s * 0.3, footH, z * s * 0.27),
				Color = look.Trim,
				Material = FABRIC,
			})
		end
	end
	local body = part(m, {
		Name = "Fur",
		Size = Vector3.new(w, h, d),
		CFrame = CFrame.new(0, footH + h / 2, 0),
		Color = look.Body,
		Material = FABRIC,
		CastShadow = true,
	})
	-- Two big googly eyes; each Pupil may roll EyeRadius studs round its Eye's centre.
	local eye = s * 0.34
	local pupil = s * 0.15
	local faceZ = -d / 2
	for _, x in { -1, 1 } do
		local centre = Vector3.new(x * s * 0.22, footH + h * 0.48, faceZ)
		part(m, {
			Name = "Eye",
			Shape = BALL,
			Size = Vector3.new(eye, eye, eye * 0.7),
			CFrame = CFrame.new(centre),
			Color = WHITE,
		})
		local p = part(m, {
			Name = "Pupil",
			Shape = BALL,
			Size = Vector3.new(pupil, pupil, pupil * 0.5),
			CFrame = CFrame.new(centre + Vector3.new(0, 0, -eye * 0.35)),
			Color = INK,
		})
		p:SetAttribute("EyeRadius", (eye - pupil) * 0.42)
	end
	local top = footH + h
	inside(m, Vector3.new(w * 0.97, s * 0.06, d * 0.97), CFrame.new(0, top, 0), look.Glow)
	local lidH = s * 0.18
	local lidBottom = top + s * 0.03
	local lidD = d + s * 0.04
	part(m, {
		Name = "Lid",
		Size = Vector3.new(w + s * 0.04, lidH, lidD),
		CFrame = CFrame.new(0, lidBottom + lidH / 2, 0),
		Color = lighter(look.Body, 0.06),
		Material = FABRIC,
		CastShadow = true,
	})
	-- Teeth hanging from the lid's front edge (each a block on its corner, half inside the lid).
	local tooth = s * 0.11
	for i, x in { -0.32, -0.16, 0, 0.16, 0.32 } do
		local big = i == 1 or i == 5
		local t = if big then tooth * 1.3 else tooth
		lid(part(m, {
			Name = "Tooth",
			Size = Vector3.new(t, t, s * 0.02),
			CFrame = CFrame.new(x * s, lidBottom, -lidD / 2 + s * 0.012)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = look.Accent,
		}))
	end
	local lidTop = lidBottom + lidH
	-- Two little horns and a tuft of fur on top.
	for _, x in { -1, 1 } do
		lid(part(m, {
			Name = "Horn",
			Shape = BALL,
			Size = Vector3.new(s * 0.13, s * 0.3, s * 0.13),
			CFrame = CFrame.new(x * s * 0.3, lidTop + s * 0.1, s * 0.05)
				* CFrame.Angles(0, 0, math.rad(-x * 20)),
			Color = look.Trim,
		}))
	end
	lid(part(m, {
		Name = "Tuft",
		Shape = BALL,
		Size = Vector3.new(s * 0.32, s * 0.12, s * 0.28),
		CFrame = CFrame.new(0, lidTop, -s * 0.05),
		Color = darker(look.Body, 0.1),
		Material = GRASS,
	}))
	return body
end

local BUILDERS: { [string]: Builder } = {
	Chest = buildChest,
	Moon = buildMoon,
	Pumpkin = buildPumpkin,
	Candy = buildCandy,
	Coffin = buildCoffin,
	Tomb = buildTomb,
	Monster = buildMonster,
}

function CrateArt.Build(crate: any, size: number?): Model
	local s = size or Config.Crates.Stand.CrateSize
	local m = Instance.new("Model")
	m.Name = crate.Id
	m:SetAttribute("CrateId", crate.Id)
	local look = CrateLook.Of(crate)
	local build = BUILDERS[look.Style] or buildChest
	local body = build(m, crate, look, s)
	-- Rarity crates whose rarity is a rainbow (CRAZY): every glowing part cycles the rainbow.
	local level = crate.Rarity and (Config.Rarity.Levels :: any)[crate.Rarity]
	if level and level.Rainbow == true then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Material == NEON then
				d:SetAttribute("Rainbow", true)
			end
		end
	end
	m.PrimaryPart = body
	body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.identity)
	return m
end

function CrateArt.AddPrompt(holder: BasePart, crate: any): ProximityPrompt
	local text = Config.Crates.Text
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenCratePrompt"
	prompt.ActionText = text.Prompt:format(crate.Name)
	prompt.ObjectText = text.PromptObject
	prompt.MaxActivationDistance = Config.Crates.Stand.PromptDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CrateId", crate.Id)
	prompt.Parent = holder
	return prompt
end

function CrateArt.Preview(crate: any, size: number?): Model
	local custom = CustomAssets.Clone("Props", crate.Id)
	if custom then
		-- (by its longest side: a long coffin or a tall sarcophagus still fits the preview)
		CustomAssets.Fit(custom, CrateArt.Height(size), true)
		CustomAssets.MakeDecor(custom)
		CustomAssets.PlaceFeet(custom, CFrame.identity)
		custom:SetAttribute("CrateId", crate.Id)
		return custom
	end
	return CrateArt.Build(crate, size)
end

return CrateArt
