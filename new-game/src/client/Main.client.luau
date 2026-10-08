--!strict
--[[
	Client entry point: builds the UI and input handlers.
	Add a new screen or controller = add its module name to ORDER below (a module next to
	this script with a Mount(gui) function).
	Layout, PanelManager and Sounds mount first and in order. Every other module mounts on
	its own: if one breaks or waits for something, the Output window shows a warning with
	its name and the rest of the UI still appears. A feature switched off in Config.Features
	shows nothing.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Layout = require(script.Parent.Layout)
local PanelManager = require(script.Parent.PanelManager)
local Sounds = require(script.Parent.Sounds)

-- Mounted in this order, each in its own thread after Layout, PanelManager and Sounds.
local ORDER = {
	"MenuUI", -- the top-left Menu: the panels below put their buttons in it as tiles
	"MenuTiles", -- the Menu's own tiles (Skins, Crates, Vote, Spectate, VIP...)
	"Hud",
	"VoteUI",
	"ResultsUI",
	"GhostUI",
	"NpcDialogUI",
	"Dances", -- Photo Spot dances on every character
	"SkinAnim", -- skin pieces that move or change colour (Style.Animate) on every character
	"SkinWalk", -- walk styles (Style.Motion: Zombie, Ghost...) on every character
	"MinionFeedback",
	"ShopUI",
	"VipUI",
	"RewardsUI",
	"SettingsUI",
	"AdminUI",
	"KingHeardUI",
	"RoundJuiceUI",
	"TutorialUI", -- does nothing while Config.Features.Tutorial is off
	"Spectate",
	"CrateUI",
	"ParkourUI",
	"TowerUI", -- the Tormented Tower (the parkour screen with its own words)
	"CandyRushUI",
	"WebScourUI",
	"EasterEggUI",
	"HideSeekUI",
	"ScareMazeUI",
	"GhostFlight",
	"Controls",
	"VoiceMeter",
	"HubAmbience",
	"LobbyLife", -- the shopkeeper waves, the Ready pad pulses, floor signs shimmer, bats fly
	"MapLife", -- round maps: pumpkins bob and pop, fireflies drift, Hide & Seek decoys wobble
	"CrateIdle", -- the crates on the lobby stand bob, peek and wake up when you walk over
	"ReadySign", -- the "READY x / y" sign over the Ready pad
	"VoteBoardUI",
	"ZoneLighting",
	"AnnounceUI", -- server-wide banners ("X conquered the Tormented Tower!")
}

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
-- Sibling: a panel's ZIndex lifts it above other panels while its own children still draw
-- on top of it (with Global, the raised Shop panel covered its own buttons and text).
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Layout.Mount(gui) -- first: the screen scale and the Menu tiles the others use
PanelManager.Mount(gui) -- one centred panel at a time (Menu, Shop, Settings, Codes...)
Sounds.Mount() -- early, so every button made below gets click/hover sounds

-- The first moments of a game report a stand-in screen size (the camera says 1x1, the gui a
-- PC-sized box), and screens choose their phone or PC layout when they mount: wait for the
-- real size first (Config.UI.ScreenWaitSeconds at most).
local camera = workspace.CurrentCamera
if camera and camera.ViewportSize.X <= 1 then
	local waited = 0
	while camera.ViewportSize.X <= 1 and waited < Config.UI.ScreenWaitSeconds do
		waited += task.wait()
	end
	task.wait() -- one more frame, so the gui has taken the new size too
end

local function report(name: string, err: unknown)
	warn(
		("[Main] %s failed to mount (the rest of the UI keeps working): %s"):format(
			name,
			tostring(err)
		)
	)
end

for _, name in ORDER do
	-- task.spawn runs the module straight away, so the order above is kept; a module that
	-- waits (for a remote, a part, ...) no longer holds up the ones after it.
	task.spawn(function()
		local moduleScript = script.Parent:FindFirstChild(name)
		if not (moduleScript and moduleScript:IsA("ModuleScript")) then
			report(name, "the module is missing")
			return
		end
		local ok, err = xpcall(function()
			local module = (require :: any)(moduleScript)
			module.Mount(gui) -- modules without a gui parameter just ignore it
		end, debug.traceback)
		if not ok then
			report(name, err)
		end
	end)
end
