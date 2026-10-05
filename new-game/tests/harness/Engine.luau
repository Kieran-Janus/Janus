--[[
	Engine behaviour the harness adds on top of the plain instance tree (Dom.luau):

	  BasePart     Position / Orientation / Rotation aliases of CFrame, GetPivot, PivotTo,
	               GetMass
	  Model        GetPivot / PivotTo / WorldPivot (PrimaryPart first), GetBoundingBox,
	               GetExtentsSize, ScaleTo / GetScale, MoveTo, TranslateBy,
	               SetPrimaryPartCFrame
	  Attachment   Position / Orientation / World* aliases
	  Humanoid     Health (clamped, Died), TakeDamage, MoveTo (walks in a straight line over
	               virtual time), LoadAnimation
	  Camera       WorldToViewportPoint / ScreenPointToRay with a simple perspective model
	  WorldRoot    Raycast against part boxes, balls and cylinders; GetPartBoundsInBox /
	               InRadius / GetPartsInPart by bounding boxes

	All of it is real math on the parts' CFrame and Size; there is still no physics: nothing
	falls, collides or touches.
]]

local roblox = require("@lune/roblox")
local Dom = require("./Dom")
local Types = require("./Types")

local CFrame, Vector3, Vector2, Enum = roblox.CFrame, roblox.Vector3, roblox.Vector2, roblox.Enum
local typeof = Types.typeof

local Engine = {}

type Data = Dom.Data

-- Part helpers ---------------------------------------------------------------------------------

local function partCF(pd: Data): CFrame
	return pd.props.CFrame or CFrame.identity
end

local function partSize(pd: Data): Vector3
	return pd.props.Size or Dom.get(pd.u, "Size")
end

local function setCF(pd: Data, cf: CFrame)
	Dom.set(pd.u, "CFrame", cf)
end

local function isBasePart(d: Data): boolean
	return d.class.isA.BasePart == true and d.ClassName ~= "Terrain"
end

local function baseParts(root: Data, includeSelf: boolean): { Data }
	local out = {}
	if includeSelf and isBasePart(root) then
		table.insert(out, root)
	end
	for _, d in Dom.descendantData(root) do
		if isBasePart(d) then
			table.insert(out, d)
		end
	end
	return out
end
Engine.baseParts = baseParts

local function isDescendant(d: Data, ancestor: Data): boolean
	local a = d.parent
	while a do
		if a == ancestor then
			return true
		end
		a = a.parent
	end
	return false
end

local function partPivot(pd: Data): CFrame
	return partCF(pd) * (pd.props.PivotOffset or CFrame.identity)
end

local function expectCFrame(value: any, method: string)
	if typeof(value) ~= "CFrame" then
		error(
			("invalid argument #1 to '%s' (CFrame expected, got %s)"):format(method, typeof(value)),
			3
		)
	end
end

-- Axis-aligned box (in `orientation`'s rotation) around every part: exact for blocks.
local function boundingBox(parts: { Data }, orientation: CFrame): (CFrame?, Vector3)
	if #parts == 0 then
		return nil, Vector3.zero
	end
	local rot = orientation.Rotation
	local inf = math.huge
	local minX, minY, minZ, maxX, maxY, maxZ = inf, inf, inf, -inf, -inf, -inf
	for _, pd in parts do
		local half = partSize(pd) / 2
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rot:ToObjectSpace(partCF(pd))
			:GetComponents()
		local p = rot:PointToObjectSpace(partCF(pd).Position)
		local ex = math.abs(r00) * half.X + math.abs(r01) * half.Y + math.abs(r02) * half.Z
		local ey = math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z
		local ez = math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
		minX, maxX = math.min(minX, p.X - ex), math.max(maxX, p.X + ex)
		minY, maxY = math.min(minY, p.Y - ey), math.max(maxY, p.Y + ey)
		minZ, maxZ = math.min(minZ, p.Z - ez), math.max(maxZ, p.Z + ez)
	end
	local centre =
		rot:PointToWorldSpace(Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2))
	return CFrame.new(centre) * rot, Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
end
Engine.boundingBox = boundingBox

