--!strict
--[[
	SkinStudioControls: the colour pickers, sliders, dropdowns and lists of Skin Studio
	(src/client/SkinStudioUI.luau). Every control is made from a SkinSchema field (its Label,
	Help, Min/Max/Step, Choices...), so a new Style key gets a control without new UI code.

	Controls.Field(parent, field, ctx) -> Control   the right control for a SkinSchema field
	Controls.Color / Number / Choice / Toggle / Text / Patterns (parent, ..., ctx) -> Control
	Controls.Effects(parent, ctx) -> Control       the Style.Animate list editor
	Controls.Motion(parent, ctx) -> Control        the walk style picker
	Controls.Catalog(parent, ctx) -> Control       catalog items (look up, thumbnails)
	Controls.Section(parent, title, ctx, toggle?) -> Frame   a section heading (with an on/off)
	Controls.Note(parent, text, color?) -> TextLabel         a line of help or warnings
	Control = { Frame: GuiObject, Refresh: () -> () }   Refresh shows the skin's value again.
	The context (ctx) gives the controls the skin (Get/Set/Begin/Commit), a popover to open,
	the phone flag and the row height (44 on phones, so a finger always hits).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local SkinAnimate = require(ReplicatedStorage.Shared.SkinAnimate)
local SkinCatalog = require(ReplicatedStorage.Shared.SkinCatalog)
local SkinMotion = require(ReplicatedStorage.Shared.SkinMotion)
local SkinSchema = require(ReplicatedStorage.Shared.SkinSchema)
local Theme = require(script.Parent.Theme)

local Controls = {}

export type Option = { Value: any, Text: string, Disabled: string? }
export type Control = { Frame: GuiObject, Refresh: () -> () }
export type Context = {
	Phone: boolean,
	Row: number, -- control height (44 on phones)
	TextSize: number,
	Get: (path: { any }) -> any,
	Set: (path: { any }, value: any) -> (),
	Begin: () -> (),
	Commit: () -> (),
	Dragging: (on: boolean) -> (),
	Popover: (title: string, build: (body: Frame, close: () -> ()) -> ()) -> (),
	Help: (text: string) -> (),
	Status: (text: string, kind: string?) -> (),
	Locked: (field: any) -> string?, -- why this field can't change right now, or nil
	PartNames: () -> { string }, -- names inside the head piece (Part: targets)
	Lookup: (id: number) -> any?, -- asks the server about a catalog id (yields)
	Known: (id: number) -> any?, -- what a lookup already said about an id
}

local GOOD = Color3.fromRGB(80, 170, 90)
local OFF = Color3.fromRGB(70, 64, 86)
local WARN = Color3.fromRGB(255, 210, 90)
local DIM = 0.55 -- transparency of a greyed-out control

-- Small builders ---------------------------------------------------------------------------------

local function label(parent: Instance, text: string, ctx: Context, color: Color3?): TextLabel
	local l = Theme.label(text, ctx.TextSize, parent)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color or Theme.Text
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

local function button(parent: Instance, text: string, ctx: Context, color: Color3?): TextButton
	local b = Theme.button(text, parent, color)
	b.TextSize = ctx.TextSize
	b.Size = UDim2.new(0, ctx.Row, 0, ctx.Row)
	return b
end

local function hlist(parent: Instance, gap: number?)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 4)
	layout.Parent = parent
end

local function vlist(parent: Instance, gap: number?)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 4)
	layout.Parent = parent
end

