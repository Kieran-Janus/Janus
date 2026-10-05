--!strict
--[[
	Easter eggs (Config.EasterEggs): hidden pumpkins in the lobby (tag EasterEgg, attributes
	EggId and Coins) that give coins once per player (saved in data.EasterEggs).
	On/off: Config.Features.EasterEggs (off = Start() does nothing).
	TODO(easter eggs agent): this is a placeholder so Main.server.luau can already start it; the
	real feature goes here. If a client module calls one of this service's remotes, create
	that remote in Start() BEFORE the feature check, so the client never waits forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local EasterEggService = {}

function EasterEggService.Start()
	if not Config.Features.EasterEggs then
		return
	end
end

return EasterEggService
