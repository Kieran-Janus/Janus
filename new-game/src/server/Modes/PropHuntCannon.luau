--!strict
--[[
	The finders' Pumpkin Cannon in Prop Hunt (settings: Config.PropHunt.Cannon), used by
	src/server/Modes/PropHunt.luau. The client only says where the player aimed; everything
	that counts happens here.

	PropHuntCannon.Make() -> Tool
	    A Tool (attribute PumpkinCannon = true) built from parts: a stubby black cannon with
	    orange bands, little wheels and a pumpkin peeking out of the barrel, with a "Muzzle"
	    attachment on the Handle where pumpkins fly out (client looks only).
	PropHuntCannon.Trace(origin, target, ignore) -> Trace
	    The pumpkin's path: a ray from `origin` (the finder's head) toward the aimed point, at
	    most Cannon.MaxRange long, stopping at the first thing it hits (`ignore` doesn't block).
	PropHuntCannon.Near(trace, center, radius, tolerance) -> number?
	    How far along the path a ball at `center` with `radius` (+ tolerance) is touched, or nil.
	    Lets a shot that only grazes a hider still count (lag, phones).
	PropHuntCannon.Finite(v) -> boolean   a Vector3 with real numbers (no NaN or infinity)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local PropHuntCannon = {}

export type Trace = {
	Origin: Vector3,
	Stop: Vector3, -- where the pumpkin ends: the hit point, or the end of its range
	Instance: BasePart?, -- what it hit (nil = nothing in range)
	Normal: Vector3?, -- the hit surface's direction (nil = nothing hit)
}

function PropHuntCannon.Finite(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

-- One welded, non-colliding, weightless piece of the cannon.
local function piece(props: { [string]: any }, handle: BasePart, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

function PropHuntCannon.Make(): Tool
	local cfg = Config.PropHunt.Cannon
	local colors = cfg.Colors
	local tool = Instance.new("Tool")
	tool.Name = cfg.Name
	tool.ToolTip = cfg.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("PumpkinCannon", true)
	-- The hand holds the back of the barrel; the barrel points forward (-Z).
	tool.Grip = CFrame.new(0, -0.5, 0.6)

	local handle = Kit.part({
		Name = "Handle",
		Size = Vector3.new(0.9, 0.9, 2.4),
		Color = colors.Barrel,
		Material = Enum.Material.Metal,
	}, tool)
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	local cf = handle.CFrame

	-- The barrel (a fat cylinder pointing forward) and its orange bands.
	piece({
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 1.15, 1.15),
		CFrame = cf * CFrame.new(0, 0.25, -0.8) * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Barrel,
		Material = Enum.Material.Metal,
	}, handle, tool)
	for _, z in { -0.1, -1.6 } do
		piece({
			Name = "Band",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 1.3, 1.3),
			CFrame = cf * CFrame.new(0, 0.25, z) * CFrame.Angles(0, math.rad(90), 0),
			Color = colors.Band,
			Material = Enum.Material.SmoothPlastic,
		}, handle, tool)
	end
	-- A pumpkin peeking out of the barrel.
	piece({
		Name = "Ammo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.85, 0.75, 0.85),
		CFrame = cf * CFrame.new(0, 0.25, -2.05),
		Color = colors.Pumpkin,
	}, handle, tool)
	-- Two little wheels either side.
	for _, x in { -1, 1 } do
		piece({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1, 1),
			CFrame = cf * CFrame.new(x * 0.6, -0.15, 0.2),
			Color = colors.Wheel,
			Material = Enum.Material.Wood,
		}, handle, tool)
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.25, -2.3)
	muzzle.Parent = handle
	return tool
end

function PropHuntCannon.Trace(origin: Vector3, target: Vector3, ignore: { Instance }): Trace
	local cfg = Config.PropHunt.Cannon
	local offset = target - origin
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(0, 0, -1)
	-- A little past the aimed point so the pumpkin reaches the surface the player clicked.
	local reach = math.min(offset.Magnitude + 3, cfg.MaxRange)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, direction * reach, params)
	if result then
		local hit = result.Instance
		return {
			Origin = origin,
			Stop = result.Position,
			Instance = if hit:IsA("BasePart") then hit else nil,
			Normal = result.Normal,
		}
	end
	return { Origin = origin, Stop = origin + direction * reach, Instance = nil, Normal = nil }
end

function PropHuntCannon.Near(
	trace: Trace,
	center: Vector3,
	radius: number,
	tolerance: number
): number?
	local path = trace.Stop - trace.Origin
	local length = path.Magnitude
	if length < 1e-3 then
		return nil
	end
	local direction = path / length
	-- The point on the path closest to the ball's centre.
	local along = math.clamp((center - trace.Origin):Dot(direction), 0, length)
	local closest = trace.Origin + direction * along
	if (center - closest).Magnitude <= radius + tolerance then
		return along
	end
	return nil
end

return PropHuntCannon
