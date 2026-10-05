-- Self-tests for the harness: if these fail, the other specs can't be trusted.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local env = rt.env
local CFrame, Vector3, Color3, Instance, Enum =
	env.CFrame, env.Vector3, env.Color3, env.Instance, env.Enum
local task = env.task

-- Runs `source` as a ModuleScript under ServerScriptService and returns what it returns.
local function run(source: string): any
	local module =
		rt:create("ModuleScript", { Name = "Snippet" }, rt.game:GetService("ServerScriptService"))
	rt.Dom.setSource(module, source, "Snippet.luau")
	return rt:require(module)
end

local function part(props: { [string]: any }, parent: any?): any
	local p = Instance.new("Part")
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

describe("matchers", function()
	it("fail when they should", function()
		expect(function()
			expect(1).toBe(2)
		end).toThrow("expected 1 to be 2")
		expect(function()
			expect({ a = { 1 } }).toEqual({ a = { 2 } })
		end).toThrow()
		expect(function()
			expect(Vector3.new(1, 2, 3)).toBeNear(Vector3.new(1, 2, 3.1))
		end).toThrow()
		expect(function()
			expect(0 / 0).toBeFinite()
		end).toThrow()
		expect(function()
			expect(nil).never.toBeNil()
		end).toThrow("expected NOT")
		expect({ 1, 2 }).toEqual({ 1, 2 })
		expect("abc").toContain("b")
	end)
end)

describe("instances", function()
	it("are stable table keys and compare by identity", function()
		local model = Instance.new("Model")
		local p = part({ Name = "A" }, model)
		local keyed = { [p] = true }
		expect(keyed[model.A]).toBe(true)
		expect(keyed[model:GetChildren()[1]]).toBe(true)
		expect(env.typeof(p)).toBe("Instance")
		expect(type(p)).toBe("userdata")
	end)

	it("reject wrong property types and unknown members like Roblox", function()
		local p = Instance.new("Part")
		expect(function()
			p.Size = 5
		end).toThrow("Vector3 expected")
		expect(function()
			p.Material = Enum.PartType.Ball
		end).toThrow("Enum.Material")
		expect(function()
			p.Colour = Color3.new()
		end).toThrow("not a valid member")
		expect(function()
			return p.Nope
		end).toThrow("Nope is not a valid member of Part")
		expect(function()
			Instance.new("Workspace")
		end).toThrow("Unable to create")
		expect(function()
			p:SetAttribute("Bad", {})
		end).toThrow("not a supported attribute type")
		p.Material = "Neon" -- strings and numbers convert, as in Roblox
		expect(p.Material).toBe(Enum.Material.Neon)
	end)

	it("keep Position and CFrame in sync", function()
		local p = part({ CFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0, math.rad(90), 0) })
		expect(p.Position).toBeNear(Vector3.new(1, 2, 3))
		expect(p.Orientation).toBeNear(Vector3.new(0, 90, 0), 1e-3)
		p.Position = Vector3.new(5, 5, 5)
		expect(p.CFrame.Position).toBeNear(Vector3.new(5, 5, 5))
		expect(p.CFrame.LookVector).toBeNear(Vector3.new(-1, 0, 0), 1e-5)
	end)

	it("clone with internal references remapped, and lock Parent after Destroy", function()
		local model = Instance.new("Model")
		local a = part({ Name = "A" }, model)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = a
		weld.Parent = a
		model.PrimaryPart = a
		a:AddTag("Tagged")
		a:SetAttribute("Hp", 3)
		local copy = model:Clone()
		expect(copy.PrimaryPart).toBe(copy.A)
		expect(copy.A.WeldConstraint.Part0).toBe(copy.A)
		expect(copy.A:HasTag("Tagged")).toBe(true)
		expect(copy.A:GetAttribute("Hp")).toBe(3)
		model:Destroy()
		expect(a.Parent).toBeNil()
		expect(function()
			a.Parent = copy
		end).toThrow("locked")
	end)

	it("fire structural events", function()
		local folder = Instance.new("Folder")
		local added, destroyed, changed = 0, 0, 0
		folder.ChildAdded:Connect(function()
			added += 1
		end)
		local child = Instance.new("Folder")
		child.Destroying:Connect(function()
			destroyed += 1
		end)
		child:GetPropertyChangedSignal("Name"):Connect(function()
			changed += 1
		end)
		child.Parent = folder
		child.Name = "Renamed"
		child:Destroy()
		expect(added).toBe(1)
		expect(changed).toBe(1)
		expect(destroyed).toBe(1)
	end)
