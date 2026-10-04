--!strict
-- Client entry point: builds the UI and input handlers.
local Players = game:GetService("Players")

local Controls = require(script.Parent.Controls)
local GhostFlight = require(script.Parent.GhostFlight)
local GhostUI = require(script.Parent.GhostUI)
local Hud = require(script.Parent.Hud)
local ResultsUI = require(script.Parent.ResultsUI)
local VoteUI = require(script.Parent.VoteUI)

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Hud.Mount(gui)
VoteUI.Mount(gui)
ResultsUI.Mount(gui)
GhostUI.Mount(gui)
GhostFlight.Mount()
Controls.Mount()
