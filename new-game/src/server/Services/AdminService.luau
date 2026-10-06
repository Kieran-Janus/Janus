--!strict
--[[
	Owner-only test panel (client: src/client/AdminUI.luau, key Config.Admin.OpenKey).
	Made for trying out customisations fast: give yourself coins, unlock every cosmetic,
	reset your save, rebuild the hub after changing Config.Hub or custom NPC models, repaint
	the hub from Config.Hub.Palette, swap in your custom props (Apply custom props).

	Who is an admin:
	  - anyone in a Studio playtest (only you and your Team Create collaborators can be there)
	  - in live servers only if Config.Admin.AllowInLiveServers is true, and then only the
	    experience owner, the owning group's owner, or Config.Admin.UserIds
	Every command is checked here on the server; the client panel is only buttons.

	Adding a command (from any server service, at any time, e.g. in its Start()):
	  AdminService.Register("GiveEggs", "Find every egg", function(player, data)
	      ...                         -- data is the player's save (DataService.Get)
	      return "Done!"              -- shown under the buttons
	  end, danger?)                   -- danger = true: red button, needs a second click
	The panel asks the server for the list each time it opens (GetAdminCommands, admins only).

	"Reset my save" puts the save back to Config.Data.Template (purchase receipts are kept, so
	a Robux purchase is never given twice). A service that shows saved things on screen (e.g.
	Easter eggs found, parkour best) refreshes them with:
	  AdminService.OnSaveReset(function(player) ... end)

	Remotes: AdminCommand(name) -> (ok, message)
	         GetAdminCommands() -> { { Name, Label, Danger } }  (empty for non-admins)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HubService = require(script.Parent.HubService)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local Swap = require(script.Parent.Parent.Tools.Swap)

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
		-- Still works; the type checker flags it as deprecated (GroupService has a newer API),
		-- hence the cast. Swap it once the newer call is tested in a group-owned live game.
		return (player :: any):GetRankInGroupAsync(game.CreatorId)
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

export type CommandFn = (player: Player, data: { [string]: any }) -> string
export type CommandInfo = { Name: string, Label: string, Danger: boolean }

type Command = { Info: CommandInfo, Run: CommandFn }

local commands: { [string]: Command } = {}
local order: { string } = {} -- names, in the order the buttons are shown
local saveResetListeners: { (player: Player) -> () } = {}

--[[
	Adds a button to the admin panel. `name` must be unique (registering it again replaces
	it), `label` is the button text, `fn` runs on the server with the player's save and
	returns the message to show. danger = true makes it red and asks for a second click.
	Safe to call at any time; the panel picks new commands up the next time it opens.
]]
function AdminService.Register(name: string, label: string, fn: CommandFn, danger: boolean?)
	assert(type(name) == "string" and name ~= "", "AdminService.Register: name must be a string")
	assert(type(fn) == "function", "AdminService.Register: fn must be a function")
	if not commands[name] then
		table.insert(order, name)
	end
	commands[name] = {
		Info = { Name = name, Label = tostring(label), Danger = danger == true },
		Run = fn,
	}
end

-- Runs `fn(player)` after "Reset my save", so a service can show the fresh save straight away.
function AdminService.OnSaveReset(fn: (player: Player) -> ())
	assert(type(fn) == "function", "AdminService.OnSaveReset: fn must be a function")
	table.insert(saveResetListeners, fn)
end

AdminService.Register("AddCoins", "+ Coins", function(player, data)
	DataService.Add(player, "Coins", Config.Admin.CoinsPerClick)
	ShopService.Push(player)
	return ("+%d %s (now %d)"):format(
		Config.Admin.CoinsPerClick,
		Config.Economy.CurrencyName,
		data.Coins
	)
end)

AdminService.Register("UnlockAll", "Unlock all items", function(player, data)
	for _, item in Config.Shop.Items do
		data.Owned[item.Id] = true
	end
	ShopService.Push(player)
	return "Unlocked every shop item (VIP-only items still need VIP)."
end)

AdminService.Register("ResetDaily", "Reset daily reward", function(_player, data)
	data.Daily = { Streak = data.Daily and data.Daily.Streak or 0, Last = 0 }
	return "Daily reward reset: rejoin to claim it again."
end)

AdminService.Register("RebuildHub", "Rebuild hub", function(_player, _data)
	return HubService.Rebuild()
end)

AdminService.Register("RepaintHub", "Repaint hub", function(_player, _data)
	return HubService.Repaint()
end)

-- Swaps every prop in the lobby, the current map and the baked maps for your models in
-- ReplicatedStorage.Custom.Props (src/server/Tools/Swap.luau), for this playtest.
AdminService.Register("ApplyCustomProps", "Apply custom props", function(_player, _data)
	local _, message = Swap.Props()
	return message
end)

AdminService.Register("ResetSave", "Reset my save", function(player, data)
	-- Purchases already granted stay remembered, so Roblox can never grant one twice.
	local receipts = data.Receipts
	for key in data do
		data[key] = nil
	end
	for key, value in Config.Data.Template :: { [string]: any } do
		data[key] = deepCopy(value)
	end
	if type(receipts) == "table" then
		data.Receipts = receipts
	end
	DataService.Add(player, "Coins", 0) -- refresh leaderstats
	ShopService.Dress(player)
	ShopService.Push(player)
	for _, fn in saveResetListeners do
		-- (the cast: the old type checker misreads pcall of a function returning nothing)
		local ok, err = pcall(fn :: any, player)
		if not ok then
			warn("[AdminService] After Reset my save: " .. tostring(err))
		end
	end
	return "Your save is back to a brand new player (saved when you leave)."
end, true)

-- The button list for the client panel; empty for anyone who isn't an admin.
local function list(player: Player): { CommandInfo }
	if not player:GetAttribute("Admin") then
		return {}
	end
	local infos: { CommandInfo } = {}
	for _, name in order do
		local command = commands[name]
		if command then
			table.insert(infos, table.clone(command.Info))
		end
	end
	return infos
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
	local ok, result = pcall(command.Run, player, data)
	if not ok then
		warn("[AdminService] " .. tostring(result))
		return false, "That failed: " .. tostring(result)
	end
	return true, tostring(result)
end

function AdminService.Start()
	Remotes.Function("AdminCommand").OnServerInvoke = run
	Remotes.Function("GetAdminCommands").OnServerInvoke = list
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
