--!strict
--[[
	Lobby section: the parkour course.
	Where: Config.Lobby.Zones.Parkour (it also has a Height); settings: Config.Parkour.

	HubBuilder calls Parkour.Build(hub, zone) with zone = { Name, CFrame, Size }: CFrame is the
	zone's centre on top of the plaza, its front (-Z) facing the hub centre; Size is (width,
	height or 0, depth) in studs. Decorations never go inside a zone.

	TODO(parkour agent): build the course here, inside the "Parkour" model. Tag its parts
	ParkourStart / ParkourCheckpoint (attribute Index) / ParkourFinish / ParkourHazard
	(src/shared/Tags.luau) so ParkourService finds them. Use Kit.prop for decorations so they
	can be reskinned. Off (Config.Features.Parkour = false): keep the empty model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local Parkour = {}

function Parkour.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("Parkour", hub)
	if not Config.Features.Parkour then
		return area
	end
	return area
end

return Parkour
