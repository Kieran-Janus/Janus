--!strict
--[[
	THE tweak file. Every number, name, price and AI persona lives here.
	Want a longer round? Change Round.Duration. Want a new NPC? Add to AI.Npcs.
	Nothing else in the codebase should hardcode gameplay values.

	The v2 settings each have their own short file in this folder (src/shared/Config/):
	  Features.luau    on/off switch for every v2 feature (start here!)
	  Modes.luau       game modes and the mode + map pairs offered in the vote
	  Lobby.luau       lobby areas, the Ready pad and spectating
	  Parkour.luau, Minigames.luau, EasterEggs.luau, HideSeek.luau, ScareMaze.luau
	  Rarity.luau      Common / Uncommon / Rare / CRAZY prices and colours
	  Crates.luau      crates and their odds
	  MapLife.luau     round maps come alive (bobbing pumpkins, fireflies, wobbling decoys)
	  ScreenMotion.luau  animations of the Hide & Seek, ScareMaze, ghost, spectate, rewards,
	                   NPC dialogue, announcement and Voting Board screens
	  Menu.luau        the top-left menu tiles
	  Maps/<Id>.luau   one file per round map (added to Maps.List below)
	  Skins/           crate skins, one file per theme (added to Shop.Items below), and
	                   Skins/Settings.luau (Config.Skins: themes, glow, auras, CRAZY effects)
	Everything is still read the same way: Config.Features.Parkour, Config.Lobby.Zones, ...
]]

-- One hub NPC (Npcs.List below). Give it a Zone (it stands in the middle of that lobby zone)
-- or an Offset (studs from Hub.Center). It faces the middle of the hub, or LookAt (studs from
-- Hub.Center) if it has one. OpensShop is optional.
export type NpcDef = {
	Id: string,
	Kind: string,
	DisplayName: string,
	Zone: string?,
	Offset: Vector3?,
	LookAt: Vector3?,
	Prompt: { ActionText: string, ObjectText: string },
	OpensShop: string?,
	Lines: { string },
}

--[[
	LOBBY COLOURS (Config.Hub.Palette). Each name is a colour "role". Every lobby part painted
	from here has the attribute PaletteRole (see it in Studio: select a part > Properties >
	Attributes), plus PaletteShade when it is a darker (0.3 = 30% darker) or lighter (-0.2)
	version of that colour. Change a colour below and every part with that role follows the
	next time the game starts (also on a hand-edited, Locked hub). A part you recolour by hand
	keeps your colour until this colour changes; delete its PaletteRole to keep it for good.
]]
local hubPalette: { [string]: Color3 } = {
	Ground = Color3.fromRGB(92, 80, 102), -- the plaza cobbles
	Stone = Color3.fromRGB(128, 120, 138), -- clock tower, tombstones, statue, Ready pad
	Wood = Color3.fromRGB(92, 62, 40), -- stall, posts, trees, signs
	Iron = Color3.fromRGB(35, 32, 40), -- lamps, fences, cauldron
	Bone = Color3.fromRGB(235, 228, 210), -- candles, cobwebs, ropes
	Orange = Color3.fromRGB(255, 130, 20), -- pumpkins, awning stripes
	Purple = Color3.fromRGB(128, 64, 182), -- roofs, awning stripes, banners
	Green = Color3.fromRGB(110, 200, 90), -- pumpkin stems, the cauldron brew, the Ready glow
	Glow = Color3.fromRGB(255, 200, 90), -- lights, lit windows, flames, carved faces
	Gold = Color3.fromRGB(255, 210, 60), -- the King statue's crown
	Cloth = Color3.fromRGB(70, 110, 160), -- the shopkeeper's shirt
	Straw = Color3.fromRGB(200, 170, 90), -- the shopkeeper's hat
	Dark = Color3.fromRGB(30, 22, 40), -- screens, backdrops, bats
	Teal = Color3.fromRGB(70, 225, 200), -- the Ready circle's runes, glowing mushrooms
	Foliage = Color3.fromRGB(70, 48, 92), -- the puffy leaves on the spooky trees
	Path = Color3.fromRGB(150, 128, 128), -- the smooth stone paths and the promenade ring
}

