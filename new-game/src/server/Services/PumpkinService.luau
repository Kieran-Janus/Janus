--!strict
--[[
	Spawns pumpkins on the round map and handles pickups.
	Pickup is a server-side Touched check (no remote): the server decides who may collect,
	checks distance, and counts each pumpkin once. A player's count for the current round
	is the "Pumpkins" attribute on the Player, which the HUD reads.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local NoiseService = require(script.Parent.NoiseService)

local PumpkinService = {}

local folder: Folder? = nil
local spawnThread: thread? = nil
local active = 0
local function nobody(_player: Player): boolean
	return false
end
local canCollect: (Player) -> boolean = nobody

function PumpkinService.GetCount(player: Player): number
	return player:GetAttribute("Pumpkins") or 0
end

local function collect(pumpkin: BasePart, hit: BasePart)
	if pumpkin:GetAttribute("Collected") then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not character or player:GetAttribute("Out") or not canCollect(player) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	if (root.Position - pumpkin.Position).Magnitude > Config.Pumpkins.PickupRange then
		return
	end

	pumpkin:SetAttribute("Collected", true)
	active -= 1
	pumpkin:Destroy()
	player:SetAttribute("Pumpkins", PumpkinService.GetCount(player) + Config.Pumpkins.Value)
	NoiseService.Report(pumpkin.Position, Config.King.Noise.PumpkinPickup, player)
end

local function spawnOne(map: MapService.LoadedMap)
	local spot = MapService.RandomFloorPoint(
		map,
		Config.Pumpkins.EdgeMargin,
		Config.Pumpkins.SpawnAttempts,
		Config.Pumpkins.HoverHeight
	)
	if not spot or not folder then
		return
	end
	local cfg = Config.Pumpkins
	local pumpkin = Instance.new("Part")
	pumpkin.Name = "Pumpkin"
	pumpkin.Shape = Enum.PartType.Ball
	pumpkin.Size = Vector3.one * cfg.Size
	pumpkin.Color = cfg.Color
	pumpkin.Material = Enum.Material.SmoothPlastic
	pumpkin.Anchored = true
	pumpkin.CanCollide = false
	pumpkin.CanQuery = false -- don't block the King's line of sight or floor raycasts
	pumpkin.Position = spot
	pumpkin.Touched:Connect(function(hit)
		collect(pumpkin, hit)
	end)
	pumpkin.Parent = folder
	active += 1
end

-- Starts spawning for a round. `collectable` says whether a player may pick up right now.
function PumpkinService.Begin(
	map: MapService.LoadedMap,
	difficultyId: string,
	collectable: (Player) -> boolean
)
	PumpkinService.Stop()
	local level = Config.Difficulty.Levels[difficultyId]
	canCollect = collectable
	active = 0

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Pumpkins"
	newFolder.Parent = map.Model
	folder = newFolder

	for _ = 1, level.PumpkinsAtStart do
		spawnOne(map)
	end
	spawnThread = task.spawn(function()
		while true do
			task.wait(level.SpawnInterval)
			if active < level.MaxPumpkins then
				spawnOne(map)
			end
		end
	end)
end

function PumpkinService.Stop()
	if spawnThread then
		task.cancel(spawnThread)
		spawnThread = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	canCollect = nobody
	active = 0
end

function PumpkinService.ResetCounts()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Pumpkins", 0)
	end
end

function PumpkinService.Start()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Pumpkins", 0)
	end)
end

return PumpkinService
