--!strict
--[[
	PUMPKIN HIDE & SEEK: hiders are pumpkins, seekers have candy guns.
	On/off: Config.Features.HideSeek (off = the vote never offers it). Settings: Config.HideSeek.
	Maps: Pumpkin Farm and Hedge Maze (Config.Modes.Playlists).

	TODO(hide & seek agent): this is a placeholder that ends the round straight away with no
	results, so the round loop already works if this mode is picked. Write the round in Run
	(see src/server/Modes/Types.luau for ctx and the result shape, and KingHunt.luau for an
	example): pick seekers, teleport with ctx.Teleport to parts tagged SeekerSpawn/HiderSpawn
	(src/shared/Tags.luau), use ctx.Countdown("Playing", ...) for the main part (clients look
	for that State), set the ReplicatedStorage attribute Alive if hiders can be found, and
	return one row per player still in the server (Score, base Coins, Survived, Top, Team)
	with a ScoreLabel from Config.HideSeek. Undo everything in Cleanup().
]]

local Types = require(script.Parent.Types)

local HideSeek = {}

function HideSeek.Cleanup() end

function HideSeek.Run(_ctx: Types.RoundContext): Types.RoundResult
	return Types.Empty("")
end

return HideSeek
