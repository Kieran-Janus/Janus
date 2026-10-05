--[[
	RBXScriptSignal / RBXScriptConnection fakes.

	Game code can :Connect, :Once, :Wait and :Disconnect exactly like in Roblox. The engine
	never fires anything by itself; the harness fires structural events (ChildAdded,
	Destroying, Changed, AttributeChanged, ...) and tests fire the rest through
	Signal.fire / Runtime:fire. Handlers run like task.spawn (each in its own task thread),
	so they may yield.
]]

local Signal = {}

local SignalMethods = {}
local SignalMeta = {
	__index = SignalMethods,
	__type = "RBXScriptSignal",
	__tostring = function(self)
		return "Signal " .. self._name
	end,
}

local ConnectionMethods = {}
local ConnectionMeta = {
	__index = ConnectionMethods,
	__type = "RBXScriptConnection",
	__tostring = function()
		return "Connection"
	end,
}

export type World = {
	scheduler: any,
	listening: { [string]: number },
	connectionCount: number,
}

-- `world` (optional) gives the scheduler that runs handlers and the per-event listener
-- counts the instance tree uses to skip work nobody listens to.
function Signal.new(name: string, world: any?)
	return setmetatable({
		_name = name,
		_world = world,
		_conns = {},
		_waiting = {},
	}, SignalMeta)
end

function Signal.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == SignalMeta
end

local function connect(self, fn, once: boolean)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 3)
	end
	local c =
		setmetatable({ Connected = true, _signal = self, _fn = fn, _once = once }, ConnectionMeta)
	table.insert(self._conns, c)
	local world = self._world
	if world then
		world.listening[self._name] = (world.listening[self._name] or 0) + 1
		world.connectionCount += 1
	end
	return c
end

function SignalMethods:Connect(fn)
	return connect(self, fn, false)
end

function SignalMethods:ConnectParallel(fn)
	return connect(self, fn, false)
end

function SignalMethods:Once(fn)
	return connect(self, fn, true)
end

function SignalMethods:Wait()
	local world = self._world
	local scheduler = world and world.scheduler
	local thread = coroutine.running()
	if not (scheduler and scheduler:owns(thread)) then
		error(
			(
				"%s:Wait() would block forever: in the test harness only task threads (task.spawn, "
				.. "a running Script, an event handler) can yield. Fire the event before waiting, "
				.. "or wait from inside a task."
			):format(self._name),
			2
		)
	end
	table.insert(self._waiting, thread)
	return coroutine.yield()
end

function ConnectionMethods:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	local index = table.find(signal._conns, self)
	if index then
		table.remove(signal._conns, index)
	end
	local world = signal._world
	if world then
		world.listening[signal._name] = (world.listening[signal._name] or 1) - 1
	end
end

local function run(signal, fn, ...)
	local world = signal._world
	local scheduler = world and world.scheduler
	if scheduler then
		scheduler:spawn(fn, ...)
	else
		local ok, err = pcall(fn, ...)
		if not ok then
			print("[harness] error in " .. signal._name .. " handler: " .. tostring(err))
		end
	end
end

-- Fires the signal: every connected handler runs (in connection order), then every thread
-- blocked in :Wait() resumes with the same arguments.
function Signal.fire(signal, ...)
	local conns = signal._conns
	if #conns > 0 then
		for _, c in table.clone(conns) do
			if c.Connected then
				if c._once then
					c:Disconnect()
				end
				run(signal, c._fn, ...)
			end
		end
	end
	if #signal._waiting > 0 then
		local waiting = signal._waiting
		signal._waiting = {}
		local scheduler = signal._world and signal._world.scheduler
		for _, thread in waiting do
			if scheduler then
				scheduler:resume(thread, ...)
			else
				coroutine.resume(thread, ...)
			end
		end
	end
end

-- Number of live connections.
function Signal.count(signal): number
	return #signal._conns
end

function Signal.disconnectAll(signal)
	for _, c in table.clone(signal._conns) do
		c:Disconnect()
	end
	signal._waiting = {}
end

-- A connection to nothing, for stubbed engine methods that return one.
function Signal.dummyConnection()
	return setmetatable(
		{ Connected = true, _signal = Signal.new("Dummy"), _fn = function() end },
		ConnectionMeta
	)
end

return Signal
