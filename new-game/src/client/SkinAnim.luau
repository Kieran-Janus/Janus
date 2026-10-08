--!strict
--[[
	Animated skins on this screen (a skin's Style.Animate; what each effect does:
	src/shared/SkinAnimate.luau). The server only builds the skin once (src/shared/Cosmetics.luau
	tags its model Tags.SkinAnim); every player's own screen moves and colours the pieces, so
	nothing is sent over the network per frame. Everyone sees the same wing beat at the same
	moment because the time is Workspace:GetServerTimeNow().

	  Moving pieces   hang on an invisible AnimPivot part; this turns its Motor6D (SkinMotor)
	                  every frame, so the pieces also follow dances and walking.
	  Colours, glow   change 30 times a second (Config.SkinAnimate.ColorHz), sharing one
	                  budget of writes per frame across every character and preview.
	  Sparkle bursts  ParticleEmitter:Emit on the skin's own aura, only while it's switched on.
	Only the closest Config.SkinAnimate.MaxCharacters characters animate (fewer on phones), your
	own first. Characters off screen (except yours) get nothing. Hide & Seek hiders never
	animate. Nothing ever changes Transparency or Enabled, so a disguise can't be undone, and
	what CRAZY skins animate (src/client/SkinFx.luau) is never touched here. When an effect
	stops, a colour goes back only if nothing else changed it meanwhile. Nothing runs per frame
	while no animated skin or preview is about. On/off: Config.Features.SkinAnimations.

	SkinAnim.Mount(gui)                    starts watching (does nothing when switched off)
	SkinAnim.AnimatePreview(model) -> stop moves and colours a shop / crate / Skin Studio
	                                       preview while it is on screen (SkinFx.AnimatePreview
	                                       calls it for every skin preview)
	SkinAnim.PreviewVisible(viewport) -> boolean   shown, and inside every scrolling list's
	                                       visible area
	SkinAnim.Active() -> number            characters animating right now
	SkinAnim.ColorWrites() -> number       colour and light writes in the last frame
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local SkinAnimate = require(ReplicatedStorage.Shared.SkinAnimate)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)

type Effect = SkinAnimate.Effect

local SkinAnim = {}

-- A turning joint: its effects (several multiply, in list order) and the last offset worked out.
type Motor = {
	Motor: Motor6D,
	Effects: { Effect },
	Side: number,
	Cached: CFrame,
	Ready: boolean, -- Cached has been worked out at least once
}
-- A recoloured part: the effect that colours it (the last one in the list wins).
type Paint = {
	Part: BasePart,
	Effect: Effect,
	Base: Color3, -- its colour when the effect started (or the server's newer one)
	Index: number, -- its place among the effect's parts (colours ripple across them)
	Height: number, -- 0 at the bottom of the effect's parts, 1 at the top (Shimmer)
}
type Glow = {
	Light: PointLight,
	Bright: Effect?, -- Pulse or Flicker on the brightness
	Tint: Effect?, -- ColorCycle on the colour
	Brightness: number,
	Color: Color3,
}
type Burst = { Effect: Effect, Emitter: ParticleEmitter, Last: number }
-- Everything this screen has written, so it is only put back if nothing else changed it.
type Written = { [Instance]: { [string]: any } }

type Entry = {
	Model: Model, -- the character's Cosmetic_Skin model (tagged SkinAnim)
	Player: Player?,
	Effects: { Effect },
	Active: boolean,
	Dirty: boolean, -- pieces arrived later (streaming): look them up again
	Motors: { Motor },
	Paints: { Paint },
	Glow: Glow?,
	Bursts: { Burst },
	Written: Written,
	Seed: number, -- the wearer's UserId (Flicker looks the same on every screen)
	Distance: number,
	HalfRate: boolean,
	Connections: { RBXScriptConnection },
}

-- A moving group of a preview: a Model (AnimGroup) PivotTo'd relative to its parent group.
type Group = {
	Model: Model,
	Parent: Model?, -- the group it hangs on, or nil (the preview model itself)
	Effects: { Effect },
	Side: number,
	RelPos: Vector3, -- rest place relative to the parent, at scale 1
	RelRot: CFrame,
}
type Preview = {
	Model: Model,
	Groups: { Group }, -- parents first
	Paints: { Paint },
	Written: Written,
}

local entries: { [Model]: Entry } = {}
local active: { Entry } = {} -- closest first (yours first)
local previews: { [Model]: Preview } = {}
local loop: RBXScriptConnection? = nil
local ensureLoop: () -> () -- (defined with the frame loop, below)
local mounted = false
local nextPick = 0
local nextColour = 0
local frame = 0
local writes = 0
local lastWrites = 0
local budget = 0
local burstScale = 1

local function settings()
	return Config.SkinAnimate
end

local function phone(): boolean
	local ok, result = pcall(Layout.IsPhone)
	return ok and result == true
end

-- Colours --------------------------------------------------------------------------------------

-- Part colours are stored as whole numbers 0-255 per channel: compare them that way.
local function sameColour(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.5 / 255
		and math.abs(a.G - b.G) < 0.5 / 255
		and math.abs(a.B - b.B) < 0.5 / 255
end

local function remember(written: Written, instance: Instance, property: string, value: any)
	local list = written[instance]
	if not list then
		list = {}
		written[instance] = list
	end
	list[property] = value
end

local function lastWritten(written: Written, instance: Instance, property: string): any
	local list = written[instance]
	return if list then list[property] else nil
end

-- One part's new colour (counts toward this frame's budget; skipped when unchanged).
local function paint(written: Written, p: Paint, t: number, seed: number)
	local part = p.Part
	if part.Parent == nil then
		return
	end
	local last = lastWritten(written, part, "Color")
	if last ~= nil and not sameColour(part.Color, last) then
		p.Base = part.Color -- the server changed it meanwhile: start from its colour
	end
	local c = SkinAnimate.Tint(p.Effect, p.Base, t, p.Index, p.Height, seed)
	if last ~= nil and sameColour(c, last) then
		return
	end
	part.Color = c
	remember(written, part, "Color", c)
	writes += 1
end

-- Puts back what an effect changed, only where it still holds what it last wrote (D4: the
-- server may have recoloured it, or put a new skin on, meanwhile).
local function restore(written: Written, paints: { Paint }, glow: Glow?)
	for _, p in paints do
		local last = lastWritten(written, p.Part, "Color")
		if p.Part.Parent and last ~= nil and sameColour(p.Part.Color, last) then
			p.Part.Color = p.Base
		end
	end
	if glow then
		local light = glow.Light
		local bright = lastWritten(written, light, "Brightness")
		if bright ~= nil and math.abs(light.Brightness - bright) < 1e-6 then
			light.Brightness = glow.Brightness
		end
		local colour = lastWritten(written, light, "Color")
		if colour ~= nil and sameColour(light.Color, colour) then
			light.Color = glow.Color
		end
	end
	table.clear(written)
end

-- Where each of `parts` sits from bottom (0) to top (1), in `frame`'s up direction.
local function heights(parts: { BasePart }, up: CFrame?): { number }
	local ys = {}
	local lo, hi = math.huge, -math.huge
	for i, p in parts do
		local y = if up then up:PointToObjectSpace(p.Position).Y else p.Position.Y
		ys[i] = y
		lo = math.min(lo, y)
		hi = math.max(hi, y)
	end
	local out = {}
	for i, y in ys do
		out[i] = if hi - lo > 1e-4 then (y - lo) / (hi - lo) else 0.5
	end
	return out
end

-- The colour effects' parts (in `root`: a Cosmetic_Skin model or a preview), the last effect
-- in the list winning a part. Rainbow parts belong to CRAZY (SkinFx) and are always left out.
local function paintsFor(root: Instance, effects: { Effect }, body: Model?, up: CFrame?): { Paint }
	local byPart: { [BasePart]: Paint } = {}
	local order: { BasePart } = {}
	local max = settings().MaxColorParts
	local function use(parts: { BasePart }, effect: Effect)
		local list = {}
		for _, p in parts do
			if p:GetAttribute("Rainbow") ~= true and p:GetAttribute("AnimGroup") == nil then
				table.insert(list, p)
				if #list >= max then
					break
				end
			end
		end
		local hs = heights(list, up)
		for i, p in list do
			local old = byPart[p]
			if not old then
				table.insert(order, p)
			end
			byPart[p] = {
				Part = p,
				Effect = effect,
				Base = if old then old.Base else p.Color,
				Index = i,
				Height = hs[i],
			}
		end
	end
	-- custom-model colour marks (an Animate attribute on a part or Model of the head piece)
	for _, d in root:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Model")) and d:GetAttribute("SkinPart") == "Head" then
			local effect = SkinAnimate.FromAttributes(d)
			if effect and not SkinAnimate.IsMotion(effect.Effect) then
				local parts = {}
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
				for _, inner in d:GetDescendants() do
					if inner:IsA("BasePart") then
						table.insert(parts, inner)
					end
				end
				use(parts, effect)
			end
		end
	end
	for _, effect in effects do
		local info = SkinAnimate.Info(effect.Effect)
		if not info or (info.Kind ~= "Colour" and info.Kind ~= "Light") then
			continue
		end
		if effect.Target == "Body" then
			if body then
				use(Cosmetics.BodyParts(body), effect)
			end
		else
			-- (on a character the Glow is a light, handled apart; a preview's is its halo)
			use(SkinAnimate.PartsFor(root, effect.Target), effect)
		end
	end
	local out = {}
	for _, p in order do
		table.insert(out, byPart[p])
	end
	return out
end

-- Characters -------------------------------------------------------------------------------------

local function characterOf(entry: Entry): Model?
	local parent = entry.Model.Parent
	return if parent and parent:IsA("Model") then parent else nil
end

local function rootOf(entry: Entry): BasePart?
	local character = characterOf(entry)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function hidden(entry: Entry): boolean
	local player = entry.Player
	return player ~= nil and player:GetAttribute("HideSeekRole") == "Hider"
end

local function deactivate(entry: Entry)
	if not entry.Active then
		return
	end
	entry.Active = false
	for _, m in entry.Motors do
		if m.Motor.Parent then
			m.Motor.Transform = CFrame.identity
		end
	end
	restore(entry.Written, entry.Paints, entry.Glow)
	entry.Motors = {}
	entry.Paints = {}
	entry.Glow = nil
	entry.Bursts = {}
	local index = table.find(active, entry)
	if index then
		table.remove(active, index)
	end
end

local function activate(entry: Entry)
	if entry.Active then
		return
	end
	local character = characterOf(entry)
	if not character then
		return
	end
	entry.Active = true
	entry.Dirty = false
	local model = entry.Model
	local t = Workspace:GetServerTimeNow()
	-- Moving groups: pivots by their AnimGroup attribute.
	local byGroup: { [string]: { Effect } } = {}
	for _, effect in entry.Effects do
		if SkinAnimate.IsMotion(effect.Effect) then
			local groups: { string } = if effect.Target == "Wings"
				then { "WingL", "WingR" }
				else { effect.Target }
			for _, name in groups do
				local list = byGroup[name] or {}
				table.insert(list, effect)
				byGroup[name] = list
			end
		end
	end
	for _, d in model:GetDescendants() do
		local name = d:GetAttribute("AnimGroup")
		local motor = d:FindFirstChild("SkinMotor")
		if d:IsA("BasePart") and type(name) == "string" and motor and motor:IsA("Motor6D") then
			local list: { Effect }? = byGroup[name]
			if string.sub(name, 1, 7) == "Custom:" then
				local own = SkinAnimate.FromAttributes(d)
				list = if own and SkinAnimate.IsMotion(own.Effect) then { own } else nil
			end
			if list then
				local side = d:GetAttribute("AnimSide")
				table.insert(entry.Motors, {
					Motor = motor,
					Effects = list,
					Side = if type(side) == "number" then side else 1,
					Cached = CFrame.identity,
					Ready = false,
				})
			end
		end
	end
	local root = rootOf(entry)
	entry.Paints = paintsFor(model, entry.Effects, character, if root then root.CFrame else nil)
	-- The glow light and the aura's particles.
	local light: PointLight? = nil
	local emitter: ParticleEmitter? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") and d.Name == "SkinGlow" then
			light = d
		elseif d:IsA("ParticleEmitter") and d.Name == "SkinAura" then
			emitter = d
		end
	end
	for _, effect in entry.Effects do
		if effect.Target == "Glow" and light then
			local glow: Glow = entry.Glow
				or {
					Light = light,
					Bright = nil,
					Tint = nil,
					Brightness = light.Brightness,
					Color = light.Color,
				}
			if effect.Effect == "ColorCycle" then
				glow.Tint = effect
			elseif effect.Effect == "Pulse" or effect.Effect == "Flicker" then
				glow.Bright = effect
			end
			entry.Glow = glow
		elseif effect.Effect == "SparkleBurst" and emitter then
			table.insert(entry.Bursts, { Effect = effect, Emitter = emitter, Last = t })
		end
	end
end

-- Is the character on this screen (with a margin)? Off-screen characters (except yours) get
-- no writes at all.
local function onScreen(entry: Entry, camera: Camera?): boolean
	local root = rootOf(entry)
	if not root or not camera then
		return false
	end
	local point = camera:WorldToViewportPoint(root.Position)
	local size = camera.ViewportSize
	local m = settings().OffScreenMargin
	return point.Z > 0
		and point.X >= -m * size.X
		and point.X <= (1 + m) * size.X
		and point.Y >= -m * size.Y
		and point.Y <= (1 + m) * size.Y
end

local function watchPlayer(entry: Entry)
	if entry.Player then
		return
	end
	local character = characterOf(entry)
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	entry.Player = player
	entry.Seed = player.UserId
	-- Becoming a Hide & Seek hider stops everything at once (not at the next pick).
	table.insert(
		entry.Connections,
		player:GetAttributeChangedSignal("HideSeekRole"):Connect(function()
			if hidden(entry) then
				deactivate(entry)
			end
			nextPick = 0
		end)
	)
end

-- Animates the closest characters (yours first), up to MaxCharacters (fewer on phones).
local function pick()
	local cfg = settings()
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	local me = Players.LocalPlayer
	local near: { Entry } = {}
	for model, entry in entries do
		watchPlayer(entry)
		local root = rootOf(entry)
		local ok = root ~= nil and model:IsDescendantOf(Workspace) and not hidden(entry)
		if root and ok then
			local own = me ~= nil and entry.Player == me
			local distance = (root.Position - from).Magnitude
			if own or distance <= cfg.MaxDistance then
				entry.Distance = if own then -1 else distance
				table.insert(near, entry)
				continue
			end
		end
		deactivate(entry)
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	local limit = if phone() then cfg.PhoneMaxCharacters else cfg.MaxCharacters
	for i, entry in near do
		if i > limit then
			deactivate(entry)
			continue
		end
		if entry.Dirty then
			deactivate(entry) -- pieces arrived late (streaming): look everything up again
		end
		activate(entry)
		entry.HalfRate = entry.Distance > cfg.HalfRateDistance
	end
	table.clear(active)
	for i, entry in near do
		if i <= limit and entry.Active then
			table.insert(active, entry)
		end
	end
end

local function stepEntry(entry: Entry, t: number, colourTick: boolean, camera: Camera?)
	if entry.Distance >= 0 and not onScreen(entry, camera) then
		return -- off screen: its pieces may rest while nobody can see them
	end
	-- Motion: written every frame (the Animator may reset joints each frame); far away the
	-- maths only runs every second frame.
	local compute = not entry.HalfRate or frame % 2 == 0
	for _, m in entry.Motors do
		if compute or not m.Ready then
			local offset = CFrame.identity
			for _, effect in m.Effects do
				offset *= SkinAnimate.Offset(effect, t, m.Side)
			end
			m.Cached = offset
			m.Ready = true
		end
		if m.Motor.Parent then
			m.Motor.Transform = m.Cached
		end
	end
	if colourTick then
		for _, p in entry.Paints do
			if writes >= budget then
				break
			end
			paint(entry.Written, p, t, entry.Seed)
		end
		local glow = entry.Glow
		if glow and glow.Light.Parent then
			local light = glow.Light
			local bright = glow.Bright
			if bright and writes < budget then
				local b = SkinAnimate.Brightness(bright, glow.Brightness, t, entry.Seed)
				local last = lastWritten(entry.Written, light, "Brightness")
				if last == nil or math.abs(last - b) > 1e-4 then
					light.Brightness = b
					remember(entry.Written, light, "Brightness", b)
					writes += 1
				end
			end
			local tint = glow.Tint
			if tint and writes < budget then
				local c = SkinAnimate.Tint(tint, glow.Color, t, 0, 0.5, entry.Seed)
				local last = lastWritten(entry.Written, light, "Color")
				if last == nil or not sameColour(last, c) then
					light.Color = c
					remember(entry.Written, light, "Color", c)
					writes += 1
				end
			end
		end
	end
	for _, burst in entry.Bursts do
		if SkinAnimate.BurstDue(burst.Effect, burst.Last, t) then
			local emitter = burst.Emitter
			-- never on a switched-off aura (a disguised hider's, for one)
			if emitter.Parent and emitter.Enabled then
				emitter:Emit(SkinAnimate.BurstCount(burst.Effect, burstScale))
			end
		end
		burst.Last = t
	end
end

-- Previews ---------------------------------------------------------------------------------------

local function guiShown(instance: Instance): boolean
	local node: Instance? = instance
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- Is `gui` inside `clip`'s visible area? (The same maths as CrateUI's inView.) Sizes are 0
-- before the first layout, which counts as not visible yet.
local function inView(gui: GuiObject, clip: GuiObject): boolean
	local size = clip.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return false
	end
	local a, b = gui.AbsolutePosition, gui.AbsolutePosition + gui.AbsoluteSize
	local lo, hi = clip.AbsolutePosition, clip.AbsolutePosition + size
	return b.X >= lo.X and a.X <= hi.X and b.Y >= lo.Y and a.Y <= hi.Y
end

function SkinAnim.PreviewVisible(viewport: GuiObject): boolean
	if not guiShown(viewport) then
		return false
	end
	local node: Instance? = viewport.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("ScrollingFrame") and not inView(viewport, node) then
			return false
		end
		node = node.Parent
	end
	return true
end

local function viewportOf(model: Model): ViewportFrame?
	local node: Instance? = model.Parent
	while node do
		if node:IsA("ViewportFrame") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function groupOf(instance: Instance, root: Model): Model?
	local node: Instance? = instance.Parent
	while node and node ~= root do
		if node:IsA("Model") and node:GetAttribute("AnimGroup") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function depth(g: Group): number
	local n = 0
	local node: Instance? = g.Model
	while node do
		if node:IsA("Model") and node:GetAttribute("AnimGroup") ~= nil then
			n += 1
		end
		node = node.Parent
	end
	return n
end

local function restPivot(preview: Preview, g: Group, s: number): CFrame
	local parent = if g.Parent then g.Parent:GetPivot() else preview.Model:GetPivot()
	return parent * CFrame.new(g.RelPos * s) * g.RelRot
end

function SkinAnim.AnimatePreview(model: Model): () -> ()
	if not Config.Features.SkinAnimations then
		return function() end
	end
	local style = SkinAnimate.StyleOf(model)
	local effects: { Effect } = {}
	if style then
		local list = SkinAnimate.Normalize(style.Animate, style)
		if list then
			effects = list
		end
	end
	local byGroup: { [string]: { Effect } } = {}
	for _, effect in effects do
		if SkinAnimate.IsMotion(effect.Effect) then
			local names: { string } = if effect.Target == "Wings"
				then { "WingL", "WingR" }
				else { effect.Target }
			for _, name in names do
				local list = byGroup[name] or {}
				table.insert(list, effect)
				byGroup[name] = list
			end
		end
	end
	local s0 = model:GetScale()
	local groups: { Group } = {}
	for _, d in model:GetDescendants() do
		local name = d:GetAttribute("AnimGroup")
		if d:IsA("Model") and type(name) == "string" then
			local list = byGroup[name] or {}
			if string.sub(name, 1, 7) == "Custom:" then
				local own = SkinAnimate.FromAttributes(d)
				list = if own and SkinAnimate.IsMotion(own.Effect) then { own } else {}
			end
			local parent = groupOf(d, model)
			local parentPivot = if parent then parent:GetPivot() else model:GetPivot()
			local rel = parentPivot:ToObjectSpace(d:GetPivot())
			local side = d:GetAttribute("AnimSide")
			table.insert(groups, {
				Model = d,
				Parent = parent,
				Effects = list,
				Side = if type(side) == "number" then side else 1,
				RelPos = rel.Position / s0,
				RelRot = rel.Rotation,
			})
		end
	end
	table.sort(groups, function(a, b)
		return depth(a) < depth(b)
	end)
	local moving = false
	for _, g in groups do
		if #g.Effects > 0 then
			moving = true
		end
	end
	local paints = paintsFor(model, effects, model, nil)
	if not moving and #paints == 0 then
		return function() end
	end
	local preview: Preview = {
		Model = model,
		Groups = if moving then groups else {},
		Paints = paints,
		Written = {},
	}
	previews[model] = preview
	ensureLoop()
	return function()
		if previews[model] ~= preview then
			return
		end
		previews[model] = nil
		restore(preview.Written, preview.Paints, nil)
		if model.Parent then
			local s = model:GetScale()
			for _, g in preview.Groups do
				if g.Model.Parent then
					g.Model:PivotTo(restPivot(preview, g, s))
				end
			end
		end
	end
end

local function stepPreview(preview: Preview, t: number, colourTick: boolean, motion: boolean)
	if motion then
		local model = preview.Model
		local s = model:GetScale()
		for _, g in preview.Groups do
			if #g.Effects == 0 or not g.Model.Parent then
				continue
			end
			local o = CFrame.identity
			for _, effect in g.Effects do
				o *= SkinAnimate.Offset(effect, t, g.Side)
			end
			g.Model:PivotTo(restPivot(preview, g, s) * CFrame.new(o.Position * s) * o.Rotation)
		end
	end
	if colourTick then
		for _, p in preview.Paints do
			if writes >= budget then
				break
			end
			paint(preview.Written, p, t, 0)
		end
	end
end

-- The frame loop -------------------------------------------------------------------------------

local function step()
	local cfg = settings()
	local now = os.clock()
	if now >= nextPick then
		nextPick = now + cfg.CheckSeconds
		pick()
	end
	frame += 1
	local t = Workspace:GetServerTimeNow()
	local colourTick = now >= nextColour
	if colourTick then
		nextColour = now + 1 / cfg.ColorHz
	end
	local onPhone = phone()
	burstScale = if onPhone then cfg.PhoneBurstScale else 1
	writes = 0
	budget = if colourTick
		then (if onPhone then cfg.PhoneMaxColorWrites else cfg.MaxColorWrites)
		else 0
	local camera = Workspace.CurrentCamera
	for _, entry in active do
		if entry.Active then
			stepEntry(entry, t, colourTick, camera)
		end
	end
	local moving = 0
	local motionAllowed = cfg.PreviewMotionOnPhones or not onPhone
	for model, preview in previews do
		if model.Parent == nil then
			previews[model] = nil -- destroyed with its card
			continue
		end
		local viewport = viewportOf(model)
		if viewport and SkinAnim.PreviewVisible(viewport) then
			local motion = motionAllowed and #preview.Groups > 0 and moving < cfg.MaxPreviewMotion
			if motion then
				moving += 1
			end
			stepPreview(preview, t, colourTick, motion)
		end
	end
	lastWrites = writes
	-- Nothing animated about: stop running every frame until something turns up.
	local current = loop
	if current and next(entries) == nil and next(previews) == nil then
		current:Disconnect()
		loop = nil
	end
end

ensureLoop = function()
	if loop == nil then
		-- After Roblox's animations have set the joints this frame (like Dances).
		loop = RunService.PreSimulation:Connect(step)
	end
end

local function effectsOf(model: Model): { Effect }
	local style = SkinAnimate.StyleOf(model)
	local list = if style then SkinAnimate.Normalize(style.Animate, style) else nil
	return if list then list else {}
end

local function onTagged(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local entry: Entry = {
		Model = instance,
		Player = nil,
		Effects = effectsOf(instance),
		Active = false,
		Dirty = false,
		Motors = {},
		Paints = {},
		Glow = nil,
		Bursts = {},
		Written = {},
		Seed = 0,
		Distance = math.huge,
		HalfRate = false,
		Connections = {},
	}
	table.insert(
		entry.Connections,
		instance.DescendantAdded:Connect(function(d)
			if
				d:IsA("BasePart")
				or d:IsA("Light")
				or d:IsA("ParticleEmitter")
				or d:IsA("Motor6D")
			then
				entry.Dirty = true
			end
		end)
	)
	entries[instance] = entry
	watchPlayer(entry)
	nextPick = 0 -- pick who animates on the next frame
	ensureLoop()
end

local function onUntagged(instance: Instance)
	local entry = entries[instance :: Model]
	if entry then
		deactivate(entry)
		for _, connection in entry.Connections do
			connection:Disconnect()
		end
		entries[instance :: Model] = nil
	end
end

function SkinAnim.Mount(_gui: ScreenGui?)
	if mounted or not Config.Features.SkinAnimations then
		return
	end
	mounted = true
	CollectionService:GetInstanceAddedSignal(Tags.SkinAnim):Connect(onTagged)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinAnim):Connect(onUntagged)
	for _, instance in CollectionService:GetTagged(Tags.SkinAnim) do
		onTagged(instance)
	end
end

function SkinAnim.Active(): number
	local n = 0
	for _, entry in entries do
		if entry.Active then
			n += 1
		end
	end
	return n
end

function SkinAnim.ColorWrites(): number
	return lastWrites
end

return SkinAnim
