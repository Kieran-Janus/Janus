--!strict
--[[
	Who you can watch during a round, and keeping the camera on them. Shared by the ghost
	screen (GhostUI, caught players in Spectate mode) and lobby spectating (Spectate.luau).
	Not a screen itself (not in Main.client.luau's ORDER).

	A target is a Player in the round who isn't out (InRound and not Out), or a Pumpkin King
	(a Model named "PumpkinKing" in Workspace.Map, King Hunt only). In Hide & Seek the hidden
	pumpkins (HideSeekRole "Hider") can't be watched, so nobody can tell the seekers where they
	are (Config.HideSeek.SpectateHiders = true allows it).

	SpectateTargets.Kings() -> { Model }
	SpectateTargets.List() -> { Instance }          Kings first, then the players still in
	SpectateTargets.Step(current, step) -> Instance? the next (+1) / previous (-1) target, nil if none
	SpectateTargets.Watchable(target) -> boolean    still there and not caught
	SpectateTargets.Name(target) -> string          display name, or Config.King.Name
	SpectateTargets.IsKing(target) -> boolean
	SpectateTargets.Follow(target)                  camera on the target (call every frame)
	SpectateTargets.RestoreCamera()                 camera back on your own character
	SpectateTargets.StreamMap(on)                   ask the server to stream the round map to
	                                                you while watching from the lobby
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SpectateTargets = {}

function SpectateTargets.Kings(): { Model }
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, child in map:GetChildren() do
			if child.Name == "PumpkinKing" and child:IsA("Model") then
				table.insert(list, child)
			end
		end
	end
	return list
end

-- A player in the round you may watch: not out, and not a hidden Hide & Seek pumpkin.
local function watchablePlayer(other: Player): boolean
	if other:GetAttribute("InRound") ~= true or other:GetAttribute("Out") == true then
		return false
	end
	return Config.HideSeek.SpectateHiders
		or ReplicatedStorage:GetAttribute("Mode") ~= "HideSeek"
		or other:GetAttribute("HideSeekRole") ~= "Hider"
end

-- Everything you can watch: the Kings first, then the players still in the round.
function SpectateTargets.List(): { Instance }
	local list: { Instance } = {}
	for _, king in SpectateTargets.Kings() do
		table.insert(list, king)
	end
	for _, other in Players:GetPlayers() do
		if watchablePlayer(other) then
			table.insert(list, other)
		end
	end
	return list
end

-- The target `step` places after `current` in the list (wrapping round), or nil if nobody.
function SpectateTargets.Step(current: Instance?, step: number): Instance?
	local list = SpectateTargets.List()
	if #list == 0 then
		return nil
	end
	local index = (current and table.find(list, current)) or 0
	return list[(index + step - 1) % #list + 1]
end

function SpectateTargets.Watchable(target: Instance?): boolean
	if not target or target.Parent == nil then
		return false
	end
	if target:IsA("Player") then
		return watchablePlayer(target)
	end
	return true
end

function SpectateTargets.IsKing(target: Instance): boolean
	return not target:IsA("Player")
end

function SpectateTargets.Name(target: Instance): string
	if target:IsA("Player") then
		return target.DisplayName
	end
	return Config.King.Name
end

-- The Humanoid the camera should follow for a target.
local function subjectOf(target: Instance?): Humanoid?
	if not target then
		return nil
	end
	local model = if target:IsA("Player") then target.Character else target
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- Points the camera at the target (cheap to call every frame; only changes it when needed).
function SpectateTargets.Follow(target: Instance?)
	local humanoid = subjectOf(target)
	local camera = workspace.CurrentCamera
	if humanoid and camera and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

function SpectateTargets.RestoreCamera()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid and camera then
		camera.CameraSubject = humanoid
	end
end

-- The server creates SpectateFocus in GhostService.Start; fetched in the background so a
-- slow server start never holds anything up.
local focusRemote: RemoteEvent? = nil
local fetching = false
local wanted = false

function SpectateTargets.StreamMap(on: boolean)
	wanted = on
	if focusRemote then
		focusRemote:FireServer(on)
		return
	end
	if fetching then
		return
	end
	fetching = true
	task.spawn(function()
		local remote = Remotes.Event("SpectateFocus")
		focusRemote = remote
		remote:FireServer(wanted)
	end)
end

return SpectateTargets
