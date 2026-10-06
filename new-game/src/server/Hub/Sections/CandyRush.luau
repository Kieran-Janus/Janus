--!strict
--[[
	Lobby section: the Candy Rush stand (the race itself: src/server/Services/CandyRushService.luau).
	Where: Config.Lobby.Zones.CandyRush. Settings: Config.Minigames.CandyRush (the look is
	in its Stand part). Off (Config.Features.CandyRush = false): only an empty model is made.

	Workspace.Hub.CandyRush
	  CandyStand        the stand (tag CandyRushStation). Copy it for a second race.
	    CandyBoard      the tilted board candies pop up on (tag CandyRushBoard). Its big flat
	                    side faces the pads; resize or move it and the lanes follow.
	    JoinPads        Pad1, Pad2... the coloured pads (tag CandyRushPad, attribute Lane).
	                    Lane 1 is the left column of the board as you look at it.
	    BoardFrame      the candy-cane frame and the lane stripes (looks only)
	    Scoreboard      the screen above the board (SurfaceGui "ScoreboardGui", labels Status
	                    and Record: CandyRushService writes them)
	    Sign            "CANDY RUSH - first to grab all the candy wins!"
	    CandyCane       the two giant candy canes holding the sign (prop "CandyCane")
	  Floor             the checkered floor and the coloured runners from the pads to the board
	  Decorations       giant lollipops, candy buckets and gumdrops (props, swappable)
	The service adds a "Candies" folder (the candies) and a "LaneScreen" part (the lanes'
	names and progress drawn on the board) to the stand while the game runs.

	CandyRush.Build(hub, zone) -> Model
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local CandyRush = {}

local cfg = Config.Minigames.CandyRush
local stand = cfg.Stand
local colors = stand.Colors
local paint = Kit.painter(Config.Hub.Palette)

local WHITE = Color3.fromRGB(255, 252, 245)

-- Helpers ---------------------------------------------------------------------------------------

local function decor(props: Kit.Props, parent: Instance): Part
	local p = Kit.decor(props, parent)
	p.CastShadow = false
	return p
end

-- An oval (a block with a sphere mesh: a Ball part can only be a perfect sphere).
local function oval(props: Kit.Props, parent: Instance, solid: boolean?): Part
	local p = if solid then Kit.part(props, parent) else decor(props, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A cylinder from `a` to `b`.
local function rod(
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	parent: Instance,
	solid: boolean?
): Part
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(dir.Magnitude, diameter, diameter),
		CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
	}
	return if solid then Kit.part(props, parent) else decor(props, parent)
end

-- A white rod with slanted coloured bands: candy-cane stripes.
local function candyStripes(
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	spacing: number,
	parent: Instance,
	solid: boolean?
)
	rod(name, a, b, diameter, colors.Frame, parent, solid)
	local dir = b - a
	local length = dir.Magnitude
	local up = if math.abs(dir.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local count = math.max(1, math.floor(length / spacing))
	for i = 1, count do
		local p = a + dir * ((i - 0.5) / count)
		decor({
			Name = "Stripe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(diameter * 0.32, diameter + 0.1, diameter + 0.1),
			CFrame = CFrame.lookAt(p, b, up)
				* CFrame.Angles(0, math.rad(90), 0)
				* CFrame.Angles(0, 0, math.rad(28)),
			Color = colors.Stripe,
		}, parent)
	end
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
	return decor({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(depth, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
	}, parent)
end

local function laneColor(lane: number): Color3
	local list = stand.LaneColors
	return list[(lane - 1) % #list + 1]
end

-- Decorations (props: swap any of them for your own model in ReplicatedStorage.Custom.Props) ----

-- A giant candy cane standing on `cf`, its hook curling towards cf's -X (`hookSide` = -1) or +X.
local function candyCane(cf: CFrame, height: number, hookSide: number, parent: Instance): Model
	return Kit.prop("CandyCane", cf, parent, height + 2, function()
		local m = Kit.model("CandyCane", parent)
		local d = 1.5
		local radius = 1.9
		local top = cf * CFrame.new(0, height, 0)
		rod(
			"Foot",
			cf.Position,
			(cf * CFrame.new(0, 0.6, 0)).Position,
			d + 0.8,
			colors.Stripe,
			m,
			true
		)
		candyStripes("Shaft", cf.Position, top.Position, d, 1.5, m, true)
		-- The hook: short pieces around a half circle, white and coloured in turn.
		local centre = top * CFrame.new(hookSide * radius, 0, 0)
		local segments = 8
		local function point(t: number): Vector3
			local a = math.pi * t
			return (centre * CFrame.new(-hookSide * radius * math.cos(a), radius * math.sin(a), 0)).Position
		end
		for i = 0, segments - 1 do
			local a, b = point(i / segments), point((i + 1) / segments)
			local piece = rod(
				"Hook",
				a,
				b + (b - a).Unit * 0.25,
				d,
				if i % 2 == 0 then colors.Frame else colors.Stripe,
				m
			)
			piece.CanCollide = false
		end
		local tip = point(1)
		rod("Hook", tip, tip - Vector3.new(0, 1.2, 0), d, colors.Frame, m)
		local cap = decor({
			Name = "HookEnd",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d,
			CFrame = CFrame.new(tip - Vector3.new(0, 1.2, 0)),
			Color = colors.Frame,
		}, m)
		cap.CanQuery = false
		return m
	end)
end

-- A giant swirly lollipop on a stick, facing cf's front (-Z).
local function giantLollipop(cf: CFrame, height: number, color: Color3, parent: Instance): Model
	return Kit.prop("GiantLollipop", cf, parent, height, function()
		local m = Kit.model("GiantLollipop", parent)
		local d = height * 0.5
		local stickTop = height - d / 2
		rod("Stick", cf.Position, (cf * CFrame.new(0, stickTop, 0)).Position, 0.45, WHITE, m, true)
		local centre = cf * CFrame.new(0, stickTop, 0)
		disc("Candy", d, 0.6, centre, color, m)
		local ringColors = { WHITE, color, WHITE, color }
		for i, ring in ringColors do
			disc("Swirl", d * (1 - i * 0.18), 0.6, centre * CFrame.new(0, 0, -0.04 * i), ring, m)
		end
		-- A bow under the candy.
		for _, side in { -1, 1 } do
			oval({
				Name = "Bow",
				Size = Vector3.new(1.1, 0.6, 0.4),
				CFrame = centre
					* CFrame.new(side * 0.55, -d / 2 - 0.15, -0.1)
					* CFrame.Angles(0, 0, math.rad(25 * side)),
				Color = colors.Stripe,
			}, m)
		end
		local glow = Kit.holder("Glow", centre, Vector3.one, m)
		Kit.light(glow, color, d * 2.5, 0.8, false)
		return m
	end)
end

-- A jack-o'-lantern trick-or-treat bucket full of candy.
local function candyBucket(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("CandyBucket", cf, parent, size * 1.4, function()
		local m = Kit.model("CandyBucket", parent)
		local body = oval({
			Name = "Bucket",
			Size = Vector3.new(size * 1.15, size, size * 1.15),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			Color = paint.color("Orange"),
			PaletteRole = "Orange",
		}, m, true)
		Kit.carvedFace(cf * CFrame.new(0, size / 2, -size * 0.07), size, paint.color("Dark"), m)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d ~= body then
				d:SetAttribute("PaletteRole", "Dark")
				d.Material = Enum.Material.SmoothPlastic
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		-- Candy heaped on top.
		local candyColors = cfg.Candy.Colors
		for i = 1, 7 do
			local a = i * 2.4
			local r = if i == 7 then 0 else size * 0.28
			oval({
				Name = "Sweet",
				Size = Vector3.new(size * 0.32, size * 0.22, size * 0.22),
				CFrame = cf * CFrame.new(
					math.cos(a) * r,
					size * (if i == 7 then 1.05 else 0.95),
					math.sin(a) * r
				) * CFrame.Angles(0, a, math.rad(15)),
				Color = candyColors[(i - 1) % #candyColors + 1],
			}, m)
		end
		-- The handle.
		local segments = 6
		local handleRadius = size * 0.58
		local centre = cf * CFrame.new(0, size * 0.85, 0)
		local last: Vector3? = nil
		for i = 0, segments do
			local a = math.pi * i / segments
			local p = (centre * CFrame.new(
				math.cos(a) * handleRadius,
				math.sin(a) * handleRadius * 0.9,
				0
			)).Position
			if last then
				local piece = rod("Handle", last, p, 0.15, paint.color("Iron"), m)
				piece:SetAttribute("PaletteRole", "Iron")
			end
			last = p
		end
		m.PrimaryPart = body
		return m
	end)
end

-- A sugar-coated gumdrop.
local function gumdrop(cf: CFrame, size: number, color: Color3, parent: Instance): Model
	return Kit.prop("Gumdrop", cf, parent, size, function()
		local m = Kit.model("Gumdrop", parent)
		oval({
			Name = "Gumdrop",
			Size = Vector3.new(size, size * 1.5, size),
			CFrame = cf * CFrame.new(0, size * 0.2, 0),
			Color = color,
			Material = Enum.Material.Sand,
		}, m, true)
		return m
	end)
end

-- The stand ----------------------------------------------------------------------------------------

-- Where a lane's pad stands (x across the stand): lane 1 is on the left as you face the board.
local function laneX(lane: number, lanes: number): number
	local width: number = stand.BoardWidth
	return width / 2 - (lane - 0.5) * width / lanes
end

-- The board, its candy-cane frame and the lane stripes. Returns the board part.
local function buildBoard(standModel: Model, base: CFrame, lanes: number): BasePart
	local width: number, height: number = stand.BoardWidth, stand.BoardHeight
	local thickness = 1
	-- The bottom middle of the board's face, then tilted back.
	local hinge = base
		* CFrame.new(0, stand.BoardLift, stand.BoardBack)
		* CFrame.Angles(math.rad(stand.BoardTilt), 0, 0)
	local board = Kit.part({
		Name = "CandyBoard",
		Size = Vector3.new(width, height, thickness),
		CFrame = hinge * CFrame.new(0, height / 2, thickness / 2),
		Color = colors.Board,
		Material = Enum.Material.SmoothPlastic,
	}, standModel)
	CollectionService:AddTag(board, Tags.CandyRushBoard)

	local frame = Kit.model("BoardFrame", standModel)
	local face = hinge * CFrame.new(0, height / 2, 0) -- the middle of the front face
	-- Lane stripes: a soft tint of each lane's colour, white lines between lanes.
	local laneWidth = width / lanes
	for lane = 1, lanes do
		local tint = decor({
			Name = "LaneTint",
			Size = Vector3.new(laneWidth - 0.3, height - 0.3, 0.05),
			CFrame = face * CFrame.new(laneX(lane, lanes), 0, -0.03),
			Color = laneColor(lane),
			Transparency = 0.58,
		}, frame)
		tint:SetAttribute("Lane", lane)
		-- A gumdrop "light" at the top of each lane in its colour.
		local bulb = oval({
			Name = "LaneBulb",
			Size = Vector3.new(1.1, 1.1, 0.7),
			CFrame = face * CFrame.new(laneX(lane, lanes), height / 2 + 0.75, -0.35),
			Color = laneColor(lane),
			Material = Enum.Material.Neon,
		}, frame)
		bulb:SetAttribute("Lane", lane)
	end
	for i = 1, lanes - 1 do
		decor({
			Name = "LaneLine",
			Size = Vector3.new(0.22, height - 0.4, 0.12),
			CFrame = face * CFrame.new(width / 2 - i * laneWidth, 0, -0.08),
			Color = WHITE,
		}, frame)
	end
	-- The candy-cane frame around the edge, with round corners.
	local function corner(x: number, y: number): Vector3
		return (face * CFrame.new(x, y, -0.2)).Position
	end
	local hw, hh = width / 2 + 0.55, height / 2 + 0.55
	local corners = { corner(-hw, -hh), corner(hw, -hh), corner(hw, hh), corner(-hw, hh) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		candyStripes("FrameBar", a, b, 1.1, 1.6, frame, true)
		decor({
			Name = "FrameCorner",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.5,
			CFrame = CFrame.new(a),
			Color = colors.Stripe,
		}, frame)
	end
	-- Two legs behind the board, down to the ground.
	for _, side in { -1, 1 } do
		local top = (face * CFrame.new(side * (width / 2 - 3), -height / 4, thickness + 0.4)).Position
		rod(
			"Leg",
			top,
			Vector3.new(top.X, base.Position.Y, top.Z) + base.LookVector * -1.5,
			0.8,
			paint.color("Wood"),
			frame,
			true
		):SetAttribute("PaletteRole", "Wood")
	end
	return board
end

local function buildPads(standModel: Model, base: CFrame, lanes: number)
	local pads = Kit.model("JoinPads", standModel)
	local size: number = stand.PadSize
	local z = stand.BoardBack - stand.PadDistance
	for lane = 1, lanes do
		local color = laneColor(lane)
		local spot = base * CFrame.new(laneX(lane, lanes), 0, z)
		local pad = Kit.part({
			Name = "Pad" .. lane,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, size, size),
			CFrame = Kit.upright(spot * CFrame.new(0, 0.3, 0)),
			Color = color,
		}, pads)
		pad:SetAttribute("Lane", lane)
		CollectionService:AddTag(pad, Tags.CandyRushPad)
		-- A peppermint swirl on top: a white ring and the lane colour in the middle.
		decor({
			Name = "PadRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.08, size - 0.9, size - 0.9),
			CFrame = Kit.upright(spot * CFrame.new(0, 0.62, 0)),
			Color = WHITE,
		}, pads)
		decor({
			Name = "PadCentre",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, size - 2.2, size - 2.2),
			CFrame = Kit.upright(spot * CFrame.new(0, 0.64, 0)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		}, pads)
	end
end

local function textLabel(
	name: string,
	text: string,
	font: Enum.Font,
	color: Color3,
	parent: Instance
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = parent
	return label
end

-- The sign on top and the scoreboard screen under it.
local function buildSign(standModel: Model, base: CFrame)
	local text = cfg.Text
	local width: number = stand.BoardWidth
	local boardTop = stand.BoardLift + stand.BoardHeight * math.cos(math.rad(stand.BoardTilt))
	local backZ = stand.BoardBack + stand.BoardHeight * math.sin(math.rad(stand.BoardTilt))

	-- Scoreboard: a dark screen just above the board.
	local screenSize = Vector3.new(width * 0.62, 3.2, 0.5)
	local screenCf = base * CFrame.new(0, boardTop + 1 + screenSize.Y / 2, backZ + 0.3)
	local scoreboard = Kit.model("Scoreboard", standModel)
	local screen = Kit.part({
		Name = "Screen",
		Size = screenSize,
		CFrame = screenCf,
		Color = colors.Screen,
	}, scoreboard)
	local border = colors.Stripe
	for _, side in { -1, 1 } do
		decor({
			Name = "ScreenEdge",
			Size = Vector3.new(screenSize.X + 0.6, 0.3, 0.7),
			CFrame = screenCf * CFrame.new(0, side * (screenSize.Y / 2 + 0.15), 0),
			Color = border,
		}, scoreboard)
		decor({
			Name = "ScreenEdge",
			Size = Vector3.new(0.3, screenSize.Y, 0.7),
			CFrame = screenCf * CFrame.new(side * (screenSize.X / 2 + 0.15), 0, 0),
			Color = border,
		}, scoreboard)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ScoreboardGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local status = textLabel("Status", text.Idle, Enum.Font.FredokaOne, colors.SignText, gui)
	status.Position = UDim2.fromScale(0.04, 0.06)
	status.Size = UDim2.fromScale(0.92, 0.58)
	local record = textLabel("Record", text.NoRecord, Enum.Font.GothamBold, WHITE, gui)
	record.Position = UDim2.fromScale(0.1, 0.66)
	record.Size = UDim2.fromScale(0.8, 0.28)
	gui.Parent = screen

	-- The sign: a rounded purple board with the name.
	local signModel = Kit.model("Sign", standModel)
	local signSize = Vector3.new(width - 2, 4.4, 0.8)
	local signCf = base
		* CFrame.new(0, boardTop + 1 + screenSize.Y + 1 + signSize.Y / 2, backZ + 0.5)
	local sign = Kit.part({
		Name = "SignBoard",
		Size = signSize,
		CFrame = signCf,
		Color = colors.Sign,
	}, signModel)
	for _, side in { -1, 1 } do
		Kit.part({
			Name = "SignEnd",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(signSize.Z, signSize.Y, signSize.Y),
			CFrame = signCf
				* CFrame.new(side * signSize.X / 2, 0, 0)
				* CFrame.Angles(0, math.rad(90), 0),
			Color = colors.Sign,
		}, signModel)
	end
	-- An orange piping along the top and bottom edge.
	for _, side in { -1, 1 } do
		rod(
			"SignPiping",
			(signCf * CFrame.new(-signSize.X / 2, side * signSize.Y / 2, -0.1)).Position,
			(signCf * CFrame.new(signSize.X / 2, side * signSize.Y / 2, -0.1)).Position,
			0.45,
			colors.Stripe,
			signModel
		)
	end
	local lettering = Instance.new("SurfaceGui")
	lettering.Name = "Lettering"
	lettering.Face = Enum.NormalId.Front
	lettering.LightInfluence = 0
	lettering.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	lettering.PixelsPerStud = 40
	local title =
		textLabel("Title", text.SignTitle, Enum.Font.FredokaOne, colors.SignText, lettering)
	title.Position = UDim2.fromScale(0.02, 0.04)
	title.Size = UDim2.fromScale(0.96, 0.62)
	title.TextStrokeColor3 = Color3.fromRGB(60, 20, 80)
	title.TextStrokeTransparency = 0
	local subtitle =
		textLabel("Subtitle", text.SignSubtitle, Enum.Font.GothamBold, WHITE, lettering)
	subtitle.Position = UDim2.fromScale(0.06, 0.66)
	subtitle.Size = UDim2.fromScale(0.88, 0.28)
	lettering.Parent = sign
	local glow = Kit.holder("SignGlow", signCf * CFrame.new(0, 0, -2), Vector3.one, signModel)
	Kit.light(glow, colors.SignText, 22, 0.9, false)

	-- Candy corn on top of the sign.
	for i, x in { -0.32, 0, 0.32 } do
		local s = if i == 2 then 2.6 else 1.8
		local cornCf = signCf * CFrame.new(x * signSize.X, signSize.Y / 2 + s * 0.42, 0)
		Kit.prop("SignCandyCorn", cornCf, signModel, s, function()
			local corn = Kit.model("SignCandyCorn", signModel)
			local cornColors = cfg.Candy.CornColors
			local h, w = s * 0.85, s * 0.62
			local layers = {
				{ h, w, 0, 0 },
				{ h * 2 / 3, w * 2 / 3, h / 6, -0.12 },
				{ h / 3, w / 3, h / 3, -0.24 },
			}
			for layer, info in layers do
				for _, sideX in { -1, 1 } do
					local wedge = Kit.wedge({
						Name = "Corn",
						Size = Vector3.new(0.3, info[1], info[2] / 2),
						CFrame = cornCf
							* CFrame.new(sideX * info[2] / 4, info[3], info[4])
							* CFrame.Angles(0, math.rad(-90 * sideX), 0),
						Color = cornColors[layer],
					}, corn)
					wedge.CanCollide = false
					wedge.CanQuery = false
					wedge.CastShadow = false
				end
			end
			return corn
		end, { Anchor = "Center" })
	end
end

function CandyRush.Build(hub: Model, zone: Zone): Model
	local area = Kit.model("CandyRush", hub)
	if not Config.Features.CandyRush then
		return area
	end
	local base = zone.CFrame
	local lanes = math.clamp(math.floor(stand.Lanes), 2, 6)

	-- The floor: a pink-and-white checkerboard with a coloured runner from each pad to the board.
	local floor = Kit.model("Floor", area)
	local tile = 6
	local columns, rows = 5, 4
	local floorCentre = base * CFrame.new(0, 0, 1)
	decor({
		Name = "FloorMat",
		Size = Vector3.new(columns * tile, 0.12, rows * tile),
		CFrame = floorCentre * CFrame.new(0, 0.06, 0),
		Color = colors.Floor,
	}, floor)
	for cx = 1, columns do
		for cz = 1, rows do
			if (cx + cz) % 2 == 0 then
				decor({
					Name = "FloorTile",
					Size = Vector3.new(tile, 0.14, tile),
					CFrame = floorCentre * CFrame.new(
						(cx - (columns + 1) / 2) * tile,
						0.07,
						(cz - (rows + 1) / 2) * tile
					),
					Color = colors.FloorAlt,
				}, floor)
			end
		end
	end
	local padZ = stand.BoardBack - stand.PadDistance
	for lane = 1, lanes do
		local from = padZ + stand.PadSize / 2
		local to = stand.BoardBack + 0.5
		decor({
			Name = "LaneRunner",
			Size = Vector3.new(1.4, 0.18, to - from),
			CFrame = base * CFrame.new(laneX(lane, lanes), 0.09, (from + to) / 2),
			Color = laneColor(lane),
		}, floor)
	end

	-- The stand itself (the race happens on it).
	local standModel = Kit.model("CandyStand", area)
	CollectionService:AddTag(standModel, Tags.CandyRushStation)
	buildBoard(standModel, base, lanes)
	buildPads(standModel, base, lanes)
	buildSign(standModel, base)
	local caneX = stand.BoardWidth / 2 + 2.2
	local caneHeight = stand.BoardLift + stand.BoardHeight + 6
	for _, side in { -1, 1 } do
		candyCane(
			base * CFrame.new(side * caneX, 0, stand.BoardBack + 1.6),
			caneHeight,
			-side,
			standModel
		)
	end
	standModel.WorldPivot = base

	-- Decorations around it.
	local decorations = Kit.model("Decorations", area)
	local halfX, halfZ = zone.Size.X / 2, zone.Size.Z / 2
	local front = -halfZ + 2.5
	for i, side in { -1, 1 } do
		giantLollipop(
			base * CFrame.new(side * (halfX - 2.5), 0, front),
			8,
			if i == 1 then colors.Stripe else stand.LaneColors[5] or colors.Sign,
			decorations
		)
		candyBucket(base * CFrame.new(side * (halfX - 1.8), 0, padZ - 4), 2.6, decorations)
	end
	local gumdropColors = cfg.Candy.Colors
	local spots = {
		Vector3.new(-halfX + 1.5, 0, halfZ - 2),
		Vector3.new(halfX - 1.5, 0, halfZ - 2),
		Vector3.new(-halfX + 3, 0, halfZ - 1.2),
		Vector3.new(halfX - 3, 0, halfZ - 1.2),
		Vector3.new(-halfX + 1.2, 0, front + 3),
		Vector3.new(halfX - 1.2, 0, front + 3),
	}
	for i, spot in spots do
		gumdrop(
			base * CFrame.new(spot),
			1.2 + (i % 3) * 0.3,
			gumdropColors[(i - 1) % #gumdropColors + 1],
			decorations
		)
	end
	return area
end

return CandyRush
