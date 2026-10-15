--!strict
--[[
	"Crumbling Crypt" map builder (settings: src/shared/Config/Maps/CrumblingCrypt.luau), the
	Crumbling Crypt (TileFall) mode's map.

	  Floor       the goo pit (the whole crypt floor), tagged TileFallGoo: fall into it = out
	  Tiles       the slab floor, 3 layers (Easy) over the goo: src/server/Modes/TileFallBoard.luau
	              (every slab tagged TileFallTile, attribute Layer)
	  Spawns      start spots in a ring on the top layer
	  Crypt       the walls round the pit, the ledges along them and the sign
	  Pillars     stone pillars round the slabs, each with a candle and a skull on top
	  Decor       gravestones and skulls on the ledges, bats over the slabs
	  GooGlow     the green glow and bubbles under the slabs, and the lights shining up
	Everything that isn't a slab, the goo, a wall or a ledge is walk-through decoration, so
	nobody can stand on a pillar and skip the game.
	Repeated decorations are props (Kit.prop), so one model in ReplicatedStorage.Custom.Props
	swaps every copy: CryptPillar, Skull, Candle, Gravestone, Bat.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Build.Props)
local TileFallBoard = require(script.Parent.Parent.Modes.TileFallBoard)

local CrumblingCrypt = {}

-- A skull standing on cf (front = cf.LookVector), `size` studs tall.
local function skull(paint: Kit.Painter, cf: CFrame, size: number, parent: Instance): Model
	return Kit.prop("Skull", cf, parent, size, function()
		local m = Kit.model("Skull", parent)
		local s = size
		local head = paint.decor({
			Name = "Cranium",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9 * s, 0.78 * s, 0.95 * s),
			CFrame = cf * CFrame.new(0, 0.58 * s, 0),
			PaletteRole = "Bone",
		}, m)
		paint.decor({
			Name = "Jaw",
			Size = Vector3.new(0.58 * s, 0.26 * s, 0.6 * s),
			CFrame = cf * CFrame.new(0, 0.15 * s, -0.12 * s),
			PaletteRole = "Bone",
			PaletteShade = 0.06,
		}, m)
		for _, side in { -1, 1 } do
			paint.decor({
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.24 * s,
				CFrame = cf * CFrame.new(side * 0.2 * s, 0.55 * s, -0.4 * s),
				PaletteRole = "Dark",
			}, m)
		end
		paint.decor({
			Name = "Nose",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.1 * s, 0.14 * s, 0.1 * s),
			CFrame = cf * CFrame.new(0, 0.36 * s, -0.44 * s),
			PaletteRole = "Dark",
		}, m)
		m.PrimaryPart = head
		return m
	end, { Visual = true })
end

-- A stone pillar standing on cf, `height` studs tall.
local function pillar(paint: Kit.Painter, cf: CFrame, height: number, parent: Instance): Model
	return Kit.prop("CryptPillar", cf, parent, height, function()
		local m = Kit.model("CryptPillar", parent)
		local base = paint.decor({
			Name = "Base",
			Size = Vector3.new(6, 3, 6),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			PaletteRole = "Pillar",
			PaletteShade = 0.15,
			Material = Enum.Material.Slate,
		}, m)
		local shaft = height - 5
		paint.roundedDecor({
			Name = "Shaft",
			Size = Vector3.new(4, shaft, 4),
			CFrame = cf * CFrame.new(0, 3 + shaft / 2, 0),
			PaletteRole = "Pillar",
			Material = Enum.Material.Slate,
		}, m)
		for _, at in { 0.3, 0.7 } do
			paint.roundedDecor({
				Name = "Ring",
				Size = Vector3.new(4.4, 0.6, 4.4),
				CFrame = cf * CFrame.new(0, 3 + shaft * at, 0),
				PaletteRole = "Pillar",
				PaletteShade = 0.2,
				Material = Enum.Material.Slate,
			}, m)
		end
		paint.decor({
			Name = "Capital",
			Size = Vector3.new(6, 2, 6),
			CFrame = cf * CFrame.new(0, height - 1, 0),
			PaletteRole = "Pillar",
			PaletteShade = 0.1,
			Material = Enum.Material.Slate,
		}, m)
		m.PrimaryPart = base
		return m
	end, { Visual = true })
end

