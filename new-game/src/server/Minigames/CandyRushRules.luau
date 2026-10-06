--!strict
--[[
	Candy Rush rules: the maths behind the lobby candy race, with no parts and no services, so
	it can be tested on its own (tests/specs/candyrush.spec.luau). Settings come from
	Config.Minigames.CandyRush; CandyRushService (src/server/Services) uses these.

	Rules.AssignLanes(current, standing, lanes, keep?, blocked?) -> { [lane]: who }
	    Who stands on which join pad. Someone already on a lane keeps it while they stand on it
	    (or while `keep[who]` says so: the few seconds of grace after stepping off); newcomers
	    get the first free lane they stand on, in the order `standing` lists them. One lane per
	    player, one player per lane; `blocked` lanes (racing right now) are never given out.
	Rules.LaneRect(lane, lanes, width, height, candy, margin, bottom) -> Rect
	    The area of the board where lane `lane`'s candies may appear, in studs from the board's
	    centre as a player on the pads sees it (x to the right, y up). Lane 1 is on the left.
	Rules.RandomSpot(rect, rng, avoid?, minDistance?) -> Vector2
	    A random point in `rect`, not too close to the last candy's spot when possible.
	Rules.Decide(runners, total, solo, timedOut) -> (winner?, reason)
	    Who won (or nobody) and why; reason "Running" means the race goes on.
	Rules.Reward(record, kind, popped, now, cfg) -> (coins, record, note?)
	    Coins for one player after a race, with the cooldowns and the daily cap.
	Rules.Day(now) -> number   the day number of an os.time() (days since 1970, UTC)
]]

local Rules = {}

export type Standing<K> = { Key: K, Lanes: { number } }

export type Rect = { XMin: number, XMax: number, YMin: number, YMax: number }

export type RunnerInfo<K> = { Key: K, Popped: number, Out: boolean }

-- "Finished": someone grabbed every candy. "LastStanding": everyone else left. "TimeUp": the
-- clock ran out and the winner had the most candies. "Tie": time ran out with no clear leader.
-- "Empty": everyone left. "Left": the solo player left. "Running": not over yet.
export type Reason = "Finished" | "LastStanding" | "TimeUp" | "Tie" | "Empty" | "Left" | "Running"

export type RewardKind = "Win" | "Play" | "Solo"

-- What is saved per player (in data.Minigames) to apply the cooldowns and the daily cap.
export type RewardRecord = {
	Day: number, -- Rules.Day() of CoinsToday
	CoinsToday: number,
	LastReward: number, -- os.time() of the last race coins
	LastSolo: number, -- os.time() of the last solo coins
}

export type RewardConfig = {
	WinCoins: number,
	PlayCoins: number,
	SoloCoins: number,
	MinCandies: number,
	CooldownSeconds: number,
	SoloCooldownSeconds: number,
	DailyCap: number,
}

export type RewardNote = "TooFew" | "Cooldown" | "DailyCap"

function Rules.AssignLanes<K>(
	current: { [number]: K },
	standing: { Standing<K> },
	lanes: number,
	keep: { [K]: boolean }?,
	blocked: { [number]: boolean }?
): { [number]: K }
	local onLane: { [K]: { [number]: boolean } } = {}
	for _, entry in standing do
		local set = onLane[entry.Key] or {}
		for _, lane in entry.Lanes do
			set[lane] = true
		end
		onLane[entry.Key] = set
	end
	local result: { [number]: K } = {}
	local placed: { [K]: boolean } = {}
	-- Keep everyone who is still on their lane (or within their grace time).
	for lane = 1, lanes do
		local key = current[lane]
		if key == nil or placed[key] or (blocked and blocked[lane]) then
			continue
		end
		local set = onLane[key]
		if (set and set[lane]) or (keep and keep[key]) then
			result[lane] = key
			placed[key] = true
		end
	end
	-- Newcomers: the first free lane they stand on.
	for _, entry in standing do
		if placed[entry.Key] then
			continue
		end
		local sorted = table.clone(entry.Lanes)
		table.sort(sorted)
		for _, lane in sorted do
			if
				lane >= 1
				and lane <= lanes
				and result[lane] == nil
				and not (blocked and blocked[lane])
			then
				result[lane] = entry.Key
				placed[entry.Key] = true
				break
			end
		end
	end
	return result
