--!strict
--[[
	Live text on the Ready pad's floating sign (the BillboardGui "Sign" on parts tagged
	ReadySign, built by src/server/Hub/Sections/ReadyArea.luau):
	  top line      "READY x / y" from the ReplicatedStorage attributes ReadyCount (players on
	                the pad) and ReadyNeeded (players needed to start), set by ReadyService
	  bottom line   "You're ready!" while you stand on the pad (your player attribute Ready),
	                otherwise what the round is doing (ReplicatedStorage attribute State)
	Text comes from Config.Hub.ReadyArea.Sign. Only your own copy of the sign changes. Signs
	that stream in later, or are added in Studio (any part tagged ReadySign with TextLabels
	called Title and Status), are filled in too. Off when Config.Features.ReadyPad is false.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local ReadySign = {}

-- The two lines for the current attributes (pure: also used by the tests).
function ReadySign.Text(
	count: unknown,
	needed: unknown,
	state: unknown,
	isReady: boolean
): (string, string)
	local text = Config.Hub.ReadyArea.Sign
	local title = text.TitleWaiting
	if typeof(count) == "number" and typeof(needed) == "number" then
		if count >= needed then
			title = text.TitleEnough:format(count)
		else
			title = text.Title:format(count, needed)
		end
	elseif typeof(count) == "number" then
		title = text.TitleEnough:format(count)
	end
	local status: string
	if isReady then
		status = text.YouAreReady
	elseif typeof(state) == "string" and state ~= "" then
		status = text.States[state] or state
	else
		status = Config.Lobby.Ready.PadText
	end
	return title, status
end

function ReadySign.Mount()
	if not Config.Features.ReadyPad then
		return
	end
	local player = Players.LocalPlayer

	local function labels(sign: Instance): (TextLabel?, TextLabel?)
		local title = sign:FindFirstChild("Title", true)
		local status = sign:FindFirstChild("Status", true)
		return if title and title:IsA("TextLabel") then title else nil,
			if status and status:IsA("TextLabel") then status else nil
	end

	local function refresh(sign: Instance)
		local titleLabel, statusLabel = labels(sign)
		local title, status = ReadySign.Text(
			ReplicatedStorage:GetAttribute("ReadyCount"),
			ReplicatedStorage:GetAttribute("ReadyNeeded"),
			ReplicatedStorage:GetAttribute("State"),
			player:GetAttribute("Ready") == true
		)
		if titleLabel then
			titleLabel.Text = title
		end
		if statusLabel then
			statusLabel.Text = status
		end
	end

	local function refreshAll()
		for _, sign in CollectionService:GetTagged(Tags.ReadySign) do
			refresh(sign)
		end
	end

	CollectionService:GetInstanceAddedSignal(Tags.ReadySign):Connect(function(sign)
		refresh(sign)
		-- With streaming, the labels can arrive just after the part.
		task.delay(1, refresh, sign)
	end)
	for _, name in { "ReadyCount", "ReadyNeeded", "State" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshAll)
	end
	player:GetAttributeChangedSignal("Ready"):Connect(refreshAll)
	refreshAll()

	-- Standing under the sign (on the pad) you can only see its cut-off bottom covering the top
	-- of the screen, and the Hud already shows the count: hide it while the camera is that close.
	local hideNear = Config.Hub.ReadyArea.Sign.HideNear
	if hideNear > 0 then
		task.spawn(function()
			while true do
				local camera = workspace.CurrentCamera
				if camera then
					local eye = camera.CFrame.Position
					for _, sign in CollectionService:GetTagged(Tags.ReadySign) do
						local gui = sign:FindFirstChildWhichIsA("BillboardGui")
						if gui and sign:IsA("BasePart") then
							local flat = (sign.Position - eye) * Vector3.new(1, 0, 1)
							gui.Enabled = flat.Magnitude > hideNear
						end
					end
				end
				task.wait(0.25)
			end
		end)
	end
end

return ReadySign
