--!strict
--[[
	How the lobby NPCs look (the parts only). src/server/Hub/Npcs.luau decides where they stand,
	gives them prompts, tags and name tags, and calls these. Colours come from
	Config.Hub.Palette (PaletteRole attributes), text from Config.

	NpcLooks.Stall(cf, parent) -> Model           the Pumpkin Shop stall, Model "Stall" (prop
	                                              "VendorStall"): counter ("Counter"), striped
	                                              awning ("AwningStripe"), shelves, big sign,
	                                              lanterns. cf = the middle of the stall on the
	                                              ground, front (-Z) towards the plaza; the
	                                              keeper stands 0.5 studs behind it.
	NpcLooks.Keeper(spot, parent) -> Model        the pumpkin-headed shopkeeper, Model "Keeper"
	NpcLooks.Board(cf, m, text) -> (BasePart, BasePart)       the Voting Board: its "Screen"
	                                              (the vote is drawn on its front) and the part
	                                              its name tag hangs from
	NpcLooks.Gravestone(cf, m) -> (BasePart, BasePart)  the Leaderboard Gravestone: "Screen", tag part
	NpcLooks.PhotoSpot(cf, m) -> BasePart         the Photo Spot stage ("Stage")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)

local NpcLooks = {}

local hubCfg = Config.Hub
local paint = Kit.painter(hubCfg.Palette)
local part = paint.part
local decor = paint.decor
local wedge = paint.wedge
local color = paint.color
local model = Kit.model
local upright = Kit.upright

-- Words painted on the front of `target` (FredokaOne: round and friendly).
local function sign(
	target: BasePart,
	text: string,
	textColor: Color3,
	face: Enum.NormalId?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeColor3 = color("Dark")
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = target
	return label
end

-- The Pumpkin Shop stall --------------------------------------------------------------------------

local SHELF_ITEMS = { "Pumpkin", "Potion", "WhitePumpkin", "Hat" }

local function shelfItem(kind: string, cf: CFrame, parent: Instance)
	if kind == "Pumpkin" or kind == "WhitePumpkin" then
		decor({
			Name = "ShelfPumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1, 1.3),
			CFrame = cf * CFrame.new(0, 0.5, 0),
			PaletteRole = if kind == "Pumpkin" then "Orange" else "Bone",
		}, parent)
		decor({
			Name = "ShelfPumpkinStem",
			Size = Vector3.new(0.18, 0.35, 0.18),
			CFrame = cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(12)),
			PaletteRole = "Green",
			PaletteShade = 0.3,
		}, parent)
	elseif kind == "Potion" then
		decor({
			Name = "PotionBottle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 1.1, 0.9),
			CFrame = cf * CFrame.new(0, 0.55, 0),
			PaletteRole = "Teal",
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, parent)
		decor({
			Name = "PotionCork",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.45, 0.35, 0.35),
			CFrame = upright(cf * CFrame.new(0, 1.25, 0)),
			PaletteRole = "Wood",
		}, parent)
	else
		decor({
			Name = "HatBrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 1.5, 1.5),
			CFrame = upright(cf * CFrame.new(0, 0.08, 0)),
			PaletteRole = "Purple",
			PaletteShade = 0.25,
		}, parent)
		decor({
			Name = "HatTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 1.4, 0.7),
			CFrame = cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(10)),
			PaletteRole = "Purple",
			PaletteShade = 0.25,
		}, parent)
	end
end

