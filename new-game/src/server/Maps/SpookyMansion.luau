--!strict
--[[
	"Spooky Mansion", built from Config.Maps.List[SpookyMansion].Layout.
	A roofless mansion split into a 3x3 grid of rooms. Every pair of neighbouring rooms shares
	a doorway (random position along the wall), so all rooms connect. A few walls also have a
	secret door: a fake bookcase players can walk through but the King can't path through.
	Furniture stays in the middle of each room so doorways along the walls are never blocked.

	  Library       rows of tall bookcases to hide between
	  Gallery       portraits, suits of armour, a curtained alcove (hiding spot)
	  Bedroom       four-poster bed, walk-in wardrobes (hiding spots)
	  Dining        long table with candelabras (hotspot)
	  GrandHall     the spawn room: chandelier, round rug, lanterns
	  Kitchen       counters, a bubbling cauldron, pantry (hiding spot)
	  Conservatory  dead plants and tall hedges (hiding spots)
	  Ballroom      big open checkered floor and chandelier (hotspot, risky)
	  Crypt         coffins, pillars and a stone tomb (hiding spot)
	Repeated decorations are props (Kit.prop), so one model in ReplicatedStorage.Custom.Props
	swaps every copy: JackOLantern, Candle, Cobweb, Cauldron, Coffin.
]]

local Kit = require(script.Parent.Parent.Build.Kit)
local MapBase = require(script.Parent.MapBase)

local SpookyMansion = {}

type Room = {
	Name: string,
	Center: Vector3, -- floor top at the middle of the room
	Model: Model,
	Ctx: MapBase.Ctx,
}

local function c(room: Room, x: number, y: number, z: number): CFrame
	return CFrame.new(room.Center + Vector3.new(x, y, z))
end

local function chandelier(room: Room, height: number)
	local colors = room.Ctx.Def.Colors
	local m = Kit.model("Chandelier", room.Model)
	local ring = Kit.decor({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 9, 9),
		CFrame = Kit.upright(c(room, 0, height, 0)),
		Color = colors.Gold,
		Material = Enum.Material.Metal,
	}, m)
	Kit.decor({
		Name = "Chain",
		Size = Vector3.new(0.3, 6, 0.3),
		CFrame = c(room, 0, height + 3, 0),
		Color = colors.Gold,
		Material = Enum.Material.Metal,
	}, m)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		Kit.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.8, 0.5),
			CFrame = c(room, math.cos(a) * 4.2, height + 0.8, math.sin(a) * 4.2),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
	end
	Kit.light(ring, colors.Glow, 45, 1.6, true)
	m.PrimaryPart = ring
	Kit.float(m, 0.3, room.Ctx.Rng)
end

-- A candle (prop "Candle") whose wax starts `foot`; `height` = wax + flame. Only for looks
-- (a custom candle never blocks anyone either).
local function candle(
	room: Room,
	foot: CFrame,
	height: number,
	light: number,
	build: (m: Model) -> BasePart
): Model
	local colors = room.Ctx.Def.Colors
	return Kit.prop("Candle", foot, room.Model, height, function()
		local m = Kit.model("Candle", room.Model)
		m.PrimaryPart = build(m)
		return m
	end, {
		Light = { Color = colors.Glow, Range = light, Brightness = 0.8, Height = 0.85 },
		Visual = true,
	})
end

local function floatingCandle(room: Room, x: number, y: number, z: number)
	local colors = room.Ctx.Def.Colors
	local m = candle(room, c(room, x, y - 0.8, z), 2.2, 10, function(holder: Model): BasePart
		local wax = Kit.decor({
			Name = "Wax",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 0.6, 0.6),
			CFrame = Kit.upright(c(room, x, y, z)),
			Color = colors.Bone,
		}, holder)
		local flame = Kit.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.6, 0.35),
			CFrame = c(room, x, y + 1.1, z),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, holder)
		Kit.light(flame, colors.Glow, 10, 0.8, true)
		return wax
	end)
	Kit.float(m, 0.8, room.Ctx.Rng)
end

local function rug(room: Room, size: Vector3, color: Color3, round: boolean?)
	if round then
		Kit.decor({
			Name = "Rug",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, size.X, size.X),
			CFrame = Kit.upright(c(room, 0, 0.1, 0)),
			Color = color,
			Material = Enum.Material.Fabric,
		}, room.Model)
	else
		Kit.decor({
			Name = "Rug",
			Size = Vector3.new(size.X, 0.2, size.Z),
			CFrame = c(room, 0, 0.1, 0),
			Color = color,
			Material = Enum.Material.Fabric,
		}, room.Model)
	end
