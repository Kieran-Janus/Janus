-- Phone layouts (fixes from the v2 review): on a short landscape phone (640 x 302 usable UI
-- units, the top bar taken off) banners stay under the Hud, the results, vote, spectate and
-- Secret Pumpkins panels fit at full size (no text shrunk below Config.UI.MinTextSize), the
-- shop's and the crate panel's Buy buttons are in view without scrolling (with the crate's
-- one-line luck summary pinned right above them), and the crate strip only builds 3D pictures
-- once it slows down.
--
-- The harness has no GUI layout (AbsoluteSize reads zero), so each test sets the screen's
-- size and the Hud's place by hand (Dom.rawSet), the way Roblox would lay them out.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local REMOTE_FUNCTIONS = {
	"GetShopState",
	"BuyItem",
	"EquipItem",
	"OpenCrate",
	"PrepareCrateRobux",
	"ParkourRequest",
	"AdminCommand",
	"GetAdminCommands",
}
local REMOTE_EVENTS = {
	"ShopState",
	"CrateResult",
	"CastVote",
	"VoteUpdate",
	"RoundResults",
	"EasterEggFound",
	"ParkourEvent",
	"SpectateFocus",
}

-- A client whose screen is `width` x `height` UI units (touch = a phone or tablet), with a
-- Hud bar where Hud.luau puts it (520 x 64, centred, at 0.02 of the height).
local function screen(width: number, height: number, touch: boolean)
	local rt = Runtime.new({ client = true })
	local Vector2 = rt.env.Vector2
	local remotes = rt:create("Folder", { Name = "Remotes" }, rt:find("ReplicatedStorage"))
	for _, name in REMOTE_FUNCTIONS do
		rt:create("RemoteFunction", { Name = name }, remotes)
	end
	for _, name in REMOTE_EVENTS do
		rt:create("RemoteEvent", { Name = name }, remotes)
	end
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	gui:SetAttribute("ForceTouch", touch)
	Dom.rawSet(gui, "AbsoluteSize", Vector2.new(width, height))
	local hud = rt:create("Frame", { Name = "Hud" }, gui)
	Dom.rawSet(hud, "AbsolutePosition", Vector2.new((width - 520) / 2, height * 0.02))
	Dom.rawSet(hud, "AbsoluteSize", Vector2.new(520, 64))
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	local Layout = rt:require(Client.Layout)
	Layout.Mount(gui)
	rt:require(Client.PanelManager).Mount(gui)
	return {
		rt = rt,
		gui = gui,
		hud = hud,
		player = player,
		remotes = remotes,
		Client = Client,
		Layout = Layout,
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		hudBottom = height * 0.02 + 64,
		width = width,
		height = height,
	}
end

-- Where `item` (a direct child of the screen) starts, in UI units from the top.
local function topOf(item: any, height: number): number
	local y = item.Position.Y.Scale * height + item.Position.Y.Offset
	local size = item.Size.Y.Scale * height + item.Size.Y.Offset
	return y - item.AnchorPoint.Y * size
end

