--!strict
--[[
	LOBBY LAYOUT, READY PAD AND SPECTATING (Config.Lobby)

	Zones are areas of the lobby kept free for one thing each (the Ready pad, the shop, the
	minigames, the parkour course). Decorations are never placed inside a zone.
	  Offset  where the zone's centre is, in studs from Config.Hub.Center (x = east/west,
	          z = north/south; y is ignored: zones sit on the plaza)
	  Size    width (x) and depth (z) in studs; y is unused
	  Height  optional: how tall the zone is (only the parkour course needs one)
	Each zone faces the middle of the hub, so its front edge points at the plaza centre.
	Move a zone by changing its Offset; src/shared/Lobby.luau turns these into positions.
]]

return {
	Zones = {
		ReadyArea = { Offset = Vector3.new(0, 0, 46), Size = Vector3.new(22, 0, 18) }, -- right in front of the spawn
		Shop = { Offset = Vector3.new(40, 0, -18), Size = Vector3.new(22, 0, 18) },
		CandyRush = { Offset = Vector3.new(-60, 0, 0), Size = Vector3.new(30, 0, 26) },
		WebScour = { Offset = Vector3.new(-38, 0, -32), Size = Vector3.new(32, 0, 26) },
		-- (the course spirals up to about 90 studs; deeper at the back, so its front still clears
		-- the clock tower)
		Parkour = { Offset = Vector3.new(0, 0, -86), Size = Vector3.new(76, 0, 48), Height = 120 },
		Crates = { Offset = Vector3.new(46, 0, 6), Size = Vector3.new(20, 0, 12) }, -- crate stand by the shop
	} :: { [string]: { Offset: Vector3, Size: Vector3, Height: number? } },

	-- The Ready pad (Config.Features.ReadyPad): stand on it to join the next round.
	-- The pad is any part tagged ReadyPad (src/shared/Tags.luau): move, resize, recolour or
	-- duplicate it in Studio and it keeps working. Round pads (cylinders) work too.
	-- With no ReadyPad part in the game, everyone in the lobby counts as ready (a warning
	-- in the Output window says so), so rounds still start.
	Ready = {
		-- A vote starts once this many players are ready (2 = never alone). Never fewer than the
		-- switched-on modes need (Config.Modes MinPlayers): with only Hide & Seek on, that's 2.
		MinReady = 1,
		CheckSeconds = 0.25, -- how often the server checks who is standing on the pad
		PadHeight = 12, -- studs above the pad's top that still count as standing on it (jumping is fine)
		EdgeMargin = 1, -- studs past the pad's edge that still count (feet hanging over the side)
		LeaveGraceSeconds = 1, -- stepping off for less than this doesn't un-ready you (wobbles, jumps)
		-- true = only ready players can vote (others see the vote greyed out; on phones they
		-- only see the "stand on the pad" hint, so the vote doesn't cover a small screen)
		VoteOnlyReady = true,
		PadText = "Stand here to play!",
		Text = { -- shown on the top bar and the vote panel
			Count = "Ready: %d/%d", -- ready players / players needed
			StandOnPad = "Stand on the Ready pad to play",
			YoureReady = "You're ready!",
			NextRound = "Stand on the Ready pad to play next round",
			ReadyNextRound = "You're ready for the next round",
			VoteHint = "Stand on the Ready pad to vote",
		},
	},

	-- Glowing floor signs (src/server/Hub/FloorSigns.luau): a flat pad on the ground in front of
	-- each lobby area with big glowing words, readable from far away. Each pad is its own part,
	-- named "<Zone>FloorSign" and tagged FloorSign, so you can move, turn or resize it in Studio.
	-- (Changing words, colours or sizes here shows after the hub is rebuilt: F8 > Rebuild hub
	-- or Bake.Hub(); a sign only shows while its Feature is on.)
	FloorSigns = {
		On = true, -- false = no floor signs
		Size = Vector3.new(24, 0.2, 7), -- width, thickness, depth of each pad (studs)
		Gap = 2, -- studs between the area's edge and its sign
		PadColor = Color3.fromRGB(24, 16, 34), -- the dark pad under the words
		Font = Enum.Font.FredokaOne,
		Glow = 3, -- how brightly the words glow (1 = like paint, higher = glowing)
		LightRange = 14, -- a soft light of the sign's colour over each pad (0 = none)
		-- One per area. Side = "Front" (the side facing the middle of the lobby) or "Back"
		-- (the far side: the Ready pad is reached from the spawn, behind it). Or give it its own
		-- spot: Offset = studs from Config.Hub.Center, LookAt = the spot its words face (the
		-- parkour's front is behind the clock tower, so its sign sits beside the tower). Width =
		-- its own width in studs (instead of Size.X).
		Signs = {
			{
				Zone = "ReadyArea",
				Text = "READY? STEP IN!",
				Color = Color3.fromRGB(70, 255, 225),
				Feature = "ReadyPad",
				-- between the pumpkin arch and the spawn stone, facing the pad, narrow enough
				-- to fit between the arch's pillars
				Offset = Vector3.new(0, 0, 59.2),
				LookAt = Vector3.new(0, 0, 46),
				Width = 10,
			},
			{
				Zone = "Shop",
				Text = "PUMPKIN SHOP",
				Color = Color3.fromRGB(255, 150, 40),
				Feature = "",
			},
			{
				Zone = "Crates",
				Text = "MYSTERY CRATES",
				Color = Color3.fromRGB(255, 80, 220),
				Feature = "Crates",
			},
			{
				Zone = "CandyRush",
				Text = "CANDY RUSH",
				Color = Color3.fromRGB(255, 110, 160),
				Feature = "CandyRush",
			},
			{
				Zone = "WebScour",
				Text = "WEB SCOUR",
				Color = Color3.fromRGB(150, 255, 90),
				Feature = "WebScour",
			},
			{
				Zone = "Parkour",
				Text = "PARKOUR",
				Color = Color3.fromRGB(255, 220, 60),
				Feature = "Parkour",
				Offset = Vector3.new(-26, 0, -58),
				LookAt = Vector3.new(-26, 0, -84),
			},
			{
				Zone = "TowerParkour", -- the Tormented Tower's doorway (Config.TowerParkour)
				Text = "TORMENTED TOWER - only the bravest",
				Color = Color3.fromRGB(255, 60, 70),
				Feature = "TowerParkour",
				Offset = Vector3.new(0, 0, -29), -- in front of the clock tower's door
				LookAt = Vector3.new(0, 0, -47),
				Width = 16,
			},
		} :: {
			{
				Zone: string,
				Text: string,
				Color: Color3,
				Feature: string,
				Side: string?,
				Offset: Vector3?,
				LookAt: Vector3?,
				Width: number?,
			}
		},
	},

	-- A solid lobby (src/server/Hub/HubSolid.luau): when the game starts, every decoration you
	-- would expect to bump into or stand on is made solid (trees, lampposts, benches, gravestones,
	-- crates, hay, fences, statues, the cauldron, stalls, stands, the mansion, big pumpkins...).
	-- This also works on a lobby saved in your place and on your own models from
	-- ReplicatedStorage.Custom.Props. What stays walk-through:
	Solid = {
		On = true, -- false = leave every decoration as it was built
		MinSize = 2.5, -- studs: pieces smaller than this (their longest side) stay walk-through
		StepHeight = 1.25, -- studs: low things you'd just step over (curbs, path stones, rugs)
		MaxTransparency = 0.6, -- more see-through than this (mist, glow, light beams) stays walk-through
		-- Decorations (their PropName attribute) that always stay walk-through: they hang in the
		-- air or are webs you need to reach through.
		KeepWalkThrough = {
			"Cobweb",
			"Candle",
			"Bat",
			"ParkourBat",
			"Lantern",
			"Mushroom",
			"GroveSpider",
		},
		-- Lobby parts in a group (Folder or Model) with one of these names stay walk-through (the Web Scour webs,
		-- the glowing rune circle, mist and fireflies, and the parkour course's decorations:
		-- its steps are solid already and the jumps are measured without the decorations).
		KeepAreas = { "Webs", "Runes", "Mist", "Fireflies", "FloatingCandles", "Course" },
	},

	-- The lobby comes alive (src/client/LobbyLife.luau): small animations each player's own
	-- screen plays, so the server never moves anything. Only things within Range studs of the
	-- camera move (PhoneRange on phones); everything goes back exactly where it was when the
	-- camera moves away. Each part has its own On switch; On = false here switches all of it off.
	-- Nothing made here can be bumped into, clicked or touched.
	Life = {
		On = true, -- false = no lobby life at all
		Range = 120, -- studs from the camera: closer than this animates
		PhoneRange = 80, -- the same on phones (less work for small devices)
		-- The Pumpkin Shop keeper (any Model tagged ShopKeeper holding a character Model named
		-- in Models: the built "Keeper" or your custom "Look"). It breathes, turns to face the
		-- nearest player and waves when one walks up. A custom model without arm parts does a
		-- little happy wiggle instead.
		Keeper = {
			On = true, -- false = the keeper stands still
			Models = { "Keeper", "Look" }, -- names of the character models inside the NPC
			ArmNames = { "Arm", "RightArm", "Right Arm", "RightUpperArm" }, -- parts that can wave
			BreathHeight = 0.12, -- studs the keeper rises and sinks while breathing
			BreathSpeed = 1.8, -- breathing speed (bigger = faster)
			TurnRange = 28, -- studs: a player closer than this gets looked at
			MaxTurn = 50, -- degrees the keeper may turn left or right from its counter
			TurnSpeed = 3, -- how quickly it turns (bigger = snappier)
			WaveDistance = 14, -- studs: walking this close makes it wave
			WaveRearm = 6, -- extra studs you must walk away before it waves again
			WaveSeconds = 1.8, -- how long a wave lasts
			WaveRaise = 120, -- degrees the arm lifts to wave
			WaveSwing = 25, -- degrees the raised arm swings side to side
			WaveSwings = 3, -- how many swings in one wave
			WiggleAngle = 8, -- degrees of the whole-body wiggle (models without arms)
			WiggleHop = 0.5, -- studs of the little hop in that wiggle
		},
		-- A soft glowing ring round every Ready pad (tag ReadyPad) that pulses, faster while
		-- someone is ready, and the floating READY sign (tag ReadySign) does a little bounce
		-- whenever the number of ready players changes.
		ReadyPad = {
			On = true, -- false = no ring and no bounce
			Color = Color3.fromRGB(70, 255, 225), -- the ring's colour
			RingWidth = 1.6, -- studs the ring reaches past the pad's edge
			Brightest = 0.45, -- ring transparency at the top of a pulse (0 = solid)
			Faintest = 0.85, -- ring transparency at the bottom of a pulse (1 = invisible)
			Grow = 0.08, -- how much bigger the ring gets at the top of a pulse (0.08 = 8%)
			SlowSpeed = 1.6, -- pulse speed with nobody ready
			FastSpeed = 5, -- pulse speed while someone is ready
			BounceHeight = 1.2, -- studs the sign hops when the count changes
			BounceSeconds = 0.6, -- how long the hop lasts
			BounceHops = 2, -- hops per bounce
		},
		-- The glowing floor signs (tag FloorSign) shimmer like wet glowing paint.
		FloorSigns = {
			On = true, -- false = signs stay steady
			Speed = 1.3, -- shimmer speed
			TextFade = 0.22, -- how far the words fade at the dimmest point (0 = never, 1 = gone)
			FrameFade = 0.35, -- the same for the thin glowing frame
			LightDip = 0.3, -- the sign's light dims by this share at its dimmest
			UpdatesPerSecond = 12, -- how often the shimmer updates (fewer = cheaper)
		},
		-- The cauldron in the middle of the plaza (a prop named "Cauldron") puffs green bubbles
		-- now and then, and its "Bubble" parts bob in the brew.
		Cauldron = {
			On = true, -- false = a still cauldron
			Color = Color3.fromRGB(140, 255, 120), -- the puffs' colour
			EveryMin = 1.5, -- seconds between puffs (a random time between these two)
			EveryMax = 3.5,
			Puffs = 6, -- bubbles in one puff
			PhonePuffs = 3, -- the same on phones
			BubbleBob = 0.25, -- studs the brew's bubbles bob
			BubbleSpeed = 2.2, -- bubbling speed
			ScanSeconds = 6, -- how often to look for the cauldron until it is found
		},
		-- Now and then a little bat flaps across the sky near you while you are in the lobby.
		Bats = {
			On = true, -- false = no bats
			Max = 2, -- most bats flying at once
			PhoneMax = 1, -- the same on phones
			EveryMin = 6, -- seconds between bats (a random time between these two)
			EveryMax = 14,
			Height = 22, -- studs above the camera they fly
			Distance = 30, -- studs in front of the camera their path passes
			Span = 140, -- studs each bat flies before vanishing
			Speed = 22, -- studs per second
			FlapSpeed = 14, -- wing beats speed
			FlapAngle = 40, -- degrees the wings beat
			Size = 1.4, -- body size in studs (wings are wider)
			Color = Color3.fromRGB(30, 22, 40),
			HubRadius = 200, -- only while the camera is this close to the lobby's spawn (tag HubSpawn)
		},
	},

	-- Watching the round from the lobby (Config.Features.LobbySpectate): Menu > Spectate, or the
	-- "Watch the round" button the lobby shows while a round is being played.
	-- Keys: change the lists below (keyboard keys and gamepad buttons both work).
	Spectate = {
		NextKeys = { Enum.KeyCode.E, Enum.KeyCode.Right, Enum.KeyCode.ButtonR1 }, -- next player
		PreviousKeys = { Enum.KeyCode.Q, Enum.KeyCode.Left, Enum.KeyCode.ButtonL1 }, -- previous player
		ShowWatchButton = true, -- false = only the Menu's Spectate tile starts watching
		MessageSeconds = 2.5, -- how long "Nobody is playing right now." stays up
		Text = {
			Watching = "Watching %s", -- %s = the player's name
			King = "Watching the Pumpkin King",
			Nobody = "Nobody is playing right now.",
			NobodyLeft = "Nobody left to watch",
			Next = "Next",
			Previous = "Back",
			Stop = "Stop",
			WatchButton = "Watch the round",
		},
	},
}
