--!strict
--[[
	Robux purchases (Config.Monetization). Nothing here trusts the client: the client may
	open Roblox's purchase prompt, but only Roblox's callbacks grant anything.

	VIP gamepass  - checked (UserOwnsGamePassAsync) on join and when a purchase finishes, never
	                taken from the purchase event alone (it can be faked); sets the player's "VIP"
	                attribute. Perks: speed (SprintService), VIP-only cosmetics (ShopService),
	                chat tag (client) and the King tracker below.
	Coin packs    - Developer Products granted in ProcessReceipt. Each receipt id is stored in
	                the player's save and the save must succeed before Roblox is told it was
	                granted, so a purchase is never lost or granted twice. While one receipt is
	                being handled, Roblox asking about the same one again gets "not yet". A
	                receipt that arrives as the player joins waits for their save to load
	                (Config.Monetization.ReceiptLoadWaitSeconds).
	Crates        - a Developer Product that is a crate's Robux.ProductId (Config.Crates) opens
	                that crate the same way: the receipt is checked first, then CrateService
	                rolls and gives the skin, and everything is undone if the save fails (Roblox
	                retries later with a new roll). The player's screen then plays the opening
	                (CrateResult). If crates aren't allowed for the player (their region, or
	                Config.Features.Crates / RobuxCrates switched off) they get the crate's coin
	                Price instead of a random skin (Config.Crates.RobuxFallbackCoins for a crate
	                with no Price).
	King tracker  - TrackKing() -> (direction, distance) of the nearest King, VIP only, for a
	                living player in the round, with a cooldown (attribute TrackerReadyAt).
	IDs of 0 mean "not created yet": nothing is checked or granted for them.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateOdds = require(ReplicatedStorage.Shared.CrateOdds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CrateService = require(script.Parent.CrateService)
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

local function rememberReceipt(data: { [string]: any }, receiptId: string)
	table.insert(data.Receipts, receiptId)
	while #data.Receipts > Config.Monetization.ReceiptHistory do
		table.remove(data.Receipts, 1)
	end
end

local function forgetReceipt(data: { [string]: any }, receiptId: string)
	local index = table.find(data.Receipts, receiptId)
	if index then
		table.remove(data.Receipts, index)
	end
end

-- Receipt ids being handled right now. Roblox may ask about the same purchase again while the
-- first answer is still saving; that second ask is told "not yet", so a purchase is never
-- reported as granted before its save has finished (the save could still fail and be undone).
local pending: { [string]: boolean } = {}

-- A crate bought with Robux (Config.Crates, Robux.ProductId).
local function processCrateReceipt(
	player: Player,
	data: { [string]: any },
	receiptId: string,
	crate: CrateOdds.Crate
): Enum.ProductPurchaseDecision
	-- May wait a little for the region check that starts when the player joins.
	local allowed = CrateService.CanOpenWithRobux(player, Config.Crates.Policy.WaitSeconds)
	if player.Parent ~= Players or DataService.Get(player) ~= data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- granted while we were waiting
	end

	local result: CrateService.Result? = nil
	local undo: () -> () = function() end
	if allowed then
		result, undo = CrateService.Grant(player, crate, "Robux")
	end
	local coins = 0
	if not result then
		-- No random skin for this player: the crate's coin price instead (or the fallback for
		-- a crate sold only for Robux). Never "grant" nothing for real Robux.
		coins = CrateOdds.CoinPrice(crate) or math.floor(Config.Crates.RobuxFallbackCoins)
		if not (coins > 0) then
			warn(
				"[MonetizationService] "
					.. crate.Id
					.. " has no coin Price and Config.Crates.RobuxFallbackCoins is 0, so a Robux purchase of it can't be given as coins; it stays unfinished until crates can be opened."
			)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		DataService.Add(player, "Coins", coins)
		result = {
			Ok = false,
			Message = Config.Crates.Text.RobuxInstead:format(coins, Config.Economy.CurrencyName),
			CrateId = crate.Id,
			Paid = "Robux",
		}
	end
	rememberReceipt(data, receiptId)
	if not DataService.Save(player) then
		-- Undo, so the retry Roblox will make doesn't double up.
		undo()
		if coins > 0 then
			DataService.Add(player, "Coins", -coins)
		end
		forgetReceipt(data, receiptId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ShopService.Push(player)
	if result then
		CrateService.SendResult(player, result)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- A coin pack (Config.Monetization.Products).
local function processCoinPack(
	player: Player,
	data: { [string]: any },
	receiptId: string,
	product: any
): Enum.ProductPurchaseDecision
	DataService.Add(player, "Coins", product.Coins)
	rememberReceipt(data, receiptId)
	if not DataService.Save(player) then
		-- Undo, so the retry Roblox will make doesn't double up.
		DataService.Add(player, "Coins", -product.Coins)
		forgetReceipt(data, receiptId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ShopService.Push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function handleReceipt(receipt: any, receiptId: string): Enum.ProductPurchaseDecision
	local crate = CrateOdds.ByProductId(receipt.ProductId)
	local product = if crate then nil else productById(receipt.ProductId)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not (crate or product) or not player then
		-- Unknown product, or the buyer left: Roblox retries next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Roblox often hands over an unfinished purchase as the player joins: let the save load.
	if not DataService.WaitForLoad(player, Config.Monetization.ReceiptLoadWaitSeconds) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if type(data.Receipts) ~= "table" then
		data.Receipts = {}
	end
	if table.find(data.Receipts, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (and saved) earlier
	end
	if crate then
		return processCrateReceipt(player, data, receiptId, crate)
	end
	return processCoinPack(player, data, receiptId, product)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local receiptId = tostring(receipt.PurchaseId)
	if pending[receiptId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- still being handled (see pending)
	end
	pending[receiptId] = true
	local ok, decision = pcall(handleReceipt, receipt, receiptId)
	pending[receiptId] = nil
	if not ok then
		warn("[MonetizationService] Receipt " .. receiptId .. " failed: " .. tostring(decision))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return decision
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
		-- An exploiter can fake this event with purchased = true, so ask Roblox whether they
		-- really own the pass (a pass bought in this server shows as owned straight away).
		if purchased and passId == Config.Monetization.VipGamePassId and passId ~= 0 then
			task.spawn(checkVip, player)
		end
	end)
	Remotes.Function("TrackKing").OnServerInvoke = onTrackKing

	Players.PlayerAdded:Connect(checkVip)
	for _, player in Players:GetPlayers() do
		task.spawn(checkVip, player)
	end
end

return MonetizationService
