-- Swapping props (ReplicatedStorage.Custom.Props): one model per name replaces every copy in
-- the lobby and in every round map, the gameplay pieces keep working with any model (King
-- Hunt pumpkins, parkour pumpkins, Hide & Seek decoys and disguises, hiding haystacks), a
-- custom model in place of walk-through decoration is walk-through too, a custom model never
-- moves anything else, custom jack-o'-lanterns keep the lobby inside its light budget, the
-- docs list every name, and the Swap tool (src/server/Tools/Swap.luau) swaps, reverts and
-- replaces things in a saved hub and a baked map (never parts of props, never a round in play).

local fs = require("@lune/fs")

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

-- A fresh game with the modules these tests use.
local function world(): any
	local rt = Runtime.new()
	local w = {
		rt = rt,
		Vector3 = rt.env.Vector3,
		CFrame = rt.env.CFrame,
		CollectionService = rt.game:GetService("CollectionService"),
		ServerStorage = rt.game:GetService("ServerStorage"),
		Config = rt:require("ReplicatedStorage.Shared.Config"),
		CustomAssets = rt:require("ReplicatedStorage.Shared.CustomAssets"),
		Kit = rt:require("ServerScriptService.Server.Build.Kit"),
		HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder"),
		MapService = rt:require("ServerScriptService.Server.Services.MapService"),
	}
	-- How many Pumpkin steps and checkpoints the parkour course has (Config.Parkour.Course).
	w.parkourPumpkins = 0
	w.parkourCheckpoints = 0
	for _, step in w.Config.Parkour.Course do
		if step.Kind == "Pumpkin" then
			w.parkourPumpkins += 1
		elseif step.Kind == "Checkpoint" then
			w.parkourCheckpoints += 1
		end
	end
	-- A plain custom model: one block, 3 studs tall, standing on the origin (any shape works).
	function w.model(name: string): any
		local m = rt:create("Model", { Name = name })
		rt:create("Part", {
			Name = "Look",
			Size = w.Vector3.new(2, 3, 2),
			CFrame = w.CFrame.new(0, 1.5, 0),
			Color = rt.env.Color3.fromRGB(10, 200, 90),
		}, m)
		return m
	end
	-- Puts a custom model called `name` into ReplicatedStorage.Custom.Props.
	function w.custom(name: string): any
		local m = w.model(name)
		m.Parent = rt:find("ReplicatedStorage.Custom.Props")
		return m
	end
	-- Every prop model under `root`: { model }.
	function w.props(root: any): { any }
		local list = {}
		for _, d in root:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") ~= nil then
				table.insert(list, d)
			end
		end
		return list
	end
	function w.tagged(tag: string, root: any): { any }
		local list = {}
		for _, instance in w.CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(root) then
				table.insert(list, instance)
			end
		end
		return list
	end
	return w
end

-- Is BasePart `d` part of prop `m` itself (not of a prop inside it)?
local function ownPart(d: any, m: any): boolean
	local node = d.Parent
	while node and node ~= m do
		if node:IsA("Model") and node:GetAttribute("PropName") ~= nil then
			return false
		end
		node = node.Parent
	end
	return true
end

-- True when prop `m` is pure decoration: it has parts and none of them collides or blocks
-- raycasts (King sight, candy).
local function onlyLooks(m: any): boolean
	local any = false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and ownPart(d, m) then
			if d.CanCollide or d.CanQuery then
				return false
			end
			any = true
		end
	end
	return any
end

-- Where prop `m` stands, for matching a built prop with the custom one in its place.
local function spotKey(place: string, m: any): string
	local p = m:GetPivot().Position
	return ("%s|%s|%.2f,%.2f,%.2f"):format(place, m:GetAttribute("PropName"), p.X, p.Y, p.Z)
end

-- The props under `root` that aren't inside another prop, in the order they were made.
local function outerProps(root: any): { any }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("PropName") ~= nil then
			local inside = false
			local node = d.Parent
			while node and node ~= root do
				if node:IsA("Model") and node:GetAttribute("PropName") ~= nil then
					inside = true
					break
				end
				node = node.Parent
			end
			if not inside then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function lightCount(root: any): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Light") and d.Enabled then
			n += 1
		end
	end
	return n
end

-- The lobby and every round map, built from code: calls visit(name, model) for each.
local function eachPlace(w: any, visit: (string, any) -> ())
	local hub = w.HubBuilder.Build()
	visit("Hub", hub)
	for _, def in w.Config.Maps.List do
		local map = w.MapService.Load(def.Id)
		visit(def.Id, map.Model)
		w.MapService.Unload()
	end
end

-- The prop names docs/CUSTOMIZE.md lists in backticks in its "Swap every copy" table.
local function documentedNames(): { [string]: boolean }
	local path = if fs.isFile("docs/CUSTOMIZE.md")
		then "docs/CUSTOMIZE.md"
		else "new-game/docs/CUSTOMIZE.md"
	local text = fs.readFile(path)
	local start = text:find("## Swap every copy of something at once", 1, true)
	assert(start, "docs/CUSTOMIZE.md has no section 'Swap every copy of something at once'")
	local section = text:sub(start)
	local stop = section:find("\n## ", 5, true)
	if stop then
		section = section:sub(1, stop)
	end
	local names = {}
	for line in section:gmatch("[^\n]+") do
		if line:sub(1, 2) == "| " then
			local first = line:match("^| ([^|]+)|") or ""
			for name in first:gmatch("`([%w]+)`") do
				names[name] = true
			end
		end
	end
	return names
