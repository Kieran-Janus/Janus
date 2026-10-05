--!strict
--[[
	Caught (or dead) players are ghosts for the rest of the round: see-through, floating,
	unable to collect pumpkins, and ignored by the King. Each ghost picks a mode:
	  Spectate  - parked in the lobby; the client camera follows survivors
	  Haunt     - float around the map; near a King, Haunt blurs its sight for a moment
	  GhostChat - float around the map; sets the GhostChat flag (voice part comes in M3)
	Flying itself is client-side (the ghost's own character); the server only decides who
	is a ghost and what each request is allowed to do.

	Player attributes the client reads: InRound, Out, GhostMode, GhostChat, HauntReadyAt
	Client -> server: SetGhostMode(mode) event, Haunt() function -> number of Kings affected,
	  SpectateFocus(on: boolean) event: someone watching the round from the lobby (a ghost in
	  Spectate mode, or a lobby player using Spectate) gets the map streamed to them
	  (Player.ReplicationFocus = the map's Floor) until they stop or the round ends.

	Collision groups: ghosts don't collide with players, other ghosts or the King.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KingService = require(script.Parent.KingService)
local MapService = require(script.Parent.MapService)
local SprintService = require(script.Parent.SprintService)

local GhostService = {}

local roundMap: MapService.LoadedMap? = nil
local lastSwitch: { [Player]: number } = {}

local function isMode(mode: unknown): boolean
	return typeof(mode) == "string" and table.find(Config.Ghost.Modes, mode) ~= nil
end

local function style(player: Player, instance: Instance)
	local out = player:GetAttribute("Out") == true
	if instance:IsA("BasePart") then
		instance.CollisionGroup = if out then "Ghosts" else "Players"
		if out and instance.Name ~= "HumanoidRootPart" then
			instance.Transparency = math.max(instance.Transparency, Config.Ghost.Transparency)
		end
	elseif out and instance:IsA("Decal") then
		instance.Transparency = math.max(instance.Transparency, Config.Ghost.Transparency)
	end
end

local function styleCharacter(player: Player)
	local character = player.Character
	if character then
		for _, descendant in character:GetDescendants() do
			style(player, descendant)
		end
	end
end

-- Moves a ghost's character to where its mode says: lobby for Spectate, otherwise the map.
local function place(player: Player)
	local character = player.Character
	if not character or not player:GetAttribute("Out") then
		return
	end
	if player:GetAttribute("GhostMode") == "Spectate" then
		character:PivotTo(MapService.LobbyCFrame())
	elseif roundMap then
		local spawns = roundMap.Spawns
		local spawn = spawns[math.random(1, #spawns)]
		character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, Config.Maps.SpawnHeight, 0)))
	end
end

local function setMode(player: Player, mode: string, move: boolean)
	player:SetAttribute("GhostMode", mode)
	player:SetAttribute("GhostChat", if mode == "GhostChat" then true else nil)
	if move then
		place(player)
	end
end

function GhostService.BeginRound(map: MapService.LoadedMap, participants: { Player })
	roundMap = map
	for _, player in Players:GetPlayers() do
		player:SetAttribute("InRound", if table.find(participants, player) then true else nil)
		player:SetAttribute("Out", nil)
		player:SetAttribute("GhostMode", nil)
		player:SetAttribute("GhostChat", nil)
		player:SetAttribute("HauntReadyAt", nil)
	end
end

--[[
	Makes a participant a ghost. `inPlace` = caught standing on the map, so the ghost stays
	where it is; otherwise (died and respawned in the lobby) it is moved to its mode's spot.
]]
function GhostService.MarkOut(player: Player, inPlace: boolean)
	if player:GetAttribute("Out") then
		return
	end
	player:SetAttribute("Out", true)
	styleCharacter(player)
	SprintService.Apply(player)
	local mode = Config.Ghost.DefaultMode
	setMode(player, mode, not inPlace or mode == "Spectate")
end

function GhostService.EndRound()
	roundMap = nil
	for _, player in Players:GetPlayers() do
		for _, name in { "InRound", "Out", "GhostMode", "GhostChat", "HauntReadyAt" } do
			player:SetAttribute(name, nil)
		end
		player.ReplicationFocus = nil
	end
end

-- Watching from afar: stream the map to this player (see the header). Players still playing
-- (in the round and not out) can't move their streaming away from themselves.
local lastFocus: { [Player]: number } = {}

local function onSpectateFocus(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	if not on then
		player.ReplicationFocus = nil
		return
	end
	local now = os.clock()
	if now - (lastFocus[player] or 0) < Config.Performance.SpectateFocusCooldown then
		return
	end
	lastFocus[player] = now
	local playing = player:GetAttribute("InRound") == true and player:GetAttribute("Out") ~= true
	local map = roundMap
	if map and not playing and map.Floor.Parent then
		player.ReplicationFocus = map.Floor
	end
end

local function onSetGhostMode(player: Player, mode: unknown)
	if not roundMap or not player:GetAttribute("Out") or not isMode(mode) then
		return
	end
	if player:GetAttribute("GhostMode") == mode then
		return
	end
	local now = os.clock()
	if now - (lastSwitch[player] or 0) < Config.Ghost.ModeSwitchCooldown then
		return
	end
	lastSwitch[player] = now
	-- Into or out of Spectate moves between lobby and map; Haunt <-> GhostChat stays put.
	local previous = player:GetAttribute("GhostMode")
	setMode(player, mode :: string, mode == "Spectate" or previous == "Spectate")
end

-- Returns the number of Kings haunted (0 = not allowed, on cooldown, or none in range).
local lastHauntTry: { [Player]: number } = {}

local function onHaunt(player: Player): number
	local tryAt = os.clock()
	if tryAt - (lastHauntTry[player] or 0) < Config.Performance.HauntTryCooldown then
		return 0
	end
	lastHauntTry[player] = tryAt
	if
		not roundMap
		or not player:GetAttribute("Out")
		or player:GetAttribute("GhostMode") ~= "Haunt"
	then
		return 0
	end
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("HauntReadyAt") or 0) then
		return 0
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end
	local affected = KingService.Haunt(root.Position)
	if affected > 0 then
		-- Cooldown only starts when the haunt actually landed.
		player:SetAttribute("HauntReadyAt", now + Config.Ghost.Haunt.Cooldown)
	end
	return affected
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character.DescendantAdded:Connect(function(descendant)
			style(player, descendant)
		end)
		styleCharacter(player)
		-- A ghost that respawned (e.g. reset) goes back to its mode's spot.
		if player:GetAttribute("Out") and roundMap then
			task.defer(function()
				SprintService.Apply(player)
				place(player)
			end)
		end
	end)
	if player.Character then
		styleCharacter(player)
	end
end

function GhostService.Start()
	for _, group in { "Players", "Ghosts", "King" } do
		PhysicsService:RegisterCollisionGroup(group)
	end
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Ghosts", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "King", false)

	Remotes.Event("SetGhostMode").OnServerEvent:Connect(onSetGhostMode)
	Remotes.Function("Haunt").OnServerInvoke = onHaunt
	Remotes.Event("SpectateFocus").OnServerEvent:Connect(onSpectateFocus)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwitch[player] = nil
		lastHauntTry[player] = nil
		lastFocus[player] = nil
	end)
end

return GhostService
