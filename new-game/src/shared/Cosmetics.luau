--!strict
--[[
	Shop cosmetics built from Parts, from each Config.Shop.Items[i].Style.
	Shared so the server can dress characters and the client can draw shop previews with
	exactly the same models.

	Cosmetics.Find(id) -> item?
	Cosmetics.Build(item) -> Model         hats, pets and skin head pieces (anchored,
	                                       PrimaryPart = Handle)
	Cosmetics.Preview(item) -> Model       anything, for a ViewportFrame (trails as a ribbon,
	                                       skins on a stand-in avatar)
	Cosmetics.Wear(character, item)        server: put it on (replaces that slot)
	Cosmetics.TakeOff(character, slot)
	Cosmetics.HasLook(name) -> boolean     is there a builder called `name` (Style.Kind / Head)
	Cosmetics.Patterns                     the accent patterns a skin's Accent can use

	Hats are built with y = 0 at the top of the head; pets around their own centre; skin head
	pieces (src/shared/HeadPieces.luau) around the centre of the head.

	Custom art: a Model (or Accessory) named after the item Id in
	ReplicatedStorage.Custom.Cosmetics replaces the Part-built look (src/shared/CustomAssets).
	A new item can use Style = { Kind = "Custom" } and only a custom model. For a skin, the
	custom model replaces its head piece.

	Skins (Slot "Skin", every option is listed at the top of Config/Skins/Pumpkin.luau):
	  colours and materials for the whole body or per part (head, torso, arms, legs)
	  Accent    a second colour in a pattern (belt, stripes, bones, cape...) made of thin
	            parts welded onto the body
	  Head      a head piece (HeadPieces) that replaces your head
	  Glow      a light around you;  Aura  particles around you (Config.Skins.Auras)
	  Crazy     animated effects drawn by each player's own screen (src/client/SkinFx.luau)
	Everything a skin changes on the avatar is remembered in attributes ("Skin_*") and put
	back by TakeOff; everything it adds lives in the character's Cosmetic_Skin model, which
	TakeOff deletes. A CRAZY skin's model has the tag Tags.SkinFx so SkinFx can find it.
]]

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local CustomAssets = require(script.Parent.CustomAssets)
local HeadPieces = require(script.Parent.HeadPieces)
local Items = require(script.Parent.Items)
local Tags = require(script.Parent.Tags)

local Cosmetics = {}

-- The shop item with this Id, or nil (same as Items.Get).
function Cosmetics.Find(id: unknown): any
	return Items.Get(id)
end

local part = HeadPieces.Part

local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local function eyes(m: Model, y: number, z: number, spacing: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(side * spacing, y, z),
			Color = color,
			Material = Enum.Material.Neon,
		})
	end
end

local builders: { [string]: (Model, any) -> BasePart } = {}

-- Hats ----------------------------------------------------------------------------------------

function builders.PumpkinCap(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.9, 1, 1.9),
		CFrame = CFrame.new(0, 0.3, 0),
		Color = style.Color,
	})
	part(m, {
		Name = "Stem",
		Size = Vector3.new(0.2, 0.45, 0.2),
		CFrame = CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(12)),
		Color = Color3.fromRGB(90, 160, 60),
	})
	return handle
end

function builders.WitchHat(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 3, 3),
		CFrame = upright(CFrame.new(0, 0.05, 0)),
		Color = style.Color,
	})
	part(m, {
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 1.55, 1.55),
		CFrame = upright(CFrame.new(0, 0.25, 0)),
		Color = style.Band,
	})
	local layers = 5
	for i = 0, layers - 1 do
		local r = 0.75 * (1 - i / layers) + 0.08
		part(m, {
			Name = "Cone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.45, r * 2, r * 2),
			CFrame = upright(CFrame.new(i * 0.06, 0.35 + i * 0.42, 0)),
			Color = style.Color,
		})
	end
	return handle
end

function builders.CatEars(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Size = Vector3.new(1.3, 0.12, 0.25),
		CFrame = CFrame.new(0, 0.05, 0),
		Color = style.Color,
	})
	for _, side in { -1, 1 } do
		local base = CFrame.new(side * 0.45, 0.35, 0) * CFrame.Angles(0, 0, math.rad(-side * 15))
		part(m, {
			Name = "Ear",
			Size = Vector3.new(0.45, 0.6, 0.15),
			CFrame = base,
			Color = style.Color,
		})
		part(m, {
			Name = "Inner",
			Size = Vector3.new(0.25, 0.38, 0.05),
			CFrame = base * CFrame.new(0, -0.03, -0.09),
			Color = style.Inner,
		})
	end
	return handle
end

function builders.BatWings(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Size = Vector3.new(1.35, 0.15, 0.3),
		CFrame = CFrame.new(0, 0.05, 0),
		Color = style.Color,
	})
	for _, side in { -1, 1 } do
		for i, size in { Vector3.new(0.9, 0.55, 0.06), Vector3.new(0.7, 0.4, 0.06) } do
			part(m, {
				Name = "Wing",
				Size = size,
				CFrame = CFrame.new(side * (0.8 + i * 0.45), 0.25 + i * 0.12, 0.1)
					* CFrame.Angles(0, math.rad(side * 20), math.rad(side * (20 + i * 15))),
				Color = style.Color,
			})
		end
	end
	return handle
end

function builders.Crown(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, 1.5, 1.5),
		CFrame = upright(CFrame.new(0, 0.2, 0)),
		Color = style.Color,
		Material = Enum.Material.Metal,
	})
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(m, {
			Name = "Spike",
			Size = Vector3.new(0.22, 0.5, 0.22),
			CFrame = CFrame.new(math.cos(a) * 0.62, 0.65, math.sin(a) * 0.62)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = style.Color,
			Material = Enum.Material.Metal,
		})
		part(m, {
			Name = "Gem",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.2,
			CFrame = CFrame.new(math.cos(a) * 0.76, 0.2, math.sin(a) * 0.76),
			Color = Color3.fromRGB(255, 110, 0),
			Material = Enum.Material.Neon,
		})
	end
	return handle
end

-- A three-tier candy corn cone (yellow, orange, white tip), tipped back a little.
function builders.CandyCornHat(m: Model, style: any): BasePart
	local tilt = CFrame.Angles(math.rad(-10), 0, math.rad(6))
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.55, 1.6, 1.6),
		CFrame = tilt * upright(CFrame.new(0, 0.25, 0)),
		Color = style.Base,
	})
	part(m, {
		Name = "Middle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.55, 1.15, 1.15),
		CFrame = tilt * upright(CFrame.new(0, 0.78, 0)),
		Color = style.Middle,
	})
	part(m, {
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.75, 0.8, 0.75),
		CFrame = tilt * CFrame.new(0, 1.25, 0),
		Color = style.Tip,
	})
	return handle
