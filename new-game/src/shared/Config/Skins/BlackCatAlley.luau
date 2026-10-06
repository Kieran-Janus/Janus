--!strict
--[[
	BLACK CAT ALLEY CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (BlackCatAlleyCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "BlackCatAlley_AlleyCat",
		Name = "Alley Cat",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 22, 30),
			ArmsColor = rgb(150, 255, 80),
			LegsColor = rgb(235, 235, 240),
			Material = M.Fabric,
			Accent = { Color = rgb(250, 230, 120), Pattern = "Heart" },
		},
	},
	{
		Id = "BlackCatAlley_MidnightMouser",
		Name = "Midnight Mouser",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 105, 110),
			ArmsColor = rgb(150, 255, 80),
			LegsColor = rgb(110, 60, 150),
			Material = M.Brick,
			Accent = { Color = rgb(110, 60, 150), Pattern = "Collar" },
		},
	},
	{
		Id = "BlackCatAlley_TrashCanTom",
		Name = "Trash Can Tom",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 70, 55),
			ArmsColor = rgb(110, 60, 150),
			LegsColor = rgb(110, 105, 110),
			Accent = { Color = rgb(235, 235, 240), Pattern = { "Boots", "Wings" } },
		},
	},
	{
		Id = "BlackCatAlley_WhiskerWanderer",
		Name = "Whisker Wanderer",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 255, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(25, 22, 30), Pattern = "Spots" },
		},
	},
	{
		Id = "BlackCatAlley_FenceProwler",
		Name = "Fence Prowler",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(250, 230, 120),
			ArmsColor = rgb(25, 22, 30),
			LegsColor = rgb(150, 255, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 105, 110), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "BlackCatAlley_LuckyBlackCat",
		Name = "Lucky Black Cat",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 60, 150),
			ArmsColor = rgb(25, 22, 30),
			LegsColor = rgb(150, 70, 55),
			Material = M.Brick,
			Accent = { Color = rgb(150, 70, 55), Pattern = { "Sash", "Tail" } },
		},
	},
	{
		Id = "BlackCatAlley_MoonGazer",
		Name = "Moon Gazer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 235, 240),
			ArmsColor = rgb(150, 70, 55),
			LegsColor = rgb(110, 60, 150),
			Accent = { Color = rgb(150, 255, 80), Pattern = "Tail" },
		},
	},
	{
		Id = "BlackCatAlley_ShadowTabby",
		Name = "Shadow Tabby",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(25, 22, 30),
			Material = M.Fabric,
			Accent = { Color = rgb(250, 230, 120), Pattern = "Star" },
		},
	},
	{
		Id = "BlackCatAlley_RooftopRunner",
		Name = "Rooftop Runner",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 105, 110),
			ArmsColor = rgb(250, 230, 120),
			LegsColor = rgb(25, 22, 30),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 60, 150), Pattern = { "Cuffs", "Web" } },
		},
	},
	{
		Id = "BlackCatAlley_PurringShadow",
		Name = "Purring Shadow",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 70, 55),
			ArmsColor = rgb(250, 230, 120),
			LegsColor = rgb(235, 235, 240),
			Material = M.Brick,
			Accent = { Color = rgb(235, 235, 240), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "BlackCatAlley_FishBoneFan",
		Name = "Fish Bone Fan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 255, 80),
			ArmsColor = rgb(235, 235, 240),
			LegsColor = rgb(150, 70, 55),
			Accent = { Color = rgb(25, 22, 30), Pattern = "Belly" },
		},
	},
	{
		Id = "BlackCatAlley_LampPostLounger",
		Name = "Lamp Post Lounger",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(250, 230, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 105, 110), Pattern = { "Stitches", "Heart" } },
		},
	},
	{
		Id = "BlackCatAlley_TuxedoKitty",
		Name = "Tuxedo Kitty",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 60, 150),
			ArmsColor = rgb(110, 105, 110),
			LegsColor = rgb(250, 230, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(150, 70, 55), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "BlackCatAlley_WitchsCat",
		Name = "Witch's Cat",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(235, 235, 240),
			ArmsColor = rgb(150, 70, 55),
			LegsColor = rgb(110, 60, 150),
			Accent = { Color = rgb(150, 255, 80), Pattern = { "Web", "Patches" } },
			Head = "CatHead",
			HeadColor = rgb(150, 70, 55),
			HeadColor2 = rgb(110, 60, 150),
			GlowColor = rgb(25, 22, 30),
		},
	},
	{
		Id = "BlackCatAlley_AlleyWitch",
		Name = "Alley Witch",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(25, 22, 30),
			ArmsColor = rgb(150, 255, 80),
			LegsColor = rgb(235, 235, 240),
			Accent = { Color = rgb(250, 230, 120), Material = M.Neon, Pattern = { "Belt", "Star" } },
			Head = "WitchHood",
			HeadColor = rgb(250, 230, 120),
			HeadColor2 = rgb(25, 22, 30),
			GlowColor = rgb(150, 70, 55),
		},
	},
	{
		Id = "BlackCatAlley_ShadowPanther",
		Name = "Shadow Panther",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(110, 105, 110),
			Accent = { Color = rgb(110, 60, 150), Pattern = { "Gloves", "Wraps" } },
			Head = "CatHead",
			HeadColor = rgb(235, 235, 240),
			HeadColor2 = rgb(150, 70, 55),
			GlowColor = rgb(250, 230, 120),
		},
	},
	{
		Id = "BlackCatAlley_NineLives",
		Name = "Nine Lives",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 70, 55),
			ArmsColor = rgb(110, 60, 150),
			LegsColor = rgb(110, 105, 110),
			Accent = { Color = rgb(235, 235, 240), Pattern = { "Wraps", "Sash" } },
			Head = "WitchHood",
			HeadColor = rgb(110, 105, 110),
			HeadColor2 = rgb(250, 230, 120),
			GlowColor = rgb(235, 235, 240),
		},
	},
	{
		Id = "BlackCatAlley_NeonEyes",
		Name = "Neon Eyes",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 255, 80),
			ArmsColor = rgb(235, 235, 240),
			LegsColor = rgb(150, 70, 55),
			Accent = { Color = rgb(25, 22, 30), Pattern = { "Buttons", "Belt" } },
			Head = "CatHead",
			HeadColor = rgb(150, 255, 80),
			HeadColor2 = rgb(235, 235, 240),
			GlowColor = rgb(110, 105, 110),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "BlackCatAlley_CatQueen",
		Name = "Cat Queen",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(235, 235, 240),
			ArmsColor = rgb(150, 255, 80),
			LegsColor = rgb(25, 22, 30),
			Accent = { Color = rgb(150, 255, 80), Pattern = { "Heart", "Collar" } },
			Head = "CatHead",
			HeadColor = rgb(110, 60, 150),
			HeadColor2 = rgb(25, 22, 30),
			GlowColor = rgb(250, 230, 120),
			Glow = { Color = rgb(250, 230, 120), Brightness = 1.6 },
			Aura = { Kind = "Stars", Color = rgb(250, 230, 120), Color2 = rgb(110, 105, 110) },
		},
	},
	{
		Id = "BlackCatAlley_MoonCat",
		Name = "Moon Cat",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(25, 22, 30),
			ArmsColor = rgb(250, 230, 120),
			LegsColor = rgb(110, 105, 110),
			Accent = { Color = rgb(250, 230, 120), Pattern = { "Collar", "Belly" } },
			Head = "CatHead",
			HeadColor = rgb(110, 105, 110),
			HeadColor2 = rgb(150, 255, 80),
			GlowColor = rgb(25, 22, 30),
			Glow = { Color = rgb(25, 22, 30), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(25, 22, 30), Color2 = rgb(250, 230, 120) },
		},
	},
	{
		Id = "BlackCatAlley_MidnightFamiliar",
		Name = "Midnight Familiar",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(110, 105, 110),
			ArmsColor = rgb(110, 60, 150),
			LegsColor = rgb(150, 70, 55),
			Accent = { Color = rgb(110, 60, 150), Pattern = { "Boots", "Wings" } },
			Head = "WitchHood",
			HeadColor = rgb(250, 230, 120),
			HeadColor2 = rgb(235, 235, 240),
			GlowColor = rgb(150, 255, 80),
			Glow = { Color = rgb(150, 255, 80), Brightness = 2.0 },
			Aura = { Kind = "Smoke", Color = rgb(150, 255, 80), Color2 = rgb(25, 22, 30) },
		},
	},
} :: { any }
