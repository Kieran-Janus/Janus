--!strict
--[[
	The crate luck meter and pack guarantees (Config.Crates.Luck and Config.Crates.Open.Guarantee;
	switches Config.Features.CrateLuck and CratePacks). Pure maths, shared: the server rolls and
	the crate page shows the chances with the SAME functions and the same saved level, so the
	chances on screen are exactly the ones rolled. docs/CRATE-LUCK-SPEC.md has every rule.

	How the meter works (for each player and each themed crate, saved in data.Crates.Luck):
	  - every crate below Luck.Boost (Rare) fills one step: Luck.PerStep % moves from
	    Luck.TakeFrom (Common) to Luck.Boost for the next crate of that kind;
	  - a Rare or better empties it (back to 0);
	  - a full meter (Luck.Steps) makes the next crate Rare or better for sure (FullGuarantee).
	Only themed crates have one: not rarity crates, not Deluxe crates (Base), not a crate line
	with Luck = false, and not a crate whose Rare (or Common) skins are all hidden.
	A switch never erases saved luck: while a crate has no meter its saved level is simply
	not read or written, and it is used again once the meter is back.

	CrateLuck.ConfigOk() -> boolean       Boost is below the top rarity and TakeFrom below Boost
	                                      (otherwise no crate has a meter; warns once)
	CrateLuck.Applies(crate) -> boolean   does this crate have a luck meter right now?
	CrateLuck.Steps() -> number           steps in a full meter (at least 1)
	CrateLuck.Clamp(value) -> number      a whole number 0..Steps (anything odd counts as 0)
	CrateLuck.Get(data, crate) -> number  (server) the saved level, 0 when the crate has no meter
	CrateLuck.Set(data, crate, level)     (server) saves it and tidies the saved table; only
	                                      call it when Applies(crate)
	CrateLuck.Snapshot(data) -> { [crateId]: level }   the levels the client may see (non-zero,
	                                      real crates in the game with a meter)
	CrateLuck.Boost(crate, level, atLeast?) -> CrateOdds.Boost?   the odds change for one roll:
	                                      the luck shift, the full-meter guarantee and a pack
	                                      guarantee (the higher of the two); nil = plain odds
	CrateLuck.After(crate, level, rarity) -> number   the level after a crate gave `rarity`
	CrateLuck.Guarantee(crate, count) -> rarity?      the pack guarantee for opening `count`
	                                      at once (nil for x1, CratePacks off, or impossible)
	CrateLuck.PackLevel(crate, level, count) -> number   the level of a pack's guaranteed last
	                                      crate: min(level + count - 1, Steps) (0 without a meter)
]]

local Config = require(script.Parent.Config)
local CrateOdds = require(script.Parent.CrateOdds)

local CrateLuck = {}

-- Saved luck table limits (a save is player data: never trust its shape).
local MAX_KEY_LENGTH = 64
local MAX_ENTRIES = 64

local warned: { [string]: boolean } = {}
local function warnOnce(message: string)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[CrateLuck] " .. message)
end

local function rarityIndex(rarity: unknown): number?
	if type(rarity) ~= "string" then
		return nil
	end
	return table.find(Config.Rarity.Order, rarity)
end

function CrateLuck.ConfigOk(): boolean
	local cfg = Config.Crates.Luck
	local boost = rarityIndex(cfg.Boost)
	local takeFrom = rarityIndex(cfg.TakeFrom)
	if not boost or boost >= #Config.Rarity.Order then
		warnOnce(
			("Config.Crates.Luck.Boost (%s) must be a rarity below the top one, so no crate has a luck meter."):format(
				tostring(cfg.Boost)
			)
		)
		return false
	end
	if not takeFrom or takeFrom >= boost then
		warnOnce(
			("Config.Crates.Luck.TakeFrom (%s) must be a rarity below Luck.Boost (%s), so no crate has a luck meter."):format(
				tostring(cfg.TakeFrom),
				tostring(cfg.Boost)
			)
		)
		return false
	end
	local perStep = cfg.PerStep
	if type(perStep) ~= "number" or not (perStep >= 0) or perStep == math.huge then
		warnOnce(
			"Config.Crates.Luck.PerStep must be a number, 0 or more, so no crate has a luck meter."
		)
		return false
	end
	return true
end

function CrateLuck.Steps(): number
	local steps = tonumber(Config.Crates.Luck.Steps) or 1
	if steps ~= steps or steps == math.huge then
		return 1
	end
	return math.max(1, math.floor(steps))
end

function CrateLuck.Clamp(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, CrateLuck.Steps())
end

function CrateLuck.Applies(crate: CrateOdds.Crate): boolean
	if not Config.Features.CrateLuck then
		return false
	end
	if crate.Rarity ~= nil or crate.Base ~= nil or crate.Luck == false then
		return false
	end
	if not CrateLuck.ConfigOk() then
		return false
	end
	local cfg = Config.Crates.Luck
	return CrateOdds.Shares(crate, cfg.Boost) and CrateOdds.Shares(crate, cfg.TakeFrom)
end

-- data.Crates.Luck, or nil when the save doesn't have a proper one.
local function savedTable(data: { [string]: any }): { [any]: any }?
	local stats = data.Crates
	if type(stats) ~= "table" then
		return nil
	end
	local luck = stats.Luck
	return if type(luck) == "table" then luck else nil
end

