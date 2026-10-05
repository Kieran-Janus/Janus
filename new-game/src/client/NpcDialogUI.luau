--!strict
--[[
	Hub NPC interactions. Every hub ProximityPrompt has an NpcId attribute; triggering one
	opens a dialog with that NPC's Config.Npcs lines (Next / Close). Special cases:
	  VotingBoard - adds whether voting is open right now
	  Leaderboard - adds the current top list from the gravestone
	  PhotoSpot   - opens the emote bar instead (hides when you walk away)
	  OpensShop   - NPCs with this set (Witch Wanda, Pumpkin Vendor) open the shop on that tab
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopUI = require(script.Parent.ShopUI)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

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

	local pages: { string } = {}
	local page = 1
	local function showPage()
		body.Text = pages[page] or ""
		nextButton.Visible = page < #pages
	end
	nextButton.Activated:Connect(function()
		page = math.min(page + 1, #pages)
		showPage()
	end)
	closeButton.Activated:Connect(function()
		dialog.Visible = false
	end)

	-- Photo spot emote bar ------------------------------------------------------------------
	local emoteBar = Theme.panel(gui)
	emoteBar.Name = "EmoteBar"
	emoteBar.AnchorPoint = Vector2.new(0.5, 1)
	emoteBar.Position = UDim2.new(0.5, 0, 1, -24)
	emoteBar.Size = UDim2.fromOffset(560, 60)
	emoteBar.Visible = false
	Layout.Fit(emoteBar, true)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = emoteBar
	local emotes = Config.Hub.PhotoSpot.Emotes
	for _, emote in emotes do
		local b = button(emote.Label, emoteBar)
		b.Size = UDim2.new(1 / (#emotes + 1), -6, 0, 40)
		b.Activated:Connect(function()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not character or not humanoid then
				return
			end
			-- Built-in emotes (the "/e wave" ones) are played by the default Animate script's
			-- PlayEmote function; Humanoid:PlayEmote only knows the avatar's equipped emotes.
			local animate = character:FindFirstChild("Animate")
			local playEmote = animate and animate:FindFirstChild("PlayEmote")
			local played = false
			if playEmote and playEmote:IsA("BindableFunction") then
				local ok, result = pcall(function()
					return playEmote:Invoke(emote.Emote)
				end)
				played = ok and result == true
			end
			if not played then
				pcall(function()
					humanoid:PlayEmote(emote.Emote)
				end)
			end
		end)
	end
	local closeEmotes = button("X", emoteBar)
	closeEmotes.Size = UDim2.fromOffset(40, 40)
	closeEmotes.Activated:Connect(function()
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

		if def.Kind == "PhotoSpot" then
			dialog.Visible = false
			photoAnchor = prompt.Parent :: BasePart
			emoteBar.Visible = true
			return
		end

		pages = table.clone(def.Lines)
		if def.Id == "VotingBoard" then
			local state = ReplicatedStorage:GetAttribute("State")
			table.insert(
				pages,
				1,
				if state == "Voting"
					then "Voting is open right now! Tap a choice on the board or on the vote panel."
					else ("Right now: %s. The next vote starts after this round."):format(
						tostring(state or "waiting")
					)
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
	end)
end

return NpcDialogUI
