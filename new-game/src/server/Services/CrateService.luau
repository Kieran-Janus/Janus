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

	Client -> server:
	  OpenCrate(crateId, count?) -> Result opens `count` crates (one of Config.Crates.Open.Counts,
	                                      default 1) for count x its coin Price, taken in one go;
	                                      the server rolls them all. Result.Results lists every
	                                      result when count > 1 (Result itself is the first).
	Server -> client:
	  CrateResult(Result)                 a crate opened some other way (Robux purchase, F8
	                                      free crate): the panel plays the opening for it
	Result = { Ok, Message, CrateId, ItemId?, ItemName?, Rarity?, Duplicate?, Refund?, Reel?,
	           WinIndex?, Paid? } (Reel: item ids for the spinning strip, Reel[WinIndex] = ItemId)
	A CRAZY skin unboxed any way is announced to the whole server (AnnounceService; "Huge" for a
	ONE IN A MILLION skin) while Config.Crates.AnnounceCrazy is on.

	Robux crates: MonetizationService's ProcessReceipt calls CrateService.Grant for products
	that are a crate's Robux.ProductId (and undoes it if the save fails).

	CrateService.Grant(player, crate, paid) -> (Result?, undo)  roll and give (no payment)
	CrateService.IsRestricted(player, waitSeconds?) -> boolean  true while crates are closed
	                                                            for this player
	CrateService.CanOpenWithRobux(player, waitSeconds?) -> boolean
	CrateService.SendResult(player, result)
	CrateService.EnsurePrompt(instance) -> ProximityPrompt?     for parts tagged CrateDisplay
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateArt = require(ReplicatedStorage.Shared.CrateArt)
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
}

local CrateService = {}

local rng = Random.new()
local lastOpen: { [Player]: number } = {}
-- true = crates closed for this player, false = allowed, nil = still asking Roblox
local restricted: { [Player]: boolean } = {}
local resultEvent: RemoteEvent? = nil
local started = false

local function text()
	return Config.Crates.Text
end

local function fail(crateId: string, message: string): Result
	return { Ok = false, Message = message, CrateId = crateId }
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

function CrateService.CanOpenWithRobux(player: Player, waitSeconds: number?): boolean
	if not (Config.Features.Crates and Config.Features.RobuxCrates) then
		return false
	end
	return not CrateService.IsRestricted(player, waitSeconds)
end

-- Rolling and giving ----------------------------------------------------------------------

--[[
	Rolls `crate` and gives the player the skin, or its duplicate refund if they own it
	already. Takes no payment (the caller did). Returns the Result for the client and a
	function that takes it all back (for a Robux purchase whose save failed); nil if the
	player's data isn't there or the crate is empty.
]]
function CrateService.Grant(
	player: Player,
	crate: CrateOdds.Crate,
	paid: string
): (Result?, () -> ())
	local data = DataService.Get(player)
	if not data then
		return nil, noUndo
	end
	local item = CrateOdds.Roll(crate, rng)
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
		data.Crates = { Opened = 0 }
	end
	local stats = data.Crates
	stats.Opened = (tonumber(stats.Opened) or 0) + 1

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
		Reel = CrateOdds.Reel(crate, item.Id, rng, reel.Cards, winIndex),
		WinIndex = winIndex,
		Paid = paid,
		OneInAMillion = if item.OneInAMillion then true else nil,
	}
	-- A CRAZY skin: the whole server hears about it (extra big for a one-in-a-million one).
	if rarity == "Crazy" and Config.Crates.AnnounceCrazy then
		local t = text()
		local words = if item.OneInAMillion then t.AnnounceMillion else t.AnnounceCrazy
		AnnounceService.All(
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
	end
	return result, undo
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

local function onOpen(player: Player, crateId: unknown, countIn: unknown): Result
	local t = text()
	local id = if typeof(crateId) == "string" and #crateId <= 64 then crateId else ""
	if not Config.Features.Crates then
		return fail(id, t.Closed)
	end
	-- How many at once: only the counts the crate page offers (x1, x5, x10).
	local count = 1
	if countIn ~= nil then
		if typeof(countIn) ~= "number" or not table.find(Config.Crates.Open.Counts, countIn) then
			return fail(id, t.NoCrate)
		end
		count = countIn :: number
	end
	local now = os.clock()
	if now - (lastOpen[player] or -math.huge) < Config.Crates.RequestCooldown then
		return fail(id, t.SlowDown)
	end
	lastOpen[player] = now
	local crate = CrateOdds.Get(id)
	local price = if crate then CrateOdds.CoinPrice(crate) else nil
	if not crate or not price or #CrateOdds.Items(crate) == 0 then
		return fail(id, t.NoCrate)
	end
	local closed = restricted[player]
	if closed == nil then
		return fail(id, t.StillChecking)
	elseif closed then
		return fail(id, t.Restricted)
	end
	local data = DataService.Get(player)
	if not data then
		return fail(id, t.NotLoaded)
	end
	local total = price * count
	if not DataService.Spend(player, "Coins", total) then
		return fail(id, t.NoCoins:format(total - (data.Coins or 0), Config.Economy.CurrencyName))
	end
	local results: { Result } = {}
	for _ = 1, count do
		local result = CrateService.Grant(player, crate, "Coins")
		if not result then
			break
		end
		table.insert(results, result)
	end
	if #results < count then
		-- Some weren't given (an empty crate): give their coins back.
		DataService.Add(player, "Coins", price * (count - #results))
	end
	local first = results[1]
	if not first then
		return fail(id, t.NoCrate)
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
		return batch
	end
	return first
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
end

function CrateService.Start()
	-- Remotes first, even when crates are off, so a client never waits for them forever.
	resultEvent = Remotes.Event("CrateResult")
	Remotes.Function("OpenCrate").OnServerInvoke = onOpen
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
		restricted[player] = nil
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
