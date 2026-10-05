--!strict
--[[
	MAP: ScareMaze (one entry of Config.Maps.List), the ScareMaze mode's map.

	Built by src/server/Maps/ScareMaze.luau from these settings (or replaced by a Model
	named ScareMaze in ServerStorage.Maps). Change Size, Colors, Lighting or AmbientSound
	here. Modes lists the game modes this map is used for.
]]

return {
	Id = "ScareMaze",
	Name = "ScareMaze",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "ScareMaze",
	Modes = { "ScareMaze" }, -- game modes played on this map (Config.Modes)
	Seed = 5,
	Size = Vector3.new(200, 1, 200),
	WallHeight = 16, -- the outer wall
	Spawns = 10,
	SpawnRadius = 14,
	Colors = {
		Floor = Color3.fromRGB(70, 64, 78), -- old flagstones
		Wall = Color3.fromRGB(52, 42, 64),
		Stone = Color3.fromRGB(110, 104, 120),
		Wood = Color3.fromRGB(80, 54, 38),
		Bone = Color3.fromRGB(235, 228, 210),
		Orange = Color3.fromRGB(255, 130, 20),
		Green = Color3.fromRGB(110, 200, 90),
		Glow = Color3.fromRGB(255, 200, 90),
	},
	-- TODO(scaremaze agent): layout settings for the ScareMaze builder.
	Layout = {},
	Lighting = { -- dark and foggy, but never pitch black
		ClockTime = 23,
		Brightness = 1.3,
		Ambient = Color3.fromRGB(90, 70, 115),
		OutdoorAmbient = Color3.fromRGB(100, 80, 130),
		Atmosphere = {
			Density = 0.45,
			Offset = 0.2,
			Color = Color3.fromRGB(100, 80, 140),
			Decay = Color3.fromRGB(80, 60, 130),
			Glare = 0,
			Haze = 2,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.15,
			Saturation = 0.05,
			TintColor = Color3.fromRGB(240, 225, 255),
		},
		Bloom = { Intensity = 0.9, Size = 26, Threshold = 0.88 },
	},
	Particles = {
		Mist = { Rate = 10, Color = Color3.fromRGB(170, 150, 210) },
		Wisps = { Rate = 5, Color = Color3.fromRGB(150, 220, 255) },
	},
	-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
}
