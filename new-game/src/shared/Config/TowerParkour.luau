--!strict
--[[
	TORMENTED TOWER (Config.TowerParkour; on/off: Config.Features.TowerParkour)

	A REALLY hard parkour climb INSIDE the lobby's crooked clock tower, for the bravest players.
	Walk in through the doorway at the bottom of the tower, stand on the START pad and climb up
	to the clock face: tiny platforms, narrow beams, truss climbs, platforms that vanish, spinning
	bars that knock you off, turning gears, slime that sends you back, and long jumps you can only
	make while sprinting (hold Shift, or the sprint button on phones). There are only 3
	checkpoints. Falling sends you back to your last checkpoint (or the start).

	Beat it once and you win the tower's own CRAZY skin (Reward.SkinId, never sold or in a crate),
	the whole server sees "<name> conquered the Tormented Tower!", and Roblox gives you the badge
	in Reward.BadgeId (0 = no badge). Your best time is saved.

	The tower is built from Config.Hub.ClockTower (Offset, Width, Floors, FloorHeight, Lean,
	Twist), so the course follows the tower if you move or resize it. Swap the ClockTower prop
	for your own model (ReplicatedStorage.Custom.Props.ClockTower) and the course still works:
	any part of your model inside the tower's hollow middle stops being solid, and an inner
	wall is built so the inside still looks spooky. Leave a doorway gap at the front of your
	model (the side facing the middle of the lobby), or players walk through its wall there.

	Change the course: edit Course below. Each line is one piece, in climbing order. The game
	checks every jump with the same jump maths as the lobby parkour (src/shared/TowerLogic.luau,
	tests/specs/tower.spec.luau) and warns in the Output window about a jump that can't be made.
	Course changes show after the hub is rebuilt (F8 > Rebuild hub, Bake.Hub(), or raise
	Config.Hub.BuildVersion). In Studio you can move the built pieces (Workspace.Hub.TowerParkour):
	the game finds the working parts by tag (TowerStart, TowerCheckpoint with Index = 1, 2, 3,
	TowerFinish, TowerHazard, TowerVanish, TowerSpinner, TowerGear).
]]

--[[
	THE COURSE: one line per piece, in the order you climb them.
	  Kind     Start, Ledge (a small stone shelf), Tiny (a tiny post top), Beam (a narrow plank),
	           Truss (a ladder to climb), Vanish (a platform that disappears now and then),
	           Spinner (a platform with a spinning bar that knocks you off), Gear (a turning
	           cog you ride), Checkpoint, Finish, or Hazard (slime on the piece before it: touching
	           it sends you back)
	  Offset   Vector3.new(right, up, back): where the middle of the piece's TOP is, in studs:
	             right  from the middle of the tower, seen from the plaza (+ = right)
	             up     height above the tower's inside floor
	             back   + = further from the door, - = towards the door
	           The tower leans and twists a little on each floor; right and back follow the floor
	           the piece is on.
	  Size     (optional) Vector3.new(width, height, depth); leave out for the normal size (Sizes)
	  Rotation (optional) a number of degrees to turn it
	  Sprint   (optional) true = the jump to this piece needs sprinting (it is longer than a
	           walking jump can reach)
	  Label    (optional, Checkpoint) words on the checkpoint
	Keep the Start first and the Finish last.
]]
type Step = {
	Kind: string,
	Offset: Vector3,
	Size: Vector3?,
	Rotation: number?,
	Sprint: boolean?,
	Label: string?,
}

