--!strict
--[[
	Shows what a minion just did to you (MinionHit(kind, push) from MinionService) and applies
	the skeleton's knockback to your own character. The server already decided the hit and
	applied the real effects (slow, noise, stolen pumpkin); this is only feedback.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local MinionFeedback = {}

function MinionFeedback.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer

	local toast = Theme.panel(gui)
	toast.Name = "MinionToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.16)
	toast.Size = UDim2.fromOffset(440, 44)
	toast.Visible = false
	Layout.Fit(toast)
	local label = Theme.label("", 18, toast)
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.TextColor3 = Theme.Selected
	label.TextScaled = true
	local maxSize = Instance.new("UITextSizeConstraint")
	maxSize.MaxTextSize = 18
	maxSize.Parent = label

	local shownAt = 0
	Remotes.Event("MinionHit").OnClientEvent:Connect(function(kind: unknown, push: unknown)
		local cfg = typeof(kind) == "string" and (Config.Monsters :: any)[kind]
		if type(cfg) ~= "table" then
			return
		end
		label.Text = cfg.Message
		toast.Visible = true
		local stamp = os.clock()
		shownAt = stamp
		task.delay(Config.Monsters.FeedbackSeconds, function()
			if shownAt == stamp then
				toast.Visible = false
			end
		end)

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if typeof(push) == "Vector3" and push.Magnitude > 0 and root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = push + Vector3.new(0, push.Magnitude * 0.4, 0)
		end
	end)
end

return MinionFeedback
