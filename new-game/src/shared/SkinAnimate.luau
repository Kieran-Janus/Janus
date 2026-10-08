--!strict
--[[
	Animated skins: the effects a skin's Style.Animate list can use, checking them, and the
	maths of every effect. Pure and shared: the server checks and builds skins with it
	(src/shared/Cosmetics.luau), every player's screen animates them (src/client/SkinAnim.luau)
	and Skin Studio builds its controls from the metadata. The numbers are in
	Config.SkinAnimate (src/shared/Config/SkinAnimate.luau).

	A skin's effects:
	    Animate = {
	        { Effect = "Flap", Target = "Wings", Speed = 1.5 },
	        { Effect = "ColorCycle", Target = "Head", Colors = { rgb(255, 120, 0), rgb(150, 60, 200) } },
	    }
	Keys (all optional except Effect): Target, Speed (0.1-5), Amount (0-3), Delay (0-10 s),
	Axis ("X", "Y", "Z"), Reverse (Spin), Colors (ColorCycle, 2-6 colours), Every (Flicker and
	SparkleBurst, seconds), Count (SparkleBurst, 1-50).
	Targets: "Head" (the head piece or custom model), "Wings" / "Tail" / "Cape" (those accent
	patterns, they can move), any other accent pattern name ("Belt", "Stripes"...),
	"Accents" (every accent piece), "All" (head + accents), "Body" (the avatar's body parts),
	"Glow" (the light), "Aura" (the particles), "Part:<Name>" (parts or a Model called <Name>
	inside the head piece or custom model).
	CRAZY owns what Style.Crazy drives: with Crazy.Rainbow no colour effect may target the
	accents, with Crazy.Pulse no Pulse or Flicker may target the Glow (Normalize says so).

	SkinAnimate.Effects                      every effect's metadata, in editor order
	SkinAnimate.Info(name) -> EffectInfo?
	SkinAnimate.Has(name) -> boolean
	SkinAnimate.IsMotion(name) -> boolean    Spin, Bob, Float, Wobble, Flap, Wag, Breathe
	SkinAnimate.MovingPatterns               { "Wings", "Tail", "Cape" }: patterns that can move
	SkinAnimate.IsFinite(x) -> boolean       a number that isn't NaN or +-inf
	SkinAnimate.Normalize(list, style?) -> (effects?, errors, warnings)
	                                         checks a Style.Animate list and fills defaults; bad
	                                         entries are left out (and explained in errors)
	SkinAnimate.FromAttributes(instance) -> Effect?
	                                         a custom-model part's Animate / Speed / Amount /
	                                         Delay / Every / Axis / Reverse / Color2 attributes
	SkinAnimate.Forbidden(effect, target, style?) -> string?   why CRAZY owns this target, or nil
	SkinAnimate.TargetsIn(style, partNames?, effect?) -> { string }
	                                         the targets this style really has (for an effect:
	                                         only those it may use)
	SkinAnimate.PartNames(model) -> { string }   names of parts/Models in a head piece (Part:)
	SkinAnimate.Offset(effect, t, side?) -> CFrame         a moving piece's offset at time t
	SkinAnimate.Tint(effect, base, t, index, height, seed) -> Color3
	SkinAnimate.Brightness(effect, base, t, seed) -> number
	SkinAnimate.BurstDue(effect, lastT, t) -> boolean
	SkinAnimate.BurstCount(effect, scale) -> number
	SkinAnimate.Hash(a, b) -> number         a repeatable 0-1 number (Flicker)
	SkinAnimate.EncodeLive(style) -> (string?, problem?)   a draft's { Crazy, Animate } as JSON
	SkinAnimate.DecodeLive(text) -> { Crazy?, Animate? }
	SkinAnimate.StyleOf(model) -> style?     the catalogue item's Style (attribute ItemId), else
	                                         the draft's LiveStyle
	SkinAnimate.RarityProblems(item) -> { string }   Config.SkinAnimate.Rarity rules

	Time t is Workspace:GetServerTimeNow(), so every screen shows the same wing beat at once.
]]

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

local SkinAnimate = {}

export type Effect = {
	Effect: string,
	Target: string,
	Speed: number,
	Amount: number,
	Delay: number,
	Axis: string?,
	Reverse: boolean?,
	Colors: { Color3 }?,
	Every: number?,
	Count: number?,
}

export type ParamInfo = {
	Key: string,
	Label: string,
	Help: string,
	Type: "number" | "boolean" | "Axis" | "Colors",
	Min: number?,
	Max: number?,
	Step: number?,
	Default: any,
}

export type EffectInfo = {
	Name: string,
	Label: string,
	Help: string,
	Kind: "Motion" | "Colour" | "Light" | "Particles",
	Targets: { string }, -- target kinds: "Head", "Wings", "Tail", "Cape", "Pattern" (any
	-- accent pattern), "Accents", "All", "Body", "Glow", "Aura", "Part" (Part:<Name>)
	DefaultTarget: string,
	Params: { ParamInfo }, -- every key it takes besides Effect and Target, in editor order
}

local function settings()
	return Config.SkinAnimate
end

local function preset(name: string): any
	return settings().Presets[name] or {}
end

-- Metadata ---------------------------------------------------------------------------------------

local presets = Config.SkinAnimate.Presets

local SPEED: ParamInfo = {
	Key = "Speed",
	Label = "Speed",
	Help = "How fast: 2 = twice as fast, 0.5 = half as fast.",
	Type = "number",
	Min = 0.1,
	Max = 5,
	Step = 0.1,
	Default = 1,
}
local AMOUNT: ParamInfo = {
	Key = "Amount",
	Label = "Amount",
	Help = "How strong: bigger moves or stronger colours (1 = normal).",
	Type = "number",
	Min = 0,
	Max = 3,
	Step = 0.1,
	Default = 1,
}
local DELAY: ParamInfo = {
	Key = "Delay",
	Label = "Delay",
	Help = "Seconds later it starts, so two effects don't move together.",
	Type = "number",
	Min = 0,
	Max = 10,
	Step = 0.1,
	Default = 0,
}
local function axis(default: string): ParamInfo
	return {
		Key = "Axis",
		Label = "Axis",
		Help = "Which way it turns: X = nod forward and back, Y = turn left and right, Z = tilt sideways.",
		Type = "Axis",
		Default = default,
	}
end
local REVERSE: ParamInfo = {
	Key = "Reverse",
	Label = "Reverse",
	Help = "Spin the other way.",
	Type = "boolean",
	Default = false,
}
local COLORS: ParamInfo = {
	Key = "Colors",
	Label = "Colours",
	Help = "2 to 6 colours to fade through, in order.",
	Type = "Colors",
	Default = nil,
}
local function every(min: number, default: number, help: string): ParamInfo
	return {
		Key = "Every",
		Label = "Every",
		Help = help,
		Type = "number",
		Min = min,
		Max = 30,
		Step = if min < 0.1 then 0.01 else 0.1,
		Default = default,
	}
end
local COUNT: ParamInfo = {
	Key = "Count",
	Label = "Count",
	Help = "Particles in each burst (1 to 50).",
	Type = "number",
	Min = 1,
	Max = 50,
	Step = 1,
	Default = presets.SparkleBurst.Count,
}

local MOTION_TARGETS = { "Head", "Wings", "Tail", "Cape", "Part" }
local COLOUR_TARGETS = { "Glow", "Head", "Accents", "Pattern", "Body", "Part", "All" }

SkinAnimate.Effects = {
	{
		Name = "Spin",
		Label = "Spin",
		Help = "Turns round and round, like a spinning top.",
		Kind = "Motion",
		Targets = MOTION_TARGETS,
		DefaultTarget = "Head",
		Params = { SPEED, AMOUNT, DELAY, axis("Y"), REVERSE },
	},
	{
		Name = "Bob",
		Label = "Bob",
		Help = "Bobs up and down.",
		Kind = "Motion",
		Targets = MOTION_TARGETS,
		DefaultTarget = "Head",
		Params = { SPEED, AMOUNT, DELAY },
	},
	{
		Name = "Float",
		Label = "Float",
		Help = "Floats up and sways gently, like it's under water.",
		Kind = "Motion",
		Targets = MOTION_TARGETS,
		DefaultTarget = "Head",
		Params = { SPEED, AMOUNT, DELAY },
	},
	{
		Name = "Wobble",
		Label = "Wobble",
		Help = "Tilts from side to side.",
		Kind = "Motion",
		Targets = MOTION_TARGETS,
		DefaultTarget = "Head",
		Params = { SPEED, AMOUNT, DELAY, axis("Z") },
	},
	{
		Name = "Flap",
		Label = "Flap",
		Help = "Wings beat open and back, like a bat.",
		Kind = "Motion",
		Targets = { "Wings", "Part" },
		DefaultTarget = "Wings",
		Params = { SPEED, AMOUNT, DELAY, axis("Y") },
	},
	{
		Name = "Wag",
		Label = "Wag",
		Help = "Swings from side to side, like a happy tail.",
		Kind = "Motion",
		Targets = { "Tail", "Part" },
		DefaultTarget = "Tail",
		Params = { SPEED, AMOUNT, DELAY, axis("Y") },
	},
	{
		Name = "Breathe",
		Label = "Breathe",
		Help = "A slow, tiny lift and tilt, like a cape in a breeze.",
		Kind = "Motion",
		Targets = MOTION_TARGETS,
		DefaultTarget = "Cape",
		Params = { SPEED, AMOUNT, DELAY, axis("X") },
	},
	{
		Name = "Pulse",
		Label = "Pulse",
		Help = "Glows brighter and dimmer, like a heartbeat.",
		Kind = "Light",
		Targets = COLOUR_TARGETS,
		DefaultTarget = "Glow",
		Params = { SPEED, AMOUNT, DELAY },
	},
	{
		Name = "ColorCycle",
		Label = "Colour cycle",
		Help = "Fades through your colours in order, rippling across the pieces.",
		Kind = "Colour",
		Targets = COLOUR_TARGETS,
		DefaultTarget = "Accents",
		Params = { SPEED, AMOUNT, DELAY, COLORS },
	},
	{
		Name = "Flicker",
		Label = "Flicker",
		Help = "Flickers like a candle flame.",
		Kind = "Light",
		Targets = COLOUR_TARGETS,
		DefaultTarget = "Glow",
		Params = {
			SPEED,
			AMOUNT,
			DELAY,
			every(0.05, presets.Flicker.Every, "Seconds between flickers (0.05 to 30)."),
		},
	},
	{
		Name = "Shimmer",
		Label = "Shimmer",
		Help = "A bright band of light sweeps up the pieces.",
		Kind = "Colour",
		Targets = { "Head", "Accents", "Pattern", "Body", "Part", "All" },
		DefaultTarget = "Accents",
		Params = { SPEED, AMOUNT, DELAY },
	},
	{
		Name = "SparkleBurst",
		Label = "Sparkle burst",
		Help = "Bursts out a puff of the skin's particles every few seconds (needs an Aura).",
		Kind = "Particles",
		Targets = { "Aura" },
		DefaultTarget = "Aura",
		Params = {
			SPEED,
			AMOUNT,
			DELAY,
			every(0.5, presets.SparkleBurst.Every, "Seconds between bursts (0.5 to 30)."),
			COUNT,
		},
	},
} :: { EffectInfo }

local byName: { [string]: EffectInfo } = {}
for _, info in SkinAnimate.Effects do
	byName[info.Name] = info
end

SkinAnimate.MovingPatterns = { "Wings", "Tail", "Cape" }

function SkinAnimate.Info(name: unknown): EffectInfo?
	return if type(name) == "string" then byName[name] else nil
end

function SkinAnimate.Has(name: unknown): boolean
	return type(name) == "string" and byName[name] ~= nil
end

function SkinAnimate.IsMotion(name: unknown): boolean
	local info = SkinAnimate.Info(name)
	return info ~= nil and info.Kind == "Motion"
end

function SkinAnimate.IsFinite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- Accent patterns (Cosmetics.Patterns, looked up when first needed: Cosmetics requires this
-- module, so it can't be required at the top).
local patternSet: { [string]: boolean }? = nil
local function isPattern(name: string): boolean
	local set = patternSet
	if not set then
		local Cosmetics = (require :: any)(script.Parent.Cosmetics)
		local new: { [string]: boolean } = {}
		for _, pattern in Cosmetics.Patterns do
			new[pattern] = true
		end
		patternSet = new
		set = new
	end
	return (set :: { [string]: boolean })[name] == true
end

local KEYWORDS = {
	Head = true,
	Glow = true,
	Aura = true,
	Accents = true,
	Body = true,
	All = true,
}

-- The kind of a target ("Head", "Wings", "Pattern", "Part"...), or nil if it means nothing.
local function targetKind(target: string): string?
	if string.sub(target, 1, 5) == "Part:" then
		local name = string.sub(target, 6)
		if #name >= 1 and #name <= 60 and not string.find(name, "%c") then
			return "Part"
		end
		return nil
	end
	if KEYWORDS[target] then
		return target
	end
	if isPattern(target) then
		return if table.find(SkinAnimate.MovingPatterns, target) then target else "Pattern"
	end
	return nil
end

local function allowed(info: EffectInfo, target: string): boolean
	local kind = targetKind(target)
	if not kind then
		return false
	end
	if table.find(info.Targets, kind) then
		return true
	end
	-- a moving pattern is also "a pattern" for colour effects
	return kind ~= "Pattern" and isPattern(target) and table.find(info.Targets, "Pattern") ~= nil
end

local function crazyOf(style: any): any
	return if type(style) == "table" and type(style.Crazy) == "table" then style.Crazy else nil
end

-- Why Style.Crazy already owns this (effect, target), in plain English, or nil (section 3.2a
-- of docs/SKIN-STUDIO-SPEC.md: two systems writing one property every frame would flicker).
function SkinAnimate.Forbidden(effect: string, target: string, style: any?): string?
	local info = byName[effect]
	local crazy = crazyOf(style)
	if not info or not crazy then
		return nil
	end
	local colour = info.Kind == "Colour" or info.Kind == "Light"
	if
		crazy.Rainbow == true
		and colour
		and (target == "Accents" or target == "All" or isPattern(target))
	then
		return "CRAZY Rainbow already colours the accents. Use Target Head or Body, or turn Crazy.Rainbow off."
	end
	if crazy.Pulse == true and (effect == "Pulse" or effect == "Flicker") and target == "Glow" then
		return "CRAZY Pulse already pulses the glow. Use ColorCycle on the Glow, or turn Crazy.Pulse off."
	end
	return nil
end

local function patternList(style: any): { string }
	local accent = if type(style) == "table" then style.Accent else nil
	if type(accent) ~= "table" then
		return {}
	end
	local pattern = accent.Pattern
	if type(pattern) == "string" then
		return { pattern }
	elseif type(pattern) == "table" then
		local list = {}
		for _, name in pattern do
			if type(name) == "string" then
				table.insert(list, name)
			end
		end
		return list
	end
	return {}
end

-- Checking ---------------------------------------------------------------------------------------

local function isSequence(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	local n = #t
	local count = 0
	for key in t do
		count += 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > n then
			return false
		end
	end
	return count == n
end

local AXES = { X = true, Y = true, Z = true }

-- What a target this style doesn't have would do (nothing), or nil.
local function missing(target: string, style: any): string?
	if type(style) ~= "table" then
		return nil
	end
	local patterns = patternList(style)
	if target == "Head" then
		return if style.Head == nil
			then "the skin has no head piece (fine if it has a custom model)"
			else nil
	elseif target == "Glow" then
		return if style.Glow == nil then "the skin has no Glow" else nil
	elseif target == "Aura" then
		return if style.Aura == nil then "the skin has no Aura" else nil
	elseif target == "Accents" then
		return if #patterns == 0 then "the skin has no accent pieces" else nil
	elseif target == "All" then
		return if #patterns == 0 and style.Head == nil
			then "the skin has no head piece or accents"
			else nil
	elseif isPattern(target) then
		return if table.find(patterns, target) == nil
			then ("the skin's Accent has no %s pattern"):format(target)
			else nil
	end
	return nil
end

local function checkEntry(
	raw: any,
	index: number,
	style: any,
	custom: boolean
): (Effect?, { string }, { string })
	local errors, warnings = {}, {}
	local function bad(message: string): (Effect?, { string }, { string })
		table.insert(errors, ("Animate %d: %s"):format(index, message))
		return nil, errors, warnings
	end
	if type(raw) ~= "table" then
		return bad('should be a table like { Effect = "Spin" }')
	end
	local name = raw.Effect
	local info = SkinAnimate.Info(name)
	if not info then
		return bad(("unknown Effect %s"):format(tostring(name)))
	end
	local prefix = ("%s: "):format(info.Name)
	local params: { [string]: ParamInfo } = {}
	for _, param in info.Params do
		params[param.Key] = param
	end
	for key in raw do
		if key ~= "Effect" and key ~= "Target" and (type(key) ~= "string" or not params[key]) then
			return bad(prefix .. ("%s doesn't go with %s (typo?)"):format(tostring(key), info.Name))
		end
	end
	local out: Effect = {
		Effect = info.Name,
		Target = info.DefaultTarget,
		Speed = 1,
		Amount = 1,
		Delay = 0,
	}
	local target = raw.Target
	if target ~= nil then
		if type(target) ~= "string" then
			return bad(prefix .. "Target should be a word in quotes")
		end
		out.Target = target
	end
	if not targetKind(out.Target) then
		return bad(prefix .. ("there's no target called %s"):format(out.Target))
	end
	if not allowed(info, out.Target) then
		return bad(prefix .. ("can't be used on %s"):format(out.Target))
	end
	local owned = SkinAnimate.Forbidden(info.Name, out.Target, style)
	if owned then
		return bad(prefix .. owned)
	end
	for key, param in params do
		local value = raw[key]
		if value == nil then
			if
				param.Type == "Axis"
				or (
					param.Type == "number"
					and key ~= "Speed"
					and key ~= "Amount"
					and key ~= "Delay"
				)
			then
				(out :: any)[key] = param.Default
			end
			continue
		end
		if param.Type == "number" then
			if type(value) ~= "number" then
				return bad(prefix .. key .. " should be a number")
			end
			if not SkinAnimate.IsFinite(value) then
				return bad(prefix .. key .. " should be a real number (not NaN or infinity)")
			end
			local min, max = param.Min :: number, param.Max :: number
			if value < min or value > max then
				return bad(
					prefix
						.. ("%s should be between %s and %s"):format(
							key,
							tostring(min),
							tostring(max)
						)
				)
			end
			if key == "Count" and value % 1 ~= 0 then
				return bad(prefix .. "Count should be a whole number")
			end
			(out :: any)[key] = value
		elseif param.Type == "boolean" then
			if type(value) ~= "boolean" then
				return bad(prefix .. key .. " should be true or false")
			end
			(out :: any)[key] = value
		elseif param.Type == "Axis" then
			if type(value) ~= "string" or not AXES[value] then
				return bad(prefix .. 'Axis should be "X", "Y" or "Z"')
			end
			out.Axis = value
		elseif param.Type == "Colors" then
			if not isSequence(value) then
				return bad(prefix .. "Colors should be a list of colours")
			end
			local least = if custom then 1 else 2
			if #value < least or #value > 6 then
				return bad(prefix .. "Colors should have 2 to 6 colours")
			end
			local list = {}
			for _, c in value do
				if typeof(c) ~= "Color3" then
					return bad(prefix .. "Colors should only hold colours (rgb(...))")
				end
				table.insert(list, c)
			end
			out.Colors = list
		end
	end
	if info.Name == "ColorCycle" and out.Colors == nil then
		return bad(prefix .. "needs Colors = { rgb(...), rgb(...) }")
	end
	local why = missing(out.Target, style)
	if why then
		table.insert(
			warnings,
			("Animate %d: %s on %s does nothing: %s"):format(index, info.Name, out.Target, why)
		)
	end
	return out, errors, warnings
end

function SkinAnimate.Normalize(list: any, style: any?): ({ Effect }?, { string }, { string })
	local errors: { string }, warnings: { string } = {}, {}
	if list == nil then
		return nil, errors, warnings
	end
	if not isSequence(list) then
		table.insert(errors, 'Animate should be a list: Animate = { { Effect = "Spin" }, ... }')
		return nil, errors, warnings
	end
	local max = settings().MaxEffects
	if #list > max then
		table.insert(errors, ("Animate has %d effects; at most %d"):format(#list, max))
	end
	local out: { Effect } = {}
	for i, raw in list do
		if i > max then
			break
		end
		local effect, errs, warns = checkEntry(raw, i, style, false)
		table.move(errs, 1, #errs, #errors + 1, errors)
		table.move(warns, 1, #warns, #warnings + 1, warnings)
		if effect then
			table.insert(out, effect)
		end
	end
	return out, errors, warnings
end

-- A custom model's animated part (Kieran sets these attributes in Studio). nil when it has
-- none or a value is wrong (wrong values are ignored, never a script error).
local ATTRIBUTES = { "Speed", "Amount", "Delay", "Every", "Axis", "Reverse" }
function SkinAnimate.FromAttributes(instance: Instance): Effect?
	local name = instance:GetAttribute("Animate")
	local info = SkinAnimate.Info(name)
	if not info then
		return nil
	end
	local keys: { [string]: boolean } = {}
	for _, param in info.Params do
		keys[param.Key] = true
	end
	local raw: { [string]: any } = { Effect = info.Name, Target = "Part:Custom" }
	for _, key in ATTRIBUTES do
		if keys[key] then
			raw[key] = instance:GetAttribute(key)
		end
	end
	local color2 = instance:GetAttribute("Color2")
	if keys.Colors and typeof(color2) == "Color3" then
		raw.Colors = { color2 } -- from the part's own colour to Color2 (see Tint)
	end
	local effect = checkEntry(raw, 1, nil, true)
	return effect
end

-- The targets `style` really has (Skin Studio's dropdown). With `effect`, only the ones that
-- effect may use and Style.Crazy doesn't already own.
function SkinAnimate.TargetsIn(style: any, partNames: { string }?, effect: string?): { string }
	local out: { string } = {}
	local info = if effect then byName[effect] else nil
	local function add(target: string)
		if table.find(out, target) then
			return
		end
		if
			info and (not allowed(info, target) or SkinAnimate.Forbidden(info.Name, target, style))
		then
			return
		end
		table.insert(out, target)
	end
	local s = if type(style) == "table" then style else {}
	local patterns = patternList(s)
	if s.Head ~= nil or (partNames and #partNames > 0) then
		add("Head")
	end
	for _, name in SkinAnimate.MovingPatterns do
		if table.find(patterns, name) then
			add(name)
		end
	end
	if #patterns > 0 then
		add("Accents")
	end
	for _, name in patterns do
		if isPattern(name) then
			add(name)
		end
	end
	if s.Head ~= nil or #patterns > 0 then
		add("All")
	end
	add("Body")
	if s.Glow ~= nil then
		add("Glow")
	end
	if s.Aura ~= nil then
		add("Aura")
	end
	if partNames then
		for _, name in partNames do
			add("Part:" .. name)
		end
	end
	return out
end

-- Unique names of the parts and Models inside a head piece or custom model (Part:<Name>).
function SkinAnimate.PartNames(model: Instance): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, d in model:GetDescendants() do
		if
			(d:IsA("BasePart") or d:IsA("Model"))
			and d:GetAttribute("SkinPart") == "Head"
			and d.Name ~= "AnimPivot"
			and d.Name ~= "AnimGroup"
			and not seen[d.Name]
		then
			seen[d.Name] = true
			table.insert(out, d.Name)
		end
	end
	table.sort(out)
	return out
end

-- Maths ------------------------------------------------------------------------------------------

local TAU = math.pi * 2
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- The angle of a cycle of `seconds` at time t (kept within two turns, so half-speed waves
-- like Float's sway stay smooth).
local function angle(effect: Effect, t: number, seconds: number): number
	return ((t + effect.Delay) * effect.Speed / seconds) % 2 * TAU
end

local function turn(axisName: string?, radians: number): CFrame
	if axisName == "X" then
		return CFrame.Angles(radians, 0, 0)
	elseif axisName == "Z" then
		return CFrame.Angles(0, 0, radians)
	end
	return CFrame.Angles(0, radians, 0)
end

local DEFAULT_AXIS = { Spin = "Y", Wobble = "Z", Flap = "Y", Wag = "Y", Breathe = "X" }

function SkinAnimate.Offset(effect: Effect, t: number, side: number?): CFrame
	local name = effect.Effect
	local p = preset(name)
	local a = effect.Amount
	local ax = effect.Axis or DEFAULT_AXIS[name]
	if name == "Spin" then
		local w = angle(effect, t, p.Seconds)
		return turn(ax, if effect.Reverse then -w else w)
	elseif name == "Bob" then
		return CFrame.new(0, p.Height * a * math.sin(angle(effect, t, p.Seconds)), 0)
	elseif name == "Float" then
		local w = angle(effect, t, p.Seconds)
		return CFrame.new(0, p.Height * a * (0.5 + 0.5 * math.sin(w)), 0)
			* CFrame.Angles(0, 0, math.rad(p.Sway * a * math.sin(w / 2)))
	elseif name == "Wobble" or name == "Wag" then
		return turn(ax, math.rad(p.Degrees * a * math.sin(angle(effect, t, p.Seconds))))
	elseif name == "Flap" then
		local wave = 0.5 + 0.5 * math.sin(angle(effect, t, p.Seconds))
		return turn(ax, math.rad((side or 1) * p.Degrees * a * wave))
	elseif name == "Breathe" then
		local s = math.sin(angle(effect, t, p.Seconds))
		return CFrame.new(0, p.Height * a * s, 0) * turn(ax, math.rad(p.Degrees * a * s))
	end
	return CFrame.identity
end

local TWO32 = 4294967296

-- a * b in 32-bit maths without losing digits (Luau numbers are doubles).
local function mul32(a: number, b: number): number
	local hi = bit32.rshift(a, 16)
	local lo = bit32.band(a, 0xFFFF)
	return ((hi * b % 65536) * 65536 + lo * b) % TWO32
end

-- A repeatable number from 0 to 1 for two whole numbers (the same on every screen).
function SkinAnimate.Hash(a: number, b: number): number
	local h = bit32.bxor(math.floor(a) % TWO32, 0x9E3779B9)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 16)), 0x85EBCA6B)
	h = bit32.bxor(h, math.floor(b) % TWO32)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 13)), 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / TWO32
end

local function flickerDim(effect: Effect, t: number, seed: number): boolean
	local p = preset("Flicker")
	local step = (effect.Every or p.Every) / effect.Speed
	return SkinAnimate.Hash(math.floor((t + effect.Delay) / step), seed) < p.Chance
end

-- How strongly an effect may change colours (Amount above 1 can't be stronger than full).
local function strength(effect: Effect): number
	return math.clamp(effect.Amount, 0, 1)
end

function SkinAnimate.Tint(
	effect: Effect,
	base: Color3,
	t: number,
	index: number,
	height: number,
	seed: number
): Color3
	local name = effect.Effect
	local p = preset(name)
	if name == "Pulse" then
		local wave = 0.5 + 0.5 * math.sin(angle(effect, t, p.Seconds))
		return base:Lerp(BLACK, (1 - wave) * (1 - p.Low) * strength(effect))
	elseif name == "ColorCycle" then
		local given = effect.Colors or {}
		local colors = if #given == 1 then { base, given[1] } else given
		local n = #colors
		if n == 0 then
			return base
		end
		local per = p.SecondsPerColor / effect.Speed
		local pos = ((t + effect.Delay) / per + index * p.Spread) % n
		local i = math.floor(pos)
		local f = pos - i
		f = f * f * (3 - 2 * f) -- ease in and out of each colour
		local c = colors[i + 1]:Lerp(colors[(i + 1) % n + 1], f)
		return base:Lerp(c, strength(effect))
	elseif name == "Flicker" then
		if flickerDim(effect, t, seed) then
			return base:Lerp(BLACK, (1 - p.Low) * strength(effect))
		end
		return base
	elseif name == "Shimmer" then
		-- the band travels from below the bottom to above the top, so it never jumps
		local travel = ((t + effect.Delay) * effect.Speed / p.Seconds) % 1
		local band = -p.Width + travel * (1 + 2 * p.Width)
		local s = math.max(0, 1 - math.abs(height - band) / p.Width) * p.Strength * strength(effect)
		return base:Lerp(WHITE, s)
	end
	return base
end

function SkinAnimate.Brightness(effect: Effect, base: number, t: number, seed: number): number
	local name = effect.Effect
	local p = preset(name)
	if name == "Pulse" then
		local wave = 0.5 + 0.5 * math.sin(angle(effect, t, p.Seconds))
		local low = 1 - (1 - p.Low) * strength(effect)
		return base * (low + (1 - low) * wave)
	elseif name == "Flicker" then
		if flickerDim(effect, t, seed) then
			return base * (1 - (1 - p.Low) * strength(effect))
		end
	end
	return base
end

local function burstPeriod(effect: Effect): number
	local p = preset("SparkleBurst")
	return math.max(effect.Every or p.Every, 0.05) / effect.Speed
end

-- Has a burst moment passed between lastT and t? (Every screen bursts at the same moments.)
function SkinAnimate.BurstDue(effect: Effect, lastT: number, t: number): boolean
	if effect.Effect ~= "SparkleBurst" then
		return false
	end
	local period = burstPeriod(effect)
	return math.floor((t + effect.Delay) / period) > math.floor((lastT + effect.Delay) / period)
end

-- Particles in one burst (scale: 1, or Config.SkinAnimate.PhoneBurstScale on phones).
function SkinAnimate.BurstCount(effect: Effect, scale: number): number
	local p = preset("SparkleBurst")
	local n = math.floor((effect.Count or p.Count) * effect.Amount * scale + 0.5)
	return math.clamp(n, 0, p.MaxCount)
end

-- Drafts (Skin Studio): LiveStyle ------------------------------------------------------------

local function hex(c: Color3): string
	return ("#%02X%02X%02X"):format(
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function fromHex(value: any): Color3?
	if type(value) ~= "string" then
		return nil
	end
	local r, g, b = string.match(value, "^#(%x%x)(%x%x)(%x%x)$")
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(
		tonumber(r, 16) :: number,
		tonumber(g, 16) :: number,
		tonumber(b, 16) :: number
	)
end

-- A copy that JSON can hold: colours as "#RRGGBB", materials by name.
local function jsonSafe(value: any, depth: number): any
	if depth > 6 then
		return nil
	end
	local kind = typeof(value)
	if kind == "Color3" then
		return hex(value)
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return value
	elseif kind == "table" then
		local out = {}
		for key, v in value do
			if type(key) == "string" or type(key) == "number" then
				out[key] = jsonSafe(v, depth + 1)
			end
		end
		return out
	end
	return nil
end

function SkinAnimate.EncodeLive(style: any): (string?, string?)
	if type(style) ~= "table" or (style.Crazy == nil and style.Animate == nil) then
		return nil, nil
	end
	local ok, text = pcall(function()
		return HttpService:JSONEncode({
			Crazy = jsonSafe(style.Crazy, 1),
			Animate = jsonSafe(style.Animate, 1),
		})
	end)
	if not ok or type(text) ~= "string" then
		return nil, "can't be written down"
	end
	if #text > settings().MaxLiveChars then
		return nil, "too long"
	end
	return text, nil
end

local function shortString(value: any): string?
	return if type(value) == "string" and #value <= 60 then value else nil
end

local function decodeCrazy(value: any): any
	if type(value) ~= "table" then
		return nil
	end
	local count = value.Count
	return {
		Rainbow = if type(value.Rainbow) == "boolean" then value.Rainbow else nil,
		Pulse = if type(value.Pulse) == "boolean" then value.Pulse else nil,
		Orbit = shortString(value.Orbit),
		Count = if SkinAnimate.IsFinite(count) then count else nil,
		Effect = shortString(value.Effect),
		OrbitColor = fromHex(value.OrbitColor),
	}
end

function SkinAnimate.DecodeLive(text: any): { Crazy: any?, Animate: { Effect }? }
	if type(text) ~= "string" or #text > settings().MaxLiveChars then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if not ok or type(data) ~= "table" then
		return {}
	end
	local crazy = decodeCrazy(data.Crazy)
	local animate: { Effect }? = nil
	if type(data.Animate) == "table" then
		local raw = {}
		for i, entry in data.Animate do
			if type(entry) == "table" and type(entry.Colors) == "table" then
				local copy = table.clone(entry)
				local colors = {}
				for k, c in entry.Colors do
					colors[k] = fromHex(c) or c
				end
				copy.Colors = colors
				entry = copy
			end
			raw[i] = entry
		end
		local list = SkinAnimate.Normalize(raw, { Crazy = crazy })
		if list and #list > 0 then
			animate = list
		end
	end
	return { Crazy = crazy, Animate = animate }
end

-- The Style a skin model (Cosmetic_Skin or a preview) was built from: the catalogue item named
-- by its ItemId attribute, else a Skin Studio draft's LiveStyle.
function SkinAnimate.StyleOf(model: Instance): any?
	local item = Items.Get(model:GetAttribute("ItemId"))
	if item and type(item.Style) == "table" then
		return item.Style
	end
	local live = model:GetAttribute("LiveStyle")
	if type(live) == "string" then
		local decoded = SkinAnimate.DecodeLive(live)
		if decoded.Crazy ~= nil or decoded.Animate ~= nil then
			return decoded
		end
	end
	return nil
end

-- Rarity rules (Config.SkinAnimate.Rarity): how many effects, and walk styles or not.
function SkinAnimate.RarityProblems(item: any): { string }
	local problems: { string } = {}
	if type(item) ~= "table" or type(item.Style) ~= "table" then
		return problems
	end
	local rules = settings().Rarity
	local rarity = if type(item.Rarity) == "string" and rules[item.Rarity]
		then item.Rarity
		else "Common"
	local rule = rules[rarity]
	local level = Config.Rarity.Levels[rarity]
	local label = if level then level.Name else rarity
	local who = if type(item.Id) == "string" then item.Id .. ": " else ""
	local animate = item.Style.Animate
	local n = if type(animate) == "table" then #animate else 0
	if n > rule.Effects then
		table.insert(
			problems,
			("%s%s skins can have at most %d animation%s (this one has %d)"):format(
				who,
				label,
				rule.Effects,
				if rule.Effects == 1 then "" else "s",
				n
			)
		)
	end
	if item.Style.Motion ~= nil and not rule.Motion then
		table.insert(
			problems,
			("%s%s skins can't have a walk style (Motion): that's for Rare and CRAZY skins"):format(
				who,
				label
			)
		)
	end
	return problems
end

return SkinAnimate
