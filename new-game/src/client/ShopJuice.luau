--!strict
--[[
	Small animations for the shop screens (ShopUI's Pumpkin Shop and Packs & VIP, SettingsUI,
	the VIP King tracker). Every time and size is in Config.Shop.Juice; Animate = false there
	turns them all off (things just change, instantly). Phones (Layout.IsPhone) get fewer.

	ShopJuice.On()                       true while the extra animation is switched on
	ShopJuice.Press(button)              squashes a button while it's held
	ShopJuice.Hover(frame, stroke?)      lifts and lights up a card under the mouse (PC)
	ShopJuice.Pop(gui, scale, time)      grows `gui` to `scale` and back
	ShopJuice.Bounce(gui)                springs `gui` in from small
	ShopJuice.Shake(gui)                 wiggles `gui` sideways, then puts it back exactly
	ShopJuice.Sparkles(gui)              a burst of sparkles over `gui` (cleans itself up)
	ShopJuice.Count(label, from, to, format, done?)   rolls a number; returns a stop function
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)

local ShopJuice = {}

local function cfg(): any
	return Config.Shop.Juice
end

function ShopJuice.On(): boolean
	return cfg().Animate == true
end

-- The UIScale on `gui` this module animates (made once, named "JuiceScale").
function ShopJuice.Scale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("JuiceScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "JuiceScale"
	scale.Parent = gui
	return scale
end

local function tween(
	instance: Instance,
	time: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	delay: number?
)
	local info = TweenInfo.new(
		math.max(time, 0),
		style or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		delay or 0
	)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end
ShopJuice.Tween = tween

function ShopJuice.Press(button: GuiButton)
	local c = cfg()
	button.MouseButton1Down:Connect(function()
		if ShopJuice.On() then
			tween(ShopJuice.Scale(button), c.PressTime, { Scale = c.PressScale })
		end
	end)
	local function release()
		local scale = button:FindFirstChild("JuiceScale")
		if scale and scale:IsA("UIScale") and scale.Scale < 1 then
			tween(scale, c.PressTime * 1.5, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- Cards: grow a little and thicken their border while the mouse is over them (no mouse on
-- phones, so nothing happens there).
function ShopJuice.Hover(frame: GuiObject, stroke: UIStroke?)
	local c = cfg()
	local baseThickness = if stroke then stroke.Thickness else 0
	frame.MouseEnter:Connect(function()
		if not ShopJuice.On() or Layout.IsPhone() then
			return
		end
		tween(ShopJuice.Scale(frame), c.HoverTime, { Scale = c.HoverScale })
		if stroke then
			tween(stroke, c.HoverTime, { Thickness = baseThickness + c.HoverGlow })
		end
	end)
	frame.MouseLeave:Connect(function()
		local scale = frame:FindFirstChild("JuiceScale")
		if scale and scale:IsA("UIScale") then
			tween(scale, c.HoverTime, { Scale = 1 })
		end
		if stroke then
			tween(stroke, c.HoverTime, { Thickness = baseThickness })
		end
	end)
end

function ShopJuice.Pop(gui: GuiObject, scale: number, time: number)
	if not ShopJuice.On() then
		return
	end
	local s = ShopJuice.Scale(gui)
	tween(s, time, { Scale = scale }).Completed:Once(function()
		tween(s, time * 1.5, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

function ShopJuice.Bounce(gui: GuiObject)
	if not ShopJuice.On() then
		return
	end
	local c = cfg()
	local s = ShopJuice.Scale(gui)
	s.Scale = c.BounceFrom
	tween(s, c.BounceTime, { Scale = 1 }, Enum.EasingStyle.Back)
end

function ShopJuice.Shake(gui: GuiObject)
	if not ShopJuice.On() then
		return
	end
	local c = cfg()
	if gui:GetAttribute("Shaking") then
		return
	end
	gui:SetAttribute("Shaking", true)
	local home = gui.Position
	task.spawn(function()
		local steps = 6
		for i = 1, steps do
			local side = if i % 2 == 1 then 1 else -1
			local push = c.ShakePixels * side * (1 - (i - 1) / steps)
			gui.Position = home + UDim2.fromOffset(push, 0)
			task.wait(c.ShakeTime / steps)
		end
		gui.Position = home
		gui:SetAttribute("Shaking", nil)
	end)
end

-- Sparkles fly out from the middle of `gui` and fade; the holder is destroyed afterwards.
function ShopJuice.Sparkles(gui: GuiObject)
	if not ShopJuice.On() then
		return
	end
	local c = cfg()
	local count = if Layout.IsPhone() then c.PhoneSparkles else c.Sparkles
	if count <= 0 then
		return
	end
	local burst = Instance.new("Frame")
	burst.Name = "SparkleBurst"
	burst.BackgroundTransparency = 1
	burst.Size = UDim2.fromScale(1, 1)
	burst.ZIndex = 5
	burst.Parent = gui
	local random = Random.new()
	for i = 1, count do
		local spark = Instance.new("Frame")
		spark.Name = "Sparkle"
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromScale(0.5, 0.4)
		local size = random:NextInteger(6, 11)
		spark.Size = UDim2.fromOffset(size, size)
		spark.Rotation = 45
		spark.BorderSizePixel = 0
		spark.ZIndex = 6
		spark.BackgroundColor3 = c.SparkleColors[(i - 1) % #c.SparkleColors + 1]
		spark.Parent = burst
		local angle = (i / count) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local reach = c.SparkleReach * random:NextNumber(0.6, 1)
		tween(spark, c.SparkleTime, {
			Position = UDim2.new(0.5, math.cos(angle) * reach, 0.4, math.sin(angle) * reach),
			BackgroundTransparency = 1,
			Rotation = 45 + random:NextInteger(90, 270),
		})
	end
	task.delay(c.SparkleTime + 0.05, function()
		burst:Destroy()
	end)
end

-- Rolls `label` from `from` to `to` (label.Text = format(n)). Ends on exactly `to`.
-- Returns a function that stops the roll (the label keeps what it shows).
function ShopJuice.Count(
	label: TextLabel,
	from: number,
	to: number,
	format: (number) -> string,
	done: (() -> ())?
): () -> ()
	local time = cfg().CoinRollTime
	if not ShopJuice.On() or time <= 0 or from == to then
		label.Text = format(to)
		if done then
			done()
		end
		return function() end
	end
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - start) / time, 0, 1)
		if alpha >= 1 then
			connection:Disconnect()
			label.Text = format(to)
			if done then
				done()
			end
			return
		end
		local eased = 1 - (1 - alpha) ^ 3
		label.Text = format(math.floor(from + (to - from) * eased + 0.5))
	end)
	return function()
		connection:Disconnect()
	end
end

return ShopJuice
