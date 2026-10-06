--!strict
--[[
	Easter eggs (Config.EasterEggs): secret pumpkins (and candy, skulls, ghosts) hidden in the
	lobby. Each gives its coins once per player, ever (saved in data.EasterEggs).
	On/off: Config.Features.EasterEggs (off = no eggs: they are taken out of the running game).

	An egg is any part tagged EasterEgg with the attributes EggId and Coins (the eggs built by
	src/server/Hub/Sections/EasterEggs.luau, or any part you tag in Studio). An EggId from
	Config.EasterEggs.List pays the Coins written there (its Coins attribute is only used for
	eggs that aren't in the list). On start, eggs in Config.EasterEggs.List that the lobby
	doesn't have are placed (Sections/EasterEggs).
	Collecting: the egg's "Take" button or walking into it. The server checks the player's
	save is loaded, they aren't in a round, they are within ReachDistance of the egg, aren't
	grabbing too fast and haven't found that egg before; then it adds the coins and tells
	the player ("Easter egg found! +50 Coins (3/10)").

	What the client sees (src/client/EasterEggUI.luau):
	  Player attribute            EasterEggsFound   the ids they found ("ShopPumpkin,PatchGold")
	  ReplicatedStorage attribute EasterEggsActive  the ids of the eggs in the lobby right now
	  RemoteEvent EasterEggFound  server -> client  { Id, Name, Coins, Found, Total }
	Admin (F8): "Easter eggs: reset mine" hides every egg from you again.

	EasterEggService.Start()
	EasterEggService.Collect(player, eggPart) -> boolean   (also used by the tests)
	EasterEggService.ActiveIds() -> { string }
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EasterEggRules = require(ReplicatedStorage.Shared.EasterEggRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local EggSection = require(script.Parent.Parent.Hub.Sections.EasterEggs)

local EasterEggService = {}

local cfg = Config.EasterEggs
local foundEvent: RemoteEvent? = nil
local lastTry: { [Player]: number } = {}
local wired: { [BasePart]: { RBXScriptConnection } } = {}
local publishQueued = false

-- Egg parts that are really in the game.
local function eggParts(): { BasePart }
	local list = {}
	for _, instance in CollectionService:GetTagged(Tags.EasterEgg) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(list, instance)
		end
	end
	return list
end

-- The ids of the eggs in the lobby: in Config order, then any others (eggs made in Studio).
function EasterEggService.ActiveIds(): { string }
	local present: { [string]: boolean } = {}
	for _, part in eggParts() do
		local id = part:GetAttribute("EggId")
		if type(id) == "string" and id ~= "" and not id:find(",", 1, true) then
			present[id] = true
		end
	end
	local ids = {}
	for _, egg in cfg.List do
		if present[egg.Id] then
			table.insert(ids, egg.Id)
			present[egg.Id] = nil
		end
	end
	local others = {}
	for id in present do
		table.insert(others, id)
	end
	table.sort(others)
	for _, id in others do
		table.insert(ids, id)
	end
	return ids
end

local function publishActive()
	ReplicatedStorage:SetAttribute(
		EasterEggRules.ActiveAttribute,
		EasterEggRules.JoinIds(EasterEggService.ActiveIds())
	)
end

-- Many eggs can appear at once (a hub being built): tell the clients once, a moment later.
local function queuePublish()
	if publishQueued then
		return
	end
	publishQueued = true
	task.defer(function()
		publishQueued = false
		publishActive()
	end)
end

local function foundSet(player: Player): { [string]: boolean }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local found = data.EasterEggs
	if type(found) ~= "table" then
		found = {}
		data.EasterEggs = found
	end
	return found
end

local function publishFound(player: Player)
	local found = foundSet(player)
	if not found then
		return
	end
	local ids = {}
	for id, yes in found do
		if yes == true and type(id) == "string" then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	player:SetAttribute(EasterEggRules.FoundAttribute, EasterEggRules.JoinIds(ids))
end

local function eggName(id: string): string
	local def = EasterEggRules.Def(id)
	return if def then def.Name else id
end

function EasterEggService.Collect(player: Player, part: BasePart): boolean
	if not Config.Features.EasterEggs then
		return false
	end
	local id = part:GetAttribute("EggId")
	if type(id) ~= "string" or id == "" then
		return false
	end
	if not (part:IsDescendantOf(workspace) and CollectionService:HasTag(part, Tags.EasterEgg)) then
		return false
	end
	local found = foundSet(player)
	if not found then
		return false -- save not loaded yet
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	local last = lastTry[player]
	local why = EasterEggRules.CheckCollect({
		AlreadyFound = found[id] == true,
		InRound = player:GetAttribute("InRound") == true,
		SinceLastTry = if last then now - last else math.huge,
		Distance = if root and root:IsA("BasePart")
			then (root.Position - part.Position).Magnitude
			else math.huge,
	}, cfg)
	if why == "Found" or why == "TooFast" then
		return false
	end
	lastTry[player] = now
	if why then
		return false
	end
	found[id] = true
	-- An egg in Config.EasterEggs.List pays its Coins from there (so changing it works on a
	-- saved hub too); an egg you made yourself in Studio pays its Coins attribute.
	local def = EasterEggRules.Def(id)
	local reward = if def and type(def.Coins) == "number"
		then def.Coins
		else part:GetAttribute("Coins")
	local coins = EasterEggRules.Coins(reward, cfg.MaxCoins)
	if coins > 0 then
		DataService.Add(player, "Coins", coins)
		pcall(ShopService.Push, player)
	end
	publishFound(player)
	local count, total = EasterEggRules.Count(found, EasterEggService.ActiveIds())
	local event = foundEvent
	if event then
		event:FireClient(
			player,
			{ Id = id, Name = eggName(id), Coins = coins, Found = count, Total = total }
		)
	end
	return true
end

-- Gives an egg part its button (Config settings) and listens to the button and to touches.
local function wire(instance: Instance)
	if not (instance:IsA("BasePart") and instance:IsDescendantOf(workspace)) or wired[instance] then
		return
	end
	local part: BasePart = instance
	local prompt = part:FindFirstChild("EggPrompt")
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		local created = Instance.new("ProximityPrompt")
		created.Name = "EggPrompt"
		created.Parent = part
		prompt = created
	end
	assert(prompt and prompt:IsA("ProximityPrompt"), "unreachable")
	prompt.ActionText = cfg.Prompt.ActionText
	local id = part:GetAttribute("EggId")
	prompt.ObjectText = if type(id) == "string" then eggName(id) else ""
	prompt.HoldDuration = cfg.Prompt.HoldDuration
	prompt.MaxActivationDistance = cfg.Prompt.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	local connections = {
		prompt.Triggered:Connect(function(player: Player)
			EasterEggService.Collect(player, part)
		end),
	}
	if cfg.TouchToCollect then
		part.CanTouch = true
		table.insert(
			connections,
			part.Touched:Connect(function(hit: BasePart)
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					EasterEggService.Collect(player, part)
				end
			end)
		)
	end
	wired[part] = connections
	queuePublish()
end

local function unwire(instance: Instance)
	local part = instance :: BasePart
	local connections = wired[part]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		wired[part] = nil
	end
	queuePublish()
end

-- Feature off: no eggs in the running game (the saved place is not changed).
local function removeEggs()
	for _, part in eggParts() do
		local m = part.Parent
		if m and m:IsA("Model") and m.PrimaryPart == part then
			m:Destroy()
		else
			part:Destroy()
		end
	end
	ReplicatedStorage:SetAttribute(EasterEggRules.ActiveAttribute, nil)
end

local function onPlayer(player: Player)
	if player:GetAttribute("DataReady") then
		publishFound(player)
	end
	player:GetAttributeChangedSignal("DataReady"):Connect(function()
		publishFound(player)
	end)
end

function EasterEggService.Start()
	foundEvent = Remotes.Event("EasterEggFound")
	if not Config.Features.EasterEggs then
		removeEggs()
		return
	end
	-- Eggs the lobby doesn't have yet (a hub saved before them, or ones deleted by hand).
	local hub = workspace:FindFirstChild("Hub")
	if hub and hub:IsA("Model") then
		local ok, result = pcall(EggSection.PlaceMissing, hub)
		if not ok then
			warn("[EasterEggs] Couldn't place the eggs: " .. tostring(result))
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.EasterEgg) do
		wire(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.EasterEgg):Connect(function(instance)
		task.defer(wire, instance) -- (its parent is set right after the tag)
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.EasterEgg):Connect(unwire)
	publishActive()

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)

	AdminService.Register("EasterEggsReset", "Easter eggs: reset mine", function(player, data)
		data.EasterEggs = {}
		publishFound(player)
		return "Every Easter egg is hidden from you again: go and find them!"
	end)
end

return EasterEggService
