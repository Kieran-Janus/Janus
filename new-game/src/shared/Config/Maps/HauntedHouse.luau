--!strict
--[[
	MAP: The Haunted House (one entry of Config.Maps.List), the Prop Hunt map.

	Built by src/server/Maps/HauntedHouse.luau from these settings (or replaced by a Model named
	HauntedHouse in ServerStorage.Maps). A creepy mansion (six rooms downstairs, an attic and a
	nursery upstairs up the ramp in the stair hall) in an overgrown yard with a graveyard, a
	pumpkin patch, dead trees and the Finder Hut. Everything hiders can turn into is spread
	about at random from Seed: change Seed for a new layout, or the counts in Layout.Props for
	more or fewer things. Colours, lighting and sound are here too.
]]

return {
	Id = "HauntedHouse",
	Name = "The Haunted House",
	Thumbnail = 0,
	SpawnFolder = "Spawns",
	Builder = "HauntedHouse",
	Modes = { "PropHunt" }, -- game modes played on this map (Config.Modes)
	Seed = 41, -- change it for a different spread of things
	Size = Vector3.new(200, 1, 200),
	WallHeight = 20, -- the walls round the edge of the yard
	Spawns = 12, -- hider spawns (in the rooms and round the yard)
	SpawnRadius = 30,
	Colors = {
		Floor = Color3.fromRGB(58, 70, 46), -- the overgrown yard
		Wall = Color3.fromRGB(46, 40, 54), -- the yard's edge wall
		HouseWall = Color3.fromRGB(78, 62, 92),
		HouseTrim = Color3.fromRGB(44, 30, 40),
		Boards = Color3.fromRGB(92, 64, 46), -- the house's floorboards
		Panel = Color3.fromRGB(110, 72, 50),
		Rug = Color3.fromRGB(130, 30, 50),
		RugAlt = Color3.fromRGB(60, 40, 120),
		Wood = Color3.fromRGB(96, 64, 42),
		DarkWood = Color3.fromRGB(52, 34, 26),
		Iron = Color3.fromRGB(40, 38, 46),
		Stone = Color3.fromRGB(128, 126, 136),
		Bone = Color3.fromRGB(235, 228, 210),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(90, 140, 60),
		Glow = Color3.fromRGB(255, 200, 90),
		Slime = Color3.fromRGB(120, 255, 110),
		Potion = Color3.fromRGB(190, 90, 255),
		Hay = Color3.fromRGB(214, 180, 96),
		Path = Color3.fromRGB(110, 104, 98),
		Window = Color3.fromRGB(150, 110, 255),
		HutWall = Color3.fromRGB(70, 46, 80),
		HutDoor = Color3.fromRGB(255, 130, 20),
		HutText = Color3.fromRGB(255, 230, 160),
		Roof = Color3.fromRGB(40, 30, 50),
	},
	Layout = {
		-- The mansion (map offset of its middle; Width along X, Depth along Z).
		House = {
			Offset = Vector3.new(0, 0, -22),
			Width = 72,
			Depth = 52,
			WallHeight = 14, -- downstairs walls (the upstairs floor sits on top of them)
			UpperWallHeight = 8, -- the attic and nursery walls
			DoorWidth = 10,
			DoorHeight = 11,
		},
		-- Where the finders wait during the head start (door opens when they are let out).
		FinderHut = {
			Offset = Vector3.new(0, 0, 80),
			FacesTowards = Vector3.new(0, 0, 0),
			Size = Vector3.new(14, 9, 10), -- inside: width, wall height, depth
			Spawns = 4,
		},
		Graveyard = { Offset = Vector3.new(-62, 0, 40), Size = Vector3.new(44, 0, 40), Graves = 14 },
		PumpkinPatch = {
			Offset = Vector3.new(62, 0, 40),
			Size = Vector3.new(40, 0, 36),
			Pumpkins = 16,
		},
		-- Things hiders can become, spread at random (Seed) on free spots.
		Props = {
			PerRoom = 10, -- in each downstairs room
			Upstairs = 9, -- in the attic and in the nursery
			Yard = 72, -- round the yard
		},
		DeadTrees = 12,
		Lampposts = 4, -- along the path from the Finder Hut to the front door
		Bats = 6,
	},
	Lighting = {
		ClockTime = 21.5,
		Brightness = 1.5,
		Ambient = Color3.fromRGB(104, 88, 120),
		OutdoorAmbient = Color3.fromRGB(128, 110, 150),
		Atmosphere = {
			Density = 0.3,
			Offset = 0.1,
			Color = Color3.fromRGB(140, 110, 170),
			Decay = Color3.fromRGB(255, 150, 90),
			Glare = 0.1,
			Haze = 1.2,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.1,
			Saturation = 0.18,
			TintColor = Color3.fromRGB(255, 240, 235),
		},
		Bloom = { Intensity = 0.55, Size = 26, Threshold = 0.9 },
	},
	Particles = {
		Mist = { Rate = 5, Color = Color3.fromRGB(170, 150, 210) },
		Wisps = { Rate = 4, Color = Color3.fromRGB(150, 220, 255) },
	},
	-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
}
