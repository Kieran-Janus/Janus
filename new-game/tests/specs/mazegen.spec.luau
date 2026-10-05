-- MazeGen: every maze is fully connected, rooms are open, wall runs match the walls.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local MazeGen = rt:require("ServerScriptService.Server.Maps.MazeGen")

local function wallCount(m): number
	local n = 0
	for x = 1, m.Width do
		for y = 1, m.Height do
			if x < m.Width and m.East[x][y] then
				n += 1
			end
			if y < m.Height and m.South[x][y] then
				n += 1
			end
		end
	end
	return n
end

describe("MazeGen", function()
	it("connects every cell, for many seeds and braid levels", function()
		for seed = 1, 25 do
			for _, braid in { 0, 0.4, 1 } do
				local m = MazeGen.Generate(
					12,
					9,
					seed,
					{ Braid = braid, Rooms = { { X = 5, Y = 4, W = 3, H = 3 } } }
				)
				for y = 1, m.Height do
					for x = 1, m.Width do
						if not MazeGen.Solve(m, { X = 1, Y = 1 }, { X = x, Y = y }) then
							error(
								("cell %d,%d unreachable (seed %d, braid %s)"):format(
									x,
									y,
									seed,
									tostring(braid)
								)
							)
						end
					end
				end
			end
		end
	end)

	it("opens every wall inside a room", function()
		local m = MazeGen.Generate(10, 10, 3, { Rooms = { { X = 4, Y = 4, W = 3, H = 2 } } })
		expect(MazeGen.HasWall(m, 4, 4, "E")).toBe(false)
		expect(MazeGen.HasWall(m, 5, 4, "S")).toBe(false)
	end)

	it("merges walls into runs that add up to the same wall length", function()
		for seed = 1, 10 do
			local m = MazeGen.Generate(15, 11, seed, { Braid = 0.3 })
			local fromRuns = 0
			for _, r in MazeGen.WallRuns(m) do
				fromRuns += (r.X1 - r.X0) + (r.Y1 - r.Y0)
			end
			expect(fromRuns).toBe(wallCount(m))
		end
	end)

	it("is the same maze for the same seed", function()
		local a = MazeGen.Generate(8, 8, 42)
		local b = MazeGen.Generate(8, 8, 42)
		expect(wallCount(a)).toBe(wallCount(b))
		for x = 1, 8 do
			for y = 1, 8 do
				expect(a.East[x][y]).toBe(b.East[x][y])
				expect(a.South[x][y]).toBe(b.South[x][y])
			end
		end
	end)

	it("leaves almost no dead ends at Braid = 1", function()
		local m = MazeGen.Generate(14, 14, 9, { Braid = 1 })
		expect(#MazeGen.DeadEnds(m) <= 2).toBe(true)
	end)
end)
