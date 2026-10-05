--[[
	A tiny describe / it / expect test API (Jest-like; `.never` negates because `not` is a
	keyword in Luau):

	  local T = require("../harness/Test")
	  local describe, it, expect = T.describe, T.it, T.expect

	  describe("Config", function()
	      it("has maps", function()
	          expect(#Config.Maps.List).toBeGreaterThan(0)
	          expect(ids).never.toContain("")
	      end)
	  end)

	Matchers: toBe, toEqual (deep), toBeNear(x, epsilon?) (numbers, Vector2/3, CFrame,
	Color3), toBeTruthy, toBeFalsy, toBeNil, toBeGreaterThan, toBeGreaterThanOrEqual,
	toBeLessThan, toBeLessThanOrEqual, toContain, toHaveLength, toBeA(typeName),
	toBeInstanceOf(className), toMatch(pattern), toThrow(substring?), toBeFinite.
	T.note(...) adds a line to the test's report (shown under its name).
]]

local Types = require("./Types")

local typeof = Types.typeof

local Test = {}

export type Case = {
	name: string,
	fn: () -> (),
	before: { () -> () },
	after: { () -> () },
	skip: boolean,
}

local state = {
	cases = {} :: { Case },
	path = {} :: { string },
	before = {} :: { { () -> () } },
	after = {} :: { { () -> () } },
	notes = nil :: { string }?,
}

function Test.reset()
	state.cases = {}
	state.path = {}
	state.before = { {} }
	state.after = { {} }
end
Test.reset()

function Test.cases(): { Case }
	return state.cases
end

local function flatten(stack: { { () -> () } }): { () -> () }
	local out = {}
	for _, level in stack do
		for _, fn in level do
			table.insert(out, fn)
		end
	end
	return out
end

function Test.describe(name: string, fn: () -> ())
	table.insert(state.path, name)
	table.insert(state.before, {})
	table.insert(state.after, {})
	fn()
	table.remove(state.after)
	table.remove(state.before)
	table.remove(state.path)
end

local function add(name: string, fn: () -> (), skip: boolean)
	local path = table.clone(state.path)
	table.insert(path, name)
	table.insert(state.cases, {
		name = table.concat(path, " > "),
		fn = fn,
		before = flatten(state.before),
		after = flatten(state.after),
		skip = skip,
	})
end

function Test.it(name: string, fn: () -> ())
	add(name, fn, false)
end

function Test.skip(name: string, fn: () -> ())
	add(name, fn, true)
end

function Test.beforeEach(fn: () -> ())
	table.insert(state.before[#state.before], fn)
end

function Test.afterEach(fn: () -> ())
	table.insert(state.after[#state.after], fn)
end

-- Adds an informational line to the running test's report.
function Test.note(...)
	if state.notes then
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(state.notes, table.concat(parts, " "))
	end
end

function Test._setNotes(notes: { string }?)
	state.notes = notes
end

-- Formatting -------------------------------------------------------------------------------------

local function show(value: any, depth: number?): string
	local t = typeof(value)
	if t == "string" then
		return ("%q"):format(value)
	elseif t == "Instance" then
		local ok, name = pcall(function()
			return value:GetFullName()
		end)
		return "Instance(" .. (if ok then name else tostring(value)) .. ")"
	elseif t == "table" then
		if (depth or 0) >= 2 then
			return "{...}"
		end
		local parts = {}
		local count = 0
		for k, v in value do
			count += 1
			if count > 8 then
				table.insert(parts, "...")
				break
			end
			if type(k) == "number" then
				table.insert(parts, show(v, (depth or 0) + 1))
			else
				table.insert(parts, tostring(k) .. " = " .. show(v, (depth or 0) + 1))
			end
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "Color3" then
		return t .. "(" .. tostring(value) .. ")"
	end
	return tostring(value)
end
Test.show = show

local function deepEqual(a: any, b: any, seen: { [any]: any }?): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local s = seen or {}
	if s[a] == b then
		return true
	end
	s[a] = b
	for k, v in a do
		if not deepEqual(v, b[k], s) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
Test.deepEqual = deepEqual

local function components(value: any): { number }?
	local t = typeof(value)
	if t == "number" then
		return { value }
	elseif t == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif t == "Vector2" then
		return { value.X, value.Y }
	elseif t == "Color3" then
		return { value.R, value.G, value.B }
	elseif t == "CFrame" then
		return { value:GetComponents() }
	end
	return nil
end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- expect ----------------------------------------------------------------------------------------

-- Stack level (as seen from the caller of this function) of the first frame outside this file,
-- so a failed expectation points at the spec line.
local function specLevel(): number
	local level = 2
	while true do
		local source = debug.info(level + 1, "s")
		if source == nil then
			return 2
		end
		if not source:find("harness/Test", 1, true) then
			return level
		end
		level += 1
	end
end

local function matchers(value: any, negate: boolean)
	local m = {}
	local function check(pass: boolean, message: string)
		if negate then
			pass = not pass
			message = message:gsub("^expected ", "expected NOT ")
		end
		if not pass then
			error(message, specLevel())
		end
	end

	function m.toBe(expected: any)
		check(
			rawequal(value, expected) or value == expected,
			("expected %s to be %s"):format(show(value), show(expected))
		)
	end

	function m.toEqual(expected: any)
		check(
			deepEqual(value, expected),
			("expected %s to equal %s"):format(show(value), show(expected))
		)
	end

	function m.toBeNear(expected: any, epsilon: number?)
		local eps = epsilon or 1e-4
		local a, b = components(value), components(expected)
		local pass = a ~= nil and b ~= nil and #a == #b
		if pass then
			for i = 1, #(a :: any) do
				if math.abs((a :: any)[i] - (b :: any)[i]) > eps then
					pass = false
				end
			end
		end
		check(pass, ("expected %s to be within %g of %s"):format(show(value), eps, show(expected)))
	end

	function m.toBeTruthy()
		check(value ~= nil and value ~= false, ("expected %s to be truthy"):format(show(value)))
	end

	function m.toBeFalsy()
		check(value == nil or value == false, ("expected %s to be falsy"):format(show(value)))
	end

	function m.toBeNil()
		check(value == nil, ("expected %s to be nil"):format(show(value)))
	end

	local function compare(op: string, expected: number, pass: (number, number) -> boolean)
		check(
			type(value) == "number" and type(expected) == "number" and pass(value, expected),
			("expected %s to be %s %s"):format(show(value), op, show(expected))
		)
	end

	function m.toBeGreaterThan(n: number)
		compare(">", n, function(a, b)
			return a > b
		end)
	end

	function m.toBeGreaterThanOrEqual(n: number)
		compare(">=", n, function(a, b)
			return a >= b
		end)
	end

	function m.toBeLessThan(n: number)
		compare("<", n, function(a, b)
			return a < b
		end)
	end

	function m.toBeLessThanOrEqual(n: number)
		compare("<=", n, function(a, b)
			return a <= b
		end)
	end

	function m.toContain(item: any)
		local pass = false
		if type(value) == "string" then
			pass = value:find(item, 1, true) ~= nil
		elseif type(value) == "table" then
			for _, v in value do
				if v == item or deepEqual(v, item) then
					pass = true
					break
				end
			end
		end
		check(pass, ("expected %s to contain %s"):format(show(value), show(item)))
	end

	function m.toHaveLength(n: number)
		local len = if type(value) == "table" or type(value) == "string" then #value else nil
		check(
			len == n,
			("expected %s to have length %d, got %s"):format(show(value), n, tostring(len))
		)
	end

	function m.toBeA(typeName: string)
		check(
			typeof(value) == typeName,
			("expected %s to be a %s, got %s"):format(show(value), typeName, typeof(value))
		)
	end

	function m.toBeInstanceOf(className: string)
		local ok, isA = pcall(function()
			return value:IsA(className)
		end)
		check(
			ok and isA == true,
			("expected %s to be an instance of %s"):format(show(value), className)
		)
	end

	function m.toMatch(pattern: string)
		check(
			type(value) == "string" and value:match(pattern) ~= nil,
			("expected %s to match %q"):format(show(value), pattern)
		)
	end

	function m.toThrow(substring: string?)
		if type(value) ~= "function" then
			error("toThrow expects a function", 2)
		end
		local ok, err = pcall(value)
		local pass = not ok and (substring == nil or tostring(err):find(substring, 1, true) ~= nil)
		check(
			pass,
			if ok
				then "expected function to throw"
				else ("expected error %s to contain %s"):format(
					show(tostring(err)),
					show(substring)
				)
		)
	end

	function m.toBeFinite()
		local c = components(value)
		local pass = c ~= nil
		for _, n in c or {} do
			if not isFinite(n) then
				pass = false
			end
		end
		check(pass, ("expected %s to be finite"):format(show(value)))
	end

	if not negate then
		m.never = matchers(value, true)
	end
	return m
end

function Test.expect(value: any)
	return matchers(value, false)
end

return Test
