--!strict
-- Client entry point: builds the UI and input handlers.
local Players = game:GetService("Players")

local Controls = require(script.Parent.Controls)
local GhostFlight = require(script.Parent.GhostFlight)
local GhostUI = require(script.Parent.GhostUI)
local HubAmbience = require(script.Parent.HubAmbience)
local Hud = require(script.Parent.Hud)
local NpcDialogUI = require(script.Parent.NpcDialogUI)
local ResultsUI = require(script.Parent.ResultsUI)
local VoteUI = require(script.Parent.VoteUI)
local VoteBoardUI = require(script.Parent.VoteBoardUI)
local VoiceMeter = require(script.Parent.VoiceMeter)

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Hud.Mount(gui)
VoteUI.Mount(gui)
ResultsUI.Mount(gui)
GhostUI.Mount(gui)
NpcDialogUI.Mount(gui)
GhostFlight.Mount()
Controls.Mount()
VoiceMeter.Mount()
HubAmbience.Mount()
VoteBoardUI.Mount()
