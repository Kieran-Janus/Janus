--!strict
--[[
	Web Scour, a lobby minigame (Config.Minigames.WebScour): a quick scavenger hunt in the
	spider webs. Found by the WebScour* tags (src/shared/Tags.luau).
	On/off: Config.Features.WebScour (off = Start() does nothing).
	TODO(minigames agent): this is a placeholder so Main.server.luau can already start it; the
	real feature goes here. If a client module calls one of this service's remotes, create
	that remote in Start() BEFORE the feature check, so the client never waits forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WebScourService = {}

function WebScourService.Start()
	if not Config.Features.WebScour then
		return
	end
end

return WebScourService
