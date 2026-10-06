--!strict
--[[
	The Hide & Seek pumpkin. The decoy pumpkins on the Hide & Seek maps and the pumpkins that
	hiders turn into are made here from the same settings (Config.HideSeek.Pumpkin), so a hider
	looks exactly like a decoy. Each one gets a slightly different size and colour.

	Want your own pumpkin model? Put a Model named "HidingPumpkin" in
	ReplicatedStorage.Custom.Props (assets/Props/HidingPumpkin): every decoy AND every hider
	uses it (scaled to each pumpkin's height). Your model is only for looks: an invisible part
	called "Hitbox" (the pumpkin's size, its PrimaryPart) does the colliding and is what candy
	hits, so any model works. Hiders wear a copy of one of the map's decoys
	(src/server/Modes/HideSeek.luau), so they always match them; a map baked into
	ServerStorage.Maps gets your model when it loads (Kit.applyCustomProps), or for good with
	require(game.ServerScriptService.Server.Tools.Swap).Props() in the command bar.

	HidingPumpkin.Build(cframe, rng, parent) -> Model
	    A pumpkin standing on `cframe` (the middle of its bottom). Anchored; the big parts
	    collide and can be hit by candy. The mode unanchors it and welds it to a hider.
	HidingPumpkin.Decoy(cframe, rng, parent) -> Model
	    Build + the HidingDecoy tag (src/shared/Tags.luau): candy that hits it is a miss.
	HidingPumpkin.Size(rng) -> (width, height)   the random size Build uses
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Kit)

local HidingPumpkin = {}

local PROP_NAME = "HidingPumpkin"

function HidingPumpkin.Size(rng: Random): (number, number)
	local cfg = Config.HideSeek.Pumpkin
	local scale = 1 + rng:NextNumber(-cfg.SizeVariation, cfg.SizeVariation)
	-- A little squash or stretch too, so the rows don't look copy-pasted.
	local squash = 1 + rng:NextNumber(-0.06, 0.06)
	return cfg.Width * scale, cfg.Height * scale * squash
end

-- Everything random about one pumpkin, drawn before it is built (in the same order every
-- time), so a custom model never changes the rest of the map.
type Look = {
	Width: number,
	Height: number,
	Color: Color3,
	Twist: number,
	Tilt: CFrame,
	Leaf: number?, -- the leaf's turn, or nil for no leaf
}

local function pickLook(rng: Random): Look
	local cfg = Config.HideSeek.Pumpkin
	local width, height = HidingPumpkin.Size(rng)
	local base = cfg.Colors[rng:NextInteger(1, #cfg.Colors)]
	local color = Kit.shade(base, rng:NextNumber(-cfg.ColorVariation, cfg.ColorVariation))
	local twist = rng:NextNumber(0, math.pi / 3)
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))
	local leaf: number? = nil
	if rng:NextNumber() < cfg.LeafChance then
		leaf = rng:NextNumber(0, math.pi * 2)
	end
	return {
		Width = width,
		Height = height,
		Color = color,
		Twist = twist,
		Tilt = tilt,
		Leaf = leaf,
	}
end

-- An oval: a block part with a sphere mesh fills its whole size (a Ball part can't be oval).
local function oval(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Kit.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function build(cframe: CFrame, look: Look): Model
	local cfg = Config.HideSeek.Pumpkin
	local width, height, color = look.Width, look.Height, look.Color
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	local center = cframe * CFrame.new(0, height / 2, 0)
	-- The core shows in the grooves between the ribs, so it is a bit darker.
	local body = oval(
		"Body",
		Vector3.new(width * 0.82, height * 0.96, width * 0.82),
		center,
		Kit.shade(color, cfg.GrooveShade),
		m
	)
	-- Three long ovals crossing at 60 degrees make six rounded ribs.
	for i = 0, 2 do
		oval(
			"Rib",
			Vector3.new(width, height, width * 0.5),
			center * CFrame.Angles(0, look.Twist + i * math.pi / 3, 0),
			color,
			m
		)
	end
	local stemHeight = height * 0.3
	local stem = Kit.part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(stemHeight, width * 0.12, width * 0.12),
		CFrame = Kit.upright(cframe * CFrame.new(0, height * 0.92 + stemHeight / 2, 0) * look.Tilt),
		Color = cfg.StemColor,
		Material = Enum.Material.Wood,
		CanCollide = false,
	}, m)
	stem.CanQuery = false
	if look.Leaf then
		local leaf = oval(
			"Leaf",
			Vector3.new(width * 0.34, 0.14, width * 0.2),
			cframe
				* CFrame.new(0, height * 0.97, 0)
				* CFrame.Angles(0, look.Leaf, 0)
				* CFrame.new(width * 0.16, 0, 0)
				* CFrame.Angles(0, 0, math.rad(-12)),
			cfg.LeafColor,
			m
		)
		leaf.CanCollide = false
		leaf.CanQuery = false
	end
	m.PrimaryPart = body
	return m
end

function HidingPumpkin.Build(cframe: CFrame, rng: Random, parent: Instance): Model
	local look = pickLook(rng)
	local width, height = look.Width, look.Height
	local model = Kit.prop(PROP_NAME, cframe, parent, height, function()
		local built = build(cframe, look)
		built.Parent = parent
		return built
	end, {
		-- A custom model is only for looks: this invisible box collides and gets hit by candy.
		Hitbox = Vector3.new(width * 0.85, height, width * 0.85),
	})
	model.Name = "Pumpkin"
	model:SetAttribute("PumpkinWidth", width)
	model:SetAttribute("PumpkinHeight", height)
	return model
end

function HidingPumpkin.Decoy(cframe: CFrame, rng: Random, parent: Instance): Model
	local model = HidingPumpkin.Build(cframe, rng, parent)
	CollectionService:AddTag(model, Tags.HidingDecoy)
	return model
end

return HidingPumpkin
