--!strict
--[[
	Extra dressing for the lobby, built by HubBuilder.Build from Config.Hub.Polish:
	  - Terrain around the plaza: grass ground, gentle hills, mud patches (the default
	    Baseplate is hidden but stays solid underneath)
	  - Forest: a ring of dead trees; HauntedMansion: a dark house on a hill in the distance
	  - KingStatue near the clock tower (prop "KingStatue")
	  - PumpkinPatch and OldGraves (props "Gravestone")
	  - Fence: an iron fence round the plaza with cobwebs and ground fog
	  - Paths: glowing stepping stones from the spawn pad to every NPC and the Ready pad
	Each is a Model inside Workspace.Hub.Decor. Nothing is placed inside a lobby zone
	(Config.Lobby.Zones). Terrain is deterministic (seeded), so rebuilding refills the same
	shapes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.HubLayout)
local Npcs = require(script.Parent.Npcs)

local HubExtras = {}

local hubCfg = Config.Hub
local cfg = hubCfg.Polish
local paint = Kit.painter(hubCfg.Palette)
local part = paint.part
local decor = paint.decor
local color = paint.color

local at = HubLayout.At
local facingCenter = HubLayout.FacingCenter
local blocked = HubLayout.Blocked

-- A random point in a ring around the hub centre (flat offset).
local function ringPoint(rng: Random, min: number, max: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(min, max)
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function cobweb(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("Cobweb", cf, parent, size, function()
		local web = Kit.cobweb(cf, size, color("Bone"), parent)
		Kit.setRole(web, "Bone")
		return web
	end, { Anchor = "Center" })
end

-- A bare tree (prop "DeadTree"). Its branches use their own random numbers (`seed`), so the
-- rest of the layout is the same whether or not a custom tree replaces it.
function HubExtras.DeadTree(base: CFrame, height: number, seed: number, parent: Instance): Model
	return Kit.prop("DeadTree", base, parent, height, function()
		local shade = 0.4
		local tree = Kit.deadTree(base, height, color("Wood", shade), Random.new(seed), parent)
		Kit.setRole(tree, "Wood", shade)
		return tree
	end)
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
	for _ = 1, f.Count do
		local offset = ringPoint(rng, f.RingMin, f.RingMax)
		local base = CFrame.new(at(offset)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local height = rng:NextNumber(f.MinHeight, f.MaxHeight)
		local seed = rng:NextInteger(1, 1000000)
		if blocked(base.Position, 4) then
			continue
		end
		HubExtras.DeadTree(base, height, seed, folder)
	end
end

local function buildMansion(parent: Instance)
	-- Coloured from Config.Hub.Polish.Mansion (not the palette).
	local m = cfg.Mansion
	local folder = Kit.model("HauntedMansion", parent)
	local hillTop = m.HillRadius - m.HillSink
	local base = facingCenter(at(m.Offset + Vector3.new(0, hillTop - 2, 0)))
	local size: Vector3 = m.Size
	local function block(name: string, cf: CFrame, s: Vector3, tint: Color3?, neon: boolean?)
		Kit.decor({
			Name = name,
			Size = s,
			CFrame = cf,
			Color = tint or m.Color,
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
	block(
		"Door",
		base * CFrame.new(0, 5, -size.Z / 2 - 0.2),
		Vector3.new(6, 10, 0.3),
		color("Iron")
	)
end

local function buildStatue(parent: Instance)
	local s = cfg.KingStatue
	local k = s.Height / 16 -- everything below is drawn for a 16-stud statue
	local base = facingCenter(at(s.Offset + Vector3.new(0, 1, 0)))
	Kit.prop("KingStatue", base, parent, 17.5 * k, function()
		local folder = Kit.model("KingStatue", parent)
		part({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3 * k, 9 * k, 9 * k),
			CFrame = Kit.upright(base * CFrame.new(0, 1.5 * k, 0)),
			PaletteRole = "Stone",
			Material = Enum.Material.Slate,
		}, folder)
		part({
			Name = "Robe",
			Size = Vector3.new(5 * k, 7 * k, 3.2 * k),
			CFrame = base * CFrame.new(0, 6.5 * k, 0),
			PaletteRole = "Purple",
			PaletteShade = 0.35,
			Material = Enum.Material.Slate,
		}, folder)
		for _, side in { -1, 1 } do
			decor({
				Name = "Arm",
				Size = Vector3.new(1.4 * k, 5 * k, 1.4 * k),
				CFrame = base
					* CFrame.new(side * 3.3 * k, 7.5 * k, 0)
					* CFrame.Angles(0, 0, math.rad(side * 25)),
				PaletteRole = "Purple",
				PaletteShade = 0.35,
				Material = Enum.Material.Slate,
			}, folder)
		end
		local headCf = base * CFrame.new(0, 12.4 * k, 0)
		local head = part({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 5.5 * k,
			CFrame = headCf,
			PaletteRole = "Orange",
		}, folder)
		Kit.carvedFace(headCf, 5.5 * k, color("Glow"), folder)
		Kit.light(head, color("Orange"), 30 * k, 1.5, true):SetAttribute("PaletteRole", "Orange")
		decor({
			Name = "Crown",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4 * k, 4 * k, 4 * k),
			CFrame = Kit.upright(base * CFrame.new(0, 15.6 * k, 0)),
			PaletteRole = "Gold",
			Material = Enum.Material.Metal,
		}, folder)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			decor({
				Name = "CrownSpike",
				Size = Vector3.new(0.7 * k, 1.4 * k, 0.7 * k),
				CFrame = base
					* CFrame.new(math.cos(a) * 1.6 * k, 16.8 * k, math.sin(a) * 1.6 * k)
					* CFrame.Angles(0, 0, math.rad(45)),
				PaletteRole = "Gold",
				Material = Enum.Material.Metal,
			}, folder)
		end
		cobweb(base * CFrame.new(3.5 * k, 4 * k, -2 * k), 3 * k, folder)
		return folder
	end)
end

local function buildPumpkinPatch(parent: Instance, rng: Random)
	local p = cfg.PumpkinPatch
	local centre = at(p.Offset + Vector3.new(0, 1, 0))
	-- The random numbers are drawn either way, so the layout after this stays the same.
	local pumpkins = {}
	for i = 1, p.Pumpkins do
		local offset = ringPoint(rng, 0, p.Radius)
		pumpkins[i] = {
			Offset = offset,
			Size = rng:NextNumber(1.5, 3.2),
			Yaw = rng:NextNumber(0, math.pi * 2),
			Shade = -rng:NextNumber(0, 0.25),
		}
	end
	if blocked(centre, p.Radius) then
		return
	end
	local folder = Kit.model("PumpkinPatch", parent)
	decor({
		Name = "Dirt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, p.Radius * 2 + 2, p.Radius * 2 + 2),
		CFrame = Kit.upright(CFrame.new(centre + Vector3.new(0, 0.1, 0))),
		PaletteRole = "Wood",
		PaletteShade = 0.25,
		Material = Enum.Material.Ground,
	}, folder)
	for _, pumpkin in pumpkins do
		local size = pumpkin.Size
		local cf = CFrame.new(centre + pumpkin.Offset) * CFrame.Angles(0, pumpkin.Yaw, 0)
		part({
			Name = "Pumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = cf * CFrame.new(0, size / 2, 0),
			PaletteRole = "Orange",
			PaletteShade = pumpkin.Shade,
		}, folder)
		decor({
			Name = "Stem",
			Size = Vector3.new(size * 0.15, size * 0.3, size * 0.15),
			CFrame = cf * CFrame.new(0, size * 1.1, 0),
			PaletteRole = "Green",
		}, folder)
	end
end

-- A small tombstone (prop "Gravestone"); `epitaph` is written on the built one.
function HubExtras.Gravestone(
	cf: CFrame,
	size: number,
	shade: number,
	epitaph: string?,
	parent: Instance
): Model
	local k = size / 3.6 -- drawn for a 3.6-stud stone
	return Kit.prop("Gravestone", cf, parent, size + 0.4 * k, function()
		local m = Kit.model("Gravestone", parent)
		local slab = part({
			Name = "Tombstone",
			Size = Vector3.new(3.4 * k, size, 0.8 * k),
			CFrame = cf * CFrame.new(0, size / 2, 0),
			PaletteRole = "Stone",
			PaletteShade = shade,
			Material = Enum.Material.Slate,
		}, m)
		decor({
			Name = "TombstoneTop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8 * k, 3.4 * k, 3.4 * k),
			CFrame = cf * CFrame.new(0, size, 0) * CFrame.Angles(0, math.rad(90), 0),
			PaletteRole = "Stone",
			PaletteShade = shade,
			Material = Enum.Material.Slate,
		}, m)
		if epitaph then
			Kit.surfaceText(slab, epitaph, color("Bone"))
		end
		m.PrimaryPart = slab
		return m
	end)
end

local function buildExtraGraves(parent: Instance, rng: Random)
	local g = cfg.ExtraGraves
	local folder = Kit.model("OldGraves", parent)
	for _ = 1, g.Count do
		local offset = g.Offset + ringPoint(rng, 0, g.Spread)
		local cf = facingCenter(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
		local shade = rng:NextNumber(0, 0.3)
		if blocked(cf.Position, 2) then
			continue
		end
		HubExtras.Gravestone(cf, 3.2, shade, nil, folder)
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
		if inGap(angle) or blocked(pos, 1) then
			previous = nil
			continue
		end
		local cf = facingCenter(pos)
		part({
			Name = "FencePost",
			Size = Vector3.new(0.6, f.Height + 0.8, 0.6),
			CFrame = cf * CFrame.new(0, (f.Height + 0.8) / 2, 0),
			PaletteRole = "Iron",
		}, folder)
		table.insert(postCfs, cf)
		if previous then
			local a, b = previous, pos
			part({
				Name = "FenceRail",
				Size = Vector3.new(0.3, f.Height * 0.5, (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, f.Height * 0.55, 0),
				PaletteRole = "Iron",
				Transparency = 0.15,
			}, folder)
		end
		previous = pos
	end
	-- Cobwebs on a few posts, facing into the plaza.
	for _ = 1, math.min(cfg.Cobwebs, #postCfs) do
		local cf = postCfs[rng:NextInteger(1, #postCfs)]
		cobweb(cf * CFrame.new(1.4, f.Height * 0.7, -0.4), 2.6, folder)
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

-- Where the glowing paths lead: every NPC, and the Ready pad.
local function pathGoals(): { Vector3 }
	local goals = {}
	for _, npc in Config.Npcs.List do
		table.insert(goals, Npcs.Spot(npc).Position)
	end
	if Config.Features.ReadyPad and Config.Lobby.Zones.ReadyArea then
		table.insert(goals, HubLayout.Zone("ReadyArea").CFrame.Position)
	end
	return goals
end

local function buildPaths(parent: Instance)
	-- Coloured from Config.Hub.Polish.Paths (not the palette).
	local p = cfg.Paths
	local folder = Kit.model("Paths", parent)
	local start = at(hubCfg.Spawn.Offset)
	for _, goal in pathGoals() do
		local flat = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z)
		local length = flat.Magnitude - p.StopShort - hubCfg.Spawn.Size.X / 2
		if length > 0 then
			local dir = flat.Unit
			local from = start + dir * (hubCfg.Spawn.Size.X / 2 + p.Spacing / 2)
			for d = 0, length, p.Spacing do
				local pos = from + dir * d
				local stonePos = Vector3.new(pos.X, hubCfg.Center.Y + 1.08, pos.Z)
				if blocked(stonePos, 0) then
					continue
				end
				Kit.decor({
					Name = "PathStone",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.15, p.StoneSize, p.StoneSize),
					CFrame = Kit.upright(CFrame.new(stonePos)),
					Color = p.Color,
					Material = Enum.Material.Neon,
					Transparency = p.Transparency,
				}, folder)
			end
		end
	end
end

-- Builds all the extras into `decor` (Workspace.Hub.Decor) and the Terrain around it.
function HubExtras.Build(_hub: Model, decorModel: Model)
	local rng = Random.new(hubCfg.Seed + 1)
	buildTerrain(rng)
	buildForest(decorModel, rng)
	buildMansion(decorModel)
	buildStatue(decorModel)
	buildPumpkinPatch(decorModel, rng)
	buildExtraGraves(decorModel, rng)
	buildFence(decorModel, rng)
	buildPaths(decorModel)
end

return HubExtras
