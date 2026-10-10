--!strict
--[[
	SKIN SETTINGS (Config.Skins)

	How skins look and how the Skins tab of the shop shows them. The skins themselves are in
	the theme files next to this one (Pumpkin.luau, Candy.luau, ...).

	Themes   one line per theme file. Id = the file name, Name = what players see,
	         Crate = the crate its skins drop from (Config.Crates), Color = its colour in the
	         shop. To add a theme: make a new file like Pumpkin.luau, add a line here and a
	         line in InGame.luau.
	         WHICH THEMES ARE IN THE GAME: the on/off switches are in InGame.luau (next to this
	         file). Themes = only the ones switched on; AllThemes = every theme.
	Glow     the light around Rare and CRAZY skins, when a skin doesn't set its own.
	Auras    the particle looks a skin's Aura can use (Aura = { Kind = "Embers", ... }).
	         Texture can be any Roblox image id ("rbxassetid://123"); the ones below are
	         built into Roblox.
	Effects  the animated CRAZY effects (rainbow, orbiting pieces, pulsing glow). They run on
	         each player's own screen; MaxAnimated keeps phones fast. Switch them off with
	         Config.Features.SkinEffects.
	Shop     the Skins tab: cards per page and the theme name for skins not in a crate.
]]

export type Theme = { Id: string, Name: string, Crate: string, Color: Color3 }

export type Aura = {
	Texture: string,
	Rate: number,
	Lifetime: { number },
	Speed: { number },
	Size: { number },
	Transparency: { number },
	Rise: number,
	Spin: number,
	Glow: number,
	Spread: number,
}

local InGame = require(script.Parent.InGame)

local ALL_THEMES: { Theme } = {
	{
		Id = "Pumpkin",
		Name = "Pumpkin",
		Crate = "PumpkinCrate",
		Color = Color3.fromRGB(255, 130, 20),
	},
	{
		Id = "Candy",
		Name = "Candy",
		Crate = "CandyCrate",
		Color = Color3.fromRGB(255, 110, 190),
	},
	{
		Id = "Spooky",
		Name = "Spooky",
		Crate = "SpookyCrate",
		Color = Color3.fromRGB(150, 95, 230),
	},
	{
		Id = "Graveyard",
		Name = "Graveyard",
		Crate = "GraveyardCrate",
		Color = Color3.fromRGB(130, 160, 140),
	},
	{
		Id = "Monster",
		Name = "Monster",
		Crate = "MonsterCrate",
		Color = Color3.fromRGB(110, 210, 90),
	},
	{
		Id = "Moonlight",
		Name = "Moonlight",
		Crate = "MoonlightCrate",
		Color = Color3.fromRGB(110, 150, 255),
	},
	-- The 24 newer themes (each 21 skins, three of them with a ONE IN A MILLION CRAZY skin).
	{
		Id = "VampireCastle",
		Name = "Vampire Castle",
		Crate = "VampireCastleCrate",
		Color = Color3.fromRGB(170, 20, 40),
	},
	{
		Id = "ZombieTown",
		Name = "Zombie Town",
		Crate = "ZombieTownCrate",
		Color = Color3.fromRGB(110, 150, 80),
	},
	{
		Id = "HauntedCarnival",
		Name = "Haunted Carnival",
		Crate = "HauntedCarnivalCrate",
		Color = Color3.fromRGB(220, 40, 50),
	},
	{
		Id = "MummyTomb",
		Name = "Mummy Tomb",
		Crate = "MummyTombCrate",
		Color = Color3.fromRGB(225, 200, 140),
	},
	{
		Id = "WerewolfWoods",
		Name = "Werewolf Woods",
		Crate = "WerewolfWoodsCrate",
		Color = Color3.fromRGB(120, 85, 60),
	},
	{
		Id = "MadScientistLab",
		Name = "Mad Scientist Lab",
		Crate = "MadScientistLabCrate",
		Color = Color3.fromRGB(120, 255, 80),
	},
	{
		Id = "GhostShip",
		Name = "Ghost Ship",
		Crate = "GhostShipCrate",
		Color = Color3.fromRGB(140, 230, 220),
	},
	{
		Id = "BatCave",
		Name = "Bat Cave",
		Crate = "BatCaveCrate",
		Color = Color3.fromRGB(110, 60, 160),
	},
	{
		Id = "SpiderLair",
		Name = "Spider Lair",
		Crate = "SpiderLairCrate",
		Color = Color3.fromRGB(130, 220, 60),
	},
	{
		Id = "SkeletonCrew",
		Name = "Skeleton Crew",
		Crate = "SkeletonCrewCrate",
		Color = Color3.fromRGB(240, 235, 215),
	},
	{
		Id = "CursedToys",
		Name = "Cursed Toys",
		Crate = "CursedToysCrate",
		Color = Color3.fromRGB(240, 140, 180),
	},
	{
		Id = "ScarecrowFarm",
		Name = "Scarecrow Farm",
		Crate = "ScarecrowFarmCrate",
		Color = Color3.fromRGB(230, 200, 110),
	},
	{
		Id = "HauntedHotel",
		Name = "Haunted Hotel",
		Crate = "HauntedHotelCrate",
		Color = Color3.fromRGB(150, 20, 40),
	},
	{
		Id = "MonsterDisco",
		Name = "Monster Disco",
		Crate = "MonsterDiscoCrate",
		Color = Color3.fromRGB(255, 60, 180),
	},
	{
		Id = "BlackCatAlley",
		Name = "Black Cat Alley",
		Crate = "BlackCatAlleyCrate",
		Color = Color3.fromRGB(150, 255, 80),
	},
	{
		Id = "GoblinMarket",
		Name = "Goblin Market",
		Crate = "GoblinMarketCrate",
		Color = Color3.fromRGB(110, 170, 60),
	},
	{
		Id = "SwampCreatures",
		Name = "Swamp Creatures",
		Crate = "SwampCreaturesCrate",
		Color = Color3.fromRGB(60, 140, 120),
	},
	{
		Id = "WitchsBrew",
		Name = "Witch's Brew",
		Crate = "WitchsBrewCrate",
		Color = Color3.fromRGB(100, 40, 140),
	},
	{
		Id = "AlienAbduction",
		Name = "Alien Abduction",
		Crate = "AlienAbductionCrate",
		Color = Color3.fromRGB(120, 230, 90),
	},
	{
		Id = "FrostyFright",
		Name = "Frosty Fright",
		Crate = "FrostyFrightCrate",
		Color = Color3.fromRGB(140, 200, 255),
	},
	{
		Id = "GraveyardParty",
		Name = "Graveyard Party",
		Crate = "GraveyardPartyCrate",
		Color = Color3.fromRGB(255, 110, 190),
	},
	{
		Id = "CandyFactory",
		Name = "Candy Factory",
		Crate = "CandyFactoryCrate",
		Color = Color3.fromRGB(255, 140, 200),
	},
	{
		Id = "PhantomTheatre",
		Name = "Phantom Theatre",
		Crate = "PhantomTheatreCrate",
		Color = Color3.fromRGB(160, 20, 40),
	},
	{
		Id = "AutumnLeaves",
		Name = "Autumn Leaves",
		Crate = "AutumnLeavesCrate",
		Color = Color3.fromRGB(230, 130, 40),
	},
}

