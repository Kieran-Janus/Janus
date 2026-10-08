--!strict
--[[
	Lobby section: the Ready area, right in front of the spawn. Players walk in under the pumpkin
	arch and stand on the glowing rune circle to join the next round (ReadyService checks who
	is standing on parts tagged ReadyPad).

	Workspace.Hub.ReadyArea
	  ReadyPad       the round stone (tag ReadyPad). Move, resize or copy it in Studio and it
	                 keeps working; the glowing runes on top are only decoration.
	  Runes          the glowing rings, runes and the pumpkin in the middle, and their light
	  Stones         little standing stones round the circle, open on the arch side
	  ReadyPadArch   the arch over the entrance (prop "ReadyPadArch"): stone pillars with
	                 jack-o-lanterns, pumpkins along the top and the "PLAY!" banner
	  Pumpkins       a few pumpkins and candles by the entrance
	  ReadySign      invisible part (tag ReadySign) holding the floating "READY x / y" sign.
	                 src/client/ReadySign.luau fills in the numbers from the ReplicatedStorage
	                 attributes ReadyCount, ReadyNeeded and State.

	Where: Config.Lobby.Zones.ReadyArea; the arch faces away from the middle of the hub
	(towards the spawn). Look: Config.Hub.ReadyArea. Switched off (Config.Features.ReadyPad =
	false): only an empty ReadyArea model is made.

	ReadyArea.Build(hub, zone) -> Model    the whole area
	ReadyArea.Repair(hub, zone) -> Model   only the pad (and the sign, if that is gone too),
	                                       for a saved hub that lost its pad (HubService)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Parent.Build.Props)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local ReadyArea = {}

local cfg = Config.Hub.ReadyArea
local paint = Kit.painter(Config.Hub.Palette)
local part = paint.part
local decor = paint.decor
local color = paint.color

-- A flat round slab on `centre`, its top `top` studs above it.
local function disc(
	name: string,
	centre: CFrame,
	diameter: number,
	top: number,
	thickness: number,
	props: Kit.Props,
	parent: Instance
): Part
	local p = table.clone(props)
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter)
	p.CFrame = Kit.upright(centre * CFrame.new(0, top - thickness / 2, 0))
	p.CastShadow = false
	return decor(p, parent)
end

