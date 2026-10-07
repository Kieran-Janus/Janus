-- LobbyLife (src/client/LobbyLife.luau): the shopkeeper breathes, turns and waves, the Ready
-- pad pulses and its sign bounces, floor signs shimmer, the cauldron puffs and bats fly by,
-- only near the camera. Each test builds the whole hub into a client runtime and mounts it.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

type World = { [string]: any }

local function world(opts: { setup: ((w: World) -> ())? }?): World
	local o = opts or {}
	local rt = Runtime.new({ client = true })
	local env = rt.env
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Features.ReadyPad = true
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local hub = HubBuilder.Build()
	hub.Parent = rt.workspace
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(1600, 900))
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	local CS = rt.game:GetService("CollectionService")
	local w: World = {
		rt = rt,
		env = env,
		Config = Config,
		Life = Config.Lobby.Life,
		Client = Client,
		hub = hub,
		player = player,
		gui = gui,
		CS = CS,
		RS = rt.game:GetService("ReplicatedStorage"),
	}
	function w.npc()
		for _, m in CS:GetTagged("ShopKeeper") do
			if m:IsA("Model") then
				return m
			end
		end
		return nil
	end
	function w.keeper()
		return w.npc():FindFirstChild("Keeper") or w.npc():FindFirstChild("Look")
	end
	function w.spot()
		return w.npc():FindFirstChild("KeeperSpot").CFrame
	end
	function w.look(at: any, distance: number?)
		rt.workspace.CurrentCamera.CFrame =
			env.CFrame.new(at + env.Vector3.new(0, 6, distance or 14), at)
	end
	function w.far()
		rt.workspace.CurrentCamera.CFrame = env.CFrame.new(0, 500, 5000)
	end
	function w.away()
		w.player.Character.HumanoidRootPart.CFrame = env.CFrame.new(0, 3, 4000)
	end
	function w.standAt(cf: any)
		w.player.Character.HumanoidRootPart.CFrame = cf
	end
	function w.mount()
		rt:require(Client.LobbyLife).Mount(gui)
	end
	function w.fx()
		return rt.workspace:FindFirstChild("LobbyLifeFx")
	end
	if o.setup then
		o.setup(w)
	end
	rt:spawnCharacter(player, env.CFrame.new(0, 3, 4000))
	return w
end

local function samePlace(a: any, b: any): boolean
	return (a.Position - b.Position).Magnitude < 1e-4
		and (a.LookVector - b.LookVector).Magnitude < 1e-4
		and (a.UpVector - b.UpVector).Magnitude < 1e-4
end

local function poses(model: any): { [any]: any }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			out[d] = d.CFrame
		end
	end
	return out
end

local function allAtRest(rest: { [any]: any }): boolean
	for part, cf in rest do
		if not samePlace(part.CFrame, cf) then
			return false
		end
	end
	return true
end

-- The keeper's turn (degrees) from its rest facing, + = towards the +X side of its spot.
local function yawOf(w: World, head: any, rest: any): number
	local spot = w.spot()
	local function heading(v: any): number
		local p = spot:VectorToObjectSpace(v)
		return math.atan2(p.X, -p.Z)
	end
	local d = heading(head.CFrame.LookVector) - heading(rest.LookVector)
	d = (d + math.pi) % (2 * math.pi) - math.pi
	return math.deg(d)
end