end

local function bookcase(room: Room, cf: CFrame, length: number, height: number, solid: boolean)
	local colors = room.Ctx.Def.Colors
	local props = {
		Name = "Bookcase",
		Size = Vector3.new(length, height, 3),
		CFrame = cf * CFrame.new(0, height / 2, 0),
		Color = colors.DarkWood,
		Material = Enum.Material.Wood,
	}
	local case = if solid then Kit.part(props, room.Model) else Kit.decor(props, room.Model)
	-- Rows of book spines on both faces.
	local bookColors = { colors.Rug, colors.RugAlt, colors.Plant, colors.Gold }
	for shelf = 1, math.floor(height / 2.5) do
		for _, face in { -1, 1 } do
			Kit.decor({
				Name = "Books",
				Size = Vector3.new(length - 0.6, 1.6, 0.2),
				CFrame = cf * CFrame.new(0, shelf * 2.5 - 1, face * 1.55),
				Color = bookColors[(shelf + face) % #bookColors + 1],
			}, room.Model)
		end
	end
	return case
end

-- Rooms -------------------------------------------------------------------------------------

local Rooms: { [string]: (Room) -> () } = {}

function Rooms.Library(room: Room)
	local colors = room.Ctx.Def.Colors
	for _, z in { -14, 0, 14 } do
		bookcase(room, c(room, 0, 0, z), 26, 10, true)
	end
	rug(room, Vector3.new(40, 0, 6), colors.RugAlt)
	for i = 1, 4 do
		floatingCandle(room, -16 + i * 6.5, 12, -7 + (i % 2) * 14)
	end
end

function Rooms.Gallery(room: Room)
	local colors = room.Ctx.Def.Colors
	-- Portraits hang high on all four walls (above the doorways) with glowing eyes.
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		for _, along in { -14, 0, 14 } do
			local x = side[1] * 27.6 + (if side[1] == 0 then along else 0)
			local z = side[2] * 27.6 + (if side[2] == 0 then along else 0)
			local cf = CFrame.lookAt(
				room.Center + Vector3.new(x, 14, z),
				room.Center + Vector3.new(0, 14, 0)
			)
			Kit.decor({
				Name = "Frame",
				Size = Vector3.new(6, 4.4, 0.3),
				CFrame = cf,
				Color = colors.Gold,
				Material = Enum.Material.Metal,
			}, room.Model)
			Kit.decor({
				Name = "Painting",
				Size = Vector3.new(5.2, 3.6, 0.2),
				CFrame = cf * CFrame.new(0, 0, -0.1),
				Color = colors.RugAlt:Lerp(colors.Trim, 0.5),
			}, room.Model)
			for _, ex in { -0.7, 0.7 } do
				Kit.decor({
					Name = "Eye",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.4, 0.4, 0.4),
					CFrame = cf * CFrame.new(ex, 0.4, -0.25),
					Color = colors.Slime,
					Material = Enum.Material.Neon,
				}, room.Model)
			end
		end
	end
	-- Suits of armour.
	for _, p in { { -16, -16 }, { 16, -16 }, { -16, 16 }, { 16, 16 } } do
		Kit.part({
			Name = "Armour",
			Size = Vector3.new(2.4, 6, 1.6),
			CFrame = c(room, p[1], 3, p[2]),
			Color = colors.Stone,
			Material = Enum.Material.DiamondPlate,
		}, room.Model)
		Kit.decor({
			Name = "Helmet",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = c(room, p[1], 6.9, p[2]),
			Color = colors.Stone,
			Material = Enum.Material.DiamondPlate,
		}, room.Model)
	end
	Kit.hidingSpot({
		Name = "CurtainAlcove",
		Size = Vector3.new(7, 9, 7),
		CFrame = c(room, 0, 4.5, 0),
		Color = colors.Curtain,
		Material = Enum.Material.Fabric,
		Transparency = 0.2,
	}, room.Model)
	rug(room, Vector3.new(44, 0, 8), colors.Rug)
end

