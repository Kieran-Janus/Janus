--!strict
--[[
	PARKOUR COURSE: "Spooky Sky Climb" (Config.Parkour)

	The climb behind the clock tower (on/off: Config.Features.Parkour; its area is
	Config.Lobby.Zones.Parkour). Stand on the START pad and climb about 60 jumps in 8 stages,
	spiralling up round the area: Pumpkin Hop, Broomstick Bridge, Graveyard Steps, Candy Sky, Bat
	Wings, Crypt Lids, Lantern Leap and Moonlight Summit. Each stage starts at a checkpoint (one every
	6-8 jumps), so a fall only costs you that stage. Touch the checkpoints in order and reach the
	glowing trophy pumpkin at the top. It starts super easy and gets only a little trickier near the
	top (slightly smaller pieces, slightly longer gaps): the hardest jump needs about 60% of a
	normal jump. The timer starts
	when you leave the start pad. Fall to the ground (or touch green slime) and you go back
	to your last checkpoint. Finishing gives coins once every Reward.CooldownHours.

	Change the course: edit the Course list just below. Each line is one piece. To add a
	jump, copy a line, paste it where it goes in the order and change its Offset. The Output
	window warns about any jump that is too far or too high for a normal player.
	Course changes show after the hub is rebuilt (F8 > Rebuild hub to try them, then
	Bake.Hub() or raise Config.Hub.BuildVersion). A hub saved in the place, or Locked, keeps
	the course it was built with: move its pieces in Studio instead. Rewards, times and words
	work straight away, also on a saved hub.
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
	Checkpoints are numbered 1, 2, 3... in the order they appear. Keep the Start first and the
	Finish last. The zone is 76 wide (right -38 to 38), 48 deep (back -24 to 24), 120 high.
	The course below was laid out on an oval (28 studs to each side, 17 forward and back) by a
	one-off script, then checked with ParkourLogic.Check (tests/specs/parkour.spec.luau): every
	jump is easy, and each lap climbs high enough that nothing hangs over your head (Headroom).
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
	-- Stage 1: Pumpkin Hop
	{ Kind = "Start", Offset = Vector3.new(-9.6, 1.5, -16) },
	{ Kind = "Pumpkin", Offset = Vector3.new(1.2, 3.2, -17), Size = Vector3.new(8.6, 5, 8.6) },
	{ Kind = "Pumpkin", Offset = Vector3.new(10, 5.1, -15.9), Size = Vector3.new(8.6, 5, 8.6) },
	{ Kind = "Pumpkin", Offset = Vector3.new(18.5, 7, -12.7), Size = Vector3.new(8.5, 5, 8.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(25.5, 8.4, -7.1), Size = Vector3.new(8.5, 5, 8.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(27.9, 10.1, 1.7), Size = Vector3.new(8.5, 5, 8.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(23.1, 12.1, 9.6), Size = Vector3.new(8.5, 5, 8.5) },
	{ Kind = "Pumpkin", Offset = Vector3.new(15.2, 13.7, 14.3), Size = Vector3.new(8.4, 5, 8.4) },
	-- Stage 2: Broomstick Bridge
	{ Kind = "Checkpoint", Offset = Vector3.new(5.4, 14.9, 16.7), Label = "Broomstick Bridge" },
	{ Kind = "Broom", Offset = Vector3.new(-7.3, 16.7, 16.4), Size = Vector3.new(5, 3, 11), Rotation = 99 },
	{ Kind = "Broom", Offset = Vector3.new(-20.7, 18.7, 11.4), Size = Vector3.new(5, 3, 11), Rotation = 124 },
	{ Kind = "Broom", Offset = Vector3.new(-28, 20.5, -0.1), Size = Vector3.new(5, 3, 11), Rotation = -179 },
	{ Kind = "Broom", Offset = Vector3.new(-20.5, 21.9, -11.6), Size = Vector3.new(5, 3, 11), Rotation = -123 },
	{ Kind = "Broom", Offset = Vector3.new(-7.1, 23.8, -16.4), Size = Vector3.new(5, 3, 11), Rotation = -99 },
	{ Kind = "Broom", Offset = Vector3.new(7.4, 25.7, -16.4), Size = Vector3.new(5, 3, 11), Rotation = -81 },
	-- Stage 3: Graveyard Steps
	{ Kind = "Checkpoint", Offset = Vector3.new(19.3, 26.9, -12.3), Label = "Graveyard Steps" },
	{ Kind = "Grave", Offset = Vector3.new(27.1, 30.1, -4.2), Size = Vector3.new(6.7, 5.5, 4.8), Rotation = 67, Text = "RIP\nSlow Pokey" },
	{ Kind = "Grave", Offset = Vector3.new(25.6, 31.9, 6.9), Size = Vector3.new(6.7, 5.5, 4.8), Rotation = 126, Text = "BOO!" },
	{ Kind = "Grave", Offset = Vector3.new(17.6, 33.9, 13.2), Size = Vector3.new(6.7, 5.5, 4.8), Rotation = 154, Text = "Here lies\nMr. Bones" },
	{ Kind = "Platform", Offset = Vector3.new(5.3, 35.3, 16.7), Size = Vector3.new(12, 1.5, 5), Rotation = 173 },
	{ Kind = "Hazard", Offset = Vector3.new(5.3, 35.3, 16.7), Size = Vector3.new(3, 0.4, 5), Rotation = 173 },
	{ Kind = "Grave", Offset = Vector3.new(-7.7, 37.3, 16.3), Size = Vector3.new(6.7, 5.5, 4.8), Rotation = -170, Text = "Gone\nbatty" },
	{ Kind = "Grave", Offset = Vector3.new(-17.7, 39.3, 13.2), Size = Vector3.new(6.7, 5.5, 4.8), Rotation = -154, Text = "Back\nsoon" },
	-- Stage 4: Candy Sky
	{ Kind = "Checkpoint", Offset = Vector3.new(-25.8, 40.5, 6.6), Label = "Candy Sky" },
	{ Kind = "Candy", Offset = Vector3.new(-26.7, 42.4, -5.2), Size = Vector3.new(7, 1.4, 7) },
	{ Kind = "Candy", Offset = Vector3.new(-19, 44.4, -12.5), Size = Vector3.new(7, 1.4, 7) },
	{ Kind = "Candy", Offset = Vector3.new(-9, 46.3, -16.1), Size = Vector3.new(6.9, 1.4, 6.9) },
	{ Kind = "Candy", Offset = Vector3.new(1.6, 47.7, -17), Size = Vector3.new(6.9, 1.4, 6.9) },
	{ Kind = "Candy", Offset = Vector3.new(12.3, 49.5, -15.3), Size = Vector3.new(6.9, 1.4, 6.9) },
	{ Kind = "Candy", Offset = Vector3.new(21.8, 51.4, -10.7), Size = Vector3.new(6.9, 1.4, 6.9) },
	{ Kind = "Candy", Offset = Vector3.new(27.8, 53.3, -1.9), Size = Vector3.new(6.8, 1.4, 6.8) },
	-- Stage 5: Bat Wings
	{ Kind = "Checkpoint", Offset = Vector3.new(24.7, 54.5, 8), Label = "Bat Wings" },
	{ Kind = "Bat", Offset = Vector3.new(13.6, 56.5, 14.8), Size = Vector3.new(9.2, 1.2, 4.7), Rotation = 161 },
	{ Kind = "Bat", Offset = Vector3.new(0.4, 58.5, 17), Size = Vector3.new(9.2, 1.2, 4.7), Rotation = 180 },
	{ Kind = "Bat", Offset = Vector3.new(-12.9, 60.4, 15.1), Size = Vector3.new(9.2, 1.2, 4.7), Rotation = -163 },
	{ Kind = "Bat", Offset = Vector3.new(-24.7, 61.8, 8), Size = Vector3.new(9.2, 1.2, 4.7), Rotation = -131 },
	{ Kind = "Bat", Offset = Vector3.new(-26.9, 63.8, -4.8), Size = Vector3.new(9.1, 1.2, 4.7), Rotation = -64 },
	{ Kind = "Bat", Offset = Vector3.new(-16.4, 65.8, -13.8), Size = Vector3.new(9.1, 1.2, 4.6), Rotation = -24 },
	-- Stage 6: Crypt Lids
	{ Kind = "Checkpoint", Offset = Vector3.new(-5.2, 67, -16.7), Label = "Crypt Lids" },
	{ Kind = "Platform", Offset = Vector3.new(7.6, 69.1, -16.4), Size = Vector3.new(8.4, 1.5, 4.7), Rotation = 10 },
	{ Kind = "Platform", Offset = Vector3.new(20, 71, -11.9), Size = Vector3.new(8.4, 1.5, 4.7), Rotation = 32 },
	{ Kind = "Platform", Offset = Vector3.new(28, 73, -1), Size = Vector3.new(12, 1.5, 5), Rotation = 85 },
	{ Kind = "Hazard", Offset = Vector3.new(28, 73, -1), Size = Vector3.new(3, 0.4, 5), Rotation = 85 },
	{ Kind = "Platform", Offset = Vector3.new(21.6, 74.4, 10.8), Size = Vector3.new(8.3, 1.5, 4.7), Rotation = 144 },
	{ Kind = "Platform", Offset = Vector3.new(9.7, 76.5, 16), Size = Vector3.new(8.3, 1.5, 4.7), Rotation = 167 },
	{ Kind = "Platform", Offset = Vector3.new(-3.3, 78.6, 16.9), Size = Vector3.new(8.3, 1.5, 4.6), Rotation = -176 },
	-- Stage 7: Lantern Leap
	{ Kind = "Checkpoint", Offset = Vector3.new(-14.2, 79.8, 14.7), Label = "Lantern Leap" },
	{ Kind = "Pumpkin", Offset = Vector3.new(-24.4, 81.7, 8.3), Size = Vector3.new(7.4, 5, 7.4) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-27.9, 83.8, -1.2), Size = Vector3.new(7.4, 5, 7.4) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-22.4, 85.9, -10.2), Size = Vector3.new(7.4, 5, 7.4) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-13.4, 87.3, -14.9), Size = Vector3.new(7.3, 5, 7.3) },
	{ Kind = "Pumpkin", Offset = Vector3.new(-3.4, 89.3, -16.9), Size = Vector3.new(7.3, 5, 7.3) },
	{ Kind = "Pumpkin", Offset = Vector3.new(7, 91.3, -16.5), Size = Vector3.new(7.3, 5, 7.3) },
	{ Kind = "Pumpkin", Offset = Vector3.new(16.9, 93.4, -13.6), Size = Vector3.new(7.2, 5, 7.2) },
	-- Stage 8: Moonlight Summit
	{ Kind = "Checkpoint", Offset = Vector3.new(24.7, 94.6, -8), Label = "Moonlight Summit" },
	{ Kind = "Candy", Offset = Vector3.new(27.1, 96.6, 4.3), Size = Vector3.new(6.2, 1.4, 6.2) },
	{ Kind = "Bat", Offset = Vector3.new(17.9, 98.8, 13.1), Size = Vector3.new(8.7, 1.2, 4.5), Rotation = 153 },
	{ Kind = "Candy", Offset = Vector3.new(5.9, 100.8, 16.6), Size = Vector3.new(6.1, 1.4, 6.1) },
	{ Kind = "Platform", Offset = Vector3.new(-8.3, 102.2, 16.2), Size = Vector3.new(12, 1.5, 5), Rotation = -169 },
	{ Kind = "Hazard", Offset = Vector3.new(-8.3, 102.2, 16.2), Size = Vector3.new(3, 0.4, 5), Rotation = -169 },
	{ Kind = "Bat", Offset = Vector3.new(-22.9, 104.4, 9.7), Size = Vector3.new(8.6, 1.2, 4.4), Rotation = -139 },
	{ Kind = "Candy", Offset = Vector3.new(-27.7, 106.4, -2.3), Size = Vector3.new(6.1, 1.4, 6.1) },
	{ Kind = "Finish", Offset = Vector3.new(-19.3, 107.4, -12.3) },
}

return {
	Name = "Spooky Sky Climb", -- shown on the start sign, the board and the menu

	-- Coins for reaching the top.
	Reward = {
		Coins = 300, -- coins for reaching the finish (a long climb: about 60 jumps)...
		CooldownHours = 20, -- ...at most once per this many hours (saved per player)
	},

	-- Rules the server checks (it never trusts the player's computer about these).
	MinSeconds = 45, -- a finish faster than this doesn't count (stops cheaters who teleport)
	MaxRunSeconds = 1800, -- a run still going after this long stops by itself (30 minutes)
	CheckSeconds = 0.1, -- how often the server looks where every climber is
	FallMargin = 1, -- studs below the lowest pad (start, checkpoints) that count as "fell"
	-- studs below your last checkpoint that count as "fell" too (the course spirals up, so a
	-- fall usually lands on a lower loop instead of the ground: you go back to the checkpoint)
	FallBelowCheckpoint = 6,
	FallGraceSeconds = 1.5, -- stepping off the start pad onto the ground this soon just stops the run
	TouchMargin = 1, -- studs past a pad's edge that still count as standing on it
	TouchHeight = 6, -- studs above a pad's top that still count (landing from a jump is fine)
	StartHeight = 11, -- the same for the start pad, so jumping on it doesn't start the clock
	HazardHeight = 3.5, -- studs above slime that still count as touching it
	TeleportGraceSeconds = 0.6, -- after being sent back, don't check that climber for this long
	LeaveDistance = 90, -- a climber further than this from every course pad has left: run stops
	-- Anti-teleport (src/shared/SpeedCheck.luau): a climber who moves faster than this stops.
	SpeedTolerance = 1.5, -- moving sideways faster than sprint speed x this = cheating
	SpeedSlack = 8, -- extra sideways studs allowed (bumps, lag), once per SpeedWindowSeconds
	MaxRiseSpeed = 14, -- studs per second a climber can go UP (jumping from piece to piece)...
	RiseSlack = 8, -- ...plus this many studs (one jump), so flying straight up is caught
	SpeedWindowSeconds = 1, -- the slack only counts once in this many seconds, not every check
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
		-- Free space above every jump, from the higher of its two tops to the bottom of anything
		-- hanging over it: a jump goes 7.2 studs up and a character is 5 tall.
		Headroom = 12.5,
		HeadroomMargin = 2, -- studs either side of a jump's line kept clear (your body is ~2 wide)
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

	-- Little celebrations on the climber's screen (src/client/ParkourUI.luau; the Tormented
	-- Tower uses the same ones). Only for fun: the server still decides every checkpoint, time
	-- and best. Shared numbers: Config.Minigames.Effects.
	Effects = {
		On = true, -- false = no bursts, fireworks, confetti or pops (the course is the same)
		CheckpointSparkles = 26, -- sparkles bursting up from a checkpoint you reach (phones: fewer)
		CheckpointColors = {
			Color3.fromRGB(120, 230, 120),
			Color3.fromRGB(255, 230, 120),
			Color3.fromRGB(255, 255, 255),
		},
		Fireworks = 3, -- bursts in the sky over the finish
		FireworkSparkles = 30, -- sparkles in each one (phones: fewer)
		FireworkHeight = 14, -- studs above the finish they go off
		FireworkGap = 0.35, -- seconds between them
		FinishConfetti = 50, -- confetti pieces when you finish (phones: fewer)
		NewBestConfetti = 90, -- confetti pieces for a new best time (instead of the above)
		NewBestText = "NEW BEST!", -- the big words for a new best time
		NewBestSeconds = 2.2, -- how long they stay up
		TickBump = 1.03, -- the running timer swells this much on every whole second (1 = never)
	},

	-- How the pieces look (src/server/Hub/Sections/Parkour.luau).
	Look = {
		PumpkinTop = 0.75, -- share of a pumpkin's width that is flat on top to stand on
		Lights = true, -- lights at the start, the checkpoints, the slime and the finish
		-- false = the pumpkins, candies and graves glow (neon) without a light of their own: a
		-- 60-piece course would use too many lights for phones (Config.Hub.Budget).
		PieceLights = false,
		-- The rock island under the finish: how many rings, how tall each, how much smaller each
		-- ring is (share of the pad). Tiers x TierHeight must stay within Hang.Finish below.
		Island = { Tiers = 2, TierHeight = 1.9, Shrink = 0.3 },
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
		Broom = Vector3.new(5, 3, 11), -- long side = depth (the handle points "forward"); 5 wide: easy to land on
		Candy = Vector3.new(7, 1.4, 7),
		Bat = Vector3.new(10, 1.2, 4.5),
		Platform = Vector3.new(10, 1.5, 5),
		Checkpoint = Vector3.new(9, 1.4, 9),
		Finish = Vector3.new(14, 1.6, 14),
		Hazard = Vector3.new(4, 0.4, 4),
	},

	-- How far each kind's solid decoration hangs below its Size (the crypt's dirt, the
	-- bat's round body, the rock island under the finish). The head-room check adds it, so
	-- nothing solid can catch your head mid-jump. Make it bigger if you add something solid
	-- underneath a piece.
	Hang = {
		Grave = 0,
		Platform = 1.9,
		Bat = 1.8,
		Candy = 1,
		Broom = 1.1,
		Finish = 3.8,
	},

	Course = Course, -- the list at the top of this file
}
