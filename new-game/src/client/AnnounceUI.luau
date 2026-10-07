--!strict
--[[
	Server-wide announcement banners (looks: Config.Announce; sent by the server's
	AnnounceService over the Announce remote): "<name> conquered the Tormented Tower!", someone
	unboxing a CRAZY skin, and friends. They show at the top of the screen, below the Hud.
	Several at once stack under each other (Config.Announce.MaxShown; phones show one at a time
	and for at most PhoneMaxSeconds, so the middle of a small screen is never covered for long);
	more wait in a queue (MaxQueue).
	Motion (Config.ScreenMotion.Announce): each banner drops in with a light sweeping across it,
	shrinks away when its time is over, and the others slide into the space it leaves.

	AnnounceUI.Show(text, style)   shows one now (or after the ones waiting)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local MinigameFx = require(script.Parent.MinigameFx)
local ScreenFx = require(script.Parent.ScreenFx)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)
local UIMotion = require(script.Parent.UIMotion)

local AnnounceUI = {}

type Entry = { Text: string, Style: string }
type Card = { Frame: Frame, Height: number }

local queue: { Entry } = {}
local cards: { Card } = {} -- showing now, top to bottom
local show: ((entry: Entry) -> ())? = nil

-- How many banners may show at once on this screen.
local function capacity(): number
	local cfg = Config.Announce
	return math.max(if Layout.IsPhone() then cfg.PhoneMaxShown else cfg.MaxShown, 1)
end

-- Starts the waiting banners while there is room.
local function pump()
	local fn = show
	while fn and #queue > 0 and #cards < capacity() do
		local entry = table.remove(queue, 1) :: Entry
		fn(entry)
	end
end

function AnnounceUI.Show(text: string, style: string)
	table.insert(queue, { Text = text, Style = style })
	while #queue > Config.Announce.MaxQueue do
		table.remove(queue, 1)
	end
	pump()
end

-- The size a Layout.Fit panel is drawn at (1 = its own size).
local function fitOf(frame: Frame): number
	local fit = frame:FindFirstChild("FitScale")
	return if fit and fit:IsA("UIScale") then fit.Scale else 1
end

-- Where the i-th banner showing sits inside the holder.
local function slot(index: number): UDim2
	local y = 0
	for i = 1, index - 1 do
		local card = cards[i]
		y += card.Height * fitOf(card.Frame) + Config.Announce.Gap
	end
	return UDim2.new(0.5, 0, 0, math.floor(y + 0.5))
end

function AnnounceUI.Mount(gui: ScreenGui)
	local motion = Config.ScreenMotion.Announce

	-- The banners stack inside this (it moves down under the Hud on short phone screens).
	local holder = Instance.new("Frame")
	holder.Name = "Announcements"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.12)
	holder.Size = UDim2.fromOffset(1, 1)
	holder.ZIndex = 20
	holder.Visible = false
	holder.Parent = gui
	Layout.KeepBelowHud({ holder })

	show = function(entry: Entry)
		local style = (Config.Announce.Styles :: any)[entry.Style] or Config.Announce.Styles.Big
		local banner = Theme.panel(holder)
		banner.Name = "Announcement"
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Size = UDim2.fromOffset(style.Width, style.Height)
		banner.BackgroundColor3 = style.Background
		banner.ZIndex = 20
		Layout.Fit(banner)
		local label = Theme.label(entry.Text, 30, banner)
		label.Name = "Text"
		label.Font = Enum.Font.GothamBlack
		label.Position = UDim2.fromOffset(12, 6)
		label.Size = UDim2.new(1, -24, 1, -12)
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = style.Color
		label.ZIndex = 21
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize = Config.UI.MinTextSize
		limit.MaxTextSize = math.max(style.TextSize, Config.UI.MinTextSize)
		limit.Parent = label

		local card: Card = { Frame = banner, Height = style.Height }
		table.insert(cards, card)
		holder.Visible = true
		ScreenFx.Slide(
			banner,
			slot(#cards),
			Vector2.new(0, -motion.SlideDistance),
			motion.SlideSeconds
		)
		if ScreenFx.On() and motion.ShineSeconds > 0 then
			MinigameFx.Shine(banner, motion.ShineSeconds, motion.SlideSeconds + motion.ShineDelay)
		end
		local rainbow: RBXScriptConnection? = nil
		if style.Rainbow then
			rainbow = RunService.RenderStepped:Connect(function()
				label.TextColor3 = Color3.fromHSV((os.clock() * 0.35) % 1, 0.75, 1)
			end)
		end
		Sounds.PlaySpec(style.Sound)

		local seconds = style.Seconds
		if Layout.IsPhone() then
			seconds = math.min(seconds, Config.Announce.PhoneMaxSeconds)
		end
		task.delay(seconds, function()
			if rainbow then
				rainbow:Disconnect()
			end
			local index = table.find(cards, card)
			if index then
				table.remove(cards, index)
			end
			-- The others move up into the space it leaves.
			for i, other in cards do
				ScreenFx.MoveTo(other.Frame, slot(i), motion.MoveSeconds)
			end
			local function gone()
				banner:Destroy()
				if #cards == 0 then
					holder.Visible = false
				end
			end
			if ScreenFx.On() then
				UIMotion.PopOut(banner, gone)
			else
				gone()
			end
			pump()
		end)
	end
	pump() -- any that arrived before this screen was ready

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
