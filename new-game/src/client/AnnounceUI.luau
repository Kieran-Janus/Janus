--!strict
--[[
	Server-wide announcement banners (looks: Config.Announce; sent by the server's
	AnnounceService over the Announce remote): "<name> conquered the Tormented Tower!" and
	friends. One banner at a time at the top of the screen, below the Hud; more wait in a queue.

	AnnounceUI.Show(text, style)   shows one now (or after the ones waiting)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)

local AnnounceUI = {}

type Entry = { Text: string, Style: string }

local queue: { Entry } = {}
local showing = false
local show: ((entry: Entry) -> ())? = nil

local function nextOne()
	local entry = table.remove(queue, 1)
	local fn = show
	if entry and fn then
		showing = true
		fn(entry)
	else
		showing = false
	end
end

function AnnounceUI.Show(text: string, style: string)
	table.insert(queue, { Text = text, Style = style })
	while #queue > Config.Announce.MaxQueue do
		table.remove(queue, 1)
	end
	if not showing then
		nextOne()
	end
end

function AnnounceUI.Mount(gui: ScreenGui)
	local banner = Theme.panel(gui)
	banner.Name = "Announcement"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.12)
	banner.Size = UDim2.fromOffset(560, 64)
	banner.Visible = false
	banner.ZIndex = 20
	Layout.Fit(banner)
	Layout.KeepBelowHud({ banner })
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = banner
	local label = Theme.label("", 30, banner)
	label.Name = "Text"
	label.Font = Enum.Font.GothamBlack
	label.Position = UDim2.fromOffset(12, 6)
	label.Size = UDim2.new(1, -24, 1, -12)
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = 21
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = Config.UI.MinTextSize
	limit.Parent = label

	local rainbow: RBXScriptConnection? = nil
	show = function(entry: Entry)
		local style = (Config.Announce.Styles :: any)[entry.Style] or Config.Announce.Styles.Big
		banner.Size = UDim2.fromOffset(style.Width, style.Height)
		banner.BackgroundColor3 = style.Background
		limit.MaxTextSize = style.TextSize
		label.Text = entry.Text
		label.TextColor3 = style.Color
		if rainbow then
			rainbow:Disconnect()
			rainbow = nil
		end
		if style.Rainbow then
			rainbow = RunService.RenderStepped:Connect(function()
				label.TextColor3 = Color3.fromHSV((os.clock() * 0.35) % 1, 0.75, 1)
			end)
		end
		banner.Visible = true
		pop.Scale = 0.5
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sounds.PlaySpec(style.Sound)
		task.delay(style.Seconds, function()
			banner.Visible = false
			if rainbow then
				rainbow:Disconnect()
				rainbow = nil
			end
			nextOne()
		end)
	end

	-- (The server's AnnounceService always makes the remote, see Main.server.luau.)
	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	Remotes.Event("Announce").OnClientEvent:Connect(function(message: unknown)
		if type(message) ~= "table" then
			return
		end
		local m = message :: any
		if type(m.Text) == "string" and #m.Text > 0 then
			AnnounceUI.Show(m.Text, if type(m.Style) == "string" then m.Style else "Big")
		end
	end)
end

return AnnounceUI
