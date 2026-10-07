--!strict
--[[
	Leaderboard Gravestone: top lifetime pumpkin collectors.
	Lifetime totals are the saved PumpkinsCollected field (DataService). They are also
	written to an OrderedDataStore so the top list is global; when DataStores aren't
	available (unpublished place, no API access) the list shows players in this server.
	The list is drawn on the gravestone's Screen part and copied to its "TopList"
	attribute for the client dialog.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local HubService = require(script.Parent.HubService)

type Entry = { UserId: number, Name: string, Pumpkins: number }

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local dirty: { [Player]: number } = {} -- the lifetime total still to write to the store
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "Unknown"
	return names[userId]
end

local function total(player: Player): number
	local data = DataService.Get(player)
	return if data then data.PumpkinsCollected or 0 else 0
end

-- Studio's local-server test players have user ids of 0 or below: never on the board.
local function isRealUser(userId: number): boolean
	return userId > 0
end

local function save(player: Player)
	local amount = dirty[player]
	if not store or not amount or not isRealUser(player.UserId) then
		return
	end
	dirty[player] = nil
	local activeStore = store
	local ok, err = pcall(function()
		activeStore:SetAsync(tostring(player.UserId), amount)
	end)
	if not ok then
		if player.Parent == Players and dirty[player] == nil then
			dirty[player] = amount -- (not for a player who left meanwhile: nothing would clear it)
		end
		warn("[LeaderboardService] save failed: " .. tostring(err))
	end
end

local function collect(): { Entry }
	local byUser: { [number]: number } = {}
	if store then
		local activeStore = store
		local ok, page = pcall(function()
			return activeStore:GetSortedAsync(false, Config.Leaderboard.TopCount):GetCurrentPage()
		end)
		if ok then
			for _, item in page do
				local userId = tonumber(item.key)
				if userId and isRealUser(userId) then
					byUser[userId] = item.value
				end
			end
		end
	end
	-- Online players' live totals (newer than the store until the next save).
	for _, player in Players:GetPlayers() do
		local amount = total(player)
		if amount > 0 and isRealUser(player.UserId) then
			byUser[player.UserId] = math.max(byUser[player.UserId] or 0, amount)
		end
	end
	local entries: { Entry } = {}
	for userId, pumpkins in byUser do
		table.insert(entries, { UserId = userId, Name = "", Pumpkins = pumpkins })
	end
	table.sort(entries, function(a, b)
		return a.Pumpkins > b.Pumpkins
	end)
	while #entries > Config.Leaderboard.TopCount do
		table.remove(entries)
	end
	for _, entry in entries do
		entry.Name = nameOf(entry.UserId)
	end
	return entries
end

local function render(entries: { Entry })
	local screen = HubService.Screen("Leaderboard")
	if not screen then
		return
	end
	local lines = {}
	for i, entry in entries do
		table.insert(lines, ("%d. %s  %d"):format(i, entry.Name, entry.Pumpkins))
	end
	local text = if #lines > 0
		then table.concat(lines, "\n")
		else "No pumpkins collected yet.\nBe the first!"
	screen:SetAttribute("TopList", text)

	local gui = screen:FindFirstChild("TopGui") :: SurfaceGui?
	if not gui then
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "TopGui"
		newGui.Face = Enum.NormalId.Front
		newGui.LightInfluence = 0
		newGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		newGui.PixelsPerStud = 30
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.18)
		title.Font = Enum.Font.Creepster
		title.TextScaled = true
		title.TextColor3 = Config.Hub.Colors.Orange
		title.Text = "Top Pumpkin Collectors"
		title.Parent = newGui
		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromScale(0.06, 0.2)
		body.Size = UDim2.fromScale(0.88, 0.78)
		body.Font = Enum.Font.GothamBold
		body.TextScaled = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextColor3 = Config.Hub.Colors.Bone
		body.Parent = newGui
		local maxSize = Instance.new("UITextSizeConstraint")
		maxSize.MaxTextSize = 36
		maxSize.Parent = body
		newGui.Parent = screen
		gui = newGui
	end
	local body = (gui :: SurfaceGui):FindFirstChild("Body") :: TextLabel?
	if body then
		body.Text = text
	end
end

function LeaderboardService.Refresh()
	for player in dirty do
		save(player)
	end
	render(collect())
end

-- Called at the end of each round with the pumpkins a player collected in it.
function LeaderboardService.Record(player: Player, pumpkins: number)
	if pumpkins <= 0 then
		return
	end
	DataService.Add(player, "PumpkinsCollected", pumpkins)
	-- Only a save that loaded has the real lifetime total: one that didn't load holds just this
	-- session's pumpkins, and writing that would wipe the player's total off the board.
	if DataService.IsLoaded(player) then
		dirty[player] = total(player)
	end
end

function LeaderboardService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.StoreName)
	end)
	if ok then
		store = result
	else
		warn(
			"[LeaderboardService] OrderedDataStore unavailable - gravestone shows this server only."
		)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		dirty[player] = nil
	end)

	task.spawn(function()
		while true do
			local refreshOk, err = pcall(LeaderboardService.Refresh)
			if not refreshOk then
				warn("[LeaderboardService] " .. tostring(err))
			end
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
