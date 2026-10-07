--!strict
--[[
	The lobby comes alive (this client only: the server never moves anything here).
	Settings and switches: Config.Lobby.Life (src/shared/Config/Lobby.luau). Off with
	Config.Lobby.Life.On = false, or each part with its own On.

	Only things within Life.Range of the camera (Life.PhoneRange on phones) animate; when the
	camera moves away (and when you leave) everything goes back exactly where it was. While
	nothing is near, it only looks around a few times a second (Config.Performance.IdleScanHz).
	  Keeper     every Model tagged ShopKeeper holding a character Model (Life.Keeper.Models:
	             the built "Keeper" or a custom "Look") breathes, turns (yaw only, within
	             MaxTurn degrees) to the nearest player and waves one arm when a player walks
	             up. A model without arm parts does a whole-body wiggle instead. Its parts are
	             moved from their rest pose each frame, so nothing drifts.
	  ReadyPad   a soft neon ring round each ReadyPad part pulses, faster while ReadyCount (a
	             ReplicatedStorage attribute) is above 0; the floating sign (tag ReadySign) hops
	             when ReadyCount changes (its BillboardGui's StudsOffset, nothing else).
	  FloorSigns the words, frame and light of every FloorSign part breathe like glowing paint.
	  Cauldron   the plaza's cauldron (a prop with PropName "Cauldron") puffs bubbles now and
	             then and its "Bubble" parts bob.
	  Bats       now and then a little bat flaps across the sky near you in the lobby.
	Everything made here is in Workspace.LobbyLifeFx: never solid, clickable or touchable.
	Streamed-out parts are skipped and picked up again when they come back.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)
local Tags = require(ReplicatedStorage.Shared.Tags)
local FramePace = require(script.Parent.FramePace)
local Layout = require(script.Parent.Layout)

type Keeper = {
	Npc: Model,
	Model: Model?,
	Parts: { BasePart },
	Rest: { CFrame }, -- each part where the server put it
	Rel: { CFrame }, -- each part relative to Root
	Root: CFrame, -- the keeper's feet, facing out over its counter
	Arm: number?, -- index in Parts of the arm that waves
	ArmSide: number, -- +1 = on the keeper's +X side
	Shoulder: CFrame, -- the waving arm's shoulder, relative to Root
	Yaw: number,
	Active: boolean,
	Near: boolean,
	WaveStart: number?,
	Phase: number,
	Dirty: boolean,
	Watch: { RBXScriptConnection }, -- the character model's changes
	NpcWatch: RBXScriptConnection?, -- the NPC's new children (a custom look swapped in)
}

type Ring = {
	Pad: Instance,
	Part: Part,
	Phase: number,
	Shown: boolean, -- pulsing (near the camera)
	Speed: number?, -- the PulseSpeed attribute last set
	Centre: Vector3?, -- the pad's footprint, measured on each scan (it can be moved)
	Bottom: number,
	Width: number,
}

type Sign = {
	Part: BasePart,
	Phase: number,
	Active: boolean,
	Words: { { Gui: SurfaceGui, Brightness: number } },
	Labels: { { Label: TextLabel, Transparency: number } },
	Frames: { { Box: SelectionBox, Transparency: number } },
	Lights: { { Light: PointLight, Brightness: number } },
}

type Cauldron = {
	Model: Model,
	Bubbles: { { Part: BasePart, Rest: CFrame } },
	Fx: Part,
	Emitter: ParticleEmitter,
	NextPuff: number,
	Active: boolean,
}

type Bat = {
	Body: Part,
	Wings: { Part },
	Start: Vector3,
	Dir: Vector3,
	Born: number,
	Seconds: number,
}

local LobbyLife = {}

local stopper: (() -> ())? = nil

-- The yaw (radians) that turns a keeper resting at `root` (facing its -Z) towards `target`,
-- limited to maxDegrees either way. Pure: also used by the tests.
function LobbyLife.TurnAngle(root: CFrame, target: Vector3, maxDegrees: number): number
	local p = root:PointToObjectSpace(target)
	if p.X * p.X + p.Z * p.Z < 1e-6 then
		return 0
	end
	local a = math.atan2(-p.X, -p.Z)
	local limit = math.rad(maxDegrees)
	return math.clamp(a, -limit, limit)
end

-- Puts everything back and stops (also done when you leave the game).
function LobbyLife.Stop()
	local stop = stopper
	stopper = nil
	if stop then
		stop()
	end
end

local function makePart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function bulkMove(parts: { BasePart }, cframes: { CFrame })
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes)
	end
end

function LobbyLife.Mount(_gui: ScreenGui?)
	local life = Config.Lobby.Life
	if not life.On then
		return
	end
	LobbyLife.Stop() -- (mounted twice: the old one tidies up first)
	local player = Players.LocalPlayer
	local rng = Random.new()
	local connections: { RBXScriptConnection } = {}
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "LobbyLifeFx"
	fxFolder.Parent = workspace
	local loop: FramePace.IdleLoop -- (the frame loop, started at the end)

	local phone = false
	local range = life.Range
	local nextScreenCheck = 0
	local last = os.clock()

	-- Keeper --------------------------------------------------------------------------------

	local keeperCfg = life.Keeper
	local keepers: { [Model]: Keeper } = {}
	local armNames: { [string]: boolean } = {}
	for _, name in keeperCfg.ArmNames do
		armNames[name] = true
	end

	local function restoreKeeper(k: Keeper)
		local parts: { BasePart } = {}
		local cframes: { CFrame } = {}
		for i, p in k.Parts do
			if p.Parent then
				table.insert(parts, p)
				table.insert(cframes, k.Rest[i])
			end
		end
		bulkMove(parts, cframes)
		k.Active = false
		k.Yaw = 0
		k.WaveStart = nil
		k.Near = false
	end

	local function unwatch(k: Keeper)
		for _, c in k.Watch do
			c:Disconnect()
		end
		k.Watch = {}
	end

	local function characterOf(npc: Model): Model?
		for _, name in keeperCfg.Models do
			local child = npc:FindFirstChild(name)
			if child and child:IsA("Model") then
				return child
			end
		end
		return nil
	end

	-- Reads the keeper's rest pose (it is at rest: never called while it is animated).
	local function snapshot(k: Keeper): boolean
		unwatch(k)
		k.Model = nil
		k.Parts, k.Rest, k.Rel = {}, {}, {}
		k.Arm = nil
		k.Dirty = false
		local model = characterOf(k.Npc)
		if not model or not model:IsDescendantOf(workspace) then
			return false
		end
		local parts: { BasePart } = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		if #parts == 0 then
			return false
		end
		local boxCf, boxSize = model:GetBoundingBox()
		local spot = k.Npc:FindFirstChild("KeeperSpot")
		local facing = if spot and spot:IsA("BasePart") then spot.CFrame else model:GetPivot()
		local root = CFrame.new(boxCf.X, boxCf.Y - boxSize.Y / 2, boxCf.Z)
			* CustomAssets.Yaw(facing)
		k.Model = model
		k.Root = root
		k.Parts = parts
		local bestX = -math.huge
		for i, p in parts do
			k.Rest[i] = p.CFrame
			local rel = root:ToObjectSpace(p.CFrame)
			k.Rel[i] = rel
			if armNames[p.Name] and math.abs(rel.X) > 1e-3 and rel.X > bestX then
				bestX = rel.X
				k.Arm = i
			end
		end
		local arm = k.Arm
		if arm then
			local rel = k.Rel[arm]
			local half = parts[arm].Size.Y / 2
			local a = (rel * CFrame.new(0, half, 0)).Position
			local b = (rel * CFrame.new(0, -half, 0)).Position
			k.Shoulder = CFrame.new(if a.Y >= b.Y then a else b)
			k.ArmSide = if rel.X >= 0 then 1 else -1
		end
		local function dirty()
			k.Dirty = true
		end
		k.Watch = {
			model.DescendantAdded:Connect(dirty),
			model.DescendantRemoving:Connect(dirty),
			model.AncestryChanged:Connect(dirty),
		}
		return true
	end

	local function addKeeper(instance: Instance)
		if not keeperCfg.On or not instance:IsA("Model") or keepers[instance] then
			return
		end
		local k: Keeper = {
			Npc = instance,
			Model = nil,
			Parts = {},
			Rest = {},
			Rel = {},
			Root = CFrame.identity,
			Arm = nil,
			ArmSide = 1,
			Shoulder = CFrame.identity,
			Yaw = 0,
			Active = false,
			Near = false,
			WaveStart = nil,
			Phase = rng:NextNumber(0, math.pi * 2),
			Dirty = true,
			Watch = {},
			NpcWatch = nil,
		}
		keepers[instance] = k
		-- A custom look swapped in (or the keeper streaming in) changes the NPC's children.
		k.NpcWatch = instance.ChildAdded:Connect(function()
			k.Dirty = true
		end)
	end

	local function removeKeeper(instance: Instance)
		local k = keepers[instance :: Model]
		if k then
			keepers[instance :: Model] = nil
			restoreKeeper(k)
			unwatch(k)
			local npcWatch = k.NpcWatch
			if npcWatch then
				npcWatch:Disconnect()
			end
		end
	end

	local function nearestRoot(at: Vector3, within: number): (Vector3?, number)
		local best: Vector3? = nil
		local bestDistance = within
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = (root.Position - at).Magnitude
				if d <= bestDistance then
					best, bestDistance = root.Position, d
				end
			end
		end
		return best, bestDistance
	end

	local function updateKeeper(k: Keeper, now: number, dt: number, eye: Vector3)
		if k.Dirty then
			if k.Model then
				restoreKeeper(k)
			end
			snapshot(k)
		end
		if not k.Model then
			return
		end
		local root = k.Root
		if (root.Position - eye).Magnitude > range then
			if k.Active then
				restoreKeeper(k)
			end
			return
		end
		for _, p in k.Parts do
			if not p.Parent then
				k.Dirty = true -- streamed out: picked up again next frame
				return
			end
		end
		k.Active = true

		-- Turn towards the nearest player; wave when one walks up.
		local target, distance =
			nearestRoot(root.Position, math.max(keeperCfg.TurnRange, keeperCfg.WaveDistance))
		local wantYaw = 0
		if target and distance <= keeperCfg.TurnRange then
			wantYaw = LobbyLife.TurnAngle(root, target, keeperCfg.MaxTurn)
		end
		k.Yaw += (wantYaw - k.Yaw) * math.min(1, dt * keeperCfg.TurnSpeed)
		local reach = keeperCfg.WaveDistance + (if k.Near then keeperCfg.WaveRearm else 0)
		local near = target ~= nil and distance <= reach
		if near and not k.Near then
			k.WaveStart = now
		end
		k.Near = near

		local y = math.sin(now * keeperCfg.BreathSpeed + k.Phase) * keeperCfg.BreathHeight
		local roll = 0
		local armAngle = 0
		local started = k.WaveStart
		if started then
			local p = (now - started) / math.max(keeperCfg.WaveSeconds, 0.01)
			if p >= 1 then
				k.WaveStart = nil
			else
				local envelope = math.min(1, p / 0.2, (1 - p) / 0.2)
				if k.Arm then
					local swing = math.sin(p * math.pi * 2 * keeperCfg.WaveSwings)
						* keeperCfg.WaveSwing
					armAngle = math.rad(keeperCfg.WaveRaise + swing) * envelope * k.ArmSide
				else
					local fade = 1 - p
					roll = math.rad(
						math.sin(p * math.pi * 2 * keeperCfg.WaveSwings)
							* keeperCfg.WiggleAngle
							* fade
					)
					y += math.abs(math.sin(p * math.pi * keeperCfg.WaveSwings)) * keeperCfg.WiggleHop * fade
				end
			end
		end
		local pose = root * CFrame.new(0, y, 0) * CFrame.Angles(0, k.Yaw, roll)
		local cframes: { CFrame } = table.create(#k.Parts)
		for i, rel in k.Rel do
			cframes[i] = pose * rel
		end
		local arm = k.Arm
		if arm and armAngle ~= 0 then
			cframes[arm] = pose
				* k.Shoulder
				* CFrame.Angles(0, 0, armAngle)
				* k.Shoulder:Inverse()
				* k.Rel[arm]
		end
		bulkMove(k.Parts, cframes)
	end

	-- Ready pad ring and sign bounce -------------------------------------------------------------

	local padCfg = life.ReadyPad
	local rings: { [Instance]: Ring } = {}
	local signRest: { [BillboardGui]: Vector3 } = {}
	local bounceStart: number? = nil

	local function addPad(instance: Instance)
		if not padCfg.On or rings[instance] then
			return
		end
		if not (instance:IsA("BasePart") or instance:IsA("Model")) then
			return
		end
		local ring = makePart("ReadyRing", fxFolder)
		ring.Shape = Enum.PartType.Cylinder
		ring.Color = padCfg.Color
		ring.Transparency = 1
		ring.Size = Vector3.new(0.1, 1, 1)
		rings[instance] = {
			Pad = instance,
			Part = ring,
			Phase = rng:NextNumber(0, math.pi * 2),
			Shown = false,
			Speed = nil,
			Centre = nil,
			Bottom = 0,
			Width = 0,
		}
	end

	local function removePad(instance: Instance)
		local r = rings[instance]
		if r then
			rings[instance] = nil
			r.Part:Destroy()
		end
	end

	-- The pad's footprint: centre, bottom (world Y) and width across.
	local function padShape(pad: Instance): (Vector3?, number, number)
		local cf: CFrame, size: Vector3
		local round = false
		if pad:IsA("BasePart") then
			cf, size = pad.CFrame, pad.Size
			round = pad:IsA("Part") and pad.Shape == Enum.PartType.Cylinder
		elseif pad:IsA("Model") then
			if not pad:FindFirstChildWhichIsA("BasePart", true) then
				return nil, 0, 0
			end
			cf, size = pad:GetBoundingBox()
		else
			return nil, 0, 0
		end
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local half = (math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z) / 2
		local width: number
		if round then
			width = math.min(size.Y, size.Z)
		else
			local ex = math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z
			local ez = math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
			width = math.min(ex, ez)
		end
		return cf.Position, cf.Position.Y - half, width
	end

	local function hideRing(r: Ring)
		if r.Shown then
			r.Shown = false
			r.Part.Transparency = 1
		end
	end

	-- `scanning`: also measure the pads again (a bounding box per pad: not every frame).
	local function updateRings(dt: number, eye: Vector3, scanning: boolean)
		local count = ReplicatedStorage:GetAttribute("ReadyCount")
		local speed = if typeof(count) == "number" and count > 0
			then padCfg.FastSpeed
			else padCfg.SlowSpeed
		for pad, r in rings do
			if scanning or (r.Shown and not r.Centre) then
				if pad:IsDescendantOf(workspace) then
					r.Centre, r.Bottom, r.Width = padShape(pad)
				else
					r.Centre = nil
				end
			end
			local centre = r.Centre
			if not centre or not pad.Parent or (centre - eye).Magnitude > range then
				hideRing(r)
				continue
			end
			r.Shown = true
			r.Phase += dt * speed
			local w = (math.sin(r.Phase) + 1) / 2
			local across = (r.Width + padCfg.RingWidth * 2) * (1 + padCfg.Grow * w)
			r.Part.Size = Vector3.new(0.1, across, across)
			r.Part.CFrame = CFrame.new(centre.X, r.Bottom + 0.08, centre.Z)
				* CFrame.Angles(0, 0, math.rad(90))
			r.Part.Transparency = padCfg.Faintest + (padCfg.Brightest - padCfg.Faintest) * w
			if r.Speed ~= speed then
				r.Speed = speed
				r.Part:SetAttribute("PulseSpeed", speed)
			end
		end
	end

	local function restoreSigns()
		for gui, rest in signRest do
			if gui.Parent then
				gui.StudsOffset = rest
			end
		end
		table.clear(signRest)
	end

	local function updateSignBounce(now: number, eye: Vector3)
		local started = bounceStart
		if not started then
			return
		end
		local p = (now - started) / math.max(padCfg.BounceSeconds, 0.01)
		if p >= 1 then
			bounceStart = nil
			restoreSigns()
			return
		end
		local hop = math.abs(math.sin(p * math.pi * padCfg.BounceHops))
			* padCfg.BounceHeight
			* (1 - p)
		for _, sign in CollectionService:GetTagged(Tags.ReadySign) do
			local gui = sign:FindFirstChildWhichIsA("BillboardGui")
			if not gui or not sign:IsA("BasePart") then
				continue
			end
			local rest = signRest[gui]
			if (sign.Position - eye).Magnitude > range then
				if rest then
					gui.StudsOffset = rest
					signRest[gui] = nil
				end
				continue
			end
			if not rest then
				rest = gui.StudsOffset
				signRest[gui] = rest
			end
			gui.StudsOffset = (rest :: Vector3) + Vector3.new(0, hop, 0)
		end
	end

	-- Floor signs --------------------------------------------------------------------------------

	local floorCfg = life.FloorSigns
	local signs: { [BasePart]: Sign } = {}
	local nextShimmer = 0

	local function addFloorSign(instance: Instance)
		if not floorCfg.On or not instance:IsA("BasePart") or signs[instance] then
			return
		end
		local at = instance.Position
		signs[instance] = {
			Part = instance,
			Phase = (at.X * 0.37 + at.Z * 0.21) % (math.pi * 2),
			Active = false,
			Words = {},
			Labels = {},
			Frames = {},
			Lights = {},
		}
	end

	local function restoreFloorSign(s: Sign)
		for _, w in s.Words do
			if w.Gui.Parent then
				w.Gui.Brightness = w.Brightness
			end
		end
		for _, l in s.Labels do
			if l.Label.Parent then
				l.Label.TextTransparency = l.Transparency
			end
		end
		for _, f in s.Frames do
			if f.Box.Parent then
				f.Box.Transparency = f.Transparency
			end
		end
		for _, l in s.Lights do
			if l.Light.Parent then
				l.Light.Brightness = l.Brightness
			end
		end
		s.Words, s.Labels, s.Frames, s.Lights = {}, {}, {}, {}
		s.Active = false
	end

	-- What shimmers, read when the sign starts (its children may stream in after the part).
	local function captureFloorSign(s: Sign)
		for _, d in s.Part:GetDescendants() do
			if d:IsA("SurfaceGui") then
				table.insert(s.Words, { Gui = d, Brightness = d.Brightness })
			elseif d:IsA("TextLabel") then
				table.insert(s.Labels, { Label = d, Transparency = d.TextTransparency })
			elseif d:IsA("SelectionBox") then
				table.insert(s.Frames, { Box = d, Transparency = d.Transparency })
			elseif d:IsA("PointLight") then
				table.insert(s.Lights, { Light = d, Brightness = d.Brightness })
			end
		end
		s.Active = true
	end

	local function updateFloorSigns(now: number, eye: Vector3)
		if now < nextShimmer then
			return
		end
		nextShimmer = now + 1 / math.max(floorCfg.UpdatesPerSecond, 1)
		for part, s in signs do
			if not part:IsDescendantOf(workspace) then
				if s.Active then
					restoreFloorSign(s)
				end
				continue
			end
			if (part.Position - eye).Magnitude > range then
				if s.Active then
					restoreFloorSign(s)
				end
				continue
			end
			if not s.Active then
				captureFloorSign(s)
			end
			local w = (math.sin(now * floorCfg.Speed + s.Phase) + 1) / 2
			for _, l in s.Labels do
				if l.Label.Parent then
					l.Label.TextTransparency = math.min(1, l.Transparency + floorCfg.TextFade * w)
				end
			end
			for _, f in s.Frames do
				if f.Box.Parent then
					f.Box.Transparency = math.min(1, f.Transparency + floorCfg.FrameFade * w)
				end
			end
			for _, g in s.Words do
				if g.Gui.Parent then
					g.Gui.Brightness = g.Brightness * (1 - floorCfg.TextFade * 0.5 * w)
				end
			end
			for _, l in s.Lights do
				if l.Light.Parent then
					l.Light.Brightness = l.Brightness * (1 - floorCfg.LightDip * w)
				end
			end
		end
	end

	-- Cauldron -----------------------------------------------------------------------------------

	local cauldronCfg = life.Cauldron
	local cauldron: Cauldron? = nil
	local nextScan = 0

	local function findCauldron(): Model?
		for _, spawnPart in CollectionService:GetTagged(Tags.HubSpawn) do
			local hub: Instance = spawnPart
			while hub.Parent and hub.Parent ~= workspace do
				hub = hub.Parent
			end
			if hub.Parent ~= workspace then
				continue
			end
			for _, d in hub:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("PropName") == "Cauldron" then
					return d
				end
			end
		end
		return nil
	end

	local function restoreCauldron(c: Cauldron)
		for _, b in c.Bubbles do
			if b.Part.Parent then
				b.Part.CFrame = b.Rest
			end
		end
		c.Active = false
	end

	local function dropCauldron()
		local c = cauldron
		if c then
			restoreCauldron(c)
			c.Fx:Destroy()
			cauldron = nil
		end
	end

	local function setUpCauldron(model: Model, now: number)
		local brew = model:FindFirstChild("Brew", true)
		local top: Vector3
		if brew and brew:IsA("BasePart") then
			top = brew.Position + Vector3.new(0, 0.4, 0)
		else
			local boxCf, boxSize = model:GetBoundingBox()
			top = boxCf.Position + Vector3.new(0, boxSize.Y / 2, 0)
		end
		local fx = makePart("CauldronPuff", fxFolder)
		fx.Transparency = 1
		fx.Size = Vector3.one * 0.2
		fx.CFrame = CFrame.new(top)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Bubbles"
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(cauldronCfg.Color)
		emitter.LightEmission = 0.7
		emitter.Size = NumberSequence.new(0.5, 0.1)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(0.9, 1.6)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, 1.5, 0)
		emitter.Parent = fx
		local bubbles = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Bubble" then
				table.insert(bubbles, { Part = d, Rest = d.CFrame })
			end
		end
		cauldron = {
			Model = model,
			Bubbles = bubbles,
			Fx = fx,
			Emitter = emitter,
			NextPuff = now + rng:NextNumber(0, cauldronCfg.EveryMax),
			Active = false,
		}
	end

	local function updateCauldron(now: number, eye: Vector3)
		local c = cauldron
		if c and not c.Model:IsDescendantOf(workspace) then
			dropCauldron()
			c = nil
		end
		if not c then
			if now >= nextScan then
				nextScan = now + cauldronCfg.ScanSeconds
				local found = findCauldron()
				if found then
					setUpCauldron(found, now)
				end
			end
			return
		end
		if (c.Fx.Position - eye).Magnitude > range then
			if c.Active then
				restoreCauldron(c)
			end
			return
		end
		c.Active = true
		for i, b in c.Bubbles do
			if b.Part.Parent then
				local w = (math.sin(now * cauldronCfg.BubbleSpeed + i * 2.1) + 1) / 2
				b.Part.CFrame = b.Rest + Vector3.new(0, w * cauldronCfg.BubbleBob, 0)
			end
		end
		if now >= c.NextPuff then
			c.NextPuff = now + rng:NextNumber(cauldronCfg.EveryMin, cauldronCfg.EveryMax)
			c.Emitter:Emit(if phone then cauldronCfg.PhonePuffs else cauldronCfg.Puffs)
		end
	end

	-- Bats ---------------------------------------------------------------------------------------

	local batCfg = life.Bats
	local bats: { Bat } = {}
	local nextBat = os.clock() + rng:NextNumber(batCfg.EveryMin, batCfg.EveryMax)

	local function inLobby(eye: Vector3): boolean
		for _, spawnPart in CollectionService:GetTagged(Tags.HubSpawn) do
			if
				spawnPart:IsA("BasePart")
				and (spawnPart.Position - eye).Magnitude <= batCfg.HubRadius
			then
				return true
			end
		end
		return false
	end

	local function spawnBat(now: number, camera: Camera)
		local s = batCfg.Size
		local body = makePart("Bat", fxFolder)
		body.Shape = Enum.PartType.Ball
		body.Material = Enum.Material.SmoothPlastic
		body.Color = batCfg.Color
		body.Size = Vector3.one * s
		local wings: { Part } = {}
		for _ = 1, 2 do
			local wing = makePart("BatWing", fxFolder)
			wing.Material = Enum.Material.SmoothPlastic
			wing.Color = batCfg.Color
			wing.Size = Vector3.new(s * 1.4, 0.1, s * 0.8)
			table.insert(wings, wing)
		end
		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
		local angle = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local centre = camera.CFrame.Position
			+ forward * batCfg.Distance
			+ Vector3.new(0, batCfg.Height, 0)
		table.insert(bats, {
			Body = body,
			Wings = wings,
			Start = centre - dir * batCfg.Span / 2,
			Dir = dir,
			Born = now,
			Seconds = batCfg.Span / math.max(batCfg.Speed, 0.1),
		})
	end

	local function destroyBat(b: Bat)
		b.Body:Destroy()
		for _, w in b.Wings do
			w:Destroy()
		end
	end

	local function updateBats(now: number, camera: Camera)
		for i = #bats, 1, -1 do
			local b = bats[i]
			local age = now - b.Born
			if age >= b.Seconds then
				destroyBat(b)
				table.remove(bats, i)
				continue
			end
			local pos = b.Start
				+ b.Dir * (age * batCfg.Speed)
				+ Vector3.new(0, math.sin(age * 3) * 0.8, 0)
			local base = CFrame.lookAt(pos, pos + b.Dir)
			local flap = math.rad(math.sin(age * batCfg.FlapSpeed) * batCfg.FlapAngle)
			local half = batCfg.Size * 0.35
			local reach = batCfg.Size * 0.7
			b.Body.CFrame = base
			b.Wings[1].CFrame = base
				* CFrame.new(-half, 0, 0)
				* CFrame.Angles(0, 0, -flap)
				* CFrame.new(-reach, 0, 0)
			b.Wings[2].CFrame = base
				* CFrame.new(half, 0, 0)
				* CFrame.Angles(0, 0, flap)
				* CFrame.new(reach, 0, 0)
		end
		if now < nextBat then
			return
		end
		nextBat = now + rng:NextNumber(batCfg.EveryMin, batCfg.EveryMax)
		local max = if phone then batCfg.PhoneMax else batCfg.Max
		if #bats < max and inLobby(camera.CFrame.Position) then
			spawnBat(now, camera)
		end
	end

	-- Wiring -------------------------------------------------------------------------------------

	local function watchTag(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(add))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(remove))
	end

	if keeperCfg.On then
		watchTag(Tags.ShopKeeper, addKeeper, removeKeeper)
	end
	if padCfg.On then
		watchTag(Tags.ReadyPad, addPad, removePad)
		table.insert(
			connections,
			ReplicatedStorage:GetAttributeChangedSignal("ReadyCount"):Connect(function()
				bounceStart = os.clock()
				loop.Wake()
			end)
		)
	end
	if floorCfg.On then
		watchTag(Tags.FloorSign, addFloorSign, function(instance: Instance)
			local s = signs[instance :: BasePart]
			if s then
				signs[instance :: BasePart] = nil
				restoreFloorSign(s)
			end
		end)
	end

	-- Is anything animating (or put out of place) right now? While nothing is, the frame loop
	-- stops and only looks around now and then from a timer (FramePace.IdleLoop).
	local function busy(): boolean
		if bounceStart or #bats > 0 or (cauldron and cauldron.Active) then
			return true
		end
		for _, k in keepers do
			if k.Active or k.Dirty then
				return true
			end
		end
		for _, r in rings do
			if r.Shown then
				return true
			end
		end
		for _, s in signs do
			if s.Active then
				return true
			end
		end
		return false
	end
	local nextIdleScan = 0

	loop = FramePace.IdleLoop(RunService.RenderStepped, function(scanNow: boolean): boolean
		local now = os.clock()
		local dt = math.clamp(now - last, 0, 0.25)
		last = now
		local scanning = scanNow or now >= nextIdleScan
		if scanning then
			nextIdleScan = now + FramePace.ScanSeconds()
		end
		if now >= nextScreenCheck then
			nextScreenCheck = now + 1
			phone = Layout.IsPhone()
			range = if phone then life.PhoneRange else life.Range
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return false
		end
		local eye = camera.CFrame.Position
		for _, k in keepers do
			updateKeeper(k, now, dt, eye)
		end
		if padCfg.On then
			updateRings(dt, eye, scanning)
			updateSignBounce(now, eye)
		end
		if floorCfg.On then
			updateFloorSigns(now, eye)
		end
		if cauldronCfg.On then
			updateCauldron(now, eye)
		end
		if batCfg.On then
			updateBats(now, camera)
		end
		return busy()
	end)

	stopper = function()
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		loop.Stop()
		for npc in keepers do
			removeKeeper(npc)
		end
		restoreSigns()
		for _, s in signs do
			restoreFloorSign(s)
		end
		table.clear(signs)
		dropCauldron()
		for _, b in bats do
			destroyBat(b)
		end
		table.clear(bats)
		table.clear(rings)
		fxFolder:Destroy()
	end

	-- Leaving the game: put everything back and tidy up.
	table.insert(
		connections,
		player.AncestryChanged:Connect(function(_, parent)
			if not parent then
				LobbyLife.Stop()
			end
		end)
	)
end

return LobbyLife
