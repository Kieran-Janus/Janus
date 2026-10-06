--!strict
--[[
	Lobby section: the Spider Grove, home of the Web Scour minigame.
	Where: Config.Lobby.Zones.WebScour; settings and look: Config.Minigames.WebScour (Grove).

	Workspace.Hub.WebScour
	  GroveFloor     mossy ground, fallen leaves and glowing mushrooms (only for looks)
	  Trees          twisted trees (prop "SpiderGroveTree": put your own model with that name in
	                 ReplicatedStorage.Custom.Props to swap them all)
	  Webs           Web1, Web2... giant glowing webs strung between the trees, and the Bough
	                 the big web hangs from
	  GroveSpider    the big friendly spider on top (prop "GroveSpider")
	  StartLantern   the lantern on its post: the part "Lantern" (tag WebScourStart) has the
	                 "Scour the Web!" button; the sign says what the game is
	  HidingSpots    Spot01, Spot02... invisible parts (tag WebScourSpot) where critters appear.
	                 Move, copy or delete them in Studio: the game uses whatever is tagged.
	  Mist           a little ground fog
	Nothing here collides except the tree trunks and the lantern post, so the whole grove is
	easy to walk through.

	WebScour.Build(hub, zone) -> Model
	  zone = { Name, CFrame, Size }: CFrame is the zone's centre on the plaza, its front (-Z)
	  facing the hub centre. Off (Config.Features.WebScour = false): only the empty model.
	WebScour.Repair(hub, zone) -> Model   for a hub saved without a lantern (WebScourService):
	                                      a grove that still has hiding spots keeps everything
	                                      and only gets a new lantern; an empty one is built
	                                      again from scratch
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local WebScourRules = require(ReplicatedStorage.Shared.WebScourRules)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local WebScour = {}

local cfg = Config.Minigames.WebScour
local grove = cfg.Grove
local colors = grove.Colors
local paint = Kit.painter(Config.Hub.Palette)
local part = paint.part
local decor = paint.decor

-- Geometry helpers ------------------------------------------------------------------------------

-- A frame at `position` whose LookVector points from `position` to `target` (any direction,
-- also straight up or down).
local function along(position: Vector3, target: Vector3): CFrame
	local dir = target - position
	if dir.Magnitude < 1e-4 then
		return CFrame.new(position)
	end
	local up = if math.abs(dir.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, target, up)
end

-- A round stick from a to b (a Cylinder part: its length runs along its X axis).
local function stick(
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	props: { [string]: any },
	parent: Instance,
	solid: boolean?
): Part
	local length = (b - a).Magnitude
	local p = table.clone(props)
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(math.max(length, 0.05), thickness, thickness)
	p.CFrame = along((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	return if solid then part(p, parent) else decor(p, parent)
end

-- A thin glowing web strand from a to b.
local function strand(name: string, a: Vector3, b: Vector3, thickness: number, parent: Instance)
	local length = (b - a).Magnitude
	decor({
		Name = name,
		Size = Vector3.new(thickness, thickness, math.max(length, 0.05)),
		CFrame = along((a + b) / 2, b),
		Color = colors.Web,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CastShadow = false,
	}, parent)
end

-- An egg/oval shape: a Ball part is always a perfect sphere, so ovals are a block with a
-- sphere mesh (the mesh fills the part's size).
local function oval(props: { [string]: any }, parent: Instance, solid: boolean?): Part
	local p = if solid then part(props, parent) else decor(props, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function ball(
	name: string,
	position: Vector3,
	size: number,
	props: { [string]: any },
	parent: Instance
): Part
	local p = table.clone(props)
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(position)
	return decor(p, parent)
end

-- The Spider Grove's own layout frame: offsets are (right, up, back) seen from the plaza.
type Frame = {
	Zone: CFrame,
	Point: (offset: Vector3) -> Vector3,
	FacePlaza: (position: Vector3) -> CFrame,
}

local function frameOf(zone: Zone): Frame
	local zoneCf = zone.CFrame
	return {
		Zone = zoneCf,
		Point = function(offset: Vector3): Vector3
			-- The zone's -Z faces the plaza, so "right" seen from the plaza is the zone's -X.
			return (zoneCf * CFrame.new(-offset.X, offset.Y, offset.Z)).Position
		end,
		FacePlaza = function(position: Vector3): CFrame
			return CFrame.new(position) * zoneCf.Rotation
		end,
	}
end

-- Trees ---------------------------------------------------------------------------------------------

type Tree = {
	Base: Vector3,
	Height: number,
	Points: { Vector3 }, -- the trunk's middle line, bottom to top
	Model: Model,
}

-- Where the middle of a trunk is at `height` studs above its base.
local function trunkAt(tree: Tree, height: number): Vector3
	local points = tree.Points
	local y = tree.Base.Y + math.clamp(height, 0, tree.Height)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if y <= b.Y or i == #points then
			local t = if b.Y - a.Y > 1e-3 then math.clamp((y - a.Y) / (b.Y - a.Y), 0, 1) else 0
			return a:Lerp(b, t)
		end
	end
	return points[#points]
end

local function trunkWidth(tree: Tree, height: number): number
	return 2.5 - 1.3 * math.clamp(height / tree.Height, 0, 1)
end

-- A twisted tree: a crooked trunk with knots, roots and curly branches.
local function buildTree(base: Vector3, height: number, rng: Random, parent: Instance): Tree
	local segments = 5
	local lean = rng:NextNumber(0, math.pi * 2)
	local points = { base }
	for i = 1, segments do
		local t = i / segments
		local wobble = math.sin(i * 1.7 + lean) * 0.8
		local drift = Vector3.new(math.cos(lean), 0, math.sin(lean)) * (t * 1.2)
		local side = Vector3.new(-math.sin(lean), 0, math.cos(lean)) * wobble
		points[i + 1] = base + Vector3.new(0, height * t, 0) + drift + side
	end
	local tree: Tree = { Base = base, Height = height, Points = points, Model = nil :: any }
	local yaw = rng:NextNumber(0, math.pi * 2)
	-- Draw every random number before building, so a custom prop never shifts the others.
	local branches = {}
	for b = 1, 3 do
		table.insert(branches, {
			Height = height * rng:NextNumber(0.55, 0.92),
			Yaw = yaw + b * math.pi * 2 / 3 + rng:NextNumber(-0.5, 0.5),
			First = rng:NextNumber(3, 4.6),
			Second = rng:NextNumber(1.8, 2.8),
		})
	end
	local bark = { Color = colors.Bark, Material = Enum.Material.Wood }
	tree.Model = Kit.prop(
		"SpiderGroveTree",
		CFrame.new(base) * CFrame.Angles(0, yaw, 0),
		parent,
		height,
		function()
			local m = Kit.model("SpiderGroveTree", parent)
			local trunk: Part? = nil
			for i = 2, #points do
				local a, b = points[i - 1], points[i]
				local width = trunkWidth(tree, (a.Y + b.Y) / 2 - base.Y)
				local piece = stick("Trunk", a, b, width, bark, m, true)
				trunk = trunk or piece
				if i < #points then
					ball("Knot", b, width * 1.08, bark, m)
				end
			end
			ball("Top", points[#points], 1.3, bark, m)
			-- Roots spreading out over the ground.
			for r = 0, 2 do
				local a = yaw + r * math.pi * 2 / 3 + 0.4
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local from = base + Vector3.new(0, 1.4, 0) + dir * 0.4
				local to = base + Vector3.new(0, 0.25, 0) + dir * 3.2
				stick("Root", from, to, 1.1, bark, m)
				ball("RootTip", to, 0.7, bark, m)
			end
			-- Branches that curl upwards at the ends.
			for _, branch in branches do
				local start = trunkAt(tree, branch.Height)
				local out = Vector3.new(math.cos(branch.Yaw), 0, math.sin(branch.Yaw))
				local elbow = start
					+ out * (branch.First * 0.8)
					+ Vector3.new(0, branch.First * 0.6, 0)
				local tip = elbow + out * (branch.Second * 0.35) + Vector3.new(0, branch.Second, 0)
				stick("Branch", start, elbow, 0.7, bark, m)
				ball("Elbow", elbow, 0.75, bark, m)
				stick("Twig", elbow, tip, 0.45, bark, m)
				ball("Curl", tip, 0.5, bark, m)
			end
			m.PrimaryPart = trunk
			return m
		end
	)
	return tree
end

-- Webs -------------------------------------------------------------------------------------------------

type WebDef = { Between: { number }, Height: number, Radius: number, Spots: { number } }

type Web = {
	Frame: CFrame, -- at the web's middle; LookVector points away from the front
	Radius: number,
	Spots: { number },
	Knots: { { Vector3 } }, -- Knots[ring][spoke]: where a ring thread crosses a spoke
	Spokes: number,
	Turn: number, -- how far spoke 1 is turned from 12 o'clock (radians, clockwise)
	Rings: { number },
}

-- A giant web between two trees, facing `viewer` (a point in front of it).
local function buildWeb(
	name: string,
	def: WebDef,
	a: Tree,
	b: Tree,
	viewer: Vector3,
	rng: Random,
	parent: Instance
): Web
	local pa, pb = trunkAt(a, def.Height), trunkAt(b, def.Height)
	local centre = (pa + pb) / 2
	local flat = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
	local across = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
	local normal = across:Cross(Vector3.yAxis)
	local toViewer = Vector3.new(viewer.X - centre.X, 0, viewer.Z - centre.Z)
	if normal:Dot(toViewer) < 0 then
		normal = -normal
	end
	-- LookVector away from the viewer: RightVector is then "right" as the viewer sees it.
	local frame = CFrame.lookAt(centre, centre - normal)
	local halfGap = flat.Magnitude / 2
		- math.max(trunkWidth(a, def.Height), trunkWidth(b, def.Height)) / 2
	local radius = math.max(math.min(def.Radius, halfGap - 0.6), 1.5)

	local m = Kit.model(name, parent)
	local spokes = if radius > 6 then 9 else 7
	local turn = rng:NextNumber(0, math.pi * 2 / spokes)
	local rings = { 0.3, 0.58, 0.86 }
	local tips: { Vector3 } = {}
	local ringPoints: { { Vector3 } } = {}
	for s = 1, spokes do
		local angle = turn + (s - 1) / spokes * math.pi * 2
		local reach = radius * rng:NextNumber(0.95, 1.06)
		local dir = frame.RightVector * math.sin(angle) + frame.UpVector * math.cos(angle)
		local tip = centre + dir * reach
		tips[s] = tip
		strand("Spoke", centre, tip, 0.13, m)
		for r, fraction in rings do
			ringPoints[r] = ringPoints[r] or {}
			ringPoints[r][s] = centre + dir * (reach * fraction)
		end
	end
	for _, points in ringPoints do
		for s = 1, spokes do
			strand("Thread", points[s], points[s % spokes + 1], 0.1, m)
		end
	end
	ball("WebMiddle", centre, 0.55, { Color = colors.Web, Material = Enum.Material.Neon }, m)
	-- Guy lines from the web's edge to the two trunks (the two tips nearest each tree), fanning
	-- out up and down the trunk.
	for _, tree in { a, b } do
		local trunk = trunkAt(tree, def.Height)
		local toward = Vector3.new(trunk.X - centre.X, 0, trunk.Z - centre.Z).Unit
		local order = {}
		for s, tip in tips do
			table.insert(order, { Index = s, Score = (tip - centre).Unit:Dot(toward) })
		end
		table.sort(order, function(x, y)
			return x.Score > y.Score
		end)
		for k = 1, 2 do
			local tip = tips[order[k].Index]
			local spread = (tip.Y - centre.Y) * 1.8
			local height = math.clamp(def.Height + spread, 0.6, tree.Height - 1)
			local anchor = trunkAt(tree, height)
			local inset = Vector3.new(tip.X - anchor.X, 0, tip.Z - anchor.Z)
			if inset.Magnitude > 0.01 then
				anchor += inset.Unit * (trunkWidth(tree, height) / 2 - 0.1)
			end
			strand("GuyLine", tip, anchor, 0.11, m)
		end
	end
	return {
		Frame = frame,
		Radius = radius,
		Spots = def.Spots,
		Knots = ringPoints,
		Spokes = spokes,
		Turn = turn,
		Rings = rings,
	}
end

-- The thick branch the big web hangs from (between the web's two trees, above the web).
local function buildBough(a: Tree, b: Tree, height: number, parent: Instance): Vector3
	local pa, pb = trunkAt(a, height), trunkAt(b, height)
	local bark = { Color = colors.Bark, Material = Enum.Material.Wood }
	local pieces = 4
	local points = {}
	for i = 0, pieces do
		local t = i / pieces
		local sag = math.sin(t * math.pi) * 0.9
		local wiggle = math.sin(t * math.pi * 3) * 0.35
		points[i] = pa:Lerp(pb, t) - Vector3.new(0, sag, 0) + Vector3.new(0, wiggle, 0)
	end
	local m = Kit.model("Bough", parent)
	for i = 1, pieces do
		stick("Bough", points[i - 1], points[i], 1.4, bark, m)
		if i < pieces then
			ball("Knot", points[i], 1.5, bark, m)
		end
	end
	return points[pieces // 2] -- the middle, where the spider sits
end

-- The friendly spider -------------------------------------------------------------------------------------

-- A big cartoon spider with huge eyes, rosy cheeks, a smile and a little witch hat, standing
-- on `cf` (feet on cf, face towards cf.LookVector).
local function buildSpider(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("GroveSpider", cf, parent, size, function()
		local m = Kit.model("GroveSpider", parent)
		local s = size / 7 -- the design below is 7 studs long
		local function at(x: number, y: number, z: number): Vector3
			return (cf * CFrame.new(x * s, y * s, z * s)).Position
		end
		local abdomen = oval({
			Name = "Body",
			Size = Vector3.new(4.6, 3.9, 5) * s,
			CFrame = cf * CFrame.new(0, 3.5 * s, 1.6 * s) * CFrame.Angles(math.rad(12), 0, 0),
			Color = colors.Spider,
		}, m)
		local headCentre = Vector3.new(0, 3.1, -1.7)
		local headRadii = Vector3.new(1.85, 1.7, 1.6)
		oval({
			Name = "Head",
			Size = headRadii * (2 * s),
			CFrame = cf * CFrame.new(headCentre * s),
			Color = Kit.shade(colors.Spider, -0.12),
		}, m)
		-- A point on the front of the head (x right, y up in design studs), `lift` studs out.
		local function onFace(x: number, y: number, lift: number): Vector3
			local dx, dy = x / headRadii.X, (y - headCentre.Y) / headRadii.Y
			local depth = headRadii.Z * math.sqrt(math.max(1 - dx * dx - dy * dy, 0))
			return at(x, y, headCentre.Z - depth - lift)
		end
		local white = { Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic }
		local black = { Color = Color3.fromRGB(20, 14, 26), Material = Enum.Material.SmoothPlastic }
		for _, side in { -1, 1 } do
			-- (seen from the front, the spider's left is our right: side only mirrors)
			ball("Eye", onFace(side * 0.72, 3.45, -0.25), 1.45 * s, white, m)
			ball("Pupil", onFace(side * 0.62, 3.38, 0.35), 0.7 * s, black, m)
			ball(
				"Sparkle",
				onFace(side * 0.5, 3.6, 0.62),
				0.25 * s,
				{ Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon },
				m
			)
			ball("LittleEye", onFace(side * 0.42, 4.35, -0.05), 0.45 * s, black, m)
			oval({
				Name = "Cheek",
				Size = Vector3.new(0.75, 0.45, 0.25) * s,
				CFrame = CFrame.lookAt(
					onFace(side * 1.2, 2.65, -0.02),
					onFace(side * 1.2, 2.65, 1)
				),
				Color = colors.Cheeks,
			}, m)
		end
		-- A smile: little dots along a curve.
		for i = -2, 2 do
			local t = i / 2
			ball("Smile", onFace(t * 0.55, 2.42 - 0.22 * math.cos(t * 1.2), 0), 0.24 * s, black, m)
		end
		-- Orange spots on the back.
		for _, spot in
			{ Vector3.new(0, 5.35, 1.2), Vector3.new(-1.05, 5, 2.4), Vector3.new(1.05, 5, 2.4) }
		do
			ball(
				"Spot",
				at(spot.X, spot.Y, spot.Z),
				0.85 * s,
				{ Color = colors.SpiderSpots, Material = Enum.Material.SmoothPlastic },
				m
			)
		end
		-- Eight legs: up to a knee, then down to the branch.
		local legs = { Color = colors.SpiderLegs, Material = Enum.Material.SmoothPlastic }
		for _, side in { -1, 1 } do
			for i = 1, 4 do
				-- Front legs to back legs: the knees fan out and the feet spread along the branch.
				local z = -1.2 + (i - 1) * 0.8
				local root = at(side * 1.3, 3.1, z)
				local knee = at(side * (2.5 + 0.4 * i), 5.5 - 0.3 * i, z * 1.9)
				local foot = at(side * (3 + 0.95 * i), 0.25, z * 0.8)
				stick("Leg", root, knee, 0.62 * s, legs, m)
				ball("Knee", knee, 0.8 * s, legs, m)
				stick("Leg", knee, foot, 0.55 * s, legs, m)
				ball(
					"Foot",
					foot,
					0.7 * s,
					{ Color = colors.SpiderSpots, Material = Enum.Material.SmoothPlastic },
					m
				)
			end
		end
		-- A little witch hat, tipped to one side.
		local hatCf = cf
			* CFrame.new(0.35 * s, 4.65 * s, -1.6 * s)
			* CFrame.Angles(math.rad(-8), 0, math.rad(-14))
		local hat = { Material = Enum.Material.SmoothPlastic }
		local function hatPiece(
			name: string,
			y: number,
			width: number,
			height: number,
			role: string
		)
			local p = table.clone(hat)
			p.Name = name
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(height * s, width * s, width * s)
			p.CFrame = Kit.upright(hatCf * CFrame.new(0, y * s, 0))
			p.PaletteRole = role
			decor(p, m)
		end
		hatPiece("HatBrim", 0, 3, 0.22, "Purple")
		hatPiece("HatBand", 0.28, 1.8, 0.34, "Orange")
		-- The cone: thinner and thinner rings (Roblox has no cone part).
		for i, width in { 1.6, 1.28, 0.98, 0.7, 0.45 } do
			hatPiece("Hat", 0.45 + i * 0.42, width, 0.46, "Purple")
		end
		ball(
			"HatTip",
			(hatCf * CFrame.new(0, 2.85 * s, 0)).Position,
			0.45 * s,
			{ PaletteRole = "Orange", Material = Enum.Material.Neon },
			m
		)
		m.PrimaryPart = abdomen
		return m
	end, { Visual = true })
end

-- The start lantern ----------------------------------------------------------------------------------------

local function buildLantern(frame: Frame, parent: Instance): BasePart
	local m = Kit.model("StartLantern", parent)
	local base = frame.FacePlaza(frame.Point(grove.Lantern))
	local wood = { PaletteRole = "Wood", PaletteShade = 0.2, Material = Enum.Material.Wood }
	local iron = { PaletteRole = "Iron", Material = Enum.Material.Metal }
	local postTop = (base * CFrame.new(0.25, 8, 0)).Position
	stick("Post", base.Position, postTop, 0.8, wood, m, true)
	-- The arm the lantern hangs from, sticking out to the right (seen from the plaza).
	local armEnd = (base * CFrame.new(-2.4, 7.7, 0)).Position
	stick("Arm", postTop - Vector3.new(0, 0.3, 0), armEnd, 0.45, wood, m)
	local hook = armEnd - Vector3.new(0, 0.9, 0)
	stick("Chain", armEnd, hook, 0.15, iron, m)
	local lanternCf = CFrame.new(hook - Vector3.new(0, 1.35, 0)) * base.Rotation
	local lantern = part({
		Name = "Lantern",
		Size = Vector3.new(1.6, 2, 1.6),
		CFrame = lanternCf,
		Color = colors.Lantern,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, m)
	CollectionService:AddTag(lantern, Tags.WebScourStart)
	for _, y in { 1.1, -1.1 } do
		decor({
			Name = if y > 0 then "LanternCap" else "LanternBase",
			Size = Vector3.new(2.1, 0.3, 2.1),
			CFrame = lanternCf * CFrame.new(0, y, 0),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
	end
	decor({
		Name = "LanternTop",
		Size = Vector3.new(1.1, 0.4, 1.1),
		CFrame = lanternCf * CFrame.new(0, 1.4, 0),
		PaletteRole = "Iron",
		Material = Enum.Material.Metal,
	}, m)
	for _, corner in
		{
			Vector3.new(1, 0, 1),
			Vector3.new(-1, 0, 1),
			Vector3.new(1, 0, -1),
			Vector3.new(-1, 0, -1),
		}
	do
		decor({
			Name = "LanternBar",
			Size = Vector3.new(0.16, 2, 0.16),
			CFrame = lanternCf * CFrame.new(corner * 0.82),
			PaletteRole = "Iron",
		}, m)
	end
	Kit.light(lantern, colors.Lantern, 20, 1.8, true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WebScourPrompt"
	prompt.ActionText = cfg.Prompt.ActionText
	prompt.ObjectText = cfg.Prompt.ObjectText
	prompt.HoldDuration = cfg.Prompt.HoldDuration
	prompt.MaxActivationDistance = cfg.Prompt.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = lantern

	-- The sign on the post, facing the plaza.
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(4.8, 1.9, 0.3),
		CFrame = base * CFrame.new(0, 4.6, -0.6) * CFrame.Angles(0, 0, math.rad(-3)),
		PaletteRole = "Wood",
		PaletteShade = 0.35,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	}, m)
	Kit.surfaceText(sign, cfg.Text.Title, colors.Lantern)
	local small = part({
		Name = "SignSmall",
		Size = Vector3.new(3.8, 1, 0.25),
		CFrame = base * CFrame.new(0, 3.1, -0.55) * CFrame.Angles(0, 0, math.rad(2)),
		PaletteRole = "Wood",
		PaletteShade = 0.45,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	}, m)
	Kit.surfaceText(small, cfg.Text.Sign:format(cfg.Critters), paint.color("Bone"))
	return lantern
end

-- The ground ----------------------------------------------------------------------------------------

local function buildFloor(frame: Frame, zone: Zone, trees: { Tree }, rng: Random, parent: Instance)
	local m = Kit.group("GroveFloor", parent)
	local width, depth = zone.Size.X, zone.Size.Z
	local patches: { { Offset: Vector3, Size: number } } = {
		{ Offset = Vector3.new(0, 0, 2), Size = math.min(width, depth) * 0.95 },
		{ Offset = Vector3.new(-width * 0.28, 0, -3), Size = depth * 0.6 },
		{ Offset = Vector3.new(width * 0.28, 0, -3), Size = depth * 0.6 },
	}
	for i, patch in patches do
		decor({
			Name = "Moss",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1 + i * 0.01, patch.Size, patch.Size),
			CFrame = Kit.upright(CFrame.new(frame.Point(patch.Offset) + Vector3.new(0, 0.05, 0))),
			Color = colors.Floor,
			Material = Enum.Material.Grass,
		}, m)
	end
	local leafColors = { "Orange", "Wood", "Orange", "Purple" }
	for i = 1, 16 do
		local spot = Vector3.new(
			rng:NextNumber(-width / 2 + 2, width / 2 - 2),
			0.14,
			rng:NextNumber(-depth / 2 + 3, depth / 2 - 1)
		)
		decor({
			Name = "Leaf",
			Size = Vector3.new(0.9, 0.06, 0.55),
			CFrame = CFrame.new(frame.Point(spot))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			PaletteRole = leafColors[(i - 1) % #leafColors + 1],
			PaletteShade = 0.15,
			Material = Enum.Material.Fabric,
		}, m)
	end
	-- Glowing mushrooms, kept clear of the trunks and the lantern.
	local placed = 0
	local tries = 0
	while placed < grove.Mushrooms and tries < 200 do
		tries += 1
		local offset = Vector3.new(
			rng:NextNumber(-width / 2 + 1.5, width / 2 - 1.5),
			0,
			rng:NextNumber(-depth / 2 + 1.5, depth / 2 - 1.5)
		)
		local position = frame.Point(offset)
		local clear = (offset - grove.Lantern).Magnitude > 4 and math.abs(offset.X) > 3
		for _, tree in trees do
			if
				(Vector3.new(position.X - tree.Base.X, 0, position.Z - tree.Base.Z)).Magnitude < 4
			then
				clear = false
			end
		end
		if not clear then
			continue
		end
		placed += 1
		local height = rng:NextNumber(0.7, 1.4)
		local capColor = grove.Colors.MushroomCaps[(placed - 1) % #grove.Colors.MushroomCaps + 1]
		local tilt = CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
		-- A glowing toadstool (prop "Mushroom", like the lobby's mushroom clusters).
		Kit.prop("Mushroom", CFrame.new(position), m, height * 1.32, function()
			local mushroom = Kit.model("Mushroom", m)
			mushroom.PrimaryPart = decor({
				Name = "MushroomStem",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 0.4, 0.4),
				CFrame = Kit.upright(CFrame.new(position + Vector3.new(0, height / 2, 0))),
				PaletteRole = "Bone",
			}, mushroom)
			oval({
				Name = "MushroomCap",
				Size = Vector3.new(1.3, 0.7, 1.3) * (height / 1.1),
				CFrame = CFrame.new(position + Vector3.new(0, height, 0)) * tilt,
				Color = capColor,
				Material = Enum.Material.Neon,
			}, mushroom)
			return mushroom
		end, { Visual = true })
	end
end

-- Hiding spots -----------------------------------------------------------------------------------------

local function spotPart(index: number, position: Vector3, parent: Instance)
	local p = Kit.holder(("Spot%02d"):format(index), CFrame.new(position), Vector3.one, parent)
	CollectionService:AddTag(p, Tags.WebScourSpot)
end

-- Build ----------------------------------------------------------------------------------------------------

function WebScour.Build(hub: Instance, zone: Zone): Instance
	local area = Kit.group("WebScour", hub)
	if not Config.Features.WebScour then
		return area
	end
	local frame = frameOf(zone)
	local rng = Random.new(grove.Seed)

	local treeModel = Kit.group("Trees", area)
	local trees: { Tree } = {}
	for i, def in grove.Trees do
		trees[i] = buildTree(frame.Point(def.Offset), def.Height, rng, treeModel)
	end

	local webModel = Kit.group("Webs", area)
	local viewer = frame.Point(Vector3.new(0, 0, -zone.Size.Z)) -- in front of the grove
	local webs: { Web } = {}
	for i, def in grove.Webs do
		local a, b = trees[def.Between[1]], trees[def.Between[2]]
		if not (a and b) then
			warn(
				("[WebScour] Config.Minigames.WebScour.Grove.Webs[%d] names a tree that doesn't exist"):format(
					i
				)
			)
			continue
		end
		-- Side webs face the middle of the grove; the back web faces the plaza.
		local middle = frame.Point(Vector3.new(0, 0, 0))
		local front = if i == 1 then viewer else middle
		table.insert(webs, buildWeb("Web" .. i, def :: any, a, b, front, rng, webModel))
	end

	-- The bough over the first web, and the spider on it.
	local first = grove.Webs[1]
	local a, b = first and trees[first.Between[1]], first and trees[first.Between[2]]
	local mainWeb = webs[1]
	if a and b and mainWeb then
		local height =
			math.min(first.Height + mainWeb.Radius + 1.4, math.min(a.Height, b.Height) - 1)
		local seat = buildBough(a, b, height, webModel)
		local top = mainWeb.Frame.Position + mainWeb.Frame.UpVector * mainWeb.Radius
		strand("HangLine", top, seat - Vector3.new(0, 0.5, 0), 0.14, webModel)
		-- The spider faces the plaza (the web's front).
		local facing = -mainWeb.Frame.LookVector
		buildSpider(
			CFrame.lookAt(seat + Vector3.new(0, 0.55, 0), seat + Vector3.new(0, 0.55, 0) + facing),
			grove.SpiderSize,
			area
		)
	end

	buildLantern(frame, area)
	buildFloor(frame, zone, trees, rng, area)

	-- Hiding spots: on each web's knots (where a ring thread crosses a spoke) nearest its clock
	-- hours, so every critter sits on a strand, never on the ground or a tree.
	local spots = Kit.group("HidingSpots", area)
	local count = 0
	for _, web in webs do
		local used: { [string]: boolean } = {}
		for _, hour in web.Spots do
			local spoke, ring = WebScourRules.WebKnot(
				hour,
				grove.SpotDistance,
				web.Spokes,
				web.Turn,
				web.Rings,
				used
			)
			if spoke and ring then
				used[spoke .. ":" .. ring] = true
				count += 1
				spotPart(count, web.Knots[ring][spoke] - web.Frame.LookVector * 0.35, spots)
			end
		end
	end

	local mist = Kit.holder(
		"Mist",
		CFrame.new(frame.Point(Vector3.new(0, 1, 2))),
		Vector3.new(zone.Size.X, 1, zone.Size.Z),
		area
	)
	local m = Config.Hub.Particles.Mist
	Kit.particles(mist, {
		Rate = m.Rate,
		Color = ColorSequence.new(m.Color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 5),
			NumberSequenceKeypoint.new(1, 9),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.2, 0.5),
		SpreadAngle = Vector2.new(180, 10),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	return area
end

function WebScour.Repair(hub: Instance, zone: Zone): Instance
	local old = hub:FindFirstChild("WebScour")
	if old and Kit.isGroup(old) then
		for _, d in old:GetDescendants() do
			if CollectionService:HasTag(d, Tags.WebScourSpot) then
				-- A grove (maybe edited by hand) that only lost its lantern: keep it and
				-- just put a lantern back.
				buildLantern(frameOf(zone), old)
				return old
			end
		end
	end
	if old then
		old:Destroy()
	end
	local area = WebScour.Build(hub, zone)
	area:SetAttribute("HubPiece", true)
	return area
end

return WebScour
