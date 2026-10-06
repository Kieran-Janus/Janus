--!strict
--[[
	SCAREMAZE: two teams. Survivors run through the maze to the exit and are OUT if they stand
	still for Config.ScareMaze.StopSeconds; Haunters BOO them to make them stop. Scare traps
	(scarecrows, zombies, bats, ghosts) jump out when a Survivor walks past. Spooky-cute.
	On/off: Config.Features.ScareMaze (off = the vote never offers it). Settings:
	Config.ScareMaze. Map: src/server/Maps/ScareMaze.luau. Screen: src/client/ScareMazeUI.luau.
	Pure rules (stop rule, teams, scores): src/shared/ScareMazeRules.luau.

	The round:
	  1. Teams: with Config.ScareMaze.MinPlayersForHaunters or more players, HaunterRatio of
	     them (at least 1) are Haunters; otherwise everyone is a Survivor. Survivors start on
	     the parts tagged SurvivorSpawn (the field by the entrance), Haunters on HauntSpawn.
	  2. "Get ready" (IntroSeconds): everyone waits on their spot while the teams are shown.
	  3. "Playing" (Duration): the server checks every Survivor's position SampleSeconds apart.
	     Not moving MinMoveStuds for StopSeconds = out (after a short grace at the start and
	     after every scare). Reaching a part tagged MazeExit = escaped. Walking into a part
	     tagged ScareTrigger sets off its scare (attribute Kind), then it waits Traps.Cooldown.
	     Kind "Patrol": a scarecrow walks up and down that part; walking into it scares you.
	     Out Survivors join the Haunters (OutBecomeHaunters) or watch as ghosts.
	  4. Ends when no Survivor is still running, or at 0:00 (whoever is still running is out).
	Scores (Rules.Score): escaping = EscapePoints + time bonus; Haunters get points for every
	Survivor who stops near them or soon after their BOO. Escapes also count in the save
	(Stats.ScareMazeEscapes).

	Remotes (made when this module loads, which is before clients are told the mode):
	  ScareMazeBoo (client -> server, no arguments): a Haunter's BOO. Checked here: a round is
	    on, the player is a Haunter with a living character, and the cooldown is over.
	  ScareMazeScare (server -> client, kind: string): show the full-screen jumpscare.
	Attributes: player ScareTeam, ScareState, ScareGraceUntil, BooReadyAt, ScareCatches,
	ScareStartedAs (src/shared/ScareMazeRules.luau); ReplicatedStorage Alive (Survivors still
	running) and ScareEscaped (Survivors out of the maze).
	Owner test: the F8 panel's "Force mode" (GameService) picks this mode for the next round.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.ScareMazeRules)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(script.Parent.Types)
local Kit = require(script.Parent.Parent.Build.Kit)
local ScareActors = require(script.Parent.Parent.Build.ScareActors)
local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local GhostService = require(Services.GhostService)
local SfxService = require(Services.SfxService)
local SprintService = require(Services.SprintService)

local ScareMaze = {}

local ATTR = Rules.Attributes
local SURVIVORS = "Survivors"
local HAUNTERS = "Haunters"
local TAG_NAME = "ScareMazeTag" -- the Haunter name tag over a character's head

type Runner = {
	Tracker: Rules.Tracker,
	LastPos: Vector3?,
	LastTime: number,
	LockedUntil: number, -- can't escape before this (moved impossibly fast)
	ScaredAt: number, -- last jumpscare
	CreditBy: Player?, -- the Haunter whose BOO (or trap) scared them last
	CreditAt: number,
}

type Trap = {
	Part: BasePart,
	Kind: string,
	ReadyAt: number,
	Actor: Model?, -- the scarecrow already standing in the map, if any
	Root: BasePart?,
	Rest: CFrame?,
}

type Round = {
	Ctx: Types.RoundContext,
	Participants: { Player },
	Team: { [Player]: string },
	StartedAs: { [Player]: string },
	State: { [Player]: string }, -- Survivors: Running, Escaped or Out
	Runners: { [Player]: Runner }, -- Survivors still running
	Catches: { [Player]: number },
	EscapedLeft: { [Player]: number }, -- seconds left on the clock when they escaped
	EscapeSpot: { [Player]: Vector3 },
	OutReason: { [Player]: string }, -- "Stopped", "Died" or "TimeUp"
	BooReadyAt: { [Player]: number },
	SavedZoom: { [Player]: number },
	Traps: { Trap },
	Patrols: { BasePart }, -- the Roots of the walking scarecrows
	Exits: { BasePart },
	SurvivorSpawns: { BasePart },
	HauntSpawns: { BasePart },
	Threads: { thread },
	Connections: { RBXScriptConnection },
	Folder: Folder, -- scares made during the round
	EndsAt: number, -- server time the round ends
	Active: boolean, -- "Playing" is on
	Rng: Random,
}

local round: Round? = nil

-- Made when this module loads (GameService loads it before telling clients the mode).
local scareRemote = Remotes.Event(Rules.Remotes.Scare)
local booRemote = Remotes.Event(Rules.Remotes.Boo)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Parts with `tag` inside the round's map.
local function tagged(map: Instance, tag: string): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(map) then
			table.insert(list, instance)
		end
	end
	return list
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function timeLeft(r: Round): number
	return math.max(0, r.EndsAt - now())
end

local function countAlive(r: Round)
	local running, escaped = 0, 0
	for _, state in r.State do
		if state == "Running" then
			running += 1
		elseif state == "Escaped" then
			escaped += 1
		end
	end
	ReplicatedStorage:SetAttribute("Alive", running)
	ReplicatedStorage:SetAttribute("ScareEscaped", escaped)
end

local function track(r: Round, thread: thread)
	-- Forget finished ones so the list stays short.
	for i = #r.Threads, 1, -1 do
		if coroutine.status(r.Threads[i]) == "dead" then
			table.remove(r.Threads, i)
		end
	end
	table.insert(r.Threads, thread)
end

local function setZoom(r: Round, player: Player, zoom: number)
	if r.SavedZoom[player] == nil then
		r.SavedZoom[player] = player.CameraMaxZoomDistance
	end
	player.CameraMaxZoomDistance = math.max(zoom, player.CameraMinZoomDistance)
end

local function haunterTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) or head:FindFirstChild(TAG_NAME) then
		return
	end
	local cfg = Config.ScareMaze
	local tag = Kit.nameTag(cfg.HaunterTag, head, 2.5, cfg.Colors.Haunters, cfg.HaunterTagDistance)
	tag.Name = TAG_NAME
end

local function removeTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild(TAG_NAME)
	if tag then
		tag:Destroy()
	end
end

-- Puts a player on `spawn` (spread out a little when several share one).
local function place(r: Round, player: Player, spawns: { BasePart }, index: number)
	if #spawns == 0 then
		return
	end
	local spawn = spawns[(index - 1) % #spawns + 1]
	r.Ctx.Teleport(player, spawn)
	local character = player.Character
	if character and index > #spawns then
		local angle = r.Rng:NextNumber(0, math.pi * 2)
		character:PivotTo(
			character:GetPivot() + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.5
		)
	end
	local runner = r.Runners[player]
	if runner then
		runner.LastPos = nil -- a teleport isn't cheating
	end
end

-- Scares ---------------------------------------------------------------------------------------

--[[
	A Survivor gets scared: the full-screen jumpscare, a stumble (slow), then a short grace.
	At most once per Traps.PersonalCooldown, which is longer than the grace plus StopSeconds,
	so standing next to a scare can't keep anyone safe for ever. `by` = the Haunter to credit.
]]
local function scare(
	player: Player,
	runner: Runner,
	kind: string,
	slow: number,
	seconds: number,
	by: Player?
)
	local cfg = Config.ScareMaze
	local t = now()
	if t - runner.ScaredAt < cfg.Traps.PersonalCooldown then
		return
	end
	runner.ScaredAt = t
	if by then
		runner.CreditBy = by
		runner.CreditAt = t
	end
	SprintService.Slow(player, slow, seconds)
	Rules.Grace(runner.Tracker, t + seconds + cfg.ScareGraceSeconds)
	player:SetAttribute(ATTR.GraceUntil, runner.Tracker.GraceUntil)
	scareRemote:FireClient(player, kind)
end

-- The middle of a trap's floor, and its sideways/forward directions.
local function trapFrame(part: BasePart): (Vector3, Vector3, Vector3, number)
	local cf = part.CFrame
	local floorY = cf.Position.Y - part.Size.Y / 2
	return Vector3.new(cf.Position.X, floorY, cf.Position.Z),
		flat(cf.RightVector),
		flat(cf.LookVector),
		part.Size.X / 2
end

-- Standing at `from`, turned (level) to look at `to`; along `fallback` if `to` is right there.
local function turnedTo(from: Vector3, to: Vector3, fallback: Vector3): CFrame
	local towards = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if towards.Magnitude < 0.1 then
		towards = fallback
	end
	return CFrame.lookAt(from, from + towards)
end

-- Waits, then says whether the same round is still on (false = stop what you're doing).
local function pause(r: Round, seconds: number): boolean
	task.wait(seconds)
	return round == r
end

-- Plays one trap's scare (runs in its own thread). `target` = who it jumps at, if known.
local function animate(r: Round, trap: Trap, target: Vector3?)
	local cfg = Config.ScareMaze
	local kinds = cfg.Traps.Kinds :: any
	local kindCfg = kinds[trap.Kind]
	local seconds: number = if kindCfg then kindCfg.Seconds else 2
	local centre, right, look, half = trapFrame(trap.Part)
	local aim = target or centre
	local colors = cfg.ActorColors
	if trap.Kind == "Scarecrow" then
		local temporary: Model? = nil
		local root: BasePart, rest: CFrame
		local standing, standingRest = trap.Root, trap.Rest
		if standing and standing.Parent and standingRest then
			root, rest = standing, standingRest
		else
			-- No scarecrow standing here (a copied trigger): one steps out of the wall.
			local base = centre + right * (half + 1)
			local actor = ScareActors.Scarecrow(CFrame.lookAt(base, base - right), r.Folder)
			temporary = actor
			root = ScareActors.Rig(actor)
			rest = root.CFrame
		end
		local pos = rest.Position
		local face = turnedTo(pos, aim, rest.LookVector)
		ScareActors.Move(root, face, 0.12, Enum.EasingStyle.Back)
		if not pause(r, 0.12) then
			return
		end
		local lunge: number = kindCfg and kindCfg.Lunge or 4
		ScareActors.Move(
			root,
			face * CFrame.new(0, 0, -lunge) * CFrame.Angles(math.rad(-12), 0, 0),
			0.2,
			Enum.EasingStyle.Back
		)
		if not pause(r, math.max(0.4, seconds - 1)) then
			return
		end
		ScareActors.Move(root, rest, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		if not pause(r, 0.85) then
			return
		end
		if temporary then
			temporary:Destroy()
		end
	elseif trap.Kind == "Zombie" then
		local base = centre + right * math.max(half - 2.2, 0) + look * 1.5
		local up = turnedTo(base, aim, -right)
		local down = up - Vector3.new(0, 7, 0) -- hidden under the floor
		local zombie = ScareActors.Zombie(down, r.Folder)
		local root = ScareActors.Rig(zombie)
		ScareActors.Puff(CFrame.new(base + Vector3.new(0, 0.3, 0)), colors.Dirt, 30, r.Folder, 2)
		ScareActors.Move(root, up, 0.35, Enum.EasingStyle.Back)
		if not pause(r, 0.4) then
			return
		end
		for _, angle in { 9, -9 } do
			ScareActors.Move(
				root,
				up * CFrame.Angles(0, 0, math.rad(angle)),
				0.3,
				Enum.EasingStyle.Sine
			)
			if not pause(r, 0.3) then
				return
			end
		end
		ScareActors.Move(root, up, 0.2)
		if not pause(r, math.max(0.2, seconds - 1.9)) then
			return
		end
		ScareActors.Move(root, down, 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if not pause(r, 0.65) then
			return
		end
		zombie:Destroy()
	elseif trap.Kind == "Bats" then
		local bats: { Model } = {}
		local count: number = kindCfg and kindCfg.Count or 6
		for _ = 1, count do
			local start = centre
				+ right * (half + 1.5)
				+ look * r.Rng:NextNumber(-4, 4)
				+ Vector3.new(0, r.Rng:NextNumber(3, 8), 0)
			local finish = centre
				- right * (half + 6)
				+ look * r.Rng:NextNumber(-8, 8)
				+ Vector3.new(0, r.Rng:NextNumber(9, 15), 0)
			local bat = ScareActors.Bat(CFrame.lookAt(start, finish), r.Folder)
			local root = ScareActors.Rig(bat)
			ScareActors.Move(
				root,
				CFrame.lookAt(finish, finish + (finish - start)),
				r.Rng:NextNumber(0.7, seconds * 0.8),
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.In
			)
			table.insert(bats, bat)
		end
		if not pause(r, seconds) then
			return
		end
		for _, bat in bats do
			bat:Destroy()
		end
	elseif trap.Kind == "Ghost" then
		local start = centre + right * (half + 5) + Vector3.new(0, 12, 0) - look * 3
		local close = centre + right * 2 + Vector3.new(0, 1, 0)
		local finish = centre - right * (half + 8) + Vector3.new(0, 15, 0) + look * 4
		local function facing(at: Vector3): CFrame
			return turnedTo(at, aim, look)
		end
		local ghost = ScareActors.Ghost(facing(start), r.Folder)
		local root = ScareActors.Rig(ghost)
		ScareActors.Move(root, facing(close), seconds * 0.35, Enum.EasingStyle.Quad)
		if not pause(r, seconds * 0.55) then
			return
		end
		ScareActors.Move(
			root,
			facing(finish),
			seconds * 0.4,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		if not pause(r, seconds * 0.45) then
			return
		end
		ghost:Destroy()
	end
end

-- Sets a trap off (if it's ready): its scare, its sound, and jumpscares for Survivors nearby.
local function fireTrap(r: Round, trap: Trap, target: Vector3?, by: Player?)
	local cfg = Config.ScareMaze
	local t = now()
	if trap.Kind == "Patrol" or t < trap.ReadyAt or not trap.Part.Parent then
		return
	end
	trap.ReadyAt = t + cfg.Traps.Cooldown
	local kindCfg = (cfg.Traps.Kinds :: any)[trap.Kind]
	if kindCfg and kindCfg.Sound then
		SfxService.Play3D(kindCfg.Sound, trap.Part)
	end
	track(r, task.spawn(animate, r, trap, target))
	local centre = trap.Part.Position
	for player, runner in r.Runners do
		local root = aliveRoot(player)
		if root and Rules.Flat(root.Position, centre) <= cfg.Traps.JumpscareRange then
			scare(player, runner, trap.Kind, cfg.Traps.SlowMultiplier, cfg.Traps.SlowSeconds, by)
		end
	end
end

-- A scarecrow walking up and down its Patrol trigger's long side, until the round ends.
local function startPatrol(r: Round, trap: Trap)
	local part = trap.Part
	local cfg = (Config.ScareMaze.Traps.Kinds :: any).Patrol
	local cf, size = part.CFrame, part.Size
	local floorY = cf.Position.Y - size.Y / 2
	local centre = Vector3.new(cf.Position.X, floorY, cf.Position.Z)
	local axis = if size.X > size.Z then flat(cf.RightVector) else flat(cf.LookVector)
	local half = math.max(size.X, size.Z) / 2
	local a, b = centre - axis * half, centre + axis * half
	local walker: BasePart
	local standing = trap.Root
	if standing and standing.Parent then
		walker = standing
	else
		walker = ScareActors.Rig(ScareActors.Scarecrow(CFrame.lookAt(a, b), r.Folder))
	end
	table.insert(r.Patrols, walker)
	track(
		r,
		task.spawn(function()
			local from, to = a, b
			walker.CFrame = CFrame.lookAt(from, to)
			local speed = math.max(cfg.Speed, 0.5)
			while round == r and r.Active and walker.Parent and (to - from).Magnitude > 1 do
				local seconds = (to - from).Magnitude / speed
				ScareActors.Move(
					walker,
					CFrame.lookAt(to, to + (to - from)),
					seconds,
					Enum.EasingStyle.Linear
				)
				if not pause(r, seconds) then
					return
				end
				-- Turn round and wait a moment.
				ScareActors.Move(walker, CFrame.lookAt(to, from), 0.5, Enum.EasingStyle.Back)
				if not pause(r, cfg.PauseSeconds) then
					return
				end
				from, to = to, from
			end
		end)
	)
end

local function setupTraps(r: Round, map: Instance)
	for _, part in tagged(map, Tags.ScareTrigger) do
		local kind = part:GetAttribute("Kind")
		if typeof(kind) ~= "string" or (Config.ScareMaze.Traps.Kinds :: any)[kind] == nil then
			warn(
				("[ScareMaze] %s has an unknown Kind %q (use Scarecrow, Zombie, Bats, Ghost or Patrol)"):format(
					part:GetFullName(),
					tostring(kind)
				)
			)
			continue
		end
		local trap: Trap = { Part = part, Kind = kind, ReadyAt = 0 }
		-- A scarecrow placed with the trap (same Model, attribute ScareActor).
		local holder = part.Parent
		if holder and holder ~= map and (kind == "Scarecrow" or kind == "Patrol") then
			for _, child in holder:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("ScareActor") then
					trap.Actor = child
					local root = ScareActors.Rig(child)
					trap.Root = root
					trap.Rest = root.CFrame
					break
				end
			end
		end
		table.insert(r.Traps, trap)
	end
end

-- Out, escaped, Haunters ---------------------------------------------------------------------

local function setTeam(r: Round, player: Player, team: string)
	local cfg = Config.ScareMaze
	r.Team[player] = team
	player:SetAttribute(ATTR.Team, team)
	if team == HAUNTERS then
		r.Catches[player] = r.Catches[player] or 0
		player:SetAttribute(ATTR.Catches, r.Catches[player])
		r.BooReadyAt[player] = r.BooReadyAt[player] or 0
		player:SetAttribute(ATTR.BooReadyAt, r.BooReadyAt[player])
		haunterTag(player)
		setZoom(r, player, cfg.HaunterMaxZoom)
	else
		setZoom(r, player, cfg.SurvivorMaxZoom)
	end
end

-- Haunters near the spot (and the one who scared them last) score a catch.
local function creditCatch(r: Round, player: Player, runner: Runner, position: Vector3?)
	local cfg = Config.ScareMaze
	local credited: { [Player]: boolean } = {}
	local by = runner.CreditBy
	if by and now() - runner.CreditAt <= cfg.CatchCreditSeconds and r.Team[by] == HAUNTERS then
		credited[by] = true
	end
	if position then
		for other, team in r.Team do
			if team == HAUNTERS and other ~= player then
				local root = aliveRoot(other)
				if root and Rules.Flat(root.Position, position) <= cfg.CatchCreditRange then
					credited[other] = true
				end
			end
		end
	end
	for haunter in credited do
		if haunter.Parent == Players then
			r.Catches[haunter] = (r.Catches[haunter] or 0) + 1
			haunter:SetAttribute(ATTR.Catches, r.Catches[haunter])
		end
	end
end

local function becomeHaunter(r: Round, player: Player)
	setTeam(r, player, HAUNTERS)
	if aliveRoot(player) then
		place(r, player, r.HauntSpawns, r.Rng:NextInteger(1, math.max(#r.HauntSpawns, 1)))
	end
end

-- A Survivor is out: `reason` = "Stopped", "Died" or "TimeUp".
local function knockOut(r: Round, player: Player, reason: string, position: Vector3?)
	local runner = r.Runners[player]
	if not runner or r.State[player] ~= "Running" then
		return
	end
	local cfg = Config.ScareMaze
	r.Runners[player] = nil
	r.State[player] = "Out"
	r.OutReason[player] = reason
	player:SetAttribute(ATTR.State, "Out")
	if reason == "Stopped" then
		creditCatch(r, player, runner, position)
	end
	countAlive(r)
	if reason == "TimeUp" or not r.Active then
		return
	end
	if cfg.OutBecomeHaunters then
		track(
			r,
			task.delay(cfg.OutToHaunterDelay, function()
				if round == r and r.Active and player.Parent == Players then
					becomeHaunter(r, player)
				end
			end)
		)
	else
		GhostService.MarkOut(player, reason == "Stopped")
	end
end

local function escape(r: Round, player: Player, position: Vector3)
	if r.State[player] ~= "Running" then
		return
	end
	r.Runners[player] = nil
	r.State[player] = "Escaped"
	r.EscapedLeft[player] = timeLeft(r)
	r.EscapeSpot[player] = position
	player:SetAttribute(ATTR.State, "Escaped")
	countAlive(r)
	local data = DataService.Get(player)
	local stats = data and data.Stats
	if type(stats) == "table" then
		stats.ScareMazeEscapes = (tonumber(stats.ScareMazeEscapes) or 0) + 1
	end
end

local function inExit(r: Round, position: Vector3): boolean
	for _, exit in r.Exits do
		if exit.Parent and Rules.InBox(position, exit.CFrame, exit.Size, 0.5) then
			return true
		end
	end
	return false
end

-- One check of every running Survivor: moving? escaped? walked into a trap or a patrol?
local function sample(r: Round)
	local cfg = Config.ScareMaze
	local patrolCfg = (cfg.Traps.Kinds :: any).Patrol
	local t = now()
	for player, runner in r.Runners do
		local root = aliveRoot(player)
		if not root then
			continue
		end
		local position = root.Position
		local last = runner.LastPos
		if
			last
			and Rules.TooFast(last, position, t - runner.LastTime, cfg.MaxMoveSpeed, cfg.SlackStuds)
		then
			runner.LockedUntil = t + cfg.EscapeLockSeconds
		end
		runner.LastPos = position
		runner.LastTime = t
		if Rules.Update(runner.Tracker, position, t, cfg.MinMoveStuds) >= cfg.StopSeconds then
			knockOut(r, player, "Stopped", position)
			continue
		end
		if t >= runner.LockedUntil and inExit(r, position) then
			escape(r, player, position)
			continue
		end
		for _, trap in r.Traps do
			if
				trap.Kind ~= "Patrol"
				and t >= trap.ReadyAt
				and trap.Part.Parent
				and Rules.InBox(position, trap.Part.CFrame, trap.Part.Size, 0)
			then
				fireTrap(r, trap, position, nil)
			end
		end
		for _, walker in r.Patrols do
			if walker.Parent and Rules.Flat(walker.Position, position) <= patrolCfg.ScareRange then
				if t - runner.ScaredAt >= cfg.Traps.PersonalCooldown then
					SfxService.Play3D(patrolCfg.Sound, walker)
				end
				scare(
					player,
					runner,
					"Scarecrow",
					cfg.Traps.SlowMultiplier,
					cfg.Traps.SlowSeconds,
					nil
				)
			end
		end
	end
end

-- BOO! ---------------------------------------------------------------------------------------

local function onBoo(player: Player)
	local r = round
	if not r or not r.Active or r.Team[player] ~= HAUNTERS then
		return
	end
	local cfg = Config.ScareMaze
	local t = now()
	if t < (r.BooReadyAt[player] or 0) then
		return
	end
	local root = aliveRoot(player)
	if not root then
		return
	end
	r.BooReadyAt[player] = t + cfg.Boo.Cooldown
	player:SetAttribute(ATTR.BooReadyAt, r.BooReadyAt[player])
	SfxService.Play3D(cfg.BooSound, root)
	ScareActors.Puff(root.CFrame, cfg.ActorColors.Ghost, 25, r.Folder, 1.5)
	local nearest: Vector3? = nil
	local nearestDistance = math.huge
	for survivor, runner in r.Runners do
		local other = aliveRoot(survivor)
		if other then
			local distance = (other.Position - root.Position).Magnitude
			if distance <= cfg.Boo.Range then
				scare(survivor, runner, "Boo", cfg.Boo.SlowMultiplier, cfg.Boo.SlowSeconds, player)
			end
			if distance < nearestDistance then
				nearest, nearestDistance = other.Position, distance
			end
		end
	end
	for _, trap in r.Traps do
		if (trap.Part.Position - root.Position).Magnitude <= cfg.Boo.TrapRange then
			fireTrap(r, trap, nearest, player)
		end
	end
end

booRemote.OnServerEvent:Connect(onBoo)

-- The round -----------------------------------------------------------------------------------

-- Stops everything a ScareMaze round runs and clears what it set. Safe to call any time.
function ScareMaze.Cleanup()
	local r = round
	round = nil
	ReplicatedStorage:SetAttribute("Alive", nil)
	ReplicatedStorage:SetAttribute("ScareEscaped", nil)
	if not r then
		return
	end
	r.Active = false
	local current = coroutine.running()
	for _, thread in r.Threads do
		if thread ~= current and coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
	end
	table.clear(r.Threads)
	for _, connection in r.Connections do
		connection:Disconnect()
	end
	table.clear(r.Connections)
	r.Folder:Destroy()
	for _, player in r.Participants do
		for _, name in ATTR :: { [string]: string } do
			player:SetAttribute(name, nil)
		end
		local zoom = r.SavedZoom[player]
		if zoom and player.Parent == Players then
			player.CameraMaxZoomDistance = zoom
		end
		removeTag(player)
	end
end

local function result(r: Round): Types.RoundResult
	local cfg = Config.ScareMaze
	local text = cfg.Text
	local survivors, escaped = 0, 0
	for _, player in r.Participants do
		if r.StartedAs[player] == SURVIVORS then
			survivors += 1
			if r.State[player] == "Escaped" then
				escaped += 1
			end
		end
	end
	local rows: { Types.ResultRow } = {}
	local best = 0
	for _, player in r.Participants do
		if player.Parent ~= Players then
			continue
		end
		local wasSurvivor = r.StartedAs[player] ~= HAUNTERS
		local got = r.State[player] == "Escaped"
		local left = math.floor(r.EscapedLeft[player] or 0)
		local catches = r.Catches[player] or 0
		local score, coins =
			Rules.Score({ Escaped = got, TimeLeft = left, Catches = catches }, cfg.Rewards)
		local stats: { string } = {}
		if got then
			table.insert(stats, text.StatEscaped:format(left // 60, left % 60))
		end
		if catches > 0 then
			table.insert(stats, text.StatCatches:format(catches))
		end
		best = math.max(best, score)
		table.insert(rows, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = score,
			Pumpkins = score,
			Coins = coins,
			Survived = got or not wasSurvivor,
			Top = false,
			Team = if wasSurvivor then text.TeamSurvivor else text.TeamHaunter,
			Badge = if got
				then text.BadgeEscaped
				elseif not wasSurvivor then text.BadgeHaunter
				elseif r.OutReason[player] == "TimeUp" then text.BadgeTimeUp
				else text.BadgeStopped,
			Stat = if #stats > 0 then table.concat(stats, ", ") else nil,
		})
	end
	for _, row in rows do
		row.Top = best > 0 and row.Score == best
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	local hadHaunters = false
	for _, team in r.StartedAs do
		if team == HAUNTERS then
			hadHaunters = true
		end
	end
	local winner = if survivors > 0 and escaped == survivors
		then text.WinnerEveryone
		elseif escaped > 0 then text.WinnerSome:format(escaped, survivors)
		elseif hadHaunters then text.WinnerHaunters
		else text.WinnerMaze
	return {
		Rows = rows,
		ScoreLabel = text.ScoreLabel,
		Winner = winner,
		MvpLine = text.MvpLine,
	}
end

function ScareMaze.Run(ctx: Types.RoundContext): Types.RoundResult
	ScareMaze.Cleanup()
	local cfg = Config.ScareMaze
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "ScareFX"
	folder.Parent = map.Model
	local r: Round = {
		Ctx = ctx,
		Participants = table.clone(ctx.Players),
		Team = {},
		StartedAs = {},
		State = {},
		Runners = {},
		Catches = {},
		EscapedLeft = {},
		EscapeSpot = {},
		OutReason = {},
		BooReadyAt = {},
		SavedZoom = {},
		Traps = {},
		Patrols = {},
		Exits = tagged(map.Model, Tags.MazeExit),
		SurvivorSpawns = tagged(map.Model, Tags.SurvivorSpawn),
		HauntSpawns = tagged(map.Model, Tags.HauntSpawn),
		Threads = {},
		Connections = {},
		Folder = folder,
		EndsAt = now() + cfg.IntroSeconds + cfg.Duration,
		Active = false,
		Rng = Random.new(),
	}
	round = r
	if #r.SurvivorSpawns == 0 then
		r.SurvivorSpawns = map.Spawns
	end
	if #r.HauntSpawns == 0 then
		r.HauntSpawns = map.Spawns
	end
	if #r.Exits == 0 then
		warn("[ScareMaze] The map has no part tagged MazeExit, so nobody can escape.")
	end
	setupTraps(r, map.Model)

	-- Teams: who is playing (alive) is split; anyone whose character is gone just watches.
	local playing: { Player } = {}
	for _, player in r.Participants do
		if ctx.AliveHumanoid(player) then
			table.insert(playing, player)
		end
	end
	local survivors, haunters =
		Rules.PickTeams(playing, cfg.HaunterRatio, cfg.MinPlayersForHaunters, r.Rng)
	local t0 = now()
	for i, player in survivors do
		r.StartedAs[player] = SURVIVORS
		player:SetAttribute(ATTR.StartedAs, SURVIVORS)
		setTeam(r, player, SURVIVORS)
		r.State[player] = "Running"
		player:SetAttribute(ATTR.State, "Running")
		r.Runners[player] = {
			Tracker = Rules.NewTracker(t0),
			LastPos = nil,
			LastTime = t0,
			LockedUntil = 0,
			ScaredAt = -math.huge,
			CreditBy = nil,
			CreditAt = 0,
		}
		place(r, player, r.SurvivorSpawns, i)
	end
	for i, player in haunters do
		r.StartedAs[player] = HAUNTERS
		player:SetAttribute(ATTR.StartedAs, HAUNTERS)
		setTeam(r, player, HAUNTERS)
		place(r, player, r.HauntSpawns, i)
	end
	for _, player in r.Participants do
		if not r.StartedAs[player] then
			r.StartedAs[player] = SURVIVORS
			r.State[player] = "Out"
			r.OutReason[player] = "Died"
			GhostService.MarkOut(player, false)
		end
	end
	countAlive(r)

	-- Leaving, dying and respawning.
	local function watchCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if round ~= r or not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		table.insert(
			r.Connections,
			humanoid.Died:Connect(function()
				knockOut(r, player, "Died", nil)
			end)
		)
	end
	for _, player in r.Participants do
		if player.Character then
			track(r, task.spawn(watchCharacter, player, player.Character))
		end
		table.insert(
			r.Connections,
			player.CharacterAdded:Connect(function(character)
				track(r, task.spawn(watchCharacter, player, character))
				task.defer(function()
					if round ~= r then
						return
					end
					if r.Team[player] == HAUNTERS then
						haunterTag(player)
						place(
							r,
							player,
							r.HauntSpawns,
							r.Rng:NextInteger(1, math.max(#r.HauntSpawns, 1))
						)
					elseif r.State[player] == "Escaped" then
						local spot = r.EscapeSpot[player]
						if spot then
							character:PivotTo(
								CFrame.new(spot + Vector3.new(0, Config.Maps.SpawnHeight, 0))
							)
						end
					end
				end)
			end)
		)
	end
	table.insert(
		r.Connections,
		Players.PlayerRemoving:Connect(function(player)
			if r.Runners[player] then
				r.Runners[player] = nil
				r.State[player] = "Out"
				r.OutReason[player] = "Died"
				countAlive(r)
			end
			r.BooReadyAt[player] = nil
			r.SavedZoom[player] = nil
		end)
	)

	-- Get ready: everyone waits on their spot.
	for _, player in playing do
		SprintService.Slow(player, 0, cfg.IntroSeconds)
	end
	ctx.Countdown("Get ready", cfg.IntroSeconds)

	-- Run!
	local start = now()
	r.EndsAt = start + cfg.Duration
	r.Active = true
	for player, runner in r.Runners do
		runner.Tracker = Rules.NewTracker(start)
		Rules.Grace(runner.Tracker, start + cfg.StartGraceSeconds)
		runner.LastPos = nil
		player:SetAttribute(ATTR.GraceUntil, runner.Tracker.GraceUntil)
	end
	for _, trap in r.Traps do
		if trap.Kind == "Patrol" then
			startPatrol(r, trap)
		end
	end
	track(
		r,
		task.spawn(function()
			while round == r and r.Active do
				local ok, err = pcall(function()
					sample(r)
					return nil
				end)
				if not ok then
					warn("[ScareMaze] Position check failed: " .. tostring(err))
				end
				task.wait(cfg.SampleSeconds)
			end
		end)
	)
	ctx.Countdown("Playing", cfg.Duration, function()
		return next(r.Runners) == nil
	end)

	-- Time's up: whoever is still in the maze is out.
	r.Active = false
	for player in r.Runners do
		knockOut(r, player, "TimeUp", nil)
	end
	local final = result(r)
	ScareMaze.Cleanup()
	return final
end

return ScareMaze
