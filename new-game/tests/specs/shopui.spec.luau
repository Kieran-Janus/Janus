-- The Pumpkin Shop's feel (src/client/ShopUI.luau + ShopJuice.luau, Config.Shop.Juice): a
-- purchase the server confirms pops the card, bursts sparkles (cleaned up afterwards), rolls
-- the coins to the exact new total and turns the button into Unequip (buying puts it on);
-- a refused one wiggles the button and names the exact coins missing; putting something on
-- pops the checkmark and the "Wearing it!" toast; a new page still shows the right items,
-- popping in one after another; Animate = false makes everything instant.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

-- A client with the shop mounted; the test plays the server (BuyItem / EquipItem answers).
local function shop(animate: boolean)
	local rt = Runtime.new({ client = true })
	local remotes = rt:create("Folder", { Name = "Remotes" }, rt:find("ReplicatedStorage"))
	for _, name in { "GetShopState", "BuyItem", "EquipItem" } do
		rt:create("RemoteFunction", { Name = name }, remotes)
	end
	rt:create("RemoteEvent", { Name = "ShopState" }, remotes)
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Shop.Juice.Animate = animate
	local server = {
		Ready = true,
		Coins = 500,
		Owned = { "Skeleton" },
		Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" },
		Vip = false,
	}
	local function copy()
		return {
			Ready = true,
			Coins = server.Coins,
			Owned = table.clone(server.Owned),
			Equipped = table.clone(server.Equipped),
			Vip = false,
		}
	end
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	-- leaderstats up front, like the server makes them (ShopUI waits for them; the harness's
	-- WaitForChild polling would otherwise keep RunService frames from running).
	local player = rt.game:GetService("Players").LocalPlayer
	local stats = rt:create("Folder", { Name = "leaderstats" }, player)
	local coinsValue = rt:create("IntValue", { Name = "Coins", Value = server.Coins }, stats)
	remotes.GetShopState.OnServerInvoke = function()
		return copy()
	end
	remotes.BuyItem.OnServerInvoke = function(_, id)
		local item
		for _, i in Config.Shop.Items do
			if i.Id == id then
				item = i
			end
		end
		local price = Items.Price(item)
		if server.Coins < price then
			return false,
				("You need %d more %s."):format(price - server.Coins, Config.Economy.CurrencyName),
				copy()
		end
		server.Coins -= price
		coinsValue.Value = server.Coins
		table.insert(server.Owned, id)
		server.Equipped[item.Slot] = id
		return true, "Bought " .. item.Name .. "!", copy()
	end
	remotes.EquipItem.OnServerInvoke = function(_, slot, id)
		server.Equipped[slot] = id
		return copy()
	end
	local gui = rt:create("ScreenGui", { Name = "GameUI" })
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	rt:require(Client.PanelManager).Mount(gui)
	local ShopUI = rt:require(Client.ShopUI)
	ShopUI.Mount(gui)
	rt:advance(0.5)
	ShopUI.Open("Skin")
	rt:advance(1)
	local panel = gui.Shop

	local function cards(): { any }
		local out = {}
		for _, frame in panel:GetDescendants() do
			if frame:IsA("Frame") and frame:FindFirstChild("RarityBorder") then
				table.insert(out, frame)
			end
		end
		return out
	end
	local function nameOf(card: any): string
		for _, d in card:GetChildren() do
			if d:IsA("TextLabel") and d.TextWrapped then
				return d.Text
			end
		end
		return ""
	end
	local function card(name: string): any
		for _, c in cards() do
			if nameOf(c) == name then
				return c
			end
		end
		error("no card for " .. name)
	end
	local function actionOf(c: any): any
		return c:FindFirstChildOfClass("TextButton")
	end
	local function coinsText(): string
		for _, d in panel:GetChildren() do
			if d:IsA("TextLabel") and d.TextXAlignment == rt.env.Enum.TextXAlignment.Right then
				return d.Text
			end
		end
		return ""
	end
	local function leftovers(): number
		local n = 0
		for _, d in panel:GetDescendants() do
			if d.Name == "Sparkle" or d.Name == "SparkleBurst" or d:GetAttribute("Shaking") then
				n += 1
			end
		end
		return n
	end
	return {
		rt = rt,
		Config = Config,
		Items = Items,
		server = server,
		panel = panel,
		cards = cards,
		card = card,
		nameOf = nameOf,
		actionOf = actionOf,
		coinsText = coinsText,
		leftovers = leftovers,
		currency = Config.Economy.CurrencyName,
	}
end

