--!strict
--[[
	Minion monsters (Config.Monsters) that make the round maps feel alive:
	  Skeleton Patrol - slow, walks back and forth on a fixed straight route. Bumping into it
	                    slows you, knocks you back and rattles (noise the King hears).
	  Bat Swarm       - circles its roost; darts in zig-zags at a player it can see nearby,
	                    but gives up after a short distance. A hit slows you and screeches.
	  Ghost Cat       - drifts through walls and stalks players carrying pumpkins. A touch
	                    steals one, which reappears somewhere on the map a few seconds later.
	Minions never catch anyone. The server moves them (anchored parts, one BulkMoveTo per
	frame) and decides every hit; ghosts are ignored. The hit player's client gets a
	MinionHit(kind, push) event for the on-screen message and the knockback.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapService = require(script.Parent.MapService)
local NoiseService = require(script.Parent.NoiseService)
local PumpkinService = require(script.Parent.PumpkinService)
local SprintService = require(script.Parent.SprintService)

-- One part of a minion's body, posed relative to the minion's root CFrame every frame.
type Piece = {
	Part: BasePart,
	Joint: CFrame, -- root -> joint
	Offset: CFrame, -- joint -> part centre
	Swing: { Axis: Vector3, Amp: number, Speed: number, Phase: number }?,
}

type Body = { Model: Model, Pieces: { Piece } }

type Minion = {
	Kind: string,
	Bodies: { Body },
	Root: CFrame,
	Moving: boolean,
	State: string,
	-- Skeleton
	A: Vector3?,
	B: Vector3?,
	ToB: boolean?,
	PauseUntil: number?,
	-- Bats
	Home: Vector3?,
	Base: Vector3?,
	Target: Player?,
	RestUntil: number?,
	-- Cat
	Goal: Vector3?,
	FleeFrom: Vector3?,
	FleeUntil: number?,
}

local MinionService = {}

local minions: { Minion } = {}
local folder: Folder? = nil
local spawnThread: thread? = nil
local heartbeat: RBXScriptConnection? = nil
local lastHit: { [Player]: number } = {}
local minionHit: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid.RootPart
	end
	return nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Body building -------------------------------------------------------------------------------

local function piece(
	body: Body,
	props: { [string]: any },
	joint: CFrame,
	offset: CFrame?,
	swing: { Axis: Vector3, Amp: number, Speed: number, Phase: number }?
): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = body.Model
	table.insert(
		body.Pieces,
		{ Part = p, Joint = joint, Offset = offset or CFrame.identity, Swing = swing }
	)
	return p
end

local function newBody(name: string, parent: Instance): Body
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return { Model = m, Pieces = {} }
end

-- Feet at the root; faces the root's LookVector.
local function buildSkeleton(parent: Instance): Body
	local cfg = Config.Monsters.SkeletonPatrol
	local body = newBody("SkeletonPatrol", parent)
	piece(
		body,
		{ Name = "Pelvis", Size = Vector3.new(1.6, 0.5, 0.8), Color = cfg.Color },
		CFrame.new(0, 2.6, 0)
	)
	piece(
		body,
		{ Name = "Ribs", Size = Vector3.new(1.8, 1.8, 0.9), Color = cfg.Color },
		CFrame.new(0, 3.9, 0)
	)
	piece(body, {
		Name = "Skull",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		Color = cfg.Color,
	}, CFrame.new(0, 5.5, 0))
	for _, side in { -1, 1 } do
		piece(body, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.35,
			Color = cfg.EyeColor,
			Material = Enum.Material.Neon,
		}, CFrame.new(side * 0.32, 5.6, -0.68))
		local legPhase = if side < 0 then 0 else math.pi
		piece(
			body,
			{ Name = "Leg", Size = Vector3.new(0.35, 2.5, 0.35), Color = cfg.Color },
			CFrame.new(side * 0.5, 2.5, 0),
			CFrame.new(0, -1.25, 0),
			{ Axis = Vector3.xAxis, Amp = 0.5, Speed = 7, Phase = legPhase }
		)
		piece(
			body,
			{ Name = "Arm", Size = Vector3.new(0.3, 2.2, 0.3), Color = cfg.Color },
			CFrame.new(side * 1.15, 4.6, 0),
			CFrame.new(0, -1.1, 0),
			{ Axis = Vector3.xAxis, Amp = 0.6, Speed = 7, Phase = legPhase + math.pi }
		)
	end
	return body
end

local function buildBat(parent: Instance): Body
	local cfg = Config.Monsters.BatSwarm
	local body = newBody("Bat", parent)
	piece(body, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		Color = cfg.Color,
	}, CFrame.identity)
	for _, side in { -1, 1 } do
		piece(body, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.2,
			Color = cfg.EyeColor,
			Material = Enum.Material.Neon,
		}, CFrame.new(side * 0.18, 0.12, -0.4))
		piece(
			body,
			{ Name = "Wing", Size = Vector3.new(1.6, 0.1, 0.8), Color = cfg.Color },
			CFrame.new(side * 0.35, 0, 0),
			CFrame.new(side * 0.8, 0, 0),
			{ Axis = Vector3.zAxis, Amp = 0.8 * side, Speed = 20, Phase = 0 }
		)
	end
	return body
