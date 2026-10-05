--!strict
--[[
	The shop (title: Config.Shop.Title): a tab per cosmetic slot (Config.Shop.Slots) plus
	"Packs & VIP". Opens from the Menu (Shop, Skins and VIP & Packs tiles), the B key and the
	Pumpkin Shop stall (Config.Npcs OpensShop -> ShopUI.Open(tab), the Skins tab). Every action goes through the server (ShopService); this only shows
	the state it sends back. Each card shows a rarity tag (Config.Rarity) and the price from
	Items.Price. Robux buttons open Roblox's own purchase prompt and are disabled while an ID
	in Config.Monetization is still 0.
]]
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local ShopUI = {}

local openShop: ((string?) -> ())? = nil

-- Opens the shop on `tab` (a slot such as "Hat", or "Packs"). Safe to call before Mount.
function ShopUI.Open(tab: string?)
	if openShop then
		openShop(tab)
	end
end

type State = {
	Ready: boolean,
	Coins: number,
	Owned: { string },
	Equipped: { [string]: string },
	Vip: boolean,
}

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
	return b
end

-- A ViewportFrame showing `model`, framed to fit.
local function preview(model: Model, parent: Instance): ViewportFrame
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
	local distance = size.Magnitude * 1.5 + 0.5
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(distance * 0.45, distance * 0.3, -distance),
		cf.Position
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

function ShopUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local getState = Remotes.Function("GetShopState")
	local buyItem = Remotes.Function("BuyItem")
	local equipItem = Remotes.Function("EquipItem")
	local currency = Config.Economy.CurrencyName

	local state: State = { Ready = false, Coins = 0, Owned = {}, Equipped = {}, Vip = false }
	local tab = Config.Shop.Slots[1]
	local busy = false

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
	-- Phones: nearly full height and shorter cards, so a whole row of cards fits.
	local compact = Layout.IsPhone()
	local cardHeight = if compact then 158 else 190
	local previewHeight = if compact then 72 else 100
	panel.Size = UDim2.new(0.92, 0, if compact then 0.97 else 0.8, 0) -- capped below
	panel.Visible = false
	Layout.Fit(panel)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(660, 460)
	sizeLimit.Parent = panel

	local title = Theme.label(Config.Shop.Title, 22, panel)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(0.6, 0, 0, 32)

	local coinsLabel = Theme.label("", 18, panel)
	coinsLabel.TextColor3 = Theme.Selected
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -56, 0, 8)
	coinsLabel.Size = UDim2.new(0.4, -56, 0, 32)

	local close = button("X", panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(36, 32)

	local tabsBar = Instance.new("Frame")
	tabsBar.BackgroundTransparency = 1
	tabsBar.Position = UDim2.fromOffset(16, 46)
	tabsBar.Size = UDim2.new(1, -32, 0, 34)
	tabsBar.Parent = panel
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = tabsBar

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 88)
	list.Size = UDim2.new(1, -32, 1, if compact then -112 else -130)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local message = Theme.label("", 15, panel)
	message.TextColor3 = Theme.Muted
	message.AnchorPoint = Vector2.new(0, 1)
	message.Position = UDim2.new(0, 16, 1, -8)
	message.Size = UDim2.new(1, -32, 0, 28)

	local tabButtons: { [string]: TextButton } = {}
	local render: () -> ()

	local function owns(id: string): boolean
		return table.find(state.Owned, id) ~= nil
	end

	local function setState(new: any)
		if typeof(new) == "table" and typeof(new.Coins) == "number" then
			state = new
		end
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

	local function act(fn: () -> ())
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then
				message.Text = "Something went wrong, try again."
				warn("[ShopUI] " .. tostring(err))
			end
			busy = false
			render()
		end)
	end

	-- Small coloured rarity label in the top-left corner of a card's preview.
	local function rarityTag(item: any, parent: Frame)
		local info = Items.RarityInfo(item)
		local tag = Theme.label(info.Name, 14, parent)
		tag.Name = "RarityTag"
		tag.ZIndex = 2 -- above the preview
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Position = UDim2.fromOffset(12, 12)
		tag.Size = UDim2.fromOffset(0, 20)
		tag.BackgroundTransparency = 0.1
		tag.BackgroundColor3 = info.Color
		tag.TextStrokeTransparency = 0.6
		Theme.round(tag, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = tag
	end

	local function renderItems(slot: string)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(140, cardHeight)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = list
		for index, item in Config.Shop.Items do
			if item.Slot ~= slot then
				continue
			end
			local frame = card(cardHeight)
			frame.LayoutOrder = index
			local view = preview(Cosmetics.Preview(item), frame)
			view.Position = UDim2.fromOffset(8, 8)
			view.Size = UDim2.new(1, -16, 0, previewHeight)
			rarityTag(item, frame)

			local name = Theme.label(item.Name, 14, frame)
			name.TextWrapped = true
			name.Position = UDim2.fromOffset(6, previewHeight + 10)
			name.Size = UDim2.new(1, -12, 0, 34)

			local price = Items.Price(item)
			local usable = if item.VipOnly then state.Vip else owns(item.Id)
			local equipped = state.Equipped[slot] == item.Id
			local action = button("", frame)
			action.Position = UDim2.new(0, 8, 1, -40)
			action.Size = UDim2.new(1, -16, 0, 32)
			if equipped then
				action.Text = "Unequip"
				action.Activated:Connect(function()
					act(function()
						setState(equipItem:InvokeServer(slot, ""))
						message.Text = ""
					end)
				end)
			elseif usable then
				action.Text = "Equip"
				action.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
				action.Activated:Connect(function()
					act(function()
						setState(equipItem:InvokeServer(slot, item.Id))
						message.Text = "Wearing " .. item.Name .. "."
					end)
				end)
			elseif item.VipOnly then
				action.Text = Config.Monetization.VipName .. " only"
				action.BackgroundColor3 = Color3.fromRGB(120, 95, 30)
				action.Activated:Connect(function()
					ShopUI.Open("Packs")
				end)
			elseif price == nil then
				-- Not sold for coins (CrateOnly): only crates give it.
				action.Text = "From crates"
				action.AutoButtonColor = false
				action.BackgroundColor3 = Color3.fromRGB(70, 65, 80)
			else
				action.Text = ("Buy  %d"):format(price)
				action.BackgroundColor3 = Theme.Selected
				action.Activated:Connect(function()
					act(function()
						local bought, text, new = buyItem:InvokeServer(item.Id)
						if bought then
							Sounds.Play("Purchase")
						end
						setState(new)
						message.Text = tostring(text)
					end)
				end)
			end
		end
	end

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
		vip.Size = UDim2.new(1, -10, 0, 150)
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
			row.LayoutOrder = index
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

	render = function()
		coinsLabel.Text = ("%d %s"):format(state.Coins, currency)
		for id, b in tabButtons do
			b.BackgroundColor3 = if id == tab then Theme.Selected else Theme.Button
		end
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		if not state.Ready then
			local wait = Theme.label("Loading your bag...", 16, list)
			wait.Size = UDim2.new(1, 0, 0, 40)
			return
		end
		if tab == "Packs" then
			renderPacks()
		else
			renderItems(tab)
		end
	end

	local tabIds = table.clone(Config.Shop.Slots)
	table.insert(tabIds, "Packs")
	for i, id in tabIds do
		local b =
			button(if id == "Packs" then "Packs & VIP" else Config.Shop.SlotNames[id], tabsBar)
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(if id == "Packs" then 130 else 100, 34)
		b.Activated:Connect(function()
			tab = id
			message.Text = ""
			render()
		end)
		tabButtons[id] = b
	end

	local function refresh()
		task.spawn(function()
			local ok, new = pcall(function()
				return getState:InvokeServer()
			end)
			if ok then
				setState(new)
			end
			if panel.Visible then
				render()
			end
		end)
	end

	openShop = function(which: string?)
		if which and (which == "Packs" or table.find(Config.Shop.Slots, which)) then
			tab = which
		end
		message.Text = ""
		panel.Visible = true
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
	ContextActionService:BindAction("OpenShop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Config.Shop.OpenKey)

	Remotes.Event("ShopState").OnClientEvent:Connect(function(new)
		setState(new)
		if panel.Visible then
			render()
		end
	end)
	refresh()
	-- Coins also change at round end; keep the label right while the shop is open.
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 60)
		local coins = stats and stats:WaitForChild("Coins", 60)
		if coins and coins:IsA("IntValue") then
			coins.Changed:Connect(function(value)
				state.Coins = value
				if panel.Visible then
					coinsLabel.Text = ("%d %s"):format(value, currency)
				end
			end)
		end
	end)
end

return ShopUI
