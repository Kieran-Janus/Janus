--!strict
--[[
	MAP: Hedge Maze (one entry of Config.Maps.List), a Hide & Seek map.

	A moonlit garden maze of tall rounded hedges with a fountain plaza in the middle. Decoy
	pumpkins sit in the dead ends and corners; the Seeker Hut is in a corner room.
	Built by src/server/Maps/HedgeMaze.luau from these settings (or replaced by a Model named
	HedgeMaze in ServerStorage.Maps). The maze itself comes from src/server/Maps/MazeGen.luau:
	change Seed for a different maze, Braid for more or fewer loops (0 = one way between any two
	spots, 1 = lots of loops), Cells / CellSize for a bigger or smaller maze.
]]

return {
	Id = "HedgeMaze",
	Name = "Hedge Maze",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "HedgeMaze",
	Modes = { "HideSeek" }, -- game modes played on this map (Config.Modes)
	Seed = 4,
	Size = Vector3.new(164, 1, 164), -- keep it a little bigger than Cells x CellSize
	WallHeight = 14, -- an invisible wall round the edge (the outer hedge is what you see)
	Spawns = 10, -- hider spawn spots, spread over the maze away from the Seeker Hut
	SpawnRadius = 20, -- (not used: the maze picks the spots)
	Colors = {
		Floor = Color3.fromRGB(150, 140, 120), -- gravel paths
		Wall = Color3.fromRGB(34, 72, 40),
		Hedge = Color3.fromRGB(52, 104, 56),
		HedgeTop = Color3.fromRGB(70, 130, 66),
		Stone = Color3.fromRGB(176, 172, 180),
		Paving = Color3.fromRGB(150, 146, 156),
		Water = Color3.fromRGB(90, 170, 210),
		Wood = Color3.fromRGB(120, 82, 52),
		Iron = Color3.fromRGB(40, 38, 46),
		Pot = Color3.fromRGB(176, 96, 64),
		Roof = Color3.fromRGB(60, 52, 70),
		Trim = Color3.fromRGB(240, 232, 214),
		Flowers = {
			Color3.fromRGB(255, 120, 170),
			Color3.fromRGB(255, 220, 90),
			Color3.fromRGB(180, 130, 255),
			Color3.fromRGB(255, 255, 255),
		},
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 196, 110),
		HutWall = Color3.fromRGB(150, 96, 170), -- the Seeker Hut
		HutDoor = Color3.fromRGB(255, 110, 180),
		HutText = Color3.fromRGB(255, 250, 240),
	},
	Layout = {
		Cells = 13, -- the maze is Cells x Cells
		CellSize = 12, -- studs per cell (corridors are CellSize - HedgeThickness wide)
		HedgeHeight = 10, -- taller than anyone can jump
		HedgeThickness = 3,
		Braid = 0.4,
		-- Open rooms in the maze, in cells (X = column from the west, Y = row from the north).
		Plaza = { X = 6, Y = 6, W = 3, H = 3 }, -- the fountain plaza in the middle
		HutRoom = { X = 12, Y = 1, W = 2, H = 2 }, -- the Seeker Hut's garden (north-east)
		HutSize = Vector3.new(12, 9, 12), -- room inside the hut: width, height, depth
		HutSpawns = 4,
		DecoysPerDeadEnd = 2, -- decoy pumpkins at the closed end of each dead end
		CorridorDecoys = 14, -- more decoys along the paths
		PlazaDecoys = 6,
		LanternGrid = 3, -- a lamp post in every 3rd cell across and down
		FlowerPatches = 24,
		RoseChance = 0.35, -- share of hedges with little roses on them
		Arches = 8, -- white garden arches over gaps between two hedge ends
	},
	Lighting = { -- moonlit twilight, with warm lamps, so hiders can still be found
		ClockTime = 19.6,
		Brightness = 2,
		Ambient = Color3.fromRGB(110, 104, 140),
		OutdoorAmbient = Color3.fromRGB(140, 134, 176),
		Atmosphere = {
			Density = 0.32,
			Offset = 0.1,
			Color = Color3.fromRGB(150, 150, 196),
			Decay = Color3.fromRGB(120, 150, 170),
			Glare = 0.2,
			Haze = 1.3,
		},
		ColorCorrection = {
			Brightness = 0.06,
			Contrast = 0.1,
			Saturation = 0.15,
			TintColor = Color3.fromRGB(240, 242, 255),
		},
		Bloom = { Intensity = 0.7, Size = 26, Threshold = 0.9 },
	},
	Particles = {
		Fireflies = { Rate = 12, Color = Color3.fromRGB(210, 255, 120) },
		Mist = { Rate = 6, Color = Color3.fromRGB(180, 200, 220) },
	},
	-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.25 },
}
