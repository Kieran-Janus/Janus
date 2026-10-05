--!strict
--[[
	THE tweak file. Every number, name, price and AI persona lives here.
	Want a longer round? Change Round.Duration. Want a new NPC? Add to AI.Npcs.
	Nothing else in the codebase should hardcode gameplay values.
]]

local Config = {
	Game = {
		Name = "Pumpkin Panic", -- working title, see docs/DESIGN.md
		Version = "0.1.0",
	},

	Round = {
		MinPlayers = 1,
		IntermissionSeconds = 5, -- after voting, while the map loads
		Duration = 300, -- seconds of play per round
		ResultsSeconds = 10, -- how long the results screen stays up
		ResultsShowTop = 10, -- rows on the results screen
	},

	-- The results screen after each round (src/client/ResultsUI.luau). It stays up for
	-- Round.ResultsSeconds; Round.ResultsShowTop rows are listed (your own row is always shown).
	Results = {
		PopSeconds = 0.35, -- panel slides in with a little bounce
		RowDelay = 0.08, -- rows appear one after another
		CountUpDelay = 0.6, -- seconds before coins start counting up
		CountUpSeconds = 1.6, -- coins count from 0 to the total in this long
		CoinSoundEvery = 0.12, -- coin sound while your coins count up, at most this often
		SpotlightSpinSeconds = 6, -- one turn of the glow behind the MVP's headshot
		MaxListHeight = 300, -- rows scroll past this many pixels
		Text = {
			Title = "Round over!",
			Mvp = "MVP",
			MvpLine = "%s collected %d pumpkins!", -- name, pumpkins
			Survived = "Survived!",
			Caught = "Caught",
			NextRound = "Next round in %d",
			Nobody = "Nobody finished this round.",
		},
		Colors = {
			Mvp = Color3.fromRGB(255, 210, 60),
			Survived = Color3.fromRGB(110, 220, 120),
			Caught = Color3.fromRGB(170, 160, 190),
			MyRow = Color3.fromRGB(255, 130, 20), -- background tint of your own row
		},
	},

	Voting = {
		Seconds = 20,
		MapChoices = 3, -- maps offered per vote (capped by how many maps exist)
		MinSecondsBetweenVotes = 0.5, -- per-player spam guard on the vote remote
	},

	Maps = {
		Origin = Vector3.new(0, 0, 1000), -- where the round map is built, away from the lobby
		SpawnHeight = 4, -- studs above a spawn pad that a character is placed
		-- How a map is made, first match wins:
		--   1. a Model named after the Id in ServerStorage.Maps (hand-built or Creator Store art)
		--      with a part named "Floor", a folder named SpawnFolder holding spawn parts and
		--      optionally a folder "Hotspots" of parts where extra pumpkins appear;
		--   2. otherwise src/server/Maps/<Builder>.luau builds it from the settings below.
		-- Lighting, particles and ambient sound switch on the client when the camera is over the
		-- map (src/client/ZoneLighting.luau) so players in the hub keep the hub look.
		LightingFadeSeconds = 1.5,
		ZoneCheckSeconds = 0.25,
		List = {
			{
				Id = "PumpkinPatch",
				Name = "Haunted Pumpkin Patch",
				Thumbnail = 0, -- rbxassetid, 0 = none yet
				SpawnFolder = "Spawns",
				Builder = "PumpkinPatch",
				Seed = 1,
				Size = Vector3.new(220, 1, 220),
				WallHeight = 14, -- the thorny hedge around the edge
				Spawns = 8,
				SpawnRadius = 20,
				Colors = {
					Grass = Color3.fromRGB(62, 92, 44),
					Dirt = Color3.fromRGB(92, 64, 42),
					Hedge = Color3.fromRGB(32, 52, 34),
					Corn = Color3.fromRGB(176, 160, 70),
					CornTop = Color3.fromRGB(214, 190, 90),
					Hay = Color3.fromRGB(222, 184, 92),
					Barn = Color3.fromRGB(150, 42, 40),
					Roof = Color3.fromRGB(70, 44, 40),
					Wood = Color3.fromRGB(92, 62, 40),
					Stone = Color3.fromRGB(120, 118, 128),
					Iron = Color3.fromRGB(35, 32, 40),
					Orange = Color3.fromRGB(255, 130, 20),
					Green = Color3.fromRGB(110, 200, 90),
					Glow = Color3.fromRGB(255, 200, 90),
					Bone = Color3.fromRGB(235, 228, 210),
				},
				-- Offsets are from the map centre (x, z); the spawn clearing is in the middle.
				Layout = {
					ClearingRadius = 30, -- nothing big is placed here
					CornMaze = { -- tall rows block the King's view; gaps are the way through
						Offset = Vector3.new(58, 0, -58),
						Size = Vector3.new(76, 10, 76), -- y = stalk height
						RowSpacing = 9,
						GapsPerRow = 2,
						GapWidth = 6,
					},
					Barn = { -- doors at both ends make it a shortcut; hay inside to hide in
						Offset = Vector3.new(-60, 0, -58),
						Size = Vector3.new(30, 16, 40),
						DoorWidth = 12,
						DoorHeight = 12,
					},
					Field = { -- open pumpkin rows: lots of pumpkins, nowhere to hide (risky)
						Offset = Vector3.new(-58, 0, 58),
						Size = Vector3.new(70, 0, 56),
						Rows = 6,
						DecorPumpkinsPerRow = 7,
					},
					Graveyard = {
						Offset = Vector3.new(58, 0, 58),
						Size = Vector3.new(60, 0, 56),
						Tombstones = 14,
					},
					Haystacks = 7, -- walk-in hiding spots scattered in the open
					JumpFences = 6, -- low fences players can hop; the King can't jump
					JumpFenceHeight = 3.5,
					HayBales = 14,
					DeadTrees = 9,
					Lanterns = 12,
					JackOLanterns = 14,
					Scarecrows = 3,
				},
				Lighting = {
					ClockTime = 0.2, -- full moon
					Brightness = 2,
					Ambient = Color3.fromRGB(85, 70, 110),
					OutdoorAmbient = Color3.fromRGB(110, 100, 150),
					Atmosphere = {
						Density = 0.42,
						Offset = 0.1,
						Color = Color3.fromRGB(120, 110, 170),
						Decay = Color3.fromRGB(255, 150, 80),
						Glare = 0.3,
						Haze = 2,
					},
					ColorCorrection = {
						Brightness = 0.04,
						Contrast = 0.1,
						Saturation = 0.2,
						TintColor = Color3.fromRGB(240, 235, 255),
					},
					Bloom = { Intensity = 0.8, Size = 30, Threshold = 0.9 },
				},
				Particles = {
					Fireflies = { Rate = 14, Color = Color3.fromRGB(210, 255, 120) },
					Mist = { Rate = 10, Color = Color3.fromRGB(190, 175, 220) },
					Leaves = { Rate = 6, Color = Color3.fromRGB(205, 110, 40) },
				},
				-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
				AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.3 },
			},
			{
				Id = "SpookyMansion",
				Name = "Spooky Mansion",
				Thumbnail = 0,
				SpawnFolder = "Spawns",
				Builder = "SpookyMansion",
				Seed = 2,
				Size = Vector3.new(180, 1, 180),
				WallHeight = 20, -- outer walls; the roof caved in long ago
				Spawns = 8,
				SpawnRadius = 16,
				Colors = {
					Floor = Color3.fromRGB(96, 66, 50),
					OuterWall = Color3.fromRGB(70, 62, 82),
					Wall = Color3.fromRGB(88, 60, 110),
					Trim = Color3.fromRGB(50, 34, 40),
					Rug = Color3.fromRGB(140, 30, 50),
					RugAlt = Color3.fromRGB(60, 40, 120),
					Wood = Color3.fromRGB(80, 50, 34),
					DarkWood = Color3.fromRGB(48, 30, 24),
					Gold = Color3.fromRGB(230, 180, 70),
					Stone = Color3.fromRGB(120, 118, 128),
					Curtain = Color3.fromRGB(110, 20, 40),
					Plant = Color3.fromRGB(50, 80, 50),
					Bone = Color3.fromRGB(235, 228, 210),
					Orange = Color3.fromRGB(255, 130, 20),
					Green = Color3.fromRGB(110, 200, 90),
					Glow = Color3.fromRGB(255, 200, 90),
					Slime = Color3.fromRGB(120, 255, 110),
				},
				Layout = {
					-- A 3x3 grid of rooms, listed north-west to south-east. The middle one is
					-- where everyone spawns. Every neighbouring pair of rooms shares a doorway.
					Rooms = {
						"Library",
						"Gallery",
						"Bedroom",
						"Dining",
						"GrandHall",
						"Kitchen",
						"Conservatory",
						"Ballroom",
						"Crypt",
					},
					WallHeight = 16, -- inside walls
					WallThickness = 2,
					DoorWidth = 12,
					DoorHeight = 11,
					-- Extra gaps hidden behind a fake bookcase: players walk through, the King
					-- can't path through them (PathfindingModifier label "SecretDoor").
					SecretDoors = 3,
					SecretDoorWidth = 6,
					Hotspots = { "Ballroom", "Dining" }, -- rooms where extra pumpkins appear
				},
				Lighting = {
					ClockTime = 22,
					Brightness = 1.4,
					Ambient = Color3.fromRGB(95, 70, 120),
					OutdoorAmbient = Color3.fromRGB(105, 85, 135),
					Atmosphere = {
						Density = 0.36,
						Offset = 0.2,
						Color = Color3.fromRGB(110, 90, 150),
						Decay = Color3.fromRGB(90, 60, 140),
						Glare = 0,
						Haze = 1.4,
					},
					ColorCorrection = {
						Brightness = 0.03,
						Contrast = 0.15,
						Saturation = 0.1,
						TintColor = Color3.fromRGB(245, 230, 255),
					},
					Bloom = { Intensity = 0.9, Size = 26, Threshold = 0.88 },
				},
				Particles = {
					Dust = { Rate = 10, Color = Color3.fromRGB(230, 220, 200) },
					Wisps = { Rate = 5, Color = Color3.fromRGB(150, 220, 255) },
					Mist = { Rate = 5, Color = Color3.fromRGB(170, 150, 210) },
				},
				-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
				AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
			},
		} :: { any }, -- maps differ in shape (each Builder reads its own Layout)
	},

	Difficulty = {
		Order = { "Easy", "Hard" }, -- order shown in the vote
		Default = "Easy", -- used if nobody votes
		Levels = {
			Easy = {
				Name = "Easy",
				PumpkinsAtStart = 25,
				MaxPumpkins = 35, -- most pumpkins on the map at once
				SpawnInterval = 2, -- seconds between new pumpkins
				RewardMultiplier = 1,
			},
			Hard = {
				Name = "Hard",
				PumpkinsAtStart = 12,
				MaxPumpkins = 18,
				SpawnInterval = 4,
				RewardMultiplier = 2,
			},
		},
	},

	Pumpkins = {
		Size = 2.5,
		Color = Color3.fromRGB(255, 130, 20),
		HoverHeight = 2, -- studs above the floor
		Value = 1, -- pumpkins added per pickup
		PickupRange = 10, -- server ignores touches from farther than this (studs)
		EdgeMargin = 8, -- keep spawns this far from the map edge
		SpawnAttempts = 10, -- tries to find open floor before skipping one spawn
		HotspotChance = 0.35, -- share of pumpkins placed in a map's risky "Hotspots" areas
		Glow = { Color = Color3.fromRGB(255, 170, 60), Range = 8, Brightness = 1 }, -- seen in the dark
	},

	Rewards = {
		CoinsPerPumpkin = 5, -- multiplied by the difficulty's RewardMultiplier
		SurvivorBonus = 25, -- coins for still being alive when the round ends
		TopCollectorWins = 1, -- Wins added to the player(s) with the most pumpkins
	},

	-- The Pumpkin King: a server-controlled NPC that hunts players.
	King = {
		Name = "The Pumpkin King",
		-- Picked by the difficulty vote. Players walk at Player.WalkSpeed and sprint at SprintSpeed.
		Difficulty = {
			Easy = {
				Count = 1,
				WalkSpeed = 12, -- while wandering or investigating a noise
				ChaseSpeed = 18,
				HearingRange = 90, -- studs; noise farther away is ignored
				SightRange = 45, -- studs; needs a clear line of sight
			},
			Hard = {
				Count = 2,
				WalkSpeed = 14,
				ChaseSpeed = 21,
				HearingRange = 130,
				SightRange = 60,
			},
		},
		SpawnDelay = 15, -- seconds of grace at round start before the King appears
		MinSpawnDistance = 60, -- studs from every player when it spawns
		CatchRange = 4.5, -- studs from the King's root to a player's root (touching also catches)
		RepathSeconds = 0.6, -- how often the path is recomputed while chasing
		WanderRepathSeconds = 3, -- and while wandering or investigating
		StuckSeconds = 2.5, -- no progress for this long = give up on the current goal
		WaypointReachedDistance = 2.5, -- studs (flat) to count a path waypoint as reached
		HipHeight = 3,
		BodySize = Vector3.new(3, 4, 2),
		HeadSize = 4.5,
		BodyColor = Color3.fromRGB(40, 25, 55),
		HeadColor = Color3.fromRGB(255, 110, 0),
		CrownColor = Color3.fromRGB(255, 210, 60),
		Path = {
			AgentRadius = 2.5,
			AgentHeight = 8,
			AgentCanJump = false, -- so low "jump fences" are shortcuts only players can use
			WaypointSpacing = 4,
			Costs = { SecretDoor = math.huge }, -- mansion secret doors are for players only
		},
		-- Noise attracts the King. Every loudness below is decided by the server; clients only
		-- say "I'm sprinting" or "I shouted". Sprint, pickups and shouting mean players without
		-- voice still play the stealth game (docs/DESIGN.md). M3 adds voice only as a clamped,
		-- rate-limited hint on top.
		-- The clip moment: when the King turns towards a noise a player made, that player sees
		-- a big banner and players nearby are told who it heard.
		Heard = {
			Cooldown = 8, -- seconds before the same player can trigger it again
			NearbyRadius = 60, -- studs; players this close to the heard player see "The King heard X!"
			Banner = "THE KING HEARD YOU!",
			NearbyText = "The King heard %s!", -- %s = display name
			BannerSeconds = 2.2,
			RoarSoundId = "rbxassetid://133651202885353", -- "Monster Roar" (Creator Store); "" = silent
			RoarVolume = 0.8,
			RoarPitch = 1.15, -- a bit higher = more cartoon, less scary
		},
		Noise = {
			MemorySeconds = 6, -- how long a noise stays interesting
			TickSeconds = 0.5,
			SprintPerTick = 6, -- loudness each tick while sprinting and moving
			PumpkinPickup = 10,
			Shout = 25,
			ShoutCooldown = 4, -- seconds between shouts per player
			ShoutText = "HEY!", -- shown above the player's head
			ShoutBubbleSeconds = 1.5,
		},
	},

	-- Minion monsters that make the maps feel alive. They never catch anyone (only the King
	-- does); they slow you down, make noise the King hears, or steal a pumpkin. The server
	-- moves them and decides every hit; ghosts are ignored. Count is per difficulty.
	Monsters = {
		SpawnDelay = 5, -- seconds after the round starts
		MinSpawnDistance = 30, -- studs from every player when a minion appears
		HitCooldown = 3, -- seconds a player is safe from all minions after any hit
		TickSeconds = 0.1, -- how often minions look for targets (movement is every frame)
		FeedbackSeconds = 2.5, -- how long the hit message shows on the player's screen

		SkeletonPatrol = {
			Name = "Skeleton Patrol",
			Count = { Easy = 2, Hard = 4 },
			Speed = 6, -- slow: studs per second
			RouteMin = 30, -- each skeleton walks back and forth on a straight route this long
			RouteMax = 60,
			PauseSeconds = 1.5, -- stands still at each end of its route
			HitRange = 4, -- studs, flat
			SlowMultiplier = 0.4, -- walk speed is multiplied by this...
			SlowSeconds = 2, -- ...for this long
			Knockback = 45, -- push away (studs per second), applied by the hit player's client
			Noise = 15, -- the rattle the King can hear
			Color = Color3.fromRGB(235, 228, 210),
			EyeColor = Color3.fromRGB(120, 255, 110),
			Message = "Bonk! A skeleton rattled you. The King heard that!",
		},
		BatSwarm = {
			Name = "Bat Swarm",
			Count = { Easy = 1, Hard = 2 },
			Bats = 5, -- bats per swarm
			FlyHeight = 6, -- studs above the floor
			IdleRadius = 4, -- circles its roost while waiting
			DartSpeed = 30, -- fast...
			ReturnSpeed = 12,
			AggroRange = 28, -- ...but short range: needs a clear view of you within this
			LeashRange = 40, -- gives up when this far from its roost
			ZigZagWidth = 5, -- studs side to side while darting
			ZigZagHz = 2.5,
			RestSeconds = 4, -- back at the roost after a hit or giving up
			HitRange = 4,
			SlowMultiplier = 0.6,
			SlowSeconds = 3,
			Noise = 12,
			Color = Color3.fromRGB(40, 30, 55),
			EyeColor = Color3.fromRGB(255, 70, 70),
			Message = "Bats! They screeched and made you dizzy.",
		},
		GhostCat = {
			Name = "Ghost Cat",
			Count = { Easy = 1, Hard = 2 },
			WanderSpeed = 8,
			StalkSpeed = 14, -- a bit slower than walking, so you can escape if you notice it
			NoticeRange = 30, -- goes after players carrying pumpkins this close
			HitRange = 3.5,
			Steal = 1, -- pumpkins taken per touch
			DropSeconds = 6, -- the stolen pumpkin reappears somewhere on the map after this
			FleeSeconds = 4, -- runs off after a steal before it hunts again
			Hover = 1.5, -- floats this high (it's a ghost: it also drifts through walls)
			Noise = 8,
			Color = Color3.fromRGB(190, 225, 255),
			Transparency = 0.35,
			EyeColor = Color3.fromRGB(255, 220, 80),
			Message = "The Ghost Cat swiped a pumpkin! It'll drop it somewhere...",
		},
	},

	-- Sound effects. Each one: SoundId ("" = silent), Volume (0-1), optional PitchMin/PitchMax
	-- (random pitch each play) and, for 3D sounds on a part, RollOffMin/RollOffMax (studs: full
	-- volume inside Min, silent past Max). All ids are free Creator Store audio; swap any of them.
	-- Players can turn music and sounds off in Settings (saved). Music = hub music + map
	-- ambience; Sounds = everything below.
	Sounds = {
		-- UI (every button in the game UI)
		Click = { SoundId = "rbxassetid://87437544236708", Volume = 0.5 },
		Hover = { SoundId = "rbxassetid://139800881181209", Volume = 0.25 },
		-- Rewards and round events (only you hear them)
		PumpkinPickup = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.6,
			PitchMin = 0.9,
			PitchMax = 1.2,
		},
		Coins = { SoundId = "rbxassetid://4612374807", Volume = 0.5 },
		RoundStart = { SoundId = "rbxassetid://17798541626", Volume = 0.6 },
		CountdownTick = {
			SoundId = "rbxassetid://134410911353980",
			Volume = 0.5,
			LastSeconds = 10, -- ticks during the last this-many seconds of...
			States = { "Voting", "Intermission", "Playing" }, -- ...these round states
		},
		Caught = { SoundId = "rbxassetid://9113854528", Volume = 0.7 },
		Ghost = { SoundId = "rbxassetid://140334012603496", Volume = 0.6, Delay = 0.5 }, -- after Caught
		Purchase = { SoundId = "rbxassetid://120891770644830", Volume = 0.6 },
		DailyReward = { SoundId = "rbxassetid://1841209502", Volume = 0.6 },
		CodeRedeemed = { SoundId = "rbxassetid://9045119921", Volume = 0.6 },
		-- 3D, heard by everyone near them (the King's roar is Config.King.Heard.RoarSoundId)
		KingFootstep = {
			SoundId = "rbxassetid://140594308250996",
			Volume = 0.9,
			PitchMin = 0.55, -- low and heavy
			PitchMax = 0.65,
			RollOffMin = 12,
			RollOffMax = 90,
			WalkInterval = 0.6, -- seconds between steps while wandering or listening
			ChaseInterval = 0.32, -- ...and while chasing
		},
		SkeletonRattle = {
			SoundId = "rbxassetid://9120924561",
			Volume = 0.6,
			PitchMin = 1.1,
			PitchMax = 1.4,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		BatSqueak = {
			SoundId = "rbxassetid://117491181431951",
			Volume = 0.5,
			PitchMin = 1,
			PitchMax = 1.3,
			RollOffMin = 8,
			RollOffMax = 50,
		},
		CatMeow = {
			SoundId = "rbxassetid://134699420140804",
			Volume = 0.6,
			PitchMin = 0.95,
			PitchMax = 1.15,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		-- Minions also make their sound now and then on their own, so you hear them coming.
		MinionIdleMin = 5, -- seconds between idle sounds per minion (random in this range)
		MinionIdleMax = 11,
		SettingsCooldown = 0.3, -- per-player spam guard on the Settings toggles
	},

	-- Screen layout for phones, tablets and PC (src/client/Layout.luau).
	UI = {
		ReferenceHeight = 760, -- usable screen height the UI is drawn for; taller screens scale up...
		MaxScale = 1.35, -- ...to at most this (never down: phones keep full-size, readable text)
		PhoneMaxHeight = 500, -- a touch screen this short (usable points) gets the phone layout
		EdgeMargin = 12, -- gap between panels and the screen edge
		SideButton = { Width = 110, Height = 40, Gap = 8, PhoneWidth = 96, PhoneHeight = 38 },
		-- On touch screens the side buttons go top-left, above Roblox's thumbstick (bottom-left),
		-- and panels along the bottom keep this clear of the thumbstick and jump button.
		PhoneSideTop = 8,
		TouchBottomSideClear = 130,
		MinTextSize = 14, -- shrinking text never goes below this
	},

	Player = {
		WalkSpeed = 16,
		SprintSpeed = 24,
		SprintToggleCooldown = 0.1, -- per-player spam guard on the sprint remote
	},

	-- Caught players become ghosts: see-through, floating, can't collect pumpkins, ignored by
	-- the King. Each ghost picks a mode on the ghost screen.
	Ghost = {
		Modes = { "Spectate", "Haunt", "GhostChat" }, -- order shown on the ghost screen
		ModeNames = { Spectate = "Spectate", Haunt = "Haunt", GhostChat = "Ghost chat" },
		DefaultMode = "Haunt",
		ModeSwitchCooldown = 1,
		Transparency = 0.65,
		FlySpeed = 22,
		FlyVerticalSpeed = 14,
		MaxFlyHeight = 40, -- studs above the map floor
		-- Haunt: a ghost near a King can blur its vision for a moment.
		Haunt = {
			Range = 25, -- studs from the ghost to the King
			Seconds = 3, -- how long the King's sight is reduced
			SightMultiplier = 0.4, -- King's SightRange is multiplied by this while haunted
			Cooldown = 15, -- seconds per ghost
		},
	},

	-- Proximity voice (VoiceChatService.UseAudioApi = Enabled, EnableDefaultVoice = true).
	-- Voice is a bonus: everything here must degrade to "nothing happens" for players
	-- without voice, and the game must stay fully playable without it.
	Voice = {
		-- Built-in Acoustic Simulation: voices are muffled through walls and bend around
		-- corners (SoundService.AcousticSimulationEnabled). Map parts block sound unless
		-- their AudioCanCollide is off.
		AcousticSimulation = true,
		-- How loud a voice is by distance: studs -> volume (1 = full, 0 = silent).
		Attenuation = { [0] = 1, [15] = 0.9, [45] = 0.4, [80] = 0 },
		-- Ghost voices get an echo (AudioEcho; levels are in decibels).
		GhostEcho = {
			DelayTime = 0.22, -- seconds between echoes
			Feedback = 0.45, -- 0 = one echo, 1 = never fades
			DryLevel = -2,
			WetLevel = -6,
		},
		-- Ghost chat: ghosts in "GhostChat" mode hear each other; living players never hear
		-- ghosts. Enforced server-side with AudioDeviceInput access lists.
		ReconcileSeconds = 1, -- how often voice routing is re-checked (respawns, mode changes)
		-- Voice -> King noise. The client may send a mic level HINT; the server clamps it,
		-- rate-limits it and turns it into noise. It can never be louder than MaxLoudness,
		-- and non-voice players have the same tools (sprint, pickups, shout).
		Noise = {
			HintSeconds = 0.25, -- client sends at most this often
			MinHintGapSeconds = 0.2, -- server drops hints that arrive faster than this
			MinLevel = 0.04, -- mic level (0-1) below this is treated as silence
			LevelGain = 4, -- mic RMS is small for normal speech; scaled by this, then capped at 1
			MaxLoudness = 18, -- noise at full mic level (Shout is 25)
			RequireActiveMic = false, -- also require AudioDeviceInput.Active (verify on a published place before enabling)
		},
	},

	-- Spawn hub. Built by src/server/Hub/HubBuilder.luau from these settings when Workspace.Hub
	-- is missing (so hand edits made in Studio are kept). Positions are relative to Center.
	Hub = {
		Name = "Spooky Town Square",
		Center = Vector3.new(0, 0, 0), -- top of the baseplate
		Seed = 31, -- random variation in decorations
		Radius = 70, -- cobblestone plaza
		GroundColor = Color3.fromRGB(88, 78, 96),
		GroundMaterial = Enum.Material.Cobblestone,
		Spawn = { Offset = Vector3.new(0, 0, 24), Size = Vector3.new(14, 1, 14) },

		Lighting = {
			ClockTime = 19.6, -- dusk
			Brightness = 1.6,
			Ambient = Color3.fromRGB(70, 55, 95),
			OutdoorAmbient = Color3.fromRGB(95, 75, 120),
			Atmosphere = {
				Density = 0.38,
				Offset = 0.15,
				Color = Color3.fromRGB(150, 120, 190),
				Decay = Color3.fromRGB(255, 140, 70),
				Glare = 0.2,
				Haze = 1.6,
			},
			ColorCorrection = {
				Brightness = 0.02,
				Contrast = 0.12,
				Saturation = 0.18,
				TintColor = Color3.fromRGB(255, 238, 255),
			},
			Bloom = { Intensity = 0.7, Size = 28, Threshold = 0.92 },
		},

		Music = {
			SoundId = "rbxassetid://122867483102494", -- "Haunted Carousel" (DistroKid); "" = no music
			Volume = 0.25,
		},

		Colors = {
			Orange = Color3.fromRGB(255, 130, 20),
			Purple = Color3.fromRGB(120, 60, 170),
			Green = Color3.fromRGB(110, 200, 90),
			Bone = Color3.fromRGB(235, 228, 210),
			Stone = Color3.fromRGB(120, 118, 128),
			Wood = Color3.fromRGB(92, 62, 40),
			Iron = Color3.fromRGB(35, 32, 40),
			Glow = Color3.fromRGB(255, 200, 90),
		},

		ClockTower = {
			Offset = Vector3.new(0, 0, -50),
			Floors = 5,
			FloorHeight = 9,
			Width = 14,
			Lean = 2.5, -- degrees each floor tilts, for the crooked look
			ClockTime = { Hour = 11, Minute = 55 }, -- the hands are frozen just before midnight
		},
		Cauldron = { Offset = Vector3.new(0, 0, 0), Radius = 5 },
		Lampposts = { Count = 10, Radius = 60, Height = 14 },
		Bunting = { FlagsPerSpan = 9, Sag = 2.5, Colors = { "Orange", "Purple", "Green" } },
		JackOLanterns = { Count = 16, Radius = 52, Size = 3 },
		Candles = {
			Count = 18,
			MinRadius = 10,
			MaxRadius = 34,
			MinHeight = 8,
			MaxHeight = 16,
			BobHeight = 0.8,
		},
		Graveyard = {
			Offset = Vector3.new(-48, 0, 34),
			Epitaphs = {
				"RIP Mr. Bones",
				"Here lies Boo's homework",
				"Ate 100 candies",
				"Back in 5 mins",
				"Too spooky",
				"BRB haunting",
			},
		},
		Cobwebs = { Size = 5 },
		DeadTrees = {
			Offsets = {
				Vector3.new(-62, 0, -30),
				Vector3.new(62, 0, -34),
				Vector3.new(-30, 0, 62),
				Vector3.new(58, 0, 52),
			},
		},
		Particles = {
			Fireflies = { Rate = 6, Color = Color3.fromRGB(210, 255, 120) },
			Mist = { Rate = 4, Color = Color3.fromRGB(190, 175, 220) },
			Bubbles = { Rate = 8, Color = Color3.fromRGB(120, 255, 110) },
			Leaves = { Rate = 2, Color = Color3.fromRGB(205, 110, 40) },
		},
		PhotoSpot = {
			Sign = "Spooky Town Square",
			-- Built-in Roblox emotes (the "/e wave" set: wave, point, dance, dance2, dance3, laugh, cheer).
			Emotes = {
				{ Label = "Wave", Emote = "wave" },
				{ Label = "Cheer", Emote = "cheer" },
				{ Label = "Dance", Emote = "dance" },
				{ Label = "Dance 2", Emote = "dance2" },
				{ Label = "Laugh", Emote = "laugh" },
				{ Label = "Point", Emote = "point" },
			},
			CloseDistance = 18, -- the emote bar hides when you walk this far away
		},
	},

	-- Hub NPCs and interactive props. Kind picks the placeholder model; Lines are shown in the
	-- dialog when the prompt is used. Offsets are relative to Hub.Center; they face the center.
	Npcs = {
		InteractCooldown = 0.5,
		List = {
			{
				Id = "WitchWanda",
				Kind = "Witch",
				DisplayName = "Witch Wanda",
				Offset = Vector3.new(-40, 0, -18),
				Prompt = { ActionText = "Shop", ObjectText = "Witch Wanda" },
				OpensShop = "Hat", -- opens the shop on this tab instead of a dialog
				Lines = { "Welcome, dearie! Hats, trails and pets, all freshly brewed." },
			},
			{
				Id = "BooGuide",
				Kind = "Ghost",
				DisplayName = "Boo Guide",
				Offset = Vector3.new(-16, 0, 32),
				Prompt = { ActionText = "Get tips", ObjectText = "Boo Guide" },
				Lines = {
					"Boo! Welcome to Pumpkin Panic! Vote for a map and difficulty on the Voting Board.",
					"In a round, grab as many pumpkins as you can. Each one is worth coins at the end.",
					"The Pumpkin King hunts by sound. Sprinting (Shift), shouting (G) and talking make noise!",
					"If you get caught you become a ghost: spectate, haunt the King, or chat with other ghosts.",
					"Hard mode has two Kings but pays double. Good luck!",
				},
			},
			{
				Id = "PumpkinVendor",
				Kind = "Vendor",
				DisplayName = "Pumpkin Vendor",
				Offset = Vector3.new(40, 0, -18),
				Prompt = { ActionText = "Browse", ObjectText = "Pumpkin Vendor" },
				OpensShop = "Packs",
				Lines = { "Fresh pumpkin packs and VIP passes!" },
			},
			{
				Id = "VotingBoard",
				Kind = "Board",
				DisplayName = "Voting Board",
				Offset = Vector3.new(16, 0, 36),
				Prompt = { ActionText = "Vote", ObjectText = "Voting Board" },
				Lines = {
					"Voting opens between rounds. Pick a map and Easy or Hard on the board or the vote panel.",
				},
			},
			{
				Id = "Leaderboard",
				Kind = "Gravestone",
				DisplayName = "Leaderboard Gravestone",
				Offset = Vector3.new(-30, 0, 46),
				Prompt = { ActionText = "Read", ObjectText = "Top Pumpkin Collectors" },
				Lines = { "Here lie the greatest pumpkin collectors of all time..." },
			},
			{
				Id = "PhotoSpot",
				Kind = "PhotoSpot",
				DisplayName = "Photo Spot",
				Offset = Vector3.new(44, 0, 30),
				Prompt = { ActionText = "Strike a pose", ObjectText = "Photo Spot" },
				Lines = { "Say pumpkin!" },
			},
		},
		Prompt = {
			HoldDuration = 0,
			MaxActivationDistance = 12,
			Height = 3, -- studs above the ground
			Forward = 3, -- studs in front of the NPC, towards the plaza
		},
	},

	-- Leaderboard Gravestone: top lifetime pumpkin collectors.
	Leaderboard = {
		StoreName = "TopPumpkins_v1", -- OrderedDataStore (published places with API access only)
		TopCount = 10,
		RefreshSeconds = 60,
	},

	Economy = {
		-- Pumpkins collected in a round turn into this currency at the end (Rewards above).
		CurrencyName = "Coins",
	},

	-- Cosmetic shop (Witch Wanda, or the Shop button). Prices are in Economy.CurrencyName.
	-- Looks are built from Parts by src/shared/Cosmetics.luau from each item's Style, so the
	-- same code dresses the character (server) and draws the shop previews (client).
	Shop = {
		RequestCooldown = 0.25, -- per-player spam guard on buy/equip
		OpenKey = Enum.KeyCode.B,
		-- Shop tabs, in order; a player wears one item per slot. Skin comes first so it's put
		-- on before the hat (a skin's head piece lifts the hat).
		Slots = { "Skin", "Hat", "Trail", "Pet" },
		SlotNames = { Skin = "Skins", Hat = "Hats", Trail = "Trails", Pet = "Pets" },
		Items = {
			-- Skins recolour your avatar and can add a head piece. HideClothes hides shirts and
			-- pants; Head is a head-piece builder in src/shared/Cosmetics.luau (or drop a model
			-- named after the item Id into ReplicatedStorage.Custom.Cosmetics).
			{
				Id = "Skeleton",
				Name = "Skeleton",
				Slot = "Skin",
				Price = 400,
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(235, 228, 210),
					HideClothes = true,
					Head = "SkinSkull",
					HeadColor = Color3.fromRGB(235, 228, 210),
					GlowColor = Color3.fromRGB(120, 255, 110),
				},
			},
			{
				Id = "PumpkinHead",
				Name = "Pumpkin Head",
				Slot = "Skin",
				Price = 350,
				Style = {
					Kind = "Skin",
					Head = "SkinPumpkin",
					HeadColor = Color3.fromRGB(255, 130, 20),
					GlowColor = Color3.fromRGB(255, 220, 90),
				},
			},
			{
				Id = "Zombie",
				Name = "Zombie",
				Slot = "Skin",
				Price = 300,
				Style = { Kind = "Skin", BodyColor = Color3.fromRGB(120, 170, 95) },
			},
			{
				Id = "Ghost",
				Name = "Ghost",
				Slot = "Skin",
				Price = 500,
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(235, 240, 255),
					Material = Enum.Material.Neon,
					Transparency = 0.3,
					HideClothes = true,
				},
			},
			{
				Id = "Mummy",
				Name = "Mummy",
				Slot = "Skin",
				Price = 450,
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(215, 205, 180),
					Material = Enum.Material.Fabric,
					HideClothes = true,
				},
			},
			{
				Id = "KingSkin",
				Name = "Pumpkin King",
				Slot = "Skin",
				Price = 0,
				VipOnly = true,
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(40, 25, 55),
					HideClothes = true,
					Head = "SkinKing",
					HeadColor = Color3.fromRGB(255, 110, 0),
					GlowColor = Color3.fromRGB(255, 210, 60),
				},
			},
			-- Hats sit on the head.
			{
				Id = "PumpkinCap",
				Name = "Pumpkin Cap",
				Slot = "Hat",
				Price = 100,
				Style = { Kind = "PumpkinCap", Color = Color3.fromRGB(255, 130, 20) },
			},
			{
				Id = "WitchHat",
				Name = "Witch Hat",
				Slot = "Hat",
				Price = 200,
				Style = {
					Kind = "WitchHat",
					Color = Color3.fromRGB(60, 30, 90),
					Band = Color3.fromRGB(255, 130, 20),
				},
			},
			{
				Id = "CatEars",
				Name = "Cat Ears",
				Slot = "Hat",
				Price = 150,
				Style = {
					Kind = "CatEars",
					Color = Color3.fromRGB(40, 35, 45),
					Inner = Color3.fromRGB(255, 150, 190),
				},
			},
			{
				Id = "BatWings",
				Name = "Bat Wings Headband",
				Slot = "Hat",
				Price = 300,
				Style = { Kind = "BatWings", Color = Color3.fromRGB(45, 30, 60) },
			},
			{
				Id = "KingCrown",
				Name = "Pumpkin King Crown",
				Slot = "Hat",
				Price = 0,
				VipOnly = true,
				Style = { Kind = "Crown", Color = Color3.fromRGB(255, 210, 60) },
			},
			-- Trails stream behind you.
			{
				Id = "OrangeTrail",
				Name = "Jack-o'-Glow",
				Slot = "Trail",
				Price = 120,
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(255, 140, 30),
					Color2 = Color3.fromRGB(255, 220, 80),
				},
			},
			{
				Id = "SlimeTrail",
				Name = "Slime Drip",
				Slot = "Trail",
				Price = 180,
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(120, 255, 110),
					Color2 = Color3.fromRGB(40, 160, 60),
				},
			},
			{
				Id = "GhostTrail",
				Name = "Ghostly Mist",
				Slot = "Trail",
				Price = 250,
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(200, 230, 255),
					Color2 = Color3.fromRGB(150, 120, 220),
				},
			},
			{
				Id = "CandyTrail",
				Name = "Candy Corn",
				Slot = "Trail",
				Price = 0,
				VipOnly = true,
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(255, 200, 40),
					Color2 = Color3.fromRGB(255, 110, 20),
				},
			},
			-- Pets float by your shoulder.
			{
				Id = "MiniPumpkin",
				Name = "Mini Pumpkin",
				Slot = "Pet",
				Price = 300,
				Style = { Kind = "PumpkinPet", Color = Color3.fromRGB(255, 130, 20) },
			},
			{
				Id = "BabyBat",
				Name = "Baby Bat",
				Slot = "Pet",
				Price = 450,
				Style = { Kind = "BatPet", Color = Color3.fromRGB(50, 35, 70) },
			},
			{
				Id = "GhostKitty",
				Name = "Ghost Kitty",
				Slot = "Pet",
				Price = 600,
				Style = { Kind = "GhostPet", Color = Color3.fromRGB(200, 230, 255) },
			},
			{
				Id = "SkellyPup",
				Name = "Skelly Pup",
				Slot = "Pet",
				Price = 0,
				VipOnly = true,
				Style = { Kind = "SkullPet", Color = Color3.fromRGB(235, 228, 210) },
			},
		} :: { any }, -- styles differ per Kind
		PetOffset = Vector3.new(2.6, 1.2, 1.5), -- from the character's root (right, up, back)
		TrailLifetime = 0.6,
	},

	-- Robux purchases. IDs are 0 until the owner creates them in Creator Hub (see
	-- docs/PROGRESS.md, M6); with an ID of 0 the shop shows "Coming soon" and nothing prompts.
	Monetization = {
		VipGamePassId = 0,
		VipName = "VIP",
		VipSuggestedRobux = 249, -- for reference only; the real price is set in Creator Hub
		-- The paid gameplay edge (docs/DESIGN.md): kept modest so free players aren't left behind.
		VipSpeedMultiplier = 1.1, -- walk and sprint speed
		Tracker = {
			Key = Enum.KeyCode.T,
			Cooldown = 30, -- seconds between uses
			ShowSeconds = 5, -- the arrow to the nearest King shows this long
		},
		ChatTag = { Text = "[VIP]", Color = Color3.fromRGB(255, 210, 60) },
		VipPerks = {
			"+10% walk and sprint speed",
			"King tracker: press T for an arrow to the nearest King (30 s cooldown)",
			"VIP chat tag and VIP-only cosmetics (Pumpkin King skin, crown, trail and pet)",
		},
		-- Developer Products: coin packs. Key is saved with each receipt; don't rename.
		Products = {
			{
				Key = "PumpkinPouch",
				Name = "Pumpkin Pouch",
				Id = 0,
				Coins = 250,
				SuggestedRobux = 25,
			},
			{
				Key = "PumpkinCart",
				Name = "Pumpkin Cart",
				Id = 0,
				Coins = 1200,
				SuggestedRobux = 99,
			},
			{
				Key = "PumpkinMountain",
				Name = "Pumpkin Mountain",
				Id = 0,
				Coins = 3500,
				SuggestedRobux = 249,
			},
		},
		ReceiptHistory = 50, -- receipt ids remembered per player, so a purchase is never granted twice
	},

	-- Custom art: drop your own models into ReplicatedStorage.Custom (docs/CUSTOMIZE.md,
	-- src/shared/CustomAssets.luau). They're scaled to these sizes unless they have the
	-- attribute KeepSize = true.
	Custom = {
		StripScripts = true, -- remove scripts from custom models (free models can hide bad ones)
		Heights = { -- studs, feet to top
			PumpkinKing = 10,
			SkeletonPatrol = 6.2,
			Bat = 1.4,
			GhostCat = 3,
			WitchWanda = 8,
			BooGuide = 6.5,
			PumpkinVendor = 7.5,
		} :: { [string]: number },
		CosmeticSize = { Hat = 2, Pet = 1.6, Skin = 2.4 } :: { [string]: number }, -- biggest side, studs
		-- Walk and idle for a custom King that is a real R15 rig (Roblox's own R15 animations).
		RigAnimations = {
			Walk = "rbxassetid://507777826",
			Idle = "rbxassetid://507766388",
		},
	},

	-- Codes players type in the Codes box (Shop > Codes). Give one to each YouTuber/TikToker
	-- and add a new one every update. Code is case-insensitive. Expires is "YYYY-MM-DD" (the
	-- code works until the end of that day, UTC) or "" for never. Reward Coins, Item (a shop
	-- item Id) or both.
	Codes = {
		RequestCooldown = 2, -- seconds between attempts per player
		List = {
			{ Code = "PUMPKIN", Coins = 250, Expires = "" },
			{ Code = "RELEASE", Coins = 500, Expires = "2026-11-15" },
			{ Code = "SPOOKY", Item = "PumpkinCap", Expires = "2026-11-01" },
		} :: { { Code: string, Coins: number?, Item: string?, Expires: string } },
	},

	-- Daily login streak: coins the first time you join each day. Missing more than
	-- GraceHours since your last claim resets the streak to day 1.
	Daily = {
		Rewards = { 50, 75, 100, 150, 200, 250, 500 }, -- day 1..7; after day 7 the last one repeats
		CooldownHours = 20, -- earliest next claim
		GraceHours = 48,
	},

	-- Friends make the algorithm and the game better (docs/VIRAL.md).
	Social = {
		FriendBonusPercent = 10, -- extra round coins per Roblox friend in the same server...
		MaxFriendBonusPercent = 50, -- ...up to this
		InviteButton = true, -- "Invite friends" button on the HUD
		FavoritePromptAfterRounds = 1, -- ask to favourite once, after this many finished rounds; 0 = never
		GroupId = 0, -- your Roblox group (0 = none); members get GroupBonusPercent extra round coins
		GroupBonusPercent = 10,
	},

	-- Owner-only test panel (press OpenKey). The experience owner, the group owner and
	-- UserIds are admins. Commands are checked on the server.
	Admin = {
		UserIds = {} :: { number },
		OpenKey = Enum.KeyCode.F8,
		AllowInLiveServers = false, -- false = only in Studio playtests
		CoinsPerClick = 1000,
	},

	Data = {
		StoreName = "PlayerData_v1", -- bump the suffix to wipe/reset all saves
		AutosaveSeconds = 120,
		Template = {
			Coins = 0,
			Wins = 0,
			Joins = 0,
			PumpkinsCollected = 0, -- lifetime, for the Leaderboard Gravestone
			Owned = {} :: { [string]: boolean }, -- [itemId] = true
			Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" }, -- item id per Shop slot, "" = none
			Receipts = {} :: { string }, -- recent Developer Product purchase ids (newest last)
			Codes = {} :: { [string]: boolean }, -- redeemed codes, upper case
			Daily = { Streak = 0, Last = 0 }, -- login streak and the os.time() of the last claim
			RoundsPlayed = 0,
			FavoritePrompted = false,
			Settings = { Music = true, Sounds = true }, -- the Settings panel's toggles
		},
	},

	AI = {
		-- Off until an in-game chat box uses it (nothing calls AskNpc yet; see docs/ROADMAP.md).
		Enabled = false,
		MaxRequestsPerMinute = 60, -- whole server, protects your API bill
		-- Your proxy (see tools/ai-proxy). The key lives in Roblox Secrets, never in code.
		ProxyUrl = "https://YOUR-WORKER.workers.dev/chat",
		SecretName = "AI_PROXY_KEY",
		CooldownSeconds = 3, -- per player
		MaxMessageLength = 200,
		MaxReplyTokens = 150,
		Npcs = {
			Guide = {
				DisplayName = "Guide Bot",
				Persona = "You are Guide Bot, a cheerful helper in a Roblox game. "
					.. "Keep replies under 2 short sentences, kid-friendly, no links, "
					.. "never discuss real-world personal info. Stay in character.",
			},
		},
	},

	Moderation = {
		-- AI text is ALWAYS filtered with TextService before display. Don't remove.
		FilterAIText = true,
	},
}

return Config
