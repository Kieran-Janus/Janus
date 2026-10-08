--!strict
--[[
	CRATES (Config.Crates)

	Mystery crates give a random skin. On/off: Config.Features.Crates (Robux crates also need
	Config.Features.RobuxCrates). Players always see every skin in a crate and its exact chance
	before they open it (a Roblox rule for paid random items).

	HOW A CRATE PICKS A SKIN
	  1. It picks a rarity using the crate's Odds (percent: Common 73.48 means 73.48 in 100 opens).
	  2. It picks one skin of that rarity from the crate, every skin equally likely.
	  So one skin's chance = its rarity's odds / how many skins of that rarity the crate has.
	  Pumpkin Crate: 12 Commons share 73.48% (6.123% each), 5 Uncommons share 24% (4.800%
	  each), 2 Rares share 2.5% (1.250% each) and its one CRAZY skin has 0.020%.
	  A rarity with no skins in a crate is skipped and the others grow to fill 100% (the newer
	  crates have no ordinary CRAZY skin, so their 13 Commons, 5 Uncommons and 3 Rares share it).
	  ONE IN A MILLION: a skin with its own Odds (in its theme file, e.g. Odds = 0.0001) has
	  exactly that chance (0.0001% = 1 open in a million), and the rest of the crate shares the
	  other 99.9999%. These skins (OneInAMillion = true) are never in the CRAZY Crate.
	  Rare and CRAZY were made rarer in the big skin update (Rare 5% -> 2.5%, CRAZY 0.1% ->
	  0.02%), so they stay special now that there are about 630 skins.

	WHICH SKINS ARE IN A CRATE
	  Themed crates: every skin whose Crate is that crate's Id (the theme files in
	  Config/Skins/ fill this in for you: every Pumpkin skin is in PumpkinCrate).
	  Rarity crates (they have Rarity = "Common" etc.): every crate skin of that rarity, from
	  every themed crate, all equally likely.

	CHANGE A PRICE   change Price (coins). Robux prices are set in Creator Hub (see Robux below).
	CHANGE THE ODDS  change Odds below (every themed crate) or give one crate its own
	                 Odds = { Common = 60, Uncommon = 30, Rare = 9.5, Crazy = 0.5 }. Keep the total
	                 at 100 (the shop shows the exact numbers to players).
	ADD A CRATE      copy one line in List, give it a new Id (never rename an Id once the game is
	                 live), a Name and colours, then put Crate = "<new Id>" on the skins it gives.
	                 It appears in Menu > Crates straight away. The crate stand in the lobby
	                 shows it once the hub is rebuilt (F8 > Rebuild hub, or Bake.Hub()). A hub
	                 you saved or Locked keeps its stand: copy a crate's <Id>Display model
	                 there and set the CrateId attribute of its CratePrompt part instead.
	SELL FOR ROBUX   make a Developer Product in Creator Hub (Monetization > Developer Products)
	                 and paste its id into that crate's Robux.ProductId. 0 = "Coming soon".
	                 SuggestedRobux is only a note for you: the real price is the one in Creator Hub.

	Each crate in List:
	  Id         unique name, saved nowhere but used by skins (Crate = "...") and the stand
	  Name       what players see
	  Blurb      one short line under the name
	  Color      the crate's main colour;  Trim  the bands and lid edge;  Glow  the glowing "?"
	  Topper     the little thing sitting on the lid: Pumpkins, Candies, Ghosts, Bones, Eyes,
	             Stars or Bats (the same pieces that fly around CRAZY skins), or Gem
	  Price      coins to open one (leave it out to sell the crate only for Robux)
	  Robux      { ProductId = 0, SuggestedRobux = 49 }
	  Rarity     (rarity crates only) the rarity it gives, 100% of the time
	  Odds       (optional) this crate's own odds instead of the ones below
	  Category   (optional) its tab in Menu > Crates (Categories below)
	  Look       its shape, emblem, extra colour and how it moves (LookDefaults below)
	  New        (optional) true = a NEW ribbon on its card in Menu > Crates
	Prices (themed crates): 600 coins, double the old 300, since there are now 30 crates and the
	best skins are much rarer: a crate is a gamble for the rare and the one-in-a-million skins,
	not the cheap way to get Commons (buy those in the shop for 125). One open is worth about
	257 coins at shop prices (0.7348 x 125 + 0.24 x 500 + 0.025 x 1000 + 0.0002 x 100000), and
	EVERY duplicate pays coins back (Config/Rarity.luau, DuplicateRefund: about half the shop
	price), so a crate never leaves you empty-handed.
	Rarity crates cost a bit less than buying one skin of that rarity in the shop (125, 500,
	1000, 100000), because you don't get to choose which skin you get. They were NOT doubled:
	doubled they would cost more than the shop.
	OPEN SEVERAL AT ONCE: Open.Counts (x1, x5, x10). The server rolls them all in one request
	and takes the coins in one go. QuickOpen skips the spinning strip and shows every result
	on one page.
]]

export type RobuxInfo = { ProductId: number, SuggestedRobux: number }

