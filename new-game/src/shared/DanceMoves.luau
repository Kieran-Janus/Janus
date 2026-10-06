--!strict
--[[
	The Photo Spot's code-made dances (Config.Dances), shared by the client and the tests.

	DanceMoves.Pose(id, t) -> Pose
	        where each body joint is at time t (seconds) in dance `id`. A Pose maps a joint name
	        (Root, Waist, Neck, LeftShoulder, RightShoulder, LeftElbow, RightElbow, LeftHip,
	        RightHip, LeftKnee, RightKnee) to a turn (and for Root a shift, in studs) measured
	        in the body's own directions: X = right, Y = up, -Z = forward. An unknown id gives
	        a happy bounce.
	DanceMoves.Joints(character) -> { [string]: Joint }   (Motor6D or AnimationConstraint)
	        the character's joints under those names, for R15 and R6 (R6 has no Waist, elbows
	        or knees: its Waist turn goes into Root, the others are skipped)
	DanceMoves.Apply(joints, pose)
	        sets each joint's Transform so the pose shows (works whatever way the rig's joints
	        are turned)
	DanceMoves.Clear(joints)
	        puts every joint back to rest (the normal animations take over again)

	Signs, for writing a new dance: LeftShoulder rz(-90) raises the left arm out to the side,
	RightShoulder rz(90) the right one; Shoulder rx(90) raises an arm forward; Hip rx(30)
	kicks a leg forward; Knee rx(-60) bends it back; Elbow rx(60) bends the forearm forward.
]]

local DanceMoves = {}

export type Pose = { [string]: CFrame }

local R15: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	RightHip = { "RightUpperLeg", "RightHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
}

local R6: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftHip = { "Torso", "Left Hip" },
	RightHip = { "Torso", "Right Hip" },
}

local function rx(deg: number): CFrame
	return CFrame.Angles(math.rad(deg), 0, 0)
end
local function ry(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end
local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, math.rad(deg))
end
local sin, abs = math.sin, math.abs

-- Arms: `out` degrees out to the side, `forward` degrees forward (the same for both sides).
local function arms(pose: Pose, out: number, forward: number)
	pose.LeftShoulder = rx(forward) * rz(-out)
	pose.RightShoulder = rx(forward) * rz(out)
end

local moves: { [string]: (t: number) -> Pose } = {}

function moves.ZombieShuffle(t: number): Pose
	local step = sin(t * 4)
	local pose: Pose = {
		Root = CFrame.new(step * 0.25, -0.15 + abs(step) * 0.1, 0) * ry(step * 12),
		Waist = rx(12) * rz(step * 6),
		Neck = rz(20 + sin(t * 2) * 8) * rx(-10),
		LeftHip = rx(step * 18),
		RightHip = rx(-step * 18),
		LeftKnee = rx(-math.max(step, 0) * 30),
		RightKnee = rx(-math.max(-step, 0) * 30),
	}
	arms(pose, 8, 85 + sin(t * 4 + 1) * 6)
	pose.LeftElbow = rx(-5)
	pose.RightElbow = rx(-5)
	return pose
end

function moves.SkeletonRattle(t: number): Pose
	local shake = function(phase: number, size: number): number
		return sin(t * 28 + phase) * size
	end
	local pose: Pose = {
		Root = CFrame.new(0, abs(sin(t * 6)) * 0.3, 0) * rz(shake(0, 4)),
		Waist = ry(shake(1, 10)),
		Neck = rz(shake(2, 18)) * rx(shake(3, 8)),
		LeftHip = rz(-12 + shake(4, 10)),
		RightHip = rz(12 + shake(5, 10)),
		LeftKnee = rx(shake(6, 15) - 15),
		RightKnee = rx(shake(7, 15) - 15),
		LeftElbow = rx(40 + shake(8, 25)),
		RightElbow = rx(40 + shake(9, 25)),
	}
	pose.LeftShoulder = rz(-55 + shake(10, 20))
	pose.RightShoulder = rz(55 + shake(11, 20))
	return pose
