--!strict
--[[
	LOBBY MINIGAMES (Config.Minigames)

	Little games beside the lobby that you can play while a round is running. Each one has
	its own settings file next to this one:
	  CandyRush  click your candies; the first to clear them all wins   (CandyRush.luau)
	  WebScour   a quick Halloween scavenger hunt in the spider webs     (WebScour.luau)
	Turn them on/off in Config.Features; their areas are in Config.Lobby.Zones.
]]

return {
	CandyRush = require(script.Parent.CandyRush),
	WebScour = require(script.Parent.WebScour),
}
