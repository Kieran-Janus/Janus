--!strict
--[[
	CRATE SKINS (added to Config.Shop.Items)

	One file per theme in this folder (Pumpkin.luau, Candy.luau, ...), each a list of 20
	skins: 12 Common, 5 Uncommon, 2 Rare and 1 CRAZY. Config (init.luau) adds them all to
	Config.Shop.Items, so the shop, crates, codes and saves find them like any other item.

	Each skin needs:
	  Id       unique, starts with the theme ("Pumpkin_CandleKid"). It is saved in players'
	           data: NEVER rename it once the game is live (change Name instead).
	  Name     what players see
	  Rarity   "Common", "Uncommon", "Rare" or "Crazy": sets its shop price (Config/Rarity.luau)
	  Style    how it looks (every option is listed at the top of Pumpkin.luau)
	Filled in for you here, so the theme files stay short:
	  Slot = "Skin", Crate = the theme's crate (Settings.luau, Themes), Theme = the theme's Id,
	  Style.Kind = "Skin", Style.HideClothes = true (a costume covers your shirt and pants).
	  Give a skin its own Crate to put it in a different crate.
	Optional: Price = 300 (its own price), CrateOnly = true (only from crates, not sold in
	the shop).

	New theme: copy a theme file, rename it and every Id in it, then add a line to Themes in
	Settings.luau (the Id there is the file name).
]]

local Settings = require(script.Settings)

local all: { any } = {}
for _, theme in Settings.Themes do
	local file = script:FindFirstChild(theme.Id)
	if not (file and file:IsA("ModuleScript")) then
		warn(("[Config.Skins] theme %s has no file Skins/%s.luau"):format(theme.Id, theme.Id))
		continue
	end
	local list = (require :: any)(file) :: { any }
	for _, item in list do
		item.Slot = item.Slot or "Skin"
		item.Crate = item.Crate or theme.Crate
		item.Theme = item.Theme or theme.Id
		item.Style = item.Style or {}
		item.Style.Kind = item.Style.Kind or "Skin"
		if item.Style.HideClothes == nil then
			item.Style.HideClothes = true
		end
		table.insert(all, item)
	end
end
return all
