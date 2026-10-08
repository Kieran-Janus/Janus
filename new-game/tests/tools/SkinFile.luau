--[[
	SkinFile: the helpers tests/save-skins.luau uses to put Skin Studio drafts into the theme
	files (src/shared/Config/Skins/<Theme>.luau). Pure: text in, text out (tests use them too).

	A theme file is a list of entries, each from a line "\t{" to the next line "\t},", with the
	keys one tab deeper ("\t\tId = \"Pumpkin_CandleKid\","). Only the lines of the entry that
	changes are touched: every other byte of the file stays exactly the same.

	SkinFile.Find(text, id) -> (first, last)?    the entry's line numbers
	SkinFile.Replace(text, id, entry) -> (text?, problem?)
	SkinFile.Insert(text, rarity, entry) -> (text?, problem?)
	                                             after the last entry of that rarity, or before
	                                             the closing "} :: { any }"
	SkinFile.Counts(text) -> { Common, Uncommon, Rare, Crazy, Million, Total }
	SkinFile.UpdateHeader(text, counts) -> text  the "(20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY"
	                                             line at the top, when it has that shape
	SkinFile.HasLocals(text) -> boolean          the file defines rgb and M (ToLuau writes them)
	SkinFile.Plan(pages, deps, options?) -> Plan the whole /save-skins run, without writing
]]

local SkinFile = {}

local RARITIES = { "Common", "Uncommon", "Rare", "Crazy" }

-- The text as lines, and the line ending it uses ("\r\n" on Windows checkouts).
local function split(text: string): ({ string }, string)
	local newline = if text:find("\r\n", 1, true) then "\r\n" else "\n"
	local lines = {}
	local start = 1
	while true do
		local at = text:find(newline, start, true)
		if not at then
			table.insert(lines, text:sub(start))
			break
		end
		table.insert(lines, text:sub(start, at - 1))
		start = at + #newline
	end
	return lines, newline
end

local function join(lines: { string }, newline: string): string
	return table.concat(lines, newline)
end

local function entryLines(entry: string): { string }
	local lines = {}
	for line in (entry .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, (line:gsub("\r$", "")))
	end
	return lines
end

-- Every entry: { First, Last, Id, Rarity, Million }.
local function entries(lines: { string }): { any }
	local out = {}
	local first: number? = nil
	for i, line in lines do
		if line == "\t{" then
			first = i
		elseif line == "\t}," and first then
			local entry = { First = first, Last = i, Id = nil, Rarity = nil, Million = false }
			for j = first + 1, i - 1 do
				local l = lines[j]
				entry.Id = entry.Id or l:match('^\t\tId = "([^"]+)",')
				entry.Rarity = entry.Rarity or l:match('^\t\tRarity = "(%a+)",')
				if l:match("^\t\tOneInAMillion = true") then
					entry.Million = true
				end
			end
			table.insert(out, entry)
			first = nil
		end
	end
	return out
end

function SkinFile.Find(text: string, id: string): (number?, number?)
	local lines = split(text)
	for _, entry in entries(lines) do
		if entry.Id == id then
			return entry.First, entry.Last
		end
	end
	return nil, nil
end

function SkinFile.Replace(text: string, id: string, entry: string): (string?, string?)
	local lines, newline = split(text)
	for _, found in entries(lines) do
		if found.Id == id then
			local out = table.move(lines, 1, found.First - 1, 1, {})
			for _, line in entryLines(entry) do
				table.insert(out, line)
			end
			for i = found.Last + 1, #lines do
				table.insert(out, lines[i])
			end
			return join(out, newline), nil
		end
	end
	return nil, "no entry with Id " .. id
end

function SkinFile.Insert(text: string, rarity: string, entry: string): (string?, string?)
	local lines, newline = split(text)
	local after: number? = nil
	for _, found in entries(lines) do
		if found.Rarity == rarity then
			after = found.Last
		end
	end
	if not after then
		for i = #lines, 1, -1 do
			if lines[i]:match("^}") then
				after = i - 1
				break
			end
		end
	end
	if not after then
		return nil, "the file has no closing } :: { any }"
	end
	local out = table.move(lines, 1, after, 1, {})
	for _, line in entryLines(entry) do
		table.insert(out, line)
	end
	for i = after + 1, #lines do
		table.insert(out, lines[i])
	end
	return join(out, newline), nil
end

function SkinFile.Counts(text: string): { [string]: number }
	local counts = { Common = 0, Uncommon = 0, Rare = 0, Crazy = 0, Million = 0, Total = 0 }
	for _, entry in entries((split(text))) do
		counts.Total += 1
		if entry.Million then
			counts.Million += 1
		elseif entry.Rarity and counts[entry.Rarity] then
			counts[entry.Rarity] += 1
		end
	end
	return counts
end

