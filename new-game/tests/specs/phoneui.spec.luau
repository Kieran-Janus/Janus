-- Phone layouts (fixes from the v2 review): on a short landscape phone (640 x 302 usable UI
-- units, the top bar taken off) banners stay under the Hud, the results, vote, spectate and
-- Secret Pumpkins panels fit at full size (no text shrunk below Config.UI.MinTextSize), the
-- shop's and the crate panel's Buy buttons are in view without scrolling, and the crate strip
-- only builds 3D pictures once it slows down.
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
				expect(card.Size.Y.Offset).toBe(grid.CellSize.Y.Offset)
			end
		end
		expect(cards).toBeGreaterThan(0)
		panel.Visible = false
		p.rt:advance(0.1)
	end)

	it("pins the crate's Open buttons under the scrolling column", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
		local CrateUI = p.rt:require(p.Client.CrateUI)
		CrateUI.Mount(p.gui)
		p.rt:advance(0.5)
		p.player:SetAttribute("CratesRestricted", false)
		CrateUI.Open("PumpkinCrate")
		local preview = p.gui.Crates.Body.Preview
		expect(preview.Side:FindFirstChild("Buy")).toBeNil()
		local pinned = preview.Buttons
		expect(pinned.AnchorPoint.Y).toBe(1)
		expect(pinned.Buy.OpenCoins).toBeInstanceOf("TextButton")
		expect(pinned.Nav.Back).toBeInstanceOf("TextButton")
		-- The column above stops where the buttons start.
		expect(preview.Side.Size.Y.Offset).toBe(-(pinned.Size.Y.Offset + 6))
		-- Restricted players: no buy row, a shorter pinned strip.
		p.player:SetAttribute("CratesRestricted", true)
		p.rt:advance(0.1)
		expect(preview.Buttons.Buy.Visible).toBe(false)
		expect(preview.Buttons.Size.Y.Offset).toBe(32)
		p.player:SetAttribute("CratesRestricted", false)
		p.rt:advance(0.1)
	end)

	it("builds 3D pictures only on the cards the slowing strip shows", function()
		local p = screen(640, 302, true)
		p.Config.Features.Crates = true
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