local Config = {
	-- v2 settings, one file each (see the list above).
	Features = require(script.Features),
	Modes = require(script.Modes),
	Lobby = require(script.Lobby),
	Parkour = require(script.Parkour),
	Minigames = require(script.Minigames),
	EasterEggs = require(script.EasterEggs),
	HideSeek = require(script.HideSeek),
	ScareMaze = require(script.ScareMaze),
	Rarity = require(script.Rarity),
	Crates = require(script.Crates),
	Skins = require(script.Skins.Settings),
	SkinAnimate = require(script.SkinAnimate),
	SkinMotion = require(script.SkinMotion),
	SkinCatalog = require(script.SkinCatalog),
	Menu = require(script.Menu),
	Dances = require(script.Dances),
	TowerParkour = require(script.TowerParkour),
	Announce = require(script.Announce),
	MapLife = require(script.MapLife),
	ScreenMotion = require(script.ScreenMotion),
	SkinStudio = require(script.SkinStudio),

	Game = {
		Name = "Pumpkin Panic", -- working title, see docs/DESIGN.md
		Version = "0.1.0",
	},

	-- The round loop (src/server/Services/GameService.luau), the same for every game mode:
	-- Waiting for players -> Voting -> Intermission -> play -> Results -> again.
	-- How many players a round needs: Config.Lobby.Ready.MinReady (Config/Lobby.luau).
	Round = {
		IntermissionSeconds = 5, -- after voting, while the map loads
		Duration = 300, -- seconds of play per King Hunt round (other modes: their own file)
		ResultsSeconds = 10, -- how long the results screen stays up
		ResultsShowTop = 10, -- rows on the results screen
		CancelledSeconds = 3, -- "Not enough players" shows this long when a round is called off
		ErrorWaitSeconds = 5, -- if a round breaks (a bug), wait this long, then start a new one
		SafetyLimitSeconds = 1200, -- a round still going after this long is stopped (only a bug does that)
	},

	-- First-round tutorial for new players (RoundsPlayed = 0 and not TutorialDone): Boo Guide
	-- pops up in a small speech bubble with a tip at each moment, once each. "Skip" (or the
	-- last tip) marks it done in the save. src/client/TutorialUI.luau, TutorialService.
	-- Switched off in v2: set Config.Features.Tutorial = true to bring it back.
	Tutorial = {
		Name = "Boo Guide",
		SkipText = "Skip",
		HubDelay = 2.5, -- seconds after joining before the first tip
		MinSeconds = 2.5, -- a tip stays at least this long before the next one replaces it
		Gap = 8, -- space above any panel along the bottom (vote, ghost, dialog)
		Tips = {
			Hub = { Text = "Walk to the Voting Board or wait for the vote.", Seconds = 7 },
			RoundStart = { Text = "Grab pumpkins! Each one is coins.", Seconds = 5 },
			Pickup = { Text = "Nice! Keep going.", Seconds = 3 },
			King = {
				Text = "The King hunts by SOUND: don't sprint or shout near him.",
				Seconds = 6,
			},
			Caught = { Text = "You're a ghost now: spectate or haunt the King.", Seconds = 6 },
			Results = { Text = "Spend coins at the Pumpkin Shop!", Seconds = 6 },
		},
		Colors = {
			Name = Color3.fromRGB(255, 170, 70),
			Boo = Color3.fromRGB(240, 240, 255),
		},
	},

	-- Round moments on screen (src/client/RoundJuiceUI.luau). Spooky-cute, never gory.
	Juice = {
		Run = { Text = "RUN!", Seconds = 1.8, Color = Color3.fromRGB(255, 120, 30) }, -- when the King appears
		LastSeconds = {
			At = 30,
			Text = "Last 30 seconds!",
			Seconds = 2.2,
			Color = Color3.fromRGB(255, 210, 60),
		},
		Survivors = { -- when someone is caught
			Text = "%d survivors left",
			One = "Only 1 survivor left!",
			Seconds = 2,
			Color = Color3.fromRGB(200, 170, 255),
		},
		Pickup = { Text = "+%d", Seconds = 0.9, Rise = 3, Color = Color3.fromRGB(255, 160, 40) }, -- floats up from you
		Heartbeat = { -- red pulse at the screen edges while a King chases you
			Distance = 45, -- studs; starts at this distance and gets stronger as it closes in
			Color = Color3.fromRGB(200, 20, 40),
			MaxOpacity = 0.55, -- strongest edge colour (0-1)
			SlowBeat = 1.1, -- seconds between beats when far...
			FastBeat = 0.45, -- ...and when very close
			SoundId = "rbxassetid://79637236152913", -- per beat ("Heartbeat", Creator Store); "" = none
			Volume = 0.6,
		},
		-- Extra motion: numbers pop, banners punch in with a little shake, "+1" arcs up.
		-- false = the same messages, just shown still (no tweens).
		Animate = true,
		-- Big 3-2-1 in the middle of the screen at the end of the intermission, for the players
		-- about to play (on the Ready pad, or everyone when there is no pad).
		Countdown = {
			From = 3, -- numbers for the last this-many seconds
			Color = Color3.fromRGB(255, 230, 120),
			PopScale = 1.8, -- each number starts this big...
			PopSeconds = 0.25, -- ...and snaps to its normal size in this long
			HoldSeconds = 0.4, -- stays still this long...
			ShrinkSeconds = 0.3, -- ...then shrinks and fades (keep the three under 1 second)
		},
		-- Banner when the round starts straight after the countdown (King Hunt). Modes with
		-- their own intro (Hide & Seek's hiding time, ScareMaze's "Get ready") show their own.
		Start = { Text = "GO!", Seconds = 1.2, Color = Color3.fromRGB(120, 230, 120) },
		Motion = {
			BannerPopScale = 1.6, -- banners start this big and snap down
			BannerPopSeconds = 0.35,
			ShakeDegrees = 7, -- banners start tilted this much and wobble straight
			ShakeSeconds = 0.5,
			FadeSeconds = 0.3, -- banners fade out in this long
			PopStartScale = 0.5, -- "X survivors left" grows from this size
			PopSeconds = 0.25,
			PickupPopSeconds = 0.15, -- "+1" pops to full size in this long...
			PickupDrift = 0.25, -- ...while drifting sideways (fraction of its box) as it rises
			PickupFadeAfter = 0.4, -- starts fading after this fraction of Pickup.Seconds
		},
	},

	-- The results screen after each round (src/client/ResultsUI.luau). It stays up for
	-- Round.ResultsSeconds; Round.ResultsShowTop rows are listed (your own row is always shown).
	Results = {
		PopSeconds = 0.35, -- panel slides in with a little bounce
		RowDelay = 0.08, -- rows appear one after another
		CountUpDelay = 0.6, -- seconds before coins start counting up
		CountUpSeconds = 1.6, -- coins count from 0 to the total in this long
		CoinSoundEvery = 0.12, -- coin sound while your coins count up, at most this often
		SpotlightSpinSeconds = 6, -- one turn of the glow behind the MVP's headshot
		-- Rows scroll past this many UI units (or sooner, when the screen is too short to
		-- show the whole panel: the rows scroll instead of the panel and its text shrinking).
		MaxListHeight = 300,
		PhoneMvpHeight = 56, -- phones get a slimmer MVP spotlight (the full one is 112 tall)
		-- Extra motion (rows pop in, shine sweeps, coin pulse, "You got X coins!").
		-- false = no motion: the panel, every row and the final coin totals show at once.
		Animate = true,
		RowStartScale = 0.8, -- each row grows from this size as it appears...
		RowInSeconds = 0.25, -- ...in this long
		ShineDelay = 0.15, -- after the top row / your row appears, a light sweeps across it
		ShineSeconds = 0.8,
		CoinPulseScale = 1.35, -- your coins pulse this big when they finish counting
		CoinPulseSeconds = 0.3,
		YouGotSeconds = 1.8, -- the "You got X coins!" pop stays this long
		Text = {
			Title = "Round over!",
			Mvp = "MVP",
			MvpLine = "%s collected the most pumpkins: %d!", -- King Hunt: name, pumpkins
			MvpLineDefault = "%s got the top score: %d!", -- other modes, unless they send their own
			ScoreLabel = "Pumpkins", -- King Hunt's score column (other modes send their own)
			Survived = "Survived!",
			Caught = "Caught",
			NextRound = "Next round in %d",
			Nobody = "Nobody finished this round.",
			YouGot = "You got %d coins!", -- pops once your coins finish counting up
		},
		Colors = {
			Mvp = Color3.fromRGB(255, 210, 60),
			Survived = Color3.fromRGB(110, 220, 120),
			Caught = Color3.fromRGB(170, 160, 190),
			MyRow = Color3.fromRGB(255, 130, 20), -- background tint of your own row
			TopRow = Color3.fromRGB(255, 210, 60), -- background tint of the top player's row
			Shine = Color3.fromRGB(255, 255, 255), -- the light sweeping across a row
			YouGot = Color3.fromRGB(255, 210, 60), -- the "You got X coins!" pill
		},
	},

	-- The vote before each round (src/server/Services/VotingService.luau): players pick a
	-- playlist (a mode on a map, Config.Modes.Playlists) and, for King Hunt, the difficulty.
	Voting = {
		Seconds = 20,
		-- How many choices the vote offers: Config.Modes.VoteChoices (Config/Modes.luau).
		MinSecondsBetweenVotes = 0.5, -- per-player spam guard on the vote remote
		-- The vote panel (src/client/VoteUI.luau).
		Text = {
			Heading = "Vote for the next game",
			Difficulty = "Vote for the difficulty",
			TimeLeft = "%ds", -- the seconds left, small and quiet beside the heading
		},
		-- Extra motion on the vote panel. A vote is always sent the moment you tap.
		-- false = no motion: cards and counts change at once, the panel closes right away.
		Animate = true,
		Motion = {
			CardInSeconds = 0.3, -- each card pops in...
			CardStagger = 0.07, -- ...this long after the one before it
			PressScale = 0.88, -- the card you tap squashes to this size and bounces back
			BounceSeconds = 0.3,
			HighlightColor = Color3.fromRGB(255, 230, 120), -- outline of the card you voted for
			HighlightThickness = 3,
			TickSeconds = 0.06, -- a count steps to its new number one vote at a time...
			MaxTicks = 6, -- ...in at most this many steps (big jumps step faster)
			PulseScale = 1.1, -- and the card pulses this big when it gets there
			PulseSeconds = 0.25,
			WinnerWaitSeconds = 4, -- after the vote, wait up to this long to learn the winner
			WinnerScale = 1.15, -- the winning card pops this big...
			WinnerSeconds = 1.6, -- ...and the panel closes this long later
			WinnerColor = Color3.fromRGB(255, 200, 60),
		},
	},

	Maps = {
		Origin = Vector3.new(0, 0, 1000), -- where the round map is built, away from the lobby
		SpawnHeight = 4, -- studs above a spawn pad that a character is placed
		-- How a map is made, first match wins:
		--   1. a Model named after the Id in ServerStorage.Maps (hand-built or Creator Store art)
		--      with a part named "Floor", a folder named SpawnFolder holding spawn parts and
		--      optionally a folder "Hotspots" of parts where extra pumpkins appear;
		--   2. otherwise src/server/Maps/<Builder>.luau builds it from its settings file.
		-- Lighting, particles and ambient sound switch on the client when the camera is over the
		-- map (src/client/ZoneLighting.luau) so players in the hub keep the hub look.
		LightingFadeSeconds = 1.5,
		ZoneCheckSeconds = 0.25,
		-- Every map's settings are in their own file: src/shared/Config/Maps/<Id>.luau.
		-- To add a map: copy one of those files, change its Id/Name/Builder, add it here and
		-- add a playlist for it in Config/Modes.luau.
		List = {
			require(script.Maps.PumpkinPatch) :: any, -- King Hunt
			require(script.Maps.SpookyMansion) :: any, -- King Hunt
			require(script.Maps.PumpkinFarm) :: any, -- Hide & Seek
			require(script.Maps.HedgeMaze) :: any, -- Hide & Seek
			require(script.Maps.ScareMaze) :: any, -- ScareMaze
		} :: { any }, -- maps differ in shape (each Builder reads its own Layout)
	},

	Difficulty = {
		Order = { "Easy", "Hard" }, -- order shown in the vote
		Default = "Easy", -- used if nobody votes
		Levels = {
			Easy = {
				Name = "Easy",
				PumpkinsAtStart = 25,
				MaxPumpkins = 35, -- most pumpkins on the map at once
				SpawnInterval = 2, -- seconds between new pumpkins
				RewardMultiplier = 1,
			},
			Hard = {
				Name = "Hard",
				PumpkinsAtStart = 12,
				MaxPumpkins = 18,
				SpawnInterval = 4,
				RewardMultiplier = 2,
			},
		},
	},

	Pumpkins = {
		Size = 2.5,
		Color = Color3.fromRGB(255, 130, 20),
		HoverHeight = 2, -- studs above the floor
		Value = 1, -- pumpkins added per pickup
		PickupRange = 10, -- server ignores touches from farther than this (studs)
		EdgeMargin = 8, -- keep spawns this far from the map edge
		SpawnAttempts = 10, -- tries to find open floor before skipping one spawn
		HotspotChance = 0.35, -- share of pumpkins placed in a map's risky "Hotspots" areas
		Glow = { Color = Color3.fromRGB(255, 170, 60), Range = 8, Brightness = 1 }, -- seen in the dark
	},

	Rewards = {
		CoinsPerPumpkin = 5, -- multiplied by the difficulty's RewardMultiplier
		SurvivorBonus = 25, -- coins for still being alive when the round ends
		TopCollectorWins = 1, -- Wins added to each round's top player(s) (most pumpkins in King Hunt)
	},

	-- The Pumpkin King: a server-controlled NPC that hunts players.
	King = {
		Name = "The Pumpkin King",
		-- Picked by the difficulty vote. Players walk at Player.WalkSpeed and sprint at SprintSpeed.
		Difficulty = {
			Easy = {
				Count = 1,
				WalkSpeed = 12, -- while wandering or investigating a noise
				ChaseSpeed = 18,
				HearingRange = 90, -- studs; noise farther away is ignored
				SightRange = 45, -- studs; needs a clear line of sight
			},
			Hard = {
				Count = 2,
				WalkSpeed = 14,
				ChaseSpeed = 21,
				HearingRange = 130,
				SightRange = 60,
			},
		},
		SpawnDelay = 15, -- seconds of grace at round start before the King appears
		MinSpawnDistance = 60, -- studs from every player when it spawns
		CatchRange = 4.5, -- studs from the King's root to a player's root (touching also catches)
		RepathSeconds = 0.6, -- how often the path is recomputed while chasing
		WanderRepathSeconds = 3, -- and while wandering or investigating
		StuckSeconds = 2.5, -- no progress for this long = give up on the current goal
		WaypointReachedDistance = 2.5, -- studs (flat) to count a path waypoint as reached
		HipHeight = 3,
		BodySize = Vector3.new(3, 4, 2),
		HeadSize = 4.5,
		BodyColor = Color3.fromRGB(40, 25, 55),
		HeadColor = Color3.fromRGB(255, 110, 0),
		CrownColor = Color3.fromRGB(255, 210, 60),
		Path = {
			AgentRadius = 2.5,
			AgentHeight = 8,
			AgentCanJump = false, -- so low "jump fences" are shortcuts only players can use
			WaypointSpacing = 4,
			Costs = { SecretDoor = math.huge }, -- mansion secret doors are for players only
		},
		-- Noise attracts the King. Every loudness below is decided by the server; clients only
		-- say "I'm sprinting" or "I shouted". Sprint, pickups and shouting mean players without
		-- voice still play the stealth game (docs/DESIGN.md). M3 adds voice only as a clamped,
		-- rate-limited hint on top.
		-- The clip moment: when the King turns towards a noise a player made, that player sees
		-- a big banner and players nearby are told who it heard.
		Heard = {
			Cooldown = 8, -- seconds before the same player can trigger it again
			NearbyRadius = 60, -- studs; players this close to the heard player see "The King heard X!"
			Banner = "THE KING HEARD YOU!",
			NearbyText = "The King heard %s!", -- %s = display name
			BannerSeconds = 2.2,
			RoarSoundId = "rbxassetid://133651202885353", -- "Monster Roar" (Creator Store); "" = silent
			RoarVolume = 0.8,
			RoarPitch = 1.15, -- a bit higher = more cartoon, less scary
		},
		Noise = {
			MemorySeconds = 6, -- how long a noise stays interesting
			TickSeconds = 0.5,
			SprintPerTick = 6, -- loudness each tick while sprinting and moving
			PumpkinPickup = 10,
			Shout = 25,
			ShoutCooldown = 4, -- seconds between shouts per player
			ShoutText = "HEY!", -- shown above the player's head
			ShoutBubbleSeconds = 1.5,
		},
	},

	-- Minion monsters that make the maps feel alive. They never catch anyone (only the King
	-- does); they slow you down, make noise the King hears, or steal a pumpkin. The server
	-- moves them and decides every hit; ghosts are ignored. Count is per difficulty.
	Monsters = {
		SpawnDelay = 5, -- seconds after the round starts
		MinSpawnDistance = 30, -- studs from every player when a minion appears
		HitCooldown = 3, -- seconds a player is safe from all minions after any hit
		TickSeconds = 0.1, -- how often minions look for targets (movement is every frame)
		FeedbackSeconds = 2.5, -- how long the hit message shows on the player's screen

		SkeletonPatrol = {
			Name = "Skeleton Patrol",
			Count = { Easy = 2, Hard = 4 },
			Speed = 6, -- slow: studs per second
			RouteMin = 30, -- each skeleton walks back and forth on a straight route this long
			RouteMax = 60,
			PauseSeconds = 1.5, -- stands still at each end of its route
			HitRange = 4, -- studs, flat
			SlowMultiplier = 0.4, -- walk speed is multiplied by this...
			SlowSeconds = 2, -- ...for this long
			Knockback = 45, -- push away (studs per second), applied by the hit player's client
			Noise = 15, -- the rattle the King can hear
			Color = Color3.fromRGB(235, 228, 210),
			EyeColor = Color3.fromRGB(120, 255, 110),
			Message = "Bonk! A skeleton rattled you. The King heard that!",
		},
		BatSwarm = {
			Name = "Bat Swarm",
			Count = { Easy = 1, Hard = 2 },
			Bats = 5, -- bats per swarm
			FlyHeight = 6, -- studs above the floor
			IdleRadius = 4, -- circles its roost while waiting
			DartSpeed = 30, -- fast...
			ReturnSpeed = 12,
			AggroRange = 28, -- ...but short range: needs a clear view of you within this
			LeashRange = 40, -- gives up when this far from its roost
			ZigZagWidth = 5, -- studs side to side while darting
			ZigZagHz = 2.5,
			RestSeconds = 4, -- back at the roost after a hit or giving up
			HitRange = 4,
			SlowMultiplier = 0.6,
			SlowSeconds = 3,
			Noise = 12,
			Color = Color3.fromRGB(40, 30, 55),
			EyeColor = Color3.fromRGB(255, 70, 70),
			Message = "Bats! They screeched and made you dizzy.",
		},
		GhostCat = {
			Name = "Ghost Cat",
			Count = { Easy = 1, Hard = 2 },
			WanderSpeed = 8,
			StalkSpeed = 14, -- a bit slower than walking, so you can escape if you notice it
			NoticeRange = 30, -- goes after players carrying pumpkins this close
			HitRange = 3.5,
			Steal = 1, -- pumpkins taken per touch
			DropSeconds = 6, -- the stolen pumpkin reappears somewhere on the map after this
			FleeSeconds = 4, -- runs off after a steal before it hunts again
			Hover = 1.5, -- floats this high (it's a ghost: it also drifts through walls)
			Noise = 8,
			Color = Color3.fromRGB(190, 225, 255),
			Transparency = 0.35,
			EyeColor = Color3.fromRGB(255, 220, 80),
			Message = "The Ghost Cat swiped a pumpkin! It'll drop it somewhere...",
		},
	},

	-- Sound effects. Each one: SoundId ("" = silent), Volume (0-1), optional PitchMin/PitchMax
	-- (random pitch each play) and, for 3D sounds on a part, RollOffMin/RollOffMax (studs: full
	-- volume inside Min, silent past Max). All ids are free Creator Store audio; swap any of them.
	-- Players can turn music and sounds off in Settings (saved). Music = hub music + map
	-- ambience; Sounds = everything below.
	Sounds = {
		-- UI (every button in the game UI)
		Click = { SoundId = "rbxassetid://87437544236708", Volume = 0.5 },
		Hover = { SoundId = "rbxassetid://139800881181209", Volume = 0.25 },
		-- Rewards and round events (only you hear them)
		PumpkinPickup = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.6,
			PitchMin = 0.9,
			PitchMax = 1.2,
		},
		Coins = { SoundId = "rbxassetid://4612374807", Volume = 0.5 },
		RoundStart = { SoundId = "rbxassetid://17798541626", Volume = 0.6 },
		CountdownTick = {
			SoundId = "rbxassetid://134410911353980",
			Volume = 0.5,
			LastSeconds = 10, -- ticks during the last this-many seconds of...
			States = { "Voting", "Intermission", "Playing" }, -- ...these round states
		},
		Caught = { SoundId = "rbxassetid://9113854528", Volume = 0.7 },
		Ghost = { SoundId = "rbxassetid://140334012603496", Volume = 0.6, Delay = 0.5 }, -- after Caught
		Purchase = { SoundId = "rbxassetid://120891770644830", Volume = 0.6 },
		DailyReward = { SoundId = "rbxassetid://1841209502", Volume = 0.6 },
		CodeRedeemed = { SoundId = "rbxassetid://9045119921", Volume = 0.6 },
		-- 3D, heard by everyone near them (the King's roar is Config.King.Heard.RoarSoundId)
		KingFootstep = {
			SoundId = "rbxassetid://140594308250996",
			Volume = 0.9,
			PitchMin = 0.55, -- low and heavy
			PitchMax = 0.65,
			RollOffMin = 12,
			RollOffMax = 90,
			WalkInterval = 0.6, -- seconds between steps while wandering or listening
			ChaseInterval = 0.32, -- ...and while chasing
		},
		SkeletonRattle = {
			SoundId = "rbxassetid://9120924561",
			Volume = 0.6,
			PitchMin = 1.1,
			PitchMax = 1.4,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		BatSqueak = {
			SoundId = "rbxassetid://117491181431951",
			Volume = 0.5,
			PitchMin = 1,
			PitchMax = 1.3,
			RollOffMin = 8,
			RollOffMax = 50,
		},
		CatMeow = {
			SoundId = "rbxassetid://134699420140804",
			Volume = 0.6,
			PitchMin = 0.95,
			PitchMax = 1.15,
			RollOffMin = 8,
			RollOffMax = 60,
		},
		-- Minions also make their sound now and then on their own, so you hear them coming.
		MinionIdleMin = 5, -- seconds between idle sounds per minion (random in this range)
		MinionIdleMax = 11,
		SettingsCooldown = 0.3, -- per-player spam guard on the Settings toggles
	},

	-- Keeping low-end phones smooth. Lower numbers = less work per second (and choppier motion);
	-- the Phone... ones are used on small touch screens instead.
	Performance = {
		AmbienceDistance = 170, -- floating candles / flickering lights only animate this close to the camera
		PhoneAmbienceDistance = 130,
		FlickerHz = 20, -- light flicker updates per second (not every frame)
		PhoneFlickerHz = 12,
		-- While nothing near the camera is animating, the lobby and map animations (candles,
		-- shopkeeper, Ready ring, crate stand, map pumpkins) only look for something nearby this
		-- many times a second instead of every frame. Things already animating move every frame.
		IdleScanHz = 8,
		PhoneIdleScanHz = 5,
		ShopStateCooldown = 0.2, -- a client asking for its shop state faster than this gets the last answer
		HauntTryCooldown = 0.25, -- spam guard on the Haunt button when it misses
		SpectateFocusCooldown = 0.5, -- spam guard: spectators asking the server to stream the map to them
	},

	-- Screen layout for phones, tablets and PC (src/client/Layout.luau).
	UI = {
		ReferenceHeight = 760, -- usable screen height the UI is drawn for; taller screens scale up...
		MaxScale = 1.35, -- ...to at most this (never down: phones keep full-size, readable text)
		PhoneMaxHeight = 500, -- a touch screen this short (usable points) gets the phone layout
		-- At start-up the screen size isn't known for a moment; the screens wait for it (at most
		-- this many seconds) so they pick the phone or PC layout from the real size.
		ScreenWaitSeconds = 5,
		EdgeMargin = 12, -- gap between panels and the screen edge
		-- The old column of Shop / Codes / Invite / Settings buttons, only used when the Menu is
		-- switched off (Features.Menu = false; the Menu's own sizes are in Config/Menu.luau).
		SideButton = { Width = 110, Height = 40, Gap = 8, PhoneWidth = 96, PhoneHeight = 38 },
		-- On touch screens that column goes top-left, above Roblox's thumbstick (bottom-left),
		-- and panels along the bottom keep this clear of the thumbstick and jump button.
		PhoneSideTop = 8,
		TouchBottomSideClear = 130,
		-- The vote panel also keeps this much clear on the right: the jump button plus the round
		-- action buttons Roblox puts around it (HEY!, Run).
		TouchActionsClear = 205,
		MinTextSize = 14, -- shrinking text never goes below this
		-- Banners and big messages placed part-way down the screen (round, minigame and easter
		-- egg pop-ups) move down on short phone screens so they never cover the bar at the top
		-- (the Hud): they keep at least this many UI units under it.
		BelowHudGap = 8,
		-- Animated UI (src/client/UIMotion.luau): panels pop in and out, buttons squash when
		-- pressed, coin numbers roll. On = false turns every animation off (everything instant).
		-- Times are in seconds; sizes are multiples of normal size (1 = normal).
		Motion = {
			On = true,
			PopInSeconds = 0.22, -- a panel (Menu, Shop, Crates...) growing in when it opens
			PopOutSeconds = 0.12, -- ...and shrinking away when it closes
			PopFrom = 0.6, -- the size a panel starts at when it pops in
			PopOutTo = 0.7, -- the size it shrinks to before it disappears
			PressScale = 0.92, -- a button squashes to this while pressed
			PressSeconds = 0.06,
			HoverScale = 1.05, -- grows a little under the mouse (PC only, never on touch)
			HoverSeconds = 0.1,
			BumpScale = 1.15, -- a quick pulse to catch the eye
			BumpSeconds = 0.12,
			CountSeconds = 0.6, -- a number rolling to its new value
			FloatSeconds = 1.1, -- "+50" drifting away and fading
			FloatDistance = 36, -- how far it drifts (UI units)
			TileStagger = 0.03, -- the Menu's tiles pop in one after another, this far apart
			WobbleDelay = 2, -- the Menu button wobbles once, this long after joining...
			WobbleAngle = 10, -- ...tilting this many degrees...
			WobbleSeconds = 0.1, -- ...this fast...
			WobbleTimes = 3, -- ...this many times
			-- A closing panel shrinks away as a short-lived copy (the real one hides at once).
			-- Panels with more parts than this just vanish (copying them would cost too much).
			GhostMaxParts = 500,
		},
		-- The bar at the top middle (src/client/Hud.luau): the round, its timer, one or two lines
		-- of details and your coins. It grows with its words up to MaxWidth (never wider than
		-- the screen) and wraps onto a second line instead of cutting words off.
		Hud = {
			MinWidth = 520,
			MaxWidth = 860,
			TitleHeight = 36, -- the top row (round name and timer, coins on the right)
			TitleSize = 22, -- its text size (shrinks to fit, never below MinTextSize)
			DetailSize = 15, -- the details' text size (shrinks to fit, never below MinTextSize)
			DetailMaxLines = 2, -- details wrap onto at most this many lines
			Padding = 10, -- room at the left, right and bottom
			CoinsWidth = 104, -- the coins pill in the top-right corner
			CoinsIcon = "💰", -- before the number (🪙 shows as an empty box in Roblox's font)
			CoinsGain = Color3.fromRGB(255, 215, 70), -- the "+50" that drifts away when you earn coins
		},
	},

	Player = {
		WalkSpeed = 16,
		SprintSpeed = 24,
		SprintToggleCooldown = 0.1, -- per-player spam guard on the sprint remote
	},

	-- Caught players become ghosts: see-through, floating, can't collect pumpkins, ignored by
	-- the King. Each ghost picks a mode on the ghost screen.
	Ghost = {
		Modes = { "Spectate", "Haunt", "GhostChat" }, -- order shown on the ghost screen
		ModeNames = { Spectate = "Spectate", Haunt = "Haunt", GhostChat = "Ghost chat" },
		DefaultMode = "Haunt",
		ModeSwitchCooldown = 1,
		Transparency = 0.65,
		FlySpeed = 22,
		FlyVerticalSpeed = 14,
		MaxFlyHeight = 40, -- studs above the map floor
		-- Haunt: a ghost near a King can blur its vision for a moment.
		Haunt = {
			Range = 25, -- studs from the ghost to the King
			Seconds = 3, -- how long the King's sight is reduced
			SightMultiplier = 0.4, -- King's SightRange is multiplied by this while haunted
			Cooldown = 15, -- seconds per ghost
		},
		-- The moment you're caught: the camera circles the King (or where you were caught if
		-- no King is near) before the normal ghost controls start.
		HauntCam = {
			Seconds = 2,
			Radius = 16, -- studs from the King
			Height = 7, -- studs above it
			Turns = 0.6, -- how far round it goes in that time (1 = a full circle)
			KingRange = 80, -- use the nearest King within this many studs, else the catch spot
		},
		WatchKingText = "Watch King", -- spectate button that jumps the camera to the King
	},

	-- Proximity voice (VoiceChatService.UseAudioApi = Enabled, EnableDefaultVoice = true).
	-- Voice is a bonus: everything here must degrade to "nothing happens" for players
	-- without voice, and the game must stay fully playable without it.
	Voice = {
		-- Built-in Acoustic Simulation: voices are muffled through walls and bend around
		-- corners (SoundService.AcousticSimulationEnabled). Map parts block sound unless
		-- their AudioCanCollide is off.
		AcousticSimulation = true,
		-- How loud a voice is by distance: studs -> volume (1 = full, 0 = silent).
		Attenuation = { [0] = 1, [15] = 0.9, [45] = 0.4, [80] = 0 },
		-- Ghost voices get an echo (AudioEcho; levels are in decibels).
		GhostEcho = {
			DelayTime = 0.22, -- seconds between echoes
			Feedback = 0.45, -- 0 = one echo, 1 = never fades
			DryLevel = -2,
			WetLevel = -6,
		},
		-- Ghost chat: ghosts in "GhostChat" mode hear each other; living players never hear
		-- ghosts. Enforced server-side with AudioDeviceInput access lists.
		ReconcileSeconds = 1, -- how often voice routing is re-checked (respawns, mode changes)
		-- Voice -> King noise. The client may send a mic level HINT; the server clamps it,
		-- rate-limits it and turns it into noise. It can never be louder than MaxLoudness,
		-- and non-voice players have the same tools (sprint, pickups, shout).
		Noise = {
			HintSeconds = 0.25, -- client sends at most this often
			MinHintGapSeconds = 0.2, -- server drops hints that arrive faster than this
			MinLevel = 0.04, -- mic level (0-1) below this is treated as silence
			LevelGain = 4, -- mic RMS is small for normal speech; scaled by this, then capped at 1
			MaxLoudness = 18, -- noise at full mic level (Shout is 25)
			RequireActiveMic = false, -- also require AudioDeviceInput.Active (verify on a published place before enabling)
		},
	},

	--[[
		THE LOBBY ("Spooky Town Square", Workspace.Hub). Built by src/server/Hub/HubBuilder.luau
		(and HubExtras.luau) from these settings; each lobby area (Ready pad, shop, minigames)
		is its own file in src/server/Hub/Sections/ and sits in its Config.Lobby.Zones area.
		Decorations are props (src/server/Build/Props.luau): drop a model with the same name in
		ReplicatedStorage.Custom.Props to swap every copy (docs/CUSTOMIZE.md > props).

		Directions: positions are studs from Center. x = east (+) / west (-), z = south (+) /
		north (-). The spawn is in the south, the clock tower in the north.

		The hub saved in your place file is used as it is, except:
		  - it is rebuilt from code when its BuildVersion is lower than the one below, unless you
		    set the attribute Locked = true on Workspace.Hub (do that once you edit it by hand);
		  - a missing spawn, Ready pad or shopkeeper is always put back, even on a Locked hub.
		Step by step: docs/CUSTOMIZE.md > "Editing the lobby and maps by hand".
	]]
	Hub = {
		Name = "Spooky Town Square",
		-- Bump this number (10 -> 11) whenever the hub code or these settings change in a way the
		-- saved hub should pick up: a saved hub with a lower number is rebuilt on the next start.
		BuildVersion = 10,
		Center = Vector3.new(0, 0, 0), -- top of the baseplate
		Seed = 31, -- random variation in decorations (change it for a different scatter)
		Radius = 105, -- cobblestone plaza (room for 32 players)
		GroundMaterial = Enum.Material.Cobblestone, -- colour: Palette.Ground
		-- Where players appear: a round stone in the south, looking north at the Ready circle.
		-- Size is the SpawnLocation's (it is invisible: you see the round stone around it).
		Spawn = {
			Offset = Vector3.new(0, 0, 72),
			Size = Vector3.new(14, 1, 14),
			LookAt = Vector3.new(0, 0, 0), -- players face this spot when they appear
			Diameter = 17, -- the round stone players stand on
			Text = "BOO!", -- written on the stone
		},
		NameTagDistance = 120, -- NPC name tags hide further away than this (studs)
		-- Phones: the whole lobby (with the minigames and parkour) should stay under these.
		-- tests/specs/HubLook.spec.luau checks them. With every lobby feature switched on the
		-- lobby is about 4,230 parts and 88 lights (decorations about 1,900; the 60-jump parkour,
		-- the Tormented Tower, Candy Rush, Web Scour, the crate stand and the eggs about 1,600).
		-- Most parts are anchored and cast no shadow, which phones handle well; lights cost more,
		-- so keep MaxLights where it is.
		Budget = { MaxParts = 4300, MaxLights = 90 },

		--[[
			Lighting. Dusk: a purple sky with an orange glow, warm lamps.
			For soft shadows from the lamps, set Lighting > Technology to "Future" once in
			Studio (Properties window): scripts are not allowed to change it.
			Sky: StarCount, CelestialBodiesShown (sun + moon), MoonAngularSize (a big moon). Put your
			own Sky in Lighting (a skybox from the Toolbox) and it is used instead.
			Clouds: drifting clouds (Cover 0-1 = how much of the sky, Density 0-1 = how thick).
			DepthOfField: far things get a little soft (Enabled = false to turn it off).
		]]
		Lighting = {
			ClockTime = 19.4, -- dusk
			Brightness = 1.7,
			Ambient = Color3.fromRGB(78, 60, 104),
			OutdoorAmbient = Color3.fromRGB(104, 82, 132),
			Atmosphere = {
				Density = 0.34,
				Offset = 0.12,
				Color = Color3.fromRGB(150, 116, 196),
				Decay = Color3.fromRGB(255, 136, 72),
				Glare = 0.25,
				Haze = 1.8,
			},
			ColorCorrection = {
				Brightness = 0.03,
				Contrast = 0.14,
				Saturation = 0.22,
				TintColor = Color3.fromRGB(255, 240, 255),
			},
			Bloom = { Intensity = 0.8, Size = 30, Threshold = 0.9 },
			Sky = {
				StarCount = 3000,
				CelestialBodiesShown = true,
				MoonAngularSize = 22, -- the default is 11
				SunAngularSize = 14,
			},
			Clouds = {
				Enabled = true,
				Cover = 0.55,
				Density = 0.45,
				Color = Color3.fromRGB(176, 140, 206),
			},
			DepthOfField = {
				Enabled = true,
				FarIntensity = 0.12,
				FocusDistance = 70,
				InFocusRadius = 90,
				NearIntensity = 0,
			},
		},

		Music = {
			SoundId = "rbxassetid://122867483102494", -- "Haunted Carousel" (DistroKid); "" = no music
			Volume = 0.25,
		},

		-- Lobby colours by role: edit them in hubPalette at the top of this file.
		Palette = hubPalette,
		Colors = hubPalette, -- the old name for Palette (the same colours), still used by some code

		-- The Ready area (src/server/Hub/Sections/ReadyArea.luau): a glowing rune circle players
		-- stand on to join the next round, ringed by little standing stones, with a pumpkin
		-- arch facing the spawn. It sits in the lobby zone Config.Lobby.Zones.ReadyArea (move
		-- it there). The pad is the round part tagged ReadyPad: resize or move it in Studio
		-- and it still works.
		ReadyArea = {
			PadSize = Vector3.new(16, 0.6, 16), -- the round stone: diameter (x/z), thickness (y)
			GlowRole = "Teal", -- the Palette colour of the glowing runes
			Stones = 16, -- little standing stones around the circle (0 = none)
			StoneGap = 100, -- degrees left open on the arch side, so players walk in there
			ArchHeight = 13, -- the arch over the entrance (studs)
			ArchWidth = 11, -- between its pillars (studs)
			ArchPumpkins = 5, -- little pumpkins along the arch
			LanternSize = 2.4, -- the jack-o-lanterns on the pillars
			Banner = "PLAY!", -- the cloth banner under the arch ("" = no banner)
			-- The floating sign above the arch. The client fills in the numbers
			-- (src/client/ReadySign.luau); %d is replaced by a number.
			Sign = {
				Height = 18, -- studs above the plaza
				MaxDistance = 300, -- hidden further away than this (studs)
				-- Hidden while the camera is this close (flat distance, studs): from right under it
				-- only its cut-off bottom shows, over the top of the screen. 0 = always shown.
				HideNear = 12,
				Title = "READY %d / %d", -- players ready / players needed to start
				TitleEnough = "READY %d", -- once enough players are ready
				TitleWaiting = "READY", -- before the server has counted anyone
				YouAreReady = "You're ready!",
				-- The second line for each round state; other states are shown as they are.
				States = {
					["Waiting for players"] = "Stand here to play!",
					Voting = "Voting now!",
					Intermission = "Round starting soon!",
					Playing = "Round on! Stand here for the next one",
					Results = "Round over!",
				} :: { [string]: string },
			},
		},

		-- The Pumpkin Shop stall (src/server/Hub/NpcLooks.luau) and the dressing around it
		-- (src/server/Hub/Sections/Shop.luau). It stands in Config.Lobby.Zones.Shop.
		ShopStall = {
			SignText = "PUMPKIN SHOP", -- the big sign on top
			Chalkboard = "NEW SKINS!", -- the little board out front ("" = no board)
			ShelfItems = 4, -- goodies on each of the 3 shelves behind the keeper
			Pumpkins = 3, -- pumpkins piled on each side of the stall
		},

		-- The ground: cobbles, a walking ring (promenade) round the middle, paths out to every
		-- lobby area, and small details (cracks, puddles, leaves).
		Plaza = {
			EdgeBand = 4, -- darker cobbles round the edge (studs)
			Curbs = 40, -- stones in the curb round the edge
			Promenade = { Radius = 30, Width = 8 }, -- the smooth stone ring round the cauldron
			PathWidth = 7, -- paths from the promenade to each area
			Cracks = 14,
			Puddles = 6,
			Leaves = 44, -- fallen leaves scattered on the ground
		},

		-- Paths and signposts lead to these lobby zones (only while their feature is on).
		-- Text is what the signs say. Feature = the Config.Features switch ("" = always).
		Signposts = {
			Zones = {
				{ Zone = "ReadyArea", Text = "Ready!", Feature = "ReadyPad" },
				{ Zone = "Shop", Text = "Pumpkin Shop", Feature = "" },
				{ Zone = "Crates", Text = "Crates", Feature = "Crates" },
				{ Zone = "Parkour", Text = "Parkour", Feature = "Parkour" },
				{ Zone = "CandyRush", Text = "Candy Rush", Feature = "CandyRush" },
				{ Zone = "WebScour", Text = "Web Scour", Feature = "WebScour" },
			} :: { { Zone: string, Text: string, Feature: string } },
			Spawn = Vector3.new(13, 0, 74), -- the big signpost next to the spawn
			Centre = Vector3.new(-10, 0, -15), -- the one by the cauldron (pointing everywhere)
		},

		ClockTower = {
			Offset = Vector3.new(0, 0, -47),
			Floors = 7, -- the Tormented Tower climbs inside (Config.TowerParkour)
			FloorHeight = 8.5,
			Width = 22, -- room for the Tormented Tower inside
			Lean = 2.2, -- degrees each floor tilts, for the crooked look
			Twist = 4, -- degrees each floor turns
			ClockTime = { Hour = 11, Minute = 55 }, -- the hands are frozen just before midnight
			Bats = 4, -- bats flapping round the roof
		},
		-- The bubbling cauldron in the middle, on a round stone step (Dais).
		Cauldron = { Offset = Vector3.new(0, 0, 0), Radius = 5.5, DaisRadius = 13 },
		-- Lampposts round the edge of the plaza (Count, Radius) with bunting between them, and
		-- a few more by the cauldron (Inner) and along the spawn path (Spawn).
		Lampposts = {
			Count = 12,
			Radius = 93,
			Height = 14,
			Inner = { Count = 4, Radius = 19 },
			Spawn = { Vector3.new(-15, 0, 67), Vector3.new(15, 0, 67) },
		},
		Bunting = { FlagsPerSpan = 5, Sag = 2.5, Colors = { "Orange", "Purple", "Teal" } },
		-- Jack-o-lanterns round the plaza; every LightEvery-th one lights up the ground, and every
		-- Friends-th one has a little plain pumpkin next to it.
		JackOLanterns = { Count = 14, Radius = 82, Size = 3, LightEvery = 4, Friends = 2 },
		Candles = { -- floating candles over the middle
			Count = 16,
			MinRadius = 10,
			MaxRadius = 30,
			MinHeight = 10,
			MaxHeight = 16,
			MinSize = 0.8, -- studs of wax (random in this range)
			MaxSize = 1.4,
			BobHeight = 0.8,
			LightEvery = 4, -- every 4th candle lights up (lights cost a little on phones)
		},
		Benches = { Count = 6, Radius = 22 }, -- round the cauldron, between the paths
		Graveyard = {
			Offset = Vector3.new(-58, 0, 42),
			Epitaphs = {
				"RIP Mr. Bones",
				"Here lies my homework",
				"Ate 100 candies",
				"Back in 5 mins",
				"Too spooky",
				"BRB haunting",
			},
		},
		Cobwebs = { Size = 5 },
		-- Big twisted trees round the plaza (Bare = no leaves, with hanging lanterns).
		DeadTrees = {
			Offsets = {
				Vector3.new(-70, 0, -46),
				Vector3.new(68, 0, -52),
				Vector3.new(-36, 0, 80),
				Vector3.new(62, 0, 66),
				Vector3.new(-88, 0, 24),
				Vector3.new(90, 0, -10),
			},
			Bare = { false, true, false, true, true, false },
			MinHeight = 16,
			MaxHeight = 22,
		},
		-- Little things dotted around: hay bales, crates, barrels, glowing mushrooms.
		Clutter = {
			HayBales = {
				Vector3.new(60, 0, -34),
				Vector3.new(64, 0, -28),
				Vector3.new(-78, 0, -24),
			},
			Crates = { Vector3.new(56, 0, -40), Vector3.new(-30, 0, 70) },
			Barrels = { Vector3.new(53, 0, -36), Vector3.new(-26, 0, 72) },
			Mushrooms = {
				Vector3.new(-66, 0, -40),
				Vector3.new(-82, 0, 30),
				Vector3.new(58, 0, 70),
				Vector3.new(-40, 0, 76),
				Vector3.new(-70, 0, 60),
				Vector3.new(92, 0, -4),
			},
		},
		-- Extra dressing around the plaza (src/server/Hub/HubExtras.luau).
		Polish = {
			Terrain = {
				Enabled = true, -- grass ground, hills and mud around the plaza
				Radius = 320, -- studs of ground around the hub
				Depth = 6,
				Hills = 16,
				HillRingMin = 160, -- hills stay this far out...
				HillRingMax = 300, -- ...and inside this
				HillMinRadius = 24,
				HillMaxRadius = 50,
				MudPatches = 12,
				GrassColor = Color3.fromRGB(64, 92, 66), -- the grass terrain's colour (dusky green)
				HideBaseplate = true, -- the default Baseplate becomes invisible (still solid underneath)
			},
			-- The forest ring outside the fence. Simple trees (fewer parts), some bare.
			Forest = {
				Count = 30,
				RingMin = 122,
				RingMax = 200,
				MinHeight = 16,
				MaxHeight = 30,
				BareChance = 0.35,
			},
			Mansion = { -- a dark haunted house on a hill far behind the clock tower
				Offset = Vector3.new(0, 0, -330),
				HillRadius = 70,
				HillSink = 45, -- how far the hill's centre is below the ground (higher = flatter hill)
				Size = Vector3.new(64, 30, 30),
				WindowColor = Color3.fromRGB(255, 170, 60),
				Color = Color3.fromRGB(46, 34, 58),
				RoofColor = Color3.fromRGB(70, 40, 92),
			},
			KingStatue = { Offset = Vector3.new(26, 0, -44), Height = 16 },
			PumpkinPatch = { Offset = Vector3.new(74, 0, 34), Radius = 13, Pumpkins = 12 },
			ExtraGraves = { Offset = Vector3.new(-84, 0, 62), Spread = 13, Count = 8 },
			-- The iron fence round the plaza: posts with little pumpkins on top.
			Fence = {
				Radius = 110,
				PostSpacing = 15,
				Height = 4.5,
				Pickets = 2, -- upright bars between two posts
				Gaps = 4,
				GapWidth = 18,
			},
			-- Glowing stepping stones along the paths.
			Paths = {
				Spacing = 9,
				StoneSize = 1.4,
				StopShort = 3, -- studs before the area
				Color = Color3.fromRGB(255, 150, 60), -- Neon glows a lot
				Transparency = 0.55,
			},
			Cobwebs = 6, -- on fence posts
			FogRate = 5, -- ground fog along the fence
		},
		Particles = {
			Fireflies = { Rate = 8, Color = Color3.fromRGB(210, 255, 160) },
			Mist = { Rate = 4, Color = Color3.fromRGB(190, 175, 220) },
			Bubbles = { Rate = 10, Color = Color3.fromRGB(120, 255, 170) },
			Leaves = { Rate = 2, Color = Color3.fromRGB(215, 110, 40) },
		},
		PhotoSpot = {
			Sign = "Spooky Town Square",
			-- Its dance buttons are in Config.Dances (src/shared/Config/Dances.luau).
			CloseDistance = 18, -- the dance bar hides (and dancing is refused) this far away
		},
	},

	-- Hub NPCs and interactive props (built by src/server/Hub/Npcs.luau). Kind picks the
	-- placeholder model; Lines are shown in the dialog when the prompt is used. Where it stands:
	-- Zone = a Config.Lobby.Zones name (the middle of that area, e.g. the shop) or Offset =
	-- studs from Hub.Center. They face the center.
	-- OpensShop (optional) opens the shop on that tab instead of a dialog.
	-- v2 removed Witch Wanda and the Boo Guide: the Pumpkin Shop is the only shopkeeper. To bring
	-- them back, restore their entries and their builders from git history (commit 7717d52:
	-- src/shared/Config.luau and src/server/Hub/HubBuilder.luau).
	Npcs = {
		InteractCooldown = 0.5,
		-- The Voting Board: its dialog's first line (from what the game is doing right now; %s =
		-- the round's state, e.g. "Playing") and the words on the board itself.
		BoardText = {
			Voting = "Voting is open right now! Tap a choice on the board or on the vote panel.",
			Waiting = "No vote yet: stand on the Ready pad and a vote opens.",
			Round = "Right now: %s. The next vote opens after this round.",
			Title = "Voting Board",
			Pick = "Pick the next game",
			Difficulty = "Easy or Hard?",
			SignWaiting = "Stand on the Ready pad to start a vote.",
			SignRound = "The next vote opens after this round.",
		},
		List = {
			{
				Id = "PumpkinVendor", -- the shopkeeper (the Id stays the same so saved hubs keep working)
				Kind = "Vendor",
				DisplayName = "Pumpkin Shop",
				Zone = "Shop", -- stands in the Shop area (Config.Lobby.Zones.Shop)
				Prompt = { ActionText = "Shop", ObjectText = "Pumpkin Shop" },
				OpensShop = "Skin",
				Lines = {
					"Welcome to the Pumpkin Shop! Skins, hats, trails and pets, fresh from the patch.",
				},
			},
			{
				Id = "VotingBoard",
				Kind = "Board",
				DisplayName = "Voting Board",
				Offset = Vector3.new(-24, 0, 56), -- by the Ready circle...
				LookAt = Vector3.new(0, 0, 60), -- ...turned so players on the pad and at the spawn can read it
				Prompt = { ActionText = "Vote", ObjectText = "Voting Board" },
				Lines = {
					"Voting opens between rounds. Pick a map and Easy or Hard on the board or the vote panel.",
				},
			},
			{
				Id = "Leaderboard",
				Kind = "Gravestone",
				DisplayName = "Leaderboard Gravestone",
				Offset = Vector3.new(-50, 0, 36), -- at the front of the graveyard
				Prompt = { ActionText = "Read", ObjectText = "Top Pumpkin Collectors" },
				Lines = { "Here lie the greatest pumpkin collectors of all time..." },
			},
			{
				Id = "PhotoSpot",
				Kind = "PhotoSpot",
				DisplayName = "Photo Spot",
				Offset = Vector3.new(36, 0, 62), -- near the spawn...
				LookAt = Vector3.new(0, 0, 62), -- ...facing it
				Prompt = { ActionText = "Strike a pose", ObjectText = "Photo Spot" },
				Lines = { "Say pumpkin!" },
			},
		} :: { NpcDef },
		Prompt = {
			HoldDuration = 0,
			MaxActivationDistance = 12,
			Height = 3, -- studs above the ground
			Forward = 3, -- studs in front of the NPC, towards the plaza
		},
	},

	-- Leaderboard Gravestone: top lifetime pumpkin collectors.
	Leaderboard = {
		StoreName = "TopPumpkins_v1", -- OrderedDataStore (published places with API access only)
		TopCount = 10,
		RefreshSeconds = 60,
	},

	Economy = {
		-- Pumpkins collected in a round turn into this currency at the end (Rewards above).
		CurrencyName = "Coins",
	},

	-- Cosmetic shop (the Pumpkin Shop stall in the lobby, or Menu > Shop). Prices are in
	-- Economy.CurrencyName. Looks are built from Parts by src/shared/Cosmetics.luau from each
	-- item's Style, so the same code dresses the character (server) and draws the shop previews
	-- (client).
	-- Price: an item costs its Rarity's price (Config/Rarity.luau: Common 125, Uncommon 500,
	-- Rare 1000, Crazy 100000). Give an item its own "Price = 300," to override that. VipOnly
	-- items come free with VIP and can't be bought. Crate skins are added from Config/Skins/.
	Shop = {
		Title = "Pumpkin Shop", -- shown at the top of the shop panel
		RequestCooldown = 0.25, -- per-player spam guard on buy/equip
		OpenKey = Enum.KeyCode.B,
		BuyText = "Buy %s %s", -- the buy button: price (with commas), currency name
		PreviewDistance = 1.15, -- how far the camera is from an item in its card (smaller = bigger)
		PhonePreviewDistance = 0.95, -- the same on phones (closer: bigger pictures on small cards)
		-- The rarity tag in the top-left corner of each card: text size, height, distance from
		-- the card's corner and the space either side of the word. Phones get a smaller one
		-- tucked into the corner so it covers less of the picture (text never below UI.MinTextSize).
		RarityTag = { TextSize = 14, Height = 20, Inset = 12, Padding = 6 },
		PhoneRarityTag = { TextSize = 14, Height = 16, Inset = 5, Padding = 4 },
		-- The shop's little animations (src/client/ShopJuice.luau, used by the shop, Packs & VIP,
		-- Settings and the VIP tracker). Times are in seconds. Animate = false turns them all off:
		-- things just change straight away. Phones get fewer (no turning previews, fewer sparkles).
		Juice = {
			Animate = true, -- false = no extra animation anywhere in the shop
			HoverScale = 1.05, -- a card grows this much under the mouse (PC only)
			HoverGlow = 1.5, -- ...and its border gets this much thicker
			HoverTime = 0.12,
			PressScale = 0.92, -- a button squashes to this size while you hold it
			PressTime = 0.07,
			SpinSpeed = 30, -- degrees a second the 3D previews turn (0 = still; never on phones)
			RareShineSeconds = 2.4, -- one sweep of the soft shine across a Rare card's border
			CrazyPulse = 1, -- a CRAZY card's rainbow border swells by this much, in and out
			EnterTime = 0.2, -- a new page: how long one card takes to pop in...
			EnterStagger = 0.04, -- ...and the wait between one card and the next
			PopScale = 1.12, -- a card you just bought grows this much and springs back
			PopTime = 0.1,
			Sparkles = 12, -- sparkles bursting over a card you just bought...
			PhoneSparkles = 6, -- ...on phones
			SparkleReach = 70, -- how far they fly (pixels)
			SparkleTime = 0.6,
			SparkleColors = {
				Color3.fromRGB(255, 220, 90),
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(255, 150, 40),
			},
			CoinRollTime = 0.7, -- the coins counter rolls down to your new total in this time
			BounceFrom = 0.7, -- a button that changes (Buy -> Unequip) springs in from this size
			BounceTime = 0.25,
			ShakeTime = 0.35, -- the Buy button wiggles this long when you can't afford it...
			ShakePixels = 7, -- ...this far each way
			NeedText = "Need %s more %s", -- then says how many more: amount, currency name
			NeedSeconds = 1.8, -- ...for this long, then shows the price again
			CheckPop = 1.4, -- the checkmark on the card you put on pops to this size
			ToastText = "Wearing it!", -- the little message when you put something on
			ToastSeconds = 1.4,
		},
		-- Shop tabs, in order; a player wears one item per slot. Skin comes first so it's put
		-- on before the hat (a skin's head piece lifts the hat).
		Slots = { "Skin", "Hat", "Trail", "Pet" },
		SlotNames = { Skin = "Skins", Hat = "Hats", Trail = "Trails", Pet = "Pets" },
		Items = {
			-- Skins recolour your avatar and can add a head piece. HideClothes hides shirts and
			-- pants; Head is a head-piece builder in src/shared/Cosmetics.luau (or drop a model
			-- named after the item Id into ReplicatedStorage.Custom.Cosmetics).
			{
				Id = "Skeleton",
				Name = "Skeleton",
				Slot = "Skin",
				Rarity = "Uncommon",
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(235, 228, 210),
					HideClothes = true,
					Head = "SkinSkull",
					HeadColor = Color3.fromRGB(235, 228, 210),
					GlowColor = Color3.fromRGB(120, 255, 110),
				},
			},
			{
				Id = "PumpkinHead",
				Name = "Pumpkin Head",
				Slot = "Skin",
				Rarity = "Uncommon",
				Style = {
					Kind = "Skin",
					Head = "SkinPumpkin",
					HeadColor = Color3.fromRGB(255, 130, 20),
					GlowColor = Color3.fromRGB(255, 220, 90),
				},
			},
			{
				Id = "Zombie",
				Name = "Zombie",
				Slot = "Skin",
				Rarity = "Common",
				Style = { Kind = "Skin", BodyColor = Color3.fromRGB(120, 170, 95) },
			},
			{
				Id = "Ghost",
				Name = "Ghost",
				Slot = "Skin",
				Rarity = "Rare",
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(235, 240, 255),
					Material = Enum.Material.Neon,
					Transparency = 0.3,
					HideClothes = true,
				},
			},
			{
				Id = "Mummy",
				Name = "Mummy",
				Slot = "Skin",
				Rarity = "Uncommon",
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(215, 205, 180),
					Material = Enum.Material.Fabric,
					HideClothes = true,
				},
			},
			{
				Id = "KingSkin",
				Name = "Pumpkin King",
				Slot = "Skin",
				Price = 0,
				Rarity = "Rare",
				VipOnly = true,
				Style = {
					Kind = "Skin",
					BodyColor = Color3.fromRGB(40, 25, 55),
					HideClothes = true,
					Head = "SkinKing",
					HeadColor = Color3.fromRGB(255, 110, 0),
					GlowColor = Color3.fromRGB(255, 210, 60),
				},
			},
			-- Hats sit on the head.
			{
				Id = "PumpkinCap",
				Name = "Pumpkin Cap",
				Slot = "Hat",
				Rarity = "Common",
				Style = { Kind = "PumpkinCap", Color = Color3.fromRGB(255, 130, 20) },
			},
			{
				Id = "WitchHat",
				Name = "Witch Hat",
				Slot = "Hat",
				Rarity = "Uncommon",
				Style = {
					Kind = "WitchHat",
					Color = Color3.fromRGB(60, 30, 90),
					Band = Color3.fromRGB(255, 130, 20),
				},
			},
			{
				Id = "CatEars",
				Name = "Cat Ears",
				Slot = "Hat",
				Rarity = "Common",
				Style = {
					Kind = "CatEars",
					Color = Color3.fromRGB(40, 35, 45),
					Inner = Color3.fromRGB(255, 150, 190),
				},
			},
			{
				Id = "BatWings",
				Name = "Bat Wings Headband",
				Slot = "Hat",
				Rarity = "Uncommon",
				Style = { Kind = "BatWings", Color = Color3.fromRGB(45, 30, 60) },
			},
			{
				Id = "KingCrown",
				Name = "Pumpkin King Crown",
				Slot = "Hat",
				Price = 0,
				Rarity = "Rare",
				VipOnly = true,
				Style = { Kind = "Crown", Color = Color3.fromRGB(255, 210, 60) },
			},
			{
				Id = "CandyCornHat",
				Name = "Candy Corn Hat",
				Slot = "Hat",
				Rarity = "Common",
				Style = {
					Kind = "CandyCornHat",
					Base = Color3.fromRGB(255, 200, 40),
					Middle = Color3.fromRGB(255, 120, 20),
					Tip = Color3.fromRGB(250, 245, 230),
				},
			},
			{
				Id = "BatBow",
				Name = "Bat Bow",
				Slot = "Hat",
				Rarity = "Uncommon",
				Style = {
					Kind = "BatBow",
					Color = Color3.fromRGB(70, 40, 110),
					Knot = Color3.fromRGB(255, 120, 190),
					EyeColor = Color3.fromRGB(255, 230, 90),
				},
			},
			-- Trails stream behind you.
			{
				Id = "OrangeTrail",
				Name = "Jack-o'-Glow",
				Slot = "Trail",
				Rarity = "Common",
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(255, 140, 30),
					Color2 = Color3.fromRGB(255, 220, 80),
				},
			},
			{
				Id = "SlimeTrail",
				Name = "Slime Drip",
				Slot = "Trail",
				Rarity = "Common",
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(120, 255, 110),
					Color2 = Color3.fromRGB(40, 160, 60),
				},
			},
			{
				Id = "GhostTrail",
				Name = "Ghostly Mist",
				Slot = "Trail",
				Rarity = "Uncommon",
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(200, 230, 255),
					Color2 = Color3.fromRGB(150, 120, 220),
				},
			},
			{
				Id = "CandyTrail",
				Name = "Candy Corn",
				Slot = "Trail",
				Price = 0,
				Rarity = "Uncommon",
				VipOnly = true,
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(255, 200, 40),
					Color2 = Color3.fromRGB(255, 110, 20),
				},
			},
			{
				Id = "CandySwirlTrail",
				Name = "Candy Swirl",
				Slot = "Trail",
				Rarity = "Common",
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(255, 120, 190),
					Color2 = Color3.fromRGB(255, 245, 250),
				},
			},
			{
				Id = "PurpleFogTrail",
				Name = "Purple Fog",
				Slot = "Trail",
				Rarity = "Uncommon",
				Style = {
					Kind = "Trail",
					Color = Color3.fromRGB(150, 80, 220),
					Color2 = Color3.fromRGB(60, 30, 100),
				},
			},
			-- Pets float by your shoulder.
			{
				Id = "MiniPumpkin",
				Name = "Mini Pumpkin",
				Slot = "Pet",
				Rarity = "Common",
				Style = { Kind = "PumpkinPet", Color = Color3.fromRGB(255, 130, 20) },
			},
			{
				Id = "BabyBat",
				Name = "Baby Bat",
				Slot = "Pet",
				Rarity = "Uncommon",
				Style = { Kind = "BatPet", Color = Color3.fromRGB(50, 35, 70) },
			},
			{
				Id = "GhostKitty",
				Name = "Ghost Kitty",
				Slot = "Pet",
				Rarity = "Rare",
				Style = { Kind = "GhostPet", Color = Color3.fromRGB(200, 230, 255) },
			},
			{
				Id = "MiniCauldron",
				Name = "Mini Cauldron",
				Slot = "Pet",
				Rarity = "Uncommon",
				Style = {
					Kind = "CauldronPet",
					Color = Color3.fromRGB(40, 36, 46),
					Brew = Color3.fromRGB(120, 255, 110),
				},
			},
			{
				Id = "SpiderPet",
				Name = "Itsy Spider",
				Slot = "Pet",
				Price = 0,
				Rarity = "Rare",
				VipOnly = true,
				Style = {
					Kind = "SpiderPet",
					Color = Color3.fromRGB(85, 60, 115), -- dusky purple, readable in dark maps
					EyeColor = Color3.fromRGB(255, 80, 80),
				},
			},
			{
				Id = "SkellyPup",
				Name = "Skelly Pup",
				Slot = "Pet",
				Price = 0,
				Rarity = "Rare",
				VipOnly = true,
				Style = { Kind = "SkullPet", Color = Color3.fromRGB(235, 228, 210) },
			},
		} :: { any }, -- styles differ per Kind
		PetOffset = Vector3.new(2.6, 1.2, 1.5), -- from the character's root (right, up, back)
		TrailLifetime = 0.6,
	},

	-- Robux purchases: the VIP game pass (VipGamePassId) and the coin packs (Products). IDs are 0
	-- until the owner creates them in Creator Hub (Creations > this experience > Monetization)
	-- and pastes them here; with an ID of 0 the shop shows "Coming soon" and nothing prompts.
	-- Step by step: docs/V2-CHANGES.md > "Robux setup". Crate ids go in Config/Crates.luau.
	Monetization = {
		VipGamePassId = 0,
		VipName = "VIP",
		VipSuggestedRobux = 249, -- for reference only; the real price is set in Creator Hub
		-- The paid gameplay edge (docs/DESIGN.md): kept modest so free players aren't left behind.
		VipSpeedMultiplier = 1.1, -- walk and sprint speed
		Tracker = {
			Key = Enum.KeyCode.T,
			Cooldown = 30, -- seconds between uses
			ShowSeconds = 5, -- the arrow to the nearest King shows this long
		},
		ChatTag = { Text = "[VIP]", Color = Color3.fromRGB(255, 210, 60) },
		VipPerks = {
			"+10% walk and sprint speed",
			"King tracker: press T for an arrow to the nearest King (30 s cooldown)",
			"VIP chat tag and VIP-only cosmetics (Pumpkin King skin, crown, trail and two pets)",
		},
		-- Developer Products: coin packs. Key is saved with each receipt; don't rename.
		Products = {
			{
				Key = "PumpkinPouch",
				Name = "Pumpkin Pouch",
				Id = 3717218504,
				Coins = 250,
				SuggestedRobux = 25,
			},
			{
				Key = "PumpkinCart",
				Name = "Pumpkin Cart",
				Id = 3717218508,
				Coins = 1200,
				SuggestedRobux = 99,
			},
			{
				Key = "PumpkinMountain",
				Name = "Pumpkin Mountain",
				Id = 3717218513,
				Coins = 3500,
				SuggestedRobux = 249,
			},
		},
		ReceiptHistory = 50, -- receipt ids remembered per player, so a purchase is never granted twice
		-- A purchase Roblox hands over as the player joins (e.g. one that couldn't finish last
		-- time) waits up to this many seconds for their save to load, instead of waiting for
		-- their next visit.
		ReceiptLoadWaitSeconds = 30,
		-- Crates sold for Robux are Developer Products too: paste each one's id into that crate's
		-- Robux.ProductId in Config/Crates.luau (not in Products above).
	},

	-- Custom art: drop your own models into ReplicatedStorage.Custom (docs/CUSTOMIZE.md,
	-- src/shared/CustomAssets.luau). They're scaled to these sizes unless they have the
	-- attribute KeepSize = true. Props (Custom > Props: Pumpkin, JackOLantern, Lamppost,
	-- HayBale, Gravestone... the full list is in docs/CUSTOMIZE.md, "Swap every copy of
	-- something at once") replace every copy in the lobby AND the round maps, scaled to the
	-- size of the thing they replace.
	Custom = {
		-- Lights for custom props. Your own lantern, lamppost, candle or jack-o'-lantern with
		-- no light inside gets the game's glow light, so the lobby and the maps don't go dark.
		--   AddLights          false = never add a light to a custom model
		--   EveryJackOLantern  false = only the custom jack-o'-lanterns whose built version has
		--                      a light get one (the lobby stays inside its phone light budget,
		--                      Hub.Budget.MaxLights). true = every custom jack-o'-lantern glows
		--                      (the built ones glow through their carved faces; yours may not),
		--                      but that adds about 16 lights to the lobby and goes over the
		--                      budget: slower on phones
		--   JackOLanternGlow   the glow's colour, brightness and reach (studs of light per stud
		--                      of pumpkin height) when the built one had no light to copy
		--   ModelLights        false = a light inside your model is switched off where the built
		--                      thing has none (most lobby jack-o'-lanterns, the scarecrow), so a
		--                      Toolbox model with a light in it keeps the lobby inside its phone
		--                      light budget; true = every light your models bring shines
		PropLights = {
			AddLights = true,
			EveryJackOLantern = false,
			ModelLights = false,
			JackOLanternGlow = {
				Color = Color3.fromRGB(255, 170, 70),
				Brightness = 1.2,
				RangePerStud = 3.3,
			},
		},
		StripScripts = true, -- remove scripts from custom models (free models can hide bad ones)
		Heights = { -- studs, feet to top
			PumpkinKing = 10,
			SkeletonPatrol = 6.2,
			Bat = 1.4,
			GhostCat = 3,
			PumpkinVendor = 7.5, -- the Pumpkin Shop keeper
		} :: { [string]: number },
		CosmeticSize = { Hat = 2, Pet = 1.6, Skin = 2.4 } :: { [string]: number }, -- biggest side, studs
		-- Walk and idle for a custom King that is a real R15 rig (Roblox's own R15 animations).
		RigAnimations = {
			Walk = "rbxassetid://507777826",
			Idle = "rbxassetid://507766388",
		},
	},

	-- Codes players type in the Codes box (Shop > Codes). Give one to each YouTuber/TikToker
	-- and add a new one every update. Code is case-insensitive. Expires is "YYYY-MM-DD" (the
	-- code works until the end of that day, UTC) or "" for never. Reward Coins, Item (a shop
	-- item Id) or both.
	Codes = {
		RequestCooldown = 2, -- seconds between attempts per player
		List = {
			{ Code = "PUMPKIN", Coins = 250, Expires = "" },
			{ Code = "RELEASE", Coins = 500, Expires = "2026-11-15" },
			{ Code = "SPOOKY", Item = "PumpkinCap", Expires = "2026-11-01" },
		} :: { { Code: string, Coins: number?, Item: string?, Expires: string } },
	},

	-- Daily login streak: coins the first time you join each day. Missing more than
	-- GraceHours since your last claim resets the streak to day 1.
	Daily = {
		Rewards = { 50, 75, 100, 150, 200, 250, 500 }, -- day 1..7; after day 7 the last one repeats
		CooldownHours = 20, -- earliest next claim
		GraceHours = 48,
	},

	-- Friends make the algorithm and the game better (docs/VIRAL.md).
	Social = {
		FriendBonusPercent = 10, -- extra round coins per Roblox friend in the same server...
		MaxFriendBonusPercent = 50, -- ...up to this
		InviteButton = true, -- "Invite" tile in the Menu (Roblox's invite-friends prompt)
		FavoritePromptAfterRounds = 1, -- ask to favourite once, after this many finished rounds; 0 = never
		GroupId = 0, -- your Roblox group (0 = none); members get GroupBonusPercent extra round coins
		GroupBonusPercent = 10,
	},

	-- Owner-only test panel (press OpenKey). The experience owner, the group owner and
	-- UserIds are admins. Commands are checked on the server.
	Admin = {
		UserIds = {} :: { number },
		OpenKey = Enum.KeyCode.F8,
		AllowInLiveServers = false, -- false = only in Studio playtests
		CoinsPerClick = 1000,
	},

	-- Saved player data. A new saved field only needs a line in Template: old saves get the
	-- default. Tables with something in them (Equipped, Daily, Settings, Parkour, ...) fill in
	-- missing keys one level deep; empty tables ({}) are taken whole from the save.
	Data = {
		StoreName = "PlayerData_v1", -- bump the suffix to wipe/reset all saves
		AutosaveSeconds = 120,
		Template = {
			Coins = 0,
			Wins = 0,
			Joins = 0,
			PumpkinsCollected = 0, -- lifetime, for the Leaderboard Gravestone
			Owned = {} :: { [string]: boolean }, -- [itemId] = true
			Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" }, -- item id per Shop slot, "" = none
			Receipts = {} :: { string }, -- recent Developer Product purchase ids (newest last)
			Codes = {} :: { [string]: boolean }, -- redeemed codes, upper case
			Daily = { Streak = 0, Last = 0 }, -- login streak and the os.time() of the last claim
			RoundsPlayed = 0,
			FavoritePrompted = false,
			Settings = { Music = true, Sounds = true }, -- the Settings panel's toggles
			TutorialDone = false, -- finished or skipped the first-round tutorial
			-- v2
			EasterEggs = {} :: { [string]: boolean }, -- [eggId] = true once found
			Parkour = { Best = 0, LastReward = 0, Runs = 0 }, -- best time (s), os.time() of the last reward, finishes
			TowerParkour = { Best = 0, Runs = 0, Conquered = false }, -- Tormented Tower: best time (s), finishes, beaten once (skin given)
			-- Lobby minigames: Candy Rush wins, best solo time (s) and its coin limits (the UTC day
			-- number, coins earned that day, os.time() of the last reward and of the last solo
			-- race), the best Web Scour time (s) and the os.time() of its last coins (for its
			-- RewardCooldown, so a new server doesn't skip it).
			Minigames = {
				CandyRushWins = 0,
				CandyRushBest = 0,
				CandyRushDay = 0,
				CandyRushCoinsToday = 0,
				CandyRushLastReward = 0,
				CandyRushLastSolo = 0,
				WebScourBest = 0,
				WebScourLastReward = 0,
			},
			Crates = { Opened = 0 }, -- crates opened, ever
			Stats = { HideSeekTags = 0, HideSeekWins = 0, ScareMazeEscapes = 0 },
		},
	},

	AI = {
		-- Off until an in-game chat box uses it (nothing calls AskNpc yet; see docs/ROADMAP.md).
		Enabled = false,
		MaxRequestsPerMinute = 60, -- whole server, protects your API bill
		-- Your proxy (see tools/ai-proxy). The key lives in Roblox Secrets, never in code.
		ProxyUrl = "https://YOUR-WORKER.workers.dev/chat",
		SecretName = "AI_PROXY_KEY",
		CooldownSeconds = 3, -- per player
		MaxMessageLength = 200,
		MaxReplyTokens = 150,
		Npcs = {
			Guide = {
				DisplayName = "Guide Bot",
				Persona = "You are Guide Bot, a cheerful helper in a Roblox game. "
					.. "Keep replies under 2 short sentences, kid-friendly, no links, "
					.. "never discuss real-world personal info. Stay in character.",
			},
		},
	},

	Moderation = {
		-- AI text is ALWAYS filtered with TextService before display. Don't remove.
		FilterAIText = true,
	},
}

-- Crate skins (src/shared/Config/Skins/) join the shop list, so the shop, crates, codes and
-- saves all find them in Config.Shop.Items.
for _, item in require(script.Skins) do
	table.insert(Config.Shop.Items, item)
end

-- The Tormented Tower's own skin (Config.TowerParkour.Skin): only won by beating the tower.
-- Exclusive = never sold in the shop and in no crate (Items.Price is nil for it).
do
	local skin = table.clone(Config.TowerParkour.Skin) :: any
	skin.Slot = "Skin"
	skin.Exclusive = "TowerParkour"
	skin.Theme = "Tower"
	skin.Style = table.clone(skin.Style)
	skin.Style.Kind = "Skin"
	skin.Style.HideClothes = true
	table.insert(Config.Shop.Items, skin)
end

return Config
