--!strict
--[[
	The vote pads' floating signs and the vote hint (Config.VotePads, switch
	Config.Features.VotePads; the voting itself is on the server: VotingService).

	Every part tagged VotePad gets a floating sign above it (a BillboardGui in PlayerGui, folder
	"VotePadSigns", one per pad, named "Sign<slot>"), drawn from the pad's attributes that the
	server keeps up to date: the game's (or EASY / HARD's) picture and name, the number of
	players standing on it, "Needs 2 players" for a game that can't be played yet, and "Your
	vote" on the pad you stand on (that pad's sign grows a little). A pad with nothing on offer
	shows no sign.
	While the vote is on (ReplicatedStorage State = "Voting"), a line at the top of the screen
	under the top bar says what to do: "Stand on a pad to pick the game! 12s", then
	"King Hunt: stand on EASY or HARD! 6s" (ReplicatedStorage attribute VoteMode).
	Works the same with a mouse, a touch screen or a gamepad: you only walk.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local VotePadsUI = {}

type Sign = {
	Pad: BasePart,
	Gui: BillboardGui,
	Board: Frame,
	Icon: TextLabel,
	Title: TextLabel,
	Count: TextLabel,
	Note: TextLabel,
	Stroke: UIStroke,
	Connections: { RBXScriptConnection },
}

local signs: { [BasePart]: Sign } = {}
local folder: Folder? = nil

local function slotOf(pad: BasePart): number
	local slot = pad:GetAttribute("VoteSlot")
	return if type(slot) == "number" then slot else 0
end

