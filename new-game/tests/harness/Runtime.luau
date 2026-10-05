--[[
	Runtime: one fake Roblox game, built from the Rojo project, that runs the real game code.

	  local Runtime = require("../harness/Runtime")
	  local rt = Runtime.new()                         -- loads default.project.json
	  local Config = rt:require("ReplicatedStorage.Shared.Config")
	  local hub = rt:require("ServerScriptService.Server.Hub.HubBuilder").Build()
	  rt:advance(5)                                    -- run 5 virtual seconds of tasks

	Options (all optional):
	  root        project folder (default: the current directory, or ./new-game)
	  project     project file (default "default.project.json")
	  place       load this .rbxl/.rbxlx (e.g. `rojo build` output) instead of the project
	  client      run as a client: RunService:IsClient(), Players.LocalPlayer exists
	  studio      RunService:IsStudio() (default false)
	  seed        math.random seed (default 1)
	  time        os.time() when the runtime starts (default 1767225600 = 2026-01-01)
	  echo        "all" | "warn" | "none": which game output is printed (default "warn")
	  dataStores  false: GetDataStore errors like an unpublished place
	  baseplate   true: add the Baseplate + SpawnLocation of Studio's Baseplate template
	  input       { TouchEnabled = true, ... } for UserInputService

	Fields: rt.game, rt.workspace, rt.env (the shared globals), rt.logs, rt.warnings,
	rt.errors (errors thrown inside task threads), rt.scheduler, plus the state tables
	listed at the top of Services.luau.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Dom = require("./Dom")
require("./Engine")
local Services = require("./Services")
local Globals = require("./Globals")
local Project = require("./Project")
local Scheduler = require("./Scheduler")
local Signal = require("./Signal")
local Types = require("./Types")

local CFrame, Vector3, Color3, Enum = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum
local typeof = Types.typeof

local Runtime = {}
Runtime.__index = Runtime

-- Defaults every new runtime starts from (the test runner sets echo from --verbose / --quiet).
Runtime.defaults = {
	echo = "warn",
	seed = 1,
	time = 1767225600,
}

-- Errors raised inside task threads of any runtime, not yet collected by the test runner.
Runtime.uncaught = {} :: { string }

-- Services that exist from the start (like a new place in Studio).
local STARTING_SERVICES = {
	"Workspace",
	"Players",
	"Lighting",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"Chat",
	"TextChatService",
	"RunService",
}

local function findRoot(options): string
	if options.root then
		return options.root
	end
	local cwd = process.cwd:gsub("[/\\]$", "")
	local project = options.project or "default.project.json"
	if fs.isFile(cwd .. "/" .. project) then
		return cwd
	elseif fs.isFile(cwd .. "/new-game/" .. project) then
		return cwd .. "/new-game"
	end
	return cwd
end

function Runtime.new(options: { [string]: any }?)
	local opts = table.clone(Runtime.defaults)
	for k, v in options or {} do
		opts[k] = v
	end
	local self = setmetatable({}, Runtime)
	self.options = opts
	self.root = findRoot(opts)
	-- World state used by Dom / Signal / Services.
	self.listening = {}
	self.connectionCount = 0
	self.instanceCount = 0
	self.callLog = {}
	self.logs = {}
	self.warnings = {}
	self.errors = {}
	self.modules = {}
	self.tagSignals = {}
	self.dataStores = {}
	self.dataStoreFailures = 0
	self.secrets = {}
	self.gamePasses = {}
	self.groupRanks = {}
	self.friends = {}
	self.actions = {}
	self.renderSteps = {}
	self.closeCallbacks = {}
	self.collisionGroups =
		{ registered = { Default = true }, order = { "Default" }, collidable = {} }
	self.httpHandler = nil
	self.filterText = nil
	self.nextUserId = 1
	self.epoch = opts.time
	self.requireDepth = 0
	math.randomseed(opts.seed)

	self.scheduler = Scheduler.new(function(message, traceback)
		self:_taskError(message, traceback)
	end)
	self.scheduler.frameHook = function(dt)
		Services.frame(self, dt)
	end
	self.scheduler.frameActive = function()
		return Services.frameActive(self)
	end

	self.game = Dom.new(self, "DataModel", true)
	self.gameData = Dom.data(self.game)
	self.game.Name = opts.placeName or "Game"
	for _, name in STARTING_SERVICES do
		self:getService(name)
	end
	self.workspace = self:getService("Workspace")
	local terrain = Dom.new(self, "Terrain", true)
	terrain.Name = "Terrain"
	Dom.setParent(terrain, self.workspace)
	local camera = Dom.new(self, "Camera", true)
	camera.Name = "Camera"
	Dom.set(camera, "CFrame", CFrame.new(0, 20, 20) * CFrame.Angles(-math.rad(30), 0, 0))
	Dom.setParent(camera, self.workspace)
	Dom.set(self.workspace, "CurrentCamera", camera)
	local starterPlayer = self:getService("StarterPlayer")
	for _, name in { "StarterPlayerScripts", "StarterCharacterScripts" } do
		local folder = Dom.new(self, name, true)
		folder.Name = name
		Dom.setParent(folder, starterPlayer)
	end
	if opts.baseplate then
		self:_addBaseplate()
	end

	self.env = Globals.build(self)

	if opts.place then
		Project.loadPlace(self, opts.place)
	else
		Project.load(self, self.root, opts.project or "default.project.json")
	end

	if opts.client then
		self.localPlayer = self:addPlayer({ Name = "LocalPlayer", character = opts.character })
	end
	return self
end

function Runtime:_addBaseplate()
	local plate = Dom.new(self, "Part", true)
	plate.Name = "Baseplate"
	Dom.set(plate, "Size", Vector3.new(2048, 16, 2048))
	Dom.set(plate, "CFrame", CFrame.new(0, -8, 0))
	Dom.set(plate, "Anchored", true)
	Dom.set(plate, "Color", Color3.fromRGB(91, 91, 91))
	Dom.setParent(plate, self.workspace)
	local spawn = Dom.new(self, "SpawnLocation", true)
	spawn.Name = "SpawnLocation"
	Dom.set(spawn, "Size", Vector3.new(12, 1, 12))
	Dom.set(spawn, "CFrame", CFrame.new(0, 0.5, 0))
	Dom.set(spawn, "Anchored", true)
	Dom.setParent(spawn, self.workspace)
end

-- World hooks (called by Dom / Services) ----------------------------------------------------------

function Runtime:log(level: string, text: string)
	table.insert(self.logs, { level = level, text = text })
	if level == "warn" then
		table.insert(self.warnings, text)
	end
	local echo = self.options.echo
	if echo == "all" or (echo == "warn" and level ~= "print") then
		print(("    [game %s] %s"):format(level, text))
	end
end

function Runtime:_taskError(message: string, traceback: string)
	-- Lune may already have folded a traceback into the message; keep one copy.
	local text = message:gsub("^runtime error: ", "")
	local first = text:match("^[^\n]*") or text
	local full = if text:find("stack traceback", 1, true) then text else traceback
	table.insert(self.errors, full)
	table.insert(Runtime.uncaught, full)
	self:log("error", first)
end

function Runtime:recordCall(className: string, method: string, instance: any, ...)
	local key = className .. ":" .. method
	local list = self.callLog[key]
	if not list then
		list = {}
		self.callLog[key] = list
	end
	self.callSeq = (self.callSeq or 0) + 1
	if #list < 10000 then
		table.insert(
			list,
			{ instance = instance, method = method, args = table.pack(...), seq = self.callSeq }
		)
	end
end

function Runtime:tagSignal(tag: string, added: boolean)
	local pair = self.tagSignals[tag]
	if not pair then
		pair = {}
		self.tagSignals[tag] = pair
	end
	local key = if added then "added" else "removed"
	if not pair[key] then
		pair[key] = Signal.new(if added then "InstanceAdded" else "InstanceRemoved", self)
	end
	return pair[key]
end

-- Unknown services get a permissive stand-in so modules still load (and the use is logged).
local function permissive(rt, name: string)
	local meta = { __type = "Instance" }
	local obj = setmetatable({}, meta)
	meta.__index = function(_, key)
		return function(...)
			rt:recordCall(name, tostring(key), obj, ...)
			return nil
		end
	end
	meta.__newindex = function() end
	meta.__tostring = function()
		return name
	end
	return obj
end

function Runtime:getService(name: string): any
	for _, child in self.gameData.children do
		if child.ClassName == name then
			return child.u
		end
	end
	local class = Dom.getClass(name)
	if class and (class.Tags.Service or name:match("Service$")) then
		local service = Dom.new(self, name, true)
		service.Name = name
		Dom.setParent(service, self.game)
		return service
	end
	self.unknownServices = self.unknownServices or {}
	if not self.unknownServices[name] then
		self:log(
			"warn",
			("[harness] GetService(%q): unknown service, using a permissive fake"):format(
				tostring(name)
			)
		)
		self.unknownServices[name] = permissive(self, tostring(name))
	end
	return self.unknownServices[name]
end

function Runtime:settings(): any
	if not self._settings then
		self._settings = Dom.new(self, "GlobalSettings", true)
	end
	return self._settings
end

function Runtime:userSettings(): any
	if not self._userSettings then
		self._userSettings = Dom.new(self, "UserSettings", true)
	end
	return self._userSettings
end

function Runtime:relativePath(path: string): string
	local root = self.root:gsub("\\", "/")
	path = path:gsub("\\", "/")
	if path:sub(1, #root + 1) == root .. "/" then
		return path:sub(#root + 2)
	end
	return path
end

-- Finding and running code ------------------------------------------------------------------------

--[[
	Finds an instance by dotted path from the DataModel:
	  rt:find("ReplicatedStorage.Shared.Config")   rt:find("Workspace.Hub.Spawn")
	Errors when any part is missing.
]]
function Runtime:find(path: string): any
	local current = self.game
	for segment in path:gmatch("[^%.]+") do
		if current == self.game then
			if segment ~= "game" then
				local found = current:FindFirstChild(segment)
				if not found then
					local class = Dom.getClass(segment)
					if not (class and class.Tags.Service) then
						error(
							("Runtime:find(%q): the game has no service or child %q"):format(
								path,
								segment
							),
							2
						)
					end
					found = self:getService(segment)
				end
				current = found
			end
		else
			local found = current:FindFirstChild(segment)
			if not found then
				error(
					("Runtime:find(%q): %s has no child %q"):format(
						path,
						current:GetFullName(),
						segment
					),
					2
				)
			end
			current = found
		end
	end
	return current
end

function Runtime:_scriptEnv(script: any): { [string]: any }
	return setmetatable({ script = script }, { __index = self.env })
end

local function chunkName(d: any): string
	return "@" .. (d.sourcePath or Dom.fullNameOf(d))
end

local function loadScript(self, script: any): (...any) -> ...any
	local d = Dom.data(script)
	if not d or d.source == nil then
		error(("%s has no source"):format(tostring(script)), 3)
	end
	local ok, fn = pcall(luau.load, d.source, {
		debugName = chunkName(d),
		environment = self:_scriptEnv(script),
		injectGlobals = false,
	})
	if not ok then
		error(tostring(fn), 0)
	end
	return fn
end

-- The `require` scripts see: ModuleScripts run once per runtime and are cached.
function Runtime:_require(target: any): any
	if not Dom.isA(target, "ModuleScript") then
		if type(target) == "number" then
			error("require(assetId) is not supported in the test harness", 2)
		end
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local entry = self.modules[target]
	if entry then
		if entry.state == "loading" then
			error(("Requested module was required recursively: %s"):format(Dom.fullName(target)), 2)
		elseif entry.state == "failed" then
			error(
				("Requested module experienced an error while loading: %s\n%s"):format(
					Dom.fullName(target),
					entry.error
				),
				2
			)
		end
		return entry.value
	end
	entry = { state = "loading" }
	self.modules[target] = entry
	local fn = loadScript(self, target)
	local traceback
	local results = table.pack(xpcall(fn, function(err)
		-- An error from a nested require already carries the innermost traceback.
		local text = tostring(err)
		traceback = if text:find("stack traceback", 1, true) then text else debug.traceback(text, 2)
		return err
	end))
	if not results[1] then
		entry.state = "failed"
		entry.error = tostring(results[2])
		error(traceback or tostring(results[2]), 0)
	end
	if results.n ~= 2 then
		entry.state = "failed"
		entry.error = "Module code did not return exactly one value"
		error(("Module code did not return exactly one value: %s"):format(Dom.fullName(target)), 2)
	end
	entry.state = "done"
	entry.value = results[2]
	return entry.value
end

--[[
	Requires a ModuleScript (an instance or a path for Runtime:find) the way a script would,
	then runs anything it deferred.
]]
function Runtime:require(target: any): any
	if type(target) == "string" then
		target = self:find(target)
	end
	self.requireDepth += 1
	local ok, result = pcall(self._require, self, target)
	self.requireDepth -= 1
	if not ok then
		error(result, 0)
	end
	if self.requireDepth == 0 then
		self.scheduler:flush()
	end
	return result
end

--[[
	Runs a Script / LocalScript as a task thread (it may yield and keep running as time
	advances). Returns false and the error if it failed before its first yield.
]]
function Runtime:runScript(target: any): (boolean, string?)
	if type(target) == "string" then
		target = self:find(target)
	end
	local fn = loadScript(self, target)
	local before = #self.errors
	self.scheduler:spawn(fn)
	self.scheduler:flush()
	if #self.errors > before then
		return false, self.errors[#self.errors]
	end
	return true
end

--[[
	Copies what a server replicates to its clients from another runtime: the children of
	ReplicatedStorage, ReplicatedFirst, Workspace and Lighting that this runtime doesn't have
	yet. Typical use: boot a server runtime, then client:replicateFrom(server) so client
	modules find the remotes they WaitForChild on.
]]
function Runtime:replicateFrom(server: any, serviceNames: { string }?)
	for _, name in
		serviceNames or { "ReplicatedStorage", "ReplicatedFirst", "Workspace", "Lighting" }
	do
		local from, to = server:getService(name), self:getService(name)
		for _, child in from:GetChildren() do
			local className = child.ClassName
			if className == "Terrain" or className == "Camera" then
				continue
			end
			local existing = to:FindFirstChild(child.Name)
			if not (existing and existing.ClassName == className) then
				local copy = Dom.cloneInto(child, self)
				if copy then
					Dom.setParent(copy, to)
				end
			end
		end
	end
	self.scheduler:flush()
end

-- Runs every enabled Script under ServerScriptService (what a server does on start).
function Runtime:startServer(): { string }
	local failures = {}
	for _, script in self:getService("ServerScriptService"):GetDescendants() do
		if script.ClassName == "Script" and not Dom.get(script, "Disabled") then
			local ok, err = self:runScript(script)
			if not ok then
				table.insert(failures, err :: string)
			end
		end
	end
	return failures
end

--[[
	Runs `fn(...)` as a task thread and advances virtual time until it finishes (up to
	`maxSeconds`, default 60). Returns its results; rethrows its error. Use it to call game
	code that yields (DataStore retries, :WaitForChild, task.wait loops) from a test.
]]
function Runtime:call(fn: (...any) -> ...any, ...): ...any
	local results = nil
	local failure = nil
	local args = table.pack(...)
	self.scheduler:spawn(function()
		local packed = table.pack(xpcall(fn, function(err)
			return debug.traceback(tostring(err), 2)
		end, table.unpack(args, 1, args.n)))
		if packed[1] then
			results = packed
		else
			failure = packed[2]
		end
	end)
	local waited = 0
	local limit = (self.options.callTimeout or 60)
	while results == nil and failure == nil and waited < limit do
		self.scheduler:advance(self.scheduler.frame)
		waited += self.scheduler.frame
	end
	if failure then
		error(failure, 0)
	end
	if results == nil then
		error(("Runtime:call: still running after %g virtual seconds"):format(limit), 2)
	end
	return table.unpack(results :: any, 2, (results :: any).n)
end

-- Time -------------------------------------------------------------------------------------------

-- Advances virtual time, running frames (RunService events) and due tasks.
function Runtime:advance(seconds: number)
	self.scheduler:advance(seconds)
end

-- Runs deferred tasks without moving time.
function Runtime:flush()
	self.scheduler:flush()
end

function Runtime:now(): number
	return self.scheduler.now
end

-- Players ----------------------------------------------------------------------------------------

local function rigPart(rt, model, name: string, size: Vector3, cf: CFrame, color: Color3)
	local p = Dom.new(rt, "Part", true)
	p.Name = name
	Dom.set(p, "Size", size)
	Dom.set(p, "CFrame", cf)
	Dom.set(p, "Color", color)
	Dom.setParent(p, model)
	return p
end

local function weld(rt, a, b)
	local w = Dom.new(rt, "Weld", true)
	w.Name = "Weld"
	Dom.set(w, "Part0", a)
	Dom.set(w, "Part1", b)
	Dom.set(w, "C0", (Dom.get(a, "CFrame") :: CFrame):ToObjectSpace(Dom.get(b, "CFrame")))
	Dom.setParent(w, a)
end

-- A simple R15-like character: HumanoidRootPart, Head (with face, hair accessory), torso,
-- limbs, Humanoid + Animator, BodyColors, Shirt and Pants.
function Runtime:buildCharacter(name: string, at: CFrame?): any
	local cf = at or CFrame.new(0, 3, 0)
	local model = Dom.new(self, "Model", true)
	model.Name = name
	local skin = Color3.fromRGB(255, 205, 160)
	local root = rigPart(self, model, "HumanoidRootPart", Vector3.new(2, 2, 1), cf, skin)
	Dom.set(root, "Transparency", 1)
	local upper =
		rigPart(self, model, "UpperTorso", Vector3.new(2, 1.6, 1), cf * CFrame.new(0, 0.2, 0), skin)
	local lower = rigPart(
		self,
		model,
		"LowerTorso",
		Vector3.new(2, 0.4, 1),
		cf * CFrame.new(0, -0.8, 0),
		skin
	)
	local head =
		rigPart(self, model, "Head", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 1.6, 0), skin)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local arm = rigPart(
			self,
			model,
			prefix .. "UpperArm",
			Vector3.new(1, 2, 1),
			cf * CFrame.new(side * 1.5, 0, 0),
			skin
		)
		local leg = rigPart(
			self,
			model,
			prefix .. "UpperLeg",
			Vector3.new(1, 2, 1),
			cf * CFrame.new(side * 0.5, -2, 0),
			skin
		)
		weld(self, upper, arm)
		weld(self, lower, leg)
	end
	weld(self, root, upper)
	weld(self, upper, lower)
	weld(self, upper, head)
	local face = Dom.new(self, "Decal", true)
	face.Name = "face"
	Dom.setParent(face, head)
	local hair = Dom.new(self, "Accessory", true)
	hair.Name = "Hair"
	local handle = rigPart(
		self,
		hair,
		"Handle",
		Vector3.new(1.3, 0.6, 1.3),
		cf * CFrame.new(0, 2.2, 0),
		Color3.fromRGB(60, 40, 20)
	)
	local accessoryWeld = Dom.new(self, "Weld", true)
	accessoryWeld.Name = "AccessoryWeld"
	Dom.set(accessoryWeld, "Part0", handle)
	Dom.set(accessoryWeld, "Part1", head)
	Dom.setParent(accessoryWeld, handle)
	Dom.setParent(hair, model)
	local humanoid = Dom.new(self, "Humanoid", true)
	Dom.set(humanoid, "RigType", Enum.HumanoidRigType.R15)
	Dom.setParent(humanoid, model)
	local animator = Dom.new(self, "Animator", true)
	Dom.setParent(animator, humanoid)
	for _, className in { "BodyColors", "Shirt", "Pants" } do
		local inst = Dom.new(self, className, true)
		Dom.setParent(inst, model)
	end
	Dom.set(model, "PrimaryPart", root)
	return model
end

--[[
	Adds a player (fires Players.PlayerAdded) and, unless character = false, spawns their
	character (fires CharacterAdded). opts: { Name, UserId, DisplayName, character }.
]]
function Runtime:addPlayer(opts: { [string]: any }?): any
	local o = opts or {}
	local userId = o.UserId or self.nextUserId
	self.nextUserId = math.max(self.nextUserId, userId) + 1
	local player = Dom.new(self, "Player", true)
	player.Name = o.Name or ("Player" .. userId)
	Dom.set(player, "UserId", userId)
	if o.DisplayName then
		Dom.set(player, "DisplayName", o.DisplayName)
	end
	for _, className in { "Backpack", "PlayerGui", "PlayerScripts" } do
		local child = Dom.new(self, className, true)
		child.Name = className
		Dom.setParent(child, player)
	end
	local players = self:getService("Players")
	Dom.setParent(player, players)
	Dom.emit(players, "PlayerAdded", player)
	self.scheduler:flush()
	if o.character ~= false then
		self:spawnCharacter(player)
	end
	return player
end

-- Fires PlayerRemoving, removes the character and the player.
function Runtime:removePlayer(player: any)
	local players = self:getService("Players")
	Dom.emit(players, "PlayerRemoving", player)
	local character = Dom.get(player, "Character")
	if character then
		Dom.emit(player, "CharacterRemoving", character)
		Dom.destroy(character)
	end
	Dom.setParent(player, nil)
	self.scheduler:flush()
end

-- (Re)spawns a player's character on the first SpawnLocation (fires CharacterAdded).
function Runtime:spawnCharacter(player: any, at: CFrame?): any
	local old = Dom.get(player, "Character")
	if old then
		Dom.emit(player, "CharacterRemoving", old)
		Dom.destroy(old)
	end
	local cf = at
	if not cf then
		for _, d in self.workspace:GetDescendants() do
			if d.ClassName == "SpawnLocation" and Dom.get(d, "Enabled") ~= false then
				cf = CFrame.new((d :: any).Position + Vector3.new(0, 3.5, 0))
				break
			end
		end
	end
	local character = self:buildCharacter((Dom.data(player) :: any).Name, cf)
	Dom.set(player, "Character", character)
	Dom.setParent(character, self.workspace)
	Dom.emit(player, "CharacterAdded", character)
	self.scheduler:flush()
	return character
end

-- Events -----------------------------------------------------------------------------------------

--[[
	Fires an event the engine would fire:
	  rt:fire(part.Touched, otherPart)
	  rt:fire(prompt, "Triggered", player)
]]
function Runtime:fire(target: any, ...)
	if Signal.is(target) then
		Signal.fire(target, ...)
	else
		Dom.emit(target, ...)
	end
	self.scheduler:flush()
end

-- A client firing a RemoteEvent at the server.
function Runtime:fireServer(remote: any, player: any, ...)
	Dom.emit(remote, "OnServerEvent", player, ...)
	self.scheduler:flush()
end

-- A client invoking a RemoteFunction: runs OnServerInvoke and returns its results.
function Runtime:invokeServer(remote: any, player: any, ...): ...any
	local callback = Dom.callback(remote, "OnServerInvoke")
	if not callback then
		error(("%s has no OnServerInvoke"):format(Dom.fullName(remote)), 2)
	end
	return self:call(callback, player, ...)
end

-- A player triggering a ProximityPrompt.
function Runtime:triggerPrompt(prompt: any, player: any)
	Dom.emit(prompt, "Triggered", player)
	Dom.emit(self:getService("ProximityPromptService"), "PromptTriggered", prompt, player)
	self.scheduler:flush()
end

-- A Developer Product purchase: runs MarketplaceService.ProcessReceipt, returns its decision.
function Runtime:purchase(player: any, productId: number): any
	local callback = Dom.callback(self:getService("MarketplaceService"), "ProcessReceipt")
	if not callback then
		error("MarketplaceService.ProcessReceipt is not set", 2)
	end
	self.nextPurchase = (self.nextPurchase or 0) + 1
	return self:call(callback, {
		PlayerId = Dom.get(player, "UserId"),
		ProductId = productId,
		PurchaseId = "purchase-" .. self.nextPurchase,
		CurrencySpent = 0,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = 0,
	})
end

-- Calls a ContextActionService action bound with BindAction.
function Runtime:triggerAction(name: string, state: any?, input: any?): any
	local action = self.actions[name]
	if not action then
		error(("no action bound as %q"):format(name), 2)
	end
	return action.fn(name, state or Enum.UserInputState.Begin, input)
end

-- Runs game:BindToClose callbacks (server shutdown).
function Runtime:close()
	for _, fn in self.closeCallbacks do
		self:call(fn)
	end
end

-- Inspection -------------------------------------------------------------------------------------

--[[
	Calls made to a stubbed engine method: a list of { instance, args = { n = ... }, seq },
	where seq orders calls across methods. With several method names, the calls to any of them
	in the order they were made: rt:calls("Terrain", { "FillBall", "FillBlock" }).
]]
function Runtime:calls(className: string, method: string | { string }): { any }
	if type(method) == "string" then
		return self.callLog[className .. ":" .. method] or {}
	end
	local all = {}
	for _, name in method do
		for _, call in self.callLog[className .. ":" .. name] or {} do
			table.insert(all, call)
		end
	end
	table.sort(all, function(a, b)
		return a.seq < b.seq
	end)
	return all
end

-- Every BasePart under `root` (default: Workspace), excluding Terrain.
function Runtime:parts(root: any?): { any }
	local out = {}
	for _, d in Dom.descendantData(Dom.data(root or self.workspace) :: any) do
		if d.class.isA.BasePart and d.ClassName ~= "Terrain" then
			table.insert(out, d.u)
		end
	end
	return out
end

-- The source code of a script (an instance or a path for Runtime:find).
function Runtime:source(target: any): string
	if type(target) == "string" then
		target = self:find(target)
	end
	local d = Dom.data(target)
	if not d or d.source == nil then
		error(("%s has no source"):format(tostring(target)), 2)
	end
	return d.source
end

-- Instance.new from test code (can also create classes scripts can't, like Player).
function Runtime:create(className: string, props: { [string]: any }?, parent: any?): any
	local inst = Dom.new(self, className, true)
	for k, v in props or {} do
		(inst :: any)[k] = v
	end
	if parent then
		Dom.setParent(inst, parent)
	end
	return inst
end

Runtime.typeof = typeof
Runtime.Dom = Dom

-- Errors thrown inside task threads since the last call (used by the test runner).
function Runtime.takeUncaught(): { string }
	local list = Runtime.uncaught
	Runtime.uncaught = {}
	return list
end

return Runtime
