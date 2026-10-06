--!strict
--[[
	HAUNTED HOTEL CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (HauntedHotelCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "HauntedHotel_NightPorter",
		Name = "Night Porter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 20, 40),
			ArmsColor = rgb(240, 230, 210),
			LegsColor = rgb(25, 20, 25),
			Material = M.Fabric,
			Accent = { Color = rgb(100, 50, 35), Pattern = "Belly" },
		},
	},
	{
		Id = "HauntedHotel_RoomService",
		Name = "Room Service",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(220, 180, 80),
			ArmsColor = rgb(240, 230, 210),
			LegsColor = rgb(50, 90, 60),
			Material = M.Carpet,
			Accent = { Color = rgb(50, 90, 60), Pattern = "Stitches" },
		},
	},
	{
		Id = "HauntedHotel_HousekeeperGhost",
		Name = "Housekeeper Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 110, 110),
			ArmsColor = rgb(50, 90, 60),
			LegsColor = rgb(220, 180, 80),
			Material = M.Marble,
			Accent = { Color = rgb(25, 20, 25), Pattern = { "Cape", "Stitches" } },
		},
	},
	{
		Id = "HauntedHotel_LobbyBoy",
		Name = "Lobby Boy",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 230, 210),
			Accent = { Color = rgb(150, 20, 40), Pattern = "Web" },
		},
	},
	{
		Id = "HauntedHotel_ElevatorOperator",
		Name = "Elevator Operator",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(100, 50, 35),
			ArmsColor = rgb(150, 20, 40),
			LegsColor = rgb(240, 230, 210),
			Material = M.Fabric,
			Accent = { Color = rgb(220, 180, 80), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "HauntedHotel_KeyClerk",
		Name = "Key Clerk",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(50, 90, 60),
			ArmsColor = rgb(150, 20, 40),
			LegsColor = rgb(40, 110, 110),
			Material = M.Carpet,
			Accent = { Color = rgb(40, 110, 110), Pattern = { "Gloves", "Patches" } },
		},
	},
	{
		Id = "HauntedHotel_Doorman",
		Name = "Doorman",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(25, 20, 25),
			ArmsColor = rgb(40, 110, 110),
			LegsColor = rgb(50, 90, 60),
			Material = M.Marble,
			Accent = { Color = rgb(240, 230, 210), Pattern = "Wraps" },
		},
	},
	{
		Id = "HauntedHotel_LaundryGhost",
		Name = "Laundry Ghost",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 20, 40),
			Accent = { Color = rgb(100, 50, 35), Pattern = "Buttons" },
		},
	},
	{
		Id = "HauntedHotel_ChandelierDust",
		Name = "Chandelier Dust",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(220, 180, 80),
			ArmsColor = rgb(100, 50, 35),
			LegsColor = rgb(150, 20, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(50, 90, 60), Pattern = { "Patches", "Sash" } },
		},
	},
	{
		Id = "HauntedHotel_GuestBook",
		Name = "Guest Book",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 110, 110),
			ArmsColor = rgb(100, 50, 35),
			LegsColor = rgb(25, 20, 25),
			Material = M.Carpet,
			Accent = { Color = rgb(25, 20, 25), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "HauntedHotel_HallwayWanderer",
		Name = "Hallway Wanderer",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 230, 210),
			ArmsColor = rgb(25, 20, 25),
			LegsColor = rgb(40, 110, 110),
			Material = M.Marble,
			Accent = { Color = rgb(150, 20, 40), Pattern = "Heart" },
		},
	},
	{
		Id = "HauntedHotel_BellboyGhost",
		Name = "Bellboy Ghost",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(100, 50, 35),
			Accent = { Color = rgb(220, 180, 80), Pattern = { "Collar", "Cape" } },
		},
	},
	{
		Id = "HauntedHotel_SuiteGuest",
		Name = "Suite Guest",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(50, 90, 60),
			ArmsColor = rgb(220, 180, 80),
			LegsColor = rgb(100, 50, 35),
			Material = M.Fabric,
			Accent = { Color = rgb(40, 110, 110), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "HauntedHotel_HauntedBellhop",
		Name = "Haunted Bellhop",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(25, 20, 25),
			ArmsColor = rgb(40, 110, 110),
			LegsColor = rgb(50, 90, 60),
			Accent = { Color = rgb(240, 230, 210), Pattern = { "Spots", "Belly" } },
			Head = "BellhopHat",
			HeadColor = rgb(40, 110, 110),
			HeadColor2 = rgb(50, 90, 60),
			GlowColor = rgb(150, 20, 40),
		},
	},
	{
		Id = "HauntedHotel_LanternWatchman",
		Name = "Lantern Watchman",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(150, 20, 40),
			ArmsColor = rgb(240, 230, 210),
			LegsColor = rgb(25, 20, 25),
			Accent = { Color = rgb(100, 50, 35), Material = M.Neon, Pattern = { "Bones", "Wings" } },
			Head = "LanternHead",
			HeadColor = rgb(100, 50, 35),
			HeadColor2 = rgb(150, 20, 40),
			GlowColor = rgb(40, 110, 110),
		},
	},
	{
		Id = "HauntedHotel_CandlelightMaid",
		Name = "Candlelight Maid",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(220, 180, 80),
			Accent = { Color = rgb(50, 90, 60), Pattern = { "Sash", "Cuffs" } },
			Head = "CandleHead",
			HeadColor = rgb(25, 20, 25),
			HeadColor2 = rgb(40, 110, 110),
			GlowColor = rgb(100, 50, 35),
		},
	},
	{
		Id = "HauntedHotel_GhostlyConcierge",
		Name = "Ghostly Concierge",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(40, 110, 110),
			ArmsColor = rgb(50, 90, 60),
			LegsColor = rgb(220, 180, 80),
			Accent = { Color = rgb(25, 20, 25), Pattern = { "Tail", "Buttons" } },
			Head = "BellhopHat",
			HeadColor = rgb(220, 180, 80),
			HeadColor2 = rgb(100, 50, 35),
			GlowColor = rgb(25, 20, 25),
		},
	},
	{
		Id = "HauntedHotel_Room13Guest",
		Name = "Room 13 Guest",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 230, 210),
			ArmsColor = rgb(25, 20, 25),
			LegsColor = rgb(40, 110, 110),
			Accent = { Color = rgb(150, 20, 40), Pattern = { "Star", "Tail" } },
			Head = "LanternHead",
			HeadColor = rgb(240, 230, 210),
			HeadColor2 = rgb(25, 20, 25),
			GlowColor = rgb(220, 180, 80),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "HauntedHotel_HotelPhantom",
		Name = "Hotel Phantom",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(25, 20, 25),
			ArmsColor = rgb(240, 230, 210),
			LegsColor = rgb(150, 20, 40),
			Accent = { Color = rgb(240, 230, 210), Pattern = { "Belly", "Web" } },
			Head = "BellhopHat",
			HeadColor = rgb(50, 90, 60),
			HeadColor2 = rgb(150, 20, 40),
			GlowColor = rgb(100, 50, 35),
			Glow = { Color = rgb(100, 50, 35), Brightness = 1.6 },
			Aura = { Kind = "Smoke", Color = rgb(100, 50, 35), Color2 = rgb(220, 180, 80) },
		},
	},
	{
		Id = "HauntedHotel_PenthouseGhost",
		Name = "Penthouse Ghost",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(150, 20, 40),
			ArmsColor = rgb(100, 50, 35),
			LegsColor = rgb(220, 180, 80),
			Accent = { Color = rgb(100, 50, 35), Pattern = { "Stitches", "Boots" } },
			Head = "CandleHead",
			HeadColor = rgb(220, 180, 80),
			HeadColor2 = rgb(240, 230, 210),
			GlowColor = rgb(150, 20, 40),
			Glow = { Color = rgb(150, 20, 40), Brightness = 1.8 },
			Aura = { Kind = "Sparkles", Color = rgb(150, 20, 40), Color2 = rgb(100, 50, 35) },
		},
	},
	{
		Id = "HauntedHotel_TheNightManager",
		Name = "The Night Manager",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(220, 180, 80),
			ArmsColor = rgb(50, 90, 60),
			LegsColor = rgb(40, 110, 110),
			Accent = { Color = rgb(50, 90, 60), Pattern = { "Cape", "Stitches" } },
			Head = "LanternHead",
			HeadColor = rgb(100, 50, 35),
			HeadColor2 = rgb(25, 20, 25),
			GlowColor = rgb(240, 230, 210),
			Glow = { Color = rgb(240, 230, 210), Brightness = 2.0 },
			Aura = { Kind = "Embers", Color = rgb(240, 230, 210), Color2 = rgb(150, 20, 40) },
		},
	},
} :: { any }
