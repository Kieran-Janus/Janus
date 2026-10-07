-- Phone performance of the client (src/client/): with the whole hub built and every screen
-- mounted, how many per-frame callbacks (RunService RenderStepped / Heartbeat / ...) run and
-- how much they do while idle far from everything (should be almost nothing), near the crate
-- stand (bounded); panels opened and closed 20 times leave no instances or connections
-- behind; a round's worth of MapLife setup and teardown cleans up after itself.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local FRAME_EVENTS =
	{ "PreRender", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation", "Heartbeat" }

-- Client modules that must run nothing per frame idle in the lobby far from everything.
local IDLE_FREE = {
	"FramePace", -- (CrateIdle, LobbyLife and HubAmbience's loops)
	"CrateIdle",
	"LobbyLife",
	"HubAmbience",
	"MapLife",
	"SkinFx",
	"Dances",
	"ShopUI",
	"CrateUI",
	"ParkourUI",
	"VipUI",
	"RoundJuiceUI",
	"CandyGunClient",
}

type Stats = {
	frames: number,
	listeners: number, -- per-frame callbacks connected at the end
	calls: number, -- per-frame callbacks run
	busy: number, -- of those, how many changed something (wrote a property, made an instance...)
	writes: number, -- property writes they made
	seconds: number, -- real CPU time spent in them
	instances: number, -- instances made while measuring
	connections: number, -- connections made while measuring
	sources: { [string]: number }, -- callbacks run, by the script that connected them
	busyBy: { [string]: number }, -- busy callbacks, by script
}

-- Every per-frame callback connected right now.
local function frameListeners(rt): number
	local n = 0
	for _, name in FRAME_EVENTS do
		n += rt.listening[name] or 0
	end
	for _ in rt.renderSteps do
		n += 1
	end
	return n
end

-- Live connections of every kind (Disconnect and Destroy count them down).
local function liveConnections(rt): number
	local n = 0
	for _, count in rt.listening do
		n += count
	end
	return n
end

local function sourceOf(fn: any): string
	local src = debug.info(fn, "s") or "?"
	return src:match("([%w_]+)%.luau") or src:match("([%w_]+)$") or src
end

-- Runs `seconds` of virtual time and measures the per-frame callbacks.
local function measure(rt, seconds: number): Stats
	local run = rt.game:GetService("RunService")
	local stats: Stats = {
		frames = 0,
		listeners = 0,
		calls = 0,
		busy = 0,
		writes = 0,
		seconds = 0,
		instances = 0,
		connections = 0,
		sources = {},
		busyBy = {},
	}
	local wrapped = {}
	for _, name in FRAME_EVENTS do
		local signal = (run :: any)[name]
		for _, c in signal._conns do
			local fn = c._fn
			local src = sourceOf(fn)
			table.insert(wrapped, { c = c, fn = fn })
			c._fn = function(...)
				local instances, changes, writes =
					rt.instanceCount, rt.connectionCount, rt.propWrites or 0
				local t = os.clock()
				fn(...)
				stats.seconds += os.clock() - t
				stats.calls += 1
				stats.sources[src] = (stats.sources[src] or 0) + 1
				local wrote = (rt.propWrites or 0) - writes
				stats.writes += wrote
				if wrote > 0 or rt.instanceCount ~= instances or rt.connectionCount ~= changes then
					stats.busy += 1
					stats.busyBy[src] = (stats.busyBy[src] or 0) + 1
				end
			end
		end
	end
	local heartbeat = (run :: any).Heartbeat
	local counter = heartbeat:Connect(function()
		stats.frames += 1
	end)
	local instances0, connections0 = rt.instanceCount, rt.connectionCount
	rt:advance(seconds)
	counter:Disconnect()
	stats.instances = rt.instanceCount - instances0
	stats.connections = rt.connectionCount - connections0
	for _, w in wrapped do
		w.c._fn = w.fn
	end
	stats.listeners = frameListeners(rt)
	return stats
end

local function describeStats(label: string, s: Stats): string
	local parts = {}
	for src, n in s.sources do
		local busy = s.busyBy[src]
		table.insert(
			parts,
			if busy then ("%s %d (%d busy)"):format(src, n, busy) else ("%s %d"):format(src, n)
		)
	end
	table.sort(parts)
	return ("%s: %d frames, %d per-frame callbacks connected, %d calls (%.1f per frame), %d busy, %d property writes, %.1f ms in them, %d instances, %d connections made [%s]"):format(
		label,
		s.frames,
		s.listeners,
		s.calls,
		s.calls / math.max(s.frames, 1),
		s.busy,
		s.writes,
		s.seconds * 1000,
		s.instances,
		s.connections,
		table.concat(parts, ", ")
	)
end

-- A server that built the hub, and a client that got it and mounted every screen.
local function boot(opts: { phone: boolean? }?)
	local o = opts or {}
	local server = Runtime.new()
	local ok, err = server:runScript("ServerScriptService.Server.Main")
	assert(ok, err)
	server:advance(1)
	local client = Runtime.new({ client = true })
	client:replicateFrom(server)
	local env = client.env
	local player = client.game:GetService("Players").LocalPlayer
	client:spawnCharacter(player, env.CFrame.new(0, 3, 4000))
	local camera = client.workspace.CurrentCamera
	camera.CFrame = env.CFrame.new(0, 500, 5000)
	local ok2, err2 = client:runScript("StarterPlayer.StarterPlayerScripts.Client.Main")
	assert(ok2, err2)
	local gui = player.PlayerGui:WaitForChild("GameUI")
	if o.phone then
		gui:SetAttribute("ForceTouch", true)
		Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(640, 302))
	else
		Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(1600, 900))
	end
	client:advance(10)
	for _, text in client.warnings do
		assert(not text:find("[Main]", 1, true), text)
	end
	return {
		server = server,
		rt = client,
		env = env,
		player = player,
		gui = gui,
		camera = camera,
		Config = client:require("ReplicatedStorage.Shared.Config"),
		CS = client.game:GetService("CollectionService"),
		Client = client:find("StarterPlayer.StarterPlayerScripts.Client"),
	}
