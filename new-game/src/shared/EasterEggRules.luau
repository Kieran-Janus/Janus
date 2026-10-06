--!strict
--[[
	Easter egg rules (Config.EasterEggs), shared by the server, the client and the tests.
	Plain functions: no parts, no players, no waiting.

	EasterEggRules.JoinIds(ids) -> string / ParseIds(text) -> { string }
	        egg ids <-> the text kept in the attributes below ("ShopPumpkin,PatchGold")
	EasterEggRules.Count(found, active) -> (number, number)
	        how many of the eggs in the game (`active` ids, or the whole Config list when the
	        server hasn't said yet) the player has found (`found` = their saved set)
	EasterEggRules.Coins(value, max) -> number
	        an egg's Coins attribute made safe: a whole number from 0 to max
	EasterEggRules.CheckCollect(check, cfg) -> string?
	        nil when a grab counts, else why not: "Found", "InRound", "TooFast" or "TooFar"
	EasterEggRules.Def(id) -> Config egg line or nil

	Attributes the server keeps up to date:
	  Player            EasterEggsFound   the ids that player has found
	  ReplicatedStorage EasterEggsActive  the ids of the eggs in the lobby right now
]]

local Config = require(script.Parent.Config)

local EasterEggRules = {}

EasterEggRules.FoundAttribute = "EasterEggsFound"
EasterEggRules.ActiveAttribute = "EasterEggsActive"

export type CollectCheck = {
	AlreadyFound: boolean,
	InRound: boolean,
	SinceLastTry: number, -- seconds since this player's previous grab (math.huge = never)
	Distance: number, -- studs from the player to the egg
}

export type CollectConfig = { ReachDistance: number, CooldownSeconds: number }

function EasterEggRules.JoinIds(ids: { string }): string
	return table.concat(ids, ",")
end

function EasterEggRules.ParseIds(text: unknown): { string }
	local ids = {}
	if type(text) == "string" then
		for id in text:gmatch("[^,]+") do
			table.insert(ids, id)
		end
	end
	return ids
end

function EasterEggRules.Count(found: { [string]: boolean }, active: { string }?): (number, number)
	local ids: { string } = {}
	if active then
		for _, id in active do
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		for _, egg in Config.EasterEggs.List do
			table.insert(ids, egg.Id)
		end
	end
	local count = 0
	for _, id in ids do
		if found[id] then
			count += 1
		end
	end
	return count, #ids
end

function EasterEggRules.Coins(value: unknown, max: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, math.max(max, 0))
end

function EasterEggRules.CheckCollect(check: CollectCheck, cfg: CollectConfig): string?
	if check.AlreadyFound then
		return "Found"
	end
	if check.InRound then
		return "InRound"
	end
	if check.SinceLastTry < cfg.CooldownSeconds then
		return "TooFast"
	end
	if check.Distance ~= check.Distance or check.Distance > cfg.ReachDistance then
		return "TooFar"
	end
	return nil
end

function EasterEggRules.Def(id: string): any
	for _, egg in Config.EasterEggs.List do
		if egg.Id == id then
			return egg
		end
	end
	return nil
end

return EasterEggRules
