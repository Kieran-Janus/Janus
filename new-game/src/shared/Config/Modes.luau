--!strict
--[[
	GAME MODES AND PLAYLISTS (Config.Modes)

	A mode is a way to play (King Hunt, Hide & Seek, ScareMaze); its code is
	src/server/Modes/<Id>.luau and its on/off switch is Config.Features.<Feature>.
	Each mode in List has:
	  Name            what players see (top bar, vote, results)
	  Feature         the Config.Features switch that turns this mode on or off
	  Description     one short line about how to play
	  MinPlayers      the fewest ready players this mode works with
	  UsesDifficulty  true = the vote also asks Easy or Hard (King Hunt); false = no difficulty

	A playlist is one mode on one map. The vote before each round offers playlists:
	  Id          unique name, also the vote option id (don't rename once live)
	  Mode        a mode id from List below
	  Map         a map Id from Config.Maps.List (that map's Modes must include this mode)
	  Name        what players see on the vote button
	  MinPlayers  optional: a bigger number than the mode's MinPlayers if this map needs more
	              players (the playlist is only offered when this many players are ready)
	To add a new map to a mode: add a map file in Config/Maps/, then add a playlist here.
	To take a playlist out of the vote, delete its line (or switch its mode off in Features).
]]

return {
	-- Modes, in the order the vote shows them.
	Order = { "KingHunt", "HideSeek", "ScareMaze" },
	VoteChoices = 3, -- how many playlists the vote offers (picked at random from the ones that fit)
	-- Used when no playlist fits (too few players, or every mode switched off), so a round
	-- can always start.
	FallbackMode = "KingHunt",
	-- The owner's "Force mode" button (F8 panel) only exists in Studio playtests unless this
	-- is true. It picks the next round's playlist without a vote, to test modes alone.
	ForceModeInLiveServers = false,

	List = {
		KingHunt = {
			Name = "King Hunt",
			Feature = "KingHunt", -- Config.Features switch for this mode
			Description = "Grab pumpkins, stay quiet, don't get caught by the Pumpkin King!",
			MinPlayers = 1,
			UsesDifficulty = true,
		},
		HideSeek = {
			Name = "Pumpkin Hide & Seek",
			Feature = "HideSeek",
			Description = "Hiders are pumpkins. Seekers have candy guns. Find them all!",
			MinPlayers = 2,
			UsesDifficulty = false,
		},
		ScareMaze = {
			Name = "ScareMaze",
			Feature = "ScareMaze",
			Description = "Survivors run the maze, Haunters scare them. Don't stand still!",
			MinPlayers = 2,
			UsesDifficulty = false,
		},
	} :: {
		[string]: {
			Name: string,
			Feature: string,
			Description: string,
			MinPlayers: number,
			UsesDifficulty: boolean,
		},
	},

	Playlists = {
		{
			Id = "KingHuntPatch",
			Mode = "KingHunt",
			Map = "PumpkinPatch",
			Name = "King Hunt: Haunted Pumpkin Patch",
			MinPlayers = 1,
		},
		{
			Id = "KingHuntMansion",
			Mode = "KingHunt",
			Map = "SpookyMansion",
			Name = "King Hunt: Spooky Mansion",
			MinPlayers = 1,
		},
		{
			Id = "HideSeekFarm",
			Mode = "HideSeek",
			Map = "PumpkinFarm",
			Name = "Hide & Seek: Pumpkin Farm",
			MinPlayers = 2,
		},
		{
			Id = "HideSeekHedgeMaze",
			Mode = "HideSeek",
			Map = "HedgeMaze",
			Name = "Hide & Seek: Hedge Maze",
			MinPlayers = 2,
		},
		{
			Id = "ScareMaze",
			Mode = "ScareMaze",
			Map = "ScareMaze",
			Name = "ScareMaze",
			MinPlayers = 2,
		},
	} :: { { Id: string, Mode: string, Map: string, Name: string, MinPlayers: number? } },
}
