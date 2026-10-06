--!strict
--[[
	The lobby's prop kit: chunky, rounded, toy-like decorations built from Parts (ovals, rounded
	cylinders, bent segments). Used by the hub (src/server/Hub/) and free for the maps.

	Every builder takes a painter (Kit.painter(palette)), so colours come from that palette by
	role (PaletteRole attributes: "Repaint hub" recolours them), and goes through Kit.prop, so a
	model with the same name in ReplicatedStorage.Custom.Props replaces every copy at once (in
	the lobby AND the round maps, which use the same names for the same kind of thing):

	  Prop name       Built by                 What
	  Pumpkin         Props.Pumpkin            ribbed pumpkin with a curly stem and a leaf
	  JackOLantern    Props.JackOLantern       ribbed pumpkin with a glowing carved face
	  SpookyTree      Props.Tree               twisted tree with puffy dark leaves
	  DeadTree        Props.Tree (Bare)        twisted bare tree, lanterns hanging from it
	  Lamppost        Props.Lamppost           iron lamppost with a glass lantern
	  Bench           Props.Bench              wooden bench with iron sides
	  Gravestone      Props.Gravestone         rounded, cross or pointed tombstone
	  HayRoll         Props.HayRoll            round roll of hay lying on its side
	  Candle          Props.Candle             wax candle with drips and a flame
	  Cobweb          Props.Cobweb             spider web (thin Beams: costs a single part)
	  Crate           Props.Crate              wooden crate
	  Barrel          Props.Barrel             bulging barrel with iron hoops
	  Lantern         Props.Lantern            small glass lantern (hanging or standing)
	  FencePost       Props.FencePost          iron fence post with a pumpkin on top
	  Signpost        Props.Signpost           wooden post with arrow boards (text from Config)
	  Bat             Props.Bat                little flying bat (bobs: tag HubFloat)
	  Mushroom        Props.Mushrooms          a cluster of glowing toadstools
	Not swappable (they connect two points): Props.Bunting (flags on a rope), Props.FenceSpan.
	Lit props pass their light to Kit.prop, so a custom one with no light still glows.

	Facing: a prop's front is cf.LookVector (-Z); it stands on cf (unless it says "centre").
]]

local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)

type Painter = Kit.Painter
type Props = Kit.Props

local Props = {}

-- Helpers -------------------------------------------------------------------------------------

