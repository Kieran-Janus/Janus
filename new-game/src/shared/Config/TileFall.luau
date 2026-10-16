--!strict
--[[
	CRUMBLING CRYPT (Config.TileFall), the "falling tiles" party game (mode id TileFall).

	Everyone stands on a floor of stone slabs (2 or 3 layers, with gaps between them) over a
	pit of glowing green goo. A slab you step on cracks, then drops after CrumbleSeconds and
	never comes back. Keep moving! Fall through every layer into the goo and you're out (you
	watch as a ghost). The last player standing wins; playing alone, survive as long as you can.
	On/off: Config.Features.TileFall (off = the vote never offers it).

	Easy tweaks:
	  Difficulty.Easy / .Hard   how many layers, slab size, how fast slabs drop, the safe start,
	                            the round length, when "sudden death" starts, coin multiplier
	  EndWhenOneLeft            false = keep playing until the clock runs out, even with 1 left
	  Rewards                   coins
	  Text                      every message players see
	The crypt itself (how big the slab floor is, layer heights, candles, bats, colours) is in
	src/shared/Config/Maps/CrumblingCrypt.luau.
	The code: src/server/Modes/TileFall.luau (server), src/server/Modes/TileFallBoard.luau (builds
	the slabs), src/client/TileFallUI.luau (screen, slab shake and falling pieces).
]]

