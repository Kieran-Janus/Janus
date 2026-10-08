--!strict
--[[
	Walk styles (a skin's Style.Motion): checking them and the pose of every code-made walk
	style. Pure and shared: the server checks a skin's Motion when it dresses you
	(src/shared/Cosmetics.luau sets the character attributes SkinMotion / SkinMotionIds) and
	every player's screen poses the characters (src/client/SkinWalk.luau). The numbers are in
	Config.SkinMotion (src/shared/Config/SkinMotion.luau).

	    Motion = "Zombie"                                   a code-made walk style
	    Motion = { Walk = "rbxassetid://123", Run = ..., Idle = ... }   your own animations
	    Motion = { Preset = "Ghost", Idle = "rbxassetid://789" }        both

	SkinMotion.Names                       the walk styles, in menu order
	SkinMotion.Info                        { Name, Label, Help } for each (plain English)
	SkinMotion.Has(name) -> boolean
	SkinMotion.Normalize(value) -> (Motion?, errors)   checks a Style.Motion; ids come back
	                                       as "rbxassetid://<digits>"
	SkinMotion.Pose(name, t, move) -> Pose   where each joint is at time t (seconds) while
	                                       moving at `move` (0 = standing, 1 = full walk speed)
	SkinMotion.IdsText(motion) -> string?  "Walk=123;Run=456;Idle=789" (the SkinMotionIds
	                                       character attribute), nil when it has no ids
	SkinMotion.ParseIds(text) -> { Walk?, Run?, Idle? }   back from that text

	A Pose maps DanceMoves joint names (Root, Waist, Neck, LeftShoulder, RightShoulder,
	LeftElbow, RightElbow, LeftHip, RightHip, LeftKnee, RightKnee) to { Mode, Turn }, with Turn
	in the body's own directions (X = right, Y = up, -Z = forward; Root may also shift, in
	studs). Mode "Set" replaces Roblox's walk animation for that joint (the zombie's arms);
	"Add" goes on top of it (a lean, a hop).
	Signs (as in DanceMoves): Shoulder rx(90) raises an arm forward, LeftShoulder rz(-90) /
	RightShoulder rz(90) raise them out to the side, Hip rx(30) kicks a leg forward, Knee
	rx(-60) bends it back, Waist rx(-10) leans forward, Neck rx(10) lifts the chin.
]]

local Config = require(script.Parent.Config)

local SkinMotion = {}

export type Motion = { Preset: string?, Walk: string?, Run: string?, Idle: string? }
export type JointPose = { Mode: "Set" | "Add", Turn: CFrame }
export type Pose = { [string]: JointPose }

SkinMotion.Info = {
	{
		Name = "Zombie",
		Label = "Zombie",
		Help = "Arms held out in front, head tilted, a slow shuffle.",
	},
	{ Name = "Mummy", Label = "Mummy", Help = "Stiff arms forward and short, stiff steps." },
	{ Name = "Ghost", Label = "Ghost", Help = "Floats above the ground and bobs, legs dangling." },
	{
		Name = "Robot",
		Label = "Robot",
		Help = "Straight arms and legs, head turning in little ticks.",
	},
	{ Name = "Bat", Label = "Bat", Help = "Arms out flapping like wings, with a little hover." },
	{ Name = "Sneaky", Label = "Sneaky", Help = "A crouched tiptoe with arms held close." },
	{ Name = "Bouncy", Label = "Bouncy", Help = "An extra hop in every step." },
	{ Name = "Proud", Label = "Proud", Help = "Chest out, chin up." },
}

SkinMotion.Names = {}
for _, info in SkinMotion.Info do
	table.insert(SkinMotion.Names, info.Name)
end

function SkinMotion.Has(name: unknown): boolean
	return type(name) == "string" and table.find(SkinMotion.Names, name) ~= nil
end

-- Checking ---------------------------------------------------------------------------------------

local ID_KEYS = { "Walk", "Run", "Idle" }

-- "rbxassetid://<digits>" for an animation id written as a number, "123" or
-- "rbxassetid://123"; nil when it isn't one.
local function canonicalId(value: any): string?
	local digits: string? = nil
	if type(value) == "number" then
		if value == value and value > 0 and value < 2 ^ 53 and value % 1 == 0 then
			digits = ("%d"):format(value)
		end
	elseif type(value) == "string" then
		digits = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
	end
	if not digits or #digits > 20 or not string.find(digits, "[1-9]") then
		return nil
	end
	return "rbxassetid://" .. digits
end

