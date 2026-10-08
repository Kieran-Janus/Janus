--!strict
--[[
	Server entry point. Add a new service = add its name to ORDER below (it must be a module
	in Services/ with a Start() function).
	Each service is loaded and started on its own: if one breaks, the Output window shows a
	warning with its name and the rest of the game still starts. A feature that is switched
	off in Config.Features does nothing in its Start().
]]
local Services = script.Parent:WaitForChild("Services")

-- Start order matters: earlier services are ready before later ones start.
local ORDER = {
	"SfxService", -- first: creates the sound groups the hub music uses
	"AnnounceService", -- server-wide banners (the Announce remote), used by later services
	"HubService", -- early, so the hub spawn exists before characters load
	"DataService",
	"ShopService",
	"SkinCatalogService", -- catalog items in skins (after ShopService: it re-dresses players)
	"TutorialService", -- does nothing while Config.Features.Tutorial is off
	"MonetizationService",
	"CrateService", -- after Shop and Monetization (crates grant items and take Robux)
	"RewardsService",
	"AdminService",
	"SkinStudioService", -- Skin Studio drafts (admins in Studio; after AdminService for its F8 button)
	"MapService",
	"MapVisitService", -- Studio only: F8 "Visit map" and the name finder
	"NoiseService",
	"SprintService",
	"ShoutService",
	"DanceService", -- Photo Spot dances
	"PumpkinService",
	"KingService",
	"MinionService",
	"GhostService",
	"VoiceService",
	"LeaderboardService",
	"VotingService",
	"AIService",
	"ParkourService", -- lobby extras: they work between and during rounds
	"TowerService", -- the Tormented Tower (after ParkourService: they share the course runner)
	"CandyRushService",
	"WebScourService",
	"EasterEggService",
	"ReadyService", -- before GameService: rounds take the players on the Ready pad
	"GameService", -- last: starts the round loop
}

local function report(name: string, step: string, err: unknown)
	warn(
		("[Main] %s failed to %s (the rest of the game keeps running): %s"):format(
			name,
			step,
			tostring(err)
		)
	)
end

-- Load every module first (a module that errors while loading is skipped)...
local loaded: { { Name: string, Module: any } } = {}
for _, name in ORDER do
	local moduleScript = Services:FindFirstChild(name)
	if not (moduleScript and moduleScript:IsA("ModuleScript")) then
		report(name, "load", "Services/" .. name .. " is missing")
		continue
	end
	local ok, result = xpcall(require, debug.traceback, moduleScript)
	if ok then
		table.insert(loaded, { Name = name, Module = result })
	else
		report(name, "load", result)
	end
end

-- ...then start them in order.
for _, entry in loaded do
	local start = if type(entry.Module) == "table" then entry.Module.Start else nil
	if type(start) ~= "function" then
		report(entry.Name, "start", "it has no Start() function")
		continue
	end
	local ok, err = xpcall(start, debug.traceback)
	if not ok then
		report(entry.Name, "start", err)
	end
end