end)

describe("CFrame", function()
	it(
		"lookAt / lookAlong / new(pos, target) face the target (Lune's own lookAt is mirrored)",
		function()
			local at = Vector3.new(1, 2, 3)
			for _, target in
				{
					Vector3.new(4, 2, 7),
					Vector3.new(1, 2, 10),
					Vector3.new(-5, 2, 3),
					Vector3.new(1, 9, 3),
				}
			do
				local dir = (target - at).Unit
				expect(CFrame.lookAt(at, target).LookVector).toBeNear(dir, 1e-5)
				expect(CFrame.lookAt(at, target).Position).toBeNear(at)
				expect(CFrame.new(at, target).LookVector).toBeNear(dir, 1e-5)
				expect(CFrame.lookAlong(at, target - at).LookVector).toBeNear(dir, 1e-5)
			end
			local cf = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 5))
			expect(cf.RightVector).toBeNear(Vector3.new(-1, 0, 0), 1e-5)
			expect(cf.UpVector).toBeNear(Vector3.new(0, 1, 0), 1e-5)
		end
	)
end)

describe("model geometry", function()
	it("pivots to the PrimaryPart pivot and moves every part rigidly", function()
		local model = Instance.new("Model")
		local a = part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(10, 0, 0) }, model)
		local b = part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(14, 0, 0) }, model)
		model.PrimaryPart = a
		expect(model:GetPivot()).toBeNear(CFrame.new(10, 0, 0))
		local target = CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(90), 0)
		model:PivotTo(target)
		expect(a.CFrame).toBeNear(target, 1e-5)
		expect(b.Position).toBeNear(Vector3.new(0, 5, -4), 1e-5)
	end)

	it("uses the bounding box centre as pivot until one is set", function()
		local model = Instance.new("Model")
		part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 0, 0) }, model)
		part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(10, 0, 0) }, model)
		expect(model:GetPivot().Position).toBeNear(Vector3.new(5, 0, 0))
		model:PivotTo(CFrame.new(0, 0, 0))
		expect(model.WorldPivot.Position).toBeNear(Vector3.zero)
		local cf, size = model:GetBoundingBox()
		expect(cf.Position).toBeNear(Vector3.zero)
		expect(size).toBeNear(Vector3.new(12, 2, 2))
	end)

	it("measures rotated parts with their real corners", function()
		local model = Instance.new("Model")
		part({ Size = Vector3.new(4, 2, 2), CFrame = CFrame.Angles(0, 0, math.rad(90)) }, model)
		local _, size = model:GetBoundingBox()
		expect(size).toBeNear(Vector3.new(2, 4, 2), 1e-4)
		expect(model:GetExtentsSize()).toBeNear(Vector3.new(2, 4, 2), 1e-4)
	end)

	it("scales sizes and offsets about the pivot", function()
		local model = Instance.new("Model")
		local a = part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 1, 0) }, model)
		local b = part({ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 5, 0) }, model)
		model.PrimaryPart = a
		model:ScaleTo(2)
		expect(model:GetScale()).toBe(2)
		expect(a.Size).toBeNear(Vector3.new(4, 4, 4))
		expect(a.Position).toBeNear(Vector3.new(0, 1, 0))
		expect(b.Position).toBeNear(Vector3.new(0, 9, 0))
		expect(function()
			model:ScaleTo(0)
		end).toThrow()
	end)
end)

