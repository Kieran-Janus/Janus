--!strict
--[[
	Where things go in the lobby. Shared by HubBuilder, HubExtras, Npcs and the lobby
	sections (src/server/Hub/Sections/).

	HubLayout.At(offset) -> Vector3             Config.Hub.Center + offset
	HubLayout.FacingCenter(position) -> CFrame  at `position`, front (-Z) towards the hub centre
	HubLayout.Zone(name) -> Zone                the Config.Lobby.Zones area called `name`: its
	                                            centre on the plaza top (facing the hub centre)
	                                            and size. A name with no zone gets the hub centre.
	HubLayout.Zones() -> { Zone }               every zone, sorted by name
	HubLayout.Blocked(position, margin?) -> boolean
	                                            true inside any zone (plus `margin` studs):
	                                            decorations skip these spots, so every lobby
	                                            area stays free for the thing it is for
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lobby = require(ReplicatedStorage.Shared.Lobby)

export type Zone = {
	Name: string,
	CFrame: CFrame, -- centre of the zone on top of the plaza, front (-Z) towards the hub centre
	Size: Vector3, -- width, height (0 = any height), depth in studs
}

local HubLayout = {}

function HubLayout.At(offset: Vector3): Vector3
	return Config.Hub.Center + offset
end

function HubLayout.FacingCenter(position: Vector3): CFrame
	local center: Vector3 = Config.Hub.Center
	local target = Vector3.new(center.X, position.Y, center.Z)
	if (target - position).Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, target)
end

function HubLayout.Zone(name: string): Zone
	if Config.Lobby.Zones[name] then
		return { Name = name, CFrame = Lobby.ZoneCFrame(name), Size = Lobby.ZoneSize(name) }
	end
	return {
		Name = name,
		CFrame = CFrame.new(HubLayout.At(Vector3.new(0, 1, 0))),
		Size = Vector3.zero,
	}
end

function HubLayout.Zones(): { Zone }
	local names = {}
	for name in Config.Lobby.Zones do
		table.insert(names, name)
	end
	table.sort(names)
	local zones = {}
	for _, name in names do
		table.insert(zones, HubLayout.Zone(name))
	end
	return zones
end

function HubLayout.Blocked(position: Vector3, margin: number?): boolean
	for name in Config.Lobby.Zones do
		if Lobby.InZone(position, name, margin) then
			return true
		end
	end
	return false
end

return HubLayout
