--!strict
--[[
	2D sound effects for this player (Config.Sounds), and the Music / Sounds settings.

	Sounds.Play(name)      plays Config.Sounds[name] once (no-op for "" or unknown names).
	Sounds.PlaySpec(spec, at?)  plays { SoundId, Volume?, PitchMin?, PitchMax? } once, for
	                       features that keep their sounds in their own config file; with
	                       `at` (a part or Attachment) it is a 3D sound coming from there.
	Mount() also wires the automatic ones:
	  - click and hover on every button in the game UI (anything added to PlayerGui)
	  - pumpkin pickup (random pitch), coins gained, round start, countdown ticks,
	    getting caught and the ghost whoosh after it
	Settings: the server sets the player attributes SettingMusic / SettingSounds (saved);
	this turns SoundService's Music / Effects groups up or down on this client only.
	3D sounds (King, minions) are made by the server (SfxService) in the Effects group.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

local effectsGroup: SoundGroup? = nil

-- A sound description, as in Config.Sounds or a feature's own config file.
export type Spec = {
	SoundId: string, -- "rbxassetid://..." ("" = silent)
	Volume: number?, -- 0-1 (default 0.5)
	PitchMin: number?, -- random pitch between these each play (default 1)
	PitchMax: number?,
}

-- Plays a sound described by `spec` once, in the Effects group (so the Sounds setting
-- mutes it). Features keep their sound ids in their own config file and call this.
-- `at` (a BasePart or Attachment) makes it a 3D sound coming from there.
function Sounds.PlaySpec(spec: Spec, at: Instance?)
	if type(spec) ~= "table" or type(spec.SoundId) ~= "string" or spec.SoundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.SoundId
	sound.Volume = spec.Volume or 0.5
	local low = spec.PitchMin or 1
	local high = spec.PitchMax or low
	sound.PlaybackSpeed = low + math.random() * (high - low)
	sound.SoundGroup = effectsGroup
	sound.Parent = if at and (at:IsA("BasePart") or at:IsA("Attachment")) then at else SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Plays Config.Sounds[name] once (no-op for "" or unknown names).
function Sounds.Play(name: string)
	local spec = (Config.Sounds :: any)[name]
	if type(spec) == "table" then
		Sounds.PlaySpec(spec)
	end
end

local function hookButton(instance: Instance)
	if not instance:IsA("GuiButton") or instance:GetAttribute("NoSound") then
		return
	end
	instance.Activated:Connect(function()
		Sounds.Play("Click")
	end)
	instance.MouseEnter:Connect(function()
		Sounds.Play("Hover")
	end)
end

function Sounds.Mount()
	local player = Players.LocalPlayer
	local musicGroup: SoundGroup? = nil

	-- Settings ---------------------------------------------------------------------------------
	local function applySettings()
		if musicGroup then
			musicGroup.Volume = if player:GetAttribute("SettingMusic") == false then 0 else 1
		end
		if effectsGroup then
			effectsGroup.Volume = if player:GetAttribute("SettingSounds") == false then 0 else 1
		end
	end
	player:GetAttributeChangedSignal("SettingMusic"):Connect(applySettings)
	player:GetAttributeChangedSignal("SettingSounds"):Connect(applySettings)
	-- The server creates the groups; don't hold up the rest of the UI waiting for them.
	task.spawn(function()
		musicGroup = SoundService:WaitForChild("Music", 30) :: SoundGroup?
		effectsGroup = SoundService:WaitForChild("Effects", 30) :: SoundGroup?
		applySettings()
	end)

	-- Buttons ------------------------------------------------------------------------------------
	local playerGui = player:WaitForChild("PlayerGui")
	for _, d in playerGui:GetDescendants() do
		hookButton(d)
	end
	playerGui.DescendantAdded:Connect(hookButton)

	-- Pumpkins and coins ---------------------------------------------------------------------------
	local pumpkins = player:GetAttribute("Pumpkins") or 0
	player:GetAttributeChangedSignal("Pumpkins"):Connect(function()
		local now = player:GetAttribute("Pumpkins") or 0
		if now > pumpkins then
			Sounds.Play("PumpkinPickup")
		end
		pumpkins = now
	end)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 60)
		local coins = stats and stats:WaitForChild("Coins", 60)
		if coins and coins:IsA("IntValue") then
			local last = coins.Value
			coins.Changed:Connect(function(value)
				if value > last then
					Sounds.Play("Coins")
				end
				last = value
			end)
		end
	end)

	-- Round --------------------------------------------------------------------------------------
	-- Players waiting in the lobby during someone else's round don't hear its start or its
	-- last-seconds ticks (they only hear the vote and intermission countdowns).
	local tick = Config.Sounds.CountdownTick
	local lastState = ReplicatedStorage:GetAttribute("State")
	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(function()
		local state = ReplicatedStorage:GetAttribute("State")
		if state == "Playing" and lastState ~= "Playing" and player:GetAttribute("InRound") then
			Sounds.Play("RoundStart")
		end
		lastState = state
	end)
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(function()
		local left = ReplicatedStorage:GetAttribute("TimeLeft")
		local state = ReplicatedStorage:GetAttribute("State")
		if
			typeof(left) == "number"
			and left > 0
			and left <= tick.LastSeconds
			and table.find(tick.States, state)
			and (state ~= "Playing" or player:GetAttribute("InRound"))
		then
			Sounds.Play("CountdownTick")
		end
	end)

	-- Caught -> ghost ------------------------------------------------------------------------------
	player:GetAttributeChangedSignal("Out"):Connect(function()
		if player:GetAttribute("Out") then
			Sounds.Play("Caught")
			task.delay(Config.Sounds.Ghost.Delay, Sounds.Play, "Ghost")
		end
	end)
end

return Sounds
