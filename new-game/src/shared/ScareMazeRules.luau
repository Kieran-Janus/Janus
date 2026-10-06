--!strict
--[[
	ScareMaze rules that both the server (src/server/Modes/ScareMaze.luau) and the client
	(src/client/ScareMazeUI.luau) use. Pure maths: no parts, no players, no waiting, so the
	tests can try them with made-up positions and times (tests/specs/scaremaze.spec.luau).
	Settings: Config.ScareMaze.

	Keep moving (the stop rule):
	  local tracker = Rules.NewTracker(now)
	  Rules.Grace(tracker, untilTime)          -- safe until then (start of the run, after a scare)
	  local stillFor = Rules.Update(tracker, position, now, minMoveStuds)
	  if stillFor >= stopSeconds then ... out ... end
	"Moving" means getting at least minMoveStuds away (sideways: jumping on the spot doesn't
	count) from where you were when the still-clock last started. Walking back and forth
	further than that counts as moving; wiggling on the spot doesn't.

	Teams:
	  Rules.HaunterCount(players, ratio, minPlayers) -> number of Haunters
	  Rules.PickTeams(list, ratio, minPlayers, rng) -> (survivors, haunters)
]]

local Rules = {}

-- Remote names (the server makes them when the ScareMaze mode loads).
Rules.Remotes = {
	Boo = "ScareMazeBoo", -- client -> server: a Haunter pressed BOO (no arguments)
	Scare = "ScareMazeScare", -- server -> client: show a jumpscare (kind: string)
}

-- Player attributes the server sets during a ScareMaze round (the client reads them).
Rules.Attributes = {
	Team = "ScareTeam", -- "Survivors" or "Haunters"
	State = "ScareState", -- Survivors: "Running", "Escaped" or "Out"
	GraceUntil = "ScareGraceUntil", -- server time (workspace:GetServerTimeNow()) the safe time ends
	BooReadyAt = "BooReadyAt", -- Haunters: server time BOO can be used again
	Catches = "ScareCatches", -- Haunters: Survivors caught this round
	StartedAs = "ScareStartedAs", -- the team this player started the round in
}

export type Tracker = {
	Anchor: Vector3?, -- where the still-clock last started (nil = not seen yet)
	AnchorTime: number, -- when it started
	GraceUntil: number, -- the still-clock can't run before this time
}

function Rules.NewTracker(now: number): Tracker
	return { Anchor = nil, AnchorTime = now, GraceUntil = now }
end

-- Safe (the still-clock stays at 0) until `untilTime`. Never shortens a longer grace.
function Rules.Grace(tracker: Tracker, untilTime: number)
	if untilTime > tracker.GraceUntil then
		tracker.GraceUntil = untilTime
	end
end

-- Distance between two points, ignoring height.
function Rules.Flat(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

--[[
	Feeds one position sample in and returns how long (seconds) this player has been standing
	still. Samples can come at any rate; the result only depends on positions and times.
]]
function Rules.Update(tracker: Tracker, position: Vector3, now: number, minMove: number): number
	local anchor = tracker.Anchor
	if now < tracker.GraceUntil then
		-- Safe: the clock starts again from 0 (at this spot) when the grace ends.
		tracker.Anchor = position
		tracker.AnchorTime = tracker.GraceUntil
		return 0
	end
	if anchor == nil or Rules.Flat(position, anchor) >= minMove then
		tracker.Anchor = position
		tracker.AnchorTime = math.max(now, tracker.GraceUntil)
		return 0
	end
	return math.max(0, now - math.max(tracker.AnchorTime, tracker.GraceUntil))
end

-- 1 = full (just moved), 0 = empty (out). For the client's KEEP MOVING meter.
function Rules.Meter(stillFor: number, stopSeconds: number): number
	if stopSeconds <= 0 then
		return 0
	end
	return math.clamp(1 - stillFor / stopSeconds, 0, 1)
end

-- Whole seconds left before being out (3, 2, 1), for the red countdown. 0 = out.
function Rules.SecondsLeft(stillFor: number, stopSeconds: number): number
	return math.max(0, math.ceil(stopSeconds - stillFor - 1e-6))
end

-- How many Haunters a round with `players` players gets (0 = everyone is a Survivor).
function Rules.HaunterCount(players: number, ratio: number, minPlayers: number): number
	if players < math.max(2, minPlayers) then
		return 0
	end
	-- At least one Haunter, and always at least one Survivor.
	return math.clamp(math.floor(players * ratio), 1, players - 1)
end

-- Splits `list` into Survivors and Haunters at random (the list itself isn't changed).
function Rules.PickTeams<T>(
	list: { T },
	ratio: number,
	minPlayers: number,
	rng: Random
): ({ T }, { T })
	local shuffled = table.clone(list)
	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local count = Rules.HaunterCount(#shuffled, ratio, minPlayers)
	local survivors: { T } = {}
	local haunters: { T } = {}
	for i, item in shuffled do
		if i <= count then
			table.insert(haunters, item)
		else
			table.insert(survivors, item)
		end
	end
	return survivors, haunters
end

-- Is `position` inside a box at `cframe` with `size` (grown by `margin` studs on every side)?
function Rules.InBox(position: Vector3, cframe: CFrame, size: Vector3, margin: number): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 + margin
		and math.abs(p.Y) <= size.Y / 2 + margin
		and math.abs(p.Z) <= size.Z / 2 + margin
end

--[[
	Anti-cheat: did a player get from `a` to `b` in `seconds` faster than anyone can run?
	`maxSpeed` studs per second, plus `slack` studs for lag.
]]
function Rules.TooFast(
	a: Vector3,
	b: Vector3,
	seconds: number,
	maxSpeed: number,
	slack: number
): boolean
	return Rules.Flat(a, b) > maxSpeed * math.max(seconds, 0) + slack
end

-- Score and base coins for one player at the end of a round (Config.ScareMaze.Rewards).
export type Outcome = {
	Escaped: boolean,
	TimeLeft: number, -- seconds on the clock when they escaped (0 if they didn't)
	Catches: number, -- Survivors caught while a Haunter
}

function Rules.Score(outcome: Outcome, rewards: any): (number, number)
	local score = outcome.Catches * rewards.PointsPerCatch
	local coins = rewards.PlayCoins + outcome.Catches * rewards.CoinsPerCatch
	if outcome.Escaped then
		local left = math.max(0, outcome.TimeLeft)
		score += rewards.EscapePoints + math.floor(left * rewards.PointsPerSecondLeft)
		coins += rewards.EscapeCoins + math.floor(left * rewards.CoinsPerSecondLeft)
	end
	return score, coins
end

return Rules
