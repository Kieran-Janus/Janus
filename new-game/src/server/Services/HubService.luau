--!strict
--[[
	The lobby, "Spooky Town Square": a Model in Workspace named "Hub", built by
	src/server/Hub/HubBuilder.luau. What happens on every server start:

	  1. Lighting comes from Config.Hub.Lighting.
	  2. The hub saved in the place file is used as it is, unless it is older than the code:
	     its attribute BuildVersion is missing or lower than Config.Hub.BuildVersion. Then it is
	     rebuilt from code, UNLESS it has the attribute Locked = true (set that once you edit
	     the hub by hand): a Locked hub is kept and the Output shows a warning.
	     No hub at all: one is built. If building fails, a plain plaza with the spawn and the
	     Ready pad is used instead, so the server always starts.
	  3. EnsureRequired: the pieces the game needs are put back if they are missing, even on a
	     Locked hub (with a warning): the spawn (tag HubSpawn), the Ready pad (tag ReadyPad,
	     while Config.Features.ReadyPad is on) and the Pumpkin Shop keeper (tag ShopKeeper).
	  4. Old NPCs that v2 removed (Witch Wanda, Boo Guide) are deleted, a custom shopkeeper
	     model is applied, the music is set and palette colours changed in Config are repainted.
	  5. There is only ever one hub: extra "Hub" models and loose copies of hub pieces in
	     Workspace are removed, with a warning saying what to clean up in the saved place.

	Edit the hub by hand: docs/CUSTOMIZE.md > "Editing the lobby and maps by hand", or build it
	into the place from the command bar: require(game.ServerScriptService.Server.Tools.Bake).Hub()

	HubService.Get() -> Model?
	HubService.Screen(npcId) -> BasePart?   an NPC's "Screen" part (Voting Board, Leaderboard)
	HubService.IsOutdated(hub) -> boolean
	HubService.EnsureRequired(hub) -> { string }   what was put back
	HubService.RemoveRetired(hub) -> number
	HubService.Rebuild() -> string           F8 > Rebuild hub
	HubService.Repaint() -> string           F8 > Repaint hub
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local Hub = script.Parent.Parent.Hub
local HubBuilder = require(Hub.HubBuilder)
local HubPalette = require(Hub.HubPalette)
local Npcs = require(Hub.Npcs)

local HubService = {}

-- NPCs that v2 removed. Their models are deleted from a saved hub, unless they are back in
-- Config.Npcs.List.
local RETIRED_NPCS = { "WitchWanda", "BooGuide" }

function HubService.Get(): Model?
	local hub = workspace:FindFirstChild("Hub")
	return if hub and hub:IsA("Model") then hub else nil
end

-- The part on an NPC model that carries a SurfaceGui (Voting Board, Gravestone).
function HubService.Screen(npcId: string): BasePart?
	local hub = HubService.Get()
	local npc = hub and Npcs.Find(hub, npcId)
	local screen = npc and npc:FindFirstChild("Screen")
	return if screen and screen:IsA("BasePart") then screen else nil
end

function HubService.IsOutdated(hub: Model): boolean
	local version = hub:GetAttribute("BuildVersion")
	return typeof(version) ~= "number" or version < Config.Hub.BuildVersion
end

-- Keeps the first "Hub" model in Workspace and destroys any others. Returns the one kept.
local function keepOneHub(): Model?
	local hubs = HubBuilder.FindHubs()
	for i = 2, #hubs do
		hubs[i]:Destroy()
	end
	if #hubs > 1 then
		warn(
			("[HubService] Removed %d extra Hub model(s) from Workspace. Delete them in Studio and save the place."):format(
				#hubs - 1
			)
		)
	end
	return hubs[1]
end

-- Builds the full hub; if that fails, the plain fallback hub (and if even that fails, nil).
local function safeBuild(): Model?
	local ok, result = pcall(HubBuilder.Build)
	if ok then
		return result
	end
	warn(
		"[HubService] Building the hub failed, so a plain plaza is used for now. Please send this error to Claude: "
			.. tostring(result)
	)
	local fallbackOk, fallback = pcall(HubBuilder.BuildFallback)
	if fallbackOk then
		return fallback
	end
	warn("[HubService] Even the plain plaza failed to build: " .. tostring(fallback))
	return nil
end

function HubService.RemoveRetired(hub: Model): number
	local inConfig: { [string]: boolean } = {}
	for _, def in Config.Npcs.List do
		inConfig[def.Id] = true
	end
	local removed = 0
	for _, id in RETIRED_NPCS do
		if inConfig[id] then
			continue
		end
		local m = Npcs.Find(hub, id)
		while m do
			m:Destroy()
			removed += 1
			m = Npcs.Find(hub, id)
		end
	end
	return removed
end

-- Tagged instances inside `hub`.
local function taggedIn(hub: Model, tag: string): { Instance }
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(hub) then
			table.insert(list, instance)
		end
	end
	return list
end

local function shopIds(): { [string]: boolean }
	local ids = {}
	for _, def in Npcs.ShopDefs() do
		ids[def.Id] = true
	end
	return ids
end

-- The working shop prompt under (or on) `root`: a ProximityPrompt whose NpcId opens the shop.
local function shopPrompt(root: Instance, ids: { [string]: boolean }): ProximityPrompt?
	local function check(d: Instance): ProximityPrompt?
		if d:IsA("ProximityPrompt") then
			local id = d:GetAttribute("NpcId")
			if typeof(id) == "string" and ids[id] then
				return d
			end
		end
		return nil
	end
	local found = check(root)
	if found then
		return found
	end
	for _, d in root:GetDescendants() do
		found = check(d)
		if found then
			return found
		end
	end
	return nil
end

local function ensureSpawn(hub: Model, notes: { string })
	for _, instance in CollectionService:GetTagged(Tags.HubSpawn) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			return
		end
	end
	-- A hub saved before tags existed: its spawn is the SpawnLocation called "Spawn".
	local old = hub:FindFirstChild("Spawn")
	if old and old:IsA("SpawnLocation") then
		CollectionService:AddTag(old, Tags.HubSpawn)
		return
	end
	HubBuilder.BuildSpawn(hub)
	table.insert(notes, "the spawn (tag HubSpawn)")
end

local function ensureShopKeeper(hub: Model, notes: { string })
	local defs = Npcs.ShopDefs()
	if #defs == 0 then
		return
	end
	local ids = shopIds()
	-- A part tagged ShopKeeper without a prompt gets one, so tagging any part works.
	local working = false
	for _, instance in taggedIn(hub, Tags.ShopKeeper) do
		if shopPrompt(instance, ids) then
			working = true
		elseif instance:IsA("BasePart") then
			Npcs.AddPrompt(defs[1], instance)
			working = true
		end
	end
	if working then
		return
	end
	-- A hub saved before tags existed: tag its shop prompt and keeper.
	local prompt = shopPrompt(hub, ids)
	if prompt then
		local anchor = prompt.Parent
		if anchor then
			CollectionService:AddTag(anchor, Tags.ShopKeeper)
			local npc = anchor:FindFirstAncestorWhichIsA("Model")
			if npc and npc ~= hub then
				CollectionService:AddTag(npc, Tags.ShopKeeper)
			end
		end
		return
	end
	local def = defs[1]
	local stale = Npcs.Find(hub, def.Id)
	if stale then
		-- The shop is there but its prompt was deleted: give it a new one where it stands.
		local spot = stale:FindFirstChild("KeeperSpot", true)
		local cf = if spot and spot:IsA("BasePart")
			then spot.CFrame * CFrame.new(0, 0, -0.5)
			else stale:GetPivot()
		Npcs.AttachPrompt(def, stale, cf)
		table.insert(notes, ("the shop prompt on %s (tag ShopKeeper)"):format(stale.Name))
		return
	end
	Npcs.Build(def, hub)
	table.insert(notes, ("the shopkeeper %s (tag ShopKeeper)"):format(def.Id))
end

local function ensureReadyPad(hub: Model, notes: { string })
	if not Config.Features.ReadyPad then
		return
	end
	for _, instance in CollectionService:GetTagged(Tags.ReadyPad) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			return
		end
	end
	HubBuilder.RepairSection(hub, "ReadyArea")
	table.insert(notes, "the Ready pad (tag ReadyPad)")
end

--[[
	Puts back the pieces the game can't work without, also on a Locked hub. Returns what was
	added (empty when nothing was missing) and warns about each one.
]]
function HubService.EnsureRequired(hub: Model): { string }
	local notes: { string } = {}
	for _, step in { ensureSpawn, ensureShopKeeper, ensureReadyPad } do
		local ok, err = pcall(step :: any, hub, notes)
		if not ok then
			warn("[HubService] Couldn't check the hub: " .. tostring(err))
		end
	end
	if #notes > 0 then
		warn(
			("[HubService] Your saved hub was missing %s, so the game added it back for this server. To keep it, open the place in Studio and run require(game.ServerScriptService.Server.Tools.Bake).Repair() in the command bar, then save."):format(
				table.concat(notes, ", ")
			)
		)
	end
	-- Every Config NPC should be somewhere in the hub (the shop is covered by ShopKeeper above:
	-- any part tagged ShopKeeper can stand in for it).
	for _, def in Config.Npcs.List do
		if not def.OpensShop and not Npcs.Find(hub, def.Id) then
			warn(
				("[HubService] Config.Npcs.List has %s, but the saved hub doesn't. Remove it from the list, or F8 > Rebuild hub."):format(
					def.Id
				)
			)
		end
	end
	return notes
end

-- Everything that runs on a hub after it is chosen or built (also on a Locked hub). Each step
-- runs on its own: one failing never stops the others or the server.
local function prepare(hub: Model)
	local steps: { () -> () } = {
		function()
			local retired = HubService.RemoveRetired(hub)
			if retired > 0 then
				print(
					("[HubService] Removed %d retired NPC(s) (Witch Wanda, Boo Guide) from the saved hub."):format(
						retired
					)
				)
			end
		end,
		function()
			HubService.EnsureRequired(hub)
		end,
		function()
			Kit.applyCustomProps(hub)
		end,
		function()
			HubBuilder.ApplyCustomNpcs(hub)
		end,
		function()
			HubBuilder.ApplyMusic(hub)
		end,
		function()
			HubPalette.Sync(hub)
		end,
		function()
			local loose = HubBuilder.RemoveLoosePieces(hub)
			if loose > 0 then
				warn(
					("[HubService] Removed %d loose hub piece(s) from Workspace (an ungrouped or pasted hub copy). Delete them in Studio and save the place."):format(
						loose
					)
				)
			end
		end,
		HubBuilder.DisableDefaultSpawn,
	}
	for _, step in steps do
		local ok, err = pcall(step :: any)
		if not ok then
			warn("[HubService] " .. tostring(err))
		end
	end
end

function HubService.Start()
	HubBuilder.ApplyLighting()
	local hub = keepOneHub()
	if hub and HubService.IsOutdated(hub) then
		if hub:GetAttribute("Locked") == true then
			warn(
				("[HubService] Your saved hub (Workspace.Hub, BuildVersion %s) is older than the code (BuildVersion %d). It is Locked, so it was kept as it is. To update it: F8 > Rebuild hub (this playtest only) or, in edit mode, require(game.ServerScriptService.Server.Tools.Bake).Hub(true) in the command bar. Your hand edits will be replaced."):format(
					tostring(hub:GetAttribute("BuildVersion") or "none"),
					Config.Hub.BuildVersion
				)
			)
		else
			hub = nil -- rebuilt below
		end
	end
	if not hub then
		hub = safeBuild()
	end
	if hub then
		prepare(hub)
	end
end

-- F8 > Rebuild hub: a fresh hub from Config (this playtest only).
function HubService.Rebuild(): string
	local hub = safeBuild()
	if not hub then
		return "The hub failed to build: see the Output window."
	end
	prepare(hub)
	if hub:GetAttribute("Fallback") then
		return "The full hub failed to build (see Output), so a plain plaza is shown."
	end
	return "Hub rebuilt from Config.Hub and custom models (this playtest only)."
end

-- F8 > Repaint hub: every part with a PaletteRole takes its Config.Hub.Palette colour again.
function HubService.Repaint(): string
	local hub = HubService.Get()
	if not hub then
		return "There is no Workspace.Hub to repaint."
	end
	local changed = HubPalette.Repaint(hub)
	HubPalette.Stamp(hub)
	return ("Repainted %d part(s) from Config.Hub.Palette (this playtest only)."):format(changed)
end

return HubService
