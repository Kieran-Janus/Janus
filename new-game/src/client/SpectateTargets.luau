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
	SpectateTargets.Follow(target)                  camera on the target (call every frame);
	                                                a new target glides over (Config.ScreenMotion.SpectateCamera)
	SpectateTargets.RestoreCamera()                 camera back on your own character
	SpectateTargets.StopGlide()                     stop a glide now (something else wants the camera)
	SpectateTargets.Gliding() -> boolean
	SpectateTargets.StreamMap(on)                   ask the server to stream the round map to
	                                                you while watching from the lobby
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScreenFx = require(script.Parent.ScreenFx)

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

-- Glides (Config.ScreenMotion.SpectateCamera) ------------------------------------------------
-- Changing CameraSubject makes the camera jump. Instead the camera turns Scriptable for
-- GlideSeconds and slides from where it is to where the normal camera will be behind the new
-- subject (same angle and distance as before), then it's handed back: CameraType Custom, the
-- new subject. A newer switch restarts the glide from wherever the camera is, so it always
-- ends on the last one. Nothing else may own the camera meanwhile: if something else changes
-- CameraType, the glide stops and only sets the subject.

type Glide = {
	Subject: Humanoid,
	From: CFrame,
	Offset: Vector3, -- camera position minus the focus point, kept for the new subject
	Started: number,
	Connection: RBXScriptConnection,
}
local glide: Glide? = nil

local function smoothing(): boolean
	local cfg = Config.ScreenMotion.SpectateCamera
	return cfg.On == true and cfg.GlideSeconds > 0 and ScreenFx.On()
end

-- The point the normal camera looks at on a humanoid (a little above its root).
local function focusOf(humanoid: Humanoid): Vector3?
	local root = humanoid.RootPart
	if not root then
		local model = humanoid.Parent
		local part = model and model:FindFirstChild("HumanoidRootPart")
		root = if part and part:IsA("BasePart") then part else nil
	end
	return if root then root.Position + Vector3.new(0, 1.5, 0) else nil
end

-- Ends the glide: the normal camera on `subject` (kept as is when `handBack` is false,
-- because something else took the camera).
local function endGlide(handBack: boolean)
	local current = glide
	if not current then
		return
	end
	glide = nil
	current.Connection:Disconnect()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if handBack then
		camera.CameraType = Enum.CameraType.Custom
	end
	if current.Subject:IsDescendantOf(workspace) then
		camera.CameraSubject = current.Subject
	elseif handBack then
		-- Its character was removed during the glide (e.g. a respawn as the round ended; a
		-- removed character keeps its Humanoid, so check Workspace): back to your own one.
		local character = Players.LocalPlayer.Character
		local own = character and character:FindFirstChildOfClass("Humanoid")
		if own then
			camera.CameraSubject = own
		end
	end
end

local function glideTo(camera: Camera, humanoid: Humanoid)
	local to = focusOf(humanoid)
	local old = camera.CameraSubject
	local from = camera.CFrame
	local current = glide
	local oldFocus = if current then focusOf(current.Subject) else nil
	if not oldFocus then
		oldFocus = if old and old:IsA("Humanoid") then focusOf(old) else camera.Focus.Position
	end
	if not to or not oldFocus then
		endGlide(true)
		camera.CameraSubject = humanoid -- nothing to glide to yet: jump like before
		return
	end
	local offset = if current then current.Offset else from.Position - oldFocus
	if offset.Magnitude < 1 then
		offset = -from.LookVector * Config.ScreenMotion.SpectateCamera.FallbackDistance
	end
	if current then
		current.Connection:Disconnect()
		glide = nil
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local g = glide
		if not g then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			endGlide(false) -- something else took the camera
			return
		end
		local seconds = Config.ScreenMotion.SpectateCamera.GlideSeconds
		local a = math.clamp((os.clock() - g.Started) / seconds, 0, 1)
		local focus = focusOf(g.Subject)
		if not focus or not g.Subject:IsDescendantOf(workspace) then
			endGlide(true)
			return
		end
		local eased = 1 - (1 - a) * (1 - a) -- quick start, gentle landing
		local goal = CFrame.lookAt(focus + g.Offset, focus)
		camera.CFrame = if a >= 1 then goal else g.From:Lerp(goal, eased)
		if a >= 1 then
			endGlide(true) -- exactly where the normal camera takes over
		end
	end)
	glide = {
		Subject = humanoid,
		From = from,
		Offset = offset,
		Started = started,
		Connection = connection,
	}
end

-- Points the camera at `humanoid`: a glide, or a jump with smoothing off.
local function aim(humanoid: Humanoid)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local current = glide
	if current and current.Subject == humanoid then
		return -- already on its way there
	end
	if not current and camera.CameraSubject == humanoid then
		return
	end
	-- Glide only from the normal camera (or another glide): never fight a cutscene or the
	-- haunt cam, and with smoothing off switch at once like before.
	local gliding = current ~= nil and camera.CameraType == Enum.CameraType.Scriptable
	if smoothing() and (gliding or camera.CameraType == Enum.CameraType.Custom) then
		glideTo(camera, humanoid)
	else
		endGlide(current ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
		camera.CameraSubject = humanoid
	end
end

-- Points the camera at the target (cheap to call every frame; only changes it when needed).
function SpectateTargets.Follow(target: Instance?)
	local humanoid = subjectOf(target)
	if humanoid then
		aim(humanoid)
	end
end

-- Camera back on your own character (gliding there too), ending on CameraType Custom.
function SpectateTargets.RestoreCamera()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		aim(humanoid)
	else
		local camera = workspace.CurrentCamera
		endGlide(camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
	end
end

-- Stops a glide at once (something else wants the camera, e.g. the ghost's haunt cam); the
-- camera keeps the subject it was gliding to.
function SpectateTargets.StopGlide()
	endGlide(false)
end

-- True while the camera is gliding between targets.
function SpectateTargets.Gliding(): boolean
	return glide ~= nil
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
