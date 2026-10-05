--!strict
--[[
	SCAREMAZE (Config.ScareMaze)

	Two teams (on/off: Config.Features.ScareMaze): Survivors must get through the maze;
	Haunters try to stop them. A Survivor who stands still too long is out. Moving
	scarecrows and zombies pop up for jumpscares (spooky-cute, never gory).
	Change StandStillSeconds to make standing still more or less dangerous.
]]

return {
	-- TODO(scaremaze agent): teams, scares and the rest of the settings go here.
	StandStillSeconds = 3, -- a Survivor who doesn't move for this long is out
	Duration = 240, -- seconds to reach the exit
}
