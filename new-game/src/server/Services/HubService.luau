--!strict
--[[
	Spawn hub "Spooky Town Square".
	The hub is a Model in Workspace named "Hub". If it is missing (a fresh place built from
	git), it is built from Config by HubBuilder; if it exists (built or hand-edited in
	Studio), it is left alone. Lighting always comes from Config.Hub.Lighting.
	To rebuild after changing Config.Hub: delete Workspace.Hub in Studio, or run
	require(game.ServerScriptService.Server.Hub.HubBuilder).Build() in the command bar.
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

function HubService.Start()
	HubBuilder.ApplyLighting()
	local hub = HubService.Get()
	if hub then
		-- A hub saved in Studio still picks up custom NPC models (docs/CUSTOMIZE.md).
		HubBuilder.ApplyCustomNpcs(hub)
	else
		HubBuilder.Build()
	end
	HubBuilder.DisableDefaultSpawn()
end

return HubService
