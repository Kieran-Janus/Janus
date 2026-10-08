--[[
	Puts Skin Studio drafts into the theme files (src/shared/Config/Skins/<Theme>.luau).
	/save-skins in Claude Code runs it (see .claude/commands/save-skins.md). From new-game/:

	  lune run tests/save-skins -- tests/out/skin-drafts --dry-run      show the plan only
	  lune run tests/save-skins -- tests/out/skin-drafts                 write the files
	  lune run tests/save-skins -- page-1.json --only Pumpkin_A,Candy_B  just these skins

	The input is SkinExport's pages (src/server/Tools/SkinExport.luau), saved as .json files.
	Every draft's checksum is checked first (a page damaged while copying stops everything).
	Each draft is decoded and checked with SkinSchema, and its Luau is written again from the
	checked data (never copied from the page). Refused: drafts with errors, Classic and Tower
	skins, an Id that changed or is used elsewhere, two drafts with one Id, catalog ids not in
	Config.SkinCatalog.ApprovedIds. Exit code 1 when anything was refused.
	Each draft's note (Skin Studio's Save tab, "a note for Claude Code") is printed next to it.
	After writing, it prints the SkinExport.MarkWritten line that tells the running playtest
	which drafts are now in the files (Skin Studio then shows them with a tick).
	The edits themselves are in tests/tools/SkinFile.luau.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Runtime = require("./harness/Runtime")
local SkinFile = require("./tools/SkinFile")

local root = if fs.isDir("src") then "" else "new-game/"

-- Arguments ---------------------------------------------------------------------------------------

local input: string? = nil
local dryRun = false
local only: { [string]: boolean }? = nil
local args = process.args
local i = 1
while i <= #args do
	local arg = args[i]
	if arg == "--dry-run" then
		dryRun = true
	elseif arg == "--only" then
		i += 1
		local set = {}
		for id in (args[i] or ""):gmatch("[^,%s]+") do
			set[id] = true
		end
		only = set
	elseif arg ~= "--" then
		input = arg
	end
	i += 1
end

if not input then
	print(
		"usage: lune run tests/save-skins -- <page.json | folder of pages> [--dry-run] [--only Id,Id]"
	)
	process.exit(1)
end
local path = input :: string

-- Pages -------------------------------------------------------------------------------------------

local files = {}
if fs.isDir(path) then
	for _, name in fs.readDir(path) do
		if name:match("%.json$") then
			table.insert(files, path .. "/" .. name)
		end
	end
	-- page-2 before page-10
	table.sort(files, function(a, b)
		local na, nb = tonumber(a:match("(%d+)%.json$")), tonumber(b:match("(%d+)%.json$"))
		if na and nb and na ~= nb then
			return na < nb
		end
		return a < b
	end)
elseif fs.isFile(path) then
	table.insert(files, path)
end
if #files == 0 then
	print("No pages found at " .. path)
	process.exit(1)
end

local pages = {}
for _, file in files do
	local ok, page = pcall(serde.decode, "json", fs.readFile(file))
	if not ok then
		print(("%s isn't JSON: read it again from Studio (%s)"):format(file, tostring(page)))
		process.exit(1)
	end
	table.insert(pages, page)
end

-- Plan ----------------------------------------------------------------------------------------------

local rt = Runtime.new({ echo = "none" })
local plan = SkinFile.Plan(pages, {
	Schema = rt:require("ReplicatedStorage.Shared.SkinSchema"),
	Export = rt:require("ServerScriptService.Server.Tools.SkinExport"),
	Config = rt:require("ReplicatedStorage.Shared.Config"),
	Items = rt:require("ReplicatedStorage.Shared.Items"),
	Decode = function(text: string): any
		return serde.decode("json", text)
	end,
	ReadTheme = function(theme: string): string?
		local file = root .. "src/shared/Config/Skins/" .. theme .. ".luau"
		if not fs.isFile(file) then
			return nil
		end
		return fs.readFile(file)
	end,
}, { Only = only })

if plan.Damaged then
	print("STOPPED: " .. plan.Damaged)
	process.exit(1)
end

print(if dryRun then "Plan (dry run, nothing written):" else "Saving:")
-- A note is Kieran's own text: shown as it is, on one line, for Claude Code to raise with him.
local function noteText(note: string?): string
	if type(note) ~= "string" or note == "" then
		return ""
	end
	local quoted = string.gsub(string.format("%q", note), "\\\n", " ")
	return "   note: " .. quoted
end

local themes = {}
local written: { number } = {}
for theme in plan.Files do
	table.insert(themes, theme)
end
table.sort(themes)
for _, theme in themes do
	local file = plan.Files[theme]
	print(("\n%s.luau"):format(theme))
	for _, change in file.Changes do
		print(("  %s %s%s"):format(change.Action, change.Id, noteText(change.Note)))
		table.insert(written, change.Sum)
	end
	print("  before: " .. SkinFile.CountsText(file.CountsBefore))
	print("  after:  " .. SkinFile.CountsText(file.CountsAfter))
	if not dryRun then
		fs.writeFile(root .. "src/shared/Config/Skins/" .. theme .. ".luau", file.After)
	end
end
if #themes == 0 then
	print("  (nothing to write)")
end

if #plan.Economy > 0 then
	print("\n!!! ECONOMY CHANGES (skins players already own) !!!")
	for _, text in plan.Economy do
		print("  " .. text)
	end
end
if #plan.Warnings > 0 then
	print("\nWarnings (allowed, but the tests may complain):")
	for _, text in plan.Warnings do
		print("  " .. text)
	end
end
if #plan.Refused > 0 then
	print("\nRefused:")
	for _, refused in plan.Refused do
		print(("  %s: %s%s"):format(refused.Id, refused.Why, noteText(refused.Note)))
	end
end
if not dryRun and #written > 0 then
	local sums = {}
	for _, sum in written do
		table.insert(sums, string.format("%d", sum))
	end
	print(
		"\nTell the playtest these drafts are in the files now (Skin Studio shows them with a tick"
	)
	print('and stops reminding you): Studio MCP execute_luau, datamodel_type "Server":')
	print(
		('  return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).MarkWritten({ %s })'):format(
			table.concat(sums, ", ")
		)
	)
end
if #plan.Refused > 0 then
	process.exit(1)
end
process.exit(0)
