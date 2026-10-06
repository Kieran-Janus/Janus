--!strict
--[[
	SCARECROW FARM CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (ScarecrowFarmCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "ScarecrowFarm_Farmhand",
		Name = "Farmhand",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 200, 110),
			ArmsColor = rgb(170, 140, 100),
			LegsColor = rgb(240, 130, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(250, 210, 60), Pattern = "Gloves" },
		},
	},
	{
		Id = "ScarecrowFarm_HayBale",
		Name = "Hay Bale",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(70, 100, 150),
			ArmsColor = rgb(170, 140, 100),
			LegsColor = rgb(30, 30, 35),
			Material = M.Grass,
			Accent = { Color = rgb(30, 30, 35), Pattern = "Wraps" },
		},
	},
	{
		Id = "ScarecrowFarm_CornPicker",
		Name = "Corn Picker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(180, 50, 40),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(70, 100, 150),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(240, 130, 40), Pattern = "Buttons" },
		},
	},
	{
		Id = "ScarecrowFarm_PumpkinPatcher",
		Name = "Pumpkin Patcher",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 140, 100),
			Accent = { Color = rgb(230, 200, 110), Pattern = "Patches" },
		},
	},
	{
		Id = "ScarecrowFarm_CrowShooer",
		Name = "Crow Shooer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(250, 210, 60),
			ArmsColor = rgb(230, 200, 110),
			LegsColor = rgb(170, 140, 100),
			Material = M.Fabric,
			Accent = { Color = rgb(70, 100, 150), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "ScarecrowFarm_BarnPainter",
		Name = "Barn Painter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(230, 200, 110),
			LegsColor = rgb(180, 50, 40),
			Material = M.Grass,
			Accent = { Color = rgb(180, 50, 40), Pattern = { "Heart", "Bones" } },
		},
	},
	{
		Id = "ScarecrowFarm_StrawHat",
		Name = "Straw Hat",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 130, 40),
			ArmsColor = rgb(180, 50, 40),
			LegsColor = rgb(30, 30, 35),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(170, 140, 100), Pattern = "Collar" },
		},
	},
	{
		Id = "ScarecrowFarm_OverallJoe",
		Name = "Overall Joe",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(230, 200, 110),
			Accent = { Color = rgb(250, 210, 60), Pattern = "Boots" },
		},
	},
	{
		Id = "ScarecrowFarm_TractorKid",
		Name = "Tractor Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(70, 100, 150),
			ArmsColor = rgb(250, 210, 60),
			LegsColor = rgb(230, 200, 110),
			Material = M.Fabric,
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Spots", "Stitches" } },
		},
	},
	{
		Id = "ScarecrowFarm_HarvestHelper",
		Name = "Harvest Helper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(180, 50, 40),
			ArmsColor = rgb(250, 210, 60),
			LegsColor = rgb(240, 130, 40),
			Material = M.Grass,
			Accent = { Color = rgb(240, 130, 40), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "ScarecrowFarm_FenceSitter",
		Name = "Fence Sitter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 140, 100),
			ArmsColor = rgb(240, 130, 40),
			LegsColor = rgb(180, 50, 40),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(230, 200, 110), Pattern = "Sash" },
		},
	},
	{
		Id = "ScarecrowFarm_SeedSower",
		Name = "Seed Sower",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(250, 210, 60),
			Accent = { Color = rgb(70, 100, 150), Pattern = { "Tail", "Patches" } },
		},
	},
	{
		Id = "ScarecrowFarm_RoosterWaker",
		Name = "Rooster Waker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(70, 100, 150),
			LegsColor = rgb(250, 210, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(180, 50, 40), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "ScarecrowFarm_PatchScarecrow",
		Name = "Patch Scarecrow",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 130, 40),
			ArmsColor = rgb(180, 50, 40),
			LegsColor = rgb(30, 30, 35),
			Accent = { Color = rgb(170, 140, 100), Pattern = { "Cuffs", "Wraps" } },
			Head = "ScarecrowHead",
			HeadColor = rgb(180, 50, 40),
			HeadColor2 = rgb(30, 30, 35),
			GlowColor = rgb(230, 200, 110),
		},
	},
	{
		Id = "ScarecrowFarm_PumpkinGrower",
		Name = "Pumpkin Grower",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 200, 110),
			ArmsColor = rgb(170, 140, 100),
			LegsColor = rgb(240, 130, 40),
			Accent = {
				Color = rgb(250, 210, 60),
				Material = M.Neon,
				Pattern = { "Stripes", "Sash" },
			},
			Head = "SkinPumpkin",
			Face = "Surprised",
			HeadColor = rgb(250, 210, 60),
			HeadColor2 = rgb(230, 200, 110),
			GlowColor = rgb(180, 50, 40),
		},
	},
	{
		Id = "ScarecrowFarm_MushroomFarmer",
		Name = "Mushroom Farmer",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(70, 100, 150),
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Belly", "Belt" } },
			Head = "ToadstoolHead",
			HeadColor = rgb(240, 130, 40),
			HeadColor2 = rgb(180, 50, 40),
			GlowColor = rgb(250, 210, 60),
		},
	},
	{
		Id = "ScarecrowFarm_FieldGhoul",
		Name = "Field Ghoul",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(180, 50, 40),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(70, 100, 150),
			Accent = { Color = rgb(240, 130, 40), Pattern = { "Stitches", "Spots" } },
			Head = "ScarecrowHead",
			HeadColor = rgb(70, 100, 150),
			HeadColor2 = rgb(250, 210, 60),
			GlowColor = rgb(240, 130, 40),
		},
	},
	{
		Id = "ScarecrowFarm_CornMazeGhost",
		Name = "Corn Maze Ghost",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(170, 140, 100),
			ArmsColor = rgb(240, 130, 40),
			LegsColor = rgb(180, 50, 40),
			Accent = { Color = rgb(230, 200, 110), Pattern = "Cape" },
			Head = "SkinPumpkin",
			Face = "Toothy",
			HeadColor = rgb(170, 140, 100),
			HeadColor2 = rgb(240, 130, 40),
			GlowColor = rgb(70, 100, 150),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "ScarecrowFarm_HarvestLord",
		Name = "Harvest Lord",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 130, 40),
			ArmsColor = rgb(170, 140, 100),
			LegsColor = rgb(230, 200, 110),
			Accent = { Color = rgb(170, 140, 100), Pattern = { "Gloves", "Wings" } },
			Head = "ScarecrowHead",
			HeadColor = rgb(30, 30, 35),
			HeadColor2 = rgb(230, 200, 110),
			GlowColor = rgb(250, 210, 60),
			Glow = { Color = rgb(250, 210, 60), Brightness = 1.6 },
			Aura = { Kind = "Embers", Color = rgb(250, 210, 60), Color2 = rgb(70, 100, 150) },
		},
	},
	{
		Id = "ScarecrowFarm_JackotheFields",
		Name = "Jack o' the Fields",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(230, 200, 110),
			ArmsColor = rgb(250, 210, 60),
			LegsColor = rgb(70, 100, 150),
			Accent = { Color = rgb(250, 210, 60), Pattern = { "Wraps", "Cuffs" } },
			Head = "SkinPumpkin",
			Face = "Wink",
			HeadColor = rgb(70, 100, 150),
			HeadColor2 = rgb(170, 140, 100),
			GlowColor = rgb(230, 200, 110),
			Glow = { Color = rgb(230, 200, 110), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(230, 200, 110), Color2 = rgb(250, 210, 60) },
		},
	},
	{
		Id = "ScarecrowFarm_CrowCommander",
		Name = "Crow Commander",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(70, 100, 150),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(180, 50, 40),
			Accent = { Color = rgb(30, 30, 35), Pattern = "Buttons" },
			Head = "ScarecrowHead",
			HeadColor = rgb(250, 210, 60),
			HeadColor2 = rgb(240, 130, 40),
			GlowColor = rgb(170, 140, 100),
			Glow = { Color = rgb(170, 140, 100), Brightness = 2.0 },
			Aura = { Kind = "Smoke", Color = rgb(170, 140, 100), Color2 = rgb(230, 200, 110) },
		},
	},
} :: { any }
