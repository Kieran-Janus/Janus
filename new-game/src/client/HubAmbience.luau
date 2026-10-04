--!strict
--[[
	Local-only hub animation, so the server never has to move decorations:
	  "HubFloat" Models bob up and down (attributes BobHeight, Phase)
	  "HubFlicker" PointLights flicker like candles
	Anything tagged later (the hub may be built after this client starts) is picked up too.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local HubAmbience = {}

function HubAmbience.Mount()
	local floats: { [Model]: CFrame } = {}
	local flickers: { [PointLight]: number } = {}

	local function addFloat(instance: Instance)
		if instance:IsA("Model") and instance.PrimaryPart then
			floats[instance] = instance:GetPivot()
		end
	end
	local function addFlicker(instance: Instance)
		if instance:IsA("PointLight") then
			flickers[instance] = instance.Brightness
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

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for m, base in floats do
			if m.Parent then
				local bob = (m:GetAttribute("BobHeight") or 0) :: number
				local phase = (m:GetAttribute("Phase") or 0) :: number
				m:PivotTo(base * CFrame.new(0, math.sin(t * 1.5 + phase) * bob, 0))
			else
				floats[m] = nil
			end
		end
		for l, brightness in flickers do
			if l.Parent then
				l.Brightness = brightness * (0.8 + 0.25 * math.noise(t * 3, l.Range))
			else
				flickers[l] = nil
			end
		end
	end)
end

return HubAmbience
