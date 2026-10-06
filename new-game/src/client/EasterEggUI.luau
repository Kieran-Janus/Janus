--!strict
--[[
	Easter eggs on this player's screen (Config.EasterEggs; on/off: Config.Features.EasterEggs,
	off = Mount does nothing).

	  EasterEggToast   "Shy Shop Pumpkin / Easter egg found! +50 Coins (3/10)" when you find one
	  EasterEggs       the Menu > Secret Pumpkins panel: the eggs you found, by name, and a
	                   riddle for each one you haven't
	  Eggs you already found are hidden on your screen only (other players still see them).

	EasterEggUI.Mount(gui)
	EasterEggUI.Progress() -> (found, total)   for the Menu's "3/10" badge
	EasterEggUI.Open()                         opens the panel (the Menu tile calls this)

	It reads the attributes the server keeps up to date (EasterEggsFound on the player,
	EasterEggsActive on ReplicatedStorage) and listens to the EasterEggFound remote.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local EasterEggRules = require(ReplicatedStorage.Shared.EasterEggRules)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local PanelManager = require(script.Parent.PanelManager)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local EasterEggUI = {}

local cfg = Config.EasterEggs
local text = cfg.Text

local openPanel: (() -> ())? = nil

-- The ids this player has found (from the server's attribute).
local function foundSet(): { [string]: boolean }
	local set = {}
	local player = Players.LocalPlayer
	if player then
		for _, id in EasterEggRules.ParseIds(player:GetAttribute(EasterEggRules.FoundAttribute)) do
			set[id] = true
		end
	end
	return set
end

-- The ids of the eggs in the lobby (nil until the server has said).
local function activeIds(): { string }?
	local ids =
		EasterEggRules.ParseIds(ReplicatedStorage:GetAttribute(EasterEggRules.ActiveAttribute))
	return if #ids > 0 then ids else nil
end

function EasterEggUI.Progress(): (number, number)
	return EasterEggRules.Count(foundSet(), activeIds())
end

function EasterEggUI.Open()
	local open = openPanel
	if open then
		open()
	end
end

-- The parts and effects that make up the egg `part` belongs to: its whole model when it is
-- that model's PrimaryPart, else just the part.
local function eggRoot(part: BasePart): Instance
	local parent = part.Parent
	if parent and parent:IsA("Model") and parent.PrimaryPart == part then
		return parent
	end
	return part
end

local function setHidden(part: BasePart, hide: boolean)
	local root = eggRoot(part)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hide then 1 else 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ProximityPrompt") then
			(d :: any).Enabled = not hide
		end
	end
end

function EasterEggUI.Mount(gui: ScreenGui)
	if not Config.Features.EasterEggs then
		return
	end
	local player = Players.LocalPlayer

	-- Hide eggs already found ---------------------------------------------------------------------
	local hidden: { [BasePart]: boolean } = {}
	local function refreshEgg(instance: Instance, found: { [string]: boolean })
		if not instance:IsA("BasePart") then
			return
		end
		local id = instance:GetAttribute("EggId")
		local hide: boolean = if type(id) == "string" then found[id] == true else false
		if hide or hidden[instance] then
			setHidden(instance, hide)
			if hide then
				hidden[instance] = true
			else
				hidden[instance] = nil
			end
		end
	end
	local function refreshEggs()
		local found = foundSet()
		for _, instance in CollectionService:GetTagged(Tags.EasterEgg) do
			refreshEgg(instance, found)
		end
	end
	CollectionService:GetInstanceAddedSignal(Tags.EasterEgg):Connect(function(instance)
		task.defer(function() -- (an egg streaming in: let its model and attributes arrive)
			refreshEgg(instance, foundSet())
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.EasterEgg):Connect(function(instance)
		hidden[instance :: BasePart] = nil
	end)

	-- The toast -------------------------------------------------------------------------------------
	local toast = Theme.panel(gui)
	toast.Name = "EasterEggToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.15)
	toast.Size = UDim2.fromOffset(400, 70)
	toast.Visible = false
	toast.ZIndex = 7
	Layout.Fit(toast)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = toast
	local toastTitle = Theme.label("", 22, toast)
	toastTitle.Name = "Title"
	toastTitle.Font = Enum.Font.GothamBlack
	toastTitle.TextColor3 = Color3.fromRGB(255, 200, 60)
	toastTitle.Position = UDim2.fromOffset(10, 6)
	toastTitle.Size = UDim2.new(1, -20, 0, 28)
	toastTitle.TextScaled = true
	local toastLine = Theme.label("", 16, toast)
	toastLine.Name = "Detail"
	toastLine.Position = UDim2.fromOffset(10, 36)
	toastLine.Size = UDim2.new(1, -20, 0, 26)
	toastLine.TextScaled = true
	for _, label in { toastTitle, toastLine } do
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = if label == toastTitle then 22 else 16
		limit.MinTextSize = Config.UI.MinTextSize
		limit.Parent = label
	end
	local toastToken = 0
	local function showToast(name: string, coins: number, found: number, total: number)
		toastTitle.Text = text.ToastTitle:format(name)
		toastLine.Text = text.Toast:format(coins, Config.Economy.CurrencyName, found, total)
		toast.Visible = true
		pop.Scale = 0.6
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sounds.PlaySpec(cfg.Sounds.Found)
		toastToken += 1
		local mine = toastToken
		task.delay(cfg.ToastSeconds, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end

	-- The list panel (Menu > Secret Pumpkins) --------------------------------------------------------
	local size = cfg.Panel
	local panel = Theme.panel(gui)
	panel.Name = "EasterEggs"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(size.Width, size.Height)
	panel.BackgroundTransparency = 0.03
	panel.ZIndex = 10
	panel.Visible = false
	Layout.Fit(panel)
	local title = Theme.label(text.PanelTitle, 24, panel)
	title.Name = "Title"
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Theme.Selected
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -120, 0, 30)
	local count = Theme.label("", 16, panel)
	count.Name = "Progress"
	count.TextColor3 = Theme.Muted
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.Position = UDim2.fromOffset(16, 40)
	count.Size = UDim2.new(1, -32, 0, 22)
	local close = Theme.button(text.Close, panel)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(84, 36)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 70)
	list.Size = UDim2.new(1, -24, 1, -82)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	PanelManager.Register(panel)

	local function row(order: number, icon: string, words: string, found: boolean)
		local frame = Instance.new("Frame")
		frame.Name = "Egg" .. order
		frame.LayoutOrder = order
		frame.BackgroundColor3 = if found then Color3.fromRGB(70, 52, 24) else Theme.Button
		frame.BackgroundTransparency = 0.2
		frame.Size = UDim2.new(1, -8, 0, size.RowHeight)
		frame.Parent = list
		Theme.round(frame, 8)
		local picture = Theme.label(icon, 24, frame)
		picture.Name = "Icon"
		picture.Size = UDim2.new(0, 40, 1, 0)
		local label = Theme.label(words, 15, frame)
		label.Name = "Text"
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if found then Color3.fromRGB(255, 215, 90) else Theme.Muted
		label.Position = UDim2.fromOffset(44, 0)
		label.Size = UDim2.new(1, -50, 1, 0)
	end

	local function refreshPanel()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local found = foundSet()
		local ids: { string } = {}
		local active = activeIds()
		if active then
			for _, id in active do
				table.insert(ids, id)
			end
		end
		if #ids == 0 then
			for _, egg in cfg.List do
				table.insert(ids, egg.Id)
			end
		end
		local got, total = EasterEggRules.Count(found, ids)
		count.Text = if total > 0 and got >= total
			then text.AllFound
			else text.Progress:format(got, total)
		for i, id in ids do
			local def = EasterEggRules.Def(id)
			local name = if def then def.Name else id
			if found[id] then
				local coins = if def then def.Coins else 0
				local look = if def and def.Look then def.Look else "GoldenPumpkin"
				row(
					i,
					cfg.Icons[look] or cfg.Icons.GoldenPumpkin,
					text.FoundLine:format(name, coins),
					true
				)
			else
				local hint = if def then def.Hint else ""
				row(i, cfg.Icons.Missing, text.MissingLine:format(hint), false)
			end
		end
	end
	openPanel = function()
		refreshPanel()
		panel.Visible = true
	end

	local function onChange()
		refreshEggs()
		if panel.Visible then
			refreshPanel()
		end
	end
	player:GetAttributeChangedSignal(EasterEggRules.FoundAttribute):Connect(onChange)
	ReplicatedStorage:GetAttributeChangedSignal(EasterEggRules.ActiveAttribute):Connect(onChange)
	refreshEggs()

	-- The toast's remote (the server makes it even while the eggs are off).
	task.spawn(function()
		-- (What Remotes.Event does on a client, without requiring Remotes here: requiring it
		-- waits for the Remotes folder, and this module must load without waiting.)
		local found =
			ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EasterEggFound") :: RemoteEvent
		found.OnClientEvent:Connect(function(message: unknown)
			if type(message) ~= "table" then
				return
			end
			local m = message :: { [string]: any }
			local name = if type(m.Name) == "string" then m.Name else ""
			local function number(value: unknown): number
				return if type(value) == "number" and value == value then value else 0
			end
			showToast(name, number(m.Coins), number(m.Found), number(m.Total))
		end)
	end)
end

return EasterEggUI