function NpcLooks.Stall(cf: CFrame, parent: Instance): Model
	local cfg = hubCfg.ShopStall
	local stall = model("Stall", parent)
	local half = 7.6 -- from the middle to the posts (the stall is about 16 studs wide)
	local wallWidth = half * 2 + 1.2
	part({
		Name = "Counter",
		Size = Vector3.new(half * 2 - 1.4, 3.2, 2.6),
		CFrame = cf * CFrame.new(0, 1.6, -2.5),
		PaletteRole = "Wood",
		Material = Enum.Material.WoodPlanks,
	}, stall)
	part({
		Name = "CounterTop",
		Size = Vector3.new(half * 2 - 0.6, 0.4, 3.2),
		CFrame = cf * CFrame.new(0, 3.4, -2.5),
		PaletteRole = "Wood",
		PaletteShade = -0.15,
		Material = Enum.Material.WoodPlanks,
	}, stall)
	local panels = 5
	local panelWidth = (half * 2 - 1.8) / panels
	for i = 0, panels - 1 do
		decor({
			Name = "CounterStripe",
			Size = Vector3.new(panelWidth - 0.15, 2.3, 0.12),
			CFrame = cf * CFrame.new(-(half - 0.9) + panelWidth * (i + 0.5), 1.75, -3.85),
			PaletteRole = if i % 2 == 0 then "Orange" else "Purple",
			Material = Enum.Material.Fabric,
		}, stall)
	end
	for _, x in { -half, half } do
		for _, z in { -3.8, 5 } do
			part({
				Name = "Post",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(11, 0.9, 0.9),
				CFrame = upright(cf * CFrame.new(x, 5.5, z)),
				PaletteRole = "Wood",
				PaletteShade = 0.1,
				Material = Enum.Material.Wood,
			}, stall)
		end
	end
	part({
		Name = "BackWall",
		Size = Vector3.new(wallWidth, 12.4, 0.6),
		CFrame = cf * CFrame.new(0, 6.2, 5.5),
		PaletteRole = "Wood",
		PaletteShade = 0.25,
		Material = Enum.Material.WoodPlanks,
	}, stall)
	-- Shelves of goodies behind the keeper.
	for s, y in { 3.8, 6.5, 9.2 } do
		decor({
			Name = "Shelf",
			Size = Vector3.new(half * 2 - 1.6, 0.3, 1.4),
			CFrame = cf * CFrame.new(0, y, 4.55),
			PaletteRole = "Wood",
			PaletteShade = -0.1,
			Material = Enum.Material.WoodPlanks,
		}, stall)
		local count = math.max(cfg.ShelfItems, 0)
		local span = half * 2 - 3
		for i = 1, count do
			local x = -span / 2 + (i - 0.5) * (span / count)
			local kind = SHELF_ITEMS[(i + s) % #SHELF_ITEMS + 1]
			shelfItem(
				kind,
				cf * CFrame.new(x, y + 0.15, 4.5) * CFrame.Angles(0, math.rad(180), 0),
				stall
			)
		end
	end
	-- The striped awning, sloping down towards the plaza, with a scalloped edge.
	local stripes = 8
	local back, front = Vector3.new(0, 12.8, 5.8), Vector3.new(0, 9.6, -6.2)
	local slope = math.atan2(back.Y - front.Y, back.Z - front.Z)
	local length = (back - front).Magnitude + 0.4
	local stripeWidth = (wallWidth + 0.4) / stripes
	for i = 0, stripes - 1 do
		local x = -(wallWidth + 0.4) / 2 + stripeWidth * (i + 0.5)
		local role = if i % 2 == 0 then "Orange" else "Purple"
		decor({
			Name = "AwningStripe",
			Size = Vector3.new(stripeWidth + 0.02, 0.3, length),
			CFrame = cf
				* CFrame.new(x, (back.Y + front.Y) / 2, (back.Z + front.Z) / 2)
				* CFrame.Angles(-slope, 0, 0),
			PaletteRole = role,
			Material = Enum.Material.Fabric,
		}, stall)
		-- A hanging band with a round bottom: the scalloped edge.
		decor({
			Name = "AwningValance",
			Size = Vector3.new(stripeWidth + 0.02, 0.9, 0.16),
			CFrame = cf * CFrame.new(x, front.Y - 0.5, front.Z - 0.1),
			PaletteRole = role,
			Material = Enum.Material.Fabric,
		}, stall)
		decor({
			Name = "AwningScallop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.16, stripeWidth * 0.98, stripeWidth * 0.98),
			CFrame = cf
				* CFrame.new(x, front.Y - 0.95, front.Z - 0.1)
				* CFrame.Angles(0, math.rad(90), 0),
			PaletteRole = role,
			Material = Enum.Material.Fabric,
		}, stall)
	end
	-- The big sign on top.
	local signY = back.Y + 2.9
	part({
		Name = "SignFrame",
		Size = Vector3.new(wallWidth + 0.6, 5, 0.4),
		CFrame = cf * CFrame.new(0, signY, 5.5),
		PaletteRole = "Wood",
		PaletteShade = 0.2,
		Material = Enum.Material.WoodPlanks,
	}, stall)
	local board = decor({
		Name = "SignBoard",
		Size = Vector3.new(wallWidth - 0.4, 4, 0.3),
		CFrame = cf * CFrame.new(0, signY, 5.2),
		PaletteRole = "Purple",
		PaletteShade = 0.45,
	}, stall)
	sign(board, cfg.SignText, color("Orange"))
	Props.JackOLantern(
		paint,
		cf * CFrame.new(0, signY + 2.5, 5.4),
		2.6,
		stall,
		{ Detail = "Simple" }
	)
	for _, x in { -(half - 0.6), half - 0.6 } do
		Props.Pumpkin(
			paint,
			cf * CFrame.new(x, signY + 2.5, 5.4),
			1.4,
			stall,
			{ Ribs = 3, Leaf = false, Solid = false }
		)
	end
	-- Lanterns hanging from the front corners of the awning.
	for _, x in { -half, half } do
		decor({
			Name = "LanternRope",
			Size = Vector3.new(0.08, 1.2, 0.08),
			CFrame = cf * CFrame.new(x, front.Y - 0.6, -4.7),
			PaletteRole = "Iron",
		}, stall)
		Props.Lantern(
			paint,
			cf * CFrame.new(x, front.Y - 3, -4.7),
			1.7,
			stall,
			{ Light = true, Range = 18 }
		)
	end
	-- Two little jack-o-lanterns on the counter.
	for _, x in { -(half - 2.6), half - 2.6 } do
		Props.JackOLantern(paint, cf * CFrame.new(x, 3.6, -2.7), 1.4, stall, { Detail = "Simple" })
	end
	return stall
end

-- A pumpkin-headed farmer in a straw hat. Stands on `spot`, facing spot.LookVector.
function NpcLooks.Keeper(spot: CFrame, parent: Instance): Model
	local keeper = model("Keeper", parent)
	part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.7, 4, 2.2),
		CFrame = spot * CFrame.new(0, 3.1, 0),
		PaletteRole = "Cloth",
		Material = Enum.Material.Fabric,
	}, keeper)
	decor({
		Name = "Apron",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2.6, 0.6),
		CFrame = spot * CFrame.new(0, 2.7, -0.85),
		PaletteRole = "Straw",
		PaletteShade = -0.2,
		Material = Enum.Material.Fabric,
	}, keeper)
	for _, side in { -1, 1 } do
		decor({
			Name = "Arm",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 2.4, 0.8),
			CFrame = spot
				* CFrame.new(side * 1.45, 3.4, -0.5)
				* CFrame.Angles(math.rad(35), 0, math.rad(side * 14)),
			PaletteRole = "Cloth",
			PaletteShade = 0.15,
			Material = Enum.Material.Fabric,
		}, keeper)
	end
	local headCf = spot * CFrame.new(0, 6.3, 0)
	local headSize = Vector3.new(3.3, 2.8, 3.3)
	local head, ovals =
		Kit.pumpkinBody(headCf, headSize, 3, { PaletteRole = "Orange" }, keeper, hubCfg.Palette)
	head.Name = "Head"
	Kit.carvedFace(headCf, headSize, color("Glow"), keeper, { Ovals = ovals })
	part({
		Name = "Hat",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 4.8, 4.8),
		CFrame = upright(spot * CFrame.new(0, 7.6, 0) * CFrame.Angles(math.rad(-6), 0, 0)),
		PaletteRole = "Straw",
		Material = Enum.Material.Fabric,
	}, keeper)
	paint.roundedDecor({
		Name = "HatCrown",
		Size = Vector3.new(2.4, 1.2, 2.4),
		CFrame = spot * CFrame.new(0, 8.3, 0.05) * CFrame.Angles(math.rad(-6), 0, 0),
		PaletteRole = "Straw",
		Material = Enum.Material.Fabric,
	}, keeper)
	decor({
		Name = "HatBand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 2.5, 2.5),
		CFrame = upright(spot * CFrame.new(0, 7.95, 0.03) * CFrame.Angles(math.rad(-6), 0, 0)),
		PaletteRole = "Orange",
	}, keeper)
	keeper.PrimaryPart = head
	return keeper
