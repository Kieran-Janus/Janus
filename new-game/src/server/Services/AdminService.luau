--!strict
--[[
	Owner-only test panel (client: src/client/AdminUI.luau, key Config.Admin.OpenKey).
	Made for trying out customisations fast: give yourself coins, unlock every cosmetic,
	reset your save, rebuild the hub after changing Config.Hub or custom NPC models.

	Who is an admin:
	  - anyone in a Studio playtest (only you and your Team Create collaborators can be there)
	  - in live servers only if Config.Admin.AllowInLiveServers is true, and then only the
	    experience owner, the owning group's owner, or Config.Admin.UserIds
	Every command is checked here on the server; the client panel is only buttons.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local AdminService = {}

local lastCommand: { [Player]: number } = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local cfg = Config.Admin
	if not cfg.AllowInLiveServers then
		return false
	end
	if table.find(cfg.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroupAsync(game.CreatorId)
	end)
	return ok and rank == 255
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

local commands: { [string]: (Player, { [string]: any }) -> string } = {}

function commands.AddCoins(player, data)
	DataService.Add(player, "Coins", Config.Admin.CoinsPerClick)
	ShopService.Push(player)
	return ("+%d %s (now %d)"):format(
		Config.Admin.CoinsPerClick,
		Config.Economy.CurrencyName,
		data.Coins
	)
end

function commands.UnlockAll(player, data)
	for _, item in Config.Shop.Items do
		data.Owned[item.Id] = true
	end
	ShopService.Push(player)
	return "Unlocked every shop item (VIP-only items still need VIP)."
end

function commands.ResetSave(player, data)
	for key in data do
		data[key] = nil
	end
	for key, value in Config.Data.Template :: { [string]: any } do
		data[key] = deepCopy(value)
	end
	DataService.Add(player, "Coins", 0) -- refresh leaderstats
	ShopService.Dress(player)
	ShopService.Push(player)
	return "Your save is back to a brand new player (saved when you leave)."
end

function commands.ResetDaily(_player, data)
	data.Daily = { Streak = data.Daily and data.Daily.Streak or 0, Last = 0 }
	return "Daily reward reset: rejoin to claim it again."
end

function commands.RebuildHub(_player, _data)
	local hub = HubBuilder.Build()
	HubBuilder.RemoveLoosePieces(hub)
	return "Hub rebuilt from Config.Hub and custom models (this playtest only)."
end

local function run(player: Player, name: unknown): (boolean, string)
	-- "Admin" is set by this server on join (clients can't set attributes that replicate).
	if not player:GetAttribute("Admin") then
		return false, "Not allowed."
	end
	local now = os.clock()
	if now - (lastCommand[player] or 0) < 0.3 then
		return false, "Slow down."
	end
	lastCommand[player] = now
	local command = if typeof(name) == "string" then commands[name] else nil
	if not command then
		return false, "Unknown command."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Your save hasn't loaded yet."
	end
	local ok, result = pcall(command, player, data)
	if not ok then
		warn("[AdminService] " .. tostring(result))
		return false, "That failed: " .. tostring(result)
	end
	return true, result
end

function AdminService.Start()
	Remotes.Function("AdminCommand").OnServerInvoke = run
	local function onPlayer(player: Player)
		if isAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
end

return AdminService
