--[[
	Minimal, deterministic behaviour for the engine services game code talks to.

	Anything not implemented here still exists: unimplemented methods are recorded no-op stubs
	(Runtime:calls("Class", "Method") lists their calls) and every event is a signal that only
	fires when a test fires it. State lives on the Runtime ("world"), so tests can set it up:
	  rt.secrets.AI_PROXY_KEY = "..."            HttpService:GetSecret
	  rt.httpHandler = function(request) ... end  HttpService:RequestAsync / GetAsync / PostAsync
	  rt.gamePasses[userId] = { [passId] = true } MarketplaceService:UserOwnsGamePassAsync
	  rt.groupRanks[userId] = { [groupId] = 255 } Player:GetRankInGroup
	  rt.dataStoreFailures = 2                    the next 2 DataStore requests error
	  rt.options.dataStores = false               GetDataStore errors (unpublished place)
	  rt.filterText = function(text) ... end      TextService filtering
]]

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Dom = require("./Dom")
local Types = require("./Types")

local Enum, Vector2 = roblox.Enum, roblox.Vector2
local typeof = Types.typeof

type Data = Dom.Data

local function world(self): any
	return (Dom.data(self) :: Data).world
end

local function childrenOfClass(self, className: string): { any }
	local out = {}
	for _, child in (Dom.data(self) :: Data).children do
		if child.class.isA[className] then
			table.insert(out, child.u)
		end
	end
	return out
end

local function newInternal(self, className: string): any
	return Dom.new(world(self), className, true)
end

-- DataModel -------------------------------------------------------------------------------------

Dom.define("DataModel", {
	GetService = function(self, name)
		return world(self):getService(name)
	end,
	FindService = function(self, name)
		for _, child in (Dom.data(self) :: Data).children do
			if child.ClassName == name then
				return child.u
			end
		end
		return nil
	end,
	BindToClose = function(self, fn)
		if type(fn) ~= "function" then
			error("BindToClose expects a function", 2)
		end
		table.insert(world(self).closeCallbacks, fn)
	end,
	IsLoaded = function()
		return true
	end,
	PlaceId = {
		get = function(_, d)
			return d.world.options.placeId or 0
		end,
		readOnly = true,
	},
	GameId = {
		get = function(_, d)
			return d.world.options.gameId or 0
		end,
		readOnly = true,
	},
	JobId = {
		get = function(_, d)
			return d.world.options.jobId or "00000000-0000-0000-0000-000000000000"
		end,
		readOnly = true,
	},
	CreatorId = {
		get = function(_, d)
			return d.world.options.creatorId or 0
		end,
		readOnly = true,
	},
	CreatorType = {
		get = function()
			return Enum.CreatorType.User
		end,
		readOnly = true,
	},
	PrivateServerId = {
		get = function()
			return ""
		end,
		readOnly = true,
	},
	PrivateServerOwnerId = {
		get = function()
			return 0
		end,
		readOnly = true,
	},
})

Dom.define("Workspace", {
	Terrain = {
		get = function(_, d)
			for _, child in d.children do
				if child.ClassName == "Terrain" then
					return child.u
				end
			end
			return nil
		end,
		readOnly = true,
	},
	GetServerTimeNow = function(self)
		local w = world(self)
		return w.epoch + w.scheduler.now
	end,
	DistributedGameTime = {
		get = function(_, d)
			return d.world.scheduler.now
		end,
		readOnly = true,
	},
})

Dom.define("Lighting", {
	GetMinutesAfterMidnight = function(self)
		return (Dom.get(self, "ClockTime") :: number) * 60
	end,
	SetMinutesAfterMidnight = function(self, minutes)
		Dom.set(self, "ClockTime", (minutes / 60) % 24)
	end,
})

-- Players ---------------------------------------------------------------------------------------

local function userIdOf(player): number
	return Dom.get(player, "UserId") :: number
end