end

-- A bow on the side of the head whose loops are little bat wings.
function builders.BatBow(m: Model, style: any): BasePart
	local at = CFrame.new(0.45, 0.05, -0.1) * CFrame.Angles(0, 0, math.rad(-15))
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.38,
		CFrame = at,
		Color = style.Knot,
	})
	for _, side in { -1, 1 } do
		for i, size in { Vector3.new(0.55, 0.5, 0.08), Vector3.new(0.4, 0.32, 0.08) } do
			part(m, {
				Name = "Wing",
				Size = size,
				CFrame = at
					* CFrame.new(side * (0.3 + (i - 1) * 0.32), 0.05 - (i - 1) * 0.12, 0)
					* CFrame.Angles(0, 0, math.rad(side * (15 + i * 12))),
				Color = style.Color,
			})
		end
	end
	eyes(m, 0.07, -0.14, 0.08, 0.08, style.EyeColor)
	-- the eyes were placed at the origin; move them onto the knot
	for _, child in m:GetChildren() do
		if child.Name == "Eye" and child:IsA("BasePart") then
			child.CFrame = at * child.CFrame
		end
	end
	return handle
end

-- Pets ----------------------------------------------------------------------------------------

-- A tiny witch's cauldron with bubbling green brew.
function builders.CauldronPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.35, 1.05, 1.35),
		Color = style.Color,
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 1.2, 1.2),
		CFrame = upright(CFrame.new(0, 0.42, 0)),
		Color = style.Color,
		Material = Enum.Material.Metal,
	})
	part(m, {
		Name = "Brew",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 1.0, 1.0),
		CFrame = upright(CFrame.new(0, 0.46, 0)),
		Color = style.Brew,
		Material = Enum.Material.Neon,
	})
	for i, offset in { Vector3.new(0.2, 0.62, 0.1), Vector3.new(-0.18, 0.72, -0.15) } do
		part(m, {
			Name = "Bubble",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.22 - i * 0.04),
			CFrame = CFrame.new(offset),
			Color = style.Brew,
			Material = Enum.Material.Neon,
		})
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		part(m, {
			Name = "Leg",
			Size = Vector3.new(0.14, 0.3, 0.14),
			CFrame = CFrame.new(math.cos(a) * 0.4, -0.55, math.sin(a) * 0.4),
			Color = style.Color,
			Material = Enum.Material.Metal,
		})
	end
	return handle
end

-- A round little spider with big eyes and eight legs.
function builders.SpiderPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.0,
		CFrame = CFrame.new(0, 0, 0.25),
		Color = style.Color,
	})
	part(m, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.62,
		CFrame = CFrame.new(0, -0.05, -0.42),
		Color = style.Color,
	})
	eyes(m, 0.02, -0.7, 0.14, 0.2, style.EyeColor)
	for _, side in { -1, 1 } do
		for i = 1, 4 do
			local z = -0.2 + (i - 1) * 0.22
			local yaw = math.rad(side * (-30 + (i - 1) * 25))
			part(m, {
				Name = "Leg",
				Size = Vector3.new(0.75, 0.08, 0.08),
				CFrame = CFrame.new(side * 0.55, -0.05, z)
					* CFrame.Angles(0, yaw, math.rad(side * -30))
					* CFrame.new(side * 0.3, 0, 0),
				Color = style.Color,
			})
		end
	end
	return handle
end

function builders.PumpkinPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.15, 1.4),
		Color = style.Color,
	})
	part(m, {
		Name = "Stem",
		Size = Vector3.new(0.15, 0.35, 0.15),
		CFrame = CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(90, 160, 60),
	})
	eyes(m, 0.15, -0.6, 0.25, 0.22, Color3.fromRGB(255, 220, 90))
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(0.5, 0.1, 0.05),
		CFrame = CFrame.new(0, -0.2, -0.66),
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Neon,
	})
	return handle
end

function builders.BatPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1,
		Color = style.Color,
	})
	eyes(m, 0.12, -0.42, 0.18, 0.2, Color3.fromRGB(255, 70, 70))
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Wing",
			Size = Vector3.new(1.1, 0.08, 0.6),
			CFrame = CFrame.new(side * 0.85, 0.15, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
			Color = style.Color,
		})
		part(m, {
			Name = "Ear",
			Size = Vector3.new(0.18, 0.35, 0.1),
			CFrame = CFrame.new(side * 0.25, 0.55, 0),
			Color = style.Color,
		})
	end
	return handle
end

function builders.GhostPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
		Color = style.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	part(m, {
		Name = "Tail",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 1, 0.8),
		CFrame = CFrame.new(0, -0.7, 0.15),
		Color = style.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Ear",
			Size = Vector3.new(0.3, 0.4, 0.1),
			CFrame = CFrame.new(side * 0.32, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)),
			Color = style.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
	end
	eyes(m, 0.1, -0.58, 0.22, 0.2, Color3.fromRGB(30, 30, 45))
	return handle
end

function builders.SkullPet(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Color = style.Color,
	})
	part(m, {
		Name = "Jaw",
		Size = Vector3.new(0.7, 0.3, 0.6),
		CFrame = CFrame.new(0, -0.55, -0.2),
		Color = style.Color,
	})
	eyes(m, 0.1, -0.5, 0.22, 0.28, Color3.fromRGB(20, 20, 25))
	eyes(m, 0.1, -0.56, 0.22, 0.1, Color3.fromRGB(120, 255, 110))
	return handle
end

-- Skins ------------------------------------------------------------------------------------------

-- Skin head pieces are in src/shared/HeadPieces.luau.
for name, build in HeadPieces.Builders do
	builders[name] = build
end

-- A skin's model is its head piece (or an invisible handle when it only recolours).
function builders.Skin(m: Model, style: any): BasePart
	local head = style.Head and builders[style.Head]
	if head then
		return head(m, style)
	end
	return part(m, { Name = "Handle", Size = Vector3.one * 0.2, Transparency = 1 })
end

-- Which Style keys paint each body part (<Group>Color, <Group>Material), R15 and R6 names.
local GROUP_OF: { [string]: string } = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	Torso = "Torso",
	LeftUpperArm = "Arms",
	LeftLowerArm = "Arms",
	LeftHand = "Arms",
	RightUpperArm = "Arms",
	RightLowerArm = "Arms",
	RightHand = "Arms",
	["Left Arm"] = "Arms",
	["Right Arm"] = "Arms",
	LeftUpperLeg = "Legs",
	LeftLowerLeg = "Legs",
	LeftFoot = "Legs",
	RightUpperLeg = "Legs",
	RightLowerLeg = "Legs",
	RightFoot = "Legs",
	["Left Leg"] = "Legs",
	["Right Leg"] = "Legs",
}

