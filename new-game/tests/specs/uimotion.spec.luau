-- Animated UI (src/client/UIMotion.luau, Config.UI.Motion): pop in / pop out end at full size
-- with the right Visible, interrupting never leaves a gui hidden or tiny, pressing keeps
-- Activated working, rolling numbers end exactly on the target, Motion.On = false makes it all
-- instant, PanelManager panels still open / close / Escape at once (the pop-out is a ghost
-- copy), the Hud's coins roll and float "+N", the Menu's tiles pop in one after another, and
-- the Hud's details never get cut off (they grow the bar, then wrap).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum :: any
local Vector2 = roblox.Vector2
local Color3 = roblox.Color3

local describe, it, expect = T.describe, T.it, T.expect

local function client(width: number?, height: number?, input: any?)
	local rt = Runtime.new({ client = true, input = input })
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	if width and height then
		Dom.rawSet(gui, "AbsoluteSize", rt.env.Vector2.new(width, height))
	end
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	return {
		rt = rt,
		gui = gui,
		player = player,
		Client = Client,
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		UIMotion = rt:require(Client.UIMotion),
		Theme = rt:require(Client.Theme),
	}
end

-- The motion factor a gui shows right now (1 = normal size).
local function scaleOf(gui: any): number
	local fit = gui:FindFirstChild("FitScale")
	if fit then
		return fit.Scale
	end
	local own = gui:FindFirstChild("MotionScale")
	return if own then own.Scale else 1
end

local function fakeInput(kind: string): any
	return { UserInputType = (Enum.UserInputType :: any)[kind], KeyCode = Enum.KeyCode.Unknown }
end

