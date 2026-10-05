--!strict
-- The top-left Menu: Config.Menu is complete, side buttons become the right tiles, the tile
-- grid fits every screen, and the Menu button never covers the Hud (src/client/MenuLogic.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The Hud as src/client/Hud.luau draws it: 520 x 64 at the top middle (Position 0.5, 0.02),
-- shrunk by Layout.Fit when it doesn't fit. Returns left, top, width, height in UI units.
local function hudRect(screen: Vector2, margin: number): (number, number, number, number)
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
local SCREENS = {
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

return function(t: any)
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local MenuLogic = require(t.Client.MenuLogic) :: any
	local margin = Config.UI.EdgeMargin

	t.test("every Menu tile line is complete", function()
		local seen = {}
		for _, tile in Config.Menu.Tiles do
			t.eq(type(tile.Id), "string", "tile Id")
			t.ok(not seen[tile.Id], tile.Id .. " is listed twice")
			seen[tile.Id] = true
			t.ok(type(tile.Text) == "string" and tile.Text ~= "", tile.Id .. " has Text")
			t.eq(type(tile.Icon), "string", tile.Id .. " Icon")
			t.ok(tile.Color == nil or typeof(tile.Color) == "Color3", tile.Id .. " Color")
			if tile.Feature ~= nil then
				t.eq(type(Config.Features[tile.Feature]), "boolean", tile.Id .. " Feature")
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
			t.ok(seen[id], id .. " is in Config.Menu.Tiles")
		end
	end)

	t.test("Menu settings are sensible", function()
		local p = Config.Menu.Panel
		t.ok(p.TileMinWidth <= p.TileMaxWidth, "TileMinWidth <= TileMaxWidth")
		t.ok(p.MaxColumns >= 1, "MaxColumns")
		t.ok(p.TileTextSize >= Config.UI.MinTextSize, "tile text is readable")
		t.ok(Config.Menu.Button.TextSize >= Config.UI.MinTextSize, "button text is readable")
		t.ok(Config.Menu.Button.IconWidth <= Config.Menu.Button.Width, "the icon is smaller")
		t.eq(typeof(Config.Menu.Key), "EnumItem", "Key")
		for _, key in { "KeyHint", "NoVote", "NoVoteNoPad", "RoundRunning", "Parkour", "EasterEggs" } do
			t.eq(type(Config.Menu.Text[key]), "string", "Text." .. key)
		end
		t.ok(Config.Menu.Text.KeyHint:format("M", "B"), "KeyHint takes two key names")
		t.ok(Config.Menu.Text.Parkour:format(100, "Coins"), "Parkour takes coins and a name")
		t.ok(Config.Menu.Text.EasterEggs:format(1, 5), "EasterEggs takes two numbers")
	end)

	t.test("side buttons become their listed tiles", function()
		t.eq(MenuLogic.TileId("Shop (B)"), "Shop")
		t.eq(MenuLogic.TileId("Shop"), "Shop")
		t.eq(MenuLogic.TileId("  Settings"), "Settings")
		-- Every Layout.SideButton("...") in the client code matches a Config.Menu.Tiles line,
		-- so it gets its words, icon and place from there.
		local ids = {}
		for _, tile in Config.Menu.Tiles do
			ids[tile.Id] = true
		end
		local found = 0
		for _, file in { "ShopUI", "SettingsUI", "RewardsUI" } do
			local source = t.readFile("src/client/" .. file .. ".luau")
			t.ok(source, file)
			for call in (source :: string):gmatch("Layout%.SideButton(%b())") do
				for text in call:gmatch('"([^"]+)"') do
					found += 1
					t.ok(ids[MenuLogic.TileId(text)], ('"%s" (%s) has a tile line'):format(text, file))
				end
			end
		end
		t.ok(found >= 4, "found the Shop, Settings, Codes and Invite buttons")
	end)

	t.test("Config.Menu.Tiles sets a tile's words and place", function()
		local listed = MenuLogic.Resolve("Settings", "Something else", 1)
		local index = 0
		for i, tile in Config.Menu.Tiles do
			if tile.Id == "Settings" then
				index = i
			end
		end
		t.eq(listed.Order, index)
		t.eq(listed.Label, Config.Menu.Tiles[index].Text)
		t.eq(listed.Hidden, false)
		local other = MenuLogic.Resolve("CandyRushTest", "Candy Rush", 3, "🍬")
		t.eq(other.Label, "Candy Rush")
		t.eq(other.Icon, "🍬")
		t.ok(other.Order > #Config.Menu.Tiles, "unlisted tiles go after the listed ones")
		local crates = MenuLogic.Resolve("Crates", "Crates", 3)
		t.eq(crates.Feature, "Crates", "the Crates tile follows its feature switch")
	end)

	t.test("the tile grid fits every screen", function()
		local p = Config.Menu.Panel
		for _, screen in SCREENS do
			for _, count in { 1, 6, 11, 20 } do
				local grid = MenuLogic.Grid(screen, count)
				local where = ("%dx%d, %d tiles"):format(screen.X, screen.Y, count)
				t.ok(grid.Width <= screen.X - 2 * margin, "width fits " .. where)
				t.ok(grid.Height <= screen.Y - 2 * margin, "height fits " .. where)
				t.ok(grid.Height <= p.MaxHeight, "height capped " .. where)
				t.ok(grid.Columns >= 1 and grid.Columns <= p.MaxColumns, "columns " .. where)
				t.ok(grid.Cell <= p.TileMaxWidth, "tile width " .. where)
				if grid.Columns > 1 then
					t.ok(grid.Cell >= p.TileMinWidth, "tiles not too narrow " .. where)
				end
			end
		end
		-- An upright 360-wide phone still gets 3 tiles per row.
		t.ok(MenuLogic.Grid(Vector2.new(360, 640), 11).Columns >= 3, "3 per row at 360 wide")
	end)

	t.test("the Menu button never covers the Hud", function()
		local b = Config.Menu.Button
		local alone = MenuLogic.ButtonPlace(nil, nil)
		t.eq(alone.Mode, "Full", "no Hud yet: the whole button")
		t.eq(alone.Y, b.Top)
		for _, screen in SCREENS do
			local hx, hy, hw, hh = hudRect(screen, margin)
			local spot = MenuLogic.ButtonPlace(hx, hy + hh)
			local where = ("%dx%d (%s)"):format(screen.X, screen.Y, spot.Mode)
			t.ok(
				not overlaps(spot.X, spot.Y, spot.Width, spot.Height, hx, hy, hw, hh),
				"button clear of the Hud at " .. where
			)
			t.ok(spot.X + spot.Width <= screen.X and spot.Y + spot.Height <= screen.Y, where)
		end
		-- PC: the whole button at the top.
		local hx, hy, hw, hh = hudRect(Vector2.new(1366, 700), margin)
		local pc = MenuLogic.ButtonPlace(hx, hy + hh)
		t.eq(pc.Mode, "Full")
		t.eq(pc.Y, b.Top)
		-- A sideways phone: just the icon, still at the top.
		hx, hy, hw, hh = hudRect(Vector2.new(667, 339), margin)
		local phone = MenuLogic.ButtonPlace(hx, hy + hh)
		t.eq(phone.Mode, "Icon")
		t.eq(phone.Y, b.Top)
		-- An upright 360-wide phone: the Hud fills the top, so the button goes below it.
		hx, hy, hw, hh = hudRect(Vector2.new(360, 640), margin)
		local upright = MenuLogic.ButtonPlace(hx, hy + hh)
		t.ok(upright.Y >= hy + hh, "below the Hud")
	end)
end
