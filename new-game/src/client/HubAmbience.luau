--!strict
--[[
	Local-only hub (and map) animation, so the server never has to move decorations:
	  "HubFloat" Models bob up and down (attributes BobHeight, Phase)
	  "HubFlicker" PointLights flicker like candles
	Anything tagged later (the hub may be built after this client starts) is picked up too.
	Cheap on phones (Config.Performance): only things near the camera animate, and the
	flicker updates a few times a second rather than every frame.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

type Float = { Base: CFrame?, Bob: number, Phase: number }
type Flicker = { Brightness: number, Seed: number }

local HubAmbience = {}

function HubAmbience.Mount()
	local perf = Config.Performance
	local floats: { [Model]: Float } = {}
	local flickers: { [PointLight]: Flicker } = {}

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

	local nextFlicker = 0
	local maxDistance = perf.AmbienceDistance
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local eye = workspace.CurrentCamera.CFrame.Position
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
			if (base.Position - eye).Magnitude <= maxDistance then
				-- World-space bob: many models (candles) are built from rotated cylinders, so a
				-- local offset would slide them sideways instead of up and down.
				m:PivotTo(CFrame.new(0, math.sin(t * 1.5 + f.Phase) * f.Bob, 0) * base)
			end
		end
		if t < nextFlicker then
			return
		end
		nextFlicker = t + 1 / perf.FlickerHz
		for l, f in flickers do
			local holder = l.Parent
			-- (in a part, or in an Attachment: the light a custom prop gets, Kit.prop)
			local at: Vector3? = if holder and holder:IsA("BasePart")
				then holder.Position
				elseif holder and holder:IsA("Attachment") then holder.WorldPosition
				else nil
			if not holder then
				flickers[l] = nil
			elseif at and (at - eye).Magnitude <= maxDistance then
				l.Brightness = f.Brightness * (0.8 + 0.25 * math.noise(t * 3, f.Seed))
			end
		end
	end)
end

return HubAmbience
