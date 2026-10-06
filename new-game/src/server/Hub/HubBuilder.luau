--!strict
--[[
	Builds "Spooky Town Square", the lobby (Workspace.Hub), from Config.Hub, Config.Npcs and
	Config.Lobby. HubService decides WHEN to build (a saved hub is kept, see its header); this
	module knows HOW. Runs fine in Studio's edit mode too (src/server/Tools/Bake.luau).

	The look: a cobbled town square at dusk. The spawn is in the south, looking north through
	the pumpkin arch of the glowing Ready circle at the bubbling cauldron in the middle and the
	crooked clock tower behind it. A stone promenade rings the cauldron; paths with signposts
	lead to every lobby area.

	What it builds (every group is a Model with a readable name):
	  Workspace.Hub   attributes HubName, BuildVersion, PaletteColors (and Locked, if you set it)
	    Plaza         the ground: cobbles (Ground, the PrimaryPart), the promenade ring, the
	                  stone step round the cauldron (Dais), Walkways, Curb, Cracks, Puddles, Leaves
	    Spawn         where players appear (tag HubSpawn): an invisible SpawnLocation on a round
	                  stone (SpawnStone)
	    CandyRush, Crates, EasterEggs, Parkour, ReadyArea, Shop, WebScour
	                  the lobby sections: src/server/Hub/Sections/<Name>.luau builds each one in
	                  its Config.Lobby.Zones area. The Pumpkin Shop keeper stands in Shop.
	    Npcs          the Voting Board, Leaderboard Gravestone and Photo Spot (Hub/Npcs.luau)
	    Decor         only for looks: ClockTower, Cauldron, Lamps (round the edge), PathLamps,
	                  Bunting, JackOLanterns, Candles, Benches, Graveyard, Trees, Clutter,
	                  Signposts, Ambience, and (HubExtras.luau) Forest, HauntedMansion,
	                  KingStatue, PumpkinPatch, OldGraves, Fence, Paths (glowing stones)
	    Music
	Decorations never go inside a lobby zone. Parts coloured from Config.Hub.Palette carry the
	attribute PaletteRole. Decorations are props (src/server/Build/Props.luau: Pumpkin,
	JackOLantern, Lamppost, SpookyTree, Bench, ...), swapped for your own model when
	ReplicatedStorage.Custom.Props has one with the same name (Kit.prop).

	HubBuilder.Build() -> Model             a fresh hub in Workspace (old ones are removed)
	HubBuilder.BuildFallback() -> Model     plain plaza + spawn + Ready pad (if Build fails)
	HubBuilder.BuildSpawn(hub) -> SpawnLocation
	HubBuilder.BuildSection(hub, name) -> Model?   one section (Sections/<name>.luau)
	HubBuilder.RepairSection(hub, name) -> Model?  a section's Repair(), else its Build()
	HubBuilder.ApplyLighting(), ApplyMusic(hub), ApplyCustomNpcs(hub), DisableDefaultSpawn()
	HubBuilder.FindHubs(), RemoveLoosePieces(keep), PieceAttribute
	HubBuilder.RemoveSwitchedOff(hub) -> { string }   empties the lobby areas whose
	                                   Config.Features switch is off (running game only)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)
local FloorSigns = require(script.Parent.FloorSigns)
local HubExtras = require(script.Parent.HubExtras)
local HubLayout = require(script.Parent.HubLayout)
local HubPalette = require(script.Parent.HubPalette)
local HubPaths = require(script.Parent.HubPaths)
local Npcs = require(script.Parent.Npcs)

local HubBuilder = {}

local hubCfg = Config.Hub
local rng = Random.new(hubCfg.Seed)

-- Helpers ------------------------------------------------------------------------------

local paint = Kit.painter(hubCfg.Palette)
local part = paint.part
local decor = paint.decor
local color = paint.color
local model = Kit.model
local upright = Kit.upright
local light = Kit.light
local particles = Kit.particles
local holder = Kit.holder

local at = HubLayout.At
local facingCenter = HubLayout.FacingCenter
local blocked = HubLayout.Blocked

local function glowLight(
	parent: BasePart,
	role: string,
	range: number,
	brightness: number,
	flicker: boolean?
)
	light(parent, color(role), range, brightness, flicker ~= false):SetAttribute(
		"PaletteRole",
		role
	)
end

-- The plaza top at (x, z) offset from the hub centre, plus `y`.
local function ground(x: number, z: number, y: number?): Vector3
	return at(Vector3.new(x, 1 + (y or 0), z))
end

-- A flat round slab centred on `centre` (x/z), its top at `top` (world y).
local function disc(
	name: string,
	centre: Vector3,
	radius: number,
	top: number,
	thickness: number,
	props: Kit.Props,
	parent: Instance,
	solid: boolean?
): Part
	local p = table.clone(props)
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, radius * 2, radius * 2)
	p.CFrame = upright(CFrame.new(centre.X, top - thickness / 2, centre.Z))
	p.CastShadow = false
	return if solid then part(p, parent) else decor(p, parent)
end

-- A flat strip from a to b (x/z), `width` wide, its top at `top`.
local function strip(
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	top: number,
	props: Kit.Props,
	parent: Instance
): Part?
	local flatA = Vector3.new(a.X, top - 0.03, a.Z)
	local flatB = Vector3.new(b.X, top - 0.03, b.Z)
	local length = (flatB - flatA).Magnitude
	if length < 0.05 then
		return nil
	end
	local p = table.clone(props)
	p.Name = name
	p.Size = Vector3.new(width, 0.06, length)
	p.CFrame = CFrame.lookAt((flatA + flatB) / 2, flatB)
	p.CastShadow = false
	return decor(p, parent)
end

-- The flat stone heights, bottom to top (studs above the plaza), so nothing flickers.
local LAYER = {
	Field = 0.02,
	Detail = 0.035,
	PromenadeEdge = 0.04,
	Promenade = 0.06,
	InnerEdge = 0.08,
	InnerField = 0.1,
	PathEdge = 0.12,
	Path = 0.14,
}

-- Ground ----------------------------------------------------------------------------------

local function plazaTop(): number
	return hubCfg.Center.Y + 1
end

-- A walkway along `points`: a darker edge and a smooth stone top, round at every bend.
local function walkway(name: string, points: { Vector3 }, width: number, parent: Instance)
	local top = plazaTop()
	local edge = { PaletteRole = "Path", PaletteShade = 0.32, Material = Enum.Material.Slate }
	local stone = { PaletteRole = "Path", Material = Enum.Material.Slate }
	for i = 1, #points - 1 do
		strip(
			name .. "Edge",
			points[i],
			points[i + 1],
			width + 1.2,
			top + LAYER.PathEdge,
			edge,
			parent
		)
		strip(name, points[i], points[i + 1], width, top + LAYER.Path, stone, parent)
	end
	for _, point in points do
		disc(name .. "Edge", point, (width + 1.2) / 2, top + LAYER.PathEdge, 0.06, edge, parent)
		disc(name, point, width / 2, top + LAYER.Path, 0.06, stone, parent)
	end
end