Dom.define("Players", {
	GetPlayers = function(self)
		return childrenOfClass(self, "Player")
	end,
	GetPlayerByUserId = function(self, userId)
		for _, player in childrenOfClass(self, "Player") do
			if userIdOf(player) == userId then
				return player
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(self, character)
		if character == nil then
			return nil
		end
		for _, player in childrenOfClass(self, "Player") do
			if Dom.get(player, "Character") == character then
				return player
			end
		end
		return nil
	end,
	LocalPlayer = {
		get = function(_, d)
			return d.world.localPlayer
		end,
		readOnly = true,
	},
	MaxPlayers = {
		get = function(_, d)
			return d.world.options.maxPlayers or 12
		end,
		readOnly = true,
	},
	GetUserThumbnailAsync = function(_, userId)
		return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(tonumber(userId) or 0),
			true
	end,
	GetNameFromUserIdAsync = function(self, userId)
		for _, player in childrenOfClass(self, "Player") do
			if userIdOf(player) == userId then
				return (Dom.data(player) :: Data).Name
			end
		end
		return "Player" .. tostring(userId)
	end,
	GetUserIdFromNameAsync = function(self, name)
		for _, player in childrenOfClass(self, "Player") do
			if (Dom.data(player) :: Data).Name == name then
				return userIdOf(player)
			end
		end
		error("Failed to get user id for " .. tostring(name), 2)
	end,
})

Dom.define("Player", {
	DisplayName = {
		get = function(_, d)
			return d.props.DisplayName or d.Name
		end,
		set = function(_, d, value)
			d.props.DisplayName = Dom.check("String", value, "DisplayName")
		end,
	},
	Kick = function(self, message)
		local w = world(self)
		w:recordCall("Player", "Kick", self, message)
		w:removePlayer(self)
	end,
	LoadCharacter = function(self)
		world(self):spawnCharacter(self)
	end,
	GetRankInGroup = function(self, groupId)
		local ranks = world(self).groupRanks[userIdOf(self)]
		return ranks and ranks[groupId] or 0
	end,
	GetRankInGroupAsync = function(self, groupId)
		local ranks = world(self).groupRanks[userIdOf(self)]
		return ranks and ranks[groupId] or 0
	end,
	GetRoleInGroup = function(self, groupId)
		local ranks = world(self).groupRanks[userIdOf(self)]
		return if ranks and (ranks[groupId] or 0) > 0 then "Member" else "Guest"
	end,
	IsInGroup = function(self, groupId)
		local ranks = world(self).groupRanks[userIdOf(self)]
		return ranks ~= nil and (ranks[groupId] or 0) > 0
	end,
	IsInGroupAsync = function(self, groupId)
		local ranks = world(self).groupRanks[userIdOf(self)]
		return ranks ~= nil and (ranks[groupId] or 0) > 0
	end,
	IsFriendsWith = function(self, otherId)
		local friends = world(self).friends[userIdOf(self)]
		return friends ~= nil and friends[otherId] == true
	end,
	IsFriendsWithAsync = function(self, otherId)
		local friends = world(self).friends[userIdOf(self)]
		return friends ~= nil and friends[otherId] == true
	end,
	HasAppearanceLoaded = function()
		return true
	end,
	DistanceFromCharacter = function(self, point)
		local character = Dom.get(self, "Character")
		local head = character and (character :: any):FindFirstChild("Head")
		if not head then
			return 0
		end
		return ((head :: any).Position - point).Magnitude
	end,
	GetJoinData = function()
		return { LaunchData = "", Members = {}, TeleportData = nil }
	end,
	GetMouse = function(self)
		local d = Dom.data(self) :: Data
		local mouse = d.props.__Mouse
		if not mouse then
			mouse = newInternal(self, "PlayerMouse")
			d.props.__Mouse = mouse
		end
		return mouse
	end,
})

-- RunService ------------------------------------------------------------------------------------

Dom.define("RunService", {
	IsServer = function(self)
		return world(self).options.client ~= true
	end,
	IsClient = function(self)
		return world(self).options.client == true
	end,
	IsStudio = function(self)
		return world(self).options.studio == true
	end,
	IsRunning = function()
		return true
	end,
	IsRunMode = function()
		return true
	end,
	IsEdit = function()
		return false
	end,
	BindToRenderStep = function(self, name, priority, fn)
		world(self).renderSteps[name] = { priority = priority, fn = fn }
	end,
	UnbindFromRenderStep = function(self, name)
		world(self).renderSteps[name] = nil
	end,
})

