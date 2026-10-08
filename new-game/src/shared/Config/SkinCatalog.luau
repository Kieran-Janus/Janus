--!strict
--[[
	CATALOG ITEMS IN SKINS (Config.SkinCatalog)

	A skin can also put real Roblox catalog items on you: hats, hair, glasses, back items and
	classic shirts, pants and T-shirts. In the skin's Style:
	    Catalog = {
	        Accessories = { { Id = 1234567890, Type = "Hat" }, { Id = 2345678901, Type = "Back" } },
	        Shirt = 3456789012, Pants = 4567890123,   -- (the skin needs HideClothes = false)
	        ClassicFace = 6789012345,                 -- a flat face (only on a skin with no Head)
	    },
	(the numbers above are made up: use real catalog ids).
	The server adds them to your own avatar (src/server/Services/SkinCatalogService.luau) and
	takes them off again with the skin. If Roblox can't load them, you simply see the skin
	without them. Shop and crate cards show them as small pictures (src/client/CatalogBadge.luau).

	SAFETY RULES (crates are sold for Robux, and this is a kids' game):
	  - Only items made by Roblox, by you or by your group (AllowedCreators). Skin Studio's
	    "Look up" refuses anyone else's items.
	  - Every id a skin in the game files uses must be listed in ApprovedIds, after you have
	    checked the item yourself. The tests fail for any id that isn't. Claude Code only adds
	    an id when you say yes AND it was made by Roblox, you or your group.
	  - It stays switched off (Config.Features.SkinCatalog = false) until you have tried it in
	    Studio. ShowBuyButtons stays false (no "Buy" buttons on cards).
	Only rigid accessories, classic clothes and a classic face are allowed: bundles, body parts,
	body scales, layered (3D) clothing and animation packs would break the skins' welded parts
	(docs/CUSTOMIZE.md, "Catalog items in skins", says why).
]]

return {
	MaxAccessories = 4, -- catalog accessories in one skin
	-- The kinds of accessory a skin may add (FaceAccessory = glasses or a mask; a flat face is
	-- ClassicFace instead).
	Types = { "Hat", "Hair", "FaceAccessory", "Neck", "Shoulder", "Front", "Back", "Waist" },
	-- Who may make the items. Crates are sold for Robux, so only Roblox, you and your group.
	AllowedCreators = {
		Roblox = true,
		UserIds = {} :: { number }, -- your Roblox UserId, e.g. { 123456789 }
		GroupIds = {} :: { number }, -- the game's group, if it has one
	},
	-- Every catalog id a skin in the game files uses must be listed here, after you have
	-- checked it:  [id] = "item name, creator, checked on <date>",
	-- for example (a made-up id):  [1234567890] = "Pumpkin Cap, Roblox, checked on 9 Oct 2026",
	ApprovedIds = {} :: { [number]: string },
	SecondsBetweenApplies = 2, -- per player; the newest skin always wins
	AppearanceWaitSeconds = 10, -- wait this long for the avatar to load before the first apply
	ShowThumbnails = true, -- small pictures of the items on shop and crate cards
	ShowBuyButtons = false, -- true = a small "Buy" button under each picture (Roblox's own buy window)
	ThumbnailSize = 150, -- pixels Roblox draws each picture at (150 or 420)
	MaxThumbnails = 4, -- pictures on one card
	BadgeSize = 26, -- how big each picture is on a card (pixels; 4 fit on a shop card)
	PhoneBadgeSize = 22,
	Text = {
		Hover = "Roblox catalog item", -- shown when the mouse is over a picture
		Buy = "Buy",
	},
}
