--!strict
--[[
	Proximity voice for the round.

	Roblox creates the voice graph for us (VoiceChatService.EnableDefaultVoice):
	  Player.AudioDeviceInput --Wire--> Character.AudioEmitter, and an AudioListener on the camera.
	This service adjusts it:
	  - Acoustic Simulation on, so voices are muffled through walls.
	  - Every voice emitter uses Config.Voice.Attenuation.
	  - Ghosts: an AudioEcho is spliced in (device -> echo -> emitter).
	  - Who hears whom, via AudioDeviceInput access lists (enforced by Roblox, not the client):
	      living players: everyone can hear them
	      ghosts in GhostChat mode: only other GhostChat ghosts
	      other ghosts: nobody
	  - VoiceLevel(level) hint from clients -> clamped, rate-limited noise for the King.

	Players without voice simply have no AudioDeviceInput; every step skips them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NoiseService = require(script.Parent.NoiseService)

local VoiceService = {}

local ECHO_NAME = "GhostEcho"
local lastHint: { [Player]: number } = {}

local function deviceOf(player: Player): AudioDeviceInput?
	return player:FindFirstChildOfClass("AudioDeviceInput")
end

local function isGhostChat(player: Player): boolean
	return player:GetAttribute("Out") == true and player:GetAttribute("GhostMode") == "GhostChat"
end

local function newWire(source: Instance, target: Instance, parent: Instance): Wire
	local wire = Instance.new("Wire")
	wire.SourceInstance = source
	wire.TargetInstance = target
	wire.Parent = parent
	return wire
end

-- Wires leaving `instance` that weren't created by us.
local function outputWires(instance: Instance): { Wire }
	local ok, wires = pcall(function()
		return (instance :: any):GetConnectedWires("Output")
	end)
	return if ok then wires else {}
end

-- Splices the ghost echo in or out of the player's voice chain. Safe to call repeatedly.
local function routeEcho(device: AudioDeviceInput, ghost: boolean)
	local echo = device:FindFirstChild(ECHO_NAME) :: AudioEcho?
	if ghost then
		if not echo then
			local cfg = Config.Voice.GhostEcho
			local newEcho = Instance.new("AudioEcho")
			newEcho.Name = ECHO_NAME
			newEcho.DelayTime = cfg.DelayTime
			newEcho.Feedback = cfg.Feedback
			newEcho.DryLevel = cfg.DryLevel
			newEcho.WetLevel = cfg.WetLevel
			newEcho.Parent = device
			echo = newEcho
		end
		-- Any wire from the device that bypasses the echo (e.g. a respawned character's new
		-- emitter) is redirected: device -> echo -> that target.
		for _, wire in outputWires(device) do
			local target = wire.TargetInstance
			if target and target ~= echo then
				wire.TargetInstance = echo
				newWire(echo :: AudioEcho, target, echo :: AudioEcho)
			end
		end
	elseif echo then
		-- Point the device's wires straight back at whatever the echo fed, then remove it.
		local targets = {}
		for _, wire in outputWires(echo) do
			if wire.TargetInstance then
				table.insert(targets, wire.TargetInstance)
			end
		end
		local intoEcho = {}
		for _, wire in outputWires(device) do
			if wire.TargetInstance == echo then
				table.insert(intoEcho, wire)
			end
		end
		for i, target in targets do
			if intoEcho[i] then
				intoEcho[i].TargetInstance = target
			else
				newWire(device, target, target)
			end
		end
		echo:Destroy()
	end
end

-- New voice emitters (each character gets one) use our distance curve, once.
-- Only emitters fed by this player's mic (directly or via the echo) count as voice emitters.
local function tuneEmitters(device: AudioDeviceInput)
	local sources: { [Instance]: boolean } = { [device] = true }
	local echo = device:FindFirstChild(ECHO_NAME)
	if echo then
		sources[echo] = true
	end
	for source in sources do
		for _, wire in outputWires(source) do
			local emitter = wire.TargetInstance
			if
				emitter
				and emitter:IsA("AudioEmitter")
				and not emitter:GetAttribute("VoiceTuned")
			then
				emitter:SetDistanceAttenuation(Config.Voice.Attenuation)
				emitter:SetAttribute("VoiceTuned", true)
			end
		end
	end
end

local function sameList(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	local set = {}
	for _, id in a do
		set[id] = true
	end
	for _, id in b do
		if not set[id] then
			return false
		end
	end
	return true
end

local function updateAccess(device: AudioDeviceInput, player: Player)
	local accessType = Enum.AccessModifierType.Deny -- deny-list of nobody = everyone hears
	local list: { number } = {}
	if player:GetAttribute("Out") then
		accessType = Enum.AccessModifierType.Allow -- allow-list: only these hear
		if isGhostChat(player) then
			for _, other in Players:GetPlayers() do
				if other ~= player and isGhostChat(other) then
					table.insert(list, other.UserId)
				end
			end
		end
	end
	-- Only write when something changed; this runs every ReconcileSeconds.
	if device.AccessType ~= accessType or not sameList(device:GetUserIdAccessList(), list) then
		device.AccessType = accessType
		device:SetUserIdAccessList(list)
	end
end

function VoiceService.Reconcile()
	for _, player in Players:GetPlayers() do
		local device = deviceOf(player)
		if device then
			local ok, err = pcall(function()
				routeEcho(device, player:GetAttribute("Out") == true)
				tuneEmitters(device)
				updateAccess(device, player)
			end)
			if not ok then
				warn(("[VoiceService] %s: %s"):format(player.Name, tostring(err)))
			end
		end
	end
end

local function onVoiceLevel(player: Player, level: unknown)
	if typeof(level) ~= "number" or level ~= level then -- also rejects NaN
		return
	end
	local cfg = Config.Voice.Noise
	local now = os.clock()
	if now - (lastHint[player] or 0) < cfg.MinHintGapSeconds then
		return
	end
	lastHint[player] = now

	local clamped = math.clamp(level, 0, 1)
	if clamped < cfg.MinLevel or player:GetAttribute("Out") then
		return
	end
	-- Only players who actually have an unmuted voice device can make voice noise.
	local device = deviceOf(player)
	if not device or device.Muted or (cfg.RequireActiveMic and not device.Active) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local loudness = math.min(clamped * cfg.LevelGain, 1) * cfg.MaxLoudness
	NoiseService.Report(root.Position, loudness, player)
end

function VoiceService.Start()
	local ok, err = pcall(function()
		SoundService.AcousticSimulationEnabled = Config.Voice.AcousticSimulation
	end)
	if not ok then
		warn("[VoiceService] could not set AcousticSimulationEnabled: " .. tostring(err))
	end

	Remotes.Event("VoiceLevel").OnServerEvent:Connect(onVoiceLevel)

	local function onPlayer(player: Player)
		for _, name in { "Out", "GhostMode" } do
			player:GetAttributeChangedSignal(name):Connect(VoiceService.Reconcile)
		end
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				task.defer(VoiceService.Reconcile)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastHint[player] = nil
		task.defer(VoiceService.Reconcile) -- a ghost-chat member left
	end)

	-- Catches what events miss: respawned characters get a fresh emitter and wire.
	task.spawn(function()
		while true do
			task.wait(Config.Voice.ReconcileSeconds)
			VoiceService.Reconcile()
		end
	end)
end

return VoiceService
