--!strict
--[[
	THE tweak file. Every number, name, price and AI persona lives here.
	Want a longer round? Change Round.Duration. Want a new NPC? Add to AI.Npcs.
	Nothing else in the codebase should hardcode gameplay values.
]]

local Config = {
	Game = {
		Name = "New Game", -- rename me
		Version = "0.1.0",
	},

	Round = {
		MinPlayers = 2,
		IntermissionSeconds = 20,
		Duration = 120,
		RewardWinner = 100,
		RewardParticipant = 25,
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
