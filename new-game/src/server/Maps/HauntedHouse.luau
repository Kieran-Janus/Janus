--!strict
--[[
	"The Haunted House", the Prop Hunt map (settings: src/shared/Config/Maps/HauntedHouse.luau).

	  middle-north  the mansion: six rooms downstairs (Library, Stair Hall, Kitchen at the back;
	                Parlour, Grand Hall, Dining Room at the front) joined by wide doorways, the
	                roof long gone over the front rooms. A ramp in the Stair Hall climbs to the
	                Attic (west) and the Nursery (east), joined by a balcony.
	  south         the Finder Hut (HideSeekProps.seekerHut: door tagged SeekerDoor, SeekerSpawn
	                pads inside) at the end of a stepping-stone path to the front porch
	  south-west    a fenced graveyard;  south-east  a pumpkin patch
	  everywhere    dead trees, glowing mushrooms, bats, cobwebs, portraits whose eyes follow you

	The things hiders can turn into are tagged PropHuntProp (src/shared/Tags.luau): pumpkins,
	jack-o'-lanterns, crates, barrels, gravestones, hay bales, candles, lanterns, cauldrons,
	coffins, chairs, tables, skulls, brooms, potions and piles of books, spread from the map's
	Seed over free spots in every room and round the yard (Layout.Props). Each is a Kit.prop,
	so one model in ReplicatedStorage.Custom.Props swaps every copy (docs/CUSTOMIZE.md); new
	names here: Chair, Table, Skull, Broom, Potion, Books, Bookshelf (and Cauldron, Coffin,
	built here in this map's own style). Every random number is drawn before Kit.prop, so a
	custom model never moves the rest of the map.

	Phone budget: well under 4000 parts and about 20 lights. Hider spawns (tag HiderSpawn, in
	the Spawns folder): one per room and a few round the yard.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)
local Portrait = require(script.Parent.Parent.Build.Portrait)
local HideSeekProps = require(script.Parent.HideSeekProps)
local MapBase = require(script.Parent.MapBase)

local HauntedHouse = {}

local WALL = 2 -- wall thickness
local BOARDS = 0.2 -- the house's floorboards stand this far above the yard
local UPPER = 15 -- the upstairs floor's top

type Rect = { Min: Vector2, Max: Vector2 }

type Env = {
	Ctx: MapBase.Ctx,
	Colors: any,
	Paint: Kit.Painter,
}

type Area = {
	Name: string,
	Rect: Rect, -- where things may stand (map offsets)
	Y: number, -- floor height
	Parent: Instance,
	Reserved: { Rect },
	Kinds: { string },
	Count: number,
}

-- Rectangles and free spots --------------------------------------------------------------------

local function rect(minX: number, minZ: number, maxX: number, maxZ: number): Rect
	return { Min = Vector2.new(minX, minZ), Max = Vector2.new(maxX, maxZ) }
end

local function reserve(list: { Rect }, center: Vector2, size: Vector2, pad: number)
	local half = size / 2 + Vector2.new(pad, pad)
	table.insert(list, { Min = center - half, Max = center + half })
end

local function clear(list: { Rect }, p: Vector2, radius: number): boolean
	for _, r in list do
		if
			p.X + radius > r.Min.X
			and p.X - radius < r.Max.X
			and p.Y + radius > r.Min.Y
			and p.Y - radius < r.Max.Y
		then
			return false
		end
	end
	return true
end

-- A free spot inside `area` at least `radius` from everything reserved (nil if none found).
local function freeSpot(rng: Random, list: { Rect }, area: Rect, radius: number): Vector2?
	local lowX, highX = area.Min.X + radius, area.Max.X - radius
	local lowZ, highZ = area.Min.Y + radius, area.Max.Y - radius
	if lowX >= highX or lowZ >= highZ then
		return nil
	end
	for _ = 1, 40 do
		local p = Vector2.new(rng:NextNumber(lowX, highX), rng:NextNumber(lowZ, highZ))
		if clear(list, p, radius) then
			return p
		end
	end
	return nil
end

-- Things hiders can become ----------------------------------------------------------------------

-- Tags `m` as a thing hiders can turn into, and makes sure pumpkins can hit it (a pumpkin that
-- lands on a real thing tells the finder "just a pumpkin!", see src/server/Modes/PropHunt.luau).
local function hideable(m: Model): Model
	CollectionService:AddTag(m, Tags.PropHuntProp)
	local main: BasePart? = m.PrimaryPart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.CanQuery then
				return m
			end
			if not main or d.Size.Magnitude > main.Size.Magnitude then
				main = d
			end
		end
	end
	if main then
		main.CanQuery = true
	end
	return m
end

-- An oval (a block with a sphere mesh).
local function oval(props: { [string]: any }, parent: Instance, solid: boolean?): Part
	return HideSeekProps.oval(props, parent, solid)
end

-- A wooden chair with a spiky high back (prop "Chair"), facing cf.LookVector.
local function chair(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local wood = HideSeekProps.jitter(colors.DarkWood, rng, 0.08)
	local cushion = if rng:NextNumber() < 0.5 then colors.Rug else colors.RugAlt
	return Kit.prop("Chair", cf, parent, 4.4, function()
		local m = Kit.model("Chair", parent)
		local seat = Kit.part({
			Name = "Seat",
			Size = Vector3.new(2.4, 0.35, 2.4),
			CFrame = cf * CFrame.new(0, 1.9, 0),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Cushion",
			Size = Vector3.new(2.1, 0.25, 2.1),
			CFrame = cf * CFrame.new(0, 2.15, 0),
			Color = cushion,
			Material = Enum.Material.Fabric,
		}, m)
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				Kit.decor({
					Name = "Leg",
					Size = Vector3.new(0.3, 1.8, 0.3),
					CFrame = cf * CFrame.new(x * 1.0, 0.9, z * 1.0),
					Color = wood,
					Material = Enum.Material.Wood,
				}, m)
			end
		end
		Kit.part({
			Name = "Back",
			Size = Vector3.new(2.4, 2.2, 0.3),
			CFrame = cf * CFrame.new(0, 3.15, 1.05),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		for _, x in { -1, 1 } do
			Kit.decor({
				Name = "Spike",
				Size = Vector3.new(0.35, 0.6, 0.35),
				CFrame = cf * CFrame.new(x * 1.05, 4.4, 1.05) * CFrame.Angles(0, math.rad(45), 0),
				Color = wood,
				Material = Enum.Material.Wood,
			}, m)
		end
		m.PrimaryPart = seat
		return m
	end, { Hitbox = Vector3.new(2.4, 4.4, 2.4) })
end

-- A round side table on one leg, with a little cloth (prop "Table").
local function sideTable(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local wood = HideSeekProps.jitter(colors.Wood, rng, 0.08)
	local cloth = if rng:NextNumber() < 0.5 then colors.Rug else colors.Bone
	return Kit.prop("Table", cf, parent, 3, function()
		local m = Kit.model("Table", parent)
		local top = Kit.part({
			Name = "Top",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3.6, 3.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 2.85, 0)),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Cloth",
			Size = Vector3.new(2.6, 0.05, 2.6),
			CFrame = cf * CFrame.new(0, 3.02, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color = cloth,
			Material = Enum.Material.Fabric,
		}, m)
		Kit.part({
			Name = "Leg",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.7, 0.6, 0.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 1.35, 0)),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Foot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2, 2),
			CFrame = Kit.upright(cf * CFrame.new(0, 0.15, 0)),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		m.PrimaryPart = top
		return m
	end, { Hitbox = Vector3.new(3.6, 3, 3.6) })
end

-- A grinning skull (prop "Skull").
local function skull(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local bone = HideSeekProps.jitter(colors.Bone, rng, 0.06)
	local dark = Color3.fromRGB(24, 20, 26)
	return Kit.prop("Skull", cf, parent, 1.4, function()
		local m = Kit.model("Skull", parent)
		local head = Kit.part({
			Name = "Cranium",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.15, 1.45),
			CFrame = cf * CFrame.new(0, 0.85, 0.05),
			Color = bone,
		}, m)
		Kit.decor({
			Name = "Jaw",
			Size = Vector3.new(0.8, 0.4, 0.6),
			CFrame = cf * CFrame.new(0, 0.25, -0.35),
			Color = bone,
		}, m)
		for _, x in { -1, 1 } do
			Kit.decor({
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.36, 0.36, 0.2),
				CFrame = cf * CFrame.new(x * 0.28, 0.9, -0.66),
				Color = dark,
			}, m)
		end
		Kit.decor({
			Name = "Nose",
			Size = Vector3.new(0.14, 0.2, 0.1),
			CFrame = cf * CFrame.new(0, 0.62, -0.7) * CFrame.Angles(0, 0, math.rad(45)),
			Color = dark,
		}, m)
		m.PrimaryPart = head
		return m
	end, { Hitbox = Vector3.new(1.3, 1.4, 1.5) })
end

-- A witch's broom standing on its bristles (prop "Broom").
local function broom(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	return Kit.prop("Broom", cf, parent, 4.8, function()
		local m = Kit.model("Broom", parent)
		local bristles = oval({
			Name = "Bristles",
			Size = Vector3.new(1.3, 1.6, 1.3),
			CFrame = cf * lean * CFrame.new(0, 0.8, 0),
			Color = colors.Hay,
			Material = Enum.Material.Fabric,
		}, m, true)
		Kit.decor({
			Name = "Band",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 0.75, 0.75),
			CFrame = Kit.upright(cf * lean * CFrame.new(0, 1.55, 0)),
			Color = colors.Rug,
		}, m)
		Kit.decor({
			Name = "Handle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 0.28, 0.28),
			CFrame = Kit.upright(cf * lean * CFrame.new(0, 3.1, 0)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, m)
		m.PrimaryPart = bristles
		return m
	end, { Hitbox = Vector3.new(1.3, 4.8, 1.3) })
end

local POTION_COLORS = { "Potion", "Slime", "Orange" }

-- A round glass potion bottle with a glowing brew (prop "Potion").
local function potion(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local brew: Color3 = colors[POTION_COLORS[rng:NextInteger(1, #POTION_COLORS)]]
	local size = rng:NextNumber(1.3, 1.8)
	return Kit.prop("Potion", cf, parent, size, function()
		local m = Kit.model("Potion", parent)
		local k = size / 1.6
		local glass = Kit.part({
			Name = "Bottle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1 * k,
			CFrame = cf * CFrame.new(0, 0.55 * k, 0),
			Color = Color3.fromRGB(200, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.45,
		}, m)
		Kit.decor({
			Name = "Brew",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.8 * k,
			CFrame = cf * CFrame.new(0, 0.5 * k, 0),
			Color = brew,
			Material = Enum.Material.Neon,
		}, m)
		Kit.decor({
			Name = "Neck",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.45 * k, 0.35 * k, 0.35 * k),
			CFrame = Kit.upright(cf * CFrame.new(0, 1.2 * k, 0)),
			Color = Color3.fromRGB(200, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.45,
		}, m)
		Kit.decor({
			Name = "Cork",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25 * k, 0.3 * k, 0.3 * k),
			CFrame = Kit.upright(cf * CFrame.new(0, 1.48 * k, 0)),
			Color = colors.Wood,
		}, m)
		m.PrimaryPart = glass
		return m
	end, { Hitbox = Vector3.new(1.1, 1.6, 1.1) * (size / 1.6) })
end

local BOOK_COLORS = {
	Color3.fromRGB(120, 30, 40),
	Color3.fromRGB(40, 70, 120),
	Color3.fromRGB(50, 100, 60),
	Color3.fromRGB(110, 70, 140),
	Color3.fromRGB(140, 100, 40),
}

-- A messy pile of old books (prop "Books").
local function books(_env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local count = rng:NextInteger(3, 4)
	local pile = {}
	local height = 0
	for i = 1, count do
		local thick = rng:NextNumber(0.3, 0.45)
		pile[i] = {
			Color = BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
			Thick = thick,
			Turn = rng:NextNumber(-0.5, 0.5),
			Shift = Vector2.new(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.15, 0.15)),
			Y = height,
		}
		height += thick
	end
	return Kit.prop("Books", cf, parent, height, function()
		local m = Kit.model("Books", parent)
		local first: Part? = nil
		for i, book in pile do
			local p = Kit.part({
				Name = "Book",
				Size = Vector3.new(1.9 - i * 0.12, book.Thick, 1.4 - i * 0.08),
				CFrame = cf
					* CFrame.new(book.Shift.X, book.Y + book.Thick / 2, book.Shift.Y)
					* CFrame.Angles(0, book.Turn, 0),
				Color = book.Color,
				Material = Enum.Material.Fabric,
			}, m)
			first = first or p
		end
		m.PrimaryPart = first
		return m
	end, { Hitbox = Vector3.new(1.9, height, 1.5) })
end

-- A three-legged iron cauldron of bubbling brew (prop "Cauldron").
local function cauldron(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local brew: Color3 = if rng:NextNumber() < 0.6 then colors.Slime else colors.Potion
	return Kit.prop("Cauldron", cf, parent, 3, function()
		local m = Kit.model("Cauldron", parent)
		local pot = Kit.part({
			Name = "Pot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.2, 2.5, 3.2),
			CFrame = cf * CFrame.new(0, 1.55, 0),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.6, 2.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 2.75, 0)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Brew",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 2.2, 2.2),
			CFrame = Kit.upright(cf * CFrame.new(0, 2.88, 0)),
			Color = brew,
			Material = Enum.Material.Neon,
		}, m)
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			Kit.decor({
				Name = "Leg",
				Size = Vector3.new(0.3, 0.6, 0.3),
				CFrame = cf * CFrame.new(math.cos(a) * 1.1, 0.3, math.sin(a) * 1.1),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, m)
		end
		m.PrimaryPart = pot
		return m
	end, { Hitbox = Vector3.new(3.2, 3, 3.2) })
end

-- A dark wooden coffin with a cross on the lid (prop "Coffin").
local function coffin(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local wood = HideSeekProps.jitter(colors.DarkWood, rng, 0.08)
	return Kit.prop("Coffin", cf, parent, 2, function()
		local m = Kit.model("Coffin", parent)
		local body = Kit.part({
			Name = "Coffin",
			Size = Vector3.new(3, 1.7, 6.6),
			CFrame = cf * CFrame.new(0, 0.85, 0),
			Color = wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Lid",
			Size = Vector3.new(3.2, 0.3, 6.8),
			CFrame = cf * CFrame.new(0, 1.85, 0),
			Color = Kit.shade(wood, 0.15),
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Cross",
			Size = Vector3.new(0.35, 0.06, 2.6),
			CFrame = cf * CFrame.new(0, 2.02, -0.6),
			Color = colors.Glow,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Cross",
			Size = Vector3.new(1.6, 0.06, 0.35),
			CFrame = cf * CFrame.new(0, 2.02, -1.3),
			Color = colors.Glow,
			Material = Enum.Material.Metal,
		}, m)
		m.PrimaryPart = body
		return m
	end, { Hitbox = Vector3.new(3, 2, 6.6) })
end

local GRAVE_STYLES = { "Round", "Cross", "Pointed" }

-- Every kind of thing hiders can become: name -> builder(env, cf, rng, parent). Random numbers
-- are drawn first in every builder, so a custom model never changes the rest of the map.
local KINDS: { [string]: (Env, CFrame, Random, Instance) -> Model } = {
	Pumpkin = function(env, cf, rng, parent)
		local size = rng:NextNumber(1.5, 2.4)
		return Props.Pumpkin(env.Paint, cf, size, parent, { Solid = true })
	end,
	JackOLantern = function(env, cf, rng, parent)
		local size = rng:NextNumber(1.7, 2.5)
		return Props.JackOLantern(env.Paint, cf, size, parent, { Light = false, Detail = "Simple" })
	end,
	Crate = function(env, cf, rng, parent)
		return Props.Crate(env.Paint, cf, rng:NextNumber(2.2, 3), parent)
	end,
	Barrel = function(env, cf, rng, parent)
		return Props.Barrel(env.Paint, cf, rng:NextNumber(3, 3.6), parent)
	end,
	Gravestone = function(env, cf, rng, parent)
		local size = rng:NextNumber(3, 4)
		local style = GRAVE_STYLES[rng:NextInteger(1, #GRAVE_STYLES)]
		local moss = rng:NextNumber() < 0.5
		return Props.Gravestone(env.Paint, cf, size, parent, { Style = style, Moss = moss })
	end,
	HayBale = function(env, cf, rng, parent)
		return HideSeekProps.hayBale(cf, env.Colors, rng, parent)
	end,
	Candle = function(env, cf, rng, parent)
		return Props.Candle(env.Paint, cf, rng:NextNumber(1, 1.8), parent)
	end,
	Lantern = function(env, cf, rng, parent)
		return Props.Lantern(env.Paint, cf, rng:NextNumber(1.4, 1.8), parent)
	end,
	Cauldron = cauldron,
	Coffin = coffin,
	Chair = chair,
	Table = sideTable,
	Skull = skull,
	Broom = broom,
	Potion = potion,
	Books = books,
}

-- How far apart (radius, studs) each kind needs to stand from other things.
local RADIUS: { [string]: number } = {
	Pumpkin = 1.7,
	JackOLantern = 1.7,
	Crate = 2,
	Barrel = 1.7,
	Gravestone = 1.9,
	HayBale = 2.7,
	Candle = 0.8,
	Lantern = 0.9,
	Cauldron = 2,
	Coffin = 3.8,
	Chair = 1.7,
	Table = 2,
	Skull = 0.9,
	Broom = 0.9,
	Potion = 0.8,
	Books = 1.2,
}

-- One thing hiders can become, of `kind`, on floor point (map offset) p at height y.
local function place(
	env: Env,
	kind: string,
	p: Vector2,
	y: number,
	rng: Random,
	parent: Instance
): Model
	local turn = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(MapBase.at(env.Ctx, p.X, p.Y, y)) * CFrame.Angles(0, turn, 0)
	return hideable(KINDS[kind](env, cf, rng, parent))
end

-- Fills `area` with `area.Count` things of its kinds on free spots.
local function fill(env: Env, area: Area, rng: Random)
	local made = 0
	for _ = 1, area.Count * 4 do
		if made >= area.Count then
			break
		end
		local kind = area.Kinds[rng:NextInteger(1, #area.Kinds)]
		local radius = RADIUS[kind] or 1.5
		local p = freeSpot(rng, area.Reserved, area.Rect, radius)
		if p then
			place(env, kind, p, area.Y, rng, area.Parent)
			reserve(area.Reserved, p, Vector2.new(radius * 2, radius * 2), 0.4)
			made += 1
		end
	end
end

-- The house: walls, floors, the ramp -------------------------------------------------------------

type Gap = { Center: number, Width: number, Height: number? } -- Height nil = full height

--[[
	A straight wall along X (axis "X", at z = `fixed`) or along Z (axis "Z", at x = `fixed`)
	from `from` to `to`, `height` tall standing at y0, with door gaps (a lintel above a gap
	that has a Height).
]]
local function wallLine(
	env: Env,
	axis: string,
	fixed: number,
	from: number,
	to: number,
	y0: number,
	height: number,
	gaps: { Gap },
	parent: Instance,
	color: Color3?,
	material: Enum.Material?
)
	local ctx = env.Ctx
	local paintColor = color or env.Colors.HouseWall
	local mat = material or Enum.Material.Brick
	local function piece(a: number, b: number, bottom: number, top: number)
		if b - a < 0.05 or top - bottom < 0.05 then
			return
		end
		local mid = (a + b) / 2
		local size = if axis == "X"
			then Vector3.new(b - a, top - bottom, WALL)
			else Vector3.new(WALL, top - bottom, b - a)
		local p = if axis == "X"
			then MapBase.at(ctx, mid, fixed, (bottom + top) / 2)
			else MapBase.at(ctx, fixed, mid, (bottom + top) / 2)
		Kit.part({
			Name = "Wall",
			Size = size,
			CFrame = CFrame.new(p),
			Color = paintColor,
			Material = mat,
		}, parent)
	end
	local sorted = table.clone(gaps)
	table.sort(sorted, function(a: Gap, b: Gap)
		return a.Center < b.Center
	end)
	local cursor = from
	for _, gap in sorted do
		local a = gap.Center - gap.Width / 2
		local b = gap.Center + gap.Width / 2
		piece(cursor, a, y0, y0 + height)
		if gap.Height then
			piece(a, b, y0 + gap.Height, y0 + height)
		end
		cursor = b
	end
	piece(cursor, to, y0, y0 + height)
end

-- A part from floor point a to b (map offsets with heights), `width` wide: the ramp.
local function ramp(env: Env, a: Vector3, b: Vector3, width: number, parent: Instance): Part
	local ctx = env.Ctx
	local pa = ctx.Origin + a
	local pb = ctx.Origin + b
	local length = (pb - pa).Magnitude
	local cf = CFrame.lookAt((pa + pb) / 2, pb) * CFrame.new(0, -0.5, 0)
	return Kit.part({
		Name = "Ramp",
		Size = Vector3.new(width, 1, length),
		CFrame = cf,
		Color = env.Colors.Wood,
		Material = Enum.Material.WoodPlanks,
	}, parent)
end

-- A glowing window pane on an outside wall (looks only).
local function window(env: Env, cf: CFrame, parent: Instance)
	Kit.decor({
		Name = "Window",
		Size = Vector3.new(3, 4.5, 0.2),
		CFrame = cf,
		Color = env.Colors.Window,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	}, parent)
	Kit.decor({
		Name = "WindowBar",
		Size = Vector3.new(0.3, 4.5, 0.3),
		CFrame = cf * CFrame.new(0, 0, -0.1),
		Color = env.Colors.HouseTrim,
	}, parent)
end

-- A tall bookshelf full of books against a wall (prop "Bookshelf"), its back on cf (facing
-- cf.LookVector into the room).
local function bookshelf(env: Env, cf: CFrame, rng: Random, parent: Instance): Model
	local colors = env.Colors
	local rows = {}
	for shelf = 1, 4 do
		local row = {}
		for i = 1, 3 do
			row[i] = {
				Color = BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
				Height = rng:NextNumber(1.1, 1.6),
			}
		end
		rows[shelf] = row
	end
	return Kit.prop("Bookshelf", cf, parent, 9, function()
		local m = Kit.model("Bookshelf", parent)
		local w, d, h = 6, 1.6, 9
		local back = Kit.part({
			Name = "Back",
			Size = Vector3.new(w, h, 0.3),
			CFrame = cf * CFrame.new(0, h / 2, -0.15),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, m)
		for _, x in { -1, 1 } do
			Kit.part({
				Name = "Side",
				Size = Vector3.new(0.3, h, d),
				CFrame = cf * CFrame.new(x * (w / 2 - 0.15), h / 2, -d / 2),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
		end
		for shelf, row in rows do
			local y = (shelf - 1) * 2.2 + 0.2
			Kit.part({
				Name = "Shelf",
				Size = Vector3.new(w, 0.3, d),
				CFrame = cf * CFrame.new(0, y, -d / 2),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
			for i, book in row do
				Kit.decor({
					Name = "Books",
					Size = Vector3.new(1.5, book.Height, d - 0.4),
					CFrame = cf * CFrame.new((i - 2) * 1.75, y + 0.15 + book.Height / 2, -d / 2),
					Color = book.Color,
					Material = Enum.Material.Fabric,
				}, m)
			end
		end
		Kit.part({
			Name = "Top",
			Size = Vector3.new(w + 0.4, 0.4, d + 0.3),
			CFrame = cf * CFrame.new(0, h, -d / 2),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, m)
		m.PrimaryPart = back
		return m
	end)
end

-- A hanging cluster of candles (one light) at height y over room point p.
local function hangingLight(env: Env, p: Vector3, parent: Instance, range: number)
	local colors = env.Colors
	local m = Kit.model("HangingCandles", parent)
	local ring = Kit.decor({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 4, 4),
		CFrame = Kit.upright(CFrame.new(env.Ctx.Origin + p)),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, m)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		Kit.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.6, 0.35),
			CFrame = CFrame.new(
				env.Ctx.Origin + p + Vector3.new(math.cos(a) * 1.8, 0.45, math.sin(a) * 1.8)
			),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
	end
	Kit.light(ring, colors.Glow, range, 1.2, true)
	m.PrimaryPart = ring
end

type House = {
	X0: number,
	X1: number,
	Z0: number,
	Z1: number,
	ZM: number, -- the line between the back and front rows
	Cols: { number }, -- the four x lines of the walls (west to east)
	RampZ: { number }, -- the ramp's z from and to
	Rooms: { [string]: Rect }, -- inside of each room (between the walls)
}

local function buildHouse(env: Env, parent: Instance, rng: Random): House
	local def = env.Ctx.Def
	local layout = def.Layout.House
	local colors = env.Colors
	local cx, cz = layout.Offset.X, layout.Offset.Z
	local x0, x1 = cx - layout.Width / 2, cx + layout.Width / 2
	local z0, z1 = cz - layout.Depth / 2, cz + layout.Depth / 2
	local zm = cz
	local third = layout.Width / 3
	local cols = { x0, x0 + third, x0 + third * 2, x1 }
	local h: number = layout.WallHeight
	local upperH: number = layout.UpperWallHeight
	local door: number = layout.DoorWidth
	local doorH: number = layout.DoorHeight
	local backMid = (z0 + zm) / 2
	local frontMid = (zm + z1) / 2
	local function colMid(i: number): number
		return (cols[i] + cols[i + 1]) / 2
	end

	local house = Kit.group("House", parent)
	local walls = Kit.model("HouseWalls", house)

	-- Floorboards (just above the yard, so the yard's Floor stays the open floor outside).
	Kit.part({
		Name = "Boards",
		Size = Vector3.new(layout.Width, BOARDS, layout.Depth),
		CFrame = CFrame.new(MapBase.at(env.Ctx, cx, cz, BOARDS / 2)),
		Color = colors.Boards,
		Material = Enum.Material.WoodPlanks,
	}, house)

	-- Outside walls: front door (Grand Hall), side doors (Parlour, Dining), back door (Kitchen).
	local rampTo = z0 + WALL / 2 + 7
	wallLine(env, "X", z0, x0 - WALL / 2, x1 + WALL / 2, 0, h, {
		{ Center = colMid(3), Width = door, Height = doorH },
	}, walls)
	wallLine(env, "X", z1, x0 - WALL / 2, x1 + WALL / 2, 0, h, {
		{ Center = colMid(2), Width = door + 2, Height = doorH },
	}, walls)
	wallLine(env, "Z", x0, z0 + WALL / 2, z1 - WALL / 2, 0, h, {
		{ Center = frontMid, Width = door, Height = doorH },
	}, walls)
	wallLine(env, "Z", x1, z0 + WALL / 2, z1 - WALL / 2, 0, h, {
		{ Center = frontMid, Width = door, Height = doorH },
	}, walls)
	-- Inside walls with a doorway into every neighbouring room.
	local inner = Kit.shade(colors.HouseWall, -0.08)
	for i = 2, 3 do
		wallLine(env, "Z", cols[i], z0 + WALL / 2, z1 - WALL / 2, 0, h, {
			{ Center = backMid, Width = door, Height = doorH },
			{ Center = frontMid, Width = door, Height = doorH },
		}, walls, inner, Enum.Material.Plaster)
	end
	wallLine(env, "X", zm, x0 + WALL / 2, x1 - WALL / 2, 0, h, {
		{ Center = colMid(1), Width = door, Height = doorH },
		{ Center = colMid(2), Width = door + 2, Height = doorH },
		{ Center = colMid(3), Width = door, Height = doorH },
	}, walls, inner, Enum.Material.Plaster)

	-- Upstairs: the Attic over the Library, the Nursery over the Kitchen, a balcony between.
	local upper = Kit.model("Upstairs", house)
	for _, side in { { cols[1], cols[2] }, { cols[3], cols[4] } } do
		local width = side[2] - side[1]
		Kit.part({
			Name = "UpperBoards",
			Size = Vector3.new(width + WALL, 1, zm - z0 + WALL),
			CFrame = CFrame.new(
				MapBase.at(env.Ctx, (side[1] + side[2]) / 2, (z0 + zm) / 2, UPPER - 0.5)
			),
			Color = colors.Boards,
			Material = Enum.Material.WoodPlanks,
		}, upper)
	end
	local balconyZ = zm - 6
	Kit.part({
		Name = "Balcony",
		Size = Vector3.new(cols[3] - cols[2], 1, zm - balconyZ),
		CFrame = CFrame.new(MapBase.at(env.Ctx, colMid(2), (balconyZ + zm) / 2, UPPER - 0.5)),
		Color = colors.Boards,
		Material = Enum.Material.WoodPlanks,
	}, upper)
	-- Upstairs walls: tall at the back and sides, a low railing over the front rooms.
	local rail = 3.5
	wallLine(env, "X", z0, x0 - WALL / 2, cols[2], UPPER, upperH, {}, upper)
	wallLine(env, "X", z0, cols[3], x1 + WALL / 2, UPPER, upperH, {}, upper)
	wallLine(env, "Z", x0, z0 + WALL / 2, zm + WALL / 2, UPPER, upperH, {}, upper)
	wallLine(env, "Z", x1, z0 + WALL / 2, zm + WALL / 2, UPPER, upperH, {}, upper)
	wallLine(
		env,
		"X",
		zm,
		x0 + WALL / 2,
		x1 - WALL / 2,
		UPPER,
		rail,
		{},
		upper,
		colors.HouseTrim,
		Enum.Material.Wood
	)
	-- Attic's east wall: open where the ramp arrives and onto the balcony.
	wallLine(
		env,
		"Z",
		cols[2],
		rampTo,
		balconyZ,
		UPPER,
		upperH,
		{},
		upper,
		inner,
		Enum.Material.Plaster
	)
	-- Nursery's west wall: open onto the balcony.
	wallLine(
		env,
		"Z",
		cols[3],
		z0 + WALL / 2,
		balconyZ,
		UPPER,
		upperH,
		{},
		upper,
		inner,
		Enum.Material.Plaster
	)
	-- The balcony's back railing (over the Stair Hall).
	wallLine(
		env,
		"X",
		balconyZ,
		cols[2] + WALL / 2,
		cols[3] - WALL / 2,
		UPPER,
		rail,
		{},
		upper,
		colors.HouseTrim,
		Enum.Material.Wood
	)

	-- The ramp up the Stair Hall's back wall, from its east end to the Attic.
	local rampFrom = z0 + WALL / 2
	local rampZ = (rampFrom + rampTo) / 2
	ramp(
		env,
		Vector3.new(cols[3] - 3, 0, rampZ),
		Vector3.new(cols[2] + WALL / 2, UPPER, rampZ),
		rampTo - rampFrom,
		house
	)

	-- Rafters over the front rooms (the roof fell in long ago).
	local rafters = Kit.model("Rafters", house)
	for i = 1, 5 do
		local x = x0 + layout.Width * i / 6
		Kit.decor({
			Name = "Rafter",
			Size = Vector3.new(1, 1, z1 - zm),
			CFrame = CFrame.new(MapBase.at(env.Ctx, x, (zm + z1) / 2, h - 0.5))
				* CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 6 else -4)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, rafters)
	end

	-- Glowing windows on the outside walls.
	local windows = Kit.model("Windows", house)
	for _, x in { -0.4, -0.25, 0.25, 0.4 } do
		window(
			env,
			CFrame.new(MapBase.at(env.Ctx, cx + x * layout.Width, z1 + WALL / 2 + 0.1, 7)),
			windows
		)
	end
	for _, side in { -1, 1 } do
		for _, z in { backMid, frontMid - 6 } do
			window(
				env,
				CFrame.new(
					MapBase.at(env.Ctx, cx + side * (layout.Width / 2 + WALL / 2 + 0.1), z, 7)
				) * CFrame.Angles(0, math.rad(90), 0),
				windows
			)
		end
	end

	-- The porch: a step, two posts, a sign and two lit lanterns.
	local porch = Kit.model("Porch", house)
	local doorX = colMid(2)
	Kit.part({
		Name = "Step",
		Size = Vector3.new(16, 0.5, 5),
		CFrame = CFrame.new(MapBase.at(env.Ctx, doorX, z1 + WALL / 2 + 2.5, 0.25)),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, porch)
	for _, side in { -1, 1 } do
		Kit.part({
			Name = "PorchPost",
			Size = Vector3.new(0.8, h, 0.8),
			CFrame = CFrame.new(
				MapBase.at(env.Ctx, doorX + side * 7.5, z1 + WALL / 2 + 4.5, h / 2)
			),
			Color = colors.HouseTrim,
			Material = Enum.Material.Wood,
		}, porch)
		Props.Lantern(
			env.Paint,
			CFrame.new(MapBase.at(env.Ctx, doorX + side * 7.5, z1 + WALL / 2 + 4.5, 0.5)),
			1.7,
			porch,
			{ Light = true, Range = 16 }
		)
	end
	local sign = Kit.part({
		Name = "Sign",
		Size = Vector3.new(14, 2, 0.4),
		CFrame = CFrame.new(MapBase.at(env.Ctx, doorX, z1 + WALL / 2 + 0.3, doorH + 1.5)),
		Color = colors.HouseTrim,
		Material = Enum.Material.Wood,
		CanCollide = false,
	}, porch)
	Kit.surfaceText(sign, "THE HAUNTED HOUSE", colors.Orange, Enum.NormalId.Back)

	local i0 = WALL / 2
	local rooms: { [string]: Rect } = {
		Library = rect(cols[1] + i0, z0 + i0, cols[2] - i0, zm - i0),
		StairHall = rect(cols[2] + i0, z0 + i0, cols[3] - i0, zm - i0),
		Kitchen = rect(cols[3] + i0, z0 + i0, cols[4] - i0, zm - i0),
		Parlour = rect(cols[1] + i0, zm + i0, cols[2] - i0, z1 - i0),
		GrandHall = rect(cols[2] + i0, zm + i0, cols[3] - i0, z1 - i0),
		Dining = rect(cols[3] + i0, zm + i0, cols[4] - i0, z1 - i0),
		Attic = rect(cols[1] + i0, z0 + i0, cols[2] - i0, zm - i0),
		Nursery = rect(cols[3] + i0, z0 + i0, cols[4] - i0, zm - i0),
	}
	local _ = rng
	return {
		X0 = x0,
		X1 = x1,
		Z0 = z0,
		Z1 = z1,
		ZM = zm,
		Cols = cols,
		RampZ = { rampFrom, rampTo },
		Rooms = rooms,
	}
end

-- Rooms: furniture, lights, portraits, then the things to hide as ----------------------------

local ROOM_KINDS: { [string]: { string } } = {
	Library = {
		"Books",
		"Books",
		"Books",
		"Candle",
		"Skull",
		"Chair",
		"Table",
		"Potion",
		"Lantern",
	},
	StairHall = { "Crate", "Barrel", "Skull", "Candle", "Pumpkin", "Broom", "JackOLantern" },
	Kitchen = {
		"Cauldron",
		"Cauldron",
		"Barrel",
		"Potion",
		"Potion",
		"Crate",
		"Broom",
		"Pumpkin",
		"Table",
	},
	Parlour = { "Chair", "Chair", "Table", "Books", "Candle", "Lantern", "Pumpkin", "Skull" },
	GrandHall = {
		"JackOLantern",
		"Pumpkin",
		"Lantern",
		"Coffin",
		"Candle",
		"Broom",
		"Skull",
		"Barrel",
	},
	Dining = { "Candle", "Potion", "JackOLantern", "Pumpkin", "Table", "Skull", "Books" },
	Attic = { "Crate", "Crate", "Barrel", "Coffin", "Books", "Skull", "Lantern", "Chair", "Broom" },
	Nursery = { "Pumpkin", "JackOLantern", "Chair", "Table", "Books", "Candle", "Skull", "Potion" },
}

local YARD_KINDS = {
	"Pumpkin",
	"Pumpkin",
	"JackOLantern",
	"JackOLantern",
	"Crate",
	"Barrel",
	"HayBale",
	"HayBale",
	"Cauldron",
	"Broom",
	"Lantern",
	"Skull",
	"Gravestone",
	"Coffin",
}

local function center(r: Rect): Vector2
	return (r.Min + r.Max) / 2
end

-- Keeps a doorway clear: a box `depth` deep on both sides of the gap (map offsets).
local function keepDoorClear(list: { Rect }, at: Vector2, alongX: boolean, width: number)
	local size = if alongX then Vector2.new(width + 1, 7) else Vector2.new(7, width + 1)
	reserve(list, at, size, 0)
end

local function furnish(
	env: Env,
	house: House,
	parent: Instance,
	rng: Random,
	spawnSpots: { Vector3 }
)
	local ctx = env.Ctx
	local colors = env.Colors
	local def = ctx.Def
	local layout = def.Layout
	local rooms = house.Rooms
	local cols = house.Cols
	local zm, z0, z1 = house.ZM, house.Z0, house.Z1
	local door: number = layout.House.DoorWidth
	local backMid = (z0 + zm) / 2
	local frontMid = (zm + z1) / 2

	-- Doorways to keep clear (the same for every room: a reserved box only matters where it is).
	local doors: { Rect } = {}
	for i = 2, 3 do
		keepDoorClear(doors, Vector2.new(cols[i], backMid), false, door)
		keepDoorClear(doors, Vector2.new(cols[i], frontMid), false, door)
	end
	for i = 1, 3 do
		keepDoorClear(doors, Vector2.new((cols[i] + cols[i + 1]) / 2, zm), true, door + 2)
	end
	keepDoorClear(doors, Vector2.new((cols[2] + cols[3]) / 2, z1), true, door + 2)
	keepDoorClear(doors, Vector2.new((cols[3] + cols[4]) / 2, z0), true, door)
	keepDoorClear(doors, Vector2.new(cols[1], frontMid), false, door)
	keepDoorClear(doors, Vector2.new(cols[4], frontMid), false, door)

	local furniture = Kit.group("Furniture", parent)
	local things = Kit.group("Things", parent)
	local portraitCount = 0
	local function hangPortrait(cf: CFrame)
		portraitCount += 1
		local kind = Portrait.Kinds[(portraitCount - 1) % #Portrait.Kinds + 1]
		Portrait.Build(
			cf,
			Vector2.new(4.4, 5.6),
			kind,
			{ Frame = colors.Glow, Eyes = colors.Slime },
			furniture
		)
	end
	local function at(x: number, z: number, y: number?): Vector3
		return MapBase.at(ctx, x, z, y)
	end
	local function rug(r: Rect, color: Color3, scale: number)
		local c = center(r)
		local size = (r.Max - r.Min) * scale
		Kit.decor({
			Name = "Rug",
			Size = Vector3.new(size.X, 0.06, size.Y),
			CFrame = CFrame.new(at(c.X, c.Y, BOARDS + 0.03)),
			Color = color,
			Material = Enum.Material.Fabric,
		}, furniture)
	end

	local areas: { Area } = {}
	local function area(name: string, y: number, count: number): Area
		local list = table.clone(doors)
		local a: Area = {
			Name = name,
			Rect = rooms[name],
			Y = y,
			Parent = things,
			Reserved = list,
			Kinds = ROOM_KINDS[name],
			Count = count,
		}
		table.insert(areas, a)
		return a
	end
	local perRoom: number = layout.Props.PerRoom
	local upstairs: number = layout.Props.Upstairs

	-- Library: bookshelves along the back and west walls, a reading light.
	local library = area("Library", BOARDS, perRoom)
	do
		local r = rooms.Library
		for i, x in { -6, 6 } do
			local p = Vector2.new(center(r).X + x, r.Min.Y)
			bookshelf(
				env,
				CFrame.lookAt(at(p.X, p.Y, BOARDS), at(p.X, p.Y + 1, BOARDS)),
				rng,
				furniture
			)
			reserve(library.Reserved, p + Vector2.new(0, 1), Vector2.new(6.4, 2), 0.5)
			local _ = i
		end
		for _, z in { r.Min.Y + 7, r.Max.Y - 6 } do
			local p = Vector2.new(r.Min.X, z)
			bookshelf(
				env,
				CFrame.lookAt(at(p.X, p.Y, BOARDS), at(p.X + 1, p.Y, BOARDS)),
				rng,
				furniture
			)
			reserve(library.Reserved, p + Vector2.new(1, 0), Vector2.new(2, 6.4), 0.5)
		end
		rug(r, colors.RugAlt, 0.5)
		hangingLight(env, Vector3.new(center(r).X, BOARDS + 11.5, center(r).Y), furniture, 26)
	end

	-- Stair Hall: keep the ramp clear, a light at the top.
	local stair = area("StairHall", BOARDS, math.max(perRoom - 3, 1))
	do
		local r = rooms.StairHall
		reserve(
			stair.Reserved,
			Vector2.new(center(r).X, (house.RampZ[1] + house.RampZ[2]) / 2),
			Vector2.new(r.Max.X - r.Min.X, house.RampZ[2] - house.RampZ[1]),
			1.5
		)
		hangingLight(env, Vector3.new(center(r).X, UPPER + 4, center(r).Y + 4), furniture, 30)
		for _, x in { r.Min.X + 0.8, r.Max.X - 0.8 } do
			Props.Cobweb(
				env.Paint,
				CFrame.new(at(x, r.Max.Y - 3, 10)) * CFrame.Angles(0, math.rad(90), 0),
				4,
				furniture
			)
		end
	end

	-- Kitchen: a stove with a glowing fire and a long counter.
	local kitchen = area("Kitchen", BOARDS, perRoom)
	do
		local r = rooms.Kitchen
		local stoveAt = Vector2.new(r.Max.X - 2.5, center(r).Y + 4)
		Kit.part({
			Name = "Stove",
			Size = Vector3.new(4, 4, 6),
			CFrame = CFrame.new(at(stoveAt.X, stoveAt.Y, BOARDS + 2)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, furniture)
		local fire = Kit.decor({
			Name = "Fire",
			Size = Vector3.new(0.3, 1.6, 3.6),
			CFrame = CFrame.new(at(stoveAt.X - 2.05, stoveAt.Y, BOARDS + 1.5)),
			Color = colors.Orange,
			Material = Enum.Material.Neon,
		}, furniture)
		Kit.light(fire, colors.Orange, 22, 1.2, true)
		Kit.part({
			Name = "Chimney",
			Size = Vector3.new(2, 10, 2),
			CFrame = CFrame.new(at(stoveAt.X + 0.5, stoveAt.Y, BOARDS + 9)),
			Color = colors.Stone,
			Material = Enum.Material.Brick,
		}, furniture)
		reserve(kitchen.Reserved, stoveAt, Vector2.new(4, 6), 1)
		local counterAt = Vector2.new(r.Max.X - 1.5, center(r).Y - 6)
		Kit.part({
			Name = "Counter",
			Size = Vector3.new(3, 3.2, 8),
			CFrame = CFrame.new(at(counterAt.X, counterAt.Y, BOARDS + 1.6)),
			Color = colors.Wood,
			Material = Enum.Material.WoodPlanks,
		}, furniture)
		reserve(kitchen.Reserved, counterAt, Vector2.new(3, 8), 1)
		for i = 1, 3 do
			Props.Candle(
				env.Paint,
				CFrame.new(at(counterAt.X, counterAt.Y - 3 + i * 1.6, BOARDS + 3.2)),
				0.7,
				furniture
			)
		end
	end

	-- Parlour: a fireplace on the west wall, armchairs round it, a portrait.
	local parlour = area("Parlour", BOARDS, perRoom)
	do
		local r = rooms.Parlour
		local fireAt = Vector2.new(r.Min.X + 1.5, center(r).Y - 6)
		Kit.part({
			Name = "Fireplace",
			Size = Vector3.new(3, 7, 9),
			CFrame = CFrame.new(at(fireAt.X, fireAt.Y, BOARDS + 3.5)),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, furniture)
		Kit.part({
			Name = "Mantel",
			Size = Vector3.new(3.8, 0.5, 10),
			CFrame = CFrame.new(at(fireAt.X + 0.3, fireAt.Y, BOARDS + 7.2)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, furniture)
		local fire = Kit.decor({
			Name = "Fire",
			Size = Vector3.new(0.4, 2.4, 4.4),
			CFrame = CFrame.new(at(fireAt.X + 1.4, fireAt.Y, BOARDS + 1.5)),
			Color = colors.Orange,
			Material = Enum.Material.Neon,
		}, furniture)
		Kit.light(fire, colors.Orange, 26, 1.4, true)
		reserve(parlour.Reserved, fireAt + Vector2.new(1.5, 0), Vector2.new(6, 10), 0.5)
		for _, dz in { -3.5, 3.5 } do
			local p = fireAt + Vector2.new(7, dz)
			place(env, "Chair", p, BOARDS, rng, things)
			reserve(parlour.Reserved, p, Vector2.new(3.4, 3.4), 0.3)
		end
		rug(r, colors.Rug, 0.55)
		hangPortrait(
			CFrame.lookAt(at(center(r).X, r.Max.Y - 0.05, 8), at(center(r).X, r.Max.Y - 1, 8))
		)
	end

	-- Grand Hall: a long rug from the front door, a grandfather clock, candles overhead.
	local hall = area("GrandHall", BOARDS, perRoom)
	do
		local r = rooms.GrandHall
		local c = center(r)
		Kit.decor({
			Name = "Runner",
			Size = Vector3.new(6, 0.06, r.Max.Y - r.Min.Y),
			CFrame = CFrame.new(at(c.X, c.Y, BOARDS + 0.03)),
			Color = colors.Rug,
			Material = Enum.Material.Fabric,
		}, furniture)
		reserve(hall.Reserved, c, Vector2.new(7, r.Max.Y - r.Min.Y), 0)
		local clockAt = Vector2.new(r.Min.X + 1.5, r.Min.Y + 3)
		local clock = Kit.part({
			Name = "GrandfatherClock",
			Size = Vector3.new(2.4, 9, 2.4),
			CFrame = CFrame.new(at(clockAt.X, clockAt.Y, BOARDS + 4.5)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, furniture)
		Kit.surfaceText(clock, "XII", colors.Glow, Enum.NormalId.Right)
		reserve(hall.Reserved, clockAt, Vector2.new(2.4, 2.4), 0.8)
		hangingLight(env, Vector3.new(c.X, BOARDS + 11, c.Y + 2), furniture, 30)
		for _, side in { -1, 1 } do
			hangPortrait(
				CFrame.lookAt(
					at(c.X + side * 7.5, r.Max.Y - 0.05, 8),
					at(c.X + side * 7.5, r.Max.Y - 1, 8)
				)
			)
		end
	end

	-- Dining Room: a long table with chairs round it (hiders love sitting there).
	local dining = area("Dining", BOARDS, perRoom)
	do
		local r = rooms.Dining
		local c = center(r) + Vector2.new(0, -1)
		Kit.part({
			Name = "DiningTable",
			Size = Vector3.new(5, 0.5, 12),
			CFrame = CFrame.new(at(c.X, c.Y, BOARDS + 3)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, furniture)
		for _, x in { -2, 2 } do
			for _, z in { -5.4, 5.4 } do
				Kit.part({
					Name = "TableLeg",
					Size = Vector3.new(0.5, 2.75, 0.5),
					CFrame = CFrame.new(at(c.X + x, c.Y + z, BOARDS + 1.375)),
					Color = colors.DarkWood,
					Material = Enum.Material.Wood,
				}, furniture)
			end
		end
		local candelabra = Kit.decor({
			Name = "Candelabra",
			Size = Vector3.new(0.6, 1.4, 0.6),
			CFrame = CFrame.new(at(c.X, c.Y, BOARDS + 4)),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, furniture)
		Kit.light(candelabra, colors.Glow, 22, 1.1, true)
		reserve(dining.Reserved, c, Vector2.new(5, 12), 0.5)
		for _, z in { -3.5, 0, 3.5 } do
			for _, side in { -1, 1 } do
				local p = c + Vector2.new(side * 3.9, z)
				local turn = CFrame.lookAt(at(p.X, p.Y, BOARDS), at(c.X, p.Y, BOARDS))
				hideable(chair(env, turn, rng, things))
				reserve(dining.Reserved, p, Vector2.new(3, 3), 0)
			end
		end
		hangPortrait(CFrame.lookAt(at(c.X, r.Max.Y - 0.05, 8), at(c.X, r.Max.Y - 1, 8)))
	end

	-- Attic and Nursery (upstairs).
	local attic = area("Attic", UPPER, upstairs)
	do
		local r = rooms.Attic
		-- keep the way from the ramp and the balcony clear
		reserve(
			attic.Reserved,
			Vector2.new(r.Max.X - 4, (house.RampZ[1] + house.RampZ[2]) / 2),
			Vector2.new(8, house.RampZ[2] - house.RampZ[1]),
			0.5
		)
		reserve(attic.Reserved, Vector2.new(r.Max.X - 4, zm - 3), Vector2.new(8, 7), 0.5)
		hangingLight(env, Vector3.new(center(r).X, UPPER + 7, center(r).Y), furniture, 24)
		Props.Cobweb(
			env.Paint,
			CFrame.new(at(r.Min.X + 0.6, r.Min.Y + 3, UPPER + 5))
				* CFrame.Angles(0, math.rad(90), 0),
			4.5,
			furniture
		)
	end
	local nursery = area("Nursery", UPPER, upstairs)
	do
		local r = rooms.Nursery
		reserve(nursery.Reserved, Vector2.new(r.Min.X + 4, zm - 3), Vector2.new(8, 7), 0.5)
		local bedAt = Vector2.new(r.Max.X - 3, r.Min.Y + 5)
		Kit.part({
			Name = "Bed",
			Size = Vector3.new(5, 2, 8),
			CFrame = CFrame.new(at(bedAt.X, bedAt.Y, UPPER + 1)),
			Color = colors.RugAlt,
			Material = Enum.Material.Fabric,
		}, furniture)
		Kit.part({
			Name = "Headboard",
			Size = Vector3.new(5, 4.5, 0.5),
			CFrame = CFrame.new(at(bedAt.X, bedAt.Y - 4, UPPER + 2.25)),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, furniture)
		reserve(nursery.Reserved, bedAt, Vector2.new(5, 8.5), 0.8)
		hangingLight(env, Vector3.new(center(r).X, UPPER + 7, center(r).Y), furniture, 24)
		Props.Cobweb(
			env.Paint,
			CFrame.new(at(r.Max.X - 0.6, r.Max.Y - 4, UPPER + 5))
				* CFrame.Angles(0, math.rad(90), 0),
			4.5,
			furniture
		)
	end

	-- A few cobwebs in the downstairs corners.
	for _, name in { "Library", "Kitchen", "Parlour", "Dining" } do
		local r = rooms[name]
		Props.Cobweb(
			env.Paint,
			CFrame.new(at(r.Min.X + 0.6, r.Min.Y + 3, 11)) * CFrame.Angles(0, math.rad(90), 0),
			4,
			furniture
		)
	end

	-- Hider spawns in every room first (kept clear), then the things.
	for _, a in areas do
		local p = freeSpot(rng, a.Reserved, a.Rect, 2.5) or center(a.Rect)
		reserve(a.Reserved, p, Vector2.new(5, 5), 0)
		table.insert(spawnSpots, MapBase.at(ctx, p.X, p.Y, a.Y))
	end
	for _, a in areas do
		fill(env, a, rng)
	end
end

-- The yard ---------------------------------------------------------------------------------------

local function buildYard(
	env: Env,
	house: House,
	parent: Instance,
	rng: Random,
	spawnSpots: { Vector3 }
)
	local ctx = env.Ctx
	local colors = env.Colors
	local def = ctx.Def
	local layout = def.Layout
	local half = ctx.Half
	local reserved: { Rect } = {}
	local yard = Kit.group("Yard", parent)
	local things = Kit.group("YardThings", parent)
	local function at(x: number, z: number, y: number?): Vector3
		return MapBase.at(ctx, x, z, y)
	end

	-- The house and its porch.
	reserve(
		reserved,
		Vector2.new((house.X0 + house.X1) / 2, (house.Z0 + house.Z1) / 2),
		Vector2.new(house.X1 - house.X0, house.Z1 - house.Z0),
		3
	)
	local doorX = (house.Cols[2] + house.Cols[3]) / 2
	reserve(reserved, Vector2.new(doorX, house.Z1 + 4), Vector2.new(18, 8), 1)
	-- Side and back doors stay clear.
	local frontMid = (house.ZM + house.Z1) / 2
	reserve(reserved, Vector2.new(house.X0 - 4, frontMid), Vector2.new(8, 12), 0)
	reserve(reserved, Vector2.new(house.X1 + 4, frontMid), Vector2.new(8, 12), 0)
	reserve(
		reserved,
		Vector2.new((house.Cols[3] + house.Cols[4]) / 2, house.Z0 - 4),
		Vector2.new(12, 8),
		0
	)

	-- The Finder Hut, facing the house.
	local hut = layout.FinderHut
	local hutAt = Vector2.new(hut.Offset.X, hut.Offset.Z)
	local hutModel = HideSeekProps.seekerHut(
		CFrame.lookAt(at(hutAt.X, hutAt.Y), at(hut.FacesTowards.X, hut.FacesTowards.Z)),
		hut.Size,
		{
			Wall = colors.HutWall,
			Roof = colors.Roof,
			Trim = colors.HouseTrim,
			Door = colors.HutDoor,
			Glow = colors.Glow,
			Text = colors.HutText,
		},
		hut.Spawns,
		yard
	)
	hutModel.Name = "FinderHut"
	local sign = hutModel:FindFirstChild("Sign")
	local lettering = sign and sign:FindFirstChild("Lettering")
	local text = lettering and lettering:FindFirstChild("Text")
	if text and text:IsA("TextLabel") then
		text.Text = "FINDER HUT"
	end
	reserve(reserved, hutAt, Vector2.new(hut.Size.X + 4, hut.Size.Z + 4), 6)

	-- A stepping-stone path from the hut to the porch, lamp posts beside it.
	local path = Kit.model("Path", yard)
	local fromZ = hutAt.Y - hut.Size.Z / 2 - 4
	local toZ = house.Z1 + 7
	local stones = math.max(2, math.floor((fromZ - toZ) / 4))
	for i = 0, stones do
		local z = fromZ + (toZ - fromZ) * i / stones
		Kit.decor({
			Name = "Stone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 3.4, 3.4),
			CFrame = Kit.upright(
				CFrame.new(at(doorX + (if i % 2 == 0 then -0.6 else 0.6), z, 0.08))
			),
			Color = colors.Path,
			Material = Enum.Material.Slate,
		}, path)
	end
	reserve(
		reserved,
		Vector2.new(doorX, (fromZ + toZ) / 2),
		Vector2.new(6, math.abs(fromZ - toZ)),
		0
	)
	local lamps: number = layout.Lampposts
	for i = 1, lamps do
		local z = toZ + (fromZ - toZ) * (i - 0.5) / lamps
		local side = if i % 2 == 0 then 1 else -1
		local p = Vector2.new(doorX + side * 5, z)
		HideSeekProps.lantern(
			CFrame.lookAt(at(p.X, p.Y), at(doorX, p.Y)),
			{ Iron = colors.Iron, Glow = colors.Glow },
			yard
		)
		reserve(reserved, p, Vector2.new(2, 2), 0.5)
	end

	-- The graveyard: an iron fence (gate on the east side) and rows of gravestones.
	local graves = layout.Graveyard
	local gyard = Kit.group("Graveyard", yard)
	local gc = Vector2.new(graves.Offset.X, graves.Offset.Z)
	local gs = Vector2.new(graves.Size.X, graves.Size.Z)
	local corners = {
		gc + Vector2.new(-gs.X / 2, -gs.Y / 2),
		gc + Vector2.new(gs.X / 2, -gs.Y / 2),
		gc + Vector2.new(gs.X / 2, gs.Y / 2),
		gc + Vector2.new(-gs.X / 2, gs.Y / 2),
	}
	for side = 1, 4 do
		local a, b = corners[side], corners[side % 4 + 1]
		local length = (b - a).Magnitude
		local posts = math.max(1, math.floor(length / 8 + 0.5))
		local last: Vector3? = nil
		for i = 0, posts do
			local t = i / posts
			local p = a:Lerp(b, t)
			-- The gate: no fence in the middle of the east side.
			local gate = side == 2 and math.abs(t - 0.5) < 0.2
			local here = at(p.X, p.Y)
			if not gate then
				Props.FencePost(env.Paint, CFrame.new(here), 4.5, gyard)
				if last then
					Props.FenceSpan(env.Paint, last, here, 4.5, gyard, { Pickets = 3 })
				end
				last = here
			else
				last = nil
			end
		end
	end
	Kit.decor({
		Name = "GraveDirt",
		Size = Vector3.new(gs.X - 2, 0.05, gs.Y - 2),
		CFrame = CFrame.new(at(gc.X, gc.Y, 0.03)),
		Color = Color3.fromRGB(60, 48, 40),
		Material = Enum.Material.Ground,
	}, gyard)
	local gravesWanted: number = graves.Graves
	local rows = math.max(1, math.floor(math.sqrt(gravesWanted)))
	local perRow = math.ceil(gravesWanted / rows)
	local made = 0
	for row = 1, rows do
		for col = 1, perRow do
			if made >= gravesWanted then
				break
			end
			local x = gc.X - gs.X / 2 + 5 + (col - 0.5) * (gs.X - 12) / perRow
			local z = gc.Y - gs.Y / 2 + 5 + (row - 0.5) * (gs.Y - 10) / rows
			local jx, jz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
			local p = Vector2.new(x + jx, z + jz)
			local size = rng:NextNumber(3, 4)
			local style = GRAVE_STYLES[rng:NextInteger(1, #GRAVE_STYLES)]
			local moss = rng:NextNumber() < 0.5
			local tilt = CFrame.Angles(
				0,
				math.rad(180) + rng:NextNumber(-0.25, 0.25),
				rng:NextNumber(-0.08, 0.08)
			)
			hideable(Props.Gravestone(env.Paint, CFrame.new(at(p.X, p.Y)) * tilt, size, gyard, {
				Style = style,
				Moss = moss,
			}))
			made += 1
		end
	end
	-- A glowing lamp at the gate.
	HideSeekProps.lantern(
		CFrame.lookAt(at(gc.X + gs.X / 2 + 2, gc.Y + 6), at(gc.X + gs.X, gc.Y + 6)),
		{ Iron = colors.Iron, Glow = colors.Glow },
		gyard
	)
	reserve(reserved, gc, gs, 3)

	-- The pumpkin patch: rows of pumpkins and jack-o'-lanterns, hay bales, one big lit lantern.
	local patch = layout.PumpkinPatch
	local pgroup = Kit.group("PumpkinPatch", yard)
	local pc = Vector2.new(patch.Offset.X, patch.Offset.Z)
	local ps = Vector2.new(patch.Size.X, patch.Size.Z)
	for i = 1, 4 do
		local z = pc.Y - ps.Y / 2 + (i - 0.5) * ps.Y / 4
		Kit.decor({
			Name = "Furrow",
			Size = Vector3.new(ps.X - 4, 0.3, 3),
			CFrame = CFrame.new(at(pc.X, z, 0.15)),
			Color = Color3.fromRGB(70, 52, 38),
			Material = Enum.Material.Ground,
		}, pgroup)
	end
	local pumpkinsWanted: number = patch.Pumpkins
	local patchReserved: { Rect } = {}
	local bigAt = pc
	Props.JackOLantern(env.Paint, CFrame.new(at(bigAt.X, bigAt.Y)), 4.2, pgroup, { Light = true })
	reserve(patchReserved, bigAt, Vector2.new(6, 6), 0.5)
	local pmade = 0
	for _ = 1, pumpkinsWanted * 4 do
		if pmade >= pumpkinsWanted then
			break
		end
		local kind = if rng:NextNumber() < 0.7
			then "Pumpkin"
			elseif rng:NextNumber() < 0.6 then "JackOLantern"
			else "HayBale"
		local radius = RADIUS[kind]
		local p = freeSpot(
			rng,
			patchReserved,
			rect(pc.X - ps.X / 2, pc.Y - ps.Y / 2, pc.X + ps.X / 2, pc.Y + ps.Y / 2),
			radius
		)
		if p then
			place(env, kind, p, 0, rng, pgroup)
			reserve(patchReserved, p, Vector2.new(radius * 2, radius * 2), 0.6)
			pmade += 1
		end
	end
	reserve(reserved, pc, ps, 3)

	-- Hider spawns round the yard (left, right, behind the house, by the graveyard and patch).
	local yardSpots = {
		Vector2.new(house.X0 - 12, house.ZM - 8),
		Vector2.new(house.X1 + 12, house.ZM - 8),
		Vector2.new(-36, house.Z0 - 12),
		Vector2.new(30, house.Z0 - 14),
		Vector2.new(gc.X + 2, gc.Y - gs.Y / 2 - 9),
		Vector2.new(pc.X - 2, pc.Y - ps.Y / 2 - 9),
	}
	for _, p in yardSpots do
		reserve(reserved, p, Vector2.new(5, 5), 0)
		table.insert(spawnSpots, at(p.X, p.Y))
	end

	-- Dead trees, then things to hide as, on free spots round the yard.
	local area = rect(-half.X + 6, -half.Y + 6, half.X - 6, half.Y - 6)
	local trees = Kit.group("Trees", yard)
	local treeCount: number = layout.DeadTrees
	for _ = 1, treeCount do
		local p = freeSpot(rng, reserved, area, 3)
		if p then
			local height = rng:NextNumber(14, 22)
			local turn = rng:NextNumber(0, math.pi * 2)
			Kit.deadTree(
				CFrame.new(at(p.X, p.Y)) * CFrame.Angles(0, turn, 0),
				height,
				Color3.fromRGB(40, 32, 36),
				rng,
				trees
			)
			reserve(reserved, p, Vector2.new(4, 4), 1)
			local m = Vector2.new(rng:NextNumber(-2, 2), rng:NextNumber(2.5, 3.5))
			Props.Mushrooms(
				env.Paint,
				CFrame.new(at(p.X + m.X, p.Y + m.Y)),
				rng:NextNumber(1, 1.8),
				trees,
				rng
			)
		end
	end
	local yardArea: Area = {
		Name = "Yard",
		Rect = area,
		Y = 0,
		Parent = things,
		Reserved = reserved,
		Kinds = YARD_KINDS,
		Count = layout.Props.Yard,
	}
	fill(env, yardArea, rng)

	-- Bats over the house.
	local bats = Kit.group("Bats", yard)
	local batCount: number = layout.Bats
	for i = 1, batCount do
		local a = i / batCount * math.pi * 2
		local p = Vector3.new(
			math.cos(a) * 30 + rng:NextNumber(-6, 6),
			rng:NextNumber(18, 26),
			house.ZM + math.sin(a) * 22
		)
		Props.Bat(
			env.Paint,
			CFrame.new(ctx.Origin + p) * CFrame.Angles(0, -a, 0),
			rng:NextNumber(1.4, 2),
			bats,
			rng
		)
	end
end

function HauntedHouse.Build(def: any): Model
	local colors = def.Colors
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Grass,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.Slate,
	})
	local model = ctx.Model
	local rng = ctx.Rng
	local env: Env = {
		Ctx = ctx,
		Colors = colors,
		Paint = Kit.painter({
			Wood = colors.Wood,
			Iron = colors.Iron,
			Stone = colors.Stone,
			Bone = colors.Bone,
			Orange = colors.Orange,
			Green = colors.Green,
			Glow = colors.Glow,
			Teal = colors.Slime,
			Straw = colors.Hay,
			Dark = Color3.fromRGB(30, 22, 34),
			Foliage = Color3.fromRGB(60, 100, 50),
		}),
	}

	local spawnSpots: { Vector3 } = {}
	local house = buildHouse(env, model, rng)
	furnish(env, house, model, rng, spawnSpots)
	buildYard(env, house, model, rng, spawnSpots)

	-- Exactly def.Spawns hider spawns (tag HiderSpawn) in the Spawns folder.
	local spawnFolder = model:FindFirstChild(def.SpawnFolder) :: Instance
	spawnFolder:ClearAllChildren()
	local wanted: number = def.Spawns
	for i = 1, wanted do
		local spot = spawnSpots[(i - 1) % math.max(#spawnSpots, 1) + 1]
			or MapBase.at(ctx, math.cos(i) * def.SpawnRadius, math.sin(i) * def.SpawnRadius)
		if i > #spawnSpots then
			spot += Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		end
		HideSeekProps.hiderSpawn(spot, rng, spawnFolder)
	end
	return model
end

return HauntedHouse