local function buildPlaza(hub: Model): BasePart
	local cfg = hubCfg.Plaza
	local plaza = model("Plaza", hub)
	local radius = hubCfg.Radius
	local centre = at(Vector3.zero)
	local top = plazaTop()
	-- The ground players walk on; its outer band is darker (the field on top is lighter).
	local groundPart = part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		PaletteShade = 0.22,
		Material = hubCfg.GroundMaterial,
	}, plaza)
	disc("Field", centre, radius - cfg.EdgeBand, top + LAYER.Field, 0.1, {
		PaletteRole = "Ground",
		Material = hubCfg.GroundMaterial,
	}, plaza)
	-- The promenade: a smooth stone ring round the middle, with darker edges.
	local ring = cfg.Promenade
	local outer = ring.Radius + ring.Width / 2
	local inner = ring.Radius - ring.Width / 2
	disc("PromenadeEdge", centre, outer + 0.7, top + LAYER.PromenadeEdge, 0.1, {
		PaletteRole = "Path",
		PaletteShade = 0.32,
		Material = Enum.Material.Slate,
	}, plaza)
	disc("Promenade", centre, outer, top + LAYER.Promenade, 0.1, {
		PaletteRole = "Path",
		Material = Enum.Material.Slate,
	}, plaza)
	disc("PromenadeEdge", centre, inner, top + LAYER.InnerEdge, 0.1, {
		PaletteRole = "Path",
		PaletteShade = 0.32,
		Material = Enum.Material.Slate,
	}, plaza)
	disc("InnerCobbles", centre, inner - 0.7, top + LAYER.InnerField, 0.1, {
		PaletteRole = "Ground",
		PaletteShade = -0.06,
		Material = hubCfg.GroundMaterial,
	}, plaza)
	-- The round stone step the cauldron stands on (players can walk up it).
	local cauldron = hubCfg.Cauldron
	local daisCentre = at(cauldron.Offset)
	disc("Dais", daisCentre, cauldron.DaisRadius, top + 0.5, 0.6, {
		PaletteRole = "Stone",
		PaletteShade = 0.12,
		Material = Enum.Material.Slate,
	}, plaza, true)
	disc("DaisRim", daisCentre, cauldron.DaisRadius + 0.5, top + 0.3, 0.3, {
		PaletteRole = "Path",
		PaletteShade = 0.35,
		Material = Enum.Material.Slate,
	}, plaza)
	disc("DaisTop", daisCentre, cauldron.DaisRadius - 3.2, top + 1, 0.6, {
		PaletteRole = "Stone",
		PaletteShade = 0.05,
		Material = Enum.Material.Slate,
	}, plaza, true)
	disc("DaisRing", daisCentre, cauldron.DaisRadius - 2.6, top + 0.55, 0.1, {
		PaletteRole = "Teal",
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	}, plaza)

	-- Walkways: from the spawn, and out to every lobby area.
	local walkways = model("Walkways", plaza)
	for _, path in HubPaths.Network() do
		walkway(path.Name, path.Points, path.Width, walkways)
	end

	-- The curb round the edge of the plaza.
	local curb = model("Curb", plaza)
	for i = 1, cfg.Curbs do
		local a = (i / cfg.Curbs) * math.pi * 2
		local pos = ground(math.cos(a) * (radius - 0.6), math.sin(a) * (radius - 0.6), -0.4)
		if blocked(pos, 1) then
			continue
		end
		decor({
			Name = "CurbStone",
			Size = Vector3.new(1.6, 1.1, 2 * math.pi * radius / cfg.Curbs - 0.25),
			CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))),
			PaletteRole = "Stone",
			PaletteShade = 0.28 + (i % 3) * 0.05,
			Material = Enum.Material.Slate,
		}, curb)
	end

	-- Small details on the cobbles: cracks, puddles and fallen leaves.
	local details = model("Details", plaza)
	local function freeSpot(minR: number, maxR: number, margin: number): Vector3?
		for _ = 1, 12 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(minR, maxR)
			local pos = ground(math.cos(a) * r, math.sin(a) * r)
			if not blocked(pos, margin) and not HubPaths.OnPath(pos, margin) then
				return pos
			end
		end
		return nil
	end
	for _ = 1, cfg.Cracks do
		local pos = freeSpot(inner + 2, radius - 8, 1)
		if not pos then
			continue
		end
		local point = pos
		local heading = rng:NextNumber(0, math.pi * 2)
		for _ = 1, 3 do
			heading += rng:NextNumber(-0.9, 0.9)
			local nextPoint = point
				+ Vector3.new(math.cos(heading), 0, math.sin(heading))
					* rng:NextNumber(1.4, 2.6)
			strip("Crack", point, nextPoint, 0.22, top + LAYER.Detail, {
				PaletteRole = "Dark",
				PaletteShade = 0.2,
			}, details)
			point = nextPoint
		end
	end
	for _ = 1, cfg.Puddles do
		local pos = freeSpot(outer + 3, radius - 10, 2)
		if not pos then
			continue
		end
		local s = rng:NextNumber(3, 6)
		decor({
			Name = "Puddle",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, 0.08, s * rng:NextNumber(0.55, 0.8)),
			CFrame = CFrame.new(pos + Vector3.new(0, LAYER.Detail + 0.01, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			PaletteRole = "Dark",
			PaletteShade = -0.25,
			Material = Enum.Material.Glass,
			Reflectance = 0.35,
			Transparency = 0.1,
		}, details)
	end
	local leafRoles = { "Orange", "Gold", "Wood", "Orange" }
	for i = 1, cfg.Leaves do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(inner + 1, radius - 2)
		local pos = ground(math.cos(a) * r, math.sin(a) * r, 0.16)
		if blocked(pos, 0) then
			continue
		end
		decor({
			Name = "Leaf",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.05, 0.5),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			PaletteRole = leafRoles[i % #leafRoles + 1],
			PaletteShade = rng:NextNumber(-0.05, 0.3),
		}, details)
	end

	plaza.PrimaryPart = groundPart
	return groundPart
end

function HubBuilder.BuildSpawn(hub: Model): SpawnLocation
	local cfg = hubCfg.Spawn
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn"
	s.Anchored = true
	s.Neutral = true
	s.Duration = 0
	s.Size = cfg.Size
	local pos = at(cfg.Offset + Vector3.new(0, 1.1, 0))
	local look = at(cfg.LookAt)
	local flat = Vector3.new(look.X - pos.X, 0, look.Z - pos.Z)
	s.CFrame = if flat.Magnitude > 0.1 then CFrame.lookAt(pos, pos + flat) else CFrame.new(pos)
	s.Transparency = 1 -- the round stone below is what you see
	s.Material = Enum.Material.SmoothPlastic
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = hub
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	local top = s.Position.Y + s.Size.Y / 2
	local base = CFrame.new(s.Position.X, top, s.Position.Z) * s.CFrame.Rotation
	local d = cfg.Diameter
	disc("SpawnStone", base.Position, d / 2, top, 0.8, {
		PaletteRole = "Path",
		PaletteShade = 0.05,
		Material = Enum.Material.Slate,
	}, s, true)
	disc("SpawnRim", base.Position, d / 2 + 0.6, top - 0.25, 0.6, {
		PaletteRole = "Path",
		PaletteShade = 0.35,
		Material = Enum.Material.Slate,
	}, s)
	disc("SpawnGlow", base.Position, d / 2 - 1.2, top + 0.03, 0.06, {
		PaletteRole = "Glow",
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	}, s)
	disc("SpawnInlay", base.Position, d / 2 - 1.55, top + 0.06, 0.06, {
		PaletteRole = "Purple",
		PaletteShade = 0.3,
		Material = Enum.Material.Slate,
	}, s)
	Kit.surfaceText(s, cfg.Text, color("Orange"), Enum.NormalId.Top)
	CollectionService:AddTag(s, Tags.HubSpawn)
	return s
end

-- Decorations ----------------------------------------------------------------------------

local function buildClockTower(parent: Instance)
	local cfg = hubCfg.ClockTower
	local base = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	local height = cfg.Floors * cfg.FloorHeight + 22
	local batSpots = {}
	for i = 1, cfg.Bats do
		batSpots[i] = {
			Angle = i / cfg.Bats * math.pi * 2 + rng:NextNumber(-0.3, 0.3),
			Up = rng:NextNumber(-3, 5),
		}
	end
	-- The bats round the roof, and where each starts its bob: worked out now, before Kit.prop,
	-- so a custom clock tower (no bats) draws the same random numbers and moves nothing else.
	-- (The roof's frame is worked out the same way as the floors below.)
	local roof = base * CFrame.new(0, 1.6, 0)
	for i = 1, cfg.Floors do
		local turn = if i % 2 == 0 then cfg.Twist else -cfg.Twist
		roof = roof
			* CFrame.new(0, cfg.FloorHeight, 0)
			* CFrame.Angles(0, math.rad(turn), math.rad(cfg.Lean))
	end
	roof *= CFrame.new(0, 6, 0)
	local roofWidth = if cfg.Floors >= 1
		then cfg.Width * (1 - 0.05 * (cfg.Floors - 1))
		else cfg.Width
	local bats: { { CFrame: CFrame, Phase: number } } = {}
	for _, spot in batSpots do
		local pos = (roof * CFrame.new(
			math.cos(spot.Angle) * (roofWidth + 3),
			spot.Up,
			math.sin(spot.Angle) * (roofWidth + 3)
		)).Position
		if not blocked(pos, 0) then
			table.insert(bats, {
				CFrame = CFrame.lookAt(
					pos,
					pos + Vector3.new(-math.sin(spot.Angle), 0, math.cos(spot.Angle))
				),
				Phase = rng:NextNumber(0, math.pi * 2),
			})
		end
	end
	-- Hollow when the Tormented Tower is on: the climb goes up inside (Config.TowerParkour).
	local hollow = Config.Features.TowerParkour == true
	local walls = Config.TowerParkour.Walls
	-- One floor's four walls. hole = (width, height, bottom) of a gap in the front wall (the
	-- side facing the plaza), bottom measured from the floor's middle.
	local function towerWalls(
		tower: Instance,
		floorCf: CFrame,
		width: number,
		i: number,
		hole: Vector3?
	)
		local t = walls.Thickness
		local h = cfg.FloorHeight
		local shade = if i % 2 == 0 then 0.04 else 0.1
		local function wall(name: string, size: Vector3, cframe: CFrame)
			if size.X <= 0.05 or size.Y <= 0.05 or size.Z <= 0.05 then
				return
			end
			part({
				Name = name,
				Size = size,
				CFrame = cframe,
				PaletteRole = "Stone",
				PaletteShade = shade,
				Material = Enum.Material.Brick,
			}, tower)
		end
		local prefix = "TowerFloor" .. i
		-- Back and sides.
		wall(
			prefix .. "Back",
			Vector3.new(width, h, t),
			floorCf * CFrame.new(0, 0, width / 2 - t / 2)
		)
		for _, side in { -1, 1 } do
			wall(
				prefix .. "Side",
				Vector3.new(t, h, width - 2 * t),
				floorCf * CFrame.new(side * (width / 2 - t / 2), 0, 0)
			)
		end
		-- Front, round the hole.
		local front = floorCf * CFrame.new(0, 0, -(width / 2 - t / 2))
		if not hole then
			wall(prefix .. "Front", Vector3.new(width, h, t), front)
			return
		end
		local hw, hh, bottom = hole.X, hole.Y, hole.Z
		local top = bottom + hh
		local sideW = (width - hw) / 2
		for _, side in { -1, 1 } do
			wall(
				prefix .. "Front",
				Vector3.new(sideW, h, t),
				front * CFrame.new(side * (hw / 2 + sideW / 2), 0, 0)
			)
		end
		local aboveH = h / 2 - top
		wall(
			prefix .. "Front",
			Vector3.new(hw, aboveH, t),
			front * CFrame.new(0, top + aboveH / 2, 0)
		)
		local belowH = bottom + h / 2
		wall(
			prefix .. "Front",
			Vector3.new(hw, belowH, t),
			front * CFrame.new(0, -h / 2 + belowH / 2, 0)
		)
	end
	Kit.prop("ClockTower", base, parent, height, function()
		local tower = model("ClockTower", parent)
		local w0 = cfg.Width
		part({
			Name = "Step",
			Size = Vector3.new(w0 + 5, 0.8, w0 + 5),
			CFrame = base * CFrame.new(0, 0.4, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.28,
			Material = Enum.Material.Slate,
		}, tower)
		part({
			Name = "Step",
			Size = Vector3.new(w0 + 2.4, 0.8, w0 + 2.4),
			CFrame = base * CFrame.new(0, 1.2, 0),
			PaletteRole = "Stone",
			PaletteShade = 0.18,
			Material = Enum.Material.Slate,
		}, tower)
		-- An arched door with two lanterns (open, with no door, when the tower is hollow).
		if not hollow then
			decor({
				Name = "Door",
				Size = Vector3.new(4, 5.5, 0.3),
				CFrame = base * CFrame.new(0, 4.35, -w0 / 2 - 0.1),
				PaletteRole = "Wood",
				PaletteShade = 0.3,
				Material = Enum.Material.WoodPlanks,
			}, tower)
		end
		if not hollow then
			decor({
				Name = "DoorArch",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 4, 4),
				CFrame = base
					* CFrame.new(0, 7.1, -w0 / 2 - 0.1)
					* CFrame.Angles(0, math.rad(90), 0),
				PaletteRole = "Wood",
				PaletteShade = 0.3,
				Material = Enum.Material.WoodPlanks,
			}, tower)
		end
		for _, side in { -1, 1 } do
			Props.Lantern(
				paint,
				base * CFrame.new(side * 3.2, 6.2, -w0 / 2 - 0.7),
				1.4,
				tower,
				{ Light = side < 0, Range = 14 }
			)
		end

		local cf = base * CFrame.new(0, 1.6, 0)
		local clockFloor = math.max(cfg.Floors - 1, 1)
		local width = w0
		for i = 1, cfg.Floors do
			width = w0 * (1 - 0.05 * (i - 1))
			local floorCf = cf * CFrame.new(0, cfg.FloorHeight / 2, 0)
			if hollow then
				-- The Tormented Tower climbs inside: four walls, a doorway on the ground floor
				-- and a window behind the clock face (Config.TowerParkour.Walls).
				local hole: Vector3? = nil
				if i == 1 then
					hole = Vector3.new(walls.DoorWidth, walls.DoorHeight, -cfg.FloorHeight / 2)
				elseif i == clockFloor and walls.ClockWindow > 0 then
					hole = Vector3.new(walls.ClockWindow, walls.ClockWindow, -walls.ClockWindow / 2)
				end
				towerWalls(tower, floorCf, width, i, hole)
			else
				part({
					Name = "TowerFloor" .. i,
					Size = Vector3.new(width, cfg.FloorHeight, width),
					CFrame = floorCf,
					PaletteRole = "Stone",
					PaletteShade = if i % 2 == 0 then 0.04 else 0.1,
					Material = Enum.Material.Brick,
				}, tower)
			end
			-- Corner stones and a jutting ledge at the top: a layered, crooked silhouette.
			-- (Hollow: the stones stand just outside the corners, clear of the climb inside.)
			local stone = width * 0.14
			local stoneAt = if hollow
				then width / 2 - walls.Thickness + stone / 2
				else width / 2 - width * 0.05
			for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				decor({
					Name = "CornerStone",
					Size = Vector3.new(stone, cfg.FloorHeight - 0.4, stone),
					CFrame = floorCf * CFrame.new(corner[1] * stoneAt, 0, corner[2] * stoneAt),
					PaletteRole = "Stone",
					PaletteShade = -0.08,
					Material = Enum.Material.Slate,
				}, tower)
			end
			local ledgeCf = floorCf * CFrame.new(0, cfg.FloorHeight / 2 - 0.2, 0)
			if hollow then
				-- A ring round the outside only, so the inside stays open from top to bottom.
				local rim = walls.Thickness + 0.65
				for side = 0, 3 do
					decor({
						Name = "Ledge",
						Size = Vector3.new(width + 1.3, 0.7, rim),
						CFrame = ledgeCf
							* CFrame.Angles(0, side * math.pi / 2, 0)
							* CFrame.new(0, 0, (width + 1.3) / 2 - rim / 2),
						PaletteRole = "Purple",
						PaletteShade = 0.45,
						Material = Enum.Material.Slate,
					}, tower)
				end
			else
				decor({
					Name = "Ledge",
					Size = Vector3.new(width + 1.3, 0.7, width + 1.3),
					CFrame = ledgeCf,
					PaletteRole = "Purple",
					PaletteShade = 0.45,
					Material = Enum.Material.Slate,
				}, tower)
			end
			if i ~= clockFloor and i > 1 then
				-- An arched, glowing window on each side.
				for side = 0, 3 do
					local face = floorCf
						* CFrame.Angles(0, side * math.pi / 2, 0)
						* CFrame.new(0, -0.4, -width / 2 - 0.05)
					local ww = width * 0.22
					decor({
						Name = "Window",
						Size = Vector3.new(ww, cfg.FloorHeight * 0.36, 0.2),
						CFrame = face,
						PaletteRole = "Glow",
						Material = Enum.Material.Neon,
					}, tower)
					decor({
						Name = "WindowArch",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.2, ww, ww),
						CFrame = face
							* CFrame.new(0, cfg.FloorHeight * 0.18, 0)
							* CFrame.Angles(0, math.rad(90), 0),
						PaletteRole = "Glow",
						Material = Enum.Material.Neon,
					}, tower)
				end
			elseif i == clockFloor then
				-- Glowing clock faces on the front and both sides (the back faces the parkour).
				local t = cfg.ClockTime
				for side = -1, 1 do
					local faceCf = floorCf
						* CFrame.Angles(0, side * math.pi / 2, 0)
						* CFrame.new(0, 0, -width / 2 - 0.25)
					local diameter = width * (if side == 0 then 0.78 else 0.6)
					decor({
						Name = "ClockRim",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.5, diameter + 1, diameter + 1),
						CFrame = faceCf * CFrame.Angles(0, math.rad(90), 0),
						PaletteRole = "Iron",
						Material = Enum.Material.Metal,
					}, tower)
					local face = decor({
						Name = "ClockFace",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.5, diameter, diameter),
						CFrame = faceCf
							* CFrame.new(0, 0, -0.1)
							* CFrame.Angles(0, math.rad(90), 0),
						PaletteRole = "Glow",
						PaletteShade = -0.35,
						Material = Enum.Material.Neon,
					}, tower)
					if side == 0 then
						glowLight(face, "Glow", 34, 1.6, false)
					end
					local function hand(name: string, angle: number, length: number, thick: number)
						decor({
							Name = name,
							Size = Vector3.new(thick, length, 0.2),
							CFrame = faceCf
								* CFrame.Angles(0, 0, -angle)
								* CFrame.new(0, length / 2 - 0.3, -0.45),
							PaletteRole = "Iron",
						}, tower)
					end
					hand(
						"HourHand",
						((t.Hour % 12) + t.Minute / 60) / 12 * math.pi * 2,
						diameter * 0.28,
						0.55
					)
					hand("MinuteHand", t.Minute / 60 * math.pi * 2, diameter * 0.42, 0.35)
					local marks = if side == 0 then 12 else 4
					for m = 0, marks - 1 do
						decor({
							Name = "HourMark",
							Size = Vector3.new(0.35, if m % 3 == 0 then 1 else 0.6, 0.2),
							CFrame = faceCf
								* CFrame.Angles(0, 0, m / marks * math.pi * 2)
								* CFrame.new(0, diameter * 0.4, -0.4),
							PaletteRole = "Iron",
						}, tower)
					end
				end
			end
			local turn = if i % 2 == 0 then cfg.Twist else -cfg.Twist
			cf = cf
				* CFrame.new(0, cfg.FloorHeight, 0)
				* CFrame.Angles(0, math.rad(turn), math.rad(cfg.Lean))
		end
		-- The roof: wide eaves and a crooked two-tier spire with a glowing tip.
		decor({
			Name = "Eaves",
			Size = Vector3.new(width + 3, 0.8, width + 3),
			CFrame = cf * CFrame.new(0, 0.4, 0),
			PaletteRole = "Purple",
			PaletteShade = 0.5,
			Material = Enum.Material.Slate,
		}, tower)
		local tip = Props.spire(paint, tower, cf * CFrame.new(0, 0.8, 0), (width + 2.4) / 2, 20, {
			PaletteRole = "Purple",
			PaletteShade = 0.3,
		})
		local orb = decor({
			Name = "Tip",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.2,
			CFrame = tip,
			PaletteRole = "Orange",
			Material = Enum.Material.Neon,
		}, tower)
		glowLight(orb, "Orange", 26, 1.6)
		-- Bats round the roof (placed above, before Kit.prop).
		for _, bat in bats do
			Props.Bat(paint, bat.CFrame, 2.2, tower, bat.Phase)
		end
		-- Cobwebs in the bottom front corners.
		for _, side in { -1, 1 } do
			Props.Cobweb(
				paint,
				base
					* CFrame.new(side * (w0 / 2 - 0.4), cfg.FloorHeight + 0.4, -w0 / 2 - 0.2)
					* CFrame.Angles(0, 0, math.rad(side * 45)),
				hubCfg.Cobwebs.Size,
				tower
			)
		end
		return tower
	end)
