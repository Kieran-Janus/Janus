--!strict
--[[
	The "shout" emote: a loud noise the King can hear, so non-voice players have a way to
	be loud (or lure the King) too. The client only sends Shout() with no arguments;
	loudness, cooldown and position are all decided here.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NoiseService = require(script.Parent.NoiseService)

local ShoutService = {}

local lastShout: { [Player]: number } = {}

local function bubble(head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Shout"
	gui.Size = UDim2.fromOffset(120, 50)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Config.Pumpkins.Color
	label.TextStrokeTransparency = 0
	label.Text = Config.King.Noise.ShoutText
	label.Parent = gui
	gui.Parent = head
	Debris:AddItem(gui, Config.King.Noise.ShoutBubbleSeconds)
end

local function onShout(player: Player)
	if player:GetAttribute("Out") then
		return -- ghosts are silent to the King
	end
	local now = os.clock()
	if now - (lastShout[player] or -math.huge) < Config.King.Noise.ShoutCooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	lastShout[player] = now
	NoiseService.Report(root.Position, Config.King.Noise.Shout, player)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		bubble(head)
	end
end

function ShoutService.Start()
	Remotes.Event("Shout").OnServerEvent:Connect(onShout)
	Players.PlayerRemoving:Connect(function(player)
		lastShout[player] = nil
	end)
end

return ShoutService