describe("Banners on a short phone screen (Layout.KeepBelowHud)", function()
	it("is a phone and finds the Hud's bottom edge", function()
		local p = screen(640, 302, true)
		expect(p.Layout.IsPhone()).toBe(true)
		expect(p.Layout.HudBottom()).toBeNear(p.hudBottom, 0.01)
		p.hud.Visible = false
		expect(p.Layout.HudBottom()).toBeNil()
	end)

	it("moves a banner down just enough to clear the Hud", function()
		local p = screen(640, 302, true)
		local env = p.rt.env
		local banner = p.rt:create("TextLabel", {
			Name = "TestBanner",
			AnchorPoint = env.Vector2.new(0.5, 0.5),
			Position = env.UDim2.fromScale(0.5, 0.26),
			Size = env.UDim2.fromOffset(320, 96),
			Visible = false,
		}, p.gui)
		expect(topOf(banner, p.height)).toBeLessThan(p.hudBottom) -- the bug: it covered the Hud
		p.Layout.KeepBelowHud({ banner })
		banner.Visible = true
		local want = p.hudBottom + p.Config.UI.BelowHudGap
		expect(topOf(banner, p.height)).toBeGreaterThanOrEqual(want)
		expect(topOf(banner, p.height)).toBeLessThan(want + 1) -- (offsets are whole numbers)
		expect(banner.Position.Y.Scale).toBeNear(0.26, 1e-6) -- still placed by its usual spot
	end)

	it("keeps the parkour messages under the timer while it shows", function()
		local p = screen(640, 302, true)
		local env = p.rt.env
		local timer = p.rt:create("Frame", { Name = "ParkourTimer", Visible = false }, p.gui)
		Dom.rawSet(timer, "AbsolutePosition", env.Vector2.new(205, p.hudBottom + 6))
		Dom.rawSet(timer, "AbsoluteSize", env.Vector2.new(230, 54))
		local pop = p.rt:create("TextLabel", {
			AnchorPoint = env.Vector2.new(0.5, 0.5),
			Position = env.UDim2.fromScale(0.5, 0.34),
			Size = env.UDim2.new(0.9, 0, 0, 52),
			Visible = true,
		}, p.gui)
		p.Layout.KeepBelowHud({ pop }, timer)
		local gap = p.Config.UI.BelowHudGap
		expect(topOf(pop, p.height)).toBeGreaterThanOrEqual(p.hudBottom + gap)
		timer.Visible = true
		local underTimer = p.hudBottom + 6 + 54 + gap
		expect(topOf(pop, p.height)).toBeGreaterThanOrEqual(underTimer)
		expect(topOf(pop, p.height)).toBeLessThan(underTimer + 1)
		timer.Visible = false
		expect(topOf(pop, p.height)).toBeLessThan(p.hudBottom + 6 + 54)
	end)

	it("leaves banners where they are on a tall screen", function()
		local p = screen(1280, 760, false)
		local env = p.rt.env
		local home = env.UDim2.fromScale(0.5, 0.26)
		local banner = p.rt:create("TextLabel", {
			AnchorPoint = env.Vector2.new(0.5, 0.5),
			Position = home,
			Size = env.UDim2.fromOffset(420, 110),
		}, p.gui)
		p.Layout.KeepBelowHud({ banner })
		expect(banner.Position).toBe(home)
	end)

	it("keeps the easter egg toast clear and the Secret Pumpkins panel on screen", function()
		local p = screen(640, 302, true)
		p.Config.Features.EasterEggs = true
		local EasterEggUI = p.rt:require(p.Client.EasterEggUI)
		EasterEggUI.Mount(p.gui)
		p.rt:advance(0.2)
		p.rt:fire(p.remotes.EasterEggFound, "OnClientEvent", {
			Name = "Shy Shop Pumpkin",
			Coins = 50,
			Found = 1,
			Total = 10,
		})
		local toast = p.gui.EasterEggToast
		expect(toast.Visible).toBe(true)
		expect(topOf(toast, p.height)).toBeGreaterThanOrEqual(p.hudBottom + p.Config.UI.BelowHudGap)
		EasterEggUI.Open()
		local panel = p.gui.EasterEggs
		expect(panel.Visible).toBe(true)
		-- Fits the screen as it is (the list scrolls), so Layout.Fit never shrinks its text.
		local margin = 2 * p.Config.UI.EdgeMargin
		expect(panel.Size.Y.Offset).toBeLessThanOrEqual(p.height - margin)
		expect(panel.Size.X.Offset).toBeLessThanOrEqual(p.width - margin)
	end)
end)

