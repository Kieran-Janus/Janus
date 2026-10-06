--!strict
--[[
	"Haunted Pumpkin Patch", built from Config.Maps.List[PumpkinPatch].Layout.
	  centre      spawn clearing with a scarecrow lantern
	  north-east  corn maze: tall rows block the King's view, gaps are the way through
	  north-west  barn with doors at both ends (a shortcut) and hay to hide in
	  south-west  open pumpkin field: extra pumpkins, nowhere to hide (risky hotspot)
	  south-east  graveyard with tombstones and a mausoleum
	  everywhere  walk-in haystacks (hiding spots), low jump fences only players can cross,
	              hay bales, dead trees, lanterns and jack-o'-lanterns
]]

local Kit = require(script.Parent.Parent.Build.Kit)
local MapBase = require(script.Parent.MapBase)

local PumpkinPatch = {}

type Rect = { Center: Vector2, Half: Vector2 }

local function overlaps(a: Rect, b: Rect): boolean
	return math.abs(a.Center.X - b.Center.X) < a.Half.X + b.Half.X
		and math.abs(a.Center.Y - b.Center.Y) < a.Half.Y + b.Half.Y
end

-- Scatter helper: finds a free spot of radius `r` outside the clearing and every reserved area.
local function freeSpot(ctx: MapBase.Ctx, reserved: { Rect }, r: number, clearing: number): Vector2?
	local margin = 6 + r
	for _ = 1, 60 do
		local p = Vector2.new(
			ctx.Rng:NextNumber(-ctx.Half.X + margin, ctx.Half.X - margin),
			ctx.Rng:NextNumber(-ctx.Half.Y + margin, ctx.Half.Y - margin)
		)
		if p.Magnitude > clearing + r then
			local rect = { Center = p, Half = Vector2.new(r, r) }
			local free = true
			for _, other in reserved do
				if overlaps(rect, other) then
					free = false
					break
				end
			end
			if free then
				table.insert(reserved, rect)
				return p
			end
		end
	end
	return nil
end

local function reserve(reserved: { Rect }, offset: Vector3, size: Vector3, pad: number)
	table.insert(reserved, {
		Center = Vector2.new(offset.X, offset.Z),
		Half = Vector2.new(size.X / 2 + pad, size.Z / 2 + pad),
	})
end

-- A plain pumpkin sitting on cf, `size` studs tall without its stem (prop "Pumpkin").
local function decorPumpkin(cf: CFrame, size: number, colors: any, parent: Instance)
	Kit.prop("Pumpkin", cf, parent, size * 1.25, function()
		local m = Kit.model("Pumpkin", parent)
		m.PrimaryPart = Kit.decor({
			Name = "Pumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 1.2, size, size * 1.2),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			Color = colors.Orange,
		}, m)
		Kit.decor({
			Name = "Stem",
			Size = Vector3.new(size * 0.15, size * 0.3, size * 0.15),
			CFrame = cf * CFrame.new(0, size + size * 0.1, 0),
			Color = colors.Green,
		}, m)
		return m
	end)
end

