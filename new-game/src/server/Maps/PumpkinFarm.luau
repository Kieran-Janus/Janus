--!strict
--[[
	"Pumpkin Farm", a Hide & Seek map (settings: src/shared/Config/Maps/PumpkinFarm.luau).
	A cosy harvest farm at sunset, x = east, z = south:
	  north-west  the red barn: big doors at both ends, a hayloft up hay-bale steps
	  north       a small pumpkin field
	  north-east  the farmhouse with its porch and a little orchard
	  east        the Seeker Hut (seekers count in here; its door is tagged SeekerDoor)
	  south-west  the corn patch (rows with gaps: great for hiding)
	  south       the big pumpkin field
	  middle      the farmyard: dirt paths, a well, hay, wheelbarrows, lanterns
	  edge        a rail fence and autumn trees (an invisible wall keeps everyone in)
	Decoy pumpkins (src/server/Build/HidingPumpkin.luau, tag HidingDecoy) fill the fields and
	sit round the yard; hiders start on the parts tagged HiderSpawn (folder Spawns).
	Everything is placed with ctx.Rng, so the farm is the same every time (random numbers are
	drawn before Kit.prop, so a custom model never moves the rest of the farm).
	Repeated decorations are props (one model in ReplicatedStorage.Custom.Props swaps every
	copy): HidingPumpkin, Pumpkin (the little ones in the carts), CornStalk, HayBale, HayRoll,
	Lamppost, AutumnTree, Scarecrow, Wheelbarrow, HarvestCart, Well, Tractor, RockingChair.
]]

local Kit = require(script.Parent.Parent.Build.Kit)
local HidingPumpkin = require(script.Parent.Parent.Build.HidingPumpkin)
local HideSeekProps = require(script.Parent.HideSeekProps)
local MapBase = require(script.Parent.MapBase)

local PumpkinFarm = {}

type Rect = { Center: Vector2, Half: Vector2 }

local oval = HideSeekProps.oval
local jitter = HideSeekProps.jitter

local function overlaps(a: Rect, b: Rect): boolean
	return math.abs(a.Center.X - b.Center.X) < a.Half.X + b.Half.X
		and math.abs(a.Center.Y - b.Center.Y) < a.Half.Y + b.Half.Y
end

local function reserve(reserved: { Rect }, center: Vector2, size: Vector2, pad: number)
	table.insert(reserved, { Center = center, Half = size / 2 + Vector2.new(pad, pad) })
end

local function isFree(reserved: { Rect }, rect: Rect): boolean
	for _, other in reserved do
		if overlaps(rect, other) then
			return false
		end
	end
	return true
end

-- A free spot of radius `r` inside the fence, or nil after many tries.
local function freeSpot(ctx: MapBase.Ctx, reserved: { Rect }, r: number, limit: number): Vector2?
	for _ = 1, 80 do
		local p = Vector2.new(
			ctx.Rng:NextNumber(-limit + r, limit - r),
			ctx.Rng:NextNumber(-limit + r, limit - r)
		)
		local rect = { Center = p, Half = Vector2.new(r, r) }
		if isFree(reserved, rect) then
			table.insert(reserved, rect)
			return p
		end
	end
	return nil
end

local function at(ctx: MapBase.Ctx, p: Vector2, y: number?): Vector3
	return MapBase.at(ctx, p.X, p.Y, y)
end

-- Flat ground cover (dirt, paths): decoration only, never blocks anything.
local function patch(
	ctx: MapBase.Ctx,
	name: string,
	center: Vector2,
	size: Vector2,
	color: Color3,
	parent: Instance,
	yaw: number?
)
	Kit.decor({
		Name = name,
		Size = Vector3.new(size.X, 0.2, size.Y),
		CFrame = CFrame.new(at(ctx, center, 0.08)) * CFrame.Angles(0, yaw or 0, 0),
		Color = color,
		Material = Enum.Material.Ground,
	}, parent)
end

-- Paths ------------------------------------------------------------------------------------------

local function buildPaths(ctx: MapBase.Ctx, parent: Instance)
	local colors = ctx.Def.Colors
	local folder = Kit.model("Paths", parent)
	local width = 7
	for _, segment in ctx.Def.Layout.Paths do
		local a: Vector2, b: Vector2 = segment[1], segment[2]
		local offset = b - a
		local length = offset.Magnitude
		if length < 0.5 then
			continue
		end
		local mid = (a + b) / 2
		local yaw = math.atan2(-offset.X, -offset.Y)
		Kit.decor({
			Name = "Path",
			Size = Vector3.new(width, 0.2, length),
			CFrame = CFrame.new(at(ctx, mid, 0.1)) * CFrame.Angles(0, yaw, 0),
			Color = colors.Path,
			Material = Enum.Material.Ground,
		}, folder)
		for _, p in { a, b } do
			Kit.decor({
				Name = "PathEnd",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, width, width),
				CFrame = Kit.upright(CFrame.new(at(ctx, p, 0.1))),
				Color = colors.Path,
				Material = Enum.Material.Ground,
			}, folder)
		end
	end
end

-- Pumpkin fields ----------------------------------------------------------------------------------

local function buildFields(ctx: MapBase.Ctx, parent: Instance, reserved: { Rect }): number
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local folder = Kit.model("PumpkinFields", parent)
	local count = 0
	for i, field in layout.PumpkinFields do
		local m = Kit.model("Field" .. i, folder)
		local center = Vector2.new(field.Offset.X, field.Offset.Z)
		local size = Vector2.new(field.Size.X, field.Size.Z)
		reserve(reserved, center, size, 3)
		patch(ctx, "Soil", center, size + Vector2.new(4, 4), colors.Dirt, m)
		local rowGap = size.Y / field.Rows
		for row = 1, field.Rows do
			local z = center.Y - size.Y / 2 + (row - 0.5) * rowGap
			-- A green vine along the row, with leaves here and there.
			Kit.decor({
				Name = "Vine",
				Size = Vector3.new(size.X, 0.25, 0.5),
				CFrame = CFrame.new(MapBase.at(ctx, center.X, z, 0.25)),
				Color = colors.Vine,
				Material = Enum.Material.LeafyGrass,
			}, m)
			local step = size.X / field.PerRow
			for n = 1, field.PerRow do
				local x = center.X - size.X / 2 + (n - 0.5) * step
				if ctx.Rng:NextNumber() < layout.MissingChance then
					-- An empty spot: a leaf, so the row still looks planted.
					oval({
						Name = "Leaf",
						Size = Vector3.new(2.4, 0.3, 1.6),
						CFrame = CFrame.new(
							MapBase.at(ctx, x, z + ctx.Rng:NextNumber(-0.6, 0.6), 0.35)
						) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi), 0),
						Color = jitter(colors.Vine, ctx.Rng, 0.15),
						Material = Enum.Material.LeafyGrass,
					}, m)
					continue
				end
				local spot = MapBase.at(
					ctx,
					x + ctx.Rng:NextNumber(-0.8, 0.8),
					z + ctx.Rng:NextNumber(-0.8, 0.8),
					0
				)
				HidingPumpkin.Decoy(
					CFrame.new(spot) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
					ctx.Rng,
					m
				)
				count += 1
			end
		end
		-- Low rail fence round the field with a gap in the middle of each side.
		local hx, hz = size.X / 2 + 3, size.Y / 2 + 3
		local corners = {
			Vector2.new(-hx, -hz),
			Vector2.new(hx, -hz),
			Vector2.new(hx, hz),
			Vector2.new(-hx, hz),
		}
		for c = 1, 4 do
			local a = center + corners[c]
			local b = center + corners[c % 4 + 1]
			local mid = (a + b) / 2
			local dir = (b - a).Unit
			local gap = 4
			HideSeekProps.railFence(at(ctx, a), at(ctx, mid - dir * gap), 3, colors.Wood, m)
			HideSeekProps.railFence(at(ctx, mid + dir * gap), at(ctx, b), 3, colors.Wood, m)
		end
	end
	return count