function CrateLuck.Get(data: { [string]: any }, crate: CrateOdds.Crate): number
	if not CrateLuck.Applies(crate) then
		return 0
	end
	local luck = savedTable(data)
	return if luck then CrateLuck.Clamp(luck[crate.Id]) else 0
end

-- Every crate Id the game knows, also of themes that are switched off (their saved luck is
-- kept for when they come back).
local function knownCrates(): { [string]: boolean }
	local known: { [string]: boolean } = {}
	for _, crate in Config.Crates.List do
		known[crate.Id] = true
	end
	for _, theme in Config.Skins.AllThemes do
		if type(theme.Crate) == "string" then
			known[theme.Crate] = true
		end
	end
	return known
end

function CrateLuck.Set(data: { [string]: any }, crate: CrateOdds.Crate, level: number)
	if type(data.Crates) ~= "table" then
		data.Crates = { Opened = 0, Luck = {} }
	end
	if type(data.Crates.Luck) ~= "table" then
		data.Crates.Luck = {}
	end
	local old: { [any]: any } = data.Crates.Luck
	-- Keep only proper entries: a crate Id (a short string) and a level 1..Steps.
	local clean: { [string]: number } = {}
	local count = 0
	for key, value in old do
		if type(key) == "string" and #key <= MAX_KEY_LENGTH and key ~= crate.Id then
			local steps = CrateLuck.Clamp(value)
			if steps > 0 then
				clean[key] = steps
				count += 1
			end
		end
	end
	local steps = CrateLuck.Clamp(level)
	if steps > 0 then
		clean[crate.Id] = steps
		count += 1
	end
	-- Too many: drop the ones that aren't a crate the game knows (in a fixed order).
	if count > MAX_ENTRIES then
		local known = knownCrates()
		local unknown: { string } = {}
		for key in clean do
			if not known[key] and key ~= crate.Id then
				table.insert(unknown, key)
			end
		end
		table.sort(unknown)
		for _, key in unknown do
			if count <= MAX_ENTRIES then
				break
			end
			clean[key] = nil
			count -= 1
		end
	end
	data.Crates.Luck = clean
end

function CrateLuck.Snapshot(data: { [string]: any }): { [string]: number }
	local out: { [string]: number } = {}
	if not Config.Features.CrateLuck then
		return out
	end
	local luck = savedTable(data)
	if not luck then
		return out
	end
	for key, value in luck do
		if type(key) ~= "string" or #key > MAX_KEY_LENGTH then
			continue
		end
		local crate = CrateOdds.Get(key)
		if crate and CrateLuck.Applies(crate) then
			local steps = CrateLuck.Clamp(value)
			if steps > 0 then
				out[key] = steps
			end
		end
	end
	return out
end

function CrateLuck.Boost(crate: CrateOdds.Crate, level: number, atLeast: string?): CrateOdds.Boost?
	local cfg = Config.Crates.Luck
	local shift: { [string]: number }? = nil
	if CrateLuck.Applies(crate) then
		local l = CrateLuck.Clamp(level)
		local base: { [string]: number } = if type(crate.Odds) == "table"
			then crate.Odds
			else Config.Crates.Odds
		local amount = math.min(l * cfg.PerStep, base[cfg.TakeFrom] or 0)
		if amount > 0 then
			shift = { [cfg.TakeFrom] = -amount, [cfg.Boost] = amount }
		end
		if cfg.FullGuarantee and l >= CrateLuck.Steps() then
			atLeast = CrateOdds.Higher(atLeast, cfg.Boost)
		end
	end
	if atLeast and not CrateOdds.CanGuarantee(crate, atLeast) then
		atLeast = nil
	end
	if shift == nil and atLeast == nil then
		return nil
	end
	return { Shift = shift, AtLeast = atLeast }
end

function CrateLuck.After(_crate: CrateOdds.Crate, level: number, rarity: string): number
	local boost = Config.Crates.Luck.Boost
	if CrateOdds.RarityIndex(rarity) >= CrateOdds.RarityIndex(boost) then
		return 0
	end
	return math.min(CrateLuck.Clamp(level) + 1, CrateLuck.Steps())
end

function CrateLuck.Guarantee(crate: CrateOdds.Crate, count: number): string?
	if not Config.Features.CratePacks then
		return nil
	end
	local wanted = (Config.Crates.Open.Guarantee :: any)[count]
	if wanted == nil then
		return nil
	end
	local index = rarityIndex(wanted)
	if not index then
		warnOnce(
			("Config.Crates.Open.Guarantee[%s] (%s) isn't a rarity, so it is ignored."):format(
				tostring(count),
				tostring(wanted)
			)
		)
		return nil
	end
	if not CrateLuck.ConfigOk() or index > (rarityIndex(Config.Crates.Luck.Boost) or 0) then
		warnOnce(
			("Config.Crates.Open.Guarantee[%s] (%s) is above Config.Crates.Luck.Boost, so it is ignored."):format(
				tostring(count),
				tostring(wanted)
			)
		)
		return nil
	end
	if not CrateOdds.CanGuarantee(crate, wanted) then
		return nil
	end
	return wanted
end

function CrateLuck.PackLevel(crate: CrateOdds.Crate, level: number, count: number): number
	if not CrateLuck.Applies(crate) then
		return 0
	end
	return math.min(CrateLuck.Clamp(level) + math.max(0, math.floor(count) - 1), CrateLuck.Steps())
end

return CrateLuck
