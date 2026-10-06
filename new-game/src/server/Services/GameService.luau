--!strict
--[[
	The round loop, the same for every game mode:
	  Waiting for players -> Voting -> Intermission -> the mode plays -> Results -> again
	- Waiting: until Config.Lobby.Ready.MinReady players stand on the Ready pad (ReadyService;
	  at least as many as the smallest switched-on mode needs).
	- Voting: VotingService offers playlists (a mode on a map, Config.Modes.Playlists).
	- Intermission: the map loads. The vote and intermission stop if too few stay ready.
	- The mode plays: src/server/Modes/<Mode>.luau, Run(ctx) (see Modes/Types.luau). Only the
	  players who are ready when the round starts take part; everyone else stays in the lobby.
	- Results: the mode's rows, plus the friend/group bonus (RewardsService), coins and Wins
	  granted here (DataService), then the players who took part go back to the lobby spawn and
	  must step on the Ready pad again.
	If a round breaks (a bug in a mode or a map), the Output window says why, everything is
	cleaned up and a new round starts after Config.Round.ErrorWaitSeconds.

	ReplicatedStorage attributes clients read:
	  State, TimeLeft, MapName, Difficulty (only for modes that use it), Mode (mode id, e.g.
	  "KingHunt"), ModeName (e.g. "King Hunt"); modes add their own (King Hunt: Alive, KingCount).
	Remote RoundResults(rows, info): rows = Modes/Types.luau ResultRow list (best first),
	  info = { ScoreLabel, Winner?, MvpLine?, Mode, ModeName }.
	Owner buttons (F8 panel): "Start round now", and in Studio "Force mode" plus one
	"<mode>: force next round" per mode (e.g. "Pumpkin Hide & Seek: force next round").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Playlists = require(ReplicatedStorage.Shared.Playlists)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(script.Parent.Parent.Modes.Types)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MapService = require(script.Parent.MapService)
local ReadyService = require(script.Parent.ReadyService)
local RewardsService = require(script.Parent.RewardsService)
local VotingService = require(script.Parent.VotingService)

local ModesFolder = script.Parent.Parent.Modes

local GameService = {}

local roundResults: RemoteEvent

-- Owner test buttons (AdminService): start the next round now / pick its playlist.
local startNow = false
local forcedPlaylist: Playlists.Playlist? = nil
local lastForced: { [string]: string } = {} -- mode id -> the playlist its button picked last

-- What the current round has running, so it can be cleaned up if it breaks.
local activeMode: Types.Mode? = nil
local roundPlayers: { Player } = {}

local function setState(state: string, timeLeft: number)
	ReplicatedStorage:SetAttribute("State", state)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
end

local function countdown(state: string, seconds: number, stopIf: (() -> boolean)?)
	for remaining = seconds, 1, -1 do
		if stopIf and stopIf() then
			return
		end
		setState(state, remaining)
		task.wait(1)
	end
end

-- Enough players are ready for a round (or the owner pressed "Start round now").
local function canStart(): boolean
	if #Players:GetPlayers() == 0 then
		return false
	end
	return startNow or ReadyService.Count() >= ReadyService.Needed()
end

local function aliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function teleport(player: Player, spawn: BasePart)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, Config.Maps.SpawnHeight, 0)))
	end
end

-- The mode module for `modeId`, or the fallback mode (with a warning) if it is missing or broken.
local function loadMode(modeId: string): (Types.Mode, string)
	local moduleScript = ModesFolder:FindFirstChild(modeId)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		local ok, mode = pcall(require, moduleScript)
		if ok and type(mode) == "table" and type((mode :: any).Run) == "function" then
			return mode :: any, modeId
		end
		warn(
			("[GameService] Mode %s is broken, playing %s instead: %s"):format(
				modeId,
				Config.Modes.FallbackMode,
				if ok then "it has no Run function" else tostring(mode)
			)
		)
	else
		warn(
			("[GameService] There is no src/server/Modes/%s.luau, playing %s instead."):format(
				modeId,
				Config.Modes.FallbackMode
			)
		)
	end
	local fallback = ModesFolder:FindFirstChild(Config.Modes.FallbackMode)
	assert(fallback and fallback:IsA("ModuleScript"), "the fallback mode module is missing")
	return (require :: any)(fallback), Config.Modes.FallbackMode