-- The round pad players stand on, with its glowing runes.
local function buildPad(parent: Instance, base: CFrame): BasePart
	local size: Vector3 = cfg.PadSize
	local d = math.min(size.X, size.Z)
	local pad = part({
		Name = "ReadyPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size.Y, d, d),
		CFrame = Kit.upright(base * CFrame.new(0, size.Y / 2, 0)),
		PaletteRole = "Stone",
		PaletteShade = 0.35,
		Material = Enum.Material.Slate,
	}, parent)
	CollectionService:AddTag(pad, Tags.ReadyPad)

	local runes = Kit.group("Runes", parent)
	local glow = cfg.GlowRole
	local top = size.Y
	disc("PadRim", base, d + 1.4, top - 0.25, 0.5, {
		PaletteRole = "Path",
		PaletteShade = 0.35,
		Material = Enum.Material.Slate,
	}, runes)
	local ring = disc("GlowRing", base, d - 0.8, top + 0.03, 0.06, {
		PaletteRole = glow,
		Material = Enum.Material.Neon,
	}, runes)
	disc("PadCentre", base, d - 1.9, top + 0.06, 0.06, {
		PaletteRole = "Stone",
		PaletteShade = 0.25,
		Material = Enum.Material.Slate,
	}, runes)
	local inner = d * 0.56
	disc("InnerRing", base, inner, top + 0.09, 0.06, {
		PaletteRole = glow,
		Material = Enum.Material.Neon,
	}, runes)
	disc("InnerCentre", base, inner - 0.9, top + 0.12, 0.06, {
		PaletteRole = "Stone",
		PaletteShade = 0.3,
		Material = Enum.Material.Slate,
	}, runes)
	-- Runes between the two rings: diamonds and bars, in turn.
	local runeRadius = ((d - 1.9) / 2 + inner / 2) / 2
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local spot = base * CFrame.Angles(0, a, 0) * CFrame.new(0, top + 0.1, -runeRadius)
		decor({
			Name = "Rune",
			Size = if i % 2 == 0 then Vector3.new(0.9, 0.06, 0.9) else Vector3.new(0.3, 0.06, 1.3),
			CFrame = if i % 2 == 0 then spot * CFrame.Angles(0, math.rad(45), 0) else spot,
			PaletteRole = glow,
			Material = Enum.Material.Neon,
		}, runes)
	end
	-- A glowing pumpkin in the middle.
	decor({
		Name = "Emblem",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 0.08, 2.7),
		CFrame = base * CFrame.new(0, top + 0.15, 0.2),
		PaletteRole = "Orange",
		Material = Enum.Material.Neon,
	}, runes)
	decor({
		Name = "EmblemStem",
		Size = Vector3.new(0.5, 0.08, 0.8),
		CFrame = base * CFrame.new(0, top + 0.15, -1.4),
		PaletteRole = "Green",
		Material = Enum.Material.Neon,
	}, runes)
	Kit.light(ring, color(glow), 26, 1.6, false):SetAttribute("PaletteRole", glow)

	-- Little sparks rising from the ring.
	local sparkles =
		Kit.holder("Sparkles", base * CFrame.new(0, top + 0.5, 0), Vector3.new(d, 0.2, d), runes)
	Kit.particles(sparkles, {
		Rate = 10,
		Color = ColorSequence.new(color(glow)),
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

-- Little standing stones round the circle, leaving the arch side open.
local function buildStones(parent: Instance, base: CFrame)
	local count = cfg.Stones
	if count < 2 then
		return
	end
	local stones = Kit.group("Stones", parent)
	local d = math.min(cfg.PadSize.X, cfg.PadSize.Z)
	local radius = d / 2 + 1.35
	local gap = math.rad(cfg.StoneGap)
	for i = 0, count - 1 do
		-- Angle from the arch side (+Z), round the far side and back.
		local a = gap / 2 + i * (math.pi * 2 - gap) / (count - 1)
		local h = if i % 2 == 0 then 2.3 else 1.6
		local cf = base * CFrame.new(math.sin(a) * radius, 0, math.cos(a) * radius)
		local look = CFrame.lookAt(cf.Position, base.Position)
		paint.rounded({
			Name = "Stone",
			Size = Vector3.new(1.35, h, 1.35),
			CFrame = look
				* CFrame.new(0, h / 2, 0)
				* CFrame.Angles(math.rad((i % 3 - 1) * 4), 0, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.15 + (i % 3) * 0.05,
			Material = Enum.Material.Slate,
		}, stones)
		if i % 2 == 0 then
			decor({
				Name = "StoneRune",
				Size = Vector3.new(0.35, 0.5, 0.06),
				CFrame = look * CFrame.new(0, h * 0.6, -0.66),
				PaletteRole = cfg.GlowRole,
				Material = Enum.Material.Neon,
			}, stones)
		end
	end
end

-- An arch over the entrance: stone pillars with jack-o-lanterns, pumpkins along an iron band.
local function buildArch(parent: Instance, cf: CFrame): Model
	local arch = Kit.model("ReadyPadArch", parent)
	local halfSpan = cfg.ArchWidth / 2 + 0.9
	local pillarTop = math.max(cfg.ArchHeight - halfSpan, 4)
	for _, side in { -1, 1 } do
		local foot = cf * CFrame.new(side * halfSpan, 0, 0)
		paint.rounded({
			Name = "PillarBase",
			Size = Vector3.new(2.6, 1.2, 2.6),
			CFrame = foot * CFrame.new(0, 0.6, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.25,
			Material = Enum.Material.Slate,
		}, arch)
		paint.rounded({
			Name = "Pillar",
			Size = Vector3.new(1.9, pillarTop - 1.8, 1.9),
			CFrame = foot * CFrame.new(0, 1.2 + (pillarTop - 1.8) / 2, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.08,
			Material = Enum.Material.Slate,
		}, arch)
		paint.rounded({
			Name = "PillarCap",
			Size = Vector3.new(2.7, 0.7, 2.7),
			CFrame = foot * CFrame.new(0, pillarTop - 0.35, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.25,
			Material = Enum.Material.Slate,
		}, arch)
		Props.JackOLantern(paint, foot * CFrame.new(0, pillarTop, 0), cfg.LanternSize, arch, {
			Light = true,
		})
	end
	-- The curved iron band: short straight pieces round a half circle.
	local segments = 12
	local radius = halfSpan
	local function point(t: number): Vector3
		local a = math.pi * t
		return (cf * CFrame.new(math.cos(a) * radius, pillarTop + math.sin(a) * radius * 0.7, 0)).Position
	end
	for i = 0, segments - 1 do
		local a, b = point(i / segments), point((i + 1) / segments)
		decor({
			Name = "ArchBand",
			Size = Vector3.new(0.8, 0.8, (b - a).Magnitude + 0.3),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, arch)
	end
	local count = cfg.ArchPumpkins
	for i = 1, count do
		local p = point(i / (count + 1))
		Props.Pumpkin(paint, CFrame.new(p + Vector3.new(0, 0.35, 0)) * cf.Rotation, 1.15, arch, {
			Ribs = 3,
			Solid = false,
			Role = if i % 2 == 0 then "Purple" else "Orange",
			Shade = if i % 2 == 0 then -0.15 else 0,
		})
	end
	if cfg.Banner ~= "" then
		local top = point(0.5)
		local banner = decor({
			Name = "Banner",
			Size = Vector3.new(cfg.ArchWidth * 0.62, 2.2, 0.15),
			CFrame = CFrame.new(top - Vector3.new(0, 2.1, 0)) * cf.Rotation,
			PaletteRole = "Purple",
			Material = Enum.Material.Fabric,
		}, arch)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Kit.surfaceText(banner, cfg.Banner, color("Orange"), face)
			local label = gui:FindFirstChild("Text")
			if label and label:IsA("TextLabel") then
				label.Font = Enum.Font.FredokaOne
				label.TextStrokeTransparency = 0.3
			end
		end
		for _, side in { -1, 1 } do
			decor({
				Name = "BannerRope",
				Size = Vector3.new(0.08, 1.2, 0.08),
				CFrame = CFrame.new(
					top + cf.RightVector * side * cfg.ArchWidth * 0.28 - Vector3.new(0, 0.6, 0)
				),
				PaletteRole = "Bone",
			}, arch)
		end
	end
	return arch
end

-- The floating "READY x / y" sign above the arch (the client keeps its text up to date).
local function buildSign(parent: Instance, base: CFrame): BasePart
	local d = math.min(cfg.PadSize.X, cfg.PadSize.Z)
	local anchor = Kit.holder(
		"ReadySign",
		base * CFrame.new(0, cfg.Sign.Height, d / 2 + 1.6),
		Vector3.one,
		parent
	)
	CollectionService:AddTag(anchor, Tags.ReadySign)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	-- Sized in studs like a real sign, plus a few pixels so it stays readable from afar.
	gui.Size = UDim2.new(cfg.Sign.Size.X, 120, cfg.Sign.Size.Y, 44)
	gui.MaxDistance = cfg.Sign.MaxDistance
	gui.LightInfluence = 0
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "Board"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color("Dark")
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color(cfg.GlowRole)
	stroke.Thickness = 4
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(color("Purple", 0.35), color("Dark"))
	gradient.Rotation = 90
	gradient.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.Size = UDim2.fromScale(0.92, 0.6)
	title.Font = Enum.Font.FredokaOne
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

function ReadyArea.Build(hub: Instance, zone: Zone): Instance
	local area = Kit.group("ReadyArea", hub)
	if not Config.Features.ReadyPad then
		return area
	end
	local base = zone.CFrame
	buildPad(area, base)
	buildStones(area, base)

	-- The arch stands on the side away from the middle of the hub, facing the spawn.
	local d = math.min(cfg.PadSize.X, cfg.PadSize.Z)
	local archCf = base * CFrame.new(0, 0, d / 2 + 1.6) * CFrame.Angles(0, math.pi, 0)
	Kit.prop("ReadyPadArch", archCf, area, cfg.ArchHeight + cfg.LanternSize, function()
		return buildArch(area, archCf)
	end)

	-- Pumpkins and candles by the entrance.
	local extras = Kit.group("Pumpkins", area)
	local halfSpan = cfg.ArchWidth / 2 + 0.9
	for _, side in { -1, 1 } do
		local spot = archCf * CFrame.new(side * (halfSpan + 2.4), 0, 0.6)
		Props.Pumpkin(paint, spot * CFrame.Angles(0, side * 0.5, 0), 2.2, extras)
		Props.Pumpkin(paint, spot * CFrame.new(side * 1.6, 0, 1.4), 1.3, extras, { Solid = false })
		Props.Candle(paint, spot * CFrame.new(side * -0.4, 0, -1.9), 1.8, extras)
	end

	buildSign(area, base)
	return area
end

function ReadyArea.Repair(hub: Instance, zone: Zone): Instance
	local existing = hub:FindFirstChild("ReadyArea")
	local area = if existing and Kit.isGroup(existing)
		then existing
		else Kit.group("ReadyArea", hub)
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
