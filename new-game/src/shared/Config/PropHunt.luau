--!strict
--[[
	PROP HUNT (Config.PropHunt)

	A player-vs-player mode (on/off: Config.Features.PropHunt). Played on The Haunted House
	(src/shared/Config/Maps/HauntedHouse.luau). HIDERS turn into things on the map (pumpkins,
	chairs, skulls, coffins, cauldrons...) and hide while the FINDERS wait in the Finder Hut.
	Then the finders come out wearing pumpkin heads, with Pumpkin Cannons: a pumpkin that hits
	a disguised hider finds them, and found hiders become finders too. Finders win when every
	hider is found; hiders win if anyone is still hidden at 0:00.

	How to play (also on phones and gamepads):
	  Hiders   look at a thing near you (or just stand next to it) and press E / the big
	           "BECOME IT" button / gamepad X. Q (or the LOCK button, gamepad Y) locks you in
	           place so you don't wobble. T (or the TAUNT button, gamepad L1) giggles for bonus
	           coins (it gives you away a little!).
	  Finders  click or tap a thing to fire a pumpkin at it (gamepad: right trigger at the
	           crosshair, phones: the FIRE button shoots at the middle of the screen). Hitting a
	           thing that is NOT a hider makes you wait a little longer (Cannon.PropPenalty).

	Easy vs Hard: the vote picks a difficulty (Config.Difficulty). Each one has its own block
	in Difficulty below: Easy gives hiders a longer head start and more prop changes, and gives
	finders more hints (hiders giggle on their own and glow near the end). If rounds keep
	ending with hiders never found, make them giggle more often (GiggleInterval) or glow
	sooner (GlowLastSeconds); if the finders win too fast, do the opposite.

	Code: src/server/Modes/PropHunt.luau (the round), src/server/Modes/PropHuntRules.luau
	(scores), src/server/Modes/PropHuntCannon.luau (the cannon), src/server/Maps/HauntedHouse.luau
	(the map), src/client/PropHuntUI.luau (screen and buttons), src/client/PropHuntCannon.luau
	(aiming and pumpkin effects).
]]

