--!strict
--[[
	Extra dressing for the lobby, built by HubBuilder.Build from Config.Hub.Polish:
	  - Terrain around the plaza: grass ground (tinted Polish.Terrain.GrassColor), gentle hills,
	    mud patches (the default Baseplate is hidden but stays solid underneath)
	  - Forest: a ring of twisted trees, some bare (props "SpookyTree" / "DeadTree")
	  - HauntedMansion: a dark house with pointy towers on a hill in the distance
	  - KingStatue near the clock tower (prop "KingStatue")
	  - PumpkinPatch (props "Pumpkin", "JackOLantern", a scarecrow) and OldGraves
	    (props "Gravestone")
	  - Fence: an iron fence round the plaza, little pumpkins on the posts (prop "FencePost"),
	    cobwebs and ground fog
	  - Paths: glowing stepping stones along the walkways (src/server/Hub/HubPaths.luau)
	Each is a Model inside Workspace.Hub.Decor. Nothing is placed inside a lobby zone
	(Config.Lobby.Zones). Terrain is deterministic (seeded), so rebuilding refills the same
	shapes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)
local HubLayout = require(script.Parent.HubLayout)
local HubPaths = require(script.Parent.HubPaths)

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

local function buildTerrain(rng: Random)
	local t = cfg.Terrain
	if not t.Enabled then
		return
	end
	local terrain = workspace.Terrain
	-- Start clean, so a rebuild with new numbers doesn't keep old hills.
	-- (The terrain around the hub is all generated here; hand-made terrain in this area is lost.)
	terrain:FillCylinder(CFrame.new(at(Vector3.new(0, 35, 0))), 90, t.Radius, Enum.Material.Air)
	terrain:SetMaterialColor(Enum.Material.Grass, t.GrassColor)
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
		local bare = rng:NextNumber() < f.BareChance
		if blocked(base.Position, 4) then
			continue
		end
		Props.Tree(paint, base, height, seed, folder, { Simple = true, Bare = bare })
	end
end

local function buildMansion(parent: Instance)
	-- Coloured from Config.Hub.Polish.Mansion (not the palette): it is far away, in the haze.
	local m = cfg.Mansion
	local folder = Kit.model("HauntedMansion", parent)
	local hillTop = m.HillRadius - m.HillSink
	local base = facingCenter(at(m.Offset + Vector3.new(0, hillTop - 2, 0)))
	local size: Vector3 = m.Size
	local function block(name: string, cf: CFrame, s: Vector3, tint: Color3?, neon: boolean?): Part
		return Kit.decor({
			Name = name,
			Size = s,
			CFrame = cf,
			Color = tint or m.Color,
			Material = if neon then Enum.Material.Neon else Enum.Material.Slate,
		}, folder)
	end
	local function roofWedge(name: string, cf: CFrame, s: Vector3)
		Kit.wedge({
			Name = name,
			Size = s,
			CFrame = cf,
			Color = m.RoofColor,
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, folder)
	end
	block("Body", base * CFrame.new(0, size.Y / 2, 0), size)
	-- A steep gable roof along the length, and a little gable over the porch.
	for _, side in { -1, 1 } do
		roofWedge(
			"Roof",
			base
				* CFrame.new(0, size.Y + 7, side * size.Z / 4)
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Vector3.new(size.X + 3, 14, size.Z / 2 + 1)
		)
	end
	block("Porch", base * CFrame.new(0, 7, -size.Z / 2 - 3), Vector3.new(14, 14, 6))
	for _, side in { -1, 1 } do
		roofWedge(
			"PorchRoof",
			base
				* CFrame.new(side * 3.75, 17, -size.Z / 2 - 3)
				* CFrame.Angles(0, math.rad(90 * side), 0),
			Vector3.new(8, 6, 7.5)
		)
	end
	for _, side in { -1, 1 } do
		block("Chimney", base * CFrame.new(side * 18, size.Y + 10, 4), Vector3.new(3.5, 12, 3.5))
	end
	-- Two crooked towers with witch-hat roofs.
	for _, side in { -1, 1 } do
		local tower = base * CFrame.new(side * (size.X / 2 + 4), 0, 0)
		local towerHeight = size.Y * 1.45
		block("Tower", tower * CFrame.new(0, towerHeight / 2, 0), Vector3.new(11, towerHeight, 11))
		Kit.decor({
			Name = "TowerLedge",
			Size = Vector3.new(13, 1.2, 13),
			CFrame = tower * CFrame.new(0, towerHeight, 0),
			Color = m.RoofColor,
			Material = Enum.Material.Slate,
		}, folder)
		local tip = Props.spire(
			paint,
			folder,
			tower * CFrame.new(0, towerHeight + 0.6, 0) * CFrame.Angles(0, 0, math.rad(side * 4)),
			7.5,
			22,
			{ Color = m.RoofColor, CanCollide = false, CanQuery = false, CanTouch = false }
		)
		block("TowerTip", tip, Vector3.one * 1.6, m.WindowColor, true)
		for row = 0, 1 do
			block(
				"TowerWindow",
				tower * CFrame.new(0, size.Y * 0.6 + row * 10, -5.7),
				Vector3.new(2.6, 4, 0.3),
				m.WindowColor,
				true
			)
		end
	end
	-- Glowing windows on the front.
	for row = 0, 1 do
		for col = -2, 2 do
			if not (col == 0) then
				block(
					"Window",
					base * CFrame.new(col * 11, 9 + row * 11, -size.Z / 2 - 0.2),
					Vector3.new(4, 5.5, 0.3),
					m.WindowColor,
					true
				)
			end
		end
	end
	block("Door", base * CFrame.new(0, 5, -size.Z / 2 - 6.1), Vector3.new(5, 9, 0.3), color("Iron"))
	block(
		"PorchWindow",
		base * CFrame.new(0, 12, -size.Z / 2 - 6.1),
		Vector3.new(3, 3, 0.3),
		m.WindowColor,
		true
	)
end

local function buildStatue(parent: Instance)
	local s = cfg.KingStatue
	local k = s.Height / 16 -- everything below is drawn for a 16-stud statue
	local base = facingCenter(at(s.Offset + Vector3.new(0, 1, 0)))
	if blocked(base.Position, 3) then
		return
	end
	Kit.prop("KingStatue", base, parent, 18 * k, function()
		local folder = Kit.model("KingStatue", parent)
		paint.rounded({
			Name = "Pedestal",
			Size = Vector3.new(9.5 * k, 2 * k, 9.5 * k),
			CFrame = base * CFrame.new(0, 1 * k, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.2,
			Material = Enum.Material.Slate,
		}, folder)
		paint.rounded({
			Name = "Pedestal",
			Size = Vector3.new(7.5 * k, 1.4 * k, 7.5 * k),
			CFrame = base * CFrame.new(0, 2.6 * k, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.1,
			Material = Enum.Material.Slate,
		}, folder)
		part({
			Name = "Robe",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5.6 * k, 9 * k, 4.2 * k),
			CFrame = base * CFrame.new(0, 7 * k, 0),
			PaletteRole = "Purple",
			PaletteShade = 0.3,
			Material = Enum.Material.Slate,
		}, folder)
		decor({
			Name = "Cape",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(6.4 * k, 9.4 * k, 3 * k),
			CFrame = base * CFrame.new(0, 6.8 * k, 1 * k),
			PaletteRole = "Purple",
			PaletteShade = 0.5,
			Material = Enum.Material.Fabric,
		}, folder)
		for _, side in { -1, 1 } do
			decor({
				Name = "Arm",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.5 * k, 4.6 * k, 1.5 * k),
				CFrame = base
					* CFrame.new(side * 3 * k, 8 * k, -0.4 * k)
					* CFrame.Angles(math.rad(-20), 0, math.rad(side * 28)),
				PaletteRole = "Purple",
				PaletteShade = 0.3,
				Material = Enum.Material.Slate,
			}, folder)
		end
		local headCf = base * CFrame.new(0, 13.6 * k, 0)
		local headSize = Vector3.new(6.6, 5.4, 6.6) * k
		local head, ovals =
			Kit.pumpkinBody(headCf, headSize, 4, { PaletteRole = "Orange" }, folder, hubCfg.Palette)
		head.Name = "Head"
		Kit.carvedFace(headCf, headSize, color("Glow"), folder, { Ovals = ovals })
		Kit.light(head, color("Orange"), 26 * k, 1.4, true):SetAttribute("PaletteRole", "Orange")
		decor({
			Name = "Crown",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5 * k, 3.6 * k, 3.6 * k),
			CFrame = Kit.upright(base * CFrame.new(0, 16.8 * k, 0)),
			PaletteRole = "Gold",
			Material = Enum.Material.Metal,
		}, folder)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			decor({
				Name = "CrownPoint",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.75 * k,
				CFrame = base * CFrame.new(math.cos(a) * 1.5 * k, 17.9 * k, math.sin(a) * 1.5 * k),
				PaletteRole = "Gold",
				Material = Enum.Material.Neon,
			}, folder)
		end
		Props.Cobweb(paint, base * CFrame.new(3.6 * k, 4.4 * k, -2 * k), 3 * k, folder)
		return folder
	end)
end

local function buildScarecrow(cf: CFrame, parent: Instance)
	local m = Kit.model("Scarecrow", parent)
	part({
		Name = "Pole",
		Size = Vector3.new(0.5, 8, 0.5),
		CFrame = cf * CFrame.new(0, 4, 0.2),
		PaletteRole = "Wood",
		PaletteShade = 0.2,
		Material = Enum.Material.Wood,
	}, m)
	decor({
		Name = "Crossbar",
		Size = Vector3.new(6.5, 0.45, 0.45),
		CFrame = cf * CFrame.new(0, 6, 0.2),
		PaletteRole = "Wood",
		PaletteShade = 0.2,
		Material = Enum.Material.Wood,
	}, m)
	decor({
		Name = "Shirt",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 3.4, 1.6),
		CFrame = cf * CFrame.new(0, 5.2, 0),
		PaletteRole = "Cloth",
		PaletteShade = 0.1,
		Material = Enum.Material.Fabric,
	}, m)
	for _, side in { -1, 1 } do
		decor({
			Name = "Sleeve",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 0.9, 0.9),
			CFrame = cf * CFrame.new(side * 2, 6, 0.1),
			PaletteRole = "Orange",
			PaletteShade = 0.3,
			Material = Enum.Material.Fabric,
		}, m)
		decor({
			Name = "Straw",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.6, 0.6),
			CFrame = cf * CFrame.new(side * 3.4, 6, 0.1),
			PaletteRole = "Straw",
			Material = Enum.Material.Fabric,
		}, m)
	end
	Props.JackOLantern(paint, cf * CFrame.new(0, 6.9, 0), 2.4, m, { Detail = "Full", Light = true })
	decor({
		Name = "HatBrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 3.8, 3.8),
		CFrame = Kit.upright(cf * CFrame.new(0, 9.4, 0) * CFrame.Angles(0, 0, math.rad(-8))),
		PaletteRole = "Straw",
		PaletteShade = 0.2,
		Material = Enum.Material.Fabric,
	}, m)
	paint.roundedDecor({
		Name = "HatTop",
		Size = Vector3.new(2, 1.3, 2),
		CFrame = cf * CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		PaletteRole = "Straw",
		PaletteShade = 0.2,
		Material = Enum.Material.Fabric,
	}, m)
