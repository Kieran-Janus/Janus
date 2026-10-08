--!strict
--[[
	WALK STYLES (Config.SkinMotion)

	A skin can change how you walk: shuffle like a zombie, float like a ghost, march like a
	robot or flap like a bat. In the skin's Style:
	    Motion = "Zombie"
	or your own uploaded animations (they must belong to the game's owner, or Roblox):
	    Motion = { Walk = "rbxassetid://123", Run = "rbxassetid://456", Idle = "rbxassetid://789" }
	or both (the preset's poses plus your own idle):
	    Motion = { Preset = "Ghost", Idle = "rbxassetid://789" }

	Every player's own screen poses the walk styles (src/client/SkinWalk.luau); only the
	closest characters get one, so phones stay fast. Your own uploaded animations play on your
	own character and Roblox shows them to everyone.
	Presets holds each walk style's numbers (degrees, studs and seconds per step): make the
	zombie's arms lower with a smaller ArmsForward, the ghost float higher with Height...
	Walk styles are for Rare and CRAZY skins (Config.SkinAnimate.Rarity).
	Switch them off with Config.Features.WalkStyles; AllowUploaded = false ignores uploaded ids.
]]

return {
	MaxCharacters = 12, -- characters with a walk style at once (the closest; you first)
	PhoneMaxCharacters = 6,
	MaxDistance = 100, -- studs from the camera
	CheckSeconds = 0.5, -- how often the closest ones are picked again
	HalfRateDistance = 50, -- further than this: maths every second frame (still written every frame)
	FadeSeconds = 0.25, -- blend in and out
	AllowUploaded = true, -- false = only the code presets (uploaded ids are ignored)
	WalkThreshold = 0.5, -- studs/s: slower than this counts as standing still
	RunSpeed = 20, -- studs/s: faster than this plays your Run animation
	AirSpeed = 10, -- studs/s up or down: other players' walk style fades out (jumping, falling, climbing)
	OwnRootShiftMax = 0.2, -- studs: your own character never floats or hops higher than this (ceilings)
	LoadCheckSeconds = 3, -- an uploaded animation that hasn't loaded by then is skipped

	-- Each walk style's numbers (degrees, studs, seconds for one step cycle).
	Presets = {
		-- arms held forward, head tilted, a slight lean, a shuffle
		Zombie = { ArmsForward = 85, Lean = 8, HeadTilt = 12, Seconds = 1.1 },
		-- stiff arms forward a little lower, short stiff steps
		Mummy = { ArmsForward = 75, Step = 14, Lean = 4, Seconds = 1.3 },
		-- floats above the ground and bobs, legs dangle, arms limp
		Ghost = { Height = 0.8, Bob = 0.25, Seconds = 2.4, Dangle = 18 },
		-- straight elbows and knees, swinging arms, head turns in ticks
		Robot = { Swing = 28, Step = 24, HeadTurn = 20, Ticks = 4, Seconds = 0.9 },
		-- arms out flapping (faster when moving), a small hover
		Bat = { ArmsOut = 70, Flap = 35, Hover = 0.3, Seconds = 0.35, IdleSeconds = 0.8 },
		-- a crouched tiptoe with arms close
		Sneaky = { Crouch = 0.35, Lean = 14, Knees = 35, Seconds = 0.9 },
		-- an extra hop in every step
		Bouncy = { Hop = 0.35, Seconds = 0.5 },
		-- chest out, chin up
		Proud = { ChestOut = 8, ChinUp = 12, Sway = 4, Seconds = 2 },
	},
}
