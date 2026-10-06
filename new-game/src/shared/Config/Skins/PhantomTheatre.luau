--!strict
--[[
	PHANTOM THEATRE CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (PhantomTheatreCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "PhantomTheatre_UsherGhost",
		Name = "Usher Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(160, 20, 40),
			ArmsColor = rgb(20, 18, 22),
			LegsColor = rgb(190, 190, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(90, 40, 130), Pattern = "Heart" },
		},
	},
	{
		Id = "PhantomTheatre_Stagehand",
		Name = "Stagehand",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(225, 185, 80),
			ArmsColor = rgb(20, 18, 22),
			LegsColor = rgb(255, 240, 170),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 240, 170), Pattern = "Collar" },
		},
	},
	{
		Id = "PhantomTheatre_TicketSeller",
		Name = "Ticket Seller",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 235, 220),
			ArmsColor = rgb(255, 240, 170),
			LegsColor = rgb(225, 185, 80),
			Material = M.Marble,
			Accent = { Color = rgb(190, 190, 200), Pattern = { "Boots", "Stitches" } },
		},
	},
	{
		Id = "PhantomTheatre_PropMaster",
		Name = "Prop Master",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(20, 18, 22),
			Material = M.Foil,
			Accent = { Color = rgb(160, 20, 40), Pattern = "Spots" },
		},
	},
	{
		Id = "PhantomTheatre_ChorusSinger",
		Name = "Chorus Singer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(90, 40, 130),
			ArmsColor = rgb(160, 20, 40),
			LegsColor = rgb(20, 18, 22),
			Material = M.Fabric,
			Accent = { Color = rgb(225, 185, 80), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "PhantomTheatre_BalletGhost",
		Name = "Ballet Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 240, 170),
			ArmsColor = rgb(160, 20, 40),
			LegsColor = rgb(240, 235, 220),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 235, 220), Pattern = { "Sash", "Patches" } },
		},
	},
	{
		Id = "PhantomTheatre_SpotlightOperator",
		Name = "Spotlight Operator",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 190, 200),
			ArmsColor = rgb(240, 235, 220),
			LegsColor = rgb(255, 240, 170),
			Material = M.Marble,
			Accent = { Color = rgb(20, 18, 22), Pattern = "Tail" },
		},
	},
	{
		Id = "PhantomTheatre_CostumeMaker",
		Name = "Costume Maker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(160, 20, 40),
			Material = M.Foil,
			Accent = { Color = rgb(90, 40, 130), Pattern = "Star" },
		},
	},
	{
		Id = "PhantomTheatre_Prompter",
		Name = "Prompter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(225, 185, 80),
			ArmsColor = rgb(90, 40, 130),
			LegsColor = rgb(160, 20, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 240, 170), Pattern = { "Cuffs", "Sash" } },
		},
	},
	{
		Id = "PhantomTheatre_Understudy",
		Name = "Understudy",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 235, 220),
			ArmsColor = rgb(90, 40, 130),
			LegsColor = rgb(190, 190, 200),
			Material = M.Fabric,
			Accent = { Color = rgb(190, 190, 200), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "PhantomTheatre_BoxSeatGuest",
		Name = "Box Seat Guest",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(20, 18, 22),
			ArmsColor = rgb(190, 190, 200),
			LegsColor = rgb(240, 235, 220),
			Material = M.Marble,
			Accent = { Color = rgb(160, 20, 40), Pattern = "Belly" },
		},
	},
	{
		Id = "PhantomTheatre_CurtainPuller",
		Name = "Curtain Puller",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(90, 40, 130),
			Material = M.Foil,
			Accent = { Color = rgb(225, 185, 80), Pattern = { "Stitches", "Cape" } },
		},
	},
	{
		Id = "PhantomTheatre_OperaFan",
		Name = "Opera Fan",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 240, 170),
			ArmsColor = rgb(225, 185, 80),
			LegsColor = rgb(90, 40, 130),
			Material = M.Fabric,
			Accent = { Color = rgb(240, 235, 220), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "PhantomTheatre_MaskedPhantom",
		Name = "Masked Phantom",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(190, 190, 200),
			ArmsColor = rgb(240, 235, 220),
			LegsColor = rgb(255, 240, 170),
			Accent = { Color = rgb(20, 18, 22), Pattern = { "Web", "Belly" } },
			Head = "PhantomMask",
			HeadColor = rgb(240, 235, 220),
			HeadColor2 = rgb(255, 240, 170),
			GlowColor = rgb(160, 20, 40),
		},
	},
	{
		Id = "PhantomTheatre_StageGhost",
		Name = "Stage Ghost",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(160, 20, 40),
			ArmsColor = rgb(20, 18, 22),
			LegsColor = rgb(190, 190, 200),
			Accent = { Color = rgb(90, 40, 130), Material = M.Neon, Pattern = { "Belt", "Wings" } },
			Head = "GhostSheet",
			HeadColor = rgb(90, 40, 130),
			HeadColor2 = rgb(160, 20, 40),
			GlowColor = rgb(240, 235, 220),
		},
	},
	{
		Id = "PhantomTheatre_TheCritic",
		Name = "The Critic",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(225, 185, 80),
			Accent = { Color = rgb(255, 240, 170), Pattern = { "Gloves", "Cuffs" } },
			Head = "GentlemanGourd",
			Face = "Surprised",
			HeadColor = rgb(190, 190, 200),
			HeadColor2 = rgb(240, 235, 220),
			GlowColor = rgb(90, 40, 130),
		},
	},
	{
		Id = "PhantomTheatre_LeadingLadyGhost",
		Name = "Leading Lady Ghost",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 235, 220),
			ArmsColor = rgb(255, 240, 170),
			LegsColor = rgb(225, 185, 80),
			Accent = { Color = rgb(190, 190, 200), Pattern = { "Wraps", "Buttons" } },
			Head = "PhantomMask",
			HeadColor = rgb(225, 185, 80),
			HeadColor2 = rgb(90, 40, 130),
			GlowColor = rgb(190, 190, 200),
		},
	},
	{
		Id = "PhantomTheatre_OperaSinger",
		Name = "Opera Singer",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(20, 18, 22),
			ArmsColor = rgb(190, 190, 200),
			LegsColor = rgb(240, 235, 220),
			Accent = { Color = rgb(160, 20, 40), Pattern = { "Buttons", "Tail" } },
			Head = "GhostSheet",
			HeadColor = rgb(20, 18, 22),
			HeadColor2 = rgb(190, 190, 200),
			GlowColor = rgb(225, 185, 80),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "PhantomTheatre_OperaPhantom",
		Name = "Opera Phantom",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(190, 190, 200),
			ArmsColor = rgb(20, 18, 22),
			LegsColor = rgb(160, 20, 40),
			Accent = { Color = rgb(20, 18, 22), Pattern = { "Heart", "Web" } },
			Head = "PhantomMask",
			HeadColor = rgb(255, 240, 170),
			HeadColor2 = rgb(160, 20, 40),
			GlowColor = rgb(90, 40, 130),
			Glow = { Color = rgb(90, 40, 130), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(90, 40, 130), Color2 = rgb(225, 185, 80) },
		},
	},
	{
		Id = "PhantomTheatre_MidnightMaestro",
		Name = "Midnight Maestro",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(160, 20, 40),
			ArmsColor = rgb(90, 40, 130),
			LegsColor = rgb(225, 185, 80),
			Accent = { Color = rgb(90, 40, 130), Pattern = { "Collar", "Boots" } },
			Head = "PhantomMask",
			HeadColor = rgb(225, 185, 80),
			HeadColor2 = rgb(20, 18, 22),
			GlowColor = rgb(160, 20, 40),
			Glow = { Color = rgb(160, 20, 40), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(160, 20, 40), Color2 = rgb(90, 40, 130) },
		},
	},
	{
		Id = "PhantomTheatre_GrandMasquerade",
		Name = "Grand Masquerade",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(225, 185, 80),
			ArmsColor = rgb(255, 240, 170),
			LegsColor = rgb(240, 235, 220),
			Accent = { Color = rgb(255, 240, 170), Pattern = { "Boots", "Stitches" } },
			Head = "GhostSheet",
			HeadColor = rgb(90, 40, 130),
			HeadColor2 = rgb(190, 190, 200),
			GlowColor = rgb(20, 18, 22),
			Glow = { Color = rgb(20, 18, 22), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(20, 18, 22), Color2 = rgb(160, 20, 40) },
		},
	},
} :: { any }
