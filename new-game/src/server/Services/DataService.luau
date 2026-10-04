--!strict
--[[
	Player data: load on join, autosave, save on leave / shutdown.
	Swap the internals for ProfileStore later if you need session locking -
	keep the same public API (Get / Add / Save) so nothing else changes.
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
	warn("[DataService] DataStore unavailable - progress will NOT save. Publish the place and enable Studio API access.")
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

local function copyTemplate(): { [string]: any }
	local data = {}
	for key, value in Config.Data.Template do
		data[key] = value
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

function DataService.Add(player: Player, key: string, amount: number)
	local data = cache[player]
	if not data then
		return
	end
	data[key] = (data[key] or 0) + amount
	syncLeaderstats(player)
end

function DataService.Save(player: Player)
	local data = cache[player]
	if not store or not data or not loaded[player] then
		return
	end
	local activeStore = store
	withRetry(function()
		activeStore:UpdateAsync(tostring(player.UserId), function()
			return data
		end)
	end)
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
	local data = copyTemplate()
	if ok and typeof(saved) == "table" then
		for key, value in saved :: any do
			data[key] = value
		end
	end
	data.Joins = (data.Joins or 0) + 1
	cache[player] = data
	-- If the load failed we still let them play, but never overwrite their real save.
	loaded[player] = ok
	syncLeaderstats(player)
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
