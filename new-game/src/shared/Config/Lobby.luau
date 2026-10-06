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
		Parkour = { Offset = Vector3.new(0, 0, -80), Size = Vector3.new(60, 0, 44), Height = 60 },
		Crates = { Offset = Vector3.new(46, 0, 6), Size = Vector3.new(20, 0, 12) }, -- crate stand by the shop
	} :: { [string]: { Offset: Vector3, Size: Vector3, Height: number? } },

	-- The Ready pad (Config.Features.ReadyPad): stand on it to join the next round.
	-- The pad is any part tagged ReadyPad (src/shared/Tags.luau): move, resize, recolour or
	-- duplicate it in Studio and it keeps working. Round pads (cylinders) work too.
	-- With no ReadyPad part in the game, everyone in the lobby counts as ready (a warning
	-- in the Output window says so), so rounds still start.
	Ready = {
		MinReady = 1, -- a vote starts once this many players are ready (2 = never alone)
		CheckSeconds = 0.25, -- how often the server checks who is standing on the pad
		PadHeight = 12, -- studs above the pad's top that still count as standing on it (jumping is fine)
		EdgeMargin = 1, -- studs past the pad's edge that still count (feet hanging over the side)
		LeaveGraceSeconds = 1, -- stepping off for less than this doesn't un-ready you (wobbles, jumps)
		VoteOnlyReady = true, -- true = only ready players can vote (others see the vote greyed out)
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
