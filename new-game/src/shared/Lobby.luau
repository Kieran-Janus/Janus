--!strict
--[[
	Lobby zone helpers (shared by the server and the client), from Config.Lobby.Zones.

	Lobby.ZoneCFrame(name) -> CFrame   the zone's centre on top of the plaza, turned so its
	                                   front (-Z, LookVector) faces the middle of the hub
	Lobby.ZoneSize(name) -> Vector3    (width, Height or 0, depth) in studs
	Lobby.InZone(position, name, margin?) -> boolean
	                                   true if `position` is inside the zone's area (plus
	                                   `margin` studs on every side). Height is only
	                                   checked for zones that have one (Parkour).
	Unknown zone names error, so a typo shows up straight away.
]]

local Config = require(script.Parent.Config)

local Lobby = {}

type Zone = { Offset: Vector3, Size: Vector3, Height: number? }

local function zone(name: string): Zone
	local z = Config.Lobby.Zones[name]
	if not z then
		error("Config.Lobby.Zones has no zone named " .. tostring(name), 3)
	end
	return z
end

-- Height of the plaza's top surface (players stand here).
function Lobby.GroundY(): number
	return Config.Hub.Center.Y + 1
end

function Lobby.ZoneCFrame(name: string): CFrame
	local z = zone(name)
	local center: Vector3 = Config.Hub.Center
	local position = Vector3.new(center.X + z.Offset.X, Lobby.GroundY(), center.Z + z.Offset.Z)
	local toCenter = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
	if toCenter.Magnitude < 1e-3 then
		return CFrame.new(position) -- a zone in the exact middle has no "towards the middle"
	end
	return CFrame.lookAt(position, position + toCenter.Unit)
end

function Lobby.ZoneSize(name: string): Vector3
	local z = zone(name)
	return Vector3.new(z.Size.X, z.Height or 0, z.Size.Z)
end

function Lobby.InZone(position: Vector3, name: string, margin: number?): boolean
	local z = zone(name)
	local m = margin or 0
	local localPos = Lobby.ZoneCFrame(name):PointToObjectSpace(position)
	if math.abs(localPos.X) > z.Size.X / 2 + m or math.abs(localPos.Z) > z.Size.Z / 2 + m then
		return false
	end
	local height = z.Height
	if height then
		return localPos.Y >= -m and localPos.Y <= height + m
	end
	return true
end

return Lobby