end

function moves.GhostFloat(t: number): Pose
	local wave = sin(t * 2)
	local pose: Pose = {
		Root = CFrame.new(0, 1 + wave * 0.5, 0) * ry(sin(t * 0.8) * 25) * rz(wave * 6),
		Waist = rx(-8),
		Neck = rz(sin(t * 1.3) * 12),
		LeftHip = rx(-12),
		RightHip = rx(-18),
		LeftKnee = rx(-20),
		RightKnee = rx(-25),
	}
	pose.LeftShoulder = rx(70 + sin(t * 3) * 15) * rz(-25)
	pose.RightShoulder = rx(70 + sin(t * 3 + 2) * 15) * rz(25)
	pose.LeftElbow = rx(sin(t * 3 + 1) * 25)
	pose.RightElbow = rx(sin(t * 3 + 3) * 25)
	return pose
end

function moves.PumpkinHeadSpin(t: number): Pose
	local bounce = abs(sin(t * 4))
	local pose: Pose = {
		Root = CFrame.new(0, bounce * 0.2, 0),
		Neck = ry(t * 360 % 360),
		LeftHip = rz(-6),
		RightHip = rz(6),
		LeftKnee = rx(-bounce * 15),
		RightKnee = rx(-bounce * 15),
	}
	-- Hands on hips.
	pose.LeftShoulder = rz(-45) * rx(-10)
	pose.RightShoulder = rz(45) * rx(-10)
	pose.LeftElbow = rx(70)
	pose.RightElbow = rx(70)
	return pose
end

function moves.MonsterMash(t: number): Pose
	local beat = sin(t * 5)
	local pose: Pose = {
		Root = CFrame.new(sin(t * 2.5) * 0.6, -0.3 + abs(beat) * 0.2, 0) * ry(sin(t * 2.5) * 15),
		Waist = rz(-beat * 8),
		Neck = rz(beat * 10),
		LeftHip = rx(25),
		RightHip = rx(25),
		LeftKnee = rx(-45),
		RightKnee = rx(-45),
	}
	pose.LeftShoulder = rx(70 + beat * 35) * rz(-15)
	pose.RightShoulder = rx(70 - beat * 35) * rz(15)
	pose.LeftElbow = rx(30)
	pose.RightElbow = rx(30)
	return pose
end

function moves.BatFlap(t: number): Pose
	local flap = sin(t * 10)
	local pose: Pose = {
		Root = CFrame.new(0, 0.2 + abs(sin(t * 5)) * 0.6, 0) * rx(-flap * 4),
		Waist = rx(-6),
		Neck = rx(-15 + flap * 5),
		LeftHip = rx(20),
		RightHip = rx(20),
		LeftKnee = rx(-60),
		RightKnee = rx(-60),
	}
	arms(pose, 70 + flap * 40, 10)
	pose.LeftElbow = rx(flap * 20)
	pose.RightElbow = rx(flap * 20)
	return pose
end

function moves.ScaredyCatShiver(t: number): Pose
	local shiver = sin(t * 40)
	local pose: Pose = {
		Root = CFrame.new(shiver * 0.06, -0.6, 0) * rz(shiver * 2),
		Waist = rx(25),
		Neck = rx(20) * ry(sin(t * 3) * 25),
		LeftHip = rx(55),
		RightHip = rx(55),
		LeftKnee = rx(-90),
		RightKnee = rx(-90),
	}
	-- Hands over the eyes.
	pose.LeftShoulder = rx(150 + shiver * 4) * rz(20)
	pose.RightShoulder = rx(150 - shiver * 4) * rz(-20)
	pose.LeftElbow = rx(60)
	pose.RightElbow = rx(60)
	return pose
end

