--!strict
--[[
	SPOOKY OBBY (Config.ObbyRace): an easy race over a Halloween obstacle course.
	On/off: Config.Features.ObbyRace. Mode code: src/server/Modes/ObbyRace.luau. Screen:
	src/client/ObbyRaceUI.luau. The course itself (where every jump is) is in the map's file,
	src/shared/Config/Maps/SpookyObby.luau (Course).

	How a round goes: everyone waits on the start plaza for IntroSeconds ("Get ready", nobody
	can walk), then GO! Touch the glowing checkpoints in order and reach the trophy at the
	finish. Fall off (or touch green goo, or a ghost sweeper) and you go back to your last
	checkpoint. The first to finish wins the most coins; everyone who finishes gets coins;
	everyone else gets coins for each checkpoint they reached. The round ends when everybody has
	finished, when the time runs out, or EndAfterFirstSeconds after the first finisher.

	To change it: edit a number below and press Play. Easy and Hard each have their own block
	(Difficulty): the vote picks one.
]]

return {
	IntroSeconds = 5, -- "Get ready" on the start plaza (frozen) before GO!
	-- After the first player finishes, the rest have this many seconds left (if the clock has
	-- more). 0 = no hurry: the round runs until everyone finishes or the time is up.
	EndAfterFirstSeconds = 60,
	MinSeconds = 25, -- a finish faster than this doesn't count (stops teleport cheats)
	SampleSeconds = 0.1, -- how often the server looks where every racer is
	FallBelowCheckpoint = 8, -- studs below your last checkpoint (or the plaza) that count as fallen
	BackCooldown = 3, -- seconds between "Back to checkpoint" button presses
	TouchMargin = 1, -- studs past a checkpoint's edge that still count as standing on it
	TouchHeight = 7, -- studs above a checkpoint's top that still count (landing from a jump)
	HazardHeight = 3.5, -- studs above goo that still count as touching it
	-- Ghost sweepers (the spinning bars): how forgiving they are. Your body counts as this
	-- many studs round (a little less than a real body, so a near miss is a miss).
	SweeperBodyRadius = 0.5,

	-- Anti-teleport (src/shared/SpeedCheck.luau): moving faster than this puts you back.
	SpeedTolerance = 1.5, -- sideways faster than sprint speed x this = cheating
	SpeedSlack = 8, -- extra sideways studs allowed (bumps, lag), once per SpeedWindowSeconds
	MaxRiseSpeed = 14, -- studs per second a racer can go UP...
	RiseSlack = 8, -- ...plus this many studs (one jump)
	SpeedWindowSeconds = 1,

	-- Easy and Hard (the vote picks one).
	Difficulty = {
		Easy = {
			TimeLimit = 300, -- seconds to reach the finish
			SweeperSpeed = 0.45, -- ghost sweepers spin at this share of their Speed (slow)
			CoinMultiplier = 1, -- coins x this
		},
		Hard = {
			TimeLimit = 180,
			SweeperSpeed = 1.25,
			CoinMultiplier = 1.5,
		},
	},

	-- Coins and points (before the friend bonus; Hard multiplies coins by CoinMultiplier).
	Rewards = {
		PlayCoins = 10, -- everyone who takes part
		FinishCoins = 40, -- everyone who reaches the finish...
		PlaceCoins = { 60, 40, 25 }, -- ...plus this for 1st, 2nd, 3rd
		CheckpointCoins = 5, -- per checkpoint, for racers who don't finish
		-- Points (the results' score column): finishers by place (after the list: LastPoints),
		-- the rest CheckpointPoints per checkpoint (always less than any finisher).
		PlacePoints = { 100, 80, 65, 55, 50 },
		LastPoints = 45,
		CheckpointPoints = 5,
	},

	-- "Back to checkpoint" keys (the button is always on screen too, also on phones).
	BackKeys = { Enum.KeyCode.R, Enum.KeyCode.ButtonY },

	-- Everything players read.
	Text = {
		ScoreLabel = "Points",
		GetReady = "Get ready...",
		Hint = "Race to the glowing trophy! Fall off? Back to your checkpoint.",
		Go = "GO!",
		Checkpoint = "Checkpoint %d/%d", -- the counter
		CheckpointReached = "Checkpoint %d/%d!",
		Start = "Start",
		Place = "%s place", -- "2nd place"
		Fell = "Whoops! Back to checkpoint %d",
		FellStart = "Whoops! Back to the start",
		Goo = "Gooey! Back to checkpoint %d",
		GooStart = "Gooey! Back to the start",
		Swept = "Swept away! Back to checkpoint %d",
		SweptStart = "Swept away! Back to the start",
		TooFast = "Too fast! Back to checkpoint %d",
		TooFastStart = "Too fast! Back to the start",
		BackButton = "Back to checkpoint",
		BackKey = "R",
		Finished = "FINISHED!",
		FinishedPlace = "%s place!", -- under FINISHED!
		FinishTime = "Time: %s",
		Hurry = "%s finished! Hurry up!", -- when the first player finishes
		TimeUp = "Time's up!",
		BadgePlace = "%s", -- the results badge for finishers: "1st"
		BadgeCheckpoint = "Checkpoint %d",
		BadgeStart = "Didn't start",
		StatTime = "%s", -- finish time on the results
		WinnerOne = "%s wins the Spooky Obby!",
		WinnerNone = "Nobody reached the finish this time!",
		MvpLine = "%s won the race! (%d points)",
	},

	Colors = {
		Checkpoint = Color3.fromRGB(120, 255, 140),
		Back = Color3.fromRGB(255, 150, 80),
		Finish = Color3.fromRGB(255, 210, 60),
		Timer = Color3.fromRGB(255, 200, 90),
		Hurry = Color3.fromRGB(255, 110, 90),
		Button = Color3.fromRGB(150, 80, 210),
	},

	-- Sounds (Sounds.PlaySpec): only the racer hears them. SoundId "" = silent.
	Sounds = {
		Checkpoint = {
			SoundId = "rbxassetid://113730061669739",
			Volume = 0.7,
			PitchMin = 1.25,
			PitchMax = 1.25,
		},
		Back = { SoundId = "rbxassetid://140334012603496", Volume = 0.5 },
		Finish = { SoundId = "rbxassetid://1841209502", Volume = 0.7 },
	},

	-- Screen celebrations (look only; the server already decided).
	Effects = {
		On = true, -- false = no confetti or sparkles (Config.Minigames.Effects.On turns all of them off)
		PopSeconds = 1.8, -- "Checkpoint 2/5!" and "Whoops!" messages
		FinishSeconds = 5, -- the FINISHED! banner
		FinishConfetti = 70, -- confetti pieces when you finish (phones: fewer)
		WinnerConfetti = 110, -- ...when you finish 1st
		CheckpointSparkles = 22,
		CheckpointColors = {
			Color3.fromRGB(120, 255, 140),
			Color3.fromRGB(255, 230, 120),
			Color3.fromRGB(255, 255, 255),
		},
		SweeperRange = 220, -- ghost sweepers further than this from your camera don't animate
	},
}
