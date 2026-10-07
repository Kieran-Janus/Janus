--!strict
--[[
	THE ROUND MAPS COME ALIVE (Config.MapLife, used by src/client/MapLife.luau).

	Everything here happens on each player's own screen only: the server never moves anything,
	pumpkins are touched and collected exactly where the server put them, and nothing made here
	is solid, clickable or touchable (candy and the King's eyes go straight through it).
	Whole feature on/off: Config.Features.MapLife. Each part below also has its own On.
	Only things within Range studs of the camera (PhoneRange on phones) move.
]]

return {
	Range = 90, -- studs from the camera: pumpkins farther away stay still (cheaper)
	PhoneRange = 60, -- the same on phones

	-- King Hunt pumpkins (the ones you collect): bob, spin, glow, and pop when collected.
	Pickups = {
		On = true,
		BobHeight = 0.45, -- studs up and down
		BobSpeed = 2.2, -- how fast they bob
		SpinSpeed = 50, -- degrees per second they turn
		Stem = true, -- the plain orange ball gets a little green stem (so you see it spin)
		StemColor = Color3.fromRGB(70, 140, 50),
		GlowPulse = 0.4, -- how much the glow light breathes (0.4 = 40% brighter and dimmer)
		GlowSpeed = 3, -- how fast it breathes
		-- When someone collects one near you: a sparkle burst and a quick "pop" ball
		BurstCount = 16, -- sparkles (phones make PhoneBurstCount)
		PhoneBurstCount = 8,
		BurstColors = {
			Color3.fromRGB(255, 200, 60), -- gold
			Color3.fromRGB(255, 140, 30), -- orange
			Color3.fromRGB(255, 255, 200), -- white
		},
		PopSeconds = 0.35, -- how long the pop ball takes to grow and fade
		PopGrow = 2, -- how big it grows (2 = twice the pumpkin's size)
		PopColor = Color3.fromRGB(255, 190, 80),
	},

	-- Fireflies / embers drifting round your camera while you are on a round map.
	Ambient = {
		On = true,
		Count = 12, -- how many at once
		PhoneCount = 5, -- how many on phones
		Radius = 28, -- studs round the camera they drift in (farther ones come back near you)
		Height = { Min = 1.5, Max = 9 }, -- studs above the camera's feet level they float
		Size = 0.3, -- studs across
		Drift = 1.6, -- studs per second they wander
		BlinkSpeed = 1.3, -- how fast they glow and fade
		Color = Color3.fromRGB(255, 225, 120), -- warm firefly yellow (maps not listed below)
		-- A colour per map (the map's Id from Config.Maps.List)
		MapColors = {
			PumpkinPatch = Color3.fromRGB(255, 150, 60), -- embers
			SpookyMansion = Color3.fromRGB(170, 220, 255), -- ghostly wisps
			PumpkinFarm = Color3.fromRGB(220, 255, 120), -- fireflies
			HedgeMaze = Color3.fromRGB(160, 255, 170), -- green fireflies
			ScareMaze = Color3.fromRGB(200, 130, 255), -- purple wisps
		},
	},

	-- Hide & Seek: now and then one pumpkin near you does a tiny wobble. Decoys AND hiders'
	-- pumpkins are picked the same way and wobble the same way, so a wobble never gives a
	-- hider away (and neither does standing still).
	Wobble = {
		On = true,
		EveryMin = 0.8, -- seconds between wobbles (a random time between these two)
		EveryMax = 2.2,
		MaxAtOnce = 3, -- at most this many wobbling at the same time
		Seconds = 0.9, -- how long one wobble lasts
		Angle = 7, -- degrees it tips each way
		Wiggles = 2, -- back-and-forth wiggles in one wobble
	},
}