-- CollectionService -------------------------------------------------------------------------------

local function expectInstance(value: any, argument: number, method: string)
	if not Dom.isInstance(value) then
		error(
			("invalid argument #%d to '%s' (Instance expected, got %s)"):format(
				argument,
				method,
				typeof(value)
			),
			3
		)
	end
end

Dom.define("CollectionService", {
	AddTag = function(_, instance, tag)
		expectInstance(instance, 1, "AddTag")
		instance:AddTag(tag)
	end,
	RemoveTag = function(_, instance, tag)
		expectInstance(instance, 1, "RemoveTag")
		instance:RemoveTag(tag)
	end,
	HasTag = function(_, instance, tag)
		expectInstance(instance, 1, "HasTag")
		return instance:HasTag(tag)
	end,
	GetTags = function(_, instance)
		expectInstance(instance, 1, "GetTags")
		return instance:GetTags()
	end,
	GetTagged = function(self, tag)
		local out = {}
		for _, d in Dom.descendantData(world(self).gameData) do
			if d.tags and table.find(d.tags, tag) then
				table.insert(out, d.u)
			end
		end
		return out
	end,
	GetAllTags = function(self)
		local seen, out = {}, {}
		for _, d in Dom.descendantData(world(self).gameData) do
			for _, tag in d.tags or {} do
				if not seen[tag] then
					seen[tag] = true
					table.insert(out, tag)
				end
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(self, tag)
		return world(self):tagSignal(tag, true)
	end,
	GetInstanceRemovedSignal = function(self, tag)
		return world(self):tagSignal(tag, false)
	end,
})

-- TweenService ------------------------------------------------------------------------------------

local function ease(alpha: number, style: any, direction: any): number
	alpha = math.clamp(alpha, 0, 1)
	local function curve(t: number): number
		if style == Enum.EasingStyle.Linear then
			return t
		elseif style == Enum.EasingStyle.Sine then
			return 1 - math.cos(t * math.pi / 2)
		elseif style == Enum.EasingStyle.Cubic then
			return t ^ 3
		elseif style == Enum.EasingStyle.Quart then
			return t ^ 4
		elseif style == Enum.EasingStyle.Quint then
			return t ^ 5
		elseif style == Enum.EasingStyle.Exponential then
			return if t == 0 then 0 else 2 ^ (10 * t - 10)
		elseif style == Enum.EasingStyle.Circular then
			return 1 - math.sqrt(1 - t * t)
		end
		return t * t -- Quad, and an approximation of the rest
	end
	if direction == Enum.EasingDirection.In then
		return curve(alpha)
	elseif direction == Enum.EasingDirection.InOut then
		return if alpha < 0.5 then curve(alpha * 2) / 2 else 1 - curve((1 - alpha) * 2) / 2
	end
	return 1 - curve(1 - alpha)
end

Dom.define("TweenService", {
	Create = function(self, instance, info, goals)
		expectInstance(instance, 1, "Create")
		if typeof(info) ~= "TweenInfo" then
			error(
				("invalid argument #2 to 'Create' (TweenInfo expected, got %s)"):format(
					typeof(info)
				),
				2
			)
		end
		if type(goals) ~= "table" then
			error(
				("invalid argument #3 to 'Create' (table expected, got %s)"):format(typeof(goals)),
				2
			)
		end
		for key, value in goals do
			local member = Dom.member(instance, key)
			if not member or member.kind ~= "prop" then
				error(
					("TweenService:Create no property named '%s' for object '%s'"):format(
						tostring(key),
						Dom.fullName(instance)
					),
					2
				)
			end
			local current = Dom.get(instance, key)
			if typeof(current) ~= typeof(value) then
				error(
					("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')"):format(
						key,
						typeof(current),
						typeof(value)
					),
					2
				)
			end
		end
		local tween = newInternal(self, "Tween")
		Dom.rawSet(tween, "__Target", instance)
		Dom.rawSet(tween, "__Info", info)
		Dom.rawSet(tween, "__Goals", table.clone(goals))
		Dom.rawSet(tween, "__State", Enum.PlaybackState.Begin)
		return tween
	end,
	GetValue = function(_, alpha, style, direction)
		return ease(alpha, style, direction)
	end,
})