end

-- Paws at the root; faces the root's LookVector.
local function buildCat(parent: Instance): Body
	local cfg = Config.Monsters.GhostCat
	local body = newBody("GhostCat", parent)
	local fur =
		{ Color = cfg.Color, Transparency = cfg.Transparency, Material = Enum.Material.Neon }
	local function with(extra: { [string]: any }): { [string]: any }
		local t = table.clone(fur)
		for k, v in extra do
			t[k] = v
		end
		return t
	end
	local torso = piece(
		body,
		with({ Name = "Body", Size = Vector3.new(1.3, 1.2, 2.4) }),
		CFrame.new(0, 1.1, 0)
	)
	piece(
		body,
		with({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4 }),
		CFrame.new(0, 1.9, -1.4)
	)
	for _, side in { -1, 1 } do
		piece(
			body,
			with({ Name = "Ear", Size = Vector3.new(0.45, 0.6, 0.15) }),
			CFrame.new(side * 0.38, 2.6, -1.4) * CFrame.Angles(0, 0, math.rad(-side * 20))
		)
		piece(body, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.28,
			Color = cfg.EyeColor,
			Material = Enum.Material.Neon,
		}, CFrame.new(side * 0.3, 2, -2.05))
		for _, z in { -0.8, 0.8 } do
			piece(
				body,
				with({ Name = "Leg", Size = Vector3.new(0.3, 0.9, 0.3) }),
				CFrame.new(side * 0.45, 0.6, z),
				CFrame.new(0, -0.35, 0),
				{
					Axis = Vector3.xAxis,
					Amp = 0.4,
					Speed = 9,
					Phase = if side * z > 0 then 0 else math.pi,
				}
			)
		end
	end
	piece(
		body,
		with({ Name = "Tail", Size = Vector3.new(0.25, 1.8, 0.25) }),
		CFrame.new(0, 1.4, 1.2) * CFrame.Angles(math.rad(-30), 0, 0),
		CFrame.new(0, 0.9, 0),
		{ Axis = Vector3.zAxis, Amp = 0.5, Speed = 3, Phase = 0 }
	)
	local glow = Instance.new("PointLight")
	glow.Color = cfg.Color
	glow.Range = 10
	glow.Brightness = 0.8
	glow.Shadows = false
	glow.Parent = torso
	return body
end

-- Placement ---------------------------------------------------------------------------------

local function mapParams(map: MapService.LoadedMap): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }
	return params
end

local function floorTop(map: MapService.LoadedMap): number
	return map.Floor.Position.Y + map.Floor.Size.Y / 2
end

-- Keeps a point inside the walls.
local function clampToMap(map: MapService.LoadedMap, point: Vector3, margin: number): Vector3
	local local_ = map.Floor.CFrame:PointToObjectSpace(point)
	local hx, hz = map.Floor.Size.X / 2 - margin, map.Floor.Size.Z / 2 - margin
	return map.Floor.CFrame:PointToWorldSpace(
		Vector3.new(math.clamp(local_.X, -hx, hx), local_.Y, math.clamp(local_.Z, -hz, hz))
	)
end

