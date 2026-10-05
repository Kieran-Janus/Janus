--!strict
--[[
	MAP: Hedge Maze (one entry of Config.Maps.List), a Hide & Seek map.

	Built by src/server/Maps/HedgeMaze.luau from these settings (or replaced by a Model
	named HedgeMaze in ServerStorage.Maps). Change Size, Colors, Lighting or AmbientSound
	here. Modes lists the game modes this map is used for.
]]

return {
	Id = "HedgeMaze",
	Name = "Hedge Maze",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "HedgeMaze",
	Modes = { "HideSeek" }, -- game modes played on this map (Config.Modes)
	Seed = 4,
	Size = Vector3.new(180, 1, 180),
	WallHeight = 14, -- the tall hedge around the edge
	Spawns = 10,
	SpawnRadius = 14,
	Colors = {
		Floor = Color3.fromRGB(104, 98, 86), -- gravel paths
		Wall = Color3.fromRGB(34, 72, 40), -- hedge
		Hedge = Color3.fromRGB(40, 84, 46),
		Stone = Color3.fromRGB(130, 128, 138),
		Wood = Color3.fromRGB(92, 62, 40),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 200, 90),
	},
	-- TODO(hide & seek agent): layout settings for the Hedge Maze builder.
	Layout = {},
	Lighting = { -- a bright full moon so hiders can still be found
		ClockTime = 0.3,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(90, 90, 120),
		OutdoorAmbient = Color3.fromRGB(120, 120, 160),
		Atmosphere = {
			Density = 0.35,
			Offset = 0.1,
			Color = Color3.fromRGB(130, 140, 180),
			Decay = Color3.fromRGB(110, 160, 140),
			Glare = 0.2,
			Haze = 1.4,
		},
		ColorCorrection = {
			Brightness = 0.05,
			Contrast = 0.1,
			Saturation = 0.15,
			TintColor = Color3.fromRGB(235, 245, 255),
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
