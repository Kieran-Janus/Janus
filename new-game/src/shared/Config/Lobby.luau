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
		ReadyArea = { Offset = Vector3.new(0, 0, 48), Size = Vector3.new(22, 0, 18) },
		Shop = { Offset = Vector3.new(40, 0, -18), Size = Vector3.new(22, 0, 18) },
		CandyRush = { Offset = Vector3.new(-60, 0, 0), Size = Vector3.new(30, 0, 26) },
		WebScour = { Offset = Vector3.new(-38, 0, -32), Size = Vector3.new(32, 0, 26) },
		Parkour = { Offset = Vector3.new(0, 0, -80), Size = Vector3.new(60, 0, 44), Height = 60 },
	} :: { [string]: { Offset: Vector3, Size: Vector3, Height: number? } },

	-- The Ready pad (Config.Features.ReadyPad): stand on it to join the next round.
	Ready = {
		MinReady = 1, -- a vote starts once this many players are ready
		CheckSeconds = 0.25, -- how often the server checks who is standing on the pad
		PadHeight = 8, -- studs above the pad's top that still count as standing on it (jumping is fine)
		VoteOnlyReady = true, -- true = only ready players can vote
		PadText = "Stand here to play!",
	},

	-- Watching the round from the lobby (Config.Features.LobbySpectate): Menu > Spectate.
	Spectate = {
		NextKey = Enum.KeyCode.X, -- next player (E is taken by prompts, Q/G/H/T by other actions)
		PreviousKey = Enum.KeyCode.Z, -- previous player
		NextButton = Enum.KeyCode.ButtonR1, -- the same on a gamepad
		PreviousButton = Enum.KeyCode.ButtonL1,
		Text = {
			Watching = "Watching %s", -- %s = the player's name
			King = "Watching the Pumpkin King",
			Nobody = "Nobody is playing right now.",
			Next = "Next",
			Previous = "Back",
			Stop = "Stop watching",
		},
	},
}