-- Each limb's parts from the bottom up (R15 names, then R6).
local LIMBS: { [string]: { string } } = {
	Torso = { "LowerTorso", "UpperTorso", "Torso" },
	LeftArm = { "LeftHand", "LeftLowerArm", "LeftUpperArm", "Left Arm" },
	RightArm = { "RightHand", "RightLowerArm", "RightUpperArm", "Right Arm" },
	LeftLeg = { "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "Left Leg" },
	RightLeg = { "RightFoot", "RightLowerLeg", "RightUpperLeg", "Right Leg" },
}
local GROUPS: { [string]: { string } } = {
	Torso = { "Torso" },
	Arms = { "LeftArm", "RightArm" },
	Legs = { "LeftLeg", "RightLeg" },
}

local PAD = 0.1 -- bands are this much wider and deeper than the body part they wrap (studs)

-- Where a skin's extra pieces go and how they're attached.
type Dress = {
	Body: Model, -- the character, or the preview stand-in
	Into: Model, -- where new pieces go (the Cosmetic_Skin model)
	Weld: boolean, -- weld to the body (wearing) or leave anchored (preview)
	Color: Color3, -- accent colour and material
	Material: Enum.Material,
	Rainbow: boolean, -- CRAZY: accents start in rainbow colours and SkinFx cycles them
	Count: number,
}

-- A new piece on body part `on` at `offset` (in that part's space). Plain pieces (the aura
-- holder) keep their own colour and never go rainbow.
local function add(
	ctx: Dress,
	on: BasePart,
	props: { [string]: any },
	offset: CFrame,
	plain: boolean?
): Part
	props.CFrame = on.CFrame * offset
	if not plain then
		props.Color = props.Color or ctx.Color
		props.Material = props.Material or ctx.Material
	end
	local p = part(ctx.Into, props)
	if ctx.Rainbow and not plain then
		ctx.Count += 1
		p.Color = Color3.fromHSV((ctx.Count * 0.137) % 1, 0.7, 1)
		p:SetAttribute("Rainbow", true)
	end
	if ctx.Weld then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = on
		weld.Part1 = p
		weld.Parent = p
		p.Anchored = false
	end
	return p
end

local function limbParts(body: Model, limb: string): { BasePart }
	local list = {}
	local names: { string } = LIMBS[limb] or {}
	for _, name in names do
		local p = body:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(list, p)
		end
	end
	return list
end

local function heightOf(parts: { BasePart }): number
	local total = 0
	for _, p in parts do
		total += p.Size.Y
	end
	return total
end

-- The body part at height f of a limb (0 = bottom, 1 = top) and the height there in its space.
local function along(parts: { BasePart }, f: number): (BasePart?, number)
	local target = math.clamp(f, 0, 1) * heightOf(parts)
	local below = 0
	for i, p in parts do
		if target <= below + p.Size.Y or i == #parts then
			return p, math.clamp(target - below, 0, p.Size.Y) - p.Size.Y / 2
		end
		below += p.Size.Y
	end
	return nil, 0
end

-- A band around every limb of `group` ("Torso", "Arms" or "Legs") from height `from` to `to`.
local function fill(ctx: Dress, group: string, from: number, to: number, name: string)
	local limbs: { string } = GROUPS[group] or { group }
	for _, limb in limbs do
		local parts = limbParts(ctx.Body, limb)
		local total = heightOf(parts)
		local below = 0
		for _, p in parts do
			local lo = math.max(below / total, from)
			local hi = math.min((below + p.Size.Y) / total, to)
			if hi - lo > 0.005 then
				local y0 = lo * total - below - p.Size.Y / 2
				local y1 = hi * total - below - p.Size.Y / 2
				add(ctx, p, {
					Name = name,
					Size = Vector3.new(p.Size.X + PAD, y1 - y0, p.Size.Z + PAD),
				}, CFrame.new(0, (y0 + y1) / 2, 0))
			end
			below += p.Size.Y
		end
	end
end

-- A flat piece on the surface of `limb` at height f. face: "Front", "Back" or "Out" (the
-- outer side of an arm or leg); u slides it sideways (-1 to 1); turn tilts it (degrees).
local function onFace(
	ctx: Dress,
	limb: string,
	f: number,
	face: string,
	u: number,
	size: Vector3,
	props: { [string]: any },
	turn: number?
): Part?
	local p, y = along(limbParts(ctx.Body, limb), f)
	if not p then
		return nil
	end
	local s = p.Size
	local offset: CFrame
	if face == "Out" then
		local side = if string.find(limb, "Left") then -1 else 1
		offset = CFrame.new(side * (s.X / 2 + size.Z / 2 - 0.01), y, u * s.Z / 2)
			* CFrame.Angles(0, math.rad(90 * side), 0)
	else
		local dir = if face == "Back" then 1 else -1
		offset = CFrame.new(u * s.X / 2, y, dir * (s.Z / 2 + size.Z / 2 - 0.01))
	end
	if turn then
		offset *= CFrame.Angles(0, 0, math.rad(turn))
	end
	local all = table.clone(props)
	all.Size = size
	return add(ctx, p, all, offset)
end

-- The top part of the torso (UpperTorso or Torso).
local function chest(ctx: Dress): BasePart?
	local parts = limbParts(ctx.Body, "Torso")
	return parts[#parts]
end

-- Accent patterns: each puts thin pieces in the accent colour on the body.
local patterns: { [string]: (Dress) -> () } = {}

function patterns.Belt(ctx: Dress)
	fill(ctx, "Torso", 0, 0.14, "Belt")
	onFace(ctx, "Torso", 0.07, "Front", 0, Vector3.new(0.4, 0.3, 0.06), {
		Name = "Buckle",
		Color = Color3.fromRGB(255, 215, 80),
		Material = Enum.Material.Foil,
	})
end

function patterns.Collar(ctx: Dress)
	fill(ctx, "Torso", 0.86, 1, "Collar")
end

function patterns.Cuffs(ctx: Dress)
	fill(ctx, "Arms", 0.1, 0.2, "Cuff")
	fill(ctx, "Legs", 0.05, 0.14, "Cuff")
end

function patterns.Gloves(ctx: Dress)
	fill(ctx, "Arms", 0, 0.24, "Glove")
end

function patterns.Boots(ctx: Dress)
	fill(ctx, "Legs", 0, 0.32, "Boot")
end

function patterns.Stripes(ctx: Dress)
	for _, range in { { 0.26, 0.38 }, { 0.58, 0.7 } } do
		for _, group in { "Torso", "Arms", "Legs" } do
			fill(ctx, group, range[1], range[2], "Stripe")
		end
	end
end

function patterns.Wraps(ctx: Dress)
	for _, limb in { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		local parts = limbParts(ctx.Body, limb)
		for i, f in { 0.14, 0.38, 0.62, 0.86 } do
			local p, y = along(parts, f)
			if p then
				add(
					ctx,
					p,
					{
						Name = "Wrap",
						Size = Vector3.new(p.Size.X + PAD * 1.5, 0.22, p.Size.Z + PAD * 1.5),
					},
					CFrame.new(0, y, 0)
						* CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 9 else -9))
				)
			end
		end
	end
end

function patterns.Spots(ctx: Dress)
	local spot = { Name = "Spot", Shape = Enum.PartType.Ball }
	onFace(ctx, "Torso", 0.72, "Front", -0.45, Vector3.new(0.5, 0.45, 0.06), spot)
	onFace(ctx, "Torso", 0.42, "Front", 0.42, Vector3.new(0.42, 0.38, 0.06), spot)
	onFace(ctx, "Torso", 0.62, "Back", 0.3, Vector3.new(0.6, 0.55, 0.06), spot)
	onFace(ctx, "Torso", 0.3, "Back", -0.4, Vector3.new(0.4, 0.36, 0.06), spot)
	onFace(ctx, "LeftArm", 0.7, "Out", 0, Vector3.new(0.38, 0.34, 0.06), spot)
	onFace(ctx, "RightArm", 0.45, "Out", 0.1, Vector3.new(0.34, 0.3, 0.06), spot)
	onFace(ctx, "LeftLeg", 0.62, "Front", 0, Vector3.new(0.4, 0.36, 0.06), spot)
	onFace(ctx, "RightLeg", 0.35, "Front", 0.15, Vector3.new(0.36, 0.32, 0.06), spot)
end

function patterns.Belly(ctx: Dress)
	local top = chest(ctx)
	local w = if top then top.Size.X else 2
	onFace(ctx, "Torso", 0.5, "Front", 0, Vector3.new(w * 0.58, w * 0.55, 0.06), {
		Name = "Belly",
		Shape = Enum.PartType.Ball,
	})
end

function patterns.Buttons(ctx: Dress)
	for _, f in { 0.36, 0.55, 0.74 } do
		onFace(ctx, "Torso", f, "Front", 0, Vector3.new(0.24, 0.24, 0.06), {
			Name = "Button",
			Shape = Enum.PartType.Ball,
		})
	end
end

function patterns.Bones(ctx: Dress)
	local bone = { Name = "Bone" }
	onFace(ctx, "Torso", 0.6, "Front", 0, Vector3.new(0.16, 0.95, 0.05), bone)
	for _, f in { 0.47, 0.61, 0.75 } do
		for _, u in { -0.42, 0.42 } do
			onFace(ctx, "Torso", f, "Front", u, Vector3.new(0.6, 0.11, 0.05), bone, u * 12)
		end
	end
	onFace(ctx, "Torso", 0.1, "Front", 0, Vector3.new(0.85, 0.2, 0.05), bone)
	for _, limb in { "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		onFace(ctx, limb, 0.74, "Front", 0, Vector3.new(0.14, 0.75, 0.05), bone)
		onFace(ctx, limb, 0.3, "Front", 0, Vector3.new(0.14, 0.65, 0.05), bone)
	end
end

function patterns.Stitches(ctx: Dress)
	local seam = { Name = "Stitch" }
	onFace(ctx, "Torso", 0.55, "Front", 0.38, Vector3.new(0.05, 1.1, 0.04), seam)
	for i = 0, 4 do
		onFace(ctx, "Torso", 0.36 + i * 0.1, "Front", 0.38, Vector3.new(0.24, 0.05, 0.04), seam)
	end
	for _, limb in { "LeftArm", "RightLeg" } do
		local face = if limb == "LeftArm" then "Out" else "Front"
		onFace(ctx, limb, 0.6, face, 0, Vector3.new(0.9, 0.05, 0.04), seam)
		for i = -1, 1 do
			onFace(ctx, limb, 0.6, face, i * 0.5, Vector3.new(0.05, 0.22, 0.04), seam)
		end
	end
end

function patterns.Patches(ctx: Dress)
	local patch = { Name = "Patch" }
	onFace(ctx, "Torso", 0.35, "Front", -0.45, Vector3.new(0.55, 0.5, 0.05), patch, 8)
	onFace(ctx, "Torso", 0.7, "Back", 0.3, Vector3.new(0.6, 0.55, 0.05), patch, -6)
	onFace(ctx, "LeftLeg", 0.62, "Front", 0.1, Vector3.new(0.5, 0.45, 0.05), patch, -10)
	onFace(ctx, "RightArm", 0.7, "Out", 0, Vector3.new(0.45, 0.4, 0.05), patch, 12)
end

function patterns.Sash(ctx: Dress)
	local top = chest(ctx)
	if not top then
		return
	end
	local w, h = top.Size.X, top.Size.Y
	local length = math.sqrt(w * w + h * h) * 0.9
	local angle = math.deg(math.atan2(h, w))
	for _, dir in { -1, 1 } do
		add(
			ctx,
			top,
			{
				Name = "Sash",
				Size = Vector3.new(length, 0.32, 0.05),
			},
			CFrame.new(0, 0, dir * (top.Size.Z / 2 + 0.02))
				* CFrame.Angles(0, 0, math.rad(dir * angle))
		)
	end
end

function patterns.Cape(ctx: Dress)
	local top = chest(ctx)
	if not top then
		return
	end
	local length = heightOf(limbParts(ctx.Body, "Torso"))
		+ heightOf(limbParts(ctx.Body, "LeftLeg")) * 0.6
	local width = top.Size.X * 0.95
	local hang = CFrame.new(0, top.Size.Y / 2 - 0.05, top.Size.Z / 2 + 0.06)
		* CFrame.Angles(math.rad(-7), 0, 0)
	add(
		ctx,
		top,
		{ Name = "Cape", Size = Vector3.new(width, length, 0.08) },
		hang * CFrame.new(0, -length / 2, 0)
	)
	add(
		ctx,
		top,
		{
			Name = "CapeCollar",
			Size = Vector3.new(width * 0.85, 0.55, 0.08),
		},
		CFrame.new(0, top.Size.Y / 2 + 0.2, top.Size.Z / 2 + 0.04)
			* CFrame.Angles(math.rad(18), 0, 0)
	)
end

function patterns.Wings(ctx: Dress)
	local top = chest(ctx)
	if not top then
		return
	end
	for _, side in { -1, 1 } do
		local root = CFrame.new(side * 0.3, top.Size.Y * 0.3, top.Size.Z / 2 + 0.12)
			* CFrame.Angles(0, math.rad(side * -20), 0)
		local bone = root * CFrame.Angles(0, 0, math.rad(side * 22))
		add(ctx, top, {
			Name = "WingBone",
			Size = Vector3.new(2.3, 0.14, 0.14),
		}, bone * CFrame.new(side * 1.15, 0, 0))
		for i, s in { 1.15, 0.95, 0.75 } do
			add(
				ctx,
				top,
				{
					Name = "Wing",
					Size = Vector3.new(s, s, 0.06),
				},
				bone
					* CFrame.new(side * (i * 0.62 - 0.1), -s * 0.38, 0.02)
					* CFrame.Angles(0, 0, math.rad(45))
			)
		end
	end
end

function patterns.Tail(ctx: Dress)
	local base = limbParts(ctx.Body, "Torso")[1]
	if not base then
		return
	end
	for i = 0, 5 do
		local s = 0.42 - i * 0.04
		add(ctx, base, {
			Name = "Tail",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s,
		}, CFrame.new(
			0,
			-base.Size.Y / 2 + 0.15 + i * i * 0.05,
			base.Size.Z / 2 + 0.12 + i * 0.22
		))
	end
end

function patterns.Web(ctx: Dress)
	local p, y = along(limbParts(ctx.Body, "Torso"), 0.62)
	if not p then
		return
	end
	local centre = CFrame.new(0, y, -(p.Size.Z / 2 + 0.02))
	local thread = { Size = Vector3.new(1.5, 0.04, 0.04) }
	for i = 0, 3 do
		add(
			ctx,
			p,
			{ Name = "Web", Size = thread.Size },
			centre * CFrame.Angles(0, 0, math.rad(i * 45))
		)
	end
	for _, r in { 0.32, 0.62 } do
		for i = 0, 7 do
			local mid = math.rad(i * 45 + 22.5)
			local length = 2 * r * math.sin(math.rad(22.5)) + 0.04
			add(
				ctx,
				p,
				{
					Name = "Web",
					Size = Vector3.new(length, 0.04, 0.04),
				},
				centre
					* CFrame.new(math.cos(mid) * r * 0.93, math.sin(mid) * r * 0.93, 0)
					* CFrame.Angles(0, 0, mid + math.pi / 2)
			)
		end
	end
end

function patterns.Heart(ctx: Dress)
	local p, y = along(limbParts(ctx.Body, "Torso"), 0.62)
	if not p then
		return
	end
	local centre = CFrame.new(0, y, -(p.Size.Z / 2 + 0.03))
	for _, side in { -1, 1 } do
		add(ctx, p, {
			Name = "Heart",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.46, 0.46, 0.05),
		}, centre * CFrame.new(side * 0.15, 0.1, 0))
	end
	add(
		ctx,
		p,
		{ Name = "Heart", Size = Vector3.new(0.46, 0.46, 0.05) },
		centre * CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(45))
	)
