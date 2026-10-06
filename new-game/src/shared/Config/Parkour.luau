--!strict
--[[
	PARKOUR COURSE: "Spooky Sky Climb" (Config.Parkour)

	The climb behind the clock tower (on/off: Config.Features.Parkour; its area is
	Config.Lobby.Zones.Parkour). Stand on the START pad, jump up the pieces, touch the 3
	checkpoints in order and reach the glowing trophy pumpkin at the top. The timer starts
	when you leave the start pad. Fall to the ground (or touch green slime) and you go back
	to your last checkpoint. Finishing gives coins once every Reward.CooldownHours.

	Change the course: edit the Course list just below. Each line is one piece. To add a
	jump, copy a line, paste it where it goes in the order and change its Offset. The Output
	window warns about any jump that is too far or too high for a normal player.
	In Studio you can also move, resize or copy the built pieces (Workspace.Hub.Parkour): the
	game finds the working parts by their tags (ParkourStart, ParkourCheckpoint with the
	attribute Index = 1, 2, 3..., ParkourFinish, ParkourHazard), not by name or position.
]]

--[[
	THE COURSE: one line per piece, in the order you climb them.
	  Kind      Start, Pumpkin, Grave, Broom, Candy, Bat, Platform, Checkpoint, Finish, or
	            Hazard (green slime: touching it sends you back; it isn't jumped on)
	  Offset    Vector3.new(right, up, back): where the middle of the piece's TOP is, in studs
	            from the middle of the parkour zone, seen from the plaza (facing the clock tower)
	              right  + = to the right, - = to the left
	              up     height of the top above the ground (where your feet go)
	              back   + = further away from the plaza, - = closer
	  Size      (optional) Vector3.new(width, height, depth); leave it out for the normal size
	            of that kind (Sizes, further down)
	  Rotation  (optional) Vector3.new(tip, turn, lean) in degrees, like Studio's Orientation,
	            or just a number to turn it. Without one, a piece shows its face (carving,
	            writing) to the plaza; Checkpoints face the next piece
	  Spicy     (optional) true = a harder jump is allowed here (Jumps.SpicyMaxGap)
	  Label     (optional, Checkpoint) the name of the stage that starts here, on its sign
	  Text      (optional, Grave) what is written on the gravestone
	Checkpoints are numbered 1, 2, 3 in the order they appear. Keep the Start first and the
	Finish last. The zone is 60 wide (right -30 to 30), 44 deep (back -22 to 22), 60 high.
]]
type Step = { -- (what one line may contain; leave this as it is)
	Kind: string,
	Offset: Vector3,
	Size: Vector3?,
	Rotation: (Vector3 | number)?,
	Spicy: boolean?,
	Label: string?,
	Text: string?,
}

-- stylua: ignore
local Course: { Step } = {
	-- Stage 1: Pumpkin Hop (up the left side)
	{ Kind = "Start", Offset = Vector3.new(-20, 1.5, -15) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-15, 3.5, -5.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-25, 5.5, -2), Size = Vector3.new(7, 4.5, 7) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-15.5, 7, 2.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-25, 8.5, 6.5), Size = Vector3.new(7, 4.5, 7) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-14, 10.5, 10.5), Size = Vector3.new(9, 5.5, 9) },
	{ Kind = "Checkpoint", Offset = Vector3.new(-24.5, 12.5, 16.5), Label = "Broomstick Bridge" },
	-- Stage 2: Broomstick Bridge (across the back; turned about -90 so the handles point right,
	-- tipped up 6 degrees so each broom climbs a little)
	{ Kind = "Broom", Offset = Vector3.new(-12.25, 14.5, 16.5), Rotation = Vector3.new(6, -86, 0) },
	{ Kind = "Broom", Offset = Vector3.new(0, 17, 16.5), Rotation = Vector3.new(6, -95, 0) },
	{ Kind = "Broom", Offset = Vector3.new(12.25, 19.5, 16.5), Rotation = Vector3.new(6, -88, 0) },
	{ Kind = "Checkpoint", Offset = Vector3.new(24.5, 22, 16.5), Label = "Graveyard Steps" },
	-- Stage 3: Graveyard Steps (down the right side), with a slimy crypt lid to jump across
	{ Kind = "Grave", Offset = Vector3.new(16, 24, 9.5), Rotation = Vector3.new(0, 8, 4), Text = "RIP\nSlow Pokey" },
	{ Kind = "Grave", Offset = Vector3.new(26, 26, 3.5), Rotation = Vector3.new(0, -6, -4), Text = "BOO!" },
	{ Kind = "Platform", Offset = Vector3.new(16, 27, -5.5), Size = Vector3.new(5, 1.5, 11), Spicy = true },
	{ Kind = "Hazard", Offset = Vector3.new(16, 27, -5.5), Size = Vector3.new(5, 0.4, 3) },
	{ Kind = "Grave", Offset = Vector3.new(25.5, 29, -14), Rotation = Vector3.new(0, 5, 3), Text = "Here lies\nMr. Bones" },
	{ Kind = "Checkpoint", Offset = Vector3.new(15, 31.5, -17), Label = "Candy Sky" },
	-- Stage 4: Candy Sky (up to the trophy)
	{ Kind = "Candy", Offset = Vector3.new(4.5, 33.5, -11.5) },
	{ Kind = "Bat", Offset = Vector3.new(-8, 35.5, -15.5) },
	{ Kind = "Candy", Offset = Vector3.new(-20, 37.5, -11) },
	{ Kind = "Bat", Offset = Vector3.new(-21, 39.5, 1), Rotation = 90 },
	{ Kind = "Candy", Offset = Vector3.new(-11, 42.5, 8), Size = Vector3.new(5.5, 1.4, 5.5), Spicy = true },
	{ Kind = "Finish", Offset = Vector3.new(-22, 45.5, 14) },
}

