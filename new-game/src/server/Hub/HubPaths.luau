--!strict
--[[
	The lobby's paths, worked out from Config (no parts): the smooth stone walkways the plaza
	draws (HubBuilder) and the glowing stepping stones along them (HubExtras).

	  - the promenade: a ring round the cauldron (Config.Hub.Plaza.Promenade)
	  - from the spawn: straight to the Ready arch, and two curving paths to the promenade
	  - from the promenade out to the front of every lobby zone in Config.Hub.Signposts.Zones
	    whose feature is on (around the clock tower when it stands in the way)

	HubPaths.Network() -> { Path }       every path (not the promenade ring)
	HubPaths.Enabled(entry) -> boolean   a Signposts.Zones entry whose zone and feature are on
	HubPaths.OnPath(position, margin?) -> boolean
	                                     true on a path or the promenade (decorations that
	                                     would trip players skip these spots)
	Points are on the plaza top (y = Config.Hub.Center.Y + 1).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HubLayout = require(script.Parent.HubLayout)

export type Path = {
	Name: string,
	Points: { Vector3 },
	Width: number,
	Zone: string?, -- the lobby zone it leads to
}

local HubPaths = {}

local function ground(x: number, z: number): Vector3
	local c: Vector3 = Config.Hub.Center
	return Vector3.new(c.X + x, c.Y + 1, c.Z + z)
end

function HubPaths.Enabled(entry: { Zone: string, Text: string, Feature: string }): boolean
	if not Config.Lobby.Zones[entry.Zone] then
		return false
	end
	if entry.Feature == "" then
		return true
	end
	local features = Config.Features :: any
	return features[entry.Feature] == true
end

-- The clock tower's footprint half-width (with its steps) and centre, flat.
local function tower(): (Vector3, number)
	local cfg = Config.Hub.ClockTower
	return ground(cfg.Offset.X, cfg.Offset.Z), cfg.Width / 2 + 3
end

-- Distance from p to the segment a-b, flat.
local function flatDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local lengthSq = ab:Dot(ab)
	local t = if lengthSq > 0 then math.clamp(ap:Dot(ab) / lengthSq, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

function HubPaths.Network(): { Path }
	local hubCfg = Config.Hub
	local plaza = hubCfg.Plaza
	local width = plaza.PathWidth
	local ringOuter = plaza.Promenade.Radius + plaza.Promenade.Width / 2
	local ringMid = plaza.Promenade.Radius
	local stopShort = hubCfg.Polish.Paths.StopShort
	local paths: { Path } = {}

	-- From the spawn.
	local spawn: Vector3 = hubCfg.Spawn.Offset
	local spawnRadius = hubCfg.Spawn.Diameter / 2
	local ready = Config.Lobby.Zones.ReadyArea
	if ready and Config.Features.ReadyPad then
		local zone = HubLayout.Zone("ReadyArea")
		local arch = zone.CFrame * CFrame.new(0, 0, zone.Size.Z / 2 + 0.5)
		local from = ground(spawn.X, spawn.Z)
		local dir = Vector3.new(arch.X - from.X, 0, arch.Z - from.Z)
		if dir.Magnitude > spawnRadius + 1 then
			table.insert(paths, {
				Name = "SpawnToReady",
				Points = {
					from + dir.Unit * (spawnRadius - 1),
					Vector3.new(arch.X, from.Y, arch.Z),
				},
				Width = width + 1,
				Zone = "ReadyArea",
			})
		end
	end
	-- Two curving paths from the spawn round the Ready circle to the promenade.
	for _, side in { -1, 1 } do
		local a = math.rad(90 - side * 46)
		local join = ground(math.cos(a) * ringMid, math.sin(a) * ringMid)
		local start = ground(spawn.X + side * spawnRadius * 0.6, spawn.Z - spawnRadius * 0.6)
		local bend = ground(spawn.X + side * 17, (spawn.Z + join.Z) / 2 + 6)
		table.insert(paths, {
			Name = if side < 0 then "SpawnWest" else "SpawnEast",
			Points = { start, bend, join },
			Width = width,
		})
	end

	-- From the promenade out to each lobby area.
	local towerCentre, towerHalf = tower()
	for _, entry in hubCfg.Signposts.Zones do
		if entry.Zone == "ReadyArea" or not HubPaths.Enabled(entry) then
			continue
		end
		local zone = HubLayout.Zone(entry.Zone)
		local centre = zone.CFrame.Position
		local flat = Vector3.new(centre.X - hubCfg.Center.X, 0, centre.Z - hubCfg.Center.Z)
		if flat.Magnitude < 1 then
			continue
		end
		local dir = flat.Unit
		-- The zone faces the middle, so its front edge is half its depth before its centre.
		local frontDistance = flat.Magnitude - zone.Size.Z / 2 - stopShort
		local from = ground(0, 0) + dir * (ringOuter - 1)
		local to = ground(0, 0) + dir * frontDistance
		if frontDistance <= ringOuter then
			continue -- the zone touches the promenade
		end
		if flatDistance(towerCentre, from, to) < towerHalf + width / 2 then
			-- Round both sides of the clock tower.
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for _, s in { -1, 1 } do
				local offset = side * s * (towerHalf + width / 2 + 1)
				table.insert(paths, {
					Name = entry.Zone .. (if s < 0 then "Left" else "Right"),
					Points = {
						from,
						towerCentre - dir * (towerHalf + 2) + offset,
						towerCentre + offset,
						to + offset * 0.6,
					},
					Width = width,
					Zone = entry.Zone,
				})
			end
		else
			table.insert(
				paths,
				{ Name = entry.Zone, Points = { from, to }, Width = width, Zone = entry.Zone }
			)
		end
	end
	-- Up to the foot of the clock tower.
	local towerFlat = towerCentre - ground(0, 0)
	if towerFlat.Magnitude > ringOuter + towerHalf then
		local towerDir = towerFlat.Unit
		table.insert(paths, {
			Name = "ClockTower",
			Points = {
				ground(0, 0) + towerDir * (ringOuter - 1),
				towerCentre - towerDir * (towerHalf + 0.5),
			},
			Width = width,
		})
	end
	return paths
end

function HubPaths.OnPath(position: Vector3, margin: number?): boolean
	local m = margin or 0
	local plaza = Config.Hub.Plaza
	local flat = Vector3.new(position.X - Config.Hub.Center.X, 0, position.Z - Config.Hub.Center.Z)
	if math.abs(flat.Magnitude - plaza.Promenade.Radius) <= plaza.Promenade.Width / 2 + m then
		return true
	end
	for _, path in HubPaths.Network() do
		for i = 1, #path.Points - 1 do
			if flatDistance(position, path.Points[i], path.Points[i + 1]) <= path.Width / 2 + m then
				return true
			end
		end
	end
	return false
end

return HubPaths