end

function patterns.Star(ctx: Dress)
	local p, y = along(limbParts(ctx.Body, "Torso"), 0.6)
	if not p then
		return
	end
	local centre = CFrame.new(0, y, -(p.Size.Z / 2 + 0.03))
	for _, turn in { 0, 45 } do
		add(
			ctx,
			p,
			{ Name = "Star", Size = Vector3.new(0.3, 0.9, 0.05) },
			centre * CFrame.Angles(0, 0, math.rad(turn))
		)
		add(
			ctx,
			p,
			{ Name = "Star", Size = Vector3.new(0.9, 0.3, 0.05) },
			centre * CFrame.Angles(0, 0, math.rad(turn))
		)
	end
end

local patternNames = {}
for name in patterns do
	table.insert(patternNames, name)
end
table.sort(patternNames)
Cosmetics.Patterns = patternNames

-- Is there a builder (Style.Kind or a skin's Head) or an accent pattern called `name`?
function Cosmetics.HasLook(name: unknown): boolean
	return type(name) == "string" and builders[name] ~= nil
end

function Cosmetics.HasPattern(name: unknown): boolean
	return type(name) == "string" and patterns[name] ~= nil
end

-- The accent's pattern names (Pattern = "Belt" or Pattern = { "Belt", "Cuffs" }).
local function patternList(accent: any): { string }
	local pattern = accent.Pattern
	if type(pattern) == "string" then
		return { pattern }
	elseif type(pattern) == "table" then
		return pattern
	end
	return {}
end

local function addAccents(ctx: Dress, style: any)
	local accent = style.Accent
	if type(accent) ~= "table" then
		return
	end
	for _, name in patternList(accent) do
		local make = patterns[name]
		if make then
			make(ctx)
		else
			warn("[Cosmetics] unknown accent pattern " .. tostring(name))
		end
	end
end

local function newDress(body: Model, into: Model, style: any, weld: boolean): Dress
	local accent = if type(style.Accent) == "table" then style.Accent else {}
	local crazy = if type(style.Crazy) == "table" then style.Crazy else {}
	local material: Enum.Material = Enum.Material.SmoothPlastic
	if typeof(accent.Material) == "EnumItem" then
		material = accent.Material :: any
	end
	return {
		Body = body,
		Into = into,
		Weld = weld,
		Color = if typeof(accent.Color) == "Color3" then accent.Color else Color3.new(1, 1, 1),
		Material = material,
		Rainbow = crazy.Rainbow == true,
		Count = 0,
	}
end

-- A rainbow from start to end, for CRAZY particles.
local function rainbowSequence(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.7, 1)))
	end
	return ColorSequence.new(keys)