-- Model pivots ---------------------------------------------------------------------------------

local function primaryPart(md: Data): Data?
	local pp = md.props.PrimaryPart
	local pd = pp and Dom.data(pp)
	if pd and isDescendant(pd, md) then
		return pd
	end
	return nil
end

-- PrimaryPart's pivot, else WorldPivot, else (never set) the centre of the bounding box.
local function modelPivot(md: Data): CFrame
	local pp = primaryPart(md)
	if pp then
		return partPivot(pp)
	end
	local stored = md.props.WorldPivotData
	if stored then
		return stored
	end
	local box = boundingBox(baseParts(md, false), CFrame.identity)
	return if box then CFrame.new(box.Position) else CFrame.identity
end
Engine.modelPivot = modelPivot

-- Moves every part (and nested model pivot) under `root` rigidly by `delta` (world space).
local function moveBy(root: Data, delta: CFrame, includeSelf: boolean)
	for _, pd in baseParts(root, includeSelf) do
		setCF(pd, delta * partCF(pd))
	end
	for _, d in Dom.descendantData(root) do
		if d.class.isA.Model and d.props.WorldPivotData then
			d.props.WorldPivotData = delta * d.props.WorldPivotData
		end
	end
end

local function modelPivotTo(md: Data, target: CFrame)
	local delta = target * modelPivot(md):Inverse()
	moveBy(md, delta, false)
	if not primaryPart(md) then
		md.props.WorldPivotData = target
	elseif md.props.WorldPivotData then
		md.props.WorldPivotData = delta * md.props.WorldPivotData
	end
end

local function boxOrientation(md: Data): CFrame
	local pp = primaryPart(md)
	if pp then
		return partCF(pp)
	end
	return modelPivot(md)
end

local function scaleModel(md: Data, newScale: number)
	if
		type(newScale) ~= "number"
		or newScale ~= newScale
		or newScale <= 0
		or newScale == math.huge
	then
		error(
			("invalid argument #1 to 'ScaleTo' (scale must be a positive number, got %s)"):format(
				tostring(newScale)
			),
			3
		)
	end
	local current = md.props.Scale or 1
	local factor = newScale / current
	if math.abs(factor - 1) < 1e-12 then
		return
	end
	local pivot = modelPivot(md)
	local function scalePoint(cf: CFrame): CFrame
		local rel = pivot:ToObjectSpace(cf)
		return pivot * (CFrame.new(rel.Position * factor) * rel.Rotation)
	end
	for _, pd in baseParts(md, false) do
		Dom.set(pd.u, "Size", partSize(pd) * factor)
		setCF(pd, scalePoint(partCF(pd)))
		local offset = pd.props.PivotOffset
		if offset then
			pd.props.PivotOffset = CFrame.new(offset.Position * factor) * offset.Rotation
		end
	end
	for _, d in Dom.descendantData(md) do
		local isA = d.class.isA
		if isA.Attachment then
			local cf = d.props.CFrame or CFrame.identity
			d.props.CFrame = CFrame.new(cf.Position * factor) * cf.Rotation
		elseif isA.JointInstance then
			for _, key in { "C0", "C1" } do
				local cf = d.props[key]
				if cf then
					d.props[key] = CFrame.new(cf.Position * factor) * cf.Rotation
				end
			end
		elseif isA.Model then
			if d.props.WorldPivotData then
				d.props.WorldPivotData = scalePoint(d.props.WorldPivotData)
			end
			d.props.Scale = (d.props.Scale or 1) * factor
		elseif isA.SpecialMesh then
			d.props.Scale = (d.props.Scale or Vector3.one) * factor
			d.props.Offset = (d.props.Offset or Vector3.zero) * factor
		elseif isA.Light then
			d.props.Range = (Dom.get(d.u, "Range") :: number) * factor
		elseif isA.Humanoid then
			d.props.HipHeight = (Dom.get(d.u, "HipHeight") :: number) * factor
		end
	end
	md.props.Scale = newScale
	if not primaryPart(md) and md.props.WorldPivotData == nil then
		md.props.WorldPivotData = pivot
	end
end

