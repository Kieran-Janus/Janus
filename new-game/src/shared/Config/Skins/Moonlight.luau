--!strict
--[[
	MOONLIGHT CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Every Style option is explained at the top of Pumpkin.luau. Change Names and looks freely;
	NEVER change an Id (it is saved in players' data).
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Moonlight_Stargazer",
		Name = "Stargazer",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 50, 110),
			Accent = { Color = rgb(255, 230, 120), Pattern = "Star" },
		},
	},
	{
		Id = "Moonlight_StarryNight",
		Name = "Starry Night",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(25, 30, 70),
			Accent = { Color = rgb(230, 235, 255), Material = M.Neon, Pattern = "Spots" },
		},
	},
	{
		Id = "Moonlight_MoonbeamPJs",
		Name = "Moonbeam PJs",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(170, 180, 240),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 250, 200), Pattern = "Buttons" },
		},
	},
	{
		Id = "Moonlight_Twilight",
		Name = "Twilight",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 80, 170),
			ArmsColor = rgb(80, 70, 160),
			LegsColor = rgb(40, 40, 100),
			Accent = { Color = rgb(255, 220, 120), Pattern = "Belt" },
		},
	},
	{
		Id = "Moonlight_SilverMoon",
		Name = "Silver Moon",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(200, 205, 220),
			Material = M.Foil,
			Accent = { Color = rgb(120, 140, 220), Pattern = "Collar" },
		},
	},
	{
		Id = "Moonlight_MoonDust",
		Name = "Moon Dust",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(220, 215, 200),
			Material = M.Slate,
			Accent = { Color = rgb(175, 170, 160), Pattern = "Spots" },
		},
	},
	{
		Id = "Moonlight_Firefly",
		Name = "Firefly",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 45, 40),
			Accent = { Color = rgb(220, 255, 120), Material = M.Neon, Pattern = "Belly" },
		},
	},
	{
		Id = "Moonlight_MidnightBlue",
		Name = "Midnight Blue",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(20, 30, 80),
			Accent = { Color = rgb(100, 140, 255), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "Moonlight_NorthernLights",
		Name = "Northern Lights",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 230, 180),
			ArmsColor = rgb(100, 160, 255),
			LegsColor = rgb(170, 110, 255),
			Material = M.Glass,
			Accent = { Color = rgb(235, 250, 255), Pattern = "Cuffs" },
		},
	},
	{
		Id = "Moonlight_Sleepwalker",
		Name = "Sleepwalker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(235, 235, 250),
			Material = M.Fabric,
			Accent = { Color = rgb(180, 190, 255), Pattern = { "Cuffs", "Collar" } },
		},
	},
	{
		Id = "Moonlight_CometTail",
		Name = "Comet Tail",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(30, 35, 60),
			Accent = { Color = rgb(255, 220, 150), Material = M.Neon, Pattern = "Sash" },
		},
	},
	{
		Id = "Moonlight_FrostyNight",
		Name = "Frosty Night",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(180, 220, 255),
			Material = M.Ice,
			Accent = { Color = rgb(240, 250, 255), Material = M.Glass, Pattern = "Gloves" },
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Moonlight_SleepyMoon",
		Name = "Sleepy Moon",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(60, 70, 150),
			Material = M.Fabric,
			Accent = { Color = rgb(250, 238, 180), Pattern = "Buttons" },
			Head = "MoonHead",
			HeadColor = rgb(255, 228, 120),
			HeadColor2 = rgb(60, 70, 150),
		},
	},
	{
		Id = "Moonlight_NightOwl",
		Name = "Night Owl",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(140, 100, 70),
			Material = M.Fabric,
			Accent = {
				Color = rgb(240, 225, 195),
				Material = M.Fabric,
				Pattern = { "Wings", "Belly" },
			},
			Head = "OwlHead",
			HeadColor = rgb(140, 100, 70),
			HeadColor2 = rgb(240, 225, 195),
			GlowColor = rgb(255, 200, 50),
		},
	},
	{
		Id = "Moonlight_SilverHowler",
		Name = "Silver Howler",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(170, 175, 195),
			Material = M.Fabric,
			Accent = { Color = rgb(230, 232, 240), Material = M.Fabric, Pattern = "Tail" },
			Head = "WolfHead",
			HeadColor = rgb(170, 175, 195),
			HeadColor2 = rgb(230, 232, 240),
			GlowColor = rgb(150, 220, 255),
		},
	},
	{
		Id = "Moonlight_Glowshroom",
		Name = "Glowshroom",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(230, 240, 255),
			Accent = { Color = rgb(60, 120, 255), Pattern = "Spots" },
			Head = "ToadstoolHead",
			HeadColor = rgb(60, 120, 255),
			HeadColor2 = rgb(230, 240, 255),
			GlowColor = rgb(150, 255, 255),
		},
	},
	{
		Id = "Moonlight_Twinkle",
		Name = "Twinkle",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(40, 45, 110),
			Accent = { Color = rgb(255, 220, 70), Pattern = "Star" },
			Head = "StarHead",
			HeadColor = rgb(255, 220, 70),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Moonlight_MoonMoth",
		Name = "Moon Moth",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(200, 190, 240),
			Material = M.Fabric,
			Accent = { Color = rgb(170, 150, 230), Pattern = "Wings" },
			Head = "MothHead",
			HeadColor = rgb(235, 225, 250),
			HeadColor2 = rgb(170, 150, 230),
			GlowColor = rgb(40, 30, 70),
			Glow = { Color = rgb(200, 180, 255), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(230, 220, 255), Color2 = rgb(160, 140, 255) },
			Animate = {
				{ Effect = "Flap", Target = "Wings", Speed = 0.5, Amount = 1.2 },
				{ Effect = "Pulse", Target = "Glow", Speed = 0.6 },
			} :: { any }, -- (effects differ in shape)
		},
	},
	{
		Id = "Moonlight_StarWizard",
		Name = "Star Wizard",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(40, 50, 130),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 220, 90), Material = M.Neon, Pattern = { "Star", "Cuffs" } },
			Head = "WitchHood",
			HeadColor = rgb(255, 205, 160),
			HeadColor2 = rgb(40, 50, 130),
			GlowColor = rgb(255, 220, 90),
			Glow = { Color = rgb(150, 170, 255) },
			Aura = { Kind = "Stars", Color = rgb(255, 240, 150), Color2 = rgb(150, 170, 255) },
		},
	},

	-- CRAZY (0.1% in the Moonlight Crate) --------------------------------------------------
	{
		Id = "Moonlight_LunarLegend",
		Name = "Lunar Legend",
		Rarity = "Crazy",
		Style = {
			BodyColor = rgb(30, 35, 90),
			Material = M.Foil,
			Accent = { Material = M.Neon, Pattern = { "Cape", "Star", "Cuffs" } },
			Head = "MoonCrown",
			HeadColor = rgb(250, 240, 190),
			GlowColor = rgb(255, 240, 150),
			Glow = { Color = rgb(220, 220, 255), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Stars", Color = rgb(255, 245, 200) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Stars", Count = 5 },
			Animate = {
				{ Effect = "Float", Target = "Head", Speed = 0.7, Amount = 0.6 },
				{ Effect = "Spin", Target = "Part:Crescent", Speed = 0.35 },
				{ Effect = "Breathe", Target = "Cape", Amount = 1.5 },
				{
					Effect = "ColorCycle",
					Target = "Glow",
					Colors = { rgb(220, 220, 255), rgb(255, 245, 200) },
				},
			} :: { any }, -- (effects differ in shape)
			Motion = "Ghost",
		},
	},
} :: { any }