end

-- The glow light and aura particles (Rare and up), on an invisible part around the body.
local function addGlowAndAura(ctx: Dress, root: BasePart, style: any)
	local glow = if type(style.Glow) == "table" then style.Glow else nil
	local aura = if type(style.Aura) == "table" then style.Aura else nil
	if not glow and not aura then
		return
	end
	local holder = add(ctx, root, {
		Name = "SkinAura",
		Size = Vector3.new(root.Size.X * 1.3, root.Size.Y * 2.3, root.Size.Z * 1.6),
		Transparency = 1,
	}, CFrame.new(0, -root.Size.Y * 0.2, 0), true)
	local settings = Config.Skins
	if glow then
		local light = Instance.new("PointLight")
		light.Name = "SkinGlow"
		light.Color = if typeof(glow.Color) == "Color3" then glow.Color else Color3.new(1, 1, 1)
		light.Brightness = if type(glow.Brightness) == "number"
			then glow.Brightness
			else settings.Glow.Brightness
		light.Range = if type(glow.Range) == "number" then glow.Range else settings.Glow.Range
		light.Shadows = false
		light.Parent = holder
	end
	if aura then
		local look = settings.Auras[aura.Kind] or settings.Auras.Sparkles
		local c1 = if typeof(aura.Color) == "Color3" then aura.Color else Color3.new(1, 1, 1)
		local c2 = if typeof(aura.Color2) == "Color3" then aura.Color2 else c1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SkinAura"
		emitter.Texture = look.Texture
		emitter.Rate = look.Rate
		emitter.Lifetime = NumberRange.new(look.Lifetime[1], look.Lifetime[2])
		emitter.Speed = NumberRange.new(look.Speed[1], look.Speed[2])
		emitter.Size = NumberSequence.new(look.Size[1], look.Size[2])
		emitter.Transparency = NumberSequence.new(look.Transparency[1], look.Transparency[2])
		emitter.Acceleration = Vector3.new(0, look.Rise, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-look.Spin, look.Spin)
		emitter.LightEmission = look.Glow
		emitter.LightInfluence = 1 - math.clamp(look.Glow, 0, 1) -- glowing bits shine at night
		emitter.SpreadAngle = Vector2.new(look.Spread, look.Spread)
		emitter.Color = if ctx.Rainbow then rainbowSequence() else ColorSequence.new(c1, c2)
		emitter.Parent = holder
	end
