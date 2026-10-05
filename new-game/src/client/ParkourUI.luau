--!strict
--[[
	Parkour course screen bits (Config.Parkour): timer, checkpoint and finish messages.
	On/off: Config.Features.Parkour (off = Mount does nothing and nothing shows).
	TODO(parkour agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ParkourUI = {}

function ParkourUI.Mount(_gui: ScreenGui)
	if not Config.Features.Parkour then
		return
	end
end

return ParkourUI
