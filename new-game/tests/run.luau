--!strict
--[[
	Smoke tests that run WITHOUT Roblox Studio, using Lune (https://lune-org.github.io).
	From the new-game folder:   lune run tests/run            (all specs)
	                            lune run tests/run Items      (only specs whose name has "Items")

	Every file in tests/specs/ named <Name>.spec.luau is a spec. It runs like game code
	(script, require, game:GetService("ReplicatedStorage").Shared..., Vector3, CFrame, Enum
	and task all work) and returns a function that receives `t`:
	  t.test(name, fn)            one test; an error inside fn fails it
	  t.ok(value, message?)       fails unless value is truthy
	  t.eq(actual, expected, message?)
	  t.near(actual, expected, epsilon?, message?)   numbers or Vector3s
	  t.errors(fn, message?)      fails unless fn errors
	  t.Server, t.Client          src/server and src/client, e.g. require(t.Client.MenuUI)
	  t.readFile(path)            source of a file, path relative to new-game (or nil)
	Each spec gets fresh copies of every module, so specs can't affect each other.

	Only pure logic can be tested here (Config, Items, Lobby maths...): there are no real
	parts, players, remotes or physics. game:GetService works for ReplicatedStorage (with
	Shared), ServerScriptService (with Server), StarterPlayer, RunService and Players (no
	players); anything else errors with a clear message.
	Note: Lune's own CFrame.lookAt has the Z direction flipped, so the one given to game code
	here is a corrected copy.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any
local task = require("@lune/task")

local ROOT = "." -- run from the new-game folder
local SPECS = "tests/specs"

-- Roblox datatypes ------------------------------------------------------------------------

local CFrame = setmetatable({}, { __index = roblox.CFrame }) :: any
function CFrame.lookAt(position: any, target: any, up: any?): any
	local look = (target - position).Unit
	local right = look:Cross(up or roblox.Vector3.new(0, 1, 0)).Unit
	local trueUp = right:Cross(look)
	return roblox.CFrame.fromMatrix(position, right, trueUp, -look)
end

local DATATYPES = {
	"Axes",
	"BrickColor",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"Region3int16",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}

-- Fake instance tree for src/ -------------------------------------------------------------

type Node = {
	Name: string,
	ClassName: string,
	Source: string?, -- file path of a ModuleScript's code
	Dir: string?, -- folder whose files are this node's children
	Parent: any,
}

local nodeMeta: { [any]: any } = {}
local proxies: { [string]: any } = {} -- one proxy per path, so == works like Instances

-- The file tree is read once up front: Lune's fs calls can yield, and the instance lookups
-- below run inside metamethods, which must not yield.
local files: { [string]: string } = {} -- path -> source
local dirs: { [string]: { string } } = {} -- path -> entry names

local function scan(dir: string)
	local entries = fs.readDir(dir)
	table.sort(entries)
	dirs[dir] = entries
	for _, entry in entries do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			scan(path)
		elseif entry:match("%.luau$") then
			files[path] = fs.readFile(path)
		end
	end
end
scan(ROOT .. "/src")
scan(ROOT .. "/tests")

local function isFile(path: string): boolean
	return files[path] ~= nil
end

local function isDir(path: string): boolean
	return dirs[path] ~= nil
end

local makeNode: (name: string, class: string, source: string?, dir: string?, parent: any) -> any

-- The child called `name` inside folder `dir`, following Rojo's rules.
local function childOf(dir: string, name: string, parent: any): any
	local file = dir .. "/" .. name .. ".luau"
	if isFile(file) then
		return makeNode(name, "ModuleScript", file, nil, parent)
	end
	for _, suffix in { ".server.luau", ".client.luau" } do
		if isFile(dir .. "/" .. name .. suffix) then
			return makeNode(name, "Script", dir .. "/" .. name .. suffix, nil, parent)
		end
	end
	local sub = dir .. "/" .. name
	if isDir(sub) then
		if isFile(sub .. "/init.luau") then
			return makeNode(name, "ModuleScript", sub .. "/init.luau", sub, parent)
		end
		return makeNode(name, "Folder", nil, sub, parent)
	end
	return nil
end

local function childNames(dir: string): { string }
	local names = {}
	local seen = {}
	for _, entry in dirs[dir] or {} do
		local name = entry
		if isFile(dir .. "/" .. entry) then
			if entry == "init.luau" or not entry:match("%.luau$") then
				continue
			end
			name = entry:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", "")
		end
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local methods = {}

function methods.FindFirstChild(self: any, name: string): any
	local node = nodeMeta[self]
	if node.Dir == nil then
		return nil
	end
	return childOf(node.Dir, name, self)
end

function methods.WaitForChild(self: any, name: string): any
	local child = methods.FindFirstChild(self, name)
	if child == nil then
		error(
			("WaitForChild would wait forever: %s has no child %s"):format(
				nodeMeta[self].Name,
				name
			)
		)
	end
	return child
end

function methods.GetChildren(self: any): { any }
	local node = nodeMeta[self]
	local list = {}
	if node.Dir then
		for _, name in childNames(node.Dir) do
			table.insert(list, childOf(node.Dir, name, self))
		end
	end
	return list
end

function methods.IsA(self: any, class: string): boolean
	local own = nodeMeta[self].ClassName
	return own == class
		or class == "Instance"
		or (class == "LuaSourceContainer" and (own == "ModuleScript" or own == "Script"))
end

function methods.GetFullName(self: any): string
	local node = nodeMeta[self]
	return (node.Source or node.Dir or node.Name) :: string
end

makeNode = function(name: string, class: string, source: string?, dir: string?, parent: any): any
	local key = (source or dir or name) :: string
	local existing = proxies[key]
	if existing then
		return existing
	end
	local proxy = newproxy(true)
	local node: Node =
		{ Name = name, ClassName = class, Source = source, Dir = dir, Parent = parent }
	nodeMeta[proxy] = node
	local meta = getmetatable(proxy)
	meta.__index = function(self: any, key2: string): any
		if key2 == "Name" or key2 == "ClassName" or key2 == "Parent" then
			return (node :: any)[key2]
		end
		if methods[key2] then
			return methods[key2]
		end
		local child = methods.FindFirstChild(self, key2)
		if child == nil then
			error(("%s is not a valid member of %s"):format(key2, node.Name), 2)
		end
		return child
	end
	meta.__tostring = function(): string
		return name
	end
	proxies[key] = proxy
	return proxy
end

-- Fake services -----------------------------------------------------------------------------

local function folderService(name: string, children: { [string]: string }): any
	local attributes: { [string]: any } = {}
	local service = {}
	function service.GetAttribute(_self: any, key: string): any
		return attributes[key]
	end
	function service.SetAttribute(_self: any, key: string, value: any)
		attributes[key] = value
	end
	function service.FindFirstChild(_self: any, childName: string): any
		local dir = children[childName]
		return if dir then makeNode(childName, "Folder", nil, dir, service) else nil
	end
	function service.WaitForChild(self: any, childName: string): any
		local child = service.FindFirstChild(self, childName)
		if not child then
			error(("WaitForChild would wait forever: %s has no child %s"):format(name, childName))
		end
		return child
	end
	return setmetatable(service, {
		__index = function(self: any, key: string): any
			local child = service.FindFirstChild(self, key)
			if child == nil then
				error(
					("%s is not a valid member of %s (not available in tests)"):format(key, name),
					2
				)
			end
			return child
		end,
	})
end

local function newGame(): any
	local services: { [string]: any } = {
		ReplicatedStorage = folderService("ReplicatedStorage", { Shared = ROOT .. "/src/shared" }),
		ServerScriptService = folderService(
			"ServerScriptService",
			{ Server = ROOT .. "/src/server" }
		),
		StarterPlayer = folderService("StarterPlayer", {}),
		-- No players in tests: enough for modules that only list players or wait for them.
		Players = {
			LocalPlayer = nil,
			GetPlayers = function()
				return {}
			end,
		},
		RunService = {
			IsServer = function()
				return true
			end,
			IsClient = function()
				return false
			end,
			IsStudio = function()
				return true
			end,
		},
	}
	local game = {}
	function game.GetService(_self: any, name: string): any
		local service = services[name]
		if service == nil then
			error(("game:GetService(%q) is not available in tests"):format(name), 2)
		end
		return service
	end
	return game
end

-- Module loading ------------------------------------------------------------------------------

type Session = { Game: any, Cache: { [string]: any }, Loading: { [string]: boolean } }

local loadFile: (session: Session, path: string, scriptNode: any) -> any

local function makeEnv(session: Session, scriptNode: any): { [string]: any }
	local env: { [string]: any } = {
		script = scriptNode,
		game = session.Game,
		task = task,
		CFrame = CFrame,
		Instance = roblox.Instance,
		require = function(target: any): any
			local node = nodeMeta[target]
			if node == nil or node.ClassName ~= "ModuleScript" then
				error("require() in game code needs a ModuleScript, got " .. tostring(target), 2)
			end
			local path = node.Source :: string
			if session.Cache[path] ~= nil then
				return session.Cache[path]
			end
			if session.Loading[path] then
				error("circular require: " .. path, 2)
			end
			session.Loading[path] = true
			local result = loadFile(session, path, target)
			session.Loading[path] = nil
			session.Cache[path] = result
			return result
		end,
	}
	for _, name in DATATYPES do
		env[name] = roblox[name]
	end
	return env
end

loadFile = function(session: Session, path: string, scriptNode: any): any
	local source = files[path]
	if source == nil then
		error("no such file: " .. path)
	end
	local chunk = luau.load(source, {
		debugName = path,
		environment = makeEnv(session, scriptNode),
	})
	return chunk()
end

-- Test API ------------------------------------------------------------------------------------

local passed, failed = 0, 0
local failures: { string } = {}

local function describe(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function makeT(specName: string): any
	local t = {}
	-- The script folders, for requiring server or client modules directly:
	-- require(t.Server.Services.ReadyService), require(t.Client.MenuUI).
	t.Server = makeNode("Server", "Folder", nil, ROOT .. "/src/server", nil)
	t.Client = makeNode("Client", "Folder", nil, ROOT .. "/src/client", nil)
	-- Source text of a file under src/ or tests/ (path relative to new-game), or nil.
	function t.readFile(path: string): string?
		return files[ROOT .. "/" .. path]
	end
	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			passed += 1
			print(("  ok    %s"):format(name))
		else
			failed += 1
			local line = ("%s > %s: %s"):format(specName, name, tostring(err))
			table.insert(failures, line)
			print(("  FAIL  %s\n        %s"):format(name, tostring(err)))
		end
	end
	function t.ok(value: any, message: string?)
		if not value then
			error(message or "expected a truthy value", 2)
		end
	end
	function t.eq(actual: any, expected: any, message: string?)
		if actual ~= expected then
			error(
				("%sexpected %s, got %s"):format(
					if message then message .. ": " else "",
					describe(expected),
					describe(actual)
				),
				2
			)
		end
	end
	function t.near(actual: any, expected: any, epsilon: number?, message: string?)
		local eps = epsilon or 1e-4
		local diff = if type(actual) == "number"
			then math.abs(actual - expected)
			else (actual - expected).Magnitude
		if diff > eps then
			error(
				("%sexpected about %s, got %s"):format(
					if message then message .. ": " else "",
					tostring(expected),
					tostring(actual)
				),
				2
			)
		end
	end
	function t.errors(fn: () -> (), message: string?)
		if pcall(fn) then
			error(message or "expected an error", 2)
		end
	end
	return t
end

-- Run -------------------------------------------------------------------------------------------

local filter = process.args[1]
local specFiles = {}
for _, entry in dirs[ROOT .. "/" .. SPECS] or {} do
	if entry:match("%.spec%.luau$") and (filter == nil or entry:find(filter, 1, true)) then
		table.insert(specFiles, entry)
	end
end
table.sort(specFiles)

for _, file in specFiles do
	local specName = file:gsub("%.spec%.luau$", "")
	print(specName)
	local session: Session = { Game = newGame(), Cache = {}, Loading = {} }
	table.clear(proxies) -- fresh module tree per spec
	local ok, err = pcall(function()
		local specFn = loadFile(
			session,
			ROOT .. "/" .. SPECS .. "/" .. file,
			makeNode(specName, "ModuleScript", nil, nil, nil)
		)
		assert(type(specFn) == "function", file .. " must return a function(t)")
		specFn(makeT(specName))
	end)
	if not ok then
		failed += 1
		table.insert(failures, ("%s (loading): %s"):format(specName, tostring(err)))
		print("  FAIL  could not run: " .. tostring(err))
	end
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	for _, line in failures do
		print("FAILED " .. line)
	end
	process.exit(1)
end
