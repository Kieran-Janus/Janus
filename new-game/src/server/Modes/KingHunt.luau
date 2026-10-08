--!strict
--[[
	KING HUNT (the classic mode): grab pumpkins, stay quiet, don't get caught by the Pumpkin King.
	On/off: Config.Features.KingHunt. Settings: Config.Difficulty (each level's RoundSeconds is the
	round length, else Config.Round.Duration), Config.Pumpkins, Config.King, Config.Monsters,
	Config.Rewards.

	Everyone starts on the map's spawns. Pumpkins appear (PumpkinService), the King comes after
	Config.King.SpawnDelay (KingService) and minions roam (MinionService). Caught or dead
	players become ghosts (GhostService) for the rest of the round. The round ends at 0:00 or
	when everyone is caught.
	Score = pumpkins collected. Coins = pumpkins x Rewards.CoinsPerPumpkin x the difficulty's
	RewardMultiplier, + Rewards.SurvivorBonus if still alive (GameService adds the friend bonus).

	ReplicatedStorage attributes: Alive (survivors left), KingCount (set by KingService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(script.Parent.Types)
local Services = script.Parent.Parent.Services
local GhostService = require(Services.GhostService)
local KingService = require(Services.KingService)
local LeaderboardService = require(Services.LeaderboardService)
local MinionService = require(Services.MinionService)
local NoiseService = require(Services.NoiseService)
local PumpkinService = require(Services.PumpkinService)

local KingHunt = {}

local connections: { RBXScriptConnection } = {}

local function disconnectAll()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

-- Stops everything a King Hunt round runs. Safe to call when nothing is running.
function KingHunt.Cleanup()
	KingService.Stop()
	MinionService.Stop()
	PumpkinService.Stop()
	NoiseService.Clear()
	disconnectAll()
	ReplicatedStorage:SetAttribute("Alive", nil)
end

function KingHunt.Run(ctx: Types.RoundContext): Types.RoundResult
	local map = ctx.Map
	local difficultyId = ctx.Difficulty
	local participants = ctx.Players
	local alive: { [Player]: boolean } = {}
	disconnectAll()

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
	for i, player in participants do
		local humanoid = ctx.AliveHumanoid(player)
		if humanoid then
			alive[player] = true
			ctx.Teleport(player, map.Spawns[(i - 1) % #map.Spawns + 1])
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
			if alive[player] then
				alive[player] = nil
				countAlive()
			end
		end)
	)
	countAlive()
	-- Someone whose character died between the vote and now starts as a ghost.
	for _, player in participants do
		if not alive[player] then
			GhostService.MarkOut(player, false)
		end
	end

	local function isAlive(player: Player): boolean
		return alive[player] == true
	end
	PumpkinService.Begin(map, difficultyId, isAlive)
	KingService.Begin(map, difficultyId, isAlive, function(player)
		knockOut(player, true)
	end)
	MinionService.Begin(map, difficultyId, isAlive)
	-- Ends at 0:00, or early once every participant is caught.
	local seconds = Config.Difficulty.Levels[difficultyId].RoundSeconds or Config.Round.Duration
	ctx.Countdown("Playing", seconds, function()
		return next(alive) == nil
	end)
	KingService.Stop()
	MinionService.Stop()
	PumpkinService.Stop()
	NoiseService.Clear()
	disconnectAll()
	ReplicatedStorage:SetAttribute("Alive", nil)

	-- Score everyone who started the round and is still in the server.
	local multiplier = Config.Difficulty.Levels[difficultyId].RewardMultiplier
	local best = 0
	for _, player in participants do
		best = math.max(best, PumpkinService.GetCount(player))
	end
	local rows: { Types.ResultRow } = {}
	for _, player in participants do
		if player.Parent ~= Players then
			continue
		end
		local pumpkins = PumpkinService.GetCount(player)
		local survived = alive[player] == true and ctx.AliveHumanoid(player) ~= nil
		local coins = pumpkins * Config.Rewards.CoinsPerPumpkin * multiplier
		if survived then
			coins += Config.Rewards.SurvivorBonus
		end
		LeaderboardService.Record(player, pumpkins)
		table.insert(rows, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = pumpkins,
			Pumpkins = pumpkins,
			Coins = coins,
			Survived = survived,
			Top = best > 0 and pumpkins == best,
		})
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	return {
		Rows = rows,
		ScoreLabel = Config.Results.Text.ScoreLabel,
		MvpLine = Config.Results.Text.MvpLine,
	}
end

return KingHunt
