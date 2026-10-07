--!strict
--[[
	Small helpers that keep per-frame code cheap on phones (settings: Config.Performance).

	FramePace.ScanSeconds() -> number
		How long the lobby / map animations (HubAmbience, LobbyLife, MapLife, CrateIdle) wait
		between looks for something near the camera while nothing is animating
		(1 / IdleScanHz, or 1 / PhoneIdleScanHz on phones). Anything already animating still
		moves every frame.
	FramePace.IdleLoop(signal, step) -> { Wake, Stop }
		Runs step(scan) every frame while it says something is animating (returns true);
		otherwise only every ScanSeconds() from a timer, with no per-frame connection at all.
	FramePace.WhileVisible(gui, signal, fn) -> stop
		Connects fn to a per-frame signal (RunService.Heartbeat...) only while `gui` is
		Visible, so a closed panel runs nothing at all. stop() disconnects it for good (it also
		stops when the gui is destroyed).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local FramePace = {}

function FramePace.ScanSeconds(): number
	local perf = Config.Performance
	local hz = if Layout.IsPhone() then perf.PhoneIdleScanHz else perf.IdleScanHz
	return 1 / math.max(hz, 1)
end

export type IdleLoop = {
	Wake: () -> (), -- run every frame again now (something started animating)
	Stop: () -> (), -- stop for good
}

-- Calls step(scan) every frame on `signal` while it returns true (something is animating).
-- Once it returns false the per-frame connection goes away and step(true) is only called
-- every ScanSeconds() from a timer, until it returns true again. `scan` is true when step
-- should look for new things to animate (the timer, and the first frame after Wake).
function FramePace.IdleLoop(signal: RBXScriptSignal, step: (scan: boolean) -> boolean): IdleLoop
	local connection: RBXScriptConnection? = nil
	local stopped = false
	local token = 0
	local scanNext = true
	local loop: IdleLoop
	local function idle()
		token += 1
		local mine = token
		task.delay(FramePace.ScanSeconds(), function()
			if stopped or token ~= mine or connection then
				return
			end
			-- Protected: one error (a part removed mid-scan) must not stop the scans for good.
			local ok, animating = pcall(step, true)
			if not ok then
				warn("[FramePace] An idle scan failed: " .. tostring(animating))
			end
			if ok and animating then
				loop.Wake()
			else
				idle()
			end
		end)
	end
	local function frame()
		local scan = scanNext
		scanNext = false
		if not step(scan) and not stopped then
			local current = connection
			if current then
				current:Disconnect()
				connection = nil
			end
			idle()
		end
	end
	loop = {
		Wake = function()
			if stopped or connection then
				return
			end
			token += 1 -- (the waiting timer has nothing to do now)
			scanNext = true
			connection = signal:Connect(frame)
		end,
		Stop = function()
			stopped = true
			token += 1
			local current = connection
			if current then
				current:Disconnect()
				connection = nil
			end
		end,
	}
	loop.Wake()
	return loop
end

function FramePace.WhileVisible(
	gui: GuiObject,
	signal: RBXScriptSignal,
	fn: (...any) -> ()
): () -> ()
	local connection: RBXScriptConnection? = nil
	local stopped = false
	local function update()
		local want = gui.Visible and not stopped
		if want and not connection then
			connection = signal:Connect(fn)
		elseif not want and connection then
			connection:Disconnect()
			connection = nil
		end
	end
	local watch = gui:GetPropertyChangedSignal("Visible"):Connect(update)
	local function stop()
		stopped = true
		watch:Disconnect()
		update()
	end
	gui.Destroying:Once(stop)
	update()
	return stop
end

return FramePace
