--!strict
--[[
	FEATURE SWITCHES (Config.Features)

	One line per feature: true = on, false = off. Turning a feature off hides it completely:
	its server code does nothing and its buttons, panels and lobby pieces don't show.
	Something broken? Switch it off here and the rest of the game keeps working.
]]

return {
	ReadyPad = true, -- stand on the Ready pad to join the next round (off = everyone plays)
	LobbySpectate = true, -- players in the lobby can watch the round (Menu > Spectate)
	Menu = true, -- the top-left Menu button with tiles for every panel
	KingHunt = true, -- the classic mode: grab pumpkins and hide from the Pumpkin King
	HideSeek = false, -- Pumpkin Hide & Seek: seekers with candy guns vs pumpkin hiders
	ScareMaze = false, -- ScareMaze: Survivors run the maze, Haunters scare them
	Parkour = false, -- the parkour course in the lobby
	CandyRush = false, -- lobby minigame: click your candies, first to clear them all wins
	WebScour = false, -- lobby minigame: a quick scavenger hunt in the spider webs
	EasterEggs = false, -- hidden pumpkins around the lobby that give coins once each
	Crates = false, -- crates bought with coins that give a random skin
	RobuxCrates = false, -- crates can also be bought with Robux (needs Crates on too)
	Tutorial = false, -- Boo Guide's first-round tips (removed in v2; true brings them back)
}