end

-- Puts every body colour and material of a skin on `body`. `keep` remembers the old values
-- (for TakeOff). Returns true if any colour changed.
local remember: (Instance, string, any) -> ()

local function paintBody(body: Model, style: any, keep: boolean): boolean
	local recoloured = false
	for _, child in body:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			local group = GROUP_OF[child.Name]
			local c = if group then style[group .. "Color"] else nil
			if typeof(c) ~= "Color3" then
				c = style.BodyColor
			end
			local material = if group then style[group .. "Material"] else nil
			if typeof(material) ~= "EnumItem" then
				material = style.Material
			end
			if typeof(c) == "Color3" then
				if keep then
					remember(child, "Color", child.Color)
				end
				child.Color = c
				recoloured = true
			end
			if typeof(material) == "EnumItem" then
				if keep then
					remember(child, "Material", child.Material.Name)
				end
				child.Material = material :: any
			end
			if type(style.Transparency) == "number" then
				if keep then
					remember(child, "Transparency", child.Transparency)
				end
				child.Transparency = math.max(child.Transparency, style.Transparency)
			end
		end
	end
	return recoloured
end

-- Does this skin add anything to the character besides colours?
local function hasExtras(item: any): boolean
	local style = item.Style
	return style.Head ~= nil
		or style.Accent ~= nil
		or style.Glow ~= nil
		or style.Aura ~= nil
		or style.Crazy ~= nil
		or CustomAssets.Has("Cosmetics", item.Id)
end

-- Previews ---------------------------------------------------------------------------------------

local SKIN_TONE = Color3.fromRGB(255, 205, 160)
local SHIRT = Color3.fromRGB(90, 110, 160)
local PANTS = Color3.fromRGB(60, 60, 80)

-- A blocky R6-shaped stand-in avatar (the same part names as a real R6 character).
local function standIn(clothes: boolean): Model
	local m = Instance.new("Model")
	m.Name = "SkinPreview"
	local function limb(name: string, size: Vector3, at: Vector3, c: Color3): Part
		return part(m, { Name = name, Size = size, CFrame = CFrame.new(at), Color = c })
	end
	local torso =
		limb("Torso", Vector3.new(2, 2, 1), Vector3.zero, if clothes then SHIRT else SKIN_TONE)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		limb(prefix .. " Arm", Vector3.new(1, 2, 1), Vector3.new(side * 1.5, 0, 0), SKIN_TONE)
		limb(
			prefix .. " Leg",
			Vector3.new(1, 2, 1),
			Vector3.new(side * 0.5, -2, 0),
			if clothes then PANTS else SKIN_TONE
		)
	end
	local head = limb("Head", Vector3.new(1.25, 1.25, 1.25), Vector3.new(0, 1.6, 0), SKIN_TONE)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = head
	m.PrimaryPart = torso
	return m
end

-- A simple smiley on the stand-in's head.
local function standInFace(m: Model, head: BasePart)
	local z = -head.Size.Z / 2 - 0.01
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Face",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.16, 0.24, 0.05),
			CFrame = head.CFrame * CFrame.new(side * 0.22, 0.12, z),
			Color = Color3.fromRGB(30, 22, 38),
		})
	end
	part(m, {
		Name = "Face",
		Size = Vector3.new(0.4, 0.07, 0.05),
		CFrame = head.CFrame * CFrame.new(0, -0.22, z),
		Color = Color3.fromRGB(30, 22, 38),
	})
end

-- Where the preview's aura bits float (around a stand-in centred on its torso).
local AURA_SPOTS = {
	Vector3.new(-2.0, 1.3, -0.4),
	Vector3.new(2.1, 0.7, -0.2),
	Vector3.new(-2.3, -0.8, 0.2),
	Vector3.new(1.9, -1.7, -0.5),
	Vector3.new(-1.5, -2.7, -0.6),
	Vector3.new(1.6, 2.2, 0.3),
	Vector3.new(-0.9, 2.8, 0.5),
	Vector3.new(2.4, -0.4, 0.4),
}

-- Particles don't show in a ViewportFrame: still pieces stand in for them.
local function auraBit(into: Model, kind: string, at: Vector3, c: Color3, i: number)
	local spin = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(i * 37))
	if kind == "Bubbles" then
		part(into, {
			Name = "AuraBit",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.3 + (i % 3) * 0.1),
			CFrame = spin,
			Color = c,
			Material = Enum.Material.Glass,
			Transparency = 0.4,
		})
	elseif kind == "Smoke" then
		part(into, {
			Name = "AuraBit",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.7 + (i % 3) * 0.2),
			CFrame = spin,
			Color = c,
			Transparency = 0.6,
		})
	elseif kind == "Snow" or kind == "Embers" then
		part(into, {
			Name = "AuraBit",
			Size = Vector3.one * (0.16 + (i % 2) * 0.06),
			CFrame = spin * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = c,
			Material = Enum.Material.Neon,
		})
	elseif kind == "Hearts" then
		for _, side in { -1, 1 } do
			part(into, {
				Name = "AuraBit",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.2, 0.2, 0.06),
				CFrame = CFrame.new(at + Vector3.new(side * 0.07, 0.05, 0)),
				Color = c,
				Material = Enum.Material.Neon,
			})
		end
		part(into, {
			Name = "AuraBit",
			Size = Vector3.new(0.2, 0.2, 0.06),
			CFrame = CFrame.new(at + Vector3.new(0, -0.04, 0)) * CFrame.Angles(0, 0, math.rad(45)),
			Color = c,
			Material = Enum.Material.Neon,
		})
	else -- Sparkles, Stars
		local s = if kind == "Stars" then 0.5 else 0.36
		for _, size in { Vector3.new(s * 0.3, s, 0.05), Vector3.new(s, s * 0.3, 0.05) } do
			part(into, {
				Name = "AuraBit",
				Size = size,
				CFrame = spin,
				Color = c,
				Material = Enum.Material.Neon,
			})
		end
	end
