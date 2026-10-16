--!strict
--[[
	MAP: Spooky Obby (one entry of Config.Maps.List), the course of the Spooky Obby mode
	(Config.ObbyRace). Built by src/server/Maps/SpookyObby.luau from these settings.

	A misty graveyard in the sky: the start plaza (the Floor, with the spawns), then nine
	stages over the void: Pumpkin Hop, Gravestone Hops, Coffin Bridge, Ghost Sweepers (spinning
	bars to jump over), Candy Cane Rails, the Haunted Tree climb, Bat Wing Leaps, the Spin Cycle
	and the Tightrope Twist, up to the glowing finish
	with the golden trophy pumpkin. Glowing checkpoints sit between the stages.

	THE COURSE: one line per piece, in the order you jump on them (the same way of writing as
	the lobby parkour, Config.Parkour.Course):
	  Kind      what the jump maths sees: Start, Pumpkin, Grave, Platform, Candy, Checkpoint,
	            Finish, or Hazard (green goo: touching it sends you back; it isn't jumped on)
	  Look      how it looks: Plaza, Pumpkin, Grave, Coffin, Sweeper, Pad, CandyRail, CandyDrop,
	            Branch, Checkpoint, Finish, Goo
	  Offset    Vector3.new(right, up, back): where the middle of the piece's TOP is, in studs
	            from the middle of the start plaza (back = further along the course)
	  Size      Vector3.new(width, height, depth)
	  Rotation  (optional) degrees to turn it (90 = a rail lying across the course)
	  Only      (optional) "Easy" or "Hard": the piece is only there on that difficulty (Easy
	            gets bigger pumpkins, wider rails, an extra checkpoint; Hard gets goo on the
	            coffins and a second sweeper bar)
	  Label     (optional, Checkpoint) the name of the stage that starts there
	  Sweeper   (optional, Look Sweeper) { Speed = degrees per second (minus = the other way),
	            Length = bar length, Cross = true for a second bar on Hard }
	Keep every jump easy: tests/specs/obbyrace.spec.luau checks each one with the parkour jump
	maths (ParkourLogic.Check) for Easy AND Hard (run `lune run tests/run -- obbyrace`).
	Checkpoints are numbered in the order they appear. Keep the Start first, the Finish last.
	After changing the course, test it in Studio (F8 > "Spooky Obby: force next round").
]]

type Step = {
	Kind: string,
	Look: string,
	Offset: Vector3,
	Size: Vector3,
	Rotation: number?,
	Only: string?,
	Label: string?,
	Sweeper: { Speed: number, Length: number, Cross: boolean? }?,
}

-- stylua: ignore
local Course: { Step } = {
	{ Kind = "Start", Look = "Plaza", Offset = Vector3.new(0, 0, 0), Size = Vector3.new(48, 1, 48) },
	-- Stage 1: Pumpkin Hop (Easy: big pumpkins; Hard: smaller ones in the same spots)
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 1, 31), Size = Vector3.new(8, 5, 8), Only = "Easy" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 1, 31), Size = Vector3.new(5.5, 4.5, 5.5), Only = "Hard" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(5, 1.5, 39), Size = Vector3.new(8, 5, 8), Only = "Easy" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(5, 1.5, 39), Size = Vector3.new(5.5, 4.5, 5.5), Only = "Hard" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 2, 47), Size = Vector3.new(8, 5, 8), Only = "Easy" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 2, 47), Size = Vector3.new(5.5, 4.5, 5.5), Only = "Hard" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(-5, 2.5, 55), Size = Vector3.new(8, 5, 8), Only = "Easy" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(-5, 2.5, 55), Size = Vector3.new(5.5, 4.5, 5.5), Only = "Hard" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 3, 63), Size = Vector3.new(8, 5, 8), Only = "Easy" },
	{ Kind = "Pumpkin", Look = "Pumpkin", Offset = Vector3.new(0, 3, 63), Size = Vector3.new(5.5, 4.5, 5.5), Only = "Hard" },
	-- Stage 2: Gravestone Hops
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(0, 3, 74), Size = Vector3.new(12, 1.4, 12), Label = "Gravestone Hops" },
	{ Kind = "Grave", Look = "Grave", Offset = Vector3.new(0, 4, 85), Size = Vector3.new(6.5, 6, 4.5) },
	{ Kind = "Grave", Look = "Grave", Offset = Vector3.new(4, 5, 92), Size = Vector3.new(6.5, 6, 4.5) },
	{ Kind = "Grave", Look = "Grave", Offset = Vector3.new(-1, 6, 99), Size = Vector3.new(6.5, 6, 4.5) },
	{ Kind = "Grave", Look = "Grave", Offset = Vector3.new(3, 6.5, 106), Size = Vector3.new(6.5, 6, 4.5) },
	-- Stage 3: Coffin Bridge (Hard: a stripe of goo across two coffins to hop over)
	{ Kind = "Platform", Look = "Coffin", Offset = Vector3.new(3, 7, 116), Size = Vector3.new(5, 2, 10) },
	{ Kind = "Platform", Look = "Coffin", Offset = Vector3.new(0, 7.5, 129), Size = Vector3.new(5, 2, 10) },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(0, 7.5, 129), Size = Vector3.new(5, 0.4, 2.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Coffin", Offset = Vector3.new(3, 8, 142), Size = Vector3.new(5, 2, 10) },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(3, 8, 142), Size = Vector3.new(5, 0.4, 2.5), Only = "Hard" },
	-- Stage 4: Ghost Sweepers (jump over the spinning bars; Easy: slow, with a checkpoint
	-- between the two; Hard: faster, with a second bar)
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(0, 8.5, 156), Size = Vector3.new(12, 1.4, 12), Label = "Ghost Sweepers" },
	{ Kind = "Platform", Look = "Sweeper", Offset = Vector3.new(0, 9, 177), Size = Vector3.new(24, 1.5, 24), Sweeper = { Speed = 60, Length = 21, Cross = true } },
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(0, 9.5, 198), Size = Vector3.new(12, 1.4, 12), Only = "Easy", Label = "Halfway there!" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(0, 9.5, 198), Size = Vector3.new(8, 1.5, 8), Only = "Hard" },
	{ Kind = "Platform", Look = "Sweeper", Offset = Vector3.new(0, 10, 219), Size = Vector3.new(24, 1.5, 24), Sweeper = { Speed = -75, Length = 21, Cross = true } },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(-7.5, 10, 212), Size = Vector3.new(6, 0.4, 5) },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(7.5, 10, 226), Size = Vector3.new(6, 0.4, 5) },
	-- Stage 5: Candy Cane Rails (Easy: 4 studs wide; Hard: 2.5)
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(0, 10.5, 240), Size = Vector3.new(12, 1.4, 12), Label = "Candy Cane Rails" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(0, 11, 258), Size = Vector3.new(4, 1, 18), Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(0, 11, 258), Size = Vector3.new(2, 1, 18), Only = "Hard" },
	{ Kind = "Candy", Look = "CandyDrop", Offset = Vector3.new(0, 11.5, 273.5), Size = Vector3.new(7, 1.4, 7) },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(15.5, 12, 273.5), Size = Vector3.new(4, 1, 18), Rotation = 90, Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(15.5, 12, 273.5), Size = Vector3.new(2, 1, 18), Rotation = 90, Only = "Hard" },
	{ Kind = "Candy", Look = "CandyDrop", Offset = Vector3.new(31, 12.5, 273.5), Size = Vector3.new(7, 1.4, 7) },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(31, 13, 289.5), Size = Vector3.new(4, 1, 18), Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(31, 13, 289.5), Size = Vector3.new(2, 1, 18), Only = "Hard" },
	-- Stage 6: the Haunted Tree (climb its branches; Hard: thinner branches)
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(31, 13.5, 307.5), Size = Vector3.new(12, 1.4, 12), Label = "The Haunted Tree" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 15.5, 319), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 15.5, 319), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 17.5, 326), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 17.5, 326), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 19.5, 333), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 19.5, 333), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 21.5, 340), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 21.5, 340), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 23.5, 347), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(31, 23.5, 347), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 25.5, 354), Size = Vector3.new(7, 1.2, 5), Only = "Easy" },
	{ Kind = "Platform", Look = "Branch", Offset = Vector3.new(25, 25.5, 354), Size = Vector3.new(4.5, 1.2, 3.5), Only = "Hard" },
	-- Stage 7: Bat Wing Leaps (pads zigzagging up; Easy: 6 studs across, Hard: 4)
	{ Kind = "Checkpoint", Look = "Checkpoint", Offset = Vector3.new(25, 26.5, 366), Size = Vector3.new(12, 1.4, 12), Label = "Bat Wing Leaps" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(29, 27.5, 378), Size = Vector3.new(6, 1.2, 6), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(29, 27.5, 378), Size = Vector3.new(4, 1.2, 4), Only = "Hard" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(23, 28.5, 387), Size = Vector3.new(6, 1.2, 6), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(23, 28.5, 387), Size = Vector3.new(4, 1.2, 4), Only = "Hard" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(29, 29.5, 396), Size = Vector3.new(6, 1.2, 6), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(29, 29.5, 396), Size = Vector3.new(4, 1.2, 4), Only = "Hard" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(23, 30.5, 405), Size = Vector3.new(6, 1.2, 6), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(23, 30.5, 405), Size = Vector3.new(4, 1.2, 4), Only = "Hard" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(27, 31.5, 414), Size = Vector3.new(6, 1.2, 6), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(27, 31.5, 414), Size = Vector3.new(4, 1.2, 4), Only = "Hard" },
	-- Stage 8: Spin Cycle (a sweeper with two bars; Hard: faster, with goo on the floor)
	{ Kind = "Platform", Look = "Sweeper", Offset = Vector3.new(27, 32, 433), Size = Vector3.new(24, 1.5, 24), Sweeper = { Speed = 95, Length = 21, Cross = true } },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(19.5, 32, 427), Size = Vector3.new(6, 0.4, 5), Only = "Hard" },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(34.5, 32, 439), Size = Vector3.new(6, 0.4, 5), Only = "Hard" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(27, 32.5, 454), Size = Vector3.new(10, 1.5, 10), Only = "Easy" },
	{ Kind = "Platform", Look = "Pad", Offset = Vector3.new(27, 32.5, 454), Size = Vector3.new(8, 1.5, 8), Only = "Hard" },
	-- Stage 9: Tightrope Twist (candy rails with a turn; Easy: 4 wide, Hard: 2 with goo to hop over)
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(27, 33, 469), Size = Vector3.new(4, 1, 20), Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(27, 33, 469), Size = Vector3.new(2, 1, 20), Only = "Hard" },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(27, 33, 469), Size = Vector3.new(2, 0.4, 2), Only = "Hard" },
	{ Kind = "Candy", Look = "CandyDrop", Offset = Vector3.new(27, 33.5, 485), Size = Vector3.new(6, 1.4, 6) },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(41, 34, 485), Size = Vector3.new(4, 1, 18), Rotation = 90, Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(41, 34, 485), Size = Vector3.new(2, 1, 18), Rotation = 90, Only = "Hard" },
	{ Kind = "Candy", Look = "CandyDrop", Offset = Vector3.new(55, 34.5, 485), Size = Vector3.new(6, 1.4, 6) },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(55, 35, 501), Size = Vector3.new(4, 1, 20), Only = "Easy" },
	{ Kind = "Platform", Look = "CandyRail", Offset = Vector3.new(55, 35, 501), Size = Vector3.new(2, 1, 20), Only = "Hard" },
	{ Kind = "Hazard", Look = "Goo", Offset = Vector3.new(55, 35, 501), Size = Vector3.new(2, 0.4, 2), Only = "Hard" },
	-- The finish
	{ Kind = "Finish", Look = "Finish", Offset = Vector3.new(55, 36, 520), Size = Vector3.new(14, 1.6, 14) },
}

