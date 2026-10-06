--!strict
--[[
	Lobby section: the hidden Easter eggs (settings and the egg list: Config.EasterEggs).

	Workspace.Hub.EasterEggs
	  Shy Shop Pumpkin, Golden Patch Pumpkin, ...   one Model per egg, named after it. Its
	        PrimaryPart "Egg" is the egg that counts: tag EasterEgg, attributes EggId and
	        Coins, and a "Take" button (EggPrompt). Move or copy eggs in Studio freely.

	Eggs hide next to other things in the lobby (each egg's Anchor and Offset), and those are
	built after the sections (NPCs, decorations), so the eggs are placed once the whole hub is
	built: when the hub is put into Workspace. EasterEggService also places any egg that is
	missing when the game starts (a hub saved before eggs existed, or one deleted by hand).
	Each egg drops onto whatever is below its spot (Snap), and steps aside a little if its spot
	is inside something solid.

	EasterEggs.Build(hub, zone) -> Model          the (empty) EasterEggs model; places the eggs
	                                              when the hub is in the game
	EasterEggs.PlaceMissing(hub) -> { string }    places every Config egg the hub doesn't have
	                                              yet; returns their ids
	EasterEggs.Anchor(hub, name) -> CFrame?       where an Anchor is (nil = not in the game),
	                                              turned to face the middle of the lobby
	EasterEggs.BuildEgg(egg, base, parent) -> (Model, BasePart)
	                                              one egg standing on `base`, and its egg part
	Off (Config.Features.EasterEggs = false): only the empty model.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)
local Npcs = require(script.Parent.Parent.Npcs)

type Zone = HubLayout.Zone
type Egg = {
	Id: string,
	Name: string,
	Coins: number,
	Look: string?,
	Anchor: string,
	Offset: Vector3,
	Snap: (number | boolean)?,
	Hint: string,
}

local EasterEggs = {}

local cfg = Config.EasterEggs
local colors = cfg.Colors
local LOOKS = { GoldenPumpkin = true, Candy = true, Lollipop = true, Skull = true, Ghost = true }
local SNAP_DEPTH = 12 -- studs below the spot the drop still finds the ground
local warned: { [string]: boolean } = {}

-- The hub's EasterEggs model (made if it is missing).
local function folderOf(hub: Model): Model
	local existing = hub:FindFirstChild("EasterEggs")
	if existing and existing:IsA("Model") then
		return existing
	end
	local m = Kit.model("EasterEggs", hub)
	m:SetAttribute("HubPiece", true)
	return m
end

-- Is there an egg with this id in the hub (or anywhere in the game) already?
local function hasEgg(hub: Model, id: string): boolean
	for _, instance in CollectionService:GetTagged(Tags.EasterEgg) do
		if
			instance:GetAttribute("EggId") == id
			and (instance:IsDescendantOf(hub) or instance:IsDescendantOf(workspace))
		then
			return true
		end
	end
	return false
end

-- Anchors ---------------------------------------------------------------------------------------------

local function facing(position: Vector3, turn: CFrame): CFrame
	return CFrame.new(position) * CustomAssets.Yaw(turn)
end

-- The spot an NPC stands on (from its prompt holder, so it follows the NPC when it is moved).
local function npcSpot(hub: Model, def: any): CFrame
	local m = Npcs.Find(hub, def.Id)
	local holder = m and m:FindFirstChild("PromptAnchor", true)
	if holder and holder:IsA("BasePart") then
		local p = Config.Npcs.Prompt
		return facing((holder.CFrame * CFrame.new(0, -p.Height, p.Forward)).Position, holder.CFrame)
	end
	local spot = Npcs.Spot(def)
	return facing(spot.Position, spot)
end

local function taggedSpot(hub: Model, tag: string): CFrame?
	local inHub: { Instance } = {}
	local elsewhere: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(hub) then
			table.insert(inHub, instance)
		elseif instance:IsDescendantOf(workspace) then
			table.insert(elsewhere, instance)
		end
	end
	local list = if #inHub > 0 then inHub else elsewhere
	-- Parts before models, then by name, so the same one is picked every time.
	table.sort(list, function(a: Instance, b: Instance): boolean
		local pa, pb = a:IsA("BasePart"), b:IsA("BasePart")
		if pa ~= pb then
			return pa
		end
		return a:GetFullName() < b:GetFullName()
	end)
	local first = list[1]
	if not first then
		return nil
	end
	if first:IsA("BasePart") then
		-- An NPC's prompt holder (the ShopKeeper tag): use the spot the NPC stands on.
		local prompt = first:FindFirstChildOfClass("ProximityPrompt")
		local npcId = prompt and prompt:GetAttribute("NpcId")
		if typeof(npcId) == "string" then
			local p = Config.Npcs.Prompt
			return facing(
				(first.CFrame * CFrame.new(0, -p.Height, p.Forward)).Position,
				first.CFrame
			)
		end
		return facing(first.Position, first.CFrame)
	elseif first:IsA("Model") then
		local pivot = first:GetPivot()
		return facing(pivot.Position, pivot)
	end
	return nil
end

-- A lobby landmark with an Offset in Config.Hub (ClockTower) or Config.Hub.Polish (Mansion).
local function landmark(name: string): Vector3?
	for _, group in { Config.Hub :: any, (Config.Hub :: any).Polish } do
		local entry = type(group) == "table" and group[name]
		if type(entry) == "table" and typeof(entry.Offset) == "Vector3" then
			return entry.Offset
		end
	end
	return nil
end

function EasterEggs.Anchor(hub: Model, name: string): CFrame?
	if name == "Hub" then
		return CFrame.new(HubLayout.At(Vector3.new(0, 1, 0)))
	end
	if Config.Lobby.Zones[name] then
		return HubLayout.Zone(name).CFrame
	end
	for _, def in Config.Npcs.List do
		if def.Id == name then
			return npcSpot(hub, def)
		end
	end
	local spot = taggedSpot(hub, name)
	if spot then
		return spot
	end
	local offset = landmark(name)
	if offset then
		return HubLayout.FacingCenter(HubLayout.At(offset + Vector3.new(0, 1, 0)))
	end
	return nil
end

-- Is `name` something an anchor can be at all (to warn about typos, not about switched-off
-- features whose tagged parts aren't there)?
local function knownAnchor(name: string): boolean
	if name == "Hub" or Config.Lobby.Zones[name] or landmark(name) then
		return true
	end
	for _, def in Config.Npcs.List do
		if def.Id == name then
			return true
		end
	end
	for _, tag in Tags :: any do
		if tag == name then
			return true
		end
	end
	return false
end

-- Where an egg goes ---------------------------------------------------------------------------------

local function ignoreList(hub: Model): { Instance }
	local list: { Instance } = { folderOf(hub) }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(list, character)
		end
	end
	return list
end

-- Drops a spot onto whatever solid thing is below it (looking from `height` studs above).
local function drop(spot: Vector3, height: number, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local from = spot + Vector3.new(0, height, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -(height + SNAP_DEPTH), 0), params)
	return if hit then hit.Position else spot
end

-- Is there room for an egg standing on `base` (nothing solid in the way)?
local function roomAt(base: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local size = cfg.Size
	local box = Vector3.new(size * 0.8, size * 0.7, size * 0.8)
	local centre = base + Vector3.new(0, size * 0.5 + 0.15, 0)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(centre), box, params) do
		if part:IsA("BasePart") and not part:IsA("Terrain") and part.CanCollide then
			return false
		end
	end
	return true
end

-- The base (bottom middle) of an egg at its anchor, stepping aside if the spot is blocked.
local function eggBase(egg: Egg, anchor: CFrame, ignore: { Instance }): Vector3
	local snap = egg.Snap
	local height: number? = if snap == false
		then nil
		elseif type(snap) == "number" then snap
		else cfg.SnapHeight
	local function at(offset: Vector3): Vector3
		local spot = (anchor * CFrame.new(offset)).Position
		return if height then drop(spot, height, ignore) else spot
	end
	local first = at(egg.Offset)
	if not height or roomAt(first, ignore) then
		return first
	end
	for _, distance in { 2, 4 } do
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local base =
				at(egg.Offset + Vector3.new(math.cos(a) * distance, 0, math.sin(a) * distance))
			if roomAt(base, ignore) then
				return base
			end
		end
	end
	return first
end

-- Egg looks -------------------------------------------------------------------------------------------

local function bit(props: { [string]: any }, parent: Instance, round: boolean?): Part
	local p = Kit.decor(props, parent)
	p.CastShadow = false
	if round then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end

-- Builds the look on `base` (bottom middle, front = base.LookVector); returns the egg part.
local function buildLook(look: string, base: CFrame, m: Model): BasePart
	local s = cfg.Size
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x * s, y * s, z * s)
	end
	if look == "Candy" then
		local body = bit({
			Name = "Egg",
			Size = Vector3.new(1, 0.62, 0.62) * s,
			CFrame = at(0, 0.36, 0),
			Color = colors.Candy,
			Material = Enum.Material.Neon,
		}, m, true)
		bit({
			Name = "Stripe",
			Size = Vector3.new(0.28, 0.64, 0.64) * s,
			CFrame = at(0, 0.36, 0),
			Color = colors.Wrapper,
		}, m, true)
		for _, side in { -1, 1 } do
			bit({
				Name = "Wrapper",
				Size = Vector3.new(0.3, 0.55, 0.08) * s,
				CFrame = at(side * 0.6, 0.36, 0) * CFrame.Angles(math.rad(side * 25), 0, 0),
				Color = colors.Wrapper,
			}, m)
		end
		return body
	elseif look == "Lollipop" then
		-- A swirly lollipop on its stick, its round face towards the front.
		bit({
			Name = "Stick",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.75 * s, 0.12 * s, 0.12 * s),
			CFrame = Kit.upright(at(0, 0.375, 0)),
			Color = colors.Wrapper,
		}, m)
		local face = at(0, 1.05, 0) * CFrame.Angles(0, math.rad(90), 0) -- a Cylinder's flat side faces X
		local candy = bit({
			Name = "Egg",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2 * s, 0.85 * s, 0.85 * s),
			CFrame = face,
			Color = colors.Candy,
			Material = Enum.Material.Neon,
		}, m)
		for i, ring in { 0.62, 0.38, 0.16 } do
			bit({
				Name = "Swirl",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new((0.22 + i * 0.01) * s, ring * s, ring * s),
				CFrame = face,
				Color = if i % 2 == 1 then colors.Wrapper else colors.Candy,
				Material = if i % 2 == 1 then Enum.Material.SmoothPlastic else Enum.Material.Neon,
			}, m)
		end
		return candy
	elseif look == "Skull" then
		local head = bit({
			Name = "Egg",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.95 * s),
			CFrame = at(0, 0.55, 0),
			Color = colors.Bone,
		}, m)
		bit({
			Name = "Jaw",
			Size = Vector3.new(0.58, 0.26, 0.5) * s,
			CFrame = at(0, 0.17, -0.12),
			Color = colors.Bone,
		}, m)
		for _, side in { -1, 1 } do
			bit({
				Name = "Eye",
				Size = Vector3.new(0.27, 0.3, 0.12) * s,
				CFrame = at(side * 0.2, 0.6, -0.4),
				Color = colors.Eyes,
			}, m, true)
			bit({
				Name = "Twinkle",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (0.08 * s),
				CFrame = at(side * 0.17, 0.66, -0.47),
				Color = colors.Sparkle,
				Material = Enum.Material.Neon,
			}, m)
		end
		bit({
			Name = "Nose",
			Size = Vector3.new(0.12, 0.12, 0.08) * s,
			CFrame = at(0, 0.42, -0.45),
			Color = colors.Eyes,
		}, m, true)
		for i = -1, 1 do
			bit({
				Name = "Tooth",
				Size = Vector3.new(0.1, 0.1, 0.05) * s,
				CFrame = at(i * 0.13, 0.25, -0.37),
				Color = colors.Eyes,
			}, m)
		end
		return head
	elseif look == "Ghost" then
		local body = bit({
			Name = "Egg",
			Size = Vector3.new(0.85, 1.1, 0.8) * s,
			CFrame = at(0, 0.75, 0),
			Color = colors.Ghost,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		}, m, true)
		bit({
			Name = "Tail",
			Size = Vector3.new(0.55, 0.42, 0.5) * s,
			CFrame = at(0.16, 0.22, 0.1) * CFrame.Angles(0, 0, math.rad(-20)),
			Color = colors.Ghost,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		}, m, true)
		for _, side in { -1, 1 } do
			bit({
				Name = "Eye",
				Size = Vector3.new(0.18, 0.28, 0.1) * s,
				CFrame = at(side * 0.17, 0.88, -0.39),
				Color = colors.Eyes,
			}, m, true)
		end
		bit({
			Name = "Mouth",
			Size = Vector3.new(0.16, 0.16, 0.08) * s,
			CFrame = at(0, 0.62, -0.4),
			Color = colors.Eyes,
		}, m, true)
		return body
	end
	-- GoldenPumpkin
	local body = bit({
		Name = "Egg",
		Size = Vector3.new(1.15, 0.85, 1.15) * s,
		CFrame = at(0, 0.43, 0),
		Color = colors.Gold,
		Material = Enum.Material.Neon,
	}, m, true)
	for _, turn in { 0, 60, 120 } do
		bit({
			Name = "Rib",
			Size = Vector3.new(0.42, 0.87, 1.17) * s,
			CFrame = at(0, 0.43, 0) * CFrame.Angles(0, math.rad(turn), 0),
			Color = colors.GoldDark,
			Material = Enum.Material.SmoothPlastic,
		}, m, true)
	end
	bit({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3 * s, 0.16 * s, 0.16 * s),
		CFrame = Kit.upright(at(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(12)),
		Color = colors.Stem,
	}, m)
	bit({
		Name = "Leaf",
		Size = Vector3.new(0.34, 0.05, 0.22) * s,
		CFrame = at(0.14, 0.88, 0.05) * CFrame.Angles(0, math.rad(30), math.rad(-20)),
		Color = colors.Stem,
	}, m, true)
	return body
