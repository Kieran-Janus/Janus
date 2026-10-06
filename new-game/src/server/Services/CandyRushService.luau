--!strict
--[[
	CANDY RUSH, a lobby minigame (settings: Config.Minigames.CandyRush; on/off:
	Config.Features.CandyRush; the stand: src/server/Hub/Sections/CandyRush.luau).

	How a race goes (one race at a time on each stand):
	  1. Players stand on the coloured join pads (parts tagged CandyRushPad, attribute Lane).
	     The server checks positions every CheckSeconds (not Touched). One player per pad.
	  2. With MinPlayers on pads: a 3-2-1 countdown, on the board and on their screens.
	     Alone on a pad for Solo.AfterSeconds: a solo "beat your time" run instead.
	  3. GO: everyone gets Candies candies, one at a time, at random spots in their own lane of
	     the board (the part tagged CandyRushBoard). Clicking / tapping your candy pops it
	     (a ClickDetector; the server checks it is yours, the race is on and you are close).
	  4. The first to pop them all wins. Leaving your pad (or the game) knocks you out and the
	     last one left wins. After MaxRaceSeconds the one with the most candies wins.
	  5. Coins (Config ... Rewards): the winner, everyone else who stayed, a finished solo run;
	     each needs MinCandies popped, has a cooldown and a daily cap. Saved in data.Minigames:
	     CandyRushWins (races won), CandyRushBest (best solo time, seconds) and the cooldown
	     fields CandyRushDay, CandyRushCoinsToday, CandyRushLastReward, CandyRushLastSolo.
	Players in a round (player attribute InRound) are ignored. A stand is a Model tagged
	CandyRushStation; a copy of it is a second, separate race. A saved hub with no stand gets
	one for this server (src/server/Hub/Sections/CandyRush.luau Repair, with a warning).

	Remote (created even when the feature is off):
	  CandyRushState (server -> client): the State below for the stand you are on, or nil when
	  you are not on one any more (the screen hides).
	While the game runs each stand gets a "Candies" folder (the candies: Models with the
	attributes OwnerUserId and Lane) and a "LaneScreen" part (names, progress and the big
	countdown drawn on the board). The stand's "ScoreboardGui" shows the status and the record.
	Admin command: CandyRushSolo, "Candy Rush: start solo test".

	CandyRushService.StartSolo(player) -> (boolean, string)   puts you on a free pad and starts
	                                                           a solo run straight away
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Build.Kit)
local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)
local CandyRushCandy = require(script.Parent.Parent.Minigames.CandyRushCandy)
local Rules = require(script.Parent.Parent.Minigames.CandyRushRules)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local ReadyService = require(script.Parent.ReadyService)
local SfxService = require(script.Parent.SfxService)
local ShopService = require(script.Parent.ShopService)

local CandyRushService = {}

local cfg = Config.Minigames.CandyRush
local text = cfg.Text

local MAX_LANES = 12
local GO_SECONDS = 1 -- "GO!" stays on the board this long
local CANDY_GAP = 0.75 -- studs between the board's face and a candy's middle
local SCREEN_GAP = 0.12 -- studs between the board's face and the LaneScreen
local RESCAN_SECONDS = 1 -- how often the stands, boards and pads are looked up again

export type Phase = "Waiting" | "Countdown" | "Live" | "Results"

-- One lane as the client sees it.
export type LaneRow = {
	Lane: number,
	UserId: number,
	Name: string,
	Popped: number,
	Out: boolean,
	Color: Color3,
}

-- What CandyRushState sends (src/client/CandyRushUI.luau shows it).
export type State = {
	Phase: Phase,
	Count: number?, -- the countdown number (3, 2, 1)
	Total: number, -- candies to win
	Solo: boolean,
	Lanes: { LaneRow },
	Needed: number, -- more players needed before a race starts (Waiting)
	SoloIn: number?, -- seconds until a solo run starts (Waiting, alone)
	Winner: { UserId: number, Name: string }?,
	Reason: string?, -- Rules.Reason, once the race is over
	StartedAt: number?, -- workspace:GetServerTimeNow() at GO
	EndsAt: number?, -- ... when the race stops
	Record: { Name: string, Time: number }?,
	-- About you:
	YourLane: number?,
	InRace: boolean,
	Out: boolean?,
	Time: number?, -- your time to pop them all (seconds)
	Best: number?, -- your best solo time
	NewBest: boolean?,
	Coins: number?, -- coins you got for this race
	Note: string?, -- why you got fewer coins: "TooFew", "Cooldown" or "DailyCap"
}

type Box = { CFrame: CFrame, Size: Vector3, Shape: string }

-- The board's face as a player on the pads sees it: View looks INTO the board, x to the
-- player's right, y up; Width/Height/Thickness in studs.
type Face = { View: CFrame, Width: number, Height: number, Thickness: number }

type Runner = {
	Player: Player,
	Name: string,
	Lane: number,
	Popped: number,
	Out: boolean,
	Candy: Model?,
	ShownAt: number, -- os.clock() when the current candy appeared
	LastOnPad: number,
	LastSpot: Vector2?,
	Time: number?,
	Best: number?,
	NewBest: boolean?,
	Coins: number?,
	Note: string?,
}

