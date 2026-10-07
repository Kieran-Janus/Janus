-- CrateIdle (src/client/CrateIdle.luau): the crates on the lobby stand bob, peek their lids,
-- glow, follow you with their eyes and wake up when you walk over, only near the camera.
-- Each test builds the crate stand straight into a client runtime and mounts CrateIdle.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

type World = { [string]: any }

-- A client with the crate stand built, a screen (phone = a 640 x 302 touch screen) and the
-- camera looking at `focus` (a crate Id) from a few studs away.
local function world(opts: { phone: boolean?, setup: ((w: World) -> ())? }?): World
	local o = opts or {}
	local rt = Runtime.new({ client = true })
	local env = rt.env
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Features.Crates = true
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
	local stand = HubBuilder.BuildSection(hub, "CrateStand")
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
		stand = stand,
		player = player,
		gui = gui,
		CS = rt.game:GetService("CollectionService"),
		Tags = rt:require("ReplicatedStorage.Shared.Tags"),
	}
	function w.display(id: string)
		return stand:FindFirstChild(id .. "Display")
	end
	function w.crate(id: string)
		return w.display(id):FindFirstChild(id)
	end
	function w.lookAt(id: string, distance: number?)
		local p = w.crate(id):GetPivot().Position
		rt.workspace.CurrentCamera.CFrame =
			env.CFrame.new(p + env.Vector3.new(0, 3, distance or 8), p)
	end
	function w.mount()
		rt:require(Client.CrateIdle).Mount(gui)
	end
	if o.setup then
		o.setup(w)
	end
	return w
end

local function samePlace(a: any, b: any): boolean
	return (a.Position - b.Position).Magnitude < 1e-4
		and (a.LookVector - b.LookVector).Magnitude < 1e-4
		and (a.UpVector - b.UpVector).Magnitude < 1e-4
end

