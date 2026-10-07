--!strict
--[[
	The round maps come alive (this client only: the server never moves anything here).
	Settings: Config.MapLife (src/shared/Config/MapLife.luau). Off: Config.Features.MapLife =
	false, or each part with its own On.

	Only things within MapLife.Range of the camera (PhoneRange on phones) move. With no round
	map, pumpkins or wobble going on (the lobby) nothing here runs per frame at all.
	  Pickups   King Hunt pumpkins (tag PumpkinPickup, set by PumpkinService) bob, spin and
	            their glow light breathes. When one is collected near you (it disappears while
	            its round is still on, with a player right next to it) a sparkle burst and a
	            quick "pop" ball show where it was.
	  Ambient   a few fireflies / embers (fewer on phones) drift round your camera while it is on
	            the round map (Workspace.Map), in the map's colour (Ambient.MapColors).
	  Wobble    Hide & Seek: now and then one pumpkin near you does a tiny wobble. It is picked
	            from the decoys (tag HidingDecoy) AND the hiders' pumpkins (tag HiderPumpkin)
	            alike and wobbles the same way, so it never gives a hider away.
	Lantern and torch flicker on the maps is HubAmbience's job (tag HubFlicker), not this.

	How the real parts stay safe: nothing the server made is ever moved. While a pumpkin is
	animated, a look-only copy of it (in Workspace.MapLifeFx: anchored, never solid, never hit by
	raycasts or touches, no scripts, tags or lights) does the moving, and the real parts are
	hidden on this screen only (LocalTransparencyModifier, put back exactly afterwards). So the
	pumpkin you touch is exactly where the server put it, and candy and the King's eyes see the
	same pumpkins as before. Streamed-out parts are skipped and picked up again later.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local FramePace = require(script.Parent.FramePace)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)

-- A look-only copy of something, and what was hidden to show it instead.
type Proxy = {
	Root: Instance,
	Parts: { BasePart },
	Rel: { CFrame }, -- each copied part relative to the base it was made at
	Hidden: { { Part: BasePart, Was: number } },
	Guis: { { Gui: LayerCollector, Was: boolean } },
}

type Pickup = {
	Part: BasePart,
	Holder: Instance?, -- the folder it was in (still in the world = the round is still on)
	Phase: number,
	At: Vector3, -- where it was last seen
	Proxy: Proxy?,
	Light: PointLight?,
	LightBase: number,
	Watch: RBXScriptConnection?,
}

type Wobble = { Target: Instance, Proxy: Proxy, BottomRel: CFrame, Start: number }

type Firefly = { Part: Part, Phase: number, Seed: number }

local MapLife = {}

local stopper: (() -> ())? = nil
local wobbleNow: ((Instance) -> boolean)? = nil
local wobbling: { Wobble } = {}

-- Puts everything back and stops (also done when you leave the game).
function MapLife.Stop()
	local stop = stopper
	stopper = nil
	wobbleNow = nil
	if stop then
		stop()
	end
end

-- The tilt of a wobble `p` (0..1) of the way through, round the pumpkin's bottom middle.
-- Pure: the same for decoys and hiders, and used by the tests.
function MapLife.WobblePose(bottom: CFrame, p: number): CFrame
	local cfg = Config.MapLife.Wobble
	local envelope = math.sin(math.clamp(p, 0, 1) * math.pi)
	local a = math.rad(cfg.Angle) * envelope * math.sin(p * math.pi * 2 * cfg.Wiggles)
	return bottom * CFrame.Angles(a * 0.5, 0, a)
end

-- Starts a wobble on this decoy or hider pumpkin now (false if it can't: too far, already
-- wobbling, glowing, or MapLife isn't running).
function MapLife.Wobble(target: Instance): boolean
	local start = wobbleNow
	return if start then start(target) else false
end

-- The pumpkins wobbling right now.
function MapLife.Wobbling(): { Instance }
	local out = {}
	for _, w in wobbling do
		table.insert(out, w.Target)
	end
	return out
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

-- What a look-only copy keeps (everything else: scripts, lights, welds, sounds... goes).
local function keepInCopy(d: Instance): boolean
	return d:IsA("BasePart")
		or d:IsA("DataModelMesh")
		or d:IsA("Decal") -- (and Texture)
		or d:IsA("SurfaceAppearance")
		or d:IsA("SurfaceGui")
		or d:IsA("GuiObject")
		or d:IsA("UIComponent")
		or d:IsA("Model")
		or d:IsA("Folder")
end

local function untag(d: Instance)
	for _, tag in CollectionService:GetTags(d) do
		CollectionService:RemoveTag(d, tag)
	end
end

local function makeSafe(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.LocalTransparencyModifier = 0
end

-- A look-only copy of `source` (a Model or a part), in `parent`, its parts measured from
-- `base`; the real parts are hidden on this screen. nil if it can't be copied.
local function makeProxy(source: Instance, parent: Instance, base: CFrame): Proxy?
	local ok, copy = pcall(function(): Instance?
		return source:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local root: Instance = copy
	untag(root)
	root:SetAttribute("MapLifeCopy", true)
	local parts: { BasePart } = {}
	if root:IsA("BasePart") then
		makeSafe(root)
		table.insert(parts, root)
	end
	for _, d in root:GetDescendants() do
		if not d.Parent then
			continue
		end
		if not keepInCopy(d) then
			d:Destroy()
			continue
		end
		untag(d)
		if d:IsA("BasePart") then
			makeSafe(d)
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		root:Destroy()
		return nil
	end
	local rel: { CFrame } = table.create(#parts)
	for i, p in parts do
		rel[i] = base:ToObjectSpace(p.CFrame)
	end
	local hidden = {}
	local guis = {}
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			table.insert(hidden, { Part = d, Was = d.LocalTransparencyModifier })
			d.LocalTransparencyModifier = 1
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			table.insert(guis, { Gui = d, Was = d.Enabled })
			d.Enabled = false
		end
	end
	hide(source)
	for _, d in source:GetDescendants() do
		hide(d)
	end
	root.Parent = parent
	return { Root = root, Parts = parts, Rel = rel, Hidden = hidden, Guis = guis }
end

local function moveProxy(proxy: Proxy, pose: CFrame)
	local cframes: { CFrame } = table.create(#proxy.Parts)
	for i, rel in proxy.Rel do
		cframes[i] = pose * rel
	end
	workspace:BulkMoveTo(proxy.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Destroys the copy and shows the real parts again, exactly as they were.
local function dropProxy(proxy: Proxy)
	for _, h in proxy.Hidden do
		if h.Part.Parent then
			h.Part.LocalTransparencyModifier = h.Was
		end
	end
	for _, g in proxy.Guis do
		if g.Gui.Parent then
			g.Gui.Enabled = g.Was
		end
	end
	proxy.Root:Destroy()
end

-- A pumpkin's bottom middle, level, facing the way it faces (works for Models and parts).
local function bottomOf(target: Instance): CFrame?
	local cf: CFrame, size: Vector3
	if target:IsA("Model") then
		if not target:FindFirstChildWhichIsA("BasePart", true) then
			return nil
		end
		cf, size = target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		cf, size = target.CFrame, target.Size
	else
		return nil
	end
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	return CFrame.lookAt(bottom, bottom + flat)
end

local function pivotOf(target: Instance): CFrame?
	if target:IsA("PVInstance") then
		return target:GetPivot()
	end
	return nil
end

function MapLife.Mount(_gui: ScreenGui?)
	local cfg = Config.MapLife
	if not Config.Features.MapLife then
		return
	end
	MapLife.Stop() -- (mounted twice: the old one tidies up first)
	local player = Players.LocalPlayer
	local rng = Random.new()
	local connections: { RBXScriptConnection } = {}
	local alive = true
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "MapLifeFx"
	fxFolder.Parent = workspace

	local phone = false
	local range = cfg.Range
	local nextScreenCheck = 0
	local last = os.clock()

	local function watchTag(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(add))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(remove))
	end

	-- Starts the frame loop if it stopped (set below, once the loop is defined).
	local ensureLoop: () -> () = function() end

	-- Pickups -----------------------------------------------------------------------------------

	local pickCfg = cfg.Pickups
	local pickups: { [BasePart]: Pickup } = {}

	local function stopPickup(p: Pickup)
		local proxy = p.Proxy
		if proxy then
			p.Proxy = nil
			dropProxy(proxy)
		end
		local light = p.Light
		if light then
			if light.Parent then
				light.Brightness = p.LightBase
			end
			p.Light = nil
		end
	end

	-- Is a player standing right by `at` (the one who just picked it up)?
	local function someoneBy(at: Vector3): boolean
		local reach = Config.Pumpkins.PickupRange + 4
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - at).Magnitude <= reach then
				return true
			end
		end
		return false
	end

	local function celebrate(at: Vector3)
		local camera = workspace.CurrentCamera
		if not alive or not camera or (camera.CFrame.Position - at).Magnitude > range then
			return
		end
		local count = if phone then pickCfg.PhoneBurstCount else pickCfg.BurstCount
		MinigameFx.Burst(at, pickCfg.BurstColors, count)
		local pop = makePart("PickupPop", fxFolder)
		pop.Shape = Enum.PartType.Ball
		pop.Color = pickCfg.PopColor
		pop.Size = Vector3.one * Config.Pumpkins.Size
		pop.Transparency = 0.25
		pop.CFrame = CFrame.new(at)
		TweenService:Create(
			pop,
			TweenInfo.new(pickCfg.PopSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * Config.Pumpkins.Size * pickCfg.PopGrow, Transparency = 1 }
		):Play()
		task.delay(pickCfg.PopSeconds + 0.05, function()
			pop:Destroy()
		end)
	end

	local function removePickup(instance: Instance)
		local p = pickups[instance :: BasePart]
		if not p then
			return
		end
		pickups[instance :: BasePart] = nil
		local watch = p.Watch
		if watch then
			watch:Disconnect()
		end
		stopPickup(p)
		-- Collected (gone while its round's folder is still in the world, with a player right
		-- next to it), not the round ending or the pumpkin streaming out far from everyone.
		local holder = p.Holder
		local at = p.At
		task.defer(function()
			if
				alive
				and holder
				and holder:IsDescendantOf(workspace)
				and not instance:IsDescendantOf(workspace)
				and someoneBy(at)
			then
				celebrate(at)
			end
		end)
	end

	local function addPickup(instance: Instance)
		if not pickCfg.On or not instance:IsA("BasePart") or pickups[instance] then
			return
		end
		local at = instance.Position
		local p: Pickup = {
			Part = instance,
			Holder = instance.Parent,
			Phase = (at.X * 0.41 + at.Z * 0.27) % (math.pi * 2),
			At = at,
			Proxy = nil,
			Light = nil,
			LightBase = 0,
			Watch = nil,
		}
		pickups[instance] = p
		ensureLoop()
		p.Watch = instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(workspace) then
				removePickup(instance)
			end
		end)
	end

	local function startPickup(p: Pickup)
		local part = p.Part
		local base = part.CFrame
		local proxy = makeProxy(part, fxFolder, base)
		if not proxy then
			return
		end
		-- The plain ball is its own look: a little stem shows it turning.
		if pickCfg.Stem and part.Transparency < 1 then
			local stem = makePart("Stem", proxy.Root)
			stem.Material = Enum.Material.SmoothPlastic
			stem.Color = pickCfg.StemColor
			local s = part.Size.Y
			stem.Size = Vector3.new(s * 0.12, s * 0.28, s * 0.12)
			stem.CFrame = base * CFrame.new(0, s * 0.5, 0) * CFrame.Angles(0, 0, math.rad(14))
			table.insert(proxy.Parts, stem)
			table.insert(proxy.Rel, base:ToObjectSpace(stem.CFrame))
		end
		p.Proxy = proxy
		local light = part:FindFirstChildWhichIsA("PointLight", true)
		if light then
			p.Light = light
			p.LightBase = light.Brightness
		end
	end

	-- `scanning`: also look at the pumpkins that aren't animating (not every frame).
	local function updatePickups(now: number, eye: Vector3, scanning: boolean)
		for part, p in pickups do
			if not scanning and not p.Proxy then
				continue
			end
			if not part:IsDescendantOf(workspace) then
				continue
			end
			p.At = part.Position
			if (part.Position - eye).Magnitude > range then
				if p.Proxy then
					stopPickup(p)
				end
				continue
			end
			if not p.Proxy then
				startPickup(p)
			end
			local proxy = p.Proxy
			if not proxy then
				continue
			end
			local bob = math.sin(now * pickCfg.BobSpeed + p.Phase) * pickCfg.BobHeight
			local spin = math.rad(now * pickCfg.SpinSpeed) + p.Phase
			moveProxy(proxy, part.CFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0))
			local light = p.Light
			if light and light.Parent then
				local w = math.sin(now * pickCfg.GlowSpeed + p.Phase)
				light.Brightness = p.LightBase * (1 + pickCfg.GlowPulse * w)
			end
		end
	end

	-- Ambient fireflies --------------------------------------------------------------------------

	local ambCfg = cfg.Ambient
	local flies: { Firefly } = {}
	local mapModel: Model? = nil
	local mapBox = CFrame.identity
	local mapSize = Vector3.zero
	local nextMapCheck = 0

	local function clearFlies()
		for _, f in flies do
			f.Part:Destroy()
		end
		table.clear(flies)
	end

	-- The round map, if the camera is on it.
	local function mapHere(now: number, eye: Vector3): Model?
		local found = workspace:FindFirstChild("Map")
		local map: Model? = if found and found:IsA("Model") then found else nil
		if map ~= mapModel or now >= nextMapCheck then
			nextMapCheck = now + 3 -- (parts stream in: measure it again now and then)
			mapModel = map
			if map and map:FindFirstChildWhichIsA("BasePart", true) then
				mapBox, mapSize = map:GetBoundingBox()
			else
				mapSize = Vector3.zero
			end
		end
		if not map or mapSize.Magnitude < 1 then
			return nil
		end
		local p = mapBox:PointToObjectSpace(eye)
		local margin = 10
		if
			math.abs(p.X) > mapSize.X / 2 + margin
			or math.abs(p.Z) > mapSize.Z / 2 + margin
			or math.abs(p.Y) > mapSize.Y / 2 + 40
		then
			return nil
		end
		return map
	end

	local function placeFly(f: Firefly, centre: Vector3)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = ambCfg.Radius * math.sqrt(rng:NextNumber(0.05, 1))
		local y = rng:NextNumber(ambCfg.Height.Min, ambCfg.Height.Max)
		f.Part.Position = centre + Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	end

	local function updateFlies(now: number, dt: number, camera: Camera)
		local eye = camera.CFrame.Position
		local map = mapHere(now, eye)
		if not map then
			if #flies > 0 then
				clearFlies()
			end
			return
		end
		local id = map:GetAttribute("MapId")
		local colors = ambCfg.MapColors :: { [string]: Color3 }
		local color = if typeof(id) == "string" and colors[id] then colors[id] else ambCfg.Color
		-- Around the player (or the camera when there is no character), from about their feet up.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local centre = if root
				and root:IsA("BasePart")
				and (root.Position - eye).Magnitude < 60
			then root.Position - Vector3.new(0, 3, 0)
			else eye - Vector3.new(0, 5, 0)
		local want = if phone then ambCfg.PhoneCount else ambCfg.Count
		while #flies > want do
			local f = table.remove(flies) :: Firefly
			f.Part:Destroy()
		end
		while #flies < want do
			local part = makePart("Firefly", fxFolder)
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * ambCfg.Size
			local f: Firefly = {
				Part = part,
				Phase = rng:NextNumber(0, math.pi * 2),
				Seed = rng:NextNumber(0, 100),
			}
			placeFly(f, centre)
			table.insert(flies, f)
		end
		for _, f in flies do
			local part = f.Part
			if part.Color ~= color then
				part.Color = color
			end
			local pos = part.Position
			local offset = pos - centre
			if Vector3.new(offset.X, 0, offset.Z).Magnitude > ambCfg.Radius then
				placeFly(f, centre)
				pos = part.Position
			end
			local t = now * 0.35
			local dir = Vector3.new(
				math.noise(t, f.Seed, 0.5),
				math.noise(f.Seed, t, 1.5) * 0.4,
				math.noise(0.5, f.Seed, t)
			)
			-- Drift, and stay within the height band above the player.
			local height = pos.Y - centre.Y
			local lift = if height < ambCfg.Height.Min
				then 0.5
				elseif height > ambCfg.Height.Max then -0.5
				else 0
			part.Position = pos + (dir * 2 + Vector3.new(0, lift, 0)) * ambCfg.Drift * dt
			local glow = (math.sin(now * ambCfg.BlinkSpeed + f.Phase) + 1) / 2
			part.Transparency = 0.15 + 0.75 * (1 - glow)
		end
	end

	-- Hide & Seek wobble -----------------------------------------------------------------------

	local wobCfg = cfg.Wobble
	local candidates: { [Instance]: boolean } = {}
	local nextWobble = os.clock() + rng:NextNumber(wobCfg.EveryMin, wobCfg.EveryMax)

	local function endWobble(i: number)
		local w = table.remove(wobbling, i) :: Wobble
		dropProxy(w.Proxy)
	end

	local function glowing(target: Instance): boolean
		for _, d in target:GetDescendants() do
			if d:IsA("Highlight") and d.Enabled then
				return true
			end
		end
		return false
	end

	local function canWobble(target: Instance, eye: Vector3): boolean
		if not target:IsDescendantOf(workspace) then
			return false
		end
		for _, w in wobbling do
			if w.Target == target then
				return false
			end
		end
		local pivot = pivotOf(target)
		if not pivot or (pivot.Position - eye).Magnitude > range then
			return false
		end
		-- (a glowing pumpkin is already showing itself: its glow mustn't blink off)
		return not glowing(target)
	end

	local function startWobble(target: Instance, now: number): boolean
		local camera = workspace.CurrentCamera
		if not camera or not canWobble(target, camera.CFrame.Position) then
			return false
		end
		local bottom = bottomOf(target)
		local pivot = pivotOf(target)
		if not bottom or not pivot then
			return false
		end
		local proxy = makeProxy(target, fxFolder, bottom)
		if not proxy then
			return false
		end
		table.insert(wobbling, {
			Target = target,
			Proxy = proxy,
			BottomRel = pivot:ToObjectSpace(bottom),
			Start = now,
		})
		ensureLoop()
		return true
	end

	local function updateWobbles(now: number, eye: Vector3)
		for i = #wobbling, 1, -1 do
			local w = wobbling[i]
			local pivot = pivotOf(w.Target)
			local p = (now - w.Start) / math.max(wobCfg.Seconds, 0.05)
			if p >= 1 or not pivot or not w.Target:IsDescendantOf(workspace) then
				endWobble(i)
				continue
			end
			-- (follows a hider who walks off mid-wobble)
			moveProxy(w.Proxy, MapLife.WobblePose(pivot * w.BottomRel, p))
		end
		if now < nextWobble then
			return
		end
		nextWobble = now + rng:NextNumber(wobCfg.EveryMin, wobCfg.EveryMax)
		if #wobbling >= wobCfg.MaxAtOnce then
			return
		end
		-- Every pumpkin near you has the same chance, decoy or hider.
		local near = {}
		for target in candidates do
			if canWobble(target, eye) then
				table.insert(near, target)
			end
		end
		if #near > 0 then
			startWobble(near[rng:NextInteger(1, #near)], now)
		end
	end

	local function addCandidate(instance: Instance)
		if instance:IsA("Model") or instance:IsA("BasePart") then
			candidates[instance] = true
			ensureLoop()
		end
	end
	local function removeCandidate(instance: Instance)
		candidates[instance] = nil
		for i = #wobbling, 1, -1 do
			if wobbling[i].Target == instance then
				endWobble(i)
			end
		end
	end

	-- Wiring -------------------------------------------------------------------------------------

	if pickCfg.On then
		watchTag(Tags.PumpkinPickup, addPickup, removePickup)
	end
	if wobCfg.On then
		watchTag(Tags.HidingDecoy, addCandidate, removeCandidate)
		watchTag(Tags.HiderPumpkin, addCandidate, removeCandidate)
		wobbleNow = function(target: Instance): boolean
			return startWobble(target, os.clock())
		end
	end

	-- The frame loop only runs while there is a round map, pumpkins or something animating:
	-- in the lobby it disconnects itself (and comes back when a map or a pumpkin arrives).
	-- Things not animating yet are only looked at now and then (FramePace.ScanSeconds).
	local loop: RBXScriptConnection? = nil
	local nextIdleScan = 0

	local function hasWork(): boolean
		return next(pickups) ~= nil
			or next(candidates) ~= nil
			or #wobbling > 0
			or #flies > 0
			or workspace:FindFirstChild("Map") ~= nil
	end

	local function frame()
		local now = os.clock()
		local dt = math.clamp(now - last, 0, 0.25)
		last = now
		local scanning = now >= nextIdleScan
		if scanning then
			nextIdleScan = now + FramePace.ScanSeconds()
		end
		if now >= nextScreenCheck then
			nextScreenCheck = now + 1
			phone = Layout.IsPhone()
			range = if phone then cfg.PhoneRange else cfg.Range
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		if pickCfg.On then
			updatePickups(now, eye, scanning)
		end
		if ambCfg.On and (scanning or #flies > 0) then
			updateFlies(now, dt, camera)
		end
		if wobCfg.On and (scanning or #wobbling > 0) then
			updateWobbles(now, eye)
		end
		local current = loop
		if scanning and current and not hasWork() then
			current:Disconnect()
			loop = nil
		end
	end

	ensureLoop = function()
		if alive and not loop then
			last = os.clock()
			nextIdleScan = 0
			loop = RunService.RenderStepped:Connect(frame)
		end
	end
	ensureLoop()
	table.insert(
		connections,
		workspace.ChildAdded:Connect(function(child)
			if child.Name == "Map" then
				ensureLoop()
			end
		end)
	)

	stopper = function()
		alive = false
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		local current = loop
		if current then
			current:Disconnect()
			loop = nil
		end
		for part in pickups do
			local p = pickups[part]
			pickups[part] = nil
			local watch = p.Watch
			if watch then
				watch:Disconnect()
			end
			stopPickup(p)
		end
		for i = #wobbling, 1, -1 do
			endWobble(i)
		end
		table.clear(candidates)
		clearFlies()
		fxFolder:Destroy()
	end

	-- Leaving the game: put everything back and tidy up.
	table.insert(
		connections,
		player.AncestryChanged:Connect(function(_, parent)
			if not parent then
				MapLife.Stop()
			end
		end)
	)
end

return MapLife