end

local function buildPumpkinPatch(parent: Instance, rng: Random)
	local p = cfg.PumpkinPatch
	local centre = at(p.Offset + Vector3.new(0, 1, 0))
	-- The random numbers are drawn either way, so the layout after this stays the same.
	local pumpkins = {}
	for i = 1, p.Pumpkins do
		local offset = ringPoint(rng, 1.5, p.Radius - 1.5)
		pumpkins[i] = {
			Offset = offset,
			Size = rng:NextNumber(1.3, 3.2),
			Yaw = rng:NextNumber(0, math.pi * 2),
			Shade = -rng:NextNumber(0, 0.15),
			White = rng:NextNumber() < 0.2,
			Vine = rng:NextNumber(0, math.pi * 2),
		}
	end
	if blocked(centre, p.Radius) then
		return
	end
	local folder = Kit.model("PumpkinPatch", parent)
	decor({
		Name = "Dirt",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(p.Radius * 2 + 3, 0.7, p.Radius * 2 + 1),
		CFrame = CFrame.new(centre + Vector3.new(0, 0.02, 0)),
		PaletteRole = "Wood",
		PaletteShade = 0.4,
		Material = Enum.Material.Ground,
	}, folder)
	for i, pumpkin in pumpkins do
		local size = pumpkin.Size
		local cf = CFrame.new(centre + pumpkin.Offset + Vector3.new(0, 0.2, 0))
			* CFrame.Angles(0, pumpkin.Yaw, 0)
		if i % 6 == 0 then
			Props.JackOLantern(
				paint,
				CFrame.lookAt(cf.Position, at(Vector3.new(0, 1.2, 0))),
				size,
				folder
			)
		else
			Props.Pumpkin(paint, cf, size, folder, {
				Role = if pumpkin.White then "Bone" else "Orange",
				Shade = pumpkin.Shade,
			})
		end
		-- A curly vine and a leaf on the ground.
		local out = Vector3.new(math.cos(pumpkin.Vine), 0, math.sin(pumpkin.Vine))
		local a = cf.Position + out * size * 0.55
		decor({
			Name = "Vine",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(size * 1.3, 0.18, 0.18),
			CFrame = Props.segment(
				a,
				a + (out + Vector3.new(out.Z, 0, -out.X) * 0.6).Unit * size * 1.3
			),
			PaletteRole = "Green",
			PaletteShade = 0.3,
		}, folder)
		if i % 2 == 0 then
			decor({
				Name = "PatchLeaf",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size * 0.9, 0.12, size * 0.6),
				CFrame = CFrame.new(a + out * size * 0.6 + Vector3.new(0, 0.1, 0))
					* CFrame.Angles(0, pumpkin.Vine, 0),
				PaletteRole = "Green",
				PaletteShade = 0.15,
			}, folder)
		end
	end
	local outward = Vector3.new(p.Offset.X, 0, p.Offset.Z).Unit
	local back = centre + outward * (p.Radius + 2)
	buildScarecrow(CFrame.lookAt(back, at(Vector3.new(0, 1, 0))), folder)
