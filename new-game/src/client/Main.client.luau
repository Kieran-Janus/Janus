--!strict
--[[
	Client entry point: builds the UI and input handlers.
	Add a new screen or controller = add its module name to ORDER below (a module next to
	this script with a Mount(gui) function).
	Layout and Sounds mount first and in order. Every other module mounts on its own: if one
	breaks or waits for something, the Output window shows a warning with its name and the
	rest of the UI still appears. A feature switched off in Config.Features shows nothing.
]]
local Players = game:GetService("Players")

local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)

-- Mounted in this order, each in its own thread after Layout and Sounds.
local ORDER = {
	"MenuUI", -- the top-left Menu that the panels below put their buttons in
	"Hud",
	"VoteUI",
	"ResultsUI",
	"GhostUI",
	"NpcDialogUI",
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
	"CandyRushUI",
	"WebScourUI",
	"EasterEggUI",
	"HideSeekUI",
	"ScareMazeUI",
	"GhostFlight",
	"Controls",
	"VoiceMeter",
	"HubAmbience",
	"VoteBoardUI",
	"ZoneLighting",
}

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
-- Sibling: a panel's ZIndex lifts it above other panels while its own children still draw
-- on top of it (with Global, the raised Shop panel covered its own buttons and text).
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Layout.Mount(gui) -- first: the screen scale and button column the others use
Sounds.Mount() -- early, so every button made below gets click/hover sounds

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
