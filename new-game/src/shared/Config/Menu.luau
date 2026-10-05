--!strict
--[[
	TOP-LEFT MENU (Config.Menu)

	One "Menu" button at the top left (on/off: Config.Features.Menu) opens a grid of tiles.
	Tiles are shown in the order below; Text is what each tile says. A tile whose feature
	is switched off in Config.Features is hidden. Reorder or rename tiles here.
]]

return {
	ButtonText = "Menu",
	Key = Enum.KeyCode.M, -- opens and closes the menu on a keyboard
	-- TODO(menu agent): tile settings go here.
	Tiles = {
		{ Id = "Skins", Text = "Skins" },
		{ Id = "Shop", Text = "Shop" },
		{ Id = "Crates", Text = "Crates" },
		{ Id = "Vote", Text = "Vote" },
		{ Id = "Spectate", Text = "Spectate" },
		{ Id = "Invite", Text = "Invite" },
		{ Id = "Codes", Text = "Codes" },
		{ Id = "Settings", Text = "Settings" },
		{ Id = "Vip", Text = "VIP" },
		{ Id = "Progress", Text = "Parkour & Eggs" },
	},
}
