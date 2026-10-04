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

	Voting = {
		Seconds = 20,
		MapChoices = 3, -- maps offered per vote (capped by how many maps exist)
		MinSecondsBetweenVotes = 0.2, -- per-player spam guard on the vote remote
	},

	Maps = {
		Origin = Vector3.new(0, 0, 1000), -- where the round map is built, away from the lobby
		SpawnHeight = 4, -- studs above a spawn pad that a character is placed
		-- Real maps: put a Model named after the Id in ServerStorage.Maps, with a part named
		-- "Floor" and a folder named SpawnFolder holding spawn parts. Until one exists, a
		-- placeholder is built from the Placeholder settings.
		List = {
			{
				Id = "PumpkinPatch",
				Name = "Haunted Pumpkin Patch",
				Thumbnail = 0, -- rbxassetid, 0 = none yet
				SpawnFolder = "Spawns",
				Placeholder = {
					Size = Vector3.new(220, 1, 220),
					FloorColor = Color3.fromRGB(62, 92, 44),
					WallHeight = 14,
					WallColor = Color3.fromRGB(60, 40, 30),
					Obstacles = 22,
					ObstacleMinSize = Vector3.new(6, 4, 6),
					ObstacleMaxSize = Vector3.new(16, 10, 16),
					ObstacleColor = Color3.fromRGB(110, 70, 40),
					ObstacleClearRadius = 40, -- keep obstacles away from the spawn ring
					Spawns = 8,
					SpawnRadius = 20,
					Seed = 1,
				},
			},
			{
				Id = "SpookyMansion",
				Name = "Spooky Mansion",
				Thumbnail = 0,
				SpawnFolder = "Spawns",
				Placeholder = {
					Size = Vector3.new(180, 1, 180),
					FloorColor = Color3.fromRGB(70, 55, 80),
					WallHeight = 20,
					WallColor = Color3.fromRGB(40, 30, 50),
					Obstacles = 30,
					ObstacleMinSize = Vector3.new(4, 12, 20),
					ObstacleMaxSize = Vector3.new(6, 16, 40),
					ObstacleColor = Color3.fromRGB(90, 75, 100),
					ObstacleClearRadius = 35,
					Spawns = 8,
					SpawnRadius = 18,
					Seed = 2,
				},
			},
		},
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
			AgentCanJump = false,
			WaypointSpacing = 4,
		},
		-- Noise attracts the King. Every loudness below is decided by the server; clients only
		-- say "I'm sprinting" or "I shouted". Sprint, pickups and shouting mean players without
		-- voice still play the stealth game (docs/DESIGN.md). M3 adds voice only as a clamped,
		-- rate-limited hint on top.
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
			SoundId = "", -- e.g. "rbxassetid://123"; empty = no music (pick one from the Creator Store)
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
				Lines = {
					"Welcome, dearie! My cauldron of cosmetics is still bubbling.",
					"Hats, pets, trails and spooky voices are coming soon. Save your pumpkins!",
				},
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
				Lines = {
					"Fresh pumpkins! Well... pumpkin packs, soon.",
					"My stall opens with the shop update. Come back then!",
				},
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
		CurrencyName = "Coins",
		StartingCoins = 0,
		-- Add products/gamepasses here and read them in a ShopService.
		Products = {
			-- DoubleCoins = { Id = 0, Price = 199 },
		},
	},

	Data = {
		StoreName = "PlayerData_v1", -- bump the suffix to wipe/reset all saves
		AutosaveSeconds = 120,
		Template = {
			Coins = 0,
			Wins = 0,
			Joins = 0,
			PumpkinsCollected = 0, -- lifetime, for the Leaderboard Gravestone
		},
	},

	AI = {
		Enabled = true,
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
