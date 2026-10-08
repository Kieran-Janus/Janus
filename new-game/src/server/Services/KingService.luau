--!strict
--[[
	The Pumpkin King: a server-controlled NPC that hunts players with pathfinding.

	Each tick a King picks a goal, in priority order:
	  1. Chase  - the nearest player it can see (within SightRange, clear line of sight;
	              a ghost's Haunt shrinks SightRange for a few seconds)
	  2. Listen - the loudest recent noise it can hear (NoiseService, within HearingRange)
	  3. Wander - a random spot on the floor
	A player within CatchRange is caught; GameService decides what that means.

	The placeholder body is built from parts (src/server/Build/KingBody.luau). To use your
	own King, put a Model named PumpkinKing in ReplicatedStorage.Custom.Characters
	(docs/CUSTOMIZE.md). It can be a real R15 rig (Humanoid + HumanoidRootPart, e.g. from Avatar > Rig Builder; it walks with
	Config.Custom.RigAnimations) or any plain model (it glides, welded to a hidden root).
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)
local KingBody = require(script.Parent.Parent.Build.KingBody)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapService = require(script.Parent.MapService)
local NoiseService = require(script.Parent.NoiseService)
local SfxService = require(script.Parent.SfxService)

type Level = {
	Count: number,
	WalkSpeed: number,
	ChaseSpeed: number,
	HearingRange: number,
	SightRange: number,
}

type King = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Thread: thread?,
}

local KingService = {}

local kings: { King } = {}
local lastHeard: { [Player]: number } = {}
local kingHeard: RemoteEvent

local spawnThread: thread? = nil
local catchConnection: RBXScriptConnection? = nil

local function weld(part: BasePart, root: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function setCollisionGroup(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "King"
		end
	end
end

local function setupHumanoid(humanoid: Humanoid)
	humanoid.DisplayName = Config.King.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
end

-- Walk/idle animations for a custom R15 rig (plain models have nothing to animate).
local function animateRig(humanoid: Humanoid)
	local ids = Config.Custom.RigAnimations
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id: string): AnimationTrack?
		if id == "" then
			return nil
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		return if ok then track else nil
	end
	local walk = load(ids.Walk)
	local idle = load(ids.Idle)
	if walk then
		walk.Looped = true
		walk.Priority = Enum.AnimationPriority.Movement
	end
	if idle then
		idle.Looped = true
		idle.Priority = Enum.AnimationPriority.Idle
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not walk then
			return
		end
		if speed > 0.5 and not walk.IsPlaying then
			walk:Play(0.2)
			if idle then
				idle:Stop(0.2)
			end
		elseif speed <= 0.5 and walk.IsPlaying then
			walk:Stop(0.2)
			if idle then
				idle:Play(0.2)
			end
		end
	end)
end

local function buildCustomKing(model: Model, position: Vector3): King
	local cfg = Config.King
	model.Name = "PumpkinKing"
	CustomAssets.Fit(model, Config.Custom.Heights.PumpkinKing)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		-- A real rig: it already knows how to stand and walk.
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				if part ~= root then
					part.CanCollide = false
				end
			end
		end
		model.PrimaryPart = root
		model:PivotTo(CFrame.new(position) * root.CFrame.Rotation)
		setupHumanoid(humanoid)
		-- Animations can only load once the model is in the game: KingService.Begin.
		model:SetAttribute("AnimatedRig", true)
	else
		-- A Humanoid without a HumanoidRootPart can't walk; replace it with ours.
		if humanoid then
			humanoid:Destroy()
		end
		-- A plain model: weld it to a hidden root, like the placeholder body.
		local feet = CustomAssets.Origin(model, "Feet")
		local newRoot = Instance.new("Part")
		newRoot.Name = "HumanoidRootPart"
		newRoot.Size = Vector3.new(2, 2, 1)
		newRoot.Transparency = 1
		newRoot.CFrame = feet * CFrame.new(0, cfg.HipHeight + 1, 0)
		newRoot.Parent = model
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= newRoot then
				weld(part, newRoot, newRoot.CFrame:ToObjectSpace(part.CFrame))
			end
		end
		model.PrimaryPart = newRoot
		model:PivotTo(CFrame.new(position) * feet.Rotation)
		local h = Instance.new("Humanoid")
		h.HipHeight = cfg.HipHeight
		h.RigType = Enum.HumanoidRigType.R15
		h.RequiresNeck = false
		setupHumanoid(h)
		h.Parent = model
		humanoid = h
		root = newRoot
	end
	setCollisionGroup(model)
	return {
		Model = model,
		Humanoid = humanoid :: Humanoid,
		Root = root :: BasePart,
		Thread = nil,
	}
end

local function buildKing(position: Vector3): King
	local custom = CustomAssets.Clone("Characters", "PumpkinKing")
	if custom then
		return buildCustomKing(custom, position)
	end
	local model, humanoid, root = KingBody.Build(position)
	setCollisionGroup(model)
	return { Model = model, Humanoid = humanoid, Root = root, Thread = nil }
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid.RootPart
	end
	return nil
end

-- "THE KING HEARD YOU!" for the noisy player, "The King heard X!" for players nearby.
local function announceHeard(king: King, player: Player)
	local cfg = Config.King.Heard
	local now = os.clock()
	if player.Parent ~= Players or now - (lastHeard[player] or -math.huge) < cfg.Cooldown then
		return
	end
	lastHeard[player] = now
	kingHeard:FireClient(player, true, player.DisplayName)
	local root = rootOf(player)
	if root then
		for _, other in Players:GetPlayers() do
			local otherRoot = rootOf(other)
			if
				other ~= player
				and otherRoot
				and (otherRoot.Position - root.Position).Magnitude <= cfg.NearbyRadius
			then
				kingHeard:FireClient(other, false, player.DisplayName)
			end
		end
	end
	SfxService.Play3D({
		SoundId = cfg.RoarSoundId,
		Volume = cfg.RoarVolume,
		PitchMin = cfg.RoarPitch,
		RollOffMin = 20,
		RollOffMax = 200,
	}, king.Root)
end

local function canSee(king: King, target: BasePart, range: number): boolean
	local origin = king.Root.Position + Vector3.new(0, Config.King.BodySize.Y, 0)
	local offset = target.Position - origin
	if offset.Magnitude > range then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { king.Model }
	for _, other in kings do
		table.insert(ignore, other.Model)
	end
	params.FilterDescendantsInstances = ignore
	params.CollisionGroup = "King" -- ghosts don't collide with the King, so they don't block its view
	local hit = workspace:Raycast(origin, offset, params)
	return hit ~= nil
		and target.Parent ~= nil
		and hit.Instance:IsDescendantOf(target.Parent :: Instance)
end

-- Follows a path toward `goal` for up to `budget` seconds. Returns false if no progress.
local function walkTo(king: King, goal: Vector3, budget: number): boolean
	local cfg = Config.King
	local path = PathfindingService:CreatePath(cfg.Path)
	local ok = pcall(function()
		path:ComputeAsync(king.Root.Position, goal)
	end)
	local deadline = os.clock() + budget
	local start = king.Root.Position

	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- No path (goal inside a prop, mid-air, ...): step straight at it briefly.
		king.Humanoid:MoveTo(goal)
		task.wait(math.min(budget, 0.5))
		return (king.Root.Position - start).Magnitude > 1
	end

	-- Waypoints are on the floor but the root floats at HipHeight, so compare flat distance.
	local function flatDistance(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	local waypoints = path:GetWaypoints()
	for i = 2, #waypoints do
		if os.clock() > deadline then
			break
		end
		local target = waypoints[i].Position
		king.Humanoid:MoveTo(target)
		local stuckSince = os.clock()
		local last = king.Root.Position
		while
			flatDistance(king.Root.Position, target) > cfg.WaypointReachedDistance
			and os.clock() < deadline
		do
			task.wait(0.1)
			if (king.Root.Position - last).Magnitude > 0.5 then
				last = king.Root.Position
				stuckSince = os.clock()
			elseif os.clock() - stuckSince > cfg.StuckSeconds then
				return false
			end
		end
	end
	return true
end

local function think(
	king: King,
	level: Level,
	isTarget: (Player) -> boolean,
	map: MapService.LoadedMap
)
	local cfg = Config.King
	while king.Model.Parent do
		-- A haunted King sees less far for a moment.
		local sight = level.SightRange
		if (king.Model:GetAttribute("HauntedUntil") or 0) > os.clock() then
			sight *= Config.Ghost.Haunt.SightMultiplier
		end

		-- 1. Chase the nearest visible player.
		local chase: BasePart? = nil
		local chased: Player? = nil
		local nearest = math.huge
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and isTarget(player) then
				local distance = (root.Position - king.Root.Position).Magnitude
				if distance < nearest and canSee(king, root, sight) then
					chase, chased, nearest = root, player, distance
				end
			end
		end
		-- Who it's chasing (0 = nobody); clients use it for the heartbeat warning.
		king.Model:SetAttribute("TargetUserId", if chased then chased.UserId else 0)

		if chase then
			king.Humanoid.WalkSpeed = level.ChaseSpeed
			king.Model:SetAttribute("Mode", "Chase")
			walkTo(king, chase.Position, cfg.RepathSeconds)
		else
			-- 2. Investigate the loudest noise, 3. or wander.
			king.Humanoid.WalkSpeed = level.WalkSpeed
			local noise = NoiseService.Loudest(king.Root.Position, level.HearingRange)
			local goal: Vector3? = if noise then noise.Position else nil
			if noise and noise.Player and isTarget(noise.Player) then
				announceHeard(king, noise.Player)
			end
			king.Model:SetAttribute("Mode", if goal then "Listen" else "Wander")
			if not goal then
				goal = MapService.RandomFloorPoint(map, cfg.Path.AgentRadius * 2, 10, 0)
			end
			if goal then
				walkTo(king, goal, cfg.WanderRepathSeconds)
			else
				task.wait(cfg.RepathSeconds)
			end
		end
	end
end

local function spawnPoint(map: MapService.LoadedMap): Vector3?
	local cfg = Config.King
	local best: Vector3? = nil
	local bestDistance = -1
	for _ = 1, 20 do
		local point =
			MapService.RandomFloorPoint(map, cfg.Path.AgentRadius * 2, 10, cfg.HipHeight + 1)
		if point then
			local closest = math.huge
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root then
					closest = math.min(closest, (root.Position - point).Magnitude)
				end
			end
			if closest >= cfg.MinSpawnDistance then
				return point
			elseif closest > bestDistance then
				best, bestDistance = point, closest
			end
		end
	end
	return best -- small map: the farthest spot found
end

--[[
	Starts the hunt for a round. Kings appear after Config.King.SpawnDelay.
	`isTarget(player)` says who can be chased/caught; `onCatch(player)` is called once per catch
	(isTarget should return false for that player afterwards).
]]
function KingService.Begin(
	map: MapService.LoadedMap,
	difficultyId: string,
	isTarget: (Player) -> boolean,
	onCatch: (Player) -> ()
)
	KingService.Stop()
	local level: Level = Config.King.Difficulty[difficultyId]
	-- Ghosts are never targets, whatever the caller says.
	local callerTarget = isTarget
	isTarget = function(player: Player): boolean
		return not player:GetAttribute("Out") and callerTarget(player)
	end
	ReplicatedStorage:SetAttribute("KingCount", 0)

	local function tryCatch(player: Player)
		if isTarget(player) and rootOf(player) then
			onCatch(player)
		end
	end

	spawnThread = task.delay(Config.King.SpawnDelay, function()
		spawnThread = nil
		for _ = 1, level.Count do
			local point = spawnPoint(map)
			if point then
				local king = buildKing(point)
				king.Model.Parent = map.Model
				if king.Model:GetAttribute("AnimatedRig") then
					animateRig(king.Humanoid)
				end
				king.Root:SetNetworkOwner(nil) -- server physics, so clients can't move it
				SfxService.StartFootsteps(king.Model, king.Root)
				-- Touching any part of the King catches, as well as the CatchRange check below.
				for _, part in king.Model:GetDescendants() do
					if part:IsA("BasePart") then
						part.Touched:Connect(function(hit)
							local character = hit:FindFirstAncestorOfClass("Model")
							local player = character and Players:GetPlayerFromCharacter(character)
							if player then
								tryCatch(player)
							end
						end)
					end
				end
				king.Thread = task.spawn(think, king, level, isTarget, map)
				table.insert(kings, king)
			end
		end
		ReplicatedStorage:SetAttribute("KingCount", #kings)
	end)

	catchConnection = RunService.Heartbeat:Connect(function()
		for _, king in kings do
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if
					root
					and (root.Position - king.Root.Position).Magnitude <= Config.King.CatchRange
				then
					tryCatch(player)
				end
			end
		end
	end)
end

function KingService.Stop()
	if spawnThread then
		task.cancel(spawnThread)
		spawnThread = nil
	end
	if catchConnection then
		catchConnection:Disconnect()
		catchConnection = nil
	end
	for _, king in kings do
		if king.Thread then
			task.cancel(king.Thread)
		end
		king.Model:Destroy()
	end
	table.clear(kings)
	ReplicatedStorage:SetAttribute("KingCount", 0)
end

--[[
	A ghost haunts from `position`: every King within Haunt.Range has its sight reduced for
	Haunt.Seconds. Returns how many Kings were affected (0 = too far, nothing happened).
]]
function KingService.Haunt(position: Vector3): number
	local cfg = Config.Ghost.Haunt
	local affected = 0
	for _, king in kings do
		if (king.Root.Position - position).Magnitude <= cfg.Range then
			king.Model:SetAttribute("HauntedUntil", os.clock() + cfg.Seconds)
			affected += 1
		end
	end
	return affected
end

-- Where the nearest King to `position` is, or nil if none is out yet (VIP tracker).
function KingService.Nearest(position: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, king in kings do
		local distance = (king.Root.Position - position).Magnitude
		if king.Model.Parent and distance < bestDistance then
			best, bestDistance = king.Root.Position, distance
		end
	end
	return best
end

function KingService.Start()
	kingHeard = Remotes.Event("KingHeard")
	Players.PlayerRemoving:Connect(function(player)
		lastHeard[player] = nil
	end)
end

return KingService
