--!strict
--[[
	The rules of Prop Hunt as plain maths (no parts, no players needed), used by
	src/server/Modes/PropHunt.luau and tested in tests/specs/prophunt.spec.luau. Numbers come
	from Config.PropHunt (passed in as `cfg`). Teams, picking and the winner work exactly like
	Hide & Seek's (src/server/Modes/HideSeekRules.luau), so they are shared.

	PropHuntRules.FinderCount(players, cfg) -> number
	    finders at the start: FinderRatio of the players (rounded down), at least MinFinders,
	    always leaving at least one hider. One player alone plays cfg.SoloRole.
	PropHuntRules.PickFinders(list, count, rng, wasFinder?) -> (finders, hiders)
	PropHuntRules.Promote(hiders, rng) -> item?
	PropHuntRules.Winner(state) -> "Seekers" | "Hiders" | nil   (Seekers = the finders)
	PropHuntRules.Settings(cfg, difficulty) -> the Easy or Hard block (Easy if unknown)
	PropHuntRules.Results(entries, winner, cfg, multiplier) -> { Row }   best first
]]

local HideSeekRules = require(script.Parent.HideSeekRules)

local PropHuntRules = {}

export type Role = "Hider" | "Seeker"

-- One player's round, kept by the mode and turned into a results row at the end.
export type Entry = {
	UserId: number,
	Name: string,
	StartRole: Role,
	Finds: number, -- hiders this player found (as a finder, or after being found and joining)
	Found: boolean, -- a hider who was found
	HiddenSeconds: number, -- hiders: seconds hidden after the finders came out
	Taunts: number, -- taunts that counted (Config.PropHunt.Taunt)
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
	Won: boolean,
}

export type WinnerState = HideSeekRules.WinnerState

function PropHuntRules.FinderCount(players: number, cfg: any): number
	return HideSeekRules.SeekerCount(players, {
		SoloRole = cfg.SoloRole,
		SeekerRatio = cfg.FinderRatio,
		MinSeekers = cfg.MinFinders,
	})
end

PropHuntRules.PickFinders = HideSeekRules.PickSeekers
PropHuntRules.Promote = HideSeekRules.Promote
PropHuntRules.Winner = HideSeekRules.Winner
PropHuntRules.Clock = HideSeekRules.Clock

function PropHuntRules.Settings(cfg: any, difficulty: string?): any
	local levels = cfg.Difficulty
	return (difficulty and levels[difficulty]) or levels.Easy
end

function PropHuntRules.Results(
	entries: { Entry },
	winner: string?,
	cfg: any,
	multiplier: number?
): { Row }
	local rewards = cfg.Rewards
	local text = cfg.Text
	local times = multiplier or 1
	local scores: { [Entry]: number } = {}
	local best = 0
	for _, entry in entries do
		local score = entry.Finds + entry.Taunts * cfg.Taunt.Points
		scores[entry] = score
		best = math.max(best, score)
	end
	local rows: { Row } = {}
	for _, entry in entries do
		local isHider = entry.StartRole == "Hider"
		local hidden = isHider and not entry.Found
		-- Found hiders who joined the finders win with them; ghosts don't.
		local finalFinder = not isHider or (entry.Found and cfg.FoundBecomeFinders == true)
		local won = (winner == "Seekers" and finalFinder) or (winner == "Hiders" and hidden)
		local coins = rewards.Played
			+ entry.Finds * rewards.PerFind
			+ entry.Taunts * rewards.PerTaunt
		if hidden then
			coins += rewards.HiderSurvived
		elseif isHider then
			coins += math.floor(entry.HiddenSeconds / 60) * rewards.PerMinuteHidden
		end
		if won then
			coins += rewards.WinningTeam
		end
		coins = math.floor(coins * times + 0.5)
		local stat: string? = nil
		if isHider then
			local minutes, seconds = HideSeekRules.Clock(entry.HiddenSeconds)
			stat = text.StatHidden:format(minutes, seconds)
			if entry.Taunts > 0 then
				stat = stat .. ", " .. text.StatTaunts:format(entry.Taunts)
			end
		end
		local score = scores[entry]
		table.insert(rows, {
			UserId = entry.UserId,
			Name = entry.Name,
			Score = score,
			Pumpkins = score,
			Coins = coins,
			-- Green badge: a hider never found, or a finder on the winning side.
			Survived = hidden or (not isHider and won),
			Top = (best > 0 and score == best) or (hidden and won),
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

return PropHuntRules
