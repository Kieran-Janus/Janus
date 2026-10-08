--!strict
--[[
	MAP: Pumpkin Farm (one entry of Config.Maps.List), a Hide & Seek map.

	A cosy harvest farm at sunset: pumpkin fields full of decoy pumpkins, a red barn with a
	hayloft, a corn patch, a farmhouse porch, hay, scarecrows and lanterns. Hiders blend in with
	the decoys; seekers start in the Seeker Hut on the east side.
	Built by src/server/Maps/PumpkinFarm.luau from these settings (or replaced by a Model named
	PumpkinFarm in ServerStorage.Maps). Positions are studs from the middle of the farm
	(x = east, z = south). Move a building by changing its Offset; change how many decoys
	there are with the fields' Rows / PerRow and ExtraDecoys.
]]

return {
	Id = "PumpkinFarm",
	Name = "Pumpkin Farm",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "PumpkinFarm",
	Modes = { "HideSeek" }, -- game modes played on this map (Config.Modes)
	Seed = 3,
	Size = Vector3.new(180, 1, 180),
	WallHeight = 14, -- an invisible wall round the edge (the fence and trees are what you see)
	Spawns = 8, -- hider spawn spots: the first Spawns points of Layout.HiderSpawns
	SpawnRadius = 20, -- (not used: the spots are listed in Layout.HiderSpawns)
	Colors = {
		Floor = Color3.fromRGB(104, 138, 58), -- grass
		Wall = Color3.fromRGB(110, 76, 48),
		Dirt = Color3.fromRGB(118, 82, 52),
		Path = Color3.fromRGB(170, 134, 92),
		Hay = Color3.fromRGB(226, 190, 100),
		Barn = Color3.fromRGB(172, 48, 40),
		Trim = Color3.fromRGB(240, 232, 214),
		Roof = Color3.fromRGB(70, 56, 58),
		House = Color3.fromRGB(236, 222, 190),
		Wood = Color3.fromRGB(110, 74, 46),
		Iron = Color3.fromRGB(46, 40, 44),
		Stone = Color3.fromRGB(150, 146, 140),
		Corn = Color3.fromRGB(150, 160, 70),
		CornTop = Color3.fromRGB(222, 196, 104),
		Vine = Color3.fromRGB(70, 120, 48),
		Cloth = Color3.fromRGB(96, 120, 170),
		Sack = Color3.fromRGB(206, 182, 140),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 196, 110),
		HutWall = Color3.fromRGB(150, 96, 170), -- the Seeker Hut
		HutDoor = Color3.fromRGB(255, 110, 180),
		HutText = Color3.fromRGB(255, 250, 240),
		Leaves = {
			Color3.fromRGB(226, 120, 36),
			Color3.fromRGB(200, 70, 40),
			Color3.fromRGB(238, 176, 52),
			Color3.fromRGB(176, 120, 50),
		},
	},
	Layout = {
		Barn = {
			Offset = Vector3.new(-50, 0, -48),
			Size = Vector3.new(38, 14, 26), -- length (east-west), wall height, width
			DoorWidth = 12, -- big doors at both ends
			LoftHeight = 8, -- the hayloft floor (reached by hay-bale steps inside)
		},
		Farmhouse = {
			Offset = Vector3.new(48, 0, -64),
			Size = Vector3.new(30, 12, 18),
			PorchDepth = 8, -- the porch on its south side
		},
		SeekerHut = {
			Offset = Vector3.new(72, 0, 8),
			Size = Vector3.new(14, 9, 14), -- room inside: width, height, depth
			FacesTowards = Vector3.new(0, 0, 8), -- the door faces this point
			Spawns = 4,
		},
		CornPatch = {
			Offset = Vector3.new(-52, 0, 46),
			Size = Vector3.new(46, 9, 56), -- x, stalk height, z
			RowSpacing = 7,
			GapsPerRow = 2,
			GapWidth = 5,
		},
		-- Rows of decoy pumpkins (the main hiding places).
		PumpkinFields = {
			{
				Offset = Vector3.new(24, 0, 52),
				Size = Vector3.new(60, 0, 44),
				Rows = 7,
				PerRow = 11,
			},
			{
				Offset = Vector3.new(-2, 0, -60),
				Size = Vector3.new(34, 0, 32),
				Rows = 5,
				PerRow = 7,
			},
		},
		MissingChance = 0.15, -- share of row spots left empty (gaps for hiders to fill)
		ExtraDecoys = 26, -- loose decoys round the yard, barn, porch and corn
		-- Dirt paths: pairs of points (x, z).
		Paths = {
			{ Vector2.new(-30, -48), Vector2.new(-26, -48) },
			{ Vector2.new(-26, -48), Vector2.new(-26, 8) },
			{ Vector2.new(-30, 8), Vector2.new(64, 8) },
			{ Vector2.new(48, -44), Vector2.new(30, -16) },
			{ Vector2.new(30, -16), Vector2.new(30, 8) },
			{ Vector2.new(4, 8), Vector2.new(4, 27) },
		},
		HayStacks = 9, -- stacks of hay bales dropped on free spots
		Wheelbarrows = 3,
		BorderTrees = 30,
		Scarecrows = { Vector2.new(8, 46), Vector2.new(40, 64), Vector2.new(-6, -62) },
		Orchard = { Offset = Vector2.new(64, -26), Size = Vector2.new(20, 24), Trees = 6 },
		Tractor = { Position = Vector2.new(-40, -24), FacesTowards = Vector2.new(0, -24) },
		Cart = { Position = Vector2.new(-8, -18), FacesTowards = Vector2.new(10, -18) },
		Pond = { Position = Vector2.new(-58, -10), Radius = 8 },
		Lanterns = {
			Vector2.new(-30.5, -32),
			Vector2.new(-30.5, -8),
			Vector2.new(-12, 12.5),
			Vector2.new(14, 12.5),
			Vector2.new(42, 12.5),
			Vector2.new(54, 14),
			Vector2.new(35, -30),
			Vector2.new(8.5, 22),
			Vector2.new(-24, 14),
			Vector2.new(-14, -36),
		},
		Well = Vector2.new(12, -14),
		-- Where hiders appear (they have HeadStart seconds to run and hide).
		HiderSpawns = {
			Vector2.new(-8, -6),
			Vector2.new(14, 0),
			Vector2.new(-14, 18),
			Vector2.new(20, 22),
			Vector2.new(-36, -4),
			Vector2.new(42, -22),
			Vector2.new(-6, -30),
			Vector2.new(46, 24),
		},
	},
	Lighting = { -- a warm sunset, bright enough that hiders are fairly easy to spot
		ClockTime = 17.4,
		Brightness = 2.1,
		Ambient = Color3.fromRGB(130, 104, 96),
		OutdoorAmbient = Color3.fromRGB(160, 132, 118),
		Atmosphere = {
			Density = 0.28,
			Offset = 0.1,
			Color = Color3.fromRGB(236, 178, 136),
			Decay = Color3.fromRGB(255, 150, 80),
			Glare = 0.4,
			Haze = 1.2,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(255, 240, 225),
		},
		Bloom = { Intensity = 0.45, Size = 26, Threshold = 0.95 },
	},
	Particles = {
		Fireflies = { Rate = 10, Color = Color3.fromRGB(210, 255, 120) },
		Leaves = { Rate = 6, Color = Color3.fromRGB(205, 110, 40) },
	},
	-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.25 },
}
