--!strict
--[[
	Catalog items in skins (a skin's Style.Catalog; Config.SkinCatalog; on/off:
	Config.Features.SkinCatalog, off until Kieran has tried it in Studio).

	When a skin with catalog items goes on, this adds them to the player's OWN avatar with
	Humanoid:ApplyDescriptionAsync (server only; Roblox shows it to everyone). Only the
	accessories, classic clothes and classic face change: body parts, colours and sizes stay
	exactly the same, so the Part-built skin keeps every weld. When the skin comes off (or a
	skin without catalog items goes on), the player's own avatar description goes back on.

	How it runs (one worker per character; the newest skin always wins):
	  1. Cosmetics.OnSkinChanged tells us a character's skin changed. Several changes at once
	     (ShopService.Dress putting every slot on) become one apply.
	  2. The worker waits for the avatar to load (up to AppearanceWaitSeconds), keeps applies
	     SecondsBetweenApplies apart, and never works on a Hide & Seek hider, a dead
	     character or an old one.
	  3. Once per character it remembers the player's own avatar (GetAppliedDescription), then
	     applies that plus the skin's items.
	  4. Afterwards the new accessories get the attribute SkinCatalog = true (so a head piece
	     never hides them), the character gets SkinCatalogStatus ("On" or "Failed: <why>")
	     and ShopService.Dress puts the Part skin back over anything the apply reset.
	If Roblox can't load an item, the skin simply shows without it (one warning per id, in
	Studio only), and that skin isn't tried again until it changes. A respawned character
	starts again from the player's own avatar.

	SkinCatalogService.Start()                          nothing at all when the feature is off
	SkinCatalogService.Status(character) -> string?     "Loading", "On", "Failed: <why>" or nil
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local SkinCatalog = require(ReplicatedStorage.Shared.SkinCatalog)
local ShopService = require(script.Parent.ShopService)

local SkinCatalogService = {}

local STATUS = "SkinCatalogStatus"

type Job = {
	Player: Player,
	Wanted: string, -- SkinCatalog.Key of the skin worn now ("" = no catalog items)
	Catalog: SkinCatalog.Catalog?, -- ...and its items
	Applied: string, -- the key last applied ("" = the player's own avatar)
	Running: boolean,
	Waited: boolean, -- already waited for the avatar to load
	Base: HumanoidDescription?, -- the player's own avatar (once per character)
}

local jobs: { [Model]: Job } = {}
local lastApply: { [Player]: number } = {}
local warned: { [number]: boolean } = {}

function SkinCatalogService.Status(character: Model): string?
	local status = character:GetAttribute(STATUS)
	return if type(status) == "string" then status else nil
end

-- A short, one-line reason for the status attribute.
local function shortReason(text: string): string
	local line = string.gsub(text, "%c", " ")
	return if #line > 80 then string.sub(line, 1, 77) .. "..." else line
end

-- One warning per catalog id per server, only in Studio (never during Wear: workers run later).
local function warnOnce(catalog: SkinCatalog.Catalog?, reason: string)
	if not RunService:IsStudio() then
		return
	end
	local fresh = {}
	for _, id in SkinCatalog.Ids(catalog) do
		if not warned[id] then
			warned[id] = true
			table.insert(fresh, ("%d"):format(id))
		end
	end
	if #fresh > 0 then
		warn(
			("[SkinCatalog] catalog item %s didn't load, the skin shows without it: %s"):format(
				table.concat(fresh, ", "),
				shortReason(reason)
			)
		)
	end
end

-- The player's own avatar plus the skin's catalog items. Body parts, colours and scales are
-- copied unchanged, so only accessories, clothes and the face differ.
local function describe(
	base: HumanoidDescription,
	catalog: SkinCatalog.Catalog?
): HumanoidDescription
	local desc = base:Clone()
	if not catalog then
		return desc
	end
	local own = base:GetAccessories(true)
	local list = table.clone(own)
	local have: { [number]: boolean } = {}
	for _, accessory in own do
		have[accessory.AssetId] = true
	end
	for _, accessory in catalog.Accessories do
		local kind = SkinCatalog.AccessoryType(accessory.Type)
		if kind and not have[accessory.Id] then
			have[accessory.Id] = true
			table.insert(list, { AssetId = accessory.Id, AccessoryType = kind, IsLayered = false })
		end
	end
	desc:SetAccessories(list, true)
	if catalog.Shirt then
		desc.Shirt = catalog.Shirt
	end
	if catalog.Pants then
		desc.Pants = catalog.Pants
	end
	if catalog.TShirt then
		desc.GraphicTShirt = catalog.TShirt
	end
	if catalog.ClassicFace then
		desc.Face = catalog.ClassicFace
	end
	return desc
end

-- Yields while Roblox loads the items. Returns (ok, why it failed).
local function apply(humanoid: Humanoid, desc: HumanoidDescription): (boolean, string?)
	local ok, err = pcall(function()
		local h = humanoid :: any
		local hasAsync, method = pcall(function()
			return h.ApplyDescriptionAsync
		end)
		if hasAsync and type(method) == "function" then
			method(h, desc, Enum.AssetTypeVerification.Always)
		else
			h:ApplyDescription(desc, Enum.AssetTypeVerification.Always)
		end
	end)
	return ok, if ok then nil else tostring(err)
end

-- The humanoid to dress, or nil: never a Hide & Seek hider, a dead or an old character.
local function usable(player: Player, character: Model): Humanoid?
	if player:GetAttribute("HideSeekRole") == "Hider" then
		return nil
	end
	if player.Character ~= character or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

-- Waits (at most AppearanceWaitSeconds) until the player's avatar has loaded.
local function waitForAppearance(player: Player, character: Model, job: Job)
	if player:HasAppearanceLoaded() then
		return
	end
	local loaded = false
	local connection = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local deadline = os.clock() + Config.SkinCatalog.AppearanceWaitSeconds
	while
		not loaded
		and jobs[character] == job
		and os.clock() < deadline
		and not player:HasAppearanceLoaded()
	do
		task.wait(0.2)
	end
	connection:Disconnect()
end

local function accessories(character: Model): { [Instance]: boolean }
	local set: { [Instance]: boolean } = {}
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			set[child] = true
		end
	end
	return set
end

local function worker(character: Model, job: Job)
	local player = job.Player
	while jobs[character] == job and job.Wanted ~= job.Applied do
		-- The first OnSkinChanged comes from CharacterAdded, before the avatar has loaded.
		if not job.Waited then
			job.Waited = true
			waitForAppearance(player, character, job)
			continue
		end
		local wait = (lastApply[player] or -math.huge)
			+ Config.SkinCatalog.SecondsBetweenApplies
			- os.clock()
		if wait > 0 then
			task.wait(wait)
			continue
		end
		local humanoid = usable(player, character)
		if not humanoid then
			break -- ShopService.Dress (after Hide & Seek, on respawn) starts it again
		end
		local key, catalog = job.Wanted, job.Catalog
		-- The player's own avatar, before our first apply (no web call).
		local base = job.Base
		if not base then
			local ok, got = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			if ok and typeof(got) == "Instance" and got:IsA("HumanoidDescription") then
				base = got
				job.Base = got
			else
				job.Applied = key
				character:SetAttribute(STATUS, "Failed: no avatar description")
				break
			end
		end
		assert(base, "the avatar description was just read")
		local built, desc = pcall(describe, base, catalog)
		local before = accessories(character)
		lastApply[player] = os.clock()
		character:SetAttribute(STATUS, "Loading")
		local ok, why = false, nil
		if built then
			ok, why = apply(humanoid, desc)
		else
			why = tostring(desc)
		end
		-- (yielded) The character may be gone, or a hider now.
		if jobs[character] ~= job or character.Parent == nil then
			return
		end
		if player:GetAttribute("HideSeekRole") == "Hider" then
			-- Nothing new may show on a hider: back to their own avatar (the disguise hides it).
			apply(humanoid, base:Clone())
			job.Applied = ""
			character:SetAttribute(STATUS, nil)
			break
		end
		if key ~= "" then
			for child in accessories(character) do
				if not before[child] then
					child:SetAttribute("SkinCatalog", true)
				end
			end
		end
		-- After a failure too, so a broken id isn't tried again until the skin changes.
		job.Applied = key
		if ok then
			character:SetAttribute(STATUS, if key ~= "" then "On" else nil)
		else
			local reason = why or "unknown"
			character:SetAttribute(STATUS, "Failed: " .. shortReason(reason))
			warnOnce(catalog, reason)
		end
		-- The Part skin back over anything the apply reset (body colours, clothes). This fires
		-- OnSkinChanged with the same items, so it starts nothing new.
		ShopService.Dress(player)
	end
	job.Running = false
end

local function onSkinChanged(character: Model, item: any?)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local style = if item and type(item.Style) == "table" then item.Style else nil
	local catalog = if style then (SkinCatalog.Normalize(style.Catalog)) else nil
	local key = SkinCatalog.Key(catalog)
	local job = jobs[character]
	if not job then
		if key == "" then
			return -- no catalog items, and none were ever put on this character
		end
		job = {
			Player = player,
			Wanted = "",
			Catalog = nil,
			Applied = "",
			Running = false,
			Waited = false,
			Base = nil,
		}
		jobs[character] = job
	end
	assert(job, "made above")
	job.Wanted = key
	job.Catalog = catalog
	if job.Wanted ~= job.Applied and not job.Running then
		job.Running = true
		task.defer(worker, character, job)
	end
end

local function watch(player: Player)
	player.CharacterRemoving:Connect(function(character)
		jobs[character] = nil
	end)
end

function SkinCatalogService.Start()
	if not Config.Features.SkinCatalog then
		return
	end
	Cosmetics.OnSkinChanged(onSkinChanged)
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastApply[player] = nil
		for character, job in jobs do
			if job.Player == player then
				jobs[character] = nil
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
		-- (Studio Play Solo dresses you before this service starts: dress again so the
		-- listener above sees your skin.)
		if player.Character then
			task.defer(ShopService.Dress, player)
		end
	end
end

return SkinCatalogService
