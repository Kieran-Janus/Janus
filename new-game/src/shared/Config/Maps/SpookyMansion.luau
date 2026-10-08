--!strict
--[[
	MAP: Spooky Mansion (one entry of Config.Maps.List)

	Built by src/server/Maps/SpookyMansion.luau from these settings (or replaced by a Model
	named SpookyMansion in ServerStorage.Maps). Change the rooms, colours, lighting or
	sound here. Modes lists the game modes this map is used for.
]]

return {
	Id = "SpookyMansion",
	Name = "Spooky Mansion",
	Thumbnail = 0,
	SpawnFolder = "Spawns",
	Builder = "SpookyMansion",
	Modes = { "KingHunt" }, -- game modes played on this map (Config.Modes)
	Seed = 2,
	Size = Vector3.new(180, 1, 180),
	WallHeight = 20, -- outer walls; the roof caved in long ago
	Spawns = 8,
	SpawnRadius = 16,
	Colors = {
		Floor = Color3.fromRGB(96, 66, 50),
		OuterWall = Color3.fromRGB(70, 62, 82),
		Wall = Color3.fromRGB(88, 60, 110),
		Trim = Color3.fromRGB(50, 34, 40),
		Rug = Color3.fromRGB(140, 30, 50),
		RugAlt = Color3.fromRGB(60, 40, 120),
		Wood = Color3.fromRGB(80, 50, 34),
		DarkWood = Color3.fromRGB(48, 30, 24),
		Gold = Color3.fromRGB(230, 180, 70),
		Stone = Color3.fromRGB(120, 118, 128),
		Curtain = Color3.fromRGB(110, 20, 40),
		Plant = Color3.fromRGB(50, 80, 50),
		Bone = Color3.fromRGB(235, 228, 210),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 200, 90),
		Slime = Color3.fromRGB(120, 255, 110), -- also the portraits' glowing eyes
		Moon = Color3.fromRGB(70, 95, 170), -- the moonlit windows on the outside walls
		Panel = Color3.fromRGB(120, 78, 52), -- the wood panelling along the bottom of the inside walls
	},
	Layout = {
		-- A 3x3 grid of rooms, listed north-west to south-east. The middle one is
		-- where everyone spawns. Every neighbouring pair of rooms shares a doorway.
		Rooms = {
			"Library",
			"Gallery",
			"Bedroom",
			"Dining",
			"GrandHall",
			"Kitchen",
			"Conservatory",
			"Ballroom",
			"Crypt",
		},
		WallHeight = 16, -- inside walls
		WallThickness = 2,
		PanelHeight = 4, -- the dark wood panelling along the bottom of every inside wall
		DoorWidth = 12,
		DoorHeight = 11,
		-- Extra gaps hidden behind a fake bookcase: players walk through, the King
		-- can't path through them (PathfindingModifier label "SecretDoor").
		SecretDoors = 3,
		SecretDoorWidth = 6,
		Hotspots = { "Ballroom", "Dining" }, -- rooms where extra pumpkins appear
	},
	Lighting = {
		ClockTime = 22,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(95, 70, 120),
		OutdoorAmbient = Color3.fromRGB(105, 85, 135),
		Atmosphere = {
			Density = 0.36,
			Offset = 0.2,
			Color = Color3.fromRGB(110, 90, 150),
			Decay = Color3.fromRGB(90, 60, 140),
			Glare = 0,
			Haze = 1.4,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.15,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(245, 230, 255),
		},
		Bloom = { Intensity = 0.6, Size = 26, Threshold = 0.88 },
	},
	Particles = {
		Dust = { Rate = 10, Color = Color3.fromRGB(230, 220, 200) },
		Wisps = { Rate = 5, Color = Color3.fromRGB(150, 220, 255) },
		Mist = { Rate = 5, Color = Color3.fromRGB(170, 150, 210) },
	},
	-- The haunted portraits (src/server/Build/Portrait.luau): painted figures whose eyes follow
	-- you. Put picture codes here to hang your own pictures instead, taking turns round the
	-- house: Images = { "rbxassetid://123456789" }. It must be the IMAGE id: insert the decal
	-- in Studio (Toolbox), select it and copy the number in its Texture property. The eyes only
	-- move on the painted figures.
	Paintings = { Images = {} :: { string } },
	-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
}
