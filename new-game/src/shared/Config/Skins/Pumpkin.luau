--!strict
--[[
	PUMPKIN CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (PumpkinCrate) and Style.Kind are filled in by init.luau.

	STYLE OPTIONS (every theme file uses the same ones; leave out what you don't need)
	  Colours, written rgb(red, green, blue) with each number 0-255:
	    BodyColor     the whole body
	    HeadColor, TorsoColor, ArmsColor, LegsColor
	                  one body part (wins over BodyColor). With a head piece, HeadColor
	                  colours the head piece instead.
	  Materials, written M.Name (M.Neon, M.Foil, M.Glass, M.ForceField, M.Marble,
	  M.Cobblestone, M.Fabric, M.Slate, M.Ice, M.Snow, M.CrackedLava, M.Metal, ...):
	    Material      the whole body;  HeadMaterial, TorsoMaterial, ArmsMaterial, LegsMaterial
	  Transparency    0 = solid, 1 = invisible
	  HideClothes     crate skins hide the avatar's shirt and pants; false keeps them
	  Accent = { Color = rgb(...), Material = M.Neon, Pattern = "Stripes" }
	                  a second colour on the body. Patterns: Belt, Collar, Cuffs, Gloves,
	                  Boots, Stripes, Wraps, Spots, Belly, Buttons, Bones, Stitches, Patches,
	                  Sash, Cape, Wings, Tail, Web, Heart, Star. Several at once:
	                  Pattern = { "Belt", "Boots" }
	  Uncommon and up, a head piece (src/shared/HeadPieces.luau):
	    Head          SkinPumpkin, GentlemanGourd, ScarecrowHead, CandleHead, CandyWrapper,
	                  CupcakeHead, GumdropHead, CandyCornHead, CandySkull, GhostSheet, BatHead,
	                  CatHead, WitchHood, CauldronHat, SpiderCrown, PotionHead, SkinSkull,
	                  MummyHead, ZombieHead, TombstoneHead, VampireHead, LanternHead,
	                  FrankenHead, EyeballHead, WolfHead, FuzzyHead, BlobHead, MoonHead,
	                  OwlHead, ToadstoolHead, StarHead, MothHead
	    HeadColor2    the head piece's second colour (hat, wrapper, inner ears...)
	    HeadColor3    a third colour (only GentlemanGourd's hat band)
	    GlowColor     the head piece's glowing bits (carved face, eyes, flame, potion)
	    Face          pumpkin heads: "Happy", "Spooky", "Surprised", "Sleepy", "Wink", "Toothy"
	  Rare and up:
	    Glow = { Color = rgb(...), Brightness = 2, Range = 12 }   a light around you
	    Aura = { Kind = "Embers", Color = rgb(...), Color2 = rgb(...) }   particles around
	                  you, fading from Color to Color2. Kinds (Config/Skins/Settings.luau):
	                  Sparkles, Embers, Bubbles, Hearts, Snow, Smoke, Stars
	  CRAZY only (the one-of-a-kind skin in each crate):
	    Crazy = { Rainbow = true, Pulse = true, Orbit = "Pumpkins", Count = 3 }
	                  Rainbow: a rainbow shimmer over you and rainbow accents
	                  Pulse: the glow pulses;  Orbit: pieces flying around you (Pumpkins,
	                  Candies, Ghosts, Bones, Eyes, Stars, Bats), Count of them
	                  CRAZY heads are one per crate: MegaGourd, SugarStorm, PhantomKing,
	                  StarSkull, GloopMonster, MoonCrown
	How each rarity should look: Common = colours, materials and an accent; Uncommon = + a
	head piece; Rare = + glow and particles; CRAZY = everything + rainbow + orbiting pieces.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "Pumpkin_PumpkinSpice",
		Name = "Pumpkin Spice",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 125, 40),
			ArmsColor = rgb(160, 95, 55),
			LegsColor = rgb(160, 95, 55),
			Accent = { Color = rgb(250, 235, 200), Pattern = "Stripes" },
		},
	},
	{
		Id = "Pumpkin_CandleKid",
		Name = "Candle Kid",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(250, 236, 205),
			Accent = {
				Color = rgb(255, 170, 60),
				Material = M.Neon,
				Pattern = { "Collar", "Cuffs" },
			},
		},
	},
	{
		Id = "Pumpkin_PatchKid",
		Name = "Patch Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 130, 30),
			ArmsColor = rgb(110, 170, 70),
			LegsColor = rgb(90, 140, 60),
			Accent = { Color = rgb(130, 85, 50), Material = M.Fabric, Pattern = "Patches" },
		},
	},
	{
		Id = "Pumpkin_FarmhandFred",
		Name = "Farmhand Fred",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 60, 50),
			ArmsColor = rgb(190, 60, 50),
			LegsColor = rgb(60, 90, 150),
			Material = M.Fabric,
			Accent = { Color = rgb(110, 75, 45), Pattern = { "Belt", "Boots" } },
		},
	},
	{
		Id = "Pumpkin_Gourdy",
		Name = "Gourdy",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(215, 205, 90),
			Accent = { Color = rgb(110, 150, 60), Pattern = "Stripes" },
		},
	},
	{
		Id = "Pumpkin_PumpkinPie",
		Name = "Pumpkin Pie",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(225, 120, 45),
			ArmsColor = rgb(225, 180, 110),
			LegsColor = rgb(225, 180, 110),
			ArmsMaterial = M.Sand,
			LegsMaterial = M.Sand,
			Accent = { Color = rgb(255, 250, 245), Pattern = "Collar" },
		},
	},
	{
		Id = "Pumpkin_VineClimber",
		Name = "Vine Climber",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(95, 160, 65),
			Material = M.Grass,
			Accent = { Color = rgb(255, 140, 30), Pattern = "Spots" },
		},
	},
	{
		Id = "Pumpkin_JacksJumper",
		Name = "Jack's Jumper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(245, 130, 25),
			ArmsColor = rgb(245, 130, 25),
			LegsColor = rgb(35, 30, 40),
			Accent = { Color = rgb(35, 30, 40), Pattern = "Stripes" },
		},
	},
	{
		Id = "Pumpkin_StrawStuffed",
		Name = "Straw Stuffed",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(205, 175, 120),
			Material = M.Fabric,
			Accent = { Color = rgb(70, 50, 40), Pattern = "Stitches" },
		},
	},
	{
		Id = "Pumpkin_CopperGourd",
		Name = "Copper Gourd",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(190, 110, 60),
			Material = M.Metal,
			Accent = { Color = rgb(255, 205, 80), Material = M.Foil, Pattern = { "Belt", "Cuffs" } },
		},
	},
	{
		Id = "Pumpkin_GhostPumpkin",
		Name = "Ghost Pumpkin",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 235, 220),
			Material = M.Marble,
			Accent = { Color = rgb(255, 150, 50), Pattern = "Belly" },
		},
	},
	{
		Id = "Pumpkin_Bonfire",
		Name = "Bonfire",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 50, 55),
			Material = M.Basalt,
			Accent = { Color = rgb(255, 120, 30), Material = M.Neon, Pattern = "Stripes" },
		},
	},

	-- UNCOMMON (head pieces) ---------------------------------------------------------------
	{
		Id = "Pumpkin_JackOGrin",
		Name = "Jack O' Grin",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(70, 130, 60),
			Accent = { Color = rgb(255, 140, 30), Pattern = { "Collar", "Cuffs" } },
			Head = "SkinPumpkin",
			Face = "Happy",
			HeadColor = rgb(255, 130, 20),
			GlowColor = rgb(255, 220, 90),
		},
	},
	{
		Id = "Pumpkin_SpookyJack",
		Name = "Spooky Jack",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(35, 30, 40),
			Accent = { Color = rgb(110, 50, 150), Pattern = "Cape" },
			Head = "SkinPumpkin",
			Face = "Spooky",
			HeadColor = rgb(230, 100, 10),
			GlowColor = rgb(255, 170, 40),
		},
	},
	{
		Id = "Pumpkin_ScarecrowSam",
		Name = "Scarecrow Sam",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(180, 70, 55),
			ArmsColor = rgb(180, 70, 55),
			LegsColor = rgb(70, 95, 150),
			Material = M.Fabric,
			Accent = { Color = rgb(215, 180, 90), Material = M.Fabric, Pattern = "Patches" },
			Head = "ScarecrowHead",
			HeadColor = rgb(205, 175, 120),
			HeadColor2 = rgb(215, 180, 90),
			GlowColor = rgb(200, 60, 50),
		},
	},
	{
		Id = "Pumpkin_WickyCandle",
		Name = "Wicky the Candle",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(250, 230, 200),
			Accent = { Color = rgb(255, 170, 60), Material = M.Neon, Pattern = "Cuffs" },
			Head = "CandleHead",
			HeadColor = rgb(255, 175, 100),
			GlowColor = rgb(255, 190, 60),
		},
	},
	{
		Id = "Pumpkin_SleepyGourd",
		Name = "Sleepy Gourd",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(160, 170, 230),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 255, 255), Pattern = "Buttons" },
			Head = "SkinPumpkin",
			Face = "Sleepy",
			HeadColor = rgb(240, 235, 220),
			GlowColor = rgb(150, 200, 255),
		},
	},

	-- RARE (+ glow and particles) ----------------------------------------------------------
	{
		Id = "Pumpkin_SirGourdington",
		Name = "Sir Gourdington",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(35, 28, 45),
			ArmsColor = rgb(35, 28, 45),
			LegsColor = rgb(60, 50, 70),
			Accent = { Color = rgb(150, 60, 200), Pattern = { "Cape", "Buttons" } },
			Head = "GentlemanGourd",
			Face = "Happy",
			HeadColor = rgb(255, 130, 20),
			HeadColor2 = rgb(35, 28, 45),
			HeadColor3 = rgb(150, 60, 200),
			GlowColor = rgb(255, 220, 90),
			Glow = { Color = rgb(255, 180, 80), Brightness = 1.5 },
			Aura = { Kind = "Sparkles", Color = rgb(255, 220, 120), Color2 = rgb(200, 140, 255) },
		},
	},
	{
		Id = "Pumpkin_BlazeJack",
		Name = "Blaze Jack",
		Rarity = "Rare",
		Style = {
			BodyColor = rgb(70, 45, 40),
			Material = M.CrackedLava,
			Accent = {
				Color = rgb(255, 120, 30),
				Material = M.Neon,
				Pattern = { "Gloves", "Boots" },
			},
			Head = "SkinPumpkin",
			Face = "Toothy",
			HeadColor = rgb(255, 100, 10),
			GlowColor = rgb(255, 240, 150),
			Glow = { Color = rgb(255, 120, 40), Brightness = 2 },
			Aura = { Kind = "Embers", Color = rgb(255, 210, 90), Color2 = rgb(255, 70, 20) },
		},
	},

	-- CRAZY (0.1% in the Pumpkin Crate) ----------------------------------------------------
	{
		Id = "Pumpkin_MegaGourdSupreme",
		Name = "Mega Gourd Supreme",
		Rarity = "Crazy",
		Style = {
			TorsoColor = rgb(255, 170, 40),
			ArmsColor = rgb(255, 140, 30),
			LegsColor = rgb(90, 50, 130),
			TorsoMaterial = M.Foil,
			ArmsMaterial = M.Foil,
			Accent = { Material = M.Neon, Pattern = { "Belt", "Cuffs", "Cape" } },
			Head = "MegaGourd",
			HeadColor = rgb(255, 120, 10),
			GlowColor = rgb(255, 240, 120),
			Glow = { Color = rgb(255, 170, 60), Brightness = 2.2, Range = 14 },
			Aura = { Kind = "Embers", Color = rgb(255, 210, 90) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Pumpkins", Count = 3 },
		},
	},
} :: { any }