end

local function far(w)
	w.camera.CFrame = w.env.CFrame.new(0, 500, 5000)
	w.player.Character.HumanoidRootPart.CFrame = w.env.CFrame.new(0, 3, 4000)
end

local function nearCrates(w)
	local display = w.CS:GetTagged("CrateDisplay")[1]
	expect(display).toBeTruthy()
	local at = display.Position
	w.camera.CFrame = w.env.CFrame.new(at + w.env.Vector3.new(0, 6, 14), at)
	w.player.Character.HumanoidRootPart.CFrame = w.env.CFrame.new(at + w.env.Vector3.new(0, 0, 6))
end

-- Instances under the game (PlayerGui and Workspace included).
local function count(rt): number
	return #rt.game:GetDescendants()
end

describe("client per-frame work", function()
	it("does almost nothing idle far from everything in the lobby", function()
		local w = boot()
		far(w)
		w.rt:advance(1) -- (anything that was animating puts itself back first)
		local s = measure(w.rt, 5)
		T.note(describeStats("idle, far", s))
		expect(#w.rt.errors).toBe(0)
		-- Far from everything: no callback changes anything and nothing is made.
		expect(s.instances).toBe(0)
		expect(s.connections).toBe(0)
		expect(s.busy).toBe(0)
		-- The lobby / map animations and closed panels connect nothing per frame out here
		-- (FramePace.IdleLoop looks around from a timer instead).
		for _, name in IDLE_FREE do
			if s.sources[name] then
				error(name .. " still runs every frame far from everything", 0)
			end
		end
		expect(s.calls / s.frames).toBeLessThanOrEqual(6)
	end)

	it("keeps the work near the crate stand bounded", function()
		local w = boot()
		nearCrates(w)
		w.rt:advance(1)
		local s = measure(w.rt, 5)
		T.note(describeStats("near the crate stand", s))
		expect(#w.rt.errors).toBe(0)
		expect(s.calls / s.frames).toBeLessThanOrEqual(10)
		-- Peeks and sparkles may make a few things; nothing piles up.
		expect(s.instances).toBeLessThan(60)
		expect(s.writes / s.frames).toBeLessThan(150)
	end)

	it("does as little on a phone", function()
		local w = boot({ phone = true })
		far(w)
		w.rt:advance(1)
		local s = measure(w.rt, 5)
		T.note(describeStats("phone, idle, far", s))
		expect(s.busy).toBe(0)
		expect(s.instances).toBe(0)
		nearCrates(w)
		w.rt:advance(1)
		local near = measure(w.rt, 5)
		T.note(describeStats("phone, near the crate stand", near))
		expect(near.calls / near.frames).toBeLessThanOrEqual(10)
		expect(#w.rt.errors).toBe(0)
	end)
end)

describe("panels don't leak", function()
	it("opens and closes the Shop, Crates and Menu 20 times with flat counts", function()
		local w = boot()
		far(w)
		local ShopUI = w.rt:require(w.Client.ShopUI)
		local CrateUI = w.rt:require(w.Client.CrateUI)
		local MenuUI = w.rt:require(w.Client.MenuUI)
		local PanelManager = w.rt:require(w.Client.PanelManager)
		local idleListeners = frameListeners(w.rt)
		local function cycle()
			MenuUI.Open()
			w.rt:advance(0.5)
			expect(MenuUI.IsOpen()).toBe(true)
			MenuUI.Close()
			w.rt:advance(0.5)
			ShopUI.Open("Hat")
			w.rt:advance(1)
			local shop = PanelManager.Top()
			expect(shop).toBeTruthy()
			-- (an open panel animates: its loops run only now)
			expect(frameListeners(w.rt)).toBeGreaterThan(idleListeners)
			PanelManager.CloseAll()
			w.rt:advance(0.5)
			expect(shop.Visible).toBe(false)
			CrateUI.Open()
			w.rt:advance(1)
			local crates = PanelManager.Top()
			expect(crates).toBeTruthy()
			expect(crates).never.toBe(shop)
			expect(frameListeners(w.rt)).toBeGreaterThan(idleListeners)
			PanelManager.CloseAll()
			w.rt:advance(1)
			expect(frameListeners(w.rt)).toBe(idleListeners)
		end
		-- The first open builds each panel's contents: measure from the second.
		cycle()
		w.rt:advance(2)
		local instances0, connections0 = count(w.rt), liveConnections(w.rt)
		local listeners0 = frameListeners(w.rt)
		for _ = 1, 20 do
			cycle()
		end
		w.rt:advance(2)
		local instances, connections = count(w.rt), liveConnections(w.rt)
		T.note(
			("instances %d -> %d, live connections %d -> %d, per-frame callbacks %d -> %d"):format(
				instances0,
				instances,
				connections0,
				connections,
				listeners0,
				frameListeners(w.rt)
			)
		)
		expect(#w.rt.errors).toBe(0)
		expect(instances).toBeLessThanOrEqual(instances0 + 5)
		expect(connections).toBeLessThanOrEqual(connections0 + 5)
		expect(frameListeners(w.rt)).toBeLessThanOrEqual(listeners0)
		-- Closed panels don't keep anything running every frame.
		local s = measure(w.rt, 2)
		T.note(describeStats("after the panels closed", s))
		expect(s.busy).toBe(0)
	end)
end)

describe("MapLife round setup and teardown", function()
	it("cleans up after each of several King Hunt rounds", function()
		local rt = Runtime.new({ client = true })
		local env = rt.env
		local player = rt.game:GetService("Players").LocalPlayer
		local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
		Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(1600, 900))
		local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
		rt:require(Client.Layout).Mount(gui)
		rt:spawnCharacter(player, env.CFrame.new(0, 3, 4000))
		local MapService = rt:require("ServerScriptService.Server.Services.MapService")
		local PumpkinService = rt:require("ServerScriptService.Server.Services.PumpkinService")
		local MapLife = rt:require(Client.MapLife)
		local CS = rt.game:GetService("CollectionService")
		local camera = rt.workspace.CurrentCamera
		camera.CFrame = env.CFrame.new(0, 500, 9000)
		MapLife.Mount(gui)
		rt:advance(1)
		local fx = rt.workspace:FindFirstChild("MapLifeFx")
		local baseInstances, baseConnections = count(rt), liveConnections(rt)
		local lobby = measure(rt, 2)
		T.note(describeStats("MapLife in the lobby", lobby))
		expect(lobby.busy).toBe(0)
		local roundStats
		for round = 1, 4 do
			local map = MapService.Load("PumpkinPatch")
			PumpkinService.Begin(map, "Easy", function()
				return true
			end)
			local pickups = CS:GetTagged("PumpkinPickup")
			expect(#pickups).toBeGreaterThan(5)
			local at = pickups[1].Position
			camera.CFrame = env.CFrame.new(at + env.Vector3.new(0, 6, 12), at)
			player.Character.HumanoidRootPart.CFrame =
				env.CFrame.new(at + env.Vector3.new(0, 0, 30))
			rt:advance(0.5)
			if round == 1 then
				roundStats = measure(rt, 3)
				T.note(describeStats("MapLife on the map", roundStats))
			else
				rt:advance(3)
			end
			expect(#fx:GetChildren()).toBeGreaterThan(0)
			PumpkinService.Stop()
			MapService.Unload()
			camera.CFrame = env.CFrame.new(0, 500, 9000)
			rt:advance(2)
			expect(#fx:GetChildren()).toBe(0)
		end
		local after = measure(rt, 2)
		T.note(
			("instances %d -> %d, live connections %d -> %d"):format(
				baseInstances,
				count(rt),
				baseConnections,
				liveConnections(rt)
			)
		)
		expect(after.busy).toBe(0)
		expect(count(rt)).toBeLessThanOrEqual(baseInstances + 2)
		expect(liveConnections(rt)).toBeLessThanOrEqual(baseConnections + 2)
		expect(#rt.errors).toBe(0)
	end)
end)
