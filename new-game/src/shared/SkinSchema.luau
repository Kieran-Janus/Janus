--!strict
--[[
	SkinSchema: what a crate skin may contain, in one place (client + server, no state).
	Skin Studio builds its controls from it, the server checks every draft with it, it turns a
	skin into JSON and back, and it writes a skin as Luau for the theme files. The catalogue
	tests (tests/specs/skins.spec.luau) use its rarity and look rules, so the editor's
	warnings and the tests can never disagree.

	SkinSchema.Fields                 every editable key (item fields + every Style key), in the
	                                  order the theme files write them (see Field below)
	SkinSchema.ItemKeys               editable item keys: Id, Name, Rarity, Crate, Price, CrateOnly, Style
	SkinSchema.ReadOnlyKeys           carried unchanged: Slot, Theme, OneInAMillion, Odds, VipOnly, Exclusive
	SkinSchema.EconomyKeys            Rarity, Crate, Price, CrateOnly (locked for skins players own)
	SkinSchema.Encode(item) -> EncodedItem       JSON-safe copy: colours "#RRGGBB", materials by name
	SkinSchema.Decode(encoded) -> (item?, errors)
	SkinSchema.Validate(item) -> (ok, errors, warnings)   errors = the server refuses it
	SkinSchema.Check(item, catalogue) -> warnings          allowed, but worth a look
	SkinSchema.CheckSections(item, catalogue) -> { { Section, Text } }   the same, per section
	SkinSchema.RarityProblems(item) -> { string }  the rarity look rules (+ animation limits)
	SkinSchema.CrazyHeadProblems(catalogue) -> { string }   a CRAZY head used by another skin
	SkinSchema.LookKey(style) -> string            two skins with the same key look the same
	SkinSchema.IdOk(id, theme, taken?) -> (ok, why?)
	SkinSchema.IdFromName(theme, name) -> string   "Pumpkin", "Jack's Jumper" -> "Pumpkin_JacksJumper"
	SkinSchema.NewItem(theme) -> item              a blank Common skin in that theme
	SkinSchema.Duplicate(item) -> item             a copy with Id "<Id>Copy", Name "<Name> Copy"
	SkinSchema.WearItem(record) -> item            what Skin Studio wears: Id "StudioDraft_...",
	                                               ModelId = the real Id (custom models still found)
	SkinSchema.ToLuau(item, theme?) -> string      one entry for a theme file, one tab indented
	SkinSchema.Copy(item) -> item                  a deep copy
	SkinSchema.Same(a, b) -> boolean               the two skins are exactly alike
	SkinSchema.Get(item, path) / SkinSchema.Set(item, path, value)   read / change one key
	                                               (Set makes Accent/Glow/Aura... with sensible
	                                               defaults; clearing the last key removes them)
	SkinSchema.ThemeCrate(theme) -> string?        the crate a theme's skins drop from
	SkinSchema.IsCrateTheme(theme) -> boolean

	The animation, walk-style and catalog parts of a Style (Animate, Motion, Catalog) are checked
	by their own modules (SkinAnimate, SkinMotion, SkinCatalog: Normalize), so the editor, the
	server and the tests all use the same rules.
]]

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Cosmetics)
local HeadPieces = require(script.Parent.HeadPieces)
local SkinAnimate = require(script.Parent.SkinAnimate)
local SkinCatalog = require(script.Parent.SkinCatalog)
local SkinMotion = require(script.Parent.SkinMotion)

local SkinSchema = {}

export type Field = {
	Key: string,
	Path: { string },
	Label: string,
	Help: string,
	Section: string,
	Control: string, -- "Color" | "Material" | "Choice" | "Patterns" | "Toggle" | "Number" | "Text" | "Effects" | "Motion" | "Catalog"
	Choices: (() -> { string })?,
	Min: number?,
	Max: number?,
	Step: number?,
	Optional: boolean,
	From: string?, -- the lowest rarity it suits
	Economy: boolean?, -- locked for skins players already own
	Hidden: boolean?, -- not shown in the editor (Style.Kind)
}

export type SectionProblem = { Section: string, Text: string }

local MAX_DEPTH = 6 -- the item is level 1; Style.Animate[i].Colors is level 5
local MAX_STRING = 60
local MAX_NAME = 40
local MAX_PRICE = 10000000
local DRAFT_PREFIX = "StudioDraft_"
local WHITE = Color3.new(1, 1, 1)

local function studio(): any
	return Config.SkinStudio
end

-- What each key holds. A table = a group of keys (Accent, Glow, ...).
local ITEM_SHAPE: { [string]: any } = {
	Id = "string",
	Name = "string",
	Rarity = "string",
	OneInAMillion = "boolean",
	Odds = "number",
	Slot = "string",
	Theme = "string",
	Crate = "string",
	Price = "number",
	CrateOnly = "boolean",
	VipOnly = "boolean",
	Exclusive = "string",
	Style = "Style",
}

local STYLE_SHAPE: { [string]: any } = {
	Kind = "string",
	BodyColor = "Color3",
	TorsoColor = "Color3",
	ArmsColor = "Color3",
	LegsColor = "Color3",
	Material = "Material",
	TorsoMaterial = "Material",
	ArmsMaterial = "Material",
	LegsMaterial = "Material",
	HeadMaterial = "Material",
	Transparency = "number",
	HideClothes = "boolean",
	Accent = { Color = "Color3", Material = "Material", Pattern = "Pattern" },
	Head = "string",
	Face = "string",
	HeadColor = "Color3",
	HeadColor2 = "Color3",
	HeadColor3 = "Color3",
	GlowColor = "Color3",
	Glow = { Color = "Color3", Brightness = "number", Range = "number" },
	Aura = { Kind = "string", Color = "Color3", Color2 = "Color3" },
	Crazy = {
		Rainbow = "boolean",
		Pulse = "boolean",
		Orbit = "string",
		Count = "number",
		Effect = "string",
	},
	Animate = "Animate",
	Motion = "Motion",
	Catalog = "Catalog",
}

-- The order keys are written in (theme files), for tables that aren't Fields.
local ITEM_ORDER = {
	"Id",
	"Name",
	"Rarity",
	"OneInAMillion",
	"Odds",
	"Slot",
	"Theme",
	"Crate",
	"Price",
	"CrateOnly",
	"VipOnly",
	"Exclusive",
	"Style",
}
local KEY_ORDER: { [string]: { string } } = {
	Effect = {
		"Effect",
		"Target",
		"Speed",
		"Amount",
		"Delay",
		"Axis",
		"Reverse",
		"Colors",
		"Every",
		"Count",
	},
	Motion = { "Preset", "Walk", "Run", "Idle" },
	Catalog = { "Accessories", "Shirt", "Pants", "TShirt", "ClassicFace" },
	Accessory = { "Id", "Type" },
}