export type Crate = {
	Id: string,
	Name: string,
	Blurb: string,
	Color: Color3,
	Trim: Color3,
	Glow: Color3,
	Topper: string,
	Price: number?,
	Robux: RobuxInfo?,
	Rarity: string?,
	Odds: { [string]: number }?,
	Category: string?, -- which tab of Menu > Crates it is on (Categories below)
	Look: { [string]: any }?, -- its look and movement (LookDefaults below has every field)
	New: boolean?, -- shows a NEW ribbon in Menu > Crates
}

local rgb = Color3.fromRGB

return {
	-- The chance of each rarity (percent) for every crate without its own Odds. Must add up
	-- to 100. Rarity names are the ones in Config/Rarity.luau.
	Odds = { Common = 73.48, Uncommon = 24, Rare = 2.5, Crazy = 0.02 } :: { [string]: number },
	-- How a chance under 1% is shown on the crate panel ("<1%"; "" = the exact number, e.g.
	-- "0.0001%"). Larger chances show with one decimal ("6.1%").
	SmallOdds = "<1%",

	RequestCooldown = 1, -- seconds between two crate opens by the same player
	-- Open several at once: the buttons on a crate's page (each costs Count x Price, taken in one
	-- go). The server rolls them all in one request (RequestCooldown still applies).
	Open = {
		Counts = { 1, 5, 10 },
		SkipKey = Enum.KeyCode.Space, -- jumps straight to the result while the strip spins
	},
	-- Quick open: a switch on the crate page. On = no spinning strip: every result at once on one
	-- page, in a grid with rarity colours, duplicates marked with their coins back and the best
	-- skin highlighted.
	QuickOpen = {
		Default = false, -- the switch's starting position
		Columns = 5, -- results per row (phones use PhoneColumns)
		PhoneColumns = 3,
	},
	-- The tabs of Menu > Crates (each crate's Category). A crate with no Category goes on the
	-- first tab. Crates per page = PageSize (PhonePageSize on phones).
	Categories = {
		"Classic",
		"Monsters",
		"Haunted Places",
		"Creepy Critters",
		"Sweet & Silly",
		"By Rarity",
	},
	PageSize = 8,
	PhonePageSize = 6,
	-- A server-wide announcement when anyone unboxes a CRAZY skin (Config.Announce has the looks).
	AnnounceCrazy = true,
	-- Seconds the announcement waits after the crate is opened, so the winner sees their own
	-- reveal first (about the length of the opening: drop, shake, burst, fly, pedestal).
	AnnounceDelay = 4.5,
	-- After winning one of these rarities the save is written straight away (other wins are
	-- saved by the normal autosave, Config.Data.AutosaveSeconds).
	SaveRightAway = { Rare = true, Crazy = true } :: { [string]: boolean },

	-- The opening animation: a strip of skin cards spins sideways and slows down on your skin.
	-- The other cards on the strip are real random picks from the same crate (no fake "near
	-- misses").
	Reel = {
		Cards = 32, -- cards on the strip
		WinIndex = 28, -- the card that is your skin (a few more come after it)
		SpinSeconds = 5.5, -- how long the strip spins
		CardWidth = 112, -- UI units (phones use PhoneCardWidth)
		PhoneCardWidth = 92,
		CardGap = 8,
		RevealDelay = 0.4, -- pause between the strip stopping and the big reveal
		-- The cards get their 3D skin picture once the strip slows down to this many cards a
		-- second (while it whizzes past they show the name and rarity colour). Building a 3D
		-- picture for every card at full speed made phones stutter. Higher = pictures sooner.
		PreviewSpeed = 4,
	},

	-- HOW A CRATE LOOKS AND MOVES. Every crate in List has its own Look (Style, Emblem, Accent);
	-- anything it leaves out comes from LookDefaults. Colours come from the crate's Color
	-- (body), Trim (bands, lid edge) and Glow (glowing bits); Accent is one extra colour (the
	-- pumpkin's leaves, the candy box's bow, the ghost, the moss, the monster's teeth, the
	-- stars). Change a number here and every crate follows; give one crate its own (e.g.
	-- Look = { Style = "Monster", Shake = 1.6 }) to change only that one.
	--   Style    the shape of the built chest: "Pumpkin" (carved pumpkin, leafy lid), "Candy"
	--            (wrapped candy box with a bow), "Coffin" (coffin crate, a ghost peeking out),
	--            "Tomb" (mossy tombstone chest), "Monster" (furry, googly eyes, teeth), "Moon"
	--            (starry chest, crescent moon) or "Chest" (a chunky chest with its Emblem)
	--   Emblem   on the front of a "Chest": a head piece name (src/shared/HeadPieces.luau,
	--            e.g. "WolfHead", "ClownHead") or "Gem"; "" = none
	-- Every built chest has a part named "Lid" that opens. Your own crate model (a Model named
	-- after the crate's Id in ReplicatedStorage.Custom.Props) bobs and shakes the same way;
	-- its lid only opens if it has a part named "Lid".
	LookDefaults = {
		Style = "Chest",
		Emblem = "",
		Bob = 0.18, -- studs up and down while it waits on the stand
		Sway = 3, -- degrees it rocks from side to side while it waits
		PeekEvery = 7, -- seconds between lid peeks (0 = never)
		PeekAngle = 28, -- degrees the lid lifts when it peeks
		Shake = 1, -- how hard it shakes before it opens (1 = normal, 2 = twice as hard)
		Sparkles = 10, -- sparkles in a peek puff (phones get Idle.PhoneSparkleShare of them)
		-- Sounds for this crate on the stand ({ SoundId = "rbxassetid://...", Volume = 0.4 };
		-- SoundId = "" = silent).
		Sounds = {
			Peek = { SoundId = "", Volume = 0.3 },
			Wake = { SoundId = "", Volume = 0.4 },
		},
	},

	-- The crates on the lobby stand come alive (client side, only for crates near the camera).
	Idle = {
		On = true,
		Range = 70, -- studs from the camera: crates further away sit still
		PhoneRange = 40,
		PhoneSparkleShare = 0.35, -- phones show this share of the sparkles
		WakeDistance = 11, -- studs: when you walk this close a crate wakes up
		WiggleSeconds = 0.6, -- its happy wiggle when it wakes up
		WakeLabel = true, -- name, price and an "Odds" button float above an awake crate
		GlowRing = true, -- a soft glowing ring under each crate, in its Glow colour
		GlowRingTransparency = 0.8,
		EyeRange = 30, -- the Monster crate's eyes follow the nearest player this close
		-- (src/client/CrateIdle.luau does all of this.) Finer settings:
		BobSpeed = 1.6, -- how fast it bobs (bigger = faster)
		SwaySpeed = 1.1, -- how fast it rocks from side to side
		PeekSeconds = 1.2, -- how long one lid peek takes (open and shut again)
		PeekLightBrightness = 2.5, -- the puff of coloured light when the lid peeks
		PeekLightRange = 9, -- studs the puff of light reaches
		SparkleSpeed = 6, -- how fast the peek sparkles fly up
		SparkleSize = 0.3, -- studs, one sparkle
		SparkleLifetime = 0.9, -- seconds a sparkle lasts
		WakeHysteresis = 2, -- studs: an awake crate falls asleep at WakeDistance + this
		WiggleHops = 2, -- little hops in the happy wiggle
		WiggleHeight = 0.5, -- studs, how high it hops
		WiggleTwist = 14, -- degrees it twists while it hops
		GlowRingScale = 1.25, -- the ring's width compared with the crate's
		GlowRingThickness = 0.05, -- studs
		GlowRingDrop = 0.2, -- studs below the crate's bottom
		EyeSpeed = 8, -- how quickly the Monster crate's pupils catch up (bigger = snappier)
		-- The floating label over an awake crate (UI units; text never smaller than
		-- Config.UI.MinTextSize). Its price is the real one: coins from Price, Robux from Roblox
		-- (only when the crate has a Robux.ProductId).
		LabelWidth = 220,
		LabelHeight = 104,
		PhoneLabelWidth = 180,
		PhoneLabelHeight = 92,
		LabelAbove = 2.2, -- studs above the top of the crate
		LabelTextSize = 18,
		LabelCoins = "%s %s", -- price, currency name: "600 Coins"
		LabelRobux = "R$ %d",
		LabelBoth = "%s  or  %s", -- coins, Robux
		LabelOdds = "Odds", -- the button that opens the crate panel (every skin and its chance)
	},

	-- Opening a crate (Style "Chest"): the chest drops in and bounces, shakes faster and
	-- faster, then the lid bursts open with a beam in the colour of the rarity you really
	-- won, and the skin flies out onto a spinning pedestal before the reveal card. Space or a
	-- tap skips; Quick open shows every result at once. Style "Reel" = the old spinning strip.
	Opening = {
		Style = "Chest",
		DropSeconds = 0.5,
		ShakeSeconds = 1.5, -- about how long it shakes (faster and faster)
		BurstSeconds = 0.6, -- the lid flying open and the beam
		FlySeconds = 0.7, -- the skin flying out onto the pedestal
		PedestalSeconds = 1.2, -- the skin spinning on its pedestal before the reveal card
		CameraDistance = 3.8, -- how far the camera is from the chest, in chest widths (smaller = bigger chest)
		PhoneCameraDistance = 3, -- the same on phones (closer: a bigger chest on a small screen)
		-- The beam's colour for each rarity (CRAZY is a rainbow).
		BeamColors = {
			Common = rgb(160, 200, 150),
			Uncommon = rgb(80, 150, 255),
			Rare = rgb(185, 95, 255),
		} :: { [string]: Color3 },
		RainbowRarities = { Crazy = true } :: { [string]: boolean },
		-- How the beam looks: a soft fan of light pouring up out of the chest (a few faint
		-- overlapping shafts, brightest in the middle), slow rays turning behind it and a
		-- quick white flash when the lid bursts. Sizes are fractions of the stage's height.
		Beam = {
			Height = 0.8, -- how tall the light reaches above the chest
			Width = 0.13, -- how wide each shaft of light is
			Shafts = 7, -- shafts in the fan (more = softer edges; phones: PhoneShafts)
			PhoneShafts = 5,
			Spread = 16, -- degrees the fan opens to each side (0 = a straight column)
			ShaftTransparency = 0.72, -- how see-through one shaft is (they add up in the middle)
			Sway = 3, -- degrees the shafts drift side to side
			SwaySpeed = 1.6, -- how fast they drift
			Shimmer = 0.35, -- how much the light flickers (0 = steady, 1 = a lot)
			ShimmerSpeed = 7,
			Rays = 6, -- straight rays turning slowly behind the chest (each makes two spokes)
			RayLength = 1.5, -- how far the rays reach
			RayWidth = 0.05,
			RayTransparency = 0.8,
			RaySpeed = 18, -- degrees a second the rays turn
			HoldFade = 0.6, -- how much the light dims once the skin is on its pedestal (0-1)
			FlashSeconds = 0.3, -- the white flash when the lid bursts (0 = no flash)
			FlashTransparency = 0.25, -- how strong the flash starts (0 = solid white)
		},
		Confetti = 70, -- confetti pieces for a CRAZY (phones: PhoneConfetti)
		PhoneConfetti = 25,
		CoinPour = 14, -- coins pouring out for a duplicate (phones: PhoneCoinPour)
		PhoneCoinPour = 6,
		CoinsBack = "+%d coins back", -- %d = the coins a duplicate pays back
		-- The cards either side of yours on the strip (Style "Reel") never show a rarer skin
		-- than the one you won: no teasing "near misses".
		TeaseGuard = 2,
		ShakeDegrees = 7, -- how far it rocks at the end of the shake (x the crate's Look.Shake)
		ShakeStuds = 0.12, -- how far it jiggles sideways at the end of the shake (x Look.Shake)
		ShakeTickStart = 0.3, -- seconds between shake sounds at the start...
		ShakeTickEnd = 0.07, -- ...and at the end (faster and faster)
		LidAngle = 115, -- degrees the lid flies open (a crate without a lid pops instead)
		PedestalSpin = 90, -- degrees a second the skin turns on its pedestal
		CrazySeconds = 3.5, -- how long the full-screen rainbow and confetti last for a CRAZY
		Sounds = {
			Drop = { SoundId = "", Volume = 0.5 },
			Shake = {
				SoundId = "rbxassetid://87437544236708",
				Volume = 0.2,
				PitchMin = 0.9,
				PitchMax = 1.4,
			},
			Burst = { SoundId = "rbxassetid://120891770644830", Volume = 0.6 },
			Coins = { SoundId = "rbxassetid://4612374807", Volume = 0.5 },
			CrazyBurst = { SoundId = "rbxassetid://1841209502", Volume = 0.9 },
		} :: {
			[string]: { SoundId: string, Volume: number?, PitchMin: number?, PitchMax: number? },
		},
	},

	-- The crate cards in Menu > Crates: each chest turns slowly in its picture (only cards on
	-- screen, only while the panel is open) with a soft halo in the crate's Glow colour, and
	-- the card bounces when tapped.
	Cards = {
		SpinSpeed = 30, -- degrees a second (0 = the chests stand still)
		Halo = true,
		HaloTransparency = 0.55, -- 0 = solid, 1 = invisible
		PopSeconds = 0.14, -- the bounce when a card is tapped, before its page opens
	},

	-- Roblox's paid random items rule (PolicyService): players in a region where paid random
	-- items aren't allowed can't open any crate (coins can be bought with Robux, so coin crates
	-- count too). They can still buy every skin straight from the Shop. If Roblox can't tell
	-- us, crates stay closed for that player (in Studio playtests they stay open instead, with
	-- a warning, so you can test them).
	Policy = {
		TestAsRestricted = false, -- true = in Studio, act like a player whose region blocks crates
		Attempts = 3, -- how many times to ask Roblox before giving up
		RetrySeconds = 2,
		WaitSeconds = 15, -- a Robux crate bought while still asking waits this long for the answer
	},

	-- A Robux crate bought by a player who can't open crates (their region, or crates were
	-- switched off before the purchase finished) gives coins instead of a random skin: the
	-- crate's coin Price, or this many coins for a crate sold only for Robux (no Price).
	-- Keep it above 0: with 0 the purchase is left unfinished (Roblox asks again later).
	RobuxFallbackCoins = 500,

	-- F8 admin panel buttons (Studio playtests).
	Admin = {
		FreeCrate = "PumpkinCrate", -- "Crates: open free ..." opens this one without paying
		Coins = 100000, -- "Crates: +100k coins"
	},

	-- Sounds you hear while opening (any "rbxassetid://..." id; "" = silent).
	Sounds = {
		Tick = {
			SoundId = "rbxassetid://87437544236708",
			Volume = 0.25,
			PitchMin = 1.1,
			PitchMax = 1.3,
		},
		Reveal = { SoundId = "rbxassetid://120891770644830", Volume = 0.6 },
		Rare = { SoundId = "rbxassetid://9045119921", Volume = 0.7 }, -- Rare reveal
		Crazy = { SoundId = "rbxassetid://1841209502", Volume = 0.9 }, -- CRAZY reveal
	} :: {
		[string]: { SoundId: string, Volume: number?, PitchMin: number?, PitchMax: number? },
	},

	-- The crate stand in the lobby (src/server/Hub/Sections/CrateStand.luau), in the
	-- Config.Lobby.Zones.Crates area next to the Pumpkin Shop. Every crate in List below is
	-- shown: themed crates on the low front row, rarity crates raised up behind them.
	-- Changes here show after the hub is rebuilt (F8 > Rebuild hub, or Bake.Hub()); a hub
	-- saved in the place keeps the stand it was built with.
	Stand = {
		SignText = "MYSTERY CRATES",
		-- The themed crates on the stand (it has room for six; every crate is in Menu > Crates).
		Themed = {
			"PumpkinCrate",
			"CandyCrate",
			"SpookyCrate",
			"GraveyardCrate",
			"MonsterCrate",
			"MoonlightCrate",
		},
		CrateSize = 2.6, -- studs, the crate box
		PromptDistance = 9, -- how close you must be to see "Open <crate>"
		-- How far the crates float up and down (0 = they sit still). Only while Idle.On is false:
		-- with it on, each crate's Look.Bob is used instead.
		Bob = 0.35,
		-- The light under each crate (in its colour). Brighter washes the painted chests out.
		LightBrightness = 0.6,
	},

	-- Words players see (the crate panel, Menu > Crates, and the stand).
	Text = {
		Title = "Mystery Crates",
		Hint = "Tap a crate to see every skin inside and its chance.",
		Restricted = "Crates aren't available in your region; you can still buy any skin directly in the Shop.",
		Checking = "Checking...",
		OpenCoins = "Open %s %s", -- price, currency name ("Open 600 Coins")
		OpenRobux = "R$ %d", -- always says R$, so a Robux price is never mistaken for coins
		ComingSoon = "Coming soon",
		RobuxOnly = "Robux only",
		WaitingRobux = "Finish the purchase in the Roblox window...",
		Chances = "What's inside",
		Owned = "Owned",
		New = "NEW!",
		Duplicate = "Duplicate! +%d %s back", -- coins, currency name
		DuplicateShort = "Duplicate! +%d", -- on a small result card
		OpenMany = "x%d  %s %s", -- the open buttons: count, price, currency name
		NewRibbon = "NEW", -- the ribbon on a crate card with New = true
		OddsButton = "Odds", -- the small button on each crate card (every skin and its chance)
		QuickOpen = "Quick open",
		SkipHint = "Space = skip",
		Next = "Next (%d left)", -- after a reveal, when several were opened
		Results = "You opened %d crates!",
		Best = "BEST!",
		CoinsBack = "Duplicates paid back %d %s",
		Page = "%d / %d",
		OneInAMillion = "ONE IN A MILLION!",
		AnnounceCrazy = "%s unboxed the CRAZY skin %s!", -- player, skin
		AnnounceMillion = "%s unboxed %s: a ONE IN A MILLION skin!!!",
		Equip = "Equip now",
		Wearing = "Wearing it!",
		OpenAnother = "Open another",
		Back = "Back",
		Skip = "Skip",
		ShopButton = "Buy in the Shop",
		ShopChip = "🎁 Crates", -- the button on the Shop's Skins tab that opens the crates
		Prompt = "Open %s", -- the stand's prompt; %s = the crate's name
		PromptObject = "Mystery Crate",
		-- Messages from the server
		Closed = "Crates are closed right now.",
		NoCrate = "That crate isn't for sale.",
		NoCoins = "You need %d more %s.",
		SlowDown = "Slow down!",
		NotLoaded = "Your save is still loading.",
		StillChecking = "Still checking if crates are allowed for you. Try again in a moment.",
		RobuxInstead = "Crates aren't available for you, so you got %d %s instead.",
	},

	List = {
		-- THEMED CRATES (one per skin theme, Config/Skins/Settings.luau) ----------------------
		{
			Id = "PumpkinCrate",
			Name = "Pumpkin Crate",
			Blurb = "Carved, candlelit and a little bit spicy.",
			Color = rgb(255, 130, 20),
			Trim = rgb(92, 52, 24),
			Glow = rgb(255, 220, 110),
			Topper = "Pumpkins",
			Look = { Style = "Pumpkin", Accent = rgb(90, 170, 60) },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218517, SuggestedRobux = 79 },
		},
		{
			Id = "CandyCrate",
			Name = "Candy Crate",
			Blurb = "Sweets, sprinkles and sugar rushes.",
			Color = rgb(255, 120, 195),
			Trim = rgb(255, 245, 250),
			Glow = rgb(140, 240, 255),
			Topper = "Candies",
			Look = { Style = "Candy", Accent = rgb(120, 220, 255) },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218522, SuggestedRobux = 79 },
		},
		{
			Id = "SpookyCrate",
			Name = "Spooky Crate",
			Blurb = "Ghosts, witches and things that go boo.",
			Color = rgb(120, 70, 190),
			Trim = rgb(40, 28, 60),
			Glow = rgb(170, 255, 140),
			Topper = "Ghosts",
			Look = { Style = "Coffin", Accent = rgb(240, 245, 255) },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218525, SuggestedRobux = 79 },
		},
		{
			Id = "GraveyardCrate",
			Name = "Graveyard Crate",
			Blurb = "Bones, lanterns and mossy old stones.",
			Color = rgb(120, 140, 125),
			Trim = rgb(60, 58, 66),
			Glow = rgb(130, 255, 200),
			Topper = "Bones",
			Look = { Style = "Tomb", Accent = rgb(95, 150, 75) },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218527, SuggestedRobux = 79 },
		},
		{
			Id = "MonsterCrate",
			Name = "Monster Crate",
			Blurb = "Fuzzy, slimy and friendly (mostly).",
			Color = rgb(100, 200, 80),
			Trim = rgb(70, 40, 110),
			Glow = rgb(255, 240, 90),
			Topper = "Eyes",
			Look = { Style = "Monster", Accent = rgb(255, 250, 235), Shake = 1.4 },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218530, SuggestedRobux = 79 },
		},
		{
			Id = "MoonlightCrate",
			Name = "Moonlight Crate",
			Blurb = "Stars, owls and silver moonbeams.",
			Color = rgb(70, 95, 190),
			Trim = rgb(225, 230, 255),
			Glow = rgb(190, 220, 255),
			Topper = "Stars",
			Look = { Style = "Moon", Accent = rgb(255, 240, 150) },
			Category = "Classic",
			Price = 600,
			Robux = { ProductId = 3717218537, SuggestedRobux = 79 },
		},

		-- THE NEWER THEMED CRATES (in Menu > Crates; the lobby stand shows the ones in Stand.Themed).
		-- Three of them hold a ONE IN A MILLION skin (its own Odds in its theme file).
		{
			Id = "VampireCastleCrate",
			Name = "Vampire Castle Crate",
			Blurb = "Capes, fangs and candlelit halls. Holds a ONE IN A MILLION skin!",
			Color = rgb(150, 20, 40),
			Trim = rgb(30, 15, 30),
			Glow = rgb(255, 80, 100),
			Topper = "Bats",
			Look = { Emblem = "VampireHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218542, SuggestedRobux = 79 },
		},
		{
			Id = "ZombieTownCrate",
			Name = "Zombie Town Crate",
			Blurb = "Shuffling neighbours who really like brains.",
			Color = rgb(110, 150, 80),
			Trim = rgb(80, 60, 50),
			Glow = rgb(220, 255, 120),
			Topper = "Eyes",
			Look = { Emblem = "ZombieHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218548, SuggestedRobux = 79 },
		},
		{
			Id = "WerewolfWoodsCrate",
			Name = "Werewolf Woods Crate",
			Blurb = "Howls, flannel and a very full moon.",
			Color = rgb(120, 85, 60),
			Trim = rgb(40, 70, 45),
			Glow = rgb(230, 230, 255),
			Topper = "Stars",
			Look = { Emblem = "WolfHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218553, SuggestedRobux = 79 },
		},
		{
			Id = "MummyTombCrate",
			Name = "Mummy Tomb Crate",
			Blurb = "Wrapped, golden and a little bit cursed.",
			Color = rgb(225, 200, 140),
			Trim = rgb(40, 70, 170),
			Glow = rgb(255, 215, 90),
			Topper = "Gem",
			Look = { Emblem = "MummyHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218557, SuggestedRobux = 79 },
		},
		{
			Id = "SkeletonCrewCrate",
			Name = "Skeleton Crew Crate",
			Blurb = "A rattling pirate crew, bones and all.",
			Color = rgb(240, 235, 215),
			Trim = rgb(40, 50, 100),
			Glow = rgb(255, 220, 120),
			Topper = "Bones",
			Look = { Emblem = "SkinSkull" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218558, SuggestedRobux = 79 },
		},
		{
			Id = "SwampCreaturesCrate",
			Name = "Swamp Creatures Crate",
			Blurb = "Croaks, bubbles and mud between your toes.",
			Color = rgb(60, 140, 120),
			Trim = rgb(90, 80, 50),
			Glow = rgb(160, 255, 120),
			Topper = "Eyes",
			Look = { Emblem = "FrogHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218561, SuggestedRobux = 79 },
		},
		{
			Id = "GoblinMarketCrate",
			Name = "Goblin Market Crate",
			Blurb = "Shady deals from the greenest traders.",
			Color = rgb(110, 170, 60),
			Trim = rgb(120, 80, 50),
			Glow = rgb(255, 210, 80),
			Topper = "Gem",
			Look = { Emblem = "GoblinHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Monsters",
			Price = 600,
			Robux = { ProductId = 3717218565, SuggestedRobux = 79 },
		},
		{
			Id = "HauntedCarnivalCrate",
			Name = "Haunted Carnival Crate",
			Blurb = "Step right up... if you dare.",
			Color = rgb(220, 40, 50),
			Trim = rgb(255, 210, 50),
			Glow = rgb(120, 255, 240),
			Topper = "Candies",
			Look = { Emblem = "ClownHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218568, SuggestedRobux = 79 },
		},
		{
			Id = "HauntedHotelCrate",
			Name = "Haunted Hotel Crate",
			Blurb = "Check in any time. Never check out.",
			Color = rgb(150, 20, 40),
			Trim = rgb(220, 180, 80),
			Glow = rgb(255, 240, 180),
			Topper = "Ghosts",
			Look = { Emblem = "BellhopHat" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218571, SuggestedRobux = 79 },
		},
		{
			Id = "GhostShipCrate",
			Name = "Ghost Ship Crate",
			Blurb = "A phantom crew sailing through the mist.",
			Color = rgb(40, 70, 110),
			Trim = rgb(190, 160, 110),
			Glow = rgb(140, 255, 240),
			Topper = "Ghosts",
			Look = { Emblem = "CaptainHat" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218576, SuggestedRobux = 79 },
		},
		{
			Id = "PhantomTheatreCrate",
			Name = "Phantom Theatre Crate",
			Blurb = "Masks, curtains and a ghostly encore.",
			Color = rgb(160, 20, 40),
			Trim = rgb(225, 185, 80),
			Glow = rgb(255, 245, 200),
			Topper = "Stars",
			Look = { Emblem = "PhantomMask" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218577, SuggestedRobux = 79 },
		},
		{
			Id = "GraveyardPartyCrate",
			Name = "Graveyard Party Crate",
			Blurb = "The dead really know how to party.",
			Color = rgb(255, 110, 190),
			Trim = rgb(70, 70, 80),
			Glow = rgb(255, 230, 90),
			Topper = "Bones",
			Look = { Emblem = "PartyHat" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218579, SuggestedRobux = 79 },
		},
		{
			Id = "MadScientistLabCrate",
			Name = "Mad Scientist Lab Crate",
			Blurb = "Bubbling beakers and crackling coils.",
			Color = rgb(235, 240, 245),
			Trim = rgb(60, 170, 255),
			Glow = rgb(140, 255, 90),
			Topper = "Gem",
			Look = { Emblem = "FrankenHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Haunted Places",
			Price = 600,
			Robux = { ProductId = 3717218581, SuggestedRobux = 79 },
		},
		{
			Id = "BatCaveCrate",
			Name = "Bat Cave Crate",
			Blurb = "Echoes, crystals and upside-down naps.",
			Color = rgb(70, 60, 90),
			Trim = rgb(150, 140, 130),
			Glow = rgb(200, 150, 255),
			Topper = "Bats",
			Look = { Emblem = "BatHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Creepy Critters",
			Price = 600,
			Robux = { ProductId = 3717218584, SuggestedRobux = 79 },
		},
		{
			Id = "SpiderLairCrate",
			Name = "Spider Lair Crate",
			Blurb = "Eight legs, many eyes, lots of webs.",
			Color = rgb(40, 30, 50),
			Trim = rgb(230, 230, 240),
			Glow = rgb(150, 255, 80),
			Topper = "Eyes",
			Look = { Emblem = "SpiderCrown" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Creepy Critters",
			Price = 600,
			Robux = { ProductId = 3717218586, SuggestedRobux = 79 },
		},
		{
			Id = "BlackCatAlleyCrate",
			Name = "Black Cat Alley Crate",
			Blurb = "Nine lives of midnight mischief.",
			Color = rgb(30, 25, 40),
			Trim = rgb(150, 70, 55),
			Glow = rgb(160, 255, 90),
			Topper = "Eyes",
			Look = { Emblem = "CatHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Creepy Critters",
			Price = 600,
			Robux = { ProductId = 3717218590, SuggestedRobux = 79 },
		},
		{
			Id = "ScarecrowFarmCrate",
			Name = "Scarecrow Farm Crate",
			Blurb = "Straw, crows and a field full of pumpkins.",
			Color = rgb(230, 200, 110),
			Trim = rgb(180, 50, 40),
			Glow = rgb(255, 180, 70),
			Topper = "Pumpkins",
			Look = { Emblem = "ScarecrowHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Creepy Critters",
			Price = 600,
			Robux = { ProductId = 3717218593, SuggestedRobux = 79 },
		},
		{
			Id = "AlienAbductionCrate",
			Name = "Alien Abduction Crate",
			Blurb = "Beamed up from far away. Holds a ONE IN A MILLION skin!",
			Color = rgb(120, 230, 90),
			Trim = rgb(200, 205, 215),
			Glow = rgb(90, 240, 255),
			Topper = "Stars",
			Look = { Emblem = "AlienHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Creepy Critters",
			Price = 600,
			Robux = { ProductId = 3717218597, SuggestedRobux = 79 },
		},
		{
			Id = "CursedToysCrate",
			Name = "Cursed Toys Crate",
			Blurb = "Toys that play with you when the lights go out.",
			Color = rgb(240, 140, 180),
			Trim = rgb(80, 150, 240),
			Glow = rgb(255, 230, 120),
			Topper = "Stars",
			Look = { Emblem = "TeddyHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218602, SuggestedRobux = 79 },
		},
		{
			Id = "MonsterDiscoCrate",
			Name = "Monster Disco Crate",
			Blurb = "Funky beats and glitter. Holds a ONE IN A MILLION skin!",
			Color = rgb(160, 60, 255),
			Trim = rgb(255, 210, 60),
			Glow = rgb(255, 120, 230),
			Topper = "Stars",
			Look = { Emblem = "DiscoAfro" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218605, SuggestedRobux = 79 },
		},
		{
			Id = "CandyFactoryCrate",
			Name = "Candy Factory Crate",
			Blurb = "Fresh off the sugary conveyor belt.",
			Color = rgb(255, 140, 200),
			Trim = rgb(140, 240, 200),
			Glow = rgb(255, 245, 140),
			Topper = "Candies",
			Look = { Emblem = "GumballHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218610, SuggestedRobux = 79 },
		},
		{
			Id = "WitchsBrewCrate",
			Name = "Witch's Brew Crate",
			Blurb = "Bubble, bubble, a brand-new look.",
			Color = rgb(100, 40, 140),
			Trim = rgb(30, 25, 35),
			Glow = rgb(130, 255, 100),
			Topper = "Stars",
			Look = { Emblem = "CauldronHat" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218614, SuggestedRobux = 79 },
		},
		{
			Id = "FrostyFrightCrate",
			Name = "Frosty Fright Crate",
			Blurb = "A chilly scare from the snowy north.",
			Color = rgb(140, 200, 255),
			Trim = rgb(240, 245, 255),
			Glow = rgb(200, 250, 255),
			Topper = "Stars",
			Look = { Emblem = "SnowmanHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218619, SuggestedRobux = 79 },
		},
		{
			Id = "AutumnLeavesCrate",
			Name = "Autumn Leaves Crate",
			Blurb = "Crunchy leaves, cosy scarves and acorns.",
			Color = rgb(230, 130, 40),
			Trim = rgb(110, 75, 45),
			Glow = rgb(255, 210, 90),
			Topper = "Pumpkins",
			Look = { Emblem = "AcornHead" },
			New = true, -- the NEW ribbon in Menu > Crates
			Category = "Sweet & Silly",
			Price = 600,
			Robux = { ProductId = 3717218622, SuggestedRobux = 79 },
		},

		-- RARITY CRATES (every crate skin of one rarity, from every theme) ---------------------
		{
			Id = "CommonCrate",
			Name = "Common Crate",
			Blurb = "A Common skin from any theme.",
			Rarity = "Common",
			Color = rgb(150, 175, 140),
			Trim = rgb(70, 80, 66),
			Glow = rgb(235, 255, 225),
			Topper = "Gem",
			Look = { Emblem = "Gem" },
			Category = "By Rarity",
			Price = 100,
			Robux = { ProductId = 3717218625, SuggestedRobux = 19 },
		},
		{
			Id = "UncommonCrate",
			Name = "Uncommon Crate",
			Blurb = "An Uncommon skin (with a head piece) from any theme.",
			Rarity = "Uncommon",
			Color = rgb(70, 150, 255),
			Trim = rgb(30, 50, 110),
			Glow = rgb(190, 230, 255),
			Topper = "Gem",
			Look = { Emblem = "Gem" },
			Category = "By Rarity",
			Price = 400,
			Robux = { ProductId = 3717218630, SuggestedRobux = 69 },
		},
		{
			Id = "RareCrate",
			Name = "Rare Crate",
			Blurb = "A glowing Rare skin from any theme.",
			Rarity = "Rare",
			Color = rgb(175, 90, 255),
			Trim = rgb(60, 25, 100),
			Glow = rgb(255, 210, 255),
			Topper = "Gem",
			Look = { Emblem = "Gem" },
			Category = "By Rarity",
			Price = 800,
			Robux = { ProductId = 3717218636, SuggestedRobux = 129 },
		},
		{
			Id = "CrazyCrate",
			Name = "CRAZY Crate",
			Blurb = "One of the six one-of-a-kind CRAZY skins!",
			Rarity = "Crazy",
			Color = rgb(255, 60, 200),
			Trim = rgb(255, 215, 70),
			Glow = rgb(255, 255, 255),
			Topper = "Gem",
			Look = { Emblem = "Gem", Shake = 1.6 },
			Category = "By Rarity",
			Price = 80000,
			-- Optional: leave ProductId at 0 to keep this one coins-only.
			Robux = { ProductId = 3717218640, SuggestedRobux = 1999 },
		},
	} :: { Crate },
}
