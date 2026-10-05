-- Every ModuleScript loads, the server boots and survives a player joining and leaving, and
-- the client modules load against what the server replicated.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local function modulesUnder(rt, path: string): { any }
	local out = {}
	for _, d in rt:find(path):GetDescendants() do
		if d:IsA("ModuleScript") then
			table.insert(out, d)
		end
	end
	return out
end

-- Main.server / Main.client catch a failing service or UI and only warn "[Main] X failed to
-- ...", so the game keeps running. In tests that warning is a failure.
local function noMainFailures(rt)
	local failures = {}
	for _, text in rt.warnings do
		if text:find("[Main]", 1, true) then
			table.insert(failures, text)
		end
	end
	if #failures > 0 then
		error(table.concat(failures, "\n"), 0)
	end
end

describe("server and shared modules", function()
	local rt = Runtime.new()
	for _, path in { "ReplicatedStorage.Shared", "ServerScriptService.Server" } do
		for _, module in modulesUnder(rt, path) do
			it("requires " .. module:GetFullName(), function()
				rt:require(module)
			end)
		end
	end
end)

local server = Runtime.new()

describe("server boot", function()
	it("runs Main.server.luau", function()
		local ok, err = server:runScript("ServerScriptService.Server.Main")
		if not ok then
			error(err, 0)
		end
		server:advance(1)
		noMainFailures(server)
		expect(server.workspace:FindFirstChild("Hub")).toBeInstanceOf("Model")
		expect(server:find("ReplicatedStorage.Remotes")).toBeInstanceOf("Folder")
	end)

	it("plays a whole round with a player in it, then lets them leave", function()
		local ReplicatedStorage = server.game:GetService("ReplicatedStorage")
		local states = {}
		ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(function()
			local state = ReplicatedStorage:GetAttribute("State")
			if states[#states] ~= state then
				table.insert(states, state)
			end
		end)
		local Config = server:require("ReplicatedStorage.Shared.Config")
		local player = server:addPlayer({ Name = "Tester" })
		-- Voting + intermission + the round + results, with some slack.
		local r = Config.Round
		server:advance(
			Config.Voting.Seconds + r.IntermissionSeconds + r.Duration + r.ResultsSeconds + 30
		)
		expect(states).toContain("Playing")
		expect(states).toContain("Results")
		expect(player:GetAttribute("DataReady")).toBe(true)
		server:removePlayer(player)
		server:advance(5)
		T.note("states: " .. table.concat(states, " -> "))
		T.note(
			("%d instances made, %d connections, %d remotes, %.0f virtual seconds"):format(
				server.instanceCount,
				server.connectionCount,
				#server:find("ReplicatedStorage.Remotes"):GetChildren(),
				server:now()
			)
		)
	end)
end)

describe("client modules", function()
	local client = Runtime.new({ client = true })

	it("receives what the server replicates", function()
		client:replicateFrom(server)
		expect(client:find("ReplicatedStorage.Remotes")).toBeInstanceOf("Folder")
		expect(client.game:GetService("Players").LocalPlayer).toBeInstanceOf("Player")
	end)

	for _, module in modulesUnder(client, "StarterPlayer.StarterPlayerScripts.Client") do
		it("requires " .. module:GetFullName(), function()
			client:require(module)
		end)
	end

	it("runs Main.client.luau and builds the UI", function()
		local ok, err = client:runScript("StarterPlayer.StarterPlayerScripts.Client.Main")
		if not ok then
			error(err, 0)
		end
		client:advance(10)
		noMainFailures(client)
		local gui = client.game:GetService("Players").LocalPlayer.PlayerGui
		expect(gui:FindFirstChildOfClass("ScreenGui")).toBeInstanceOf("ScreenGui")
		local names = {}
		for _, child in gui:GetChildren() do
			table.insert(names, child.Name)
		end
		T.note("PlayerGui: " .. table.concat(names, ", "))
	end)
end)