return {
	Name = "Spooky Sky Climb", -- shown on the start sign, the board and the menu

	-- Coins for reaching the top.
	Reward = {
		Coins = 100, -- coins for reaching the finish...
		CooldownHours = 20, -- ...at most once per this many hours (saved per player)
	},

	-- Rules the server checks (it never trusts the player's computer about these).
	MinSeconds = 15, -- a finish faster than this doesn't count (stops cheaters who teleport)
	MaxRunSeconds = 900, -- a run still going after this long stops by itself (15 minutes)
	CheckSeconds = 0.1, -- how often the server looks where every climber is
	FallMargin = 1, -- studs below the lowest pad (start, checkpoints) that count as "fell"
	FallGraceSeconds = 1.5, -- stepping off the start pad onto the ground this soon just stops the run
	TouchMargin = 1, -- studs past a pad's edge that still count as standing on it
	TouchHeight = 6, -- studs above a pad's top that still count (landing from a jump is fine)
	StartHeight = 11, -- the same for the start pad, so jumping on it doesn't start the clock
	HazardHeight = 3.5, -- studs above slime that still count as touching it
	TeleportGraceSeconds = 0.6, -- after being sent back, don't check that climber for this long
	LeaveDistance = 90, -- a climber further than this from every course pad has left: run stops
	SpeedTolerance = 1.5, -- moving faster than sprint speed x this between checks = cheating
	SpeedSlack = 8, -- extra studs allowed per check (bumps, lag)
	RequestCooldown = 2, -- seconds between "Go to start" / "Stop" requests from one player
	HintSeconds = 10, -- "Start on the START pad" shows at most this often (climbing without starting)
	LobbyRadius = 450, -- "Go to start" only works within this many studs of the hub centre
	BoardRows = 5, -- times listed on the board at the start

	-- How hard jumps may be. The game checks every jump in Course against these when it builds
	-- the course and warns in the Output window if one is too hard.
	Jumps = {
		MaxGap = 9, -- studs across, edge to edge, for a normal jump
		MaxRise = 5, -- studs up for a normal jump
		SpicyMaxGap = 10, -- the same for a piece marked Spicy = true (a harder jump)
		SpicyMaxRise = 5.5,
		Safety = 0.85, -- normal jumps use at most this share of the longest possible jump
		SpicySafety = 0.97, -- ...and spicy ones this share
		MinGap = -0.5, -- pieces may touch, but not overlap more than this
		Headroom = 10, -- studs kept between a piece and one hanging right above it
		HeadroomMargin = 1, -- extra studs around pieces for the head-room check
		-- A normal Roblox character (no sprinting): used to work out the longest jump.
		Character = { WalkSpeed = 16, JumpHeight = 7.2, Gravity = 196.2, Body = 1 },
	},

	-- What players see and hear (src/client/ParkourUI.luau).
	Text = {
		Ready = "Ready... jump!", -- on the start pad (the clock starts when you leave it)
		Timer = "%s", -- the time, e.g. 1:05.32
		CheckpointCount = "Checkpoint %d/%d",
		Checkpoint = "Checkpoint %d/%d!",
		Fell = "Whoops! Back to checkpoint %d",
		FellStart = "Whoops! Back to the start",
		Slimed = "Slimed! Back to checkpoint %d",
		SlimedStart = "Slimed! Back to the start",
		Missed = "You missed checkpoint %d!",
		NeedCheckpoints = "Touch every checkpoint first!",
		NeedStart = "Start on the START pad to win coins!",
		Finished = "You reached the top!",
		FinishTime = "Time: %s",
		NewBest = "New best!",
		Best = "Best: %s",
		Coins = "+%d %s",
		CoinsLater = "More coins in %s",
		Stopped = "Run stopped",
		TooFast = "Run stopped (too fast!)",
		Left = "You left the course",
		TimeUp = "Out of time! Try again",
		Stop = "Stop",
		-- The menu tile and its panel.
		Tile = "Parkour",
		PanelTitle = "Spooky Sky Climb",
		NoBest = "Not finished yet: can you reach the top?",
		Runs = "Times finished: %d",
		RewardReady = "Reward: %d %s for reaching the top!",
		RewardWait = "Next reward in %s (you can still climb for a best time)",
		GoToStart = "Go to start",
		Close = "Close",
		Teleported = "Jump off the start pad to start the clock!",
		InRound = "You're in a round right now!",
		NotInLobby = "You can only do that from the lobby.",
		NoCourse = "The parkour course isn't in this lobby.",
		Wait = "Wait a moment...",
		-- The board at the start.
		BoardTitle = "Fastest climbers",
		BoardEmpty = "Be the first to reach the top!",
		BoardRow = "%d. %s  %s", -- place, name, time
		BoardReward = "Reach the top: %d %s",
	},

	-- Sounds (Sounds.PlaySpec): SoundId "" = silent. Only the climber hears them.
	Sounds = {
		Start = {
			SoundId = "rbxassetid://134410911353980",
			Volume = 0.5,
			PitchMin = 1.2,
			PitchMax = 1.2,
		},
		Checkpoint = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.7,
			PitchMin = 1.25,
			PitchMax = 1.25,
		},
		Back = { SoundId = "rbxassetid://140334012603496", Volume = 0.5 }, -- fell or slimed
		Finish = { SoundId = "rbxassetid://1841209502", Volume = 0.7 },
		NewBest = { SoundId = "rbxassetid://9045119921", Volume = 0.6 },
	},

	-- Screen timings and colours.
	Screen = {
		PopSeconds = 1.6, -- "Checkpoint 2/3!" and "Whoops!" messages
		FinishSeconds = 5, -- the finish banner
		TimerGap = 6, -- space between the bar at the top and the timer
		Colors = {
			Timer = Color3.fromRGB(255, 200, 90),
			Checkpoint = Color3.fromRGB(120, 230, 120),
			Back = Color3.fromRGB(255, 150, 80),
			Finish = Color3.fromRGB(255, 210, 60),
			NewBest = Color3.fromRGB(140, 220, 255),
		},
	},

	-- How the pieces look (src/server/Hub/Sections/Parkour.luau).
	Look = {
		PumpkinTop = 0.75, -- share of a pumpkin's width that is flat on top to stand on
		Lights = true, -- glowing faces, lanterns and lights along the course
		Colors = {
			Pumpkin = Color3.fromRGB(255, 125, 25),
			PumpkinStem = Color3.fromRGB(90, 140, 60),
			Face = Color3.fromRGB(255, 205, 90), -- carved faces, lanterns
			Stone = Color3.fromRGB(125, 122, 135), -- start pad, checkpoints, graves
			Moss = Color3.fromRGB(95, 140, 80),
			Dirt = Color3.fromRGB(85, 60, 45),
			Wood = Color3.fromRGB(110, 75, 45), -- broom handles, signs
			Straw = Color3.fromRGB(215, 175, 85), -- broom bristles
			Candy = Color3.fromRGB(250, 245, 240),
			CandyStripe = Color3.fromRGB(225, 40, 60),
			Wrapper = Color3.fromRGB(255, 150, 200),
			Bat = Color3.fromRGB(70, 45, 95),
			BatEyes = Color3.fromRGB(255, 230, 80),
			Slime = Color3.fromRGB(110, 255, 90),
			Checkpoint = Color3.fromRGB(120, 255, 140), -- the glowing ring on checkpoints
			Start = Color3.fromRGB(255, 140, 30), -- the glowing ring on the start pad
			Finish = Color3.fromRGB(170, 90, 255), -- the finish platform's glow
			Hat = Color3.fromRGB(80, 40, 120), -- the witch hat on the trophy
			HatBand = Color3.fromRGB(255, 140, 30),
			Trophy = Color3.fromRGB(255, 200, 50), -- the golden trophy pumpkin
			Text = Color3.fromRGB(255, 225, 160),
			Board = Color3.fromRGB(30, 22, 40),
		},
	},

	-- Default size of each kind of piece (width, height, depth). A line in Course can give its
	-- own Size instead. The top of the piece is where you stand.
	Sizes = {
		Start = Vector3.new(10, 1.5, 10),
		Pumpkin = Vector3.new(8, 5, 8),
		Grave = Vector3.new(6.5, 7.5, 4.5), -- a headstone with a rounded top
		Broom = Vector3.new(3, 3, 10), -- long side = depth (the handle points "forward")
		Candy = Vector3.new(7, 1.4, 7),
		Bat = Vector3.new(10, 1.2, 4.5),
		Platform = Vector3.new(10, 1.5, 5),
		Checkpoint = Vector3.new(9, 1.4, 9),
		Finish = Vector3.new(14, 1.6, 14),
		Hazard = Vector3.new(4, 0.4, 4),
	},

	Course = Course, -- the list at the top of this file
}
