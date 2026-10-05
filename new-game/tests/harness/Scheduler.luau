--[[
	Virtual-time task scheduler behind task.spawn / defer / delay / wait.

	Time only moves when something advances it: a test calling Runtime:advance(seconds), or
	task.wait() called outside a task thread (a test body or a top-level require), which
	advances the clock by that long and runs whatever falls due. Inside a task thread
	task.wait() yields that thread until the clock reaches its wake-up time. So a server loop
	like `while true do task.wait(1) ... end` runs exactly 60 times per advance(60) and never
	blocks a test.

	Frames are 1/60 s. RunService events fire once per frame while time advances, but only
	when something is connected to them (see Runtime), so idle advances are cheap.
]]

local Scheduler = {}
Scheduler.__index = Scheduler

local MAX_RESUMES = 1_000_000

export type Item = {
	time: number,
	seq: number,
	thread: thread,
	args: { n: number, [number]: any }?,
	start: number?,
	defer: boolean?,
}

function Scheduler.new(onError: (message: string, traceback: string) -> ())
	local self = setmetatable({}, Scheduler)
	self.now = 0
	self.frame = 1 / 60
	self.heap = {} :: { Item }
	self.seq = 0
	self.owned = setmetatable({}, { __mode = "k" })
	self.cancelled = setmetatable({}, { __mode = "k" })
	self.onError = onError
	-- Set by the runtime: called once per frame while advancing, if frameActive() says so.
	self.frameHook = nil :: ((dt: number) -> ())?
	self.frameActive = nil :: (() -> boolean)?
	self.resumes = 0
	return self
end

-- Binary min-heap on (time, seq) ----------------------------------------------------------

local function less(a: Item, b: Item): boolean
	if a.time ~= b.time then
		return a.time < b.time
	end
	return a.seq < b.seq
end

function Scheduler:_push(item: Item)
	self.seq += 1
	item.seq = self.seq
	local heap = self.heap
	table.insert(heap, item)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if less(heap[i], heap[parent]) then
			heap[i], heap[parent] = heap[parent], heap[i]
			i = parent
		else
			break
		end
	end
end

function Scheduler:_pop(): Item?
	local heap = self.heap
	local n = #heap
	if n == 0 then
		return nil
	end
	local top = heap[1]
	heap[1] = heap[n]
	heap[n] = nil
	n -= 1
	local i = 1
	while true do
		local l, r = i * 2, i * 2 + 1
		local smallest = i
		if l <= n and less(heap[l], heap[smallest]) then
			smallest = l
		end
		if r <= n and less(heap[r], heap[smallest]) then
			smallest = r
		end
		if smallest == i then
			break
		end
		heap[i], heap[smallest] = heap[smallest], heap[i]
		i = smallest
	end
	return top
end

-- Threads ----------------------------------------------------------------------------------

function Scheduler:owns(thread: thread): boolean
	return self.owned[thread] == true
end

-- Resumes a suspended thread; errors are reported, never thrown into the caller.
function Scheduler:resume(thread: thread, ...)
	if self.cancelled[thread] or coroutine.status(thread) ~= "suspended" then
		return
	end
	self.resumes += 1
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		self.onError(tostring(err), debug.traceback(thread, tostring(err)))
	end
end

local function toThread(self, fnOrThread: any, name: string): thread
	if type(fnOrThread) == "thread" then
		self.owned[fnOrThread] = true
		return fnOrThread
	elseif type(fnOrThread) == "function" then
		local thread = coroutine.create(fnOrThread)
		self.owned[thread] = true
		return thread
	end
	error(("invalid argument #1 to '%s' (function or thread expected)"):format(name), 3)
end

function Scheduler:spawn(fnOrThread: any, ...): thread
	local thread = toThread(self, fnOrThread, "spawn")
	self:resume(thread, ...)
	return thread
end

function Scheduler:defer(fnOrThread: any, ...): thread
	local thread = toThread(self, fnOrThread, "defer")
	self:_push({ time = self.now, seq = 0, thread = thread, args = table.pack(...), defer = true })
	return thread
end

function Scheduler:delay(seconds: number?, fnOrThread: any, ...): thread
	local thread = toThread(self, fnOrThread, "delay")
	local t = math.max(tonumber(seconds) or 0, 0)
	self:_push({ time = self.now + t, seq = 0, thread = thread, args = table.pack(...) })
	return thread
end

-- task.wait: yields a task thread, or advances the clock when called from anywhere else.
function Scheduler:wait(seconds: number?): number
	local t = math.max(tonumber(seconds) or 0, self.frame)
	local thread = coroutine.running()
	if self.owned[thread] then
		self:_push({ time = self.now + t, seq = 0, thread = thread, start = self.now })
		return coroutine.yield()
	end
	self:advance(t)
	return t
end

function Scheduler:cancel(thread: thread)
	self.cancelled[thread] = true
	if coroutine.status(thread) == "suspended" then
		pcall(coroutine.close, thread)
	end
end

function Scheduler:_run(item: Item)
	if self.cancelled[item.thread] then
		return
	end
	if item.start then
		self:resume(item.thread, self.now - item.start)
	elseif item.args then
		self:resume(item.thread, table.unpack(item.args, 1, item.args.n))
	else
		self:resume(item.thread)
	end
end

-- Runs everything already due (task.defer, task.delay(0)) without moving the clock.
function Scheduler:flush()
	local count = 0
	while true do
		local top = self.heap[1]
		if not top or top.time > self.now then
			break
		end
		self:_run(self:_pop() :: Item)
		count += 1
		if count > MAX_RESUMES then
			error("scheduler: too many resumptions in flush (a task.defer loop?)")
		end
	end
end

-- Moves the clock forward by `dt` seconds, running frames and due threads in time order.
function Scheduler:advance(dt: number?)
	local target = self.now + math.max(tonumber(dt) or 0, 0)
	local count = 0
	while true do
		local top = self.heap[1]
		local frames = self.frameHook ~= nil and self.frameActive ~= nil and self.frameActive()
		local nextFrame = (math.floor(self.now / self.frame + 1e-7) + 1) * self.frame
		if frames and nextFrame <= target + 1e-9 and (not top or nextFrame <= top.time) then
			self.now = math.max(self.now, nextFrame);
			(self.frameHook :: any)(self.frame)
		elseif top and top.time <= target then
			self:_pop()
			self.now = math.max(self.now, top.time)
			self:_run(top)
		else
			break
		end
		count += 1
		if count > MAX_RESUMES then
			error(
				("scheduler: more than %d resumptions while advancing %.2fs (an endless task.wait(0) loop?)"):format(
					MAX_RESUMES,
					dt or 0
				)
			)
		end
	end
	self.now = math.max(self.now, target)
end

-- Number of threads waiting to run.
function Scheduler:pending(): number
	return #self.heap
end

return Scheduler
