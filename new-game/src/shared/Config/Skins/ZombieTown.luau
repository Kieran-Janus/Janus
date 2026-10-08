--!strict
--[[
	ZOMBIE TOWN CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (ZombieTownCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "ZombieTown_ShufflingMailman",
		Name = "Shuffling Mailman",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 150, 80),
			ArmsColor = rgb(60, 80, 120),
			LegsColor = rgb(200, 200, 90),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 80, 50), Pattern = "Sash" },
		},
	},
	{
		Id = "ZombieTown_BrainSnacker",
		Name = "Brain Snacker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 120, 110),
			ArmsColor = rgb(60, 80, 120),
			LegsColor = rgb(170, 50, 40),
			Accent = { Color = rgb(170, 50, 40), Pattern = "Tail" },
		},
	},
	{
		Id = "ZombieTown_UndeadJogger",
		Name = "Undead Jogger",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 80, 120),
			ArmsColor = rgb(170, 50, 40),
			LegsColor = rgb(120, 120, 110),
			Material = M.Concrete,
			Accent = { Color = rgb(200, 200, 90), Pattern = { "Star", "Buttons" } },
		},
	},
	{
		Id = "ZombieTown_RottenPlumber",
		Name = "Rotten Plumber",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 80, 120),
			Material = M.Pebble,
			Accent = { Color = rgb(110, 150, 80), Pattern = "Cuffs" },
		},
	},
	{
		Id = "ZombieTown_ZombiePaperboy",
		Name = "Zombie Paperboy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 80, 50),
			ArmsColor = rgb(110, 150, 80),
			LegsColor = rgb(60, 80, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(120, 120, 110), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "ZombieTown_LurchingChef",
		Name = "Lurching Chef",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 50, 40),
			ArmsColor = rgb(110, 150, 80),
			LegsColor = rgb(100, 80, 120),
			Accent = { Color = rgb(100, 80, 120), Pattern = { "Belly", "Bones" } },
		},
	},
	{
		Id = "ZombieTown_MoldyMayor",
		Name = "Moldy Mayor",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 200, 90),
			ArmsColor = rgb(100, 80, 120),
			LegsColor = rgb(170, 50, 40),
			Material = M.Concrete,
			Accent = { Color = rgb(60, 80, 120), Pattern = "Stitches" },
		},
	},
	{
		Id = "ZombieTown_GraveyardGardener",
		Name = "Graveyard Gardener",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(110, 150, 80),
			Material = M.Pebble,
			Accent = { Color = rgb(110, 80, 50), Pattern = "Cape" },
		},
	},
	{
		Id = "ZombieTown_StitchyStudent",
		Name = "Stitchy Student",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 120, 110),
			ArmsColor = rgb(110, 80, 50),
			LegsColor = rgb(110, 150, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(170, 50, 40), Pattern = { "Web", "Stitches" } },
		},
	},
	{
		Id = "ZombieTown_GroaningGrocer",
		Name = "Groaning Grocer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 80, 120),
			ArmsColor = rgb(110, 80, 50),
			LegsColor = rgb(200, 200, 90),
			Accent = { Color = rgb(200, 200, 90), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "ZombieTown_PatchworkTourist",
		Name = "Patchwork Tourist",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 80, 120),
			ArmsColor = rgb(200, 200, 90),
			LegsColor = rgb(100, 80, 120),
			Material = M.Concrete,
			Accent = { Color = rgb(110, 150, 80), Pattern = "Gloves" },
		},
	},
	{
		Id = "ZombieTown_SleepySheriff",
		Name = "Sleepy Sheriff",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(110, 80, 50),
			Material = M.Pebble,
			Accent = { Color = rgb(120, 120, 110), Pattern = { "Wraps", "Patches" } },
		},
	},
	{
		Id = "ZombieTown_DecayingDJ",
		Name = "Decaying DJ",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 50, 40),
			ArmsColor = rgb(120, 120, 110),
			LegsColor = rgb(110, 80, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(100, 80, 120), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "ZombieTown_ZombieRocker",
		Name = "Zombie Rocker",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 200, 90),
			ArmsColor = rgb(100, 80, 120),
			LegsColor = rgb(170, 50, 40),
			Accent = { Color = rgb(60, 80, 120), Pattern = { "Patches", "Wraps" } },
			Head = "ZombieHead",
			HeadColor = rgb(100, 80, 120),
			HeadColor2 = rgb(170, 50, 40),
			GlowColor = rgb(110, 150, 80),
		},
	},
	{
		Id = "ZombieTown_BrainyProfessor",
		Name = "Brainy Professor",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(110, 150, 80),
			ArmsColor = rgb(60, 80, 120),
			LegsColor = rgb(200, 200, 90),
			Accent = { Color = rgb(110, 80, 50), Material = M.Neon, Pattern = { "Wings", "Sash" } },
			Head = "FrankenHead",
			HeadColor = rgb(110, 80, 50),
			HeadColor2 = rgb(110, 150, 80),
			GlowColor = rgb(100, 80, 120),
		},
	},
	{
		Id = "ZombieTown_UndeadBuilder",
		Name = "Undead Builder",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(120, 120, 110),
			Accent = { Color = rgb(170, 50, 40), Pattern = { "Heart", "Belt" } },
			Head = "ZombieHead",
			HeadColor = rgb(200, 200, 90),
			HeadColor2 = rgb(100, 80, 120),
			GlowColor = rgb(110, 80, 50),
		},
	},
	{
		Id = "ZombieTown_SwampyShambler",
		Name = "Swampy Shambler",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(100, 80, 120),
			ArmsColor = rgb(170, 50, 40),
			LegsColor = rgb(120, 120, 110),
			Accent = { Color = rgb(200, 200, 90), Pattern = { "Collar", "Spots" } },
			Head = "FrankenHead",
			HeadColor = rgb(120, 120, 110),
			HeadColor2 = rgb(110, 80, 50),
			GlowColor = rgb(200, 200, 90),
		},
	},
	{
		Id = "ZombieTown_MidnightMechanic",
		Name = "Midnight Mechanic",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 80, 120),
			ArmsColor = rgb(200, 200, 90),
			LegsColor = rgb(100, 80, 120),
			Accent = { Color = rgb(110, 150, 80), Pattern = { "Boots", "Cape" } },
			Head = "ZombieHead",
			HeadColor = rgb(60, 80, 120),
			HeadColor2 = rgb(200, 200, 90),
			GlowColor = rgb(120, 120, 110),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "ZombieTown_ZombieOverlord",
		Name = "Zombie Overlord",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 200, 90),
			ArmsColor = rgb(60, 80, 120),
			LegsColor = rgb(110, 150, 80),
			Accent = { Color = rgb(60, 80, 120), Pattern = { "Sash", "Wings" } },
			Head = "ZombieHead",
			HeadColor = rgb(170, 50, 40),
			HeadColor2 = rgb(110, 150, 80),
			GlowColor = rgb(110, 80, 50),
			Glow = { Color = rgb(110, 80, 50), Brightness = 1.6 },
			Aura = { Kind = "Smoke", Color = rgb(110, 80, 50), Color2 = rgb(120, 120, 110) },
			Animate = {
				{ Effect = "Flap", Target = "Wings", Speed = 0.7, Amount = 0.8 },
			} :: { any }, -- (effects differ in shape)
			Motion = "Zombie",
		},
	},
	{
		Id = "ZombieTown_PlagueDoctor",
		Name = "Plague Doctor",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(110, 150, 80),
			ArmsColor = rgb(110, 80, 50),
			LegsColor = rgb(120, 120, 110),
			Accent = { Color = rgb(110, 80, 50), Pattern = { "Tail", "Cuffs" } },
			Head = "TombstoneHead",
			HeadColor = rgb(120, 120, 110),
			HeadColor2 = rgb(60, 80, 120),
			GlowColor = rgb(110, 150, 80),
			Glow = { Color = rgb(110, 150, 80), Brightness = 1.8 },
			Aura = { Kind = "Bubbles", Color = rgb(110, 150, 80), Color2 = rgb(110, 80, 50) },
		},
	},
	{
		Id = "ZombieTown_RottingRoyalty",
		Name = "Rotting Royalty",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 120, 110),
			ArmsColor = rgb(170, 50, 40),
			LegsColor = rgb(100, 80, 120),
			Accent = { Color = rgb(170, 50, 40), Pattern = { "Star", "Buttons" } },
			Head = "FrankenHead",
			HeadColor = rgb(110, 80, 50),
			HeadColor2 = rgb(200, 200, 90),
			GlowColor = rgb(60, 80, 120),
			Glow = { Color = rgb(60, 80, 120), Brightness = 2.0 },
			Aura = { Kind = "Embers", Color = rgb(60, 80, 120), Color2 = rgb(110, 150, 80) },
		},
	},
} :: { any }
