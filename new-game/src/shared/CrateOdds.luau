--!strict
--[[
	Crate odds (shared by the server, which rolls, and the client, which shows the chances).
	Crates and their odds are in Config.Crates (src/shared/Config/Crates.luau).

	An item's chance = its rarity's odds / how many items of that rarity the crate has. A
	rarity the crate has no items of is left out and the others are scaled up to fill 100%,
	so the chances always add up to exactly what players are shown. An item with its own Odds
	(percent, e.g. the one-in-a-million skins: Odds = 0.0001) gets exactly that chance; the
	rest of the crate shares what is left by rarity. Items with OneInAMillion = true are only
	in their own themed crate, never in a rarity crate.

	CrateOdds.Get(id) -> crate?            the Config.Crates.List entry with that Id
	CrateOdds.List() -> { crate }          every crate that has at least one item, in order
	CrateOdds.Items(crate) -> { item }     the shop items the crate can give (never VIP-only)
	CrateOdds.RarityOdds(crate) -> { [rarity]: percent }   the odds actually used
	CrateOdds.Chances(crate) -> { Chance } every item with its chance in percent, highest
	                                       rarity first (sums to 100)
	CrateOdds.Pick(chances, roll) -> item  the item a roll (0 <= roll < 1) lands on
	CrateOdds.Roll(crate, rng) -> item?    a random item, using `rng` (a Random)
	CrateOdds.Reel(crate, winnerId, rng, cards, winIndex) -> { itemId }
	                                       the opening animation's strip: random picks from
	                                       the crate with the winner at winIndex. The cards
	                                       within Config.Crates.Opening.TeaseGuard places of
	                                       the winner are never rarer than the win (no fake
	                                       near misses)
	CrateOdds.RarityIndex(rarity) -> number its place in Config.Rarity.Order (1 = commonest)
	CrateOdds.Format(percent) -> string    "0.100%", or "0.0001%" for tiny chances
	CrateOdds.CoinPrice(crate) -> number?  coins to open it (nil = not sold for coins)
	CrateOdds.ProductId(crate) -> number   its Robux Developer Product id (0 = not for sale)
	CrateOdds.ByProductId(id) -> crate?    the crate a Developer Product opens
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
}

export type Chance = {
	Item: any, -- the Config.Shop.Items entry
	Rarity: string, -- its rarity id
	Chance: number, -- percent, 0-100
}

local CrateOdds = {}

function CrateOdds.Get(id: unknown): Crate?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, crate in Config.Crates.List do
		if crate.Id == id then
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

function CrateOdds.Items(crate: Crate): { any }
	local listed = listedIds()
	local rarity = crate.Rarity
	local out = {}
	for _, item in Config.Shop.Items do
		if item.VipOnly or type(item.Id) ~= "string" then
			continue
		end
		local mine = item.Crate == crate.Id
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

-- The configured odds for this crate (before leaving out rarities it has no items of).
local function configuredOdds(crate: Crate): { [string]: number }
	if type(crate.Odds) == "table" then
		return crate.Odds
	end
	if type(crate.Rarity) == "string" then
		return { [crate.Rarity] = 100 }
	end
	return Config.Crates.Odds
end

local function countByRarity(items: { any }): { [string]: number }
	local counts = {}
	for _, item in items do
		local rarity = Items.Rarity(item)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	return counts
end

local function scaledOdds(crate: Crate, counts: { [string]: number }): { [string]: number }
	local wanted = configuredOdds(crate)
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

-- An item's own fixed chance (percent) in `crate`, or nil. Only in its own themed crate.
local function fixedOdds(crate: Crate, item: any): number?
	local odds = item.Odds
	if type(odds) == "number" and odds > 0 and item.Crate == crate.Id then
		return odds
	end
	return nil
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

function CrateOdds.RarityOdds(crate: Crate): { [string]: number }
	local items = CrateOdds.Items(crate)
	local rest, share = shared(crate, items)
	local odds = scaledOdds(crate, countByRarity(rest))
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

function CrateOdds.Chances(crate: Crate): { Chance }
	local items = CrateOdds.Items(crate)
	local rest, share = shared(crate, items)
	local counts = countByRarity(rest)
	local odds = scaledOdds(crate, counts)
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

function CrateOdds.Roll(crate: Crate, rng: Random): any
	return CrateOdds.Pick(CrateOdds.Chances(crate), rng:NextNumber())
end

function CrateOdds.Reel(
	crate: Crate,
	winnerId: string,
	rng: Random,
	cards: number,
	winIndex: number
): { string }
	local chances = CrateOdds.Chances(crate)
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

-- A rarity's place in Config.Rarity.Order (1 = the commonest); unknown rarities count as the
-- commonest.
function CrateOdds.RarityIndex(rarity: string?): number
	return table.find(Config.Rarity.Order, rarity or "") or 1
end

-- A chance (percent) as players see it: "6.1%", "24%", and anything under 1% as
-- Config.Crates.SmallOdds ("<1%"). With SmallOdds = "" every digit that matters shows
-- instead ("0.020%", "0.0001%"): CrateOdds.Exact.
function CrateOdds.Format(percent: number): string
	local small = Config.Crates.SmallOdds
	if percent > 0 and percent < 1 and small ~= "" then
		return small
	end
	if percent < 1 then
		return CrateOdds.Exact(percent)
	end
	local shown = ("%.1f"):format(percent):gsub("%.0$", "")
	return shown .. "%"
end

-- Every digit that matters: "6.123%", "0.020%", "0.0001%" (never "0.000%").
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
		if #CrateOdds.Items(crate :: any) > 0 then
			table.insert(out, crate :: any)
		end
	end
	return out
end

return CrateOdds
