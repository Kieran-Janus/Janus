--!strict
--[[
	First-round tutorial (Config.Tutorial): Boo Guide in a small speech bubble at the bottom
	of the screen, one short tip at each moment, each tip once:
	  Hub         after joining            RoundStart  the round begins (you're in it)
	  Pickup      your first pumpkin       King        the King first appears
	  Caught      you become a ghost       Results     the results screen (then it's done)
	Only while the server sets the player attribute "Tutorial" (new players). Skip, or the
	last tip, tells the server (FinishTutorial) so it never shows again.
	Phones: the bubble lifts itself above any panel along the bottom (vote, ghost, dialog,
	emotes) but never over the HUD, and Layout.Fit keeps it clear of the thumbstick/jump.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local TutorialUI = {}

local WIDTH, HEIGHT = 400, 74
-- Phones are short: a compact bubble (no name line, Skip beside the text) fits between the
-- HUD and a panel's buttons.
local PHONE_HEIGHT = 52
local BOTTOM_PANELS = { "Vote", "Ghost", "NpcDialog", "EmoteBar" }

local function circle(parent: Instance, size: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(size, size)
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	return f
end

function TutorialUI.Mount(gui: ScreenGui)
	local cfg = Config.Tutorial
	local player = Players.LocalPlayer
	local finishTutorial = Remotes.Event("FinishTutorial")

	-- Bubble -----------------------------------------------------------------------------------
	local compact = Layout.IsPhone()
	local bubble = Theme.panel(gui)
	bubble.Name = "Tutorial"
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.new(0.5, 0, 1, -24)
	bubble.Size = UDim2.fromOffset(WIDTH, if compact then PHONE_HEIGHT else HEIGHT)
	bubble.BackgroundTransparency = 0.05
	bubble.ZIndex = 9
	bubble.Visible = false
	Layout.Fit(bubble, true)

	-- Boo's little face.
	local faceSize = if compact then 40 else 52
	local face = circle(bubble, faceSize, cfg.Colors.Boo)
	face.Position = UDim2.new(0, 8, 0.5, -faceSize / 2)
	local k = faceSize / 52
	for _, x in { 15, 30 } do
		circle(face, 8 * k, Theme.Background).Position = UDim2.fromOffset(x * k, 18 * k)
	end
	circle(face, 9 * k, Theme.Background).Position = UDim2.fromOffset(22 * k, 32 * k)
	local textLeft = faceSize + 18

	local name = Theme.label(cfg.Name, 14, bubble)
	name.TextColor3 = cfg.Colors.Name
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(textLeft, 6)
	name.Size = UDim2.new(1, -140, 0, 18)
	name.Visible = not compact

	local text = Theme.label("", 16, bubble)
	text.Font = Enum.Font.GothamMedium
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	if compact then
		-- Beside the Skip button, using the whole height.
		text.Position = UDim2.fromOffset(textLeft, 6)
		text.Size = UDim2.new(1, -textLeft - 76, 1, -12)
		text.TextYAlignment = Enum.TextYAlignment.Center
		-- Long tips shrink a little to fit two or three lines, never below 13 px.
		text.TextScaled = true
		local limits = Instance.new("UITextSizeConstraint")
		limits.MinTextSize = 13
		limits.MaxTextSize = 16
		limits.Parent = text
	else
		text.Position = UDim2.fromOffset(textLeft, 30) -- below the Skip button's row
		text.Size = UDim2.new(1, -textLeft - 12, 0, 40)
	end

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, if compact then 0.5 else 0)
	skip.Position = if compact then UDim2.new(1, -8, 0.5, 0) else UDim2.new(1, -8, 0, 4)
	skip.Size = UDim2.fromOffset(58, if compact then 32 else 24)
	skip.BackgroundColor3 = Theme.Button
	skip.TextColor3 = Theme.Text
	skip.Font = Theme.Font
	skip.TextSize = 14
	skip.Text = cfg.SkipText
	skip.Parent = bubble
	Theme.round(skip, 8)

	-- Placement: above any open bottom panel, never over the HUD -----------------------------------
	local function place()
		local scale = Layout.Scale()
		local screenBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
		local lift = 24 * scale
		for _, panelName in BOTTOM_PANELS do
			local panel = gui:FindFirstChild(panelName)
			if panel and panel:IsA("GuiObject") and panel.Visible then
				lift = math.max(lift, screenBottom - panel.AbsolutePosition.Y + cfg.Gap * scale)
			end
		end
		local hud = gui:FindFirstChild("Hud")
		if hud and hud:IsA("GuiObject") then
			local hudBottom = hud.AbsolutePosition.Y + hud.AbsoluteSize.Y + 6 * scale
			local maxLift = screenBottom - hudBottom - bubble.AbsoluteSize.Y
			lift = math.max(24 * scale, math.min(lift, maxLift))
		end
		bubble.Position = UDim2.new(0.5, 0, 1, -lift / scale)
	end

	-- Tips --------------------------------------------------------------------------------------
	local shown: { [string]: boolean } = {}
	local token = 0
	local finished = false
	local shownAt = 0 -- when the current tip appeared
	local queuedUntil = 0 -- tips that had to wait are shown one after another from here

	local function active(): boolean
		return not finished and player:GetAttribute("Tutorial") == true
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		bubble.Visible = false
		finishTutorial:FireServer()
	end

	local display: (string) -> ()

	local function show(id: string)
		local tip = (cfg.Tips :: any)[id]
		if not active() or shown[id] or not tip then
			return
		end
		shown[id] = true
		-- Let the current tip stay up for at least MinSeconds (e.g. caught and results can
		-- arrive in the same second when you were the last survivor).
		local now = os.clock()
		local readyAt =
			math.max(if bubble.Visible then shownAt + cfg.MinSeconds else now, queuedUntil)
		if readyAt > now then
			queuedUntil = readyAt + cfg.MinSeconds
			task.delay(readyAt - now, display, id)
		else
			display(id)
		end
	end

	display = function(id: string)
		local tip = (cfg.Tips :: any)[id]
		if not active() or not tip then
			return
		end
		shownAt = os.clock()
		token += 1
		local mine = token
		text.Text = tip.Text
		place()
		bubble.Visible = true
		-- Keep it clear of panels that open or close while it's up.
		task.spawn(function()
			while bubble.Visible and token == mine do
				place()
				task.wait(0.15)
			end
		end)
		task.delay(tip.Seconds, function()
			if token == mine then
				bubble.Visible = false
				if id == "Results" then
					finish()
				end
			end
		end)
	end

	skip.Activated:Connect(finish)

	local function inRound(): boolean
		return player:GetAttribute("InRound") == true
			and ReplicatedStorage:GetAttribute("State") == "Playing"
	end

	-- Hub: shortly after joining (or once the server says this player is new).
	local function hubTip()
		task.delay(cfg.HubDelay, function()
			if not inRound() then
				show("Hub")
			end
		end)
	end
	player:GetAttributeChangedSignal("Tutorial"):Connect(function()
		if player:GetAttribute("Tutorial") == true then
			hubTip()
		end
	end)
	if player:GetAttribute("Tutorial") == true then
		hubTip()
	end

	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(function()
		if inRound() then
			show("RoundStart")
		end
	end)

	local pumpkins = player:GetAttribute("Pumpkins") or 0
	player:GetAttributeChangedSignal("Pumpkins"):Connect(function()
		local now = player:GetAttribute("Pumpkins") or 0
		if now > pumpkins and inRound() then
			show("Pickup")
		end
		pumpkins = now
	end)

	local kings = ReplicatedStorage:GetAttribute("KingCount") or 0
	ReplicatedStorage:GetAttributeChangedSignal("KingCount"):Connect(function()
		local now = ReplicatedStorage:GetAttribute("KingCount") or 0
		if now > kings and inRound() and not player:GetAttribute("Out") then
			show("King")
		end
		kings = now
	end)

	player:GetAttributeChangedSignal("Out"):Connect(function()
		if player:GetAttribute("Out") then
			show("Caught")
		end
	end)

	Remotes.Event("RoundResults").OnClientEvent:Connect(function(rows: unknown)
		if typeof(rows) ~= "table" then
			return
		end
		for _, row in rows :: { any } do
			if typeof(row) == "table" and row.UserId == player.UserId then
				show("Results")
				return
			end
		end
	end)
end

return TutorialUI
