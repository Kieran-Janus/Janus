--!strict
--[[
	The vote before each round: players pick a playlist (a game mode on a map,
	Config.Modes.Playlists) and, when an offered mode uses it, the difficulty.
	Offered: up to Config.Modes.VoteChoices random playlists whose mode is switched on in
	Config.Features and whose MinPlayers fits the number of ready players (when every mode is
	off: Config.Modes.FallbackMode, King Hunt; when none fits: no vote, back to waiting).
	With Config.Lobby.Ready.VoteOnlyReady, only players on the Ready pad can vote (and only
	their votes count); everyone else sees the vote greyed out.

	Client -> server: CastVote(kind: "Map" | "Difficulty", choice: string)
	                  ("Map" = a playlist id, the name is kept so older UI code still works)
	Server -> clients: VoteUpdate(state) with the options and live counts:
	  { Open, Maps = { {Id, Name, Votes, Mode} }, Difficulties = { {Id, Name, Votes} },
	    ReadyOnly }  -- Difficulties is empty when no offered mode uses difficulty
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Playlists = require(ReplicatedStorage.Shared.Playlists)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ReadyService = require(script.Parent.ReadyService)

export type Option = { Id: string, Name: string, Votes: number, Mode: string? }
export type VoteState = {
	Open: boolean,
	Maps: { Option }, -- playlists
	Difficulties: { Option },
	ReadyOnly: boolean, -- true = only players with the Ready attribute can vote
}
export type RunOptions = {
	SetState: (string, number) -> (),
	AbortIf: () -> boolean, -- stop the vote with no result (e.g. too few players ready)
	EndIf: (() -> boolean)?, -- close the vote early and use the votes so far
	Forced: Playlists.Playlist?, -- offer only this playlist (owner "Force mode" button)
}

local VotingService = {}

local open = false
local mapOptions: { Option } = {}
local difficultyOptions: { Option } = {}
local choices: { [Player]: { Map: string?, Difficulty: string? } } = {}
local lastVote: { [Player]: number } = {}
local lastSent = ""

local castVote: RemoteEvent
local voteUpdate: RemoteEvent

local function readyOnly(): boolean
	return Config.Lobby.Ready.VoteOnlyReady and ReadyService.PadsActive()
end

local function canVote(player: Player): boolean
	return not readyOnly() or ReadyService.IsReady(player)
end

local function state(): VoteState
	return {
		Open = open,
		Maps = mapOptions,
		Difficulties = difficultyOptions,
		ReadyOnly = readyOnly(),
	}
end

-- A short text of everything clients see, so unchanged counts aren't re-sent every second.
local function signature(): string
	local parts = { tostring(open), tostring(readyOnly()) }
	for _, list in { mapOptions, difficultyOptions } do
		for _, option in list do
			table.insert(parts, option.Id .. "=" .. option.Votes)
		end
	end
	return table.concat(parts, ",")
end

-- Counts the votes of players who may vote right now and tells clients if anything changed.
local function recount(force: boolean?)
	for _, list in { mapOptions, difficultyOptions } do
		for _, option in list do
			option.Votes = 0
		end
	end
	for player, choice in choices do
		if not canVote(player) then
			continue
		end
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
	local now = signature()
	if force or now ~= lastSent then
		lastSent = now
		voteUpdate:FireAllClients(state())
	end
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
	if not canVote(player) then
		return
	end

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

-- Closes the vote (if one is open) without a result. Used after a round breaks.
function VotingService.Close()
	if open then
		open = false
		table.clear(choices)
		recount(true)
	end
end

--[[
	Runs one vote. Yields for Config.Voting.Seconds (publishing the countdown through
	options.SetState) and returns the winning playlist id and difficulty id (the difficulty is
	Config.Difficulty.Default when nobody voted for one, or when no offered mode uses it).
	Returns nil, nil if options.AbortIf() returned true part-way through.
]]
function VotingService.Run(options: RunOptions): (string?, string?)
	local offered: { Playlists.Playlist } = if options.Forced
		then { options.Forced }
		else Playlists.Offer(ReadyService.Count(), Config.Modes.VoteChoices)
	if #offered == 0 then
		return nil, nil -- too few ready players for every switched-on mode: no vote
	end
	mapOptions = {}
	local usesDifficulty = false
	for _, playlist in offered do
		table.insert(
			mapOptions,
			{ Id = playlist.Id, Name = playlist.Name, Votes = 0, Mode = playlist.Mode }
		)
		usesDifficulty = usesDifficulty or Playlists.UsesDifficulty(playlist)
	end
	difficultyOptions = {}
	if usesDifficulty then
		for _, id in Config.Difficulty.Order do
			table.insert(
				difficultyOptions,
				{ Id = id, Name = Config.Difficulty.Levels[id].Name, Votes = 0 }
			)
		end
	end
	table.clear(choices)
	open = true
	recount(true)

	local aborted = false
	for remaining = Config.Voting.Seconds, 1, -1 do
		if options.AbortIf() then
			aborted = true
			break
		end
		if options.EndIf and options.EndIf() then
			break
		end
		options.SetState("Voting", remaining)
		recount() -- players stepping on or off the pad change whose votes count
		task.wait(1)
	end

	recount()
	open = false
	recount(true)
	if aborted then
		return nil, nil
	end

	-- Difficulty falls back to the default when nobody voted for anything.
	local difficulty = Config.Difficulty.Default
	local anyDifficultyVotes = false
	for _, option in difficultyOptions do
		anyDifficultyVotes = anyDifficultyVotes or option.Votes > 0
	end
	if anyDifficultyVotes then
		difficulty = winner(difficultyOptions)
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
