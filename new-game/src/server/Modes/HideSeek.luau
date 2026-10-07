--!strict
--[[
	PUMPKIN HIDE & SEEK: hiders are pumpkins, seekers have candy guns.
	On/off: Config.Features.HideSeek (off = the vote never offers it). Settings: Config.HideSeek.
	Maps: Pumpkin Farm and Hedge Maze (Config.Modes.Playlists), or any map with the tags below.

	How a round goes (Run):
	  1. Roles: Config.HideSeek.SeekerRatio of the players are seekers (at least 1, never
	     everyone; last round's seekers are picked last), the rest hide.
	  2. Hiders go to parts tagged HiderSpawn and turn into pumpkins: their character is made
	     invisible and a copy of one of the map's decoys (tag HidingDecoy) is welded on,
	     sitting on the ground. While hidden, the shop doesn't dress them (ShopService.Dress);
	     their look comes back when they are found. Seekers wait in the closed seeker hut
	     (parts tagged SeekerSpawn; extra seekers line up in front of the pads), frozen, with a
	     "COUNTING..." blindfold on screen, for HeadStart seconds (State "Hiding").
	  3. The hut door (tag SeekerDoor) swings open and every seeker gets a candy gun (State
	     "Playing"). The client sends where the player aimed (remote HideSeekShoot); the server
	     checks it's a seeker in this round, with the gun out and off cooldown, casts a ray from
	     the seeker's head (src/server/Modes/CandyGun.luau) and tags the hider whose pumpkin it
	     hits. Hitting a decoy adds Gun.DecoyPenalty to the cooldown.
	  4. Tagged hiders join the seekers (TaggedBecomeSeekers) or watch as ghosts. Hiders giggle
	     every GiggleInterval, leave a leaf trail while moving and glow in the last
	     GlowLastSeconds, so they are fairly easy to find. A hider who resets (or dies) after
	     the seekers are out leaves their pumpkin in place (it can still be tagged) and comes
	     back to it.
	  5. The round ends when every pumpkin is found (seekers win), at 0:00 (pumpkins still
	     hidden win) or when every seeker leaves (pumpkins win; during the head start a hider
	     is made a seeker instead). Scores: tags; coins: Config.HideSeek.Rewards; saved stats:
	     Stats.HideSeekTags and Stats.HideSeekWins.

	Attributes clients read:
	  ReplicatedStorage: HidersLeft, SeekerCount (numbers, during the round)
	  Player: HideSeekRole ("Hider", "Seeker" or "Out"), HideSeekTags (this round's tags)
	Remotes (made when this module loads, which is before GameService sets Mode = "HideSeek"):
	  HideSeekShoot (client -> server): target Vector3, where the player aimed
	  HideSeekEvent (server -> clients): (kind, data) with kind
	    "Shot"     { Shooter, From, To, Normal?, Result = "Hider"|"Decoy"|"Miss", Candy, Cooldown }
	    "Tagged"   { Hider, Seeker, Position, HidersLeft }
	    "Giggle"   { Hider, Pumpkin }      (the client plays the giggle and puffs sparkles)
	    "Released" {}                      (seekers are out)
	    "Glow"     {}                      (the last seconds: pumpkins glow)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local HidingPumpkin = require(script.Parent.Parent.Build.HidingPumpkin)
local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local GhostService = require(Services.GhostService)
local MapService = require(Services.MapService)
local ShopService = require(Services.ShopService)
local CandyGun = require(script.Parent.CandyGun)
local Rules = require(script.Parent.HideSeekRules)
local Types = require(script.Parent.Types)

local HideSeek = {}

type Role = Rules.Role

-- A hider's pumpkin and how to undo everything done to their character.
type Disguise = {
	Model: Model,
	Body: BasePart,
	Radius: number, -- half the pumpkin's width (for near-miss hits)
	Source: Instance?, -- the map decoy it is a copy of (nil = built by HidingPumpkin)
	FloorOffset: CFrame, -- where the pumpkin's bottom middle is, seen from Body
	Frozen: CFrame?, -- set while the hider is dead: the pumpkin waits on this spot (its bottom)
	Trail: ParticleEmitter,
	Light: PointLight,
	Highlight: Highlight,
	Undo: { () -> () },
	Connections: { RBXScriptConnection },
}

type Round = {
	Map: MapService.LoadedMap,
	Rng: Random,
	Participants: { Player },
	Role: { [Player]: Role }, -- players still playing (found ghosts and leavers are removed)
	Entries: { [Player]: Rules.Entry },
	Disguises: { [Player]: Disguise },
	Guns: { [Player]: Tool },
	NextShot: { [Player]: number }, -- os.clock() when the player may shoot again
	NextGiggle: { [Player]: number },
	HiderSpawns: { BasePart },
	SeekerSpawns: { BasePart },
	Decoys: { Instance }, -- the map's decoy pumpkins (tag HidingDecoy): hiders copy one
	Pumpkins: Folder,
	Released: boolean,
	ReleasedAt: number,
	EndsAt: number,
	Glowing: boolean,
	StartedHiders: number,
	StartedSeekers: number,
	Connections: { RBXScriptConnection },
	Threads: { thread },
	Over: boolean,
}

local round: Round? = nil
local lastSeekers: { [number]: boolean } = {} -- UserIds of last round's seekers

local shootRemote = Remotes.Event("HideSeekShoot")
local eventRemote = Remotes.Event("HideSeekEvent")

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
	return root.Size.Y / 2 + 2 -- R6: half the torso plus the legs
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

-- Parts in the map with `tag` (functional parts are found by tag, see src/shared/Tags.luau).
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
	ReplicatedStorage:SetAttribute("HidersLeft", hiders)
	ReplicatedStorage:SetAttribute("SeekerCount", seekers)
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

-- The round is decided (someone won early) or everyone left.
local function decided(r: Round): boolean
	if next(r.Role) == nil then
		return true
	end
	return Rules.Winner(winnerState(r, false)) ~= nil
end

local function addStat(player: Player, key: string, amount: number)
	local data = DataService.Get(player)
	local stats = data and data.Stats
	if type(stats) == "table" then
		stats[key] = (tonumber(stats[key]) or 0) + amount
	end
end

-- Stands the character with its feet on `floor` (a position and the way to face).
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

-- Where players stand on `spawn`: `row` 0 is the pad itself, rows 1, 2... are lined up in
-- front of it, Config.HideSeek.SpawnRowSpacing apart (more seekers than seeker pads).
local function spotOn(spawn: BasePart, row: number): Vector3
	local ahead = row * Config.HideSeek.SpawnRowSpacing
	return (spawn.CFrame * CFrame.new(0, 0, -ahead)).Position + Vector3.new(0, spawn.Size.Y / 2, 0)
end

-- Stands the character on top of `spawn` (a little spread out so players don't stack).
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

--[[
	The seeker pad (and row) for `player`: the first spot nobody else in the round stands on,
	trying every pad before starting a row in front of them (at most Config.HideSeek.SpawnRows
	rows). The seeker hut has 4 small pads, so with 5+ seekers nobody ends up frozen inside
	someone else (they would be flung about when the door opens).
]]
local function seekerSpot(r: Round, player: Player): (BasePart?, number)
	local cfg = Config.HideSeek
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

-- Seekers can't move while they count (anchored on the server, so nobody can cheat it).
local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = frozen
	end
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

local function makeEffects(model: Model, body: BasePart): (ParticleEmitter, PointLight, Highlight)
	local fx = Config.HideSeek.Effects
	local box, size = model:GetBoundingBox()
	local function attachment(name: string, y: number): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = body.CFrame:PointToObjectSpace(Vector3.new(box.X, y, box.Z))
		a.Parent = body
		return a
	end

	local trail = Instance.new("ParticleEmitter")
	trail.Name = "LeafTrail"
	trail.Enabled = false
	trail.Rate = fx.LeafRate
	trail.Color = ColorSequence.new(fx.LeafColors[1], fx.LeafColors[#fx.LeafColors])
	trail.Size = NumberSequence.new(0.4, 0.2)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.75, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = NumberRange.new(1.6, 2.6)
	trail.Speed = NumberRange.new(0.6, 1.6)
	trail.SpreadAngle = Vector2.new(70, 70)
	trail.Acceleration = Vector3.new(0, -1.5, 0)
	trail.Rotation = NumberRange.new(0, 360)
	trail.RotSpeed = NumberRange.new(-120, 120)
	trail.LightInfluence = 0.6
	trail.Parent = attachment("LeafTrail", box.Y - size.Y / 2 + 0.25)

	-- Puffed by each client when this hider giggles (HideSeekUI calls :Emit on it).
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
	sparkles.Parent = attachment("GiggleSparkles", box.Y + size.Y / 2)

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
	return trail, light, highlight
end

--[[
	A pumpkin for a hider, its bottom middle on `floor`: a copy of one of the map's decoys
	(`like` if given), so it looks exactly like them even on a map that was baked or edited by
	hand before the pumpkin look changed. Maps without decoys get a new one from
	src/server/Build/HidingPumpkin.luau. Returns the model and the decoy it copies.
]]
local function newPumpkin(r: Round, floor: CFrame, like: Instance?): (Model, Instance?)
	local source: Instance? = nil
	if like and like:IsDescendantOf(r.Map.Model) then
		source = like
	else
		for _ = 1, 5 do -- (a decoy may have been deleted during the round)
			local candidate = if #r.Decoys > 0
				then r.Decoys[r.Rng:NextInteger(1, #r.Decoys)]
				else nil
			if candidate and candidate:IsDescendantOf(r.Map.Model) then
				source = candidate
				break
			end
		end
	end
	if not source then
		return HidingPumpkin.Build(floor, r.Rng, r.Pumpkins), nil
	end
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		model = Instance.new("Model")
		copy.Parent = model
		if copy:IsA("BasePart") then
			model.PrimaryPart = copy
		end
	end
	model.Name = "Pumpkin"
	-- Not a decoy any more (candy that hits it finds a hider), and never any scripts.
	CollectionService:RemoveTag(model, Tags.HidingDecoy)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		else
			CollectionService:RemoveTag(d, Tags.HidingDecoy)
		end
	end
	local box, size = model:GetBoundingBox()
	local bottom = box.Position - box.UpVector * (size.Y / 2)
	model:PivotTo(model:GetPivot() + (floor.Position - bottom))
	model.Parent = r.Pumpkins
	return model, source
end

-- The hider died: their pumpkin stays where it is (anchored, it can still be found) and they
-- come back there (setUp), so resetting is no way to escape a seeker.
local function freeze(d: Disguise)
	local spot = d.Body.CFrame * d.FloorOffset
	local level = CFrame.new(spot.Position) * yaw(spot)
	d.Frozen = level
	d.Trail.Enabled = false
	for _, part in d.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		elseif part:IsA("WeldConstraint") then
			local other = part.Part0
			if other and not other:IsDescendantOf(d.Model) then
				part:Destroy() -- the weld to the dead character
			end
		end
	end
	d.Model:PivotTo(level * spot:ToObjectSpace(d.Model:GetPivot()))
end

-- Still on the map (not fallen into the void or out of the world)?
local function onMap(r: Round, part: BasePart): boolean
	local floor = r.Map.Floor
	return part:IsDescendantOf(workspace)
		and part.Position.Y > floor.Position.Y - floor.Size.Y / 2 - Config.HideSeek.FallMargin
end

-- Turns a hider's character into a pumpkin (again, after a respawn).
local function disguise(r: Round, player: Player)
	local before = r.Disguises[player]
	local like = if before then before.Source else nil
	undisguise(r, player)
	local character, humanoid, root = alive(player)
	if not character or not humanoid or not root then
		return
	end
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
	-- Everything that shows who you are: body, face, clothes' accessories, cosmetics, name.
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			set(d, "Transparency", 1)
			set(d, "CastShadow", false)
		elseif d:IsA("Decal") then -- faces (and Textures)
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

	-- The pumpkin lives in the map (not in the character) so candy rays that skip characters
	-- still hit it; it is welded to the root part, its bottom on the floor under the feet.
	-- After a respawn it copies the same decoy as before, so it doesn't change its look.
	local floorAt = root.Position - Vector3.new(0, rootHeight(humanoid, root), 0)
	local floor = CFrame.new(floorAt) * yaw(root.CFrame)
	local model, source = newPumpkin(r, floor, like)
	model:SetAttribute("HiderUserId", player.UserId)
	-- (screens wobble it now and then exactly like the decoys: src/client/MapLife.luau)
	CollectionService:AddTag(model, Tags.HiderPumpkin)
	-- (its width, for near misses: measured before it is welded on)
	local width = model:GetAttribute("PumpkinWidth")
	if typeof(width) ~= "number" then
		local _, size = model:GetBoundingBox()
		width = math.max(size.X, size.Z)
	end
	local body: BasePart? = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			-- (a custom pumpkin model may have no PrimaryPart: then its biggest part)
			if not model.PrimaryPart and (not body or d.Size.Magnitude > body.Size.Magnitude) then
				body = d
			end
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
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
		return
	end
	local trail, light, highlight = makeEffects(model, body)
	local d: Disguise = {
		Model = model,
		Body = body,
		Radius = (if typeof(width) == "number" then width else Config.HideSeek.Pumpkin.Width) / 2,
		Source = source,
		FloorOffset = body.CFrame:ToObjectSpace(floor),
		Frozen = nil,
		Trail = trail,
		Light = light,
		Highlight = highlight,
		Undo = undo,
		Connections = {},
	}
	-- New things on the character (a cosmetic equipped mid-round) are hidden too.
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
	-- A dead character's welds break. Once the seekers are out, the pumpkin stays put (it can
	-- still be found) and the hider comes back to it; before that, or if it fell off the
	-- map, it goes away and the hider starts again on a hider spawn.
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
	if r.Glowing then
		setGlow(d, true)
	end
end

-- Seekers --------------------------------------------------------------------------------------

local function giveGun(r: Round, player: Player)
	local character, humanoid = alive(player)
	if not character or not humanoid then
		return
	end
	local old = r.Guns[player]
	-- First gun, or the old one went with the old character's backpack.
	local gun = if old and old.Parent ~= nil then old else CandyGun.Make()
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

-- Puts a player (back) into the round as their role: on a spawn, as a pumpkin or with a gun.
local function setUp(r: Round, player: Player, move: boolean)
	local role = r.Role[player]
	if role == "Hider" then
		if move then
			local old = r.Disguises[player]
			local waiting = if old then old.Frozen else nil
			if waiting then
				placeAt(player, waiting) -- back to the pumpkin they left when they died
			else
				placeOn(r, player, pick(r.HiderSpawns, r.Rng))
			end
		end
		disguise(r, player)
	elseif role == "Seeker" then
		if move then
			local spawn, row = seekerSpot(r, player)
			placeOn(r, player, spawn, row)
		end
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
			-- Swing outwards (towards its front) round its left edge.
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
			-- A door made of several parts: they just vanish.
			for _, d in instance:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Transparency = 1
				end
			end
		end
	end
end

local function release(r: Round)
	local cfg = Config.HideSeek
	r.Released = true
	r.ReleasedAt = os.clock()
	r.EndsAt = r.ReleasedAt + cfg.Duration
	openDoors(r)
	for player, role in r.Role do
		if role == "Seeker" then
			setFrozen(player, false)
			giveGun(r, player)
		elseif role == "Hider" then
			local jitter = r.Rng:NextNumber(-cfg.GiggleJitter, cfg.GiggleJitter)
			r.NextGiggle[player] = r.ReleasedAt + math.max(2, cfg.FirstGiggleAfter + jitter)
		end
	end
	eventRemote:FireAllClients("Released", {})
end

-- Tagging and shooting -----------------------------------------------------------------------

local function tag(r: Round, hider: Player, seeker: Player, position: Vector3)
	if r.Role[hider] ~= "Hider" then
		return
	end
	local cfg = Config.HideSeek
	local now = os.clock()
	local entry = r.Entries[hider]
	if entry then
		entry.Found = true
		entry.HiddenSeconds = if r.Released then now - r.ReleasedAt else 0
	end
	local seekerEntry = r.Entries[seeker]
	if seekerEntry then
		seekerEntry.Tags += 1
		seeker:SetAttribute("HideSeekTags", seekerEntry.Tags)
	end
	addStat(seeker, "HideSeekTags", 1)
	undisguise(r, hider)
	r.NextGiggle[hider] = nil
	if cfg.TaggedBecomeSeekers then
		r.Role[hider] = "Seeker"
		r.NextShot[hider] = now + cfg.TaggedSeekerDelay
	else
		r.Role[hider] = nil
	end
	publish(r)
	local hidersLeft = counts(r)
	eventRemote:FireAllClients("Tagged", {
		Hider = hider,
		Seeker = seeker,
		Position = position,
		HidersLeft = hidersLeft,
	})
	if cfg.TaggedBecomeSeekers then
		hider:SetAttribute("HideSeekRole", "Seeker")
		-- Their own look back (with anything they equipped while hidden).
		task.spawn(ShopService.Dress, hider)
		task.delay(cfg.TaggedSeekerDelay, function()
			if round == r and not r.Over and r.Role[hider] == "Seeker" then
				giveGun(r, hider)
			end
		end)
	else
		hider:SetAttribute("HideSeekRole", "Out")
		task.spawn(ShopService.Dress, hider)
		GhostService.MarkOut(hider, true)
	end
end

local function isDecoy(part: Instance): boolean
	local node: Instance? = part
	while node and node ~= workspace do
		if CollectionService:HasTag(node, Tags.HidingDecoy) then
			return true
		end
		node = node.Parent
	end
	return false
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
	if typeof(target) ~= "Vector3" or not CandyGun.Finite(target) then
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
		return -- the gun must be out
	end
	local cfg = Config.HideSeek.Gun
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart")
		then head.Position
		else root.Position + Vector3.new(0, 1.5, 0)
	if (target - origin).Magnitude < 0.5 then
		return
	end
	r.NextShot[player] = now + cfg.FireCooldown

	-- Characters never stop a candy (hiders' invisible bodies, other seekers).
	local ignore: { Instance } = {}
	for _, participant in r.Participants do
		if participant.Character then
			table.insert(ignore, participant.Character)
		end
	end
	local trace = CandyGun.Trace(origin, target, ignore)

	-- A direct hit on a hider's pumpkin, else the hider the candy passes closest to first.
	local victim: Player? = if trace.Instance then owner(r, trace.Instance) else nil
	local hitPoint = trace.Stop
	local normal = trace.Normal
	if victim == nil then
		local best = math.huge
		for hider, d in r.Disguises do
			if r.Role[hider] == "Hider" and d.Body.Parent then
				local along = CandyGun.Near(trace, d.Body.Position, d.Radius)
				if along and along < best then
					best = along
					victim = hider
					local back = origin - d.Body.Position
					local side = if back.Magnitude > 1e-3 then back.Unit else Vector3.yAxis
					hitPoint = d.Body.Position + side * d.Radius * 0.8
					normal = side
				end
			end
		end
	end
	local result = "Miss"
	local cooldown = cfg.FireCooldown
	if victim then
		result = "Hider"
	elseif trace.Instance and isDecoy(trace.Instance) then
		result = "Decoy"
		cooldown += cfg.DecoyPenalty
		r.NextShot[player] = now + cooldown
	end
	eventRemote:FireAllClients("Shot", {
		Shooter = player,
		From = origin,
		To = hitPoint,
		Normal = normal,
		Result = result,
		Candy = r.Rng:NextInteger(1, #cfg.CandyColors),
		Cooldown = cooldown,
	})
	if victim then
		tag(r, victim, player, hitPoint)
	end
end

shootRemote.OnServerEvent:Connect(onShoot)

-- Giggles, leaf trails and the last-seconds glow (every quarter second).
local function effects(r: Round)
	local cfg = Config.HideSeek
	while round == r and not r.Over do
		local now = os.clock()
		if r.Released then
			for hider, d in r.Disguises do
				if r.Role[hider] ~= "Hider" or not d.Body.Parent then
					continue
				end
				local v = d.Body.AssemblyLinearVelocity
				local moving = Vector3.new(v.X, 0, v.Z).Magnitude > cfg.TrailMinSpeed
				if d.Trail.Enabled ~= moving then
					d.Trail.Enabled = moving
				end
				local due = r.NextGiggle[hider]
				if due and now >= due then
					local jitter = r.Rng:NextNumber(-cfg.GiggleJitter, cfg.GiggleJitter)
					r.NextGiggle[hider] = now + math.max(2, cfg.GiggleInterval + jitter)
					eventRemote:FireAllClients("Giggle", { Hider = hider, Pumpkin = d.Model })
				end
			end
			if not r.Glowing and r.EndsAt - now <= cfg.GlowLastSeconds then
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
function HideSeek.Cleanup()
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
		for player in r.Disguises do
			undisguise(r, player)
		end
		for player in r.Guns do
			takeGun(r, player)
		end
		for _, player in r.Participants do
			if player.Parent == Players then
				player:SetAttribute("HideSeekRole", nil)
				player:SetAttribute("HideSeekTags", nil)
				setFrozen(player, false)
			end
		end
		r.Pumpkins:Destroy()
	end
	ReplicatedStorage:SetAttribute("HidersLeft", nil)
	ReplicatedStorage:SetAttribute("SeekerCount", nil)
end

local function winnerText(r: Round, winner: string?, endedEarly: boolean): string
	local text = Config.HideSeek.Text
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

function HideSeek.Run(ctx: Types.RoundContext): Types.RoundResult
	HideSeek.Cleanup()
	local cfg = Config.HideSeek
	local map = ctx.Map
	local rng = Random.new()

	local players: { Player } = {}
	for _, player in ctx.Players do
		if player.Parent == Players then
			table.insert(players, player)
		end
	end
	local wasSeeker: { [Player]: boolean } = {}
	for _, player in players do
		if lastSeekers[player.UserId] then
			wasSeeker[player] = true
		end
	end
	local seekers, hiders =
		Rules.PickSeekers(players, Rules.SeekerCount(#players, cfg), rng, wasSeeker)
	table.clear(lastSeekers)
	for _, player in seekers do
		lastSeekers[player.UserId] = true
	end

	local folder = Instance.new("Folder")
	folder.Name = "HiderPumpkins"
	folder.Parent = map.Model
	local hiderSpawns = tagged(map, Tags.HiderSpawn)
	local seekerSpawns = tagged(map, Tags.SeekerSpawn)
	local decoys: { Instance } = {}
	for _, instance in CollectionService:GetTagged(Tags.HidingDecoy) do
		if
			(instance:IsA("Model") or instance:IsA("BasePart"))
			and instance:IsDescendantOf(map.Model)
		then
			table.insert(decoys, instance)
		end
	end
	local r: Round = {
		Map = map,
		Rng = rng,
		Participants = players,
		Role = {},
		Entries = {},
		Disguises = {},
		Guns = {},
		NextShot = {},
		NextGiggle = {},
		-- Maps without the tags still work: everyone uses the map's normal spawns.
		HiderSpawns = if #hiderSpawns > 0 then hiderSpawns else map.Spawns,
		SeekerSpawns = if #seekerSpawns > 0 then seekerSpawns else map.Spawns,
		Decoys = decoys,
		Pumpkins = folder,
		Released = false,
		ReleasedAt = 0,
		EndsAt = math.huge,
		Glowing = false,
		StartedHiders = #hiders,
		StartedSeekers = #seekers,
		Connections = {},
		Threads = {},
		Over = false,
	}
	round = r

	local function join(player: Player, role: Role)
		r.Role[player] = role
		r.Entries[player] = {
			UserId = player.UserId,
			Name = player.DisplayName,
			StartRole = role,
			Tags = 0,
			Found = false,
			HiddenSeconds = 0,
		}
		player:SetAttribute("HideSeekRole", role)
		player:SetAttribute("HideSeekTags", 0)
	end
	for _, player in seekers do
		join(player, "Seeker")
	end
	for _, player in hiders do
		join(player, "Hider")
	end
	publish(r)

	-- Hiders spread over the hider spawns, seekers into the hut.
	local spawnOrder = shuffled(r.HiderSpawns, rng)
	for i, player in hiders do
		placeOn(r, player, spawnOrder[(i - 1) % #spawnOrder + 1])
		disguise(r, player)
	end
	for _, player in seekers do
		local spawn, row = seekerSpot(r, player)
		placeOn(r, player, spawn, row)
		setFrozen(player, true)
	end

	-- A new character (reset, fell off) goes straight back in as its role.
	for _, player in players do
		table.insert(
			r.Connections,
			player.CharacterAdded:Connect(function(character)
				task.spawn(function()
					character:WaitForChild("HumanoidRootPart", 5)
					task.wait() -- let Roblox finish putting it on the lobby spawn first
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
			r.Role[player] = nil
			r.Entries[player] = nil
			r.NextShot[player] = nil
			r.NextGiggle[player] = nil
			local hidersLeft, seekersLeft = counts(r)
			-- Every seeker left while still counting: a hider takes over (if one can be spared).
			if role == "Seeker" and not r.Released and seekersLeft == 0 and hidersLeft >= 2 then
				local list: { Player } = {}
				for other, otherRole in r.Role do
					if otherRole == "Hider" and other.Parent == Players then
						table.insert(list, other)
					end
				end
				local promoted = Rules.Promote(list, r.Rng)
				if promoted then
					undisguise(r, promoted)
					r.Role[promoted] = "Seeker"
					local entry = r.Entries[promoted]
					if entry then
						entry.StartRole = "Seeker"
					end
					promoted:SetAttribute("HideSeekRole", "Seeker")
					task.spawn(ShopService.Dress, promoted)
					setUp(r, promoted, true)
				end
			end
			publish(r)
		end)
	)
	table.insert(r.Threads, task.spawn(effects, r))

	-- Hiding: the seekers count in the hut.
	ctx.Countdown("Hiding", cfg.HeadStart, function()
		return decided(r)
	end)
	if not decided(r) then
		release(r)
		ctx.Countdown("Playing", cfg.Duration, function()
			return decided(r)
		end)
	end

	-- Score everyone still in the server.
	local endedEarly = decided(r)
	local winner = Rules.Winner(winnerState(r, true))
	local now = os.clock()
	local entries: { Rules.Entry } = {}
	local byUserId: { [number]: Player } = {}
	for player, entry in r.Entries do
		if player.Parent ~= Players then
			continue
		end
		if entry.StartRole == "Hider" and not entry.Found then
			entry.HiddenSeconds = if r.Released then now - r.ReleasedAt else 0
		end
		table.insert(entries, entry)
		byUserId[entry.UserId] = player
	end
	local winnerLine = winnerText(r, winner, endedEarly)
	HideSeek.Cleanup()

	local rows: { Types.ResultRow } = {}
	for _, row in Rules.Results(entries, winner, cfg) do
		local player = byUserId[row.UserId]
		if row.Won and player then
			addStat(player, "HideSeekWins", 1)
		end
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

return HideSeek