type Race = {
	Token: number,
	Solo: boolean,
	Total: number,
	StartedAt: number, -- os.clock()
	EndsAt: number,
	ServerStart: number, -- workspace:GetServerTimeNow()
	ServerEnds: number,
	Runners: { [Player]: Runner },
	Order: { Runner }, -- by lane
	Winner: Runner?,
	Reason: string?,
}

type LaneColumn = { Frame: Frame, Fill: Frame, Name: TextLabel }

type Screen = {
	Part: BasePart,
	Columns: { [number]: LaneColumn },
	Banner: TextLabel,
	Key: string, -- lanes and board size it was made for
}

type Station = {
	Model: Instance,
	Board: Instance?,
	Pads: { [number]: Instance },
	LaneCount: number,
	Phase: Phase,
	Lanes: { [number]: Player }, -- who waits on each pad (runners hold theirs in Race)
	LastOnPad: { [Player]: number },
	Benched: { [Player]: boolean }, -- must step off the pads before joining again
	Watchers: { [Player]: boolean }, -- who was sent this stand's state last time
	AloneSince: number?,
	CountdownEnds: number,
	CountdownSolo: boolean,
	Count: number?,
	GoUntil: number,
	ResultsUntil: number,
	Race: Race?,
	ForceSolo: Player?, -- the admin test command
	ForceUntil: number,
	Record: { Name: string, Time: number }?,
	Candies: Folder,
	Screen: Screen?,
	Signature: string,
	Warned: boolean,
	PartsAt: number, -- os.clock() when the board and pads were last looked up
}

local stateRemote: RemoteEvent? = nil
local stations: { [Instance]: Station } = {}
local nextToken = 0
local rng = Random.new()

-- Helpers ---------------------------------------------------------------------------------------

local function num(value: unknown): number
	return if typeof(value) == "number" and value == value then value else 0
end

-- A tagged part, or a tagged Model as its bounding box.
local function boxOf(instance: Instance): Box?
	if instance:IsA("BasePart") then
		local shape = "Block"
		if instance:IsA("Part") then
			if instance.Shape == Enum.PartType.Cylinder then
				shape = "Cylinder"
			elseif instance.Shape == Enum.PartType.Ball then
				shape = "Ball"
			end
		end
		return { CFrame = instance.CFrame, Size = instance.Size, Shape = shape }
	elseif instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return { CFrame = cframe, Size = size, Shape = "Block" }
	end
	return nil
end