end

local function buildExtraGraves(parent: Instance, rng: Random)
	local g = cfg.ExtraGraves
	local folder = Kit.model("OldGraves", parent)
	local styles = { "Round", "Cross", "Pointed" }
	for i = 1, g.Count do
		local offset = g.Offset + ringPoint(rng, 0, g.Spread)
		local cf = facingCenter(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(
				math.rad(rng:NextNumber(-10, 10)),
				math.rad(rng:NextNumber(-20, 20)),
				math.rad(rng:NextNumber(-10, 10))
			)
		local shade = rng:NextNumber(0, 0.3)
		if blocked(cf.Position, 2) then
			continue
		end
		Props.Gravestone(
			paint,
			cf,
			rng:NextNumber(2.6, 3.6),
			folder,
			{ Style = styles[i % #styles + 1], Shade = shade }
		)
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
		if i < posts then
			Props.FencePost(paint, cf, f.Height, folder)
			table.insert(postCfs, cf)
		end
		if previous then
			Props.FenceSpan(paint, previous, pos, f.Height - 0.4, folder, { Pickets = f.Pickets })
		end
		previous = pos
	end
	-- Cobwebs on a few posts, facing into the plaza.
	for _ = 1, math.min(cfg.Cobwebs, #postCfs) do
		local cf = postCfs[rng:NextInteger(1, #postCfs)]
		Props.Cobweb(paint, cf * CFrame.new(1.6, f.Height * 0.65, -0.4), 2.8, folder)
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

-- Glowing stepping stones down the middle of every walkway.
local function buildPaths(parent: Instance)
	-- Coloured from Config.Hub.Polish.Paths (not the palette).
	local p = cfg.Paths
	local folder = Kit.model("Paths", parent)
	for _, path in HubPaths.Network() do
		local carry = p.Spacing / 2
		for i = 1, #path.Points - 1 do
			local a, b = path.Points[i], path.Points[i + 1]
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local length = flat.Magnitude
			if length < 0.1 then
				continue
			end
			local dir = flat.Unit
			local d = carry
			while d < length do
				local pos = a + dir * d
				local stonePos = Vector3.new(pos.X, hubCfg.Center.Y + 1.17, pos.Z)
				if not blocked(stonePos, 0) then
					Kit.decor({
						Name = "PathStone",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.06, p.StoneSize, p.StoneSize),
						CFrame = Kit.upright(CFrame.new(stonePos)),
						Color = p.Color,
						Material = Enum.Material.Neon,
						Transparency = p.Transparency,
					}, folder)
				end
				d += p.Spacing
			end
			carry = d - length
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
