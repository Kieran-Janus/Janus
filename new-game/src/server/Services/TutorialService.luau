--!strict
--[[
	First-round tutorial (Config.Tutorial). New players (RoundsPlayed = 0 and not
	TutorialDone in their save) get the player attribute "Tutorial" = true; the client
	(src/client/TutorialUI.luau) shows Boo Guide's tips while it is set.
	Client -> server: FinishTutorial() when the player taps Skip or sees the last tip.
	It saves TutorialDone so it never shows again.
	Off in v2 (Config.Features.Tutorial = false): the remote is still created so nothing
	waits for it, but no player is ever given the tutorial.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local function check(player: Player)
	local data = DataService.Get(player)
	if data and (data.RoundsPlayed or 0) == 0 and not data.TutorialDone then
		player:SetAttribute("Tutorial", true)
	else
		player:SetAttribute("Tutorial", nil)
	end
end

local function onFinish(player: Player)
	local data = DataService.Get(player)
	if not data or data.TutorialDone then
		player:SetAttribute("Tutorial", nil)
		return
	end
	data.TutorialDone = true
	player:SetAttribute("Tutorial", nil)
end

function TutorialService.Start()
	-- Created even when the tutorial is off, so a client asking for it never waits forever.
	local finishTutorial = Remotes.Event("FinishTutorial")
	if not Config.Features.Tutorial then
		return
	end
	finishTutorial.OnServerEvent:Connect(onFinish)
	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal("DataReady"):Connect(function()
			check(player)
		end)
		if player:GetAttribute("DataReady") then
			check(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return TutorialService
