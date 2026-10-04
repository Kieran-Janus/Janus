--!strict
--[[
	Ghost screen, shown while this player is Out:
	  - mode buttons: Spectate / Haunt / Ghost chat (SetGhostMode)
	  - Haunt mode: a Haunt button (H) with its cooldown
	  - Spectate mode: camera follows a survivor, with previous/next buttons
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

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
	return b
end

function GhostUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local setGhostMode = Remotes.Event("SetGhostMode")
	local haunt = Remotes.Function("Haunt")

	local panel = Theme.panel(gui)
	panel.Name = "Ghost"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(480, 150)
	panel.Visible = false

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
	watching.Size = UDim2.new(1, -104, 1, 0)
	local nextButton = button(">", actionRow)
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.fromScale(1, 0)
	nextButton.Size = UDim2.new(0, 44, 1, 0)

	-- Spectating ---------------------------------------------------------------
	local target: Player? = nil

	local function survivors(): { Player }
		local list = {}
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("InRound") and not other:GetAttribute("Out") then
				table.insert(list, other)
			end
		end
		return list
	end

	local function watch(step: number)
		local list = survivors()
		if #list == 0 then
			target = nil
			watching.Text = "Nobody left to watch"
			return
		end
		local index = (target and table.find(list, target)) or 0
		target = list[(index + step - 1) % #list + 1]
		watching.Text = "Watching " .. target.DisplayName
	end
	prev.Activated:Connect(function()
		watch(-1)
	end)
	nextButton.Activated:Connect(function()
		watch(1)
	end)

	local function restoreCamera()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local camera = workspace.CurrentCamera
			camera.CameraSubject = humanoid
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

	-- Refresh -------------------------------------------------------------------
	local function refresh()
		local out = player:GetAttribute("Out") == true
		local mode = player:GetAttribute("GhostMode")
		panel.Visible = out
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
		hauntButton.Visible = mode == "Haunt"
		prev.Visible = mode == "Spectate"
		nextButton.Visible = mode == "Spectate"
		watching.Visible = mode == "Spectate"

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
			status.Text = "Spectating survivors."
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
		if player:GetAttribute("GhostMode") == "Spectate" then
			if not target or target.Parent == nil or target:GetAttribute("Out") then
				watch(1)
			end
			local character = target and target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and workspace.CurrentCamera.CameraSubject ~= humanoid then
				local camera = workspace.CurrentCamera
				camera.CameraSubject = humanoid
			end
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
