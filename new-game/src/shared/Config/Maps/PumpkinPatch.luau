--!strict
--[[
	MAP: Haunted Pumpkin Patch (one entry of Config.Maps.List)

	Built by src/server/Maps/PumpkinPatch.luau from these settings (or replaced by a Model
	named PumpkinPatch in ServerStorage.Maps). Change Size, Colors, Layout counts, Lighting
	or AmbientSound here. Modes lists the game modes this map is used for.
]]

return {
	Id = "PumpkinPatch",
	Name = "Haunted Pumpkin Patch",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "PumpkinPatch",
	Modes = { "KingHunt" }, -- game modes played on this map (Config.Modes)
	Seed = 1,
	Size = Vector3.new(220, 1, 220),
	WallHeight = 14, -- the thorny hedge around the edge
	Spawns = 8,
	SpawnRadius = 20,
	Colors = {
		Grass = Color3.fromRGB(62, 92, 44),
		Dirt = Color3.fromRGB(92, 64, 42),
		Hedge = Color3.fromRGB(32, 52, 34),
		Corn = Color3.fromRGB(176, 160, 70),
		CornTop = Color3.fromRGB(214, 190, 90),
		Hay = Color3.fromRGB(222, 184, 92),
		Barn = Color3.fromRGB(150, 42, 40),
		Roof = Color3.fromRGB(70, 44, 40),
		Wood = Color3.fromRGB(92, 62, 40),
		Stone = Color3.fromRGB(120, 118, 128),
		Iron = Color3.fromRGB(35, 32, 40),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 200, 90),
		Bone = Color3.fromRGB(235, 228, 210),
	},
	-- Offsets are from the map centre (x, z); the spawn clearing is in the middle.
	Layout = {
		ClearingRadius = 30, -- nothing big is placed here
		PathWidth = 7, -- the dirt paths from the clearing out to each area
		CornMaze = { -- tall rows block the King's view; gaps are the way through
			Offset = Vector3.new(58, 0, -58),
			Size = Vector3.new(76, 10, 76), -- y = stalk height
			RowSpacing = 9,
			GapsPerRow = 2,
			GapWidth = 6,
		},
		Barn = { -- doors at both ends make it a shortcut; hay inside to hide in
			Offset = Vector3.new(-60, 0, -58),
			Size = Vector3.new(30, 16, 40),
			DoorWidth = 12,
			DoorHeight = 12,
		},
		Field = { -- open pumpkin rows: lots of pumpkins, nowhere to hide (risky)
			Offset = Vector3.new(-58, 0, 58),
			Size = Vector3.new(70, 0, 56),
			Rows = 6,
			DecorPumpkinsPerRow = 7,
		},
		Graveyard = {
			Offset = Vector3.new(58, 0, 58),
			Size = Vector3.new(60, 0, 56),
			Tombstones = 14,
		},
		Haystacks = 7, -- walk-in hiding spots scattered in the open
		JumpFences = 6, -- low fences players can hop; the King can't jump
		JumpFenceHeight = 3.5,
		HayBales = 14,
		DeadTrees = 9,
		Lanterns = 12,
		JackOLanterns = 14,
		Scarecrows = 3,
	},
	Lighting = {
		ClockTime = 0.2, -- full moon
		Brightness = 1.7,
		Ambient = Color3.fromRGB(85, 70, 110),
		OutdoorAmbient = Color3.fromRGB(110, 100, 150),
		Atmosphere = {
			Density = 0.42,
			Offset = 0.1,
			Color = Color3.fromRGB(120, 110, 170),
			Decay = Color3.fromRGB(255, 150, 80),
			Glare = 0.3,
			Haze = 2,
		},
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.1,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(240, 235, 255),
		},
		Bloom = { Intensity = 0.55, Size = 30, Threshold = 0.9 },
	},
	Particles = {
		Fireflies = { Rate = 14, Color = Color3.fromRGB(210, 255, 120) },
		Mist = { Rate = 10, Color = Color3.fromRGB(190, 175, 220) },
		Leaves = { Rate = 6, Color = Color3.fromRGB(205, 110, 40) },
	},
	-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.3 },
}
