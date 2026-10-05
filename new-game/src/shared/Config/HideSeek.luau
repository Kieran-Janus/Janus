--!strict
--[[
	PUMPKIN HIDE & SEEK (Config.HideSeek)

	A player-vs-player mode (on/off: Config.Features.HideSeek). Hiders turn into pumpkins
	and hide; seekers hunt them with candy guns. Played on the Pumpkin Farm and Hedge Maze
	maps (Config.Modes.Playlists). Hiders should be fairly easy to find.
	Change the times below to make rounds longer or shorter.
]]

return {
	-- TODO(hide & seek agent): candy gun, hider and seeker settings go here.
	HideSeconds = 30, -- hiders get this long to hide before the seekers are let out
	Duration = 180, -- seconds of seeking
}
