--!strict
--[[
	The Tormented Tower: a really hard climb inside the lobby's clock tower (Config.TowerParkour;
	on/off: Config.Features.TowerParkour). Built from Config only (src/shared/TowerLogic.luau
	works out the leaning, twisting floors), so it stays put when the ClockTower prop is swapped.

	Workspace.Hub.TowerParkour
	  Course       one Model per piece, "Step03_Tiny"..., in climbing order. Working parts are
	               tagged: TowerStart, TowerCheckpoint (attribute Index 1, 2, 3), TowerFinish,
	               TowerHazard (slime), TowerVanish (attribute Phase), TowerSpinner (the bar),
	               TowerGear (the cog). Spinning bars and cogs turn on a motor (HingeConstraint).
	  Lanterns     glowing lanterns on the inside walls (Config.TowerParkour.Walls.Lights)
	  Shell        only for a custom ClockTower model: inner walls and a floor (TowerParkour.Fit)

	The built clock tower is hollow while the feature is on (HubBuilder). TowerParkour.Fit(hub)
	runs when the game starts (HubService): any part of the ClockTower prop inside the tower's
	hollow middle or its doorway stops being solid (a custom model may be solid inside), and a
	custom tower gets the Shell.

	TowerParkour.Build(hub, zone) -> Model
	TowerParkour.Fit(hub) -> number   parts made walk-through
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local TowerLogic = require(ReplicatedStorage.Shared.TowerLogic)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)

local TowerParkour = {}

local cfg = Config.TowerParkour
local colors = cfg.Look.Colors

local function solid(props: Kit.Props, parent: Instance): Part
	return Kit.part(props, parent)
end

local function decor(props: Kit.Props, parent: Instance): Part
	return Kit.decor(props, parent)
end

local function tag(instance: Instance, name: string)
	CollectionService:AddTag(instance, name)
end

-- A vertical hinge with a motor: `turning` spins round `axle` (anchored) at `speed` rad/s.
local function motor(axle: BasePart, turning: BasePart, at: CFrame, speed: number)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- an attachment's axis is its X: point it up
	local a0 = Instance.new("Attachment")
	a0.Name = "Axle"
	a0.CFrame = axle.CFrame:ToObjectSpace(at) * upright
	a0.Parent = axle
	local a1 = Instance.new("Attachment")
	a1.Name = "Axle"
	a1.CFrame = turning.CFrame:ToObjectSpace(at) * upright
	a1.Parent = turning
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "Motor"
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = speed
	hinge.MotorMaxTorque = 1e8
	hinge.MotorMaxAcceleration = 1e4
	hinge.Parent = turning
end

-- Pieces --------------------------------------------------------------------------------------

type Ctx = {
	Top: CFrame, -- the top middle of the piece (level)
	Size: Vector3,
	Model: Model,
	Step: TowerLogic.Step,
}

local builders: { [string]: (ctx: Ctx) -> BasePart } = {}

local function slab(ctx: Ctx, name: string, color: Color3, material: Enum.Material): Part
	return solid({
		Name = name,
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0),
		Color = color,
		Material = material,
	}, ctx.Model)
end

function builders.Start(ctx: Ctx): BasePart
	local pad = slab(ctx, "Pad", colors.Stone, Enum.Material.Slate)
	tag(pad, Tags.TowerStart)
	Kit.surfaceText(pad, "START", colors.Spinner, Enum.NormalId.Top)
	return pad
end

function builders.Ledge(ctx: Ctx): BasePart
	local ledge = slab(ctx, "Ledge", colors.Stone, Enum.Material.Cobblestone)
	-- A little stone bracket under it (looks only).
	decor({
		Name = "Bracket",
		Size = Vector3.new(ctx.Size.X * 0.5, 1.2, ctx.Size.Z * 0.5),
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y - 0.6, 0),
		Color = Kit.shade(colors.Stone, 0.25),
		Material = Enum.Material.Slate,
	}, ctx.Model)
	return ledge
end

function builders.Tiny(ctx: Ctx): BasePart
	return Kit.rounded({
		Name = "Post",
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, ctx.Model)
end

function builders.Beam(ctx: Ctx): BasePart
	return slab(ctx, "Beam", colors.Wood, Enum.Material.WoodPlanks)
end

function builders.Truss(ctx: Ctx): BasePart
	local truss = Instance.new("TrussPart")
	truss.Name = "Truss"
	truss.Anchored = true
	truss.Size = ctx.Size
	truss.CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0)
	truss.Color = colors.Iron
	truss.Material = Enum.Material.Metal
	truss.Parent = ctx.Model
	return truss
