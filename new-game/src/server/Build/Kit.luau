--!strict
--[[
	Part-kitbashing helpers shared by the hub builder and the map builders.
	Everything here is placeholder art built from Parts; colours are always passed in so
	each place keeps its own palette from Config.

	Colour roles: props tables may contain PaletteRole = "Wood" (and PaletteShade = 0.3 for
	30% darker, -0.2 for 20% lighter). They become attributes on the part, so the colour can be
	re-applied later from the palette (src/server/Hub/HubPalette.luau). Kit.painter(palette)
	gives part/decor/wedge helpers that also fill in Color from the role.

	Props: Kit.prop(name, cframe, parent, size?, build) swaps a decoration for a model in
	ReplicatedStorage.Custom.Props with the same name (every copy at once), else builds it.

	Shapes: Roblox always draws a Ball part as a perfect sphere (its smallest side wins), so
	Kit.part turns a Ball with unequal sides into a Block with a SpecialMesh "Oval" (MeshType
	Sphere), which stretches to the part's size: real ovals for pumpkins, eggs, mounds and
	flames. (A mesh doesn't change how the part collides: it bumps like its box.)
	Kit.rounded makes a rounded cylinder (SpecialMesh Head) for posts, drums and pads.

	Small decorations cast no shadow (cheaper on phones): see SMALL_DECOR below.

	Client animation hooks (src/client/HubAmbience.luau), used by the hub and the maps:
	  tag "HubFloat"   on Models that bob (attributes BobHeight, Phase)
	  tag "HubFlicker" on PointLights that flicker
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)

local Kit = {}

export type Props = { [string]: any }
export type ColorPalette = { [string]: Color3 }

-- `color` made darker (amount > 0, 1 = black) or lighter (amount < 0, -1 = white).
function Kit.shade(color: Color3, amount: number?): Color3
	local a = amount or 0
	if a > 0 then
		return color:Lerp(Color3.new(0, 0, 0), math.min(a, 1))
	elseif a < 0 then
		return color:Lerp(Color3.new(1, 1, 1), math.min(-a, 1))
	end
	return color
end

-- The colour for a role in `palette` (with its shade), or nil for an unknown role.
function Kit.roleColor(palette: ColorPalette, role: string, shade: number?): Color3?
	local base = palette[role]
	return if base then Kit.shade(base, shade) else nil
end

-- Marks `instance` (a part or light, or every part/light inside a model) with a colour role.
function Kit.setRole(instance: Instance, role: string, shade: number?)
	local function mark(d: Instance)
		if d:IsA("BasePart") or d:IsA("Light") then
			d:SetAttribute("PaletteRole", role)
			d:SetAttribute("PaletteShade", if shade and shade ~= 0 then shade else nil)
		end
	end
	mark(instance)
	for _, d in instance:GetDescendants() do
		mark(d)
	end
end

local function apply(instance: Instance, props: Props, palette: ColorPalette?)
	for key, value in props do
		if key == "PaletteRole" or key == "PaletteShade" then
			instance:SetAttribute(key, value)
		else
			(instance :: any)[key] = value
		end
	end
	local role = props.PaletteRole
	if palette and type(role) == "string" and props.Color == nil then
		local color = Kit.roleColor(palette, role, props.PaletteShade)
		if color then
			local target: any = instance
			target.Color = color
		end
	end
end

-- Decorations no bigger than this (studs, longest side) cast no shadow: you never notice
-- their shadows, and every shadow caster costs a little on phones.
local SMALL_DECOR = 4

-- True for a Size Roblox can't draw as a Ball (its sides are not all the same).
function Kit.isOval(size: any): boolean
	if typeof(size) ~= "Vector3" then
		return false
	end
	return math.abs(size.X - size.Y) > 1e-3 or math.abs(size.Y - size.Z) > 1e-3
end

-- Gives `p` a SpecialMesh that fills its box (MeshType Sphere = oval, Head = rounded cylinder
-- standing along Y, Cylinder = cylinder along X). Returns the mesh.
function Kit.mesh(p: BasePart, meshType: Enum.MeshType, name: string?): SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = name or "Shape"
	mesh.MeshType = meshType
	mesh.Parent = p
	return mesh
end

function Kit.part(props: Props, parent: Instance, palette: ColorPalette?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	-- A Ball with unequal sides would be drawn as a plain sphere: make it a real oval.
	local oval = props.Shape == Enum.PartType.Ball and Kit.isOval(props.Size)
	if oval then
		local copy = table.clone(props)
		copy.Shape = Enum.PartType.Block
		apply(p, copy, palette)
		Kit.mesh(p, Enum.MeshType.Sphere, "Oval")
	else
		apply(p, props, palette)
	end
	p.Parent = parent
	return p
end

--[[
	A rounded cylinder standing up (SpecialMesh Head): Size = (diameter, height, diameter).
	Chunky, toy-like posts, drums, stones and pads. Collides like its box.
]]
function Kit.rounded(props: Props, parent: Instance, palette: ColorPalette?): Part
	local p = Kit.part(props, parent, palette)
	Kit.mesh(p, Enum.MeshType.Head, "Rounded")
	return p
end

function Kit.wedge(props: Props, parent: Instance, palette: ColorPalette?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	apply(w, props, palette)
	w.Parent = parent
	return w
end

function Kit.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Upright cylinder (Roblox cylinders point along X, so rotate onto Y).
function Kit.upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- A decoration: no collision, never hit by raycasts (King sight, pumpkin spawns), no touch.
function Kit.decor(props: Props, parent: Instance, palette: ColorPalette?): Part
	local p = Kit.part(props, parent, palette)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	Kit.noShadowIfSmall(p)
	return p
end

-- Small, glowing or see-through parts cast no shadow.
function Kit.noShadowIfSmall(p: BasePart)
	local size = p.Size
	if
		math.max(size.X, size.Y, size.Z) <= SMALL_DECOR
		or p.Material == Enum.Material.Neon
		or p.Transparency >= 0.5
	then
		p.CastShadow = false
	end
end

-- A rounded cylinder (Kit.rounded) that is only for looks.
function Kit.roundedDecor(props: Props, parent: Instance, palette: ColorPalette?): Part
	local p = Kit.decor(props, parent, palette)
	Kit.mesh(p, Enum.MeshType.Head, "Rounded")
	return p
end

export type Painter = {
	part: (props: Props, parent: Instance) -> Part,
	decor: (props: Props, parent: Instance) -> Part,
	wedge: (props: Props, parent: Instance) -> WedgePart,
	rounded: (props: Props, parent: Instance) -> Part,
	roundedDecor: (props: Props, parent: Instance) -> Part,
	color: (role: string, shade: number?) -> Color3,
	palette: ColorPalette,
}

-- part/decor/wedge that colour themselves from `palette` by PaletteRole.
function Kit.painter(palette: ColorPalette): Painter
	return {
		part = function(props: Props, parent: Instance): Part
			return Kit.part(props, parent, palette)
		end,
		decor = function(props: Props, parent: Instance): Part
			return Kit.decor(props, parent, palette)
		end,
		wedge = function(props: Props, parent: Instance): WedgePart
			return Kit.wedge(props, parent, palette)
		end,
		rounded = function(props: Props, parent: Instance): Part
			return Kit.rounded(props, parent, palette)
		end,
		roundedDecor = function(props: Props, parent: Instance): Part
			return Kit.roundedDecor(props, parent, palette)
		end,
		color = function(role: string, shade: number?): Color3
			return Kit.roleColor(palette, role, shade) or Color3.new(1, 0, 1)
		end,
		palette = palette,
	}
end

export type PropOptions = {
	Anchor: string?, -- "Feet" (default: stands on cframe) or "Center" (middle at cframe)
}

-- Moves a model's pivot (what Studio's move/rotate tools hold) to `cframe` without moving it.
local function setPivot(m: Model, cframe: CFrame)
	local primary = m.PrimaryPart
	if primary then
		primary.PivotOffset = primary.CFrame:ToObjectSpace(cframe)
	else
		m.WorldPivot = cframe
	end
end

--[[
	A decoration that can be swapped for your own model. If ReplicatedStorage.Custom.Props has
	a model called `name`, a copy of it is used: scaled to `size` studs tall (if given, and the
	model has no KeepSize attribute), stood on `cframe` facing the same way (turned left/right
	only), anchored, scripts removed. Otherwise build() makes the Part-built version (it must
	put its model at `cframe`). Either way the model gets the attribute PropName = name, so in
	Studio you can see what to call your own version, and its pivot is `cframe`.
	options.Anchor = "Center" instead puts the model's middle at cframe with cframe's full
	turn (flat things hung on walls, like cobwebs).
	Built props remember their size and anchor (attributes PropSize, PropAnchor) so
	Kit.applyCustomProps can swap them later, e.g. in a hub saved in the place file.
]]
function Kit.prop(
	name: string,
	cframe: CFrame,
	parent: Instance,
	size: number?,
	build: () -> Model,
	options: PropOptions?
): Model
	local anchor = if options and options.Anchor == "Center" then "Center" else nil
	local custom = CustomAssets.Clone("Props", name)
	if custom then
		CustomAssets.Fit(custom, size)
		for _, d in custom:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		if anchor == "Center" then
			CustomAssets.PlaceCenter(custom, cframe)
		else
			CustomAssets.PlaceFeet(custom, cframe)
		end
		custom.Name = name
		custom:SetAttribute("CustomProp", true)
	end
	local m = custom or build()
	m:SetAttribute("PropName", name)
	m:SetAttribute("PropSize", size)
	m:SetAttribute("PropAnchor", anchor)
	-- Built or custom, the pivot is the spot it was placed on (other code relies on this, e.g.
	-- the shopkeeper stands relative to the stall's pivot).
	setPivot(m, cframe)
	if m.Parent == nil then
		m.Parent = parent
	end
	return m
end

--[[
	Swaps every built prop under `root` (a Model with a PropName attribute) for the custom
	model of that name in ReplicatedStorage.Custom.Props, when there is one. It goes where the
	built one's pivot is now, so props moved by hand in Studio keep their new spot. Tags and
	the bobbing attributes are carried over. Returns how many were swapped.
]]
function Kit.applyCustomProps(root: Instance): number
	-- Built props that have a custom version, outermost first: a prop inside one that is
	-- swapped (a lantern on a custom stall) goes with it.
	local wanted: { [Instance]: boolean } = {}
	local list: { Model } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("CustomProp") ~= true then
			local name = d:GetAttribute("PropName")
			if typeof(name) == "string" and CustomAssets.Has("Props", name) then
				wanted[d] = true
				table.insert(list, d)
			end
		end
	end
	local swapped = 0
	for _, d in list do
		local ancestor = d.Parent
		local inside = false
		while ancestor and ancestor ~= root do
			if wanted[ancestor] then
				inside = true
				break
			end
			ancestor = ancestor.Parent
		end
		local parent = d.Parent
		if inside or not parent then
			continue
		end
		local name = d:GetAttribute("PropName") :: string
		local size = d:GetAttribute("PropSize")
		local custom = Kit.prop(
			name,
			d:GetPivot(),
			parent,
			if typeof(size) == "number" then size else nil,
			function()
				return d
			end,
			{ Anchor = if d:GetAttribute("PropAnchor") == "Center" then "Center" else nil }
		)
		if custom == d then
			continue
		end
		for _, tag in CollectionService:GetTags(d) do
			CollectionService:AddTag(custom, tag)
		end
		for _, key in { "BobHeight", "Phase" } do
			custom:SetAttribute(key, d:GetAttribute(key))
		end
		d:Destroy()
		swapped += 1
	end
	return swapped
end

-- A floating name above `adornee` (height studs up), hidden beyond maxDistance studs.
function Kit.nameTag(
	text: string,
	adornee: BasePart,
	height: number,
	color: Color3,
	maxDistance: number
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

-- Spooky lettering painted on one face of `target`.
function Kit.surfaceText(
	target: BasePart,
	text: string,
	color: Color3,
	face: Enum.NormalId?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = target
	return gui
end

-- An invisible, non-colliding part used to hold lights, particles and prompts.
function Kit.holder(name: string, cf: CFrame, size: Vector3, parent: Instance): Part
	return Kit.decor({ Name = name, CFrame = cf, Size = size, Transparency = 1 }, parent)
end

function Kit.light(
	parent: BasePart,
	color: Color3,
	range: number,
	brightness: number,
	flicker: boolean
): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(l, "HubFlicker")
	end
	return l
end

function Kit.particles(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

function Kit.float(m: Model, bob: number, rng: Random)
	m:SetAttribute("BobHeight", bob)
	m:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	CollectionService:AddTag(m, "HubFloat")
end

-- Ovals and ribbed pumpkins -------------------------------------------------------------------

-- One oval making up a body: where it sits (relative to the body's centre) and half its size.
export type Oval = { CFrame: CFrame, Semi: Vector3 }

-- The far point where a ray from `o` along `d` leaves the oval (in the oval's own space).
local function exitDistance(o: Vector3, d: Vector3, semi: Vector3): number?
	local ox, oy, oz = o.X / semi.X, o.Y / semi.Y, o.Z / semi.Z
	local dx, dy, dz = d.X / semi.X, d.Y / semi.Y, d.Z / semi.Z
	local a = dx * dx + dy * dy + dz * dz
	local b = 2 * (ox * dx + oy * dy + oz * dz)
	local c = ox * ox + oy * oy + oz * oz - 1
	local disc = b * b - 4 * a * c
	if a <= 0 or disc < 0 then
		return nil
	end
	return (-b + math.sqrt(disc)) / (2 * a)
end

--[[
	How far in front of the body's centre its surface is at (x, y) on the face (front = -Z):
	the frontmost of `ovals`. Used to stick carved faces onto round and ribbed bodies.
]]
function Kit.frontDepth(ovals: { Oval }, x: number, y: number): number
	local best = 0
	local forward = Vector3.new(0, 0, -1)
	for _, oval in ovals do
		local o = oval.CFrame:PointToObjectSpace(Vector3.new(x, y, 0))
		local d = oval.CFrame:VectorToObjectSpace(forward)
		local t = exitDistance(o, d, oval.Semi)
		if t and t > best then
			best = t
		end
	end
	return best
end

--[[
	A ribbed pumpkin body centred on `cf`: an oval core plus `ribs` long ovals turned around the
	middle (each makes two bulges, so 3 ribs = 6 bulges, 4 = 8). size = (width, height, width).
	The core (named "Pumpkin") gets `props` (Color or PaletteRole, CanCollide...) and is a shade
	darker so the grooves look deep; the ribs are only for looks. Returns the core and the
	ovals (for Kit.frontDepth / Kit.carvedFace).
]]
function Kit.pumpkinBody(
	cf: CFrame,
	size: Vector3,
	ribs: number,
	props: Props,
	parent: Instance,
	palette: ColorPalette?
): (Part, { Oval })
	local coreSize = Vector3.new(size.X * 0.84, size.Y * 0.97, size.Z * 0.84)
	local baseShade = if typeof(props.PaletteShade) == "number" then props.PaletteShade else 0
	local coreProps = table.clone(props)
	coreProps.Name = "Pumpkin"
	coreProps.Shape = Enum.PartType.Ball
	coreProps.Size = coreSize
	coreProps.CFrame = cf
	coreProps.PaletteShade = baseShade + 0.12
	if typeof(props.Color) == "Color3" then
		coreProps.Color = Kit.shade(props.Color, 0.12)
	end
	local core = Kit.part(coreProps, parent, palette)
	if not core.CanCollide then
		Kit.noShadowIfSmall(core)
	end
	local ovals: { Oval } = { { CFrame = CFrame.identity, Semi = coreSize / 2 } }
	local count = math.max(ribs, 0)
	for i = 0, count - 1 do
		local turn = CFrame.Angles(0, i * math.pi / count, 0)
		local ribSize = Vector3.new(size.X * 0.56, size.Y, size.Z)
		local shade = baseShade + (if i % 2 == 0 then 0 else 0.05)
		Kit.decor({
			Name = "Rib",
			Shape = Enum.PartType.Ball,
			Size = ribSize,
			CFrame = cf * turn,
			Material = props.Material or Enum.Material.SmoothPlastic,
			Color = if typeof(props.Color) == "Color3"
				then Kit.shade(props.Color, shade - baseShade)
				else nil,
			PaletteRole = props.PaletteRole,
			PaletteShade = shade,
		}, parent, palette)
		table.insert(ovals, { CFrame = turn, Semi = ribSize / 2 })
	end
	return core, ovals
end

export type FaceOptions = {
	Ovals: { Oval }?, -- the body's shape (default: one oval of `size`)
	Detail: string?, -- "Full" (eyes, nose, grin) or "Simple" (eyes and a mouth)
}

--[[
	A glowing carved face on the front (cf.LookVector) of a body centred on `cf`. `size` is the
	body's diameter (a number) or its oval size (width, height, depth). Every piece sits on the
	surface, turned to follow its curve.
]]
function Kit.carvedFace(
	cf: CFrame,
	size: number | Vector3,
	glow: Color3,
	parent: Instance,
	options: FaceOptions?
)
	local box: Vector3 = if typeof(size) == "Vector3" then size else Vector3.one * (size :: number)
	local semi = box / 2
	local ovals: { Oval } = if options and options.Ovals
		then options.Ovals
		else { { CFrame = CFrame.identity, Semi = semi } }
	local full = not (options and options.Detail == "Simple")
	local w, h = box.X, box.Y
	local thick = math.max(math.min(w, h) * 0.06, 0.08)
	-- A spot on the surface at (x, y), facing out of it.
	local function onSurface(x: number, y: number): CFrame
		local depth = Kit.frontDepth(ovals, x, y)
		local pos = Vector3.new(x, y, -(depth - thick * 0.3))
		local normal = Vector3.new(
			x / (semi.X * semi.X),
			y / (semi.Y * semi.Y),
			-math.max(depth, 0.01) / (semi.Z * semi.Z)
		).Unit
		return cf * CFrame.lookAt(pos, pos + normal)
	end
	local function glowing(props: Props): Props
		props.Color = glow
		props.PaletteRole = "Glow"
		props.Material = Enum.Material.Neon
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.CastShadow = false
		return props
	end
	for _, side in { -1, 1 } do
		-- Triangle eyes: a wedge turned so its triangle faces forward.
		Kit.wedge(
			glowing({
				Name = "Eye",
				Size = Vector3.new(thick, h * 0.2, w * 0.17),
				CFrame = onSurface(side * w * 0.17, h * 0.12)
					* CFrame.Angles(0, math.rad(90 * side), 0),
			}),
			parent
		)
	end
	if full then
		Kit.wedge(
			glowing({
				Name = "Nose",
				Size = Vector3.new(thick, h * 0.09, w * 0.07),
				CFrame = onSurface(0, -h * 0.02) * CFrame.Angles(0, math.rad(90), 0),
			}),
			parent
		)
		-- A grin: a middle and two ends turned up.
		Kit.part(
			glowing({
				Name = "Mouth",
				Size = Vector3.new(w * 0.2, h * 0.08, thick),
				CFrame = onSurface(0, -h * 0.2),
			}),
			parent
		)
		for _, side in { -1, 1 } do
			Kit.part(
				glowing({
					Name = "Mouth",
					Size = Vector3.new(w * 0.13, h * 0.07, thick),
					CFrame = onSurface(side * w * 0.15, -h * 0.165)
						* CFrame.Angles(0, 0, math.rad(side * 28)),
				}),
				parent
			)
		end
	else
		Kit.part(
			glowing({
				Name = "Mouth",
				Size = Vector3.new(w * 0.36, h * 0.09, thick),
				CFrame = onSurface(0, -h * 0.18),
			}),
			parent
		)
	end
end

export type Palette = { Orange: Color3, Green: Color3, Glow: Color3 }

export type LanternOptions = {
	Light: boolean?, -- a flickering PointLight inside (default true; the neon face glows anyway)
	Ribs: number?, -- 3 (6 bulges, default) or 4 (8 bulges)
	Detail: string?, -- "Full" face (default) or "Simple"
}

--[[
	A carved, glowing, ribbed pumpkin sitting on `cf` (front = cf.LookVector); `size` is its
	height. Model "JackOLantern": the core ("Pumpkin", collides, the PrimaryPart), ribs, a
	curly stem and the face.
]]
function Kit.jackOLantern(
	cf: CFrame,
	size: number,
	colors: Palette,
	parent: Instance,
	options: LanternOptions?
): Model
	local m = Kit.model("JackOLantern", parent)
	local body = Vector3.new(size * 1.22, size, size * 1.22)
	local centre = cf * CFrame.new(0, size / 2, 0)
	local ribs = if options and options.Ribs then options.Ribs else 3
	local core, ovals = Kit.pumpkinBody(centre, body, ribs, {
		Color = colors.Orange,
		PaletteRole = "Orange",
	}, m)
	Kit.decor({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size * 0.32, size * 0.16, size * 0.16),
		CFrame = Kit.upright(
			cf * CFrame.new(0, size * 1.05, 0) * CFrame.Angles(math.rad(14), 0, math.rad(10))
		),
		Color = Kit.shade(colors.Green, 0.25),
		PaletteRole = "Green",
		PaletteShade = 0.25,
	}, m)
	Kit.carvedFace(centre, body, colors.Glow, m, {
		Ovals = ovals,
		Detail = if options and options.Detail then options.Detail else "Full",
	})
	if not (options and options.Light == false) then
		Kit.light(core, colors.Glow, size * 4, 1.2, true):SetAttribute("PaletteRole", "Glow")
	end
	m.PrimaryPart = core
	return m
end

-- A flat spider web facing cf.LookVector.
function Kit.cobweb(cf: CFrame, size: number, color: Color3, parent: Instance): Model
	local m = Kit.model("Cobweb", parent)
	local spokes = 6
	local points: { { Vector3 } } = {}
	for i = 1, spokes do
		local a = (i / spokes) * math.pi * 2
		local dir = (cf.RightVector * math.cos(a) + cf.UpVector * math.sin(a))
		Kit.decor({
			Name = "Strand",
			Size = Vector3.new(0.06, 0.06, size),
			CFrame = CFrame.lookAt(cf.Position + dir * size / 2, cf.Position + dir * size),
			Color = color,
			Transparency = 0.35,
		}, m)
		points[i] = { cf.Position + dir * size * 0.45, cf.Position + dir * size * 0.85 }
	end
	for ring = 1, 2 do
		for i = 1, spokes do
			local a = points[i][ring]
			local b = points[i % spokes + 1][ring]
			Kit.decor({
				Name = "Strand",
				Size = Vector3.new(0.05, 0.05, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = color,
				Transparency = 0.35,
			}, m)
		end
	end
	return m
end

-- A bare spooky tree standing on `base`.
function Kit.deadTree(
	base: CFrame,
	height: number,
	color: Color3,
	rng: Random,
	parent: Instance
): Model
	local m = Kit.model("DeadTree", parent)
	Kit.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.2, 2.2),
		CFrame = Kit.upright(base * CFrame.new(0, height / 2, 0)),
		Color = color,
		Material = Enum.Material.Wood,
	}, m)
	for b = 1, 5 do
		local y = height * rng:NextNumber(0.45, 0.95)
		local yaw = (b / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local length = rng:NextNumber(4, 8)
		Kit.decor({
			Name = "Branch",
			Size = Vector3.new(0.6, 0.6, length),
			CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(
				math.rad(rng:NextNumber(30, 55)),
				0,
				0
			) * CFrame.new(0, 0, -length / 2),
			Color = color,
			Material = Enum.Material.Wood,
		}, m)
	end
	return m
end

--[[
	A walk-in hiding spot: players pass through it, but it blocks the King's line of sight
	(CanQuery stays on) so someone standing inside can't be seen. Tagged "HidingSpot".
]]
function Kit.hidingSpot(props: { [string]: any }, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	CollectionService:AddTag(p, "HidingSpot")
	return p
end

--[[
	Map-wide ambient particles. `kinds` maps a kind name to { Rate, Color }:
	  Fireflies, Wisps - glowing dots drifting in the air
	  Mist             - big soft puffs low over the floor
	  Leaves, Dust     - small flakes drifting down
	The area is centred on `center` (floor top) with footprint `size`.
]]
function Kit.ambientParticles(
	center: Vector3,
	size: Vector3,
	kinds: { [string]: any },
	parent: Instance
)
	local folder = Kit.model("Ambience", parent)
	for kind, cfg in kinds do
		if kind == "Fireflies" or kind == "Wisps" then
			local air = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 6, 0)),
				Vector3.new(size.X, 8, size.Z),
				folder
			)
			Kit.particles(air, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
				LightEmission = 1,
				Size = NumberSequence.new(if kind == "Wisps" then 0.6 else 0.25),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, if kind == "Wisps" then 0.4 else 0),
					NumberSequenceKeypoint.new(0.7, if kind == "Wisps" then 0.4 else 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(4, 7),
				Speed = NumberRange.new(0.3, 1.2),
				SpreadAngle = Vector2.new(180, 180),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
		elseif kind == "Mist" then
			local ground = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 1.5, 0)),
				Vector3.new(size.X, 1, size.Z),
				folder
			)
			Kit.particles(ground, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 8),
					NumberSequenceKeypoint.new(1, 14),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.4, 0.82),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(8, 12),
				Speed = NumberRange.new(0.2, 0.6),
				SpreadAngle = Vector2.new(180, 10),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
		elseif kind == "Leaves" or kind == "Dust" then
			local sky = Kit.holder(
				kind,
				CFrame.new(center + Vector3.new(0, 18, 0)),
				Vector3.new(size.X, 1, size.Z),
				folder
			)
			Kit.particles(sky, {
				Rate = cfg.Rate,
				Color = ColorSequence.new(cfg.Color),
				Size = NumberSequence.new(if kind == "Dust" then 0.15 else 0.35),
				LightEmission = if kind == "Dust" then 0.6 else 0,
				Lifetime = NumberRange.new(8, 12),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0.5, if kind == "Dust" then -0.3 else -1.2, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
				EmissionDirection = Enum.NormalId.Bottom,
				Shape = Enum.ParticleEmitterShape.Box,
			})
		end
	end
	return folder
end

return Kit