-- BasePart -------------------------------------------------------------------------------------

local function degrees(x: number, y: number, z: number): Vector3
	return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
end

local function cframeChanged(d: Data)
	if d.signals or d.propSignals then
		Dom.changed(d.u, "CFrame")
		Dom.changed(d.u, "Position")
		Dom.changed(d.u, "Orientation")
	end
end

Dom.define("BasePart", {
	CFrame = {
		get = function(_, d)
			return d.props.CFrame or CFrame.identity
		end,
		set = function(_, d, value)
			d.props.CFrame = Dom.check("CFrame", value, "CFrame")
			cframeChanged(d)
		end,
	},
	Position = {
		get = function(_, d)
			return partCF(d).Position
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "Position")
			d.props.CFrame = CFrame.new(value) * partCF(d).Rotation
			cframeChanged(d)
		end,
	},
	Orientation = {
		get = function(_, d)
			return degrees(partCF(d):ToOrientation())
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "Orientation")
			d.props.CFrame = CFrame.new(partCF(d).Position)
				* CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
			cframeChanged(d)
		end,
	},
	Rotation = {
		get = function(_, d)
			return degrees(partCF(d):ToEulerAnglesXYZ())
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "Rotation")
			d.props.CFrame = CFrame.new(partCF(d).Position)
				* CFrame.fromEulerAnglesXYZ(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
			cframeChanged(d)
		end,
	},
	Mass = {
		get = function(_, d)
			local s = partSize(d)
			return s.X * s.Y * s.Z * 0.7
		end,
		readOnly = true,
	},
	AssemblyMass = {
		get = function(_, d)
			local s = partSize(d)
			return s.X * s.Y * s.Z * 0.7
		end,
		readOnly = true,
	},
	GetMass = function(self)
		local s = partSize(Dom.data(self) :: Data)
		return s.X * s.Y * s.Z * 0.7
	end,
	GetPivot = function(self)
		return partPivot(Dom.data(self) :: Data)
	end,
	PivotTo = function(self, target)
		expectCFrame(target, "PivotTo")
		local pd = Dom.data(self) :: Data
		moveBy(pd, target * partPivot(pd):Inverse(), true)
	end,
	GetTouchingParts = function()
		return {}
	end,
	GetConnectedParts = function(self)
		return { self }
	end,
})

-- Model ----------------------------------------------------------------------------------------