-- A frame centred between a and b with its X axis running from a to b (cylinders run along X).
function Props.segment(a: Vector3, b: Vector3): CFrame
	local x = (b - a).Unit
	local ref = if math.abs(x.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local z = x:Cross(ref).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix((a + b) / 2, x, y, z)
end

-- A cylinder from a to b.
local function rod(
	paint: Painter,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	props: Props,
	parent: Instance,
	solid: boolean?
): Part
	local p = table.clone(props)
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new((b - a).Magnitude, diameter, diameter)
	p.CFrame = Props.segment(a, b)
	return if solid then paint.part(p, parent) else paint.decor(p, parent)
end

local function glowLight(paint: Painter, parent: BasePart, range: number, brightness: number)
	Kit.light(parent, paint.color("Glow"), range, brightness, true)
		:SetAttribute("PaletteRole", "Glow")
end

-- A point on the cubic curve a Beam draws from a to b sagging `sag` studs (t = 0..1).
local function sagPoint(a: Vector3, b: Vector3, sag: number, t: number): Vector3
	local c = sag / 0.75
	local p1 = a - Vector3.new(0, c, 0)
	local p2 = b - Vector3.new(0, c, 0)
	local u = 1 - t
	return a * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + b * (t * t * t)
end

-- A sagging Beam (rope, strand) from a to b, held by attachments on `holder`.
local function beam(
	holder: BasePart,
	a: Vector3,
	b: Vector3,
	sag: number,
	width: number,
	color: Color3,
	transparency: number,
	sagDirection: Vector3?
): Beam
	local down = sagDirection or Vector3.new(0, -1, 0)
	local function attach(point: Vector3): Attachment
		local att = Instance.new("Attachment")
		att.Name = "Point"
		local world = CFrame.fromMatrix(
			point,
			down,
			(down:Cross(Vector3.zAxis).Magnitude > 0.1) and down:Cross(Vector3.zAxis).Unit
				or down:Cross(Vector3.xAxis).Unit
		)
		att.CFrame = holder.CFrame:ToObjectSpace(world)
		att.Parent = holder
		return att
	end
	local b0, b1 = attach(a), attach(b)
	local c = sag / 0.75
	local strand = Instance.new("Beam")
	strand.Name = "Strand"
	strand.Attachment0 = b0
	strand.Attachment1 = b1
	strand.CurveSize0 = c
	strand.CurveSize1 = -c
	strand.Width0 = width
	strand.Width1 = width
	strand.Color = ColorSequence.new(color)
	strand.Transparency = NumberSequence.new(transparency)
	strand.LightEmission = 0.2
	strand.FaceCamera = true
	strand.Segments = if sag > 0 then 8 else 1
	strand.Parent = holder
	return strand
end

--[[
	A pointy witch-hat roof: two eight-sided tiers of wedges (16 parts), the top one a little
	crooked, standing on `base` (its middle at the eaves). `style` gives the colour (Color, or
	PaletteRole and PaletteShade). Returns where the tip is (put a finial there).
]]
function Props.spire(
	paint: Painter,
	parent: Instance,
	base: CFrame,
	radius: number,
	height: number,
	style: Props
): CFrame
	local tiers = {
		{ Radius = radius, Height = height * 0.38, Lift = 0 },
		{ Radius = radius * 0.46, Height = height * 0.62, Lift = height * 0.3 },
	}
	local top = base
	local shade = if typeof(style.PaletteShade) == "number" then style.PaletteShade else 0
	for t, tier in tiers do
		local tierBase = base
			* CFrame.new(0, tier.Lift, 0)
			* (if t == 2 then CFrame.Angles(math.rad(5), 0, math.rad(-6)) else CFrame.identity)
		local width = 2 * tier.Radius * math.tan(math.pi / 8) * 1.04
		for k = 0, 7 do
			local a = k * math.pi / 4
			local out = tierBase:VectorToWorldSpace(Vector3.new(math.sin(a), 0, math.cos(a)))
			local centre = tierBase.Position
				+ out * (tier.Radius / 2)
				+ tierBase.UpVector * (tier.Height / 2)
			local props = table.clone(style)
			props.Name = "Spire"
			props.Size = Vector3.new(width, tier.Height, tier.Radius)
			props.CFrame = CFrame.lookAt(centre, centre + out, tierBase.UpVector)
			props.Material = style.Material or Enum.Material.Slate
			if style.PaletteRole then
				props.PaletteShade = shade + (if k % 2 == 0 then 0 else 0.06)
			end
			paint.wedge(props, parent)
		end
		top = tierBase * CFrame.new(0, tier.Height, 0)
	end
	return top
end

-- Pumpkins --------------------------------------------------------------------------------------

export type PumpkinOptions = {
	Ribs: number?, -- 3 or 4 (default: 4 for big ones)
	Role: string?, -- palette colour (default "Orange"; "Bone" makes a white pumpkin)
	Shade: number?,
	Leaf: boolean?, -- a leaf by the stem (default: when it is 1.5 studs or bigger)
	Solid: boolean?, -- players bump into it (default: when it is 2.5 studs or bigger)
}

--[[
	A ribbed pumpkin sitting on cf; `size` is its height. Model "Pumpkin" (PrimaryPart: its
	core, named "Pumpkin"). A small one is walk-through, and so is a custom model in its place.
]]
function Props.Pumpkin(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	options: PumpkinOptions?
): Model
	local o: PumpkinOptions = options or {}
	local solid = if o.Solid ~= nil then o.Solid else size >= 2.5
	return Kit.prop("Pumpkin", cf, parent, size * 1.25, function()
		local m = Kit.model("Pumpkin", parent)
		local body = Vector3.new(size * 1.28, size, size * 1.28)
		local core = Kit.pumpkinBody(
			cf * CFrame.new(0, size * 0.48, 0),
			body,
			o.Ribs or (if size >= 2 then 4 else 3),
			{
				PaletteRole = o.Role or "Orange",
				PaletteShade = o.Shade or 0,
				CanCollide = solid,
				CanQuery = false,
				CanTouch = false,
			},
			m,
			paint.palette
		)
		-- A curly stem: two short bent pieces.
		local top = cf * CFrame.new(0, size * 0.92, 0)
		local bend = top * CFrame.Angles(math.rad(18), 0, math.rad(12))
		rod(
			paint,
			"Stem",
			top.Position,
			(bend * CFrame.new(0, size * 0.22, 0)).Position,
			size * 0.13,
			{
				PaletteRole = "Green",
				PaletteShade = 0.3,
			},
			m
		)
		local tip = bend * CFrame.new(0, size * 0.22, 0)
		rod(
			paint,
			"Stem",
			tip.Position,
			(tip * CFrame.Angles(0, 0, math.rad(-70)) * CFrame.new(0, size * 0.12, 0)).Position,
			size * 0.09,
			{ PaletteRole = "Green", PaletteShade = 0.3 },
			m
		)
		if if o.Leaf ~= nil then o.Leaf else size >= 1.5 then
			paint.decor({
				Name = "Leaf",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size * 0.5, size * 0.06, size * 0.3),
				CFrame = top
					* CFrame.new(size * 0.22, 0.02, size * 0.05)
					* CFrame.Angles(0, math.rad(30), math.rad(-14)),
				PaletteRole = "Green",
				PaletteShade = 0.1,
			}, m)
		end
		m.PrimaryPart = core
		return m
	end, { Visual = not solid })
end

export type JackOptions = {
	Light: boolean?, -- a flickering light inside (default false: the face glows anyway)
	Detail: string?, -- "Full" (default) or "Simple"
	Ribs: number?,
}

-- A carved, glowing pumpkin sitting on cf, facing cf.LookVector; `size` is its height.
function Props.JackOLantern(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	options: JackOptions?
): Model
	local o: JackOptions = options or {}
	local palette = paint.palette
	return Kit.jackOLantern(cf, size, {
		Orange = palette.Orange,
		Green = palette.Green,
		Glow = palette.Glow,
	}, parent, { Light = o.Light == true, Detail = o.Detail, Ribs = o.Ribs })
end

-- Trees -----------------------------------------------------------------------------------------

