--!strict
--[[
	The ScareMaze's scare characters: how they look (built from Parts) and how they move.
	Used by the ScareMaze map builder (scarecrows standing in the corn) and by the ScareMaze
	mode (src/server/Modes/ScareMaze.luau), which makes them jump out.
	Settings: Config.ScareMaze.ActorSizes / ActorColors / Traps.Kinds.

	Every character is a Model whose pivot is at its feet, facing its LookVector (-Z). Your own
	model can replace any of them: put a Model named ScareScarecrow, ScareZombie, ScareBat or
	ScareGhost in ReplicatedStorage.Custom.Props (assets/Props) and every copy uses it
	(Kit.prop). Kid-friendly: cartoon faces, nothing gory.

	  ScareActors.Scarecrow(cf, parent) / Zombie / Bat / Ghost -> Model (still, anchored)
	  ScareActors.Rig(model) -> BasePart     glues the model to one anchored "Root" part so the
	                                         server can move it smoothly (one CFrame to replicate)
	  ScareActors.Move(root, cf, seconds, style?, direction?)   tweens the Root
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local ScareActors = {}

local function colors(): { [string]: Color3 }
	return Config.ScareMaze.ActorColors
end

-- A part that never blocks, collides or gets touched (the scares pass through walls).
local function piece(props: Kit.Props, parent: Instance): Part
	local p = Kit.decor(props, parent)
	p.CastShadow = false
	return p
end

-- An oval (Roblox Ball parts are always round, so a Block with a sphere mesh).
local function oval(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = piece({ Name = name, Size = size, CFrame = cf, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A spot on the front (-Z) of an oval centred at `center` with half sizes `half`, at (x, y).
local function onOval(center: CFrame, half: Vector3, x: number, y: number): CFrame
	local inside = 1 - (x / half.X) ^ 2 - (y / half.Y) ^ 2
	local z = half.Z * math.sqrt(math.max(inside, 0))
	return center * CFrame.new(x, y, -z)
end

-- The invisible part every character hangs from (its feet, facing forward).
local function root(cf: CFrame, parent: Model): Part
	local r = Kit.holder("Root", cf, Vector3.new(1, 1, 1), parent)
	parent.PrimaryPart = r
	return r
end

-- Cartoon eyes on the front (-Z) of a head at `head`: a white eye with a dark pupil.
local function eye(head: CFrame, x: number, y: number, z: number, size: number, parent: Instance)
	local c = colors()
	piece({
		Name = "Eye",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = head * CFrame.new(x, y, z),
		Color = c.Eyes,
	}, parent)
	piece({
		Name = "Pupil",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.5,
		CFrame = head * CFrame.new(x, y, z - size * 0.32),
		Color = c.Pupils,
	}, parent)
end

-- Scarecrow on a post, 9 studs tall (pumpkin head with a glowing grin, straw hands, hat).
local function buildScarecrow(cf: CFrame, parent: Instance): Model
	local c = colors()
	local m = Kit.model("ScareScarecrow", parent)
	root(cf, m)
	piece({
		Name = "Post",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 0.7, 0.7),
		CFrame = Kit.upright(cf * CFrame.new(0, 4.5, 0)),
		Color = c.Wood,
		Material = Enum.Material.Wood,
	}, m)
	piece({
		Name = "ArmPole",
		Size = Vector3.new(6.6, 0.45, 0.45),
		CFrame = cf * CFrame.new(0, 6.4, 0),
		Color = c.Wood,
		Material = Enum.Material.Wood,
	}, m)
	piece({
		Name = "Shirt",
		Size = Vector3.new(2.6, 3, 1.4),
		CFrame = cf * CFrame.new(0, 5.6, 0),
		Color = c.Shirt,
		Material = Enum.Material.Fabric,
	}, m)
	piece({
		Name = "Patch",
		Size = Vector3.new(0.8, 0.8, 0.1),
		CFrame = cf * CFrame.new(0.5, 5.2, -0.72) * CFrame.Angles(0, 0, math.rad(12)),
		Color = c.Patch,
		Material = Enum.Material.Fabric,
	}, m)
	for _, side in { -1, 1 } do
		piece({
			Name = "Sleeve",
			Size = Vector3.new(1.9, 1, 1),
			CFrame = cf * CFrame.new(side * 2.2, 6.4, 0),
			Color = c.Shirt,
			Material = Enum.Material.Fabric,
		}, m)
		piece({
			Name = "StrawHand",
			Size = Vector3.new(1, 0.9, 0.9),
			CFrame = cf * CFrame.new(side * 3.4, 6.3, 0) * CFrame.Angles(0, 0, math.rad(side * 30)),
			Color = c.Straw,
			Material = Enum.Material.Grass,
		}, m)
	end
	piece({
		Name = "StrawSkirt",
		Size = Vector3.new(2.2, 0.9, 1.2),
		CFrame = cf * CFrame.new(0, 3.75, 0),
		Color = c.Straw,
		Material = Enum.Material.Grass,
	}, m)
	local headCf = cf * CFrame.new(0, 8.25, 0)
	local half = Vector3.new(1.35, 1.15, 1.25)
	oval("PumpkinHead", half * 2, headCf, c.Pumpkin, m)
	-- Glowing carved face, standing just out of the pumpkin's curved front.
	for _, side in { -1, 1 } do
		local eyeAt = onOval(headCf, half, side * 0.48, 0.3)
		local w = Kit.wedge({
			Name = "Eye",
			Size = Vector3.new(0.2, 0.55, 0.5),
			CFrame = eyeAt * CFrame.Angles(0, math.rad(90 * side), 0),
			Color = c.Glow,
			Material = Enum.Material.Neon,
		}, m)
		w.CanCollide = false
	end
	piece({
		Name = "Mouth",
		Size = Vector3.new(1.2, 0.28, 0.2),
		CFrame = onOval(headCf, half, 0, -0.38),
		Color = c.Glow,
		Material = Enum.Material.Neon,
	}, m)
	piece({
		Name = "Stem",
		Size = Vector3.new(0.35, 0.5, 0.35),
		CFrame = headCf * CFrame.new(0, 1.25, 0),
		Color = c.Wood,
	}, m)
	piece({
		Name = "HatBrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 3.6, 3.6),
		CFrame = Kit.upright(headCf * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(6))),
		Color = c.Hat,
		Material = Enum.Material.Fabric,
	}, m)
	piece({
		Name = "HatTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 1.8, 1.8),
		CFrame = Kit.upright(headCf * CFrame.new(0.1, 1.85, 0) * CFrame.Angles(0, 0, math.rad(8))),
		Color = c.Hat,
		Material = Enum.Material.Fabric,
	}, m)
	-- The carved face parts from Kit are solid; make them decorations like the rest.
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	return m
end

-- A goofy cartoon zombie, 6 studs tall, arms out in front.
local function buildZombie(cf: CFrame, parent: Instance): Model
	local c = colors()
	local m = Kit.model("ScareZombie", parent)
	root(cf, m)
	for _, side in { -1, 1 } do
		piece({
			Name = "Leg",
			Size = Vector3.new(0.85, 2.4, 0.9),
			CFrame = cf * CFrame.new(side * 0.5, 1.2, 0),
			Color = c.ZombiePants,
			Material = Enum.Material.Fabric,
		}, m)
		piece({
			Name = "Arm",
			Size = Vector3.new(0.7, 0.7, 2.1),
			CFrame = cf
				* CFrame.new(side * 1.35, 4.3, -0.9)
				* CFrame.Angles(math.rad(side * 6), 0, 0),
			Color = c.ZombieShirt,
			Material = Enum.Material.Fabric,
		}, m)
		piece({
			Name = "Hand",
			Size = Vector3.new(0.75, 0.6, 0.75),
			CFrame = cf * CFrame.new(side * 1.35, 4.3, -2.2),
			Color = c.ZombieSkin,
		}, m)
	end
	piece({
		Name = "Shirt",
		Size = Vector3.new(2.1, 2.3, 1.1),
		CFrame = cf * CFrame.new(0, 3.55, 0),
		Color = c.ZombieShirt,
		Material = Enum.Material.Fabric,
	}, m)
	local headCf = cf * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(8))
	oval("Head", Vector3.new(1.9, 1.9, 1.8), headCf, c.ZombieSkin, m)
	-- One big eye, one small eye: silly, not scary-gross.
	eye(headCf, -0.42, 0.2, -0.7, 0.75, m)
	eye(headCf, 0.45, 0.15, -0.75, 0.55, m)
	piece({
		Name = "Mouth",
		Size = Vector3.new(0.9, 0.2, 0.1),
		CFrame = headCf * CFrame.new(0, -0.45, -0.88),
		Color = c.Pupils,
	}, m)
	piece({
		Name = "Hair",
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = headCf * CFrame.new(0.2, 1, 0) * CFrame.Angles(0, 0, math.rad(35)),
		Color = c.ZombiePants,
	}, m)
	return m
end

-- One little bat, 1.4 studs tall, wings spread.
local function buildBat(cf: CFrame, parent: Instance): Model
	local c = colors()
	local m = Kit.model("ScareBat", parent)
	root(cf, m)
	local body = cf * CFrame.new(0, 0.7, 0)
	oval("Body", Vector3.new(0.7, 0.8, 0.8), body, c.Bat, m)
	for _, side in { -1, 1 } do
		piece({
			Name = "Wing",
			Size = Vector3.new(1.5, 0.3, 0.9),
			CFrame = body
				* CFrame.new(side * 0.95, 0.2, 0)
				* CFrame.Angles(0, 0, math.rad(side * 30)),
			Color = c.Bat,
		}, m)
		piece({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.18,
			CFrame = body * CFrame.new(side * 0.15, 0.12, -0.36),
			Color = c.BatEyes,
			Material = Enum.Material.Neon,
		}, m)
	end
	return m
end

-- A floating sheet ghost, 6 studs tall, with big round eyes and an "O" mouth.
local function buildGhost(cf: CFrame, parent: Instance): Model
	local c = colors()
	local m = Kit.model("ScareGhost", parent)
	root(cf, m)
	local body = oval("Sheet", Vector3.new(3.6, 5.2, 3.4), cf * CFrame.new(0, 3.4, 0), c.Ghost, m)
	body.Transparency = 0.1
	for i = 0, 3 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		oval(
			"Hem",
			Vector3.new(1.5, 1.4, 1.5),
			cf * CFrame.new(math.cos(angle) * 1.15, 1, math.sin(angle) * 1.1),
			c.Ghost,
			m
		).Transparency =
			0.1
	end
	for _, side in { -1, 1 } do
		oval(
			"Eye",
			Vector3.new(0.6, 0.9, 0.2),
			cf * CFrame.new(side * 0.6, 4.4, -1.62),
			c.Pupils,
			m
		)
	end
	oval("Mouth", Vector3.new(0.7, 0.8, 0.2), cf * CFrame.new(0, 3.4, -1.76), c.Pupils, m)
	Kit.light(body, Color3.fromRGB(190, 210, 255), 12, 1, false)
	return m
end

local BUILDERS: { [string]: (CFrame, Instance) -> Model } = {
	ScareScarecrow = buildScarecrow,
	ScareZombie = buildZombie,
	ScareBat = buildBat,
	ScareGhost = buildGhost,
}

-- Builds (or clones your custom model of) actor `name` standing on `cf`.
local function make(name: string, cf: CFrame, parent: Instance): Model
	local size = (Config.ScareMaze.ActorSizes :: any)[name]
	local build = BUILDERS[name]
	local m = Kit.prop(name, cf, parent, if typeof(size) == "number" then size else nil, function()
		return build(cf, parent)
	end, { Visual = true })
	-- A custom model is anchored by Kit.prop; make it pass through everything like ours.
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return m
end

function ScareActors.Scarecrow(cf: CFrame, parent: Instance): Model
	return make("ScareScarecrow", cf, parent)
end

function ScareActors.Zombie(cf: CFrame, parent: Instance): Model
	return make("ScareZombie", cf, parent)
end

function ScareActors.Bat(cf: CFrame, parent: Instance): Model
	return make("ScareBat", cf, parent)
end

function ScareActors.Ghost(cf: CFrame, parent: Instance): Model
	return make("ScareGhost", cf, parent)
end

--[[
	Glues every part of `model` to one anchored part (its "Root", made at the model's pivot if
	it has none), so moving the Root moves the whole character and only one CFrame has to reach
	the players. Safe to call twice. Returns the Root.
]]
function ScareActors.Rig(model: Model): BasePart
	local existing = model:FindFirstChild("Root")
	local r: BasePart
	if existing and existing:IsA("BasePart") then
		r = existing
	else
		r = Kit.holder("Root", model:GetPivot(), Vector3.new(1, 1, 1), model)
	end
	r.Anchored = true
	model.PrimaryPart = r
	if model:GetAttribute("Rigged") then
		return r
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= r then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = r
			weld.Part1 = d
			weld.Parent = d
			d.Massless = true
			d.Anchored = false
		end
	end
	model:SetAttribute("Rigged", true)
	return r
end

-- Smoothly moves a rigged character's Root to `cf` (doesn't wait).
function ScareActors.Move(
	r: BasePart,
	cf: CFrame,
	seconds: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	if not r.Parent then
		return
	end
	if seconds <= 0 then
		r.CFrame = cf
		return
	end
	local info = TweenInfo.new(
		seconds,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	TweenService:Create(r, info, { CFrame = cf }):Play()
end

-- A one-off puff of particles at `cf` (dirt for zombies), cleaned up after `seconds`.
function ScareActors.Puff(
	cf: CFrame,
	color: Color3,
	amount: number,
	parent: Instance,
	seconds: number
)
	local holder = Kit.holder("Puff", cf, Vector3.new(4, 0.5, 4), parent)
	local emitter = Kit.particles(holder, {
		Rate = 0,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 2.2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, -25, 0),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	emitter.LightInfluence = 1
	emitter:Emit(amount)
	task.delay(seconds, function()
		holder:Destroy()
	end)
end

return ScareActors
