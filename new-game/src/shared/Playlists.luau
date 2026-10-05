--!strict
--[[
	Playlist helpers (a playlist = one game mode on one map, Config.Modes.Playlists).
	Shared by the server (vote, round loop) and the client (menus can show modes).

	Playlists.Get(id) -> Playlist?               the playlist with this Id
	Playlists.Mode(playlist) -> ModeDef?          its Config.Modes.List entry
	Playlists.MinPlayers(playlist) -> number      ready players it needs (mode's or the playlist's, the bigger)
	Playlists.UsesDifficulty(playlist) -> boolean true when the vote should ask Easy or Hard
	Playlists.IsEnabled(playlist) -> boolean      its mode exists and is switched on, its map exists
	Playlists.Available(readyCount) -> { Playlist }   enabled ones that fit this many players
	Playlists.Enabled() -> { Playlist }           every enabled one, whatever the player count
	Playlists.Offer(readyCount, count, rng?) -> { Playlist }
	                                              `count` random picks for the vote; never empty
	                                              (falls back to Config.Modes.FallbackMode)
	Playlists.Fallback() -> Playlist              the playlist used when nothing else fits
	Playlists.ForMap(mapId, modeId?) -> Playlist  a playlist on this map (made up if none is listed)
	Playlists.ModeName(modeId) -> string          what players see for a mode id
]]

local Config = require(script.Parent.Config)

export type Playlist = { Id: string, Mode: string, Map: string, Name: string, MinPlayers: number? }
export type ModeDef = {
	Name: string,
	Feature: string,
	Description: string,
	MinPlayers: number,
	UsesDifficulty: boolean,
}

local Playlists = {}

local function mapDef(id: string): any
	for _, def in Config.Maps.List do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function Playlists.Get(id: string): Playlist?
	for _, playlist in Config.Modes.Playlists do
		if playlist.Id == id then
			return playlist
		end
	end
	return nil
end

function Playlists.Mode(playlist: Playlist): ModeDef?
	return Config.Modes.List[playlist.Mode]
end

function Playlists.ModeName(modeId: string): string
	local mode = Config.Modes.List[modeId]
	return if mode then mode.Name else modeId
end

function Playlists.MinPlayers(playlist: Playlist): number
	local mode = Playlists.Mode(playlist)
	return math.max(1, mode and mode.MinPlayers or 1, playlist.MinPlayers or 1)
end

function Playlists.UsesDifficulty(playlist: Playlist): boolean
	local mode = Playlists.Mode(playlist)
	return mode ~= nil and mode.UsesDifficulty == true
end

function Playlists.IsEnabled(playlist: Playlist): boolean
	local mode = Playlists.Mode(playlist)
	if not mode then
		return false
	end
	local features = Config.Features :: { [string]: boolean }
	return features[mode.Feature] == true and mapDef(playlist.Map) ~= nil
end

-- In Config.Modes.Order, then in the order of Config.Modes.Playlists, so lists are stable
-- and easy to read.
local function sorted(list: { Playlist }): { Playlist }
	local order = Config.Modes.Order
	local function rank(playlist: Playlist): number
		return table.find(order, playlist.Mode) or #order + 1
	end
	local function position(playlist: Playlist): number
		return table.find(Config.Modes.Playlists, playlist) or math.huge
	end
	table.sort(list, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return position(a) < position(b)
	end)
	return list
end

function Playlists.Enabled(): { Playlist }
	local list = {}
	for _, playlist in Config.Modes.Playlists do
		if Playlists.IsEnabled(playlist) then
			table.insert(list, playlist)
		end
	end
	return sorted(list)
end

function Playlists.Available(readyCount: number): { Playlist }
	local list = {}
	for _, playlist in Playlists.Enabled() do
		if Playlists.MinPlayers(playlist) <= readyCount then
			table.insert(list, playlist)
		end
	end
	return list
end

-- A listed playlist on `mapId` (for `modeId` if given), or a made-up one so that mode can
-- always be played there (modeId defaults to Config.Modes.FallbackMode).
function Playlists.ForMap(mapId: string, modeId: string?): Playlist
	for _, playlist in Config.Modes.Playlists do
		if playlist.Map == mapId and (modeId == nil or playlist.Mode == modeId) then
			return playlist
		end
	end
	local def = mapDef(mapId)
	local mode = modeId or Config.Modes.FallbackMode
	return {
		Id = mode .. mapId,
		Mode = mode,
		Map = mapId,
		Name = if def then def.Name else mapId,
	}
end

-- The fallback mode's first playlist (switched on if possible), so a round can always start.
function Playlists.Fallback(): Playlist
	local modeId = Config.Modes.FallbackMode
	local first: Playlist? = nil
	for _, playlist in Config.Modes.Playlists do
		if playlist.Mode == modeId and mapDef(playlist.Map) then
			if Playlists.IsEnabled(playlist) then
				return playlist
			end
			first = first or playlist
		end
	end
	if first then
		return first
	end
	-- No playlist for the fallback mode at all: play it on the first map.
	local def = Config.Maps.List[1]
	return Playlists.ForMap(def.Id, modeId)
end

--[[
	The vote's choices: up to `count` different playlists picked at random from the ones that
	fit `readyCount` players, in Config.Modes.Order. Never empty. `rng` is optional (a Random).
]]
function Playlists.Offer(readyCount: number, count: number, rng: Random?): { Playlist }
	local pool = Playlists.Available(readyCount)
	if #pool == 0 then
		return { Playlists.Fallback() }
	end
	local picked = {}
	for _ = 1, math.min(math.max(count, 1), #pool) do
		local index = if rng then rng:NextInteger(1, #pool) else math.random(1, #pool)
		table.insert(picked, table.remove(pool, index) :: Playlist)
	end
	return sorted(picked)
end

return Playlists