function SkinMotion.Normalize(value: any): (Motion?, { string })
	local errors: { string } = {}
	if value == nil then
		return nil, errors
	end
	local names = table.concat(SkinMotion.Names, ", ")
	if type(value) == "string" then
		if SkinMotion.Has(value) then
			return { Preset = value }, errors
		end
		table.insert(errors, ("Motion: there's no walk style called %s (%s)"):format(value, names))
		return nil, errors
	end
	if type(value) ~= "table" then
		table.insert(
			errors,
			'Motion should be a walk style like "Zombie" or a table of animation ids'
		)
		return nil, errors
	end
	for key in value do
		if key ~= "Preset" and not table.find(ID_KEYS, key) then
			table.insert(
				errors,
				("Motion: %s doesn't go here (Preset, Walk, Run or Idle)"):format(tostring(key))
			)
			return nil, errors
		end
	end
	local out: Motion = {}
	if value.Preset ~= nil then
		if not SkinMotion.Has(value.Preset) then
			table.insert(
				errors,
				("Motion: there's no walk style called %s (%s)"):format(
					tostring(value.Preset),
					names
				)
			)
			return nil, errors
		end
		out.Preset = value.Preset
	end
	for _, key in ID_KEYS do
		local raw = value[key]
		if raw ~= nil then
			local id = canonicalId(raw)
			if not id then
				table.insert(
					errors,
					('Motion: %s should be an animation id like "rbxassetid://123"'):format(key)
				)
				return nil, errors
			end
			(out :: any)[key] = id
		end
	end
	if out.Preset == nil and out.Walk == nil and out.Run == nil and out.Idle == nil then
		table.insert(errors, "Motion needs a Preset or an animation id")
		return nil, errors
	end
	return out, errors
end

function SkinMotion.IdsText(motion: Motion): string?
	local parts = {}
	for _, key in ID_KEYS do
		local id = (motion :: any)[key]
		local digits = if type(id) == "string"
			then string.match(id, "^rbxassetid://(%d+)$")
			else nil
		if digits then
			table.insert(parts, key .. "=" .. digits)
		end
	end
	return if #parts > 0 then table.concat(parts, ";") else nil
end

function SkinMotion.ParseIds(text: any): { Walk: string?, Run: string?, Idle: string? }
	local out: { [string]: string } = {}
	if type(text) ~= "string" or #text > 200 then
		return out :: any
	end
	for key, digits in string.gmatch(text, "(%a+)=(%d+)") do
		if table.find(ID_KEYS, key) and out[key] == nil then
			local id = canonicalId(digits)
			if id then
				out[key] = id
			end
		end
	end
	return out :: any
end

-- Poses ------------------------------------------------------------------------------------------

local TAU = math.pi * 2
local sin, abs = math.sin, math.abs

local function rx(deg: number): CFrame
	return CFrame.Angles(math.rad(deg), 0, 0)
end
local function ry(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end
local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, math.rad(deg))
end

local function set(turn: CFrame): JointPose
	return { Mode = "Set", Turn = turn }
end
local function add(turn: CFrame): JointPose
	return { Mode = "Add", Turn = turn }
end

-- The angle of a cycle of `seconds` at time t (kept within two turns).
local function cycle(t: number, seconds: number): number
	return (t / seconds) % 2 * TAU
end

local poses: { [string]: (p: any, t: number, move: number) -> Pose } = {}

function poses.Zombie(p: any, t: number, move: number): Pose
	local w = cycle(t, p.Seconds)
	local s = sin(w)
	return {
		LeftShoulder = set(rx(p.ArmsForward + sin(w + 1) * 4) * rz(-6)),
		RightShoulder = set(rx(p.ArmsForward + s * 4) * rz(6)),
		LeftElbow = set(rx(4)),
		RightElbow = set(rx(4)),
		Waist = add(rx(-p.Lean) * rz(s * 3 * (0.4 + 0.6 * move))),
		Neck = add(rz(p.HeadTilt + sin(w * 0.5) * 3) * rx(-6)),
		Root = add(ry(s * 5 * move)),
	}
end

function poses.Mummy(p: any, t: number, move: number): Pose
	local w = cycle(t, p.Seconds)
	local s = sin(w)
	local step = s * p.Step * move
	return {
		LeftShoulder = set(rx(p.ArmsForward) * rz(-3)),
		RightShoulder = set(rx(p.ArmsForward) * rz(3)),
		LeftElbow = set(CFrame.identity),
		RightElbow = set(CFrame.identity),
		LeftHip = set(rx(step)),
		RightHip = set(rx(-step)),
		LeftKnee = set(CFrame.identity),
		RightKnee = set(CFrame.identity),
		Waist = add(rx(-p.Lean) * rz(s * 3 * move)),
		Neck = add(rx(-4)),
		Root = add(rz(s * 4 * move)),
	}
end

