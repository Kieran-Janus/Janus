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

type LoadedMap = { Model: Model, Floor: BasePart }

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

local function findSpot(map: LoadedMap): Vector3?
	local floor = map.Floor
	local cfg = Config.Pumpkins
	local halfX = floor.Size.X / 2 - cfg.EdgeMargin
	local halfZ = floor.Size.Z / 2 - cfg.EdgeMargin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }

	for _ = 1, cfg.SpawnAttempts do
		local point = floor.CFrame
			* Vector3.new(math.random() * halfX * 2 - halfX, 0, math.random() * halfZ * 2 - halfZ)
		local top = point + Vector3.new(0, floor.Size.Y / 2, 0)
		-- Cast down from high above; only accept spots where the first thing hit is the floor.
		local result =
			workspace:Raycast(top + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
		if result and result.Instance == floor then
			return result.Position + Vector3.new(0, cfg.HoverHeight, 0)
		end
	end
	return nil
end

local function collect(pumpkin: BasePart, hit: BasePart)
	if pumpkin:GetAttribute("Collected") then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not character or not canCollect(player) then
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
end

local function spawnOne(map: LoadedMap)
	local spot = findSpot(map)
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
	pumpkin.Position = spot
	pumpkin.Touched:Connect(function(hit)
		collect(pumpkin, hit)
	end)
	pumpkin.Parent = folder
	active += 1
end

-- Starts spawning for a round. `collectable` says whether a player may pick up right now.
function PumpkinService.Begin(
	map: LoadedMap,
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
