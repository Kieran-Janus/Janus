--!strict
--[[
	AUTUMN LEAVES CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (AutumnLeavesCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "AutumnLeaves_LeafRaker",
		Name = "Leaf Raker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 60, 30),
			ArmsColor = rgb(110, 75, 45),
			LegsColor = rgb(240, 225, 190),
			Material = M.Fabric,
			Accent = { Color = rgb(100, 120, 50), Pattern = "Gloves" },
		},
	},
	{
		Id = "AutumnLeaves_AcornCollector",
		Name = "Acorn Collector",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 130, 40),
			ArmsColor = rgb(110, 75, 45),
			LegsColor = rgb(110, 50, 80),
			Material = M.Wood,
			Accent = { Color = rgb(110, 50, 80), Pattern = "Wraps" },
		},
	},
	{
		Id = "AutumnLeaves_MapleKid",
		Name = "Maple Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 190, 60),
			ArmsColor = rgb(110, 50, 80),
			LegsColor = rgb(230, 130, 40),
			Material = M.LeafyGrass,
			Accent = { Color = rgb(240, 225, 190), Pattern = { "Buttons", "Sash" } },
		},
	},
	{
		Id = "AutumnLeaves_HayRider",
		Name = "Hay Rider",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(110, 75, 45),
			Accent = { Color = rgb(200, 60, 30), Pattern = "Patches" },
		},
	},
	{
		Id = "AutumnLeaves_ApplePicker",
		Name = "Apple Picker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 120, 50),
			ArmsColor = rgb(200, 60, 30),
			LegsColor = rgb(110, 75, 45),
			Material = M.Fabric,
			Accent = { Color = rgb(230, 130, 40), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "AutumnLeaves_CiderSipper",
		Name = "Cider Sipper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 50, 80),
			ArmsColor = rgb(200, 60, 30),
			LegsColor = rgb(240, 190, 60),
			Material = M.Wood,
			Accent = { Color = rgb(240, 190, 60), Pattern = { "Heart", "Cape" } },
		},
	},
	{
		Id = "AutumnLeaves_ScarfWrapper",
		Name = "Scarf Wrapper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 225, 190),
			ArmsColor = rgb(240, 190, 60),
			LegsColor = rgb(110, 50, 80),
			Material = M.LeafyGrass,
			Accent = { Color = rgb(110, 75, 45), Pattern = "Collar" },
		},
	},
	{
		Id = "AutumnLeaves_SquirrelWatcher",
		Name = "Squirrel Watcher",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(200, 60, 30),
			Accent = { Color = rgb(100, 120, 50), Pattern = "Boots" },
		},
	},
	{
		Id = "AutumnLeaves_PuddleJumper",
		Name = "Puddle Jumper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 130, 40),
			ArmsColor = rgb(100, 120, 50),
			LegsColor = rgb(200, 60, 30),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 50, 80), Pattern = { "Spots", "Wings" } },
		},
	},
	{
		Id = "AutumnLeaves_HarvestMoon",
		Name = "Harvest Moon",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 190, 60),
			ArmsColor = rgb(100, 120, 50),
			LegsColor = rgb(240, 225, 190),
			Material = M.Wood,
			Accent = { Color = rgb(240, 225, 190), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "AutumnLeaves_BonfireKid",
		Name = "Bonfire Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 75, 45),
			ArmsColor = rgb(240, 225, 190),
			LegsColor = rgb(240, 190, 60),
			Material = M.LeafyGrass,
			Accent = { Color = rgb(200, 60, 30), Pattern = "Sash" },
		},
	},
	{
		Id = "AutumnLeaves_SweaterWeather",
		Name = "Sweater Weather",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(100, 120, 50),
			Accent = { Color = rgb(230, 130, 40), Pattern = "Tail" },
		},
	},
	{
		Id = "AutumnLeaves_ChestnutRoaster",
		Name = "Chestnut Roaster",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(110, 50, 80),
			ArmsColor = rgb(230, 130, 40),
			LegsColor = rgb(100, 120, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 190, 60), Pattern = "Star" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "AutumnLeaves_AcornSprite",
		Name = "Acorn Sprite",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 225, 190),
			ArmsColor = rgb(240, 190, 60),
			LegsColor = rgb(110, 50, 80),
			Accent = { Color = rgb(110, 75, 45), Pattern = { "Cuffs", "Bones" } },
			Head = "AcornHead",
			HeadColor = rgb(240, 190, 60),
			HeadColor2 = rgb(110, 50, 80),
			GlowColor = rgb(200, 60, 30),
		},
	},
	{
		Id = "AutumnLeaves_PumpkinPatchPal",
		Name = "Pumpkin Patch Pal",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 60, 30),
			ArmsColor = rgb(110, 75, 45),
			LegsColor = rgb(240, 225, 190),
			Accent = {
				Color = rgb(100, 120, 50),
				Material = M.Neon,
				Pattern = { "Stripes", "Web" },
			},
			Head = "SkinPumpkin",
			Face = "Surprised",
			HeadColor = rgb(100, 120, 50),
			HeadColor2 = rgb(200, 60, 30),
			GlowColor = rgb(240, 190, 60),
		},
	},
	{
		Id = "AutumnLeaves_WiseOldOwl",
		Name = "Wise Old Owl",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(230, 130, 40),
			Accent = { Color = rgb(110, 50, 80), Pattern = { "Belly", "Boots" } },
			Head = "OwlHead",
			HeadColor = rgb(240, 225, 190),
			HeadColor2 = rgb(240, 190, 60),
			GlowColor = rgb(100, 120, 50),
		},
	},
	{
		Id = "AutumnLeaves_OakSpirit",
		Name = "Oak Spirit",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 190, 60),
			ArmsColor = rgb(110, 50, 80),
			LegsColor = rgb(230, 130, 40),
			Accent = { Color = rgb(240, 225, 190), Pattern = "Stitches" },
			Head = "AcornHead",
			HeadColor = rgb(230, 130, 40),
			HeadColor2 = rgb(100, 120, 50),
			GlowColor = rgb(240, 225, 190),
		},
	},
	{
		Id = "AutumnLeaves_LeafPileMonster",
		Name = "Leaf Pile Monster",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(110, 75, 45),
			ArmsColor = rgb(240, 225, 190),
			LegsColor = rgb(240, 190, 60),
			Accent = { Color = rgb(200, 60, 30), Pattern = { "Cape", "Heart" } },
			Head = "SkinPumpkin",
			Face = "Toothy",
			HeadColor = rgb(110, 75, 45),
			HeadColor2 = rgb(240, 225, 190),
			GlowColor = rgb(230, 130, 40),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "AutumnLeaves_AutumnKing",
		Name = "Autumn King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 225, 190),
			ArmsColor = rgb(110, 75, 45),
			LegsColor = rgb(200, 60, 30),
			Accent = { Color = rgb(110, 75, 45), Pattern = { "Gloves", "Star" } },
			Head = "AcornHead",
			HeadColor = rgb(110, 50, 80),
			HeadColor2 = rgb(200, 60, 30),
			GlowColor = rgb(100, 120, 50),
			Glow = { Color = rgb(100, 120, 50), Brightness = 1.6 },
			Aura = { Kind = "Embers", Color = rgb(100, 120, 50), Color2 = rgb(230, 130, 40) },
		},
	},
	{
		Id = "AutumnLeaves_HarvestSpirit",
		Name = "Harvest Spirit",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 60, 30),
			ArmsColor = rgb(100, 120, 50),
			LegsColor = rgb(230, 130, 40),
			Accent = { Color = rgb(100, 120, 50), Pattern = "Wraps" },
			Head = "SkinPumpkin",
			Face = "Wink",
			HeadColor = rgb(230, 130, 40),
			HeadColor2 = rgb(110, 75, 45),
			GlowColor = rgb(200, 60, 30),
			Glow = { Color = rgb(200, 60, 30), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(200, 60, 30), Color2 = rgb(100, 120, 50) },
		},
	},
	{
		Id = "AutumnLeaves_GoldenLeafOwl",
		Name = "Golden Leaf Owl",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(230, 130, 40),
			ArmsColor = rgb(110, 50, 80),
			LegsColor = rgb(240, 190, 60),
			Accent = { Color = rgb(110, 50, 80), Pattern = { "Buttons", "Sash" } },
			Head = "OwlHead",
			HeadColor = rgb(100, 120, 50),
			HeadColor2 = rgb(240, 225, 190),
			GlowColor = rgb(110, 75, 45),
			Glow = { Color = rgb(110, 75, 45), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(110, 75, 45), Color2 = rgb(200, 60, 30) },
		},
	},
} :: { any }
