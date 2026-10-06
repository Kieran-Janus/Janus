--!strict
--[[
	Glowing floor signs (Config.Lobby.FloorSigns): a flat pad lying on the ground in front of each
	lobby area, with the area's name in big glowing letters facing the players walking up to it.

	FloorSigns.Build(parent) -> Model   a Model "FloorSigns" with one part per sign whose area
	                                    and feature are on, named "<Zone>FloorSign", tagged
	                                    FloorSign (attribute Zone). Walk-through and never hit
	                                    by raycasts (it's floor text).
	FloorSigns.Place(entry) -> CFrame   where a sign goes: on the ground, Gap studs outside the
	                                    area's Front (or Back) edge, its -Z pointing at the area
	FloorSigns.FeatureOf(zone) -> string?  the Config.Features switch of that area's sign
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local HubLayout = require(script.Parent.HubLayout)
local HubPaths = require(script.Parent.HubPaths)

local FloorSigns = {}

type Entry = {
	Zone: string,
	Text: string,
	Color: Color3,
	Feature: string,
	Side: string?,
	Offset: Vector3?,
	LookAt: Vector3?,
	Width: number?,
}

local PIXELS_PER_STUD = 40
local QUARTER_TURN = CFrame.Angles(0, math.rad(-90), 0)

function FloorSigns.Place(entry: Entry): CFrame
	local cfg = Config.Lobby.FloorSigns
	local zone = HubLayout.Zone(entry.Zone)
	if entry.Offset then
		-- Its own spot (studs from Config.Hub.Center), facing LookAt (or the area).
		local y = zone.CFrame.Position.Y + cfg.Size.Y / 2 + 0.03
		local at = HubLayout.At(entry.Offset)
		local spot = Vector3.new(at.X, y, at.Z)
		local look = if entry.LookAt then HubLayout.At(entry.LookAt) else zone.CFrame.Position
		return CFrame.lookAt(spot, Vector3.new(look.X, y, look.Z))
	end
	local back = entry.Side == "Back"
	-- A zone's front (-Z) faces the middle of the lobby.
	local out = zone.Size.Z / 2 + cfg.Gap + cfg.Size.Z / 2
	local spot = zone.CFrame * CFrame.new(0, cfg.Size.Y / 2 + 0.03, if back then out else -out)
	local area = zone.CFrame.Position
	local target = Vector3.new(area.X, spot.Position.Y, area.Z)
	return CFrame.lookAt(spot.Position, target)
end

local function buildSign(entry: Entry, parent: Instance): Part
	local cfg = Config.Lobby.FloorSigns
	local pad = Instance.new("Part")
	pad.Name = entry.Zone .. "FloorSign"
	pad.Anchored = true
	-- A top-face SurfaceGui runs its width along the part's depth (Z): turn the pad a quarter
	-- so the words run left to right for someone walking up to the area.
	pad.Size = Vector3.new(cfg.Size.Z, cfg.Size.Y, entry.Width or cfg.Size.X)
	pad.CFrame = FloorSigns.Place(entry) * QUARTER_TURN
	pad.Color = cfg.PadColor
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = false
	pad.CastShadow = false
	pad:SetAttribute("Zone", entry.Zone)
	CollectionService:AddTag(pad, Tags.FloorSign)

	-- A thin glowing frame round the edge.
	local frame = Instance.new("SelectionBox")
	frame.Name = "Glow"
	frame.Adornee = pad
	frame.Color3 = entry.Color
	frame.LineThickness = 0.08
	frame.SurfaceTransparency = 1
	frame.Parent = pad

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = cfg.Glow
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.Parent = pad
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Font = cfg.Font
	label.Text = entry.Text
	label.TextColor3 = entry.Color
	label.TextScaled = true
	label.TextWrapped = true -- two bigger lines when that fits better than one
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	if cfg.LightRange > 0 then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = entry.Color
		light.Range = cfg.LightRange
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = pad
	end
	pad.Parent = parent
	return pad
end

-- The Config.Features switch of the sign for lobby area `zone` ("" = always on, nil = no sign).
function FloorSigns.FeatureOf(zone: string): string?
	for _, entry in Config.Lobby.FloorSigns.Signs do
		if entry.Zone == zone then
			return entry.Feature
		end
	end
	return nil
end

function FloorSigns.Build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "FloorSigns"
	model.Parent = parent
	local cfg = Config.Lobby.FloorSigns
	if not cfg.On then
		return model
	end
	for _, entry in cfg.Signs do
		if HubPaths.Enabled(entry) then
			buildSign(entry, model)
		end
	end
	return model
end

return FloorSigns