return {
	Id = "SpookyObby",
	Name = "Spooky Obby",
	Thumbnail = 0, -- rbxassetid, 0 = none yet
	SpawnFolder = "Spawns",
	Builder = "SpookyObby",
	Modes = { "ObbyRace" }, -- game modes played on this map (Config.Modes)
	Seed = 51,
	Size = Vector3.new(48, 1, 48), -- the start plaza (the course goes on over the void)
	WallHeight = 4, -- the low railing round the plaza (open towards the course)
	Spawns = 12,
	SpawnRadius = 12,
	Scenery = false, -- no ground under the course: it floats over a misty void
	Solid = false, -- decorations stay walk-through (solid trees or gravestones could make shortcuts)
	Course = Course,
	Colors = {
		Plaza = Color3.fromRGB(70, 62, 84),
		Stone = Color3.fromRGB(125, 122, 135),
		Moss = Color3.fromRGB(95, 140, 80),
		Pumpkin = Color3.fromRGB(255, 125, 25),
		PumpkinStem = Color3.fromRGB(90, 140, 60),
		Face = Color3.fromRGB(255, 205, 90),
		Wood = Color3.fromRGB(92, 62, 40),
		Coffin = Color3.fromRGB(70, 42, 34),
		CoffinTrim = Color3.fromRGB(200, 170, 90),
		Candy = Color3.fromRGB(250, 245, 240),
		CandyStripe = Color3.fromRGB(225, 40, 60),
		Bark = Color3.fromRGB(46, 36, 44),
		Leaves = Color3.fromRGB(120, 60, 140),
		Goo = Color3.fromRGB(110, 255, 90),
		Ghost = Color3.fromRGB(200, 220, 255),
		Checkpoint = Color3.fromRGB(120, 255, 140),
		Finish = Color3.fromRGB(170, 90, 255),
		Trophy = Color3.fromRGB(255, 200, 50),
		Hat = Color3.fromRGB(80, 40, 120),
		HatBand = Color3.fromRGB(255, 140, 30),
		Mist = Color3.fromRGB(120, 90, 160),
		Iron = Color3.fromRGB(35, 32, 40),
		Glow = Color3.fromRGB(255, 200, 90),
		Text = Color3.fromRGB(255, 225, 160),
		Orange = Color3.fromRGB(255, 130, 20), -- (jack-o'-lanterns)
		Green = Color3.fromRGB(110, 200, 90),
	},
	Layout = {
		MistDepth = 30, -- studs under the plaza where the glowing mist floats (walk-through)
		Islands = 8, -- little floating graveyard islands far off to the sides (decoration)
		PlazaLamps = 4, -- lampposts on the plaza (each one a light)
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
		Wisps = { Rate = 6, Color = Color3.fromRGB(200, 170, 255) },
		Mist = { Rate = 6, Color = Color3.fromRGB(190, 175, 220) },
	},
	AmbientSound = { SoundId = "rbxassetid://9112764040", Volume = 0.25 },
}
