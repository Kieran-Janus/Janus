--!strict
--[[
	Lobby section: the Web Scour minigame.
	Where: Config.Lobby.Zones.WebScour; settings: Config.Minigames.WebScour.

	HubBuilder calls WebScour.Build(hub, zone) with zone = { Name, CFrame, Size }: CFrame is
	the zone's centre on top of the plaza, its front (-Z) facing the hub centre; Size is (width,
	height or 0, depth) in studs. Decorations never go inside a zone.

	TODO(minigames agent): build it here, inside the "WebScour" model. Tag its parts
	WebScourStart / WebScourSpot (src/shared/Tags.luau) so WebScourService finds them. Use
	Kit.prop for decorations so they can be reskinned.
	Off (Config.Features.WebScour = false): keep the empty model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local WebScour = {}

function WebScour.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("WebScour", hub)
	if not Config.Features.WebScour then
		return area
	end
	return area
end

return WebScour
