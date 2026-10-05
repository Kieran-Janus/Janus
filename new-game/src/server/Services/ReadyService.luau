--!strict
--[[
	Ready pad (Config.Lobby.Ready): a player is ready while their character stands on a part
	tagged ReadyPad (src/shared/Tags.luau). Only ready players are put into the next round.
	On/off: Config.Features.ReadyPad (off = everyone in the server plays, like before v2).

	ReadyService.List() -> { Player }       the players who are ready right now
	ReadyService.IsReady(player) -> boolean

	TODO(rounds agent): this is a placeholder so Main.server.luau can already start it
	(before GameService). It counts every player as ready until the pad check is written:
	check positions every Config.Lobby.Ready.CheckSeconds, publish the ReplicatedStorage
	attributes ReadyCount / ReadyNeeded and the player attribute Ready. Create any remote a
	client uses in Start() BEFORE the feature check, so the client never waits forever.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ReadyService = {}

function ReadyService.List(): { Player }
	return Players:GetPlayers()
end

function ReadyService.IsReady(player: Player): boolean
	return player.Parent == Players
end

function ReadyService.Start()
	if not Config.Features.ReadyPad then
		return
	end
end

return ReadyService