describe("LobbyLife", function()
	it("mounts without errors with the hub built", function()
		local w = world()
		w.look(w.spot().Position)
		w.mount()
		w.rt:advance(2)
		expect(#w.rt.errors).toBe(0)
		expect(w.fx()).toBeTruthy()
		expect(w.keeper()).toBeTruthy()
	end)

	it("turns the keeper towards a nearby player and back to rest when they leave", function()
		local w = world()
		local spot = w.spot()
		w.look(spot.Position)
		local head = w.keeper():FindFirstChild("Head")
		local headRest = head.CFrame
		local rest = poses(w.keeper())
		w.mount()
		w.rt:advance(1)
		expect(math.abs(yawOf(w, head, headRest))).toBeLessThan(0.5)
		-- In front of the counter, off to the keeper's +X side, beyond waving distance.
		w.standAt(spot * w.env.CFrame.new(14, 3, -16))
		w.rt:advance(3)
		local turned = yawOf(w, head, headRest)
		T.note(("turned %.1f degrees"):format(turned))
		expect(turned).toBeGreaterThan(10)
		expect(turned).toBeLessThan(w.Life.Keeper.MaxTurn + 0.5)
		-- Far behind it on the other side: never past MaxTurn.
		w.standAt(spot * w.env.CFrame.new(-6, 3, 10))
		w.rt:advance(4)
		expect(math.abs(yawOf(w, head, headRest))).toBeLessThan(w.Life.Keeper.MaxTurn + 0.5)
		-- Gone: back to facing its counter (still breathing).
		w.away()
		w.rt:advance(5)
		expect(math.abs(yawOf(w, head, headRest))).toBeLessThan(1)
		-- Camera away: every part exactly where the server put it.
		w.far()
		w.rt:advance(0.1)
		expect(allAtRest(rest)).toBe(true)
		expect(#w.rt.errors).toBe(0)
	end)

	it("breathes while the camera is near and goes back exactly when it leaves", function()
		local w = world()
		w.look(w.spot().Position)
		local rest = poses(w.keeper())
		local head = w.keeper():FindFirstChild("Head")
		local y0 = head.Position.Y
		w.mount()
		local moved = 0
		for _ = 1, 30 do
			w.rt:advance(0.1)
			moved = math.max(moved, math.abs(head.Position.Y - y0))
		end
		expect(moved).toBeGreaterThan(0.02)
		expect(moved).toBeLessThan(w.Life.Keeper.BreathHeight + 0.01)
		w.far()
		w.rt:advance(0.1)
		expect(allAtRest(rest)).toBe(true)
	end)

	it("waves an arm when a player walks up", function()
		local w = world()
		local spot = w.spot()
		w.look(spot.Position)
		local keeper = w.keeper()
		local arms = {}
		for _, d in keeper:GetDescendants() do
			if d.Name == "Arm" then
				table.insert(arms, d)
			end
		end
		expect(#arms).toBe(2)
		local body = keeper:FindFirstChild("Body")
		local rel = {}
		for i, arm in arms do
			rel[i] = body.CFrame:ToObjectSpace(arm.CFrame)
		end
		w.mount()
		w.rt:advance(0.5)
		w.standAt(spot * w.env.CFrame.new(0, 3, -7))
		local lifted = { 0, 0 }
		for _ = 1, 12 do
			w.rt:advance(0.1)
			for i, arm in arms do
				local now = body.CFrame:ToObjectSpace(arm.CFrame)
				lifted[i] = math.max(lifted[i], (now.Position - rel[i].Position).Magnitude)
			end
		end
		T.note(("arm moved %.2f / %.2f studs"):format(lifted[1], lifted[2]))
		-- one arm waves, the other stays by its side
		expect(math.max(lifted[1], lifted[2])).toBeGreaterThan(0.5)
		expect(math.min(lifted[1], lifted[2])).toBeLessThan(1e-3)
		-- after the wave the arm is back in place
		w.rt:advance(w.Life.Keeper.WaveSeconds + 0.2)
		for i, arm in arms do
			local now = body.CFrame:ToObjectSpace(arm.CFrame)
			expect(samePlace(now, rel[i])).toBe(true)
		end
		expect(#w.rt.errors).toBe(0)
	end)

	it("wiggles a custom keeper without arms as one piece and restores it", function()
		local w = world({
			setup = function(w: World)
				local npc = w.npc()
				local spot = w.spot()
				npc:FindFirstChild("Keeper"):Destroy()
				local look = w.rt:create("Model", { Name = "Look" }, npc)
				local a = w.rt:create("Part", {
					Name = "Torso",
					Anchored = true,
					Size = w.env.Vector3.new(2, 4, 1),
					CFrame = spot * w.env.CFrame.new(0, 2, 0),
				}, look)
				w.rt:create("Part", {
					Name = "Hat",
					Anchored = true,
					Size = w.env.Vector3.new(1, 1, 1),
					CFrame = spot * w.env.CFrame.new(0, 4.5, 0),
				}, look)
				look.PrimaryPart = a
			end,
		})
		local spot = w.spot()
		w.look(spot.Position)
		local look = w.keeper()
		expect(look.Name).toBe("Look")
		local torso, hat = look.Torso, look.Hat
		local rest = poses(look)
		local gap = torso.CFrame:ToObjectSpace(hat.CFrame)
		w.mount()
		w.rt:advance(0.5)
		w.standAt(spot * w.env.CFrame.new(0, 3, -7))
		local tilted = 0
		for _ = 1, 15 do
			w.rt:advance(0.1)
			tilted =
				math.max(tilted, math.deg(math.acos(math.clamp(torso.CFrame.UpVector.Y, -1, 1))))
			-- moved as one piece
			expect(samePlace(torso.CFrame:ToObjectSpace(hat.CFrame), gap)).toBe(true)
		end
		expect(tilted).toBeGreaterThan(1)
		expect(tilted).toBeLessThan(w.Life.Keeper.WiggleAngle + 1)
		expect(#look:GetChildren()).toBe(2) -- nothing added to your model
		w.far()
		w.rt:advance(0.1)
		expect(allAtRest(rest)).toBe(true)
		expect(#w.rt.errors).toBe(0)
	end)

	it("puts a pulsing ring round the Ready pad, faster when someone is ready", function()
		local function pulses(count: number): (number, any)
			local w = world()
			local pad = w.CS:GetTagged("ReadyPad")[1]
			w.look(pad.Position, 20)
			w.RS:SetAttribute("ReadyCount", count)
			w.mount()
			w.rt:advance(0.2)
			local ring = w.fx():FindFirstChild("ReadyRing")
			expect(ring).toBeTruthy()
			local mid = (w.Life.ReadyPad.Brightest + w.Life.ReadyPad.Faintest) / 2
			local crossings, above = 0, nil
			local lo, hi = 1, 0
			for _ = 1, 160 do
				w.rt:advance(1 / 30)
				local t = ring.Transparency
				lo, hi = math.min(lo, t), math.max(hi, t)
				local now = t > mid
				if above ~= nil and now ~= above then
					crossings += 1
				end
				above = now
			end
			expect(lo).toBeGreaterThanOrEqual(w.Life.ReadyPad.Brightest - 1e-3)
			expect(hi).toBeLessThanOrEqual(w.Life.ReadyPad.Faintest + 1e-3)
			-- round the pad, lying at its foot
			local d = math.min(pad.Size.Y, pad.Size.Z)
			expect(ring.Size.Y).toBeGreaterThan(d)
			expect(math.abs(ring.Position.X - pad.Position.X)).toBeLessThan(0.01)
			expect(ring.Position.Y).toBeLessThan(pad.Position.Y)
			return crossings, ring
		end
		local idle, ring = pulses(0)
		local busy = pulses(2)
		T.note(("%d crossings idle, %d with players ready"):format(idle, busy))
		expect(busy).toBeGreaterThan(idle)
		expect(ring.CanCollide).toBe(false)
		expect(ring.CanQuery).toBe(false)
		expect(ring.CanTouch).toBe(false)
	end)

	it("bounces the READY sign when the count changes", function()
		local w = world()
		local sign = w.CS:GetTagged("ReadySign")[1]
		local gui = sign:FindFirstChildWhichIsA("BillboardGui")
		local rest = gui.StudsOffset
		w.look(sign.Position, 20)
		w.mount()
		w.rt:advance(0.5)
		expect(gui.StudsOffset).toBeNear(rest)
		w.RS:SetAttribute("ReadyCount", 1)
		local high = 0
		for _ = 1, 10 do
			w.rt:advance(0.04)
			high = math.max(high, gui.StudsOffset.Y - rest.Y)
		end
		expect(high).toBeGreaterThan(0.2)
		expect(high).toBeLessThanOrEqual(w.Life.ReadyPad.BounceHeight + 1e-3)
		w.rt:advance(w.Life.ReadyPad.BounceSeconds + 0.2)
		expect(gui.StudsOffset).toBeNear(rest)
	end)

	it("shimmers the floor signs within sane transparency and restores them", function()
		local w = world()
		local sign = w.CS:GetTagged("FloorSign")[1]
		local label = sign:FindFirstChild("Text", true)
		local box = sign:FindFirstChildWhichIsA("SelectionBox")
		local light = sign:FindFirstChildWhichIsA("PointLight")
		local rest = { label.TextTransparency, box.Transparency, light.Brightness }
		w.look(sign.Position, 16)
		w.mount()
		local lo, hi = 1, 0
		for _ = 1, 60 do
			w.rt:advance(0.1)
			lo = math.min(lo, label.TextTransparency)
			hi = math.max(hi, label.TextTransparency)
			expect(box.Transparency).toBeLessThanOrEqual(
				rest[2] + w.Life.FloorSigns.FrameFade + 1e-3
			)
			expect(light.Brightness).toBeLessThanOrEqual(rest[3] + 1e-3)
		end
		expect(hi - lo).toBeGreaterThan(0.05)
		expect(lo).toBeGreaterThanOrEqual(rest[1] - 1e-3)
		expect(hi).toBeLessThanOrEqual(rest[1] + w.Life.FloorSigns.TextFade + 1e-3)
		expect(hi).toBeLessThan(0.5) -- always readable
		w.far()
		w.rt:advance(0.2)
		expect(label.TextTransparency).toBe(rest[1])
		expect(box.Transparency).toBe(rest[2])
		expect(light.Brightness).toBe(rest[3])
	end)

	it("puffs the cauldron and bobs its bubbles", function()
		local w = world()
		local cauldron = nil
		for _, d in w.hub:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") == "Cauldron" then
				cauldron = d
			end
		end
		expect(cauldron).toBeTruthy()
		w.look(cauldron:GetPivot().Position, 20)
		local rest = poses(cauldron)
		w.mount()
		w.rt:advance(6)
		local emits = w.rt:calls("ParticleEmitter", "Emit")
		expect(#emits).toBeGreaterThan(0)
		expect(emits[1].args[1]).toBe(w.Life.Cauldron.Puffs)
		w.far()
		w.rt:advance(0.1)
		expect(allAtRest(rest)).toBe(true)
	end)

	it("leaves everything alone far from the camera", function()
		local w = world()
		w.far()
		local keeperRest = poses(w.keeper())
		local sign = w.CS:GetTagged("FloorSign")[1]
		local label = sign:FindFirstChild("Text", true)
		local t0 = label.TextTransparency
		local gui = w.CS:GetTagged("ReadySign")[1]:FindFirstChildWhichIsA("BillboardGui")
		local offset = gui.StudsOffset
		w.mount()
		w.standAt(w.spot() * w.env.CFrame.new(0, 3, -7))
		w.RS:SetAttribute("ReadyCount", 2)
		for _ = 1, 30 do
			w.rt:advance(0.1)
			expect(allAtRest(keeperRest)).toBe(true)
			expect(label.TextTransparency).toBe(t0)
			expect(gui.StudsOffset).toBeNear(offset)
		end
		expect(w.fx():FindFirstChild("ReadyRing").Transparency).toBe(1)
		expect(#w.rt:calls("ParticleEmitter", "Emit")).toBe(0)
		expect(w.fx():FindFirstChild("Bat")).toBeNil() -- no bats out here
	end)

	it("does nothing with Life switched off, and only the keeper stops with Keeper off", function()
		local w = world()
		w.Life.On = false
		w.look(w.spot().Position)
		local rest = poses(w.keeper())
		w.mount()
		w.standAt(w.spot() * w.env.CFrame.new(0, 3, -7))
		w.rt:advance(5)
		expect(w.fx()).toBeNil()
		expect(allAtRest(rest)).toBe(true)

		local w2 = world()
		w2.Life.Keeper.On = false
		w2.look(w2.spot().Position)
		local rest2 = poses(w2.keeper())
		w2.mount()
		w2.standAt(w2.spot() * w2.env.CFrame.new(0, 3, -7))
		w2.rt:advance(5)
		expect(allAtRest(rest2)).toBe(true)
		expect(w2.fx():FindFirstChild("ReadyRing")).toBeTruthy()
	end)

	it("lets bats fly by in the lobby, and nothing it makes collides or can be clicked", function()
		local w = world()
		local spawnPart = w.CS:GetTagged("HubSpawn")[1]
		w.look(spawnPart.Position, 20)
		w.mount()
		local sawBat = false
		local most = 0
		for _ = 1, 400 do
			w.rt:advance(0.1)
			local n = 0
			for _, p in w.fx():GetChildren() do
				if p.Name == "Bat" then
					n += 1
				end
			end
			if n > 0 then
				sawBat = true
			end
			most = math.max(most, n)
			for _, p in w.fx():GetDescendants() do
				if p:IsA("BasePart") then
					expect(p.CanCollide).toBe(false)
					expect(p.CanQuery).toBe(false)
					expect(p.CanTouch).toBe(false)
					expect(p.Anchored).toBe(true)
				end
			end
		end
		expect(sawBat).toBe(true)
		expect(most).toBeLessThanOrEqual(w.Life.Bats.Max)
		-- Stop puts it all away.
		w.rt:require(w.Client.LobbyLife).Stop()
		expect(w.fx()).toBeNil()
		expect(#w.rt.errors).toBe(0)
	end)
end)
