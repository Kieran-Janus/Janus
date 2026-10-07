--!strict
--[[
	SCREEN MOTION (Config.ScreenMotion)

	The little animations on the Hide & Seek, ScareMaze, ghost, spectate, daily reward / codes,
	NPC dialogue, announcement and Voting Board screens (helper: src/client/ScreenFx.luau).
	They are only looks: every button press, vote and message happens at once, the animation
	plays on top, and every one of them ends on the real final state (shown, full size, the
	exact words and numbers).

	On = false turns all of them off here (everything shows still and at once).
	Config.UI.Motion.On = false turns them off too, with the rest of the game's UI motion.
	Times are in seconds; "scale" is a multiple of the normal size (1 = normal); distances are
	UI units (the size of a 1280 x 760 screen's pixels).
]]

return {
	On = true,
	PhoneShare = 0.5, -- phones get this share of the sparkles and confetti (they're smaller and slower)

	-- Sparkles flying out of a point on the screen (TAGGED!, ESCAPED!, the daily streak).
	Burst = {
		Size = 12, -- each sparkle starts this big...
		Distance = 110, -- ...flies about this far...
		Seconds = 0.6, -- ...in this long, shrinking and fading away
	},

	-- Pumpkin Hide & Seek (src/client/HideSeekUI.luau)
	HideSeek = {
		BannerSeconds = 4, -- how long "You're a PUMPKIN - hide!" stays
		FeedSeconds = 3.5, -- how long a message line ("X found Y!") stays
		FoundBannerSeconds = 2.5, -- after "You were found!", the role banner waits this long
		FadeSeconds = 0.4, -- banners fade away in this long
		RolePopScale = 1.5, -- the role banner starts this big...
		RolePopSeconds = 0.35, -- ...and snaps to its size in this long...
		RoleShakeDegrees = 8, -- ...starting tilted this much and wobbling straight
		RoleShakeSeconds = 0.5,
		TaggedPopScale = 1.9, -- "TAGGED!" punches in from this big
		TaggedPopSeconds = 0.3,
		TaggedShakeDegrees = 10,
		TaggedSparkles = 16, -- sparkles bursting out of "TAGGED!"
		TaggedColors = {
			Color3.fromRGB(255, 230, 120),
			Color3.fromRGB(255, 150, 60),
			Color3.fromRGB(255, 255, 255),
		},
		-- The seekers' head-start count: each new number grows a little and settles (calm).
		CountPulseScale = 1.08,
		CountPulseSeconds = 0.45,
		-- (A message line, a candy miss too, pops with Config.UI.Motion's BumpScale.)
		-- "The pumpkins are glowing!" breathes gently: it fades to GlowPulseFade and back,
		-- GlowPulses times, GlowPulseSeconds each way, and ends fully solid.
		GlowPulses = 3,
		GlowPulseSeconds = 0.45,
		GlowPulseFade = 0.45,
	},

	-- ScareMaze (src/client/ScareMazeUI.luau)
	ScareMaze = {
		TeamPopScale = 1.6, -- "You're a SURVIVOR!" starts this big...
		TeamPopSeconds = 0.35,
		TeamShakeDegrees = 6, -- ...tilted this much, settling straight
		HintFadeDelay = 0.15, -- the hint under it fades in after this long...
		HintFadeSeconds = 0.3, -- ...in this long
		MessagePopScale = 1.6, -- ESCAPED! / You stopped! / +1 catch! start this big
		MessagePopSeconds = 0.3,
		-- The standing-still 3-2-1: each number punches in, but never so big or tilted that it's
		-- hard to read.
		CountdownPopScale = 1.35,
		CountdownPopSeconds = 0.25,
		CountdownTilt = 5, -- degrees, left then right
		-- The BOO button: a ring around it fills up (every frame, from the real cooldown) while
		-- BOO is recharging, and the button bumps when it's ready again.
		RingThickness = 6,
		RingColor = Color3.fromRGB(255, 255, 255),
		RingGap = 6, -- how far outside the button the ring sits
		-- Escaping: confetti and a sparkle burst.
		EscapeConfetti = 40,
		EscapeSparkles = 18,
		EscapeColors = {
			Color3.fromRGB(110, 255, 140),
			Color3.fromRGB(255, 230, 120),
			Color3.fromRGB(255, 255, 255),
		},
	},

	-- The ScareMaze jumpscare (src/client/ScareMazeJumpscare.luau). It stays short
	-- (Config.ScareMaze.Jumpscare.Seconds) and silly: the face zooms in and wobbles like it's
	-- laughing. With the motion off the face just shows (no zoom or wobble).
	Jumpscare = {
		ZoomFrom = 0.15, -- the face starts this small...
		ZoomTo = 1.1, -- ...and zooms to this
		WobbleDegrees = 7, -- a giggly wobble left and right
		WobbleSeconds = 0.1,
	},

	-- The ghost screen (src/client/GhostUI.luau) and the lobby spectate bar
	-- (src/client/Spectate.luau): they slide up from the bottom; the name of who you're watching
	-- fades in when it changes (the words change at once).
	Ghost = {
		SlideDistance = 60,
		SlideSeconds = 0.3,
		NameFadeFrom = 0.7, -- the new name starts this see-through (0 = solid, 1 = invisible)
		NameFadeSeconds = 0.2,
	},
	Spectate = {
		SlideDistance = 60,
		SlideSeconds = 0.3,
		NameFadeFrom = 0.7,
		NameFadeSeconds = 0.2,
	},

	-- Toasts from src/client/RewardsUI.luau ("Day 3 streak! +100 Coins").
	Rewards = {
		SlideDistance = 50, -- slides down this far into place...
		SlideSeconds = 0.3,
		OutSeconds = 0.25, -- ...and back up when it goes
		Gap = 8, -- toasts showing at once stack this far apart
		CountDelay = 0.2, -- the coins start counting up after this long...
		CountSeconds = 0.8, -- ...and reach the real number in this long
		StreakConfetti = 24, -- the daily streak's celebration
		StreakSparkles = 12,
		StreakColors = {
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(255, 140, 40),
			Color3.fromRGB(255, 255, 255),
		},
	},

	-- NPC dialogue (src/client/NpcDialogUI.luau): the box pops in and the words type out.
	-- Tap the words to show them all at once; Next and Close always work straight away.
	NpcDialog = {
		CharsPerSecond = 70,
		MaxTypeSeconds = 1.5, -- long pages type faster so they never take longer than this
	},

	-- Server-wide announcements (src/client/AnnounceUI.luau; how many show at once and their
	-- looks: Config.Announce).
	Announce = {
		SlideDistance = 50, -- each banner drops in from this far above...
		SlideSeconds = 0.35,
		-- (When its time is over it shrinks away like a closing panel: Config.UI.Motion.)
		MoveSeconds = 0.2, -- the others slide into the space it leaves
		ShineDelay = 0.2, -- then a light sweeps across it once
		ShineSeconds = 0.7,
	},

	-- The Voting Board in the lobby (src/client/VoteBoardUI.luau).
	VoteBoard = {
		PulseScale = 1.12, -- a choice whose vote count changes pulses this big...
		PulseSeconds = 0.3,
		FlashColor = Color3.fromRGB(255, 200, 80), -- ...and flashes this colour
		RowPopSeconds = 0.25, -- when the vote opens, the choices pop in one by one...
		RowStagger = 0.06, -- ...this far apart
	},
}
