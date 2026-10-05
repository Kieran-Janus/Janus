--!strict
--[[
	The shapes every game mode uses. A mode is a module in this folder (src/server/Modes/<Id>.luau,
	Id = a key of Config.Modes.List) with:

	  Mode.Run(ctx: RoundContext) -> RoundResult
	      Plays one round. It yields for the whole round and cleans up after itself (stops its
	      NPCs, removes what it spawned, disconnects its events). GameService has already loaded
	      the map, marked the players InRound and published the Mode/ModeName attributes; after
	      Run returns it rewards the rows, shows the results and sends everyone to the lobby.
	  Mode.Cleanup()   (optional)
	      Called only if Run broke part-way (an error) or ran past Config.Round.SafetyLimitSeconds:
	      stop anything Run started. Must be safe to call when nothing is running.

	GameService handles everything that is the same for every mode: the vote, the map, the
	countdowns, InRound, the friend bonus, granting coins and Wins, the results screen and the
	trip back to the lobby. Modes only play the round and score it.
]]

local Playlists = require(game:GetService("ReplicatedStorage").Shared.Playlists)
local MapService = require(script.Parent.Parent.Services.MapService)

export type Playlist = Playlists.Playlist

export type RoundContext = {
	Map: MapService.LoadedMap,
	Players: { Player }, -- the ready players taking part (alive when the round started)
	Difficulty: string, -- a Config.Difficulty id (modes that don't use difficulty ignore it)
	Playlist: Playlist, -- the Config.Modes.Playlists entry that won the vote
	-- Publishes the ReplicatedStorage attributes State and TimeLeft. Clients look for the State
	-- "Playing" for in-round effects, so use it for the main part of the round.
	SetState: (state: string, timeLeft: number) -> (),
	-- Counts down once a second (publishing State/TimeLeft); stops early when stopIf() is true.
	Countdown: (state: string, seconds: number, stopIf: (() -> boolean)?) -> (),
	-- Puts a player's character on top of a spawn part.
	Teleport: (player: Player, spawn: BasePart) -> (),
	-- The player's Humanoid if their character is alive, else nil.
	AliveHumanoid: (player: Player) -> Humanoid?,
}

-- One line of the results screen. Rows are shown in the order the mode returns them
-- (best first).
export type ResultRow = {
	UserId: number,
	Name: string, -- the player's DisplayName
	Score: number, -- the mode's score (pumpkins in King Hunt), shown under RoundResult.ScoreLabel
	Pumpkins: number, -- the same as Score (older UI code reads Pumpkins)
	Coins: number, -- coins earned before the friend/group bonus; GameService adds it and grants them
	Survived: boolean, -- badge colour: green when true, grey when false
	Top: boolean, -- the round's best player(s): MVP spotlight and Config.Rewards.TopCollectorWins Wins
	Team: string?, -- optional, e.g. "Seekers": shown after the name
	Badge: string?, -- optional text for the badge on the right (default "Survived!" / "Caught")
	Stat: string?, -- optional extra detail shown after the name, e.g. "found 3"
}

export type RoundResult = {
	Rows: { ResultRow },
	ScoreLabel: string, -- the score column's heading, e.g. "Pumpkins"
	Winner: string?, -- optional line under the title, e.g. "The Seekers win!"
	MvpLine: string?, -- optional MVP text, "%s" = name and "%d" = score (default in Config.Results)
}

export type Mode = {
	Run: (ctx: RoundContext) -> RoundResult,
	Cleanup: (() -> ())?,
}

-- A result with no rows, for a round that ended before anyone scored.
local function empty(scoreLabel: string): RoundResult
	return { Rows = {}, ScoreLabel = scoreLabel }
end

return {
	Empty = empty,
}