end

-- Corn patch --------------------------------------------------------------------------------------

local function buildCorn(ctx: MapBase.Ctx, parent: Instance, reserved: { Rect })
	local cfg = ctx.Def.Layout.CornPatch
	local colors = ctx.Def.Colors
	local folder = Kit.model("CornPatch", parent)
	local offset: Vector3, size: Vector3 = cfg.Offset, cfg.Size
	reserve(reserved, Vector2.new(offset.X, offset.Z), Vector2.new(size.X, size.Z), 2)
	patch(
		ctx,
		"Soil",
		Vector2.new(offset.X, offset.Z),
		Vector2.new(size.X + 4, size.Z + 4),
		colors.Dirt,
		folder
	)
	local halfX = size.X / 2
	local rows = math.floor(size.Z / cfg.RowSpacing) + 1
	for row = 0, rows - 1 do
		local z = offset.Z - size.Z / 2 + row * cfg.RowSpacing
		local gaps: { number } = {}
		for _ = 1, cfg.GapsPerRow do
			for _ = 1, 20 do
				local c = ctx.Rng:NextNumber(-halfX + cfg.GapWidth, halfX - cfg.GapWidth)
				local ok = true
				for _, g in gaps do
					if math.abs(g - c) < cfg.GapWidth * 2.5 then
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
			if length < 2 then
				continue
			end
			local stalks = math.max(1, math.ceil(length / 2.3))
			local step = length / stalks
			for n = 1, stalks do
				local x = offset.X + piece[1] + (n - 0.5) * step
				local height = size.Y * ctx.Rng:NextNumber(0.8, 1.05)
				local zz = z
					+ (if n % 2 == 0 then 0.35 else -0.35)
					+ ctx.Rng:NextNumber(-0.15, 0.15)
				local lean = CFrame.Angles(
					ctx.Rng:NextNumber(-0.05, 0.05),
					0,
					ctx.Rng:NextNumber(-0.05, 0.05)
				)
				local foot = CFrame.new(MapBase.at(ctx, x, zz, 0)) * lean
				local cornColor = jitter(colors.Corn, ctx.Rng, 0.12)
				local leafSide, leafHeight, leafColor = 0, 0, colors.Corn
				if n % 2 == 1 then
					leafSide = if ctx.Rng:NextNumber() < 0.5 then -1 else 1
					leafHeight = height * ctx.Rng:NextNumber(0.35, 0.6)
					leafColor = jitter(colors.Corn, ctx.Rng, 0.15)
				end
				local tasselColor = jitter(colors.CornTop, ctx.Rng, 0.08)
				-- A tall corn stalk (solid: it blocks the view and candy), a leaf, a tassel.
				Kit.prop("CornStalk", foot, folder, height + 1.05, function()
					local m = Kit.model("CornStalk", folder)
					m.PrimaryPart = oval({
						Name = "Corn",
						Size = Vector3.new(1.9, height, 1.9),
						CFrame = foot * CFrame.new(0, height / 2 - 0.3, 0),
						Color = cornColor,
						Material = Enum.Material.LeafyGrass,
					}, m, true)
					if leafSide ~= 0 then
						oval({
							Name = "Leaf",
							Size = Vector3.new(0.25, 3.2, 1.1),
							CFrame = foot
								* CFrame.new(0, leafHeight, leafSide * 1.2)
								* CFrame.Angles(leafSide * math.rad(40), 0, 0),
							Color = leafColor,
							Material = Enum.Material.LeafyGrass,
						}, m)
					end
					oval({
						Name = "Tassel",
						Size = Vector3.new(0.7, 1.5, 0.7),
						CFrame = foot * CFrame.new(0, height + 0.3, 0),
						Color = tasselColor,
						Material = Enum.Material.Fabric,
					}, m)
					return m
				end)
			end
		end
	end
end

-- Barn ------------------------------------------------------------------------------------------

