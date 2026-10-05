--!strict
--[[
	Spawn hub "Spooky Town Square".
	The hub is a Model in Workspace named "Hub". If it is missing (a fresh place built from
	git), it is built from Config by HubBuilder; if it exists (built or hand-edited in
	Studio), it is left alone. Lighting always comes from Config.Hub.Lighting.
	To rebuild after changing Config.Hub: delete Workspace.Hub in Studio, or run
	require(game.ServerScriptService.Server.Hub.HubBuilder).Build() in the command bar.

	There is only ever one hub: extra "Hub" models and loose copies of hub pieces left in
	Workspace (e.g. a hub that was ungrouped, pasted or duplicated in Studio) are removed on
	start, with a warning saying what to clean up in the saved place.
]]

local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)

local HubService = {}

function HubService.Get(): Model?
	local hub = workspace:FindFirstChild("Hub")
	return if hub and hub:IsA("Model") then hub else nil
end

-- The part on an NPC model that carries a SurfaceGui (Voting Board, Gravestone).
function HubService.Screen(npcId: string): BasePart?
	local hub = HubService.Get()
	local npcs = hub and hub:FindFirstChild("Npcs")
	local npc = npcs and npcs:FindFirstChild(npcId)
	local screen = npc and npc:FindFirstChild("Screen")
	return if screen and screen:IsA("BasePart") then screen else nil
end

-- Keeps the first "Hub" model in Workspace and destroys any others. Returns the one kept.
local function keepOneHub(): Model?
	local hubs = HubBuilder.FindHubs()
	for i = 2, #hubs do
		hubs[i]:Destroy()
	end
	if #hubs > 1 then
		warn(
			("[HubService] Removed %d extra Hub model(s) from Workspace. Delete them in Studio and save the place."):format(
				#hubs - 1
			)
		)
	end
	return hubs[1]
end

function HubService.Start()
	HubBuilder.ApplyLighting()
	local hub = keepOneHub()
	if hub then
		-- A hub saved in Studio still picks up custom NPC models (docs/CUSTOMIZE.md).
		HubBuilder.ApplyCustomNpcs(hub)
		HubBuilder.ApplyMusic(hub)
	else
		hub = HubBuilder.Build()
	end
	local loose = HubBuilder.RemoveLoosePieces(hub :: Model)
	if loose > 0 then
		warn(
			("[HubService] Removed %d loose hub piece(s) from Workspace (an ungrouped or pasted hub copy). Delete them in Studio and save the place."):format(
				loose
			)
		)
	end
	HubBuilder.DisableDefaultSpawn()
end

return HubService