function poses.Ghost(p: any, t: number, move: number): Pose
	local w = cycle(t, p.Seconds)
	local s = sin(w)
	local reach = 25 + 10 * move
	return {
		Root = add(CFrame.new(0, p.Height + p.Bob * s, 0) * rz(sin(w * 0.5) * 4)),
		Waist = add(rx(-6 - 6 * move)),
		LeftHip = set(rx(-p.Dangle * 0.6 + s * 4)),
		RightHip = set(rx(-p.Dangle + sin(w + 1.5) * 4)),
		LeftKnee = set(rx(-p.Dangle)),
		RightKnee = set(rx(-p.Dangle * 1.2)),
		LeftShoulder = set(rx(reach + s * 6) * rz(-12)),
		RightShoulder = set(rx(reach + sin(w + 2) * 6) * rz(12)),
		LeftElbow = set(rx(20)),
		RightElbow = set(rx(20)),
	}
end

function poses.Robot(p: any, t: number, move: number): Pose
	local s = sin(cycle(t, p.Seconds))
	-- the head looks round in little ticks: ahead, one way, ahead, the other way...
	local tick = math.floor((t / (p.Seconds * 2)) % 1 * p.Ticks)
	return {
		LeftShoulder = set(rx(-s * p.Swing * move)),
		RightShoulder = set(rx(s * p.Swing * move)),
		LeftElbow = set(CFrame.identity),
		RightElbow = set(CFrame.identity),
		LeftHip = set(rx(s * p.Step * move)),
		RightHip = set(rx(-s * p.Step * move)),
		LeftKnee = set(CFrame.identity),
		RightKnee = set(CFrame.identity),
		Neck = set(ry(p.HeadTurn * sin(TAU * tick / p.Ticks))),
		Root = add(CFrame.new(0, abs(s) * 0.05 * move, 0)),
	}
end

function poses.Bat(p: any, t: number, move: number): Pose
	-- slow flaps while standing, fast ones while moving (mixed, so it never jumps)
	local flap = sin(cycle(t, p.IdleSeconds)) * (1 - move) + sin(cycle(t, p.Seconds)) * move
	local out = p.ArmsOut + flap * p.Flap
	return {
		LeftShoulder = set(rz(-out) * rx(10)),
		RightShoulder = set(rz(out) * rx(10)),
		LeftElbow = set(rx(flap * 12)),
		RightElbow = set(rx(flap * 12)),
		Root = add(CFrame.new(0, p.Hover * (0.6 + 0.4 * flap), 0)),
		Waist = add(rx(-6)),
		LeftKnee = add(rx(-20)),
		RightKnee = add(rx(-20)),
	}
end

function poses.Sneaky(p: any, t: number, move: number): Pose
	local w = cycle(t, p.Seconds)
	local s = sin(w)
	return {
		Root = add(CFrame.new(0, -p.Crouch, 0)),
		Waist = add(rx(-p.Lean)),
		LeftHip = add(rx(p.Knees * 0.7)),
		RightHip = add(rx(p.Knees * 0.7)),
		LeftKnee = add(rx(-p.Knees)),
		RightKnee = add(rx(-p.Knees)),
		LeftShoulder = set(rx(35 + s * 6 * move) * rz(-10)),
		RightShoulder = set(rx(35 - s * 6 * move) * rz(10)),
		LeftElbow = set(rx(80)),
		RightElbow = set(rx(80)),
		Neck = add(ry(sin(w * 0.5) * 15) * rx(4)), -- looking round
	}
end

function poses.Bouncy(p: any, t: number, move: number): Pose
	local hop = abs(sin(cycle(t, p.Seconds))) * p.Hop * (0.15 + 0.85 * move)
	return {
		Root = add(CFrame.new(0, hop, 0)),
		LeftShoulder = add(rz(-10 - hop * 30)),
		RightShoulder = add(rz(10 + hop * 30)),
		LeftKnee = add(rx(-hop * 40)),
		RightKnee = add(rx(-hop * 40)),
	}
end

function poses.Proud(p: any, t: number, move: number): Pose
	local s = sin(cycle(t, p.Seconds))
	return {
		Waist = add(rx(p.ChestOut)),
		Neck = add(rx(p.ChinUp)),
		LeftShoulder = add(rz(-6) * rx(-4)),
		RightShoulder = add(rz(6) * rx(-4)),
		Root = add(rz(s * p.Sway * (0.3 + 0.7 * move))),
	}
end

function SkinMotion.Pose(name: string, t: number, move: number): Pose
	local make = poses[name]
	if not make then
		return {}
	end
	return make(Config.SkinMotion.Presets[name] or {}, t, math.clamp(move, 0, 1))
end

return SkinMotion
