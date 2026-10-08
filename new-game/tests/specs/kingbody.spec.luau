-- The Pumpkin King's part-built body (src/server/Build/KingBody.luau): it stands on the floor
-- (no floating), every piece is welded to the hidden root and walks through nothing, it has
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
		local robe = model:FindFirstChild("Robe1")
		expect(robe).toBeTruthy()
		-- The robe's lowest tier touches the floor: no gap under him.
		local robeBottom = robe.Position.Y - robe.Size.X / 2
		expect(robeBottom - floor).toBeNear(0.1, 0.05)
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

	it("welds every piece to the root, with no collisions", function()
		local w = world()
		local model, _, root = w.KingBody.Build(w.Vector3.new(0, 4, 0))
		local count = 0
		for _, p in parts(model) do
			if p ~= root then
				count += 1
				expect(p.Anchored).toBe(false)
				expect(p.CanCollide).toBe(false)
				expect(p.Massless).toBe(true)
				local weld = p:FindFirstChildOfClass("WeldConstraint")
				expect(weld).toBeTruthy()
				expect(weld.Part0).toBe(root)
			end
		end
		expect(count > 30).toBe(true)
		expect(count < 120).toBe(true)
	end)

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
