--!strict
--[[
	Builds "Spooky Town Square", the lobby (Workspace.Hub), from Config.Hub, Config.Npcs and
	Config.Lobby. HubService decides WHEN to build (a saved hub is kept, see its header); this
	module knows HOW. Runs fine in Studio's edit mode too (src/server/Tools/Bake.luau).

	What it builds (every group is a Model with a readable name):
	  Workspace.Hub   attributes HubName, BuildVersion, PaletteColors (and Locked, if you set it)
	    Plaza         the cobbled ground
	    Spawn         where players appear (tag HubSpawn)
	    CandyRush, EasterEggs, Parkour, ReadyArea, Shop, WebScour
	                  the lobby sections: src/server/Hub/Sections/<Name>.luau builds each one in
	                  its Config.Lobby.Zones area. The Pumpkin Shop keeper stands in Shop.
	    Npcs          the Voting Board, Leaderboard Gravestone and Photo Spot (Hub/Npcs.luau)
	    Decor         only for looks: ClockTower, Cauldron, Lamps, Bunting, JackOLanterns, Candles,
	                  Graveyard, Trees, Ambience, and (HubExtras.luau) Forest, HauntedMansion,
	                  KingStatue, PumpkinPatch, OldGraves, Fence, Paths
	    Music
	Decorations never go inside a lobby zone. Parts coloured from Config.Hub.Palette carry the
	attribute PaletteRole. Props (Lamppost, JackOLantern, DeadTree, ...) are swapped for your own
	model when ReplicatedStorage.Custom.Props has one with the same name (Kit.prop).

	HubBuilder.Build() -> Model             a fresh hub in Workspace (old ones are removed)
	HubBuilder.BuildFallback() -> Model     plain plaza + spawn + Ready pad (if Build fails)
	HubBuilder.BuildSpawn(hub) -> SpawnLocation
	HubBuilder.BuildSection(hub, name) -> Model?   one section (Sections/<name>.luau)
	HubBuilder.RepairSection(hub, name) -> Model?  a section's Repair(), else its Build()
	HubBuilder.ApplyLighting(), ApplyMusic(hub), ApplyCustomNpcs(hub), DisableDefaultSpawn()
	HubBuilder.FindHubs(), RemoveLoosePieces(keep), PieceAttribute
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local HubExtras = require(script.Parent.HubExtras)
local HubLayout = require(script.Parent.HubLayout)
local HubPalette = require(script.Parent.HubPalette)
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

local function jackOLantern(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("JackOLantern", cf, parent, size * 1.2, function()
		return Kit.jackOLantern(cf, size, hubCfg.Palette :: any, parent)
	end)
end

local function cobweb(cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("Cobweb", cf, parent, size, function()
		local web = Kit.cobweb(cf, size, color("Bone"), parent)
		Kit.setRole(web, "Bone")
		return web
	end, { Anchor = "Center" })
end

local function glowLight(parent: BasePart, role: string, range: number, brightness: number)
	light(parent, color(role), range, brightness, true):SetAttribute("PaletteRole", role)
end

-- Ground and spawn -----------------------------------------------------------------------

local function buildPlaza(hub: Model): BasePart
	local plaza = model("Plaza", hub)
	local radius = hubCfg.Radius
	local ground = part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		Material = hubCfg.GroundMaterial,
	}, plaza)
	-- A darker ring path around the square.
	part({
		Name = "PathRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.05, radius * 1.45, radius * 1.45),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		PaletteShade = 0.25,
		Material = Enum.Material.Slate,
	}, plaza)
	part({
		Name = "InnerRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, radius * 1.3, radius * 1.3),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		Material = hubCfg.GroundMaterial,
	}, plaza)
	plaza.PrimaryPart = ground
	return ground
end

function HubBuilder.BuildSpawn(hub: Model): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn"
	s.Anchored = true
	s.Neutral = true
	s.Duration = 0
	s.Size = hubCfg.Spawn.Size
	s.CFrame = facingCenter(at(hubCfg.Spawn.Offset + Vector3.new(0, 1.1, 0)))
	s.Color = color("Purple")
	s:SetAttribute("PaletteRole", "Purple")
	s.Material = Enum.Material.SmoothPlastic
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = hub
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	Kit.surfaceText(s, "BOO!", color("Orange"), Enum.NormalId.Top)
	CollectionService:AddTag(s, Tags.HubSpawn)
	return s
end

-- Decorations ----------------------------------------------------------------------------

local function buildClockTower(parent: Instance)
	local cfg = hubCfg.ClockTower
	local base = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	local height = cfg.Floors * cfg.FloorHeight + 15
	Kit.prop("ClockTower", base, parent, height, function()
		local tower = model("ClockTower", parent)
		local cf = base
		local faceFloor: CFrame = cf
		local width: number = cfg.Width
		for i = 1, cfg.Floors do
			width = cfg.Width * (1 - 0.06 * (i - 1))
			local floorCf = cf * CFrame.new(0, cfg.FloorHeight / 2, 0)
			part({
				Name = "TowerFloor" .. i,
				Size = Vector3.new(width, cfg.FloorHeight, width),
				CFrame = floorCf,
				PaletteRole = "Stone",
				PaletteShade = if i % 2 == 0 then 0 else 0.15,
				Material = Enum.Material.Brick,
			}, tower)
			-- A glowing window on each side of the floor.
			for _, side in { 0, 90, 180, 270 } do
				part({
					Name = "Window",
					Size = Vector3.new(width * 0.25, cfg.FloorHeight * 0.4, 0.2),
					CFrame = floorCf
						* CFrame.Angles(0, math.rad(side), 0)
						* CFrame.new(0, 0, -width / 2 - 0.05),
					PaletteRole = "Glow",
					Material = Enum.Material.Neon,
				}, tower)
			end
			if i == cfg.Floors - 1 then
				faceFloor = floorCf
			end
			cf = cf * CFrame.new(0, cfg.FloorHeight, 0) * CFrame.Angles(0, 0, math.rad(cfg.Lean))
		end
		-- Pointy roof from shrinking slabs, with a glowing tip.
		for i = 0, 5 do
			local w = width * (1.1 - i * 0.18)
			part({
				Name = "RoofTier",
				Size = Vector3.new(w, 2, w),
				CFrame = cf * CFrame.new(0, 1 + i * 2, 0),
				PaletteRole = "Purple",
				PaletteShade = 0.4,
				Material = Enum.Material.Slate,
			}, tower)
		end
		local tip = part({
			Name = "Tip",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = cf * CFrame.new(0, 14, 0),
			PaletteRole = "Orange",
			Material = Enum.Material.Neon,
		}, tower)
		glowLight(tip, "Orange", 30, 2)

		-- Clock face just outside the front of the second-to-top floor.
		local faceWidth = cfg.Width * (1 - 0.06 * (cfg.Floors - 2))
		local faceCf = faceFloor * CFrame.new(0, 0, -faceWidth / 2 - 0.3)
		local diameter = faceWidth * 0.75
		part({
			Name = "ClockFace",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, diameter, diameter),
			CFrame = faceCf * CFrame.Angles(0, math.rad(90), 0),
			PaletteRole = "Bone",
			Material = Enum.Material.Neon,
		}, tower)
		local function hand(name: string, angle: number, length: number, thickness: number)
			part({
				Name = name,
				Size = Vector3.new(thickness, length, 0.2),
				CFrame = faceCf * CFrame.Angles(0, 0, -angle) * CFrame.new(0, length / 2, -0.35),
				PaletteRole = "Iron",
			}, tower)
		end
		local t = cfg.ClockTime
		hand("HourHand", ((t.Hour % 12) + t.Minute / 60) / 12 * math.pi * 2, diameter * 0.28, 0.5)
		hand("MinuteHand", t.Minute / 60 * math.pi * 2, diameter * 0.42, 0.3)
		for i = 0, 3 do
			part({
				Name = "HourMark",
				Size = Vector3.new(0.4, 0.9, 0.2),
				CFrame = faceCf
					* CFrame.Angles(0, 0, math.rad(i * 90))
					* CFrame.new(0, diameter * 0.4, -0.3),
				PaletteRole = "Iron",
			}, tower)
		end

		-- Cobwebs in the bottom front corners.
		for _, side in { -1, 1 } do
			cobweb(
				base
					* CFrame.new(
						side * (cfg.Width / 2 - 0.2),
						cfg.FloorHeight - 1.5,
						-cfg.Width / 2 - 0.15
					)
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
	local base = CFrame.new(at(cfg.Offset + Vector3.new(0, 1, 0)))
	local r = cfg.Radius
	Kit.prop("Cauldron", base, parent, r * 1.8 + 1, function()
		local m = model("Cauldron", parent)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			part({
				Name = "Leg",
				Size = Vector3.new(0.8, 2, 0.8),
				CFrame = base * CFrame.new(math.cos(a) * r * 0.6, 1, math.sin(a) * r * 0.6),
				PaletteRole = "Iron",
			}, m)
		end
		part({
			Name = "Pot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(r * 2, r * 1.6, r * 2),
			CFrame = base * CFrame.new(0, r * 0.9 + 1, 0),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
		part({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, r * 1.8, r * 1.8),
			CFrame = upright(base * CFrame.new(0, r * 1.55 + 1, 0)),
			PaletteRole = "Iron",
			Material = Enum.Material.Metal,
		}, m)
		local brew = part({
			Name = "Brew",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, r * 1.6, r * 1.6),
			CFrame = upright(base * CFrame.new(0, r * 1.65 + 1, 0)),
			PaletteRole = "Green",
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, m)
		glowLight(brew, "Green", 20, 2)
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
			EmissionDirection = Enum.NormalId.Right, -- the disc is rotated, so +X points up
		})
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 2
		fire.Color = color("Orange")
		fire.SecondaryColor = color("Glow")
		fire.Parent = holder("Embers", base * CFrame.new(0, 0.5, 0), Vector3.one, m)
		return m
	end)
end

local function buildLamps(parent: Instance)
	local cfg = hubCfg.Lampposts
	local lamps = model("Lamps", parent)
	local tops: { [number]: Vector3 } = {}
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2
		local pos = at(Vector3.new(math.cos(a) * cfg.Radius, 1, math.sin(a) * cfg.Radius))
		if blocked(pos, 2) then
			continue
		end
		local base = facingCenter(pos)
		Kit.prop("Lamppost", base, lamps, cfg.Height + 2.5, function()
			local lamp = model("Lamppost", lamps)
			local pole = part({
				Name = "Pole",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(cfg.Height, 0.7, 0.7),
				CFrame = upright(CFrame.new(pos + Vector3.new(0, cfg.Height / 2, 0))),
				PaletteRole = "Iron",
				Material = Enum.Material.Metal,
			}, lamp)
			local lantern = part({
				Name = "Lantern",
				Size = Vector3.new(1.6, 2, 1.6),
				CFrame = CFrame.new(pos + Vector3.new(0, cfg.Height + 1, 0)),
				PaletteRole = "Glow",
				Material = Enum.Material.Neon,
			}, lamp)
			part({
				Name = "Cap",
				Size = Vector3.new(2.2, 0.5, 2.2),
				CFrame = CFrame.new(pos + Vector3.new(0, cfg.Height + 2.25, 0)),
				PaletteRole = "Iron",
			}, lamp)
			glowLight(lantern, "Glow", 22, 1.5)
			if i % 3 == 0 then
				cobweb(base * CFrame.new(0, cfg.Height - 2, -0.5), hubCfg.Cobwebs.Size * 0.6, lamp)
			end
			lamp.PrimaryPart = pole
			return lamp
		end)
		tops[i] = pos + Vector3.new(0, cfg.Height - 0.5, 0)
	end

	-- Bunting: a sagging rope between neighbouring lamps with diamond flags.
	local bunting = model("Bunting", parent)
	local b = hubCfg.Bunting
	for i = 1, cfg.Count do
		local a, c = tops[i], tops[i % cfg.Count + 1]
		if not (a and c) then
			continue -- a lamp was left out (it stood in a lobby zone)
		end
		local function point(t: number): Vector3
			return a:Lerp(c, t) - Vector3.new(0, b.Sag * 4 * t * (1 - t), 0)
		end
		local segments = b.FlagsPerSpan + 1
		for s = 0, segments - 1 do
			local p1, p2 = point(s / segments), point((s + 1) / segments)
			decor({
				Name = "Rope",
				Size = Vector3.new(0.12, 0.12, (p2 - p1).Magnitude),
				CFrame = CFrame.lookAt((p1 + p2) / 2, p2),
				PaletteRole = "Bone",
			}, bunting)
		end
		local along = (c - a).Unit
		local normal = along:Cross(Vector3.yAxis).Unit
		for f = 1, b.FlagsPerSpan do
			local p = point(f / segments)
			local colorName = b.Colors[(f - 1) % #b.Colors + 1]
			-- A square turned 45 degrees hangs as a diamond from the rope.
			decor({
				Name = "Flag",
				Size = Vector3.new(0.1, 1.4, 1.4),
				CFrame = CFrame.fromMatrix(p - Vector3.new(0, 1, 0), normal, Vector3.yAxis)
					* CFrame.Angles(math.rad(45), 0, 0),
				PaletteRole = colorName,
			}, bunting)
		end
	end
end

local function buildJackOLanterns(parent: Instance)
	local cfg = hubCfg.JackOLanterns
	local folder = model("JackOLanterns", parent)
	for i = 1, cfg.Count do
		local a = (i / cfg.Count) * math.pi * 2 + math.pi / cfg.Count
		local pos = at(Vector3.new(math.cos(a) * cfg.Radius, 1, math.sin(a) * cfg.Radius))
		local size = cfg.Size * rng:NextNumber(0.75, 1.25)
		local turn = rng:NextNumber(-0.3, 0.3)
		if blocked(pos, 2) then
			continue
		end
		jackOLantern(facingCenter(pos) * CFrame.Angles(0, turn, 0), size, folder)
	end
end

local function buildCandles(parent: Instance)
	local cfg = hubCfg.Candles
	local folder = model("Candles", parent)
	for _ = 1, cfg.Count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(cfg.MinRadius, cfg.MaxRadius)
		local y = rng:NextNumber(cfg.MinHeight, cfg.MaxHeight)
		local height = rng:NextNumber(1.2, 2.2)
		local phase = rng:NextNumber(0, math.pi * 2)
		-- The bottom of the candle (it floats: the wax runs up from here).
		local foot = at(Vector3.new(math.cos(a) * r, y - height / 2, math.sin(a) * r))
		if blocked(foot, 1) then
			continue
		end
		local m = Kit.prop("Candle", CFrame.new(foot), folder, height + 0.6, function()
			local candle = model("Candle", folder)
			local wax = decor({
				Name = "Wax",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 0.6, 0.6),
				CFrame = upright(CFrame.new(foot + Vector3.new(0, height / 2, 0))),
				PaletteRole = "Bone",
			}, candle)
			local flame = decor({
				Name = "Flame",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.35, 0.6, 0.35),
				CFrame = CFrame.new(foot + Vector3.new(0, height + 0.3, 0)),
				PaletteRole = "Glow",
				Material = Enum.Material.Neon,
			}, candle)
			light(flame, color("Glow"), 8, 0.8, true):SetAttribute("PaletteRole", "Glow")
			candle.PrimaryPart = wax
			return candle
		end)
		m:SetAttribute("BobHeight", cfg.BobHeight)
		m:SetAttribute("Phase", phase)
		CollectionService:AddTag(m, Tags.HubFloat)
	end
end

local function buildGraveyard(parent: Instance)
	local cfg = hubCfg.Graveyard
	local origin = facingCenter(at(cfg.Offset + Vector3.new(0, 1, 0)))
	-- Draw every random number first, so leaving a stone out never moves the others.
	local tilts = {}
	for i in cfg.Epitaphs do
		tilts[i] =
			CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-8, 8)))
	end
	if blocked(origin.Position, 2) then
		return
	end
	local folder = model("Graveyard", parent)
	for i, epitaph in cfg.Epitaphs do
		local row = (i - 1) // 3
		local col = (i - 1) % 3
		local spot = origin * CFrame.new((col - 1) * 7, 0, row * 7)
		if blocked(spot.Position, 2) then
			continue
		end
		local cf = spot * tilts[i]
		HubExtras.Gravestone(cf, 3.6, 0, epitaph, folder)
		-- Little mound of dirt in front.
		part({
			Name = "DirtMound",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 0.8, 4.5),
			CFrame = cf * CFrame.new(0, 0, -2.8),
			PaletteRole = "Wood",
			PaletteShade = 0.3,
			Material = Enum.Material.Ground,
		}, folder)
	end
	-- Iron fence on three sides, open towards the plaza.
	local fence = model("GraveyardFence", folder)
	local corners = {
		origin * CFrame.new(-12, 0, -5),
		origin * CFrame.new(-12, 0, 18),
		origin * CFrame.new(12, 0, 18),
		origin * CFrame.new(12, 0, -5),
	}
	for c = 1, 3 do
		local a, b = corners[c].Position, corners[c + 1].Position
		if blocked(a, 1) or blocked(b, 1) then
			continue
		end
		local posts = math.floor((b - a).Magnitude / 3)
		for p = 0, posts do
			local pos = a:Lerp(b, p / posts)
			part({
				Name = "FencePost",
				Size = Vector3.new(0.4, 4, 0.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)),
				PaletteRole = "Iron",
			}, fence)
		end
		for _, y in { 1.2, 3.4 } do
			part({
				Name = "FenceRail",
				Size = Vector3.new(0.25, 0.25, (b - a).Magnitude),
				CFrame = CFrame.lookAt(
					(a + b) / 2 + Vector3.new(0, y, 0),
					b + Vector3.new(0, y, 0)
				),
				PaletteRole = "Iron",
			}, fence)
		end
	end