local function setTweenState(tween, state)
	Dom.rawSet(tween, "__State", state)
	Dom.changed(tween, "PlaybackState")
end

Dom.define("Tween", {
	Instance = {
		get = function(_, d)
			return d.props.__Target
		end,
		readOnly = true,
	},
	TweenInfo = {
		get = function(_, d)
			return d.props.__Info
		end,
		readOnly = true,
	},
	PlaybackState = {
		get = function(_, d)
			return d.props.__State
		end,
		readOnly = true,
	},
	-- Goals are applied when the tween finishes (after its virtual duration).
	Play = function(self)
		local d = Dom.data(self) :: Data
		if d.props.__State == Enum.PlaybackState.Playing then
			return
		end
		local info = d.props.__Info
		local target = d.props.__Target
		local goals = d.props.__Goals
		local start = {}
		for key in goals do
			start[key] = Dom.get(target, key)
		end
		local token = (d.props.__Token or 0) + 1
		d.props.__Token = token
		setTweenState(self, Enum.PlaybackState.Playing)
		if info.RepeatCount < 0 then
			return -- loops forever
		end
		local passes = (info.RepeatCount + 1) * (if info.Reverses then 2 else 1)
		local total = info.DelayTime + info.Time * passes
		world(self).scheduler:delay(total, function()
			if d.props.__Token ~= token then
				return
			end
			local final = if info.Reverses then start else goals
			for key, value in final do
				Dom.set(target, key, value)
			end
			setTweenState(self, Enum.PlaybackState.Completed)
			Dom.emit(self, "Completed", Enum.PlaybackState.Completed)
		end)
	end,
	Pause = function(self)
		local d = Dom.data(self) :: Data
		d.props.__Token = (d.props.__Token or 0) + 1
		setTweenState(self, Enum.PlaybackState.Paused)
	end,
	Cancel = function(self)
		local d = Dom.data(self) :: Data
		d.props.__Token = (d.props.__Token or 0) + 1
		setTweenState(self, Enum.PlaybackState.Cancelled)
		Dom.emit(self, "Completed", Enum.PlaybackState.Cancelled)
	end,
})

-- Bindables (remote events only record their calls: there is no client/server split) ----------

Dom.define("BindableEvent", {
	Fire = function(self, ...)
		Dom.emit(self, "Event", ...)
	end,
})

Dom.define("BindableFunction", {
	Invoke = function(self, ...)
		local callback = Dom.callback(self, "OnInvoke")
		if not callback then
			error(
				("%s has no OnInvoke callback (it would yield forever)"):format(Dom.fullName(self)),
				2
			)
		end
		return callback(...)
	end,
})

-- A client calling the server. In a client runtime a test can play the server by setting the
-- remote's OnServerInvoke (called with the local player); without one the call is only
-- recorded and returns nothing.
Dom.define("RemoteFunction", {
	InvokeServer = function(self, ...)
		local w = world(self)
		w:recordCall("RemoteFunction", "InvokeServer", self, ...)
		local callback = Dom.callback(self, "OnServerInvoke")
		if callback and w.localPlayer then
			return callback(w.localPlayer, ...)
		end
		return nil
	end,
})

-- Debris ------------------------------------------------------------------------------------------

Dom.define("Debris", {
	AddItem = function(self, item, lifetime)
		expectInstance(item, 1, "AddItem")
		world(self).scheduler:delay(tonumber(lifetime) or 10, function()
			Dom.destroy(item)
		end)
	end,
})

-- HttpService -------------------------------------------------------------------------------------

local SecretMeta = { __type = "Secret" }
SecretMeta.__index = {
	AddPrefix = function(self, prefix)
		return setmetatable({ _value = prefix .. self._value }, SecretMeta)
	end,
	AddSuffix = function(self, suffix)
		return setmetatable({ _value = self._value .. suffix }, SecretMeta)
	end,
}
SecretMeta.__tostring = function()
	return "Secret"
end