describe("raycasts", function()
	local world = Runtime.new()
	local floor = world:create("Part", {
		Name = "Floor",
		Size = Vector3.new(100, 2, 100),
		CFrame = CFrame.new(0, -1, 0),
		Anchored = true,
	}, world.workspace)
	local ball = world:create("Part", {
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(20, 2, 0),
	}, world.workspace)
	world:create("Part", {
		Name = "Ghost",
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(0, 10, 0),
		CanCollide = false,
		CanQuery = false,
	}, world.workspace)

	it("hit the nearest queryable part with the right point and normal", function()
		local hit = world.workspace:Raycast(Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
		expect(hit.Instance).toBe(floor)
		expect(hit.Position).toBeNear(Vector3.new(0, 0, 0), 1e-4)
		expect(hit.Normal).toBeNear(Vector3.new(0, 1, 0), 1e-4)
		local top = world.workspace:Raycast(Vector3.new(20, 50, 0), Vector3.new(0, -100, 0))
		expect(top.Instance).toBe(ball)
		expect(top.Position.Y).toBeNear(4, 1e-3)
	end)

	it("respect RaycastParams filters and ray length", function()
		local params = env.RaycastParams.new()
		params.FilterDescendantsInstances = { floor }
		expect(world.workspace:Raycast(Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)).toBeNil()
		params.FilterType = Enum.RaycastFilterType.Include
		expect(
			world.workspace:Raycast(Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params).Instance
		).toBe(floor)
		expect(world.workspace:Raycast(Vector3.new(0, 50, 0), Vector3.new(0, -10, 0))).toBeNil()
	end)
end)

describe("task scheduler", function()
	it("runs task loops in virtual time without blocking", function()
		local ticks = 0
		task.spawn(function()
			while true do
				task.wait(1)
				ticks += 1
			end
		end)
		rt:advance(10)
		expect(ticks).toBe(10)
		local fired = false
		task.delay(5, function()
			fired = true
		end)
		rt:advance(4.9)
		expect(fired).toBe(false)
		rt:advance(0.2)
		expect(fired).toBe(true)
	end)

	it("advances the clock when a test waits", function()
		local start = env.os.clock()
		task.wait(3)
		expect(env.os.clock() - start).toBeNear(3, 1e-6)
		expect(env.tick() - rt.epoch).toBeNear(rt:now(), 1e-6)
	end)

	it("lets task threads wait on signals", function()
		local bindable = Instance.new("BindableEvent")
		local got = nil
		task.spawn(function()
			got = bindable.Event:Wait()
		end)
		bindable:Fire("hello")
		expect(got).toBe("hello")
		expect(function()
			bindable.Event:Wait()
		end).toThrow("would block forever")
	end)

	it("reports errors thrown inside task threads", function()
		local before = #rt.errors
		rt.options.echo = "none"
		task.spawn(function()
			error("boom")
		end)
		rt.options.echo = Runtime.defaults.echo
		expect(#rt.errors).toBe(before + 1)
		expect(rt.errors[#rt.errors]).toContain("boom")
		Runtime.takeUncaught() -- expected here; don't fail this test
	end)

	it("runs RunService.Heartbeat once per frame while time advances", function()
		local frames = 0
		local connection = rt.game:GetService("RunService").Heartbeat:Connect(function()
			frames += 1
		end)
		rt:advance(1)
		connection:Disconnect()
		rt:advance(1)
		expect(frames).toBe(60)
	end)

	it("lets WaitForChild find children created by other tasks", function()
		local folder = Instance.new("Folder")
		task.delay(1, function()
			local child = Instance.new("Folder")
			child.Name = "Late"
			child.Parent = folder
		end)
		expect(folder:WaitForChild("Late")).toBeInstanceOf("Folder")
		expect(function()
			folder:WaitForChild("Never")
		end).toThrow("Infinite yield")
	end)
end)

describe("Random", function()
	it("is deterministic per seed and in range", function()
		local a, b = env.Random.new(42), env.Random.new(42)
		for _ = 1, 100 do
			local x = a:NextNumber(5, 10)
			expect(x).toBe(b:NextNumber(5, 10))
			expect(x >= 5 and x < 10).toBe(true)
			local n = a:NextInteger(1, 3)
			expect(n).toBe(b:NextInteger(1, 3))
			expect(n >= 1 and n <= 3 and n % 1 == 0).toBe(true)
		end
		local c = a:Clone()
		expect(c:NextNumber()).toBe(a:NextNumber())
		expect(env.Random.new(1):NextNumber()).never.toBe(env.Random.new(2):NextNumber())
		local t = { 1, 2, 3, 4, 5 }
		a:Shuffle(t)
		table.sort(t)
		expect(t).toEqual({ 1, 2, 3, 4, 5 })
		expect(function()
			a:NextInteger(5, 1)
		end).toThrow("interval is empty")
	end)
end)

describe("services", function()
	it("track tags through CollectionService", function()
		local CollectionService = rt.game:GetService("CollectionService")
		local added = 0
		CollectionService:GetInstanceAddedSignal("Thing"):Connect(function()
			added += 1
		end)
		local p = Instance.new("Part")
		CollectionService:AddTag(p, "Thing")
		expect(added).toBe(0) -- not in the DataModel yet
		p.Parent = rt.workspace
		expect(added).toBe(1)
		expect(CollectionService:GetTagged("Thing")).toEqual({ p })
		expect(CollectionService:HasTag(p, "Thing")).toBe(true)
		p:Destroy()
		expect(#CollectionService:GetTagged("Thing")).toBe(0)
	end)

	it("save DataStore values as JSON and can simulate failures", function()
		local store = rt.game:GetService("DataStoreService"):GetDataStore("Test")
		store:SetAsync("k", { Coins = 5, Owned = { Hat = true } })
		expect(store:GetAsync("k")).toEqual({ Coins = 5, Owned = { Hat = true } })
		expect(function()
			store:SetAsync("bad", { Where = Vector3.zero })
		end).toThrow("Cannot store Vector3")
		rt.dataStoreFailures = 1
		expect(function()
			store:GetAsync("k")
		end).toThrow("502")
		expect(store:GetAsync("k").Coins).toBe(5)
	end)

	it("complete tweens after their duration", function()
		local p = part({ Transparency = 0 }, rt.workspace)
		local tween =
			rt.game:GetService("TweenService"):Create(p, env.TweenInfo.new(2), { Transparency = 1 })
		local done = nil
		tween.Completed:Connect(function(state)
			done = state
		end)
		tween:Play()
		rt:advance(1)
		expect(p.Transparency).toBe(0)
		rt:advance(1.5)
		expect(p.Transparency).toBe(1)
		expect(done).toBe(Enum.PlaybackState.Completed)
		expect(function()
			rt.game
				:GetService("TweenService")
				:Create(p, env.TweenInfo.new(1), { Transparency = "x" })
		end).toThrow("type mismatch")
	end)

	it("add players with characters", function()
		local Players = rt.game:GetService("Players")
		local joined = nil
		Players.PlayerAdded:Connect(function(player)
			joined = player
		end)
		local player = rt:addPlayer({ Name = "Alice", UserId = 77 })
		expect(joined).toBe(player)
		expect(Players:GetPlayerByUserId(77)).toBe(player)
		expect(Players:GetPlayerFromCharacter(player.Character)).toBe(player)
		expect(player.Character.Humanoid.Health).toBe(100)
		player.Character.Humanoid:TakeDamage(150)
		expect(player.Character.Humanoid.Health).toBe(0)
		rt:removePlayer(player)
		expect(#Players:GetPlayers()).toBe(0)
	end)
end)

describe("modules", function()
	it("run with script, require and the Roblox globals", function()
		local result = run([[
			local Players = game:GetService("Players")
			return {
				name = script.Name,
				server = game:GetService("RunService"):IsServer(),
				players = #Players:GetPlayers(),
				hasTask = typeof(task.wait) == "function",
				random = typeof(Random.new(1)),
			}
		]])
		expect(result).toEqual({
			name = "Snippet",
			server = true,
			players = 0,
			hasTask = true,
			random = "Random",
		})
	end)

	it("report errors with the source file and line", function()
		expect(function()
			run("local x = nil\nreturn x.field")
		end).toThrow("Snippet.luau:2")
	end)
end)
