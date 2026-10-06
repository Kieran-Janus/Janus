--!strict
--[[
	WEB SCOUR (Config.Minigames.WebScour)

	A quick Halloween scavenger hunt in the "Spider Grove": walk up to the glowing lantern and
	use "Scour the Web!". Little glowing critters (spiders, bats, candy, ghosts) appear in the
	webs, only for you, and you have TimeLimit seconds to click or tap them all. Several
	players can play at once, each with their own critters.
	On/off: Config.Features.WebScour. Where it is: Config.Lobby.Zones.WebScour (move the zone
	to move the whole grove). Built by src/server/Hub/Sections/WebScour.luau, played by
	src/server/Services/WebScourService.luau and src/client/WebScourUI.luau.

	Easy changes:
	  - more or fewer critters: Critters       - more or less time: TimeLimit
	  - coins: CoinsPerCritter, FinishCoins, TimeBonusPerSecond, MaxCoins, RewardCooldown
	  - what it says on screen: Text            - sounds: Sounds (any rbxassetid, "" = silent)
	In Studio the hiding spots are the invisible parts tagged WebScourSpot and the lantern is
	the part tagged WebScourStart: move, copy or delete them and the game keeps working (your
	own lantern model works too: tag the Model WebScourStart). Delete the lantern and a new one
	is put back at Config.Lobby.Zones.WebScour; the rest of the grove stays as you left it
	(as long as it still has hiding spots).
]]

-- What one sound line may contain (leave this as it is).
type Sound = { SoundId: string, Volume: number?, PitchMin: number?, PitchMax: number? }