-- stylua: ignore
local Course: { Step } = {
	{ Kind = "Start", Offset = Vector3.new(0, 0.5, -4.5) },
	{ Kind = "Ledge", Offset = Vector3.new(7.3, 2.3, -8.1), Rotation = 0 },
	{ Kind = "Tiny", Offset = Vector3.new(8.6, 4.1, -2.1) },
	{ Kind = "Ledge", Offset = Vector3.new(8.1, 5.9, 4.2), Rotation = 90 },
	{ Kind = "Hazard", Offset = Vector3.new(8.1, 5.9, 4.2), Size = Vector3.new(1.4, 0.4, 2.5), Rotation = 90 },
	{ Kind = "Beam", Offset = Vector3.new(4.2, 7.7, 8.9), Rotation = 90 },
	{ Kind = "Ledge", Offset = Vector3.new(-8.2, 8, 5.5), Rotation = 90, Sprint = true },
	{ Kind = "Vanish", Offset = Vector3.new(-7.1, 9.8, -2.3) },
	{ Kind = "Truss", Offset = Vector3.new(-4.8, 14.3, -7.8), Size = Vector3.new(2, 6, 2) },
	{ Kind = "Checkpoint", Offset = Vector3.new(0.9, 14.8, -6.6), Label = "The Clockwork" },
	{ Kind = "Tiny", Offset = Vector3.new(8, 16.6, -4) },
	{ Kind = "Ledge", Offset = Vector3.new(-0.1, 18.1, 7.1), Rotation = 0, Sprint = true },
	{ Kind = "Spinner", Offset = Vector3.new(-5.3, 19.9, 0.5) },
	{ Kind = "Gear", Offset = Vector3.new(1.4, 23.6, -5.8) },
	{ Kind = "Vanish", Offset = Vector3.new(6.6, 25.4, 2.1) },
	{ Kind = "Checkpoint", Offset = Vector3.new(-5.5, 27.2, 5.4), Label = "The Bell Shaft" },
	{ Kind = "Tiny", Offset = Vector3.new(-6.9, 29, -2.1) },
	{ Kind = "Beam", Offset = Vector3.new(-4.3, 31.6, -7.3), Rotation = 90 },
	{ Kind = "Spinner", Offset = Vector3.new(2.8, 33.4, -4.8) },
	{ Kind = "Truss", Offset = Vector3.new(6.2, 37.9, 5), Size = Vector3.new(2, 6, 2) },
	{ Kind = "Ledge", Offset = Vector3.new(0.5, 38.4, 6), Rotation = 0 },
	{ Kind = "Hazard", Offset = Vector3.new(0.5, 38.4, 6), Size = Vector3.new(1.4, 0.4, 2.5), Rotation = 0 },
	{ Kind = "Checkpoint", Offset = Vector3.new(-5, 40.2, 0), Label = "The Clock Face" },
	{ Kind = "Tiny", Offset = Vector3.new(0.3, 43.4, -5.8) },
	{ Kind = "Gear", Offset = Vector3.new(4.2, 45.2, 0.4) },
	{ Kind = "Vanish", Offset = Vector3.new(-4.2, 47, 4.9) },
	{ Kind = "Finish", Offset = Vector3.new(-4.2, 49.5, -3.4) },
}

