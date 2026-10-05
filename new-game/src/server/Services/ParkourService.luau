--!strict
--[[
	Parkour course in the lobby (Config.Parkour): checkpoints, hazards and a finish reward,
	found by the Parkour* tags (src/shared/Tags.luau).
	On/off: Config.Features.Parkour (off = Start() does nothing).
	TODO(parkour agent): this is a placeholder so Main.server.luau can already start it; the
	real feature goes here. If a client module calls one of this service's remotes, create
	that remote in Start() BEFORE the feature check, so the client never waits forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ParkourService = {}

function ParkourService.Start()
	if not Config.Features.Parkour then
		return
	end
end

return ParkourService
