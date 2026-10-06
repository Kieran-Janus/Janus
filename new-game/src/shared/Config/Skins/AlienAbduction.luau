--!strict
--[[
	ALIEN ABDUCTION CRATE SKINS (22): 13 Common, 5 Uncommon, 3 Rare, and 1 CRAZY that is ONE IN A MILLION (Odds = 0.0001: 0.0001% a crate).
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (AlienAbductionCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "AlienAbduction_CropCircle",
		Name = "Crop Circle",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 230, 90),
			ArmsColor = rgb(120, 60, 200),
			LegsColor = rgb(240, 255, 100),
			Material = M.Metal,
			Accent = { Color = rgb(20, 20, 30), Pattern = "Heart" },
		},
	},
	{
		Id = "AlienAbduction_SpaceTourist",
		Name = "Space Tourist",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 205, 215),
			ArmsColor = rgb(120, 60, 200),
			LegsColor = rgb(255, 80, 170),
			Accent = { Color = rgb(255, 80, 170), Pattern = "Collar" },
		},
	},
	{
		Id = "AlienAbduction_GreenVisitor",
		Name = "Green Visitor",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 240, 255),
			ArmsColor = rgb(255, 80, 170),
			LegsColor = rgb(200, 205, 215),
			Material = M.Foil,
			Accent = { Color = rgb(240, 255, 100), Pattern = { "Boots", "Gloves" } },
		},
	},
	{
		Id = "AlienAbduction_BeamRider",
		Name = "Beam Rider",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 60, 200),
			Material = M.Glass,
			Accent = { Color = rgb(120, 230, 90), Pattern = "Spots" },
		},
	},
	{
		Id = "AlienAbduction_ProbePal",
		Name = "Probe Pal",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(20, 20, 30),
			ArmsColor = rgb(120, 230, 90),
			LegsColor = rgb(120, 60, 200),
			Material = M.Metal,
			Accent = { Color = rgb(200, 205, 215), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "AlienAbduction_MoonRock",
		Name = "Moon Rock",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 80, 170),
			ArmsColor = rgb(120, 230, 90),
			LegsColor = rgb(90, 240, 255),
			Accent = { Color = rgb(90, 240, 255), Pattern = { "Sash", "Boots" } },
		},
	},
	{
		Id = "AlienAbduction_StarMap",
		Name = "Star Map",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 255, 100),
			ArmsColor = rgb(90, 240, 255),
			LegsColor = rgb(255, 80, 170),
			Material = M.Foil,
			Accent = { Color = rgb(120, 60, 200), Pattern = "Tail" },
		},
	},
	{
		Id = "AlienAbduction_RayGun",
		Name = "Ray Gun",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(120, 230, 90),
			Material = M.Glass,
			Accent = { Color = rgb(20, 20, 30), Pattern = "Star" },
		},
	},
	{
		Id = "AlienAbduction_CowChaser",
		Name = "Cow Chaser",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 205, 215),
			ArmsColor = rgb(20, 20, 30),
			LegsColor = rgb(120, 230, 90),
			Material = M.Metal,
			Accent = { Color = rgb(255, 80, 170), Pattern = { "Cuffs", "Stripes" } },
		},
	},
	{
		Id = "AlienAbduction_FlyingSaucer",
		Name = "Flying Saucer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 240, 255),
			ArmsColor = rgb(20, 20, 30),
			LegsColor = rgb(240, 255, 100),
			Accent = { Color = rgb(240, 255, 100), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "AlienAbduction_AntennaKid",
		Name = "Antenna Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 60, 200),
			ArmsColor = rgb(240, 255, 100),
			LegsColor = rgb(90, 240, 255),
			Material = M.Foil,
			Accent = { Color = rgb(120, 230, 90), Pattern = "Belly" },
		},
	},
	{
		Id = "AlienAbduction_SignalSeeker",
		Name = "Signal Seeker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(20, 20, 30),
			Material = M.Glass,
			Accent = { Color = rgb(200, 205, 215), Pattern = { "Stitches", "Wraps" } },
		},
	},
	{
		Id = "AlienAbduction_OrbitKid",
		Name = "Orbit Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 80, 170),
			ArmsColor = rgb(200, 205, 215),
			LegsColor = rgb(20, 20, 30),
			Material = M.Metal,
			Accent = { Color = rgb(90, 240, 255), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "AlienAbduction_LittleGreenAlien",
		Name = "Little Green Alien",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 255, 100),
			ArmsColor = rgb(90, 240, 255),
			LegsColor = rgb(255, 80, 170),
			Accent = { Color = rgb(120, 60, 200), Pattern = { "Web", "Belt" } },
			Head = "AlienHead",
			HeadColor = rgb(90, 240, 255),
			HeadColor2 = rgb(255, 80, 170),
			GlowColor = rgb(120, 230, 90),
		},
	},
	{
		Id = "AlienAbduction_BigEye",
		Name = "Big Eye",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(120, 230, 90),
			ArmsColor = rgb(120, 60, 200),
			LegsColor = rgb(240, 255, 100),
			Accent = { Color = rgb(20, 20, 30), Material = M.Neon, Pattern = { "Belt", "Spots" } },
			Head = "EyeballHead",
			HeadColor = rgb(20, 20, 30),
			HeadColor2 = rgb(120, 230, 90),
			GlowColor = rgb(90, 240, 255),
		},
	},
	{
		Id = "AlienAbduction_BlobFromSpace",
		Name = "Blob From Space",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(200, 205, 215),
			Accent = { Color = rgb(255, 80, 170), Pattern = { "Gloves", "Cape" } },
			Head = "BlobHead",
			HeadColor = rgb(240, 255, 100),
			HeadColor2 = rgb(90, 240, 255),
			GlowColor = rgb(20, 20, 30),
		},
	},
	{
		Id = "AlienAbduction_SaucerPilot",
		Name = "Saucer Pilot",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(90, 240, 255),
			ArmsColor = rgb(255, 80, 170),
			LegsColor = rgb(200, 205, 215),
			Accent = { Color = rgb(240, 255, 100), Pattern = { "Wraps", "Collar" } },
			Head = "AlienHead",
			HeadColor = rgb(200, 205, 215),
			HeadColor2 = rgb(20, 20, 30),
			GlowColor = rgb(240, 255, 100),
		},
	},
	{
		Id = "AlienAbduction_GalaxyGazer",
		Name = "Galaxy Gazer",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(120, 60, 200),
			ArmsColor = rgb(240, 255, 100),
			LegsColor = rgb(90, 240, 255),
			Accent = { Color = rgb(120, 230, 90), Pattern = { "Buttons", "Belly" } },
			Head = "EyeballHead",
			HeadColor = rgb(120, 60, 200),
			HeadColor2 = rgb(240, 255, 100),
			GlowColor = rgb(200, 205, 215),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "AlienAbduction_MothershipCommander",
		Name = "Mothership Commander",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 255, 100),
			ArmsColor = rgb(120, 60, 200),
			LegsColor = rgb(120, 230, 90),
			Accent = { Color = rgb(120, 60, 200), Pattern = { "Heart", "Buttons" } },
			Head = "AlienHead",
			HeadColor = rgb(255, 80, 170),
			HeadColor2 = rgb(120, 230, 90),
			GlowColor = rgb(20, 20, 30),
			Glow = { Color = rgb(20, 20, 30), Brightness = 1.6 },
			Aura = { Kind = "Stars", Color = rgb(20, 20, 30), Color2 = rgb(200, 205, 215) },
		},
	},
	{
		Id = "AlienAbduction_CosmicEye",
		Name = "Cosmic Eye",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 230, 90),
			ArmsColor = rgb(20, 20, 30),
			LegsColor = rgb(200, 205, 215),
			Accent = { Color = rgb(20, 20, 30), Pattern = { "Collar", "Tail" } },
			Head = "EyeballHead",
			HeadColor = rgb(200, 205, 215),
			HeadColor2 = rgb(120, 60, 200),
			GlowColor = rgb(120, 230, 90),
			Glow = { Color = rgb(120, 230, 90), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(120, 230, 90), Color2 = rgb(20, 20, 30) },
		},
	},
	{
		Id = "AlienAbduction_NebulaBeing",
		Name = "Nebula Being",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(200, 205, 215),
			ArmsColor = rgb(255, 80, 170),
			LegsColor = rgb(90, 240, 255),
			Accent = { Color = rgb(255, 80, 170), Pattern = { "Boots", "Gloves" } },
			Head = "AlienHead",
			HeadColor = rgb(20, 20, 30),
			HeadColor2 = rgb(240, 255, 100),
			GlowColor = rgb(120, 60, 200),
			Glow = { Color = rgb(120, 60, 200), Brightness = 2.0 },
			Aura = { Kind = "Bubbles", Color = rgb(120, 60, 200), Color2 = rgb(120, 230, 90) },
		},
	},

	-- ONE IN A MILLION (CRAZY, 0.0001% a crate: the flashiest skin in the game) ----------
	{
		Id = "AlienAbduction_StarVoyager",
		Name = "Star Voyager",
		Rarity = "Crazy",
		OneInAMillion = true, -- only in this crate, never in the CRAZY Crate
		Odds = 0.0001, -- percent: 1 in 1,000,000 opens
		Style = {
			BodyColor = rgb(210, 215, 230),
			Material = M.Foil,
			Accent = {
				Color = rgb(90, 240, 255),
				Material = M.Neon,
				Pattern = { "Cape", "Gloves", "Boots", "Belt" },
			},
			Head = "StarVoyager",
			HeadColor = rgb(120, 230, 90),
			HeadColor2 = rgb(200, 220, 255),
			GlowColor = rgb(90, 255, 220),
			Glow = { Color = rgb(90, 255, 220), Brightness = 3, Range = 16 },
			Aura = { Kind = "Sparkles", Color = rgb(120, 255, 230), Color2 = rgb(200, 120, 255) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Stars", Count = 5, Effect = "UfoBeam" },
		},
	},
} :: { any }
