--!strict
--[[
	"ScareMaze" map builder (settings: src/shared/Config/Maps/ScareMaze.luau): a foggy
	cornfield maze at night, made with MazeGen.

	  south (+Z)  the field where Survivors start (folder Spawns, tagged SurvivorSpawn) and the
	              entrance gate with the "SCAREMAZE - DON'T STOP MOVING" sign
	  middle      the corn maze (folder Maze: CornWalls, Lanterns, Decor), with a clearing in
	              the middle where Haunters start (folder HauntSpawns, tagged HauntSpawn)
	  north (-Z)  the glowing exit gate (part MazeExit, tagged MazeExit) and the escape yard
	Scare traps are in folder ScareTraps: one Model per trap holding its Trigger part (tagged
	ScareTrigger, attribute Kind) and, for scarecrows, the scarecrow itself (attribute
	ScareActor). Zombies, bats and ghosts appear only when their trap goes off.
	A Trigger's RightVector points at the corn wall its scare comes out of; a Patrol trigger is
	a long box: its scarecrow walks from one end to the other.
	The way from the entrance to the exit always exists (MazeGen.Solve); most traps and the
	lanterns are along it.
	Repeated decorations are props (Kit.prop), so one model in ReplicatedStorage.Custom.Props
	swaps every copy: Pumpkin, JackOLantern, Lantern (on the corn walls; the bracket stays),
	Lamppost, HayBale, Crow, DeadTree.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local ScareActors = require(script.Parent.Parent.Build.ScareActors)
local MapBase = require(script.Parent.MapBase)
local MazeGen = require(script.Parent.MazeGen)

local ScareMaze = {}

type Cell = MazeGen.Cell

export type Plan = {
	Maze: MazeGen.Maze,
	Width: number, -- cells west-east
	Height: number, -- cells north-south
	CellSize: number,
	Thickness: number,
	West: number, -- map x offset of the maze's west edge
	North: number, -- map z offset of the maze's north edge
	Entrance: Cell, -- on the south row
	Exit: Cell, -- on the north row
	Route: { Cell }, -- entrance to exit
	Clearing: MazeGen.Room?,
	Traps: { { Cell: Cell, Kind: string, Travel: Vector3 } },
	Patrols: { { From: Cell, To: Cell } },
	HauntCells: { Cell },
	Lanterns: { Cell },
	DeadEnds: { Cell },
}

local DIRS = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local DIR_ORDER = { "N", "E", "S", "W" } -- fixed order, so the same seed gives the same map

local function key(c: Cell): string
	return c.X .. "," .. c.Y
end

-- The maze side ("N", "S", "E", "W") a flat direction points at.
local function sideOf(dir: Vector3): string
	if math.abs(dir.X) > math.abs(dir.Z) then
		return if dir.X > 0 then "E" else "W"
	end
	return if dir.Z > 0 then "S" else "N"
end

-- A maze column from the Layout: 0 = middle, negative = counted from the east.
local function column(value: number, width: number): number
	if value == 0 then
		return math.ceil(width / 2)
	elseif value < 0 then
		return math.clamp(width + 1 + value, 1, width)
	end
	return math.clamp(value, 1, width)
end

--[[
	Works out the maze, the way out and where everything goes, without making any parts
	(the tests check it: tests/specs/scaremaze.spec.luau).
]]
function ScareMaze.Plan(def: any): Plan
	local layout = def.Layout
	local size: Vector3 = def.Size
	local p: number = layout.CellSize
	local t: number = layout.WallThickness
	local width = math.max(4, math.floor((size.X - t) / p))
	local height = math.max(4, math.floor((size.Z - t - layout.PlazaDepth - layout.YardDepth) / p))
	local rng = Random.new(def.Seed)

	local clearing: MazeGen.Room? = nil
	local c = layout.Clearing
	if c > 0 and c < width - 2 and c < height - 2 then
		clearing = {
			X = math.floor((width - c) / 2) + 1,
			Y = math.floor((height - c) / 2) + 1,
			W = c,
			H = c,
		}
	end
	local maze = MazeGen.Generate(
		width,
		height,
		def.Seed,
		{ Braid = layout.Braid, Rooms = if clearing then { clearing } else nil }
	)
	-- Entrance (south row) and exit (north row). A column of 0 = the one that makes the
	-- longest way through.
	local entranceColumns: { number } = {}
	local exitColumns: { number } = {}
	for x = 1, width do
		if layout.EntranceColumn == 0 then
			table.insert(entranceColumns, x)
		end
		if layout.ExitColumn == 0 then
			table.insert(exitColumns, x)
		end
	end
	if #entranceColumns == 0 then
		entranceColumns = { column(layout.EntranceColumn, width) }
	end
	if #exitColumns == 0 then
		exitColumns = { column(layout.ExitColumn, width) }
	end
	local entrance: Cell = { X = entranceColumns[1], Y = height }
	local exit: Cell = { X = exitColumns[1], Y = 1 }
	local route: { Cell } = {}
	for _, ex in entranceColumns do
		for _, xx in exitColumns do
			local way = MazeGen.Solve(maze, { X = ex, Y = height }, { X = xx, Y = 1 })
			if way and #way > #route then
				entrance, exit, route = { X = ex, Y = height }, { X = xx, Y = 1 }, way
			end
		end
	end
	assert(#route > 0, "ScareMaze: no way from the entrance to the exit") -- MazeGen mazes are connected

	local onRoute: { [string]: number } = {}
	for i, cell in route do
		onRoute[key(cell)] = i
	end
	local function inClearing(cell: Cell): boolean
		local r = clearing
		return r ~= nil
			and cell.X >= r.X
			and cell.X < r.X + r.W
			and cell.Y >= r.Y
			and cell.Y < r.Y + r.H
	end

	-- Cells already used by a trap or patrol, and the ones next to them (spacing).
	local used: { Cell } = {}
	local function farFromUsed(cell: Cell, gap: number): boolean
		for _, u in used do
			if math.abs(u.X - cell.X) + math.abs(u.Y - cell.Y) < gap then
				return false
			end
		end
		return true
	end
	-- Keep traps away from the first and last few cells of the way out.
	local function allowed(cell: Cell): boolean
		local i = onRoute[key(cell)]
		if i and (i <= 2 or i >= #route - 1) then
			return false
		end
		return not inClearing(cell)
			and not (cell.X == entrance.X and cell.Y == entrance.Y)
			and not (cell.X == exit.X and cell.Y == exit.Y)
	end

	-- Traps: most of them spread evenly along the way out, the rest in side paths.
	local kinds: { string } = {}
	for i = 1, layout.Traps do
		table.insert(kinds, layout.TrapKinds[(i - 1) % #layout.TrapKinds + 1])
	end
	for i = #kinds, 2, -1 do
		local j = rng:NextInteger(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	local traps: { { Cell: Cell, Kind: string, Travel: Vector3 } } = {}
	local function travelAt(cell: Cell): Vector3
		local i = onRoute[key(cell)]
		if i and i > 1 then
			-- The way Survivors come in (always straight along the maze grid).
			local from = route[i - 1]
			return Vector3.new(cell.X - from.X, 0, cell.Y - from.Y)
		end
		-- A side path: the way in from the first open side.
		for _, name in DIR_ORDER do
			if not MazeGen.HasWall(maze, cell.X, cell.Y, name) then
				return -DIRS[name]
			end
		end
		return DIRS.N
	end
	local function addTrap(cell: Cell): boolean
		if
			#traps >= layout.Traps
			or not allowed(cell)
			or not farFromUsed(cell, layout.TrapSpacing)
		then
			return false
		end
		table.insert(traps, { Cell = cell, Kind = kinds[#traps + 1], Travel = travelAt(cell) })
		table.insert(used, cell)
		return true
	end
	local routeTraps = math.floor(layout.Traps * layout.RouteTrapShare + 0.5)
	local stride = math.max(1, (#route - 4) / math.max(routeTraps, 1))
	local position = 3
	while position <= #route - 2 and #traps < routeTraps do
		local index = math.floor(position)
		-- Try this spot, then a couple further on if it's too close to something.
		for offset = 0, 2 do
			local cell = route[index + offset]
			if cell and addTrap(cell) then
				break
			end
		end
		position += stride
	end

	-- Patrols: straight corridors (no wall between neighbours) of PatrolMinCells to
	-- PatrolMaxCells, preferring the way out, not right next to a trap.
	type Corridor = { From: Cell, To: Cell, Cells: { Cell }, Score: number }
	local corridors: { Corridor } = {}
	local function addCorridor(run: { Cell })
		local span = math.min(#run, layout.PatrolMaxCells)
		if span < layout.PatrolMinCells then
			return
		end
		-- The window of the run with the most of the way out in it.
		local best: { Cell }? = nil
		local bestScore = -1
		for first = 1, #run - span + 1 do
			local cells = table.move(run, first, first + span - 1, 1, {})
			local score = rng:NextNumber(0, 0.5)
			local ok = true
			for _, cell in cells do
				if not allowed(cell) then
					ok = false
					break
				end
				if onRoute[key(cell)] then
					score += 1
				end
			end
			if ok and score > bestScore then
				best, bestScore = cells, score
			end
		end
		if best then
			table.insert(
				corridors,
				{ From = best[1], To = best[#best], Cells = best, Score = bestScore }
			)
		end
	end
	for y = 1, height do
		local run: { Cell } = {}
		for x = 1, width do
			table.insert(run, { X = x, Y = y })
			if MazeGen.HasWall(maze, x, y, "E") then
				addCorridor(run)
				run = {}
			end
		end
	end
	for x = 1, width do
		local run: { Cell } = {}
		for y = 1, height do
			table.insert(run, { X = x, Y = y })
			if MazeGen.HasWall(maze, x, y, "S") then
				addCorridor(run)
				run = {}
			end
		end
	end
	table.sort(corridors, function(a, b)
		return a.Score > b.Score
	end)
	local patrols: { { From: Cell, To: Cell } } = {}
	for _, corridor in corridors do
		if #patrols >= layout.Patrols then
			break
		end
		local free = true
		for _, cell in corridor.Cells do
			if not farFromUsed(cell, 2) then
				free = false
				break
			end
		end
		if free then
			table.insert(patrols, { From = corridor.From, To = corridor.To })
			for _, cell in corridor.Cells do
				table.insert(used, cell)
			end
		end
	end

	-- Side paths: dead ends first, then any cell off the way out.
	local deadEnds = MazeGen.DeadEnds(maze)
	local side: { Cell } = {}
	for _, cell in deadEnds do
		if not onRoute[key(cell)] then
			table.insert(side, cell)
		end
	end
	for i = #side, 2, -1 do
		local j = rng:NextInteger(1, i)
		side[i], side[j] = side[j], side[i]
	end
	local others: { Cell } = {}
	for y = 1, height do
		for x = 1, width do
			local cell = { X = x, Y = y }
			if not onRoute[key(cell)] then
				table.insert(others, cell)
			end
		end
	end
	for i = #others, 2, -1 do
		local j = rng:NextInteger(1, i)
		others[i], others[j] = others[j], others[i]
	end
	for _, list in { side, others, route } do
		for _, cell in list do
			if #traps >= layout.Traps then
				break
			end
			addTrap(cell)
		end
	end

	-- Haunters start in the clearing, then in cells far from the entrance.
	local haunt: { Cell } = {}
	if clearing then
		for y = clearing.Y, clearing.Y + clearing.H - 1 do
			for x = clearing.X, clearing.X + clearing.W - 1 do
				table.insert(haunt, { X = x, Y = y })
			end
		end
	end
	for _, cell in others do
		if #haunt >= layout.HauntSpawns then
			break
		end
		if cell.Y < height - 2 and farFromUsed(cell, 2) and not inClearing(cell) then
			table.insert(haunt, cell)
		end
	end
	while #haunt > layout.HauntSpawns do
		table.remove(haunt)
	end

	-- Lanterns every few cells along the way out, plus a few in side paths.
	local lanterns: { Cell } = {}
	for i = 2, #route, layout.LanternEvery do
		table.insert(lanterns, route[i])
	end
	for i = 1, math.min(layout.SideLanterns, #side) do
		table.insert(lanterns, side[#side - i + 1])
	end

	return {
		Maze = maze,
		Width = width,
		Height = height,
		CellSize = p,
		Thickness = t,
		West = -width * p / 2,
		North = -size.Z / 2 + layout.YardDepth + t / 2,
		Entrance = entrance,
		Exit = exit,
		Route = route,
		Clearing = clearing,
		Traps = traps,
		Patrols = patrols,
		HauntCells = haunt,
		Lanterns = lanterns,
		DeadEnds = deadEnds,
	}
end

-- Building -----------------------------------------------------------------------------------

type Builder = {
	Ctx: MapBase.Ctx,
	Plan: Plan,
	Colors: any,
	Layout: any,
	Rng: Random,
}

-- Map offset (x, z) of a cell's middle.
local function cellOffset(plan: Plan, cell: Cell): Vector3
	return Vector3.new(
		plan.West + (cell.X - 0.5) * plan.CellSize,
		0,
		plan.North + (cell.Y - 0.5) * plan.CellSize
	)
end

-- World position on the floor top of a cell's middle (+ height y).
local function cellPoint(b: Builder, cell: Cell, y: number?): Vector3
	local o = cellOffset(b.Plan, cell)
	return MapBase.at(b.Ctx, o.X, o.Z, y)
end

-- World position on the floor of a maze grid corner (edge coordinates).
local function edgePoint(b: Builder, ex: number, ey: number): Vector3
	local plan = b.Plan
	return MapBase.at(b.Ctx, plan.West + ex * plan.CellSize, plan.North + ey * plan.CellSize)
end

local function jitter(b: Builder, color: Color3, amount: number): Color3
	return Kit.shade(color, b.Rng:NextNumber(-amount, amount))
end

-- One straight corn wall from floor point `a` to `c` (both on the wall's middle line).
local function cornWall(b: Builder, a: Vector3, c: Vector3, parent: Instance)
	local layout, colors = b.Layout, b.Colors
	local t: number = b.Plan.Thickness
	local h: number = layout.CornHeight
	local along = c - a
	local length = along.Magnitude + t
	local mid = (a + c) / 2
	local cf = CFrame.lookAt(mid, mid + along.Unit)
	local wall = Kit.model("CornWall", parent)
	local body = h - 1.5
	Kit.part({
		Name = "Corn",
		Size = Vector3.new(t, body, length),
		CFrame = cf * CFrame.new(0, body / 2, 0),
		Color = jitter(b, colors.Corn, 0.08),
		Material = Enum.Material.Grass,
	}, wall)
	-- Rounded, leafy top.
	local top = Kit.decor({
		Name = "CornTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, t + 0.8, t + 0.8),
		CFrame = cf * CFrame.new(0, body, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = jitter(b, colors.CornTop, 0.08),
		Material = Enum.Material.Grass,
	}, wall)
	top.CastShadow = false
	-- Long drooping leaves sticking out of both sides.
	local leafSpacing: number = layout.LeafSpacing
	if leafSpacing > 0 then
		local leaves = math.max(1, math.floor(length / leafSpacing))
		for i = 1, leaves do
			local side = if i % 2 == 0 then 1 else -1
			local z = -length / 2 + (i - 0.5) * (length / leaves) + b.Rng:NextNumber(-1.5, 1.5)
			local y = b.Rng:NextNumber(3.5, body - 1)
			local outward = cf.RightVector * side
			local base = cf.Position + outward * (t / 2) + Vector3.new(0, y, 0) + cf.LookVector * z
			local long = b.Rng:NextNumber(2.4, 3.6)
			local leafCf = CFrame.lookAt(base, base + outward)
				* CFrame.Angles(0, math.rad(b.Rng:NextNumber(-30, 30)), 0)
				* CFrame.Angles(math.rad(b.Rng:NextNumber(-35, -15)), 0, 0)
			Kit.wedge({
				Name = "Leaf",
				Size = Vector3.new(0.12, 0.7, long),
				CFrame = leafCf * CFrame.new(0, 0, -long / 2 + 0.3),
				Color = jitter(b, colors.Leaf, 0.12),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, wall)
		end
	end
	-- Tassels poking out of the top so it reads as corn from inside the maze.
	local spacing: number = layout.TasselSpacing
	local count = math.max(1, math.floor(length / spacing))
	for i = 1, count do
		local z = -length / 2 + (i - 0.5) * (length / count) + b.Rng:NextNumber(-1, 1)
		local tall = b.Rng:NextNumber(1.6, 2.8)
		Kit.decor({
			Name = "Tassel",
			Size = Vector3.new(0.3, tall, 0.3),
			CFrame = cf
				* CFrame.new(b.Rng:NextNumber(-t / 3, t / 3), body + t / 2 + tall / 2 - 0.4, z)
				* CFrame.Angles(
					math.rad(b.Rng:NextNumber(-18, 18)),
					0,
					math.rad(b.Rng:NextNumber(-18, 18))
				),
			Color = jitter(b, colors.Tassel, 0.12),
			Material = Enum.Material.Grass,
		}, wall).CastShadow =
			false
	end
end

local function buildWalls(b: Builder, parent: Instance)
	local plan = b.Plan
	local folder = Kit.model("CornWalls", parent)
	for _, run in MazeGen.WallRuns(plan.Maze) do
		cornWall(b, edgePoint(b, run.X0, run.Y0), edgePoint(b, run.X1, run.Y1), folder)
	end
	-- The outside of the maze, with gaps for the entrance (south) and exit (north).
	local w, h = plan.Width, plan.Height
	local entrance, exit = plan.Entrance, plan.Exit
	local border = {
		{ 0, 0, exit.X - 1, 0 },
		{ exit.X, 0, w, 0 },
		{ 0, h, entrance.X - 1, h },
		{ entrance.X, h, w, h },
		{ 0, 0, 0, h },
		{ w, 0, w, h },
	}
	for _, r in border do
		if r[1] ~= r[3] or r[2] ~= r[4] then
			cornWall(b, edgePoint(b, r[1], r[2]), edgePoint(b, r[3], r[4]), folder)
		end
	end
end

-- A small pumpkin (an oval, Roblox Ball parts are always round), lit ones have a carved face.
-- Props "Pumpkin" and "JackOLantern", only for looks (a custom one never gets in the way).
local function pumpkin(b: Builder, cf: CFrame, size: number, lit: boolean, parent: Instance)
	local colors = b.Colors
	local orange = jitter(b, colors.Orange, 0.1) -- (drawn either way: the map stays the same)
	local name = if lit then "JackOLantern" else "Pumpkin"
	local light: Kit.PropLight? = if lit
		then { Color = colors.Glow, Range = size * 5, Brightness = 1.3, Height = 0.45 }
		else nil
	return Kit.prop(name, cf, parent, size * (if lit then 1.2 else 1.25), function()
		local m = Kit.model(name, parent)
		local body = Kit.decor({
			Name = "Pumpkin",
			Size = Vector3.new(size * 1.25, size, size * 1.15),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			Color = orange,
		}, m)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		Kit.decor({
			Name = "Stem",
			Size = Vector3.new(size * 0.15, size * 0.3, size * 0.15),
			CFrame = cf * CFrame.new(0, size * 1.08, 0) * CFrame.Angles(0, 0, math.rad(10)),
			Color = colors.Green,
		}, m)
		if lit then
			local front = size * 1.15 / 2
			for _, side in { -1, 1 } do
				Kit.decor({
					Name = "Eye",
					Size = Vector3.new(size * 0.18, size * 0.18, 0.15),
					CFrame = cf
						* CFrame.new(side * size * 0.22, size * 0.62, -front * 0.92)
						* CFrame.Angles(0, 0, math.rad(45)),
					Color = colors.Glow,
					Material = Enum.Material.Neon,
				}, m)
			end
			Kit.decor({
				Name = "Mouth",
				Size = Vector3.new(size * 0.5, size * 0.1, 0.15),
				CFrame = cf * CFrame.new(0, size * 0.32, -front * 0.9),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, m)
			Kit.light(body, colors.Glow, size * 5, 1.3, true)
		end
		m.PrimaryPart = body
		return m
	end, { Light = light, Visual = true })
end

-- A lantern hanging on the corn wall on side `side` of `cell`: an iron bracket (always) and
-- the lantern itself, prop "Lantern" (the same name as the lobby's little lanterns).
local function wallLantern(b: Builder, cell: Cell, side: string, parent: Instance)
	local colors = b.Colors
	local plan = b.Plan
	local dir = DIRS[side]
	local inner = (plan.CellSize - plan.Thickness) / 2
	local base = cellPoint(b, cell, 0) + dir * (inner - 0.9)
	local cf = CFrame.lookAt(base, base + dir) -- facing the wall
	local m = Kit.model("WallLantern", parent)
	Kit.decor({
		Name = "Bracket",
		Size = Vector3.new(0.3, 0.3, 1.6),
		CFrame = cf * CFrame.new(0, 8.9, -0.4),
		Color = colors.Iron,
	}, m)
	local foot = cf * CFrame.new(0, 6.975, 0)
	Kit.prop("Lantern", foot, m, 1.675, function()
		local lantern = Kit.model("Lantern", m)
		Kit.decor({
			Name = "Cap",
			Size = Vector3.new(1.1, 0.3, 1.1),
			CFrame = cf * CFrame.new(0, 8.5, 0),
			Color = colors.Iron,
		}, lantern)
		local lamp = Kit.decor({
			Name = "Lamp",
			Size = Vector3.new(0.75, 1.1, 0.75),
			CFrame = cf * CFrame.new(0, 7.75, 0),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, lantern)
		Kit.decor({
			Name = "Base",
			Size = Vector3.new(1, 0.25, 1),
			CFrame = cf * CFrame.new(0, 7.1, 0),
			Color = colors.Iron,
		}, lantern)
		Kit.light(lamp, colors.Glow, 22, 1.5, true)
		lantern.PrimaryPart = lamp
		return lantern
	end, {
		Light = { Color = colors.Glow, Range = 22, Brightness = 1.5, Height = 0.5 },
		Visual = true,
	})
	return m
end

-- A lantern on a post (the field and the yard): prop "Lamppost".
local function postLantern(b: Builder, pos: Vector3, parent: Instance)
	local colors = b.Colors
	Kit.prop("Lamppost", CFrame.new(pos), parent, 9.7, function()
		local m = Kit.model("Lamppost", parent)
		m.PrimaryPart = Kit.part({
			Name = "Post",
			Size = Vector3.new(0.7, 8, 0.7),
			CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		local lamp = Kit.decor({
			Name = "Lamp",
			Size = Vector3.new(1, 1.3, 1),
			CFrame = CFrame.new(pos + Vector3.new(0, 8.7, 0)),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
		Kit.decor({
			Name = "Cap",
			Size = Vector3.new(1.4, 0.35, 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 9.5, 0)),
			Color = colors.Iron,
		}, m)
		Kit.light(lamp, colors.Glow, 26, 1.6, true)
		return m
	end, { Light = { Color = colors.Glow, Range = 26, Brightness = 1.6, Height = 0.9 } })
end

-- A crow perched on cf (prop "Crow", only for looks).
local function crow(b: Builder, cf: CFrame, parent: Instance)
	local colors = b.Colors
	Kit.prop("Crow", cf, parent, 1.35, function()
		local m = Kit.model("Crow", parent)
		local body = Kit.decor({
			Name = "Body",
			Size = Vector3.new(0.8, 0.8, 1.4),
			CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-15), 0, 0),
			Color = colors.Crow,
		}, m)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		Kit.decor({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = cf * CFrame.new(0, 1.05, -0.6),
			Color = colors.Crow,
		}, m)
		Kit.decor({
			Name = "Beak",
			Size = Vector3.new(0.18, 0.15, 0.45),
			CFrame = cf * CFrame.new(0, 1, -1.05),
			Color = colors.Beak,
		}, m)
		Kit.decor({
			Name = "Tail",
			Size = Vector3.new(0.5, 0.12, 0.7),
			CFrame = cf * CFrame.new(0, 0.45, 0.85) * CFrame.Angles(math.rad(20), 0, 0),
			Color = colors.Crow,
		}, m)
		m.PrimaryPart = body
		return m
	end, { Visual = true })
end

-- A rectangular hay bale standing on cf (prop "HayBale").
local function hayBale(b: Builder, cf: CFrame, parent: Instance)
	local colors = b.Colors
	local hay = jitter(b, colors.Hay, 0.08) -- (drawn either way: the map stays the same)
	Kit.prop("HayBale", cf, parent, 2.4, function()
		local m = Kit.model("HayBale", parent)
		local bale = Kit.part({
			Name = "HayBale",
			Size = Vector3.new(4, 2.4, 2.6),
			CFrame = cf * CFrame.new(0, 1.2, 0),
			Color = hay,
			Material = Enum.Material.Grass,
		}, m)
		for _, x in { -1, 1 } do
			Kit.decor({
				Name = "Twine",
				Size = Vector3.new(0.15, 2.45, 2.65),
				CFrame = bale.CFrame * CFrame.new(x * 1.1, 0, 0),
				Color = colors.Wood,
			}, m)
		end
		m.PrimaryPart = bale
		return m
	end)
end

-- A sign board with spooky lettering on its south (+Z) side.
local function sign(
	b: Builder,
	name: string,
	cf: CFrame,
	size: Vector3,
	text: string,
	color: Color3,
	parent: Instance
): Part
	local board = Kit.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = Kit.shade(b.Colors.Wood, 0.25),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	Kit.surfaceText(board, text, color, Enum.NormalId.Back)
	return board
end

-- The entrance gate on the south side: two posts, a beam and the big sign.
local function buildEntrance(b: Builder, parent: Instance)
	local plan, colors, layout = b.Plan, b.Colors, b.Layout
	local gate = Kit.model("EntranceGate", parent)
	local centre = edgePoint(b, plan.Entrance.X - 0.5, plan.Height)
	local half = (plan.CellSize - plan.Thickness) / 2 + 0.9
	for _, side in { -1, 1 } do
		local base = centre + Vector3.new(side * half, 0, 0)
		Kit.part({
			Name = "GatePost",
			Size = Vector3.new(1.8, 17, 1.8),
			CFrame = CFrame.new(base + Vector3.new(0, 8.5, 0)),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, gate)
		pumpkin(b, CFrame.new(base + Vector3.new(0, 17, 0)), 2.2, true, gate)
	end
	Kit.part({
		Name = "GateBeam",
		Size = Vector3.new(half * 2 + 2, 1.4, 1.4),
		CFrame = CFrame.new(centre + Vector3.new(0, 15, 0)),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, gate)
	sign(
		b,
		"GateSign",
		CFrame.new(centre + Vector3.new(0, 17.6, 0.2)),
		Vector3.new(half * 2 + 3, 3.6, 0.4),
		layout.GateText,
		colors.Sign,
		gate
	)
	sign(
		b,
		"GateWarning",
		CFrame.new(centre + Vector3.new(0, 13.3, 0.3)),
		Vector3.new(half * 2 - 1, 1.6, 0.3),
		layout.GateSubText,
		colors.Glow,
		gate
	)
end

-- The glowing exit archway on the north side, and the MazeExit part behind it.
local function buildExit(b: Builder, parent: Instance)
	local plan, colors, layout = b.Plan, b.Colors, b.Layout
	local gate = Kit.model("ExitGate", parent)
	local centre = edgePoint(b, plan.Exit.X - 0.5, 0)
	local half = (plan.CellSize - plan.Thickness) / 2 + 1
	local h: number = layout.CornHeight
	for _, side in { -1, 1 } do
		Kit.part({
			Name = "Pillar",
			Size = Vector3.new(2, h + 2, plan.Thickness + 1),
			CFrame = CFrame.new(centre + Vector3.new(side * half, (h + 2) / 2, 0)),
			Color = Color3.fromRGB(90, 86, 100),
			Material = Enum.Material.Slate,
		}, gate)
	end
	-- A half circle of glowing pieces over the gap.
	local pieces = 9
	local arcCentre = centre + Vector3.new(0, h + 2, 0)
	local glow: BasePart? = nil
	for i = 0, pieces - 1 do
		local a0 = math.pi * i / pieces
		local a1 = math.pi * (i + 1) / pieces
		local p0 = arcCentre + Vector3.new(math.cos(a0) * half, math.sin(a0) * half, 0)
		local p1 = arcCentre + Vector3.new(math.cos(a1) * half, math.sin(a1) * half, 0)
		local piece = Kit.decor({
			Name = "Arch",
			Size = Vector3.new(1.2, 1.2, (p1 - p0).Magnitude + 0.5),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = colors.ExitGlow,
			Material = Enum.Material.Neon,
		}, gate)
		if i == math.floor(pieces / 2) then
			glow = piece
		end
	end
	if glow then
		Kit.light(glow, colors.ExitGlow, 40, 2.5, false)
	end
	sign(
		b,
		"ExitSign",
		CFrame.new(arcCentre + Vector3.new(0, half + 1.6, 0.2)),
		Vector3.new(7, 2.4, 0.4),
		layout.ExitText,
		colors.ExitGlow,
		gate
	)
	-- Reaching this box (just past the gate) means you escaped.
	local exitPart = Kit.holder(
		"MazeExit",
		CFrame.new(centre + Vector3.new(0, 7, -plan.Thickness / 2 - 3)),
		Vector3.new(half * 2 + 2, 14, 6),
		gate
	)
	CollectionService:AddTag(exitPart, Tags.MazeExit)
end

-- A random x across the map at least `margin` from the fence and clear of every
-- { x, distance } in `avoid` (the gate, the spawns, other trees). nil if there's no room.
local function freeX(b: Builder, avoid: { { number } }, margin: number): number?
	local half = b.Ctx.Half.X - margin
	for _ = 1, 20 do
		local x = b.Rng:NextNumber(-half, half)
		local clear = true
		for _, spot in avoid do
			if math.abs(x - spot[1]) < spot[2] then
				clear = false
				break
			end
		end
		if clear then
			return x
		end
	end
	return nil
end

-- The open field in front of the entrance: Survivor spawns, lanterns, trees and hay.
local function buildPlaza(b: Builder, spawns: Instance, parent: Instance)
	local plan, colors, layout, ctx = b.Plan, b.Colors, b.Layout, b.Ctx
	local def = ctx.Def
	local field = Kit.model("Field", parent)
	local southEdge = plan.North + plan.Height * plan.CellSize + plan.Thickness / 2
	local depth = ctx.Half.Y - southEdge
	local midZ = southEdge + depth / 2 + 1
	local gateX = plan.West + (plan.Entrance.X - 0.5) * plan.CellSize
	local limitX = ctx.Half.X - 16
	-- Spawns in rows of 8 in front of the gate.
	local perRow = 8
	local rows = math.ceil(def.Spawns / perRow)
	local spacingX, spacingZ = 6, 6
	local startX = math.clamp(
		gateX,
		-limitX + (perRow - 1) * spacingX / 2,
		limitX - (perRow - 1) * spacingX / 2
	)
	for i = 1, def.Spawns do
		local col = (i - 1) % perRow
		local row = (i - 1) // perRow
		local x = startX + (col - (perRow - 1) / 2) * spacingX
		local z = midZ + (row - (rows - 1) / 2) * spacingZ
		local spawn = Kit.holder(
			"SurvivorSpawn",
			CFrame.new(MapBase.at(ctx, x, z, 0.5)),
			Vector3.new(4, 1, 4),
			spawns
		)
		CollectionService:AddTag(spawn, Tags.SurvivorSpawn)
	end
	-- Lanterns lead to the gate.
	for _, side in { -1, 1 } do
		local lanternX = math.clamp(gateX + side * 9, -ctx.Half.X + 3, ctx.Half.X - 3)
		postLantern(b, MapBase.at(ctx, lanternX, southEdge + 4), field)
		postLantern(b, MapBase.at(ctx, startX + side * (perRow * spacingX / 2 + 4), midZ), field)
	end
	-- Trees at the sides of the field, clear of the gate and the spawns.
	local avoid = { { gateX, 14 }, { startX, perRow * spacingX / 2 + 6 } }
	for _ = 1, math.ceil(layout.DeadTrees / 2) do
		local x = freeX(b, avoid, 8)
		if x then
			table.insert(avoid, { x, 12 })
			Kit.deadTree(
				CFrame.new(MapBase.at(ctx, x, southEdge + b.Rng:NextNumber(6, depth - 4)))
					* CFrame.Angles(0, b.Rng:NextNumber(0, math.pi * 2), 0),
				b.Rng:NextNumber(13, 18),
				colors.Wood,
				b.Rng,
				field
			)
		end
	end
	-- Hay along the fence at the back of the field (behind the spawns).
	for i = 1, math.ceil(layout.HayBales / 2) do
		local x = -ctx.Half.X
			+ 8
			+ (i - 0.5) * (ctx.Half.X * 2 - 16) / math.ceil(layout.HayBales / 2)
		local cf = CFrame.new(MapBase.at(ctx, x + b.Rng:NextNumber(-4, 4), ctx.Half.Y - 3))
			* CFrame.Angles(0, b.Rng:NextNumber(-0.3, 0.3), 0)
		hayBale(b, cf, field)
		pumpkin(b, cf * CFrame.new(2.4, 2.4, 0), 1.5, i % 2 == 0, field)
	end
end

-- The escape yard behind the exit gate.
local function buildYard(b: Builder, parent: Instance)
	local plan, colors, layout, ctx = b.Plan, b.Colors, b.Layout, b.Ctx
	local yard = Kit.model("EscapeYard", parent)
	local northEdge = plan.North - plan.Thickness / 2
	local depth = northEdge + ctx.Half.Y
	local exitX = plan.West + (plan.Exit.X - 0.5) * plan.CellSize
	sign(
		b,
		"YardSign",
		CFrame.new(MapBase.at(ctx, exitX, -ctx.Half.Y + 0.4, 9)),
		Vector3.new(16, 4, 0.4),
		layout.YardText,
		colors.ExitGlow,
		yard
	)
	for _, side in { -1, 1 } do
		local lanternX = math.clamp(exitX + side * 12, -ctx.Half.X + 3, ctx.Half.X - 3)
		postLantern(b, MapBase.at(ctx, lanternX, -ctx.Half.Y + depth / 2), yard)
		local x = math.clamp(exitX + side * 20, -ctx.Half.X + 4, ctx.Half.X - 4)
		local cf = CFrame.new(MapBase.at(ctx, x, -ctx.Half.Y + 5))
		hayBale(b, cf, yard)
		pumpkin(b, cf * CFrame.new(0, 2.4, 0), 1.6, true, yard)
	end
	local avoid = { { exitX, 26 } }
	for _ = 1, math.floor(layout.DeadTrees / 2) do
		local x = freeX(b, avoid, 10)
		if x then
			table.insert(avoid, { x, 12 })
			Kit.deadTree(
				CFrame.new(MapBase.at(ctx, x, -ctx.Half.Y + b.Rng:NextNumber(5, depth - 5))),
				b.Rng:NextNumber(12, 16),
				colors.Wood,
				b.Rng,
				yard
			)
		end
	end
end

-- One scare trap: its Trigger (and a scarecrow for the scarecrow kind).
local function buildTrap(
	b: Builder,
	trap: { Cell: Cell, Kind: string, Travel: Vector3 },
	parent: Instance
)
	local plan, maze = b.Plan, b.Plan.Maze
	local cell = trap.Cell
	local inner = (plan.CellSize - plan.Thickness) / 2
	local centre = cellPoint(b, cell, 0)
	-- The scare comes out of a side wall (relative to the way through), if there is one.
	local look = trap.Travel
	local right = look:Cross(Vector3.yAxis)
	if
		MazeGen.HasWall(maze, cell.X, cell.Y, sideOf(-right))
		and not MazeGen.HasWall(maze, cell.X, cell.Y, sideOf(right))
	then
		look = -look
		right = -right
	end
	local m = Kit.model("ScareTrap", parent)
	m:SetAttribute("Kind", trap.Kind)
	local trigger = Kit.holder(
		"Trigger",
		CFrame.lookAt(centre + Vector3.new(0, 5, 0), centre + Vector3.new(0, 5, 0) + look),
		Vector3.new(inner * 2, 10, inner * 2),
		m
	)
	trigger:SetAttribute("Kind", trap.Kind)
	CollectionService:AddTag(trigger, Tags.ScareTrigger)
	if trap.Kind == "Scarecrow" then
		-- Half hidden in the corn, its glowing face peeking out.
		local base = centre + right * (inner + 1) + look * 1.5
		local actor = ScareActors.Scarecrow(CFrame.lookAt(base, base - right), m)
		actor:SetAttribute("ScareActor", true)
	end
end

local function buildPatrol(b: Builder, patrol: { From: Cell, To: Cell }, parent: Instance)
	local plan = b.Plan
	local inner = (plan.CellSize - plan.Thickness) / 2
	local a = cellPoint(b, patrol.From, 0)
	local c = cellPoint(b, patrol.To, 0)
	local mid = (a + c) / 2
	local m = Kit.model("ScareTrap", parent)
	m:SetAttribute("Kind", "Patrol")
	local trigger = Kit.holder(
		"Trigger",
		CFrame.lookAt(mid + Vector3.new(0, 5, 0), c + Vector3.new(0, 5, 0)),
		Vector3.new(inner * 2, 10, (c - a).Magnitude),
		m
	)
	trigger:SetAttribute("Kind", "Patrol")
	CollectionService:AddTag(trigger, Tags.ScareTrigger)
	local actor = ScareActors.Scarecrow(CFrame.lookAt(a, c), m)
	actor:SetAttribute("ScareActor", true)
end

-- The side of `cell` to hang a lantern on: a wall, best one beside the way through.
local function lanternSide(b: Builder, cell: Cell): string?
	local maze = b.Plan.Maze
	local order = { "E", "W", "N", "S" }
	if b.Rng:NextNumber() < 0.5 then
		order = { "W", "E", "S", "N" }
	end
	for _, side in order do
		if MazeGen.HasWall(maze, cell.X, cell.Y, side) then
			return side
		end
	end
	return nil
end

function ScareMaze.Build(def: any): Model
	local colors = def.Colors
	local ctx = MapBase.new(def, {
		FloorColor = colors.Floor,
		FloorMaterial = Enum.Material.Ground,
		WallColor = colors.Wall,
		WallMaterial = Enum.Material.WoodPlanks,
	})
	local model = ctx.Model
	local plan = ScareMaze.Plan(def)
	local b: Builder = {
		Ctx = ctx,
		Plan = plan,
		Colors = colors,
		Layout = def.Layout,
		Rng = ctx.Rng,
	}

	-- The spawn ring MapBase made is in the middle of the maze: Survivors start in the field.
	local spawns = model:FindFirstChild(def.SpawnFolder)
	assert(spawns, "MapBase made no spawn folder")
	for _, child in spawns:GetChildren() do
		child:Destroy()
	end

	local mazeModel = Kit.model("Maze", model)
	buildWalls(b, mazeModel)
	buildEntrance(b, model)
	buildExit(b, model)
	buildPlaza(b, spawns, model)
	buildYard(b, model)

	local traps = Kit.model("ScareTraps", model)
	for _, trap in plan.Traps do
		buildTrap(b, trap, traps)
	end
	for _, patrol in plan.Patrols do
		buildPatrol(b, patrol, traps)
	end

	local haunt = Instance.new("Folder")
	haunt.Name = "HauntSpawns"
	haunt.Parent = model
	for _, cell in plan.HauntCells do
		local spot = Kit.holder(
			"HauntSpawn",
			CFrame.new(cellPoint(b, cell, 0.5)),
			Vector3.new(4, 1, 4),
			haunt
		)
		CollectionService:AddTag(spot, Tags.HauntSpawn)
	end

	local lanterns = Kit.model("Lanterns", mazeModel)
	for _, cell in plan.Lanterns do
		local side = lanternSide(b, cell)
		if side then
			wallLantern(b, cell, side, lanterns)
		end
	end

	-- Decorations: pumpkins in dead ends, crows on the corn.
	local decor = Kit.model("Decor", mazeModel)
	local trapCells: { [string]: boolean } = {}
	for _, trap in plan.Traps do
		trapCells[key(trap.Cell)] = true
	end
	local lit = 0
	local placed = 0
	local inner = (plan.CellSize - plan.Thickness) / 2
	for _, cell in plan.DeadEnds do
		if placed >= def.Layout.Pumpkins then
			break
		end
		local gate = (cell.X == plan.Entrance.X and cell.Y == plan.Entrance.Y)
			or (cell.X == plan.Exit.X and cell.Y == plan.Exit.Y)
		if not trapCells[key(cell)] and not gate then
			-- Tucked into a corner against the dead end's back wall.
			local open: Vector3 = DIRS.N
			for _, name in DIR_ORDER do
				if not MazeGen.HasWall(plan.Maze, cell.X, cell.Y, name) then
					open = DIRS[name]
				end
			end
			local back = cellPoint(b, cell, 0) - open * (inner - 1.6)
			local across = open:Cross(Vector3.yAxis) * b.Rng:NextNumber(-2.5, 2.5)
			local glowing = lit < def.Layout.GlowingPumpkins
			pumpkin(
				b,
				CFrame.lookAt(back + across, back + across + open),
				b.Rng:NextNumber(1.6, 2.4),
				glowing,
				decor
			)
			if glowing then
				lit += 1
			end
			placed += 1
		end
	end
	local runs = MazeGen.WallRuns(plan.Maze)
	for _ = 1, math.min(def.Layout.Crows, #runs) do
		local run = runs[b.Rng:NextInteger(1, #runs)]
		local a = edgePoint(b, run.X0, run.Y0)
		local c = edgePoint(b, run.X1, run.Y1)
		local at = a:Lerp(c, b.Rng:NextNumber(0.15, 0.85))
		local top = def.Layout.CornHeight - 1.5 + plan.Thickness / 2 + 0.3
		crow(
			b,
			CFrame.new(at + Vector3.new(0, top, 0))
				* CFrame.Angles(0, b.Rng:NextNumber(0, math.pi * 2), 0),
			decor
		)
	end

	return model
end

return ScareMaze
