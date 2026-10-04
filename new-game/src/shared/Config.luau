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
