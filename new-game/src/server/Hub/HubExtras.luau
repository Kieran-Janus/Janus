--!strict
--[[
	Extra dressing for the spawn hub, built by HubBuilder.Build from Config.Hub.Polish:
	  - Terrain around the plaza: grass ground, gentle hills, mud patches (the default
	    Baseplate is hidden but stays solid underneath)
	  - a ring of dead-tree forest and a dark haunted mansion on a hill in the distance
	  - a Pumpkin King statue near the clock tower
	  - a pumpkin patch corner and a few extra graves
	  - an iron fence round the plaza with cobwebs and ground fog
	  - glowing stepping stones from the spawn pad to every NPC
	Everything except the Terrain goes into the hub Model (folder "Extras"), so there is still
	only ever one hub. Terrain is deterministic (seeded), so rebuilding refills the same shapes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local HubExtras = {}

local hubCfg = Config.Hub
local cfg = hubCfg.Polish
local colors = hubCfg.Colors

local function at(offset: Vector3): Vector3
	return hubCfg.Center + offset
end

local function facingCenter(position: Vector3): CFrame
	local target = Vector3.new(hubCfg.Center.X, position.Y, hubCfg.Center.Z)
	if (target - position).Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, target)
end

-- A random point in a ring around the hub centre (flat offset).
local function ringPoint(rng: Random, min: number, max: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(min, max)
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function buildTerrain(rng: Random)
	local t = cfg.Terrain
	if not t.Enabled then
		return
	end
	local terrain = workspace.Terrain
	-- Start clean, so a rebuild with new numbers doesn't keep old hills.
	-- (The terrain around the hub is all generated here; hand-made terrain in this area is lost.)
	terrain:FillCylinder(CFrame.new(at(Vector3.new(0, 35, 0))), 90, t.Radius, Enum.Material.Air)
	-- Grass ground level with Center (the top of the Baseplate)...
	terrain:FillCylinder(
		CFrame.new(at(Vector3.new(0, -t.Depth / 2, 0))),
		t.Depth,
		t.Radius,
		Enum.Material.Grass
	)
	-- ...except under the plaza, which sits on the (hidden) Baseplate: terrain there would
	-- poke through the 1-stud cobbles. The ring stops just inside the plaza's edge.
	terrain:FillCylinder(
		CFrame.new(at(Vector3.new(0, -t.Depth / 2, 0))),
		t.Depth + 8,
		hubCfg.Radius - 2,
		Enum.Material.Air
	)
	for _ = 1, t.MudPatches do
		local offset = ringPoint(rng, hubCfg.Radius + 8, t.HillRingMin)
		terrain:FillCylinder(
			CFrame.new(at(offset + Vector3.new(0, -0.6, 0))),
			1.2,
			rng:NextNumber(6, 13),
			Enum.Material.Mud
		)
	end
	for _ = 1, t.Hills do
		local radius = rng:NextNumber(t.HillMinRadius, t.HillMaxRadius)
		local offset = ringPoint(rng, t.HillRingMin, t.HillRingMax)
		terrain:FillBall(at(offset - Vector3.new(0, radius * 0.6, 0)), radius, Enum.Material.Grass)
	end
	local m = cfg.Mansion
	terrain:FillBall(
		at(m.Offset - Vector3.new(0, m.HillSink, 0)),
		m.HillRadius,
		Enum.Material.Grass
	)
	if t.HideBaseplate then
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate.Transparency = 1
			for _, d in baseplate:GetChildren() do
				if d:IsA("Texture") or d:IsA("Decal") then
					d.Transparency = 1
				end
			end
		end
	end
end

local function buildForest(parent: Instance, rng: Random)
	local f = cfg.Forest
	local folder = Kit.model("Forest", parent)
	local color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.45)
	for _ = 1, f.Count do
		local offset = ringPoint(rng, f.RingMin, f.RingMax)
		local base = CFrame.new(at(offset)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		Kit.deadTree(base, rng:NextNumber(f.MinHeight, f.MaxHeight), color, rng, folder)
	end
end

local function buildMansion(parent: Instance)
	local m = cfg.Mansion
	local folder = Kit.model("HauntedMansion", parent)
	local hillTop = m.HillRadius - m.HillSink
	local base = facingCenter(at(m.Offset + Vector3.new(0, hillTop - 2, 0)))
	local size: Vector3 = m.Size
	local function block(name: string, cf: CFrame, s: Vector3, color: Color3?, neon: boolean?)
		Kit.decor({
			Name = name,
			Size = s,
			CFrame = cf,
			Color = color or m.Color,
			Material = if neon then Enum.Material.Neon else Enum.Material.Slate,
		}, folder)
	end
	block("Body", base * CFrame.new(0, size.Y / 2, 0), size)
	-- Steep roof: two slabs meeting along the length.
	for _, side in { -1, 1 } do
		block(
			"Roof",
			base
				* CFrame.new(0, size.Y + 6, side * size.Z / 4)
				* CFrame.Angles(math.rad(side * 50), 0, 0),
			Vector3.new(size.X + 4, 1.5, size.Z * 0.8)
		)
	end
	-- Two crooked towers with pointy tops.
	for _, side in { -1, 1 } do
		local tower = base * CFrame.new(side * (size.X / 2 + 4), 0, 0)
		block("Tower", tower * CFrame.new(0, size.Y * 0.7, 0), Vector3.new(10, size.Y * 1.4, 10))
		block(
			"Spire",
			tower
				* CFrame.new(0, size.Y * 1.4 + 5, 0)
				* CFrame.Angles(0, math.rad(45), math.rad(side * 6)),
			Vector3.new(6, 10, 6)
		)
		block(
			"TowerWindow",
			tower * CFrame.new(0, size.Y, -5.2),
			Vector3.new(2.5, 3.5, 0.3),
			m.WindowColor,
			true
		)
	end
	-- Glowing windows on the front.
	for row = 0, 1 do
		for col = -2, 2 do
			if not (row == 0 and col == 0) then
				block(
					"Window",
					base * CFrame.new(col * 11, 9 + row * 11, -size.Z / 2 - 0.2),
					Vector3.new(4, 5, 0.3),
					m.WindowColor,
					true
				)
			end
		end
	end
	block("Door", base * CFrame.new(0, 5, -size.Z / 2 - 0.2), Vector3.new(6, 10, 0.3), colors.Iron)
end

local function buildStatue(parent: Instance)
	local s = cfg.KingStatue
	local folder = Kit.model("KingStatue", parent)
	local k = s.Height / 16 -- everything below is drawn for a 16-stud statue
	local base = facingCenter(at(s.Offset + Vector3.new(0, 1, 0)))
	local stone = colors.Stone
	Kit.part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3 * k, 9 * k, 9 * k),
		CFrame = Kit.upright(base * CFrame.new(0, 1.5 * k, 0)),
		Color = stone,
		Material = Enum.Material.Slate,
	}, folder)
	Kit.part({
		Name = "Robe",
		Size = Vector3.new(5 * k, 7 * k, 3.2 * k),
		CFrame = base * CFrame.new(0, 6.5 * k, 0),
		Color = colors.Purple:Lerp(stone, 0.4),
		Material = Enum.Material.Slate,
	}, folder)
	for _, side in { -1, 1 } do
		Kit.decor({
			Name = "Arm",
			Size = Vector3.new(1.4 * k, 5 * k, 1.4 * k),
			CFrame = base
				* CFrame.new(side * 3.3 * k, 7.5 * k, 0)
				* CFrame.Angles(0, 0, math.rad(side * 25)),
			Color = colors.Purple:Lerp(stone, 0.4),
			Material = Enum.Material.Slate,
		}, folder)
	end
	local headCf = base * CFrame.new(0, 12.4 * k, 0)
	local head = Kit.part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5.5 * k,
		CFrame = headCf,
		Color = colors.Orange,
	}, folder)
	Kit.carvedFace(headCf, 5.5 * k, colors.Glow, folder)
	Kit.light(head, colors.Orange, 30 * k, 1.5, true)
	Kit.decor({
		Name = "Crown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4 * k, 4 * k, 4 * k),
		CFrame = Kit.upright(base * CFrame.new(0, 15.6 * k, 0)),
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Metal,
	}, folder)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		Kit.decor({
			Name = "CrownSpike",
			Size = Vector3.new(0.7 * k, 1.4 * k, 0.7 * k),
			CFrame = base
				* CFrame.new(math.cos(a) * 1.6 * k, 16.8 * k, math.sin(a) * 1.6 * k)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(255, 210, 60),
			Material = Enum.Material.Metal,
		}, folder)
	end
	Kit.cobweb(base * CFrame.new(3.5 * k, 4 * k, -2 * k), 3 * k, colors.Bone, folder)
