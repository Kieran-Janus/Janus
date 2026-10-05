--!strict
--[[
	CANDY CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Every Style option is explained at the top of Pumpkin.luau. Change Names and looks freely;
	NEVER change an Id (it is saved in players' data).
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Candy_CandyCane",
		Name = "Candy Cane",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(250, 250, 250),
			Accent = { Color = rgb(230, 40, 60), Pattern = "Stripes" },
		},
	},
	{
		Id = "Candy_BubbleGum",
		Name = "Bubble Gum",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 150, 200),
			Accent = { Color = rgb(255, 210, 235), Pattern = "Belly" },
		},
	},
	{
		Id = "Candy_LicoriceTwist",
		Name = "Licorice Twist",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 30, 45),
			Accent = { Color = rgb(230, 40, 60), Pattern = "Wraps" },
		},
	},
	{
		Id = "Candy_MintChip",
		Name = "Mint Chip",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 240, 200),
			Accent = { Color = rgb(80, 55, 45), Pattern = "Spots" },
		},
	},
	{
		Id = "Candy_CottonCandy",
		Name = "Cotton Candy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 180, 220),
			ArmsColor = rgb(170, 210, 255),
			LegsColor = rgb(170, 210, 255),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 255, 255), Pattern = "Heart" },
		},
	},
	{
		Id = "Candy_ChocolateBar",
		Name = "Chocolate Bar",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(110, 65, 40),
			Accent = { Color = rgb(255, 215, 80), Material = M.Foil, Pattern = "Sash" },
		},
	},
	{
		Id = "Candy_GummyBear",
		Name = "Gummy Bear",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 90, 90),
			Material = M.Glass,
			Accent = { Color = rgb(255, 150, 150), Material = M.Glass, Pattern = "Belly" },
		},
	},
	{
		Id = "Candy_SaltwaterTaffy",
		Name = "Saltwater Taffy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 220, 120),
			ArmsColor = rgb(140, 220, 230),
			LegsColor = rgb(140, 220, 230),
			Accent = { Color = rgb(255, 255, 255), Pattern = "Stripes" },
		},
	},
	{
		Id = "Candy_CaramelSwirl",
		Name = "Caramel Swirl",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(210, 140, 60),
			Material = M.Foil,
			Accent = { Color = rgb(255, 230, 180), Pattern = "Wraps" },
		},
	},
	{
		Id = "Candy_SprinkleParty",
		Name = "Sprinkle Party",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 190, 220),
			Accent = { Color = rgb(90, 200, 255), Material = M.Neon, Pattern = "Spots" },
		},
	},
	{
		Id = "Candy_LemonDrop",
		Name = "Lemon Drop",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(255, 235, 90),
			Material = M.Sand,
			Accent = { Color = rgb(255, 255, 255), Pattern = "Cuffs" },
		},
	},
	{
		Id = "Candy_SourApple",
		Name = "Sour Apple",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 230, 60),
			Material = M.Glass,
			Accent = { Color = rgb(255, 60, 80), Pattern = "Stripes" },
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Candy_WrappedUp",
		Name = "Wrapped Up",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(255, 90, 150),
			Accent = { Color = rgb(255, 255, 255), Pattern = "Stripes" },
			Head = "CandyWrapper",
			HeadColor = rgb(255, 90, 150),
			HeadColor2 = rgb(255, 255, 255),
		},
	},
	{
		Id = "Candy_CupcakeCutie",
		Name = "Cupcake Cutie",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(90, 200, 220),
			ArmsColor = rgb(255, 190, 220),
			LegsColor = rgb(255, 190, 220),
			Accent = { Color = rgb(235, 40, 70), Pattern = "Buttons" },
			Head = "CupcakeHead",
			HeadColor = rgb(255, 190, 220),
			HeadColor2 = rgb(90, 200, 220),
			GlowColor = rgb(235, 40, 70),
		},
	},
	{
		Id = "Candy_GumdropGus",
		Name = "Gumdrop Gus",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(140, 230, 110),
			Material = M.Sand,
			Accent = { Color = rgb(255, 255, 255), Pattern = "Spots" },
			Head = "GumdropHead",
			HeadColor = rgb(140, 230, 110),
		},
	},
	{
		Id = "Candy_SugarSkull",
		Name = "Sugar Skull",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(40, 30, 55),
			Accent = { Color = rgb(255, 180, 220), Pattern = "Bones" },
			Head = "CandySkull",
			HeadColor = rgb(250, 246, 240),
			HeadColor2 = rgb(255, 110, 190),
			GlowColor = rgb(90, 220, 255),
		},
	},
	{
		Id = "Candy_CandyCornKid",
		Name = "Candy Corn Kid",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 130, 20),
			ArmsColor = rgb(255, 250, 240),
			LegsColor = rgb(255, 205, 40),
			Accent = { Color = rgb(255, 250, 240), Pattern = "Collar" },
			Head = "CandyCornHead",
			HeadColor = rgb(255, 205, 40),
			HeadColor2 = rgb(255, 130, 20),
			GlowColor = rgb(255, 250, 240),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Candy_BubblegumBat",
		Name = "Bubblegum Bat",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(255, 140, 200),
			Accent = { Color = rgb(200, 80, 160), Pattern = "Wings" },
			Head = "BatHead",
			HeadColor = rgb(255, 140, 200),
			HeadColor2 = rgb(255, 225, 240),
			Glow = { Color = rgb(255, 120, 200) },
			Aura = { Kind = "Bubbles", Color = rgb(255, 180, 230), Color2 = rgb(255, 255, 255) },
		},
	},
	{
		Id = "Candy_CottonCandyCat",
		Name = "Cotton Candy Cat",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(180, 210, 255),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 170, 210), Pattern = { "Tail", "Gloves" } },
			Head = "CatHead",
			HeadColor = rgb(180, 210, 255),
			HeadColor2 = rgb(255, 170, 210),
			GlowColor = rgb(255, 120, 200),
			Glow = { Color = rgb(200, 170, 255) },
			Aura = { Kind = "Hearts", Color = rgb(255, 140, 200), Color2 = rgb(200, 170, 255) },
		},
	},

	-- CRAZY (0.1% in the Candy Crate) ------------------------------------------------------
	{
		Id = "Candy_SugarRushSupreme",
		Name = "Sugar Rush Supreme",
		Rarity = "Crazy",
		Style = {
			BodyColor = rgb(255, 250, 252),
			Accent = { Material = M.Neon, Pattern = { "Stripes", "Collar" } },
			Head = "SugarStorm",
			HeadColor = rgb(255, 255, 255),
			HeadColor2 = rgb(255, 120, 200),
			Glow = { Color = rgb(255, 120, 220), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Hearts", Color = rgb(255, 140, 200) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Candies", Count = 4 },
		},
	},
} :: { any }
