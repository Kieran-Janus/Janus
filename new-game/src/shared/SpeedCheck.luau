--!strict
--[[
	Anti-teleport check: "could this player really have got from where they were to where
	they are now?" Used by the parkour course (src/server/Services/ParkourService.luau) and
	ScareMaze (src/server/Modes/ScareMaze.luau). Pure maths (no parts, no players, no waiting),
	so tests/specs/parkour.spec.luau can try it with made-up positions and times.

	The server feeds in the character's position every check. A move is too fast when:
	  - sideways (X/Z) it went further than MaxSpeed x seconds + Slack, or
	  - upwards it went higher than MaxRiseSpeed x seconds + RiseSlack (falling is always fine).
	Both are tested twice: since the last check, and since the start of the current
	WindowSeconds window. The second test stops a cheat from adding the Slack (meant for lag
	and bumps) on every single check: over a whole window the Slack only counts once.

	local check = SpeedCheck.new()
	SpeedCheck.Reset(check, position, now)   -- start again from here (after the server moved
	                                         -- the player, or at the start of a run)
	SpeedCheck.Step(check, position, now, limits) -> boolean
	    true = too fast: nothing is remembered, so check.Last is still the last good spot
	    (send the player back there and Reset to it). false = fine, remembered.
	limits = { MaxSpeed, Slack, MaxRiseSpeed, RiseSlack, WindowSeconds }
]]

local SpeedCheck = {}

export type Limits = {
	MaxSpeed: number, -- studs per second sideways
	Slack: number, -- extra sideways studs allowed (lag, bumps)
	MaxRiseSpeed: number, -- studs per second upwards
	RiseSlack: number, -- extra studs upwards (one jump)
	WindowSeconds: number, -- length of the longer window
}

export type Check = {
	Last: Vector3?, -- the last good position (nil = nothing seen yet)
	LastTime: number,
	Anchor: Vector3?, -- where the current window started
	AnchorTime: number,
}

function SpeedCheck.new(): Check
	return { Last = nil, LastTime = 0, Anchor = nil, AnchorTime = 0 }
end

-- Forgets the old positions: the next one is measured from `position` (nil = from itself).
function SpeedCheck.Reset(check: Check, position: Vector3?, now: number)
	check.Last = position
	check.LastTime = now
	check.Anchor = position
	check.AnchorTime = now
end

-- Is the move from `a` to `b` in `seconds` faster than the limits allow?
function SpeedCheck.TooFast(a: Vector3, b: Vector3, seconds: number, limits: Limits): boolean
	local dt = math.max(seconds, 0)
	local dx, dz = b.X - a.X, b.Z - a.Z
	if math.sqrt(dx * dx + dz * dz) > limits.MaxSpeed * dt + limits.Slack then
		return true
	end
	return b.Y - a.Y > limits.MaxRiseSpeed * dt + limits.RiseSlack
end

function SpeedCheck.Step(check: Check, position: Vector3, now: number, limits: Limits): boolean
	local last, anchor = check.Last, check.Anchor
	if last == nil or anchor == nil then
		SpeedCheck.Reset(check, position, now)
		return false
	end
	if
		SpeedCheck.TooFast(last, position, now - check.LastTime, limits)
		or SpeedCheck.TooFast(anchor, position, now - check.AnchorTime, limits)
	then
		return true
	end
	check.Last = position
	check.LastTime = now
	if now - check.AnchorTime >= limits.WindowSeconds then
		check.Anchor = position
		check.AnchorTime = now
	end
	return false
end

return SpeedCheck
