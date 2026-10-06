--!strict
--[[
	Decorations shared by the Hide & Seek maps (src/server/Maps/PumpkinFarm.luau and
	HedgeMaze.luau). Each one is a Kit.prop, so a Model with the same name in
	ReplicatedStorage.Custom.Props replaces every copy (see docs/CUSTOMIZE.md).

	The seeker hut is the one functional piece: a closed shed whose door is tagged SeekerDoor
	(it swings open when the seekers are let out) with parts tagged SeekerSpawn inside.

	Every function takes `cf` = where the prop stands (the middle of its bottom, facing
	cf.LookVector) and a colour table with the keys it needs. Random numbers are drawn before
	Kit.prop, so a custom model never changes where the rest of the map goes.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)

local HideSeekProps = {}

-- An oval (a block with a sphere mesh fills its whole size; a Ball part is always round).
function HideSeekProps.oval(props: { [string]: any }, parent: Instance, solid: boolean?): Part
	local p = if solid then Kit.part(props, parent) else Kit.decor(props, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A slightly different shade of `color` each time (rng), so copies don't look identical.
function HideSeekProps.jitter(color: Color3, rng: Random, amount: number): Color3
	return Kit.shade(color, rng:NextNumber(-amount, amount))
end

-- A lamp post with a warm glowing lantern hanging from its arm (prop "Lamppost").
function HideSeekProps.lantern(cf: CFrame, colors: any, parent: Instance): Model
	return Kit.prop("Lamppost", cf, parent, 9, function()
		local m = Kit.model("Lamppost", parent)
		m.PrimaryPart = Kit.part({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(8.4, 0.5, 0.5),
			CFrame = Kit.upright(cf * CFrame.new(0, 4.2, 0)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Foot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 1.1, 1.1),
			CFrame = Kit.upright(cf * CFrame.new(0, 0.3, 0)),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Arm",
			Size = Vector3.new(0.25, 0.25, 2),
			CFrame = cf * CFrame.new(0, 8.2, -0.9),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		Kit.decor({
			Name = "Cap",
			Size = Vector3.new(1.3, 0.3, 1.3),
			CFrame = cf * CFrame.new(0, 7.75, -1.8),
			Color = colors.Iron,
			Material = Enum.Material.Metal,
		}, m)
		local glass = Kit.decor({
			Name = "Lamp",
			Size = Vector3.new(0.9, 1.2, 0.9),
			CFrame = cf * CFrame.new(0, 7, -1.8),
			Color = colors.Glow,
			Material = Enum.Material.Neon,
		}, m)
		Kit.light(glass, colors.Glow, 22, 1.3, true)
		return m
	end, { Light = { Color = colors.Glow, Range = 22, Brightness = 1.3, Height = 0.8 } })
end

-- A rectangular hay bale with two dark twine bands.
function HideSeekProps.hayBale(cf: CFrame, colors: any, rng: Random, parent: Instance): Model
	local hay = HideSeekProps.jitter(colors.Hay, rng, 0.06)
	return Kit.prop("HayBale", cf, parent, 2.4, function()
		local m = Kit.model("HayBale", parent)
		local size = Vector3.new(4.4, 2.4, 2.6)
		m.PrimaryPart = Kit.part({
			Name = "Hay",
			Size = size,
			CFrame = cf * CFrame.new(0, size.Y / 2, 0),
			Color = hay,
			Material = Enum.Material.Fabric,
		}, m)
		for _, x in { -1.1, 1.1 } do
			Kit.decor({
				Name = "Twine",
				Size = Vector3.new(0.18, size.Y + 0.06, size.Z + 0.06),
				CFrame = cf * CFrame.new(x, size.Y / 2, 0),
				Color = colors.Wood,
			}, m)
		end
		return m
	end)
end

-- A round hay roll lying on its side.
function HideSeekProps.hayRoll(cf: CFrame, colors: any, rng: Random, parent: Instance): Model
	local hay = HideSeekProps.jitter(colors.Hay, rng, 0.06)
	return Kit.prop("HayRoll", cf, parent, 4.6, function()
		local m = Kit.model("HayRoll", parent)
		m.PrimaryPart = Kit.part({
			Name = "Hay",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 4.6, 4.6),
			CFrame = cf * CFrame.new(0, 2.3, 0),
			Color = hay,
			Material = Enum.Material.Fabric,
		}, m)
		Kit.decor({
			Name = "Swirl",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.06, 2.2, 2.2),
			CFrame = cf * CFrame.new(0, 2.3, 0),
			Color = Kit.shade(colors.Hay, 0.15),
			Material = Enum.Material.Fabric,
		}, m)
		return m
	end)
end

-- A tree in autumn colours: a leaning trunk and a few round leaf clumps (prop "AutumnTree").
function HideSeekProps.autumnTree(
	cf: CFrame,
	height: number,
	leafColors: { Color3 },
	trunkColor: Color3,
	rng: Random,
	parent: Instance
): Model
	-- Every random number first (in the order the tree always drew them).
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	local width = height * 0.62
	local clumps = {}
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local w = width * rng:NextNumber(0.6, 0.8)
		local rise = rng:NextNumber(-0.6, 1.2)
		local color = HideSeekProps.jitter(leafColors[rng:NextInteger(1, #leafColors)], rng, 0.08)
		clumps[i] = { Angle = angle, Width = w, Rise = rise, Color = color }
	end
	local pileX = rng:NextNumber(-1, 1)
	local pileZ = rng:NextNumber(-1, 1)
	local pileColor = HideSeekProps.jitter(leafColors[1], rng, 0.1)
	return Kit.prop("AutumnTree", cf, parent, height, function()
		local m = Kit.model("AutumnTree", parent)
		local trunkHeight = height * 0.55
		m.PrimaryPart = Kit.part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(trunkHeight + 1, 1.8, 1.8),
			CFrame = Kit.upright(cf * lean * CFrame.new(0, trunkHeight / 2, 0)),
			Color = trunkColor,
			Material = Enum.Material.Wood,
		}, m)
		local top = cf * lean * CFrame.new(0, trunkHeight, 0)
		for i, clump in clumps do
			local r = if i == 1 then 0 else width * 0.22
			local w = clump.Width
			HideSeekProps.oval({
				Name = "Leaves",
				Size = Vector3.new(w, w * 0.8, w),
				CFrame = top * CFrame.new(
					math.cos(clump.Angle) * r,
					height * 0.18 + clump.Rise + (if i == 1 then height * 0.08 else 0),
					math.sin(clump.Angle) * r
				),
				Color = clump.Color,
				Material = Enum.Material.LeafyGrass,
			}, m)
		end
		-- Fallen leaves round the foot.
		HideSeekProps.oval({
			Name = "LeafPile",
			Size = Vector3.new(width * 0.7, 0.4, width * 0.6),
			CFrame = cf * CFrame.new(pileX, 0.1, pileZ),
			Color = pileColor,
			Material = Enum.Material.LeafyGrass,
		}, m)
		return m
	end)
end

-- A wooden rail fence from `a` to `b` (floor points), with posts every `spacing` studs.
function HideSeekProps.railFence(
	a: Vector3,
	b: Vector3,
	height: number,
	color: Color3,
	parent: Instance
)
	local m = Kit.model("Fence", parent)
	local offset = b - a
	local length = offset.Magnitude
	if length < 1 then
		return m
	end
	local along = CFrame.lookAt(a, b)
	local posts = math.max(1, math.floor(length / 6 + 0.5))
	for i = 0, posts do
		Kit.part({
			Name = "Post",
			Size = Vector3.new(0.6, height + 0.4, 0.6),
			CFrame = along * CFrame.new(0, (height + 0.4) / 2, -length * i / posts),
			Color = Kit.shade(color, 0.12),
			Material = Enum.Material.Wood,
		}, m)
	end
	for _, y in { height * 0.45, height * 0.85 } do
		Kit.part({
			Name = "Rail",
			Size = Vector3.new(0.3, 0.45, length),
			CFrame = along * CFrame.new(0, y, -length / 2),
			Color = color,
			Material = Enum.Material.Wood,
		}, m)
	end
	return m
end

-- A park bench (stone or wood seat on iron legs) facing cf.LookVector.
function HideSeekProps.bench(cf: CFrame, colors: any, parent: Instance): Model
	return Kit.prop("Bench", cf, parent, 3.2, function()
		local m = Kit.model("Bench", parent)
		Kit.part({
			Name = "Seat",
			Size = Vector3.new(5, 0.4, 1.6),
			CFrame = cf * CFrame.new(0, 1.6, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		Kit.decor({
			Name = "Back",
			Size = Vector3.new(5, 1.1, 0.3),
			CFrame = cf * CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = colors.Wood,
			Material = Enum.Material.Wood,
		}, m)
		for _, x in { -2.1, 2.1 } do
			Kit.decor({
				Name = "Leg",
				Size = Vector3.new(0.3, 1.6, 1.4),
				CFrame = cf * CFrame.new(x, 0.8, 0),
				Color = colors.Iron,
				Material = Enum.Material.Metal,
			}, m)
		end
		return m
	end)
end

--[[
	The seeker hut: a closed garden shed. `cf` is the middle of its floor; the door is in the
	wall facing cf.LookVector. `inner` = the room inside (width, wall height, depth).
	The door (one part, tag SeekerDoor) swings open round its left edge when the seekers are
	let out; `spawns` parts tagged SeekerSpawn stand inside, facing the door.
	colors: Wall, Roof, Trim, Door, Glow, Text.
]]
function HideSeekProps.seekerHut(
	cf: CFrame,
	inner: Vector3,
	colors: any,
	spawns: number,
	parent: Instance
): Model
	local m = Kit.model("SeekerHut", parent)
	local w, h, d = inner.X, inner.Y, inner.Z
	local t = 1 -- wall thickness
	local doorWidth, doorHeight = 6, math.min(8, h - 1)

	Kit.part({
		Name = "HutFloor",
		Size = Vector3.new(w + t * 2, 0.6, d + t * 2),
		CFrame = cf * CFrame.new(0, 0.3, 0),
		Color = colors.Trim,
		Material = Enum.Material.WoodPlanks,
	}, m)
	local floorTop = 0.6
	local function wall(name: string, size: Vector3, offset: Vector3)
		Kit.part({
			Name = name,
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = colors.Wall,
			Material = Enum.Material.WoodPlanks,
		}, m)
	end
	local wallY = floorTop + h / 2
	wall("BackWall", Vector3.new(w + t * 2, h, t), Vector3.new(0, wallY, d / 2 + t / 2))
	wall("SideWall", Vector3.new(t, h, d), Vector3.new(-w / 2 - t / 2, wallY, 0))
	wall("SideWall", Vector3.new(t, h, d), Vector3.new(w / 2 + t / 2, wallY, 0))
	-- Front wall: two pieces either side of the door and one above it.
	local side = (w + t * 2 - doorWidth) / 2
	for _, sign in { -1, 1 } do
		wall(
			"FrontWall",
			Vector3.new(side, h, t),
			Vector3.new(sign * (doorWidth / 2 + side / 2), wallY, -d / 2 - t / 2)
		)
	end
	wall(
		"FrontWall",
		Vector3.new(doorWidth, h - doorHeight, t),
		Vector3.new(0, floorTop + doorHeight + (h - doorHeight) / 2, -d / 2 - t / 2)
	)
	-- Corner trims.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Kit.decor({
				Name = "Trim",
				Size = Vector3.new(t + 0.3, h, t + 0.3),
				CFrame = cf * CFrame.new(x * (w / 2 + t / 2), wallY, z * (d / 2 + t / 2)),
				Color = colors.Trim,
				Material = Enum.Material.Wood,
			}, m)
		end
	end

	-- The door: one part so it can swing; its front faces out.
	local door = Kit.part({
		Name = "SeekerDoor",
		Size = Vector3.new(doorWidth - 0.2, doorHeight - 0.1, 0.5),
		CFrame = cf * CFrame.new(0, floorTop + doorHeight / 2, -d / 2 - t / 2),
		Color = colors.Door,
		Material = Enum.Material.WoodPlanks,
	}, m)
	CollectionService:AddTag(door, Tags.SeekerDoor)
	Kit.surfaceText(door, "NO\nPEEKING!", colors.Text, Enum.NormalId.Front)

	-- Pitched roof (ridge from front to back) with a candy-striped edge.
	local overhang = 1.2
	local half = (w + t * 2) / 2 + overhang
	local rise = 5
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	local roofDepth = d + t * 2 + overhang * 2
	for _, sign in { -1, 1 } do
		Kit.part({
			Name = "Roof",
			Size = Vector3.new(slope, 0.6, roofDepth),
			CFrame = cf
				* CFrame.new(sign * half / 2, floorTop + h + rise / 2, 0)
				* CFrame.Angles(0, 0, -sign * angle),
			Color = colors.Roof,
			Material = Enum.Material.Slate,
		}, m)
	end
	-- Gable ends: two wedges each, filling the triangles under the roof.
	for _, z in { -1, 1 } do
		for _, sign in { -1, 1 } do
			Kit.wedge({
				Name = "Gable",
				Size = Vector3.new(t, rise, (w + t * 2) / 2),
				CFrame = cf * CFrame.new(
					sign * (w + t * 2) / 4,
					floorTop + h + rise / 2,
					z * (d / 2 + t / 2)
				) * CFrame.Angles(0, math.rad(-90 * sign), 0),
				Color = colors.Wall,
				Material = Enum.Material.WoodPlanks,
			}, m)
		end
	end
	for i = -3, 3 do
		Kit.decor({
			Name = "Stripe",
			Size = Vector3.new(1.4, 0.7, 0.4),
			CFrame = cf * CFrame.new(i * 1.9, floorTop + h + 0.2, -roofDepth / 2 + 0.2),
			Color = if i % 2 == 0 then colors.Text else colors.Door,
		}, m)
	end
	-- Sign over the door.
	local sign = Kit.part({
		Name = "Sign",
		Size = Vector3.new(doorWidth + 2, 1.6, 0.3),
		CFrame = cf * CFrame.new(0, floorTop + doorHeight + 1.2, -d / 2 - t - 0.2),
		Color = colors.Trim,
		Material = Enum.Material.Wood,
		CanCollide = false,
	}, m)
	Kit.surfaceText(sign, "SEEKER HUT", colors.Text, Enum.NormalId.Front)

	local lamp =
		Kit.holder("HutLight", cf * CFrame.new(0, floorTop + h - 1, 0), Vector3.new(1, 1, 1), m)
	Kit.light(lamp, colors.Glow, math.max(w, d), 0.6, false)
	local outside = Kit.decor({
		Name = "DoorLamp",
		Size = Vector3.new(0.7, 0.9, 0.7),
		CFrame = cf
			* CFrame.new(doorWidth / 2 + 1.2, floorTop + doorHeight - 0.5, -d / 2 - t - 0.5),
		Color = colors.Glow,
		Material = Enum.Material.Neon,
	}, m)
	Kit.light(outside, colors.Glow, 9, 0.6, true)

	-- Spawn pads inside, in a row facing the door.
	for i = 1, spawns do
		local x = (i - (spawns + 1) / 2) * math.min(3.5, (w - 3) / math.max(1, spawns - 1))
		local pad = Kit.holder(
			"SeekerSpawn",
			cf * CFrame.new(x, floorTop + 0.5, d * 0.15),
			Vector3.new(3, 1, 3),
			m
		)
		CollectionService:AddTag(pad, Tags.SeekerSpawn)
	end
	return m
end

-- A spawn pad for hiders (invisible), in the map's spawn folder.
function HideSeekProps.hiderSpawn(position: Vector3, rng: Random, folder: Instance): Part
	local pad = Kit.holder(
		"HiderSpawn",
		CFrame.new(position + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Vector3.new(6, 1, 6),
		folder
	)
	CollectionService:AddTag(pad, Tags.HiderSpawn)
	return pad
end

return HideSeekProps
