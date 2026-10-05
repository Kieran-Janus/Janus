--!strict
-- The start-up lists in Main.server.luau / Main.client.luau name real modules, and the v2
-- placeholder modules load and start with their feature switched on or off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

return function(t: any)
	local Config = require(ReplicatedStorage.Shared.Config) :: any

	t.test("every server service in ORDER exists once", function()
		local source = t.readFile("src/server/Main.server.luau")
		t.ok(source, "Main.server.luau")
		local seen = {}
		for _, name in orderOf(source) do
			t.ok(not seen[name], name .. " is listed twice")
			seen[name] = true
			local module = t.Server.Services:FindFirstChild(name)
			t.ok(module and module:IsA("ModuleScript"), "Services/" .. name .. ".luau")
		end
		for _, name in { "ReadyService", "CrateService", "ParkourService", "EasterEggService" } do
			t.ok(seen[name], name .. " is started")
		end
		local order = orderOf(source)
		t.eq(order[#order], "GameService", "GameService starts last")
		t.ok(table.find(order, "ReadyService") < table.find(order, "GameService"))
		t.ok(table.find(order, "CrateService") > table.find(order, "MonetizationService"))
	end)

	t.test("every client module in ORDER exists once", function()
		local source = t.readFile("src/client/Main.client.luau")
		t.ok(source, "Main.client.luau")
		local order = orderOf(source)
		local seen = {}
		for _, name in order do
			t.ok(not seen[name], name .. " is listed twice")
			seen[name] = true
			local module = t.Client:FindFirstChild(name)
			t.ok(module and module:IsA("ModuleScript"), "src/client/" .. name .. ".luau")
		end
		t.eq(order[1], "MenuUI", "the Menu mounts first")
	end)

	-- Placeholder modules: name -> feature switch.
	local serverStubs = {
		ReadyService = "ReadyPad",
		ParkourService = "Parkour",
		CandyRushService = "CandyRush",
		WebScourService = "WebScour",
		EasterEggService = "EasterEggs",
		CrateService = "Crates",
	}
	local clientStubs = {
		MenuUI = "Menu",
		Spectate = "LobbySpectate",
		CrateUI = "Crates",
		ParkourUI = "Parkour",
		CandyRushUI = "CandyRush",
		WebScourUI = "WebScour",
		EasterEggUI = "EasterEggs",
		HideSeekUI = "HideSeek",
		ScareMazeUI = "ScareMaze",
	}

	t.test("placeholder services start with their feature on and off", function()
		for name, feature in serverStubs do
			local service = require(t.Server.Services[name]) :: any
			local saved = Config.Features[feature]
			for _, on in { false, true } do
				Config.Features[feature] = on
				service.Start()
			end
			Config.Features[feature] = saved
		end
		local ReadyService = require(t.Server.Services.ReadyService) :: any
		t.eq(#ReadyService.List(), 0, "no players in tests")
	end)

	t.test("placeholder UIs mount with their feature on and off", function()
		for name, feature in clientStubs do
			local module = require(t.Client[name]) :: any
			local saved = Config.Features[feature]
			for _, on in { false, true } do
				Config.Features[feature] = on
				module.Mount(nil)
			end
			Config.Features[feature] = saved
		end
		local Spectate = require(t.Client.Spectate) :: any
		Spectate.Toggle()
		Spectate.Stop()
		t.eq(Spectate.IsActive(), false)
		local CrateUI = require(t.Client.CrateUI) :: any
		CrateUI.Open("PumpkinCrate")
		CrateUI.Open(nil)
		local EasterEggUI = require(t.Client.EasterEggUI) :: any
		local found, total = EasterEggUI.Progress()
		t.eq(found, 0)
		t.eq(total, #Config.EasterEggs.List)
	end)
end
