--!strict
--[[
	The vote before each round: players pick a playlist (a game mode on a map,
	Config.Modes.Playlists) and, when an offered mode uses it, the difficulty.
	Offered: up to Config.Modes.VoteChoices random playlists whose mode is switched on in
	Config.Features and whose MinPlayers fits the number of ready players (when every mode is
	off: Config.Modes.FallbackMode, King Hunt; when none fits: no vote, back to waiting).
	With Config.Lobby.Ready.VoteOnlyReady, only players on the Ready pad can vote (and only
	their votes count); everyone else sees the vote greyed out.

	Vote pads (Config.VotePads, switch Config.Features.VotePads): when the lobby has parts
	tagged VotePad, players vote by standing on them instead: first the game (one pad per mode
	in Config.Modes.Order; a game needing more ready players than there are says so on its pad
	and gets no votes), then, if the winner uses difficulty, EASY or HARD on the same pads. The
	map is one of the winning game's playlists, at random. Each pad gets the attributes its
	floating sign is drawn from (VoteOption, VoteName, VoteIcon, VoteVotes, VoteNeeds,
	VoteColor, VotePhase = "Mode" / "Difficulty" / ""); ReplicatedStorage attribute VoteMode is
	the game's name during the difficulty vote. CastVote is ignored then.

	Client -> server: CastVote(kind: "Map" | "Difficulty", choice: string)
	                  ("Map" = a playlist id, the name is kept so older UI code still works)
	Server -> clients: VoteUpdate(state) with the options and live counts:
	  { Open, Maps = { {Id, Name, Votes, Mode} }, Difficulties = { {Id, Name, Votes} },
	    ReadyOnly }  -- Difficulties is empty when no offered mode uses difficulty
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Playlists = require(ReplicatedStorage.Shared.Playlists)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local ReadyService = require(script.Parent.ReadyService)

export type Option = { Id: string, Name: string, Votes: number, Mode: string? }
export type VoteState = {
	Open: boolean,
	Maps: { Option }, -- playlists
	Difficulties: { Option },
	ReadyOnly: boolean, -- true = only players with the Ready attribute can vote
	-- true = players vote by standing on the vote pads (Config.VotePads): Maps then holds one
	-- option per game (Id = the mode id) and the screens show no vote buttons
	Pads: boolean,
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
-- Studs past a vote pad's edge that still count as on it (small: the pads stand close together).
local PAD_MARGIN = 0.3
-- The pad vote (below), used by Run when Config.VotePads is on.
local runPads: (RunOptions) -> (string?, string?)

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
		Pads = VotingService.PadsActive(),
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
	if VotingService.PadsActive() then
		return -- (the pads decide: where you stand is your vote)
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
	if VotingService.PadsActive() then
		return runPads(options)
	end
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

-- Vote pads (Config.VotePads) -------------------------------------------------------------

type VotePad = { Part: BasePart, Slot: number }

-- The vote pads in Workspace (parts tagged VotePad with a VoteSlot number), by slot.
function VotingService.Pads(): { VotePad }
	local pads: { VotePad } = {}
	for _, tagged in CollectionService:GetTagged(Tags.VotePad) do
		local slot = tagged:GetAttribute("VoteSlot")
		if
			tagged:IsA("BasePart")
			and tagged:IsDescendantOf(workspace)
			and type(slot) == "number"
		then
			table.insert(pads, { Part = tagged, Slot = slot })
		end
	end
	table.sort(pads, function(a, b)
		return a.Slot < b.Slot
	end)
	return pads
end

-- Voting by standing on pads: switched on, and there are pads to stand on.
function VotingService.PadsActive(): boolean
	return Config.Features.VotePads == true
		and Config.Features.ReadyPad == true
		and #VotingService.Pads() > 0
end

local function padShape(part: BasePart): string
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		return "Cylinder"
	end
	return "Block"
end

-- The slot of the vote pad `player` stands on (the nearest one where two edges meet), or nil.
function VotingService.PadOf(player: Player, pads: { VotePad }): number?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil
	end
	local position = root.Position
	local best: number? = nil
	local bestDistance = math.huge
	for _, pad in pads do
		local part = pad.Part
		if
			ReadyService.Inside(
				position,
				part.CFrame,
				part.Size,
				padShape(part),
				PAD_MARGIN,
				Config.Lobby.Ready.PadHeight
			)
		then
			local flat = Vector3.new(position.X - part.Position.X, 0, position.Z - part.Position.Z)
			if flat.Magnitude < bestDistance then
				best = pad.Slot
				bestDistance = flat.Magnitude
			end
		end
	end
	return best
end

-- What a pad shows (attributes each screen draws its floating sign from) and its colour.
local function dressPad(pad: VotePad, option: Option?, look: string, needs: number?, phase: string)
	local style = Config.VotePads.Looks[look] or Config.VotePads.Looks.Default
	local part = pad.Part
	part:SetAttribute("VoteOption", if option then option.Id else "")
	part:SetAttribute("VoteName", if option then option.Name else "")
	part:SetAttribute("VoteIcon", style.Icon)
	part:SetAttribute("VoteVotes", if option then option.Votes else 0)
	part:SetAttribute("VoteNeeds", needs or 0)
	part:SetAttribute("VoteColor", style.Color)
	part:SetAttribute("VotePhase", phase)
	part.Color = style.Color:Lerp(Color3.new(0, 0, 0), 0.45)
	local model = part.Parent
	local rim = model and model:FindFirstChild("Rim")
	if rim and rim:IsA("BasePart") then
		rim.Color = style.Color
	end
end

-- The games on offer from `candidates` (playlists), in Config.Modes.Order, and the fewest
-- ready players each needs.
local function offeredModes(candidates: { Playlists.Playlist }): ({ string }, { [string]: number })
	local modes: { string } = {}
	local needs: { [string]: number } = {}
	for _, id in Config.Modes.Order do
		for _, playlist in candidates do
			if playlist.Mode == id then
				needs[id] = math.min(needs[id] or math.huge, Playlists.MinPlayers(playlist))
				if not table.find(modes, id) then
					table.insert(modes, id)
				end
			end
		end
	end
	return modes, needs
end

-- Between votes every pad shows its game (no counts), so players can see what's on offer.
local function idlePads(pads: { VotePad })
	local modes = offeredModes(Playlists.Enabled())
	for i, pad in pads do
		local id = modes[i]
		if id then
			local option: Option = { Id = id, Name = Playlists.ModeName(id), Votes = 0, Mode = id }
			dressPad(pad, option, if Config.VotePads.Looks[id] then id else "Default", nil, "")
		else
			dressPad(pad, nil, "Off", nil, "")
		end
	end
end

-- One part of the pad vote. slots[slot] = the option on that pad (no entry = that pad is off
-- this time). Every quarter second counts who stands where, for `seconds`. Returns false if
-- the vote was aborted.
local function padPhase(
	options: RunOptions,
	pads: { VotePad },
	phase: string,
	slots: { [number]: Option },
	looks: { [number]: string },
	needs: { [string]: number },
	seconds: number
): boolean
	local deadline = os.clock() + seconds
	local lastWhole = -1
	while true do
		if options.AbortIf() then
			return false
		end
		if options.EndIf and options.EndIf() then
			return true
		end
		local left = deadline - os.clock()
		if left <= 0 then
			break
		end
		local whole = math.ceil(left)
		if whole ~= lastWhole then
			lastWhole = whole
			options.SetState("Voting", whole)
		end
		-- Only ready players vote, and a game that needs more ready players than there are
		-- gets no votes.
		local readyCount = ReadyService.Count()
		for _, option in slots do
			option.Votes = 0
		end
		table.clear(choices)
		for _, player in Players:GetPlayers() do
			if not canVote(player) then
				continue
			end
			local slot = VotingService.PadOf(player, pads)
			local option = if slot then slots[slot] else nil
			if option and (needs[option.Id] or 0) <= readyCount then
				option.Votes += 1
				choices[player] = if phase == "Mode"
					then { Map = option.Id }
					else { Difficulty = option.Id }
			end
		end
		for _, pad in pads do
			local option = slots[pad.Slot]
			local need = if option then needs[option.Id] else nil
			dressPad(
				pad,
				option,
				looks[pad.Slot] or "Off",
				if need and need > readyCount then need else nil,
				phase
			)
		end
		recount()
		task.wait(0.25)
	end
	return true
end

-- The pad vote: the game, then (if it has one) the difficulty. Returns a playlist id (one of
-- the winning game's maps, at random) and a difficulty id, or nil, nil when aborted or when
-- too few players are ready for every game on offer.
runPads = function(options: RunOptions): (string?, string?)
	local cfg = Config.VotePads
	local pads = VotingService.Pads()
	local candidates: { Playlists.Playlist } = if options.Forced
		then { options.Forced }
		else Playlists.Enabled()
	-- The games on offer, in Config.Modes.Order, one per pad.
	local modes, needs = offeredModes(candidates)
	if options.Forced then
		-- The owner's "force next round" plays with any number of players.
		for id in needs do
			needs[id] = 1
		end
	end
	if #modes == 0 then
		local fallback = Playlists.Fallback()
		candidates = { fallback }
		modes = { fallback.Mode }
		needs[fallback.Mode] = 1
	end
	local fits = false
	for i, id in modes do
		fits = fits or (i <= #pads and needs[id] <= ReadyService.Count())
	end
	if not fits then
		return nil, nil
	end

	mapOptions = {}
	difficultyOptions = {}
	local slots: { [number]: Option } = {}
	local looks: { [number]: string } = {}
	for i, pad in pads do
		local id = modes[i]
		if id then
			local option: Option = { Id = id, Name = Playlists.ModeName(id), Votes = 0, Mode = id }
			table.insert(mapOptions, option)
			slots[pad.Slot] = option
			looks[pad.Slot] = if cfg.Looks[id] then id else "Default"
		end
	end
	local function stop()
		open = false
		idlePads(pads)
		recount(true)
	end
	table.clear(choices)
	open = true
	recount(true)
	if not padPhase(options, pads, "Mode", slots, looks, needs, cfg.ModeSeconds) then
		stop()
		return nil, nil
	end

	-- The winning game: the most votes among the games enough players are ready for.
	local playable: { Option } = {}
	for _, option in mapOptions do
		if (needs[option.Id] or 0) <= ReadyService.Count() then
			table.insert(playable, option)
		end
	end
	if #playable == 0 then
		stop()
		return nil, nil
	end
	local mode = winner(playable)

	local difficulty = Config.Difficulty.Default
	local def = Config.Modes.List[mode]
	if def and def.UsesDifficulty and not (options.EndIf and options.EndIf()) then
		local dSlots: { [number]: Option } = {}
		local dLooks: { [number]: string } = {}
		for _, id in Config.Difficulty.Order do
			local option: Option = { Id = id, Name = Config.Difficulty.Levels[id].Name, Votes = 0 }
			table.insert(difficultyOptions, option)
			local wanted = (cfg.DifficultySlots :: { [string]: { number } })[id] or {}
			for _, slot in wanted do
				dSlots[slot] = option
				dLooks[slot] = id
			end
		end
		-- The game whose difficulty is being picked (the screens show its name).
		ReplicatedStorage:SetAttribute("VoteMode", Playlists.ModeName(mode))
		local finished =
			padPhase(options, pads, "Difficulty", dSlots, dLooks, {}, cfg.DifficultySeconds)
		ReplicatedStorage:SetAttribute("VoteMode", nil)
		if not finished then
			stop()
			return nil, nil
		end
		local anyVotes = false
		for _, option in difficultyOptions do
			anyVotes = anyVotes or option.Votes > 0
		end
		if anyVotes then
			difficulty = winner(difficultyOptions)
		end
	end
	stop()

	local maps: { Playlists.Playlist } = {}
	for _, playlist in candidates do
		if
			playlist.Mode == mode
			and Playlists.MinPlayers(playlist) <= math.max(ReadyService.Count(), 1)
		then
			table.insert(maps, playlist)
		end
	end
	if #maps == 0 then
		for _, playlist in candidates do
			if playlist.Mode == mode then
				table.insert(maps, playlist)
			end
		end
	end
	local chosen = if #maps > 0 then maps[math.random(1, #maps)] else Playlists.Fallback()
	return chosen.Id, difficulty
end

function VotingService.Start()
	castVote = Remotes.Event("CastVote")
	voteUpdate = Remotes.Event("VoteUpdate")
	castVote.OnServerEvent:Connect(onCastVote)

	-- The vote pads show their games from the start (also pads added later, e.g. a saved
	-- lobby that gets its pads when the game starts).
	if Config.Features.VotePads then
		local queued = false
		local function refreshIdle()
			if queued then
				return
			end
			queued = true
			task.defer(function()
				queued = false
				if not open then
					idlePads(VotingService.Pads())
				end
			end)
		end
		CollectionService:GetInstanceAddedSignal(Tags.VotePad):Connect(refreshIdle)
		refreshIdle()
	end

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