SkinSchema.ItemKeys = { "Id", "Name", "Rarity", "Crate", "Price", "CrateOnly", "Style" }
SkinSchema.ReadOnlyKeys = { "Slot", "Theme", "OneInAMillion", "Odds", "VipOnly", "Exclusive" }
SkinSchema.EconomyKeys = { "Rarity", "Crate", "Price", "CrateOnly" }
SkinSchema.DraftPrefix = DRAFT_PREFIX

-- Small helpers --------------------------------------------------------------------------------

local function sortedKeys(t: { [string]: any }): { string }
	local out = {}
	for key in t do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

local function themeIds(): { string }
	local out = {}
	for _, theme in Config.Skins.Themes do
		table.insert(out, theme.Id)
	end
	return out
end

local function crateIds(): { string }
	local out = {}
	for _, crate in Config.Crates.List :: { any } do
		table.insert(out, crate.Id)
	end
	return out
end

function SkinSchema.IsCrateTheme(theme: unknown): boolean
	if type(theme) ~= "string" then
		return false
	end
	for _, t in Config.Skins.Themes do
		if t.Id == theme then
			return true
		end
	end
	return false
end

function SkinSchema.ThemeCrate(theme: unknown): string?
	for _, t in Config.Skins.Themes do
		if t.Id == theme then
			return t.Crate
		end
	end
	return nil
end

local function to255(x: number): number
	return math.clamp(math.floor(x * 255 + 0.5), 0, 255)
end

local function hex(c: Color3): string
	return ("#%02X%02X%02X"):format(to255(c.R), to255(c.G), to255(c.B))
end

local function fromHex(text: unknown): Color3?
	if type(text) ~= "string" then
		return nil
	end
	local r, g, b = text:match("^#(%x%x)(%x%x)(%x%x)$")
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(
		tonumber(r, 16) :: number,
		tonumber(g, 16) :: number,
		tonumber(b, 16) :: number
	)
end
SkinSchema.Hex = hex
SkinSchema.FromHex = fromHex

local function materialNamed(name: unknown): Enum.Material?
	if type(name) ~= "string" or #name == 0 or #name > 40 then
		return nil
	end
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(value) == "EnumItem" and (value :: any).Name == name then
		return value :: any
	end
	return nil
end

local function isMaterial(value: unknown): boolean
	if typeof(value) ~= "EnumItem" then
		return false
	end
	return materialNamed((value :: any).Name) == value
end

local function isFinite(x: unknown): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function isInteger(x: unknown): boolean
	return isFinite(x) and math.floor(x :: number) == x
end

-- Is `t` a proper list (keys 1..n, nothing else)? An empty table counts as a list.
local function isSequence(t: { [any]: any }): boolean
	local count = 0
	for key in t do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end
	for i = 1, count do
		if t[i] == nil then
			return false
		end
	end
	return true
end

local function hasNumberKeys(t: { [any]: any }): boolean
	for key in t do
		if type(key) == "number" then
			return true
		end
	end
	return false
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end
SkinSchema.Copy = deepCopy

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Fields ---------------------------------------------------------------------------------------

local function choices(list: { string }): () -> { string }
	return function()
		return list
	end
end

local fields: { Field } = {}

