--!strict
--[[
	Watching the round from the lobby (settings: Config.Lobby.Spectate, on/off:
	Config.Features.LobbySpectate). While a round is being played and you're not in it, Menu >
	Spectate (or the "Watch the round" button at the bottom) puts your camera on the players
	still in the round (and the Pumpkin King in King Hunt). A small bar at the bottom shows who
	you're watching with Back / Next / Stop; E/Q, the arrow keys or the gamepad shoulder
	buttons switch too (Config.Lobby.Spectate keys). It stops by itself when the round ends.
	You stay in the lobby the whole time (you can still walk around). Who can be watched comes
	from src/client/SpectateTargets.luau, shared with the ghost screen.
	Motion (Config.ScreenMotion.Spectate): the bar slides up, a new name fades in, buttons
	squash when pressed. Looks only: Back / Next / Stop act at once.

	Spectate.Mount(gui)
	Spectate.Toggle()             start watching, or stop if already watching
	Spectate.Stop()               camera back to your own character
	Spectate.IsActive() -> boolean
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local ScreenFx = require(script.Parent.ScreenFx)
local SpectateTargets = require(script.Parent.SpectateTargets)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local Spectate = {}

local ACTION_NEXT = "SpectateNext"
local ACTION_PREVIOUS = "SpectatePrevious"
local STREAM_EVERY = 3 -- seconds between "stream the map to me" reminders while watching
-- The bar on phones: narrow enough to fit between the thumbstick and the jump button at full
-- size (a wider bar would shrink and its text with it).
local PHONE_WIDTH = 300
local PHONE_HEIGHT = 88
local BAR_HOME = UDim2.new(0.5, 0, 1, -24) -- where the bar sits (it slides up into place)

local active = false
local mounted = false
local target: Instance? = nil
local showingMessage = false -- the bar is up only to show a short message
local messageToken = 0 -- counts messages, so an old one's timer can't hide a newer one

-- Set in Mount.
local bar: Frame? = nil
local twoRows = false -- phones: the name on its own line above the buttons
local watchButton: TextButton? = nil
local nameLabel: TextLabel? = nil
local controls: { GuiObject } = {}

-- You can watch while a round is being played that you're not in.
local function canWatch(): boolean
	return ReplicatedStorage:GetAttribute("State") == "Playing"
		and Players.LocalPlayer:GetAttribute("InRound") ~= true
end

-- A new name fades in (the words change at once).
local function setName(text: string)
	local label = nameLabel
	if label and label.Text ~= text then
		label.Text = text
		local motion = Config.ScreenMotion.Spectate
		ScreenFx.FadeText(label, motion.NameFadeFrom, motion.NameFadeSeconds)
	end
end

local function describe(t: Instance?): string
	local text = Config.Lobby.Spectate.Text
	if not t then
		return text.NobodyLeft
	elseif SpectateTargets.IsKing(t) then
		return text.King
	end
	return text.Watching:format(SpectateTargets.Name(t))
end

local function step(direction: number)
	if not active then
		return
	end
	target = SpectateTargets.Step(target, direction)
	setName(describe(target))
	if not target then
		SpectateTargets.RestoreCamera()
	end
end

local function refreshVisibility()
	local cfg = Config.Lobby.Spectate
	if bar then
		local show = active or showingMessage
		if show and not bar.Visible then
			bar.Visible = true
			local motion = Config.ScreenMotion.Spectate
			ScreenFx.Slide(bar, BAR_HOME, Vector2.new(0, motion.SlideDistance), motion.SlideSeconds)
		end
		bar.Visible = show
		if twoRows then
			-- Just the name line while it only shows a message.
			bar.Size = UDim2.fromOffset(PHONE_WIDTH, if active then PHONE_HEIGHT else 44)
		end
	end
	for _, control in controls do
		control.Visible = active
	end
	if watchButton then
		watchButton.Visible = cfg.ShowWatchButton
			and not active
			and canWatch()
			and not showingMessage
	end
end

local function bindKeys()
	local cfg = Config.Lobby.Spectate
	local function handler(direction: number)
		return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				step(direction)
			end
			return Enum.ContextActionResult.Sink
		end
	end
	ContextActionService:BindActionAtPriority(
		ACTION_NEXT,
		handler(1),
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(cfg.NextKeys)
	)
	ContextActionService:BindActionAtPriority(
		ACTION_PREVIOUS,
		handler(-1),
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(cfg.PreviousKeys)
	)
end

local function unbindKeys()
	ContextActionService:UnbindAction(ACTION_NEXT)
	ContextActionService:UnbindAction(ACTION_PREVIOUS)
end

-- Shows a short message in the bar (e.g. nobody is playing), then hides it.
local function flash(text: string)
	messageToken += 1
	local token = messageToken
	showingMessage = true
	setName(text)
	refreshVisibility()
	task.delay(Config.Lobby.Spectate.MessageSeconds, function()
		if token == messageToken then
			showingMessage = false
			refreshVisibility()
		end
	end)
end

function Spectate.Stop()
	if active then
		active = false
		target = nil
		unbindKeys()
		SpectateTargets.RestoreCamera()
		SpectateTargets.StreamMap(false)
	end
	refreshVisibility()
end

local function start()
	if not mounted or active then
		return
	end
	if not canWatch() then
		flash(Config.Lobby.Spectate.Text.Nobody)
		return
	end
	messageToken += 1 -- cancels a message still showing
	showingMessage = false
	active = true
	target = nil
	SpectateTargets.StreamMap(true)
	bindKeys()
	step(1)
	refreshVisibility()
end

function Spectate.Toggle()
	if not Config.Features.LobbySpectate then
		return
	end
	if active then
		Spectate.Stop()
	else
		start()
	end
end

function Spectate.IsActive(): boolean
	return active
end

local function button(text: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Button
	b.TextColor3 = Theme.Text
	b.Font = Theme.Font
	b.TextSize = 16
	b.Text = text
	b.Parent = parent
	Theme.round(b, 8)
	if ScreenFx.On() then
		UIMotion.Press(b) -- squashes when pressed (the click itself is never held up)
	end
	return b
end

function Spectate.Mount(gui: ScreenGui)
	if not Config.Features.LobbySpectate or mounted then
		return
	end
	mounted = true
	local cfg = Config.Lobby.Spectate
	local player = Players.LocalPlayer

	-- The bar: [< Back] Watching Name [Next >] [Stop]. On phones the name goes on its own
	-- line above the three buttons.
	twoRows = Layout.IsPhone()
	local buttonsTop = if twoRows then 44 else 8
	local panel = Theme.panel(gui)
	panel.Name = "SpectateBar"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = BAR_HOME
	panel.Size = if twoRows
		then UDim2.fromOffset(PHONE_WIDTH, PHONE_HEIGHT)
		else UDim2.fromOffset(520, 52)
	panel.Visible = false
	Layout.Fit(panel, true)
	bar = panel

	-- On a keyboard the buttons show their first key, e.g. "< Back (Q)".
	local keyHints = not Layout.IsTouch()
	local previousKey: Enum.KeyCode? = cfg.PreviousKeys[1]
	local nextKey: Enum.KeyCode? = cfg.NextKeys[1]
	local previous = button(
		if keyHints and previousKey
			then ("< %s (%s)"):format(cfg.Text.Previous, previousKey.Name)
			else "< " .. cfg.Text.Previous,
		panel
	)
	previous.Name = "Previous"
	previous.Position = UDim2.fromOffset(8, buttonsTop)
	previous.Size = UDim2.fromOffset(92, 36)

	local label = Theme.label("", 16, panel)
	label.Name = "Watching"
	if twoRows then
		label.Position = UDim2.fromOffset(8, 6)
		label.Size = UDim2.new(1, -16, 0, 32)
	else
		label.Position = UDim2.fromOffset(106, 8)
		label.Size = UDim2.new(1, -106 - 198, 0, 36)
	end
	label.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel = label

	local nextButton = button(
		if keyHints and nextKey
			then ("%s (%s) >"):format(cfg.Text.Next, nextKey.Name)
			else cfg.Text.Next .. " >",
		panel
	)
	nextButton.Name = "Next"
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.new(1, -100, 0, buttonsTop)
	nextButton.Size = UDim2.fromOffset(92, 36)

	local stop = button(cfg.Text.Stop, panel)
	stop.Name = "Stop"
	stop.AnchorPoint = Vector2.new(1, 0)
	stop.Position = UDim2.new(1, -8, 0, buttonsTop)
	stop.Size = UDim2.fromOffset(84, 36)
	stop.BackgroundColor3 = Theme.Selected

	controls = { previous, nextButton, stop }
	previous.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)
	stop.Activated:Connect(Spectate.Stop)

	-- "Watch the round": shown in the lobby while a round is on.
	local watch = button(cfg.Text.WatchButton, gui)
	watch.Name = "WatchRound"
	watch.AnchorPoint = Vector2.new(0.5, 1)
	watch.Position = UDim2.new(0.5, 0, 1, -24)
	watch.Size = UDim2.fromOffset(190, 40)
	watch.BackgroundColor3 = Theme.Background
	watch.BackgroundTransparency = 0.15
	watch.Visible = false
	Layout.Fit(watch, true)
	watch.Activated:Connect(start)
	watchButton = watch

	-- Stop when the round ends or you join one; show/hide the Watch button.
	local function onRoundChange()
		if active and not canWatch() then
			Spectate.Stop()
		end
		refreshVisibility()
	end
	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(onRoundChange)
	player:GetAttributeChangedSignal("InRound"):Connect(onRoundChange)

	-- Keep the camera on the target; move on when they're caught or leave.
	local lastStream = 0
	local nextLook = 0 -- when nobody is watchable, look again at most this often
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local now = os.clock()
		if not SpectateTargets.Watchable(target) and now >= nextLook then
			step(1)
			nextLook = if target then 0 else now + 0.5
		end
		SpectateTargets.Follow(target)
		if now - lastStream >= STREAM_EVERY then
			lastStream = now
			SpectateTargets.StreamMap(true)
		end
	end)
	refreshVisibility()
end

return Spectate
