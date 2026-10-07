-- MapLife (src/client/MapLife.luau): King Hunt pumpkins bob, spin, glow and pop when collected,
-- fireflies drift on the round map, Hide & Seek decoys and hiders' pumpkins wobble alike.
-- Pickup tests load the map and run PumpkinService in the client runtime itself; the Hide &
-- Seek test plays a real round on a server runtime and replicates the map into a client.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

type World = { [string]: any }

local function world(opts: { phone: boolean?, setup: ((w: World) -> ())? }?): World
	local o = opts or {}
	local rt = Runtime.new({ client = true })
	local env = rt.env
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	if o.phone then
		gui:SetAttribute("ForceTouch", true)
		Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(640, 302))
	else
		Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(1600, 900))
	end
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	local w: World = {
		rt = rt,
		env = env,
		Config = Config,
		Client = Client,
		player = player,
		gui = gui,
		CS = rt.game:GetService("CollectionService"),
	}
	function w.mount()
		w.MapLife = rt:require(Client.MapLife)
		w.MapLife.Mount(gui)
	end
	function w.fx()
		return rt.workspace:FindFirstChild("MapLifeFx")
	end
	function w.look(at: any, distance: number?)
		rt.workspace.CurrentCamera.CFrame =
			env.CFrame.new(at + env.Vector3.new(0, 6, distance or 12), at)
	end
	function w.far()
		rt.workspace.CurrentCamera.CFrame = env.CFrame.new(0, 500, 9000)
	end
	-- Loads King Hunt's map and starts its pumpkins (server code, in this runtime).
	function w.kingHunt()
		local MapService = rt:require("ServerScriptService.Server.Services.MapService")
		local PumpkinService = rt:require("ServerScriptService.Server.Services.PumpkinService")
		w.map = MapService.Load("PumpkinPatch")
		w.MapService, w.PumpkinService = MapService, PumpkinService
		PumpkinService.Begin(w.map, "Easy", function()
			return true
		end)
		w.pickups = w.CS:GetTagged("PumpkinPickup")
	end
	if o.setup then
		o.setup(w)
	end
	return w
end

-- Every part MapLife made (its folder and the shared sparkle folder).
local function madeParts(w: World): { any }
	local out = {}
	for _, name in { "MapLifeFx", "MinigameFx" } do
		local folder = w.rt.workspace:FindFirstChild(name)
		if folder then
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(out, d)
				end
			end
		end
	end
	return out
end

local function expectHarmless(parts: { any })
	for _, p in parts do
		expect(p.CanCollide).toBe(false)
		expect(p.CanQuery).toBe(false)
		expect(p.CanTouch).toBe(false)
		expect(p.Anchored).toBe(true)
	end
end

local function copies(w: World): { any }
	local out = {}
	local fx = w.fx()
	if fx then
		for _, c in fx:GetChildren() do
			if c:GetAttribute("MapLifeCopy") then
				table.insert(out, c)
			end
		end
	end
	return out
end

local function fireflies(w: World): number
	local n = 0
	local fx = w.fx()
	if fx then
		for _, c in fx:GetChildren() do
			if c.Name == "Firefly" then
				n += 1
			end
		end
	end
	return n
end