return {
	-- The game ------------------------------------------------------------------------------
	Critters = 6, -- critters to find in one go (fewer if the grove has fewer hiding spots)
	TimeLimit = 45, -- seconds to find them all
	MaxReach = 26, -- studs: you must be this close to a critter for your click to count
	MinSecondsBetweenFinds = 0.3, -- faster clicks than this are ignored (stops auto-clickers)
	FirstFindAfter = 0.5, -- seconds after the start before the first critter can be caught
	StartCooldown = 3, -- seconds after a hunt ends before you can start the next one
	LeaveDistance = 75, -- studs from the lantern: walk further away and the hunt stops
	CheckSeconds = 0.5, -- how often the server checks that hunters are still in the grove
	LagAllowance = 0.4, -- seconds after the clock runs out that a click still counts (slow internet)
	MaxActionsPerSecond = 8, -- clicks the server listens to per player per second

	-- Coins -----------------------------------------------------------------------------------
	CoinsPerCritter = 2, -- coins for every critter you find (even if time runs out)
	FinishCoins = 20, -- extra coins for finding everything in time
	TimeBonusPerSecond = 0.5, -- and this many coins for every second left on the clock
	MaxCoins = 50, -- never more than this from one hunt
	RewardCooldown = 180, -- seconds between hunts that pay coins (in between: just for fun,
	-- your best time still counts). Best times are saved in data.Minigames.WebScourBest, and
	-- when you last got coins in data.Minigames.WebScourLastReward (so changing servers
	-- doesn't skip the wait).

	-- The lantern's button ----------------------------------------------------------------------
	Prompt = {
		ActionText = "Scour the Web!",
		ObjectText = "Web Scour",
		HoldDuration = 0.2, -- seconds to hold (0 = a tap)
		MaxActivationDistance = 12, -- studs
	},

	-- The critters (only the player hunting sees them) ------------------------------------------
	-- Every critter is a cute cartoon spider sitting on a web strand. Each one gets a random
	-- colour from this list: add, remove or change colours (the name is only a label).
	CritterSize = 1.7, -- studs across
	CritterColors = {
		Pink = Color3.fromRGB(255, 95, 200),
		Lime = Color3.fromRGB(120, 255, 70),
		Orange = Color3.fromRGB(255, 150, 40),
		Sky = Color3.fromRGB(70, 200, 255),
		Purple = Color3.fromRGB(180, 100, 255),
		Yellow = Color3.fromRGB(255, 230, 60),
		Red = Color3.fromRGB(255, 70, 80),
	} :: { [string]: Color3 },
	CritterLight = 7, -- studs of glow around each critter (0 = no light)
	HintLastSeconds = 10, -- in the last seconds the critters glow brighter, to help
	CatchPromptDistance = 9, -- gamepads: a "Catch!" button shows on critters this close

	-- Sounds (only the hunter hears them) --------------------------------------------------------
	Sounds = {
		Start = { SoundId = "rbxassetid://17798541626", Volume = 0.5 },
		Catch = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.6,
			PitchMin = 1.1,
			PitchMax = 1.35,
		},
		Miss = { SoundId = "rbxassetid://139800881181209", Volume = 0.4 },
		Tick = { SoundId = "rbxassetid://134410911353980", Volume = 0.4 }, -- last HintLastSeconds
		AllFound = { SoundId = "rbxassetid://1841209502", Volume = 0.6 },
		TimeUp = {
			SoundId = "rbxassetid://9045119921",
			Volume = 0.5,
			PitchMin = 0.8,
			PitchMax = 0.8,
		},
	} :: {
		Start: Sound,
		Catch: Sound,
		Miss: Sound,
		Tick: Sound,
		AllFound: Sound,
		TimeUp: Sound,
	},

	-- What it says on screen (%d = a number, %s = words) ------------------------------------------
	Text = {
		Title = "WEB SCOUR", -- also on the sign by the lantern
		Sign = "Find %d critters!", -- the small sign under it (%d = Critters)
		HintMouse = "Click the glowing critters in the webs!",
		HintTouch = "Tap the glowing critters in the webs!",
		HintGamepad = "Walk up to the glowing critters and catch them!",
		Progress = "%d/%d found",
		Stop = "Stop",
		Catch = "Catch!", -- the gamepad button on a critter
		TooFar = "Get closer!",
		AllFound = "You found them all!",
		TimeUp = "Time's up!",
		Stopped = "Hunt stopped.",
		Left = "You left the Spider Grove.",
		Round = "Off to the round!",
		Found = "%d/%d critters", -- in the finish banner
		Time = "Time: %s",
		NewBest = "New best time!",
		Best = "Best: %s",
		Coins = "+%d %s", -- coins and the currency name
		JustForFun = "Just for fun: coins again in %s",
		Busy = "You're already scouring the webs!",
		Wait = "Catch your breath... try again in a moment.",
		InRound = "You can scour the webs after the round.",
		NotReady = "Loading your save... try again in a moment.",
		NoSpots = "The webs are empty right now.",
	},
	BannerSeconds = 5, -- how long the finish banner stays up

	-- The Spider Grove (the look) ---------------------------------------------------------------
	-- Positions are in studs from the middle of the Web Scour zone, seen from the plaza:
	-- Vector3.new(right, up, back): right + = to the right, back + = further from the plaza.
	-- Changes here show after the hub is rebuilt (F8 > Rebuild hub, or bump
	-- Config.Hub.BuildVersion so a saved hub rebuilds).
	Grove = {
		Seed = 7, -- random twists in the trees (change it for different trees)
		Trees = { -- twisted trees the webs hang between (numbered 1, 2, 3... in this order)
			{ Offset = Vector3.new(-12.5, 0, 8), Height = 22 }, -- 1: back left
			{ Offset = Vector3.new(12.5, 0, 8), Height = 22 }, -- 2: back right
			{ Offset = Vector3.new(-14, 0, -6), Height = 15 }, -- 3: front left
			{ Offset = Vector3.new(14, 0, -6), Height = 15 }, -- 4: front right
		},
		-- Giant webs, each strung between two trees (their numbers above). Height = the web's
		-- middle above the ground, Radius = its size. Spots = where spiders can hide on it,
		-- as clock hours seen from the front (12 = top, 3 = right, 6 = bottom, 9 = left;
		-- halves like 2.5 work). Each spot snaps to the nearest knot where a ring thread
		-- crosses a spoke, so every spider sits on a strand.
		Webs = {
			{
				Between = { 1, 2 },
				Height = 10,
				Radius = 8.5,
				Spots = { 12, 1.5, 3, 4.5, 6, 7.5, 9, 10.5 },
			},
			{ Between = { 3, 1 }, Height = 7, Radius = 5.2, Spots = { 12, 3, 6, 9 } },
			{ Between = { 2, 4 }, Height = 7, Radius = 5.2, Spots = { 12, 3, 6, 9 } },
		},
		SpotDistance = 0.62, -- how far out on the web a spot is (0 = middle, 1 = the edge)
		Lantern = Vector3.new(-6.5, 0, -10), -- the start lantern's post (where you press the button)
		SpiderSize = 8, -- the big friendly spider sitting on top of the back web
		Mushrooms = 7, -- glowing mushrooms scattered on the grove floor
		Colors = {
			Web = Color3.fromRGB(225, 220, 255), -- the glowing web strands
			Bark = Color3.fromRGB(58, 40, 52), -- the twisted trees
			Floor = Color3.fromRGB(46, 52, 48), -- the mossy ground
			Spider = Color3.fromRGB(96, 56, 150), -- the big spider's body
			SpiderLegs = Color3.fromRGB(64, 36, 104),
			SpiderSpots = Color3.fromRGB(255, 150, 50),
			Cheeks = Color3.fromRGB(255, 130, 170),
			Lantern = Color3.fromRGB(150, 255, 120), -- the start lantern's glow
			MushroomCaps = { Color3.fromRGB(80, 230, 210), Color3.fromRGB(190, 120, 255) },
		},
	},
}
