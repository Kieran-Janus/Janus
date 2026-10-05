--!strict
--[[
	Tag names for parts that DO something (CollectionService tags).

	The code finds these parts by their tag, never by their name or where they are, so you
	can move, resize, recolour, duplicate or swap them in Studio and they keep working.
	To see or add a tag in Studio: select a part > Properties > Tags (at the bottom), or
	View > Tag Editor.

	Some tags also need attributes on the same part (Properties > Attributes):
	  ParkourCheckpoint  Index (number: 1, 2, 3... in course order)
	  CandyRushPad       Lane (number)
	  EasterEgg          EggId (string, matches Config.EasterEggs.List) and Coins (number)
	  ScareTrigger       Kind (string: which scare plays)
	Colours: any part can have the attribute PaletteRole (an attribute, not a tag) to take its
	colour from Config.Hub.Palette (and PaletteShade: 0.3 = 30% darker, -0.2 = 20% lighter).

	Use them in code as Tags.ReadyPad etc. instead of typing the string.
]]

local Tags = {
	-- Lobby
	ReadyPad = "ReadyPad", -- stand on it to join the next round
	ReadySign = "ReadySign", -- shows "READY x / y" (a part holding the sign's BillboardGui)
	HubSpawn = "HubSpawn", -- where players appear in the lobby
	ShopKeeper = "ShopKeeper", -- the Pumpkin Shop keeper and its prompt (a tagged part with no
	-- prompt gets one, so tagging any part ShopKeeper makes it open the shop)
	-- Parkour
	ParkourStart = "ParkourStart",
	ParkourCheckpoint = "ParkourCheckpoint", -- attribute Index
	ParkourFinish = "ParkourFinish",
	ParkourHazard = "ParkourHazard", -- touching it sends you back to your last checkpoint
	ParkourBoard = "ParkourBoard", -- the part showing the fastest climbers (a SurfaceGui)
	-- Lobby minigames
	CandyRushStation = "CandyRushStation",
	CandyRushPad = "CandyRushPad", -- attribute Lane
	CandyRushBoard = "CandyRushBoard",
	WebScourStart = "WebScourStart",
	WebScourSpot = "WebScourSpot",
	-- Easter eggs
	EasterEgg = "EasterEgg", -- attributes EggId, Coins
	-- Round maps
	HidingDecoy = "HidingDecoy", -- Hide & Seek: fake pumpkins hiders blend in with
	ScareTrigger = "ScareTrigger", -- ScareMaze: walking here sets off a scare (attribute Kind)
	MazeExit = "MazeExit", -- ScareMaze: Survivors who reach it escape
	HauntSpawn = "HauntSpawn", -- ScareMaze: where Haunters start
	SurvivorSpawn = "SurvivorSpawn", -- ScareMaze: where Survivors start
	SeekerSpawn = "SeekerSpawn", -- Hide & Seek: where seekers start
	HiderSpawn = "HiderSpawn", -- Hide & Seek: where hiders start
	-- Older tags (set by src/server/Build/Kit.luau)
	HubFloat = "HubFloat", -- bobs up and down (client HubAmbience)
	HubFlicker = "HubFlicker", -- light flickers (client HubAmbience)
	HidingSpot = "HidingSpot", -- blocks the King's view while you stand in it
}

return Tags
