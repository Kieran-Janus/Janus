-- Config sanity: ids, slots, prices and references between sections line up.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
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

	it("prices every item with a whole, non-negative number", function()
		for _, item in Config.Shop.Items do
			if type(item.Price) ~= "number" or item.Price < 0 or item.Price % 1 ~= 0 then
				error(("%s has Price %s"):format(item.Id, tostring(item.Price)))
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
	it("gives every NPC an Id, a Kind and a Vector3 Offset", function()
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
			expect(npc.Offset).toBeA("Vector3")
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
end)
