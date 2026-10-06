--!strict
--[[
	EASTER EGGS (Config.EasterEggs)

	Secret pumpkins (and candy, skulls, ghosts) hidden around the lobby. Each one gives its
	coins once per player, ever (saved in data.EasterEggs). Walk into one or use its button.
	On/off: Config.Features.EasterEggs. Menu > Secret Pumpkins lists the ones you found and a
	riddle for each one you haven't.

	The List below: one line per egg.
	  Id      unique name, saved in every player's data: NEVER rename or reuse one that is live
	  Name    shown when you find it
	  Coins   coins for finding it
	  Look    GoldenPumpkin, Candy, Lollipop, Skull or Ghost (leave it out: GoldenPumpkin)
	  Anchor  what the egg hides next to (it is placed relative to this, so it follows when
	          the lobby changes). One of:
	            a tag name ("ShopKeeper", "HubSpawn", "ReadyPad", "ParkourFinish", ...): the
	              first part with that tag
	            an NPC Id ("VotingBoard", "Leaderboard", "PhotoSpot")
	            a lobby zone (Config.Lobby.Zones: "Shop", "WebScour", "CandyRush", ...)
	            a lobby landmark in Config.Hub ("ClockTower", "PumpkinPatch", "Mansion",
	              "KingStatue", "Graveyard", ...)
	            "Hub": the middle of the lobby
	          An egg whose anchor isn't in the game (e.g. ParkourFinish while the parkour is
	          switched off) is simply left out.
	  Offset  Vector3.new(right, up, back) in studs from the anchor, as the anchor faces the
	          middle of the lobby: back + = further from the middle (behind it), right + = to
	          its right. For "Hub": plain world directions (x = east, z = south).
	  Snap    (optional) the egg drops onto the ground or whatever is below it, looking from
	          this many studs above its spot (default SnapHeight). false = exactly at Offset.
	  Hint    the riddle shown in the menu until you find it

	In Studio: the eggs are in Workspace.Hub.EasterEggs. An egg is the part tagged EasterEgg
	with the attributes EggId (an Id from the list) and Coins; move it, copy it or make any part
	an egg by giving it that tag and those attributes. Eggs missing from the lobby are put back
	from this list when the game starts (to remove one for good, delete its line here).
	Coins changes work straight away, also on a hub saved in the place. A new Anchor or Offset
	for an egg that is already in a saved hub shows after the hub is rebuilt (F8 > Rebuild hub,
	or Bake.Hub()), or just move the egg in Studio.
	Your own egg look: a model named EggGoldenPumpkin (or EggCandy, EggLollipop, EggSkull,
	EggGhost) in ReplicatedStorage.Custom.Props replaces the built one.
]]

export type Egg = {
	Id: string,
	Name: string,
	Coins: number,
	Look: string?,
	Anchor: string,
	Offset: Vector3,
	Snap: (number | boolean)?,
	Hint: string,
}

