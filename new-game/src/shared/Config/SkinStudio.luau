--!strict
--[[
	SKIN STUDIO (Config.SkinStudio)

	Skin Studio is an editor for you (the owner) in a Studio playtest: Menu > Skin Studio, or
	F8 > Skin Studio. Pick any skin or make a new one, change it with colour pickers, sliders
	and dropdowns, and see it on your own character straight away. Press Save, then type
	/save-skins in Claude Code BEFORE you press Stop: Claude Code writes your skins into the
	theme files. "Copy code" always works as a backup. (docs/CUSTOMIZE.md > Skin Studio.)

	On/off: Config.Features.SkinStudio. It only ever shows for admins (Config.Admin) and,
	unless AllowInLiveServers is true, only in Studio. Players never see it.
	Code: src/shared/SkinSchema.luau (what a skin may contain), src/server/Services/
	SkinStudioService.luau (drafts), src/client/SkinStudioUI.luau (the panel).
]]

return {
	AllowInLiveServers = false, -- true = admins can use it in live games too (Config.Admin decides who)
	-- false = drafts are kept only during the playtest: run /save-skins before Stop (the safe default).
	-- true needs "Enable Studio Access to API Services", which ALSO makes Studio use your real
	-- player save and the public leaderboard. Read docs/CUSTOMIZE.md > Skin Studio first.
	UseDataStore = false,
	DraftStore = "SkinStudioDrafts_v1", -- a store of its own: it never touches player saves
	DraftKey = "Drafts",
	FlushSeconds = 7, -- DataStore writes at most this often (Roblox allows about 1 per 6 s per key)
	TombstoneDays = 30, -- deleted drafts are remembered this long so a merge can't bring them back
	MaxStoreChars = 3900000, -- under the DataStore's 4 MB per key
	MaxDrafts = 200, -- saved drafts at once
	MaxDraftBytes = 10000, -- the biggest one skin may be, as text
	MaxPatterns = 6, -- accent patterns one skin may have (more = too many parts on phones)
	LoadTries = 3, -- the DataStore load tries this many times...
	LoadRetrySeconds = 1, -- ...this far apart
	ExportPageChars = 20000, -- SkinExport page size (MCP output is cut off past roughly this)
	PrintOnStop = true, -- in Studio, print this session's drafts to Output when the playtest stops
	KeepWearingDefault = true, -- keep wearing the draft after closing the panel
	WearOnMeDefault = true, -- "Wear on me" starts ticked
	WearDelay = 0.35, -- seconds after your last change before your character wears it
	PreviewDelay = 0.15, -- seconds after your last change before the small preview updates
	-- Per admin, on the server: the shortest time between two of these.
	WearCooldown = 0.25,
	SaveCooldown = 1,
	LookupCooldown = 1,
	PrintCooldown = 5,
	OtherCooldown = 0.1, -- Hello, Get, Delete, StopWearing
	UndoSteps = 50, -- how many changes Undo remembers
	ListPageSize = 30, -- skins per page in the Skins tab
	PhoneListPageSize = 15,
	Panel = {
		Width = 440, -- on a PC the panel sits on the right, this wide
		Margin = 8, -- gap from the screen edges
		PhoneHeightScale = 0.55, -- on phones it is a sheet along the bottom, this much of the screen
		HeaderHeight = 132,
		PhoneHeaderHeight = 60,
		TabHeight = 36,
		FooterHeight = 92,
		PhoneFooterHeight = 104,
		RowHeight = 34, -- one control (PC)
		PhoneRowHeight = 44, -- one control on phones (44 = big enough for a finger)
		PreviewSize = 112, -- the small turning preview in the header (PC only)
	},
	PreviewSpinSeconds = 6, -- one turn of the header preview
	Turntable = { Seconds = 8, Distance = 9, Height = 2 }, -- the camera circling you
	-- The colour picker's swatches (24).
	Palette = {
		Color3.fromRGB(255, 130, 20), -- pumpkin orange
		Color3.fromRGB(230, 100, 10), -- deep pumpkin
		Color3.fromRGB(255, 180, 60), -- candle glow
		Color3.fromRGB(255, 220, 90), -- candy-corn yellow
		Color3.fromRGB(255, 110, 190), -- bubblegum pink
		Color3.fromRGB(255, 160, 210), -- cotton candy
		Color3.fromRGB(220, 40, 60), -- candy-apple red
		Color3.fromRGB(150, 20, 40), -- vampire red
		Color3.fromRGB(245, 245, 255), -- ghost white
		Color3.fromRGB(200, 215, 255), -- moonlight blue
		Color3.fromRGB(110, 150, 255), -- night sky
		Color3.fromRGB(70, 225, 200), -- spooky teal
		Color3.fromRGB(150, 95, 230), -- witch purple
		Color3.fromRGB(110, 60, 160), -- night purple
		Color3.fromRGB(70, 40, 100), -- deep violet
		Color3.fromRGB(35, 28, 45), -- midnight
		Color3.fromRGB(120, 255, 80), -- slime green
		Color3.fromRGB(110, 170, 70), -- zombie green
		Color3.fromRGB(60, 110, 60), -- swamp green
		Color3.fromRGB(235, 228, 210), -- bone
		Color3.fromRGB(205, 175, 120), -- straw
		Color3.fromRGB(130, 85, 50), -- old wood
		Color3.fromRGB(128, 120, 138), -- tombstone grey
		Color3.fromRGB(20, 18, 24), -- black cat
	},
	-- Materials in the material dropdowns (a skin may use any Roblox material; these are the
	-- friendly ones).
	Materials = {
		"SmoothPlastic",
		"Plastic",
		"Neon",
		"Foil",
		"Glass",
		"ForceField",
		"Metal",
		"DiamondPlate",
		"Fabric",
		"Wood",
		"WoodPlanks",
		"Marble",
		"Granite",
		"Slate",
		"Cobblestone",
		"Brick",
		"Concrete",
		"Ice",
		"Snow",
		"Sand",
		"Grass",
		"CrackedLava",
		"Pebble",
		"CorrodedMetal",
	},
	-- Lines around each printed page in Output (Print for Claude): /save-skins looks for them.
	ExportMarkers = { Begin = "--[[ SKIN STUDIO BEGIN ]]", End = "--[[ SKIN STUDIO END ]]" },
	-- Every message the panel shows.
	Text = {
		Title = "Skin Studio",
		NotAllowed = "Not allowed: Skin Studio is for admins in Studio.",
		SlowDown = "Slow down!",
		Broken = "That went wrong: %s",
		Opened = "Skin Studio opened.",
		NoRemote = "Skin Studio's server part isn't running.",
		Loading = "Loading...",
		Wearing = "Wearing: %s",
		WearingDraft = "Wearing: %s (draft)",
		WearingNothing = "Wearing: your own skin",
		WearOnMe = "Wear on me",
		KeepWearing = "Keep wearing after closing",
		Saved = "Saved for this playtest. Run /save-skins in Claude Code before you press Stop.",
		SavedDataStore = "Saved. Also kept after Stop (DataStore on).",
		Deleted = "Draft deleted.",
		NotInFiles = "%d drafts are not in the game files yet: run /save-skins in Claude Code before you press Stop",
		OneNotInFiles = "1 draft is not in the game files yet: run /save-skins in Claude Code before you press Stop",
		Unsaved = "You have unsaved changes",
		TooManyDrafts = "Too many drafts to keep after Stop: delete some",
		DataStoreLoading = "Loading saved drafts...",
		DataStoreOff = "Drafts are kept for this playtest only (run /save-skins before Stop).",
		DataStoreFailed = "Couldn't read drafts kept after Stop (is Studio API access on?). Saving still works for this playtest.",
		EconomyLocked = "This skin's rarity is locked: players already own it.",
		UnlockQuestion = "Players already own this skin. Changing its rarity or crate changes what they own and the Robux crate odds. Unlock?",
		Unlocked = "Rarity, crate and price unlocked for this skin.",
		NotAllowedCreator = "Not an allowed creator: only items made by Roblox, you or your group (Config.SkinCatalog.AllowedCreators).",
		CatalogOff = "Catalog items are switched off (Config.Features.SkinCatalog). You can still add them; they show once it's on.",
		CopyHint = "Ctrl+A, Ctrl+C, then paste it into Claude Code and say which theme file",
		Printed = "Printed %d page(s) to Output for Claude Code.",
		AnimationNote = "Your own animations must be owned by you (or your group, if the game is a group game), or made by Roblox. Others don't play.",
		SaveSteps = "1. Press Save on each skin you like.\n2. In Claude Code type /save-skins BEFORE you press Stop.\n3. Claude Code writes them into the theme files and runs the tests.\nBackup: Copy code, or Print for Claude.",
		InGameFiles = "In the game files",
		ClassicNoSave = "Classic and Tower skins can be tried here, but /save-skins won't write them: use Copy code.",
		NewName = "New Skin",
	},
}
