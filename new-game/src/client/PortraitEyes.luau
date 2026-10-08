--!strict
--[[
	Haunted portraits whose eyes follow you (this screen only). A canvas part tagged
	PortraitEyes (src/server/Build/Portrait.luau) has a SurfaceGui with eyes; each eye's "Pupil"
	frame slides towards the camera. Only portraits within Config.Maps.PortraitEyes.Range of the
	camera move, a few times a second when far, every frame when near.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local FramePace = require(script.Parent.FramePace)

local PortraitEyes = {}

-- Where a pupil sits (0..1 of its eye) for a camera at `local` (in the canvas part's space).
function PortraitEyes.Aim(localCamera: Vector3): Vector2
	local cfg = Config.Maps.PortraitEyes
	local depth = math.max(-localCamera.Z, 1) -- in front of the canvas = -Z
	-- (on a Front SurfaceGui, screen right is the part's -X and screen down its -Y)
	local x = math.clamp(-localCamera.X / depth, -1, 1)
	local y = math.clamp(-localCamera.Y / depth, -1, 1)
	return Vector2.new(0.5 + x * cfg.Reach.X, 0.5 + y * cfg.Reach.Y)
end

function PortraitEyes.Mount(_gui: ScreenGui?)
	local cfg = Config.Maps.PortraitEyes
	if not cfg.On then
		return
	end
	local canvases: { [BasePart]: { Frame } } = {}

	local function add(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local pupils: { Frame } = {}
		for _, d in instance:GetDescendants() do
			if d:IsA("Frame") and d.Name == "Pupil" then
				table.insert(pupils, d)
			end
		end
		canvases[instance] = pupils
	end
	for _, instance in CollectionService:GetTagged(Tags.PortraitEyes) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.PortraitEyes):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.PortraitEyes):Connect(function(instance)
		canvases[instance :: BasePart] = nil
	end)

	local near: { BasePart } = {}
	local nextScan = 0
	FramePace.IdleLoop(RunService.RenderStepped, function(scan: boolean): boolean
		local camera = workspace.CurrentCamera
		if not camera then
			return false
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		if scan or now >= nextScan then
			nextScan = now + FramePace.ScanSeconds()
			table.clear(near)
			for canvas in canvases do
				if not canvas.Parent then
					canvases[canvas] = nil
				elseif (canvas.Position - eye).Magnitude <= cfg.Range then
					table.insert(near, canvas)
				end
			end
		end
		for _, canvas in near do
			local pupils = canvases[canvas]
			if pupils and canvas.Parent then
				local aim = PortraitEyes.Aim(canvas.CFrame:PointToObjectSpace(eye))
				for _, pupil in pupils do
					pupil.Position = UDim2.fromScale(aim.X, aim.Y)
				end
			end
		end
		return #near > 0
	end)
end

return PortraitEyes
