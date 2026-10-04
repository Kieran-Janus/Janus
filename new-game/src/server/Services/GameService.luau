--!strict
--[[
	Round loop: Waiting -> Voting -> Intermission -> Playing -> Results -> repeat.
	State is published as attributes on ReplicatedStorage so any client UI
	can read it with GetAttributeChangedSignal:
	  State, TimeLeft, MapName, Difficulty, Alive (survivors left), KingCount
	Round results are sent once per round through the RoundResults remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)
local KingService = require(script.Parent.KingService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MapService = require(script.Parent.MapService)
local MinionService = require(script.Parent.MinionService)
local NoiseService = require(script.Parent.NoiseService)
local PumpkinService = require(script.Parent.PumpkinService)
local RewardsService = require(script.Parent.RewardsService)
local VotingService = require(script.Parent.VotingService)

export type ResultRow = {
	UserId: number,
	Name: string,
	Pumpkins: number,
	Coins: number,
	Survived: boolean,
	Top: boolean,
}

local GameService = {}

local roundResults: RemoteEvent

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

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= Config.Round.MinPlayers
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

-- Plays one round on `map`. Returns the results rows (already rewarded).
local function playRound(map: MapService.LoadedMap, difficultyId: string): { ResultRow }
	local participants: { Player } = {}
	local alive: { [Player]: boolean } = {}
	local connections: { RBXScriptConnection } = {}

	local function countAlive()
		local n = 0
		for _ in alive do
			n += 1
		end
		ReplicatedStorage:SetAttribute("Alive", n)
	end

	-- Caught by the King (inPlace) or died/reset: a ghost for the rest of the round.
	local function knockOut(player: Player, inPlace: boolean)
		if not alive[player] then
			return
		end
		alive[player] = nil
		countAlive()
		GhostService.MarkOut(player, inPlace)
	end

	PumpkinService.ResetCounts()
	for i, player in Players:GetPlayers() do
		local humanoid = aliveHumanoid(player)
		if humanoid then
			table.insert(participants, player)
			alive[player] = true
			teleport(player, map.Spawns[(i - 1) % #map.Spawns + 1])
			table.insert(
				connections,
				humanoid.Died:Connect(function()
					knockOut(player, false)
				end)
			)
		end
	end
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			alive[player] = nil
			countAlive()
		end)
	)
	countAlive()

	local function isAlive(player: Player): boolean
		return alive[player] == true
	end
	GhostService.BeginRound(map, participants)
	PumpkinService.Begin(map, difficultyId, isAlive)
	KingService.Begin(map, difficultyId, isAlive, function(player)
		knockOut(player, true)
	end)
	MinionService.Begin(map, difficultyId, isAlive)
	-- Ends at 0:00, or early once every participant is caught.
	countdown("Playing", Config.Round.Duration, function()
		return next(alive) == nil
	end)
	KingService.Stop()
	MinionService.Stop()
	PumpkinService.Stop()
	NoiseService.Clear()
	for _, connection in connections do
		connection:Disconnect()
	end
	ReplicatedStorage:SetAttribute("Alive", nil)

	-- Score and reward everyone who started the round and is still in the server.
	local multiplier = Config.Difficulty.Levels[difficultyId].RewardMultiplier
	local best = 0
	for _, player in participants do
		best = math.max(best, PumpkinService.GetCount(player))
	end
	local rows: { ResultRow } = {}
	for _, player in participants do
		if player.Parent ~= Players then
			continue
		end
		local pumpkins = PumpkinService.GetCount(player)
		local survived = alive[player] == true and aliveHumanoid(player) ~= nil
		local coins = pumpkins * Config.Rewards.CoinsPerPumpkin * multiplier
		if survived then
			coins += Config.Rewards.SurvivorBonus
		end
		-- Friends in the server / group members earn a bit more (Config.Social).
		coins = math.floor(coins * (1 + RewardsService.BonusPercent(player) / 100) + 0.5)
		local top = best > 0 and pumpkins == best
		DataService.Add(player, "Coins", coins)
		RewardsService.RoundFinished(player)
		LeaderboardService.Record(player, pumpkins)
		if top then
			DataService.Add(player, "Wins", Config.Rewards.TopCollectorWins)
		end
		table.insert(rows, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Pumpkins = pumpkins,
			Coins = coins,
			Survived = survived,
			Top = top,
		})
	end
	table.sort(rows, function(a, b)
		return a.Pumpkins > b.Pumpkins
	end)
	return rows
end

local function loop()
	while true do
		while not enoughPlayers() do
			setState("Waiting for players", 0)
			task.wait(1)
		end

		local mapId, difficultyId = VotingService.Run(setState, function()
			return not enoughPlayers()
		end)
		if not mapId or not difficultyId then
			continue
		end

		local map = MapService.Load(mapId)
		ReplicatedStorage:SetAttribute("MapName", map.Name)
		ReplicatedStorage:SetAttribute("Difficulty", Config.Difficulty.Levels[difficultyId].Name)

		countdown("Intermission", Config.Round.IntermissionSeconds, function()
			return not enoughPlayers()
		end)
		if enoughPlayers() then
			local rows = playRound(map, difficultyId)
			roundResults:FireAllClients(rows)
			GhostService.EndRound()
			-- Back to the lobby (and back to normal from ghost) while results show.
			for _, row in rows do
				local player = Players:GetPlayerByUserId(row.UserId)
				if player then
					task.spawn(player.LoadCharacter, player)
				end
			end
			task.spawn(LeaderboardService.Refresh) -- show new totals on the gravestone
			countdown("Results", Config.Round.ResultsSeconds)
		end

		MapService.Unload()
		ReplicatedStorage:SetAttribute("MapName", nil)
		ReplicatedStorage:SetAttribute("Difficulty", nil)
	end
end

function GameService.Start()
	roundResults = Remotes.Event("RoundResults")
	task.spawn(loop)
end

return GameService
