--!strict
--[[
	Round loop: Waiting -> Intermission -> Playing -> Reward -> repeat.
	State is published as attributes on ReplicatedStorage so any client UI
	can read it with GetAttributeChangedSignal (no remotes needed).

	This is the generic skeleton. Put your actual game mode in `runRound`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local GameService = {}

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

-- TODO: your game mode. Return the winning Player (or nil for no winner).
local function runRound(participants: { Player }): Player?
	countdown("Playing", Config.Round.Duration, function()
		return not enoughPlayers()
	end)
	return participants[math.random(1, #participants)]
end

local function loop()
	while true do
		while not enoughPlayers() do
			setState("Waiting for players", 0)
			task.wait(1)
		end

		countdown("Intermission", Config.Round.IntermissionSeconds, function()
			return not enoughPlayers()
		end)
		if not enoughPlayers() then
			continue
		end

		local participants = Players:GetPlayers()
		local winner = runRound(participants)

		setState("Reward", 5)
		for _, player in participants do
			if player.Parent == Players then
				DataService.Add(player, "Coins", Config.Round.RewardParticipant)
			end
		end
		if winner and winner.Parent == Players then
			DataService.Add(winner, "Coins", Config.Round.RewardWinner)
			DataService.Add(winner, "Wins", 1)
		end
		task.wait(5)
	end
end

function GameService.Start()
	task.spawn(loop)
end

return GameService
