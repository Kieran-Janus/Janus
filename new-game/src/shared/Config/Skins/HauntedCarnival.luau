--!strict
--[[
	HAUNTED CARNIVAL CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (HauntedCarnivalCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "HauntedCarnival_TicketTaker",
		Name = "Ticket Taker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(220, 40, 50),
			ArmsColor = rgb(40, 180, 170),
			LegsColor = rgb(40, 40, 90),
			Accent = { Color = rgb(130, 60, 170), Pattern = "Heart" },
		},
	},
	{
		Id = "HauntedCarnival_PopcornGhoul",
		Name = "Popcorn Ghoul",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(245, 240, 230),
			ArmsColor = rgb(40, 180, 170),
			LegsColor = rgb(255, 140, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 140, 40), Pattern = "Collar" },
		},
	},
	{
		Id = "HauntedCarnival_BalloonTwister",
		Name = "Balloon Twister",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 210, 50),
			ArmsColor = rgb(255, 140, 40),
			LegsColor = rgb(245, 240, 230),
			Material = M.Foil,
			Accent = { Color = rgb(40, 40, 90), Pattern = { "Boots", "Stitches" } },
		},
	},
	{
		Id = "HauntedCarnival_RingTossGhost",
		Name = "Ring Toss Ghost",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 180, 170),
			Material = M.Plastic,
			Accent = { Color = rgb(220, 40, 50), Pattern = "Spots" },
		},
	},
	{
		Id = "HauntedCarnival_CottonCandyKid",
		Name = "Cotton Candy Kid",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 60, 170),
			ArmsColor = rgb(220, 40, 50),
			LegsColor = rgb(40, 180, 170),
			Accent = { Color = rgb(245, 240, 230), Material = M.Neon, Pattern = "Bones" },
		},
	},
	{
		Id = "HauntedCarnival_StrongmanSpecter",
		Name = "Strongman Specter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 140, 40),
			ArmsColor = rgb(220, 40, 50),
			LegsColor = rgb(255, 210, 50),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 210, 50), Pattern = { "Sash", "Patches" } },
		},
	},
	{
		Id = "HauntedCarnival_JugglingJester",
		Name = "Juggling Jester",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 40, 90),
			ArmsColor = rgb(255, 210, 50),
			LegsColor = rgb(255, 140, 40),
			Material = M.Foil,
			Accent = { Color = rgb(40, 180, 170), Pattern = "Tail" },
		},
	},
	{
		Id = "HauntedCarnival_CarouselRider",
		Name = "Carousel Rider",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(220, 40, 50),
			Material = M.Plastic,
			Accent = { Color = rgb(130, 60, 170), Pattern = "Star" },
		},
	},
	{
		Id = "HauntedCarnival_TentPainter",
		Name = "Tent Painter",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(245, 240, 230),
			ArmsColor = rgb(130, 60, 170),
			LegsColor = rgb(220, 40, 50),
			Accent = { Color = rgb(255, 140, 40), Pattern = { "Cuffs", "Sash" } },
		},
	},
	{
		Id = "HauntedCarnival_PeanutVendor",
		Name = "Peanut Vendor",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 210, 50),
			ArmsColor = rgb(130, 60, 170),
			LegsColor = rgb(40, 40, 90),
			Material = M.Fabric,
			Accent = { Color = rgb(40, 40, 90), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "HauntedCarnival_FunhouseMirror",
		Name = "Funhouse Mirror",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 180, 170),
			ArmsColor = rgb(40, 40, 90),
			LegsColor = rgb(255, 210, 50),
			Material = M.Foil,
			Accent = { Color = rgb(220, 40, 50), Pattern = "Belly" },
		},
	},
	{
		Id = "HauntedCarnival_MidwayBarker",
		Name = "Midway Barker",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(130, 60, 170),
			Material = M.Plastic,
			Accent = { Color = rgb(245, 240, 230), Pattern = { "Stitches", "Cape" } },
		},
	},
	{
		Id = "HauntedCarnival_TightropeWalker",
		Name = "Tightrope Walker",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 140, 40),
			ArmsColor = rgb(245, 240, 230),
			LegsColor = rgb(130, 60, 170),
			Accent = { Color = rgb(255, 210, 50), Pattern = "Cape" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "HauntedCarnival_CreepyClown",
		Name = "Creepy Clown",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(40, 40, 90),
			ArmsColor = rgb(255, 210, 50),
			LegsColor = rgb(255, 140, 40),
			Accent = { Color = rgb(40, 180, 170), Pattern = { "Web", "Belly" } },
			Head = "ClownHead",
			HeadColor = rgb(255, 210, 50),
			HeadColor2 = rgb(255, 140, 40),
			GlowColor = rgb(220, 40, 50),
		},
	},
	{
		Id = "HauntedCarnival_GhostlyRingmaster",
		Name = "Ghostly Ringmaster",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(220, 40, 50),
			ArmsColor = rgb(40, 180, 170),
			LegsColor = rgb(40, 40, 90),
			Accent = { Color = rgb(130, 60, 170), Material = M.Neon, Pattern = { "Belt", "Wings" } },
			Head = "CandyWrapper",
			HeadColor = rgb(130, 60, 170),
			HeadColor2 = rgb(220, 40, 50),
			GlowColor = rgb(255, 210, 50),
		},
	},
	{
		Id = "HauntedCarnival_FortuneTeller",
		Name = "Fortune Teller",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(245, 240, 230),
			Accent = { Color = rgb(255, 140, 40), Pattern = { "Gloves", "Cuffs" } },
			Head = "ClownHead",
			HeadColor = rgb(40, 40, 90),
			HeadColor2 = rgb(255, 210, 50),
			GlowColor = rgb(130, 60, 170),
		},
	},
	{
		Id = "HauntedCarnival_KnifeJuggler",
		Name = "Knife Juggler",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 210, 50),
			ArmsColor = rgb(255, 140, 40),
			LegsColor = rgb(245, 240, 230),
			Accent = { Color = rgb(40, 40, 90), Pattern = { "Wraps", "Buttons" } },
			Head = "ClownHead",
			HeadColor = rgb(245, 240, 230),
			HeadColor2 = rgb(130, 60, 170),
			GlowColor = rgb(40, 40, 90),
		},
	},
	{
		Id = "HauntedCarnival_LaughingMime",
		Name = "Laughing Mime",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(40, 180, 170),
			ArmsColor = rgb(40, 40, 90),
			LegsColor = rgb(255, 210, 50),
			Accent = { Color = rgb(220, 40, 50), Pattern = { "Buttons", "Tail" } },
			Head = "CandyWrapper",
			HeadColor = rgb(40, 180, 170),
			HeadColor2 = rgb(40, 40, 90),
			GlowColor = rgb(245, 240, 230),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "HauntedCarnival_CarnivalPhantom",
		Name = "Carnival Phantom",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(40, 40, 90),
			ArmsColor = rgb(40, 180, 170),
			LegsColor = rgb(220, 40, 50),
			Accent = { Color = rgb(40, 180, 170), Pattern = { "Heart", "Web" } },
			Head = "ClownHead",
			HeadColor = rgb(255, 140, 40),
			HeadColor2 = rgb(220, 40, 50),
			GlowColor = rgb(130, 60, 170),
			Glow = { Color = rgb(130, 60, 170), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(130, 60, 170), Color2 = rgb(245, 240, 230) },
		},
	},
	{
		Id = "HauntedCarnival_GrandRingleader",
		Name = "Grand Ringleader",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(220, 40, 50),
			ArmsColor = rgb(130, 60, 170),
			LegsColor = rgb(245, 240, 230),
			Accent = { Color = rgb(130, 60, 170), Pattern = { "Collar", "Boots" } },
			Head = "GentlemanGourd",
			Face = "Spooky",
			HeadColor = rgb(245, 240, 230),
			HeadColor2 = rgb(40, 180, 170),
			GlowColor = rgb(220, 40, 50),
			Glow = { Color = rgb(220, 40, 50), Brightness = 1.8 },
			Aura = { Kind = "Hearts", Color = rgb(220, 40, 50), Color2 = rgb(130, 60, 170) },
		},
	},
	{
		Id = "HauntedCarnival_MirrorMazeKing",
		Name = "Mirror Maze King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(245, 240, 230),
			ArmsColor = rgb(255, 140, 40),
			LegsColor = rgb(255, 210, 50),
			Accent = { Color = rgb(255, 140, 40), Pattern = { "Boots", "Stitches" } },
			Head = "ClownHead",
			HeadColor = rgb(130, 60, 170),
			HeadColor2 = rgb(40, 40, 90),
			GlowColor = rgb(40, 180, 170),
			Glow = { Color = rgb(40, 180, 170), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(40, 180, 170), Color2 = rgb(220, 40, 50) },
		},
	},
} :: { any }
