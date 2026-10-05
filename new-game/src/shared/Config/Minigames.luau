--!strict
--[[
	LOBBY MINIGAMES (Config.Minigames)

	Little games beside the lobby that you can play while a round is running.
	  CandyRush  click your candies; the first to clear them all wins
	             (on/off: Config.Features.CandyRush, area: Config.Lobby.Zones.CandyRush)
	  WebScour   a quick Halloween scavenger hunt in the spider webs
	             (on/off: Config.Features.WebScour, area: Config.Lobby.Zones.WebScour)
	Change the coins below to make winning worth more or less.
]]

return {
	CandyRush = {
		-- TODO(minigames agent): the rest of the Candy Rush settings go here.
		WinCoins = 25, -- coins for the winner of a race
	},
	WebScour = {
		-- TODO(minigames agent): the rest of the Web Scour settings go here.
		FinishCoins = 20, -- coins for finding everything in time
	},
}