return {
	-- Teams ---------------------------------------------------------------------------------------
	FinderRatio = 0.25, -- share of players who start as finders (rounded down): 8 players = 2
	MinFinders = 1, -- at least this many finders (there is always at least 1 hider too)
	-- One player alone (testing in Studio with "Start round now"): "Hider" (try being a prop)
	-- or "Seeker" (practise the cannon). The round then just runs until the time is up.
	SoloRole = "Hider",
	FoundBecomeFinders = true, -- a found hider gets a pumpkin head and a cannon (false = ghost)
	FoundFinderDelay = 3, -- seconds before a found hider gets their own cannon

	-- Easy and Hard (the difficulty the vote picked) ---------------------------------------------
	Difficulty = {
		Easy = {
			HeadStart = 40, -- seconds hiders get to pick a thing and hide (finders wait in the hut)
			Duration = 170, -- seconds of finding after that
			-- how many times a hider can turn into something else once the finders are out
			-- (as many times as you like during the head start)
			PropChanges = 10,
			GiggleInterval = 20, -- every hider giggles on their own about this often (0 = never)
			GlowLastSeconds = 60, -- hiders glow softly for the last this-many seconds (0 = never)
			PropPenalty = 0.5, -- extra seconds a finder waits after hitting a thing that isn't a hider
			HitTolerance = 3, -- a pumpkin passing this close to a hider still finds them
			RewardMultiplier = 1, -- coins x this
		},
		Hard = {
			HeadStart = 30,
			Duration = 200,
			PropChanges = 4,
			GiggleInterval = 0,
			GlowLastSeconds = 0,
			PropPenalty = 2.5,
			HitTolerance = 1.5,
			RewardMultiplier = 2,
		},
	},

	-- Turning into things (hiders) -----------------------------------------------------------------
	Disguise = {
		Range = 16, -- studs: you can only become a thing this close to you
		Cooldown = 1.5, -- seconds between changes
		StartAsProp = true, -- hiders start as a random small thing (so they're never seen as players)
		-- The things hiders start as (prop names, see docs/CUSTOMIZE.md); any tagged thing works
		-- with E / BECOME IT.
		StartProps = { "Pumpkin", "Skull", "Crate", "Candle", "Books", "Potion" },
		MaxSize = 9, -- studs: things bigger than this (longest side) can't be copied
	},
	Lock = {
		Enabled = true, -- hiders can lock themselves in place (no wobbling)
	},
	Taunt = {
		Cooldown = 12, -- seconds between taunts
		Points = 1, -- score for each taunt after the finders are out (shown as "Taunts")
		MaxCounted = 10, -- taunts after this many still play, but give nothing more
	},

	-- Fair play ------------------------------------------------------------------------------------
	-- A hider who resets (or dies) once the finders are out leaves their thing where it was (it
	-- can still be found) and comes back to it, so resetting is no way to escape.
	FallMargin = 20, -- ...unless it fell this many studs below the map's floor
	-- Lobby spectators and ghosts only watch finders: watching a hider shows where they hide.
	SpectateHiders = false,
	HideChatBubbles = true, -- no chat bubbles during a round: they'd float over hidden hiders
	-- More finders than pads in the Finder Hut (it has 4)? Extra ones line up in rows.
	SpawnRowSpacing = 3.5,
	SpawnRows = 3,

	-- Coins at the end of the round (x the difficulty's RewardMultiplier, friend bonus on top) ----
	Rewards = {
		PerFind = 10, -- for every hider you find
		HiderSurvived = 30, -- a hider who was never found
		PerMinuteHidden = 5, -- a found hider: for every full minute they stayed hidden
		PerTaunt = 2, -- for every taunt that counted
		WinningTeam = 10, -- everyone on the winning side
		Played = 10, -- everyone who took part
	},

	-- The finders' look: a pumpkin head (a skin head piece, src/shared/HeadPieces.luau). Their own
	-- look comes back after the round. A Model named "PropHuntFinder" in
	-- ReplicatedStorage.Custom.Cosmetics replaces the head (src/shared/CustomAssets).
	FinderHead = {
		Head = "SkinPumpkin",
		Face = "Spooky", -- "Happy", "Spooky", "Surprised", "Sleepy", "Wink" or "Toothy"
		HeadColor = Color3.fromRGB(255, 130, 20),
		GlowColor = Color3.fromRGB(255, 220, 90),
	},

	-- Pumpkin Cannon (finders) -------------------------------------------------------------------
	Cannon = {
		Name = "Pumpkin Cannon", -- the tool's name in the backpack bar
		FireCooldown = 0.8, -- seconds between pumpkins
		MaxRange = 180, -- studs
		ProjectileSpeed = 120, -- studs a second the pumpkin flies (looks only: the hit is decided at once)
		MaxFlightSeconds = 0.8, -- long shots fly at least this fast
		SplatSeconds = 4, -- how long pumpkin splats stay before fading
		MaxSplats = 30, -- oldest splats disappear first (keeps phones smooth)
		Colors = {
			Barrel = Color3.fromRGB(40, 36, 48),
			Band = Color3.fromRGB(255, 140, 30),
			Wheel = Color3.fromRGB(90, 60, 40),
			Pumpkin = Color3.fromRGB(255, 130, 20),
			Splat = Color3.fromRGB(255, 150, 40),
		},
	},

	-- Hints that give hiders away --------------------------------------------------------------------
	Effects = {
		SparkleColor = Color3.fromRGB(255, 230, 140), -- the giggle / taunt puff
		SparkleCount = 16,
		GlowColor = Color3.fromRGB(255, 190, 90), -- last seconds
		GlowRange = 10,
		GlowBrightness = 1.4,
		GlowOutline = Color3.fromRGB(255, 230, 160),
		TargetColor = Color3.fromRGB(120, 255, 160), -- outline of the thing a hider would become
	},

	-- Keys (PC and gamepad). Phones get on-screen buttons.
	Keys = {
		Become = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
		Lock = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY },
		Taunt = { Enum.KeyCode.T, Enum.KeyCode.ButtonL1 },
		Fire = { Enum.KeyCode.ButtonR2 }, -- (PC fires with the left mouse button)
	},

	-- Sounds ("" = silent). Free Creator Store audio; swap any id for one you like.
	Sounds = {
		Giggle = { -- 3D, from the hider's thing (giggles and taunts)
			SoundId = "rbxassetid://117491181431951",
			Volume = 0.8,
			PitchMin = 1.3,
			PitchMax = 1.7,
			RollOffMin = 12,
			RollOffMax = 110,
		},
		Fire = {
			SoundId = "rbxassetid://87437544236708",
			Volume = 0.7,
			PitchMin = 0.45,
			PitchMax = 0.55,
		},
		Splat = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.6,
			PitchMin = 0.45,
			PitchMax = 0.6,
			RollOffMin = 8,
			RollOffMax = 70,
		},
		Found = { SoundId = "rbxassetid://1841209502", Volume = 0.6 }, -- you found someone / got found
		Become = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.4,
			PitchMin = 1.6,
			PitchMax = 1.9,
		},
	},

	-- Words on screen ------------------------------------------------------------------------------
	Text = {
		HiderRole = "You're a HIDER - turn into a thing!",
		HiderTip = "Walk up to anything and press E (or tap BECOME IT). Then sit still!",
		SeekerRole = "You're a FINDER - find the hiders!",
		SeekerTip = "Fire pumpkins at things that look wrong. Real things slow you down!",
		Counting = "COUNTING... %d",
		CountingTip = "The hiders are turning into things. No peeking!",
		Released = "The finders are coming!", -- hiders, when the finders come out
		SeekerGo = "GO! Find the hiders!", -- finders, when they come out
		FoundYou = "Peekaboo, found you! Now you're a FINDER!",
		FoundGhost = "Peekaboo, found you! Watch the rest of the round.",
		Found = "FOUND!",
		FoundBy = "%s found %s!",
		Decoy = "Just a %s! Wait...",
		HidersLeft = "Hiders left: %d",
		Finders = "Finders: %d",
		YourFinds = "Found: %d",
		ChangesLeft = "Changes: %d",
		Glow = "The hiders are glowing!",
		BecomeButton = "BECOME IT",
		BecomeKey = "[E]",
		BecomeTarget = "Become the %s", -- over the highlighted thing
		NothingNear = "Walk up to a thing first!",
		NoChanges = "No changes left!",
		LockButton = "LOCK",
		UnlockButton = "UNLOCK",
		LockKey = "[Q]",
		Locked = "Locked in place",
		TauntButton = "TAUNT",
		TauntKey = "[T]",
		FireButton = "FIRE",
		TapHint = "Tap a thing (or press FIRE) to launch a pumpkin",
		Became = "You're a %s now!",
		-- Results screen
		ScoreLabel = "Score",
		MvpLine = "%s was the best: %d!",
		SeekersWin = "The Finders found every hider!",
		HidersWin = "The Hiders win! %d never found.",
		NoSeekers = "The finders all left: the Hiders win!",
		TimeUp = "Time's up!",
		TeamHider = "Hider",
		TeamSeeker = "Finder",
		BadgeHidden = "Never found!",
		BadgeFound = "Found",
		BadgeSeeker = "Finder",
		StatHidden = "hid %d:%02d", -- minutes:seconds a hider stayed hidden
		StatTaunts = "%d taunts",
	},

	-- What each thing is called on screen ("You're a skull now!"); a thing not listed here
	-- shows its prop name.
	PropLabels = {
		Pumpkin = "pumpkin",
		JackOLantern = "jack-o'-lantern",
		Crate = "crate",
		Barrel = "barrel",
		Gravestone = "gravestone",
		HayBale = "hay bale",
		Candle = "candle",
		Lantern = "lantern",
		Cauldron = "cauldron",
		Coffin = "coffin",
		Chair = "chair",
		Table = "table",
		Skull = "skull",
		Broom = "broom",
		Potion = "potion",
		Books = "pile of books",
	} :: { [string]: string },

	-- Screen colours
	Colors = {
		Hider = Color3.fromRGB(140, 255, 140),
		Seeker = Color3.fromRGB(255, 140, 30),
		Blindfold = Color3.fromRGB(26, 14, 34),
		Found = Color3.fromRGB(255, 230, 90),
		Button = Color3.fromRGB(70, 160, 90),
		Lock = Color3.fromRGB(90, 110, 190),
		Taunt = Color3.fromRGB(170, 80, 200),
		Fire = Color3.fromRGB(230, 110, 20),
	},
}