local function httpRequest(self, request)
	local w = world(self)
	w:recordCall("HttpService", "Request", self, request)
	if not w.httpHandler then
		error("Http requests are not enabled. Enable via game settings", 3)
	end
	return w.httpHandler(request)
end

Dom.define("HttpService", {
	HttpEnabled = {
		get = function(_, d)
			return d.world.httpHandler ~= nil
		end,
		readOnly = true,
	},
	JSONEncode = function(_, value)
		local ok, result = pcall(serde.encode, "json", value)
		if not ok then
			error("Can't convert to JSON", 2)
		end
		return result
	end,
	JSONDecode = function(_, text)
		if type(text) ~= "string" then
			error("Can't parse JSON", 2)
		end
		local ok, result = pcall(serde.decode, "json", text)
		if not ok then
			error("Can't parse JSON", 2)
		end
		return result
	end,
	GenerateGUID = function(_, wrap)
		local hex = {}
		for i = 1, 32 do
			local n = math.random(1, 16)
			hex[i] = ("0123456789ABCDEF"):sub(n, n)
		end
		local s = table.concat(hex)
		local guid = ("%s-%s-%s-%s-%s"):format(
			s:sub(1, 8),
			s:sub(9, 12),
			s:sub(13, 16),
			s:sub(17, 20),
			s:sub(21, 32)
		)
		return if wrap == false then guid else "{" .. guid .. "}"
	end,
	UrlEncode = function(_, text)
		return (
			tostring(text):gsub("[^%w%-_%.~]", function(c)
				return ("%%%02X"):format(string.byte(c))
			end)
		)
	end,
	GetSecret = function(self, key)
		local value = world(self).secrets[key]
		if value == nil then
			error("Can't find secret with given key", 2)
		end
		return setmetatable({ _value = value }, SecretMeta)
	end,
	RequestAsync = function(self, request)
		return httpRequest(self, request)
	end,
	GetAsync = function(self, url, nocache, headers)
		local response = httpRequest(self, { Url = url, Method = "GET", Headers = headers })
		return response and response.Body
	end,
	PostAsync = function(self, url, body, contentType, compress, headers)
		local response =
			httpRequest(self, { Url = url, Method = "POST", Body = body, Headers = headers })
		return response and response.Body
	end,
})

-- DataStoreService --------------------------------------------------------------------------------

local function storeFor(w, kind: string, name: string, scope: string?)
	local key = ("%s:%s:%s"):format(kind, name, scope or "global")
	local store = w.dataStores[key]
	if not store then
		store = { kind = kind, name = name, data = {} }
		w.dataStores[key] = store
	end
	return store
end

local function maybeFail(w)
	if (w.dataStoreFailures or 0) > 0 then
		w.dataStoreFailures -= 1
		error("502: API Services rejected request with error. HTTP 500 (Internal Server Error)", 4)
	end
end

local function checkKey(key: any)
	if type(key) ~= "string" or #key == 0 or #key > 50 then
		error(
			("101: Key name can't be empty or longer than 50 characters (got %s)"):format(
				tostring(key)
			),
			4
		)
	end
end

-- Values are stored as JSON, so anything Roblox couldn't save fails here too.
local function encode(value: any): string
	local function check(v, path)
		local t = typeof(v)
		if t == "table" then
			local isArray = #v > 0 or next(v) == nil
			for k, inner in v do
				if isArray and type(k) ~= "number" then
					error(
						("104: Cannot store mixed array/dictionary in data store (at %s)"):format(
							path
						),
						5
					)
				elseif not isArray and type(k) ~= "string" then
					error(
						("104: Cannot store dictionary with %s keys in data store (at %s)"):format(
							type(k),
							path
						),
						5
					)
				end
				check(inner, path .. "." .. tostring(k))
			end
		elseif t ~= "string" and t ~= "number" and t ~= "boolean" and t ~= "nil" then
			error(("104: Cannot store %s in data store (at %s)"):format(t, path), 5)
		end
	end
	check(value, "value")
	return serde.encode("json", value)
end

local function decode(text: string?): any
	if text == nil then
		return nil
	end
	return serde.decode("json", text)
end

local function keyInfo()
	return setmetatable({
		Version = "1",
		CreatedTime = 0,
		UpdatedTime = 0,
		GetUserIds = function()
			return {}
		end,
		GetMetadata = function()
			return {}
		end,
	}, { __type = "DataStoreKeyInfo" })