end

local vanishCount = 0
function builders.Vanish(ctx: Ctx): BasePart
	local p = slab(ctx, "Vanish", colors.Vanish, Enum.Material.Glass)
	p.Transparency = 0.15
	vanishCount += 1
	p:SetAttribute("Phase", (vanishCount - 1) * cfg.Vanish.Stagger)
	tag(p, Tags.TowerVanish)
	return p
end

function builders.Spinner(ctx: Ctx): BasePart
	local platform = Kit.rounded({
		Name = "Platform",
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0),
		Color = colors.Iron,
		Material = Enum.Material.DiamondPlate,
	}, ctx.Model)
	local s = cfg.Spinner
	local hub = ctx.Top * CFrame.new(0, s.Height, 0)
	local axle = solid({
		Name = "Axle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(s.Height + 0.4, 0.8, 0.8),
		CFrame = Kit.upright(ctx.Top * CFrame.new(0, s.Height / 2, 0)),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, ctx.Model)
	local bar = Instance.new("Part")
	bar.Name = "Bar"
	bar.Anchored = false
	bar.Size = Vector3.new(s.Length, s.Thickness, s.Thickness)
	bar.CFrame = hub
	bar.Color = colors.Spinner
	bar.Material = Enum.Material.Neon
	bar.TopSurface = Enum.SurfaceType.Smooth
	bar.BottomSurface = Enum.SurfaceType.Smooth
	bar.CanCollide = true
	bar.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0.5)
	bar.Parent = ctx.Model
	motor(axle, bar, hub, s.Speed)
	tag(bar, Tags.TowerSpinner)
	return platform
end

function builders.Gear(ctx: Ctx): BasePart
	local g = cfg.Gear
	local center = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0)
	local cog = Instance.new("Part")
	cog.Name = "Cog"
	cog.Shape = Enum.PartType.Cylinder
	cog.Anchored = false
	cog.Size = Vector3.new(ctx.Size.Y, ctx.Size.X, ctx.Size.Z)
	cog.CFrame = Kit.upright(center)
	cog.Color = colors.Gear
	cog.Material = Enum.Material.Metal
	cog.TopSurface = Enum.SurfaceType.Smooth
	cog.BottomSurface = Enum.SurfaceType.Smooth
	cog.CustomPhysicalProperties = PhysicalProperties.new(3, 1, 0.1, 1, 1) -- grippy: you ride it
	cog.Parent = ctx.Model
	-- Teeth round the edge (looks only, carried by the cog).
	for t = 1, g.Teeth do
		local a = t / g.Teeth * math.pi * 2
		local r = ctx.Size.X / 2
		local tooth = Instance.new("Part")
		tooth.Name = "Tooth"
		tooth.Anchored = false
		tooth.Massless = true
		tooth.CanCollide = false
		tooth.CanQuery = false
		tooth.CanTouch = false
		tooth.Size = Vector3.new(0.9, ctx.Size.Y * 0.8, 0.9)
		tooth.CFrame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
		tooth.Color = Kit.shade(colors.Gear, 0.2)
		tooth.Material = Enum.Material.Metal
		tooth.Parent = ctx.Model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = cog
		weld.Part1 = tooth
		weld.Parent = tooth
	end
	local axle = solid({
		Name = "Axle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 1, 1),
		CFrame = Kit.upright(center * CFrame.new(0, -ctx.Size.Y / 2 - 0.7, 0)),
		Color = colors.Iron,
		Material = Enum.Material.Metal,
	}, ctx.Model)
	motor(axle, cog, center, g.Speed)
	tag(cog, Tags.TowerGear)
	return cog
end

local checkpointCount = 0
function builders.Checkpoint(ctx: Ctx): BasePart
	local pad = Kit.rounded({
		Name = "Pad",
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0),
		Color = colors.Checkpoint,
		Material = Enum.Material.Neon,
	}, ctx.Model)
	checkpointCount += 1
	pad:SetAttribute("Index", checkpointCount)
	tag(pad, Tags.TowerCheckpoint)
	local words = ("CHECKPOINT %d"):format(checkpointCount)
	if ctx.Step.Label then
		words ..= "\n" .. ctx.Step.Label
	end
	Kit.nameTag(words, pad, 3.5, colors.Checkpoint, 60)
	return pad
