--!strict
--[[
	The crate panel (Config.Crates): every crate, what's inside each one with its exact chance,
	and the opening animation. On/off: Config.Features.Crates (off = Mount and Open do nothing).

	Opens from Menu > Crates, the crate stand in the lobby (prompts with a CrateId attribute)
	and the Shop's Skins tab. Three views in one panel (named "Crates"):
	  list      a card per crate: its chest turning slowly (only cards on screen) on a halo in
	            its Glow colour, name, price, a NEW ribbon (crate New = true) and an "Odds"
	            button straight to its page (Config.Crates.Cards)
	  preview   one crate: EVERY skin inside with its rarity colour and % chance (Roblox
	            requires the odds to be shown before buying), and the Open buttons, labelled
	            "Open 600 Coins" / "R$ 79" so coins and Robux are never confused
	  opening   Config.Crates.Opening.Style "Chest": the chest drops in, shakes faster and
	            faster, the lid bursts open with a beam in the colour of the rarity really won
	            (rainbow + full-screen confetti for CRAZY), the skin flies onto a spinning
	            pedestal (a duplicate pours coins: "+X coins back"); Style "Reel": a strip of
	            skin cards spins and slows down on the result. Then the reveal card (rarity
	            glow), "Equip now", "Open another", and "Duplicate! +X coins" when you already
	            had it. Space or a tap skips to the reveal; Quick open shows them all at once.
	Nothing is decided here: the server (CrateService) takes the coins, rolls and gives the skin
	before the chest even drops; the beam, the strip and the reveal only show that result.
	Players whose region doesn't allow paid random items (player attribute CratesRestricted)
	see the odds but no buy buttons.

	CrateUI.Mount(gui)
	CrateUI.Open(crateId?)        opens the panel, on that crate's preview if given. Safe to call
	                              before Mount (does nothing until then).
	CrateUI.SetShopOpener(fn)     fn({ Theme?, Rarity? }) opens the Shop's Skins tab on those
	                              filters (ShopUI sets this; the
	                              crate preview's "Buy in the Shop" button uses it)
]]

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local CrateArt = require(ReplicatedStorage.Shared.CrateArt)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local CrateOdds = require(ReplicatedStorage.Shared.CrateOdds)
local Items = require(ReplicatedStorage.Shared.Items)
local FramePace = require(script.Parent.FramePace)
local Layout = require(script.Parent.Layout)
local PanelManager = require(script.Parent.PanelManager)
local SkinFx = require(script.Parent.SkinFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local CrateUI = {}

-- What the server sends back (CrateService.Result).
export type Result = {
	Ok: boolean,
	Message: string,
	CrateId: string,
	ItemId: string?,
	ItemName: string?,
	Rarity: string?,
	Duplicate: boolean?,
	Refund: number?,
	Reel: { string }?,
	WinIndex: number?,
	Paid: string?,
	OneInAMillion: boolean?,
	Results: { Result }?, -- every result, when several crates were opened at once
}

type Net = {
	Open: RemoteFunction,
	Result: RemoteEvent,
	Equip: RemoteFunction,
	GetState: RemoteFunction,
	State: RemoteEvent,
}

-- A 3D preview that is built only when it scrolls into view.
type LazyView = {
	Holder: Frame,
	Build: () -> Model,
	Stop: () -> (),
	Built: boolean,
	Spin: boolean?, -- turns slowly while on screen (the crate cards)
	Clear: boolean?, -- no background (a halo shows through)
	Model: Model?,
	Base: CFrame?, -- the model's pivot when built
}

local openPanel: ((string?) -> ())? = nil
export type ShopFilters = { Theme: string?, Rarity: string? }

local shopOpener: ((ShopFilters) -> ())? = nil

function CrateUI.Open(crateId: string?)
	if not Config.Features.Crates then
		return
	end
	if openPanel then
		openPanel(crateId)
	end
end

function CrateUI.SetShopOpener(fn: (ShopFilters) -> ())
	shopOpener = fn
end

-- Checks the shape of a result from the server (never trust a table blindly).
local function asResult(value: unknown): Result?
	if typeof(value) ~= "table" then
		return nil
	end
	local r = value :: any
	if type(r.Ok) ~= "boolean" or type(r.CrateId) ~= "string" then
		return nil
	end
	if r.Ok then
		if
			type(r.ItemId) ~= "string"
			or type(r.Reel) ~= "table"
			or type(r.WinIndex) ~= "number"
		then
			return nil
		end
		if r.Reel[r.WinIndex] ~= r.ItemId then
			return nil
		end
		-- Several at once: every one must be a proper result too.
		if r.Results ~= nil then
			if type(r.Results) ~= "table" or #r.Results < 1 or #r.Results > 10 then
				return nil
			end
			for _, one in r.Results do
				if
					type(one) ~= "table"
					or one.Ok ~= true
					or type(one.ItemId) ~= "string"
					or type(one.Reel) ~= "table"
					or type(one.WinIndex) ~= "number"
					or one.Reel[one.WinIndex] ~= one.ItemId
				then
					return nil
				end
				if type(one.Message) ~= "string" then
					one.Message = ""
				end
				if type(one.CrateId) ~= "string" then
					one.CrateId = r.CrateId
				end
			end
		end
	end
	if type(r.Message) ~= "string" then
		r.Message = ""
	end
	return r :: Result
end

local function rarityLevel(rarity: string?): any
	return (Config.Rarity.Levels :: any)[rarity or ""]
		or (Config.Rarity.Levels :: any)[Config.Rarity.Default]
end

-- 80000 -> "80,000" (easier to read for big prices).
local function commas(n: number): string
	local whole = tostring(math.floor(n))
	local out = whole
	while true do
		local swapped, count = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		out = swapped
		if count == 0 then
			break
		end
	end
	return out
end

-- "FF8014" for RichText colours.
local function hex(color: Color3): string
	return ("%02X%02X%02X"):format(
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function rainbowSequence(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.75, 1)))
	end
	return ColorSequence.new(keys)
end

local function button(text: string, parent: Instance?, color: Color3?): TextButton
	local b = Theme.button(text, parent, color)
	b.TextSize = 15
	b.TextWrapped = true
	return b
end

local function label(text: string, size: number, parent: Instance): TextLabel
	local l = Theme.label(text, size, parent)
	l.TextWrapped = true
	return l
end

-- Fills `viewport` with `model`, framed from the front (-Z) and a little to the side.
local function showModel(viewport: ViewportFrame, model: Model, zoom: number)
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = (size.Magnitude * 1.5 + 0.5) * zoom
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(distance * 0.45, distance * 0.3, -distance),
		cf.Position
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function newViewport(parent: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
	viewport.Ambient = Color3.fromRGB(200, 190, 210)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	Theme.round(viewport, 8)
	return viewport
end

-- Is `gui` on screen inside `clip` (plus `margin` pixels)? Layout sizes are 0 before the
-- first frame, which counts as not visible yet.
local function inView(gui: GuiObject, clip: GuiObject, margin: number): boolean
	local size = clip.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return false
	end
	local a, b = gui.AbsolutePosition, gui.AbsolutePosition + gui.AbsoluteSize
	local lo, hi = clip.AbsolutePosition, clip.AbsolutePosition + size
	return b.X >= lo.X - margin
		and a.X <= hi.X + margin
		and b.Y >= lo.Y - margin
		and a.Y <= hi.Y + margin
end

function CrateUI.Mount(gui: ScreenGui)
	if not Config.Features.Crates then
		return
	end
	local player = Players.LocalPlayer
	local cfg = Config.Crates
	local text = cfg.Text
	local currency = Config.Economy.CurrencyName
	local compact = Layout.IsPhone()
	local reelCfg = cfg.Reel
	local cardW = if compact then reelCfg.PhoneCardWidth else reelCfg.CardWidth
	local cardGap = reelCfg.CardGap
	local reelHeight = if compact then 128 else 156

	local net: Net? = nil
	local owned: { [string]: boolean } = {}
	local coins = 0
	local busy = false -- an open is on its way to the server or spinning
	local current: CrateOdds.Crate? = nil -- the crate on the preview / opening view
	local lastPaid = "Coins"
	local unseen: Result? = nil -- a result whose spin was cut short (panel closed)
	local lazyViews: { LazyView } = {}
	local spinConnection: RBXScriptConnection? = nil
	local skipConnection: RBXScriptConnection? = nil
	local burstConnection: RBXScriptConnection? = nil
	local revealStop: () -> () = function() end
	local queue: { Result } = {} -- results of a multi-open still to be shown
	local quickOpen = cfg.QuickOpen.Default -- the "Quick open" switch: no strip, all results at once
	local lastCount = 1 -- how many were opened last time (Open another opens as many)
	local listCategory: string? = nil -- the tab and page of the crate list
	local listPage = 1
	local skipNow: (() -> ())? = nil -- jumps the spinning strip to its result

	-- Panel ---------------------------------------------------------------------------------
	local panel = Theme.panel(gui)
	panel.Name = "Crates"
	panel.ZIndex = 10
	panel.BackgroundTransparency = 0.03
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(if compact then 0.96 else 0.92, if compact then 0.97 else 0.84)
	panel.Visible = false
	panel.ClipsDescendants = true
	Layout.Fit(panel)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(720, 480)
	sizeLimit.Parent = panel
	PanelManager.Register(panel)

	local title = label(text.Title, 22, panel)
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(0.55, 0, 0, 32)

	local coinsLabel = label("", 18, panel)
	coinsLabel.Name = "Coins"
	coinsLabel.TextColor3 = Theme.Selected
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -56, 0, 8)
	coinsLabel.Size = UDim2.new(0.4, -56, 0, 32)

	local close = button("X", panel)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(36, 32)

	local message = label(text.Hint, 14, panel)
	message.Name = "Message"
	message.TextColor3 = Theme.Muted
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.Position = UDim2.fromOffset(16, 42)
	local messageHeight = if compact then 44 else 34 -- room for 3 lines on narrow phones
	message.Size = UDim2.new(1, -32, 0, messageHeight)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, 46 + messageHeight)
	body.Size = UDim2.new(1, -24, 1, -(56 + messageHeight))
	body.Parent = panel

	local function view(name: string): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.Visible = false
		f.Parent = body
		return f
	end
	local listView = view("List")
	local previewView = view("Preview")
	local openView = view("Opening")

	-- Phones: while a crate opens, the hint line goes and the chest gets its room (a short
	-- landscape phone has little height to spare).
	if compact then
		local function fitBody()
			-- (also whenever the line is only the hint; messages that matter, like "You need X more
			-- coins" or the region rule, still show)
			local full = openView.Visible or message.Text == text.Hint or message.Text == ""
			message.Visible = not full
			local top = if full then 46 else 46 + messageHeight
			body.Position = UDim2.fromOffset(12, top)
			body.Size = UDim2.new(1, -24, 1, -(top + 10))
		end
		openView:GetPropertyChangedSignal("Visible"):Connect(fitBody)
		message:GetPropertyChangedSignal("Text"):Connect(fitBody)
		fitBody()
	end
	local resultsView = view("Results") -- quick open: every result on one page

	local function setMessage(value: string, important: boolean?)
		message.Text = value
		message.TextColor3 = if important then Theme.Selected else Theme.Muted
	end

	local function restriction(): boolean? -- true = closed, false = open, nil = still checking
		local value = player:GetAttribute("CratesRestricted")
		if typeof(value) == "boolean" then
			return value
		end
		return nil
	end

	local function defaultMessage()
		if restriction() == true then
			setMessage(text.Restricted, true)
		else
			setMessage(text.Hint)
		end
	end

	local function updateCoins()
		coinsLabel.Text = ("%s %s"):format(commas(coins), currency)
	end

	-- Lazy 3D previews -------------------------------------------------------------------------
	local function lazy(holder: Frame, build: () -> Model, spin: boolean?)
		table.insert(lazyViews, {
			Holder = holder,
			Build = build,
			Stop = function() end,
			Built = false,
			Spin = spin,
			Clear = spin,
		})
	end

	local function buildView(entry: LazyView, zoom: number?)
		entry.Built = true
		local ok, model = pcall(entry.Build)
		if not ok or not model then
			warn("[CrateUI] preview failed: " .. tostring(model))
			return
		end
		local viewport = newViewport(entry.Holder)
		viewport.Size = UDim2.fromScale(1, 1)
		if entry.Clear then
			viewport.BackgroundTransparency = 1
		end
		showModel(viewport, model, zoom or 1)
		entry.Model = model
		entry.Base = model:GetPivot()
		entry.Stop = SkinFx.AnimatePreview(model)
	end

	local function clearLazy(root: Instance)
		local keep = {}
		for _, entry in lazyViews do
			if entry.Holder:IsDescendantOf(root) then
				entry.Stop()
			else
				table.insert(keep, entry)
			end
		end
		lazyViews = keep
	end

	local function clear(root: Instance)
		clearLazy(root)
		for _, child in root:GetChildren() do
			child:Destroy()
		end
	end

	-- A list's 3D preview that has scrolled this far (pixels) out of view is taken down again
	-- (and built again if it comes back), so a big crate like the Common Crate never keeps
	-- dozens of 3D models alive at once.
	local KEEP_DISTANCE = 400
	local function unbuildView(entry: LazyView)
		entry.Stop()
		entry.Stop = function() end
		entry.Built = false
		entry.Model = nil
		local viewport = entry.Holder:FindFirstChild("Preview")
		if viewport then
			viewport:Destroy()
		end
	end

	-- A few previews per check, so scrolling never stutters.
	-- (connected only while the panel is open: a closed panel runs nothing per frame)
	local nextLazy = 0
	FramePace.WhileVisible(panel, RunService.Heartbeat, function()
		if #lazyViews == 0 then
			return
		end
		local now = os.clock()
		if now < nextLazy then
			return
		end
		nextLazy = now + 0.1
		local made = 0
		for _, entry in lazyViews do
			local scroller = entry.Holder:FindFirstAncestorWhichIsA("ScrollingFrame")
			if entry.Built then
				-- (only in a laid-out scrolling list: the reel's cards are never taken down)
				if
					scroller
					and scroller.AbsoluteSize.X > 0
					and scroller.AbsoluteSize.Y > 0
					and not inView(entry.Holder, scroller, KEEP_DISTANCE)
				then
					unbuildView(entry)
				end
			elseif made < 3 then
				local clip: GuiObject = scroller or body
				if inView(entry.Holder, clip, 60) then
					buildView(entry)
					made += 1
				end
			end
		end
	end)

	-- The crate cards' chests turn slowly: only built ones (near the screen) that are really on
	-- screen, only while the list is showing (nothing runs once the panel closes).
	local cardsCfg = cfg.Cards
	FramePace.WhileVisible(panel, RunService.Heartbeat, function()
		local speed = cardsCfg.SpinSpeed
		if speed == 0 or not listView.Visible then
			return
		end
		local yaw = math.rad((os.clock() * speed) % 360)
		for _, entry in lazyViews do
			local model, base = entry.Model, entry.Base
			if entry.Spin and model and base and model.Parent then
				local scroller = entry.Holder:FindFirstAncestorWhichIsA("ScrollingFrame")
				if scroller and inView(entry.Holder, scroller, 0) then
					model:PivotTo(base * CFrame.Angles(0, yaw, 0))
				end
			end
		end
	end)

	-- Buy buttons ----------------------------------------------------------------------------
	local priceCache: { [number]: number } = {}
	local function realPrice(id: number, b: TextButton)
		if id == 0 then
			return
		end
		if priceCache[id] then
			b.Text = text.OpenRobux:format(priceCache[id])
			return
		end
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			-- (No price, or 0, keeps the suggested price already on the button.)
			if
				ok
				and type(info) == "table"
				and typeof(info.PriceInRobux) == "number"
				and info.PriceInRobux > 0
			then
				priceCache[id] = info.PriceInRobux
				b.Text = text.OpenRobux:format(info.PriceInRobux)
			end
		end)
	end

	local function disable(b: TextButton, words: string)
		b.Text = words
		b.AutoButtonColor = false
		b.Active = false
		b.BackgroundColor3 = Color3.fromRGB(70, 65, 80)
	end

	-- Forward declarations (the views call each other).
	local showList: () -> ()
	local showPreview: (crate: CrateOdds.Crate) -> ()
	local openWithCoins: (crate: CrateOdds.Crate, count: number?) -> ()
	local showResults: (all: { Result }) -> ()
	local playNext: () -> ()
	local openWithRobux: (crate: CrateOdds.Crate) -> ()
	local playResult: (result: Result) -> ()

	local function showOnly(which: Frame)
		for _, v in { listView, previewView, openView, resultsView } do
			v.Visible = v == which
		end
	end

	-- List view: one card per crate --------------------------------------------------------------
	local function crateCard(parent: Instance, crate: CrateOdds.Crate, order: number)
		local card = Instance.new("TextButton")
		card.Name = crate.Id
		card.Text = ""
		card.AutoButtonColor = true
		card.BackgroundColor3 = Theme.Button
		card.BackgroundTransparency = 0.2
		card.LayoutOrder = order
		card.Parent = parent
		Theme.round(card, 10)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = crate.Color
		stroke.Thickness = 2
		stroke.Parent = card
		if crate.Rarity and rarityLevel(crate.Rarity).Rainbow then
			stroke.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = rainbowSequence()
			gradient.Parent = stroke
		end

		-- A soft halo in the crate's Glow colour behind its turning chest.
		if cardsCfg.Halo then
			local halo = Instance.new("Frame")
			halo.Name = "Halo"
			halo.BorderSizePixel = 0
			halo.BackgroundColor3 = crate.Glow
			halo.BackgroundTransparency = cardsCfg.HaloTransparency
			halo.AnchorPoint = Vector2.new(0.5, 0.5)
			halo.Position = UDim2.new(0.5, 0, 0.5, -26) -- (centred on the picture)
			halo.Size = UDim2.fromScale(0.72, 0.5)
			halo.Parent = card
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = halo
			local soft = Instance.new("UIGradient")
			soft.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.9),
			})
			soft.Parent = halo
		end
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromOffset(6, 6)
		art.Size = UDim2.new(1, -12, 1, -64)
		art.Parent = card
		lazy(art, function()
			return CrateArt.Preview(crate)
		end, true)
		if CrateLook.IsNew(crate) then
			local ribbon = label(text.NewRibbon, 14, card)
			ribbon.Name = "NewRibbon"
			ribbon.ZIndex = 3
			ribbon.TextWrapped = false
			ribbon.AutomaticSize = Enum.AutomaticSize.X
			ribbon.BackgroundTransparency = 0
			ribbon.BackgroundColor3 = Color3.fromRGB(230, 40, 70)
			ribbon.TextStrokeTransparency = 0.6
			ribbon.Position = UDim2.fromOffset(6, 6)
			ribbon.Size = UDim2.fromOffset(0, 20)
			Theme.round(ribbon, 6)
			local ribbonPad = Instance.new("UIPadding")
			ribbonPad.PaddingLeft = UDim.new(0, 6)
			ribbonPad.PaddingRight = UDim.new(0, 6)
			ribbonPad.Parent = ribbon
		end
		-- One tap to every skin inside and its exact chance.
		local oddsButton = button(text.OddsButton, card)
		oddsButton.Name = "Odds"
		oddsButton.ZIndex = 3
		oddsButton.TextSize = 14
		oddsButton.TextWrapped = false
		oddsButton.AnchorPoint = Vector2.new(1, 0)
		oddsButton.Position = UDim2.new(1, -6, 0, 6)
		oddsButton.Size = UDim2.fromOffset(48, 22)
		oddsButton.BackgroundTransparency = 0.15
		oddsButton.Activated:Connect(function()
			showPreview(crate)
		end)

		local name = label(crate.Name, 15, card)
		name.Name = "CrateName"
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.new(0, 4, 1, -26)
		name.Size = UDim2.new(1, -8, 0, 30)
		local price = CrateOdds.CoinPrice(crate)
		local priceLabel = label(
			if price then ("%s %s"):format(commas(price), currency) else text.RobuxOnly,
			14,
			card
		)
		priceLabel.Name = "Price"
		priceLabel.TextColor3 = Theme.Selected
		priceLabel.AnchorPoint = Vector2.new(0, 1)
		priceLabel.Position = UDim2.new(0, 4, 1, -6)
		priceLabel.Size = UDim2.new(1, -8, 0, 20)
		if crate.Rarity then
			local level = rarityLevel(crate.Rarity)
			local tag = label(("100%% %s"):format(level.Name), 14, card)
			tag.Name = "RarityTag"
			tag.ZIndex = 2
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.TextWrapped = false
			tag.Position = UDim2.fromOffset(10, 10)
			tag.Size = UDim2.fromOffset(0, 20)
			tag.BackgroundTransparency = 0.1
			tag.BackgroundColor3 = level.Color
			tag.TextStrokeTransparency = 0.6
			Theme.round(tag, 6)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 6)
			pad.Parent = tag
		end
		-- A quick bounce, then the crate's page.
		local pop = Instance.new("UIScale")
		pop.Parent = card
		local popping = false
		card.Activated:Connect(function()
			if popping then
				return
			end
			popping = true
			local seconds = math.max(0, cardsCfg.PopSeconds)
			pop.Scale = 0.9
			TweenService:Create(
				pop,
				TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
			task.delay(seconds, function()
				popping = false
				-- (unless the list was left meanwhile)
				if card.Parent and listView.Visible and panel.Visible then
					showPreview(crate)
				end
			end)
		end)
	end

	-- The crates on one tab (Config.Crates.Categories; a crate with no Category is on the first).
	local function categoryOf(crate: CrateOdds.Crate): string
		return crate.Category or cfg.Categories[1]
	end
	local function cratesIn(category: string): { CrateOdds.Crate }
		local list = {}
		for _, crate in CrateOdds.List() do
			if categoryOf(crate) == category then
				table.insert(list, crate)
			end
		end
		return list
	end

	-- A tab per category along the top, one page of crate cards, and Prev / Next at the bottom.
	showList = function()
		current = nil
		clear(listView)
		showOnly(listView)
		defaultMessage()
		local category = listCategory or cfg.Categories[1]
		if #cratesIn(category) == 0 then
			category = categoryOf(CrateOdds.List()[1] or ({} :: any))
		end
		local tabs = Instance.new("ScrollingFrame")
		tabs.Name = "Categories"
		tabs.BackgroundTransparency = 1
		tabs.BorderSizePixel = 0
		tabs.Size = UDim2.new(1, 0, 0, 34)
		tabs.ScrollBarThickness = 3
		tabs.ScrollingDirection = Enum.ScrollingDirection.X
		tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
		tabs.CanvasSize = UDim2.new()
		tabs.Parent = listView
		local tabList = Instance.new("UIListLayout")
		tabList.FillDirection = Enum.FillDirection.Horizontal
		tabList.Padding = UDim.new(0, 6)
		tabList.SortOrder = Enum.SortOrder.LayoutOrder
		tabList.Parent = tabs
		for i, name in cfg.Categories do
			if #cratesIn(name) == 0 then
				continue
			end
			local tab = button(name, tabs, if name == category then Theme.Selected else nil)
			tab.Name = "Tab" .. i
			tab:SetAttribute("Category", name)
			tab.LayoutOrder = i
			tab.TextSize = 14
			tab.TextWrapped = false
			tab.AutomaticSize = Enum.AutomaticSize.X
			tab.Size = UDim2.new(0, 0, 1, -6)
			local tabPad = Instance.new("UIPadding")
			tabPad.PaddingLeft = UDim.new(0, 10)
			tabPad.PaddingRight = UDim.new(0, 10)
			tabPad.Parent = tab
			tab.Activated:Connect(function()
				listCategory = name
				listPage = 1
				showList()
			end)
		end

		local crates = cratesIn(category)
		local perPage = math.max(1, if compact then cfg.PhonePageSize else cfg.PageSize)
		local pages = math.max(1, math.ceil(#crates / perPage))
		listPage = math.clamp(listPage, 1, pages)
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "Crates"
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.Position = UDim2.fromOffset(0, 38)
		scroller.Size = UDim2.new(1, 0, 1, -(38 + 36))
		scroller.ScrollBarThickness = 6
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.CanvasSize = UDim2.new()
		scroller.Parent = listView
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = if compact then UDim2.fromOffset(124, 168) else UDim2.fromOffset(150, 196)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroller
		if compact then
			-- Phones: a whole card (chest, name and price) fits the list's height, so nothing is cut
			-- off below; the chest shrinks a little on the shortest screens.
			local function fitCards()
				local fit = panel:FindFirstChild("FitScale")
				local scale = if fit and fit:IsA("UIScale") and fit.Scale > 0 then fit.Scale else 1
				local room = scroller.AbsoluteSize.Y / scale - 8
				if room > 0 then
					grid.CellSize = UDim2.fromOffset(124, math.clamp(math.floor(room), 118, 168))
				end
			end
			scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
			fitCards()
		end
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.Parent = scroller
		local first = (listPage - 1) * perPage + 1
		for i = first, math.min(#crates, first + perPage - 1) do
			crateCard(scroller, crates[i], i)
		end

		local pager = Instance.new("Frame")
		pager.Name = "Pager"
		pager.BackgroundTransparency = 1
		pager.AnchorPoint = Vector2.new(0.5, 1)
		pager.Position = UDim2.fromScale(0.5, 1)
		pager.Size = UDim2.fromOffset(260, 32)
		pager.Visible = pages > 1
		pager.Parent = listView
		local prev = button("<", pager)
		prev.Name = "Prev"
		prev.Size = UDim2.fromOffset(60, 32)
		local pageLabel = label(text.Page:format(listPage, pages), 15, pager)
		pageLabel.Name = "Page"
		pageLabel.Position = UDim2.fromOffset(66, 0)
		pageLabel.Size = UDim2.fromOffset(128, 32)
		local nextButton = button(">", pager)
		nextButton.Name = "Next"
		nextButton.Position = UDim2.fromOffset(200, 0)
		nextButton.Size = UDim2.fromOffset(60, 32)
		prev.Activated:Connect(function()
			listCategory = category
			listPage = if listPage > 1 then listPage - 1 else pages
			showList()
		end)
		nextButton.Activated:Connect(function()
			listCategory = category
			listPage = if listPage < pages then listPage + 1 else 1
			showList()
		end)
	end

	-- Preview view: every skin and its chance ---------------------------------------------------
	local function itemCard(parent: Instance, chance: CrateOdds.Chance, order: number)
		local item = chance.Item
		local level = rarityLevel(chance.Rarity)
		local card = Instance.new("Frame")
		card.Name = item.Id
		card.BackgroundColor3 = Theme.Button
		card.BackgroundTransparency = 0.3
		card.LayoutOrder = order
		card.Parent = parent
		Theme.round(card, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "RarityBorder"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = level.Color
		stroke.Thickness = if chance.Rarity == Config.Rarity.Default then 1.5 else 2.5
		stroke.Parent = card
		if level.Rainbow then
			stroke.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = rainbowSequence()
			gradient.Parent = stroke
		end
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromOffset(5, 5)
		art.Size = UDim2.new(1, -10, 1, -62)
		art.Parent = card
		lazy(art, function()
			return Cosmetics.Preview(item)
		end)
		local name = label(item.Name, 14, card)
		name.Name = "ItemName"
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.new(0, 3, 1, -22)
		name.Size = UDim2.new(1, -6, 0, 34)
		local odds = label(CrateOdds.Format(chance.Chance), 14, card)
		odds.Name = "Chance"
		odds.TextColor3 = level.Color:Lerp(Color3.new(1, 1, 1), 0.25)
		odds.AnchorPoint = Vector2.new(0, 1)
		odds.Position = UDim2.new(0, 3, 1, -4)
		odds.Size = UDim2.new(1, -6, 0, 18)
		local rarityTag = label(level.Name, 14, card)
		rarityTag.Name = "Rarity"
		rarityTag.ZIndex = 2
		rarityTag.TextWrapped = false
		rarityTag.TextXAlignment = Enum.TextXAlignment.Left
		rarityTag.TextColor3 = level.Color:Lerp(Color3.new(1, 1, 1), 0.2)
		rarityTag.TextStrokeTransparency = 0.4
		rarityTag.Position = UDim2.fromOffset(8, 6)
		rarityTag.Size = UDim2.new(1, -16, 0, 16)
		if owned[item.Id] then
			local tick = label("✓ " .. text.Owned, 14, card)
			tick.Name = "Owned"
			tick.ZIndex = 2
			tick.TextWrapped = false
			tick.TextXAlignment = Enum.TextXAlignment.Right
			tick.TextColor3 = Color3.fromRGB(140, 235, 140)
			tick.TextStrokeTransparency = 0.4
			tick.AnchorPoint = Vector2.new(1, 0)
			tick.Position = UDim2.new(1, -8, 0, 22)
			tick.Size = UDim2.fromOffset(70, 16)
		end
	end

	-- The rarity totals, e.g. "CRAZY 0.1%  Rare 5%  Uncommon 24.9%  Common 70%".
	local function oddsLine(crate: CrateOdds.Crate): string
		local odds = CrateOdds.RarityOdds(crate)
		local parts = {}
		for i = #Config.Rarity.Order, 1, -1 do
			local rarity = Config.Rarity.Order[i]
			local share = odds[rarity]
			if share then
				local level = rarityLevel(rarity)
				local shown = if share > 0 and share < 0.001
					then CrateOdds.Format(share):gsub("%%$", "")
					else ("%.3f"):format(share):gsub("0+$", ""):gsub("%.$", "")
				table.insert(
					parts,
					('<font color="#%s">%s %s%%</font>'):format(hex(level.Color), level.Name, shown)
				)
			end
		end
		return table.concat(parts, "   ")
	end

	local function themeOf(crate: CrateOdds.Crate): string?
		for _, theme in Config.Skins.Themes do
			if theme.Crate == crate.Id then
				return theme.Id
			end
		end
		return nil
	end

	showPreview = function(crate: CrateOdds.Crate)
		current = crate
		listCategory = categoryOf(crate) -- (Back returns to its tab)
		clear(previewView)
		showOnly(previewView)
		defaultMessage()
		local sideWidth = if compact then 168 else 214
		local closed = restriction()

		-- Left: the crate, its odds and the buttons (scrolls on short screens). On phones the
		-- buttons are pinned under the scrolling part instead, so they are always in view.
		local buttonsHeight = (if closed ~= true then (40 + 6) + (34 + 6) else 0) + 32
		local side = Instance.new("ScrollingFrame")
		side.Name = "Side"
		side.BackgroundTransparency = 1
		side.BorderSizePixel = 0
		side.Size = if compact
			then UDim2.new(0, sideWidth, 1, -(buttonsHeight + 6))
			else UDim2.new(0, sideWidth, 1, 0)
		side.ScrollBarThickness = 4
		side.AutomaticCanvasSize = Enum.AutomaticSize.Y
		side.CanvasSize = UDim2.new()
		side.Parent = previewView
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 6)
		list.Parent = side
		local buttonsParent: Instance = side
		if compact then
			local pinned = Instance.new("Frame")
			pinned.Name = "Buttons"
			pinned.BackgroundTransparency = 1
			pinned.AnchorPoint = Vector2.new(0, 1)
			pinned.Position = UDim2.fromScale(0, 1)
			pinned.Size = UDim2.fromOffset(sideWidth, buttonsHeight)
			pinned.Parent = previewView
			local pinnedList = Instance.new("UIListLayout")
			pinnedList.SortOrder = Enum.SortOrder.LayoutOrder
			pinnedList.Padding = UDim.new(0, 6)
			pinnedList.Parent = pinned
			buttonsParent = pinned
		end

		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.LayoutOrder = 1
		art.Size = UDim2.new(1, -8, 0, if compact then 72 else 120)
		art.Parent = side
		lazy(art, function()
			return CrateArt.Preview(crate)
		end)
		local name = label(crate.Name, 20, side)
		name.Name = "CrateName"
		name.LayoutOrder = 2
		name.Size = UDim2.new(1, -8, 0, 24)
		local blurb = label(crate.Blurb, 14, side)
		blurb.Name = "Blurb"
		blurb.Font = Enum.Font.Gotham
		blurb.TextColor3 = Theme.Muted
		blurb.LayoutOrder = 3
		blurb.Size = UDim2.new(1, -8, 0, 0)
		blurb.AutomaticSize = Enum.AutomaticSize.Y
		local odds = label(oddsLine(crate), 14, side)
		odds.Name = "Odds"
		odds.RichText = true
		odds.LayoutOrder = 4
		odds.Size = UDim2.new(1, -8, 0, 0)
		odds.AutomaticSize = Enum.AutomaticSize.Y

		local function row(order: number, height: number): Frame
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.LayoutOrder = order
			f.Size = UDim2.new(1, -8, 0, height)
			f.Parent = buttonsParent
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 6)
			layout.Parent = f
			return f
		end
		-- Open x1 / x5 / x10 for coins (Config.Crates.Open.Counts), then Robux and Quick open.
		local buyRow = row(5, 40)
		buyRow.Name = "Buy"
		buyRow.Visible = closed ~= true
		local extras = row(6, 34)
		extras.Name = "Extras"
		extras.Visible = closed ~= true
		local price = CrateOdds.CoinPrice(crate)
		local robuxOn = Config.Features.RobuxCrates
		local half = UDim2.new(0.5, -3, 1, 0)
		local counts = cfg.Open.Counts
		local buyLayout = buyRow:FindFirstChildOfClass("UIListLayout")
		if buyLayout then
			buyLayout.SortOrder = Enum.SortOrder.LayoutOrder -- x1, x5, x10 in Config order
		end
		if price then
			for order, count in counts do
				-- Always with the currency word ("Open 600 Coins"), never a bare number.
				local words = if count == 1
					then text.OpenCoins:format(commas(price), currency)
					else text.OpenMany:format(count, commas(price * count), currency)
				local openButton = button(words, buyRow, Theme.Selected)
				openButton.Name = if count == 1 then "OpenCoins" else "OpenCoins" .. count
				openButton.LayoutOrder = order
				openButton.TextSize = 13
				openButton.Size = UDim2.new(1 / #counts, -4, 1, 0)
				if closed == nil then
					disable(openButton, text.Checking)
				else
					openButton.Activated:Connect(function()
						openWithCoins(crate, count)
					end)
				end
			end
		end
		if robuxOn then
			local id = CrateOdds.ProductId(crate)
			local robux = crate.Robux
			local robuxButton = button(
				text.OpenRobux:format(if robux then robux.SuggestedRobux else 0),
				extras,
				Color3.fromRGB(40, 150, 70)
			)
			robuxButton.Name = "OpenRobux"
			robuxButton.TextSize = 13
			robuxButton.Size = if price then half else UDim2.fromScale(1, 1)
			if id == 0 then
				disable(robuxButton, text.ComingSoon)
			elseif closed == nil then
				disable(robuxButton, text.Checking)
			else
				realPrice(id, robuxButton)
				robuxButton.Activated:Connect(function()
					openWithRobux(crate)
				end)
			end
		end
		if price then
			local quick = button("", extras)
			quick.Name = "QuickOpen"
			quick.TextSize = 13
			quick.Size = if robuxOn then half else UDim2.fromScale(1, 1)
			local function showSwitch()
				quick.Text = (if quickOpen then "☑ " else "☐ ") .. text.QuickOpen
				quick.BackgroundColor3 = if quickOpen then Theme.Selected else Theme.Button
			end
			showSwitch()
			quick.Activated:Connect(function()
				quickOpen = not quickOpen
				showSwitch()
			end)
		end
		local navRow = row(7, 32)
		navRow.Name = "Nav"
		local back = button(text.Back, navRow)
		back.Name = "Back"
		back.TextSize = 14
		back.Size = if shopOpener then half else UDim2.fromScale(1, 1)
		back.Activated:Connect(function()
			showList()
		end)
		if shopOpener then
			local shop = button(text.ShopButton, navRow)
			shop.Name = "Shop"
			shop.TextSize = 14
			shop.Size = half
			shop.Activated:Connect(function()
				local open = shopOpener
				if open then
					panel.Visible = false
					open({ Theme = themeOf(crate), Rarity = crate.Rarity })
				end
			end)
		end

		-- Right: every skin in the crate and its chance.
		local grid = Instance.new("ScrollingFrame")
		grid.Name = "Items"
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(sideWidth + 8, 0)
		grid.Size = UDim2.new(1, -(sideWidth + 8), 1, 0)
		grid.ScrollBarThickness = 6
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new()
		grid.Parent = previewView
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = if compact then UDim2.fromOffset(92, 132) else UDim2.fromOffset(104, 146)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingLeft = UDim.new(0, 3)
		pad.Parent = grid
		for i, chance in CrateOdds.Chances(crate) do
			itemCard(grid, chance, i)
		end
	end

	-- Opening view: the spinning strip and the reveal -------------------------------------------
	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
	reel.BackgroundTransparency = 0.1
	reel.ClipsDescendants = true
	reel.AnchorPoint = Vector2.new(0.5, 0.5)
	reel.Position = UDim2.fromScale(0.5, 0.4)
	reel.Size = UDim2.new(1, 0, 0, reelHeight)
	reel.Parent = openView
	Theme.round(reel, 10)
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, 0, 1, -16)
	strip.Parent = reel
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.ZIndex = 5
	marker.BorderSizePixel = 0
	marker.BackgroundColor3 = Theme.Selected
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.new(0, 4, 1, 0)
	marker.Parent = reel
	for _, at in { 0, 1 } do
		local arrow = label(if at == 0 then "▼" else "▲", 18, reel)
		arrow.Name = "MarkerArrow"
		arrow.ZIndex = 6
		arrow.TextColor3 = Theme.Selected
		arrow.AnchorPoint = Vector2.new(0.5, at)
		arrow.Position = UDim2.fromScale(0.5, at)
		arrow.Size = UDim2.fromOffset(24, 18)
	end
	-- Darker edges, so the middle stands out.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.ZIndex = 4
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = reel
	local shadeGradient = Instance.new("UIGradient")
	shadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	shadeGradient.Parent = shade

	local status = label("", 16, openView)
	status.Name = "Status"
	status.Position = UDim2.new(0, 0, 0.4, reelHeight / 2 + 12)
	status.Size = UDim2.new(1, -120, 0, 30)
	status.TextXAlignment = Enum.TextXAlignment.Left
	local skip = button(text.Skip, openView)
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, 0, 0.4, reelHeight / 2 + 12)
	skip.Size = UDim2.fromOffset(100, 32)

	local reveal = Instance.new("Frame")
	reveal.Name = "Reveal"
	reveal.ZIndex = 8
	reveal.BackgroundColor3 = Theme.Background
	reveal.BackgroundTransparency = 0.05
	reveal.Size = UDim2.fromScale(1, 1)
	reveal.Visible = false
	reveal.ClipsDescendants = true
	reveal.Parent = openView
	Theme.round(reveal, 10)

	-- The chest opening's stage (Config.Crates.Opening.Style "Chest"). A tap anywhere on it
	-- skips to the reveal.
	local openingCfg = cfg.Opening
	local stage = Instance.new("TextButton")
	stage.Name = "Chest"
	stage.Text = ""
	stage.AutoButtonColor = false
	stage.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
	stage.BackgroundTransparency = 0.1
	stage.ClipsDescendants = true
	stage.Size = UDim2.new(1, 0, 1, -44)
	stage.Visible = false
	stage.Parent = openView
	Theme.round(stage, 10)

	local stripCards: { Frame } = {}
	local reelIds: { string } = {}

	local function reelCard(index: number, itemId: string): Frame
		local item = Items.Get(itemId)
		local level = rarityLevel(item and Items.Rarity(item))
		local card = Instance.new("Frame")
		card.Name = "Card" .. index
		card.BackgroundColor3 = Color3.fromRGB(40, 34, 56)
		card.Position = UDim2.fromOffset((index - 1) * (cardW + cardGap), 8)
		card.Size = UDim2.new(0, cardW, 1, 0)
		card.Parent = strip
		Theme.round(card, 8)
		local bar = Instance.new("Frame")
		bar.Name = "RarityBar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = level.Color
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.new(1, 0, 0, 6)
		bar.Parent = card
		if level.Rainbow then
			local gradient = Instance.new("UIGradient")
			gradient.Color = rainbowSequence()
			gradient.Parent = bar
		end
		local glow = Instance.new("UIGradient")
		glow.Rotation = 90
		glow.Color = ColorSequence.new(
			Color3.fromRGB(40, 34, 56),
			level.Color:Lerp(Color3.new(0, 0, 0), 0.45)
		)
		glow.Parent = card
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromOffset(4, 4)
		art.Size = UDim2.new(1, -8, 1, -34)
		art.Parent = card
		local name = label(if item then item.Name else "?", 14, card)
		name.Name = "ItemName"
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.new(0, 2, 1, -8)
		name.Size = UDim2.new(1, -4, 0, 26)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		return card
	end

	-- Builds the 3D preview of strip card `index` (once).
	local function reelPreview(index: number)
		local card = stripCards[index]
		local art = card and card:FindFirstChild("Art")
		if not art or art:FindFirstChild("Preview") then
			return
		end
		local item = Items.Get(reelIds[index])
		if not item then
			return
		end
		local entry: LazyView = {
			Holder = art :: Frame,
			Build = function()
				return Cosmetics.Preview(item)
			end,
			Stop = function() end,
			Built = false,
		}
		table.insert(lazyViews, entry)
		buildView(entry, 0.85)
	end

	local function stopBurst()
		if burstConnection then
			burstConnection:Disconnect()
			burstConnection = nil
		end
	end

	local function stopSpin()
		skipNow = nil
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
		if skipConnection then
			skipConnection:Disconnect()
			skipConnection = nil
		end
	end

	-- The chest stage's pieces (3D chest, skin, beam, coins) are thrown away after each opening.
	local stageStop: () -> () = function() end
	local function clearStage()
		stageStop()
		stageStop = function() end
		for _, child in stage:GetChildren() do
			if not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end

	-- The full-screen rainbow and confetti of a CRAZY (or one-in-a-million) unbox. It sits over
	-- the whole screen (not just the panel), lets clicks through and goes after
	-- Opening.CrazySeconds or when the panel closes.
	local crazyHolder: Frame? = nil
	local crazyConnection: RBXScriptConnection? = nil
	local function stopCrazy()
		if crazyConnection then
			crazyConnection:Disconnect()
			crazyConnection = nil
		end
		if crazyHolder then
			crazyHolder:Destroy()
			crazyHolder = nil
		end
	end
	local function crazyBurst()
		stopCrazy()
		Sounds.PlaySpec(openingCfg.Sounds.CrazyBurst)
		local holder = Instance.new("Frame")
		holder.Name = "CrazyBurst"
		holder.Active = false
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.ZIndex = 50
		holder.Parent = gui
		crazyHolder = holder
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Active = false
		flash.BorderSizePixel = 0
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0.25
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 50
		flash.Parent = holder
		local flashGradient = Instance.new("UIGradient")
		flashGradient.Color = rainbowSequence()
		flashGradient.Rotation = 35
		flashGradient.Parent = flash
		type Bit = { Frame: Frame, X: number, Y: number, Speed: number, Spin: number }
		local bits: { Bit } = {}
		local pieces = math.max(
			0,
			math.floor(if compact then openingCfg.PhoneConfetti else openingCfg.Confetti)
		)
		for _ = 1, pieces do
			local bit = Instance.new("Frame")
			bit.Name = "Confetti"
			bit.Active = false
			bit.BorderSizePixel = 0
			bit.ZIndex = 51
			bit.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
			bit.Size = UDim2.fromOffset(math.random(7, 12), math.random(10, 16))
			bit.Parent = holder
			table.insert(bits, {
				Frame = bit,
				X = math.random() * 0.98,
				Y = -math.random() * 0.6,
				Speed = 0.3 + math.random() * 0.4,
				Spin = (math.random() - 0.5) * 700,
			})
		end
		local began = os.clock()
		local seconds = math.max(0.5, openingCfg.CrazySeconds)
		crazyConnection = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - began
			if t >= seconds or not panel.Visible or not holder.Parent then
				stopCrazy()
				return
			end
			flash.BackgroundTransparency = math.clamp(0.25 + t / 0.9, 0.25, 1)
			flashGradient.Offset = Vector2.new(math.sin(t * 3) * 0.3, 0)
			local fade = math.clamp((seconds - t) / 0.6, 0, 1) -- the last moment fades out
			for _, b in bits do
				b.Y += b.Speed * dt
				b.Frame.Visible = b.Y >= 0
				b.Frame.Position = UDim2.fromScale(b.X, math.max(b.Y, 0))
				b.Frame.Rotation += b.Spin * dt
				b.Frame.BackgroundTransparency = 1 - fade
			end
		end)
	end

	-- Rays (and for CRAZY, confetti) behind the reveal card.
	local function burst(parent: Frame, rarity: string)
		local level = rarityLevel(rarity)
		local crazy = level.Rainbow == true
		local holder = Instance.new("Frame")
		holder.Name = "Burst"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.ZIndex = 8
		holder.Parent = parent
		local rays: { Frame } = {}
		local count = if crazy then 10 else 6
		for i = 1, count do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.BorderSizePixel = 0
			ray.ZIndex = 8
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			-- As tall as the reveal: turned any way, a ray stays inside it (rotated frames
			-- aren't clipped by ClipsDescendants).
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.new(0, if crazy then 26 else 18, 0.98, 0)
			ray.BackgroundColor3 = if crazy then Color3.fromHSV(i / count, 0.7, 1) else level.Color
			ray.BackgroundTransparency = 0.55
			ray.Rotation = i / count * 180
			ray.Parent = holder
			local fade = Instance.new("UIGradient")
			fade.Rotation = 90
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = ray
			table.insert(rays, ray)
		end
		type Bit = { Frame: Frame, X: number, Y: number, Speed: number, Spin: number }
		local bits: { Bit } = {}
		if crazy then
			for _ = 1, 36 do
				local bit = Instance.new("Frame")
				bit.Name = "Confetti"
				bit.BorderSizePixel = 0
				bit.ZIndex = 12
				bit.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
				bit.Size = UDim2.fromOffset(math.random(6, 11), math.random(9, 15))
				bit.Parent = holder
				table.insert(bits, {
					Frame = bit,
					X = math.random() * 0.96,
					Y = -math.random() * 0.8,
					Speed = 0.25 + math.random() * 0.35,
					Spin = (math.random() - 0.5) * 600,
				})
			end
		end
		stopBurst()
		local started = os.clock()
		burstConnection = RunService.Heartbeat:Connect(function(dt)
			if not holder.Parent or not panel.Visible then
				stopBurst()
				return
			end
			local t = os.clock() - started
			for i, ray in rays do
				ray.Rotation = i / #rays * 180 + t * 25
				if crazy then
					ray.BackgroundColor3 = Color3.fromHSV((i / #rays + t * 0.3) % 1, 0.7, 1)
				end
			end
			for _, b in bits do
				b.Y += b.Speed * dt
				if b.Y > 0.94 then
					b.Y = 0
					b.X = math.random() * 0.96
				end
				b.Frame.Visible = b.Y >= 0
				b.Frame.Position = UDim2.fromScale(b.X, math.max(b.Y, 0))
				b.Frame.Rotation += b.Spin * dt
			end
		end)
	end

	local function showReveal(result: Result)
		stopSpin()
		clearStage()
		unseen = nil
		busy = false
		revealStop()
		revealStop = function() end
		clear(reveal)
		reveal.Visible = true
		local itemId = result.ItemId or ""
		local item = Items.Get(itemId)
		local rarity = result.Rarity or (item and Items.Rarity(item)) or Config.Rarity.Default
		local level = rarityLevel(rarity)
		if level.Rainbow then
			Sounds.PlaySpec(cfg.Sounds.Crazy)
		elseif rarity == "Rare" then
			Sounds.PlaySpec(cfg.Sounds.Rare)
		else
			Sounds.PlaySpec(cfg.Sounds.Reveal)
		end
		if rarity ~= Config.Rarity.Default and rarity ~= "Uncommon" then
			burst(reveal, rarity)
		end

		local cardWidth = if compact then 330 else 300
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.ZIndex = 10
		card.BackgroundColor3 = Color3.fromRGB(32, 28, 46)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.new(0, cardWidth, 1, -12)
		card.Parent = reveal
		Theme.round(card, 12)
		local cardLimit = Instance.new("UISizeConstraint")
		cardLimit.MaxSize = Vector2.new(cardWidth, 330)
		cardLimit.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Glow"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = if rarity == Config.Rarity.Default then 3 else 5
		stroke.Color = level.Color
		stroke.Parent = card
		if level.Rainbow then
			stroke.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Color = rainbowSequence()
			gradient.Parent = stroke
		end
		local pop = Instance.new("UIScale")
		pop.Scale = 0.6
		pop.Parent = card
		TweenService:Create(
			pop,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()

		local gap = if compact then 2 else 4
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, gap)
		list.Parent = card
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = card

		-- The picture gets the room the lines and buttons below it leave (at most its usual
		-- size), so the buttons always fit on the card, even on the shortest phones.
		local below = 26 + 20 + 20 + 36 + 4 * gap -- name, rarity, news, buttons and the gaps
		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.LayoutOrder = 1
		art.Size = UDim2.new(1, 0, 1, -below)
		art.Parent = card
		local artLimit = Instance.new("UISizeConstraint")
		artLimit.MinSize = Vector2.new(0, 36)
		artLimit.MaxSize = Vector2.new(math.huge, if compact then 92 else 140)
		artLimit.Parent = art
		if item then
			local ok, model = pcall(Cosmetics.Preview, item)
			if ok and model then
				local viewport = newViewport(art)
				viewport.Size = UDim2.fromScale(1, 1)
				showModel(viewport, model, 0.9)
				revealStop = SkinFx.AnimatePreview(model)
			end
		end
		local name = label(result.ItemName or (item and item.Name) or itemId, 22, card)
		name.Name = "ItemName"
		name.LayoutOrder = 2
		name.Size = UDim2.new(1, 0, 0, 26)
		local rarityLabel = label(level.Name, 18, card)
		rarityLabel.Name = "Rarity"
		rarityLabel.LayoutOrder = 3
		rarityLabel.TextColor3 = level.Color:Lerp(Color3.new(1, 1, 1), 0.15)
		rarityLabel.Size = UDim2.new(1, 0, 0, 20)
		local news = if result.Duplicate
			then text.Duplicate:format(result.Refund or 0, currency)
			else text.New
		local newsLabel = label(news, 16, card)
		newsLabel.Name = "News"
		newsLabel.LayoutOrder = 4
		newsLabel.TextColor3 = if result.Duplicate
			then Theme.Selected
			else Color3.fromRGB(140, 235, 140)
		newsLabel.Size = UDim2.new(1, 0, 0, 20)

		local buttons = Instance.new("Frame")
		buttons.Name = "Buttons"
		buttons.BackgroundTransparency = 1
		buttons.LayoutOrder = 5
		buttons.Size = UDim2.new(1, 0, 0, 36)
		buttons.Parent = card
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.Padding = UDim.new(0, 6)
		row.Parent = buttons
		local third = UDim2.new(1 / 3, -4, 1, 0)

		local equip = button(text.Equip, buttons, Color3.fromRGB(70, 130, 70))
		equip.Name = "Equip"
		equip.Size = third
		equip.TextSize = 14
		local equipping = false
		equip.Activated:Connect(function()
			local n = net
			if equipping or not n or not item then
				return
			end
			equipping = true
			task.spawn(function()
				local ok, state = pcall(function()
					return n.Equip:InvokeServer(item.Slot, item.Id)
				end)
				equipping = false
				local worn = ok
					and typeof(state) == "table"
					and typeof((state :: any).Equipped) == "table"
					and (state :: any).Equipped[item.Slot] == item.Id
				if worn then
					equip.Text = text.Wearing
					equip.AutoButtonColor = false
				else
					setMessage("Couldn't put it on, try the Shop.", true)
				end
			end)
		end)

		local crate = CrateOdds.Get(result.CrateId)
		if #queue > 0 then
			-- More crates from the same open are waiting: Next (or Space) plays the next one.
			local nextButton = button(text.Next:format(#queue), buttons, Theme.Selected)
			nextButton.Name = "Next"
			nextButton.Size = third
			nextButton.TextSize = 14
			nextButton.Activated:Connect(function()
				playNext()
			end)
		else
			local again = button(text.OpenAnother, buttons, Theme.Selected)
			again.Name = "OpenAnother"
			again.Size = third
			again.TextSize = 14
			again.Visible = crate ~= nil and restriction() == false
			again.Activated:Connect(function()
				if not crate then
					return
				end
				if lastPaid == "Robux" or not CrateOdds.CoinPrice(crate) then
					openWithRobux(crate)
				else
					openWithCoins(crate, lastCount)
				end
			end)
		end
		if result.OneInAMillion then
			newsLabel.Text = text.OneInAMillion .. "  " .. newsLabel.Text
		end
		local back = button(text.Back, buttons)
		back.Name = "Back"
		back.Size = third
		back.TextSize = 14
		back.Activated:Connect(function()
			stopBurst()
			revealStop()
			revealStop = function() end
			reveal.Visible = false
			if crate then
				showPreview(crate)
			else
				showList()
			end
		end)
		if result.Duplicate then
			setMessage(news)
		else
			setMessage(("%s: %s!"):format(level.Name, name.Text))
		end
	end

	-- Where the status line and Skip sit: under the strip, or at the bottom under the chest.
	local function placeControls(chest: boolean)
		reel.Visible = not chest
		stage.Visible = chest
		if chest then
			status.Position = UDim2.new(0, 0, 1, -36)
			skip.Position = UDim2.new(1, 0, 1, -36)
		else
			status.Position = UDim2.new(0, 0, 0.4, reelHeight / 2 + 12)
			skip.Position = UDim2.new(1, 0, 0.4, reelHeight / 2 + 12)
		end
	end

	-- Spins the strip from its start to the winning card (the server already decided).
	local function playReel(result: Result)
		local crate = CrateOdds.Get(result.CrateId)
		if not result.Ok or not result.Reel or not result.WinIndex then
			busy = false
			setMessage(result.Message, true)
			return
		end
		stopSpin()
		stopBurst()
		clearStage()
		revealStop()
		revealStop = function() end
		busy = true
		unseen = result
		current = crate or current
		lastPaid = result.Paid or lastPaid
		clearLazy(strip)
		for _, child in strip:GetChildren() do
			child:Destroy()
		end
		reveal.Visible = false
		placeControls(false)
		showOnly(openView)
		status.Text = ("%s...%s"):format(
			if crate then crate.Name else text.Title,
			if Layout.IsTouch() then "" else "   " .. text.SkipHint
		)
		setMessage("")
		reelIds = table.clone(result.Reel)
		stripCards = {}
		for i, id in reelIds do
			stripCards[i] = reelCard(i, id)
		end
		strip.Size = UDim2.new(0, #reelIds * (cardW + cardGap), 1, -16)

		local step = cardW + cardGap
		local jitter = (math.random() - 0.5) * cardW * 0.7
		local finish = (result.WinIndex - 1) * step + cardW / 2 + jitter
		local start = cardW / 2
		local duration = math.max(0.5, reelCfg.SpinSeconds)
		local began = os.clock()
		local lastCard = 0
		local lastTick = 0
		local function place(x: number)
			strip.Position = UDim2.new(0.5, -x, 0, 0)
		end
		place(start)
		local function finished()
			stopSpin()
			place(finish)
			local win = stripCards[result.WinIndex]
			if win then
				local glow = Instance.new("UIStroke")
				glow.Name = "Winner"
				glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				glow.Thickness = 3
				glow.Color = rarityLevel(result.Rarity).Color
				glow.Parent = win
			end
			reelPreview(result.WinIndex)
			task.delay(reelCfg.RevealDelay, function()
				if unseen == result and panel.Visible then
					showReveal(result)
				end
			end)
		end
		skip.Visible = true
		skipNow = function()
			if spinConnection then
				finished()
			end
		end
		skipConnection = skip.Activated:Connect(function()
			local fn = skipNow
			if fn then
				fn()
			end
		end)
		spinConnection = RunService.Heartbeat:Connect(function()
			if not panel.Visible then
				stopSpin() -- the result is kept in `unseen` and shown next time the panel opens
				return
			end
			local u = math.clamp((os.clock() - began) / duration, 0, 1)
			local eased = 1 - (1 - u) ^ 4
			local x = start + (finish - start) * eased
			place(x)
			-- Previews for the cards around the marker, and a tick per card that passes it.
			local centre = math.floor(x / step) + 1
			if centre ~= lastCard then
				lastCard = centre
				local now = os.clock()
				if now - lastTick > 0.045 then
					lastTick = now
					Sounds.PlaySpec(cfg.Sounds.Tick)
				end
			end
			-- (only once it has slowed down: Config.Crates.Reel.PreviewSpeed)
			local speed = (finish - start) * 4 * (1 - u) ^ 3 / duration / step -- cards a second
			local made = 0
			for i = math.max(1, centre - 3), math.min(#stripCards, centre + 3) do
				if made >= 2 or speed > reelCfg.PreviewSpeed then
					break
				end
				local art = stripCards[i]:FindFirstChild("Art")
				if art and not art:FindFirstChild("Preview") then
					reelPreview(i)
					made += 1
				end
			end
			if u >= 1 then
				finished()
			end
		end)
	end

	-- The chest opening -------------------------------------------------------------------------
	local function bounceOut(u: number): number
		local n, d = 7.5625, 2.75
		if u < 1 / d then
			return n * u * u
		elseif u < 2 / d then
			u -= 1.5 / d
			return n * u * u + 0.75
		elseif u < 2.5 / d then
			u -= 2.25 / d
			return n * u * u + 0.9375
		end
		u -= 2.625 / d
		return n * u * u + 0.984375
	end
	local function backOut(u: number): number
		local c1 = 1.70158
		return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
	end
	local function easeOut(u: number): number
		return 1 - (1 - u) ^ 3
	end
	local function rainbowAt(shift: number): ColorSequence
		local keys = {}
		for i = 0, 6 do
			local hue = (i / 6 + shift) % 1
			table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(hue, 0.75, 1)))
		end
		return ColorSequence.new(keys)
	end

	local PEDESTAL_TOP = 0.32 -- of the crate size
	-- The spinning pedestal the skin lands on (pivot: the middle of its bottom).
	local function pedestal(size: number, ringColor: Color3): (Model, BasePart)
		local m = Instance.new("Model")
		m.Name = "Pedestal"
		local function disc(name: string, height: number, width: number, y: number): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.CanCollide = false
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(height, width, width)
			p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
			p.Color = Color3.fromRGB(70, 60, 92)
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = m
			return p
		end
		local base = disc("Base", size * 0.22, size * 1.15, size * 0.11)
		local ring = disc("Ring", size * 0.06, size * 1.22, size * 0.2)
		ring.Color = ringColor
		ring.Material = Enum.Material.Neon
		local top = disc("Top", size * 0.1, size, size * 0.27)
		top.Color = Color3.fromRGB(95, 84, 122)
		m.PrimaryPart = base
		base.PivotOffset = base.CFrame:ToObjectSpace(CFrame.new())
		return m, ring
	end

	--[[
		Plays one result as the chest opening: drop and bounce, shake faster and faster, the lid
		bursts open (no lid: the chest pops) with a beam in the colour of the rarity the SERVER
		gave, the skin flies out onto a spinning pedestal, then the reveal card. Everything shown
		comes from `result`; nothing here is random except where coins and confetti fly.
	]]
	local function playChest(result: Result)
		local crate = CrateOdds.Get(result.CrateId)
		if not result.Ok or not result.ItemId then
			busy = false
			setMessage(result.Message, true)
			return
		end
		stopSpin()
		stopBurst()
		clearStage()
		revealStop()
		revealStop = function() end
		busy = true
		unseen = result
		current = crate or current
		lastPaid = result.Paid or lastPaid
		reveal.Visible = false
		placeControls(true)
		showOnly(openView)
		status.Text = ("%s...%s"):format(
			if crate then crate.Name else text.Title,
			if Layout.IsTouch() then "" else "   " .. text.SkipHint
		)
		setMessage("")
		skip.Visible = true

		local item = Items.Get(result.ItemId)
		local rarity = result.Rarity or (item and Items.Rarity(item)) or Config.Rarity.Default
		local beamColor, rainbow = CrateLook.BeamColor(rarity)
		local celebrate = rainbow or result.OneInAMillion == true
		local look = CrateLook.Of(crate or {})
		local size = cfg.Stand.CrateSize

		-- 2D: a halo and the beam behind the 3D picture, coins and words in front of it.
		local halo = Instance.new("Frame")
		halo.Name = "Halo"
		halo.BorderSizePixel = 0
		halo.BackgroundColor3 = look.Glow
		halo.BackgroundTransparency = cardsCfg.HaloTransparency
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.6)
		halo.Size = UDim2.fromScale(0.4, 0.7)
		halo.Parent = stage
		-- (round on any screen: a wide phone stage would stretch it into a flat pill)
		local haloShape = Instance.new("UIAspectRatioConstraint")
		haloShape.AspectRatio = 1.3
		haloShape.DominantAxis = Enum.DominantAxis.Height
		haloShape.Parent = halo
		local haloRound = Instance.new("UICorner")
		haloRound.CornerRadius = UDim.new(0.5, 0)
		haloRound.Parent = halo
		local haloSoft = Instance.new("UIGradient")
		haloSoft.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		haloSoft.Parent = halo

		--[[
			The beam (Config.Crates.Opening.Beam): light pouring up out of the chest. A clear
			holder (its BackgroundColor3 is the beam colour) with a fan of faint shafts that
			overlap brightest in the middle and fade out at the top, a glow at the chest's
			mouth and slow rays turning behind it all. Every piece is made here, once; the
			frame loop in `pose` only moves and fades them. Light is coloured by the frame's
			background and tinted through its UIGradient (white, or the cycling rainbow).
		]]
		local beamCfg = openingCfg.Beam
		local beamBase = UDim2.fromScale(0.5, 0.5) -- (the chest's mouth on the stage)
		local beam = Instance.new("Frame")
		beam.Name = "Beam"
		beam.ZIndex = 2
		beam.BorderSizePixel = 0
		beam.BackgroundColor3 = beamColor
		beam.BackgroundTransparency = 1
		beam.Size = UDim2.fromScale(1, 1)
		beam.Visible = false
		beam:SetAttribute("Rarity", rarity)
		beam:SetAttribute("Rainbow", rainbow)
		beam.Parent = stage
		local lightGradients: { UIGradient } = {}
		local function light(
			name: string,
			parent: Instance,
			rotation: number,
			fade: { number }
		): Frame
			local frame = Instance.new("Frame")
			frame.Name = name
			frame.ZIndex = 2
			frame.BorderSizePixel = 0
			frame.BackgroundColor3 = beamColor
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.SizeConstraint = Enum.SizeConstraint.RelativeYY -- (sizes are of the height)
			frame.Parent = parent
			local keys = {}
			for i = 1, #fade, 2 do
				table.insert(keys, NumberSequenceKeypoint.new(fade[i], fade[i + 1]))
			end
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = rotation
			gradient.Transparency = NumberSequence.new(keys)
			gradient.Color = if rainbow
				then rainbowAt(0)
				else ColorSequence.new(Color3.new(1, 1, 1))
			gradient.Parent = frame
			table.insert(lightGradients, gradient)
			return frame
		end
		-- Rays turning behind the chest: thin bars through the middle, fading at both ends.
		local rays = Instance.new("Frame")
		rays.Name = "Rays"
		rays.ZIndex = 2
		rays.BackgroundTransparency = 1
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = beamBase
		rays.SizeConstraint = Enum.SizeConstraint.RelativeYY
		rays.Size = UDim2.fromScale(0, 0)
		rays.Parent = beam
		local rayFrames: { Frame } = {}
		local rayCount = math.max(0, math.floor(beamCfg.Rays))
		local rayLength = math.max(0.01, beamCfg.RayLength)
		for i = 1, rayCount do
			local ray = light("Ray", rays, 90, { 0, 1, 0.3, 0.55, 0.5, 0, 0.7, 0.55, 1, 1 })
			ray.SizeConstraint = Enum.SizeConstraint.RelativeXY
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromScale(beamCfg.RayWidth / rayLength, 1)
			ray.Rotation = (i - 1) * 180 / rayCount
			table.insert(rayFrames, ray)
		end
		-- The fan: each shaft is twice as tall as the light and turns about its middle (the
		-- chest's mouth); its lower half is clear, its upper half fades out towards the top.
		type Shaft = { Frame: Frame, Angle: number, Phase: number }
		local shafts: { Shaft } = {}
		local shaftCount =
			math.max(1, math.floor(if compact then beamCfg.PhoneShafts else beamCfg.Shafts))
		for i = 1, shaftCount do
			local side = if shaftCount == 1 then 0 else (i - 1) / (shaftCount - 1) * 2 - 1
			local frame =
				light("Shaft", beam, 90, { 0, 1, 0.15, 0.8, 0.42, 0.1, 0.5, 0, 0.502, 1, 1, 1 })
			frame.Position = beamBase
			frame.Size = UDim2.fromScale(0, 0)
			table.insert(shafts, { Frame = frame, Angle = side * beamCfg.Spread, Phase = i * 2.3 })
		end
		-- A soft glow where the light leaves the chest.
		local mouth = light("Glow", beam, 0, { 0, 1, 0.5, 0.2, 1, 1 })
		mouth.Position = beamBase
		mouth.Size = UDim2.fromScale(0, 0)
		local mouthRound = Instance.new("UICorner")
		mouthRound.CornerRadius = UDim.new(0.5, 0)
		mouthRound.Parent = mouth
		-- The white flash as the lid bursts (in front of the chest).
		local flash = Instance.new("Frame")
		flash.Name = "BeamFlash"
		flash.ZIndex = 4
		flash.BorderSizePixel = 0
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 1
		flash.Size = UDim2.fromScale(1, 1)
		flash.Visible = false
		flash.Parent = stage

		local viewport = newViewport(stage)
		viewport.Name = "ChestView"
		viewport.ZIndex = 3
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		local ambient = viewport.Ambient
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		local focus = Vector3.new(0, size * 0.75, -size * 0.3)
		local away = if compact then openingCfg.PhoneCameraDistance else openingCfg.CameraDistance
		camera.CFrame =
			CFrame.lookAt(focus + Vector3.new(0, size * away * 0.2, -size * away), focus)
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		-- The chest (the crate's built model or your own; its part named "Lid" opens).
		local chest: Model? = nil
		if crate then
			local ok, model = pcall(CrateArt.Preview, crate, size)
			if ok and model then
				chest = model
			else
				warn("[CrateUI] chest failed: " .. tostring(model))
			end
		end
		local lid: CrateLook.Lid? = nil
		local chestScale = 1
		local chestHeight = size
		if chest then
			chest.Parent = viewport
			chest:PivotTo(CFrame.new())
			lid = CrateLook.Lid(chest)
			chestScale = chest:GetScale()
			local _, extent = chest:GetBoundingBox()
			chestHeight = extent.Y
		end
		stage:SetAttribute("HasLid", lid ~= nil)

		-- The skin (the same 3D preview as the reveal card), shown once it flies out.
		local skin: Model? = nil
		local skinScale, skinFeet = 1, 0
		local stopFx: () -> () = function() end
		if item then
			local ok, model = pcall(Cosmetics.Preview, item)
			if ok and model then
				skin = model
				model.Name = "Skin"
				local _, extent = model:GetBoundingBox()
				local longest = math.max(extent.X, extent.Y, extent.Z)
				if longest > 0.01 then
					model:ScaleTo(model:GetScale() * size * 1.2 / longest)
				end
				skinScale = model:GetScale()
				local box, boxSize = model:GetBoundingBox()
				skinFeet = model:GetPivot().Position.Y - (box.Position.Y - boxSize.Y / 2)
				stopFx = SkinFx.AnimatePreview(model)
			end
		end
		local stand, ring = pedestal(size, beamColor)
		-- (the skin and pedestal aren't on the stage until they fly in: clear them up too)
		stageStop = function()
			stopFx()
			stand:Destroy()
			if skin then
				skin:Destroy()
			end
		end
		local pedX, pedZ = -size * 0.95, -size * 0.5 -- (the viewer's right of the chest)

		local drop = math.max(0.05, openingCfg.DropSeconds)
		local shake = math.max(0.05, openingCfg.ShakeSeconds)
		local burstTime = math.max(0.05, openingCfg.BurstSeconds)
		local fly = math.max(0.05, openingCfg.FlySeconds)
		local hold = math.max(0, openingCfg.PedestalSeconds)
		local tBurst = drop + shake
		local tFly = tBurst + burstTime
		local tEnd = tFly + fly + hold

		-- Moves and fades the beam's pieces (made above) for time `t`; nothing is created.
		local function poseBeam(t: number)
			local tb = t - tBurst
			local grow = easeOut(math.clamp(tb / burstTime, 0, 1))
			local dim = 1 - math.clamp((t - tFly) / fly, 0, 1) * math.clamp(beamCfg.HoldFade, 0, 1)
			local shimmer = math.clamp(beamCfg.Shimmer, 0, 1)
			local shaftOpacity = 1 - math.clamp(beamCfg.ShaftTransparency, 0, 1)
			for _, shaft in shafts do
				local flicker = 1
					- shimmer * (0.5 + 0.5 * math.sin(tb * beamCfg.ShimmerSpeed + shaft.Phase))
				local frame = shaft.Frame
				frame.BackgroundTransparency = 1 - shaftOpacity * dim * flicker
				frame.Rotation = shaft.Angle * (0.3 + 0.7 * grow)
					+ beamCfg.Sway * math.sin(tb * beamCfg.SwaySpeed + shaft.Phase)
				frame.Size =
					UDim2.fromScale(beamCfg.Width * (0.5 + 0.5 * grow), beamCfg.Height * 2 * grow)
			end
			local rayOpacity = (1 - math.clamp(beamCfg.RayTransparency, 0, 1)) * dim
			for _, ray in rayFrames do
				ray.BackgroundTransparency = 1 - rayOpacity
			end
			rays.Size = UDim2.fromScale(rayLength * grow, rayLength * grow)
			rays.Rotation = (tb * beamCfg.RaySpeed) % 360
			local pulse = 1 - shimmer * 0.5 * (0.5 + 0.5 * math.sin(tb * beamCfg.ShimmerSpeed))
			mouth.BackgroundTransparency = 1 - 0.75 * dim * pulse
			mouth.Size = UDim2.fromScale(beamCfg.Width * 3.2 * grow, beamCfg.Width * 1.1 * grow)
			local flashSeconds = math.max(0, beamCfg.FlashSeconds)
			local f = if flashSeconds > 0 then tb / flashSeconds else 1
			flash.Visible = f < 1
			if f < 1 then
				local start = math.clamp(beamCfg.FlashTransparency, 0, 1)
				flash.BackgroundTransparency = start + (1 - start) * f
			end
			if rainbow then
				local colors = rainbowAt(t * 0.6)
				for _, gradient in lightGradients do
					gradient.Color = colors
				end
			end
		end

		type Coin = { Frame: Frame, X: number, Y: number, VX: number, VY: number }
		local coinBits: { Coin } = {}
		local burstDone = false
		local flying = false
		local function burstOpen()
			if burstDone then
				return
			end
			burstDone = true
			beam.Visible = true
			viewport.Ambient = ambient:Lerp(beamColor, 0.4)
			if celebrate then
				crazyBurst()
			else
				Sounds.PlaySpec(openingCfg.Sounds.Burst)
			end
			if result.Duplicate then
				-- Coins pour out: the duplicate's real refund from the server.
				Sounds.PlaySpec(openingCfg.Sounds.Coins)
				local pour = math.max(
					0,
					math.floor(if compact then openingCfg.PhoneCoinPour else openingCfg.CoinPour)
				)
				for _ = 1, pour do
					local coin = Instance.new("Frame")
					coin.Name = "Coin"
					coin.ZIndex = 5
					coin.BorderSizePixel = 0
					coin.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
					coin.AnchorPoint = Vector2.new(0.5, 0.5)
					coin.Size = UDim2.fromOffset(14, 14)
					coin.Parent = stage
					local round = Instance.new("UICorner")
					round.CornerRadius = UDim.new(0.5, 0)
					round.Parent = coin
					local rim = Instance.new("UIStroke")
					rim.Color = Color3.fromRGB(190, 130, 20)
					rim.Thickness = 2
					rim.Parent = coin
					table.insert(coinBits, {
						Frame = coin,
						X = 0.5,
						Y = 0.48,
						VX = (math.random() - 0.5) * 0.7,
						VY = -0.7 - math.random() * 0.6,
					})
				end
				local back = label(openingCfg.CoinsBack:format(result.Refund or 0), 22, stage)
				back.Name = "CoinsBack"
				back.ZIndex = 6
				back.TextColor3 = Color3.fromRGB(255, 215, 80)
				back.TextStrokeTransparency = 0.3
				back.AnchorPoint = Vector2.new(0.5, 0)
				back.Position = UDim2.fromScale(0.5, 0.06)
				back.Size = UDim2.new(1, -20, 0, 30)
			end
		end

		local shakePhase = 0
		local nextTick = 0
		local lastChestScale = chestScale
		local lastSkinScale = skinScale
		local function pose(t: number, dt: number)
			local chestX = 0
			if t >= tFly then
				chestX = easeOut(math.clamp((t - tFly) / fly, 0, 1)) * size * 0.95
			end
			if chest then
				local y = 0
				if t < drop then
					y = (1 - bounceOut(t / drop)) * size * 3
				end
				local roll, side = 0, 0
				if t >= drop and t < tBurst then
					local u = (t - drop) / shake
					shakePhase += dt * math.pi * 2 * (5 + 25 * u) -- faster and faster
					local amp = u ^ 1.5 * look.Shake
					roll = math.sin(shakePhase) * openingCfg.ShakeDegrees * amp
					side = math.sin(shakePhase * 1.37) * openingCfg.ShakeStuds * amp
					if t >= nextTick then
						Sounds.PlaySpec(openingCfg.Sounds.Shake)
						local gap = openingCfg.ShakeTickStart
							+ (openingCfg.ShakeTickEnd - openingCfg.ShakeTickStart) * u
						nextTick = t + math.max(0.03, gap)
					end
				end
				if not lid then
					-- No lid to open: the chest pops instead.
					local pop = 1
					if t >= tBurst and t < tFly then
						pop = 1 + 0.28 * math.sin(math.pi * (t - tBurst) / burstTime)
					end
					if pop ~= lastChestScale / chestScale then
						chest:ScaleTo(chestScale * pop)
						lastChestScale = chestScale * pop
					end
				end
				chest:PivotTo(CFrame.new(chestX + side, y, 0) * CFrame.Angles(0, 0, math.rad(roll)))
				if lid then
					local angle = 0
					if t >= tBurst then
						angle = backOut(math.clamp((t - tBurst) / burstTime, 0, 1))
							* openingCfg.LidAngle
					end
					CrateLook.LidPose(lid, angle)
				end
			end
			if t >= tBurst then
				burstOpen()
				poseBeam(t)
				if rainbow then
					ring.Color = Color3.fromHSV((t * 0.6) % 1, 0.7, 1)
				end
			end
			for _, coin in coinBits do
				coin.VY += 2.4 * dt
				coin.X += coin.VX * dt
				coin.Y += coin.VY * dt
				coin.Frame.Position = UDim2.fromScale(coin.X, coin.Y)
				coin.Frame.Visible = coin.Y < 1.1
			end
			if t >= tFly then
				if not flying then
					flying = true
					stand.Parent = viewport
					if skin then
						skin.Parent = viewport
					end
				end
				local u = math.clamp((t - tFly) / fly, 0, 1)
				local e = easeOut(u)
				local yaw = math.rad(openingCfg.PedestalSpin * (t - tFly))
				stand:PivotTo(
					CFrame.new(pedX, -size * 1.6 * (1 - e), pedZ) * CFrame.Angles(0, yaw, 0)
				)
				if skin then
					local from = Vector3.new(chestX, chestHeight * 0.85, 0)
					local to = Vector3.new(pedX, size * PEDESTAL_TOP, pedZ)
					local at = from:Lerp(to, e)
						+ Vector3.new(0, math.sin(math.pi * u) * size * 1.3, 0)
					local k = 0.3 + 0.7 * e
					if skinScale * k ~= lastSkinScale then
						skin:ScaleTo(skinScale * k)
						lastSkinScale = skinScale * k
					end
					skin:PivotTo(
						CFrame.new(at + Vector3.new(0, skinFeet * k, 0)) * CFrame.Angles(0, yaw, 0)
					)
				end
			end
		end

		skipNow = function()
			if spinConnection then
				-- Straight to the reveal; a CRAZY still gets its celebration.
				if celebrate and not burstDone then
					crazyBurst()
				end
				showReveal(result)
			end
		end
		skipConnection = skip.Activated:Connect(function()
			local fn = skipNow
			if fn then
				fn()
			end
		end)
		Sounds.PlaySpec(openingCfg.Sounds.Drop)
		pose(0, 0)
		local began = os.clock()
		local last = began
		spinConnection = RunService.Heartbeat:Connect(function()
			if not panel.Visible then
				stopSpin() -- the result is kept in `unseen` and shown next time the panel opens
				return
			end
			local now = os.clock()
			local t = now - began
			local dt = now - last
			last = now
			if t >= tEnd then
				showReveal(result)
				return
			end
			pose(t, dt)
		end)
	end

	-- The opening for one result, in the style Config.Crates.Opening.Style picks.
	playResult = function(result: Result)
		if openingCfg.Style == "Reel" then
			playReel(result)
		else
			playChest(result)
		end
	end

	-- A tap anywhere on the chest skips to the reveal (like Space and Skip).
	stage.Activated:Connect(function()
		local fn = skipNow
		if fn then
			fn()
		end
	end)

	-- The next result of a multi-open (spins its strip).
	playNext = function()
		local result = table.remove(queue, 1)
		if result then
			playResult(result)
		end
	end

	openWithCoins = function(crate: CrateOdds.Crate, countIn: number?)
		local n = net
		if busy or not n then
			return
		end
		local closed = restriction()
		if closed == nil then
			setMessage(text.StillChecking)
			return
		elseif closed then
			defaultMessage()
			return
		end
		local count = countIn or 1
		busy = true
		lastCount = count
		setMessage(text.Checking)
		task.spawn(function()
			local ok, value = pcall(function()
				return n.Open:InvokeServer(crate.Id, if count > 1 then count else nil)
			end)
			local result = if ok then asResult(value) else nil
			if not result then
				busy = false
				setMessage("Something went wrong, try again.", true)
				return
			end
			if not result.Ok then
				busy = false
				setMessage(result.Message, true)
				return
			end
			if not panel.Visible then
				panel.Visible = true
			end
			local all = result.Results or { result }
			for _, one in all do
				if one.ItemId then
					owned[one.ItemId] = true
				end
			end
			if quickOpen then
				showResults(all)
			else
				queue = table.clone(all)
				playNext()
			end
		end)
	end

	-- Quick open: every result on one page. Rarity colours, duplicates with their coins back,
	-- and the best one highlighted.
	showResults = function(all: { Result })
		stopSpin()
		stopBurst()
		revealStop()
		revealStop = function() end
		busy = false
		unseen = nil
		queue = {}
		clear(resultsView)
		showOnly(resultsView)
		local first = all[1]
		local crate = if first then CrateOdds.Get(first.CrateId) else nil
		-- The best: the highest rarity (a one-in-a-million beats everything), the first of them.
		local function rank(r: Result): number
			local index = table.find(Config.Rarity.Order, r.Rarity or Config.Rarity.Default) or 1
			return index + (if r.OneInAMillion then 10 else 0)
		end
		local best = 1
		for i, r in all do
			if rank(r) > rank(all[best]) then
				best = i
			end
		end
		local bestLevel = rarityLevel(all[best] and all[best].Rarity)
		if bestLevel.Rainbow then
			Sounds.PlaySpec(cfg.Sounds.Crazy)
		elseif all[best] and all[best].Rarity == "Rare" then
			Sounds.PlaySpec(cfg.Sounds.Rare)
		else
			Sounds.PlaySpec(cfg.Sounds.Reveal)
		end

		local heading = label(text.Results:format(#all), 20, resultsView)
		heading.Name = "Heading"
		heading.Size = UDim2.new(1, 0, 0, 28)
		local grid = Instance.new("ScrollingFrame")
		grid.Name = "Items"
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(0, 32)
		grid.Size = UDim2.new(1, 0, 1, -(32 + 42))
		grid.ScrollBarThickness = 6
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new()
		grid.Parent = resultsView
		local columns =
			math.max(1, if compact then cfg.QuickOpen.PhoneColumns else cfg.QuickOpen.Columns)
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / columns, -8, 0, if compact then 128 else 150)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.Parent = grid
		local coinsBack = 0
		for i, r in all do
			local item = Items.Get(r.ItemId)
			local level = rarityLevel(r.Rarity)
			local card = Instance.new("Frame")
			card.Name = "Result" .. i
			card.LayoutOrder = i
			card.BackgroundColor3 = Color3.fromRGB(36, 30, 50)
			card.Parent = grid
			Theme.round(card, 8)
			local stroke = Instance.new("UIStroke")
			stroke.Name = "RarityBorder"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = level.Color
			stroke.Thickness = if i == best then 5 else 2.5
			stroke.Parent = card
			if level.Rainbow then
				stroke.Color = Color3.new(1, 1, 1)
				local gradient = Instance.new("UIGradient")
				gradient.Color = rainbowSequence()
				gradient.Parent = stroke
			end
			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Position = UDim2.fromOffset(4, 4)
			art.Size = UDim2.new(1, -8, 1, -64)
			art.Parent = card
			if item then
				lazy(art, function()
					return Cosmetics.Preview(item)
				end)
			end
			local name = label(r.ItemName or (item and item.Name) or "?", 14, card)
			name.Name = "ItemName"
			name.AnchorPoint = Vector2.new(0, 1)
			name.Position = UDim2.new(0, 3, 1, -40)
			name.Size = UDim2.new(1, -6, 0, 20)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local rarityText =
				label(if r.OneInAMillion then text.OneInAMillion else level.Name, 13, card)
			rarityText.Name = "Rarity"
			rarityText.TextColor3 = level.Color:Lerp(Color3.new(1, 1, 1), 0.2)
			rarityText.AnchorPoint = Vector2.new(0, 1)
			rarityText.Position = UDim2.new(0, 3, 1, -22)
			rarityText.Size = UDim2.new(1, -6, 0, 18)
			local news = label(
				if r.Duplicate then text.DuplicateShort:format(r.Refund or 0) else text.New,
				13,
				card
			)
			news.Name = "News"
			news.TextColor3 = if r.Duplicate then Theme.Selected else Color3.fromRGB(140, 235, 140)
			news.AnchorPoint = Vector2.new(0, 1)
			news.Position = UDim2.new(0, 3, 1, -4)
			news.Size = UDim2.new(1, -6, 0, 18)
			if r.Duplicate then
				coinsBack += r.Refund or 0
			end
			if i == best then
				card.BackgroundColor3 = level.Color:Lerp(Color3.fromRGB(36, 30, 50), 0.6)
				local tag = label(text.Best, 14, card)
				tag.Name = "Best"
				tag.ZIndex = 3
				tag.TextColor3 = Color3.fromRGB(255, 225, 90)
				tag.TextStrokeTransparency = 0.2
				tag.Position = UDim2.fromOffset(6, 4)
				tag.Size = UDim2.new(1, -12, 0, 18)
				tag.TextXAlignment = Enum.TextXAlignment.Left
			end
		end

		local footer = Instance.new("Frame")
		footer.Name = "Footer"
		footer.BackgroundTransparency = 1
		footer.AnchorPoint = Vector2.new(0, 1)
		footer.Position = UDim2.fromScale(0, 1)
		footer.Size = UDim2.new(1, 0, 0, 36)
		footer.Parent = resultsView
		local refunds = label(
			if coinsBack > 0 then text.CoinsBack:format(coinsBack, currency) else "",
			14,
			footer
		)
		refunds.Name = "CoinsBack"
		refunds.TextColor3 = Theme.Selected
		refunds.TextXAlignment = Enum.TextXAlignment.Left
		refunds.Size = UDim2.new(1, -230, 1, 0)
		local again = button(text.OpenAnother, footer, Theme.Selected)
		again.Name = "OpenAnother"
		again.AnchorPoint = Vector2.new(1, 0)
		again.Position = UDim2.new(1, -112, 0, 0)
		again.Size = UDim2.fromOffset(110, 36)
		again.Visible = crate ~= nil and restriction() == false
		again.Activated:Connect(function()
			if crate then
				openWithCoins(crate, lastCount)
			end
		end)
		local back = button(text.Back, footer)
		back.Name = "Back"
		back.AnchorPoint = Vector2.new(1, 0)
		back.Position = UDim2.fromScale(1, 0)
		back.Size = UDim2.fromOffset(104, 36)
		back.Activated:Connect(function()
			if crate then
				showPreview(crate)
			else
				showList()
			end
		end)
		setMessage(if coinsBack > 0 then text.CoinsBack:format(coinsBack, currency) else "")
	end

	openWithRobux = function(crate: CrateOdds.Crate)
		local id = CrateOdds.ProductId(crate)
		if busy or id == 0 or not Config.Features.RobuxCrates or restriction() ~= false then
			return
		end
		current = crate
		setMessage(text.WaitingRobux)
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, id)
		end)
		if not ok then
			warn("[CrateUI] " .. tostring(err))
		end
	end

	-- Opening and closing ---------------------------------------------------------------------
	local function refreshState()
		local n = net
		if not n then
			return
		end
		task.spawn(function()
			local ok, state = pcall(function()
				return n.GetState:InvokeServer()
			end)
			if ok and typeof(state) == "table" then
				local s = state :: any
				if typeof(s.Owned) == "table" then
					owned = {}
					for _, id in s.Owned do
						if typeof(id) == "string" then
							owned[id] = true
						end
					end
				end
				if typeof(s.Coins) == "number" then
					coins = s.Coins
					updateCoins()
				end
			end
		end)
	end

	openPanel = function(crateId: string?)
		local crate = CrateOdds.Get(crateId)
		panel.Visible = true
		updateCoins()
		refreshState()
		if busy and openView.Visible then
			return -- an open is on its way: keep watching it
		end
		local pending = unseen
		if pending and not crate then
			showOnly(openView)
			showReveal(pending)
			return
		end
		if #queue > 0 and not crate then
			playNext() -- the rest of a multi-open
			return
		end
		if crate then
			showPreview(crate)
		else
			showList()
		end
	end

	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- Space (Config.Crates.Open.SkipKey) skips the spinning strip, then goes on to the next crate
	-- of a multi-open. Only while the panel is open (so it doesn't stop you jumping otherwise).
	local SKIP_ACTION = "CrateSkip"
	local function onSkipKey(
		_name: string,
		state: Enum.UserInputState,
		_input: InputObject
	): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin or not openView.Visible then
			return Enum.ContextActionResult.Pass
		end
		local fn = skipNow
		if fn then
			fn()
			return Enum.ContextActionResult.Sink
		elseif reveal.Visible and #queue > 0 then
			playNext()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			ContextActionService:BindActionAtPriority(
				SKIP_ACTION,
				onSkipKey,
				false,
				Enum.ContextActionPriority.High.Value,
				cfg.Open.SkipKey
			)
			return
		end
		ContextActionService:UnbindAction(SKIP_ACTION)
		-- Free the 3D previews while the panel is closed.
		stopSpin()
		stopBurst()
		stopCrazy()
		clearStage()
		revealStop()
		revealStop = function() end
		if busy and unseen == nil then
			-- Closed while the server was still answering: the answer opens the panel again.
			return
		end
		busy = false
		clear(listView)
		clear(previewView)
		clearLazy(strip)
		for _, child in strip:GetChildren() do
			child:Destroy()
		end
		clear(reveal)
		clear(resultsView)
		reveal.Visible = false
	end)

	player:GetAttributeChangedSignal("CratesRestricted"):Connect(function()
		if not panel.Visible then
			return
		end
		local crate = current
		if previewView.Visible and crate then
			showPreview(crate)
		elseif listView.Visible then
			defaultMessage()
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_userId, productId, purchased)
		local crate = current
		if not purchased and crate and productId == CrateOdds.ProductId(crate) and not busy then
			defaultMessage()
		end
	end)

	-- The crate stand's prompts (attribute CrateId) open the panel on that crate.
	local lastPrompt = 0
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("CrateId")
		if typeof(id) ~= "string" then
			return
		end
		local now = os.clock()
		if now - lastPrompt < 0.5 then
			return
		end
		lastPrompt = now
		CrateUI.Open(id)
	end)

	-- Coins follow leaderstats (round rewards, purchases). Events, not waiting: leaderstats
	-- only appears once the save has loaded.
	local function watchCoins(value: Instance)
		if value.Name ~= "Coins" or not value:IsA("IntValue") then
			return
		end
		coins = value.Value
		updateCoins()
		value.Changed:Connect(function(new)
			coins = new
			updateCoins()
		end)
	end
	local function watchStats(stats: Instance)
		if stats.Name ~= "leaderstats" then
			return
		end
		local value = stats:FindFirstChild("Coins")
		if value then
			watchCoins(value)
		end
		stats.ChildAdded:Connect(watchCoins)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		watchStats(stats)
	end
	player.ChildAdded:Connect(watchStats)

	-- Remotes (made by CrateService and ShopService on the server, even with crates off).
	task.spawn(function()
		-- The server makes the Remotes folder before any player joins; wait for it without
		-- polling every frame.
		while not ReplicatedStorage:FindFirstChild("Remotes") do
			ReplicatedStorage.ChildAdded:Wait()
		end
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		local n: Net = {
			Open = Remotes.Function("OpenCrate"),
			Result = Remotes.Event("CrateResult"),
			Equip = Remotes.Function("EquipItem"),
			GetState = Remotes.Function("GetShopState"),
			State = Remotes.Event("ShopState"),
		}
		net = n
		n.Result.OnClientEvent:Connect(function(value)
			local result = asResult(value)
			if not result then
				return
			end
			if not result.Ok then
				panel.Visible = true
				if not (openView.Visible or previewView.Visible or listView.Visible) then
					showList()
				end
				setMessage(result.Message, true)
				return
			end
			-- Already spinning (or showing the last one)? This one plays once that is done.
			local waited = 0
			while
				spinConnection
				or (busy and unseen)
				or (reveal.Visible and panel.Visible and waited < 4)
			do
				waited += task.wait(0.5)
			end
			panel.Visible = true
			playResult(result)
		end)
		n.State.OnClientEvent:Connect(function(state)
			if typeof(state) == "table" and typeof((state :: any).Owned) == "table" then
				owned = {}
				for _, id in (state :: any).Owned do
					if typeof(id) == "string" then
						owned[id] = true
					end
				end
			end
		end)
		refreshState()
	end)
end

return CrateUI