end

--[[
	Runs mode.Run(ctx) in its own thread and waits for it, at most
	Config.Round.SafetyLimitSeconds. Errors if Run broke or got stuck (recover() then calls the
	mode's Cleanup).
]]
local function runMode(mode: Types.Mode, ctx: Types.RoundContext): Types.RoundResult
	local done = false
	local result: Types.RoundResult? = nil
	local failure: string? = nil
	local finished = Instance.new("BindableEvent")
	local thread = task.spawn(function()
		local ok, value = xpcall(mode.Run, debug.traceback, ctx)
		if ok then
			result = value
		else
			failure = tostring(value)
		end
		done = true
		finished:Fire()
	end)
	if not done then
		local timeout = task.delay(Config.Round.SafetyLimitSeconds, function()
			finished:Fire()
		end)
		finished.Event:Wait()
		if coroutine.status(timeout) ~= "dead" then
			task.cancel(timeout)
		end
	end
	finished:Destroy()
	if not done then
		if coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
		end
		error(
			("the round ran past Config.Round.SafetyLimitSeconds (%d s)"):format(
				Config.Round.SafetyLimitSeconds
			),
			0
		)
	end
	if failure then
		error(failure, 0)
	end
	if type(result) ~= "table" or type(result.Rows) ~= "table" then
		error("the mode's Run didn't return a RoundResult", 0)
	end
	return result :: Types.RoundResult
end

local function number(value: unknown, default: number): number
	if
		typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
	then
		return value
	end
	return default
end

--[[
	Grants every row's rewards (friend/group bonus on top of the mode's base coins, Wins for
	Top) to players still in the server, and returns the rows to show (bonus coins included).
]]
local function reward(result: Types.RoundResult): { Types.ResultRow }
	local rows: { Types.ResultRow } = {}
	local seen: { [Player]: boolean } = {}
	for _, row in result.Rows do
		local player = Players:GetPlayerByUserId(number(row.UserId, 0))
		if not player or seen[player] then
			continue -- left the server, or a second row for the same player
		end
		seen[player] = true
		local score = number(row.Score, number(row.Pumpkins, 0))
		local base = math.max(0, number(row.Coins, 0))
		-- Friends in the server / group members earn a bit more (Config.Social).
		local coins = math.floor(base * (1 + RewardsService.BonusPercent(player) / 100) + 0.5)
		DataService.Add(player, "Coins", coins)
		RewardsService.RoundFinished(player)
		if row.Top == true then
			DataService.Add(player, "Wins", Config.Rewards.TopCollectorWins)
		end
		table.insert(rows, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = score,
			Pumpkins = score,
			Coins = coins,
			Survived = row.Survived == true,
			Top = row.Top == true,
			Team = if typeof(row.Team) == "string" then row.Team else nil,
			Badge = if typeof(row.Badge) == "string" then row.Badge else nil,
			Stat = if typeof(row.Stat) == "string" then row.Stat else nil,
		})
	end
	return rows
end

-- Players who took part go back to the lobby spawn (a fresh character: no ghost, no gear)
-- and must step on the Ready pad again to play the next round.
local function sendToLobby(players: { Player })
	ReadyService.Reset(players)
	for _, player in players do
		if player.Parent == Players then
			-- LoadCharacter still works; the type checker flags it as deprecated (there is a
			-- newer LoadCharacterAsync), hence the cast. pcall: they may leave meanwhile.
			task.spawn(pcall, (player :: any).LoadCharacter, player)
		end
	end
end

