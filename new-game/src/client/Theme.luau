--!strict
-- Shared look for client UI so every panel matches the HUD.
local UIMotion = require(script.Parent.UIMotion)

local Theme = {}

Theme.Background = Color3.fromRGB(20, 20, 30)
Theme.Button = Color3.fromRGB(45, 40, 60)
Theme.Selected = Color3.fromRGB(255, 130, 20)
Theme.Text = Color3.new(1, 1, 1)
Theme.Muted = Color3.fromRGB(180, 180, 195)
Theme.Font = Enum.Font.GothamBold

function Theme.round(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
end

function Theme.label(text: string, size: number, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Theme.Text
	label.Font = Theme.Font
	label.TextSize = size
	label.Text = text
	label.Parent = parent
	return label
end

-- A rounded button in the game's font. `parent` can be nil (parent it yourself later);
-- `color` is the background (default Theme.Button). It squashes when pressed (UIMotion.Press).
function Theme.button(text: string, parent: Instance?, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color or Theme.Button
	button.TextColor3 = Theme.Text
	button.Font = Theme.Font
	button.TextSize = 16
	button.Text = text
	button.AutoButtonColor = true
	Theme.round(button, 8)
	UIMotion.Press(button)
	button.Parent = parent
	return button
end

function Theme.panel(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Background
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	Theme.round(frame)
	return frame
end

return Theme
