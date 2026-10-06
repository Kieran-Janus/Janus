--!strict
--[[
	SCAREMAZE (Config.ScareMaze)

	Two teams (on/off: Config.Features.ScareMaze). Survivors start at the maze entrance and
	must reach the glowing exit gate. Anyone who stops moving for StopSeconds is OUT. Haunters
	start inside the maze and press BOO to scare Survivors. Scare traps in the corridors
	(scarecrows, zombies, bats, ghosts) jump out by themselves. Spooky-cute, never gory.

	Easy tweaks:
	  Duration          how long Survivors have to get out
	  StopSeconds       how long you can stand still before you're out
	  HaunterRatio      how many players start as Haunters
	  Boo.Cooldown      how often a Haunter can BOO
	  Rewards           coins and points
	  Text              every message players see
	The maze itself (size, traps, lanterns...) is in src/shared/Config/Maps/ScareMaze.luau.
	The code: src/server/Modes/ScareMaze.luau (server), src/client/ScareMazeUI.luau (screen).
]]

return {
	-- The round ----------------------------------------------------------------------------------
	Duration = 240, -- seconds to reach the exit; whoever is still in the maze at 0:00 is out
	IntroSeconds = 5, -- "Get ready": everyone stands still at their start while teams are shown

	-- Teams --------------------------------------------------------------------------------------
	MinPlayersForHaunters = 3, -- fewer players than this: everyone is a Survivor
	HaunterRatio = 0.2, -- share of players who start as Haunters (at least 1): 10 players = 2
	OutBecomeHaunters = true, -- Survivors who are out join the Haunters (false = watch as a ghost)
	OutToHaunterDelay = 2, -- seconds before an out Survivor is moved to the Haunters' start
	SurvivorMaxZoom = 14, -- how far Survivors can zoom the camera out (no peeking over the maze)
	HaunterMaxZoom = 26, -- ...and Haunters

	-- Keep moving (the stop rule) -----------------------------------------------------------------
	StopSeconds = 3, -- stand still this long and you're OUT
	MinMoveStuds = 4, -- move at least this far (sideways) to count as moving; jumping doesn't count
	SampleSeconds = 0.2, -- how often the server checks where everyone is (0.2 = 5 times a second)
	StartGraceSeconds = 2, -- safe time when the run starts
	ScareGraceSeconds = 2, -- safe time after a jumpscare or a BOO has slowed you down
	CountdownAfter = 0.6, -- the red 3-2-1 shows after standing still this long
	-- Anti-cheat: a Survivor who moved faster than this (studs per second, plus SlackStuds for
	-- lag) can't escape for EscapeLockSeconds.
	MaxMoveSpeed = 40,
	SlackStuds = 14,
	EscapeLockSeconds = 3,

	-- Haunters: BOO! -------------------------------------------------------------------------------
	Boo = {
		Cooldown = 8, -- seconds between BOOs
		Range = 16, -- Survivors this close get a jumpscare and slow down
		SlowMultiplier = 0.25, -- their speed is multiplied by this...
		SlowSeconds = 1, -- ...for this long
		TrapRange = 22, -- scare traps this close to the Haunter go off straight away
		Keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonX }, -- keyboard / gamepad (phones get a button)
	},
	HaunterSeeSurvivors = true, -- Haunters see running Survivors through the maze walls (faintly)
	MaxHighlights = 16, -- at most this many Survivors outlined at once (Roblox shows up to 31)
	HighlightRefreshSeconds = 0.5,
	-- A Haunter scores a catch when a Survivor stops within this many studs of them, or within
	-- CatchCreditSeconds after that Haunter's BOO (or a trap they set off) scared them.
	CatchCreditRange = 30,
	CatchCreditSeconds = 10,
	HaunterTag = "👻 HAUNTER", -- floating name tag over every Haunter
	HaunterTagDistance = 70, -- studs: the tag is hidden further away

	-- Scare traps (parts tagged ScareTrigger in the map, attribute Kind) ----------------------------
	Traps = {
		Cooldown = 14, -- seconds before the same trap can go off again
		JumpscareRange = 12, -- Survivors this close to a trap that goes off get the jumpscare
		SlowMultiplier = 0.5, -- a scare makes you stumble: speed x this...
		SlowSeconds = 0.6, -- ...for this long
		-- One Survivor gets at most one jumpscare this often. Keep it longer than SlowSeconds +
		-- ScareGraceSeconds + StopSeconds, or standing next to a scare would keep you safe.
		PersonalCooldown = 6.5,
		-- How long each scare lasts (seconds) and its sound (heard nearby).
		Kinds = {
			Scarecrow = { -- a scarecrow on a post swivels round and lunges out of the corn
				Seconds = 2.2,
				Lunge = 4, -- studs it leans out
				Sound = {
					SoundId = "rbxassetid://133651202885353", -- "Monster Roar", pitched up: a screech
					Volume = 0.7,
					PitchMin = 1.5,
					PitchMax = 1.7,
					RollOffMin = 10,
					RollOffMax = 70,
				},
			},
			Zombie = { -- a cartoon zombie pops up out of the ground in a puff of dirt
				Seconds = 2.6,
				Sound = {
					SoundId = "rbxassetid://133651202885353",
					Volume = 0.7,
					PitchMin = 0.8,
					PitchMax = 0.95,
					RollOffMin = 10,
					RollOffMax = 70,
				},
			},
			Bats = { -- a swarm of bats bursts out of the corn
				Seconds = 1.6,
				Count = 7,
				Sound = {
					SoundId = "rbxassetid://117491181431951", -- bat squeaks
					Volume = 0.8,
					PitchMin = 1.1,
					PitchMax = 1.4,
					RollOffMin = 10,
					RollOffMax = 60,
				},
			},
			Ghost = { -- a sheet ghost swoops down over the wall
				Seconds = 1.8,
				Sound = {
					SoundId = "rbxassetid://140334012603496", -- ghostly whoosh
					Volume = 0.9,
					PitchMin = 0.9,
					PitchMax = 1.1,
					RollOffMin = 10,
					RollOffMax = 70,
				},
			},
			Patrol = { -- a scarecrow that slowly walks up and down a corridor (Kind "Patrol")
				Seconds = 0,
				Speed = 5, -- studs per second
				PauseSeconds = 1.5, -- stops at each end
				ScareRange = 5, -- walking into it gives you a jumpscare
				Sound = {
					SoundId = "rbxassetid://9120924561", -- rattle
					Volume = 0.6,
					PitchMin = 0.7,
					PitchMax = 0.8,
					RollOffMin = 8,
					RollOffMax = 50,
				},
			},
		},
	},
	-- Sizes (studs tall) of the scare characters. Each can be swapped for your own model: put
	-- a model with the same name (ScareScarecrow, ScareZombie, ScareBat, ScareGhost) in
	-- ReplicatedStorage.Custom.Props (assets/Props) and it is used instead.
	ActorSizes = { ScareScarecrow = 9, ScareZombie = 6, ScareBat = 1.4, ScareGhost = 6 },
	ActorColors = {
		Straw = Color3.fromRGB(230, 190, 90),
		Shirt = Color3.fromRGB(150, 60, 60),
		Patch = Color3.fromRGB(80, 110, 160),
		Hat = Color3.fromRGB(70, 55, 45),
		Wood = Color3.fromRGB(90, 62, 40),
		Pumpkin = Color3.fromRGB(255, 130, 20),
		Glow = Color3.fromRGB(255, 220, 110),
		ZombieSkin = Color3.fromRGB(140, 205, 110),
		ZombieShirt = Color3.fromRGB(110, 90, 160),
		ZombiePants = Color3.fromRGB(70, 80, 120),
		Eyes = Color3.fromRGB(255, 255, 255),
		Pupils = Color3.fromRGB(30, 30, 40),
		Bat = Color3.fromRGB(45, 30, 60),
		BatEyes = Color3.fromRGB(255, 220, 80),
		Ghost = Color3.fromRGB(240, 240, 255),
		Dirt = Color3.fromRGB(110, 80, 55),
	},

	-- The full-screen jumpscare (client) ----------------------------------------------------------
	Jumpscare = {
		Seconds = 0.6, -- how long the face stays on screen
		ShakeStuds = 0.7, -- camera shake strength
		ImageId = "", -- "rbxassetid://..." = use your own image instead of the cartoon faces below
		-- The cartoon face for each kind of scare: face colour, eye colour, mouth colour, emoji.
		Faces = {
			Scarecrow = {
				Face = Color3.fromRGB(255, 140, 30),
				Eyes = Color3.fromRGB(255, 240, 120),
				Mouth = Color3.fromRGB(60, 25, 10),
				Emoji = "🎃",
			},
			Zombie = {
				Face = Color3.fromRGB(140, 205, 110),
				Eyes = Color3.fromRGB(255, 255, 255),
				Mouth = Color3.fromRGB(70, 40, 70),
				Emoji = "🧟",
			},
			Bats = {
				Face = Color3.fromRGB(70, 45, 95),
				Eyes = Color3.fromRGB(255, 220, 80),
				Mouth = Color3.fromRGB(30, 15, 40),
				Emoji = "🦇",
			},
			Ghost = {
				Face = Color3.fromRGB(240, 240, 255),
				Eyes = Color3.fromRGB(40, 40, 60),
				Mouth = Color3.fromRGB(40, 40, 60),
				Emoji = "👻",
			},
			Boo = {
				Face = Color3.fromRGB(200, 180, 255),
				Eyes = Color3.fromRGB(40, 30, 70),
				Mouth = Color3.fromRGB(40, 30, 70),
				Emoji = "👻",
			},
		},
		-- Only you hear these.
		Sting = {
			SoundId = "rbxassetid://9113854528",
			Volume = 0.9,
			PitchMin = 1.2,
			PitchMax = 1.4,
		},
	},

	-- Rewards (coins before the friend bonus; points are the results screen's Score) -------------
	Rewards = {
		PlayCoins = 5, -- everyone who took part
		EscapeCoins = 40, -- a Survivor who gets out
		CoinsPerSecondLeft = 0.25, -- time bonus: per second still on the clock when you escape
		CoinsPerCatch = 15, -- a Haunter, per Survivor caught
		EscapePoints = 10,
		PointsPerSecondLeft = 0.1, -- 1 point per 10 seconds left
		PointsPerCatch = 5,
	},

	-- Sounds only you hear -------------------------------------------------------------------------
	Sounds = {
		Escaped = { SoundId = "rbxassetid://1841209502", Volume = 0.7 },
		Out = { SoundId = "rbxassetid://9113854528", Volume = 0.7 },
		Boo = {
			SoundId = "rbxassetid://140334012603496",
			Volume = 0.8,
			PitchMin = 1.3,
			PitchMax = 1.5,
		},
		Catch = { SoundId = "rbxassetid://4612374807", Volume = 0.6 },
	},
	-- Heard by everyone near the Haunter who BOOs.
	BooSound = {
		SoundId = "rbxassetid://140334012603496",
		Volume = 1,
		PitchMin = 1.3,
		PitchMax = 1.5,
		RollOffMin = 10,
		RollOffMax = 60,
	},

	-- Colours on screen ------------------------------------------------------------------------------
	Colors = {
		Survivors = Color3.fromRGB(255, 190, 60),
		Haunters = Color3.fromRGB(180, 110, 255),
		MeterFull = Color3.fromRGB(90, 220, 110),
		MeterHalf = Color3.fromRGB(255, 200, 60),
		MeterEmpty = Color3.fromRGB(255, 70, 60),
		Escaped = Color3.fromRGB(110, 255, 140),
		Out = Color3.fromRGB(255, 80, 70),
		HighlightFill = Color3.fromRGB(255, 190, 60), -- how Haunters see Survivors through walls
		HighlightOutline = Color3.fromRGB(255, 240, 200),
	},

	-- Every message players see ---------------------------------------------------------------------
	Text = {
		ScoreLabel = "Points",
		MvpLine = "%s scored %d points!",
		Survivors = "Survivors",
		Haunters = "Haunters",
		YouAreSurvivor = "You're a SURVIVOR!",
		SurvivorHint = "Run to the glowing exit. Don't stop for %d seconds!", -- %d = StopSeconds
		YouAreHaunter = "You're a HAUNTER!",
		HaunterHint = "BOO the Survivors to make them stop!",
		GetReady = "Get ready...",
		KeepMoving = "KEEP MOVING!",
		Move = "MOVE!",
		Safe = "Safe!",
		Escaped = "ESCAPED!",
		EscapedHint = "You made it out of the maze!",
		Out = "You stopped! The maze got you",
		NowHaunter = "Now you're a Haunter: scare the others!",
		TimeUp = "Time's up!",
		SurvivorsLeft = "Survivors left: %d",
		Escapes = "Escaped: %d",
		BooButton = "BOO!",
		BooKey = "(E)",
		Catch = "+1 catch!",
		-- Results screen
		BadgeEscaped = "Escaped!",
		BadgeStopped = "Stopped",
		BadgeTimeUp = "Time's up",
		BadgeHaunter = "Haunter",
		TeamSurvivor = "Survivor",
		TeamHaunter = "Haunter",
		StatEscaped = "escaped with %d:%02d left",
		StatCatches = "caught %d",
		WinnerEveryone = "Everyone escaped!",
		WinnerSome = "%d of %d Survivors escaped!",
		WinnerHaunters = "The Haunters win!",
		WinnerMaze = "The maze wins this time!",
	},
}
