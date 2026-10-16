--!strict
--[[
	MAP: Crumbling Crypt (one entry of Config.Maps.List), the Crumbling Crypt (TileFall) mode's
	map: a square floor of stone slabs, up to 3 layers stacked with gaps between them, floating
	over a pit of glowing green goo inside old crypt walls. Stone pillars with candles and
	skulls stand round the slabs (walk-through), gravestones line the ledges by the walls and
	bats flit overhead.

	Built by src/server/Maps/CrumblingCrypt.luau from these settings (or replaced by a Model named
	CrumblingCrypt in ServerStorage.Maps: see docs/CUSTOMIZE.md, "Bake"). The slabs themselves are
	made by src/server/Modes/TileFallBoard.luau: the map is built with the Easy board, and a
	Hard round rebuilds it with Hard's layers and slab size (Config.TileFall.Difficulty). A
	baked board you edited by hand is played as it is.
	Working parts (by tag): every slab is tagged TileFallTile (attribute Layer, 1 = top), the goo
	is tagged TileFallGoo. The goo part is also the map's "Floor".
]]

return {
	Id = "CrumblingCrypt",
	Name = "Crumbling Crypt",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns", -- start spots, on the top layer
	Builder = "CrumblingCrypt",
	Modes = { "TileFall" }, -- game modes played on this map (Config.Modes)
	Seed = 61,
	Size = Vector3.new(150, 1, 150), -- the goo pit (the whole crypt floor)
	WallHeight = 74, -- the crypt walls, from the goo up
	Spawns = 12, -- start spots in a ring on the top layer (more players share them)
	SpawnRadius = 28, -- studs from the middle (keep it inside Board.Size / 2)

	-- The slab floor (all layers are the same square, one above the other).
	Board = {
		Size = 84, -- studs across (the slabs fill it: Size / TileSize slabs a side)
		TopHeight = 68, -- studs from the goo to the top of the top floor (5 floors: the lowest is 12 up)
		LayerSpacing = 14, -- studs between floors (too high to jump back up)
		Thickness = 1.6, -- how thick a slab is
		Gap = 0.35, -- the seam between two slabs
	},

	Layout = {}, -- (every map has one; the crypt's layout is Board and Decor below)
	Scenery = false, -- no hills and ground round it: the crypt floats over its goo pit
	Colors = {
		Goo = Color3.fromRGB(70, 190, 60), -- the goo pit
		GooGlow = Color3.fromRGB(120, 255, 90), -- the glow under the slabs
		Slab = { -- the slabs, top layer first (each slab is a little lighter or darker)
			Color3.fromRGB(128, 120, 132),
			Color3.fromRGB(108, 100, 118),
			Color3.fromRGB(92, 84, 104),
			Color3.fromRGB(84, 92, 104),
			Color3.fromRGB(78, 70, 92),
		},
		SlabEdge = Color3.fromRGB(70, 64, 78), -- the rim round the edge of each layer
		Wall = Color3.fromRGB(58, 52, 66), -- crypt walls
		WallTrim = Color3.fromRGB(84, 76, 94),
		Ledge = Color3.fromRGB(66, 60, 72), -- the ledge along the walls (gravestones stand on it)
		Pillar = Color3.fromRGB(104, 96, 110),
		Stone = Color3.fromRGB(120, 116, 126), -- gravestones
		Bone = Color3.fromRGB(236, 226, 200), -- skulls and candle wax
		Glow = Color3.fromRGB(255, 200, 110), -- candle flames
		Dark = Color3.fromRGB(28, 22, 34), -- bats, eye holes
		Green = Color3.fromRGB(90, 140, 60), -- moss
		Sign = Color3.fromRGB(150, 255, 110),
	},

	-- Decorations (all walk-through, so nobody can stand on them).
	Decor = {
		PillarsPerSide = 3, -- stone pillars along each side of the slabs
		PillarGap = 9, -- studs between the slabs' edge and the pillars
		PillarHeight = 76, -- from the goo up
		LitCandles = 6, -- pillars whose candle gives light (phones: keep the lights low)
		Skulls = 14, -- skulls on the ledges (plus one on every pillar)
		Gravestones = 12, -- along the ledges
		Bats = 8, -- flying over the slabs
		GooLights = 4, -- green lights shining up from the goo
		LedgeWidth = 10,
		LedgeHeight = 2.5, -- above the goo
	},
	SignText = "CRUMBLING CRYPT",
	SignSubText = "DON'T STOP MOVING!",

	Lighting = { -- dark, green glow from below
		ClockTime = 0,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(86, 84, 108),
		OutdoorAmbient = Color3.fromRGB(104, 100, 130),
		Atmosphere = {
			Density = 0.32,
			Offset = 0.1,
			Color = Color3.fromRGB(110, 140, 120),
			Decay = Color3.fromRGB(60, 110, 70),
			Glare = 0,
			Haze = 1.4,
		},
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.12,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(235, 255, 235),
		},
		Bloom = { Intensity = 0.7, Size = 24, Threshold = 0.9 },
	},
	Particles = {
		Wisps = { Rate = 5, Color = Color3.fromRGB(160, 255, 140) },
		Dust = { Rate = 6, Color = Color3.fromRGB(200, 190, 170) },
	},
	-- "HAUNTED AMBIENCE" (DistroKid, Creator Store); "" = none
	AmbientSound = { SoundId = "rbxassetid://134980593475246", Volume = 0.3 },
}
