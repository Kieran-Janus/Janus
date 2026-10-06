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
		Parkour = { Offset = Vector3.new(0, 0, -82), Size = Vector3.new(76, 0, 48), Height = 120 },
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
				Offset = Vector3.new(-23, 0, -55),
				LookAt = Vector3.new(-23, 0, -80),
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
		-- Lobby parts in a Model with one of these names stay walk-through (the Web Scour webs,
		-- the glowing rune circle, mist and fireflies, and the parkour course's decorations:
		-- its steps are solid already and the jumps are measured without the decorations).
		KeepAreas = { "Webs", "Runes", "Mist", "Fireflies", "FloatingCandles", "Course" },
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
