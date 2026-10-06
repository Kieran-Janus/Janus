-- Crates (Config.Crates, src/shared/CrateOdds.luau, CrateService, the Robux receipts in
-- MonetizationService, the crate stand and the crate panel): odds add up to 100 and match a
-- big simulation, the server takes coins, rolls, gives or refunds, refuses restricted
-- players, undoes a Robux crate whose save failed, and the panel shows every chance.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

-- PolicyService for these tests: players called "Restricted..." live where paid random items
-- aren't allowed, "NoAnswer..." makes Roblox fail to answer; everyone else is like the
-- harness default.
Dom.define("PolicyService", {
	GetPolicyInfoForPlayerAsync = function(_self, player)
		local name = Dom.get(player, "Name")
		if type(name) == "string" and name:sub(1, 8) == "NoAnswer" then
			error("HTTP 500 (test)", 2)
		end
		return {
			AreAdsAllowed = true,
			ArePaidRandomItemsRestricted = type(name) == "string"
				and name:sub(1, 10) == "Restricted",
			AllowedExternalLinkReferences = {},
			IsContentSharingAllowed = true,
			IsEligibleToPurchaseSubscription = true,
			IsPaidItemTradingAllowed = true,
			IsSubjectToChinaPolicies = false,
		}
	end,
})

