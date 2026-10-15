--!strict
--[[
	PROP HUNT: hiders turn into things on the map, pumpkin-headed finders cannon them.
	On/off: Config.Features.PropHunt (off = the vote never offers it). Settings: Config.PropHunt
	(Easy / Hard in Config.PropHunt.Difficulty). Map: The Haunted House, or any map with things
	tagged PropHuntProp and the Hide & Seek spawn tags (SeekerSpawn, HiderSpawn, SeekerDoor).

	How a round goes (Run):
	  1. Roles: Config.PropHunt.FinderRatio of the players are finders (at least 1, never
	     everyone; last round's finders are picked last), the rest hide. Everyone gets the
	     player attribute HideSeekRole ("Hider", "Seeker" = finder, "Out"), so every guard that
	     hides skins on Hide & Seek hiders (ShopService.Dress, SkinAnim, SkinFx, SkinWalk,
	     SkinCatalogService, SkinStudioService) works for disguised hiders too.
	  2. Hiders go to parts tagged HiderSpawn and turn into a random small thing (StartAsProp):
	     their character is made invisible and a copy of the thing is welded to their
	     HumanoidRootPart, standing on the floor. Finders wait in the closed Finder Hut (parts
	     tagged SeekerSpawn), frozen, wearing a pumpkin head (Config.PropHunt.FinderHead), with
	     a "COUNTING..." blindfold on screen, for the difficulty's HeadStart (State "Hiding").
	  3. Hiders send PropHuntAction:
	       "Become" (a thing, or nil = the nearest)  the server checks it's a tagged thing on
	                this map within Disguise.Range, not too big, off cooldown, and (once the
	                finders are out) that the hider has changes left; then they become a copy
	       "Lock" (true/false)  anchors them in place (no wobbling)
	       "Taunt"  a giggle from their thing (cooldown); counts for bonus coins once the
	                finders are out
	  4. The hut door (tag SeekerDoor) swings open and every finder gets a Pumpkin Cannon
	     (State "Playing"). The client sends where the player aimed (PropHuntShoot); the server
	     checks it's a finder in this round, with the cannon out and off cooldown, casts a ray
	     from the finder's head (src/server/Modes/PropHuntCannon.luau) and finds the hider whose
	     thing it hits (or passes close to: the difficulty's HitTolerance). Hitting a real thing
	     adds the difficulty's PropPenalty to the cooldown.
	  5. Found hiders become finders (FoundBecomeFinders) or watch as ghosts. On Easy, hiders
	     giggle every GiggleInterval and glow for the last GlowLastSeconds. A hider who resets
	     after the finders are out leaves their thing in place (it can still be found) and comes
	     back to it. If every finder leaves, a hider becomes the finder (if 2+ hiders are left).
	  6. The round ends when every hider is found (finders win), at 0:00 (hiders still hidden
	     win) or when nobody is left. Scores: finds + taunts; coins: Config.PropHunt.Rewards x
	     the difficulty's RewardMultiplier.

	Attributes clients read:
	  ReplicatedStorage: PropHidersLeft, PropFinderCount (numbers, during the round)
	  Player: HideSeekRole, PropFinds, PropChangesLeft, PropLocked, PropTaunts,
	          PropTauntReadyAt (workspace:GetServerTimeNow() when the next taunt is allowed),
	          PropDisguise (the prop name of the thing a hider is)
	Remotes (made when this module loads, which is before GameService sets Mode = "PropHunt"):
	  PropHuntShoot  (client -> server): target Vector3, where the player aimed
	  PropHuntAction (client -> server): (action "Become" | "Lock" | "Taunt", argument)
	  PropHuntEvent  (server -> clients): (kind, data) with kind
	    "Shot"     { Shooter, From, To, Normal?, Result = "Hider"|"Prop"|"Miss", Prop?, Cooldown }
	    "Found"    { Hider, Seeker, Position, HidersLeft }
	    "Giggle"   { Hider, Prop, Taunt }  (the client plays the giggle and puffs sparkles)
	    "Became"   { Hider, Prop }        (a puff where a hider changed)
	    "Released" {}
	    "Glow"     {}
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Services = script.Parent.Parent.Services
local GhostService = require(Services.GhostService)
local MapService = require(Services.MapService)
local ShopService = require(Services.ShopService)
local Cannon = require(script.Parent.PropHuntCannon)
local Rules = require(script.Parent.PropHuntRules)
local Types = require(script.Parent.Types)

local PropHunt = {}

type Role = Rules.Role

-- A hider's thing and how to undo everything done to their character.
type Disguise = {
	Model: Model,
	Body: BasePart,
	Radius: number, -- half the thing's width (for near-miss hits)
	Source: Instance?, -- the map thing it is a copy of
	Name: string, -- its prop name (Pumpkin, Skull...)
	FloorOffset: CFrame, -- where the thing's bottom middle is, seen from Body
	Frozen: CFrame?, -- set while the hider is dead: the thing waits on this spot (its bottom)
	Light: PointLight,
	Highlight: Highlight,
	Undo: { () -> () },
	Connections: { RBXScriptConnection },
}

type Round = {
	Map: MapService.LoadedMap,
	Rng: Random,
	Settings: any, -- Config.PropHunt.Difficulty[ctx.Difficulty]
	Participants: { Player },
	Role: { [Player]: Role }, -- players still playing (found ghosts and leavers are removed)
	Entries: { [Player]: Rules.Entry },
	Disguises: { [Player]: Disguise },
	Guns: { [Player]: Tool },
	Heads: { [Player]: boolean }, -- finders wearing the pumpkin head
	NextShot: { [Player]: number },
	NextGiggle: { [Player]: number },
	NextChange: { [Player]: number },
	NextTaunt: { [Player]: number },
	ChangesLeft: { [Player]: number },
	Locked: { [Player]: boolean },
	HiderSpawns: { BasePart },
	SeekerSpawns: { BasePart },
	Props: { Instance }, -- the map's things hiders can become (tag PropHuntProp)
	Folder: Folder, -- the hiders' things
	Released: boolean,
	ReleasedAt: number,
	EndsAt: number,
	Glowing: boolean,
	StartedHiders: number,
	StartedSeekers: number,
	Connections: { RBXScriptConnection },
	Threads: { thread },
	Undo: { () -> () },
	Over: boolean,
}

local round: Round? = nil
local lastFinders: { [number]: boolean } = {} -- UserIds of last round's finders

local shootRemote = Remotes.Event("PropHuntShoot")
local actionRemote = Remotes.Event("PropHuntAction")
local eventRemote = Remotes.Event("PropHuntEvent")

-- The finders' pumpkin head: a skin worn for the round (Cosmetics.Wear), taken off after.
local FINDER_ITEM = {
	Id = "PropHuntFinder",
	Name = "Finder Pumpkin Head",
	Slot = "Skin",
	Rarity = "Common",
	Style = {
		Kind = "Skin",
		Head = Config.PropHunt.FinderHead.Head,
		Face = Config.PropHunt.FinderHead.Face,
		HeadColor = Config.PropHunt.FinderHead.HeadColor,
		GlowColor = Config.PropHunt.FinderHead.GlowColor,
	},
}

local PLAYER_ATTRIBUTES = {
	"HideSeekRole",
	"PropFinds",
	"PropChangesLeft",
	"PropLocked",
	"PropTaunts",
	"PropTauntReadyAt",
	"PropDisguise",
}

-- Helpers ------------------------------------------------------------------------------------

local function alive(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

-- Studs from the HumanoidRootPart's centre down to the floor the character stands on.
local function rootHeight(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return root.Size.Y / 2 + 2
end

local function yaw(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new()
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

local function shuffled<T>(list: { T }, rng: Random): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function tagged(map: MapService.LoadedMap, tag: string): { BasePart }
	local list: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(map.Model) then
			table.insert(list, instance)
		end
	end
	return list
end

local function counts(r: Round): (number, number)
	local hiders, seekers = 0, 0
	for player, role in r.Role do
		if player.Parent ~= Players then
			continue
		end
		if role == "Hider" then
			hiders += 1
		elseif role == "Seeker" then
			seekers += 1
		end
	end
	return hiders, seekers
end

local function publish(r: Round)
	local hiders, seekers = counts(r)
	ReplicatedStorage:SetAttribute("PropHidersLeft", hiders)
	ReplicatedStorage:SetAttribute("PropFinderCount", seekers)
end

local function winnerState(r: Round, timeUp: boolean): Rules.WinnerState
	local hiders, seekers = counts(r)
	return {
		StartedHiders = r.StartedHiders,
		StartedSeekers = r.StartedSeekers,
		HidersLeft = hiders,
		SeekersLeft = seekers,
		TimeUp = timeUp,
	}
end

local function decided(r: Round): boolean
	if next(r.Role) == nil then
		return true
	end
	return Rules.Winner(winnerState(r, false)) ~= nil
end

local function placeAt(player: Player, floor: CFrame)
	local character, humanoid, root = alive(player)
	if not character or not humanoid or not root then
		return
	end
	character:PivotTo(
		CFrame.new(floor.Position + Vector3.new(0, rootHeight(humanoid, root) + 0.1, 0))
			* yaw(floor)
	)
end

local function spotOn(spawn: BasePart, row: number): Vector3
	local ahead = row * Config.PropHunt.SpawnRowSpacing
	return (spawn.CFrame * CFrame.new(0, 0, -ahead)).Position + Vector3.new(0, spawn.Size.Y / 2, 0)
end

local function placeOn(r: Round, player: Player, spawn: BasePart?, row: number?)
	if not spawn then
		return
	end
	local spread = Vector3.new(
		r.Rng:NextNumber(-1, 1) * math.max(0, spawn.Size.X / 2 - 1.5),
		0,
		r.Rng:NextNumber(-1, 1) * math.max(0, spawn.Size.Z / 2 - 1.5)
	)
	local top = spotOn(spawn, row or 0) + spawn.CFrame:VectorToWorldSpace(spread)
	placeAt(player, CFrame.new(top) * yaw(spawn.CFrame))
end

local function pick(list: { BasePart }, rng: Random): BasePart?
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- The first hut pad (and row) nobody else stands on (so finders never stand inside each other).
local function seekerSpot(r: Round, player: Player): (BasePart?, number)
	local cfg = Config.PropHunt
	local roots: { BasePart } = {}
	for other in r.Role do
		local _, _, root = alive(other)
		if other ~= player and root then
			table.insert(roots, root)
		end
	end
	for row = 0, math.max(cfg.SpawnRows, 1) - 1 do
		for _, spawn in r.SeekerSpawns do
			local spot = spotOn(spawn, row)
			local free = true
			for _, root in roots do
				local dx, dz = root.Position.X - spot.X, root.Position.Z - spot.Z
				if dx * dx + dz * dz < (cfg.SpawnRowSpacing * 0.6) ^ 2 then
					free = false
					break
				end
			end
			if free then
				return spawn, row
			end
		end
	end
	return pick(r.SeekerSpawns, r.Rng), 0
end

-- Anchored on the server: finders while they count, hiders who locked themselves in place.
local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
end

local function setLocked(r: Round, player: Player, locked: boolean)
	r.Locked[player] = if locked then true else nil
	player:SetAttribute("PropLocked", locked)
	setFrozen(player, locked)
end

-- The tagged thing `part` belongs to (itself or an ancestor) inside the map, or nil.
local function propOf(r: Round, part: Instance): Instance?
	local node: Instance? = part
	while node and node ~= workspace do
		if CollectionService:HasTag(node, Tags.PropHuntProp) then
			return if node:IsDescendantOf(r.Map.Model) then node else nil
		end
		node = node.Parent
	end
	return nil
end

local function propName(prop: Instance): string
	local name = prop:GetAttribute("PropName")
	return if typeof(name) == "string" then name else prop.Name
end

-- The thing's box (a Model's bounding box, or a part's own).
local function boxOf(prop: Instance): (CFrame, Vector3)
	if prop:IsA("Model") then
		return prop:GetBoundingBox()
	elseif prop:IsA("BasePart") then
		return prop.CFrame, prop.Size
	end
	return CFrame.new(), Vector3.zero
end

-- Studs from `point` to the nearest side of the thing's box (0 inside it).
local function distanceTo(prop: Instance, point: Vector3): number
	local cf, size = boxOf(prop)
	local p = cf:PointToObjectSpace(point)
	local half = size / 2
	local clamped = Vector3.new(
		math.clamp(p.X, -half.X, half.X),
		math.clamp(p.Y, -half.Y, half.Y),
		math.clamp(p.Z, -half.Z, half.Z)
	)
	return (p - clamped).Magnitude
end

-- Disguise -----------------------------------------------------------------------------------

local function setGlow(d: Disguise, on: boolean)
	d.Light.Enabled = on
	d.Highlight.Enabled = on
end

local function undisguise(r: Round, player: Player)
	local d = r.Disguises[player]
	if not d then
		return
	end
	r.Disguises[player] = nil
	for _, connection in d.Connections do
		connection:Disconnect()
	end
	for i = #d.Undo, 1, -1 do
		d.Undo[i]()
	end
	d.Model:Destroy()
	if player.Parent == Players then
		player:SetAttribute("PropDisguise", nil)
	end
end

local HIDE_ENABLED = {
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Light",
	"Fire",
	"Smoke",
	"Sparkles",
	"Highlight",
	"BillboardGui",
	"SurfaceGui",
}

local function makeEffects(model: Model, body: BasePart): (PointLight, Highlight)
	local fx = Config.PropHunt.Effects
	local box, size = model:GetBoundingBox()
	-- Puffed by each client when this hider giggles or taunts (PropHuntCannon client).
	local a = Instance.new("Attachment")
	a.Name = "GiggleSparkles"
	a.Position = body.CFrame:PointToObjectSpace(box.Position + Vector3.new(0, size.Y / 2, 0))
	a.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "GiggleSparkles"
	sparkles.Enabled = false
	sparkles.Color = ColorSequence.new(fx.SparkleColor)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(4, 7)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Acceleration = Vector3.new(0, -5, 0)
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Parent = a

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Enabled = false
	light.Color = fx.GlowColor
	light.Range = fx.GlowRange
	light.Brightness = fx.GlowBrightness
	light.Shadows = false
	light.Parent = body

	local highlight = Instance.new("Highlight")
	highlight.Name = "Glow"
	highlight.Enabled = false
	highlight.Adornee = model
	highlight.FillColor = fx.GlowColor
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = fx.GlowOutline
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	return light, highlight
end

--[[
	A copy of map thing `source`, its bottom middle on `floor` (turned like `floor`). Not a
	tagged thing any more (a pumpkin that hits it finds a hider), never any scripts, no lights
	of its own (phones' light budget).
]]
local function newCopy(r: Round, source: Instance, floor: CFrame): Model?
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	elseif copy:IsA("BasePart") then
		model = Instance.new("Model")
		copy.Parent = model
		model.PrimaryPart = copy
	else
		copy:Destroy()
		return nil
	end
	model.Name = "HiderThing"
	CollectionService:RemoveTag(model, Tags.PropHuntProp)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		else
			CollectionService:RemoveTag(d, Tags.PropHuntProp)
			if d:IsA("Light") then
				d.Enabled = false
			end
		end
	end
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - box.UpVector * (size.Y / 2)
	local pivot = model:GetPivot()
	local relative = (CFrame.new(bottom) * yaw(pivot)):ToObjectSpace(pivot)
	model:PivotTo(floor * relative)
	model.Parent = r.Folder
	return model
end

local function onMap(r: Round, part: BasePart): boolean
	local floor = r.Map.Floor
	return part:IsDescendantOf(workspace)
		and part.Position.Y > floor.Position.Y - floor.Size.Y / 2 - Config.PropHunt.FallMargin
end

-- The hider died: their thing stays where it is (anchored, it can still be found) and they
-- come back there (setUp), so resetting is no way to escape a finder.
local function freeze(d: Disguise)
	local spot = d.Body.CFrame * d.FloorOffset
	local level = CFrame.new(spot.Position) * yaw(spot)
	d.Frozen = level
	for _, part in d.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		elseif part:IsA("WeldConstraint") then
			local other = part.Part0
			if other and not other:IsDescendantOf(d.Model) then
				part:Destroy()
			end
		end
	end
	d.Model:PivotTo(level * spot:ToObjectSpace(d.Model:GetPivot()))
end

-- Turns a hider's character into a copy of `source` (or the thing they were before).
local function disguise(r: Round, player: Player, source: Instance?): boolean
	local before = r.Disguises[player]
	local like = source or (if before then before.Source else nil)
	if not like or not like:IsDescendantOf(r.Map.Model) then
		like = nil
		for _ = 1, 5 do
			local candidate = if #r.Props > 0 then r.Props[r.Rng:NextInteger(1, #r.Props)] else nil
			if candidate and candidate:IsDescendantOf(r.Map.Model) then
				like = candidate
				break
			end
		end
	end
	local character, humanoid, root = alive(player)
	if not like or not character or not humanoid or not root then
		return false
	end
	undisguise(r, player)
	local undo: { () -> () } = {}
	local function set(instance: Instance, property: string, value: any)
		local target = instance :: any
		local old = target[property]
		if old == value then
			return
		end
		target[property] = value
		table.insert(undo, function()
			if instance.Parent then
				target[property] = old
			end
		end)
	end
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			set(d, "Transparency", 1)
			set(d, "CastShadow", false)
		elseif d:IsA("Decal") then
			set(d, "Transparency", 1)
		else
			for _, className in HIDE_ENABLED do
				if d:IsA(className) then
					set(d, "Enabled", false)
					break
				end
			end
		end
	end
	set(humanoid, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
	set(humanoid, "HealthDisplayType", Enum.HumanoidHealthDisplayType.AlwaysOff)
	for _, d in character:GetDescendants() do
		hide(d)
	end

	-- The thing lives in the map (not in the character) so pumpkin rays that skip characters
	-- still hit it; it is welded to the root part, its bottom on the floor under the feet.
	local floorAt = root.Position - Vector3.new(0, rootHeight(humanoid, root), 0)
	local floor = CFrame.new(floorAt) * yaw(root.CFrame)
	local model = newCopy(r, like, floor)
	if not model then
		for i = #undo, 1, -1 do
			undo[i]()
		end
		return false
	end
	model:SetAttribute("HiderUserId", player.UserId)
	local _, size = model:GetBoundingBox()
	local width = math.max(size.X, size.Z, 1)
	local body: BasePart? = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if not model.PrimaryPart and (not body or d.Size.Magnitude > body.Size.Magnitude) then
				body = d
			end
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true -- (finders' pumpkins hit every piece)
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	if not body then
		model:Destroy()
		for i = #undo, 1, -1 do
			undo[i]()
		end
		return false
	end
	local light, highlight = makeEffects(model, body)
	local name = propName(like)
	local d: Disguise = {
		Model = model,
		Body = body,
		Radius = width / 2,
		Source = like,
		Name = name,
		FloorOffset = body.CFrame:ToObjectSpace(floor),
		Frozen = nil,
		Light = light,
		Highlight = highlight,
		Undo = undo,
		Connections = {},
	}
	table.insert(
		d.Connections,
		character.DescendantAdded:Connect(function(added)
			task.defer(function()
				if r.Disguises[player] == d then
					hide(added)
				end
			end)
		end)
	)
	table.insert(
		d.Connections,
		humanoid.Died:Connect(function()
			if r.Disguises[player] ~= d then
				return
			end
			if r.Released and not r.Over and onMap(r, d.Body) then
				freeze(d)
			else
				undisguise(r, player)
			end
		end)
	)
	r.Disguises[player] = d
	player:SetAttribute("PropDisguise", name)
	if r.Glowing then
		setGlow(d, true)
	end
	return true
end

-- A random small thing to start as (Disguise.StartProps), else any thing.
local function startProp(r: Round): Instance?
	local names = Config.PropHunt.Disguise.StartProps
	local list: { Instance } = {}
	for _, prop in r.Props do
		if table.find(names, propName(prop)) then
			table.insert(list, prop)
		end
	end
	if #list == 0 then
		list = r.Props
	end
	return if #list > 0 then list[r.Rng:NextInteger(1, #list)] else nil
end

-- Finders: pumpkin head and cannon --------------------------------------------------------------

local function wearHead(r: Round, player: Player)
	r.Heads[player] = true
	local character = player.Character
	if character then
		Cosmetics.Wear(character, FINDER_ITEM)
	end
end

-- Their own look back (with anything they equipped during the round).
local function removeHead(r: Round, player: Player)
	if not r.Heads[player] then
		return
	end
	r.Heads[player] = nil
	local character = player.Character
	if character and player.Parent == Players then
		Cosmetics.TakeOff(character, "Skin")
		task.spawn(ShopService.Dress, player)
	end
end

local function giveGun(r: Round, player: Player)
	local character, humanoid = alive(player)
	if not character or not humanoid then
		return
	end
	local old = r.Guns[player]
	local gun = if old and old.Parent ~= nil then old else Cannon.Make()
	r.Guns[player] = gun
	if gun.Parent ~= character then
		gun.Parent = player:FindFirstChildOfClass("Backpack") or character
	end
	humanoid:EquipTool(gun)
end

local function takeGun(r: Round, player: Player)
	local gun = r.Guns[player]
	r.Guns[player] = nil
	if gun then
		gun:Destroy()
	end
end

-- Puts a player (back) into the round as their role.
local function setUp(r: Round, player: Player, move: boolean)
	local role = r.Role[player]
	if r.Locked[player] then
		setLocked(r, player, false)
	end
	if role == "Hider" then
		if move then
			local old = r.Disguises[player]
			local waiting = if old then old.Frozen else nil
			if waiting then
				placeAt(player, waiting)
			else
				placeOn(r, player, pick(r.HiderSpawns, r.Rng))
			end
		end
		disguise(r, player, nil)
	elseif role == "Seeker" then
		if move then
			local spawn, row = seekerSpot(r, player)
			placeOn(r, player, spawn, row)
		end
		wearHead(r, player)
		if r.Released then
			giveGun(r, player)
		else
			setFrozen(player, true)
		end
	end
end

local function openDoors(r: Round)
	for _, instance in CollectionService:GetTagged(Tags.SeekerDoor) do
		if not instance:IsDescendantOf(r.Map.Model) then
			continue
		end
		if instance:IsA("BasePart") then
			instance.CanCollide = false
			local hinge = instance.CFrame * CFrame.new(-instance.Size.X / 2, 0, 0)
			local open = hinge
				* CFrame.Angles(0, math.rad(100), 0)
				* CFrame.new(instance.Size.X / 2, 0, 0)
			TweenService:Create(
				instance,
				TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = open }
			):Play()
		else
			for _, d in instance:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Transparency = 1
				end
			end
		end
	end
end

local function firstGiggle(r: Round, player: Player)
	local interval = r.Settings.GiggleInterval
	if interval and interval > 0 then
		r.NextGiggle[player] = os.clock() + interval * r.Rng:NextNumber(0.4, 1)
	end
end

local function release(r: Round)
	r.Released = true
	r.ReleasedAt = os.clock()
	r.EndsAt = r.ReleasedAt + r.Settings.Duration
	openDoors(r)
	for player, role in r.Role do
		if role == "Seeker" then
			setFrozen(player, false)
			giveGun(r, player)
		elseif role == "Hider" then
			firstGiggle(r, player)
		end
	end
	eventRemote:FireAllClients("Released", {})
end

-- Becoming a finder (found, or promoted when every finder left).
local function makeFinder(r: Round, player: Player, delay: number)
	undisguise(r, player)
	if r.Locked[player] then
		setLocked(r, player, false)
	end
	r.NextGiggle[player] = nil
	r.Role[player] = "Seeker"
	player:SetAttribute("HideSeekRole", "Seeker")
	player:SetAttribute("PropChangesLeft", nil)
	-- Their look comes back with the pumpkin head on top (Dress first, then the head).
	task.spawn(function()
		ShopService.Dress(player)
		if round == r and not r.Over and r.Role[player] == "Seeker" then
			wearHead(r, player)
		end
	end)
	if not r.Released then
		setUp(r, player, true)
		return
	end
	r.NextShot[player] = os.clock() + delay
	task.delay(delay, function()
		if round == r and not r.Over and r.Role[player] == "Seeker" then
			giveGun(r, player)
		end
	end)
end

-- Finding and shooting -------------------------------------------------------------------------

local function found(r: Round, hider: Player, seeker: Player, position: Vector3)
	if r.Role[hider] ~= "Hider" then
		return
	end
	local cfg = Config.PropHunt
	local now = os.clock()
	local entry = r.Entries[hider]
	if entry then
		entry.Found = true
		entry.HiddenSeconds = if r.Released then now - r.ReleasedAt else 0
	end
	local seekerEntry = r.Entries[seeker]
	if seekerEntry then
		seekerEntry.Finds += 1
		seeker:SetAttribute("PropFinds", seekerEntry.Finds)
	end
	if cfg.FoundBecomeFinders then
		makeFinder(r, hider, cfg.FoundFinderDelay)
	else
		undisguise(r, hider)
		if r.Locked[hider] then
			setLocked(r, hider, false)
		end
		r.NextGiggle[hider] = nil
		r.Role[hider] = nil
		hider:SetAttribute("HideSeekRole", "Out")
		task.spawn(ShopService.Dress, hider)
		GhostService.MarkOut(hider, true)
	end
	publish(r)
	local hidersLeft = counts(r)
	eventRemote:FireAllClients("Found", {
		Hider = hider,
		Seeker = seeker,
		Position = position,
		HidersLeft = hidersLeft,
	})
end

local function owner(r: Round, part: Instance): Player?
	for hider, d in r.Disguises do
		if part:IsDescendantOf(d.Model) then
			return hider
		end
	end
	return nil
end

local function onShoot(player: Player, target: unknown)
	local r = round
	if not r or r.Over or not r.Released then
		return
	end
	if typeof(target) ~= "Vector3" or not Cannon.Finite(target) then
		return
	end
	if r.Role[player] ~= "Seeker" then
		return
	end
	local now = os.clock()
	if now < (r.NextShot[player] or 0) then
		return
	end
	local character, _, root = alive(player)
	local gun = r.Guns[player]
	if not character or not root or not gun or gun.Parent ~= character then
		return -- the cannon must be out
	end
	local cfg = Config.PropHunt.Cannon
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart")
		then head.Position
		else root.Position + Vector3.new(0, 1.5, 0)
	if (target - origin).Magnitude < 0.5 then
		return
	end
	r.NextShot[player] = now + cfg.FireCooldown

	-- Characters never stop a pumpkin (hiders' invisible bodies, other finders).
	local ignore: { Instance } = {}
	for _, participant in r.Participants do
		if participant.Character then
			table.insert(ignore, participant.Character)
		end
	end
	local trace = Cannon.Trace(origin, target, ignore)

	local victim: Player? = if trace.Instance then owner(r, trace.Instance) else nil
	if victim and r.Role[victim] ~= "Hider" then
		victim = nil
	end
	local hitPoint = trace.Stop
	local normal = trace.Normal
	if victim == nil then
		local best = math.huge
		for hider, d in r.Disguises do
			if r.Role[hider] == "Hider" and d.Body.Parent then
				local box = d.Model:GetBoundingBox()
				local along = Cannon.Near(trace, box.Position, d.Radius, r.Settings.HitTolerance)
				if along and along < best then
					best = along
					victim = hider
					local back = origin - box.Position
					local side = if back.Magnitude > 1e-3 then back.Unit else Vector3.yAxis
					hitPoint = box.Position + side * d.Radius * 0.8
					normal = side
				end
			end
		end
	end
	local result = "Miss"
	local cooldown = cfg.FireCooldown
	local hitProp = if trace.Instance and not victim then propOf(r, trace.Instance) else nil
	if victim then
		result = "Hider"
	elseif hitProp then
		result = "Prop"
		cooldown += r.Settings.PropPenalty
		r.NextShot[player] = now + cooldown
	end
	eventRemote:FireAllClients("Shot", {
		Shooter = player,
		From = origin,
		To = hitPoint,
		Normal = normal,
		Result = result,
		Prop = if hitProp then propName(hitProp) else nil,
		Cooldown = cooldown,
	})
	if victim then
		found(r, victim, player, hitPoint)
	end
end

-- Hiders' actions ------------------------------------------------------------------------------

-- The nearest thing within range of `point`, or nil.
local function nearestProp(r: Round, point: Vector3): Instance?
	local range = Config.PropHunt.Disguise.Range
	local best: Instance? = nil
	local bestDistance = range
	for _, prop in r.Props do
		if prop:IsDescendantOf(r.Map.Model) then
			local distance = distanceTo(prop, point)
			if distance <= bestDistance then
				best = prop
				bestDistance = distance
			end
		end
	end
	return best
end

local function onBecome(r: Round, player: Player, target: unknown)
	local cfg = Config.PropHunt.Disguise
	local now = os.clock()
	if now < (r.NextChange[player] or 0) then
		return
	end
	local _, _, root = alive(player)
	if not root then
		return
	end
	if r.Released and (r.ChangesLeft[player] or 0) <= 0 then
		return
	end
	local prop: Instance? = nil
	if target == nil then
		prop = nearestProp(r, root.Position)
	elseif typeof(target) == "Instance" then
		prop = propOf(r, target)
	end
	if not prop then
		return
	end
	if distanceTo(prop, root.Position) > cfg.Range then
		return
	end
	local _, size = boxOf(prop)
	if math.max(size.X, size.Y, size.Z) > cfg.MaxSize then
		return
	end
	r.NextChange[player] = now + cfg.Cooldown
	if disguise(r, player, prop) then
		if r.Released then
			r.ChangesLeft[player] = (r.ChangesLeft[player] or 1) - 1
			player:SetAttribute("PropChangesLeft", r.ChangesLeft[player])
		end
		local d = r.Disguises[player]
		eventRemote:FireAllClients("Became", { Hider = player, Prop = d and d.Model })
		if r.Locked[player] then
			setFrozen(player, true)
		end
	end
end

local function onTaunt(r: Round, player: Player)
	local cfg = Config.PropHunt.Taunt
	local now = os.clock()
	if now < (r.NextTaunt[player] or 0) then
		return
	end
	local d = r.Disguises[player]
	if not d then
		return
	end
	r.NextTaunt[player] = now + cfg.Cooldown
	player:SetAttribute("PropTauntReadyAt", workspace:GetServerTimeNow() + cfg.Cooldown)
	local entry = r.Entries[player]
	if entry and r.Released and entry.Taunts < cfg.MaxCounted then
		entry.Taunts += 1
		player:SetAttribute("PropTaunts", entry.Taunts)
	end
	eventRemote:FireAllClients("Giggle", { Hider = player, Prop = d.Model, Taunt = true })
end

local function onAction(player: Player, action: unknown, argument: unknown)
	local r = round
	if not r or r.Over or r.Role[player] ~= "Hider" or typeof(action) ~= "string" then
		return
	end
	if action == "Become" then
		onBecome(r, player, argument)
	elseif action == "Lock" then
		if typeof(argument) ~= "boolean" or not Config.PropHunt.Lock.Enabled then
			return
		end
		if not alive(player) or not r.Disguises[player] then
			return
		end
		setLocked(r, player, argument)
	elseif action == "Taunt" then
		onTaunt(r, player)
	end
end

shootRemote.OnServerEvent:Connect(onShoot)
actionRemote.OnServerEvent:Connect(onAction)

-- Giggles and the last-seconds glow (every quarter second; Easy only by default).
local function effects(r: Round)
	local settings = r.Settings
	while round == r and not r.Over do
		local now = os.clock()
		if r.Released then
			for hider, d in r.Disguises do
				if r.Role[hider] ~= "Hider" or not d.Body.Parent then
					continue
				end
				local due = r.NextGiggle[hider]
				if due and now >= due and settings.GiggleInterval > 0 then
					local jitter = r.Rng:NextNumber(-0.2, 0.2) * settings.GiggleInterval
					r.NextGiggle[hider] = now + math.max(3, settings.GiggleInterval + jitter)
					eventRemote:FireAllClients(
						"Giggle",
						{ Hider = hider, Prop = d.Model, Taunt = false }
					)
				end
			end
			local glow = settings.GlowLastSeconds
			if not r.Glowing and glow > 0 and r.EndsAt - now <= glow then
				r.Glowing = true
				for _, d in r.Disguises do
					setGlow(d, true)
				end
				eventRemote:FireAllClients("Glow", {})
			end
		end
		task.wait(0.25)
	end
end

-- Round --------------------------------------------------------------------------------------

-- Undoes everything a round did. Safe to call when nothing is running.
function PropHunt.Cleanup()
	local r = round
	round = nil
	if r then
		r.Over = true
		for _, connection in r.Connections do
			connection:Disconnect()
		end
		for _, thread in r.Threads do
			if coroutine.status(thread) == "suspended" then
				pcall(task.cancel, thread)
			end
		end
		for _, fn in r.Undo do
			fn()
		end
		for player in r.Disguises do
			undisguise(r, player)
		end
		for player in r.Guns do
			takeGun(r, player)
		end
		for _, player in r.Participants do
			if player.Parent == Players then
				for _, name in PLAYER_ATTRIBUTES do
					player:SetAttribute(name, nil)
				end
				setFrozen(player, false)
			end
		end
		for player in table.clone(r.Heads) do
			removeHead(r, player)
		end
		r.Folder:Destroy()
	end
	ReplicatedStorage:SetAttribute("PropHidersLeft", nil)
	ReplicatedStorage:SetAttribute("PropFinderCount", nil)
end

local function winnerText(r: Round, winner: string?, endedEarly: boolean): string
	local text = Config.PropHunt.Text
	local hiders, seekers = counts(r)
	if winner == "Seekers" then
		return text.SeekersWin
	elseif winner == "Hiders" then
		if endedEarly and seekers == 0 then
			return text.NoSeekers
		end
		return text.HidersWin:format(hiders)
	end
	return text.TimeUp
end

function PropHunt.Run(ctx: Types.RoundContext): Types.RoundResult
	PropHunt.Cleanup()
	local cfg = Config.PropHunt
	local settings = Rules.Settings(cfg, ctx.Difficulty)
	local map = ctx.Map
	local rng = Random.new()

	local players: { Player } = {}
	for _, player in ctx.Players do
		if player.Parent == Players then
			table.insert(players, player)
		end
	end
	local wasFinder: { [Player]: boolean } = {}
	for _, player in players do
		if lastFinders[player.UserId] then
			wasFinder[player] = true
		end
	end
	local finders, hiders =
		Rules.PickFinders(players, Rules.FinderCount(#players, cfg), rng, wasFinder)
	table.clear(lastFinders)
	for _, player in finders do
		lastFinders[player.UserId] = true
	end

	local folder = Instance.new("Folder")
	folder.Name = "HiderThings"
	folder.Parent = map.Model
	local hiderSpawns = tagged(map, Tags.HiderSpawn)
	local seekerSpawns = tagged(map, Tags.SeekerSpawn)
	local props: { Instance } = {}
	for _, instance in CollectionService:GetTagged(Tags.PropHuntProp) do
		if
			(instance:IsA("Model") or instance:IsA("BasePart"))
			and instance:IsDescendantOf(map.Model)
		then
			table.insert(props, instance)
		end
	end
	local r: Round = {
		Map = map,
		Rng = rng,
		Settings = settings,
		Participants = players,
		Role = {},
		Entries = {},
		Disguises = {},
		Guns = {},
		Heads = {},
		NextShot = {},
		NextGiggle = {},
		NextChange = {},
		NextTaunt = {},
		ChangesLeft = {},
		Locked = {},
		HiderSpawns = if #hiderSpawns > 0 then hiderSpawns else map.Spawns,
		SeekerSpawns = if #seekerSpawns > 0 then seekerSpawns else map.Spawns,
		Props = props,
		Folder = folder,
		Released = false,
		ReleasedAt = 0,
		EndsAt = math.huge,
		Glowing = false,
		StartedHiders = #hiders,
		StartedSeekers = #finders,
		Connections = {},
		Threads = {},
		Undo = {},
		Over = false,
	}
	round = r

	-- Something put a skin on a finder mid-round (the shop, a respawn): the pumpkin head goes
	-- back on top.
	table.insert(
		r.Undo,
		Cosmetics.OnSkinChanged(function(character: Model, item: any?)
			if item == FINDER_ITEM then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player and r.Heads[player] then
				task.defer(function()
					if
						round == r
						and not r.Over
						and r.Heads[player]
						and r.Role[player] == "Seeker"
						and player.Character == character
					then
						Cosmetics.Wear(character, FINDER_ITEM)
					end
				end)
			end
		end)
	)

	local function join(player: Player, role: Role)
		r.Role[player] = role
		r.Entries[player] = {
			UserId = player.UserId,
			Name = player.DisplayName,
			StartRole = role,
			Finds = 0,
			Found = false,
			HiddenSeconds = 0,
			Taunts = 0,
		}
		player:SetAttribute("HideSeekRole", role)
		player:SetAttribute("PropFinds", 0)
		player:SetAttribute("PropTaunts", 0)
		player:SetAttribute("PropLocked", false)
		if role == "Hider" then
			r.ChangesLeft[player] = settings.PropChanges
			player:SetAttribute("PropChangesLeft", settings.PropChanges)
		end
	end
	for _, player in finders do
		join(player, "Seeker")
	end
	for _, player in hiders do
		join(player, "Hider")
	end
	publish(r)

	local spawnOrder = shuffled(r.HiderSpawns, rng)
	for i, player in hiders do
		placeOn(r, player, spawnOrder[(i - 1) % math.max(#spawnOrder, 1) + 1])
		if cfg.Disguise.StartAsProp then
			disguise(r, player, startProp(r))
		end
	end
	for _, player in finders do
		local spawn, row = seekerSpot(r, player)
		placeOn(r, player, spawn, row)
		setFrozen(player, true)
		wearHead(r, player)
	end

	for _, player in players do
		table.insert(
			r.Connections,
			player.CharacterAdded:Connect(function(character)
				task.spawn(function()
					character:WaitForChild("HumanoidRootPart", 5)
					task.wait()
					if round == r and not r.Over and player.Character == character then
						setUp(r, player, true)
					end
				end)
			end)
		)
	end
	table.insert(
		r.Connections,
		Players.PlayerRemoving:Connect(function(player)
			local role = r.Role[player]
			if role == nil then
				return
			end
			undisguise(r, player)
			takeGun(r, player)
			r.Heads[player] = nil
			r.Role[player] = nil
			r.Entries[player] = nil
			r.NextShot[player] = nil
			r.NextGiggle[player] = nil
			r.NextChange[player] = nil
			r.NextTaunt[player] = nil
			r.ChangesLeft[player] = nil
			r.Locked[player] = nil
			local hidersLeft, seekersLeft = counts(r)
			-- Every finder left: a hider takes over (if one can be spared).
			if role == "Seeker" and seekersLeft == 0 and hidersLeft >= 2 then
				local list: { Player } = {}
				for other, otherRole in r.Role do
					if otherRole == "Hider" and other.Parent == Players then
						table.insert(list, other)
					end
				end
				table.sort(list, function(a, b)
					return a.UserId < b.UserId
				end)
				local promoted = Rules.Promote(list, r.Rng)
				if promoted then
					local entry = r.Entries[promoted]
					if entry and not r.Released then
						entry.StartRole = "Seeker"
					end
					makeFinder(r, promoted, 0)
				end
			end
			publish(r)
		end)
	)
	table.insert(r.Threads, task.spawn(effects, r))

	-- Hiding: the finders count in the hut.
	ctx.Countdown("Hiding", settings.HeadStart, function()
		return decided(r)
	end)
	if not decided(r) then
		release(r)
		ctx.Countdown("Playing", settings.Duration, function()
			return decided(r)
		end)
	end

	-- Score everyone still in the server.
	local endedEarly = decided(r)
	local winner = Rules.Winner(winnerState(r, true))
	local now = os.clock()
	local entries: { Rules.Entry } = {}
	for player, entry in r.Entries do
		if player.Parent ~= Players then
			continue
		end
		if entry.StartRole == "Hider" and not entry.Found then
			entry.HiddenSeconds = if r.Released then now - r.ReleasedAt else 0
		end
		table.insert(entries, entry)
	end
	local winnerLine = winnerText(r, winner, endedEarly)
	PropHunt.Cleanup()

	local rows: { Types.ResultRow } = {}
	for _, row in Rules.Results(entries, winner, cfg, settings.RewardMultiplier) do
		table.insert(rows, {
			UserId = row.UserId,
			Name = row.Name,
			Score = row.Score,
			Pumpkins = row.Pumpkins,
			Coins = row.Coins,
			Survived = row.Survived,
			Top = row.Top,
			Team = row.Team,
			Badge = row.Badge,
			Stat = row.Stat,
		})
	end
	return {
		Rows = rows,
		ScoreLabel = cfg.Text.ScoreLabel,
		Winner = winnerLine,
		MvpLine = cfg.Text.MvpLine,
	}
end

return PropHunt
