--!strict
--[[
	"Hedge Maze", a Hide & Seek map (settings: src/shared/Config/Maps/HedgeMaze.luau).
	A garden maze from src/server/Maps/MazeGen.luau (Braid gives it loops, so seekers can't
	just follow one path):
	  hedges      tall, with rounded tops and round posts where they meet; each straight run
	              is one part (MazeGen.WallRuns), which keeps the part count low
	  middle      the fountain plaza (a MazeGen room) with benches, lamps, topiary and flowers
	  north-east  the Seeker Hut's garden (a MazeGen room); the hut's door is tagged SeekerDoor
	  dead ends   decoy pumpkins (tag HidingDecoy), more along the paths and round the fountain
	Hiders start on cells spread across the maze, away from the hut (tag HiderSpawn, folder
	Spawns). The same Seed always gives the same maze.

	HedgeMaze.Plan(def) -> Plan   the maze and the chosen cells, without building anything
	                              (tests use it to check every spawn can reach the hut)
	Repeated decorations are props (one model in ReplicatedStorage.Custom.Props swaps every
	copy): HidingPumpkin, HedgePost (the round posts where hedges meet; the long hedges can't
	be swapped, they come in every length), Flowers, Lamppost, Bench, Topiary, Fountain.
]]

local Kit = require(script.Parent.Parent.Build.Kit)
local HidingPumpkin = require(script.Parent.Parent.Build.HidingPumpkin)
local HideSeekProps = require(script.Parent.HideSeekProps)
local MapBase = require(script.Parent.MapBase)
local MazeGen = require(script.Parent.MazeGen)

local HedgeMaze = {}

local oval = HideSeekProps.oval
local jitter = HideSeekProps.jitter

-- The four sides of a cell: MazeGen's name and the step to the neighbour (x east, y south).
type Side = { Name: string, Step: Vector2 }
local SIDES: { Side } = {
	{ Name = "N", Step = Vector2.new(0, -1) },
	{ Name = "S", Step = Vector2.new(0, 1) },
	{ Name = "E", Step = Vector2.new(1, 0) },
	{ Name = "W", Step = Vector2.new(-1, 0) },
}

export type Plan = {
	Maze: MazeGen.Maze,
	Plaza: MazeGen.Room,
	HutRoom: MazeGen.Room,
	HutCell: MazeGen.Cell, -- the hut room's corner cell nearest the maze middle
	SpawnCells: { MazeGen.Cell },
	DeadEnds: { MazeGen.Cell },
}

local function inRoom(room: MazeGen.Room, x: number, y: number): boolean
	return x >= room.X and x < room.X + room.W and y >= room.Y and y < room.Y + room.H
end

function HedgeMaze.Plan(def: any): Plan
	local layout = def.Layout
	local cells: number = layout.Cells
	local plaza: MazeGen.Room = layout.Plaza
	local hutRoom: MazeGen.Room = layout.HutRoom
	local maze = MazeGen.Generate(
		cells,
		cells,
		def.Seed,
		{ Braid = layout.Braid, Rooms = { plaza, hutRoom } }
	)
	local mid = (cells + 1) / 2
	-- The hut room's cell nearest the middle (where the seekers come out).
	local hutCell = { X = hutRoom.X, Y = hutRoom.Y }
	local best = math.huge
	for x = hutRoom.X, hutRoom.X + hutRoom.W - 1 do
		for y = hutRoom.Y, hutRoom.Y + hutRoom.H - 1 do
			local d = (x - mid) ^ 2 + (y - mid) ^ 2
			if d < best then
				best = d
				hutCell = { X = x, Y = y }
			end
		end
	end

	-- Hider spawns: cells far from the hut, outside the rooms, spread out from each other.
	local rng = Random.new(def.Seed + 101)
	local candidates: { MazeGen.Cell } = {}
	for y = 1, cells do
		for x = 1, cells do
			local far = math.abs(x - hutCell.X) + math.abs(y - hutCell.Y) >= 5
			if far and not inRoom(plaza, x, y) and not inRoom(hutRoom, x, y) then
				table.insert(candidates, { X = x, Y = y })
			end
		end
	end
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local spawns: { MazeGen.Cell } = {}
	for _, spacing in { 4, 3, 2, 0 } do
		for _, c in candidates do
			if #spawns >= def.Spawns then
				break
			end
			local ok = true
			for _, s in spawns do
				if
					(s.X == c.X and s.Y == c.Y)
					or math.abs(s.X - c.X) + math.abs(s.Y - c.Y) < spacing
				then
					ok = false
					break
				end
			end
			if ok then
				table.insert(spawns, c)
			end
		end
	end

	local deadEnds: { MazeGen.Cell } = {}
	for _, c in MazeGen.DeadEnds(maze) do
		if not inRoom(plaza, c.X, c.Y) and not inRoom(hutRoom, c.X, c.Y) then
			table.insert(deadEnds, c)
		end
	end
	return {
		Maze = maze,
		Plaza = plaza,
		HutRoom = hutRoom,
		HutCell = hutCell,
		SpawnCells = spawns,
		DeadEnds = deadEnds,
	}
