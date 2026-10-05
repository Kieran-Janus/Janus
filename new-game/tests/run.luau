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

	Mostly pure logic can be tested here (Config, Items, Lobby maths...): there are no players,
	remotes, physics or rendering. game:GetService works for ReplicatedStorage (with Shared),
	ServerScriptService (with Server), StarterPlayer, RunService and Players (no players);
	anything else errors with a clear message. There is also a small world made of real
	(Lune) instances, enough to BUILD things like the hub: Workspace (the global `workspace`,
	with a Terrain whose Fill* calls do nothing), Lighting, SoundService, ServerStorage and a
	CollectionService that works on instance tags. Model:GetPivot/PivotTo/ScaleTo/GetScale/
	GetBoundingBox are simple stand-ins. Read part positions as part.CFrame.Position in code
	you want to test (Lune can't read part.Position), and never touch an instance after it
	was destroyed (Lune errors where Roblox returns nil).
	  t.workspace                 this spec's Workspace
	  t.setCustom(folder)         use `folder` (a Folder instance) as ReplicatedStorage.Custom
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

-- Roblox's Random (Lune has none): a small seeded generator with the same methods. The same
-- seed always gives the same numbers, but not the numbers Roblox would give.
local Random = {}
Random.__index = Random
function Random.new(seed: number?): any
	local state = math.floor(seed or os.clock() * 1e6) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ State = state }, Random)
end
function Random.NextNumber(self: any, min: number?, max: number?): number
	self.State = (self.State * 16807) % 2147483647
	local low, high = min or 0, max or 1
	return low + (high - low) * ((self.State - 1) / 2147483646)
end
function Random.NextInteger(self: any, min: number, max: number): number
	return math.min(math.floor(Random.NextNumber(self, min, max + 1)), max)
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

-- Engine methods Lune doesn't have (simple stand-ins, enough to build the hub) ---------------

for _, method in { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "Clear" } do
	roblox.implementMethod("Terrain", method, function() end)
end

-- World-space box around every BasePart in `root`: (centre, size), or nil without parts.
local function partsBox(root: any): (any, any)
	local low, high = nil, nil
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = d.CFrame * roblox.Vector3.new(half.X * x, half.Y * y, half.Z * z)
						low = if low then low:Min(p) else p
						high = if high then high:Max(p) else p
					end
				end
			end
		end
	end
	if not low then
		return nil, nil
	end
	return (low + high) / 2, high - low
end

local function pivotOf(model: any): any
	local primary = model.PrimaryPart
	if primary then
		return primary.CFrame * primary.PivotOffset
	end
	local ok, pivot = pcall(function()
		return model.WorldPivot
	end)
	if ok then
		return pivot
	end
	local centre = partsBox(model)
	return if centre then roblox.CFrame.new(centre) else roblox.CFrame.new()
end

roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(self: any, target: any)
	local delta = target * pivotOf(self):Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	if not self.PrimaryPart then
		self.WorldPivot = target
	end
end)
roblox.implementMethod("Model", "GetScale", function(self: any): number
	return self:GetAttribute("TestScale") or 1
end)
roblox.implementMethod("Model", "ScaleTo", function(self: any, scale: number)
	local factor = scale / (self:GetAttribute("TestScale") or 1)
	local pivot = pivotOf(self)
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size = d.Size * factor
			d.CFrame = pivot * roblox.CFrame.new(rel.Position * factor) * rel.Rotation
		end
	end
	self:SetAttribute("TestScale", scale)
end)
roblox.implementMethod("Model", "GetBoundingBox", function(self: any): (any, any)
	local centre, size = partsBox(self)
	if not centre then
		return pivotOf(self), roblox.Vector3.new()
	end
	return roblox.CFrame.new(centre), size
end)

-- Fake services -----------------------------------------------------------------------------

-- CollectionService on top of Lune's instance tags. Its signals never fire.
local function collectionService(world: any): any
	local service = {}
	function service.AddTag(_self: any, instance: any, tag: string)
		instance:AddTag(tag)
	end
	function service.RemoveTag(_self: any, instance: any, tag: string)
		instance:RemoveTag(tag)
	end
	function service.HasTag(_self: any, instance: any, tag: string): boolean
		return instance:HasTag(tag)
	end
	function service.GetTags(_self: any, instance: any): { string }
		return instance:GetTags()
	end
	function service.GetTagged(_self: any, tag: string): { any }
		local list = {}
		for _, d in world:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(list, d)
			end
		end
		return list
	end
	local function signal(): any
		return {
			Connect = function()
				return { Disconnect = function() end }
			end,
		}
	end
	service.GetInstanceAddedSignal = signal
	service.GetInstanceRemovedSignal = signal
	return service
end

-- `extras`: real instances to show as children too (ReplicatedStorage.Custom in tests).
local function folderService(
	name: string,
	children: { [string]: string },
	extras: { [string]: any }?
): any
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
		if dir then
			return makeNode(childName, "Folder", nil, dir, service)
		end
		return if extras then extras[childName] else nil
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

local function newGame(extras: { [string]: any }): (any, any)
	local world = roblox.Instance.new("DataModel")
	local workspaceService = world:GetService("Workspace")
	roblox.Instance.new("Terrain").Parent = workspaceService
	local services: { [string]: any } = {
		ReplicatedStorage = folderService(
			"ReplicatedStorage",
			{ Shared = ROOT .. "/src/shared" },
			extras
		),
		Workspace = workspaceService,
		Lighting = world:GetService("Lighting"),
		SoundService = world:GetService("SoundService"),
		ServerStorage = world:GetService("ServerStorage"),
		CollectionService = collectionService(world),
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
			IsRunning = function()
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
	return game, workspaceService
end

-- Module loading ------------------------------------------------------------------------------

type Session = {
	Game: any,
	Workspace: any,
	Extras: { [string]: any }, -- extra ReplicatedStorage children (t.setCustom)
	Cache: { [string]: any },
	Loading: { [string]: boolean },
}

local loadFile: (session: Session, path: string, scriptNode: any) -> any

local function makeEnv(session: Session, scriptNode: any): { [string]: any }
	local env: { [string]: any } = {
		script = scriptNode,
		game = session.Game,
		workspace = session.Workspace,
		task = task,
		CFrame = CFrame,
		Random = Random,
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

local function makeT(specName: string, session: Session): any
	local t = {}
	t.workspace = session.Workspace
	-- Makes `folder` (a Folder instance) appear as ReplicatedStorage.Custom.
	function t.setCustom(folder: any)
		session.Extras.Custom = folder
	end
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
	local extras = {}
	local game, workspaceService = newGame(extras)
	local session: Session = {
		Game = game,
		Workspace = workspaceService,
		Extras = extras,
		Cache = {},
		Loading = {},
	}
	table.clear(proxies) -- fresh module tree per spec
	local ok, err = pcall(function()
		local specFn = loadFile(
			session,
			ROOT .. "/" .. SPECS .. "/" .. file,
			makeNode(specName, "ModuleScript", nil, nil, nil)
		)
		assert(type(specFn) == "function", file .. " must return a function(t)")
		specFn(makeT(specName, session))
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
