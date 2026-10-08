--!strict
--[[
	"Midnight Market", a small Hide & Seek map (settings: src/shared/Config/Maps/MidnightMarket.luau).
	A walled night market square:
	  edges       a low brick wall with stone caps, market stalls (striped awnings, counters of
	              goods, a lantern each) round the inside, gaps left at the corners
	  north-west  the Seeker Hut (HideSeekProps.seekerHut: door tagged SeekerDoor, SeekerSpawn pads)
	  middle      a pyramid of pumpkins with a lamp post at each corner
	  everywhere  clutter on free spots: crate stacks, barrel groups, sacks, hay rolls, handcarts,
	              benches; strings of little glowing lanterns across the square
	  decoys      Layout.Decoys decoy pumpkins (tag HidingDecoy): beside the clutter, under the
	              counters, along the walls, then anywhere free
	With Layout.Shuffle on, the clutter, the decoys and the hider spawns land in new spots every
	round (the walls, stalls, hut and pyramid always stay put, so the map still feels familiar).
	Repeated things are props (one model in ReplicatedStorage.Custom.Props swaps every copy):
	MarketStall, Crate, Barrel, HayRoll, Sack, Handcart, Bench, Lamppost, PumpkinPyramid,
	HidingPumpkin.
]]

local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)
local HidingPumpkin = require(script.Parent.Parent.Build.HidingPumpkin)
local HideSeekProps = require(script.Parent.HideSeekProps)
local MapBase = require(script.Parent.MapBase)

local MidnightMarket = {}

type Rect = { Min: Vector2, Max: Vector2 }

local function reserve(list: { Rect }, center: Vector2, size: Vector2, pad: number)
	local half = size / 2 + Vector2.new(pad, pad)
	table.insert(list, { Min = center - half, Max = center + half })
end

local function free(list: { Rect }, center: Vector2, radius: number): boolean
	for _, r in list do
		if
			center.X + radius > r.Min.X
			and center.X - radius < r.Max.X
			and center.Y + radius > r.Min.Y
			and center.Y - radius < r.Max.Y
		then
			return false
		end
	end
	return true
end

-- A free spot (map offset) at least `radius` from everything reserved, inside `limit`.
local function freeSpot(rng: Random, list: { Rect }, radius: number, limit: number): Vector2?
	for _ = 1, 60 do
		local p = Vector2.new(rng:NextNumber(-limit, limit), rng:NextNumber(-limit, limit))
		if free(list, p, radius) then
			return p
		end
	end
	return nil
end

-- A sack of grain: a squashed oval with a tied neck (prop "Sack").
local function sack(paint: any, cf: CFrame, height: number, parent: Instance): Model
	return Kit.prop("Sack", cf, parent, height, function()
		local m = Kit.model("Sack", parent)
		local body = HideSeekProps.oval({
			Name = "Bag",
			Size = Vector3.new(height * 0.85, height, height * 0.7),
			CFrame = cf * CFrame.new(0, height / 2, 0),
			Color = paint.color("Sack"),
			Material = Enum.Material.Fabric,
		}, m, true)
		paint.decor({
			Name = "Neck",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height * 0.25, height * 0.3, height * 0.3),
			CFrame = Kit.upright(cf * CFrame.new(0, height * 1.02, 0)),
			PaletteRole = "Sack",
			PaletteShade = 0.15,
			Material = Enum.Material.Fabric,
		}, m)
		m.PrimaryPart = body
		return m
	end)
end

