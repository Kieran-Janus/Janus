--!strict
--[[
	Photo Spot dances on this screen (Config.Dances; on/off: Config.Features.Dances).

	Every character with a Dance attribute (set by the server's DanceService) dances here: its
	joints move with DanceMoves, after Roblox's own animations each frame, so everyone sees
	everyone dance. A dance with an AnimationId plays that animation instead (only the
	dancer's own screen plays it; Roblox shows it to everyone).
	Your own dance stops when you walk or jump (and the server stops it too).

	Dances.Request(id)     ask the server to dance `id` ("" = stop); used by the dance bar
	Dances.Current() -> string?   the dance your character is doing
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DanceMoves = require(ReplicatedStorage.Shared.DanceMoves)

local Dances = {}

local cfg = Config.Dances
local remote: RemoteEvent? = nil

type Active = {
	Id: string,
	Started: number,
	Joints: { [string]: DanceMoves.Joint },
}
local active: { [Model]: Active } = {}
local ownTrack: AnimationTrack? = nil
local ownTrackId: string? = nil

local function defOf(id: string): { Id: string, Label: string, AnimationId: string }?
	for _, dance in cfg.List do
		if dance.Id == id then
			return dance
		end
	end
	return nil
end

local function getRemote(): RemoteEvent
	local r = remote
	if r then
		return r
	end
	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	local made = Remotes.Event("Dance")
	remote = made
	return made
end

function Dances.Request(id: string)
	if not Config.Features.Dances then
		return
	end
	getRemote():FireServer(id)
end

function Dances.Current(): string?
	local character = Players.LocalPlayer.Character
	local id = character and character:GetAttribute("Dance")
	return if type(id) == "string" and id ~= "" then id else nil
end

local function stopOwnTrack()
	local track = ownTrack
	if track then
		track:Stop(0.2)
		track:Destroy()
	end
	ownTrack, ownTrackId = nil, nil
end

-- Your own uploaded animation (a dance with an AnimationId).
local function playOwnTrack(character: Model, id: string, animationId: string)
	if ownTrackId == id then
		return
	end
	stopOwnTrack()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2)
		ownTrack, ownTrackId = track, id
	end
end

local function step()
	local now = os.clock()
	local me = Players.LocalPlayer
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local id = character:GetAttribute("Dance")
		if type(id) ~= "string" or id == "" then
			continue
		end
		local def = defOf(id)
		local animationId = if def then def.AnimationId else ""
		if animationId ~= "" then
			if player == me then
				playOwnTrack(character, id, animationId)
			end
			continue
		end
		seen[character] = true
		local state = active[character]
		if not state or state.Id ~= id then
			state = { Id = id, Started = now, Joints = DanceMoves.Joints(character) }
			active[character] = state
		end
		DanceMoves.Apply(state.Joints, DanceMoves.Pose(id, (now - state.Started) * cfg.Speed))
	end
	for character, state in active do
		if not seen[character] then
			if character.Parent then
				DanceMoves.Clear(state.Joints)
			end
			active[character] = nil
		end
	end
	if ownTrack and not Dances.Current() then
		stopOwnTrack()
	end
	-- Walking or jumping stops your own dance.
	local character = me.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		humanoid
		and Dances.Current()
		and (humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump)
	then
		if character then
			character:SetAttribute("Dance", nil) -- stop on this screen now; the server agrees
		end
		Dances.Request("")
	end
end

function Dances.Mount(_gui: ScreenGui)
	if not Config.Features.Dances then
		return
	end
	-- After Roblox's animations have set the joints this frame, so the dance wins.
	RunService.PreSimulation:Connect(step)
end

return Dances
