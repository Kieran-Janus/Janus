--!strict
-- Client entry point: builds the HUD, the vote panel and the results screen.
local Players = game:GetService("Players")

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
