--!strict
--[[
	SkinExport: hands Skin Studio's saved drafts to Claude Code (/save-skins), page by page.
	Safe to require anywhere, also in edit mode from the Studio MCP or the command bar: it keeps
	no state, makes no instances and only requires Config.

	SkinExport.Count() -> string            JSON {"From":"Playtest"|"DataStore"|"None","Drafts":n,"Pages":n,"Problem":"..."?}
	SkinExport.Json(page) -> string         JSON {"Version":2,"From":...,"Page":p,"Pages":n,"Drafts":[{"Sum":n,"Text":"<draft JSON>"}]}
	SkinExport.Print() -> number            prints every page to Output between
	                                        Config.SkinStudio.ExportMarkers; returns the page count
	SkinExport.Sum(text) -> number          a checksum (FNV-1a, 32 bit) of `text`

	Where the drafts come from: during a playtest, the server's ServerStorage.SkinStudioDrafts
	(one StringValue per draft, made by SkinStudioService). Otherwise, the DataStore copy (only
	when Config.SkinStudio.UseDataStore is on). Deleted drafts are never exported.
	Each draft's Text is the exact stored text, and Sum is worked out from that same text, so
	tests/save-skins.luau can tell when a page was damaged while being copied.

	From Claude Code with the Studio MCP (execute_luau, datamodel_type "Server" while playing):
	  return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).Count()
	  return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).Json(1)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local SkinExport = {}

local MIRROR = "SkinStudioDrafts"
local ENVELOPE = 300 -- room kept in each page for {"Version":2,"From":...}

type Entry = { Sum: number, Text: string, Key: string }

-- FNV-1a over the bytes of `text`, kept to 32 bits.
function SkinExport.Sum(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		-- hash * 16777619, split in two so it stays exact in a double
		local low = bit32.band(hash, 0xFFFF)
		local high = bit32.rshift(hash, 16)
		hash = bit32.band(
			low * 16777619 + bit32.lshift(bit32.band(high * 16777619, 0xFFFF), 16),
			0xFFFFFFFF
		)
	end
	return hash
end

-- Every live draft as { Sum, Text }, sorted, and where they came from.
local function collect(): ({ Entry }, string, string?)
	local entries: { Entry } = {}
	local mirror = ServerStorage:FindFirstChild(MIRROR)
	if mirror then
		for _, child in mirror:GetChildren() do
			if child:IsA("StringValue") then
				local text = child.Value
				table.insert(entries, {
					Sum = SkinExport.Sum(text),
					Text = text,
					Key = tostring(child:GetAttribute("SkinId") or "") .. "|" .. child.Name,
				})
			end
		end
		table.sort(entries, function(a, b)
			return a.Key < b.Key
		end)
		return entries, "Playtest", nil
	end
	local cfg = Config.SkinStudio
	if not cfg.UseDataStore then
		return entries,
			"None",
			"No playtest is running and UseDataStore is off: press Play, open Skin Studio and Save again."
	end
	local ok, stored = pcall(function()
		return DataStoreService:GetDataStore(cfg.DraftStore):GetAsync(cfg.DraftKey)
	end)
	if not ok then
		return entries, "None", "Couldn't read the DataStore: " .. tostring(stored)
	end
	local drafts = if type(stored) == "table" and type(stored.Drafts) == "table"
		then stored.Drafts
		else {}
	for id, record in drafts do
		if type(record) == "table" and not record.Deleted and type(record.Item) == "table" then
			local text = HttpService:JSONEncode(record)
			local skinId = tostring(record.Item.Id or "")
			table.insert(
				entries,
				{ Sum = SkinExport.Sum(text), Text = text, Key = skinId .. "|" .. tostring(id) }
			)
		end
	end
	table.sort(entries, function(a, b)
		return a.Key < b.Key
	end)
	return entries, "DataStore", nil
end

-- Splits the entries into pages of whole drafts, each under ExportPageChars.
local function paginate(entries: { Entry }): { { { Sum: number, Text: string } } }
	local limit = Config.SkinStudio.ExportPageChars - ENVELOPE
	local pages = {}
	local current: { { Sum: number, Text: string } } = {}
	local size = 0
	for _, entry in entries do
		local item = { Sum = entry.Sum, Text = entry.Text }
		local cost = #HttpService:JSONEncode(item) + 1
		if #current > 0 and size + cost > limit then
			table.insert(pages, current)
			current = {}
			size = 0
		end
		table.insert(current, item)
		size += cost
	end
	if #current > 0 then
		table.insert(pages, current)
	end
	return pages
end

function SkinExport.Count(): string
	local entries, from, problem = collect()
	local pages = paginate(entries)
	return HttpService:JSONEncode({
		From = from,
		Drafts = #entries,
		Pages = #pages,
		Problem = problem,
	})
end

function SkinExport.Json(page: number): string
	local entries, from = collect()
	local pages = paginate(entries)
	local index = if type(page) == "number" then math.floor(page) else 1
	return HttpService:JSONEncode({
		Version = 2,
		From = from,
		Page = index,
		Pages = #pages,
		Drafts = pages[index] or {},
	})
end

function SkinExport.Print(): number
	local entries, from = collect()
	local pages = paginate(entries)
	local markers = Config.SkinStudio.ExportMarkers
	for index, drafts in pages do
		print(markers.Begin)
		print(HttpService:JSONEncode({
			Version = 2,
			From = from,
			Page = index,
			Pages = #pages,
			Drafts = drafts,
		}))
		print(markers.End)
	end
	return #pages
end

return SkinExport
