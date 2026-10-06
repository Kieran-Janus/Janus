--!strict
--[[
	A parkour course run by the server: the lobby's "Spooky Sky Climb" (ParkourService) and the
	Tormented Tower (TowerService) are each one CourseRunner with their own tags, settings, save
	and remotes. The server decides everything from where characters really are (checked every
	Settings.CheckSeconds), never from what a player's computer says:
	  - standing on a part tagged Tags.Start gets you ready; leaving it starts the clock
	  - parts tagged Tags.Checkpoint (attribute Index) must be touched in Index order
	  - falling below the lowest pad (minus FallMargin), more than FallBelowCheckpoint under the
	    last checkpoint, onto the start pad after a checkpoint, or touching a part tagged
	    Tags.Hazard (slime) sends you back to your last checkpoint (or the start)
	  - reaching a part tagged Tags.Finish after every checkpoint, and no faster than
	    MinSeconds, finishes: the best time and finishes are saved (data[SaveKey]) and
	    def.OnFinish gives the reward
	  - moving sideways or upwards faster than anyone can run (sprinting), jump or climb stops
	    the run ("TooFast", src/shared/SpeedCheck.luau)
	Players in a round (attribute InRound) are left alone; a run stops when you respawn, leave
	the course, join a round or leave the game.

	Remotes (made in Start even when the feature is off):
	  def.Event    server -> client (kind, info): Start, Checkpoint {Index, Count},
	               Back {Reason = "Fall" | "Hazard", Checkpoint}, Missed {Next},
	               NeedCheckpoints, NeedStart, Finish {Time, Best, NewBest, ...OnFinish info},
	               Cancel {Reason = "Stopped" | "TooFast" | "Left" | "TimeUp" | "Cheat"}
	  def.Request  client -> server ("GoToStart" | "Stop") -> (ok, message)
	Player attributes (Prefix = def.Prefix): <Prefix>Run ("" | "Ready" | "Running"),
	  <Prefix>Started (server time), <Prefix>Reached, <Prefix>Best, <Prefix>Runs, plus what
	  def.Publish sets. ReplicatedStorage attribute def.CountAttribute = how many checkpoints.

	CourseRunner.new(def) -> Runner
	  runner.Course() -> CourseParts      the tagged parts right now
	  runner.Check()                       one round of position checks (the loop calls it)
	  runner.Run(player) -> Run?
	  runner.GoToStart(player) -> (ok, message)
	  runner.ToCheckpoint(player, n) -> (ok, message)   admin: on checkpoint n, a run there
	  runner.Saved(player) -> { [string]: any }?        data[SaveKey], fixed up
	  runner.Publish(player)               copy the saved numbers onto the attributes
	  runner.UpdateBoards(leaving?)
	  runner.Stop(player, reason?)
	  runner.Start()                       remotes, slime watching, players and the loop
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpeedCheck = require(ReplicatedStorage.Shared.SpeedCheck)
local DataService = require(script.Parent.Parent.Services.DataService)
local ReadyService = require(script.Parent.Parent.Services.ReadyService)

local CourseRunner = {}

export type Pad = {
	Instance: Instance,
	CFrame: CFrame,
	Size: Vector3,
	Shape: string,
	Index: number,
}

export type CourseParts = {
	Starts: { Pad },
	Checkpoints: { Pad },
	Finishes: { Pad },
	Hazards: { Pad },
	Order: { number }, -- checkpoint Index values in the order they must be touched
	FallY: number, -- feet below this height = fell
}

export type Run = {
	State: string, -- "Ready" (on the start pad) or "Running"
	Started: number, -- workspace:GetServerTimeNow() when the clock started
	Reached: number, -- checkpoints reached, in order
	Character: Model,
	Speed: SpeedCheck.Check, -- anti-teleport: where they were at the last checks (os.clock())
	GraceUntil: number, -- os.clock(): ignore falls and slime until then (just sent back)
	Hinted: number?, -- the skipped checkpoint we last told them about
	FinishHinted: boolean,
}

-- What a course's settings must have (Config.Parkour has all of them).
export type Settings = {
	CheckSeconds: number,
	FallMargin: number,
	FallBelowCheckpoint: number,
	FallGraceSeconds: number,
	TouchMargin: number,
	TouchHeight: number,
	StartHeight: number,
	HazardHeight: number,
	TeleportGraceSeconds: number,
	LeaveDistance: number,
	SpeedTolerance: number,
	SpeedSlack: number,
	MaxRiseSpeed: number,
	RiseSlack: number,
	SpeedWindowSeconds: number,
	RequestCooldown: number,
	HintSeconds: number,
	LobbyRadius: number,
	BoardRows: number,
	MinSeconds: number,
	MaxRunSeconds: number,
	Text: { [string]: string },
}

export type Def = {
	Name: string, -- for warnings: "[Name] ..."
	Feature: string, -- its Config.Features switch
	Settings: () -> Settings, -- read every time (so tests and tweaks apply at once)
	Tags: { Start: string, Checkpoint: string, Finish: string, Hazard: string, Board: string? },
	Prefix: string, -- player attributes <Prefix>Run, <Prefix>Best...
	SaveKey: string, -- data[SaveKey]
	SaveNumbers: { string }, -- the numbers kept in it (Best and Runs at least)
	CountAttribute: string, -- ReplicatedStorage attribute: how many checkpoints
	Event: string, -- remote names
	Request: string,
	-- The reward: called after a counted finish (Best and Runs already saved). Returns extra
	-- fields for the Finish message.
	OnFinish: (player: Player, time: number, saved: { [string]: any }) -> { [string]: any },
	Publish: ((player: Player, saved: { [string]: any }) -> ())?, -- more attributes
	BoardGui: ((part: BasePart) -> SurfaceGui)?, -- the best-times board(s), tagged Tags.Board
}

export type Runner = {
	Course: () -> CourseParts,
	Check: () -> (),
	Run: (player: Player) -> Run?,
	GoToStart: (player: Player) -> (boolean, string),
	ToCheckpoint: (player: Player, n: number) -> (boolean, string),
	Saved: (player: Player) -> { [string]: any }?,
	Publish: (player: Player) -> (),
	UpdateBoards: (leaving: Player?) -> (),
	Stop: (player: Player, reason: string?) -> (),
	Start: () -> (),
}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function shapeOf(part: BasePart): string
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif part.Shape == Enum.PartType.Ball then
			return "Ball"
		end
	end
	return "Block"
end

local function padOf(instance: Instance): Pad?
	if not instance:IsDescendantOf(workspace) then
		return nil
	end
	if instance:IsA("BasePart") then
		return {
			Instance = instance :: Instance,
			CFrame = instance.CFrame,
			Size = instance.Size,
			Shape = shapeOf(instance),
			Index = 0,
		}
	elseif instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return {
			Instance = instance :: Instance,
			CFrame = cframe,
			Size = size,
			Shape = "Block",
			Index = 0,
		}
	end
	return nil
end

local function padsTagged(tag: string): { Pad }
	local pads: { Pad } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		local pad = padOf(instance)
		if pad then
			table.insert(pads, pad)
		end
	end
	return pads
end

type Body = { Character: Model, Humanoid: Humanoid, Root: BasePart }

local function bodyOf(player: Player): Body?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return { Character = character, Humanoid = humanoid, Root = root }
	end
	return nil
end

-- How far the root part is above the feet.
local function standHeight(body: Body): number
	if body.Humanoid.RigType == Enum.HumanoidRigType.R6 then
		return body.Root.Size.Y / 2 + 2 -- R6 legs are 2 studs, HipHeight is 0
	end
	return body.Root.Size.Y / 2 + body.Humanoid.HipHeight
end

-- Puts a character on top of `pad`, facing the way the pad faces.
local function teleport(body: Body, pad: Pad)
	local top = ParkourLogic.TopY(pad.CFrame, pad.Size)
	local look = pad.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local position = Vector3.new(pad.CFrame.X, top + standHeight(body) + 0.3, pad.CFrame.Z)
	body.Character:PivotTo(CFrame.lookAt(position, position + flat.Unit))
	body.Root.AssemblyLinearVelocity = Vector3.zero
end

function CourseRunner.new(def: Def): Runner
	local runner = {} :: Runner
	local runs: { [Player]: Run } = {}
	local lastRequest: { [Player]: number } = {}
	local lastHint: { [Player]: number } = {}
	local playerConnections: { [Player]: { RBXScriptConnection } } = {}
	local hazardConnections: { [Instance]: RBXScriptConnection } = {}
	local warnedIndex: { [Instance]: boolean } = {}
	local event: RemoteEvent? = nil
	local started = false
	local prefix = def.Prefix

	local function settings(): Settings
		return def.Settings()
	end

	local function fire(player: Player, kind: string, info: { [string]: any }?)
		local remote = event
		if remote and player.Parent == Players then
			remote:FireClient(player, kind, info or {})
		end
	end

	-- How fast a climber can really move (sprinting, VIP).
	local function speedLimits(): SpeedCheck.Limits
		local cfg = settings()
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

	function runner.Course(): CourseParts
		local tags = def.Tags
		local starts = padsTagged(tags.Start)
		local finishes = padsTagged(tags.Finish)
		local checkpoints: { Pad } = {}
		local indices: { number } = {}
		for _, pad in padsTagged(tags.Checkpoint) do
			local index = pad.Instance:GetAttribute("Index")
			if type(index) ~= "number" then
				if not warnedIndex[pad.Instance] then
					warnedIndex[pad.Instance] = true
					warn(
						("[%s] %s is tagged %s but has no number attribute Index, so it is ignored."):format(
							def.Name,
							pad.Instance:GetFullName(),
							tags.Checkpoint
						)
					)
				end
				continue
			end
			pad.Index = index
			table.insert(checkpoints, pad)
			table.insert(indices, index)
		end
		local lowest = math.huge
		for _, list in { starts, checkpoints, finishes } do
			for _, pad in list do
				lowest = math.min(lowest, ParkourLogic.TopY(pad.CFrame, pad.Size))
			end
		end
		return {
			Starts = starts,
			Checkpoints = checkpoints,
			Finishes = finishes,
			Hazards = padsTagged(tags.Hazard),
			Order = ParkourLogic.Order(indices),
			FallY = if lowest < math.huge then lowest - settings().FallMargin else -math.huge,
		}
	end

	local function inside(position: Vector3, pad: Pad, margin: number, height: number): boolean
		return ReadyService.Inside(position, pad.CFrame, pad.Size, pad.Shape, margin, height)
	end

	local function onAny(position: Vector3, pads: { Pad }): boolean
		local cfg = settings()
		for _, pad in pads do
			if inside(position, pad, cfg.TouchMargin, cfg.TouchHeight) then
				return true
			end
		end
		return false
	end

	local function onStartPad(position: Vector3, pads: { Pad }): boolean
		local cfg = settings()
		for _, pad in pads do
			if inside(position, pad, cfg.TouchMargin, cfg.StartHeight) then
				return true
			end
		end
		return false
	end

	local function nearestDistance(position: Vector3, course: CourseParts): number
		local best = math.huge
		for _, list in { course.Starts, course.Checkpoints, course.Finishes } do
			for _, pad in list do
				best = math.min(best, (pad.CFrame.Position - position).Magnitude)
			end
		end
		return best
	end

	-- Data ------------------------------------------------------------------------------------

	function runner.Saved(player: Player): { [string]: any }?
		local data = DataService.Get(player)
		if not data then
			return nil
		end
		local saved = data[def.SaveKey]
		if type(saved) ~= "table" then
			saved = {}
			data[def.SaveKey] = saved
		end
		for _, key in def.SaveNumbers do
			if type(saved[key]) ~= "number" or saved[key] ~= saved[key] then
				saved[key] = 0
			end
		end
		return saved
	end

	function runner.Publish(player: Player)
		local saved = runner.Saved(player)
		if not saved then
			return
		end
		player:SetAttribute(prefix .. "Best", saved.Best)
		player:SetAttribute(prefix .. "Runs", saved.Runs)
		if def.Publish then
			def.Publish(player, saved)
		end
	end

	-- The board(s): the fastest saved bests of the players in this server.
	function runner.UpdateBoards(leaving: Player?)
		local boardTag = def.Tags.Board
		local boardGui = def.BoardGui
		if not (boardTag and boardGui) then
			return
		end
		local cfg = settings()
		local text = cfg.Text
		local entries: { { Name: string, Time: number } } = {}
		for _, player in Players:GetPlayers() do
			if player == leaving then
				continue
			end
			local data = DataService.Get(player)
			local saved = data and data[def.SaveKey]
			local best = if type(saved) == "table" then saved.Best else nil
			if type(best) == "number" and best > 0 then
				table.insert(entries, { Name = player.DisplayName, Time = best })
			end
		end
		table.sort(entries, function(a, b)
			return a.Time < b.Time
		end)
		for _, instance in CollectionService:GetTagged(boardTag) do
			if not (instance:IsA("BasePart") and instance:IsDescendantOf(workspace)) then
				continue
			end
			local gui = boardGui(instance)
			for i = 1, math.max(cfg.BoardRows, 1) do
				local row = gui:FindFirstChild("Row" .. i)
				if row and row:IsA("TextLabel") then
					local entry = entries[i]
					if entry then
						row.Text =
							text.BoardRow:format(i, entry.Name, ParkourLogic.FormatTime(entry.Time))
					else
						row.Text = if i == 1 then text.BoardEmpty else ""
					end
				end
			end
		end
	end

	-- Runs ------------------------------------------------------------------------------------

	local function setRunAttributes(player: Player, run: Run?)
		player:SetAttribute(prefix .. "Run", if run then run.State else "")
		player:SetAttribute(
			prefix .. "Started",
			if run and run.State == "Running" then run.Started else 0
		)
		player:SetAttribute(prefix .. "Reached", if run then run.Reached else 0)
	end

	function runner.Stop(player: Player, reason: string?)
		if not runs[player] then
			return
		end
		runs[player] = nil
		setRunAttributes(player, nil)
		if reason then
			fire(player, "Cancel", { Reason = reason })
		end
	end
	local stop = runner.Stop

	local function arm(player: Player, character: Model)
		local run: Run = {
			State = "Ready",
			Started = 0,
			Reached = 0,
			Character = character,
			Speed = SpeedCheck.new(),
			GraceUntil = 0,
			Hinted = nil,
			FinishHinted = false,
		}
		runs[player] = run
		setRunAttributes(player, run)
	end

	local function checkpointPad(course: CourseParts, reached: number): Pad?
		local index = course.Order[reached]
		for _, pad in course.Checkpoints do
			if pad.Index == index then
				return pad
			end
		end
		return nil
	end

	-- More than FallBelowCheckpoint studs under the last checkpoint reached: on a course that
	-- spirals up, a fall usually lands on a lower loop, not on the ground.
	local function belowCheckpoint(run: Run, course: CourseParts, feet: number): boolean
		if run.Reached == 0 then
			return false
		end
		local pad = checkpointPad(course, run.Reached)
		return pad ~= nil
			and feet < ParkourLogic.TopY(pad.CFrame, pad.Size) - settings().FallBelowCheckpoint
	end

	-- Fell or touched slime: back to the last checkpoint reached (or the start pad).
	local function sendBack(
		player: Player,
		run: Run,
		body: Body,
		course: CourseParts,
		reason: string
	)
		local target: Pad? = if run.Reached > 0 then checkpointPad(course, run.Reached) else nil
		if not target then
			run.Reached = 0
			target = course.Starts[1]
		end
		if not target then
			stop(player, "Left")
			return
		end
		teleport(body, target)
		run.GraceUntil = os.clock() + settings().TeleportGraceSeconds
		SpeedCheck.Reset(run.Speed, nil, os.clock()) -- the server moved them: not a teleport
		run.FinishHinted = false
		if run.Reached == 0 then
			run.State = "Ready" -- back on the start pad: the clock starts again when they leave it
		end
		setRunAttributes(player, run)
		fire(player, "Back", { Reason = reason, Checkpoint = run.Reached })
	end

	local function finish(player: Player, run: Run)
		local cfg = settings()
		local elapsed = serverNow() - run.Started
		stop(player, nil)
		if elapsed < cfg.MinSeconds then
			warn(
				("[%s] %s finished in %.1f s (less than MinSeconds = %d): not counted."):format(
					def.Name,
					player.Name,
					elapsed,
					cfg.MinSeconds
				)
			)
			fire(player, "Cancel", { Reason = "Cheat" })
			return
		end
		local saved = runner.Saved(player)
		if not saved then
			return
		end
		local time = math.floor(elapsed * 100 + 0.5) / 100
		saved.Runs += 1
		local newBest = ParkourLogic.IsNewBest(saved.Best, time)
		if newBest then
			saved.Best = time
		end
		local info: { [string]: any } = { Time = time, Best = saved.Best, NewBest = newBest }
		local ok, extra = pcall(def.OnFinish, player, time, saved)
		if ok and type(extra) == "table" then
			for key, value in extra do
				info[key] = value
			end
		elseif not ok then
			warn(("[%s] the finish reward failed: %s"):format(def.Name, tostring(extra)))
		end
		runner.Publish(player)
		runner.UpdateBoards()
		fire(player, "Finish", info)
	end

	-- One player's position check.
	local function checkPlayer(player: Player, course: CourseParts)
		local cfg = settings()
		local run: Run? = runs[player]
		if player:GetAttribute("InRound") == true then
			stop(player, nil) -- the round has them now
			return
		end
		local body = bodyOf(player)
		if not body then
			stop(player, nil)
			return
		end
		if run and run.Character ~= body.Character then
			stop(player, nil) -- respawned
			run = nil
		end
		local position = body.Root.Position
		local feet = position.Y - standHeight(body)
		local onStart = onStartPad(position, course.Starts)
		if not run then
			if onStart and player:GetAttribute("DataReady") == true and #course.Finishes > 0 then
				arm(player, body.Character)
			elseif onAny(position, course.Checkpoints) then
				-- Climbed on without starting: tell them where the clock starts (now and then).
				-- (Not on the finish: that is where everyone stands just after finishing.)
				local now = os.clock()
				if now - (lastHint[player] or -math.huge) >= cfg.HintSeconds then
					lastHint[player] = now
					fire(player, "NeedStart")
				end
			end
			return
		end

		local clock = os.clock()
		if clock < run.GraceUntil then
			-- Just sent back: the player's computer may report the old spot for a moment.
			SpeedCheck.Reset(run.Speed, nil, clock)
			return
		end

		-- Teleport check: nobody walks, jumps or climbs this fast (src/shared/SpeedCheck.luau).
		if SpeedCheck.Step(run.Speed, position, clock, speedLimits()) then
			stop(player, "TooFast")
			return
		end

		if run.State == "Ready" then
			if onStart then
				return
			end
			if feet < course.FallY then
				stop(player, nil) -- stepped off the pad onto the ground: not playing
				return
			end
			run.State = "Running"
			run.Started = serverNow()
			setRunAttributes(player, run)
			fire(player, "Start", { Started = run.Started })
			return
		end

		-- Running.
		if onStart then
			if run.Reached > 0 then
				-- Fell from higher up onto the start pad (it sits under the course): back to the
				-- last checkpoint, never a fresh start. ("Go to start" restarts.)
				sendBack(player, run, body, course, "Fall")
			else
				arm(player, body.Character) -- back on the start pad: ready to start again
			end
			return
		end
		local elapsed = serverNow() - run.Started
		if elapsed > cfg.MaxRunSeconds then
			stop(player, "TimeUp")
			return
		end
		for _, hazard in course.Hazards do
			if inside(position, hazard, 0.3, cfg.HazardHeight) then
				sendBack(player, run, body, course, "Hazard")
				return
			end
		end
		if feet < course.FallY or belowCheckpoint(run, course, feet) then
			if run.Reached == 0 and elapsed < cfg.FallGraceSeconds then
				stop(player, nil) -- walked off the start pad: not playing
			else
				sendBack(player, run, body, course, "Fall")
			end
			return
		end
		if nearestDistance(position, course) > cfg.LeaveDistance then
			stop(player, "Left")
			return
		end
		for _, pad in course.Checkpoints do
			if not inside(position, pad, cfg.TouchMargin, cfg.TouchHeight) then
				continue
			end
			local result = ParkourLogic.Touch(course.Order, run.Reached, pad.Index)
			if result == "Next" then
				run.Reached += 1
				run.Hinted = nil
				run.FinishHinted = false
				setRunAttributes(player, run)
				fire(player, "Checkpoint", { Index = run.Reached, Count = #course.Order })
			elseif result == "Skipped" and run.Hinted ~= pad.Index then
				run.Hinted = pad.Index
				fire(player, "Missed", { Next = run.Reached + 1 })
			end
		end
		for _, pad in course.Finishes do
			if inside(position, pad, cfg.TouchMargin, cfg.TouchHeight) then
				if ParkourLogic.CanFinish(course.Order, run.Reached) then
					finish(player, run)
				elseif not run.FinishHinted then
					run.FinishHinted = true
					fire(player, "NeedCheckpoints", { Next = run.Reached + 1 })
				end
				return
			end
		end
	end

	function runner.Check()
		local course = runner.Course()
		if ReplicatedStorage:GetAttribute(def.CountAttribute) ~= #course.Order then
			ReplicatedStorage:SetAttribute(def.CountAttribute, #course.Order)
		end
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(checkPlayer :: any, player, course)
			if not ok then
				warn(("[%s] %s"):format(def.Name, tostring(err)))
			end
		end
	end

	function runner.Run(player: Player): Run?
		return runs[player]
	end

	-- Slime also counts when it is touched between two checks (a fast runner).
	local function watchHazard(instance: Instance)
		if hazardConnections[instance] or not instance:IsA("BasePart") then
			return
		end
		hazardConnections[instance] = instance.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			local run = player and runs[player]
			if not (player and run and run.State == "Running" and os.clock() >= run.GraceUntil) then
				return
			end
			local body = bodyOf(player)
			if body and body.Character == run.Character then
				sendBack(player, run, body, runner.Course(), "Hazard")
			end
		end)
	end

	local function unwatchHazard(instance: Instance)
		local connection = hazardConnections[instance]
		if connection then
			connection:Disconnect()
			hazardConnections[instance] = nil
		end
	end

	-- Checks the player may be moved to the course (in the lobby, not in a round).
	local function movable(player: Player): (Body?, string)
		local text = settings().Text
		if player:GetAttribute("InRound") == true then
			return nil, text.InRound
		end
		local body = bodyOf(player)
		if not body then
			return nil, text.NotInLobby
		end
		local center: Vector3 = Config.Hub.Center
		local offset = body.Root.Position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > settings().LobbyRadius then
			return nil, text.NotInLobby
		end
		return body, ""
	end

	local function moveTo(player: Player, pad: Pad): (boolean, string)
		local text = settings().Text
		if workspace.StreamingEnabled then
			pcall(function()
				player:RequestStreamAroundAsync(pad.CFrame.Position, 2)
			end)
		end
		-- (Streaming can take a moment: check again that they are still here and not in a round.)
		local fresh = bodyOf(player)
		if not fresh or player:GetAttribute("InRound") == true then
			return false, text.InRound
		end
		teleport(fresh, pad)
		return true, text.Teleported
	end

	-- Teleports a player in the lobby to the start pad. Returns (ok, message for the player).
	function runner.GoToStart(player: Player): (boolean, string)
		local body, why = movable(player)
		if not body then
			return false, why
		end
		local start = runner.Course().Starts[1]
		if not start then
			return false, settings().Text.NoCourse
		end
		stop(player, nil)
		return moveTo(player, start)
	end

	-- Admin: onto checkpoint n with a run that has reached it (its clock started MinSeconds ago,
	-- so a quick test finish still counts).
	function runner.ToCheckpoint(player: Player, n: number): (boolean, string)
		local body, why = movable(player)
		if not body then
			return false, why
		end
		local course = runner.Course()
		local pad = checkpointPad(course, n)
		if not pad then
			return false, settings().Text.NoCourse
		end
		stop(player, nil)
		local ok, message = moveTo(player, pad)
		if not ok then
			return ok, message
		end
		local fresh = bodyOf(player)
		if fresh then
			arm(player, fresh.Character)
			local run = runs[player]
			run.State = "Running"
			run.Reached = n
			run.Started = serverNow() - settings().MinSeconds
			run.GraceUntil = os.clock() + settings().TeleportGraceSeconds
			setRunAttributes(player, run)
			fire(player, "Start", { Started = run.Started })
		end
		return true, message
	end

	local function onRequest(player: Player, action: unknown): (boolean, string)
		local features = Config.Features :: any
		if not features[def.Feature] or type(action) ~= "string" then
			return false, ""
		end
		local cfg = settings()
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < cfg.RequestCooldown then
			return false, cfg.Text.Wait
		end
		lastRequest[player] = now
		if action == "GoToStart" then
			return runner.GoToStart(player)
		elseif action == "Stop" then
			stop(player, "Stopped")
			return true, cfg.Text.Stopped
		end
		return false, ""
	end

	-- Players -----------------------------------------------------------------------------------

	local function onPlayer(player: Player)
		if playerConnections[player] then
			return
		end
		setRunAttributes(player, nil)
		local list: { RBXScriptConnection } = {}
		table.insert(
			list,
			player:GetAttributeChangedSignal("DataReady"):Connect(function()
				runner.Publish(player)
				runner.UpdateBoards()
			end)
		)
		table.insert(
			list,
			player.CharacterAdded:Connect(function()
				stop(player, nil)
			end)
		)
		playerConnections[player] = list
		if player:GetAttribute("DataReady") then
			runner.Publish(player)
			runner.UpdateBoards()
		end
	end

	local function onLeave(player: Player)
		runs[player] = nil
		lastRequest[player] = nil
		lastHint[player] = nil
		local list = playerConnections[player]
		playerConnections[player] = nil
		if list then
			for _, connection in list do
				connection:Disconnect()
			end
		end
		runner.UpdateBoards(player)
	end

	-- Remotes first, even when switched off, so a client never waits for them forever. Returns
	-- false (and does nothing more) while the feature is off.
	function runner.Start()
		event = Remotes.Event(def.Event)
		Remotes.Function(def.Request).OnServerInvoke = onRequest
		local features = Config.Features :: any
		if not features[def.Feature] or started then
			return
		end
		started = true

		local tags = def.Tags
		for _, instance in CollectionService:GetTagged(tags.Hazard) do
			watchHazard(instance)
		end
		CollectionService:GetInstanceAddedSignal(tags.Hazard):Connect(watchHazard)
		CollectionService:GetInstanceRemovedSignal(tags.Hazard):Connect(unwatchHazard)
		local boardTag = tags.Board
		if boardTag then
			-- A board built later (F8 > Rebuild hub) shows the times straight away.
			CollectionService:GetInstanceAddedSignal(boardTag):Connect(function()
				task.defer(runner.UpdateBoards)
			end)
		end

		Players.PlayerAdded:Connect(onPlayer)
		Players.PlayerRemoving:Connect(onLeave)
		for _, player in Players:GetPlayers() do
			onPlayer(player)
		end
		runner.UpdateBoards()

		task.spawn(function()
			while true do
				task.wait(settings().CheckSeconds)
				local checked, problem = pcall(runner.Check :: any)
				if not checked then
					warn(("[%s] %s"):format(def.Name, tostring(problem)))
				end
			end
		end)
	end

	return runner
end

return CourseRunner