return {
	Size = 1.6, -- studs: how big an egg is
	SnapHeight = 6, -- default for Snap (see above)
	ReachDistance = 14, -- studs: you must be this close to an egg to collect it (anti-cheat)
	CooldownSeconds = 0.5, -- per player: grabs closer together than this are ignored
	TouchToCollect = true, -- true = walking into an egg collects it (as well as its button)
	MaxCoins = 500, -- an egg never gives more than this, whatever its Coins attribute says
	Prompt = {
		ActionText = "Take",
		HoldDuration = 0.3, -- seconds to hold the button
		MaxActivationDistance = 8, -- studs
	},
	Sparkles = 3, -- little glints per second around each egg (0 = none)
	GlowRange = 0, -- studs of light around each egg (0 = no light: lights cost performance)
	Colors = { -- the built looks
		Gold = Color3.fromRGB(255, 196, 40),
		GoldDark = Color3.fromRGB(205, 140, 20),
		Stem = Color3.fromRGB(90, 160, 60),
		Candy = Color3.fromRGB(255, 90, 170),
		Wrapper = Color3.fromRGB(255, 255, 255),
		Bone = Color3.fromRGB(245, 240, 225),
		Ghost = Color3.fromRGB(225, 250, 255),
		Eyes = Color3.fromRGB(25, 18, 32),
		Sparkle = Color3.fromRGB(255, 240, 150),
	},
	Sounds = {
		Found = { SoundId = "rbxassetid://1841209502", Volume = 0.6 }, -- you found one
	} :: {
		Found: { SoundId: string, Volume: number?, PitchMin: number?, PitchMax: number? },
	},
	ToastSeconds = 4,
	-- The picture next to each egg in the Menu > Secret Pumpkins list (any emoji).
	Icons = {
		GoldenPumpkin = "🎃",
		Candy = "🍬",
		Lollipop = "🍭",
		Skull = "💀",
		Ghost = "👻",
		Missing = "❓", -- an egg you haven't found yet
	} :: { [string]: string },
	-- The list's size in UI units (smaller screens get a smaller panel whose list scrolls).
	Panel = { Width = 440, Height = 400, RowHeight = 46 },
	Text = {
		Toast = "Easter egg found! +%d %s (%d/%d)", -- coins, currency, found, total
		ToastTitle = "%s", -- the egg's Name, above the line above
		PanelTitle = "Secret Pumpkins",
		Progress = "Found %d of %d",
		AllFound = "You found every secret pumpkin. Amazing!",
		FoundLine = "%s  (+%d)", -- a found egg: its Name and coins
		MissingLine = "???  %s", -- an egg you haven't found: its Hint
		Close = "Close",
	},

	-- The eggs. Hide them in fun places that a player can reach.
	List = {
		{
			Id = "ShopPumpkin",
			Name = "Shy Shop Pumpkin",
			Coins = 50,
			Anchor = "Shop",
			Offset = Vector3.new(4.5, 0, 7.6),
			Hint = "The shopkeeper keeps one shy pumpkin out of sight, round the back.",
		},
		{
			Id = "PatchGold",
			Name = "Golden Patch Pumpkin",
			Coins = 40,
			Anchor = "PumpkinPatch",
			Offset = Vector3.new(2.5, 0, 4),
			Snap = 10,
			Hint = "One pumpkin in the patch shines brighter than all the others.",
		},
		{
			Id = "GraveCandy",
			Name = "Graveyard Gumdrop",
			Coins = 35,
			Look = "Candy",
			Anchor = "Leaderboard",
			Offset = Vector3.new(3, 0, 3.6),
			Hint = "The champions' stone hides something sweet behind its back.",
		},
		{
			Id = "BallotSkull",
			Name = "Ballot Box Skull",
			Coins = 30,
			Look = "Skull",
			Anchor = "VotingBoard",
			Offset = Vector3.new(1.5, 0, 0.4),
			Snap = 1.5,
			Hint = "Vote for the spookiest hiding place... then look beneath the votes.",
		},
		{
			Id = "PhotoGhost",
			Name = "Camera-Shy Ghost",
			Coins = 40,
			Look = "Ghost",
			Anchor = "PhotoSpot",
			Offset = Vector3.new(-3, 0, 9.5),
			Hint = "Say pumpkin! Someone camera-shy is hiding behind the picture.",
		},
		{
			Id = "SpawnLolly",
			Name = "Welcome Lollipop",
			Coins = 25,
			Look = "Lollipop",
			Anchor = "HubSpawn",
			Offset = Vector3.new(-8, 0, 10),
			Hint = "Where every adventure begins... just don't forget to look behind you.",
		},
		{
			Id = "SkyPumpkin",
			Name = "Sky-High Pumpkin",
			Coins = 100,
			Anchor = "ParkourFinish",
			Offset = Vector3.new(4, 0, 3),
			Snap = 4,
			Hint = "Climb all the way up to the trophy in the sky.",
		},
		{
			Id = "TowerSkull",
			Name = "Tick-Tock Skull",
			Coins = 35,
			Look = "Skull",
			Anchor = "ClockTower",
			Offset = Vector3.new(15.5, 0, 4),
			Hint = "Tick tock... walk round the side of the crooked clock.",
		},
		{
			Id = "GroveCandy",
			Name = "Spider's Sweet",
			Coins = 30,
			Look = "Candy",
			Anchor = "WebScour",
			Offset = Vector3.new(15.2, 0, 12),
			Hint = "The friendly spider guards a sweet behind one of its trees.",
		},
		{
			Id = "ForestGhost",
			Name = "Lost Forest Ghost",
			Coins = 60,
			Look = "Ghost",
			Anchor = "Hub",
			Offset = Vector3.new(-90, 0, -96),
			Snap = 12,
			Hint = "Slip through a gap in the fence and wander into the woods to the north-west.",
		},
		{
			Id = "MansionPumpkin",
			Name = "Haunted House Pumpkin",
			Coins = 100,
			Anchor = "Mansion",
			Offset = Vector3.new(9, 0, -22),
			Snap = 90,
			Hint = "Brave the long walk up the hill to the haunted house.",
		},
	} :: { Egg },
}
