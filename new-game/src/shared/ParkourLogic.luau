--!strict
--[[
	Parkour maths, shared by the course builder (src/server/Hub/Sections/Parkour.luau), the
	server (src/server/Services/ParkourService.luau), the screen (src/client/ParkourUI.luau)
	and the tests (tests/specs/parkour.spec.luau). Nothing in here changes the game.

	Course space (how Config.Parkour.Course is written): Offset = Vector3.new(right, up, back)
	  right  studs to the right of the zone's middle, seen from the plaza (negative = left)
	  up     height of the piece's TOP (where you stand) above the plaza
	  back   studs further away from the plaza (negative = closer)
	In code that is the CFrame course space: X right, Y up, -Z back (Roblox's "forward").

	Course geometry:
	  ParkourLogic.StepCFrame(course, i) -> CFrame     top middle of step i, in course space
	  ParkourLogic.CourseFrame(zoneCFrame) -> CFrame   course space -> world
	  ParkourLogic.SizeOf(step) -> Vector3             its Size, or the Kind's default size
	  ParkourLogic.Footprint(step) -> Footprint        the part of its top you can stand on
	  ParkourLogic.Jump(a, cfA, b, cfB) -> (gap, rise) edge-to-edge gap and height change
	  ParkourLogic.Reach(rise) -> number               longest gap a character can jump
	  ParkourLogic.Check(course, zoneSize?) -> { string }   problems (empty list = all fine)
	Parts:
	  ParkourLogic.TopY(cframe, size) -> number        height of a part's top face
	Runs:
	  ParkourLogic.Order(indices) -> { number }        checkpoint order (sorted, no repeats)
	  ParkourLogic.Touch(order, reached, index) -> "Next" | "Old" | "Skipped"
	  ParkourLogic.CanFinish(order, reached) -> boolean
	  ParkourLogic.IsNewBest(best, time) -> boolean
	  ParkourLogic.RewardWait(lastReward, now, hours) -> number   seconds until coins again
	  ParkourLogic.FormatTime(seconds) -> "1:05.32"
	  ParkourLogic.FormatWait(seconds) -> "5h 12m"
]]

local Config = require(script.Parent.Config)

local ParkourLogic = {}

export type Step = {
	Kind: string,
	Offset: Vector3,
	Size: Vector3?,
	Rotation: (Vector3 | number)?,
	Spicy: boolean?,
	Label: string?,
	Text: string?,
}

export type Footprint = {
	Shape: string, -- "Box" or "Round"
	HalfX: number, -- half its width (across)
	HalfZ: number, -- half its depth (along)
}

-- Kinds you jump on. Hazard is the only kind that is not part of the jumping line.
ParkourLogic.Kinds = {
	"Start",
	"Pumpkin",
	"Grave",
	"Broom",
	"Candy",
	"Bat",
	"Platform",
	"Checkpoint",
	"Finish",
	"Hazard",
}

local ROUND: { [string]: boolean } = {
	Pumpkin = true,
	Candy = true,
	Checkpoint = true,
	Finish = true,
}

-- Kinds that face the next piece when they have no Rotation (so a teleport faces the way on).
local AUTO_FACE: { [string]: boolean } = { Checkpoint = true }

local function isKind(kind: unknown): boolean
	return type(kind) == "string" and table.find(ParkourLogic.Kinds, kind) ~= nil
end

function ParkourLogic.IsJumpStep(step: Step): boolean
	return step.Kind ~= "Hazard"
end

function ParkourLogic.SizeOf(step: Step): Vector3
	if typeof(step.Size) == "Vector3" then
		return step.Size :: Vector3
	end
	local default = (Config.Parkour.Sizes :: any)[step.Kind]
	return if typeof(default) == "Vector3" then default else Vector3.new(6, 1, 6)
end

-- Rotation as written in Config: Vector3 degrees like Studio's Orientation (tip, turn, lean)
-- or just a number (turn only).
function ParkourLogic.Rotation(rotation: unknown): CFrame
	if typeof(rotation) == "Vector3" then
		local r = rotation :: Vector3
		return CFrame.fromEulerAnglesYXZ(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	elseif type(rotation) == "number" then
		return CFrame.Angles(0, math.rad(rotation), 0)
	end
	return CFrame.identity
end

local function position(step: Step): Vector3
	local o = step.Offset
	return Vector3.new(o.X, o.Y, -o.Z)
end

-- The next (or previous, dir = -1) step you jump on, from step i.
local function neighbour(course: { Step }, i: number, dir: number): Step?
	local j = i + dir
	while course[j] do
		if ParkourLogic.IsJumpStep(course[j]) then
			return course[j]
		end
		j += dir
	end
	return nil
end

--[[
	The top middle of course[i] in course space, turned by its Rotation. Not turned, its front
	(-Z) points away from the plaza and its back (+Z, where faces and writing go) at the
	plaza. A Checkpoint without a Rotation faces the next piece instead, so players sent
	back to it face the right way.
]]
function ParkourLogic.StepCFrame(course: { Step }, i: number): CFrame
	local step = course[i]
	local pos = position(step)
	if step.Rotation ~= nil then
		return CFrame.new(pos) * ParkourLogic.Rotation(step.Rotation)
	end
	local nextStep = if AUTO_FACE[step.Kind] then neighbour(course, i, 1) else nil
	if nextStep then
		local target = position(nextStep)
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		if flat.Magnitude > 1e-3 then
			return CFrame.lookAt(pos, pos + flat)
		end
	end
	return CFrame.new(pos)
end

-- Course space -> world: the zone's CFrame turned around, so +X is "right" seen from the
-- plaza and -Z points away from the plaza.
function ParkourLogic.CourseFrame(zoneCFrame: CFrame): CFrame
	return zoneCFrame * CFrame.Angles(0, math.pi, 0)
end

function ParkourLogic.Footprint(step: Step): Footprint
	local size = ParkourLogic.SizeOf(step)
	local scale = if step.Kind == "Pumpkin" then Config.Parkour.Look.PumpkinTop else 1
	return {
		Shape = if ROUND[step.Kind] then "Round" else "Box",
		HalfX = size.X * scale / 2,
		HalfZ = size.Z * scale / 2,
	}
end

-- How far (flat studs) from the middle of a footprint to its edge, going along `dir`.
local function edgeDistance(step: Step, cf: CFrame, dir: Vector3): number
	local f = ParkourLogic.Footprint(step)
	local l = cf:VectorToObjectSpace(dir)
	local lx, lz = math.abs(l.X), math.abs(l.Z)
	if f.Shape == "Round" then
		local k = (lx / f.HalfX) ^ 2 + (lz / f.HalfZ) ^ 2
		return if k > 0 then 1 / math.sqrt(k) else math.huge
	end
	local tx = if lx > 1e-6 then f.HalfX / lx else math.huge
	local tz = if lz > 1e-6 then f.HalfZ / lz else math.huge
	return math.min(tx, tz)
end

-- Height of a (maybe tilted) top at a flat offset from its middle.
local function heightAt(cf: CFrame, flat: Vector3): number
	local n = cf.UpVector
	if math.abs(n.Y) < 1e-3 then
		return cf.Position.Y
	end
	return cf.Position.Y - (n.X * flat.X + n.Z * flat.Z) / n.Y
end

--[[
	The jump from step a (top at cfA) to step b (top at cfB), both in course space:
	gap  = flat studs between a's edge and b's edge along the line between their middles
	       (negative when they overlap)
	rise = how much higher b's edge is than a's (negative = jumping down)
]]
function ParkourLogic.Jump(a: Step, cfA: CFrame, b: Step, cfB: CFrame): (number, number)
	local d = cfB.Position - cfA.Position
	local flat = Vector3.new(d.X, 0, d.Z)
	local distance = flat.Magnitude
	if distance < 1e-3 then
		return -math.huge, cfB.Position.Y - cfA.Position.Y
	end
	local dir = flat / distance
	local out = edgeDistance(a, cfA, dir)
	local into = edgeDistance(b, cfB, -dir)
	local rise = heightAt(cfB, -dir * into) - heightAt(cfA, dir * out)
	return distance - out - into, rise
end

--[[
	The longest flat gap a normal character can jump when the landing is `rise` studs higher
	(Config.Parkour.Jumps.Character: walking speed, jump height, gravity). 0 = too high.
]]
function ParkourLogic.Reach(rise: number): number
	local c = Config.Parkour.Jumps.Character
	if rise >= c.JumpHeight then
		return 0
	end
	local up = math.sqrt(2 * c.JumpHeight / c.Gravity)
	local down = math.sqrt(2 * (c.JumpHeight - rise) / c.Gravity)
	return c.WalkSpeed * (up + down) + c.Body
end

local function stepName(course: { Step }, i: number): string
	local step = course[i]
	return ("Step%02d_%s"):format(i, tostring(step and step.Kind))
end
ParkourLogic.StepName = stepName

--[[
	Everything that could make the course broken or too hard, as readable sentences (empty =
	all fine). zoneSize = (width, height, depth) of Config.Lobby.Zones.Parkour, to also check
	that every piece fits inside it.
]]
function ParkourLogic.Check(course: { Step }, zoneSize: Vector3?): { string }
	local rules = Config.Parkour.Jumps
	local problems: { string } = {}
	local function add(text: string)
		table.insert(problems, text)
	end
	if type(course) ~= "table" or #course == 0 then
		add("Config.Parkour.Course is empty.")
		return problems
	end
	local counts: { [string]: number } = {}
	local valid = true
	for i, step in course do
		if type(step) ~= "table" or not isKind(step.Kind) then
			add(
				("Line %d of the course has an unknown Kind (%s). Use one of: %s."):format(
					i,
					tostring(type(step) == "table" and step.Kind),
					table.concat(ParkourLogic.Kinds, ", ")
				)
			)
			valid = false
			continue
		end
		if typeof(step.Offset) ~= "Vector3" then
			add(("%s has no Offset (a Vector3)."):format(stepName(course, i)))
			valid = false
		end
		if step.Size ~= nil then
			local size = step.Size
			if typeof(size) ~= "Vector3" or size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
				add(("%s: Size must be a Vector3 bigger than 0."):format(stepName(course, i)))
				valid = false
			end
		end
		if
			step.Rotation ~= nil
			and typeof(step.Rotation) ~= "Vector3"
			and type(step.Rotation) ~= "number"
		then
			add(("%s: Rotation must be a number or a Vector3."):format(stepName(course, i)))
			valid = false
		end
		counts[step.Kind] = (counts[step.Kind] or 0) + 1
	end
	if not valid then
		return problems
	end
	local jumps: { number } = {}
	for i, step in course do
		if ParkourLogic.IsJumpStep(step) then
			table.insert(jumps, i)
		end
	end
	if course[jumps[1]].Kind ~= "Start" then
		add("The first piece of the course must be the Start.")
	end
	if course[jumps[#jumps]].Kind ~= "Finish" then
		add("The last piece of the course must be the Finish.")
	end
	if counts.Start ~= 1 then
		add(("The course needs exactly one Start (it has %d)."):format(counts.Start or 0))
	end
	if counts.Finish ~= 1 then
		add(("The course needs exactly one Finish (it has %d)."):format(counts.Finish or 0))
	end
	if (counts.Checkpoint or 0) < 1 then
		add("The course needs at least one Checkpoint.")
	end

	local cframes: { [number]: CFrame } = {}
	for i in course do
		cframes[i] = ParkourLogic.StepCFrame(course, i)
	end

	-- Every jump: not too far, not too high.
	for k = 2, #jumps do
		local ia, ib = jumps[k - 1], jumps[k]
		local a, b = course[ia], course[ib]
		local gap, rise = ParkourLogic.Jump(a, cframes[ia], b, cframes[ib])
		local spicy = b.Spicy == true
		local maxGap = if spicy then rules.SpicyMaxGap else rules.MaxGap
		local maxRise = if spicy then rules.SpicyMaxRise else rules.MaxRise
		local safety = if spicy then rules.SpicySafety else rules.Safety
		local reach = ParkourLogic.Reach(rise) * safety
		local name = stepName(course, ib)
		if gap > maxGap + 1e-6 then
			add(
				("%s: the jump to it is %.1f studs across (most allowed: %.1f)."):format(
					name,
					gap,
					maxGap
				)
			)
		end
		if rise > maxRise + 1e-6 then
			add(
				("%s is %.1f studs higher than the piece before (most allowed: %.1f)."):format(
					name,
					rise,
					maxRise
				)
			)
		end
		if gap > reach + 1e-6 then
			add(
				("%s: a %.1f stud jump that goes %.1f studs up is too hard (about %.1f is fine)."):format(
					name,
					gap,
					rise,
					reach
				)
			)
		end
		if gap < rules.MinGap - 1e-6 then
			add(("%s overlaps the piece before it."):format(name))
		end
	end

	-- Head room: nothing may hang over a jump (or over where you stand before and after it)
	-- lower than Headroom studs above it, or players bump their heads mid-jump and fall. A
	-- piece hangs SizeOf(piece).Y studs below its top (a gravestone is tall).
	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local function radius(step: Step): number
		local size = ParkourLogic.SizeOf(step)
		return math.max(size.X, size.Z) / 2
	end
	local function toSegment(p: Vector3, a: Vector3, b: Vector3): number
		local ab = b - a
		local t = if ab.Magnitude > 1e-6 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		return (p - (a + ab * t)).Magnitude
	end
	for k = 2, #jumps do
		local ia, ib = jumps[k - 1], jumps[k]
		local pa, pb = cframes[ia].Position, cframes[ib].Position
		local floor = math.max(pa.Y, pb.Y)
		for _, ic in jumps do
			if ic == ia or ic == ib then
				continue
			end
			local c = course[ic]
			local pc = cframes[ic].Position
			if pc.Y <= floor then
				continue -- below the jump: nothing to bump into
			end
			local rc = radius(c)
			local over = toSegment(flat(pc), flat(pa), flat(pb)) < rc + rules.HeadroomMargin
				or (flat(pc) - flat(pa)).Magnitude < rc + radius(course[ia])
				or (flat(pc) - flat(pb)).Magnitude < rc + radius(course[ib])
			local bottom = pc.Y - ParkourLogic.SizeOf(c).Y
			if over and bottom - floor < rules.Headroom - 1e-6 then
				add(
					("%s hangs too low over the jump from %s to %s (keep %.1f studs of head room)."):format(
						stepName(course, ic),
						stepName(course, ia),
						stepName(course, ib),
						rules.Headroom
					)
				)
			end
		end
	end

	-- Inside the parkour zone.
	if zoneSize then
		for i, step in course do
			local f = ParkourLogic.Footprint(step)
			local reach = math.max(f.HalfX, f.HalfZ)
			local p = cframes[i].Position
			if
				math.abs(p.X) + reach > zoneSize.X / 2 + 1e-6
				or math.abs(p.Z) + reach > zoneSize.Z / 2 + 1e-6
			then
				add(
					("%s sticks out of the parkour zone (Config.Lobby.Zones.Parkour)."):format(
						stepName(course, i)
					)
				)
			end
			if zoneSize.Y > 0 and (p.Y < 0 or p.Y > zoneSize.Y) then
				add(("%s is higher than the parkour zone's Height."):format(stepName(course, i)))
			end
		end
	end
	return problems
end

-- Height of the highest point of a part (cframe, size): the top face of a level part.
function ParkourLogic.TopY(cframe: CFrame, size: Vector3): number
	local reach = math.abs(cframe.RightVector.Y) * size.X / 2
		+ math.abs(cframe.UpVector.Y) * size.Y / 2
		+ math.abs(cframe.LookVector.Y) * size.Z / 2
	return cframe.Position.Y + reach
end

-- Runs --------------------------------------------------------------------------------------

-- The checkpoint Index values in the order they must be touched (sorted, no repeats).
function ParkourLogic.Order(indices: { number }): { number }
	local seen: { [number]: boolean } = {}
	local order: { number } = {}
	for _, index in indices do
		if type(index) == "number" and index == index and not seen[index] then
			seen[index] = true
			table.insert(order, index)
		end
	end
	table.sort(order)
	return order
end

--[[
	A player who has reached `reached` checkpoints (of `order`) touches the checkpoint with
	`index`: "Next" = that is the next one (count it), "Old" = one they already have,
	"Skipped" = one further on (they missed one in between).
]]
function ParkourLogic.Touch(order: { number }, reached: number, index: number): string
	local nextIndex = order[reached + 1]
	if nextIndex ~= nil and index == nextIndex then
		return "Next"
	end
	local last = order[reached]
	if last ~= nil and index <= last then
		return "Old"
	end
	return "Skipped"
end

function ParkourLogic.CanFinish(order: { number }, reached: number): boolean
	return reached >= #order
end

function ParkourLogic.IsNewBest(best: number, time: number): boolean
	return best <= 0 or time < best
end

-- Seconds until the coin reward can be won again (0 = it can be won now).
function ParkourLogic.RewardWait(lastReward: number, now: number, hours: number): number
	if lastReward <= 0 then
		return 0
	end
	return math.max(0, lastReward + hours * 3600 - now)
end

-- 65.321 -> "1:05.32"
function ParkourLogic.FormatTime(seconds: number): string
	local hundredths = math.max(0, math.floor(seconds * 100 + 0.5))
	local minutes = hundredths // 6000
	local rest = hundredths % 6000
	return ("%d:%02d.%02d"):format(minutes, rest // 100, rest % 100)
end

-- 18720 -> "5h 12m", 600 -> "10m", 42 -> "42s"
function ParkourLogic.FormatWait(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local hours = s // 3600
	local minutes = (s % 3600) // 60
	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	elseif minutes > 0 then
		return ("%dm"):format(minutes)
	end
	return ("%ds"):format(s)
end

return ParkourLogic
