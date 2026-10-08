-- The Pumpkin King's part-built body (src/server/Build/KingBody.luau): it stands on the floor
-- (no floating), every piece is joined to the hidden root and walks through nothing, it has
-- a Head (for the name tag) and one light, and its look comes from Config.King.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local function world(): any
	local rt = Runtime.new()
	return {
		rt = rt,
		Vector3 = rt.env.Vector3,
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		KingBody = rt:require("ServerScriptService.Server.Build.KingBody"),
	}
end

local function parts(model: any): { any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

describe("The Pumpkin King's body (Build/KingBody)", function()
	it("stands on the floor, about 11 studs tall, facing forward", function()
		local w = world()
		local cfg = w.Config.King
		local position = w.Vector3.new(10, 50, -20)
		local model, humanoid, root = w.KingBody.Build(position)
		expect(model.Name).toBe("PumpkinKing")
		expect(model.PrimaryPart).toBe(root)
		expect(root.Name).toBe("HumanoidRootPart")
		expect(humanoid.HipHeight).toBe(cfg.HipHeight)
		expect(humanoid.DisplayName).toBe(cfg.Name)

		-- The root's centre is HipHeight + 1 above the floor.
		local floor = position.Y - (cfg.HipHeight + 1)
		local highest = -math.huge
		for _, p in parts(model) do
			if p ~= root then
				highest = math.max(highest, p.Position.Y)
			end
		end
		-- Both boots stand on the floor: he doesn't float.
		local boots = 0
		for _, p in parts(model) do
			if p.Name == "Boot" then
				boots += 1
				expect(p.Position.Y - p.Size.Y / 2 - floor).toBeNear(0, 0.05)
			end
		end
		expect(boots).toBe(2)
		expect(highest - floor > 9).toBe(true)
		expect(highest - floor < 13).toBe(true)

		-- The face is on the front (-Z, where he looks).
		local head = model:FindFirstChild("Head")
		expect(head).toBeTruthy()
		local eyes = 0
		for _, p in parts(model) do
			if p.Name == "Eye" then
				eyes += 1
				expect(p.Position.Z < head.Position.Z - 1).toBe(true)
			end
		end
		expect(eyes).toBe(2)
	end)

	it(
		"joins every piece to the root (welds, and joints for the walk), with no collisions",
		function()
			local w = world()
			local model, _, root = w.KingBody.Build(w.Vector3.new(0, 4, 0))
			-- What each part hangs from: a WeldConstraint's Part0 or a Motor6D's Part0.
			local parent: { [any]: any } = {}
			local joints: { [string]: boolean } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("WeldConstraint") then
					parent[d.Part1] = d.Part0
				elseif d:IsA("Motor6D") then
					parent[d.Part1] = d.Part0
					joints[d.Name] = true
				end
			end
			for _, name in
				{
					"Waist",
					"LeftHip",
					"RightHip",
					"LeftKnee",
					"RightKnee",
					"LeftShoulder",
					"RightShoulder",
				}
			do
				expect(joints[name]).toBe(true)
			end
			expect(model:GetAttribute("LegLength")).toBeA("number")
			local count = 0
			for _, p in parts(model) do
				if p ~= root then
					count += 1
					expect(p.Anchored).toBe(false)
					expect(p.CanCollide).toBe(false)
					expect(p.Massless).toBe(true)
					local at, hops = p, 0
					while at ~= root and hops < 5 do
						at = parent[at]
						hops += 1
					end
					if at ~= root then
						error(p.Name .. " isn't joined to the root")
					end
				end
			end
			expect(count > 30).toBe(true)
			expect(count < 120).toBe(true)
		end
	)

	it("glows from inside the head, with embers from Config.King", function()
		local w = world()
		local cfg = w.Config.King
		local model = w.KingBody.Build(w.Vector3.new(0, 4, 0))
		local lights = 0
		for _, d in model:GetDescendants() do
			if d:IsA("Light") then
				lights += 1
				expect(d.Range).toBe(cfg.FaceGlow.Range)
			end
		end
		expect(lights).toBe(1)
		local embers = model:FindFirstChild("Embers", true)
		if cfg.Embers > 0 then
			expect(embers.Rate).toBe(cfg.Embers)
		else
			expect(embers).toBe(nil)
		end
		expect(model:FindFirstChild("Head").Color).toBe(cfg.HeadColor)
		expect(model:FindFirstChild("Cape").Color).toBe(cfg.CapeColor)
	end)
end)

describe("The Pumpkin King's walk and pace", function()
	it("strides without sliding: the planted foot stays on the floor", function()
		local w = world()
		local KingStride = w.rt:require("StarterPlayer.StarterPlayerScripts.Client.KingStride")
		local legLength = 3.5
		for i = 0, 15 do
			local phase = i / 16 * 2 * math.pi
			local pose = KingStride.Pose(phase, 1, legLength)
			-- The straight (unbent) leg's foot is legLength below the dropped hip.
			for _, side in { "Left", "Right" } do
				if pose[side .. "Knee"] < 1e-6 then
					local footHeight = legLength
						- pose.Drop
						- legLength * math.cos(pose[side .. "Hip"])
					expect(footHeight).toBeNear(0, 1e-6)
				end
			end
			expect(pose.LeftHip).toBeNear(-pose.RightHip, 1e-9)
		end
		-- Standing still: no stride at all.
		local still = KingStride.Pose(1.3, 0, legLength)
		expect(still.LeftHip).toBe(0)
		expect(still.Drop).toBe(0)
		expect(KingStride.CycleLength(legLength) > 6).toBe(true)
	end)

	it("is one King on every difficulty, a little faster every 30 seconds, up to a cap", function()
		local w = world()
		local cfg = w.Config.King
		for _, level in cfg.Difficulty do
			expect(level.Count).toBe(1)
		end
		local KingService = w.rt:require("ServerScriptService.Server.Services.KingService")
		expect(KingService.ExtraSpeed(0)).toBe(0)
		expect(KingService.ExtraSpeed(cfg.SpeedUp.Every - 0.1)).toBe(0)
		expect(KingService.ExtraSpeed(cfg.SpeedUp.Every)).toBe(cfg.SpeedUp.Add)
		expect(KingService.ExtraSpeed(cfg.SpeedUp.Every * 2.5)).toBe(cfg.SpeedUp.Add * 2)
		expect(KingService.ExtraSpeed(100000)).toBe(cfg.SpeedUp.Max)
	end)

	it("plays King Hunt for 3 minutes on Easy", function()
		local w = world()
		expect(w.Config.Difficulty.Levels.Easy.RoundSeconds).toBe(180)
	end)
end)

describe("The King statue in the lobby", function()
	it("is the King himself on a pedestal, still on the server, swaying on screens", function()
		local w = world()
		local HubBuilder = w.rt:require("ServerScriptService.Server.Hub.HubBuilder")
		local hub = HubBuilder.Build()
		local statue = hub:FindFirstChild("KingStatue", true)
		expect(statue).toBeTruthy()
		local figure = statue:FindFirstChild("KingFigure")
		expect(figure).toBeInstanceOf("Model")
		local CS = w.rt.game:GetService("CollectionService")
		expect(CS:HasTag(figure, "HubSway")).toBe(true)
		local s = w.Config.Hub.Polish.KingStatue
		expect(figure:GetAttribute("SwayAngle")).toBe(s.SwayAngle)
		expect(figure:FindFirstChildOfClass("Humanoid")).toBeNil()
		local top = -math.huge
		for _, d in figure:GetDescendants() do
			expect(d:IsA("JointInstance") or d:IsA("WeldConstraint")).toBe(false)
			if d:IsA("BasePart") then
				expect(d.Anchored).toBe(true)
				top = math.max(top, d.Position.Y)
			end
		end
		-- Its feet are on the pedestal (its pivot), and it is taller than the old 16-stud statue.
		local feet = figure:GetPivot().Position.Y
		expect(top - feet > 12).toBe(true)
		expect(figure:FindFirstChild("Head")).toBeTruthy()
	end)
end)
