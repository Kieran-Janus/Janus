--[[
	Scene preview export (from new-game/): builds the hub, a map or a lobby section in the test
	harness and writes a scene JSON for the offline previewer (cloud tooling, outside the repo):

	  lune run tests/preview -- hub [out.json]
	  lune run tests/preview -- map <MapId> [out.json]
	  lune run tests/preview -- section <SectionName> [out.json]

	Default output: tests/out/<hub | MapId | section-Name>.json. Then render it with
	  node /tmp/claude-0/render/render.mjs tests/out/hub.json tests/out/hub --views overview,top,ground

	Options:
	  --exporter <path>   the previewer's export.luau (default: $ROBLOX_PREVIEW_EXPORTER, else
	                      /tmp/claude-0/render/export.luau)
	  --pretty            pretty-print the JSON

	hub      HubBuilder.Build() with Config.Hub.Lighting, plus the terrain it fills
	map      MapService.Load(<MapId>) (its builder, or ServerStorage.Maps) with the map's Lighting
	section  src/server/Hub/Sections/<Name>.luau: Build(hub, HubLayout.Zone(<Name>)) into an
	         empty hub Model, with Config.Hub.Lighting (the zone HubBuilder gives every section)
	Terrain:Fill* calls are recorded by the harness (not simulated) and exported as shapes.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Runtime = require("./harness/Runtime")

local DEFAULT_EXPORTER = "/tmp/claude-0/render/export.luau"

local USAGE = [[
usage (from new-game/):
  lune run tests/preview -- hub [out.json]
  lune run tests/preview -- map <MapId> [out.json]
  lune run tests/preview -- section <SectionName> [out.json]
options: --exporter <path to export.luau>  --pretty]]

local function fail(message: string)
	print("preview: " .. message)
	process.exit(1)
	error(message) -- not reached
end

-- Arguments ---------------------------------------------------------------------------------------

local positional: { string } = {}
local exporterPath = process.env.ROBLOX_PREVIEW_EXPORTER or DEFAULT_EXPORTER
local pretty = false
do
	local args = process.args
	local i = 1
	while i <= #args do
		local arg = args[i]
		if arg == "--exporter" then
			exporterPath = args[i + 1] or fail("--exporter needs a path")
			i += 1
		elseif arg == "--pretty" then
			pretty = true
		elseif arg == "--help" or arg == "-h" then
			print(USAGE)
			process.exit(0)
		else
			table.insert(positional, arg)
		end
		i += 1
	end
end

local kind = positional[1]
local name: string? = nil
local output: string? = nil
if kind == "hub" then
	output = positional[2]
elseif kind == "map" or kind == "section" then
	name = positional[2]
	output = positional[3]
	if not name then
		fail(("%s needs a name\n%s"):format(kind, USAGE))
	end
else
	fail(USAGE)
end
output = output
	or ("tests/out/%s.json"):format(
		if kind == "hub" then "hub" elseif kind == "map" then name else "section-" .. name
	)

-- The exporter lives outside the repo (cloud tooling).
if not fs.isFile(exporterPath) then
	fail(
		("can't find the scene exporter at %s.\nIt is part of the cloud preview tooling, not this repo: pass --exporter <path to export.luau> or set ROBLOX_PREVIEW_EXPORTER."):format(
			exporterPath
		)
	)
end
local Export = luau.load(fs.readFile(exporterPath), { debugName = exporterPath })()

-- Build ---------------------------------------------------------------------------------------------

local rt = Runtime.new({ echo = "warn" })
local Config = rt:require("ReplicatedStorage.Shared.Config")
local roots: { any } = {}
local lighting: any

if kind == "hub" then
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	table.insert(roots, HubBuilder.Build())
	lighting = Config.Hub.Lighting
elseif kind == "map" then
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")
	if not MapService.Get(name) then
		local ids = {}
		for _, def in Config.Maps.List do
			table.insert(ids, def.Id)
		end
		fail(("unknown map %s (maps: %s)"):format(tostring(name), table.concat(ids, ", ")))
	end
	local map = MapService.Load(name)
	table.insert(roots, map.Model)
	lighting = MapService.Get(name).Lighting
else
	local hubFolder = rt:find("ServerScriptService.Server.Hub")
	local sections = hubFolder:FindFirstChild("Sections")
	if not sections then
		fail("src/server/Hub/Sections doesn't exist yet, so there are no sections to preview")
	end
	local module = sections:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		local names = {}
		for _, child in sections:GetChildren() do
			if child:IsA("ModuleScript") then
				table.insert(names, child.Name)
			end
		end
		fail(("no section %s (sections: %s)"):format(tostring(name), table.concat(names, ", ")))
	end
	local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
	-- The same zone HubBuilder.BuildSection passes: { Name, CFrame, Size } from Config.Lobby.Zones.
	local HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout")
	rt:require(module).Build(hub, HubLayout.Zone(name))
	table.insert(roots, hub)
	lighting = Config.Hub.Lighting
end
rt:flush()

-- Terrain: the recorded Terrain:Fill* calls, in the order they were made ------------------------

local FILLS = { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "FillRegion" }
local terrain = {}
for _, call in rt:calls("Terrain", FILLS) do
	local a = call.args
	local entry
	if call.method == "FillBlock" then
		entry = { kind = "Block", cframe = a[1], size = a[2], material = a[3] }
	elseif call.method == "FillBall" then
		entry = { kind = "Ball", cframe = rt.env.CFrame.new(a[1]), radius = a[2], material = a[3] }
	elseif call.method == "FillCylinder" then
		entry = { kind = "Cylinder", cframe = a[1], height = a[2], radius = a[3], material = a[4] }
	elseif call.method == "FillWedge" then
		entry = { kind = "Wedge", cframe = a[1], size = a[2], material = a[3] }
	else
		local region = a[1]
		entry = {
			min = region.CFrame.Position - region.Size / 2,
			max = region.CFrame.Position + region.Size / 2,
			material = a[3],
		}
	end
	table.insert(terrain, entry)
end

-- Write -----------------------------------------------------------------------------------------------

local dir = (output :: string):match("^(.*)[/\\][^/\\]+$")
if dir and dir ~= "" and not fs.isDir(dir) then
	fs.writeDir(dir)
end
local stats = Export.write(output, roots, {
	lighting = lighting,
	terrain = terrain,
	pretty = pretty,
	meta = { source = "new-game/tests/preview.luau", kind = kind, name = name or "Hub" },
})
print(
	("wrote %s: %d parts, %d lights, %d effects, %d labels, %d terrain fills"):format(
		output :: string,
		stats.parts,
		stats.lights,
		stats.effects,
		stats.labels,
		#terrain
	)
)
local renderer = exporterPath:gsub("export%.luau$", "render.mjs")
print(
	("render: node %s %s %s --views overview,top,ground"):format(
		renderer,
		output :: string,
		((output :: string):gsub("%.json$", ""))
	)
)
