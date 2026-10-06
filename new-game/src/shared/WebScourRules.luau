--!strict
--[[
	Web Scour maths (Config.Minigames.WebScour), shared by the server, the client and the
	tests. Plain functions: no parts, no players, no waiting.

	WebScourRules.PickSpots(available, count, rng) -> { number }
	        `count` different numbers from 1..available, in a random order (fewer if there
	        aren't enough)
	WebScourRules.Coins(cfg, found, total, secondsLeft) -> number
	        coins for a hunt: CoinsPerCritter each, plus FinishCoins and the time bonus when
	        all were found, never more than MaxCoins
	WebScourRules.CheckFind(check, cfg) -> string?
	        nil when a click on a critter counts, else why not: "Over", "Found", "TooSoon",
	        "TooFast" or "TooFar"
	WebScourRules.ClockPoint(hour, radius) -> (right, up)
	        where a clock hour (12 = top, 3 = right) is on a circle of that radius
	WebScourRules.FormatTime(seconds) -> string      "23.4s", "1:05.2"
	WebScourRules.FormatWait(seconds) -> string      "45s", "2m 05s"
]]

local WebScourRules = {}

export type CoinConfig = {
	CoinsPerCritter: number,
	FinishCoins: number,
	TimeBonusPerSecond: number,
	MaxCoins: number,
}

export type FindConfig = {
	MaxReach: number,
	MinSecondsBetweenFinds: number,
	FirstFindAfter: number,
}

export type FindCheck = {
	Now: number, -- server clock now
	Started: number, -- when the hunt started
	Deadline: number, -- when it runs out (plus any lag allowance)
	LastFind: number?, -- when the previous critter was caught
	AlreadyFound: boolean, -- this critter was caught already
	Distance: number, -- studs from the hunter to the critter
}

function WebScourRules.PickSpots(available: number, count: number, rng: Random): { number }
	local pool = {}
	for i = 1, math.max(math.floor(available), 0) do
		pool[i] = i
	end
	local picked = {}
	local wanted = math.min(math.max(math.floor(count), 0), #pool)
	for _ = 1, wanted do
		local index = rng:NextInteger(1, #pool)
		table.insert(picked, pool[index])
		pool[index] = pool[#pool]
		pool[#pool] = nil
	end
	return picked
end

function WebScourRules.Coins(
	cfg: CoinConfig,
	found: number,
	total: number,
	secondsLeft: number
): number
	if total <= 0 or found <= 0 then
		return 0
	end
	local caught = math.min(found, total)
	local coins = caught * cfg.CoinsPerCritter
	if caught >= total then
		coins += cfg.FinishCoins + math.max(secondsLeft, 0) * cfg.TimeBonusPerSecond
	end
	return math.clamp(math.floor(coins), 0, math.max(cfg.MaxCoins, 0))
end

function WebScourRules.CheckFind(check: FindCheck, cfg: FindConfig): string?
	if check.Now > check.Deadline then
		return "Over"
	end
	if check.AlreadyFound then
		return "Found"
	end
	if check.Now - check.Started < cfg.FirstFindAfter then
		return "TooSoon"
	end
	local last = check.LastFind
	if last and check.Now - last < cfg.MinSecondsBetweenFinds then
		return "TooFast"
	end
	if check.Distance ~= check.Distance or check.Distance > cfg.MaxReach then
		return "TooFar" -- (NaN never counts)
	end
	return nil
end

function WebScourRules.ClockPoint(hour: number, radius: number): (number, number)
	local angle = (hour % 12) / 12 * math.pi * 2
	return math.sin(angle) * radius, math.cos(angle) * radius
end

function WebScourRules.FormatTime(seconds: number): string
	local s = math.max(seconds, 0)
	if s < 60 then
		return ("%.1fs"):format(s)
	end
	local minutes = math.floor(s / 60)
	return ("%d:%04.1f"):format(minutes, s - minutes * 60)
end

function WebScourRules.FormatWait(seconds: number): string
	local s = math.max(math.ceil(seconds), 0)
	if s < 60 then
		return ("%ds"):format(s)
	end
	return ("%dm %02ds"):format(s // 60, s % 60)
end

return WebScourRules
