--!strict
--[[
	The crates on the lobby stand come alive (this client only, so the server never moves them).
	Settings: Config.Crates.Idle, Config.Crates.LookDefaults and each crate's Look
	(src/shared/Config/Crates.luau), read through CrateLook.Of. Switched off with
	Config.Features.Crates = false or Config.Crates.Idle.On = false (then nothing here runs and
	HubAmbience floats the crates the old way).

	Crates are found by the tag CrateDisplay (the invisible CratePrompt part, attribute CrateId),
	so a stand moved, copied or saved in the place works the same. The crate itself is the Model
	next to that part named after the crate Id (or with the attribute PropName = Id): the built
	chest or your own model from ReplicatedStorage.Custom.Props.

	Only crates within Idle.Range of the camera (Idle.PhoneRange on phones) move:
	  - they bob (Look.Bob studs) and rock (Look.Sway degrees), each with its own rhythm;
	  - every Look.PeekEvery seconds the lid peeks open (Look.PeekAngle) with a puff of light in
	    the crate's Glow colour, sparkles (Look.Sparkles; phones Idle.PhoneSparkleShare of them)
	    and the Look.Sounds.Peek sound. A custom model without a part named "Lid" only bobs;
	  - the Monster crate's pupils (parts named "Pupil" with the attribute EyeRadius) look at
	    the nearest player within Idle.EyeRange, inside their "Eye";
	  - when you walk within Idle.WakeDistance a crate does a happy wiggle (Look.Sounds.Wake)
	    and a label floats over it: its name, its real price and an "Odds" button that opens
	    the crate panel on it (every skin and its exact chance).
	A soft glowing disc in the crate's Glow colour sits under each crate (Idle.GlowRing).
	When a crate leaves range it goes back to where the server put it, lid shut.
	Everything made here is local: Workspace.CrateIdleFx and the labels in PlayerGui.
]]
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

type Pupil = {
	Part: BasePart,
	Eye: BasePart,
	Rest: CFrame, -- the pupil relative to its eye, looking straight ahead
	Normal: Vector3, -- out of the eye, in the eye's space
	Radius: number,
	Offset: Vector3, -- where it looks now, in the eye's space
}

