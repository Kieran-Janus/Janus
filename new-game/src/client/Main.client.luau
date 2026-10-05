--!strict
-- Client entry point: builds the UI and input handlers.
local Players = game:GetService("Players")

local AdminUI = require(script.Parent.AdminUI)
local Controls = require(script.Parent.Controls)
local GhostFlight = require(script.Parent.GhostFlight)
local GhostUI = require(script.Parent.GhostUI)
local HubAmbience = require(script.Parent.HubAmbience)
local Hud = require(script.Parent.Hud)
local KingHeardUI = require(script.Parent.KingHeardUI)
local Layout = require(script.Parent.Layout)
local MinionFeedback = require(script.Parent.MinionFeedback)
local NpcDialogUI = require(script.Parent.NpcDialogUI)
local ResultsUI = require(script.Parent.ResultsUI)
local RewardsUI = require(script.Parent.RewardsUI)
local RoundJuiceUI = require(script.Parent.RoundJuiceUI)
local SettingsUI = require(script.Parent.SettingsUI)
local ShopUI = require(script.Parent.ShopUI)
local Sounds = require(script.Parent.Sounds)
local TutorialUI = require(script.Parent.TutorialUI)
local VoteUI = require(script.Parent.VoteUI)
local VoteBoardUI = require(script.Parent.VoteBoardUI)
local VipUI = require(script.Parent.VipUI)
local VoiceMeter = require(script.Parent.VoiceMeter)
local ZoneLighting = require(script.Parent.ZoneLighting)

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
-- Sibling: a panel's ZIndex lifts it above other panels while its own children still draw
-- on top of it (with Global, the raised Shop panel covered its own buttons and text).
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Layout.Mount(gui) -- first: side-button column and screen scale the others use
Sounds.Mount() -- early, so every button made below gets click/hover sounds
Hud.Mount(gui)
VoteUI.Mount(gui)
ResultsUI.Mount(gui)
GhostUI.Mount(gui)
NpcDialogUI.Mount(gui)
MinionFeedback.Mount(gui)
ShopUI.Mount(gui)
VipUI.Mount(gui)
RewardsUI.Mount(gui)
SettingsUI.Mount(gui)
AdminUI.Mount(gui)
KingHeardUI.Mount(gui)
RoundJuiceUI.Mount(gui)
TutorialUI.Mount(gui)
GhostFlight.Mount()
Controls.Mount()
VoiceMeter.Mount()
HubAmbience.Mount()
VoteBoardUI.Mount()
ZoneLighting.Mount()
