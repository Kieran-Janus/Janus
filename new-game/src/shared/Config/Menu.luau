--!strict
--[[
	TOP-LEFT MENU (Config.Menu)

	One big "Menu" button at the top left (on/off: Config.Features.Menu) opens a grid of
	tiles. On a keyboard, Key (M) opens and closes it too. When the screen is too narrow
	for the whole button next to the bar at the top middle, it shows only its icon, or moves
	just below that bar.

	Tiles: shown in the order listed below. Each line is one tile:
	  Id       which tile it is (don't change it: the code finds tiles by Id)
	  Text     the words on the tile (change freely)
	  Icon     the picture on the tile: any emoji ("" = no picture)
	  Color    the tile's colour (optional, leave it out for the normal dark tile)
	  Feature  (optional) the tile only shows while Config.Features[Feature] is on
	  Hidden   (optional) true = never show this tile
	Move a line up or down to move its tile. A tile some other feature adds that isn't
	listed here goes after these.
	Switching the Menu off (Config.Features.Menu = false) brings back the old column of
	Shop / Codes / Invite / Settings buttons.
]]

export type TileEntry = {
	Id: string,
	Text: string,
	Icon: string,
	Color: Color3?,
	Feature: string?,
	Hidden: boolean?,
}

return {
	ButtonText = "Menu", -- the word on the Menu button
	Key = Enum.KeyCode.M, -- opens and closes the menu on a keyboard

	-- The Menu button (sizes in UI units: on big screens everything scales up a little).
	Button = {
		Left = 12, -- gap from the left edge of the screen
		Top = 8, -- gap below Roblox's top bar
		Width = 120, -- the whole button: icon + word...
		Height = 48,
		IconWidth = 52, -- ...or just the icon, on screens too narrow for the word
		TextSize = 22,
		Color = Color3.fromRGB(255, 130, 20), -- pumpkin orange, easy to spot
		Gap = 8, -- space kept between the button and the bar at the top middle
	},

	-- The tile grid the button opens.
	Panel = {
		Title = "Menu",
		MaxWidth = 600, -- biggest the panel gets on large screens
		MaxHeight = 480,
		Padding = 12, -- space inside the panel's edges
		HeaderHeight = 52, -- the title row
		FooterHeight = 44, -- the message line at the bottom
		ScrollBar = 6, -- room for the scroll bar when there are more tiles than fit
		TileHeight = 96,
		TileMinWidth = 92, -- tiles are at least this wide (fewer per row on narrow screens)...
		TileMaxWidth = 130, -- ...and at most this wide
		TileGap = 10,
		MaxColumns = 4, -- most tiles in one row
		TileTextSize = 15,
		IconSize = 32,
	},

	-- Round states (the word at the top of the screen) the menu cares about.
	RoundStates = { "Intermission", "Playing", "Results" }, -- "a round is on" (see Text.RoundRunning)
	SpectateStates = { "Playing" }, -- the Spectate tile shows in these, for players not in the round

	-- Messages shown at the bottom of the menu.
	Text = {
		KeyHint = "Keys: %s opens this menu, %s opens the shop.", -- the two key names
		NoVote = "Voting starts when enough players stand on the Ready pad.",
		NoVoteNoPad = "Voting starts when enough players have joined.", -- when the Ready pad is off
		RoundRunning = "A round is on right now. Voting starts after it ends.",
		Parkour = "Find the parkour course in the lobby and reach the finish for %d %s!",
		EasterEggs = "Secret pumpkins found: %d of %d. Keep exploring the lobby!",
	},

	Tiles = {
		{ Id = "Skins", Text = "Skins", Icon = "🧟", Color = Color3.fromRGB(110, 70, 160) },
		{ Id = "Shop", Text = "Shop", Icon = "🛒", Color = Color3.fromRGB(255, 130, 20) },
		{
			Id = "Crates",
			Text = "Crates",
			Icon = "🎁",
			Color = Color3.fromRGB(170, 60, 120),
			Feature = "Crates",
		},
		{ Id = "Vote", Text = "Vote", Icon = "🗳️", Color = Color3.fromRGB(50, 110, 160) },
		{ Id = "Spectate", Text = "Spectate", Icon = "👀", Feature = "LobbySpectate" },
		{ Id = "Invite", Text = "Invite", Icon = "💌", Color = Color3.fromRGB(60, 130, 80) },
		{ Id = "Codes", Text = "Codes", Icon = "🔑" },
		{ Id = "Settings", Text = "Settings", Icon = "⚙️" },
		{ Id = "Vip", Text = "VIP & Packs", Icon = "⭐", Color = Color3.fromRGB(150, 115, 30) },
		{ Id = "Parkour", Text = "Parkour", Icon = "🏃", Feature = "Parkour" },
		{ Id = "EasterEggs", Text = "Secret Pumpkins", Icon = "🎃", Feature = "EasterEggs" },
	} :: { TileEntry },
}
