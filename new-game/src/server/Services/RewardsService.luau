--!strict
--[[
	Things that bring players back and bring their friends (docs/VIRAL.md):
	  Codes        - RedeemCode(text) -> (ok, message). Config.Codes; each code once per player.
	  Daily streak - coins on the first join of each day (Config.Daily); the client is told
	                 with DailyReward(streak, coins).
	  Round bonus  - extra round coins for each Roblox friend in the server and for members of
	                 Config.Social.GroupId. GameService asks BonusPercent(player).
	  Favourite    - after Config.Social.FavoritePromptAfterRounds finished rounds the client
	                 is told once (PromptFavorite) to show Roblox's favourite prompt.
	Everything is decided and saved on the server; the client only sends the code text.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local RewardsService = {}

local lastAttempt: { [Player]: number } = {}
local friends: { [Player]: { [number]: boolean } } = {} -- [player][otherUserId] = friends?
local inGroup: { [Player]: boolean } = {}
local dailyReward: RemoteEvent
local promptFavorite: RemoteEvent

-- Codes ---------------------------------------------------------------------------------------

local function normalise(text: string): string
	return (text:gsub("%s", "")):upper()
end

-- "YYYY-MM-DD" -> the last second of that day (UTC), or nil for "never expires".
local function expiryTime(expires: string): number?
	local y, m, d = expires:match("^(%d+)-(%d+)-(%d+)$")
	if not y then
		return nil
	end
	return os.time({
		year = tonumber(y) :: number,
		month = tonumber(m) :: number,
		day = tonumber(d) :: number,
		hour = 23,
		min = 59,
		sec = 59,
	})
end

local function findCode(code: string): any
	for _, def in Config.Codes.List do
		if normalise(def.Code) == code then
			return def
		end
	end
	return nil
end

local function redeem(player: Player, text: unknown): (boolean, string)
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < Config.Codes.RequestCooldown then
		return false, "Slow down, try again in a moment."
	end
	lastAttempt[player] = now
	if typeof(text) ~= "string" or #text == 0 or #text > 40 then
		return false, "Type a code first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading your save, try again."
	end
	local code = normalise(text)
	local def = findCode(code)
	if not def then
		return false, "That code doesn't exist."
	end
	local expires = expiryTime(def.Expires)
	if expires and os.time() > expires then
		return false, "That code has expired."
	end
	data.Codes = data.Codes or {}
	if data.Codes[code] then
		return false, "You already used that code."
	end
	data.Codes[code] = true
	local gifts = {}
	if def.Coins and def.Coins > 0 then
		DataService.Add(player, "Coins", def.Coins)
		table.insert(gifts, ("%d %s"):format(def.Coins, Config.Economy.CurrencyName))
	end
	if def.Item then
		local item = Cosmetics.Find(def.Item)
		if item then
			data.Owned[item.Id] = true
			table.insert(gifts, item.Name)
		else
			warn("[RewardsService] code " .. code .. " gives unknown item " .. tostring(def.Item))
		end
	end
	ShopService.Push(player)
	return true, "Redeemed! You got " .. table.concat(gifts, " and ") .. "."
end

-- Daily streak ----------------------------------------------------------------------------------

local function claimDaily(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local cfg = Config.Daily
	local daily = data.Daily or { Streak = 0, Last = 0 }
	local now = os.time()
	local hours = (now - (daily.Last or 0)) / 3600
	if (daily.Last or 0) ~= 0 and hours < cfg.CooldownHours then
		return -- already claimed today
	end
	local streak = daily.Streak or 0
	if (daily.Last or 0) == 0 or hours > cfg.GraceHours then
		streak = 0
	end
	streak += 1
	local coins = cfg.Rewards[math.min(streak, #cfg.Rewards)]
	data.Daily = { Streak = streak, Last = now }
	DataService.Add(player, "Coins", coins)
	ShopService.Push(player)
	dailyReward:FireClient(player, streak, coins)
end

-- Friends and groups ------------------------------------------------------------------------------

local function checkFriends(player: Player)
	if player.Parent ~= Players then
		return
	end
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if player.Parent ~= Players or other.Parent ~= Players or not friends[player] then
			continue -- someone left while we were asking Roblox
		end
		if other ~= player and friends[player][other.UserId] == nil then
			local ok, result = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			-- (That asked Roblox and waited: either of them may have left meanwhile, and their
			-- tables were cleared then. Don't bring them back.)
			if player.Parent ~= Players or other.Parent ~= Players or not friends[player] then
				continue
			end
			local yes = ok and result == true
			friends[player][other.UserId] = yes
			friends[other] = friends[other] or {}
			friends[other][player.UserId] = yes
		end
	end
end

-- Extra round coins for this player, in percent.
function RewardsService.BonusPercent(player: Player): number
	local cfg = Config.Social
	local count = 0
	local mine = friends[player]
	if mine then
		for _, other in Players:GetPlayers() do
			if mine[other.UserId] then
				count += 1
			end
		end
	end
	local percent = math.min(count * cfg.FriendBonusPercent, cfg.MaxFriendBonusPercent)
	if inGroup[player] then
		percent += cfg.GroupBonusPercent
	end
	return percent
end

-- Called by GameService for every player who finished a round.
function RewardsService.RoundFinished(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.RoundsPlayed = (data.RoundsPlayed or 0) + 1
	local after = Config.Social.FavoritePromptAfterRounds
	if after > 0 and data.RoundsPlayed >= after and not data.FavoritePrompted then
		data.FavoritePrompted = true
		promptFavorite:FireClient(player)
	end
end

function RewardsService.Start()
	dailyReward = Remotes.Event("DailyReward")
	promptFavorite = Remotes.Event("PromptFavorite")
	Remotes.Function("RedeemCode").OnServerInvoke = redeem

	local function onPlayer(player: Player)
		task.spawn(checkFriends, player)
		if Config.Social.GroupId ~= 0 then
			task.spawn(function()
				local ok, result = pcall(function()
					return player:IsInGroupAsync(Config.Social.GroupId)
				end)
				if player.Parent == Players then
					inGroup[player] = ok and result == true
				end
			end)
		end
		if player:GetAttribute("DataReady") then
			claimDaily(player)
		else
			player:GetAttributeChangedSignal("DataReady"):Connect(function()
				claimDaily(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAttempt[player] = nil
		friends[player] = nil
		inGroup[player] = nil
		for _, list in friends do
			list[player.UserId] = nil
		end
	end)
end

return RewardsService
