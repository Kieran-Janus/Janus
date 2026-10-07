--!strict
--[[
	VIP extras on the client (the server decides who is VIP: the player's "VIP" attribute).
	  King tracker - T (or the on-screen button) asks the server TrackKing(); the answer is
	                 shown as an arrow pointing to the nearest King for a few seconds.
	  Chat tag     - "[VIP]" in front of VIP players' chat messages.
	The tracker pops when a new reading comes in and wiggles while it's still recharging
	(src/client/ShopJuice.luau, Config.Shop.Juice).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local ShopJuice = require(script.Parent.ShopJuice)
local Theme = require(script.Parent.Theme)

local VipUI = {}

function VipUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local cfg = Config.Monetization
	local trackKing = Remotes.Function("TrackKing")

	-- Tracker arrow ---------------------------------------------------------------------------
	local holder = Theme.panel(gui)
	holder.Name = "KingTracker"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.24)
	holder.Size = UDim2.fromOffset(200, 96)
	Layout.Fit(holder)
	holder.Visible = false
	local arrow = Theme.label("^", 60, holder)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextColor3 = Theme.Selected
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0, 38)
	arrow.Size = UDim2.fromOffset(60, 60)
	local info = Theme.label("", 14, holder)
	info.Position = UDim2.new(0, 0, 1, -24)
	info.Size = UDim2.new(1, 0, 0, 20)

	local direction: Vector3? = nil
	local showUntil = 0
	RunService.RenderStepped:Connect(function()
		if not direction or os.clock() > showUntil then
			holder.Visible = false
			return
		end
		local camera = workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude < 0.01 then
			return
		end
		forward = forward.Unit
		local right = Vector3.new(-forward.Z, 0, forward.X)
		local angle = math.atan2(direction:Dot(right), direction:Dot(forward))
		arrow.Rotation = math.deg(angle)
		holder.Visible = true
	end)

	local function canTrack(): boolean
		return player:GetAttribute("VIP") == true
			and player:GetAttribute("InRound") == true
			and not player:GetAttribute("Out")
			and ReplicatedStorage:GetAttribute("State") == "Playing"
	end

	local asking = false
	local function track()
		if asking or not canTrack() then
			return
		end
		local wait = (player:GetAttribute("TrackerReadyAt") or 0) - workspace:GetServerTimeNow()
		if wait > 0 then
			info.Text = ("Tracker ready in %ds"):format(math.ceil(wait))
			direction = direction or Vector3.new(0, 0, -1)
			showUntil = os.clock() + 1.5
			ShopJuice.Shake(holder)
			return
		end
		asking = true
		task.spawn(function()
			local ok, dir, distance = pcall(function()
				return trackKing:InvokeServer()
			end)
			asking = false
			if ok and typeof(dir) == "Vector3" and typeof(distance) == "number" then
				direction = if dir.Magnitude > 0 then dir else Vector3.new(0, 0, -1)
				info.Text = ("Pumpkin King: %d studs"):format(math.floor(distance))
				showUntil = os.clock() + cfg.Tracker.ShowSeconds
				ShopJuice.Pop(holder, Config.Shop.Juice.PopScale, Config.Shop.Juice.PopTime)
			end
		end)
	end

	-- The action (and its touch button) only exists while it can be used.
	local bound = false
	local function updateBinding()
		local should = canTrack()
		if should and not bound then
			ContextActionService:BindAction("TrackKing", function(_, state)
				if state == Enum.UserInputState.Begin then
					track()
				end
				return Enum.ContextActionResult.Sink
			end, true, cfg.Tracker.Key)
			ContextActionService:SetTitle("TrackKing", "Track")
			bound = true
		elseif not should and bound then
			ContextActionService:UnbindAction("TrackKing")
			bound = false
		end
	end
	for _, name in { "VIP", "InRound", "Out" } do
		player:GetAttributeChangedSignal(name):Connect(updateBinding)
	end
	ReplicatedStorage:GetAttributeChangedSignal("State"):Connect(updateBinding)
	updateBinding()

	-- Chat tag ----------------------------------------------------------------------------------
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if not speaker or not speaker:GetAttribute("VIP") then
			return nil
		end
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = ('<font color="#%s">%s</font> %s'):format(
			cfg.ChatTag.Color:ToHex(),
			cfg.ChatTag.Text,
			message.PrefixText
		)
		return props
	end
end

return VipUI
