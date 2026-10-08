--!strict
--[[
	MONSTER DISCO CRATE SKINS (22): 13 Common, 5 Uncommon, 3 Rare, and 1 CRAZY that is ONE IN A MILLION (Odds = 0.0001: 0.0001% a crate).
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (MonsterDiscoCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "MonsterDisco_DanceFloorDan",
		Name = "Dance Floor Dan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 60, 180),
			ArmsColor = rgb(60, 230, 255),
			LegsColor = rgb(20, 20, 30),
			Material = M.Foil,
			Accent = { Color = rgb(255, 210, 60), Pattern = "Sash" },
		},
	},
	{
		Id = "MonsterDisco_GlitterGhoul",
		Name = "Glitter Ghoul",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(160, 60, 255),
			ArmsColor = rgb(60, 230, 255),
			LegsColor = rgb(210, 210, 220),
			Accent = { Color = rgb(210, 210, 220), Pattern = "Tail" },
		},
	},
	{
		Id = "MonsterDisco_BoogieBeast",
		Name = "Boogie Beast",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 255, 60),
			ArmsColor = rgb(210, 210, 220),
			LegsColor = rgb(160, 60, 255),
			Material = M.Glass,
			Accent = { Color = rgb(20, 20, 30), Pattern = { "Star", "Sash" } },
		},
	},
	{
		Id = "MonsterDisco_FunkyFang",
		Name = "Funky Fang",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 230, 255),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 60, 180), Pattern = "Cuffs" },
		},
	},
	{
		Id = "MonsterDisco_GroovyGhost",
		Name = "Groovy Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 210, 60),
			ArmsColor = rgb(255, 60, 180),
			LegsColor = rgb(60, 230, 255),
			Material = M.Foil,
			Accent = { Color = rgb(160, 60, 255), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "MonsterDisco_RollerMonster",
		Name = "Roller Monster",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 210, 220),
			ArmsColor = rgb(255, 60, 180),
			LegsColor = rgb(150, 255, 60),
			Accent = { Color = rgb(150, 255, 60), Pattern = { "Belly", "Cape" } },
		},
	},
	{
		Id = "MonsterDisco_NeonNibbler",
		Name = "Neon Nibbler",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(20, 20, 30),
			ArmsColor = rgb(150, 255, 60),
			LegsColor = rgb(210, 210, 220),
			Material = M.Glass,
			Accent = { Color = rgb(60, 230, 255), Pattern = "Stitches" },
		},
	},
	{
		Id = "MonsterDisco_BasslineBlob",
		Name = "Bassline Blob",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 60, 180),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 210, 60), Pattern = "Cape" },
		},
	},
	{
		Id = "MonsterDisco_SpinningSpook",
		Name = "Spinning Spook",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(160, 60, 255),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(255, 60, 180),
			Material = M.Foil,
			Accent = { Color = rgb(210, 210, 220), Pattern = { "Web", "Wings" } },
		},
	},
	{
		Id = "MonsterDisco_StrobeSlime",
		Name = "Strobe Slime",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 255, 60),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(20, 20, 30),
			Accent = { Color = rgb(20, 20, 30), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "MonsterDisco_FunkyFur",
		Name = "Funky Fur",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 230, 255),
			ArmsColor = rgb(20, 20, 30),
			LegsColor = rgb(150, 255, 60),
			Material = M.Glass,
			Accent = { Color = rgb(255, 60, 180), Pattern = "Gloves" },
		},
	},
	{
		Id = "MonsterDisco_MirrorShine",
		Name = "Mirror Shine",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 210, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(160, 60, 255), Pattern = { "Wraps", "Tail" } },
		},
	},
	{
		Id = "MonsterDisco_PlatformShoes",
		Name = "Platform Shoes",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(210, 210, 220),
			ArmsColor = rgb(160, 60, 255),
			LegsColor = rgb(255, 210, 60),
			Material = M.Foil,
			Accent = { Color = rgb(150, 255, 60), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "MonsterDisco_DiscoMonster",
		Name = "Disco Monster",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(20, 20, 30),
			ArmsColor = rgb(150, 255, 60),
			LegsColor = rgb(210, 210, 220),
			Accent = { Color = rgb(60, 230, 255), Pattern = { "Patches", "Bones" } },
			Head = "DiscoAfro",
			HeadColor = rgb(150, 255, 60),
			HeadColor2 = rgb(210, 210, 220),
			GlowColor = rgb(255, 60, 180),
		},
	},
	{
		Id = "MonsterDisco_GrooveBlob",
		Name = "Groove Blob",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 60, 180),
			ArmsColor = rgb(60, 230, 255),
			LegsColor = rgb(20, 20, 30),
			Accent = { Color = rgb(255, 210, 60), Material = M.Neon, Pattern = { "Wings", "Web" } },
			Head = "BlobHead",
			HeadColor = rgb(255, 210, 60),
			HeadColor2 = rgb(255, 60, 180),
			GlowColor = rgb(150, 255, 60),
		},
	},
	{
		Id = "MonsterDisco_StarryDancer",
		Name = "Starry Dancer",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(160, 60, 255),
			Accent = { Color = rgb(210, 210, 220), Pattern = { "Heart", "Boots" } },
			Head = "StarHead",
			HeadColor = rgb(20, 20, 30),
			HeadColor2 = rgb(150, 255, 60),
			GlowColor = rgb(255, 210, 60),
		},
	},
	{
		Id = "MonsterDisco_AfroGhoul",
		Name = "Afro Ghoul",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 255, 60),
			ArmsColor = rgb(210, 210, 220),
			LegsColor = rgb(160, 60, 255),
			Accent = { Color = rgb(20, 20, 30), Pattern = { "Collar", "Stitches" } },
			Head = "DiscoAfro",
			HeadColor = rgb(160, 60, 255),
			HeadColor2 = rgb(255, 210, 60),
			GlowColor = rgb(20, 20, 30),
		},
	},
	{
		Id = "MonsterDisco_FunkMaster",
		Name = "Funk Master",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 230, 255),
			ArmsColor = rgb(20, 20, 30),
			LegsColor = rgb(150, 255, 60),
			Accent = { Color = rgb(255, 60, 180), Pattern = { "Boots", "Heart" } },
			Head = "BlobHead",
			HeadColor = rgb(60, 230, 255),
			HeadColor2 = rgb(20, 20, 30),
			GlowColor = rgb(160, 60, 255),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "MonsterDisco_DanceKing",
		Name = "Dance King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(20, 20, 30),
			ArmsColor = rgb(60, 230, 255),
			LegsColor = rgb(255, 60, 180),
			Accent = { Color = rgb(60, 230, 255), Pattern = { "Sash", "Star" } },
			Head = "DiscoAfro",
			HeadColor = rgb(210, 210, 220),
			HeadColor2 = rgb(255, 60, 180),
			GlowColor = rgb(255, 210, 60),
			Glow = { Color = rgb(255, 210, 60), Brightness = 1.6 },
			Aura = { Kind = "Stars", Color = rgb(255, 210, 60), Color2 = rgb(160, 60, 255) },
		},
	},
	{
		Id = "MonsterDisco_GlitterQueen",
		Name = "Glitter Queen",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(255, 60, 180),
			ArmsColor = rgb(255, 210, 60),
			LegsColor = rgb(160, 60, 255),
			Accent = { Color = rgb(255, 210, 60), Pattern = { "Tail", "Wraps" } },
			Head = "StarHead",
			HeadColor = rgb(160, 60, 255),
			HeadColor2 = rgb(60, 230, 255),
			GlowColor = rgb(255, 60, 180),
			Glow = { Color = rgb(255, 60, 180), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(255, 60, 180), Color2 = rgb(255, 210, 60) },
		},
	},
	{
		Id = "MonsterDisco_StrobePhantom",
		Name = "Strobe Phantom",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(160, 60, 255),
			ArmsColor = rgb(210, 210, 220),
			LegsColor = rgb(150, 255, 60),
			Accent = { Color = rgb(210, 210, 220), Pattern = { "Star", "Sash" } },
			Head = "BlobHead",
			HeadColor = rgb(255, 210, 60),
			HeadColor2 = rgb(20, 20, 30),
			GlowColor = rgb(60, 230, 255),
			Glow = { Color = rgb(60, 230, 255), Brightness = 2.0 },
			Aura = { Kind = "Hearts", Color = rgb(60, 230, 255), Color2 = rgb(255, 60, 180) },
		},
	},

	-- ONE IN A MILLION (CRAZY, 0.0001% a crate: the flashiest skin in the game) ----------
	{
		Id = "MonsterDisco_DiscoDemon",
		Name = "Disco Demon",
		Rarity = "Crazy",
		OneInAMillion = true, -- only in this crate, never in the CRAZY Crate
		Odds = 0.0001, -- percent: 1 in 1,000,000 opens
		Style = {
			BodyColor = rgb(30, 20, 40),
			Material = M.Foil,
			Accent = {
				Color = rgb(255, 60, 200),
				Material = M.Neon,
				Pattern = { "Cape", "Gloves", "Boots", "Belt" },
			},
			Head = "DiscoDemon",
			HeadColor = rgb(220, 220, 235),
			HeadColor2 = rgb(200, 30, 60),
			GlowColor = rgb(255, 255, 120),
			Glow = { Color = rgb(255, 255, 120), Brightness = 3, Range = 16 },
			Aura = { Kind = "Stars", Color = rgb(255, 120, 255), Color2 = rgb(120, 255, 255) },
			Crazy = {
				Rainbow = true,
				Pulse = true,
				Orbit = "Stars",
				Count = 5,
				Effect = "DiscoInferno",
			},
			Animate = {
				{ Effect = "Wobble", Target = "Cape", Speed = 2, Amount = 1.5 },
				{ Effect = "Bob", Target = "Head", Speed = 2 },
				{ Effect = "Spin", Target = "Part:MirrorTile" },
				{
					Effect = "ColorCycle",
					Target = "Glow",
					Speed = 2,
					Colors = { rgb(255, 120, 255), rgb(120, 255, 255), rgb(255, 255, 120) },
				},
				{ Effect = "SparkleBurst", Every = 2, Count = 15 },
			} :: { any }, -- (effects differ in shape)
			Motion = "Proud",
		},
	},
} :: { any }
