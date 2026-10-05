--!strict
--[[
	Lobby section: the Candy Rush minigame.
	Where: Config.Lobby.Zones.CandyRush; settings: Config.Minigames.CandyRush.

	HubBuilder calls CandyRush.Build(hub, zone) with zone = { Name, CFrame, Size }: CFrame is
	the zone's centre on top of the plaza, its front (-Z) facing the hub centre; Size is (width,
	height or 0, depth) in studs. Decorations never go inside a zone.

	TODO(minigames agent): build it here, inside the "CandyRush" model. Tag its parts
	CandyRushStation / CandyRushPad (attribute Lane) / CandyRushBoard (src/shared/Tags.luau)
	so CandyRushService finds them. Use Kit.prop for decorations so they can be reskinned.
	Off (Config.Features.CandyRush = false): keep the empty model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local CandyRush = {}

function CandyRush.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("CandyRush", hub)
	if not Config.Features.CandyRush then
		return area
	end
	return area
end

return CandyRush
