--!strict
--[[
	Lobby NPCs and interactive props from Config.Npcs.List: the Pumpkin Shop (Vendor), the
	Voting Board (Board), the Leaderboard Gravestone (Gravestone) and the Photo Spot.
	Their parts (how they look) are built by src/server/Hub/NpcLooks.luau.

	Each NPC is a Model named after its Id with the attributes NpcId and DisplayName. An NPC
	with a Zone stands in the middle of that lobby zone, inside the section model of the same
	name (the Pumpkin Shop: Workspace.Hub.Shop.PumpkinVendor); the others go in
	Workspace.Hub.Npcs. Each has a ProximityPrompt "Interact" (attribute NpcId) on an invisible
	PromptAnchor part; src/client/NpcDialogUI.luau handles it.

	The Pumpkin Shop keeper (Kind "Vendor"):
	  PumpkinVendor   tag ShopKeeper
	    Stall         the counter, posts and awning (prop "VendorStall", see Kit.prop). A custom
	                  keeper stands behind its counter, measured from the stall's pivot, so
	                  moving the stall (or the whole PumpkinVendor model) takes the keeper along.
	    Keeper        the pumpkin-headed shopkeeper (or "Look": your custom PumpkinVendor model)
	    KeeperSpot    invisible: where the keeper stands (used if the stall is deleted)
	    TagAnchor     invisible, above the awning: carries the floating name (drawn on top)
	    PromptAnchor  invisible, tag ShopKeeper: the "Shop" prompt

	Npcs.Build(def, hub) -> Model?      builds one NPC into the hub
	Npcs.BuildAll(hub)
	Npcs.Find(hub, id) -> Model?        the NPC model, wherever it was moved inside the hub
	Npcs.Spot(def) -> CFrame            where the NPC stands, facing the hub centre (or def.LookAt)
	Npcs.AttachPrompt(def, m, cf) -> BasePart   a PromptAnchor with the prompt, in front of cf
	Npcs.AddPrompt(def, anchor) -> ProximityPrompt
	Npcs.ShopDefs() -> { NpcDef }       NPCs that open the shop
	Npcs.ApplyCustom(hub)               swaps the shopkeeper for a custom model when there is one
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.HubLayout)
local NpcLooks = require(script.Parent.NpcLooks)

type NpcDef = Config.NpcDef

local Npcs = {}

local hubCfg = Config.Hub
local paint = Kit.painter(hubCfg.Palette)
local holder = Kit.holder
local model = Kit.model
local color = paint.color

local function nameTag(text: string, adornee: BasePart, height: number): BillboardGui
	return Kit.nameTag(text, adornee, height, color("Glow"), hubCfg.NameTagDistance)
end

-- Builders: (cf = the NPC's spot on the plaza, facing the centre; m = its model) -> the part
-- that becomes the model's PrimaryPart.

-- Vendor -------------------------------------------------------------------------------------

-- How far behind the NPC's spot the keeper stands (behind the counter).
local KEEPER_OFFSET = CFrame.new(0, 0, 0.5)

-- The stall and the keeper are drawn in Hub/NpcLooks.luau.
local function buildStall(cf: CFrame, parent: Instance): Model
	return NpcLooks.Stall(cf, parent)
end

local function buildKeeper(spot: CFrame, parent: Instance): Model
	-- A custom PumpkinVendor model (Custom > Characters) replaces just this, standing on
	-- KeeperSpot (Npcs.ApplyCustom).
	return NpcLooks.Keeper(spot, parent)
end

-- The top of everything you can see in `root` (world Y), or `fallback`.
local function visibleTop(root: Instance, fallback: number): number
	local _, high, found = CustomAssets.VisibleBox(root)
	return if found then high.Y else fallback
end

local function buildVendor(cf: CFrame, m: Model, def: NpcDef): BasePart
	local stall = Kit.prop("VendorStall", cf, m, 21, function()
		return buildStall(cf, m)
	end)
	local spot = cf * KEEPER_OFFSET
	buildKeeper(spot, m)
	local keeperSpot = holder("KeeperSpot", spot, Vector3.new(1, 0.2, 1), m)
	-- The name floats above the awning, wherever the keeper is, and is drawn on top so a
	-- taller custom stall or keeper never hides it.
	local tagY = math.max(visibleTop(stall, cf.Y + 10), visibleTop(m, cf.Y + 10)) + 1.5
	local anchor =
		holder("TagAnchor", CFrame.new(spot.X, tagY, spot.Z) * spot.Rotation, Vector3.one, m)
	nameTag(def.DisplayName, anchor, 0).AlwaysOnTop = true
	return keeperSpot
end

-- Voting Board ---------------------------------------------------------------------------------

local function buildBoard(cf: CFrame, m: Model, def: NpcDef): BasePart
	-- The Screen's front face carries the live vote SurfaceGui (rendered by each client).
	local screen, top = NpcLooks.Board(cf, m, def.DisplayName)
	nameTag(def.DisplayName, top, 4)
	return screen
end

-- Leaderboard Gravestone ------------------------------------------------------------------------

local function buildGravestone(cf: CFrame, m: Model, def: NpcDef): BasePart
	-- The Screen's front face carries the top-collectors SurfaceGui (filled by the server).
	local screen, slab = NpcLooks.Gravestone(cf, m)
	nameTag(def.DisplayName, slab, 13)
	return screen
end

-- Photo Spot --------------------------------------------------------------------------------------

local function buildPhotoSpot(cf: CFrame, m: Model, _def: NpcDef): BasePart
	return NpcLooks.PhotoSpot(cf, m)
end

local builders: { [string]: (CFrame, Model, NpcDef) -> BasePart } = {
	Vendor = buildVendor,
	Board = buildBoard,
	Gravestone = buildGravestone,
	PhotoSpot = buildPhotoSpot,
}

-- Public -------------------------------------------------------------------------------------------

function Npcs.Spot(def: NpcDef): CFrame
	local zoneName = def.Zone
	if zoneName then
		if not Config.Lobby.Zones[zoneName] then
			warn(
				("[Npcs] %s has Zone = %q, but Config.Lobby.Zones has no zone with that name; it stands in the middle of the hub."):format(
					def.Id,
					zoneName
				)
			)
		end
		return HubLayout.Zone(zoneName).CFrame
	end
	local offset = def.Offset or Vector3.zero
	local position = HubLayout.At(offset + Vector3.new(0, 1, 0))
	local lookAt = def.LookAt
	if lookAt then
		local target = HubLayout.At(lookAt)
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if flat.Magnitude > 0.1 then
			return CFrame.lookAt(position, position + flat)
		end
	end
	return HubLayout.FacingCenter(position)
end

function Npcs.ShopDefs(): { NpcDef }
	local list = {}
	for _, def in Config.Npcs.List do
		if def.OpensShop then
			table.insert(list, def)
		end
	end
	return list
end

function Npcs.AddPrompt(def: NpcDef, anchor: BasePart): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "Interact"
	p.ActionText = def.Prompt.ActionText
	p.ObjectText = def.Prompt.ObjectText
	p.HoldDuration = Config.Npcs.Prompt.HoldDuration
	p.MaxActivationDistance = Config.Npcs.Prompt.MaxActivationDistance
	p.RequiresLineOfSight = false
	p:SetAttribute("NpcId", def.Id)
	p.Parent = anchor
	return p
end

local function npcsFolder(hub: Model): Instance
	local folder = hub:FindFirstChild("Npcs")
	if folder then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "Npcs"
	created.Parent = hub
	return created
end

function Npcs.Build(def: NpcDef, hub: Model): Model?
	local build = builders[def.Kind]
	if not build then
		warn(("[Npcs] %s has an unknown Kind %q"):format(def.Id, tostring(def.Kind)))
		return nil
	end
	local zoneName = def.Zone
	local parent: Instance = if zoneName
		then (hub:FindFirstChild(zoneName) or model(zoneName, hub))
		else npcsFolder(hub)
	local m = model(def.Id, parent)
	m:SetAttribute("NpcId", def.Id)
	m:SetAttribute("DisplayName", def.DisplayName)
	local cf = Npcs.Spot(def)
	local primary = build(cf, m, def)
	if not m.PrimaryPart then
		m.PrimaryPart = primary
	end
	Npcs.AttachPrompt(def, m, cf)
	return m
end

--[[
	Gives NPC model `m` (standing at `cf`) its prompt on an invisible PromptAnchor part in
	front of it: a prompt on a part that also carries a SurfaceGui (board, gravestone) hides
	itself and never triggers. Shop NPCs and their anchor get the ShopKeeper tag.
]]
function Npcs.AttachPrompt(def: NpcDef, m: Model, cf: CFrame): BasePart
	local p = Config.Npcs.Prompt
	local anchor = holder("PromptAnchor", cf * CFrame.new(0, p.Height, -p.Forward), Vector3.one, m)
	Npcs.AddPrompt(def, anchor)
	if def.Kind == "PhotoSpot" then
		CollectionService:AddTag(anchor, Tags.PhotoSpot) -- dances only start near it
	end
	if def.OpensShop then
		CollectionService:AddTag(m, Tags.ShopKeeper)
		CollectionService:AddTag(anchor, Tags.ShopKeeper)
	end
	return anchor
end

function Npcs.BuildAll(hub: Model)
	npcsFolder(hub)
	for _, def in Config.Npcs.List do
		Npcs.Build(def, hub)
	end
end

function Npcs.Find(hub: Model, id: string): Model?
	for _, d in hub:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("NpcId") == id then
			return d
		end
	end
	-- Hubs saved before NPC models had the NpcId attribute.
	local folder = hub:FindFirstChild("Npcs")
	local m = folder and folder:FindFirstChild(id)
	return if m and m:IsA("Model") then m else nil
end

-- Custom shopkeeper -------------------------------------------------------------------------------

-- NPC kinds whose person can be swapped for a custom model in Custom > Characters (named
-- after the NPC's Id). The board, gravestone and photo spot carry screens and prompts other
-- code relies on, so they keep their built look.
local CHARACTER_KINDS = { Vendor = true }
-- Keeper parts of a stall built before the Keeper model existed (hub saved in Studio).
local OLD_KEEPER_PARTS = { Body = true, Head = true, Hat = true, Eye = true, Mouth = true }

local function yawOnly(cf: CFrame): CFrame
	return CFrame.new(cf.Position) * CustomAssets.Yaw(cf)
end

-- The stall model (built "Stall" or a custom "VendorStall" prop) inside a vendor NPC.
local function findStall(m: Model): Model?
	for _, child in m:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PropName") == "VendorStall" then
			return child
		end
	end
	return nil
end

-- Where the keeper stands: behind the stall's counter (the stall's pivot is the NPC's spot,
-- so moving just the stall in Studio takes the keeper with it), else the KeeperSpot part, or
-- for older saved hubs a spot worked out from the counter, or the Config position.
local function keeperSpot(m: Model, def: NpcDef): CFrame
	local stall = findStall(m)
	if stall then
		return yawOnly(stall:GetPivot() * KEEPER_OFFSET)
	end
	local spot = m:FindFirstChild("KeeperSpot", true)
	if spot and spot:IsA("BasePart") then
		return yawOnly(spot.CFrame)
	end
	local counter = m:FindFirstChild("Counter", true)
	if counter and counter:IsA("BasePart") then
		return yawOnly(counter.CFrame * CFrame.new(0, -counter.Size.Y / 2, 3))
	end
	return Npcs.Spot(def) * KEEPER_OFFSET
end

-- The top of the counter the keeper stands behind (world Y).
local function counterTop(m: Model, spot: CFrame): number
	local counter = m:FindFirstChild("Counter", true)
	if counter and counter:IsA("BasePart") then
		return counter.CFrame.Y + counter.Size.Y / 2
	end
	return spot.Y + 3
end

-- Why a custom keeper can't be used (nil = it's fine).
local function problem(custom: Model, target: number?, minTop: number): string?
	local low, high, found = CustomAssets.VisibleBox(custom)
	local visible = false
	for _, d in custom:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			visible = true
			break
		end
	end
	if not found or not visible then
		return "it has no visible parts"
	end
	local height = high.Y - low.Y
	if target and (height < target * 0.5 or height > target * 1.5) then
		return ("it is %.1f studs tall after scaling, but should be about %.1f (Config.Custom.Heights): check KeepSize and that it stands upright"):format(
			height,
			target
		)
	end
	if high.Y < minTop then
		return "its head would be hidden behind the counter (it is too short or stands too low)"
	end
	return nil
end

--[[
	Swaps the shopkeeper's Part-built look for a custom model named after its Id (e.g.
	PumpkinVendor) in ReplicatedStorage.Custom.Characters. Runs on every start, also on a hub
	saved in Studio. The custom model only replaces the keeper when it passes these checks,
	otherwise the built keeper stays and a warning says why:
	  - it has parts you can see,
	  - after scaling it is 50-150% of Config.Custom.Heights[Id] tall,
	  - its top is at least 2 studs above the counter.
	It stands behind the stall's counter, measured from the stall's pivot (so a stall moved in
	Studio keeps its keeper), turned left/right only.
]]
function Npcs.ApplyCustom(hub: Model)
	for _, def in Config.Npcs.List do
		if not CHARACTER_KINDS[def.Kind] then
			continue
		end
		local m = Npcs.Find(hub, def.Id)
		if not m then
			continue
		end
		local custom = CustomAssets.Clone("Characters", def.Id)
		if not custom then
			continue
		end
		local target = Config.Custom.Heights[def.Id]
		CustomAssets.Fit(custom, target)
		for _, d in custom:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local spot = keeperSpot(m, def)
		CustomAssets.PlaceFeet(custom, spot)
		local why = problem(custom, target, counterTop(m, spot) + 2)
		if why then
			custom:Destroy()
			warn(
				("[Npcs] Your custom %s model (ReplicatedStorage.Custom.Characters) was not used: %s. The built shopkeeper is shown instead. See docs/CUSTOMIZE.md > Builder mode."):format(
					def.Id,
					why
				)
			)
			continue
		end
		for _, child in m:GetChildren() do
			if
				child.Name == "Keeper"
				or child.Name == "Look"
				or (child:IsA("BasePart") and OLD_KEEPER_PARTS[child.Name] == true)
			then
				child:Destroy()
			end
		end
		custom.Name = "Look"
		custom.Parent = m
		-- Older saved hubs have no fixed name anchor: put one above the awning and the model.
		if not m:FindFirstChild("TagAnchor") then
			local top = math.max(visibleTop(m, spot.Y + 10), spot.Y + 10) + 1.5
			local anchor =
				holder("TagAnchor", CFrame.new(spot.X, top, spot.Z) * spot.Rotation, Vector3.one, m)
			nameTag(def.DisplayName, anchor, 0).AlwaysOnTop = true
			for _, d in m:GetDescendants() do
				if d:IsA("BillboardGui") and d.Name == "NameTag" and d.Parent ~= anchor then
					d:Destroy()
				end
			end
		end
	end
end

return Npcs
