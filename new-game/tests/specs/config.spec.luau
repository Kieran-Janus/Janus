-- Config sanity: ids, slots, prices and references between sections line up.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Items = rt:require("ReplicatedStorage.Shared.Items")
local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
local typeof = Runtime.typeof

describe("Config.Shop", function()
	it("has items", function()
		expect(#Config.Shop.Items).toBeGreaterThan(0)
		T.note(#Config.Shop.Items, "shop items")
	end)

	it("gives every item a unique Id", function()
		local seen = {}
		for i, item in Config.Shop.Items do
			expect(typeof(item.Id)).toBe("string")
			expect(#item.Id).toBeGreaterThan(0)
			if seen[item.Id] then
				error(("duplicate shop Id %q (items %d and %d)"):format(item.Id, seen[item.Id], i))
			end
			seen[item.Id] = i
		end
	end)

	it("puts every item in a known Slot", function()
		for _, item in Config.Shop.Items do
			if not table.find(Config.Shop.Slots, item.Slot) then
				error(
					("%s has Slot %s, not one of Config.Shop.Slots"):format(
						item.Id,
						tostring(item.Slot)
					)
				)
			end
		end
	end)

	it("gives every item a Rarity from Config.Rarity.Order", function()
		for _, item in Config.Shop.Items do
			if not table.find(Config.Rarity.Order, item.Rarity) then
				error(
					("%s has Rarity %s, not one of %s"):format(
						item.Id,
						tostring(item.Rarity),
						table.concat(Config.Rarity.Order, ", ")
					)
				)
			end
		end
	end)

	it("prices items by rarity with Items.Price (own Price wins, VIP/crate-only unsold)", function()
		for _, item in Config.Shop.Items do
			local price = Items.Price(item)
			if item.VipOnly or item.CrateOnly then
				expect(price).toBeNil()
			else
				local expected = if item.Price ~= nil
					then item.Price
					else Config.Rarity.Levels[item.Rarity].Price
				if price ~= expected then
					error(
						("%s: Items.Price is %s, expected %s"):format(
							item.Id,
							tostring(price),
							tostring(expected)
						)
					)
				end
				if type(price) ~= "number" or price < 0 or price % 1 ~= 0 then
					error(("%s costs %s"):format(item.Id, tostring(price)))
				end
			end
		end
	end)

	it("gives every item a Style table with a Kind", function()
		for _, item in Config.Shop.Items do
			if type(item.Style) ~= "table" or type(item.Style.Kind) ~= "string" then
				error(("%s has no Style.Kind"):format(item.Id))
			end
		end
	end)

	it("names every slot", function()
		for _, slot in Config.Shop.Slots do
			expect(Config.Shop.SlotNames[slot]).toBeA("string")
		end
	end)

	it("has a save slot for every shop slot", function()
		for _, slot in Config.Shop.Slots do
			expect(Config.Data.Template.Equipped[slot]).toBe("")
		end
	end)

	it("only gives codes for items that exist", function()
		local ids = {}
		for _, item in Config.Shop.Items do
			ids[item.Id] = true
		end
		for _, code in Config.Codes.List do
			if code.Item and not ids[code.Item] then
				error(("code %s gives unknown item %s"):format(code.Code, code.Item))
			end
		end
	end)
end)

describe("Config.Npcs", function()
	it("gives every NPC an Id, a Kind and a place (a lobby Zone or a Vector3 Offset)", function()
		expect(#Config.Npcs.List).toBeGreaterThan(0)
		local seen = {}
		for i, npc in Config.Npcs.List do
			if type(npc.Id) ~= "string" or npc.Id == "" then
				error(("Npcs.List[%d] has no Id"):format(i))
			end
			if seen[npc.Id] then
				error("duplicate NPC Id " .. npc.Id)
			end
			seen[npc.Id] = true
			expect(npc.Kind).toBeA("string")
			if npc.Zone ~= nil then
				expect(npc.Zone).toBeA("string")
				if not Config.Lobby.Zones[npc.Zone] then
					error(
						("%s has Zone %q, which isn't in Config.Lobby.Zones"):format(
							npc.Id,
							npc.Zone
						)
					)
				end
			else
				expect(npc.Offset).toBeA("Vector3")
			end
		end
	end)

	it("gives every NPC a prompt", function()
		for _, npc in Config.Npcs.List do
			expect(npc.Prompt).toBeA("table")
			expect(npc.Prompt.ActionText).toBeA("string")
		end
	end)
end)

describe("Config.Maps", function()
	it("has unique map ids", function()
		expect(#Config.Maps.List).toBeGreaterThan(0)
		local seen = {}
		for _, def in Config.Maps.List do
			expect(def.Id).toBeA("string")
			if seen[def.Id] then
				error("duplicate map Id " .. def.Id)
			end
			seen[def.Id] = true
		end
	end)

	it("points every map at a builder module that exists", function()
		local maps = rt:find("ServerScriptService.Server.Maps")
		for _, def in Config.Maps.List do
			local builder = maps:FindFirstChild(def.Builder or "")
			if not (builder and builder:IsA("ModuleScript")) then
				error(
					("%s has Builder %s, but there is no src/server/Maps/%s.luau"):format(
						def.Id,
						tostring(def.Builder),
						tostring(def.Builder)
					)
				)
			end
		end
	end)

	it("gives every map a size, spawns and a spawn folder", function()
		for _, def in Config.Maps.List do
			expect(def.Size).toBeA("Vector3")
			expect(def.Spawns).toBeGreaterThan(0)
			expect(def.SpawnFolder).toBeA("string")
			expect(def.SpawnRadius).toBeLessThan(math.min(def.Size.X, def.Size.Z) / 2)
		end
	end)

	it("gives every map all the Lighting groups ZoneLighting applies", function()
		for _, def in Config.Maps.List do
			if type(def.Lighting) ~= "table" then
				error(def.Id .. " has no Lighting")
			end
			for _, group in { "Atmosphere", "ColorCorrection", "Bloom" } do
				if type(def.Lighting[group]) ~= "table" then
					error(("%s has no Lighting.%s"):format(def.Id, group))
				end
			end
		end
	end)

	it("gives every map a Modes list of real modes", function()
		for _, def in Config.Maps.List do
			if type(def.Modes) ~= "table" or #def.Modes == 0 then
				error(def.Id .. " has no Modes list")
			end
			for _, mode in def.Modes do
				if not Config.Modes.List[mode] then
					error(("%s lists unknown mode %s"):format(def.Id, tostring(mode)))
				end
			end
		end
	end)
end)

describe("Config.Modes", function()
	it("points every playlist at a real mode and a map made for that mode", function()
		local maps = {}
		for _, def in Config.Maps.List do
			maps[def.Id] = def
		end
		for _, playlist in Config.Modes.Playlists or {} do
			if not Config.Modes.List[playlist.Mode] then
				error(("playlist %s: unknown mode %s"):format(playlist.Id, tostring(playlist.Mode)))
			end
			local map = maps[playlist.Map]
			if not map then
				error(("playlist %s: unknown map %s"):format(playlist.Id, tostring(playlist.Map)))
			end
			if not table.find(map.Modes or {}, playlist.Mode) then
				error(
					("playlist %s: map %s isn't made for %s"):format(
						playlist.Id,
						playlist.Map,
						playlist.Mode
					)
				)
			end
		end
	end)

	it("orders every mode, with a feature switch each", function()
		for _, id in Config.Modes.Order do
			local mode = Config.Modes.List[id]
			expect(mode).toBeA("table")
			expect(Config.Features[mode.Feature]).toBeA("boolean")
		end
	end)
end)

-- The four corners (x, z) of a lobby zone, which is turned to face the hub centre.
local function zoneCorners(name: string): { { number } }
	local zone = Config.Lobby.Zones[name]
	local cf = Lobby.ZoneCFrame(name)
	local corners = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = cf * rt.env.Vector3.new(sx * zone.Size.X / 2, 0, sz * zone.Size.Z / 2)
			table.insert(corners, { p.X, p.Z })
		end
	end
	return corners
end

-- Separating-axis test for two convex quads in the XZ plane (touching edges don't count).
local function quadsOverlap(a: { { number } }, b: { { number } }): boolean
	for _, quad in { a, b } do
		for i = 1, #quad do
			local p, q = quad[i], quad[i % #quad + 1]
			local nx, nz = q[2] - p[2], p[1] - q[1]
			local function project(points)
				local lo, hi = math.huge, -math.huge
				for _, c in points do
					local d = c[1] * nx + c[2] * nz
					lo, hi = math.min(lo, d), math.max(hi, d)
				end
				return lo, hi
			end
			local aLo, aHi = project(a)
			local bLo, bHi = project(b)
			local tolerance = 1e-6 * math.max(1, math.abs(nx) + math.abs(nz))
			if aHi <= bLo + tolerance or bHi <= aLo + tolerance then
				return false
			end
		end
	end
	return true
end

describe("Config.Lobby", function()
	it("gives every zone a Vector3 Offset and Size with a real footprint", function()
		for name, zone in Config.Lobby.Zones do
			if typeof(zone.Offset) ~= "Vector3" or typeof(zone.Size) ~= "Vector3" then
				error(name .. " needs a Vector3 Offset and Size")
			end
			if zone.Size.X <= 0 or zone.Size.Z <= 0 then
				error(("%s has size %s"):format(name, tostring(zone.Size)))
			end
		end
	end)

	it("keeps zones from overlapping each other", function()
		local names = {}
		for name in Config.Lobby.Zones do
			table.insert(names, name)
		end
		table.sort(names)
		-- (corners are listed around each zone: -x-z, -x+z, +x+z, +x-z)
		local quads = {}
		for _, name in names do
			local c = zoneCorners(name)
			quads[name] = { c[1], c[2], c[4], c[3] }
		end
		-- The check itself works: a zone overlaps itself, and a copy moved 1 stud overlaps it.
		local ready = quads.ReadyArea or quads[names[1]]
		expect(quadsOverlap(ready, ready)).toBe(true)
		local moved = {}
		for i, c in ready do
			moved[i] = { c[1] + 1, c[2] }
		end
		expect(quadsOverlap(ready, moved)).toBe(true)
		local far = {}
		for i, c in ready do
			far[i] = { c[1] + 1000, c[2] }
		end
		expect(quadsOverlap(ready, far)).toBe(false)
		local clashes = {}
		for i = 1, #names do
			for j = i + 1, #names do
				if quadsOverlap(quads[names[i]], quads[names[j]]) then
					table.insert(clashes, names[i] .. " / " .. names[j])
				end
			end
		end
		if #clashes > 0 then
			error("overlapping lobby zones: " .. table.concat(clashes, ", "))
		end
		T.note(#names, "zones")
	end)
end)