Dom.define("Model", {
	WorldPivot = {
		get = function(_, d)
			return d.props.WorldPivotData or modelPivot(d)
		end,
		set = function(_, d, value)
			d.props.WorldPivotData = Dom.check("CFrame", value, "WorldPivot")
		end,
	},
	GetPivot = function(self)
		return modelPivot(Dom.data(self) :: Data)
	end,
	PivotTo = function(self, target)
		expectCFrame(target, "PivotTo")
		modelPivotTo(Dom.data(self) :: Data, target)
	end,
	GetBoundingBox = function(self)
		local md = Dom.data(self) :: Data
		local cf, size = boundingBox(baseParts(md, false), boxOrientation(md))
		return cf or modelPivot(md), size
	end,
	GetExtentsSize = function(self)
		local md = Dom.data(self) :: Data
		local _, size = boundingBox(baseParts(md, false), boxOrientation(md))
		return size
	end,
	GetModelSize = function(self)
		local md = Dom.data(self) :: Data
		local _, size = boundingBox(baseParts(md, false), boxOrientation(md))
		return size
	end,
	GetModelCFrame = function(self)
		local md = Dom.data(self) :: Data
		local cf = boundingBox(baseParts(md, false), boxOrientation(md))
		return cf or modelPivot(md)
	end,
	GetScale = function(self)
		return (Dom.data(self) :: Data).props.Scale or 1
	end,
	ScaleTo = function(self, scale)
		scaleModel(Dom.data(self) :: Data, scale)
	end,
	MoveTo = function(self, position)
		if typeof(position) ~= "Vector3" then
			error(
				("invalid argument #1 to 'MoveTo' (Vector3 expected, got %s)"):format(
					typeof(position)
				),
				2
			)
		end
		local md = Dom.data(self) :: Data
		local pp = primaryPart(md)
		local from: Vector3
		if pp then
			from = partCF(pp).Position
		else
			local box = boundingBox(baseParts(md, false), CFrame.identity)
			from = if box then box.Position else modelPivot(md).Position
		end
		local delta = CFrame.new(position - from)
		moveBy(md, delta, false)
		if md.props.WorldPivotData then
			md.props.WorldPivotData = delta * md.props.WorldPivotData
		end
	end,
	TranslateBy = function(self, offset)
		if typeof(offset) ~= "Vector3" then
			error(
				("invalid argument #1 to 'TranslateBy' (Vector3 expected, got %s)"):format(
					typeof(offset)
				),
				2
			)
		end
		local md = Dom.data(self) :: Data
		local delta = CFrame.new(offset)
		moveBy(md, delta, false)
		if md.props.WorldPivotData then
			md.props.WorldPivotData = delta * md.props.WorldPivotData
		end
	end,
	SetPrimaryPartCFrame = function(self, cf)
		expectCFrame(cf, "SetPrimaryPartCFrame")
		local md = Dom.data(self) :: Data
		local pp = primaryPart(md)
		if not pp then
			error(
				"Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set, or the PrimaryPart no longer exists. Please set Model.PrimaryPart before using this.",
				2
			)
		end
		moveBy(md, cf * partCF(pp):Inverse(), false)
	end,
	GetPrimaryPartCFrame = function(self)
		local pp = primaryPart(Dom.data(self) :: Data)
		if not pp then
			error(
				"Model:GetPrimaryPartCFrame() failed because no PrimaryPart has been set, or the PrimaryPart no longer exists. Please set Model.PrimaryPart before using this.",
				2
			)
		end
		return partCF(pp)
	end,
})

-- Attachment -----------------------------------------------------------------------------------

local function attachmentCF(d: Data): CFrame
	return d.props.CFrame or CFrame.identity
end

local function parentCF(d: Data): CFrame
	local p = d.parent
	if p and isBasePart(p) then
		return partCF(p)
	end
	return CFrame.identity
end

Dom.define("Attachment", {
	Position = {
		get = function(_, d)
			return attachmentCF(d).Position
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "Position")
			d.props.CFrame = CFrame.new(value) * attachmentCF(d).Rotation
			Dom.changed(d.u, "Position")
		end,
	},
	Orientation = {
		get = function(_, d)
			return degrees(attachmentCF(d):ToOrientation())
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "Orientation")
			d.props.CFrame = CFrame.new(attachmentCF(d).Position)
				* CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
		end,
	},
	WorldCFrame = {
		get = function(_, d)
			return parentCF(d) * attachmentCF(d)
		end,
		set = function(_, d, value)
			value = Dom.check("CFrame", value, "WorldCFrame")
			d.props.CFrame = parentCF(d):ToObjectSpace(value)
		end,
	},
	WorldPosition = {
		get = function(_, d)
			return (parentCF(d) * attachmentCF(d)).Position
		end,
		set = function(_, d, value)
			value = Dom.check("Vector3", value, "WorldPosition")
			local world = CFrame.new(value) * (parentCF(d) * attachmentCF(d)).Rotation
			d.props.CFrame = parentCF(d):ToObjectSpace(world)
		end,
	},
	WorldOrientation = {
		get = function(_, d)
			return degrees((parentCF(d) * attachmentCF(d)):ToOrientation())
		end,
		readOnly = true,
	},
	Axis = {
		get = function(_, d)
			return attachmentCF(d).RightVector
		end,
		readOnly = true,
	},
	SecondaryAxis = {
		get = function(_, d)
			return attachmentCF(d).UpVector
		end,
		readOnly = true,
	},
	WorldAxis = {
		get = function(_, d)
			return (parentCF(d) * attachmentCF(d)).RightVector
		end,
		readOnly = true,
	},
	WorldSecondaryAxis = {
		get = function(_, d)
			return (parentCF(d) * attachmentCF(d)).UpVector
		end,
		readOnly = true,
	},
})

