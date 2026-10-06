--!strict
--[[
	Player data: load on join, autosave, save on leave / shutdown.
	Swap the internals for ProfileStore later if you need session locking -
	keep the same public API (Get / IsLoaded / WaitForLoad / Add / Spend / Save) so nothing
	else changes.
	New saved fields go in Config.Data.Template; old saves get the missing fields (and
	missing keys inside table fields such as Equipped) filled in from the template on load.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

-- GetDataStore throws in Studio until the place is published and "Enable Studio Access to
-- API Services" is on. Fall back to no-save mode so the game still runs while building.
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(Config.Data.StoreName)
end)
local store: DataStore? = if storeOk then storeResult else nil
if not store then
	warn(
		"[DataService] DataStore unavailable - progress will NOT save. Publish the place and enable Studio API access."
	)
end
local cache: { [Player]: { [string]: any } } = {}
local loaded: { [Player]: boolean } = {}

local function withRetry<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] attempt %d failed: %s"):format(attempt, tostring(result)))
		task.wait(2 ^ attempt)
	end
	return false, nil
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- The template plus whatever the save has; template tables that are dictionaries (Equipped)
-- also get any keys the save is missing.
local function fromSave(saved: { [string]: any }?): { [string]: any }
	local data = deepCopy(Config.Data.Template)
	if not saved then
		return data
	end
	for key, value in saved do
		local default = data[key]
		if type(default) == "table" and type(value) == "table" and next(default) ~= nil then
			for k, v in value do
				default[k] = v
			end
		elseif default == nil or type(default) == type(value) then
			data[key] = value
		end
	end
	return data
end

local function syncLeaderstats(player: Player)
	local data = cache[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	for _, key in { "Coins", "Wins" } do
		local value = stats:FindFirstChild(key) :: IntValue?
		if not value then
			value = Instance.new("IntValue")
			value.Name = key
			value.Parent = stats
		end
		value.Value = data[key] or 0
	end
end

function DataService.Get(player: Player): { [string]: any }?
	return cache[player]
end

function DataService.IsLoaded(player: Player): boolean
	return loaded[player] == true
end

--[[
	For things that happen as a player joins (e.g. a Robux purchase Roblox hands over straight
	away): waits up to `seconds` while their save is still loading. Returns IsLoaded(player):
	false if it took too long, the load failed, or they left. May yield.
]]
function DataService.WaitForLoad(player: Player, seconds: number): boolean
	local deadline = os.clock() + math.max(seconds, 0)
	while cache[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.2)
	end
	return loaded[player] == true and player.Parent == Players
end

function DataService.Add(player: Player, key: string, amount: number)
	local data = cache[player]
	if not data then
		return
	end
	data[key] = (data[key] or 0) + amount
	syncLeaderstats(player)
end

-- Takes `amount` of a number field if the player has enough. Returns whether it did.
function DataService.Spend(player: Player, key: string, amount: number): boolean
	local data = cache[player]
	if not data or amount < 0 or (data[key] or 0) < amount then
		return false
	end
	data[key] -= amount
	syncLeaderstats(player)
	return true
end

--[[
	Saves now. Returns true when the data is safely stored, or when saving is off (no
	DataStore in an unpublished Studio place: nothing persists anyway). Returns false if the
	player's save never loaded or every attempt failed.
]]
function DataService.Save(player: Player): boolean
	local data = cache[player]
	if not data or not loaded[player] then
		return false
	end
	if not store then
		return true
	end
	local activeStore = store
	local ok = withRetry(function()
		activeStore:UpdateAsync(tostring(player.UserId), function()
			return data
		end)
	end)
	return ok
end

local function onJoin(player: Player)
	local ok: boolean = false
	local saved: any = nil
	if store then
		local activeStore = store
		ok, saved = withRetry(function()
			return activeStore:GetAsync(tostring(player.UserId))
		end)
	end
	if player.Parent ~= Players then
		return -- left while the save was loading; onLeave already ran
	end
	local data = fromSave(if ok and typeof(saved) == "table" then saved else nil)
	data.Joins = (data.Joins or 0) + 1
	cache[player] = data
	-- If the load failed we still let them play, but never overwrite their real save.
	-- With no DataStore at all (unpublished Studio place) nothing saves, so treat as loaded.
	loaded[player] = ok or not store
	syncLeaderstats(player)
	-- Other services wait for this before reading the data (e.g. to put on cosmetics).
	player:SetAttribute("DataReady", true)
end

local function onLeave(player: Player)
	DataService.Save(player)
	cache[player] = nil
	loaded[player] = nil
end

function DataService.Start()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
		task.wait(3)
	end)
end

return DataService