-- Only the themes switched on in InGame.luau (a theme missing there counts as on).
local themes: { Theme } = {}
for _, theme in ALL_THEMES do
	if InGame.Themes[theme.Id] ~= false then
		table.insert(themes, theme)
	end
end

return {
	Themes = themes,
	AllThemes = ALL_THEMES,
	-- Skin Ids hidden one at a time (InGame.luau > SkinsOff).
	SkinsOff = InGame.SkinsOff,

	-- Rare and CRAZY skins glow. A skin's Glow = { Color = ..., Brightness = 2, Range = 12 }
	-- uses these numbers for anything it leaves out.
	Glow = {
		Brightness = 1.6,
		Range = 10, -- studs
	},

	-- Particle looks for Aura = { Kind = "...", Color = ..., Color2 = ... }. Numbers in pairs
	-- are { smallest, biggest } (Lifetime, Speed) or { start, end } (Size, Transparency).
	Auras = {
		Sparkles = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 10, -- particles per second
			Lifetime = { 0.8, 1.5 }, -- seconds
			Speed = { 0.3, 1.2 }, -- studs per second
			Size = { 0.45, 0 },
			Transparency = { 0, 1 },
			Rise = 0.6, -- upward pull (negative = falls)
			Spin = 120, -- degrees per second
			Glow = 1, -- 0 = flat colour, 1 = glowing
			Spread = 180, -- 0 = straight up, 180 = every direction
		},
		Embers = {
			Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
			Rate = 14,
			Lifetime = { 0.8, 1.4 },
			Speed = { 1, 2.5 },
			Size = { 0.3, 0 },
			Transparency = { 0, 1 },
			Rise = 2,
			Spin = 0,
			Glow = 1,
			Spread = 25,
		},
		Bubbles = {
			Texture = "rbxasset://textures/particles/forcefield_glow_main.dds",
			Rate = 6,
			Lifetime = { 1.2, 2 },
			Speed = { 0.6, 1.4 },
			Size = { 0.3, 0.6 },
			Transparency = { 0.3, 1 },
			Rise = 0.8,
			Spin = 0,
			Glow = 0.4,
			Spread = 30,
		},
		Hearts = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 6,
			Lifetime = { 1.2, 1.8 },
			Speed = { 0.5, 1 },
			Size = { 0.6, 0.2 },
			Transparency = { 0, 1 },
			Rise = 0.8,
			Spin = 40,
			Glow = 0.8,
			Spread = 40,
		},
		Snow = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 10,
			Lifetime = { 1.5, 2.5 },
			Speed = { 0, 0.3 },
			Size = { 0.25, 0.15 },
			Transparency = { 0, 1 },
			Rise = -1.5,
			Spin = 30,
			Glow = 0.6,
			Spread = 180,
		},
		Smoke = {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Rate = 4,
			Lifetime = { 1.8, 2.6 },
			Speed = { 0.4, 0.9 },
			Size = { 1, 2.6 },
			Transparency = { 0.55, 1 },
			Rise = 0.4,
			Spin = 20,
			Glow = 0,
			Spread = 60,
		},
		Stars = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 5,
			Lifetime = { 1.5, 2.2 },
			Speed = { 0.2, 0.6 },
			Size = { 0.7, 0 },
			Transparency = { 0, 1 },
			Rise = 0.3,
			Spin = 60,
			Glow = 1,
			Spread = 180,
		},
	} :: { [string]: Aura },

	-- CRAZY skins' animated effects (src/client/SkinFx.luau, on each player's screen).
	Effects = {
		MaxAnimated = 6, -- at most this many CRAZY players animate at once (the closest ones)
		MaxDistance = 150, -- studs from the camera; further away they stop animating
		CheckSeconds = 0.5, -- how often the closest ones are picked again
		RainbowSeconds = 3, -- one trip around the rainbow
		PulseSeconds = 1.6, -- one glow pulse
		PulseLow = 0.45, -- the dimmest the glow gets (0.45 = 45% of its brightness)
		OrbitSeconds = 3.2, -- one lap of the orbiting pieces
		OrbitRadius = 3, -- studs from your middle
		OrbitHeight = 0.6, -- studs above your middle
		OrbitBob = 0.4, -- how far they bob up and down
		OrbitScale = 1.5, -- size of the orbiting pieces (1 = as built, 2 = twice as big)
		TintTransparency = 0.72, -- the rainbow tint over the body (1 = no tint)
		OutlineTransparency = 0.35, -- the rainbow outline (1 = no outline)
		-- Special effects a skin can name with Crazy = { Effect = "..." } (src/client/SkinEffects.luau).
		Special = {
			-- The Tormented Tower's skin: ghostly chains swirling round you and red lightning.
			Torment = {
				Links = 9, -- links in each of the two chains
				Radius = 2.4, -- studs from your middle
				Height = 5.5, -- how tall the swirl is
				Seconds = 2.4, -- one turn of the swirl
				ChainColor = Color3.fromRGB(70, 40, 90),
				BoltColor = Color3.fromRGB(255, 40, 60),
				BoltEvery = 0.8, -- seconds between lightning flashes
				BoltSeconds = 0.15, -- how long a flash lasts
			},
			-- ONE IN A MILLION: Night Lord Supreme. A blood-red moon rises behind you, a ring of
			-- little bats circles it and red mist drifts up.
			BloodMoon = {
				MoonSize = 3.2, -- studs across
				MoonHeight = 3.4, -- studs above your middle (and a little behind you)
				MoonColor = Color3.fromRGB(220, 20, 40),
				Bats = 6,
				BatColor = Color3.fromRGB(25, 10, 25),
				Seconds = 2.2, -- one lap of the bats round the moon
				Mist = 6, -- red mist puffs rising round your feet
				MistColor = Color3.fromRGB(200, 30, 50),
			},
			-- ONE IN A MILLION: Disco Demon. A mirror ball spins over your head and coloured
			-- light beams sweep the floor round you.
			DiscoInferno = {
				BallSize = 1.6,
				BallHeight = 4.2,
				Beams = 6,
				BeamLength = 7,
				Seconds = 3, -- one turn of the beams
				FloorRing = 4.5, -- studs: the radius of the glowing dance-floor ring at your feet
			},
			-- ONE IN A MILLION: Star Voyager. A little flying saucer hovers above you and beams
			-- you up with a glowing cone of light, with tiny stars swirling up inside it.
			UfoBeam = {
				SaucerWidth = 4,
				SaucerHeight = 5.2,
				Seconds = 2.6, -- one turn of the saucer
				BeamColor = Color3.fromRGB(120, 255, 230),
				Sparks = 8,
			},
		},
	},

	-- The Skins tab of the shop.
	Shop = {
		PageSize = 12, -- cards per page
		PhonePageSize = 8, -- cards per page on phones
		ClassicTheme = "Classic", -- the theme filter name for skins that aren't in a crate
		ShimmerSeconds = 2.5, -- one turn of the shimmer around CRAZY cards
	},
}