local function field(
	path: { string },
	control: string,
	section: string,
	label: string,
	help: string,
	extra: { [string]: any }?
)
	local f: Field = {
		Key = path[#path],
		Path = path,
		Label = label,
		Help = help,
		Section = section,
		Control = control,
		Optional = true,
	}
	if extra then
		for key, value in extra do
			(f :: any)[key] = value
		end
	end
	table.insert(fields, f)
end

local function headNames(): { string }
	return sortedKeys(HeadPieces.Builders :: any)
end

local function materials(): { string }
	return studio().Materials
end

-- Basics
field(
	{ "Id" },
	"Text",
	"Basics",
	"Id",
	"The skin's code name: <Theme>_<Name>, e.g. Pumpkin_CandleKid. It is saved in players' data, so it never changes once the skin is in the game.",
	{ Optional = false }
)
field(
	{ "Name" },
	"Text",
	"Basics",
	"Name",
	"What players see (1 to 40 letters).",
	{ Optional = false }
)
field(
	{ "Rarity" },
	"Choice",
	"Basics",
	"Rarity",
	"Common, Uncommon, Rare or CRAZY: sets the shop price and how rare it is in crates.",
	{
		Optional = false,
		Economy = true,
		Choices = function()
			return Config.Rarity.Order
		end,
	}
)
field(
	{ "Theme" },
	"Choice",
	"Basics",
	"Theme",
	"The theme file (and crate) the skin belongs to. Fixed for skins already in the game.",
	{
		Choices = themeIds,
	}
)
field(
	{ "Crate" },
	"Choice",
	"Basics",
	"Crate",
	"The crate it drops from. Normally the theme's own crate.",
	{
		Economy = true,
		Choices = crateIds,
	}
)
field(
	{ "Price" },
	"Number",
	"Basics",
	"Price",
	"Its own shop price in coins. Empty = the rarity's price (the normal way).",
	{
		Economy = true,
		Min = 0,
		Max = MAX_PRICE,
		Step = 25,
	}
)
field(
	{ "CrateOnly" },
	"Toggle",
	"Basics",
	"Crate only",
	"On = only from crates, never sold in the shop.",
	{ Economy = true }
)

-- Body
field(
	{ "Style", "Kind" },
	"Choice",
	"Body",
	"Kind",
	"Always Skin.",
	{ Hidden = true, Choices = choices({ "Skin" }) }
)
field(
	{ "Style", "BodyColor" },
	"Color",
	"Body",
	"Body colour",
	"The colour of the whole body (a part colour below wins)."
)
field(
	{ "Style", "TorsoColor" },
	"Color",
	"Body",
	"Torso colour",
	"The colour of the chest and tummy."
)
field(
	{ "Style", "ArmsColor" },
	"Color",
	"Body",
	"Arms colour",
	"The colour of both arms and hands."
)
field({ "Style", "LegsColor" }, "Color", "Body", "Legs colour", "The colour of both legs and feet.")
field(
	{ "Style", "Material" },
	"Material",
	"Body",
	"Body material",
	"What the whole body is made of: Neon glows, Foil shines, Fabric is cloth...",
	{ Choices = materials }
)
field(
	{ "Style", "TorsoMaterial" },
	"Material",
	"Body",
	"Torso material",
	"The torso's own material (wins over Body material).",
	{ Choices = materials }
)
field(
	{ "Style", "ArmsMaterial" },
	"Material",
	"Body",
	"Arms material",
	"The arms' own material.",
	{ Choices = materials }
)
field(
	{ "Style", "LegsMaterial" },
	"Material",
	"Body",
	"Legs material",
	"The legs' own material.",
	{ Choices = materials }
)
field(
	{ "Style", "HeadMaterial" },
	"Material",
	"Body",
	"Head material",
	"The head's own material (no head piece only).",
	{ Choices = materials }
)
field(
	{ "Style", "Transparency" },
	"Number",
	"Body",
	"See-through",
	"0 = solid, 0.9 = nearly invisible. Ghosts use about 0.3.",
	{ Min = 0, Max = 0.9, Step = 0.05 }
)
field(
	{ "Style", "HideClothes" },
	"Toggle",
	"Body",
	"Hide clothes",
	"On = the costume covers the avatar's own shirt and pants (crate skins always do)."
)

-- Accent
field(
	{ "Style", "Accent", "Color" },
	"Color",
	"Accent",
	"Accent colour",
	"A second colour on the body, in the patterns below."
)
field(
	{ "Style", "Accent", "Material" },
	"Material",
	"Accent",
	"Accent material",
	"What the accent pieces are made of (Neon glows).",
	{ Choices = materials }
)
field(
	{ "Style", "Accent", "Pattern" },
	"Patterns",
	"Accent",
	"Patterns",
	"Tap to add or remove: belts, stripes, a cape, wings, a tail...",
	{
		Choices = function()
			return Cosmetics.Patterns
		end,
	}
)

-- Head
field(
	{ "Style", "Head" },
	"Choice",
	"Head",
	"Head piece",
	"A head piece that replaces your head. Uncommon and up. CRAZY heads (★) belong to one skin each.",
	{ Choices = headNames, From = "Uncommon" }
)
field({ "Style", "Face" }, "Choice", "Head", "Face", "The carved face (pumpkin heads only).", {
	Choices = function()
		return HeadPieces.Faces
	end,
	From = "Uncommon",
})
field(
	{ "Style", "HeadColor" },
	"Color",
	"Head",
	"Head colour",
	"The head piece's main colour (or your head's colour without one)."
)
field(
	{ "Style", "HeadColor2" },
	"Color",
	"Head",
	"Head colour 2",
	"The head piece's second colour: the hat, the wrapper, the inner ears...",
	{ From = "Uncommon" }
)
field(
	{ "Style", "HeadColor3" },
	"Color",
	"Head",
	"Head colour 3",
	"A third colour (only the Gentleman Gourd's hat band).",
	{ From = "Uncommon" }
)
field(
	{ "Style", "GlowColor" },
	"Color",
	"Head",
	"Glowing bits",
	"The head piece's glowing bits: carved face, eyes, flames, potions.",
	{ From = "Uncommon" }
)

-- Glow and particles
field(
	{ "Style", "Glow", "Color" },
	"Color",
	"Glow",
	"Glow colour",
	"Glow: a light around you. Rare and up.",
	{ From = "Rare" }
)
field(
	{ "Style", "Glow", "Brightness" },
	"Number",
	"Glow",
	"Glow brightness",
	"How bright the light is (0 to 10, about 2 is normal).",
	{ Min = 0, Max = 10, Step = 0.1, From = "Rare" }
)
field(
	{ "Style", "Glow", "Range" },
	"Number",
	"Glow",
	"Glow range",
	"How far the light reaches, in studs (0 to 60, about 12 is normal).",
	{ Min = 0, Max = 60, Step = 1, From = "Rare" }
)
field(
	{ "Style", "Aura", "Kind" },
	"Choice",
	"Aura",
	"Particles",
	"Particles floating around you. Rare and up.",
	{
		Choices = function()
			return sortedKeys(Config.Skins.Auras :: any)
		end,
		From = "Rare",
	}
)
field(
	{ "Style", "Aura", "Color" },
	"Color",
	"Aura",
	"Particle colour",
	"The particles' colour when they appear.",
	{ From = "Rare" }
)
field(
	{ "Style", "Aura", "Color2" },
	"Color",
	"Aura",
	"Particle colour 2",
	"The colour they fade to.",
	{ From = "Rare" }
)

-- CRAZY
field(
	{ "Style", "Crazy", "Rainbow" },
	"Toggle",
	"CRAZY",
	"Rainbow",
	"A rainbow shimmer over you and rainbow accents. CRAZY only.",
	{ From = "Crazy" }
)
field(
	{ "Style", "Crazy", "Pulse" },
	"Toggle",
	"CRAZY",
	"Pulse",
	"The glow pulses. CRAZY only.",
	{ From = "Crazy" }
)
field(
	{ "Style", "Crazy", "Orbit" },
	"Choice",
	"CRAZY",
	"Orbit",
	"Little pieces flying around you. CRAZY only.",
	{
		Choices = function()
			return HeadPieces.OrbitKinds
		end,
		From = "Crazy",
	}
)
field(
	{ "Style", "Crazy", "Count" },
	"Number",
	"CRAZY",
	"Orbit count",
	"How many pieces fly around you (1 to 8).",
	{ Min = 1, Max = 8, Step = 1, From = "Crazy" }
)
field(
	{ "Style", "Crazy", "Effect" },
	"Choice",
	"CRAZY",
	"Special effect",
	"A big special effect (the one-in-a-million skins have one each).",
	{
		Choices = function()
			return sortedKeys(Config.Skins.Effects.Special :: any)
		end,
		From = "Crazy",
	}
)

-- Animations, walk styles, catalog items
field(
	{ "Style", "Animate" },
	"Effects",
	"Animate",
	"Animations",
	"Moving and colour effects: wings flap, tails wag, glows flicker. Uncommon 1, Rare 3, CRAZY 6.",
	{ From = "Uncommon" }
)
field(
	{ "Style", "Motion" },
	"Motion",
	"Walk",
	"Walk style",
	"How you walk: Zombie, Ghost, Robot, Bat... Rare and up.",
	{ From = "Rare" }
)
field(
	{ "Style", "Catalog" },
	"Catalog",
	"Catalog",
	"Catalog items",
	"Real Roblox catalog items (made by Roblox, you or your group only)."
)

SkinSchema.Fields = fields

-- The Style keys in export order (from Fields).
local STYLE_ORDER: { string } = {}
do
	local seen: { [string]: boolean } = {}
	for _, f in fields do
		if f.Path[1] == "Style" and not seen[f.Path[2]] then
			seen[f.Path[2]] = true
			table.insert(STYLE_ORDER, f.Path[2])
		end
	end
end
SkinSchema.StyleKeys = STYLE_ORDER

local function groupOrder(group: string): { string }
	local out = {}
	for _, f in fields do
		if f.Path[1] == "Style" and f.Path[2] == group and f.Path[3] then
			table.insert(out, f.Path[3])
		end
	end
	return out
end
for _, group in { "Accent", "Glow", "Aura", "Crazy" } do
	KEY_ORDER[group] = groupOrder(group)
end

-- Encode / Decode ------------------------------------------------------------------------------

local function encodeValue(value: any): any
	local kind = typeof(value)
	if kind == "Color3" then
		return hex(value)
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "table" then
		local out = {}
		for k, v in value do
			out[k] = encodeValue(v)
		end
		return out
	end
	return value
end

function SkinSchema.Encode(item: any): any
	return encodeValue(item)
end

function SkinSchema.Same(a: any, b: any): boolean
	return deepEqual(encodeValue(a), encodeValue(b))
end

-- The checks every value gets, whatever its key: depth, proper lists, plain keys, no control
-- characters, finite numbers. `encoded` = only JSON types are allowed (no Color3/Enum).
local function structure(
	value: any,
	path: string,
	depth: number,
	errors: { string },
	encoded: boolean
)
	local kind = typeof(value)
	if kind == "table" then
		if depth > MAX_DEPTH then
			table.insert(errors, path .. " is nested too deep")
			return
		end
		if hasNumberKeys(value) then
			if not isSequence(value) then
				table.insert(errors, path .. " must be a list with no gaps")
				return
			end
		else
			for key in value do
				if type(key) ~= "string" then
					table.insert(errors, path .. " has a key that isn't a name")
					return
				end
			end
		end
		for key, inner in value do
			structure(
				inner,
				path .. (if type(key) == "number" then "[" .. key .. "]" else "." .. key),
				depth + 1,
				errors,
				encoded
			)
		end
	elseif kind == "string" then
		if value:find("%c") then
			table.insert(errors, path .. " has a line break or another hidden character")
		end
	elseif kind == "number" then
		if not isFinite(value) then
			table.insert(errors, path .. " must be a real number")
		end
	elseif kind == "boolean" then
		return
	elseif not encoded and (kind == "Color3" or kind == "EnumItem") then
		return
	else
		table.insert(errors, path .. " has a value of a kind skins can't use (" .. kind .. ")")
	end
end

-- Does `value` have the right type for `kind` (a string from the shapes above)?
local function typeOk(kind: string, value: any, encoded: boolean): boolean
	if kind == "Color3" then
		return if encoded then fromHex(value) ~= nil else typeof(value) == "Color3"
	elseif kind == "Material" then
		return if encoded then materialNamed(value) ~= nil else isMaterial(value)
	elseif kind == "Pattern" then
		if type(value) == "string" then
			return true
		end
		if type(value) ~= "table" then
			return false
		end
		for _, name in value do
			if type(name) ~= "string" then
				return false
			end
		end
		return true
	elseif kind == "Animate" or kind == "Catalog" or kind == "Style" then
		return type(value) == "table"
	elseif kind == "Motion" then
		return type(value) == "string" or type(value) == "table"
	end
	return type(value) == kind
end

local KIND_WORDS: { [string]: string } = {
	Color3 = "a colour",
	Material = "a material",
	Pattern = "a pattern name or a list of them",
	Animate = "a list of animations",
	Catalog = "a table",
	Style = "a table",
	Motion = "a walk style name or a table",
	string = "text",
	number = "a number",
	boolean = "true or false",
}

-- Walks `value` along `shape`: unknown keys and wrong types are errors. Returns the decoded
-- (item-form) copy when `decode` is true.
local function shaped(
	shape: any,
	value: any,
	path: string,
	errors: { string },
	decode: boolean
): any
	if type(shape) == "table" then
		if type(value) ~= "table" then
			table.insert(errors, path .. " must be a table")
			return nil
		end
		local out = {}
		for key, inner in value do
			local sub = if type(key) == "string" then shape[key] else nil
			if sub == nil then
				table.insert(errors, ("%s has an unknown key %s"):format(path, tostring(key)))
			else
				out[key] = shaped(sub, inner, path .. "." .. key, errors, decode)
			end
		end
		return out
	end
	local kind = shape :: string
	if kind == "Style" then
		return shaped(STYLE_SHAPE, value, path, errors, decode)
	end
	if not typeOk(kind, value, decode) then
		table.insert(errors, ("%s must be %s"):format(path, KIND_WORDS[kind] or kind))
		return nil
	end
	if not decode then
		return value
	end
	if kind == "Color3" then
		return fromHex(value)
	elseif kind == "Material" then
		return materialNamed(value)
	elseif kind == "Animate" then
		local out = {}
		for i, effect in value do
			if type(effect) == "table" then
				local copy = deepCopy(effect)
				if type(effect.Colors) == "table" then
					local colors = {}
					for j, text in effect.Colors do
						local c = fromHex(text)
						if not c then
							table.insert(
								errors,
								("%s[%s].Colors[%s] must be a colour"):format(
									path,
									tostring(i),
									tostring(j)
								)
							)
						end
						colors[j] = c
					end
					copy.Colors = colors
				end
				out[i] = copy
			else
				out[i] = effect
			end
		end
		return out
	end
	return deepCopy(value)
end

function SkinSchema.Decode(encoded: any): (any?, { string })
	local errors: { string } = {}
	if type(encoded) ~= "table" then
		return nil, { "The skin must be a table." }
	end
	structure(encoded, "Item", 1, errors, true)
	if #errors > 0 then
		return nil, errors
	end
	local item = shaped(ITEM_SHAPE, encoded, "Item", errors, true)
	if #errors > 0 then
		return nil, errors
	end
	return item, errors
end

-- Ids ------------------------------------------------------------------------------------------

function SkinSchema.IdOk(
	id: unknown,
	theme: unknown,
	taken: { [string]: boolean }?
): (boolean, string?)
	if type(id) ~= "string" or #id == 0 then
		return false, "The Id is empty."
	end
	if #id > MAX_STRING then
		return false, "The Id is too long."
	end
	if id:sub(1, #DRAFT_PREFIX) == DRAFT_PREFIX then
		return false, "Ids can't start with " .. DRAFT_PREFIX .. "."
	end
	if theme == nil then
		-- Classic skins (not in a crate theme): one PascalCase word.
		if not id:match("^%u%w*$") then
			return false, "A classic skin's Id is one word starting with a capital, like Zombie."
		end
	else
		local prefix, rest = id:match("^(%u%a+)_(%u%w+)$")
		if not (prefix and rest) then
			return false,
				("The Id must look like %s_SomeName (letters and numbers, no spaces)."):format(
					tostring(theme)
				)
		end
		if prefix ~= theme then
			return false, ("The Id must start with %s_ (its theme)."):format(tostring(theme))
		end
	end
	if taken and taken[id] then
		return false, ("The Id %s is already used by another skin or draft."):format(id)
	end
	return true, nil
end

function SkinSchema.IdFromName(theme: string?, name: string): string
	local words = {}
	for raw in name:gmatch("[%w']+") do
		local word = raw:gsub("'", "")
		if #word > 0 then
			table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
		end
	end
	local body = table.concat(words)
	if body == "" or not body:match("^%u") then
		body = "Skin" .. body
	end
	body = body:sub(1, MAX_STRING - (if theme then #theme + 1 else 0))
	return if theme then theme .. "_" .. body else body
end

-- Rarity looks ---------------------------------------------------------------------------------

local function isCrateSkin(item: any): boolean
	return SkinSchema.IsCrateTheme(item.Theme) and not item.Exclusive
end

function SkinSchema.RarityProblems(item: any): { string }
	local problems: { string } = {}
	local s = if type(item) == "table" and type(item.Style) == "table" then item.Style else {}
	local id = tostring(if type(item) == "table" then item.Id else "?")
	if type(item) == "table" and isCrateSkin(item) then
		local rarity = item.Rarity
		if rarity == "Common" then
			if s.Head or s.Glow or s.Aura or s.Crazy then
				table.insert(problems, id .. ": Commons are colours, materials and accents only")
			end
			if not (s.BodyColor or s.TorsoColor) then
				table.insert(problems, id .. ": Commons need a BodyColor or TorsoColor")
			end
		elseif rarity == "Uncommon" then
			if not s.Head or s.Glow or s.Aura or s.Crazy then
				table.insert(
					problems,
					id .. ": Uncommons add a head piece (no glow, particles or CRAZY effects)"
				)
			end
		elseif rarity == "Rare" then
			if not (s.Head and s.Glow and s.Aura) or s.Crazy then
				table.insert(problems, id .. ": Rares have a head piece, a glow and particles")
			end
		elseif rarity == "Crazy" then
			if not (s.Head and s.Glow and s.Aura and s.Crazy) then
				table.insert(problems, id .. ": CRAZY skins have everything")
			else
				if s.Crazy.Rainbow ~= true then
					table.insert(problems, id .. ": CRAZY skins have Crazy.Rainbow = true")
				end
				if type(s.Crazy.Orbit) ~= "string" then
					table.insert(problems, id .. ": CRAZY skins have orbiting pieces (Crazy.Orbit)")
				end
			end
		end
	end
	if type(item) == "table" then
		local ok, more = pcall(SkinAnimate.RarityProblems, item)
		if ok and type(more) == "table" then
			for _, text in more do
				table.insert(problems, tostring(text))
			end
		end
	end
	return problems
end

-- The CRAZY heads in `catalogue` (head -> the CRAZY crate skin it belongs to).
local function crazyHeads(catalogue: { any }): { [string]: string }
	local heads: { [string]: string } = {}
	for _, item in catalogue do
		if
			item.Slot == "Skin"
			and item.Rarity == "Crazy"
			and isCrateSkin(item)
			and type(item.Style.Head) == "string"
		then
			heads[item.Style.Head] = item.Id
		end
	end
	return heads
end

function SkinSchema.CrazyHeadProblems(catalogue: { any }): { string }
	local heads = crazyHeads(catalogue)
	local problems = {}
	for _, item in catalogue do
		if item.Slot ~= "Skin" or item.Exclusive then
			continue
		end
		local owner = heads[item.Style.Head]
		if owner and owner ~= item.Id then
			table.insert(
				problems,
				("%s uses %s, the CRAZY head of %s"):format(item.Id, item.Style.Head, owner)
			)
		end
	end
	return problems
end

function SkinSchema.LookKey(style: any): string
	local function c(v: any): string
		if typeof(v) == "Color3" then
			return ("%d,%d,%d"):format(to255(v.R), to255(v.G), to255(v.B))
		end
		return tostring(v)
	end
	local accent = if type(style.Accent) == "table" then style.Accent else {}
	local pattern = accent.Pattern
	if type(pattern) == "table" then
		pattern = table.concat(pattern, "+")
	end
	return table.concat({
		tostring(style.Head),
		c(style.HeadColor),
		c(style.HeadColor2),
		c(style.BodyColor),
		c(style.TorsoColor),
		c(style.ArmsColor),
		c(style.LegsColor),
		tostring(style.Material),
		c(accent.Color),
		tostring(pattern),
	}, "|")
end

-- Animate / Motion / Catalog -------------------------------------------------------------------

local function addAll(into: { string }, list: any)
	if type(list) == "table" then
		for _, text in list do
			table.insert(into, tostring(text))
		end
	end
end

-- Animate, Motion and Catalog are checked by their own modules (SkinAnimate, SkinMotion,
-- SkinCatalog), so the editor, the server and the tests use the same rules. Fills errors and
-- warnings. (pcall: a draft comes from a client, so a check that throws still only refuses it.)
local function checkExtras(style: any, errors: { string }, warnings: { string })
	if style.Animate ~= nil then
		local ok, result, errs, warns = pcall(SkinAnimate.Normalize, style.Animate, style)
		if ok then
			addAll(errors, errs)
			addAll(warnings, warns)
		else
			table.insert(errors, "Style.Animate couldn't be checked: " .. tostring(result))
		end
	end
	if style.Motion ~= nil then
		local ok, result, errs = pcall(SkinMotion.Normalize, style.Motion)
		if ok then
			addAll(errors, errs)
		else
			table.insert(errors, "Style.Motion couldn't be checked: " .. tostring(result))
		end
	end
	if style.Catalog ~= nil then
		local ok, result, errs, warns = pcall(SkinCatalog.Normalize, style.Catalog, style)
		if ok then
			addAll(errors, errs)
			addAll(warnings, warns)
		else
			table.insert(errors, "Style.Catalog couldn't be checked: " .. tostring(result))
		end
	end
	if style.Animate ~= nil or style.Crazy ~= nil then
		local ok, _, problem = pcall(SkinAnimate.EncodeLive, style)
		if ok and problem == "too long" then
			table.insert(
				errors,
				"The animations are too long to send to other players: remove some"
			)
		end
	end
end

-- Validate -------------------------------------------------------------------------------------

local function inList(list: { string }, value: any): boolean
	return type(value) == "string" and table.find(list, value) ~= nil
end

local function between(
	errors: { string },
	value: any,
	path: string,
	low: number,
	high: number,
	integer: boolean?
)
	if value == nil then
		return
	end
	if not isFinite(value) or value < low or value > high then
		table.insert(
			errors,
			("%s must be between %s and %s"):format(path, tostring(low), tostring(high))
		)
	elseif integer and not isInteger(value) then
		table.insert(errors, path .. " must be a whole number")
	end
end

local function checkStrings(value: any, path: string, errors: { string })
	if type(value) == "string" then
		if path ~= "Item.Name" and #value > MAX_STRING then
			table.insert(errors, path .. " is too long")
		end
	elseif type(value) == "table" then
		for key, inner in value do
			checkStrings(inner, path .. "." .. tostring(key), errors)
		end
	end
end

local function semantics(item: any, errors: { string })
	local s = item.Style
	-- the item
	local idOk, why = SkinSchema.IdOk(item.Id, item.Theme)
	if not idOk then
		table.insert(errors, why or "Bad Id")
	end
	local nameLength = if type(item.Name) == "string" then utf8.len(item.Name) else nil
	if not nameLength or nameLength < 1 or nameLength > MAX_NAME then
		table.insert(errors, ("Name must be 1 to %d letters"):format(MAX_NAME))
	end
	if not inList(Config.Rarity.Order, item.Rarity) then
		table.insert(errors, "Rarity must be one of " .. table.concat(Config.Rarity.Order, ", "))
	end
	if item.Theme ~= nil and item.Theme ~= "Tower" and not SkinSchema.IsCrateTheme(item.Theme) then
		table.insert(errors, "Theme " .. tostring(item.Theme) .. " isn't in Config.Skins.Themes")
	end
	if item.Slot ~= nil and item.Slot ~= "Skin" then
		table.insert(errors, "Slot must be Skin")
	end
	if item.Crate ~= nil and not inList(crateIds(), item.Crate) then
		table.insert(errors, "Crate " .. tostring(item.Crate) .. " isn't in Config.Crates.List")
	end
	between(errors, item.Price, "Price", 0, MAX_PRICE, true)
	if item.Odds ~= nil and (not isFinite(item.Odds) or item.Odds <= 0 or item.Odds > 100) then
		table.insert(errors, "Odds must be a percent above 0")
	end
	checkStrings(item, "Item", errors)
	if s == nil then
		table.insert(errors, "Style is missing")
		return
	end
	-- the style
	if s.Kind ~= nil and s.Kind ~= "Skin" then
		table.insert(errors, "Style.Kind must be Skin")
	end
	if s.Head ~= nil and not HeadPieces.Has(s.Head) then
		table.insert(errors, "No head piece called " .. tostring(s.Head))
	end
	if s.Face ~= nil and not inList(HeadPieces.Faces, s.Face) then
		table.insert(errors, "No face called " .. tostring(s.Face))
	end
	between(errors, s.Transparency, "Style.Transparency", 0, 0.9)
	if s.Accent then
		local pattern = s.Accent.Pattern
		local list = if type(pattern) == "table"
			then pattern
			elseif pattern ~= nil then { pattern }
			else {}
		if type(pattern) == "table" and not isSequence(pattern) then
			table.insert(errors, "Style.Accent.Pattern must be a list")
		end
		if #list > studio().MaxPatterns then
			table.insert(
				errors,
				("Style.Accent has more than %d patterns"):format(studio().MaxPatterns)
			)
		end
		for _, name in list do
			if not Cosmetics.HasPattern(name) then
				table.insert(errors, "No accent pattern called " .. tostring(name))
			end
		end
	end
	if s.Glow then
		if typeof(s.Glow.Color) ~= "Color3" then
			table.insert(errors, "Style.Glow needs a Color")
		end
		between(errors, s.Glow.Brightness, "Style.Glow.Brightness", 0, 10)
		between(errors, s.Glow.Range, "Style.Glow.Range", 0, 60)
	end
	if s.Aura then
		if (Config.Skins.Auras :: any)[s.Aura.Kind] == nil then
			table.insert(
				errors,
				"Style.Aura.Kind must be one of "
					.. table.concat(sortedKeys(Config.Skins.Auras :: any), ", ")
			)
		end
	end
	if s.Crazy then
		if s.Crazy.Orbit ~= nil and not inList(HeadPieces.OrbitKinds, s.Crazy.Orbit) then
			table.insert(
				errors,
				"Style.Crazy.Orbit must be one of " .. table.concat(HeadPieces.OrbitKinds, ", ")
			)
		end
		between(errors, s.Crazy.Count, "Style.Crazy.Count", 1, 8, true)
		if
			s.Crazy.Effect ~= nil
			and (Config.Skins.Effects.Special :: any)[s.Crazy.Effect] == nil
		then
			table.insert(errors, "No special effect called " .. tostring(s.Crazy.Effect))
		end
	end
end

-- Every check, with each problem's section (for the editor's warning lines).
local function problemsOf(item: any, catalogue: { any }): ({ string }, { SectionProblem })
	local errors: { string } = {}
	local warnings: { SectionProblem } = {}
	local function warn(section: string, text: string)
		table.insert(warnings, { Section = section, Text = text })
	end
	if type(item) ~= "table" then
		return { "The skin must be a table." }, warnings
	end
	structure(item, "Item", 1, errors, false)
	if #errors == 0 then
		shaped(ITEM_SHAPE, item, "Item", errors, false)
	end
	if #errors > 0 then
		return errors, warnings
	end
	semantics(item, errors)
	local s = item.Style
	if s then
		local extraWarnings: { string } = {}
		local extraErrors: { string } = {}
		checkExtras(s, extraErrors, extraWarnings)
		for _, text in extraErrors do
			table.insert(errors, text)
		end
		for _, text in extraWarnings do
			local lower = text:lower()
			local section = if lower:find("catalog")
				then "Catalog"
				elseif lower:find("motion") or lower:find("walk") then "Walk"
				else "Animate"
			warn(section, text)
		end
	end
	if #errors == 0 then
		local ok, text = pcall(function()
			return HttpService:JSONEncode(encodeValue(item))
		end)
		if not ok then
			table.insert(errors, "The skin can't be turned into text")
		elseif #text > studio().MaxDraftBytes then
			table.insert(
				errors,
				("The skin is too big (%d characters, most %d)"):format(
					#text,
					studio().MaxDraftBytes
				)
			)
		end
	end
	if #errors > 0 or not s then
		return errors, warnings
	end
	-- Warnings: allowed in drafts, but the catalogue tests would complain.
	for _, text in SkinSchema.RarityProblems(item) do
		local lower = text:lower()
		warn(
			if lower:find("walk style")
				then "Walk"
				elseif lower:find("animation") then "Animate"
				else "Basics",
			text
		)
	end
	if s.Accent and s.Accent.Pattern == nil then
		warn("Accent", "The accent has no pattern, so its colour doesn't show: pick one")
	end
	local key = SkinSchema.LookKey(s)
	local heads = crazyHeads(catalogue)
	for _, other in catalogue do
		if other.Slot ~= "Skin" or other.Id == item.Id then
			continue
		end
		if SkinSchema.LookKey(other.Style) == key then
			warn("Body", ("%s and %s look the same"):format(other.Id, item.Id))
		end
		if other.Name == item.Name then
			warn("Basics", ("%s is also called %q"):format(other.Id, tostring(item.Name)))
		end
		if
			s.Head
			and other.Style.Head == s.Head
			and item.Rarity == "Crazy"
			and isCrateSkin(item)
			and not other.Exclusive
		then
			warn(
				"Head",
				("%s already uses %s, so it can't be this CRAZY skin's own head"):format(
					other.Id,
					s.Head
				)
			)
		end
	end
	local owner = s.Head and heads[s.Head]
	if owner and owner ~= item.Id then
		warn("Head", ("%s uses %s, the CRAZY head of %s"):format(tostring(item.Id), s.Head, owner))
	end
	if isCrateSkin(item) then
		if item.Crate ~= nil and item.Crate ~= SkinSchema.ThemeCrate(item.Theme) then
			warn(
				"Basics",
				"Crate skins normally drop from their theme's own crate (the tests expect it)"
			)
		end
		if item.Price ~= nil then
			warn(
				"Basics",
				"Crate skins normally use the rarity's price (the tests expect no Price)"
			)
		end
		if item.CrateOnly then
			warn(
				"Basics",
				"Crate skins are normally sold in the shop too (the tests expect no CrateOnly)"
			)
		end
		local catalog = if type(s.Catalog) == "table" then s.Catalog else {}
		local clothes = catalog.Shirt ~= nil or catalog.Pants ~= nil or catalog.TShirt ~= nil
		if s.HideClothes == false and not clothes then
			warn("Body", "Crate skins normally hide clothes (the tests expect HideClothes on)")
		end
	end
	return errors, warnings
end

function SkinSchema.Validate(item: any): (boolean, { string }, { string })
	local errors, problems = problemsOf(item, Config.Shop.Items)
	local warnings = {}
	if #errors == 0 then
		for _, p in problems do
			table.insert(warnings, p.Text)
		end
	end
	return #errors == 0, errors, warnings
end

function SkinSchema.CheckSections(item: any, catalogue: { any }): { SectionProblem }
	local errors, problems = problemsOf(item, catalogue)
	if #errors > 0 then
		local out = {}
		for _, text in errors do
			table.insert(out, { Section = "Errors", Text = text })
		end
		return out
	end
	return problems
end

function SkinSchema.Check(item: any, catalogue: { any }): { string }
	local _, problems = problemsOf(item, catalogue)
	local out = {}
	for _, p in problems do
		table.insert(out, p.Text)
	end
	return out
end

-- Making and changing items --------------------------------------------------------------------

function SkinSchema.NewItem(theme: string?): any
	local crateTheme = SkinSchema.IsCrateTheme(theme)
	local name = studio().Text.NewName
	local item: any = {
		Id = SkinSchema.IdFromName(if crateTheme then theme else nil, name),
		Name = name,
		Rarity = "Common",
		Slot = "Skin",
		Theme = if crateTheme then theme else nil,
		Crate = if crateTheme then SkinSchema.ThemeCrate(theme) else nil,
		Style = {
			Kind = "Skin",
			BodyColor = Color3.fromRGB(255, 130, 20),
			Accent = { Color = Color3.fromRGB(35, 28, 45), Pattern = "Stripes" },
			HideClothes = if crateTheme then true else nil,
		},
	}
	return item
end

function SkinSchema.Duplicate(item: any): any
	local copy = deepCopy(item)
	copy.Id = tostring(item.Id) .. "Copy"
	copy.Name = tostring(item.Name) .. " Copy"
	copy.OneInAMillion = nil -- one per crate
	copy.Odds = nil
	return copy
end

function SkinSchema.WearItem(record: any): any
	local item = record.Item
	local suffix = if type(record.DraftId) == "string"
		then record.DraftId
		else "U" .. tostring(record.Author or 0)
	local style = deepCopy(item.Style)
	style.Kind = "Skin"
	if style.HideClothes == nil and item.Theme ~= nil then
		style.HideClothes = true
	end
	return {
		Id = DRAFT_PREFIX .. suffix,
		ModelId = item.Id,
		Slot = "Skin",
		Name = item.Name,
		Rarity = item.Rarity,
		Theme = item.Theme,
		Style = style,
	}
end

-- Sets that make a group (Accent, Glow, ...) start with these, so it is valid straight away.
local GROUP_DEFAULTS: { [string]: () -> any } = {
	Accent = function()
		return { Color = Color3.fromRGB(35, 28, 45), Pattern = "Belt" }
	end,
	Glow = function()
		return { Color = WHITE }
	end,
	Aura = function()
		return { Kind = "Sparkles", Color = WHITE }
	end,
	Crazy = function()
		return { Rainbow = true }
	end,
}
SkinSchema.GroupDefaults = GROUP_DEFAULTS

function SkinSchema.Get(item: any, path: { string | number }): any
	local node = item
	for _, key in path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

-- Changes one key in place (value nil = remove it). A missing group is made with its defaults;
-- a group left empty is removed.
function SkinSchema.Set(item: any, path: { string | number }, value: any)
	local node = item
	local parents = {}
	for i = 1, #path - 1 do
		local key = path[i]
		local nextNode = node[key]
		if type(nextNode) ~= "table" then
			if value == nil then
				return
			end
			local make = if i == 2 and path[1] == "Style" then GROUP_DEFAULTS[key :: any] else nil
			nextNode = if make then make() else {}
			node[key] = nextNode
		end
		table.insert(parents, { node, key })
		node = nextNode
	end
	node[path[#path]] = value
	if value == nil then
		-- remove empty groups (never the Style itself)
		for i = #parents, 1, -1 do
			local parent, key = parents[i][1], parents[i][2]
			local child = parent[key]
			if
				type(child) == "table"
				and next(child) == nil
				and not (i == 1 and key == "Style")
			then
				parent[key] = nil
			else
				break
			end
		end
	end
end

-- Luau for the theme files ---------------------------------------------------------------------

local function num(x: number): string
	if x == math.floor(x) and math.abs(x) < 1e15 then
		return ("%d"):format(x)
	end
	for precision = 1, 17 do
		local text = ("%." .. precision .. "g"):format(x)
		if tonumber(text) == x then
			return text
		end
	end
	return ("%.17g"):format(x)
end

local function quote(text: string): string
	local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. escaped .. '"'
end

local function keyText(key: string): string
	if key:match("^[%a_][%w_]*$") then
		return key
	end
	return "[" .. quote(key) .. "]"
end

local function orderedKeys(t: { [string]: any }, order: { string }?): { string }
	local out = {}
	local seen = {}
	if order then
		for _, key in order do
			if t[key] ~= nil then
				table.insert(out, key)
				seen[key] = true
			end
		end
	end
	local rest = {}
	for key in t do
		if type(key) == "string" and not seen[key] then
			table.insert(rest, key)
		end
	end
	table.sort(rest)
	for _, key in rest do
		table.insert(out, key)
	end
	return out
end

local function width(text: string): number
	local _, tabs = text:gsub("\t", "")
	return #text + tabs * 3
end

local value: (v: any, indent: number, orderFor: string?, lead: string) -> string

-- `lead` is what comes before the value on its line (for the 100-column limit).
local function tableText(t: { [any]: any }, indent: number, orderFor: string?, lead: string): string
	local items: { string } = {}
	if isSequence(t) and next(t) ~= nil then
		local childOrder = if orderFor == "Animate"
			then "Effect"
			elseif orderFor == "Accessories" then "Accessory"
			else nil
		for _, v in t do
			table.insert(items, value(v, indent + 1, childOrder, string.rep("\t", indent + 1)))
		end
	else
		for _, key in orderedKeys(t, if orderFor then KEY_ORDER[orderFor] else nil) do
			local prefix = keyText(key) .. " = "
			table.insert(
				items,
				prefix .. value(t[key], indent + 1, key, string.rep("\t", indent + 1) .. prefix)
			)
		end
	end
	if #items == 0 then
		return "{}"
	end
	local inline = "{ " .. table.concat(items, ", ") .. " }"
	if not inline:find("\n") and width(lead .. inline) <= 100 then
		return inline
	end
	local pad = string.rep("\t", indent + 1)
	return "{\n"
		.. pad
		.. table.concat(items, ",\n" .. pad)
		.. ",\n"
		.. string.rep("\t", indent)
		.. "}"
end

value = function(v: any, indent: number, orderFor: string?, lead: string): string
	local kind = typeof(v)
	if kind == "Color3" then
		return ("rgb(%d, %d, %d)"):format(to255(v.R), to255(v.G), to255(v.B))
	elseif kind == "EnumItem" then
		if isMaterial(v) then
			return "M." .. v.Name
		end
		return tostring(v)
	elseif kind == "string" then
		return quote(v)
	elseif kind == "number" then
		return num(v)
	elseif kind == "boolean" then
		return tostring(v)
	elseif kind == "table" then
		return tableText(v, indent, orderFor, lead)
	end
	return "nil"
end

-- A lead too long for anything to fit on its line: the table is written one item per line.
local LONG_LEAD = string.rep(" ", 101)

local function commas(n: number): string
	local out = tostring(math.floor(n + 0.5))
	while true do
		local swapped, count = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		out = swapped
		if count == 0 then
			return out
		end
	end
end

function SkinSchema.ToLuau(item: any, theme: string?): string
	local fileTheme = theme or item.Theme
	local crate = SkinSchema.IsCrateTheme(fileTheme)
	local lines = { "\t{" }
	for _, key in ITEM_ORDER do
		local v = item[key]
		if v == nil then
			continue
		end
		if crate then
			-- Filled in by Skins/init.luau, so the theme files leave them out.
			if (key == "Slot" and v == "Skin") or (key == "Theme" and v == fileTheme) then
				continue
			end
			if key == "Crate" and v == SkinSchema.ThemeCrate(fileTheme) then
				continue
			end
		end
		if key == "Style" then
			table.insert(lines, "\t\tStyle = {")
			for _, styleKey in orderedKeys(v, STYLE_ORDER) do
				local sv = v[styleKey]
				if
					crate
					and (
						(styleKey == "Kind" and sv == "Skin")
						or (styleKey == "HideClothes" and sv == true)
					)
				then
					continue
				end
				local prefix = "\t\t\t" .. keyText(styleKey) .. " = "
				if styleKey == "Animate" and type(sv) == "table" then
					-- one effect per line, marked for the type checker (effects differ in shape),
					-- the way the theme files write them
					local text = value(sv, 3, styleKey, LONG_LEAD)
					table.insert(
						lines,
						prefix .. text .. " :: { any }, -- (effects differ in shape)"
					)
					continue
				end
				table.insert(lines, prefix .. value(sv, 3, styleKey, prefix) .. ",")
			end
			table.insert(lines, "\t\t},")
			continue
		end
		local line = "\t\t"
			.. keyText(key)
			.. " = "
			.. value(v, 2, key, "\t\t" .. key .. " = ")
			.. ","
		if key == "OneInAMillion" and v == true then
			line ..= " -- only in this crate, never in the CRAZY Crate"
		elseif key == "Odds" and isFinite(v) and v > 0 then
			line ..= (" -- percent: 1 in %s opens"):format(commas(100 / v))
		end
		table.insert(lines, line)
	end
	-- keys this schema doesn't know (never in a valid draft) are written too, so nothing is lost
	for _, key in orderedKeys(item, ITEM_ORDER) do
		if ITEM_SHAPE[key] == nil and key ~= "ModelId" then
			table.insert(
				lines,
				"\t\t" .. keyText(key) .. " = " .. value(item[key], 2, key, "\t\t") .. ","
			)
		end
	end
	table.insert(lines, "\t},")
	return table.concat(lines, "\n")
end

return SkinSchema
