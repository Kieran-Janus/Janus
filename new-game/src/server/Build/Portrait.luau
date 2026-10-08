--!strict
--[[
	A haunted portrait for a wall (prop "Portrait"): an ornate gold frame with a bevelled inner
	edge and corner flourishes, and a painted canvas (a SurfaceGui) with a dark varnished
	background and a figure whose eyes follow you round the room (client PortraitEyes moves the
	pupils; tag PortraitEyes on the canvas part).

	Portrait.Build(cf, size, kind, colors, parent, image?) -> Model
	  cf      the middle of the frame, facing the room (cf.LookVector points out of the wall)
	  size    Vector2: the frame's width and height (studs)
	  kind    "Lady", "Gentleman", "Child" or "PumpkinLord" (Portrait.Kinds lists them)
	  colors  Frame (gold), Eyes (the glow in their eyes)
	  image   optional "rbxassetid://..." picture painted on the canvas instead of a figure
	          (the eyes still follow you only on the built figures)
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Kit)

local Portrait = {}

Portrait.Kinds = { "Lady", "Gentleman", "Child", "PumpkinLord" }

local PIXELS = 200 -- canvas pixels per stud

-- A rounded frame (a 2D shape) on the canvas. Positions are 0..1 of the canvas.
local function shape(
	parent: Instance,
	name: string,
	center: Vector2,
	size: Vector2,
	color: Color3,
	round: number?,
	z: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(center.X, center.Y)
	f.Size = UDim2.fromScale(size.X, size.Y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z or 2
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- Soft shading from the top-left (a painted look).
local function shade(f: Frame, amount: number)
	local g = Instance.new("UIGradient")
	g.Rotation = 35
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - amount, 1 - amount, 1 - amount))
	g.Parent = f
end

-- Two eyes: a pale white, a glowing iris with a dark pupil the client moves.
local function eyes(canvas: Instance, y: number, spread: number, size: number, glow: Color3)
	for _, side in { -1, 1 } do
		local white = shape(
			canvas,
			"Eye",
			Vector2.new(0.5 + side * spread, y),
			Vector2.new(size, size * 0.62),
			Color3.fromRGB(236, 226, 206),
			0.5,
			6
		)
		white.ClipsDescendants = true
		local iris =
			shape(white, "Pupil", Vector2.new(0.5, 0.5), Vector2.new(0.55, 0.9), glow, 0.5, 7)
		shape(
			iris,
			"Dot",
			Vector2.new(0.5, 0.5),
			Vector2.new(0.45, 0.45),
			Color3.fromRGB(10, 6, 12),
			0.5,
			8
		)
	end
end

local FIGURES: { [string]: (canvas: Instance, glow: Color3) -> () } = {}

function FIGURES.Lady(canvas: Instance, glow: Color3)
	local skin = Color3.fromRGB(226, 210, 196)
	shape(
		canvas,
		"Hair",
		Vector2.new(0.5, 0.42),
		Vector2.new(0.5, 0.56),
		Color3.fromRGB(40, 22, 20),
		0.45,
		2
	)
	shape(
		canvas,
		"Dress",
		Vector2.new(0.5, 0.95),
		Vector2.new(0.78, 0.5),
		Color3.fromRGB(70, 20, 50),
		0.4,
		3
	)
	shade(shape(canvas, "Neck", Vector2.new(0.5, 0.66), Vector2.new(0.11, 0.14), skin, nil, 3), 0.2)
	local face = shape(canvas, "Face", Vector2.new(0.5, 0.45), Vector2.new(0.3, 0.36), skin, 0.5, 4)
	shade(face, 0.3)
	shape(
		canvas,
		"Pearls",
		Vector2.new(0.5, 0.74),
		Vector2.new(0.3, 0.035),
		Color3.fromRGB(240, 236, 226),
		0.5,
		5
	)
	eyes(canvas, 0.43, 0.065, 0.075, glow)
	shape(
		canvas,
		"Lips",
		Vector2.new(0.5, 0.55),
		Vector2.new(0.08, 0.025),
		Color3.fromRGB(120, 20, 30),
		0.5,
		6
	)
end

function FIGURES.Gentleman(canvas: Instance, glow: Color3)
	local skin = Color3.fromRGB(214, 196, 180)
	shape(
		canvas,
		"Coat",
		Vector2.new(0.5, 0.95),
		Vector2.new(0.86, 0.5),
		Color3.fromRGB(26, 22, 32),
		0.3,
		3
	)
	shape(
		canvas,
		"Shirt",
		Vector2.new(0.5, 0.8),
		Vector2.new(0.16, 0.22),
		Color3.fromRGB(226, 222, 214),
		nil,
		4
	)
	shape(
		canvas,
		"Tie",
		Vector2.new(0.5, 0.75),
		Vector2.new(0.1, 0.05),
		Color3.fromRGB(130, 20, 30),
		0.3,
		5
	)
	local face =
		shape(canvas, "Face", Vector2.new(0.5, 0.48), Vector2.new(0.3, 0.36), skin, 0.45, 4)
	shade(face, 0.3)
	shape(
		canvas,
		"HatBrim",
		Vector2.new(0.5, 0.29),
		Vector2.new(0.44, 0.04),
		Color3.fromRGB(16, 14, 20),
		0.5,
		5
	)
	shape(
		canvas,
		"HatTop",
		Vector2.new(0.5, 0.17),
		Vector2.new(0.28, 0.22),
		Color3.fromRGB(20, 18, 26),
		0.1,
		5
	)
	eyes(canvas, 0.45, 0.065, 0.075, glow)
	shape(
		canvas,
		"Moustache",
		Vector2.new(0.5, 0.57),
		Vector2.new(0.18, 0.04),
		Color3.fromRGB(50, 34, 26),
		0.5,
		6
	)
end

function FIGURES.Child(canvas: Instance, glow: Color3)
	local skin = Color3.fromRGB(232, 232, 238)
	shape(
		canvas,
		"Hair",
		Vector2.new(0.5, 0.4),
		Vector2.new(0.44, 0.42),
		Color3.fromRGB(70, 60, 50),
		0.5,
		2
	)
	shape(
		canvas,
		"Smock",
		Vector2.new(0.5, 0.95),
		Vector2.new(0.66, 0.46),
		Color3.fromRGB(150, 160, 190),
		0.4,
		3
	)
	shape(
		canvas,
		"Collar",
		Vector2.new(0.5, 0.73),
		Vector2.new(0.3, 0.06),
		Color3.fromRGB(240, 240, 240),
		0.5,
		4
	)
	local face =
		shape(canvas, "Face", Vector2.new(0.5, 0.48), Vector2.new(0.32, 0.36), skin, 0.5, 4)
	shade(face, 0.35)
	eyes(canvas, 0.46, 0.075, 0.09, glow)
	shape(
		canvas,
		"Mouth",
		Vector2.new(0.5, 0.58),
		Vector2.new(0.05, 0.03),
		Color3.fromRGB(60, 30, 40),
		0.5,
		6
	)
end

function FIGURES.PumpkinLord(canvas: Instance, glow: Color3)
	shape(
		canvas,
		"Cape",
		Vector2.new(0.5, 0.95),
		Vector2.new(0.9, 0.5),
		Color3.fromRGB(100, 16, 30),
		0.35,
		3
	)
	shape(
		canvas,
		"Collar",
		Vector2.new(0.5, 0.74),
		Vector2.new(0.5, 0.08),
		Color3.fromRGB(230, 190, 60),
		0.4,
		4
	)
	for i, x in { 0.4, 0.5, 0.6 } do
		local rib = shape(
			canvas,
			"Pumpkin",
			Vector2.new(x, 0.47),
			Vector2.new(if i == 2 then 0.3 else 0.26, 0.34),
			Color3.fromRGB(230, 110, 20),
			0.5,
			if i == 2 then 5 else 4
		)
		shade(rib, 0.35)
	end
	shape(
		canvas,
		"Stem",
		Vector2.new(0.5, 0.28),
		Vector2.new(0.05, 0.08),
		Color3.fromRGB(70, 90, 40),
		0.3,
		5
	)
	shape(
		canvas,
		"Crown",
		Vector2.new(0.5, 0.25),
		Vector2.new(0.22, 0.06),
		Color3.fromRGB(240, 200, 60),
		0.1,
		6
	)
	eyes(canvas, 0.45, 0.07, 0.08, glow)
	shape(canvas, "Grin", Vector2.new(0.5, 0.56), Vector2.new(0.16, 0.035), glow, 0.4, 6)
end

function Portrait.Build(
	cf: CFrame,
	size: Vector2,
	kind: string,
	colors: { Frame: Color3, Eyes: Color3 },
	parent: Instance,
	image: string?
): Model
	return Kit.prop("Portrait", cf, parent, size.Y, function()
		local m = Kit.model("Portrait", parent)
		local border = 0.45
		-- The frame: four bevelled bars and a flourish at each corner.
		for _, bar in
			{
				{ Vector3.new(size.X, border, 0.35), Vector3.new(0, size.Y / 2 - border / 2, 0) },
				{ Vector3.new(size.X, border, 0.35), Vector3.new(0, -size.Y / 2 + border / 2, 0) },
				{ Vector3.new(border, size.Y, 0.35), Vector3.new(size.X / 2 - border / 2, 0, 0) },
				{ Vector3.new(border, size.Y, 0.35), Vector3.new(-size.X / 2 + border / 2, 0, 0) },
			}
		do
			Kit.decor({
				Name = "Frame",
				Size = bar[1],
				CFrame = cf * CFrame.new(bar[2]) * CFrame.new(0, 0, -0.1),
				Color = colors.Frame,
				Material = Enum.Material.Metal,
			}, m)
		end
		Kit.decor({
			Name = "Bevel",
			Size = Vector3.new(size.X - border * 1.4, size.Y - border * 1.4, 0.2),
			CFrame = cf * CFrame.new(0, 0, -0.05),
			Color = Kit.shade(colors.Frame, 0.35),
			Material = Enum.Material.Metal,
		}, m)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				Kit.decor({
					Name = "Flourish",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * border * 1.5,
					CFrame = cf * CFrame.new(
						x * (size.X / 2 - border / 2),
						y * (size.Y / 2 - border / 2),
						-0.25
					),
					Color = colors.Frame,
					Material = Enum.Material.Metal,
				}, m)
			end
		end
		local canvasSize = Vector2.new(size.X - border * 2, size.Y - border * 2)
		local canvas = Kit.decor({
			Name = "Canvas",
			Size = Vector3.new(canvasSize.X, canvasSize.Y, 0.1),
			CFrame = cf * CFrame.new(0, 0, -0.18),
			Color = Color3.fromRGB(30, 18, 22),
			Material = Enum.Material.Fabric,
		}, m)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Painting"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = canvasSize * PIXELS
		-- Mostly its own colours (a dark room would turn the paint purple), a little room light.
		gui.LightInfluence = 0.2
		gui.Brightness = 0.9
		gui.Parent = canvas
		local back = shape(
			gui,
			"Back",
			Vector2.new(0.5, 0.5),
			Vector2.new(1, 1),
			Color3.new(1, 1, 1), -- (the gradient below gives the colour)
			nil,
			1
		)
		local varnish = Instance.new("UIGradient")
		varnish.Rotation = 90
		varnish.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 78, 62)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(72, 38, 42)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 16, 22)),
		})
		varnish.Parent = back
		if image and image ~= "" then
			local picture = Instance.new("ImageLabel")
			picture.Name = "Picture"
			picture.Size = UDim2.fromScale(1, 1)
			picture.BackgroundTransparency = 1
			picture.Image = image
			picture.ScaleType = Enum.ScaleType.Crop
			picture.ZIndex = 3
			picture.Parent = gui
		else
			-- (painted inside a clipping frame: a SurfaceGui doesn't cut off what hangs over
			-- its edge, so a coat would spill out under the frame)
			local paint = Instance.new("Frame")
			paint.Name = "Paint"
			paint.Size = UDim2.fromScale(1, 1)
			paint.BackgroundTransparency = 1
			paint.ClipsDescendants = true
			paint.ZIndex = 2
			paint.Parent = gui
			local figure = FIGURES[kind] or FIGURES.Lady
			figure(paint, colors.Eyes)
			CollectionService:AddTag(canvas, Tags.PortraitEyes)
		end
		-- A dark edge all round, like old paint.
		local vignette = shape(
			gui,
			"Vignette",
			Vector2.new(0.5, 0.5),
			Vector2.new(1, 1),
			Color3.new(0, 0, 0),
			nil,
			9
		)
		vignette.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 40
		stroke.Transparency = 0.45
		stroke.Color = Color3.fromRGB(10, 4, 8)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = vignette
		m.PrimaryPart = canvas
		return m
	end, { Visual = true })
end

return Portrait
