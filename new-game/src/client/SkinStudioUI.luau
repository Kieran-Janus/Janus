--!strict
--[[
	Skin Studio: the skin editor for admins in a Studio playtest (settings: Config.SkinStudio,
	on/off: Config.Features.SkinStudio). Open it from Menu > Skin Studio or F8 > Skin Studio.
	Only admins see it (the server re-checks every action: SkinStudioService).

	The panel sits on the right (a sheet along the bottom on phones) so you can see your own
	character, who wears what you edit. Tabs:
	  Skins    find a skin (search, theme, rarity, drafts, animated), New, Duplicate
	  Look     name, rarity, colours, materials, head piece, accents, glow, particles, CRAZY
	  Animate  animations (Style.Animate) and the walk style (Style.Motion)
	  Catalog  real Roblox catalog items (Style.Catalog)
	  Save     Save, Copy code, Print for Claude, your drafts, and how to get them into the game
	Footer: Undo, Redo, Reset, Turntable (the camera circles you) and the status line.

	Closing the panel (Escape, the Roblox menu, another panel) loses nothing: the skins you are
	editing, their Undo history, the tab and the list page live in this module. You keep
	wearing the draft unless you untick "Keep wearing after closing".

	SkinStudioUI.Mount(gui)        adds the Menu tile; opens on F8 (attribute SkinStudioOpenAt)
	SkinStudioUI.Open() / Close() / IsOpen() -> boolean
	SkinStudioUI.Current() -> State?          the skin being edited (src/client/SkinStudioState)
	SkinStudioUI.SelectSkin(id) / SelectDraft(draftId) / ShowTab(name) / New()
	SkinStudioUI.Allowed() -> boolean         admin + Studio (or AllowInLiveServers) + switch on
	The remote (SkinStudio) is only looked up when the panel opens, never in Mount.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Items = require(ReplicatedStorage.Shared.Items)
local SkinAnimate = require(ReplicatedStorage.Shared.SkinAnimate)
local SkinSchema = require(ReplicatedStorage.Shared.SkinSchema)
local Controls = require(script.Parent.SkinStudioControls)
local Layout = require(script.Parent.Layout)
local MenuUI = require(script.Parent.MenuUI)
local PanelManager = require(script.Parent.PanelManager)
local SkinFx = require(script.Parent.SkinFx)
local SkinStudioState = require(script.Parent.SkinStudioState)
local Theme = require(script.Parent.Theme)

local SkinStudioUI = {}

type State = SkinStudioState.State
type Reply = { Ok: boolean, Message: string, Data: any? }
type Entry = {
	Key: string,
	Kind: string, -- "Skin" | "Draft" | "New"
	Id: string,
	DraftId: string?,
	Name: string,
	Theme: string?,
	Rarity: string,
	Icons: string,
	Item: any?,
}
type Ui = {
	Panel: Frame,
	Phone: boolean,
	Top: number, -- where the content (and a popover) starts
	Name: TextLabel,
	Wearing: TextLabel?,
	WearToggle: TextButton,
	KeepToggle: TextButton?,
	Viewport: ViewportFrame?,
	Tabs: { [string]: TextButton },
	Content: ScrollingFrame,
	Status: TextLabel,
	Banner: TextLabel,
	Undo: TextButton,
	Redo: TextButton,
	Reset: TextButton,
	Turntable: TextButton,
	Popover: Frame?,
}

local TABS = { "Skins", "Look", "Animate", "Catalog", "Save" }
local LOOK_SECTIONS = { "Basics", "Body", "Head", "Accent", "Glow", "Aura", "CRAZY" }
local SECTION_TITLES: { [string]: string } = {
	Basics = "Basics",
	Body = "Body",
	Head = "Head piece",
	Accent = "Accent",
	Glow = "Glow",
	Aura = "Particles",
	CRAZY = "CRAZY",
	Animate = "Animations",
	Walk = "Walk style",
	Catalog = "Catalog items",
}
local GROUPS: { [string]: string } =
	{ Accent = "Accent", Glow = "Glow", Aura = "Aura", CRAZY = "Crazy" }
local COLORS = {
	Info = Color3.fromRGB(200, 200, 215),
	Good = Color3.fromRGB(120, 220, 120),
	Warn = Color3.fromRGB(255, 210, 90),
	Error = Color3.fromRGB(255, 110, 110),
}
local ANY = "Any"
local ALL = "All"

-- Everything below survives closing the panel.
local root: ScreenGui? = nil
local remote: RemoteFunction? = nil
local states: { [string]: State } = {} -- every skin you have touched, by key
local editing: State? = nil -- the skin being edited now
local currentKey: string? = nil
local tab = "Skins"
local filters = { Search = "", Theme = ALL, Rarity = ANY, Drafts = false, Animated = false }
local page = 1
local drafts: { any } = {}
local storeStatus = "Off"
local storeProblem: string? = nil
local wearOn = Config.SkinStudio.WearOnMeDefault
local keepWearing = Config.SkinStudio.KeepWearingDefault
local wearingName: string? = nil
local newCount = 0
local lookups: { [number]: any } = {}
local checks: { Errors: { string }, Sections: { [string]: { string } } } =
	{ Errors = {}, Sections = {} }

local ui: Ui? = nil
local controls: { Controls.Control } = {}
local warningLabels: { [string]: TextLabel } = {}
local errorLabel: TextLabel? = nil
local builtKey = ""
local dragging = false
local status = { Text = "", Kind = "Info" }
local wearToken = 0
local previewToken = 0
local checkToken = 0
local preview: { Model: Model?, Stop: (() -> ())?, Spin: RBXScriptConnection?, Center: Vector3, Radius: number } =
	{ Model = nil, Stop = nil, Spin = nil, Center = Vector3.zero, Radius = 6 }
local turntable: { On: boolean, Conns: { RBXScriptConnection } } = { On = false, Conns = {} }

local renderTab: () -> ()
local refreshAll: () -> ()
local context: () -> Controls.Context

local function text(): any
	return Config.SkinStudio.Text
end

function SkinStudioUI.Allowed(): boolean
	if not Config.Features.SkinStudio then
		return false
	end
	local player = Players.LocalPlayer
	if not player or player:GetAttribute("Admin") ~= true then
		return false
	end
	return RunService:IsStudio() or Config.SkinStudio.AllowInLiveServers == true
end

-- Talking to the server ----------------------------------------------------------------------------

-- Finds the remote (only ever from Open, never from Mount): false if the server has none.
local function connect(): boolean
	if remote then
		return true
	end
	local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
	local found = folder and folder:WaitForChild("SkinStudio", 10)
	if found and found:IsA("RemoteFunction") then
		remote = found
		return true
	end
	return false
end

local setStatus: (message: string, kind: string?) -> ()

local function call(action: string, payload: any?): Reply
	if not connect() then
		return { Ok = false, Message = text().NoRemote }
	end
	local ok, result = pcall(function()
		return (remote :: RemoteFunction):InvokeServer(action, payload)
	end)
	if not ok or type(result) ~= "table" then
		return { Ok = false, Message = text().Broken:format(tostring(result)) }
	end
	return result :: Reply
end

-- Small helpers -------------------------------------------------------------------------------------

local function row(): number
	local current = ui
	return if current and current.Phone
		then Config.SkinStudio.Panel.PhoneRowHeight
		else Config.SkinStudio.Panel.RowHeight
end

local function textSize(): number
	local current = ui
	return math.max(Config.UI.MinTextSize, if current and current.Phone then 16 else 14)
end

local function makeButton(parent: Instance, label: string, color: Color3?): TextButton
	local b = Theme.button(label, parent, color)
	b.TextSize = textSize()
	b.Size = UDim2.new(0, 80, 0, row())
	b.TextTruncate = Enum.TextTruncate.AtEnd
	return b
end

local function hlist(parent: Instance, gap: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 4)
	layout.Parent = parent
	return layout
end

local function line(parent: Instance, name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, row())
	f.LayoutOrder = order
	f.Parent = parent
	hlist(f)
	return f
end

local function rarityColor(rarity: any): Color3
	local level = (Config.Rarity.Levels :: any)[rarity]
	return if level then level.Color else Theme.Muted
end

local function rarityName(rarity: any): string
	local level = (Config.Rarity.Levels :: any)[rarity]
	return if level then level.Name else tostring(rarity)
end

local function themeName(id: any): string
	if id == nil then
		return Config.Skins.Shop.ClassicTheme
	end
	for _, t in Config.Skins.Themes do
		if t.Id == id then
			return t.Name
		end
	end
	return tostring(id)
end

setStatus = function(message: string, kind: string?)
	status.Text = message
	status.Kind = kind or "Info"
	local current = ui
	if current then
		current.Status.Text = message
		current.Status.TextColor3 = COLORS[status.Kind] or COLORS.Info
	end
end

-- Drafts not in the game files yet, and unsaved changes.
local function bannerText(): string
	local n = 0
	for _, summary in drafts do
		if not summary.InGameFiles then
			n += 1
		end
	end
	local lines = {}
	if n == 1 then
		table.insert(lines, "⚠ " .. text().OneNotInFiles)
	elseif n > 1 then
		table.insert(lines, "⚠ " .. text().NotInFiles:format(n))
	end
	local state = editing
	if state and state:Dirty() then
		table.insert(lines, text().Unsaved)
	end
	return table.concat(lines, "\n")
end

local function updateBanner()
	local current = ui
	if current then
		current.Banner.Text = bannerText()
	end
end

-- Every Id in use: skins in the game, saved drafts, skins being edited.
local function takenIds(except: State?): { [string]: boolean }
	local taken: { [string]: boolean } = {}
	for _, item in Items.ForSlot("Skin") do
		taken[item.Id] = true
	end
	for _, summary in drafts do
		taken[summary.SkinId] = true
	end
	for _, state in states do
		if state ~= except then
			taken[state:Peek().Id] = true
		end
	end
	return taken
end

-- Wearing and the preview -------------------------------------------------------------------------

local function wearItem(state: State): any
	return SkinSchema.WearItem({
		DraftId = state.DraftId,
		Author = if Players.LocalPlayer then Players.LocalPlayer.UserId else 0,
		Item = state:Peek(),
	})
end

local updateHeader: () -> ()

local function doWear()
	local state = editing
	if not state or not wearOn then
		return
	end
	local item = state:Get()
	local ok, errors = SkinSchema.Validate(item)
	if not ok then
		setStatus(errors[1] or "This skin can't be worn yet.", "Error")
		return
	end
	local payload =
		HttpService:JSONEncode({ DraftId = state.DraftId, Item = SkinSchema.Encode(item) })
	local reply = call("Wear", payload)
	if reply.Ok then
		wearingName = item.Name
		updateHeader()
	elseif reply.Message == text().SlowDown then
		task.delay(Config.SkinStudio.WearDelay, doWear)
	else
		setStatus(reply.Message, "Error")
	end
end

-- One Wear after WearDelay seconds of no changes (the newest skin wins).
local function scheduleWear()
	if not wearOn then
		return
	end
	wearToken += 1
	local token = wearToken
	task.delay(Config.SkinStudio.WearDelay, function()
		if token == wearToken then
			doWear()
		end
	end)
end

local function clearPreview()
	if preview.Spin then
		preview.Spin:Disconnect()
		preview.Spin = nil
	end
	if preview.Stop then
		pcall(preview.Stop)
		preview.Stop = nil
	end
	if preview.Model then
		preview.Model:Destroy()
		preview.Model = nil
	end
end

local function buildPreview()
	clearPreview()
	local panelUi = ui
	local viewport = panelUi and panelUi.Viewport
	local skin = currentKey and states[currentKey]
	if not (panelUi and viewport and skin and panelUi.Panel.Visible) then
		return
	end
	local ok, model = pcall(Cosmetics.Preview, wearItem(skin))
	if not ok or typeof(model) ~= "Instance" then
		return
	end
	local m = model :: Model
	m.Parent = viewport
	local cf, size = m:GetBoundingBox()
	preview.Model = m
	preview.Center = cf.Position
	preview.Radius = size.Magnitude * 1.5 + 1 -- far enough for the whole skin to fit
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		local made = Instance.new("Camera")
		made.FieldOfView = 40
		made.Parent = viewport
		viewport.CurrentCamera = made
		camera = made
	end
	local cam = camera :: Camera
	local function place()
		local seconds = math.max(0.5, Config.SkinStudio.PreviewSpinSeconds)
		local a = os.clock() / seconds * math.pi * 2
		local offset = Vector3.new(math.sin(a), 0.35, math.cos(a)) * preview.Radius
		cam.CFrame = CFrame.lookAt(preview.Center + offset, preview.Center)
	end
	place()
	preview.Spin = RunService.RenderStepped:Connect(place)
	-- moves and colours it like a worn skin (SkinAnim) and runs its CRAZY effects (SkinFx)
	local okFx, stop = pcall(SkinFx.AnimatePreview, m)
	if okFx and type(stop) == "function" then
		preview.Stop = stop
	end
end

local function schedulePreview()
	previewToken += 1
	local token = previewToken
	task.delay(Config.SkinStudio.PreviewDelay, function()
		if token == previewToken then
			buildPreview()
		end
	end)
end

-- The warnings under each section (SkinSchema.CheckSections), a moment after a change.
local function updateChecks()
	local state = editing
	checks = { Errors = {}, Sections = {} }
	if state then
		local item = state:Peek()
		local ok, errors = SkinSchema.Validate(item)
		if not ok then
			checks.Errors = errors
		else
			for _, problem in SkinSchema.CheckSections(item, Config.Shop.Items) do
				local list = checks.Sections[problem.Section] or {}
				checks.Sections[problem.Section] = list
				table.insert(list, problem.Text)
			end
		end
	end
	for section, labelObject in warningLabels do
		local list = checks.Sections[section]
		labelObject.Text = if list then "⚠ " .. table.concat(list, "\n⚠ ") else ""
		labelObject.Visible = list ~= nil
	end
	local err = errorLabel
	if err then
		err.Text = if #checks.Errors > 0
			then "✕ " .. table.concat(checks.Errors, "\n✕ ")
			else ""
		err.Visible = #checks.Errors > 0
	end
end

local function scheduleChecks()
	checkToken += 1
	local token = checkToken
	task.delay(Config.SkinStudio.PreviewDelay, function()
		if token == checkToken then
			updateChecks()
		end
	end)
end

-- Turntable ------------------------------------------------------------------------------------------

local updateFooter: () -> ()

local function stopTurntable()
	if not turntable.On then
		return
	end
	turntable.On = false
	RunService:UnbindFromRenderStep("SkinStudioTurntable")
	for _, c in turntable.Conns do
		c:Disconnect()
	end
	table.clear(turntable.Conns)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	updateFooter()
end

local function startTurntable()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	if not (character and humanoid and camera and character:FindFirstChild("HumanoidRootPart")) then
		setStatus("Your character hasn't spawned yet.", "Warn")
		return
	end
	turntable.On = true
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	RunService:BindToRenderStep(
		"SkinStudioTurntable",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not (rootPart and rootPart:IsA("BasePart")) then
				stopTurntable()
				return
			end
			local cfg = Config.SkinStudio.Turntable
			local a = (os.clock() - start) / math.max(1, cfg.Seconds) * math.pi * 2
			local center = rootPart.Position
			local eye = center
				+ Vector3.new(math.sin(a) * cfg.Distance, cfg.Height, math.cos(a) * cfg.Distance)
			camera.CFrame = CFrame.lookAt(eye, center)
		end
	)
	table.insert(turntable.Conns, (humanoid :: Humanoid).Died:Connect(stopTurntable))
	table.insert(
		turntable.Conns,
		(player :: Player).CharacterAdded:Connect(function()
			stopTurntable()
		end)
	)
	updateFooter()
end

-- Selecting skins ------------------------------------------------------------------------------------

local onChanged: (state: State, reason: string) -> ()

local function adopt(key: string, state: State)
	states[key] = state
	state.Changed:Connect(function(reason: string)
		onChanged(state, reason)
	end)
end

local function use(key: string, state: State)
	currentKey = key
	editing = state
	builtKey = ""
	updateChecks()
	renderTab()
	schedulePreview()
	scheduleWear()
	updateHeader()
	updateFooter()
	updateBanner()
end

local function draftFor(skinId: string): any?
	for _, summary in drafts do
		if summary.SkinId == skinId then
			return summary
		end
	end
	return nil
end

function SkinStudioUI.SelectDraft(draftId: string)
	local key = "draft:" .. draftId
	local state = states[key]
	if state then
		use(key, state)
		return
	end
	local reply = call("Get", draftId)
	if not reply.Ok then
		setStatus(reply.Message, "Error")
		return
	end
	local record = reply.Data
	local item, errors = SkinSchema.Decode(record.Item)
	if not item then
		setStatus(errors[1] or "That draft is broken.", "Error")
		return
	end
	local made = SkinStudioState.new(item, record.Source)
	made.DraftId = record.DraftId
	made.UnlockEconomy = record.UnlockEconomy == true
	made.Note = record.Note
	adopt(key, made)
	use(key, made)
end

function SkinStudioUI.SelectSkin(id: string)
	local draft = draftFor(id)
	if draft then
		SkinStudioUI.SelectDraft(draft.DraftId)
		return
	end
	local key = "skin:" .. id
	local state = states[key]
	if not state then
		local item = Items.Get(id)
		if not item or item.Slot ~= "Skin" then
			setStatus("There is no skin called " .. id .. ".", "Error")
			return
		end
		local made = SkinStudioState.new(item, item.Id)
		adopt(key, made)
		state = made
	end
	use(key, state :: State)
end

local function startNew(item: any)
	-- a free Id and Name
	local taken = takenIds(nil)
	local base = item.Name
	local n = 1
	while taken[item.Id] do
		n += 1
		item.Name = ("%s %d"):format(base, n)
		item.Id = SkinSchema.IdFromName(
			if SkinSchema.IsCrateTheme(item.Theme) then item.Theme else nil,
			item.Name
		)
	end
	newCount += 1
	local key = "new:" .. newCount
	local state = SkinStudioState.new(item, nil)
	adopt(key, state)
	use(key, state)
end

function SkinStudioUI.New()
	local theme = if SkinSchema.IsCrateTheme(filters.Theme)
		then filters.Theme
		else Config.Skins.Themes[1].Id
	startNew(SkinSchema.NewItem(theme))
end

local function duplicate()
	local state = editing
	if not state then
		setStatus("Pick a skin to copy first.", "Warn")
		return
	end
	local copy = SkinSchema.Duplicate(state:Get())
	local theme = if SkinSchema.IsCrateTheme(copy.Theme) then copy.Theme else nil
	copy.Id = SkinSchema.IdFromName(theme, copy.Name)
	startNew(copy)
end

-- The Skins tab's list -----------------------------------------------------------------------------

local function hasMovement(item: any): boolean
	local style = item and item.Style
	return type(style) == "table" and (style.Animate ~= nil or style.Motion ~= nil)
end

local function iconsFor(item: any): string
	local style = item.Style or {}
	local icons = ""
	if style.Animate then
		icons ..= "🎞"
	end
	if style.Motion then
		icons ..= "🚶"
	end
	if style.Catalog then
		icons ..= "🛍"
	end
	return icons
end

local function entries(): { Entry }
	local out: { Entry } = {}
	-- skins being made (not saved yet)
	for key, state in states do
		if key:sub(1, 4) == "new:" and not state.DraftId then
			local item = state:Peek()
			table.insert(out, {
				Key = key,
				Kind = "New",
				Id = item.Id,
				Name = item.Name,
				Theme = item.Theme,
				Rarity = item.Rarity,
				Icons = "✎ " .. iconsFor(item) .. " (not saved)",
				Item = item,
			})
		end
	end
	for _, summary in drafts do
		local state = states["draft:" .. summary.DraftId]
		table.insert(out, {
			Key = "draft:" .. summary.DraftId,
			Kind = "Draft",
			Id = summary.SkinId,
			DraftId = summary.DraftId,
			Name = summary.Name,
			Theme = summary.Theme,
			Rarity = summary.Rarity,
			Icons = "✎" .. (if summary.InGameFiles then " ✓" else ""),
			Item = state and state:Peek(),
		})
	end
	for _, item in Items.ForSlot("Skin") do
		if draftFor(item.Id) then
			continue
		end
		table.insert(out, {
			Key = "skin:" .. item.Id,
			Kind = "Skin",
			Id = item.Id,
			Name = item.Name,
			Theme = item.Theme,
			Rarity = item.Rarity,
			Icons = iconsFor(item),
			Item = item,
		})
	end
	local search = filters.Search:lower()
	local shown: { Entry } = {}
	for _, entry in out do
		if search ~= "" then
			local hay = (entry.Name .. " " .. entry.Id):lower()
			if not hay:find(search, 1, true) then
				continue
			end
		end
		if filters.Theme ~= ALL then
			local themeOf = entry.Theme or Config.Skins.Shop.ClassicTheme
			if themeOf ~= filters.Theme then
				continue
			end
		end
		if filters.Rarity ~= ANY and entry.Rarity ~= filters.Rarity then
			continue
		end
		if filters.Drafts and entry.Kind == "Skin" then
			continue
		end
		if filters.Animated and not hasMovement(entry.Item) then
			continue
		end
		table.insert(shown, entry)
	end
	return shown
end

local function pageSize(): number
	local current = ui
	return if current and current.Phone
		then Config.SkinStudio.PhoneListPageSize
		else Config.SkinStudio.ListPageSize
end

local function renderList(holder: Frame)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = entries()
	local size = pageSize()
	local pages = math.max(1, math.ceil(#list / size))
	page = math.clamp(page, 1, pages)
	for i = (page - 1) * size + 1, math.min(#list, page * size) do
		local entry = list[i]
		local b = makeButton(
			holder,
			"",
			if entry.Key == currentKey then Color3.fromRGB(110, 70, 30) else nil
		)
		b.Name = "Row_" .. entry.Key
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -8, 0, row())
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = ("      %s   %s · %s  %s"):format(
			entry.Name,
			entry.Id,
			themeName(entry.Theme),
			entry.Icons
		)
		local dot = Instance.new("Frame")
		dot.Name = "Rarity"
		dot.BackgroundColor3 = rarityColor(entry.Rarity)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 8, 0.5, 0)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.Parent = b
		Theme.round(dot, 6)
		b.Activated:Connect(function()
			if entry.Kind == "Draft" then
				SkinStudioUI.SelectDraft(entry.DraftId :: string)
			elseif entry.Kind == "New" then
				use(entry.Key, states[entry.Key])
			else
				SkinStudioUI.SelectSkin(entry.Id)
			end
		end)
	end
	if #list == 0 then
		Controls.Note(holder, "No skins match.", context())
	end
	local pager = line(holder, "Pager", 100000)
	local prev = makeButton(pager, "◀", nil)
	prev.Name = "Prev"
	prev.Size = UDim2.new(0, row() + 12, 0, row())
	local label = Theme.label(("Page %d / %d"):format(page, pages), textSize(), pager)
	label.Name = "PageLabel"
	label.Size = UDim2.new(0, 120, 1, 0)
	local nextButton = makeButton(pager, "▶", nil)
	nextButton.Name = "Next"
	nextButton.Size = UDim2.new(0, row() + 12, 0, row())
	prev.Activated:Connect(function()
		page = math.max(1, page - 1)
		renderList(holder)
	end)
	nextButton.Activated:Connect(function()
		page = math.min(pages, page + 1)
		renderList(holder)
	end)
end

-- The popover (dropdown lists, the colour picker, questions) ----------------------------------------

local function closePopover()
	local current = ui
	if current and current.Popover then
		current.Popover:Destroy()
		current.Popover = nil
	end
end

local function popover(title: string, build: (body: Frame, close: () -> ()) -> ())
	local current = ui
	if not current then
		return
	end
	closePopover()
	-- on a PC it leaves the preview in view; on a phone it uses the whole sheet
	local top = if current.Phone then 0 else Config.SkinStudio.Panel.HeaderHeight
	local pop = Instance.new("Frame")
	pop.Name = "Popover"
	pop.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	pop.ZIndex = 20
	pop.Position = UDim2.new(0, 6, 0, top + 4)
	pop.Size = UDim2.new(1, -12, 1, -(top + 10))
	pop.Parent = current.Panel
	Theme.round(pop, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Selected
	stroke.Thickness = 2
	stroke.Parent = pop
	local titleLabel = Theme.label(title, textSize() + 2, pop)
	titleLabel.Name = "Title"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.fromOffset(12, 4)
	titleLabel.Size = UDim2.new(1, -(row() + 24), 0, row())
	local close = makeButton(pop, "✕", Color3.fromRGB(140, 40, 40))
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, 4)
	close.Size = UDim2.fromOffset(row(), row())
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(8, row() + 10)
	body.Size = UDim2.new(1, -16, 1, -(row() + 16))
	body.ScrollBarThickness = 6
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = pop
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = body
	current.Popover = pop
	close.Activated:Connect(closePopover)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Items"
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Size = UDim2.new(1, 0, 0, 0)
	bodyFrame.AutomaticSize = Enum.AutomaticSize.Y
	bodyFrame.Parent = body
	local inner = Instance.new("UIListLayout")
	inner.SortOrder = Enum.SortOrder.LayoutOrder
	inner.Padding = UDim.new(0, 4)
	inner.Parent = bodyFrame
	build(bodyFrame, closePopover)
end

-- The controls' view of the skin ---------------------------------------------------------------------

local function lockReason(path: { any }): string?
	local state = editing
	if not state or not state.Source then
		return nil
	end
	local key = path[1]
	if #path == 1 and (key == "Id" or key == "Theme") then
		return "A skin already in the game keeps its Id and theme."
	end
	if #path == 1 and table.find(SkinSchema.EconomyKeys, key) and not state.UnlockEconomy then
		return text().EconomyLocked
	end
	return nil
end

-- The names inside the skin's head piece ("Part:" animation targets). They come from the header
-- preview; phones have no header preview (and on a PC it is built a moment after a change), so
-- then a model is built just to read them, once per head piece.
local namesFor = { Key = "", Names = {} :: { string } }
local function partNames(): { string }
	local model = preview.Model
	if model then
		local ok, names = pcall(SkinAnimate.PartNames, model)
		return if ok then names else {}
	end
	local skin = currentKey and states[currentKey]
	if not skin then
		return {}
	end
	local item = wearItem(skin)
	local style = if type(item.Style) == "table" then item.Style else {}
	local key = ("%s|%s"):format(tostring(style.Head), tostring(item.ModelId or item.Id))
	if key ~= namesFor.Key then
		local names: { string } = {}
		local ok, built = pcall(Cosmetics.Preview, item)
		if ok and typeof(built) == "Instance" then
			local okNames, found = pcall(SkinAnimate.PartNames, built)
			names = if okNames then found else {}
			built:Destroy()
		end
		namesFor = { Key = key, Names = names }
	end
	return namesFor.Names
end

context = function(): Controls.Context
	local current = ui
	return {
		Phone = current ~= nil and current.Phone,
		Row = row(),
		TextSize = textSize(),
		Get = function(path: { any }): any
			local state = current and currentKey and states[currentKey]
			if not state then
				return nil
			end
			return SkinSchema.Get(state:Peek(), path)
		end,
		Set = function(path: { any }, value: any)
			local state = currentKey and states[currentKey]
			if not state then
				return
			end
			local why = lockReason(path)
			if why then
				setStatus(why, "Warn")
				return
			end
			if #path == 1 and path[1] == "Theme" then
				-- a new skin's Id starts with its theme, and it drops from the theme's crate
				local item = state:Peek()
				local rest = tostring(item.Id):match("^%u%a*_(.+)$")
					or SkinSchema.IdFromName(nil, tostring(item.Name))
				state:Begin()
				state:Set({ "Theme" }, value)
				state:Set(
					{ "Id" },
					if SkinSchema.IsCrateTheme(value) then value .. "_" .. rest else rest
				)
				state:Set({ "Crate" }, SkinSchema.ThemeCrate(value))
				state:Commit()
				return
			end
			state:Set(path, value)
		end,
		Begin = function()
			local state = currentKey and states[currentKey]
			if state then
				state:Begin()
			end
		end,
		Commit = function()
			local state = currentKey and states[currentKey]
			if state then
				state:Commit()
			end
		end,
		Dragging = function(on: boolean)
			dragging = on
			if not on then
				refreshAll()
			end
		end,
		Popover = popover,
		Help = function(message: string)
			setStatus(message, "Info")
		end,
		Status = setStatus,
		Locked = lockReason,
		PartNames = partNames,
		Lookup = function(id: number): any?
			local reply = call("LookupAsset", id)
			if not reply.Ok then
				setStatus(reply.Message, "Error")
				return nil
			end
			lookups[id] = reply.Data
			return reply.Data
		end,
		Known = function(id: number): any?
			return lookups[id]
		end,
	}
end

-- Tabs ------------------------------------------------------------------------------------------------

local function clearContent()
	local current = ui
	if not current then
		return
	end
	closePopover()
	for _, child in current.Content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(controls)
	table.clear(warningLabels)
	errorLabel = nil
end

local function note(parent: Instance, message: string, order: number, color: Color3?): TextLabel
	local l = Controls.Note(parent, message, context(), color)
	l.LayoutOrder = order
	return l
end

local function warningsFor(section: string, order: number)
	local current = ui
	if not current then
		return
	end
	local l = note(current.Content, "", order, COLORS.Warn)
	l.Name = "Warnings_" .. section
	l.Visible = false
	warningLabels[section] = l
end

local function chip(parent: Instance, label: string, on: boolean, click: () -> ()): TextButton
	local b = makeButton(parent, label, if on then Theme.Selected else nil)
	b.Size = UDim2.new(0, math.max(row(), 14 + #label * 8), 0, row())
	b.Activated:Connect(click)
	return b
end

local function renderSkins(content: ScrollingFrame)
	local ctx = context()
	-- search
	local searchLine = line(content, "SearchLine", 1)
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search names and Ids"
	search.Text = filters.Search
	search.Font = Theme.Font
	search.TextSize = ctx.TextSize
	search.TextColor3 = Theme.Text
	search.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
	search.Size = UDim2.new(1, 0, 0, row())
	search.Parent = searchLine
	Theme.round(search, 6)
	-- theme dropdown
	local themeLine = line(content, "ThemeLine", 2)
	local themeButton = makeButton(themeLine, "Theme: " .. filters.Theme .. "  ▼", nil)
	themeButton.Name = "ThemeFilter"
	themeButton.Size = UDim2.new(1, 0, 0, row())
	-- rarity chips
	local rarityLine = line(content, "RarityLine", 3)
	-- drafts / animated toggles, New, Duplicate
	local toggleLine = line(content, "ToggleLine", 4)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 10
	list.Parent = content
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = list

	local function redrawChips()
		for _, child in rarityLine:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local options = { ANY }
		for _, rarity in Config.Rarity.Order do
			table.insert(options, rarity)
		end
		for i, rarity in options do
			local b = chip(
				rarityLine,
				if rarity == ANY then "Any" else rarityName(rarity),
				filters.Rarity == rarity,
				function()
					filters.Rarity = rarity
					page = 1
					redrawChips()
					renderList(list)
				end
			)
			b.Name = "Rarity_" .. rarity
			b.LayoutOrder = i
		end
		for _, child in toggleLine:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local draftsChip = chip(toggleLine, "Drafts", filters.Drafts, function()
			filters.Drafts = not filters.Drafts
			page = 1
			redrawChips()
			renderList(list)
		end)
		draftsChip.Name = "DraftsFilter"
		local animChip = chip(toggleLine, "Animated", filters.Animated, function()
			filters.Animated = not filters.Animated
			page = 1
			redrawChips()
			renderList(list)
		end)
		animChip.Name = "AnimatedFilter"
		local new = makeButton(toggleLine, "New", Color3.fromRGB(60, 130, 80))
		new.Name = "New"
		new.Activated:Connect(SkinStudioUI.New)
		local dup = makeButton(toggleLine, "Duplicate", nil)
		dup.Name = "Duplicate"
		dup.Size = UDim2.new(0, 96, 0, row())
		dup.Activated:Connect(duplicate)
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		local clean = search.Text:gsub("%c", "")
		if clean ~= filters.Search then
			filters.Search = clean
			page = 1
			renderList(list)
		end
	end)
	themeButton.Activated:Connect(function()
		local options: { Controls.Option } = { { Value = ALL, Text = "All themes" } }
		for _, t in Config.Skins.Themes do
			table.insert(options, { Value = t.Id, Text = t.Name })
		end
		table.insert(
			options,
			{ Value = Config.Skins.Shop.ClassicTheme, Text = "Classic (not in a crate)" }
		)
		table.insert(options, { Value = "Tower", Text = "Tower (won in the Tormented Tower)" })
		popover("Theme", function(body: Frame, close: () -> ())
			for i, option in options do
				local b = makeButton(
					body,
					option.Text,
					if option.Value == filters.Theme then Theme.Selected else nil
				)
				b.Name = "Theme_" .. tostring(option.Value)
				b.LayoutOrder = i
				b.Size = UDim2.new(1, -8, 0, row())
				b.Activated:Connect(function()
					close()
					filters.Theme = option.Value
					page = 1
					themeButton.Text = "Theme: " .. tostring(option.Value) .. "  ▼"
					renderList(list)
				end)
			end
		end)
	end)
	redrawChips()
	renderList(list)
end

local function groupToggle(section: string): { On: boolean, Set: (boolean) -> () }?
	local group = GROUPS[section]
	if not group then
		return nil
	end
	local state = editing
	local on = state ~= nil and state:Peek().Style[group] ~= nil
	return {
		On = on,
		Set = function(want: boolean)
			local s = editing
			if not s then
				return
			end
			if want then
				local make = SkinSchema.GroupDefaults[group]
				s:Set({ "Style", group }, make())
			else
				s:Set({ "Style", group }, nil)
			end
		end,
	}
end

-- Name and Id (a new skin's Id follows its Name until you type an Id yourself).
local function basicsText(content: ScrollingFrame, ctx: Controls.Context, order: number)
	local state = editing :: State
	local nameControl = Controls.Text(
		content,
		"Field_Name",
		"Name",
		"What players see (1 to 40 letters).",
		function()
			return state:Peek().Name
		end,
		function(value: string)
			if value == "" then
				setStatus("A skin needs a name.", "Warn")
				return
			end
			local item = state:Peek()
			if state.Source or (state :: any).IdTouched then
				state:Set({ "Name" }, value)
				return
			end
			state:Begin()
			state:Set({ "Name" }, value)
			local theme = if SkinSchema.IsCrateTheme(item.Theme) then item.Theme else nil
			state:Set({ "Id" }, SkinSchema.IdFromName(theme, value))
			state:Commit()
		end,
		40,
		ctx
	)
	nameControl.Frame.LayoutOrder = order
	table.insert(controls, nameControl)
	if state.Source then
		note(content, "Id: " .. tostring(state:Peek().Id) .. "  🔒 (never changes)", order + 1)
	else
		local idControl = Controls.Text(
			content,
			"Field_Id",
			"Id",
			"The skin's code name, <Theme>_<Name>. Saved in players' data once it's in the game.",
			function()
				return state:Peek().Id
			end,
			function(value: string)
				local ok, why = SkinSchema.IdOk(value, state:Peek().Theme, takenIds(state))
				if not ok then
					setStatus(why or "That Id can't be used.", "Warn")
					return
				end
				(state :: any).IdTouched = true
				state:Set({ "Id" }, value)
			end,
			60,
			ctx
		)
		idControl.Frame.LayoutOrder = order + 1
		table.insert(controls, idControl)
	end
end

local function renderLook(content: ScrollingFrame)
	local state = editing
	if not state then
		note(content, "Pick a skin in the Skins tab, or press New there.", 1)
		return
	end
	local ctx = context()
	local err = note(content, "", 0, COLORS.Error)
	err.Name = "Errors"
	errorLabel = err
	local order = 10
	for _, section in LOOK_SECTIONS do
		local toggle = groupToggle(section)
		local heading = Controls.Section(content, SECTION_TITLES[section], ctx, toggle)
		heading.LayoutOrder = order
		order += 1
		if section == "Basics" then
			basicsText(content, ctx, order)
			order += 2
			local item = state:Peek()
			if state.Source and not state.UnlockEconomy then
				local unlock = makeButton(
					content,
					"🔒 Unlock rarity, crate and price",
					Color3.fromRGB(120, 80, 30)
				)
				unlock.Name = "Unlock"
				unlock.Size = UDim2.new(1, 0, 0, row())
				unlock.LayoutOrder = order
				order += 1
				unlock.Activated:Connect(function()
					popover("Unlock?", function(body: Frame, close: () -> ())
						local q = Controls.Note(body, text().UnlockQuestion, ctx, COLORS.Warn)
						q.LayoutOrder = 1
						local yes = makeButton(body, "Unlock", Color3.fromRGB(150, 70, 40))
						yes.Name = "Yes"
						yes.LayoutOrder = 2
						yes.Size = UDim2.new(1, -8, 0, row())
						yes.Activated:Connect(function()
							close()
							state.UnlockEconomy = true
							setStatus(text().Unlocked, "Warn")
							builtKey = ""
							renderTab()
						end)
						local no = makeButton(body, "Keep it locked", nil)
						no.Name = "No"
						no.LayoutOrder = 3
						no.Size = UDim2.new(1, -8, 0, row())
						no.Activated:Connect(close)
					end)
				end)
			end
			local extra = {}
			if item.OneInAMillion then
				table.insert(extra, ("ONE IN A MILLION (Odds %s%%)"):format(tostring(item.Odds)))
			end
			if item.VipOnly then
				table.insert(extra, "VIP only")
			end
			if item.Exclusive then
				table.insert(extra, "Won in " .. tostring(item.Exclusive))
			end
			if #extra > 0 then
				note(content, table.concat(extra, " · ") .. " (kept as it is)", order)
				order += 1
			end
		end
		if toggle and not toggle.On then
			warningsFor(section, order)
			order += 1
			continue
		end
		for _, field in SkinSchema.Fields do
			if field.Section ~= section or field.Hidden then
				continue
			end
			if section == "Basics" and (field.Key == "Id" or field.Key == "Name") then
				continue
			end
			local control = Controls.Field(content, field, ctx)
			if control then
				control.Frame.LayoutOrder = order
				order += 1
				table.insert(controls, control)
			end
		end
		warningsFor(section, order)
		order += 1
	end
	updateChecks()
end

local function renderAnimate(content: ScrollingFrame)
	local state = editing
	if not state then
		note(content, "Pick a skin in the Skins tab, or press New there.", 1)
		return
	end
	local ctx = context()
	Controls.Section(content, SECTION_TITLES.Animate, ctx).LayoutOrder = 1
	note(
		content,
		"Wings flap, tails wag, heads spin, glows flicker. Uncommon 1, Rare 3, CRAZY 6.",
		2
	)
	local effects = Controls.Effects(content, ctx)
	effects.Frame.LayoutOrder = 3
	table.insert(controls, effects)
	warningsFor("Animate", 4)
	Controls.Section(content, SECTION_TITLES.Walk, ctx).LayoutOrder = 10
	local motion = Controls.Motion(content, ctx)
	motion.Frame.LayoutOrder = 11
	table.insert(controls, motion)
	warningsFor("Walk", 12)
	updateChecks()
end

local function renderCatalog(content: ScrollingFrame)
	local state = editing
	if not state then
		note(content, "Pick a skin in the Skins tab, or press New there.", 1)
		return
	end
	local ctx = context()
	Controls.Section(content, SECTION_TITLES.Catalog, ctx).LayoutOrder = 1
	if not (Config.Features :: any).SkinCatalog then
		note(content, text().CatalogOff, 2, COLORS.Warn)
	end
	note(
		content,
		"Only items made by Roblox, you or your group. Each id must be approved in Config.SkinCatalog.ApprovedIds before /save-skins writes it.",
		3
	)
	local catalog = Controls.Catalog(content, ctx)
	catalog.Frame.LayoutOrder = 4
	table.insert(controls, catalog)
	warningsFor("Catalog", 5)
	updateChecks()
end

local function refreshDrafts()
	local reply = call("Hello")
	if reply.Ok and type(reply.Data) == "table" then
		drafts = reply.Data.Drafts or {}
		storeStatus = reply.Data.DataStore or "Off"
		storeProblem = reply.Data.StoreProblem
		wearingName = reply.Data.Wearing or wearingName
	else
		setStatus(reply.Message, "Warn")
	end
	updateBanner()
	updateHeader()
end

local function save()
	local state = editing
	if not state then
		setStatus("Pick a skin to save first.", "Warn")
		return
	end
	local item = state:Get()
	local ok, errors = SkinSchema.Validate(item)
	if not ok then
		setStatus(errors[1] or "This skin can't be saved yet.", "Error")
		return
	end
	local payload = HttpService:JSONEncode({
		DraftId = state.DraftId,
		Source = state.Source,
		Item = SkinSchema.Encode(item),
		Note = state.Note,
		UnlockEconomy = if state.UnlockEconomy then true else nil,
	})
	setStatus(text().Loading)
	local reply = call("Save", payload)
	if not reply.Ok then
		setStatus(reply.Message, "Error")
		return
	end
	local record = reply.Data
	if not state.DraftId and currentKey then
		states[currentKey] = nil
		currentKey = "draft:" .. record.DraftId
		states[currentKey] = state
	end
	state.DraftId = record.DraftId
	state:MarkSaved()
	setStatus(reply.Message, "Good")
	refreshDrafts()
	if tab == "Save" then
		builtKey = ""
		renderTab()
	end
end

local function deleteDraft(draftId: string)
	local reply = call("Delete", draftId)
	if not reply.Ok then
		setStatus(reply.Message, "Error")
		return
	end
	local key = "draft:" .. draftId
	local state = states[key]
	if state then
		states[key] = nil
		state.DraftId = nil
		local newKey = if state.Source then "skin:" .. state.Source else nil
		if not newKey then
			newCount += 1
			newKey = "new:" .. newCount
		end
		states[newKey :: string] = state
		if currentKey == key then
			currentKey = newKey
		end
	end
	setStatus(reply.Message, "Good")
	refreshDrafts()
	builtKey = ""
	renderTab()
end

local function copyCode()
	local state = editing
	if not state then
		setStatus("Pick a skin first.", "Warn")
		return
	end
	local code = SkinSchema.ToLuau(state:Get())
	popover("Copy code", function(body: Frame, _close: () -> ())
		local hint = Controls.Note(body, text().CopyHint, context(), COLORS.Warn)
		hint.LayoutOrder = 1
		local box = Instance.new("TextBox")
		box.Name = "CopyCode"
		box.MultiLine = true
		box.ClearTextOnFocus = false
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Font = Enum.Font.Code
		box.TextSize = 13
		box.TextColor3 = Theme.Text
		box.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
		box.Size = UDim2.new(1, -8, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Text = code
		box.LayoutOrder = 2
		box.Parent = body
		box.FocusLost:Connect(function()
			box.Text = code -- typing in it never changes the code
		end)
	end)
end

local function renderSave(content: ScrollingFrame)
	local ctx = context()
	local state = editing
	Controls.Section(content, "Save", ctx).LayoutOrder = 1
	local storeLine = if storeStatus == "On"
		then text().SavedDataStore
		elseif storeStatus == "Loading" then text().DataStoreLoading
		elseif storeStatus == "Failed" then text().DataStoreFailed
		else text().DataStoreOff
	note(
		content,
		storeLine .. (if storeProblem then "\n" .. storeProblem else ""),
		2,
		if storeStatus == "Failed" then COLORS.Warn else nil
	)
	if state then
		local item = state:Peek()
		note(
			content,
			("Editing: %s (%s)%s"):format(
				item.Name,
				item.Id,
				if state.DraftId then " · saved draft" else ""
			),
			3
		)
		if not SkinSchema.IsCrateTheme(item.Theme) or item.Exclusive then
			note(content, text().ClassicNoSave, 4, COLORS.Warn)
		end
		local noteControl = Controls.Text(
			content,
			"Field_Note",
			"Note",
			"A note for Claude Code or yourself (up to 120 letters).",
			function()
				return state.Note
			end,
			function(value: string)
				state.Note = if value == "" then nil else value
			end,
			120,
			ctx
		)
		noteControl.Frame.LayoutOrder = 5
		table.insert(controls, noteControl)
		local buttons = line(content, "SaveButtons", 6)
		local saveButton = makeButton(buttons, "💾 Save", Color3.fromRGB(60, 130, 80))
		saveButton.Name = "Save"
		saveButton.Size = UDim2.new(0.33, -4, 0, row())
		saveButton.Activated:Connect(save)
		local copy = makeButton(buttons, "Copy code", nil)
		copy.Name = "CopyCode"
		copy.Size = UDim2.new(0.33, -4, 0, row())
		copy.Activated:Connect(copyCode)
		local printButton = makeButton(buttons, "Print for Claude", nil)
		printButton.Name = "Print"
		printButton.Size = UDim2.new(0.34, -4, 0, row())
		printButton.Activated:Connect(function()
			local reply = call("PrintDrafts")
			setStatus(reply.Message, if reply.Ok then "Good" else "Error")
		end)
	else
		note(content, "Pick a skin in the Skins tab to save it.", 3)
	end
	-- keep wearing after closing
	local keepLine = line(content, "KeepLine", 7)
	local keep =
		makeButton(keepLine, (if keepWearing then "☑ " else "☐ ") .. text().KeepWearing, nil)
	keep.Name = "KeepWearing"
	keep.Size = UDim2.new(1, 0, 0, row())
	keep.Activated:Connect(function()
		keepWearing = not keepWearing
		keep.Text = (if keepWearing then "☑ " else "☐ ") .. text().KeepWearing
	end)
	note(content, text().SaveSteps, 8)
	-- your drafts
	Controls.Section(content, ("Your drafts (%d)"):format(#drafts), ctx).LayoutOrder = 20
	for i, summary in drafts do
		local draftLine = line(content, "Draft_" .. summary.DraftId, 20 + i)
		local open = makeButton(
			draftLine,
			("✎ %s (%s)%s"):format(
				summary.Name,
				summary.SkinId,
				if summary.InGameFiles then " ✓ " .. text().InGameFiles else ""
			),
			nil
		)
		open.Name = "Open"
		open.TextXAlignment = Enum.TextXAlignment.Left
		open.Size = UDim2.new(1, -(row() + 70), 0, row())
		open.Activated:Connect(function()
			SkinStudioUI.SelectDraft(summary.DraftId)
		end)
		local delete = makeButton(draftLine, "Delete", Color3.fromRGB(140, 40, 40))
		delete.Name = "Delete"
		delete.Size = UDim2.new(0, row() + 62, 0, row())
		delete.Activated:Connect(function()
			deleteDraft(summary.DraftId)
		end)
	end
end

-- What decides whether a tab must be rebuilt (otherwise its controls just refresh).
local function tabKey(): string
	local state = editing
	local parts = { tab, tostring(currentKey), tostring(ui and ui.Phone) }
	if state then
		local item = state:Peek()
		for _, group in { "Accent", "Glow", "Aura", "Crazy" } do
			table.insert(parts, if item.Style[group] ~= nil then group else "-")
		end
		table.insert(
			parts,
			tostring(state.Source) .. tostring(state.UnlockEconomy) .. tostring(state.DraftId)
		)
	end
	if tab == "Save" or tab == "Skins" then
		table.insert(parts, tostring(#drafts) .. storeStatus)
	end
	return table.concat(parts, "|")
end

renderTab = function()
	local current = ui
	if not current then
		return
	end
	for name, b in current.Tabs do
		b.BackgroundColor3 = if name == tab then Theme.Selected else Theme.Button
	end
	clearContent()
	builtKey = tabKey()
	local content = current.Content
	if tab == "Skins" then
		renderSkins(content)
	elseif tab == "Look" then
		renderLook(content)
	elseif tab == "Animate" then
		renderAnimate(content)
	elseif tab == "Catalog" then
		renderCatalog(content)
	else
		renderSave(content)
	end
end

refreshAll = function()
	if dragging or not ui then
		return
	end
	if tabKey() ~= builtKey then
		renderTab()
	else
		for _, control in controls do
			control.Refresh()
		end
	end
	updateHeader()
	updateFooter()
	updateBanner()
end

function SkinStudioUI.ShowTab(name: string)
	if not table.find(TABS, name) then
		return
	end
	tab = name
	renderTab()
end

onChanged = function(state: State, _reason: string)
	if state ~= editing then
		return
	end
	scheduleWear()
	schedulePreview()
	scheduleChecks()
	refreshAll()
end

-- Header and footer ------------------------------------------------------------------------------------

updateHeader = function()
	local current = ui
	if not current then
		return
	end
	local state = currentKey and states[currentKey]
	if state then
		local item = state:Peek()
		current.Name.Text = ("%s  ·  %s"):format(item.Name, rarityName(item.Rarity))
		current.Name.TextColor3 = rarityColor(item.Rarity)
	else
		current.Name.Text = "Pick a skin"
		current.Name.TextColor3 = Theme.Text
	end
	if current.Wearing then
		current.Wearing.Text = if wearingName
			then text().WearingDraft:format(wearingName)
			else text().WearingNothing
	end
	current.WearToggle.Text = (if wearOn then "☑ " else "☐ ") .. text().WearOnMe
end

updateFooter = function()
	local current = ui
	if not current then
		return
	end
	local state = currentKey and states[currentKey]
	local canUndo = state ~= nil and state:CanUndo()
	local canRedo = state ~= nil and state:CanRedo()
	current.Undo.TextTransparency = if canUndo then 0 else 0.6
	current.Redo.TextTransparency = if canRedo then 0 else 0.6
	current.Turntable.BackgroundColor3 = if turntable.On then Theme.Selected else Theme.Button
end

-- The panel -------------------------------------------------------------------------------------------

local onHidden: () -> ()

local function build(gui: ScreenGui): Ui
	local cfg = Config.SkinStudio.Panel
	local phone = Layout.IsPhone()
	-- phones on their side: one row on top (tabs, name, close) and one at the bottom
	local wide = phone and Layout.Screen().X >= cfg.PhoneWideWidth
	local rowHeight = if phone then cfg.PhoneRowHeight else cfg.RowHeight
	local size = math.max(Config.UI.MinTextSize, if phone then 16 else 14)
	local panel = Theme.panel(gui)
	panel.Name = "SkinStudio"
	panel.ZIndex = 12
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	if phone then
		-- a sheet along the bottom (no Layout.Fit: controls stay 44 px)
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, 0)
		panel.Size = UDim2.new(1, 0, cfg.PhoneHeightScale, 0)
		local least = Instance.new("UISizeConstraint")
		least.MinSize = Vector2.new(0, cfg.PhoneMinHeight)
		least.Parent = panel
	else
		-- docked to the right edge, so your character stays in view on the left
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -cfg.Margin, 0, cfg.Margin)
		panel.Size = UDim2.new(0, cfg.Width, 1, -2 * cfg.Margin)
		Layout.Fit(panel)
	end

	local function plain(name: string, parent: Instance): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Parent = parent
		return f
	end
	local function squareButton(label: string, parent: Instance): TextButton
		local b = Theme.button(label, parent)
		b.TextSize = size
		b.Size = UDim2.new(0, rowHeight, 0, rowHeight)
		b.TextTruncate = Enum.TextTruncate.AtEnd
		return b
	end

	-- Heights of the three bands (header + tabs on top, the footer at the bottom).
	local headerHeight, tabTop, footerHeight
	if not phone then
		headerHeight, tabTop, footerHeight = cfg.HeaderHeight, cfg.HeaderHeight, cfg.FooterHeight
	elseif wide then
		headerHeight, tabTop, footerHeight = 0, 6, rowHeight + 8
	else
		headerHeight, tabTop, footerHeight = rowHeight + 8, rowHeight + 8, cfg.PhoneFooterHeight
	end
	local tabHeight = if phone then rowHeight else cfg.TabHeight
	local topHeight = tabTop + tabHeight + 6

	-- header: the preview (PC), the skin's name, what you wear, Wear on me, close
	local header = plain("Header", panel)
	header.Size = UDim2.new(1, 0, 0, math.max(headerHeight, topHeight))
	local close = squareButton("✕", header)
	close.Name = "Close"
	close.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, if wide then tabTop else 6)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local viewport: ViewportFrame? = nil
	local name = Theme.label("Pick a skin", size + 2, header)
	name.Name = "SkinName"
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local wearing: TextLabel? = nil
	local wearToggle = squareButton("", header)
	wearToggle.Name = "WearOnMe"
	if not phone then
		local v = Instance.new("ViewportFrame")
		v.Name = "Preview"
		v.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
		v.Ambient = Color3.fromRGB(200, 190, 210)
		v.LightColor = Color3.new(1, 1, 1)
		v.LightDirection = Vector3.new(-1, -1, -1)
		v.Position = UDim2.fromOffset(10, 10)
		v.Size = UDim2.fromOffset(cfg.PreviewSize, cfg.PreviewSize)
		v.Parent = header
		Theme.round(v, 8)
		viewport = v
		local left = cfg.PreviewSize + 20
		name.Position = UDim2.fromOffset(left, 6)
		name.Size = UDim2.new(1, -(left + rowHeight + 16), 0, rowHeight)
		local w = Theme.label("", size, header)
		w.Name = "Wearing"
		w.TextXAlignment = Enum.TextXAlignment.Left
		w.TextColor3 = Theme.Muted
		w.TextTruncate = Enum.TextTruncate.AtEnd
		w.Position = UDim2.fromOffset(left, 6 + rowHeight)
		w.Size = UDim2.new(1, -(left + 10), 0, rowHeight)
		wearing = w
		wearToggle.Position = UDim2.fromOffset(left, 10 + rowHeight * 2)
		wearToggle.Size = UDim2.new(1, -(left + 10), 0, rowHeight)
	elseif wide then
		-- (the name sits right of the tabs; Wear on me goes in the bottom row)
		local tabsWidth = #TABS * (cfg.PhoneTabWidth + 4)
		name.Position = UDim2.fromOffset(tabsWidth + 14, tabTop)
		name.Size = UDim2.new(1, -(tabsWidth + rowHeight + 30), 0, rowHeight)
	else
		name.Position = UDim2.fromOffset(10, 6)
		name.Size = UDim2.new(1, -(rowHeight + 170), 0, rowHeight)
		wearToggle.AnchorPoint = Vector2.new(1, 0)
		wearToggle.Position = UDim2.new(1, -(rowHeight + 12), 0, 6)
		wearToggle.Size = UDim2.new(0, 150, 0, rowHeight)
	end
	wearToggle.Activated:Connect(function()
		wearOn = not wearOn
		if wearOn then
			scheduleWear()
		else
			wearToken += 1
			task.spawn(function()
				local reply = call("StopWearing")
				if reply.Ok then
					wearingName = nil
				end
				updateHeader()
			end)
		end
		updateHeader()
	end)

	-- tabs
	local tabBar = plain("Tabs", panel)
	tabBar.Position = UDim2.fromOffset(6, tabTop)
	tabBar.Size = if wide
		then UDim2.new(0, #TABS * (cfg.PhoneTabWidth + 4), 0, tabHeight)
		else UDim2.new(1, -12, 0, tabHeight)
	hlist(tabBar, 4)
	local tabs: { [string]: TextButton } = {}
	for i, tabName in TABS do
		local b = Theme.button(tabName, tabBar)
		b.Name = "Tab_" .. tabName
		b.TextSize = size
		b.LayoutOrder = i
		b.Size = if wide
			then UDim2.new(0, cfg.PhoneTabWidth, 0, tabHeight)
			else UDim2.new(1 / #TABS, -4, 0, tabHeight)
		b.Activated:Connect(function()
			SkinStudioUI.ShowTab(tabName)
		end)
		tabs[tabName] = b
	end

	-- content
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(8, topHeight)
	content.Size = UDim2.new(1, -16, 1, -(topHeight + footerHeight + 6))
	content.ScrollBarThickness = if phone then 10 else 6
	content.ScrollingDirection = Enum.ScrollingDirection.Y -- sideways drags are for the sliders
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = panel
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 4)
	contentLayout.Parent = content
	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingRight = UDim.new(0, 10)
	contentPad.Parent = content

	-- footer: Undo, Redo, Reset, Turntable, then the status line and the drafts banner
	local footer = plain("Footer", panel)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 6, 1, -4)
	footer.Size = UDim2.new(1, -12, 0, footerHeight)
	local buttons = plain("Buttons", footer)
	local buttonWidth = if wide then cfg.PhoneTabWidth else nil
	buttons.Size = if wide
		then UDim2.new(0, 5 * (cfg.PhoneTabWidth + 4) + 60, 0, rowHeight)
		else UDim2.new(1, 0, 0, rowHeight)
	hlist(buttons, 4)
	local function footerButton(label: string, order: number): TextButton
		local b = Theme.button(label, buttons)
		b.TextSize = size
		b.LayoutOrder = order
		b.Size = if buttonWidth
			then UDim2.new(0, buttonWidth, 0, rowHeight)
			else UDim2.new(0.25, -4, 0, rowHeight)
		b.TextTruncate = Enum.TextTruncate.AtEnd
		return b
	end
	local undo = footerButton("↶ Undo", 1)
	undo.Name = "Undo"
	local redo = footerButton("↷ Redo", 2)
	redo.Name = "Redo"
	local reset = footerButton("Reset", 3)
	reset.Name = "Reset"
	local turn = footerButton("🎥 Turn", 4)
	turn.Name = "Turntable"
	if wide then
		wearToggle.Parent = buttons
		wearToggle.LayoutOrder = 5
		wearToggle.Size = UDim2.new(0, cfg.PhoneTabWidth + 60, 0, rowHeight)
	end
	undo.Activated:Connect(function()
		local state = currentKey and states[currentKey]
		if state then
			state:Undo()
		end
	end)
	redo.Activated:Connect(function()
		local state = currentKey and states[currentKey]
		if state then
			state:Redo()
		end
	end)
	reset.Activated:Connect(function()
		local state = currentKey and states[currentKey]
		if state then
			state:Reset()
		end
	end)
	turn.Activated:Connect(function()
		if turntable.On then
			stopTurntable()
		else
			startTurntable()
		end
	end)
	local statusLabel = Theme.label(status.Text, size - 1, footer)
	statusLabel.Name = "Status"
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = COLORS[status.Kind] or COLORS.Info
	local banner = Theme.label("", size - 2, footer)
	banner.Name = "Banner"
	banner.TextXAlignment = Enum.TextXAlignment.Left
	banner.TextWrapped = true
	banner.TextColor3 = COLORS.Warn
	if wide then
		-- right of the buttons: one line each (the full banner shows on closing)
		local left = 5 * (cfg.PhoneTabWidth + 4) + 64
		local half = math.floor(rowHeight / 2)
		statusLabel.TextWrapped = false
		statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
		statusLabel.Position = UDim2.fromOffset(left, 0)
		statusLabel.Size = UDim2.new(1, -left, 0, half)
		banner.TextWrapped = false
		banner.TextTruncate = Enum.TextTruncate.AtEnd
		banner.Position = UDim2.fromOffset(left, half)
		banner.Size = UDim2.new(1, -left, 0, half)
	else
		local rest = footerHeight - rowHeight - 2
		local statusHeight = math.floor(rest * 0.4)
		statusLabel.Position = UDim2.fromOffset(4, rowHeight + 2)
		statusLabel.Size = UDim2.new(1, -8, 0, statusHeight)
		banner.Position = UDim2.fromOffset(4, rowHeight + 2 + statusHeight)
		banner.Size = UDim2.new(1, -8, 0, rest - statusHeight)
	end

	PanelManager.Register(panel)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			onHidden()
		end
	end)

	return {
		Panel = panel,
		Phone = phone,
		Top = topHeight,
		Name = name,
		Wearing = wearing,
		WearToggle = wearToggle,
		KeepToggle = nil,
		Viewport = viewport,
		Tabs = tabs,
		Content = content,
		Status = statusLabel,
		Banner = banner,
		Undo = undo,
		Redo = redo,
		Reset = reset,
		Turntable = turn,
		Popover = nil,
	}
end

-- A short message on screen after closing (drafts still to save, unsaved changes).
local function toast(message: string)
	local gui = root
	if not gui or message == "" then
		return
	end
	local old = gui:FindFirstChild("SkinStudioToast")
	if old then
		old:Destroy()
	end
	local l = Theme.label(message, math.max(Config.UI.MinTextSize, 15), gui)
	l.Name = "SkinStudioToast"
	l.TextWrapped = true
	l.TextColor3 = COLORS.Warn
	l.BackgroundColor3 = Theme.Background
	l.BackgroundTransparency = 0.15
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -110)
	l.Size = UDim2.new(0, 460, 0, 64)
	Theme.round(l, 10)
	task.delay(6, function()
		if l.Parent then
			l:Destroy()
		end
	end)
end

onHidden = function()
	stopTurntable()
	clearPreview()
	closePopover()
	toast(bannerText())
	if not keepWearing and wearingName then
		wearToken += 1
		task.spawn(function()
			local reply = call("StopWearing")
			if reply.Ok then
				wearingName = nil
			end
		end)
	end
end

function SkinStudioUI.IsOpen(): boolean
	local current = ui
	return current ~= nil and current.Panel.Visible
end

function SkinStudioUI.Current(): State?
	return editing
end

function SkinStudioUI.Open()
	local gui = root
	if not gui or not SkinStudioUI.Allowed() then
		return
	end
	local existing = ui
	if existing and existing.Phone ~= Layout.IsPhone() then
		-- the screen changed between phone and PC: build the right layout
		existing.Panel:Destroy()
		ui = nil
	end
	if not ui then
		ui = build(gui)
	end
	local current = ui :: Ui
	setStatus(status.Text, status.Kind)
	current.Panel.Visible = true
	builtKey = ""
	renderTab()
	updateHeader()
	updateFooter()
	updateBanner()
	schedulePreview()
	task.spawn(function()
		refreshDrafts()
		if current.Panel.Visible and (tab == "Skins" or tab == "Save") then
			refreshAll()
		end
	end)
end

function SkinStudioUI.Close()
	local current = ui
	if current then
		current.Panel.Visible = false
	end
end

function SkinStudioUI.Mount(gui: ScreenGui)
	if not Config.Features.SkinStudio then
		return -- switched off: nothing at all
	end
	root = gui
	MenuUI.AddTile({
		Id = "SkinStudio",
		Label = "Skin Studio",
		Order = 95,
		Visible = SkinStudioUI.Allowed,
		OnClick = SkinStudioUI.Open,
	})
	-- F8 > Skin Studio: the server sets this attribute (no remote needed, so the first press works)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal("SkinStudioOpenAt"):Connect(function()
			if SkinStudioUI.Allowed() then
				SkinStudioUI.Open()
			end
		end)
	end
end

return SkinStudioUI