describe("CrateIdle", function()
	it("mounts with the stand built and puts a glow under each crate near the camera", function()
		local w = world()
		w.lookAt("PumpkinCrate")
		w.mount()
		w.rt:advance(1)
		expect(#w.rt.errors).toBe(0)
		local fx = w.rt.workspace:FindFirstChild("CrateIdleFx")
		expect(fx).toBeTruthy()
		local glow = nil
		for _, part in fx:GetChildren() do
			if part:GetAttribute("CrateId") == "PumpkinCrate" then
				glow = part
			end
		end
		expect(glow).toBeTruthy()
		expect(glow.CanCollide).toBe(false)
		expect(glow.CanQuery).toBe(false)
		expect(glow.Transparency).toBeNear(w.Config.Crates.Idle.GlowRingTransparency)
		-- under the crate
		local cratePos = w.crate("PumpkinCrate"):GetPivot().Position
		expect(glow.Position.Y).toBeLessThan(cratePos.Y + 0.01)
		expect(math.abs(glow.Position.X - cratePos.X)).toBeLessThan(1)
	end)

	it("bobs a crate near the camera and leaves one far away alone", function()
		local w = world()
		-- Carry the Candy Crate's whole display far off (moved in Studio: still found by tag).
		local far = w.display("CandyCrate")
		far:PivotTo(far:GetPivot() + w.env.Vector3.new(600, 0, 0))
		w.lookAt("PumpkinCrate")
		local near0 = w.crate("PumpkinCrate"):GetPivot()
		local far0 = w.crate("CandyCrate"):GetPivot()
		w.mount()
		local moved = 0
		for _ = 1, 30 do
			w.rt:advance(0.1)
			moved = math.max(
				moved,
				(w.crate("PumpkinCrate"):GetPivot().Position - near0.Position).Magnitude
			)
			expect(samePlace(w.crate("CandyCrate"):GetPivot(), far0)).toBe(true)
		end
		expect(moved).toBeGreaterThan(0.02)
		expect(moved).toBeLessThan(w.Config.Crates.LookDefaults.Bob + 0.2)
		-- Out of range again: straight back to where the server put it.
		w.rt.workspace.CurrentCamera.CFrame = w.env.CFrame.new(0, 500, 5000)
		w.rt:advance(0.1)
		expect(samePlace(w.crate("PumpkinCrate"):GetPivot(), near0)).toBe(true)
	end)

	it("peeks the lid open with light and sparkles, then shuts it exactly", function()
		local w = world()
		w.lookAt("PumpkinCrate")
		local model = w.crate("PumpkinCrate")
		local lid = model:FindFirstChild("Lid", true)
		expect(lid).toBeTruthy()
		local rest = model:GetPivot():ToObjectSpace(lid.CFrame)
		local base = model:GetPivot()
		w.mount()
		local opened, shutAgain = 0, false
		local lightSeen = false
		local fx = w.rt.workspace:WaitForChild("CrateIdleFx")
		for _ = 1, 200 do
			w.rt:advance(0.05)
			local now = model:GetPivot():ToObjectSpace(lid.CFrame)
			local off = (now.Position - rest.Position).Magnitude
				+ (now.LookVector - rest.LookVector).Magnitude
			if off > 0.05 then
				opened = math.max(opened, off)
			elseif opened > 0 and off < 1e-4 then
				shutAgain = true
			end
			for _, glow in fx:GetChildren() do
				if glow:GetAttribute("CrateId") == "PumpkinCrate" then
					local light = glow.Puff:FindFirstChildOfClass("PointLight")
					if light.Enabled and light.Brightness > 0 then
						lightSeen = true
					end
				end
			end
			if shutAgain then
				break
			end
		end
		expect(opened).toBeGreaterThan(0.1)
		expect(shutAgain).toBe(true)
		expect(lightSeen).toBe(true)
		local emits = w.rt:calls("ParticleEmitter", "Emit")
		expect(#emits).toBeGreaterThan(0)
		expect(emits[1].args[1]).toBe(w.Config.Crates.LookDefaults.Sparkles)
		-- Leaving range: the crate and its lid are exactly where they started.
		w.rt.workspace.CurrentCamera.CFrame = w.env.CFrame.new(0, 500, 5000)
		w.rt:advance(0.1)
		expect(samePlace(model:GetPivot(), base)).toBe(true)
		expect(samePlace(base:ToObjectSpace(lid.CFrame), rest)).toBe(true)
	end)

	it("only bobs a custom crate model without a Lid", function()
		local w = world({
			setup = function(w: World)
				local display = w.display("PumpkinCrate")
				local old = w.crate("PumpkinCrate")
				local pivot = old:GetPivot()
				old:Destroy()
				local custom = w.rt:create("Model", { Name = "PumpkinCrate" }, display)
				local box = w.rt:create("Part", {
					Name = "Box",
					Anchored = true,
					Size = w.env.Vector3.new(2, 2, 2),
					CFrame = pivot * w.env.CFrame.new(0, 1, 0),
				}, custom)
				custom.PrimaryPart = box
			end,
		})
		w.lookAt("PumpkinCrate")
		local model = w.crate("PumpkinCrate")
		local base = model:GetPivot()
		w.mount()
		local moved = 0
		for _ = 1, 120 do
			w.rt:advance(0.1)
			moved = math.max(moved, (model:GetPivot().Position - base.Position).Magnitude)
		end
		expect(moved).toBeGreaterThan(0.02)
		expect(#model:GetChildren()).toBe(1) -- nothing added to your model
		for _, call in w.rt:calls("ParticleEmitter", "Emit") do
			expect(call.instance.Parent.Parent:GetAttribute("CrateId")).never.toBe("PumpkinCrate")
		end
		expect(#w.rt.errors).toBe(0)
	end)

	it("moves the Monster crate's pupils towards the nearest player", function()
		-- (the built Monster crate has its own Eye and Pupil parts: src/shared/CrateArt.luau)
		local w = world()
		w.lookAt("MonsterCrate")
		local model = w.crate("MonsterCrate")
		local eye = model:FindFirstChild("Eye")
		local pupil = model:FindFirstChild("Pupil")
		local rest = eye.CFrame:ToObjectSpace(pupil.CFrame)
		-- A player off to the crate's left, a few studs away.
		local spot = model:GetPivot() * w.env.CFrame.new(8, 1, -6)
		w.rt:spawnCharacter(w.player, spot)
		w.mount()
		w.rt:advance(2)
		local now = eye.CFrame:ToObjectSpace(pupil.CFrame)
		local shift = now.Position - rest.Position
		expect(shift.Magnitude).toBeGreaterThan(0.05)
		expect(shift.Magnitude).toBeLessThan(pupil:GetAttribute("EyeRadius") + 1e-3) -- never out of its eye
		-- towards the player (the eye's +X is the crate's +X side)
		expect(shift.X).toBeGreaterThan(0)
	end)

	it("wakes up when you walk close: name, price and an Odds button", function()
		local w = world()
		w.lookAt("PumpkinCrate")
		local holder = w.display("PumpkinCrate").CratePrompt
		w.rt:spawnCharacter(w.player, w.env.CFrame.new(0, 3, 4000))
		w.mount()
		w.rt:advance(0.5)
		local function label()
			for _, child in w.player.PlayerGui:GetChildren() do
				if
					child:IsA("BillboardGui")
					and child:GetAttribute("CrateId") == "PumpkinCrate"
				then
					return child
				end
			end
			return nil
		end
		expect(label()).toBeNil()
		local model = w.crate("PumpkinCrate")
		local base = model:GetPivot()
		local root = w.player.Character.HumanoidRootPart
		root.CFrame = base * w.env.CFrame.new(0, 2, -5)
		w.rt:advance(0.15)
		-- the happy wiggle hops it up
		expect((model:GetPivot().Position - base.Position).Magnitude).toBeGreaterThan(0.1)
		w.rt:advance(0.5)
		local board = label()
		expect(board).toBeTruthy()
		expect(board.Enabled).toBe(true)
		expect(board.Active).toBe(true)
		expect(board.Adornee).toBe(holder)
		local minText = w.Config.UI.MinTextSize
		local name = board:FindFirstChild("CrateName", true)
		local price = board:FindFirstChild("Price", true)
		local odds = board:FindFirstChild("Odds", true)
		expect(name.Text).toBe("Pumpkin Crate")
		expect(price.Text).toBe("600 " .. w.Config.Economy.CurrencyName)
		expect(price.Text:find("R%$")).toBeNil() -- no Robux product set up: no Robux price
		expect(odds.Text).toBe(w.Config.Crates.Idle.LabelOdds)
		-- Only the nearest crate shows a label, even with others awake close by.
		local shown = 0
		for _, child in w.player.PlayerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Name == "CrateIdleLabel" and child.Enabled then
				shown += 1
			end
		end
		expect(shown).toBe(1)
		for _, t in { name, price, odds } do
			expect(t.TextSize).toBeGreaterThanOrEqual(minText)
		end
		-- Odds opens the crate panel on this crate.
		local CrateUI = w.rt:require(w.Client.CrateUI)
		local opened = nil
		CrateUI.Open = function(id)
			opened = id
		end
		w.rt:fire(odds, "Activated")
		expect(opened).toBe("PumpkinCrate")
		-- Walking away hides it.
		root.CFrame = w.env.CFrame.new(0, 3, 4000)
		w.rt:advance(0.2)
		expect(board.Enabled).toBe(false)
		expect(#w.rt.errors).toBe(0)
	end)

	it("emits fewer sparkles on phones", function()
		local function firstEmit(phone: boolean): number
			local w = world({ phone = phone })
			w.lookAt("PumpkinCrate")
			w.mount()
			w.rt:advance(12)
			local emits = w.rt:calls("ParticleEmitter", "Emit")
			expect(#emits).toBeGreaterThan(0)
			return emits[1].args[1]
		end
		local pc = firstEmit(false)
		local phone = firstEmit(true)
		expect(phone).toBeLessThan(pc)
		local cfg = Runtime.new():require("ReplicatedStorage.Shared.Config").Crates
		expect(phone).toBe(math.floor(cfg.LookDefaults.Sparkles * cfg.Idle.PhoneSparkleShare + 0.5))
	end)

	it("does nothing when crates or Idle are switched off", function()
		for _, flag in { "Crates", "Idle" } do
			local w = world()
			if flag == "Crates" then
				w.Config.Features.Crates = false
			else
				w.Config.Crates.Idle.On = false
			end
			w.lookAt("PumpkinCrate")
			local base = w.crate("PumpkinCrate"):GetPivot()
			w.mount()
			w.rt:advance(10)
			expect(samePlace(w.crate("PumpkinCrate"):GetPivot(), base)).toBe(true)
			expect(w.rt.workspace:FindFirstChild("CrateIdleFx")).toBeNil()
			expect(#w.rt:calls("ParticleEmitter", "Emit")).toBe(0)
		end
	end)
end)

describe("HubAmbience and the crate stand", function()
	it("the stand no longer tags its crates to float while Idle is on", function()
		local w = world()
		expect(w.CS:HasTag(w.crate("PumpkinCrate"), "HubFloat")).toBe(false)
	end)

	it("doesn't float stand crates in a saved lobby that still has the HubFloat tag", function()
		local w = world()
		local crate = w.crate("PumpkinCrate")
		crate:SetAttribute("BobHeight", 0.35)
		crate:SetAttribute("Phase", 1)
		w.CS:AddTag(crate, "HubFloat")
		-- an ordinary floating lantern still bobs
		local lantern = w.rt:create("Model", { Name = "Lantern" }, w.rt.workspace)
		local part = w.rt:create("Part", {
			Anchored = true,
			CFrame = crate:GetPivot() * w.env.CFrame.new(10, 0, 0),
		}, lantern)
		lantern.PrimaryPart = part
		lantern:SetAttribute("BobHeight", 0.5)
		w.CS:AddTag(lantern, "HubFloat")
		w.lookAt("PumpkinCrate")
		local crate0 = crate:GetPivot()
		local lantern0 = lantern:GetPivot()
		w.rt:require(w.Client.HubAmbience).Mount()
		local lanternMoved = 0
		for _ = 1, 20 do
			w.rt:advance(0.1)
			expect(samePlace(crate:GetPivot(), crate0)).toBe(true)
			lanternMoved =
				math.max(lanternMoved, (lantern:GetPivot().Position - lantern0.Position).Magnitude)
		end
		expect(lanternMoved).toBeGreaterThan(0.05)
	end)

	it("still floats them the old way with Idle off", function()
		local w = world({
			setup = function(w: World)
				w.Config.Crates.Idle.On = false
			end,
		})
		-- (built with Idle on above: tag it the way an Idle-off build does)
		local crate = w.crate("PumpkinCrate")
		crate:SetAttribute("BobHeight", 0.35)
		w.CS:AddTag(crate, "HubFloat")
		w.lookAt("PumpkinCrate")
		local crate0 = crate:GetPivot()
		w.rt:require(w.Client.HubAmbience).Mount()
		w.rt:advance(1)
		expect((crate:GetPivot().Position - crate0.Position).Magnitude).toBeGreaterThan(0.01)
	end)
end)
