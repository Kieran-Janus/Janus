--!strict
--[[
	Lobby section: the vote pads, a row of round pads in front of the Ready circle. Standing on
	one makes you ready (each pad is also tagged ReadyPad) and votes for the game it shows
	(src/server/Services/VotingService.luau, Config.VotePads).

	Workspace.Hub.VotePads
	  VotePad1 .. VotePadN   one Model per pad: the pad itself ("Pad", tags VotePad and
	                         ReadyPad, attribute VoteSlot = its number, left to right as you
	                         look from the Ready circle) and its glowing rim ("Rim"). The server
	                         colours both for the game or difficulty on offer; the floating sign
	                         above it is drawn by each player's screen (src/client/VotePadsUI.luau).

	Where: Config.Lobby.Zones.VotePads. Look: Config.VotePads (Pads, PadSize, Gap, PadHeight).
	Switched off (Config.Features.VotePads or ReadyPad = false): only an empty folder is made.

	VotePads.Build(hub, zone) -> Folder
	VotePads.Repair(hub, zone) -> Folder   the same, for a lobby saved without pads (HubService)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local VotePads = {}

local paint = Kit.painter(Config.Hub.Palette)

-- Where pad `slot` of `count` stands: in a row across the zone, slot 1 on the left as you look
-- from the Ready circle towards the middle of the lobby.
function VotePads.SlotCFrame(zone: Zone, slot: number, count: number): CFrame
	local cfg = Config.VotePads
	local step = cfg.PadSize + cfg.Gap
	return zone.CFrame * CFrame.new((slot - (count + 1) / 2) * step, 0, 0)
end

local function buildPad(parent: Instance, base: CFrame, slot: number): Model
	local cfg = Config.VotePads
	local model = Kit.model("VotePad" .. slot, parent)
	local look = cfg.Looks.Default
	local pad = paint.part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(cfg.PadHeight, cfg.PadSize, cfg.PadSize),
		CFrame = Kit.upright(base * CFrame.new(0, cfg.PadHeight / 2, 0)),
		Color = look.Color:Lerp(Color3.new(0, 0, 0), 0.45),
		Material = Enum.Material.Slate,
	}, model)
	pad:SetAttribute("VoteSlot", slot)
	CollectionService:AddTag(pad, Tags.VotePad)
	CollectionService:AddTag(pad, Tags.ReadyPad)
	paint.decor({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, cfg.PadSize - 0.5, cfg.PadSize - 0.5),
		CFrame = Kit.upright(base * CFrame.new(0, cfg.PadHeight + 0.04, 0)),
		Color = look.Color,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, model)
	paint.decor({
		Name = "Centre",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, cfg.PadSize - 1.4, cfg.PadSize - 1.4),
		CFrame = Kit.upright(base * CFrame.new(0, cfg.PadHeight + 0.06, 0)),
		Color = look.Color:Lerp(Color3.new(0, 0, 0), 0.55),
		Material = Enum.Material.Slate,
		CastShadow = false,
	}, model)
	model.PrimaryPart = pad
	return model
end

function VotePads.Build(hub: Instance, zone: Zone): Instance
	local folder = Kit.group("VotePads", hub)
	if not (Config.Features.VotePads and Config.Features.ReadyPad) then
		return folder
	end
	local count = math.max(1, math.floor(Config.VotePads.Pads))
	for slot = 1, count do
		buildPad(folder, VotePads.SlotCFrame(zone, slot, count), slot)
	end
	return folder
end

function VotePads.Repair(hub: Instance, zone: Zone): Instance
	local existing = hub:FindFirstChild("VotePads")
	if existing then
		existing:Destroy()
	end
	return VotePads.Build(hub, zone)
end

return VotePads
