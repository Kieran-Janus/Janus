--!strict
--[[
	Mystery crates (Config.Crates). Everything that matters happens here on the server: the
	price is taken, the skin is rolled (CrateOdds, with this server's own Random) and given
	through DataService before the client's opening animation even starts. A skin you already
	own gives coins back instead (Config.Rarity, DuplicateRefund).
	On/off: Config.Features.Crates (off = nothing opens and the stand's prompts are switched off).

	Roblox's paid random items rule: on join each player's PolicyService info is checked; while
	ArePaidRandomItemsRestricted is true (or Roblox can't tell us) they can't open any crate.
	The player attribute CratesRestricted (true / false; missing = still checking) tells the
	crate panel to hide its buy buttons.

	LUCK, PACKS AND DELUXE CRATES (docs/CRATE-LUCK-SPEC.md). Each themed crate has a luck meter
	per player (src/shared/CrateLuck.luau, saved in data.Crates.Luck): every roll reads the
	saved level, rolls with CrateLuck.Boost (the same maths the crate page shows) and moves the
	meter. The client sends the level (and pack guarantee) it showed; if that isn't what the
	server has, nothing is bought and the answer says OddsChanged with the real Luck, so a
	player always buys with the chances they saw. x5 / x10 open crate by crate; the last one
	gets the pack guarantee (Config.Crates.Open.Guarantee) if the others missed it.

	Client -> server:
	  OpenCrate(crateId, count, shownLuck, shownGuarantee?) -> Result
	                                      opens `count` crates (one of Config.Crates.Open.Counts;
	                                      nil counts as 1) for count x its coin Price, taken in
	                                      one go. shownLuck = the luck level the page showed (0
	                                      for a crate without a meter); shownGuarantee = the
	                                      pack guarantee the pack window showed (nil for x1).
	                                      Result.Results lists every result when count > 1
	                                      (Result itself is a copy of the first).
	  PrepareCrateRobux(crateId, shownLuck) -> { Ok, Message, CrateId, Luck?, LuckVersion }
	                                      before the Roblox purchase window: checks the luck
	                                      shown, then HOLDS that crate (coin opens of it say
	                                      RobuxFirst) until the purchase is cancelled, its
	                                      receipt has been handled, Config.Crates.RobuxOpen
	                                      HoldSeconds pass (window still open) or MaxHoldSeconds
	                                      pass (bought, receipt not here yet). Its own cooldown
	                                      (RobuxOpen.Cooldown), not OpenCrate's. While a receipt
	                                      is being handled, the crates that can give the same
	                                      skins (its Deluxe crate, the rarity crates) say
	                                      RobuxFirst too, so a failed save's undo can't take
	                                      back a skin a coin open counted as a duplicate.
	Server -> client:
	  CrateResult(Result)                 a crate opened some other way (Robux purchase, F8
	                                      free crate), or a Robux crate that didn't open yet
	                                      (Ok = false, RobuxLater): the panel plays / shows it
	Result = { Ok, Message, CrateId, ItemId?, ItemName?, Rarity?, Duplicate?, Refund?, Reel?,
	           WinIndex?, Paid?, OneInAMillion?, Results?,
	           Luck? (the level this crate rolled at; on a refusal the current level),
	           LuckAfter? (the level after it; for a pack, after the last crate),
	           Guaranteed? (the AtLeast rarity used: pack guarantee or full meter),
	           LuckVersion (ShopService.LuckVersion after this result; on every result) }
	(Reel: item ids for the spinning strip, Reel[WinIndex] = ItemId.)
	A CRAZY skin unboxed any way is announced to the whole server (AnnounceService; "Huge" for a
	ONE IN A MILLION skin) while Config.Crates.AnnounceCrazy is on.

	Robux crates: MonetizationService's ProcessReceipt calls ReceiptStarted, then
	CrateService.Grant for products that are a crate's Robux.ProductId (and undoes it if the
	save fails), then ReceiptFinished (always, whatever happened).

	CrateService.Grant(player, crate, paid, atLeast?) -> (Result?, undo)  roll and give (no
	                                                            payment); undo also puts the
	                                                            luck back
	CrateService.Luck(player, crateId) -> number                the player's luck level now
	CrateService.IsRestricted(player, waitSeconds?) -> boolean  true while crates are closed
	                                                            for this player
	CrateService.CanOpenWithRobux(player, waitSeconds?, crate?) -> boolean
	CrateService.ReceiptStarted(player, crate)                  a crate receipt is being handled
	CrateService.ReceiptFinished(player, crate, granted)        ...and is done (granted = false:
	                                                            sends RobuxLater)
	CrateService.SendResult(player, result)
	CrateService.EnsurePrompt(instance) -> ProximityPrompt?     for parts tagged CrateDisplay
	F8 (Studio only, while Features.CrateLuck is on): CrateLuckUp, CrateLuckQuiet (changes the
	luck without telling the screen, to test the odds check), CrateLuckReset.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateArt = require(ReplicatedStorage.Shared.CrateArt)
local CrateLuck = require(ReplicatedStorage.Shared.CrateLuck)
local CrateOdds = require(ReplicatedStorage.Shared.CrateOdds)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

export type Result = {
	Ok: boolean,
	Message: string,
	CrateId: string,
	ItemId: string?,
	ItemName: string?,
	Rarity: string?,
	Duplicate: boolean?,
	Refund: number?,
	Reel: { string }?,
	WinIndex: number?,
	Paid: string?, -- "Coins", "Robux" or "Free"
	OneInAMillion: boolean?,
	Results: { Result }?, -- every result, when several crates were opened at once
	Luck: number?, -- the luck level this crate rolled at (on a refusal: the current level)
	LuckAfter: number?, -- the level after it (a pack: after the last crate)
	Guaranteed: string?, -- the AtLeast rarity this roll used (pack guarantee or full meter)
	LuckVersion: number?, -- ShopService.LuckVersion after this result (always set)
}

-- What PrepareCrateRobux answers.
export type Prepared = {
	Ok: boolean,
	Message: string,
	CrateId: string,
	Luck: number?,
	LuckVersion: number,
}

-- A Robux purchase window opened after PrepareCrateRobux (see RobuxOpen in Config.Crates).
type Hold = { Until: number, Bought: boolean }

local CrateService = {}

local rng = Random.new()
local lastOpen: { [Player]: number } = {}
local lastPrepare: { [Player]: number } = {} -- PrepareCrateRobux's own cooldown
-- true = crates closed for this player, false = allowed, nil = still asking Roblox
local restricted: { [Player]: boolean } = {}
-- Robux holds: [player][crateId]. prepared = a purchase window opened (timed); receiving =
-- how many receipts of that crate are being handled right now.
local prepared: { [Player]: { [string]: Hold } } = {}
local receiving: { [Player]: { [string]: number } } = {}
local resultEvent: RemoteEvent? = nil
local started = false

local function text()
	return Config.Crates.Text
end

local function fail(crateId: string, message: string): Result
	return { Ok = false, Message = message, CrateId = crateId }
end

-- A refusal, with the player's luck version (and their level for `crate`, when known).
local function refuse(
	player: Player,
	crateId: string,
	message: string,
	data: { [string]: any }?,
	crate: CrateOdds.Crate?
): Result
	local result = fail(crateId, message)
	if data and crate then
		result.Luck = CrateLuck.Get(data, crate)
	end
	result.LuckVersion = ShopService.LuckVersion(player)
	return result
end

local function noUndo() end

-- Policy ---------------------------------------------------------------------------------

-- Asks Roblox whether paid random items are allowed for this player. Returns true/false, or
-- nil when every attempt failed.
local function askPolicy(player: Player): boolean?
	local cfg = Config.Crates.Policy
	for attempt = 1, math.max(1, cfg.Attempts) do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			return info.ArePaidRandomItemsRestricted == true
		end
		if attempt < cfg.Attempts then
			task.wait(cfg.RetrySeconds)
		end
		if player.Parent ~= Players then
			return nil
		end
	end
	return nil
end

local function checkPolicy(player: Player)
	local answer = askPolicy(player)
	if player.Parent ~= Players then
		return
	end
	local closed: boolean
	if answer == nil then
		if RunService:IsStudio() then
			-- Studio test players aren't real accounts and nobody pays here: keep crates open.
			warn(
				"[CrateService] PolicyService didn't answer for "
					.. player.Name
					.. "; crates stay open in Studio only."
			)
			closed = false
		else
			closed = true -- the rule: when in doubt, no paid random items
		end
	else
		closed = answer
	end
	if Config.Crates.Policy.TestAsRestricted and RunService:IsStudio() then
		closed = true
	end
	restricted[player] = closed
	player:SetAttribute("CratesRestricted", closed)
end

function CrateService.IsRestricted(player: Player, waitSeconds: number?): boolean
	local deadline = os.clock() + (waitSeconds or 0)
	while restricted[player] == nil and os.clock() < deadline and player.Parent == Players do
		task.wait(0.2)
	end
	return restricted[player] ~= false
end

function CrateService.CanOpenWithRobux(
	player: Player,
	waitSeconds: number?,
	crate: CrateOdds.Crate?
): boolean
	if not (Config.Features.Crates and Config.Features.RobuxCrates) then
		return false
	end
	-- A crate that isn't in the game right now (its theme is switched off in
	-- Config/Skins/InGame.luau, or a Deluxe crate while PremiumCrates is off): the buyer gets its
	-- coins instead. (CrateOdds.Get only finds crates that are in the game.)
	if crate and CrateOdds.Get(crate.Id) ~= crate then
		return false
	end
	return not CrateService.IsRestricted(player, waitSeconds)
end

-- Robux holds ------------------------------------------------------------------------------

-- Can two crates give some of the same skins? A Deluxe crate gives its Base crate's skins, and
-- a rarity crate gives skins from every themed crate.
local function sameSkins(a: CrateOdds.Crate, b: CrateOdds.Crate): boolean
	if a.Rarity ~= nil or b.Rarity ~= nil then
		return true
	end
	return (a.Base or a.Id) == (b.Base or b.Id)
end

-- Is a Robux purchase on its way for this player that a coin open of `crate` must wait for?
--   * A purchase window opened for this crate (PrepareCrateRobux) holds this crate only, so the
--     Robux crate rolls with the luck the player saw.
--   * A receipt being handled also holds every crate that can give the same skins (its Deluxe
--     crate, the rarity crates): if its save fails, the undo takes its skin back, and a coin
--     open in between that got that skin as a duplicate would lose it too.
local function holding(player: Player, crate: CrateOdds.Crate): boolean
	local counts = receiving[player]
	if counts then
		for id, count in counts do
			local other = if id == crate.Id then crate else CrateOdds.Get(id)
			if count > 0 and other and sameSkins(crate, other) then
				return true
			end
		end
	end
	local holds = prepared[player]
	local hold = holds and holds[crate.Id]
	if holds and hold then
		if os.clock() < hold.Until then
			return true
		end
		holds[crate.Id] = nil
	end
	return false
end

-- A bought purchase still waiting for its receipt (or one being handled).
local function bought(player: Player, crateId: string): boolean
	local counts = receiving[player]
	if counts and (counts[crateId] or 0) > 0 then
		return true
	end
	local holds = prepared[player]
	local hold = holds and holds[crateId]
	return hold ~= nil and hold.Bought and os.clock() < hold.Until
end

local function release(player: Player, crateId: string)
	local holds = prepared[player]
	if holds then
		holds[crateId] = nil
	end
end

function CrateService.ReceiptStarted(player: Player, crate: CrateOdds.Crate)
	if player.Parent ~= Players then
		return
	end
	local counts = receiving[player]
	if not counts then
		counts = {}
		receiving[player] = counts
	end
	counts[crate.Id] = (counts[crate.Id] or 0) + 1
end

-- Every ReceiptStarted ends with this, whatever happened. granted = false (the save failed,
-- the save wasn't loaded, an error...): the hold ends and the player is told Roblox will give
-- the crate again later, so the crate isn't stuck saying "still on its way".
function CrateService.ReceiptFinished(player: Player, crate: CrateOdds.Crate, granted: boolean)
	local counts = receiving[player]
	if counts then
		local left = math.max(0, (counts[crate.Id] or 0) - 1)
		if left > 0 then
			counts[crate.Id] = left
		else
			counts[crate.Id] = nil
		end
	end
	release(player, crate.Id)
	if not granted and player.Parent == Players then
		local data = DataService.Get(player)
		local result = refuse(player, crate.Id, text().RobuxLater, data, crate)
		result.Paid = "Robux"
		CrateService.SendResult(player, result)
	end
end

-- MarketplaceService.PromptProductPurchaseFinished (server side): the window closed.
local function onPurchaseFinished(userId: number, productId: number, purchased: boolean)
	local player = Players:GetPlayerByUserId(userId)
	local crate = CrateOdds.ByProductId(productId)
	if not player or not crate then
		return
	end
	local holds = prepared[player]
	local hold = holds and holds[crate.Id]
	if not holds or not hold then
		return -- (e.g. its receipt was already handled)
	end
	if purchased then
		-- Lasts until the receipt has been handled, with a safety limit.
		hold.Bought = true
		hold.Until = os.clock() + Config.Crates.RobuxOpen.MaxHoldSeconds
	else
		holds[crate.Id] = nil
	end
end

-- Rolling and giving ----------------------------------------------------------------------

--[[
	Rolls `crate` and gives the player the skin, or its duplicate refund if they own it
	already. Takes no payment (the caller did). The roll uses the player's saved luck level
	for this crate (CrateLuck) and `atLeast` (a pack guarantee: only that rarity or better),
	with exactly the chances the crate page shows for that level, then moves the meter.
	Returns the Result for the client and a function that takes it all back (for a Robux
	purchase whose save failed), luck included; nil if the player's data isn't there or the
	crate is empty.
]]
function CrateService.Grant(
	player: Player,
	crate: CrateOdds.Crate,
	paid: string,
	atLeast: string?
): (Result?, () -> ())
	local data = DataService.Get(player)
	if not data then
		return nil, noUndo
	end
	-- (with CrateLuck off, or a crate without a meter, the saved level isn't read or written)
	local applies = CrateLuck.Applies(crate)
	local level = if applies then CrateLuck.Get(data, crate) else 0
	local boost = CrateLuck.Boost(crate, level, atLeast)
	local item = CrateOdds.Pick(CrateOdds.Chances(crate, boost), rng:NextNumber())
	if not item then
		return nil, noUndo
	end
	local rarity = Items.Rarity(item)
	local owned = data.Owned
	local duplicate = owned[item.Id] == true
	local refund = 0
	if duplicate then
		refund = math.max(0, math.floor(Items.RarityInfo(item).DuplicateRefund or 0))
		if refund > 0 then
			DataService.Add(player, "Coins", refund)
		end
	else
		owned[item.Id] = true
	end
	if type(data.Crates) ~= "table" then
		data.Crates = { Opened = 0, Luck = {} }
	end
	local stats = data.Crates
	stats.Opened = (tonumber(stats.Opened) or 0) + 1
	local after = level
	if applies then
		after = CrateLuck.After(crate, level, rarity)
		CrateLuck.Set(data, crate, after)
		ShopService.LuckChanged(player)
	end

	local reel = Config.Crates.Reel
	local winIndex = math.clamp(math.floor(reel.WinIndex), 1, math.max(1, math.floor(reel.Cards)))
	local result: Result = {
		Ok = true,
		Message = "",
		CrateId = crate.Id,
		ItemId = item.Id,
		ItemName = item.Name,
		Rarity = rarity,
		Duplicate = duplicate,
		Refund = refund,
		Reel = CrateOdds.Reel(crate, item.Id, rng, reel.Cards, winIndex, boost),
		WinIndex = winIndex,
		Paid = paid,
		OneInAMillion = if item.OneInAMillion then true else nil,
		Luck = if applies then level else nil,
		LuckAfter = if applies then after else nil,
		Guaranteed = if boost then boost.AtLeast else nil,
		LuckVersion = ShopService.LuckVersion(player),
	}
	-- A CRAZY skin: the whole server hears about it (extra big for a one-in-a-million one), once
	-- the winner's own reveal has played, so the banner doesn't spoil it.
	if rarity == "Crazy" and Config.Crates.AnnounceCrazy then
		local t = text()
		local words = if item.OneInAMillion then t.AnnounceMillion else t.AnnounceCrazy
		task.delay(
			math.max(0, Config.Crates.AnnounceDelay),
			AnnounceService.All,
			words:format(player.DisplayName, item.Name),
			if item.OneInAMillion then "Huge" else "Big"
		)
	end
	local function undo()
		if duplicate then
			if refund > 0 then
				DataService.Add(player, "Coins", -math.min(refund, data.Coins or 0))
			end
		else
			owned[item.Id] = nil
		end
		stats.Opened = math.max(0, (tonumber(stats.Opened) or 1) - 1)
		-- The luck goes back exactly (unless something else changed it since).
		if applies and CrateLuck.Applies(crate) and CrateLuck.Get(data, crate) == after then
			CrateLuck.Set(data, crate, level)
			ShopService.LuckChanged(player)
		end
	end
	return result, undo
end

-- The player's luck level for a crate right now (0 if unknown or without a meter).
function CrateService.Luck(player: Player, crateId: string): number
	local data = DataService.Get(player)
	local crate = CrateOdds.Get(crateId)
	if not data or not crate then
		return 0
	end
	return CrateLuck.Get(data, crate)
end

function CrateService.SendResult(player: Player, result: Result)
	if resultEvent and player.Parent == Players then
		resultEvent:FireClient(player, result)
	end
end

local function saveIfRare(player: Player, result: Result)
	if result.Rarity and Config.Crates.SaveRightAway[result.Rarity] then
		task.spawn(DataService.Save, player)
	end
end

local function onOpen(
	player: Player,
	crateId: unknown,
	countIn: unknown,
	shownLuck: unknown,
	shownGuarantee: unknown
): Result
	local t = text()
	local id = if typeof(crateId) == "string" and #crateId <= 64 then crateId else ""
	if not Config.Features.Crates then
		return refuse(player, id, t.Closed)
	end
	-- How many at once: only the counts the crate page offers (x1, x5, x10).
	local count = 1
	if countIn ~= nil then
		if typeof(countIn) ~= "number" or not table.find(Config.Crates.Open.Counts, countIn) then
			return refuse(player, id, t.NoCrate)
		end
		count = countIn :: number
	end
	local now = os.clock()
	if now - (lastOpen[player] or -math.huge) < Config.Crates.RequestCooldown then
		return refuse(player, id, t.SlowDown)
	end
	lastOpen[player] = now
	local crate = CrateOdds.Get(id)
	local price = if crate then CrateOdds.CoinPrice(crate) else nil
	if not crate or not price or #CrateOdds.Items(crate) == 0 then
		return refuse(player, id, t.NoCrate)
	end
	local closed = restricted[player]
	if closed == nil then
		return refuse(player, id, t.StillChecking)
	elseif closed then
		return refuse(player, id, t.Restricted)
	end
	local data = DataService.Get(player)
	if not data then
		return refuse(player, id, t.NotLoaded)
	end
	-- A Robux purchase of this crate is on its way: it rolls with the luck the player saw.
	if holding(player, crate) then
		return refuse(player, id, t.RobuxFirst, data, crate)
	end
	-- The chances the player saw must be the ones the server has (never used to roll: the
	-- server only compares). Crates without a meter expect 0; x1 expects no guarantee.
	local level = CrateLuck.Get(data, crate)
	local guarantee = CrateLuck.Guarantee(crate, count)
	local luckOk = typeof(shownLuck) == "number" and shownLuck == level
	local guaranteeOk = (shownGuarantee == nil or typeof(shownGuarantee) == "string")
		and shownGuarantee == guarantee
	if not (luckOk and guaranteeOk) then
		return refuse(player, id, t.OddsChanged, data, crate)
	end
	local total = price * count
	if not DataService.Spend(player, "Coins", total) then
		return refuse(
			player,
			id,
			t.NoCoins:format(total - (data.Coins or 0), Config.Economy.CurrencyName),
			data,
			crate
		)
	end
	-- One crate after another, exactly like single opens (each reads the level the previous
	-- one left). The last one gets the pack guarantee if none before it reached it.
	local results: { Result } = {}
	local met = false
	for k = 1, count do
		local atLeast = if guarantee and k == count and not met then guarantee else nil
		local result = CrateService.Grant(player, crate, "Coins", atLeast)
		if not result then
			break
		end
		table.insert(results, result)
		if
			guarantee
			and CrateOdds.RarityIndex(result.Rarity) >= CrateOdds.RarityIndex(guarantee)
		then
			met = true
		end
	end
	if #results < count then
		-- Some weren't given (an empty crate): give their coins back.
		DataService.Add(player, "Coins", price * (count - #results))
	end
	local first = results[1]
	if not first then
		return refuse(player, id, t.NoCrate, data, crate)
	end
	-- One save for the batch if anything in it was Rare or better.
	for _, result in results do
		if result.Rarity and Config.Crates.SaveRightAway[result.Rarity] then
			saveIfRare(player, result)
			break
		end
	end
	ShopService.Push(player)
	if count > 1 then
		-- (A copy of the first: a table that contains itself can't be sent to the client.)
		local batch = table.clone(first)
		batch.Results = results
		batch.LuckAfter = results[#results].LuckAfter
		batch.LuckVersion = ShopService.LuckVersion(player)
		return batch
	end
	return first
end

-- Robux: checks the luck shown before Roblox's purchase window opens, then holds the crate.
local function onPrepare(player: Player, crateId: unknown, shownLuck: unknown): Prepared
	local t = text()
	local id = if typeof(crateId) == "string" and #crateId <= 64 then crateId else ""
	local function answer(ok: boolean, message: string, luck: number?): Prepared
		return {
			Ok = ok,
			Message = message,
			CrateId = id,
			Luck = luck,
			LuckVersion = ShopService.LuckVersion(player),
		}
	end
	if id == "" then
		return answer(false, t.NoCrate)
	end
	if not (Config.Features.Crates and Config.Features.RobuxCrates) then
		return answer(false, t.Closed)
	end
	local now = os.clock()
	if now - (lastPrepare[player] or -math.huge) < Config.Crates.RobuxOpen.Cooldown then
		return answer(false, t.SlowDown)
	end
	lastPrepare[player] = now
	local crate = CrateOdds.Get(id)
	if not crate or CrateOdds.ProductId(crate) == 0 or #CrateOdds.Items(crate) == 0 then
		return answer(false, t.NoCrate)
	end
	local closed = restricted[player]
	if closed == nil then
		return answer(false, t.StillChecking)
	elseif closed then
		return answer(false, t.Restricted)
	end
	local data = DataService.Get(player)
	if not data then
		return answer(false, t.NotLoaded)
	end
	local level = CrateLuck.Get(data, crate)
	if bought(player, crate.Id) then
		return answer(false, t.RobuxFirst, level)
	end
	if typeof(shownLuck) ~= "number" or shownLuck ~= level then
		return answer(false, t.OddsChanged, level)
	end
	local holds = prepared[player]
	if not holds then
		holds = {}
		prepared[player] = holds
	end
	holds[crate.Id] = { Until = now + Config.Crates.RobuxOpen.HoldSeconds, Bought = false }
	return answer(true, "", level)
end

-- The crate stand -------------------------------------------------------------------------

local function promptHolder(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Makes sure a part or model tagged CrateDisplay has an "Open <crate>" prompt.
function CrateService.EnsurePrompt(instance: Instance): ProximityPrompt?
	local crate = CrateOdds.Get(instance:GetAttribute("CrateId"))
	if not crate then
		warn(
			("[CrateService] %s is tagged %s but its CrateId attribute isn't a crate in Config.Crates.List"):format(
				instance:GetFullName(),
				Tags.CrateDisplay
			)
		)
		return nil
	end
	for _, d in instance:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:SetAttribute("CrateId", crate.Id)
			d.Enabled = true
			return d
		end
	end
	local holder = promptHolder(instance)
	return if holder then CrateArt.AddPrompt(holder, crate) else nil
end

local function disablePrompts()
	for _, instance in CollectionService:GetTagged(Tags.CrateDisplay) do
		for _, d in instance:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d.Enabled = false
			end
		end
	end
end

-- Admin (F8) ------------------------------------------------------------------------------

local function freeCrate(): CrateOdds.Crate?
	return CrateOdds.Get(Config.Crates.Admin.FreeCrate) or CrateOdds.List()[1]
end

local function shortNumber(n: number): string
	if n >= 1000 and n % 1000 == 0 then
		return ("%dk"):format(n // 1000)
	end
	return tostring(n)
end

-- The rarity crate of the rainbow rarity (CRAZY), for testing its opening in Studio.
local function crazyCrate(): CrateOdds.Crate?
	for _, crate in CrateOdds.List() do
		local level = crate.Rarity and (Config.Rarity.Levels :: any)[crate.Rarity]
		if level and level.Rainbow == true then
			return crate
		end
	end
	return nil
end

-- Opens `which` for nothing and plays it on the player's screen (F8 test buttons).
local function openFree(player: Player, which: CrateOdds.Crate?): string
	if not which then
		return "There are no crates in Config.Crates.List."
	end
	if CrateService.IsRestricted(player) then
		return text().Restricted
	end
	local result = CrateService.Grant(player, which, "Free")
	if not result then
		return "That crate is empty."
	end
	saveIfRare(player, result)
	ShopService.Push(player)
	CrateService.SendResult(player, result)
	return ("Free %s: %s (%s)%s"):format(
		which.Name,
		tostring(result.ItemName),
		tostring(result.Rarity),
		if result.Duplicate then (", duplicate +%d"):format(result.Refund or 0) else ""
	)
end

-- Adds `steps` to the player's luck on the F8 free crate (Studio test buttons).
local function addLuck(
	player: Player,
	data: { [string]: any },
	steps: number,
	tell: boolean
): string
	if not RunService:IsStudio() then
		return "Studio only."
	end
	local crate = freeCrate()
	if not crate or not CrateLuck.Applies(crate) then
		return "That crate has no luck meter right now (Config.Features.CrateLuck, Config.Crates.Luck)."
	end
	local level = math.min(CrateLuck.Get(data, crate) + steps, CrateLuck.Steps())
	CrateLuck.Set(data, crate, level)
	ShopService.LuckChanged(player)
	if tell then
		ShopService.Push(player)
	end
	return ("%s luck: %d / %d"):format(crate.Name, level, CrateLuck.Steps())
end

-- Studio only: the luck meter's test buttons (docs/CRATE-LUCK-SPEC.md, Studio test list).
local function registerLuckAdmin(crate: CrateOdds.Crate?)
	local name = if crate then crate.Name else "crate"
	local steps = math.max(1, math.floor(Config.Crates.Admin.LuckSteps))
	AdminService.Register(
		"CrateLuckUp",
		("Crates: +%d luck on %s"):format(steps, name),
		function(player, data)
			return addLuck(player, data, steps, true)
		end
	)
	-- Changes the luck without telling the screen: the crate page keeps its old chances, so
	-- pressing Open there shows the odds check (nothing is bought, the page redraws).
	AdminService.Register(
		"CrateLuckQuiet",
		("Crates: +1 luck on %s, screen not told (tests the odds check)"):format(name),
		function(player, data)
			return addLuck(player, data, 1, false)
		end
	)
	AdminService.Register("CrateLuckReset", "Crates: reset my luck", function(player, data)
		if not RunService:IsStudio() then
			return "Studio only."
		end
		if type(data.Crates) ~= "table" then
			data.Crates = { Opened = 0, Luck = {} }
		end
		data.Crates.Luck = {}
		ShopService.LuckChanged(player)
		ShopService.Push(player)
		return "Every crate's luck is back to 0."
	end)
end

local function registerAdmin()
	local crate = freeCrate()
	AdminService.Register(
		"CrateFree",
		("Crates: open free %s"):format(if crate then crate.Name else "crate"),
		function(player, _data)
			return openFree(player, freeCrate())
		end
	)
	-- Studio only: the CRAZY opening (rainbow beam, confetti) without 80,000 coins.
	local crazy = crazyCrate()
	if crazy and RunService:IsStudio() then
		AdminService.Register(
			"CrateFreeCrazy",
			("Crates: open free %s"):format(crazy.Name),
			function(player, _data)
				if not RunService:IsStudio() then
					return "Studio only."
				end
				return openFree(player, crazyCrate())
			end
		)
	end
	local coins = Config.Crates.Admin.Coins
	AdminService.Register(
		"CrateCoins",
		("Crates: +%s %s"):format(shortNumber(coins), Config.Economy.CurrencyName:lower()),
		function(player, data)
			DataService.Add(player, "Coins", coins)
			ShopService.Push(player)
			return ("+%d %s (now %d)"):format(coins, Config.Economy.CurrencyName, data.Coins or 0)
		end
	)
	if Config.Features.CrateLuck and RunService:IsStudio() then
		registerLuckAdmin(crate)
	end
end

function CrateService.Start()
	-- Remotes first, even when crates are off, so a client never waits for them forever.
	resultEvent = Remotes.Event("CrateResult")
	Remotes.Function("OpenCrate").OnServerInvoke = onOpen
	Remotes.Function("PrepareCrateRobux").OnServerInvoke = onPrepare
	if not Config.Features.Crates then
		disablePrompts()
		return
	end
	if started then
		return
	end
	started = true

	local function onPlayer(player: Player)
		task.spawn(checkPolicy, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
		lastPrepare[player] = nil
		restricted[player] = nil
		prepared[player] = nil
		receiving[player] = nil
	end)
	-- The Robux purchase window closed (cancelled: the hold ends; bought: it waits for the
	-- receipt, see onPurchaseFinished).
	MarketplaceService.PromptProductPurchaseFinished:Connect(onPurchaseFinished)
	-- F8 "Reset my save" empties the luck too: tell the screen with a newer version.
	AdminService.OnSaveReset(function(player)
		ShopService.LuckChanged(player)
		ShopService.Push(player)
	end)

	CollectionService:GetInstanceAddedSignal(Tags.CrateDisplay):Connect(function(instance)
		-- Deferred: a crate's model is tagged before its parts and attributes are all in.
		task.defer(CrateService.EnsurePrompt, instance)
	end)
	for _, instance in CollectionService:GetTagged(Tags.CrateDisplay) do
		CrateService.EnsurePrompt(instance)
	end

	registerAdmin()
end

return CrateService