function moves.WitchyCackle(t: number): Pose
	local laugh = sin(t * 12)
	local pose: Pose = {
		Root = CFrame.new(0, abs(laugh) * 0.15, 0) * ry(sin(t * 1.5) * 20),
		Waist = rx(-15 - laugh * 5),
		Neck = rx(-25 - laugh * 8),
		LeftHip = rz(-8),
		RightHip = rz(8),
	}
	-- One hand on the belly, the other raised like a claw.
	pose.LeftShoulder = rx(35) * rz(-10)
	pose.LeftElbow = rx(80)
	pose.RightShoulder = rz(140 + laugh * 10)
	pose.RightElbow = rx(45 + laugh * 15)
	return pose
end

function moves.MummyWobble(t: number): Pose
	local wobble = sin(t * 2)
	local pose: Pose = {
		Root = CFrame.new(wobble * 0.3, 0, 0) * rz(wobble * 12),
		Waist = rz(-wobble * 5),
		Neck = rz(-wobble * 10) * rx(-5),
		LeftHip = rx(sin(t * 4) * 10) * rz(-wobble * 8),
		RightHip = rx(-sin(t * 4) * 10) * rz(-wobble * 8),
	}
	arms(pose, 0, 90 + sin(t * 4) * 4)
	return pose
end

function moves.SpookyFloss(t: number): Pose
	local swing = sin(t * 7)
	local front = if sin(t * 14) > 0 then 1 else -1 -- arms pass in front, then behind
	local pose: Pose = {
		Root = CFrame.new(-swing * 0.35, 0, 0) * rz(-swing * 6),
		Waist = rz(swing * 8),
		Neck = rz(-swing * 8),
		LeftHip = rz(swing * 6),
		RightHip = rz(swing * 6),
	}
	pose.LeftShoulder = rx(front * 20) * rz(swing * 35)
	pose.RightShoulder = rx(-front * 20) * rz(swing * 35)
	return pose
end

local function bounce(t: number): Pose
	local up = abs(sin(t * 5))
	local pose: Pose = {
		Root = CFrame.new(0, up * 0.4, 0),
		LeftKnee = rx(-up * 20),
		RightKnee = rx(-up * 20),
	}
	arms(pose, 150, 0)
	return pose
end

function DanceMoves.Has(id: string): boolean
	return moves[id] ~= nil
end

function DanceMoves.Pose(id: string, t: number): Pose
	local move = moves[id] or bounce
	return move(t)
end

-- A joint is a Motor6D or (Roblox's newer avatar joints) an AnimationConstraint: both have a
-- Transform. Where the joint sits on its first part: C0, or Attachment0 for a constraint.
export type Joint = Motor6D | AnimationConstraint

local function seat(joint: Joint): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	local a0 = (joint :: AnimationConstraint).Attachment0
	return if a0 then a0.CFrame else CFrame.identity
end

function DanceMoves.Joints(character: Model): { [string]: Joint }
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local map = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then R6 else R15
	local joints: { [string]: Joint } = {}
	for name, where in map do
		local part = character:FindFirstChild(where[1])
		local joint = part and part:FindFirstChild(where[2])
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[name] = joint :: any
		end
	end
	if map == R6 then
		joints.Waist = nil
	end
	return joints
end

function DanceMoves.Apply(joints: { [string]: Joint }, pose: Pose)
	local waist = pose.Waist
	for name, joint in joints do
		local turn = pose[name] or CFrame.identity
		if name == "Root" and waist and not joints.Waist then
			turn *= waist -- R6: the waist bends with the whole body
		end
		-- The pose is in the body's directions; the joint may be turned (R6 shoulders are), so
		-- turn the pose into the joint's own directions.
		local c0 = seat(joint).Rotation
		joint.Transform = c0:Inverse() * turn * c0
	end
end

function DanceMoves.Clear(joints: { [string]: Joint })
	for _, joint in joints do
		joint.Transform = CFrame.identity
	end
end

return DanceMoves
