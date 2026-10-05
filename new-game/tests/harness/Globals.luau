--[[
	The global environment game scripts run in: Roblox datatypes (from Lune), the instance
	tree (Dom), and fakes for what Lune lacks: Random, TweenInfo, DateTime, RaycastParams,
	OverlapParams, task (virtual time), tick / time / os.clock (virtual clock).
]]

local roblox = require("@lune/roblox")
local Dom = require("./Dom")
local Services = require("./Services")
local Types = require("./Types")

local Enum, Vector3 = roblox.Enum, roblox.Vector3
local typeof = Types.typeof

local Globals = {}

-- CFrame: Lune 0.8.9's CFrame.lookAt mirrors the look direction's Z (a target at +Z gives a
-- LookVector of -Z) and it lacks lookAlong and CFrame.new(position, lookAt). Everything else
-- comes straight from Lune.

local LuneCFrame = roblox.CFrame

local function lookAt(at: Vector3, target: Vector3, up: Vector3?): CFrame
	local look = target - at
	if look.Magnitude < 1e-9 then
		return LuneCFrame.new(at)
	end
	look = look.Unit
	local right = look:Cross(up or Vector3.yAxis)
	if right.Magnitude < 1e-6 then
		-- Looking straight along `up`: any perpendicular will do.
		right = look:Cross(Vector3.new(0, 0, -1))
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.xAxis)
		end
	end
	right = right.Unit
	return LuneCFrame.fromMatrix(at, right, right:Cross(look), -look)
end

Globals.CFrame = setmetatable({
	lookAt = lookAt,
	lookAlong = function(at: Vector3, direction: Vector3, up: Vector3?): CFrame
		return lookAt(at, at + direction, up)
	end,
	new = function(...)
		if select("#", ...) == 2 then
			local a, b = ...
			if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
				return lookAt(a, b)
			end
		end
		return LuneCFrame.new(...)
	end,
}, { __index = LuneCFrame })

