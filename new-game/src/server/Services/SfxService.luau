--!strict
--[[
	Server-side sound: 3D sounds that everyone near them hears, the two SoundGroups, and the
	players' saved sound settings.

	SoundGroups in SoundService (created here, so they replicate):
	  Music   - hub music and map ambience
	  Effects - every sound effect (3D ones from here, 2D ones from src/client/Sounds.luau)
	Each client turns a group's volume down locally when the player switches it off.

	SfxService.Play3D(spec, part)            one-shot Config.Sounds-style spec on a part
	SfxService.StartFootsteps(model, root)   King footsteps until the model is gone

	Settings: SetSetting(key, on) with key "Music" or "Sounds"; saved in DataService
	(Settings) and mirrored to the player attributes SettingMusic / SettingSounds.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

export type Spec = {
	SoundId: string,
	Volume: number,
	PitchMin: number?,
	PitchMax: number?,
	RollOffMin: number?,
	RollOffMax: number?,
}

local SETTINGS = { "Music", "Sounds" }

local SfxService = {}

local lastSetting: { [Player]: number } = {}

local function group(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end

function SfxService.MusicGroup(): SoundGroup
	return group("Music")
end

function SfxService.EffectsGroup(): SoundGroup
	return group("Effects")
end

local function pitch(spec: Spec): number
	local low = spec.PitchMin or 1
	local high = spec.PitchMax or low
	return low + math.random() * (high - low)
end

-- Plays `spec` once from `part` (3D). Silent if the SoundId is "".
function SfxService.Play3D(spec: Spec, part: BasePart)
	if spec.SoundId == "" or not part.Parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.SoundId
	sound.Volume = spec.Volume
	sound.PlaybackSpeed = pitch(spec)
	sound.RollOffMinDistance = spec.RollOffMin or 10
	sound.RollOffMaxDistance = spec.RollOffMax or 80
	sound.SoundGroup = SfxService.EffectsGroup()
	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 10) -- in case it never loads or ends
end

--[[
	Heavy footsteps on `root` while `model` exists and is moving: every WalkInterval seconds,
	or ChaseInterval while the model's "Mode" attribute is "Chase". Ends with the model.
]]
function SfxService.StartFootsteps(model: Model, root: BasePart)
	local spec = Config.Sounds.KingFootstep
	if spec.SoundId == "" then
		return
	end
	task.spawn(function()
		while model.Parent and root.Parent do
			local chasing = model:GetAttribute("Mode") == "Chase"
			task.wait(if chasing then spec.ChaseInterval else spec.WalkInterval)
			local velocity = root.AssemblyLinearVelocity
			if root.Parent and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1 then
				SfxService.Play3D(spec, root)
			end
		end
	end)
end

local function applySettings(player: Player)
	local data = DataService.Get(player)
	local settings = data and data.Settings
	for _, key in SETTINGS do
		local on = if settings and typeof(settings[key]) == "boolean" then settings[key] else true
		player:SetAttribute("Setting" .. key, on)
	end
end

local function onSetSetting(player: Player, key: unknown, on: unknown)
	if typeof(key) ~= "string" or not table.find(SETTINGS, key) or typeof(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastSetting[player] or 0) < Config.Sounds.SettingsCooldown then
		return
	end
	lastSetting[player] = now
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Settings = data.Settings or { Music = true, Sounds = true }
	data.Settings[key] = on
	player:SetAttribute("Setting" .. key, on)
end

function SfxService.Start()
	SfxService.MusicGroup()
	SfxService.EffectsGroup()
	Remotes.Event("SetSetting").OnServerEvent:Connect(onSetSetting)

	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal("DataReady"):Connect(function()
			applySettings(player)
		end)
		if player:GetAttribute("DataReady") then
			applySettings(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSetting[player] = nil
	end)
end

return SfxService