end

-- Makes `part` the egg that counts: tag, attributes, button, glints.
local function makeEggPart(egg: Egg, part: BasePart)
	part.CanTouch = cfg.TouchToCollect
	part.CanQuery = true
	CollectionService:AddTag(part, Tags.EasterEgg)
	part:SetAttribute("EggId", egg.Id)
	part:SetAttribute("Coins", egg.Coins)
	if cfg.Sparkles > 0 then
		local glints = Instance.new("ParticleEmitter")
		glints.Name = "Glints"
		glints.Rate = cfg.Sparkles
		glints.Color = ColorSequence.new(colors.Sparkle)
		glints.LightEmission = 1
		glints.LightInfluence = 0
		glints.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		glints.Lifetime = NumberRange.new(0.8, 1.4)
		glints.Speed = NumberRange.new(0.4, 1.2)
		glints.SpreadAngle = Vector2.new(180, 180)
		glints.Parent = part
	end
	if cfg.GlowRange > 0 then
		Kit.light(part, colors.Sparkle, cfg.GlowRange, 1, false)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPrompt"
	prompt.ActionText = cfg.Prompt.ActionText
	prompt.ObjectText = egg.Name
	prompt.HoldDuration = cfg.Prompt.HoldDuration
	prompt.MaxActivationDistance = cfg.Prompt.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