function SkinFile.UpdateHeader(text: string, counts: { [string]: number }): string
	local lines, newline = split(text)
	for i = 1, math.min(#lines, 12) do
		local line = lines[i]
		local prefix, rest =
			line:match("^(.-CRATE SKINS )%(%d+%): %d+ Common, %d+ Uncommon, %d+ Rare(.*)$")
		if prefix then
			local tail = rest:gsub("^, %d+ CRAZY", "")
			if counts.Million > 0 then
				tail =
					tail:gsub("^, and %d+ CRAZY that", ", and " .. counts.Million .. " CRAZY that")
			end
			local crazy = if counts.Crazy > 0 then (", %d CRAZY"):format(counts.Crazy) else ""
			lines[i] = ("%s(%d): %d Common, %d Uncommon, %d Rare%s%s"):format(
				prefix,
				counts.Total,
				counts.Common,
				counts.Uncommon,
				counts.Rare,
				crazy,
				tail
			)
			return join(lines, newline)
		end
	end
	return text
end

function SkinFile.HasLocals(text: string): boolean
	return text:find("local rgb = Color3.fromRGB", 1, true) ~= nil
		and text:find("local M = Enum.Material", 1, true) ~= nil
end

function SkinFile.CountsText(counts: { [string]: number }): string
	local parts = {}
	for _, rarity in RARITIES do
		table.insert(parts, ("%d %s"):format(counts[rarity] or 0, rarity))
	end
	if (counts.Million or 0) > 0 then
		table.insert(parts, ("%d one in a million"):format(counts.Million))
	end
	return ("%d skins: %s"):format(counts.Total or 0, table.concat(parts, ", "))
end

--[[
	The whole /save-skins run, without writing anything.
	pages   the decoded export pages: { { Version = 2, Drafts = { { Sum, Text } } } }
	deps    { Schema = SkinSchema, Export = SkinExport, Config = Config, Items = Items,
	          Decode = function(text) -> table (JSON), ReadTheme = function(themeId) -> text? }
	options { Only = { [Id] = true }? }
	Returns { Damaged = string?, Refused = { { Id, Why, Note? } }, Warnings = { string },
	          Economy = { string }, Files = { [themeId] = { Before, After, CountsBefore,
	          CountsAfter, Changes = { { Id, Action, Note?, Sum } } } } }
	Note is the draft's "note for Claude Code" from Skin Studio's Save tab; Sum is the draft's
	checksum, for SkinExport.MarkWritten once the files are written.
]]
function SkinFile.Plan(pages: { any }, deps: any, options: any?): any
	local plan = { Damaged = nil, Refused = {}, Warnings = {}, Economy = {}, Files = {} }
	local Schema, Export, Config, Items = deps.Schema, deps.Export, deps.Config, deps.Items
	local only = options and options.Only
	-- 1. every checksum first: one damaged draft stops the whole run
	local drafts = {}
	for p, page in pages do
		if type(page) ~= "table" or page.Version ~= 2 or type(page.Drafts) ~= "table" then
			plan.Damaged = ("page %d isn't a Skin Studio export page (Version 2)"):format(p)
			return plan
		end
		for d, entry in page.Drafts do
			if
				type(entry) ~= "table"
				or type(entry.Text) ~= "string"
				or Export.Sum(entry.Text) ~= entry.Sum
			then
				plan.Damaged = ("page %d, draft %d was damaged in copying: read it again"):format(
					p,
					d
				)
				return plan
			end
			table.insert(drafts, { Text = entry.Text, Sum = entry.Sum })
		end
	end
	local notes: { [string]: string } = {} -- skin Id -> the draft's note
	local function refuse(id: any, why: string)
		table.insert(plan.Refused, { Id = tostring(id), Why = why, Note = notes[tostring(id)] })
	end
	-- 2. decode and check each draft (the Luau is always made again from the checked data)
	local accepted = {}
	local seen: { [string]: number } = {}
	for _, draft in drafts do
		local ok, record = pcall(deps.Decode, draft.Text)
		if not ok or type(record) ~= "table" or record.Deleted then
			continue
		end
		local item, errors = Schema.Decode(record.Item)
		local id = if type(record.Item) == "table" then record.Item.Id else nil
		if only and not only[tostring(id)] then
			continue
		end
		if type(record.Note) == "string" and record.Note ~= "" then
			notes[tostring(id)] = record.Note
		end
		if not item then
			refuse(id, table.concat(errors, "; "))
			continue
		end
		seen[item.Id] = (seen[item.Id] or 0) + 1
		table.insert(accepted, { Record = record, Item = item, Sum = draft.Sum })
	end
	local approved = if type(Config.SkinCatalog) == "table"
		then Config.SkinCatalog.ApprovedIds or {}
		else {}
	local ready = {}
	for _, draft in accepted do
		local record, item = draft.Record, draft.Item
		local valid, errors, warnings = Schema.Validate(item)
		if seen[item.Id] > 1 then
			refuse(item.Id, "two drafts in this batch have this Id: delete one in Skin Studio")
			continue
		end
		if not valid then
			refuse(item.Id, table.concat(errors, "; "))
			continue
		end
		if not Schema.IsCrateTheme(item.Theme) or item.Exclusive then
			refuse(
				item.Id,
				"Classic and Tower skins aren't written by /save-skins: edit them by hand or use Copy code"
			)
			continue
		end
		local existing = Items.Get(item.Id)
		if record.Source ~= nil then
			if record.Source ~= item.Id then
				refuse(
					item.Id,
					("it edits %s but its Id changed: Ids never change"):format(
						tostring(record.Source)
					)
				)
				continue
			end
			if not existing then
				refuse(item.Id, "the skin it edits isn't in the game files any more")
				continue
			end
		elseif existing then
			refuse(item.Id, "a skin with this Id is already in the game: edit that one instead")
			continue
		end
		if existing and existing.Theme ~= item.Theme then
			refuse(
				item.Id,
				("the Id is already used in the %s theme file"):format(tostring(existing.Theme))
			)
			continue
		end
		-- catalog ids must be approved in Config.SkinCatalog.ApprovedIds
		local catalog = item.Style.Catalog
		local ids = {}
		if type(catalog) == "table" then
			for _, entry in
				(if type(catalog.Accessories) == "table" then catalog.Accessories else {})
			do
				table.insert(ids, entry.Id)
			end
			for _, key in { "Shirt", "Pants", "TShirt", "ClassicFace" } do
				if type(catalog[key]) == "number" then
					table.insert(ids, catalog[key])
				end
			end
		end
		local unapproved = {}
		for _, assetId in ids do
			if approved[assetId] == nil then
				local info = type(record.Lookups) == "table"
					and record.Lookups[("%d"):format(assetId)]
				local creator = if type(info) == "table"
					then ("%s by %s (%s %s)%s"):format(
						tostring(info.Name),
						tostring(info.Creator),
						tostring(info.CreatorType),
						tostring(info.CreatorId),
						if info.RobloxMade then ", made by Roblox" else ""
					)
					else "never looked up in Skin Studio"
				table.insert(unapproved, ("%d: %s"):format(assetId, creator))
			end
		end
		if #unapproved > 0 then
			refuse(
				item.Id,
				"catalog ids not in Config.SkinCatalog.ApprovedIds: "
					.. table.concat(unapproved, "; ")
			)
			continue
		end
		-- economy changes of a skin players own (allowed only when unlocked, and said loudly)
		if existing then
			local changed = {}
			for _, key in Schema.EconomyKeys do
				if item[key] ~= existing[key] then
					table.insert(
						changed,
						("%s %s -> %s"):format(key, tostring(existing[key]), tostring(item[key]))
					)
				end
			end
			if #changed > 0 then
				if not record.UnlockEconomy then
					refuse(item.Id, "its rarity, crate or price changed but it wasn't unlocked")
					continue
				end
				table.insert(
					plan.Economy,
					("%s: %s (players already own it; crate odds change)"):format(
						item.Id,
						table.concat(changed, ", ")
					)
				)
			end
		end
		for _, text in warnings do
			table.insert(plan.Warnings, item.Id .. ": " .. text)
		end
		table.insert(ready, { Item = item, Existing = existing ~= nil, Sum = draft.Sum })
	end
	-- 3. edit each theme file
	for _, draft in ready do
		local theme = draft.Item.Theme
		local file = plan.Files[theme]
		if not file then
			local text = deps.ReadTheme(theme)
			if not text then
				refuse(draft.Item.Id, "can't read the theme file for " .. theme)
				continue
			end
			if not SkinFile.HasLocals(text) then
				refuse(
					draft.Item.Id,
					theme .. ".luau has no local rgb = Color3.fromRGB / local M = Enum.Material"
				)
				continue
			end
			file =
				{ Before = text, After = text, CountsBefore = SkinFile.Counts(text), Changes = {} }
			plan.Files[theme] = file
		end
		local code = Schema.ToLuau(draft.Item, theme)
		local newText, problem
		if SkinFile.Find(file.After, draft.Item.Id) then
			newText, problem = SkinFile.Replace(file.After, draft.Item.Id, code)
			table.insert(file.Changes, {
				Id = draft.Item.Id,
				Action = "replaced",
				Note = notes[draft.Item.Id],
				Sum = draft.Sum,
			})
		else
			newText, problem = SkinFile.Insert(file.After, draft.Item.Rarity, code)
			table.insert(file.Changes, {
				Id = draft.Item.Id,
				Action = "added",
				Note = notes[draft.Item.Id],
				Sum = draft.Sum,
			})
		end
		if not newText then
			table.remove(file.Changes)
			refuse(draft.Item.Id, problem or "couldn't edit the theme file")
			continue
		end
		file.After = newText
	end
	for _, file in plan.Files do
		file.CountsAfter = SkinFile.Counts(file.After)
		file.After = SkinFile.UpdateHeader(file.After, file.CountsAfter)
	end
	return plan
end

return SkinFile