end

-- Voting Board ----------------------------------------------------------------------------------

function NpcLooks.Board(cf: CFrame, m: Model, text: string): (BasePart, BasePart)
	for _, x in { -6.3, 6.3 } do
		part({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12.4, 0.9, 0.9),
			CFrame = upright(cf * CFrame.new(x, 6.2, 0.3)),
			PaletteRole = "Wood",
			PaletteShade = 0.15,
			Material = Enum.Material.Wood,
		}, m)
		Props.Pumpkin(
			paint,
			cf * CFrame.new(x, 12.4, 0.3),
			1.3,
			m,
			{ Ribs = 3, Leaf = false, Solid = false }
		)
	end
	local backing = part({
		Name = "Backing",
		Size = Vector3.new(12.2, 8.6, 0.6),
		CFrame = cf * CFrame.new(0, 7, 0),
		PaletteRole = "Wood",
		Material = Enum.Material.WoodPlanks,
	}, m)
	sign(backing, text, color("Orange"), Enum.NormalId.Back) -- readable from behind too
	-- The Screen's front face carries the live vote SurfaceGui (rendered by each client).
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(11, 7.4, 0.2),
		CFrame = cf * CFrame.new(0, 6.9, -0.4),
		PaletteRole = "Dark",
	}, m)
	local header = decor({
		Name = "Header",
		Size = Vector3.new(13.2, 1.5, 0.8),
		CFrame = cf * CFrame.new(0, 11.9, 0),
		PaletteRole = "Purple",
		PaletteShade = 0.2,
		Material = Enum.Material.WoodPlanks,
	}, m)
	sign(header, text, color("Orange"))
	-- A little gable roof.
	for _, side in { -1, 1 } do
		wedge({
			Name = "Roof",
			Size = Vector3.new(14.2, 1.3, 1.1),
			CFrame = cf
				* CFrame.new(0, 13.3, side * 0.55)
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			PaletteRole = "Purple",
			PaletteShade = 0.35,
			Material = Enum.Material.Slate,
		}, m)
	end
	Props.JackOLantern(paint, cf * CFrame.new(-7.8, 0, -1), 1.8, m, { Light = true })
	Props.JackOLantern(paint, cf * CFrame.new(7.8, 0, -1), 1.6, m)
	return screen, header
