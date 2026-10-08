--!strict
--[[
	The shop (title: Config.Shop.Title): a tab per cosmetic slot (Config.Shop.Slots) plus
	"Packs & VIP". Opens from the Menu (Shop, Skins and VIP & Packs tiles), the B key and the
	Pumpkin Shop stall (Config.Npcs OpensShop -> ShopUI.Open(tab), the Skins tab). Every action
	goes through the server (ShopService); this only shows the state it sends back.

	The Skins tab has a Crates button (while Config.Features.Crates is on) that opens the
	crate panel (src/client/CrateUI.luau) on the crate of the theme you're looking at.

	Item tabs show one page of cards at a time (Config.Skins.Shop.PageSize) with filters: All /
	Owned, a rarity, and (Skins tab) a theme. Each card has a border and tag in its rarity's
	colour (Config.Rarity); CRAZY cards shimmer. A card's 3D preview is only built while its
	page is shown, and coin or ownership changes just update the buttons. Prices come from
	Items.Price. Robux buttons open Roblox's own purchase prompt and are disabled while an ID
	in Config.Monetization is still 0.

	Feel (src/client/ShopJuice.luau, every time in Config.Shop.Juice, Animate = false = none):
	cards pop in one after another on a new page, lift under the mouse, previews slowly turn
	(PC, cards in view only), Rare borders shine and CRAZY rainbow borders swell. A purchase
	the server confirms pops the card, bursts sparkles, rolls the coins down and springs the
	button in; a refused one wiggles the button and says exactly how many more coins you need.
	Putting something on pops its checkmark and shows a small "Wearing it!" toast.

	ShopUI.Open(tab?, filters?)   tab: a slot ("Skin", "Hat"...) or "Packs"; filters (optional):
	                              { Owned = true, Rarity = "Rare", Theme = "Pumpkin" }
	                              Safe to call before Mount (does nothing until then).
]]
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CatalogBadge = require(script.Parent.CatalogBadge)
local CrateUI = require(script.Parent.CrateUI)
local FramePace = require(script.Parent.FramePace)
local Layout = require(script.Parent.Layout)
local ShopJuice = require(script.Parent.ShopJuice)
local SkinFx = require(script.Parent.SkinFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local ShopUI = {}

export type Filters = { Owned: boolean?, Rarity: string?, Theme: string? }

local openShop: ((string?, Filters?) -> ())? = nil

-- Opens the shop on `tab` (a slot such as "Hat", or "Packs"). Safe to call before Mount.
function ShopUI.Open(tab: string?, filters: Filters?)
	if openShop then
		openShop(tab, filters)
	end
end

type State = {
	Ready: boolean,
	Coins: number,
	Owned: { string },
	Equipped: { [string]: string },
	Vip: boolean,
}

type Card = {
	Item: any,
	Frame: Frame,
	Action: TextButton,
	Check: TextLabel, -- the checkmark on the card you're wearing
	Stop: () -> (),
	NeedText: string?, -- "Need 300 more Coins" while NeedUntil (os.clock) hasn't passed
	NeedUntil: number?,
}

-- A turning 3D preview: the camera circles `Center` at `Offset`.
type Spin = { Camera: Camera, Center: Vector3, Offset: Vector3, Frame: GuiObject }

local ANY = "Any" -- the "every rarity / every theme" filter value

local function button(text: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.Button
	b.TextColor3 = Theme.Text
	b.Font = Theme.Font
	b.TextSize = 15
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.round(b, 8)
	ShopJuice.Press(b)
	return b
end

-- A ViewportFrame showing `model`, framed to fit (and how to turn its camera: see Spin).
local function preview(model: Model, parent: Instance): (ViewportFrame, Spin)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
	viewport.Ambient = Color3.fromRGB(200, 190, 210)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	Theme.round(viewport, 8)
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude
			* (if Layout.IsPhone()
				then Config.Shop.PhonePreviewDistance
				else Config.Shop.PreviewDistance)
		+ 0.5
	local offset = Vector3.new(distance * 0.45, distance * 0.3, -distance)
	camera.CFrame = CFrame.lookAt(cf.Position + offset, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, { Camera = camera, Center = cf.Position, Offset = offset, Frame = viewport }
end

-- 80000 -> "80,000" (easier to read for big prices).
local function commas(n: number): string
	local out = tostring(math.floor(n))
	while true do
		local swapped, count = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		out = swapped
		if count == 0 then
			return out
		end
	end
end

-- Rainbow colours for the CRAZY shimmer.
local function rainbowSequence(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.75, 1)))
	end
	return ColorSequence.new(keys)
end

-- A Rare border: its colour with one soft white band (moved along by the shine).
local function shineSequence(colour: Color3): ColorSequence
	local light = colour:Lerp(Color3.new(1, 1, 1), 0.75)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour),
		ColorSequenceKeypoint.new(0.4, colour),
		ColorSequenceKeypoint.new(0.5, light),
		ColorSequenceKeypoint.new(0.6, colour),
		ColorSequenceKeypoint.new(1, colour),
	})
end

