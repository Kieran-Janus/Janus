--!strict
--[[
	The hub Voting Board: a live SurfaceGui on Hub.Npcs.VotingBoard.Screen.
	While a vote is open it shows the map and difficulty choices with counts, and its
	buttons cast votes (the server validates them like any other vote). Otherwise it shows
	the round state, map and difficulty. The SurfaceGui lives in PlayerGui (Adornee = the
	board) so its buttons are clickable.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

type Option = { Id: string, Name: string, Votes: number }
type VoteState = { Open: boolean, Maps: { Option }, Difficulties: { Option } }

local VoteBoardUI = {}

function VoteBoardUI.Mount()
	local player = Players.LocalPlayer
	local castVote = Remotes.Event("CastVote")
	local voteUpdate = Remotes.Event("VoteUpdate")
	local current: VoteState? = nil

	local gui = Instance.new("SurfaceGui")
	gui.Name = "VotingBoard"
	gui.ResetOnSpawn = false
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = root
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.04, 0)
	padding.Parent = root

	local function clear()
		for _, child in root:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function text(value: string, order: number, height: number, color: Color3?)
		local label = Theme.label(value, 30, root)
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(0.92, height)
		label.TextScaled = true
		label.TextColor3 = color or Theme.Text
		return label
	end

	local function row(kind: string, options: { Option }, order: number)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.fromScale(0.92, 0.26)
		frame.Parent = root
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0.02, 0)
		rowLayout.Parent = frame
		for _, option in options do
			local b = Instance.new("TextButton")
			b.BackgroundColor3 = Theme.Button
			b.TextColor3 = Theme.Text
			b.Font = Theme.Font
			b.TextScaled = true
			b.Text = ("%s\n%d"):format(option.Name, option.Votes)
			b.Size = UDim2.new(1 / #options, -8, 1, 0)
			b.Parent = frame
			Theme.round(b, 12)
			b.Activated:Connect(function()
				castVote:FireServer(kind, option.Id)
			end)
		end
	end

	local function render()
		clear()
		text("Voting Board", 0, 0.16, Config.Hub.Colors.Orange)
		local state = current
		if state and state.Open then
			text("Pick the next map", 1, 0.1, Theme.Muted)
			row("Map", state.Maps, 2)
			text("Easy or Hard?", 3, 0.1, Theme.Muted)
			row("Difficulty", state.Difficulties, 4)
		else
			local roundState = ReplicatedStorage:GetAttribute("State") or "Waiting"
			local mapName = ReplicatedStorage:GetAttribute("MapName")
			local difficulty = ReplicatedStorage:GetAttribute("Difficulty")
			text(tostring(roundState), 1, 0.2)
			if mapName then
				text(
					("%s  |  %s"):format(tostring(mapName), tostring(difficulty or "")),
					2,
					0.14,
					Theme.Muted
				)
			end
			text("The next vote opens between rounds.", 3, 0.12, Theme.Muted)
		end
	end

	voteUpdate.OnClientEvent:Connect(function(state: VoteState)
		if typeof(state) == "table" then
			current = state
			render()
		end
	end)
	for _, name in { "State", "MapName", "Difficulty" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
			if not (current and current.Open) then
				render()
			end
		end)
	end

	-- The hub may be built after this client starts; keep looking for the board.
	task.spawn(function()
		while true do
			local hub = workspace:FindFirstChild("Hub")
			local npcs = hub and hub:FindFirstChild("Npcs")
			local board = npcs and npcs:FindFirstChild("VotingBoard")
			local screen = board and board:FindFirstChild("Screen")
			if screen and screen:IsA("BasePart") and gui.Adornee ~= screen then
				gui.Adornee = screen
				render()
			end
			task.wait(2)
		end
	end)
	render()
end

return VoteBoardUI
