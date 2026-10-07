-- Server safety fixes from the server audit: the VIP pass is only given when Roblox says the
-- player owns it (a faked "purchase finished" event gives nothing), the gravestone leaderboard
-- never overwrites a player's lifetime total with the pumpkins of a session whose save didn't
-- load, and the friend bonus check copes with players leaving while Roblox answers.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

-- Player:IsFriendsWithAsync, as in the harness, but it waits `rt.slowFriends` seconds first
-- when a test sets that (Roblox's real call takes a while; the harness answers at once).
Dom.define("Player", {
	IsFriendsWithAsync = function(self, otherId)
		local w = Dom.data(self).world
		local wait = w.slowFriends
		if type(wait) == "number" and wait > 0 then
			w.env.task.wait(wait)
		end
		local friends = w.friends[Dom.get(self, "UserId")]
		return friends ~= nil and friends[otherId] == true
	end,
})

local SERVICES = "ServerScriptService.Server.Services."

describe("VIP game pass (MonetizationService)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Monetization.VipGamePassId = 4242
	rt:require(SERVICES .. "DataService").Start()
	rt:require(SERVICES .. "ShopService").Start()
	rt:require(SERVICES .. "MonetizationService").Start()
	local marketplace = rt.game:GetService("MarketplaceService")

	it("ignores a faked purchase-finished event and trusts Roblox's ownership check", function()
		local player = rt:addPlayer({ Name = "Faker" })
		rt:advance(3)
		expect(player:GetAttribute("VIP")).toBeNil()
		-- An exploiter fakes "I bought VIP" without owning the pass.
		rt:fire(marketplace, "PromptGamePassPurchaseFinished", player, 4242, true)
		rt:advance(1)
		expect(player:GetAttribute("VIP")).toBeNil()
		-- A real purchase: Roblox now says they own it.
		rt.gamePasses[player.UserId] = { [4242] = true }
		rt:fire(marketplace, "PromptGamePassPurchaseFinished", player, 4242, true)
		rt:advance(1)
		expect(player:GetAttribute("VIP")).toBe(true)
	end)

	it("still gives VIP on join to an owner, and nothing for another pass or a cancel", function()
		local owner = rt:addPlayer({ Name = "Owner", UserId = 7001 })
		rt.gamePasses[7001] = { [4242] = true }
		local other = rt:addPlayer({ Name = "Other", UserId = 7002 })
		rt:advance(3)
		rt:fire(marketplace, "PromptGamePassPurchaseFinished", other, 4242, false)
		rt:fire(marketplace, "PromptGamePassPurchaseFinished", other, 999, true)
		rt:advance(1)
		expect(other:GetAttribute("VIP")).toBeNil()
		-- (the owner joined before the pass was set up in the test: the join check missed it)
		rt:fire(marketplace, "PromptGamePassPurchaseFinished", owner, 4242, true)
		rt:advance(1)
		expect(owner:GetAttribute("VIP")).toBe(true)
	end)
end)

describe("Leaderboard gravestone (LeaderboardService)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Leaderboard.RefreshSeconds = 1e6 -- no periodic refresh using up DataStore failures
	local DataService = rt:require(SERVICES .. "DataService")
	local LeaderboardService = rt:require(SERVICES .. "LeaderboardService")
	DataService.Start()
	LeaderboardService.Start()
	rt:advance(1)
	local board =
		rt.game:GetService("DataStoreService"):GetOrderedDataStore(Config.Leaderboard.StoreName)

	it("keeps the real total when the player's save didn't load", function()
		board:SetAsync("5001", 100) -- their lifetime total from earlier sessions
		rt.dataStoreFailures = 4 -- every load attempt fails
		local player = rt:addPlayer({ Name = "Unlucky", UserId = 5001 })
		rt:advance(40)
		rt.dataStoreFailures = 0
		expect(player:GetAttribute("DataReady")).toBe(true)
		expect(DataService.IsLoaded(player)).toBe(false)
		LeaderboardService.Record(player, 5)
		rt:removePlayer(player)
		rt:advance(1)
		expect(board:GetAsync("5001")).toBe(100)
	end)

	it("writes a loaded player's lifetime total when they leave", function()
		local player = rt:addPlayer({ Name = "Lucky", UserId = 5002 })
		rt:advance(3)
		expect(DataService.IsLoaded(player)).toBe(true)
		DataService.Get(player).PumpkinsCollected = 40
		LeaderboardService.Record(player, 2)
		rt:removePlayer(player)
		rt:advance(1)
		expect(board:GetAsync("5002")).toBe(42)
	end)

	it("doesn't save a leaver again after a failed write", function()
		local player = rt:addPlayer({ Name = "Flaky", UserId = 5003 })
		rt:advance(3)
		LeaderboardService.Record(player, 3)
		-- The first failure hits DataService's leave save (it retries), the second the board.
		rt.dataStoreFailures = 2
		rt:removePlayer(player) -- the leave write fails
		rt:advance(5)
		rt.dataStoreFailures = 0
		local failed = false
		for _, line in rt.warnings do
			failed = failed or tostring(line):find("LeaderboardService%] save failed") ~= nil
		end
		expect(failed).toBe(true)
		board:SetAsync("5003", 77) -- (another server wrote a newer total meanwhile)
		rt:call(LeaderboardService.Refresh)
		expect(board:GetAsync("5003")).toBe(77)
	end)
end)

describe("Friend bonus (RewardsService)", function()
	local rt = Runtime.new()
	rt:require(SERVICES .. "DataService").Start()
	rt:require(SERVICES .. "ShopService").Start()
	local RewardsService = rt:require(SERVICES .. "RewardsService")
	RewardsService.Start()

	it("copes with a player leaving while Roblox checks their friends", function()
		rt.friends[6001] = { [6002] = true, [6003] = true }
		rt.friends[6002] = { [6001] = true }
		rt.friends[6003] = { [6001] = true }
		local a = rt:addPlayer({ Name = "A", UserId = 6001 })
		rt:advance(3)
		rt.slowFriends = 1
		local b = rt:addPlayer({ Name = "B", UserId = 6002 }) -- asks Roblox about A...
		rt:advance(0.5)
		rt:removePlayer(b) -- ...and leaves before the answer
		rt:advance(2)
		expect(#rt.errors).toBe(0)
		-- A friend who stays still counts.
		local c = rt:addPlayer({ Name = "C", UserId = 6003 })
		rt:advance(3)
		rt.slowFriends = 0
		expect(RewardsService.BonusPercent(c)).toBe(10)
		expect(RewardsService.BonusPercent(a)).toBe(10)
		expect(#rt.errors).toBe(0)
	end)
end)
