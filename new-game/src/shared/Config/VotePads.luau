--!strict
--[[
	VOTE PADS (Config.VotePads, switch: Config.Features.VotePads)

	Players vote by standing on a pad, not with buttons on the screen. The pads stand in a row in
	front of the Ready circle (lobby zone Config.Lobby.Zones.VotePads, built by
	src/server/Hub/Sections/VotePads.luau); each pad is also a Ready pad, so standing on one
	means "I'm ready AND I want this game".
	  1. Game vote (ModeSeconds): each pad shows one game (Config.Modes.Order). Stand on the
	     one you want; the game with the most players on its pad wins (a tie: picked at random).
	     A game that needs more ready players than there are says so and its votes don't count.
	     The map is then picked at random from that game's maps (Config.Modes.Playlists).
	  2. Difficulty vote (DifficultySeconds), only if the winning game has difficulty
	     (Config.Modes.List.<Id>.UsesDifficulty): the pads turn into EASY and HARD pads
	     (DifficultySlots). Nobody on them = Config.Difficulty.Default.
	Players standing on the Ready circle itself are ready but don't vote.
	Switched off (Config.Features.VotePads = false): the old vote panel on the screen comes back.

	The pads are parts tagged VotePad with a VoteSlot attribute (1, 2, 3 ...): move, resize or
	copy them in Studio and they keep working. A lobby saved in your place without pads gets
	them added when the game starts.
]]

return {
	ModeSeconds = 15, -- seconds to stand on the game you want
	DifficultySeconds = 8, -- seconds to stand on EASY or HARD (only for games with difficulty)
	-- Which pads become which difficulty in the difficulty vote (pad numbers, left to right as
	-- you look from the Ready circle). Pads in neither list are switched off for that part.
	DifficultySlots = {
		Easy = { 1, 2, 3 },
		Hard = { 4, 5, 6 },
	},

	-- The pads (how they look; changes show after F8 > Rebuild hub, or on a locked lobby when
	-- you delete its VotePads folder and press Play).
	Pads = 6, -- how many pads (one per game; extra games beyond this aren't offered)
	PadSize = 7, -- studs across each round pad
	Gap = 1.2, -- studs between two pads
	PadHeight = 0.5, -- studs thick
	LabelHeight = 6.5, -- studs above the pad that its floating name sign sits
	LabelMaxDistance = 90, -- studs: further away the sign is hidden

	-- Each game's pad colour and picture (an emoji). Games not listed use Default.
	Looks = {
		KingHunt = { Color = Color3.fromRGB(255, 140, 30), Icon = "👑" },
		HideSeek = { Color = Color3.fromRGB(255, 190, 60), Icon = "🎃" },
		ScareMaze = { Color = Color3.fromRGB(170, 90, 255), Icon = "👻" },
		PropHunt = { Color = Color3.fromRGB(90, 220, 120), Icon = "🪑" },
		ObbyRace = { Color = Color3.fromRGB(60, 200, 255), Icon = "🏃" },
		TileFall = { Color = Color3.fromRGB(150, 255, 90), Icon = "💀" },
		Default = { Color = Color3.fromRGB(200, 200, 210), Icon = "❓" },
		Easy = { Color = Color3.fromRGB(90, 230, 110), Icon = "😊" },
		Hard = { Color = Color3.fromRGB(255, 70, 70), Icon = "😈" },
		Off = { Color = Color3.fromRGB(60, 56, 70), Icon = "" },
	} :: { [string]: { Color: Color3, Icon: string } },

	Text = {
		Votes = "%d", -- the number of votes on a pad's sign
		NeedsPlayers = "Needs %d players", -- a game that needs more ready players
		ModeHint = "Stand on a pad to pick the game! %ds", -- the top bar during the game vote
		DifficultyHint = "%s: stand on EASY or HARD! %ds", -- game name, seconds left
		Waiting = "Stand on a pad to play!", -- the pads' signs between votes
		YourVote = "Your vote", -- under the sign of the pad you're standing on
		Board = "Stand on a game's pad by the Ready circle to vote!", -- the Voting Board during a vote
	},
}