-- A floor point far from every player (best effort), `height` above the floor.
local function spawnPoint(map: MapService.LoadedMap, height: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = -1
	for _ = 1, 20 do
		local point = MapService.RandomFloorPoint(map, 8, 10, height)
		if point then
			local closest = math.huge
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root then
					closest = math.min(closest, (root.Position - point).Magnitude)
				end
			end
			if closest >= Config.Monsters.MinSpawnDistance then
				return point
			elseif closest > bestDistance then
				best, bestDistance = point, closest
			end
		end
	end
	return best
end

-- A straight, clear patrol route starting at `a`, or nil if every direction is blocked.
local function patrolRoute(map: MapService.LoadedMap, a: Vector3): Vector3?
	local cfg = Config.Monsters.SkeletonPatrol
	local params = mapParams(map)
	for _ = 1, 16 do
		local angle = math.random() * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = cfg.RouteMin + math.random() * (cfg.RouteMax - cfg.RouteMin)
		local hit = workspace:Spherecast(a + Vector3.new(0, 3, 0), 1.5, dir * length, params)
		local reach = if hit then hit.Distance - 2 else length
		if reach >= cfg.RouteMin then
			local b = clampToMap(map, a + dir * reach, 6)
			if (b - a).Magnitude >= cfg.RouteMin then
				return b
			end
		end
	end
	return nil
end

-- Hits --------------------------------------------------------------------------------------

local function hit(player: Player, minion: Minion, at: Vector3): boolean
	local cfg = Config.Monsters
	local now = os.clock()
	if now - (lastHit[player] or -math.huge) < cfg.HitCooldown then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local kind = minion.Kind
	local push = Vector3.zero
	if kind == "SkeletonPatrol" then
		local s = cfg.SkeletonPatrol
		SprintService.Slow(player, s.SlowMultiplier, s.SlowSeconds)
		NoiseService.Report(at, s.Noise, player)
		local away = flat(root.Position - at)
		push = (if away.Magnitude > 0.01 then away.Unit else -minion.Root.LookVector) * s.Knockback
	elseif kind == "BatSwarm" then
		local b = cfg.BatSwarm
		SprintService.Slow(player, b.SlowMultiplier, b.SlowSeconds)
		NoiseService.Report(at, b.Noise, player)
	elseif kind == "GhostCat" then
		local c = cfg.GhostCat
		local taken = PumpkinService.Steal(player, c.Steal)
		if taken == 0 then
			return false
		end
		NoiseService.Report(at, c.Noise, player)
		task.delay(c.DropSeconds, PumpkinService.Drop, taken)
	end
	lastHit[player] = now
	minionHit:FireClient(player, kind, push)
	return true
end

-- Behaviour ---------------------------------------------------------------------------------

-- Nearest target within `range` of `from` that passes `ok`.
local function nearest(
	from: Vector3,
	range: number,
	isTarget: (Player) -> boolean,
	ok: ((Player, BasePart) -> boolean)?
): (Player?, BasePart?)
	local best: Player?, bestRoot: BasePart? = nil, nil
	local bestDistance = range
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isTarget(player) then
			local distance = (root.Position - from).Magnitude
			if distance <= bestDistance and (not ok or ok(player, root)) then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

local function stepToward(from: Vector3, to: Vector3, distance: number): (Vector3, boolean)
	local offset = to - from
	if offset.Magnitude <= distance then
		return to, true
	end
	return from + offset.Unit * distance, false
end

local function face(position: Vector3, direction: Vector3, fallback: CFrame): CFrame
	local d = flat(direction)
	if d.Magnitude < 0.01 then
		return fallback.Rotation + position
	end
	return CFrame.lookAt(position, position + d)
end

local function updateSkeleton(m: Minion, dt: number, now: number)
	local cfg = Config.Monsters.SkeletonPatrol
	local a, b = m.A :: Vector3, m.B :: Vector3
	if (m.PauseUntil or 0) > now then
		m.Moving = false
		return
	end
	local goal = if m.ToB then b else a
	local position = m.Root.Position
	local nextPosition, arrived = stepToward(position, goal, cfg.Speed * dt)
	m.Root = face(nextPosition, goal - position, m.Root)
	m.Moving = true
	if arrived then
		m.ToB = not m.ToB
		m.PauseUntil = now + cfg.PauseSeconds
	end
end

local function updateBats(m: Minion, dt: number, now: number, map: MapService.LoadedMap)
	local cfg = Config.Monsters.BatSwarm
	local home = m.Home :: Vector3
	local base = m.Base :: Vector3
	m.Moving = true
	if m.State == "Idle" then
		local a = now * 1.2
		base = home
			+ Vector3.new(
				math.cos(a) * cfg.IdleRadius,
				math.sin(now * 2) * 0.6,
				math.sin(a) * cfg.IdleRadius
			)
		m.Root = face(base, base - m.Root.Position, m.Root)
	elseif m.State == "Dart" then
		local target = m.Target
		local root = target and rootOf(target)
		if not root or (base - home).Magnitude > cfg.LeashRange then
			m.State = "Return"
		else
			base = stepToward(base, root.Position, cfg.DartSpeed * dt)
			-- Zig-zag: swing side to side across the line of flight.
			local forward = flat(root.Position - base)
			local right = if forward.Magnitude > 0.01
				then forward.Unit:Cross(Vector3.yAxis)
				else Vector3.xAxis
			local sway = right * math.sin(now * cfg.ZigZagHz * math.pi * 2) * cfg.ZigZagWidth / 2
			m.Root = face(base + sway, forward, m.Root)
		end
	elseif m.State == "Return" then
		local arrived
		base, arrived = stepToward(base, home, cfg.ReturnSpeed * dt)
		m.Root = face(base, home - base, m.Root)
		if arrived then
			m.State = "Rest"
			m.RestUntil = now + cfg.RestSeconds
		end
	elseif m.State == "Rest" then
		base = home
		m.Root = m.Root.Rotation + home + Vector3.new(0, math.sin(now * 2) * 0.4, 0)
		if (m.RestUntil or 0) <= now then
			m.State = "Idle"
		end
	end
	m.Base = clampToMap(map, base, 3)
end

local function updateCat(m: Minion, dt: number, now: number, map: MapService.LoadedMap)
	local cfg = Config.Monsters.GhostCat
	local height = floorTop(map) + cfg.Hover
	local position = m.Root.Position
	local goal: Vector3
	local speed = cfg.WanderSpeed
	if m.State == "Flee" then
		if (m.FleeUntil or 0) <= now then
			m.State = "Wander"
			m.Goal = nil
		end
		local away = flat(position - (m.FleeFrom or position))
		goal = position + (if away.Magnitude > 0.01 then away.Unit else m.Root.LookVector) * 10
		speed = cfg.StalkSpeed
	elseif m.State == "Stalk" and m.Target and rootOf(m.Target) then
		goal = (rootOf(m.Target) :: BasePart).Position
		speed = cfg.StalkSpeed
	else
		if not m.Goal or flat(m.Goal - position).Magnitude < 1 then
			m.Goal = MapService.RandomFloorPoint(map, 8, 10, 0)
		end
		goal = m.Goal or position
	end
	goal = clampToMap(map, Vector3.new(goal.X, height, goal.Z), 4)
	local nextPosition = stepToward(position, goal, speed * dt)
	nextPosition = Vector3.new(nextPosition.X, height + math.sin(now * 2.5) * 0.25, nextPosition.Z)
	m.Moving = (nextPosition - position).Magnitude > 0.01
	m.Root = face(nextPosition, goal - position, m.Root)
end

-- Runs every Monsters.TickSeconds: targeting and hits.
local function think(
	m: Minion,
	now: number,
	map: MapService.LoadedMap,
	isTarget: (Player) -> boolean
)
	local cfg = Config.Monsters
	local position = m.Root.Position
	if m.Kind == "SkeletonPatrol" then
		local s = cfg.SkeletonPatrol
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if
				root
				and isTarget(player)
				and flat(root.Position - position).Magnitude <= s.HitRange
				and math.abs(root.Position.Y - (position.Y + 3)) < 5
			then
				hit(player, m, position)
			end
		end
	elseif m.Kind == "BatSwarm" then
		local b = cfg.BatSwarm
		if m.State == "Idle" then
			local params = mapParams(map)
			local target = nearest(position, b.AggroRange, isTarget, function(_, root)
				local ray = workspace:Raycast(position, root.Position - position, params)
				return ray == nil
					or (root.Parent ~= nil and ray.Instance:IsDescendantOf(root.Parent))
			end)
			if target then
				m.State = "Dart"
				m.Target = target
			end
		elseif m.State == "Dart" then
			local target = m.Target
			if target and not isTarget(target) then
				m.State = "Return"
			end
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if
					root
					and isTarget(player)
					and (root.Position - position).Magnitude <= b.HitRange
				then
					hit(player, m, position)
					m.State = "Return"
					break
				end
			end
		end
	elseif m.Kind == "GhostCat" then
		local c = cfg.GhostCat
		if m.State == "Flee" then
			return
		end
		local function carrying(player: Player): boolean
			return PumpkinService.GetCount(player) > 0
		end
		if
			m.State ~= "Stalk"
			or not m.Target
			or not isTarget(m.Target)
			or not carrying(m.Target)
		then
			local target = nearest(position, c.NoticeRange, isTarget, function(player)
				return carrying(player)
			end)
			m.State = if target then "Stalk" else "Wander"
			m.Target = target
		end
		local target = m.Target
		local root = target and rootOf(target)
		if target and root and flat(root.Position - position).Magnitude <= c.HitRange then
			if hit(target, m, position) then
				m.State = "Flee"
				m.FleeFrom = root.Position
				m.FleeUntil = now + c.FleeSeconds
				m.Target = nil
			end
		elseif root and (root.Position - position).Magnitude > c.NoticeRange * 1.5 then
			m.State = "Wander"
			m.Target = nil
		end
	end
end

-- Posing --------------------------------------------------------------------------------------

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function pose(m: Minion, now: number)
	for i, body in m.Bodies do
		local root = m.Root
		if m.Kind == "BatSwarm" then
			-- Each bat flutters around the swarm centre.
			local ph = i * 1.7
			root = root
				* CFrame.new(
					math.cos(now * 2.3 + ph) * 1.6,
					math.sin(now * 3.1 + ph) * 0.7,
					math.sin(now * 2.3 + ph) * 1.6
				)
		end
		for _, p in body.Pieces do
			local cf = root * p.Joint
			local swing = p.Swing
			if swing and m.Moving then
				cf *= CFrame.fromAxisAngle(
					swing.Axis,
					swing.Amp * math.sin(now * swing.Speed + swing.Phase)
				)
			end
			table.insert(parts, p.Part)
			table.insert(cframes, cf * p.Offset)
		end
	end
end

-- Lifecycle ---------------------------------------------------------------------------------

local function spawnAll(map: MapService.LoadedMap, difficultyId: string, parent: Folder)
	local cfg = Config.Monsters
	local now = os.clock()
	for _ = 1, cfg.SkeletonPatrol.Count[difficultyId] or 0 do
		local a = spawnPoint(map, 0)
		local b = a and patrolRoute(map, a)
		if a and b then
			table.insert(minions, {
				Kind = "SkeletonPatrol",
				Bodies = { buildSkeleton(parent) },
				Root = CFrame.lookAt(a, b),
				Moving = true,
				State = "Patrol",
				A = a,
				B = b,
				ToB = true,
				PauseUntil = now,
			})
		end
	end
	for _ = 1, cfg.BatSwarm.Count[difficultyId] or 0 do
		local home = spawnPoint(map, cfg.BatSwarm.FlyHeight)
		if home then
			local bodies = {}
			for _ = 1, cfg.BatSwarm.Bats do
				table.insert(bodies, buildBat(parent))
			end
			table.insert(minions, {
				Kind = "BatSwarm",
				Bodies = bodies,
				Root = CFrame.new(home),
				Moving = true,
				State = "Idle",
				Home = home,
				Base = home,
			})
		end
	end
	for _ = 1, cfg.GhostCat.Count[difficultyId] or 0 do
		local at = spawnPoint(map, cfg.GhostCat.Hover)
		if at then
			table.insert(minions, {
				Kind = "GhostCat",
				Bodies = { buildCat(parent) },
				Root = CFrame.new(at),
				Moving = true,
				State = "Wander",
			})
		end
	end
	ReplicatedStorage:SetAttribute("MinionCount", #minions)
end

-- Starts the minions for a round. `isTarget(player)` says who they may bother.
function MinionService.Begin(
	map: MapService.LoadedMap,
	difficultyId: string,
	isTarget: (Player) -> boolean
)
	MinionService.Stop()
	local callerTarget = isTarget
	isTarget = function(player: Player): boolean
		return not player:GetAttribute("Out") and callerTarget(player)
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Minions"
	newFolder.Parent = map.Model
	folder = newFolder

	spawnThread = task.delay(Config.Monsters.SpawnDelay, function()
		spawnThread = nil
		spawnAll(map, difficultyId, newFolder)
	end)

	local tickAt = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local think_ = now >= tickAt
		if think_ then
			tickAt = now + Config.Monsters.TickSeconds
		end
		table.clear(parts)
		table.clear(cframes)
		for _, m in minions do
			if m.Kind == "SkeletonPatrol" then
				updateSkeleton(m, dt, now)
			elseif m.Kind == "BatSwarm" then
				updateBats(m, dt, now, map)
			elseif m.Kind == "GhostCat" then
				updateCat(m, dt, now, map)
			end
			if think_ then
				think(m, now, map, isTarget)
			end
			pose(m, now)
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

function MinionService.Stop()
	if spawnThread then
		task.cancel(spawnThread)
		spawnThread = nil
	end
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(minions)
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(lastHit)
	ReplicatedStorage:SetAttribute("MinionCount", 0)
end

function MinionService.Start()
	minionHit = Remotes.Event("MinionHit")
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return MinionService