end

describe("One custom model per prop name", function()
	local w = world()
	local names: { [string]: number } = {}
	local decorSpots: { [string]: boolean } = {} -- spotKey of each built walk-through prop
	type Placed = { Name: string, Pivot: any, Size: any }
	local builtOuter: { [string]: { Placed } } = {} -- per place, the outer props as built
	local builtHubLights = 0

	local function placed(root: any): { Placed }
		local list = {}
		for _, m in outerProps(root) do
			table.insert(list, {
				Name = m:GetAttribute("PropName"),
				Pivot = m:GetPivot(),
				Size = m:GetAttribute("PropSize"),
			})
		end
		return list
	end

	it("finds the props the lobby and every map build, and the docs list each name", function()
		local unmarked = {}
		eachPlace(w, function(place, root)
			for _, m in w.props(root) do
				local name = m:GetAttribute("PropName")
				names[name] = (names[name] or 0) + 1
				expect(m:GetAttribute("CustomProp")).toBeNil() -- nothing custom yet
				-- Walk-through decoration says so (Kit.prop options.Visual), so a custom model
				-- in its place is walk-through too.
				if onlyLooks(m) then
					decorSpots[spotKey(place, m)] = true
					if m:GetAttribute("PropVisual") ~= true then
						unmarked[place .. " " .. name] = true
					end
				end
			end
			builtOuter[place] = placed(root)
			if place == "Hub" then
				builtHubLights = lightCount(root)
			end
		end)
		local list = {}
		for what in unmarked do
			table.insert(list, what)
		end
		table.sort(list)
		if #list > 0 then
			error(
				"walk-through props built without Visual = true (a custom model would be solid): "
					.. table.concat(list, ", ")
			)
		end
		-- The pumpkins, in every place they appear.
		for _, name in { "Pumpkin", "JackOLantern", "HidingPumpkin", "ParkourPumpkin" } do
			expect(names[name]).toBeGreaterThan(0)
		end
		local documented = documentedNames()
		expect(documented.CollectPumpkin).toBe(true) -- (made during a round: tested below)
		-- Crates are listed as "a crate's Id": each crate in Config.Crates.List is a prop.
		local crates = {}
		for _, crate in w.Config.Crates.List do
			crates[crate.Id] = true
		end
		local missing = {}
		for name in names do
			if not documented[name] and not crates[name] then
				table.insert(missing, name)
			end
		end
		table.sort(missing)
		if #missing > 0 then
			error("not in the docs table: " .. table.concat(missing, ", "))
		end
		local count = 0
		for _ in names do
			count += 1
		end
		T.note(("%d prop names"):format(count))
	end)

	it("uses the custom model for every placement, sized to the thing it replaces", function()
		for name in names do
			w.custom(name)
		end
		local seen = 0
		eachPlace(w, function(place, root)
			for _, m in w.props(root) do
				if m:GetAttribute("CustomProp") ~= true then
					error(
						("%s: a built %s at %s"):format(
							place,
							m:GetAttribute("PropName"),
							m:GetFullName()
						)
					)
				end
				expect(m:FindFirstChild("Look")).toBeTruthy()
				local size = m:GetAttribute("PropSize")
				if typeof(size) == "number" then
					-- (standing props stand upright; hung ones, like cobwebs, take the full turn)
					local space = if m:GetAttribute("PropAnchor") == "Center"
						then m:GetPivot()
						else nil
					local low, high = w.CustomAssets.VisibleBox(m, space)
					if math.abs(high.Y - low.Y - size) > 0.02 then
						error(
							("%s: %s is %.2f studs tall, not %.2f"):format(
								place,
								m:GetFullName(),
								high.Y - low.Y,
								size
							)
						)
					end
				end
				seen += 1
			end
		end)
		T.note(("%d custom props placed"):format(seen))
		expect(seen).toBeGreaterThan(500)
		-- Every lobby area and map still builds with a custom model for everything.
		if #w.rt.warnings > 0 then
			error("warning while building: " .. tostring(w.rt.warnings[1]))
		end
	end)

	it("keeps a custom model walk-through where the built one is decoration", function()
		local checked = 0
		eachPlace(w, function(place, root)
			for _, m in w.props(root) do
				if decorSpots[spotKey(place, m)] then
					checked += 1
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then
							error(
								("%s: the custom %s at %s is solid (players could hide behind it from the King)"):format(
									place,
									m:GetAttribute("PropName"),
									m:GetFullName()
								)
							)
						end
					end
				end
			end
		end)
		T.note(("%d walk-through custom props"):format(checked))
		expect(checked).toBeGreaterThan(150) -- field pumpkins, cobwebs, candles, crows...
	end)

	it("never moves anything else: every prop stands where the built one stood", function()
		-- (a custom model skips the built one's code: random numbers drawn in there would
		-- shift every later prop)
		eachPlace(w, function(place, root)
			local built = builtOuter[place]
			local now = placed(root)
			expect(#now).toBe(#built)
			for i, b in built do
				local c = now[i]
				local moved = c.Name ~= b.Name
					or (c.Pivot.Position - b.Pivot.Position).Magnitude > 1e-3
					or (c.Pivot.LookVector - b.Pivot.LookVector).Magnitude > 1e-3
					or (typeof(b.Size) == "number" and math.abs(c.Size - b.Size) > 1e-6)
				if moved then
					error(
						("%s: prop #%d is a %s at %s facing %s, size %s; built it was a %s at %s facing %s, size %s"):format(
							place,
							i,
							c.Name,
							tostring(c.Pivot.Position),
							tostring(c.Pivot.LookVector),
							tostring(c.Size),
							b.Name,
							tostring(b.Pivot.Position),
							tostring(b.Pivot.LookVector),
							tostring(b.Size)
						)
					)
				end
			end
		end)
	end)

	it("keeps the lobby inside its light budget with your models", function()
		-- Your model for everything, and only a jack-o'-lantern (the lobby has the most of
		-- those, and most are built without a light: Config.Custom.PropLights).
		local budget = w.Config.Hub.Budget.MaxLights
		local all = lightCount(w.HubBuilder.Build())
		local only = world()
		-- (a Toolbox jack-o'-lantern often has a light of its own inside)
		local jack = only.custom("JackOLantern")
		only.rt:create("PointLight", { Name = "OwnLight" }, jack.Look)
		local onlyHub = only.HubBuilder.Build()
		local jacks = lightCount(onlyHub)
		-- Swapping them again (Swap.Props refreshes custom props) keeps their own lights off.
		local refreshed = 0
		for _, m in only.props(onlyHub) do
			if
				m:GetAttribute("PropName") == "JackOLantern"
				and m:GetAttribute("PropLit") == false
			then
				local new = only.Kit.swapProp(m)
				m:Destroy()
				expect(new.Look.OwnLight.Enabled).toBe(false)
				refreshed += 1
			end
		end
		expect(refreshed).toBeGreaterThan(5)
		expect(lightCount(onlyHub)).toBe(jacks)
		T.note(
			("%d lights built, %d with every prop custom, %d with a custom JackOLantern (budget %d)"):format(
				builtHubLights,
				all,
				jacks,
				budget
			)
		)
		for _, lights in { all, jacks } do
			expect(lights).toBeLessThanOrEqual(builtHubLights)
			expect(lights).toBeLessThanOrEqual(budget)
		end
	end)

	it("keeps parkour steps standing: the lid you land on stays, tagged pads too", function()
		local hub = w.HubBuilder.Build()
		local course = hub.Parkour.Course
		local pumpkins = 0
		for _, step in course:GetChildren() do
			if step.Name:match("_Pumpkin$") then
				pumpkins += 1
				local top = step.PrimaryPart
				expect(top.Name).toBe("Top")
				expect(top.CanCollide).toBe(true)
				expect(top.Transparency).toBe(1) -- your pumpkin is the look now
				local look = top:FindFirstChild("ParkourPumpkin")
				expect(look:GetAttribute("CustomProp")).toBe(true)
				expect(look:GetAttribute("PropLook")).toBe(true)
				for _, d in look:GetDescendants() do
					if d:IsA("BasePart") then
						expect(d.CanCollide).toBe(false)
						expect(d.CanQuery).toBe(false)
						expect(d.CanTouch).toBe(false)
					end
				end
				-- Its top is where you stand.
				local _, high = w.CustomAssets.VisibleBox(look)
				expect(high.Y).toBeNear(top.Position.Y + top.Size.X / 2, 0.05)
			end
		end
		expect(pumpkins).toBe(w.parkourPumpkins)
		for _, tag in { "ParkourStart", "ParkourFinish", "ParkourBoard" } do
			expect(#w.tagged(tag, hub)).toBe(1)
		end
		expect(#w.tagged("ParkourCheckpoint", hub)).toBe(w.parkourCheckpoints)
	end)

	it("keeps the haystacks hiding you from the King, and lanterns glowing", function()
		local map = w.MapService.Load("PumpkinPatch")
		local spots = w.tagged("HidingSpot", map.Model)
		local stacks = 0
		for _, spot in spots do
			local look = spot:FindFirstChild("Haystack")
			if look then
				stacks += 1
				expect(spot.CanQuery).toBe(true) -- still blocks the King's view
				expect(spot.Transparency).toBe(1)
				expect(look:GetAttribute("CustomProp")).toBe(true)
			end
		end
		expect(stacks).toBeGreaterThan(4)
		-- A custom jack-o'-lantern or lamppost with no light of its own gets the glow light.
		for _, m in w.props(map.Model) do
			local name = m:GetAttribute("PropName")
			if name == "JackOLantern" or name == "Lamppost" then
				expect(m:FindFirstChildWhichIsA("PointLight", true)).toBeTruthy()
			end
		end
		w.MapService.Unload()
	end)
end)

describe("King Hunt pumpkins with a custom CollectPumpkin", function()
	it("spawn with your look, and can still be picked up", function()
		local w = world()
		local rt, Config = w.rt, w.Config
		w.custom("CollectPumpkin")
		local PumpkinService = rt:require("ServerScriptService.Server.Services.PumpkinService")
		PumpkinService.Start()
		local player = rt:addPlayer({ Name = "Collector" })
		local map = w.MapService.Load("PumpkinPatch")
		PumpkinService.Begin(map, "Easy", function()
			return true
		end)
		local folder = map.Model:FindFirstChild("Pumpkins")
		local pickups = folder:GetChildren()
		expect(#pickups).toBeGreaterThan(5)
		local pumpkin = pickups[1]
		expect(pumpkin:IsA("BasePart")).toBe(true)
		expect(pumpkin.Transparency).toBe(1) -- the ball is hidden...
		expect(pumpkin:FindFirstChildOfClass("PointLight")).toBeTruthy() -- ...but still glows
		local look = pumpkin:FindFirstChild("CollectPumpkin")
		expect(look:GetAttribute("CustomProp")).toBe(true)
		local low, high = w.CustomAssets.VisibleBox(look)
		expect(high.Y - low.Y).toBeNear(Config.Pumpkins.Size, 0.02)
		expect(((low + high) / 2 - pumpkin.Position).Magnitude).toBeLessThan(0.05) -- on the ball
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then
				expect(d.CanTouch).toBe(false)
				expect(d.CanCollide).toBe(false)
			end
		end
		-- Walk up to it and touch it.
		local root = player.Character.HumanoidRootPart
		player.Character:PivotTo(w.CFrame.new(pumpkin.Position))
		rt:fire(pumpkin, "Touched", root)
		expect(player:GetAttribute("Pumpkins")).toBe(Config.Pumpkins.Value)
		expect(pumpkin.Parent).toBeNil()
		expect(look.Parent).toBeNil() -- the look goes with it
		PumpkinService.Stop()
		w.MapService.Unload()
	end)
end)

describe("Hide & Seek with a custom HidingPumpkin", function()
	it("uses it for the decoys and the hiders, and candy still finds both", function()
		local w = world()
		local rt, Config = w.rt, w.Config
		w.custom("HidingPumpkin")
		local DataService = rt:require("ServerScriptService.Server.Services.DataService")
		local HideSeek = rt:require("ServerScriptService.Server.Modes.HideSeek")
		local RS = rt.game:GetService("ReplicatedStorage")
		DataService.Start()
		local players = {}
		for i = 1, 3 do
			table.insert(players, rt:addPlayer({ Name = "Player" .. i }))
		end
		rt:advance(1)
		local map = w.MapService.Load("PumpkinFarm")
		-- The decoys: your model, an invisible hitbox, still decoys.
		local decoys = w.tagged("HidingDecoy", map.Model)
		expect(#decoys).toBeGreaterThan(100)
		for _, decoy in decoys do
			expect(decoy:GetAttribute("CustomProp")).toBe(true)
			expect(decoy:FindFirstChild("Look")).toBeTruthy()
			local box = decoy.PrimaryPart
			expect(box.Name).toBe("Hitbox")
			expect(box.Transparency).toBe(1)
			expect(box.CanQuery).toBe(true)
			expect(box.Size.Y).toBeNear(decoy:GetAttribute("PumpkinHeight"), 1e-3)
			expect(decoy.Look.CanQuery).toBe(false)
		end
		local ctx = {
			Map = map,
			Players = players,
			Difficulty = "Easy",
			Playlist = {
				Id = "HideSeekFarm",
				Mode = "HideSeek",
				Map = "PumpkinFarm",
				Name = "Test",
			},
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
				player.Character:PivotTo(w.CFrame.new(spawn.Position + w.Vector3.new(0, 4, 0)))
			end,
			AliveHumanoid = function(player)
				local character = player.Character
				return character and character:FindFirstChildOfClass("Humanoid")
			end,
		}
		rt.scheduler:spawn(function()
			HideSeek.Run(ctx)
		end)
		rt:advance(0.5)
		local seeker, hider
		for _, player in players do
			if player:GetAttribute("HideSeekRole") == "Seeker" then
				seeker = player
			elseif player:GetAttribute("HideSeekRole") == "Hider" then
				hider = hider or player
			end
		end
		expect(seeker).toBeTruthy()
		expect(hider).toBeTruthy()
		-- The hider wears a copy of a decoy: your model, welded on, its hitbox candy can hit.
		local pumpkin
		for _, model in map.Model.HiderPumpkins:GetChildren() do
			if model:GetAttribute("HiderUserId") == hider.UserId then
				pumpkin = model
			end
		end
		expect(pumpkin:GetAttribute("CustomProp")).toBe(true)
		expect(pumpkin:FindFirstChild("Look")).toBeTruthy()
		expect(pumpkin.PrimaryPart.Name).toBe("Hitbox")
		expect(pumpkin.PrimaryPart.Anchored).toBe(false)
		expect(pumpkin.PrimaryPart:FindFirstChildOfClass("WeldConstraint").Part0).toBe(
			hider.Character.HumanoidRootPart
		)
		expect(w.CollectionService:HasTag(pumpkin, "HidingDecoy")).toBe(false)
		-- F8 > Apply custom props in the middle of the round leaves the round alone: the
		-- hider's pumpkin stays welded on (a swapped copy would stand still, never tagged).
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		local _, message = Swap.Props()
		expect(message).toMatch("a round is using")
		expect(pumpkin.Parent).toBe(map.Model.HiderPumpkins)
		expect(pumpkin.PrimaryPart:FindFirstChildOfClass("WeldConstraint").Part0).toBe(
			hider.Character.HumanoidRootPart
		)
		for _, decoy in decoys do
			expect(decoy:IsDescendantOf(map.Model)).toBe(true)
		end
		-- Let the seekers out, then shoot a decoy and the hider.
		rt:advance(Config.HideSeek.HeadStart + 0.5)
		local shoot = RS.Remotes.HideSeekShoot
		local events = RS.Remotes.HideSeekEvent
		local function shootAt(target)
			seeker.Character:PivotTo(w.CFrame.new(target + w.Vector3.new(12, 1.5, 0), target))
			local gun = seeker.Backpack:FindFirstChildOfClass("Tool")
				or seeker.Character:FindFirstChildOfClass("Tool")
			gun.Parent = seeker.Character
			rt:fireServer(shoot, seeker, target)
		end
		local function results(): { string }
			local list = {}
			for _, call in rt:calls("RemoteEvent", "FireAllClients") do
				if call.instance == events and call.args[1] == "Shot" then
					table.insert(list, call.args[2].Result)
				end
			end
			return list
		end
		local decoy
		for _, d in decoys do
			if d.Parent and d.Parent.Name == "Decoys" then
				decoy = d
				break
			end
		end
		shootAt(decoy.PrimaryPart.Position)
		expect(results()[1]).toBe("Decoy")
		rt:advance(Config.HideSeek.Gun.FireCooldown + Config.HideSeek.Gun.DecoyPenalty + 0.5)
		shootAt(pumpkin.PrimaryPart.Position)
		expect(results()[2]).toBe("Hider")
		expect(hider:GetAttribute("HideSeekRole")).toBe("Seeker")
		HideSeek.Cleanup()
	end)
end)

describe("Swap tool (src/server/Tools/Swap.luau)", function()
	it("swaps a saved hub and a baked map, keeps what the game needs, and can revert", function()
		local w = world()
		local rt = w.rt
		local Bake = rt:require("ServerScriptService.Server.Tools.Bake")
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		local hub = Bake.Hub()
		Bake.Lock()
		Bake.Map("PumpkinFarm")
		local baked = w.ServerStorage.Maps.PumpkinFarm
		local function count(root, name: string, custom: boolean): number
			local n = 0
			for _, m in w.props(root) do
				if
					m:GetAttribute("PropName") == name
					and (m:GetAttribute("CustomProp") == true) == custom
				then
					n += 1
				end
			end
			return n
		end
		local lanterns = count(hub, "JackOLantern", false)
		local decoys = #w.tagged("HidingDecoy", baked)
		expect(lanterns).toBeGreaterThan(20)
		expect(decoys).toBeGreaterThan(100)
		local widths = {}
		for _, decoy in w.tagged("HidingDecoy", baked) do
			widths[decoy:GetAttribute("PumpkinWidth")] = true
		end

		-- Nothing in Custom.Props: nothing changes.
		local none = Swap.Props()
		expect(none).toBe(0)

		local lanternModel = w.custom("JackOLantern")
		w.custom("HidingPumpkin")
		w.custom("ParkourPumpkin")
		local changed = Swap.Props()
		expect(changed).toBeGreaterThanOrEqual(lanterns + decoys + w.parkourPumpkins)
		expect(count(hub, "JackOLantern", false)).toBe(0)
		expect(count(hub, "JackOLantern", true)).toBeGreaterThan(0)
		expect(count(hub, "ParkourPumpkin", true)).toBe(w.parkourPumpkins)
		-- The baked decoys are your model now, still decoys with their sizes, and a hitbox.
		local swappedDecoys = w.tagged("HidingDecoy", baked)
		expect(#swappedDecoys).toBe(decoys)
		for _, decoy in swappedDecoys do
			expect(decoy:GetAttribute("CustomProp")).toBe(true)
			expect(decoy.Name).toBe("Pumpkin")
			expect(widths[decoy:GetAttribute("PumpkinWidth")]).toBe(true)
			expect(decoy.PrimaryPart.Name).toBe("Hitbox")
		end
		-- Parkour lids stay, hidden under your pumpkin.
		local hidden = 0
		for _, step in hub.Parkour.Course:GetChildren() do
			if step.Name:match("_Pumpkin$") then
				expect(step.PrimaryPart.Transparency).toBe(1)
				hidden += 1
			end
		end
		expect(hidden).toBe(w.parkourPumpkins)
		-- The built ones are kept as backups (never counted as working pieces).
		local backups = w.ServerStorage:FindFirstChild("PropBackups")
		expect(#backups:GetChildren()).toBeGreaterThanOrEqual(lanterns + decoys + w.parkourPumpkins)
		for _, d in backups:GetChildren() do
			expect(#w.CollectionService:GetTags(d)).toBe(0)
		end
		-- The game still loads the baked map (with your decoys).
		local loaded = w.MapService.Load("PumpkinFarm")
		expect(loaded.Id).toBe("PumpkinFarm")
		expect(#w.tagged("HidingDecoy", loaded.Model)).toBe(decoys)
		w.MapService.Unload()

		-- Running it again gives fresh copies (so changes to your model show), backups kept.
		lanternModel.Look.Size = w.Vector3.new(2, 6, 2)
		local again = Swap.Props()
		expect(again).toBe(changed)
		expect(#backups:GetChildren()).toBeGreaterThanOrEqual(lanterns + decoys + w.parkourPumpkins)

		-- Take the jack-o'-lantern out of Custom.Props and revert: the built ones come back.
		lanternModel:Destroy()
		Swap.Props({ Revert = true })
		expect(count(hub, "JackOLantern", true)).toBe(0)
		expect(count(hub, "JackOLantern", false)).toBe(lanterns)
		expect(#w.tagged("HidingDecoy", baked)).toBe(decoys) -- untouched: still custom
		expect(count(baked, "HidingPumpkin", true)).toBe(decoys)
		-- A Locked hub stays Locked, and keeps its tagged pieces.
		expect(hub:GetAttribute("Locked")).toBe(true)
		for _, tag in { "ReadyPad", "HubSpawn", "ShopKeeper", "ParkourStart" } do
			expect(#w.tagged(tag, hub)).toBeGreaterThan(0)
		end
	end)

	it("Replace swaps everything with a name, at its size and spot, keeping tags", function()
		local w = world()
		local rt, Vector3, CFrame = w.rt, w.Vector3, w.CFrame
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		-- Three things called "Thing": a tagged model, a plain part (in a map) and a pad.
		local tall = rt:create("Model", { Name = "Thing" }, rt.workspace)
		rt:create("Part", {
			Name = "Body",
			Size = Vector3.new(2, 4, 2),
			CFrame = CFrame.new(10, 2, 0),
		}, tall)
		tall.WorldPivot = CFrame.new(10, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		tall:SetAttribute("Foo", 7)
		w.CollectionService:AddTag(tall, "HidingDecoy")
		local maps = w.ServerStorage:FindFirstChild("Maps")
		local inMap = rt:create("Part", {
			Name = "Thing",
			Size = Vector3.new(1, 3, 1),
			CFrame = CFrame.new(20, 1.5, 0),
		}, maps)
		local pad = rt:create("Part", { Name = "Thing", Size = Vector3.new(4, 1, 4) }, rt.workspace)
		w.CollectionService:AddTag(pad, "ReadyPad")
		-- The new look: a squat model with its pivot in the middle.
		local new = w.model("MyThing")
		new.Parent = rt.workspace
		local count = Swap.Replace("Thing", new)
		expect(count).toBe(2)
		expect(pad.Parent).toBe(rt.workspace) -- a working part is left alone
		expect(new.Parent).toBe(rt.workspace) -- the model you gave is never replaced
		local replaced = {}
		for _, d in rt.workspace:GetChildren() do
			if d.Name == "Thing" and d:IsA("Model") then
				table.insert(replaced, d)
			end
		end
		expect(#replaced).toBe(1)
		local copy = replaced[1]
		expect(copy:FindFirstChild("Look")).toBeTruthy()
		expect(copy:GetAttribute("Foo")).toBe(7)
		expect(w.CollectionService:HasTag(copy, "HidingDecoy")).toBe(true)
		local low, high = w.CustomAssets.VisibleBox(copy)
		expect(high.Y - low.Y).toBeNear(4, 0.02) -- the old one's height
		expect(low.Y).toBeNear(0, 0.02) -- standing where it stood
		expect((low + high).X / 2).toBeNear(10, 0.02)
		expect(copy:GetPivot().LookVector).toBeNear(tall.WorldPivot.LookVector, 1e-3)
		local mapCopy = maps:FindFirstChild("Thing")
		expect(mapCopy:IsA("Model")).toBe(true)
		local mlow, mhigh = w.CustomAssets.VisibleBox(mapCopy)
		expect(mhigh.Y - mlow.Y).toBeNear(3, 0.02)
		-- Nothing with that name: nothing happens.
		expect(Swap.Replace("NoSuchThing", new)).toBe(0)
		expect(function()
			Swap.Replace("Thing", nil :: any)
		end).toThrow("Model or a Part")
	end)

	it("Replace leaves props and the parts inside them alone", function()
		local w = world()
		local rt = w.rt
		local Bake = rt:require("ServerScriptService.Server.Tools.Bake")
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		local hub = Bake.Hub()
		Bake.Map("PumpkinPatch")
		Bake.Map("PumpkinFarm")
		local function named(name: string): number
			local n = 0
			for _, root in { rt.workspace, w.ServerStorage.Maps } do
				for _, d in root:GetDescendants() do
					if d.Name == name then
						n += 1
					end
				end
			end
			return n
		end
		local mine = w.model("MyRock")
		mine.Parent = rt.workspace
		-- A prop name: nothing changes (a jack-o'-lantern's core part and the Hide & Seek
		-- decoys are called Pumpkin too), and it says to use Custom.Props instead.
		local pumpkins = named("Pumpkin")
		expect(pumpkins).toBeGreaterThan(100)
		local count, message = Swap.Replace("Pumpkin", mine)
		expect(count).toBe(0)
		expect(message).toMatch("Custom > Props")
		expect(named("Pumpkin")).toBe(pumpkins)
		-- A part inside a prop (each gravestone's slab is called Tombstone): left alone.
		local slabs = named("Tombstone")
		expect(slabs).toBeGreaterThan(20)
		count, message = Swap.Replace("Tombstone", mine)
		expect(count).toBe(0)
		expect(message).toMatch("Gravestone")
		expect(named("Tombstone")).toBe(slabs)
		-- The docs' example name: nothing the game builds is called Rock, so only your own
		-- are replaced (two placed by hand), not one hidden inside a prop.
		expect(named("Rock")).toBe(0)
		for i = 1, 2 do
			rt:create("Part", {
				Name = "Rock",
				Size = w.Vector3.new(3, 2, 3),
				CFrame = w.CFrame.new(40 + i * 6, 1, 40),
			}, hub)
		end
		local gravestone
		for _, m in w.props(w.ServerStorage.Maps.PumpkinPatch) do
			if m:GetAttribute("PropName") == "Gravestone" then
				gravestone = m
				break
			end
		end
		local inProp = rt:create("Part", { Name = "Rock" }, gravestone)
		count = Swap.Replace("Rock", mine)
		expect(count).toBe(2)
		expect(inProp.Parent).toBe(gravestone)
		local copies = 0
		for _, d in hub:GetChildren() do
			if d.Name == "Rock" and d:IsA("Model") and d:FindFirstChild("Look") then
				copies += 1
			end
		end
		expect(copies).toBe(2)
	end)

	it("gives one thing, or every copy, the look of a Toolbox model", function()
		local w = world()
		local rt = w.rt
		local Bake = rt:require("ServerScriptService.Server.Tools.Bake")
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		local hub = Bake.Hub()
		Bake.Lock()
		-- (Lune can't download from the Toolbox: a fake download, named after its code)
		local downloads = 0
		Swap.LoadToolbox = function(id: number)
			downloads += 1
			return w.model("Download" .. id), nil
		end
		local function pumpkins(): { any }
			local list = {}
			for _, m in w.props(hub) do
				if m:GetAttribute("PropName") == "Pumpkin" then
					table.insert(list, m)
				end
			end
			return list
		end
		local before = pumpkins()
		expect(#before).toBeGreaterThan(5)

		-- One pumpkin (clicked on one of its parts), moved by hand, gets a look of its own.
		local chosen = before[1]
		chosen:PivotTo(chosen:GetPivot() + w.Vector3.new(0, 0, 5))
		local spot = chosen:GetPivot().Position
		local changed = Swap.Selected("https://create.roblox.com/store/asset/111111/Spooky", {
			chosen:FindFirstChildWhichIsA("BasePart", true),
		})
		expect(changed).toBe(1)
		local props = rt:find("ReplicatedStorage.Custom.Props")
		expect(props:FindFirstChild("Pumpkin_111111"):GetAttribute("ToolboxId")).toBe(111111)
		local mine
		for _, m in pumpkins() do
			if m:GetAttribute("CustomModel") == "Pumpkin_111111" then
				expect(mine).toBe(nil)
				mine = m
			else
				expect(m:GetAttribute("CustomProp")).toBe(nil) -- every other copy unchanged
			end
		end
		expect(mine.Look).toBeTruthy()
		expect((mine:GetPivot().Position - spot).Magnitude).toBeLessThan(0.01) -- stays moved

		-- Every pumpkin gets another Toolbox model; the one with its own look keeps it.
		local all = Swap.Toolbox("Pumpkin", 222222)
		expect(all).toBeGreaterThanOrEqual(#before)
		expect(props.Pumpkin:GetAttribute("ToolboxId")).toBe(222222)
		local own = 0
		for _, m in pumpkins() do
			expect(m:GetAttribute("CustomProp")).toBe(true)
			if m:GetAttribute("CustomModel") == "Pumpkin_111111" then
				own += 1
				expect((m:GetPivot().Position - spot).Magnitude).toBeLessThan(0.01)
			end
		end
		expect(own).toBe(1)
		-- A second Toolbox model for the same name keeps the first as a backup.
		Swap.Toolbox("Pumpkin", 333333)
		expect(props.Pumpkin:GetAttribute("ToolboxId")).toBe(333333)
		expect(w.ServerStorage.CustomBackups.Pumpkin:GetAttribute("ToolboxId")).toBe(222222)

		-- A parkour step: its pumpkin look changes, the lid you land on stays and keeps working.
		local step = hub.Parkour.Course:FindFirstChild("Step02_Pumpkin")
		expect(Swap.Selected(444444, { step })).toBe(1)
		expect(step.PrimaryPart.Transparency).toBe(1)
		expect(step.PrimaryPart.CanCollide).toBe(true)
		local look = step:FindFirstChild("ParkourPumpkin", true)
		expect(look:GetAttribute("CustomModel")).toBe("ParkourPumpkin_444444")

		-- A pack (a folder of 3 trees) is spread over the copies: every kind is used, in turn.
		Swap.LoadToolbox = function(id: number)
			local pack = rt:create("Model", { Name = "Pack" })
			local folder = rt:create("Folder", { Name = "Trees" }, pack)
			for k = 1, 3 do
				local tree = w.model("Tree" .. k)
				tree.Parent = folder
			end
			return pack, nil
		end
		local trees = {}
		for _, m in w.props(hub) do
			if m:GetAttribute("PropName") == "DeadTree" then
				table.insert(trees, m)
			end
		end
		expect(#trees).toBeGreaterThanOrEqual(3)
		expect(Swap.Selected(777777, trees)).toBe(#trees)
		local kinds = {}
		for _, m in w.props(hub) do
			if m:GetAttribute("PropName") == "DeadTree" then
				kinds[m:GetAttribute("CustomModel")] = (kinds[m:GetAttribute("CustomModel")] or 0)
					+ 1
			end
		end
		for _, name in { "DeadTree_777777", "DeadTree_777777_2", "DeadTree_777777_3" } do
			expect(kinds[name]).toBeGreaterThanOrEqual(1)
			expect(props:FindFirstChild(name)).toBeTruthy()
		end
		-- Swap.Toolbox with a pack: every copy of the name, the kinds taking turns.
		Swap.Toolbox("Barrel", 888888)
		local barrelKinds = {}
		for _, m in w.props(hub) do
			if m:GetAttribute("PropName") == "Barrel" then
				expect(m:GetAttribute("CustomProp")).toBe(true)
				barrelKinds[m:GetAttribute("CustomModel") or "Barrel"] = true
			end
		end
		expect(barrelKinds.Barrel).toBe(true)
		expect(barrelKinds.Barrel_2).toBe(true)

		-- One secret pumpkin: only that egg changes, and it still counts as an egg.
		Swap.LoadToolbox = function(id: number)
			return w.model("Download" .. id), nil
		end
		local function egg(id: string): any
			for _, part in w.tagged("EasterEgg", hub) do
				if part:GetAttribute("EggId") == id then
					return part
				end
			end
			return nil
		end
		expect(egg("ForestGhost")).toBeTruthy()
		expect(Swap.Egg("ForestGhost", 999999)).toBe(1)
		expect(props:FindFirstChild("EggForestGhost")).toBeTruthy()
		local ghost = egg("ForestGhost")
		expect(ghost.Parent:GetAttribute("CustomProp")).toBe(true)
		expect(ghost:GetAttribute("Coins")).toBeGreaterThan(0)
		expect(egg("PhotoGhost").Parent:GetAttribute("CustomProp")).toBe(nil) -- the other ghost egg
		-- A Toolbox model with a model inside (a lollipop): the egg part sits right in the egg's
		-- model, so collecting it hides all of it; doing it again replaces the whole egg.
		Swap.LoadToolbox = function(id: number)
			local outer = rt:create("Model", { Name = "Outer" })
			local inner = w.model("Inner")
			inner.Parent = outer
			rt:create("Part", { Name = "Stick", Size = w.Vector3.new(0.2, 2, 0.2) }, inner)
			return outer, nil
		end
		for _ = 1, 2 do
			expect(Swap.Egg("SpawnLolly", 121212)).toBe(1)
		end
		local lolly = egg("SpawnLolly")
		expect(lolly.Parent.PrimaryPart).toBe(lolly)
		expect(lolly.Parent.Parent.Name).toBe("EasterEggs")
		local lollies = 0
		for _, part in w.tagged("EasterEgg", hub) do
			if part:GetAttribute("EggId") == "SpawnLolly" then
				lollies += 1
			end
		end
		expect(lollies).toBe(1)
		expect(Swap.Egg("NoSuchEgg", 999999)).toBe(0)

		-- Something holding several things, or a bad code, changes nothing.
		local n, message = Swap.Selected(555555, { hub.Parkour.Course.Step01_Start })
		expect(n).toBe(0)
		expect(message:find("several things", 1, true)).toBeTruthy()
		local downloaded = downloads
		expect(Swap.Toolbox("Pumpkin", "pumpkin please")).toBe(0)
		expect(downloads).toBe(downloaded)
	end)

	it("swaps a baked map's decoration to a walk-through custom model", function()
		-- (a map baked before props remembered PropVisual swaps the same way)
		local w = world()
		local rt = w.rt
		local Bake = rt:require("ServerScriptService.Server.Tools.Bake")
		local Swap = rt:require("ServerScriptService.Server.Tools.Swap")
		Bake.Map("PumpkinPatch")
		local baked = w.ServerStorage.Maps.PumpkinPatch
		local field = 0
		for _, m in w.props(baked) do
			if m:GetAttribute("PropName") == "Pumpkin" then
				field += 1
				if field % 2 == 0 then
					m:SetAttribute("PropVisual", nil) -- an older bake
				end
			end
		end
		expect(field).toBeGreaterThan(20)
		local solid = w.custom("Pumpkin")
		solid.Look.CanCollide = true
		solid.Look.CanQuery = true
		Swap.Props()
		local swapped = 0
		for _, m in w.props(baked) do
			if m:GetAttribute("PropName") == "Pumpkin" then
				swapped += 1
				expect(m:GetAttribute("CustomProp")).toBe(true)
				expect(m.Look.CanCollide).toBe(false)
				expect(m.Look.CanQuery).toBe(false)
			end
		end
		expect(swapped).toBe(field)
	end)
end)