end

local function buildPumpkinPatch(parent: Instance, rng: Random)
	local p = cfg.PumpkinPatch
	local folder = Kit.model("PumpkinPatch", parent)
	local centre = at(p.Offset + Vector3.new(0, 1, 0))
	Kit.decor({
		Name = "Dirt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, p.Radius * 2 + 2, p.Radius * 2 + 2),
		CFrame = Kit.upright(CFrame.new(centre + Vector3.new(0, 0.1, 0))),
		Color = colors.Wood:Lerp(Color3.new(0, 0, 0), 0.25),
		Material = Enum.Material.Ground,
	}, folder)
	for _ = 1, p.Pumpkins do
		local offset = ringPoint(rng, 0, p.Radius)
		local size = rng:NextNumber(1.5, 3.2)
		local cf = CFrame.new(centre + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		Kit.part({
			Name = "Pumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = cf * CFrame.new(0, size / 2, 0),
			Color = colors.Orange:Lerp(Color3.fromRGB(255, 180, 60), rng:NextNumber(0, 0.4)),
		}, folder)
		Kit.decor({
			Name = "Stem",
			Size = Vector3.new(size * 0.15, size * 0.3, size * 0.15),
			CFrame = cf * CFrame.new(0, size * 1.1, 0),
			Color = colors.Green,
		}, folder)
	end
end

local function buildExtraGraves(parent: Instance, rng: Random)
	local g = cfg.ExtraGraves
	local folder = Kit.model("OldGraves", parent)
	for _ = 1, g.Count do
		local offset = g.Offset + ringPoint(rng, 0, g.Spread)
		local cf = facingCenter(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
		Kit.part({
			Name = "Tombstone",
			Size = Vector3.new(2.8, 3.2, 0.7),
			CFrame = cf * CFrame.new(0, 1.6, 0),
			Color = colors.Stone:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)),
			Material = Enum.Material.Slate,
		}, folder)
		Kit.decor({
			Name = "Top",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 2.8, 2.8),
			CFrame = cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = colors.Stone,
			Material = Enum.Material.Slate,
		}, folder)
	end