end

local function newStore(self, className: string, name: any, scope: any)
	local w = world(self)
	if w.options.dataStores == false then
		error("You must publish this place to the web to access DataStore.", 3)
	end
	if type(name) ~= "string" then
		error("invalid argument #1 (string expected)", 3)
	end
	local store = newInternal(self, className)
	Dom.data(store).Name = name
	Dom.rawSet(store, "__Store", storeFor(w, className, name, scope))
	return store
end

Dom.define("DataStoreService", {
	GetDataStore = function(self, name, scope)
		return newStore(self, "DataStore", name, scope)
	end,
	GetGlobalDataStore = function(self)
		return newStore(self, "DataStore", "global", nil)
	end,
	GetOrderedDataStore = function(self, name, scope)
		return newStore(self, "OrderedDataStore", name, scope)
	end,
	GetRequestBudgetForRequestType = function()
		return 100
	end,
})

local function storeOf(self)
	return Dom.rawGet(self, "__Store")
end

Dom.define("GlobalDataStore", {
	GetAsync = function(self, key)
		maybeFail(world(self))
		checkKey(key)
		local value = decode(storeOf(self).data[key])
		return value, if value ~= nil then keyInfo() else nil
	end,
	SetAsync = function(self, key, value)
		maybeFail(world(self))
		checkKey(key)
		storeOf(self).data[key] = encode(value)
		return "1"
	end,
	UpdateAsync = function(self, key, transform)
		maybeFail(world(self))
		checkKey(key)
		local store = storeOf(self)
		local old = decode(store.data[key])
		local new = transform(old, if old ~= nil then keyInfo() else nil)
		if new == nil then
			return nil
		end
		store.data[key] = encode(new)
		return decode(store.data[key]), keyInfo()
	end,
	RemoveAsync = function(self, key)
		maybeFail(world(self))
		checkKey(key)
		local store = storeOf(self)
		local old = decode(store.data[key])
		store.data[key] = nil
		return old, if old ~= nil then keyInfo() else nil
	end,
	IncrementAsync = function(self, key, delta)
		maybeFail(world(self))
		checkKey(key)
		local store = storeOf(self)
		local current = decode(store.data[key]) or 0
		if type(current) ~= "number" then
			error("105: Cannot increment a non-number value", 2)
		end
		local value = current + math.floor(tonumber(delta) or 1)
		store.data[key] = encode(value)
		return value
	end,
})

Dom.define("OrderedDataStore", {
	GetSortedAsync = function(self, ascending, pageSize, minValue, maxValue)
		maybeFail(world(self))
		local entries = {}
		for key, text in storeOf(self).data do
			local value = decode(text)
			if
				type(value) == "number"
				and (minValue == nil or value >= minValue)
				and (maxValue == nil or value <= maxValue)
			then
				table.insert(entries, { key = key, value = value })
			end
		end
		table.sort(entries, function(a, b)
			if a.value == b.value then
				return a.key < b.key
			end
			return if ascending then a.value < b.value else a.value > b.value
		end)
		local pages = newInternal(self, "DataStorePages")
		Dom.rawSet(pages, "__Entries", entries)
		Dom.rawSet(pages, "__Size", math.max(1, math.floor(tonumber(pageSize) or 50)))
		Dom.rawSet(pages, "__Page", 1)
		return pages
	end,
})

local function pageBounds(self): (number, number, number)
	local size = Dom.rawGet(self, "__Size")
	local page = Dom.rawGet(self, "__Page")
	return (page - 1) * size + 1, page * size, #Dom.rawGet(self, "__Entries")
end

Dom.define("Pages", {
	GetCurrentPage = function(self)
		local first, last, count = pageBounds(self)
		local out = {}
		local entries = Dom.rawGet(self, "__Entries") or {}
		for i = first, math.min(last, count) do
			table.insert(out, entries[i])
		end
		return out
	end,
	IsFinished = {
		get = function(_, d)
			if not d.props.__Entries then
				return true
			end
			local _, last, count = pageBounds(d.u)
			return last >= count
		end,
		readOnly = true,
	},
	AdvanceToNextPageAsync = function(self)
		Dom.rawSet(self, "__Page", (Dom.rawGet(self, "__Page") or 1) + 1)
	end,
})

