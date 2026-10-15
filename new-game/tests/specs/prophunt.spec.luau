-- Prop Hunt: the rules (src/server/Modes/PropHuntRules.luau), The Haunted House map, whole
-- rounds of src/server/Modes/PropHunt.luau with fake players (roles, starting as a thing,
-- turning into things, lock, taunt, the pumpkin head, the cannon's server checks, finding,
-- leaving, respawning, results) and the screen (src/client/PropHuntUI.luau).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

describe("Prop Hunt rules", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Rules = rt:require("ServerScriptService.Server.Modes.PropHuntRules")
	local cfg = Config.PropHunt

	it("has its settings, for Easy and Hard", function()
		for _, level in { "Easy", "Hard" } do
			local s = cfg.Difficulty[level]
			for _, key in
				{
					"HeadStart",
					"Duration",
					"PropChanges",
					"PropPenalty",
					"HitTolerance",
					"RewardMultiplier",
				}
			do
				expect(s[key]).toBeA("number")
			end
			expect(s.GiggleInterval).toBeGreaterThanOrEqual(0)
			expect(s.GlowLastSeconds).toBeGreaterThanOrEqual(0)
		end
		local easy, hard = cfg.Difficulty.Easy, cfg.Difficulty.Hard
		-- Easy really is easier: longer head start, more changes, hints, gentler penalty.
		expect(easy.HeadStart).toBeGreaterThan(hard.HeadStart)
		expect(easy.PropChanges).toBeGreaterThan(hard.PropChanges)
		expect(easy.GiggleInterval).toBeGreaterThan(0)
		expect(easy.GlowLastSeconds).toBeGreaterThan(0)
		expect(easy.HitTolerance).toBeGreaterThan(hard.HitTolerance)
		expect(easy.PropPenalty).toBeLessThan(hard.PropPenalty)
		expect(Rules.Settings(cfg, "Hard")).toBe(hard)
		expect(Rules.Settings(cfg, "Nope")).toBe(easy)
		for _, key in
			{ "PerFind", "HiderSurvived", "PerMinuteHidden", "PerTaunt", "WinningTeam", "Played" }
		do
			expect(cfg.Rewards[key]).toBeGreaterThanOrEqual(0)
		end
		for _, key in { "FireCooldown", "MaxRange", "ProjectileSpeed" } do
			expect(cfg.Cannon[key]).toBeGreaterThan(0)
		end
		for _, key in
			{ "HiderRole", "SeekerRole", "Counting", "ScoreLabel", "MvpLine", "FoundBy", "Decoy" }
		do
			expect(cfg.Text[key]).toBeA("string")
		end
		expect(Config.Modes.List.PropHunt.MinPlayers).toBe(2)
		expect(Config.Features.PropHunt).toBe(true)
	end)

	it("picks a quarter of the players as finders, at least one, never everyone", function()
		for players = 2, 24 do
			local finders = Rules.FinderCount(players, cfg)
			expect(finders).toBeGreaterThanOrEqual(1)
			expect(finders).toBeLessThan(players)
		end
		expect(Rules.FinderCount(8, cfg)).toBe(2)
		expect(Rules.FinderCount(1, cfg)).toBe(if cfg.SoloRole == "Hider" then 0 else 1)
	end)

	it("scores finds, taunts, hidden hiders and the winning side", function()
		local r = cfg.Rewards
		local entries = {
			{
				UserId = 1,
				Name = "Finder",
				StartRole = "Seeker",
				Finds = 2,
				Found = false,
				HiddenSeconds = 0,
				Taunts = 0,
			},
			{
				UserId = 2,
				Name = "Found",
				StartRole = "Hider",
				Finds = 0,
				Found = true,
				HiddenSeconds = 125,
				Taunts = 1,
			},
			{
				UserId = 3,
				Name = "Hidden",
				StartRole = "Hider",
				Finds = 0,
				Found = false,
				HiddenSeconds = 170,
				Taunts = 3,
			},
		}
		local rows = Rules.Results(entries, "Hiders", cfg, 1)
		expect(#rows).toBe(3)
		expect(rows[1].Name).toBe("Hidden") -- 3 taunts beat 2 finds
		expect(rows[1].Score).toBe(3 * cfg.Taunt.Points)
		expect(rows[1].Survived).toBe(true)
		expect(rows[1].Top).toBe(true)
		expect(rows[1].Coins).toBe(r.Played + 3 * r.PerTaunt + r.HiderSurvived + r.WinningTeam)
		expect(rows[1].Badge).toBe(cfg.Text.BadgeHidden)
		local finder = rows[2]
		expect(finder.Name).toBe("Finder")
		expect(finder.Coins).toBe(r.Played + 2 * r.PerFind)
		expect(finder.Team).toBe(cfg.Text.TeamSeeker)
		local found = rows[3]
		expect(found.Coins).toBe(r.Played + r.PerTaunt + 2 * r.PerMinuteHidden)
		expect(found.Stat).toMatch("2:05")
		-- Hard doubles the coins.
		local hard = Rules.Results(entries, "Hiders", cfg, 2)
		expect(hard[1].Coins).toBe(rows[1].Coins * 2)
		-- Finders win: found hiders who joined them win too.
		entries[3].Found = true
		for _, row in Rules.Results(entries, "Seekers", cfg, 1) do
			expect(row.Won).toBe(true)
		end
	end)
end)

local function taggedIn(rt: any, model: any, tag: string): { any }
	local list = {}
	for _, instance in rt.game:GetService("CollectionService"):GetTagged(tag) do
		if instance:IsDescendantOf(model) then
			table.insert(list, instance)
		end
	end
	return list
end

describe("The Haunted House", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")

	it("builds a floor, hider spawns, the Finder Hut and lots of things to become", function()
		local map = MapService.Load("HauntedHouse")
		expect(map.Id).toBe("HauntedHouse")
		expect(map.Floor.Name).toBe("Floor")
		local def = MapService.Get("HauntedHouse")
		expect(#map.Spawns).toBe(def.Spawns)
		local hiderSpawns = taggedIn(rt, map.Model, "HiderSpawn")
		expect(#hiderSpawns).toBe(def.Spawns)
		expect(#taggedIn(rt, map.Model, "SeekerSpawn")).toBe(def.Layout.FinderHut.Spawns)
		local doors = taggedIn(rt, map.Model, "SeekerDoor")
		expect(#doors).toBe(1)
		expect(map.Model:FindFirstChild("FinderHut", true)).toBeTruthy()

		local props = taggedIn(rt, map.Model, "PropHuntProp")
		expect(#props).toBeGreaterThan(120)
		local kinds = {}
		local upstairs = 0
		local floorTop = map.Floor.Position.Y + map.Floor.Size.Y / 2
		for _, prop in props do
			expect(prop:IsA("Model")).toBe(true)
			kinds[prop:GetAttribute("PropName")] = true
			local _, size = prop:GetBoundingBox()
			expect(math.max(size.X, size.Y, size.Z)).toBeLessThanOrEqual(
				Config.PropHunt.Disguise.MaxSize
			)
			-- Pumpkins can hit it.
			local hittable = false
			for _, d in prop:GetDescendants() do
				if d:IsA("BasePart") and d.CanQuery then
					hittable = true
				end
			end
			expect(hittable).toBe(true)
			if prop:GetPivot().Position.Y > floorTop + 10 then
				upstairs += 1
			end
		end
		local kindCount = 0
		for _ in kinds do
			kindCount += 1
		end
		expect(kindCount).toBeGreaterThanOrEqual(14)
		expect(upstairs).toBeGreaterThan(8)
		-- Every starting prop exists.
		for _, name in Config.PropHunt.Disguise.StartProps do
			expect(kinds[name]).toBe(true)
		end

		-- Phone budget.
		local parts = #rt:parts(map.Model)
		local lights = 0
		for _, d in map.Model:GetDescendants() do
			if d:IsA("Light") and d.Enabled then
				lights += 1
			end
		end
		expect(parts).toBeLessThan(4000)
		expect(lights).toBeLessThanOrEqual(24)
		-- Spawns stand inside the map, some upstairs.
		for _, spawn in hiderSpawns do
			local offset = map.Floor.CFrame:PointToObjectSpace(spawn.Position)
			expect(math.abs(offset.X)).toBeLessThan(map.Floor.Size.X / 2)
			expect(math.abs(offset.Z)).toBeLessThan(map.Floor.Size.Z / 2)
		end
		-- Only one part is called Floor (MapService finds it by name, anywhere in the map).
		local floors = 0
		for _, d in map.Model:GetDescendants() do
			if d.Name == "Floor" then
				floors += 1
			end
		end
		expect(floors).toBe(1)
		T.note(
			("%d parts, %d lights, %d things (%d kinds, %d upstairs)"):format(
				parts,
				lights,
				#props,
				kindCount,
				upstairs
			)
		)
		MapService.Unload()
	end)

	it("builds the same map every time (from its Seed)", function()
		local function layout(): string
			local map = MapService.Load("HauntedHouse")
			local spots = {}
			for _, prop in taggedIn(rt, map.Model, "PropHuntProp") do
				local p = prop:GetPivot().Position
				table.insert(
					spots,
					("%s %.2f,%.2f,%.2f"):format(prop:GetAttribute("PropName"), p.X, p.Y, p.Z)
				)
			end
			table.sort(spots)
			MapService.Unload()
			return table.concat(spots, ";")
		end
		expect(layout()).toBe(layout())
	end)
end)

-- A Prop Hunt round on The Haunted House, driven step by step.
local function newRound(
	playerCount: number,
	difficulty: string?,
	setup: ((any, { any }, any) -> ())?
)
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local DataService = rt:require("ServerScriptService.Server.Services.DataService")
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")
	local PropHunt = rt:require("ServerScriptService.Server.Modes.PropHunt")
	local RS = rt.game:GetService("ReplicatedStorage")
	local CollectionService = rt.game:GetService("CollectionService")
	DataService.Start()
	local players = {}
	for i = 1, playerCount do
		table.insert(players, rt:addPlayer({ Name = "Player" .. i }))
	end
	rt:advance(1)
	local map = MapService.Load("HauntedHouse")
	if setup then
		setup(rt, players, map)
	end
	local state = { Result = nil :: any, Done = false }
	local ctx = {
		Map = map,
		Players = players,
		Difficulty = difficulty or "Easy",
		Playlist = { Id = "PropHuntHouse", Mode = "PropHunt", Map = "HauntedHouse", Name = "Test" },
		SetState = function(s, timeLeft)
			RS:SetAttribute("State", s)
			RS:SetAttribute("TimeLeft", timeLeft)
		end,
		Countdown = function(s, seconds, stopIf)
			for remaining = seconds, 1, -1 do
				if stopIf and stopIf() then
					return
				end
				RS:SetAttribute("State", s)
				RS:SetAttribute("TimeLeft", remaining)
				rt.env.task.wait(1)
			end
		end,
		Teleport = function(player, spawn)
			player.Character:PivotTo(
				rt.env.CFrame.new(spawn.Position + rt.env.Vector3.new(0, 4, 0))
			)
		end,
		AliveHumanoid = function(player)
			local character = player.Character
			return character and character:FindFirstChildOfClass("Humanoid")
		end,
	}
	rt.scheduler:spawn(function()
		state.Result = PropHunt.Run(ctx)
		state.Done = true
	end)
	rt:advance(0.5)
	local remotes = RS:WaitForChild("Remotes")
	local round = {
		rt = rt,
		Config = Config,
		cfg = Config.PropHunt,
		settings = Config.PropHunt.Difficulty[difficulty or "Easy"],
		PropHunt = PropHunt,
		RS = RS,
		CollectionService = CollectionService,
		map = map,
		players = players,
		state = state,
		shoot = remotes:FindFirstChild("PropHuntShoot"),
		action = remotes:FindFirstChild("PropHuntAction"),
		events = remotes:FindFirstChild("PropHuntEvent"),
	}
	function round.role(player)
		return player:GetAttribute("HideSeekRole")
	end
	function round.withRole(role)
		local list = {}
		for _, player in players do
			if player.Parent and player:GetAttribute("HideSeekRole") == role then
				table.insert(list, player)
			end
		end
		return list
	end
	function round.thingOf(player)
		local folder = map.Model:FindFirstChild("HiderThings")
		for _, model in folder and folder:GetChildren() or {} do
			if model:GetAttribute("HiderUserId") == player.UserId then
				return model
			end
		end
		return nil
	end
	function round.sent(kind)
		local list = {}
		for _, call in rt:calls("RemoteEvent", "FireAllClients") do
			if call.instance == round.events and call.args[1] == kind then
				table.insert(list, call.args[2])
			end
		end
		return list
	end
	-- Every tagged thing on the map called `name` (in build order).
	function round.props(name)
		local list = {}
		for _, prop in CollectionService:GetTagged("PropHuntProp") do
			if
				prop:IsDescendantOf(map.Model)
				and (name == nil or prop:GetAttribute("PropName") == name)
			then
				table.insert(list, prop)
			end
		end
		return list
	end
	-- Stands `player` 3 studs from `prop` (on the floor next to it).
	function round.standBy(player, prop)
		local p = prop:GetPivot().Position
		player.Character:PivotTo(rt.env.CFrame.new(p + rt.env.Vector3.new(3, 3, 0)))
	end
	-- Stands the finder just above and behind `target`, cannon out, and fires at it.
	function round.shootAt(finder, target)
		local character = finder.Character
		local Vector3, CFrame = rt.env.Vector3, rt.env.CFrame
		character:PivotTo(CFrame.new(target + Vector3.new(0, 5, 3), target))
		local gun = finder.Backpack:FindFirstChildOfClass("Tool")
			or character:FindFirstChildOfClass("Tool")
		if gun then
			gun.Parent = character -- (Humanoid:EquipTool is only recorded in the harness)
		end
		rt:fireServer(round.shoot, finder, target)
	end
	function round.targetOf(player)
		local thing = round.thingOf(player)
		return thing and (thing:GetBoundingBox()).Position
	end
	return round
end

-- Every BasePart and Decal of a character that can be seen (1 = invisible).
local function visibleParts(character: any): number
	local n = 0
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Transparency < 1 then
			n += 1
		end
	end
	return n
end

describe("A Prop Hunt round (4 players, Easy)", function()
	local round = newRound(4)
	local rt, RS, cfg = round.rt, round.RS, round.cfg
	local finder, hiders

	it("picks one finder and three hiders, who start as things", function()
		expect(round.shoot).toBeInstanceOf("RemoteEvent")
		expect(round.action).toBeInstanceOf("RemoteEvent")
		expect(round.events).toBeInstanceOf("RemoteEvent")
		expect(RS:GetAttribute("State")).toBe("Hiding")
		local finders = round.withRole("Seeker")
		hiders = round.withRole("Hider")
		expect(#finders).toBe(1)
		expect(#hiders).toBe(3)
		finder = finders[1]
		expect(RS:GetAttribute("PropHidersLeft")).toBe(3)
		expect(RS:GetAttribute("PropFinderCount")).toBe(1)
		for _, hider in hiders do
			local thing = round.thingOf(hider)
			expect(thing).toBeInstanceOf("Model")
			expect(round.CollectionService:HasTag(thing, "PropHuntProp")).toBe(false)
			expect(table.find(cfg.Disguise.StartProps, hider:GetAttribute("PropDisguise"))).toBeTruthy()
			expect(visibleParts(hider.Character)).toBe(0)
			expect(hider:GetAttribute("PropChangesLeft")).toBe(round.settings.PropChanges)
			local body = thing.PrimaryPart or thing:FindFirstChildWhichIsA("BasePart", true)
			expect(body.Anchored).toBe(false)
			expect(body:FindFirstChildOfClass("WeldConstraint").Part0).toBe(
				hider.Character.HumanoidRootPart
			)
		end
		-- The finder waits in the hut, frozen, with a pumpkin head.
		expect(finder.Character.HumanoidRootPart.Anchored).toBe(true)
		expect(finder.Character:FindFirstChild("Cosmetic_Skin")).toBeTruthy()
		expect(finder.Character.Head.Transparency).toBe(1)
		local hut = round.map.Model:FindFirstChild("FinderHut", true)
		local offset = hut:GetPivot():PointToObjectSpace(finder.Character.HumanoidRootPart.Position)
		expect(math.abs(offset.X)).toBeLessThan(8)
		expect(math.abs(offset.Z)).toBeLessThan(8)
	end)

	it("turns a hider into the thing they stand next to, and checks every request", function()
		local hider = hiders[1]
		local skull = round.props("Skull")[1]
		local far = round.props("Gravestone")[1]
		expect(skull).toBeTruthy()
		round.standBy(hider, skull)
		-- Junk, finders, far away and untagged things are refused.
		rt:fireServer(round.action, hider, "Become", "nope")
		rt:fireServer(round.action, hider, "Become", round.map.Floor)
		rt:fireServer(round.action, hider, "Become", far)
		rt:fireServer(round.action, finder, "Become", skull)
		rt:fireServer(round.action, hider, 42, skull)
		expect(#round.sent("Became")).toBe(0)
		expect(finder:GetAttribute("PropDisguise")).toBeNil()
		rt:fireServer(round.action, hider, "Become", skull)
		expect(#round.sent("Became")).toBe(1)
		expect(hider:GetAttribute("PropDisguise")).toBe("Skull")
		local thing = round.thingOf(hider)
		expect(thing).toBeTruthy()
		expect(thing:FindFirstChild("Cranium") or thing:FindFirstChild("Hitbox")).toBeTruthy()
		expect(skull.Parent).toBeTruthy() -- the map's skull stays where it is
		-- Changes during the head start are free.
		expect(hider:GetAttribute("PropChangesLeft")).toBe(round.settings.PropChanges)
		-- Too soon for another change.
		local pumpkin = round.props("Pumpkin")[1]
		round.standBy(hider, pumpkin)
		rt:fireServer(round.action, hider, "Become", pumpkin)
		expect(hider:GetAttribute("PropDisguise")).toBe("Skull")
		-- nil = the nearest thing.
		rt:advance(cfg.Disguise.Cooldown + 0.1)
		rt:fireServer(round.action, hider, "Become", nil)
		expect(#round.sent("Became")).toBe(2)
		expect(hider:GetAttribute("PropDisguise")).never.toBeNil()
		expect(visibleParts(hider.Character)).toBe(0)
	end)

	it("locks a hider in place and lets them go", function()
		local hider = hiders[2]
		rt:fireServer(round.action, hider, "Lock", "yes")
		expect(hider.Character.HumanoidRootPart.Anchored).toBe(false)
		rt:fireServer(round.action, hider, "Lock", true)
		expect(hider.Character.HumanoidRootPart.Anchored).toBe(true)
		expect(hider:GetAttribute("PropLocked")).toBe(true)
		rt:fireServer(round.action, hider, "Lock", false)
		expect(hider.Character.HumanoidRootPart.Anchored).toBe(false)
		expect(hider:GetAttribute("PropLocked")).toBe(false)
	end)

	it("ignores shots while the finders are still counting", function()
		round.shootAt(finder, round.targetOf(hiders[1]))
		expect(#round.sent("Shot")).toBe(0)
		finder.Character.HumanoidRootPart.Anchored = true -- (shootAt moved it)
	end)

	it("lets the finders out with Pumpkin Cannons after the head start", function()
		rt:advance(round.settings.HeadStart + 0.5)
		expect(RS:GetAttribute("State")).toBe("Playing")
		expect(finder.Character.HumanoidRootPart.Anchored).toBe(false)
		local gun = finder.Backpack:FindFirstChildOfClass("Tool")
		expect(gun).toBeInstanceOf("Tool")
		expect(gun:GetAttribute("PumpkinCannon")).toBe(true)
		expect(gun.Handle:FindFirstChild("Muzzle")).toBeTruthy()
		expect(#round.sent("Released")).toBe(1)
		local door = taggedIn(rt, round.map.Model, "SeekerDoor")[1]
		expect(door.CanCollide).toBe(false)
	end)

	it("counts changes once the finders are out, and taunts for points", function()
		local hider = hiders[3]
		local candle = round.props("Candle")[2]
		round.standBy(hider, candle)
		rt:fireServer(round.action, hider, "Become", candle)
		expect(hider:GetAttribute("PropDisguise")).toBe("Candle")
		expect(hider:GetAttribute("PropChangesLeft")).toBe(round.settings.PropChanges - 1)
		rt:fireServer(round.action, hider, "Taunt")
		rt:fireServer(round.action, hider, "Taunt") -- too soon
		local taunts = {}
		for _, giggle in round.sent("Giggle") do
			if giggle.Taunt then
				table.insert(taunts, giggle)
			end
		end
		expect(#taunts).toBe(1)
		expect(taunts[1].Prop).toBe(round.thingOf(hider))
		expect(hider:GetAttribute("PropTaunts")).toBe(1)
		expect(hider:GetAttribute("PropTauntReadyAt")).toBeA("number")
	end)

	it("rejects bad shots: not a finder, junk targets, cannon put away", function()
		local target = round.targetOf(hiders[1])
		rt:fireServer(round.shoot, hiders[2], target)
		rt:fireServer(round.shoot, finder, "nope")
		rt:fireServer(round.shoot, finder, rt.env.Vector3.new(0 / 0, 0, 0))
		rt:fireServer(round.shoot, finder, target) -- the cannon is still in the backpack
		expect(#round.sent("Shot")).toBe(0)
		expect(RS:GetAttribute("PropHidersLeft")).toBe(3)
	end)

	it("finds a hider whose thing a pumpkin hits; they become a pumpkin-headed finder", function()
		local hider = hiders[1]
		local thing = round.thingOf(hider)
		round.shootAt(finder, round.targetOf(hider))
		local shots = round.sent("Shot")
		expect(#shots).toBe(1)
		expect(shots[1].Result).toBe("Hider")
		expect(#round.sent("Found")).toBe(1)
		expect(round.role(hider)).toBe("Seeker")
		expect(RS:GetAttribute("PropHidersLeft")).toBe(2)
		expect(RS:GetAttribute("PropFinderCount")).toBe(2)
		expect(finder:GetAttribute("PropFinds")).toBe(1)
		expect(thing.Parent).toBeNil()
		expect(hider:GetAttribute("PropDisguise")).toBeNil()
		rt:advance(round.cfg.FoundFinderDelay + 0.5)
		expect(hider.Backpack:FindFirstChildOfClass("Tool")).toBeInstanceOf("Tool")
		expect(hider.Character:FindFirstChild("Cosmetic_Skin")).toBeTruthy() -- the pumpkin head
	end)

	it("makes a finder wait longer after hitting a real thing, too far shots miss", function()
		local prop = nil
		for _, candidate in round.props(nil) do
			if candidate.Parent.Name == "YardThings" then
				prop = candidate
				break
			end
		end
		expect(prop).toBeTruthy()
		rt:advance(cfg.Cannon.FireCooldown + 0.1)
		local box = prop:GetBoundingBox()
		round.shootAt(finder, box.Position)
		local shots = round.sent("Shot")
		expect(#shots).toBe(2)
		expect(shots[2].Result).toBe("Prop")
		expect(shots[2].Prop).toBe(prop:GetAttribute("PropName"))
		expect(shots[2].Cooldown).toBeNear(cfg.Cannon.FireCooldown + round.settings.PropPenalty)
		local target = round.targetOf(hiders[2])
		round.shootAt(finder, target) -- straight away: too soon
		expect(#round.sent("Shot")).toBe(2)
		rt:advance(cfg.Cannon.FireCooldown + 0.1) -- a normal wait isn't enough after a real thing
		round.shootAt(finder, target)
		expect(#round.sent("Shot")).toBe(2)
		expect(RS:GetAttribute("PropHidersLeft")).toBe(2)
	end)

	it("giggles: hiders give themselves away now and then on Easy", function()
		rt:advance(round.settings.GiggleInterval + 2)
		local giggles = 0
		for _, giggle in round.sent("Giggle") do
			if not giggle.Taunt then
				giggles += 1
			end
		end
		expect(giggles).toBeGreaterThanOrEqual(2)
	end)

	it("ends when every hider is found: the finders win", function()
		rt:advance(round.settings.PropPenalty + 1)
		for _, hider in round.withRole("Hider") do
			rt:advance(cfg.Cannon.FireCooldown + 0.1)
			round.shootAt(finder, round.targetOf(hider))
		end
		expect(RS:GetAttribute("PropHidersLeft")).toBe(0)
		rt:advance(2)
		expect(round.state.Done).toBe(true)
		local result = round.state.Result
		expect(result.ScoreLabel).toBe(cfg.Text.ScoreLabel)
		expect(result.Winner).toBe(cfg.Text.SeekersWin)
		expect(#result.Rows).toBe(4)
		local top = result.Rows[1]
		expect(top.UserId).toBe(finder.UserId)
		expect(top.Score).toBe(3)
		expect(top.Top).toBe(true)
		for _, row in result.Rows do
			expect(row.Coins).toBeGreaterThan(0)
			expect(row.Team).toBeA("string")
		end
		expect(#rt.errors).toBe(0)
	end)

	it("cleans up after itself: things, cannons, heads, attributes", function()
		expect(round.map.Model:FindFirstChild("HiderThings")).toBeNil()
		expect(RS:GetAttribute("PropHidersLeft")).toBeNil()
		expect(RS:GetAttribute("PropFinderCount")).toBeNil()
		rt:advance(0.5)
		for _, player in round.players do
			for _, name in
				{ "HideSeekRole", "PropFinds", "PropChangesLeft", "PropLocked", "PropDisguise" }
			do
				expect(player:GetAttribute(name)).toBeNil()
			end
			expect(player.Backpack:FindFirstChildOfClass("Tool")).toBeNil()
			expect(player.Character:FindFirstChild("Cosmetic_Skin")).toBeNil()
			expect(player.Character.Head.Transparency).toBe(0)
			expect(player.Character.HumanoidRootPart.Anchored).toBe(false)
		end
		round.PropHunt.Cleanup() -- safe with nothing running
		round.PropHunt.Cleanup()
	end)
end)

describe("Prop Hunt with players leaving and resetting", function()
	it("makes a hider the finder if every finder leaves while counting", function()
		local round = newRound(3)
		local finder = round.withRole("Seeker")[1]
		round.rt:removePlayer(finder)
		local finders = round.withRole("Seeker")
		expect(#finders).toBe(1)
		expect(#round.withRole("Hider")).toBe(1)
		expect(round.thingOf(finders[1])).toBeNil()
		round.rt:advance(0.5)
		expect(finders[1].Character.HumanoidRootPart.Anchored).toBe(true)
		expect(finders[1].Character:FindFirstChild("Cosmetic_Skin")).toBeTruthy()
		round.PropHunt.Cleanup()
	end)

	it("promotes a hider mid-round too, so the round goes on", function()
		local round = newRound(3)
		round.rt:advance(round.settings.HeadStart + 1)
		local finder = round.withRole("Seeker")[1]
		round.rt:removePlayer(finder)
		round.rt:advance(0.5)
		expect(#round.withRole("Seeker")).toBe(1)
		expect(#round.withRole("Hider")).toBe(1)
		expect(round.state.Done).toBe(false)
		local promoted = round.withRole("Seeker")[1]
		expect(promoted.Backpack:FindFirstChildOfClass("Tool")).toBeTruthy()
		round.PropHunt.Cleanup()
	end)

	it("ends with the hiders winning when the only finder leaves mid-round", function()
		local round = newRound(2, "Hard")
		round.rt:advance(round.settings.HeadStart + 1)
		expect(round.RS:GetAttribute("State")).toBe("Playing")
		local finder = round.withRole("Seeker")[1]
		local hider = round.withRole("Hider")[1]
		round.rt:removePlayer(finder)
		round.rt:advance(2)
		expect(round.state.Done).toBe(true)
		local result = round.state.Result
		expect(result.Winner).toBe(round.cfg.Text.NoSeekers)
		expect(#result.Rows).toBe(1)
		expect(result.Rows[1].UserId).toBe(hider.UserId)
		expect(result.Rows[1].Survived).toBe(true)
		-- Hard: coins x2.
		local r = round.cfg.Rewards
		expect(result.Rows[1].Coins).toBe((r.Played + r.HiderSurvived + r.WinningTeam) * 2)
	end)

	it(
		"keeps a reset hider's thing in place (it can still be found) and brings them back",
		function()
			local round = newRound(3)
			local rt = round.rt
			rt:advance(round.settings.HeadStart + 0.5)
			local finder = round.withRole("Seeker")[1]
			local hiders = round.withRole("Hider")
			local stayer, caught = hiders[1], hiders[2]
			local thing = round.thingOf(stayer)
			local spot = thing:GetPivot().Position
			local name = stayer:GetAttribute("PropDisguise")
			stayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
			rt:advance(0.1)
			expect(round.thingOf(stayer)).toBe(thing)
			expect(round.role(stayer)).toBe("Hider")
			rt:spawnCharacter(stayer)
			rt:advance(0.5)
			local again = round.thingOf(stayer)
			expect(again).toBeTruthy()
			expect(again).never.toBe(thing)
			expect(stayer:GetAttribute("PropDisguise")).toBe(name)
			local root = stayer.Character.HumanoidRootPart.Position
			expect(math.abs(root.X - spot.X) + math.abs(root.Z - spot.Z)).toBeLessThan(3)
			expect(visibleParts(stayer.Character)).toBe(0)
			-- A finder can still find the thing of a hider waiting to respawn.
			caught.Character:FindFirstChildOfClass("Humanoid").Health = 0
			rt:advance(0.1)
			round.shootAt(finder, round.targetOf(caught))
			expect(round.role(caught)).toBe("Seeker")
			expect(round.RS:GetAttribute("PropHidersLeft")).toBe(1)
			round.PropHunt.Cleanup()
		end
	)

	it("keeps a hider hidden when the shop dresses them, and a finder's pumpkin head on", function()
		local round = newRound(2)
		local rt = round.rt
		local ShopService = rt:require("ServerScriptService.Server.Services.ShopService")
		local hider = round.withRole("Hider")[1]
		local finder = round.withRole("Seeker")[1]
		ShopService.Dress(hider)
		ShopService.Dress(finder) -- e.g. equipping something in the shop
		rt:advance(0.2)
		expect(visibleParts(hider.Character)).toBe(0)
		expect(finder.Character:FindFirstChild("Cosmetic_Skin")).toBeTruthy()
		expect(finder.Character.Head.Transparency).toBe(1)
		round.PropHunt.Cleanup()
		rt:advance(0.2)
		expect(finder.Character:FindFirstChild("Cosmetic_Skin")).toBeNil()
		expect(finder.Character.Head.Transparency).toBe(0)
	end)

	it("plays a solo round to the end", function()
		local round = newRound(1)
		local cfg = round.cfg
		expect(round.role(round.players[1])).toBe(cfg.SoloRole)
		round.rt:advance(round.settings.HeadStart + round.settings.Duration + 5)
		expect(round.state.Done).toBe(true)
		expect(round.state.Result.Winner).toBeA("string")
		expect(#round.rt.errors).toBe(0)
	end)
end)

describe("Prop Hunt on the screen", function()
	local client = Runtime.new({ client = true })
	local RS = client.game:GetService("ReplicatedStorage")
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local me = client.localPlayer
	local remotes = client:create("Folder", { Name = "Remotes" }, RS)
	for _, name in
		{ "PropHuntEvent", "PropHuntShoot", "PropHuntAction", "HideSeekEvent", "HideSeekShoot" }
	do
		client:create("RemoteEvent", { Name = name }, remotes)
	end
	local playerGui = me:FindFirstChild("PlayerGui")

	it("shows nothing with the feature off", function()
		local gui = client:create("ScreenGui", { Name = "OffGui" }, playerGui)
		Config.Features.PropHunt = false
		client:require("StarterPlayer.StarterPlayerScripts.Client.PropHuntUI").Mount(gui)
		Config.Features.PropHunt = true
		expect(#gui:GetChildren()).toBe(0)
		expect(playerGui:FindFirstChild("PropHuntBlindfold")).toBeNil()
	end)

	it("gives hiders their buttons, finders the blindfold, and hides chat bubbles", function()
		local chat = client.game:GetService("TextChatService")
		local bubbles = client:create("BubbleChatConfiguration", {}, chat)
		bubbles.Enabled = true
		local gui = client:create("ScreenGui", { Name = "GameUI" }, playerGui)
		local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.PropHuntUI")
		local HideSeekUI = client:require("StarterPlayer.StarterPlayerScripts.Client.HideSeekUI")
		UI.Mount(gui)
		HideSeekUI.Mount(gui)
		client:advance(0.1)
		local become = gui:FindFirstChild("BecomeButton", true)
		expect(become).toBeTruthy()
		expect(become.Visible).toBe(false)

		RS:SetAttribute("Mode", "PropHunt")
		RS:SetAttribute("State", "Hiding")
		RS:SetAttribute("TimeLeft", 20)
		me:SetAttribute("HideSeekRole", "Hider")
		client:advance(0.5)
		expect(become.Visible).toBe(true)
		expect(gui:FindFirstChild("LockButton", true).Visible).toBe(true)
		expect(gui:FindFirstChild("TauntButton", true).Visible).toBe(true)
		expect(bubbles.Enabled).toBe(false)
		expect(gui:FindFirstChild("PropHuntStatus").Visible).toBe(true)
		expect(gui:FindFirstChild("PropHuntBanner").Text).toBe(Config.PropHunt.Text.HiderRole)
		-- Hide & Seek's screen stays out of the way.
		expect(gui:FindFirstChild("HideSeekStatus").Visible).toBe(false)
		expect(gui:FindFirstChild("HideSeekBanner").Visible).toBe(false)
		expect(playerGui:FindFirstChild("HideSeekBlindfold").Enabled).toBe(false)

		-- Pressing BECOME IT with nothing near says so (and sends nothing).
		local fired = #client:calls("RemoteEvent", "FireServer")
		client:fire(become, "Activated")
		client:advance(0.1)
		expect(#client:calls("RemoteEvent", "FireServer")).toBe(fired)
		expect(gui:FindFirstChild("PropHuntFeed").Text).toBe(Config.PropHunt.Text.NothingNear)

		-- A finder counts behind the blindfold.
		me:SetAttribute("HideSeekRole", "Seeker")
		client:advance(0.2)
		expect(playerGui:FindFirstChild("PropHuntBlindfold").Enabled).toBe(true)
		expect(become.Visible).toBe(false)

		RS:SetAttribute("State", "Results")
		client:advance(0.2)
		expect(playerGui:FindFirstChild("PropHuntBlindfold").Enabled).toBe(false)
		expect(bubbles.Enabled).toBe(true)
		expect(gui:FindFirstChild("PropHuntStatus").Visible).toBe(false)
		RS:SetAttribute("Mode", nil)
		me:SetAttribute("HideSeekRole", nil)
		expect(#client.errors).toBe(0)
	end)

	it("keeps every hider button on a short phone screen held sideways", function()
		local gui = client:create("ScreenGui", { Name = "PhoneGui" }, playerGui)
		gui:SetAttribute("ForceTouch", true)
		local camera = client.workspace.CurrentCamera
		local saved = camera.ViewportSize
		Dom.rawSet(camera, "ViewportSize", client.env.Vector2.new(750, 323))
		client:require("StarterPlayer.StarterPlayerScripts.Client.Layout").Mount(gui)
		local UI = client:require("StarterPlayer.StarterPlayerScripts.Client.PropHuntUI")
		UI.Mount(gui)
		-- A phone sideways: 750 x 323 (the buttons are anchored at their bottom-right corner).
		local height, width = 323, 750
		for _, name in { "BecomeButton", "LockButton", "TauntButton" } do
			local b = gui:FindFirstChild(name, true)
			local top = height + b.Position.Y.Offset - b.Size.Y.Offset
			local left = width + b.Position.X.Offset - b.Size.X.Offset
			expect(top).toBeGreaterThanOrEqual(0)
			expect(left).toBeGreaterThanOrEqual(0)
			expect(b.Position.Y.Scale).toBe(1)
			expect(b.Position.X.Scale).toBe(1)
		end
		gui:Destroy()
		Dom.rawSet(camera, "ViewportSize", saved)
	end)

	it("never lets spectators watch a disguised hider", function()
		local SpectateTargets =
			client:require("StarterPlayer.StarterPlayerScripts.Client.SpectateTargets")
		local hider = client:addPlayer({ Name = "Hider", character = false })
		local finder = client:addPlayer({ Name = "Finder", character = false })
		for _, player in { hider, finder } do
			player:SetAttribute("InRound", true)
		end
		hider:SetAttribute("HideSeekRole", "Hider")
		finder:SetAttribute("HideSeekRole", "Seeker")
		RS:SetAttribute("Mode", "PropHunt")
		expect(SpectateTargets.Watchable(hider)).toBe(false)
		expect(SpectateTargets.Watchable(finder)).toBe(true)
		RS:SetAttribute("Mode", "KingHunt")
		expect(SpectateTargets.Watchable(hider)).toBe(true)
		RS:SetAttribute("Mode", nil)
	end)
end)