function Rooms.Bedroom(room: Room)
	local colors = room.Ctx.Def.Colors
	Kit.part({
		Name = "Bed",
		Size = Vector3.new(10, 3, 14),
		CFrame = c(room, 0, 1.5, -8),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, room.Model)
	Kit.decor({
		Name = "Blanket",
		Size = Vector3.new(10.2, 0.6, 10),
		CFrame = c(room, 0, 3.2, -6),
		Color = colors.RugAlt,
		Material = Enum.Material.Fabric,
	}, room.Model)
	for _, p in { { -4.6, -14.6 }, { 4.6, -14.6 }, { -4.6, -1.4 }, { 4.6, -1.4 } } do
		Kit.part({
			Name = "BedPost",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = c(room, p[1], 4.5, p[2]),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
		}, room.Model)
	end
	for _, x in { -16, 16 } do
		Kit.hidingSpot({
			Name = "Wardrobe",
			Size = Vector3.new(6, 9, 5),
			CFrame = c(room, x, 4.5, 12),
			Color = colors.DarkWood,
			Material = Enum.Material.Wood,
			Transparency = 0.15,
		}, room.Model)
	end
	rug(room, Vector3.new(24, 0, 20), colors.Rug)
	floatingCandle(room, -7, 8, 2)
	floatingCandle(room, 7, 8, 2)
end

function Rooms.Dining(room: Room)
	local colors = room.Ctx.Def.Colors
	Kit.part({
		Name = "Table",
		Size = Vector3.new(30, 3.4, 7),
		CFrame = c(room, 0, 1.7, 0),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, room.Model)
	Kit.decor({
		Name = "Cloth",
		Size = Vector3.new(30.4, 0.2, 7.4),
		CFrame = c(room, 0, 3.45, 0),
		Color = colors.Bone,
		Material = Enum.Material.Fabric,
	}, room.Model)
	for x = -12, 12, 6 do
		for _, side in { -1, 1 } do
			Kit.part({
				Name = "Chair",
				Size = Vector3.new(2.6, 5, 2.6),
				CFrame = c(room, x, 2.5, side * 5.5),
				Color = colors.DarkWood,
				Material = Enum.Material.Wood,
			}, room.Model)
		end
	end
	for _, x in { -10, 0, 10 } do
		candle(room, c(room, x, 3.6, 0), 2.8, 18, function(m: Model): BasePart
			local stick = Kit.decor({
				Name = "Candelabra",
				Size = Vector3.new(0.6, 2, 0.6),
				CFrame = c(room, x, 4.6, 0),
				Color = colors.Gold,
				Material = Enum.Material.Metal,
			}, m)
			local flame = Kit.decor({
				Name = "Flame",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.8, 0.5),
				CFrame = c(room, x, 6, 0),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, m)
			Kit.light(flame, colors.Glow, 18, 1.2, true)
			return stick
		end)
	end
	-- A row of jack-o'-lanterns as the feast.
	for _, x in { -5, 5 } do
		Kit.jackOLantern(c(room, x, 3.5, 0), 1.6, colors, room.Model)
	end
	rug(room, Vector3.new(40, 0, 18), colors.Rug)
end

function Rooms.GrandHall(room: Room)
	local colors = room.Ctx.Def.Colors
	rug(room, Vector3.new(30, 0, 30), colors.Rug, true)
	chandelier(room, 14)
	-- Pedestals with jack-o'-lanterns in the corners, clear of the spawn ring.
	for _, p in { { -22, -22 }, { 22, -22 }, { -22, 22 }, { 22, 22 } } do
		Kit.part({
			Name = "Pedestal",
			Size = Vector3.new(3, 4, 3),
			CFrame = c(room, p[1], 2, p[2]),
			Color = colors.Stone,
			Material = Enum.Material.Marble,
		}, room.Model)
		Kit.jackOLantern(
			CFrame.lookAt(
				room.Center + Vector3.new(p[1], 4, p[2]),
				room.Center + Vector3.new(0, 4, 0)
			),
			2.6,
			colors,
			room.Model
		)
	end
end

function Rooms.Kitchen(room: Room)
	local colors = room.Ctx.Def.Colors
	for _, x in { -18, 18 } do
		Kit.part({
			Name = "Counter",
			Size = Vector3.new(4, 4, 28),
			CFrame = c(room, x, 2, -2),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, room.Model)
		Kit.decor({
			Name = "CounterTop",
			Size = Vector3.new(4.4, 0.4, 28.4),
			CFrame = c(room, x, 4.2, -2),
			Color = colors.Stone,
			Material = Enum.Material.Marble,
		}, room.Model)
	end
	-- A bubbling cauldron (prop "Cauldron", like the lobby's big one).
	Kit.prop("Cauldron", c(room, 0, 0, -4), room.Model, 4.2, function()
		local m = Kit.model("Cauldron", room.Model)
		local pot = Kit.part({
			Name = "Cauldron",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 7, 7),
			CFrame = Kit.upright(c(room, 0, 2, -4)),
			Color = Color3.fromRGB(30, 28, 34),
			Material = Enum.Material.Metal,
		}, m)
		local brew = Kit.decor({
			Name = "Brew",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 6, 6),
			CFrame = Kit.upright(c(room, 0, 4, -4)),
			Color = colors.Slime,
			Material = Enum.Material.Neon,
		}, m)
		Kit.particles(brew, {
			Rate = 6,
			Color = ColorSequence.new(colors.Slime),
			LightEmission = 0.8,
			Size = NumberSequence.new(0.6),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
		})
		Kit.light(pot, colors.Slime, 20, 1.2, true)
		m.PrimaryPart = pot
		return m
	end, { Light = { Color = colors.Slime, Range = 20, Brightness = 1.2, Height = 0.8 } })
	Kit.hidingSpot({
		Name = "Pantry",
		Size = Vector3.new(7, 9, 5),
		CFrame = c(room, 8, 4.5, 16),
		Color = colors.DarkWood,
		Material = Enum.Material.WoodPlanks,
		Transparency = 0.15,
	}, room.Model)
	for i = 1, 4 do
		Kit.decor({
			Name = "HangingPot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.4, 1.6),
			CFrame = c(room, -18 + (i % 2) * 36, 11, -12 + i * 4),
			Color = Color3.fromRGB(120, 80, 60),
			Material = Enum.Material.Metal,
		}, room.Model)
	end
end

function Rooms.Conservatory(room: Room)
	local colors = room.Ctx.Def.Colors
	local rng = room.Ctx.Rng
	for _, p in { { -14, -14 }, { 0, -16 }, { 14, -14 }, { -14, 14 }, { 14, 14 } } do
		Kit.part({
			Name = "PlantPot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 3, 3),
			CFrame = Kit.upright(c(room, p[1], 1.2, p[2])),
			Color = Color3.fromRGB(150, 80, 60),
			Material = Enum.Material.Brick,
		}, room.Model)
		for _ = 1, 4 do
			local h = rng:NextNumber(3, 6)
			Kit.decor({
				Name = "Stalk",
				Size = Vector3.new(0.3, h, 0.3),
				CFrame = c(room, p[1], 2.4 + h / 2, p[2])
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)),
				Color = colors.Plant:Lerp(colors.Wood, 0.5),
			}, room.Model)
		end
	end
	for _, p in { { -10, 0 }, { 10, 0 }, { 0, 10 } } do
		Kit.hidingSpot({
			Name = "Hedge",
			Size = Vector3.new(8, 7, 4),
			CFrame = c(room, p[1], 3.5, p[2]),
			Color = colors.Plant,
			Material = Enum.Material.LeafyGrass,
			Transparency = 0.15,
		}, room.Model)
	end