end

local function buildCauldron(parent: Instance)
	local cfg = hubCfg.Cauldron
	local base = facingCenter(at(cfg.Offset + Vector3.new(0, 2, 0)))
		* CFrame.Angles(0, math.rad(180), 0)
	local r = cfg.Radius
	Kit.prop("Cauldron", base, parent, r * 1.9 + 1.6, function()
		local m = model("Cauldron", parent)
		-- A little fire under the pot.
		for i = 0, 2 do
			decor({
				Name = "Log",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(r * 1.3, 0.9, 0.9),
				CFrame = base * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, i * math.pi / 3, 0),
				PaletteRole = "Wood",
				PaletteShade = 0.3,
				Material = Enum.Material.Wood,
			}, m)
		end
		local embers = decor({
			Name = "Embers",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(r * 0.8, 0.7, r * 0.8),
			CFrame = base * CFrame.new(0, 0.6, 0),
			PaletteRole = "Orange",
			Material = Enum.Material.Neon,
		}, m)
		glowLight(embers, "Orange", 16, 1.4)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 2
		fire.Color = color("Orange")
		fire.SecondaryColor = color("Glow")
		fire.Parent = embers
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2 + math.pi / 6
			decor({
				Name = "Leg",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.3, 2.4, 1.3),
				CFrame = base
					* CFrame.new(math.cos(a) * r * 0.72, 1.1, math.sin(a) * r * 0.72)
					* CFrame.Angles(0, -a, math.rad(-18)),
				PaletteRole = "Iron",
				Material = Enum.Material.Metal,
			}, m)
		end
		-- The pot: a fat rounded drum with a round belly.
		local potBottom = 1.4
		local potHeight = r * 1.25
		local pot = paint.roundedDecor({
			Name = "Pot",
			Size = Vector3.new(r * 1.9, potHeight, r * 1.9),
			CFrame = base * CFrame.new(0, potBottom + potHeight / 2, 0),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
		-- What players bump into: an invisible round body (a rounded mesh bumps like a box).
		part({
			Name = "PotCollider",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(potHeight + 1.4, r * 2, r * 2),
			CFrame = upright(base * CFrame.new(0, (potHeight + 1.4) / 2, 0)),
			Transparency = 1,
			CastShadow = false,
		}, m)
		decor({
			Name = "Belly",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(r * 2.1, potHeight * 0.9, r * 2.1),
			CFrame = base * CFrame.new(0, potBottom + potHeight * 0.42, 0),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
		local rimY = potBottom + potHeight
		decor({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, r * 2, r * 2),
			CFrame = upright(base * CFrame.new(0, rimY + 0.1, 0)),
			PaletteRole = "Iron",
			PaletteShade = -0.15,
			Material = Enum.Material.Metal,
		}, m)
		local brew = decor({
			Name = "Brew",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, r * 1.7, r * 1.7),
			CFrame = upright(base * CFrame.new(0, rimY + 0.4, 0)),
			PaletteRole = "Green",
			Material = Enum.Material.Neon,
		}, m)
		glowLight(brew, "Green", 24, 2)
		for i, s in { 1.4, 0.9, 0.7 } do
			local a = i * 2.1
			decor({
				Name = "Bubble",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * s,
				CFrame = base
					* CFrame.new(math.cos(a) * r * 0.45, rimY + 0.45, math.sin(a) * r * 0.45),
				PaletteRole = "Green",
				PaletteShade = -0.3,
				Material = Enum.Material.Neon,
			}, m)
		end
		for _, side in { -1, 1 } do
			decor({
				Name = "Handle",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.35, 2, 2),
				CFrame = base * CFrame.new(side * r * 1.02, rimY - 1.2, 0),
				PaletteRole = "Iron",
				Material = Enum.Material.Metal,
			}, m)
		end
		decor({
			Name = "Ladle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(r * 1.3, 0.4, 0.4),
			CFrame = base
				* CFrame.new(r * 0.35, rimY + 1.6, r * 0.2)
				* CFrame.Angles(0, math.rad(30), math.rad(55)),
			PaletteRole = "Wood",
			Material = Enum.Material.Wood,
		}, m)
		local p = hubCfg.Particles.Bubbles
		particles(brew, {
			Rate = p.Rate,
			Color = ColorSequence.new(p.Color),
			LightEmission = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 1.2),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(15, 15),
			EmissionDirection = Enum.NormalId.Right, -- the disc is turned, so +X points up
		})
		local smoke = Instance.new("Smoke")
		smoke.Color = color("Teal")
		smoke.Opacity = 0.08
		smoke.RiseVelocity = 3
		smoke.Size = 3
		smoke.Parent = brew
		m.PrimaryPart = pot
		return m
	end)
