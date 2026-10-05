--!strict
--[[
	Cosmetic shop (Config.Shop). Server-authoritative: the client only names an item; the
	server checks it exists, the price, the player's coins, ownership and VIP, then saves the
	result in DataService (Owned, Equipped) and dresses the character (shared Cosmetics).

	Client -> server:
	  GetShopState() -> State
	  BuyItem(itemId) -> (ok, message, State)
	  EquipItem(slot, itemId or "") -> State
	Server -> client: ShopState(State) whenever it changes for another reason (VIP, packs).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

export type State = {
	Ready: boolean,
	Coins: number,
	Owned: { string },
	Equipped: { [string]: string },
	Vip: boolean,
}

local ShopService = {}

local lastRequest: { [Player]: number } = {}
local lastState: { [Player]: { At: number, State: State } } = {}
local shopState: RemoteEvent

local function isVip(player: Player): boolean
	return player:GetAttribute("VIP") == true
end

-- Whether the player may wear `item` right now.
local function canUse(player: Player, item: any, data: { [string]: any }): boolean
	if item.VipOnly then
		return isVip(player)
	end
	return data.Owned[item.Id] == true
end

function ShopService.State(player: Player): State
	local data = DataService.Get(player)
	if not data then
		return { Ready = false, Coins = 0, Owned = {}, Equipped = {}, Vip = isVip(player) }
	end
	local owned = {}
	for id, has in data.Owned do
		if has then
			table.insert(owned, id)
		end
	end
	return {
		Ready = true,
		Coins = data.Coins or 0,
		Owned = owned,
		Equipped = table.clone(data.Equipped),
		Vip = isVip(player),
	}
end

-- Sends the player their current shop state (after VIP or coin purchases).
function ShopService.Push(player: Player)
	shopState:FireClient(player, ShopService.State(player))
end

-- Puts every equipped (and still allowed) cosmetic on the player's character.
function ShopService.Dress(player: Player)
	local character = player.Character
	local data = DataService.Get(player)
	if not character or not data then
		return
	end
	for _, slot in Config.Shop.Slots do
		local item = Cosmetics.Find(data.Equipped[slot])
		if item and item.Slot == slot and canUse(player, item, data) then
			Cosmetics.Wear(character, item)
		else
			Cosmetics.TakeOff(character, slot)
		end
	end
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Config.Shop.RequestCooldown then
		return true
	end
	lastRequest[player] = now
	return false
end

local function onBuy(player: Player, itemId: unknown): (boolean, string, State)
	if throttled(player) then
		return false, "Slow down!", ShopService.State(player)
	end
	local data = DataService.Get(player)
	local item = Cosmetics.Find(itemId)
	if not data or not item then
		return false, "That isn't for sale.", ShopService.State(player)
	end
	if item.VipOnly then
		return false,
			"This one comes with " .. Config.Monetization.VipName .. ".",
			ShopService.State(player)
	end
	if data.Owned[item.Id] then
		return false, "You already own it.", ShopService.State(player)
	end
	if not DataService.Spend(player, "Coins", item.Price) then
		return false,
			("You need %d more %s."):format(
				item.Price - (data.Coins or 0),
				Config.Economy.CurrencyName
			),
			ShopService.State(player)
	end
	data.Owned[item.Id] = true
	-- Wear new things straight away; that's what players expect after buying.
	data.Equipped[item.Slot] = item.Id
	ShopService.Dress(player)
	return true, "Bought " .. item.Name .. "!", ShopService.State(player)
end

local function onEquip(player: Player, slot: unknown, itemId: unknown): State
	if throttled(player) then
		return ShopService.State(player)
	end
	local data = DataService.Get(player)
	if not data or typeof(slot) ~= "string" or not table.find(Config.Shop.Slots, slot) then
		return ShopService.State(player)
	end
	if itemId == "" then
		data.Equipped[slot] = ""
	else
		local item = Cosmetics.Find(itemId)
		if not item or item.Slot ~= slot or not canUse(player, item, data) then
			return ShopService.State(player)
		end
		data.Equipped[slot] = item.Id
	end
	ShopService.Dress(player)
	return ShopService.State(player)
end

function ShopService.Start()
	shopState = Remotes.Event("ShopState")
	-- Cheap, but one client spamming it gets its last answer back instead of a new one.
	Remotes.Function("GetShopState").OnServerInvoke = function(player: Player): State
		local now = os.clock()
		local cached = lastState[player]
		if cached and now - cached.At < Config.Performance.ShopStateCooldown then
			return cached.State
		end
		local state = ShopService.State(player)
		lastState[player] = { At = now, State = state }
		return state
	end
	Remotes.Function("BuyItem").OnServerInvoke = onBuy
	Remotes.Function("EquipItem").OnServerInvoke = onEquip

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Wait for the body parts the cosmetics attach to.
			character:WaitForChild("Head", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			ShopService.Dress(player)
		end)
		-- Clothes and body colours can arrive after CharacterAdded and would cover a skin.
		player.CharacterAppearanceLoaded:Connect(function()
			ShopService.Dress(player)
		end)
		player:GetAttributeChangedSignal("DataReady"):Connect(function()
			ShopService.Dress(player)
			ShopService.Push(player)
		end)
		if player:GetAttribute("DataReady") then
			ShopService.Dress(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastState[player] = nil
	end)
end

return ShopService
