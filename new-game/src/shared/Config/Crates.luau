--!strict
--[[
	CRATES (Config.Crates)

	Mystery crates give a random skin. On/off: Config.Features.Crates (Robux crates also need
	Config.Features.RobuxCrates). Players always see every skin in a crate and its exact chance
	before they open it (a Roblox rule for paid random items).

	HOW A CRATE PICKS A SKIN
	  1. It picks a rarity using the crate's Odds (percent: Common 70 means 70 in 100 opens).
	  2. It picks one skin of that rarity from the crate, every skin equally likely.
	  So one skin's chance = its rarity's odds / how many skins of that rarity the crate has.
	  Pumpkin Crate: 12 Commons share 70% (5.833% each), 5 Uncommons share 24.9% (4.980%
	  each), 2 Rares share 5% (2.500% each) and its one CRAZY skin has 0.100%.
	  A rarity with no skins in a crate is skipped and the others grow to fill 100%.

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
	Prices (themed crates): one open is worth about 362 coins on average at shop prices
	(0.70 x 125 + 0.249 x 500 + 0.05 x 1000 + 0.001 x 100000), or about 262 without the very
	rare CRAZY skin. 300 coins (about two rounds of pumpkins) is a fair gamble for a new player,
	and once you own most Commons, duplicates pay some coins back (Config/Rarity.luau,
	DuplicateRefund), so collecting the last skins of a theme in the shop is still worth it.
	Rarity crates cost a bit less than buying one skin of that rarity in the shop (125, 500,
	1000, 100000), because you don't get to choose which skin you get.
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
}

local rgb = Color3.fromRGB

return {
	-- The chance of each rarity (percent) for every crate without its own Odds. Must add up
	-- to 100. Rarity names are the ones in Config/Rarity.luau.
	Odds = { Common = 70, Uncommon = 24.9, Rare = 5, Crazy = 0.1 } :: { [string]: number },

	RequestCooldown = 1, -- seconds between two crate opens by the same player
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
		CrateSize = 2.6, -- studs, the crate box
		PromptDistance = 9, -- how close you must be to see "Open <crate>"
		Bob = 0.35, -- how far the crates float up and down (0 = they sit still)
	},

	-- Words players see (the crate panel, Menu > Crates, and the stand).
	Text = {
		Title = "Mystery Crates",
		Hint = "Tap a crate to see every skin inside and its chance.",
		Restricted = "Crates aren't available in your region; you can still buy any skin directly in the Shop.",
		Checking = "Checking...",
		OpenCoins = "Open  %s", -- %s = the price in coins
		OpenRobux = "R$ %d",
		ComingSoon = "Coming soon",
		RobuxOnly = "Robux only",
		WaitingRobux = "Finish the purchase in the Roblox window...",
		Chances = "What's inside",
		Owned = "Owned",
		New = "NEW!",
		Duplicate = "Duplicate! +%d %s", -- coins, currency name
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
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
		},
		{
			Id = "CandyCrate",
			Name = "Candy Crate",
			Blurb = "Sweets, sprinkles and sugar rushes.",
			Color = rgb(255, 120, 195),
			Trim = rgb(255, 245, 250),
			Glow = rgb(140, 240, 255),
			Topper = "Candies",
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
		},
		{
			Id = "SpookyCrate",
			Name = "Spooky Crate",
			Blurb = "Ghosts, witches and things that go boo.",
			Color = rgb(120, 70, 190),
			Trim = rgb(40, 28, 60),
			Glow = rgb(170, 255, 140),
			Topper = "Ghosts",
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
		},
		{
			Id = "GraveyardCrate",
			Name = "Graveyard Crate",
			Blurb = "Bones, lanterns and mossy old stones.",
			Color = rgb(120, 140, 125),
			Trim = rgb(60, 58, 66),
			Glow = rgb(130, 255, 200),
			Topper = "Bones",
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
		},
		{
			Id = "MonsterCrate",
			Name = "Monster Crate",
			Blurb = "Fuzzy, slimy and friendly (mostly).",
			Color = rgb(100, 200, 80),
			Trim = rgb(70, 40, 110),
			Glow = rgb(255, 240, 90),
			Topper = "Eyes",
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
		},
		{
			Id = "MoonlightCrate",
			Name = "Moonlight Crate",
			Blurb = "Stars, owls and silver moonbeams.",
			Color = rgb(70, 95, 190),
			Trim = rgb(225, 230, 255),
			Glow = rgb(190, 220, 255),
			Topper = "Stars",
			Price = 300,
			Robux = { ProductId = 0, SuggestedRobux = 49 },
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
			Price = 100,
			Robux = { ProductId = 0, SuggestedRobux = 19 },
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
			Price = 400,
			Robux = { ProductId = 0, SuggestedRobux = 69 },
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
			Price = 800,
			Robux = { ProductId = 0, SuggestedRobux = 129 },
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
			Price = 80000,
			-- Optional: leave ProductId at 0 to keep this one coins-only.
			Robux = { ProductId = 0, SuggestedRobux = 1999 },
		},
	} :: { Crate },
}
