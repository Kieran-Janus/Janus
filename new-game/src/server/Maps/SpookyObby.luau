--!strict
--[[
	"Spooky Obby", the course of the Spooky Obby mode (src/server/Modes/ObbyRace.luau), built
	from Config.Maps.List[SpookyObby] (src/shared/Config/Maps/SpookyObby.luau: Course, Colors,
	Layout). A graveyard plaza floating in a misty void, then the course:

	  Floor              the start plaza (MapBase), with the spawns and a low railing open
	                     towards the course, lampposts and the START arch (prop "ObbyArch")
	  Course
	    StepNN_<Look>    one Model per line of Course. The part you stand on is the first
	                     child ("Lid", "Stone", "Slab", "Rail", "Disc", "Pad"):
	                       Pumpkin   lid + look "ParkourPumpkin" (swappable, the lid stays)
	                       Grave     stone + look "Gravestone" (swappable, the stone stays)
	                       Coffin    slab + look "Coffin" (swappable, the slab stays)
	                       Sweeper   a square platform with a pillar and the ghost sweeper
	                                 bars (tag ObbySweeper; a Hard-only Cross bar)
	                       Checkpoint  round pad, tag ObbyCheckpoint, attribute Index
	                       Finish    round pad, tag ObbyFinish, the trophy pumpkin (prop
	                                 "ParkourTrophy") under the FINISH arch ("ObbyArch")
	                       Goo       green goo, tag ObbyHazard (walk-through: the mode decides)
	    Pieces with Only = "Easy"/"Hard" are tagged ObbyVariant (attribute Only): the mode removes
	    the other difficulty's pieces when the round starts.
	  HauntedTree        the big dead tree beside the branch climb (prop "DeadTree")
	  Void               the glowing mist far below and little graveyard islands (decoration)

	Built the same way every time (def.Seed). ObbyRace finds the working parts by their tags,
	so they can be moved, resized or copied in Studio (bake: Bake.Map("SpookyObby")).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ObbyRaceRules = require(ReplicatedStorage.Shared.ObbyRaceRules)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local MapBase = require(script.Parent.MapBase)

type Step = ObbyRaceRules.Step

local SpookyObby = {}

local PARTS = ObbyRaceRules.Parts

local EPITAPHS = { "RIP", "BOO!", "Here lies\nMr. Bones", "Back\nsoon", "Gone\nbatty", "Hop on!" }

-- Helpers ------------------------------------------------------------------------------------

local function solid(props: Kit.Props, parent: Instance): Part
	return Kit.part(props, parent)
end

local function decor(props: Kit.Props, parent: Instance): Part
	return Kit.decor(props, parent)
end

-- A round slab lying flat, its middle at `cf`.
local function disc(
	name: string,
	cf: CFrame,
	diameter: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	collide: boolean,
	material: Enum.Material?
): Part
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = Kit.upright(cf),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}
	return if collide then solid(props, parent) else decor(props, parent)
end

local function lettering(target: BasePart, text: string, color: Color3, face: Enum.NormalId)
	local gui = Kit.surfaceText(target, text, color, face)
	local label = gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Font = Enum.Font.GothamBlack
		label.TextStrokeTransparency = 0.4
	end
end

local function tag(instance: Instance, name: string)
	CollectionService:AddTag(instance, name)
end

-- The flat (world) direction from step i to the next piece that is somewhere else.
local function facingFrom(frames: { CFrame }, course: { Step }, i: number): Vector3
	local here = frames[i].Position
	for j = i + 1, #course do
		local d = frames[j].Position - here
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude > 1 and course[j].Kind ~= "Hazard" then
			return flat.Unit
		end
	end
	local look = frames[i].LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

-- Pieces -----------------------------------------------------------------------------------------

type Builder = (top: CFrame, size: Vector3, step: Step, m: Model, ctx: any) -> BasePart

local builders: { [string]: Builder } = {}

-- A pumpkin you land on: a flat lid on top (the working part) and the round body as a look
-- (prop "ParkourPumpkin", the same name as the lobby parkour's pumpkins).
builders.Pumpkin = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local lidWidth = size.X * Config.Parkour.Look.PumpkinTop
	local lid = disc("Lid", top * CFrame.new(0, -0.3, 0), lidWidth, 0.6, colors.Pumpkin, m, true)
	-- An invisible solid core under the lid: you bump into the pumpkin, not walk through it.
	local coreHeight = math.max(size.Y - 0.8, 0.5)
	local core = disc(
		"Core",
		top * CFrame.new(0, -0.6 - coreHeight / 2, 0),
		size.X * 0.88,
		coreHeight,
		colors.Pumpkin,
		m,
		true
	)
	core.Transparency = 1
	Kit.look("ParkourPumpkin", lid, top * CFrame.new(0, -size.Y, 0), size.Y, function()
		local body = Kit.model("ParkourPumpkin", lid)
		local center = top * CFrame.new(0, -size.Y / 2 + 0.25, 0)
		local main = decor({
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size.X * 0.92, size.Y, size.Z * 0.92),
			CFrame = center,
			Color = colors.Pumpkin,
		}, body)
		for i = 0, 3 do
			decor({
				Name = "Rib",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size.X, size.Y * 0.97, size.Z * 0.55),
				CFrame = center * CFrame.Angles(0, math.rad(i * 45), 0),
				Color = colors.Pumpkin:Lerp(Color3.new(0, 0, 0), if i % 2 == 0 then 0.12 else 0.04),
			}, body)
		end
		decor({
			Name = "Stem",
			Size = Vector3.new(0.7, 1.2, 0.7),
			CFrame = top * CFrame.new(0, 0.5, -lidWidth / 2 + 0.6) * CFrame.Angles(0, 0, 0.3),
			Color = colors.PumpkinStem,
		}, body)
		body.PrimaryPart = main
		return body
	end)
	return lid
