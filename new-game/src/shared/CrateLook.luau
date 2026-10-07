--!strict
--[[
	How a mystery crate looks and moves, shared by the crate stand (server build), its idle
	animation (src/client/CrateIdle.luau) and the crate panel (src/client/CrateUI.luau).
	Settings: Config.Crates.LookDefaults, each crate's Look, Config.Crates.Idle and
	Config.Crates.Opening (src/shared/Config/Crates.luau).

	CrateLook.Of(crate) -> Look              the crate's Look with every missing field filled in
	                                         from LookDefaults, plus its Body/Trim/Glow colours
	CrateLook.BeamColor(rarity) -> (Color3, boolean)
	                                         the opening beam's colour for a rarity, and whether
	                                         it is a rainbow (CRAZY)
	CrateLook.IsNew(crate) -> boolean        show a NEW ribbon
	CrateLook.Lid(model) -> Lid?             the parts that open and the hinge they turn on:
	                                         the part named "Lid", everything inside it and every
	                                         part with the attribute LidPiece (built chests put
	                                         it on the leaves, bow, ghost...). nil = no lid (a
	                                         custom model without a part named "Lid")
	CrateLook.LidPose(lid, angle) -> ()      opens the lid `angle` degrees (0 = shut)
]]

local Config = require(script.Parent.Config)

local CrateLook = {}

export type SoundSpec = { SoundId: string, Volume: number?, PitchMin: number?, PitchMax: number? }

export type Look = {
	Style: string,
	Emblem: string,
	Accent: Color3,
	Body: Color3,
	Trim: Color3,
	Glow: Color3,
	Bob: number,
	Sway: number,
	PeekEvery: number,
	PeekAngle: number,
	Shake: number,
	Sparkles: number,
	Sounds: { [string]: SoundSpec },
}

export type Lid = {
	Parts: { BasePart },
	Rest: { [BasePart]: CFrame }, -- each part's CFrame relative to the hinge, shut
	Hinge: CFrame, -- the back edge of the lid, relative to the model's pivot; turning about
	-- its X axis opens the lid
	Model: Model,
}

local STYLES = {
	Pumpkin = true,
	Candy = true,
	Coffin = true,
	Tomb = true,
	Monster = true,
	Moon = true,
	Chest = true,
}
CrateLook.Styles = STYLES

function CrateLook.Of(crate: any): Look
	local defaults = Config.Crates.LookDefaults :: any
	local own = (type(crate) == "table" and type(crate.Look) == "table") and crate.Look or {}
	local function pick(key: string): any
		local value = own[key]
		if value == nil then
			value = defaults[key]
		end
		return value
	end
	local sounds: { [string]: SoundSpec } = table.clone(defaults.Sounds)
	if type(own.Sounds) == "table" then
		for key, spec in own.Sounds do
			sounds[key] = spec
		end
	end
	local style = pick("Style")
	if not STYLES[style] then
		style = "Chest"
	end
	local body: Color3 = crate.Color or Color3.fromRGB(200, 120, 60)
	local glow: Color3 = crate.Glow or Color3.new(1, 1, 1)
	return {
		Style = style,
		Emblem = tostring(pick("Emblem") or ""),
		Accent = if typeof(own.Accent) == "Color3" then own.Accent else glow,
		Body = body,
		Trim = crate.Trim or body:Lerp(Color3.new(0, 0, 0), 0.5),
		Glow = glow,
		Bob = tonumber(pick("Bob")) or 0,
		Sway = tonumber(pick("Sway")) or 0,
		PeekEvery = tonumber(pick("PeekEvery")) or 0,
		PeekAngle = tonumber(pick("PeekAngle")) or 0,
		Shake = tonumber(pick("Shake")) or 1,
		Sparkles = tonumber(pick("Sparkles")) or 0,
		Sounds = sounds,
	}
end

function CrateLook.BeamColor(rarity: string?): (Color3, boolean)
	local opening = Config.Crates.Opening
	local name = rarity or "Common"
	if opening.RainbowRarities[name] then
		return Color3.new(1, 1, 1), true
	end
	local color = opening.BeamColors[name]
	if color then
		return color, false
	end
	local level = (Config.Rarity.Levels :: any)[name]
	return (level and level.Color) or Color3.new(1, 1, 1), false
end

function CrateLook.IsNew(crate: any): boolean
	return type(crate) == "table" and crate.New == true
end

-- Every part that belongs to the lid of `model`, or nil when it has no part named "Lid".
function CrateLook.Lid(model: Model): Lid?
	local lidPart = model:FindFirstChild("Lid", true)
	if not (lidPart and lidPart:IsA("BasePart")) then
		return nil
	end
	local parts: { BasePart } = { lidPart }
	local seen: { [BasePart]: boolean } = { [lidPart] = true }
	for _, d in lidPart:GetDescendants() do
		if d:IsA("BasePart") and not seen[d] then
			seen[d] = true
			table.insert(parts, d)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not seen[d] and d:GetAttribute("LidPiece") == true then
			seen[d] = true
			table.insert(parts, d)
		end
	end
	-- The model must not be pivoted on a lid part (opening the lid would move the whole crate):
	-- pivot it on its biggest other part instead, keeping the same pivot.
	local pivot = model:GetPivot()
	if model.PrimaryPart and seen[model.PrimaryPart] then
		local best: BasePart? = nil
		for _, d in model:GetDescendants() do
			if
				d:IsA("BasePart")
				and not seen[d]
				and (not best or d.Size.Magnitude > best.Size.Magnitude)
			then
				best = d
			end
		end
		if not best then
			return nil -- (all lid: nothing to open it from)
		end
		model.PrimaryPart = best
		best.PivotOffset = best.CFrame:ToObjectSpace(pivot)
	end
	-- The hinge: the back (+Z) top edge of the lid, in the model's pivot frame (its front is -Z).
	local local_ = pivot:ToObjectSpace(lidPart.CFrame)
	local half = lidPart.Size / 2
	local top = -math.huge
	local back = -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local p = local_ * Vector3.new(half.X * x, half.Y * y, half.Z * z)
				top = math.max(top, p.Y)
				back = math.max(back, p.Z)
			end
		end
	end
	local centre = local_.Position
	local hingeLocal = CFrame.new(centre.X, top - lidPart.Size.Y * 0.5, back)
	local hinge = pivot * hingeLocal
	local rest: { [BasePart]: CFrame } = {}
	for _, p in parts do
		rest[p] = hinge:ToObjectSpace(p.CFrame)
	end
	return { Parts = parts, Rest = rest, Hinge = hingeLocal, Model = model }
end

-- Opens the lid `angle` degrees about its hinge (0 = shut), wherever the crate is now (it may
-- be bobbing or shaking: the hinge follows the model's pivot).
function CrateLook.LidPose(lid: Lid, angle: number)
	local h = lid.Model:GetPivot() * lid.Hinge * CFrame.Angles(math.rad(angle), 0, 0)
	for _, p in lid.Parts do
		if p.Parent then
			p.CFrame = h * lid.Rest[p]
		end
	end
end

return CrateLook
