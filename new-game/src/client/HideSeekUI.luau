--!strict
--[[
	Pumpkin Hide & Seek screen (settings and words: Config.HideSeek). Shows only while the
	ReplicatedStorage attribute Mode is "HideSeek":
	  - a big role banner: "You're a PUMPKIN - hide!" / "You're a SEEKER - find the pumpkins!"
	    (and "You were found!" when a candy gets you)
	  - the seekers' blindfold while the hiders hide (State "Hiding"): "COUNTING... 15"
	  - a bar under the top Hud: your role, pumpkins left, seekers, your tags
	  - a short message line: who found whom, "The pumpkins are glowing!", decoy misses
	The candy gun's aiming, crosshair and world effects are in src/client/CandyGunClient.luau,
	mounted from here once the first Hide & Seek round starts.
	On/off: Config.Features.HideSeek (off = Mount does nothing and nothing shows).

	Reads: ReplicatedStorage attributes Mode, State, TimeLeft, HidersLeft, SeekerCount and the
	player attributes HideSeekRole, HideSeekTags, InRound (set by src/server/Modes/HideSeek.luau).
	Remotes (fetched only once Mode is "HideSeek": the server makes them when it loads the mode):
	HideSeekEvent (server -> client), HideSeekShoot (client -> server, used by CandyGunClient).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CandyGunClient = require(script.Parent.CandyGunClient)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local HideSeekUI = {}

local MODE = "HideSeek"
local BANNER_SECONDS = 4
local FEED_SECONDS = 3.5
local FOUND_BANNER_SECONDS = 2.5 -- after "You were found!", don't replace it with the role banner

local function inMode(): boolean
	return ReplicatedStorage:GetAttribute("Mode") == MODE
end

-- Spectate needs the server's remotes, so it is only loaded once a Hide & Seek round is on.
local spectate: any = nil
local function spectating(): boolean
	return spectate ~= nil and spectate.IsActive() == true
end

local function roundOn(): boolean
	local state = ReplicatedStorage:GetAttribute("State")
	return inMode() and (state == "Hiding" or state == "Playing")
end

function HideSeekUI.Mount(gui: ScreenGui)
	if not Config.Features.HideSeek then
		return
	end
	local cfg = Config.HideSeek
	local text = cfg.Text
	local player = Players.LocalPlayer

	-- Big banner ---------------------------------------------------------------------------------
	local banner = Theme.label("", 56, gui)
	banner.Name = "HideSeekBanner"
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
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner

	local tip = Theme.label("", 20, gui)
	tip.Name = "HideSeekTip"
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 0.27, 6)
	tip.Size = UDim2.fromOffset(560, 28)
	tip.TextWrapped = true
	tip.TextStrokeTransparency = 0.3
	tip.Visible = false
	tip.ZIndex = 12
	Layout.Fit(tip)
	-- On short phone screens the banner and tip move down together, clear of the top bar.
	Layout.KeepBelowHud({ banner, tip })

	local bannerToken = 0
	local foundAt = -math.huge
	local function showBanner(message: string, color: Color3, tipText: string?, seconds: number?)
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
		bannerScale.Scale = 1.5
		TweenService:Create(
			bannerScale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		task.delay(seconds or BANNER_SECONDS, function()
			if token ~= bannerToken then
				return
			end
			local fade = TweenInfo.new(0.4)
			TweenService:Create(banner, fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
			TweenService:Create(tip, fade, { TextTransparency = 1 }):Play()
			task.wait(0.45)
			if token == bannerToken then
				banner.Visible = false
				tip.Visible = false
			end
		end)
	end

	-- Status bar under the Hud ---------------------------------------------------------------------
	local status = Theme.panel(gui)
	status.Name = "HideSeekStatus"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0.02, 72)
	status.Size = UDim2.fromOffset(440, 34)
	status.Visible = false
	Layout.Fit(status)
	local statusText = Theme.label("", 17, status)
	statusText.Size = UDim2.new(1, -16, 1, 0)
	statusText.Position = UDim2.fromOffset(8, 0)
	statusText.RichText = true
	statusText.TextTruncate = Enum.TextTruncate.AtEnd

	-- Message line under it
	local feed = Theme.label("", 18, gui)
	feed.Name = "HideSeekFeed"
	feed.AnchorPoint = Vector2.new(0.5, 0)
	feed.Position = UDim2.new(0.5, 0, 0.02, 112)
	feed.Size = UDim2.fromOffset(460, 28)
	feed.TextStrokeTransparency = 0.3
	feed.Visible = false
	Layout.Fit(feed)
	local feedToken = 0
	local function showFeed(message: string, color: Color3?)
		feedToken += 1
		local token = feedToken
		feed.Text = message
		feed.TextColor3 = color or Theme.Text
		feed.Visible = true
		task.delay(FEED_SECONDS, function()
			if token == feedToken then
				feed.Visible = false
			end
		end)
	end

	-- Blindfold (its own screen, under the normal UI so the Hud and Menu stay usable) ----------
	local blindGui = Instance.new("ScreenGui")
	blindGui.Name = "HideSeekBlindfold"
	blindGui.ResetOnSpawn = false
	blindGui.IgnoreGuiInset = true
	blindGui.DisplayOrder = -1
	blindGui.Enabled = false
	blindGui.Parent = player:WaitForChild("PlayerGui")
	local blind = Instance.new("Frame")
	blind.Name = "Blindfold"
	blind.Size = UDim2.fromScale(1, 1)
	blind.BackgroundColor3 = cfg.Colors.Blindfold
	blind.BorderSizePixel = 0
	blind.Parent = blindGui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color =
		ColorSequence.new(cfg.Colors.Blindfold:Lerp(Color3.new(0, 0, 0), 0.5), cfg.Colors.Blindfold)
	gradient.Parent = blind
	local counting = Theme.label("", 72, blind)
	counting.Name = "Counting"
	counting.Font = Enum.Font.GothamBlack
	counting.AnchorPoint = Vector2.new(0.5, 0.5)
	counting.Position = UDim2.fromScale(0.5, 0.45)
	counting.Size = UDim2.fromScale(0.9, 0.16)
	counting.TextScaled = true
	counting.TextColor3 = cfg.Colors.Seeker
	counting.TextStrokeTransparency = 0.2
	local countingSize = Instance.new("UITextSizeConstraint")
	countingSize.MaxTextSize = 90
	countingSize.Parent = counting
	local countingScale = Instance.new("UIScale")
	countingScale.Parent = counting
	local peek = Theme.label(text.CountingTip, 22, blind)
	peek.Name = "Tip"
	peek.AnchorPoint = Vector2.new(0.5, 0)
	peek.Position = UDim2.fromScale(0.5, 0.56)
	peek.Size = UDim2.new(0.9, 0, 0, 30)
	peek.TextScaled = true
	peek.TextColor3 = Theme.Muted
	local peekSize = Instance.new("UITextSizeConstraint")
	peekSize.MaxTextSize = 24
	peekSize.Parent = peek

	-- Refreshing ---------------------------------------------------------------------------------
	local function myRole(): string?
		local role = player:GetAttribute("HideSeekRole")
		return if typeof(role) == "string" then role else nil
	end

	local lastCount: number? = nil
	local function refresh()
		local on = roundOn()
		local role = myRole()
		local state = ReplicatedStorage:GetAttribute("State")

		-- Blindfold with the head start's countdown.
		local blindfolded = on and state == "Hiding" and role == "Seeker"
		blindGui.Enabled = blindfolded
		if blindfolded then
			local left = ReplicatedStorage:GetAttribute("TimeLeft")
			local n = if typeof(left) == "number" then left else 0
			counting.Text = text.Counting:format(n)
			if n ~= lastCount then
				lastCount = n
				countingScale.Scale = 1.2
				TweenService:Create(countingScale, TweenInfo.new(0.3), { Scale = 1 }):Play()
			end
		end

		-- Status bar: players in the round, and anyone watching it from the lobby.
		local watching = on and (role ~= nil or spectating())
		status.Visible = watching
		if watching then
			local parts = {}
			if role == "Hider" or role == "Seeker" then
				local color = if role == "Hider" then cfg.Colors.Hider else cfg.Colors.Seeker
				local name = if role == "Hider" then text.TeamHider else text.TeamSeeker
				table.insert(
					parts,
					('<font color="#%s">%s</font>'):format(color:ToHex(), string.upper(name))
				)
			end
			local hiders = ReplicatedStorage:GetAttribute("HidersLeft")
			local seekers = ReplicatedStorage:GetAttribute("SeekerCount")
			table.insert(
				parts,
				text.HidersLeft:format(if typeof(hiders) == "number" then hiders else 0)
			)
			table.insert(
				parts,
				text.Seekers:format(if typeof(seekers) == "number" then seekers else 0)
			)
			local tags = player:GetAttribute("HideSeekTags")
			if role == "Seeker" and typeof(tags) == "number" and tags > 0 then
				table.insert(parts, text.YourTags:format(tags))
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
		if os.clock() - foundAt < FOUND_BANNER_SECONDS then
			return -- "You were found!" is showing
		end
		if role == "Hider" then
			showBanner(text.HiderRole, cfg.Colors.Hider, text.HiderTip:format(cfg.GiggleInterval))
		elseif role == "Seeker" then
			showBanner(text.SeekerRole, cfg.Colors.Seeker, text.SeekerTip)
		elseif role == "Out" then
			showBanner(text.FoundGhost, cfg.Colors.Hider)
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
		CandyGunClient.OnEvent(kind, info)
		if not inMode() then
			return
		end
		if kind == "Tagged" then
			if info.Hider == player then
				foundAt = os.clock()
				showBanner(
					if cfg.TaggedBecomeSeekers then text.FoundYou else text.FoundGhost,
					cfg.Colors.Seeker,
					nil,
					FOUND_BANNER_SECONDS + 1
				)
			elseif info.Seeker == player then
				showBanner(text.Tagged, cfg.Colors.Tagged, nil, 1.5)
			end
			if involved() then
				showFeed(
					text.TaggedBy:format(nameOf(info.Seeker), nameOf(info.Hider)),
					cfg.Colors.Tagged
				)
			end
		elseif kind == "Shot" then
			if info.Shooter == player and info.Result == "Decoy" then
				showFeed(text.Decoy, Theme.Muted)
			end
		elseif kind == "Released" then
			local role = myRole()
			if role == "Seeker" then
				showBanner(text.SeekerGo, cfg.Colors.Seeker, nil, 2.5)
				Sounds.PlaySpec(cfg.Sounds.Released :: any)
			elseif role == "Hider" then
				showFeed(text.Released, cfg.Colors.Hider)
				Sounds.PlaySpec(cfg.Sounds.Released :: any)
			end
		elseif kind == "Glow" then
			if involved() then
				showFeed(text.Glow, cfg.Effects.GlowColor)
			end
		end
	end

	-- The remotes only exist once the server has loaded the mode (it does that before it sets
	-- Mode), so they are fetched the first time Mode is "HideSeek".
	local connected = false
	local function connect()
		if connected or not inMode() then
			return
		end
		connected = true
		task.spawn(function()
			spectate = require(script.Parent.Spectate)
			local Remotes = require(ReplicatedStorage.Shared.Remotes)
			local events = Remotes.Event("HideSeekEvent")
			local shoot = Remotes.Event("HideSeekShoot")
			CandyGunClient.Mount(shoot)
			events.OnClientEvent:Connect(onEvent)
		end)
	end

	for _, name in { "Mode", "State", "TimeLeft", "HidersLeft", "SeekerCount" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(connect)
	player:GetAttributeChangedSignal("HideSeekRole"):Connect(onRole)
	player:GetAttributeChangedSignal("HideSeekTags"):Connect(refresh)
	connect()
	refresh()
	-- Spectating from the lobby has no event: check now and then.
	task.spawn(function()
		while true do
			task.wait(1)
			if inMode() then
				refresh()
			end
		end
	end)
end

return HideSeekUI
