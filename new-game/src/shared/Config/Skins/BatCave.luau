--!strict
--[[
	BAT CAVE CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (BatCaveCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "BatCave_CaveExplorer",
		Name = "Cave Explorer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(70, 70, 80),
			ArmsColor = rgb(150, 140, 130),
			LegsColor = rgb(200, 30, 60),
			Material = M.Slate,
			Accent = { Color = rgb(80, 120, 200), Pattern = "Gloves" },
		},
	},
	{
		Id = "BatCave_EchoKid",
		Name = "Echo Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(150, 140, 130),
			LegsColor = rgb(80, 110, 60),
			Material = M.Basalt,
			Accent = { Color = rgb(80, 110, 60), Pattern = "Wraps" },
		},
	},
	{
		Id = "BatCave_StalactiteSam",
		Name = "Stalactite Sam",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 60, 160),
			ArmsColor = rgb(80, 110, 60),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(200, 30, 60), Pattern = { "Buttons", "Collar" } },
		},
	},
	{
		Id = "BatCave_CaveDiver",
		Name = "Cave Diver",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 140, 130),
			Material = M.Fabric,
			Accent = { Color = rgb(70, 70, 80), Pattern = "Patches" },
		},
	},
	{
		Id = "BatCave_FruitBatFan",
		Name = "Fruit Bat Fan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 120, 200),
			ArmsColor = rgb(70, 70, 80),
			LegsColor = rgb(150, 140, 130),
			Material = M.Slate,
			Accent = { Color = rgb(30, 25, 35), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "BatCave_NightFlapper",
		Name = "Night Flapper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 110, 60),
			ArmsColor = rgb(70, 70, 80),
			LegsColor = rgb(110, 60, 160),
			Material = M.Basalt,
			Accent = { Color = rgb(110, 60, 160), Pattern = { "Heart", "Cuffs" } },
		},
	},
	{
		Id = "BatCave_CrystalMiner",
		Name = "Crystal Miner",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 30, 60),
			ArmsColor = rgb(110, 60, 160),
			LegsColor = rgb(80, 110, 60),
			Accent = { Color = rgb(150, 140, 130), Pattern = "Collar" },
		},
	},
	{
		Id = "BatCave_LanternSpelunker",
		Name = "Lantern Spelunker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(70, 70, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(80, 120, 200), Pattern = "Boots" },
		},
	},
	{
		Id = "BatCave_UpsideDownPal",
		Name = "Upside-Down Pal",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(80, 120, 200),
			LegsColor = rgb(70, 70, 80),
			Material = M.Slate,
			Accent = { Color = rgb(80, 110, 60), Pattern = { "Spots", "Gloves" } },
		},
	},
	{
		Id = "BatCave_MothChaser",
		Name = "Moth Chaser",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 60, 160),
			ArmsColor = rgb(80, 120, 200),
			LegsColor = rgb(200, 30, 60),
			Material = M.Basalt,
			Accent = { Color = rgb(200, 30, 60), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "BatCave_DripstoneDan",
		Name = "Dripstone Dan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 140, 130),
			ArmsColor = rgb(200, 30, 60),
			LegsColor = rgb(110, 60, 160),
			Accent = { Color = rgb(70, 70, 80), Pattern = "Sash" },
		},
	},
	{
		Id = "BatCave_WingNapper",
		Name = "Wing Napper",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(80, 120, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(30, 25, 35), Pattern = { "Tail", "Boots" } },
		},
	},
	{
		Id = "BatCave_SonarScout",
		Name = "Sonar Scout",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(80, 110, 60),
			ArmsColor = rgb(30, 25, 35),
			LegsColor = rgb(80, 120, 200),
			Material = M.Slate,
			Accent = { Color = rgb(110, 60, 160), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "BatCave_BatKing",
		Name = "Bat King",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 30, 60),
			ArmsColor = rgb(110, 60, 160),
			LegsColor = rgb(80, 110, 60),
			Accent = { Color = rgb(150, 140, 130), Pattern = { "Cuffs", "Heart" } },
			Head = "BatHead",
			HeadColor = rgb(110, 60, 160),
			HeadColor2 = rgb(80, 110, 60),
			GlowColor = rgb(70, 70, 80),
		},
	},
	{
		Id = "BatCave_MothMystic",
		Name = "Moth Mystic",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(70, 70, 80),
			ArmsColor = rgb(150, 140, 130),
			LegsColor = rgb(200, 30, 60),
			Accent = { Color = rgb(80, 120, 200), Material = M.Neon, Pattern = "Stripes" },
			Head = "MothHead",
			HeadColor = rgb(80, 120, 200),
			HeadColor2 = rgb(70, 70, 80),
			GlowColor = rgb(110, 60, 160),
		},
	},
	{
		Id = "BatCave_VampireBat",
		Name = "Vampire Bat",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(30, 25, 35),
			Accent = { Color = rgb(80, 110, 60), Pattern = { "Belly", "Patches" } },
			Head = "BatHead",
			HeadColor = rgb(200, 30, 60),
			HeadColor2 = rgb(110, 60, 160),
			GlowColor = rgb(80, 120, 200),
		},
	},
	{
		Id = "BatCave_EchoMaster",
		Name = "Echo Master",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(110, 60, 160),
			ArmsColor = rgb(80, 110, 60),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(200, 30, 60), Pattern = { "Stitches", "Star" } },
			Head = "MothHead",
			HeadColor = rgb(30, 25, 35),
			HeadColor2 = rgb(80, 120, 200),
			GlowColor = rgb(200, 30, 60),
		},
	},
	{
		Id = "BatCave_CaveShaman",
		Name = "Cave Shaman",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 140, 130),
			ArmsColor = rgb(200, 30, 60),
			LegsColor = rgb(110, 60, 160),
			Accent = { Color = rgb(70, 70, 80), Pattern = { "Cape", "Wraps" } },
			Head = "BatHead",
			HeadColor = rgb(150, 140, 130),
			HeadColor2 = rgb(200, 30, 60),
			GlowColor = rgb(30, 25, 35),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "BatCave_BatSwarmLord",
		Name = "Bat Swarm Lord",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 30, 60),
			ArmsColor = rgb(150, 140, 130),
			LegsColor = rgb(70, 70, 80),
			Accent = { Color = rgb(150, 140, 130), Pattern = { "Gloves", "Spots" } },
			Head = "BatHead",
			HeadColor = rgb(80, 110, 60),
			HeadColor2 = rgb(70, 70, 80),
			GlowColor = rgb(80, 120, 200),
			Glow = { Color = rgb(80, 120, 200), Brightness = 1.6 },
			Aura = { Kind = "Smoke", Color = rgb(80, 120, 200), Color2 = rgb(30, 25, 35) },
		},
	},
	{
		Id = "BatCave_CrystalMoth",
		Name = "Crystal Moth",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(70, 70, 80),
			ArmsColor = rgb(80, 120, 200),
			LegsColor = rgb(30, 25, 35),
			Accent = { Color = rgb(80, 120, 200), Pattern = { "Wraps", "Cape" } },
			Head = "MothHead",
			HeadColor = rgb(30, 25, 35),
			HeadColor2 = rgb(150, 140, 130),
			GlowColor = rgb(70, 70, 80),
			Glow = { Color = rgb(70, 70, 80), Brightness = 1.8 },
			Aura = { Kind = "Stars", Color = rgb(70, 70, 80), Color2 = rgb(80, 120, 200) },
		},
	},
	{
		Id = "BatCave_NightWingMonarch",
		Name = "Night Wing Monarch",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(30, 25, 35),
			ArmsColor = rgb(80, 110, 60),
			LegsColor = rgb(110, 60, 160),
			Accent = { Color = rgb(80, 110, 60), Pattern = { "Buttons", "Collar" } },
			Head = "BatHead",
			HeadColor = rgb(80, 120, 200),
			HeadColor2 = rgb(200, 30, 60),
			GlowColor = rgb(150, 140, 130),
			Glow = { Color = rgb(150, 140, 130), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(150, 140, 130), Color2 = rgb(70, 70, 80) },
		},
	},
} :: { any }