end

-- Glow, aura and orbiting pieces for the preview (lights and particles don't draw in a
-- ViewportFrame).
local function previewExtras(into: Model, style: any, rainbowOn: boolean)
	local glow = if type(style.Glow) == "table" then style.Glow else nil
	local aura = if type(style.Aura) == "table" then style.Aura else nil
	local crazy = if type(style.Crazy) == "table" then style.Crazy else nil
	if glow then
		local c = if typeof(glow.Color) == "Color3" then glow.Color else Color3.new(1, 1, 1)
		for i, d in { 5.6, 3.9 } do
			part(into, {
				Name = "GlowHalo",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, d, d),
				CFrame = CFrame.new(0, -0.3, 0.9 + i * 0.05) * CFrame.Angles(0, math.rad(90), 0),
				Color = c,
				Material = Enum.Material.Neon,
				Transparency = if i == 1 then 0.85 else 0.72,
			})
		end
	end
	if aura then
		local c1 = if typeof(aura.Color) == "Color3" then aura.Color else Color3.new(1, 1, 1)
		local c2 = if typeof(aura.Color2) == "Color3" then aura.Color2 else c1
		local kind = if type(aura.Kind) == "string" then aura.Kind else "Sparkles"
		for i, at in AURA_SPOTS do
			local c = if rainbowOn
				then Color3.fromHSV(i / #AURA_SPOTS, 0.7, 1)
				else c1:Lerp(c2, (i - 1) / (#AURA_SPOTS - 1))
			auraBit(into, kind, at, c, i)
		end
	end
	if crazy and type(crazy.Orbit) == "string" then
		local fx = Config.Skins.Effects
		local count = if type(crazy.Count) == "number" then crazy.Count else 3
		local tint = if typeof(crazy.OrbitColor) == "Color3" then crazy.OrbitColor else nil
		for i = 1, count do
			local a = math.pi * 0.8 + (i - 1) / count * math.pi * 2
			local piece = HeadPieces.Orbit(crazy.Orbit, tint, fx.OrbitScale)
			piece:PivotTo(
				CFrame.new(
					math.cos(a) * fx.OrbitRadius,
					fx.OrbitHeight + math.sin(i * 2) * 0.4,
					math.sin(a) * fx.OrbitRadius
				) * CFrame.Angles(0, -a, 0)
			)
			piece.Parent = into
		end
	end
end

-- A stand-in avatar wearing the skin, for the shop and crate previews.
local function skinPreview(item: any): Model
	local style = item.Style
	local m = standIn(not style.HideClothes)
	paintBody(m, style, false)
	local head = m:FindFirstChild("Head") :: BasePart
	if style.Head or CustomAssets.Has("Cosmetics", item.Id) then
		head.Transparency = 1
		local piece = Cosmetics.Build(item)
		piece:PivotTo(head.CFrame)
		piece.Parent = m
	else
		standInFace(m, head)
	end
	local extras = Instance.new("Model")
	extras.Name = "Extras"
	extras.Parent = m
	local ctx = newDress(m, extras, style, false)
	addAccents(ctx, style)
	previewExtras(extras, style, ctx.Rainbow)
	return m
end

-- Placeholder for an item whose look is missing (Kind "Custom" without its model yet).
function builders.Missing(m: Model, _style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(0, 0.6, 0),
		Color = Color3.fromRGB(255, 0, 200),
		Material = Enum.Material.Neon,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "?"
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = handle
	return handle
end

-- Public --------------------------------------------------------------------------------------

-- Where a custom model's design origin is, per slot (see the top of this file).
local CUSTOM_ANCHOR = { Hat = "Bottom", Pet = "Center", Skin = "Center", Trail = "Center" }

local function buildCustom(item: any, m: Model): Model
	m.Name = "Cosmetic_" .. item.Slot
	m:SetAttribute("ItemId", item.Id)
	CustomAssets.Fit(m, Config.Custom.CosmeticSize[item.Slot], true)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = false
		end
	end
	local found = m.PrimaryPart or CustomAssets.BiggestPart(m)
	local handle: BasePart
	if found then
		handle = found
	else
		warn("[Cosmetics] custom model " .. item.Id .. " has no parts; showing a placeholder")
		m:ClearAllChildren()
		handle = builders.Missing(m, item.Style)
	end
	m.PrimaryPart = handle
	local origin = CustomAssets.Origin(m, CUSTOM_ANCHOR[item.Slot] or "Center")
	handle.PivotOffset = handle.CFrame:ToObjectSpace(origin)
	-- Put the design origin at the world origin, like the Part-built ones.
	m:PivotTo(CFrame.identity)
	handle.PivotOffset = handle.CFrame:Inverse()
	return m
end

function Cosmetics.Build(item: any): Model
	local custom = CustomAssets.Clone("Cosmetics", item.Id)
	if custom then
		return buildCustom(item, custom)
	end
	local m = Instance.new("Model")
	m.Name = "Cosmetic_" .. item.Slot
	m:SetAttribute("ItemId", item.Id)
	local build = builders[item.Style.Kind]
	if not build then
		if item.Style.Kind ~= "Custom" then
			warn(
				"[Cosmetics] no builder for " .. tostring(item.Style.Kind) .. " (" .. item.Id .. ")"
			)
		end
		build = builders.Missing
	end
	local handle = build(m, item.Style)
	m.PrimaryPart = handle
	-- Pivot at the design origin (top of the head for hats), not at the handle's centre.
	handle.PivotOffset = handle.CFrame:Inverse()
	return m
end

function Cosmetics.Preview(item: any): Model
	if item.Slot == "Skin" then
		return skinPreview(item)
	end
	if item.Slot ~= "Trail" then
		return Cosmetics.Build(item)
	end
	-- A curved ribbon fading from Color to Color2.
	local m = Instance.new("Model")
	m.Name = "TrailPreview"
	local steps = 6
	for i = 0, steps - 1 do
		local t = i / (steps - 1)
		local p = part(m, {
			Name = "Ribbon",
			Size = Vector3.new(0.7, 1.4 * (1 - t * 0.6), 0.1),
			CFrame = CFrame.new(-1.8 + i * 0.7, math.sin(t * math.pi) * 0.6, 0),
			Color = item.Style.Color:Lerp(item.Style.Color2, t),
			Material = Enum.Material.Neon,
			Transparency = t * 0.6,
		})
		if i == 0 then
			m.PrimaryPart = p
		end
	end
	return m
end

local function weldAll(m: Model, to: BasePart)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
		end
	end
end

local STASH = "SkinStash"

remember = function(instance: Instance, property: string, value: any)
	local key = "Skin_" .. property
	if instance:GetAttribute(key) == nil then
		instance:SetAttribute(key, value)
	end
end

-- Puts back everything a skin changed.
local function restoreSkin(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local color = d:GetAttribute("Skin_Color")
			local material = d:GetAttribute("Skin_Material")
			local transparency = d:GetAttribute("Skin_Transparency")
			if d:IsA("BasePart") then
				if typeof(color) == "Color3" then
					d.Color = color
				end
				if typeof(material) == "string" then
					local ok, value = pcall(function()
						return (Enum.Material :: any)[material]
					end)
					if ok and value then
						d.Material = value
					end
				end
			end
			if typeof(transparency) == "number" then
				(d :: any).Transparency = transparency
			end
			d:SetAttribute("Skin_Color", nil)
			d:SetAttribute("Skin_Material", nil)
			d:SetAttribute("Skin_Transparency", nil)
		end
	end
	local stash = character:FindFirstChild(STASH)
	if stash then
		for _, child in stash:GetChildren() do
			child.Parent = character
		end
		stash:Destroy()
	end
	character:SetAttribute("HatLift", nil)
end

local function stashIn(character: Model): Folder
	local stash = character:FindFirstChild(STASH)
	if stash and stash:IsA("Folder") then
		return stash
	end
	local folder = Instance.new("Folder")
	folder.Name = STASH
	folder.Parent = character
	return folder
end

-- Accessories (hair, hats from the avatar) attached to the head.
local function headAccessories(character: Model, head: BasePart): { BasePart }
	local list = {}
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				for _, j in handle:GetChildren() do
					if j:IsA("JointInstance") and (j.Part0 == head or j.Part1 == head) then
						table.insert(list, handle)
						break
					end
				end
			end
		end
	end
	return list
end

local function wearSkin(character: Model, item: any, head: BasePart, root: BasePart): boolean
	local style = item.Style
	if paintBody(character, style, true) then
		-- BodyColors would paint the avatar's own colours back.
		for _, child in character:GetChildren() do
			if child:IsA("BodyColors") then
				child.Parent = stashIn(character)
			end
		end
	end
	if style.HideClothes then
		for _, child in character:GetChildren() do
			if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
				(child :: Instance).Parent = stashIn(character)
			elseif child:IsA("Accessory") then
				-- 3D (layered) clothes: jackets, shirts and shoes that wrap the body
				local handle = child:FindFirstChild("Handle")
				if
					handle
					and handle:IsA("BasePart")
					and handle:FindFirstChildOfClass("WrapLayer")
				then
					remember(handle, "Transparency", handle.Transparency)
					handle.Transparency = 1
				end
			end
		end
	end
	if not hasExtras(item) then
		return true
	end
	local m: Model
	if style.Head or CustomAssets.Has("Cosmetics", item.Id) then
		remember(head, "Transparency", head.Transparency)
		head.Transparency = 1
		for _, d in head:GetChildren() do
			if d:IsA("Decal") then
				remember(d, "Transparency", d.Transparency)
				d.Transparency = 1
			end
		end
		for _, handle in headAccessories(character, head) do
			remember(handle, "Transparency", handle.Transparency)
			handle.Transparency = 1
		end
		m = Cosmetics.Build(item)
		m:PivotTo(head.CFrame)
		weldAll(m, head)
		-- Hats go on top of the head piece.
		local box, size = m:GetBoundingBox()
		local lift = (box.Position.Y + size.Y / 2) - (head.Position.Y + head.Size.Y / 2)
		character:SetAttribute("HatLift", math.max(0, lift))
	else
		m = Instance.new("Model")
		m.Name = "Cosmetic_Skin"
		m:SetAttribute("ItemId", item.Id)
	end
	-- Accents, glow and aura go in the same model, so TakeOff removes them with it.
	local ctx = newDress(character, m, style, true)
	addAccents(ctx, style)
	addGlowAndAura(ctx, root, style)
	m.Parent = character
	if type(style.Crazy) == "table" then
		-- src/client/SkinFx.luau animates it on every player's screen.
		CollectionService:AddTag(m, Tags.SkinFx)
	end
	return true
end

function Cosmetics.TakeOff(character: Model, slot: string)
	if slot == "Skin" then
		restoreSkin(character)
	end
	for _, child in character:GetChildren() do
		if child.Name == "Cosmetic_" .. slot then
			child:Destroy()
		end
	end
	if slot == "Trail" then
		local root = character:FindFirstChild("HumanoidRootPart")
		for _, name in { "CosmeticTrail", "CosmeticTrail0", "CosmeticTrail1" } do
			local old = root and root:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end
end

-- Puts `item` on `character` (server). Returns false if the character isn't ready.
function Cosmetics.Wear(character: Model, item: any): boolean
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return false
	end
	Cosmetics.TakeOff(character, item.Slot)
	if item.Slot == "Skin" then
		return wearSkin(character, item, head, root)
	end
	if item.Slot == "Trail" then
		local a0 = Instance.new("Attachment")
		a0.Name = "CosmeticTrail0"
		a0.Position = Vector3.new(0, 0.9, 0.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "CosmeticTrail1"
		a1.Position = Vector3.new(0, -0.9, 0.4)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "CosmeticTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(item.Style.Color, item.Style.Color2)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 0.6
		trail.Lifetime = Config.Shop.TrailLifetime
		trail.FaceCamera = true
		trail.Parent = root
		return true
	end
	local m = Cosmetics.Build(item)
	if item.Slot == "Hat" then
		local lift = character:GetAttribute("HatLift")
		local extra = if typeof(lift) == "number" then lift else 0
		m:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + extra, 0))
		weldAll(m, head)
	else
		m:PivotTo(root.CFrame * CFrame.new(Config.Shop.PetOffset))
		weldAll(m, root)
	end
	m.Parent = character
	return true
end

return Cosmetics