end

-- Hedges -------------------------------------------------------------------------------------------

-- One straight hedge from edge point a to b (map offsets): a block with a rounded top.
local function hedge(ctx: MapBase.Ctx, a: Vector2, b: Vector2, parent: Instance)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local h, t = layout.HedgeHeight, layout.HedgeThickness
	local length = (b - a).Magnitude + t
	local mid = (a + b) / 2
	local alongX = math.abs(b.X - a.X) > math.abs(b.Y - a.Y)
	local yaw = if alongX then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new()
	local color = jitter(colors.Hedge, ctx.Rng, 0.05)
	local body = h - t / 2
	Kit.part({
		Name = "Hedge",
		Size = Vector3.new(t, body, length),
		CFrame = CFrame.new(MapBase.at(ctx, mid.X, mid.Y, body / 2)) * yaw,
		Color = color,
		Material = Enum.Material.LeafyGrass,
	}, parent)
	-- Rounded top: a cylinder lying along the hedge.
	Kit.part({
		Name = "HedgeTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, t, t),
		CFrame = CFrame.new(MapBase.at(ctx, mid.X, mid.Y, body))
			* yaw
			* CFrame.Angles(0, math.pi / 2, 0),
		Color = jitter(colors.HedgeTop, ctx.Rng, 0.05),
		Material = Enum.Material.LeafyGrass,
	}, parent)
end

-- A round post where hedges meet, a little taller, with a leafy ball on top (prop "HedgePost").
local function post(ctx: MapBase.Ctx, p: Vector2, parent: Instance)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local h, t = layout.HedgeHeight, layout.HedgeThickness
	local postColor = jitter(colors.Hedge, ctx.Rng, 0.06)
	local topColor = jitter(colors.HedgeTop, ctx.Rng, 0.06)
	local foot = CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
	Kit.prop("HedgePost", foot, parent, h + 1.1 + t / 2, function()
		local m = Kit.model("HedgePost", parent)
		m.PrimaryPart = Kit.part({
			Name = "HedgePost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, t + 0.8, t + 0.8),
			CFrame = Kit.upright(foot * CFrame.new(0, h / 2, 0)),
			Color = postColor,
			Material = Enum.Material.LeafyGrass,
		}, m)
		oval({
			Name = "PostTop",
			Size = Vector3.new(t + 1.4, t + 1, t + 1.4),
			CFrame = foot * CFrame.new(0, h + 0.6, 0),
			Color = topColor,
			Material = Enum.Material.LeafyGrass,
		}, m)
		return m
	end)
end