describe("Panels at full size on a short phone screen", function()
	local function resultRows(count: number)
		local rows = {}
		for i = 1, count do
			table.insert(rows, {
				UserId = 1000 + i,
				Name = "Player" .. i,
				Score = 20 - i,
				Pumpkins = 20 - i,
				Coins = 50,
				Survived = i % 2 == 0,
				Top = i == 1,
			})
		end
		return rows
	end

	it("fits the round results (8 players and a winner line) without shrinking", function()
		local p = screen(640, 302, true)
		p.rt:require(p.Client.ResultsUI).Mount(p.gui)
		p.rt:fire(
			p.remotes.RoundResults,
			"OnClientEvent",
			resultRows(8),
			{ ScoreLabel = "Found", Winner = "The Seekers win!" }
		)
		local panel = p.gui.Results
		expect(panel.Visible).toBe(true)
		expect(panel.Size.Y.Offset).toBeLessThanOrEqual(p.height - 2 * p.Config.UI.EdgeMargin)
		expect(panel.Mvp.Size.Y.Offset).toBe(p.Config.Results.PhoneMvpHeight)
		-- The rows scroll in the room that is left (at least one row shows).
		expect(panel.Rows.Size.Y.Offset).toBeLessThan(8 * 38)
		expect(panel.Rows.Size.Y.Offset).toBeGreaterThanOrEqual(38)
		-- Once it has slid in, it sits below the Hud, or (too tall for that) as low as it can
		-- go while staying on the screen.
		p.rt:advance(2)
		local topEdge = panel.Position.Y.Offset - panel.Size.Y.Offset / 2
		local bottomEdge = panel.Position.Y.Offset + panel.Size.Y.Offset / 2
		local margin = p.Config.UI.EdgeMargin
		expect(bottomEdge <= p.height - margin + 1).toBe(true)
		expect(topEdge >= p.hudBottom or bottomEdge >= p.height - margin - 1).toBe(true)
		-- One result row: the same rule.
		p.rt:fire(p.remotes.RoundResults, "OnClientEvent", resultRows(1), {})
		p.rt:advance(2)
		local top1 = panel.Position.Y.Offset - panel.Size.Y.Offset / 2
		local bottom1 = panel.Position.Y.Offset + panel.Size.Y.Offset / 2
		expect(top1 >= p.hudBottom or bottom1 >= p.height - margin - 1).toBe(true)
	end)

	it("keeps the full results screen on a big screen", function()
		local p = screen(1280, 760, false)
		p.rt:require(p.Client.ResultsUI).Mount(p.gui)
		p.rt:fire(p.remotes.RoundResults, "OnClientEvent", resultRows(8), {})
		local panel = p.gui.Results
		expect(panel.Mvp.Size.Y.Offset).toBe(112)
		expect(panel.Rows.Size.Y.Offset).toBe(math.min(8 * 38, p.Config.Results.MaxListHeight))
	end)

	local function voteState()
		return {
			Open = true,
			ReadyOnly = true,
			Maps = {
				{ Id = "KingHuntPatch", Name = "King Hunt: Haunted Pumpkin Patch", Votes = 2 },
				{ Id = "HideSeekFarm", Name = "Hide & Seek: Pumpkin Farm", Votes = 1 },
				{ Id = "ScareMaze", Name = "ScareMaze", Votes = 0 },
			},
			Difficulties = {
				{ Id = "Easy", Name = "Easy", Votes = 0 },
				{ Id = "Hard", Name = "Hard", Votes = 1 },
			},
		}
	end

	it("shows only the hint to a phone player who can't vote yet", function()
		local p = screen(640, 302, true)
		p.rt:require(p.Client.VoteUI).Mount(p.gui)
		p.rt:fire(p.remotes.VoteUpdate, "OnClientEvent", voteState())
		local panel = p.gui.Vote
		expect(panel.Visible).toBe(true)
		expect(panel.Hint.Visible).toBe(true)
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") and child ~= panel.Hint then
				expect(child.Visible).toBe(false)
			end
		end
		expect(p.height - 24 - panel.Size.Y.Offset).toBeGreaterThan(p.height / 2)
	end)

	it("fits the vote between the thumbstick and the jump button once you can vote", function()
		local p = screen(640, 302, true)
		p.rt:require(p.Client.VoteUI).Mount(p.gui)
		p.player:SetAttribute("Ready", true)
		p.rt:fire(p.remotes.VoteUpdate, "OnClientEvent", voteState())
		local panel = p.gui.Vote
		local ui = p.Config.UI
		expect(panel.Hint.Visible).toBe(false)
		-- As wide as the gap allows (never under 340), so Layout.Fit has nothing to shrink...
		local gap = p.width - ui.TouchBottomSideClear - ui.TouchActionsClear
		expect(panel.Size.X.Offset).toBe(math.max(gap, 340))
		expect(panel.Position.X.Offset - panel.Size.X.Offset / 2).toBe(ui.TouchBottomSideClear)
		-- ...and below the Hud (it sits 24 above the bottom edge).
		expect(p.height - 24 - panel.Size.Y.Offset).toBeGreaterThanOrEqual(p.hudBottom)
		local buttons = 0
		for _, b in panel:GetDescendants() do
			if b:IsA("TextButton") then
				buttons += 1
				local limit = b:FindFirstChildOfClass("UITextSizeConstraint")
				expect(limit).toBeTruthy()
				expect(limit.MinTextSize).toBeGreaterThanOrEqual(ui.MinTextSize)
			end
		end
		expect(buttons).toBe(5)
		-- An iPhone 14 on its side: the panel ends before the round buttons by the jump button
		-- (HEY!, Run), so a tap on "Hard" never lands on them.
		local phone = screen(749, 309, true)
		phone.rt:require(phone.Client.VoteUI).Mount(phone.gui)
		phone.player:SetAttribute("Ready", true)
		phone.rt:fire(phone.remotes.VoteUpdate, "OnClientEvent", voteState())
		local vote = phone.gui.Vote
		local right = vote.Position.X.Offset + vote.Size.X.Offset / 2
		expect(right <= phone.width - ui.TouchActionsClear).toBe(true)
		-- PC and tablets keep the wide panel.
		local pc = screen(1280, 760, false)
		pc.rt:require(pc.Client.VoteUI).Mount(pc.gui)
		pc.rt:fire(pc.remotes.VoteUpdate, "OnClientEvent", voteState())
		expect(pc.gui.Vote.Size.X.Offset).toBe(560)
		expect(pc.gui.Vote.Hint.Visible).toBe(true) -- greyed out with the hint, as before
	end)

	it("makes the spectate bar narrow enough on a phone", function()
		local p = screen(640, 302, true)
		p.Config.Features.LobbySpectate = true
		p.rt:require(p.Client.Spectate).Mount(p.gui)
		local bar = p.gui.SpectateBar
		expect(bar.Size.X.Offset).toBeLessThanOrEqual(
			p.width - 2 * p.Config.UI.TouchBottomSideClear
		)
		-- The name has its own line above the buttons.
		expect(bar.Watching.Position.Y.Offset + bar.Watching.Size.Y.Offset).toBeLessThanOrEqual(
			bar.Previous.Position.Y.Offset
		)
	end)
end)

