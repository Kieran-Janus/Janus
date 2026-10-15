--!strict
--[[
	SPOOKY OBBY: everybody races over a Halloween obstacle course (map SpookyObby, built by
	src/server/Maps/SpookyObby.luau from src/shared/Config/Maps/SpookyObby.luau). Easy to play:
	falling off only sends you back to your last checkpoint.
	On/off: Config.Features.ObbyRace. Settings: Config.ObbyRace. Screen: src/client/ObbyRaceUI.luau.
	Pure rules (touching pads, sweepers, rewards, order): src/shared/ObbyRaceRules.luau.

	The round:
	  1. The pieces of the other difficulty (parts tagged ObbyVariant whose attribute Only is not
	     this round's difficulty) are removed; the ghost sweepers get this difficulty's speed.
	  2. "Get ready" (IntroSeconds): everyone stands on the start plaza and can't walk.
	  3. GO! The server checks every racer SampleSeconds apart:
	       - moving faster than anyone can run (SpeedCheck) -> back to the last checkpoint
	       - falling FallBelowCheckpoint studs below the last checkpoint -> back to it
	       - goo (tag ObbyHazard) or a sweeper bar (tag ObbySweeper) -> back to it
	       - standing on the NEXT checkpoint (tag ObbyCheckpoint, attribute Index) counts it;
	         checkpoints only count in order
	       - the finish (tag ObbyFinish) after every checkpoint, no sooner than MinSeconds
	         after GO, = finished (places 1st, 2nd, 3rd... in finishing order)
	  4. Ends when everyone has finished, at 0:00, or EndAfterFirstSeconds after the first
	     finisher. A racer who resets or dies comes back at their last checkpoint.
	Scores (Rules.Reward): finishers get points and coins by place; the rest get some for each
	checkpoint. Hard multiplies coins (Config.ObbyRace.Difficulty.Hard.CoinMultiplier).

	Remote (made when this module loads, which is before clients are told the mode):
	  ObbyRaceBack (client -> server, no arguments): "Back to checkpoint". Checked here: a race
	  is on, the player is racing (not finished), alive, and BackCooldown has passed.
	Attributes: player ObbyCheckpoint, ObbyTotal, ObbyRank, ObbyPlace, ObbyTime, ObbyBack,
	ObbyBackReason, ObbyBackReadyAt; ReplicatedStorage ObbyFinished, ObbyStartedAt, ObbyLeader
	(src/shared/ObbyRaceRules.luau). All cleared by Cleanup.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.ObbyRaceRules)
local SpeedCheck = require(ReplicatedStorage.Shared.SpeedCheck)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Types = require(script.Parent.Types)
local SprintService = require(script.Parent.Parent.Services.SprintService)

local ObbyRace = {}

local ATTR = Rules.Attributes
local SHARED = Rules.Shared
local PARTS = Rules.Parts

type Pad = {
	Part: BasePart,
	Index: number,
	Frame: CFrame, -- level, at the top middle
	Size: Vector3,
	Round: boolean,
}

type Sweeper = {
	Part: BasePart,
	Center: Vector3,
	Speed: number,
	Phase: number,
	Size: Vector3,
}

type Racer = {
	Player: Player,
	Reached: number, -- checkpoints reached
	ReachedAt: number,
	Speed: SpeedCheck.Check,
	Finished: boolean,
	Place: number,
	Time: number,
	BackReadyAt: number,
	Spawn: BasePart?,
	Left: boolean,
}

type Round = {
	Ctx: Types.RoundContext,
	Difficulty: string,
	Settings: any,
	Participants: { Player },
	Racers: { [Player]: Racer },
	Order: { Pad }, -- checkpoints in the order they must be touched
	Finish: Pad?,
	Hazards: { Pad },
	Sweepers: { Sweeper },
	PlazaTop: number,
	Forward: Vector3, -- the way the course goes from the plaza (flat)
	Finishers: { Player },
	Threads: { thread },
	Connections: { RBXScriptConnection },
	Active: boolean, -- the race is on (after GO!)
	StartedAt: number,
	EndsAt: number,
	Rng: Random,
}

local round: Round? = nil

-- Made when this module loads (GameService loads it before telling clients the mode).
local backRemote = Remotes.Event(Rules.Remotes.Back)

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

local function tagged(map: Instance, tag: string): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(map) then
			table.insert(list, instance)
		end
	end
	return list
end

local function track(r: Round, thread: thread)
	for i = #r.Threads, 1, -1 do
		if coroutine.status(r.Threads[i]) == "dead" then
			table.remove(r.Threads, i)
		end
	end
	table.insert(r.Threads, thread)
end

-- A part's top as a pad: a level frame at its top middle, its footprint, and whether it is round
-- (a cylinder lying flat).
local function padOf(part: BasePart, index: number): Pad
	local cf, size = part.CFrame, part.Size
	local top = ParkourLogic.TopY(cf, size)
	local p = cf.Position
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		local d = math.min(size.Y, size.Z)
		return {
			Part = part,
			Index = index,
			Frame = CFrame.new(p.X, top, p.Z),
			Size = Vector3.new(d, size.X, d),
			Round = true,
		}
	end
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	local at = Vector3.new(p.X, top, p.Z)
	return {
		Part = part,
		Index = index,
		Frame = CFrame.lookAt(at, at + look.Unit),
		Size = size,
		Round = false,
	}
end

local function speedLimits(): SpeedCheck.Limits
	local cfg = Config.ObbyRace
	return {
		MaxSpeed = Config.Player.SprintSpeed
			* Config.Monetization.VipSpeedMultiplier
			* cfg.SpeedTolerance,
		Slack = cfg.SpeedSlack,
		MaxRiseSpeed = cfg.MaxRiseSpeed,
		RiseSlack = cfg.RiseSlack,
		WindowSeconds = cfg.SpeedWindowSeconds,
	}
end

-- Where a racer stands in the race (for Rules.Sort).
local function standing(racer: Racer): Rules.Standing
	return {
		Finished = racer.Finished,
		Place = racer.Place,
		Checkpoints = racer.Reached,
		ReachedAt = racer.ReachedAt,
	}
end

-- The live places (ObbyRank) of everyone still in the race.
local function rerank(r: Round)
	local list: { Racer } = {}
	for _, racer in r.Racers do
		if not racer.Left then
			table.insert(list, racer)
		end
	end
	table.sort(list, function(a, b)
		return Rules.Sort(standing(a), standing(b))
	end)
	for i, racer in list do
		if racer.Player:GetAttribute(ATTR.Rank) ~= i then
			racer.Player:SetAttribute(ATTR.Rank, i)
		end
	end
end

--[[
	Puts a racer back where they belong: the finish (finished), their last checkpoint, or their
	spot on the plaza. `reason` (Fell, Goo, Swept, TooFast, Button) tells their screen why;
	nil = quietly (a respawn).
]]
local function sendBack(r: Round, racer: Racer, reason: string?)
	local player = racer.Player
	local character = player.Character
	if not character then
		return
	end
	local spot: Vector3
	local facing = r.Forward
	if racer.Finished and r.Finish then
		spot = r.Finish.Frame.Position
	elseif racer.Reached > 0 and r.Order[racer.Reached] then
		local pad = r.Order[racer.Reached]
		spot = pad.Frame.Position
		local saved = pad.Part:GetAttribute(PARTS.Facing)
		if typeof(saved) == "Vector3" and saved.Magnitude > 1e-3 then
			facing = Vector3.new(saved.X, 0, saved.Z).Unit
		end
		spot += Vector3.new(r.Rng:NextNumber(-1.5, 1.5), 0, r.Rng:NextNumber(-1.5, 1.5))
	elseif racer.Spawn then
		local top = racer.Spawn.Position
		spot = Vector3.new(top.X, r.PlazaTop, top.Z)
	else
		spot = r.Ctx.Map.Floor.Position + Vector3.new(0, r.Ctx.Map.Floor.Size.Y / 2, 0)
	end
	local at = spot + Vector3.new(0, Config.Maps.SpawnHeight, 0)
	character:PivotTo(CFrame.lookAt(at, at + facing))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- The server moved them (not cheating): the anti-cheat measures from here.
	SpeedCheck.Reset(
		racer.Speed,
		if root and root:IsA("BasePart") then root.Position else at,
		now()
	)
	if reason then
		local count = player:GetAttribute(ATTR.Back)
		player:SetAttribute(ATTR.BackReason, reason)
		player:SetAttribute(ATTR.Back, (if typeof(count) == "number" then count else 0) + 1)
	end
end

local function racing(r: Round): boolean
	for _, racer in r.Racers do
		if not racer.Left and not racer.Finished then
			return true
		end
	end
	return false
end

local function finish(r: Round, racer: Racer, elapsed: number)
	racer.Finished = true
	table.insert(r.Finishers, racer.Player)
	racer.Place = #r.Finishers
	racer.Time = elapsed
	racer.Player:SetAttribute(ATTR.Time, elapsed)
	racer.Player:SetAttribute(ATTR.Place, racer.Place)
	ReplicatedStorage:SetAttribute(SHARED.Finished, #r.Finishers)
	if racer.Place == 1 then
		ReplicatedStorage:SetAttribute(SHARED.Leader, racer.Player.DisplayName)
		local after = Config.ObbyRace.EndAfterFirstSeconds
		if after > 0 then
			r.EndsAt = math.min(r.EndsAt, now() + after)
		end
	end
	rerank(r)
end

-- One check of every racer.
local function sample(r: Round)
	local cfg = Config.ObbyRace
	local t = now()
	local limits = speedLimits()
	for player, racer in r.Racers do
		if racer.Left then
			continue
		end
		local root = aliveRoot(player)
		if not root then
			continue
		end
		local position = root.Position
		if SpeedCheck.Step(racer.Speed, position, t, limits) then
			sendBack(r, racer, "TooFast")
			continue
		end
		if racer.Finished then
			local finishPad = r.Finish
			if finishPad and position.Y < finishPad.Frame.Position.Y - cfg.FallBelowCheckpoint then
				sendBack(r, racer, nil)
			end
			continue
		end
		local base = if racer.Reached > 0 and r.Order[racer.Reached]
			then r.Order[racer.Reached].Frame.Position.Y
			else r.PlazaTop
		if position.Y < base - cfg.FallBelowCheckpoint then
			sendBack(r, racer, "Fell")
			continue
		end
		local hit: string? = nil
		for _, hazard in r.Hazards do
			if
				hazard.Part.Parent
				and Rules.OnPad(position, hazard.Frame, hazard.Size, false, 0, cfg.HazardHeight)
			then
				hit = "Goo"
				break
			end
		end
		if not hit then
			local elapsed = t - r.StartedAt
			for _, sweeper in r.Sweepers do
				if sweeper.Part.Parent then
					local angle = Rules.SweeperAngle(sweeper.Phase, sweeper.Speed, elapsed)
					local bar = Rules.SweeperCFrame(sweeper.Center, angle)
					if Rules.SweeperHit(position, bar, sweeper.Size, cfg.SweeperBodyRadius) then
						hit = "Swept"
						break
					end
				end
			end
		end
		if hit then
			sendBack(r, racer, hit)
			continue
		end
		-- The next checkpoint (only the next one counts).
		local nextPad = r.Order[racer.Reached + 1]
		if
			nextPad
			and nextPad.Part.Parent
			and Rules.OnPad(
				position,
				nextPad.Frame,
				nextPad.Size,
				nextPad.Round,
				cfg.TouchMargin,
				cfg.TouchHeight
			)
		then
			racer.Reached += 1
			racer.ReachedAt = t
			player:SetAttribute(ATTR.Checkpoint, racer.Reached)
			rerank(r)
		end
		local finishPad = r.Finish
		if
			finishPad
			and racer.Reached >= #r.Order
			and Rules.OnPad(
				position,
				finishPad.Frame,
				finishPad.Size,
				finishPad.Round,
				cfg.TouchMargin,
				cfg.TouchHeight
			)
		then
			local elapsed = t - r.StartedAt
			if elapsed < cfg.MinSeconds then
				sendBack(r, racer, "TooFast") -- nobody can do the whole course that fast
			else
				finish(r, racer, elapsed)
			end
		end
	end
end

local function onBack(player: Player)
	local r = round
	if not r or not r.Active then
		return
	end
	local racer = r.Racers[player]
	if not racer or racer.Left or racer.Finished then
		return
	end
	local t = now()
	if t < racer.BackReadyAt or not aliveRoot(player) then
		return
	end
	racer.BackReadyAt = t + Config.ObbyRace.BackCooldown
	player:SetAttribute(ATTR.BackReadyAt, racer.BackReadyAt)
	sendBack(r, racer, "Button")
end

backRemote.OnServerEvent:Connect(onBack)

-- The round -------------------------------------------------------------------------------------

-- Stops everything a Spooky Obby round runs and clears what it set. Safe to call any time.
function ObbyRace.Cleanup()
	local r = round
	round = nil
	for _, name in SHARED :: { [string]: string } do
		ReplicatedStorage:SetAttribute(name, nil)
	end
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
	for _, player in r.Participants do
		for _, name in ATTR :: { [string]: string } do
			player:SetAttribute(name, nil)
		end
		if player.Parent == Players then
			SprintService.Slow(player, 1, 0) -- (never left frozen)
		end
	end
end

local function result(r: Round): Types.RoundResult
	local cfg = Config.ObbyRace
	local text = cfg.Text
	local multiplier = r.Settings.CoinMultiplier or 1
	local list: { Racer } = {}
	for _, player in r.Participants do
		local racer = r.Racers[player]
		if racer and player.Parent == Players then
			table.insert(list, racer)
		end
	end
	table.sort(list, function(a, b)
		return Rules.Sort(standing(a), standing(b))
	end)
	local rows: { Types.ResultRow } = {}
	for _, racer in list do
		local points, coins = Rules.Reward({
			Finished = racer.Finished,
			Place = racer.Place,
			Checkpoints = racer.Reached,
		}, cfg.Rewards :: any, multiplier)
		table.insert(rows, {
			UserId = racer.Player.UserId,
			Name = racer.Player.DisplayName,
			Score = points,
			Pumpkins = points,
			Coins = coins,
			Survived = racer.Finished,
			Top = racer.Finished and racer.Place == 1,
			Badge = if racer.Finished
				then text.BadgePlace:format(Rules.Ordinal(racer.Place))
				elseif racer.Reached > 0 then text.BadgeCheckpoint:format(racer.Reached)
				else text.BadgeStart,
			Stat = if racer.Finished
				then text.StatTime:format(ParkourLogic.FormatTime(racer.Time))
				else nil,
		})
	end
	local winner = r.Finishers[1]
	return {
		Rows = rows,
		ScoreLabel = text.ScoreLabel,
		Winner = if winner then text.WinnerOne:format(winner.DisplayName) else text.WinnerNone,
		MvpLine = text.MvpLine,
	}
end

function ObbyRace.Run(ctx: Types.RoundContext): Types.RoundResult
	ObbyRace.Cleanup()
	local cfg = Config.ObbyRace
	local difficulty = if cfg.Difficulty[ctx.Difficulty] then ctx.Difficulty else "Easy"
	local settings = Rules.DifficultyOf(cfg.Difficulty, difficulty)
	local map = ctx.Map
	local floor = map.Floor

	-- Only this difficulty's pieces stay.
	for _, instance in CollectionService:GetTagged(Tags.ObbyVariant) do
		if
			instance:IsDescendantOf(map.Model)
			and instance:GetAttribute(PARTS.Only) ~= difficulty
		then
			instance:Destroy()
		end
	end

	local r: Round = {
		Ctx = ctx,
		Difficulty = difficulty,
		Settings = settings,
		Participants = table.clone(ctx.Players),
		Racers = {},
		Order = {},
		Finish = nil,
		Hazards = {},
		Sweepers = {},
		PlazaTop = ParkourLogic.TopY(floor.CFrame, floor.Size),
		Forward = Vector3.new(0, 0, 1),
		Finishers = {},
		Threads = {},
		Connections = {},
		Active = false,
		StartedAt = now(),
		EndsAt = now() + cfg.IntroSeconds + settings.TimeLimit,
		Rng = Random.new(),
	}
	round = r

	-- The working parts, by tag.
	local byIndex: { [number]: BasePart } = {}
	local indices: { number } = {}
	for _, part in tagged(map.Model, Tags.ObbyCheckpoint) do
		local index = part:GetAttribute(PARTS.Index)
		if typeof(index) == "number" and not byIndex[index] then
			byIndex[index] = part
			table.insert(indices, index)
		end
	end
	for _, index in ParkourLogic.Order(indices) do
		table.insert(r.Order, padOf(byIndex[index], index))
	end
	local finishes = tagged(map.Model, Tags.ObbyFinish)
	if finishes[1] then
		r.Finish = padOf(finishes[1], 0)
	else
		warn("[ObbyRace] The map has no part tagged ObbyFinish, so nobody can finish.")
	end
	for _, part in tagged(map.Model, Tags.ObbyHazard) do
		table.insert(r.Hazards, padOf(part, 0))
	end
	for _, part in tagged(map.Model, Tags.ObbySweeper) do
		local center = part:GetAttribute(PARTS.Center)
		local base = part:GetAttribute(PARTS.BaseSpeed)
		local phase = part:GetAttribute(PARTS.Phase)
		local speed = (if typeof(base) == "number" then base else 60) * settings.SweeperSpeed
		part:SetAttribute(PARTS.Speed, speed)
		table.insert(r.Sweepers, {
			Part = part,
			Center = if typeof(center) == "Vector3" then center else part.Position,
			Speed = speed,
			Phase = if typeof(phase) == "number" then phase else 0,
			Size = part.Size,
		})
	end
	local towards = (
		if r.Order[1]
			then r.Order[1].Frame.Position
			elseif r.Finish then r.Finish.Frame.Position
			else floor.Position + Vector3.new(0, 0, 1)
	) - floor.Position
	local flat = Vector3.new(towards.X, 0, towards.Z)
	if flat.Magnitude > 1e-3 then
		r.Forward = flat.Unit
	end

	-- Racers on the plaza.
	local t0 = now()
	for i, player in r.Participants do
		local spawns = map.Spawns
		local racer: Racer = {
			Player = player,
			Reached = 0,
			ReachedAt = t0,
			Speed = SpeedCheck.new(),
			Finished = false,
			Place = 0,
			Time = 0,
			BackReadyAt = 0,
			Spawn = if #spawns > 0 then spawns[(i - 1) % #spawns + 1] else nil,
			Left = false,
		}
		r.Racers[player] = racer
		player:SetAttribute(ATTR.Checkpoint, 0)
		player:SetAttribute(ATTR.Total, #r.Order)
		player:SetAttribute(ATTR.Back, 0)
		player:SetAttribute(ATTR.BackReadyAt, 0)
		if ctx.AliveHumanoid(player) then
			sendBack(r, racer, nil)
			SprintService.Slow(player, 0, cfg.IntroSeconds)
		end
	end
	ReplicatedStorage:SetAttribute(SHARED.Finished, 0)
	rerank(r)

	-- Respawns come back at their checkpoint; leavers drop out.
	for _, player in r.Participants do
		table.insert(
			r.Connections,
			player.CharacterAdded:Connect(function(character)
				track(
					r,
					task.spawn(function()
						character:WaitForChild("HumanoidRootPart", 10)
						task.wait() -- (after Roblox has put the character at a spawn)
						local racer = r.Racers[player]
						if round ~= r or not racer or racer.Left then
							return
						end
						sendBack(r, racer, nil)
						if not r.Active then
							SprintService.Slow(player, 0, math.max(r.StartedAt - now(), 0.1))
						end
					end)
				)
			end)
		)
	end
	table.insert(
		r.Connections,
		Players.PlayerRemoving:Connect(function(player)
			local racer = r.Racers[player]
			if racer then
				racer.Left = true
				rerank(r)
			end
		end)
	)

	-- Get ready: everyone waits on the plaza.
	r.StartedAt = now() + cfg.IntroSeconds
	ctx.Countdown("Get ready", cfg.IntroSeconds)

	-- GO!
	local start = now()
	r.StartedAt = start
	r.EndsAt = start + settings.TimeLimit
	r.Active = true
	ReplicatedStorage:SetAttribute(SHARED.StartedAt, start)
	for player, racer in r.Racers do
		if player.Parent == Players then
			SprintService.Slow(player, 1, 0)
		end
		-- Still measured from their plaza spot (set by sendBack): nobody could walk during
		-- "Get ready", so a cheat that moved them then is caught on the first check.
		SpeedCheck.Reset(racer.Speed, racer.Speed.Last, start)
	end
	track(
		r,
		task.spawn(function()
			while round == r and r.Active do
				local ok, err = pcall(sample, r)
				if not ok then
					warn("[ObbyRace] Position check failed: " .. tostring(err))
				end
				task.wait(cfg.SampleSeconds)
			end
		end)
	)
	local shown = -1
	while round == r do
		local left = r.EndsAt - now()
		if left <= 0 or not racing(r) then
			break
		end
		local seconds = math.ceil(left)
		if seconds ~= shown then
			shown = seconds
			ctx.SetState("Playing", seconds)
		end
		task.wait(math.min(0.25, left))
	end
	r.Active = false
	local final = result(r)
	ObbyRace.Cleanup()
	return final
end

return ObbyRace
