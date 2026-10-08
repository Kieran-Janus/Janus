--!strict
--[[
	The Pumpkin King walks: long strides instead of gliding (this screen only; the server
	never moves his legs). Settings: Config.King.Stride (On = false: he glides).

	KingService tags the part-built King (Tags.KingStride). His body (src/server/Build/
	KingBody.luau) has joints: Waist (root -> Pelvis, which carries everything above the legs),
	LeftHip/RightHip (Pelvis -> thighs), LeftKnee/RightKnee (thighs -> shins) and
	LeftShoulder/RightShoulder (Pelvis -> arms). Each frame,
	for every tagged King within Range of the camera, those joints' Transform is set from how
	fast he is moving: legs swing forward and back, the leg coming forward bends its knee, the
	body dips when his legs are apart and rises over the planted foot (so the feet stay on the
	floor), rolls a little side to side, and leans forward while chasing (attribute Mode). The
	strides are as long as his legs allow (attribute LegLength), so faster = quicker steps,
	never sliding feet. His arms swing against his legs, hanging low while he wanders and
	stretched out with twitching claws while he chases. Standing still eases back to standing
	straight.
	Nothing runs per frame while no King is on the map.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local KingStride = {}

type Walker = {
	Model: Model,
	Phase: number,
	Amount: number, -- 0 standing .. 1 full strides (eased)
	Lean: number, -- eased chase lean, 0..1
}

local walkers: { [Model]: Walker } = {}
local connection: RBXScriptConnection? = nil

local function motor(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Motor6D") then found else nil
end

local function setTransform(model: Model, name: string, transform: CFrame)
	local m = motor(model, name)
	if m then
		m.Transform = transform
	end
end

-- The stride math, kept apart so the tests can check it: for a phase (radians) and an
-- amount (0..1), the hip and knee angles of each leg (radians, forward = +) and how far
-- the body drops (studs) and rolls (radians).
export type Pose = {
	LeftHip: number,
	RightHip: number,
	LeftKnee: number,
	RightKnee: number,
	Drop: number,
	Roll: number,
	LeftArm: number, -- shoulder swing (radians, forward = +), opposite the leg on its side
	RightArm: number,
}

function KingStride.Pose(phase: number, amount: number, legLength: number): Pose
	local cfg = Config.King.Stride
	local swing = math.rad(cfg.Swing) * amount
	local left = swing * math.sin(phase)
	-- The leg swinging forward (its hip angle growing) lifts and bends its knee.
	local knee = math.rad(cfg.KneeBend) * amount
	local leftKnee = knee * math.max(0, math.cos(phase))
	local rightKnee = knee * math.max(0, -math.cos(phase))
	-- Legs apart = hips lower by exactly what keeps the planted foot on the floor.
	local drop = legLength * (1 - math.cos(left))
	return {
		LeftHip = left,
		RightHip = -left,
		LeftKnee = leftKnee,
		RightKnee = rightKnee,
		Drop = drop,
		Roll = math.rad(cfg.Sway) * amount * math.sin(phase),
		LeftArm = -math.rad(cfg.ArmSwing) * amount * math.sin(phase),
		RightArm = math.rad(cfg.ArmSwing) * amount * math.sin(phase),
	}
end

-- How far one full stride cycle (left step + right step) carries him, in studs.
function KingStride.CycleLength(legLength: number): number
	return 4 * legLength * math.sin(math.rad(Config.King.Stride.Swing))
end

local function step(dt: number)
	local cfg = Config.King.Stride
	local camera = workspace.CurrentCamera
	for model, walker in walkers do
		local root = model.PrimaryPart
		if not root or not model.Parent then
			continue
		end
		if camera and (camera.CFrame.Position - root.Position).Magnitude > cfg.Range then
			continue
		end
		local legLength = model:GetAttribute("LegLength")
		if type(legLength) ~= "number" or legLength <= 0 then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local wanted = math.clamp(speed / 3, 0, 1)
		walker.Amount += (wanted - walker.Amount) * math.min(1, dt * 6)
		local chasing = model:GetAttribute("Mode") == "Chase"
		walker.Lean += ((if chasing then 1 else 0) - walker.Lean) * math.min(1, dt * 4)
		walker.Phase = (walker.Phase + dt * speed / KingStride.CycleLength(legLength) * 2 * math.pi)
			% (2 * math.pi)

		local pose = KingStride.Pose(walker.Phase, walker.Amount, legLength)
		local lean = math.rad(cfg.ChaseLean) * walker.Lean
		-- Rotations about X: positive swings a leg forward (towards -Z, where he faces).
		setTransform(
			model,
			"Waist",
			CFrame.new(0, -pose.Drop, 0) * CFrame.Angles(-lean, 0, pose.Roll)
		)
		setTransform(model, "LeftHip", CFrame.Angles(pose.LeftHip + lean, 0, 0))
		setTransform(model, "RightHip", CFrame.Angles(pose.RightHip + lean, 0, 0))
		setTransform(model, "LeftKnee", CFrame.Angles(-pose.LeftKnee, 0, 0))
		setTransform(model, "RightKnee", CFrame.Angles(-pose.RightKnee, 0, 0))
		-- Arms: lowered and swinging while he wanders, stretched out with twitching claws
		-- while he chases you.
		local lowered = -math.rad(cfg.ArmDrop) * (1 - walker.Lean)
		local twitch = math.rad(cfg.ArmTwitch) * walker.Lean * math.sin(os.clock() * 13)
		setTransform(model, "LeftShoulder", CFrame.Angles(lowered + pose.LeftArm + twitch, 0, 0))
		setTransform(model, "RightShoulder", CFrame.Angles(lowered + pose.RightArm - twitch, 0, 0))
	end
end

local function refresh()
	if next(walkers) and not connection then
		-- PreSimulation: joint Transforms set here are drawn this frame.
		connection = RunService.PreSimulation:Connect(step)
	elseif not next(walkers) and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function add(instance: Instance)
	if instance:IsA("Model") and not walkers[instance] then
		walkers[instance] = { Model = instance, Phase = 0, Amount = 0, Lean = 0 }
		refresh()
	end
end

local function remove(instance: Instance)
	if instance:IsA("Model") and walkers[instance] then
		walkers[instance] = nil
		refresh()
	end
end

function KingStride.Mount(_gui: ScreenGui?)
	if not Config.King.Stride.On then
		return
	end
	CollectionService:GetInstanceAddedSignal(Tags.KingStride):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.KingStride):Connect(remove)
	for _, instance in CollectionService:GetTagged(Tags.KingStride) do
		add(instance)
	end
end

return KingStride
