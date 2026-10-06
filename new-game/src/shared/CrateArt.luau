--!strict
--[[
	The look of a mystery crate, built from Parts: a wooden box in the crate's Color with
	Trim bands, a glowing "?" on the front and a little Topper on the lid (Config.Crates.List).
	The lobby crate stand (server) and the crate panel's 3D previews (client) both use it, so
	they always match.

	Your own crate model: put a Model named after the crate's Id (e.g. "PumpkinCrate") in
	ReplicatedStorage.Custom.Props. The stand and the panel use it instead, scaled to the
	height of the built crate (front = the model's pivot front, -Z).

	CrateArt.Build(crate, size?) -> Model    the Part-built crate. Pivot: bottom centre of the
	                                         box, front (-Z) shows the "?". size = box width
	                                         in studs (default Config.Crates.Stand.CrateSize)
	CrateArt.Preview(crate, size?) -> Model  your custom model if there is one, else Build
	CrateArt.Height(size?) -> number         how tall a built crate is (box, lid and topper)
	CrateArt.AddPrompt(holder, crate) -> ProximityPrompt
	                                         the "Open <crate>" prompt (attribute CrateId) the
	                                         crate panel opens on (src/client/CrateUI.luau)
]]

local Config = require(script.Parent.Config)
local CustomAssets = require(script.Parent.CustomAssets)
local HeadPieces = require(script.Parent.HeadPieces)

local CrateArt = {}

local WOOD = Enum.Material.WoodPlanks
local NEON = Enum.Material.Neon
local BOX_HEIGHT = 0.78 -- of the width
local LID_HEIGHT = 0.2
local TOPPER = 0.5 -- the topper's biggest side, as a share of the width

local function part(m: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = m
	return p
end

function CrateArt.Height(size: number?): number
	local s = size or Config.Crates.Stand.CrateSize
	return s * (BOX_HEIGHT + LID_HEIGHT + TOPPER * 0.8)
end

-- The "?" on the front face, made of glowing blocks. `front` is the centre of the front face
-- (its -Z points out of the crate); c is one "pixel" of the glyph.
local function questionMark(m: Model, front: CFrame, c: number, glow: Color3, rainbow: boolean)
	local depth = math.max(c * 0.3, 0.05)
	type Piece = { Name: string, W: number, H: number, X: number, Y: number }
	local pieces: { Piece } = {
		{ Name = "Top", W = 2.4, H = 0.8, X = 0, Y = 2.4 },
		{ Name = "Hook", W = 0.8, H = 0.8, X = -1.2, Y = 1.7 },
		{ Name = "Right", W = 0.8, H = 1.8, X = 1.2, Y = 1.5 },
		{ Name = "Middle", W = 1.6, H = 0.8, X = 0.4, Y = 0.6 },
		{ Name = "Stem", W = 0.8, H = 1.2, X = 0, Y = -0.3 },
		{ Name = "Dot", W = 0.8, H = 0.8, X = 0, Y = -1.9 },
	}
	for _, piece in pieces do
		local name, w, h, x, y = piece.Name, piece.W, piece.H, piece.X, piece.Y
		local p = part(m, {
			Name = "Mark" .. name,
			Size = Vector3.new(w * c, h * c, depth),
			-- x is mirrored: the crate's front faces -Z, so the viewer's right is the crate's -X.
			CFrame = front * CFrame.new(-x * c, y * c, -depth / 2),
			Color = glow,
			Material = NEON,
			CastShadow = false,
		})
		if rainbow then
			p:SetAttribute("Rainbow", true)
		end
	end
end

-- A cut gem standing on one corner, with a glowing heart (the rarity crates' topper).
local function gem(color: Color3, glow: Color3): Model
	local g = Instance.new("Model")
	g.Name = "Gem"
	local tilt = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local shell = part(g, {
		Name = "Gem",
		Size = Vector3.one * 0.6,
		CFrame = tilt,
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.15,
	})
	part(g, {
		Name = "GemCore",
		Size = Vector3.one * 0.36,
		CFrame = tilt,
		Color = glow,
		Material = NEON,
		CastShadow = false,
	})
	g.PrimaryPart = shell
	return g
end

function CrateArt.Build(crate: any, size: number?): Model
	local s = size or Config.Crates.Stand.CrateSize
	local m = Instance.new("Model")
	m.Name = crate.Id
	m:SetAttribute("CrateId", crate.Id)
	local color: Color3 = crate.Color
	local trim: Color3 = crate.Trim
	local glow: Color3 = crate.Glow
	local rainbow = crate.Rarity ~= nil
		and (Config.Rarity.Levels :: any)[crate.Rarity] ~= nil
		and (Config.Rarity.Levels :: any)[crate.Rarity].Rainbow == true
	local h = s * BOX_HEIGHT
	local base = CFrame.new(0, 0, 0)

	local box = part(m, {
		Name = "Box",
		Size = Vector3.new(s, h, s),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = color,
		Material = WOOD,
	})
	-- Corner posts and two bands around the box.
	local post = s * 0.13
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(m, {
				Name = "CornerPost",
				Size = Vector3.new(post, h + 0.02, post),
				CFrame = base * CFrame.new(
					x * (s / 2 - post / 2 + 0.03),
					h / 2,
					z * (s / 2 - post / 2 + 0.03)
				),
				Color = trim,
				Material = WOOD,
			})
		end
	end
	part(m, {
		Name = "Band",
		Size = Vector3.new(s + 0.08, s * 0.1, s + 0.08),
		CFrame = base * CFrame.new(0, s * 0.12, 0),
		Color = trim,
		Material = WOOD,
	})
	-- The glowing seam under the lid.
	local seam = part(m, {
		Name = "GlowSeam",
		Size = Vector3.new(s + 0.04, s * 0.05, s + 0.04),
		CFrame = base * CFrame.new(0, h - s * 0.02, 0),
		Color = glow,
		Material = NEON,
		CastShadow = false,
	})
	if rainbow then
		seam:SetAttribute("Rainbow", true)
	end
	local lidH = s * LID_HEIGHT
	part(m, {
		Name = "Lid",
		Size = Vector3.new(s + 0.16, lidH, s + 0.16),
		CFrame = base * CFrame.new(0, h + lidH / 2, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.08),
		Material = WOOD,
	})
	part(m, {
		Name = "LidTrim",
		Size = Vector3.new(s + 0.22, lidH * 0.35, s + 0.22),
		CFrame = base * CFrame.new(0, h + lidH * 0.2, 0),
		Color = trim,
		Material = WOOD,
	})
	-- A clasp under the "?".
	part(m, {
		Name = "Clasp",
		Size = Vector3.new(s * 0.16, s * 0.2, 0.08),
		CFrame = base * CFrame.new(0, h - s * 0.06, -s / 2 - 0.08),
		Color = trim,
		Material = Enum.Material.Metal,
	})
	questionMark(m, base * CFrame.new(0, h * 0.5, -s / 2 - 0.01), s * 0.075, glow, rainbow)

	-- The topper sits on the lid, turned a little so it reads as 3D from the front.
	local ok, topper = pcall(function(): Model
		if crate.Topper == "Gem" then
			return gem(color:Lerp(Color3.new(1, 1, 1), 0.2), glow)
		end
		return HeadPieces.Orbit(tostring(crate.Topper), nil)
	end)
	if ok and topper then
		local _, extent = topper:GetBoundingBox()
		local biggest = math.max(extent.X, extent.Y, extent.Z)
		if biggest > 0.01 then
			topper:ScaleTo(topper:GetScale() * s * TOPPER / biggest)
		end
		local _, scaled = topper:GetBoundingBox()
		topper.Name = "Topper"
		-- A star stands on a point (a sparkle), not on its side (it would read as an "X").
		local roll = if crate.Topper == "Stars" then math.rad(45) else 0
		topper:PivotTo(
			base
				* CFrame.new(0, h + lidH + scaled.Y / 2, 0)
				* CFrame.Angles(0, math.rad(-20), 0)
				* CFrame.Angles(0, 0, roll)
		)
		topper.Parent = m
		for _, d in topper:GetDescendants() do
			if d:IsA("BasePart") and rainbow and d.Material == NEON then
				d:SetAttribute("Rainbow", true)
			end
		end
	end

	m.PrimaryPart = box
	box.PivotOffset = box.CFrame:ToObjectSpace(base)
	return m
end

function CrateArt.AddPrompt(holder: BasePart, crate: any): ProximityPrompt
	local text = Config.Crates.Text
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenCratePrompt"
	prompt.ActionText = text.Prompt:format(crate.Name)
	prompt.ObjectText = text.PromptObject
	prompt.MaxActivationDistance = Config.Crates.Stand.PromptDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CrateId", crate.Id)
	prompt.Parent = holder
	return prompt
end

function CrateArt.Preview(crate: any, size: number?): Model
	local custom = CustomAssets.Clone("Props", crate.Id)
	if custom then
		CustomAssets.Fit(custom, CrateArt.Height(size))
		CustomAssets.MakeDecor(custom)
		CustomAssets.PlaceFeet(custom, CFrame.identity)
		custom:SetAttribute("CrateId", crate.Id)
		return custom
	end
	return CrateArt.Build(crate, size)
end

return CrateArt
