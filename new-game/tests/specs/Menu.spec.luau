-- The top-left Menu: Config.Menu is complete, side buttons become the right tiles, the tile
-- grid fits every screen, the Menu button never covers the Hud (src/client/MenuLogic.luau),
-- and the mounted Menu adds, replaces, opens and closes tiles (src/client/MenuUI.luau).
-- (modules.spec checks the real tiles after Main.client.luau runs against a server.)

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local client = Runtime.new({ client = true })
local Vector2 = client.env.Vector2
local typeof = Runtime.typeof
local Config = client:require("ReplicatedStorage.Shared.Config")
local folder = client:find("StarterPlayer.StarterPlayerScripts.Client")
local MenuLogic = client:require(folder.MenuLogic)
local margin = Config.UI.EdgeMargin

-- The Hud as src/client/Hud.luau draws it: 520 x 64 at the top middle (Position 0.5, 0.02),
-- shrunk by Layout.Fit when it doesn't fit. Returns left, top, width, height in UI units.
local function hudRect(screen: any, margin: number): (number, number, number, number)
	local width, height = 520, 64
	local s = math.min(1, (screen.X - 2 * margin) / width, (screen.Y - 2 * margin) / height)
	s = math.max(s, 0.3)
	local w, h = width * s, height * s
	return screen.X / 2 - w / 2, screen.Y * 0.02, w, h
end

local function overlaps(
	ax: number,
	ay: number,
	aw: number,
	ah: number,
	bx: number,
	by: number,
	bw: number,
	bh: number
): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- Screen sizes in UI units: phones upright and sideways, tablets, PC.
local SCREENS: { any } = {
	Vector2.new(360, 640),
	Vector2.new(320, 480),
	Vector2.new(568, 320),
	Vector2.new(640, 360),
	Vector2.new(667, 339),
	Vector2.new(740, 300),
	Vector2.new(844, 390),
	Vector2.new(1024, 710),
	Vector2.new(1366, 700),
	Vector2.new(1422, 760),
}

describe("Config.Menu", function()
	it("has a complete line for every tile", function()
		local seen = {}
		for _, tile in Config.Menu.Tiles do
			expect(tile.Id).toBeA("string")
			if seen[tile.Id] then
				error(tile.Id .. " is listed twice")
			end
			seen[tile.Id] = true
			expect(tile.Text).toBeA("string")
			expect(tile.Text).never.toBe("")
			expect(tile.Icon).toBeA("string")
			if tile.Color ~= nil then
				expect(typeof(tile.Color)).toBe("Color3")
			end
			if tile.Feature ~= nil then
				expect(Config.Features[tile.Feature]).toBeA("boolean")
			end
		end
		for _, id in
			{
				"Skins",
				"Shop",
				"Crates",
				"Vote",
				"Spectate",
				"Invite",
				"Codes",
				"Settings",
				"Vip",
				"Parkour",
				"EasterEggs",
			}
		do
			if not seen[id] then
				error(id .. " is not in Config.Menu.Tiles")
			end
		end
	end)

	it("has sensible settings", function()
		local p = Config.Menu.Panel
		expect(p.TileMinWidth).toBeLessThanOrEqual(p.TileMaxWidth)
		expect(p.MaxColumns).toBeGreaterThanOrEqual(1)
		expect(p.TileTextSize).toBeGreaterThanOrEqual(Config.UI.MinTextSize) -- readable
		expect(Config.Menu.Button.TextSize).toBeGreaterThanOrEqual(Config.UI.MinTextSize)
		expect(Config.Menu.Button.IconWidth).toBeLessThanOrEqual(Config.Menu.Button.Width)
		expect(typeof(Config.Menu.Key)).toBe("EnumItem")
		for _, key in { "KeyHint", "NoVote", "NoVoteNoPad", "RoundRunning" } do
			expect(Config.Menu.Text[key]).toBeA("string")
		end
		expect(Config.Menu.Text.KeyHint:format("M", "B")).toBeA("string") -- two key names
		-- The Spectate tile shows in the same round state lobby spectating works in.
		expect(Config.Menu.SpectateStates).toContain("Playing")
	end)
end)

