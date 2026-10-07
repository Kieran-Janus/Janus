--!strict
--[[
	The ScareMaze full-screen jumpscare (used by src/client/ScareMazeUI.luau, not mounted on
	its own). A big cartoon face zooms at the screen with a flash, a camera shake and a sting
	sound for Config.ScareMaze.Jumpscare.Seconds. Spooky-cute: big eyes and an "O" mouth,
	never gory.

	ScareMazeJumpscare.Play(kind)   kind = "Scarecrow", "Zombie", "Bats", "Ghost" or "Boo"
	                                 (face colours and emoji: Config.ScareMaze.Jumpscare.Faces)
	Set Config.ScareMaze.Jumpscare.ImageId to an image ("rbxassetid://...") to show that
	instead of the faces built here.
	Its zoom and giggly wobble: Config.ScreenMotion.Jumpscare (with the motion off the face just
	shows for the same time, no zoom, flash, wobble or camera shake).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)

local ScareMazeJumpscare = {}

local screen: ScreenGui? = nil
local playing = 0 -- counts jumpscares, so an old one's timer can't hide a newer one

-- A circle (or rounded box) frame.
local function blob(
	name: string,
	color: Color3,
	size: UDim2,
	position: UDim2,
	parent: Instance,
	round: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(round or 0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function screenGui(): ScreenGui
	local existing = screen
	if existing and existing.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScareMazeJumpscare"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the whole screen, top bar included
	gui.DisplayOrder = 50 -- above the game UI
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = gui
	return gui
end

-- Builds the face for `kind` (a fresh one each time: it's small and only lives 0.6 s).
local function buildFace(kind: string, parent: Instance): GuiObject
	local cfg = Config.ScareMaze.Jumpscare
	local faces = cfg.Faces :: any
	local look = faces[kind] or faces.Boo
	if cfg.ImageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Face"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.9, 0.9)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = cfg.ImageId
		image.Parent = parent
		return image
	end
	-- A square box that keeps its shape on any screen.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.52)
	face.Size = UDim2.fromScale(0.8, 0.8)
	face.BackgroundTransparency = 1
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = face
	face.Parent = parent

	local head = blob("Head", look.Face, UDim2.fromScale(1, 0.92), UDim2.fromScale(0.5, 0.5), face)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Parent = head
	for _, side in { -1, 1 } do
		local eye = blob(
			"Eye",
			look.Eyes,
			UDim2.fromScale(0.26, 0.3),
			UDim2.fromScale(0.5 + side * 0.2, 0.38),
			head
		)
		-- Pupils look a bit cross-eyed: silly-scary.
		blob(
			"Pupil",
			look.Mouth,
			UDim2.fromScale(0.42, 0.42),
			UDim2.fromScale(0.5 - side * 0.12, 0.55),
			eye
		)
		blob(
			"Brow",
			look.Mouth,
			UDim2.fromScale(0.26, 0.05),
			UDim2.fromScale(0.5 + side * 0.2, 0.19),
			head,
			0.4
		).Rotation = side
			* 18
	end
	local mouth =
		blob("Mouth", look.Mouth, UDim2.fromScale(0.36, 0.3), UDim2.fromScale(0.5, 0.74), head, 0.5)
	blob(
		"Tongue",
		Color3.fromRGB(255, 110, 140),
		UDim2.fromScale(0.5, 0.35),
		UDim2.fromScale(0.5, 0.78),
		mouth
	)
	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.BackgroundTransparency = 1
	emoji.AnchorPoint = Vector2.new(0.5, 0.5)
	emoji.Position = UDim2.fromScale(0.86, 0.12)
	emoji.Size = UDim2.fromScale(0.3, 0.3)
	emoji.TextScaled = true
	emoji.Font = Enum.Font.GothamBlack
	emoji.Text = look.Emoji
	emoji.Rotation = 15
	emoji.Parent = face
	return face
end

-- Shakes the camera by nudging the humanoid's CameraOffset (works with the default camera).
local function shake(seconds: number, strength: number, token: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= seconds or token ~= playing or humanoid.Parent == nil then
			humanoid.CameraOffset = Vector3.zero
			if connection then
				connection:Disconnect()
			end
			return
		end
		local fade = 1 - elapsed / seconds
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * 2 * strength * fade,
			(math.random() - 0.5) * 2 * strength * fade,
			0
		)
	end)
end

function ScareMazeJumpscare.Play(kind: string)
	local cfg = Config.ScareMaze.Jumpscare
	playing += 1
	local token = playing
	local gui = screenGui()
	gui:ClearAllChildren()

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local motion = Config.ScreenMotion.Jumpscare
	local animate = ScreenFx.On()
	local face = buildFace(kind, gui)
	local scale = Instance.new("UIScale")
	scale.Scale = if animate then motion.ZoomFrom else 1
	scale.Parent = face

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.2
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui

	gui.Enabled = true
	Sounds.PlaySpec(cfg.Sting)
	if not animate then
		-- No motion: the face just shows (no zoom, flash, wobble or shake) and goes.
		flash.BackgroundTransparency = 1
		task.delay(cfg.Seconds, function()
			if token == playing then
				gui.Enabled = false
				gui:ClearAllChildren()
			end
		end)
		return
	end
	TweenService:Create(
		scale,
		TweenInfo.new(cfg.Seconds * 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = motion.ZoomTo }
	):Play()
	TweenService:Create(flash, TweenInfo.new(cfg.Seconds * 0.4), { BackgroundTransparency = 1 })
		:Play()
	shake(cfg.Seconds, cfg.ShakeStuds, token)
	-- A giggly wobble: silly, not scary.
	if motion.WobbleDegrees > 0 and motion.WobbleSeconds > 0 then
		face.Rotation = -motion.WobbleDegrees
		local times = math.max(math.floor(cfg.Seconds * 0.7 / motion.WobbleSeconds), 1)
		TweenService:Create(
			face,
			TweenInfo.new(
				motion.WobbleSeconds,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				times - 1,
				true
			),
			{ Rotation = motion.WobbleDegrees }
		):Play()
	end

	task.delay(cfg.Seconds * 0.75, function()
		if token ~= playing then
			return
		end
		local out = TweenInfo.new(cfg.Seconds * 0.25)
		TweenService:Create(scale, out, { Scale = 1.4 }):Play()
		TweenService:Create(dim, out, { BackgroundTransparency = 1 }):Play()
		for _, d in face:GetDescendants() do
			if d:IsA("Frame") then
				TweenService:Create(d, out, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, out, { TextTransparency = 1 }):Play()
			end
		end
		if face:IsA("ImageLabel") then
			TweenService:Create(face, out, { ImageTransparency = 1 }):Play()
		end
	end)
	task.delay(cfg.Seconds, function()
		if token == playing then
			gui.Enabled = false
			gui:ClearAllChildren()
		end
	end)
end

-- Hides a jumpscare that is showing (e.g. the round ended).
function ScareMazeJumpscare.Stop()
	playing += 1
	local gui = screen
	if gui then
		gui.Enabled = false
		gui:ClearAllChildren()
	end
end

return ScareMazeJumpscare