-- A lamp on a wooden post with a glowing lamp hanging from its arm (prop "Lamppost").
local function lantern(ctx: MapBase.Ctx, pos: Vector3, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Lamppost", CFrame.new(pos), parent, 9, function()
		local m = Kit.model("Lamppost", parent)
		m.PrimaryPart = Kit.part({
			Name = "Post",
			Size = Vector3.new(0.6, 9, 0.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Arm",
			Size = Vector3.new(2.4, 0.3, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(1, 8.7, 0)),
			Color = colors.Iron,
		}, m)
		local glass = Kit.decor({
			Name = "Lamp",
			Size = Vector3.new(1.1, 1.4, 1.1),
			CFrame = CFrame.new(pos + Vector3.new(2, 7.7, 0)),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
		Kit.light(glass, colors.Glow, 22, 1.4, true)
		return m
	end, { Light = { Color = colors.Glow, Range = 22, Brightness = 1.4, Height = 0.85 } })
end

-- A scarecrow with a jack-o'-lantern head standing on `base` (prop "Scarecrow").
local function scarecrow(ctx: MapBase.Ctx, base: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Scarecrow", base, parent, 12.6, function()
		local m = Kit.model("Scarecrow", parent)
		m.PrimaryPart = Kit.part({
			Name = "Pole",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = base * CFrame.new(0, 4.5, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Arms",
			Size = Vector3.new(7, 0.6, 0.6),
			CFrame = base * CFrame.new(0, 6.5, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Shirt",
			Size = Vector3.new(3, 3, 1.4),
			CFrame = base * CFrame.new(0, 6, 0),
			Color = colors.Barn:Lerp(colors.Hay, 0.4),
			Material = Enum.Material.Fabric,
		}, m)
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Straw",
				Size = Vector3.new(0.8, 0.8, 0.8),
				CFrame = base * CFrame.new(side * 3.7, 6.5, 0) * CFrame.Angles(0, 0, math.rad(45)),
				Color = colors.Hay,
				Material = Enum.Material.Grass,
			}, m)
		end
		local head = Kit.jackOLantern(base * CFrame.new(0, 7.6, 0), 2.6, colors, m)
		for _, d in head:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		Kit.decor({
			Name = "HatBrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 4, 4),
			CFrame = Kit.upright(base * CFrame.new(0, 10.4, 0)),
			Color = colors.Iron,
		}, m)
		Kit.decor({
			Name = "Hat",
			Size = Vector3.new(1.6, 2.2, 1.6),
			CFrame = base * CFrame.new(0, 11.5, 0) * CFrame.Angles(0, 0, math.rad(8)),
			Color = colors.Iron,
		}, m)
		return m
	end)
end

-- A rectangular hay bale standing on cf (prop "HayBale", like the Hide & Seek maps').
local function hayBale(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("HayBale", cf, parent, 2.6, function()
		local m = Kit.model("HayBale", parent)
		m.PrimaryPart = Kit.part({
			Name = "HayBale",
			Size = Vector3.new(4, 2.6, 2.6),
			CFrame = cf * CFrame.new(0, 1.3, 0),
			Color = colors.Hay,
			Material = Enum.Material.Grass,
		}, m)
		return m
	end)
end

--[[
	A walk-in haystack standing on `foot`: the hiding spot (tag HidingSpot: it hides you from
	the King) is a see-through cylinder (`size` = height, width, width); `top` adds a round
	top. Its look is prop "Haystack" (Kit.look): your own model replaces the look, and the
	spot (now invisible) keeps hiding you.
]]
local function haystack(
	ctx: MapBase.Ctx,
	name: string,
	foot: Vector3,
	size: Vector3,
	top: boolean,
	parent: Instance
)
	local colors = ctx.Def.Colors
	local spot = Kit.hidingSpot({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = size,
		CFrame = Kit.upright(CFrame.new(foot + Vector3.new(0, size.X / 2, 0))),
		Color = colors.Hay,
		Material = Enum.Material.Grass,
		Transparency = 0.2,
	}, parent)
	local height = if top then size.X + 3 else size.X -- (the round top pokes 3 studs out)
	Kit.look(
		"Haystack",
		spot,
		CFrame.new(foot),
		height,
		if top
			then function(): Model
				local m = Kit.model("Haystack", spot)
				m.PrimaryPart = Kit.decor({
					Name = name .. "Top",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(7, 7, 7),
					CFrame = CFrame.new(foot + Vector3.new(0, height - 3.5, 0)),
					Color = colors.Hay,
					Material = Enum.Material.Grass,
					Transparency = 0.2,
				}, m)
				return m
			end
			else nil
	)
end

local function buildCornMaze(ctx: MapBase.Ctx, parent: Model)
	local cfg = ctx.Def.Layout.CornMaze
	local colors = ctx.Def.Colors
	local folder = Kit.model("CornMaze", parent)
	local offset: Vector3, size: Vector3 = cfg.Offset, cfg.Size
	local halfX = size.X / 2
	local rows = math.floor(size.Z / cfg.RowSpacing) + 1
	for row = 0, rows - 1 do
		local z = offset.Z - size.Z / 2 + row * cfg.RowSpacing
		-- Pick gap centres along the row, kept apart and away from the row ends.
		local gaps: { number } = {}
		for _ = 1, cfg.GapsPerRow do
			for _ = 1, 20 do
				local c = ctx.Rng:NextNumber(-halfX + cfg.GapWidth, halfX - cfg.GapWidth)
				local ok = true
				for _, g in gaps do
					if math.abs(g - c) < cfg.GapWidth * 2 then
						ok = false
					end
				end
				if ok then
					table.insert(gaps, c)
					break
				end
			end
		end
		table.sort(gaps)
		local cursor = -halfX
		local pieces: { { number } } = {}
		for _, g in gaps do
			table.insert(pieces, { cursor, g - cfg.GapWidth / 2 })
			cursor = g + cfg.GapWidth / 2
		end
		table.insert(pieces, { cursor, halfX })
		for _, piece in pieces do
			local length = piece[2] - piece[1]
			if length > 0.5 then
				local x = offset.X + (piece[1] + piece[2]) / 2
				Kit.part({
					Name = "CornRow",
					Size = Vector3.new(length, size.Y, 2),
					CFrame = CFrame.new(MapBase.at(ctx, x, z, size.Y / 2)),
					Color = colors.Corn,
					Material = Enum.Material.Grass,
				}, folder)
				-- Tassels along the top so the rows read as corn, not walls.
				local tufts = math.floor(length / 4)
				for t = 0, tufts - 1 do
					local tx = offset.X + piece[1] + (t + 0.5) * (length / math.max(tufts, 1))
					Kit.decor({
						Name = "Tassel",
						Size = Vector3.new(1.2, 1.6, 1.2),
						CFrame = CFrame.new(MapBase.at(ctx, tx, z, size.Y + 0.6))
							* CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi), math.rad(20)),
						Color = colors.CornTop,
						Material = Enum.Material.Grass,
					}, folder)
				end
			end
		end
	end
	-- The middle of the maze is worth the trip.
	MapBase.hotspot(ctx, offset, Vector3.new(size.X * 0.5, 0, size.Z * 0.5))
end

local function buildBarn(ctx: MapBase.Ctx, parent: Model)
	local cfg = ctx.Def.Layout.Barn
	local colors = ctx.Def.Colors
	local folder = Kit.model("Barn", parent)
	local o: Vector3, s: Vector3 = cfg.Offset, cfg.Size
	local t = 1.5
	local function wall(x: number, z: number, size: Vector3, color: Color3?)
		Kit.part({
			Name = "BarnWall",
			Size = size,
			CFrame = CFrame.new(MapBase.at(ctx, o.X + x, o.Z + z, size.Y / 2)),
			Color = color or colors.Barn,
			Material = Enum.Material.WoodPlanks,
		}, folder)
	end
	-- Long sides.
	for _, side in { -1, 1 } do
		wall(side * s.X / 2, 0, Vector3.new(t, s.Y, s.Z))
	end
	-- Ends, each with a big door gap (the barn is a shortcut) and a lintel above it.
	local sideWidth = (s.X - cfg.DoorWidth) / 2
	for _, side in { -1, 1 } do
		local z = side * s.Z / 2
		for _, lr in { -1, 1 } do
			wall(lr * (cfg.DoorWidth / 2 + sideWidth / 2), z, Vector3.new(sideWidth, s.Y, t))
		end
		Kit.part({
			Name = "Lintel",
			Size = Vector3.new(cfg.DoorWidth, s.Y - cfg.DoorHeight, t),
			CFrame = CFrame.new(
				MapBase.at(ctx, o.X, o.Z + z, cfg.DoorHeight + (s.Y - cfg.DoorHeight) / 2)
			),
			Color = colors.Bone,
			Material = Enum.Material.WoodPlanks,
		}, folder)
		-- White X trim on the open doors, folded back against the wall.
		for _, lr in { -1, 1 } do
			Kit.decor({
				Name = "DoorTrim",
				Size = Vector3.new(0.4, cfg.DoorHeight * 1.2, 0.4),
				CFrame = CFrame.new(
					MapBase.at(
						ctx,
						o.X + lr * (cfg.DoorWidth / 2 + sideWidth / 2),
						o.Z + z + side * (t / 2 + 0.25),
						cfg.DoorHeight / 2
					)
				) * CFrame.Angles(0, 0, math.rad(35)),
				Color = colors.Bone,
			}, folder)
		end
	end
	-- Gable roof: two slabs meeting along the barn's length. CanQuery off so pumpkins can
	-- still spawn inside (their floor check casts down from the sky).
	local rise = 7
	local halfSpan = s.X / 2 + 1.5
	local slope = math.sqrt(halfSpan * halfSpan + rise * rise)
	local angle = math.atan2(rise, halfSpan)
	for _, side in { -1, 1 } do
		local roof = Kit.part({
			Name = "Roof",
			Size = Vector3.new(slope, 0.8, s.Z + 3),
			CFrame = CFrame.new(MapBase.at(ctx, o.X + side * halfSpan / 2, o.Z, s.Y + rise / 2))
				* CFrame.Angles(0, 0, -side * angle),
			Color = colors.Roof,
			Material = Enum.Material.WoodPlanks,
		}, folder)
		roof.CanQuery = false
	end
	-- Hay inside: stacked bales to dodge around, and a loose pile to hide in.
	for _ = 1, 6 do
		local x = ctx.Rng:NextNumber(-s.X / 2 + 3, s.X / 2 - 3)
		local z = ctx.Rng:NextNumber(-s.Z / 2 + 6, s.Z / 2 - 6)
		if math.abs(x) > 4 then -- keep the aisle between the doors clear
			hayBale(
				ctx,
				CFrame.new(MapBase.at(ctx, o.X + x, o.Z + z, 0))
					* CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi), 0),
				folder
			)
		end
	end
	haystack(
		ctx,
		"HayPile",
		MapBase.at(ctx, o.X - s.X / 2 + 5.5, o.Z, 0),
		Vector3.new(7, 9, 9),
		false,
		folder
	)
	local lamp = Kit.decor({
		Name = "Lamp",
		Size = Vector3.new(1, 1.4, 1),
		CFrame = CFrame.new(MapBase.at(ctx, o.X, o.Z, s.Y - 2)),
		Color = colors.Glow,
		Material = Enum.Material.Neon,
	}, folder)
	Kit.light(lamp, colors.Glow, 28, 1.2, true)
end

local function buildField(ctx: MapBase.Ctx, parent: Model)
	local cfg = ctx.Def.Layout.Field
	local colors = ctx.Def.Colors
	local folder = Kit.model("PumpkinField", parent)
	local o: Vector3, s: Vector3 = cfg.Offset, cfg.Size
	for row = 1, cfg.Rows do
		local z = o.Z - s.Z / 2 + (row - 0.5) * (s.Z / cfg.Rows)
		Kit.decor({
			Name = "Dirt",
			Size = Vector3.new(s.X, 0.2, 4),
			CFrame = CFrame.new(MapBase.at(ctx, o.X, z, 0.1)),
			Color = colors.Dirt,
			Material = Enum.Material.Ground,
		}, folder)
		Kit.decor({
			Name = "Vine",
			Size = Vector3.new(s.X - 2, 0.25, 0.4),
			CFrame = CFrame.new(MapBase.at(ctx, o.X, z, 0.3)),
			Color = colors.Green,
			Material = Enum.Material.Grass,
		}, folder)
		for i = 1, cfg.DecorPumpkinsPerRow do
			local x = o.X - s.X / 2 + (i - 0.5) * (s.X / cfg.DecorPumpkinsPerRow)
			decorPumpkin(
				CFrame.new(MapBase.at(ctx, x + ctx.Rng:NextNumber(-2, 2), z, 0.2))
					* CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
				ctx.Rng:NextNumber(1.6, 3.2),
				colors,
				folder
			)
		end
	end
	scarecrow(ctx, CFrame.new(MapBase.at(ctx, o.X, o.Z, 0)), folder)
	MapBase.hotspot(ctx, o, s)
end

local function buildGraveyard(ctx: MapBase.Ctx, parent: Model)
	local cfg = ctx.Def.Layout.Graveyard
	local colors = ctx.Def.Colors
	local folder = Kit.model("Graveyard", parent)
	local o: Vector3, s: Vector3 = cfg.Offset, cfg.Size
	-- Mausoleum at the back corner: walls on three sides, a doorway facing the map.
	local mx, mz = o.X + s.X / 2 - 9, o.Z + s.Z / 2 - 9
	for _, w in
		{
			{ Vector3.new(12, 10, 1.2), Vector3.new(0, 0, 6) },
			{ Vector3.new(1.2, 10, 12), Vector3.new(6, 0, 0) },
			{ Vector3.new(1.2, 10, 12), Vector3.new(-6, 0, 0) },
			{ Vector3.new(3.5, 10, 1.2), Vector3.new(-4.25, 0, -6) },
			{ Vector3.new(3.5, 10, 1.2), Vector3.new(4.25, 0, -6) },
		}
	do
		Kit.part({
			Name = "Mausoleum",
			Size = w[1],
			CFrame = CFrame.new(MapBase.at(ctx, mx + w[2].X, mz + w[2].Z, 5)),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, folder)
	end
	local cap = Kit.part({
		Name = "MausoleumRoof",
		Size = Vector3.new(14, 1.2, 14),
		CFrame = CFrame.new(MapBase.at(ctx, mx, mz, 10.6)),
		Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.Slate,
	}, folder)
	cap.CanQuery = false
	local candleFoot = CFrame.new(MapBase.at(ctx, mx, mz + 3, 0.6))
	Kit.prop("Candle", candleFoot, folder, 0.8, function()
		local m = Kit.model("Candle", folder)
		local candle = Kit.decor({
			Name = "Candle",
			Size = Vector3.new(0.5, 0.8, 0.5),
			CFrame = candleFoot * CFrame.new(0, 0.4, 0),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
		Kit.light(candle, colors.Glow, 12, 1, true)
		m.PrimaryPart = candle
		return m
	end, { Light = { Color = colors.Glow, Range = 12, Brightness = 1, Height = 0.9 } })

	local reserved: { Rect } = { { Center = Vector2.new(mx, mz), Half = Vector2.new(9, 9) } }
	for _ = 1, cfg.Tombstones do
		local spot: Vector2? = nil
		for _ = 1, 30 do
			local p = Vector2.new(
				o.X + ctx.Rng:NextNumber(-s.X / 2 + 3, s.X / 2 - 3),
				o.Z + ctx.Rng:NextNumber(-s.Z / 2 + 3, s.Z / 2 - 3)
			)
			local rect = { Center = p, Half = Vector2.new(3, 3) }
			local free = true
			for _, other in reserved do
				if overlaps(rect, other) then
					free = false
				end
			end
			if free then
				table.insert(reserved, rect)
				spot = p
				break
			end
		end
		if spot then
			local cf = CFrame.new(MapBase.at(ctx, spot.X, spot.Y, 0))
				* CFrame.Angles(0, math.rad(ctx.Rng:NextNumber(-15, 15)), 0)
				* CFrame.Angles(math.rad(ctx.Rng:NextNumber(-6, 6)), 0, 0)
			Kit.prop("Gravestone", cf, folder, 4.9, function()
				local m = Kit.model("Gravestone", folder)
				m.PrimaryPart = Kit.part({
					Name = "Tombstone",
					Size = Vector3.new(3, 3.4, 0.8),
					CFrame = cf * CFrame.new(0, 1.7, 0),
					Color = colors.Stone,
					Material = Enum.Material.Slate,
				}, m)
				Kit.decor({
					Name = "Top",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.8, 3, 3),
					CFrame = cf * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.rad(90), 0),
					Color = colors.Stone,
					Material = Enum.Material.Slate,
				}, m)
				Kit.decor({
					Name = "Mound",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2.6, 0.7, 4),
					CFrame = cf * CFrame.new(0, 0, -2.6),
					Color = colors.Dirt,
					Material = Enum.Material.Ground,
				}, m)
				return m
			end)
		end
	end
	-- Iron fence posts along the two inner edges, with gaps to walk through.
	for _, edge in
		{
			{
				Vector2.new(o.X - s.X / 2, o.Z - s.Z / 2),
				Vector2.new(o.X + s.X / 2, o.Z - s.Z / 2),
			},
			{
				Vector2.new(o.X - s.X / 2, o.Z - s.Z / 2),
				Vector2.new(o.X - s.X / 2, o.Z + s.Z / 2),
			},
		}
	do
		local a, b = edge[1], edge[2]
		local posts = math.floor((b - a).Magnitude / 3)
		for p = 0, posts do
			-- Leave an opening every few posts.
			if p % 6 ~= 3 and p % 6 ~= 4 then
				local pos = a:Lerp(b, p / posts)
				local foot = CFrame.new(MapBase.at(ctx, pos.X, pos.Y, 0))
				Kit.prop("FencePost", foot, folder, 4.5, function()
					local m = Kit.model("FencePost", folder)
					m.PrimaryPart = Kit.part({
						Name = "FencePost",
						Size = Vector3.new(0.4, 4.5, 0.4),
						CFrame = foot * CFrame.new(0, 2.25, 0),
						Color = colors.Iron,
					}, m)
					return m
				end)
			end
		end
	end
end

function PumpkinPatch.Build(def: any): Model
	local colors = def.Colors
	local layout = def.Layout
	local ctx = MapBase.new(def, {
		FloorColor = colors.Grass,
		FloorMaterial = Enum.Material.Grass,
		WallColor = colors.Hedge,
		WallMaterial = Enum.Material.LeafyGrass,
	})
	local model = ctx.Model
	local rng = ctx.Rng

	local reserved: { Rect } = {}
	for _, area in { layout.CornMaze, layout.Barn, layout.Field, layout.Graveyard } do
		reserve(reserved, area.Offset, area.Size, 6)
	end
	buildCornMaze(ctx, model)
	buildBarn(ctx, model)
	buildField(ctx, model)
	buildGraveyard(ctx, model)

	-- The spawn clearing: a big scarecrow lantern in the middle of the spawn ring.
	local centre = Kit.model("Clearing", model)
	scarecrow(ctx, CFrame.new(MapBase.at(ctx, 0, 0, 0)), centre)
	lantern(ctx, MapBase.at(ctx, 3, 3, 0), centre)

	local scatter = Kit.model("Scatter", model)
	local clearing: number = layout.ClearingRadius

	for _ = 1, layout.Haystacks do
		local p = freeSpot(ctx, reserved, 5, clearing)
		if p then
			haystack(
				ctx,
				"Haystack",
				MapBase.at(ctx, p.X, p.Y, 0),
				Vector3.new(7.5, 9, 9),
				true,
				scatter
			)
		end
	end

	for _ = 1, layout.JumpFences do
		local p = freeSpot(ctx, reserved, 10, clearing)
		if p then
			local cf = CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
				* CFrame.Angles(0, (rng:NextInteger(0, 1)) * math.pi / 2, 0)
			local h: number = layout.JumpFenceHeight
			Kit.part({
				Name = "JumpFence",
				Size = Vector3.new(20, h, 0.6),
				CFrame = cf * CFrame.new(0, h / 2, 0),
				Color = colors.Wood,
				Material = Enum.Material.WoodPlanks,
			}, scatter)
			for x = -10, 10, 5 do
				Kit.decor({
					Name = "Post",
					Size = Vector3.new(0.8, h + 0.6, 0.8),
					CFrame = cf * CFrame.new(x, (h + 0.6) / 2, 0),
					Color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.3),
					Material = Enum.Material.Wood,
				}, scatter)
			end
		end
	end

	for _ = 1, layout.HayBales do
		local p = freeSpot(ctx, reserved, 3, clearing)
		if p then
			hayBale(
				ctx,
				CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				scatter
			)
		end
	end

	for _ = 1, layout.DeadTrees do
		local p = freeSpot(ctx, reserved, 3, clearing)
		if p then
			local base = CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local tree = Kit.deadTree(
				base,
				rng:NextNumber(14, 22),
				colors.Wood:Lerp(Color3.new(0, 0, 0), 0.35),
				rng,
				scatter
			)
			if tree:GetAttribute("CustomProp") ~= true then -- (on the built trunk)
				Kit.cobweb(base * CFrame.new(0, 8, -1.15), 3.5, colors.Bone, tree)
			end
		end
	end

	for _ = 1, layout.Lanterns do
		local p = freeSpot(ctx, reserved, 2, clearing * 0.5)
		if p then
			lantern(ctx, MapBase.at(ctx, p.X, p.Y, 0), scatter)
		end
	end

	for _ = 1, layout.JackOLanterns do
		local p = freeSpot(ctx, reserved, 2, clearing * 0.6)
		if p then
			Kit.jackOLantern(
				CFrame.lookAt(MapBase.at(ctx, p.X, p.Y, 0), MapBase.at(ctx, 0, 0, 0)),
				rng:NextNumber(2, 3.2),
				colors,
				scatter
			)
		end
	end

	for _ = 1, layout.Scarecrows do
		local p = freeSpot(ctx, reserved, 4, clearing)
		if p then
			scarecrow(
				ctx,
				CFrame.lookAt(MapBase.at(ctx, p.X, p.Y, 0), MapBase.at(ctx, 0, 0, 0)),
				scatter
			)
		end
	end

	return model
end

return PumpkinPatch