describe("MapLife pickups", function()
	it("mounts without errors with a map loaded", function()
		local w = world()
		w.kingHunt()
		expect(#w.pickups).toBeGreaterThan(5)
		w.look(w.pickups[1].Position)
		w.mount()
		w.rt:advance(2)
		expect(#w.rt.errors).toBe(0)
		expect(w.fx()).toBeTruthy()
	end)

	it("bobs and spins a look-only copy; the touch part stays where the server put it", function()
		local w = world()
		w.kingHunt()
		local pumpkin = w.pickups[1]
		local rest = pumpkin.CFrame
		local light = pumpkin:FindFirstChildOfClass("PointLight")
		local brightness = light.Brightness
		w.look(pumpkin.Position)
		w.mount()
		local heights, turns = {}, {}
		local copy
		for _ = 1, 12 do
			w.rt:advance(0.13)
			for _, c in copies(w) do
				if (c.Position - pumpkin.Position).Magnitude < 2 then
					copy = c
				end
			end
			expect(copy).toBeTruthy()
			table.insert(heights, copy.Position.Y - rest.Y)
			table.insert(turns, copy.CFrame.LookVector)
			-- The real pumpkin: not moved, hidden on this screen only, still touchable.
			expect((pumpkin.CFrame.Position - rest.Position).Magnitude).toBe(0)
			expect(pumpkin.LocalTransparencyModifier).toBe(1)
			expect(pumpkin.CanTouch).toBe(true)
		end
		local lo, hi = math.huge, -math.huge
		for _, h in heights do
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
		expect(hi - lo).toBeGreaterThan(0.1) -- it bobs
		expect(hi).toBeLessThanOrEqual(w.Config.MapLife.Pickups.BobHeight + 1e-3)
		expect((turns[1] - turns[#turns]).Magnitude).toBeGreaterThan(0.05) -- it spins
		expect(copy:FindFirstChild("Stem")).toBeTruthy() -- (the plain ball gets a stem)
		expect(copy:FindFirstChildWhichIsA("PointLight", true)).toBeNil()
		expect(#w.CS:GetTags(copy)).toBe(0)
		expect(math.abs(light.Brightness - brightness)).toBeGreaterThan(0) -- the glow breathes
		expectHarmless(madeParts(w))

		-- Camera away: everything back exactly.
		w.far()
		w.rt:advance(0.2)
		expect(pumpkin.LocalTransparencyModifier).toBe(0)
		expect(light.Brightness).toBe(brightness)
		expect(#copies(w)).toBe(0)
		expect(pumpkin.CFrame).toEqual(rest)
		expect(#w.rt.errors).toBe(0)
	end)

	it("still collects on touch, then bursts and pops where it was and cleans up", function()
		local w = world()
		w.kingHunt()
		local pumpkin = w.pickups[1]
		local at = pumpkin.Position
		w.look(at)
		w.mount()
		w.rt:advance(0.5)
		expect(pumpkin.LocalTransparencyModifier).toBe(1)
		local player = w.player
		w.rt:spawnCharacter(player, w.env.CFrame.new(at))
		player.Character:PivotTo(w.env.CFrame.new(at))
		w.rt:fire(pumpkin, "Touched", player.Character.HumanoidRootPart)
		expect(player:GetAttribute("Pumpkins")).toBe(w.Config.Pumpkins.Value)
		expect(pumpkin.Parent).toBeNil()
		w.rt:advance(0.05)
		local burst = w.rt.workspace:FindFirstChild("MinigameFx")
		expect(burst and burst:FindFirstChild("Burst")).toBeTruthy()
		local emits = w.rt:calls("ParticleEmitter", "Emit")
		expect(emits[#emits].args[1]).toBe(w.Config.MapLife.Pickups.BurstCount)
		local pop = w.fx():FindFirstChild("PickupPop")
		expect(pop).toBeTruthy()
		expect((pop.Position - at).Magnitude).toBeLessThan(0.01)
		expectHarmless(madeParts(w))
		-- Its copy went with it.
		for _, c in copies(w) do
			expect((c.Position - at).Magnitude).toBeGreaterThan(1)
		end
		w.rt:advance(2)
		expect(w.fx():FindFirstChild("PickupPop")).toBeNil()
		expect(burst:FindFirstChild("Burst")).toBeNil()
		expect(#w.rt.errors).toBe(0)
	end)

	it("doesn't pop pumpkins when the round ends (they all go at once)", function()
		local w = world()
		w.kingHunt()
		w.look(w.pickups[1].Position)
		w.rt:spawnCharacter(w.player, w.env.CFrame.new(w.pickups[1].Position))
		w.mount()
		w.rt:advance(0.5)
		w.PumpkinService.Stop()
		w.rt:advance(0.1)
		expect(w.fx():FindFirstChild("PickupPop")).toBeNil()
		expect(#copies(w)).toBe(0)
		expect(#w.rt.errors).toBe(0)
	end)

	it(
		"works with a custom CollectPumpkin model (the look moves, the hidden ball stays)",
		function()
			local w = world()
			local m = w.rt:create("Model", { Name = "CollectPumpkin" })
			w.rt:create("Part", {
				Name = "Look",
				Size = w.env.Vector3.new(2, 3, 2),
				CFrame = w.env.CFrame.new(0, 1.5, 0),
			}, m)
			m.Parent = w.rt:find("ReplicatedStorage.Custom.Props")
			w.kingHunt()
			local pumpkin = w.pickups[1]
			local rest = pumpkin.CFrame
			local look = pumpkin:FindFirstChild("CollectPumpkin"):FindFirstChild("Look")
			local lookRest = look.CFrame
			w.look(pumpkin.Position)
			w.mount()
			w.rt:advance(1)
			expect(pumpkin.CFrame).toEqual(rest)
			expect(look.CFrame).toEqual(lookRest)
			expect(look.LocalTransparencyModifier).toBe(1)
			local copy = copies(w)[1]
			expect(copy).toBeTruthy()
			expect(copy:FindFirstChild("Stem")).toBeNil() -- your model has its own look
			expectHarmless(madeParts(w))
			w.MapLife.Stop()
			expect(look.LocalTransparencyModifier).toBe(0)
			expect(w.fx()).toBeNil()
		end
	)

	it("does nothing with the switch off", function()
		local w = world()
		w.Config.Features.MapLife = false
		w.kingHunt()
		w.look(w.pickups[1].Position)
		w.mount()
		w.rt:advance(2)
		expect(w.fx()).toBeNil()
		expect(w.pickups[1].LocalTransparencyModifier).toBe(0)
	end)
end)

describe("MapLife ambience", function()
	it("drifts fireflies near the camera on the map, fewer on phones, none in the lobby", function()
		local function count(phone: boolean): (number, any)
			local w = world({ phone = phone })
			w.kingHunt()
			w.look(w.map.Floor.Position + w.env.Vector3.new(0, 4, 0))
			w.mount()
			w.rt:advance(2)
			local n = fireflies(w)
			expectHarmless(madeParts(w))
			-- They drift, and stay near you.
			local fx = w.fx()
			local fly = fx:FindFirstChild("Firefly")
			local before = fly.Position
			w.rt:advance(1)
			expect((fly.Position - before).Magnitude).toBeGreaterThan(0)
			local eye = w.rt.workspace.CurrentCamera.CFrame.Position
			for _, f in fx:GetChildren() do
				if f.Name == "Firefly" then
					expect((f.Position - eye).Magnitude).toBeLessThan(
						w.Config.MapLife.Ambient.Radius + 30
					)
				end
			end
			-- Off the map (the lobby): gone.
			w.far()
			w.rt:advance(0.5)
			expect(fireflies(w)).toBe(0)
			expect(#w.rt.errors).toBe(0)
			return n, w.Config.MapLife.Ambient
		end
		local pc, cfg = count(false)
		local phone = count(true)
		expect(pc).toBe(cfg.Count)
		expect(phone).toBe(cfg.PhoneCount)
		expect(phone).toBeLessThan(pc)
	end)
end)

describe("MapLife Hide & Seek wobble", function()
	-- A real round on a server, replicated into a client with MapLife mounted.
	local function round(): (World, any, any)
		local server = Runtime.new()
		local Config = server:require("ReplicatedStorage.Shared.Config")
		local DataService = server:require("ServerScriptService.Server.Services.DataService")
		local MapService = server:require("ServerScriptService.Server.Services.MapService")
		local HideSeek = server:require("ServerScriptService.Server.Modes.HideSeek")
		local RS = server.game:GetService("ReplicatedStorage")
		DataService.Start()
		local players = {}
		for i = 1, 3 do
			table.insert(players, server:addPlayer({ Name = "Player" .. i }))
		end
		server:advance(1)
		local map = MapService.Load("PumpkinFarm")
		local ctx = {
			Map = map,
			Players = players,
			Difficulty = "Easy",
			Playlist = { Id = "HideSeekFarm", Mode = "HideSeek", Map = "PumpkinFarm", Name = "T" },
			SetState = function(s, timeLeft)
				RS:SetAttribute("State", s)
				RS:SetAttribute("TimeLeft", timeLeft)
			end,
			Countdown = function(s, seconds, stopIf)
				for remaining = seconds, 1, -1 do
					if stopIf and stopIf() then
						return
					end
					RS:SetAttribute("State", s)
					RS:SetAttribute("TimeLeft", remaining)
					server.env.task.wait(1)
				end
			end,
			Teleport = function(player, spawn)
				player.Character:PivotTo(
					server.env.CFrame.new(spawn.Position + server.env.Vector3.new(0, 4, 0))
				)
			end,
			AliveHumanoid = function(player)
				local character = player.Character
				return character and character:FindFirstChildOfClass("Humanoid")
			end,
		}
		server.scheduler:spawn(function()
			HideSeek.Run(ctx)
		end)
		server:advance(0.5)
		local serverPumpkin
		for _, model in server.game:GetService("CollectionService"):GetTagged("HiderPumpkin") do
			serverPumpkin = model
		end
		expect(serverPumpkin).toBeTruthy()
		expect(Config.Features.MapLife).toBe(true)

		local w = world()
		w.rt:replicateFrom(server, { "Workspace" })
		local hider = w.CS:GetTagged("HiderPumpkin")[1]
		expect(hider).toBeTruthy()
		-- The nearest decoy to the hider.
		local decoy, best = nil, math.huge
		for _, d in w.CS:GetTagged("HidingDecoy") do
			local dist = (d:GetPivot().Position - hider:GetPivot().Position).Magnitude
			if dist < best then
				decoy, best = d, dist
			end
		end
		expect(decoy).toBeTruthy()
		return w, hider, decoy
	end

	it("wobbles decoys and hiders' pumpkins the same way, never moving the real ones", function()
		local w, hider, decoy = round()
		w.look(hider:GetPivot().Position, 10)
		w.mount()
		w.rt:advance(0.1)
		local function realPoses(target)
			local out = {}
			for _, d in target:GetDescendants() do
				if d:IsA("BasePart") then
					out[d] = d.CFrame
				end
			end
			return out
		end
		local hiderRest, decoyRest = realPoses(hider), realPoses(decoy)
		-- Stop the random wobbles, then wobble each one on purpose and compare the motion.
		local cfg = w.Config.MapLife.Wobble
		for _, target in w.MapLife.Wobbling() do
			expect(target).toBeTruthy()
		end
		w.rt:advance(cfg.Seconds + 0.1)
		-- How far a pumpkin's copy is turned from the real one (degrees, whatever its shape).
		local function tilt(target): number
			local real = target.PrimaryPart
			local copy
			for _, c in copies(w) do
				if c.PrimaryPart and (c.PrimaryPart.Position - real.Position).Magnitude < 3 then
					copy = c.PrimaryPart
				end
			end
			expect(copy).toBeTruthy()
			local turn = copy.CFrame * real.CFrame:Inverse()
			local _, _, _, r00, _, _, _, r11, _, _, _, r22 = turn:GetComponents()
			return math.deg(math.acos(math.clamp((r00 + r11 + r22 - 1) / 2, -1, 1)))
		end
		-- (wait for any random wobble on them to finish, then start both on the same frame)
		for _ = 1, 30 do
			local now = w.MapLife.Wobbling()
			if not table.find(now, hider) and not table.find(now, decoy) then
				break
			end
			w.rt:advance(0.1)
		end
		expect(w.MapLife.Wobble(hider)).toBe(true)
		expect(w.MapLife.Wobble(decoy)).toBe(true)
		local hiderTilt, decoyTilt = {}, {}
		for _ = 1, 6 do
			w.rt:advance(cfg.Seconds / 8)
			table.insert(hiderTilt, tilt(hider))
			table.insert(decoyTilt, tilt(decoy))
			for _, target in { hider, decoy } do
				for _, d in target:GetDescendants() do
					if d:IsA("BasePart") then
						expect(d.LocalTransparencyModifier).toBe(1) -- hidden while its copy wobbles
					end
				end
			end
		end
		local most = 0
		for i, a in hiderTilt do
			most = math.max(most, a)
			expect(a).toBeNear(decoyTilt[i], 0.05) -- the same wobble
		end
		expect(most).toBeGreaterThan(1)
		expect(most).toBeLessThanOrEqual(cfg.Angle * 1.2)
		expectHarmless(madeParts(w))
		-- The real pumpkins never moved, and show again afterwards.
		w.rt:advance(cfg.Seconds + 0.2)
		for part, cf in hiderRest do
			expect(part.CFrame).toEqual(cf)
		end
		for part, cf in decoyRest do
			expect(part.CFrame).toEqual(cf)
			expect(part.LocalTransparencyModifier).toBe(0)
		end
		expect(#w.rt.errors).toBe(0)
	end)

	it("picks hiders' pumpkins as often as decoys", function()
		local w, hider = round()
		w.look(hider:GetPivot().Position, 2)
		-- Only the pumpkins right by the hider: it and the few nearest decoys.
		local eye = w.rt.workspace.CurrentCamera.CFrame.Position
		local dists = {}
		for _, d in w.CS:GetTagged("HidingDecoy") do
			table.insert(dists, (d:GetPivot().Position - eye).Magnitude)
		end
		table.sort(dists)
		w.Config.MapLife.Range =
			math.max(dists[3] + 0.5, (hider:GetPivot().Position - eye).Magnitude + 0.5)
		w.mount()
		local seen = {}
		for _ = 1, 600 do
			w.rt:advance(0.1)
			for _, target in w.MapLife.Wobbling() do
				seen[target] = true
			end
		end
		local n = 0
		for _ in seen do
			n += 1
		end
		expect(seen[hider]).toBe(true)
		expect(n).toBeGreaterThan(1) -- decoys too
		T.note(("%d different pumpkins wobbled in 60 seconds"):format(n))
		expect(#w.rt.errors).toBe(0)
	end)

	it("doesn't wobble with the switch off", function()
		local w, hider = round()
		w.Config.MapLife.Wobble.On = false
		w.look(hider:GetPivot().Position, 2)
		w.mount()
		w.rt:advance(10)
		expect(#w.MapLife.Wobbling()).toBe(0)
		expect(w.MapLife.Wobble(hider)).toBe(false)
		expect(#copies(w)).toBe(0)
	end)
end)
