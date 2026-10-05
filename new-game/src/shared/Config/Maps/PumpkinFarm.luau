--!strict
--[[
	MAP: Pumpkin Farm (one entry of Config.Maps.List), a Hide & Seek map.

	Built by src/server/Maps/PumpkinFarm.luau from these settings (or replaced by a Model
	named PumpkinFarm in ServerStorage.Maps). Change Size, Colors, Lighting or AmbientSound
	here. Modes lists the game modes this map is used for.
]]

return {
	Id = "PumpkinFarm",
	Name = "Pumpkin Farm",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "PumpkinFarm",
	Modes = { "HideSeek" }, -- game modes played on this map (Config.Modes)
	Seed = 3,
	Size = Vector3.new(200, 1, 200),
	WallHeight = 12, -- the fence around the farm
	Spawns = 10,
	SpawnRadius = 18,
	Colors = {
		Floor = Color3.fromRGB(78, 112, 52), -- grass
		Wall = Color3.fromRGB(110, 76, 48), -- wooden fence
		Dirt = Color3.fromRGB(96, 68, 44),
		Hay = Color3.fromRGB(222, 184, 92),
		Barn = Color3.fromRGB(160, 50, 44),
		Wood = Color3.fromRGB(92, 62, 40),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 200, 90),
	},
	-- TODO(hide & seek agent): layout settings for the Pumpkin Farm builder.
	Layout = {},
	Lighting = { -- a warm sunset, bright enough that hiders are fairly easy to spot
		ClockTime = 18.2,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(120, 95, 90),
		OutdoorAmbient = Color3.fromRGB(150, 120, 110),
		Atmosphere = {
			Density = 0.3,
			Offset = 0.1,
			Color = Color3.fromRGB(230, 170, 130),
			Decay = Color3.fromRGB(255, 140, 70),
			Glare = 0.4,
			Haze = 1.2,
		},
		ColorCorrection = {
			Brightness = 0.05,
			Contrast = 0.08,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(255, 240, 225),
		},
		Bloom = { Intensity = 0.6, Size = 26, Threshold = 0.95 },
	},
	Particles = {
		Fireflies = { Rate = 10, Color = Color3.fromRGB(210, 255, 120) },
		Leaves = { Rate = 6, Color = Color3.fromRGB(205, 110, 40) },
	},
	-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.25 },
}
