--!strict
--[[
	Studio tools for looking at things, in the F8 admin panel (AdminService):

	  "Visit map: <name>"  loads that round map between rounds and puts you on it, so you can
	                       walk round it with its real lighting. Nothing hunts you (no King,
	                       pumpkins or round). "Leave the map" brings you back to the lobby.
	                       Starting a round ends every visit first (the round loads its own map).
	  "Name finder on/off" while on, clicking (or tapping) anything shows what it is called and
	                       where it is (src/client/NameFinder.luau), so you can copy that name and
	                       ask Claude Code to change exactly that thing.

	Studio only (never in live servers). Settings: Config.Admin.Tools.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local MapService = require(script.Parent.MapService)

local MapVisitService = {}

local visiting: { [Player]: boolean } = {}
local visitMap: Model? = nil
local roundActive: () -> boolean = function()
	return false
end

-- Back to the lobby spawn (a player who isn't in the game any more is skipped).
local function toLobby(player: Player)
	visiting[player] = nil
	player:SetAttribute(Config.Admin.Tools.VisitAttribute, nil)
	local character = player.Character
	if character and player.Parent == Players then
		character:PivotTo(MapService.LobbyCFrame())
	end
end

local function endVisits()
	for player in visiting do
		toLobby(player)
	end
end

-- GameService passes in how to tell whether a round is on (it owns that state).
function MapVisitService.SetRoundCheck(fn: () -> boolean)
	roundActive = fn
end

-- Called by GameService just before a round loads its map: visitors go back to the lobby.
function MapVisitService.EndAll()
	endVisits()
	visitMap = nil
end

-- Where players really start on this map: a mode's own spawn (Hide & Seek hiders, ScareMaze
-- Survivors) when it has them, else nil (then the map's Spawns folder).
local function startSpot(model: Model): BasePart?
	for _, tag in { Tags.HiderSpawn, Tags.SurvivorSpawn } do
		for _, part in CollectionService:GetTagged(tag) do
			if part:IsA("BasePart") and part:IsDescendantOf(model) then
				return part
			end
		end
	end
	return nil
end

local function visit(player: Player, def: any): string
	if roundActive() then
		return "A round is being played: wait for it to end (or watch it with Menu > Spectate)."
	end
	local current = MapService.Current()
	local map
	if current and current.Model == visitMap and current.Id == def.Id then
		map = current -- already loaded by another visit
	else
		map = MapService.Load(def.Id)
		visitMap = map.Model
		map.Model.Destroying:Once(function()
			if visitMap == map.Model then
				visitMap = nil
			end
			endVisits()
		end)
	end
	local character = player.Character
	local spawnPart = startSpot(map.Model) or map.Spawns[1]
	if not (character and spawnPart) then
		return "Your character isn't loaded yet: try again in a moment."
	end
	character:PivotTo(spawnPart.CFrame + Vector3.new(0, Config.Maps.SpawnHeight, 0))
	visiting[player] = true
	player:SetAttribute(Config.Admin.Tools.VisitAttribute, def.Id)
	return ('Visiting %s. Walk around (Shift+P = free camera); "Leave the map" takes you back.'):format(
		def.Name
	)
end

function MapVisitService.Start()
	if not RunService:IsStudio() then
		return -- tools for building in Studio only
	end
	for _, def in Config.Maps.List do
		AdminService.Register(
			"VisitMap" .. def.Id,
			"Visit map: " .. def.Name,
			function(player, _data)
				return visit(player, def)
			end
		)
	end
	AdminService.Register("LeaveMap", "Leave the map", function(player, _data)
		local wasVisiting = visiting[player] == true
		toLobby(player)
		-- Nobody left looking at it: take the map away again (not a round's map).
		local current = MapService.Current()
		if
			next(visiting) == nil
			and current
			and current.Model == visitMap
			and not roundActive()
		then
			visitMap = nil
			MapService.Unload()
		end
		return if wasVisiting then "Back in the lobby." else "You weren't visiting a map."
	end)
	AdminService.Register("NameFinder", "Name finder on/off", function(player, _data)
		local attribute = Config.Admin.Tools.NameFinderAttribute
		local on = not player:GetAttribute(attribute)
		player:SetAttribute(attribute, if on then true else nil)
		return if on
			then "Name finder ON: click anything to see its name (click the name box, then Ctrl+A and Ctrl+C to copy it)."
			else "Name finder off."
	end)
	Players.PlayerRemoving:Connect(function(player)
		visiting[player] = nil
	end)
end

return MapVisitService