local function clearRoundAttributes()
	for _, name in { "MapName", "Difficulty", "Mode", "ModeName", "Alive" } do
		ReplicatedStorage:SetAttribute(name, nil)
	end
end

-- Who plays: the ready players with a living character (everyone alive if the owner forced
-- a start with nobody on the pad).
local function pickPlayers(forced: boolean): { Player }
	local list: { Player } = {}
	for _, player in ReadyService.List() do
		if aliveHumanoid(player) then
			table.insert(list, player)
		end
	end
	if #list == 0 and forced then
		for _, player in Players:GetPlayers() do
			if aliveHumanoid(player) then
				table.insert(list, player)
			end
		end
	end
	return list
end

-- One full round. Returns false early (back to waiting) when there aren't enough players,
-- true once a round was played.
local function playOneRound(): boolean
	while not canStart() do
		setState("Waiting for players", 0)
		task.wait(1)
	end

	local forced = forcedPlaylist
	forcedPlaylist = nil
	local offer = forced
	if not offer and #Playlists.Available(ReadyService.Count()) == 0 then
		-- Only "Start round now" gets here (otherwise canStart waits for enough ready players):
		-- play a switched-on playlist anyway.
		offer = Playlists.Offer(math.huge, 1)[1]
	end
	local playlistId, difficultyId = VotingService.Run({
		SetState = setState,
		AbortIf = function()
			return not canStart()
		end,
		EndIf = function()
			return startNow
		end,
		Forced = offer,
	})
	if not playlistId or not difficultyId then
		forcedPlaylist = forcedPlaylist or forced -- keep the owner's pick for the next try
		return false
	end
	local playlist: Playlists.Playlist = forced or Playlists.Get(playlistId) or Playlists.Fallback()

	local map = MapService.Load(playlist.Map)
	if map.Id ~= playlist.Map then
		-- The map was broken and MapService loaded a fallback one: play the fallback mode there.
		playlist = Playlists.ForMap(map.Id, Config.Modes.FallbackMode)
	end
	local mode, modeId = loadMode(playlist.Mode)
	local modeName = Playlists.ModeName(modeId)
	local usesDifficulty = Config.Modes.List[modeId] ~= nil
		and Config.Modes.List[modeId].UsesDifficulty
	ReplicatedStorage:SetAttribute("MapName", map.Name)
	ReplicatedStorage:SetAttribute(
		"Difficulty",
		if usesDifficulty then Config.Difficulty.Levels[difficultyId].Name else nil
	)
	ReplicatedStorage:SetAttribute("Mode", modeId)
	ReplicatedStorage:SetAttribute("ModeName", modeName)

	countdown("Intermission", Config.Round.IntermissionSeconds, function()
		return startNow or not canStart()
	end)
	local forcedStart = startNow
	startNow = false
	local players = if canStart() or forcedStart then pickPlayers(forcedStart) else {}
	local needed = if forced or forcedStart then 1 else Playlists.MinPlayers(playlist)
	if #players < needed then
		setState("Not enough players", 0)
		task.wait(Config.Round.CancelledSeconds)
		MapService.Unload()
		clearRoundAttributes()
		return false
	end

	roundPlayers = players
	activeMode = mode
	GhostService.BeginRound(map, players)
	local result = runMode(mode, {
		Map = map,
		Players = players,
		Difficulty = difficultyId,
		Playlist = playlist,
		SetState = setState,
		Countdown = countdown,
		Teleport = teleport,
		AliveHumanoid = aliveHumanoid,
	})
	activeMode = nil
	ReplicatedStorage:SetAttribute("Alive", nil)

	local rows = reward(result)
	GhostService.EndRound()
	roundResults:FireAllClients(rows, {
		ScoreLabel = tostring(result.ScoreLabel or ""),
		Winner = if typeof(result.Winner) == "string" then result.Winner else nil,
		MvpLine = if typeof(result.MvpLine) == "string" then result.MvpLine else nil,
		Mode = modeId,
		ModeName = modeName,
	})
	-- Back to the lobby (and back to normal from ghost) while results show.
	sendToLobby(players)
	roundPlayers = {}
	task.spawn(LeaderboardService.Refresh) -- show new totals on the gravestone
	countdown("Results", Config.Round.ResultsSeconds)

	MapService.Unload()
	clearRoundAttributes()
	return true
