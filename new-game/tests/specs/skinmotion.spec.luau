-- Walk styles (Style.Motion, src/shared/SkinMotion.luau): every preset poses R15 and R6 joints
-- with finite turns, Normalize accepts presets and animation ids and refuses everything else,
-- the server sets and clears the character attributes, and the client SkinWalk (Add mode on
-- top of Roblox's walk without building up, Set mode, who gets a walk style, your own float
-- capped, your own uploaded walk / run / idle animations, hiders).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
local SkinMotion = rt:require("ReplicatedStorage.Shared.SkinMotion")
local DanceMoves = rt:require("ReplicatedStorage.Shared.DanceMoves")

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

local function finite(cf: any): boolean
	for _, n in { cf:GetComponents() } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

describe("SkinMotion: presets and checking", function()
	it("has Config numbers, a label and help for every walk style", function()
		expect(#SkinMotion.Names).toBe(8)
		for _, info in SkinMotion.Info do
			expect(Config.SkinMotion.Presets[info.Name]).toBeTruthy()
			expect(#info.Help).toBeGreaterThan(10)
			expect(SkinMotion.Has(info.Name)).toBe(true)
		end
		for name in Config.SkinMotion.Presets do
			expect(SkinMotion.Has(name)).toBe(true)
		end
		expect(Config.Features.WalkStyles).toBe(true)
	end)

	it("poses every joint with finite turns that move, standing and walking", function()
		for _, name in SkinMotion.Names do
			local moved = false
			for _, move in { 0, 0.5, 1 } do
				local a = SkinMotion.Pose(name, 1000.3, move)
				local b = SkinMotion.Pose(name, 1000.9, move)
				for joint, pose in a do
					expect(table.find(JOINTS, joint)).toBeTruthy()
					expect(pose.Mode == "Set" or pose.Mode == "Add").toBe(true)
					expect(finite(pose.Turn)).toBe(true)
					expect(pose.Turn.Position.Magnitude).toBeLessThan(1.5)
					if joint ~= "Root" then
						expect(pose.Turn.Position.Magnitude).toBe(0) -- only the root shifts
					end
					local other = b[joint]
					local gap = if other
						then (other.Turn.Position - pose.Turn.Position).Magnitude + (
							other.Turn.LookVector - pose.Turn.LookVector
						).Magnitude + (other.Turn.UpVector - pose.Turn.UpVector).Magnitude
						else 0
					if gap > 1e-4 then
						moved = true
					end
				end
			end
			if not moved then
				error(name .. " never moves")
			end
		end
		expect(next(SkinMotion.Pose("NoSuchWalk", 1, 1))).toBeNil()
	end)

	it("accepts presets and animation ids, and refuses everything else", function()
		local m = SkinMotion.Normalize("Zombie")
		expect(m).toEqual({ Preset = "Zombie" })
		m = SkinMotion.Normalize({ Walk = 123, Run = "456", Idle = "rbxassetid://789" })
		expect(m).toEqual({
			Walk = "rbxassetid://123",
			Run = "rbxassetid://456",
			Idle = "rbxassetid://789",
		})
		m = SkinMotion.Normalize({ Preset = "Ghost", Idle = 789 })
		expect(m).toEqual({ Preset = "Ghost", Idle = "rbxassetid://789" })
		expect((SkinMotion.Normalize(nil))).toBeNil()
		for _, bad in
			{
				"Moonwalk",
				42,
				true,
				{},
				{ Preset = "Moonwalk" },
				{ Preset = "Ghost", Jump = 1 },
				{ Walk = 0 },
				{ Walk = -5 },
				{ Walk = 1.5 },
				{ Walk = 0 / 0 },
				{ Walk = math.huge },
				{ Walk = -math.huge },
				{ Walk = "abc" },
				{ Walk = "rbxassetid://" },
				{ Walk = "rbxassetid://12a" },
				{ Walk = "http://evil/123" },
				{ Walk = string.rep("9", 21) },
				{ Walk = { 1 } },
			}
		do
			local motion, errors = SkinMotion.Normalize(bad)
			expect(motion).toBeNil()
			expect(#errors).toBe(1)
		end
	end)

	it("writes and reads the ids attribute", function()
		local m = SkinMotion.Normalize({ Preset = "Bat", Walk = 11, Idle = 33 })
		local text = SkinMotion.IdsText(m)
		expect(text).toBe("Walk=11;Idle=33")
		expect(SkinMotion.ParseIds(text)).toEqual({
			Walk = "rbxassetid://11",
			Idle = "rbxassetid://33",
		})
		expect(SkinMotion.IdsText({ Preset = "Bat" })).toBeNil()
		expect(SkinMotion.ParseIds(42)).toEqual({})
		expect(SkinMotion.ParseIds("Jump=5;Walk=x")).toEqual({})
	end)

	it("only gives walk styles to Rare and CRAZY catalogue skins, all of them valid", function()
		for _, item in rt:require("ReplicatedStorage.Shared.Items").ForSlot("Skin") do
			local motion = item.Style.Motion
			if motion ~= nil then
				local _, errors = SkinMotion.Normalize(motion)
				if #errors > 0 then
					error(item.Id .. ": " .. table.concat(errors, "; "))
				end
				expect(item.Rarity == "Rare" or item.Rarity == "Crazy").toBe(true)
			end
		end
		local _ = DanceMoves
	end)
end)

-- Server: the character attributes ---------------------------------------------------------------

describe("Walk styles on the server (Cosmetics)", function()
	it(
		"sets SkinMotion / SkinMotionIds when a skin goes on and clears them when it comes off",
		function()
			local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
			local player = rt:addPlayer({ Name = "Strider" })
			local character = player.Character
			local item = {
				Id = "Test_Strider",
				Slot = "Skin",
				Rarity = "Rare",
				Style = {
					Kind = "Skin",
					BodyColor = rt.env.Color3.new(1, 0, 0),
					Motion = { Preset = "Zombie", Run = 99 },
				},
			}
			Cosmetics.Wear(character, item)
			expect(character:GetAttribute("SkinMotion")).toBe("Zombie")
			expect(character:GetAttribute("SkinMotionIds")).toBe("Run=99")
			-- another skin without a walk style clears them
			Cosmetics.Wear(
				character,
				rt:require("ReplicatedStorage.Shared.Items").Get("Pumpkin_PumpkinSpice")
			)
			expect(character:GetAttribute("SkinMotion")).toBeNil()
			Cosmetics.Wear(character, item)
			Cosmetics.TakeOff(character, "Skin")
			expect(character:GetAttribute("SkinMotion")).toBeNil()
			expect(character:GetAttribute("SkinMotionIds")).toBeNil()
		end
	)
end)

-- Client (src/client/SkinWalk.luau) -----------------------------------------------------------------

local Dom = require("../harness/Dom")
local CFrame = rt.env.CFrame

type Client = { rt: any, env: any, Config: any, SkinWalk: any, gui: any, me: any }

local function client(opts: { phone: boolean?, mount: boolean?, studio: boolean? }?): Client
	local o = opts or {}
	local c = Runtime.new({ client = true, studio = o.studio })
	local cenv = c.env
	local player = c.game:GetService("Players").LocalPlayer
	local gui = c:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	local Client = c:find("StarterPlayer.StarterPlayerScripts.Client")
	if o.phone then
		gui:SetAttribute("ForceTouch", true)
		Dom.rawSet(gui, "AbsoluteSize", cenv.Vector2.new(640, 302))
	end
	c:require(Client.Layout).Mount(gui)
	c.workspace.CurrentCamera.CFrame =
		cenv.CFrame.lookAt(cenv.Vector3.new(0, 5, -30), cenv.Vector3.new(0, 3, 0))
	local SkinWalk = c:require(Client.SkinWalk)
	if o.mount ~= false then
		SkinWalk.Mount(gui)
	end
	return {
		rt = c,
		env = cenv,
		Config = c:require("ReplicatedStorage.Shared.Config"),
		SkinWalk = SkinWalk,
		gui = gui,
		me = player,
	}
end

local R15_JOINTS = {
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

-- A rig with a root, a Humanoid + Animator and the Motor6Ds DanceMoves knows (R6 C0s turned
-- like Roblox's), standing at (x, 3, z), for `player` (a new one when nil).
local function rigFor(
	c: Client,
	name: string,
	kind: string,
	x: number,
	z: number,
	player: any?
): (any, any)
	local CF, V3 = c.env.CFrame, c.env.Vector3
	local m = c.rt:create("Model", { Name = name })
	local root = c.rt:create(
		"Part",
		{ Name = "HumanoidRootPart", Size = V3.new(2, 2, 1), CFrame = CF.new(x, 3, z) },
		m
	)
	m.PrimaryPart = root
	local humanoid = c.rt:create("Humanoid", {}, m)
	humanoid.RigType = if kind == "R6"
		then c.env.Enum.HumanoidRigType.R6
		else c.env.Enum.HumanoidRigType.R15
	c.rt:create("Animator", {}, humanoid)
	local function motor(partName: string, jointName: string, c0: any)
		local p = m:FindFirstChild(partName)
			or c.rt:create("Part", { Name = partName, Size = V3.one, CFrame = CF.new(x, 3, z) }, m)
		c.rt:create("Motor6D", { Name = jointName, C0 = c0 }, p)
	end
	if kind == "R6" then
		motor("HumanoidRootPart", "RootJoint", CF.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
		motor("Torso", "Neck", CF.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
		motor("Torso", "Left Shoulder", CF.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
		motor("Torso", "Right Shoulder", CF.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
		motor("Torso", "Left Hip", CF.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
		motor("Torso", "Right Hip", CF.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	else
		for _, w in R15_JOINTS do
			motor(w[1], w[2], CF.new(0, 0.5, 0))
		end
	end
	local p = player or c.rt:addPlayer({ Name = name .. "Player", character = false })
	m.Parent = c.rt.workspace
	p.Character = m
	return p, m
end

local function joint(m: any, name: string): any
	local where = R15_JOINTS[name]
	return m[where[1]][where[2]]
end

local function anyPosed(m: any): boolean
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and d.Transform ~= CFrame.identity then
			return true
		end
	end
	return false
end

-- Animator.EvaluationThrottled for the tests: a runtime's `throttled` (true / false), or a
-- "not a valid member" error like older Roblox clients (and the harness) give when unset.
-- Animator:LoadAnimation also keeps the tracks it makes in the runtime's `loadedTracks`.
-- Humanoid:GetState can be made to fail for other players' characters (`getStateTrap`).
-- ContentProvider:PreloadAsync answers through the runtime's `preloadStatus(contentId)`
-- (an Enum.AssetFetchStatus, or nil = no answer, like a download still going).
local LuneEnum = require("@lune/roblox").Enum
Dom.define("ContentProvider", {
	PreloadAsync = function(self, list, callback)
		local d = Dom.data(self)
		local answer = d.world.preloadStatus
		if not answer or type(callback) ~= "function" then
			return
		end
		for _, thing in list do
			local id = if type(thing) == "string" then thing else thing.AnimationId
			local status = answer(id)
			if status then
				callback(id, status)
			end
		end
	end,
})
Dom.define("Animator", {
	EvaluationThrottled = {
		get = function(_, d)
			local value = d.world.throttled
			if value == nil then
				error("EvaluationThrottled is not a valid member of Animator")
			end
			return value
		end,
	},
	LoadAnimation = function(self, animation)
		local d = Dom.data(self)
		local track = Dom.new(d.world, "AnimationTrack", true)
		Dom.rawSet(track, "Animation", animation)
		local log = d.world.loadedTracks
		if log then
			table.insert(log, track)
		end
		return track
	end,
})
Dom.define("Humanoid", {
	GetState = function(self)
		local d = Dom.data(self)
		local trap = d.world.getStateTrap
		if trap then
			trap(self)
		end
		return d.props.__State
			or (
				if (d.props.Health or Dom.get(self, "MaxHealth")) <= 0
					then LuneEnum.HumanoidStateType.Dead
					else LuneEnum.HumanoidStateType.Running
			)
	end,
})

describe("SkinWalk (client)", function()
	it("does nothing with the feature off, and never waits", function()
		local c = client({ mount = false })
		c.Config.Features.WalkStyles = false
		c.SkinWalk.Mount(c.gui)
		local _, m = rigFor(c, "Off", "R15", 0, 10)
		m:SetAttribute("SkinMotion", "Zombie")
		c.rt:advance(1)
		expect(anyPosed(m)).toBe(false)
		expect(c.rt.listening.PreSimulation or 0).toBe(0)
		expect(c.SkinWalk.Active()).toBe(0)
	end)

	it("poses R15 and R6 characters with every walk style, and lets go when it ends", function()
		local c = client()
		c.Config.SkinMotion.MaxCharacters = 20 -- (every rig here at once)
		for i, name in SkinMotion.Names do
			for _, kind in { "R15", "R6" } do
				local _, m = rigFor(c, name .. kind, kind, (i % 4) * 4 - 6, 10 + i)
				m:SetAttribute("SkinMotion", name)
			end
		end
		c.rt:advance(1)
		for _, d in c.rt.workspace:GetChildren() do
			if d:GetAttribute("SkinMotion") then
				if not anyPosed(d) then
					error(d.Name .. " isn't posed")
				end
				for _, j in d:GetDescendants() do
					if j:IsA("Motor6D") then
						expect(finite(j.Transform)).toBe(true)
					end
				end
				d:SetAttribute("SkinMotion", nil)
			end
		end
		c.rt:advance(1)
		for _, d in c.rt.workspace:GetChildren() do
			if
				d:IsA("Model")
				and d:FindFirstChildOfClass("Humanoid")
				and d.Name ~= "LocalPlayer"
			then
				expect(anyPosed(d)).toBe(false)
			end
		end
		expect(c.rt.listening.PreSimulation or 0).toBe(0) -- nothing left to do: no frame loop
	end)

	it("adds on top of Roblox's walk without building up, every frame", function()
		-- `throttled`: nil = this Roblox can't say (the fallback guess), else EvaluationThrottled
		local function proud(throttled: boolean?): (any, any, (number) -> any)
			local c = client()
			c.rt.throttled = throttled
			local _, m = rigFor(c, "Proud", "R15", 0, 10)
			m:SetAttribute("SkinMotion", "Proud") -- every joint in Add mode
			local waist = joint(m, "Waist")
			local DanceMovesC = c.rt:require("ReplicatedStorage.Shared.DanceMoves")
			local SkinMotionC = c.rt:require("ReplicatedStorage.Shared.SkinMotion")
			local function pose(): any
				local t = c.rt.workspace:GetServerTimeNow()
				return DanceMovesC.Local(waist, SkinMotionC.Pose("Proud", t, 0).Waist.Turn)
			end
			return c, waist, pose
		end
		-- The fallback guess. 1: nobody else writes the joint: it holds exactly the pose.
		local c, waist, pose = proud(nil)
		c.rt:advance(1) -- (faded in)
		for _ = 1, 30 do
			c.rt:advance(1 / 60)
		end
		expect(waist.Transform).toBeNear(pose(), 1e-4)
		-- 2: "Roblox's walk" writes a new pose every frame: ours goes on top of it
		local walk = CFrame.Angles(0.3, 0, 0)
		for _ = 1, 10 do
			waist.Transform = walk
			c.rt:advance(1 / 60)
			expect(waist.Transform).toBeNear(walk * pose(), 1e-4)
		end
		-- EvaluationThrottled readable: false = the joint holds Roblox's fresh pose this frame
		c, waist, pose = proud(false)
		c.rt:advance(1)
		for _ = 1, 10 do
			waist.Transform = walk
			c.rt:advance(1 / 60)
			expect(waist.Transform).toBeNear(walk * pose(), 1e-4)
		end
		-- true = Roblox skipped this frame: the base stays last frame's, whatever the joint holds
		c.rt.throttled = true
		for _ = 1, 5 do
			waist.Transform = CFrame.Angles(-1, 0, 0)
			c.rt:advance(1 / 60)
			expect(waist.Transform).toBeNear(walk * pose(), 1e-4)
		end
	end)

	it("writes every frame far away too, and Set mode replaces the walk", function()
		local c = client()
		local cfg = c.Config.SkinMotion
		local _, m = rigFor(c, "FarZombie", "R15", 0, cfg.HalfRateDistance + 15)
		m:SetAttribute("SkinMotion", "Zombie")
		c.rt:advance(1)
		local shoulder = joint(m, "RightShoulder")
		local DanceMovesC = c.rt:require("ReplicatedStorage.Shared.DanceMoves")
		local SkinMotionC = c.rt:require("ReplicatedStorage.Shared.SkinMotion")
		for _ = 1, 10 do
			shoulder.Transform = CFrame.Angles(-1, 0, 0) -- Roblox's arm swing
			c.rt:advance(1 / 60)
			expect(shoulder.Transform ~= CFrame.Angles(-1, 0, 0)).toBe(true)
			-- Set: the arm is where the zombie pose puts it (maths at half rate: last or this frame)
			local t = c.rt.workspace:GetServerTimeNow()
			local now =
				DanceMovesC.Local(shoulder, SkinMotionC.Pose("Zombie", t, 0).RightShoulder.Turn)
			local before = DanceMovesC.Local(
				shoulder,
				SkinMotionC.Pose("Zombie", t - 1 / 60, 0).RightShoulder.Turn
			)
			local gap = math.min(
				(shoulder.Transform.LookVector - now.LookVector).Magnitude,
				(shoulder.Transform.LookVector - before.LookVector).Magnitude
			)
			expect(gap).toBeLessThan(1e-4)
		end
	end)

	it("skips dancers, hiders, the seated, the dead and characters out of budget", function()
		for _, onPhone in { false, true } do
			local c = client({ phone = onPhone })
			local cfg = c.Config.SkinMotion
			local rigs = {}
			for i = 1, 14 do
				local p, m = rigFor(c, "Walker" .. i, "R15", 0, 4 + i * 4)
				m:SetAttribute("SkinMotion", "Robot")
				table.insert(rigs, { Player = p, Model = m })
			end
			c.rt:advance(1)
			local limit = if onPhone then cfg.PhoneMaxCharacters else cfg.MaxCharacters
			expect(c.SkinWalk.Active()).toBe(limit)
			for i, r in rigs do
				expect(anyPosed(r.Model)).toBe(i <= limit)
			end
			-- the closest four stop for their own reasons; the next ones take their places
			rigs[1].Model:SetAttribute("Dance", "ZombieShuffle")
			rigs[2].Player:SetAttribute("HideSeekRole", "Hider")
			rigs[3].Model:FindFirstChildOfClass("Humanoid").Sit = true
			rigs[4].Model:FindFirstChildOfClass("Humanoid").Health = 0
			c.rt:flush()
			expect(anyPosed(rigs[2].Model)).toBe(false) -- a hider stops at once
			c.rt:advance(1)
			for i = 1, 4 do
				if i ~= 1 then -- (the dance itself would move the dancer's joints)
					expect(anyPosed(rigs[i].Model)).toBe(false)
				end
			end
			expect(c.SkinWalk.Active()).toBe(math.min(limit, #rigs - 4))
		end
	end)

	it(
		"never asks other players' Humanoids for their state, and fades them out in the air",
		function()
			local c = client()
			local _, m = rigFor(c, "Jumper", "R15", 0, 10)
			local mine = c.me.Character
			c.rt.getStateTrap = function(humanoid)
				if not humanoid:IsDescendantOf(mine) then
					error("GetState called for another player's character")
				end
			end
			m:SetAttribute("SkinMotion", "Zombie")
			c.rt:advance(1)
			expect(anyPosed(m)).toBe(true)
			m.HumanoidRootPart.AssemblyLinearVelocity = c.env.Vector3.new(0, 40, 0) -- jumping
			c.rt:advance(c.Config.SkinMotion.FadeSeconds + 0.1)
			expect(anyPosed(m)).toBe(false)
			m.HumanoidRootPart.AssemblyLinearVelocity = c.env.Vector3.zero -- landed
			c.rt:advance(c.Config.SkinMotion.FadeSeconds + 0.1)
			expect(anyPosed(m)).toBe(true)
			c.rt.getStateTrap = nil
			expect(#c.rt.errors).toBe(0)
		end
	)

	it("keeps your own float and hop under OwnRootShiftMax (others see the full float)", function()
		local c = client()
		local cfg = c.Config.SkinMotion
		local old = c.me.Character
		local _, mine = rigFor(c, "Me", "R15", 0, 0, c.me)
		old:Destroy()
		local _, other = rigFor(c, "Ghosty", "R15", 3, 10)
		mine:SetAttribute("SkinMotion", "Ghost")
		other:SetAttribute("SkinMotion", "Ghost")
		local mostMine, mostOther = 0, 0
		for _ = 1, 120 do
			c.rt:advance(1 / 30)
			mostMine = math.max(mostMine, joint(mine, "Root").Transform.Position.Magnitude)
			mostOther = math.max(mostOther, joint(other, "Root").Transform.Position.Magnitude)
		end
		expect(mostMine).toBeLessThanOrEqual(cfg.OwnRootShiftMax + 1e-6)
		expect(mostOther).toBeGreaterThan(cfg.Presets.Ghost.Height * 0.8)
	end)

	it("plays your own uploaded walk, run and idle, and stops them when it should", function()
		local c = client({ studio = true })
		local cfg = c.Config.SkinMotion
		c.rt.loadedTracks = {}
		local _, mine = rigFor(c, "MyRig", "R15", 0, 0, c.me)
		local root = mine.HumanoidRootPart
		mine:SetAttribute("SkinMotionIds", "Walk=11;Run=22;Idle=33")
		c.rt:advance(0.2)
		local tracks = {}
		for _, track in c.rt.loadedTracks do
			Dom.rawSet(track, "Length", 1) -- (loaded)
			tracks[string.match(track.Animation.AnimationId, "%d+")] = track
		end
		expect(tracks["11"] and tracks["22"] and tracks["33"]).toBeTruthy()
		expect(tracks["11"].Priority).toBe(c.env.Enum.AnimationPriority.Movement)
		expect(tracks["11"].Looped).toBe(true)
		local function playing(): string
			local list = {}
			for id, track in tracks do
				if track.IsPlaying then
					table.insert(list, id)
				end
			end
			table.sort(list)
			return table.concat(list, ",")
		end
		c.rt:advance(0.1)
		expect(playing()).toBe("33") -- standing still: idle
		root.AssemblyLinearVelocity = c.env.Vector3.new(10, 0, 0)
		c.rt:advance(0.1)
		expect(playing()).toBe("11") -- walking
		root.AssemblyLinearVelocity = c.env.Vector3.new(0, 0, cfg.RunSpeed + 5)
		c.rt:advance(0.1)
		expect(playing()).toBe("22") -- running
		mine:FindFirstChildOfClass("Humanoid"):ChangeState(c.env.Enum.HumanoidStateType.Freefall)
		c.rt:advance(0.1)
		expect(playing()).toBe("") -- in the air: Roblox's own fall shows
		mine:FindFirstChildOfClass("Humanoid"):ChangeState(c.env.Enum.HumanoidStateType.Running)
		c.rt:advance(0.1)
		expect(playing()).toBe("22")
		-- becoming a hider stops them at once, and they don't start again while hiding
		c.me:SetAttribute("HideSeekRole", "Hider")
		c.rt:flush()
		expect(playing()).toBe("")
		local loads = #c.rt.loadedTracks
		c.rt:advance(1)
		expect(#c.rt.loadedTracks).toBe(loads)
		c.me:SetAttribute("HideSeekRole", nil)
		c.rt:advance(0.5)
		expect(#c.rt.loadedTracks).toBe(loads + 3) -- loaded again
		-- the skin comes off: everything stops
		local again = c.rt.loadedTracks
		mine:SetAttribute("SkinMotionIds", nil)
		c.rt:advance(0.2)
		for i = loads + 1, #again do
			expect(again[i].IsPlaying).toBe(false)
		end
		-- an animation that never loads (not the owner's) is skipped after LoadGiveUpSeconds
		-- (not before: a slow download isn't a failure), with one warning in Studio
		local function warningsFor(id: string): number
			local n = 0
			for _, w in c.rt.warnings do
				if string.find(w, "animation " .. id .. " didn't load", 1, true) then
					n += 1
				end
			end
			return n
		end
		root.AssemblyLinearVelocity = c.env.Vector3.new(10, 0, 0)
		mine:SetAttribute("SkinMotionIds", "Walk=44")
		c.rt:advance(cfg.LoadGiveUpSeconds - 1)
		expect(warningsFor("44")).toBe(0)
		local never = c.rt.loadedTracks[#c.rt.loadedTracks]
		expect(never.IsPlaying).toBe(true) -- kept (and asked to play) while it may still download
		c.rt:advance(1.5)
		expect(warningsFor("44")).toBe(1)
		expect(never.IsPlaying).toBe(false)
	end)

	it("waits for slow downloads, and drops at once what Roblox says failed", function()
		local c = client({ studio = true })
		local cfg = c.Config.SkinMotion
		c.rt.loadedTracks = {}
		c.rt.preloadStatus = function(id: string)
			return if string.find(id, "66", 1, true)
				then c.env.Enum.AssetFetchStatus.Failure
				else nil
		end
		local _, mine = rigFor(c, "SlowRig", "R15", 0, 0, c.me)
		local root = mine.HumanoidRootPart
		mine:SetAttribute("SkinMotionIds", "Walk=55;Run=66")
		c.rt:advance(0.2)
		local walk, run
		for _, track in c.rt.loadedTracks do
			local id = string.match(track.Animation.AnimationId, "%d+")
			if id == "55" then
				walk = track
			elseif id == "66" then
				run = track
			end
		end
		expect(walk and run).toBeTruthy()
		-- the run failed (not the owner's): dropped straight away, running uses the walk
		c.rt:advance(0.2)
		local warned = 0
		for _, w in c.rt.warnings do
			if string.find(w, "animation 66 didn't load", 1, true) then
				warned += 1
			end
		end
		expect(warned).toBe(1)
		expect(run.IsPlaying).toBe(false)
		-- the walk is still downloading 10 seconds later (a phone joining): kept, never warned
		c.rt:advance(10)
		for _, w in c.rt.warnings do
			expect(string.find(w, "animation 55", 1, true)).toBeNil()
		end
		Dom.rawSet(walk, "Length", 1) -- now it has loaded
		root.AssemblyLinearVelocity = c.env.Vector3.new(0, 0, cfg.RunSpeed + 5)
		c.rt:advance(0.2)
		expect(walk.IsPlaying).toBe(true) -- running plays the walk (the run failed)
		-- loaded tracks are never given up later
		c.rt:advance(cfg.LoadGiveUpSeconds + 1)
		expect(walk.IsPlaying).toBe(true)
		c.rt.preloadStatus = nil
	end)
end)