-- MarketplaceService ------------------------------------------------------------------------------

Dom.define("MarketplaceService", {
	UserOwnsGamePassAsync = function(self, userId, passId)
		local owned = world(self).gamePasses[userId]
		return owned ~= nil and owned[passId] == true
	end,
	PlayerOwnsAsset = function()
		return false
	end,
	GetProductInfo = function(_, id)
		return {
			Name = "Product " .. tostring(id),
			Description = "",
			PriceInRobux = 0,
			AssetId = id,
			ProductId = id,
			IsForSale = true,
			Creator = { Name = "Test", Id = 0 },
			IconImageAssetId = 0,
		}
	end,
})

Dom.define("PolicyService", {
	GetPolicyInfoForPlayerAsync = function()
		return {
			AreAdsAllowed = true,
			ArePaidRandomItemsRestricted = false,
			AllowedExternalLinkReferences = {},
			IsContentSharingAllowed = true,
			IsEligibleToPurchaseSubscription = true,
			IsPaidItemTradingAllowed = true,
			IsSubjectToChinaPolicies = false,
		}
	end,
})

-- TextService -------------------------------------------------------------------------------------

local function filtered(self): string
	local text = Dom.rawGet(self, "__Text")
	local filter = world(self).filterText
	return if filter then filter(text) else text
end

