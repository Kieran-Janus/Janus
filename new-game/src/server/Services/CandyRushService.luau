--!strict
--[[
	Candy Rush, a lobby minigame (Config.Minigames.CandyRush): click your candies, the first to
	clear them all wins. Stations are found by the CandyRush* tags (src/shared/Tags.luau).
	On/off: Config.Features.CandyRush (off = Start() does nothing).
	TODO(minigames agent): this is a placeholder so Main.server.luau can already start it; the
	real feature goes here. If a client module calls one of this service's remotes, create
	that remote in Start() BEFORE the feature check, so the client never waits forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CandyRushService = {}

function CandyRushService.Start()
	if not Config.Features.CandyRush then
		return
	end
end

return CandyRushService