-- Humanoid -------------------------------------------------------------------------------------

local function maxHealth(d: Data): number
	return Dom.get(d.u, "MaxHealth") :: number
end

local function setHealth(d: Data, value: number)
	local old = d.props.Health or maxHealth(d)
	local new = math.clamp(value, 0, maxHealth(d))
	d.props.Health = new
	if new ~= old then
		Dom.changed(d.u, "Health")
		Dom.emit(d.u, "HealthChanged", new)
		if new <= 0 and old > 0 then
			Dom.emit(d.u, "Died")
		end
	end
end

local function rootPart(d: Data): Data?
	local model = d.parent
	if not model then
		return nil
	end
	for _, child in model.children do
		if child.Name == "HumanoidRootPart" and isBasePart(child) then
			return child
		end
	end
	local pp = model.props.PrimaryPart
	return pp and Dom.data(pp)
end

Dom.define("Humanoid", {
	Health = {
		get = function(_, d)
			return d.props.Health or maxHealth(d)
		end,
		set = function(_, d, value)
			setHealth(d, Dom.check("Float32", value, "Health"))
		end,
	},
	RootPart = {
		get = function(_, d)
			local root = rootPart(d)
			return root and root.u
		end,
		readOnly = true,
	},
	TakeDamage = function(self, amount)
		local d = Dom.data(self) :: Data
		local model = d.parent
		if model then
			for _, child in model.children do
				if child.ClassName == "ForceField" then
					return
				end
			end
		end
		setHealth(d, (d.props.Health or maxHealth(d)) - (tonumber(amount) or 0))
	end,
	GetState = function(self)
		local d = Dom.data(self) :: Data
		return d.props.__State
			or (
				if (d.props.Health or maxHealth(d)) <= 0
					then Enum.HumanoidStateType.Dead
					else Enum.HumanoidStateType.Running
			)
	end,
	ChangeState = function(self, state)
		local d = Dom.data(self) :: Data
		local old = Dom.data(self) and (self :: any):GetState()
		d.props.__State = state
		Dom.emit(self, "StateChanged", old, state)
	end,
	-- Walks the root part straight to the point over virtual time (WalkSpeed studs/s).
	MoveTo = function(self, position, part)
		local d = Dom.data(self) :: Data
		local w = d.world
		d.props.WalkToPoint = position
		d.props.WalkToPart = part
		d.props.__MoveToken = (d.props.__MoveToken or 0) + 1
		local token = d.props.__MoveToken
		local root = rootPart(d)
		if not (w and root and typeof(position) == "Vector3") then
			return
		end
		local from = partCF(root).Position
		local flat = Vector3.new(position.X, from.Y, position.Z)
		local speed = math.max(Dom.get(self, "WalkSpeed") :: number, 0.01)
		local duration = (flat - from).Magnitude / speed
		w.scheduler:delay(duration, function()
			if d.props.__MoveToken ~= token then
				return
			end
			local model = d.parent
			if model and model.class.isA.Model then
				local current = partCF(root)
				local target = CFrame.new(flat) * current.Rotation
				moveBy(model, target * current:Inverse(), false)
			end
			Dom.emit(self, "MoveToFinished", true)
		end)
	end,
	LoadAnimation = function(self, animation)
		local d = Dom.data(self) :: Data
		local track = Dom.new(d.world, "AnimationTrack", true)
		Dom.rawSet(track, "Animation", animation)
		return track
	end,
})

Dom.define("Animator", {
	LoadAnimation = function(self, animation)
		local d = Dom.data(self) :: Data
		local track = Dom.new(d.world, "AnimationTrack", true)
		Dom.rawSet(track, "Animation", animation)
		return track
	end,
})

Dom.define("AnimationTrack", {
	Play = function(self)
		Dom.rawSet(self, "IsPlaying", true)
	end,
	Stop = function(self)
		Dom.rawSet(self, "IsPlaying", false)
		Dom.emit(self, "Stopped")
	end,
})

-- Sound: no audio, but Play / Stop keep Playing and IsPlaying honest.