local function buildBarn(
	ctx: MapBase.Ctx,
	parent: Instance,
	reserved: { Rect },
	decoySpots: { CFrame }
)
	local cfg = ctx.Def.Layout.Barn
	local colors = ctx.Def.Colors
	local m = Kit.model("Barn", parent)
	local size: Vector3 = cfg.Size
	local L, H, W = size.X, size.Y, size.Z
	local t = 1
	local base = CFrame.new(MapBase.at(ctx, cfg.Offset.X, cfg.Offset.Z, 0))
	reserve(reserved, Vector2.new(cfg.Offset.X, cfg.Offset.Z), Vector2.new(L + 14, W + 4), 2)

	local function part(
		name: string,
		s: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		decor: boolean?
	): Part
		local props = {
			Name = name,
			Size = s,
			CFrame = base * cf,
			Color = color,
			Material = material or Enum.Material.WoodPlanks,
		}
		return if decor then Kit.decor(props, m) else Kit.part(props, m)
	end

	-- Stone foundation strip and the floor inside (packed dirt).
	patch(
		ctx,
		"BarnFloor",
		Vector2.new(cfg.Offset.X, cfg.Offset.Z),
		Vector2.new(L, W),
		colors.Dirt,
		m
	)
	for _, z in { -1, 1 } do
		part(
			"Foundation",
			Vector3.new(L + 0.6, 1, t + 0.6),
			CFrame.new(0, 0.5, z * W / 2),
			colors.Stone,
			Enum.Material.Cobblestone,
			true
		)
	end
	-- Long walls with windows.
	for _, z in { -1, 1 } do
		part("Wall", Vector3.new(L, H, t), CFrame.new(0, H / 2, z * W / 2), colors.Barn)
		for i = -1, 1 do
			local x = i * L / 3.2
			part(
				"WindowFrame",
				Vector3.new(4.2, 4.2, 0.3),
				CFrame.new(x, H * 0.6, z * (W / 2 + 0.55)),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
			part(
				"Window",
				Vector3.new(3.2, 3.2, 0.3),
				CFrame.new(x, H * 0.6, z * (W / 2 + 0.6)),
				colors.Glow,
				Enum.Material.Neon,
				true
			)
			part(
				"WindowBar",
				Vector3.new(0.3, 3.2, 0.35),
				CFrame.new(x, H * 0.6, z * (W / 2 + 0.65)),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
		end
	end
	-- End walls with the big door openings, and the doors standing open against the wall.
	local dw = cfg.DoorWidth
	local dh = math.min(H - 2, 11)
	local sideWidth = (W - dw) / 2
	for _, x in { -1, 1 } do
		local wx = x * L / 2
		for _, z in { -1, 1 } do
			part(
				"EndWall",
				Vector3.new(t, H, sideWidth),
				CFrame.new(wx, H / 2, z * (dw / 2 + sideWidth / 2)),
				colors.Barn
			)
			-- An open door panel, white X brace on red.
			local doorCf = CFrame.new(wx + x * 0.7, dh / 2, z * (dw / 2 + dw / 4 + 0.3))
			part(
				"Door",
				Vector3.new(0.4, dh, dw / 2),
				doorCf,
				colors.Barn,
				Enum.Material.WoodPlanks,
				true
			)
			local diagonal = math.sqrt((dw / 2) ^ 2 + dh ^ 2)
			local angle = math.atan2(dh, dw / 2)
			for _, sign in { -1, 1 } do
				part(
					"Brace",
					Vector3.new(0.5, 0.5, diagonal - 0.6),
					doorCf * CFrame.new(x * 0.1, 0, 0) * CFrame.Angles(sign * angle, 0, 0),
					colors.Trim,
					Enum.Material.Wood,
					true
				)
			end
			part(
				"DoorFrame",
				Vector3.new(0.5, dh, 0.5),
				doorCf * CFrame.new(x * 0.1, 0, dw / 4 - 0.25),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
			part(
				"DoorFrame",
				Vector3.new(0.5, dh, 0.5),
				doorCf * CFrame.new(x * 0.1, 0, -dw / 4 + 0.25),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
			part(
				"DoorFrame",
				Vector3.new(0.5, 0.5, dw / 2),
				doorCf * CFrame.new(x * 0.1, dh / 2 - 0.25, 0),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
		end
		part(
			"EndWall",
			Vector3.new(t, H - dh, dw),
			CFrame.new(wx, dh + (H - dh) / 2, 0),
			colors.Barn
		)
		part(
			"DoorTrim",
			Vector3.new(t + 0.3, 0.6, dw + 0.6),
			CFrame.new(wx, dh + 0.3, 0),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
	end
	-- Corner trims.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(
				"Trim",
				Vector3.new(t + 0.4, H, t + 0.4),
				CFrame.new(x * L / 2, H / 2, z * W / 2),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
		end
	end

	-- Gambrel roof: steep lower slopes and gentle upper ones, ridge running east-west.
	local lowRise, lowRun = 6, W * 0.2
	local topRise, topRun = 3.5, W / 2 - lowRun
	local overhang = 1.5
	local roofLength = L + overhang * 2
	for _, z in { -1, 1 } do
		local lowLength = math.sqrt(lowRise ^ 2 + lowRun ^ 2) + 0.8
		local lowAngle = math.atan2(lowRise, lowRun)
		part(
			"Roof",
			Vector3.new(roofLength, 0.6, lowLength),
			CFrame.new(0, H + lowRise / 2, z * (W / 2 - lowRun / 2))
				* CFrame.Angles(z * lowAngle, 0, 0),
			colors.Roof,
			Enum.Material.Slate
		)
		local topLength = math.sqrt(topRise ^ 2 + topRun ^ 2) + 0.6
		local topAngle = math.atan2(topRise, topRun)
		part(
			"Roof",
			Vector3.new(roofLength, 0.6, topLength),
			CFrame.new(0, H + lowRise + topRise / 2, z * topRun / 2)
				* CFrame.Angles(z * topAngle, 0, 0),
			colors.Roof,
			Enum.Material.Slate
		)
	end
	part(
		"Ridge",
		Vector3.new(roofLength, 0.5, 1),
		CFrame.new(0, H + lowRise + topRise + 0.1, 0),
		colors.Trim,
		Enum.Material.Wood,
		true
	)
	-- Gable ends (the shape under the roof) at both ends.
	for _, x in { -1, 1 } do
		local wx = x * L / 2
		part(
			"Gable",
			Vector3.new(t, lowRise, W - lowRun * 2),
			CFrame.new(wx, H + lowRise / 2, 0),
			colors.Barn
		)
		for _, z in { -1, 1 } do
			-- Wedge: tall face at +Z. Turned so the tall side is towards the middle.
			Kit.wedge({
				Name = "Gable",
				Size = Vector3.new(t, lowRise, lowRun),
				CFrame = base
					* CFrame.new(wx, H + lowRise / 2, z * (W / 2 - lowRun / 2))
					* CFrame.Angles(0, if z > 0 then math.pi else 0, 0),
				Color = colors.Barn,
				Material = Enum.Material.WoodPlanks,
			}, m)
			Kit.wedge({
				Name = "Gable",
				Size = Vector3.new(t, topRise, topRun),
				CFrame = base
					* CFrame.new(wx, H + lowRise + topRise / 2, z * topRun / 2)
					* CFrame.Angles(0, if z > 0 then math.pi else 0, 0),
				Color = colors.Barn,
				Material = Enum.Material.WoodPlanks,
			}, m)
		end
		-- Hayloft door: a white frame round a dark opening, a bale peeking out.
		part(
			"LoftDoor",
			Vector3.new(0.3, 4.5, 5),
			CFrame.new(wx + x * 0.55, H + 2.6, 0),
			colors.Roof,
			Enum.Material.Wood,
			true
		)
		part(
			"LoftFrame",
			Vector3.new(0.3, 5.3, 0.5),
			CFrame.new(wx + x * 0.65, H + 2.6, 2.6),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		part(
			"LoftFrame",
			Vector3.new(0.3, 5.3, 0.5),
			CFrame.new(wx + x * 0.65, H + 2.6, -2.6),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		part(
			"LoftFrame",
			Vector3.new(0.3, 0.5, 5.6),
			CFrame.new(wx + x * 0.65, H + 5.1, 0),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		part(
			"LoftBeam",
			Vector3.new(3, 0.6, 0.6),
			CFrame.new(wx + x * 1.5, H + 6, 0),
			colors.Wood,
			Enum.Material.Wood,
			true
		)
	end
	-- Weathervane on the ridge.
	local top = H + lowRise + topRise
	part(
		"VanePole",
		Vector3.new(0.25, 3, 0.25),
		CFrame.new(0, top + 1.5, 0),
		colors.Iron,
		Enum.Material.Metal,
		true
	)
	part(
		"VaneArrow",
		Vector3.new(3, 0.2, 0.2),
		CFrame.new(0, top + 2.6, 0) * CFrame.Angles(0, 0.6, 0),
		colors.Iron,
		Enum.Material.Metal,
		true
	)
	part(
		"VaneTail",
		Vector3.new(0.8, 0.8, 0.1),
		CFrame.new(0, top + 2.6, 0) * CFrame.Angles(0, 0.6, 0) * CFrame.new(-1.4, 0, 0),
		colors.Iron,
		Enum.Material.Metal,
		true
	)

	-- Hayloft over the west half, reached by hay-bale steps along the north wall.
	local loftY = cfg.LoftHeight
	local loftLength = L / 2 - 1
	part(
		"Loft",
		Vector3.new(loftLength, 0.8, W - 2),
		CFrame.new(-L / 2 + 0.5 + loftLength / 2, loftY - 0.4, 0),
		colors.Wood,
		Enum.Material.WoodPlanks
	)
	-- A rail along the loft's edge, open at the north end where the hay steps come up.
	part(
		"LoftRail",
		Vector3.new(0.4, 0.4, W - 9),
		CFrame.new(-0.3, loftY + 2.6, 3.5),
		colors.Wood,
		Enum.Material.Wood
	)
	for i = 0, 3 do
		local z = -1 + i * (W - 9) / 3 - (W - 9) / 2 + 4.5
		part(
			"LoftPost",
			Vector3.new(0.4, 2.8, 0.4),
			CFrame.new(-0.3, loftY + 1.4, z),
			colors.Wood,
			Enum.Material.Wood,
			true
		)
	end
	for _, z in { 0, W / 2 - 4 } do
		part(
			"LoftPillar",
			Vector3.new(0.8, loftY, 0.8),
			CFrame.new(-0.9, loftY / 2, z),
			colors.Wood,
			Enum.Material.Wood
		)
	end
	local steps = math.ceil(loftY / 2)
	for s = 1, steps do
		local h = s * loftY / steps
		part(
			"HayStep",
			Vector3.new(3.4, h, 3),
			CFrame.new(-0.5 + 1.8 + (steps - s) * 3.1, h / 2, -W / 2 + 2.5),
			colors.Hay,
			Enum.Material.Fabric
		)
	end
	-- Hay up in the loft and down below, decoy pumpkins among it.
	for i = 1, 5 do
		HideSeekProps.hayBale(
			base
				* CFrame.new(-L / 2 + 4 + i * 2.6, loftY, W / 2 - 3.5)
				* CFrame.Angles(0, ctx.Rng:NextNumber(-0.2, 0.2), 0),
			colors,
			ctx.Rng,
			m
		)
	end
	HideSeekProps.hayRoll(
		base * CFrame.new(L / 2 - 6, 0, W / 2 - 4) * CFrame.Angles(0, math.rad(90), 0),
		colors,
		ctx.Rng,
		m
	)
	HideSeekProps.hayRoll(
		base * CFrame.new(L / 2 - 11, 0, W / 2 - 4) * CFrame.Angles(0, math.rad(90), 0),
		colors,
		ctx.Rng,
		m
	)
	HideSeekProps.hayBale(base * CFrame.new(L / 2 - 5, 0, -W / 2 + 4), colors, ctx.Rng, m)
	table.insert(decoySpots, base * CFrame.new(-L / 2 + 6, loftY, -W / 2 + 5))
	table.insert(decoySpots, base * CFrame.new(-L / 4, loftY, 2))
	table.insert(decoySpots, base * CFrame.new(L / 2 - 8, 0, -W / 2 + 5))
	table.insert(decoySpots, base * CFrame.new(L / 4, 0, W / 2 - 8))
	-- A lantern hanging inside.
	local lamp = part(
		"BarnLamp",
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(L / 4, H - 3, 0),
		colors.Glow,
		Enum.Material.Neon,
		true
	)
	Kit.light(lamp, colors.Glow, 26, 1.2, true)
end

-- Farmhouse ------------------------------------------------------------------------------------

local function buildFarmhouse(
	ctx: MapBase.Ctx,
	parent: Instance,
	reserved: { Rect },
	decoySpots: { CFrame }
)
	local cfg = ctx.Def.Layout.Farmhouse
	local colors = ctx.Def.Colors
	local m = Kit.model("Farmhouse", parent)
	local size: Vector3 = cfg.Size
	local L, H, D = size.X, size.Y, size.Z
	local porch = cfg.PorchDepth
	-- The front (porch side) faces south (+Z), towards the farmyard.
	local base = CFrame.new(MapBase.at(ctx, cfg.Offset.X, cfg.Offset.Z, 0))
		* CFrame.Angles(0, math.pi, 0)
	reserve(
		reserved,
		Vector2.new(cfg.Offset.X, cfg.Offset.Z + porch / 2),
		Vector2.new(L + 4, D + porch + 4),
		2
	)

	local function part(
		name: string,
		s: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		decor: boolean?
	): Part
		local props = {
			Name = name,
			Size = s,
			CFrame = base * cf,
			Color = color,
			Material = material or Enum.Material.WoodPlanks,
		}
		return if decor then Kit.decor(props, m) else Kit.part(props, m)
	end

	local floorY = 1.6
	part(
		"Foundation",
		Vector3.new(L + 0.6, floorY, D + 0.6),
		CFrame.new(0, floorY / 2, 0),
		colors.Stone,
		Enum.Material.Cobblestone
	)
	part("House", Vector3.new(L, H, D), CFrame.new(0, floorY + H / 2, 0), colors.House)
	-- Roof with the ridge along the house, gables at the ends.
	local rise = 6
	local overhang = 1.4
	local half = D / 2 + overhang
	local slope = math.sqrt(half ^ 2 + rise ^ 2)
	local angle = math.atan2(rise, half)
	for _, z in { -1, 1 } do
		part(
			"Roof",
			Vector3.new(L + overhang * 2, 0.7, slope),
			CFrame.new(0, floorY + H + rise / 2 - 0.3, z * half / 2)
				* CFrame.Angles(z * angle, 0, 0),
			colors.Roof,
			Enum.Material.Slate
		)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Kit.wedge({
				Name = "Gable",
				Size = Vector3.new(0.8, rise, D / 2),
				CFrame = base
					* CFrame.new(x * (L / 2 - 0.4), floorY + H + rise / 2, z * D / 4)
					* CFrame.Angles(0, if z > 0 then math.pi else 0, 0),
				Color = colors.House,
				Material = Enum.Material.WoodPlanks,
			}, m)
		end
	end
	part(
		"Chimney",
		Vector3.new(2.6, rise + 4, 2.6),
		CFrame.new(L / 2 - 4, floorY + H + rise / 2 + 1, 2),
		colors.Barn:Lerp(colors.Stone, 0.4),
		Enum.Material.Brick
	)
	-- Corner trims and the eave line.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(
				"Trim",
				Vector3.new(0.6, H, 0.6),
				CFrame.new(x * L / 2, floorY + H / 2, z * D / 2),
				colors.Trim,
				Enum.Material.Wood,
				true
			)
		end
	end
	-- Windows on the front (local -Z after the turn is the porch side): glowing, with shutters.
	local front = -D / 2
	local function window(x: number, y: number)
		part(
			"WindowFrame",
			Vector3.new(3.6, 4.4, 0.3),
			CFrame.new(x, y, front - 0.15),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		part(
			"Window",
			Vector3.new(2.8, 3.6, 0.3),
			CFrame.new(x, y, front - 0.25),
			colors.Glow,
			Enum.Material.Neon,
			true
		)
		part(
			"WindowBar",
			Vector3.new(2.8, 0.25, 0.35),
			CFrame.new(x, y, front - 0.35),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		part(
			"WindowBar",
			Vector3.new(0.25, 3.6, 0.35),
			CFrame.new(x, y, front - 0.35),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
		for _, side in { -1, 1 } do
			part(
				"Shutter",
				Vector3.new(1.4, 4.2, 0.25),
				CFrame.new(x + side * 2.6, y, front - 0.2),
				colors.Cloth,
				Enum.Material.WoodPlanks,
				true
			)
		end
	end
	for _, x in { -10, -5, 5, 10 } do
		window(x, floorY + 4)
	end
	for _, x in { -8, 0, 8 } do
		window(x, floorY + 9.2)
	end
	part(
		"Door",
		Vector3.new(3.4, 6.4, 0.4),
		CFrame.new(0, floorY + 3.2, front - 0.2),
		colors.Wood,
		Enum.Material.WoodPlanks,
		true
	)
	part(
		"DoorFrame",
		Vector3.new(4.2, 7, 0.3),
		CFrame.new(0, floorY + 3.5, front - 0.1),
		colors.Trim,
		Enum.Material.Wood,
		true
	)
	local wreath = Kit.decor({
		Name = "Wreath",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.6, 1.6),
		CFrame = base * CFrame.new(0, floorY + 5, front - 0.5) * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Leaves[1],
		Material = Enum.Material.LeafyGrass,
	}, m)
	wreath.Name = "Wreath"

	-- Porch: a deck along the front with posts, a rail, a sloping roof and steps.
	local deckZ = front - porch / 2
	part(
		"Porch",
		Vector3.new(L, floorY, porch),
		CFrame.new(0, floorY / 2, deckZ),
		colors.Wood,
		Enum.Material.WoodPlanks
	)
	local porchRoofY = floorY + 8.5
	part(
		"PorchRoof",
		Vector3.new(L + 1, 0.5, porch + 1.6),
		CFrame.new(0, porchRoofY, deckZ - 0.3) * CFrame.Angles(math.rad(-10), 0, 0),
		colors.Roof,
		Enum.Material.Slate
	)
	for i = 0, 5 do
		local x = -L / 2 + 0.6 + i * (L - 1.2) / 5
		part(
			"PorchPost",
			Vector3.new(0.7, 8, 0.7),
			CFrame.new(x, floorY + 4, front - porch + 0.5),
			colors.Trim,
			Enum.Material.Wood
		)
	end
	for _, side in { -1, 1 } do
		part(
			"PorchRail",
			Vector3.new(L / 2 - 3, 0.4, 0.4),
			CFrame.new(side * (L / 4 + 1.5), floorY + 2.6, front - porch + 0.5),
			colors.Trim,
			Enum.Material.Wood
		)
		part(
			"PorchRail",
			Vector3.new(L / 2 - 3, 0.3, 0.3),
			CFrame.new(side * (L / 4 + 1.5), floorY + 1.2, front - porch + 0.5),
			colors.Trim,
			Enum.Material.Wood,
			true
		)
	end
	for s = 1, 2 do
		part(
			"Step",
			Vector3.new(5, floorY * s / 3, 1.4),
			CFrame.new(0, floorY * s / 6, front - porch - (3 - s) * 1.4 + 0.7),
			colors.Wood,
			Enum.Material.WoodPlanks
		)
	end
	-- Rocking chairs (only for looks) and pumpkins on the porch.
	for _, x in { -9, 9 } do
		local chair = base * CFrame.new(x, floorY, deckZ + 0.5) * CFrame.Angles(0, math.pi, 0)
		Kit.prop("RockingChair", chair, m, 4, function()
			local c = Kit.model("RockingChair", m)
			Kit.decor({
				Name = "Seat",
				Size = Vector3.new(2.2, 0.3, 2),
				CFrame = chair * CFrame.new(0, 1.5, 0),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, c)
			Kit.decor({
				Name = "Back",
				Size = Vector3.new(2.2, 2.6, 0.3),
				CFrame = chair * CFrame.new(0, 2.9, 1) * CFrame.Angles(math.rad(-12), 0, 0),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, c)
			for _, side in { -1, 1 } do
				Kit.decor({
					Name = "Rocker",
					Size = Vector3.new(0.25, 0.25, 2.8),
					CFrame = chair * CFrame.new(side * 1, 0.4, 0),
					Color = colors.Wood,
					Material = Enum.Material.Wood,
				}, c)
				Kit.decor({
					Name = "Leg",
					Size = Vector3.new(0.25, 1.2, 0.25),
					CFrame = chair * CFrame.new(side * 1, 0.9, 0),
					Color = colors.Wood,
					Material = Enum.Material.Wood,
				}, c)
			end
			return c
		end, { Visual = true })
	end
	table.insert(decoySpots, base * CFrame.new(-4.5, 0, front - porch - 3))
	table.insert(decoySpots, base * CFrame.new(4.5, 0, front - porch - 3.5))
	table.insert(decoySpots, base * CFrame.new(-13, floorY, deckZ))
	table.insert(decoySpots, base * CFrame.new(13, floorY, deckZ - 1))
	-- Porch lanterns.
	for _, x in { -6, 6 } do
		local lamp = part(
			"PorchLamp",
			Vector3.new(0.8, 1.1, 0.8),
			CFrame.new(x, porchRoofY - 1.4, front - porch + 1.2),
			colors.Glow,
			Enum.Material.Neon,
			true
		)
		Kit.light(lamp, colors.Glow, 18, 1.2, true)
	end
end

-- Small props ------------------------------------------------------------------------------------

local function scarecrow(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Scarecrow", cf, parent, 10, function()
		local m = Kit.model("Scarecrow", parent)
		Kit.part({
			Name = "Pole",
			Size = Vector3.new(0.7, 8.5, 0.7),
			CFrame = cf * CFrame.new(0, 4.25, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Arms",
			Size = Vector3.new(7, 0.5, 0.5),
			CFrame = cf * CFrame.new(0, 6.4, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Shirt",
			Size = Vector3.new(2.8, 3, 1.4),
			CFrame = cf * CFrame.new(0, 5.8, 0),
			Color = colors.Cloth,
			Material = Enum.Material.Fabric,
		}, m)
		Kit.decor({
			Name = "Patch",
			Size = Vector3.new(0.8, 0.8, 0.1),
			CFrame = cf * CFrame.new(0.6, 5.4, -0.72),
			Color = colors.Barn,
			Material = Enum.Material.Fabric,
		}, m)
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Sleeve",
				Size = Vector3.new(2.2, 1.1, 1.1),
				CFrame = cf * CFrame.new(side * 2.4, 6.4, 0),
				Color = colors.Cloth,
				Material = Enum.Material.Fabric,
			}, m)
			oval({
				Name = "Straw",
				Size = Vector3.new(1.2, 0.8, 0.8),
				CFrame = cf * CFrame.new(side * 3.8, 6.4, 0),
				Color = colors.Hay,
				Material = Enum.Material.Fabric,
			}, m)
		end
		oval({
			Name = "Head",
			Size = Vector3.new(2.2, 2.4, 2.2),
			CFrame = cf * CFrame.new(0, 8.4, 0),
			Color = colors.Sack,
			Material = Enum.Material.Fabric,
		}, m)
		-- Stitched smile and button eyes.
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.4, 0.4, 0.4),
				CFrame = cf * CFrame.new(side * 0.45, 8.7, -1),
				Color = colors.Iron,
			}, m)
		end
		Kit.decor({
			Name = "Smile",
			Size = Vector3.new(1, 0.15, 0.1),
			CFrame = cf * CFrame.new(0, 8, -1.05),
			Color = colors.Iron,
		}, m)
		Kit.decor({
			Name = "HatBrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 3.6, 3.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 9.5, 0)),
			Color = colors.Hay,
			Material = Enum.Material.Fabric,
		}, m)
		Kit.decor({
			Name = "Hat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 2, 2),
			CFrame = Kit.upright(cf * CFrame.new(0, 10.2, 0)),
			Color = colors.Hay,
			Material = Enum.Material.Fabric,
		}, m)
		Kit.decor({
			Name = "HatBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35, 2.05, 2.05),
			CFrame = Kit.upright(cf * CFrame.new(0, 9.75, 0)),
			Color = colors.Barn,
			Material = Enum.Material.Fabric,
		}, m)
		return m
	end)
end

-- Little pumpkins (prop "Pumpkin") sitting on a heap of hay in a cart: `spots` are their
-- middles (relative to `cf`), `size` their width and height. Their colours are drawn now.
local function littlePumpkins(
	ctx: MapBase.Ctx,
	cf: CFrame,
	spots: { Vector3 },
	size: Vector2
): (Model) -> ()
	local colors = ctx.Def.Colors
	local shades = {}
	for i in spots do
		shades[i] = jitter(colors.Orange, ctx.Rng, 0.08)
	end
	return function(m: Model)
		for i, p in spots do
			local foot = cf * CFrame.new(p.X, p.Y - size.Y / 2, p.Z) * CFrame.Angles(0, i, 0)
			Kit.prop("Pumpkin", foot, m, size.Y, function()
				local pumpkin = Kit.model("Pumpkin", m)
				pumpkin.PrimaryPart = oval({
					Name = "LittlePumpkin",
					Size = Vector3.new(size.X, size.Y, size.X),
					CFrame = foot * CFrame.new(0, size.Y / 2, 0),
					Color = shades[i],
				}, pumpkin)
				return pumpkin
			end, { Visual = true })
		end
	end
end

local function wheelbarrow(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	local pumpkins = littlePumpkins(ctx, cf, {
		Vector3.new(-0.6, 3.1, -0.8),
		Vector3.new(0.6, 3.1, 0.6),
		Vector3.new(-0.3, 3.2, 1.2),
	}, Vector2.new(1.4, 1.1))
	Kit.prop("Wheelbarrow", cf, parent, 3, function()
		local m = Kit.model("Wheelbarrow", parent)
		Kit.part({
			Name = "Tray",
			Size = Vector3.new(3, 1.4, 4),
			CFrame = cf * CFrame.new(0, 1.9, 0),
			Color = colors.Barn,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Rim",
			Size = Vector3.new(3.3, 0.25, 4.3),
			CFrame = cf * CFrame.new(0, 2.65, 0),
			Color = Kit.shade(colors.Barn, 0.2),
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 1.8, 1.8),
			CFrame = cf * CFrame.new(0, 0.9, -2.4),
			Color = colors.Iron,
		}, m)
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Handle",
				Size = Vector3.new(0.3, 0.3, 5.5),
				CFrame = cf * CFrame.new(side * 1.2, 1.6, 0.6) * CFrame.Angles(math.rad(10), 0, 0),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
			Kit.decor({
				Name = "Leg",
				Size = Vector3.new(0.3, 1.4, 0.3),
				CFrame = cf * CFrame.new(side * 1.2, 0.7, 1.2),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
		end
		-- A few little pumpkins (smaller than the hiding ones) and a heap of hay.
		oval({
			Name = "Hay",
			Size = Vector3.new(2.6, 0.8, 3.6),
			CFrame = cf * CFrame.new(0, 2.7, 0),
			Color = colors.Hay,
			Material = Enum.Material.Fabric,
		}, m)
		pumpkins(m)
		return m
	end)
end

local function well(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Well", cf, parent, 9, function()
		local m = Kit.model("Well", parent)
		Kit.part({
			Name = "Wall",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 6, 6),
			CFrame = Kit.upright(cf * CFrame.new(0, 1.5, 0)),
			Color = colors.Stone,
			Material = Enum.Material.Cobblestone,
		}, m)
		Kit.decor({
			Name = "Water",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 4.6, 4.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 2.9, 0)),
			Color = Color3.fromRGB(50, 70, 90),
			Material = Enum.Material.Glass,
		}, m)
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Post",
				Size = Vector3.new(0.5, 6, 0.5),
				CFrame = cf * CFrame.new(side * 2.6, 5.5, 0),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
			Kit.decor({
				Name = "Roof",
				Size = Vector3.new(3.6, 0.3, 4.4),
				CFrame = cf
					* CFrame.new(side * 1.5, 8.9, 0)
					* CFrame.Angles(0, 0, side * math.rad(-35)),
				Color = colors.Roof,
				Material = Enum.Material.Slate,
			}, m)
		end
		Kit.decor({
			Name = "Crank",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5.6, 0.4, 0.4),
			CFrame = cf * CFrame.new(0, 7.2, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Bucket",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = Kit.upright(cf * CFrame.new(0, 5.6, 0)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		return m
	end)
end

-- A stack of bales (and sometimes a roll), with spots for decoy pumpkins around it.
local function hayStack(ctx: MapBase.Ctx, cf: CFrame, parent: Instance, decoySpots: { CFrame })
	local colors = ctx.Def.Colors
	local m = Kit.model("HayStack", parent)
	local kind = ctx.Rng:NextInteger(1, 3)
	if kind == 1 then
		for i = -1, 1 do
			HideSeekProps.hayBale(cf * CFrame.new(i * 4.5, 0, 0), colors, ctx.Rng, m)
		end
		for i = -0.5, 0.5 do
			HideSeekProps.hayBale(
				cf
					* CFrame.new(i * 4.5, 2.4, 0)
					* CFrame.Angles(0, ctx.Rng:NextNumber(-0.1, 0.1), 0),
				colors,
				ctx.Rng,
				m
			)
		end
		HideSeekProps.hayBale(cf * CFrame.new(0, 4.8, 0), colors, ctx.Rng, m)
	elseif kind == 2 then
		HideSeekProps.hayRoll(cf * CFrame.new(-2.5, 0, 0), colors, ctx.Rng, m)
		HideSeekProps.hayRoll(cf * CFrame.new(2.5, 0, 0.4), colors, ctx.Rng, m)
	else
		HideSeekProps.hayBale(cf, colors, ctx.Rng, m)
		HideSeekProps.hayBale(cf * CFrame.new(0, 0, 2.8), colors, ctx.Rng, m)
		HideSeekProps.hayBale(
			cf * CFrame.new(0.3, 2.4, 1.4) * CFrame.Angles(0, 0.3, 0),
			colors,
			ctx.Rng,
			m
		)
	end
	table.insert(decoySpots, cf * CFrame.new(0, 0, -4.2))
	table.insert(decoySpots, cf * CFrame.new(ctx.Rng:NextNumber(-3, 3), 0, 4.8))
end

-- A little red tractor.
local function buildTractor(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Tractor", cf, parent, 6, function()
		local m = Kit.model("Tractor", parent)
		local red = colors.Barn
		Kit.part({
			Name = "Body",
			Size = Vector3.new(3, 2.4, 6),
			CFrame = cf * CFrame.new(0, 2.4, -0.8),
			Color = red,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Grille",
			Size = Vector3.new(2.4, 1.8, 0.2),
			CFrame = cf * CFrame.new(0, 2.4, -3.85),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		for _, side in { -1, 1 } do
			local light = Kit.decor({
				Name = "Headlight",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = cf * CFrame.new(side * 0.9, 3.2, -3.9),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, m)
			light.Name = "Headlight"
		end
		Kit.part({
			Name = "Cab",
			Size = Vector3.new(3.4, 0.5, 3),
			CFrame = cf * CFrame.new(0, 6.6, 1.6),
			Color = red,
			Material = Enum.Material.Metal,
		}, m)
		for _, x in { -1.5, 1.5 } do
			for _, z in { 0.3, 2.9 } do
				Kit.decor({
					Name = "CabPost",
					Size = Vector3.new(0.25, 3, 0.25),
					CFrame = cf * CFrame.new(x, 5.1, z),
					Color = colors.Iron,
					Material = Enum.Material.Metal,
				}, m)
			end
		end
		Kit.decor({
			Name = "Seat",
			Size = Vector3.new(1.6, 0.5, 1.4),
			CFrame = cf * CFrame.new(0, 3.9, 1.8),
			Color = colors.Iron,
		}, m)
		Kit.decor({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 1.2, 1.2),
			CFrame = cf
				* CFrame.new(0, 4.6, 0.6)
				* CFrame.Angles(math.rad(60), 0, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = colors.Iron,
		}, m)
		Kit.decor({
			Name = "Exhaust",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 0.35, 0.35),
			CFrame = Kit.upright(cf * CFrame.new(0.9, 4.6, -2.6)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		for _, side in { -1, 1 } do
			Kit.part({
				Name = "BigWheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.3, 4.6, 4.6),
				CFrame = cf * CFrame.new(side * 2.2, 2.3, 1.8),
				Color = colors.Iron,
			}, m)
			Kit.decor({
				Name = "Hub",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 2, 2),
				CFrame = cf * CFrame.new(side * 2.2, 2.3, 1.8),
				Color = colors.CornTop,
				Material = Enum.Material.Metal,
			}, m)
			Kit.part({
				Name = "FrontWheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.9, 2.4, 2.4),
				CFrame = cf * CFrame.new(side * 1.8, 1.2, -2.8),
				Color = colors.Iron,
			}, m)
			Kit.decor({
				Name = "Hub",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 1, 1),
				CFrame = cf * CFrame.new(side * 1.8, 1.2, -2.8),
				Color = colors.CornTop,
				Material = Enum.Material.Metal,
			}, m)
		end
		return m
	end)
end

-- A wooden harvest cart (decoy pumpkins sit round it).
local function buildCart(ctx: MapBase.Ctx, cf: CFrame, parent: Instance)
	local colors = ctx.Def.Colors
	local pumpkins = littlePumpkins(ctx, cf, {
		Vector3.new(-0.9, 3.5, -1.8),
		Vector3.new(0.8, 3.5, 0.2),
		Vector3.new(-0.5, 3.5, 2),
	}, Vector2.new(1.7, 1.3))
	Kit.prop("HarvestCart", cf, parent, 4, function()
		local m = Kit.model("HarvestCart", parent)
		Kit.part({
			Name = "Bed",
			Size = Vector3.new(4.4, 0.5, 7),
			CFrame = cf * CFrame.new(0, 2.4, 0),
			Color = colors.Wood,
			Material = Enum.Material.WoodPlanks,
		}, m)
		for _, side in { -1, 1 } do
			Kit.decor({
				Name = "Side",
				Size = Vector3.new(0.3, 1.2, 7),
				CFrame = cf * CFrame.new(side * 2.1, 3.2, 0),
				Color = Kit.shade(colors.Wood, -0.15),
				Material = Enum.Material.WoodPlanks,
			}, m)
			Kit.part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5, 3.6, 3.6),
				CFrame = cf * CFrame.new(side * 2.6, 1.8, 0.6),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
			Kit.decor({
				Name = "Hub",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.7, 0.9, 0.9),
				CFrame = cf * CFrame.new(side * 2.6, 1.8, 0.6),
				Color = colors.Iron,
			}, m)
			Kit.decor({
				Name = "Shaft",
				Size = Vector3.new(0.3, 0.3, 5),
				CFrame = cf * CFrame.new(side * 1.4, 2, -5.6) * CFrame.Angles(math.rad(-8), 0, 0),
				Color = colors.Wood,
				Material = Enum.Material.Wood,
			}, m)
		end
		Kit.decor({
			Name = "Back",
			Size = Vector3.new(4.4, 1.2, 0.3),
			CFrame = cf * CFrame.new(0, 3.2, 3.4),
			Color = Kit.shade(colors.Wood, -0.15),
			Material = Enum.Material.WoodPlanks,
		}, m)
		oval({
			Name = "Hay",
			Size = Vector3.new(3.8, 1, 6.2),
			CFrame = cf * CFrame.new(0, 2.9, 0),
			Color = colors.Hay,
			Material = Enum.Material.Fabric,
		}, m)
		pumpkins(m)
		return m
	end)
end

-- A small pond with stones, reeds and lily pads (you can walk across it).
local function buildPond(ctx: MapBase.Ctx, center: Vector2, radius: number, parent: Instance)
	local colors = ctx.Def.Colors
	local m = Kit.model("Pond", parent)
	Kit.decor({
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = Kit.upright(CFrame.new(at(ctx, center, 0.12))),
		Color = Color3.fromRGB(70, 130, 150),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	}, m)
	Kit.decor({
		Name = "Shore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, radius * 2 + 2.4, radius * 2 + 2.4),
		CFrame = Kit.upright(CFrame.new(at(ctx, center, 0.08))),
		Color = colors.Dirt,
		Material = Enum.Material.Mud,
	}, m)
	local stones = math.floor(radius * 1.6)
	for i = 1, stones do
		local a = i / stones * math.pi * 2 + ctx.Rng:NextNumber(-0.15, 0.15)
		local r = radius + 0.6
		local s = ctx.Rng:NextNumber(1, 1.8)
		oval({
			Name = "Stone",
			Size = Vector3.new(s * 1.4, s * 0.8, s),
			CFrame = CFrame.new(at(ctx, center + Vector2.new(math.cos(a), math.sin(a)) * r, 0.2))
				* CFrame.Angles(0, a, 0),
			Color = jitter(colors.Stone, ctx.Rng, 0.12),
			Material = Enum.Material.Slate,
		}, m)
	end
	for i = 1, 6 do
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local p = center
			+ Vector2.new(math.cos(a), math.sin(a)) * ctx.Rng:NextNumber(0, radius * 0.7)
		Kit.decor({
			Name = "LilyPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 1.6, 1.6),
			CFrame = Kit.upright(CFrame.new(at(ctx, p, 0.25))),
			Color = jitter(colors.Vine, ctx.Rng, 0.1),
		}, m)
		if i % 2 == 0 then
			local b = a + ctx.Rng:NextNumber(-0.5, 0.5)
			local q = center + Vector2.new(math.cos(b), math.sin(b)) * (radius - 0.5)
			Kit.decor({
				Name = "Reed",
				Size = Vector3.new(0.2, 3.4, 0.2),
				CFrame = CFrame.new(at(ctx, q, 1.7)),
				Color = colors.Vine,
			}, m)
			oval({
				Name = "Cattail",
				Size = Vector3.new(0.4, 1, 0.4),
				CFrame = CFrame.new(at(ctx, q, 3.4)),
				Color = colors.Wood,
			}, m)
		end
	end
end

-- The edge: a rail fence inside the invisible wall, autumn trees and bushes behind it.
local function buildBorder(ctx: MapBase.Ctx, parent: Instance, reserved: { Rect })
	local colors = ctx.Def.Colors
	local folder = Kit.model("Border", parent)
	local fence = ctx.Half.X - 6
	local corners = {
		Vector2.new(-fence, -fence),
		Vector2.new(fence, -fence),
		Vector2.new(fence, fence),
		Vector2.new(-fence, fence),
	}
	for c = 1, 4 do
		HideSeekProps.railFence(
			at(ctx, corners[c]),
			at(ctx, corners[c % 4 + 1]),
			3.4,
			colors.Wood,
			folder
		)
	end
	local ring = ctx.Half.X - 2.5
	local trees = ctx.Def.Layout.BorderTrees
	for i = 1, trees do
		local t = (i - 1) / trees * 4
		local side = math.floor(t)
		local f = (t - side) * 2 - 1
		local along = f * (ring - 4) + ctx.Rng:NextNumber(-3, 3)
		local p = if side == 0
			then Vector2.new(along, -ring)
			elseif side == 1 then Vector2.new(ring, along)
			elseif side == 2 then Vector2.new(-along, ring)
			else Vector2.new(-ring, -along)
		local rect = { Center = p, Half = Vector2.new(3, 3) }
		if not isFree(reserved, rect) then
			continue
		end
		HideSeekProps.autumnTree(
			CFrame.new(at(ctx, p)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
			ctx.Rng:NextNumber(13, 18),
			colors.Leaves,
			colors.Wood,
			ctx.Rng,
			folder
		)
		-- A bush between this tree and the next.
		local q = p:Lerp(Vector2.new(0, 0), 0.02)
			+ Vector2.new(ctx.Rng:NextNumber(-6, 6), ctx.Rng:NextNumber(-6, 6))
		if math.abs(q.X) > fence + 1 or math.abs(q.Y) > fence + 1 then
			oval({
				Name = "Bush",
				Size = Vector3.new(
					ctx.Rng:NextNumber(5, 8),
					ctx.Rng:NextNumber(3, 4.5),
					ctx.Rng:NextNumber(4, 6)
				),
				CFrame = CFrame.new(at(ctx, q, 1.4)),
				Color = jitter(colors.Vine, ctx.Rng, 0.15),
				Material = Enum.Material.LeafyGrass,
			}, folder)
		end
	end
end

-- Build ------------------------------------------------------------------------------------------

function PumpkinFarm.Build(def: any): Model
	local colors = def.Colors
	local layout = def.Layout
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Grass,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.WoodPlanks,
	})
	local model = ctx.Model
	-- The edge walls stay (they keep everyone in) but you see the fence and trees instead.
	local walls = model:FindFirstChild("Walls")
	if walls then
		for _, wall in walls:GetChildren() do
			if wall:IsA("BasePart") then
				wall.Transparency = 1
				wall.CastShadow = false
			end
		end
	end
	local reserved: { Rect } = {}
	local decoySpots: { CFrame } = {}
	local farm = Kit.model("Farm", model)

	-- Seeker hut first (its spot must stay clear).
	local hut = layout.SeekerHut
	local hutPos = MapBase.at(ctx, hut.Offset.X, hut.Offset.Z, 0)
	local facing = MapBase.at(ctx, hut.FacesTowards.X, hut.FacesTowards.Z, 0)
	HideSeekProps.seekerHut(CFrame.lookAt(hutPos, facing), hut.Size, {
		Wall = colors.HutWall,
		Roof = colors.Roof,
		Trim = colors.Trim,
		Door = colors.HutDoor,
		Glow = colors.Glow,
		Text = colors.HutText,
	}, hut.Spawns, farm)
	reserve(
		reserved,
		Vector2.new(hut.Offset.X, hut.Offset.Z),
		Vector2.new(hut.Size.X + 6, hut.Size.Z + 6),
		3
	)

	buildPaths(ctx, farm)
	for _, segment in layout.Paths do
		local a: Vector2, b: Vector2 = segment[1], segment[2]
		reserve(reserved, (a + b) / 2, Vector2.new(math.abs(b.X - a.X), math.abs(b.Y - a.Y)), 3.5)
	end
	buildBarn(ctx, farm, reserved, decoySpots)
	buildFarmhouse(ctx, farm, reserved, decoySpots)
	buildCorn(ctx, farm, reserved)
	buildFields(ctx, farm, reserved)

	-- Spawns: hiders start round the farmyard (instead of MapBase's ring; keep them clear).
	local spawnFolder = model:FindFirstChild(def.SpawnFolder) :: Instance
	spawnFolder:ClearAllChildren()
	for i = 1, math.min(def.Spawns, #layout.HiderSpawns) do
		local p: Vector2 = layout.HiderSpawns[i]
		HideSeekProps.hiderSpawn(at(ctx, p), ctx.Rng, spawnFolder)
		reserve(reserved, p, Vector2.new(6, 6), 1)
	end

	local well0: Vector2 = layout.Well
	well(ctx, CFrame.new(at(ctx, well0)) * CFrame.Angles(0, 0.4, 0), farm)
	reserve(reserved, well0, Vector2.new(7, 7), 2)
	for _, p in layout.Lanterns do
		HideSeekProps.lantern(
			CFrame.new(at(ctx, p)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
			colors,
			farm
		)
		reserve(reserved, p, Vector2.new(2, 2), 1)
	end

	-- Scattered farm things, each on a free spot inside the fence.
	local limit = ctx.Half.X - 10
	local props = Kit.model("Props", farm)
	-- Scarecrows stand in the fields, among the pumpkins.
	for _, p in layout.Scarecrows do
		scarecrow(
			ctx,
			CFrame.new(at(ctx, p)) * CFrame.Angles(0, math.pi + ctx.Rng:NextNumber(-0.4, 0.4), 0),
			props
		)
	end
	-- A little orchard between the farmhouse and the hut, in two rows.
	local orchard = layout.Orchard
	local perRow = math.ceil(orchard.Trees / 2)
	for i = 1, orchard.Trees do
		local row = if i <= perRow then -1 else 1
		local n = (i - 1) % perRow
		local p = orchard.Offset
			+ Vector2.new(
				row * orchard.Size.X / 4,
				(n / math.max(1, perRow - 1) - 0.5) * orchard.Size.Y
			)
			+ Vector2.new(ctx.Rng:NextNumber(-1, 1), ctx.Rng:NextNumber(-1, 1))
		HideSeekProps.autumnTree(
			CFrame.new(at(ctx, p)) * CFrame.Angles(0, i, 0),
			ctx.Rng:NextNumber(11, 14),
			{ colors.Leaves[2], colors.Leaves[1] },
			colors.Wood,
			ctx.Rng,
			props
		)
		table.insert(decoySpots, CFrame.new(at(ctx, p + Vector2.new(3.4, -1.2))))
	end
	reserve(reserved, orchard.Offset, orchard.Size, 3)
	local tractor = layout.Tractor
	buildTractor(
		ctx,
		CFrame.lookAt(at(ctx, tractor.Position), at(ctx, tractor.FacesTowards)),
		props
	)
	reserve(reserved, tractor.Position, Vector2.new(9, 9), 2)
	local cart = layout.Cart
	local cartCf = CFrame.lookAt(at(ctx, cart.Position), at(ctx, cart.FacesTowards))
	buildCart(ctx, cartCf, props)
	reserve(reserved, cart.Position, Vector2.new(10, 10), 2)
	for _, offset in
		{ Vector3.new(-3.6, 0, 1.5), Vector3.new(3.8, 0, -0.5), Vector3.new(-3.2, 0, -2.6) }
	do
		table.insert(decoySpots, 1, cartCf * CFrame.new(offset))
	end
	local pond = layout.Pond
	buildPond(ctx, pond.Position, pond.Radius, props)
	reserve(reserved, pond.Position, Vector2.new(pond.Radius * 2, pond.Radius * 2), 2)
	-- Scattered farm things, each on a free spot inside the fence.
	for _ = 1, layout.HayStacks do
		local p = freeSpot(ctx, reserved, 7, limit)
		if p then
			hayStack(
				ctx,
				CFrame.new(at(ctx, p)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
				props,
				decoySpots
			)
		end
	end
	for _ = 1, layout.Wheelbarrows do
		local p = freeSpot(ctx, reserved, 4, limit)
		if p then
			wheelbarrow(
				ctx,
				CFrame.new(at(ctx, p)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
				props
			)
			table.insert(decoySpots, CFrame.new(at(ctx, p + Vector2.new(3.5, 2))))
		end
	end
	buildBorder(ctx, farm, reserved)

	-- Loose decoys: by the hay, barn, porch, trees and wheelbarrows, then anywhere free.
	local decoys = Kit.model("Decoys", farm)
	local spots = table.clone(decoySpots)
	for i = #spots, 2, -1 do
		local j = ctx.Rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, layout.ExtraDecoys do
		local cf: CFrame? = spots[i]
		if cf == nil then
			local p = freeSpot(ctx, reserved, 2.5, limit)
			if p then
				cf = CFrame.new(at(ctx, p))
			end
		end
		local spot = cf
		if spot then
			HidingPumpkin.Decoy(
				spot * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
				ctx.Rng,
				decoys
			)
		end
	end
	return model
end

return PumpkinFarm