function EasterEggs.BuildEgg(egg: Egg, base: CFrame, parent: Instance): (Model, BasePart)
	local look = egg.Look or "GoldenPumpkin"
	if not LOOKS[look] then
		look = "GoldenPumpkin"
	end
	local m: Model? = nil
	local main: BasePart? = nil
	-- Your own look: a model named Egg<Look> in ReplicatedStorage.Custom.Props.
	local custom = CustomAssets.Clone("Props", "Egg" .. look)
	if custom then
		CustomAssets.Fit(custom, cfg.Size)
		for _, d in custom:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end
		CustomAssets.PlaceFeet(custom, base)
		local biggest = custom.PrimaryPart or CustomAssets.BiggestPart(custom)
		if biggest then
			m, main = custom, biggest
			custom:SetAttribute("CustomProp", true)
		else
			custom:Destroy() -- no parts in it: use the built look
		end
	end
	if not (m and main) then
		local built = Instance.new("Model")
		m, main = built, buildLook(look, base, built)
	end
	assert(m and main, "an egg always has a model and an egg part")
	m.Name = egg.Name
	m.PrimaryPart = main
	main.Name = "Egg"
	makeEggPart(egg, main)
	m.WorldPivot = base
	m.Parent = parent
	return m, main
end

-- Placing ----------------------------------------------------------------------------------------------