return {
	Name = "Tormented Tower",

	-- How long and how tall the pieces are by default (studs).
	Sizes = {
		Start = Vector3.new(5, 1, 5),
		Ledge = Vector3.new(3, 1, 2.5),
		Tiny = Vector3.new(1.6, 1, 1.6),
		Beam = Vector3.new(1, 0.8, 7),
		Truss = Vector3.new(2, 8, 2),
		Vanish = Vector3.new(3.5, 0.8, 3.5),
		Spinner = Vector3.new(5, 1, 5),
		Gear = Vector3.new(5, 1, 5),
		Checkpoint = Vector3.new(4.5, 1, 4.5),
		Finish = Vector3.new(5, 1, 5),
		Hazard = Vector3.new(2, 0.4, 2.5),
	},

	-- The hollow tower: its walls are this thick, and pieces keep this far from them.
	Walls = {
		Thickness = 1.2,
		Clearance = 0.3, -- studs between a piece and the inside of a wall
		DoorWidth = 5, -- the doorway at the bottom front
		DoorHeight = 7.5,
		Color = Color3.fromRGB(56, 44, 66), -- the inner walls (also the shell built inside a custom tower)
		Material = Enum.Material.Brick,
		Lights = { -- glowing lanterns inside, as heights above the inside floor (each is a light)
			Heights = { 8, 22, 36 },
			Color = Color3.fromRGB(255, 120, 60),
			Range = 26,
			Brightness = 2,
		},
		ClockWindow = 6, -- studs across the hole behind the clock face on the clock floor (0 = none)
	},

	-- How hard jumps may be. Every jump in Course is checked against these.
	Jumps = {
		MaxGap = 13, -- studs across, edge to edge (sprint jumps included)
		MaxRise = 4.6, -- studs up
		Safety = 0.93, -- a walking jump uses at most this share of the longest possible one
		SprintSafety = 0.9, -- ...and a Sprint jump this share of the longest sprinting jump
		MinGap = -0.5, -- pieces may touch, but not overlap more than this
		-- A piece hanging low over a jump makes you bump your head, so you can't jump as high or
		-- as far: the check works out the shorter jump. BodyHeight = how tall a character is.
		BodyHeight = 5.2,
		HeadroomMargin = 1.5, -- studs either side of a jump's line that count as "over" it
	},

	-- Colours of the pieces.
	Look = {
		Colors = {
			Stone = Color3.fromRGB(96, 84, 108), -- ledges and the start pad
			Wood = Color3.fromRGB(112, 72, 46), -- beams
			Iron = Color3.fromRGB(70, 68, 80), -- tiny posts, trusses, axles
			Vanish = Color3.fromRGB(175, 90, 255), -- vanishing platforms (they flicker red first)
			VanishWarn = Color3.fromRGB(255, 60, 70),
			Spinner = Color3.fromRGB(230, 40, 50), -- spinning bars
			Gear = Color3.fromRGB(205, 150, 60), -- turning cogs
			Slime = Color3.fromRGB(90, 255, 70),
			Checkpoint = Color3.fromRGB(255, 120, 40),
			Finish = Color3.fromRGB(255, 215, 80),
			Lantern = Color3.fromRGB(255, 140, 60),
		},
	},

	-- Moving pieces (the server moves them, everyone sees the same).
	Vanish = {
		Visible = 2.2, -- seconds a Vanish platform is there...
		Gone = 1.6, -- ...then seconds it is gone (it fades out first)
		Warn = 0.6, -- seconds it flickers before it goes
		Stagger = 0.9, -- seconds between neighbouring platforms (so they don't all vanish at once)
	},
	Spinner = {
		Speed = 2.2, -- how fast the bar turns, in radians per second (2.2 = one turn every 3 seconds)
		Height = 2.4, -- studs above the platform: jump it or duck past at the right moment
		Length = 6, -- studs long
		Thickness = 0.8,
	},
	Gear = {
		Speed = 0.5, -- radians per second the cog turns (slow: you ride it)
		Teeth = 8,
	},

	-- Rewards.
	Reward = {
		SkinId = "Tower_TormentedSoul", -- the exclusive skin (its look is in Skin, below)
		BadgeId = 0, -- a Roblox badge for beating the tower (Creator Hub > your game > Badges); 0 = none
	},
	MinSeconds = 60, -- a finish faster than this doesn't count (stops teleport cheats)
	MaxRunSeconds = 3600, -- a run still going after this long stops by itself

	-- The exclusive skin, only won by beating the tower: never sold in the shop, never in a crate.
	-- Same Style options as the crate skins (see the top of Config/Skins/Pumpkin.luau). Effect is
	-- its own animated effect (src/client/SkinFx.luau): "Torment" = a swirl of ghostly chains and
	-- red lightning crackling round you.
	Skin = {
		Id = "Tower_TormentedSoul",
		Name = "Tormented Soul",
		Rarity = "Crazy",
		Style = {
			BodyColor = Color3.fromRGB(40, 24, 52),
			Material = Enum.Material.Slate,
			Accent = {
				Color = Color3.fromRGB(255, 40, 60),
				Material = Enum.Material.Neon,
				Pattern = { "Stitches", "Bones" },
			},
			Head = "SkinSkull",
			HeadColor = Color3.fromRGB(210, 200, 225),
			HeadColor2 = Color3.fromRGB(40, 24, 52),
			GlowColor = Color3.fromRGB(255, 40, 60),
			Glow = { Color = Color3.fromRGB(255, 50, 70), Brightness = 2.4, Range = 14 },
			Aura = {
				Kind = "Smoke",
				Color = Color3.fromRGB(140, 20, 50),
				Color2 = Color3.fromRGB(20, 10, 30),
			},
			Crazy = { Pulse = true, Orbit = "Bones", Count = 3, Effect = "Torment" },
		},
	},

	-- Words (the timer and panel are the lobby parkour's, with these words). The glowing sign in
	-- front of the door is in Config.Lobby.FloorSigns (the line with Zone = "TowerParkour").
	Text = {
		Ready = "Ready... if you dare!",
		Timer = "%s",
		CheckpointCount = "Checkpoint %d/%d",
		Checkpoint = "Checkpoint %d/%d!",
		Fell = "Tormented! Back to checkpoint %d",
		FellStart = "Tormented! Back to the start",
		Slimed = "Slimed! Back to checkpoint %d",
		SlimedStart = "Slimed! Back to the start",
		Missed = "You missed checkpoint %d!",
		NeedCheckpoints = "Touch every checkpoint first!",
		NeedStart = "Start on the START pad at the bottom of the tower!",
		Finished = "YOU CONQUERED THE TOWER!",
		FinishTime = "Time: %s",
		NewBest = "New best!",
		Best = "Best: %s",
		Coins = "+%d %s",
		CoinsLater = "Your best time is saved",
		SkinWon = "You won the %s skin!",
		Stopped = "Climb stopped",
		TooFast = "That was too fast to be real...",
		Left = "You left the tower",
		TimeUp = "Out of time",
		Stop = "Stop",
		Tile = "Tormented Tower",
		PanelTitle = "Tormented Tower",
		NoBest = "Not conquered yet. Only the bravest make it to the clock...",
		Runs = "Times conquered: %d",
		RewardReady = "Prize: the Tormented Soul skin",
		RewardWait = "You own the Tormented Soul skin",
		GoToStart = "Go to the tower",
		Close = "Close",
		InRound = "Not during a round",
		NotInLobby = "Go back to the lobby first",
		NoCourse = "The tower isn't open",
		Teleported = "Good luck...",
		Wait = "Wait a moment",
		Announce = "%s conquered the Tormented Tower!",
		Sign = "TORMENTED TOWER\nonly the bravest",
	},

	Course = Course, -- the list at the top of this file
}
