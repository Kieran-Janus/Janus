--!strict
--[[
	Shop cosmetics built from Parts, from each Config.Shop.Items[i].Style.
	Shared so the server can dress characters and the client can draw shop previews with
	exactly the same models.

	Cosmetics.Find(id) -> item?
	Cosmetics.Build(item) -> Model         hats and pets (anchored, PrimaryPart = Handle)
	Cosmetics.Preview(item) -> Model       anything, for a ViewportFrame (trails as a ribbon)
	Cosmetics.Wear(character, item)        server: put it on (replaces that slot)
	Cosmetics.TakeOff(character, slot)

	Hats are built with y = 0 at the top of the head; pets around their own centre; skin head
	pieces around the centre of the head.

	Custom art: a Model (or Accessory) named after the item Id in
	ReplicatedStorage.Custom.Cosmetics replaces the Part-built look (src/shared/CustomAssets).
	A new item can use Style = { Kind = "Custom" } and only a custom model.

	Skins (Slot "Skin") recolour the avatar, can hide clothes and add a head piece. Everything
	they change is remembered in attributes ("Skin_*") and put back by TakeOff.
]]

local Config = require(script.Parent.Config)
local CustomAssets = require(script.Parent.CustomAssets)

local Cosmetics = {}

function Cosmetics.Find(id: unknown): any
	if typeof(id) ~= "string" then
		return nil
	end
	for _, item in Config.Shop.Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

local function part(m: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	-- Ball parts are forced round; squashed balls use a sphere mesh on a block instead.
	local size: Vector3 = props.Size or p.Size -- p.Size may already be forced round
	if p.Shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
		p.Shape = Enum.PartType.Block
		p.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = m
	return p
end

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

-- Pets ----------------------------------------------------------------------------------------

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

-- Skin head pieces (built around the centre of the head) -------------------------------------

local function carvedFace(m: Model, glow: Color3, z: number, scale: number)
	for _, side in { -1, 1 } do
		part(m, {
			Name = "Eye",
			Size = Vector3.new(0.45, 0.4, 0.08) * scale,
			CFrame = CFrame.new(side * 0.42 * scale, 0.25 * scale, z)
				* CFrame.Angles(0, 0, math.rad(side * 12)),
			Color = glow,
			Material = Enum.Material.Neon,
		})
	end
	part(m, {
		Name = "Mouth",
		Size = Vector3.new(1.1, 0.28, 0.08) * scale,
		CFrame = CFrame.new(0, -0.35 * scale, z),
		Color = glow,
		Material = Enum.Material.Neon,
	})
end

function builders.SkinPumpkin(m: Model, style: any): BasePart
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.5, 2.1, 2.5),
		Color = style.HeadColor or Color3.fromRGB(255, 130, 20),
	})
	part(m, {
		Name = "Stem",
		Size = Vector3.new(0.3, 0.5, 0.3),
		CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(10)),
		Color = Color3.fromRGB(90, 160, 60),
	})
	carvedFace(m, style.GlowColor or Color3.fromRGB(255, 220, 90), -1.2, 1)
	return handle
end

function builders.SkinSkull(m: Model, style: any): BasePart
	local bone = style.HeadColor or Color3.fromRGB(235, 228, 210)
	local handle = part(m, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.7, 1.6, 1.7),
		CFrame = CFrame.new(0, 0.1, 0),
		Color = bone,
	})
	part(m, {
		Name = "Jaw",
		Size = Vector3.new(1, 0.4, 0.9),
		CFrame = CFrame.new(0, -0.65, -0.25),
		Color = bone,
	})
	eyes(m, 0.2, -0.72, 0.32, 0.42, Color3.fromRGB(20, 20, 25))
	eyes(m, 0.2, -0.8, 0.32, 0.14, style.GlowColor or Color3.fromRGB(120, 255, 110))
	return handle
end

function builders.SkinKing(m: Model, style: any): BasePart
	local handle = builders.SkinPumpkin(m, style)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(m, {
			Name = "CrownSpike",
			Size = Vector3.new(0.3, 0.6, 0.3),
			CFrame = CFrame.new(math.cos(a) * 0.55, 1.35, math.sin(a) * 0.55)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = style.GlowColor or Color3.fromRGB(255, 210, 60),
			Material = Enum.Material.Neon,
		})
	end
	return handle
end

-- A skin's model is its head piece (or an invisible handle when it only recolours).
function builders.Skin(m: Model, style: any): BasePart
	local head = style.Head and builders[style.Head]
	if head then
		return head(m, style)
	end
	return part(m, { Name = "Handle", Size = Vector3.one * 0.2, Transparency = 1 })
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
	local handle = m.PrimaryPart or CustomAssets.BiggestPart(m)
	assert(handle, "custom cosmetic " .. item.Id .. " has no parts")
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

-- A blocky stand-in avatar wearing a skin, for the shop preview.
local function skinPreview(item: any): Model
	local style = item.Style
	local skin = style.BodyColor or Color3.fromRGB(255, 205, 160)
	local shirt = if style.HideClothes or not style.BodyColor
		then skin
		else Color3.fromRGB(90, 110, 160)
	local pants = if style.HideClothes or not style.BodyColor
		then skin
		else Color3.fromRGB(60, 60, 80)
	local m = Instance.new("Model")
	m.Name = "SkinPreview"
	local look = {
		Material = style.Material or Enum.Material.SmoothPlastic,
		Transparency = style.Transparency or 0,
	}
	local function limb(name: string, size: Vector3, at: Vector3, color: Color3): Part
		return part(m, {
			Name = name,
			Size = size,
			CFrame = CFrame.new(at),
			Color = color,
			Material = look.Material,
			Transparency = look.Transparency,
		})
	end
	local torso = limb("Torso", Vector3.new(2, 2, 1), Vector3.zero, shirt)
	for _, side in { -1, 1 } do
		limb("Arm", Vector3.new(1, 2, 1), Vector3.new(side * 1.5, 0, 0), skin)
		limb("Leg", Vector3.new(1, 2, 1), Vector3.new(side * 0.5, -2, 0), pants)
	end
	local headCentre = Vector3.new(0, 1.6, 0)
	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), headCentre, skin)
	if style.Head or CustomAssets.Has("Cosmetics", item.Id) then
		head.Transparency = 1
		local piece = Cosmetics.Build(item)
		piece:PivotTo(CFrame.new(headCentre))
		piece.Parent = m
	end
	m.PrimaryPart = torso
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

local function remember(instance: Instance, property: string, value: any)
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

local function wearSkin(character: Model, item: any, head: BasePart): boolean
	local style = item.Style
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			if style.BodyColor then
				remember(child, "Color", child.Color)
				child.Color = style.BodyColor
			end
			if style.Material then
				remember(child, "Material", child.Material.Name)
				child.Material = style.Material
			end
			if style.Transparency then
				remember(child, "Transparency", child.Transparency)
				child.Transparency = math.max(child.Transparency, style.Transparency)
			end
		end
	end
	if style.BodyColor then
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
			end
		end
	end
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
		local m = Cosmetics.Build(item)
		m:PivotTo(head.CFrame)
		weldAll(m, head)
		m.Parent = character
		-- Hats go on top of the head piece.
		local box, size = m:GetBoundingBox()
		local lift = (box.Position.Y + size.Y / 2) - (head.Position.Y + head.Size.Y / 2)
		character:SetAttribute("HatLift", math.max(0, lift))
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
		return wearSkin(character, item, head)
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
