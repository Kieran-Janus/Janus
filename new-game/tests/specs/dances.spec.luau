-- Photo Spot dances (Config.Dances): the dance list, DanceMoves poses on R15 and R6 rigs,
-- DanceService's checks (at the Photo Spot, real dances only, cooldown, stops when you walk
-- off) and the client animating every dancing character.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local base = Runtime.new()
local Config = base:require("ReplicatedStorage.Shared.Config")
local DanceMoves = base:require("ReplicatedStorage.Shared.DanceMoves")
local cfg = Config.Dances

local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
}

-- A bare rig: the parts and Motor6Ds DanceMoves looks for (C0 turned like Roblox's R6).
local function rig(rt: any, kind: string): any
	local CF, V3 = rt.env.CFrame, rt.env.Vector3
	local m = rt:create("Model", { Name = kind .. "Rig" }, rt.workspace)
	local humanoid = rt:create("Humanoid", {}, m)
	humanoid.RigType = if kind == "R6"
		then rt.env.Enum.HumanoidRigType.R6
		else rt.env.Enum.HumanoidRigType.R15
	local function motor(partName: string, name: string, c0: any)
		local part = m:FindFirstChild(partName)
			or rt:create("Part", { Name = partName, Size = V3.one }, m)
		if kind == "R15Constraints" then
			-- Roblox's newer avatar joints: an AnimationConstraint between two attachments.
			local a0 =
				rt:create("Attachment", { Name = name .. "RigAttachment", CFrame = c0 }, part)
			local joint = rt:create("AnimationConstraint", { Name = name }, part)
			joint.Attachment0 = a0
		else
			rt:create("Motor6D", { Name = name, C0 = c0 }, part)
		end
	end
	if kind == "R6" then
		motor("HumanoidRootPart", "RootJoint", CF.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
		motor("Torso", "Neck", CF.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
		motor("Torso", "Left Shoulder", CF.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
		motor("Torso", "Right Shoulder", CF.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
		motor("Torso", "Left Hip", CF.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
		motor("Torso", "Right Hip", CF.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	else
		local where = {
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
		for _, w in where do
			motor(w[1], w[2], CF.new(0, 0.5, 0))
		end
	end
	return m
end

local function finite(cf: any): boolean
	for _, n in { cf:GetComponents() } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

describe("Config.Dances and DanceMoves", function()
	it("lists 10 spooky dances, each made in code, with an optional AnimationId", function()
		expect(#cfg.List).toBe(10)
		local seen = {}
		for _, dance in cfg.List do
			expect(seen[dance.Id]).toBeNil()
			seen[dance.Id] = true
			expect(#dance.Label).toBeGreaterThan(0)
			expect(dance.AnimationId).toBeA("string")
			expect(DanceMoves.Has(dance.Id)).toBe(true)
		end
		expect(cfg.MaxDrift).toBeGreaterThan(0)
		expect(cfg.Columns).toBeGreaterThanOrEqual(1)
	end)

	it("gives every dance sensible poses that move", function()
		for _, dance in cfg.List do
			local a = DanceMoves.Pose(dance.Id, 0.3)
			local b = DanceMoves.Pose(dance.Id, 0.9)
			local moved = false
			for name, cf in a do
				expect(table.find(JOINTS, name)).toBeTruthy()
				expect(finite(cf)).toBe(true)
				expect(cf.Position.Magnitude).toBeLessThan(2) -- never flies off
				local other = b[name]
				if
					other
					and (
						cf.Position ~= other.Position
						or cf.LookVector ~= other.LookVector
						or cf.UpVector ~= other.UpVector
					)
				then
					moved = true
				end
			end
			expect(moved).toBe(true)
		end
		expect(DanceMoves.Pose("NoSuchDance", 1).Root).toBeTruthy() -- a happy bounce
	end)

	it(
		"moves R15 and R6 joints, in the body's directions whatever way a joint is turned",
		function()
			local rt = Runtime.new()
			local Moves = rt:require("ReplicatedStorage.Shared.DanceMoves")
			local CF = rt.env.CFrame
			local r15 = Moves.Joints(rig(rt, "R15"))
			local r6 = Moves.Joints(rig(rt, "R6"))
			local r15c = Moves.Joints(rig(rt, "R15Constraints"))
			expect(r15c.RightShoulder.ClassName).toBe("AnimationConstraint")
			local count15, count6 = 0, 0
			for _ in r15 do
				count15 += 1
			end
			for _ in r6 do
				count6 += 1
			end
			expect(count15).toBe(11)
			expect(count6).toBe(6)
			expect(r6.Waist).toBeNil()
			-- Raise the right arm out to the side: the arm's joint frame (C0 * Transform) must be
			-- the pose applied in the torso's directions, on every rig.
			local pose = { RightShoulder = CF.Angles(0, 0, math.rad(90)) }
			for _, joints in { r15, r6, r15c } do
				Moves.Apply(joints, pose)
				local motor = joints.RightShoulder
				local seat = if motor:IsA("Motor6D") then motor.C0 else motor.Attachment0.CFrame
				local got = seat.Rotation * motor.Transform
				local want = pose.RightShoulder * seat.Rotation
				expect((got.LookVector - want.LookVector).Magnitude).toBeLessThan(1e-4)
				expect((got.UpVector - want.UpVector).Magnitude).toBeLessThan(1e-4)
				Moves.Clear(joints)
				expect(motor.Transform.Position.Magnitude).toBe(0)
			end
		end
	)
end)

-- A server with the hub (the Photo Spot) and dances.
local function server()
	local rt = Runtime.new({ studio = true })
	for _, name in { "HubService", "DataService", "DanceService" } do
		rt:require("ServerScriptService.Server.Services." .. name).Start()
	end
	return rt
end

local function photoSpot(rt: any): any
	return rt.game:GetService("CollectionService"):GetTagged("PhotoSpot")[1]
end

local function standAt(rt: any, player: any, position: any)
	player.Character:PivotTo(rt.env.CFrame.new(position))
end

describe("DanceService", function()
	it("dances only at the Photo Spot, only real dances, and stops when you walk off", function()
		local rt = server()
		local Dance = rt:require("ServerScriptService.Server.Services.DanceService")
		local spot = photoSpot(rt)
		expect(spot).toBeTruthy()
		local player = rt:addPlayer({ Name = "Dancer" })
		rt:advance(1)
		local V3 = rt.env.Vector3
		local id = cfg.List[1].Id

		standAt(rt, player, spot.Position + V3.new(0, 0, Config.Hub.PhotoSpot.CloseDistance + 10))
		expect(select(2, Dance.Set(player, id))).toBe("TooFar")
		expect(player.Character:GetAttribute("Dance")).toBeNil()

		standAt(rt, player, spot.Position + V3.new(2, 0, 2))
		expect(select(2, Dance.Set(player, "Floss!!"))).toBe("BadId")
		expect(select(2, Dance.Set(player, 42))).toBe("BadId")
		-- Through the remote, like a real client.
		rt:fireServer(rt:find("ReplicatedStorage.Remotes.Dance"), player, id)
		rt:flush()
		expect(player.Character:GetAttribute("Dance")).toBe(id)
		expect(select(2, Dance.Set(player, cfg.List[2].Id))).toBe("TooSoon")
		rt:advance(cfg.Cooldown + 0.1)
		expect((Dance.Set(player, cfg.List[2].Id))).toBe(true)
		expect(player.Character:GetAttribute("Dance")).toBe(cfg.List[2].Id)

		-- Still there a moment later; walking away stops it.
		rt:advance(1)
		expect(player.Character:GetAttribute("Dance")).toBe(cfg.List[2].Id)
		standAt(rt, player, spot.Position + V3.new(2 + cfg.MaxDrift + 1, 0, 2))
		rt:advance(0.5)
		expect(player.Character:GetAttribute("Dance")).toBeNil()

		-- "" stops it too.
		standAt(rt, player, spot.Position + V3.new(2, 0, 2))
		rt:advance(cfg.Cooldown + 0.1)
		expect((Dance.Set(player, id))).toBe(true)
		expect((Dance.Set(player, ""))).toBe(true)
		expect(player.Character:GetAttribute("Dance")).toBeNil()
	end)

	it("refuses every dance while switched off", function()
		local rt = server()
		local C = rt:require("ReplicatedStorage.Shared.Config")
		local Dance = rt:require("ServerScriptService.Server.Services.DanceService")
		local player = rt:addPlayer({ Name = "Dancer" })
		rt:advance(1)
		standAt(rt, player, photoSpot(rt).Position)
		C.Features.Dances = false
		local ok, why = Dance.Set(player, cfg.List[1].Id)
		C.Features.Dances = true
		expect(ok).toBe(false)
		expect(why).toBe("Off")
	end)
end)

describe("Dances (client)", function()
	it("animates every character with a Dance attribute and lets go when it ends", function()
		local srv = server()
		local client = Runtime.new({ client = true })
		client:replicateFrom(srv)
		local Dances = client:require("StarterPlayer.StarterPlayerScripts.Client.Dances")
		local player = client.game:GetService("Players").LocalPlayer
		local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
		Dances.Mount(gui)
		local other = client:addPlayer({ Name = "Other" })
		local otherRig = rig(client, "R6")
		otherRig.Parent = client.workspace
		other.Character = otherRig
		otherRig:SetAttribute("Dance", cfg.List[1].Id)
		client:advance(0.5)
		local neck = otherRig.Torso.Neck
		local moved = neck.Transform
		expect(finite(moved)).toBe(true)
		expect(moved == client.env.CFrame.identity).toBe(false)
		otherRig:SetAttribute("Dance", nil)
		client:advance(0.1)
		expect(neck.Transform == client.env.CFrame.identity).toBe(true)
	end)
end)
