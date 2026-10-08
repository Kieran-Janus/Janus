--!strict
--[[
	Walk styles on this screen (a skin's Style.Motion; the poses are in
	src/shared/SkinMotion.luau, the numbers in Config.SkinMotion). The server only sets the
	character attributes SkinMotion (a code-made style: "Zombie", "Ghost"...) and SkinMotionIds
	(your own uploaded animations) when it dresses you (src/shared/Cosmetics.luau).

	  Code-made styles  every screen poses every nearby character itself, after Roblox's own
	                    animations each frame (like the Photo Spot dances). A joint in "Set"
	                    mode replaces the walk animation (the zombie's arms); "Add" goes on top
	                    of it (a lean, a hop) and never builds up from frame to frame.
	  Uploaded ids      only your own screen plays them, on your own character (walk, run or
	                    idle by your speed); Roblox shows them to everyone. They must belong to
	                    the game's owner (or Roblox), or Roblox won't play them: in Studio a
	                    warning says so and your normal walk stays.
	Only the closest Config.SkinMotion.MaxCharacters characters (fewer on phones, yours first)
	get a walk style. A character that is dancing (the dance wins), sitting, dead, a Hide &
	Seek hider or off screen gets none, and in the air it fades out. Your own float or hop is
	kept small (OwnRootShiftMax) so you don't bump ceilings. Nothing runs per frame while
	nobody has a walk style. On/off: Config.Features.WalkStyles.

	SkinWalk.Mount(gui)       starts watching (does nothing when switched off)
	SkinWalk.Active() -> number   characters with a walk style posed right now
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DanceMoves = require(ReplicatedStorage.Shared.DanceMoves)
local SkinMotion = require(ReplicatedStorage.Shared.SkinMotion)
local Layout = require(script.Parent.Layout)

type Joint = DanceMoves.Joint

local SkinWalk = {}

type Walker = {
	Character: Model,
	Player: Player,
	Own: boolean,
	Joints: { [string]: Joint },
	Preset: string,
	Active: boolean, -- picked this time (in range, on screen, within the budget)
	Fade: number, -- 0 = not posed, 1 = fully posed
	HalfRate: boolean,
	Cached: { [Joint]: SkinMotion.JointPose }, -- the pose in each joint's own directions
	Written: { [Joint]: CFrame }, -- what this screen last wrote
	LastBase: { [Joint]: CFrame }, -- Roblox's own pose under ours, last frame
	Modes: { [Joint]: "Set" | "Add" },
}

local walkers: { [Model]: Walker } = {}
local loop: RBXScriptConnection? = nil
local mounted = false
local nextPick = 0
local frame = 0
local wanted = false -- someone has a walk style (or your own animations)

-- Your own uploaded animations.
type Own = {
	Character: Model?,
	Text: string?,
	Tracks: { [string]: AnimationTrack },
	LoadedAt: number,
	Checked: boolean,
}
local own: Own = { Character = nil, Text = nil, Tracks = {}, LoadedAt = 0, Checked = false }
local warned: { [string]: boolean } = {}

local function settings()
	return Config.SkinMotion
end

local function phone(): boolean
	local ok, result = pcall(Layout.IsPhone)
	return ok and result == true
end

local function humanoidOf(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function dancing(character: Model): boolean
	local dance = character:GetAttribute("Dance")
	return type(dance) == "string" and dance ~= ""
end

local function hider(player: Player): boolean
	return player:GetAttribute("HideSeekRole") == "Hider"
end

-- Roblox's newer Animator says when it skipped a frame (throttling far-away characters).
-- Older clients (and the offline tests) don't have it: then we guess.
local throttleKnown = true
local function throttled(character: Model): boolean?
	if not throttleKnown then
		return nil
	end
	local humanoid = humanoidOf(character)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local ok, value = pcall(function()
		return (animator :: any).EvaluationThrottled
	end)
	if not ok or type(value) ~= "boolean" then
		throttleKnown = false
		return nil
	end
	return value
end

-- Puts the joints back: Set ones to rest (Roblox's walk takes over), Add ones to Roblox's pose.
local function stopPose(w: Walker)
	for joint, mode in w.Modes do
		if joint.Parent then
			local motor: any = joint
			motor.Transform = if mode == "Set"
				then CFrame.identity
				else w.LastBase[joint] or CFrame.identity
		end
	end
	table.clear(w.Modes)
	table.clear(w.Written)
	table.clear(w.LastBase)
	table.clear(w.Cached)
	w.Fade = 0
end

local function newWalker(character: Model, player: Player, preset: string): Walker
	return {
		Character = character,
		Player = player,
		Own = player == Players.LocalPlayer,
		Joints = DanceMoves.Joints(character),
		Preset = preset,
		Active = false,
		Fade = 0,
		HalfRate = false,
		Cached = {},
		Written = {},
		LastBase = {},
		Modes = {},
	}
end

local function onScreen(root: BasePart): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local point = camera:WorldToViewportPoint(root.Position)
	local size = camera.ViewportSize
	local m = 0.2
	return point.Z > 0
		and point.X >= -m * size.X
		and point.X <= (1 + m) * size.X
		and point.Y >= -m * size.Y
		and point.Y <= (1 + m) * size.Y
end

-- Who gets a walk style: the closest (yours first), up to MaxCharacters (fewer on phones).
local function pick()
	local cfg = settings()
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	local near: { { Walker: Walker, Distance: number } } = {}
	local seen: { [Model]: boolean } = {}
	wanted = false
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		if player == Players.LocalPlayer and character:GetAttribute("SkinMotionIds") ~= nil then
			wanted = true
		end
		local preset = character:GetAttribute("SkinMotion")
		if type(preset) ~= "string" or not SkinMotion.Has(preset) then
			continue
		end
		wanted = true
		seen[character] = true
		local w = walkers[character]
		if not w then
			w = newWalker(character, player, preset)
			walkers[character] = w
		elseif w.Preset ~= preset then
			stopPose(w)
			w.Preset = preset
		end
		if next(w.Joints) == nil then
			w.Joints = DanceMoves.Joints(character) -- (joints streamed in later)
		end
		local humanoid = humanoidOf(character)
		local root = rootOf(character)
		local ok = humanoid ~= nil
			and root ~= nil
			and character:IsDescendantOf(Workspace)
			and humanoid.Health > 0
			and not humanoid.Sit
			and not dancing(character)
			and not hider(player)
		local distance = if root then (root.Position - from).Magnitude else math.huge
		if ok and root and not w.Own then
			ok = distance <= cfg.MaxDistance and onScreen(root)
		end
		if ok then
			table.insert(near, { Walker = w, Distance = if w.Own then -1 else distance })
		else
			w.Active = false
			stopPose(w)
		end
	end
	for character, w in walkers do
		if not seen[character] then
			stopPose(w)
			walkers[character] = nil
		end
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	local limit = if phone() then cfg.PhoneMaxCharacters else cfg.MaxCharacters
	for i, candidate in near do
		local w = candidate.Walker
		if i <= limit then
			w.Active = true
			w.HalfRate = candidate.Distance > cfg.HalfRateDistance
		else
			w.Active = false
			stopPose(w)
		end
	end
end

-- The pose for this frame, turned into each joint's own directions.
local function poseOf(w: Walker, t: number, move: number): { [Joint]: SkinMotion.JointPose }
	local pose = SkinMotion.Pose(w.Preset, t, move)
	local joints = w.Joints
	-- R6 has no waist: it bends with the whole body
	local waist = pose.Waist
	if waist and not joints.Waist then
		local root = pose.Root
		pose.Root = {
			Mode = if root then root.Mode else "Add",
			Turn = (if root then root.Turn else CFrame.identity) * waist.Turn,
		}
		local loose: any = pose
		loose.Waist = nil
	end
	-- your own float or hop stays small, so your head doesn't bump ceilings
	local root = pose.Root
	local max = settings().OwnRootShiftMax
	if w.Own and root and root.Turn.Position.Magnitude > max then
		local p = root.Turn.Position
		pose.Root = {
			Mode = root.Mode,
			Turn = CFrame.new(p.Unit * max) * root.Turn.Rotation,
		}
	end
	local out: { [Joint]: SkinMotion.JointPose } = {}
	for name, jp in pose do
		local joint = joints[name]
		if joint then
			out[joint] = { Mode = jp.Mode, Turn = DanceMoves.Local(joint, jp.Turn) }
		end
	end
	return out
end

-- Roblox's own pose of `joint` under ours this frame (base tracking, so Add never builds up).
-- `skipped`: the Animator's EvaluationThrottled (true = it didn't write a new pose this
-- frame), or nil when this Roblox can't say.
local function baseOf(w: Walker, joint: Joint, current: CFrame, skipped: boolean?): CFrame
	local last = w.LastBase[joint]
	if skipped == false then
		return current -- the Animator wrote a new pose this frame
	elseif skipped == true then
		return last or current -- it kept last frame's: that is still what we wrote on top of
	end
	-- no way to ask: if the joint still holds what we wrote, nobody wrote it since
	local written = w.Written[joint]
	if written and last and current == written then
		return last
	end
	return current
end

local function stepWalker(w: Walker, t: number, dt: number)
	local character = w.Character
	local humanoid = humanoidOf(character)
	local root = rootOf(character)
	if not humanoid or not root or not character.Parent then
		return
	end
	if dancing(character) or hider(w.Player) then
		w.Active = false -- the dance wins; a hider shows nothing
		stopPose(w)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	-- in the air (jumping, falling, climbing): fade out. Other players' Humanoid state isn't
	-- reliable on this screen, so only the vertical speed counts for them.
	local target = if math.abs(velocity.Y) > settings().AirSpeed then 0 else 1
	if w.Own then
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Climbing then
			target = 0
		end
	end
	local step = dt / math.max(settings().FadeSeconds, 1e-3)
	if w.Fade < target then
		w.Fade = math.min(target, w.Fade + step)
	elseif w.Fade > target then
		w.Fade = math.max(target, w.Fade - step)
	end
	if w.Fade <= 0 then
		if next(w.Modes) then
			stopPose(w)
		end
		return
	end
	-- The maths every second frame far away; the joints are written every frame.
	if not w.HalfRate or frame % 2 == 0 or next(w.Cached) == nil then
		local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local move = math.clamp(flat / math.max(humanoid.WalkSpeed, 1), 0, 1)
		w.Cached = poseOf(w, t, move)
	end
	local skipped = throttled(character)
	local f = w.Fade
	for joint, jp in w.Cached do
		if not joint.Parent then
			continue
		end
		local current = joint.Transform
		local base = baseOf(w, joint, current, skipped)
		local write = if jp.Mode == "Set"
			then base:Lerp(jp.Turn, f)
			else base * CFrame.identity:Lerp(jp.Turn, f)
		local motor: any = joint -- (Motor6D or AnimationConstraint: both have a Transform)
		motor.Transform = write
		w.Written[joint] = write
		w.LastBase[joint] = base
		w.Modes[joint] = jp.Mode
	end
end

-- Your own uploaded animations --------------------------------------------------------------------

local function stopOwn()
	for _, track in own.Tracks do
		track:Stop(0.2)
		track:Destroy()
	end
	own.Tracks = {}
	own.Text = nil
	own.Character = nil
	own.Checked = false
end

-- Humanoid states where Roblox's own jump / fall / climb / swim / sit animations show.
local AIR_STATES = {
	Jumping = true,
	Freefall = true,
	Climbing = true,
	Swimming = true,
	Seated = true,
	FallingDown = true,
	Ragdoll = true,
}

local function stepOwn()
	local cfg = settings()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local text = if character then character:GetAttribute("SkinMotionIds") else nil
	local humanoid = if character then humanoidOf(character) else nil
	local ok = character ~= nil
		and humanoid ~= nil
		and type(text) == "string"
		and cfg.AllowUploaded
		and humanoid.RigType == Enum.HumanoidRigType.R15 -- (uploaded animations are R15)
		and humanoid.Health > 0
		and not dancing(character)
		and not hider(player)
	if not ok or not character or not humanoid then
		if next(own.Tracks) then
			stopOwn()
		end
		return
	end
	if own.Character ~= character or own.Text ~= text then
		stopOwn()
		own.Character = character
		own.Text = text :: string
		own.LoadedAt = os.clock()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		local ids = SkinMotion.ParseIds(text) :: { [string]: string }
		for _, key in { "Walk", "Run", "Idle" } do
			local id = ids[key]
			if not id then
				continue
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local loaded, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if loaded and track then
				track.Priority = Enum.AnimationPriority.Movement
				track.Looped = true
				own.Tracks[key] = track
			end
		end
	end
	-- An animation that hasn't loaded by now (not owned by the game's owner?) is skipped.
	if not own.Checked and os.clock() - own.LoadedAt >= cfg.LoadCheckSeconds then
		own.Checked = true
		for key, track in own.Tracks do
			if track.Length <= 0 then
				local id = track.Animation and track.Animation.AnimationId or "?"
				if RunService:IsStudio() and not warned[id] then
					warned[id] = true
					warn(
						("[SkinWalk] animation %s didn't load: is it owned by the game's owner?"):format(
							string.match(id, "%d+") or id
						)
					)
				end
				track:Stop(0)
				track:Destroy()
				own.Tracks[key] = nil
			end
		end
	end
	-- Which one plays: run, walk or idle by your speed; none in the air (Roblox's show).
	local root = rootOf(character)
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local tracks = own.Tracks
	local choice: AnimationTrack? = nil
	if not (AIR_STATES[humanoid:GetState().Name] or humanoid.Sit) then
		if speed > cfg.RunSpeed then
			choice = tracks.Run or tracks.Walk
		elseif speed > cfg.WalkThreshold then
			choice = tracks.Walk
		else
			choice = tracks.Idle
		end
	end
	for _, track in tracks do
		if track == choice then
			if not track.IsPlaying then
				track:Play(0.2)
			end
			if track == tracks.Walk or track == tracks.Run then
				track:AdjustSpeed(speed / math.max(humanoid.WalkSpeed, 1))
			end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

-- The frame loop -----------------------------------------------------------------------------------

local function step(dt: number)
	local now = os.clock()
	if now >= nextPick then
		nextPick = now + settings().CheckSeconds
		pick()
	end
	frame += 1
	local t = Workspace:GetServerTimeNow()
	for _, w in walkers do
		if w.Active then
			stepWalker(w, t, dt)
		end
	end
	stepOwn()
	-- Nobody has a walk style and nothing is left to undo: stop until an attribute appears.
	local current = loop
	if current and not wanted and next(walkers) == nil and next(own.Tracks) == nil then
		current:Disconnect()
		loop = nil
	end
end

local function ensureLoop()
	nextPick = 0
	if loop == nil then
		-- After Roblox's animations have set the joints this frame (like the dances).
		loop = RunService.PreSimulation:Connect(step)
	end
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watchCharacter(character: Model?)
	if not character or watched[character] then
		return
	end
	watched[character] = true
	character:GetAttributeChangedSignal("SkinMotion"):Connect(ensureLoop)
	character:GetAttributeChangedSignal("SkinMotionIds"):Connect(ensureLoop)
	if
		character:GetAttribute("SkinMotion") ~= nil
		or character:GetAttribute("SkinMotionIds") ~= nil
	then
		ensureLoop()
	end
end

local watchedPlayers: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watchPlayer(player: Player)
	if watchedPlayers[player] then
		return
	end
	watchedPlayers[player] = true
	watchCharacter(player.Character)
	player:GetPropertyChangedSignal("Character"):Connect(function()
		watchCharacter(player.Character)
	end)
	-- Becoming a Hide & Seek hider stops everything at once.
	player:GetAttributeChangedSignal("HideSeekRole"):Connect(function()
		if hider(player) then
			local character = player.Character
			local w = character and walkers[character]
			if w then
				w.Active = false
				stopPose(w)
			end
			if player == Players.LocalPlayer then
				stopOwn()
			end
		end
		nextPick = 0
	end)
end

function SkinWalk.Mount(_gui: ScreenGui?)
	if mounted or not Config.Features.WalkStyles then
		return
	end
	mounted = true
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

function SkinWalk.Active(): number
	local n = 0
	for _, w in walkers do
		if w.Active and w.Fade > 0 then
			n += 1
		end
	end
	return n
end

return SkinWalk
