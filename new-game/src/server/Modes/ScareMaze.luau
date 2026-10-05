--!strict
--[[
	SCAREMAZE: two teams. Survivors must get through the maze (and are out if they stand still
	for Config.ScareMaze.StandStillSeconds); Haunters try to stop them. Jumpscares from moving
	scarecrows and zombies (spooky-cute, never gory).
	On/off: Config.Features.ScareMaze (off = the vote never offers it). Settings: Config.ScareMaze.

	TODO(scaremaze agent): this is a placeholder that ends the round straight away with no
	results, so the round loop already works if this mode is picked. Write the round in Run
	(see src/server/Modes/Types.luau for ctx and the result shape, and KingHunt.luau for an
	example): split the teams, teleport with ctx.Teleport to parts tagged SurvivorSpawn and
	HauntSpawn, use ctx.Countdown("Playing", ...) for the main part (clients look for that
	State), set the ReplicatedStorage attribute Alive (Survivors left), and return one row per
	player still in the server (Score, base Coins, Survived, Top, Team) with a ScoreLabel from
	Config.ScareMaze. Undo everything in Cleanup().
]]

local Types = require(script.Parent.Types)

local ScareMaze = {}

function ScareMaze.Cleanup() end

function ScareMaze.Run(_ctx: Types.RoundContext): Types.RoundResult
	return Types.Empty("")
end

return ScareMaze