describe("Config.Crates and CrateOdds", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	local CrateOdds = rt:require("ReplicatedStorage.Shared.CrateOdds")

	it("has the default odds, adding up to 100", function()
		local odds = Config.Crates.Odds
		expect(odds.Common).toBe(70)
		expect(odds.Uncommon).toBe(24.9)
		expect(odds.Rare).toBe(5)
		expect(odds.Crazy).toBe(0.1)
		local total = 0
		for _, v in odds do
			total += v
		end
		expect(total).toBeNear(100, 1e-9)
	end)

	it("has a themed crate per skin theme and a crate per rarity", function()
		for _, theme in Config.Skins.Themes do
			local crate = CrateOdds.Get(theme.Crate)
			expect(crate).toBeTruthy()
			expect(crate.Rarity).toBeNil()
		end
		for _, rarity in Config.Rarity.Order do
			local crate = CrateOdds.Get(rarity .. "Crate")
			expect(crate).toBeTruthy()
			expect(crate.Rarity).toBe(rarity)
		end
		local ids = {}
		for _, crate in Config.Crates.List do
			expect(ids[crate.Id]).toBeNil()
			ids[crate.Id] = true
			expect(crate.Name).toBeA("string")
			expect(crate.Blurb).toBeA("string")
			expect(typeof(crate.Color)).toBe("Color3")
			expect(typeof(crate.Trim)).toBe("Color3")
			expect(typeof(crate.Glow)).toBe("Color3")
			expect(CrateOdds.CoinPrice(crate)).toBeGreaterThan(0)
			expect(crate.Robux.ProductId).toBe(0) -- "Coming soon" until Kieran makes the products
			expect(crate.Robux.SuggestedRobux).toBeGreaterThan(0)
		end
		expect(CrateOdds.Get("NoSuchCrate")).toBeNil()
		expect(CrateOdds.Get(42)).toBeNil()
		-- A Robux crate that can't be opened for the buyer always gives some coins back.
		expect(Config.Crates.RobuxFallbackCoins).toBeGreaterThan(0)
		expect(Config.Monetization.ReceiptLoadWaitSeconds).toBeGreaterThan(0)
	end)

	it("gives every crate at least one item, and chances that add up to 100", function()
		for _, crate in Config.Crates.List do
			local chances = CrateOdds.Chances(crate)
			expect(#chances).toBeGreaterThan(0)
			local total = 0
			for _, c in chances do
				expect(c.Chance).toBeGreaterThan(0)
				expect(c.Item.VipOnly).toBeFalsy()
				total += c.Chance
			end
			expect(total).toBeNear(100, 1e-9)
			local byRarity = 0
			for _, v in CrateOdds.RarityOdds(crate) do
				byRarity += v
			end
			expect(byRarity).toBeNear(100, 1e-9)
		end
		expect(#CrateOdds.List()).toBe(#Config.Crates.List)
	end)

	it("splits each rarity's odds equally between its items", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		local seen = {}
		for _, c in CrateOdds.Chances(pumpkin) do
			seen[c.Rarity] = (seen[c.Rarity] or 0) + 1
			expect(c.Item.Crate).toBe("PumpkinCrate")
		end
		expect(seen).toEqual({ Common = 12, Uncommon = 5, Rare = 2, Crazy = 1 })
		local chances = CrateOdds.Chances(pumpkin)
		expect(chances[1].Rarity).toBe("Crazy") -- highest rarity first
		expect(CrateOdds.Format(chances[1].Chance)).toBe("0.100%")
		for _, c in chances do
			local expected = Config.Crates.Odds[c.Rarity] / seen[c.Rarity]
			expect(c.Chance).toBeNear(expected, 1e-9)
		end
		expect(CrateOdds.Format(70 / 12)).toBe("5.833%")
		expect(CrateOdds.Format(24.9 / 5)).toBe("4.980%")
	end)

	it("fills rarity crates with only their rarity, from every theme", function()
		for _, rarity in Config.Rarity.Order do
			local crate = CrateOdds.Get(rarity .. "Crate")
			local chances = CrateOdds.Chances(crate)
			local themes = {}
			for _, c in chances do
				expect(c.Rarity).toBe(rarity)
				expect(Items.Rarity(c.Item)).toBe(rarity)
				expect(c.Chance).toBeNear(100 / #chances, 1e-9)
				themes[c.Item.Theme] = true
			end
			for _, theme in Config.Skins.Themes do
				if not themes[theme.Id] then
					error(("%s has nothing from the %s theme"):format(crate.Id, theme.Id))
				end
			end
		end
		expect(#CrateOdds.Chances(CrateOdds.Get("CrazyCrate"))).toBe(#Config.Skins.Themes)
	end)

	it("scales the odds up when a crate has no items of a rarity", function()
		local crate = {
			Id = "TestCrate",
			Name = "Test",
			Odds = { Common = 50, Uncommon = 30, Rare = 15, Crazy = 5 },
		}
		local items = Config.Shop.Items
		local added = {
			{ Id = "TestA", Name = "A", Slot = "Hat", Rarity = "Common", Crate = "TestCrate" },
			{ Id = "TestB", Name = "B", Slot = "Hat", Rarity = "Rare", Crate = "TestCrate" },
		}
		for _, item in added do
			table.insert(items, item)
		end
		local ok, err = pcall(function()
			local odds = CrateOdds.RarityOdds(crate)
			expect(odds.Common).toBeNear(100 * 50 / 65, 1e-9)
			expect(odds.Rare).toBeNear(100 * 15 / 65, 1e-9)
			expect(odds.Uncommon).toBeNil()
			local total = 0
			for _, c in CrateOdds.Chances(crate) do
				total += c.Chance
			end
			expect(total).toBeNear(100, 1e-9)
		end)
		for _ = 1, #added do
			table.remove(items)
		end
		if not ok then
			error(err, 0)
		end
	end)

	it("picks items by their chance, even tiny ones", function()
		local chances = {
			{ Item = "a", Rarity = "Common", Chance = 99.9 },
			{ Item = "b", Rarity = "Crazy", Chance = 0.1 },
		}
		expect(CrateOdds.Pick(chances, 0)).toBe("a")
		expect(CrateOdds.Pick(chances, 0.9989)).toBe("a")
		expect(CrateOdds.Pick(chances, 0.9991)).toBe("b")
		expect(CrateOdds.Pick(chances, 1)).toBe("b")
		expect(CrateOdds.Pick({}, 0.5)).toBeNil()
	end)

	it("matches the odds over 200,000 simulated rolls", function()
		local Random = rt.env.Random
		local rng = Random.new(20261006)
		local crate = CrateOdds.Get("PumpkinCrate")
		local chances = CrateOdds.Chances(crate)
		local rolls = 200000
		local hits: { [string]: number } = {}
		local rarityHits: { [string]: number } = {}
		for _ = 1, rolls do
			local item = CrateOdds.Pick(chances, rng:NextNumber())
			hits[item.Id] = (hits[item.Id] or 0) + 1
			local rarity = Items.Rarity(item)
			rarityHits[rarity] = (rarityHits[rarity] or 0) + 1
		end
		-- Within 5 standard deviations (a correct roll fails this about once in 1.7 million).
		local function check(name: string, count: number, percent: number)
			local p = percent / 100
			local sigma = math.sqrt(rolls * p * (1 - p))
			local expected = rolls * p
			if math.abs(count - expected) > 5 * sigma + 1 then
				error(("%s: %d hits, expected about %.0f"):format(name, count, expected))
			end
		end
		for rarity, percent in Config.Crates.Odds do
			check(rarity, rarityHits[rarity] or 0, percent)
		end
		for _, c in chances do
			check(c.Item.Id, hits[c.Item.Id] or 0, c.Chance)
		end
		T.note(
			("Common %d, Uncommon %d, Rare %d, CRAZY %d"):format(
				rarityHits.Common or 0,
				rarityHits.Uncommon or 0,
				rarityHits.Rare or 0,
				rarityHits.Crazy or 0
			)
		)
	end)

	it("builds a reel with the winner at WinIndex and real items around it", function()
		local rng = rt.env.Random.new(7)
		local crate = CrateOdds.Get("CandyCrate")
		local winner = Items.ByCrate("CandyCrate")[1].Id
		local reel = CrateOdds.Reel(crate, winner, rng, 32, 28)
		expect(#reel).toBe(32)
		expect(reel[28]).toBe(winner)
		for _, id in reel do
			expect(Items.Get(id).Crate).toBe("CandyCrate")
		end
	end)

	it("finds crates by their Robux product", function()
		expect(CrateOdds.ByProductId(0)).toBeNil()
		local crate = CrateOdds.Get("SpookyCrate")
		crate.Robux.ProductId = 555
		expect(CrateOdds.ByProductId(555)).toBe(crate)
		crate.Robux.ProductId = 0
		expect(CrateOdds.ByProductId(555)).toBeNil()
	end)
end)

-- A server with the services crates need, and a player with a loaded save.
local function serverWorld(options: { [string]: any }?)
	local server = Runtime.new(options)
	local Config = server:require("ReplicatedStorage.Shared.Config")
	Config.Features.Crates = true
	Config.Features.RobuxCrates = true
	local services = "ServerScriptService.Server.Services."
	local DataService = server:require(services .. "DataService")
	local ShopService = server:require(services .. "ShopService")
	local CrateService = server:require(services .. "CrateService")
	local MonetizationService = server:require(services .. "MonetizationService")
	DataService.Start()
	ShopService.Start()
	MonetizationService.Start()
	CrateService.Start()
	return {
		rt = server,
		Config = Config,
		Items = server:require("ReplicatedStorage.Shared.Items"),
		CrateOdds = server:require("ReplicatedStorage.Shared.CrateOdds"),
		DataService = DataService,
		CrateService = CrateService,
		open = function(player, crateId)
			server:advance(Config.Crates.RequestCooldown + 0.1)
			return server:invokeServer(
				server:find("ReplicatedStorage.Remotes.OpenCrate"),
				player,
				crateId
			)
		end,
		join = function(name: string)
			local player = server:addPlayer({ Name = name })
			server:advance(3)
			return player, DataService.Get(player)
		end,
		results = function(player)
			local out = {}
			for _, call in server:calls("RemoteEvent", "FireClient") do
				local remote, target, payload = call.instance, call.args[1], call.args[2]
				if remote.Name == "CrateResult" and target == player then
					table.insert(out, payload)
				end
			end
			return out
		end,
	}
end

describe("CrateService (coins)", function()
	local w = serverWorld()
	local Config, Items, DataService = w.Config, w.Items, w.DataService
	local player, data = w.join("Opener")

	it("knows the player may open crates", function()
		expect(player:GetAttribute("CratesRestricted")).toBe(false)
		expect(w.CrateService.IsRestricted(player)).toBe(false)
	end)

	it("takes the price, gives a skin from the crate and counts it", function()
		DataService.Add(player, "Coins", 1000)
		local before = data.Coins
		local result = w.open(player, "PumpkinCrate")
		expect(result.Ok).toBe(true)
		expect(result.Message).toBe("")
		local item = Items.Get(result.ItemId)
		expect(item.Crate).toBe("PumpkinCrate")
		expect(result.Rarity).toBe(Items.Rarity(item))
		expect(result.Duplicate).toBe(false)
		expect(result.Refund).toBe(0)
		expect(data.Owned[result.ItemId]).toBe(true)
		expect(data.Coins).toBe(before - 300)
		expect(data.Crates.Opened).toBe(1)
		expect(#result.Reel).toBe(Config.Crates.Reel.Cards)
		expect(result.Reel[result.WinIndex]).toBe(result.ItemId)
		expect(result.Paid).toBe("Coins")
	end)

	it("refunds coins for a skin you already own", function()
		for _, item in Items.ByCrate("GraveyardCrate") do
			data.Owned[item.Id] = true
		end
		data.Coins = 300
		local result = w.open(player, "GraveyardCrate")
		expect(result.Ok).toBe(true)
		expect(result.Duplicate).toBe(true)
		local refund = Config.Rarity.Levels[result.Rarity].DuplicateRefund
		expect(result.Refund).toBe(refund)
		expect(data.Coins).toBe(refund)
		expect(data.Crates.Opened).toBe(2)
	end)

	it("refuses without enough coins, unknown crates and spam", function()
		data.Coins = 50
		local opened = data.Crates.Opened
		local result = w.open(player, "PumpkinCrate")
		expect(result.Ok).toBe(false)
		expect(result.Message).toMatch("more")
		expect(data.Coins).toBe(50)
		for _, bad in { "NoSuchCrate", 42, nil, { "PumpkinCrate" }, string.rep("x", 200) } do
			local r = w.open(player, bad)
			expect(r.Ok).toBe(false)
		end
		data.Coins = 1000
		w.open(player, "CommonCrate")
		local remote = w.rt:find("ReplicatedStorage.Remotes.OpenCrate")
		local fast = w.rt:invokeServer(remote, player, "CommonCrate")
		expect(fast.Ok).toBe(false)
		expect(fast.Message).toBe(Config.Crates.Text.SlowDown)
		expect(data.Crates.Opened).toBe(opened + 1)
		expect(data.Coins).toBe(900)
	end)

	it("gives rarity crates only their rarity", function()
		data.Coins = 5000
		for _ = 1, 4 do
			local result = w.open(player, "RareCrate")
			expect(result.Ok).toBe(true)
			expect(result.Rarity).toBe("Rare")
		end
	end)

	it("opens nothing while crates are switched off", function()
		Config.Features.Crates = false
		data.Coins = 1000
		local result = w.open(player, "PumpkinCrate")
		Config.Features.Crates = true
		expect(result.Ok).toBe(false)
		expect(result.Message).toBe(Config.Crates.Text.Closed)
		expect(data.Coins).toBe(1000)
	end)

	it("cleans up when the player leaves", function()
		local leaver = w.join("Leaver")
		expect(leaver:GetAttribute("CratesRestricted")).toBe(false)
		w.rt:removePlayer(leaver)
		w.rt:advance(1)
		expect(w.CrateService.IsRestricted(leaver)).toBe(true) -- no state left = closed
	end)
end)

describe("CrateService (paid random items rule)", function()
	local w = serverWorld()
	local Config, DataService = w.Config, w.DataService

	it("refuses every crate to a restricted player", function()
		local player, data = w.join("RestrictedKid")
		expect(player:GetAttribute("CratesRestricted")).toBe(true)
		data.Coins = 100000
		for _, crate in Config.Crates.List do
			local result = w.open(player, crate.Id)
			expect(result.Ok).toBe(false)
			expect(result.Message).toBe(Config.Crates.Text.Restricted)
		end
		expect(data.Coins).toBe(100000)
		expect(data.Crates.Opened).toBe(0)
	end)

	it("treats no answer from Roblox as restricted (outside Studio)", function()
		local player, data = w.join("NoAnswerKid")
		w.rt:advance(Config.Crates.Policy.Attempts * Config.Crates.Policy.RetrySeconds + 1)
		expect(player:GetAttribute("CratesRestricted")).toBe(true)
		data.Coins = 1000
		expect(w.open(player, "PumpkinCrate").Ok).toBe(false)
		expect(data.Coins).toBe(1000)
	end)

	it("refuses while it is still asking", function()
		local player = w.rt:addPlayer({ Name = "NoAnswerSlow" })
		w.rt:advance(2.5) -- data loaded, policy still retrying
		local data = DataService.Get(player)
		expect(player:GetAttribute("CratesRestricted")).toBeNil()
		data.Coins = 1000
		local result = w.open(player, "PumpkinCrate")
		expect(result.Ok).toBe(false)
		expect(result.Message).toBe(Config.Crates.Text.StillChecking)
		expect(data.Coins).toBe(1000)
	end)

	it("gives a restricted Robux buyer the crate's coins instead of a random skin", function()
		local player, data = w.join("RestrictedBuyer")
		local crate = w.CrateOdds.Get("PumpkinCrate")
		crate.Robux.ProductId = 4242
		local owned = 0
		for _ in data.Owned do
			owned += 1
		end
		local before = data.Coins
		local decision = w.rt:purchase(player, 4242)
		crate.Robux.ProductId = 0
		expect(decision.Name).toBe("PurchaseGranted")
		expect(data.Coins).toBe(before + 300)
		local after = 0
		for _ in data.Owned do
			after += 1
		end
		expect(after).toBe(owned)
		local sent = w.results(player)
		expect(#sent).toBe(1)
		expect(sent[1].Ok).toBe(false)
	end)
end)

describe("Robux crates (MonetizationService)", function()
	local w = serverWorld()
	local DataService = w.DataService
	local player, data = w.join("RobuxBuyer")
	local crate = w.CrateOdds.Get("MoonlightCrate")
	crate.Robux.ProductId = 777

	it("rolls, gives, saves and tells the client", function()
		local decision = w.rt:purchase(player, 777)
		expect(decision.Name).toBe("PurchaseGranted")
		expect(#data.Receipts).toBe(1)
		expect(data.Crates.Opened).toBe(1)
		local sent = w.results(player)
		expect(#sent).toBe(1)
		expect(sent[1].Ok).toBe(true)
		expect(sent[1].Paid).toBe("Robux")
		expect(data.Owned[sent[1].ItemId]).toBe(true)
		expect(w.Items.Get(sent[1].ItemId).Crate).toBe("MoonlightCrate")
	end)

	it("never grants the same receipt twice", function()
		local callback = Dom.callback(w.rt.game:GetService("MarketplaceService"), "ProcessReceipt")
		local receipt = {
			PlayerId = player.UserId,
			ProductId = 777,
			PurchaseId = data.Receipts[1],
			CurrencySpent = 0,
		}
		local decision = w.rt:call(callback, receipt)
		expect(decision.Name).toBe("PurchaseGranted")
		expect(data.Crates.Opened).toBe(1)
		expect(#w.results(player)).toBe(1)
	end)

	it("undoes everything when the save fails, so Roblox can retry", function()
		local owned = table.clone(data.Owned)
		local coins = data.Coins
		w.rt.dataStoreFailures = 4 -- every save attempt fails
		local decision = w.rt:purchase(player, 777)
		w.rt.dataStoreFailures = 0
		expect(decision.Name).toBe("NotProcessedYet")
		expect(data.Owned).toEqual(owned)
		expect(data.Coins).toBe(coins)
		expect(data.Crates.Opened).toBe(1)
		expect(#data.Receipts).toBe(1)
		expect(#w.results(player)).toBe(1)
	end)

	it("still sells coin packs", function()
		local Config = w.Config
		local pack = Config.Monetization.Products[1]
		pack.Id = 9001
		local before = data.Coins
		local decision = w.rt:purchase(player, 9001)
		pack.Id = 0
		expect(decision.Name).toBe("PurchaseGranted")
		expect(data.Coins).toBe(before + pack.Coins)
		local _ = DataService
	end)

	it("gives coins for a Robux-only crate it can't open, never 0", function()
		local Config = w.Config
		local price = crate.Price
		crate.Price = nil -- sold only for Robux
		Config.Features.RobuxCrates = false -- e.g. switched off before the purchase finished
		local before = data.Coins
		local opened = data.Crates.Opened
		local fallback = Config.Crates.RobuxFallbackCoins
		local decision = w.rt:purchase(player, 777)
		expect(decision.Name).toBe("PurchaseGranted")
		expect(data.Coins).toBe(before + fallback)
		expect(data.Crates.Opened).toBe(opened)
		local sent = w.results(player)
		expect(sent[#sent].Ok).toBe(false)
		expect(sent[#sent].Message).toMatch(tostring(fallback))

		-- No fallback either: left unfinished for later instead of giving nothing.
		Config.Crates.RobuxFallbackCoins = 0
		local receipts = table.clone(data.Receipts)
		decision = w.rt:purchase(player, 777)
		Config.Crates.RobuxFallbackCoins = fallback
		Config.Features.RobuxCrates = true
		crate.Price = price
		expect(decision.Name).toBe("NotProcessedYet")
		expect(data.Coins).toBe(before + fallback)
		expect(data.Receipts).toEqual(receipts)
	end)

	it("answers 'not yet' to a second ask about a purchase that is still saving", function()
		local callback = Dom.callback(w.rt.game:GetService("MarketplaceService"), "ProcessReceipt")
		local receipt = {
			PlayerId = player.UserId,
			ProductId = 777,
			PurchaseId = "slow-save",
			CurrencySpent = 0,
		}
		local owned = table.clone(data.Owned)
		local opened = data.Crates.Opened
		local first: any = nil
		w.rt.dataStoreFailures = 100 -- the first answer's save keeps failing (and retrying)
		w.rt.env.task.spawn(function()
			first = callback(receipt)
		end)
		w.rt:advance(1)
		expect(first).toBeNil() -- still trying to save
		local second = w.rt:call(callback, receipt)
		expect(second.Name).toBe("NotProcessedYet") -- not "granted": that save could still fail
		w.rt:advance(40)
		w.rt.dataStoreFailures = 0
		expect(first.Name).toBe("NotProcessedYet")
		expect(data.Owned).toEqual(owned)
		expect(data.Crates.Opened).toBe(opened)
		expect(table.find(data.Receipts, "slow-save")).toBeNil()

		-- Roblox asks again later: granted, and only once.
		expect(w.rt:call(callback, receipt).Name).toBe("PurchaseGranted")
		expect(data.Crates.Opened).toBe(opened + 1)
		expect(w.rt:call(callback, receipt).Name).toBe("PurchaseGranted")
		expect(data.Crates.Opened).toBe(opened + 1)
	end)

	it("waits for the save of a buyer who is still joining", function()
		local pack = w.Config.Monetization.Products[1]
		pack.Id = 9002
		w.rt.dataStoreFailures = 1 -- the first load attempt fails, the retry 2 s later works
		local late = w.rt:addPlayer({ Name = "LateBuyer" })
		expect(DataService.Get(late)).toBeNil()
		local decision = w.rt:purchase(late, 9002)
		expect(decision.Name).toBe("PurchaseGranted")
		expect(DataService.IsLoaded(late)).toBe(true)
		expect(DataService.Get(late).Coins).toBe(pack.Coins)

		-- A buyer who leaves while their save loads: left for their next visit.
		w.rt.dataStoreFailures = 1
		local leaver = w.rt:addPlayer({ Name = "Leaver" })
		local callback = Dom.callback(w.rt.game:GetService("MarketplaceService"), "ProcessReceipt")
		local result: any = nil
		w.rt.env.task.spawn(function()
			result = callback({
				PlayerId = leaver.UserId,
				ProductId = 9002,
				PurchaseId = "leaver-1",
				CurrencySpent = 0,
			})
		end)
		w.rt:advance(0.5)
		expect(result).toBeNil()
		w.rt:removePlayer(leaver)
		w.rt:advance(1)
		pack.Id = 0
		expect(result.Name).toBe("NotProcessedYet")
		w.rt:advance(5)
		w.rt.dataStoreFailures = 0
	end)
end)

describe("Admin crate commands", function()
	local w = serverWorld({ studio = true }) -- admins: anyone in a Studio playtest
	local AdminService = w.rt:require("ServerScriptService.Server.Services.AdminService")
	AdminService.Start()
	local player, data = w.join("Owner")

	it("opens a free crate and adds 100k coins", function()
		local run = w.rt:find("ReplicatedStorage.Remotes.AdminCommand")
		local list =
			w.rt:invokeServer(w.rt:find("ReplicatedStorage.Remotes.GetAdminCommands"), player)
		local labels = {}
		for _, info in list do
			labels[info.Name] = info.Label
		end
		expect(labels.CrateFree).toBe("Crates: open free Pumpkin Crate")
		expect(labels.CrateCoins).toBe("Crates: +100k coins")
		local coins = data.Coins
		w.rt:advance(1)
		local ok, message = w.rt:invokeServer(run, player, "CrateFree")
		expect(ok).toBe(true)
		expect(message).toMatch("Free Pumpkin Crate")
		expect(data.Coins).toBe(coins)
		expect(data.Crates.Opened).toBe(1)
		expect(#w.results(player)).toBe(1)
		w.rt:advance(1)
		ok = w.rt:invokeServer(run, player, "CrateCoins")
		expect(ok).toBe(true)
		expect(data.Coins).toBe(coins + 100000)
	end)
end)

describe("Crate stand (lobby)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Features.Crates = true
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")

	it("puts every crate on the stand with an Open prompt, inside the Crates zone", function()
		local hub = HubBuilder.Build()
		local stand = hub:FindFirstChild("CrateStand")
		expect(stand).toBeInstanceOf("Model")
		local CS = rt.game:GetService("CollectionService")
		local found = {}
		for _, holder in CS:GetTagged(Tags.CrateDisplay) do
			expect(holder:IsDescendantOf(stand)).toBe(true)
			local id = holder:GetAttribute("CrateId")
			local prompt = holder:FindFirstChildOfClass("ProximityPrompt")
			expect(prompt).toBeInstanceOf("ProximityPrompt")
			expect(prompt:GetAttribute("CrateId")).toBe(id)
			found[id] = true
			expect(Lobby.InZone(holder.Position, "Crates")).toBe(true)
			local crate = rt:require("ReplicatedStorage.Shared.CrateOdds").Get(id)
			expect(prompt.ActionText).toBe(Config.Crates.Text.Prompt:format(crate.Name))
		end
		for _, crate in Config.Crates.List do
			if not found[crate.Id] then
				error("no " .. crate.Id .. " on the stand")
			end
			expect(stand:FindFirstChild(crate.Id .. "Display")).toBeInstanceOf("Model")
		end
		for _, d in stand:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				if not Lobby.InZone(d.Position, "Crates", 1) then
					error(d:GetFullName() .. " sticks out of the Crates zone")
				end
			end
		end
		expect(stand.SignBoard.Board:FindFirstChild("Lettering")).toBeTruthy()
	end)

	it("adds a prompt to any part tagged CrateDisplay, and builds nothing when off", function()
		local CrateService = rt:require("ServerScriptService.Server.Services.CrateService")
		local part = rt:create("Part", { Name = "MyCrate" }, rt.workspace)
		part:SetAttribute("CrateId", "CandyCrate")
		local prompt = CrateService.EnsurePrompt(part)
		expect(prompt).toBeInstanceOf("ProximityPrompt")
		expect(prompt:GetAttribute("CrateId")).toBe("CandyCrate")
		expect(CrateService.EnsurePrompt(part)).toBe(prompt) -- not twice
		Config.Features.Crates = false
		local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
		local empty = HubBuilder.BuildSection(hub, "CrateStand")
		Config.Features.Crates = true
		expect(#empty:GetChildren()).toBe(0)
	end)
end)

describe("CrateUI (client)", function()
	local w = serverWorld()
	local player = w.join("Viewer")
	local client = Runtime.new({ client = true })
	client:replicateFrom(w.rt)
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	CConfig.Features.Crates = true
	CConfig.Features.RobuxCrates = true
	local CrateUI = client:require("StarterPlayer.StarterPlayerScripts.Client.CrateUI")
	local me = client.game:GetService("Players").LocalPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me.PlayerGui)
	CrateUI.Mount(gui)
	client:advance(1)
	local panel = gui:FindFirstChild("Crates")
	local _ = player

	it("lists every crate", function()
		me:SetAttribute("CratesRestricted", false)
		CrateUI.Open()
		expect(panel.Visible).toBe(true)
		local cards = panel.Body.List.Crates
		for _, crate in CConfig.Crates.List do
			expect(cards:FindFirstChild(crate.Id)).toBeInstanceOf("TextButton")
		end
	end)

	it("shows every skin in a crate with its exact chance before buying", function()
		CrateUI.Open("PumpkinCrate")
		local preview = panel.Body.Preview
		expect(preview.Visible).toBe(true)
		local CrateOdds = client:require("ReplicatedStorage.Shared.CrateOdds")
		local chances = CrateOdds.Chances(CrateOdds.Get("PumpkinCrate"))
		local count = 0
		for _, c in chances do
			local card = preview.Items:FindFirstChild(c.Item.Id)
			expect(card).toBeInstanceOf("Frame")
			expect(card.Chance.Text).toBe(CrateOdds.Format(c.Chance))
			count += 1
		end
		expect(count).toBe(20)
		expect(preview.Items:FindFirstChild("Pumpkin_PumpkinSpice").Chance.Text).toBe("5.833%")
		expect(preview.Side.Buy.Visible).toBe(true)
		expect(preview.Side.Buy.OpenCoins.Text).toMatch("300")
		expect(preview.Side.Buy.OpenRobux.Text).toBe(CConfig.Crates.Text.ComingSoon)
	end)

	it("hides the buy buttons from restricted players", function()
		me:SetAttribute("CratesRestricted", true)
		client:advance(0.1)
		local preview = panel.Body.Preview
		expect(preview.Side.Buy.Visible).toBe(false)
		expect(panel.Message.Text).toBe(CConfig.Crates.Text.Restricted)
		me:SetAttribute("CratesRestricted", false)
		client:advance(0.1)
		expect(panel.Body.Preview.Side.Buy.Visible).toBe(true)
	end)

	it("spins to the server's result and reveals it", function()
		local reel = {}
		for i = 1, 32 do
			reel[i] = "Pumpkin_PumpkinSpice"
		end
		reel[28] = "Pumpkin_SirGourdington"
		local result = {
			Ok = true,
			Message = "",
			CrateId = "PumpkinCrate",
			ItemId = "Pumpkin_SirGourdington",
			ItemName = "Sir Gourdington",
			Rarity = "Uncommon",
			Duplicate = true,
			Refund = 125,
			Reel = reel,
			WinIndex = 28,
			Paid = "Robux",
		}
		client:fire(client:find("ReplicatedStorage.Remotes.CrateResult"), "OnClientEvent", result)
		client:advance(0.5)
		local opening = panel.Body.Opening
		expect(opening.Visible).toBe(true)
		expect(#opening.Reel.Strip:GetChildren()).toBe(32)
		expect(opening.Reveal.Visible).toBe(false)
		client:advance(CConfig.Crates.Reel.SpinSeconds + CConfig.Crates.Reel.RevealDelay + 0.5)
		expect(opening.Reveal.Visible).toBe(true)
		local card = opening.Reveal.Card
		expect(card.ItemName.Text).toBe("Sir Gourdington")
		expect(card.News.Text).toBe(
			CConfig.Crates.Text.Duplicate:format(125, CConfig.Economy.CurrencyName)
		)
		expect(card.Buttons.Equip).toBeInstanceOf("TextButton")
		expect(card.Buttons.OpenAnother.Visible).toBe(true)
	end)

	it("ignores a malformed result", function()
		client:fire(client:find("ReplicatedStorage.Remotes.CrateResult"), "OnClientEvent", {
			Ok = true,
			CrateId = "PumpkinCrate",
			ItemId = "Pumpkin_SirGourdington",
			Reel = { "Pumpkin_PumpkinSpice" },
			WinIndex = 1,
		})
		client:advance(0.5)
		expect(panel.Body.Opening.Reveal.Visible).toBe(true) -- still showing the last one
		panel.Visible = false
		client:advance(0.1)
	end)
end)
