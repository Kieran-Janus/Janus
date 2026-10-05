--!strict
--[[
	PARKOUR COURSE (Config.Parkour)

	The obstacle course in the lobby (on/off: Config.Features.Parkour). Its area is
	Config.Lobby.Zones.Parkour. The parts are found by tag (src/shared/Tags.luau):
	ParkourStart, ParkourCheckpoint (attribute Index = 1, 2, 3...), ParkourFinish and
	ParkourHazard, so you can move, resize or add pieces in Studio and it still works.
	Change the reward below to make finishing worth more or less.
]]

return {
	-- TODO(parkour agent): course layout and the rest of the settings go here.
	Reward = {
		Coins = 100, -- coins for reaching the finish...
		CooldownHours = 20, -- ...at most once per this many hours (saved per player)
	},
}