local function blank(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Parent = parent
	return f
end

-- A row: the label (with a "?" for help) and room for the control. On a PC the control sits
-- right of the label; on a phone it goes underneath at full width (more room for fingers).
local function row(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	ctx: Context
): (Frame, Frame)
	local holder = blank(parent, name)
	local top = Instance.new("Frame")
	top.Name = "Label"
	top.BackgroundTransparency = 1
	top.Parent = holder
	local l = label(top, text, ctx)
	l.Size = UDim2.new(1, -(ctx.Row + 4), 1, 0)
	local ask = button(top, "?", ctx, OFF)
	ask.Name = "Help"
	ask.AnchorPoint = Vector2.new(1, 0)
	ask.Position = UDim2.new(1, 0, 0, 0)
	ask.Activated:Connect(function()
		ctx.Help(text .. ": " .. help)
	end)
	local content = Instance.new("Frame")
	content.Name = "Control"
	content.BackgroundTransparency = 1
	content.Parent = holder
	if ctx.Phone then
		top.Size = UDim2.new(1, 0, 0, ctx.Row)
		content.Position = UDim2.new(0, 0, 0, ctx.Row + 2)
		content.Size = UDim2.new(1, 0, 0, ctx.Row)
	else
		top.Size = UDim2.new(0.4, -4, 0, ctx.Row)
		content.Position = UDim2.new(0.4, 0, 0, 0)
		content.Size = UDim2.new(0.6, 0, 0, ctx.Row)
	end
	return holder, content
end

-- Greys a control out (it still shows its value) and says why when tapped.
local function lockOverlay(content: Frame, why: string?, ctx: Context)
	local old = content:FindFirstChild("Lock")
	if old and why then
		return -- already locked
	end
	if old then
		old:Destroy()
	end
	if not why then
		return
	end
	local cover = Instance.new("TextButton")
	cover.Name = "Lock"
	cover.Text = "🔒"
	cover.TextSize = ctx.TextSize
	cover.TextColor3 = Theme.Text
	cover.TextXAlignment = Enum.TextXAlignment.Right
	cover.BackgroundColor3 = Theme.Background
	cover.BackgroundTransparency = DIM
	cover.AutoButtonColor = false
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 5
	cover.Parent = content
	cover.Activated:Connect(function()
		ctx.Help(why)
	end)
end

local function fmt(x: number): string
	if x == math.floor(x) then
		return tostring(math.floor(x))
	end
	return (("%.3f"):format(x):gsub("0+$", ""):gsub("%.$", ""))
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- A number line: [-10] [-] [====o----] [+] [+10] [box]. `set(value, final)`; nil = cleared.
type NumberSpec = {
	Min: number,
	Max: number,
	Step: number,
	Optional: boolean,
	Get: () -> number?,
	Set: (value: number?) -> (),
	Default: number?,
}

local function numberLine(parent: Instance, spec: NumberSpec, ctx: Context): (Frame, () -> ())
	local line = Instance.new("Frame")
	line.Name = "Number"
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, ctx.Row)
	line.Parent = parent
	hlist(line)
	local step = if spec.Step > 0 then spec.Step else 1
	local function snap(x: number): number
		x = math.clamp(x, spec.Min, spec.Max)
		x = spec.Min + math.floor((x - spec.Min) / step + 0.5) * step
		x = math.clamp(x, spec.Min, spec.Max)
		return tonumber(("%.4f"):format(x)) :: number
	end
	local function current(): number
		local v = spec.Get()
		if v ~= nil then
			return v
		end
		return spec.Default or spec.Min
	end
	local deltas: { number } = if ctx.Phone then { -10, -1 } else { -1 }
	for i, d in deltas do
		local b = button(line, if d == -10 then "−10" else "−", ctx, OFF)
		b.Name = "Step" .. d
		b.LayoutOrder = i
		if d == -10 then
			b.Size = UDim2.new(0, ctx.Row + 8, 0, ctx.Row)
		end
		b.Activated:Connect(function()
			spec.Set(snap(current() + d * step))
		end)
	end
	local reserve = (#deltas * 2) * (ctx.Row + 4) + (if ctx.Phone then 16 else 0) + 64
	local bar = Instance.new("TextButton")
	bar.Name = "Bar"
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
	-- (on phones the whole row height can be dragged: an easy target for a finger)
	bar.Size = UDim2.new(1, -reserve, 0, if ctx.Phone then ctx.Row else math.floor(ctx.Row * 0.6))
	bar.LayoutOrder = 10
	bar.Parent = line
	Theme.round(bar, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Selected
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	Theme.round(fill, 6)
	local ups: { number } = { 1, 10 }
	for i, d in ups do
		if d == 10 and not ctx.Phone then
			continue
		end
		local b = button(line, if d == 10 then "+10" else "+", ctx, OFF)
		b.Name = "Step" .. d
		b.LayoutOrder = 20 + i
		if d == 10 then
			b.Size = UDim2.new(0, ctx.Row + 8, 0, ctx.Row)
		end
		b.Activated:Connect(function()
			spec.Set(snap(current() + d * step))
		end)
	end
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.ClearTextOnFocus = false
	box.Font = Theme.Font
	box.TextSize = ctx.TextSize
	box.TextColor3 = Theme.Text
	box.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
	box.Size = UDim2.new(0, 56, 0, ctx.Row)
	box.LayoutOrder = 30
	box.Parent = line
	Theme.round(box, 6)

	local function refresh()
		local v = spec.Get()
		if not box:IsFocused() then
			box.Text = if v ~= nil then fmt(v) else ""
		end
		local range = spec.Max - spec.Min
		local f = if v ~= nil and range > 0 then (v - spec.Min) / range else 0
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end

	box.FocusLost:Connect(function()
		local text = box.Text:gsub("%s", "")
		if text == "" and spec.Optional then
			spec.Set(nil)
		else
			local n = tonumber(text)
			if finite(n) then
				spec.Set(snap(n :: number))
			end
		end
		refresh()
	end)

	-- Dragging the bar: one Undo step for the whole drag.
	local moving: RBXScriptConnection? = nil
	local ending: RBXScriptConnection? = nil
	local function fromX(x: number)
		local width = bar.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local f = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
		spec.Set(snap(spec.Min + f * (spec.Max - spec.Min)))
		refresh()
	end
	local function stop()
		if moving then
			moving:Disconnect()
			moving = nil
		end
		if ending then
			ending:Disconnect()
			ending = nil
			ctx.Dragging(false)
			ctx.Commit()
		end
	end
	bar.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		stop()
		ctx.Begin()
		ctx.Dragging(true)
		fromX(input.Position.X)
		moving = UserInputService.InputChanged:Connect(function(changed: InputObject)
			local t = changed.UserInputType
			if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
				fromX(changed.Position.X)
			end
		end)
		ending = UserInputService.InputEnded:Connect(function(ended: InputObject)
			local t = ended.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				stop()
			end
		end)
	end)
	line.Destroying:Once(stop)
	refresh()
	return line, refresh
end

-- Options shown in a popover list; disabled ones are greyed with their reason.
local function choose(
	title: string,
	options: { Option },
	current: any,
	pick: (any) -> (),
	ctx: Context
)
	ctx.Popover(title, function(body: Frame, close: () -> ())
		for i, option in options do
			local b = button(
				body,
				option.Text,
				ctx,
				if option.Value == current then Theme.Selected else nil
			)
			b.Name = "Option_" .. tostring(option.Value or "None")
			b.LayoutOrder = i
			b.Size = UDim2.new(1, -8, 0, ctx.Row)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextTruncate = Enum.TextTruncate.AtEnd
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8)
			pad.Parent = b
			if option.Disabled then
				b.TextTransparency = DIM
				b.AutoButtonColor = false
				b.Text = option.Text .. "  (" .. option.Disabled .. ")"
				b.Activated:Connect(function()
					ctx.Help(option.Disabled :: string)
				end)
			else
				b.Activated:Connect(function()
					close()
					pick(option.Value)
				end)
			end
		end
	end)
end

-- Controls ---------------------------------------------------------------------------------------

function Controls.Note(parent: Instance, text: string, ctx: Context, color: Color3?): TextLabel
	local l = label(parent, text, ctx, color or Theme.Muted)
	l.Name = "Note"
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	return l
end

