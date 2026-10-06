--!strict
--[[
	CRAZY skins' animated effects, drawn by each player's own screen (the server only puts the
	skin on and tags its model with Tags.SkinFx, see src/shared/Cosmetics.luau):
	  Rainbow  a rainbow tint and outline over the whole character (a Highlight) and the
	           skin's rainbow parts cycling through the colours
	  Pulse    the skin's glow light pulses
	  Orbit    little pieces (pumpkins, candies, ghosts...) flying around the character
	Only the closest Config.Skins.Effects.MaxAnimated CRAZY players animate, so phones stay
	fast; nothing here changes what other players see. On/off: Config.Features.SkinEffects.

	SkinFx.Start()                    starts watching (ShopUI.Mount calls it; safe to call twice)
	SkinFx.AnimatePreview(model) -> stop
	                                  cycles the rainbow parts of a shop or crate preview while
	                                  its ViewportFrame is on screen; call stop() (or destroy
	                                  the model) when done
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HeadPieces = require(ReplicatedStorage.Shared.HeadPieces)
local Items = require(ReplicatedStorage.Shared.Items)
local Tags = require(ReplicatedStorage.Shared.Tags)

local SkinFx = {}

type Entry = {
	Model: Model, -- the character's Cosmetic_Skin model (tagged SkinFx)
	Crazy: any, -- the skin's Style.Crazy
	Active: boolean,
	Rainbow: { BasePart },
	Base: { [BasePart]: Color3 }, -- the rainbow parts' colours from the server
	Tint: Highlight?,
	Light: PointLight?,
	Brightness: number,
	Orbit: { Model },
}

local entries: { [Model]: Entry } = {}
local previews: { [Model]: { BasePart } } = {}
local folder: Folder? = nil
local started = false
local heartbeat: RBXScriptConnection? = nil
local nextPick = 0

local function settings()
	return Config.Skins.Effects
end

local function hue(t: number, offset: number): Color3
	return Color3.fromHSV((t / settings().RainbowSeconds + offset) % 1, 0.7, 1)
end

local function rainbowParts(root: Instance): { BasePart }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Rainbow") == true then
			table.insert(list, d)
		end
	end
	return list
end

local function characterOf(entry: Entry): Model?
	local parent = entry.Model.Parent
	return if parent and parent:IsA("Model") then parent else nil
end

local function rootOf(entry: Entry): BasePart?
	local character = characterOf(entry)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function fxFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local new = Instance.new("Folder")
	new.Name = "LocalSkinFx" -- only on this player's screen
	new.Parent = Workspace
	folder = new
	return new
end

local function activate(entry: Entry)
	if entry.Active then
		return
	end
	local character = characterOf(entry)
	if not character then
		return
	end
	entry.Active = true
	local crazy = entry.Crazy
	local fx = settings()
	entry.Rainbow = if crazy.Rainbow then rainbowParts(entry.Model) else {}
	entry.Base = {}
	for _, p in entry.Rainbow do
		entry.Base[p] = p.Color
	end
	if crazy.Rainbow then
		local tint = Instance.new("Highlight")
		tint.Name = "SkinFxTint"
		tint.Adornee = character
		-- Occluded: never shows through walls (no free wallhack for hide and seek)
		tint.DepthMode = Enum.HighlightDepthMode.Occluded
		tint.FillTransparency = fx.TintTransparency
		tint.OutlineTransparency = fx.OutlineTransparency
		tint.Parent = entry.Model
		entry.Tint = tint
	end
	local light = entry.Model:FindFirstChild("SkinGlow", true)
	if crazy.Pulse and light and light:IsA("PointLight") then
		entry.Light = light
		entry.Brightness = light.Brightness
	end
	if type(crazy.Orbit) == "string" then
		local count = math.clamp(if type(crazy.Count) == "number" then crazy.Count else 3, 1, 8)
		local tint = if typeof(crazy.OrbitColor) == "Color3" then crazy.OrbitColor else nil
		for _ = 1, count do
			local piece = HeadPieces.Orbit(crazy.Orbit, tint, fx.OrbitScale)
			piece.Parent = fxFolder()
			table.insert(entry.Orbit, piece)
		end
	end
end

local function deactivate(entry: Entry)
	if not entry.Active then
		return
	end
	entry.Active = false
	for p, c in entry.Base do
		if p.Parent then
			p.Color = c
		end
	end
	entry.Rainbow = {}
	entry.Base = {}
	if entry.Tint then
		entry.Tint:Destroy()
		entry.Tint = nil
	end
	if entry.Light then
		entry.Light.Brightness = entry.Brightness
		entry.Light = nil
	end
	for _, piece in entry.Orbit do
		piece:Destroy()
	end
	entry.Orbit = {}
end

local function onTagged(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local item = Items.Get(instance:GetAttribute("ItemId"))
	local crazy = item and item.Style and item.Style.Crazy
	if type(crazy) ~= "table" then
		return
	end
	entries[instance] = {
		Model = instance,
		Crazy = crazy,
		Active = false,
		Rainbow = {},
		Base = {},
		Tint = nil,
		Light = nil,
		Brightness = 0,
		Orbit = {},
	}
	nextPick = 0 -- pick who animates on the next frame
end

local function onUntagged(instance: Instance)
	local entry = entries[instance :: Model]
	if entry then
		deactivate(entry)
		entries[instance :: Model] = nil
	end
end

-- Animates the closest CRAZY players (up to MaxAnimated, within MaxDistance).
local function pick()
	local fx = settings()
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	local near = {}
	for model, entry in entries do
		local root = if model:IsDescendantOf(Workspace) then rootOf(entry) else nil
		local distance = if root then (root.Position - from).Magnitude else math.huge
		if distance <= fx.MaxDistance then
			table.insert(near, { Entry = entry, Distance = distance })
		else
			deactivate(entry)
		end
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	for i, candidate in near do
		if i <= fx.MaxAnimated then
			activate(candidate.Entry)
		else
			deactivate(candidate.Entry)
		end
	end
end

local function guiShown(instance: Instance): boolean
	local node: Instance? = instance
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function step()
	local now = os.clock()
	local fx = settings()
	if now >= nextPick then
		nextPick = now + fx.CheckSeconds
		pick()
	end
	for _, entry in entries do
		if not entry.Active then
			continue
		end
		for i, p in entry.Rainbow do
			p.Color = hue(now, i * 0.11)
		end
		local tint = entry.Tint
		if tint then
			tint.FillColor = hue(now, 0)
			tint.OutlineColor = hue(now, 0.5)
		end
		local light = entry.Light
		if light then
			local wave = (math.sin(now * math.pi * 2 / fx.PulseSeconds) + 1) / 2
			light.Brightness = entry.Brightness * (fx.PulseLow + (1 - fx.PulseLow) * wave)
		end
		local root = rootOf(entry)
		if root and #entry.Orbit > 0 then
			local centre = root.Position + Vector3.new(0, fx.OrbitHeight, 0)
			local turn = now * math.pi * 2 / fx.OrbitSeconds
			for k, piece in entry.Orbit do
				local a = turn + (k - 1) / #entry.Orbit * math.pi * 2
				local bob = math.sin(now * 2 + k) * fx.OrbitBob
				piece:PivotTo(
					CFrame.new(
						centre
							+ Vector3.new(
								math.cos(a) * fx.OrbitRadius,
								bob,
								math.sin(a) * fx.OrbitRadius
							)
					) * CFrame.Angles(0, -a, 0)
				)
			end
		end
	end
	for model, parts in previews do
		if model.Parent == nil then
			previews[model] = nil
		elseif guiShown(model) then
			for i, p in parts do
				p.Color = hue(now, i * 0.11)
			end
		end
	end
end

local function ensureLoop()
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

function SkinFx.Start()
	if started or not Config.Features.SkinEffects then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(Tags.SkinFx):Connect(onTagged)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinFx):Connect(onUntagged)
	for _, instance in CollectionService:GetTagged(Tags.SkinFx) do
		onTagged(instance)
	end
	ensureLoop()
end

function SkinFx.AnimatePreview(model: Model): () -> ()
	if not Config.Features.SkinEffects then
		return function() end
	end
	local parts = rainbowParts(model)
	if #parts == 0 then
		return function() end
	end
	previews[model] = parts
	ensureLoop()
	return function()
		previews[model] = nil
	end
end

return SkinFx
