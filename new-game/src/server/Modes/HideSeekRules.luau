--!strict
--[[
	The rules of Pumpkin Hide & Seek as plain maths (no parts, no players needed), used by
	src/server/Modes/HideSeek.luau and tested in tests/specs/hideseek.spec.luau.
	Numbers come from Config.HideSeek (passed in as `cfg`).

	HideSeekRules.SeekerCount(players, cfg) -> number
	    seekers at the start: SeekerRatio of the players (rounded down), at least MinSeekers,
	    and always leaving at least one hider. One player alone plays cfg.SoloRole.
	HideSeekRules.PickSeekers(list, count, rng, wasSeeker?) -> (seekers, hiders)
	    a random pick; anyone in `wasSeeker` (seekers last round) is picked last.
	HideSeekRules.Promote(hiders, rng) -> item?   a random hider to make a seeker
	HideSeekRules.Winner(state) -> "Seekers" | "Hiders" | nil
	HideSeekRules.Results(entries, winner, cfg) -> { Row }   scores, coins, badges, best first
]]

local HideSeekRules = {}

export type Role = "Hider" | "Seeker"

-- One player's round, kept by the mode and turned into a results row at the end.
export type Entry = {
	UserId: number,
	Name: string,
	StartRole: Role,
	Tags: number, -- hiders this player tagged (as a seeker, or after being found and joining)
	Found: boolean, -- a hider who was tagged
	HiddenSeconds: number, -- hiders: seconds hidden after the seekers came out
}

export type Row = {
	UserId: number,
	Name: string,
	Score: number,
	Pumpkins: number,
	Coins: number,
	Survived: boolean,
	Top: boolean,
	Team: string,
	Badge: string,
	Stat: string?,
	Won: boolean, -- on the winning side (the mode adds 1 to Stats.HideSeekWins)
}

export type WinnerState = {
	StartedHiders: number, -- hiders when the round began (0 = a solo practice round)
	StartedSeekers: number, -- seekers when the round began (0 = a solo pumpkin round)
	HidersLeft: number,
	SeekersLeft: number,
	TimeUp: boolean,
}

function HideSeekRules.SeekerCount(players: number, cfg: any): number
	if players <= 0 then
		return 0
	elseif players == 1 then
		return if cfg.SoloRole == "Hider" then 0 else 1
	end
	local count = math.max(cfg.MinSeekers or 1, math.floor(players * cfg.SeekerRatio))
	return math.clamp(count, 1, players - 1)
end

-- Shuffles a copy of `list` with `rng`.
local function shuffled<T>(list: { T }, rng: Random): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

function HideSeekRules.PickSeekers<T>(
	list: { T },
	count: number,
	rng: Random,
	wasSeeker: { [T]: boolean }?
): ({ T }, { T })
	local order = shuffled(list, rng)
	if wasSeeker then
		-- Players who were seekers last round go to the back of the queue (stable for the rest).
		local fresh: { T } = {}
		local again: { T } = {}
		for _, item in order do
			if wasSeeker[item] then
				table.insert(again, item)
			else
				table.insert(fresh, item)
			end
		end
		order = fresh
		for _, item in again do
			table.insert(order, item)
		end
	end
	local seekers: { T } = {}
	local hiders: { T } = {}
	for i, item in order do
		if i <= count then
			table.insert(seekers, item)
		else
			table.insert(hiders, item)
		end
	end
	return seekers, hiders
end

function HideSeekRules.Promote<T>(hiders: { T }, rng: Random): T?
	if #hiders == 0 then
		return nil
	end
	return hiders[rng:NextInteger(1, #hiders)]
end

--[[
	Who won: the Seekers once every hider is found (only in a round that had hiders), the
	Hiders if the time ran out or every seeker left while someone was still hidden, otherwise
	nobody yet (nil; also a solo practice round at 0:00). A solo round never ends early.
]]
function HideSeekRules.Winner(state: WinnerState): string?
	if state.StartedHiders > 0 and state.HidersLeft <= 0 then
		return "Seekers"
	end
	if
		state.HidersLeft > 0
		and (state.TimeUp or (state.StartedSeekers > 0 and state.SeekersLeft <= 0))
	then
		return "Hiders"
	end
	return nil
end

-- "2:05" style text for a number of seconds.
function HideSeekRules.Clock(seconds: number): (number, number)
	local whole = math.max(0, math.floor(seconds))
	return whole // 60, whole % 60
end

function HideSeekRules.Results(entries: { Entry }, winner: string?, cfg: any): { Row }
	local rewards = cfg.Rewards
	local text = cfg.Text
	local best = 0
	for _, entry in entries do
		best = math.max(best, entry.Tags)
	end
	local rows: { Row } = {}
	for _, entry in entries do
		local isHider = entry.StartRole == "Hider"
		local hidden = isHider and not entry.Found
		-- Found hiders who joined the seekers win with them; ghosts (TaggedBecomeSeekers off) don't.
		local finalSeeker = not isHider or (entry.Found and cfg.TaggedBecomeSeekers == true)
		local won = (winner == "Seekers" and finalSeeker) or (winner == "Hiders" and hidden)
		local coins = rewards.Played + entry.Tags * rewards.PerTag
		if hidden then
			coins += rewards.HiderSurvived
		elseif isHider then
			coins += math.floor(entry.HiddenSeconds / 60) * rewards.PerMinuteHidden
		end
		if won then
			coins += rewards.WinningTeam
		end
		local stat: string? = nil
		if isHider then
			local minutes, seconds = HideSeekRules.Clock(entry.HiddenSeconds)
			stat = text.StatHidden:format(minutes, seconds)
		end
		table.insert(rows, {
			UserId = entry.UserId,
			Name = entry.Name,
			Score = entry.Tags,
			Pumpkins = entry.Tags,
			Coins = coins,
			-- Green badge: a pumpkin never found, or a seeker on the winning side.
			Survived = hidden or (not isHider and won),
			-- Best tagger(s), and every hidden pumpkin when the pumpkins win.
			Top = (best > 0 and entry.Tags == best) or (hidden and won),
			Team = if isHider then text.TeamHider else text.TeamSeeker,
			Badge = if hidden
				then text.BadgeHidden
				elseif isHider then text.BadgeFound
				else text.BadgeSeeker,
			Stat = stat,
			Won = won,
		})
	end
	table.sort(rows, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		elseif a.Survived ~= b.Survived then
			return a.Survived
		elseif a.Coins ~= b.Coins then
			return a.Coins > b.Coins
		end
		return a.Name < b.Name
	end)
	return rows
end

return HideSeekRules
