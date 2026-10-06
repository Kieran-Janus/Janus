--!strict
--[[
	SWAMP CREATURES CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (SwampCreaturesCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "SwampCreatures_BogWalker",
		Name = "Bog Walker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(70, 110, 60),
			ArmsColor = rgb(60, 140, 120),
			LegsColor = rgb(160, 170, 160),
			Material = M.Mud,
			Accent = { Color = rgb(100, 70, 45), Pattern = "Belly" },
		},
	},
	{
		Id = "SwampCreatures_MudPuddle",
		Name = "Mud Puddle",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 80, 50),
			ArmsColor = rgb(60, 140, 120),
			LegsColor = rgb(140, 220, 60),
			Material = M.Grass,
			Accent = { Color = rgb(140, 220, 60), Pattern = "Stitches" },
		},
	},
	{
		Id = "SwampCreatures_LilyHopper",
		Name = "Lily Hopper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 150, 190),
			ArmsColor = rgb(140, 220, 60),
			LegsColor = rgb(90, 80, 50),
			Accent = { Color = rgb(160, 170, 160), Pattern = { "Cape", "Star" } },
		},
	},
	{
		Id = "SwampCreatures_ReedRustler",
		Name = "Reed Rustler",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 140, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(70, 110, 60), Pattern = "Web" },
		},
	},
	{
		Id = "SwampCreatures_CroakKid",
		Name = "Croak Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 70, 45),
			ArmsColor = rgb(70, 110, 60),
			LegsColor = rgb(60, 140, 120),
			Material = M.Mud,
			Accent = { Color = rgb(90, 80, 50), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "SwampCreatures_MurkyWader",
		Name = "Murky Wader",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 220, 60),
			ArmsColor = rgb(70, 110, 60),
			LegsColor = rgb(240, 150, 190),
			Material = M.Grass,
			Accent = { Color = rgb(240, 150, 190), Pattern = { "Gloves", "Belt" } },
		},
	},
	{
		Id = "SwampCreatures_AlgaeBloom",
		Name = "Algae Bloom",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(160, 170, 160),
			ArmsColor = rgb(240, 150, 190),
			LegsColor = rgb(140, 220, 60),
			Accent = { Color = rgb(60, 140, 120), Pattern = "Wraps" },
		},
	},
	{
		Id = "SwampCreatures_FireflyCatcher",
		Name = "Firefly Catcher",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(70, 110, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(100, 70, 45), Pattern = "Buttons" },
		},
	},
	{
		Id = "SwampCreatures_SwampGas",
		Name = "Swamp Gas",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 80, 50),
			ArmsColor = rgb(100, 70, 45),
			LegsColor = rgb(70, 110, 60),
			Material = M.Mud,
			Accent = { Color = rgb(140, 220, 60), Pattern = { "Patches", "Collar" } },
		},
	},
	{
		Id = "SwampCreatures_Cattail",
		Name = "Cattail",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 150, 190),
			ArmsColor = rgb(100, 70, 45),
			LegsColor = rgb(160, 170, 160),
			Material = M.Grass,
			Accent = { Color = rgb(160, 170, 160), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "SwampCreatures_MossBack",
		Name = "Moss Back",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 140, 120),
			ArmsColor = rgb(160, 170, 160),
			LegsColor = rgb(240, 150, 190),
			Accent = { Color = rgb(70, 110, 60), Pattern = "Heart" },
		},
	},
	{
		Id = "SwampCreatures_Tadpole",
		Name = "Tadpole",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(100, 70, 45),
			Material = M.Fabric,
			Accent = { Color = rgb(90, 80, 50), Pattern = { "Collar", "Cuffs" } },
		},
	},
	{
		Id = "SwampCreatures_BayouDrifter",
		Name = "Bayou Drifter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 220, 60),
			ArmsColor = rgb(90, 80, 50),
			LegsColor = rgb(100, 70, 45),
			Material = M.Mud,
			Accent = { Color = rgb(240, 150, 190), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "SwampCreatures_SwampFrog",
		Name = "Swamp Frog",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(160, 170, 160),
			ArmsColor = rgb(240, 150, 190),
			LegsColor = rgb(140, 220, 60),
			Accent = { Color = rgb(60, 140, 120), Pattern = { "Spots", "Tail" } },
			Head = "FrogHead",
			HeadColor = rgb(240, 150, 190),
			HeadColor2 = rgb(140, 220, 60),
			GlowColor = rgb(70, 110, 60),
		},
	},
	{
		Id = "SwampCreatures_BogBlob",
		Name = "Bog Blob",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(70, 110, 60),
			ArmsColor = rgb(60, 140, 120),
			LegsColor = rgb(160, 170, 160),
			Accent = {
				Color = rgb(100, 70, 45),
				Material = M.Neon,
				Pattern = { "Bones", "Gloves" },
			},
			Head = "BlobHead",
			HeadColor = rgb(100, 70, 45),
			HeadColor2 = rgb(70, 110, 60),
			GlowColor = rgb(240, 150, 190),
		},
	},
	{
		Id = "SwampCreatures_LilyPadPrince",
		Name = "Lily Pad Prince",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(90, 80, 50),
			Accent = { Color = rgb(140, 220, 60), Pattern = { "Sash", "Bones" } },
			Head = "FrogHead",
			HeadColor = rgb(160, 170, 160),
			HeadColor2 = rgb(240, 150, 190),
			GlowColor = rgb(100, 70, 45),
		},
	},
	{
		Id = "SwampCreatures_MudMonster",
		Name = "Mud Monster",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 150, 190),
			ArmsColor = rgb(140, 220, 60),
			LegsColor = rgb(90, 80, 50),
			Accent = { Color = rgb(160, 170, 160), Pattern = { "Tail", "Web" } },
			Head = "BlobHead",
			HeadColor = rgb(90, 80, 50),
			HeadColor2 = rgb(100, 70, 45),
			GlowColor = rgb(160, 170, 160),
		},
	},
	{
		Id = "SwampCreatures_ToadWizard",
		Name = "Toad Wizard",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(60, 140, 120),
			ArmsColor = rgb(160, 170, 160),
			LegsColor = rgb(240, 150, 190),
			Accent = { Color = rgb(70, 110, 60), Pattern = { "Star", "Boots" } },
			Head = "FrogHead",
			HeadColor = rgb(60, 140, 120),
			HeadColor2 = rgb(160, 170, 160),
			GlowColor = rgb(90, 80, 50),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "SwampCreatures_FrogKing",
		Name = "Frog King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(160, 170, 160),
			ArmsColor = rgb(60, 140, 120),
			LegsColor = rgb(70, 110, 60),
			Accent = { Color = rgb(60, 140, 120), Pattern = { "Belly", "Stripes" } },
			Head = "FrogHead",
			HeadColor = rgb(140, 220, 60),
			HeadColor2 = rgb(70, 110, 60),
			GlowColor = rgb(100, 70, 45),
			Glow = { Color = rgb(100, 70, 45), Brightness = 1.6 },
			Aura = { Kind = "Bubbles", Color = rgb(100, 70, 45), Color2 = rgb(90, 80, 50) },
		},
	},
	{
		Id = "SwampCreatures_SwampThing",
		Name = "Swamp Thing",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(70, 110, 60),
			ArmsColor = rgb(100, 70, 45),
			LegsColor = rgb(90, 80, 50),
			Accent = { Color = rgb(100, 70, 45), Pattern = { "Stitches", "Patches" } },
			Head = "BlobHead",
			HeadColor = rgb(90, 80, 50),
			HeadColor2 = rgb(60, 140, 120),
			GlowColor = rgb(70, 110, 60),
			Glow = { Color = rgb(70, 110, 60), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(70, 110, 60), Color2 = rgb(100, 70, 45) },
		},
	},
	{
		Id = "SwampCreatures_BogTitan",
		Name = "Bog Titan",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(90, 80, 50),
			ArmsColor = rgb(140, 220, 60),
			LegsColor = rgb(240, 150, 190),
			Accent = { Color = rgb(140, 220, 60), Pattern = { "Cape", "Star" } },
			Head = "FrogHead",
			HeadColor = rgb(100, 70, 45),
			HeadColor2 = rgb(160, 170, 160),
			GlowColor = rgb(60, 140, 120),
			Glow = { Color = rgb(60, 140, 120), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(60, 140, 120), Color2 = rgb(70, 110, 60) },
		},
	},
} :: { any }
