--!strict
--[[
	Robux purchases (Config.Monetization). Nothing here trusts the client: the client may
	open Roblox's purchase prompt, but only Roblox's callbacks grant anything.

	VIP gamepass  - checked on join and when a purchase finishes; sets the player's "VIP"
	                attribute. Perks: speed (SprintService), VIP-only cosmetics (ShopService),
	                chat tag (client) and the King tracker below.
	Coin packs    - Developer Products granted in ProcessReceipt. Each receipt id is stored in
	                the player's save and the save must succeed before Roblox is told it was
	                granted, so a purchase is never lost or granted twice.
	King tracker  - TrackKing() -> (direction, distance) of the nearest King, VIP only, for a
	                living player in the round, with a cooldown (attribute TrackerReadyAt).
	IDs of 0 mean "not created yet": nothing is checked or granted for them.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local KingService = require(script.Parent.KingService)
local ShopService = require(script.Parent.ShopService)
local SprintService = require(script.Parent.SprintService)

local MonetizationService = {}

local function setVip(player: Player)
	if player:GetAttribute("VIP") then
		return
	end
	player:SetAttribute("VIP", true)
	SprintService.Apply(player)
	ShopService.Dress(player)
	ShopService.Push(player)
end

local function checkVip(player: Player)
	local id = Config.Monetization.VipGamePassId
	if id == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns then
		setVip(player)
	elseif not ok then
		warn("[MonetizationService] VIP check failed for " .. player.Name .. ": " .. tostring(owns))
	end
end

local function productById(id: number): any
	if id == 0 then
		return nil
	end
	for _, product in Config.Monetization.Products do
		if product.Id == id then
			return product
		end
	end
	return nil
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local product = productById(receipt.ProductId)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not product or not player then
		-- Unknown product, or the buyer left: Roblox retries next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data or not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted earlier
	end

	DataService.Add(player, "Coins", product.Coins)
	table.insert(data.Receipts, receiptId)
	while #data.Receipts > Config.Monetization.ReceiptHistory do
		table.remove(data.Receipts, 1)
	end
	if not DataService.Save(player) then
		-- Undo, so the retry Roblox will make doesn't double up.
		DataService.Add(player, "Coins", -product.Coins)
		local index = table.find(data.Receipts, receiptId)
		if index then
			table.remove(data.Receipts, index)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ShopService.Push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onTrackKing(player: Player): (Vector3?, number?)
	local cfg = Config.Monetization.Tracker
	if
		not player:GetAttribute("VIP")
		or not player:GetAttribute("InRound")
		or player:GetAttribute("Out")
	then
		return nil, nil
	end
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("TrackerReadyAt") or 0) then
		return nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local king = root and KingService.Nearest(root.Position)
	if not root or not king then
		return nil, nil -- no cooldown spent when there's nothing to point at
	end
	player:SetAttribute("TrackerReadyAt", now + cfg.Cooldown)
	local offset = Vector3.new(king.X - root.Position.X, 0, king.Z - root.Position.Z)
	if offset.Magnitude < 0.01 then
		return Vector3.zero, 0
	end
	return offset.Unit, offset.Magnitude
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Monetization.VipGamePassId and passId ~= 0 then
			setVip(player)
		end
	end)
	Remotes.Function("TrackKing").OnServerInvoke = onTrackKing

	Players.PlayerAdded:Connect(checkVip)
	for _, player in Players:GetPlayers() do
		task.spawn(checkVip, player)
	end
end

return MonetizationService
