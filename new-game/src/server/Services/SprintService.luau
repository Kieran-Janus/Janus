--!strict
--[[
	Sprinting. The client only asks to sprint (SetSprint(boolean)); the server sets the
	speed, and reports noise while a sprinting player is actually moving.
	Ghosts move at Ghost.FlySpeed, can't sprint and don't make noise.
	Slow(player, multiplier, seconds) scales a living player's speed for a while (minion hits).
	VIP players (attribute "VIP") move Config.Monetization.VipSpeedMultiplier faster.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NoiseService = require(script.Parent.NoiseService)

local SprintService = {}

local sprinting: { [Player]: boolean } = {}
local lastToggle: { [Player]: number } = {}
local slows: { [Player]: { Multiplier: number, Until: number } } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Applies the speed a player should have right now. Call after anything that changes it.
function SprintService.Apply(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	if player:GetAttribute("Out") then
		humanoid.WalkSpeed = Config.Ghost.FlySpeed
		return
	end
	local speed = if sprinting[player] then Config.Player.SprintSpeed else Config.Player.WalkSpeed
	if player:GetAttribute("VIP") then
		speed *= Config.Monetization.VipSpeedMultiplier
	end
	local slow = slows[player]
	if slow and slow.Until > os.clock() then
		speed *= slow.Multiplier
	else
		slows[player] = nil
	end
	humanoid.WalkSpeed = speed
end

function SprintService.Slow(player: Player, multiplier: number, seconds: number)
	local slow = { Multiplier = multiplier, Until = os.clock() + seconds }
	slows[player] = slow
	SprintService.Apply(player)
	task.delay(seconds, function()
		if slows[player] == slow then
			slows[player] = nil
			SprintService.Apply(player)
		end
	end)
end

local function onSetSprint(player: Player, wants: unknown)
	if typeof(wants) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Config.Player.SprintToggleCooldown then
		return
	end
	lastToggle[player] = now
	sprinting[player] = if wants then true else nil
	SprintService.Apply(player)
end

function SprintService.Start()
	Remotes.Event("SetSprint").OnServerEvent:Connect(onSetSprint)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			sprinting[player] = nil
			slows[player] = nil
			task.defer(SprintService.Apply, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sprinting[player] = nil
		lastToggle[player] = nil
		slows[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.King.Noise.TickSeconds)
			for player in sprinting do
				local humanoid = humanoidOf(player)
				local root = humanoid and humanoid.RootPart
				if
					humanoid
					and root
					and humanoid.Health > 0
					and humanoid.MoveDirection.Magnitude > 0
					and not player:GetAttribute("Out")
				then
					NoiseService.Report(root.Position, Config.King.Noise.SprintPerTick, player)
				end
			end
		end
	end)
end

return SprintService