export type TreeOptions = {
	Bare: boolean?, -- no leaves (prop "DeadTree"); otherwise puffy dark leaves (prop "SpookyTree")
	Simple: boolean?, -- fewer parts, for far-away trees
	Lanterns: number?, -- little lanterns hanging from the branches (bare trees)
	LanternLight: boolean?, -- the first lantern lights up
}

--[[
	A twisted spooky tree standing on cf, `height` studs tall. `seed` picks its shape, so the
	same seed always grows the same tree.
]]
function Props.Tree(
	paint: Painter,
	cf: CFrame,
	height: number,
	seed: number,
	parent: Instance,
	options: TreeOptions?
): Model
	local o: TreeOptions = options or {}
	local name = if o.Bare then "DeadTree" else "SpookyTree"
	return Kit.prop(name, cf, parent, height, function()
		local rng = Random.new(seed)
		local m = Kit.model(name, parent)
		local bark: Props =
			{ PaletteRole = "Wood", PaletteShade = 0.45, Material = Enum.Material.Wood }
		local thick = math.max(height * 0.1, 1.2)
		-- The trunk: bent pieces, thinner as it goes up, a knot at each bend.
		local pieces = if o.Simple then 2 else 3
		local point = cf.Position
		local lean = cf
			* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8)))
		local direction = lean.UpVector
		local joints: { Vector3 } = {}
		local trunkHeight = height * (if o.Bare then 0.62 else 0.55)
		local trunk: Part? = nil
		for i = 1, pieces do
			local d = thick * (1 - (i - 1) * 0.24)
			local length = trunkHeight / pieces
			local nextPoint = point + direction * length
			local piece = rod(paint, "Trunk", point, nextPoint, d, bark, m, i == 1)
			if i == 1 then
				trunk = piece
			end
			if i < pieces and not o.Simple then
				paint.decor({
					Name = "Knot",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * d * 1.05,
					CFrame = CFrame.new(nextPoint),
					PaletteRole = "Wood",
					PaletteShade = 0.45,
					Material = Enum.Material.Wood,
				}, m)
			end
			table.insert(joints, nextPoint)
			point = nextPoint
			-- Bend the next piece: a twist the other way each time.
			local side = if i % 2 == 0 then 1 else -1
			direction = (CFrame.fromAxisAngle(
				Vector3.zAxis,
				math.rad(side * rng:NextNumber(10, 22))
			) * CFrame.fromAxisAngle(Vector3.xAxis, math.rad(rng:NextNumber(-12, 12)))):VectorToWorldSpace(
				direction
			)
		end
		-- Roots flaring out at the bottom.
		if not o.Simple then
			for r = 1, 3 do
				local a = r / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				rod(
					paint,
					"Root",
					cf.Position + Vector3.new(0, thick * 0.6, 0),
					cf.Position + out * thick * 1.6 - Vector3.new(0, thick * 0.15, 0),
					thick * 0.45,
					bark,
					m
				)
			end
		end
		-- Branches from the top joints, each two crooked pieces.
		local branchCount = if o.Bare
			then (if o.Simple then 3 else 5)
			else (if o.Simple then 2 else 3)
		local ends: { Vector3 } = {}
		for b = 1, branchCount do
			local from = joints[math.max(#joints - (b % 2), 1)]
			local a = b / branchCount * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local up = rng:NextNumber(0.5, 1.1)
			local length = height * rng:NextNumber(0.18, 0.28)
			local mid = from + (out + Vector3.new(0, up, 0)).Unit * length
			local d = thick * 0.38
			rod(paint, "Branch", from, mid, d, bark, m)
			local tipDir = (out * 0.8 + Vector3.new(0, rng:NextNumber(0.6, 1.2), 0) + Vector3.new(
				rng:NextNumber(-0.4, 0.4),
				0,
				rng:NextNumber(-0.4, 0.4)
			)).Unit
			local tip = mid + tipDir * length * 0.7
			if not o.Simple or o.Bare then
				rod(paint, "Branch", mid, tip, d * 0.6, bark, m)
			end
			table.insert(ends, if o.Bare then tip else mid)
		end
		if not o.Bare then
			-- Puffy leaves: dark ovals around the crown.
			local crown = joints[#joints] + Vector3.new(0, height * 0.12, 0)
			local puffs = if o.Simple then 3 else 5
			for p = 1, puffs do
				local spot = if p == 1
					then crown + Vector3.new(0, height * 0.08, 0)
					else ends[(p - 2) % #ends + 1]
				local s = height * rng:NextNumber(0.32, 0.44) * (if p == 1 then 1.15 else 1)
				paint.decor({
					Name = "Leaves",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(s * 1.2, s * 0.85, s * 1.1),
					CFrame = CFrame.new(spot + Vector3.new(0, s * 0.15, 0))
						* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					PaletteRole = "Foliage",
					PaletteShade = rng:NextNumber(-0.12, 0.15),
					Material = Enum.Material.SmoothPlastic,
				}, m)
			end
		else
			-- Little lanterns hanging from the branch tips.
			for l = 1, math.min(o.Lanterns or 0, #ends) do
				local tip = ends[l]
				local hang = tip - Vector3.new(0, 1.4, 0)
				paint.decor({
					Name = "LanternRope",
					Size = Vector3.new(0.08, 1.4, 0.08),
					CFrame = CFrame.new((tip + hang) / 2),
					PaletteRole = "Iron",
				}, m)
				Props.Lantern(paint, CFrame.new(hang - Vector3.new(0, 1.3, 0)), 1.3, m, {
					Light = o.LanternLight == true and l == 1,
				})
			end
		end
		m.PrimaryPart = trunk
		return m
	end)
end

-- Lamps, lanterns, candles ------------------------------------------------------------------------

export type LanternOptions = { Light: boolean?, Range: number? }

-- A small glass lantern standing on cf (or hanging: put cf where its bottom should be).
function Props.Lantern(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	options: LanternOptions?
): Model
	local o: LanternOptions = options or {}
	local light: Kit.PropLight? = if o.Light
		then { Color = paint.color("Glow"), Range = o.Range or 14, Brightness = 1.4, Height = 0.45 }
		else nil
	return Kit.prop("Lantern", cf, parent, size, function()
		local m = Kit.model("Lantern", parent)
		local k = size / 1.3
		paint.roundedDecor({
			Name = "Base",
			Size = Vector3.new(0.9 * k, 0.2 * k, 0.9 * k),
			CFrame = cf * CFrame.new(0, 0.1 * k, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Glass",
			Size = Vector3.new(0.7 * k, 0.8 * k, 0.7 * k),
			CFrame = cf * CFrame.new(0, 0.6 * k, 0),
			PaletteRole = "Glow",
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		}, m)
		local flame = paint.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3 * k, 0.5 * k, 0.3 * k),
			CFrame = cf * CFrame.new(0, 0.6 * k, 0),
			PaletteRole = "Glow",
			Material = Enum.Material.Neon,
		}, m)
		paint.roundedDecor({
			Name = "Cap",
			Size = Vector3.new(1 * k, 0.35 * k, 1 * k),
			CFrame = cf * CFrame.new(0, 1.12 * k, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Handle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.25 * k,
			CFrame = cf * CFrame.new(0, 1.38 * k, 0),
			PaletteRole = "Iron",
		}, m)
		if o.Light then
			glowLight(paint, flame, o.Range or 14, 1.4)
		end
		m.PrimaryPart = flame
		return m
	end, { Light = light, Visual = true })
end

export type LampOptions = { Light: boolean?, Range: number? }

-- An iron lamppost standing on cf, `height` studs to the top of its lantern.
function Props.Lamppost(
	paint: Painter,
	cf: CFrame,
	height: number,
	parent: Instance,
	options: LampOptions?
): Model
	local o: LampOptions = options or {}
	local light: Kit.PropLight? = if o.Light ~= false
		then { Color = paint.color("Glow"), Range = o.Range or 22, Brightness = 1.6, Height = 0.85 }
		else nil
	return Kit.prop("Lamppost", cf, parent, height, function()
		local m = Kit.model("Lamppost", parent)
		local iron: Props = { PaletteRole = "Iron", Material = Enum.Material.Metal }
		local base = paint.rounded({
			Name = "Base",
			Size = Vector3.new(1.7, 1.3, 1.7),
			CFrame = cf * CFrame.new(0, 0.65, 0),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
		local poleTop = height - 2.6
		local pole = rod(
			paint,
			"Pole",
			(cf * CFrame.new(0, 1.2, 0)).Position,
			(cf * CFrame.new(0, poleTop, 0)).Position,
			0.42,
			iron,
			m,
			true
		)
		paint.roundedDecor({
			Name = "Collar",
			Size = Vector3.new(0.85, 0.35, 0.85),
			CFrame = cf * CFrame.new(0, height * 0.42, 0),
			PaletteRole = "Iron",
		}, m)
		paint.roundedDecor({
			Name = "LanternBase",
			Size = Vector3.new(1.3, 0.3, 1.3),
			CFrame = cf * CFrame.new(0, poleTop + 0.1, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Glass",
			Size = Vector3.new(1.15, 1.55, 1.15),
			CFrame = cf * CFrame.new(0, poleTop + 1.05, 0),
			PaletteRole = "Glow",
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		}, m)
		local flame = paint.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.5, 0.85, 0.5),
			CFrame = cf * CFrame.new(0, poleTop + 1.0, 0),
			PaletteRole = "Glow",
			Material = Enum.Material.Neon,
		}, m)
		paint.roundedDecor({
			Name = "Cap",
			Size = Vector3.new(1.8, 0.4, 1.8),
			CFrame = cf * CFrame.new(0, poleTop + 1.95, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Dome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 0.8, 1.2),
			CFrame = cf * CFrame.new(0, poleTop + 2.15, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Finial",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.45,
			CFrame = cf * CFrame.new(0, poleTop + 2.6, 0),
			PaletteRole = "Orange",
		}, m)
		if o.Light ~= false then
			glowLight(paint, flame, o.Range or 22, 1.6)
		end
		m.PrimaryPart = pole
		local _ = base
		return m
	end, { Light = light })
end

export type CandleOptions = { Light: boolean?, Drips: number? }

-- A wax candle standing on cf, `height` studs of wax, with drips and a flame.
function Props.Candle(
	paint: Painter,
	cf: CFrame,
	height: number,
	parent: Instance,
	options: CandleOptions?
): Model
	local o: CandleOptions = options or {}
	local light: Kit.PropLight? = if o.Light
		then { Color = paint.color("Glow"), Range = 9, Brightness = 0.9, Height = 0.95 }
		else nil
	return Kit.prop("Candle", cf, parent, height + 0.7, function()
		local m = Kit.model("Candle", parent)
		local d = 0.55 + height * 0.08
		local wax = paint.decor({
			Name = "Wax",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, d, d),
			CFrame = Kit.upright(cf * CFrame.new(0, height / 2, 0)),
			PaletteRole = "Bone",
		}, m)
		paint.roundedDecor({
			Name = "MeltedTop",
			Size = Vector3.new(d * 1.12, 0.18, d * 1.12),
			CFrame = cf * CFrame.new(0, height - 0.04, 0),
			PaletteRole = "Bone",
			PaletteShade = -0.05,
		}, m)
		for i = 1, o.Drips or 2 do
			local a = i * 2.4
			local long = 0.35 + (i % 2) * 0.3
			paint.decor({
				Name = "Drip",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.2, long, 0.2),
				CFrame = cf
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, height - long / 2, -d / 2 + 0.03),
				PaletteRole = "Bone",
				PaletteShade = -0.05,
			}, m)
		end
		local flame = paint.decor({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3, 0.6, 0.3),
			CFrame = cf * CFrame.new(0, height + 0.38, 0),
			PaletteRole = "Glow",
			Material = Enum.Material.Neon,
		}, m)
		if o.Light then
			glowLight(paint, flame, 9, 0.9)
		end
		m.PrimaryPart = wax
		return m
	end, { Light = light, Visual = true })