local function setPlaying(self, playing: boolean)
	Dom.rawSet(self, "Playing", playing)
	Dom.rawSet(self, "IsPlaying", playing)
	Dom.changed(self, "Playing")
end

Dom.define("Sound", {
	Play = function(self)
		local w = (Dom.data(self) :: Data).world
		if w then
			w:recordCall("Sound", "Play", self)
		end
		setPlaying(self, true)
		Dom.emit(self, "Played", Dom.get(self, "SoundId"))
	end,
	Resume = function(self)
		setPlaying(self, true)
	end,
	Pause = function(self)
		setPlaying(self, false)
		Dom.emit(self, "Paused", Dom.get(self, "SoundId"))
	end,
	Stop = function(self)
		setPlaying(self, false)
		Dom.emit(self, "Stopped", Dom.get(self, "SoundId"))
	end,
})

-- Camera ---------------------------------------------------------------------------------------

local function viewport(d: Data): Vector2
	local v = d.props.ViewportSize
	return if v and v.X > 0 then v else Vector2.new(1280, 720)
end

local function project(d: Data, world: Vector3): (Vector3, boolean)
	local cf = d.props.CFrame or CFrame.identity
	local p = cf:PointToObjectSpace(world)
	local depth = -p.Z
	local size = viewport(d)
	local h = math.tan(math.rad(Dom.get(d.u, "FieldOfView") :: number) / 2)
	local aspect = size.X / size.Y
	local x = if depth ~= 0 then p.X / (depth * h * aspect) else 0
	local y = if depth ~= 0 then p.Y / (depth * h) else 0
	local onScreen = depth > 0 and math.abs(x) <= 1 and math.abs(y) <= 1
	return Vector3.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y, depth), onScreen
end

local function rayThrough(d: Data, x: number, y: number, depth: number?)
	local cf = d.props.CFrame or CFrame.identity
	local size = viewport(d)
	local h = math.tan(math.rad(Dom.get(d.u, "FieldOfView") :: number) / 2)
	local nx = (x / size.X) * 2 - 1
	local ny = 1 - (y / size.Y) * 2
	local dir = cf:VectorToWorldSpace(Vector3.new(nx * h * size.X / size.Y, ny * h, -1)).Unit
	return roblox.Ray.new(cf.Position + dir * (depth or 0), dir)
end

Dom.define("Camera", {
	ViewportSize = {
		get = function(_, d)
			return viewport(d)
		end,
		set = function(_, d, value)
			d.props.ViewportSize = value
		end,
	},
	WorldToViewportPoint = function(self, point)
		return project(Dom.data(self) :: Data, point)
	end,
	WorldToScreenPoint = function(self, point)
		return project(Dom.data(self) :: Data, point)
	end,
	ViewportPointToRay = function(self, x, y, depth)
		return rayThrough(Dom.data(self) :: Data, x, y, depth)
	end,
	ScreenPointToRay = function(self, x, y, depth)
		return rayThrough(Dom.data(self) :: Data, x, y, depth)
	end,
	GetPivot = function(self)
		return (Dom.data(self) :: Data).props.CFrame or CFrame.identity
	end,
	PivotTo = function(self, cf)
		expectCFrame(cf, "PivotTo")
		Dom.set(self, "CFrame", cf)
	end,
})

-- Spatial queries --------------------------------------------------------------------------------

-- Ray (in part-local space) against a box of `size`: entry t in [0, 1] and the local normal.
local function rayBox(o: Vector3, dir: Vector3, size: Vector3): (number?, Vector3?)
	local tmin, tmax = -math.huge, math.huge
	local normal = nil
	for _, axis in { "X", "Y", "Z" } do
		local oc, dc, h = (o :: any)[axis], (dir :: any)[axis], (size :: any)[axis] / 2
		if math.abs(dc) < 1e-12 then
			if oc < -h or oc > h then
				return nil
			end
		else
			local t1, t2 = (-h - oc) / dc, (h - oc) / dc
			local sign = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				sign = 1
			end
			if t1 > tmin then
				tmin = t1
				normal = if axis == "X"
					then Vector3.new(sign, 0, 0)
					elseif axis == "Y" then Vector3.new(0, sign, 0)
					else Vector3.new(0, 0, sign)
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	if tmin < 0 or tmin > 1 or not normal then
		return nil -- starts inside (Roblox ignores those) or out of reach
	end
	return tmin, normal
