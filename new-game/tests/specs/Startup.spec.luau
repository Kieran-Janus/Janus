-- The start-up lists in Main.server.luau / Main.client.luau name real modules, and the v2
-- placeholder modules load and start with their feature switched on or off.
-- (modules.spec boots both Main scripts for real.)

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

-- The quoted names inside `local ORDER = { ... }` of a Main script.
local function orderOf(source: string): { string }
	local block = source:match("local ORDER = (%b{})")
	assert(block, "no ORDER list found")
	local names = {}
	for name in block:gmatch('"(%w+)"') do
		table.insert(names, name)
	end
	return names
end

local function checkUnique(order: { string }, folder: any, where: string)
	local seen = {}
	for _, name in order do
		if seen[name] then
			error(name .. " is listed twice")
		end
		seen[name] = true
		local module = folder:FindFirstChild(name)
		if not (module and module:IsA("ModuleScript")) then
			error(("%s is in ORDER but %s%s.luau doesn't exist"):format(name, where, name))
		end
	end
end

-- Runs fn with Config.Features[feature] set to false, then true, then puts it back.
local function withFeature(Config, feature: string, fn: () -> ())
	local saved = Config.Features[feature]
	local ok, err = pcall(function()
		for _, on in { false, true } do
			Config.Features[feature] = on
			fn()
		end
	end)
	Config.Features[feature] = saved
	if not ok then
		error(("%s (feature %s)"):format(tostring(err), feature), 0)
	end
end

describe("Main.server.luau", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local services = rt:find("ServerScriptService.Server.Services")
	local order = orderOf(rt:source("ServerScriptService.Server.Main"))

	it("starts every service in ORDER, once each", function()
		checkUnique(order, services, "Services/")
		for _, name in { "ReadyService", "CrateService", "ParkourService", "EasterEggService" } do
			expect(order).toContain(name)
		end
	end)

	it("starts the Ready pad and crates in the right place", function()
		expect(order[#order]).toBe("GameService")
		expect(table.find(order, "ReadyService")).toBeLessThan(table.find(order, "GameService"))
		expect(table.find(order, "CrateService")).toBeGreaterThan(
			table.find(order, "MonetizationService")
		)
	end)

	local stubs = {
		ReadyService = "ReadyPad",
		ParkourService = "Parkour",
		CandyRushService = "CandyRush",
		WebScourService = "WebScour",
		EasterEggService = "EasterEggs",
		CrateService = "Crates",
	}
	for name, feature in stubs do
		it(("starts %s with %s off and on"):format(name, feature), function()
			local service = rt:require(services:FindFirstChild(name))
			withFeature(Config, feature, function()
				service.Start()
			end)
		end)
	end

	it("has nobody ready with no players", function()
		expect(#rt:require(services.ReadyService).List()).toBe(0)
	end)
end)

describe("Main.client.luau", function()
	local client = Runtime.new({ client = true })
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local folder = client:find("StarterPlayer.StarterPlayerScripts.Client")
	local order = orderOf(client:source(folder.Main))

	it("mounts every module in ORDER, once each, the Menu first", function()
		checkUnique(order, folder, "src/client/")
		expect(order[1]).toBe("MenuUI")
	end)

	-- (Spectate is real now and needs the server's remotes: modules.spec mounts it against a
	-- replicated server, and Rounds.spec tests the Ready pad and playlist logic.)
	local stubs = {
		MenuUI = "Menu",
		CrateUI = "Crates",
		ParkourUI = "Parkour",
		CandyRushUI = "CandyRush",
		WebScourUI = "WebScour",
		EasterEggUI = "EasterEggs",
		HideSeekUI = "HideSeek",
		ScareMazeUI = "ScareMaze",
	}
	for name, feature in stubs do
		it(("mounts %s with %s off and on"):format(name, feature), function()
			local module = client:require(folder:FindFirstChild(name))
			local gui = client:create("ScreenGui", { Name = "TestGui" })
			withFeature(Config, feature, function()
				module.Mount(gui)
			end)
		end)
	end

	it("answers the Menu's calls", function()
		local CrateUI = client:require(folder.CrateUI)
		CrateUI.Open("PumpkinCrate")
		CrateUI.Open(nil)
		local found, total = client:require(folder.EasterEggUI).Progress()
		expect(found).toBe(0)
		expect(total).toBe(#Config.EasterEggs.List)
	end)
end)
