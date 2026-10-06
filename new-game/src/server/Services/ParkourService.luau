--!strict
--[[
	PARKOUR: "Spooky Sky Climb" in the lobby (settings: Config.Parkour; on/off:
	Config.Features.Parkour; the course is built by src/server/Hub/Sections/Parkour.luau).

	The server decides everything from where characters really are (checked every
	Config.Parkour.CheckSeconds), never from what a player's computer says:
	  - standing on a part tagged ParkourStart gets you ready; leaving it starts the clock
	  - parts tagged ParkourCheckpoint (attribute Index) must be touched in Index order
	  - falling below the lowest pad (minus FallMargin), or touching a part tagged
	    ParkourHazard (green slime), sends you back to your last checkpoint (or the start)
	  - reaching a part tagged ParkourFinish after every checkpoint, and no faster than
	    MinSeconds, finishes: best time and finishes are saved (data.Parkour) and
	    Reward.Coins are given once every Reward.CooldownHours
	Players in a round (attribute InRound) are left alone; a run stops when you respawn,
	leave the course, join a round or leave the game. Parts are found by tag only, so pieces
	can be moved, resized or copied in Studio. A saved hub with no course gets one built.

	Remotes (made in Start even when the feature is off):
	  ParkourEvent    server -> client (kind, info): Start, Checkpoint {Index, Count},
	                  Back {Reason = "Fall" | "Hazard", Checkpoint}, Missed {Next},
	                  NeedCheckpoints, NeedStart (on a checkpoint without a run),
	                  Finish {Time, Best, NewBest, Coins, Wait},
	                  Cancel {Reason = "Stopped" | "TooFast" | "Left" | "TimeUp" | "Cheat"}
	  ParkourRequest  client -> server ("GoToStart" | "Stop") -> (ok, message)
	Player attributes: ParkourRun ("" | "Ready" | "Running"), ParkourStarted (server time),
	  ParkourReached, ParkourBest (seconds, 0 = never), ParkourRuns, ParkourRewardAt
	  (server time when coins can be won again, 0 = now).
	ReplicatedStorage attribute: ParkourCheckpoints (how many checkpoints the course has).
	Admin (F8): "Parkour: teleport to start", "Parkour: reset my best/cooldown".

	ParkourService.GoToStart(player) -> (boolean, string)
	ParkourService.Course() -> CourseParts    the tagged parts right now
	ParkourService.Run(player) -> Run?        the player's run (for tests)
	ParkourService.Check()                    one round of position checks (the loop calls it)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local HubService = require(script.Parent.HubService)
local ReadyService = require(script.Parent.ReadyService)
local ShopService = require(script.Parent.ShopService)
local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)
local ParkourSection = require(script.Parent.Parent.Hub.Sections.Parkour)

local ParkourService = {}

local cfg = Config.Parkour
local text = cfg.Text

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
	LastPosition: Vector3?,
	LastCheck: number, -- os.clock() of the last check
	GraceUntil: number, -- os.clock(): ignore falls and slime until then (just sent back)
	Hinted: number?, -- the skipped checkpoint we last told them about
	FinishHinted: boolean,
}

local runs: { [Player]: Run } = {}
local lastRequest: { [Player]: number } = {}
local lastHint: { [Player]: number } = {} -- os.clock() of the last "start on the START pad" hint
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local hazardConnections: { [Instance]: RBXScriptConnection } = {}
local event: RemoteEvent? = nil
local warnedIndex: { [Instance]: boolean } = {}
local started = false

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function fire(player: Player, kind: string, info: { [string]: any }?)
	local remote = event
	if remote and player.Parent == Players then
		remote:FireClient(player, kind, info or {})
	end
end

-- The tagged parts ---------------------------------------------------------------------------

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