describe("MenuLogic", function()
	it("turns side buttons into their listed tiles", function()
		expect(MenuLogic.TileId("Shop (B)")).toBe("Shop")
		expect(MenuLogic.TileId("Shop")).toBe("Shop")
		expect(MenuLogic.TileId("  Settings")).toBe("Settings")
		-- Every Layout.SideButton("...") in the client code matches a Config.Menu.Tiles line,
		-- so it gets its words, icon and place from there.
		local ids = {}
		for _, tile in Config.Menu.Tiles do
			ids[tile.Id] = true
		end
		local found = 0
		for _, file in { "ShopUI", "SettingsUI", "RewardsUI" } do
			local source = client:source(folder:FindFirstChild(file))
			for call in source:gmatch("Layout%.SideButton(%b())") do
				for text in call:gmatch('"([^"]+)"') do
					found += 1
					if not ids[MenuLogic.TileId(text)] then
						error(('"%s" (%s) has no Config.Menu.Tiles line'):format(text, file))
					end
				end
			end
		end
		expect(found).toBeGreaterThanOrEqual(4) -- the Shop, Settings, Codes and Invite buttons
	end)

	it("takes a tile's words and place from Config.Menu.Tiles", function()
		local listed = MenuLogic.Resolve("Settings", "Something else", 1)
		local index = 0
		for i, tile in Config.Menu.Tiles do
			if tile.Id == "Settings" then
				index = i
			end
		end
		expect(listed.Order).toBe(index)
		expect(listed.Label).toBe(Config.Menu.Tiles[index].Text)
		expect(listed.Hidden).toBe(false)
		local other = MenuLogic.Resolve("CandyRushTest", "Candy Rush", 3, "🍬")
		expect(other.Label).toBe("Candy Rush")
		expect(other.Icon).toBe("🍬")
		expect(other.Order).toBeGreaterThan(#Config.Menu.Tiles) -- unlisted tiles go last
		local crates = MenuLogic.Resolve("Crates", "Crates", 3)
		expect(crates.Feature).toBe("Crates") -- the Crates tile follows its feature switch
	end)

	it("fits the tile grid on every screen", function()
		local p = Config.Menu.Panel
		for _, screen in SCREENS do
			for _, count in { 1, 6, 11, 20 } do
				local grid = MenuLogic.Grid(screen, count)
				local where = ("%dx%d, %d tiles"):format(screen.X, screen.Y, count)
				local function check(ok: boolean, what: string)
					if not ok then
						error(what .. " at " .. where)
					end
				end
				check(grid.Width <= screen.X - 2 * margin, "too wide")
				check(grid.Height <= screen.Y - 2 * margin, "too tall")
				check(grid.Height <= p.MaxHeight, "taller than MaxHeight")
				check(
					grid.Columns >= 1
						and grid.Columns <= math.max(p.MaxColumns, p.ShortScreenMaxColumns),
					"bad column count"
				)
				check(grid.Cell <= p.TileMaxWidth, "tiles too wide")
				check(
					grid.TileHeight >= p.TileMinHeight and grid.TileHeight <= p.TileHeight,
					"bad tile height"
				)
				if grid.Columns > 1 then
					check(grid.Cell >= p.TileMinWidth, "tiles too narrow")
				end
			end
		end
		-- An upright 360-wide phone still gets 3 tiles per row.
		expect(MenuLogic.Grid(Vector2.new(360, 640), 11).Columns).toBeGreaterThanOrEqual(3)
		-- Phones on their side (iPhone 14 in Studio: 749x309 below the top bar): all 11 tiles
		-- show without scrolling.
		for _, phone in { Vector2.new(749, 309), Vector2.new(667, 317) } do
			local grid = MenuLogic.Grid(phone, 11)
			local rows = math.ceil(11 / grid.Columns)
			local tiles = rows * grid.TileHeight + (rows - 1) * p.TileGap + 2 * MenuLogic.TileInset
			expect(p.HeaderHeight + tiles + p.FooterHeight <= grid.Height).toBe(true)
		end
		-- A big screen keeps the normal tiles.
		expect(MenuLogic.Grid(Vector2.new(1920, 1017), 11).TileHeight).toBe(p.TileHeight)
	end)

	it("never puts the Menu button over the Hud", function()
		local b = Config.Menu.Button
		local alone = MenuLogic.ButtonPlace(nil, nil)
		expect(alone.Mode).toBe("Full") -- no Hud yet: the whole button
		expect(alone.Y).toBe(b.Top)
		for _, screen in SCREENS do
			local hx, hy, hw, hh = hudRect(screen, margin)
			local spot = MenuLogic.ButtonPlace(hx, hy + hh)
			local where = ("%dx%d (%s)"):format(screen.X, screen.Y, spot.Mode)
			if overlaps(spot.X, spot.Y, spot.Width, spot.Height, hx, hy, hw, hh) then
				error("the button covers the Hud at " .. where)
			end
			if not (spot.X + spot.Width <= screen.X and spot.Y + spot.Height <= screen.Y) then
				error("the button is off screen at " .. where)
			end
		end
		-- PC: the whole button at the top.
		local hx, hy, _, hh = hudRect(Vector2.new(1366, 700), margin)
		local pc = MenuLogic.ButtonPlace(hx, hy + hh)
		expect(pc.Mode).toBe("Full")
		expect(pc.Y).toBe(b.Top)
		-- A sideways phone: just the icon, still at the top.
		hx, hy, _, hh = hudRect(Vector2.new(667, 339), margin)
		local phone = MenuLogic.ButtonPlace(hx, hy + hh)
		expect(phone.Mode).toBe("Icon")
		expect(phone.Y).toBe(b.Top)
		-- An upright 360-wide phone: the Hud fills the top, so the button goes below it.
		hx, hy, _, hh = hudRect(Vector2.new(360, 640), margin)
		local upright = MenuLogic.ButtonPlace(hx, hy + hh)
		expect(upright.Y).toBeGreaterThanOrEqual(hy + hh)
	end)
end)

describe("MenuUI (mounted)", function()
	local rt = Runtime.new({ client = true })
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	local MenuUI = rt:require(Client.MenuUI)
	local clicks = 0
	-- A tile added before Mount waits and appears once the Menu exists.
	MenuUI.AddTile({
		Id = "TestTile",
		Label = "First",
		Order = 50,
		OnClick = function()
			clicks += 1
		end,
	})
	local gui = rt:create("ScreenGui", { Name = "GameUI" })
	rt:require(Client.Layout).Mount(gui)
	rt:require(Client.PanelManager).Mount(gui)
	MenuUI.Mount(gui)

	local function tilesWith(id: string): { any }
		local list = {}
		for _, child in gui.Menu.Tiles:GetChildren() do
			if child:GetAttribute("MenuTile") == id then
				table.insert(list, child)
			end
		end
		return list
	end

	it("builds the button and the closed panel", function()
		expect(gui:FindFirstChild("MenuButton")).toBeInstanceOf("TextButton")
		expect(gui.Menu.Visible).toBe(false)
		expect(MenuUI.IsOpen()).toBe(false)
		expect(#tilesWith("TestTile")).toBe(1)
	end)

	it("opens, toggles and closes", function()
		MenuUI.Open()
		expect(MenuUI.IsOpen()).toBe(true)
		MenuUI.Toggle()
		expect(MenuUI.IsOpen()).toBe(false)
		rt:triggerAction("ToggleMenu") -- the M key
		expect(MenuUI.IsOpen()).toBe(true)
		MenuUI.Close()
		expect(MenuUI.IsOpen()).toBe(false)
	end)

	it("frees the mouse (a Modal button) only while a panel is open", function()
		local cursor = gui:FindFirstChild("PanelCursor")
		expect(cursor).toBeInstanceOf("TextButton")
		expect(cursor.Modal).toBe(true)
		expect(cursor.Visible).toBe(false)
		MenuUI.Open()
		expect(cursor.Visible).toBe(true)
		MenuUI.Close()
		expect(cursor.Visible).toBe(false)
	end)

	it("hides Roblox's touch action buttons (Run, HEY!) while a panel is open", function()
		local playerGui = rt.game:GetService("Players").LocalPlayer.PlayerGui
		local actions = rt:create("ScreenGui", { Name = "ContextActionGui" }, playerGui)
		MenuUI.Open()
		expect(actions.Enabled).toBe(false)
		MenuUI.Close()
		expect(actions.Enabled).toBe(true)
		actions:Destroy()
	end)

	it("closes when a tile is clicked, and replaces a tile with the same Id", function()
		MenuUI.Open()
		rt:fire(tilesWith("TestTile")[1], "Activated")
		expect(clicks).toBe(1)
		expect(MenuUI.IsOpen()).toBe(false)
		MenuUI.AddTile({
			Id = "TestTile",
			Label = "Second",
			KeepOpen = true,
			OnClick = function()
				clicks += 10
				MenuUI.ShowMessage("kept open")
			end,
		})
		local list = tilesWith("TestTile")
		expect(#list).toBe(1)
		MenuUI.Open()
		rt:fire(list[1], "Activated")
		expect(clicks).toBe(11)
		expect(MenuUI.IsOpen()).toBe(true) -- KeepOpen
		expect(gui.Menu.Message.Text).toBe("kept open")
		MenuUI.Close()
	end)

	it("turns a Layout.SideButton into a tile", function()
		local Layout = rt:require(Client.Layout)
		local button = Layout.SideButton("Settings", 1)
		expect(button:GetAttribute("MenuTile")).toBe("Settings")
		expect(button:IsDescendantOf(gui.Menu)).toBe(true)
	end)
end)
