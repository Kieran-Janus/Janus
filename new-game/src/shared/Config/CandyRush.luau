--!strict
--[[
	CANDY RUSH (Config.Minigames.CandyRush)

	The candy stand in the lobby: stand on one of the coloured pads in front of the candy
	board. When at least MinPlayers stand on pads, a 3-2-1 countdown starts, then candies pop
	up one at a time in your lane of the board. Click (or tap) YOUR candy to grab it; the first
	to grab them all wins. Waiting alone? After Solo.AfterSeconds a solo "beat your time" run
	starts instead.
	On/off: Config.Features.CandyRush. Where it is: Config.Lobby.Zones.CandyRush.

	The stand's working parts are found by their tags (src/shared/Tags.luau), so you can move,
	resize or copy the stand in Studio and it keeps working:
	  CandyRushStation  the whole stand (a Model). A copy of it is a second, separate race.
	  CandyRushBoard    the board the candies pop up on (its big flat side faces the pads)
	  CandyRushPad      a join pad, with the attribute Lane = 1, 2, 3... Lane 1 is the left
	                    column of the board as you look at it.

	To tune it, change the numbers below (times in seconds, sizes in studs).
]]

return {
	-- The race ------------------------------------------------------------------------------
	Candies = 10, -- candies each player grabs to win
	MinPlayers = 2, -- players on pads needed to start a race (2 or more)
	CountdownSeconds = 3, -- the 3-2-1 before GO
	MaxRaceSeconds = 60, -- a race stops after this long; the player with the most candies wins
	NextCandyDelay = { Min = 0.1, Max = 0.35 }, -- wait before your next candy pops up
	MinClickSeconds = 0.12, -- a candy can't be grabbed faster than this after it appears (stops auto-clickers)
	ClickDistance = 32, -- how far away (studs) you can click a candy from
	ResultsSeconds = 5, -- the winner banner stays up this long, then the next race can start
	LeaveGraceSeconds = 1, -- stepping off your pad for less than this is fine (wobbles, jumps)
	CheckSeconds = 0.2, -- how often the server checks who is standing on the pads
	PadHeight = 8, -- studs above a pad that still count as standing on it (jumping is fine)
	PadEdgeMargin = 0.5, -- studs past a pad's edge that still count

	-- Solo practice: one player alone on a pad races the clock ----------------------------------
	Solo = {
		On = true, -- false = no solo runs (a race always needs MinPlayers)
		AfterSeconds = 6, -- waiting alone on a pad this long starts a solo run
	},

	-- Coins. Only players who grabbed at least MinCandies get any, and never more than DailyCap
	-- coins a day from Candy Rush (saved, so changing servers doesn't reset it).
	Rewards = {
		WinCoins = 25, -- the winner of a race
		PlayCoins = 5, -- everyone else who finished the race on their pad
		SoloCoins = 5, -- finishing a solo run
		MinCandies = 3, -- candies you must grab to earn anything
		CooldownSeconds = 15, -- race coins at most once per this many seconds
		SoloCooldownSeconds = 300, -- solo coins at most once per this many seconds
		DailyCap = 300, -- most Candy Rush coins one player can get per day (0 = no limit)
	},

	-- The candies ---------------------------------------------------------------------------------
	-- Kinds: "Wrapped" (a wrapped sweet), "Lollipop" and "CandyCorn". Each can be swapped for
	-- your own model: put a model called CandyRushWrapped / CandyRushLollipop /
	-- CandyRushCandyCorn in ReplicatedStorage.Custom.Props (assets/Props).
	Candy = {
		Size = 2.4, -- how big a candy is (studs)
		Kinds = { "Wrapped", "Lollipop", "CandyCorn" },
		Colors = { -- wrapped sweets and lollipops pick one of these
			Color3.fromRGB(255, 105, 180), -- bubblegum pink
			Color3.fromRGB(255, 140, 30), -- pumpkin orange
			Color3.fromRGB(150, 90, 230), -- grape purple
			Color3.fromRGB(80, 220, 140), -- lime green
			Color3.fromRGB(70, 180, 255), -- blue raspberry
			Color3.fromRGB(255, 70, 80), -- cherry red
		},
		CornColors = { -- candy corn, bottom to tip
			Color3.fromRGB(255, 205, 40),
			Color3.fromRGB(255, 130, 20),
			Color3.fromRGB(255, 250, 235),
		},
		EdgeMargin = 0.4, -- space kept free along the edges of each lane
		BottomSpace = 1.8, -- space kept free at the bottom of each lane (for the name)
		HitboxPadding = 0.8, -- the invisible click area is this much bigger (easier to tap)
	},

	-- The stand (src/server/Hub/Sections/CandyRush.luau builds it) ---------------------------------
	-- Changes here show after the hub is rebuilt (F8 > Rebuild hub, or Bake.Hub()); a hub saved
	-- in the place keeps the stand it was built with (move or resize its parts in Studio).
	Stand = {
		Lanes = 4, -- join pads / lanes the stand is built with (2 to 6)
		BoardWidth = 24, -- the candy board, studs
		BoardHeight = 12,
		BoardTilt = 12, -- degrees the board leans back
		BoardLift = 4, -- studs from the ground to the bottom of the board (above the players' heads)
		BoardBack = 7, -- how far behind the middle of the zone the board stands
		PadSize = 5, -- join pad width
		PadDistance = 9, -- from the board to the pads
		LaneColors = { -- lane 1, 2, 3... (the pads and the lane stripes on the board)
			Color3.fromRGB(255, 105, 180), -- pink
			Color3.fromRGB(80, 220, 140), -- mint
			Color3.fromRGB(70, 180, 255), -- blue
			Color3.fromRGB(255, 210, 50), -- lemon
			Color3.fromRGB(170, 110, 255), -- lilac
			Color3.fromRGB(255, 140, 30), -- orange
		},
		Colors = {
			Board = Color3.fromRGB(40, 24, 60), -- the board's face (dark, so candies pop)
			Frame = Color3.fromRGB(255, 250, 240), -- candy-cane white
			Stripe = Color3.fromRGB(255, 120, 30), -- candy-cane stripes
			Floor = Color3.fromRGB(255, 190, 220), -- checkered floor
			FloorAlt = Color3.fromRGB(255, 245, 250),
			Sign = Color3.fromRGB(120, 60, 170), -- the sign board
			SignText = Color3.fromRGB(255, 200, 60),
			Screen = Color3.fromRGB(30, 22, 40), -- the scoreboard
		},
	},

	-- The words (the sign, the scoreboard and the screen). %s = a name, %d = a number,
	-- %.1f = a time in seconds.
	Text = {
		SignTitle = "CANDY RUSH",
		SignSubtitle = "first to grab all the candy wins!",
		Idle = "Stand on a pad to play!",
		NeedMore = "Waiting for %d more player(s)...",
		SoloSoon = "Solo run in %d...",
		RaceOn = "Grab your candy!",
		NextRace = "Next race starts soon",
		Go = "GO!",
		Wins = "%s WINS!",
		SoloDone = "%s: %.1fs",
		TimeUp = "Time's up!",
		NoWinner = "Nobody wins this time",
		Record = "Fastest: %s %.1fs",
		NoRecord = "Fastest: nobody yet!",
		FreeLane = "Free pad", -- on the board, under a lane nobody stands on
		-- On the player's screen
		Title = "Candy Rush",
		YouWin = "YOU WIN!",
		YouLose = "%s won!",
		SoloFinish = "%.1f seconds!",
		NewBest = "New best time!",
		Best = "Your best: %.1fs",
		CoinsGot = "+%d coins",
		Out = "You left your pad: out of this race",
		OutTag = "out",
		You = "You",
		TooFew = "Grab more candies to earn coins",
		Cooldown = "No coins this time (cooldown)",
		DailyCap = "Daily Candy Rush coins reached",
		LaneTaken = "Someone is on this pad",
	},

	-- Little celebrations on the player's own screen (src/client/CandyRushUI.luau). Only for fun:
	-- grabs still count the moment you click. Shared numbers: Config.Minigames.Effects.
	Effects = {
		On = true, -- false = no sparkles, "+1"s, confetti or smooth bars (the race is the same)
		GrabSparkles = 14, -- sparkles where your candy was when you grab it (phones: fewer)
		PlusText = "+1", -- floats up next to your candy count
		BarSeconds = 0.22, -- lane progress bars slide to their new length in this many seconds
		CountdownScale = 1.9, -- the 3-2-1 / GO! starts this big and punches down to size
		CountdownTilt = 10, -- degrees it starts tilted (0 = straight)
		WinConfetti = 60, -- confetti pieces when YOU win (phones: fewer)
		BounceSeconds = 0.3, -- new candies bounce in over this many seconds
	},

	-- Sounds: "rbxassetid://..." or "" for none. The pop is heard by everyone near the stand;
	-- the others only by the player.
	Sounds = {
		Pop = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.6,
			PitchMin = 1.2,
			PitchMax = 1.5,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		Tick = { SoundId = "rbxassetid://134410911353980", Volume = 0.5 },
		Go = { SoundId = "rbxassetid://17798541626", Volume = 0.6 },
		Win = { SoundId = "rbxassetid://1841209502", Volume = 0.6 },
		Lose = { SoundId = "rbxassetid://9045119921", Volume = 0.4, PitchMin = 0.8, PitchMax = 0.8 },
	},
}
