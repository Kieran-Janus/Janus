--!strict
--[[
	Small shared animations for the UI (settings in Config.UI.Motion; On = false makes every
	one of them instant). Required by other modules; it has no Mount.

	UIMotion.PopIn(gui, delay?)        shows `gui` and grows it from small to full size
	UIMotion.PopOut(gui, onDone?)      shrinks it, then hides it (Visible = false) and calls onDone
	UIMotion.Press(button)             a squash while pressed, a little grow under the mouse (PC
	                                   only, never on touch). Safe to call twice.
	UIMotion.Bump(gui)                 a quick pulse to draw the eye
	UIMotion.Wobble(gui)               a short tilt left and right (Rotation, ends at 0)
	UIMotion.CountTo(label, from, to, format?)
	                                   rolls the number shown in `label` from `from` to `to`
	                                   (format turns a number into the text; default 1,234)
	UIMotion.FloatText(parent, text, color, distance?) -> TextLabel?
	                                   "+50" drifting up (or down, with a negative distance) and
	                                   fading, then removed
	UIMotion.Ghost(panel, into)        a short-lived copy of a panel that has just been hidden,
	                                   shrinking away inside `into` (used by PanelManager)
	UIMotion.Enabled() -> boolean      Config.UI.Motion.On

	Sizes go through a UIScale, never the gui's own Size or Position (layout code owns those).
	A gui sized by Layout.Fit already has a UIScale (FitScale): that one is asked through the
	attribute MotionScale instead (Layout multiplies it in). A gui with some other UIScale of its
	own (e.g. a crate card's) is left alone. Every call cancels the gui's previous animation, and
	an interrupted animation never leaves a gui hidden or tiny: PopIn always ends visible at full
	size, PopOut always ends hidden at full size (ready for the next PopIn).
	Tweens only, no per-frame loops.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local UIMotion = {}

local SCALE_NAME = "MotionScale"

type Channel = {
	Gui: GuiObject,
	Attr: boolean, -- true: Layout.Fit's FitScale, asked through the MotionScale attribute
	Scale: UIScale?, -- our own UIScale (made the first time it isn't 1)
	Base: number, -- the scale that counts as "normal" (1, or a ghost's copied fit)
	Value: NumberValue, -- the motion factor the tweens move (1 = normal)
	Tween: Tween?,
	Token: number,
}

local channels: { [GuiObject]: Channel } = setmetatable({}, { __mode = "k" }) :: any
local pressed: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
type Counter = { Value: NumberValue, Tween: Tween?, Token: number }
local counters: { [TextLabel]: Counter } = setmetatable({}, { __mode = "k" }) :: any

local function cfg()
	return Config.UI.Motion
end

function UIMotion.Enabled(): boolean
	return cfg().On == true
end

local function write(channel: Channel)
	local factor = channel.Value.Value
	if channel.Attr then
		local want: number? = if math.abs(factor - 1) < 1e-4 then nil else factor
		if channel.Gui:GetAttribute("MotionScale") ~= want then
			channel.Gui:SetAttribute("MotionScale", want)
		end
		return
	end
	local scale = channel.Scale
	if not scale then
		if math.abs(factor - 1) < 1e-4 and channel.Base == 1 then
			return -- nothing to show yet: don't add a UIScale to every button up front
		end
		local made = Instance.new("UIScale")
		made.Name = SCALE_NAME
		made.Parent = channel.Gui
		channel.Scale = made
		scale = made
	end
	assert(scale, "a scale was just made")
	scale.Scale = channel.Base * factor
end

-- The gui's motion channel, or nil when it has a UIScale of its own we must not fight.
local function channelOf(gui: GuiObject, base: UIScale?): Channel?
	local existing = channels[gui]
	if existing then
		return existing
	end
	local attr = false
	local own: UIScale? = nil
	local baseValue = 1
	if base then
		-- A ghost copy: its copied scale becomes ours, its value the normal size.
		own = base
		baseValue = base.Scale
		base.Name = SCALE_NAME
	else
		local fit = gui:FindFirstChild("FitScale")
		if fit and fit:IsA("UIScale") then
			attr = true
		else
			local other = gui:FindFirstChildOfClass("UIScale")
			if other and other.Name ~= SCALE_NAME then
				return nil
			end
			own = other
		end
	end
	local value = Instance.new("NumberValue")
	value.Value = 1
	local channel: Channel = {
		Gui = gui,
		Attr = attr,
		Scale = own,
		Base = baseValue,
		Value = value,
		Tween = nil,
		Token = 0,
	}
	value:GetPropertyChangedSignal("Value"):Connect(function()
		write(channel)
	end)
	channels[gui] = channel
	gui.Destroying:Once(function()
		channels[gui] = nil
		value:Destroy()
	end)
	return channel
end

local function stop(channel: Channel)
	channel.Token += 1
	local tween = channel.Tween
	channel.Tween = nil
	if tween then
		tween:Cancel()
	end
end

local function setFactor(channel: Channel, factor: number)
	if channel.Value.Value ~= factor then
		channel.Value.Value = factor
	else
		write(channel)
	end
end

-- Moves the channel's factor to `target`; `final` is set when it ends (after reversing tweens),
-- then onDone runs. Without motion it all happens at once.
local function animate(
	channel: Channel,
	target: number,
	info: TweenInfo,
	final: number,
	onDone: (() -> ())?
)
	stop(channel)
	if not UIMotion.Enabled() or info.Time <= 0 then
		setFactor(channel, final)
		if onDone then
			onDone()
		end
		return
	end
	local token = channel.Token
	local tween = TweenService:Create(channel.Value, info, { Value = target })
	channel.Tween = tween
	tween.Completed:Connect(function(state)
		if channel.Token ~= token then
			return -- cancelled by a newer animation (it decides how this ends)
		end
		channel.Tween = nil
		tween:Destroy()
		if state ~= Enum.PlaybackState.Completed then
			return
		end
		setFactor(channel, final)
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

function UIMotion.PopIn(gui: GuiObject, delay: number?)
	if not gui.Visible then
		gui.Visible = true
	end
	local channel = channelOf(gui)
	if not channel then
		return
	end
	local c = cfg()
	if not UIMotion.Enabled() then
		stop(channel)
		setFactor(channel, 1)
		return
	end
	stop(channel)
	setFactor(channel, c.PopFrom)
	animate(
		channel,
		1,
		TweenInfo.new(
			c.PopInSeconds,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		1
	)
end

function UIMotion.PopOut(gui: GuiObject, onDone: (() -> ())?)
	local channel = channelOf(gui)
	local function finish()
		gui.Visible = false
		if onDone then
			onDone()
		end
	end
	if not channel then
		finish()
		return
	end
	local c = cfg()
	animate(
		channel,
		c.PopOutTo,
		TweenInfo.new(c.PopOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		1,
		function()
			-- (setFactor ran first: hidden at full size, ready to pop in again)
			finish()
		end
	)
end

function UIMotion.Bump(gui: GuiObject)
	local channel = channelOf(gui)
	if not channel then
		return
	end
	local c = cfg()
	animate(
		channel,
		c.BumpScale,
		TweenInfo.new(c.BumpSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
		1
	)
end

function UIMotion.Wobble(gui: GuiObject)
	local c = cfg()
	if not UIMotion.Enabled() or c.WobbleTimes <= 0 then
		return
	end
	local start = gui.Rotation
	gui.Rotation = start - c.WobbleAngle / 2
	local tween = TweenService:Create(
		gui,
		TweenInfo.new(
			c.WobbleSeconds,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			c.WobbleTimes - 1, -- each pass tilts one way and back
			true
		),
		{ Rotation = start + c.WobbleAngle / 2 }
	)
	tween.Completed:Connect(function()
		gui.Rotation = start -- always back straight, even if cancelled
		tween:Destroy()
	end)
	tween:Play()
end

-- The pointer is a mouse (PC), not a finger: only then does a button grow under it.
local function canHover(): boolean
	return UserInputService.MouseEnabled and not UserInputService.TouchEnabled
end

local function isPress(input: InputObject): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

function UIMotion.Press(button: GuiButton)
	if pressed[button] then
		return
	end
	pressed[button] = true
	local hovering = false
	local holding = false
	local function settle()
		local channel = channelOf(button)
		if not channel then
			return
		end
		local c = cfg()
		local target = if holding then c.PressScale elseif hovering then c.HoverScale else 1
		local seconds = if holding then c.PressSeconds else c.HoverSeconds
		animate(
			channel,
			target,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			target
		)
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			holding = true
			settle()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) and holding then
			holding = false
			settle()
		end
	end)
	button.MouseEnter:Connect(function()
		if canHover() then
			hovering = true
			settle()
		end
	end)
	button.MouseLeave:Connect(function()
		if hovering or holding then
			hovering = false
			holding = false
			settle()
		end
	end)
end

-- 1234567 -> "1,234,567"
function UIMotion.Commas(n: number): string
	local text = tostring(math.round(math.abs(n)))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if n < 0 then "-" .. out else out
end

function UIMotion.CountTo(label: TextLabel, from: number, to: number, format: ((number) -> string)?)
	local show = format or UIMotion.Commas
	local counter = counters[label]
	if not counter then
		local value = Instance.new("NumberValue")
		local made: Counter = { Value = value, Tween = nil, Token = 0 }
		value:GetPropertyChangedSignal("Value"):Connect(function()
			if made.Tween then
				label.Text = show(math.round(value.Value))
			end
		end)
		counters[label] = made
		label.Destroying:Once(function()
			counters[label] = nil
			value:Destroy()
		end)
		counter = made
	end
	assert(counter, "a counter was just made")
	counter.Token += 1
	local token = counter.Token
	local old = counter.Tween
	counter.Tween = nil
	if old then
		old:Cancel()
	end
	local seconds = cfg().CountSeconds
	if not UIMotion.Enabled() or seconds <= 0 or from == to then
		label.Text = show(to)
		return
	end
	counter.Value.Value = from
	label.Text = show(from)
	local tween = TweenService:Create(
		counter.Value,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = to }
	)
	counter.Tween = tween
	tween.Completed:Connect(function()
		tween:Destroy()
		if counter.Token ~= token then
			return
		end
		counter.Tween = nil
		label.Text = show(to) -- exactly the target, whatever the rounding on the way
	end)
	tween:Play()
end

function UIMotion.FloatText(
	parent: GuiObject,
	text: string,
	color: Color3,
	distance: number?
): TextLabel?
	local c = cfg()
	if not UIMotion.Enabled() then
		return nil
	end
	local rise = distance or c.FloatDistance
	local label = Instance.new("TextLabel")
	label.Name = "FloatText"
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 20
	label.TextStrokeTransparency = 0.3
	label.ZIndex = parent.ZIndex + 5
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(120, 26)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Parent = parent
	local tween = TweenService:Create(
		label,
		TweenInfo.new(c.FloatSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, 0.5, -rise),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween.Completed:Connect(function()
		tween:Destroy()
		label:Destroy()
	end)
	tween:Play()
	return label
end

-- How many instances a panel has, stopping once past `limit`.
local function bigger(panel: Instance, limit: number): boolean
	local count = 0
	local stack = { panel }
	while #stack > 0 do
		local item = table.remove(stack) :: Instance
		for _, child in item:GetChildren() do
			count += 1
			if count > limit then
				return true
			end
			table.insert(stack, child)
		end
	end
	return false
end

function UIMotion.Ghost(panel: GuiObject, into: Instance): GuiObject?
	if not UIMotion.Enabled() or bigger(panel, cfg().GhostMaxParts) then
		return nil
	end
	local ok, copy = pcall(function()
		return panel:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local ghost = copy :: GuiObject
	ghost.Name = "PanelGhost"
	ghost:SetAttribute("MotionScale", nil)
	ghost:SetAttribute("PanelGhost", true)
	ghost.Active = false
	local fit = ghost:FindFirstChild("FitScale")
	local scale: UIScale? = nil
	if fit and fit:IsA("UIScale") then
		scale = fit
	else
		local other = ghost:FindFirstChildOfClass("UIScale")
		if other then
			scale = other
		end
	end
	if not scale then
		local made = Instance.new("UIScale")
		scale = made
		made.Parent = ghost
	end
	assert(scale, "a scale was just made")
	ghost.Visible = true
	ghost.Parent = into
	channelOf(ghost, scale)
	UIMotion.PopOut(ghost, function()
		ghost:Destroy()
	end)
	return ghost
end

return UIMotion