end

-- Furniture and clutter ---------------------------------------------------------------------------

-- A wooden bench with iron sides, standing on cf; people would sit facing cf.LookVector.
function Props.Bench(paint: Painter, cf: CFrame, parent: Instance): Model
	return Kit.prop("Bench", cf, parent, 3.6, function()
		local m = Kit.model("Bench", parent)
		local width = 6
		local seat: Part? = nil
		for i, z in { -0.45, 0.45 } do
			local plank = paint.part({
				Name = "Seat",
				Size = Vector3.new(width, 0.28, 0.82),
				CFrame = cf * CFrame.new(0, 1.55, z),
				PaletteRole = "Wood",
				PaletteShade = if i == 1 then -0.12 else -0.05,
				Material = Enum.Material.WoodPlanks,
			}, m)
			seat = seat or plank
		end
		for i, y in { 2.35, 3.15 } do
			paint.decor({
				Name = "Backrest",
				Size = Vector3.new(width, 0.6, 0.2),
				CFrame = cf * CFrame.new(0, y, 1.05) * CFrame.Angles(math.rad(-10), 0, 0),
				PaletteRole = "Wood",
				PaletteShade = if i == 1 then -0.08 else -0.12,
				Material = Enum.Material.WoodPlanks,
			}, m)
		end
		for _, side in { -1, 1 } do
			paint.part({
				Name = "Side",
				Size = Vector3.new(0.3, 1.45, 1.9),
				CFrame = cf * CFrame.new(side * (width / 2 - 0.4), 0.72, 0.1),
				PaletteRole = "Iron",
			}, m)
			paint.decor({
				Name = "Armrest",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 2.6, 0.32),
				CFrame = cf
					* CFrame.new(side * (width / 2 - 0.4), 2.35, 0.35)
					* CFrame.Angles(0, math.rad(90), math.rad(-80)),
				PaletteRole = "Iron",
			}, m)
		end
		m.PrimaryPart = seat
		return m
	end)