Dom.define("TextService", {
	FilterStringAsync = function(self, text, fromUserId)
		if type(text) ~= "string" then
			error("invalid argument #1 to 'FilterStringAsync' (string expected)", 2)
		end
		local result = newInternal(self, "TextFilterResult")
		Dom.rawSet(result, "__Text", text)
		return result
	end,
	GetTextSize = function(_, text, size, _font, frame)
		local width = #tostring(text) * size * 0.5
		local lines = 1
		if frame and frame.X > 0 and width > frame.X then
			lines = math.ceil(width / frame.X)
			width = frame.X
		end
		return Vector2.new(width, size * lines)
	end,
	GetTextBoundsAsync = function(_, params)
		local size = Dom.get(params, "Size") :: number
		return Vector2.new(#(Dom.get(params, "Text") :: string) * size * 0.5, size)
	end,
})

Dom.define("TextFilterResult", {
	GetNonChatStringForBroadcastAsync = function(self)
		return filtered(self)
	end,
	GetNonChatStringForUserAsync = function(self)
		return filtered(self)
	end,
	GetChatForUserAsync = function(self)
		return filtered(self)
	end,
})

-- PhysicsService ----------------------------------------------------------------------------------

local function groups(self)
	return world(self).collisionGroups
end

local function requireGroup(self, name: string)
	if not groups(self).registered[name] then
		error(("Collision group '%s' does not exist."):format(tostring(name)), 3)
	end
end

local function pairKey(a: string, b: string): string
	return if a < b then a .. "\0" .. b else b .. "\0" .. a
end

Dom.define("PhysicsService", {
	RegisterCollisionGroup = function(self, name)
		local g = groups(self)
		if not g.registered[name] then
			g.registered[name] = true
			table.insert(g.order, name)
		end
	end,
	UnregisterCollisionGroup = function(self, name)
		local g = groups(self)
		g.registered[name] = nil
		local i = table.find(g.order, name)
		if i then
			table.remove(g.order, i)
		end
	end,
	IsCollisionGroupRegistered = function(self, name)
		return groups(self).registered[name] == true
	end,
	CollisionGroupSetCollidable = function(self, a, b, collidable)
		requireGroup(self, a)
		requireGroup(self, b)
		groups(self).collidable[pairKey(a, b)] = collidable == true
	end,
	CollisionGroupsAreCollidable = function(self, a, b)
		requireGroup(self, a)
		requireGroup(self, b)
		local value = groups(self).collidable[pairKey(a, b)]
		return value ~= false
	end,
	GetRegisteredCollisionGroups = function(self)
		local out = {}
		for i, name in groups(self).order do
			out[i] = { name = name, id = i - 1, mask = 0 }
		end
		return out
	end,
	GetMaxCollisionGroups = function()
		return 32
	end,
})

-- PathfindingService: straight-line paths -----------------------------------------------------------

local WaypointMeta = { __type = "PathWaypoint" }
WaypointMeta.__tostring = function(self)
	return "PathWaypoint(" .. tostring(self.Position) .. ")"
end

local function waypoint(position: Vector3)
	return setmetatable(
		{ Position = position, Action = Enum.PathWaypointAction.Walk, Label = "" },
		WaypointMeta
	)
end

Dom.define("PathfindingService", {
	CreatePath = function(self, params)
		local path = newInternal(self, "Path")
		Dom.rawSet(path, "__Params", params)
		return path
	end,
	FindPathAsync = function(self, from, to)
		local path = newInternal(self, "Path")
		path:ComputeAsync(from, to)
		return path
	end,
})

Dom.define("Path", {
	ComputeAsync = function(self, from, to)
		Dom.rawSet(self, "__Waypoints", { waypoint(from), waypoint(to) })
		Dom.rawSet(self, "Status", Enum.PathStatus.Success)
		world(self):recordCall("Path", "ComputeAsync", self, from, to)
	end,
	GetWaypoints = function(self)
		return table.clone(Dom.rawGet(self, "__Waypoints") or {})
	end,
	CheckOcclusionAsync = function()
		return -1
	end,
})

-- Input ---------------------------------------------------------------------------------------------

Dom.define("ContextActionService", {
	BindAction = function(self, name, fn, _touch, ...)
		world(self).actions[name] = { fn = fn, inputs = { ... } }
	end,
	BindActionAtPriority = function(self, name, fn, _touch, _priority, ...)
		world(self).actions[name] = { fn = fn, inputs = { ... } }
	end,
	UnbindAction = function(self, name)
		world(self).actions[name] = nil
	end,
	GetBoundActionInfo = function(self, name)
		local action = world(self).actions[name]
		return if action then { inputTypes = action.inputs } else {}
	end,
})

local function inputFlag(name: string, default: boolean)
	return {
		get = function(_, d)
			local input = d.world.options.input
			if input and input[name] ~= nil then
				return input[name]
			end
			return default
		end,
		readOnly = true,
	}
end

Dom.define("UserInputService", {
	TouchEnabled = inputFlag("TouchEnabled", false),
	KeyboardEnabled = inputFlag("KeyboardEnabled", true),
	MouseEnabled = inputFlag("MouseEnabled", true),
	GamepadEnabled = inputFlag("GamepadEnabled", false),
	VREnabled = inputFlag("VREnabled", false),
	IsKeyDown = function()
		return false
	end,
	GetMouseLocation = function()
		return Vector2.zero
	end,
	GetLastInputType = function()
		return Enum.UserInputType.Keyboard
	end,
})

local Services = {}

-- RunService events, fired once per frame while time advances (Runtime wires this up).
function Services.frame(w, dt: number)
	local run = w.game:FindService("RunService")
	if run then
		local now = w.scheduler.now
		if w.options.client then
			Dom.emit(run, "PreRender", dt)
			Dom.emit(run, "RenderStepped", dt)
			local steps = {}
			for _, step in w.renderSteps do
				table.insert(steps, step)
			end
			table.sort(steps, function(a, b)
				return a.priority < b.priority
			end)
			for _, step in steps do
				w.scheduler:spawn(step.fn, dt)
			end
		end
		Dom.emit(run, "Stepped", now, dt)
		Dom.emit(run, "PreSimulation", dt)
		Dom.emit(run, "PostSimulation", dt)
		Dom.emit(run, "Heartbeat", dt)
	end
end

function Services.frameActive(w): boolean
	local l = w.listening
	return (l.Heartbeat or 0) > 0
		or (l.Stepped or 0) > 0
		or (l.RenderStepped or 0) > 0
		or (l.PreRender or 0) > 0
		or (l.PreSimulation or 0) > 0
		or (l.PostSimulation or 0) > 0
		or next(w.renderSteps) ~= nil
end

Services.waypoint = waypoint
Services.ease = ease

return Services
