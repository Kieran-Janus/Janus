--!strict
--[[
	MAP: Midnight Market (one entry of Config.Maps.List), a small Hide & Seek map.

	A cosy walled night market, packed with stalls, crate stacks, barrels, sacks, hay and
	pumpkin piles under strings of glowing lanterns. It is small, so the seekers with their
	candy guns are never far away, and it has lots of places to hide: every round the clutter
	and the decoy pumpkins are shuffled into new spots (Shuffle = false keeps the same layout
	every round, from Seed).
	Built by src/server/Maps/MidnightMarket.luau (or replaced by a Model named MidnightMarket
	in ServerStorage.Maps). Change the counts in Layout for more or fewer things.
]]

return {
	Id = "MidnightMarket",
	Name = "Midnight Market",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "MidnightMarket",
	Modes = { "HideSeek" }, -- game modes played on this map (Config.Modes)
	Seed = 31,
	Size = Vector3.new(104, 1, 104),
	WallHeight = 14, -- an invisible wall round the edge (the brick wall is what you see)
	Spawns = 10, -- hider spawn spots
	SpawnRadius = 30, -- (not used: the market picks the spots)
	Colors = {
		Floor = Color3.fromRGB(92, 84, 100), -- cobbles
		Wall = Color3.fromRGB(70, 48, 52),
		Brick = Color3.fromRGB(122, 64, 58),
		Cap = Color3.fromRGB(150, 142, 150),
		Wood = Color3.fromRGB(110, 74, 46),
		Iron = Color3.fromRGB(40, 36, 46),
		Straw = Color3.fromRGB(206, 170, 88),
		Sack = Color3.fromRGB(176, 150, 112),
		Cloth = Color3.fromRGB(70, 110, 160),
		-- Stall awnings take turns with these stripes.
		Awnings = {
			{ Color3.fromRGB(150, 60, 190), Color3.fromRGB(255, 150, 40) },
			{ Color3.fromRGB(60, 150, 110), Color3.fromRGB(245, 235, 210) },
			{ Color3.fromRGB(200, 50, 70), Color3.fromRGB(255, 220, 120) },
			{ Color3.fromRGB(60, 90, 180), Color3.fromRGB(240, 240, 255) },
		},
		Goods = {
			Color3.fromRGB(255, 130, 20),
			Color3.fromRGB(220, 40, 50),
			Color3.fromRGB(120, 200, 80),
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(170, 90, 220),
		},
		Orange = Color3.fromRGB(255, 130, 20),
		Glow = Color3.fromRGB(255, 196, 110),
		Roof = Color3.fromRGB(60, 44, 70),
		Trim = Color3.fromRGB(240, 226, 200),
		HutWall = Color3.fromRGB(120, 70, 150), -- the Seeker Hut
		HutDoor = Color3.fromRGB(255, 110, 180),
		HutText = Color3.fromRGB(255, 250, 240),
	},
	Layout = {
		Shuffle = true, -- new spots for the clutter and decoys every round
		SeekerHut = {
			Offset = Vector3.new(-38, 0, -38), -- studs from the middle (north-west corner)
			FacesTowards = Vector3.new(0, 0, 0),
			Size = Vector3.new(12, 9, 12), -- room inside: width, height, depth
			Spawns = 4,
		},
		Stalls = 8, -- market stalls round the edge
		Clutter = 22, -- crate stacks, barrel groups, sacks, hay and carts on the square
		Decoys = 110, -- decoy pumpkins (hiders look just like these)
		Lampposts = 4, -- round the pumpkin pyramid in the middle
		LanternStrings = 4, -- strings of little glowing lanterns across the square
		WallHeight = 7, -- the brick wall you see round the market
	},
	Lighting = { -- night, but the lanterns keep it warm enough to spot a wobbling pumpkin
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
		Fireflies = { Rate = 8, Color = Color3.fromRGB(255, 200, 120) },
		Mist = { Rate = 4, Color = Color3.fromRGB(190, 170, 210) },
	},
	Scenery = { Trees = 14, Hills = 12, PostSpacing = 30 },
	-- Crickets loop (Pro Sound Effects, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.25 },
}
