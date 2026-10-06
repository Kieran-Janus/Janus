--!strict
--[[
	MAP: ScareMaze (one entry of Config.Maps.List), the ScareMaze mode's map: a foggy
	cornfield maze at night. Survivors start in the field in front of the entrance gate
	(south), Haunters in the clearing in the middle, and the glowing exit gate is on the far
	(north) side.

	Built by src/server/Maps/ScareMaze.luau from these settings (or replaced by a Model named
	ScareMaze in ServerStorage.Maps: see docs/CUSTOMIZE.md, "Bake"). The maze fills the floor:
	make Size bigger for a bigger maze, or change Layout.CellSize for wider corridors.
	Change Seed for a different maze (the same seed always gives the same maze).
	Scare traps are parts tagged ScareTrigger (attribute Kind = Scarecrow, Zombie, Bats, Ghost
	or Patrol); the exit is the part tagged MazeExit. Move, resize or copy them in Studio.
]]

return {
	Id = "ScareMaze",
	Name = "ScareMaze",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns", -- the Survivors' start spots (also tagged SurvivorSpawn)
	Builder = "ScareMaze",
	Modes = { "ScareMaze" }, -- game modes played on this map (Config.Modes)
	Seed = 5,
	-- Floor size. The maze fills it: (X - WallThickness) / CellSize columns, and the rows that
	-- fit between the entrance field (PlazaDepth) and the escape yard (YardDepth).
	Size = Vector3.new(198, 1, 205),
	WallHeight = 16, -- the fence around the edge
	Spawns = 16, -- Survivor start spots in the field (more players share them)
	SpawnRadius = 14, -- (not used by this map: the spots are in a grid in front of the gate)
	Colors = {
		Floor = Color3.fromRGB(62, 48, 40), -- dark soil
		Wall = Color3.fromRGB(46, 34, 30), -- the fence around the edge
		Corn = Color3.fromRGB(104, 100, 52), -- dry corn stalks
		CornTop = Color3.fromRGB(78, 92, 44), -- the leafy top of the corn
		Leaf = Color3.fromRGB(122, 124, 60), -- corn leaves sticking out of the walls
		Tassel = Color3.fromRGB(214, 184, 104), -- corn tassels sticking out of the top
		Wood = Color3.fromRGB(86, 60, 42),
		Iron = Color3.fromRGB(40, 38, 46),
		Hay = Color3.fromRGB(214, 176, 92),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(90, 140, 60),
		Glow = Color3.fromRGB(255, 200, 90), -- lanterns and pumpkin faces
		ExitGlow = Color3.fromRGB(120, 255, 150), -- the exit archway
		Sign = Color3.fromRGB(255, 150, 40), -- sign lettering
		Crow = Color3.fromRGB(28, 24, 34),
		Beak = Color3.fromRGB(240, 170, 50),
	},
	Layout = {
		CellSize = 13, -- studs from one corridor's middle to the next
		WallThickness = 3, -- corridors are CellSize - WallThickness wide (10)
		CornHeight = 12, -- how tall the corn walls are (too tall to jump or see over)
		Braid = 0.25, -- 0 = one single way through; higher = more loops (easier, better chases)
		PlazaDepth = 26, -- the field in front of the entrance where Survivors start (south)
		YardDepth = 20, -- the escape yard behind the exit gate (north)
		-- Maze column of the entrance and the exit gate: 1 = the west side, negative = counted
		-- from the east, 0 = whichever makes the longest way through the maze.
		EntranceColumn = 0,
		ExitColumn = 0,
		Clearing = 2, -- the open clearing in the middle where Haunters start (cells across, 0 = none)
		HauntSpawns = 6, -- Haunter start spots (in the clearing, then deep in the maze)
		Traps = 16, -- scare traps (Scarecrow, Zombie, Bats, Ghost), spread along the way out...
		RouteTrapShare = 0.65, -- ...this share right on the way out, the rest in side paths
		TrapKinds = { "Scarecrow", "Zombie", "Bats", "Ghost" },
		TrapSpacing = 3, -- at least this many cells between two traps
		Patrols = 4, -- scarecrows that walk up and down straight corridors
		PatrolMinCells = 3, -- a patrol walks a straight corridor at least this many cells long...
		PatrolMaxCells = 4, -- ...and at most this many
		LanternEvery = 3, -- a lantern every this-many cells along the way out
		SideLanterns = 5, -- extra lanterns in side paths (fewer = the way out is easier to spot)
		TasselSpacing = 5, -- studs between corn tassels on the wall tops
		LeafSpacing = 7, -- studs between corn leaves sticking out of the walls (0 = none)
		Pumpkins = 22, -- pumpkins in dead ends and around the field
		GlowingPumpkins = 6, -- how many of them are lit jack-o'-lanterns
		Crows = 14, -- crows sitting on the corn
		DeadTrees = 6, -- spooky trees in the field and the yard
		HayBales = 8,
		GateText = "SCAREMAZE", -- the sign over the entrance
		GateSubText = "DON'T STOP MOVING",
		ExitText = "EXIT",
		YardText = "YOU ESCAPED!",
	},
	Lighting = { -- dark and foggy, but never pitch black
		ClockTime = 23,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(80, 66, 105),
		OutdoorAmbient = Color3.fromRGB(95, 80, 125),
		Atmosphere = {
			Density = 0.5,
			Offset = 0.15,
			Color = Color3.fromRGB(95, 82, 130),
			Decay = Color3.fromRGB(70, 55, 110),
			Glare = 0,
			Haze = 2.4,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.15,
			Saturation = 0,
			TintColor = Color3.fromRGB(235, 225, 255),
		},
		Bloom = { Intensity = 0.9, Size = 26, Threshold = 0.88 },
	},
	Particles = {
		Mist = { Rate = 12, Color = Color3.fromRGB(170, 155, 205) },
		Wisps = { Rate = 4, Color = Color3.fromRGB(160, 255, 190) },
	},
	-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
}
