--!strict
--[[
	Small look-only animations for the Hide & Seek, ScareMaze, ghost, spectate, rewards, NPC
	dialogue, announcement and Voting Board screens (settings: Config.ScreenMotion). Required by
	those modules; it has no Mount. Callers change the real thing first (the text, Visible, the
	vote) and then ask for an animation, so nothing waits for one. With Config.ScreenMotion.On
	or Config.UI.Motion.On off, every call jumps straight to the end.

	ScreenFx.On() -> boolean
	ScreenFx.Count(n) -> number                 n, or fewer on phones (ScreenMotion.PhoneShare)
	ScreenFx.Punch(gui, from, seconds, tilt?, delay?)   grows (or shrinks) from `from` to full
	                                             size and from `tilt` degrees to straight
	                                             (starting after `delay`). Uses its own
	                                             UIScale "FxScale": not for a Layout.Fit panel.
	ScreenFx.Slide(gui, home, offset, seconds)   moves from home + offset (UI units) to home
	ScreenFx.SlideOut(gui, home, offset, seconds, onDone)   the other way, then onDone
	ScreenFx.FadeText(label, from, seconds, delay?)   text from see-through `from` to solid
	ScreenFx.Pulse(label, times, seconds, fade)  text breathes to `fade` and back, ends solid
	ScreenFx.Burst(parent, position, colors, count) -> Frame?   sparkles out of a screen point
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local ScreenFx = {}

local SCALE = "FxScale"

-- The tween playing on each instance, per job ("scale", "spin", "move", "text"): a new one on
-- the same job cancels the old one.
local playing: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function ScreenFx.On(): boolean
	return Config.ScreenMotion.On == true and Config.UI.Motion.On == true
end

function ScreenFx.Count(n: number): number
	if n <= 0 then
		return 0
	end
	if Layout.IsPhone() then
		return math.max(1, math.floor(n * Config.ScreenMotion.PhoneShare + 0.5))
	end
	return math.floor(n + 0.5)
end

local function cancel(item: Instance, job: string)
	local jobs = playing[item]
	local tween = jobs and jobs[job]
	if jobs and tween then
		jobs[job] = nil
		tween:Cancel()
		tween:Destroy()
	end
end

local function play(
	item: Instance,
	job: string,
	info: TweenInfo,
	goal: { [string]: any },
	onDone: (() -> ())?
)
	cancel(item, job)
	local tween = TweenService:Create(item, info, goal)
	local jobs = playing[item]
	if not jobs then
		jobs = {}
		playing[item] = jobs
	end
	assert(jobs, "jobs was just made")
	jobs[job] = tween
	tween.Completed:Once(function(state)
		if jobs[job] ~= tween then
			return -- replaced by a newer one (it decides how this ends)
		end
		jobs[job] = nil
		tween:Destroy()
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild(SCALE)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local made = Instance.new("UIScale")
	made.Name = SCALE
	made.Parent = gui
	return made
end

function ScreenFx.Punch(
	gui: GuiObject,
	from: number,
	seconds: number,
	tilt: number?,
	delay: number?
)
	local scale = scaleOf(gui)
	if not ScreenFx.On() or seconds <= 0 then
		cancel(scale, "scale")
		cancel(gui, "spin")
		scale.Scale = 1
		gui.Rotation = 0
		return
	end
	scale.Scale = from
	local after = delay or 0
	play(
		scale,
		"scale",
		TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, after),
		{ Scale = 1 }
	)
	if tilt and tilt ~= 0 then
		gui.Rotation = tilt
		play(
			gui,
			"spin",
			TweenInfo.new(
				seconds * 1.4,
				Enum.EasingStyle.Elastic,
				Enum.EasingDirection.Out,
				0,
				false,
				after
			),
			{ Rotation = 0 }
		)
	else
		cancel(gui, "spin")
		gui.Rotation = 0
	end
end

local function shifted(home: UDim2, offset: Vector2): UDim2
	return UDim2.new(home.X.Scale, home.X.Offset + offset.X, home.Y.Scale, home.Y.Offset + offset.Y)
end

function ScreenFx.Slide(gui: GuiObject, home: UDim2, offset: Vector2, seconds: number)
	if not ScreenFx.On() or seconds <= 0 then
		cancel(gui, "move")
		gui.Position = home
		return
	end
	gui.Position = shifted(home, offset)
	play(
		gui,
		"move",
		TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = home }
	)
end

-- Moves `gui` to `to` (e.g. a stacked banner taking the place of one that left).
function ScreenFx.MoveTo(gui: GuiObject, to: UDim2, seconds: number)
	if not ScreenFx.On() or seconds <= 0 then
		cancel(gui, "move")
		gui.Position = to
		return
	end
	play(
		gui,
		"move",
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = to }
	)
end

function ScreenFx.SlideOut(
	gui: GuiObject,
	home: UDim2,
	offset: Vector2,
	seconds: number,
	onDone: () -> ()
)
	if not ScreenFx.On() or seconds <= 0 then
		cancel(gui, "move")
		onDone()
		return
	end
	play(
		gui,
		"move",
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = shifted(home, offset) },
		onDone
	)
end

function ScreenFx.FadeText(label: TextLabel, from: number, seconds: number, delay: number?)
	if not ScreenFx.On() or seconds <= 0 then
		cancel(label, "text")
		label.TextTransparency = 0
		return
	end
	label.TextTransparency = from
	play(
		label,
		"text",
		TweenInfo.new(
			seconds,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		{ TextTransparency = 0 }
	)
end

function ScreenFx.Pulse(label: TextLabel, times: number, seconds: number, fade: number)
	cancel(label, "text")
	label.TextTransparency = 0
	if not ScreenFx.On() or times <= 0 or seconds <= 0 then
		return
	end
	play(
		label,
		"text",
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, times - 1, true),
		{ TextTransparency = fade },
		function()
			label.TextTransparency = 0
		end
	)
	-- (A cancelled pulse is followed by whatever cancelled it, which sets its own text.)
end

-- Sparkles flying out of `position` inside `parent` (count already chosen: pass it through
-- Count first). Gone after Config.ScreenMotion.Burst.Seconds.
function ScreenFx.Burst(
	parent: Instance,
	position: UDim2,
	colors: { Color3 },
	count: number
): Frame?
	if not ScreenFx.On() or count <= 0 then
		return nil
	end
	local b = Config.ScreenMotion.Burst
	local layer = Instance.new("Frame")
	layer.Name = "FxBurst"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromOffset(0, 0)
	layer.Position = position
	layer.Active = false
	layer.ZIndex = 40
	layer.Parent = parent
	local rng = Random.new()
	for i = 1, count do
		local dot = Instance.new("Frame")
		dot.Name = "Sparkle"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = colors[(i - 1) % math.max(#colors, 1) + 1] or Color3.new(1, 1, 1)
		dot.Size = UDim2.fromOffset(b.Size, b.Size)
		dot.Rotation = 45
		dot.Active = false
		dot.ZIndex = 40
		dot.Parent = layer
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = b.Distance * rng:NextNumber(0.6, 1)
		TweenService
			:Create(
				dot,
				TweenInfo.new(b.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = UDim2.fromOffset(
						math.cos(angle) * distance,
						math.sin(angle) * distance
					),
					Size = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					Rotation = 45 + rng:NextNumber(-180, 180),
				}
			)
			:Play()
	end
	task.delay(b.Seconds + 0.1, function()
		layer:Destroy()
	end)
	return layer
end

return ScreenFx
