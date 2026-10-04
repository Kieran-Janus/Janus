--!strict
--[[
	Ghost flying. While this player is a ghost on the map (not spectating), their own
	character floats: move with the usual controls, Space/E to rise, Q to sink.
	The client owns its character's physics, so this runs locally; the server has already
	made ghosts harmless (no pickups, ignored by the King, no collisions with players).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local GhostFlight = {}

function GhostFlight.Mount()
	local player = Players.LocalPlayer
	local vertical = 0
	local up, down = false, false
	local active: { Instance } = {}
	local stepConnection: RBXScriptConnection? = nil

	local function stop()
		if stepConnection then
			stepConnection:Disconnect()
			stepConnection = nil
		end
		for _, instance in active do
			instance:Destroy()
		end
		table.clear(active)
		ContextActionService:UnbindAction("GhostUp")
		ContextActionService:UnbindAction("GhostDown")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	local function start()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not character or not humanoid or not root or stepConnection then
			return
		end
		humanoid.PlatformStand = true

		local attachment = Instance.new("Attachment")
		attachment.Name = "GhostFlight"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.MaxForce = math.huge
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Parent = root
		active = { attachment, velocity, align }

		local function bind(name: string, setter: (boolean) -> (), ...: Enum.KeyCode)
			ContextActionService:BindAction(name, function(_, state)
				setter(state == Enum.UserInputState.Begin)
				return Enum.ContextActionResult.Sink
			end, true, ...)
		end
		bind("GhostUp", function(on)
			up = on
		end, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
		bind("GhostDown", function(on)
			down = on
		end, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("GhostUp", "Up")
		ContextActionService:SetTitle("GhostDown", "Down")

		stepConnection = RunService.RenderStepped:Connect(function()
			if not root.Parent then
				stop()
				return
			end
			vertical = (if up then 1 else 0) - (if down then 1 else 0)
			-- Don't fly off into the sky: cap height above the map floor.
			local map = workspace:FindFirstChild("Map")
			local floor = map and map:FindFirstChild("Floor", true)
			if floor and floor:IsA("BasePart") and vertical > 0 then
				if root.Position.Y > floor.Position.Y + Config.Ghost.MaxFlyHeight then
					vertical = 0
				end
			end
			velocity.VectorVelocity = humanoid.MoveDirection * Config.Ghost.FlySpeed
				+ Vector3.new(0, vertical * Config.Ghost.FlyVerticalSpeed, 0)
			-- Face where the camera looks (flattened), like normal walking.
			local look = workspace.CurrentCamera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				align.CFrame = CFrame.lookAt(Vector3.zero, flat)
			end
		end)
	end

	local function refresh()
		local flying = player:GetAttribute("Out") == true
			and player:GetAttribute("GhostMode") ~= "Spectate"
		if flying then
			start()
		else
			stop()
		end
	end

	player:GetAttributeChangedSignal("Out"):Connect(refresh)
	player:GetAttributeChangedSignal("GhostMode"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		stop()
		task.defer(refresh)
	end)
	refresh()
end

return GhostFlight
