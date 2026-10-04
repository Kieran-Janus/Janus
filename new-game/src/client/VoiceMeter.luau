--!strict
--[[
	Measures this player's own microphone level and sends it as a hint (VoiceLevel) so the
	King can hear loud talkers. The server clamps and rate-limits it, so this is only ever
	a hint. Players without voice have no AudioDeviceInput and nothing happens.
	Only sends while alive in a round and above the silence threshold.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local VoiceMeter = {}

function VoiceMeter.Mount()
	local player = Players.LocalPlayer
	local voiceLevel = Remotes.Event("VoiceLevel")
	local analyzer: AudioAnalyzer? = nil

	local function attach(device: AudioDeviceInput)
		if analyzer and analyzer.Parent then
			return
		end
		-- Local-only analyzer listening to our own mic; it isn't heard by anyone.
		local newAnalyzer = Instance.new("AudioAnalyzer")
		newAnalyzer.Name = "VoiceMeter"
		local wire = Instance.new("Wire")
		wire.SourceInstance = device
		wire.TargetInstance = newAnalyzer
		wire.Parent = newAnalyzer
		newAnalyzer.Parent = device
		analyzer = newAnalyzer
	end

	local existing = player:FindFirstChildOfClass("AudioDeviceInput")
	if existing then
		attach(existing)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			attach(child)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Voice.Noise.HintSeconds)
			local current = analyzer
			if
				current
				and current.Parent
				and ReplicatedStorage:GetAttribute("State") == "Playing"
				and player:GetAttribute("InRound")
				and not player:GetAttribute("Out")
			then
				local level = current.RmsLevel
				if level >= Config.Voice.Noise.MinLevel then
					voiceLevel:FireServer(level)
				end
			end
		end
	end)
end

return VoiceMeter
