--!strict
--[[
	CRATE SKINS (added to Config.Shop.Items)

	Skins live in one file per crate theme in this folder (for example PumpkinSkins.luau),
	so each list stays short. Every file returns a list of shop items with the same fields
	as Config.Shop.Items, plus:
	  Rarity     "Common", "Uncommon", "Rare" or "Crazy" (sets the price, Config.Rarity)
	  Crate      the Id of the crate it can drop from (Config.Crates)
	  CrateOnly  true = only from crates, never sold in the shop
	To add a theme file: create it here, then add it to the list below.
	Config (init.luau) appends everything returned here to Config.Shop.Items.
]]

local themes: { { any } } = {
	-- TODO(crates agent): one require per theme file, e.g. require(script.PumpkinSkins),
}

local all: { any } = {}
for _, list in themes do
	for _, item in list do
		table.insert(all, item)
	end
end
return all
