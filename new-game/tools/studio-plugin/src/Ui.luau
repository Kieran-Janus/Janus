--!strict
--[[
	Small helpers that build the Pumpkin Tools panel: a scrolling list of sections, labels,
	buttons, text boxes and rows, in Studio-friendly dark colours.
]]

local Ui = {}

local COLORS = {
	Back = Color3.fromRGB(37, 30, 46),
	Section = Color3.fromRGB(52, 42, 66),
	Text = Color3.fromRGB(240, 234, 248),
	Dim = Color3.fromRGB(180, 168, 196),
	Button = Color3.fromRGB(255, 130, 20),
	ButtonText = Color3.fromRGB(30, 18, 8),
	Quiet = Color3.fromRGB(86, 72, 108),
	Input = Color3.fromRGB(24, 19, 30),
	Good = Color3.fromRGB(120, 220, 140),
	Bad = Color3.fromRGB(255, 120, 110),
}
Ui.Colors = COLORS

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function list(parent: Instance, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
end

local function pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- The scrolling page inside the widget.
function Ui.Page(widget: Instance): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundColor3 = COLORS.Back
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 8
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pad(page, 8)
	list(page, 8)
	page.Parent = widget
	return page
end

-- A boxed group with a title; returns the frame to put things in.
function Ui.Section(page: Instance, title: string): Frame
	local box = Instance.new("Frame")
	box.Name = title
	box.LayoutOrder = nextOrder()
	box.Size = UDim2.new(1, -4, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = COLORS.Section
	box.BorderSizePixel = 0
	corner(box, 8)
	pad(box, 8)
	list(box, 6)
	local heading = Ui.Label(box, title, 16)
	heading.Font = Enum.Font.GothamBold
	heading.TextColor3 = COLORS.Button
	box.Parent = page
	return box
end

function Ui.Label(parent: Instance, text: string, size: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = nextOrder()
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = size or 13
	label.TextColor3 = COLORS.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.RichText = true
	label.Text = text
	label.Parent = parent
	return label
end

function Ui.Hint(parent: Instance, text: string): TextLabel
	local label = Ui.Label(parent, text, 12)
	label.TextColor3 = COLORS.Dim
	return label
end

function Ui.Button(parent: Instance, text: string, onClick: () -> (), quiet: boolean?): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = nextOrder()
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = if quiet then COLORS.Quiet else COLORS.Button
	b.TextColor3 = if quiet then COLORS.Text else COLORS.ButtonText
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextWrapped = true
	b.AutoButtonColor = true
	b.Text = text
	corner(b, 6)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

function Ui.Input(parent: Instance, placeholder: string, multiLine: boolean?): TextBox
	local box = Instance.new("TextBox")
	box.LayoutOrder = nextOrder()
	box.Size = UDim2.new(1, 0, 0, if multiLine then 44 else 28)
	box.BackgroundColor3 = COLORS.Input
	box.TextColor3 = COLORS.Text
	box.PlaceholderColor3 = COLORS.Dim
	box.PlaceholderText = placeholder
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.ClearTextOnFocus = false
	box.TextWrapped = true
	box.MultiLine = multiLine == true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = ""
	pad(box, 6)
	corner(box, 6)
	box.Parent = parent
	return box
end

-- A horizontal row; its children share the width (each gets `weights[i]` of it).
function Ui.Row(parent: Instance, height: number?): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, 0, 0, height or 28)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	row.Parent = parent
	return row
end

-- Makes the children of a row share its width.
function Ui.Share(row: Frame, weights: { number })
	local total = 0
	for _, w in weights do
		total += w
	end
	local i = 0
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			i += 1
			local share = (weights[i] or 1) / total
			child.Size = UDim2.new(share, -6, 1, 0)
		end
	end
end

-- An empty holder that can be cleared and refilled (lists that change).
function Ui.Holder(parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.LayoutOrder = nextOrder()
	holder.Size = UDim2.fromScale(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	list(holder, 4)
	holder.Parent = parent
	return holder
end

function Ui.Clear(holder: Instance)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui
