--!strict
--[[
	Spooky Obby rules: pure maths shared by the mode (src/server/Modes/ObbyRace.luau), the map
	builder (src/server/Maps/SpookyObby.luau), the screen (src/client/ObbyRaceUI.luau) and the
	tests (tests/specs/obbyrace.spec.luau). Nothing in here changes the game.

	Course:
	  Rules.Course(course, difficulty) -> { Step }   the pieces there on that difficulty
	  Rules.CourseFrame(origin) -> CFrame            course space -> world (the course runs to +Z)
	  Rules.DifficultyOf(id) -> settings             Config.ObbyRace.Difficulty[id] (or Easy)
	Touching:
	  Rules.OnPad(position, cframe, size, round, margin, height) -> boolean   a racer's root is
	                                             standing on (or just above) a pad's top
	  Rules.InBox(position, cframe, size, margin) -> boolean
	Ghost sweepers (spinning bars, animated on screens, judged on the server, same maths):
	  Rules.SweeperAngle(phase, speed, elapsed) -> number            degrees
	  Rules.SweeperCFrame(center, angle) -> CFrame                    the bar's CFrame
	  Rules.SweeperHit(rootPosition, barCFrame, barSize, bodyRadius) -> boolean
	Results:
	  Rules.Ordinal(n) -> "1st", "2nd", "3rd", "4th"...
	  Rules.Reward(outcome, rewards, multiplier) -> (points, coins)
	  Rules.Sort(a, b) -> boolean                    results order (finishers by place first)
]]

local Rules = {}

-- Player attributes the mode sets and the screen reads (cleared after the round).
Rules.Attributes = {
	Checkpoint = "ObbyCheckpoint", -- checkpoints reached (0 = none yet)
	Total = "ObbyTotal", -- checkpoints on this round's course
	Rank = "ObbyRank", -- current place in the race (1 = in front)
	Place = "ObbyPlace", -- finishing place (set when you finish)
	Time = "ObbyTime", -- finishing time in seconds
	Back = "ObbyBack", -- counts up every time you're sent back (the screen shows why)
	BackReason = "ObbyBackReason", -- "Fell", "Goo", "Swept", "TooFast" or "Button"
	BackReadyAt = "ObbyBackReadyAt", -- server time the Back button works again
}

-- ReplicatedStorage attributes (cleared after the round).
Rules.Shared = {
	Finished = "ObbyFinished", -- how many have finished
	StartedAt = "ObbyStartedAt", -- server time of GO! (the sweepers turn from then)
	Leader = "ObbyLeader", -- the first finisher's name
}

-- Attributes on map parts.
Rules.Parts = {
	Index = "Index", -- checkpoints: 1, 2, 3... in course order
	Only = "Only", -- "Easy" / "Hard": the piece is removed on the other difficulty
	Facing = "Facing", -- checkpoints: the flat direction to face when sent back there
	Speed = "Speed", -- sweeper bars: degrees per second (the mode sets the round's speed)
	BaseSpeed = "BaseSpeed", -- sweeper bars: the map's Speed before the difficulty
	Phase = "Phase", -- sweeper bars: degrees at GO!
	Center = "Center", -- sweeper bars: the point they turn round (world)
}

Rules.Remotes = {
	Back = "ObbyRaceBack", -- client -> server: "send me back to my checkpoint"
}

export type Step = {
	Kind: string,
	Look: string,
	Offset: Vector3,
	Size: Vector3,
	Rotation: number?,
	Only: string?,
	Label: string?,
	Sweeper: { Speed: number, Length: number, Cross: boolean? }?,
}

export type Outcome = {
	Finished: boolean,
	Place: number, -- 0 when not finished
	Checkpoints: number,
}

export type Rewards = {
	PlayCoins: number,
	FinishCoins: number,
	PlaceCoins: { number },
	CheckpointCoins: number,
	PlacePoints: { number },
	LastPoints: number,
	CheckpointPoints: number,
}

-- The pieces there on `difficulty` (a piece with Only = the other difficulty is left out).
function Rules.Course(course: { Step }, difficulty: string): { Step }
	local list: { Step } = {}
	for _, step in course do
		if step.Only == nil or step.Only == difficulty then
			table.insert(list, step)
		end
	end
	return list
end

-- Course space (Offset = right, up, back) -> world: the plaza's top middle at `origin`, the
-- course running away from the lobby (+Z), "right" seen from the plaza looking along it.
function Rules.CourseFrame(origin: Vector3): CFrame
	return CFrame.new(origin) * CFrame.Angles(0, math.pi, 0)
end

-- The settings of difficulty `id` (Easy when unknown).
function Rules.DifficultyOf(settings: { [string]: any }, id: string): any
	return settings[id] or settings.Easy
end

function Rules.InBox(position: Vector3, cframe: CFrame, size: Vector3, margin: number): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 + margin
		and math.abs(p.Y) <= size.Y / 2 + margin
		and math.abs(p.Z) <= size.Z / 2 + margin
end

--[[
	Is a racer's root (at `position`) standing on a pad? `cframe` = the pad's top middle (level),
	`size` its size (X, Z = its footprint), `round` = a round pad. The root may be up to
	`height` studs above the top (standing, or landing) and `margin` studs past its edge.
]]
function Rules.OnPad(
	position: Vector3,
	cframe: CFrame,
	size: Vector3,
	round: boolean,
	margin: number,
	height: number
): boolean
	local p = cframe:PointToObjectSpace(position)
	if p.Y < -0.5 or p.Y > height then
		return false
	end
	if round then
		local r = math.min(size.X, size.Z) / 2 + margin
		return p.X * p.X + p.Z * p.Z <= r * r
	end
	return math.abs(p.X) <= size.X / 2 + margin and math.abs(p.Z) <= size.Z / 2 + margin
end

-- Degrees a sweeper has turned `elapsed` seconds after GO! (before GO!: its phase).
function Rules.SweeperAngle(phase: number, speed: number, elapsed: number): number
	return (phase + speed * math.max(elapsed, 0)) % 360
end

-- The bar's CFrame: centred on `center`, turned `angle` degrees round the vertical.
function Rules.SweeperCFrame(center: Vector3, angle: number): CFrame
	return CFrame.new(center) * CFrame.Angles(0, math.rad(angle), 0)
end

--[[
	Does a bar (cframe, size: long along X) hit a racer whose root is at `root`? The body
	reaches 3 studs below the root (feet) and 2 above (head), `bodyRadius` studs round. A racer
	whose feet are above the bar (jumping over it) is safe.
]]
function Rules.SweeperHit(root: Vector3, cframe: CFrame, size: Vector3, bodyRadius: number): boolean
	local p = cframe:PointToObjectSpace(root)
	local feet, head = p.Y - 3, p.Y + 2
	if feet > size.Y / 2 or head < -size.Y / 2 then
		return false
	end
	return math.abs(p.X) <= size.X / 2 + bodyRadius and math.abs(p.Z) <= size.Z / 2 + bodyRadius
end

-- 1 -> "1st", 2 -> "2nd", 11 -> "11th", 22 -> "22nd".
function Rules.Ordinal(n: number): string
	local teen = n % 100
	local last = n % 10
	local suffix = "th"
	if teen < 11 or teen > 13 then
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return ("%d%s"):format(n, suffix)
end

-- Points and coins (before the friend bonus) for one racer.
function Rules.Reward(outcome: Outcome, rewards: Rewards, multiplier: number): (number, number)
	local points, coins
	if outcome.Finished then
		points = rewards.PlacePoints[outcome.Place] or rewards.LastPoints
		coins = rewards.PlayCoins + rewards.FinishCoins + (rewards.PlaceCoins[outcome.Place] or 0)
	else
		points = rewards.CheckpointPoints * outcome.Checkpoints
		coins = rewards.PlayCoins + rewards.CheckpointCoins * outcome.Checkpoints
	end
	return points, math.floor(coins * multiplier + 0.5)
end

export type Standing = {
	Finished: boolean,
	Place: number,
	Checkpoints: number,
	ReachedAt: number, -- when the last checkpoint was reached (earlier = in front)
}

-- Who is in front: finishers by place, then the most checkpoints, then who got there first.
function Rules.Sort(a: Standing, b: Standing): boolean
	if a.Finished ~= b.Finished then
		return a.Finished
	end
	if a.Finished then
		return a.Place < b.Place
	end
	if a.Checkpoints ~= b.Checkpoints then
		return a.Checkpoints > b.Checkpoints
	end
	return a.ReachedAt < b.ReachedAt
end

return Rules
