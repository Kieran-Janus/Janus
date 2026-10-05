--[[
	Dom: a pure-Luau stand-in for Roblox's instance tree.

	Why not Lune's own Instance? Lune hands out a new userdata on every access (so instances
	can't be table keys: `cache[player]` breaks), it can't override built-in properties such
	as BasePart.Position or Model.WorldPivot, and parenting into a destroyed instance panics
	and poisons every later test. So instances here are Luau userdata with:

	  - classes, superclasses, property types and defaults from Lune's reflection database
	    (roblox.getReflectionDatabase()), with Roblox-like type checks on assignment;
	  - events, methods and callbacks from Api.luau (generated from luau-lsp's definitions):
	    every event exists as a signal, every method the harness doesn't implement is a
	    recorded no-op stub that returns a harmless default;
	  - harness behaviour layered on top with Dom.define (see Engine.luau / Services.luau).

	Each instance belongs to a "world" (the Runtime): its scheduler runs event handlers and
	its call log records stubbed engine calls.
]]

local roblox = require("@lune/roblox")
local Api = require("./Api")
local Signal = require("./Signal")
local Types = require("./Types")

local db = roblox.getReflectionDatabase()
local Enum = roblox.Enum
local Vector3, Vector2, CFrame, Color3 =
	roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Color3
local typeof = Types.typeof

local Dom = {}

-- Classes -------------------------------------------------------------------------------------

export type Member = {
	kind: string, -- "prop" | "method" | "event" | "callback"
	type: string?, -- reflection datatype of a prop ("Vector3", "Enum.Material", "Ref", ...)
	hint: string?, -- default-value hint (Api.luau)
	readOnly: boolean?,
	get: ((any, any) -> any)?,
	set: ((any, any, any) -> ())?,
	fn: ((...any) -> ...any)?,
	harness: boolean?, -- defined by the harness (wins over generated members)
}

export type Class = {
	Name: string,
	Super: Class?,
	Tags: { [string]: boolean },
	Db: any,
	members: { [string]: Member }?,
	defaults: { [string]: any }?,
	inits: { (any, any) -> () }?,
	isA: { [string]: boolean },
}

local classes: { [string]: Class | false } = {}
local overrides: { [string]: { [string]: Member } } = {}
local initializers: { [string]: { (any, any) -> () } } = {}

local function getClass(name: string): Class?
	local cached = classes[name]
	if cached ~= nil then
		return cached or nil
	end
	local dbClass = type(name) == "string" and db:GetClass(name) or nil
	if not dbClass then
		classes[name] = false
		return nil
	end
	local class: Class = {
		Name = name,
		Super = nil,
		Tags = {},
		Db = dbClass,
		isA = { [name] = true },
	}
	for _, tag in dbClass.Tags do
		class.Tags[tag] = true
	end
	classes[name] = class
	if dbClass.Superclass then
		class.Super = getClass(dbClass.Superclass)
		local super = class.Super
		while super do
			class.isA[super.Name] = true
			super = super.Super
		end
	end
	return class
end
Dom.getClass = getClass

local HINT_ZERO = {
	b = false,
	n = 0,
	s = "",
	v = Vector3.zero,
	f = CFrame.identity,
	w = Vector2.zero,
	["3"] = Color3.new(),
	u = roblox.UDim2.new(),
}

local function addApi(members: { [string]: Member }, className: string)
	local entry = Api[className]
	if not entry then
		return
	end
	local function free(name: string): boolean
		local existing = members[name]
		return existing == nil or not existing.harness
	end
	for name in entry[2]:gmatch("%S+") do
		if free(name) then
			members[name] = { kind = "event" }
		end
	end
	for word in entry[3]:gmatch("%S+") do
		local name, hint = word:match("^([^:]+):?(.*)$")
		if name and free(name) then
			members[name] = { kind = "method", stub = true, hint = hint, name = name } :: any
		end
	end
	for name in entry[4]:gmatch("%S+") do
		if free(name) then
			members[name] = { kind = "callback" }
		end
	end
	for word in entry[5]:gmatch("%S+") do
		local name, hint = word:match("^([^:]+):?(.*)$")
		if name and members[name] == nil then
			members[name] = { kind = "prop", hint = hint }
		end
	end
end

local makeStub: (string, string?) -> (...any) -> ...any

local function membersOf(class: Class): ({ [string]: Member }, { [string]: any })
	if class.members then
		return class.members :: any, class.defaults :: any
	end
	local members: { [string]: Member } = {}
	local defaults: { [string]: any } = {}
	if class.Super then
		local superMembers, superDefaults = membersOf(class.Super)
		for k, v in superMembers do
			members[k] = v
		end
		for k, v in superDefaults do
			defaults[k] = v
		end
	else
		addApi(members, "Object")
	end
	for name, prop in class.Db.Properties do
		local s = prop.Scriptability
		if s ~= "None" and s ~= "Custom" then
			local existing = members[name]
			if not (existing and existing.harness) then
				members[name] = { kind = "prop", type = prop.Datatype, readOnly = s == "Read" }
			end
		end
	end
	for name, value in class.Db.DefaultProperties do
		defaults[name] = value
	end
	addApi(members, class.Name)
	local own = overrides[class.Name]
	if own then
		for name, member in own do
			members[name] = member
		end
	end
	-- Generated method stubs get their function now (one per class and name).
	for name, member in members do
		local m = member :: any
		if m.kind == "method" and m.stub and not m.fn then
			members[name] =
				{ kind = "method", fn = makeStub(name, m.hint), hint = m.hint, stub = true }
		end
	end
	local inits = {}
	local chain: { Class } = {}
	local c: Class? = class
	while c do
		table.insert(chain, 1, c)
		c = c.Super
	end
	for _, link in chain do
		for _, init in initializers[link.Name] or {} do
			table.insert(inits, init)
		end
	end
	class.members, class.defaults, class.inits = members, defaults, inits
	return members, defaults
end

local function resetMembers()
	for _, class in classes do
		if class then
			class.members = nil
			class.defaults = nil
			class.inits = nil
		end
	end
end

-- Instance data -------------------------------------------------------------------------------

export type Data = {
	u: any, -- the userdata scripts see
	class: Class,
	ClassName: string,
	Name: string,
	parent: Data?,
	children: { Data },
	props: { [string]: any },
	attrs: { [string]: any }?,
	tags: { string }?,
	signals: { [string]: any }?,
	propSignals: { [string]: any }?,
	attrSignals: { [string]: any }?,
	callbacks: { [string]: any }?,
	world: any,
	destroyed: boolean?,
	parentLocked: boolean?,
	source: string?,
	sourcePath: string?,
	debugId: number?,
}

local function dataOf(value: any): Data?
	if type(value) ~= "userdata" then
		return nil
	end
	local mt = getmetatable(value)
	if type(mt) ~= "table" then
		return nil
	end
	return rawget(mt, "__d")
end
Dom.data = dataOf

function Dom.isInstance(value: any): boolean
	return dataOf(value) ~= nil
end

local function fullName(d: Data): string
	local names = { d.Name }
	local p = d.parent
	while p and p.ClassName ~= "DataModel" do
		table.insert(names, 1, p.Name)
		p = p.parent
	end
	return table.concat(names, ".")
end
Dom.fullNameOf = fullName

local function findChild(d: Data, name: string): Data?
	for _, child in d.children do
		if child.Name == name then
			return child
		end
	end
	return nil
end

-- Defaults ------------------------------------------------------------------------------------

local ZERO: { [string]: any } = {
	Bool = false,
	Float32 = 0,
	Float64 = 0,
	Int32 = 0,
	Int64 = 0,
	String = "",
	Content = "",
	ContentId = "",
	BinaryString = "",
	ProtectedString = "",
	Vector3 = Vector3.zero,
	Vector2 = Vector2.zero,
	CFrame = CFrame.identity,
	Color3 = Color3.new(),
	UDim = roblox.UDim.new(0, 0),
	UDim2 = roblox.UDim2.new(),
	NumberRange = roblox.NumberRange.new(0),
	NumberSequence = roblox.NumberSequence.new(0),
	ColorSequence = roblox.ColorSequence.new(Color3.new()),
	Rect = roblox.Rect.new(0, 0, 0, 0),
	BrickColor = roblox.BrickColor.new("Medium stone grey"),
	Font = roblox.Font.new("rbxasset://fonts/families/SourceSansPro.json"),
	Faces = roblox.Faces.new(),
	Axes = roblox.Axes.new(),
}

local enumZero: { [string]: any } = {}
local function zeroFor(datatype: string?, hint: string?): any
	if datatype then
		local z = ZERO[datatype]
		if z ~= nil then
			return z
		end
		local enumName = datatype:match("^Enum%.(.+)$")
		if enumName then
			if enumZero[enumName] == nil then
				local ok, items = pcall(function()
					return Enum[enumName]:GetEnumItems()
				end)
				local best = nil
				if ok then
					for _, item in items do
						if best == nil or item.Value < best.Value then
							best = item
						end
					end
				end
				enumZero[enumName] = best or false
			end
			return enumZero[enumName] or nil
		end
		return nil
	end
	if hint then
		return HINT_ZERO[hint]
	end
	return nil
end

-- Type checks on assignment -------------------------------------------------------------------

local PRIMITIVE = {
	Bool = "boolean",
	Float32 = "number",
	Float64 = "number",
	Int32 = "number",
	Int64 = "number",
	String = "string",
	Content = "string",
	ContentId = "string",
	BinaryString = "string",
	ProtectedString = "string",
}

local DATATYPES = {
	Vector3 = true,
	Vector2 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
	Rect = true,
	BrickColor = true,
	PhysicalProperties = true,
	Faces = true,
	Axes = true,
	Font = true,
	Ray = true,
	Region3 = true,
	Region3int16 = true,
	Vector3int16 = true,
	Vector2int16 = true,
}

local function findEnumItem(datatype: string, value: any): any
	local enumName = datatype:sub(6)
	local ok, items = pcall(function()
		return Enum[enumName]:GetEnumItems()
	end)
	if not ok then
		return nil
	end
	for _, item in items do
		if item.Name == value or item.Value == value then
			return item
		end
	end
	return nil
end

local function coerce(datatype: string?, value: any, key: string, level: number): any
	if datatype == nil then
		return value
	end
	local vt = typeof(value)
	local function fail(expected: string)
		error(
			("Unable to assign property %s. %s expected, got %s"):format(key, expected, vt),
			level + 1
		)
	end
	local prim = PRIMITIVE[datatype]
	if prim then
		if vt == prim then
			return value
		elseif prim == "number" and vt == "string" and tonumber(value) then
			return tonumber(value)
		elseif prim == "string" and vt == "number" then
			return tostring(value)
		end
		fail(prim)
	end
	if datatype == "Ref" then
		if value == nil or dataOf(value) then
			return value
		end
		fail("Instance")
	end
	if datatype == "OptionalCFrame" then
		if value == nil or vt == "CFrame" then
			return value
		end
		fail("CFrame")
	end
	if DATATYPES[datatype] then
		if vt == datatype or (datatype == "PhysicalProperties" and value == nil) then
			return value
		end
		fail(datatype)
	end
	if datatype:sub(1, 5) == "Enum." then
		if vt == "EnumItem" then
			if tostring(value.EnumType) == datatype then
				return value
			end
			error(
				("Unable to assign property %s. %s expected, got %s"):format(
					key,
					datatype,
					tostring(value)
				),
				level
			)
		elseif vt == "string" or vt == "number" then
			local item = findEnumItem(datatype, value)
			if item then
				return item
			end
		end
		fail(datatype)
	end
	return value
end

-- Events --------------------------------------------------------------------------------------

local function signalFor(d: Data, name: string)
	local signals = d.signals
	if not signals then
		signals = {}
		d.signals = signals
	end
	local s = signals[name]
	if not s then
		s = Signal.new(name, d.world)
		signals[name] = s
	end
	return s
end

local function emit(d: Data, name: string, ...)
	local signals = d.signals
	local s = signals and signals[name]
	if s then
		Signal.fire(s, ...)
	end
end

local function listening(d: Data, name: string): boolean
	local w = d.world
	return w ~= nil and (w.listening[name] or 0) > 0
end

local function changed(d: Data, key: string)
	if d.signals then
		emit(d, "Changed", key)
	end
	local ps = d.propSignals and d.propSignals[key]
	if ps then
		Signal.fire(ps)
	end
end

-- Property access -----------------------------------------------------------------------------

local function readProp(d: Data, key: string, member: Member): any
	local get = member.get
	if get then
		return get(d.u, d)
	end
	local v = d.props[key]
	if v ~= nil then
		return v
	end
	v = (d.class.defaults :: any)[key]
	if v ~= nil then
		return v
	end
	return zeroFor(member.type, member.hint)
end

local function writeProp(
	d: Data,
	key: string,
	member: Member,
	value: any,
	level: number,
	internal: boolean?
)
	local set = member.set
	if set then
		set(d.u, d, value)
		return
	end
	if not internal and (member.readOnly or member.get) then
		error(("Unable to assign property %s. Property is read only"):format(key), level)
	end
	value = coerce(member.type, value, key, level + 1)
	local old = d.props[key]
	d.props[key] = value
	if (d.signals or d.propSignals) and old ~= value then
		changed(d, key)
	end
end

local function index(u: any, key: any): any
	local d: Data = getmetatable(u).__d
	local class = d.class
	local member = (class.members or membersOf(class))[key]
	if member then
		local kind = member.kind
		if kind == "prop" then
			return readProp(d, key, member)
		elseif kind == "method" then
			return member.fn
		elseif kind == "event" then
			return signalFor(d, key)
		else
			error(
				("%s is a callback member of %s; you can only set the callback value, get is not available"):format(
					key,
					d.ClassName
				),
				2
			)
		end
	end
	if type(key) == "string" then
		local child = findChild(d, key)
		if child then
			return child.u
		end
	end
	error(
		('%s is not a valid member of %s "%s"'):format(tostring(key), d.ClassName, fullName(d)),
		2
	)
end

local function newindex(u: any, key: any, value: any)
	local d: Data = getmetatable(u).__d
	local class = d.class
	local member = (class.members or membersOf(class))[key]
	if not member then
		error(
			('%s is not a valid member of %s "%s"'):format(tostring(key), d.ClassName, fullName(d)),
			2
		)
	end
	local kind = member.kind
	if kind == "prop" then
		writeProp(d, key, member, value, 3)
	elseif kind == "callback" then
		if value ~= nil and type(value) ~= "function" then
			error(("%s must be a function"):format(key), 2)
		end
		d.callbacks = d.callbacks or {};
		(d.callbacks :: any)[key] = value
	else
		error(("%s cannot be assigned to"):format(key), 2)
	end
end

local function tostr(u: any): string
	return getmetatable(u).__d.Name
end

-- Creation ------------------------------------------------------------------------------------

local function newData(world: any, class: Class, className: string): Data
	local u = newproxy(true)
	local mt = getmetatable(u)
	local d: Data = {
		u = u,
		class = class,
		ClassName = className,
		Name = className,
		parent = nil,
		children = {},
		props = {},
		world = world,
	}
	mt.__d = d
	mt.__index = index
	mt.__newindex = newindex
	mt.__tostring = tostr
	mt.__type = "Instance"
	if world then
		world.instanceCount = (world.instanceCount or 0) + 1
	end
	return d
end

--[[
	Creates an instance of `className` in `world`. Scripts can't create services or
	NotCreatable classes; the harness itself passes internal = true to do so.
]]
function Dom.new(world: any, className: string, internal: boolean?): any
	local class = getClass(className)
	if not class or (not internal and (class.Tags.NotCreatable or class.Tags.Service)) then
		error(('Unable to create an Instance of type "%s"'):format(tostring(className)), 3)
	end
	membersOf(class)
	local d = newData(world, class, className)
	for _, init in class.inits :: any do
		init(d.u, d)
	end
	return d.u
end

-- Harness extension points ------------------------------------------------------------------

--[[
	Adds or replaces members of a class (and its subclasses):
	  Dom.define("Model", {
	      GetPivot = function(self) ... end,                     -- method
	      WorldPivot = { get = function(u, d) ... end, set = ... }, -- property
	      Something = "event",                                    -- event
	  })
]]
function Dom.define(className: string, defs: { [string]: any })
	assert(getClass(className), "Dom.define: unknown class " .. className)
	local own = overrides[className] or {}
	overrides[className] = own
	for name, def in defs do
		if type(def) == "function" then
			-- Stored as is (no wrapper) so error(msg, 2) inside it points at the calling script.
			own[name] = { kind = "method", harness = true, fn = def }
		elseif def == "event" then
			own[name] = { kind = "event", harness = true }
		elseif def == "callback" then
			own[name] = { kind = "callback", harness = true }
		elseif type(def) == "table" then
			own[name] = {
				kind = "prop",
				harness = true,
				get = def.get,
				set = def.set,
				type = def.type,
				readOnly = def.readOnly,
			}
		end
	end
	resetMembers()
end

-- Runs `fn(u, d)` for every new instance of className (or a subclass).
function Dom.onCreate(className: string, fn: (any, any) -> ())
	initializers[className] = initializers[className] or {}
	table.insert(initializers[className], fn)
	resetMembers()
end

function Dom.member(u: any, key: string): Member?
	local d = dataOf(u)
	if not d then
		return nil
	end
	return (membersOf(d.class))[key]
end

-- Reads a property without member checks (used by harness code; fast path for set props).
function Dom.get(u: any, key: string): any
	local d = dataOf(u) :: Data
	local v = d.props[key]
	if v ~= nil then
		return v
	end
	local member = membersOf(d.class)[key]
	if not member then
		return nil
	end
	return readProp(d, key, member)
end

-- Writes a property from harness code: type-checked, read-only allowed, fires Changed.
function Dom.set(u: any, key: string, value: any)
	local d = dataOf(u) :: Data
	local member = membersOf(d.class)[key]
	if member and member.set then
		member.set(u, d, value)
	elseif member and member.kind == "prop" and not member.get then
		writeProp(d, key, member, value, 3, true)
	else
		local old = d.props[key]
		d.props[key] = value
		if (d.signals or d.propSignals) and old ~= value then
			changed(d, key)
		end
	end
end

-- Stores a raw value with no checks and no events (custom property storage).
function Dom.rawSet(u: any, key: string, value: any)
	(dataOf(u) :: Data).props[key] = value
end

function Dom.rawGet(u: any, key: string): any
	return (dataOf(u) :: Data).props[key]
end

Dom.changed = function(u: any, key: string)
	changed(dataOf(u) :: Data, key)
end

function Dom.signal(u: any, name: string)
	return signalFor(dataOf(u) :: Data, name)
end

function Dom.emit(u: any, name: string, ...)
	emit(dataOf(u) :: Data, name, ...)
end

function Dom.callback(u: any, name: string): ((...any) -> ...any)?
	local d = dataOf(u) :: Data
	return d.callbacks and d.callbacks[name]
end

function Dom.isA(u: any, className: string): boolean
	local d = dataOf(u)
	return d ~= nil and d.class.isA[className] == true
end

function Dom.setSource(u: any, source: string, path: string?)
	local d = dataOf(u) :: Data
	d.source = source
	d.sourcePath = path
end

function Dom.fullName(u: any): string
	return fullName(dataOf(u) :: Data)
end

-- Tree helpers ----------------------------------------------------------------------------------

local function collect(d: Data, out: { Data })
	for _, child in d.children do
		table.insert(out, child)
		collect(child, out)
	end
end

-- Descendant data, depth-first pre-order (the order GetDescendants uses).
function Dom.descendantData(d: Data): { Data }
	local out = {}
	collect(d, out)
	return out
end

function Dom.descendants(u: any, className: string?): { any }
	local out = {}
	for _, d in Dom.descendantData(dataOf(u) :: Data) do
		if not className or d.class.isA[className] then
			table.insert(out, d.u)
		end
	end
	return out
end

local function rootOf(d: Data): Data
	while d.parent do
		d = d.parent
	end
	return d
end

local function inGame(d: Data): boolean
	local w = d.world
	return w ~= nil and w.gameData ~= nil and rootOf(d) == w.gameData
end
Dom.inGame = inGame

local function tagListeners(d: Data): boolean
	local w = d.world
	return w ~= nil and w.tagSignals ~= nil and next(w.tagSignals) ~= nil
end

local function fireTag(d: Data, tag: string, added: boolean)
	local w = d.world
	local pair = w and w.tagSignals and w.tagSignals[tag]
	if pair then
		local s = if added then pair.added else pair.removed
		if s then
			Signal.fire(s, d.u)
		end
	end
end

local function fireSubtreeTags(d: Data, added: boolean)
	local function visit(x: Data)
		if x.tags then
			for _, tag in x.tags do
				fireTag(x, tag, added)
			end
		end
		for _, child in x.children do
			visit(child)
		end
	end
	visit(d)
end

-- Parenting ---------------------------------------------------------------------------------------

local function setParent(d: Data, parent: Data?, level: number)
	if d.parentLocked then
		error(
			("The Parent property of %s is locked, current parent: %s, new parent %s"):format(
				d.Name,
				if d.parent then d.parent.Name else "NULL",
				if parent then parent.Name else "NULL"
			),
			level
		)
	end
	if parent then
		local a: Data? = parent
		while a do
			if a == d then
				error(
					("Attempt to set parent of %s to %s would result in circular reference"):format(
						fullName(d),
						fullName(parent)
					),
					level
				)
			end
			a = a.parent
		end
	end
	local old = d.parent
	if old == parent then
		return
	end
	local tagged = tagListeners(d)
	local wasInGame = tagged and inGame(d)
	if old then
		if listening(d, "DescendantRemoving") then
			local a: Data? = old
			local moving = { d }
			collect(d, moving)
			while a do
				for _, m in moving do
					emit(a, "DescendantRemoving", m.u)
				end
				a = a.parent
			end
		end
		local i = table.find(old.children, d)
		if i then
			table.remove(old.children, i)
		end
	end
	d.parent = parent
	if parent then
		table.insert(parent.children, d)
	end
	if old then
		emit(old, "ChildRemoved", d.u)
	end
	if parent then
		emit(parent, "ChildAdded", d.u)
		if listening(d, "DescendantAdded") then
			local moving = { d }
			collect(d, moving)
			local a: Data? = parent
			while a do
				for _, m in moving do
					emit(a, "DescendantAdded", m.u)
				end
				a = a.parent
			end
		end
	end
	if listening(d, "AncestryChanged") then
		local pu = if parent then parent.u else nil
		emit(d, "AncestryChanged", d.u, pu)
		for _, m in Dom.descendantData(d) do
			emit(m, "AncestryChanged", d.u, pu)
		end
	end
	if d.signals or d.propSignals then
		changed(d, "Parent")
	end
	if tagged then
		local nowInGame = inGame(d)
		if nowInGame ~= wasInGame then
			fireSubtreeTags(d, nowInGame)
		end
	end
end

function Dom.setParent(u: any, parent: any)
	setParent(dataOf(u) :: Data, if parent ~= nil then dataOf(parent) else nil, 3)
end

local function destroy(d: Data)
	if d.destroyed then
		return
	end
	emit(d, "Destroying")
	if d.parent then
		setParent(d, nil, 3)
	end
	d.parentLocked = true
	d.destroyed = true
	for _, child in table.clone(d.children) do
		destroy(child)
	end
	for _, s in d.signals or {} do
		Signal.disconnectAll(s)
	end
	for _, s in d.propSignals or {} do
		Signal.disconnectAll(s)
	end
	for _, s in d.attrSignals or {} do
		Signal.disconnectAll(s)
	end
end
Dom.destroy = function(u: any)
	destroy(dataOf(u) :: Data)
end

local function cloneTree(root: Data, intoWorld: any?): Data?
	local map: { [Data]: Data } = {}
	local list: { Data } = {}
	local function copy(d: Data, isRoot: boolean): Data?
		if d.props.Archivable == false then
			return nil
		end
		local c = newData(intoWorld or d.world, d.class, d.ClassName)
		c.Name = d.Name
		for k, v in d.props do
			c.props[k] = v
		end
		if d.attrs then
			c.attrs = table.clone(d.attrs)
		end
		if d.tags then
			c.tags = table.clone(d.tags)
		end
		c.source, c.sourcePath = d.source, d.sourcePath
		map[d] = c
		table.insert(list, c)
		for _, child in d.children do
			local cc = copy(child, false)
			if cc then
				cc.parent = c
				table.insert(c.children, cc)
			end
		end
		return c
	end
	local result = copy(root, true)
	-- References inside the copied tree (PrimaryPart, Part0, Attachment0...) point at the copies.
	for _, c in list do
		for k, v in c.props do
			local vd = dataOf(v)
			if vd and map[vd] then
				c.props[k] = map[vd].u
			end
		end
	end
	return result
end

-- A copy of `u` (and its descendants) that belongs to another world (runtime).
function Dom.cloneInto(u: any, intoWorld: any): any
	local c = cloneTree(dataOf(u) :: Data, intoWorld)
	return c and c.u
end

-- Attributes --------------------------------------------------------------------------------------

local ATTRIBUTE_TYPES = {
	boolean = true,
	number = true,
	string = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

local function checkAttributeName(name: any, level: number)
	if type(name) ~= "string" then
		error(("Attribute name must be a string, got %s"):format(typeof(name)), level)
	end
	if #name > 100 or not name:match("^[%w_]+$") or name:sub(1, 3) == "RBX" then
		error(("Attribute name '%s' is invalid"):format(name), level)
	end
end

-- Built-in Instance members -----------------------------------------------------------------------

local function isA(d: Data, className: string): boolean
	return d.class.isA[className] == true
end

local function findDescendant(d: Data, pred: (Data) -> boolean): Data?
	for _, child in d.children do
		if pred(child) then
			return child
		end
		local found = findDescendant(child, pred)
		if found then
			return found
		end
	end
	return nil
end

Dom.define("Instance", {
	Name = {
		get = function(_, d)
			return d.Name
		end,
		set = function(_, d, value)
			if type(value) == "number" then
				value = tostring(value)
			end
			if type(value) ~= "string" then
				error(
					("Unable to assign property Name. string expected, got %s"):format(
						typeof(value)
					),
					4
				)
			end
			if d.Name ~= value then
				d.Name = value
				if d.signals or d.propSignals then
					changed(d, "Name")
				end
			end
		end,
	},
	Parent = {
		get = function(_, d)
			return if d.parent then d.parent.u else nil
		end,
		set = function(_, d, value)
			local pd = nil
			if value ~= nil then
				pd = dataOf(value)
				if not pd then
					error(
						("Unable to assign property Parent. Instance expected, got %s"):format(
							typeof(value)
						),
						4
					)
				end
			end
			setParent(d, pd, 5)
		end,
	},
	ClassName = {
		get = function(_, d)
			return d.ClassName
		end,
		readOnly = true,
	},
	IsA = function(self, className)
		return isA(dataOf(self) :: Data, className)
	end,
	FindFirstChild = function(self, name, recursive)
		local d = dataOf(self) :: Data
		local found = if recursive
			then findDescendant(d, function(x)
				return x.Name == name
			end)
			else findChild(d, name)
		return found and found.u
	end,
	FindFirstChildOfClass = function(self, className)
		for _, child in (dataOf(self) :: Data).children do
			if child.ClassName == className then
				return child.u
			end
		end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, className, recursive)
		local d = dataOf(self) :: Data
		if recursive then
			local found = findDescendant(d, function(x)
				return isA(x, className)
			end)
			return found and found.u
		end
		for _, child in d.children do
			if isA(child, className) then
				return child.u
			end
		end
		return nil
	end,
	FindFirstDescendant = function(self, name)
		local found = findDescendant(dataOf(self) :: Data, function(x)
			return x.Name == name
		end)
		return found and found.u
	end,
	FindFirstAncestor = function(self, name)
		local a = (dataOf(self) :: Data).parent
		while a do
			if a.Name == name then
				return a.u
			end
			a = a.parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, className)
		local a = (dataOf(self) :: Data).parent
		while a do
			if a.ClassName == className then
				return a.u
			end
			a = a.parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, className)
		local a = (dataOf(self) :: Data).parent
		while a do
			if isA(a, className) then
				return a.u
			end
			a = a.parent
		end
		return nil
	end,
	GetChildren = function(self)
		local out = {}
		for i, child in (dataOf(self) :: Data).children do
			out[i] = child.u
		end
		return out
	end,
	GetDescendants = function(self)
		local out = {}
		for i, d in Dom.descendantData(dataOf(self) :: Data) do
			out[i] = d.u
		end
		return out
	end,
	IsDescendantOf = function(self, ancestor)
		local target = dataOf(ancestor)
		local a = (dataOf(self) :: Data).parent
		while a do
			if a == target then
				return true
			end
			a = a.parent
		end
		return false
	end,
	IsAncestorOf = function(self, descendant)
		local d = dataOf(self)
		local a = dataOf(descendant)
		a = a and a.parent
		while a do
			if a == d then
				return true
			end
			a = a.parent
		end
		return false
	end,
	GetFullName = function(self)
		return fullName(dataOf(self) :: Data)
	end,
	GetDebugId = function(self)
		local d = dataOf(self) :: Data
		if not d.debugId then
			local w = d.world or {}
			w.nextDebugId = (w.nextDebugId or 0) + 1
			d.debugId = w.nextDebugId
		end
		return ("%d_%d"):format(0, d.debugId :: number)
	end,
	Clone = function(self)
		local c = cloneTree(dataOf(self) :: Data)
		return c and c.u
	end,
	Destroy = function(self)
		destroy(dataOf(self) :: Data)
	end,
	Remove = function(self)
		setParent(dataOf(self) :: Data, nil, 3)
	end,
	ClearAllChildren = function(self)
		for _, child in table.clone((dataOf(self) :: Data).children) do
			destroy(child)
		end
	end,
	GetAttribute = function(self, name)
		checkAttributeName(name, 3)
		local attrs = (dataOf(self) :: Data).attrs
		return attrs and attrs[name]
	end,
	SetAttribute = function(self, name, value)
		checkAttributeName(name, 3)
		local vt = typeof(value)
		if value ~= nil and not ATTRIBUTE_TYPES[vt] then
			error(("SetAttribute: %s is not a supported attribute type"):format(vt), 2)
		end
		local d = dataOf(self) :: Data
		d.attrs = d.attrs or {}
		local attrs = d.attrs :: any
		local old = attrs[name]
		attrs[name] = value
		if old ~= value or typeof(old) ~= vt then
			emit(d, "AttributeChanged", name)
			local s = d.attrSignals and d.attrSignals[name]
			if s then
				Signal.fire(s)
			end
		end
	end,
	GetAttributes = function(self)
		local attrs = (dataOf(self) :: Data).attrs
		return if attrs then table.clone(attrs) else {}
	end,
	GetAttributeChangedSignal = function(self, name)
		local d = dataOf(self) :: Data
		d.attrSignals = d.attrSignals or {}
		local signals = d.attrSignals :: any
		signals[name] = signals[name] or Signal.new("AttributeChanged", d.world)
		return signals[name]
	end,
	GetPropertyChangedSignal = function(self, prop)
		local d = dataOf(self) :: Data
		local member = membersOf(d.class)[prop]
		if not member or member.kind ~= "prop" then
			error(("%s is not a valid property name."):format(tostring(prop)), 2)
		end
		d.propSignals = d.propSignals or {}
		local signals = d.propSignals :: any
		signals[prop] = signals[prop] or Signal.new("PropertyChanged", d.world)
		return signals[prop]
	end,
	AddTag = function(self, tag)
		local d = dataOf(self) :: Data
		d.tags = d.tags or {}
		if not table.find(d.tags :: any, tag) then
			table.insert(d.tags :: any, tag)
			if tagListeners(d) and inGame(d) then
				fireTag(d, tag, true)
			end
		end
	end,
	RemoveTag = function(self, tag)
		local d = dataOf(self) :: Data
		local i = d.tags and table.find(d.tags, tag)
		if i then
			table.remove(d.tags :: any, i)
			if tagListeners(d) and inGame(d) then
				fireTag(d, tag, false)
			end
		end
	end,
	HasTag = function(self, tag)
		local tags = (dataOf(self) :: Data).tags
		return tags ~= nil and table.find(tags, tag) ~= nil
	end,
	GetTags = function(self)
		local tags = (dataOf(self) :: Data).tags
		return if tags then table.clone(tags) else {}
	end,
	IsPropertyModified = function(self, prop)
		return (dataOf(self) :: Data).props[prop] ~= nil
	end,
	ResetPropertyToDefault = function(self, prop)
		(dataOf(self) :: Data).props[prop] = nil
	end,
	GetActor = function()
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		local d = dataOf(self) :: Data
		if type(name) ~= "string" then
			error("Argument 1 missing or nil", 2)
		end
		local child = findChild(d, name)
		if child then
			return child.u
		end
		local w = d.world
		local scheduler = w and w.scheduler
		if not scheduler then
			return nil
		end
		if scheduler:owns(coroutine.running()) then
			-- A task thread: yield a frame at a time until it appears.
			local start = scheduler.now
			local warned = false
			while true do
				scheduler:wait(0)
				child = findChild(d, name)
				if child then
					return child.u
				end
				local waited = scheduler.now - start
				if timeout and waited >= timeout then
					return nil
				end
				if not timeout and not warned and waited >= 5 then
					warned = true
					w:log(
						"warn",
						("Infinite yield possible on '%s:WaitForChild(\"%s\")'"):format(
							fullName(d),
							name
						)
					)
				end
			end
		end
		-- A test body or top-level require: let scheduled work run for a while first.
		local limit = timeout or w.waitForChildSeconds or 5
		local start = scheduler.now
		while scheduler.now - start < limit do
			scheduler:advance(scheduler.frame)
			child = findChild(d, name)
			if child then
				return child.u
			end
		end
		if timeout then
			return nil
		end
		error(
			('Infinite yield: %s:WaitForChild("%s") - nothing created it within %g virtual seconds'):format(
				fullName(d),
				name,
				limit
			),
			2
		)
	end,
})

-- Generated stubs ---------------------------------------------------------------------------------

local function hintValue(hint: string?): any
	if hint == nil or hint == "" then
		return nil
	elseif hint == "t" then
		return {}
	elseif hint == "c" then
		return Signal.dummyConnection()
	elseif hint == "g" then
		return Signal.new("Signal")
	end
	return HINT_ZERO[hint]
end

makeStub = function(name: string, hint: string?)
	return function(self, ...)
		local d = dataOf(self)
		if not d then
			error(("Expected ':' not '.' calling member function %s"):format(name), 2)
		end
		local w = d.world
		if w then
			w:recordCall(d.ClassName, name, self, ...)
		end
		return hintValue(hint)
	end
end

Dom.zeroFor = zeroFor

-- Type-checks a value assigned in a custom property setter (errors point at the script).
function Dom.check(datatype: string, value: any, key: string): any
	-- fail -> coerce -> check -> setter -> writeProp -> __newindex -> script
	return coerce(datatype, value, key, 6)
end

-- Error level that points at the script from inside a custom property setter.
Dom.SETTER_LEVEL = 4

return Dom
