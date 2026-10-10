--!strict
--[[
	WHICH SKINS ARE IN THE GAME (the on/off switches for skins)

	THEMES: true = that theme's skins and its crate are in the game, false = they're hidden
	(left out of the shop, Menu > Crates, the rarity crates and Skin Studio). Nothing is deleted:
	set it back to true and they all come back, exactly as they were.
	Each theme has about 20 skins (13 Common, 5 Uncommon, 2-3 Rare, sometimes one CRAZY).

	ONE SKIN: put its Id in SkinsOff to hide just that skin (find the Id in its theme file,
	src/shared/Config/Skins/<Theme>.luau, or in Skin Studio). Remove the line to bring it back.

	Players who own a hidden skin keep it in their save: it simply can't be worn until it's back.
	Keep at least one theme on. The lobby crate stand shows the six classic crates
	(Config.Crates.Stand.Themed): keep those on, or the stand has an empty gap until the hub is
	rebuilt.
]]

return {
	Themes = {
		-- The six classic themes (the crates on the lobby stand)
		Pumpkin = true,
		Candy = true,
		Spooky = true,
		Graveyard = true,
		Monster = true,
		Moonlight = true,

		-- Monsters
		VampireCastle = true, -- has a ONE IN A MILLION skin (Night Lord Supreme)
		ZombieTown = true,
		WerewolfWoods = false,
		MummyTomb = false,
		SkeletonCrew = false,
		SwampCreatures = false,
		GoblinMarket = false,

		-- Haunted Places
		HauntedCarnival = true,
		HauntedHotel = false,
		GhostShip = false,
		PhantomTheatre = false,
		GraveyardParty = false,
		MadScientistLab = false,

		-- Creepy Critters
		SpiderLair = true,
		AlienAbduction = true, -- has a ONE IN A MILLION skin (Star Voyager)
		BatCave = false,
		BlackCatAlley = false,
		ScarecrowFarm = false,

		-- Sweet & Silly
		MonsterDisco = true, -- has a ONE IN A MILLION skin (Disco Demon)
		CursedToys = false,
		CandyFactory = false,
		WitchsBrew = false,
		FrostyFright = false,
		AutumnLeaves = false,
	} :: { [string]: boolean },

	-- Single skins to hide, by Id, e.g. "Pumpkin_CandleKid",
	SkinsOff = {} :: { string },
}
