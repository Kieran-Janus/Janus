--!strict
--[[
	CRUMBLING CRYPT (mode id TileFall): a "falling tiles" party game. Everyone stands on stone
	slabs (2 or 3 layers with gaps between them) over a pit of glowing goo. A slab you step on
	cracks and drops CrumbleSeconds later, for good. Fall through every layer into the goo and
	you're out (a ghost, GhostService). The last one standing wins; alone, survive as long as
	you can.
	On/off: Config.Features.TileFall (off = the vote never offers it). Settings:
	Config.TileFall (src/shared/Config/TileFall.luau). Map: src/server/Maps/CrumblingCrypt.luau
	(slabs: src/server/Modes/TileFallBoard.luau). Screen: src/client/TileFallUI.luau.

	The round:
	  1. The slabs: a map built from code is built for Easy; a Hard round rebuilds them with
	     Hard's Layers and TileSize. A baked map (BakedFrom attribute) is played as it is.
	     Slabs are the parts tagged TileFallTile, the goo is the part tagged TileFallGoo (else
	     the map's Floor).
	  2. "Get ready" (IntroSeconds): everyone stands still on their start spot.
	  3. "Playing" (the difficulty's Duration): every SampleSeconds the server looks up the
	     slab under each player still in (a grid lookup from their position, no raycasts). After
	     GraceSeconds a slab someone stands on starts cracking (TileState "Cracking", crack
	     colour) and drops CrumbleSeconds later (TileState "Gone": no collision, invisible) for
	     the rest of the round. After SuddenDeathAfter seconds random slabs crack by themselves.
	     Out (a ghost, watching): below the goo's top + OutHeight, dead or reset (no free
	     respawn), further than BoundsMargin past the slabs or MaxHeightAbove over them, or with
	     no slab under you for MaxAirSeconds (hovering). Moving faster than anyone can run (a
	     teleport or fly cheat, src/shared/SpeedCheck.luau) puts you back where you were.
	  4. Ends when nobody is left, when only LastStanding are left (2+ players and
	     EndWhenOneLeft), or at 0:00. Then the winners have CelebrateSeconds on the map.
	Score = seconds stayed up. Place 1 = the last standing (still up at 0:00 = shared 1st).
	Solo: Top (a Win) only for staying up until 0:00.

	Attributes: player TileFallState ("In", "Out", "Winner" during the celebration);
	ReplicatedStorage Alive (players still in), TileFallSolo, TileFallSuddenDeath; each slab
	TileState and CrumbleAt (server time it drops). No remotes: the screen reads attributes.
	Owner test: the F8 panel's "Crumbling Crypt: force next round" (GameService).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SpeedCheck = require(ReplicatedStorage.Shared.SpeedCheck)
local Tags = require(ReplicatedStorage.Shared.Tags)
local TileFallBoard = require(script.Parent.TileFallBoard)
local Types = require(script.Parent.Types)
local Services = script.Parent.Parent.Services
local GhostService = require(Services.GhostService)
local MapService = require(Services.MapService)
local SprintService = require(Services.SprintService)

local TileFall = {}

TileFall.Attributes = {
	State = "TileFallState", -- player: "In", "Out" or "Winner"
	Solo = "TileFallSolo", -- ReplicatedStorage: true when one player started
	SuddenDeath = "TileFallSuddenDeath", -- ReplicatedStorage: true once sudden death started
	TileState = "TileState", -- slab: "Cracking" or "Gone" (nil = solid)
	CrumbleAt = "CrumbleAt", -- slab: server time it drops
}
local ATTR = TileFall.Attributes

local CELL = 4 -- studs: the size of one square of the slab lookup grid
local FOOT = 0.8 -- studs: you're on a slab if your middle is this close to its edge
local IN, OUT, LEFT = "In", "Out", "Left"

type Tile = {
	Part: BasePart,
	Layer: number,
	Top: number, -- the height of its top surface
	State: string, -- "Solid", "Cracking" or "Gone"
	CrumbleAt: number,
}

type Runner = {
	Speed: SpeedCheck.Check,
	AirSince: number?, -- since when there's been no slab under them
}

type Round = {
	Ctx: Types.RoundContext,
	Participants: { Player },
	State: { [Player]: string }, -- In, Out or Left
	Runners: { [Player]: Runner }, -- players still in
	OutAfter: { [Player]: number }, -- seconds they stayed up (players who are out)
	Tiles: { Tile },
	Grid: { [number]: { Tile } },
	Cracking: { [Tile]: boolean },
	GooY: number,
	TopY: number, -- the top of the highest slab
	Min: Vector2, -- the slabs' corners (x, z), for the bounds check
	Max: Vector2,
	Level: any, -- Config.TileFall.Difficulty[...]
	Solo: boolean,
	StartedAt: number, -- server time of GO! (math.huge before)
	EndedAt: number?,
	CrackFrom: number, -- nothing cracks before this
	SuddenAt: number, -- sudden death starts
	NextSudden: number,
	SuddenRounds: number,
	Threads: { thread },
	Connections: { RBXScriptConnection },
	Active: boolean, -- "Playing" is on
	Rng: Random,
}

local round: Round? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function track(r: Round, thread: thread)
	for i = #r.Threads, 1, -1 do
		if coroutine.status(r.Threads[i]) == "dead" then
			table.remove(r.Threads, i)
		end
	end
	table.insert(r.Threads, thread)
end

-- The difficulty's settings (Easy if the id is unknown).
local function levelOf(id: string): any
	local levels = Config.TileFall.Difficulty :: any
	return levels[id] or levels[Config.Difficulty.Default] or levels.Easy
end

local function speedLimits(): SpeedCheck.Limits
	local cfg = Config.TileFall
	return {
		MaxSpeed = cfg.MaxMoveSpeed,
		Slack = cfg.SlackStuds,
		MaxRiseSpeed = cfg.MaxRiseSpeed,
		RiseSlack = cfg.RiseSlack,
		WindowSeconds = cfg.SpeedWindowSeconds,
	}
end

local function stillIn(r: Round): number
	local n = 0
	for _, state in r.State do
		if state == IN then
			n += 1
		end
	end
	return n
end

local function countAlive(r: Round)
	ReplicatedStorage:SetAttribute("Alive", stillIn(r))
end

-- The slabs ----------------------------------------------------------------------------------

local function gridKey(cx: number, cz: number): number
	return (cx + 50000) * 100000 + (cz + 50000)
end

-- A Hard round on a map built from code gets Hard's layers and slab size.
local function prepareBoard(map: MapService.LoadedMap, level: any)
	local folder = map.Model:FindFirstChild(TileFallBoard.FolderName)
	if
		not folder
		or folder:GetAttribute("BoardBuilt") ~= true
		or map.Model:GetAttribute("BakedFrom") ~= nil
	then
		return
	end
	if
		folder:GetAttribute("Layers") == level.Layers
		and folder:GetAttribute("TileSize") == level.TileSize
	then
		return
	end
	local def = MapService.Get(map.Id)
	local gooTop = folder:GetAttribute("GooTop")
	if not (def and type(def.Board) == "table" and typeof(gooTop) == "Vector3") then
		return
	end
	local parent = folder.Parent or map.Model
	folder:Destroy()
	TileFallBoard.Build(parent, gooTop, def.Board, level.Layers, level.TileSize, def.Colors)
end

-- Finds the slabs and the goo in the map and fills the lookup grid.
local function loadBoard(r: Round, map: MapService.LoadedMap)
	local goo: BasePart = map.Floor
	for _, tagged in CollectionService:GetTagged(Tags.TileFallGoo) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(map.Model) then
			goo = tagged
			break
		end
	end
	r.GooY = goo.Position.Y + goo.Size.Y / 2
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	local topY = -math.huge
	for _, tagged in CollectionService:GetTagged(Tags.TileFallTile) do
		if not (tagged:IsA("BasePart") and tagged:IsDescendantOf(map.Model)) then
			continue
		end
		local part = tagged :: BasePart
		local layer = part:GetAttribute("Layer")
		local tile: Tile = {
			Part = part,
			Layer = if typeof(layer) == "number" then layer else 1,
			Top = part.Position.Y + part.Size.Y / 2,
			State = "Solid",
			CrumbleAt = 0,
		}
		table.insert(r.Tiles, tile)
		topY = math.max(topY, tile.Top)
		-- Into every grid square its footprint (turned any way) can touch.
		local reach = math.sqrt(part.Size.X ^ 2 + part.Size.Z ^ 2) / 2 + FOOT
		local p = part.Position
		minX, maxX = math.min(minX, p.X - reach), math.max(maxX, p.X + reach)
		minZ, maxZ = math.min(minZ, p.Z - reach), math.max(maxZ, p.Z + reach)
		for cx = math.floor((p.X - reach) / CELL), math.floor((p.X + reach) / CELL) do
			for cz = math.floor((p.Z - reach) / CELL), math.floor((p.Z + reach) / CELL) do
				local key = gridKey(cx, cz)
				local list = r.Grid[key]
				if not list then
					list = {}
					r.Grid[key] = list
				end
				table.insert(list, tile)
			end
		end
	end
	if #r.Tiles == 0 then
		warn("[TileFall] The map has no part tagged TileFallTile: there is nothing to stand on.")
		local f = map.Floor
		minX, maxX = f.Position.X - f.Size.X / 2, f.Position.X + f.Size.X / 2
		minZ, maxZ = f.Position.Z - f.Size.Z / 2, f.Position.Z + f.Size.Z / 2
		topY = r.GooY
	end
	r.TopY = topY
	r.Min = Vector2.new(minX, minZ)
	r.Max = Vector2.new(maxX, maxZ)
end

-- The slabs right under `position` (the highest layer within reach; several when standing on
-- a seam). Gone slabs don't count.
local function under(r: Round, position: Vector3): { Tile }
	local list = r.Grid[gridKey(math.floor(position.X / CELL), math.floor(position.Z / CELL))]
	local found: { Tile } = {}
	if not list then
		return found
	end
	local reach: number = Config.TileFall.StandReach
	local best = -math.huge
	for _, tile in list do
		if
			tile.State == "Gone"
			or tile.Top > position.Y + 1
			or tile.Top < position.Y - reach
			or tile.Top < best - 0.5
		then
			continue
		end
		local part = tile.Part
		local loc = part.CFrame:PointToObjectSpace(position)
		if
			math.abs(loc.X) <= part.Size.X / 2 + FOOT
			and math.abs(loc.Z) <= part.Size.Z / 2 + FOOT
		then
			if tile.Top > best + 0.5 then
				table.clear(found)
				best = tile.Top
			end
			table.insert(found, tile)
		end
	end
	return found
end

local function crack(r: Round, tile: Tile, t: number)
	if tile.State ~= "Solid" then
		return
	end
	local cfg = Config.TileFall
	tile.State = "Cracking"
	tile.CrumbleAt = t + r.Level.CrumbleSeconds
	r.Cracking[tile] = true
	local part = tile.Part
	part:SetAttribute(ATTR.CrumbleAt, tile.CrumbleAt)
	part:SetAttribute(ATTR.TileState, "Cracking")
	part.Color = cfg.CrackColor
	part.Material = cfg.CrackMaterial
end

local function drop(r: Round, tile: Tile)
	if tile.State == "Gone" then
		return
	end
	tile.State = "Gone"
	r.Cracking[tile] = nil
	local part = tile.Part
	part:SetAttribute(ATTR.TileState, "Gone")
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
end

-- Sudden death: a few random solid slabs crack by themselves.
local function suddenDeath(r: Round, t: number)
	local sd = Config.TileFall.SuddenDeath
	if not sd.On or t < r.SuddenAt or t < r.NextSudden then
		return
	end
	if r.SuddenRounds == 0 then
		ReplicatedStorage:SetAttribute(ATTR.SuddenDeath, true)
	end
	local solid: { Tile } = {}
	for _, tile in r.Tiles do
		if tile.State == "Solid" then
			table.insert(solid, tile)
		end
	end
	local count = math.min(sd.Tiles + sd.Grow * r.SuddenRounds, sd.MaxTiles, #solid)
	for _ = 1, count do
		local i = r.Rng:NextInteger(1, #solid)
		crack(r, solid[i], t)
		solid[i] = solid[#solid]
		solid[#solid] = nil
	end
	r.SuddenRounds += 1
	r.NextSudden = t + math.max(sd.Every, 0.2)
end

-- Out ---------------------------------------------------------------------------------------

-- A player is out: `reason` = "Fell", "Died", "Bounds", "Floating" (their ghost goes on the
-- slabs to watch) or "Left" (left the game).
local function knockOut(r: Round, player: Player, reason: string)
	if r.State[player] ~= IN then
		return
	end
	r.Runners[player] = nil
	r.State[player] = if reason == "Left" then LEFT else OUT
	r.OutAfter[player] = math.max(0, now() - r.StartedAt)
	countAlive(r)
	if reason == "Left" then
		return
	end
	player:SetAttribute(ATTR.State, OUT)
	-- Not "in place": the ghost comes back up to the slabs to watch.
	GhostService.MarkOut(player, false)
end

-- One check of everyone still in: anti-cheat, out, and the slab under them.
local function sample(r: Round)
	local cfg = Config.TileFall
	local t = now()
	for tile in r.Cracking do
		if t >= tile.CrumbleAt then
			drop(r, tile)
		end
	end
	suddenDeath(r, t)
	local limits = speedLimits()
	for player, runner in r.Runners do
		local root = aliveRoot(player)
		if not root then
			continue
		end
		local position = root.Position
		if SpeedCheck.Step(runner.Speed, position, t, limits) then
			-- Moved impossibly fast (a teleport or fly cheat): back to the last good spot.
			local back = runner.Speed.Last
			local character = player.Character
			if back and character then
				character:PivotTo(character:GetPivot() + (back - position))
				position = back
			end
			SpeedCheck.Reset(runner.Speed, back, t)
		end
		if position.Y < r.GooY + cfg.OutHeight then
			knockOut(r, player, "Fell")
			continue
		end
		local margin = cfg.BoundsMargin
		if
			position.X < r.Min.X - margin
			or position.X > r.Max.X + margin
			or position.Z < r.Min.Y - margin
			or position.Z > r.Max.Y + margin
			or position.Y > r.TopY + cfg.MaxHeightAbove
		then
			knockOut(r, player, "Bounds")
			continue
		end
		local tiles = under(r, position)
		if #tiles > 0 then
			runner.AirSince = nil
			if t >= r.CrackFrom then
				for _, tile in tiles do
					crack(r, tile, t)
				end
			end
		else
			local since = runner.AirSince or t
			runner.AirSince = since
			if t - since >= cfg.MaxAirSeconds then
				knockOut(r, player, "Floating")
			end
		end
	end
end

-- The round -----------------------------------------------------------------------------------

-- Stops everything a round runs and clears what it set. Safe to call any time.
function TileFall.Cleanup()
	local r = round
	round = nil
	ReplicatedStorage:SetAttribute("Alive", nil)
	ReplicatedStorage:SetAttribute(ATTR.Solo, nil)
	ReplicatedStorage:SetAttribute(ATTR.SuddenDeath, nil)
	if not r then
		return
	end
	r.Active = false
	local current = coroutine.running()
	for _, thread in r.Threads do
		if thread ~= current and coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
	end
	table.clear(r.Threads)
	for _, connection in r.Connections do
		connection:Disconnect()
	end
	table.clear(r.Connections)
	for _, player in r.Participants do
		player:SetAttribute(ATTR.State, nil)
	end
	table.clear(r.Runners)
	table.clear(r.Cracking)
end

local function ordinal(n: number): string
	local last2 = n % 100
	local suffix = if last2 >= 11 and last2 <= 13
		then "th"
		elseif n % 10 == 1 then "st"
		elseif n % 10 == 2 then "nd"
		elseif n % 10 == 3 then "rd"
		else "th"
	return tostring(n) .. suffix
end

-- How long each participant stayed up (math.huge = still up at the end) and their place.
local function standings(r: Round): ({ [Player]: number }, { [Player]: number })
	local up: { [Player]: number } = {}
	for _, player in r.Participants do
		local state = r.State[player]
		if state == IN then
			up[player] = math.huge
		elseif state == OUT then
			up[player] = r.OutAfter[player] or 0
		end
	end
	local place: { [Player]: number } = {}
	for player, mine in up do
		local better = 0
		for other, theirs in up do
			if other ~= player and theirs > mine then
				better += 1
			end
		end
		place[player] = better + 1
	end
	return up, place
end

local function result(r: Round): Types.RoundResult
	local cfg = Config.TileFall
	local text = cfg.Text
	local rewards = cfg.Rewards
	local up, place = standings(r)
	local ended = r.EndedAt or now()
	local length = math.max(0, ended - r.StartedAt)
	local rows: { Types.ResultRow } = {}
	local rank: { [Types.ResultRow]: number } = {}
	local standing = 0
	for _, state in r.State do
		if state == IN then
			standing += 1
		end
	end
	local multiplier = r.Level.RewardMultiplier or 1
	for _, player in r.Participants do
		if player.Parent ~= Players or up[player] == nil then
			continue
		end
		local isUp = r.State[player] == IN
		local seconds = math.floor(if isUp then length else up[player])
		local myPlace = place[player]
		local top = if r.Solo then isUp else myPlace == 1
		local coins = rewards.PlayCoins
			+ math.min(rewards.MaxTimeCoins, (seconds // 10) * rewards.CoinsPer10Seconds)
		if r.Solo then
			if isUp then
				coins += rewards.SoloSurviveCoins
			end
		else
			coins += rewards.PlaceCoins[myPlace] or 0
		end
		local row: Types.ResultRow = {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = seconds,
			Pumpkins = seconds,
			Coins = math.floor(coins * multiplier + 0.5),
			Survived = isUp,
			Top = top,
			Badge = if top
					and not r.Solo
					and standing <= 1
				then text.BadgeWinner
				elseif isUp then text.BadgeStanding
				else text.BadgeFell,
			Stat = if r.Solo then nil else text.StatPlace:format(ordinal(myPlace)),
		}
		rank[row] = myPlace
		table.insert(rows, row)
	end
	-- Best place first (the results screen shows rows in this order).
	table.sort(rows, function(a, b)
		if rank[a] ~= rank[b] then
			return rank[a] < rank[b]
		end
		return a.Score > b.Score
	end)
	local winner: string
	if r.Solo then
		local row = rows[1]
		winner = if row and row.Survived
			then text.SoloSurvived
			else text.SoloFell:format(if row then row.Score else 0)
	else
		local tops: { Types.ResultRow } = {}
		for _, row in rows do
			if row.Top then
				table.insert(tops, row)
			end
		end
		winner = if #tops == 1
			then text.WinnerOne:format(tops[1].Name)
			elseif standing > 1 then text.WinnerMany:format(standing)
			else text.WinnerNobody
	end
	return {
		Rows = rows,
		ScoreLabel = text.ScoreLabel,
		Winner = winner,
		MvpLine = text.MvpLine,
	}
end

function TileFall.Run(ctx: Types.RoundContext): Types.RoundResult
	TileFall.Cleanup()
	local cfg = Config.TileFall
	local level = levelOf(ctx.Difficulty)
	local map = ctx.Map
	prepareBoard(map, level)
	local r: Round = {
		Ctx = ctx,
		Participants = table.clone(ctx.Players),
		State = {},
		Runners = {},
		OutAfter = {},
		Tiles = {},
		Grid = {},
		Cracking = {},
		GooY = 0,
		TopY = 0,
		Min = Vector2.zero,
		Max = Vector2.zero,
		Level = level,
		Solo = false,
		StartedAt = math.huge,
		EndedAt = nil,
		CrackFrom = math.huge,
		SuddenAt = math.huge,
		NextSudden = 0,
		SuddenRounds = 0,
		Threads = {},
		Connections = {},
		Active = false,
		Rng = Random.new(),
	}
	round = r
	loadBoard(r, map)

	-- Who plays: everyone with a living character; anyone else just watches.
	local playing: { Player } = {}
	for _, player in r.Participants do
		if ctx.AliveHumanoid(player) then
			table.insert(playing, player)
		end
	end
	r.Solo = #playing == 1
	ReplicatedStorage:SetAttribute(ATTR.Solo, r.Solo)
	local spawns = map.Spawns
	local t0 = now()
	for i, player in playing do
		r.State[player] = IN
		player:SetAttribute(ATTR.State, IN)
		local runner: Runner = { Speed = SpeedCheck.new(), AirSince = nil }
		r.Runners[player] = runner
		if #spawns > 0 then
			ctx.Teleport(player, spawns[(i - 1) % #spawns + 1])
			local character = player.Character
			if character and i > #spawns then
				-- More players than spots: spread out a little.
				local angle = r.Rng:NextNumber(0, math.pi * 2)
				character:PivotTo(
					character:GetPivot() + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.5
				)
			end
		end
		local root = aliveRoot(player)
		-- The anti-cheat measures from the start spot (the server put them there).
		SpeedCheck.Reset(runner.Speed, if root then root.Position else nil, t0)
	end
	for _, player in r.Participants do
		if not r.State[player] then
			r.State[player] = OUT
			r.OutAfter[player] = 0
			player:SetAttribute(ATTR.State, OUT)
			GhostService.MarkOut(player, false)
		end
	end
	countAlive(r)

	-- Dying (or resetting) = out, leaving = gone.
	local function watchCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if round ~= r or not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		table.insert(
			r.Connections,
			humanoid.Died:Connect(function()
				knockOut(r, player, "Died")
			end)
		)
	end
	for _, player in r.Participants do
		if player.Character then
			track(r, task.spawn(watchCharacter, player, player.Character))
		end
		table.insert(
			r.Connections,
			player.CharacterAdded:Connect(function(character)
				-- A new body while still in (respawned without dying): that counts as out too,
				-- so nobody gets a free trip back onto solid slabs.
				knockOut(r, player, "Died")
				track(r, task.spawn(watchCharacter, player, character))
			end)
		)
	end
	table.insert(
		r.Connections,
		Players.PlayerRemoving:Connect(function(player)
			knockOut(r, player, "Left")
		end)
	)

	-- Get ready: everyone waits on their spot.
	for _, player in playing do
		SprintService.Slow(player, 0, cfg.IntroSeconds)
	end
	ctx.Countdown("Get ready", cfg.IntroSeconds)

	-- GO!
	local start = now()
	r.StartedAt = start
	r.CrackFrom = start + level.GraceSeconds
	r.SuddenAt = start + level.SuddenDeathAfter
	r.NextSudden = r.SuddenAt
	r.Active = true
	for _, runner in r.Runners do
		-- Still measured from the start spot: a cheat that moved them during "Get ready" is
		-- caught on the first check.
		SpeedCheck.Reset(runner.Speed, runner.Speed.Last, start)
	end
	track(
		r,
		task.spawn(function()
			while round == r and r.Active do
				local ok, err = pcall(sample, r)
				if not ok then
					warn("[TileFall] Position check failed: " .. tostring(err))
				end
				task.wait(cfg.SampleSeconds)
			end
		end)
	)
	ctx.Countdown("Playing", level.Duration, function()
		local left = stillIn(r)
		if left == 0 then
			return true
		end
		return not r.Solo and cfg.EndWhenOneLeft and left <= cfg.LastStanding
	end)

	-- The end: the winners get a moment on the map.
	r.Active = false
	r.EndedAt = now()
	ctx.SetState("Playing", 0)
	local winners = 0
	for player, state in r.State do
		if state == IN then
			winners += 1
			player:SetAttribute(ATTR.State, "Winner")
		end
	end
	if winners > 0 and cfg.CelebrateSeconds > 0 then
		task.wait(cfg.CelebrateSeconds)
	end
	local final = result(r)
	TileFall.Cleanup()
	return final
end

return TileFall
