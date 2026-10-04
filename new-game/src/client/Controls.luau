--!strict
-- Sprint (hold Shift / L3) and Shout (G / Y). Only intent is sent; the server sets speed and noise.
-- On touch devices ContextActionService adds on-screen buttons for both.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Controls = {}

function Controls.Mount()
	local setSprint = Remotes.Event("SetSprint")
	local shout = Remotes.Event("Shout")

	-- High priority so Shift sprints instead of toggling shift-lock.
	ContextActionService:BindActionAtPriority("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint:FireServer(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setSprint:FireServer(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run")

	ContextActionService:BindAction("Shout", function(_, state)
		if state == Enum.UserInputState.Begin then
			shout:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("Shout", Config.King.Noise.ShoutText)
end

return Controls
