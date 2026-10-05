--!strict
--[[
	Maze generator shared by the maze maps (Hedge Maze for Hide & Seek, the ScareMaze).
	Pure maths, no parts: a map builder turns the result into walls.

	Cells are numbered x = 1..Width (west to east) and y = 1..Height (north to south).
	Between two neighbouring cells there is either a wall or a gap.

	  local maze = MazeGen.Generate(12, 12, seed, { Braid = 0.3, Rooms = { {X=5, Y=5, W=3, H=3} } })
	  MazeGen.HasWall(maze, x, y, "E")     -- wall on the east side of cell (x, y)?
	  MazeGen.Solve(maze, {X=1,Y=1}, {X=12,Y=12}) -- list of cells from start to finish, or nil
	  MazeGen.WallRuns(maze)               -- walls merged into long straight runs (fewer parts)

	Options:
	  Braid  0..1  share of dead ends that get opened up (0 = a perfect maze with exactly one
	               route between any two cells; higher = more loops, easier and better for
	               chases).
	  Rooms        open rectangles with no walls inside (spawn rooms, plazas). Their edges
	               stay connected to the maze.
	The same seed always gives the same maze.
]]

local MazeGen = {}

export type Cell = { X: number, Y: number }
export type Room = { X: number, Y: number, W: number, H: number }
export type Maze = {
	Width: number,
	Height: number,
	-- East[x][y]: wall between (x, y) and (x + 1, y). South[x][y]: wall between (x, y) and (x, y + 1).
	East: { { boolean } },
	South: { { boolean } },
}
export type Run = {
	-- A straight wall in cell-edge coordinates: from (X0, Y0) to (X1, Y1), where the edge
	-- coordinates go from 0 (the west/north border) to Width/Height (the east/south border).
	X0: number,
	Y0: number,
	X1: number,
	Y1: number,
}
export type Options = { Braid: number?, Rooms: { Room }? }

local DIRS = {
	{ Name = "N", DX = 0, DY = -1 },
	{ Name = "S", DX = 0, DY = 1 },
	{ Name = "E", DX = 1, DY = 0 },
	{ Name = "W", DX = -1, DY = 0 },
}

local function inRoom(rooms: { Room }, x: number, y: number): boolean
	for _, r in rooms do
		if x >= r.X and x < r.X + r.W and y >= r.Y and y < r.Y + r.H then
			return true
		end
	end
	return false
end

local function setWall(maze: Maze, x: number, y: number, dir: string, value: boolean)
	if dir == "E" then
		if x < maze.Width then
			maze.East[x][y] = value
		end
	elseif dir == "W" then
		if x > 1 then
			maze.East[x - 1][y] = value
		end
	elseif dir == "S" then
		if y < maze.Height then
			maze.South[x][y] = value
		end
	elseif dir == "N" then
		if y > 1 then
			maze.South[x][y - 1] = value
		end
	end
end

-- Is there a wall on side `dir` of cell (x, y)? The outer border always counts as a wall.
function MazeGen.HasWall(maze: Maze, x: number, y: number, dir: string): boolean
	if dir == "E" then
		return x >= maze.Width or maze.East[x][y]
	elseif dir == "W" then
		return x <= 1 or maze.East[x - 1][y]
	elseif dir == "S" then
		return y >= maze.Height or maze.South[x][y]
	elseif dir == "N" then
		return y <= 1 or maze.South[x][y - 1]
	end
	return true
end

local function openSides(maze: Maze, x: number, y: number): number
	local n = 0
	for _, d in DIRS do
		if not MazeGen.HasWall(maze, x, y, d.Name) then
			n += 1
		end
	end
	return n
end

