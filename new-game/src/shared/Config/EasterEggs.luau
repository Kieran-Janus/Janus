--!strict
--[[
	EASTER EGGS (Config.EasterEggs)

	Hidden pumpkins around the lobby (on/off: Config.Features.EasterEggs). Each one gives
	its coins once per player, ever (saved). In Studio an egg is any part tagged EasterEgg
	with the attributes EggId (matching an Id below) and Coins.
	  Id     unique name, saved in the player's data (never rename one that is live)
	  Name   shown when you find it
	  Coins  coins for finding it
	  Hint   a small clue shown in the egg progress list
	To add an egg: add a line here and place a tagged part with that EggId in the lobby.
]]

return {
	-- TODO(easter eggs agent): the egg list, e.g.
	-- { Id = "BehindTheShop", Name = "Shy Pumpkin", Coins = 50, Hint = "Shopkeepers hide things out back..." },
	List = {} :: { { Id: string, Name: string, Coins: number, Hint: string } },
}
