--!strict
--[[
	Per-place look, local to this client: when the camera is over the round map (Workspace.Map,
	attribute MapId) the map's Config.Maps.List[i].Lighting and AmbientSound are used,
	otherwise the hub's Config.Hub.Lighting and hub music. Players still in the hub (or
	spectating from it) keep the hub look while others play.
	The server creates the effects (Lighting.HubAtmosphere, HubColorCorrection, HubBloom);
	this only changes their properties on this client.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local ZoneLighting = {}

local function mapDef(id: unknown): any
	for _, def in Config.Maps.List do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- The map whose floor the camera is over, or nil (hub).
local function currentMap(): any
	local map = workspace:FindFirstChild("Map")
	local camera = workspace.CurrentCamera
	if not map or not camera then
		return nil
	end
	local floor = map:FindFirstChild("Floor", true)
	if not floor or not floor:IsA("BasePart") then
		return nil
	end
	local p = floor.CFrame:PointToObjectSpace(camera.Focus.Position)
	local margin = 10
	if
		math.abs(p.X) <= floor.Size.X / 2 + margin
		and math.abs(p.Z) <= floor.Size.Z / 2 + margin
	then
		return mapDef(map:GetAttribute("MapId"))
	end
	return nil
end

local function tween(instance: Instance?, goals: { [string]: any }, seconds: number)
	if instance then
		TweenService:Create(instance, TweenInfo.new(seconds), goals):Play()
	end
end

local function apply(profile: any, seconds: number)
	-- ClockTime jumps (tweening it would sweep through daytime).
	Lighting.ClockTime = profile.ClockTime
	tween(Lighting, {
		Brightness = profile.Brightness,
		Ambient = profile.Ambient,
		OutdoorAmbient = profile.OutdoorAmbient,
	}, seconds)
	tween(Lighting:FindFirstChild("HubAtmosphere"), profile.Atmosphere, seconds)
	tween(Lighting:FindFirstChild("HubColorCorrection"), profile.ColorCorrection, seconds)
	tween(Lighting:FindFirstChild("HubBloom"), profile.Bloom, seconds)
	-- The lobby's soft far focus is only for the lobby: round maps (and spectating) stay sharp.
	local dof = Lighting:FindFirstChild("HubDepthOfField")
	if dof and dof:IsA("DepthOfFieldEffect") then
		local hubDof = Config.Hub.Lighting.DepthOfField
		dof.Enabled = profile == Config.Hub.Lighting and hubDof.Enabled
	end
end

function ZoneLighting.Mount()
	local ambience = Instance.new("Sound")
	ambience.Name = "MapAmbience"
	ambience.Looped = true
	ambience.Volume = 0
	ambience.Parent = SoundService
	-- Map ambience counts as music for the Settings toggle.
	task.spawn(function()
		local group = SoundService:WaitForChild("Music", 30)
		if group and group:IsA("SoundGroup") then
			ambience.SoundGroup = group
		end
	end)

	local current: any = false -- false = nothing applied yet, nil = hub
	task.spawn(function()
		while true do
			local def = currentMap()
			if def ~= current then
				current = def
				local seconds = Config.Maps.LightingFadeSeconds
				apply(if def then def.Lighting else Config.Hub.Lighting, seconds)

				local hub = workspace:FindFirstChild("Hub")
				local music = hub and hub:FindFirstChild("Music")
				if music and music:IsA("Sound") then
					tween(music, { Volume = if def then 0 else Config.Hub.Music.Volume }, seconds)
				end
				local sound = def and def.AmbientSound
				if sound and sound.SoundId ~= "" then
					ambience.SoundId = sound.SoundId
					ambience:Play()
					tween(ambience, { Volume = sound.Volume }, seconds)
				else
					tween(ambience, { Volume = 0 }, seconds)
				end
			end
			task.wait(Config.Maps.ZoneCheckSeconds)
		end
	end)
end

return ZoneLighting