end

-- A round roll of hay lying on cf (its length runs left to right), `size` studs tall.
function Props.HayRoll(paint: Painter, cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("HayRoll", cf, parent, size, function()
		local m = Kit.model("HayRoll", parent)
		local length = size * 1.15
		local roll = paint.part({
			Name = "Hay",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, size, size),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			PaletteRole = "Straw",
			Material = Enum.Material.Fabric,
		}, m)
		for _, side in { -1, 1 } do
			paint.decor({
				Name = "Swirl",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, size * 0.82, size * 0.82),
				CFrame = cf * CFrame.new(side * length / 2, size / 2, 0),
				PaletteRole = "Straw",
				PaletteShade = 0.18,
				Material = Enum.Material.Fabric,
			}, m)
		end
		paint.decor({
			Name = "Twine",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, size + 0.06, size + 0.06),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			PaletteRole = "Wood",
			PaletteShade = 0.2,
		}, m)
		m.PrimaryPart = roll
		return m
	end)
end

-- A wooden crate (size studs on every side) standing on cf.
function Props.Crate(paint: Painter, cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("Crate", cf, parent, size, function()
		local m = Kit.model("Crate", parent)
		local box = paint.part({
			Name = "Box",
			Size = Vector3.one * size,
			CFrame = cf * CFrame.new(0, size / 2, 0),
			PaletteRole = "Wood",
			PaletteShade = -0.1,
			Material = Enum.Material.WoodPlanks,
		}, m)
		for _, y in { 0.08, 0.92 } do
			paint.decor({
				Name = "Band",
				Size = Vector3.new(size + 0.12, size * 0.14, size + 0.12),
				CFrame = cf * CFrame.new(0, size * y, 0),
				PaletteRole = "Wood",
				PaletteShade = 0.25,
				Material = Enum.Material.Wood,
			}, m)
		end
		m.PrimaryPart = box
		return m
	end)
end

-- A bulging barrel standing on cf, `height` studs tall.
function Props.Barrel(paint: Painter, cf: CFrame, height: number, parent: Instance): Model
	return Kit.prop("Barrel", cf, parent, height, function()
		local m = Kit.model("Barrel", parent)
		local d = height * 0.72
		local body = paint.part({
			Name = "Staves",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, d, d),
			CFrame = Kit.upright(cf * CFrame.new(0, height / 2, 0)),
			PaletteRole = "Wood",
			Material = Enum.Material.Wood,
		}, m)
		paint.decor({
			Name = "Bulge",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d * 1.12, height * 0.8, d * 1.12),
			CFrame = cf * CFrame.new(0, height / 2, 0),
			PaletteRole = "Wood",
			Material = Enum.Material.Wood,
		}, m)
		for _, y in { 0.2, 0.8 } do
			paint.decor({
				Name = "Hoop",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.18, d * 1.09, d * 1.09),
				CFrame = Kit.upright(cf * CFrame.new(0, height * y, 0)),
				PaletteRole = "Iron",
			}, m)
		end
		m.PrimaryPart = body
		return m
	end)
