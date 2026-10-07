--!strict
--[[
	Ghost screen, shown while this player is Out:
	  - mode buttons: Spectate / Haunt / Ghost chat (SetGhostMode)
	  - Haunt mode: a Haunt button (H) with its cooldown
	  - Spectate mode: camera follows a survivor or a King, with previous/next buttons and a
	    "Watch King" button (who can be watched: src/client/SpectateTargets.luau)
	  - the moment you're caught, a short camera orbit around the King (Config.Ghost.HauntCam)
	Motion (Config.ScreenMotion.Ghost): the panel slides up, a new name fades in, buttons squash
	when pressed. Looks only: every button acts at once.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local ScreenFx = require(script.Parent.ScreenFx)
local SpectateTargets = require(script.Parent.SpectateTargets)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local GhostUI = {}

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

function GhostUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local setGhostMode = Remotes.Event("SetGhostMode")
	local haunt = Remotes.Function("Haunt")

	local panel = Theme.panel(gui)
	panel.Name = "Ghost"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	local home = UDim2.new(0.5, 0, 1, -24)
	local motion = Config.ScreenMotion.Ghost
	panel.Position = home
	panel.Size = UDim2.fromOffset(480, 150)
	panel.Visible = false
	Layout.Fit(panel, true)

	local title = Theme.label("You were caught! You're a ghost now.", 18, panel)
	title.Position = UDim2.fromOffset(0, 6)
	title.Size = UDim2.new(1, 0, 0, 26)

	local status = Theme.label("", 14, panel)
	status.TextColor3 = Theme.Muted
	status.Position = UDim2.fromOffset(0, 30)
	status.Size = UDim2.new(1, 0, 0, 20)

	local modeRow = Instance.new("Frame")
	modeRow.BackgroundTransparency = 1
	modeRow.Position = UDim2.fromOffset(12, 56)
	modeRow.Size = UDim2.new(1, -24, 0, 40)
	modeRow.Parent = panel
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = modeRow

	local modeButtons: { [string]: TextButton } = {}
	for _, mode in Config.Ghost.Modes do
		local b = button(Config.Ghost.ModeNames[mode] or mode, modeRow)
		b.Size = UDim2.new(1 / #Config.Ghost.Modes, -8, 1, 0)
		b.Activated:Connect(function()
			setGhostMode:FireServer(mode)
		end)
		modeButtons[mode] = b
	end

	local actionRow = Instance.new("Frame")
	actionRow.BackgroundTransparency = 1
	actionRow.Position = UDim2.fromOffset(12, 104)
	actionRow.Size = UDim2.new(1, -24, 0, 36)
	actionRow.Parent = panel

	local hauntButton = button("Haunt (H)", actionRow)
	hauntButton.Size = UDim2.fromScale(1, 1)

	local prev = button("<", actionRow)
	prev.Size = UDim2.new(0, 44, 1, 0)
	local watching = Theme.label("", 16, actionRow)
	watching.Position = UDim2.fromOffset(52, 0)
	watching.Size = UDim2.new(1, -226, 1, 0)
	watching.TextTruncate = Enum.TextTruncate.AtEnd
	local watchKing = button(Config.Ghost.WatchKingText, actionRow)
	watchKing.Name = "WatchKing"
	watchKing.AnchorPoint = Vector2.new(1, 0)
	watchKing.Position = UDim2.new(1, -52, 0, 0)
	watchKing.Size = UDim2.new(0, 114, 1, 0)
	local nextButton = button(">", actionRow)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.fromScale(1, 0)
	nextButton.Size = UDim2.new(0, 44, 1, 0)

	-- Spectating ---------------------------------------------------------------
	-- A target is a surviving Player or a King Model (src/client/SpectateTargets.luau).
	local target: Instance? = nil
	local kings = SpectateTargets.Kings

	local function label(t: Instance): string
		return "Watching " .. SpectateTargets.Name(t)
	end

	-- A new name fades in (the words change at once).
	local function setWatching(words: string)
		if watching.Text ~= words then
			watching.Text = words
			ScreenFx.FadeText(watching, motion.NameFadeFrom, motion.NameFadeSeconds)
		end
	end

	local function watch(step: number)
		target = SpectateTargets.Step(target, step)
		setWatching(if target then label(target) else "Nobody left to watch")
	end

	watchKing.Activated:Connect(function()
		local camera = workspace.CurrentCamera
		local best: Model? = nil
		local bestDistance = math.huge
		for _, king in kings() do
			local distance = (king:GetPivot().Position - camera.Focus.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = king, distance
			end
		end
		if best then
			target = best
			setWatching(label(best))
		else
			setWatching("The King isn't here yet")
		end
	end)
	prev.Activated:Connect(function()
		watch(-1)
	end)
	nextButton.Activated:Connect(function()
		watch(1)
	end)

	local hauntCamUntil = 0
	local restoreCamera = SpectateTargets.RestoreCamera

	-- A ghost spectating from the lobby needs the map streamed to it.
	local streaming = false
	local function setStreaming(on: boolean)
		if on ~= streaming then
			streaming = on
			SpectateTargets.StreamMap(on)
		end
	end

	-- Haunting -----------------------------------------------------------------
	local function doHaunt()
		if player:GetAttribute("GhostMode") ~= "Haunt" then
			return
		end
		local affected = haunt:InvokeServer()
		status.Text = if typeof(affected) == "number" and affected > 0
			then "You spooked the King! It can't see far for a moment."
			else "Get closer to the King to haunt it."
	end
	hauntButton.Activated:Connect(doHaunt)

	-- Haunt cam ----------------------------------------------------------------
	local function hauntCam()
		local cfg = Config.Ghost.HauntCam
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local catchSpot = root.Position
		local focusKing: Model? = nil
		local nearest = cfg.KingRange
		for _, king in kings() do
			local distance = (king:GetPivot().Position - catchSpot).Magnitude
			if distance <= nearest then
				focusKing, nearest = king, distance
			end
		end
		hauntCamUntil = os.clock() + cfg.Seconds
		camera.CameraType = Enum.CameraType.Scriptable
		local started = os.clock()
		local offset = camera.CFrame.Position - catchSpot
		local startAngle = math.atan2(offset.X, offset.Z)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - started) / cfg.Seconds
			if t >= 1 or player:GetAttribute("Out") ~= true then
				connection:Disconnect()
				hauntCamUntil = 0
				camera.CameraType = Enum.CameraType.Custom
				if player:GetAttribute("GhostMode") ~= "Spectate" then
					restoreCamera()
				end
				return
			end
			local focus = if focusKing and focusKing.Parent
				then focusKing:GetPivot().Position
				else catchSpot
			local angle = startAngle + t * cfg.Turns * math.pi * 2
			local eye = focus
				+ Vector3.new(
					math.sin(angle) * cfg.Radius,
					cfg.Height,
					math.cos(angle) * cfg.Radius
				)
			camera.CFrame = CFrame.lookAt(eye, focus + Vector3.new(0, 3, 0))
		end)
	end

	-- Refresh -------------------------------------------------------------------
	local wasOut = player:GetAttribute("Out") == true
	local shownMode: unknown = nil
	local function refresh()
		local out = player:GetAttribute("Out") == true
		if out and not wasOut and ReplicatedStorage:GetAttribute("State") == "Playing" then
			task.spawn(hauntCam)
		end
		wasOut = out
		local mode = player:GetAttribute("GhostMode")
		if out and not panel.Visible then
			panel.Visible = true
			ScreenFx.Slide(panel, home, Vector2.new(0, motion.SlideDistance), motion.SlideSeconds)
		end
		panel.Visible = out
		setStreaming(out and mode == "Spectate")
		if not out then
			ContextActionService:UnbindAction("Haunt")
			if target then
				target = nil
				restoreCamera()
			end
			return
		end
		for id, b in modeButtons do
			b.BackgroundColor3 = if id == mode then Theme.Selected else Theme.Button
		end
		local picked = if typeof(mode) == "string" then modeButtons[mode] else nil
		if mode ~= shownMode and picked and ScreenFx.On() then
			UIMotion.Bump(picked) -- the mode the server switched you to
		end
		shownMode = mode
		hauntButton.Visible = mode == "Haunt"
		prev.Visible = mode == "Spectate"
		nextButton.Visible = mode == "Spectate"
		watching.Visible = mode == "Spectate"
		watchKing.Visible = mode == "Spectate"

		if mode == "Haunt" then
			status.Text = "Fly near the King and haunt it to blur its vision."
			ContextActionService:BindAction("Haunt", function(_, state)
				if state == Enum.UserInputState.Begin then
					task.spawn(doHaunt)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.H)
		else
			ContextActionService:UnbindAction("Haunt")
		end
		if mode == "GhostChat" then
			status.Text = "Ghost chat: talk with other ghosts here. The living can't hear you."
		elseif mode == "Spectate" then
			status.Text = "Spectating: use < > to switch, or Watch King."
			watch(0)
		end
		if mode ~= "Spectate" and target then
			target = nil
			restoreCamera()
		end
	end

	-- Keep the camera on the target, move on if they get caught, and show the cooldown.
	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		if hauntCamUntil > os.clock() then
			return -- the haunt cam has the camera for a moment
		end
		if player:GetAttribute("GhostMode") == "Spectate" then
			if not SpectateTargets.Watchable(target) then
				watch(1)
			end
			SpectateTargets.Follow(target)
		elseif hauntButton.Visible then
			local readyAt = player:GetAttribute("HauntReadyAt") or 0
			local remaining = readyAt - workspace:GetServerTimeNow()
			hauntButton.Text = if remaining > 0
				then ("Haunt (%ds)"):format(math.ceil(remaining))
				else "Haunt (H)"
		end
	end)

	for _, name in { "Out", "GhostMode" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return GhostUI