end

-- A gravestone you hop along: the stone is the working part, its look prop "Gravestone".
builders.Grave = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local stone = solid({
		Name = "Stone",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	local words = EPITAPHS[(ctx.Index % #EPITAPHS) + 1]
	Kit.look("Gravestone", stone, top * CFrame.new(0, -size.Y, 0), size.Y, function()
		local look = Kit.model("Gravestone", stone)
		-- A darker plaque with words on the side facing the plaza, and moss at its foot.
		local plaque = decor({
			Name = "Plaque",
			Size = Vector3.new(size.X * 0.7, size.Y * 0.4, 0.1),
			CFrame = top * CFrame.new(0, -size.Y * 0.35, size.Z / 2 + 0.05),
			Color = colors.Stone:Lerp(Color3.new(0, 0, 0), 0.35),
			Material = Enum.Material.Slate,
		}, look)
		lettering(plaque, words, colors.Text, Enum.NormalId.Back)
		decor({
			Name = "Moss",
			Size = Vector3.new(size.X + 0.3, 0.8, size.Z + 0.3),
			CFrame = top * CFrame.new(0, -size.Y + 0.4, 0),
			Color = colors.Moss,
			Material = Enum.Material.Grass,
		}, look)
		look.PrimaryPart = plaque
		return look
	end)
	return stone
end

-- A coffin lying along the course: the slab is the working part, its look prop "Coffin".
builders.Coffin = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local slab = solid({
		Name = "Slab",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Coffin,
		Material = Enum.Material.Wood,
	}, m)
	Kit.look("Coffin", slab, top * CFrame.new(0, -size.Y, 0), size.Y, function()
		local look = Kit.model("Coffin", slab)
		-- A gold trim round the lid and a cross on top (flat, so you never trip on it).
		local trim = decor({
			Name = "Trim",
			Size = Vector3.new(size.X + 0.2, 0.3, size.Z + 0.2),
			CFrame = top * CFrame.new(0, -0.4, 0),
			Color = colors.CoffinTrim,
			Material = Enum.Material.Metal,
		}, look)
		decor({
			Name = "CrossLong",
			Size = Vector3.new(0.6, 0.05, size.Z * 0.5),
			CFrame = top * CFrame.new(0, 0.03, 0),
			Color = colors.CoffinTrim,
			Material = Enum.Material.Metal,
		}, look)
		decor({
			Name = "CrossShort",
			Size = Vector3.new(size.X * 0.55, 0.05, 0.6),
			CFrame = top * CFrame.new(0, 0.03, size.Z * 0.12),
			Color = colors.CoffinTrim,
			Material = Enum.Material.Metal,
		}, look)
		look.PrimaryPart = trim
		return look
	end)
	return slab
end

-- A plain stone slab with a glowing edge (the Hard-only stepping pad).
builders.Pad = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local slab = solid({
		Name = "Pad",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	decor({
		Name = "Glow",
		Size = Vector3.new(size.X - 0.8, 0.06, size.Z - 0.8),
		CFrame = top * CFrame.new(0, 0.03, 0),
		Color = colors.Ghost,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
	}, m)
	return slab
end

-- A square platform with a pillar in the middle and a ghost sweeper bar going round it (two
-- crossed bars on Hard). The bars are walk-through: ObbyRace decides who they hit, with the same
-- maths the screens use to turn them (src/shared/ObbyRaceRules.luau).
builders.Sweeper = function(top, size, step, m, ctx)
	local colors = ctx.Colors
	local slab = solid({
		Name = "Slab",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Plaza,
		Material = Enum.Material.Slate,
	}, m)
	for i = 0, 3 do
		decor({
			Name = "GlowEdge",
			Size = Vector3.new(size.X - 0.6, 0.08, 0.5),
			CFrame = top
				* CFrame.Angles(0, math.rad(i * 90), 0)
				* CFrame.new(0, 0.04, -size.Z / 2 + 0.5),
			Color = colors.Ghost,
			Material = Enum.Material.Neon,
		}, m)
	end
	Kit.rounded({
		Name = "Pillar",
		Size = Vector3.new(2.6, 4, 2.6),
		CFrame = top * CFrame.new(0, 2, 0),
		Color = colors.Stone,
		Material = Enum.Material.Slate,
	}, m)
	local orb = decor({
		Name = "GhostOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = top * CFrame.new(0, 4.8, 0),
		Color = colors.Ghost,
		Material = Enum.Material.Neon,
	}, m)
	Kit.light(orb, colors.Ghost, 16, 1.2, false)
	local sweeper = step.Sweeper or { Speed = 60, Length = size.X - 3 }
	local center = (top * CFrame.new(0, 1.4, 0)).Position
	local bars = { { Phase = 0, Only = nil :: string? } }
	if sweeper.Cross then
		table.insert(bars, { Phase = 90, Only = "Hard" })
	end
	for _, info in bars do
		local bar = decor({
			Name = if info.Only then "CrossBar" else "Bar",
			Size = Vector3.new(sweeper.Length, 1.2, 1),
			CFrame = ObbyRaceRules.SweeperCFrame(center, info.Phase),
			Color = colors.Ghost,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, m)
		bar.CastShadow = false
		tag(bar, Tags.ObbySweeper)
		bar:SetAttribute(PARTS.Center, center)
		bar:SetAttribute(PARTS.BaseSpeed, sweeper.Speed)
		bar:SetAttribute(PARTS.Speed, 0) -- still until the round's GO! (the mode sets it)
		bar:SetAttribute(PARTS.Phase, info.Phase)
		if info.Only then
			tag(bar, Tags.ObbyVariant)
			bar:SetAttribute(PARTS.Only, info.Only)
		end
	end
	return slab
end

-- A white candy cane rail with red stripes (comes in every length, so not a swappable prop).
builders.CandyRail = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local rail = solid({
		Name = "Rail",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Candy,
	}, m)
	local stripes = math.max(1, math.floor(size.Z / 2.5))
	for i = 1, stripes do
		local z = -size.Z / 2 + (i - 0.5) * size.Z / stripes
		decor({
			Name = "Stripe",
			Size = Vector3.new(size.X + 0.06, size.Y + 0.06, 0.7),
			CFrame = top * CFrame.new(0, -size.Y / 2, z) * CFrame.Angles(math.rad(20), 0, 0),
			Color = colors.CandyStripe,
		}, m)
	end
	return rail
end

-- A round wrapped sweet to land on, between the rails.
builders.CandyDrop = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local d = math.min(size.X, size.Z)
	local candy =
		disc("Disc", top * CFrame.new(0, -size.Y / 2, 0), d, size.Y, colors.CandyStripe, m, true)
	disc("Swirl", top * CFrame.new(0, 0.02, 0), d * 0.6, 0.06, colors.Candy, m, false)
	for _, side in { -1, 1 } do
		decor({
			Name = "Wrapper",
			Size = Vector3.new(2.2, size.Y * 0.8, 2.6),
			CFrame = top * CFrame.new(side * (d / 2 + 0.9), -size.Y / 2, 0),
			Color = colors.Candy,
			Transparency = 0.3,
		}, m)
	end
	return candy
end

-- A branch of the haunted tree: a wooden slab with a bough reaching back to the trunk.
builders.Branch = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local slab = solid({
		Name = "Slab",
		Size = size,
		CFrame = top * CFrame.new(0, -size.Y / 2, 0),
		Color = colors.Bark,
		Material = Enum.Material.Wood,
	}, m)
	local from = (top * CFrame.new(0, -size.Y / 2 - 0.4, 0)).Position
	local trunk: Vector3 = ctx.TrunkAt
	local to = Vector3.new(trunk.X, from.Y - 1.5, trunk.Z)
	local length = (to - from).Magnitude
	if length > 1 then
		decor({
			Name = "Bough",
			Size = Vector3.new(0.9, 0.9, length),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = colors.Bark,
			Material = Enum.Material.Wood,
		}, m)
	end
	-- A few purple leaves under the edge (never on top: nothing to trip on).
	decor({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size.X * 0.8, 1.4, size.Z * 0.8),
		CFrame = top * CFrame.new(0, -size.Y - 0.6, 0),
		Color = colors.Leaves,
		Material = Enum.Material.Grass,
	}, m)
	return slab
end

-- A round stone pad with a glowing ring. Returns the pad.
local function ringPad(top: CFrame, size: Vector3, ring: Color3, stone: Color3, m: Model): Part
	local diameter = math.min(size.X, size.Z)
	local pad = disc(
		"Pad",
		top * CFrame.new(0, -size.Y / 2, 0),
		diameter,
		size.Y,
		stone,
		m,
		true,
		Enum.Material.Slate
	)
	local glowRing = disc(
		"GlowRing",
		top * CFrame.new(0, 0.03, 0),
		diameter - 0.8,
		0.08,
		ring,
		m,
		false,
		Enum.Material.Neon
	)
	disc(
		"PadCentre",
		top * CFrame.new(0, 0.05, 0),
		diameter - 2.2,
		0.1,
		stone:Lerp(Color3.new(0, 0, 0), 0.15),
		m,
		false,
		Enum.Material.Slate
	)
	Kit.light(glowRing, ring, 16, 1.3, false)
	return pad
end

-- A checkpoint: a glowing pad with a signpost and a little lantern (prop "Lantern").
builders.Checkpoint = function(top, size, step, m, ctx)
	local colors = ctx.Colors
	local pad = ringPad(top, size, colors.Checkpoint, colors.Stone, m)
	tag(pad, Tags.ObbyCheckpoint)
	ctx.Checkpoints += 1
	pad:SetAttribute(PARTS.Index, ctx.Checkpoints)
	pad:SetAttribute(PARTS.Facing, ctx.Facing)
	-- The sign at the side of the pad, facing the players arriving.
	local radius = math.min(size.X, size.Z) / 2
	local facing: Vector3 = ctx.Facing
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local spot = top.Position + side * (radius - 0.8)
	local cf = CFrame.lookAt(spot, spot - facing)
	solid({
		Name = "SignPost",
		Size = Vector3.new(0.5, 6, 0.5),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = colors.Wood,
		Material = Enum.Material.Wood,
	}, m)
	local board = decor({
		Name = "Sign",
		Size = Vector3.new(5, 2.4, 0.3),
		CFrame = cf * CFrame.new(0, 5.2, -0.4),
		Color = colors.Wood,
		Material = Enum.Material.WoodPlanks,
	}, m)
	local words = if step.Label then "CHECKPOINT\n" .. step.Label else "CHECKPOINT"
	lettering(board, words, colors.Text, Enum.NormalId.Front)
	local lanternAt = cf * CFrame.new(0, 6, 0)
	Kit.prop("Lantern", lanternAt, m, 1.5, function()
		local lantern = Kit.model("Lantern", m)
		lantern.PrimaryPart = decor({
			Name = "Glass",
			Size = Vector3.new(0.9, 1.2, 0.9),
			CFrame = lanternAt * CFrame.new(0, 0.6, 0),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, lantern)
		decor({
			Name = "Cap",
			Size = Vector3.new(1.1, 0.3, 1.1),
			CFrame = lanternAt * CFrame.new(0, 1.35, 0),
			Color = colors.Iron,
		}, lantern)
		return lantern
	end, { Visual = true })
	return pad
end

-- An arch to walk under with a name board and two small jack-o'-lanterns (prop "ObbyArch").
local function arch(
	foot: CFrame,
	width: number,
	height: number,
	words: string,
	ctx: any,
	m: Instance
)
	local colors = ctx.Colors
	Kit.prop("ObbyArch", foot, m, height + 2, function()
		local model = Kit.model("ObbyArch", m)
		local first: BasePart? = nil
		for _, side in { -1, 1 } do
			local pillar = solid({
				Name = "Pillar",
				Size = Vector3.new(1.4, height, 1.4),
				CFrame = foot * CFrame.new(side * width / 2, height / 2, 0),
				Color = colors.Stone,
				Material = Enum.Material.Slate,
			}, model)
			first = first or pillar
			Kit.jackOLantern(
				foot * CFrame.new(side * width / 2, height + 0.2, 0),
				1.6,
				colors,
				model,
				{ Light = false, Detail = "Simple" }
			)
		end
		local beam = decor({
			Name = "NameBoard",
			Size = Vector3.new(width + 1.4, 2.2, 0.5),
			CFrame = foot * CFrame.new(0, height - 0.8, 0),
			Color = colors.Wood,
			Material = Enum.Material.WoodPlanks,
		}, model)
		lettering(beam, words, colors.Glow, Enum.NormalId.Front)
		lettering(beam, words, colors.Glow, Enum.NormalId.Back)
		decor({
			Name = "GlowStrip",
			Size = Vector3.new(width + 1.4, 0.2, 0.6),
			CFrame = foot * CFrame.new(0, height - 2, 0),
			Color = colors.Finish,
			Material = Enum.Material.Neon,
		}, model)
		model.PrimaryPart = first
		return model
	end)
end

-- The finish: a glowing pad under an arch, with the golden trophy pumpkin (prop "ParkourTrophy").
builders.Finish = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local pad = ringPad(top, size, colors.Finish, colors.Stone:Lerp(colors.Finish, 0.25), m)
	tag(pad, Tags.ObbyFinish)
	local diameter = math.min(size.X, size.Z)
	local facing: Vector3 = ctx.Arrive -- the way players arrive
	local entry = top.Position - facing * (diameter / 2 - 3)
	arch(CFrame.lookAt(entry, entry + facing), 9, 12, "FINISH", ctx, m)
	local spot = top.Position + facing * (diameter / 2 - 3.2)
	local trophySpot = CFrame.lookAt(spot, spot - facing)
	Kit.prop("ParkourTrophy", trophySpot, m, 12, function()
		local trophy = Kit.model("ParkourTrophy", m)
		local pedestal = solid({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 4.6, 4.6),
			CFrame = Kit.upright(trophySpot * CFrame.new(0, 0.7, 0)),
			Color = colors.Stone,
			Material = Enum.Material.Marble,
		}, trophy)
		local center = trophySpot * CFrame.new(0, 1.4 + 2.2, 0)
		local pumpkin = solid({
			Name = "TrophyPumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5.6, 4.4, 5.6),
			CFrame = center,
			Color = colors.Trophy,
			Material = Enum.Material.Foil,
		}, trophy)
		for i = 0, 3 do
			solid({
				Name = "TrophyRib",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(5.9, 4.3, 3.2),
				CFrame = center * CFrame.Angles(0, math.rad(i * 45), 0),
				Color = colors.Trophy:Lerp(Color3.new(0, 0, 0), if i % 2 == 0 then 0.12 else 0.04),
				Material = Enum.Material.Foil,
			}, trophy)
		end
		Kit.light(pumpkin, colors.Trophy, 24, 2, false)
		local hat = center * CFrame.new(0, 2.1, 0)
		disc("HatBrim", hat, 7, 0.3, colors.Hat, trophy, true)
		disc("HatBand", hat * CFrame.new(0, 0.55, 0), 3.9, 0.7, colors.HatBand, trophy, true)
		local tierY = 0.3
		for tier = 0, 3 do
			disc(
				"HatCone",
				hat * CFrame.new(-tier * 0.2, tierY + 0.5, 0),
				3.7 * (1 - tier * 0.22),
				1,
				colors.Hat,
				trophy,
				true
			)
			tierY += 0.95
		end
		trophy.PrimaryPart = pedestal
		return trophy
	end, { Light = { Color = colors.Trophy, Range = 24, Brightness = 2, Height = 0.5 } })
	local sign = Kit.holder("FinishSign", top * CFrame.new(0, 15, 0), Vector3.one, m)
	Kit.nameTag("FINISH!", sign, 0, colors.Trophy, 500)
	return pad
end

-- Green goo: touching it sends you back (walk-through; ObbyRace decides who touched it).
builders.Goo = function(top, size, _step, m, ctx)
	local colors = ctx.Colors
	local goo = decor({
		Name = "Goo",
		Size = size,
		CFrame = top * CFrame.new(0, size.Y / 2 - 0.15, 0),
		Color = colors.Goo,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	}, m)
	tag(goo, Tags.ObbyHazard)
	Kit.particles(goo, {
		Rate = 3,
		Color = ColorSequence.new(colors.Goo),
		LightEmission = 0.6,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	return goo
end

-- The plaza ---------------------------------------------------------------------------------------

-- A low railing round the plaza, open where the course starts; lampposts in the corners; the
-- START arch over the way out.
local function buildPlaza(ctx: MapBase.Ctx, frame: CFrame, colors: any, look: any)
	local def = ctx.Def
	local folder = Kit.group("Plaza", ctx.Model)
	local half = def.Size.X / 2
	local exitHalf = 7
	local rails = Kit.group("Railing", folder)
	local posts = Kit.group("Posts", folder)
	-- Posts every 6 studs along each side (the course side has a gap in the middle).
	local spots: { Vector3 } = {}
	for i = 0, 8 do
		local t = -half + i * (def.Size.X / 8)
		table.insert(spots, Vector3.new(t, 0, -half)) -- plaza back (towards the lobby)
		if math.abs(t) >= exitHalf then
			table.insert(spots, Vector3.new(t, 0, half)) -- course side, open in the middle
		end
		if i > 0 and i < 8 then
			table.insert(spots, Vector3.new(-half, 0, t))
			table.insert(spots, Vector3.new(half, 0, t))
		end
	end
	for _, p in spots do
		local foot = frame * CFrame.new(p.X, 0, -p.Z)
		Kit.prop("FencePost", foot, posts, 4.5, function()
			local post = Kit.model("FencePost", posts)
			post.PrimaryPart = solid({
				Name = "FencePost",
				Size = Vector3.new(0.8, 4.5, 0.8),
				CFrame = foot * CFrame.new(0, 2.25, 0),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, post)
			decor({
				Name = "Spike",
				Size = Vector3.new(0.4, 0.8, 0.4),
				CFrame = foot * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, post)
			return post
		end)
	end
	-- Rails between the posts (two bars, solid, so nobody walks off by accident).
	local function rail(a: Vector3, b: Vector3)
		local wa = (frame * CFrame.new(a.X, 0, -a.Z)).Position
		local wb = (frame * CFrame.new(b.X, 0, -b.Z)).Position
		local length = (wb - wa).Magnitude
		for _, y in { 1.6, 3.6 } do
			solid({
				Name = "Rail",
				Size = Vector3.new(0.3, 0.3, length),
				CFrame = CFrame.lookAt(
					(wa + wb) / 2 + Vector3.new(0, y, 0),
					wb + Vector3.new(0, y, 0)
				),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, rails)
		end
	end
	rail(Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half))
	rail(Vector3.new(-half, 0, -half), Vector3.new(-half, 0, half))
	rail(Vector3.new(half, 0, -half), Vector3.new(half, 0, half))
	rail(Vector3.new(-half, 0, half), Vector3.new(-exitHalf, 0, half))
	rail(Vector3.new(exitHalf, 0, half), Vector3.new(half, 0, half))

	-- Lampposts in the corners (prop "Lamppost"), each with its light.
	local lamps = Kit.group("Lamps", folder)
	local corners = {
		Vector3.new(-half + 3, 0, -half + 3),
		Vector3.new(half - 3, 0, -half + 3),
		Vector3.new(-half + 3, 0, half - 3),
		Vector3.new(half - 3, 0, half - 3),
	}
	for i = 1, math.min(look.PlazaLamps or 4, #corners) do
		local foot = frame * CFrame.new(corners[i].X, 0, -corners[i].Z)
		Kit.prop("Lamppost", foot, lamps, 9, function()
			local lamp = Kit.model("Lamppost", lamps)
			lamp.PrimaryPart = solid({
				Name = "Post",
				Size = Vector3.new(0.6, 9, 0.6),
				CFrame = foot * CFrame.new(0, 4.5, 0),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, lamp)
			local glass = decor({
				Name = "Lamp",
				Size = Vector3.new(1.1, 1.4, 1.1),
				CFrame = foot * CFrame.new(0, 9.5, 0),
				Color = colors.Glow,
				Material = Enum.Material.Neon,
			}, lamp)
			Kit.light(glass, colors.Glow, 22, 1.3, true)
			return lamp
		end, { Light = { Color = colors.Glow, Range = 22, Brightness = 1.3, Height = 0.9 } })
	end

	-- START written on the plaza and the arch over the way out.
	local label = decor({
		Name = "StartLabel",
		Size = Vector3.new(16, 0.05, 6),
		CFrame = frame * CFrame.new(0, 0.03, -(half - 6)),
		Transparency = 1,
	}, folder)
	lettering(label, "START", colors.Glow, Enum.NormalId.Top)
	local exitFoot = frame * CFrame.new(0, 0, -(half - 0.8))
	arch(exitFoot, exitHalf * 2 - 1.4, 11, "SPOOKY OBBY", { Colors = colors }, folder)
end

-- The void: glowing mist far below, and little graveyard islands floating off to the sides.
local function buildVoid(ctx: MapBase.Ctx, frame: CFrame, colors: any, look: any, length: number)
	local folder = Kit.group("Void", ctx.Model)
	local depth: number = look.MistDepth or 30
	local mid = frame * CFrame.new(0, -depth, -length / 2)
	local mist = decor({
		Name = "Mist",
		Size = Vector3.new(420, 1, length + 260),
		CFrame = mid,
		Color = colors.Mist,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.25,
	}, folder)
	mist.CastShadow = false
	Kit.particles(mist, {
		Rate = 8,
		Color = ColorSequence.new(colors.Mist:Lerp(Color3.new(1, 1, 1), 0.4)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 20),
			NumberSequenceKeypoint.new(1, 34),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 10),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	-- Islands: numbers drawn first (never inside Kit.prop's build), then built.
	type Island = {
		At: Vector3,
		Radius: number,
		Graves: { Vector3 },
		Tree: boolean,
		TreeHeight: number,
		TreeSeed: number,
	}
	local islands: { Island } = {}
	local count: number = look.Islands or 8
	for i = 1, count do
		local side = if i % 2 == 0 then 1 else -1
		local at = Vector3.new(
			side * ctx.Rng:NextNumber(70, 120),
			ctx.Rng:NextNumber(-14, 18),
			-length * (i - 0.5) / count + ctx.Rng:NextNumber(-15, 15)
		)
		local radius = ctx.Rng:NextNumber(9, 15)
		local graves: { Vector3 } = {}
		for _ = 1, ctx.Rng:NextInteger(2, 3) do
			local a = ctx.Rng:NextNumber(0, math.pi * 2)
			local r = ctx.Rng:NextNumber(0, radius * 0.6)
			table.insert(
				graves,
				Vector3.new(math.cos(a) * r, ctx.Rng:NextNumber(0, math.pi * 2), math.sin(a) * r)
			)
		end
		table.insert(islands, {
			At = at,
			Radius = radius,
			Graves = graves,
			Tree = ctx.Rng:NextNumber() < 0.5,
			TreeHeight = ctx.Rng:NextNumber(12, 18),
			TreeSeed = ctx.Rng:NextInteger(1, 1e6),
		})
	end
	for i, island in islands do
		local group = Kit.group(("Island%d"):format(i), folder)
		local top = frame * CFrame.new(island.At.X, island.At.Y, island.At.Z)
		disc(
			"Ground",
			top * CFrame.new(0, -1, 0),
			island.Radius * 2,
			2,
			colors.Moss,
			group,
			false,
			Enum.Material.Grass
		)
		decor({
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(island.Radius * 1.8, island.Radius * 1.2, island.Radius * 1.8),
			CFrame = top * CFrame.new(0, -2 - island.Radius * 0.5, 0),
			Color = colors.Plaza,
			Material = Enum.Material.Rock,
		}, group).CastShadow =
			false
		for _, g in island.Graves do
			local foot = top * CFrame.new(g.X, 0, g.Z) * CFrame.Angles(0, g.Y, 0)
			Kit.prop("Gravestone", foot, group, 4, function()
				local stone = Kit.model("Gravestone", group)
				stone.PrimaryPart = decor({
					Name = "Stone",
					Size = Vector3.new(2.6, 4, 0.8),
					CFrame = foot * CFrame.new(0, 2, 0),
					Color = colors.Stone,
					Material = Enum.Material.Slate,
				}, stone)
				return stone
			end, { Visual = true })
		end
		if island.Tree then
			Kit.deadTree(top, island.TreeHeight, colors.Bark, Random.new(island.TreeSeed), group)
		end
	end
end

-- Build --------------------------------------------------------------------------------------------

function SpookyObby.Build(def: any): Model
	local colors = def.Colors
	local look = def.Layout or {}
	local ctx = MapBase.new(def, {
		FloorColor = colors.Plaza,
		FloorMaterial = Enum.Material.Slate,
		WallColor = colors.Iron,
		WallMaterial = Enum.Material.Metal,
	})
	-- MapBase's walls would close the plaza: it gets a railing open towards the course instead.
	local walls = ctx.Model:FindFirstChild("Walls")
	if walls then
		walls:Destroy()
	end
	local frame = ObbyRaceRules.CourseFrame(ctx.Origin)
	local course: { Step } = def.Course
	local frames: { CFrame } = {}
	for i in course do
		local step = course[i]
		frames[i] = frame
			* CFrame.new(step.Offset.X, step.Offset.Y, -step.Offset.Z)
			* ParkourLogic.Rotation(step.Rotation)
	end
	local length = 0
	for _, step in course do
		length = math.max(length, step.Offset.Z)
	end

	buildPlaza(ctx, frame, colors, look)

	-- The haunted tree stands beside the branch climb (right of it, seen from the plaza).
	local trunkAt = frame.Position
	local low, high = math.huge, -math.huge
	local branchCount = 0
	for i, step in course do
		if step.Look == "Branch" then
			branchCount += 1
			trunkAt += frames[i].Position
			low = math.min(low, frames[i].Position.Y)
			high = math.max(high, frames[i].Position.Y)
		end
	end
	local folder = Kit.group("Course", ctx.Model)
	local pieceCtx = {
		Colors = colors,
		Checkpoints = 0,
		Index = 0,
		Facing = Vector3.new(0, 0, 1),
		Arrive = Vector3.new(0, 0, 1),
		TrunkAt = Vector3.zero,
	}
	if branchCount > 0 then
		local middle = (trunkAt - frame.Position) / branchCount
		local tree = frame:PointToObjectSpace(middle)
		local base = frame * CFrame.new(tree.X + 11, low - 14 - frame.Position.Y, tree.Z)
		pieceCtx.TrunkAt = base.Position
		local treeFolder = Kit.group("HauntedTree", ctx.Model)
		disc(
			"Roots",
			base * CFrame.new(0, -1, 0),
			10,
			2,
			colors.Moss,
			treeFolder,
			true,
			Enum.Material.Grass
		)
		Kit.deadTree(base, high - low + 24, colors.Bark, Random.new(def.Seed + 3), treeFolder)
	end

	for i, step in course do
		local build = builders[step.Look]
		if step.Kind == "Start" or not build then
			continue -- the plaza is the Floor (MapBase)
		end
		local m = Kit.model(("Step%02d_%s"):format(i, step.Look), folder)
		pieceCtx.Index = i
		pieceCtx.Facing = facingFrom(frames, course, i)
		local before = frames[math.max(i - 1, 1)].Position
		local arrive = frames[i].Position - before
		pieceCtx.Arrive = if Vector3.new(arrive.X, 0, arrive.Z).Magnitude > 1e-3
			then Vector3.new(arrive.X, 0, arrive.Z).Unit
			else pieceCtx.Facing
		local working = build(frames[i], step.Size, step, m, pieceCtx)
		m.PrimaryPart = working
		if step.Only then
			tag(m, Tags.ObbyVariant)
			m:SetAttribute(PARTS.Only, step.Only)
		end
	end

	buildVoid(ctx, frame, colors, look, length)
	return ctx.Model
end

return SpookyObby
