--!strict
--[[
	Little celebrations for the lobby minigames (Candy Rush, Web Scour, secret pumpkins and the
	parkour courses). Settings: Config.Minigames.Effects (shared) and each game's own Effects
	table (its On switch and counts). Everything here is made on this computer only, is never
	solid, never waits for anything and cleans itself up when it is done, so a game can call
	it and carry straight on.

	MinigameFx.Enabled(own)                      -> Config.Minigames.Effects.On and own.On
	MinigameFx.Count(n)                          -> n, or fewer on phones (PhoneShare)
	MinigameFx.Burst(position, colors, count)    sparkles flying out of a point in the world
	MinigameFx.FloatText(parent, words, color, position)   "+1" that floats up and fades
	MinigameFx.Confetti(gui, count)              confetti falling over the screen
	MinigameFx.Punch(item, scale?, tilt?)        starts big (and tilted), settles to its size
	MinigameFx.PopFit(panel, from, seconds)      the same for a panel with Layout.Fit
	MinigameFx.CountUp(label, to, seconds, format)   counts a number up; ends on the exact one
	MinigameFx.Shine(frame, seconds, delay)      a light sweeps across a frame once
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local MinigameFx = {}

local shared = Config.Minigames.Effects

-- The folder the world sparkles go in (one per client, made when first needed).
local function worldFolder(): Folder
	local existing = workspace:FindFirstChild("MinigameFx")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "MinigameFx"
	folder.Parent = workspace
	return folder
end

function MinigameFx.Enabled(own: { On: boolean }?): boolean
	if not shared.On then
		return false
	end
	return own == nil or own.On == true
end

function MinigameFx.Count(n: number): number
	if n <= 0 then
		return 0
	end
	if Layout.IsPhone() then
		return math.max(1, math.floor(n * shared.PhoneShare + 0.5))
	end
	return math.floor(n + 0.5)
end

-- Sparkles flying out of `position` (count already chosen: pass it through Count first).
function MinigameFx.Burst(position: Vector3, colors: { Color3 }, count: number): BasePart?
	if count <= 0 then
		return nil
	end
	local b = shared.Burst
	local holder = Instance.new("Part")
	holder.Name = "Burst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	if #colors >= 2 then
		local keys = {}
		for i, color in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
		end
		emitter.Color = ColorSequence.new(keys)
	else
		emitter.Color = ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, b.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	emitter.Lifetime = NumberRange.new(b.Lifetime.Min, b.Lifetime.Max)
	emitter.Speed = NumberRange.new(b.Speed.Min, b.Speed.Max)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = worldFolder()
	emitter:Emit(count)
	task.delay(b.Lifetime.Max + 0.3, function()
		holder:Destroy()
	end)
	return holder
end

-- "+1" (or any words) that floats up from `position` inside `parent` and fades away.
function MinigameFx.FloatText(
	parent: GuiObject | ScreenGui,
	words: string,
	color: Color3,
	position: UDim2
): TextLabel
	local f = shared.FloatText
	local label = Instance.new("TextLabel")
	label.Name = "FxFloat"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(80, f.TextSize + 8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = words
	label.TextSize = math.max(f.TextSize, Config.UI.MinTextSize)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Active = false
	label.ZIndex = 20
	label.Parent = parent
	local rise = TweenService:Create(
		label,
		TweenInfo.new(f.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = position + UDim2.fromOffset(0, -f.Rise),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	rise.Completed:Once(function()
		label:Destroy()
	end)
	rise:Play()
	return label
end

-- Confetti falling over the whole screen (count already chosen: pass it through Count first).
function MinigameFx.Confetti(gui: ScreenGui | GuiObject, count: number): Frame?
	if count <= 0 then
		return nil
	end
	local c = shared.Confetti
	local layer = Instance.new("Frame")
	layer.Name = "FxConfetti"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Active = false
	layer.ZIndex = 30
	layer.ClipsDescendants = true
	layer.Parent = gui
	local rng = Random.new()
	local colors = c.Colors
	for i = 1, count do
		local piece = Instance.new("Frame")
		piece.Name = "Piece"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = colors[rng:NextInteger(1, math.max(#colors, 1))]
			or Color3.new(1, 1, 1)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(rng:NextInteger(6, 11), rng:NextInteger(10, 16))
		local x = rng:NextNumber(0.03, 0.97)
		piece.Position = UDim2.fromScale(x, -0.05)
		piece.Rotation = rng:NextNumber(0, 360)
		piece.ZIndex = 30
		piece.Active = false
		piece.Parent = layer
		local start = (i - 1) / math.max(count - 1, 1) * c.Spread
		local fall = TweenService:Create(
			piece,
			TweenInfo.new(
				c.Seconds * rng:NextNumber(0.8, 1.15),
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				start
			),
			{
				Position = UDim2.fromScale(x + rng:NextNumber(-0.12, 0.12), 1.05),
				Rotation = piece.Rotation + rng:NextNumber(-540, 540),
			}
		)
		fall:Play()
	end
	task.delay(c.Spread + c.Seconds * 1.15 + 0.2, function()
		layer:Destroy()
	end)
	return layer
end

-- Starts `item` big (and tilted) and lets it settle to its normal size. Uses its own UIScale
-- named FxPunch, so only for things without Layout.Fit (those use PopFit).
function MinigameFx.Punch(item: GuiObject, scale: number?, tilt: number?)
	local p = shared.Punch
	local s = item:FindFirstChild("FxPunch")
	if not (s and s:IsA("UIScale")) then
		local made = Instance.new("UIScale")
		made.Name = "FxPunch"
		made.Parent = item
		s = made
	end
	local uiScale = s :: UIScale
	uiScale.Scale = scale or p.Scale
	local info = TweenInfo.new(p.Seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(uiScale, info, { Scale = 1 }):Play()
	if tilt and tilt ~= 0 then
		local home = item:GetAttribute("FxHomeRotation")
		if type(home) ~= "number" then
			home = item.Rotation
			item:SetAttribute("FxHomeRotation", home)
		end
		item.Rotation = (home :: number) + tilt
		TweenService:Create(item, info, { Rotation = home }):Play()
	end
end

-- A pop for a panel that has Layout.Fit (its FitScale): through the MotionScale attribute
-- Layout.Fit listens to, so the fit and the pop never fight. Ends exactly at 1.
function MinigameFx.PopFit(panel: GuiObject, from: number, seconds: number)
	local value = Instance.new("NumberValue")
	value.Value = from
	panel:SetAttribute("MotionScale", from)
	value:GetPropertyChangedSignal("Value"):Connect(function()
		if panel.Parent then
			panel:SetAttribute("MotionScale", math.max(value.Value, 0.05))
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		value:Destroy()
		panel:SetAttribute("MotionScale", 1)
	end)
	tween:Play()
end

-- Counts `label` up from 0 to `to` over `seconds`, writing format(n) each step; it always ends
-- on format(to), the real number. A newer CountUp on the same label takes over.
local counting: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
function MinigameFx.CountUp(
	label: TextLabel,
	to: number,
	seconds: number,
	format: (n: number) -> string
)
	local token = (counting[label] or 0) + 1
	counting[label] = token
	if seconds <= 0 or to <= 0 then
		label.Text = format(to)
		return
	end
	label.Text = format(0)
	local value = Instance.new("NumberValue")
	value.Value = 0
	value:GetPropertyChangedSignal("Value"):Connect(function()
		if counting[label] == token then
			label.Text = format(math.floor(value.Value + 0.5))
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = to }
	)
	tween.Completed:Once(function()
		value:Destroy()
		if counting[label] == token then
			label.Text = format(to)
		end
	end)
	tween:Play()
end

-- A soft light that sweeps across `frame` once (after `delay` seconds), then goes away.
function MinigameFx.Shine(frame: GuiObject, seconds: number, delay: number?)
	local shine = Instance.new("Frame")
	shine.Name = "FxShine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.Active = false
	shine.ZIndex = frame.ZIndex + 1
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = shine
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = shine
	shine.Parent = frame
	local sweep = TweenService:Create(
		gradient,
		TweenInfo.new(
			seconds,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			0,
			false,
			delay or 0
		),
		{ Offset = Vector2.new(1, 0) }
	)
	sweep.Completed:Once(function()
		shine:Destroy()
	end)
	sweep:Play()
end

return MinigameFx
