--!strict
--[[
	Sprinting. The client only asks to sprint (SetSprint(boolean)); the server sets the
	speed, and reports noise while a sprinting player is actually moving.
	Ghosts move at Ghost.FlySpeed, can't sprint and don't make noise.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NoiseService = require(script.Parent.NoiseService)

local SprintService = {}

local sprinting: { [Player]: boolean } = {}
local lastToggle: { [Player]: number } = {}

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
	elseif sprinting[player] then
		humanoid.WalkSpeed = Config.Player.SprintSpeed
	else
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
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
