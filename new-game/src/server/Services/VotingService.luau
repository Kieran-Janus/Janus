--!strict
--[[
	Map + difficulty vote before each round.
	Client -> server: CastVote(kind: "Map" | "Difficulty", choice: string)
	Server -> clients: VoteUpdate(state) with the options and live counts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Option = { Id: string, Name: string, Votes: number }
export type VoteState = { Open: boolean, Maps: { Option }, Difficulties: { Option } }

local VotingService = {}

local open = false
local mapOptions: { Option } = {}
local difficultyOptions: { Option } = {}
local choices: { [Player]: { Map: string?, Difficulty: string? } } = {}
local lastVote: { [Player]: number } = {}

local castVote: RemoteEvent
local voteUpdate: RemoteEvent

local function state(): VoteState
	return { Open = open, Maps = mapOptions, Difficulties = difficultyOptions }
end

local function recount()
	for _, list in { mapOptions, difficultyOptions } do
		for _, option in list do
			option.Votes = 0
		end
	end
	for _, choice in choices do
		for _, option in mapOptions do
			if option.Id == choice.Map then
				option.Votes += 1
			end
		end
		for _, option in difficultyOptions do
			if option.Id == choice.Difficulty then
				option.Votes += 1
			end
		end
	end
	voteUpdate:FireAllClients(state())
end

local function hasOption(list: { Option }, id: string): boolean
	for _, option in list do
		if option.Id == id then
			return true
		end
	end
	return false
end

-- Highest votes wins; ties (including zero votes) are broken at random.
local function winner(list: { Option }): string
	local best = -1
	local tied: { string } = {}
	for _, option in list do
		if option.Votes > best then
			best = option.Votes
			tied = { option.Id }
		elseif option.Votes == best then
			table.insert(tied, option.Id)
		end
	end
	return tied[math.random(1, #tied)]
end

local function onCastVote(player: Player, kind: unknown, choice: unknown)
	if not open or typeof(kind) ~= "string" or typeof(choice) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastVote[player] or 0) < Config.Voting.MinSecondsBetweenVotes then
		return
	end
	lastVote[player] = now

	local entry = choices[player] or {}
	if kind == "Map" and hasOption(mapOptions, choice) then
		entry.Map = choice
	elseif kind == "Difficulty" and hasOption(difficultyOptions, choice) then
		entry.Difficulty = choice
	else
		return
	end
	choices[player] = entry
	recount()
end

--[[
	Runs one vote. Yields for Config.Voting.Seconds (publishing the countdown through
	setState) and returns the winning map id and difficulty id, or nil if `abortIf`
	returned true part-way through.
]]
function VotingService.Run(
	setState: (string, number) -> (),
	abortIf: () -> boolean
): (string?, string?)
	-- Offer a random subset of the King Hunt maps (a map's Modes lists the modes it's made
	-- for; maps without Modes count as King Hunt). Mode playlists replace this in v2.
	local pool = {}
	for _, def in Config.Maps.List do
		if def.Modes == nil or table.find(def.Modes, "KingHunt") then
			table.insert(pool, def)
		end
	end
	mapOptions = {}
	for _ = 1, math.min(Config.Voting.MapChoices, #pool) do
		local def = table.remove(pool, math.random(1, #pool))
		table.insert(mapOptions, { Id = def.Id, Name = def.Name, Votes = 0 })
	end
	difficultyOptions = {}
	for _, id in Config.Difficulty.Order do
		table.insert(
			difficultyOptions,
			{ Id = id, Name = Config.Difficulty.Levels[id].Name, Votes = 0 }
		)
	end
	table.clear(choices)
	open = true
	recount()

	local aborted = false
	for remaining = Config.Voting.Seconds, 1, -1 do
		if abortIf() then
			aborted = true
			break
		end
		setState("Voting", remaining)
		task.wait(1)
	end

	open = false
	voteUpdate:FireAllClients(state())
	if aborted then
		return nil, nil
	end

	-- Difficulty falls back to the default when nobody voted for anything.
	local difficulty = winner(difficultyOptions)
	local anyDifficultyVotes = false
	for _, option in difficultyOptions do
		anyDifficultyVotes = anyDifficultyVotes or option.Votes > 0
	end
	if not anyDifficultyVotes then
		difficulty = Config.Difficulty.Default
	end
	return winner(mapOptions), difficulty
end

function VotingService.Start()
	castVote = Remotes.Event("CastVote")
	voteUpdate = Remotes.Event("VoteUpdate")
	castVote.OnServerEvent:Connect(onCastVote)

	Players.PlayerAdded:Connect(function(player)
		if open then
			voteUpdate:FireClient(player, state())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastVote[player] = nil
		if choices[player] then
			choices[player] = nil
			if open then
				recount()
			end
		end
	end)
end

return VotingService
