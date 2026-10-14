--!strict
--[[
	Crate odds (shared by the server, which rolls, and the client, which shows the chances).
	Crates and their odds are in Config.Crates (src/shared/Config/Crates.luau).

	An item's chance = its rarity's odds / how many items of that rarity the crate has. A
	rarity the crate has no items of is left out and the others are scaled up to fill 100%,
	so the chances always add up to exactly what players are shown. An item with its own Odds
	(percent, e.g. the one-in-a-million skins: Odds = 0.0001) gets exactly that chance; the
	rest of the crate shares what is left by rarity. Items with OneInAMillion = true are only
	in their own themed crate (and its Deluxe crate), never in a rarity crate.

	A BOOST changes the odds of one roll (the luck meter and the pack guarantees, worked out by
	src/shared/CrateLuck.luau). The server rolls and the client shows with the same boost, so
	the chances on screen are exactly the ones rolled:
	  Shift    percent added to (negative: taken from) each rarity's configured odds
	  AtLeast  only this rarity or better: lower rarities drop out and the rest keep their
	           proportions, scaled up to 100% (exactly "rolled again until it is this or
	           better"). Ignored unless CanGuarantee(crate, AtLeast). Fixed-odds items keep
	           their exact chance.

	CrateOdds.Get(id) -> crate?            the Config.Crates.List entry with that Id (nil for a
	                                       crate that isn't Available right now)
	CrateOdds.List() -> { crate }          every available crate that has at least one item
	CrateOdds.Available(crate) -> boolean  false for a Deluxe crate (Base) while
	                                       Config.Features.PremiumCrates is off
	CrateOdds.Items(crate) -> { item }     the shop items the crate can give (never VIP-only);
	                                       a Deluxe crate gives its Base crate's items
	CrateOdds.RarityOdds(crate, boost?) -> { [rarity]: percent }   the odds actually used
	CrateOdds.Chances(crate, boost?) -> { Chance }  every item that can drop, with its chance in
	                                       percent, fixed-odds items first, then highest rarity
	                                       first (sums to 100)
	CrateOdds.Shown(crate, boost?) -> { Chance }    EVERY item of the crate in the same order,
	                                       0 for the ones that can't drop with this boost (the
	                                       crate page shows them all)
	CrateOdds.Shares(crate, rarity) -> boolean     the crate's configured odds give `rarity`
	                                       more than 0 and it has an item of that rarity
	                                       without its own fixed Odds
	CrateOdds.CanGuarantee(crate, rarity) -> boolean   = Shares: an AtLeast rarity must
	                                       itself be possible, or there is no guarantee
	CrateOdds.Higher(a?, b?) -> rarity?    the higher of two rarity names
	CrateOdds.Pick(chances, roll) -> item  the item a roll (0 <= roll < 1) lands on
	CrateOdds.Roll(crate, rng, boost?) -> item?   a random item, using `rng` (a Random)
	CrateOdds.Reel(crate, winnerId, rng, cards, winIndex, boost?) -> { itemId }
	                                       the opening animation's strip: random picks from
	                                       the odds actually rolled, with the winner at
	                                       winIndex. The cards within
	                                       Config.Crates.Opening.TeaseGuard places of the
	                                       winner are never rarer than the win (no fake near
	                                       misses)
	CrateOdds.RarityIndex(rarity) -> number its place in Config.Rarity.Order (1 = commonest)
	CrateOdds.Format(percent) -> string    exact: "5.082%", "24%", "0.02%", "0.04442%",
	                                       "0.0001%" (3 decimals from 1% up, 4 significant
	                                       figures under 1%; never rounded to 0% or 100%)
	CrateOdds.Exact(percent) -> string     "6.123%", "0.020%", "0.0001%" (fixed 3 decimals)
	CrateOdds.CoinPrice(crate) -> number?  coins to open it (nil = not sold for coins)
	CrateOdds.ProductId(crate) -> number   its Robux Developer Product id (0 = not for sale)
	CrateOdds.ByProductId(id) -> crate?    the crate a Developer Product opens (also an
	                                       unavailable one, so its receipt still pays coins)
]]

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

export type Crate = {
	Id: string,
	Name: string,
	Blurb: string,
	Color: Color3,
	Trim: Color3,
	Glow: Color3,
	Topper: string,
	Price: number?,
	Robux: { ProductId: number, SuggestedRobux: number }?,
	Rarity: string?,
	Odds: { [string]: number }?,
	Category: string?, -- its tab in Menu > Crates
	Look: { [string]: any }?,
	New: boolean?,
	Luck: boolean?, -- false = no luck meter for this crate
	Base: string?, -- (Deluxe crates) the crate whose skins it gives
}

export type Chance = {
	Item: any, -- the Config.Shop.Items entry
	Rarity: string, -- its rarity id
	Chance: number, -- percent, 0-100
}

-- How one roll's odds are changed (see the top of this file).
export type Boost = {
	Shift: { [string]: number }?, -- percent added to (negative: taken from) each rarity's odds
	AtLeast: string?, -- only this rarity or better: lower rarities drop out, the rest scale up
}

local CrateOdds = {}

function CrateOdds.Available(crate: Crate): boolean
	if crate.Base ~= nil and not Config.Features.PremiumCrates then
		return false
	end
	return true
end

function CrateOdds.Get(id: unknown): Crate?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, crate in Config.Crates.List do
		if crate.Id == id then
			if not CrateOdds.Available(crate :: any) then
				return nil
			end
			return crate :: any
		end
	end
	return nil
end

-- Ids of the crates in Config.Crates.List (a rarity crate draws from items in any of them).
local function listedIds(): { [string]: boolean }
	local ids = {}
	for _, crate in Config.Crates.List do
		ids[crate.Id] = true
	end
	return ids
end

-- The crate whose items this one gives (a Deluxe crate gives its Base crate's).
local function source(crate: Crate): string
	return crate.Base or crate.Id
end

function CrateOdds.Items(crate: Crate): { any }
	local listed = listedIds()
	local rarity = crate.Rarity
	local from = source(crate)
	local out = {}
	for _, item in Config.Shop.Items do
		if item.VipOnly or type(item.Id) ~= "string" then
			continue
		end
		local mine = item.Crate == from
		local byRarity = rarity ~= nil
			and not item.OneInAMillion
			and Items.Rarity(item) == rarity
			and type(item.Crate) == "string"
			and listed[item.Crate] == true
		if mine or byRarity then
			table.insert(out, item)
		end
	end
	return out
end

-- A rarity's place in Config.Rarity.Order (1 = the commonest); unknown rarities count as the
-- commonest.
function CrateOdds.RarityIndex(rarity: string?): number
	return table.find(Config.Rarity.Order, rarity or "") or 1
end

-- The higher of two rarity names (either may be nil).
function CrateOdds.Higher(a: string?, b: string?): string?
	if a == nil then
		return b
	elseif b == nil then
		return a
	end
	return if CrateOdds.RarityIndex(b) > CrateOdds.RarityIndex(a) then b else a
end

-- The crate's own configured odds, before any boost.
local function plainOdds(crate: Crate): { [string]: number }
	if type(crate.Odds) == "table" then
		return crate.Odds
	end
	if type(crate.Rarity) == "string" then
		return { [crate.Rarity] = 100 }
	end
	return Config.Crates.Odds
end

-- An item's own fixed chance (percent) in `crate`, or nil. Only in its own themed crate (and
-- that crate's Deluxe crate).
local function fixedOdds(crate: Crate, item: any): number?
	local odds = item.Odds
	if type(odds) == "number" and odds > 0 and item.Crate == source(crate) then
		return odds
	end
	return nil
end

function CrateOdds.Shares(crate: Crate, rarity: string): boolean
	local odds = plainOdds(crate)[rarity]
	if type(odds) ~= "number" or not (odds > 0) then
		return false
	end
	for _, item in CrateOdds.Items(crate) do
		if Items.Rarity(item) == rarity and not fixedOdds(crate, item) then
			return true
		end
	end
	return false
end

function CrateOdds.CanGuarantee(crate: Crate, rarity: string): boolean
	return CrateOdds.Shares(crate, rarity)
end

-- The configured odds for this crate with `boost` applied (before leaving out rarities it
-- has no items of). Always a new table.
local function configuredOdds(crate: Crate, boost: Boost?): { [string]: number }
	local odds = table.clone(plainOdds(crate))
	if not boost then
		return odds
	end
	if boost.Shift then
		for rarity, amount in boost.Shift do
			local before = odds[rarity]
			local now = (if type(before) == "number" then before else 0) + amount
			odds[rarity] = math.max(0, now)
		end
	end
	local atLeast = boost.AtLeast
	if atLeast and CrateOdds.CanGuarantee(crate, atLeast) then
		local floor = CrateOdds.RarityIndex(atLeast)
		for rarity in odds do
			if CrateOdds.RarityIndex(rarity) < floor then
				odds[rarity] = 0
			end
		end
	end
	return odds
end

local function countByRarity(items: { any }): { [string]: number }
	local counts = {}
	for _, item in items do
		local rarity = Items.Rarity(item)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	return counts
end

local function scaledOdds(
	crate: Crate,
	counts: { [string]: number },
	boost: Boost?
): { [string]: number }
	local wanted = configuredOdds(crate, boost)
	local total = 0
	for _, rarity in Config.Rarity.Order do
		local odds = wanted[rarity]
		if type(odds) == "number" and odds > 0 and (counts[rarity] or 0) > 0 then
			total += odds
		end
	end
	local out = {}
	if total <= 0 then
		return out
	end
	for _, rarity in Config.Rarity.Order do
		local odds = wanted[rarity]
		if type(odds) == "number" and odds > 0 and (counts[rarity] or 0) > 0 then
			out[rarity] = odds * 100 / total
		end
	end
	return out
end

-- The items sharing the crate by rarity (no fixed Odds), and the percent they share.
local function shared(crate: Crate, items: { any }): ({ any }, number)
	local rest = {}
	local fixedTotal = 0
	for _, item in items do
		local fixed = fixedOdds(crate, item)
		if fixed then
			fixedTotal += fixed
		else
			table.insert(rest, item)
		end
	end
	return rest, math.max(0, 100 - fixedTotal)
end

function CrateOdds.RarityOdds(crate: Crate, boost: Boost?): { [string]: number }
	local items = CrateOdds.Items(crate)
	local rest, share = shared(crate, items)
	local odds = scaledOdds(crate, countByRarity(rest), boost)
	for rarity, percent in odds do
		odds[rarity] = percent * share / 100
	end
	-- Fixed-odds items count towards their rarity's total.
	for _, item in items do
		local fixed = fixedOdds(crate, item)
		if fixed then
			local rarity = Items.Rarity(item)
			odds[rarity] = (odds[rarity] or 0) + fixed
		end
	end
	return odds
end

function CrateOdds.Chances(crate: Crate, boost: Boost?): { Chance }
	local items = CrateOdds.Items(crate)
	local rest, share = shared(crate, items)
	local counts = countByRarity(rest)
	local odds = scaledOdds(crate, counts, boost)
	local out: { Chance } = {}
	-- Highest rarity first (CRAZY at the top), Config order inside a rarity; fixed-odds items
	-- (the one-in-a-million skins) first of all.
	for _, item in items do
		local fixed = fixedOdds(crate, item)
		if fixed then
			table.insert(out, { Item = item, Rarity = Items.Rarity(item), Chance = fixed })
		end
	end
	for i = #Config.Rarity.Order, 1, -1 do
		local rarity = Config.Rarity.Order[i]
		local percent = odds[rarity]
		if not percent then
			continue
		end
		local each = percent * share / 100 / counts[rarity]
		for _, item in rest do
			if Items.Rarity(item) == rarity then
				table.insert(out, { Item = item, Rarity = rarity, Chance = each })
			end
		end
	end
	return out
end

function CrateOdds.Shown(crate: Crate, boost: Boost?): { Chance }
	local chanceOf: { [any]: number } = {}
	for _, c in CrateOdds.Chances(crate, boost) do
		chanceOf[c.Item] = c.Chance
	end
	local items = CrateOdds.Items(crate)
	local out: { Chance } = {}
	-- The same order as Chances: fixed-odds items, then highest rarity first.
	for _, item in items do
		if fixedOdds(crate, item) then
			table.insert(
				out,
				{ Item = item, Rarity = Items.Rarity(item), Chance = chanceOf[item] or 0 }
			)
		end
	end
	for i = #Config.Rarity.Order, 1, -1 do
		local rarity = Config.Rarity.Order[i]
		for _, item in items do
			if not fixedOdds(crate, item) and Items.Rarity(item) == rarity then
				table.insert(out, { Item = item, Rarity = rarity, Chance = chanceOf[item] or 0 })
			end
		end
	end
	return out
end

function CrateOdds.Pick(chances: { Chance }, roll: number): any
	if #chances == 0 then
		return nil
	end
	local total = 0
	for _, c in chances do
		total += c.Chance
	end
	-- Floats, not whole numbers, so a 0.1% (or 0.001%) chance is exact.
	local target = math.clamp(roll, 0, 1) * total
	local sum = 0
	for _, c in chances do
		sum += c.Chance
		if target < sum then
			return c.Item
		end
	end
	return chances[#chances].Item -- roll was (nearly) 1: rounding can leave a tiny gap
end

function CrateOdds.Roll(crate: Crate, rng: Random, boost: Boost?): any
	return CrateOdds.Pick(CrateOdds.Chances(crate, boost), rng:NextNumber())
end

function CrateOdds.Reel(
	crate: Crate,
	winnerId: string,
	rng: Random,
	cards: number,
	winIndex: number,
	boost: Boost?
): { string }
	-- The odds actually rolled (with the same boost), so the strip is an honest picture.
	local chances = CrateOdds.Chances(crate, boost)
	local count = math.max(1, math.floor(cards))
	local win = math.clamp(math.floor(winIndex), 1, count)
	-- No teasing near misses: the cards next to the winner (Config.Crates.Opening.TeaseGuard
	-- places either side) are drawn only from the rarities up to the one actually won, with
	-- their real chances among those. Every other card is an honest draw from the whole crate.
	local guard = math.max(0, math.floor(tonumber(Config.Crates.Opening.TeaseGuard) or 0))
	local winner = Items.Get(winnerId)
	local wonLevel = if winner then CrateOdds.RarityIndex(Items.Rarity(winner)) else nil
	local near: { Chance } = chances
	if guard > 0 and wonLevel then
		near = {}
		for _, c in chances do
			if CrateOdds.RarityIndex(c.Rarity) <= wonLevel then
				table.insert(near, c)
			end
		end
	end
	local reel = table.create(count, winnerId)
	for i = 1, count do
		if i ~= win then
			local pool = if math.abs(i - win) <= guard then near else chances
			local item = CrateOdds.Pick(pool, rng:NextNumber())
			reel[i] = if item then item.Id else winnerId
		end
	end
	return reel
end

-- "12.500" -> "12.5", "24.000" -> "24".
local function trimZeros(digits: string): string
	if digits:find("%.") then
		digits = digits:gsub("0+$", ""):gsub("%.$", "")
	end
	return digits
end

--[[
	A chance (percent) as players see it, exactly:
	  from 1% up: 3 decimals, trailing zeros removed ("5.082%", "24%", "4.8%", "49.978%")
	  under 1%: 4 significant figures ("0.5%", "0.02%", "0.04442%", "0.1235%", "0.0001%")
	A chance is never rounded to 0% or 100%: only a real 0 shows "0%" (and 100 or more "100%");
	a chance just under 100 gets more decimals ("99.9999%").
]]
function CrateOdds.Format(percent: number): string
	if not (percent > 0) then
		return "0%"
	elseif percent >= 100 then
		return "100%"
	end
	local decimals = 3
	if percent < 1 then
		decimals = 3 - math.floor(math.log10(percent))
	end
	local digits = ("%." .. decimals .. "f"):format(percent)
	-- Rounding up to "100" (or "1.000" for a chance just under 1%: fine, it isn't 0 or 100).
	while (tonumber(digits) or 0) >= 100 and decimals < 12 do
		decimals += 1
		digits = ("%." .. decimals .. "f"):format(percent)
	end
	return trimZeros(digits) .. "%"
end

-- Every digit that matters with 3 decimals: "6.123%", "0.020%", "0.0001%" (never "0.000%").
function CrateOdds.Exact(percent: number): string
	if percent > 0 and percent < 0.001 then
		local digits = ("%.6f"):format(percent):gsub("0+$", "")
		return digits .. "%"
	end
	return ("%.3f%%"):format(percent)
end

function CrateOdds.CoinPrice(crate: Crate): number?
	local price = crate.Price
	if type(price) == "number" and price > 0 and price == math.floor(price) then
		return price
	end
	return nil
end

function CrateOdds.ProductId(crate: Crate): number
	local robux = crate.Robux
	if type(robux) == "table" and type(robux.ProductId) == "number" then
		return robux.ProductId
	end
	return 0
end

-- (Unavailable crates too: a Deluxe crate bought while PremiumCrates is off still pays its coins.)
function CrateOdds.ByProductId(id: unknown): Crate?
	if typeof(id) ~= "number" or id == 0 then
		return nil
	end
	for _, crate in Config.Crates.List do
		if CrateOdds.ProductId(crate :: any) == id then
			return crate :: any
		end
	end
	return nil
end

function CrateOdds.List(): { Crate }
	local out: { Crate } = {}
	for _, crate in Config.Crates.List do
		if CrateOdds.Available(crate :: any) and #CrateOdds.Items(crate :: any) > 0 then
			table.insert(out, crate :: any)
		end
	end
	return out
end

return CrateOdds