describe("Buy buttons in view on a short phone screen", function()
	it("fits a whole shop card, Buy button included, in the list", function()
		local p = screen(640, 302, true)
		local ShopUI = p.rt:require(p.Client.ShopUI)
		ShopUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.rt:fire(p.remotes.ShopState, "OnClientEvent", {
			Ready = true,
			Coins = 500,
			Owned = {},
			Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" },
			Vip = false,
		})
		ShopUI.Open("Skin")
		p.rt:advance(0.5)
		local panel = p.gui.Shop
		local list = panel:FindFirstChild("ScrollingFrame")
		local grid = list:FindFirstChildOfClass("UIGridLayout")
		-- The list's height on this screen: the panel (0.97 of it) minus the bars around it.
		expect(list.Size.Y.Scale).toBe(1)
		local listHeight = p.height * 0.97 + list.Size.Y.Offset
		T.note(("list %.0f tall, cards %d tall"):format(listHeight, grid.CellSize.Y.Offset))
		expect(grid.CellSize.Y.Offset).toBeLessThanOrEqual(listHeight)
		local cards = 0
		for _, card in list:GetChildren() do
			if card:IsA("Frame") and card:FindFirstChild("RarityBorder") then
				cards += 1
				local preview = card:FindFirstChildOfClass("ViewportFrame")
				expect(preview.Size.Y.Offset).toBeGreaterThanOrEqual(30)
				-- The one-line name sits between the preview and the button, overlapping neither.
				local label = nil
				local action = nil
				for _, child in card:GetChildren() do
					if child:IsA("TextLabel") and child.Name == "TextLabel" then
						label = child
					elseif child:IsA("TextButton") then
						action = child
					end
				end
				local nameBottom = label.Position.Y.Offset + label.Size.Y.Offset
				local buttonTop = card.Size.Y.Offset + action.Position.Y.Offset
				expect(label.Position.Y.Offset).toBeGreaterThanOrEqual(preview.Size.Y.Offset)
				expect(nameBottom).toBeLessThanOrEqual(buttonTop)
				-- A price always says what it costs in (honest labels): "Buy 500 Coins".
				for _, b in card:GetDescendants() do
					if b:IsA("TextButton") and b.Text:find("^Buy") then
						expect(b.Text:find(p.Config.Economy.CurrencyName, 1, true)).toBeTruthy()
					end
				end
				expect(card.Size.Y.Offset).toBe(grid.CellSize.Y.Offset)
			end
		end
		expect(cards).toBeGreaterThan(0)
		panel.Visible = false
		p.rt:advance(0.1)
	end)

	it("tucks a smaller rarity tag into the card's corner on phones", function()
		local function firstTag(width: number, height: number, touch: boolean)
			local p = screen(width, height, touch)
			local ShopUI = p.rt:require(p.Client.ShopUI)
			ShopUI.Mount(p.gui)
			p.rt:advance(0.5)
			p.rt:fire(p.remotes.ShopState, "OnClientEvent", {
				Ready = true,
				Coins = 500,
				Owned = {},
				Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" },
				Vip = false,
			})
			ShopUI.Open("Skin")
			p.rt:advance(0.5)
			local tag = p.gui.Shop:FindFirstChild("RarityTag", true)
			expect(tag).toBeTruthy()
			return tag, p.Config
		end
		local phone, Config = firstTag(640, 302, true)
		local pc = firstTag(1280, 760, false)
		T.note(
			("phone tag %d tall, text %d, at %d; PC %d tall, text %d, at %d"):format(
				phone.Size.Y.Offset,
				phone.TextSize,
				phone.Position.X.Offset,
				pc.Size.Y.Offset,
				pc.TextSize,
				pc.Position.X.Offset
			)
		)
		expect(phone.TextSize).toBeGreaterThanOrEqual(Config.UI.MinTextSize)
		expect(phone.TextSize).toBeLessThanOrEqual(pc.TextSize)
		expect(phone.Size.Y.Offset).toBeLessThan(pc.Size.Y.Offset)
		expect(phone.Position.X.Offset).toBeLessThan(pc.Position.X.Offset)
		expect(phone.Position.Y.Offset).toBeLessThan(pc.Position.Y.Offset)
		local phonePad = phone:FindFirstChildOfClass("UIPadding").PaddingLeft.Offset
		local pcPad = pc:FindFirstChildOfClass("UIPadding").PaddingLeft.Offset
		expect(phonePad).toBeLessThan(pcPad)
	end)

	it("pins the crate's Open buttons under the scrolling column, with the luck line", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
		p.Config.Features.CrateLuck = true
		p.Config.Features.CratePacks = true
		-- The server's state: this player's Pumpkin Crate luck meter is at 4.
		p.remotes.GetShopState.OnServerInvoke = function()
			return {
				Ready = true,
				Coins = 5000,
				Owned = {},
				Equipped = {},
				Vip = false,
				CrateLuck = { PumpkinCrate = 4 },
				LuckVersion = 1,
			}
		end
		local CrateUI = p.rt:require(p.Client.CrateUI)
		CrateUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.player:SetAttribute("CratesRestricted", false)
		CrateUI.Open("PumpkinCrate")
		p.rt:advance(0.2)
		local preview = p.gui.Crates.Body.Preview
		expect(preview.Side:FindFirstChild("Buy")).toBeNil()
		local pinned = preview.Buttons
		expect(pinned.AnchorPoint.Y).toBe(1)
		expect(pinned.Buy.OpenCoins).toBeInstanceOf("TextButton")
		expect(pinned.Buy.OpenCoins.Text).toMatch("600") -- (not "Checking...": luck is known)
		expect(pinned.Nav.Back).toBeInstanceOf("TextButton")
		-- The luck strip scrolls in the column; its one-line summary is pinned right above the
		-- buy buttons, so it is always in view.
		local luck = preview.Side:FindFirstChild("Luck")
		expect(luck).toBeTruthy()
		expect(luck:FindFirstChild("Help", true)).toBeNil() -- (the help is in Every chance)
		expect(preview.Side:FindFirstChild("Packs")).toBeTruthy()
		expect(preview.Side:FindFirstChild("LuckLine", true)).toBeNil()
		local line = pinned.LuckLine
		expect(line.Text).toBe("Luck 4/15 · Rare or better 23.02%")
		expect(line.LayoutOrder).toBeLessThan(pinned.Buy.LayoutOrder)
		-- The pinned strip holds every visible row and the 6 px gaps between them.
		local rows, height = 0, 0
		for _, child in pinned:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				rows += 1
				height += child.Size.Y.Offset
			end
		end
		expect(rows).toBe(4) -- LuckLine, Buy, Extras, Nav
		expect(pinned.Size.Y.Offset).toBeGreaterThanOrEqual(height + 6 * (rows - 1))
		-- The column above stops where the buttons start.
		expect(preview.Side.Size.Y.Offset).toBe(-(pinned.Size.Y.Offset + 6))
		-- Every new piece stays inside its column, and no text is too small.
		local minText = p.Config.UI.MinTextSize
		for _, piece in { luck, preview.Side.Packs, line } do
			expect(piece.Size.X.Scale).toBeLessThanOrEqual(1)
			expect(piece.Size.X.Offset).toBeLessThanOrEqual(0)
			for _, d in piece:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					expect(d.TextSize).toBeGreaterThanOrEqual(minText)
				end
			end
		end
		expect(line.TextSize).toBeGreaterThanOrEqual(minText)
		expect(line.TextWrapped).toBe(true)
		-- Every chance on a phone: the rows wrap.
		p.rt:fire(luck:FindFirstChild("EveryChance", true), "Activated")
		local row = preview.LuckTable.Rows.Row4
		expect(row.TextWrapped).toBe(true)
		expect(row.AutomaticSize).toBe(p.rt.env.Enum.AutomaticSize.Y)
		p.rt:fire(preview.LuckTable.Back, "Activated")
		-- The pack window: its buttons in a row at the bottom.
		p.rt:fire(pinned.Buy.OpenCoins10, "Activated")
		local window = preview.PackConfirm
		expect(window.Buttons.Size.Y.Offset).toBe(36)
		expect(window.Buttons.Confirm).toBeInstanceOf("TextButton")
		p.rt:fire(window.Buttons.Cancel, "Activated")
		-- Restricted players: no buy row, no luck line, a shorter pinned strip.
		p.player:SetAttribute("CratesRestricted", true)
		p.rt:advance(0.1)
		expect(preview.Buttons.Buy.Visible).toBe(false)
		expect(preview.Buttons:FindFirstChild("LuckLine")).toBeNil()
		expect(preview.Side:FindFirstChild("Luck")).toBeNil()
		expect(preview.Side:FindFirstChild("Packs")).toBeNil()
		expect(preview.Buttons.Size.Y.Offset).toBe(32)
		p.player:SetAttribute("CratesRestricted", false)
		p.rt:advance(0.1)
		-- A crate without a meter keeps today's pinned height (no luck line).
		CrateUI.Open("CommonCrate")
		p.rt:advance(0.1)
		expect(preview.Buttons:FindFirstChild("LuckLine")).toBeNil()
		expect(preview.Buttons.Size.Y.Offset).toBe((40 + 6) + (34 + 6) + 32)
	end)

	it("builds 3D pictures only on the cards the slowing strip shows", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
		p.Config.Crates.Opening.Style = "Reel" -- (the spinning strip, not the chest)
		local reelCfg = p.Config.Crates.Reel
		local CrateUI = p.rt:require(p.Client.CrateUI)
		CrateUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.player:SetAttribute("CratesRestricted", false)
		CrateUI.Open("PumpkinCrate")
		local reel = {}
		for i = 1, reelCfg.Cards do
			reel[i] = if i % 2 == 0 then "Pumpkin_PumpkinSpice" else "Pumpkin_SirGourdington"
		end
		reel[reelCfg.WinIndex] = "Pumpkin_SirGourdington"
		p.rt:fire(p.remotes.CrateResult, "OnClientEvent", {
			Ok = true,
			Message = "",
			CrateId = "PumpkinCrate",
			ItemId = "Pumpkin_SirGourdington",
			ItemName = "Sir Gourdington",
			Rarity = "Uncommon",
			Reel = reel,
			WinIndex = reelCfg.WinIndex,
			Paid = "Coins",
		})
		p.rt:advance(reelCfg.SpinSeconds + 0.1)
		local opening = p.gui.Crates.Body.Opening
		local strip = opening.Reel.Strip
		local built = {}
		for i = 1, reelCfg.Cards do
			if strip["Card" .. i].Art:FindFirstChild("Preview") then
				table.insert(built, i)
			end
		end
		T.note(("cards with a 3D picture: %s"):format(table.concat(built, ", ")))
		expect(#built).toBeGreaterThan(1)
		expect(#built).toBeLessThan(reelCfg.Cards // 2) -- (every card passing got one before)
		expect(strip["Card" .. reelCfg.WinIndex].Art:FindFirstChild("Preview")).toBeTruthy()
		expect(strip.Card2.Art:FindFirstChild("Preview")).toBeNil() -- whizzed past at full speed

		-- The reveal card's picture takes only the room the buttons leave.
		p.rt:advance(reelCfg.RevealDelay + 0.5)
		local card = opening.Reveal.Card
		expect(card.Art.Size.Y.Scale).toBe(1)
		local limit = card.Art:FindFirstChildOfClass("UISizeConstraint")
		expect(limit.MaxSize.Y).toBe(92)
		expect(card.Buttons.Equip).toBeInstanceOf("TextButton")
		p.gui.Crates.Visible = false
		p.rt:advance(0.1)
	end)
end)

describe("The crate panel's room on a phone", function()
	it("drops the hint line so the crates get the room, but keeps real messages", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
		local CrateUI = p.rt:require(p.Client.CrateUI)
		CrateUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.player:SetAttribute("CratesRestricted", false)
		CrateUI.Open()
		p.rt:advance(0.2)
		local panel = p.gui.Crates
		local message = panel.Message
		expect(message.Text).toBe(p.Config.Crates.Text.Hint)
		expect(message.Visible).toBe(false)
		expect(panel.Body.Position.Y.Offset).toBe(46) -- straight under the title row
		-- A message that matters (here the region rule) shows, and the body makes room again.
		p.player:SetAttribute("CratesRestricted", true)
		p.rt:advance(0.2)
		expect(message.Text).toBe(p.Config.Crates.Text.Restricted)
		expect(message.Visible).toBe(true)
		expect(panel.Body.Position.Y.Offset).toBeGreaterThan(46)
		p.player:SetAttribute("CratesRestricted", false)
		p.rt:advance(0.2)
	end)

	it("keeps a crate page's left column full height while a message shows", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
		p.Config.Features.CrateLuck = true
		p.Config.Features.CratePacks = true
		p.remotes.GetShopState.OnServerInvoke = function()
			return {
				Ready = true,
				Coins = 50,
				Owned = {},
				Equipped = {},
				Vip = false,
				CrateLuck = { PumpkinCrate = 4 },
				LuckVersion = 1,
			}
		end
		local text = p.Config.Crates.Text
		local noCoins = text.NoCoins:format(550, p.Config.Economy.CurrencyName)
		p.remotes.OpenCrate.OnServerInvoke = function(_player, crateId)
			return { Ok = false, Message = noCoins, CrateId = crateId, Luck = 4, LuckVersion = 1 }
		end
		local CrateUI = p.rt:require(p.Client.CrateUI)
		CrateUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.player:SetAttribute("CratesRestricted", false)
		CrateUI.Open("PumpkinCrate")
		p.rt:advance(0.2)
		local panel = p.gui.Crates
		local message = panel.Message
		local preview = panel.Body.Preview
		expect(message.Visible).toBe(false)
		local column = preview.Side.Size.Y.Offset
		-- A refusal ("You need 550 more Coins"): the line shows over the skins on the right, so
		-- the page (and its left column: the crate, its luck and the buttons) keeps its height.
		p.rt:fire(preview.Buttons.Buy.OpenCoins, "Activated")
		p.rt:advance(0.5)
		expect(message.Text).toBe(noCoins)
		expect(message.Visible).toBe(true)
		expect(panel.Body.Position.Y.Offset).toBe(46)
		expect(preview.Side.Size.Y.Offset).toBe(column)
		local skins = preview.Items
		local body = panel.Body.Position
		expect(message.Position.X.Offset).toBeGreaterThanOrEqual(
			body.X.Offset + skins.Position.X.Offset
		)
		expect(message.Position.Y.Offset + message.Size.Y.Offset).toBeLessThanOrEqual(
			body.Y.Offset + skins.Position.Y.Offset
		)
		-- Every chance covers the page: the line waits and the window gets the whole page.
		p.rt:fire(preview.Side.Luck:FindFirstChild("EveryChance", true), "Activated")
		p.rt:advance(0.1)
		expect(preview.LuckTable).toBeTruthy()
		expect(message.Visible).toBe(false)
		expect(panel.Body.Position.Y.Offset).toBe(46)
		p.rt:fire(preview.LuckTable.Back, "Activated")
		p.rt:advance(0.1)
		expect(message.Visible).toBe(true)
		-- The crate list: the line back in its usual place, the list makes room for it.
		p.rt:fire(preview.Buttons.Nav.Back, "Activated")
		p.rt:advance(0.1)
		message.Text = noCoins
		p.rt:advance(0.1)
		expect(message.Visible).toBe(true)
		expect(message.Position.X.Offset).toBe(16)
		expect(panel.Body.Position.Y.Offset).toBeGreaterThan(46)
		p.gui.Crates.Visible = false
		p.rt:advance(0.1)
	end)
end)

describe("The owner panel on a phone", function()
	it("gives admins an Admin button instead of F8, and it opens the panel", function()
		local p = screen(749, 309, true)
		p.player:SetAttribute("Admin", true)
		p.rt:require(p.Client.AdminUI).Mount(p.gui)
		local button = p.gui:FindFirstChild("AdminButton")
		expect(button).toBeInstanceOf("TextButton")
		expect(button.Visible).toBe(true)
		p.rt:fire(button, "Activated")
		expect(p.gui.Admin.Visible).toBe(true)
		p.rt:fire(button, "Activated")
		expect(p.gui.Admin.Visible).toBe(false)
	end)
end)