return {
	-- The round ----------------------------------------------------------------------------------
	IntroSeconds = 5, -- "Get ready": everyone waits on their spot (nothing crumbles yet)
	-- With 2+ players the round ends as soon as only this many (or fewer) are still standing.
	-- Playing alone, it ends when you fall or the clock runs out.
	EndWhenOneLeft = true, -- false = always play until the clock runs out
	LastStanding = 1,
	CelebrateSeconds = 3, -- after the end: the winner's moment on the map before the results
	SampleSeconds = 0.1, -- how often the server checks where everyone stands (0.1 = 10 times a second)

	-- Easy and Hard (the vote picks one; Config.Modes.List.TileFall.UsesDifficulty = true).
	Difficulty = {
		Easy = {
			Layers = 5, -- floors of slabs (max 5: the crypt is built for 5, Board in its map file)
			TileSize = 12, -- studs across one slab (bigger = easier)
			CrumbleSeconds = 1.8, -- seconds from the first crack until the slab drops
			GraceSeconds = 6, -- after GO! nothing cracks for this long
			Duration = 150, -- the clock (seconds)
			SuddenDeathAfter = 100, -- seconds after GO! when random slabs start cracking by themselves
			RewardMultiplier = 1, -- coins x this
		},
		Hard = {
			Layers = 4,
			TileSize = 8,
			CrumbleSeconds = 0.7,
			GraceSeconds = 1.5,
			Duration = 180,
			SuddenDeathAfter = 75,
			RewardMultiplier = 2,
		},
	},

	-- Sudden death: so a round can't go on for ever, after SuddenDeathAfter seconds this many
	-- random slabs start cracking every SuddenDeathEvery seconds (and one more each time).
	SuddenDeath = {
		On = true,
		Every = 2, -- seconds
		Tiles = 2, -- slabs the first time...
		Grow = 1, -- ...plus this many more each time after
		MaxTiles = 10,
	},

	-- Falling out -----------------------------------------------------------------------------------
	-- You're out when your body is lower than this many studs above the goo (the lowest layer is
	-- Board.TopHeight - (Layers - 1) x Board.LayerSpacing above it in Config/Maps/CrumblingCrypt.luau).
	OutHeight = 6,
	-- Resetting or dying also counts as falling: you're out (no free respawn back on the slabs).

	-- Anti-cheat (src/shared/SpeedCheck.luau) -------------------------------------------------------
	-- Moving faster than anyone can run (a teleport or fly cheat) puts you back where you were.
	MaxMoveSpeed = 40, -- studs per second sideways...
	SlackStuds = 14, -- ...plus this many for lag (counted once per SpeedWindowSeconds)
	MaxRiseSpeed = 14, -- studs per second upwards (jumping is fine, flying up isn't)...
	RiseSlack = 10, -- ...plus this many (one jump)
	SpeedWindowSeconds = 1,
	StandReach = 8, -- a slab counts as "under you" if its top is at most this far below your body
	-- Hovering: with no slab under you for this long (floating or flying), you're out.
	MaxAirSeconds = 4,
	-- Leaving the crypt: further than this past the slab floor's edge (or this high above it) = out.
	BoundsMargin = 10,
	MaxHeightAbove = 30,

	-- Looks (the server sets them, every screen sees them) --------------------------------------------
	CrackColor = Color3.fromRGB(150, 230, 90), -- a cracking slab glows goo-green...
	CrackMaterial = Enum.Material.CrackedLava, -- ...with cracks
	-- Each screen also shakes cracking slabs and shows falling pieces (src/client/TileFallUI.luau).
	Effects = {
		On = true, -- false = slabs just change colour and vanish
		ShakeStuds = 0.15, -- how far a cracking slab shakes
		Range = 140, -- only slabs this close to your camera shake and fall (phones too)
		MaxFalling = 24, -- at most this many falling pieces at once (8 on phones)
		PhoneMaxFalling = 8,
		FallSeconds = 0.9,
		FallStuds = 14,
	},

	-- Coins and score ---------------------------------------------------------------------------------
	-- Score = seconds you stayed up. Place 1 = the last one standing (with 2+ players, everyone still
	-- up when the clock runs out shares 1st). Coins are multiplied by the difficulty's
	-- RewardMultiplier. The winner(s) also get Config.Rewards.TopCollectorWins Wins.
	Rewards = {
		PlayCoins = 10, -- everyone who took part
		CoinsPer10Seconds = 2, -- for every 10 seconds you stayed up...
		MaxTimeCoins = 30, -- ...at most this many
		PlaceCoins = { 30, 15, 8 }, -- 1st, 2nd, 3rd (only with 2+ players)
		SoloSurviveCoins = 30, -- alone: stayed up until the clock ran out
	},

	-- Words ---------------------------------------------------------------------------------------------
	Text = {
		GetReady = "Get ready!",
		Hint = "Slabs crack where you step. Keep moving!",
		SoloHint = "Stay up as long as you can!",
		Go = "GO!",
		PlayersLeft = "Players left: %d",
		Time = "%d:%02d",
		SuddenDeath = "Hurry! The crypt is crumbling!",
		Out = "Splash! You fell in the goo!",
		Watching = "Watching... (you're a ghost now)",
		Winner = "LAST ONE STANDING!",
		SoloWinner = "YOU SURVIVED!",
		WinnerHint = "The crypt couldn't get you!",
		-- Results screen
		ScoreLabel = "Seconds",
		StatPlace = "%s place", -- "1st place"
		BadgeWinner = "Last standing!",
		BadgeStanding = "Still up!",
		BadgeFell = "Fell in",
		WinnerOne = "%s is the last one standing!",
		WinnerMany = "%d players stayed up!",
		WinnerNobody = "The crypt got everyone!",
		SoloSurvived = "You survived the Crumbling Crypt!",
		SoloFell = "You stayed up %d seconds!",
		MvpLine = "%s stayed up the longest (%d s)!",
	},
	Colors = {
		Info = Color3.fromRGB(150, 255, 110),
		Out = Color3.fromRGB(255, 110, 110),
		Winner = Color3.fromRGB(255, 210, 70),
		SuddenDeath = Color3.fromRGB(255, 140, 60),
	},
	-- Sounds only you hear
	Sounds = {
		Out = { SoundId = "rbxassetid://9113854528", Volume = 0.7 },
		Winner = { SoundId = "rbxassetid://1841209502", Volume = 0.7 },
	},
	WinnerConfetti = 60, -- confetti pieces for the winner (fewer on phones)
}