-- Is the local character standing on `pad`? (A circle the size of the pad, up to the Ready
-- pad's PadHeight above it; the server makes the real decision.)
function VotePadsUI.StandingOn(pad: BasePart, position: Vector3): boolean
	local flat = Vector3.new(position.X - pad.Position.X, 0, position.Z - pad.Position.Z)
	local radius = math.min(pad.Size.Y, pad.Size.Z) / 2
	if pad:IsA("Part") and pad.Shape ~= Enum.PartType.Cylinder then
		radius = math.min(pad.Size.X, pad.Size.Z) / 2
	end
	local above = position.Y - pad.Position.Y
	return flat.Magnitude <= radius + 0.3
		and above >= -1
		and above <= Config.Lobby.Ready.PadHeight + 3
end

-- The words on a pad's sign, from its attributes: icon, title, count, note.
function VotePadsUI.Words(pad: BasePart, mine: boolean): (string, string, string, string)
	local text = Config.VotePads.Text
	local name = pad:GetAttribute("VoteName")
	local icon = pad:GetAttribute("VoteIcon")
	local votes = pad:GetAttribute("VoteVotes")
	local needs = pad:GetAttribute("VoteNeeds")
	local phase = pad:GetAttribute("VotePhase")
	local title = if type(name) == "string" then name else ""
	local count = ""
	if phase == "Mode" or phase == "Difficulty" then
		count = text.Votes:format(if type(votes) == "number" then votes else 0)
	end
	local note = ""
	if type(needs) == "number" and needs > 0 then
		note = text.NeedsPlayers:format(needs)
	elseif mine and title ~= "" then
		note = text.YourVote
	end
	return if type(icon) == "string" then icon else "", title, count, note
end

local function makeSign(pad: BasePart)
	local parent = folder
	if not parent or signs[pad] then
		return
	end
	local cfg = Config.VotePads
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign" .. slotOf(pad)
	gui.Adornee = pad
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = cfg.LabelMaxDistance
	-- Sized in studs like a real sign, so the six signs never overlap.
	gui.Size = UDim2.fromScale(cfg.PadSize * 0.95, cfg.PadSize * 0.62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, cfg.LabelHeight, 0)
	gui.ResetOnSpawn = false
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.fromScale(0.5, 0.5)
	board.Size = UDim2.fromScale(0.86, 0.86)
	board.BackgroundColor3 = Color3.fromRGB(24, 18, 34)
	board.BackgroundTransparency = 0.15
	board.Parent = gui
	Theme.round(board, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = cfg.Looks.Default.Color
	stroke.Parent = board
	local function text(name: string, y: number, h: number, font: Enum.Font): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.4
		l.Text = ""
		l.Parent = board
		return l
	end
	local icon = text("Icon", 0.03, 0.3, Enum.Font.GothamBold)
	local title = text("Title", 0.33, 0.27, Enum.Font.FredokaOne)
	local count = text("Count", 0.6, 0.22, Enum.Font.FredokaOne)
	count.TextColor3 = Color3.fromRGB(255, 230, 120)
	local note = text("Note", 0.81, 0.16, Enum.Font.GothamBold)
	note.TextColor3 = Color3.fromRGB(220, 210, 235)
	gui.Parent = parent
	local sign: Sign = {
		Pad = pad,
		Gui = gui,
		Board = board,
		Icon = icon,
		Title = title,
		Count = count,
		Note = note,
		Stroke = stroke,
		Connections = {},
	}
	signs[pad] = sign
	table.insert(
		sign.Connections,
		pad.AncestryChanged:Connect(function()
			if not pad:IsDescendantOf(workspace) then
				gui:Destroy()
				for _, c in sign.Connections do
					c:Disconnect()
				end
				signs[pad] = nil
			end
		end)
	)
end

-- Redraws every sign (cheap: a handful of labels, a few times a second).
-- Sets a property only when it changes (most refreshes change nothing).
local function set(instance: Instance, property: string, value: any)
	if (instance :: any)[property] ~= value then
		(instance :: any)[property] = value
	end
end

-- Redraws every sign (a handful of labels, a few times a second; unchanged ones are left).
local function refresh(position: Vector3?)
	for pad, sign in signs do
		local mine = position ~= nil and VotePadsUI.StandingOn(pad, position)
		local icon, title, count, note = VotePadsUI.Words(pad, mine)
		set(sign.Gui, "Enabled", title ~= "")
		set(sign.Icon, "Text", icon)
		set(sign.Title, "Text", title)
		set(sign.Count, "Text", count)
		set(sign.Note, "Text", note)
		local color = pad:GetAttribute("VoteColor")
		set(
			sign.Stroke,
			"Color",
			if typeof(color) == "Color3" then color else Config.VotePads.Looks.Default.Color
		)
		set(sign.Stroke, "Thickness", if mine then 6 else 3)
		set(sign.Board, "Size", if mine then UDim2.fromScale(1, 1) else UDim2.fromScale(0.86, 0.86))
		local needs = pad:GetAttribute("VoteNeeds")
		set(
			sign.Board,
			"BackgroundTransparency",
			if type(needs) == "number" and needs > 0 then 0.45 else 0.15
		)
	end
end

-- The hint under the top bar while the vote is on, or "" when there is none.
function VotePadsUI.Hint(): string
	if ReplicatedStorage:GetAttribute("State") ~= "Voting" then
		return ""
	end
	local text = Config.VotePads.Text
	local left = ReplicatedStorage:GetAttribute("TimeLeft")
	local seconds = if type(left) == "number" then left else 0
	local mode = ReplicatedStorage:GetAttribute("VoteMode")
	if type(mode) == "string" and mode ~= "" then
		return text.DifficultyHint:format(mode, seconds)
	end
	return text.ModeHint:format(seconds)
end

function VotePadsUI.Mount(gui: ScreenGui)
	if not (Config.Features.VotePads and Config.Features.ReadyPad) then
		return
	end
	local player = Players.LocalPlayer
	local playerGui = gui.Parent or player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local signFolder = Instance.new("Folder")
	signFolder.Name = "VotePadSigns"
	signFolder.Parent = playerGui
	folder = signFolder

	-- The hint line under the top bar.
	local hint = Theme.label("", 18, gui)
	hint.Name = "VotePadHint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 70)
	hint.Size = UDim2.fromOffset(if Layout.IsPhone() then 300 else 440, 34)
	hint.BackgroundColor3 = Color3.fromRGB(24, 18, 34)
	hint.BackgroundTransparency = 0.2
	hint.TextColor3 = Color3.fromRGB(255, 230, 120)
	hint.TextScaled = true
	hint.Visible = false
	Theme.round(hint, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = hint
	Layout.KeepBelowHud({ hint })

	for _, pad in CollectionService:GetTagged(Tags.VotePad) do
		if pad:IsA("BasePart") and pad:IsDescendantOf(workspace) then
			makeSign(pad)
		end
	end
	CollectionService:GetInstanceAddedSignal(Tags.VotePad):Connect(function(pad)
		if pad:IsA("BasePart") then
			makeSign(pad)
		end
	end)

	-- Five times a second on a timer (nothing runs every frame).
	task.spawn(function()
		while signFolder.Parent do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			refresh(if root and root:IsA("BasePart") then root.Position else nil)
			local words = VotePadsUI.Hint()
			set(hint, "Text", words)
			set(hint, "Visible", words ~= "")
			task.wait(0.2)
		end
	end)
end

return VotePadsUI
