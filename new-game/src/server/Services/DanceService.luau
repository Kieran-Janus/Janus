--!strict
--[[
	Photo Spot dances (Config.Dances; on/off: Config.Features.Dances).

	The client sends Dance(id) from the Photo Spot's dance bar (id "" = stop). The server
	checks the id is in Config.Dances.List, the cooldown, and that the player stands within
	Config.Hub.PhotoSpot.CloseDistance of the Photo Spot (tag PhotoSpot), then sets the
	attribute Dance = id on the character. Every client animates characters with a Dance
	attribute (client Dances.luau), so everyone sees it.
	The dance stops (attribute cleared) when the player drifts more than MaxDrift studs from
	where they started, jumps or falls, dies or respawns.

	DanceService.Set(player, id) -> (ok, reason?)   the same checks, for tests and admin
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local DanceService = {}

local cfg = Config.Dances
local lastChange: { [Player]: number } = {}
local startedAt: { [Player]: Vector3 } = {}

local function isDance(id: string): boolean
	for _, dance in cfg.List do
		if dance.Id == id then
			return true
		end
	end
	return false
end

-- The Photo Spot parts: tagged PhotoSpot, or (a hub saved before the tag) the part holding
-- the prompt with NpcId "PhotoSpot".
local function photoSpots(): { BasePart }
	local list: { BasePart } = {}
	for _, tagged in CollectionService:GetTagged(Tags.PhotoSpot) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(workspace) then
			table.insert(list, tagged)
		end
	end
	if #list == 0 then
		for _, d in workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") and d:GetAttribute("NpcId") == "PhotoSpot" then
				local parent = d.Parent
				if parent and parent:IsA("BasePart") then
					table.insert(list, parent)
				end
			end
		end
	end
	return list
end

local function rootOf(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return character, humanoid.RootPart
end

local function stop(player: Player)
	startedAt[player] = nil
	local character = player.Character
	if character and character:GetAttribute("Dance") ~= nil then
		character:SetAttribute("Dance", nil)
	end
end

function DanceService.Set(player: Player, id: unknown): (boolean, string?)
	if not Config.Features.Dances then
		return false, "Off"
	end
	if type(id) ~= "string" or #id > 40 then
		return false, "BadId"
	end
	if id == "" then
		stop(player)
		return true, nil
	end
	if not isDance(id) then
		return false, "BadId"
	end
	local now = os.clock()
	if now - (lastChange[player] or -math.huge) < cfg.Cooldown then
		return false, "TooSoon"
	end
	local character, root = rootOf(player)
	if not character or not root then
		return false, "NoCharacter"
	end
	local near = false
	for _, spot in photoSpots() do
		if (spot.Position - root.Position).Magnitude <= Config.Hub.PhotoSpot.CloseDistance then
			near = true
			break
		end
	end
	if not near then
		return false, "TooFar"
	end
	lastChange[player] = now
	startedAt[player] = root.Position
	character:SetAttribute("Dance", id)
	return true, nil
end

-- Stops dances whose dancer walked off, jumped, fell or died.
local function check()
	for player, start in startedAt do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not character or not humanoid or not root or humanoid.Health <= 0 then
			stop(player)
			continue
		end
		local state = humanoid:GetState()
		local airborne = state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
		if airborne or (root.Position - start).Magnitude > cfg.MaxDrift then
			stop(player)
		end
	end
end

function DanceService.Start()
	-- The remote exists even while dances are off (the client may look for it).
	local remote = Remotes.Event("Dance")
	if not Config.Features.Dances then
		return
	end
	remote.OnServerEvent:Connect(function(player: Player, id: unknown)
		DanceService.Set(player, id)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			check()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			startedAt[player] = nil
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			startedAt[player] = nil
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
		startedAt[player] = nil
	end)
end

return DanceService
