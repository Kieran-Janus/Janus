--!strict
--[[
	Round moments (Config.Juice), all local to this player and only while playing (in the
	round, or watching it with Spectate from the lobby):
	  - "RUN!" banner when the King appears (KingCount goes up)
	  - red heartbeat pulse at the screen edges while a King chases you (the server marks
	    each King with TargetUserId) and is within Heartbeat.Distance; faster when closer
	  - "+1" floating up from you on every pumpkin pickup
	  - "Last 30 seconds!" warning
	  - "X survivors left" when someone is caught
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Spectate = require(script.Parent.Spectate)
local Theme = require(script.Parent.Theme)

local RoundJuiceUI = {}

-- A round is on and this player is in it (or watching it from the lobby): players busy in
-- the lobby don't get round banners over their screen.
local function playing(): boolean
	return ReplicatedStorage:GetAttribute("State") == "Playing"
		and (Players.LocalPlayer:GetAttribute("InRound") == true or Spectate.IsActive())
end

function RoundJuiceUI.Mount(gui: ScreenGui)
	local cfg = Config.Juice
	local player = Players.LocalPlayer

	-- Banners ---------------------------------------------------------------------------------------
	local banner = Theme.label("", 64, gui)
	banner.Name = "JuiceBanner"
	banner.Font = Enum.Font.GothamBlack
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromScale(0.9, 0.16)
	banner.TextScaled = true
	banner.TextStrokeTransparency = 0.2
	banner.Visible = false
	banner.ZIndex = 12
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local bannerToken = 0

	local function showBanner(text: string, color: Color3, seconds: number)
		bannerToken += 1
		local token = bannerToken
		banner.Text = text
		banner.TextColor3 = color
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.2
		banner.Visible = true
		bannerScale.Scale = 1.6
		TweenService:Create(
			bannerScale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		task.delay(seconds, function()
			if token ~= bannerToken then
				return
			end
			local fade = TweenService:Create(
				banner,
				TweenInfo.new(0.3),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fade:Play()
			fade.Completed:Once(function()
				if token == bannerToken then
					banner.Visible = false
				end
			end)
		end)
	end

	-- Small pop (survivors left) under the banner area.
	local pop = Theme.label("", 26, gui)
	pop.Name = "JuicePop"
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Position = UDim2.fromScale(0.5, 0.42)
	pop.Size = UDim2.fromOffset(500, 40)
	pop.TextStrokeTransparency = 0.3
	pop.Visible = false
	pop.ZIndex = 12
	-- On short phone screens both move down together, clear of the top bar.
	Layout.KeepBelowHud({ banner, pop })
	local popToken = 0
	local function showPop(text: string, color: Color3, seconds: number)
		popToken += 1
		local token = popToken
		pop.Text = text
		pop.TextColor3 = color
		pop.Visible = true
		task.delay(seconds, function()
			if token == popToken then
				pop.Visible = false
			end
		end)
	end

	local function inRound(): boolean
		return playing()
			and player:GetAttribute("InRound") == true
			and not player:GetAttribute("Out")
	end

	-- RUN! ------------------------------------------------------------------------------------------
	local lastKings = ReplicatedStorage:GetAttribute("KingCount") or 0
	ReplicatedStorage:GetAttributeChangedSignal("KingCount"):Connect(function()
		local kings = ReplicatedStorage:GetAttribute("KingCount") or 0
		if kings > lastKings and inRound() then
			showBanner(cfg.Run.Text, cfg.Run.Color, cfg.Run.Seconds)
		end
		lastKings = kings
	end)

	-- Last 30 seconds -----------------------------------------------------------------------------
	ReplicatedStorage:GetAttributeChangedSignal("TimeLeft"):Connect(function()
		if playing() and ReplicatedStorage:GetAttribute("TimeLeft") == cfg.LastSeconds.At then
			showBanner(cfg.LastSeconds.Text, cfg.LastSeconds.Color, cfg.LastSeconds.Seconds)
		end
	end)

	-- Survivors left --------------------------------------------------------------------------------
	local lastAlive = ReplicatedStorage:GetAttribute("Alive")
	ReplicatedStorage:GetAttributeChangedSignal("Alive"):Connect(function()
		local alive = ReplicatedStorage:GetAttribute("Alive")
		if
			playing()
			and typeof(alive) == "number"
			and typeof(lastAlive) == "number"
			and alive < lastAlive
			and alive > 0
		then
			local s = cfg.Survivors
			showPop(if alive == 1 then s.One else s.Text:format(alive), s.Color, s.Seconds)
		end
		lastAlive = alive
	end)

	-- +1 on pickup ----------------------------------------------------------------------------------
	local pumpkins = player:GetAttribute("Pumpkins") or 0
	player:GetAttributeChangedSignal("Pumpkins"):Connect(function()
		local now = player:GetAttribute("Pumpkins") or 0
		local gained = now - pumpkins
		pumpkins = now
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if gained <= 0 or not head or not head:IsA("BasePart") then
			return
		end
		local p = cfg.Pickup
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PickupPop"
		billboard.Adornee = head
		billboard.Size = UDim2.fromOffset(80, 40)
		billboard.StudsOffsetWorldSpace = Vector3.new(math.random() * 1.2 - 0.6, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		local label = Theme.label(p.Text:format(gained), 30, billboard)
		label.Font = Enum.Font.GothamBlack
		label.Size = UDim2.fromScale(1, 1)
		label.TextColor3 = p.Color
		label.TextStrokeTransparency = 0.2
		billboard.Parent = gui
		local info = TweenInfo.new(p.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(billboard, info, {
			StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, p.Rise, 0),
		}):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
		task.delay(p.Seconds, function()
			billboard:Destroy()
		end)
	end)

	-- Heartbeat vignette ----------------------------------------------------------------------------
	local hb = cfg.Heartbeat
	local vignette = Instance.new("Frame")
	vignette.Name = "Heartbeat"
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 4
	vignette.Visible = false
	vignette.Parent = gui
	-- Four edge strips that fade towards the middle of the screen.
	local edges: { Frame } = {}
	for _, side in { "Top", "Bottom", "Left", "Right" } do
		local edge = Instance.new("Frame")
		edge.Name = side
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = hb.Color
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new(0, 1)
		if side == "Top" then
			edge.Size = UDim2.fromScale(1, 0.25)
			gradient.Rotation = 90
		elseif side == "Bottom" then
			edge.AnchorPoint = Vector2.new(0, 1)
			edge.Position = UDim2.fromScale(0, 1)
			edge.Size = UDim2.fromScale(1, 0.25)
			gradient.Rotation = -90
		elseif side == "Left" then
			edge.Size = UDim2.fromScale(0.18, 1)
			gradient.Rotation = 0
		else
			edge.AnchorPoint = Vector2.new(1, 0)
			edge.Position = UDim2.fromScale(1, 0)
			edge.Size = UDim2.fromScale(0.18, 1)
			gradient.Rotation = 180
		end
		gradient.Parent = edge
		edge.Parent = vignette
		table.insert(edges, edge)
	end

	local function setOpacity(opacity: number)
		for _, edge in edges do
			edge.BackgroundTransparency = 1 - opacity
		end
	end

	local beatSound: Sound? = nil
	if hb.SoundId ~= "" then
		local s = Instance.new("Sound")
		s.Name = "HeartbeatSound"
		s.SoundId = hb.SoundId
		s.Volume = hb.Volume
		s.Parent = SoundService
		task.spawn(function()
			local group = SoundService:WaitForChild("Effects", 30)
			if group and group:IsA("SoundGroup") then
				s.SoundGroup = group
			end
		end)
		beatSound = s
	end

	-- How close (0..1) the nearest King chasing you is; 0 = none in range.
	local function danger(): number
		if not inRound() then
			return 0
		end
		local map = workspace:FindFirstChild("Map")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not map or not root or not root:IsA("BasePart") then
			return 0
		end
		local best = 0
		for _, king in map:GetChildren() do
			if
				king.Name == "PumpkinKing"
				and king:GetAttribute("TargetUserId") == player.UserId
			then
				local kingRoot = king:IsA("Model") and king.PrimaryPart
				if kingRoot then
					local distance = (kingRoot.Position - root.Position).Magnitude
					best = math.max(best, 1 - distance / hb.Distance)
				end
			end
		end
		return math.clamp(best, 0, 1)
	end

	local nextBeat = 0
	local level = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextBeat then
			level = danger()
			if level > 0 then
				nextBeat = now + hb.SlowBeat + (hb.FastBeat - hb.SlowBeat) * level
				if beatSound then
					beatSound:Play()
				end
			else
				nextBeat = now + 0.25 -- check again soon
			end
		end
		if level <= 0 then
			vignette.Visible = false
			return
		end
		vignette.Visible = true
		-- A quick double thump that fades out until the next beat.
		local interval = hb.SlowBeat + (hb.FastBeat - hb.SlowBeat) * level
		local phase = 1 - math.clamp((nextBeat - now) / interval, 0, 1)
		local thump = math.max(math.exp(-phase * 12), 0.7 * math.exp(-math.abs(phase - 0.22) * 14))
		setOpacity(hb.MaxOpacity * (0.35 + 0.65 * level) * (0.4 + 0.6 * thump))
	end)
end

return RoundJuiceUI
