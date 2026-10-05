--!strict
--[[
	Client side of RewardsService (docs/VIRAL.md):
	  Codes button  - opens a small box to type a code; the server decides.
	  Invite button - Roblox's invite-friends prompt (Config.Social.InviteButton).
	  Daily toast   - "Day 3 streak! +100 Coins" when the server pays the daily reward.
	  Favourite     - Roblox's "favourite this experience" prompt, once, when the server says.
]]
local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local RewardsUI = {}

local function toast(gui: ScreenGui, text: string, seconds: number)
	local frame = Theme.panel(gui)
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.14)
	frame.Size = UDim2.fromOffset(360, 54)
	Layout.Fit(frame)
	local label = Theme.label(text, 20, frame)
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Theme.Selected
	task.delay(seconds, function()
		frame:Destroy()
	end)
end

function RewardsUI.Mount(gui: ScreenGui)
	local player = Players.LocalPlayer
	local redeemCode = Remotes.Function("RedeemCode")

	-- Codes -------------------------------------------------------------------------------------
	local codesButton = Layout.SideButton("Codes", 3)
	codesButton.Name = "CodesButton"

	local box = Theme.panel(gui)
	box.Name = "Codes"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(340, 170)
	box.Visible = false
	Layout.Fit(box)
	local title = Theme.label("Enter a code", 22, box)
	title.Size = UDim2.new(1, 0, 0, 40)
	local input = Instance.new("TextBox")
	input.Position = UDim2.fromOffset(20, 48)
	input.Size = UDim2.new(1, -40, 0, 40)
	input.BackgroundColor3 = Theme.Button
	input.TextColor3 = Theme.Text
	input.PlaceholderText = "e.g. PUMPKIN"
	input.PlaceholderColor3 = Theme.Muted
	input.Font = Theme.Font
	input.TextSize = 18
	input.Text = ""
	input.ClearTextOnFocus = false
	input.Parent = box
	Theme.round(input, 8)
	local message = Theme.label("", 14, box)
	message.Position = UDim2.fromOffset(20, 92)
	message.Size = UDim2.new(1, -40, 0, 22)
	message.TextColor3 = Theme.Muted
	message.TextWrapped = true
	local redeem = Instance.new("TextButton")
	redeem.Position = UDim2.new(0, 20, 1, -50)
	redeem.Size = UDim2.new(0.5, -25, 0, 36)
	redeem.BackgroundColor3 = Theme.Selected
	redeem.TextColor3 = Theme.Text
	redeem.Font = Theme.Font
	redeem.TextSize = 16
	redeem.Text = "Redeem"
	redeem.Parent = box
	Theme.round(redeem, 8)
	local close = Instance.new("TextButton")
	close.Position = UDim2.new(0.5, 5, 1, -50)
	close.Size = UDim2.new(0.5, -25, 0, 36)
	close.BackgroundColor3 = Theme.Button
	close.TextColor3 = Theme.Text
	close.Font = Theme.Font
	close.TextSize = 16
	close.Text = "Close"
	close.Parent = box
	Theme.round(close, 8)

	local busy = false
	local function submit()
		if busy then
			return
		end
		busy = true
		message.Text = "Checking..."
		local ok, okResult, text = pcall(function()
			return redeemCode:InvokeServer(input.Text)
		end)
		if ok then
			message.Text = tostring(text)
			message.TextColor3 = if okResult then Theme.Selected else Theme.Muted
			if okResult then
				Sounds.Play("CodeRedeemed")
			end
			if okResult then
				input.Text = ""
			end
		else
			message.Text = "Something went wrong, try again."
		end
		busy = false
	end
	redeem.Activated:Connect(submit)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	codesButton.Activated:Connect(function()
		box.Visible = not box.Visible
		message.Text = ""
	end)
	close.Activated:Connect(function()
		box.Visible = false
	end)

	-- Invite friends ------------------------------------------------------------------------------
	if Config.Social.InviteButton then
		local invite = Layout.SideButton("Invite", 2)
		invite.Name = "InviteButton"
		invite.Activated:Connect(function()
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			else
				toast(gui, "Invites aren't available right now.", 3)
			end
		end)
	end

	-- Daily streak ------------------------------------------------------------------------------
	Remotes.Event("DailyReward").OnClientEvent:Connect(function(streak: number, coins: number)
		toast(gui, ("Day %d streak! +%d %s"):format(streak, coins, Config.Economy.CurrencyName), 5)
		Sounds.Play("DailyReward")
	end)

	-- Favourite prompt ------------------------------------------------------------------------------
	Remotes.Event("PromptFavorite").OnClientEvent:Connect(function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
end

return RewardsUI
