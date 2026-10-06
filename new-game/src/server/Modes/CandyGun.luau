--!strict
--[[
	The seekers' candy gun (settings: Config.HideSeek.Gun), used by src/server/Modes/HideSeek.luau.
	The client only says where the player aimed; everything that counts happens here.

	CandyGun.Make() -> Tool
	    A Tool (attribute CandyGun = true) built from parts: a striped candy blaster with a
	    "Muzzle" attachment on the Handle where candies come out (client looks only).
	CandyGun.Trace(origin, target, ignore) -> Trace
	    The candy's path: a ray from `origin` (the seeker's head) toward the aimed point, at most
	    Gun.MaxRange long, stopping at the first thing it hits (characters in `ignore` don't
	    block it). Returns where it stopped, the surface it hit and that surface's direction.
	CandyGun.Near(trace, center, radius) -> number?
	    How far along the path a ball at `center` with `radius` (+ Gun.HitTolerance) is touched,
	    or nil if the path misses it. Lets a shot that only grazes a hider still count.
	CandyGun.Finite(v) -> boolean   a Vector3 with real numbers (no NaN or infinity)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local CandyGun = {}

export type Trace = {
	Origin: Vector3,
	Stop: Vector3, -- where the candy ends: the hit point, or the end of its range
	Instance: BasePart?, -- what it hit (nil = nothing in range)
	Normal: Vector3?, -- the hit surface's direction (nil = nothing hit)
}

function CandyGun.Finite(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

-- One welded, non-colliding, weightless piece of the gun.
local function piece(props: { [string]: any }, handle: BasePart, parent: Instance): Part
	local p = Kit.part(props, parent)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

function CandyGun.Make(): Tool
	local cfg = Config.HideSeek.Gun
	local colors = cfg.Colors
	local tool = Instance.new("Tool")
	tool.Name = cfg.Name
	tool.ToolTip = cfg.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("CandyGun", true)
	-- The hand holds the grip under the back of the body; the barrel points forward (-Z).
	tool.Grip = CFrame.new(0, -0.55, 0.45)

	local handle = Kit.part({
		Name = "Handle",
		Size = Vector3.new(0.7, 0.8, 2),
		Color = colors.Body,
	}, tool)
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	local cf = handle.CFrame

	-- Candy-cane stripes round the body.
	for i = -1, 1 do
		piece({
			Name = "Stripe",
			Size = Vector3.new(0.74, 0.84, 0.22),
			CFrame = cf * CFrame.new(0, 0, i * 0.6) * CFrame.Angles(0, 0, math.rad(20)),
			Color = colors.Stripe,
		}, handle, tool)
	end
	-- Barrel and its rim.
	piece({
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 0.5, 0.5),
		CFrame = cf * CFrame.new(0, 0.05, -1.4) * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Body,
	}, handle, tool)
	piece({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 0.66, 0.66),
		CFrame = cf * CFrame.new(0, 0.05, -1.9) * CFrame.Angles(0, math.rad(90), 0),
		Color = colors.Stripe,
	}, handle, tool)
	-- A round candy jar on top.
	piece({
		Name = "Hopper",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = cf * CFrame.new(0, 0.6, 0.2),
		Color = colors.Hopper,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	}, handle, tool)
	-- Grip under the back.
	piece({
		Name = "Grip",
		Size = Vector3.new(0.45, 0.9, 0.5),
		CFrame = cf * CFrame.new(0, -0.6, 0.45) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = colors.Grip,
	}, handle, tool)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.05, -2.05)
	muzzle.Parent = handle
	return tool
end

function CandyGun.Trace(origin: Vector3, target: Vector3, ignore: { Instance }): Trace
	local cfg = Config.HideSeek.Gun
	local offset = target - origin
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(0, 0, -1)
	-- A little past the aimed point so the candy reaches the surface the player clicked.
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

function CandyGun.Near(trace: Trace, center: Vector3, radius: number): number?
	local tolerance = Config.HideSeek.Gun.HitTolerance
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

return CandyGun