describe("UIMotion", function()
	local w = client()
	local M = w.Config.UI.Motion
	local wait = math.max(M.PopInSeconds, M.PopOutSeconds) + 0.05

	it("pops in to full size and out to hidden at full size", function()
		local frame = w.rt:create("Frame", { Name = "Box", Visible = false }, w.gui)
		w.UIMotion.PopIn(frame)
		expect(frame.Visible).toBe(true)
		expect(scaleOf(frame)).toBeNear(M.PopFrom, 1e-6) -- starts small
		w.rt:advance(wait)
		expect(scaleOf(frame)).toBeNear(1, 1e-6)
		local done = false
		w.UIMotion.PopOut(frame, function()
			done = true
		end)
		expect(frame.Visible).toBe(true) -- still shrinking
		w.rt:advance(wait)
		expect(frame.Visible).toBe(false)
		expect(done).toBe(true)
		expect(scaleOf(frame)).toBeNear(1, 1e-6) -- ready for the next pop in
	end)

	it("ends visible at full size when a PopIn interrupts a PopOut", function()
		local frame = w.rt:create("Frame", { Name = "Box2" }, w.gui)
		local closed = false
		w.UIMotion.PopOut(frame, function()
			closed = true
		end)
		w.rt:advance(M.PopOutSeconds / 2)
		w.UIMotion.PopIn(frame)
		w.rt:advance(wait * 2)
		expect(frame.Visible).toBe(true)
		expect(closed).toBe(false)
		expect(scaleOf(frame)).toBeNear(1, 1e-6)
		-- ...and the other way round: a PopOut cut short by another PopOut still hides.
		w.UIMotion.PopOut(frame)
		w.UIMotion.PopOut(frame)
		w.rt:advance(wait)
		expect(frame.Visible).toBe(false)
		expect(scaleOf(frame)).toBeNear(1, 1e-6)
	end)

	it("animates a Layout.Fit panel through MotionScale without breaking its fit", function()
		local panel = w.rt:create("Frame", { Name = "Fitted", Visible = false }, w.gui)
		w.rt:require(w.Client.Layout).Fit(panel)
		w.UIMotion.PopIn(panel)
		expect(panel:GetAttribute("MotionScale")).toBeNear(M.PopFrom, 1e-6)
		expect(panel.FitScale.Scale).toBeNear(M.PopFrom, 1e-6)
		expect(#panel:GetChildren()).toBe(1) -- no second UIScale
		w.rt:advance(wait)
		expect(panel:GetAttribute("MotionScale")).toBeNil()
		expect(panel.FitScale.Scale).toBeNear(1, 1e-6)
	end)

	it("leaves a gui with its own UIScale alone", function()
		local card = w.rt:create("Frame", { Name = "Card", Visible = false }, w.gui)
		local own = w.rt:create("UIScale", { Name = "CardScale", Scale = 0.5 }, card)
		w.UIMotion.PopIn(card)
		w.rt:advance(wait)
		expect(card.Visible).toBe(true)
		expect(own.Scale).toBe(0.5)
		expect(#card:GetChildren()).toBe(1)
	end)

	it("squashes Theme buttons when pressed and keeps Activated working", function()
		local clicks = 0
		local button = w.Theme.button("Go", w.gui)
		button.Activated:Connect(function()
			clicks += 1
		end)
		expect(button:FindFirstChild("MotionScale")).toBeNil() -- nothing added until used
		w.rt:fire(button, "InputBegan", fakeInput("Touch"))
		w.rt:advance(M.PressSeconds + 0.02)
		expect(scaleOf(button)).toBeNear(M.PressScale, 1e-6)
		w.rt:fire(button, "Activated")
		w.rt:fire(button, "InputEnded", fakeInput("Touch"))
		w.rt:advance(M.HoverSeconds + 0.02)
		expect(clicks).toBe(1)
		expect(scaleOf(button)).toBeNear(1, 1e-6)
		w.UIMotion.Press(button) -- twice is harmless
		w.rt:fire(button, "Activated")
		expect(clicks).toBe(2)
	end)

	it("never grows a button under the 'mouse' on a touch screen", function()
		local touch = client(nil, nil, { TouchEnabled = true })
		local button = touch.Theme.button("Tap", touch.gui)
		touch.rt:fire(button, "MouseEnter", 0, 0)
		touch.rt:advance(M.HoverSeconds + 0.02)
		expect(scaleOf(button)).toBeNear(1, 1e-6)
		-- ...while a PC mouse does.
		local mouse = w.Theme.button("Point", w.gui)
		w.rt:fire(mouse, "MouseEnter", 0, 0)
		w.rt:advance(M.HoverSeconds + 0.02)
		expect(scaleOf(mouse)).toBeNear(M.HoverScale, 1e-6)
		w.rt:fire(mouse, "MouseLeave", 0, 0)
		w.rt:advance(M.HoverSeconds + 0.02)
		expect(scaleOf(mouse)).toBeNear(1, 1e-6)
	end)

	it("bumps and wobbles back to normal", function()
		local frame = w.rt:create("Frame", { Name = "Bump" }, w.gui)
		w.UIMotion.Bump(frame)
		w.rt:advance(M.BumpSeconds * 2 + 0.05)
		expect(scaleOf(frame)).toBeNear(1, 1e-6)
		w.UIMotion.Wobble(frame)
		expect(frame.Rotation).never.toBe(0)
		w.rt:advance(M.WobbleSeconds * 2 * M.WobbleTimes + 0.1)
		expect(frame.Rotation).toBe(0)
	end)

	it("rolls a number to exactly its target, even when interrupted", function()
		local label = w.rt:create("TextLabel", { Name = "Count" }, w.gui)
		w.UIMotion.CountTo(label, 0, 1234)
		expect(label.Text).toBe("0")
		w.rt:advance(M.CountSeconds + 0.05)
		expect(label.Text).toBe("1,234")
		w.UIMotion.CountTo(label, 1234, 5000)
		w.rt:advance(M.CountSeconds / 3)
		w.UIMotion.CountTo(label, 1500, 77, function(n)
			return ("%d coins"):format(n)
		end)
		w.rt:advance(M.CountSeconds * 2)
		expect(label.Text).toBe("77 coins")
		expect(w.UIMotion.Commas(-1234567)).toBe("-1,234,567")
		expect(w.UIMotion.Commas(999)).toBe("999")
	end)

	it("floats text away and removes it", function()
		local frame = w.rt:create("Frame", { Name = "Floaty" }, w.gui)
		local label = w.UIMotion.FloatText(frame, "+50", Color3.new(1, 1, 0))
		expect(label).toBeTruthy()
		expect(label.Parent).toBe(frame)
		w.rt:advance(M.FloatSeconds + 0.05)
		expect(frame:FindFirstChild("FloatText")).toBeNil()
	end)
end)

describe("UIMotion with Config.UI.Motion.On = false", function()
	local w = client()
	w.Config.UI.Motion.On = false

	it("does everything at once", function()
		local frame = w.rt:create("Frame", { Name = "Box", Visible = false }, w.gui)
		w.UIMotion.PopIn(frame)
		expect(frame.Visible).toBe(true)
		expect(scaleOf(frame)).toBe(1)
		local done = false
		w.UIMotion.PopOut(frame, function()
			done = true
		end)
		expect(frame.Visible).toBe(false)
		expect(done).toBe(true)
		local label = w.rt:create("TextLabel", { Name = "Count" }, w.gui)
		w.UIMotion.CountTo(label, 0, 500)
		expect(label.Text).toBe("500")
		expect(w.UIMotion.FloatText(frame, "+5", Color3.new(1, 1, 1))).toBeNil()
		w.UIMotion.Wobble(frame)
		expect(frame.Rotation).toBe(0)
	end)

	it("closes PanelManager panels without a ghost", function()
		local PanelManager = w.rt:require(w.Client.PanelManager)
		PanelManager.Mount(w.gui)
		local panel = w.rt:create("Frame", { Name = "Shop", Visible = false }, w.gui)
		w.rt:flush()
		panel.Visible = true
		expect(scaleOf(panel)).toBe(1)
		PanelManager.CloseTop()
		expect(panel.Visible).toBe(false)
		local ghosts = w.player.PlayerGui:FindFirstChild("PanelGhosts")
		expect(ghosts == nil or #ghosts:GetChildren() <= 1).toBe(true) -- (its UIScale only)
	end)
end)

describe("PanelManager with motion", function()
	local w = client()
	local M = w.Config.UI.Motion
	local PanelManager = w.rt:require(w.Client.PanelManager)
	PanelManager.Mount(w.gui)
	local shop = w.rt:create("Frame", { Name = "Shop", Visible = false }, w.gui)
	local settings = w.rt:create("Frame", { Name = "Settings", Visible = false }, w.gui)
	w.rt:create("TextLabel", { Name = "Words", Text = "hello" }, shop)
	w.rt:flush() -- registered by name (AUTO_NAMES)

	local function ghostLayer(): any
		return w.player.PlayerGui:FindFirstChild("PanelGhosts")
	end

	it("pops a panel in when it opens", function()
		shop.Visible = true
		expect(PanelManager.Top()).toBe(shop)
		expect(scaleOf(shop)).toBeNear(M.PopFrom, 1e-6)
		w.rt:advance(M.PopInSeconds + 0.05)
		expect(scaleOf(shop)).toBeNear(1, 1e-6)
	end)

	it("hides at once when another opens, and a ghost copy shrinks away", function()
		settings.Visible = true
		expect(shop.Visible).toBe(false) -- one at a time, straight away
		expect(PanelManager.Top()).toBe(settings)
		local layer = ghostLayer()
		expect(layer).toBeInstanceOf("ScreenGui")
		local ghost = layer:FindFirstChild("PanelGhost")
		expect(ghost).toBeTruthy()
		expect(ghost.Visible).toBe(true)
		expect(ghost.Words.Text).toBe("hello")
		expect(w.gui:FindFirstChild("PanelGhost")).toBeNil() -- never inside the game UI
		w.rt:advance(M.PopOutSeconds + 0.05)
		expect(layer:FindFirstChild("PanelGhost")).toBeNil()
	end)

	it("CloseTop, Escape and CloseAll still close at once", function()
		expect(PanelManager.CloseTop()).toBe(true)
		expect(settings.Visible).toBe(false)
		expect(PanelManager.Top()).toBeNil()
		shop.Visible = true
		w.rt:advance(1)
		local uis = w.rt.game:GetService("UserInputService")
		w.rt:fire(
			uis,
			"InputBegan",
			{ KeyCode = Enum.KeyCode.Escape, UserInputType = Enum.UserInputType.Keyboard },
			false
		)
		expect(shop.Visible).toBe(false)
		settings.Visible = true
		PanelManager.CloseAll()
		expect(settings.Visible).toBe(false)
		expect(PanelManager.CloseTop()).toBe(false)
		-- Reopened while its ghost still shrinks: its ghost goes, the panel is full size.
		local before = #ghostLayer():GetChildren()
		settings.Visible = true
		expect(#ghostLayer():GetChildren()).toBe(before - 1)
		w.rt:advance(M.PopInSeconds + 0.05)
		expect(settings.Visible).toBe(true)
		expect(scaleOf(settings)).toBeNear(1, 1e-6)
		settings.Visible = false
		w.rt:advance(1)
	end)

	it("closes whatever is open when you're pulled into a round", function()
		shop.Visible = true
		w.rt:advance(1)
		w.player:SetAttribute("InRound", true)
		w.rt:flush()
		expect(shop.Visible).toBe(false)
		expect(PanelManager.Top()).toBeNil()
		w.player:SetAttribute("InRound", nil) -- back in the lobby: nothing reopens
		w.rt:flush()
		expect(shop.Visible).toBe(false)
		w.rt:advance(1)
	end)
end)

describe("Hud coins", function()
	local w = client(1280, 720)
	local M = w.Config.UI.Motion
	local icon = w.Config.UI.Hud.CoinsIcon
	w.rt:require(w.Client.Hud).Mount(w.gui)
	local hud = w.gui.Hud
	local stats = w.rt:create("Folder", { Name = "leaderstats" }, w.player)
	local coins = w.rt:create("IntValue", { Name = "Coins", Value = 100 }, stats)

	it("shows the coins once leaderstats arrive", function()
		expect(hud.Coins.Visible).toBe(true)
		expect(hud.Coins.Amount.Text).toBe(icon .. " 100")
	end)

	it("rolls up to the exact new value and floats +N on a gain", function()
		coins.Value = 1350
		expect(hud.Coins:FindFirstChild("FloatText")).toBeTruthy()
		expect(hud.Coins.FloatText.Text).toBe("+1,250")
		w.rt:advance(math.max(M.CountSeconds, M.FloatSeconds) + 0.1)
		expect(hud.Coins.Amount.Text).toBe(icon .. " 1,350")
		expect(hud.Coins:FindFirstChild("FloatText")).toBeNil()
	end)

	it("just rolls down on a loss", function()
		coins.Value = 350
		expect(hud.Coins:FindFirstChild("FloatText")).toBeNil()
		w.rt:advance(M.CountSeconds / 2)
		coins.Value = 360 -- a change mid-roll still ends exactly right
		w.rt:advance(M.CountSeconds + 0.1)
		expect(hud.Coins.Amount.Text).toBe(icon .. " 360")
	end)
end)

describe("Hud details never cut off", function()
	local LONG =
		"Spooky Mansion  |  Easy  |  Pumpkins: 0  |  Survivors: 1  |  The King is coming..."

	it("grows the bar on a PC screen so the whole line fits", function()
		local w = client(1329, 760)
		local Hud = w.rt:require(w.Client.Hud)
		local cfg = w.Config.UI.Hud
		local m = Hud.Measure("King Hunt  4:59", LONG, 1329)
		expect(m.Fits).toBe(true)
		expect(m.DetailLines).toBe(1)
		expect(m.DetailSize).toBe(cfg.DetailSize)
		local text = w.rt.game:GetService("TextService")
		local need = text:GetTextSize(
			LONG,
			m.DetailSize,
			Enum.Font.GothamBold,
			Vector2.new(math.huge, math.huge)
		).X
		expect(m.Width - 2 * cfg.Padding).toBeGreaterThanOrEqual(need)
		expect(m.Width).toBeLessThanOrEqual(cfg.MaxWidth)

		-- Mounted, in a real King Hunt round.
		local rs = w.rt.game:GetService("ReplicatedStorage")
		Hud.Mount(w.gui)
		rs:SetAttribute("State", "Playing")
		rs:SetAttribute("Mode", "KingHunt")
		rs:SetAttribute("ModeName", "King Hunt")
		rs:SetAttribute("MapName", "Spooky Mansion")
		rs:SetAttribute("Difficulty", "Easy")
		rs:SetAttribute("Alive", 1)
		w.player:SetAttribute("InRound", true)
		local detail = w.gui.Hud.Detail
		expect(detail.Text).toBe(LONG)
		expect(w.gui.Hud.Size.X.Offset - 2 * cfg.Padding).toBeGreaterThanOrEqual(need)
		expect(detail.TextSize).toBe(cfg.DetailSize)
	end)

	it("wraps onto two lines on a narrow phone, text never below MinTextSize", function()
		local w = client(360, 640)
		local Hud = w.rt:require(w.Client.Hud)
		local cfg = w.Config.UI.Hud
		local m = Hud.Measure("King Hunt  4:59", LONG, 360)
		expect(m.Width).toBeLessThanOrEqual(360 - 2 * w.Config.UI.EdgeMargin) -- no Fit shrink
		expect(m.DetailSize).toBeGreaterThanOrEqual(w.Config.UI.MinTextSize)
		expect(m.TitleSize).toBeGreaterThanOrEqual(w.Config.UI.MinTextSize)
		expect(m.DetailLines).toBe(2)
		expect(m.Fits).toBe(true)
		expect(m.Height).toBeGreaterThan(64)
		local text = w.rt.game:GetService("TextService")
		local wrapped = text:GetTextSize(
			LONG,
			m.DetailSize,
			Enum.Font.GothamBold,
			Vector2.new(m.Width - 2 * cfg.Padding, math.huge)
		).Y
		expect(m.DetailHeight).toBeGreaterThanOrEqual(wrapped)
		-- A short line keeps the usual one-line bar.
		local short = Hud.Measure("Voting  0:20", "Pumpkin Patch", 360)
		expect(short.DetailLines).toBe(1)
		expect(short.Height).toBe(64)
	end)
end)

describe("Menu motion", function()
	local w = client()
	local M = w.Config.UI.Motion
	local MenuUI = w.rt:require(w.Client.MenuUI)
	w.rt:require(w.Client.PanelManager).Mount(w.gui)
	for i = 1, 4 do
		MenuUI.AddTile({
			Id = "Motion" .. i,
			Label = "Tile " .. i,
			Order = 40 + i,
			OnClick = function() end,
		})
	end
	MenuUI.Mount(w.gui)

	local function tile(i: number): any
		return w.gui.Menu.Tiles:FindFirstChild("Motion" .. i .. "Tile")
	end

	it("wobbles the Menu button once, a little after joining", function()
		local button = w.player.PlayerGui:FindFirstChild("MenuButton", true)
		expect(button).toBeTruthy()
		w.rt:advance(M.WobbleDelay + 0.01)
		expect(button.Rotation).never.toBe(0)
		w.rt:advance(M.WobbleSeconds * 2 * M.WobbleTimes + 0.1)
		expect(button.Rotation).toBe(0)
	end)

	it("pops the tiles in one after another when the Menu opens", function()
		MenuUI.Open()
		expect(MenuUI.IsOpen()).toBe(true)
		for i = 1, 4 do
			expect(scaleOf(tile(i))).toBeNear(M.PopFrom, 1e-6)
		end
		-- The first has finished before the last one has.
		w.rt:advance(M.PopInSeconds + 0.01)
		expect(scaleOf(tile(1))).toBeNear(1, 1e-6)
		expect(scaleOf(tile(4))).toBeLessThan(1)
		w.rt:advance(M.TileStagger * 4 + 0.05)
		for i = 1, 4 do
			expect(scaleOf(tile(i))).toBeNear(1, 1e-6)
		end
		MenuUI.Close()
		expect(MenuUI.IsOpen()).toBe(false)
	end)
end)
