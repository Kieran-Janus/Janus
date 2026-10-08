--!strict
--[[
	ANIMATED SKINS (Config.SkinAnimate)

	Skin pieces that move or change colour: wings flap, tails wag, capes sway, head pieces
	spin, bob or float, colours fade, glows flicker and sparkles burst. A skin asks for them
	in its Style:
	    Animate = {
	        { Effect = "Flap", Target = "Wings" },
	        { Effect = "Pulse", Target = "Glow", Speed = 0.5 },
	    },
	(every effect and target is explained in docs/CUSTOMIZE.md, "Animated skins").

	Every player's own screen draws the movement (src/client/SkinAnim.luau), so it costs no
	network. The numbers at the top keep phones fast: only the closest characters animate.
	Presets holds each effect's own numbers: change Seconds to make every skin using that
	effect faster or slower, Degrees / Height to make it bigger or smaller.
	Rarity says how many effects a skin of each rarity may have (and whether it may have a
	walk style, Config.SkinMotion). The tests check every skin follows it.
	Switch it all off with Config.Features.SkinAnimations.
]]

return {
	MaxCharacters = 8, -- characters whose skin pieces animate at once (the closest; you first)
	PhoneMaxCharacters = 4,
	MaxDistance = 120, -- studs from the camera
	HalfRateDistance = 60, -- further than this: maths every second frame (still written every frame)
	OffScreenMargin = 0.2, -- how far past the screen edge (fraction of the screen) still counts as on screen
	CheckSeconds = 0.5, -- how often the closest ones are picked again
	ColorHz = 30, -- colour and light effects update this many times a second
	MaxColorWrites = 400, -- colour/light writes per frame, all characters and previews together (PC)
	PhoneMaxColorWrites = 120,
	PhoneBurstScale = 0.5, -- SparkleBurst particles on phones (0.5 = half)
	MaxEffects = 6, -- effects in one skin's Animate list (rarity limits below are lower)
	MaxPivots = 6, -- moving groups in one skin
	MaxColorParts = 40, -- parts one colour effect changes
	MaxLiveChars = 4000, -- a Skin Studio draft's LiveStyle attribute (characters of JSON)
	MaxPreviewMotion = 4, -- shop/crate/studio previews whose pieces move at once
	PreviewMotionOnPhones = false,

	-- How many Animate effects each rarity may have, and whether it may have a walk style.
	Rarity = {
		Common = { Effects = 0, Motion = false },
		Uncommon = { Effects = 1, Motion = false },
		Rare = { Effects = 3, Motion = true },
		Crazy = { Effects = 6, Motion = true },
	},

	-- Each effect's numbers (what the effects do: src/shared/SkinAnimate.luau and
	-- docs/CUSTOMIZE.md). Seconds = one full cycle at Speed 1.
	Presets = {
		Spin = { Seconds = 4 }, -- one full turn
		Bob = { Seconds = 1.2, Height = 0.15 }, -- studs up and down
		Float = { Seconds = 3, Height = 0.35, Sway = 6 }, -- studs up, degrees of gentle sway
		Wobble = { Seconds = 1, Degrees = 8 }, -- tilt each way
		Flap = { Seconds = 0.6, Degrees = 35 }, -- how far wings beat back
		Wag = { Seconds = 0.5, Degrees = 25 }, -- side to side
		Breathe = { Seconds = 3.5, Height = 0.05, Degrees = 3 }, -- a slow tiny lift and tilt
		Pulse = { Seconds = 1.6, Low = 0.45 }, -- Low = the dimmest it gets (0.45 = 45%)
		ColorCycle = { SecondsPerColor = 1, Spread = 0.15 }, -- Spread = how far each piece is behind the last
		Flicker = { Every = 0.08, Low = 0.3, Chance = 0.35 }, -- Chance = how often it dims
		Shimmer = { Seconds = 2, Width = 0.25, Strength = 0.6 }, -- a bright band sweeping upward
		SparkleBurst = { Every = 3, Count = 20, MaxCount = 50 }, -- seconds between bursts, particles
	},
}