end

local function rayBall(o: Vector3, dir: Vector3, radius: number): (number?, Vector3?)
	local a = dir:Dot(dir)
	local b = 2 * o:Dot(dir)
	local c = o:Dot(o) - radius * radius
	local disc = b * b - 4 * a * c
	if a == 0 or disc < 0 or c < 0 then
		return nil
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	if t < 0 or t > 1 then
		return nil
	end
	return t, (o + dir * t).Unit
end

-- Roblox cylinders run along the part's X axis.
local function rayCylinder(o: Vector3, dir: Vector3, size: Vector3): (number?, Vector3?)
	local r = math.min(size.Y, size.Z) / 2
	local h = size.X / 2
	if math.abs(o.X) <= h and o.Y * o.Y + o.Z * o.Z <= r * r then
		return nil
	end
	local best, normal = nil, nil
	local a = dir.Y * dir.Y + dir.Z * dir.Z
	if a > 1e-12 then
		local b = 2 * (o.Y * dir.Y + o.Z * dir.Z)
		local c = o.Y * o.Y + o.Z * o.Z - r * r
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			local t = (-b - math.sqrt(disc)) / (2 * a)
			local x = o.X + dir.X * t
			if t >= 0 and t <= 1 and math.abs(x) <= h then
				best = t
				local p = o + dir * t
				normal = Vector3.new(0, p.Y, p.Z).Unit
			end
		end
	end
	if math.abs(dir.X) > 1e-12 then
		for _, side in { -1, 1 } do
			local t = (side * h - o.X) / dir.X
			if t >= 0 and t <= 1 and (not best or t < best) then
				local p = o + dir * t
				if p.Y * p.Y + p.Z * p.Z <= r * r then
					best, normal = t, Vector3.new(side, 0, 0)
				end
			end
		end
	end
	return best, normal
end

local function filterSet(params: any): ({ [Data]: boolean }, boolean)
	local set = {}
	local include = false
	if params then
		include = params.FilterType == Enum.RaycastFilterType.Include
		for _, inst in params.FilterDescendantsInstances or {} do
			local d = Dom.data(inst)
			if d then
				set[d] = true
			end
		end
	end
	return set, include
end

local function passes(pd: Data, set: { [Data]: boolean }, include: boolean): boolean
	local x: Data? = pd
	while x do
		if set[x] then
			return include
		end
		x = x.parent
	end
	return not include
end

local function queryable(pd: Data, respectCanCollide: boolean): boolean
	local canCollide = Dom.get(pd.u, "CanCollide")
	if respectCanCollide then
		return canCollide == true
	end
	return canCollide == true or Dom.get(pd.u, "CanQuery") == true
end

local function candidates(root: Data, params: any): { Data }
	local set, include = filterSet(params)
	local respect = params ~= nil and params.RespectCanCollide == true
	local out = {}
	for _, pd in baseParts(root, false) do
		if queryable(pd, respect) and passes(pd, set, include) then
			table.insert(out, pd)
		end
	end
	return out
end

function Engine.raycast(root: Data, origin: Vector3, direction: Vector3, params: any): any
	local best, bestPart, bestNormal = math.huge, nil, nil
	for _, pd in candidates(root, params) do
		local cf = partCF(pd)
		local o = cf:PointToObjectSpace(origin)
		local dir = cf:VectorToObjectSpace(direction)
		local size = partSize(pd)
		local shape = pd.props.Shape
		local t, n
		if shape == Enum.PartType.Ball then
			t, n = rayBall(o, dir, math.min(size.X, size.Y, size.Z) / 2)
		elseif shape == Enum.PartType.Cylinder then
			t, n = rayCylinder(o, dir, size)
		else
			t, n = rayBox(o, dir, size)
		end
		if t and t < best then
			best, bestPart, bestNormal = t, pd, cf:VectorToWorldSpace(n)
		end
	end
	if not bestPart then
		return nil
	end
	return setmetatable({
		Instance = bestPart.u,
		Position = origin + direction * best,
		Normal = bestNormal,
		Distance = direction.Magnitude * best,
		Material = Dom.get(bestPart.u, "Material"),
	}, {
		__type = "RaycastResult",
		__tostring = function()
			return "RaycastResult{" .. bestPart.Name .. "}"
		end,
	})
