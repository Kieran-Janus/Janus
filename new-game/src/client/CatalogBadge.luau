--!strict
--[[
	Small pictures of a skin's Roblox catalog items (Style.Catalog) on shop, crate and Skin
	Studio cards. They are 2D thumbnails from Roblox (rbxthumb://): a 3D preview can't load
	catalog items, so the picture shows what the server adds when you wear the skin.

	CatalogBadge.Add(parent, item) -> Frame?
	    puts a row of up to Config.SkinCatalog.MaxThumbnails pictures across the bottom of
	    `parent` (a card's preview). nil (nothing made) when the skin has no catalog items,
	    the feature is off (Config.Features.SkinCatalog) or ShowThumbnails is false.
	On a PC, hovering a picture says "Roblox catalog item". With ShowBuyButtons (off by
	default, to stay kid-friendly) each picture gets a small Buy button that opens Roblox's own
	buy window (MarketplaceService:PromptPurchase; no remote, the game never sells it).
	Everything lives under the returned Frame, so it goes when the card goes.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SkinCatalog = require(ReplicatedStorage.Shared.SkinCatalog)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local CatalogBadge = {}

local GAP = 3 -- pixels between pictures
local BUY_HEIGHT = 16

function CatalogBadge.Add(parent: GuiObject, item: any): Frame?
	local cfg = Config.SkinCatalog
	if not Config.Features.SkinCatalog or not cfg.ShowThumbnails then
		return nil
	end
	local style = if type(item) == "table" and type(item.Style) == "table" then item.Style else nil
	local catalog = if style then (SkinCatalog.Normalize(style.Catalog)) else nil
	local ids = SkinCatalog.Ids(catalog)
	if #ids == 0 then
		return nil
	end
	local size = if Layout.IsPhone() then cfg.PhoneBadgeSize else cfg.BadgeSize
	local buy = cfg.ShowBuyButtons
	local height = size + (if buy then BUY_HEIGHT + 2 else 0)

	local row = Instance.new("Frame")
	row.Name = "CatalogBadge"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 4, 1, -4)
	row.Size = UDim2.new(1, -8, 0, height)
	row.ZIndex = 4
	local items = Instance.new("Frame")
	items.Name = "Items"
	items.BackgroundTransparency = 1
	items.Size = UDim2.fromScale(1, 1)
	items.ZIndex = 4
	items.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = items

	-- "Roblox catalog item", over the pictures while the mouse is on one (PC).
	local hover = Theme.label(cfg.Text.Hover, math.max(12, Config.UI.MinTextSize), row)
	hover.Name = "Hover"
	hover.Visible = false
	hover.ZIndex = 6
	hover.AnchorPoint = Vector2.new(1, 1)
	hover.Position = UDim2.new(1, 0, 0, -2)
	hover.Size = UDim2.fromOffset(0, 18)
	hover.AutomaticSize = Enum.AutomaticSize.X
	hover.BackgroundColor3 = Theme.Background
	hover.BackgroundTransparency = 0.15
	hover.TextStrokeTransparency = 0.6
	Theme.round(hover, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = hover

	for i = 1, math.min(#ids, cfg.MaxThumbnails) do
		local id = ids[i]
		local slot = Instance.new("Frame")
		slot.Name = "Item"
		slot.LayoutOrder = i
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(size, height)
		slot.ZIndex = 4
		slot:SetAttribute("AssetId", id)
		slot.Parent = items

		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.Image = SkinCatalog.Thumbnail(id)
		picture.BackgroundColor3 = Color3.fromRGB(235, 235, 245)
		picture.BackgroundTransparency = 0.2
		picture.Size = UDim2.fromOffset(size, size)
		picture.ZIndex = 5
		picture.Parent = slot
		Theme.round(picture, 6)
		picture.MouseEnter:Connect(function()
			hover.Visible = true
		end)
		picture.MouseLeave:Connect(function()
			hover.Visible = false
		end)

		if buy then
			local button = Theme.button(cfg.Text.Buy, slot)
			button.Name = "Buy"
			button.ZIndex = 5
			button.TextSize = math.max(10, Config.UI.MinTextSize)
			button.Position = UDim2.fromOffset(0, size + 2)
			button.Size = UDim2.fromOffset(size, BUY_HEIGHT)
			Theme.round(button, 4)
			button.Activated:Connect(function()
				local player = Players.LocalPlayer
				if player then
					pcall(function()
						MarketplaceService:PromptPurchase(player, id)
					end)
				end
			end)
		end
	end
	row.Parent = parent
	return row
end

return CatalogBadge
