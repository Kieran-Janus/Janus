--!strict
--[[
	LOBBY MINIGAMES (Config.Minigames)

	Little games beside the lobby that you can play while a round is running. Each one has
	its own settings file next to this one:
	  CandyRush  click your candies; the first to clear them all wins   (CandyRush.luau)
	  WebScour   a quick Halloween scavenger hunt in the spider webs     (WebScour.luau)
	Turn them on/off in Config.Features; their areas are in Config.Lobby.Zones.

	Effects (below) are the little celebrations shared by Candy Rush, Web Scour, the secret
	pumpkins and both parkour courses: sparkle bursts, "+1"s, confetti, pops. They are only
	for fun on each player's own screen: the games work exactly the same with them off.
	Each game also has its own Effects table (its On switch and its own numbers).
]]

return {
	CandyRush = require(script.Parent.CandyRush),
	WebScour = require(script.Parent.WebScour),

	-- Shared celebration effects (src/client/MinigameFx.luau) ---------------------------------
	Effects = {
		On = true, -- false = no extra celebrations in ANY lobby minigame (one switch for all)
		PhoneShare = 0.5, -- phones make this share of the particles and confetti (smoother)
		-- Sparkle bursts in the world (made on this computer only, never solid)
		Burst = {
			Lifetime = { Min = 0.35, Max = 0.8 }, -- seconds each sparkle lives
			Speed = { Min = 6, Max = 12 }, -- studs per second they fly out
			Size = 0.45, -- studs across at the start (they shrink to nothing)
		},
		-- Floating "+1" words on the screen
		FloatText = {
			Rise = 46, -- pixels it floats up
			Seconds = 0.8, -- how long it takes to float up and fade
			TextSize = 26,
		},
		-- Confetti falling over the screen
		Confetti = {
			Seconds = 1.8, -- how long a piece takes to fall
			Spread = 0.6, -- seconds between the first and the last piece starting
			Colors = {
				Color3.fromRGB(255, 105, 180), -- pink
				Color3.fromRGB(255, 200, 60), -- gold
				Color3.fromRGB(120, 230, 120), -- green
				Color3.fromRGB(70, 180, 255), -- blue
				Color3.fromRGB(180, 110, 255), -- purple
				Color3.fromRGB(255, 140, 30), -- orange
			},
		},
		-- Words and banners that "punch" in (start big, settle to their size)
		Punch = {
			Scale = 1.5, -- how big they start
			Seconds = 0.28, -- how long they take to settle
		},
	},
}
