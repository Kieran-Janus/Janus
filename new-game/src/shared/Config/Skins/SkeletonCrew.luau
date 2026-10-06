--!strict
--[[
	SKELETON CREW CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.
	Change a Name or any Style value freely. NEVER change an Id (it is saved in players' data).
	Slot, Crate (SkeletonCrewCrate) and Style.Kind are filled in by init.luau. Every Style option is
	listed at the top of Pumpkin.luau.
]]

local rgb = Color3.fromRGB
local M = Enum.Material

return {
	-- COMMON -------------------------------------------------------------------------------
	{
		Id = "SkeletonCrew_BoneRower",
		Name = "Bone Rower",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(240, 235, 215),
			ArmsColor = rgb(230, 190, 70),
			LegsColor = rgb(120, 120, 125),
			Accent = { Color = rgb(40, 50, 100), Pattern = "Sash" },
		},
	},
	{
		Id = "SkeletonCrew_RibCage",
		Name = "Rib Cage",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(230, 190, 70),
			LegsColor = rgb(200, 180, 130),
			Material = M.Fabric,
			Accent = { Color = rgb(200, 180, 130), Pattern = "Tail" },
		},
	},
	{
		Id = "SkeletonCrew_SkullSwabber",
		Name = "Skull Swabber",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 40, 40),
			ArmsColor = rgb(200, 180, 130),
			LegsColor = rgb(30, 30, 35),
			Material = M.Marble,
			Accent = { Color = rgb(120, 120, 125), Pattern = { "Star", "Stripes" } },
		},
	},
	{
		Id = "SkeletonCrew_FemurFighter",
		Name = "Femur Fighter",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(230, 190, 70),
			Material = M.Limestone,
			Accent = { Color = rgb(240, 235, 215), Pattern = "Cuffs" },
		},
	},
	{
		Id = "SkeletonCrew_RattlingRecruit",
		Name = "Rattling Recruit",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(40, 50, 100),
			ArmsColor = rgb(240, 235, 215),
			LegsColor = rgb(230, 190, 70),
			Accent = { Color = rgb(30, 30, 35), Material = M.Neon, Pattern = "Stripes" },
		},
	},
	{
		Id = "SkeletonCrew_BonyBoatswain",
		Name = "Bony Boatswain",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 180, 130),
			ArmsColor = rgb(240, 235, 215),
			LegsColor = rgb(190, 40, 40),
			Material = M.Fabric,
			Accent = { Color = rgb(190, 40, 40), Pattern = { "Belly", "Wraps" } },
		},
	},
	{
		Id = "SkeletonCrew_GrinningGunner",
		Name = "Grinning Gunner",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(120, 120, 125),
			ArmsColor = rgb(190, 40, 40),
			LegsColor = rgb(200, 180, 130),
			Material = M.Marble,
			Accent = { Color = rgb(230, 190, 70), Pattern = "Stitches" },
		},
	},
	{
		Id = "SkeletonCrew_CalciumCook",
		Name = "Calcium Cook",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(240, 235, 215),
			Material = M.Limestone,
			Accent = { Color = rgb(40, 50, 100), Pattern = "Cape" },
		},
	},
	{
		Id = "SkeletonCrew_MarrowMate",
		Name = "Marrow Mate",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(40, 50, 100),
			LegsColor = rgb(240, 235, 215),
			Accent = { Color = rgb(200, 180, 130), Pattern = { "Web", "Spots" } },
		},
	},
	{
		Id = "SkeletonCrew_JawboneJack",
		Name = "Jawbone Jack",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(190, 40, 40),
			ArmsColor = rgb(40, 50, 100),
			LegsColor = rgb(120, 120, 125),
			Material = M.Fabric,
			Accent = { Color = rgb(120, 120, 125), Material = M.Neon, Pattern = "Belt" },
		},
	},
	{
		Id = "SkeletonCrew_SpineSailor",
		Name = "Spine Sailor",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(230, 190, 70),
			ArmsColor = rgb(120, 120, 125),
			LegsColor = rgb(190, 40, 40),
			Material = M.Marble,
			Accent = { Color = rgb(240, 235, 215), Pattern = "Gloves" },
		},
	},
	{
		Id = "SkeletonCrew_KnuckleKnot",
		Name = "Knuckle Knot",
		Rarity = "Common",
		Style = {
			BodyColor = rgb(40, 50, 100),
			Material = M.Limestone,
			Accent = { Color = rgb(30, 30, 35), Pattern = { "Wraps", "Belly" } },
		},
	},
	{
		Id = "SkeletonCrew_PelvisPete",
		Name = "Pelvis Pete",
		Rarity = "Common",
		Style = {
			TorsoColor = rgb(200, 180, 130),
			ArmsColor = rgb(30, 30, 35),
			LegsColor = rgb(40, 50, 100),
			Accent = { Color = rgb(190, 40, 40), Pattern = "Buttons" },
		},
	},

	-- UNCOMMON (a head piece) ------------------------------------------------------------
	{
		Id = "SkeletonCrew_SkeletonCaptain",
		Name = "Skeleton Captain",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(120, 120, 125),
			ArmsColor = rgb(190, 40, 40),
			LegsColor = rgb(200, 180, 130),
			Accent = { Color = rgb(230, 190, 70), Pattern = { "Patches", "Cuffs" } },
			Head = "SkinSkull",
			HeadColor = rgb(190, 40, 40),
			HeadColor2 = rgb(200, 180, 130),
			GlowColor = rgb(240, 235, 215),
		},
	},
	{
		Id = "SkeletonCrew_BonePirate",
		Name = "Bone Pirate",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(240, 235, 215),
			ArmsColor = rgb(230, 190, 70),
			LegsColor = rgb(120, 120, 125),
			Accent = {
				Color = rgb(40, 50, 100),
				Material = M.Neon,
				Pattern = { "Wings", "Buttons" },
			},
			Head = "CaptainHat",
			HeadColor = rgb(40, 50, 100),
			HeadColor2 = rgb(240, 235, 215),
			GlowColor = rgb(190, 40, 40),
		},
	},
	{
		Id = "SkeletonCrew_DeadeyeSkull",
		Name = "Deadeye Skull",
		Rarity = "Uncommon",
		Style = {
			BodyColor = rgb(30, 30, 35),
			Accent = { Color = rgb(200, 180, 130), Pattern = { "Heart", "Tail" } },
			Head = "CandySkull",
			HeadColor = rgb(120, 120, 125),
			HeadColor2 = rgb(190, 40, 40),
			GlowColor = rgb(40, 50, 100),
		},
	},
	{
		Id = "SkeletonCrew_Rattlebones",
		Name = "Rattlebones",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(190, 40, 40),
			ArmsColor = rgb(200, 180, 130),
			LegsColor = rgb(30, 30, 35),
			Accent = { Color = rgb(120, 120, 125), Pattern = { "Collar", "Gloves" } },
			Head = "SkinSkull",
			HeadColor = rgb(30, 30, 35),
			HeadColor2 = rgb(40, 50, 100),
			GlowColor = rgb(120, 120, 125),
		},
	},
	{
		Id = "SkeletonCrew_GrimQuartermaster",
		Name = "Grim Quartermaster",
		Rarity = "Uncommon",
		Style = {
			TorsoColor = rgb(230, 190, 70),
			ArmsColor = rgb(120, 120, 125),
			LegsColor = rgb(190, 40, 40),
			Accent = { Color = rgb(240, 235, 215), Pattern = { "Boots", "Bones" } },
			Head = "CaptainHat",
			HeadColor = rgb(230, 190, 70),
			HeadColor2 = rgb(120, 120, 125),
			GlowColor = rgb(30, 30, 35),
		},
	},

	-- RARE (head piece, glow and particles) --------------------------------------------
	{
		Id = "SkeletonCrew_SkeletonKing",
		Name = "Skeleton King",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(120, 120, 125),
			ArmsColor = rgb(230, 190, 70),
			LegsColor = rgb(240, 235, 215),
			Accent = { Color = rgb(230, 190, 70), Pattern = { "Sash", "Stitches" } },
			Head = "SkinSkull",
			HeadColor = rgb(200, 180, 130),
			HeadColor2 = rgb(240, 235, 215),
			GlowColor = rgb(40, 50, 100),
			Glow = { Color = rgb(40, 50, 100), Brightness = 1.6 },
			Aura = { Kind = "Sparkles", Color = rgb(40, 50, 100), Color2 = rgb(30, 30, 35) },
		},
	},
	{
		Id = "SkeletonCrew_GoldenBones",
		Name = "Golden Bones",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(240, 235, 215),
			ArmsColor = rgb(40, 50, 100),
			LegsColor = rgb(30, 30, 35),
			Accent = { Color = rgb(40, 50, 100), Pattern = { "Tail", "Heart" } },
			Head = "CandySkull",
			HeadColor = rgb(30, 30, 35),
			HeadColor2 = rgb(230, 190, 70),
			GlowColor = rgb(240, 235, 215),
			Glow = { Color = rgb(240, 235, 215), Brightness = 1.8 },
			Aura = { Kind = "Smoke", Color = rgb(240, 235, 215), Color2 = rgb(40, 50, 100) },
		},
	},
	{
		Id = "SkeletonCrew_GhostFleetCommander",
		Name = "Ghost Fleet Commander",
		Rarity = "Rare",
		Style = {
			TorsoColor = rgb(30, 30, 35),
			ArmsColor = rgb(200, 180, 130),
			LegsColor = rgb(190, 40, 40),
			Accent = { Color = rgb(200, 180, 130), Pattern = { "Star", "Stripes" } },
			Head = "CaptainHat",
			HeadColor = rgb(40, 50, 100),
			HeadColor2 = rgb(120, 120, 125),
			GlowColor = rgb(230, 190, 70),
			Glow = { Color = rgb(230, 190, 70), Brightness = 2.0 },
			Aura = { Kind = "Stars", Color = rgb(230, 190, 70), Color2 = rgb(240, 235, 215) },
		},
	},
} :: { any }