-- Random (mulberry32: deterministic per seed; not Roblox's exact sequence) -------------------

local TWO32 = 4294967296

local function imul(a: number, b: number): number
	local aHi, aLo = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bHi, bLo = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	return (aLo * bLo + bit32.lshift((aHi * bLo + aLo * bHi) % 65536, 16)) % TWO32
end

local function nextU32(state: { s: number }): number
	state.s = (state.s + 0x6D2B79F5) % TWO32
	local t = state.s
	t = imul(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
	t = bit32.bxor(t, (t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % TWO32)
	return bit32.bxor(t, bit32.rshift(t, 14))
end

local RandomMethods = {}
local RandomMeta = { __index = RandomMethods, __type = "Random" }
RandomMeta.__tostring = function()
	return "Random"
end

local function unit(self): number
	local a = bit32.rshift(nextU32(self._state), 5) -- 27 bits
	local b = bit32.rshift(nextU32(self._state), 6) -- 26 bits
	return (a * 67108864 + b) / 9007199254740992
end

function RandomMethods:NextNumber(min: number?, max: number?): number
	local lo, hi = tonumber(min) or 0, tonumber(max) or 1
	return lo + unit(self) * (hi - lo)
end

function RandomMethods:NextInteger(min: number, max: number): number
	if type(min) ~= "number" or type(max) ~= "number" then
		error("invalid argument to 'NextInteger' (number expected)", 2)
	end
	min, max = math.floor(min), math.floor(max)
	if max < min then
		error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
	end
	return min + math.floor(unit(self) * (max - min + 1))
end

function RandomMethods:NextUnitVector(): Vector3
	local z = unit(self) * 2 - 1
	local a = unit(self) * math.pi * 2
	local r = math.sqrt(1 - z * z)
	return Vector3.new(r * math.cos(a), r * math.sin(a), z)
end

function RandomMethods:Shuffle(t: { any })
	if type(t) ~= "table" then
		error("invalid argument #1 to 'Shuffle' (table expected)", 2)
	end
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

function RandomMethods:Clone()
	return setmetatable({ _state = { s = self._state.s } }, RandomMeta)
end

local Random = {}

function Random.new(seed: number?)
	local s = if seed == nil then math.random(0, 2 ^ 31 - 1) else tonumber(seed)
	if s == nil then
		error("invalid argument #1 to 'new' (number expected)", 2)
	end
	s = math.floor(s)
	local lo = s % TWO32
	local hi = math.floor(s / TWO32) % TWO32
	local self = setmetatable({ _state = { s = bit32.bxor(lo, imul(hi, 0x9E3779B9)) } }, RandomMeta)
	nextU32(self._state)
	return self
end

Globals.Random = Random

-- TweenInfo -------------------------------------------------------------------------------------

local TweenInfoMeta = { __type = "TweenInfo" }
TweenInfoMeta.__index = function(self, key)
	local v = rawget(self, "_fields")[key]
	if v == nil then
		error(("%s is not a valid member of TweenInfo"):format(tostring(key)), 2)
	end
	return v
end
TweenInfoMeta.__newindex = function(_, key)
	error(("%s cannot be assigned to"):format(tostring(key)), 2)
end
TweenInfoMeta.__tostring = function(self)
	local f = rawget(self, "_fields")
	return ("TweenInfo(%g, %s, %s, %d, %s, %g)"):format(
		f.Time,
		f.EasingStyle.Name,
		f.EasingDirection.Name,
		f.RepeatCount,
		tostring(f.Reverses),
		f.DelayTime
	)
end

local TweenInfo = {}

function TweenInfo.new(
	time: number?,
	style: any?,
	direction: any?,
	repeatCount: number?,
	reverses: boolean?,
	delayTime: number?
)
	return setmetatable({
		_fields = {
			Time = time or 1,
			EasingStyle = style or Enum.EasingStyle.Quad,
			EasingDirection = direction or Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		},
	}, TweenInfoMeta)
end

Globals.TweenInfo = TweenInfo

-- RaycastParams / OverlapParams -----------------------------------------------------------------

local function paramsClass(typeName: string, fields: { [string]: any })
	local meta = { __type = typeName }
	local methods = {
		AddToFilter = function(self, value)
			local list = rawget(self, "_fields").FilterDescendantsInstances
			if typeof(value) == "Instance" then
				table.insert(list, value)
			else
				for _, inst in value do
					table.insert(list, inst)
				end
			end
		end,
	}
	meta.__index = function(self, key)
		if methods[key] then
			return methods[key]
		end
		local f = rawget(self, "_fields")
		if f[key] == nil and fields[key] == nil then
			error(("%s is not a valid member of %s"):format(tostring(key), typeName), 2)
		end
		if key == "FilterDescendantsInstances" then
			return table.clone(f[key])
		end
		return f[key]
	end
	meta.__newindex = function(self, key, value)
		if fields[key] == nil then
			error(("%s is not a valid member of %s"):format(tostring(key), typeName), 2)
		end
		if key == "FilterDescendantsInstances" then
			if type(value) ~= "table" then
				error("FilterDescendantsInstances must be an array of Instances", 2)
			end
			for _, inst in value do
				if typeof(inst) ~= "Instance" then
					error("FilterDescendantsInstances must contain only Instances", 2)
				end
			end
			value = table.clone(value)
		elseif key == "FilterType" then
			if
				typeof(value) ~= "EnumItem"
				or tostring(value.EnumType) ~= "Enum.RaycastFilterType"
			then
				error("FilterType must be an Enum.RaycastFilterType", 2)
			end
		elseif typeof(value) ~= typeof(fields[key]) then
			error(("%s expects a %s, got %s"):format(key, typeof(fields[key]), typeof(value)), 2)
		end
		rawget(self, "_fields")[key] = value
	end
	meta.__tostring = function()
		return typeName
	end
	return {
		new = function(init: { [string]: any }?)
			local f = table.clone(fields)
			f.FilterDescendantsInstances = {}
			local self = setmetatable({ _fields = f }, meta)
			for k, v in init or {} do
				(self :: any)[k] = v
			end
			return self
		end,
	}
end

Globals.RaycastParams = paramsClass("RaycastParams", {
	FilterType = Enum.RaycastFilterType.Exclude,
	FilterDescendantsInstances = {},
	IgnoreWater = false,
	CollisionGroup = "Default",
	RespectCanCollide = false,
	BruteForceAllSlow = false,
})

Globals.OverlapParams = paramsClass("OverlapParams", {
	FilterType = Enum.RaycastFilterType.Exclude,
	FilterDescendantsInstances = {},
	MaxParts = 0,
	CollisionGroup = "Default",
	RespectCanCollide = false,
	BruteForceAllSlow = false,
})

-- DateTime (UTC only) ---------------------------------------------------------------------------

local function daysFromCivil(y: number, m: number, d: number): number
	y = if m <= 2 then y - 1 else y
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

local function civilFromDays(z: number): (number, number, number)
	z += 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	return if m <= 2 then y + 1 else y, m, d
end

local DateTimeMethods = {}
local DateTimeMeta = { __type = "DateTime" }
DateTimeMeta.__index = function(self, key)
	if key == "UnixTimestampMillis" then
		return rawget(self, "_ms")
	elseif key == "UnixTimestamp" then
		return rawget(self, "_ms") // 1000
	end
	local m = DateTimeMethods[key]
	if m == nil then
		error(("%s is not a valid member of DateTime"):format(tostring(key)), 2)
	end
	return m
end
DateTimeMeta.__eq = function(a, b)
	return rawget(a, "_ms") == rawget(b, "_ms")
end
DateTimeMeta.__lt = function(a, b)
	return rawget(a, "_ms") < rawget(b, "_ms")
end
DateTimeMeta.__le = function(a, b)
	return rawget(a, "_ms") <= rawget(b, "_ms")
end

local function newDateTime(ms: number)
	return setmetatable({ _ms = math.floor(ms) }, DateTimeMeta)
end

function DateTimeMethods:ToUniversalTime()
	local ms = rawget(self, "_ms")
	local days = ms // 86400000
	local rest = ms - days * 86400000
	local y, m, d = civilFromDays(days)
	return {
		Year = y,
		Month = m,
		Day = d,
		Hour = rest // 3600000,
		Minute = (rest // 60000) % 60,
		Second = (rest // 1000) % 60,
		Millisecond = rest % 1000,
	}
end
DateTimeMethods.ToLocalTime = DateTimeMethods.ToUniversalTime

function DateTimeMethods:ToIsoDate(): string
	local t = self:ToUniversalTime()
	return ("%04d-%02d-%02dT%02d:%02d:%02dZ"):format(
		t.Year,
		t.Month,
		t.Day,
		t.Hour,
		t.Minute,
		t.Second
	)
end

-- Supports the common tokens: YYYY MM DD HH mm ss (anything else is kept as is).
function DateTimeMethods:FormatUniversalTime(format: string): string
	local t = self:ToUniversalTime()
	local out = format
		:gsub("YYYY", ("%04d"):format(t.Year))
		:gsub("MM", ("%02d"):format(t.Month))
		:gsub("DD", ("%02d"):format(t.Day))
		:gsub("HH", ("%02d"):format(t.Hour))
		:gsub("mm", ("%02d"):format(t.Minute))
		:gsub("ss", ("%02d"):format(t.Second))
	return out
end
DateTimeMethods.FormatLocalTime = DateTimeMethods.FormatUniversalTime

local function makeDateTime(clock: () -> number)
	local DateTime = {}
	function DateTime.now()
		return newDateTime(clock() * 1000)
	end
	function DateTime.fromUnixTimestamp(seconds: number)
		return newDateTime(seconds * 1000)
	end
	function DateTime.fromUnixTimestampMillis(ms: number)
		return newDateTime(ms)
	end
	function DateTime.fromUniversalTime(
		y: number?,
		mo: number?,
		d: number?,
		h: number?,
		mi: number?,
		s: number?,
		ms: number?
	)
		local days = daysFromCivil(y or 1970, mo or 1, d or 1)
		return newDateTime(
			((days * 24 + (h or 0)) * 60 + (mi or 0)) * 60000 + (s or 0) * 1000 + (ms or 0)
		)
	end
	DateTime.fromLocalTime = DateTime.fromUniversalTime
	function DateTime.fromIsoDate(text: string)
		local y, mo, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
		if not y then
			return nil
		end
		local h, mi, s = text:match("T(%d%d):(%d%d):(%d%d)")
		return DateTime.fromUniversalTime(
			tonumber(y),
			tonumber(mo),
			tonumber(d),
			tonumber(h) or 0,
			tonumber(mi) or 0,
			tonumber(s) or 0
		)
	end
	return DateTime
end

Globals.daysFromCivil = daysFromCivil

-- The environment -----------------------------------------------------------------------------------

local function formatArgs(...): string
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

-- Builds the shared global table for one runtime. Each script gets
-- setmetatable({ script = ... }, { __index = env }).
function Globals.build(rt: any): { [string]: any }
	local scheduler = rt.scheduler
	local function clock(): number
		return rt.epoch + scheduler.now
	end

	local task = {
		spawn = function(fn, ...)
			return scheduler:spawn(fn, ...)
		end,
		defer = function(fn, ...)
			return scheduler:defer(fn, ...)
		end,
		delay = function(t, fn, ...)
			return scheduler:delay(t, fn, ...)
		end,
		wait = function(t)
			return scheduler:wait(t)
		end,
		cancel = function(thread)
			scheduler:cancel(thread)
		end,
		synchronize = function() end,
		desynchronize = function() end,
	}

	local vos = {
		time = function(t)
			if t ~= nil then
				return os.time(t)
			end
			return math.floor(clock())
		end,
		clock = function()
			return scheduler.now
		end,
		date = function(format, t)
			return os.date(format, t or math.floor(clock()))
		end,
		difftime = os.difftime,
	}

	local vdebug = table.clone(debug)
	vdebug.profilebegin = function() end
	vdebug.profileend = function() end
	vdebug.setmemorycategory = function() end
	vdebug.resetmemorycategory = function() end
	vdebug.getmemorycategory = function()
		return "Default"
	end

	local shared = {}
	local G = {}

	local InstanceLib = {
		new = function(className, parent)
			if type(className) ~= "string" then
				error("invalid argument #1 to 'new' (string expected)", 2)
			end
			local inst = Dom.new(rt, className)
			if parent ~= nil then
				(inst :: any).Parent = parent
			end
			return inst
		end,
		fromExisting = function(existing)
			local d = Dom.data(existing)
			if not d then
				error("invalid argument #1 to 'fromExisting' (Instance expected)", 2)
			end
			local copy = Dom.new(rt, d.ClassName, true)
			for k, v in d.props do
				Dom.rawSet(copy, k, v)
			end
			return copy
		end,
	}

	local env = {
		-- Luau
		assert = assert,
		error = error,
		getmetatable = getmetatable,
		setmetatable = setmetatable,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		pcall = pcall,
		xpcall = xpcall,
		rawequal = rawequal,
		rawget = rawget,
		rawset = rawset,
		rawlen = rawlen,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = table.unpack,
		newproxy = newproxy,
		gcinfo = gcinfo,
		getfenv = getfenv,
		setfenv = setfenv,
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		bit32 = bit32,
		utf8 = utf8,
		buffer = buffer,
		vector = vector :: any,
		debug = vdebug,
		os = vos,
		collectgarbage = function(option)
			if option == "count" then
				return gcinfo()
			end
			error("collectgarbage must be called with 'count'", 2)
		end,
		-- Roblox
		typeof = typeof,
		print = function(...)
			rt:log("print", formatArgs(...))
		end,
		warn = function(...)
			rt:log("warn", formatArgs(...))
		end,
		tick = clock,
		time = function()
			return scheduler.now
		end,
		elapsedTime = function()
			return scheduler.now
		end,
		wait = function(t)
			local elapsed = scheduler:wait(t)
			return elapsed, scheduler.now
		end,
		delay = function(t, fn)
			scheduler:delay(t, fn)
		end,
		spawn = function(fn)
			scheduler:defer(fn)
		end,
		version = function()
			return "0.0.0.0"
		end,
		task = task,
		shared = shared,
		_G = G,
		plugin = nil,
		game = rt.game,
		workspace = rt.workspace,
		Workspace = rt.workspace,
		Instance = InstanceLib,
		Enum = Enum,
		Random = Random,
		TweenInfo = TweenInfo,
		DateTime = makeDateTime(clock),
		RaycastParams = Globals.RaycastParams,
		OverlapParams = Globals.OverlapParams,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		Vector3int16 = roblox.Vector3int16,
		Vector2int16 = roblox.Vector2int16,
		CFrame = Globals.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Ray = roblox.Ray,
		Region3 = roblox.Region3,
		Region3int16 = roblox.Region3int16,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		PhysicalProperties = roblox.PhysicalProperties,
		Font = roblox.Font,
		Faces = roblox.Faces,
		Axes = roblox.Axes,
		PathWaypoint = {
			new = function(position, action, label)
				local w = Services.waypoint(position)
				w.Action = action or w.Action
				w.Label = label or ""
				return w
			end,
		},
		require = function(target)
			return rt:_require(target)
		end,
		settings = function()
			return rt:settings()
		end,
		UserSettings = function()
			return rt:userSettings()
		end,
	}
	return env
end

return Globals
