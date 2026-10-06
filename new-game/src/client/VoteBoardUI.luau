--!strict
--[[
	The hub Voting Board: a live SurfaceGui on the board's "Screen" part. The board is the NPC
	in Config.Npcs.List with Kind "Board" (Id VotingBoard), found by its NpcId attribute
	wherever it is in Workspace.Hub (in Npcs, in a lobby area when it has a Zone, or moved by
	hand in Studio).
	While a vote is open it shows the game (mode + map) and, when an offered mode uses it, the
	difficulty choices with counts, and its buttons cast votes (the server validates them
	like any other vote; players not on the Ready pad see a hint instead). Otherwise it shows
	the round state, mode, map and difficulty. The SurfaceGui lives in PlayerGui (Adornee = the
	board) so its buttons are clickable.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

type Option = { Id: string, Name: string, Votes: number }
type VoteState = {
	Open: boolean,
	Maps: { Option },
	Difficulties: { Option },
	ReadyOnly: boolean?,
}

local VoteBoardUI = {}

-- The Voting Board's NPC Id from Config.Npcs.List (the first NPC of Kind "Board").
local function boardId(): string
	for _, def in Config.Npcs.List do
		if def.Kind == "Board" then
			return def.Id
		end
	end
	return "VotingBoard"
end

-- The board's Screen part: Hub.Npcs.<id> first (quick), else any Model in the hub whose NpcId
-- attribute is `id`. nil while the hub or the board hasn't been built or streamed in yet.
function VoteBoardUI.FindScreen(hub: Instance, id: string): BasePart?
	local npcs = hub:FindFirstChild("Npcs")
	local board: Instance? = npcs and npcs:FindFirstChild(id)
	if not (board and board:IsA("Model") and board:FindFirstChild("Screen")) then
		board = nil
		for _, d in hub:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("NpcId") == id and d:FindFirstChild("Screen") then
				board = d
				break
			end
		end
	end
	local screen = board and board:FindFirstChild("Screen")
	return if screen and screen:IsA("BasePart") then screen else nil
end

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
		local words = Config.Npcs.BoardText
		text(words.Title, 0, 0.16, Config.Hub.Colors.Orange)
		local state = current
		if state and state.Open then
			-- Only Ready players can vote (when the server says so): the others get a hint.
			if state.ReadyOnly and player:GetAttribute("Ready") ~= true then
				text(Config.Lobby.Ready.Text.VoteHint, 1, 0.1, Theme.Selected)
			else
				text(words.Pick, 1, 0.1, Theme.Muted)
			end
			row("Map", state.Maps, 2)
			if #state.Difficulties > 0 then
				text(words.Difficulty, 3, 0.1, Theme.Muted)
				row("Difficulty", state.Difficulties, 4)
			end
		else
			local raw = ReplicatedStorage:GetAttribute("State")
			local waiting = raw == nil or raw == "Waiting for players"
			local roundState = raw or "Waiting"
			local parts = {}
			for _, name in { "ModeName", "MapName", "Difficulty" } do
				local value = ReplicatedStorage:GetAttribute(name)
				if value then
					table.insert(parts, tostring(value))
				end
			end
			text(tostring(roundState), 1, 0.2)
			if #parts > 0 then
				text(table.concat(parts, "  |  "), 2, 0.14, Theme.Muted)
			end
			text(if waiting then words.SignWaiting else words.SignRound, 3, 0.12, Theme.Muted)
		end
	end

	voteUpdate.OnClientEvent:Connect(function(state: VoteState)
		if typeof(state) == "table" then
			current = state
			render()
		end
	end)
	player:GetAttributeChangedSignal("Ready"):Connect(function()
		if current and current.Open and current.ReadyOnly then
			render()
		end
	end)
	for _, name in { "State", "ModeName", "MapName", "Difficulty" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
			if not (current and current.Open) then
				render()
			end
		end)
	end

	-- The hub may be built (or stream in) after this client starts, and can be rebuilt: look
	-- for the board again whenever the one shown is gone.
	local id = boardId()
	task.spawn(function()
		while true do
			local shown = gui.Adornee
			if not (shown and shown:IsDescendantOf(workspace)) then
				local hub = workspace:FindFirstChild("Hub")
				local screen = hub and VoteBoardUI.FindScreen(hub, id)
				if screen then
					gui.Adornee = screen
					render()
				end
			end
			task.wait(2)
		end
	end)
	render()
end

return VoteBoardUI
