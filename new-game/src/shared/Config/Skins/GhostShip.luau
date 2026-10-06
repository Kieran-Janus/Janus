--!strict
--[[
	GHOST SHIP CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (GhostShipCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "GhostShip_DeckhandGhost",
		Name = "Deckhand Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(140, 230, 220),
			ArmsColor = rgb(150, 70, 40),
			LegsColor = rgb(170, 170, 160),
			Material = M.Fabric,
			Accent = { Color = rgb(60, 120, 80), Pattern = "Heart" },
		},
	},
	{
		Id = "GhostShip_ShipCook",
		Name = "Ship Cook",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 40, 80),
			ArmsColor = rgb(150, 70, 40),
			LegsColor = rgb(235, 235, 240),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(235, 235, 240), Pattern = "Collar" },
		},
	},
	{
		Id = "GhostShip_CrowsNestLookout",
		Name = "Crow's Nest Lookout",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 160, 110),
			ArmsColor = rgb(235, 235, 240),
			LegsColor = rgb(25, 40, 80),
			Accent = { Color = rgb(170, 170, 160), Pattern = { "Boots", "Star" } },
		},
	},
	{
		Id = "GhostShip_RopeRigger",
		Name = "Rope Rigger",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 70, 40),
			Material = M.Glass,
			Accent = { Color = rgb(140, 230, 220), Pattern = "Spots" },
		},
	},
	{
		Id = "GhostShip_BarnacleBob",
		Name = "Barnacle Bob",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(60, 120, 80),
			ArmsColor = rgb(140, 230, 220),
			LegsColor = rgb(150, 70, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(25, 40, 80), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "GhostShip_GhostlySwabbie",
		Name = "Ghostly Swabbie",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 235, 240),
			ArmsColor = rgb(140, 230, 220),
			LegsColor = rgb(190, 160, 110),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(190, 160, 110), Pattern = { "Sash", "Belt" } },
		},
	},
	{
		Id = "GhostShip_LanternMate",
		Name = "Lantern Mate",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(170, 170, 160),
			ArmsColor = rgb(190, 160, 110),
			LegsColor = rgb(235, 235, 240),
			Accent = { Color = rgb(150, 70, 40), Pattern = "Tail" },
		},
	},
	{
		Id = "GhostShip_AnchorHauler",
		Name = "Anchor Hauler",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(140, 230, 220),
			Material = M.Glass,
			Accent = { Color = rgb(60, 120, 80), Pattern = "Star" },
		},
	},
	{
		Id = "GhostShip_SeaFog",
		Name = "Sea Fog",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 40, 80),
			ArmsColor = rgb(60, 120, 80),
			LegsColor = rgb(140, 230, 220),
			Material = M.Fabric,
			Accent = { Color = rgb(235, 235, 240), Pattern = { "Cuffs", "Collar" } },
		},
	},
	{
		Id = "GhostShip_TreasureCounter",
		Name = "Treasure Counter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 160, 110),
			ArmsColor = rgb(60, 120, 80),
			LegsColor = rgb(170, 170, 160),
			Material = M.WoodPlanks,
			Accent = { Color = rgb(170, 170, 160), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "GhostShip_PlankWalker",
		Name = "Plank Walker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 70, 40),
			ArmsColor = rgb(170, 170, 160),
			LegsColor = rgb(190, 160, 110),
			Accent = { Color = rgb(140, 230, 220), Pattern = "Belly" },
		},
	},
	{
		Id = "GhostShip_SailMender",
		Name = "Sail Mender",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(60, 120, 80),
			Material = M.Glass,
			Accent = { Color = rgb(25, 40, 80), Pattern = { "Stitches", "Cuffs" } },
		},
	},
	{
		Id = "GhostShip_BilgeRat",
		Name = "Bilge Rat",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 235, 240),
			ArmsColor = rgb(25, 40, 80),
			LegsColor = rgb(60, 120, 80),
			Material = M.Fabric,
			Accent = { Color = rgb(190, 160, 110), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "GhostShip_PhantomCaptain",
		Name = "Phantom Captain",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(170, 170, 160),
			ArmsColor = rgb(190, 160, 110),
			LegsColor = rgb(235, 235, 240),
			Accent = { Color = rgb(150, 70, 40), Pattern = { "Web", "Tail" } },
			Head = "CaptainHat",
			HeadColor = rgb(190, 160, 110),
			HeadColor2 = rgb(235, 235, 240),
			GlowColor = rgb(140, 230, 220),
		},
	},
	{
		Id = "GhostShip_SpectralFirstMate",
		Name = "Spectral First Mate",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(140, 230, 220),
			ArmsColor = rgb(150, 70, 40),
			LegsColor = rgb(170, 170, 160),
			Accent = { Color = rgb(60, 120, 80), Material = M.Neon, Pattern = { "Belt", "Gloves" } },
			Head = "GhostSheet",
			HeadColor = rgb(60, 120, 80),
			HeadColor2 = rgb(140, 230, 220),
			GlowColor = rgb(190, 160, 110),
		},
	},
	{
		Id = "GhostShip_GhostPirate",
		Name = "Ghost Pirate",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(25, 40, 80),
			Accent = { Color = rgb(235, 235, 240), Pattern = { "Gloves", "Bones" } },
			Head = "CaptainHat",
			HeadColor = rgb(170, 170, 160),
			HeadColor2 = rgb(190, 160, 110),
			GlowColor = rgb(60, 120, 80),
		},
	},
	{
		Id = "GhostShip_DrownedNavigator",
		Name = "Drowned Navigator",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(190, 160, 110),
			ArmsColor = rgb(235, 235, 240),
			LegsColor = rgb(25, 40, 80),
			Accent = { Color = rgb(170, 170, 160), Pattern = { "Wraps", "Web" } },
			Head = "GhostSheet",
			HeadColor = rgb(25, 40, 80),
			HeadColor2 = rgb(60, 120, 80),
			GlowColor = rgb(170, 170, 160),
		},
	},
	{
		Id = "GhostShip_SirensShadow",
		Name = "Siren's Shadow",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 70, 40),
			ArmsColor = rgb(170, 170, 160),
			LegsColor = rgb(190, 160, 110),
			Accent = { Color = rgb(140, 230, 220), Pattern = { "Buttons", "Boots" } },
			Head = "CaptainHat",
			HeadColor = rgb(150, 70, 40),
			HeadColor2 = rgb(170, 170, 160),
			GlowColor = rgb(25, 40, 80),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "GhostShip_FlyingDutchman",
		Name = "Flying Dutchman",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(170, 170, 160),
			ArmsColor = rgb(150, 70, 40),
			LegsColor = rgb(140, 230, 220),
			Accent = { Color = rgb(150, 70, 40), Pattern = { "Heart", "Stripes" } },
			Head = "CaptainHat",
			HeadColor = rgb(235, 235, 240),
			HeadColor2 = rgb(140, 230, 220),
			GlowColor = rgb(60, 120, 80),
			Glow = { Color = rgb(60, 120, 80), Brightness = 1.6 },
			Aura = { Kind = "Bubbles", Color = rgb(60, 120, 80), Color2 = rgb(25, 40, 80) },
		},
	},
	{
		Id = "GhostShip_KrakenCaller",
		Name = "Kraken Caller",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(140, 230, 220),
			ArmsColor = rgb(60, 120, 80),
			LegsColor = rgb(25, 40, 80),
			Accent = { Color = rgb(60, 120, 80), Pattern = { "Collar", "Patches" } },
			Head = "GhostSheet",
			HeadColor = rgb(25, 40, 80),
			HeadColor2 = rgb(150, 70, 40),
			GlowColor = rgb(140, 230, 220),
			Glow = { Color = rgb(140, 230, 220), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(140, 230, 220), Color2 = rgb(60, 120, 80) },
		},
	},
	{
		Id = "GhostShip_AdmiralofMist",
		Name = "Admiral of Mist",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(25, 40, 80),
			ArmsColor = rgb(235, 235, 240),
			LegsColor = rgb(190, 160, 110),
			Accent = { Color = rgb(235, 235, 240), Pattern = { "Boots", "Star" } },
			Head = "CaptainHat",
			HeadColor = rgb(60, 120, 80),
			HeadColor2 = rgb(170, 170, 160),
			GlowColor = rgb(150, 70, 40),
			Glow = { Color = rgb(150, 70, 40), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(150, 70, 40), Color2 = rgb(140, 230, 220) },
		},
	},
} :: { any }
