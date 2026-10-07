--!strict
--[[
	Local-only hub (and map) animation, so the server never has to move decorations:
	  "HubFloat" Models bob up and down (attributes BobHeight, Phase). The crates on the
	             crate stand are left alone while Config.Crates.Idle is on: CrateIdle.luau
	             animates them (a lobby saved before that still has the HubFloat tag on them).
	  "HubFlicker" PointLights flicker like candles
	Anything tagged later (the hub may be built after this client starts) is picked up too.
	Cheap on phones (Config.Performance): only things near the camera animate (looked for a
	few times a second, not every frame; closer still on phones), and the
	flicker updates a few times a second rather than every frame.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local FramePace = require(script.Parent.FramePace)
local Layout = require(script.Parent.Layout)

type Float = { Base: CFrame?, Bob: number, Phase: number }
type Flicker = { Brightness: number, Seed: number }

local HubAmbience = {}

-- A crate on the crate stand: its Display model also holds the CratePrompt part (tagged
-- CrateDisplay).
function HubAmbience.IsStandCrate(m: Model): boolean
	local display = m.Parent
	if not display or display == workspace then
		return false
	end
	if display:FindFirstChild("CratePrompt") then
		return true
	end
	for _, sibling in display:GetChildren() do
		if sibling ~= m and CollectionService:HasTag(sibling, Tags.CrateDisplay) then
			return true
		end
	end
	return false
end

-- CrateIdle animates the stand's crates (it does nothing with crates or Idle switched off).
local function crateIdleOn(): boolean
	return Config.Features.Crates == true and Config.Crates.Idle.On == true
end

function HubAmbience.Mount()
	local perf = Config.Performance
	local floats: { [Model]: Float } = {}
	local flickers: { [PointLight]: Flicker } = {}
	local skipCrates = crateIdleOn()

	local function addFloat(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		-- Base is taken the first time its PrimaryPart is there: with streaming, a model can
		-- arrive before its parts.
		floats[instance] = {
			Base = nil,
			Bob = (instance:GetAttribute("BobHeight") or 0) :: number,
			Phase = (instance:GetAttribute("Phase") or 0) :: number,
		}
	end
	local function addFlicker(instance: Instance)
		if instance:IsA("PointLight") then
			flickers[instance] =
				{ Brightness = instance.Brightness, Seed = instance.Range + math.random() }
		end
	end
	for _, instance in CollectionService:GetTagged("HubFloat") do
		addFloat(instance)
	end
	for _, instance in CollectionService:GetTagged("HubFlicker") do
		addFlicker(instance)
	end
	CollectionService:GetInstanceAddedSignal("HubFloat"):Connect(addFloat)
	CollectionService:GetInstanceAddedSignal("HubFlicker"):Connect(addFlicker)
	CollectionService:GetInstanceRemovedSignal("HubFloat"):Connect(function(instance)
		floats[instance :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("HubFlicker"):Connect(function(instance)
		flickers[instance :: PointLight] = nil
	end)

	-- Every few frames (FramePace.ScanSeconds): which floats and lights are near the camera.
	-- In between, only those move: nothing far away costs anything per frame.
	local nearFloats: { Model } = {}
	local nearFlickers: { PointLight } = {}
	local nextScan = 0
	local nextFlicker = 0
	local maxDistance = perf.AmbienceDistance
	local flickerHz = perf.FlickerHz

	local function scan(now: number, eye: Vector3)
		local phone = Layout.IsPhone()
		nextScan = now + FramePace.ScanSeconds()
		maxDistance = if phone then perf.PhoneAmbienceDistance else perf.AmbienceDistance
		flickerHz = if phone then perf.PhoneFlickerHz else perf.FlickerHz
		table.clear(nearFloats)
		for m, f in floats do
			if not m.Parent then
				floats[m] = nil
				continue
			end
			local base = f.Base
			if not base then
				if not m.PrimaryPart then
					continue
				end
				base = m:GetPivot()
				f.Base = base
			end
			if ((base :: CFrame).Position - eye).Magnitude <= maxDistance then
				table.insert(nearFloats, m)
			end
		end
		table.clear(nearFlickers)
		for l in flickers do
			local holder = l.Parent
			-- (in a part, or in an Attachment: the light a custom prop gets, Kit.prop)
			local at: Vector3? = if holder and holder:IsA("BasePart")
				then holder.Position
				elseif holder and holder:IsA("Attachment") then holder.WorldPosition
				else nil
			if not holder then
				flickers[l] = nil
			elseif at and (at - eye).Magnitude <= maxDistance then
				table.insert(nearFlickers, l)
			end
		end
	end

	-- Every frame while something near the camera moves; otherwise only the scans run (from a
	-- timer: no per-frame work at all far from everything).
	FramePace.IdleLoop(RunService.RenderStepped, function(scanNow: boolean): boolean
		local t = os.clock()
		local eye = workspace.CurrentCamera.CFrame.Position
		if scanNow or t >= nextScan then
			scan(t, eye)
		end
		for _, m in nearFloats do
			local f = floats[m]
			if not f or not m.Parent then
				continue
			end
			-- (checked every frame: with streaming the crate's CratePrompt may arrive later)
			if skipCrates and HubAmbience.IsStandCrate(m) then
				if f.Base then
					m:PivotTo(f.Base) -- back where it was, for CrateIdle to take over
				end
				floats[m] = nil
				continue
			end
			local base = f.Base :: CFrame
			-- World-space bob: many models (candles) are built from rotated cylinders, so a
			-- local offset would slide them sideways instead of up and down.
			m:PivotTo(CFrame.new(0, math.sin(t * 1.5 + f.Phase) * f.Bob, 0) * base)
		end
		local busy = #nearFloats > 0 or #nearFlickers > 0
		if t < nextFlicker or #nearFlickers == 0 then
			return busy
		end
		nextFlicker = t + 1 / math.max(flickerHz, 1)
		for _, l in nearFlickers do
			local f = flickers[l]
			if f and l.Parent then
				l.Brightness = f.Brightness * (0.8 + 0.25 * math.noise(t * 3, f.Seed))
			end
		end
		return busy
	end)
end

return HubAmbience
