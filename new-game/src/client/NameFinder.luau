--!strict
--[[
	Name finder (Studio tool, F8 > "Name finder on/off"; server side in
	src/server/Services/MapVisitService.luau).

	While it is on, clicking or tapping anything in the world outlines it and shows a box with:
	  - its name and where it is, e.g. Map > Mansion > Staircase > Step3
	  - the prop name, if it is a prop (every copy of it can be swapped at once)
	  - the file that builds it (a round map's builder or a lobby section)
	  - its size, colour and material
	The top line of the box is selectable: click it, Ctrl+A, Ctrl+C, and paste it to Claude Code
	("make Map.Mansion.Staircase taller"). Settings: Config.Admin.Tools.
	Only shows anything in Studio, for players the server marked Admin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local NameFinder = {}

-- Which file builds a thing: a round map's builder, or the lobby section it is in.
local HUB_FILES: { [string]: string } = {
	CandyRush = "src/server/Hub/Sections/CandyRush.luau",
	CrateStand = "src/server/Hub/Sections/CrateStand.luau",
	EasterEggs = "src/server/Hub/Sections/EasterEggs.luau",
	Parkour = "src/server/Hub/Sections/Parkour.luau",
	ReadyArea = "src/server/Hub/Sections/ReadyArea.luau",
	Shop = "src/server/Hub/Sections/Shop.luau",
	TowerParkour = "src/server/Hub/Sections/TowerParkour.luau",
	WebScour = "src/server/Hub/Sections/WebScour.luau",
	Npcs = "src/server/Hub/Npcs.luau",
	FloorSigns = "src/server/Hub/FloorSigns.luau",
}

-- "Workspace.Map.Mansion.Stairs" -> "Map.Mansion.Stairs" (the copyable code).
local function code(instance: Instance): string
	return (instance:GetFullName():gsub("^Workspace%.", ""))
end

local function builderFile(instance: Instance): string?
	local top: Instance = instance
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent :: Instance
	end
	if top.Name == "Map" then
		local id = top:GetAttribute("MapId")
		for _, def in Config.Maps.List do
			if def.Id == id then
				return ("src/server/Maps/%s.luau (settings: src/shared/Config/Maps/%s.luau)"):format(
					tostring(def.Builder),
					tostring(def.Id)
				)
			end
		end
	elseif top.Name == "Hub" then
		local section = instance:FindFirstAncestorWhichIsA("Folder")
		local node: Instance? = instance
		while node and node.Parent ~= top do
			node = node.Parent
		end
		local name = if node then node.Name elseif section then section.Name else ""
		return HUB_FILES[name] or "src/server/Hub/HubBuilder.luau (lobby)"
	end
	return nil
end

local function propOf(instance: Instance): Model?
	local node: Instance? = instance
	while node and node ~= workspace do
		if node:IsA("Model") and typeof(node:GetAttribute("PropName")) == "string" then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function colorName(c: Color3): string
	return ("%d, %d, %d"):format(
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

function NameFinder.Mount(gui: ScreenGui)
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local cfg = Config.Admin.Tools
	local minText = Config.UI.MinTextSize

	local panel = Theme.panel(gui)
	panel.Name = "NameFinder"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 60)
	panel.Size = UDim2.fromOffset(380, 190)
	panel.Visible = false
	panel.ZIndex = 40
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = panel

	local title = Theme.label("NAME FINDER: click anything", minText, panel)
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = cfg.NameFinderHighlight
	title.ZIndex = 41

	-- The name to copy: a TextBox, so it can be selected (Ctrl+A, Ctrl+C) but not changed.
	local nameBox = Instance.new("TextBox")
	nameBox.Name = "Code"
	nameBox.ClearTextOnFocus = false
	nameBox.TextEditable = false
	nameBox.Text = "(nothing yet)"
	nameBox.Font = Enum.Font.Code
	nameBox.TextSize = 15
	nameBox.TextWrapped = true
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.TextColor3 = Theme.Text
	nameBox.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	nameBox.Position = UDim2.fromOffset(0, 22)
	nameBox.Size = UDim2.new(1, 0, 0, 44)
	nameBox.ZIndex = 41
	Theme.round(nameBox, 6)
	nameBox.Parent = panel

	local details = Theme.label("", minText, panel)
	details.Name = "Details"
	details.Font = Enum.Font.Gotham
	details.Position = UDim2.fromOffset(0, 72)
	details.Size = UDim2.new(1, 0, 1, -80)
	details.TextWrapped = true
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.TextColor3 = Theme.Muted
	details.ZIndex = 41

	local highlight = Instance.new("Highlight")
	highlight.Name = "NameFinderOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = cfg.NameFinderHighlight
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = gui

	local function on(): boolean
		return player:GetAttribute(cfg.NameFinderAttribute) == true
	end

	local function show(part: BasePart)
		local prop = propOf(part)
		-- Outline the prop or small model it belongs to, never a whole map or lobby.
		local model = prop or part:FindFirstAncestorWhichIsA("Model")
		local whole = model ~= nil and (model.Parent == workspace or model == workspace)
		local outlined: Instance = if model and not whole then model else part
		highlight.Adornee = outlined
		highlight.Enabled = true
		-- Many parts share a name ("Wall"), so the position comes with it: from the map's centre
		-- on a round map (the offsets its settings file uses), else world coordinates.
		local position = part.Position
		local mapModel = part:FindFirstAncestor("Map")
		if mapModel and mapModel.Parent == workspace then
			position -= Config.Maps.Origin
		end
		nameBox.Text = ("%s at %d, %d, %d"):format(
			code(if prop then prop else part),
			math.round(position.X),
			math.round(position.Y),
			math.round(position.Z)
		)
		local lines = {}
		if prop then
			table.insert(
				lines,
				("Prop: %s (every copy can be swapped at once)"):format(
					tostring(prop:GetAttribute("PropName"))
				)
			)
			table.insert(lines, "Part clicked: " .. code(part))
		end
		local file = builderFile(part)
		if file then
			table.insert(lines, "Built by: " .. file)
		end
		table.insert(
			lines,
			("Size %.1f x %.1f x %.1f, colour %s, %s"):format(
				part.Size.X,
				part.Size.Y,
				part.Size.Z,
				colorName(part.Color),
				part.Material.Name
			)
		)
		details.Text = table.concat(lines, "\n")
	end

	local function refresh()
		local visible = on()
		panel.Visible = visible
		if not visible then
			highlight.Enabled = false
			highlight.Adornee = nil
		end
	end
	player:GetAttributeChangedSignal(cfg.NameFinderAttribute):Connect(refresh)
	refresh()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not on() then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = {}
		if player.Character then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		-- Look through invisible parts (hitboxes, zones) to what you can see.
		for _ = 1, 8 do
			local hit = workspace:Raycast(ray.Origin, ray.Direction * cfg.NameFinderRange, params)
			if not hit then
				return
			end
			local part = hit.Instance
			if part:IsA("BasePart") and part.Transparency < 0.95 then
				show(part)
				return
			end
			table.insert(ignore, part)
			params.FilterDescendantsInstances = ignore
		end
	end)
end

return NameFinder