end

local function buildFence(parent: Instance, rng: Random)
	local f = cfg.Fence
	local folder = Kit.model("Fence", parent)
	local circumference = 2 * math.pi * f.Radius
	local posts = math.floor(circumference / f.PostSpacing)
	local gapHalf = (f.GapWidth / f.Radius) / 2 -- half a gap, in radians
	local function inGap(angle: number): boolean
		for g = 0, f.Gaps - 1 do
			local centre = (g + 0.5) / f.Gaps * math.pi * 2
			local d = math.abs((angle - centre + math.pi) % (math.pi * 2) - math.pi)
			if d < gapHalf then
				return true
			end
		end
		return false
	end
	local postCfs: { CFrame } = {}
	local previous: Vector3? = nil
	for i = 0, posts do
		local angle = i / posts * math.pi * 2
		-- On the grass just outside the plaza (ground level = Center).
		local pos = at(Vector3.new(math.cos(angle) * f.Radius, 0, math.sin(angle) * f.Radius))
		if inGap(angle) then
			previous = nil
			continue
		end
		local cf = facingCenter(pos)
		Kit.part({
			Name = "Post",
			Size = Vector3.new(0.6, f.Height + 0.8, 0.6),
			CFrame = cf * CFrame.new(0, (f.Height + 0.8) / 2, 0),
			Color = colors.Iron,
		}, folder)
		table.insert(postCfs, cf)
		if previous then
			local a, b = previous, pos
			Kit.part({
				Name = "Rail",
				Size = Vector3.new(0.3, f.Height * 0.5, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, f.Height * 0.55, 0),
				Color = colors.Iron,
				Transparency = 0.15,
			}, folder)
		end
		previous = pos
	end
	-- Cobwebs on a few posts, facing into the plaza.
	for _ = 1, math.min(cfg.Cobwebs, #postCfs) do
		local cf = postCfs[rng:NextInteger(1, #postCfs)]
		Kit.cobweb(cf * CFrame.new(1.4, f.Height * 0.7, -0.4), 2.6, colors.Bone, folder)
	end
	-- Ground fog drifting along the fence.
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		Kit.ambientParticles(
			at(Vector3.new(math.cos(angle) * f.Radius, 0, math.sin(angle) * f.Radius)),
			Vector3.new(60, 0, 60),
			{ Mist = { Rate = cfg.FogRate, Color = hubCfg.Particles.Mist.Color } },
			folder
		)
	end
end

local function buildPaths(parent: Instance)
	local p = cfg.Paths
	local folder = Kit.model("GlowPaths", parent)
	local start = at(hubCfg.Spawn.Offset)
	for _, npc in Config.Npcs.List do
		local goal = at(npc.Offset)
		local flat = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z)
		local length = flat.Magnitude - p.StopShort - hubCfg.Spawn.Size.X / 2
		if length > 0 then
			local dir = flat.Unit
			local from = start + dir * (hubCfg.Spawn.Size.X / 2 + p.Spacing / 2)
			for d = 0, length, p.Spacing do
				local pos = from + dir * d
				Kit.decor({
					Name = "Stone",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.15, p.StoneSize, p.StoneSize),
					CFrame = Kit.upright(CFrame.new(pos.X, hubCfg.Center.Y + 1.08, pos.Z)),
					Color = p.Color,
					Material = Enum.Material.Neon,
					Transparency = p.Transparency,
				}, folder)
			end
		end
	end
end

-- Builds all the extras into `hub` (and the Terrain around it).
function HubExtras.Build(hub: Model)
	local rng = Random.new(hubCfg.Seed + 1)
	buildTerrain(rng)
	local folder = Kit.model("Extras", hub)
	buildForest(folder, rng)
	buildMansion(folder)
	buildStatue(folder)
	buildPumpkinPatch(folder, rng)
	buildExtraGraves(folder, rng)
	buildFence(folder, rng)
	buildPaths(folder)
end

return HubExtras