end

function builders.Finish(ctx: Ctx): BasePart
	local pad = Kit.rounded({
		Name = "Pad",
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, -ctx.Size.Y / 2, 0),
		Color = colors.Finish,
		Material = Enum.Material.Neon,
	}, ctx.Model)
	tag(pad, Tags.TowerFinish)
	Kit.nameTag(cfg.Name, pad, 4, colors.Finish, 80)
	return pad
end

function builders.Hazard(ctx: Ctx): BasePart
	local slime = Kit.part({
		Name = "Slime",
		Size = ctx.Size,
		CFrame = ctx.Top * CFrame.new(0, ctx.Size.Y / 2, 0),
		Color = colors.Slime,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	}, ctx.Model)
	slime.CanCollide = false
	slime.CanQuery = false
	tag(slime, Tags.TowerHazard)
	return slime
end

-- Lanterns on the inside walls ---------------------------------------------------------------

local function buildLanterns(parent: Instance, floors: { TowerLogic.Floor })
	local lights = cfg.Walls.Lights
	local folder = Kit.group("Lanterns", parent)
	for n, up in lights.Heights do
		local spine, floor = TowerLogic.Spine(up, floors)
		local half = TowerLogic.InsideHalf(floor)
		-- Round the walls in turn: back, right, left...
		local turn = CFrame.Angles(0, (n - 1) * math.pi / 2, 0)
		local at = spine * turn * CFrame.new(0, 0, -(half + cfg.Walls.Clearance - 0.2))
		local glass = decor({
			Name = "Lantern",
			Size = Vector3.new(0.9, 1.4, 0.9),
			CFrame = at,
			Color = colors.Lantern,
			Material = Enum.Material.Neon,
		}, folder)
		Kit.light(glass, lights.Color, lights.Range, lights.Brightness, true)
	end
end

-- Build ---------------------------------------------------------------------------------------

function TowerParkour.Build(hub: Instance, _zone: any): Instance
	local area = Kit.group("TowerParkour", hub)
	if not Config.Features.TowerParkour then
		return area
	end
	local floors = TowerLogic.Floors()
	local course = cfg.Course
	local courseModel = Kit.group("Course", area)
	vanishCount, checkpointCount = 0, 0
	for i, step in course do
		local build = builders[step.Kind]
		if not build then
			warn(("[TowerParkour] Step %d has an unknown Kind %q"):format(i, tostring(step.Kind)))
			continue
		end
		local m = Kit.model(("Step%02d_%s"):format(i, step.Kind), courseModel)
		local main = build({
			Top = TowerLogic.StepCFrame(course, i, floors),
			Size = TowerLogic.SizeOf(step),
			Model = m,
			Step = step,
		})
		m.PrimaryPart = main
	end
	buildLanterns(area, floors)
	local problems = TowerLogic.Check(course, floors)
	for _, problem in problems do
		warn("[TowerParkour] " .. problem)
	end
	return area
end

-- Fit the tower ------------------------------------------------------------------------------

-- The clock tower prop in the hub (built or your own model).
local function findTower(hub: Instance): Model?
	for _, d in hub:GetDescendants() do
		if
			d:IsA("Model")
			and (d:GetAttribute("PropName") == "ClockTower" or d.Name == "ClockTower")
		then
			return d
		end
	end
	return nil
end

-- The hollow inside of each floor and the doorway, as boxes (CFrame, size).
local function insideBoxes(floors: { TowerLogic.Floor }): { { CFrame: CFrame, Size: Vector3 } }
	local height = Config.Hub.ClockTower.FloorHeight
	local walls = cfg.Walls
	local boxes = {}
	for _, floor in floors do
		-- (A little smaller than the hollow: the floors lean, so a wall's top edge pokes a
		-- little way into the floor above.)
		local inner = floor.Width - 2 * walls.Thickness - 0.8
		table.insert(boxes, {
			CFrame = floor.CFrame * CFrame.new(0, height / 2, 0),
			Size = Vector3.new(inner, height - 1.5, inner),
		})
	end
	-- The doorway, through the front wall (the side facing the plaza, -Z of the floor).
	local first = floors[1]
	table.insert(boxes, {
		CFrame = first.CFrame * CFrame.new(0, walls.DoorHeight / 2, -first.Width / 2),
		Size = Vector3.new(walls.DoorWidth, walls.DoorHeight, walls.Thickness * 4),
	})
	return boxes
