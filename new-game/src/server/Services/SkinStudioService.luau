--!strict
--[[
	Skin Studio's server side (settings: Config.SkinStudio, on/off: Config.Features.SkinStudio).
	Only admins (the "Admin" attribute AdminService sets) may use it, and only in Studio unless
	Config.SkinStudio.AllowInLiveServers is true. Players never get anything from it: a draft
	is worn through ShopService.SetSkinOverride and their save never changes.

	SkinStudioService.Start()            never waits (a slow DataStore loads in its own thread)
	SkinStudioService.Allowed(player) -> boolean

	One remote: SkinStudio:InvokeServer(action, payload) -> { Ok, Message, Data? }
	  "Hello"        -> { DataStore = "Loading"|"On"|"Off"|"Failed", Drafts = { summary }, Wearing = name? }
	  "Get"          DraftId -> the saved draft
	  "Wear"         JSON text of { DraftId?, Item } -> { WornId }   your character wears it
	  "StopWearing"  back to your own equipped skin
	  "Save"         JSON text of { DraftId?, Source?, Item, Note?, UnlockEconomy? } -> the saved draft
	  "Delete"       DraftId
	  "LookupAsset"  a catalog id -> { Name, Type, AssetType, Creator, CreatorType, CreatorId,
	                 RobloxMade, Allowed, Problem? }
	  "PrintDrafts"  prints every saved draft to Output for Claude Code -> { Pages }
	Every call is checked in this order: the action is text, Allowed, the action's cooldown
	(stamped straight away), the payload's type and size, then JSON, SkinSchema.Decode and
	SkinSchema.Validate. Nothing here ever errors back to the client.

	Drafts are kept (1) in memory, (2) in ServerStorage.SkinStudioDrafts (one StringValue per
	draft: what /save-skins reads through src/server/Tools/SkinExport.luau) and (3) only when
	Config.SkinStudio.UseDataStore is on, in a DataStore of their own, written at most every
	FlushSeconds. F8 > "Skin Studio" opens the panel (the player attribute SkinStudioOpenAt).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SkinSchema = require(ReplicatedStorage.Shared.SkinSchema)
local AdminService = require(script.Parent.AdminService)
local ShopService = require(script.Parent.ShopService)
local SkinExport = require(script.Parent.Parent.Tools.SkinExport)

local SkinCatalog: any = nil
do
	local module = ReplicatedStorage.Shared:FindFirstChild("SkinCatalog")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		SkinCatalog = if ok then result else nil
	end
end

local SkinStudioService = {}

export type Reply = { Ok: boolean, Message: string, Data: any? }

local MIRROR = "SkinStudioDrafts"
local DRAFT_ID = "^[%w%-]+$" -- what a DraftId looks like (a GUID)
local DAY_MS = 86400000

local drafts: { [string]: any } = {} -- DraftId -> record (or a tombstone while the DataStore is on)
local texts: { [string]: string } = {} -- DraftId -> the exact JSON text kept in the mirror
local savedThisSession: { [string]: boolean } = {}
local stamps: { [Player]: { [string]: number } } = {}
local wearing: { [Player]: string } = {} -- the name of the draft each admin wears
local lookups: { [number]: any } = {} -- catalog id -> AssetInfo (successful lookups only)
local storeStatus = "Off" -- "Loading" | "On" | "Off" | "Failed"
local storeProblem: string? = nil
local dirty = false
local started = false

local function text(): any
	return Config.SkinStudio.Text
end

local function reply(ok: boolean, message: string, data: any?): Reply
	return { Ok = ok, Message = message, Data = data }
end

function SkinStudioService.Allowed(player: Player): boolean
	if not Config.Features.SkinStudio then
		return false
	end
	if player:GetAttribute("Admin") ~= true then
		return false
	end
	return RunService:IsStudio() or Config.SkinStudio.AllowInLiveServers == true
end

local function useDataStore(): boolean
	return Config.SkinStudio.UseDataStore == true
		and (RunService:IsStudio() or Config.SkinStudio.AllowInLiveServers == true)
end

local function nowMs(): number
	return DateTime.now().UnixTimestampMillis
end

local function isLive(record: any): boolean
	return type(record) == "table" and not record.Deleted and type(record.Item) == "table"
end

-- Is this draft exactly the skin in the game files (so /save-skins already wrote it)?
local function inGameFiles(record: any): boolean
	local catalogue = Items.Get(record.Item.Id)
	if not catalogue or catalogue.Slot ~= "Skin" then
		return false
	end
	return SkinSchema.Same(record.Item, SkinSchema.Encode(catalogue))
end

local function summary(record: any): any
	local item = record.Item
	return {
		DraftId = record.DraftId,
		SkinId = item.Id,
		Name = item.Name,
		Theme = item.Theme,
		Rarity = item.Rarity,
		Source = record.Source,
		Updated = record.Updated,
		Note = record.Note,
		InGameFiles = inGameFiles(record),
	}
end

local function liveCount(): number
	local count = 0
	for _, record in drafts do
		if isLive(record) then
			count += 1
		end
	end
	return count
end

-- The mirror ------------------------------------------------------------------------------------

local function mirrorFolder(make: boolean): Folder?
	local folder = ServerStorage:FindFirstChild(MIRROR)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if not make then
		return nil
	end
	local made = Instance.new("Folder")
	made.Name = MIRROR
	made.Parent = ServerStorage
	return made
end

-- Puts a draft in memory and the mirror (or takes it out of the mirror when it's deleted).
local function remember(record: any)
	local id = record.DraftId
	drafts[id] = record
	local folder = mirrorFolder(isLive(record))
	local value = folder and folder:FindFirstChild(id)
	if not isLive(record) then
		texts[id] = nil
		if value then
			value:Destroy()
		end
		return
	end
	local json = HttpService:JSONEncode(record)
	texts[id] = json
	local stringValue: StringValue
	if value and value:IsA("StringValue") then
		stringValue = value
	else
		stringValue = Instance.new("StringValue")
		stringValue.Name = id
		stringValue.Parent = folder
	end
	stringValue.Value = json
	stringValue:SetAttribute("SkinId", record.Item.Id)
	stringValue:SetAttribute("Theme", record.Item.Theme)
	stringValue:SetAttribute("Updated", record.Updated)
end

-- The DataStore (only with UseDataStore) --------------------------------------------------------

-- Adds `record` to `into` unless `into` already has a newer one with that DraftId.
local function keepNewest(into: { [string]: any }, record: any)
	if
		type(record) ~= "table"
		or type(record.DraftId) ~= "string"
		or type(record.Updated) ~= "number"
	then
		return
	end
	local old = into[record.DraftId]
	if old == nil or (type(old.Updated) == "number" and record.Updated > old.Updated) then
		into[record.DraftId] = record
	end
end

-- Takes in drafts from the DataStore that are newer than the ones in memory.
local function adopt(stored: any)
	if type(stored) ~= "table" or type(stored.Drafts) ~= "table" then
		return
	end
	for _, record in stored.Drafts do
		if
			type(record) == "table"
			and type(record.DraftId) == "string"
			and type(record.Updated) == "number"
		then
			local mine = drafts[record.DraftId]
			if mine == nil or record.Updated > (mine.Updated or 0) then
				local ok = record.Deleted or select(1, SkinSchema.Decode(record.Item)) ~= nil
				if ok then
					remember(record)
				end
			end
		end
	end
end

local function store(): GlobalDataStore
	return DataStoreService:GetDataStore(Config.SkinStudio.DraftStore)
end

-- Writes the drafts (merged with what is stored: per draft the newest wins, old tombstones go).
local function flush()
	if not dirty or storeStatus ~= "On" then
		return
	end
	dirty = false
	local cfg = Config.SkinStudio
	local tooBig = false
	local ok, result = pcall(function()
		return store():UpdateAsync(cfg.DraftKey, function(old: any)
			local merged: { [string]: any } = {}
			if type(old) == "table" and type(old.Drafts) == "table" then
				for _, record in old.Drafts do
					keepNewest(merged, record)
				end
			end
			for _, record in drafts do
				keepNewest(merged, record)
			end
			local cutoff = nowMs() - cfg.TombstoneDays * DAY_MS
			for id, record in merged do
				if record.Deleted and record.Updated < cutoff then
					merged[id] = nil
				end
			end
			local value = { Version = 2, Drafts = merged }
			if #HttpService:JSONEncode(value) >= cfg.MaxStoreChars then
				tooBig = true
				return nil -- not written
			end
			return value
		end)
	end)
	if not ok then
		dirty = true -- try again next time
		warn("[SkinStudioService] couldn't keep drafts in the DataStore: " .. tostring(result))
		return
	end
	storeProblem = if tooBig then text().TooManyDrafts else nil
	if not tooBig then
		adopt(result)
		-- forget old tombstones in memory too
		local cutoff = nowMs() - cfg.TombstoneDays * DAY_MS
		for id, record in drafts do
			if record.Deleted and record.Updated < cutoff then
				drafts[id] = nil
			end
		end
	end
end

local function markDirty()
	if storeStatus == "On" or storeStatus == "Loading" then
		dirty = true
	end
end

local function load()
	local cfg = Config.SkinStudio
	local ok, ds = pcall(store)
	if not ok then
		storeStatus = "Off" -- no published place, or Studio API access is off
		storeProblem = tostring(ds)
		return
	end
	for attempt = 1, math.max(1, cfg.LoadTries) do
		local loaded, stored = pcall(function()
			return (ds :: GlobalDataStore):GetAsync(cfg.DraftKey)
		end)
		if loaded then
			adopt(stored)
			storeStatus = "On"
			storeProblem = nil
			return
		end
		storeProblem = tostring(stored)
		if attempt < cfg.LoadTries then
			task.wait(cfg.LoadRetrySeconds)
		end
	end
	storeStatus = "Failed"
end

-- Payloads ---------------------------------------------------------------------------------------

-- A draft's fields only the server sets: a client sending them is ignored.
local SERVER_ONLY: { [any]: boolean } = { Lookups = true, Updated = true, Author = true }

local PAYLOAD_KEYS = {
	Wear = { DraftId = "string", Item = "table" },
	Save = {
		DraftId = "string",
		Source = "string",
		Item = "table",
		Note = "string",
		UnlockEconomy = "boolean",
	},
}

-- JSON text -> (the decoded payload, the item) or (nil, nil, why not).
local function parse(action: string, payload: unknown): (any?, any?, string?)
	if type(payload) ~= "string" then
		return nil, nil, "Send the skin as text."
	end
	if #payload > Config.SkinStudio.MaxDraftBytes then
		return nil, nil, "That skin is too big."
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(payload)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, nil, "That skin text is broken."
	end
	local shape = PAYLOAD_KEYS[action]
	for key, value in decoded do
		if SERVER_ONLY[key] then
			decoded[key] = nil -- only the server fills these in
			continue
		end
		local want = if type(key) == "string" then shape[key] else nil
		if not want or type(value) ~= want then
			return nil, nil, "That skin text has something unexpected in it."
		end
	end
	if
		type(decoded.DraftId) == "string"
		and not (#decoded.DraftId <= 40 and decoded.DraftId:match(DRAFT_ID))
	then
		return nil, nil, "That draft id is broken."
	end
	local item, errors = SkinSchema.Decode(decoded.Item)
	if not item then
		return nil, nil, errors[1] or "That skin is broken."
	end
	local valid, problems = SkinSchema.Validate(item)
	if not valid then
		return nil, nil, problems[1] or "That skin is broken."
	end
	return decoded, item, nil
end

-- Every catalog id in a skin's Catalog.
local function catalogIds(catalog: any): { number }
	if SkinCatalog and type(SkinCatalog.Ids) == "function" then
		local ok, ids = pcall(SkinCatalog.Ids, catalog)
		if ok and type(ids) == "table" then
			return ids
		end
	end
	local ids = {}
	if type(catalog) ~= "table" then
		return ids
	end
	if type(catalog.Accessories) == "table" then
		for _, entry in catalog.Accessories do
			if type(entry) == "table" and type(entry.Id) == "number" then
				table.insert(ids, entry.Id)
			end
		end
	end
	for _, key in { "Shirt", "Pants", "TShirt", "ClassicFace" } do
		if type(catalog[key]) == "number" then
			table.insert(ids, catalog[key])
		end
	end
	return ids
end

local function character(player: Player): Model?
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not (model and humanoid and humanoid.Health > 0) then
		return nil
	end
	return model
end

-- Actions ----------------------------------------------------------------------------------------

local handlers: { [string]: (Player, any) -> Reply } = {}

handlers.Hello = function(player: Player, _payload: any): Reply
	local list = {}
	for _, record in drafts do
		if isLive(record) then
			table.insert(list, summary(record))
		end
	end
	table.sort(list, function(a, b)
		return a.Updated > b.Updated
	end)
	return reply(true, "", {
		DataStore = storeStatus,
		StoreProblem = storeProblem,
		Drafts = list,
		Wearing = wearing[player],
	})
end

handlers.Get = function(_player: Player, draftId: any): Reply
	local record = if type(draftId) == "string" then drafts[draftId] else nil
	if not isLive(record) then
		return reply(false, "That draft is gone.")
	end
	return reply(true, "", SkinSchema.Copy(record))
end

handlers.Wear = function(player: Player, payload: any): Reply
	local decoded, item, why = parse("Wear", payload)
	if not decoded then
		return reply(false, why or "That skin is broken.")
	end
	if player:GetAttribute("HideSeekRole") == "Hider" then
		return reply(false, "Not while you're hiding as a pumpkin.")
	end
	if not character(player) then
		return reply(false, "Wait until your character has spawned.")
	end
	local wearItem =
		SkinSchema.WearItem({ DraftId = decoded.DraftId, Author = player.UserId, Item = item })
	ShopService.SetSkinOverride(player, wearItem)
	ShopService.Dress(player)
	wearing[player] = item.Name
	return reply(true, text().WearingDraft:format(item.Name), { WornId = wearItem.Id })
end

handlers.StopWearing = function(player: Player, _payload: any): Reply
	ShopService.SetSkinOverride(player, nil)
	wearing[player] = nil
	ShopService.Dress(player)
	return reply(true, text().WearingNothing)
end

handlers.Save = function(player: Player, payload: any): Reply
	local cfg = Config.SkinStudio
	local decoded, item, why = parse("Save", payload)
	if not decoded then
		return reply(false, why or "That skin is broken.")
	end
	local note = decoded.Note
	if note ~= nil and (utf8.len(note) == nil or #note > 120 or note:find("%c")) then
		return reply(false, "The note must be one line of up to 120 letters.")
	end
	local old = if decoded.DraftId then drafts[decoded.DraftId] else nil
	if decoded.DraftId and not isLive(old) then
		return reply(false, "That draft is gone: Save it as a new one.")
	end
	if not old and liveCount() >= cfg.MaxDrafts then
		return reply(
			false,
			("You have %d drafts already: delete some first."):format(cfg.MaxDrafts)
		)
	end
	local source = decoded.Source
	if old and old.Source ~= source then
		return reply(false, "A draft can't change which skin it edits.")
	end
	local unlock = decoded.UnlockEconomy == true
	if source ~= nil then
		local original = Items.Get(source)
		if not original or original.Slot ~= "Skin" then
			return reply(false, "There is no skin called " .. tostring(source) .. ".")
		end
		if item.Id ~= original.Id or item.Theme ~= original.Theme then
			return reply(false, "A skin already in the game keeps its Id and theme.")
		end
		if not unlock then
			for _, key in SkinSchema.EconomyKeys do
				if (item :: any)[key] ~= original[key] then
					return reply(false, text().EconomyLocked)
				end
			end
		end
	end
	-- the Id isn't used by another draft, or by a catalogue skin other than Source
	local taken: { [string]: boolean } = {}
	for _, other in Items.ForSlot("Skin") do
		if other.Id ~= source then
			taken[other.Id] = true
		end
	end
	for id, record in drafts do
		if isLive(record) and id ~= decoded.DraftId then
			taken[record.Item.Id] = true
		end
	end
	local idOk, idWhy = SkinSchema.IdOk(item.Id, item.Theme, taken)
	if not idOk then
		return reply(false, idWhy or "That Id is taken.")
	end
	-- what the server looked up for this skin's catalog ids (never what the client says)
	local recorded: { [string]: any } = {}
	for _, id in catalogIds(item.Style.Catalog) do
		local info = lookups[id]
		if info then
			recorded[("%d"):format(id)] = info
		end
	end
	local record = {
		DraftId = if old then old.DraftId else HttpService:GenerateGUID(false),
		Source = source,
		Item = SkinSchema.Encode(item),
		UnlockEconomy = if unlock then true else nil,
		Lookups = if next(recorded) then recorded else nil,
		Updated = nowMs(),
		Author = player.UserId,
		Note = note,
	}
	local json = HttpService:JSONEncode(record)
	-- one draft always fits one export page (SkinExport)
	if #HttpService:JSONEncode(json) > cfg.ExportPageChars - 500 then
		return reply(false, "That skin is too big to export.")
	end
	local total = #json
	for id, other in texts do
		if id ~= record.DraftId then
			total += #other
		end
	end
	if total > cfg.MaxStoreChars then
		return reply(false, text().TooManyDrafts)
	end
	remember(record)
	savedThisSession[record.DraftId] = true
	markDirty()
	local message = if storeStatus == "On" then text().SavedDataStore else text().Saved
	return reply(true, message, SkinSchema.Copy(record))
end

handlers.Delete = function(_player: Player, draftId: any): Reply
	local record = if type(draftId) == "string" then drafts[draftId] else nil
	if not isLive(record) then
		return reply(false, "That draft is gone.")
	end
	if useDataStore() then
		-- a tombstone, so merging with an older stored copy can't bring it back
		remember({ DraftId = draftId, Deleted = true, Updated = nowMs() })
		markDirty()
	else
		remember({ DraftId = draftId, Deleted = true, Updated = nowMs() })
		drafts[draftId] = nil
	end
	savedThisSession[draftId] = nil
	return reply(true, text().Deleted)
end

local function assetTypeName(id: unknown): string
	if type(id) ~= "number" then
		return "Unknown"
	end
	for _, item in Enum.AssetType:GetEnumItems() do
		if item.Value == id then
			return item.Name
		end
	end
	return "Unknown"
end

local function productInfo(id: number): any
	local ok, info = pcall(function()
		return (MarketplaceService :: any):GetProductInfoAsync(id, Enum.InfoType.Asset)
	end)
	if ok and type(info) == "table" and info.Name ~= nil then
		return info
	end
	local okOld, old = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if okOld and type(old) == "table" and old.Name ~= nil then
		return old
	end
	error(if ok then "Roblox didn't say what that is" else tostring(info))
end

local function creatorAllowed(creatorType: string, creatorId: number, robloxMade: boolean): boolean
	if SkinCatalog and type(SkinCatalog.CreatorAllowed) == "function" then
		local ok, allowed = pcall(SkinCatalog.CreatorAllowed, creatorType, creatorId)
		return ok and allowed == true
	end
	if robloxMade then
		return true
	end
	-- (until SkinCatalog is in the game) the game's own creator
	local ownerType = if game.CreatorType == Enum.CreatorType.Group then "Group" else "User"
	return creatorType == ownerType and creatorId == game.CreatorId and creatorId ~= 0
end

handlers.LookupAsset = function(_player: Player, id: any): Reply
	if type(id) ~= "number" or id ~= id or id < 1 or id >= 2 ^ 53 or math.floor(id) ~= id then
		return reply(false, "A catalog id is a whole number, like 1234567890.")
	end
	local cached = lookups[id]
	if cached then
		return reply(true, cached.Name, SkinSchema.Copy(cached))
	end
	local ok, info = pcall(productInfo, id)
	if not ok then
		return reply(false, "Couldn't look that up: " .. tostring(info))
	end
	local creator = if type(info.Creator) == "table" then info.Creator else {}
	local creatorType = tostring(creator.CreatorType or "User")
	local creatorId = tonumber(creator.CreatorTargetId or creator.Id) or 0
	local robloxMade = creatorType == "User" and creatorId == 1
	local assetType = assetTypeName(info.AssetTypeId)
	local catalogType = nil
	if SkinCatalog and type(SkinCatalog.TypeFromAssetType) == "function" then
		local okType, found = pcall(SkinCatalog.TypeFromAssetType, assetType)
		catalogType = if okType and type(found) == "string" then found else nil
	end
	local allowed = creatorAllowed(creatorType, creatorId, robloxMade)
	local result = {
		Name = tostring(info.Name),
		Type = catalogType,
		AssetType = assetType,
		Creator = tostring(creator.Name or "?"),
		CreatorType = creatorType,
		CreatorId = creatorId,
		RobloxMade = robloxMade,
		Allowed = allowed,
		Problem = if allowed then nil else text().NotAllowedCreator,
	}
	lookups[id] = result
	return reply(true, result.Name, SkinSchema.Copy(result))
end

handlers.PrintDrafts = function(_player: Player, _payload: any): Reply
	local pages = SkinExport.Print()
	return reply(true, text().Printed:format(pages), { Pages = pages })
end

local function cooldownOf(action: string): number
	local cfg = Config.SkinStudio
	if action == "Wear" then
		return cfg.WearCooldown
	elseif action == "Save" then
		return cfg.SaveCooldown
	elseif action == "LookupAsset" then
		return cfg.LookupCooldown
	elseif action == "PrintDrafts" then
		return cfg.PrintCooldown
	end
	return cfg.OtherCooldown
end

local function onInvoke(player: Player, action: unknown, payload: unknown): Reply
	if type(action) ~= "string" then
		return reply(false, "Unknown action.")
	end
	if not SkinStudioService.Allowed(player) then
		return reply(false, text().NotAllowed)
	end
	local handler = handlers[action]
	if not handler then
		return reply(false, "Unknown action.")
	end
	-- stamped before anything can yield, so two calls at once can't both pass
	local now = os.clock()
	local mine = stamps[player]
	if not mine then
		mine = {}
		stamps[player] = mine
	end
	local last = mine[action]
	if last and now - last < cooldownOf(action) then
		return reply(false, text().SlowDown)
	end
	mine[action] = now
	local ok, result = pcall(handler, player, payload)
	if not ok then
		warn("[SkinStudioService] " .. action .. ": " .. tostring(result))
		return reply(false, text().Broken:format(tostring(result)))
	end
	return result
end

-- Start -----------------------------------------------------------------------------------------

function SkinStudioService.Start()
	if started then
		return
	end
	started = true
	-- 1. The remote first, so a client asking never waits on a remote that doesn't exist.
	Remotes.Function("SkinStudio").OnServerInvoke = onInvoke
	-- 2. The F8 button: opens the panel through a player attribute (no remote needed).
	AdminService.Register("SkinStudio", "Skin Studio", function(player, _data)
		if not SkinStudioService.Allowed(player) then
			return text().NotAllowed
		end
		player:SetAttribute("SkinStudioOpenAt", Workspace:GetServerTimeNow())
		return text().Opened
	end)
	Players.PlayerRemoving:Connect(function(player)
		stamps[player] = nil
		wearing[player] = nil
	end)
	-- 3. Switched off: nothing else.
	if not Config.Features.SkinStudio then
		return
	end
	-- 4. Drafts kept after Stop (only with UseDataStore, only in Studio unless allowed live).
	if useDataStore() then
		storeStatus = "Loading"
		task.spawn(load)
		task.spawn(function()
			while true do
				task.wait(Config.SkinStudio.FlushSeconds)
				flush()
			end
		end)
		game:BindToClose(function()
			pcall(flush)
		end)
	end
	-- 5. A last copy in Output when the playtest stops.
	if RunService:IsStudio() and Config.SkinStudio.PrintOnStop then
		game:BindToClose(function()
			if next(savedThisSession) ~= nil then
				pcall(SkinExport.Print)
			end
		end)
	end
end

return SkinStudioService