end

function Rooms.Ballroom(room: Room)
	local colors = room.Ctx.Def.Colors
	local tile = 5
	for ix = -4, 3 do
		for iz = -4, 3 do
			Kit.decor({
				Name = "Tile",
				Size = Vector3.new(tile, 0.15, tile),
				CFrame = c(room, (ix + 0.5) * tile, 0.08, (iz + 0.5) * tile),
				Color = if (ix + iz) % 2 == 0 then colors.Bone else colors.Trim,
				Material = Enum.Material.Marble,
			}, room.Model)
		end
	end
	chandelier(room, 14)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		floatingCandle(room, math.cos(a) * 22, 9, math.sin(a) * 22)
	end
end

function Rooms.Crypt(room: Room)
	local colors = room.Ctx.Def.Colors
	local rng = room.Ctx.Rng
	for _, p in { { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } } do
		Kit.part({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 3, 3),
			CFrame = Kit.upright(c(room, p[1], 7, p[2])),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, room.Model)
		Kit.cobweb(
			CFrame.lookAt(
				room.Center + Vector3.new(p[1], 11, p[2]) * 1.1,
				room.Center + Vector3.new(0, 11, 0)
			),
			3,
			colors.Bone,
			room.Model
		)
	end
	for _, p in { { -6, -16 }, { 6, -16 }, { -18, 0 }, { 18, 0 }, { -6, 16 }, { 6, 16 } } do
		local foot = c(room, p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		Kit.prop("Coffin", foot, room.Model, 2, function()
			local m = Kit.model("Coffin", room.Model)
			m.PrimaryPart = Kit.part({
				Name = "Coffin",
				Size = Vector3.new(3, 2, 7),
				CFrame = foot * CFrame.new(0, 1, 0),
				Color = colors.DarkWood,
				Material = Enum.Material.Wood,
			}, m)
			return m
		end)
	end
	Kit.hidingSpot({
		Name = "Tomb",
		Size = Vector3.new(6, 8, 6),
		CFrame = c(room, 0, 4, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
		Transparency = 0.2,
	}, room.Model)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local x, z = math.cos(a) * 8, math.sin(a) * 8
		candle(room, c(room, x, 0, z), 1, 10, function(m: Model): BasePart
			local flame = Kit.decor({
				Name = "Candle",
				Size = Vector3.new(0.5, 1, 0.5),
				CFrame = c(room, x, 0.5, z),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, m)
			Kit.light(flame, colors.Glow, 10, 0.8, true)
			return flame
		end)
	end
end

-- Walls -------------------------------------------------------------------------------------

type Gap = { Center: number, Width: number, Secret: boolean }

-- One wall segment from s0 to s1 along an axis at `fixed`, with gaps cut out of it.
local function buildSegment(
	ctx: MapBase.Ctx,
	parent: Instance,
	vertical: boolean, -- true: runs along z at x = fixed
	fixed: number,
	s0: number,
	s1: number,
	gaps: { Gap }
)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local h: number, t: number = layout.WallHeight, layout.WallThickness
	local function piece(a: number, b: number, y0: number, y1: number, name: string)
		local length = b - a
		if length <= 0.1 then
			return
		end
		local mid = (a + b) / 2
		local size = if vertical
			then Vector3.new(t, y1 - y0, length)
			else Vector3.new(length, y1 - y0, t)
		local pos = if vertical
			then MapBase.at(ctx, fixed, mid, (y0 + y1) / 2)
			else MapBase.at(ctx, mid, fixed, (y0 + y1) / 2)
		Kit.part({
			Name = name,
			Size = size,
			CFrame = CFrame.new(pos),
			Color = colors.Wall,
			Material = Enum.Material.Plaster,
		}, parent)
		-- Dark skirting board along the bottom.
		if y0 == 0 then
			Kit.decor({
				Name = "Skirting",
				Size = if vertical
					then Vector3.new(t + 0.3, 1.2, length)
					else Vector3.new(length, 1.2, t + 0.3),
				CFrame = CFrame.new(
					if vertical
						then MapBase.at(ctx, fixed, mid, 0.6)
						else MapBase.at(ctx, mid, fixed, 0.6)
				),
				Color = colors.Trim,
				Material = Enum.Material.Wood,
			}, parent)
		end
	end
	table.sort(gaps, function(a, b)
		return a.Center < b.Center
	end)
	local cursor = s0
	for _, gap in gaps do
		local a, b = gap.Center - gap.Width / 2, gap.Center + gap.Width / 2
		piece(cursor, a, 0, h, "Wall")
		piece(a, b, layout.DoorHeight, h, "Lintel")
		cursor = b
		if gap.Secret then
			-- A fake bookcase fills the gap: walk-through for players, and the King's paths
			-- avoid it (Config.King.Path.Costs.SecretDoor = math.huge).
			local mid = gap.Center
			local cf = if vertical
				then CFrame.new(MapBase.at(ctx, fixed, mid, 0)) * CFrame.Angles(0, math.pi / 2, 0)
				else CFrame.new(MapBase.at(ctx, mid, fixed, 0))
			local room: Room =
				{ Name = "SecretDoor", Center = Vector3.zero, Model = parent :: Model, Ctx = ctx }
			local case = bookcase(room, cf, gap.Width, layout.DoorHeight, false)
			case.Name = "SecretDoor"
			case.CanQuery = true -- still blocks the King's view
			local modifier = Instance.new("PathfindingModifier")
			modifier.Label = "SecretDoor"
			modifier.PassThrough = false
			modifier.Parent = case
		end
	end
	piece(cursor, s1, 0, h, "Wall")
end

function SpookyMansion.Build(def: any): Model
	local colors = def.Colors
	local layout = def.Layout
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.WoodPlanks,
		WallColor = colors.OuterWall,
		WallMaterial = Enum.Material.Brick,
	})
	local model = ctx.Model
	local rng = ctx.Rng
	local cell = def.Size.X / 3
	local half = def.Size.X / 2

	-- Interior walls: lines between the columns (vertical) and rows (horizontal), each split
	-- into one segment per room it borders, each segment with one doorway.
	local walls = Kit.model("InnerWalls", model)
	type Segment = { Vertical: boolean, Fixed: number, S0: number, S1: number, Gaps: { Gap } }
	local segments: { Segment } = {}
	for _, vertical in { true, false } do
		for line = 1, 2 do
			local fixed = -half + line * cell
			for k = 0, 2 do
				local s0, s1 = -half + k * cell, -half + (k + 1) * cell
				local margin = layout.DoorWidth
				local door = rng:NextNumber(s0 + margin, s1 - margin)
				table.insert(segments, {
					Vertical = vertical,
					Fixed = fixed,
					S0 = s0,
					S1 = s1,
					Gaps = { { Center = door, Width = layout.DoorWidth, Secret = false } },
				})
			end
		end
	end
	-- Secret doors on random segments, away from that segment's real doorway.
	local order: { number } = {}
	for i = 1, #segments do
		table.insert(order, rng:NextInteger(1, i), i)
	end
	for n = 1, math.min(layout.SecretDoors, #segments) do
		local seg = segments[order[n]]
		local door = seg.Gaps[1].Center
		local need = (layout.DoorWidth + layout.SecretDoorWidth) / 2 + 3
		for _ = 1, 20 do
			local at =
				rng:NextNumber(seg.S0 + layout.SecretDoorWidth, seg.S1 - layout.SecretDoorWidth)
			if math.abs(at - door) > need then
				table.insert(
					seg.Gaps,
					{ Center = at, Width = layout.SecretDoorWidth, Secret = true }
				)
				break
			end
		end
	end
	for _, seg in segments do
		buildSegment(ctx, walls, seg.Vertical, seg.Fixed, seg.S0, seg.S1, seg.Gaps)
	end

	-- Rooms, furnished by name; every room also gets wall sconces, cobwebs and a soft light.
	for index, name in layout.Rooms do
		local col = (index - 1) % 3
		local row = (index - 1) // 3
		local x = -half + (col + 0.5) * cell
		local z = -half + (row + 0.5) * cell
		local room: Room = {
			Name = name,
			Center = MapBase.at(ctx, x, z, 0),
			Model = Kit.model(name, model),
			Ctx = ctx,
		}
		local furnish = Rooms[name]
		if furnish then
			furnish(room)
		end
		local inner = cell / 2 - layout.WallThickness / 2 - 0.4
		for _, side in { -1, 1 } do
			local sconce = Kit.decor({
				Name = "Sconce",
				Size = Vector3.new(0.6, 1.2, 0.6),
				CFrame = c(room, side * inner, layout.DoorHeight + 1.5, side * 8),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, room.Model)
			Kit.light(sconce, colors.Glow, 20, 1, true)
			Kit.cobweb(
				CFrame.lookAt(
					room.Center
						+ Vector3.new(
							side * (inner - 1.2),
							layout.WallHeight - 2,
							-side * (inner - 1.2)
						),
					room.Center + Vector3.new(0, layout.WallHeight - 2, 0)
				),
				4,
				colors.Bone,
				room.Model
			)
		end
		local fill =
			Kit.holder("RoomLight", c(room, 0, layout.WallHeight - 1, 0), Vector3.one, room.Model)
		Kit.light(fill, colors.Glow:Lerp(colors.Wall, 0.4), cell * 0.7, 0.5, false)
		if table.find(layout.Hotspots, name) then
			MapBase.hotspot(ctx, Vector3.new(x, 0, z), Vector3.new(cell - 10, 0, cell - 10))
		end
	end

	return model
end

return SpookyMansion