-- Little roses dotted along both sides of a hedge.
local function roses(ctx: MapBase.Ctx, a: Vector2, b: Vector2, parent: Instance)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local length = (b - a).Magnitude
	if length < 1 then
		return
	end
	local dir = (b - a) / length
	local normal = Vector2.new(-dir.Y, dir.X)
	local color = colors.Flowers[ctx.Rng:NextInteger(1, #colors.Flowers)]
	for _, side in { -1, 1 } do
		for _ = 1, math.max(2, math.floor(length / 5)) do
			local p = a
				+ dir * ctx.Rng:NextNumber(1, length - 1)
				+ normal * side * (layout.HedgeThickness / 2 + 0.1)
			local size = ctx.Rng:NextNumber(0.6, 0.9)
			Kit.decor({
				Name = "Rose",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(
					MapBase.at(ctx, p.X, p.Y, ctx.Rng:NextNumber(2, layout.HedgeHeight - 2.5))
				),
				Color = color,
			}, parent)
		end
	end
end

-- A white garden arch with flowers over a gap between two hedge ends (a to b, the post centres).
local function arch(ctx: MapBase.Ctx, a: Vector2, b: Vector2, parent: Instance)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local t = layout.HedgeThickness
	local dir = (b - a).Unit
	local left = a + dir * (t / 2 + 0.6)
	local right = b - dir * (t / 2 + 0.6)
	local span = (right - left).Magnitude
	local radius = span / 2
	local baseY = layout.HedgeHeight - 2.5
	local mid = (left + right) / 2
	local m = Kit.model("GardenArch", parent)
	for _, p in { left, right } do
		Kit.decor({
			Name = "ArchPost",
			Size = Vector3.new(0.5, baseY, 0.5),
			CFrame = CFrame.new(MapBase.at(ctx, p.X, p.Y, baseY / 2)),
			Color = colors.Trim,
			Material = Enum.Material.Wood,
		}, m)
	end
	local segments = 7
	local flower = colors.Flowers[ctx.Rng:NextInteger(1, #colors.Flowers)]
	for i = 1, segments do
		local a0 = math.pi * (i - 1) / segments
		local a1 = math.pi * i / segments
		local function point(angle: number): Vector3
			local q = mid - dir * math.cos(angle) * radius
			return MapBase.at(ctx, q.X, q.Y, baseY + math.sin(angle) * radius)
		end
		local p0, p1 = point(a0), point(a1)
		Kit.decor({
			Name = "ArchBeam",
			Size = Vector3.new(0.5, 0.5, (p1 - p0).Magnitude + 0.3),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = colors.Trim,
			Material = Enum.Material.Wood,
		}, m)
		if i % 2 == 1 then
			Kit.decor({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				CFrame = CFrame.new(p1 + Vector3.new(0, 0.3, 0)),
				Color = flower,
			}, m)
		end
	end
end

-- Plaza --------------------------------------------------------------------------------------

local function buildFountain(ctx: MapBase.Ctx, center: Vector3, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Fountain", CFrame.new(center), parent, 9, function()
		local m = Kit.model("Fountain", parent)
		local function disc(
			name: string,
			diameter: number,
			height: number,
			y: number,
			color: Color3,
			material: Enum.Material,
			solid: boolean
		)
			local props = {
				Name = name,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, diameter, diameter),
				CFrame = Kit.upright(CFrame.new(center + Vector3.new(0, y, 0))),
				Color = color,
				Material = material,
			}
			return if solid then Kit.part(props, m) else Kit.decor(props, m)
		end
		disc("Basin", 17, 1.8, 0.9, colors.Stone, Enum.Material.Limestone, true)
		disc("Lip", 18, 0.5, 1.9, Kit.shade(colors.Stone, -0.2), Enum.Material.Limestone, false)
		local water = disc("Water", 15.4, 0.3, 2, colors.Water, Enum.Material.Glass, false)
		water.Transparency = 0.1
		disc("Pillar", 2.2, 4.5, 4, colors.Stone, Enum.Material.Limestone, true)
		disc("Bowl", 7, 0.9, 6.4, colors.Stone, Enum.Material.Limestone, true)
		disc("BowlWater", 6, 0.2, 6.9, colors.Water, Enum.Material.Glass, false)
		disc("TopPillar", 1.2, 2.4, 8, colors.Stone, Enum.Material.Limestone, false)
		disc("TopBowl", 3.4, 0.6, 9.2, colors.Stone, Enum.Material.Limestone, false)
		local spout = Kit.decor({
			Name = "Spout",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(center + Vector3.new(0, 9.9, 0)),
			Color = colors.Water,
			Material = Enum.Material.Glass,
		}, m)
		Kit.particles(spout, {
			Rate = 30,
			Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
			LightEmission = 0.3,
			Size = NumberSequence.new(0.35, 0.1),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(0.9, 1.3),
			Speed = NumberRange.new(6, 8),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, -18, 0),
		})
		Kit.light(water, colors.Water, 16, 0.6, false)
		return m
	end)
end

local function topiary(ctx: MapBase.Ctx, cf: CFrame, kind: number, parent: Instance)
	local colors = ctx.Def.Colors
	Kit.prop("Topiary", cf, parent, 6, function()
		local m = Kit.model("Topiary", parent)
		Kit.part({
			Name = "Pot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 2.6, 2.6),
			CFrame = Kit.upright(cf * CFrame.new(0, 0.8, 0)),
			Color = colors.Pot,
			Material = Enum.Material.Slate,
		}, m)
		local green = jitter(colors.HedgeTop, ctx.Rng, 0.06)
		if kind == 1 then
			-- Three balls on a stick.
			Kit.decor({
				Name = "Stem",
				Size = Vector3.new(0.3, 4.5, 0.3),
				CFrame = cf * CFrame.new(0, 3.6, 0),
				Color = colors.Wood,
			}, m)
			for i, size in { 2.6, 2, 1.4 } do
				oval({
					Name = "Ball",
					Size = Vector3.new(size, size, size),
					CFrame = cf * CFrame.new(0, 1.6 + i * 1.8, 0),
					Color = green,
					Material = Enum.Material.LeafyGrass,
				}, m, true)
			end
		elseif kind == 2 then
			-- A tall rounded cone.
			for i, size in { 2.8, 2.2, 1.6, 1 } do
				oval({
					Name = "Tier",
					Size = Vector3.new(size, 1.8, size),
					CFrame = cf * CFrame.new(0, 1.4 + i * 1.2, 0),
					Color = green,
					Material = Enum.Material.LeafyGrass,
				}, m, true)
			end
		else
			-- One big ball.
			oval({
				Name = "Ball",
				Size = Vector3.new(3.4, 3.2, 3.4),
				CFrame = cf * CFrame.new(0, 3.2, 0),
				Color = green,
				Material = Enum.Material.LeafyGrass,
			}, m, true)
		end
		return m
	end)
end

-- A patch of leaves with four flowers (prop "Flowers").
local function flowers(ctx: MapBase.Ctx, center: Vector3, radius: number, parent: Instance)
	local colors = ctx.Def.Colors
	local turn = ctx.Rng:NextNumber(0, math.pi)
	local leafColor = jitter(colors.Hedge, ctx.Rng, 0.1)
	local color = colors.Flowers[ctx.Rng:NextInteger(1, #colors.Flowers)]
	local spots = {}
	for i = 1, 4 do
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local r = ctx.Rng:NextNumber(0, radius * 0.7)
		spots[i] = Vector3.new(math.cos(a) * r, 0.85, math.sin(a) * r * 0.8)
	end
	Kit.prop("Flowers", CFrame.new(center), parent, 1.15, function()
		local m = Kit.model("Flowers", parent)
		m.PrimaryPart = oval({
			Name = "Leaves",
			Size = Vector3.new(radius * 2, 0.9, radius * 1.6),
			CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, turn, 0),
			Color = leafColor,
			Material = Enum.Material.LeafyGrass,
		}, m)
		for _, spot in spots do
			Kit.decor({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = CFrame.new(center + spot),
				Color = color,
			}, m)
		end
		return m
	end)
end

local function buildPlaza(
	ctx: MapBase.Ctx,
	plan: Plan,
	cellAt: (number, number) -> Vector2,
	parent: Instance,
	decoys: Instance
)
	local layout = ctx.Def.Layout
	local colors = ctx.Def.Colors
	local cs: number = layout.CellSize
	local room = plan.Plaza
	local m = Kit.model("FountainPlaza", parent)
	local a = cellAt(room.X, room.Y)
	local b = cellAt(room.X + room.W - 1, room.Y + room.H - 1)
	local mid = (a + b) / 2
	local w = room.W * cs - layout.HedgeThickness
	local d = room.H * cs - layout.HedgeThickness
	Kit.decor({
		Name = "Paving",
		Size = Vector3.new(w, 0.2, d),
		CFrame = CFrame.new(MapBase.at(ctx, mid.X, mid.Y, 0.1)),
		Color = colors.Paving,
		Material = Enum.Material.Slate,
	}, m)
	Kit.decor({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.22, 24, 24),
		CFrame = Kit.upright(CFrame.new(MapBase.at(ctx, mid.X, mid.Y, 0.12))),
		Color = Kit.shade(colors.Paving, -0.15),
		Material = Enum.Material.Cobblestone,
	}, m)
	local center = MapBase.at(ctx, mid.X, mid.Y, 0)
	buildFountain(ctx, center, m)
	-- Benches facing the fountain; lamps, topiary and flowers in the corners (the ways in and
	-- out of the plaza are along its sides, so the corners are always against hedges).
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local benchPos = center + dir * 12.5
		HideSeekProps.bench(CFrame.lookAt(benchPos, center), colors, m)
		local sx, sz = math.sign(dir.X), math.sign(dir.Z)
		local corner = center + Vector3.new(sx * (w / 2 - 2), 0, sz * (d / 2 - 2))
		HideSeekProps.lantern(CFrame.lookAt(corner, center), colors, m)
		topiary(
			ctx,
			CFrame.new(center + Vector3.new(sx * (w / 2 - 6.5), 0, sz * (d / 2 - 2.2))),
			i % 3 + 1,
			m
		)
		flowers(ctx, center + Vector3.new(sx * (w / 2 - 2.4), 0, sz * (d / 2 - 6.5)), 1.6, m)
	end
	for i = 1, layout.PlazaDecoys do
		local angle = (i / layout.PlazaDecoys) * math.pi * 2
			+ math.pi / 12
			+ ctx.Rng:NextNumber(-0.1, 0.1)
		local r = ctx.Rng:NextNumber(10.2, 10.8)
		local p = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		HidingPumpkin.Decoy(
			CFrame.new(p) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
			ctx.Rng,
			decoys
		)
	end
end

-- Build ------------------------------------------------------------------------------------------

function HedgeMaze.Build(def: any): Model
	local colors = def.Colors
	local layout = def.Layout
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Pebble,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.LeafyGrass,
	})
	local model = ctx.Model
	local walls = model:FindFirstChild("Walls")
	if walls then
		for _, wall in walls:GetChildren() do
			if wall:IsA("BasePart") then
				wall.Transparency = 1
				wall.CastShadow = false
			end
		end
	end
	local plan = HedgeMaze.Plan(def)
	local maze = plan.Maze
	local cells: number = layout.Cells
	local cs: number = layout.CellSize
	local half = cells * cs / 2
	local function edgeAt(x: number, y: number): Vector2
		return Vector2.new(-half + x * cs, -half + y * cs)
	end
	local function cellAt(x: number, y: number): Vector2
		return Vector2.new(-half + (x - 0.5) * cs, -half + (y - 0.5) * cs)
	end

	-- Hedges: the outer ring, then every inner run, then posts where they meet.
	local hedges = Kit.model("Hedges", model)
	local posts: { [string]: Vector2 } = {}
	local function addPost(x: number, y: number)
		posts[x .. "," .. y] = edgeAt(x, y)
	end
	local border = {
		{ 0, 0, cells, 0 },
		{ cells, 0, cells, cells },
		{ 0, cells, cells, cells },
		{ 0, 0, 0, cells },
	}
	for _, run in border do
		hedge(ctx, edgeAt(run[1], run[2]), edgeAt(run[3], run[4]), hedges)
		addPost(run[1], run[2])
		addPost(run[3], run[4])
	end
	local roseFolder = Kit.model("Roses", hedges)
	for _, run in MazeGen.WallRuns(maze) do
		local a, b = edgeAt(run.X0, run.Y0), edgeAt(run.X1, run.Y1)
		hedge(ctx, a, b, hedges)
		addPost(run.X0, run.Y0)
		addPost(run.X1, run.Y1)
		if ctx.Rng:NextNumber() < layout.RoseChance then
			roses(ctx, a, b, roseFolder)
		end
	end
	for _, p in posts do
		post(ctx, p, hedges)
	end
	-- Garden arches over some gaps that have a hedge end on both sides.
	local gaps: { { Vector2 } } = {}
	for x = 1, cells - 1 do
		for y = 1, cells do
			if not maze.East[x][y] and posts[x .. "," .. (y - 1)] and posts[x .. "," .. y] then
				table.insert(gaps, { edgeAt(x, y - 1), edgeAt(x, y) })
			end
		end
	end
	for y = 1, cells - 1 do
		for x = 1, cells do
			if not maze.South[x][y] and posts[(x - 1) .. "," .. y] and posts[x .. "," .. y] then
				table.insert(gaps, { edgeAt(x - 1, y), edgeAt(x, y) })
			end
		end
	end
	for _ = 1, math.min(layout.Arches, #gaps) do
		local gap = table.remove(gaps, ctx.Rng:NextInteger(1, #gaps))
		if gap then
			arch(ctx, gap[1], gap[2], roseFolder)
		end
	end

	local garden = Kit.model("Garden", model)
	local decoys = Kit.model("Decoys", model)
	buildPlaza(ctx, plan, cellAt, garden, decoys)

	-- Seeker hut in its corner room, the door towards the maze middle.
	local room = plan.HutRoom
	local roomA = cellAt(room.X, room.Y)
	local roomB = cellAt(room.X + room.W - 1, room.Y + room.H - 1)
	local roomMid = (roomA + roomB) / 2
	local toMiddle = -roomMid
	local facing = if math.abs(toMiddle.X) >= math.abs(toMiddle.Y)
		then Vector2.new(math.sign(toMiddle.X), 0)
		else Vector2.new(0, math.sign(toMiddle.Y))
	-- Stand the hut a little back from the door side so there's room to come out.
	local hutPos = roomMid - facing * 1.5
	local hutCf = CFrame.lookAt(
		MapBase.at(ctx, hutPos.X, hutPos.Y, 0),
		MapBase.at(ctx, hutPos.X + facing.X, hutPos.Y + facing.Y, 0)
	)
	HideSeekProps.seekerHut(hutCf, layout.HutSize, {
		Wall = colors.HutWall,
		Roof = colors.Roof,
		Trim = colors.Trim,
		Door = colors.HutDoor,
		Glow = colors.Glow,
		Text = colors.HutText,
	}, layout.HutSpawns, garden)

	-- Hider spawns (instead of MapBase's ring in the middle).
	local spawnFolder = model:FindFirstChild(def.SpawnFolder) :: Instance
	spawnFolder:ClearAllChildren()
	for _, c in plan.SpawnCells do
		local p = cellAt(c.X, c.Y)
		HideSeekProps.hiderSpawn(MapBase.at(ctx, p.X, p.Y, 0), ctx.Rng, spawnFolder)
	end

	-- Decoys: tucked into the closed end of each dead end...
	local wallGap = cs / 2 - layout.HedgeThickness / 2 - 2.6 -- from cell middle to beside a hedge
	local used: { [string]: boolean } = {}
	for _, c in plan.DeadEnds do
		used[c.X .. "," .. c.Y] = true
		-- The open side; the pumpkins sit towards the opposite (closed) end.
		local openDir = Vector2.zero
		for _, side in SIDES do
			if not MazeGen.HasWall(maze, c.X, c.Y, side.Name) then
				openDir = side.Step
			end
		end
		local center = cellAt(c.X, c.Y)
		local back = center - openDir * wallGap
		local side = Vector2.new(openDir.Y, openDir.X)
		for i = 1, layout.DecoysPerDeadEnd do
			local offset = if layout.DecoysPerDeadEnd == 1 then 0 else (i - 1.5) * 4.4
			local p = back
				+ side * offset
				+ Vector2.new(ctx.Rng:NextNumber(-0.4, 0.4), ctx.Rng:NextNumber(-0.4, 0.4))
			HidingPumpkin.Decoy(
				CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
					* CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
				ctx.Rng,
				decoys
			)
		end
	end
	-- ...and along the paths, against a hedge so they don't block the way.
	local placed = 0
	local tries = 0
	while placed < layout.CorridorDecoys and tries < 400 do
		tries += 1
		local x, y = ctx.Rng:NextInteger(1, cells), ctx.Rng:NextInteger(1, cells)
		local key = x .. "," .. y
		if used[key] or inRoom(plan.Plaza, x, y) or inRoom(plan.HutRoom, x, y) then
			continue
		end
		local d = SIDES[ctx.Rng:NextInteger(1, 4)]
		if not MazeGen.HasWall(maze, x, y, d.Name) then
			continue
		end
		used[key] = true
		placed += 1
		local p = cellAt(x, y) + d.Step * wallGap
		HidingPumpkin.Decoy(
			CFrame.new(MapBase.at(ctx, p.X, p.Y, 0))
				* CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
			ctx.Rng,
			decoys
		)
	end

	-- Lamp posts on a regular grid of cells, in a corner of the cell against the hedges.
	local lamps = Kit.model("Lamps", garden)
	local grid = layout.LanternGrid
	for y = 2, cells - 1, grid do
		for x = 2, cells - 1, grid do
			if inRoom(plan.Plaza, x, y) or inRoom(plan.HutRoom, x, y) then
				continue
			end
			local c = cellAt(x, y)
			local p = c
				+ Vector2.new(
					cs / 2 - layout.HedgeThickness / 2 - 1.4,
					cs / 2 - layout.HedgeThickness / 2 - 1.4
				)
			HideSeekProps.lantern(
				CFrame.lookAt(MapBase.at(ctx, p.X, p.Y, 0), MapBase.at(ctx, c.X, c.Y, 0)),
				colors,
				lamps
			)
		end
	end

	-- Flower patches at the foot of the hedges.
	for _ = 1, layout.FlowerPatches do
		local x, y = ctx.Rng:NextInteger(1, cells), ctx.Rng:NextInteger(1, cells)
		if inRoom(plan.Plaza, x, y) or inRoom(plan.HutRoom, x, y) then
			continue
		end
		local d = SIDES[ctx.Rng:NextInteger(1, 4)]
		if MazeGen.HasWall(maze, x, y, d.Name) then
			local along = Vector2.new(d.Step.Y, d.Step.X) * ctx.Rng:NextNumber(-3, 3)
			local p = cellAt(x, y) + d.Step * (cs / 2 - layout.HedgeThickness / 2 - 1) + along
			flowers(ctx, MapBase.at(ctx, p.X, p.Y, 0), 1.2, garden)
		end
	end
	-- Topiary in the hut garden.
	for i, corner in { Vector2.new(-1, -1), Vector2.new(1, 1) } do
		local p = roomMid + corner * (room.W * cs / 2 - 4)
		topiary(ctx, CFrame.new(MapBase.at(ctx, p.X, p.Y, 0)), i, garden)
	end
	return model
end

return HedgeMaze
