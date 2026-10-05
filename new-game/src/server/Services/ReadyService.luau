--!strict
--[[
	READY PAD (settings: Config.Lobby.Ready, on/off: Config.Features.ReadyPad)

	Nobody is pulled into a round automatically. A player is ready while their character
	stands on a part tagged ReadyPad (src/shared/Tags.luau); only ready players take part in
	the next round, everyone else stays in the lobby. The pad is found by its tag, so it can
	be moved, resized, rotated, recoloured or duplicated in Studio (round pads work too).
	The server checks positions every Config.Lobby.Ready.CheckSeconds (not Touched events).

	No ReadyPad in Workspace: a warning in the Output window, and everyone in the lobby
	counts as ready (so rounds still start). Feature switched off: everyone in the server is
	ready, like before v2.

	ReadyService.List() -> { Player }    the players who are ready right now
	ReadyService.IsReady(player) -> boolean
	ReadyService.Count() -> number
	ReadyService.Needed() -> number      Config.Lobby.Ready.MinReady (at least 1)
	ReadyService.PadsActive() -> boolean true when a pad decides who is ready
	ReadyService.Reset(players)          after a round: not ready again until they step on the pad again
	ReadyService.Inside(position, cframe, size, shape, margin, height) -> boolean
	                                     the "is this spot on the pad" maths (shape "Block",
	                                     "Cylinder" or "Ball")

	ReplicatedStorage attributes: ReadyCount, ReadyNeeded, ReadyPads (pads found; 0 = everyone
	counts as ready). Player attribute: Ready (true/false).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local ReadyService = {}

type Pad = { CFrame: CFrame, Size: Vector3, Shape: string }

local ready: { [Player]: boolean? } = {}
local lastOnPad: { [Player]: number } = {} -- os.clock() when last seen on a pad
-- After a round: the character they had then (or true). Not ready again until they are seen
-- off the pad with a different character, then back on it.
local mustLeave: { [Player]: (Model | boolean)? } = {}
local padsActive = false
local warned = false
local collection: CollectionService? = nil -- set in Start

--[[
	Is `position` on a pad at `cframe` with `size`? The pad's axis that points most upwards is
	its height; the spot must be between the pad's bottom and `height` studs above its top,
	and within `margin` studs of its edge. "Cylinder" (a standing round pad) and "Ball" use a
	circle, anything else the rectangle.
]]
function ReadyService.Inside(
	position: Vector3,
	cframe: CFrame,
	size: Vector3,
	shape: string,
	margin: number,
	height: number
): boolean
	local offset = position - cframe.Position
	local axes = { cframe.RightVector, cframe.UpVector, cframe.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local up = 1
	for i = 2, 3 do
		if math.abs(axes[i].Y) > math.abs(axes[up].Y) then
			up = i
		end
	end
	local halfUp = sizes[up] / 2
	if offset.Y < -halfUp - margin or offset.Y > halfUp + height then
		return false
	end
	local a = up % 3 + 1
	local b = a % 3 + 1
	local u = offset:Dot(axes[a])
	local w = offset:Dot(axes[b])
	if shape == "Ball" then
		local radius = math.min(size.X, size.Y, size.Z) / 2
		return u * u + w * w <= (radius + margin) ^ 2
	elseif shape == "Cylinder" and up == 1 then
		-- A cylinder's length runs along its X axis; standing up, Y and Z are the diameter.
		local radius = math.min(size.Y, size.Z) / 2
		return u * u + w * w <= (radius + margin) ^ 2
	end
	return math.abs(u) <= sizes[a] / 2 + margin and math.abs(w) <= sizes[b] / 2 + margin
end

local function shapeOf(part: BasePart): string
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif part.Shape == Enum.PartType.Ball then
			return "Ball"
		end
	end
	return "Block"
end

-- Every ReadyPad in Workspace (a tagged Model counts as its bounding box).
local function findPads(): { Pad }
	local pads: { Pad } = {}
	if not collection then
		return pads
	end
	for _, tagged in collection:GetTagged(Tags.ReadyPad) do
		if not tagged:IsDescendantOf(workspace) then
			continue
		end
		if tagged:IsA("BasePart") then
			table.insert(
				pads,
				{ CFrame = tagged.CFrame, Size = tagged.Size, Shape = shapeOf(tagged) }
			)
		elseif tagged:IsA("Model") then
			local cframe, size = tagged:GetBoundingBox()
			table.insert(pads, { CFrame = cframe, Size = size, Shape = "Block" })
		end
	end
	return pads
end

-- The root part of a living character, or nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onAnyPad(position: Vector3, pads: { Pad }): boolean
	local cfg = Config.Lobby.Ready
	for _, pad in pads do
		if
			ReadyService.Inside(
				position,
				pad.CFrame,
				pad.Size,
				pad.Shape,
				cfg.EdgeMargin,
				cfg.PadHeight
			)
		then
			return true
		end
	end
	return false
end

local function setReady(player: Player, value: boolean)
	ready[player] = value
	if player:GetAttribute("Ready") ~= value then
		player:SetAttribute("Ready", value)
	end
end

-- Updates who is ready and publishes the attributes. Returns how many are ready.
local function check(): number
	local pads = findPads()
	padsActive = #pads > 0
	if not padsActive and not warned then
		warned = true
		warn(
			"[ReadyService] No part tagged ReadyPad in Workspace, so everyone in the lobby counts as ready. "
				.. "Tag a part ReadyPad (see src/shared/Tags.luau) to use the Ready pad."
		)
	end
	local now = os.clock()
	local grace = Config.Lobby.Ready.LeaveGraceSeconds
	local count = 0
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		-- Players in a round are never "ready" (they are already playing).
		local inLobby = root ~= nil and player:GetAttribute("InRound") ~= true
		local isReady: boolean
		if not padsActive then
			isReady = inLobby
		else
			local onPad = inLobby and onAnyPad((root :: BasePart).Position, pads)
			local blocked = mustLeave[player]
			if blocked ~= nil and root and not onPad and player.Character ~= blocked then
				mustLeave[player] = nil
				blocked = nil
			end
			if onPad and blocked == nil then
				lastOnPad[player] = now
			end
			local last = lastOnPad[player]
			isReady = inLobby and blocked == nil and last ~= nil and now - last <= grace
		end
		setReady(player, isReady)
		if isReady then
			count += 1
		end
	end
	ReplicatedStorage:SetAttribute("ReadyCount", count)
	ReplicatedStorage:SetAttribute("ReadyPads", #pads)
	return count
end

function ReadyService.Needed(): number
	return math.max(1, Config.Lobby.Ready.MinReady)
end

function ReadyService.PadsActive(): boolean
	return Config.Features.ReadyPad and padsActive
end

function ReadyService.IsReady(player: Player): boolean
	if not Config.Features.ReadyPad then
		return player.Parent == Players
	end
	return ready[player] == true and player.Parent == Players
end

function ReadyService.List(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if ReadyService.IsReady(player) then
			table.insert(list, player)
		end
	end
	return list
end

function ReadyService.Count(): number
	return #ReadyService.List()
end

-- After a round: these players aren't ready until they step off and back on the pad.
function ReadyService.Reset(players: { Player })
	if not Config.Features.ReadyPad then
		return
	end
	for _, player in players do
		if player.Parent == Players then
			mustLeave[player] = player.Character or true
			lastOnPad[player] = nil
			setReady(player, false)
		end
	end
end

function ReadyService.Start()
	ReplicatedStorage:SetAttribute("ReadyNeeded", ReadyService.Needed())
	if not Config.Features.ReadyPad then
		return
	end
	collection = game:GetService("CollectionService")
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		lastOnPad[player] = nil
		mustLeave[player] = nil
	end)
	task.spawn(function()
		while true do
			local ok, result = pcall(check)
			if not ok then
				warn("[ReadyService] Ready pad check failed: " .. tostring(result))
			end
			task.wait(Config.Lobby.Ready.CheckSeconds)
		end
	end)
end

return ReadyService
