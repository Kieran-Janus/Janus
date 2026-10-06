--!strict
--[[
	Web Scour, a lobby minigame (Config.Minigames.WebScour): a quick scavenger hunt in the
	spider webs of the Spider Grove (src/server/Hub/Sections/WebScour.luau).
	On/off: Config.Features.WebScour (off = no hunts, and the grove is taken out of the
	running game).

	How a hunt works (several players can hunt at once, each with their own critters):
	  1. A player uses the "Scour the Web!" button on a part tagged WebScourStart (any part
	     with that tag gets the button, even one added in Studio; a tagged Model gets it on
	     its PrimaryPart, else its first part).
	  2. The server picks Critters random parts tagged WebScourSpot and tells ONLY that
	     player where they are (the client shows the critters, nobody else sees them).
	  3. The player clicks or taps a critter: the client sends its number; the server checks
	     the hunt is still on, the critter is one of theirs and not caught yet, they are within
	     MaxReach studs and not clicking impossibly fast.
	  4. All caught, time up, Stop, walking away (LeaveDistance) or joining a round ends it.
	     Coins (WebScourRules.Coins) are only paid once every RewardCooldown seconds; the best
	     time (everything found) is saved in data.Minigames.WebScourBest.

	Remotes (created in Start() even when the feature is off, so the client never waits):
	  WebScourRun     server -> client   { Op = "Start" | "Found" | "Miss" | "End" | "Note", ... }
	  WebScourAction  client -> server   ("Catch", runId, critterId) or ("Stop", runId)
	Admin (F8): "Web Scour: start" takes you to the lantern and starts a hunt.

	WebScourService.Start()
	WebScourService.StartHunt(player, startPart?, force?) -> (boolean, string)
	WebScourService.IsHunting(player) -> boolean
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local WebScourRules = require(ReplicatedStorage.Shared.WebScourRules)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local Hub = script.Parent.Parent.Hub
local HubLayout = require(Hub.HubLayout)

local WebScourService = {}

local cfg = Config.Minigames.WebScour
local text = cfg.Text

type Critter = { Id: number, Position: Vector3, Kind: string, Found: boolean }
type Hunt = {
	Id: number,
	Started: number, -- os.clock()
	Deadline: number,
	Critters: { Critter },
	Found: number,
	LastFind: number?,
	Origin: Vector3, -- the lantern: walk too far from it and the hunt stops
}

local hunts: { [Player]: Hunt } = {}
local huntCount: { [Player]: number } = {}
local lastEnded: { [Player]: number } = {}
local actionWindow: { [Player]: { Start: number, Count: number } } = {}
-- When each player last won coins here, by UserId. Kept for the whole server (not cleared when
-- they leave) so leaving and rejoining doesn't skip the coin cooldown.
local lastReward: { [number]: number } = {}
local wiredPrompts: { [ProximityPrompt]: RBXScriptConnection } = {}
local rng = Random.new()
local runEvent: RemoteEvent? = nil

local function send(player: Player, message: { [string]: any })
	local event = runEvent
	if event and player.Parent == Players then
		event:FireClient(player, message)
	end
end

local function note(player: Player, words: string)
	send(player, { Op = "Note", Text = words })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Tagged parts that are really in the game (not a backup in ServerStorage).
local function tagged(tag: string): { BasePart }
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(list, instance)
		end
	end
	return list
end

-- The part that holds a lantern's button: a part tagged WebScourStart, or the main part
-- (PrimaryPart, else its first part) of a Model with that tag, e.g. a Toolbox lantern.
local function buttonPart(instance: Instance): BasePart?
	if not instance:IsDescendantOf(workspace) then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Every lantern in the game (its button part).
local function starts(): { BasePart }
	local list = {}
	for _, instance in CollectionService:GetTagged(Tags.WebScourStart) do
		local part = buttonPart(instance)
		if part then
			table.insert(list, part)
		end
	end
	return list
end

-- Seconds until this player can win coins again (0 = now).
local function rewardWait(player: Player, now: number): number
	local last = lastReward[player.UserId]
	if not last then
		return 0
	end
	return math.max(cfg.RewardCooldown - (now - last), 0)
end

local function minigameData(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local minigames = data.Minigames
	if type(minigames) ~= "table" then
		minigames = {}
		data.Minigames = minigames
	end
	return minigames
end

local function bestOf(player: Player): number
	local minigames = minigameData(player)
	local best = minigames and minigames.WebScourBest
	return if type(best) == "number" and best > 0 then best else 0
end

-- Ends `player`'s hunt (if any) for `reason`: AllFound, TimeUp, Stopped, Left, Round, Admin.
local function finish(player: Player, reason: string)
	local hunt = hunts[player]
	if not hunt then
		return
	end
	hunts[player] = nil
	local now = os.clock()
	lastEnded[player] = now
	local total = #hunt.Critters
	local allFound = total > 0 and hunt.Found >= total
	local elapsed = math.clamp(now - hunt.Started, 0, cfg.TimeLimit)
	local wait = rewardWait(player, now)
	local paying = reason == "AllFound" or reason == "TimeUp"
	local coins = 0
	if paying and wait <= 0 and player.Parent == Players then
		local secondsLeft = if allFound then cfg.TimeLimit - elapsed else 0
		coins = WebScourRules.Coins(cfg, hunt.Found, total, secondsLeft)
		if coins > 0 then
			DataService.Add(player, "Coins", coins)
			pcall(ShopService.Push, player)
			lastReward[player.UserId] = now
		end
	end
	local best = bestOf(player)
	local newBest = false
	if allFound and reason == "AllFound" then
		local time = math.floor(elapsed * 100 + 0.5) / 100
		if best <= 0 or time < best then
			local minigames = minigameData(player)
			if minigames then
				minigames.WebScourBest = time
				best = time
				newBest = true
			end
		end
	end
	send(player, {
		Op = "End",
		RunId = hunt.Id,
		Reason = reason,
		Found = hunt.Found,
		Total = total,
		Coins = coins,
		Time = if allFound then elapsed else nil,
		Best = best,
		NewBest = newBest,
		CooldownLeft = if paying and coins == 0 then wait else 0,
	})
end

--[[
	Starts a hunt for `player`. `startPart` is the lantern they used (nil = the nearest one).
	force = true (admin) skips the "already hunting", cooldown and distance checks.
	Returns whether it started and a message.
]]
function WebScourService.StartHunt(
	player: Player,
	startPart: BasePart?,
	force: boolean?
): (boolean, string)
	if not Config.Features.WebScour then
		return false, "Web Scour is switched off (Config.Features.WebScour)."
	end
	if player:GetAttribute("InRound") == true then
		return false, text.InRound
	end
	if not DataService.Get(player) then
		return false, text.NotReady
	end
	local now = os.clock()
	if hunts[player] then
		if not force then
			return false, text.Busy
		end
		finish(player, "Admin")
	end
	local ended = lastEnded[player]
	if not force and ended and now - ended < cfg.StartCooldown then
		return false, text.Wait
	end
	local root = rootOf(player)
	if not root then
		return false, text.NotReady
	end
	local origin = startPart
	if not origin then
		local nearest = math.huge
		for _, part in starts() do
			local distance = (part.Position - root.Position).Magnitude
			if distance < nearest then
				nearest = distance
				origin = part
			end
		end
	end
	if not origin then
		return false, text.NoSpots
	end
	local reach = cfg.Prompt.MaxActivationDistance + 8
	if not force and (origin.Position - root.Position).Magnitude > reach then
		return false, text.TooFar
	end
	local spots = tagged(Tags.WebScourSpot)
	if #spots == 0 then
		warn(
			"[WebScour] No parts are tagged WebScourSpot, so there is nowhere for critters to hide."
		)
		return false, text.NoSpots
	end
	local kinds = cfg.CritterKinds
	local critters: { Critter } = {}
	for i, index in WebScourRules.PickSpots(#spots, cfg.Critters, rng) do
		local kind = if #kinds > 0 then kinds[rng:NextInteger(1, #kinds)] else "Spider"
		critters[i] = { Id = i, Position = spots[index].Position, Kind = kind, Found = false }
	end
	local id = (huntCount[player] or 0) + 1
	huntCount[player] = id
	local hunt: Hunt = {
		Id = id,
		Started = now,
		Deadline = now + cfg.TimeLimit,
		Critters = critters,
		Found = 0,
		LastFind = nil,
		Origin = origin.Position,
	}
	hunts[player] = hunt
	local list = {}
	for _, critter in critters do
		table.insert(list, { Id = critter.Id, Position = critter.Position, Kind = critter.Kind })
	end
	send(player, {
		Op = "Start",
		RunId = id,
		TimeLimit = cfg.TimeLimit,
		Critters = list,
		Best = bestOf(player),
		CooldownLeft = rewardWait(player, now),
	})
	task.delay(cfg.TimeLimit, function()
		if hunts[player] == hunt then
			finish(player, "TimeUp")
		end
	end)
	return true, ("Hunt started: find %d critters."):format(#critters)
end

function WebScourService.IsHunting(player: Player): boolean
	return hunts[player] ~= nil
end

-- At most MaxActionsPerSecond messages per player per second.
local function allowed(player: Player): boolean
	local now = os.clock()
	local window = actionWindow[player]
	if not window or now - window.Start >= 1 then
		actionWindow[player] = { Start = now, Count = 1 }
		return true
	end
	window.Count += 1
	return window.Count <= cfg.MaxActionsPerSecond
end

local function onAction(player: Player, action: unknown, runId: unknown, critterId: unknown)
	if not allowed(player) then
		return
	end
	local hunt = hunts[player]
	if not hunt or type(runId) ~= "number" or runId ~= hunt.Id then
		return
	end
	if action == "Stop" then
		finish(player, "Stopped")
		return
	end
	if action ~= "Catch" or type(critterId) ~= "number" or critterId % 1 ~= 0 then
		return
	end
	local critter = hunt.Critters[critterId]
	if not critter then
		return
	end
	local root = rootOf(player)
	local now = os.clock()
	local why = WebScourRules.CheckFind({
		Now = now,
		Started = hunt.Started,
		Deadline = hunt.Deadline + cfg.LagAllowance,
		LastFind = hunt.LastFind,
		AlreadyFound = critter.Found,
		Distance = if root then (root.Position - critter.Position).Magnitude else math.huge,
	}, cfg)
	if why then
		if why == "TooFar" or why == "TooFast" or why == "TooSoon" then
			send(player, { Op = "Miss", RunId = hunt.Id, Id = critterId, Reason = why })
		end
		return
	end
	critter.Found = true
	hunt.Found += 1
	hunt.LastFind = now
	local found = { Op = "Found", RunId = hunt.Id, Id = critterId, Found = hunt.Found }
	found.Total = #hunt.Critters
	send(player, found)
	if hunt.Found >= #hunt.Critters then
		finish(player, "AllFound")
	end
end

-- Hunters who joined a round or walked away stop hunting.
local function check()
	for player, hunt in hunts do
		if player.Parent ~= Players then
			hunts[player] = nil
			continue
		end
		if player:GetAttribute("InRound") == true then
			finish(player, "Round")
			continue
		end
		local root = rootOf(player)
		if root and (root.Position - hunt.Origin).Magnitude > cfg.LeaveDistance then
			finish(player, "Left")
		end
	end
end

-- Gives a WebScourStart part or model its button (with the Config text) and listens to it.
local function wire(instance: Instance)
	local part = buttonPart(instance)
	if not part then
		return
	end
	local prompt: ProximityPrompt? = nil
	for _, d in instance:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "WebScourPrompt" then
			prompt = d
			break
		end
	end
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "WebScourPrompt"
		created.Parent = part
		prompt = created
	end
	assert(prompt, "unreachable")
	prompt.ActionText = cfg.Prompt.ActionText
	prompt.ObjectText = cfg.Prompt.ObjectText
	prompt.HoldDuration = cfg.Prompt.HoldDuration
	prompt.MaxActivationDistance = cfg.Prompt.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	if wiredPrompts[prompt] then
		return
	end
	local p: ProximityPrompt = prompt
	wiredPrompts[p] = p.Triggered:Connect(function(player: Player)
		local ok, message = WebScourService.StartHunt(player, part)
		if not ok then
			note(player, message)
		end
	end)
	p.Destroying:Once(function()
		local connection = wiredPrompts[p]
		if connection then
			connection:Disconnect()
			wiredPrompts[p] = nil
		end
	end)
end

-- A saved hub with no lantern (from before the Spider Grove existed, baked with Web Scour off,
-- or the lantern was deleted): WebScour.Repair builds the grove for this server, or only a
-- new lantern when the grove is still there (hand edits stay).
local function ensureGrove()
	if #starts() > 0 then
		return
	end
	local hub = workspace:FindFirstChild("Hub")
	if not (hub and hub:IsA("Model")) then
		return
	end
	local sections = Hub:FindFirstChild("Sections")
	local section = sections and sections:FindFirstChild("WebScour")
	if not (section and section:IsA("ModuleScript")) then
		return
	end
	local ok, err = pcall(function()
		(require :: any)(section).Repair(hub, HubLayout.Zone("WebScour"))
	end)
	if ok then
		warn(
			"[WebScour] Your saved hub had no Web Scour lantern (nothing tagged WebScourStart), so the Spider Grove (or just its lantern, if the grove was still there) was built for this server. To keep it, F8 > Rebuild hub or bake the hub again (Bake.Hub())."
		)
	else
		warn("[WebScour] Couldn't build the Spider Grove: " .. tostring(err))
	end
end

-- Feature off: the grove isn't part of the running game (the saved place is not changed).
local function removeGrove()
	for _, instance in CollectionService:GetTagged(Tags.WebScourStart) do
		if not instance:IsDescendantOf(workspace) then
			continue
		end
		for _, d in instance:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d.Enabled = false
			end
		end
	end
	local hub = workspace:FindFirstChild("Hub")
	local area = hub and hub:FindFirstChild("WebScour")
	if area then
		area:ClearAllChildren()
	end
end

function WebScourService.Start()
	runEvent = Remotes.Event("WebScourRun")
	local action = Remotes.Event("WebScourAction")
	if not Config.Features.WebScour then
		removeGrove()
		return
	end
	ensureGrove()
	action.OnServerEvent:Connect(onAction)
	for _, instance in CollectionService:GetTagged(Tags.WebScourStart) do
		wire(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.WebScourStart):Connect(function(instance)
		task.defer(wire, instance) -- (its parent is set right after the tag)
	end)
	Players.PlayerRemoving:Connect(function(player)
		hunts[player] = nil
		huntCount[player] = nil
		lastEnded[player] = nil
		actionWindow[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(cfg.CheckSeconds)
			local ok, err = pcall(check :: any) -- (the cast: the old type checker misreads pcall of a function returning nothing)
			if not ok then
				warn("[WebScour] " .. tostring(err))
			end
		end
	end)
	AdminService.Register("WebScourStart", "Web Scour: start", function(player, _data)
		local lantern = starts()[1]
		local character = player.Character
		if lantern and character then
			-- Stand on the ground just in front of the lantern (it hangs above head height),
			-- facing the grove.
			local look = lantern.CFrame.LookVector
			local spot = lantern.Position + look * 4 - Vector3.new(0, 3.5, 0)
			character:PivotTo(CFrame.lookAt(spot, spot - Vector3.new(look.X, 0, look.Z)))
		end
		local ok, message = WebScourService.StartHunt(player, lantern, true)
		return if ok then message else "Couldn't start: " .. message
	end)
end

return WebScourService
