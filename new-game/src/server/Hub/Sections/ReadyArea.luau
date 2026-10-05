--!strict
--[[
	Lobby section: the Ready area. Players stand on the pad to join the next round
	(ReadyService checks who is standing on parts tagged ReadyPad).

	Workspace.Hub.ReadyArea
	  ReadyPad       the stone platform (tag ReadyPad). Move, resize or copy it in Studio and
	                 it keeps working; the glowing ring on top is only decoration.
	  GlowRing, PadCentre, Sparkles   the glowing ring and its light
	  ReadyPadArch   the jack-o-lantern arch over the front (prop "ReadyPadArch")
	  Lanterns       jack-o-lanterns along the sides
	  ReadySign      invisible part (tag ReadySign) holding the floating "READY x / y" sign.
	                 src/client/ReadySign.luau fills in the numbers from the ReplicatedStorage
	                 attributes ReadyCount, ReadyNeeded and State.

	Where: Config.Lobby.Zones.ReadyArea. Look: Config.Hub.ReadyArea. Switched off
	(Config.Features.ReadyPad = false): only an empty ReadyArea model is made.

	ReadyArea.Build(hub, zone) -> Model    the whole area
	ReadyArea.Repair(hub, zone) -> Model   only the pad (and the sign, if that is gone too),
	                                       for a saved hub that lost its pad (HubService)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local ReadyArea = {}

local cfg = Config.Hub.ReadyArea
local paint = Kit.painter(Config.Hub.Palette)
local part = paint.part
local decor = paint.decor
local color = paint.color

local function jackOLantern(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("JackOLantern", cf, parent, size * 1.2, function()
		return Kit.jackOLantern(cf, size, Config.Hub.Palette :: any, parent)
	end)
end

-- The pad players stand on, with its glowing ring.
local function buildPad(parent: Instance, base: CFrame): BasePart
	local size: Vector3 = cfg.PadSize
	local top = base * CFrame.new(0, size.Y, 0)
	local pad = part({
		Name = "ReadyPad",
		Size = size,
		CFrame = base * CFrame.new(0, size.Y / 2, 0),
		PaletteRole = "Stone",
		PaletteShade = 0.35,
		Material = Enum.Material.Slate,
	}, parent)
	CollectionService:AddTag(pad, Tags.ReadyPad)

	local diameter = math.min(size.X, size.Z) - 1.5
	local ring = decor({
		Name = "GlowRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, diameter, diameter),
		CFrame = Kit.upright(top * CFrame.new(0, 0.06, 0)),
		PaletteRole = cfg.GlowRole,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	}, parent)
	decor({
		Name = "PadCentre",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, diameter - 2.4, diameter - 2.4),
		CFrame = Kit.upright(top * CFrame.new(0, 0.08, 0)),
		PaletteRole = "Stone",
		PaletteShade = 0.15,
		Material = Enum.Material.Slate,
	}, parent)
	Kit.light(ring, color(cfg.GlowRole), 24, 1.5, false):SetAttribute("PaletteRole", cfg.GlowRole)

	-- Little sparks rising from the ring.
	local sparkles = Kit.holder(
		"Sparkles",
		top * CFrame.new(0, 0.5, 0),
		Vector3.new(diameter, 0.2, diameter),
		parent
	)
	Kit.particles(sparkles, {
		Rate = 8,
		Color = ColorSequence.new(color(cfg.GlowRole)),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(8, 8),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	return pad
end

-- An arch of jack-o-lanterns on two stone pillars, over the front edge of the pad.
local function buildArch(parent: Instance, cf: CFrame, halfWidth: number): Model
	local arch = Kit.model("ReadyPadArch", parent)
	local radius = halfWidth
	local pillarHeight = math.max(cfg.ArchHeight - radius, 4)
	for _, side in { -1, 1 } do
		part({
			Name = "Pillar",
			Size = Vector3.new(1.6, pillarHeight, 1.6),
			CFrame = cf * CFrame.new(side * radius, pillarHeight / 2, 0),
			PaletteRole = "Stone",
			Material = Enum.Material.Slate,
		}, arch)
	end
	-- The curved band: short straight pieces around a half circle.
	local segments = 12
	local function point(t: number): Vector3
		local a = math.pi * t
		return (cf * CFrame.new(math.cos(a) * radius, pillarHeight + math.sin(a) * radius, 0)).Position
	end
	for i = 0, segments - 1 do
		local a, b = point(i / segments), point((i + 1) / segments)
		decor({
			Name = "ArchBand",
			Size = Vector3.new(0.9, 0.9, (b - a).Magnitude + 0.3),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			PaletteRole = "Iron",
		}, arch)
	end
	local count = math.max(cfg.ArchLanterns, 2)
	local size = cfg.LanternSize
	for i = 0, count - 1 do
		local p = point(i / (count - 1))
		local lanternCf = CFrame.new(p - Vector3.new(0, size / 2, 0)) * cf.Rotation
		jackOLantern(lanternCf, size, arch)
	end
	return arch
end

-- The floating "READY x / y" sign (the client keeps its text up to date).
local function buildSign(parent: Instance, base: CFrame): BasePart
	local size: Vector3 = cfg.PadSize
	local anchor = Kit.holder(
		"ReadySign",
		base * CFrame.new(0, cfg.Sign.Height, -size.Z / 2),
		Vector3.one,
		parent
	)
	CollectionService:AddTag(anchor, Tags.ReadySign)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	-- Sized in studs like a real sign, plus a few pixels so it stays readable from afar.
	gui.Size = UDim2.new(16, 120, 6, 44)
	gui.MaxDistance = cfg.Sign.MaxDistance
	gui.LightInfluence = 0
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "Board"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color("Dark")
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color(cfg.GlowRole)
	stroke.Thickness = 3
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.Size = UDim2.fromScale(0.92, 0.6)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = color(cfg.GlowRole)
	title.TextStrokeTransparency = 0.3
	title.Text = cfg.Sign.TitleWaiting
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.06, 0.64)
	status.Size = UDim2.fromScale(0.88, 0.3)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = color("Bone")
	status.TextStrokeTransparency = 0.4
	status.Text = Config.Lobby.Ready.PadText
	status.Parent = frame
	return anchor
end

function ReadyArea.Build(hub: Model, zone: Zone): Model
	local area = Kit.model("ReadyArea", hub)
	if not Config.Features.ReadyPad then
		return area
	end
	local base = zone.CFrame
	local size: Vector3 = cfg.PadSize
	buildPad(area, base)

	local halfWidth = size.X / 2 + 1
	local archCf = base * CFrame.new(0, 0, -size.Z / 2 - 0.4)
	Kit.prop("ReadyPadArch", archCf, area, cfg.ArchHeight + cfg.LanternSize, function()
		return buildArch(area, archCf, halfWidth)
	end)

	local lanterns = Kit.model("Lanterns", area)
	local n = cfg.SideLanterns
	for i = 0, n - 1 do
		local t = if n > 1 then i / (n - 1) else 0.5
		local z = (-size.Z / 2 + 3) + t * (size.Z - 4)
		for _, side in { -1, 1 } do
			jackOLantern(base * CFrame.new(side * halfWidth, 0, z), cfg.LanternSize, lanterns)
		end
	end

	buildSign(area, base)
	return area
end

function ReadyArea.Repair(hub: Model, zone: Zone): Model
	local existing = hub:FindFirstChild("ReadyArea")
	local area = if existing and existing:IsA("Model")
		then existing
		else Kit.model("ReadyArea", hub)
	buildPad(area, zone.CFrame)
	local hasSign = false
	for _, sign in CollectionService:GetTagged(Tags.ReadySign) do
		if sign:IsDescendantOf(hub) then
			hasSign = true
			break
		end
	end
	if not hasSign then
		buildSign(area, zone.CFrame)
	end
	return area
end

return ReadyArea
