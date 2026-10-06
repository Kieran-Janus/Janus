--!strict
--[[
	Tormented Tower maths (Config.TowerParkour), shared by the tower builder
	(src/server/Hub/HubBuilder.luau and Sections/TormentedTower.luau), the server
	(TowerService) and the tests (tests/specs/tower.spec.luau). Nothing here changes the game.

	The clock tower (Config.Hub.ClockTower) is a stack of Floors, each FloorHeight tall, each a
	little narrower than the one below, turned by Twist and tipped by Lean. Everything here works
	out from Config only, never from the tower's parts, so the course stays put when the
	ClockTower prop is swapped for a custom model.

	TowerLogic.Base() -> CFrame              the tower's base (ground level, facing the plaza)
	TowerLogic.Floors(base?) -> { Floor }    each floor's bottom middle (CFrame) and Width
	TowerLogic.Spine(up, floors) -> (CFrame, Floor)
	        the middle of the tower `up` studs above the inside floor, turned so +X is "right"
	        seen from the plaza and -Z points away from the door (course space, like the lobby
	        parkour)
	TowerLogic.InsideHalf(floor) -> number   studs from the middle to the inside of the walls,
	                                         minus Walls.Clearance
	TowerLogic.SizeOf(step) -> Vector3       its Size, or the Kind's default size
	TowerLogic.StepCFrame(course, i, floors) -> CFrame   top middle of piece i, level, in world
	TowerLogic.Jump(a, cfA, b, cfB) -> (gap, rise)       edge to edge (a Truss is grabbed low)
	TowerLogic.JumpHeight(course, jumps, cframes, ia, ib) -> number   how high that jump can go
	                                         before your head bumps a piece above
	TowerLogic.Check(course, floors?) -> { string }      problems (empty = all fine)
	TowerLogic.IsJumpStep(step) -> boolean   everything but Hazard
]]

local Config = require(script.Parent.Config)
local ParkourLogic = require(script.Parent.ParkourLogic)

local TowerLogic = {}

export type Step = {
	Kind: string,
	Offset: Vector3,
	Size: Vector3?,
	Rotation: number?,
	Sprint: boolean?,
	Label: string?,
}

export type Floor = {
	Index: number,
	CFrame: CFrame, -- the bottom middle of this floor (with its lean and twist)
	Width: number, -- outside width
}

TowerLogic.Kinds = {
	"Start",
	"Ledge",
	"Tiny",
	"Beam",
	"Truss",
	"Vanish",
	"Spinner",
	"Gear",
	"Checkpoint",
	"Finish",
	"Hazard",
}

local ROUND: { [string]: boolean } = { Gear = true, Checkpoint = true, Finish = true }

-- The steps up to the tower's inside floor (the built tower stands on two 0.8 stud steps).
TowerLogic.FloorLift = 1.6

local function cfg()
	return Config.TowerParkour
end

function TowerLogic.IsJumpStep(step: Step): boolean
	return step.Kind ~= "Hazard"
end

function TowerLogic.Base(): CFrame
	local tower = Config.Hub.ClockTower
	local center: Vector3 = Config.Hub.Center
	local position = center + tower.Offset + Vector3.new(0, 1, 0)
	local target = Vector3.new(center.X, position.Y, center.Z)
	if (target - position).Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, target)
end

function TowerLogic.Floors(base: CFrame?): { Floor }
	local tower = Config.Hub.ClockTower
	local cf = (base or TowerLogic.Base()) * CFrame.new(0, TowerLogic.FloorLift, 0)
	local floors: { Floor } = {}
	for i = 1, tower.Floors do
		floors[i] = {
			Index = i,
			CFrame = cf,
			Width = tower.Width * (1 - 0.05 * (i - 1)),
		}
		local turn = if i % 2 == 0 then tower.Twist else -tower.Twist
		cf = cf
			* CFrame.new(0, tower.FloorHeight, 0)
			* CFrame.Angles(0, math.rad(turn), math.rad(tower.Lean))
	end
	return floors
end

function TowerLogic.InsideHalf(floor: Floor): number
	local walls = cfg().Walls
	return floor.Width / 2 - walls.Thickness - walls.Clearance
end