end

-- Leaderboard Gravestone ----------------------------------------------------------------------------

function NpcLooks.Gravestone(cf: CFrame, m: Model): (BasePart, BasePart)
	local stone = { PaletteRole = "Stone", Material = Enum.Material.Slate }
	local function with(extra: { [string]: any }): { [string]: any }
		local p = table.clone(stone) :: { [string]: any }
		for key, value in extra do
			p[key] = value
		end
		return p
	end
	part(
		with({
			Name = "Plinth",
			Size = Vector3.new(13.5, 1, 4.2),
			CFrame = cf * CFrame.new(0, 0.5, 0),
			PaletteShade = 0.3,
		}),
		m
	)
	part(
		with({
			Name = "Step",
			Size = Vector3.new(11.6, 0.6, 3),
			CFrame = cf * CFrame.new(0, 1.3, 0),
			PaletteShade = 0.18,
		}),
		m
	)
	local slab = part(
		with({ Name = "Slab", Size = Vector3.new(10, 9, 1.6), CFrame = cf * CFrame.new(0, 6.1, 0) }),
		m
	)
	part(
		with({
			Name = "Arch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 10, 10),
			CFrame = cf * CFrame.new(0, 10.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		}),
		m
	)
	decor(
		with({
			Name = "ArchRim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.3, 10.9, 10.9),
			CFrame = cf * CFrame.new(0, 10.6, 0.25) * CFrame.Angles(0, math.rad(90), 0),
			PaletteShade = 0.15,
		}),
		m
	)
	for _, x in { -5.6, 5.6 } do
		paint.rounded(
			with({
				Name = "Pillar",
				Size = Vector3.new(1.4, 9.6, 1.4),
				CFrame = cf * CFrame.new(x, 6.4, -0.1),
				PaletteShade = 0.1,
			}),
			m
		)
		Props.Candle(paint, cf * CFrame.new(x, 11.2, -0.1), 1.4, m, { Light = x < 0 })
	end
	-- The Screen's front face carries the top-collectors SurfaceGui (filled by the server).
	local screen = part(
		with({
			Name = "Screen",
			Size = Vector3.new(8.4, 10.4, 0.2),
			CFrame = cf * CFrame.new(0, 7.9, -0.85),
			PaletteShade = 0.45,
		}),
		m
	)
	-- A golden crown on top: the best collectors.
	decor({
		Name = "Crown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 2.6, 2.6),
		CFrame = upright(cf * CFrame.new(0, 16, 0)),
		PaletteRole = "Gold",
		Material = Enum.Material.Metal,
	}, m)
	for i = -1, 1 do
		decor({
			Name = "CrownPoint",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = cf * CFrame.new(i * 0.9, 16.8 + (if i == 0 then 0.2 else 0), -0.9),
			PaletteRole = "Gold",
			Material = Enum.Material.Neon,
		}, m)
	end
	Props.Cobweb(paint, cf * CFrame.new(-4.6, 12.6, -0.95), hubCfg.Cobwebs.Size * 0.6, m)
	Props.Pumpkin(paint, cf * CFrame.new(5.6, 1, -2.4), 1.6, m, { Solid = false })
	return screen, slab
end

-- Photo Spot ------------------------------------------------------------------------------------------

function NpcLooks.PhotoSpot(cf: CFrame, m: Model): BasePart
	local cfg = hubCfg.PhotoSpot
	-- A real cylinder (round to bump into), not a rounded mesh (that would bump like a box).
	local stage = part({
		Name = "Stage",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = upright(cf * CFrame.new(0, 1.5, 0)),
		PaletteRole = "Path",
		PaletteShade = 0.1,
		Material = Enum.Material.Slate,
	}, m)
	decor({
		Name = "GlowRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 14.5, 14.5),
		CFrame = upright(cf * CFrame.new(0, 1.55, 0)),
		PaletteRole = "Teal",
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	}, m)
	decor({
		Name = "Rug",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 11, 11),
		CFrame = upright(cf * CFrame.new(0, 2.03, 0)),
		PaletteRole = "Purple",
		Material = Enum.Material.Fabric,
	}, m)
	-- A big pale moon behind, with a glowing halo and bats flying across it.
	local moonCf = cf * CFrame.new(0, 9, 6.6)
	part({
		Name = "Moon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 12.5, 12.5),
		CFrame = moonCf * CFrame.Angles(0, math.rad(90), 0),
		PaletteRole = "Bone",
		PaletteShade = -0.02,
	}, m)
	decor({
		Name = "MoonHalo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 13.5, 13.5),
		CFrame = moonCf * CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.rad(90), 0),
		PaletteRole = "Glow",
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	}, m)
	-- A wooden back, so from behind it looks like a painted cut-out.
	decor({
		Name = "MoonBack",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 13.8, 13.8),
		CFrame = moonCf * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0),
		PaletteRole = "Wood",
		PaletteShade = 0.3,
		Material = Enum.Material.WoodPlanks,
	}, m)
	for i, spot in
		{ Vector3.new(-2.6, 2.4, 0), Vector3.new(2.8, 0.8, 0), Vector3.new(0.4, -2.2, 0) }
	do
		Props.Bat(paint, moonCf * CFrame.new(spot.X, spot.Y, -0.5), 1.6 - i * 0.2, m, Random.new(i))
	end
	local banner = decor({
		Name = "Banner",
		Size = Vector3.new(12, 2, 0.4),
		CFrame = cf * CFrame.new(0, 3.2, 6.3),
		PaletteRole = "Wood",
		PaletteShade = 0.1,
		Material = Enum.Material.WoodPlanks,
	}, m)
	Kit.surfaceText(banner, cfg.Sign, color("Orange"))
	-- Hay bales with jack-o-lanterns on both sides.
	for _, side in { -1, 1 } do
		local base = cf
			* CFrame.new(side * 7.6, 0, 4.2)
			* CFrame.Angles(0, math.rad(90 + side * 20), 0)
		Props.HayBale(paint, base, 2.6, m)
		Props.JackOLantern(
			paint,
			base * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(-90 - side * 20), 0),
			2.4,
			m,
			{
				Light = side < 0,
			}
		)
		Props.Pumpkin(paint, cf * CFrame.new(side * 7.2, 0, 0.6), 1.6, m, { Solid = false })
	end
	return stage
end

return NpcLooks
