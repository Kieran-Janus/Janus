--!strict
--[[
	The clip moment (Config.King.Heard): when the King turns towards a noise you made you get
	a big shaking "THE KING HEARD YOU!" banner and a red flash; players nearby get a smaller
	"The King heard <name>!". The server decides when (KingService, KingHeard event).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local KingHeardUI = {}

function KingHeardUI.Mount(gui: ScreenGui)
	local cfg = Config.King.Heard

	local flash = Instance.new("Frame")
	flash.Name = "KingHeardFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 20)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 5
	flash.Parent = gui

	local banner = Theme.label("", 64, gui)
	banner.Name = "KingHeard"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.32)
	banner.Size = UDim2.fromScale(0.9, 0.14)
	banner.Font = Enum.Font.Creepster
	banner.TextScaled = true
	banner.TextColor3 = Color3.fromRGB(255, 120, 30)
	banner.TextStrokeColor3 = Color3.new(0, 0, 0)
	banner.TextStrokeTransparency = 0
	banner.ZIndex = 6
	banner.Visible = false

	local token = 0
	Remotes.Event("KingHeard").OnClientEvent:Connect(function(isYou: boolean, name: string)
		token += 1
		local mine = token
		banner.Text = if isYou then cfg.Banner else cfg.NearbyText:format(name)
		banner.Size = if isYou then UDim2.fromScale(0.9, 0.14) else UDim2.fromScale(0.6, 0.07)
		banner.TextColor3 = if isYou
			then Color3.fromRGB(255, 120, 30)
			else Color3.fromRGB(255, 220, 120)
		banner.Rotation = 0
		banner.Visible = true
		if isYou then
			flash.BackgroundTransparency = 0.55
			TweenService:Create(
				flash,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
			-- A short shake.
			task.spawn(function()
				for i = 1, 10 do
					if mine ~= token then
						return
					end
					banner.Rotation = (if i % 2 == 0 then 1 else -1) * (10 - i) * 0.6
					task.wait(0.04)
				end
				banner.Rotation = 0
			end)
		end
		task.delay(cfg.BannerSeconds, function()
			if mine == token then
				banner.Visible = false
			end
		end)
	end)
end

return KingHeardUI
