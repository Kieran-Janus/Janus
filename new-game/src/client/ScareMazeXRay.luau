--!strict
--[[
	ScareMaze: Haunters see the running Survivors through the maze walls, faintly (a Highlight
	made only on the Haunter's own screen). Used by src/client/ScareMazeUI.luau, not mounted on
	its own. Settings: Config.ScareMaze.HaunterSeeSurvivors, MaxHighlights (Roblox draws at
	most 31 Highlights, so only the nearest Survivors get one), HighlightRefreshSeconds,
	Colors.HighlightFill / HighlightOutline.

	ScareMazeXRay.SetEnabled(on)   start / stop (stopping removes every outline)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.ScareMazeRules)

local ScareMazeXRay = {}

local NAME = "ScareMazeXRay"
local ATTR = Rules.Attributes

local enabled = false
local loop: thread? = nil
local made: { [Model]: Highlight } = {}

local function clear()
	for _, highlight in made do
		highlight:Destroy()
	end
	table.clear(made)
end

local function rootPosition(character: Model?): Vector3?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function refresh()
	local cfg = Config.ScareMaze
	local me = rootPosition(Players.LocalPlayer.Character)
	if not me then
		clear()
		return
	end
	type Target = { Character: Model, Distance: number }
	local targets: { Target } = {}
	for _, other in Players:GetPlayers() do
		if
			other ~= Players.LocalPlayer
			and other:GetAttribute(ATTR.Team) == "Survivors"
			and other:GetAttribute(ATTR.State) == "Running"
		then
			local character = other.Character
			local at = rootPosition(character)
			if character and at then
				table.insert(targets, { Character = character, Distance = (at - me).Magnitude })
			end
		end
	end
	table.sort(targets, function(a, b)
		return a.Distance < b.Distance
	end)
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(#targets, cfg.MaxHighlights) do
		local character = targets[i].Character
		keep[character] = true
		local highlight = made[character]
		if not highlight or highlight.Parent ~= character then
			local h = Instance.new("Highlight")
			h.Name = NAME
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillColor = cfg.Colors.HighlightFill
			h.OutlineColor = cfg.Colors.HighlightOutline
			h.FillTransparency = 0.8
			h.OutlineTransparency = 0.35
			h.Adornee = character
			h.Parent = character
			made[character] = h
		end
	end
	for character, highlight in made do
		if not keep[character] then
			highlight:Destroy()
			made[character] = nil
		end
	end
end

function ScareMazeXRay.SetEnabled(on: boolean)
	on = on and Config.ScareMaze.HaunterSeeSurvivors
	if on == enabled then
		return
	end
	enabled = on
	if not on then
		local running = loop
		loop = nil
		if running and coroutine.status(running) ~= "dead" and running ~= coroutine.running() then
			task.cancel(running)
		end
		clear()
		return
	end
	loop = task.spawn(function()
		while enabled do
			refresh()
			task.wait(Config.ScareMaze.HighlightRefreshSeconds)
		end
	end)
end

return ScareMazeXRay