describe("ShopUI: buying", function()
	it(
		"pops a confirmed purchase, rolls the coins to the exact value and offers Unequip",
		function()
			local s = shop(true)
			expect(s.coinsText()).toBe("500 " .. s.currency)
			local zombie = s.card("Zombie")
			local action = s.actionOf(zombie)
			expect(action.Text).toBe(("Buy 125 %s"):format(s.currency))
			s.rt:fire(action, "Activated")
			s.rt:advance(0.05)
			-- Mid-effect: the card is growing, sparkles are out, the counter is rolling.
			expect(zombie:FindFirstChild("SparkleBurst")).toBeTruthy()
			expect(#zombie.SparkleBurst:GetChildren()).toBe(s.Config.Shop.Juice.Sparkles)
			expect(zombie:FindFirstChild("JuiceScale")).toBeTruthy()
			expect(s.coinsText()).never.toBe("375 " .. s.currency)
			-- The button flipped (buying puts it on, so it offers to take it off) and springs in.
			expect(action.Text).toBe("Unequip")
			expect(action:FindFirstChild("JuiceScale")).toBeTruthy()
			expect(zombie.Check.Visible).toBe(true)
			expect(s.panel.Toast.Visible).toBe(true)
			expect(s.panel.Toast.Text).toBe("Wearing it!")
			s.rt:advance(2)
			expect(s.coinsText()).toBe("375 " .. s.currency)
			expect(zombie.JuiceScale.Scale).toBe(1)
			expect(action.JuiceScale.Scale).toBe(1)
			expect(s.panel.Toast.Visible).toBe(false)
			expect(s.leftovers()).toBe(0)
		end
	)

	it("shakes a refused purchase and names the exact coins missing", function()
		local s = shop(true)
		local ghost = s.card("Ghost")
		local action = s.actionOf(ghost)
		local home = action.Position
		local price = 0
		for _, item in s.Config.Shop.Items do
			if item.Id == "Ghost" then
				price = s.Items.Price(item)
			end
		end
		expect(price).toBe(1000)
		s.rt:fire(action, "Activated")
		s.rt:advance(0.05)
		expect(action.Text).toBe(("Need %d more %s"):format(price - 500, s.currency))
		expect(action:GetAttribute("Shaking")).toBe(true)
		expect(ghost:FindFirstChild("SparkleBurst")).toBeNil()
		s.rt:advance(2)
		expect(action.Position).toEqual(home)
		expect(action.Text).toBe(("Buy 1,000 %s"):format(s.currency))
		expect(s.coinsText()).toBe("500 " .. s.currency)
		expect(s.leftovers()).toBe(0)
	end)

	it("pops the checkmark and shows the toast when you put something on", function()
		local s = shop(true)
		local skeleton = s.card("Skeleton")
		local action = s.actionOf(skeleton)
		expect(action.Text).toBe("Equip")
		expect(skeleton.Check.Visible).toBe(false)
		s.rt:fire(action, "Activated")
		s.rt:advance(0.05)
		expect(skeleton.Check.Visible).toBe(true)
		expect(skeleton.Check:FindFirstChild("JuiceScale")).toBeTruthy()
		expect(s.panel.Toast.Visible).toBe(true)
		expect(action.Text).toBe("Unequip")
		s.rt:advance(2)
		expect(skeleton.Check.JuiceScale.Scale).toBe(1)
		expect(s.panel.Toast.Visible).toBe(false)
	end)
end)

describe("ShopUI: pages", function()
	it("shows the right items on the next page, popping in one after another", function()
		local s = shop(true)
		local pageSize = s.Config.Skins.Shop.PageSize
		local skins = {}
		for _, item in s.Config.Shop.Items do
			if item.Slot == "Skin" and not item.Exclusive then
				table.insert(skins, item.Name)
			end
		end
		s.rt:fire(s.panel.Pager.Next, "Activated")
		local shown = s.cards()
		table.sort(shown, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		expect(#shown).toBe(math.min(pageSize, #skins - pageSize))
		for i, c in shown do
			expect(s.nameOf(c)).toBe(skins[pageSize + i])
			expect(c.JuiceScale.Scale).toBe(0) -- not in yet
		end
		-- Staggered: the first card is in before the last one.
		local juice = s.Config.Shop.Juice
		s.rt:advance(juice.EnterTime + juice.EnterStagger * 0.5)
		expect(shown[1].JuiceScale.Scale).toBe(1)
		expect(shown[#shown].JuiceScale.Scale).toBe(0)
		s.rt:advance(1)
		for _, c in shown do
			expect(c.JuiceScale.Scale).toBe(1)
		end
	end)
end)

describe("ShopUI: Animate off", function()
	it("does everything instantly, with no effects left behind", function()
		local s = shop(false)
		for _, c in s.cards() do
			local scale = c:FindFirstChild("JuiceScale")
			expect(scale == nil or scale.Scale == 1).toBe(true)
		end
		local zombie = s.card("Zombie")
		local action = s.actionOf(zombie)
		s.rt:fire(action, "Activated")
		s.rt:advance(0)
		expect(s.coinsText()).toBe("375 " .. s.currency)
		expect(action.Text).toBe("Unequip")
		expect(zombie:FindFirstChild("SparkleBurst")).toBeNil()
		expect(zombie:FindFirstChild("JuiceScale")).toBeNil()
		-- A refused buy still says how many more, without wiggling.
		local ghost = s.card("Ghost")
		local ghostAction = s.actionOf(ghost)
		s.rt:advance(1)
		s.rt:fire(ghostAction, "Activated")
		s.rt:advance(0)
		expect(ghostAction.Text).toBe(("Need %d more %s"):format(1000 - 375, s.currency))
		expect(ghostAction:GetAttribute("Shaking")).toBeNil()
		expect(s.leftovers()).toBe(0)
	end)
end)