end

-- World-space axis-aligned bounds of a part.
local function aabb(pd: Data): (Vector3, Vector3)
	local cf = partCF(pd)
	local half = partSize(pd) / 2
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local e = Vector3.new(
		math.abs(r00) * half.X + math.abs(r01) * half.Y + math.abs(r02) * half.Z,
		math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z,
		math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
	)
	return cf.Position - e, cf.Position + e
end

local function overlaps(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3): boolean
	return minA.X <= maxB.X
		and maxA.X >= minB.X
		and minA.Y <= maxB.Y
		and maxA.Y >= minB.Y
		and minA.Z <= maxB.Z
		and maxA.Z >= minB.Z
end

local function capped(list: { any }, params: any): { any }
	local max = params and params.MaxParts or 0
	if max > 0 and #list > max then
		local out = {}
		for i = 1, max do
			out[i] = list[i]
		end
		return out
	end
	return list
end

function Engine.partsInBox(root: Data, cf: CFrame, size: Vector3, params: any): { any }
	local fake = { props = { CFrame = cf, Size = size } } :: any
	local qmin, qmax = aabb(fake)
	local out = {}
	for _, pd in candidates(root, params) do
		local pmin, pmax = aabb(pd)
		if overlaps(pmin, pmax, qmin, qmax) then
			table.insert(out, pd.u)
		end
	end
	return capped(out, params)
end

function Engine.partsInRadius(root: Data, centre: Vector3, radius: number, params: any): { any }
	local out = {}
	for _, pd in candidates(root, params) do
		local pmin, pmax = aabb(pd)
		local closest = centre:Max(pmin):Min(pmax)
		if (closest - centre).Magnitude <= radius then
			table.insert(out, pd.u)
		end
	end
	return capped(out, params)
end

local function worldRootOf(self): Data
	return Dom.data(self) :: Data
end

Dom.define("WorldRoot", {
	Raycast = function(self, origin, direction, params)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			error(
				"Raycast expects (origin: Vector3, direction: Vector3, params: RaycastParams?)",
				2
			)
		end
		if params ~= nil and typeof(params) ~= "RaycastParams" then
			error(
				("invalid argument #3 to 'Raycast' (RaycastParams expected, got %s)"):format(
					typeof(params)
				),
				2
			)
		end
		return Engine.raycast(worldRootOf(self), origin, direction, params)
	end,
	GetPartBoundsInBox = function(self, cf, size, params)
		return Engine.partsInBox(worldRootOf(self), cf, size, params)
	end,
	GetPartBoundsInRadius = function(self, position, radius, params)
		return Engine.partsInRadius(worldRootOf(self), position, radius, params)
	end,
	GetPartsInPart = function(self, part, params)
		local pd = Dom.data(part) :: Data
		local out = {}
		for _, other in Engine.partsInBox(worldRootOf(self), partCF(pd), partSize(pd), params) do
			if other ~= part then
				table.insert(out, other)
			end
		end
		return out
	end,
	BulkMoveTo = function(_, parts, cframes)
		if type(parts) ~= "table" or type(cframes) ~= "table" or #parts ~= #cframes then
			error("BulkMoveTo expects two arrays of the same length (parts, CFrames)", 2)
		end
		for i, p in parts do
			local pd = Dom.data(p)
			if not pd or not isBasePart(pd) then
				error(("BulkMoveTo: item %d is not a BasePart"):format(i), 2)
			end
			expectCFrame(cframes[i], "BulkMoveTo")
			setCF(pd, cframes[i])
		end
	end,
	Spherecast = function()
		return nil
	end,
	Blockcast = function()
		return nil
	end,
	Shapecast = function()
		return nil
	end,
})

return Engine
