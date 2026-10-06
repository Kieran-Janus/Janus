--!strict
--[[
	PUMPKIN HIDE & SEEK (Config.HideSeek)

	A player-vs-player mode (on/off: Config.Features.HideSeek). Hiders turn into pumpkins and
	hide among the map's decoy pumpkins while the seekers count in the seeker hut. Then the
	seekers come out with candy guns: a candy that hits a hider's pumpkin tags them, and a
	tagged hider joins the seekers. Seekers win when every pumpkin is found; the pumpkins win
	if anyone is still hidden at 0:00. Maps: Pumpkin Farm and Hedge Maze (Config.Modes.Playlists).

	Hiders should be fairly easy to find. If rounds keep ending with lots of hiders never found,
	make them giggle more often (GiggleInterval) or glow sooner (GlowLastSeconds); if the seekers
	win too fast, do the opposite.
	Code: src/server/Modes/HideSeek.luau (the round), src/server/Modes/CandyGun.luau (the gun),
	src/server/Build/HidingPumpkin.luau (the pumpkin look), src/client/HideSeekUI.luau (screen).
]]

return {
	-- Teams ---------------------------------------------------------------------------------------
	SeekerRatio = 0.25, -- share of players who start as seekers (rounded down): 8 players = 2
	MinSeekers = 1, -- at least this many seekers (there is always at least 1 hider too)
	-- One player alone (testing in Studio): "Seeker" (practise the candy gun on the decoys) or
	-- "Hider" (try being a pumpkin). The round then just runs until the time is up.
	SoloRole = "Seeker",
	TaggedBecomeSeekers = true, -- a found pumpkin joins the seekers (false = watches as a ghost)
	TaggedSeekerDelay = 3, -- seconds before a found pumpkin gets their own candy gun

	-- Times ----------------------------------------------------------------------------------------
	HeadStart = 15, -- seconds the hiders get to hide while the seekers count in the hut
	Duration = 165, -- seconds of seeking after that (15 + 165 = a 3 minute round)

	-- Making hiders fairly easy to find ------------------------------------------------------------
	GiggleInterval = 20, -- every hider giggles and puffs sparkles about this often (seconds)
	GiggleJitter = 4, -- up to this many seconds earlier or later, so they don't all giggle at once
	FirstGiggleAfter = 10, -- seconds after the seekers come out before the first giggles
	TrailMinSpeed = 3, -- a hider moving faster than this (studs a second) leaves a faint leaf trail
	GlowLastSeconds = 30, -- hiders glow softly for the last this-many seconds of the round

	-- Fair play ------------------------------------------------------------------------------------
	-- A hider who resets (or dies) once the seekers are out leaves their pumpkin where it was
	-- (it can still be found) and comes back to it, so resetting is no way to escape.
	FallMargin = 20, -- ...unless the pumpkin fell this many studs below the map's floor
	-- Lobby spectators and ghosts only watch seekers: watching a hider shows where they hide
	-- (and someone could tell the seekers). true = hiders can be watched too.
	SpectateHiders = false,
	HideChatBubbles = true, -- no chat bubbles during a round: they'd float over the hidden pumpkins
	-- More seekers than seeker pads (the hut has 4)? The extra ones line up in rows in front of
	-- the pads, this many studs apart, at most SpawnRows rows deep.
	SpawnRowSpacing = 3.5,
	SpawnRows = 3,

	-- Coins at the end of the round (the friend bonus is added on top) ---------------------------
	Rewards = {
		PerTag = 10, -- for every pumpkin you tag
		HiderSurvived = 30, -- a pumpkin that was never found
		PerMinuteHidden = 5, -- a found pumpkin: for every full minute it stayed hidden
		WinningTeam = 10, -- everyone on the winning side
		Played = 5, -- everyone who took part
	},

	-- Candy gun (seekers) --------------------------------------------------------------------------
	Gun = {
		Name = "Candy Gun", -- the tool's name in the backpack bar
		FireCooldown = 0.6, -- seconds between candies
		DecoyPenalty = 1.5, -- extra seconds to wait after hitting a decoy (so spraying doesn't work)
		MaxRange = 160, -- studs
		HitTolerance = 1.5, -- a candy passing this close to a hider's pumpkin still tags it (lag, phones)
		ProjectileSpeed = 150, -- studs a second the candy flies (looks only: the hit is decided at once)
		MaxFlightSeconds = 0.7, -- long shots fly at least this fast
		SplatSeconds = 4, -- how long candy splats stay before fading
		MaxSplats = 40, -- oldest splats disappear first (keeps phones smooth)
		CandyColors = { -- each candy picks one at random
			Color3.fromRGB(255, 110, 180), -- strawberry pink
			Color3.fromRGB(110, 230, 190), -- mint
			Color3.fromRGB(255, 220, 70), -- lemon
			Color3.fromRGB(120, 170, 255), -- blueberry
			Color3.fromRGB(190, 120, 255), -- grape
		},
		Colors = { -- the gun itself
			Body = Color3.fromRGB(250, 245, 250),
			Stripe = Color3.fromRGB(235, 60, 90),
			Hopper = Color3.fromRGB(255, 140, 200),
			Grip = Color3.fromRGB(120, 70, 160),
		},
	},

	-- The pumpkin look: hiders AND the decoys on the maps use these, so hiders blend in ----------
	Pumpkin = {
		Width = 4, -- studs across, before the random size change
		Height = 3.3, -- studs tall
		SizeVariation = 0.12, -- each pumpkin is up to 12% bigger or smaller
		Colors = { -- each pumpkin picks one, then nudges it a little (ColorVariation)
			Color3.fromRGB(255, 136, 28),
			Color3.fromRGB(245, 118, 22),
			Color3.fromRGB(255, 158, 46),
			Color3.fromRGB(236, 104, 18),
		},
		ColorVariation = 0.08, -- 0 = exact colours above, 0.2 = big differences
		GrooveShade = 0.22, -- how much darker the grooves between the ribs are
		StemColor = Color3.fromRGB(96, 120, 52),
		LeafColor = Color3.fromRGB(92, 160, 64),
		LeafChance = 0.6, -- share of pumpkins with a little leaf
	},

	-- Hints that give hiders away ------------------------------------------------------------------
	Effects = {
		SparkleColor = Color3.fromRGB(255, 230, 140), -- the giggle puff
		SparkleCount = 14,
		LeafColors = { Color3.fromRGB(206, 120, 40), Color3.fromRGB(170, 90, 36) }, -- the trail
		LeafRate = 7, -- leaves a second while moving
		GlowColor = Color3.fromRGB(255, 190, 90), -- last seconds
		GlowRange = 10,
		GlowBrightness = 1.4,
		GlowOutline = Color3.fromRGB(255, 230, 160),
	},

	-- Sounds ("" = silent). Free Creator Store audio; swap any id for one you like.
	Sounds = {
		-- 3D, from the hider's pumpkin (a squeaky little giggle; any kid-friendly giggle works)
		Giggle = {
			SoundId = "rbxassetid://117491181431951",
			Volume = 0.8,
			PitchMin = 1.5,
			PitchMax = 1.8,
			RollOffMin = 12,
			RollOffMax = 110,
		},
		Shoot = {
			SoundId = "rbxassetid://87437544236708",
			Volume = 0.6,
			PitchMin = 0.7,
			PitchMax = 0.85,
		},
		Splat = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.5,
			PitchMin = 0.6,
			PitchMax = 0.75,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		Tagged = { SoundId = "rbxassetid://1841209502", Volume = 0.6 }, -- you tagged someone / got found
		-- When the seekers are let out ("" = silent: the normal round-start sound plays then anyway).
		Released = { SoundId = "", Volume = 0.6 },
	},

	-- Words on screen ------------------------------------------------------------------------------
	Text = {
		HiderRole = "You're a PUMPKIN - hide!",
		HiderTip = "Sit still next to other pumpkins. You giggle every %d seconds!",
		SeekerRole = "You're a SEEKER - find the pumpkins!",
		SeekerTip = "Click or tap a pumpkin to throw candy. Decoys slow you down!",
		Counting = "COUNTING... %d",
		CountingTip = "No peeking! The pumpkins are hiding.",
		Released = "Ready or not, here they come!", -- hiders, when the seekers come out
		SeekerGo = "GO! Find the pumpkins!", -- seekers, when they come out
		FoundYou = "You were found! Now you're a SEEKER!",
		FoundGhost = "You were found! Watch the rest of the round.",
		Tagged = "TAGGED!",
		TaggedBy = "%s found %s!",
		Decoy = "Just a pumpkin!",
		HidersLeft = "Pumpkins left: %d",
		Seekers = "Seekers: %d",
		YourTags = "Your tags: %d",
		Glow = "The pumpkins are glowing!",
		TapHint = "Tap a pumpkin to throw candy",
		-- Results screen
		ScoreLabel = "Tags",
		MvpLine = "%s tagged %d pumpkins!",
		SeekersWin = "The Seekers found every pumpkin!",
		HidersWin = "The Pumpkins win! %d never found.",
		NoSeekers = "The seekers all left: the Pumpkins win!",
		TimeUp = "Time's up!",
		TeamHider = "Pumpkin",
		TeamSeeker = "Seeker",
		BadgeHidden = "Never found!",
		BadgeFound = "Found",
		BadgeSeeker = "Seeker",
		StatHidden = "hid %d:%02d", -- minutes:seconds a pumpkin stayed hidden
	},

	-- Screen colours
	Colors = {
		Hider = Color3.fromRGB(255, 140, 30),
		Seeker = Color3.fromRGB(255, 110, 180),
		Blindfold = Color3.fromRGB(28, 16, 40),
		Tagged = Color3.fromRGB(255, 230, 90),
	},
}