function MazeGen.Generate(width: number, height: number, seed: number, options: Options?): Maze
	assert(width >= 2 and height >= 2, "MazeGen: a maze needs at least 2 x 2 cells")
	local opts: Options = options or {}
	local rooms: { Room } = opts.Rooms or {}
	local rng = Random.new(seed)

	local maze: Maze = { Width = width, Height = height, East = {}, South = {} }
	for x = 1, width do
		maze.East[x] = {}
		maze.South[x] = {}
		for y = 1, height do
			maze.East[x][y] = true
			maze.South[x][y] = true
		end
	end

	-- Rooms: knock down every wall inside them.
	for _, r in rooms do
		for x = r.X, r.X + r.W - 1 do
			for y = r.Y, r.Y + r.H - 1 do
				if x < r.X + r.W - 1 then
					setWall(maze, x, y, "E", false)
				end
				if y < r.Y + r.H - 1 then
					setWall(maze, x, y, "S", false)
				end
			end
		end
	end

	-- Recursive backtracker (iterative). A whole room counts as visited once any cell of it
	-- is reached, so each room joins the maze through exactly one doorway (plus braiding).
	local visited: { [number]: boolean } = {}
	local function key(x: number, y: number): number
		return (y - 1) * width + x
	end
	local function visit(x: number, y: number)
		visited[key(x, y)] = true
		for _, r in rooms do
			if x >= r.X and x < r.X + r.W and y >= r.Y and y < r.Y + r.H then
				for rx = r.X, r.X + r.W - 1 do
					for ry = r.Y, r.Y + r.H - 1 do
						visited[key(rx, ry)] = true
					end
				end
			end
		end
	end

	local stack: { Cell } = { { X = 1, Y = 1 } }
	visit(1, 1)
	while #stack > 0 do
		local cell = stack[#stack]
		local options2 = {}
		for _, d in DIRS do
			local nx, ny = cell.X + d.DX, cell.Y + d.DY
			if
				nx >= 1
				and nx <= width
				and ny >= 1
				and ny <= height
				and not visited[key(nx, ny)]
			then
				table.insert(options2, d)
			end
		end
		if #options2 == 0 then
			table.remove(stack)
		else
			local d = options2[rng:NextInteger(1, #options2)]
			local nx, ny = cell.X + d.DX, cell.Y + d.DY
			setWall(maze, cell.X, cell.Y, d.Name, false)
			visit(nx, ny)
			table.insert(stack, { X = nx, Y = ny })
		end
	end

	-- Braid: open a share of the dead ends into a random walled neighbour.
	local braid = math.clamp(opts.Braid or 0, 0, 1)
	if braid > 0 then
		for y = 1, height do
			for x = 1, width do
				if
					not inRoom(rooms, x, y)
					and openSides(maze, x, y) == 1
					and rng:NextNumber() < braid
				then
					local walled = {}
					for _, d in DIRS do
						local nx, ny = x + d.DX, y + d.DY
						if
							nx >= 1
							and nx <= width
							and ny >= 1
							and ny <= height
							and MazeGen.HasWall(maze, x, y, d.Name)
						then
							table.insert(walled, d)
						end
					end
					if #walled > 0 then
						setWall(maze, x, y, walled[rng:NextInteger(1, #walled)].Name, false)
					end
				end
			end
		end
	end
	return maze
end

-- Shortest route between two cells (breadth-first), as a list of cells including both ends.
function MazeGen.Solve(maze: Maze, from: Cell, to: Cell): { Cell }?
	local width = maze.Width
	local function key(x: number, y: number): number
		return (y - 1) * width + x
	end
	local cameFrom: { [number]: number } = {}
	local queue: { Cell } = { from }
	local head = 1
	cameFrom[key(from.X, from.Y)] = 0
	while head <= #queue do
		local c = queue[head]
		head += 1
		if c.X == to.X and c.Y == to.Y then
			local path: { Cell } = {}
			local k = key(c.X, c.Y)
			while k ~= 0 do
				local x = (k - 1) % width + 1
				local y = (k - x) // width + 1
				table.insert(path, 1, { X = x, Y = y })
				k = cameFrom[k]
			end
			return path
		end
		for _, d in DIRS do
			local nx, ny = c.X + d.DX, c.Y + d.DY
			if not MazeGen.HasWall(maze, c.X, c.Y, d.Name) and cameFrom[key(nx, ny)] == nil then
				cameFrom[key(nx, ny)] = key(c.X, c.Y)
				table.insert(queue, { X = nx, Y = ny })
			end
		end
	end
	return nil
end

-- Cells with exactly one way out (good spots for hiding places, scares and treasure).
function MazeGen.DeadEnds(maze: Maze): { Cell }
	local list: { Cell } = {}
	for y = 1, maze.Height do
		for x = 1, maze.Width do
			if openSides(maze, x, y) == 1 then
				table.insert(list, { X = x, Y = y })
			end
		end
	end
	return list
end

--[[
	Every inner wall merged into straight runs (the outer border is not included: build it
	as four long walls). Horizontal runs lie on edge line y = Y0 = Y1, vertical ones on
	x = X0 = X1.
]]
function MazeGen.WallRuns(maze: Maze): { Run }
	local runs: { Run } = {}
	-- Horizontal walls: South[x][y] sits on edge line y between columns x - 1 and x.
	for y = 1, maze.Height - 1 do
		local start: number? = nil
		for x = 1, maze.Width + 1 do
			local wall = x <= maze.Width and maze.South[x][y]
			if wall and start == nil then
				start = x - 1
			elseif not wall and start ~= nil then
				table.insert(runs, { X0 = start, Y0 = y, X1 = x - 1, Y1 = y })
				start = nil
			end
		end
	end
	-- Vertical walls: East[x][y] sits on edge line x between rows y - 1 and y.
	for x = 1, maze.Width - 1 do
		local start: number? = nil
		for y = 1, maze.Height + 1 do
			local wall = y <= maze.Height and maze.East[x][y]
			if wall and start == nil then
				start = y - 1
			elseif not wall and start ~= nil then
				table.insert(runs, { X0 = x, Y0 = start, X1 = x, Y1 = y - 1 })
				start = nil
			end
		end
	end
	return runs
end

return MazeGen