function ShopUI.Mount(gui: ScreenGui)
	-- CRAZY skins' animated effects on every player (no-op when Features.SkinEffects is off).
	task.spawn(function()
		local ok, err = pcall(SkinFx.Start)
		if not ok then
			warn("[ShopUI] SkinFx didn't start: " .. tostring(err))
		end
	end)

	local player = Players.LocalPlayer
	local getState = Remotes.Function("GetShopState")
	local buyItem = Remotes.Function("BuyItem")
	local equipItem = Remotes.Function("EquipItem")
	local currency = Config.Economy.CurrencyName
	local skinSettings = Config.Skins.Shop
	local levels = Config.Rarity.Levels :: any -- rarity id -> { Name, Color, ... }

	local state: State = { Ready = false, Coins = 0, Owned = {}, Equipped = {}, Vip = false }
	local tab = Config.Shop.Slots[1]
	local busy = false
	local filters = { Owned = false, Rarity = ANY, Theme = ANY }
	local page = 1
	local cards: { Card } = {}
	local shimmers: { { Stroke: UIGradient, Tag: TextLabel, Border: UIStroke } } = {}
	local shines: { UIGradient } = {} -- Rare borders (and the VIP card)
	local spins: { Spin } = {}
	local juice = Config.Shop.Juice

	-- Shop button (a tile in the Menu, see Layout.SideButton) ---------------------------------
	local shopButton = Layout.SideButton(if Layout.IsPhone() then "Shop" else "Shop (B)", 4)
	shopButton.Name = "ShopButton"
	shopButton.BackgroundColor3 = Theme.Selected
	shopButton.TextSize = 17

	-- Panel -------------------------------------------------------------------------------
	local panel = Theme.panel(gui)
	panel.Name = "Shop"
	panel.ZIndex = 10 -- above the vote panel and other HUD
	panel.BackgroundTransparency = 0.03 -- nearly solid, so the vote panel doesn't show through
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	-- Phones: nearly full height and shorter cards, so a whole row of cards fits (on the
	-- shortest phones the cards get even shorter: see fitCards).
	local compact = Layout.IsPhone()
	local cardHeight = if compact then 158 else 190
	local previewHeight = if compact then 72 else 100
	local PHONE_CARD_HEIGHT = cardHeight
	-- A phone card's height without its 3D preview (a one-line name, the button, gaps).
	local NAME_HEIGHT = if compact then 18 else 34
	local CARD_PARTS = if compact then 70 else 86
	local MIN_PREVIEW = 30
	local pageSize =
		math.max(1, if compact then skinSettings.PhonePageSize else skinSettings.PageSize)
	local panelHeight = if compact then 0.97 else 0.8 -- of the screen
	panel.Size = UDim2.fromScale(0.92, panelHeight) -- capped below
	panel.Visible = false
	Layout.Fit(panel)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(660, 460)
	sizeLimit.Parent = panel

	-- The rows above the cards (phones: tighter, so the cards and their pictures get the room).
	local HEAD = if compact
		then {
			RowY = 6,
			RowH = 28,
			TabsY = 36,
			TabsH = 30,
			FilterY = 70,
			FilterH = 28,
			ListTop = 102,
			ListTopNoFilter = 70,
		}
		else {
			RowY = 8,
			RowH = 32,
			TabsY = 46,
			TabsH = 34,
			FilterY = 86,
			FilterH = 30,
			ListTop = 122,
			ListTopNoFilter = 88,
		}

	local title = Theme.label(Config.Shop.Title, 22, panel)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(16, HEAD.RowY)
	title.Size = UDim2.new(0.6, 0, 0, HEAD.RowH)

	local coinsLabel = Theme.label("", 18, panel)
	coinsLabel.TextColor3 = Theme.Selected
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -56, 0, HEAD.RowY)
	coinsLabel.Size = UDim2.new(0.4, -56, 0, HEAD.RowH)

	-- The coins counter: jumps to a value, or (after a purchase / reward) rolls to it.
	local function coinText(n: number): string
		return ("%s %s"):format(commas(n), currency)
	end
	local shownCoins: number? = nil
	local rollTarget: number? = nil
	local stopRoll: () -> () = function() end
	local function showCoins(value: number, roll: boolean)
		if rollTarget == value then
			return -- already rolling there
		end
		stopRoll()
		rollTarget = nil
		local from = shownCoins
		shownCoins = value
		if roll and from and from ~= value and panel.Visible and ShopJuice.On() then
			rollTarget = value
			stopRoll = ShopJuice.Count(coinsLabel, from, value, coinText, function()
				rollTarget = nil
			end)
		else
			coinsLabel.Text = coinText(value)
		end
	end

	-- "Wearing it!": a small note that pops up over the cards for a moment.
	local toast = Theme.label("", 16, panel)
	toast.Name = "Toast"
	toast.Visible = false
	toast.ZIndex = 15
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -44)
	toast.Size = UDim2.fromOffset(170, 34)
	toast.BackgroundTransparency = 0.05
	toast.BackgroundColor3 = Color3.fromRGB(60, 140, 70)
	Theme.round(toast, 17)
	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local mine = toastToken
		toast.Text = text
		toast.Visible = true
		ShopJuice.Bounce(toast)
		task.delay(juice.ToastSeconds, function()
			if toastToken == mine then
				toast.Visible = false
			end
		end)
	end

	local close = button("X", panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, HEAD.RowY)
	close.Size = UDim2.fromOffset(36, HEAD.RowH)

	local tabsBar = Instance.new("Frame")
	tabsBar.BackgroundTransparency = 1
	tabsBar.Position = UDim2.fromOffset(16, HEAD.TabsY)
	tabsBar.Size = UDim2.new(1, -32, 0, HEAD.TabsH)
	tabsBar.Parent = panel
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = tabsBar

	-- Filters (item tabs): Owned, rarity chips, theme (Skins only). Scrolls sideways on
	-- narrow screens.
	local filterBar = Instance.new("ScrollingFrame")
	filterBar.Name = "Filters"
	filterBar.BackgroundTransparency = 1
	filterBar.BorderSizePixel = 0
	filterBar.Position = UDim2.fromOffset(16, HEAD.FilterY)
	filterBar.Size = UDim2.new(1, -32, 0, HEAD.FilterH)
	filterBar.ScrollBarThickness = 3
	filterBar.ScrollingDirection = Enum.ScrollingDirection.X
	filterBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	filterBar.CanvasSize = UDim2.new()
	filterBar.Parent = panel
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	filterLayout.Padding = UDim.new(0, 6)
	filterLayout.Parent = filterBar

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local message = Theme.label("", 15, panel)
	message.TextColor3 = Theme.Muted
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextTruncate = Enum.TextTruncate.AtEnd
	message.AnchorPoint = Vector2.new(0, 1)
	message.Position = UDim2.new(0, 16, 1, -8)
	message.Size = UDim2.new(1, -240, 0, 28)

	-- Pages: < Page 2 / 9 >
	local pager = Instance.new("Frame")
	pager.Name = "Pager"
	pager.BackgroundTransparency = 1
	pager.AnchorPoint = Vector2.new(1, 1)
	pager.Position = UDim2.new(1, -16, 1, -8)
	pager.Size = UDim2.fromOffset(210, 28)
	pager.Parent = panel
	local prevButton = button("<", pager)
	prevButton.Name = "Previous"
	prevButton.Size = UDim2.fromOffset(40, 28)
	local nextButton = button(">", pager)
	nextButton.Name = "Next"
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.fromScale(1, 0)
	nextButton.Size = UDim2.fromOffset(40, 28)
	local pageLabel = Theme.label("", 14, pager)
	pageLabel.TextColor3 = Theme.Muted
	pageLabel.Position = UDim2.fromOffset(44, 0)
	pageLabel.Size = UDim2.new(1, -88, 1, 0)

	local tabButtons: { [string]: TextButton } = {}
	local render: () -> ()
	local renderPage: () -> ()

	local function owns(id: string): boolean
		return table.find(state.Owned, id) ~= nil
	end

	local function usable(item: any): boolean
		return if item.VipOnly then state.Vip else owns(item.Id)
	end

	local function setState(new: any)
		if typeof(new) == "table" and typeof(new.Coins) == "number" then
			state = new
		end
	end

	local function themeOf(item: any): string
		return if type(item.Theme) == "string" then item.Theme else skinSettings.ClassicTheme
	end

	-- The items the current tab and filters show, in Config order.
	local function shownItems(): { any }
		local out = {}
		for _, item in Config.Shop.Items do
			if item.Slot ~= tab then
				continue
			end
			-- Won some other way (the Tormented Tower's skin): only shown once you own it.
			if item.Exclusive and not owns(item.Id) then
				continue
			end
			if filters.Owned and not usable(item) then
				continue
			end
			if filters.Rarity ~= ANY and Items.Rarity(item) ~= filters.Rarity then
				continue
			end
			if tab == "Skin" and filters.Theme ~= ANY and themeOf(item) ~= filters.Theme then
				continue
			end
			table.insert(out, item)
		end
		return out
	end

	local function card(height: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Theme.Button
		frame.BackgroundTransparency = 0.3
		frame.Size = UDim2.fromOffset(140, height)
		frame.Parent = list
		Theme.round(frame, 10)
		return frame
	end

	local function updateButtons()
		showCoins(state.Coins, false)
		for _, c in cards do
			local item = c.Item
			local action = c.Action
			local price = Items.Price(item)
			action.AutoButtonColor = true
			c.Check.Visible = state.Equipped[item.Slot] == item.Id
			if state.Equipped[item.Slot] == item.Id then
				action.Text = "Unequip"
				action.BackgroundColor3 = Theme.Button
			elseif usable(item) then
				action.Text = "Equip"
				action.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
			elseif item.VipOnly then
				action.Text = Config.Monetization.VipName .. " only"
				action.BackgroundColor3 = Color3.fromRGB(120, 95, 30)
			elseif price == nil then
				-- Not sold for coins (CrateOnly): only crates give it.
				action.Text = "From crates"
				action.AutoButtonColor = false
				action.BackgroundColor3 = Color3.fromRGB(70, 65, 80)
			elseif c.NeedUntil and os.clock() < c.NeedUntil and c.NeedText then
				-- Just tried without enough coins: how many more (the price comes back after).
				action.Text = c.NeedText
				action.BackgroundColor3 = Color3.fromRGB(170, 60, 60)
			else
				action.Text = Config.Shop.BuyText:format(commas(price), currency)
				action.BackgroundColor3 = Theme.Selected
			end
		end
	end

	local function findCard(id: string): Card?
		for _, c in cards do
			if c.Item.Id == id then
				return c
			end
		end
		return nil
	end

	-- The checkmark on a card you just put on pops in, and the "Wearing it!" toast shows.
	local function wearing(c: Card)
		if ShopJuice.On() then
			local s = ShopJuice.Scale(c.Check)
			s.Scale = 0.2
			ShopJuice.Tween(s, 0.12, { Scale = juice.CheckPop }).Completed:Once(function()
				ShopJuice.Tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		showToast(juice.ToastText)
	end

	-- A purchase the server confirmed: pop, sparkles, the button springs in.
	local function celebrate(id: string)
		local c = findCard(id)
		if not c then
			return
		end
		ShopJuice.Pop(c.Frame, juice.PopScale, juice.PopTime)
		ShopJuice.Sparkles(c.Frame)
		ShopJuice.Bounce(c.Action)
		if state.Equipped[c.Item.Slot] == id then
			wearing(c) -- (buying puts it on)
		end
	end

	-- Not enough coins: the button wiggles and says exactly how many more.
	local function refuse(id: string, missing: number)
		local c = findCard(id)
		if not c then
			return
		end
		c.NeedText = juice.NeedText:format(commas(missing), currency)
		c.NeedUntil = os.clock() + juice.NeedSeconds
		updateButtons()
		ShopJuice.Shake(c.Action)
		task.delay(juice.NeedSeconds, function()
			if c.Action.Parent then
				updateButtons()
			end
		end)
	end

	-- After the server answers: the buttons change, and with the Owned filter on the page too.
	local function afterChange()
		if not panel.Visible then
			return
		end
		if filters.Owned then
			renderPage()
		else
			updateButtons()
		end
	end

	-- Asks the server (fn), then updates the cards; fn may return an effect to play after that.
	local function act(fn: () -> (() -> ())?)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, result = pcall(fn)
			if not ok then
				message.Text = "Something went wrong, try again."
				warn("[ShopUI] " .. tostring(result))
			end
			busy = false
			afterChange()
			if ok and result and panel.Visible then
				result()
			end
		end)
	end

	-- What a card's button does right now (reads the latest state when clicked).
	local function onAction(item: any)
		local slot = item.Slot
		if state.Equipped[slot] == item.Id then
			act(function()
				setState(equipItem:InvokeServer(slot, ""))
				message.Text = ""
				return nil
			end)
		elseif usable(item) then
			act(function()
				setState(equipItem:InvokeServer(slot, item.Id))
				if state.Equipped[slot] ~= item.Id then
					return nil -- the server said no
				end
				message.Text = "Wearing " .. item.Name .. "."
				return function()
					local c = findCard(item.Id)
					if c then
						wearing(c)
					end
				end
			end)
		elseif item.VipOnly then
			ShopUI.Open("Packs")
		elseif Items.Price(item) ~= nil then
			act(function()
				local bought, text, new = buyItem:InvokeServer(item.Id)
				setState(new)
				message.Text = tostring(text)
				if bought then
					Sounds.Play("Purchase")
					showCoins(state.Coins, true)
					return function()
						celebrate(item.Id)
					end
				end
				-- The server's coins, so the number is exact.
				local missing = (Items.Price(item) or 0) - state.Coins
				if missing > 0 and not owns(item.Id) then
					return function()
						refuse(item.Id, missing)
					end
				end
				return nil
			end)
		end
	end

	-- Small coloured rarity label in the top-left corner of a card's preview.
	local function rarityTag(item: any, parent: Frame): TextLabel
		local info = Items.RarityInfo(item)
		-- Phones: smaller and tucked into the corner, so it covers less of the picture.
		local look = if compact then Config.Shop.PhoneRarityTag else Config.Shop.RarityTag
		local tag = Theme.label(info.Name, math.max(look.TextSize, Config.UI.MinTextSize), parent)
		tag.Name = "RarityTag"
		tag.ZIndex = 2 -- above the preview
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Position = UDim2.fromOffset(look.Inset, look.Inset)
		tag.Size = UDim2.fromOffset(0, look.Height)
		tag.BackgroundTransparency = 0.1
		tag.BackgroundColor3 = info.Color
		tag.TextStrokeTransparency = 0.6
		Theme.round(tag, if compact then 4 else 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, look.Padding)
		padding.PaddingRight = UDim.new(0, look.Padding)
		padding.Parent = tag
		return tag
	end

	local function clearCards()
		for _, c in cards do
			c.Stop()
			c.Frame:Destroy()
		end
		cards = {}
		shimmers = {}
		shines = {}
		spins = {}
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	-- `place`: the card's place on its page (1 = first), for the pop-in one after another.
	local function makeCard(item: any, order: number, place: number)
		local frame = card(cardHeight)
		frame.LayoutOrder = order
		local info = Items.RarityInfo(item)
		local border = Instance.new("UIStroke")
		border.Name = "RarityBorder"
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Thickness = if Items.Rarity(item) == "Common" then 1.5 else 2.5
		border.Color = info.Color
		border.Parent = frame

		local model = Cosmetics.Preview(item)
		local view, spin = preview(model, frame)
		view.Position = UDim2.fromOffset(8, 8)
		view.Size = UDim2.new(1, -16, 0, previewHeight)
		table.insert(spins, spin)
		local tag = rarityTag(item, frame)
		CatalogBadge.Add(view, item) -- pictures of the skin's Roblox catalog items (Style.Catalog)
		local stop = function() end
		if item.Slot == "Skin" or info.Rainbow then
			-- moving pieces (Style.Animate) and CRAZY rainbow parts, while the card is in view
			stop = SkinFx.AnimatePreview(model)
		end
		if info.Rainbow then
			border.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = rainbowSequence()
			gradient.Parent = border
			table.insert(shimmers, { Stroke = gradient, Tag = tag, Border = border })
		elseif Items.Rarity(item) == "Rare" then
			local gradient = Instance.new("UIGradient")
			gradient.Name = "Shine"
			gradient.Color = shineSequence(info.Color)
			gradient.Parent = border
			border.Color = Color3.new(1, 1, 1) -- (the gradient gives the colour)
			table.insert(shines, gradient)
		end
		ShopJuice.Hover(frame, border)

		-- The checkmark on the card you're wearing (top right of the preview).
		local check = Theme.label("✓", 18, frame)
		check.Name = "Check"
		check.Visible = false
		check.ZIndex = 3
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -12, 0, 12)
		check.Size = UDim2.fromOffset(24, 24)
		check.BackgroundTransparency = 0
		check.BackgroundColor3 = Color3.fromRGB(60, 160, 70)
		Theme.round(check, 12)

		-- A new page: the cards pop in one after another.
		if ShopJuice.On() then
			local s = ShopJuice.Scale(frame)
			s.Scale = 0
			ShopJuice.Tween(
				s,
				juice.EnterTime,
				{ Scale = 1 },
				Enum.EasingStyle.Back,
				(place - 1) * juice.EnterStagger
			)
		end

		local name = Theme.label(item.Name, 14, frame)
		name.TextWrapped = not compact -- (phones: one line, so the 3D preview gets the room)
		name.TextTruncate = if compact then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None
		name.Position = UDim2.fromOffset(6, previewHeight + 10)
		name.Size = UDim2.new(1, -12, 0, NAME_HEIGHT)

		local action = button("", frame)
		action.Position = UDim2.new(0, 8, 1, -40)
		action.Size = UDim2.new(1, -16, 0, 32)
		-- ("Buy 100,000 Coins" must fit: the text shrinks, but never below MinTextSize)
		action.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = action.TextSize
		fit.MinTextSize = Config.UI.MinTextSize
		fit.Parent = action
		action.Activated:Connect(function()
			onAction(item)
		end)
		table.insert(
			cards,
			{ Item = item, Frame = frame, Action = action, Check = check, Stop = stop }
		)
	end

	renderPage = function()
		clearCards()
		local items = shownItems()
		local pages = math.max(1, math.ceil(#items / pageSize))
		page = math.clamp(page, 1, pages)
		pageLabel.Text = ("Page %d / %d"):format(page, pages)
		prevButton.Visible = page > 1
		nextButton.Visible = page < pages
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(140, cardHeight)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = list
		if #items == 0 then
			local none = Theme.label(
				if filters.Owned
					then "You don't own any of these yet."
					else "Nothing matches these filters.",
				15,
				list
			)
			none.TextColor3 = Theme.Muted
			grid.CellSize = UDim2.new(1, -10, 0, 40)
			updateButtons() -- (the coins label)
			return
		end
		local first = (page - 1) * pageSize + 1
		for i = first, math.min(#items, page * pageSize) do
			makeCard(items[i], i, i - first + 1)
		end
		list.CanvasPosition = Vector2.zero
		updateButtons()
	end

	-- Filter chips ---------------------------------------------------------------------------
	local chips: { [string]: TextButton } = {}
	local function chip(id: string, text: string, width: number, order: number): TextButton
		local b = button(text, filterBar)
		b.Name = id .. "Filter"
		b.TextSize = 14
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(width, 28)
		chips[id] = b
		return b
	end

	local ownedChip = chip("Owned", "Owned", 70, 1)
	ownedChip.Activated:Connect(function()
		filters.Owned = not filters.Owned
		page = 1
		render()
	end)
	local rarityIds = { ANY }
	for _, id in Config.Rarity.Order do
		table.insert(rarityIds, id)
	end
	for i, id in rarityIds do
		local text = if id == ANY then "All" else levels[id].Name
		local b = chip("Rarity" .. id, text, if id == ANY then 48 else 30 + #text * 9, 1 + i)
		b.Activated:Connect(function()
			filters.Rarity = id
			page = 1
			render()
		end)
	end
	local themeIds = { ANY, skinSettings.ClassicTheme }
	local themeNames: { [string]: string } =
		{ [ANY] = "All themes", [skinSettings.ClassicTheme] = skinSettings.ClassicTheme }
	for _, theme in Config.Skins.Themes do
		table.insert(themeIds, theme.Id)
		themeNames[theme.Id] = theme.Name
	end
	local themeChip = chip("Theme", "", 130, 20)
	-- Crates (Skins tab): opens the crate panel on the shown theme's crate.
	-- (first in the row: on narrow screens the row scrolls sideways and kids miss what's at the end)
	local cratesChip = chip("Crates", Config.Crates.Text.ShopChip, 100, 0)
	cratesChip.BackgroundColor3 = Color3.fromRGB(170, 60, 120)
	cratesChip.Activated:Connect(function()
		local crateId: string? = nil
		for _, theme in Config.Skins.Themes do
			if theme.Id == filters.Theme then
				crateId = theme.Crate
			end
		end
		panel.Visible = false
		CrateUI.Open(crateId)
	end)
	CrateUI.SetShopOpener(function(wanted: CrateUI.ShopFilters)
		ShopUI.Open("Skin", { Theme = wanted.Theme, Rarity = wanted.Rarity })
	end)
	-- The theme chip opens a dropdown of every theme (there are 30), each with its colour.
	local themeMenu = Instance.new("ScrollingFrame")
	themeMenu.Name = "ThemeMenu"
	themeMenu.Visible = false
	themeMenu.ZIndex = 20
	themeMenu.BackgroundColor3 = Theme.Background
	themeMenu.BorderSizePixel = 0
	themeMenu.Position = UDim2.fromOffset(16, HEAD.FilterY + HEAD.FilterH + 2)
	themeMenu.Size = UDim2.new(0, 240, 1, -130)
	themeMenu.ScrollBarThickness = 6
	themeMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	themeMenu.CanvasSize = UDim2.new()
	themeMenu.Parent = panel
	Theme.round(themeMenu, 8)
	local menuList = Instance.new("UIListLayout")
	menuList.SortOrder = Enum.SortOrder.LayoutOrder
	menuList.Padding = UDim.new(0, 4)
	menuList.Parent = themeMenu
	local menuPad = Instance.new("UIPadding")
	menuPad.PaddingTop = UDim.new(0, 6)
	menuPad.PaddingLeft = UDim.new(0, 6)
	menuPad.Parent = themeMenu
	local themeColours: { [string]: Color3 } = {}
	for _, theme in Config.Skins.Themes do
		themeColours[theme.Id] = theme.Color
	end
	for i, id in themeIds do
		local option = button(themeNames[id] or id, themeMenu)
		option.Name = "Theme_" .. id
		option.LayoutOrder = i
		option.ZIndex = 21
		option.TextSize = 14
		option.TextXAlignment = Enum.TextXAlignment.Left
		option.Size = UDim2.new(1, -14, 0, 30)
		local optionPad = Instance.new("UIPadding")
		optionPad.PaddingLeft = UDim.new(0, 28)
		optionPad.Parent = option
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.ZIndex = 22
		swatch.BorderSizePixel = 0
		swatch.AnchorPoint = Vector2.new(0, 0.5)
		swatch.Position = UDim2.new(0, -20, 0.5, 0)
		swatch.Size = UDim2.fromOffset(14, 14)
		swatch.BackgroundColor3 = themeColours[id] or Theme.Muted
		swatch.Parent = option
		Theme.round(swatch, 7)
		option.Activated:Connect(function()
			filters.Theme = id
			page = 1
			themeMenu.Visible = false
			render()
		end)
	end
	themeChip.Activated:Connect(function()
		themeMenu.Visible = not themeMenu.Visible
	end)

	local function styleChips()
		ownedChip.BackgroundColor3 = if filters.Owned then Theme.Selected else Theme.Button
		for _, id in rarityIds do
			local b = chips["Rarity" .. id]
			local selected = filters.Rarity == id
			local colour = if id == ANY then Theme.Selected else levels[id].Color
			b.BackgroundColor3 = if selected then colour else Theme.Button
			b.TextColor3 = if selected or id == ANY then Theme.Text else colour
		end
		themeChip.Visible = tab == "Skin"
		if tab ~= "Skin" then
			themeMenu.Visible = false
		end
		cratesChip.Visible = tab == "Skin" and Config.Features.Crates
		themeChip.Text = (themeNames[filters.Theme] or filters.Theme) .. "  ▼"
		local themeColour: Color3? = nil
		for _, theme in Config.Skins.Themes do
			if theme.Id == filters.Theme then
				themeColour = theme.Color
			end
		end
		themeChip.BackgroundColor3 = if themeColour
			then themeColour:Lerp(Theme.Button, 0.45)
			else Theme.Button
	end

	-- Packs & VIP tab ------------------------------------------------------------------------

	local function robuxButton(
		id: number,
		suggested: number,
		parent: Instance,
		onBuy: () -> ()
	): TextButton
		local b = button("", parent)
		if id == 0 then
			b.Text = "Coming soon"
			b.AutoButtonColor = false
			b.BackgroundColor3 = Color3.fromRGB(70, 65, 80)
			return b
		end
		b.Text = ("R$ %d"):format(suggested)
		b.BackgroundColor3 = Color3.fromRGB(40, 150, 70)
		b.Activated:Connect(onBuy)
		return b
	end

	local priceCache: { [number]: number } = {}
	local function realPrice(id: number, infoType: Enum.InfoType, label: TextButton)
		if id == 0 then
			return
		end
		if priceCache[id] then
			label.Text = ("R$ %d"):format(priceCache[id])
			return
		end
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			if ok and info and typeof(info.PriceInRobux) == "number" then
				priceCache[id] = info.PriceInRobux
				label.Text = ("R$ %d"):format(info.PriceInRobux)
			end
		end)
	end

	local function renderPacks()
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		-- VIP card.
		local vipCfg = Config.Monetization
		local vip = card(150)
		vip.Name = "VipCard"
		vip.Size = UDim2.new(1, -10, 0, 150)
		-- A gold border with the same soft shine as Rare cards.
		local vipBorder = Instance.new("UIStroke")
		vipBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		vipBorder.Thickness = 2.5
		vipBorder.Color = Color3.new(1, 1, 1)
		vipBorder.Parent = vip
		local vipShine = Instance.new("UIGradient")
		vipShine.Name = "Shine"
		vipShine.Color = shineSequence(vipCfg.ChatTag.Color)
		vipShine.Parent = vipBorder
		table.insert(shines, vipShine)
		local vipTitle = Theme.label(vipCfg.VipName, 20, vip)
		vipTitle.TextColor3 = vipCfg.ChatTag.Color
		vipTitle.TextXAlignment = Enum.TextXAlignment.Left
		vipTitle.Position = UDim2.fromOffset(12, 6)
		vipTitle.Size = UDim2.new(1, -150, 0, 28)
		local perks = Theme.label("• " .. table.concat(vipCfg.VipPerks, "\n• "), 14, vip)
		perks.Font = Enum.Font.Gotham
		perks.TextXAlignment = Enum.TextXAlignment.Left
		perks.TextYAlignment = Enum.TextYAlignment.Top
		perks.TextWrapped = true
		perks.Position = UDim2.fromOffset(12, 38)
		perks.Size = UDim2.new(1, -160, 1, -44)
		local vipButton: TextButton
		if state.Vip then
			vipButton = button("You have VIP!", vip)
			vipButton.AutoButtonColor = false
		else
			vipButton = robuxButton(vipCfg.VipGamePassId, vipCfg.VipSuggestedRobux, vip, function()
				MarketplaceService:PromptGamePassPurchase(player, vipCfg.VipGamePassId)
			end)
			realPrice(vipCfg.VipGamePassId, Enum.InfoType.GamePass, vipButton)
		end
		vipButton.AnchorPoint = Vector2.new(1, 0.5)
		vipButton.Position = UDim2.new(1, -12, 0.5, 0)
		vipButton.Size = UDim2.fromOffset(130, 40)

		-- Coin packs.
		for index, product in vipCfg.Products do
			local row = card(64)
			row.Name = "Pack"
			row.LayoutOrder = index
			ShopJuice.Hover(row)
			if ShopJuice.On() then
				local s = ShopJuice.Scale(row)
				s.Scale = 0
				ShopJuice.Tween(
					s,
					juice.EnterTime,
					{ Scale = 1 },
					Enum.EasingStyle.Back,
					index * juice.EnterStagger
				)
			end
			row.Size = UDim2.new(1, -10, 0, 64)
			local name = Theme.label(product.Name, 17, row)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Position = UDim2.fromOffset(12, 6)
			name.Size = UDim2.new(1, -160, 0, 26)
			local amount = Theme.label(("+%d %s"):format(product.Coins, currency), 15, row)
			amount.TextColor3 = Theme.Selected
			amount.TextXAlignment = Enum.TextXAlignment.Left
			amount.Position = UDim2.fromOffset(12, 32)
			amount.Size = UDim2.new(1, -160, 0, 24)
			local buy = robuxButton(product.Id, product.SuggestedRobux, row, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
			realPrice(product.Id, Enum.InfoType.Product, buy)
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -12, 0.5, 0)
			buy.Size = UDim2.fromOffset(130, 40)
		end
	end

	-- Phones: the first row of cards always fits in the list, Buy / Equip button included
	-- (on the shortest phones the list is shorter than a card, so the 3D preview shrinks).
	-- `around` = the panel's height that isn't the list.
	local function fitCards(around: number)
		if not compact then
			return
		end
		local screenHeight = Layout.Screen().Y
		if screenHeight <= 0 then
			return -- (not laid out yet)
		end
		local listHeight = math.min(screenHeight * panelHeight, sizeLimit.MaxSize.Y) - around
		cardHeight =
			math.clamp(math.floor(listHeight - 10), CARD_PARTS + MIN_PREVIEW, PHONE_CARD_HEIGHT)
		previewHeight = cardHeight - CARD_PARTS
	end

	-- Everything for the current tab (cards are rebuilt; use updateButtons for state changes).
	render = function()
		showCoins(state.Coins, false)
		for id, b in tabButtons do
			b.BackgroundColor3 = if id == tab then Theme.Selected else Theme.Button
		end
		local items = tab ~= "Packs"
		filterBar.Visible = items and state.Ready
		pager.Visible = items and state.Ready
		local top = if filterBar.Visible then HEAD.ListTop else HEAD.ListTopNoFilter
		local bottom = if compact then 40 else 42
		list.Position = UDim2.fromOffset(16, top)
		list.Size = UDim2.new(1, -32, 1, -(top + bottom))
		fitCards(top + bottom)
		clearCards()
		if not state.Ready then
			local wait = Theme.label("Loading your bag...", 16, list)
			wait.Size = UDim2.new(1, 0, 0, 40)
			return
		end
		if items then
			styleChips()
			renderPage()
		else
			renderPacks()
		end
	end

	local tabIds = table.clone(Config.Shop.Slots)
	table.insert(tabIds, "Packs")
	for i, id in tabIds do
		local b =
			button(if id == "Packs" then "Packs & VIP" else Config.Shop.SlotNames[id], tabsBar)
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(if id == "Packs" then 130 else 100, HEAD.TabsH)
		b.Activated:Connect(function()
			if tab ~= id then
				tab = id
				page = 1
			end
			message.Text = ""
			render()
		end)
		tabButtons[id] = b
	end

	prevButton.Activated:Connect(function()
		page -= 1
		renderPage()
	end)
	nextButton.Activated:Connect(function()
		page += 1
		renderPage()
	end)

	-- Is `item` inside the list's visible area? (Unknown sizes, before layout, count as yes.)
	local function inView(item: GuiObject): boolean
		local height = list.AbsoluteSize.Y
		if height <= 0 then
			return true
		end
		local top = list.AbsolutePosition.Y
		local y = item.AbsolutePosition.Y
		return y + item.AbsoluteSize.Y >= top and y <= top + height
	end

	-- While the shop is open: CRAZY borders shimmer (and swell), Rare borders shine, and the
	-- 3D previews in view slowly turn (PC; phones keep them still). Connected only while the
	-- panel is open: a closed shop runs nothing per frame.
	FramePace.WhileVisible(panel, RunService.Heartbeat, function()
		local now = os.clock()
		local t = now / skinSettings.ShimmerSeconds
		local animate = ShopJuice.On()
		for _, s in shimmers do
			s.Stroke.Rotation = (t * 360) % 360
			s.Tag.BackgroundColor3 = Color3.fromHSV(t % 1, 0.7, 1)
			if animate then
				s.Border.Thickness = 2.5 + juice.CrazyPulse * (0.5 + 0.5 * math.sin(now * 4))
			end
		end
		if not animate then
			return
		end
		if #shines > 0 and juice.RareShineSeconds > 0 then
			-- The band sweeps across, then rests a moment off the edge.
			local x = ((now / juice.RareShineSeconds) % 1) * 3 - 1.5
			for _, g in shines do
				g.Offset = Vector2.new(x, 0)
			end
		end
		if juice.SpinSpeed > 0 and not compact and #spins > 0 then
			local turn = CFrame.Angles(0, math.rad(now * juice.SpinSpeed), 0)
			for _, s in spins do
				if inView(s.Frame) then
					s.Camera.CFrame = CFrame.lookAt(s.Center + turn * s.Offset, s.Center)
				end
			end
		end
	end)

	local wasReady = false
	local function refresh()
		task.spawn(function()
			local ok, new = pcall(function()
				return getState:InvokeServer()
			end)
			if ok then
				setState(new)
			end
			if panel.Visible then
				if state.Ready and not wasReady then
					render() -- first answer: replace "Loading your bag..."
				else
					afterChange()
				end
			end
			wasReady = state.Ready
		end)
	end

	openShop = function(which: string?, wanted: Filters?)
		if which and (which == "Packs" or table.find(Config.Shop.Slots, which)) then
			if tab ~= which then
				page = 1
			end
			tab = which
		end
		if wanted then
			filters.Owned = wanted.Owned == true
			filters.Rarity = if wanted.Rarity and levels[wanted.Rarity] then wanted.Rarity else ANY
			filters.Theme = if wanted.Theme and table.find(themeIds, wanted.Theme)
				then wanted.Theme
				else ANY
			page = 1
		end
		message.Text = ""
		panel.Visible = true
		wasReady = state.Ready
		render()
		refresh()
	end
	local function toggle()
		if panel.Visible then
			panel.Visible = false
		else
			ShopUI.Open()
		end
	end
	shopButton.Activated:Connect(toggle)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- Free the previews' memory while the shop is closed.
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			clearCards()
		end
	end)
	ContextActionService:BindAction("OpenShop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Config.Shop.OpenKey)

	Remotes.Event("ShopState").OnClientEvent:Connect(function(new)
		local before = state.Ready
		setState(new)
		if panel.Visible then
			if state.Ready and not before then
				render()
			else
				afterChange()
			end
		end
	end)
	refresh()
	-- Coins also change at round end; keep the label right while the shop is open.
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 60)
		local coins = stats and stats:WaitForChild("Coins", 60)
		if coins and coins:IsA("IntValue") then
			coins:GetPropertyChangedSignal("Value"):Connect(function()
				local value = coins.Value
				state.Coins = value
				if panel.Visible then
					showCoins(value, true)
				end
			end)
		end
	end)
end

return ShopUI
