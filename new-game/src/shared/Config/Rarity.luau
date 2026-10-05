--!strict
--[[
	RARITY (Config.Rarity)

	Every shop item and crate skin has a Rarity: "Common", "Uncommon", "Rare" or "Crazy".
	  Name             what players see on the item's tag
	  Price            coins to buy an item of this rarity in the shop (an item with its own
	                   Price uses that instead)
	  Color            colour of the rarity tag and the crate reveal
	  DuplicateRefund  coins you get back when a crate gives you something you already own
	To make every Rare cheaper, change Levels.Rare.Price; every Rare item follows.
	Don't rename the ids (Common, Uncommon, ...): items and saves use them.
]]

return {
	Order = { "Common", "Uncommon", "Rare", "Crazy" }, -- lowest to highest
	Default = "Common", -- used for an item with no Rarity
	Levels = {
		Common = {
			Name = "Common",
			Price = 125,
			Color = Color3.fromRGB(150, 175, 140), -- soft grey-green
			DuplicateRefund = 30,
		},
		Uncommon = {
			Name = "Uncommon",
			Price = 500,
			Color = Color3.fromRGB(70, 150, 255), -- blue
			DuplicateRefund = 125,
		},
		Rare = {
			Name = "Rare",
			Price = 1000,
			Color = Color3.fromRGB(175, 90, 255), -- purple
			DuplicateRefund = 250,
		},
		Crazy = {
			Name = "CRAZY",
			Price = 100000,
			Color = Color3.fromRGB(255, 60, 200), -- hot pink
			Rainbow = true, -- the tag cycles through rainbow colours where the UI supports it
			DuplicateRefund = 25000,
		},
	},
}
