--!strict
--[[
	The Tormented Tower on screen (Config.TowerParkour; on/off: Config.Features.TowerParkour):
	the same timer, messages, finish banner and Menu panel as the lobby parkour (ParkourUI),
	with the tower's words, attributes (TowerRun, TowerBest, TowerConquered...) and remotes
	(TowerEvent, TowerRequest). The finish banner shows the skin you won the first time.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourUI = require(script.Parent.ParkourUI)
local Theme = require(script.Parent.Theme)

local TowerUI = {}

function TowerUI.Mount(gui: ScreenGui)
	if not Config.Features.TowerParkour then
		return
	end
	local player = Players.LocalPlayer
	local cfg = Config.TowerParkour
	local text = cfg.Text
	local gold = Config.Parkour.Screen.Colors.Finish
	ParkourUI.MountCourse(gui, {
		Feature = "TowerParkour",
		Prefix = "Tower",
		CountAttribute = "TowerCheckpoints",
		Event = "TowerEvent",
		Request = "TowerRequest",
		Text = text,
		TileId = "TowerParkour",
		TileOrder = 11,
		Watch = { "TowerBest", "TowerRuns", "TowerConquered" },
		FinishLine = function(info: { [string]: any }): (string, Color3)
			if type(info.Skin) == "string" then
				return text.SkinWon:format(info.Skin), gold
			end
			return text.CoinsLater, Theme.Muted
		end,
		RewardLine = function(): (string, Color3)
			if player:GetAttribute("TowerConquered") == true then
				return text.RewardWait, Theme.Muted
			end
			return text.RewardReady, gold
		end,
	})
end

return TowerUI