type State = {
	Holder: BasePart,
	Id: string,
	Def: any,
	Look: CrateLook.Look,
	Phase: number,
	Model: Model?,
	FoundAt: number,
	Base: CFrame?,
	Centre: CFrame, -- the middle of the crate, relative to its pivot
	Lid: CrateLook.Lid?,
	Pupils: { Pupil },
	Active: boolean,
	Awake: boolean,
	NextPeek: number,
	PeekStart: number?,
	WiggleStart: number?,
	Fx: BasePart?, -- the glow disc (also holds the puff's light and sparkles)
	Puff: Attachment?,
	Light: PointLight?,
	Sparkles: ParticleEmitter?,
	Label: BillboardGui?,
}

local CrateIdle = {}

local states: { [BasePart]: State } = {}
local robuxPrices: { [number]: number } = {}

-- 80000 -> "80,000"
local function commas(n: number): string
	local out = tostring(math.floor(n))
	while true do
		local swapped, count = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		out = swapped
		if count == 0 then
			return out
		end
	end
end

local function crateDef(id: string): any
	for _, crate in Config.Crates.List do
		if crate.Id == id then
			return crate
		end
	end
	return nil
end

-- The price line on the label: coins from Config, Robux only once Roblox told us the real price.
local function priceText(def: any): string
	local idle = Config.Crates.Idle
	local coins = if typeof(def.Price) == "number"
		then idle.LabelCoins:format(commas(def.Price), Config.Economy.CurrencyName)
		else nil
	local robux: string? = nil
	local id = def.Robux and def.Robux.ProductId or 0
	if id ~= 0 and robuxPrices[id] then
		robux = idle.LabelRobux:format(robuxPrices[id])
	end
	if coins and robux then
		return idle.LabelBoth:format(coins, robux)
	end
	return coins or robux or Config.Crates.Text.ComingSoon
end

-- The crate model next to the CratePrompt part, or nil (streamed out, or a lone tagged part).
local function findModel(s: State): Model?
	local display = s.Holder.Parent
	if not display then
		return nil
	end
	local named = display:FindFirstChild(s.Id)
	if named and named:IsA("Model") then
		return named
	end
	for _, child in display:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PropName") == s.Id then
			return child
		end
	end
	return nil
end

local function findPupils(model: Model): { Pupil }
	local eyes: { BasePart } = {}
	local pupils: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Eye" then
				table.insert(eyes, d)
			elseif d.Name == "Pupil" and typeof(d:GetAttribute("EyeRadius")) == "number" then
				table.insert(pupils, d)
			end
		end
	end
	local out: { Pupil } = {}
	local front = model:GetPivot().LookVector
	for _, pupil in pupils do
		local eye: BasePart? = nil
		local best = math.huge
		for _, e in eyes do
			local d = (e.Position - pupil.Position).Magnitude
			if d < best then
				best, eye = d, e
			end
		end
		if eye then
			local rest = eye.CFrame:ToObjectSpace(pupil.CFrame)
			local normal = if rest.Position.Magnitude > 1e-3
				then rest.Position.Unit
				else eye.CFrame:VectorToObjectSpace(front)
			table.insert(out, {
				Part = pupil,
				Eye = eye,
				Rest = rest,
				Normal = normal,
				Radius = pupil:GetAttribute("EyeRadius") :: number,
				Offset = Vector3.zero,
			})
		end
	end
	return out
end

local function lidOk(lid: CrateLook.Lid): boolean
	for _, p in lid.Parts do
		if not p.Parent then
			return false
		end
	end
	return true
end

function CrateIdle.Mount(_gui: ScreenGui?)
	local idle = Config.Crates.Idle
	if not (Config.Features.Crates and idle.On) then
		return
	end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "CrateIdleFx"
	fxFolder.Parent = workspace
	local rng = Random.new()
	local minText = Config.UI.MinTextSize

	-- The real Robux price of each crate on sale for Robux (asked once).
	local function askRobux(def: any)
		local id = def.Robux and def.Robux.ProductId or 0
		if id == 0 or robuxPrices[id] then
			return
		end
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if
				ok
				and type(info) == "table"
				and typeof(info.PriceInRobux) == "number"
				and info.PriceInRobux > 0
			then
				robuxPrices[id] = info.PriceInRobux
				for _, s in states do
					local price = s.Label and s.Label:FindFirstChild("Price", true)
					if price and price:IsA("TextLabel") then
						price.Text = priceText(s.Def)
					end
				end
			end
		end)
	end

	-- Glow disc, light and sparkles: made once the crate's size is known.
	local function makeFx(s: State, model: Model)
		if s.Fx then
			s.Fx:Destroy()
		end
		local base = s.Base :: CFrame
		local boxCf, boxSize = model:GetBoundingBox()
		s.Centre = base:ToObjectSpace(boxCf)
		local width = math.max(boxSize.X, boxSize.Z) * idle.GlowRingScale
		local fx = Instance.new("Part")
		fx.Name = "CrateGlow"
		fx.Anchored = true
		fx.CanCollide = false
		fx.CanQuery = false
		fx.CanTouch = false
		fx.CastShadow = false
		fx.Shape = Enum.PartType.Cylinder
		fx.Material = Enum.Material.Neon
		fx.Color = s.Look.Glow
		fx.Transparency = if idle.GlowRing then idle.GlowRingTransparency else 1
		fx.Size = Vector3.new(idle.GlowRingThickness, width, width)
		local bottom = boxCf.Position.Y - boxSize.Y / 2 - idle.GlowRingDrop
		fx.CFrame = CFrame.new(boxCf.Position.X, bottom, boxCf.Position.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		fx:SetAttribute("CrateId", s.Id)
		local puff = Instance.new("Attachment")
		puff.Name = "Puff"
		puff.Parent = fx
		puff.WorldCFrame = CFrame.new(boxCf.Position)
		local light = Instance.new("PointLight")
		light.Color = s.Look.Glow
		light.Range = idle.PeekLightRange
		light.Brightness = 0
		light.Shadows = false
		light.Enabled = false
		light.Parent = puff
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Enabled = false
		sparkles.Rate = 0
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(s.Look.Glow)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(idle.SparkleSize, 0)
		sparkles.Lifetime = NumberRange.new(idle.SparkleLifetime * 0.6, idle.SparkleLifetime)
		sparkles.Speed = NumberRange.new(idle.SparkleSpeed * 0.5, idle.SparkleSpeed)
		sparkles.SpreadAngle = Vector2.new(35, 35)
		sparkles.EmissionDirection = Enum.NormalId.Top
		sparkles.Acceleration = Vector3.new(0, -idle.SparkleSpeed, 0)
		sparkles.Parent = puff
		fx.Parent = fxFolder
		s.Fx, s.Puff, s.Light, s.Sparkles = fx, puff, light, sparkles
	end

	-- The floating label over an awake crate: name, real price, Odds.
	local function makeLabel(s: State): BillboardGui
		local phone = Layout.IsPhone()
		local board = Instance.new("BillboardGui")
		board.Name = "CrateIdleLabel"
		board:SetAttribute("CrateId", s.Id)
		board.Adornee = s.Holder
		board.Active = true
		board.AlwaysOnTop = false -- (behind walls like any sign; AlwaysOnTop labels didn't draw)
		board.ResetOnSpawn = false
		board.LightInfluence = 0
		board.Size = UDim2.fromOffset(
			if phone then idle.PhoneLabelWidth else idle.LabelWidth,
			if phone then idle.PhoneLabelHeight else idle.LabelHeight
		)
		board.StudsOffsetWorldSpace = Vector3.new(0, s.Holder.Size.Y / 2 + idle.LabelAbove, 0)
		local panel = Theme.panel(board)
		panel.Name = "Panel"
		panel.Size = UDim2.fromScale(1, 1)
		local size = math.max(minText, idle.LabelTextSize)
		local name = Theme.label(s.Def.Name, size, panel)
		name.Name = "CrateName"
		name.Position = UDim2.fromOffset(8, 4)
		name.Size = UDim2.new(1, -16, 0.34, 0)
		name.TextColor3 = s.Look.Glow
		name.TextWrapped = true
		local price = Theme.label(priceText(s.Def), math.max(minText, size - 2), panel)
		price.Name = "Price"
		price.Position = UDim2.new(0, 8, 0.34, 4)
		price.Size = UDim2.new(1, -16, 0.26, 0)
		price.TextWrapped = true
		local odds = Theme.button(idle.LabelOdds, panel, Theme.Selected)
		odds.Name = "Odds"
		odds.TextSize = math.max(minText, size - 2)
		odds.AnchorPoint = Vector2.new(0.5, 1)
		odds.Position = UDim2.new(0.5, 0, 1, -6)
		odds.Size = UDim2.fromScale(0.6, 0.32)
		local id = s.Id
		odds.Activated:Connect(function()
			local CrateUI = (require :: any)(script.Parent.CrateUI)
			CrateUI.Open(id)
		end)
		board.Enabled = false
		board.Parent = playerGui
		askRobux(s.Def)
		return board
	end

	local function resetPupils(s: State)
		for _, p in s.Pupils do
			p.Offset = Vector3.zero
			if p.Part.Parent and p.Eye.Parent then
				p.Part.CFrame = p.Eye.CFrame * p.Rest
			end
		end
	end

	-- Back where the server put it, lid shut, eyes ahead, label hidden.
	local function sleep(s: State)
		local model = s.Model
		if model and s.Base and model.Parent then
			model:PivotTo(s.Base)
			if s.Lid and lidOk(s.Lid) then
				CrateLook.LidPose(s.Lid, 0)
			end
			resetPupils(s)
		end
		s.PeekStart = nil
		s.WiggleStart = nil
		s.Active = false
		s.Awake = false
		if s.Light then
			s.Light.Enabled = false
			s.Light.Brightness = 0
		end
		if s.Label then
			s.Label.Enabled = false
		end
	end

	local function forgetModel(s: State)
		s.Model = nil
		s.Base = nil
		s.Lid = nil
		s.Pupils = {}
		s.PeekStart = nil
		s.WiggleStart = nil
		s.Active = false
		s.Awake = false
		if s.Label then
			s.Label.Enabled = false
		end
	end

	local function add(instance: Instance)
		if not instance:IsA("BasePart") or states[instance] then
			return
		end
		local id = instance:GetAttribute("CrateId")
		local def = if type(id) == "string" then crateDef(id) else nil
		if not def then
			return
		end
		local look = CrateLook.Of(def)
		local now = os.clock()
		states[instance] = {
			Holder = instance,
			Id = id :: string,
			Def = def,
			Look = look,
			Phase = rng:NextNumber(0, math.pi * 2),
			Model = nil,
			FoundAt = now,
			Base = nil,
			Centre = CFrame.identity,
			Lid = nil,
			Pupils = {},
			Active = false,
			Awake = false,
			NextPeek = now + look.PeekEvery * rng:NextNumber(0.2, 1),
			PeekStart = nil,
			WiggleStart = nil,
		}
	end

	local function remove(instance: Instance)
		local s = states[instance :: BasePart]
		if not s then
			return
		end
		states[instance :: BasePart] = nil
		sleep(s)
		if s.Fx then
			s.Fx:Destroy()
		end
		if s.Label then
			s.Label:Destroy()
		end
	end

	for _, instance in CollectionService:GetTagged(Tags.CrateDisplay) do
		add(instance)
	end
	local connections = {
		CollectionService:GetInstanceAddedSignal(Tags.CrateDisplay):Connect(add),
		CollectionService:GetInstanceRemovedSignal(Tags.CrateDisplay):Connect(remove),
	}

	-- The crate's model, its resting place, lid and eyes (lazily: parts stream in and out).
	-- Returns false while there is nothing to animate yet.
	local function ready(s: State, now: number): boolean
		local display = s.Holder.Parent
		local model = s.Model
		if model and (model.Parent ~= display or not model:IsDescendantOf(workspace)) then
			forgetModel(s) -- streamed out, swapped for a new look, or moved away
			if s.Fx then
				s.Fx:Destroy()
				s.Fx = nil
			end
			model = nil
		end
		if not model then
			local found = findModel(s)
			if not found or not found:IsDescendantOf(workspace) then
				return false
			end
			s.Model = found
			s.FoundAt = now
			return false -- one frame later: anything else letting go of it has put it back
		end
		if s.Base then
			return true
		end
		if now <= s.FoundAt then
			return false
		end
		if not (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) then
			return false
		end
		s.Lid = CrateLook.Lid(model) -- (may move the pivot off the lid, keeping it in place)
		s.Base = model:GetPivot()
		s.Pupils = findPupils(model)
		makeFx(s, model)
		-- The plinth's light (Config.Crates.Stand.LightBrightness): a lobby saved with the old,
		-- brighter one would wash the painted chests out.
		local ring = display and display:FindFirstChild("GlowRing")
		local ringLight = ring and ring:FindFirstChildWhichIsA("PointLight")
		if ringLight then
			ringLight.Brightness = Config.Crates.Stand.LightBrightness
		end
		return true
	end

	local function startPeek(s: State, now: number, phone: boolean)
		s.PeekStart = now
		local model = s.Model :: Model
		if s.Puff then
			s.Puff.WorldCFrame = CFrame.new((model:GetPivot() * s.Centre).Position)
		end
		if s.Light then
			s.Light.Enabled = true
		end
		local count = s.Look.Sparkles
		if phone then
			count = math.floor(count * idle.PhoneSparkleShare + 0.5)
		end
		if s.Sparkles and count > 0 then
			s.Sparkles:Emit(count)
		end
		Sounds.PlaySpec(s.Look.Sounds.Peek :: any, s.Holder)
	end

	local function nearestHead(at: Vector3): Vector3?
		local best: Vector3? = nil
		local bestDistance = idle.EyeRange
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				local d = (head.Position - at).Magnitude
				if d <= bestDistance then
					best, bestDistance = head.Position, d
				end
			end
		end
		return best
	end

	local function look(s: State, dt: number)
		if #s.Pupils == 0 then
			return
		end
		local target = nearestHead(s.Holder.Position)
		local blend = math.min(1, dt * idle.EyeSpeed)
		for _, p in s.Pupils do
			if not (p.Part.Parent and p.Eye.Parent) then
				continue
			end
			local want = Vector3.zero
			if target then
				local dir = p.Eye.CFrame:PointToObjectSpace(target)
				local planar = dir - p.Normal * dir:Dot(p.Normal)
				if planar.Magnitude > 1e-4 and dir.Magnitude > 1e-4 then
					-- Straight ahead = the middle; off to the side = towards the edge.
					local share = if dir:Dot(p.Normal) <= 0
						then 1
						else math.clamp(planar.Magnitude / dir.Magnitude, 0, 1)
					want = planar.Unit * p.Radius * share
				end
			end
			p.Offset = p.Offset:Lerp(want, blend)
			if p.Offset.Magnitude > p.Radius then
				p.Offset = p.Offset.Unit * p.Radius
			end
			p.Part.CFrame = p.Eye.CFrame * CFrame.new(p.Offset) * p.Rest
		end
	end

	local phone = false
	local range = idle.Range
	local nextScreenCheck = 0
	local last = os.clock()
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = math.clamp(now - last, 0, 0.25)
			last = now
			if now >= nextScreenCheck then
				nextScreenCheck = now + 1
				phone = Layout.IsPhone()
				range = if phone then idle.PhoneRange else idle.Range
			end
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local eye = camera.CFrame.Position
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local rootPos = if root and root:IsA("BasePart") then root.Position else nil
			-- Only the crate nearest to you shows its label (several awake at once would overlap).
			local nearest: State? = nil
			local nearestDistance = math.huge
			if rootPos then
				for holder, s in states do
					if holder.Parent and s.Base then
						local d = ((s.Base :: CFrame).Position - rootPos).Magnitude
						if d < nearestDistance then
							nearest, nearestDistance = s, d
						end
					end
				end
			end
			for holder, s in states do
				if not holder.Parent then
					continue -- (streamed out: the removed signal cleans it up)
				end
				if not ready(s, now) then
					continue
				end
				local model = s.Model :: Model
				local base = s.Base :: CFrame
				if (base.Position - eye).Magnitude > range then
					if s.Active then
						sleep(s)
					end
					continue
				end
				if not s.Active then
					s.Active = true
					if s.NextPeek < now then
						s.NextPeek = now + s.Look.PeekEvery * rng:NextNumber(0.2, 1)
					end
				end
				local lk = s.Look

				-- Wake up when you walk up to it; fall asleep again a bit further away.
				local reach = idle.WakeDistance + (if s.Awake then idle.WakeHysteresis else 0)
				local near = rootPos ~= nil and (rootPos - base.Position).Magnitude <= reach
				if near and not s.Awake then
					s.Awake = true
					s.WiggleStart = now
					Sounds.PlaySpec(lk.Sounds.Wake :: any, s.Holder)
					if idle.WakeLabel then
						s.Label = s.Label or makeLabel(s)
						local label = s.Label :: BillboardGui
						local price = label:FindFirstChild("Price", true)
						if price and price:IsA("TextLabel") then
							price.Text = priceText(s.Def)
						end
					end
				elseif not near and s.Awake then
					s.Awake = false
					if s.Label then
						s.Label.Enabled = false
					end
				end
				if s.Label then
					s.Label.Enabled = s.Awake and s == nearest
				end

				-- Bob and sway, plus the happy wiggle.
				local y = math.sin(now * idle.BobSpeed + s.Phase) * lk.Bob
				local sway = math.sin(now * idle.SwaySpeed + s.Phase * 1.3) * lk.Sway
				local twist = 0
				if s.WiggleStart then
					local p = (now - s.WiggleStart) / math.max(idle.WiggleSeconds, 0.01)
					if p >= 1 then
						s.WiggleStart = nil
					else
						local fade = 1 - p
						y += math.abs(math.sin(p * math.pi * idle.WiggleHops)) * idle.WiggleHeight * fade
						twist = math.sin(p * math.pi * 2 * idle.WiggleHops)
							* idle.WiggleTwist
							* fade
					end
				end
				model:PivotTo(
					CFrame.new(0, y, 0) * base * CFrame.Angles(0, math.rad(twist), math.rad(sway))
				)

				-- The lid peeks (only a crate with a lid).
				local lid = s.Lid
				if lid and not lidOk(lid) then
					s.Lid = nil
					lid = nil
				end
				if lid then
					if not s.PeekStart and lk.PeekEvery > 0 and now >= s.NextPeek then
						s.NextPeek = now + lk.PeekEvery
						startPeek(s, now, phone)
					end
					local started = s.PeekStart
					if started then
						local p = (now - started) / math.max(idle.PeekSeconds, 0.01)
						if p >= 1 then
							s.PeekStart = nil
							CrateLook.LidPose(lid, 0)
							if s.Light then
								s.Light.Brightness = 0
								s.Light.Enabled = false
							end
						else
							local curve = math.sin(p * math.pi)
							CrateLook.LidPose(lid, curve * lk.PeekAngle)
							if s.Light then
								s.Light.Brightness = idle.PeekLightBrightness * curve
							end
						end
					end
				end

				look(s, dt)
			end
		end)
	)

	-- Leaving the game: put everything back and tidy up.
	table.insert(
		connections,
		player.AncestryChanged:Connect(function(_, parent)
			if parent then
				return
			end
			for _, c in connections do
				c:Disconnect()
			end
			for holder in states do
				remove(holder)
			end
			fxFolder:Destroy()
		end)
	)
end

return CrateIdle