-- A section heading. `toggle` = an on/off for a group of keys (Accent, Glow...).
function Controls.Section(
	parent: Instance,
	title: string,
	ctx: Context,
	toggle: { On: boolean, Set: (boolean) -> () }?
): Frame
	local f = Instance.new("Frame")
	f.Name = "Section_" .. title:gsub("%W", "")
	f.BackgroundColor3 = Color3.fromRGB(40, 34, 56)
	f.Size = UDim2.new(1, 0, 0, ctx.Row)
	f.Parent = parent
	Theme.round(f, 6)
	local l = label(f, "  " .. title, ctx, Theme.Selected)
	l.Size = UDim2.new(1, -(ctx.Row * 2 + 8), 1, 0)
	if toggle then
		local b = button(f, if toggle.On then "On" else "Off", ctx, if toggle.On then GOOD else OFF)
		b.Name = "Toggle"
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 0, 0, 0)
		b.Size = UDim2.new(0, ctx.Row * 2, 0, ctx.Row)
		b.Activated:Connect(function()
			toggle.Set(not toggle.On)
		end)
	end
	return f
end

function Controls.Color(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	path: { any },
	optional: boolean,
	ctx: Context
): Control
	local holder, content = row(parent, name, text, help, ctx)
	local swatch = Instance.new("TextButton")
	swatch.Name = "Swatch"
	swatch.Font = Theme.Font
	swatch.TextSize = ctx.TextSize
	swatch.Size = UDim2.new(1, 0, 1, 0)
	swatch.Parent = content
	Theme.round(swatch, 6)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.6
	stroke.Parent = swatch
	local function refresh()
		local c = ctx.Get(path)
		if typeof(c) == "Color3" then
			swatch.BackgroundColor3 = c
			swatch.Text = SkinSchema.Hex(c)
			local light = c.R * 0.3 + c.G * 0.59 + c.B * 0.11 > 0.55
			swatch.TextColor3 = if light then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
		else
			swatch.BackgroundColor3 = OFF
			swatch.Text = "(none)"
			swatch.TextColor3 = Theme.Muted
		end
		lockOverlay(content, ctx.Locked(path), ctx)
	end
	swatch.Activated:Connect(function()
		ctx.Popover(text, function(body: Frame, close: () -> ())
			-- the palette
			local grid = Instance.new("Frame")
			grid.Name = "Palette"
			grid.BackgroundTransparency = 1
			grid.Size = UDim2.new(1, -8, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.LayoutOrder = 1
			grid.Parent = body
			local layout = Instance.new("UIGridLayout")
			local cell = if ctx.Phone then 44 else 30
			layout.CellSize = UDim2.fromOffset(cell, cell)
			layout.CellPadding = UDim2.fromOffset(4, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = grid
			for i, c in Config.SkinStudio.Palette do
				local b = Instance.new("TextButton")
				b.Name = "Swatch" .. i
				b.Text = ""
				b.Size = UDim2.fromOffset(cell, cell)
				b.BackgroundColor3 = c
				b.LayoutOrder = i
				b.Parent = grid
				Theme.round(b, 6)
				b.Activated:Connect(function()
					ctx.Set(path, c)
				end)
			end
			-- red, green, blue
			local refreshers: { () -> () } = {}
			for i, part in { "R", "G", "B" } do
				local line = blank(body, "Channel" .. part)
				line.LayoutOrder = 10 + i
				local l = label(line, ({ R = "Red", G = "Green", B = "Blue" })[part], ctx)
				l.Size = UDim2.new(0, 56, 0, ctx.Row)
				local holderLine = Instance.new("Frame")
				holderLine.BackgroundTransparency = 1
				holderLine.Position = UDim2.new(0, 60, 0, 0)
				holderLine.Size = UDim2.new(1, -64, 0, ctx.Row)
				holderLine.Parent = line
				local _, refreshLine = numberLine(holderLine, {
					Min = 0,
					Max = 255,
					Step = 1,
					Optional = false,
					Get = function()
						local c = ctx.Get(path)
						if typeof(c) ~= "Color3" then
							return nil
						end
						return math.floor((c :: any)[part] * 255 + 0.5)
					end,
					Set = function(value: number?)
						local c = ctx.Get(path)
						local now = if typeof(c) == "Color3" then c else Color3.new(1, 1, 1)
						local r, g, b = now.R * 255, now.G * 255, now.B * 255
						local v = value or 0
						if part == "R" then
							r = v
						elseif part == "G" then
							g = v
						else
							b = v
						end
						ctx.Set(
							path,
							Color3.fromRGB(
								math.floor(r + 0.5),
								math.floor(g + 0.5),
								math.floor(b + 0.5)
							)
						)
					end,
				}, ctx)
				table.insert(refreshers, refreshLine)
			end
			-- hex, clear, done
			local bottom = blank(body, "Bottom")
			bottom.LayoutOrder = 20
			bottom.AutomaticSize = Enum.AutomaticSize.None
			bottom.Size = UDim2.new(1, -8, 0, ctx.Row)
			hlist(bottom)
			local hex = Instance.new("TextBox")
			hex.Name = "Hex"
			hex.ClearTextOnFocus = false
			hex.Font = Theme.Font
			hex.TextSize = ctx.TextSize
			hex.TextColor3 = Theme.Text
			hex.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
			hex.PlaceholderText = "#RRGGBB"
			hex.Size = UDim2.new(0, 100, 0, ctx.Row)
			hex.Parent = bottom
			Theme.round(hex, 6)
			local function showHex()
				local c = ctx.Get(path)
				if not hex:IsFocused() then
					hex.Text = if typeof(c) == "Color3" then SkinSchema.Hex(c) else ""
				end
				for _, fn in refreshers do
					fn()
				end
			end
			hex.FocusLost:Connect(function()
				local typed = hex.Text:gsub("%s", ""):upper()
				if typed:sub(1, 1) ~= "#" then
					typed = "#" .. typed
				end
				local c = SkinSchema.FromHex(typed)
				if c then
					ctx.Set(path, c)
				end
				showHex()
			end)
			if optional then
				local clear = button(bottom, "Clear", ctx, OFF)
				clear.Name = "Clear"
				clear.Size = UDim2.new(0, 70, 0, ctx.Row)
				clear.Activated:Connect(function()
					ctx.Set(path, nil)
					close()
				end)
			end
			local done = button(bottom, "Done", ctx, GOOD)
			done.Name = "Done"
			done.Size = UDim2.new(0, 70, 0, ctx.Row)
			done.Activated:Connect(close)
			-- keep the numbers in step while the popover is open
			local watch = swatch:GetPropertyChangedSignal("BackgroundColor3"):Connect(showHex)
			body.Destroying:Once(function()
				watch:Disconnect()
			end)
			showHex()
		end)
	end)
	refresh()
	return { Frame = holder, Refresh = refresh }
end

function Controls.Number(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	path: { any },
	spec: {
		Min: number,
		Max: number,
		Step: number,
		Optional: boolean,
		Default: number?,
	},
	ctx: Context
): Control
	local holder, content = row(parent, name, text, help, ctx)
	local _, refreshLine = numberLine(content, {
		Min = spec.Min,
		Max = spec.Max,
		Step = spec.Step,
		Optional = spec.Optional,
		Default = spec.Default,
		Get = function()
			local v = ctx.Get(path)
			return if type(v) == "number" then v else nil
		end,
		Set = function(value: number?)
			ctx.Set(path, value)
		end,
	}, ctx)
	local function refresh()
		refreshLine()
		lockOverlay(content, ctx.Locked(path), ctx)
	end
	refresh()
	return { Frame = holder, Refresh = refresh }
end

function Controls.Choice(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	path: { any },
	options: () -> { Option },
	optional: boolean,
	ctx: Context
): Control
	local holder, content = row(parent, name, text, help, ctx)
	local pick = Instance.new("TextButton")
	pick.Name = "Pick"
	pick.Font = Theme.Font
	pick.TextSize = ctx.TextSize
	pick.TextColor3 = Theme.Text
	pick.BackgroundColor3 = Theme.Button
	pick.TextXAlignment = Enum.TextXAlignment.Left
	pick.TextTruncate = Enum.TextTruncate.AtEnd
	pick.Size = UDim2.fromScale(1, 1)
	pick.Parent = content
	Theme.round(pick, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = pick
	local function textOf(value: any): string
		for _, option in options() do
			if option.Value == value then
				return option.Text
			end
		end
		return if value == nil then "(none)" else tostring(value)
	end
	local function refresh()
		pick.Text = textOf(ctx.Get(path)) .. "  ▼"
		lockOverlay(content, ctx.Locked(path), ctx)
	end
	pick.Activated:Connect(function()
		local list = options()
		if optional then
			list = table.clone(list)
			table.insert(list, 1, { Value = nil, Text = "(none)" })
		end
		choose(text, list, ctx.Get(path), function(value)
			ctx.Set(path, value)
		end, ctx)
	end)
	refresh()
	return { Frame = holder, Refresh = refresh }
end

function Controls.Toggle(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	path: { any },
	offValue: any,
	ctx: Context
): Control
	local holder, content = row(parent, name, text, help, ctx)
	local pill = button(content, "Off", ctx, OFF)
	pill.Name = "Pill"
	pill.Size = UDim2.new(0, ctx.Row * 2, 0, ctx.Row)
	local function refresh()
		local on = ctx.Get(path) == true
		pill.Text = if on then "On" else "Off"
		pill.BackgroundColor3 = if on then GOOD else OFF
		lockOverlay(content, ctx.Locked(path), ctx)
	end
	pill.Activated:Connect(function()
		ctx.Set(path, if ctx.Get(path) == true then offValue else true)
	end)
	refresh()
	return { Frame = holder, Refresh = refresh }
end

-- One line of text. `max` letters; hidden characters (line breaks, tabs) are removed as you type.
function Controls.Text(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	get: () -> string?,
	set: (string) -> (),
	max: number,
	ctx: Context
): Control
	local holder, content = row(parent, name, text, help, ctx)
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.ClearTextOnFocus = false
	box.Font = Theme.Font
	box.TextSize = ctx.TextSize
	box.TextColor3 = Theme.Text
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
	box.Size = UDim2.fromScale(1, 1)
	box.Parent = content
	Theme.round(box, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local clean = box.Text:gsub("%c", "")
		if #clean > max then
			clean = clean:sub(1, max)
		end
		if clean ~= box.Text then
			box.Text = clean
		end
	end)
	local function refresh()
		if not box:IsFocused() then
			box.Text = get() or ""
		end
	end
	box.FocusLost:Connect(function()
		local value = box.Text:gsub("%c", "")
		value = value:match("^%s*(.-)%s*$") or ""
		if value ~= (get() or "") then
			set(value)
		end
		refresh()
	end)
	refresh()
	return { Frame = holder, Refresh = refresh }
end

function Controls.Patterns(
	parent: Instance,
	name: string,
	text: string,
	help: string,
	path: { any },
	ctx: Context
): Control
	local holder = blank(parent, name)
	vlist(holder)
	local top = Instance.new("Frame")
	top.Name = "Label"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, ctx.Row)
	top.LayoutOrder = 1
	top.Parent = holder
	local title = label(top, text .. " (tap to add or remove, in order)", ctx)
	title.Size = UDim2.new(1, -(ctx.Row + 4), 1, 0)
	local ask = button(top, "?", ctx, OFF)
	ask.Name = "Help"
	ask.AnchorPoint = Vector2.new(1, 0)
	ask.Position = UDim2.new(1, 0, 0, 0)
	ask.Activated:Connect(function()
		ctx.Help(text .. ": " .. help)
	end)
	local grid = Instance.new("Frame")
	grid.Name = "Chips"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	grid.Parent = holder
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, if ctx.Phone then 104 else 96, 0, ctx.Row)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local chips: { [string]: TextButton } = {}
	local function list(): { string }
		local value = ctx.Get(path)
		if type(value) == "string" then
			return { value }
		elseif type(value) == "table" then
			return table.clone(value)
		end
		return {}
	end
	local function refresh()
		local now = list()
		for patternName, chip in chips do
			local at = table.find(now, patternName)
			chip.BackgroundColor3 = if at then Theme.Selected else Theme.Button
			chip.Text = if at then ("%d %s"):format(at, patternName) else patternName
		end
	end
	for i, patternName in Cosmetics.Patterns do
		local chip = button(grid, patternName, ctx)
		chip.Name = "Chip_" .. patternName
		chip.LayoutOrder = i
		chip.Size = layout.CellSize
		chips[patternName] = chip
		chip.Activated:Connect(function()
			local now = list()
			local at = table.find(now, patternName)
			if at then
				table.remove(now, at)
			else
				table.insert(now, patternName)
			end
			ctx.Set(path, if #now == 0 then nil elseif #now == 1 then now[1] else now)
		end)
	end
	refresh()
	return { Frame = holder, Refresh = refresh }
end

-- Choices for a SkinSchema field ("Choice" and "Material" controls).
local function fieldOptions(field: SkinSchema.Field): () -> { Option }
	return function()
		local out: { Option } = {}
		local values: { string } = if field.Choices then field.Choices() else {}
		local crazy: { [string]: boolean } = {}
		if field.Key == "Head" and field.Path[1] == "Style" then
			for _, item in Config.Shop.Items do
				if item.Slot == "Skin" and item.Rarity == "Crazy" and item.Style.Head then
					crazy[item.Style.Head] = true
				end
			end
		end
		for _, value in values do
			local shown = value
			if field.Key == "Rarity" and field.Path[1] ~= "Style" then
				local level = (Config.Rarity.Levels :: any)[value]
				shown = if level then level.Name else value
			elseif crazy[value] then
				shown = "⭐ " .. value
			elseif field.Key == "Theme" and field.Path[1] == "Theme" then
				for _, theme in Config.Skins.Themes do
					if theme.Id == value then
						shown = theme.Name
					end
				end
			end
			table.insert(out, { Value = value, Text = shown })
		end
		return out
	end
end

-- The right control for a field (Color, Number, Choice, ...).
function Controls.Field(parent: Instance, field: SkinSchema.Field, ctx: Context): Control?
	local name = "Field_" .. table.concat(field.Path, "_")
	local path = field.Path :: { any }
	local control = field.Control
	if control == "Color" then
		return Controls.Color(parent, name, field.Label, field.Help, path, field.Optional, ctx)
	elseif control == "Number" then
		return Controls.Number(parent, name, field.Label, field.Help, path, {
			Min = field.Min or 0,
			Max = field.Max or 1,
			Step = field.Step or 0.1,
			Optional = field.Optional,
		}, ctx)
	elseif control == "Choice" then
		return Controls.Choice(
			parent,
			name,
			field.Label,
			field.Help,
			path,
			fieldOptions(field),
			field.Optional,
			ctx
		)
	elseif control == "Material" then
		local options = function(): { Option }
			local out: { Option } = {}
			for _, materialName in Config.SkinStudio.Materials do
				local ok, material = pcall(function()
					return (Enum.Material :: any)[materialName]
				end)
				if ok and material then
					table.insert(out, { Value = material, Text = materialName })
				end
			end
			-- a material the skin uses that isn't in the friendly list
			local now = ctx.Get(path)
			if typeof(now) == "EnumItem" then
				local found = false
				for _, option in out do
					if option.Value == now then
						found = true
					end
				end
				if not found then
					table.insert(out, { Value = now, Text = (now :: any).Name })
				end
			end
			return out
		end
		return Controls.Choice(
			parent,
			name,
			field.Label,
			field.Help,
			path,
			options,
			field.Optional,
			ctx
		)
	elseif control == "Toggle" then
		local offValue = if field.Key == "HideClothes" then false else nil
		return Controls.Toggle(parent, name, field.Label, field.Help, path, offValue, ctx)
	elseif control == "Patterns" then
		return Controls.Patterns(parent, name, field.Label, field.Help, path, ctx)
	elseif control == "Effects" then
		return Controls.Effects(parent, ctx)
	elseif control == "Motion" then
		return Controls.Motion(parent, ctx)
	elseif control == "Catalog" then
		return Controls.Catalog(parent, ctx)
	end
	return nil
end

-- Animations (Style.Animate) -----------------------------------------------------------------------

local function effectInfos(): { any }
	return SkinAnimate.Effects
end

local function infoOf(name: any): any
	for _, info in effectInfos() do
		if info.Name == name then
			return info
		end
	end
	return nil
end

-- How many animations this rarity may have (Config.SkinAnimate.Rarity), and the most in one skin.
local function effectLimit(rarity: any): (number, string)
	local cfg = (Config :: any).SkinAnimate
	if type(cfg) ~= "table" then
		return 6, ""
	end
	local rule = cfg.Rarity and cfg.Rarity[rarity]
	local level = (Config.Rarity.Levels :: any)[rarity]
	local name = if level then level.Name else tostring(rarity)
	local most = math.min(if rule then rule.Effects else cfg.MaxEffects, cfg.MaxEffects)
	if most == 0 then
		return 0, ("%s skins don't animate: make it Uncommon or better first."):format(name)
	end
	return most,
		("%s skins can have %d animation%s."):format(name, most, if most == 1 then "" else "s")
end

local function targetOptions(effectName: string, ctx: Context): { Option }
	local style = ctx.Get({ "Style" }) or {}
	local parts = ctx.PartNames()
	local all = SkinAnimate.TargetsIn(style, parts)
	local ok = SkinAnimate.TargetsIn(style, parts, effectName)
	local out: { Option } = {}
	for _, target in all do
		local why: string? = nil
		if not table.find(ok, target) then
			why = SkinAnimate.Forbidden(effectName, target, style) or "this animation can't use it"
		end
		table.insert(out, { Value = target, Text = target, Disabled = why })
	end
	return out
end

-- A fresh effect: the first one this skin has a target for.
local function newEffect(ctx: Context): any
	local style = ctx.Get({ "Style" }) or {}
	local parts = ctx.PartNames()
	for _, info in effectInfos() do
		local targets = SkinAnimate.TargetsIn(style, parts, info.Name)
		if table.find(targets, info.DefaultTarget) then
			local effect: any = { Effect = info.Name, Target = info.DefaultTarget }
			if info.Name == "ColorCycle" then
				effect.Colors = { Color3.fromRGB(255, 130, 20), Color3.fromRGB(150, 60, 200) }
			end
			return effect
		end
	end
	return { Effect = "Shimmer", Target = "Body" }
end

-- Changing an effect keeps Speed/Amount/Delay and drops what the new one doesn't take.
local function switchEffect(old: any, name: string, ctx: Context): any
	local info = infoOf(name)
	local out: any = { Effect = name }
	local keep: { [string]: boolean } = {}
	local params: { any } = if info then info.Params else {}
	for _, param in params do
		keep[param.Key] = true
	end
	for key, value in old do
		if keep[key] then
			out[key] = value
		end
	end
	local style = ctx.Get({ "Style" }) or {}
	local allowed = SkinAnimate.TargetsIn(style, ctx.PartNames(), name)
	out.Target = if table.find(allowed, old.Target)
		then old.Target
		else (if info then info.DefaultTarget else old.Target)
	if name == "ColorCycle" and type(out.Colors) ~= "table" then
		out.Colors = { Color3.fromRGB(255, 130, 20), Color3.fromRGB(150, 60, 200) }
	end
	return out
end

function Controls.Effects(parent: Instance, ctx: Context): Control
	local holder = blank(parent, "Effects")
	vlist(holder, 6)
	local children: { Control } = {}
	local builtKey = ""
	local function key(): string
		local list = ctx.Get({ "Style", "Animate" })
		local parts = { tostring(ctx.Get({ "Rarity" })) }
		if type(list) == "table" then
			for _, effect in list do
				table.insert(
					parts,
					tostring(effect.Effect)
						.. ":"
						.. tostring(effect.Target)
						.. ":"
						.. tostring(if type(effect.Colors) == "table" then #effect.Colors else 0)
				)
			end
		end
		return table.concat(parts, "|")
	end
	local function list(): { any }
		local value = ctx.Get({ "Style", "Animate" })
		return if type(value) == "table" then SkinSchema.Copy(value) else {}
	end
	local function setList(new: { any })
		ctx.Set({ "Style", "Animate" }, if #new == 0 then nil else new)
	end
	local rebuild: () -> ()
	local function build()
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(children)
		builtKey = key()
		local effects = list()
		for i, effect in effects do
			local base: { any } = { "Style", "Animate", i }
			local card = Instance.new("Frame")
			card.Name = "Effect" .. i
			card.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.LayoutOrder = i
			card.Parent = holder
			Theme.round(card, 8)
			vlist(card, 4)
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 4)
			pad.PaddingBottom = UDim.new(0, 4)
			pad.PaddingLeft = UDim.new(0, 4)
			pad.PaddingRight = UDim.new(0, 4)
			pad.Parent = card
			-- title line: number, ✕ ▲ ▼
			local title = Instance.new("Frame")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(1, 0, 0, ctx.Row)
			title.Parent = card
			hlist(title)
			local l = label(title, ("Animation %d"):format(i), ctx, Theme.Selected)
			l.Size = UDim2.new(1, -3 * (ctx.Row + 4), 1, 0)
			for order, action in { "▲", "▼", "✕" } do
				local b = button(
					title,
					action,
					ctx,
					if action == "✕" then Color3.fromRGB(140, 40, 40) else OFF
				)
				b.Name = ({ ["▲"] = "MoveUp", ["▼"] = "MoveDown", ["✕"] = "RemoveEffect" })[action]
				b.LayoutOrder = 10 + order
				b.Activated:Connect(function()
					local now = list()
					if action == "✕" then
						table.remove(now, i)
					elseif action == "▲" and i > 1 then
						now[i], now[i - 1] = now[i - 1], now[i]
					elseif action == "▼" and i < #now then
						now[i], now[i + 1] = now[i + 1], now[i]
					else
						return
					end
					setList(now)
				end)
			end
			-- which effect
			local effectOptions = function(): { Option }
				local out: { Option } = {}
				for _, info in effectInfos() do
					table.insert(out, { Value = info.Name, Text = info.Label })
				end
				return out
			end
			local info = infoOf(effect.Effect)
			local effectHelp = if info then info.Help else "Pick what it does."
			-- (changing the effect swaps the whole entry, keeping the numbers it can use)
			local effectCtx = table.clone(ctx)
			effectCtx.Get = function()
				local now = list()[i]
				return now and now.Effect
			end
			effectCtx.Set = function(_path, value)
				local now = list()
				if now[i] and value ~= now[i].Effect then
					now[i] = switchEffect(now[i], value, ctx)
					setList(now)
				end
			end
			table.insert(
				children,
				Controls.Choice(
					card,
					"Effect",
					"Effect",
					effectHelp,
					{},
					effectOptions,
					false,
					effectCtx
				)
			)
			-- what it moves or colours
			table.insert(
				children,
				Controls.Choice(
					card,
					"Target",
					"Target",
					"What moves or changes colour. Greyed targets say why they can't be used.",
					{
						"Style",
						"Animate",
						i,
						"Target",
					},
					function()
						local now = list()[i]
						return targetOptions(if now then now.Effect else "", ctx)
					end,
					false,
					ctx
				)
			)
			-- its numbers and options
			local params: { any } = if info then info.Params else {}
			for _, param in params do
				local path = table.clone(base)
				table.insert(path, param.Key)
				local rowName = "Param_" .. param.Key
				if param.Type == "number" then
					table.insert(
						children,
						Controls.Number(card, rowName, param.Label, param.Help, path, {
							Min = param.Min or 0,
							Max = param.Max or 1,
							Step = param.Step or 0.1,
							Optional = true,
							Default = param.Default,
						}, ctx)
					)
				elseif param.Type == "boolean" then
					table.insert(
						children,
						Controls.Toggle(card, rowName, param.Label, param.Help, path, nil, ctx)
					)
				elseif param.Type == "Axis" then
					table.insert(
						children,
						Controls.Choice(card, rowName, param.Label, param.Help, path, function()
							return {
								{ Value = "X", Text = "X (nod)" },
								{ Value = "Y", Text = "Y (turn)" },
								{ Value = "Z", Text = "Z (tilt)" },
							}
						end, true, ctx)
					)
				elseif param.Type == "Colors" then
					local colors = if type(effect.Colors) == "table" then effect.Colors else {}
					for j = 1, #colors do
						local colorPath = table.clone(path)
						table.insert(colorPath, j)
						table.insert(
							children,
							Controls.Color(
								card,
								"Colour" .. j,
								("Colour %d"):format(j),
								param.Help,
								colorPath,
								false,
								ctx
							)
						)
					end
					local buttons = Instance.new("Frame")
					buttons.Name = "ColourButtons"
					buttons.BackgroundTransparency = 1
					buttons.Size = UDim2.new(1, 0, 0, ctx.Row)
					buttons.Parent = card
					hlist(buttons)
					local add = button(buttons, "+ Colour", ctx, OFF)
					add.Name = "AddColour"
					add.Size = UDim2.new(0, 110, 0, ctx.Row)
					add.Activated:Connect(function()
						local now = list()
						local c = now[i] and now[i].Colors
						if type(c) == "table" and #c < 6 then
							table.insert(c, Color3.fromRGB(255, 255, 255))
							setList(now)
						end
					end)
					local remove = button(buttons, "− Colour", ctx, OFF)
					remove.Name = "RemoveColour"
					remove.Size = UDim2.new(0, 110, 0, ctx.Row)
					remove.Activated:Connect(function()
						local now = list()
						local c = now[i] and now[i].Colors
						if type(c) == "table" and #c > 2 then
							table.remove(c)
							setList(now)
						end
					end)
				end
			end
		end
		-- + Add animation (greyed at the rarity limit, with the reason)
		local most, why = effectLimit(ctx.Get({ "Rarity" }))
		local count = #effects
		local add = button(holder, "+ Add animation", ctx, GOOD)
		add.Name = "AddAnimation"
		add.LayoutOrder = 1000
		add.Size = UDim2.new(1, 0, 0, ctx.Row)
		local full = count >= most
		if full then
			add.BackgroundColor3 = OFF
			add.TextTransparency = DIM
			add.AutoButtonColor = false
		end
		add.Activated:Connect(function()
			if full then
				ctx.Help(if most == 0 then why else ("That's the most: " .. why))
				return
			end
			local now = list()
			table.insert(now, newEffect(ctx))
			setList(now)
		end)
		if count == 0 then
			Controls.Note(holder, "No animations yet. " .. why, ctx).LayoutOrder = 999
		end
	end
	rebuild = function()
		if key() ~= builtKey then
			build()
		else
			for _, child in children do
				child.Refresh()
			end
		end
	end
	build()
	return { Frame = holder, Refresh = rebuild }
end

-- Walk style (Style.Motion) -------------------------------------------------------------------------

local function motionTable(
	value: any
): { Preset: string?, Walk: string?, Run: string?, Idle: string? }
	if type(value) == "string" then
		return { Preset = value }
	elseif type(value) == "table" then
		return {
			Preset = value.Preset,
			Walk = if value.Walk ~= nil then tostring(value.Walk) else nil,
			Run = if value.Run ~= nil then tostring(value.Run) else nil,
			Idle = if value.Idle ~= nil then tostring(value.Idle) else nil,
		}
	end
	return {}
end

-- Back to the shortest form: "Zombie", or a table when it has ids, or nil.
local function motionValue(m: { Preset: string?, Walk: string?, Run: string?, Idle: string? }): any
	if m.Walk == nil and m.Run == nil and m.Idle == nil then
		return m.Preset
	end
	return { Preset = m.Preset, Walk = m.Walk, Run = m.Run, Idle = m.Idle }
end

function Controls.Motion(parent: Instance, ctx: Context): Control
	local holder = blank(parent, "Motion")
	vlist(holder, 6)
	local path = { "Style", "Motion" }
	local options = function(): { Option }
		local out: { Option } = {}
		for _, entry in SkinMotion.Info do
			table.insert(out, { Value = entry.Name, Text = entry.Label or entry.Name })
		end
		return out
	end
	local presetCtx = table.clone(ctx)
	presetCtx.Get = function()
		return motionTable(ctx.Get(path)).Preset
	end
	presetCtx.Set = function(_p, value)
		local m = motionTable(ctx.Get(path))
		m.Preset = value
		ctx.Set(path, motionValue(m))
	end
	local preset = Controls.Choice(
		holder,
		"Preset",
		"Walk style",
		"How you walk: Zombie, Ghost, Robot, Bat... Rare and up.",
		path,
		options,
		true,
		presetCtx
	)
	preset.Frame.LayoutOrder = 1
	local children: { Control } = { preset }
	local open = false
	local expander = button(holder, "▶ Use my own animations", ctx, OFF)
	expander.Name = "OwnAnimations"
	expander.LayoutOrder = 2
	expander.Size = UDim2.new(1, 0, 0, ctx.Row)
	local own = blank(holder, "Own")
	own.LayoutOrder = 3
	vlist(own, 4)
	own.Visible = false
	Controls.Note(own, Config.SkinStudio.Text.AnimationNote, ctx, WARN).LayoutOrder = 0
	for i, which in { "Walk", "Run", "Idle" } do
		local box = Controls.Text(
			own,
			"Id_" .. which,
			which .. " id",
			"An uploaded animation id, like rbxassetid://1234567890 (R15 characters only).",
			function()
				return motionTable(ctx.Get(path))[which]
			end,
			function(text: string)
				local m: any = motionTable(ctx.Get(path))
				if text == "" then
					m[which] = nil
				else
					local digits = text:match("^rbxassetid://(%d+)$") or text:match("^(%d+)$")
					if not digits then
						ctx.Status(
							"An animation id is a number, like rbxassetid://1234567890.",
							"Warn"
						)
						return
					end
					m[which] = "rbxassetid://" .. digits
				end
				ctx.Set(path, motionValue(m))
			end,
			40,
			ctx
		)
		box.Frame.LayoutOrder = i
		table.insert(children, box)
	end
	local function refresh()
		local m = motionTable(ctx.Get(path))
		if m.Walk or m.Run or m.Idle then
			open = true
		end
		own.Visible = open
		expander.Text = (if open then "▼" else "▶") .. " Use my own animations"
		for _, child in children do
			child.Refresh()
		end
	end
	expander.Activated:Connect(function()
		open = not open
		refresh()
	end)
	refresh()
	return { Frame = holder, Refresh = refresh }
end

-- Catalog items (Style.Catalog) ---------------------------------------------------------------------

local CLOTHES = { "Shirt", "Pants", "TShirt", "ClassicFace" }

local function thumbnail(parent: Instance, id: number, size: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Thumb"
	image.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
	image.Size = UDim2.fromOffset(size, size)
	image.Image = SkinCatalog.Thumbnail(id)
	image.Parent = parent
	Theme.round(image, 6)
	return image
end

function Controls.Catalog(parent: Instance, ctx: Context): Control
	local holder = blank(parent, "Catalog")
	vlist(holder, 6)
	local builtKey = ""
	local children: { Control } = {}
	local function catalog(): any
		local value = ctx.Get({ "Style", "Catalog" })
		return if type(value) == "table" then SkinSchema.Copy(value) else {}
	end
	local function setCatalog(value: any)
		local empty = next(value) == nil
		ctx.Set({ "Style", "Catalog" }, if empty then nil else value)
	end
	local function key(): string
		local c = catalog()
		local parts = {}
		for _, entry in (if type(c.Accessories) == "table" then c.Accessories else {}) do
			table.insert(parts, tostring(entry.Id) .. tostring(entry.Type))
		end
		return table.concat(parts, ",")
	end
	local function build()
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(children)
		builtKey = key()
		local c = catalog()
		local accessories = if type(c.Accessories) == "table" then c.Accessories else {}
		for i, entry in accessories do
			local line = Instance.new("Frame")
			line.Name = "Accessory" .. i
			line.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
			line.Size = UDim2.new(1, 0, 0, ctx.Row + 8)
			line.LayoutOrder = i
			line.Parent = holder
			Theme.round(line, 6)
			hlist(line, 6)
			if type(entry.Id) == "number" then
				thumbnail(line, entry.Id, ctx.Row)
			end
			local known = if type(entry.Id) == "number" then ctx.Known(entry.Id) else nil
			local words = ("%s  (%s)  %s"):format(
				if known then known.Name else "Catalog item",
				tostring(entry.Type),
				tostring(entry.Id)
			)
			if known then
				words ..= "  by " .. tostring(known.Creator) .. (if known.RobloxMade
					then " ✓ Roblox"
					else "")
			end
			local l = label(line, words, ctx)
			l.Size = UDim2.new(1, -(ctx.Row * 2 + 16), 1, 0)
			local remove = button(line, "✕", ctx, Color3.fromRGB(140, 40, 40))
			remove.Name = "RemoveItem"
			remove.Activated:Connect(function()
				local now = catalog()
				table.remove(now.Accessories, i)
				if #now.Accessories == 0 then
					now.Accessories = nil
				end
				setCatalog(now)
			end)
		end
		-- id box + Look up
		local add = Instance.new("Frame")
		add.Name = "AddItem"
		add.BackgroundTransparency = 1
		add.Size = UDim2.new(1, 0, 0, ctx.Row)
		add.LayoutOrder = 100
		add.Parent = holder
		hlist(add)
		local box = Instance.new("TextBox")
		box.Name = "IdBox"
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Catalog id, e.g. 1234567890"
		box.Text = ""
		box.Font = Theme.Font
		box.TextSize = ctx.TextSize
		box.TextColor3 = Theme.Text
		box.BackgroundColor3 = Color3.fromRGB(35, 32, 48)
		box.Size = UDim2.new(1, -124, 0, ctx.Row)
		box.Parent = add
		Theme.round(box, 6)
		local look = button(add, "Look up", ctx, GOOD)
		look.Name = "LookUp"
		look.Size = UDim2.new(0, 116, 0, ctx.Row)
		local busy = false
		look.Activated:Connect(function()
			if busy then
				return
			end
			local id = tonumber((box.Text:gsub("%D", "")))
			if not id or id < 1 then
				ctx.Status(
					"Type a catalog id first (the number in the item's web address).",
					"Warn"
				)
				return
			end
			busy = true
			ctx.Status(Config.SkinStudio.Text.Loading)
			local info = ctx.Lookup(id)
			busy = false
			if not info then
				return -- the lookup said why
			end
			if not info.Allowed then
				ctx.Status(info.Problem or Config.SkinStudio.Text.NotAllowedCreator, "Error")
				return
			end
			local now = catalog()
			local kind = info.Type
			if kind == "Shirt" or kind == "Pants" or kind == "TShirt" or kind == "ClassicFace" then
				now[kind] = id
			elseif type(kind) == "string" then
				now.Accessories = if type(now.Accessories) == "table" then now.Accessories else {}
				for _, entry in now.Accessories do
					if entry.Id == id then
						ctx.Status("That item is already on this skin.", "Warn")
						return
					end
				end
				table.insert(now.Accessories, { Id = id, Type = kind })
			else
				ctx.Status(
					("%s is a %s: only hats, hair, face, neck, shoulder, front, back and waist accessories, classic clothes and classic faces can go on a skin."):format(
						info.Name,
						tostring(info.AssetType)
					),
					"Error"
				)
				return
			end
			box.Text = ""
			ctx.Status(("Added %s by %s."):format(info.Name, info.Creator), "Good")
			setCatalog(now)
		end)
		-- classic clothes and face
		for i, which in CLOTHES do
			local text = Controls.Text(
				holder,
				"Clothes_" .. which,
				which,
				if which == "ClassicFace"
					then "A classic face decal id (only on a skin without a head piece)."
					else "A classic " .. which .. " id. The skin needs Hide clothes off to show it.",
				function()
					local value = catalog()[which]
					return if type(value) == "number" then ("%d"):format(value) else nil
				end,
				function(value: string)
					local now = catalog()
					if value == "" then
						now[which] = nil
					else
						local id = tonumber((value:gsub("%D", "")))
						if not id or id < 1 then
							ctx.Status("A catalog id is a whole number.", "Warn")
							return
						end
						now[which] = id
					end
					setCatalog(now)
				end,
				20,
				ctx
			)
			text.Frame.LayoutOrder = 200 + i
			table.insert(children, text)
		end
	end
	local function refresh()
		if key() ~= builtKey then
			build()
		else
			for _, child in children do
				child.Refresh()
			end
		end
	end
	build()
	return { Frame = holder, Refresh = refresh }
end

return Controls
