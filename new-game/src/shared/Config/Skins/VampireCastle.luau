--!strict
--[[
	VAMPIRE CASTLE CRATE SKINS (22): 13 Common, 5 Uncommon, 3 Rare, and 1 CRAZY that is ONE IN A MILLION (Odds = 0.0001: 0.0001% a crate).
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (VampireCastleCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "VampireCastle_NightButler",
		Name = "Night Butler",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 20, 40),
			ArmsColor = rgb(230, 190, 80),
			LegsColor = rgb(190, 190, 205),
			Accent = { Color = rgb(235, 225, 230), Pattern = "Belly" },
		},
	},
	{
		Id = "VampireCastle_VelvetCloak",
		Name = "Velvet Cloak",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 15, 25),
			ArmsColor = rgb(230, 190, 80),
			LegsColor = rgb(110, 15, 45),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 15, 45), Pattern = "Stitches" },
		},
	},
	{
		Id = "VampireCastle_CrimsonCount",
		Name = "Crimson Count",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 30, 120),
			ArmsColor = rgb(110, 15, 45),
			LegsColor = rgb(25, 15, 25),
			Material = M.Foil,
			Accent = { Color = rgb(190, 190, 205), Pattern = { "Cape", "Spots" } },
		},
	},
	{
		Id = "VampireCastle_CastleGuard",
		Name = "Castle Guard",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(230, 190, 80),
			Material = M.Marble,
			Accent = { Color = rgb(170, 20, 40), Pattern = "Web" },
		},
	},
	{
		Id = "VampireCastle_MoonlitMaid",
		Name = "Moonlit Maid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 225, 230),
			ArmsColor = rgb(170, 20, 40),
			LegsColor = rgb(230, 190, 80),
			Accent = { Color = rgb(25, 15, 25), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "VampireCastle_GarlicHater",
		Name = "Garlic Hater",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 15, 45),
			ArmsColor = rgb(170, 20, 40),
			LegsColor = rgb(90, 30, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(90, 30, 120), Pattern = { "Gloves", "Belly" } },
		},
	},
	{
		Id = "VampireCastle_CoffinNapper",
		Name = "Coffin Napper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 190, 205),
			ArmsColor = rgb(90, 30, 120),
			LegsColor = rgb(110, 15, 45),
			Material = M.Foil,
			Accent = { Color = rgb(230, 190, 80), Pattern = "Wraps" },
		},
	},
	{
		Id = "VampireCastle_BatwingPage",
		Name = "Batwing Page",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 20, 40),
			Material = M.Marble,
			Accent = { Color = rgb(235, 225, 230), Pattern = "Buttons" },
		},
	},
	{
		Id = "VampireCastle_RubyDuchess",
		Name = "Ruby Duchess",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 15, 25),
			ArmsColor = rgb(235, 225, 230),
			LegsColor = rgb(170, 20, 40),
			Accent = { Color = rgb(110, 15, 45), Pattern = { "Patches", "Buttons" } },
		},
	},
	{
		Id = "VampireCastle_SilverStake",
		Name = "Silver Stake",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 30, 120),
			ArmsColor = rgb(235, 225, 230),
			LegsColor = rgb(190, 190, 205),
			Material = M.Fabric,
			Accent = { Color = rgb(190, 190, 205), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "VampireCastle_WineStain",
		Name = "Wine Stain",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 190, 80),
			ArmsColor = rgb(190, 190, 205),
			LegsColor = rgb(90, 30, 120),
			Material = M.Foil,
			Accent = { Color = rgb(170, 20, 40), Pattern = "Heart" },
		},
	},
	{
		Id = "VampireCastle_MidnightWaltz",
		Name = "Midnight Waltz",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(235, 225, 230),
			Material = M.Marble,
			Accent = { Color = rgb(25, 15, 25), Pattern = { "Collar", "Bones" } },
		},
	},
	{
		Id = "VampireCastle_GothicKnight",
		Name = "Gothic Knight",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 15, 45),
			ArmsColor = rgb(25, 15, 25),
			LegsColor = rgb(235, 225, 230),
			Accent = { Color = rgb(90, 30, 120), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "VampireCastle_FangPrince",
		Name = "Fang Prince",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(190, 190, 205),
			ArmsColor = rgb(90, 30, 120),
			LegsColor = rgb(110, 15, 45),
			Accent = { Color = rgb(230, 190, 80), Pattern = { "Spots", "Boots" } },
			Head = "VampireHead",
			HeadColor = rgb(90, 30, 120),
			HeadColor2 = rgb(110, 15, 45),
			GlowColor = rgb(170, 20, 40),
		},
	},
	{
		Id = "VampireCastle_BatBaron",
		Name = "Bat Baron",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(170, 20, 40),
			ArmsColor = rgb(230, 190, 80),
			LegsColor = rgb(190, 190, 205),
			Accent = {
				Color = rgb(235, 225, 230),
				Material = M.Neon,
				Pattern = { "Bones", "Stitches" },
			},
			Head = "BatHead",
			HeadColor = rgb(235, 225, 230),
			HeadColor2 = rgb(170, 20, 40),
			GlowColor = rgb(90, 30, 120),
		},
	},
	{
		Id = "VampireCastle_TwilightCountess",
		Name = "Twilight Countess",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(25, 15, 25),
			Accent = { Color = rgb(110, 15, 45), Pattern = { "Sash", "Heart" } },
			Head = "VampireHead",
			HeadColor = rgb(190, 190, 205),
			HeadColor2 = rgb(90, 30, 120),
			GlowColor = rgb(235, 225, 230),
		},
	},
	{
		Id = "VampireCastle_CapeDancer",
		Name = "Cape Dancer",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(90, 30, 120),
			ArmsColor = rgb(110, 15, 45),
			LegsColor = rgb(25, 15, 25),
			Accent = { Color = rgb(190, 190, 205), Pattern = { "Tail", "Stripes" } },
			Head = "BatHead",
			HeadColor = rgb(25, 15, 25),
			HeadColor2 = rgb(235, 225, 230),
			GlowColor = rgb(190, 190, 205),
		},
	},
	{
		Id = "VampireCastle_MoatLurker",
		Name = "Moat Lurker",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 190, 80),
			ArmsColor = rgb(190, 190, 205),
			LegsColor = rgb(90, 30, 120),
			Accent = { Color = rgb(170, 20, 40), Pattern = { "Star", "Patches" } },
			Head = "VampireHead",
			HeadColor = rgb(230, 190, 80),
			HeadColor2 = rgb(190, 190, 205),
			GlowColor = rgb(25, 15, 25),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "VampireCastle_BloodMoonDuke",
		Name = "Blood Moon Duke",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(190, 190, 205),
			ArmsColor = rgb(230, 190, 80),
			LegsColor = rgb(170, 20, 40),
			Accent = { Color = rgb(230, 190, 80), Pattern = { "Belly", "Sash" } },
			Head = "VampireHead",
			HeadColor = rgb(110, 15, 45),
			HeadColor2 = rgb(170, 20, 40),
			GlowColor = rgb(235, 225, 230),
			Glow = { Color = rgb(235, 225, 230), Brightness = 1.6 },
			Aura = { Kind = "Embers", Color = rgb(235, 225, 230), Color2 = rgb(25, 15, 25) },
		},
	},
	{
		Id = "VampireCastle_CryptSovereign",
		Name = "Crypt Sovereign",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(170, 20, 40),
			ArmsColor = rgb(235, 225, 230),
			LegsColor = rgb(25, 15, 25),
			Accent = { Color = rgb(235, 225, 230), Pattern = { "Stitches", "Belt" } },
			Head = "BatHead",
			HeadColor = rgb(25, 15, 25),
			HeadColor2 = rgb(230, 190, 80),
			GlowColor = rgb(170, 20, 40),
			Glow = { Color = rgb(170, 20, 40), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(170, 20, 40), Color2 = rgb(235, 225, 230) },
		},
	},
	{
		Id = "VampireCastle_EternalNight",
		Name = "Eternal Night",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(25, 15, 25),
			ArmsColor = rgb(110, 15, 45),
			LegsColor = rgb(90, 30, 120),
			Accent = { Color = rgb(110, 15, 45), Pattern = { "Cape", "Spots" } },
			Head = "VampireHead",
			HeadColor = rgb(235, 225, 230),
			HeadColor2 = rgb(190, 190, 205),
			GlowColor = rgb(230, 190, 80),
			Glow = { Color = rgb(230, 190, 80), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(230, 190, 80), Color2 = rgb(170, 20, 40) },
		},
	},

	-- ONE IN A MILLION (CRAZY, 0.0001% a crate: the flashiest skin in the game) ----------
	{
		Id = "VampireCastle_NightLordSupreme",
		Name = "Night Lord Supreme",
		Rarity = "Crazy",
		OneInAMillion = true, -- only in this crate, never in the CRAZY Crate
		Odds = 0.0001, -- percent: 1 in 1,000,000 opens
		Style = {
			BodyColor = rgb(25, 10, 25),
			Material = M.Foil,
			Accent = {
				Color = rgb(200, 20, 50),
				Material = M.Neon,
				Pattern = { "Cape", "Gloves", "Boots", "Belt" },
			},
			Head = "NightLord",
			HeadColor = rgb(235, 225, 235),
			HeadColor2 = rgb(30, 10, 30),
			GlowColor = rgb(255, 30, 60),
			Glow = { Color = rgb(255, 30, 60), Brightness = 3, Range = 16 },
			Aura = { Kind = "Embers", Color = rgb(255, 40, 60), Color2 = rgb(90, 0, 30) },
			Crazy = {
				Rainbow = true,
				Pulse = true,
				Orbit = "Bats",
				Count = 5,
				Effect = "BloodMoon",
			},
			Animate = {
				{ Effect = "Wobble", Target = "Cape", Speed = 0.6, Amount = 0.8 },
				{ Effect = "Breathe", Target = "Head", Amount = 1.5 },
				{ Effect = "SparkleBurst", Every = 5, Count = 25 },
			} :: { any }, -- (effects differ in shape)
			Motion = "Bat",
		},
	},
} :: { any }