function TowerLogic.Spine(up: number, floors: { Floor }): (CFrame, Floor)
	local height = Config.Hub.ClockTower.FloorHeight
	local index = math.clamp(math.floor(up / height) + 1, 1, #floors)
	local floor = floors[index]
	local local_ = up - (index - 1) * height
	return floor.CFrame * CFrame.new(0, local_, 0) * CFrame.Angles(0, math.pi, 0), floor
end

function TowerLogic.SizeOf(step: Step): Vector3
	if typeof(step.Size) == "Vector3" then
		return step.Size :: Vector3
	end
	local default = (cfg().Sizes :: any)[step.Kind]
	return if typeof(default) == "Vector3" then default else Vector3.new(3, 1, 3)
end

-- The piece as a lobby-parkour step, so ParkourLogic's jump maths can measure it.
local function asParkour(step: Step): ParkourLogic.Step
	return {
		Kind = if ROUND[step.Kind] then "Candy" else "Platform",
		Offset = step.Offset,
		Size = TowerLogic.SizeOf(step),
	}
end

-- Flat yaw of a frame (its lean and tip taken out), at `position`.
local function level(frame: CFrame, position: Vector3): CFrame
	local look = frame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

function TowerLogic.StepCFrame(course: { Step }, i: number, floors: { Floor }): CFrame
	local step = course[i]
	local o = step.Offset
	local spine = TowerLogic.Spine(o.Y, floors)
	local position = (spine * CFrame.new(o.X, 0, -o.Z)).Position
	local turn = if type(step.Rotation) == "number" then step.Rotation else 0
	return level(spine, position) * CFrame.Angles(0, math.rad(turn), 0)
end

function TowerLogic.Jump(a: Step, cfA: CFrame, b: Step, cfB: CFrame): (number, number)
	local gap, rise = ParkourLogic.Jump(asParkour(a), cfA, asParkour(b), cfB)
	if b.Kind == "Truss" then
		-- You grab a truss low down (about where your hands are) and climb it.
		local bottom = cfB.Position.Y - TowerLogic.SizeOf(b).Y
		rise = math.max(bottom + 1, cfA.Position.Y - 4) - cfA.Position.Y
	end
	return gap, rise
end

--[[
	How high you can jump from course[ia] to course[ib] before your head bumps a piece hanging
	over the way (Config.Parkour.Jumps.Character.JumpHeight when nothing is in the way). A piece
	counts when it is over the line between the two, or over where you stand on either; its
	bottom is SizeOf(piece).Y below its top; your head is Jumps.BodyHeight above your feet.
]]
function TowerLogic.JumpHeight(
	course: { Step },
	jumps: { number },
	cframes: { [number]: CFrame },
	ia: number,
	ib: number
): number
	local rules = cfg().Jumps
	local full = Config.Parkour.Jumps.Character.JumpHeight
	local pa, pb = cframes[ia].Position, cframes[ib].Position
	local takeoff = pa.Y
	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local function radius(step: Step): number
		local size = TowerLogic.SizeOf(step)
		return math.max(size.X, size.Z) / 2
	end
	local ab = flat(pb) - flat(pa)
	local height = full
	for _, ic in jumps do
		if ic == ia or ic == ib then
			continue
		end
		local c = course[ic]
		local pc = cframes[ic].Position
		local bottom = pc.Y - TowerLogic.SizeOf(c).Y
		if pc.Y <= math.min(pa.Y, pb.Y) then
			continue -- below you
		end
		local rel = flat(pc) - flat(pa)
		local t = if ab.Magnitude > 1e-6 then math.clamp(rel:Dot(ab) / ab:Dot(ab), 0, 1) else 0
		local toLine = (rel - ab * t).Magnitude
		local rc = radius(c)
		local over = toLine < rc + rules.HeadroomMargin
			or (flat(pc) - flat(pa)).Magnitude < rc + radius(course[ia])
			or (flat(pc) - flat(pb)).Magnitude < rc + radius(course[ib])
		if over then
			height = math.min(height, bottom - takeoff - rules.BodyHeight)
		end
	end
	return math.max(height, 0)
end

local function stepName(course: { Step }, i: number): string
	local step = course[i]
	return ("Step%02d_%s"):format(i, tostring(step and step.Kind))
end
TowerLogic.StepName = stepName

function TowerLogic.Check(course: { Step }, floorsIn: { Floor }?): { string }
	local rules = cfg().Jumps
	local problems: { string } = {}
	local function add(text: string)
		table.insert(problems, text)
	end
	if type(course) ~= "table" or #course == 0 then
		add("Config.TowerParkour.Course is empty.")
		return problems
	end
	local floors = floorsIn or TowerLogic.Floors()
	local counts: { [string]: number } = {}
	for i, step in course do
		if type(step) ~= "table" or not table.find(TowerLogic.Kinds, step.Kind) then
			add(("Line %d of the tower course has an unknown Kind."):format(i))
			return problems
		end
		if typeof(step.Offset) ~= "Vector3" then
			add(("%s has no Offset (a Vector3)."):format(stepName(course, i)))
			return problems
		end
		counts[step.Kind] = (counts[step.Kind] or 0) + 1
	end
	local jumps: { number } = {}
	for i, step in course do
		if TowerLogic.IsJumpStep(step) then
			table.insert(jumps, i)
		end
	end
	if course[jumps[1]].Kind ~= "Start" or counts.Start ~= 1 then
		add("The tower course needs exactly one Start, first.")
	end
	if course[jumps[#jumps]].Kind ~= "Finish" or counts.Finish ~= 1 then
		add("The tower course needs exactly one Finish, last.")
	end
	if (counts.Checkpoint or 0) < 1 then
		add("The tower course needs at least one Checkpoint.")
	end

	local cframes: { [number]: CFrame } = {}
	for i in course do
		cframes[i] = TowerLogic.StepCFrame(course, i, floors)
	end

	-- Every jump: not too far, not too high (a Sprint jump may use the sprinting reach). A piece
	-- hanging low over a jump cuts the jump short (you bump your head), so it reaches less far.
	local walk = Config.Parkour.Jumps.Character.WalkSpeed
	local sprint = Config.Player.SprintSpeed
	for k = 2, #jumps do
		local ia, ib = jumps[k - 1], jumps[k]
		local a, b = course[ia], course[ib]
		local gap, rise = TowerLogic.Jump(a, cframes[ia], b, cframes[ib])
		local name = stepName(course, ib)
		local height = TowerLogic.JumpHeight(course, jumps, cframes, ia, ib)
		local reach = if b.Sprint
			then ParkourLogic.Reach(rise, sprint, height) * rules.SprintSafety
			else ParkourLogic.Reach(rise, walk, height) * rules.Safety
		if gap > rules.MaxGap + 1e-6 then
			add(
				("%s: the jump to it is %.1f studs across (most allowed: %.1f)."):format(
					name,
					gap,
					rules.MaxGap
				)
			)
		end
		if rise > rules.MaxRise + 1e-6 then
			add(
				("%s is %.1f studs higher than the piece before (most allowed: %.1f)."):format(
					name,
					rise,
					rules.MaxRise
				)
			)
		end
		if gap > reach + 1e-6 then
			add(
				("%s: a %.1f stud jump going %.1f up can't be made%s (about %.1f is the most)."):format(
					name,
					gap,
					rise,
					if b.Sprint then " even sprinting" else " without Sprint = true",
					reach
				)
			)
		end
		if gap < rules.MinGap - 1e-6 then
			add(("%s overlaps the piece before it."):format(name))
		end
	end

	-- Inside the walls (in the floor each piece is on), with room for spinning bars, and
	-- under the roof.
	local height = Config.Hub.ClockTower.FloorHeight
	for i, step in course do
		local o = step.Offset
		local _, floor = TowerLogic.Spine(o.Y, floors)
		local half = TowerLogic.InsideHalf(floor)
		local size = TowerLogic.SizeOf(step)
		local turn = math.rad(if type(step.Rotation) == "number" then step.Rotation else 0)
		local ex = math.abs(math.cos(turn)) * size.X / 2 + math.abs(math.sin(turn)) * size.Z / 2
		local ez = math.abs(math.sin(turn)) * size.X / 2 + math.abs(math.cos(turn)) * size.Z / 2
		if step.Kind == "Spinner" then
			local sweep = cfg().Spinner.Length / 2
			ex, ez = math.max(ex, sweep), math.max(ez, sweep)
		end
		if math.abs(o.X) + ex > half + 1e-6 or math.abs(o.Z) + ez > half + 1e-6 then
			add(
				("%s pokes through the tower wall (keep it %.1f studs from the middle)."):format(
					stepName(course, i),
					half
				)
			)
		end
		if o.Y > #floors * height - 7 then
			add(("%s is too close to the tower's roof."):format(stepName(course, i)))
		end
		if o.Y < 0 then
			add(("%s is below the tower's inside floor."):format(stepName(course, i)))
		end
	end
	return problems
end

return TowerLogic