end

local function buildLamps(parent: Instance)
	local cfg = hubCfg.Lampposts
	local lamps = model("Lamps", parent)
	local tops: { [number]: Vector3 } = {}
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2 + math.pi / 2
		local pos = ground(math.cos(a) * cfg.Radius, math.sin(a) * cfg.Radius)
		if blocked(pos, 2) then
			continue
		end
		Props.Lamppost(paint, facingCenter(pos), cfg.Height, lamps)
		tops[i] = pos + Vector3.new(0, cfg.Height - 1.4, 0)
	end
	-- More lamps by the cauldron and along the spawn path.
	local pathLamps = model("PathLamps", parent)
	local inner: { Vector3 } = {}
	for i = 1, cfg.Inner.Count do
		local a = (i - 0.5) / cfg.Inner.Count * math.pi * 2 + math.pi / 4
		local pos = ground(math.cos(a) * cfg.Inner.Radius, math.sin(a) * cfg.Inner.Radius)
		if blocked(pos, 1) then
			continue
		end
		Props.Lamppost(paint, facingCenter(pos), cfg.Height - 1, pathLamps)
		table.insert(inner, pos + Vector3.new(0, cfg.Height - 2.4, 0))
	end
	for _, offset in cfg.Spawn do
		local pos = ground(offset.X, offset.Z)
		if not blocked(pos, 1) then
			Props.Lamppost(paint, facingCenter(pos), cfg.Height - 2, pathLamps)
		end
	end

	-- Bunting: flags on sagging ropes between neighbouring lamps (and round the cauldron).
	local bunting = model("Bunting", parent)
	local ropes = holder("Ropes", CFrame.new(at(Vector3.new(0, 10, 0))), Vector3.one * 0.2, bunting)
	local b = hubCfg.Bunting
	local options: Props.BuntingOptions = { Flags = b.FlagsPerSpan, Sag = b.Sag, Colors = b.Colors }
	for i = 1, cfg.Count do
		local a, c = tops[i], tops[i % cfg.Count + 1]
		if a and c then
			Props.Bunting(paint, ropes, a, c, options, bunting)
		end
	end
	for i = 1, #inner do
		local a, c = inner[i], inner[i % #inner + 1]
		if #inner > 1 then
			Props.Bunting(
				paint,
				ropes,
				a,
				c,
				{ Flags = 4, Sag = 1.8, Colors = b.Colors, FlagSize = 1.2 },
				bunting
			)
		end
	end
end

local function buildJackOLanterns(parent: Instance)
	local cfg = hubCfg.JackOLanterns
	local folder = model("JackOLanterns", parent)
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2 + math.pi / cfg.Count + math.pi / 2
		local pos = ground(math.cos(a) * cfg.Radius, math.sin(a) * cfg.Radius)
		local size = cfg.Size * rng:NextNumber(0.75, 1.25)
		local turn = rng:NextNumber(-0.3, 0.3)
		if blocked(pos, 2) or HubPaths.OnPath(pos, 1) then
			continue
		end
		Props.JackOLantern(paint, facingCenter(pos) * CFrame.Angles(0, turn, 0), size, folder, {
			Light = cfg.LightEvery > 0 and i % cfg.LightEvery == 0,
			Detail = "Simple",
		})
		if cfg.Friends > 0 and i % cfg.Friends == 0 then
			-- A small plain pumpkin keeps it company.
			local side = if i % 4 == 0 then 1 else -1
			Props.Pumpkin(
				paint,
				facingCenter(pos) * CFrame.new(side * size * 0.9, 0, 0.6),
				size * 0.5,
				folder,
				{ Solid = false, Leaf = false }
			)
		end
	end
end

local function buildCandles(parent: Instance)
	local cfg = hubCfg.Candles
	local folder = model("Candles", parent)
	for i = 1, cfg.Count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(cfg.MinRadius, cfg.MaxRadius)
		local y = rng:NextNumber(cfg.MinHeight, cfg.MaxHeight)
		local height = rng:NextNumber(cfg.MinSize, cfg.MaxSize)
		local phase = rng:NextNumber(0, math.pi * 2)
		-- The bottom of the candle (it floats: the wax runs up from here).
		local foot = at(Vector3.new(math.cos(a) * r, y - height / 2, math.sin(a) * r))
		if blocked(foot, 1) then
			continue
		end
		local m = Props.Candle(paint, CFrame.new(foot), height, folder, {
			Light = cfg.LightEvery > 0 and i % cfg.LightEvery == 0,
		})
		Props.floatTag(m, cfg.BobHeight, phase)
	end
end

local function buildBenches(parent: Instance)
	local cfg = hubCfg.Benches
	local folder = model("Benches", parent)
	for i = 1, cfg.Count do
		local a = (i - 0.5) / cfg.Count * math.pi * 2 + math.pi / 2
		local pos = ground(math.cos(a) * cfg.Radius, math.sin(a) * cfg.Radius)
		if blocked(pos, 2) then
			continue
		end
		Props.Bench(paint, facingCenter(pos), folder)
	end
end

local function buildGraveyard(parent: Instance)
	local cfg = hubCfg.Graveyard
	local origin = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	-- Draw every random number first, so leaving a stone out never moves the others.
	local tilts = {}
	for i in cfg.Epitaphs do
		tilts[i] = CFrame.Angles(
			math.rad(rng:NextNumber(-6, 6)),
			math.rad(rng:NextNumber(-10, 10)),
			math.rad(rng:NextNumber(-8, 8))
		)
	end
	if blocked(origin.Position, 2) then
		return
	end
	local folder = model("Graveyard", parent)
	local styles = { "Round", "Cross", "Pointed" }
	for i, epitaph in cfg.Epitaphs do
		local row = (i - 1) // 3
		local col = (i - 1) % 3
		local spot = origin * CFrame.new((col - 1) * 7, 0, 2 + row * 7.5)
		if blocked(spot.Position, 2) then
			continue
		end
		local cf = spot * tilts[i]
		Props.Gravestone(paint, cf, 3.6 + (i % 2) * 0.5, folder, {
			Style = styles[(i - 1) % #styles + 1],
			Shade = (i % 3) * 0.06,
			Epitaph = epitaph,
		})
		-- A little mound of dirt in front.
		decor({
			Name = "DirtMound",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 0.8, 4.2),
			CFrame = spot * CFrame.new(0, 0.05, -2.9),
			PaletteRole = "Wood",
			PaletteShade = 0.35,
			Material = Enum.Material.Ground,
		}, folder)
	end
	-- Iron fence on three sides with little pumpkins on the posts, open towards the plaza.
	local fence = model("GraveyardFence", folder)
	local corners = {
		origin * CFrame.new(-12, 0, -4),
		origin * CFrame.new(-12, 0, 18),
		origin * CFrame.new(12, 0, 18),
		origin * CFrame.new(12, 0, -4),
	}
	for c = 1, 3 do
		local a, b = corners[c].Position, corners[c + 1].Position
		if blocked(a, 1) or blocked(b, 1) then
			continue
		end
		local posts = math.max(math.floor((b - a).Magnitude / 5.5), 1)
		for p = 0, posts do
			local pos = a:Lerp(b, p / posts)
			if c > 1 and p == 0 then
				continue -- the corner post is already there
			end
			Props.FencePost(paint, CFrame.new(pos), 3.6, fence)
		end
		for p = 0, posts - 1 do
			Props.FenceSpan(
				paint,
				a:Lerp(b, p / posts),
				a:Lerp(b, (p + 1) / posts),
				3.2,
				fence,
				{ Pickets = 2 }
			)
		end
	end
	-- A bare tree with a lantern at the back, glowing mushrooms, and mist.
	Props.Tree(
		paint,
		origin * CFrame.new(8, 0, 15),
		15,
		4242,
		folder,
		{ Bare = true, Lanterns = 2, LanternLight = true }
	)
	Props.Mushrooms(paint, origin * CFrame.new(-9, 0, 14), 1.6, folder, rng)
	Kit.ambientParticles(
		origin.Position + origin.LookVector * -7,
		Vector3.new(24, 0, 22),
		{ Mist = { Rate = 3, Color = hubCfg.Particles.Mist.Color } },
		folder
	)
end

local function buildTrees(parent: Instance)
	local cfg = hubCfg.DeadTrees
	local folder = model("Trees", parent)
	for i, offset in cfg.Offsets do
		local base = CFrame.new(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local height = rng:NextNumber(cfg.MinHeight, cfg.MaxHeight)
		local seed = rng:NextInteger(1, 1000000)
		if blocked(base.Position, 5) then
			continue
		end
		local bare = cfg.Bare[i] == true
		local tree = Props.Tree(paint, base, height, seed, folder, {
			Bare = bare,
			Lanterns = if bare then 2 else 0,
			LanternLight = bare and i % 2 == 0,
		})
		if not bare then
			-- Falling leaves from the crown.
			local canopy = holder(
				"Leaves",
				base * CFrame.new(0, height * 0.75, 0),
				Vector3.new(10, 1, 10),
				tree
			)
			local p = hubCfg.Particles.Leaves
			particles(canopy, {
				Rate = p.Rate,
				Color = ColorSequence.new(p.Color),
				Size = NumberSequence.new(0.35),
				Lifetime = NumberRange.new(5, 8),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0.5, -1.2, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
				EmissionDirection = Enum.NormalId.Bottom,
				Shape = Enum.ParticleEmitterShape.Box,
			})
		elseif tree:GetAttribute("CustomProp") ~= true then
			Props.Cobweb(
				paint,
				base * CFrame.new(0, height * 0.45, -1.4),
				hubCfg.Cobwebs.Size * 0.7,
				tree
			)
		end
	end
end

local function buildClutter(parent: Instance)
	local cfg = hubCfg.Clutter
	local folder = model("Clutter", parent)
	local function place(offset: Vector3, margin: number): CFrame?
		local pos = ground(offset.X, offset.Z)
		if blocked(pos, margin) then
			return nil
		end
		return facingCenter(pos) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
	end
	for _, offset in cfg.HayBales do
		local cf = place(offset, 2)
		if cf then
			Props.HayRoll(paint, cf, 2.6, folder)
		end
	end
	for _, offset in cfg.Crates do
		local cf = place(offset, 2)
		if cf then
			Props.Crate(paint, cf, 2.4, folder)
			Props.Crate(
				paint,
				cf * CFrame.new(0.3, 2.4, 0.2) * CFrame.Angles(0, 0.4, 0),
				1.8,
				folder
			)
		end
	end
	for _, offset in cfg.Barrels do
		local cf = place(offset, 2)
		if cf then
			Props.Barrel(paint, cf, 3, folder)
		end
	end
	for _, offset in cfg.Mushrooms do
		local cf = place(offset, 1)
		if cf then
			Props.Mushrooms(paint, cf, rng:NextNumber(1.4, 2.2), folder, rng)
		end
	end
end

local function buildSignposts(parent: Instance)
	local cfg = hubCfg.Signposts
	local folder = model("Signposts", parent)
	local enabled = {}
	for _, entry in cfg.Zones do
		if HubPaths.Enabled(entry) then
			table.insert(enabled, entry)
		end
	end
	-- Big signposts by the spawn and by the cauldron, pointing at every area.
	for _, spot in { cfg.Spawn, cfg.Centre } do
		local pos = ground(spot.X, spot.Z)
		if blocked(pos, 1) then
			continue
		end
		local arms: { Props.SignArm } = {}
		for i, entry in enabled do
			local target = HubLayout.Zone(entry.Zone).CFrame.Position
			table.insert(arms, {
				Text = entry.Text,
				Direction = target - pos,
				Role = if i % 2 == 0 then "Wood" else "Purple",
			})
		end
		if #arms > 0 then
			Props.Signpost(paint, facingCenter(pos), arms, folder)
		end
	end
	-- Each area's own sign is a glowing floor sign in front of it (FloorSigns, built below).
end

local function buildAmbience(parent: Instance)
	local folder = model("Ambience", parent)
	local radius = hubCfg.Radius
	local f = hubCfg.Particles.Fireflies
	local air = holder(
		"Fireflies",
		CFrame.new(at(Vector3.new(0, 6, 0))),
		Vector3.new(radius * 1.6, 8, radius * 1.6),
		folder
	)
	particles(air, {
		Rate = f.Rate,
		Color = ColorSequence.new(f.Color),
		LightEmission = 1,
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local m = hubCfg.Particles.Mist
	local mist = holder(
		"Mist",
		CFrame.new(at(Vector3.new(0, 1.5, 0))),
		Vector3.new(radius * 2, 1, radius * 2),
		folder
	)
	particles(mist, {
		Rate = m.Rate,
		Color = ColorSequence.new(m.Color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 8),
			NumberSequenceKeypoint.new(1, 14),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 10),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Orientation = Enum.ParticleOrientation.FacingCamera,
	})
end

-- Lobby sections -------------------------------------------------------------------------

local function sectionModules(): { ModuleScript }
	local list = {}
	local folder = script.Parent:FindFirstChild("Sections")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("ModuleScript") then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function sectionModule(name: string): any
	local folder = script.Parent:FindFirstChild("Sections")
	local module = folder and folder:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	return (require :: any)(module)
end

-- Runs one section's function (`fnName`, or Build if it has none); a broken section is
-- skipped with a warning, the rest of the hub still builds.
local function runSection(name: string, fnName: string, hub: Model): Model?
	local ok, result = pcall(function()
		local section = sectionModule(name)
		if not section then
			return nil
		end
		local fn = section[fnName]
		if type(fn) ~= "function" then
			fn = section.Build
		end
		return fn(hub, HubLayout.Zone(name))
	end)
	if not ok then
		warn(
			("[HubBuilder] The lobby section %s failed to build (the rest of the hub is fine): %s"):format(
				name,
				tostring(result)
			)
		)
		return nil
	end
	return if typeof(result) == "Instance" and result:IsA("Model") then result else nil
end

function HubBuilder.BuildSection(hub: Model, name: string): Model?
	return runSection(name, "Build", hub)
end

function HubBuilder.RepairSection(hub: Model, name: string): Model?
	return runSection(name, "Repair", hub)
end

local function buildSections(hub: Model)
	for _, module in sectionModules() do
		HubBuilder.BuildSection(hub, module.Name)
	end
end

-- Music and lighting -----------------------------------------------------------------------

--[[
	Hub music (Config.Hub.Music) as a looping, non-positional Sound named "Music" in the hub,
	in SoundService's "Music" group (players can mute it in Settings). Also run on a hub saved
	in Studio, so changing the SoundId in Config always takes effect.
]]
function HubBuilder.ApplyMusic(hub: Model)
	local cfg = hubCfg.Music
	local existing = hub:FindFirstChild("Music")
	if cfg.SoundId == "" then
		if existing then
			existing:Destroy()
		end
		return
	end
	local sound: Sound
	if existing and existing:IsA("Sound") then
		sound = existing
	else
		if existing then
			existing:Destroy()
		end
		sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.Parent = hub
	end
	sound.SoundId = cfg.SoundId
	sound.Volume = cfg.Volume
	sound.Looped = true
	local musicGroup = SoundService:FindFirstChild("Music")
	if musicGroup and musicGroup:IsA("SoundGroup") then
		sound.SoundGroup = musicGroup
	end
	sound.Playing = true
end

function HubBuilder.ApplyCustomNpcs(hub: Model)
	Npcs.ApplyCustom(hub)
end

--[[
	Lighting from Config.Hub.Lighting: the main settings plus HubAtmosphere,
	HubColorCorrection, HubBloom (src/client/ZoneLighting.luau fades these between the hub and
	the round map), HubSky (skipped when you put your own Sky in Lighting), HubDepthOfField
	and HubClouds (on Workspace.Terrain).
	Lighting.Technology can't be set from a script: set it to Future once in Studio.
]]
function HubBuilder.ApplyLighting()
	local cfg = hubCfg.Lighting
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient

	local function ensure(parent: Instance, className: string, name: string): Instance
		local existing = parent:FindFirstChild(name)
		if existing and existing.ClassName == className then
			return existing
		end
		if existing then
			existing:Destroy()
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = parent
		return created
	end
	-- Copies each setting onto the effect. A misspelt name or a wrong kind of value in
	-- Config.Hub.Lighting is skipped with a warning, so the rest of the lobby still loads.
	local function set(instance: Instance, values: { [string]: any })
		for key, value in values do
			if key == "Enabled" then
				continue
			end
			local ok, err = pcall(function()
				(instance :: any)[key] = value
			end)
			if not ok then
				warn(
					("[HubBuilder] Config.Hub.Lighting: couldn't set %s.%s (check its spelling and value): %s"):format(
						instance.ClassName,
						tostring(key),
						tostring(err)
					)
				)
			end
		end
	end
	local atmosphere = ensure(Lighting, "Atmosphere", "HubAtmosphere") :: Atmosphere
	set(atmosphere, cfg.Atmosphere)
	set(ensure(Lighting, "ColorCorrectionEffect", "HubColorCorrection"), cfg.ColorCorrection)
	set(ensure(Lighting, "BloomEffect", "HubBloom"), cfg.Bloom)
	-- Only one Atmosphere is used by the engine; drop any other one.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= atmosphere then
			child:Destroy()
		end
	end
	-- The sky (stars and a big moon), unless you put your own Sky in Lighting: yours wins.
	local ownSky = false
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") and child.Name ~= "HubSky" then
			ownSky = true
		end
	end
	if ownSky then
		local old = Lighting:FindFirstChild("HubSky")
		if old then
			old:Destroy()
		end
	else
		set(ensure(Lighting, "Sky", "HubSky"), cfg.Sky)
	end
	local dof = ensure(Lighting, "DepthOfFieldEffect", "HubDepthOfField") :: DepthOfFieldEffect
	set(dof, cfg.DepthOfField)
	dof.Enabled = cfg.DepthOfField.Enabled
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = ensure(terrain, "Clouds", "HubClouds") :: Clouds
		set(clouds, cfg.Clouds)
		clouds.Enabled = cfg.Clouds.Enabled
	end
end

-- The default baseplate SpawnLocation would compete with the hub spawn; switch it off. A
-- SpawnLocation you tagged HubSpawn yourself (e.g. one added with Model > Spawn) IS the hub
-- spawn, so it is left on.
function HubBuilder.DisableDefaultSpawn()
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") and not CollectionService:HasTag(child, Tags.HubSpawn) then
			child.Enabled = false
			child.Transparency = 1
			child.CanCollide = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		end
	end
end

-- Finding and cleaning up hubs ---------------------------------------------------------------

-- Every top-level piece of a built hub carries this attribute, so loose copies left
-- directly in Workspace (an ungrouped or pasted hub) can be recognised and removed.
HubBuilder.PieceAttribute = "HubPiece"

-- All Models named "Hub" directly in Workspace.
function HubBuilder.FindHubs(): { Model }
	local hubs = {}
	for _, child in workspace:GetChildren() do
		if child.Name == "Hub" and child:IsA("Model") then
			table.insert(hubs, child)
		end
	end
	return hubs
end

-- Name, class and part positions: two pieces with the same signature are the same object.
local function signature(instance: Instance): string
	local count, sum = 0, Vector3.zero
	local function add(d: Instance)
		if d:IsA("BasePart") then
			count += 1
			sum += d.CFrame.Position
		end
	end
	add(instance)
	for _, d in instance:GetDescendants() do
		add(d)
	end
	return ("%s|%s|%d|%.1f,%.1f,%.1f"):format(
		instance.Name,
		instance.ClassName,
		count,
		sum.X,
		sum.Y,
		sum.Z
	)
end

--[[
	Removes hub pieces lying loose in Workspace, outside `keep`:
	  - anything tagged with PieceAttribute,
	  - exact copies of one of `keep`'s pieces (same name, class and part positions),
	  - and, when a whole ungrouped hub is lying around (at least half of `keep`'s piece
	    names, with the same classes, are loose in Workspace), all of those pieces, even if
	    they were moved or edited. Older hubs have no tag, hence the last two rules.
	A single unrelated object that happens to share a name is never removed.
	Returns how many were removed.
]]
function HubBuilder.RemoveLoosePieces(keep: Model): number
	local exact: { [string]: boolean } = {}
	local kinds: { [string]: boolean } = {} -- "Name|ClassName" of keep's pieces
	local pieceCount = 0
	for _, child in keep:GetChildren() do
		exact[signature(child)] = true
		kinds[child.Name .. "|" .. child.ClassName] = true
		pieceCount += 1
	end

	local candidates: { Instance } = {}
	local sameKind: { Instance } = {}
	local namesSeen: { [string]: boolean } = {}
	local distinctNames = 0
	for _, child in workspace:GetChildren() do
		if child == keep or child:IsA("Terrain") or child:IsA("Camera") then
			continue
		end
		if child:GetAttribute(HubBuilder.PieceAttribute) or exact[signature(child)] then
			table.insert(candidates, child)
		elseif kinds[child.Name .. "|" .. child.ClassName] then
			table.insert(sameKind, child)
			if not namesSeen[child.Name] then
				namesSeen[child.Name] = true
				distinctNames += 1
			end
		end
	end
	if pieceCount > 0 and distinctNames * 2 >= pieceCount then
		for _, child in sameKind do
			table.insert(candidates, child)
		end
	end
	for _, child in candidates do
		child:Destroy()
	end
	return #candidates
end

-- Lobby areas whose feature is switched off ------------------------------------------------

--[[
	Lobby areas that have an on/off switch in Config.Features. A hub saved in the place (baked
	or Locked) keeps the pieces it was built with, so when one of these switches is off, the
	game takes that area out of the running game on every start (your saved place is not
	changed): the area's model is emptied (NPCs standing in it stay) and every part or model
	with one of its tags is removed, wherever it was moved or copied to. Web Scour and the
	Easter eggs do the same in their own services.
	  Feature  the switch in Config.Features
	  Section  the area's model in Workspace.Hub (built by src/server/Hub/Sections/<Section>.luau)
	  Tags     the tags of its working parts (src/shared/Tags.luau)
]]
local SWITCHED_AREAS: { { Feature: string, Section: string, Tags: { string } } } = {
	{ Feature = "ReadyPad", Section = "ReadyArea", Tags = { Tags.ReadyPad, Tags.ReadySign } },
	{
		Feature = "Parkour",
		Section = "Parkour",
		Tags = {
			Tags.ParkourStart,
			Tags.ParkourCheckpoint,
			Tags.ParkourFinish,
			Tags.ParkourHazard,
			Tags.ParkourBoard,
		},
	},
	{
		Feature = "CandyRush",
		Section = "CandyRush",
		Tags = { Tags.CandyRushStation, Tags.CandyRushPad, Tags.CandyRushBoard },
	},
	{ Feature = "Crates", Section = "CrateStand", Tags = { Tags.CrateDisplay } },
	{
		Feature = "TowerParkour",
		Section = "TowerParkour",
		Tags = {
			Tags.TowerStart,
			Tags.TowerCheckpoint,
			Tags.TowerFinish,
			Tags.TowerHazard,
			Tags.TowerVanish,
			Tags.TowerSpinner,
			Tags.TowerGear,
		},
	},
}

-- NPCs (and the shopkeeper) standing inside an area that is emptied are kept.
local function isNpc(instance: Instance): boolean
	if
		instance:GetAttribute("NpcId") ~= nil or CollectionService:HasTag(instance, Tags.ShopKeeper)
	then
		return true
	end
	for _, d in instance:GetDescendants() do
		if CollectionService:HasTag(d, Tags.ShopKeeper) then
			return true
		end
	end
	return false
end

-- Easter eggs hiding next to a part with one of `tags` (their Anchor in Config.EasterEggs.List):
-- with that part gone they would float in the air, so they go too (a hub built while the
-- feature is off leaves them out the same way). Returns how many were removed.
local function removeEggsAnchoredTo(tags: { string }): number
	local anchored: { [string]: boolean } = {}
	for _, egg in Config.EasterEggs.List do
		if table.find(tags, egg.Anchor) then
			anchored[egg.Id] = true
		end
	end
	local count = 0
	for _, instance in CollectionService:GetTagged(Tags.EasterEgg) do
		local id = instance:GetAttribute("EggId")
		if typeof(id) == "string" and anchored[id] and instance:IsDescendantOf(workspace) then
			local m = instance.Parent
			if m and m:IsA("Model") and m.PrimaryPart == instance then
				m:Destroy() -- the whole egg model (its look and button)
			else
				instance:Destroy()
			end
			count += 1
		end
	end
	return count
end

--[[
	Takes every area in SWITCHED_AREAS whose switch is off out of the running game, with any
	Easter egg hiding next to one of its tagged parts. Returns the names of those switches
	that had pieces to remove (empty when there was nothing). HubService runs it on every
	start; Bake never does, so the saved place keeps its pieces and turning the switch back on
	brings them back.
]]
function HubBuilder.RemoveSwitchedOff(hub: Model): { string }
	local features = Config.Features :: any
	local removed: { string } = {}
	for _, area in SWITCHED_AREAS do
		if features[area.Feature] then
			continue
		end
		local count = 0
		local section = hub:FindFirstChild(area.Section)
		if section then
			for _, child in section:GetChildren() do
				if not isNpc(child) then
					child:Destroy()
					count += 1
				end
			end
		end
		for _, tag in area.Tags do
			for _, instance in CollectionService:GetTagged(tag) do
				-- (a piece already removed with its area is no longer in Workspace)
				if instance:IsDescendantOf(workspace) and not isNpc(instance) then
					instance:Destroy()
					count += 1
				end
			end
		end
		count += removeEggsAnchoredTo(area.Tags)
		-- Its glowing floor sign goes too.
		for _, sign in CollectionService:GetTagged(Tags.FloorSign) do
			local zone = sign:GetAttribute("Zone")
			if
				sign:IsDescendantOf(workspace)
				and typeof(zone) == "string"
				and FloorSigns.FeatureOf(zone) == area.Feature
			then
				sign:Destroy()
				count += 1
			end
		end
		if count > 0 then
			table.insert(removed, area.Feature)
		end
	end
	return removed
end

-- Building -----------------------------------------------------------------------------------

local function newHub(): Model
	for _, existing in HubBuilder.FindHubs() do
		existing:Destroy()
	end
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub:SetAttribute("HubName", hubCfg.Name)
	return hub
end

local function finish(hub: Model, groundPart: BasePart)
	HubBuilder.ApplyMusic(hub)
	hub.PrimaryPart = groundPart
	for _, child in hub:GetChildren() do
		child:SetAttribute(HubBuilder.PieceAttribute, true)
	end
	HubPalette.Stamp(hub)
	hub.Parent = workspace
	HubBuilder.DisableDefaultSpawn()
end

function HubBuilder.Build(): Model
	rng = Random.new(hubCfg.Seed)
	local hub = newHub()
	local groundPart = buildPlaza(hub)
	HubBuilder.BuildSpawn(hub)
	buildSections(hub) -- the Ready area, shop, minigames... each in its zone
	Npcs.BuildAll(hub) -- NPCs with a Zone go inside that section's model
	local decorModel = model("Decor", hub)
	buildClockTower(decorModel)
	buildCauldron(decorModel)
	buildLamps(decorModel)
	buildJackOLanterns(decorModel)
	buildCandles(decorModel)
	buildBenches(decorModel)
	buildGraveyard(decorModel)
	buildTrees(decorModel)
	buildClutter(decorModel)
	buildSignposts(decorModel)
	FloorSigns.Build(hub) -- a glowing sign on the ground in front of each area
	buildAmbience(decorModel)
	HubExtras.Build(hub, decorModel) -- terrain, forest, mansion, statue, fence, paths (Config.Hub.Polish)
	-- (A custom shopkeeper model is swapped in by HubService when the game runs, so a hub baked
	-- into the place keeps the built keeper underneath.)
	hub:SetAttribute("BuildVersion", hubCfg.BuildVersion)
	finish(hub, groundPart)
	return hub
end

--[[
	The bare minimum when Build fails: a plain plaza, the spawn and the Ready pad. HubService
	adds the shopkeeper afterwards. It has no BuildVersion, so the next start tries the full
	hub again.
]]
function HubBuilder.BuildFallback(): Model
	local hub = newHub()
	hub:SetAttribute("Fallback", true)
	local plaza = model("Plaza", hub)
	local radius = hubCfg.Radius
	local groundPart = part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		Material = hubCfg.GroundMaterial,
	}, plaza)
	plaza.PrimaryPart = groundPart
	HubBuilder.BuildSpawn(hub)
	HubBuilder.BuildSection(hub, "ReadyArea")
	finish(hub, groundPart)
	return hub
end

return HubBuilder
