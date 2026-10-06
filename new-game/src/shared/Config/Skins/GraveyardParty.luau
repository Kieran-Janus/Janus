--!strict
--[[
	GRAVEYARD PARTY CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (GraveyardPartyCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "GraveyardParty_PartyGhoul",
		Name = "Party Ghoul",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(70, 150, 255),
			LegsColor = rgb(30, 30, 35),
			Accent = { Color = rgb(150, 240, 80), Pattern = "Belly" },
		},
	},
	{
		Id = "GraveyardParty_BalloonGhost",
		Name = "Balloon Ghost",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 110, 190),
			ArmsColor = rgb(70, 150, 255),
			LegsColor = rgb(235, 230, 215),
			Material = M.Fabric,
			Accent = { Color = rgb(235, 230, 215), Pattern = "Stitches" },
		},
	},
	{
		Id = "GraveyardParty_ConfettiSkull",
		Name = "Confetti Skull",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 220, 60),
			ArmsColor = rgb(235, 230, 215),
			LegsColor = rgb(255, 110, 190),
			Material = M.Foil,
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Cape", "Spots" } },
		},
	},
	{
		Id = "GraveyardParty_DancingBones",
		Name = "Dancing Bones",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(70, 150, 255),
			Material = M.Granite,
			Accent = { Color = rgb(130, 130, 135), Pattern = "Web" },
		},
	},
	{
		Id = "GraveyardParty_CakeZombie",
		Name = "Cake Zombie",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(150, 240, 80),
			ArmsColor = rgb(130, 130, 135),
			LegsColor = rgb(70, 150, 255),
			Accent = { Color = rgb(255, 110, 190), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "GraveyardParty_StreamerSpook",
		Name = "Streamer Spook",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 230, 215),
			ArmsColor = rgb(130, 130, 135),
			LegsColor = rgb(255, 220, 60),
			Material = M.Fabric,
			Accent = { Color = rgb(255, 220, 60), Pattern = { "Gloves", "Belly" } },
		},
	},
	{
		Id = "GraveyardParty_TombstoneDJ",
		Name = "Tombstone DJ",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(255, 220, 60),
			LegsColor = rgb(235, 230, 215),
			Material = M.Foil,
			Accent = { Color = rgb(70, 150, 255), Pattern = "Wraps" },
		},
	},
	{
		Id = "GraveyardParty_PunchBowl",
		Name = "Punch Bowl",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(130, 130, 135),
			Material = M.Granite,
			Accent = { Color = rgb(150, 240, 80), Pattern = "Buttons" },
		},
	},
	{
		Id = "GraveyardParty_LimboSkeleton",
		Name = "Limbo Skeleton",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 110, 190),
			ArmsColor = rgb(150, 240, 80),
			LegsColor = rgb(130, 130, 135),
			Accent = { Color = rgb(235, 230, 215), Pattern = { "Patches", "Buttons" } },
		},
	},
	{
		Id = "GraveyardParty_PartyPopper",
		Name = "Party Popper",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(255, 220, 60),
			ArmsColor = rgb(150, 240, 80),
			LegsColor = rgb(30, 30, 35),
			Material = M.Fabric,
			Accent = { Color = rgb(30, 30, 35), Material = M.Neon, Pattern = "Wings" },
		},
	},
	{
		Id = "GraveyardParty_DiscoGrave",
		Name = "Disco Grave",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(70, 150, 255),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(255, 220, 60),
			Material = M.Foil,
			Accent = { Color = rgb(130, 130, 135), Pattern = "Heart" },
		},
	},
	{
		Id = "GraveyardParty_PinataGhost",
		Name = "Pinata Ghost",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(150, 240, 80),
			Material = M.Granite,
			Accent = { Color = rgb(255, 110, 190), Pattern = { "Collar", "Bones" } },
		},
	},
	{
		Id = "GraveyardParty_GraveRaver",
		Name = "Grave Raver",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(235, 230, 215),
			ArmsColor = rgb(255, 110, 190),
			LegsColor = rgb(150, 240, 80),
			Accent = { Color = rgb(255, 220, 60), Pattern = "Boots" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "GraveyardParty_PartySkeleton",
		Name = "Party Skeleton",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(255, 220, 60),
			LegsColor = rgb(235, 230, 215),
			Accent = { Color = rgb(70, 150, 255), Pattern = { "Spots", "Boots" } },
			Head = "PartyHat",
			HeadColor = rgb(255, 220, 60),
			HeadColor2 = rgb(235, 230, 215),
			GlowColor = rgb(130, 130, 135),
		},
	},
	{
		Id = "GraveyardParty_TombstoneJoker",
		Name = "Tombstone Joker",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(70, 150, 255),
			LegsColor = rgb(30, 30, 35),
			Accent = {
				Color = rgb(150, 240, 80),
				Material = M.Neon,
				Pattern = { "Bones", "Stitches" },
			},
			Head = "TombstoneHead",
			HeadColor = rgb(150, 240, 80),
			HeadColor2 = rgb(130, 130, 135),
			GlowColor = rgb(255, 220, 60),
		},
	},
	{
		Id = "GraveyardParty_BirthdayBones",
		Name = "Birthday Bones",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(255, 110, 190),
			Accent = { Color = rgb(235, 230, 215), Pattern = { "Sash", "Heart" } },
			Head = "SkinSkull",
			HeadColor = rgb(30, 30, 35),
			HeadColor2 = rgb(255, 220, 60),
			GlowColor = rgb(150, 240, 80),
		},
	},
	{
		Id = "GraveyardParty_PartyAnimal",
		Name = "Party Animal",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(255, 220, 60),
			ArmsColor = rgb(235, 230, 215),
			LegsColor = rgb(255, 110, 190),
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Tail", "Stripes" } },
			Head = "PartyHat",
			HeadColor = rgb(255, 110, 190),
			HeadColor2 = rgb(150, 240, 80),
			GlowColor = rgb(30, 30, 35),
		},
	},
	{
		Id = "GraveyardParty_GraveyardHost",
		Name = "Graveyard Host",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(70, 150, 255),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(255, 220, 60),
			Accent = { Color = rgb(130, 130, 135), Pattern = { "Star", "Patches" } },
			Head = "TombstoneHead",
			HeadColor = rgb(70, 150, 255),
			HeadColor2 = rgb(30, 30, 35),
			GlowColor = rgb(255, 110, 190),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "GraveyardParty_PartyKing",
		Name = "Party King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(70, 150, 255),
			LegsColor = rgb(130, 130, 135),
			Accent = { Color = rgb(70, 150, 255), Pattern = { "Belly", "Sash" } },
			Head = "PartyHat",
			HeadColor = rgb(235, 230, 215),
			HeadColor2 = rgb(130, 130, 135),
			GlowColor = rgb(150, 240, 80),
			Glow = { Color = rgb(150, 240, 80), Brightness = 1.6 },
			Aura = { Kind = "Stars", Color = rgb(150, 240, 80), Color2 = rgb(255, 110, 190) },
		},
	},
	{
		Id = "GraveyardParty_EternalPartier",
		Name = "Eternal Partier",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(130, 130, 135),
			ArmsColor = rgb(150, 240, 80),
			LegsColor = rgb(255, 110, 190),
			Accent = { Color = rgb(150, 240, 80), Pattern = { "Stitches", "Belt" } },
			Head = "TombstoneHead",
			HeadColor = rgb(255, 110, 190),
			HeadColor2 = rgb(70, 150, 255),
			GlowColor = rgb(130, 130, 135),
			Glow = { Color = rgb(130, 130, 135), Brightness = 1.8 },
			Aura = { Kind = "Hearts", Color = rgb(130, 130, 135), Color2 = rgb(150, 240, 80) },
		},
	},
	{
		Id = "GraveyardParty_RaveReaper",
		Name = "Rave Reaper",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(255, 110, 190),
			ArmsColor = rgb(235, 230, 215),
			LegsColor = rgb(255, 220, 60),
			Accent = { Color = rgb(235, 230, 215), Pattern = { "Cape", "Spots" } },
			Head = "PartyHat",
			HeadColor = rgb(150, 240, 80),
			HeadColor2 = rgb(30, 30, 35),
			GlowColor = rgb(70, 150, 255),
			Glow = { Color = rgb(70, 150, 255), Brightness = 2.0 },
			Aura = { Kind = "Sparkles", Color = rgb(70, 150, 255), Color2 = rgb(130, 130, 135) },
		},
	},
} :: { any }
