--!strict
--[[
	FEATURE SWITCHES (Config.Features)

	One line per feature: true = on, false = off. Turning a feature off hides it completely:
	its server code does nothing and its buttons, panels and lobby pieces don't show. (A lobby
	saved in your place keeps those pieces, but the game takes them out while it runs; the
	signposts pointing at them stay until the lobby is rebuilt: F8 > Rebuild hub or Bake.Hub().)
	Something broken? Switch it off here and the rest of the game keeps working.
]]

return {
	ReadyPad = true, -- stand on the Ready pad to join the next round (off = everyone plays)
	LobbySpectate = true, -- players in the lobby can watch the round (Menu > Spectate)
	Menu = true, -- the top-left Menu button with tiles for every panel
	KingHunt = true, -- the classic mode: grab pumpkins and hide from the Pumpkin King
	HideSeek = true, -- Pumpkin Hide & Seek: seekers with candy guns vs pumpkin hiders
	ScareMaze = true, -- ScareMaze: Survivors run the maze, Haunters scare them
	Parkour = true, -- the parkour course in the lobby
	CandyRush = true, -- lobby minigame: click your candies, first to clear them all wins
	WebScour = true, -- lobby minigame: a quick scavenger hunt in the spider webs
	TowerParkour = true, -- the Tormented Tower: a really hard climb inside the clock tower
	Dances = true, -- spooky code-made dances at the lobby Photo Spot (off = the bar shows nothing)
	EasterEggs = true, -- hidden pumpkins around the lobby that give coins once each
	Crates = true, -- crates bought with coins that give a random skin
	RobuxCrates = true, -- crates can also be bought with Robux (needs Crates on too)
	SkinEffects = true, -- CRAZY skins' animated rainbow, orbiting pieces and pulsing glow
	Tutorial = false, -- Boo Guide's first-round tips (removed in v2; true brings them back)
	MapLife = true, -- round maps come alive on each screen: bobbing pumpkins, fireflies, wobbling decoys
}