function CrumblingCrypt.Build(def: any): Model
	local origin: Vector3 = Config.Maps.Origin
	local size: Vector3 = def.Size
	local colors = def.Colors
	local board = def.Board
	local decor = def.Decor
	local rng = Random.new(def.Seed)
	local model = Instance.new("Model")
	model.Name = def.Id
	local gooY = origin.Y + size.Y / 2
	local center = Vector3.new(origin.X, gooY, origin.Z)
	local half = board.Size / 2
	local paint = Kit.painter({
		Pillar = colors.Pillar,
		Stone = colors.Stone,
		Bone = colors.Bone,
		Glow = colors.Glow,
		Dark = colors.Dark,
		Green = colors.Green,
	})

	-- The goo pit (the map's Floor).
	local goo = Kit.part({
		Name = "Floor",
		Size = size,
		Position = origin,
		Color = colors.Goo,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.15,
	}, model)
	CollectionService:AddTag(goo, Tags.TileFallGoo)

	-- The slabs: built for the default difficulty (a Hard round rebuilds them).
	local levels = Config.TileFall.Difficulty
	local default = levels[Config.Difficulty.Default] or levels.Easy
	TileFallBoard.Build(model, center, board, default.Layers, default.TileSize, colors)
	local topY = TileFallBoard.LayerTop(gooY, board, 1)

	-- Start spots on the top layer.
	local spawns = Instance.new("Folder")
	spawns.Name = def.SpawnFolder
	spawns.Parent = model
	for i = 1, def.Spawns do
		local angle = (i / def.Spawns) * math.pi * 2
		Kit.holder(
			"Spawn",
			CFrame.new(
				center.X + math.cos(angle) * def.SpawnRadius,
				topY + 0.5,
				center.Z + math.sin(angle) * def.SpawnRadius
			),
			Vector3.new(4, 1, 4),
			spawns
		)
	end

	-- The crypt: walls, ledges and the sign.
	local crypt = Kit.group("Crypt", model)
	local wallH: number = def.WallHeight
	local thick = 4
	for _, w in
		{
			{
				Vector3.new(size.X + thick * 2, wallH, thick),
				Vector3.new(0, 0, size.Z / 2 + thick / 2),
			},
			{
				Vector3.new(size.X + thick * 2, wallH, thick),
				Vector3.new(0, 0, -size.Z / 2 - thick / 2),
			},
			{ Vector3.new(thick, wallH, size.Z), Vector3.new(size.X / 2 + thick / 2, 0, 0) },
			{ Vector3.new(thick, wallH, size.Z), Vector3.new(-size.X / 2 - thick / 2, 0, 0) },
		}
	do
		local wall = Kit.part({
			Name = "Wall",
			Size = w[1],
			Position = center + w[2] + Vector3.new(0, wallH / 2 - size.Y / 2, 0),
			Color = colors.Wall,
			Material = Enum.Material.Slate,
		}, crypt)
		Kit.decor({
			Name = "WallTrim",
			Size = Vector3.new(w[1].X + 1, 2, w[1].Z + 1),
			Position = wall.Position + Vector3.new(0, wallH / 2, 0),
			Color = colors.WallTrim,
			Material = Enum.Material.Slate,
		}, crypt)
	end
	local ledgeW: number = decor.LedgeWidth
	local ledgeH: number = decor.LedgeHeight
	local ledges: { { From: Vector3, To: Vector3, Face: Vector3 } } = {}
	for _, side in
		{
			{ Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) },
			{ Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) },
			{ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) },
			{ Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) },
		}
	do
		local out, along = side[1], side[2]
		local mid = center + out * (size.Z / 2 - ledgeW / 2)
		local length = size.X - (if along.X ~= 0 then 0 else ledgeW * 2)
		Kit.part({
			Name = "Ledge",
			Size = Vector3.new(
				if along.X ~= 0 then length else ledgeW,
				ledgeH + 1,
				if along.Z ~= 0 then length else ledgeW
			),
			Position = mid + Vector3.new(0, (ledgeH + 1) / 2 - 1, 0),
			Color = colors.Ledge,
			Material = Enum.Material.Slate,
		}, crypt)
		local top = mid + Vector3.new(0, ledgeH, 0)
		table.insert(ledges, {
			From = top - along * (length / 2 - 4),
			To = top + along * (length / 2 - 4),
			Face = -out,
		})
	end
	-- The sign on the north wall, facing the slabs.
	local signPos = center + Vector3.new(0, board.TopHeight + 14, -size.Z / 2 + 0.3)
	local sign = Kit.decor({
		Name = "Sign",
		Size = Vector3.new(60, 9, 0.4),
		CFrame = CFrame.lookAt(signPos, signPos + Vector3.new(0, 0, 1)),
		Transparency = 1,
	}, crypt)
	Kit.surfaceText(sign, def.SignText, colors.Sign)
	local subPos = signPos - Vector3.new(0, 7, 0)
	local sub = Kit.decor({
		Name = "SubSign",
		Size = Vector3.new(44, 4, 0.4),
		CFrame = CFrame.lookAt(subPos, subPos + Vector3.new(0, 0, 1)),
		Transparency = 1,
	}, crypt)
	Kit.surfaceText(sub, def.SignSubText, colors.Bone)

	-- Pillars round the slabs, a candle and a skull on each.
	local pillars = Kit.group("Pillars", model)
	local perSide: number = decor.PillarsPerSide
	local ring = half + decor.PillarGap
	local spots: { Vector3 } = {}
	for _, side in
		{
			{ Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) },
			{ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) },
			{ Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) },
		}
	do
		for i = 1, perSide do
			local t = if perSide == 1 then 0 else (i - 1) / (perSide - 1) * 2 - 1
			table.insert(spots, center + side[1] * ring + side[2] * (t * half * 0.75))
		end
	end
	local litEvery = math.max(1, math.floor(#spots / math.max(decor.LitCandles, 1)))
	local lit = 0
	for i, spot in spots do
		local height: number = decor.PillarHeight
		local face = CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
		pillar(paint, face, height, pillars)
		local glow = lit < decor.LitCandles and (i - 1) % litEvery == 0
		if glow then
			lit += 1
		end
		local drips = 1 + i % 3
		Props.Candle(
			paint,
			face * CFrame.new(1.6, height, 0.8),
			2.4,
			pillars,
			{ Light = glow, Drips = drips }
		)
		Props.Candle(paint, face * CFrame.new(1.9, height, -1.2), 1.4, pillars, { Drips = 1 })
		skull(paint, face * CFrame.new(-1.2, height, -0.6), 2.2, pillars)
	end

	-- Gravestones and skulls on the ledges, bats over the slabs.
	local scenery = Kit.group("Decor", model)
	local styles = { "Round", "Cross", "Pointed" }
	for i = 1, decor.Gravestones do
		local ledge = ledges[(i - 1) % #ledges + 1]
		local t = rng:NextNumber(0.05, 0.95)
		local style = styles[rng:NextInteger(1, #styles)]
		local tall = rng:NextNumber(3.2, 4.6)
		local turn = rng:NextNumber(-0.25, 0.25)
		local at = ledge.From:Lerp(ledge.To, t) - ledge.Face * 1.5
		Props.Gravestone(
			paint,
			CFrame.lookAt(at, at + ledge.Face) * CFrame.Angles(0, turn, 0),
			tall,
			scenery,
			{ Style = style }
		)
	end
	for i = 1, decor.Skulls do
		local ledge = ledges[(i - 1) % #ledges + 1]
		local t = rng:NextNumber(0.05, 0.95)
		local tall = rng:NextNumber(1.2, 2)
		local turn = rng:NextNumber(-0.6, 0.6)
		local at = ledge.From:Lerp(ledge.To, t) + ledge.Face * rng:NextNumber(0, 2.5)
		skull(paint, CFrame.lookAt(at, at + ledge.Face) * CFrame.Angles(0, turn, 0), tall, scenery)
	end
	for _ = 1, decor.Bats do
		local x = rng:NextNumber(-half, half)
		local z = rng:NextNumber(-half, half)
		local y = board.TopHeight + rng:NextNumber(16, 26)
		local turn = rng:NextNumber(0, math.pi * 2)
		local phase = rng:NextNumber(0, math.pi * 2)
		local batSize = rng:NextNumber(1.4, 2.2)
		Props.Bat(
			paint,
			CFrame.new(center + Vector3.new(x, y, z)) * CFrame.Angles(0, turn, 0),
			batSize,
			scenery,
			phase
		)
	end

	-- The glow under the slabs: a see-through neon sheet on the goo, bubbles, lights.
	local glow = Kit.group("GooGlow", model)
	Kit.decor({
		Name = "Glow",
		Size = Vector3.new(board.Size + 16, 0.2, board.Size + 16),
		Position = center + Vector3.new(0, 0.15, 0),
		Color = colors.GooGlow,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	}, glow)
	local bubbles = Kit.holder(
		"Bubbles",
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Vector3.new(board.Size + 10, 1, board.Size + 10),
		glow
	)
	Kit.particles(bubbles, {
		Rate = 14,
		Color = ColorSequence.new(colors.GooGlow),
		LightEmission = 0.8,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.4),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(1, 3),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local lights: number = decor.GooLights
	local across = math.max(1, math.ceil(math.sqrt(lights)))
	for i = 1, lights do
		local gx = ((i - 1) % across + 0.5) / across * 2 - 1
		local gz = (math.floor((i - 1) / across) + 0.5) / across * 2 - 1
		local holder = Kit.holder(
			"GooLight",
			CFrame.new(center + Vector3.new(gx * half * 0.6, 3, gz * half * 0.6)),
			Vector3.one,
			glow
		)
		Kit.light(holder, colors.GooGlow, 60, 1.6, false)
	end

	Kit.ambientParticles(center, Vector3.new(board.Size, 0, board.Size), def.Particles, model)
	return model
end

return CrumblingCrypt