-- A two-wheeled wooden handcart with pumpkins in it (prop "Handcart").
local function handcart(
	paint: any,
	cf: CFrame,
	rng: Random,
	goods: { Color3 },
	parent: Instance
): Model
	local picks = {}
	for i = 1, 4 do
		picks[i] = { goods[rng:NextInteger(1, #goods)], rng:NextNumber(-0.5, 0.5) }
	end
	return Kit.prop("Handcart", cf, parent, 3.4, function()
		local m = Kit.model("Handcart", parent)
		local bed = paint.part({
			Name = "Bed",
			Size = Vector3.new(4, 0.4, 6),
			CFrame = cf * CFrame.new(0, 1.9, 0),
			PaletteRole = "Wood",
			Material = Enum.Material.WoodPlanks,
		}, m)
		for _, side in { -1, 1 } do
			paint.decor({
				Name = "Side",
				Size = Vector3.new(0.3, 1.1, 6),
				CFrame = cf * CFrame.new(side * 1.85, 2.6, 0),
				PaletteRole = "Wood",
				PaletteShade = 0.15,
				Material = Enum.Material.WoodPlanks,
			}, m)
			paint.decor({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 2.6, 2.6),
				CFrame = cf * CFrame.new(side * 2.3, 1.3, 0.8),
				PaletteRole = "Wood",
				PaletteShade = 0.3,
				Material = Enum.Material.Wood,
			}, m)
			paint.decor({
				Name = "Handle",
				Size = Vector3.new(0.25, 0.25, 3),
				CFrame = cf
					* CFrame.new(side * 1.4, 1.6, -4.2)
					* CFrame.Angles(math.rad(-15), 0, 0),
				PaletteRole = "Wood",
				Material = Enum.Material.Wood,
			}, m)
		end
		paint.decor({
			Name = "Leg",
			Size = Vector3.new(3, 1.7, 0.3),
			CFrame = cf * CFrame.new(0, 0.85, -2.6),
			PaletteRole = "Wood",
			PaletteShade = 0.2,
		}, m)
		for i, pick in picks do
			paint.decor({
				Name = "Goods",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.5,
				CFrame = cf
					* CFrame.new(((i - 1) % 2 - 0.5) * 1.6, 2.7, (i <= 2 and -1.3 or 1.3) + pick[2]),
				Color = pick[1],
				Material = Enum.Material.SmoothPlastic,
			}, m)
		end
		m.PrimaryPart = bed
		return m
	end)
end

--[[
	A market stall: four posts, a counter covered in goods, a sloped striped awning and a
	lantern (prop "MarketStall"). Its front faces cf.LookVector. Returns the stall and spots for
	decoys (under the counter, beside it).
]]
local function stall(
	paint: any,
	cf: CFrame,
	stripes: { Color3 },
	rng: Random,
	goods: { Color3 },
	parent: Instance
): (Model, { CFrame })
	local w, d = 9, 5
	local picks = {}
	for i = 1, 8 do
		picks[i] = { goods[rng:NextInteger(1, #goods)], rng:NextNumber(0.7, 1.2) }
	end
	local model = Kit.prop("MarketStall", cf, parent, 8.5, function()
		local m = Kit.model("MarketStall", parent)
		local counter = paint.part({
			Name = "Counter",
			Size = Vector3.new(w, 0.5, 2.4),
			CFrame = cf * CFrame.new(0, 3.2, -d / 2 + 1.2),
			PaletteRole = "Wood",
			PaletteShade = -0.1,
			Material = Enum.Material.WoodPlanks,
		}, m)
		paint.part({
			Name = "CounterFront",
			Size = Vector3.new(w, 2.95, 0.3),
			CFrame = cf * CFrame.new(0, 1.5, -d / 2 + 0.15),
			Color = stripes[1],
			Material = Enum.Material.Fabric,
		}, m)
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				paint.part({
					Name = "Post",
					Size = Vector3.new(0.4, if z < 0 then 6.6 else 7.6, 0.4),
					CFrame = cf * CFrame.new(
						x * (w / 2 - 0.2),
						if z < 0 then 3.3 else 3.8,
						z * (d / 2 - 0.2)
					),
					PaletteRole = "Wood",
					PaletteShade = 0.2,
					Material = Enum.Material.Wood,
				}, m)
			end
		end
		-- The awning: stripes sloping down to the front.
		local stripesCount = 6
		local slope = math.atan2(1.2, d)
		for i = 1, stripesCount do
			local x = (i - 0.5) / stripesCount * w - w / 2
			paint.decor({
				Name = "Awning",
				Size = Vector3.new(w / stripesCount + 0.02, 0.2, d + 1.4),
				CFrame = cf * CFrame.new(x, 7.2, -0.4) * CFrame.Angles(-slope, 0, 0),
				Color = stripes[(i - 1) % 2 + 1],
				Material = Enum.Material.Fabric,
			}, m)
		end
		-- A scalloped edge along the front of the awning.
		for i = 1, 6 do
			local x = (i - 0.5) / 6 * w - w / 2
			HideSeekProps.oval({
				Name = "Scallop",
				Size = Vector3.new(w / 6, 0.9, 0.15),
				CFrame = cf * CFrame.new(x, 6.45, -d / 2 - 1.05),
				Color = stripes[i % 2 + 1],
				Material = Enum.Material.Fabric,
			}, m)
		end
		-- Goods on the counter.
		for i, pick in picks do
			local size = pick[2]
			paint.decor({
				Name = "Goods",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				CFrame = cf * CFrame.new(
					(i - 4.5) / 8 * (w - 1.5),
					3.45 + size / 2,
					-d / 2 + 1.2 + (i % 2) * 0.6 - 0.3
				),
				Color = pick[1],
				Material = Enum.Material.SmoothPlastic,
			}, m)
		end
		local lamp = paint.decor({
			Name = "Lantern",
			Size = Vector3.new(0.7, 0.9, 0.7),
			CFrame = cf * CFrame.new(w / 2 - 1, 5.9, -d / 2 + 0.6),
			Color = paint.color("Glow"),
			Material = Enum.Material.Neon,
		}, m)
		Kit.light(lamp, paint.color("Glow"), 12, 0.9, true)
		m.PrimaryPart = counter
		return m
	end, { Light = { Color = paint.color("Glow"), Range = 12, Brightness = 0.9 } })
	local spots = {
		cf * CFrame.new(-w / 4, 0, 0.6), -- behind the counter
		cf * CFrame.new(w / 4, 0, 0.6),
		cf * CFrame.new(w / 2 + 1.6, 0, -d / 2 + 0.8), -- beside it
	}
	return model, spots
end

-- A tiered pile of pumpkins in the middle of the square (prop "PumpkinPyramid").
local function pyramid(paint: any, cf: CFrame, rng: Random, parent: Instance): Model
	local tiers = { { 4.6, 8 }, { 3.2, 6 }, { 1.7, 4 }, { 0, 1 } }
	local jitters = {}
	for i = 1, 19 do
		jitters[i] = rng:NextNumber(-0.15, 0.15)
	end
	return Kit.prop("PumpkinPyramid", cf, parent, 7, function()
		local m = Kit.model("PumpkinPyramid", parent)
		local base = paint.part({
			Name = "Stand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 12, 12),
			CFrame = Kit.upright(cf * CFrame.new(0, 0.5, 0)),
			PaletteRole = "Wood",
			Material = Enum.Material.WoodPlanks,
		}, m)
		local n = 0
		for level, tier in tiers do
			local radius, count = tier[1], tier[2]
			for i = 1, count do
				n += 1
				local a = i / count * math.pi * 2 + level
				Props.Pumpkin(
					paint,
					cf
						* CFrame.new(
							math.cos(a) * radius,
							1 + (level - 1) * 1.6,
							math.sin(a) * radius
						)
						* CFrame.Angles(0, a, 0),
					2.2 - level * 0.2 + (jitters[n] or 0),
					m,
					{ Solid = false }
				)
			end
		end
		m.PrimaryPart = base
		return m
	end)
end

-- A string of little glowing lanterns between two posts, sagging in the middle.
-- `a` and `b` are the tops of the two poles; each pole is `height` studs tall.
local function lanternString(paint: any, a: Vector3, b: Vector3, height: number, parent: Instance)
	local folder = Kit.model("LanternString", parent)
	for _, p in { a, b } do
		paint.part({
			Name = "Pole",
			Size = Vector3.new(0.5, height, 0.5),
			CFrame = CFrame.new(p - Vector3.new(0, height / 2, 0)),
			PaletteRole = "Wood",
			PaletteShade = 0.2,
			Material = Enum.Material.Wood,
		}, folder)
	end
	local count = 9
	local sag = 2
	local last = a
	for i = 1, count + 1 do
		local t = i / (count + 1)
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		paint.decor({
			Name = "Wire",
			Size = Vector3.new(0.08, 0.08, (p - last).Magnitude),
			CFrame = CFrame.lookAt((p + last) / 2, p),
			PaletteRole = "Iron",
			CastShadow = false,
		}, folder)
		if i <= count then
			local bulb = paint.decor({
				Name = "Bulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				CFrame = CFrame.new(p - Vector3.new(0, 0.35, 0)),
				Color = if i % 2 == 0 then paint.color("Orange") else paint.color("Glow"),
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, folder)
			if i == math.ceil(count / 2) then
				Kit.light(bulb, paint.color("Glow"), 16, 0.7, false)
			end
		end
		last = p
	end
end

function MidnightMarket.Build(def: any): Model
	local colors = def.Colors
	local layout = def.Layout
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Cobblestone,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.Brick,
	})
	local model = ctx.Model
	-- The edge walls stay (they keep everyone in); you see the brick wall instead.
	local edge = model:FindFirstChild("Walls")
	if edge then
		for _, wall in edge:GetChildren() do
			if wall:IsA("BasePart") then
				wall.Transparency = 1
				wall.CastShadow = false
			end
		end
	end
	-- Fixed things use the map's Seed; shuffled things a new seed each round.
	local fixed = ctx.Rng
	local rng = if layout.Shuffle then Random.new() else Random.new(def.Seed + 1)
	local paint = Kit.painter({
		Wood = colors.Wood,
		Iron = colors.Iron,
		Straw = colors.Straw,
		Sack = colors.Sack,
		Bone = colors.Trim,
		Glow = colors.Glow,
		Orange = colors.Orange,
		Stone = colors.Cap,
		Cloth = colors.Cloth,
		Green = Color3.fromRGB(90, 140, 60),
		Foliage = Color3.fromRGB(60, 100, 50),
		Dark = Color3.fromRGB(30, 22, 34),
	})
	local market = Kit.group("Market", model)
	local reserved: { Rect } = {}
	local decoySpots: { CFrame } = {}
	local half = ctx.Half.X
	local function at(p: Vector2, y: number?): Vector3
		return MapBase.at(ctx, p.X, p.Y, y)
	end

	-- The brick wall round the market.
	local wallFolder = Kit.model("MarketWall", market)
	local wh: number = layout.WallHeight
	for _, side in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local alongX = side[1] == 0
		local length = half * 2 + 2
		local centre = Vector2.new(side[1] * (half + 0.5), side[2] * (half + 0.5))
		Kit.part({
			Name = "Brick",
			Size = if alongX then Vector3.new(length, wh, 1) else Vector3.new(1, wh, length),
			Position = at(centre, wh / 2),
			Color = colors.Brick,
			Material = Enum.Material.Brick,
		}, wallFolder)
		Kit.decor({
			Name = "Cap",
			Size = if alongX
				then Vector3.new(length + 0.6, 0.6, 1.6)
				else Vector3.new(1.6, 0.6, length + 0.6),
			Position = at(centre, wh + 0.3),
			Color = colors.Cap,
			Material = Enum.Material.Slate,
		}, wallFolder)
	end

	-- The Seeker Hut.
	local hut = layout.SeekerHut
	local hutAt = Vector2.new(hut.Offset.X, hut.Offset.Z)
	HideSeekProps.seekerHut(
		CFrame.lookAt(at(hutAt), at(Vector2.new(hut.FacesTowards.X, hut.FacesTowards.Z))),
		hut.Size,
		{
			Wall = colors.HutWall,
			Roof = colors.Roof,
			Trim = colors.Trim,
			Door = colors.HutDoor,
			Glow = colors.Glow,
			Text = colors.HutText,
		},
		hut.Spawns,
		market
	)
	reserve(reserved, hutAt, Vector2.new(hut.Size.X + 2, hut.Size.Z + 2), 5)

	-- The pumpkin pyramid and its lamp posts in the middle.
	pyramid(paint, CFrame.new(at(Vector2.zero)), fixed, market)
	reserve(reserved, Vector2.zero, Vector2.new(12, 12), 3)
	for i = 1, layout.Lampposts do
		local a = (i - 0.5) / layout.Lampposts * math.pi * 2
		local p = Vector2.new(math.cos(a), math.sin(a)) * 9.5
		HideSeekProps.lantern(CFrame.new(at(p)) * CFrame.Angles(0, -a, 0), colors, market)
		reserve(reserved, p, Vector2.new(2, 2), 1)
	end

	-- Stalls round the edge, facing in, leaving the corners and the hut clear.
	local stalls = Kit.group("Stalls", market)
	local perSide = math.ceil(layout.Stalls / 4)
	local placed = 0
	for _, side in { Vector2.new(0, 1), Vector2.new(1, 0), Vector2.new(0, -1), Vector2.new(-1, 0) } do
		for k = 1, perSide do
			if placed >= layout.Stalls then
				break
			end
			local along = (k / (perSide + 1) - 0.5) * (half * 2 - 26)
			local tangent = Vector2.new(-side.Y, side.X)
			local p = side * (half - 4) + tangent * along
			if free(reserved, p, 5) then
				placed += 1
				local stripes = colors.Awnings[(placed - 1) % #colors.Awnings + 1]
				local facing = at(p - side * 10)
				local _, spots =
					stall(paint, CFrame.lookAt(at(p), facing), stripes, fixed, colors.Goods, stalls)
				for _, spot in spots do
					table.insert(decoySpots, spot)
				end
				reserve(reserved, p, Vector2.new(10, 10), 1)
			end
		end
	end

	-- Lantern strings across the square (fixed).
	local strings = Kit.group("LanternStrings", market)
	for i = 1, layout.LanternStrings do
		local a = (i / layout.LanternStrings) * math.pi + 0.3
		local dir = Vector2.new(math.cos(a), math.sin(a)) * (half - 13)
		lanternString(paint, at(dir, 11), at(-dir, 11), 11, strings)
	end

	-- Shuffled clutter on free spots, each with decoy spots round it.
	local clutter = Kit.group("Clutter", market)
	local limit = half - 9
	local kinds = { "Crates", "Barrels", "Sacks", "Hay", "Cart", "Bench" }
	for i = 1, layout.Clutter do
		local kind = kinds[(i - 1) % #kinds + 1]
		local p = freeSpot(rng, reserved, 4.5, limit)
		if not p then
			continue
		end
		local turn = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(at(p)) * CFrame.Angles(0, turn, 0)
		if kind == "Crates" then
			local n = rng:NextInteger(2, 4)
			for c = 1, n do
				local size = rng:NextNumber(2.6, 3.4)
				local offset = if c == 4
					then CFrame.new(0.4, 3, 0.2)
					else CFrame.new((c - 2) * 3.2, 0, rng:NextNumber(-0.3, 0.3))
				Props.Crate(
					paint,
					cf * offset * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
					size,
					clutter
				)
			end
		elseif kind == "Barrels" then
			for c = 1, rng:NextInteger(2, 3) do
				Props.Barrel(
					paint,
					cf * CFrame.new((c - 2) * 2.6, 0, rng:NextNumber(-0.6, 0.6)),
					rng:NextNumber(3.2, 3.8),
					clutter
				)
			end
		elseif kind == "Sacks" then
			for c = 1, rng:NextInteger(3, 5) do
				local a = c / 5 * math.pi * 2
				sack(
					paint,
					cf
						* CFrame.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)
						* CFrame.Angles(0, a, 0),
					rng:NextNumber(2, 2.8),
					clutter
				)
			end
		elseif kind == "Hay" then
			Props.HayRoll(paint, cf, 3.4, clutter)
			Props.HayRoll(paint, cf * CFrame.new(0, 0, 3.6), 3.4, clutter)
		elseif kind == "Cart" then
			handcart(paint, cf, rng, colors.Goods, clutter)
		else
			Props.Bench(paint, cf, clutter)
		end
		reserve(reserved, p, Vector2.new(6, 6), 0.5)
		for s = 1, 3 do
			local a = turn + s * 2.1
			table.insert(
				decoySpots,
				CFrame.new(at(p + Vector2.new(math.cos(a), math.sin(a)) * 4.6))
			)
		end
	end

	-- Hider spawns, spread out away from the hut.
	local spawnFolder = model:FindFirstChild(def.SpawnFolder) :: Instance
	spawnFolder:ClearAllChildren()
	local spawned: { Vector2 } = {}
	for _ = 1, def.Spawns * 20 do
		if #spawned >= def.Spawns then
			break
		end
		local p = freeSpot(rng, reserved, 3, limit)
		if p and (p - hutAt).Magnitude > 30 then
			local apart = true
			for _, q in spawned do
				if (p - q).Magnitude < 10 then
					apart = false
					break
				end
			end
			if apart then
				table.insert(spawned, p)
				HideSeekProps.hiderSpawn(at(p), rng, spawnFolder)
				reserve(reserved, p, Vector2.new(5, 5), 0)
			end
		end
	end

	-- Decoys: the spots beside things first (shuffled), then anywhere free.
	local decoys = Kit.model("Decoys", market)
	for i = #decoySpots, 2, -1 do
		local j = rng:NextInteger(1, i)
		decoySpots[i], decoySpots[j] = decoySpots[j], decoySpots[i]
	end
	local made = 0
	local used: { Vector2 } = {}
	local function clearOfOthers(v: Vector2): boolean
		for _, u in used do
			if (u - v).Magnitude < 2.6 then
				return false
			end
		end
		return true
	end
	for _, spot in decoySpots do
		if made >= layout.Decoys then
			break
		end
		local p = spot.Position - ctx.Origin
		local v = Vector2.new(p.X, p.Z)
		if math.abs(v.X) < limit + 4 and math.abs(v.Y) < limit + 4 and clearOfOthers(v) then
			HidingPumpkin.Decoy(
				spot * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rng,
				decoys
			)
			table.insert(used, v)
			made += 1
		end
	end
	for _ = 1, layout.Decoys * 6 do
		if made >= layout.Decoys then
			break
		end
		local v = freeSpot(rng, reserved, 1.4, limit + 3)
		if v and clearOfOthers(v) then
			HidingPumpkin.Decoy(
				CFrame.new(at(v)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rng,
				decoys
			)
			table.insert(used, v)
			made += 1
		end
	end
	return model
end

return MidnightMarket