function EasterEggs.PlaceMissing(hub: Model): { string }
	local placed = {}
	if not Config.Features.EasterEggs then
		return placed
	end
	local folder = folderOf(hub)
	local ignore = ignoreList(hub)
	for _, egg in cfg.List :: { Egg } do
		if hasEgg(hub, egg.Id) then
			continue
		end
		local anchor = EasterEggs.Anchor(hub, egg.Anchor)
		if not anchor then
			if not knownAnchor(egg.Anchor) and not warned[egg.Id] then
				warned[egg.Id] = true
				warn(
					("[EasterEggs] The egg %s has Anchor = %q, which isn't a tag, NPC, lobby zone or Config.Hub landmark, so it was left out."):format(
						egg.Id,
						egg.Anchor
					)
				)
			end
			continue
		end
		local base = eggBase(egg, anchor, ignore)
		-- Face the middle of the lobby.
		local cf = HubLayout.FacingCenter(base)
		EasterEggs.BuildEgg(egg, cf, folder)
		table.insert(placed, egg.Id)
	end
	return placed
end

function EasterEggs.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("EasterEggs", hub)
	if not Config.Features.EasterEggs then
		return area
	end
	if hub.Parent then
		EasterEggs.PlaceMissing(hub)
	else
		-- The rest of the hub (NPCs, decorations) isn't built yet: place the eggs once the
		-- finished hub is put into the game.
		local connection: RBXScriptConnection? = nil
		connection = hub.AncestryChanged:Connect(function()
			if hub.Parent == nil then
				return
			end
			local c = connection
			if c then
				c:Disconnect()
			end
			EasterEggs.PlaceMissing(hub)
		end)
	end
	return area
end

return EasterEggs
