--!strict
--[[
	Hub NPC interactions. Every hub ProximityPrompt has an NpcId attribute; triggering one
	opens a dialog with that NPC's Config.Npcs lines (Next / Close). Special cases:
	  VotingBoard - adds whether voting is open right now
	  Leaderboard - adds the current top list from the gravestone
	  PhotoSpot   - opens the dance bar instead (Config.Dances; hides when you walk away)
	  OpensShop   - NPCs with this set (the Pumpkin Shop) open the shop on that tab
	Motion (Config.ScreenMotion.NpcDialog): the box pops in, the words type out (tap them to see
	them all), buttons squash when pressed.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopUI = require(script.Parent.ShopUI)
local Layout = require(script.Parent.Layout)
local ScreenFx = require(script.Parent.ScreenFx)
local Theme = require(script.Parent.Theme)
local Dances = require(script.Parent.Dances)
local UIMotion = require(script.Parent.UIMotion)

local NpcDialogUI = {}

local function findNpc(id: string): any
	for _, def in Config.Npcs.List do
		if def.Id == id then
			return def
		end
	end
	return nil
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

function NpcDialogUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer

	-- Dialog ------------------------------------------------------------------------------
	local dialog = Theme.panel(gui)
	dialog.Name = "NpcDialog"
	dialog.AnchorPoint = Vector2.new(0.5, 1)
	dialog.Position = UDim2.new(0.5, 0, 1, -24)
	dialog.Size = UDim2.fromOffset(520, 170)
	dialog.Visible = false
	Layout.Fit(dialog, true)

	local nameLabel = Theme.label("", 20, dialog)
	nameLabel.TextColor3 = Theme.Selected
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.fromOffset(16, 8)
	nameLabel.Size = UDim2.new(1, -32, 0, 28)

	local body = Theme.label("", 16, dialog)
	body.Font = Enum.Font.Gotham
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Position = UDim2.fromOffset(16, 40)
	body.Size = UDim2.new(1, -32, 1, -90)

	local nextButton = button("Next", dialog)
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.new(1, -112, 1, -10)
	nextButton.Size = UDim2.fromOffset(90, 34)
	local closeButton = button("Close", dialog)
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.new(1, -12, 1, -10)
	closeButton.Size = UDim2.fromOffset(90, 34)

	-- The words type out (Config.ScreenMotion.NpcDialog): the whole page is in body.Text at
	-- once and MaxVisibleGraphemes shows more of it each moment. A tap on the words shows them
	-- all; Next and Close always work straight away.
	local motion = Config.ScreenMotion.NpcDialog
	local typing: Tween? = nil
	local typed = Instance.new("NumberValue")
	typed:GetPropertyChangedSignal("Value"):Connect(function()
		if typing then
			body.MaxVisibleGraphemes = math.floor(typed.Value)
		end
	end)
	local function finishTyping()
		local tween = typing
		typing = nil
		if tween then
			tween:Cancel()
			tween:Destroy()
		end
		body.MaxVisibleGraphemes = -1
	end
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.BackgroundTransparency = 1
	skip.AutoButtonColor = false
	skip.Text = ""
	skip.Position = body.Position
	skip.Size = body.Size
	skip.ZIndex = body.ZIndex + 1
	skip.Parent = dialog
	skip.Activated:Connect(finishTyping)

	local pages: { string } = {}
	local page = 1
	local function showPage()
		finishTyping()
		local words = pages[page] or ""
		body.Text = words
		nextButton.Visible = page < #pages
		local count = utf8.len(words) or #words
		local seconds = math.min(count / math.max(motion.CharsPerSecond, 1), motion.MaxTypeSeconds)
		if not ScreenFx.On() or count == 0 or seconds <= 0 then
			return
		end
		typed.Value = 0
		body.MaxVisibleGraphemes = 0
		local tween = TweenService:Create(
			typed,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Value = count }
		)
		typing = tween
		tween.Completed:Once(function()
			if typing == tween then
				typing = nil
				tween:Destroy()
				body.MaxVisibleGraphemes = -1
			end
		end)
		tween:Play()
	end
	nextButton.Activated:Connect(function()
		page = math.min(page + 1, #pages)
		showPage()
	end)
	closeButton.Activated:Connect(function()
		finishTyping()
		if ScreenFx.On() then
			UIMotion.PopOut(dialog)
		else
			dialog.Visible = false
		end
	end)

	-- Photo spot dance bar (Config.Dances) ---------------------------------------------------
	local dances = Config.Dances
	local columns = math.max(dances.Columns, 1)
	local cellW, cellH, gap = 132, 40, 6
	local buttonCount = #dances.List + 2 -- the dances, Stop and X
	local rows = math.ceil(buttonCount / columns)
	local emoteBar = Theme.panel(gui)
	emoteBar.Name = "EmoteBar"
	emoteBar.AnchorPoint = Vector2.new(0.5, 1)
	emoteBar.Position = UDim2.new(0.5, 0, 1, -24)
	emoteBar.Size = UDim2.fromOffset(columns * (cellW + gap) + 14, rows * (cellH + gap) + 14)
	emoteBar.Visible = false
	Layout.Fit(emoteBar, true)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cellW, cellH)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = emoteBar
	local function danceButton(text: string, order: number, onClick: () -> ()): TextButton
		local b = button(text, emoteBar)
		b.LayoutOrder = order
		b.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 16
		limit.MinTextSize = Config.UI.MinTextSize
		limit.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.Parent = b
		b.Activated:Connect(onClick)
		return b
	end
	for i, dance in dances.List do
		danceButton(dance.Label, i, function()
			Dances.Request(dance.Id)
		end)
	end
	local stopButton = danceButton(dances.StopLabel, #dances.List + 1, function()
		Dances.Request("")
	end)
	stopButton.BackgroundColor3 = Theme.Selected
	danceButton("X", #dances.List + 2, function()
		emoteBar.Visible = false
	end)

	local photoAnchor: BasePart? = nil
	RunService.RenderStepped:Connect(function()
		if not emoteBar.Visible or not photoAnchor then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			not root
			or (root.Position - photoAnchor.Position).Magnitude
				> Config.Hub.PhotoSpot.CloseDistance
		then
			emoteBar.Visible = false
		end
	end)

	-- Prompts -----------------------------------------------------------------------------
	local lastOpen = 0
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("NpcId")
		if typeof(id) ~= "string" then
			return
		end
		local now = os.clock()
		if now - lastOpen < Config.Npcs.InteractCooldown then
			return
		end
		lastOpen = now
		local def = findNpc(id)
		if not def then
			return
		end

		if def.OpensShop then
			dialog.Visible = false
			emoteBar.Visible = false
			ShopUI.Open(def.OpensShop)
			return
		end

		if def.Kind == "PhotoSpot" and Config.Features.Dances then
			dialog.Visible = false
			photoAnchor = prompt.Parent :: BasePart
			local was = emoteBar.Visible
			emoteBar.Visible = true
			if not was and ScreenFx.On() then
				UIMotion.PopIn(emoteBar)
			end
			return
		end

		pages = table.clone(def.Lines)
		if def.Id == "VotingBoard" then
			local state = ReplicatedStorage:GetAttribute("State")
			local words = Config.Npcs.BoardText
			table.insert(
				pages,
				1,
				if state == "Voting"
					then words.Voting
					elseif state == nil or state == "Waiting for players" then words.Waiting
					else words.Round:format(tostring(state))
			)
		elseif def.Id == "Leaderboard" then
			local npcModel = prompt:FindFirstAncestorOfClass("Model")
			local screen = npcModel and npcModel:FindFirstChild("Screen")
			local top = screen and screen:GetAttribute("TopList")
			if typeof(top) == "string" then
				table.insert(pages, top)
			end
		end
		emoteBar.Visible = false
		nameLabel.Text = def.DisplayName
		page = 1
		showPage()
		dialog.Visible = true
		if ScreenFx.On() then
			UIMotion.PopIn(dialog) -- (also cancels a close still shrinking it: ends full size)
		end
	end)
end

return NpcDialogUI