-- The root part of a living character that is in the lobby (not in a round), or nil.
local function lobbyRoot(player: Player): BasePart?
	if player.Parent ~= Players or player:GetAttribute("InRound") == true then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function laneColor(station: Station, lane: number): Color3
	local pad = station.Pads[lane]
	if pad and pad:IsA("BasePart") then
		return pad.Color
	end
	local list = cfg.Stand.LaneColors
	return list[(lane - 1) % #list + 1]
end

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local function laneOf(station: Station, player: Player): number?
	for lane, p in station.Lanes do
		if p == player then
			return lane
		end
	end
	return nil
end

-- Finds the stand's board and pads again (they may have been moved, resized or removed).
local function refreshParts(station: Station)
	local model = station.Model
	local board: Instance? = nil
	for _, tagged in CollectionService:GetTagged(Tags.CandyRushBoard) do
		if tagged:IsDescendantOf(model) and (tagged:IsA("BasePart") or tagged:IsA("Model")) then
			board = tagged
			break
		end
	end
	local pads: { [number]: Instance } = {}
	local lanes = 0
	for _, tagged in CollectionService:GetTagged(Tags.CandyRushPad) do
		if not tagged:IsDescendantOf(model) then
			continue
		end
		local lane = tagged:GetAttribute("Lane")
		if
			typeof(lane) == "number"
			and lane >= 1
			and lane <= MAX_LANES
			and lane % 1 == 0
			and not pads[lane]
		then
			pads[lane] = tagged
			lanes = math.max(lanes, lane)
		elseif not station.Warned then
			station.Warned = true
			warn(
				("[CandyRush] %s needs a Lane attribute (1, 2, 3...) that no other pad has; it is ignored."):format(
					tagged:GetFullName()
				)
			)
		end
	end
	if not board and not station.Warned then
		station.Warned = true
		warn(
			("[CandyRush] %s has no part tagged CandyRushBoard, so no race can start there."):format(
				model:GetFullName()
			)
		)
	end
	station.Board = board
	station.Pads = pads
	station.LaneCount = lanes
end

-- The board's face towards the pads (its thinnest side is its thickness).
local function faceOf(station: Station): Face?
	local box = if station.Board then boxOf(station.Board) else nil
	if not box then
		return nil
	end
	local cframe, size = box.CFrame, box.Size
	local axes = { cframe.RightVector, cframe.UpVector, cframe.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local n = 1
	for i = 2, 3 do
		if sizes[i] < sizes[n] then
			n = i
		end
	end
	local normal = axes[n]
	local sum, pads = Vector3.zero, 0
	for _, pad in station.Pads do
		local padBox = boxOf(pad)
		if padBox then
			sum += padBox.CFrame.Position
			pads += 1
		end
	end
	if pads > 0 and (sum / pads - cframe.Position):Dot(normal) < 0 then
		normal = -normal
	end
	local a, b = n % 3 + 1, (n + 1) % 3 + 1
	local up, width, height
	if math.abs(axes[a].Y) >= math.abs(axes[b].Y) then
		up, height, width = axes[a], sizes[a], sizes[b]
	else
		up, height, width = axes[b], sizes[b], sizes[a]
	end
	if up.Y < 0 then
		up = -up
	end
	local right = up:Cross(normal)
	return {
		View = CFrame.fromMatrix(cframe.Position, right, up, normal),
		Width = width,
		Height = height,
		Thickness = sizes[n],
	}
end

-- The lanes whose pad `position` is standing on, lowest first.
local function lanesUnder(station: Station, position: Vector3): { number }
	local list = {}
	for lane, pad in station.Pads do
		local box = boxOf(pad)
		if
			box
			and ReadyService.Inside(
				position,
				box.CFrame,
				box.Size,
				box.Shape,
				cfg.PadEdgeMargin,
				cfg.PadHeight
			)
		then
			table.insert(list, lane)
		end
	end
	table.sort(list)
	return list
end

-- The board ---------------------------------------------------------------------------------------

local function label(name: string, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Text = ""
	l.Parent = parent
	return l
end

-- The see-through "LaneScreen" in front of the board: a column per lane with the player's
-- name and a progress fill, and the big countdown / winner text in the middle.
local function ensureScreen(station: Station, face: Face): Screen?
	local key = ("%d|%.2f|%.2f|%s"):format(
		station.LaneCount,
		face.Width,
		face.Height,
		tostring(face.View)
	)
	local screen = station.Screen
	if screen and screen.Key == key and screen.Part.Parent == station.Model then
		return screen
	end
	if screen then
		screen.Part:Destroy()
		station.Screen = nil
	end
	if station.LaneCount < 1 then
		return nil
	end
	local part = Kit.holder(
		"LaneScreen",
		face.View * CFrame.new(0, 0, face.Thickness / 2 + SCREEN_GAP) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(face.Width, face.Height, 0.05),
		station.Model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LaneGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local columns: { [number]: LaneColumn } = {}
	local lanes = station.LaneCount
	local bottom = math.clamp(cfg.Candy.BottomSpace / math.max(face.Height, 1), 0.05, 0.4)
	for lane = 1, lanes do
		local frame = Instance.new("Frame")
		frame.Name = "Lane" .. lane
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.fromScale((lane - 1) / lanes, 0)
		frame.Size = UDim2.fromScale(1 / lanes, 1)
		frame.Parent = gui
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.AnchorPoint = Vector2.new(0.5, 1)
		fill.Position = UDim2.fromScale(0.5, 1)
		fill.Size = UDim2.fromScale(0.86, 0)
		fill.BorderSizePixel = 0
		fill.BackgroundTransparency = 0.45
		fill.BackgroundColor3 = laneColor(station, lane)
		fill.Parent = frame
		local name = label("PlayerName", frame)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.fromScale(0.5, 0.98)
		name.Size = UDim2.fromScale(0.9, bottom * 0.8)
		columns[lane] = { Frame = frame, Fill = fill, Name = name }
	end
	local banner = label("Banner", gui)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.42)
	banner.Size = UDim2.fromScale(0.9, 0.42)
	banner.ZIndex = 3
	banner.TextColor3 = cfg.Stand.Colors.SignText
	banner.TextStrokeTransparency = 0
	banner.Visible = false
	gui.Parent = part
	local made: Screen = { Part = part :: BasePart, Columns = columns, Banner = banner, Key = key }
	station.Screen = made
	return made
end

-- The line under the sign for every phase ("Stand on a pad to play!", "3", "Kieran WINS!").
local function statusText(station: Station, state: State): string
	if state.Phase == "Countdown" then
		return tostring(state.Count or "")
	elseif state.Phase == "Live" then
		return text.RaceOn
	elseif state.Phase == "Results" then
		local race = station.Race
		local winner = race and race.Winner
		if race and race.Solo and winner and winner.Time then
			return text.SoloDone:format(winner.Name, winner.Time)
		elseif winner then
			return text.Wins:format(winner.Name)
		elseif state.Reason == "TimeUp" then
			return text.TimeUp
		end
		return text.NoWinner
	end
	if state.SoloIn then
		return text.SoloSoon:format(state.SoloIn)
	elseif #state.Lanes > 0 and state.Needed > 0 then
		return text.NeedMore:format(state.Needed)
	end
	return text.Idle
end

local function drawBoard(station: Station, state: State, now: number)
	local face = faceOf(station)
	local screen = face and ensureScreen(station, face)
	if screen then
		local rows: { [number]: LaneRow } = {}
		for _, row in state.Lanes do
			rows[row.Lane] = row
		end
		local racing = state.Phase == "Live" or state.Phase == "Results"
		for lane, column in screen.Columns do
			local row = rows[lane]
			column.Fill.BackgroundColor3 = laneColor(station, lane)
			if row then
				local name = row.Name
				if racing then
					name = ("%s %d/%d"):format(name, row.Popped, state.Total)
				end
				if row.Out then
					name ..= " (" .. text.OutTag .. ")"
				end
				column.Name.Text = name
				column.Name.TextTransparency = if row.Out then 0.5 else 0
				column.Fill.Size = UDim2.fromScale(
					0.86,
					if racing then math.clamp(row.Popped / state.Total, 0, 1) else 0
				)
			else
				column.Name.Text = text.FreeLane
				column.Name.TextTransparency = 0.55
				column.Fill.Size = UDim2.fromScale(0.86, 0)
			end
		end
		local banner = ""
		if state.Phase == "Countdown" then
			banner = tostring(state.Count or "")
		elseif state.Phase == "Live" and now < station.GoUntil then
			banner = text.Go
		elseif state.Phase == "Results" then
			banner = statusText(station, state)
		end
		screen.Banner.Text = banner
		screen.Banner.Visible = banner ~= ""
	end

	local scoreboard = station.Model:FindFirstChild("ScoreboardGui", true)
	if scoreboard then
		local status = scoreboard:FindFirstChild("Status")
		if status and status:IsA("TextLabel") then
			status.Text = statusText(station, state)
		end
		local record = scoreboard:FindFirstChild("Record")
		if record and record:IsA("TextLabel") then
			local best = station.Record
			record.Text = if best then text.Record:format(best.Name, best.Time) else text.NoRecord
		end
	end
end

-- State for the clients -------------------------------------------------------------------------

local function sharedState(station: Station, now: number): State
	local race = station.Race
	local rows: { LaneRow } = {}
	if race then
		for _, runner in race.Order do
			table.insert(rows, {
				Lane = runner.Lane,
				UserId = runner.Player.UserId,
				Name = runner.Name,
				Popped = runner.Popped,
				Out = runner.Out,
				Color = laneColor(station, runner.Lane),
			})
		end
	else
		for lane = 1, station.LaneCount do
			local player = station.Lanes[lane]
			if player then
				table.insert(rows, {
					Lane = lane,
					UserId = player.UserId,
					Name = player.DisplayName,
					Popped = 0,
					Out = false,
					Color = laneColor(station, lane),
				})
			end
		end
	end
	local waiting = count(station.Lanes)
	local soloIn: number? = nil
	if station.Phase == "Waiting" and waiting == 1 and station.AloneSince and cfg.Solo.On then
		soloIn = math.max(0, math.ceil(cfg.Solo.AfterSeconds - (now - station.AloneSince)))
	end
	local winner = race and race.Winner
	return {
		Phase = station.Phase,
		Count = if station.Phase == "Countdown" then station.Count else nil,
		Total = if race then race.Total else math.max(1, math.floor(cfg.Candies)),
		Solo = if race then race.Solo else station.CountdownSolo,
		Lanes = rows,
		Needed = math.max(0, math.max(2, cfg.MinPlayers) - waiting),
		SoloIn = soloIn,
		Winner = if winner then { UserId = winner.Player.UserId, Name = winner.Name } else nil,
		Reason = if race then race.Reason else nil,
		StartedAt = if race then race.ServerStart else nil,
		EndsAt = if race then race.ServerEnds else nil,
		Record = station.Record,
		InRace = false,
	}
end

local function personalState(station: Station, shared: State, player: Player): State
	local state = table.clone(shared)
	local race = station.Race
	local runner = race and race.Runners[player]
	if runner then
		state.YourLane = runner.Lane
		state.InRace = true
		state.Out = runner.Out
		state.Time = runner.Time
		state.Best = runner.Best
		state.NewBest = runner.NewBest
		state.Coins = runner.Coins
		state.Note = runner.Note
	else
		state.YourLane = laneOf(station, player)
	end
	return state
end

-- What changed since the last refresh (the countdown number, who stands where...).
local function signature(station: Station, now: number): string
	local parts: { string } =
		{ station.Phase :: string, tostring(station.Count), tostring(now < station.GoUntil) }
	for lane = 1, station.LaneCount do
		local player = station.Lanes[lane]
		table.insert(parts, if player then tostring(player.UserId) else "-")
	end
	local race = station.Race
	if race then
		for _, runner in race.Order do
			table.insert(
				parts,
				("%d:%d:%s"):format(runner.Lane, runner.Popped, tostring(runner.Out))
			)
		end
	end
	if station.Phase == "Waiting" and station.AloneSince and cfg.Solo.On then
		table.insert(parts, tostring(math.ceil(cfg.Solo.AfterSeconds - (now - station.AloneSince))))
	end
	return table.concat(parts, ",")
end

-- Sends everyone at the stand its state, hides it for those who left, redraws the board.
local function refresh(station: Station)
	local now = os.clock()
	station.Signature = signature(station, now)
	local shared = sharedState(station, now)
	local audience: { [Player]: boolean } = {}
	for _, player in station.Lanes do
		if player.Parent == Players then
			audience[player] = true
		end
	end
	local race = station.Race
	if race then
		for _, runner in race.Order do
			if runner.Player.Parent == Players then
				audience[runner.Player] = true
			end
		end
	end
	local remote = stateRemote
	if remote then
		for player in audience do
			remote:FireClient(player, personalState(station, shared, player))
		end
		for player in station.Watchers do
			if not audience[player] and player.Parent == Players then
				remote:FireClient(player, nil)
			end
		end
	end
	station.Watchers = audience
	drawBoard(station, shared, now)
end

-- The race ---------------------------------------------------------------------------------------

local function popEffect(station: Station, cframe: CFrame, color: Color3)
	local holder = Kit.holder("CandyPop", cframe, Vector3.one, station.Candies)
	local emitter = Kit.particles(holder, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Acceleration = Vector3.new(0, -12, 0),
		Rate = 160,
		LightEmission = 0.5,
		RotSpeed = NumberRange.new(-180, 180),
	})
	task.delay(0.15, function()
		emitter.Enabled = false
	end)
	SfxService.Play3D(cfg.Sounds.Pop, holder)
	Debris:AddItem(holder, 1.5)
end

local endRace: (station: Station, race: Race, winner: Runner?, reason: string) -> ()
local checkEnd: (station: Station, race: Race) -> ()

local function isCurrent(station: Station, race: Race): boolean
	return stations[station.Model] == station and station.Race == race and station.Phase == "Live"
end

local spawnCandy: (station: Station, race: Race, runner: Runner) -> ()

local function onClick(station: Station, race: Race, runner: Runner, candy: Model, clicker: unknown)
	if typeof(clicker) ~= "Instance" or clicker ~= runner.Player then
		return -- only your own candies
	end
	if not isCurrent(station, race) or runner.Out or runner.Candy ~= candy then
		return
	end
	local now = os.clock()
	if now - runner.ShownAt < cfg.MinClickSeconds then
		return -- faster than a person can click
	end
	local root = lobbyRoot(runner.Player)
	local spot = candy:GetPivot()
	if not root or (root.Position - spot.Position).Magnitude > cfg.ClickDistance + 6 then
		return
	end
	runner.Candy = nil
	local color = candy:GetAttribute("CandyColor")
	popEffect(station, spot, if typeof(color) == "Color3" then color else Color3.new(1, 1, 1))
	candy:Destroy()
	runner.Popped += 1
	if runner.Popped >= race.Total then
		runner.Time = now - race.StartedAt
		checkEnd(station, race)
		return
	end
	refresh(station)
	local delay = cfg.NextCandyDelay
	task.delay(
		rng:NextNumber(delay.Min, math.max(delay.Min, delay.Max)),
		spawnCandy,
		station,
		race,
		runner
	)
end

spawnCandy = function(station: Station, race: Race, runner: Runner)
	if not isCurrent(station, race) or runner.Out or runner.Candy then
		return
	end
	local face = faceOf(station)
	if not face then
		endRace(station, race, nil, "Empty")
		return
	end
	local candyCfg = cfg.Candy
	local rect = Rules.LaneRect(
		runner.Lane,
		station.LaneCount,
		face.Width,
		face.Height,
		candyCfg.Size,
		candyCfg.EdgeMargin,
		candyCfg.BottomSpace
	)
	local spot = Rules.RandomSpot(rect, rng, runner.LastSpot, candyCfg.Size * 1.2)
	runner.LastSpot = spot
	local cframe = face.View
		* CFrame.new(spot.X, spot.Y, face.Thickness / 2 + CANDY_GAP)
		* CFrame.Angles(0, math.pi, 0)
	local kinds = candyCfg.Kinds
	local colors = candyCfg.Colors
	local candy = CandyRushCandy.Build(
		kinds[rng:NextInteger(1, #kinds)],
		colors[rng:NextInteger(1, #colors)],
		cframe
	)
	candy.Name = "Candy_Lane" .. runner.Lane
	candy:SetAttribute("OwnerUserId", runner.Player.UserId)
	candy:SetAttribute("Lane", runner.Lane)
	pcall(function()
		candy.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- all its parts arrive at once
	end)
	-- A click detector on every part (the candy and its invisible hitbox), so a click or tap
	-- anywhere on it counts.
	for _, part in candy:GetDescendants() do
		if part:IsA("BasePart") then
			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = cfg.ClickDistance
			detector.Parent = part
			detector.MouseClick:Connect(function(clicker: Player)
				onClick(station, race, runner, candy, clicker)
			end)
		end
	end
	runner.Candy = candy
	runner.ShownAt = os.clock()
	candy.Parent = station.Candies
end

local function knockOut(station: Station, race: Race, runner: Runner)
	if runner.Out then
		return
	end
	runner.Out = true
	if runner.Candy then
		runner.Candy:Destroy()
		runner.Candy = nil
	end
	checkEnd(station, race)
	if isCurrent(station, race) then
		refresh(station)
	end
end

local function giveReward(race: Race, runner: Runner)
	local player = runner.Player
	local data = DataService.Get(player)
	if not data then
		return
	end
	local saved = data.Minigames
	if type(saved) ~= "table" then
		saved = {}
		data.Minigames = saved
	end
	local won = race.Winner == runner
	local kind: Rules.RewardKind? = nil
	if race.Solo then
		if won and runner.Time then
			kind = "Solo"
			local best = num(saved.CandyRushBest)
			local time = math.floor(runner.Time * 100 + 0.5) / 100
			if best <= 0 or time < best then
				saved.CandyRushBest = time
				runner.NewBest = true
			end
			runner.Best = num(saved.CandyRushBest)
		end
	elseif won then
		kind = "Win"
		if runner.Popped >= cfg.Rewards.MinCandies then
			saved.CandyRushWins = num(saved.CandyRushWins) + 1
		end
	elseif not runner.Out then
		kind = "Play"
	end
	if not kind then
		return
	end
	local record: Rules.RewardRecord = {
		Day = num(saved.CandyRushDay),
		CoinsToday = num(saved.CandyRushCoinsToday),
		LastReward = num(saved.CandyRushLastReward),
		LastSolo = num(saved.CandyRushLastSolo),
	}
	local coins, new, note = Rules.Reward(record, kind, runner.Popped, os.time(), cfg.Rewards)
	saved.CandyRushDay = new.Day
	saved.CandyRushCoinsToday = new.CoinsToday
	saved.CandyRushLastReward = new.LastReward
	saved.CandyRushLastSolo = new.LastSolo
	runner.Coins = coins
	runner.Note = note
	if coins > 0 then
		DataService.Add(player, "Coins", coins)
		pcall(ShopService.Push, player)
	end
end

endRace = function(station: Station, race: Race, winner: Runner?, reason: string)
	if not isCurrent(station, race) then
		return
	end
	local now = os.clock()
	station.Phase = "Results"
	station.ResultsUntil = now + cfg.ResultsSeconds
	race.Winner = winner
	race.Reason = reason
	for _, runner in race.Order do
		if runner.Candy then
			runner.Candy:Destroy()
			runner.Candy = nil
		end
	end
	if winner and winner.Time then
		local best = station.Record
		if not best or winner.Time < best.Time then
			station.Record = { Name = winner.Name, Time = math.floor(winner.Time * 10 + 0.5) / 10 }
		end
	end
	for _, runner in race.Order do
		if runner.Player.Parent == Players then
			local ok, err = pcall(giveReward, race, runner)
			if not ok then
				warn("[CandyRush] Couldn't give the race reward: " .. tostring(err))
			end
		end
		if runner.Popped == 0 then
			-- Didn't play (away from the keyboard?): no new race until they step off the pad.
			station.Benched[runner.Player] = true
		end
	end
	refresh(station)
end

checkEnd = function(station: Station, race: Race)
	if not isCurrent(station, race) then
		return
	end
	local list: { Rules.RunnerInfo<Runner> } = {}
	for _, runner in race.Order do
		table.insert(list, { Key = runner, Popped = runner.Popped, Out = runner.Out })
	end
	local winner, reason = Rules.Decide(list, race.Total, race.Solo, os.clock() >= race.EndsAt)
	if reason ~= "Running" then
		endRace(station, race, winner, reason)
	end
end

local function startCountdown(station: Station, solo: boolean, now: number)
	station.Phase = "Countdown"
	station.CountdownSolo = solo
	station.CountdownEnds = now + cfg.CountdownSeconds
	station.Count = math.max(1, math.ceil(cfg.CountdownSeconds))
	station.ForceSolo = nil
end

local function startRace(station: Station, now: number)
	nextToken += 1
	local serverNow = workspace:GetServerTimeNow()
	local race: Race = {
		Token = nextToken,
		Solo = false,
		Total = math.max(1, math.floor(cfg.Candies)),
		StartedAt = now,
		EndsAt = now + cfg.MaxRaceSeconds,
		ServerStart = serverNow,
		ServerEnds = serverNow + cfg.MaxRaceSeconds,
		Runners = {},
		Order = {},
	}
	for lane = 1, station.LaneCount do
		local player = station.Lanes[lane]
		if player then
			local runner: Runner = {
				Player = player,
				Name = player.DisplayName,
				Lane = lane,
				Popped = 0,
				Out = false,
				ShownAt = now,
				LastOnPad = now,
			}
			race.Runners[player] = runner
			table.insert(race.Order, runner)
		end
	end
	race.Solo = #race.Order == 1
	if race.Solo then
		local data = DataService.Get(race.Order[1].Player)
		local saved = data and data.Minigames
		if type(saved) == "table" and num(saved.CandyRushBest) > 0 then
			race.Order[1].Best = num(saved.CandyRushBest)
		end
	end
	station.Lanes = {} -- the runners hold their pads in the race now
	station.Race = race
	station.Phase = "Live"
	station.Count = nil
	station.GoUntil = now + GO_SECONDS
	for _, runner in race.Order do
		spawnCandy(station, race, runner)
	end
	refresh(station)
end

-- Stations ----------------------------------------------------------------------------------------

local function newStation(model: Instance): Station
	local existing = model:FindFirstChild("Candies")
	if existing then
		existing:Destroy() -- left over from an earlier run (e.g. a hub saved while playing)
	end
	local old = model:FindFirstChild("LaneScreen")
	if old then
		old:Destroy()
	end
	local candies = Instance.new("Folder")
	candies.Name = "Candies"
	candies.Parent = model
	return {
		Model = model,
		Board = nil,
		Pads = {},
		LaneCount = 0,
		Phase = "Waiting",
		Lanes = {},
		LastOnPad = {},
		Benched = {},
		Watchers = {},
		AloneSince = nil,
		CountdownEnds = 0,
		CountdownSolo = false,
		Count = nil,
		GoUntil = 0,
		ResultsUntil = 0,
		Race = nil,
		ForceSolo = nil,
		ForceUntil = 0,
		Record = nil,
		Candies = candies,
		Screen = nil,
		Signature = "",
		Warned = false,
		PartsAt = -math.huge,
	}
end

-- A stand that was removed (e.g. the hub was rebuilt): its race just stops.
local function removeStation(station: Station)
	stations[station.Model] = nil
	station.Race = nil
	station.Phase = "Waiting"
	if station.Candies.Parent then
		station.Candies:Destroy()
	end
	if station.Screen then
		station.Screen.Part:Destroy()
	end
	local remote = stateRemote
	if remote then
		for player in station.Watchers do
			if player.Parent == Players then
				remote:FireClient(player, nil)
			end
		end
	end
	station.Watchers = {}
end

local stationList: { Station } = {}
local stationsAt = -math.huge

-- Every stand in Workspace (new ones are set up, removed ones stopped). Looked up again
-- every RESCAN_SECONDS, or straight away with `now = true`.
local function currentStations(now: boolean?): { Station }
	if not now and os.clock() - stationsAt < RESCAN_SECONDS then
		local alive = true
		for _, station in stationList do
			if not station.Model:IsDescendantOf(workspace) then
				alive = false
				break
			end
		end
		if alive then
			return stationList
		end
	end
	stationsAt = os.clock()
	local seen: { [Instance]: boolean } = {}
	local list: { Station } = {}
	for _, model in CollectionService:GetTagged(Tags.CandyRushStation) do
		if model:IsDescendantOf(workspace) then
			seen[model] = true
			local station = stations[model]
			if not station then
				station = newStation(model)
				stations[model] = station
			end
			table.insert(list, station)
		end
	end
	for model, station in stations do
		if not seen[model] then
			removeStation(station)
		end
	end
	table.sort(list, function(a, b)
		return a.Model:GetFullName() < b.Model:GetFullName()
	end)
	stationList = list
	return list
end

type LobbyPlayer = { Player: Player, Position: Vector3 }

-- One check of one stand: who stands where, countdowns, knock-outs, the end of a race.
local function step(
	station: Station,
	now: number,
	lobby: { LobbyPlayer },
	claimed: { [Player]: Station }
)
	if now - station.PartsAt >= RESCAN_SECONDS then
		station.PartsAt = now
		refreshParts(station)
	end
	local race = station.Race
	local racingLanes: { [number]: boolean } = {}
	if race and station.Phase == "Live" then
		for _, runner in race.Order do
			if not runner.Out then
				racingLanes[runner.Lane] = true
			end
		end
	end

	local standing: { Rules.Standing<Player> } = {}
	for _, entry in lobby do
		local player = entry.Player
		if claimed[player] and claimed[player] ~= station then
			continue
		end
		local lanes = lanesUnder(station, entry.Position)
		local runner = race and race.Runners[player]
		if runner then
			if not runner.Out and table.find(lanes, runner.Lane) then
				runner.LastOnPad = now
			end
			claimed[player] = station
			continue
		end
		if #lanes == 0 then
			station.Benched[player] = nil -- stepped off: can join the next race
			continue
		end
		if station.Benched[player] then
			continue
		end
		station.LastOnPad[player] = now
		table.insert(standing, { Key = player, Lanes = lanes })
	end

	local keep: { [Player]: boolean } = {}
	for _, player in station.Lanes do
		local last = station.LastOnPad[player]
		if last and now - last <= cfg.LeaveGraceSeconds and player.Parent == Players then
			keep[player] = true
		end
	end
	station.Lanes = Rules.AssignLanes(station.Lanes, standing, station.LaneCount, keep, racingLanes)
	for player, last in station.LastOnPad do
		if now - last > cfg.LeaveGraceSeconds and not laneOf(station, player) then
			station.LastOnPad[player] = nil
		end
	end
	for _, player in station.Lanes do
		claimed[player] = station
	end

	local waiting = count(station.Lanes)
	local need = math.max(2, cfg.MinPlayers)
	local forced = station.ForceSolo
	if forced and (forced.Parent ~= Players or now > station.ForceUntil) then
		station.ForceSolo = nil
		forced = nil
	end

	if station.Phase == "Live" and race then
		for _, runner in race.Order do
			if
				not runner.Out
				and (
					runner.Player.Parent ~= Players
					or now - runner.LastOnPad > cfg.LeaveGraceSeconds
				)
			then
				knockOut(station, race, runner)
			end
		end
		checkEnd(station, race)
	elseif station.Phase == "Results" then
		if now >= station.ResultsUntil then
			station.Phase = "Waiting"
			station.Race = nil
			station.AloneSince = nil
		end
	elseif station.Phase == "Waiting" then
		if waiting == 1 then
			station.AloneSince = station.AloneSince or now
		else
			station.AloneSince = nil
		end
		local alone = station.AloneSince
		if station.LaneCount > 0 and station.Board then
			if waiting >= need then
				startCountdown(station, false, now)
			elseif
				waiting == 1
				and (
					(forced and laneOf(station, forced) ~= nil)
					or (cfg.Solo.On and alone and now - alone >= cfg.Solo.AfterSeconds)
				)
			then
				startCountdown(station, true, now)
			end
		end
	elseif station.Phase == "Countdown" then
		if waiting == 0 then
			station.Phase = "Waiting"
			station.Count = nil
		elseif not station.CountdownSolo and waiting < need then
			station.Phase = "Waiting"
			station.Count = nil
			station.AloneSince = now -- the one left waits for a solo run like anyone else
		elseif station.CountdownSolo and waiting >= need then
			startCountdown(station, false, now)
		else
			local remaining = station.CountdownEnds - now
			if remaining <= 0 then
				startRace(station, now)
				return
			end
			station.Count = math.ceil(remaining)
		end
	end

	if signature(station, now) ~= station.Signature then
		refresh(station)
	end
end

local function tick()
	local now = os.clock()
	local lobby: { LobbyPlayer } = {}
	for _, player in Players:GetPlayers() do
		local root = lobbyRoot(player)
		if root then
			table.insert(lobby, { Player = player, Position = root.Position })
		end
	end
	local claimed: { [Player]: Station } = {}
	for _, station in currentStations() do
		local ok, err = pcall(function()
			step(station, now, lobby, claimed)
		end)
		if not ok then
			warn("[CandyRush] " .. tostring(err))
		end
	end
end

local function onPlayerRemoving(player: Player)
	for _, station in stations do
		local lane = laneOf(station, player)
		if lane then
			station.Lanes[lane] = nil
		end
		station.LastOnPad[player] = nil
		station.Benched[player] = nil
		station.Watchers[player] = nil
		if station.ForceSolo == player then
			station.ForceSolo = nil
		end
		local race = station.Race
		local runner = race and race.Runners[player]
		if race and runner and isCurrent(station, race) then
			knockOut(station, race, runner)
		end
	end
end

-- Admin test ----------------------------------------------------------------------------------------

-- How far a pad reaches above its middle (whichever way it is turned).
local function halfHeight(box: Box): number
	local cf, size = box.CFrame, box.Size
	return (
		math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
	) / 2
end

function CandyRushService.StartSolo(player: Player): (boolean, string)
	if not Config.Features.CandyRush then
		return false, "Candy Rush is switched off (Config.Features.CandyRush)."
	end
	if player:GetAttribute("InRound") == true then
		return false, "You're in a round: try again in the lobby."
	end
	local character = player.Character
	if not lobbyRoot(player) or not character then
		return false, "You need a character in the lobby."
	end
	local list = currentStations(true)
	if #list == 0 then
		return false, "There is no Candy Rush stand (tag CandyRushStation) in Workspace."
	end
	for _, station in list do
		refreshParts(station)
		if station.Phase ~= "Waiting" or not station.Board then
			continue
		end
		local lane = laneOf(station, player)
		if not lane then
			for l = 1, station.LaneCount do
				if station.Pads[l] and not station.Lanes[l] then
					lane = l
					break
				end
			end
		end
		local pad = lane and station.Pads[lane]
		local box = pad and boxOf(pad)
		local face = faceOf(station)
		if lane and box and face then
			local top = box.CFrame.Position + Vector3.new(0, halfHeight(box) + 3, 0)
			local look = face.View.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude < 1e-3 then
				look = Vector3.new(0, 0, -1)
			end
			character:PivotTo(CFrame.lookAt(top, top + look.Unit))
			station.Benched[player] = nil
			station.ForceSolo = player
			station.ForceUntil = os.clock() + 5
			return true, ("On pad %d: a solo Candy Rush starts in a moment."):format(lane)
		end
	end
	return false, "Every stand is busy with a race right now: try again in a few seconds."
end

-- A saved hub with no stand (baked while Candy Rush was off, or the stand was deleted) gets one
-- for this server.
local function ensureStand()
	for _, instance in CollectionService:GetTagged(Tags.CandyRushStation) do
		if instance:IsDescendantOf(workspace) then
			return
		end
	end
	local hub = workspace:FindFirstChild("Hub")
	if not (hub and hub:IsA("Model")) then
		return
	end
	if HubBuilder.RepairSection(hub, "CandyRush") then
		warn(
			"[CandyRushService] The lobby had no Candy Rush stand (tag CandyRushStation), so it was built for this server. To keep it, F8 > Rebuild hub or run require(game.ServerScriptService.Server.Tools.Bake).Hub() in edit mode, then save."
		)
	end
end

-- A click or tap the player's screen spotted itself (CandyRushUI aims only at your own candy,
-- so your own character can't block it). The same checks as the click detectors.
local function onGrab(player: Player, candy: unknown)
	if typeof(candy) ~= "Instance" or not candy:IsA("Model") then
		return
	end
	for _, station in stations do
		local race = station.Race
		local runner = race and race.Runners[player]
		if race and runner and runner.Candy == candy then
			onClick(station, race, runner, candy, player)
			return
		end
	end
end

function CandyRushService.Start()
	-- Created even when Candy Rush is off, so a client never waits for them.
	stateRemote = Remotes.Event("CandyRushState")
	local grabRemote = Remotes.Event("CandyRushGrab")
	if not Config.Features.CandyRush then
		return -- (HubService takes the stand out of the running game)
	end
	grabRemote.OnServerEvent:Connect(onGrab)
	local ok, err = pcall(ensureStand :: any)
	if not ok then
		warn("[CandyRushService] Couldn't build the Candy Rush stand: " .. tostring(err))
	end
	AdminService.Register("CandyRushSolo", "Candy Rush: start solo test", function(player, _data)
		local _, message = CandyRushService.StartSolo(player)
		return message
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	task.spawn(function()
		while true do
			tick()
			task.wait(cfg.CheckSeconds)
		end
	end)
end

return CandyRushService
