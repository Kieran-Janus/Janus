--!strict
--[[
	Lobby section: the hidden Easter egg pumpkins.
	Where: anywhere in the lobby (there is no EasterEggs zone, so `zone` is the hub centre with
	Size 0); settings: Config.EasterEggs.

	HubBuilder calls EasterEggs.Build(hub, zone) with zone = { Name, CFrame, Size }.

	TODO(easter eggs agent): build the eggs here, inside the "EasterEggs" model. Tag each egg
	EasterEgg with the attributes EggId and Coins (src/shared/Tags.luau) so EasterEggService
	finds it. Off (Config.Features.EasterEggs = false): keep the empty model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local EasterEggs = {}

function EasterEggs.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("EasterEggs", hub)
	if not Config.Features.EasterEggs then
		return area
	end
	return area
end

return EasterEggs
