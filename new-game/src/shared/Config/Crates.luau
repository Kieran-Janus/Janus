--!strict
--[[
	CRATES (Config.Crates)

	Crates give a random skin (on/off: Config.Features.Crates; Robux crates also need
	Config.Features.RobuxCrates). Each crate in List:
	  Id         unique name (don't rename once live)
	  Name       what players see
	  Price      coins to open one
	  ProductId  Robux developer product id (0 = not for sale with Robux yet)
	  Odds       % chance of each rarity (they should add up to 100)
	An item is in a crate when its Crate field is that crate's Id (Config/Skins/...), and
	the per-rarity crates draw from every item of their rarity. An item's chance is its
	rarity's odds divided by how many items of that rarity are in the crate. Players see
	every item and its chance before they buy.
]]

return {
	-- TODO(crates agent): the crate list, e.g.
	-- { Id = "PumpkinCrate", Name = "Pumpkin Crate", Price = 400, ProductId = 0,
	--   Odds = { Common = 70, Uncommon = 24.9, Rare = 5, Crazy = 0.1 } },
	List = {} :: { any },
}