end

-- After a round broke: stop whatever was running and put everyone back in the lobby.
local function recover()
	local mode = activeMode
	activeMode = nil
	local cleanup = mode and mode.Cleanup
	if cleanup then
		xpcall(cleanup, function(err: unknown)
			warn("[GameService] The mode's Cleanup failed too: " .. tostring(err))
		end)
	end
	pcall(VotingService.Close)
	pcall(GhostService.EndRound)
	pcall(sendToLobby, roundPlayers)
	roundPlayers = {}
	pcall(MapService.Unload)
	clearRoundAttributes()
	setState("Waiting for players", 0)
end

local function loop()
	while true do
		local ok, err = xpcall(playOneRound, debug.traceback)
		if not ok then
			warn(
				("[GameService] A round broke, starting a new one in %d s: %s"):format(
					Config.Round.ErrorWaitSeconds,
					tostring(err)
				)
			)
			recover()
			task.wait(Config.Round.ErrorWaitSeconds)
		end
	end
end

-- Owner buttons in the F8 admin panel (AdminService).
local function registerAdminCommands()
	AdminService.Register("StartRoundNow", "Start round now", function(_player, _data)
		-- (activeMode is set while a mode runs, including its own phases like Hide & Seek's
		-- "Hiding" or ScareMaze's "Get ready", not only "Playing".)
		if activeMode ~= nil then
			return "A round is already being played."
		end
		startNow = true
		return "Starting: skips the wait, the vote and the Ready pad (everyone plays if nobody is ready)."
	end)

	if RunService:IsStudio() or Config.Modes.ForceModeInLiveServers then
		AdminService.Register("ForceMode", "Force mode", function(_player, _data)
			local list = Playlists.Enabled()
			if #list == 0 then
				forcedPlaylist = nil
				return "No playlist has its mode switched on in Config.Features."
			end
			local index = 0
			if forcedPlaylist then
				for i, playlist in list do
					if playlist.Id == forcedPlaylist.Id then
						index = i
					end
				end
			end
			forcedPlaylist = list[index + 1] -- after the last one: nil = a normal vote again
			if forcedPlaylist then
				return ("Next round: %s (any player count). Press again for the next one."):format(
					forcedPlaylist.Name
				)
			end
			return "Next round: normal vote."
		end)

		-- One "<mode>: force next round" button per mode: the next round plays that mode
		-- without a vote (each press moves on to its next map).
		for _, modeId in Config.Modes.Order do
			local def = Config.Modes.List[modeId]
			if not def then
				continue
			end
			AdminService.Register(
				"Force" .. modeId,
				("%s: force next round"):format(def.Name),
				function(_player, _data)
					local list = {}
					for _, playlist in Playlists.Enabled() do
						if playlist.Mode == modeId then
							table.insert(list, playlist)
						end
					end
					if #list == 0 then
						return ("%s is switched off (Config.Features.%s)."):format(
							def.Name,
							def.Feature
						)
					end
					-- Move on from the last pick, even once a round has used it up.
					local index = 0
					for i, playlist in list do
						if playlist.Id == lastForced[modeId] then
							index = i
						end
					end
					local chosen = list[index % #list + 1]
					forcedPlaylist = chosen
					lastForced[modeId] = chosen.Id
					return ("Next round: %s (any player count)."):format(chosen.Name)
				end
			)
		end
	end
end

function GameService.Start()
	roundResults = Remotes.Event("RoundResults")
	registerAdminCommands()
	task.spawn(loop)
end

return GameService
