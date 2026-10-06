-- The Tormented Tower (Config.TowerParkour): the course maths in src/shared/TowerLogic.luau
-- (every jump checked with the ParkourLogic jump model, sprint jumps really need sprinting),
-- the built tower (hollow, tagged pieces, inside the walls, a custom ClockTower), the server
-- (TowerService: start, checkpoints in order, falls, slime, anti-teleport, the minimum time,
-- the exclusive skin given once, the announcement, admin buttons) and the timer UI.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local shared = Runtime.new()
local Config = shared:require("ReplicatedStorage.Shared.Config")
local TowerLogic = shared:require("ReplicatedStorage.Shared.TowerLogic")
local ParkourLogic = shared:require("ReplicatedStorage.Shared.ParkourLogic")
local cfg = Config.TowerParkour

local function jumpsOf(course: { any }): { number }
	local list = {}
	for i, step in course do
		if TowerLogic.IsJumpStep(step) then
			table.insert(list, i)
		end
	end
	return list
end

describe("Config.TowerParkour.Course", function()
	local course = cfg.Course
	local floors = TowerLogic.Floors()

	it("passes every check: jumps, head room, inside the walls, under the roof", function()
		local problems = TowerLogic.Check(course, floors)
		for _, p in problems do
			T.note(p)
		end
		expect(#problems).toBe(0)
	end)

	it("is really hard: about 24 jumps, only 3 checkpoints, every kind of trap", function()
		local jumps = jumpsOf(course)
		expect(#jumps - 1).toBeGreaterThanOrEqual(20)
		expect(#jumps - 1).toBeLessThanOrEqual(30)
		local counts: { [string]: number } = {}
		for _, step in course do
			counts[step.Kind] = (counts[step.Kind] or 0) + 1
		end
		expect(counts.Checkpoint).toBe(3)
		for _, kind in { "Tiny", "Beam", "Truss", "Vanish", "Spinner", "Gear", "Hazard" } do
			expect(counts[kind] or 0).toBeGreaterThan(0)
		end
		T.note(("%d jumps"):format(#jumps - 1))
	end)

	it("has long jumps that need sprinting (too far walking, fine sprinting)", function()
		local jumps = jumpsOf(course)
		local sprints = 0
		local walkSpeed = Config.Parkour.Jumps.Character.WalkSpeed
		for k = 2, #jumps do
			local ia, ib = jumps[k - 1], jumps[k]
			local a, b = course[ia], course[ib]
			local cfA = TowerLogic.StepCFrame(course, ia, floors)
			local cfB = TowerLogic.StepCFrame(course, ib, floors)
			local gap, rise = TowerLogic.Jump(a, cfA, b, cfB)
			local height = TowerLogic.JumpHeight(
				course,
				jumps,
				(function()
					local all = {}
					for i in course do
						all[i] = TowerLogic.StepCFrame(course, i, floors)
					end
					return all
				end)(),
				ia,
				ib
			)
			if b.Sprint then
				sprints += 1
				-- Walking can't make it (even at full stretch)...
				expect(gap).toBeGreaterThan(
					ParkourLogic.Reach(rise, walkSpeed, height) * cfg.Jumps.Safety
				)
				-- ...sprinting can.
				expect(gap).toBeLessThanOrEqual(
					ParkourLogic.Reach(rise, Config.Player.SprintSpeed, height)
						* cfg.Jumps.SprintSafety
				)
			end
		end
		expect(sprints).toBeGreaterThanOrEqual(2)
	end)

	it("explains a broken course", function()
		local V3 = shared.env.Vector3
		local broken = table.clone(course)
		broken[2] = table.clone(broken[2])
		broken[2].Offset = broken[2].Offset + V3.new(0, 0, 30) -- through the wall
		expect(table.concat(TowerLogic.Check(broken, floors), " ")).toMatch("wall")
		local far = {
			{ Kind = "Start", Offset = V3.new(-6.5, 0.5, 0) },
			{ Kind = "Tiny", Offset = V3.new(7.5, 0.5, 0) }, -- 10.7 studs away, walking
			{ Kind = "Checkpoint", Offset = V3.new(-4, 1, 7) },
			{ Kind = "Finish", Offset = V3.new(-4, 2, 0) },
		}
		expect(table.concat(TowerLogic.Check(far, floors), " ")).toMatch("without Sprint")
		-- A low piece over a jump cuts it short.
		local low = {
			{ Kind = "Start", Offset = V3.new(0, 0.5, -4) },
			{ Kind = "Ledge", Offset = V3.new(0, 1.5, 1) },
			{ Kind = "Ledge", Offset = V3.new(0, 7.5, -1.5) }, -- just over your head
			{ Kind = "Checkpoint", Offset = V3.new(-5, 9, -1.5) },
			{ Kind = "Finish", Offset = V3.new(-5, 10, 4) },
		}
		local height = TowerLogic.JumpHeight(
			low,
			{ 1, 2, 3, 4, 5 },
			(function()
				local all = {}
				for i in low do
					all[i] = TowerLogic.StepCFrame(low, i, floors)
				end
				return all
			end)(),
			1,
			2
		)
		expect(height).toBeLessThan(Config.Parkour.Jumps.Character.JumpHeight)
	end)

	it("follows the tower: floors lean and twist like Config.Hub.ClockTower", function()
		local tower = Config.Hub.ClockTower
		expect(#floors).toBe(tower.Floors)
		for i = 2, #floors do
			local rise = (floors[i].CFrame.Position - floors[i - 1].CFrame.Position).Magnitude
			expect(rise).toBeNear(tower.FloorHeight, 0.01)
			expect(floors[i].Width).toBeLessThan(floors[i - 1].Width)
		end
	end)
end)