end

function Rules.LaneRect(
	lane: number,
	lanes: number,
	width: number,
	height: number,
	candy: number,
	margin: number,
	bottom: number
): Rect
	local count = math.max(lanes, 1)
	local laneWidth = width / count
	local left = -width / 2 + (math.clamp(lane, 1, count) - 1) * laneWidth
	local inset = margin + candy / 2
	local xMin, xMax = left + inset, left + laneWidth - inset
	if xMin > xMax then
		xMin = left + laneWidth / 2
		xMax = xMin
	end
	local yMin, yMax = -height / 2 + bottom + inset, height / 2 - inset
	if yMin > yMax then
		yMin = bottom / 2 -- too small for a candy: the middle of the free space
		yMax = yMin
	end
	return { XMin = xMin, XMax = xMax, YMin = yMin, YMax = yMax }
end

function Rules.RandomSpot(rect: Rect, rng: Random, avoid: Vector2?, minDistance: number?): Vector2
	local spot = Vector2.zero
	for _ = 1, 10 do
		spot = Vector2.new(
			rect.XMin + rng:NextNumber() * (rect.XMax - rect.XMin),
			rect.YMin + rng:NextNumber() * (rect.YMax - rect.YMin)
		)
		if not avoid or not minDistance or (spot - avoid).Magnitude >= minDistance then
			break
		end
	end
	return spot
end

function Rules.Decide<K>(
	runners: { RunnerInfo<K> },
	total: number,
	solo: boolean,
	timedOut: boolean
): (K?, Reason)
	local active: { RunnerInfo<K> } = {}
	for _, runner in runners do
		if not runner.Out then
			if runner.Popped >= total then
				return runner.Key, "Finished"
			end
			table.insert(active, runner)
		end
	end
	if solo then
		if #active == 0 then
			return nil, "Left"
		elseif timedOut then
			return nil, "TimeUp"
		end
		return nil, "Running"
	end
	if #active == 0 then
		return nil, "Empty"
	elseif #active == 1 and #runners >= 2 then
		return active[1].Key, "LastStanding"
	elseif timedOut then
		local best: RunnerInfo<K>? = nil
		local tie = false
		for _, runner in active do
			if not best or runner.Popped > best.Popped then
				best = runner
				tie = false
			elseif runner.Popped == best.Popped then
				tie = true
			end
		end
		if best and not tie and best.Popped > 0 then
			return best.Key, "TimeUp"
		end
		return nil, "Tie"
	end
	return nil, "Running"
end

function Rules.Day(now: number): number
	return math.floor(now / 86400)
end

function Rules.Reward(
	record: RewardRecord,
	kind: RewardKind,
	popped: number,
	now: number,
	cfg: RewardConfig
): (number, RewardRecord, RewardNote?)
	local new = table.clone(record)
	local day = Rules.Day(now)
	if new.Day ~= day then
		new.Day = day
		new.CoinsToday = 0
	end
	if popped < cfg.MinCandies then
		return 0, new, "TooFew"
	end
	local base = if kind == "Win"
		then cfg.WinCoins
		elseif kind == "Play" then cfg.PlayCoins
		else cfg.SoloCoins
	if base <= 0 then
		return 0, new, nil
	end
	if kind == "Solo" then
		if now - new.LastSolo < cfg.SoloCooldownSeconds then
			return 0, new, "Cooldown"
		end
	elseif now - new.LastReward < cfg.CooldownSeconds then
		return 0, new, "Cooldown"
	end
	local coins = base
	if cfg.DailyCap > 0 then
		coins = math.max(0, math.min(base, cfg.DailyCap - new.CoinsToday))
	end
	if coins <= 0 then
		return 0, new, "DailyCap"
	end
	new.CoinsToday += coins
	if kind == "Solo" then
		new.LastSolo = now
	else
		new.LastReward = now
	end
	return coins, new, if coins < base then "DailyCap" else nil
end

return Rules