end

local function buildTrees(parent: Instance)
	local folder = model("Trees", parent)
	for _, offset in hubCfg.DeadTrees.Offsets do
		local base = CFrame.new(at(offset + Vector3.new(0, 1, 0)))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local height = rng:NextNumber(14, 20)
		local seed = rng:NextInteger(1, 1000000)
		if blocked(base.Position, 4) then
			continue
		end
		local tree = HubExtras.DeadTree(base, height, seed, folder)
		-- Falling leaves and a cobweb on the trunk (kept with the tree when it is moved).
		local canopy =
			holder("Leaves", base * CFrame.new(0, height, 0), Vector3.new(10, 1, 10), tree)
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
		if tree:GetAttribute("CustomProp") ~= true then
			cobweb(base * CFrame.new(0, height * 0.6, -1.15), hubCfg.Cobwebs.Size * 0.7, tree)
		end
	end
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
	local ground = holder(
		"Mist",
		CFrame.new(at(Vector3.new(0, 1.5, 0))),
		Vector3.new(radius * 2, 1, radius * 2),
		folder
	)
	particles(ground, {
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

function HubBuilder.ApplyLighting()
	local cfg = hubCfg.Lighting
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing and existing.ClassName == className then
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end
	local atmosphere = ensure("Atmosphere", "HubAtmosphere") :: Atmosphere
	for key, value in cfg.Atmosphere do
		(atmosphere :: any)[key] = value
	end
	local cc = ensure("ColorCorrectionEffect", "HubColorCorrection") :: ColorCorrectionEffect
	for key, value in cfg.ColorCorrection do
		(cc :: any)[key] = value
	end
	local bloom = ensure("BloomEffect", "HubBloom") :: BloomEffect
	for key, value in cfg.Bloom do
		(bloom :: any)[key] = value
	end
	-- Only one Atmosphere is used by the engine; drop any other one.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= atmosphere then
			child:Destroy()
		end
	end
end

-- The default baseplate SpawnLocation would compete with the hub spawn; switch it off.
function HubBuilder.DisableDefaultSpawn()
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
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

local function finish(hub: Model, ground: BasePart)
	HubBuilder.ApplyMusic(hub)
	hub.PrimaryPart = ground
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
	local ground = buildPlaza(hub)
	HubBuilder.BuildSpawn(hub)
	buildSections(hub) -- the Ready area, shop, minigames... each in its zone
	Npcs.BuildAll(hub) -- NPCs with a Zone go inside that section's model
	local decorModel = model("Decor", hub)
	buildClockTower(decorModel)
	buildCauldron(decorModel)
	buildLamps(decorModel)
	buildJackOLanterns(decorModel)
	buildCandles(decorModel)
	buildGraveyard(decorModel)
	buildTrees(decorModel)
	buildAmbience(decorModel)
	HubExtras.Build(hub, decorModel) -- terrain, forest, mansion, statue, fence, paths (Config.Hub.Polish)
	-- (A custom shopkeeper model is swapped in by HubService when the game runs, so a hub baked
	-- into the place keeps the built keeper underneath.)
	hub:SetAttribute("BuildVersion", hubCfg.BuildVersion)
	finish(hub, ground)
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
	local ground = part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = upright(CFrame.new(at(Vector3.new(0, 0.5, 0)))),
		PaletteRole = "Ground",
		Material = hubCfg.GroundMaterial,
	}, plaza)
	plaza.PrimaryPart = ground
	HubBuilder.BuildSpawn(hub)
	HubBuilder.BuildSection(hub, "ReadyArea")
	finish(hub, ground)
	return hub
end

return HubBuilder