function ParkourService.Course(): CourseParts
	local starts = padsTagged(Tags.ParkourStart)
	local finishes = padsTagged(Tags.ParkourFinish)
	local checkpoints: { Pad } = {}
	local indices: { number } = {}
	for _, pad in padsTagged(Tags.ParkourCheckpoint) do
		local index = pad.Instance:GetAttribute("Index")
		if type(index) ~= "number" then
			if not warnedIndex[pad.Instance] then
				warnedIndex[pad.Instance] = true
				warn(
					("[ParkourService] %s is tagged ParkourCheckpoint but has no number attribute Index, so it is ignored."):format(
						pad.Instance:GetFullName()
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
		Hazards = padsTagged(Tags.ParkourHazard),
		Order = ParkourLogic.Order(indices),
		FallY = if lowest < math.huge then lowest - cfg.FallMargin else -math.huge,
	}
end

local function inside(position: Vector3, pad: Pad, margin: number, height: number): boolean
	return ReadyService.Inside(position, pad.CFrame, pad.Size, pad.Shape, margin, height)
end

-- Standing on any of `pads`.
local function onAny(position: Vector3, pads: { Pad }): boolean
	for _, pad in pads do
		if inside(position, pad, cfg.TouchMargin, cfg.TouchHeight) then
			return true
		end
	end
	return false
end

-- On (or jumping on) any start pad.
local function onStartPad(position: Vector3, pads: { Pad }): boolean
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

-- Characters ----------------------------------------------------------------------------------

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

-- Data ----------------------------------------------------------------------------------------

type Saved = { Best: number, LastReward: number, Runs: number }

local function savedOf(player: Player): Saved?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local saved = data.Parkour
	if type(saved) ~= "table" then
		saved = {}
		data.Parkour = saved
	end
	for _, key in { "Best", "LastReward", "Runs" } do
		if type(saved[key]) ~= "number" or saved[key] ~= saved[key] then
			saved[key] = 0
		end
	end
	return saved :: Saved
end

-- Copies the saved numbers onto the player's attributes (the menu tile shows them).
local function publish(player: Player)
	local saved = savedOf(player)
	if not saved then
		return
	end
	local wait = ParkourLogic.RewardWait(saved.LastReward, os.time(), cfg.Reward.CooldownHours)
	player:SetAttribute("ParkourBest", saved.Best)
	player:SetAttribute("ParkourRuns", saved.Runs)
	player:SetAttribute("ParkourRewardAt", if wait > 0 then serverNow() + wait else 0)
end

-- The board(s) at the start: the fastest saved bests of the players in this server.
local function updateBoards(leaving: Player?)
	local entries: { { Name: string, Time: number } } = {}
	for _, player in Players:GetPlayers() do
		if player == leaving then
			continue
		end
		local data = DataService.Get(player)
		local saved = data and data.Parkour
		local best = if type(saved) == "table" then saved.Best else nil
		if type(best) == "number" and best > 0 then
			table.insert(entries, { Name = player.DisplayName, Time = best })
		end
	end
	table.sort(entries, function(a, b)
		return a.Time < b.Time
	end)
	for _, instance in CollectionService:GetTagged(Tags.ParkourBoard) do
		if not (instance:IsA("BasePart") and instance:IsDescendantOf(workspace)) then
			continue
		end
		local gui = ParkourSection.BoardGui(instance)
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

-- Runs ----------------------------------------------------------------------------------------

local function setRunAttributes(player: Player, run: Run?)
	player:SetAttribute("ParkourRun", if run then run.State else "")
	player:SetAttribute("ParkourStarted", if run and run.State == "Running" then run.Started else 0)
	player:SetAttribute("ParkourReached", if run then run.Reached else 0)
end

-- Ends a run. A reason tells the player why (none = quietly).
local function stop(player: Player, reason: string?)
	if not runs[player] then
		return
	end
	runs[player] = nil
	setRunAttributes(player, nil)
	if reason then
		fire(player, "Cancel", { Reason = reason })
	end
end

-- On the start pad: ready to go (the clock starts when they leave it).
local function arm(player: Player, character: Model)
	local run: Run = {
		State = "Ready",
		Started = 0,
		Reached = 0,
		Character = character,
		LastPosition = nil,
		LastCheck = os.clock(),
		GraceUntil = 0,
		Hinted = nil,
		FinishHinted = false,
	}
	runs[player] = run
	setRunAttributes(player, run)
end

-- Fell or touched slime: back to the last checkpoint reached (or the start pad).
local function sendBack(player: Player, run: Run, body: Body, course: CourseParts, reason: string)
	local target: Pad? = nil
	if run.Reached > 0 then
		local index = course.Order[run.Reached]
		for _, pad in course.Checkpoints do
			if pad.Index == index then
				target = pad
				break
			end
		end
	end
	if not target then
		run.Reached = 0
		target = course.Starts[1]
	end
	if not target then
		stop(player, "Left")
		return
	end
	teleport(body, target)
	run.GraceUntil = os.clock() + cfg.TeleportGraceSeconds
	run.LastPosition = nil
	run.FinishHinted = false
	if run.Reached == 0 then
		run.State = "Ready" -- back on the start pad: the clock starts again when they leave it
	end
	setRunAttributes(player, run)
	fire(player, "Back", { Reason = reason, Checkpoint = run.Reached })
end

local function finish(player: Player, run: Run)
	local elapsed = serverNow() - run.Started
	stop(player, nil)
	if elapsed < cfg.MinSeconds then
		warn(
			("[ParkourService] %s finished in %.1f s (less than MinSeconds = %d): not counted."):format(
				player.Name,
				elapsed,
				cfg.MinSeconds
			)
		)
		fire(player, "Cancel", { Reason = "Cheat" })
		return
	end
	local saved = savedOf(player)
	if not saved then
		return
	end
	local time = math.floor(elapsed * 100 + 0.5) / 100
	saved.Runs += 1
	local newBest = ParkourLogic.IsNewBest(saved.Best, time)
	if newBest then
		saved.Best = time
	end
	local now = os.time()
	local wait = ParkourLogic.RewardWait(saved.LastReward, now, cfg.Reward.CooldownHours)
	local coins = 0
	if wait <= 0 and cfg.Reward.Coins > 0 then
		coins = cfg.Reward.Coins
		DataService.Add(player, "Coins", coins)
		saved.LastReward = now
		wait = cfg.Reward.CooldownHours * 3600
		pcall(ShopService.Push, player)
	end
	publish(player)
	updateBoards()
	fire(player, "Finish", {
		Time = time,
		Best = saved.Best,
		NewBest = newBest,
		Coins = coins,
		Wait = wait,
	})
end

-- One player's position check.
local function checkPlayer(player: Player, course: CourseParts)
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
		run.LastPosition = nil
		return
	end

	-- Teleport check: nobody walks or jumps this fast.
	local last = run.LastPosition
	if last then
		local moved = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
		local maxSpeed = Config.Player.SprintSpeed
			* Config.Monetization.VipSpeedMultiplier
			* cfg.SpeedTolerance
		if moved > maxSpeed * (clock - run.LastCheck) + cfg.SpeedSlack then
			stop(player, "TooFast")
			return
		end
	end
	run.LastPosition = position
	run.LastCheck = clock

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
		arm(player, body.Character) -- back on the start pad: ready to start again
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
	if feet < course.FallY then
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

function ParkourService.Check()
	local course = ParkourService.Course()
	if ReplicatedStorage:GetAttribute("ParkourCheckpoints") ~= #course.Order then
		ReplicatedStorage:SetAttribute("ParkourCheckpoints", #course.Order)
	end
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(checkPlayer :: any, player, course)
		if not ok then
			warn("[ParkourService] " .. tostring(err))
		end
	end
end

function ParkourService.Run(player: Player): Run?
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
			sendBack(player, run, body, ParkourService.Course(), "Hazard")
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

-- Teleports a player in the lobby to the start pad. Returns (ok, message for the player).
function ParkourService.GoToStart(player: Player): (boolean, string)
	if player:GetAttribute("InRound") == true then
		return false, text.InRound
	end
	local body = bodyOf(player)
	if not body then
		return false, text.NotInLobby
	end
	local center: Vector3 = Config.Hub.Center
	local offset = body.Root.Position - center
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > cfg.LobbyRadius then
		return false, text.NotInLobby
	end
	local start = ParkourService.Course().Starts[1]
	if not start then
		return false, text.NoCourse
	end
	stop(player, nil)
	if workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(start.CFrame.Position, 2)
		end)
	end
	-- (Streaming can take a moment: check again that they are still here and not in a round.)
	local fresh = bodyOf(player)
	if not fresh or player:GetAttribute("InRound") == true then
		return false, text.InRound
	end
	teleport(fresh, start)
	return true, text.Teleported
end

local function onRequest(player: Player, action: unknown): (boolean, string)
	if not Config.Features.Parkour or type(action) ~= "string" then
		return false, ""
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < cfg.RequestCooldown then
		return false, text.Wait
	end
	lastRequest[player] = now
	if action == "GoToStart" then
		return ParkourService.GoToStart(player)
	elseif action == "Stop" then
		stop(player, "Stopped")
		return true, text.Stopped
	end
	return false, ""
end

-- Players -------------------------------------------------------------------------------------

local function onPlayer(player: Player)
	if playerConnections[player] then
		return
	end
	setRunAttributes(player, nil)
	local list: { RBXScriptConnection } = {}
	table.insert(
		list,
		player:GetAttributeChangedSignal("DataReady"):Connect(function()
			publish(player)
			updateBoards()
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
		publish(player)
		updateBoards()
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
	updateBoards(player)
end

-- A saved hub from before the course existed (or baked with the feature off) gets one.
local function ensureCourse()
	for _, instance in CollectionService:GetTagged(Tags.ParkourStart) do
		if instance:IsDescendantOf(workspace) then
			return
		end
	end
	local hub = HubService.Get()
	if not hub then
		return
	end
	HubBuilder.RepairSection(hub, "Parkour")
	warn(
		"[ParkourService] The lobby had no parkour start pad, so the course was built for this server. To keep it, F8 > Rebuild hub or run require(game.ServerScriptService.Server.Tools.Bake).Hub() in edit mode, then save."
	)
end

function ParkourService.Start()
	-- Remotes first, even when switched off, so a client never waits for them forever.
	event = Remotes.Event("ParkourEvent")
	Remotes.Function("ParkourRequest").OnServerInvoke = onRequest
	if not Config.Features.Parkour or started then
		return
	end
	started = true

	local ok, err = pcall(ensureCourse :: any)
	if not ok then
		warn("[ParkourService] Couldn't build the course: " .. tostring(err))
	end

	for _, instance in CollectionService:GetTagged(Tags.ParkourHazard) do
		watchHazard(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.ParkourHazard):Connect(watchHazard)
	CollectionService:GetInstanceRemovedSignal(Tags.ParkourHazard):Connect(unwatchHazard)
	-- A board built later (F8 > Rebuild hub) shows the times straight away.
	CollectionService:GetInstanceAddedSignal(Tags.ParkourBoard):Connect(function()
		task.defer(updateBoards)
	end)

	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(onLeave)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	updateBoards()

	AdminService.Register("ParkourToStart", "Parkour: teleport to start", function(player, _data)
		local done, message = ParkourService.GoToStart(player)
		return if done then "Teleported to the parkour start." else message
	end)
	AdminService.Register("ParkourReset", "Parkour: reset my best/cooldown", function(player, data)
		data.Parkour = { Best = 0, LastReward = 0, Runs = 0 }
		publish(player)
		updateBoards()
		return "Parkour best time, finishes and coin cooldown reset."
	end)
	-- F8 > Reset my save cleared data.Parkour: show the fresh best time and cooldown.
	AdminService.OnSaveReset(function(player)
		publish(player)
		updateBoards()
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.CheckSeconds)
			local checked, problem = pcall(ParkourService.Check :: any)
			if not checked then
				warn("[ParkourService] " .. tostring(problem))
			end
		end
	end)
end

return ParkourService