end

-- Graves, fences, signs ---------------------------------------------------------------------------

export type GraveOptions = {
	Style: string?, -- "Round" (default), "Cross" or "Pointed"
	Shade: number?, -- 0 = Palette.Stone, 0.3 = 30% darker
	Epitaph: string?, -- written on the front
	Moss: boolean?,
}

-- A tombstone standing on cf (front = cf.LookVector), `size` studs tall.
function Props.Gravestone(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	options: GraveOptions?
): Model
	local o: GraveOptions = options or {}
	local k = size / 3.6 -- drawn for a 3.6-stud stone
	return Kit.prop("Gravestone", cf, parent, size + 0.4 * k, function()
		local m = Kit.model("Gravestone", parent)
		local shade = o.Shade or 0
		local stone: Props = {
			PaletteRole = "Stone",
			PaletteShade = shade,
			Material = Enum.Material.Slate,
		}
		local function with(extra: Props): Props
			local p = table.clone(stone)
			for key, value in extra do
				p[key] = value
			end
			return p
		end
		paint.part(
			with({
				Name = "Plinth",
				Size = Vector3.new(3.9 * k, 0.45 * k, 1.5 * k),
				CFrame = cf * CFrame.new(0, 0.22 * k, 0),
				PaletteShade = shade + 0.15,
			}),
			m
		)
		local style = o.Style or "Round"
		local slab: Part
		local width = 3 * k
		local depth = 0.75 * k
		if style == "Cross" then
			slab = paint.part(
				with({
					Name = "Tombstone",
					Size = Vector3.new(0.9 * k, size - 0.45 * k, depth),
					CFrame = cf * CFrame.new(0, 0.45 * k + (size - 0.45 * k) / 2, 0),
				}),
				m
			)
			paint.part(
				with({
					Name = "CrossArm",
					Size = Vector3.new(width, 0.8 * k, depth),
					CFrame = cf * CFrame.new(0, size * 0.7, 0),
				}),
				m
			)
		else
			local slabHeight = size
				- 0.45 * k
				- (if style == "Round" then width / 2 else width * 0.35)
			slab = paint.part(
				with({
					Name = "Tombstone",
					Size = Vector3.new(width, slabHeight, depth),
					CFrame = cf * CFrame.new(0, 0.45 * k + slabHeight / 2, 0),
				}),
				m
			)
			local topY = 0.45 * k + slabHeight
			if style == "Round" then
				paint.decor(
					with({
						Name = "TombstoneTop",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(depth, width, width),
						CFrame = cf * CFrame.new(0, topY, 0) * CFrame.Angles(0, math.rad(90), 0),
					}),
					m
				)
			else
				for _, side in { -1, 1 } do
					paint.wedge(
						with({
							Name = "TombstoneTop",
							Size = Vector3.new(depth, width * 0.35, width / 2),
							CFrame = cf
								* CFrame.new(side * width / 4, topY + width * 0.175, 0)
								* CFrame.Angles(0, math.rad(90 * side), 0),
						}),
						m
					)
				end
			end
			-- A darker panel on the front where the words go.
			paint.decor(
				with({
					Name = "Panel",
					Size = Vector3.new(width * 0.72, slabHeight * 0.62, 0.06),
					CFrame = cf * CFrame.new(0, 0.45 * k + slabHeight * 0.55, -depth / 2 - 0.02),
					PaletteShade = shade + 0.22,
				}),
				m
			)
		end
		if o.Moss ~= false then
			paint.decor({
				Name = "Moss",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.3 * k, 0.5 * k, 0.9 * k),
				CFrame = cf * CFrame.new(-1.1 * k, 0.5 * k, -0.3 * k),
				PaletteRole = "Green",
				PaletteShade = 0.45,
				Material = Enum.Material.Grass,
			}, m)
		end
		if o.Epitaph then
			local gui = Kit.surfaceText(slab, o.Epitaph, paint.color("Bone"))
			gui.PixelsPerStud = 60
		end
		m.PrimaryPart = slab
		return m
	end)
end

