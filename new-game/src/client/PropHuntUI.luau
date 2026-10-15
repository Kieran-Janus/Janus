--!strict
--[[
	Prop Hunt screen (settings and words: Config.PropHunt). Shows only while the
	ReplicatedStorage attribute Mode is "PropHunt" and a round is on:
	  - a big role banner: "You're a HIDER - turn into a thing!" / "You're a FINDER" (and
	    "You were found!" when a pumpkin gets you)
	  - the finders' blindfold while the hiders hide (State "Hiding"): "COUNTING... 15"
	  - a bar under the top Hud: your role, hiders left, finders, your finds / changes left
	  - a short message line: who found whom, "Just a skull!", "The hiders are glowing!"
	  - hiders: the thing you'd become gets a green outline and a "Become the skull [E]" label
	    (the thing under the mouse on PC, else the nearest one); buttons BECOME IT (E, gamepad
	    X, or tap a thing), LOCK (Q, gamepad Y) and TAUNT (T, gamepad L1), big on touch screens
	  - finders on touch screens: a FIRE button (shoots at the crosshair in the middle)
	  - no chat bubbles while a round is on (they'd float over hidden hiders)
	The cannon's aiming, crosshair and world effects are in src/client/PropHuntCannon.luau,
	mounted from here once the first Prop Hunt round starts.
	On/off: Config.Features.PropHunt (off = Mount does nothing and nothing shows).

	Reads: ReplicatedStorage attributes Mode, State, TimeLeft, PropHidersLeft, PropFinderCount
	and the player attributes HideSeekRole, PropFinds, PropChangesLeft, PropLocked,
	PropTauntReadyAt, PropDisguise (set by src/server/Modes/PropHunt.luau).
	Remotes (fetched only once Mode is "PropHunt": the server makes them when it loads the
	mode): PropHuntEvent (server -> client), PropHuntAction and PropHuntShoot (client -> server).
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local PropHuntCannon = require(script.Parent.PropHuntCannon)
local ScreenFx = require(script.Parent.ScreenFx)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local PropHuntUI = {}

local MODE = "PropHunt"
local ACTIONS = { Become = "PropHuntBecome", Lock = "PropHuntLock", Taunt = "PropHuntTaunt" }
local TARGET_EVERY = 0.15 -- seconds between looks for the thing a hider would become

local function inMode(): boolean
	return ReplicatedStorage:GetAttribute("Mode") == MODE
end

local function roundOn(): boolean
	local state = ReplicatedStorage:GetAttribute("State")
	return inMode() and (state == "Hiding" or state == "Playing")
end

local function number(value: unknown): number
	return if typeof(value) == "number" then value else 0
end

-- What a thing is called on screen.
local function label(name: unknown): string
	if typeof(name) ~= "string" then
		return "thing"
	end
	return Config.PropHunt.PropLabels[name] or name
end

local spectate: any = nil
local function spectating(): boolean
	return spectate ~= nil and spectate.IsActive() == true
end

-- A round action button (Theme.button made into a circle with a key hint under the words).
local function roundButton(
	text: string,
	key: string,
	color: Color3,
	size: number,
	parent: Instance
): TextButton
	local b = Theme.button(text, parent, color)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = math.floor(size / 5)
	b.TextWrapped = true
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromOffset(size, size)
	b.Visible = false
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local hint = Theme.label(key, 13, b)
	hint.Name = "Key"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -8)
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.Visible = not Layout.IsTouch()
	return b
end

function PropHuntUI.Mount(gui: ScreenGui)
	if not Config.Features.PropHunt then
		return
	end
	local cfg = Config.PropHunt
	local text = cfg.Text
	local colors = cfg.Colors
	local motion = Config.ScreenMotion.HideSeek -- the same banner timings as Hide & Seek
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local touch = Layout.IsTouch()

	local actionRemote: RemoteEvent? = nil

	-- Big banner ---------------------------------------------------------------------------------
	local banner = Theme.label("", 56, gui)
	banner.Name = "PropHuntBanner"
	banner.Font = Enum.Font.GothamBlack
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.22)
	banner.Size = UDim2.fromScale(0.9, 0.1)
	banner.TextScaled = true
	banner.TextStrokeTransparency = 0.15
	banner.Visible = false
	banner.ZIndex = 12
	local bannerSize = Instance.new("UITextSizeConstraint")
	bannerSize.MaxTextSize = 60
	bannerSize.MinTextSize = 20
	bannerSize.Parent = banner

	local tip = Theme.label("", 20, gui)
	tip.Name = "PropHuntTip"
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 0.27, 6)
	tip.Size = UDim2.fromOffset(560, 28)
	tip.TextWrapped = true
	tip.TextStrokeTransparency = 0.3
	tip.Visible = false
	tip.ZIndex = 12
	Layout.Fit(tip)

	local bannerToken = 0
	local foundAt = -math.huge
	local function showBanner(
		message: string,
		color: Color3,
		tipText: string?,
		seconds: number?,
		burst: boolean?
	)
		bannerToken += 1
		local token = bannerToken
		banner.Text = message
		banner.TextColor3 = color
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.15
		banner.Visible = true
		tip.Text = tipText or ""
		tip.TextTransparency = 0
		tip.Visible = tipText ~= nil and tipText ~= ""
		if burst then
			ScreenFx.Punch(
				banner,
				motion.TaggedPopScale,
				motion.TaggedPopSeconds,
				motion.TaggedShakeDegrees
			)
			ScreenFx.Burst(
				gui,
				banner.Position,
				motion.TaggedColors,
				ScreenFx.Count(motion.TaggedSparkles)
			)
		else
			local side = if token % 2 == 0 then 1 else -1
			ScreenFx.Punch(
				banner,
				motion.RolePopScale,
				motion.RolePopSeconds,
				motion.RoleShakeDegrees * side
			)
		end
		task.delay(seconds or motion.BannerSeconds, function()
			if token ~= bannerToken then
				return
			end
			local fadeSeconds = if ScreenFx.On() then motion.FadeSeconds else 0
			if fadeSeconds > 0 then
				local fade = TweenInfo.new(fadeSeconds)
				TweenService
					:Create(banner, fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
					:Play()
				TweenService:Create(tip, fade, { TextTransparency = 1 }):Play()
				task.wait(fadeSeconds + 0.05)
			end
			if token == bannerToken then
				banner.Visible = false
				tip.Visible = false
			end
		end)
	end

	-- Status bar and message line --------------------------------------------------------------
	local status = Theme.panel(gui)
	status.Name = "PropHuntStatus"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0.02, 72)
	status.Size = UDim2.fromOffset(460, 34)
	status.Visible = false
	Layout.Fit(status)
	Layout.KeepBelowHud({ banner, tip }, status)
	local statusText = Theme.label("", 17, status)
	statusText.Size = UDim2.new(1, -16, 1, 0)
	statusText.Position = UDim2.fromOffset(8, 0)
	statusText.RichText = true
	statusText.TextTruncate = Enum.TextTruncate.AtEnd

	local feed = Theme.label("", 18, gui)
	feed.Name = "PropHuntFeed"
	feed.AnchorPoint = Vector2.new(0.5, 0)
	feed.Position = UDim2.new(0.5, 0, 0.02, 112)
	feed.Size = UDim2.fromOffset(480, 28)
	feed.TextStrokeTransparency = 0.3
	feed.Visible = false
	Layout.Fit(feed)
	local feedToken = 0
	local function showFeed(message: string, color: Color3?, glow: boolean?)
		feedToken += 1
		local token = feedToken
		feed.Text = message
		feed.TextColor3 = color or Theme.Text
		feed.Visible = true
		if glow then
			ScreenFx.Pulse(feed, motion.GlowPulses, motion.GlowPulseSeconds, motion.GlowPulseFade)
		else
			ScreenFx.Pulse(feed, 0, 0, 0)
			if ScreenFx.On() then
				UIMotion.Bump(feed)
			end
		end
		task.delay(motion.FeedSeconds, function()
			if token == feedToken then
				feed.Visible = false
			end
		end)
	end

	-- Blindfold (its own screen, under the normal UI) ------------------------------------------
	local blindGui = Instance.new("ScreenGui")
	blindGui.Name = "PropHuntBlindfold"
	blindGui.ResetOnSpawn = false
	blindGui.IgnoreGuiInset = true
	blindGui.DisplayOrder = -1
	blindGui.Enabled = false
	blindGui.Parent = playerGui
	local blind = Instance.new("Frame")
	blind.Name = "Blindfold"
	blind.Size = UDim2.fromScale(1, 1)
	blind.BackgroundColor3 = colors.Blindfold
	blind.BorderSizePixel = 0
	blind.Parent = blindGui
	local phone = Layout.IsPhone()
	local counting = Theme.label("", 72, blind)
	counting.Name = "Counting"
	counting.Font = Enum.Font.GothamBlack
	counting.AnchorPoint = Vector2.new(0.5, 1)
	counting.Position = if phone then UDim2.new(0.5, 0, 1, -48) else UDim2.fromScale(0.5, 0.62)
	counting.Size = UDim2.fromScale(0.9, 0.16)
	counting.TextScaled = true
	counting.TextColor3 = colors.Seeker
	counting.TextStrokeTransparency = 0.2
	local countingSize = Instance.new("UITextSizeConstraint")
	countingSize.MaxTextSize = 90
	countingSize.Parent = counting
	local peek = Theme.label(text.CountingTip, 22, blind)
	peek.Name = "Tip"
	peek.AnchorPoint = Vector2.new(0.5, if phone then 1 else 0)
	peek.Position = if phone then UDim2.new(0.5, 0, 1, -14) else UDim2.new(0.5, 0, 0.62, 6)
	peek.Size = UDim2.new(0.9, 0, 0, 30)
	peek.TextScaled = true
	peek.TextColor3 = Theme.Muted

	-- Buttons (bottom right; above the jump button on touch screens) ----------------------------
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local bigJump = math.min(viewport.X, viewport.Y) > 500
	local bottom = if touch then (if bigJump then -235 else -170) else -30
	local right = if touch then -20 else -30
	local bigSize = if touch then 104 else 112
	local smallSize = if touch then 72 else 76
	local buttons = Instance.new("Frame")
	buttons.Name = "PropHuntButtons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.fromScale(1, 1)
	buttons.Parent = gui
	local become = roundButton(text.BecomeButton, text.BecomeKey, colors.Button, bigSize, buttons)
	become.Name = "BecomeButton"
	become.Position = UDim2.new(1, right, 1, bottom)
	local lock = roundButton(text.LockButton, text.LockKey, colors.Lock, smallSize, buttons)
	lock.Name = "LockButton"
	lock.Position = UDim2.new(1, right - bigSize - 12, 1, bottom)
	local taunt = roundButton(text.TauntButton, text.TauntKey, colors.Taunt, smallSize, buttons)
	taunt.Name = "TauntButton"
	-- (above the others; on touch screens in the row beside LOCK instead: a phone held
	-- sideways is too short to stack it above BECOME IT, it would end up off the top)
	taunt.Position = if touch
		then UDim2.new(1, right - bigSize - 12 - smallSize - 10, 1, bottom)
		else UDim2.new(1, right - bigSize + smallSize * 0.3, 1, bottom - bigSize - 10)
	local tauntShade = Instance.new("TextLabel")
	tauntShade.Name = "Cooldown"
	tauntShade.BackgroundColor3 = Color3.new(0, 0, 0)
	tauntShade.BackgroundTransparency = 0.4
	tauntShade.Size = UDim2.fromScale(1, 1)
	tauntShade.Font = Enum.Font.GothamBlack
	tauntShade.TextSize = 24
	tauntShade.TextColor3 = Theme.Text
	tauntShade.Visible = false
	tauntShade.Parent = taunt
	local shadeCorner = Instance.new("UICorner")
	shadeCorner.CornerRadius = UDim.new(0.5, 0)
	shadeCorner.Parent = tauntShade
	local fire = roundButton(text.FireButton, "", colors.Fire, bigSize, buttons)
	fire.Name = "FireButton"
	fire.Position = UDim2.new(1, right, 1, bottom)

	-- The thing a hider would become: outline + label ------------------------------------------
	local outline = Instance.new("Highlight")
	outline.Name = "PropHuntTarget"
	outline.FillTransparency = 1
	outline.OutlineColor = cfg.Effects.TargetColor
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Enabled = false
	local targetTag = Instance.new("BillboardGui")
	targetTag.Name = "PropHuntTargetLabel"
	targetTag.Size = UDim2.fromOffset(240, 34)
	targetTag.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	targetTag.AlwaysOnTop = true
	targetTag.LightInfluence = 0
	targetTag.Enabled = false
	targetTag.Parent = playerGui
	local targetText = Theme.label("", 18, targetTag)
	targetText.Size = UDim2.fromScale(1, 1)
	targetText.TextColor3 = cfg.Effects.TargetColor
	targetText.TextStrokeTransparency = 0.2
	targetText.TextScaled = true

	-- State ------------------------------------------------------------------------------------
	local function myRole(): string?
		local role = player:GetAttribute("HideSeekRole")
		return if typeof(role) == "string" then role else nil
	end
	local function hiding(): boolean
		return roundOn() and myRole() == "Hider"
	end

	local target: Instance? = nil
	local function mapModel(): Instance?
		return workspace:FindFirstChild("Map")
	end
	-- The tagged thing `part` belongs to, on the map (not someone's disguise).
	local function propOf(part: Instance?): Instance?
		local node = part
		local map = mapModel()
		while node and node ~= workspace do
			if CollectionService:HasTag(node, Tags.PropHuntProp) then
				return if map and node:IsDescendantOf(map) then node else nil
			end
			node = node.Parent
		end
		return nil
	end
	local function pivotOf(prop: Instance): Vector3?
		if prop:IsA("Model") then
			return prop:GetPivot().Position
		elseif prop:IsA("BasePart") then
			return prop.Position
		end
		return nil
	end
	local function myRoot(): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end
	local function inRange(prop: Instance, root: BasePart): boolean
		local at = pivotOf(prop)
		return at ~= nil and (at - root.Position).Magnitude <= cfg.Disguise.Range
	end
	-- The thing under the screen point (viewport pixels), if it is close enough.
	local function propAt(point: Vector2): Instance?
		local cam = workspace.CurrentCamera
		local root = myRoot()
		if not cam or not root then
			return nil
		end
		local ray = cam:ViewportPointToRay(point.X, point.Y)
		local ignore: { Instance } = {}
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		local map = mapModel()
		local mine = map and map:FindFirstChild("HiderThings")
		if mine then
			table.insert(ignore, mine)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		local prop = if result then propOf(result.Instance) else nil
		return if prop and inRange(prop, root) then prop else nil
	end
	local function nearest(): Instance?
		local root = myRoot()
		local map = mapModel()
		if not root or not map then
			return nil
		end
		local best: Instance? = nil
		local bestDistance = cfg.Disguise.Range
		for _, prop in CollectionService:GetTagged(Tags.PropHuntProp) do
			if prop:IsDescendantOf(map) then
				local at = pivotOf(prop)
				local distance = if at then (at - root.Position).Magnitude else math.huge
				if distance <= bestDistance then
					best = prop
					bestDistance = distance
				end
			end
		end
		return best
	end
	local function setTarget(prop: Instance?)
		target = prop
		local show = prop ~= nil and hiding()
		outline.Adornee = if show then prop else nil
		outline.Parent = if show then workspace.CurrentCamera else nil
		outline.Enabled = show
		targetTag.Enabled = show
		if show and prop then
			targetTag.Adornee = if prop:IsA("Model")
				then (prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true))
				elseif prop:IsA("BasePart") then prop
				else nil
			local key = if touch then "" else " " .. text.BecomeKey
			targetText.Text = text.BecomeTarget:format(label(prop:GetAttribute("PropName"))) .. key
		end
	end
	local function lookForTarget()
		if not hiding() then
			if target then
				setTarget(nil)
			end
			return
		end
		local pointed: Instance? = nil
		if UserInputService.MouseEnabled and not touch then
			pointed = propAt(UserInputService:GetMouseLocation())
		end
		local prop = pointed or nearest()
		if prop ~= target or (prop ~= nil and not outline.Enabled) then
			setTarget(prop)
		end
	end

	-- Actions ----------------------------------------------------------------------------------
	local function send(action: string, argument: any)
		local remote = actionRemote
		if remote and hiding() then
			remote:FireServer(action, argument)
		end
	end
	local function doBecome(prop: Instance?)
		if not hiding() then
			return
		end
		local released = ReplicatedStorage:GetAttribute("State") == "Playing"
		if released and number(player:GetAttribute("PropChangesLeft")) <= 0 then
			showFeed(text.NoChanges, Theme.Muted)
			return
		end
		local chosen = prop or target
		if not chosen then
			showFeed(text.NothingNear, Theme.Muted)
			return
		end
		send("Become", chosen)
		if ScreenFx.On() then
			UIMotion.Bump(become)
		end
	end
	local function doLock()
		send("Lock", player:GetAttribute("PropLocked") ~= true)
	end
	local function doTaunt()
		local readyAt = number(player:GetAttribute("PropTauntReadyAt"))
		if workspace:GetServerTimeNow() < readyAt then
			return
		end
		send("Taunt", nil)
		if ScreenFx.On() then
			UIMotion.Bump(taunt)
		end
	end
	become.Activated:Connect(function()
		doBecome(nil)
	end)
	lock.Activated:Connect(doLock)
	taunt.Activated:Connect(doTaunt)
	fire.Activated:Connect(function()
		PropHuntCannon.Fire()
	end)
	-- Tapping a thing (phones) turns you into it.
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if processedByUI or not hiding() then
			return
		end
		local prop = propAt(position)
		if prop then
			doBecome(prop)
		end
	end)

	local bound = false
	local function bindKeys(on: boolean)
		if on == bound then
			return
		end
		bound = on
		if on then
			local function handler(fn: () -> ())
				return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
					if state == Enum.UserInputState.Begin then
						fn()
					end
					return Enum.ContextActionResult.Sink
				end
			end
			ContextActionService:BindAction(
				ACTIONS.Become,
				handler(function()
					doBecome(nil)
				end),
				false,
				table.unpack(cfg.Keys.Become)
			)
			ContextActionService:BindAction(
				ACTIONS.Lock,
				handler(doLock),
				false,
				table.unpack(cfg.Keys.Lock)
			)
			ContextActionService:BindAction(
				ACTIONS.Taunt,
				handler(doTaunt),
				false,
				table.unpack(cfg.Keys.Taunt)
			)
		else
			for _, name in ACTIONS do
				ContextActionService:UnbindAction(name)
			end
		end
	end

	-- Chat bubbles: off on this screen while a round is on, back as they were afterwards.
	local bubblesHidden = false
	local bubblesBefore = true
	local function hideBubbles(hide: boolean)
		if hide == bubblesHidden or (hide and not cfg.HideChatBubbles) then
			return
		end
		local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if not bubbles then
			return
		end
		local ok = pcall(function()
			if hide then
				bubblesBefore = bubbles.Enabled
				bubbles.Enabled = false
			else
				bubbles.Enabled = bubblesBefore
			end
		end)
		if ok then
			bubblesHidden = hide
		end
	end

	-- Refreshing ---------------------------------------------------------------------------------
	local lastCount: number? = nil
	local function refresh()
		local on = roundOn()
		local role = myRole()
		local state = ReplicatedStorage:GetAttribute("State")
		hideBubbles(on)

		local blindfolded = on and state == "Hiding" and role == "Seeker"
		blindGui.Enabled = blindfolded
		if blindfolded then
			local n = number(ReplicatedStorage:GetAttribute("TimeLeft"))
			counting.Text = text.Counting:format(n)
			if n ~= lastCount then
				lastCount = n
				ScreenFx.Punch(counting, motion.CountPulseScale, motion.CountPulseSeconds)
			end
		end

		local isHider = on and role == "Hider"
		become.Visible = isHider
		lock.Visible = isHider and cfg.Lock.Enabled
		taunt.Visible = isHider
		fire.Visible = on and role == "Seeker" and touch and state == "Playing"
		bindKeys(isHider)
		lock.Text = if player:GetAttribute("PropLocked") == true
			then text.UnlockButton
			else text.LockButton
		if not isHider and target then
			setTarget(nil)
		end

		local watching = on and (role ~= nil or spectating())
		status.Visible = watching
		if watching then
			local parts = {}
			if role == "Hider" or role == "Seeker" then
				local color = if role == "Hider" then colors.Hider else colors.Seeker
				local name = if role == "Hider" then text.TeamHider else text.TeamSeeker
				table.insert(
					parts,
					('<font color="#%s">%s</font>'):format(color:ToHex(), string.upper(name))
				)
			end
			table.insert(
				parts,
				text.HidersLeft:format(number(ReplicatedStorage:GetAttribute("PropHidersLeft")))
			)
			table.insert(
				parts,
				text.Finders:format(number(ReplicatedStorage:GetAttribute("PropFinderCount")))
			)
			if role == "Seeker" and number(player:GetAttribute("PropFinds")) > 0 then
				table.insert(parts, text.YourFinds:format(number(player:GetAttribute("PropFinds"))))
			elseif role == "Hider" and state == "Playing" then
				table.insert(
					parts,
					text.ChangesLeft:format(number(player:GetAttribute("PropChangesLeft")))
				)
			end
			statusText.Text = table.concat(parts, "  |  ")
		end
		if not on then
			feed.Visible = false
		end
	end

	-- The role banner when your role changes (round start, found, promoted).
	local lastRole: string? = myRole()
	local function onRole()
		local role = myRole()
		local previous = lastRole
		lastRole = role
		refresh()
		if not inMode() or role == previous then
			return
		end
		if os.clock() - foundAt < motion.FoundBannerSeconds then
			return
		end
		if role == "Hider" then
			showBanner(text.HiderRole, colors.Hider, text.HiderTip)
		elseif role == "Seeker" then
			showBanner(text.SeekerRole, colors.Seeker, text.SeekerTip)
		elseif role == "Out" then
			showBanner(text.FoundGhost, colors.Hider)
		end
	end

	-- Server events ----------------------------------------------------------------------------
	local function involved(): boolean
		return myRole() ~= nil or spectating()
	end
	local function nameOf(who: unknown): string
		if typeof(who) == "Instance" and who:IsA("Player") then
			return who.DisplayName
		end
		return "?"
	end
	local function onEvent(kind: unknown, data: unknown)
		if typeof(kind) ~= "string" or typeof(data) ~= "table" then
			return
		end
		local info = data :: { [string]: any }
		PropHuntCannon.OnEvent(kind, info)
		if not inMode() then
			return
		end
		if kind == "Found" then
			if info.Hider == player then
				foundAt = os.clock()
				showBanner(
					if cfg.FoundBecomeFinders then text.FoundYou else text.FoundGhost,
					colors.Seeker,
					nil,
					motion.FoundBannerSeconds + 1
				)
			elseif info.Seeker == player then
				showBanner(text.Found, colors.Found, nil, 1.5, true)
			end
			if involved() then
				showFeed(text.FoundBy:format(nameOf(info.Seeker), nameOf(info.Hider)), colors.Found)
			end
		elseif kind == "Shot" then
			if info.Shooter == player and info.Result == "Prop" then
				showFeed(text.Decoy:format(label(info.Prop)), Theme.Muted)
			end
		elseif kind == "Became" then
			if info.Hider == player then
				showFeed(
					text.Became:format(label(player:GetAttribute("PropDisguise"))),
					colors.Hider
				)
			end
		elseif kind == "Released" then
			local role = myRole()
			if role == "Seeker" then
				showBanner(text.SeekerGo, colors.Seeker, nil, 2.5)
			elseif role == "Hider" then
				showFeed(text.Released, colors.Hider)
			end
		elseif kind == "Glow" then
			if involved() then
				showFeed(text.Glow, cfg.Effects.GlowColor, true)
			end
		end
	end

	-- The remotes only exist once the server has loaded the mode, so they are fetched the
	-- first time Mode is "PropHunt".
	local connected = false
	local function connect()
		if connected or not inMode() then
			return
		end
		connected = true
		task.spawn(function()
			spectate = require(script.Parent.Spectate) :: any
			local Remotes = require(ReplicatedStorage.Shared.Remotes)
			local events = Remotes.Event("PropHuntEvent")
			local shoot = Remotes.Event("PropHuntShoot")
			actionRemote = Remotes.Event("PropHuntAction")
			PropHuntCannon.Mount(shoot)
			events.OnClientEvent:Connect(onEvent)
		end)
	end

	for _, name in { "Mode", "State", "TimeLeft", "PropHidersLeft", "PropFinderCount" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(connect)
	player:GetAttributeChangedSignal("HideSeekRole"):Connect(onRole)
	for _, name in { "PropFinds", "PropChangesLeft", "PropLocked" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	connect()
	refresh()

	-- While a hider: look for the thing you'd become and show the taunt cooldown. Spectating
	-- from the lobby has no event, so the status is refreshed now and then too.
	task.spawn(function()
		local sinceRefresh = 0
		while true do
			task.wait(if inMode() then TARGET_EVERY else 1)
			if not inMode() then
				if target then
					setTarget(nil)
				end
				continue
			end
			lookForTarget()
			if taunt.Visible then
				local left = number(player:GetAttribute("PropTauntReadyAt"))
					- workspace:GetServerTimeNow()
				tauntShade.Visible = left > 0
				if left > 0 then
					tauntShade.Text = tostring(math.ceil(left))
				end
			end
			sinceRefresh += TARGET_EVERY
			if sinceRefresh >= 1 then
				sinceRefresh = 0
				refresh()
			end
		end
	end)
end

return PropHuntUI
