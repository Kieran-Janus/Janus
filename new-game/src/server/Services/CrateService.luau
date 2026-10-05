--!strict
--[[
	Crates (Config.Crates): bought with coins (or Robux when Config.Features.RobuxCrates is on),
	rolled on the server, items granted through DataService, duplicates refunded.
	On/off: Config.Features.Crates (off = Start() does nothing).
	TODO(crates agent): this is a placeholder so Main.server.luau can already start it; the
	real feature goes here. If a client module calls one of this service's remotes, create
	that remote in Start() BEFORE the feature check, so the client never waits forever.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CrateService = {}

function CrateService.Start()
	if not Config.Features.Crates then
		return
	end
end

return CrateService