-- An iron fence post with a little pumpkin on top, standing on cf.
function Props.FencePost(paint: Painter, cf: CFrame, height: number, parent: Instance): Model
	return Kit.prop("FencePost", cf, parent, height + 0.9, function()
		local m = Kit.model("FencePost", parent)
		local post = paint.part({
			Name = "Post",
			Size = Vector3.new(0.55, height, 0.55),
			CFrame = cf * CFrame.new(0, height / 2, 0),
			PaletteRole = "Iron",
		}, m)
		paint.decor({
			Name = "Finial",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.05, 0.85, 1.05),
			CFrame = cf * CFrame.new(0, height + 0.38, 0),
			PaletteRole = "Orange",
		}, m)
		m.PrimaryPart = post
		return m
	end)
end

export type FenceOptions = {
	Pickets: number?, -- upright bars between the posts
	Solid: boolean?, -- players can't walk through (default true)
}

-- The iron rails (and bars) between two fence posts standing at a and b (on the ground).
function Props.FenceSpan(
	paint: Painter,
	a: Vector3,
	b: Vector3,
	height: number,
	parent: Instance,
	options: FenceOptions?
)
	local o: FenceOptions = options or {}
	local make: (Props, Instance) -> Part = if o.Solid == false then paint.decor else paint.part
	local length = (b - a).Magnitude
	for _, y in { height * 0.25, height * 0.85 } do
		make({
			Name = "FenceRail",
			Size = Vector3.new(0.22, 0.22, length),
			CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
			PaletteRole = "Iron",
			CastShadow = false,
		}, parent)
	end
	local pickets = o.Pickets or 0
	for i = 1, pickets do
		local p = a:Lerp(b, i / (pickets + 1))
		paint.decor({
			Name = "FenceBar",
			Size = Vector3.new(0.16, height * 0.95, 0.16),
			CFrame = CFrame.new(p + Vector3.new(0, height * 0.475, 0)),
			PaletteRole = "Iron",
		}, parent)
	end
end

export type SignArm = {
	Text: string,
	Direction: Vector3, -- which way the arrow points (flat)
	Role: string?, -- the board's palette colour (default "Wood")
}

--[[
	A wooden signpost on cf with one arrow board per arm (top to bottom), each pointing along
	its Direction with its Text on both sides.
]]
function Props.Signpost(paint: Painter, cf: CFrame, arms: { SignArm }, parent: Instance): Model
	local height = 6 + #arms * 1.25
	return Kit.prop("Signpost", cf, parent, height, function()
		local m = Kit.model("Signpost", parent)
		local post = paint.part({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 0.55, 0.55),
			CFrame = Kit.upright(cf * CFrame.new(0, height / 2, 0)),
			PaletteRole = "Wood",
			PaletteShade = 0.2,
			Material = Enum.Material.Wood,
		}, m)
		Props.Pumpkin(
			paint,
			cf * CFrame.new(0, height - 0.1, 0),
			0.9,
			m,
			{ Ribs = 3, Leaf = false, Solid = false }
		)
		for i, arm in arms do
			local flat = Vector3.new(arm.Direction.X, 0, arm.Direction.Z)
			if flat.Magnitude < 1e-3 then
				continue
			end
			local dir = flat.Unit
			local y = height - 1.1 - (i - 1) * 1.25
			local length = math.clamp(#arm.Text * 0.42 + 1.4, 3.6, 7.5)
			local centre = cf.Position + Vector3.new(0, y, 0) + dir * (length / 2 + 0.25)
			local frame = CFrame.fromMatrix(centre, dir, Vector3.yAxis)
			local role = arm.Role or "Wood"
			local board = paint.decor({
				Name = "Board",
				Size = Vector3.new(length, 0.95, 0.22),
				CFrame = frame,
				PaletteRole = role,
				PaletteShade = -0.1,
				Material = Enum.Material.WoodPlanks,
			}, m)
			-- The arrow point: two wedges making a triangle past the board's end.
			for _, side in { -1, 1 } do
				paint.decor({
					Name = "Arrow",
					Size = Vector3.new(0.22, 0.48, 0.6),
					CFrame = frame
						* CFrame.new(length / 2 + 0.3, side * 0.24, 0)
						* CFrame.Angles(0, math.rad(90), 0)
						* (if side > 0 then CFrame.Angles(0, 0, math.pi) else CFrame.identity),
					PaletteRole = role,
					PaletteShade = -0.1,
					Material = Enum.Material.WoodPlanks,
				}, m)
			end
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Words"
				gui.Face = face
				gui.LightInfluence = 0.3
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 50
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(0.94, 0.86)
				label.Position = UDim2.fromScale(0.03, 0.07)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = paint.color("Bone")
				label.TextStrokeTransparency = 0.5
				label.Text = arm.Text
				label.Parent = gui
				gui.Parent = board
			end
		end
		m.PrimaryPart = post
		return m
	end)
end

-- Little critters and glow ---------------------------------------------------------------------