end

local function overlaps(part: BasePart, box: { CFrame: CFrame, Size: Vector3 }): boolean
	-- Separating-axis test of two boxes.
	local a, b = part.CFrame, box.CFrame
	local ha, hb = part.Size / 2, box.Size / 2
	local axesA = { a.RightVector, a.UpVector, a.LookVector }
	local axesB = { b.RightVector, b.UpVector, b.LookVector }
	local d = b.Position - a.Position
	local function separated(axis: Vector3): boolean
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra = math.abs(axesA[1]:Dot(axis)) * ha.X
			+ math.abs(axesA[2]:Dot(axis)) * ha.Y
			+ math.abs(axesA[3]:Dot(axis)) * ha.Z
		local rb = math.abs(axesB[1]:Dot(axis)) * hb.X
			+ math.abs(axesB[2]:Dot(axis)) * hb.Y
			+ math.abs(axesB[3]:Dot(axis)) * hb.Z
		return math.abs(d:Dot(axis)) > ra + rb - 0.05
	end
	for _, axis in axesA do
		if separated(axis) then
			return false
		end
	end
	for _, axis in axesB do
		if separated(axis) then
			return false
		end
	end
	for _, x in axesA do
		for _, y in axesB do
			if separated(x:Cross(y)) then
				return false
			end
		end
	end
	return true
end

-- Inner walls and a floor inside a custom tower, so the climb still looks like a tower inside.
local function buildShell(area: Instance, floors: { TowerLogic.Floor })
	local shell = Kit.model("Shell", area)
	local walls = cfg.Walls
	local height = Config.Hub.ClockTower.FloorHeight
	local t = 0.4
	for _, floor in floors do
		local inner = floor.Width - 2 * walls.Thickness
		local mid = floor.CFrame * CFrame.new(0, height / 2, 0)
		for side = 0, 3 do
			local face = mid
				* CFrame.Angles(0, side * math.pi / 2, 0)
				* CFrame.new(0, 0, inner / 2 + t / 2)
			local isFront = side == 2 -- -Z: the door side
			if floor.Index == 1 and isFront then
				-- Round the doorway.
				local sideW = (inner - walls.DoorWidth) / 2
				for _, s in { -1, 1 } do
					solid({
						Name = "ShellWall",
						Size = Vector3.new(sideW, height, t),
						CFrame = face * CFrame.new(s * (walls.DoorWidth / 2 + sideW / 2), 0, 0),
						Color = walls.Color,
						Material = walls.Material,
					}, shell)
				end
				local above = height - walls.DoorHeight
				solid({
					Name = "ShellWall",
					Size = Vector3.new(walls.DoorWidth, above, t),
					CFrame = face * CFrame.new(0, height / 2 - above / 2, 0),
					Color = walls.Color,
					Material = walls.Material,
				}, shell)
			else
				solid({
					Name = "ShellWall",
					Size = Vector3.new(inner + 2 * t, height, t),
					CFrame = face,
					Color = walls.Color,
					Material = walls.Material,
				}, shell)
			end
		end
	end
	local first = floors[1]
	solid({
		Name = "ShellFloor",
		Size = Vector3.new(
			first.Width - 2 * walls.Thickness,
			0.6,
			first.Width - 2 * walls.Thickness
		),
		CFrame = first.CFrame * CFrame.new(0, -0.3, 0),
		Color = Kit.shade(walls.Color, 0.3),
		Material = Enum.Material.Slate,
	}, shell)
end

function TowerParkour.Fit(hub: Instance): number
	if not Config.Features.TowerParkour then
		return 0
	end
	local area = hub:FindFirstChild("TowerParkour")
	local tower = findTower(hub)
	if not (area and tower) then
		return 0
	end
	local floors = TowerLogic.Floors()
	local boxes = insideBoxes(floors)
	local count = 0
	for _, d in tower:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			for _, box in boxes do
				if overlaps(d, box) then
					d.CanCollide = false
					d.CastShadow = false
					count += 1
					break
				end
			end
		end
	end
	if tower:GetAttribute("CustomProp") == true and not area:FindFirstChild("Shell") then
		buildShell(area, floors)
	end
	return count
end

return TowerParkour
