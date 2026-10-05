--!strict
--[[
	Shop item helpers (shared by the server and the client). Items are Config.Shop.Items
	entries, which include the crate skins from Config/Skins/.

	Items.Get(id) -> item?             the item with that Id (nil for unknown or non-strings)
	Items.Price(item) -> number?       coins to buy it in the shop: its own Price if it has
	                                   one, else its rarity's price. nil = can't be bought
	                                   (CrateOnly or VipOnly)
	Items.Rarity(item) -> string       its rarity id ("Common" if missing or misspelled)
	Items.RarityInfo(item) -> level    Config.Rarity.Levels[rarity] (Name, Price, Color, ...)
	Items.ForSlot(slot) -> { item }    every item for a slot, in Config order
	Items.ByCrate(crateId) -> { item } every item whose Crate field is crateId
	Items.CanBuyDirect(item) -> bool   true if the shop sells it for coins
]]

local Config = require(script.Parent.Config)

export type RarityLevel = {
	Name: string,
	Price: number,
	Color: Color3,
	DuplicateRefund: number,
	Rainbow: boolean?,
}

local Items = {}

-- Id -> item, built on first use (the list is complete once Config has loaded).
local index: { [string]: any }? = nil
local indexedCount = 0 -- how many items the index was built from

local function getIndex(): { [string]: any }
	local built = index
	if built then
		return built
	end
	local new: { [string]: any } = {}
	for _, item in Config.Shop.Items do
		if type(item.Id) == "string" and new[item.Id] == nil then
			new[item.Id] = item
		end
	end
	index = new
	indexedCount = #Config.Shop.Items
	return new
end

function Items.Get(id: unknown): any
	if typeof(id) ~= "string" then
		return nil
	end
	local byId = getIndex()
	local found = byId[id]
	if found == nil and #Config.Shop.Items ~= indexedCount then
		-- Items were added after the index was built: rebuild it once.
		index = nil
		found = getIndex()[id]
	end
	return found
end

function Items.Rarity(item: any): string
	local rarity = item and item.Rarity
	if type(rarity) == "string" and (Config.Rarity.Levels :: any)[rarity] then
		return rarity
	end
	return Config.Rarity.Default
end

function Items.RarityInfo(item: any): RarityLevel
	return (Config.Rarity.Levels :: any)[Items.Rarity(item)]
end

function Items.Price(item: any): number?
	if not item or item.CrateOnly or item.VipOnly then
		return nil
	end
	if type(item.Price) == "number" then
		return item.Price
	end
	return Items.RarityInfo(item).Price
end

function Items.CanBuyDirect(item: any): boolean
	return Items.Price(item) ~= nil
end

function Items.ForSlot(slot: string): { any }
	local list = {}
	for _, item in Config.Shop.Items do
		if item.Slot == slot then
			table.insert(list, item)
		end
	end
	return list
end

function Items.ByCrate(crateId: string): { any }
	local list = {}
	for _, item in Config.Shop.Items do
		if item.Crate == crateId then
			table.insert(list, item)
		end
	end
	return list
end

return Items