-- A little bat centred on cf (wings out to the sides), facing cf.LookVector. It bobs: `phase`
-- is where in its bob it starts, or a Random to pick one (Kit.float).
function Props.Bat(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	phase: Random | number
): Model
	local m = Kit.prop("Bat", cf, parent, size, function()
		local bat = Kit.model("Bat", parent)
		local body = paint.decor({
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 0.45, size * 0.5, size * 0.42),
			CFrame = cf,
			PaletteRole = "Dark",
		}, bat)
		for _, side in { -1, 1 } do
			paint.wedge({
				Name = "Wing",
				Size = Vector3.new(size * 0.06, size * 0.45, size * 0.75),
				CFrame = cf
					* CFrame.new(side * size * 0.48, size * 0.08, 0)
					* CFrame.Angles(0, math.rad(-90 * side), math.rad(side * -15)),
				PaletteRole = "Dark",
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, bat)
			paint.decor({
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size * 0.09,
				CFrame = cf * CFrame.new(side * size * 0.09, size * 0.08, -size * 0.19),
				PaletteRole = "Glow",
				Material = Enum.Material.Neon,
			}, bat)
		end
		bat.PrimaryPart = body
		return bat
	end, { Anchor = "Center", Visual = true })
	Kit.float(m, size * 0.5, phase)
	return m
end

-- A cluster of 3 glowing toadstools around cf (size = the tallest one's height).
function Props.Mushrooms(
	paint: Painter,
	cf: CFrame,
	size: number,
	parent: Instance,
	rng: Random
): Model
	local spots = {}
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local r = if i == 1 then 0 else size * 0.55
		spots[i] = {
			Offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
			Scale = if i == 1 then 1 else rng:NextNumber(0.5, 0.75),
		}
	end
	return Kit.prop("Mushroom", cf, parent, size, function()
		local m = Kit.model("Mushroom", parent)
		local first: Part? = nil
		for _, spot in spots do
			local s = size * spot.Scale
			local base = cf * CFrame.new(spot.Offset)
			local stem = paint.roundedDecor({
				Name = "Stem",
				Size = Vector3.new(s * 0.32, s * 0.75, s * 0.32),
				CFrame = base * CFrame.new(0, s * 0.37, 0),
				PaletteRole = "Bone",
			}, m)
			first = first or stem
			paint.decor({
				Name = "Cap",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s * 0.95, s * 0.5, s * 0.95),
				CFrame = base * CFrame.new(0, s * 0.78, 0),
				PaletteRole = "Teal",
				Material = Enum.Material.Neon,
				Transparency = 0.1,
			}, m)
		end
		m.PrimaryPart = first
		return m
	end, { Visual = true })
end

-- Spider webs and bunting -------------------------------------------------------------------------

--[[
	A spider web centred on cf, flat, facing cf.LookVector, `size` studs across. Made of thin
	Beams on one invisible part, so it costs almost nothing.
]]
function Props.Cobweb(paint: Painter, cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("Cobweb", cf, parent, size, function()
		local m = Kit.model("Cobweb", parent)
		local holder = Kit.holder("Web", cf, Vector3.new(0.2, 0.2, 0.2), m)
		local color = paint.color("Bone")
		local spokes = 6
		local radius = size / 2
		local rim: { { Vector3 } } = {}
		for i = 1, spokes do
			local a = (i / spokes) * math.pi * 2 + 0.3
			local dir = cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a)
			beam(holder, cf.Position, cf.Position + dir * radius, 0, 0.05, color, 0.35)
			rim[i] = { cf.Position + dir * radius * 0.45, cf.Position + dir * radius * 0.85 }
		end
		for ring = 1, 2 do
			for i = 1, spokes do
				local a = rim[i][ring]
				local b = rim[i % spokes + 1][ring]
				local towardCentre = (cf.Position - (a + b) / 2).Unit
				beam(holder, a, b, radius * 0.08 * ring, 0.04, color, 0.4, towardCentre)
			end
		end
		holder:SetAttribute("PaletteRole", nil)
		m.PrimaryPart = holder
		return m
	end, { Anchor = "Center", Visual = true })
end

export type BuntingOptions = {
	Flags: number, -- flags along the rope
	Sag: number, -- studs the middle of the rope hangs down
	Colors: { string }, -- palette colours, in turn
	FlagSize: number?,
}

--[[
	A sagging rope from a to b (a Beam on `holder`, an invisible part) with triangle flags
	hanging from it. The flags are parts named "Flag".
]]
function Props.Bunting(
	paint: Painter,
	holder: BasePart,
	a: Vector3,
	b: Vector3,
	options: BuntingOptions,
	parent: Instance
)
	beam(holder, a, b, options.Sag, 0.12, paint.color("Bone"), 0)
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if along.Magnitude < 1e-3 then
		return
	end
	local normal = along.Unit:Cross(Vector3.yAxis)
	local size = options.FlagSize or 1.5
	for f = 1, options.Flags do
		local t = f / (options.Flags + 1)
		local p = sagPoint(a, b, options.Sag, t)
		local frame = CFrame.fromMatrix(p, normal, Vector3.yAxis)
		local role = options.Colors[(f - 1) % #options.Colors + 1]
		for _, side in { -1, 1 } do
			paint.wedge({
				Name = "Flag",
				Size = Vector3.new(0.08, size, size * 0.42),
				CFrame = frame
					* CFrame.new(0, -size / 2, side * size * 0.21)
					* CFrame.Angles(0, 0, math.pi)
					* (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity),
				PaletteRole = role,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, parent)
		end
	end
end

-- Tags a model as bobbing (client HubAmbience), like Kit.float.
function Props.floatTag(m: Model, bob: number, phase: number)
	m:SetAttribute("BobHeight", bob)
	m:SetAttribute("Phase", phase)
	CollectionService:AddTag(m, "HubFloat")
end

return Props
