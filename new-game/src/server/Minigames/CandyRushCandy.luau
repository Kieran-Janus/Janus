--!strict
--[[
	The candies of Candy Rush (settings: Config.Minigames.CandyRush.Candy), built from parts:
	  Wrapped    an oval sweet with a twisted wrapper on each side
	  Lollipop   a round swirly lollipop on a stick
	  CandyCorn  a yellow, orange and white candy corn
	Each is swapped for your own model when ReplicatedStorage.Custom.Props has one called
	CandyRushWrapped / CandyRushLollipop / CandyRushCandyCorn (Kit.prop).

	CandyRushCandy.Build(kind, color, cframe) -> Model
	    A candy whose middle is at `cframe`, its front (-Z) facing the player. Not parented
	    yet. Every part can be clicked (CanQuery on) but nothing collides; the invisible
	    Hitbox part (the PrimaryPart) makes it easier to tap on a phone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local CandyRushCandy = {}

local cfg = Config.Minigames.CandyRush.Candy

local WHITE = Color3.fromRGB(255, 252, 245)

-- A visible candy part: clickable, never collides, no shadow.
local function piece(props: Kit.Props, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.CastShadow = false
	return p
end

local function pieceWedge(props: Kit.Props, parent: Instance): WedgePart
	local w = Kit.wedge(props, parent)
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = true
	w.CastShadow = false
	return w
end

-- An oval: a block with a sphere mesh fills its whole size (a Ball part can only be round).
local function oval(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = piece({ Name = name, Size = size, CFrame = cf, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A flat disc facing the front (-Z) of `cf`.
local function disc(
	name: string,
	diameter: number,
	depth: number,
	cf: CFrame,
	color: Color3,
	parent: Instance
): Part
	return piece({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(depth, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, math.rad(90), 0), -- the cylinder's length (X) points forward
		Color = color,
	}, parent)
end

local function wrapped(cf: CFrame, s: number, color: Color3, m: Model)
	local bodyWidth = s * 0.6
	oval("Sweet", Vector3.new(bodyWidth, s * 0.42, s * 0.42), cf, color, m)
	local shine = oval(
		"Shine",
		Vector3.new(s * 0.16, s * 0.09, s * 0.05),
		cf * CFrame.new(-s * 0.1, s * 0.1, -s * 0.2) * CFrame.Angles(0, 0, math.rad(20)),
		WHITE,
		m
	)
	shine.Transparency = 0.25
	-- The twisted wrapper ends: a bow-tie triangle on each side, made of two wedges each.
	local length = s * 0.22
	local tall = s * 0.42
	local edge = bodyWidth / 2 - s * 0.04
	for _, side in { -1, 1 } do
		for _, half in { 1, -1 } do
			local turn = CFrame.Angles(0, math.rad(90 * side), 0)
			if half < 0 then
				turn *= CFrame.Angles(0, 0, math.pi)
			end
			pieceWedge({
				Name = "Wrapper",
				Size = Vector3.new(s * 0.08, tall / 2, length),
				CFrame = cf * CFrame.new(side * (edge + length / 2), half * tall / 4, 0) * turn,
				Color = color:Lerp(WHITE, 0.35),
			}, m)
		end
	end
end

local function lollipop(cf: CFrame, s: number, color: Color3, m: Model)
	local d = s * 0.72
	local top = cf * CFrame.new(0, s * 0.14, 0)
	disc("Lolly", d, s * 0.16, top, color, m)
	-- A bullseye swirl: rings of white and colour, each a little in front of the last.
	disc("Swirl", d * 0.74, s * 0.16, top * CFrame.new(0, 0, -0.03), WHITE, m)
	disc("Swirl", d * 0.5, s * 0.16, top * CFrame.new(0, 0, -0.06), color, m)
	disc("Swirl", d * 0.24, s * 0.16, top * CFrame.new(0, 0, -0.09), WHITE, m)
	local stickLength = s * 0.5
	piece({
		Name = "Stick",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(stickLength, s * 0.08, s * 0.08),
		CFrame = Kit.upright(top * CFrame.new(0, -d / 2 - stickLength / 2 + 0.1, s * 0.03)),
		Color = WHITE,
	}, m)
end

-- One triangle (apex up) of height h and base w, centred at `cf`, made of two wedges.
local function triangle(name: string, h: number, w: number, cf: CFrame, color: Color3, m: Model)
	for _, side in { -1, 1 } do
		pieceWedge({
			Name = name,
			Size = Vector3.new(0.12, h, w / 2),
			CFrame = cf
				* CFrame.new(side * w / 4, 0, 0)
				* CFrame.Angles(0, math.rad(-90 * side), 0),
			Color = color,
		}, m)
	end
end

local function candyCorn(cf: CFrame, s: number, m: Model)
	local colors = cfg.CornColors
	local h, w = s * 0.85, s * 0.62
	-- Three triangles of shrinking size, lined up at the tip: from the front you see a yellow
	-- base, an orange middle and a white tip.
	triangle("Corn", h, w, cf, colors[1], m)
	triangle("Corn", h * 2 / 3, w * 2 / 3, cf * CFrame.new(0, h / 6, -0.07), colors[2], m)
	triangle("Corn", h / 3, w / 3, cf * CFrame.new(0, h / 3, -0.14), colors[3], m)
end

local builders: { [string]: (CFrame, number, Color3, Model) -> () } = {
	Wrapped = wrapped,
	Lollipop = lollipop,
	CandyCorn = function(cf: CFrame, s: number, _color: Color3, m: Model)
		candyCorn(cf, s, m)
	end,
}

function CandyRushCandy.Build(kind: string, color: Color3, cframe: CFrame): Model
	local size: number = cfg.Size
	local builder = builders[kind] or builders.Wrapped
	local holder = Instance.new("Model") -- Kit.prop needs a parent; the caller re-parents it
	local candy = Kit.prop("CandyRush" .. kind, cframe, holder, size, function()
		local m = Instance.new("Model")
		m.Name = "CandyRush" .. kind
		builder(cframe, size, color, m)
		return m
	end, { Anchor = "Center" })
	-- A custom model is made clickable the same way as the built one.
	for _, d in candy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true
		end
	end
	local padding: number = cfg.HitboxPadding
	local hitbox = piece({
		Name = "Hitbox",
		Size = Vector3.new(size + padding, size + padding, 0.6),
		CFrame = cframe,
		Transparency = 1,
	}, candy)
	candy.PrimaryPart = hitbox
	candy.Name = "Candy"
	candy:SetAttribute("Kind", kind)
	candy:SetAttribute("CandyColor", if kind == "CandyCorn" then cfg.CornColors[2] else color)
	candy.Parent = nil
	holder:Destroy()
	return candy
end

return CandyRushCandy
