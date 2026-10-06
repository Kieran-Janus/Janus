--!strict
--[[
	CANDY FACTORY CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (CandyFactoryCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "CandyFactory_FactoryWorker",
		Name = "Factory Worker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 140, 200),
			ArmsColor = rgb(220, 30, 60),
			LegsColor = rgb(150, 80, 200),
			Accent = { Color = rgb(255, 235, 80), Pattern = "Sash" },
		},
	},
	{
		Id = "CandyFactory_GumdropPacker",
		Name = "Gumdrop Packer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 240, 200),
			ArmsColor = rgb(220, 30, 60),
			LegsColor = rgb(100, 60, 40),
			Material = M.Glass,
			Accent = { Color = rgb(100, 60, 40), Pattern = "Tail" },
		},
	},
	{
		Id = "CandyFactory_TaffyPuller",
		Name = "Taffy Puller",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 130, 60),
			ArmsColor = rgb(100, 60, 40),
			LegsColor = rgb(140, 240, 200),
			Material = M.Plastic,
			Accent = { Color = rgb(150, 80, 200), Pattern = { "Star", "Buttons" } },
		},
	},
	{
		Id = "CandyFactory_ChocolateDipper",
		Name = "Chocolate Dipper",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(220, 30, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 140, 200), Pattern = "Cuffs" },
		},
	},
	{
		Id = "CandyFactory_LollipopLicker",
		Name = "Lollipop Licker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 235, 80),
			ArmsColor = rgb(255, 140, 200),
			LegsColor = rgb(220, 30, 60),
			Accent = { Color = rgb(140, 240, 200), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "CandyFactory_SprinkleShaker",
		Name = "Sprinkle Shaker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 60, 40),
			ArmsColor = rgb(255, 140, 200),
			LegsColor = rgb(200, 130, 60),
			Material = M.Glass,
			Accent = { Color = rgb(200, 130, 60), Pattern = { "Belly", "Bones" } },
		},
	},
	{
		Id = "CandyFactory_CandyCaneKid",
		Name = "Candy Cane Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 80, 200),
			ArmsColor = rgb(200, 130, 60),
			LegsColor = rgb(100, 60, 40),
			Material = M.Plastic,
			Accent = { Color = rgb(220, 30, 60), Pattern = "Stitches" },
		},
	},
	{
		Id = "CandyFactory_JellyBean",
		Name = "Jelly Bean",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 140, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 235, 80), Pattern = "Cape" },
		},
	},
	{
		Id = "CandyFactory_CaramelTwister",
		Name = "Caramel Twister",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 240, 200),
			ArmsColor = rgb(255, 235, 80),
			LegsColor = rgb(255, 140, 200),
			Accent = { Color = rgb(100, 60, 40), Pattern = { "Web", "Stitches" } },
		},
	},
	{
		Id = "CandyFactory_MintTaster",
		Name = "Mint Taster",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 130, 60),
			ArmsColor = rgb(255, 235, 80),
			LegsColor = rgb(150, 80, 200),
			Material = M.Glass,
			Accent = { Color = rgb(150, 80, 200), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "CandyFactory_SugarRusher",
		Name = "Sugar Rusher",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(220, 30, 60),
			ArmsColor = rgb(150, 80, 200),
			LegsColor = rgb(200, 130, 60),
			Material = M.Plastic,
			Accent = { Color = rgb(255, 140, 200), Pattern = "Gloves" },
		},
	},
	{
		Id = "CandyFactory_WrapperFolder",
		Name = "Wrapper Folder",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 235, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(140, 240, 200), Pattern = { "Wraps", "Patches" } },
		},
	},
	{
		Id = "CandyFactory_ConveyorKid",
		Name = "Conveyor Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 60, 40),
			ArmsColor = rgb(140, 240, 200),
			LegsColor = rgb(255, 235, 80),
			Accent = { Color = rgb(200, 130, 60), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "CandyFactory_GumballBot",
		Name = "Gumball Bot",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 80, 200),
			ArmsColor = rgb(200, 130, 60),
			LegsColor = rgb(100, 60, 40),
			Accent = { Color = rgb(220, 30, 60), Pattern = { "Patches", "Wraps" } },
			Head = "GumballHead",
			HeadColor = rgb(200, 130, 60),
			HeadColor2 = rgb(100, 60, 40),
			GlowColor = rgb(255, 140, 200),
		},
	},
	{
		Id = "CandyFactory_CupcakeChef",
		Name = "Cupcake Chef",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 140, 200),
			ArmsColor = rgb(220, 30, 60),
			LegsColor = rgb(150, 80, 200),
			Accent = { Color = rgb(255, 235, 80), Material = M.Neon, Pattern = { "Wings", "Sash" } },
			Head = "CupcakeHead",
			HeadColor = rgb(255, 235, 80),
			HeadColor2 = rgb(255, 140, 200),
			GlowColor = rgb(200, 130, 60),
		},
	},
	{
		Id = "CandyFactory_GumdropGremlin",
		Name = "Gumdrop Gremlin",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(140, 240, 200),
			Accent = { Color = rgb(100, 60, 40), Pattern = { "Heart", "Belt" } },
			Head = "GumdropHead",
			HeadColor = rgb(150, 80, 200),
			HeadColor2 = rgb(200, 130, 60),
			GlowColor = rgb(255, 235, 80),
		},
	},
	{
		Id = "CandyFactory_CandyCornCaptain",
		Name = "Candy Corn Captain",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(200, 130, 60),
			ArmsColor = rgb(100, 60, 40),
			LegsColor = rgb(140, 240, 200),
			Accent = { Color = rgb(150, 80, 200), Pattern = { "Collar", "Spots" } },
			Head = "CandyCornHead",
			HeadColor = rgb(140, 240, 200),
			HeadColor2 = rgb(255, 235, 80),
			GlowColor = rgb(150, 80, 200),
		},
	},
	{
		Id = "CandyFactory_SourGumball",
		Name = "Sour Gumball",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(220, 30, 60),
			ArmsColor = rgb(150, 80, 200),
			LegsColor = rgb(200, 130, 60),
			Accent = { Color = rgb(255, 140, 200), Pattern = { "Boots", "Cape" } },
			Head = "GumballHead",
			HeadColor = rgb(220, 30, 60),
			HeadColor2 = rgb(150, 80, 200),
			GlowColor = rgb(140, 240, 200),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "CandyFactory_CandyTycoon",
		Name = "Candy Tycoon",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(150, 80, 200),
			ArmsColor = rgb(220, 30, 60),
			LegsColor = rgb(255, 140, 200),
			Accent = { Color = rgb(220, 30, 60), Pattern = { "Sash", "Wings" } },
			Head = "GumballHead",
			HeadColor = rgb(100, 60, 40),
			HeadColor2 = rgb(255, 140, 200),
			GlowColor = rgb(255, 235, 80),
			Glow = { Color = rgb(255, 235, 80), Brightness = 1.6 },
			Aura = { Kind = "Hearts", Color = rgb(255, 235, 80), Color2 = rgb(140, 240, 200) },
		},
	},
	{
		Id = "CandyFactory_FrostingFiend",
		Name = "Frosting Fiend",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(255, 140, 200),
			ArmsColor = rgb(255, 235, 80),
			LegsColor = rgb(140, 240, 200),
			Accent = { Color = rgb(255, 235, 80), Pattern = { "Tail", "Cuffs" } },
			Head = "CupcakeHead",
			HeadColor = rgb(140, 240, 200),
			HeadColor2 = rgb(220, 30, 60),
			GlowColor = rgb(255, 140, 200),
			Glow = { Color = rgb(255, 140, 200), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(255, 140, 200), Color2 = rgb(255, 235, 80) },
		},
	},
	{
		Id = "CandyFactory_SugarOverlord",
		Name = "Sugar Overlord",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(140, 240, 200),
			ArmsColor = rgb(100, 60, 40),
			LegsColor = rgb(200, 130, 60),
			Accent = { Color = rgb(100, 60, 40), Pattern = { "Star", "Buttons" } },
			Head = "GumballHead",
			HeadColor = rgb(255, 235, 80),
			HeadColor2 = rgb(150, 80, 200),
			GlowColor = rgb(220, 30, 60),
			Glow = { Color = rgb(220, 30, 60), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(220, 30, 60), Color2 = rgb(255, 140, 200) },
		},
	},
} :: { any }
