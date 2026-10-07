-- The lobby parkour course ("Spooky Sky Climb"): the course list in Config.Parkour is valid
-- and every jump is doable, ParkourLogic (jump maths, checkpoint order, times, cooldowns),
-- the built section (tags, Index order, inside its zone) and ParkourService on a running
-- server (start, checkpoints in order, falls and slime, anti-teleport, finish rewards,
-- cooldown, Go to start, rounds, respawns, admin reset, a saved hub with no course).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

-- One game for the tests that don't run the server (fewer games = a faster spec).
local shared = Runtime.new()

describe("Config.Parkour.Course", function()
	local rt = shared
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Logic = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local course = Config.Parkour.Course

	it("gives every step a known Kind and an Offset", function()
		expect(#course).toBeGreaterThan(10)
		for i, step in course do
			if not table.find(Logic.Kinds, step.Kind) then
				error(("line %d has Kind %s"):format(i, tostring(step.Kind)))
			end
			expect(typeof(step.Offset)).toBe("Vector3")
			if step.Size ~= nil then
				expect(typeof(step.Size)).toBe("Vector3")
			end
			if step.Rotation ~= nil then
				local kind = typeof(step.Rotation)
				expect(kind == "Vector3" or kind == "number").toBe(true)
			end
		end
		for _, kind in Logic.Kinds do
			expect(typeof(Config.Parkour.Sizes[kind])).toBe("Vector3")
		end
	end)

	it("starts at the Start, ends at the Finish, with a checkpoint every 6-8 jumps", function()
		local jumps = {}
		local checkpoints = 0
		local since = 0 -- jumps since the start or the last checkpoint
		for _, step in course do
			if step.Kind == "Hazard" then
				continue
			end
			table.insert(jumps, step)
			if #jumps > 1 then
				since += 1
			end
			if step.Kind == "Checkpoint" or step.Kind == "Finish" then
				if since < 6 or since > 8 then
					error(
						("%d jumps before checkpoint %d (want 6-8)"):format(since, checkpoints + 1)
					)
				end
				since = 0
			end
			if step.Kind == "Checkpoint" then
				checkpoints += 1
			end
		end
		expect(jumps[1].Kind).toBe("Start")
		expect(jumps[#jumps].Kind).toBe("Finish")
		expect(checkpoints).toBe(7) -- 8 stages: each one after the first starts at a checkpoint
	end)

	it("has about 60 jumps, each one doable and easy (no spicy ones)", function()
		local rules = Config.Parkour.Jumps
		local previous: number? = nil
		local jumps, spicy, hardest = 0, 0, 0
		for i, step in course do
			if step.Kind == "Hazard" then
				continue
			end
			if previous then
				local gap, rise = Logic.Jump(
					course[previous],
					Logic.StepCFrame(course, previous),
					step,
					Logic.StepCFrame(course, i)
				)
				local isSpicy = step.Spicy == true
				jumps += 1
				if isSpicy then
					spicy += 1
				end
				local maxGap = if isSpicy then rules.SpicyMaxGap else rules.MaxGap
				local maxRise = if isSpicy then rules.SpicyMaxRise else rules.MaxRise
				expect(maxGap).toBeLessThanOrEqual(10)
				expect(maxRise).toBeLessThanOrEqual(5.5)
				if gap > maxGap or rise > maxRise then
					error(("%s: gap %.1f, rise %.1f"):format(Logic.StepName(course, i), gap, rise))
				end
				local safety = if isSpicy then rules.SpicySafety else rules.Safety
				if gap > Logic.Reach(rise) * safety then
					error(
						("%s: %.1f across, %.1f up is too hard"):format(
							Logic.StepName(course, i),
							gap,
							rise
						)
					)
				end
				expect(gap).toBeGreaterThanOrEqual(rules.MinGap)
				hardest = math.max(hardest, gap / Logic.Reach(rise))
			end
			previous = i
		end
		T.note(
			("%d jumps, %d spicy, the hardest needs %d%% of a jump"):format(
				jumps,
				spicy,
				hardest * 100
			)
		)
		expect(jumps).toBeGreaterThanOrEqual(55)
		expect(jumps).toBeLessThanOrEqual(65)
		expect(spicy).toBe(0)
		expect(hardest).toBeLessThanOrEqual(0.7) -- still easy at the top
	end)

	it("passes every check and fits in the parkour zone", function()
		local problems = Logic.Check(course, Lobby.ZoneSize("Parkour"))
		if #problems > 0 then
			error(table.concat(problems, "\n"))
		end
	end)

	it("explains a broken course", function()
		local Vector3 = rt.env.Vector3
		local broken = table.clone(course)
		broken[2] = table.clone(broken[2])
		broken[2].Offset = broken[2].Offset + Vector3.new(0, 0, 20) -- far away
		local problems = Logic.Check(broken, Lobby.ZoneSize("Parkour"))
		expect(#problems).toBeGreaterThan(0)
		expect(Logic.Check({}, nil)[1]).toMatch("empty")
		local noFinish = table.clone(course)
		table.remove(noFinish, #noFinish)
		expect(table.concat(Logic.Check(noFinish), " ")).toMatch("Finish")
		local unknown = table.clone(course)
		unknown[3] = { Kind = "Trampoline", Offset = Vector3.zero }
		expect(table.concat(Logic.Check(unknown), " ")).toMatch("unknown Kind")
		-- A gravestone hanging just over a jump: players would bump their heads mid-jump.
		local low = { Kind = "Start", Offset = Vector3.new(0, 1, 0) }
		local lowCourse = {
			low,
			{ Kind = "Platform", Offset = Vector3.new(0, 2, 9) },
			{ Kind = "Grave", Offset = Vector3.new(0, 14, 5), Size = Vector3.new(4, 7.5, 3) },
			{ Kind = "Checkpoint", Offset = Vector3.new(0, 3, 20) },
			{ Kind = "Finish", Offset = Vector3.new(0, 4, 30) },
		}
		expect(table.concat(Logic.Check(lowCourse), " ")).toMatch("hangs too low")
		lowCourse[3] = table.clone(lowCourse[3])
		lowCourse[3].Offset = Vector3.new(0, 2 + 7.5 + Config.Parkour.Jumps.Headroom + 0.5, 5)
		expect(table.concat(Logic.Check(lowCourse), " ")).never.toMatch("hangs too low")
	end)
end)

describe("SpeedCheck (the anti-teleport maths for parkour and ScareMaze)", function()
	local rt = shared
	local V = rt.env.Vector3
	local SpeedCheck = rt:require("ReplicatedStorage.Shared.SpeedCheck")
	local limits =
		{ MaxSpeed = 40, Slack = 10, MaxRiseSpeed = 14, RiseSlack = 8, WindowSeconds = 1 }

	it("lets running, jumping and falling through, but not teleports or flying up", function()
		local check = SpeedCheck.new()
		expect(SpeedCheck.Step(check, V.new(0, 0, 0), 0, limits)).toBe(false) -- first look
		-- Running at 30 studs a second for 2 seconds, with a jump.
		local t = 0
		for i = 1, 20 do
			t = i * 0.1
			local y = if i == 5 then 6 else 0
			expect(SpeedCheck.Step(check, V.new(i * 3, y, 0), t, limits)).toBe(false)
		end
		-- Falling 50 studs at once is fine.
		expect(SpeedCheck.Step(check, V.new(60, -50, 0), t + 0.1, limits)).toBe(false)
		-- A teleport 100 studs sideways is too fast, and isn't remembered.
		local last = check.Last
		expect(SpeedCheck.Step(check, V.new(160, -50, 0), t + 0.2, limits)).toBe(true)
		expect(check.Last).toBe(last)
		-- 20 studs straight up in a tenth of a second: too fast.
		expect(SpeedCheck.Step(check, V.new(60, -30, 0), t + 0.2, limits)).toBe(true)
		-- After a Reset (the server moved them) it measures from the new spot.
		SpeedCheck.Reset(check, V.new(500, 0, 0), t + 0.3)
		expect(SpeedCheck.Step(check, V.new(503, 0, 0), t + 0.4, limits)).toBe(false)
	end)

	it("counts the slack once per window, not on every check", function()
		local check = SpeedCheck.new()
		SpeedCheck.Reset(check, V.new(0, 0, 0), 0)
		-- 13 studs every 0.1 s: each hop alone fits MaxSpeed x 0.1 + Slack = 14...
		expect(SpeedCheck.TooFast(V.new(0, 0, 0), V.new(13, 0, 0), 0.1, limits)).toBe(false)
		local caught = nil
		for i = 1, 10 do
			if SpeedCheck.Step(check, V.new(i * 13, 0, 0), i * 0.1, limits) then
				caught = i
				break
			end
		end
		-- ...but 130 studs a second is caught straight away.
		expect(caught).toBe(2)
	end)
end)

describe("ParkourLogic", function()
	local rt = shared
	local Logic = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local Vector3 = rt.env.Vector3
	local CFrame = rt.env.CFrame

	it("sorts checkpoint indexes and checks they are touched in order", function()
		local order = Logic.Order({ 3, 1, 2, 2 })
		expect(order).toEqual({ 1, 2, 3 })
		expect(Logic.Touch(order, 0, 1)).toBe("Next")
		expect(Logic.Touch(order, 0, 2)).toBe("Skipped")
		expect(Logic.Touch(order, 1, 1)).toBe("Old")
		expect(Logic.Touch(order, 1, 2)).toBe("Next")
		expect(Logic.Touch(order, 1, 3)).toBe("Skipped")
		expect(Logic.Touch(order, 3, 2)).toBe("Old")
		expect(Logic.CanFinish(order, 2)).toBe(false)
		expect(Logic.CanFinish(order, 3)).toBe(true)
		-- Gaps in the numbering are fine: 1 then 5.
		local odd = Logic.Order({ 5, 1 })
		expect(Logic.Touch(odd, 1, 5)).toBe("Next")
	end)

	it("knows new bests, cooldowns and how to write times", function()
		expect(Logic.IsNewBest(0, 50)).toBe(true)
		expect(Logic.IsNewBest(40, 50)).toBe(false)
		expect(Logic.IsNewBest(60, 50)).toBe(true)
		expect(Logic.RewardWait(0, 1000, 20)).toBe(0)
		expect(Logic.RewardWait(1000, 1000 + 3600, 20)).toBe(19 * 3600)
		expect(Logic.RewardWait(1000, 1000 + 20 * 3600, 20)).toBe(0)
		expect(Logic.FormatTime(65.321)).toBe("1:05.32")
		expect(Logic.FormatTime(59.999)).toBe("1:00.00")
		expect(Logic.FormatTime(7.5)).toBe("0:07.50")
		expect(Logic.FormatWait(18720)).toBe("5h 12m")
		expect(Logic.FormatWait(600)).toBe("10m")
		expect(Logic.FormatWait(42)).toBe("42s")
	end)

	it("measures jumps between pieces", function()
		expect(Logic.Reach(0)).toBeGreaterThan(Logic.Reach(3))
		expect(Logic.Reach(3)).toBeGreaterThan(Logic.Reach(5))
		expect(Logic.Reach(8)).toBe(0) -- higher than anyone can jump
		local a = { Kind = "Platform", Offset = Vector3.zero, Size = Vector3.new(4, 1, 4) }
		local b = { Kind = "Platform", Offset = Vector3.new(10, 2, 0), Size = Vector3.new(4, 1, 4) }
		local gap, rise = Logic.Jump(a, CFrame.new(0, 0, 0), b, CFrame.new(10, 2, 0))
		expect(gap).toBeNear(6, 1e-6)
		expect(rise).toBeNear(2, 1e-6)
		-- Round pieces measure to their round edge.
		local c = { Kind = "Candy", Offset = Vector3.zero, Size = Vector3.new(6, 1, 6) }
		gap = Logic.Jump(c, CFrame.new(0, 0, 0), c, CFrame.new(0, 0, -10))
		expect(gap).toBeNear(4, 1e-6)
		expect(Logic.TopY(CFrame.new(0, 5, 0), Vector3.new(4, 2, 4))).toBeNear(6, 1e-6)
	end)
end)

describe("The parkour section", function()
	local rt = shared
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local Lobby = rt:require("ReplicatedStorage.Shared.Lobby")
	local Logic = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout")
	local Section = rt:require("ServerScriptService.Server.Hub.Sections.Parkour")
	local CollectionService = rt.game:GetService("CollectionService")

	local function tagged(tag: string, root: any): { any }
		local list = {}
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(root) then
				table.insert(list, instance)
			end
		end
		return list
	end

	it("builds every piece with a readable name and the right tags", function()
		local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
		local zone = HubLayout.Zone("Parkour")
		local area = Section.Build(hub, zone)
		expect(area.Name).toBe("Parkour")
		local course = Config.Parkour.Course
		for i in course do
			local name = Logic.StepName(course, i)
			local model = area.Course:FindFirstChild(name)
			if not model then
				error("no " .. name)
			end
			expect(model.PrimaryPart).toBeTruthy()
		end
		expect(#tagged(Tags.ParkourStart, area)).toBe(1)
		expect(#tagged(Tags.ParkourFinish, area)).toBe(1)
		expect(#tagged(Tags.ParkourBoard, area)).toBe(1)
		expect(#tagged(Tags.ParkourHazard, area)).toBeGreaterThanOrEqual(1)
		-- Checkpoints numbered 1, 2, 3... in course order (and at the course positions).
		local checkpoints = tagged(Tags.ParkourCheckpoint, area)
		expect(#checkpoints).toBe(7)
		local n = 0
		for i, step in course do
			if step.Kind == "Checkpoint" then
				n += 1
				local pad = area.Course[Logic.StepName(course, i)].Pad
				expect(pad:HasTag(Tags.ParkourCheckpoint)).toBe(true)
				expect(pad:GetAttribute("Index")).toBe(n)
				expect(Logic.TopY(pad.CFrame, pad.Size)).toBeNear(
					Section.WorldCFrame(zone, i).Position.Y,
					0.01
				)
			end
		end
		-- Everything that does something is inside the parkour zone.
		for _, tag in
			{ Tags.ParkourStart, Tags.ParkourCheckpoint, Tags.ParkourFinish, Tags.ParkourHazard }
		do
			for _, part in tagged(tag, area) do
				if not Lobby.InZone(part.Position, "Parkour", 1) then
					error(part:GetFullName() .. " is outside the parkour zone")
				end
			end
		end
		-- The start pad faces into the course; checkpoints face the next piece.
		local start = tagged(Tags.ParkourStart, area)[1]
		expect(start.CFrame.UpVector).toBeNear(rt.env.Vector3.yAxis, 1e-4)
		local board = tagged(Tags.ParkourBoard, area)[1]
		expect(board.Board.Row1.Text).toBe(Config.Parkour.Text.BoardEmpty)
		hub:Destroy()
	end)

	-- Pieces you can see but walk through, and why. Everything else visible must be solid.
	local walkThrough = {
		Plaque = "words on a gravestone",
		Sign = "words on a checkpoint sign, above your head",
		NameBoard = "words on the start arch, above your head",
		Moss = "moss on a gravestone",
		Swirl = "a flat stripe painted on a candy",
		WingBone = "flat lines painted on a bat wing",
		PadCentre = "a flat inlay on a pad",
		Fang = "a face detail",
		Tooth = "a face detail",
		Rib = "a jack-o-lantern up on the arch or the board, out of reach",
		Stem = "a jack-o-lantern up on the arch or the board, out of reach",
	}

	-- Is `part` inside a model (below `root`) with this attribute?
	local function inside(part: any, root: any, attribute: string): boolean
		local node = part.Parent
		while node and node ~= root do
			if node:GetAttribute(attribute) == true then
				return true
			end
			node = node.Parent
		end
		return false
	end

	it("makes every piece you can see and bump into solid, without catching heads", function()
		local hub = rt:create("Model", { Name = "Hub" }, rt.workspace)
		local zone = HubLayout.Zone("Parkour")
		local area = Section.Build(hub, zone)
		local course = Config.Parkour.Course
		local Vector3 = rt.env.Vector3
		for i, step in course do
			local model = area.Course[Logic.StepName(course, i)]
			local top = Section.WorldCFrame(zone, i).Position.Y
			local lowest = top - Logic.Depth(step)
			local looks = false
			for _, part in model:GetDescendants() do
				if not part:IsA("BasePart") then
					continue
				end
				local inLook = inside(part, model, "PropLook")
				looks = looks or inLook
				local visible = part.Transparency < 0.6
					and part.Material ~= rt.env.Enum.Material.Neon
				if
					visible
					and not inLook
					and not part.CanCollide
					and not walkThrough[part.Name]
				then
					error(part:GetFullName() .. " can be seen but walked through")
				end
				if part.CanCollide then
					-- Nothing solid hangs lower than Config.Parkour.Hang says (the head-room check).
					for _, x in { -1, 1 } do
						for _, y in { -1, 1 } do
							for _, z in { -1, 1 } do
								local corner = part.CFrame:PointToWorldSpace(
									Vector3.new(
										x * part.Size.X / 2,
										y * part.Size.Y / 2,
										z * part.Size.Z / 2
									)
								)
								if corner.Y < lowest - 0.05 then
									error(
										("%s hangs %.2f studs below Config.Parkour.Hang.%s"):format(
											part:GetFullName(),
											lowest - corner.Y,
											step.Kind
										)
									)
								end
							end
						end
					end
				end
			end
			if looks then
				-- A look is only visual (it may be your own model): an invisible solid core
				-- stands in for it.
				local core = model:FindFirstChild("Core")
				expect(core and core.CanCollide).toBe(true)
			end
		end
		hub:Destroy()
	end)

	it("builds nothing when the feature is off", function()
		local saved = Config.Features.Parkour
		Config.Features.Parkour = false
		local hub = rt:create("Model", { Name = "Hub2" })
		local ok, area = pcall(Section.Build, hub, HubLayout.Zone("Parkour"))
		Config.Features.Parkour = saved
		expect(ok).toBe(true)
		expect(#area:GetChildren()).toBe(0)
	end)
end)

describe("ParkourService", function()
	local rt = Runtime.new({ studio = true })
	local Vector3 = rt.env.Vector3
	local CFrame = rt.env.CFrame
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local Logic = rt:require("ReplicatedStorage.Shared.ParkourLogic")
	local CollectionService = rt.game:GetService("CollectionService")
	local ReplicatedStorage = rt.game:GetService("ReplicatedStorage")
	local services = "ServerScriptService.Server.Services."
	local HubService = rt:require(services .. "HubService")
	local DataService = rt:require(services .. "DataService")
	local ShopService = rt:require(services .. "ShopService")
	local AdminService = rt:require(services .. "AdminService")
	local Parkour = rt:require(services .. "ParkourService")
	local cfg = Config.Parkour
	-- How many checkpoints the course has (7: one at the start of each stage after the first).
	local CHECKPOINTS = 0
	for _, step in cfg.Course do
		if step.Kind == "Checkpoint" then
			CHECKPOINTS += 1
		end
	end
	local player: any = nil

	local function first(tag: string): any
		return CollectionService:GetTagged(tag)[1]
	end
	local function checkpoint(index: number): any
		for _, pad in CollectionService:GetTagged(Tags.ParkourCheckpoint) do
			if pad:GetAttribute("Index") == index then
				return pad
			end
		end
		return nil
	end
	-- Where the root part is when standing on `part` (root 3 studs above the feet).
	local function spotOn(part: any): any
		local top = Logic.TopY(part.CFrame, part.Size)
		return Vector3.new(part.Position.X, top + 3, part.Position.Z)
	end
	local function root(): any
		return player.Character.HumanoidRootPart
	end
	-- Moves the character to `target` a few studs per check, like walking and jumping (and never
	-- climbing faster than a person can: the course is 90 studs tall).
	local function travel(target: any)
		local from = root().Position
		local d = target - from
		local flat = Vector3.new(d.X, 0, d.Z).Magnitude
		local steps = math.max(1, math.ceil(flat / 2.5), math.ceil(math.abs(d.Y) / 1.2))
		for s = 1, steps do
			player.Character:PivotTo(CFrame.new(from:Lerp(target, s / steps)))
			rt:advance(cfg.CheckSeconds)
		end
		rt:advance(cfg.CheckSeconds * 2)
	end
	local function events(kind: string): { any }
		local list = {}
		for _, call in rt:calls("RemoteEvent", "FireClient") do
			if
				call.instance.Name == "ParkourEvent"
				and call.args[1] == player
				and call.args[2] == kind
			then
				table.insert(list, call.args[3])
			end
		end
		return list
	end
	local function invoke(...): (any, any)
		local remote = ReplicatedStorage.Remotes.ParkourRequest
		return rt:invokeServer(remote, player, ...)
	end

	it("starts with the hub and makes its remotes", function()
		HubService.Start()
		DataService.Start()
		ShopService.Start()
		AdminService.Start()
		Parkour.Start()
		expect(ReplicatedStorage.Remotes:FindFirstChild("ParkourEvent")).toBeTruthy()
		expect(ReplicatedStorage.Remotes:FindFirstChild("ParkourRequest")).toBeTruthy()
		expect(first(Tags.ParkourStart)).toBeTruthy()
		player = rt:addPlayer({ Name = "Climber" })
		player.Character.Humanoid.HipHeight = 2
		rt:advance(1)
		expect(player:GetAttribute("DataReady")).toBe(true)
		expect(player:GetAttribute("ParkourBest")).toBe(0)
		expect(ReplicatedStorage:GetAttribute("ParkourCheckpoints")).toBe(CHECKPOINTS)
	end)

	it("tells you to use the start pad when you climb on without it", function()
		player.Character:PivotTo(CFrame.new(spotOn(checkpoint(1))))
		rt:advance(0.3)
		expect(#events("NeedStart")).toBe(1)
		expect(player:GetAttribute("ParkourRun")).toBe("")
		expect(Parkour.Run(player)).toBeNil()
		rt:advance(1)
		expect(#events("NeedStart")).toBe(1) -- not again straight away
		rt:advance(cfg.HintSeconds)
		expect(#events("NeedStart")).toBe(2)
	end)

	it("gets ready on the start pad and starts the clock when you leave it", function()
		player.Character:PivotTo(CFrame.new(spotOn(first(Tags.ParkourStart))))
		rt:advance(0.3)
		expect(player:GetAttribute("ParkourRun")).toBe("Ready")
		-- Jumping on the pad doesn't start the clock.
		player.Character:PivotTo(
			CFrame.new(spotOn(first(Tags.ParkourStart)) + Vector3.new(0, 6, 0))
		)
		rt:advance(0.3)
		expect(player:GetAttribute("ParkourRun")).toBe("Ready")
		local course = rt.workspace.Hub.Parkour.Course
		travel(spotOn(course.Step02_Pumpkin.PrimaryPart))
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		expect(#events("Start")).toBe(1)
		expect(player:GetAttribute("ParkourStarted")).toBeGreaterThan(0)
	end)

	it("only counts checkpoints in order", function()
		travel(spotOn(checkpoint(2)))
		expect(player:GetAttribute("ParkourReached")).toBe(0)
		expect(#events("Missed")).toBe(1)
		travel(spotOn(checkpoint(1)))
		expect(player:GetAttribute("ParkourReached")).toBe(1)
		local cp = events("Checkpoint")
		expect(#cp).toBe(1)
		expect(cp[1].Index).toBe(1)
		expect(cp[1].Count).toBe(CHECKPOINTS)
	end)

	it("sends you back to your checkpoint when you fall or touch slime", function()
		local pad = checkpoint(1)
		local ground = Vector3.new(pad.Position.X + 6, Config.Hub.Center.Y + 1 + 3, pad.Position.Z)
		player.Character:PivotTo(CFrame.new(ground))
		rt:advance(0.3)
		local back = events("Back")
		expect(#back).toBe(1)
		expect(back[1].Reason).toBe("Fall")
		expect(back[1].Checkpoint).toBe(1)
		expect((root().Position - spotOn(pad)).Magnitude).toBeLessThan(1)
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		rt:advance(cfg.TeleportGraceSeconds)
		local slime = first(Tags.ParkourHazard)
		local inSlime =
			Vector3.new(slime.Position.X, slime.Position.Y - slime.Size.Y / 2 + 3, slime.Position.Z)
		travel(inSlime + slime.CFrame.LookVector * (slime.Size.Z / 2 + 2)) -- just before it
		expect(#events("Back")).toBe(1)
		player.Character:PivotTo(CFrame.new(inSlime)) -- one step into the slime
		rt:advance(0.3)
		back = events("Back")
		expect(#back).toBe(2)
		expect(back[2].Reason).toBe("Hazard")
		expect((root().Position - spotOn(pad)).Magnitude).toBeLessThan(1)
		expect(player:GetAttribute("ParkourReached")).toBe(1)
		-- Landing on a lower loop of the spiral (well under your checkpoint, still high above
		-- the ground) is a fall too.
		rt:advance(cfg.TeleportGraceSeconds)
		local lower = spotOn(pad) - Vector3.new(0, cfg.FallBelowCheckpoint + 2, 0)
		player.Character:PivotTo(CFrame.new(lower))
		rt:advance(0.3)
		back = events("Back")
		expect(#back).toBe(3)
		expect(back[3].Reason).toBe("Fall")
		expect((root().Position - spotOn(pad)).Magnitude).toBeLessThan(1)
		-- Falling onto the start pad (it sits under the course) is a fall too, not a restart.
		rt:advance(cfg.TeleportGraceSeconds)
		local start = spotOn(first(Tags.ParkourStart))
		travel(Vector3.new(start.X, spotOn(pad).Y, start.Z)) -- over the start pad...
		player.Character:PivotTo(CFrame.new(start)) -- ...and a quick drop onto it
		rt:advance(0.3)
		back = events("Back")
		expect(#back).toBe(4)
		expect(back[4].Reason).toBe("Fall")
		expect((root().Position - spotOn(pad)).Magnitude).toBeLessThan(1)
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		expect(player:GetAttribute("ParkourReached")).toBe(1)
	end)

	it("doesn't count a finish that is too fast", function()
		rt:advance(cfg.TeleportGraceSeconds)
		for index = 2, CHECKPOINTS do
			travel(spotOn(checkpoint(index)))
		end
		expect(player:GetAttribute("ParkourReached")).toBe(CHECKPOINTS)
		local coins = DataService.Get(player).Coins
		local minSeconds = cfg.MinSeconds
		cfg.MinSeconds = 1000 -- (so this run surely counts as too fast)
		travel(spotOn(first(Tags.ParkourFinish)))
		cfg.MinSeconds = minSeconds
		local cancels = events("Cancel")
		expect(cancels[#cancels].Reason).toBe("Cheat")
		expect(#events("Finish")).toBe(0)
		expect(DataService.Get(player).Coins).toBe(coins)
		expect(player:GetAttribute("ParkourRun")).toBe("")
	end)

	it("needs every checkpoint before the finish", function()
		travel(spotOn(first(Tags.ParkourStart)))
		expect(player:GetAttribute("ParkourRun")).toBe("Ready")
		travel(spotOn(rt.workspace.Hub.Parkour.Course.Step02_Pumpkin.PrimaryPart))
		travel(spotOn(first(Tags.ParkourFinish)))
		expect(#events("NeedCheckpoints")).toBe(1)
		expect(#events("Finish")).toBe(0)
	end)

	it("rewards a real finish once per cooldown and saves the best time", function()
		local data = DataService.Get(player)
		local coins = data.Coins
		travel(spotOn(first(Tags.ParkourStart)))
		travel(spotOn(rt.workspace.Hub.Parkour.Course.Step02_Pumpkin.PrimaryPart))
		rt:advance(cfg.MinSeconds)
		for index = 1, CHECKPOINTS do
			travel(spotOn(checkpoint(index)))
		end
		travel(spotOn(first(Tags.ParkourFinish)))
		local finishes = events("Finish")
		expect(#finishes).toBe(1)
		local info = finishes[1]
		expect(info.Coins).toBe(cfg.Reward.Coins)
		expect(info.NewBest).toBe(true)
		expect(info.Time).toBeGreaterThanOrEqual(cfg.MinSeconds)
		expect(data.Coins).toBe(coins + cfg.Reward.Coins)
		expect(data.Parkour.Runs).toBe(1)
		expect(data.Parkour.Best).toBe(info.Time)
		expect(data.Parkour.LastReward).toBeGreaterThan(0)
		expect(player:GetAttribute("ParkourBest")).toBe(info.Time)
		expect(player:GetAttribute("ParkourRewardAt")).toBeGreaterThan(0)
		local board = first(Tags.ParkourBoard)
		expect(board.Board.Row1.Text).toMatch("Climber")

		-- Again straight away: a finish, but no coins until the cooldown is over.
		travel(spotOn(first(Tags.ParkourStart)))
		travel(spotOn(rt.workspace.Hub.Parkour.Course.Step02_Pumpkin.PrimaryPart))
		rt:advance(cfg.MinSeconds + 5)
		for index = 1, CHECKPOINTS do
			travel(spotOn(checkpoint(index)))
		end
		travel(spotOn(first(Tags.ParkourFinish)))
		finishes = events("Finish")
		expect(#finishes).toBe(2)
		expect(finishes[2].Coins).toBe(0)
		expect(finishes[2].NewBest).toBe(false)
		expect(finishes[2].Wait).toBeGreaterThan(0)
		expect(data.Coins).toBe(coins + cfg.Reward.Coins)
		expect(data.Parkour.Runs).toBe(2)
	end)

	it("stops a run that teleports", function()
		travel(spotOn(first(Tags.ParkourStart)))
		travel(spotOn(rt.workspace.Hub.Parkour.Course.Step02_Pumpkin.PrimaryPart))
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		player.Character:PivotTo(root().CFrame + Vector3.new(40, 0, 0))
		rt:advance(0.2)
		local cancels = events("Cancel")
		expect(cancels[#cancels].Reason).toBe("TooFast")
		expect(player:GetAttribute("ParkourRun")).toBe("")
	end)

	it("stops a run that flies straight up, or hops a little too far on every check", function()
		local step02 = rt.workspace.Hub.Parkour.Course.Step02_Pumpkin.PrimaryPart
		travel(spotOn(first(Tags.ParkourStart)))
		travel(spotOn(step02))
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		player.Character:PivotTo(root().CFrame + Vector3.new(0, 15, 0))
		rt:advance(0.2)
		local cancels = events("Cancel")
		expect(cancels[#cancels].Reason).toBe("TooFast")
		expect(player:GetAttribute("ParkourRun")).toBe("")
		-- 11 studs per check fits one check's SpeedSlack, but not a second's worth of them.
		travel(spotOn(first(Tags.ParkourStart)))
		travel(spotOn(step02))
		expect(player:GetAttribute("ParkourRun")).toBe("Running")
		local before = #events("Cancel")
		for _ = 1, 8 do
			player.Character:PivotTo(root().CFrame + Vector3.new(11, 0, 0))
			rt:advance(cfg.CheckSeconds)
			if player:GetAttribute("ParkourRun") == "" then
				break
			end
		end
		cancels = events("Cancel")
		expect(#cancels).toBe(before + 1)
		expect(cancels[#cancels].Reason).toBe("TooFast")
	end)

	it("stops on respawn and ignores players in a round", function()
		travel(spotOn(first(Tags.ParkourStart)))
		expect(player:GetAttribute("ParkourRun")).toBe("Ready")
		rt:spawnCharacter(player)
		player.Character.Humanoid.HipHeight = 2
		expect(Parkour.Run(player)).toBeNil()
		player:SetAttribute("InRound", true)
		player.Character:PivotTo(CFrame.new(spotOn(first(Tags.ParkourStart))))
		rt:advance(0.3)
		expect(player:GetAttribute("ParkourRun")).toBe("")
		rt:advance(cfg.RequestCooldown)
		local ok, message = invoke("GoToStart")
		expect(ok).toBe(false)
		expect(message).toBe(cfg.Text.InRound)
		player:SetAttribute("InRound", nil)
	end)

	it("takes you to the start from the lobby (checked on the server)", function()
		rt:advance(cfg.RequestCooldown)
		player.Character:PivotTo(CFrame.new(Config.Hub.Center + Vector3.new(0, 4, 20)))
		local ok, message = invoke("GoToStart")
		expect(ok).toBe(true)
		expect(message).toBe(cfg.Text.Teleported)
		expect((root().Position - spotOn(first(Tags.ParkourStart))).Magnitude).toBeLessThan(1)
		-- Too soon, wrong values, from far away.
		ok, message = invoke("GoToStart")
		expect(ok).toBe(false)
		expect(message).toBe(cfg.Text.Wait)
		rt:advance(cfg.RequestCooldown)
		expect((invoke(42))).toBe(false)
		rt:advance(cfg.RequestCooldown)
		expect((invoke("Fly"))).toBe(false)
		rt:advance(cfg.RequestCooldown)
		player.Character:PivotTo(CFrame.new(Config.Maps.Origin + Vector3.new(0, 5, 0)))
		ok, message = invoke("GoToStart")
		expect(ok).toBe(false)
		expect(message).toBe(cfg.Text.NotInLobby)
	end)

	it("resets your parkour save from the admin panel and forgets you when you leave", function()
		rt:advance(1)
		local remote = ReplicatedStorage.Remotes.AdminCommand
		local ok = rt:invokeServer(remote, player, "ParkourReset")
		expect(ok).toBe(true)
		expect(DataService.Get(player).Parkour.Best).toBe(0)
		expect(player:GetAttribute("ParkourBest")).toBe(0)
		expect(first(Tags.ParkourBoard).Board.Row1.Text).toBe(cfg.Text.BoardEmpty)
		-- F8 > "Reset my save" shows the fresh parkour numbers straight away too.
		local saved = DataService.Get(player)
		saved.Parkour.Best = 12.5
		saved.Parkour.Runs = 3
		player:SetAttribute("ParkourBest", 12.5) -- what the menu showed before the reset
		player:SetAttribute("ParkourRuns", 3)
		rt:advance(1)
		ok = rt:invokeServer(remote, player, "ResetSave")
		expect(ok).toBe(true)
		expect(DataService.Get(player).Parkour.Best).toBe(0)
		expect(player:GetAttribute("ParkourBest")).toBe(0)
		expect(player:GetAttribute("ParkourRuns")).toBe(0)
		expect(player:GetAttribute("ParkourRewardAt")).toBe(0)
		travel(spotOn(first(Tags.ParkourStart)))
		expect(Parkour.Run(player)).toBeTruthy()
		rt:removePlayer(player)
		expect(Parkour.Run(player)).toBeNil()
	end)
end)

describe("ParkourService on a saved hub without a course", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local Tags = rt:require("ReplicatedStorage.Shared.Tags")
	local CollectionService = rt.game:GetService("CollectionService")

	it("builds the course when the feature is switched on later", function()
		local saved = Config.Features.Parkour
		Config.Features.Parkour = false
		rt:require("ServerScriptService.Server.Services.HubService").Start()
		expect(#CollectionService:GetTagged(Tags.ParkourStart)).toBe(0)
		Config.Features.Parkour = true
		local ok, err =
			pcall(rt:require("ServerScriptService.Server.Services.ParkourService").Start)
		Config.Features.Parkour = saved
		if not ok then
			error(err)
		end
		expect(#CollectionService:GetTagged(Tags.ParkourStart)).toBe(1)
		expect(#CollectionService:GetTagged(Tags.ParkourCheckpoint)).toBe(7)
		expect(#rt.workspace.Hub:GetChildren()).toBeGreaterThan(3)
	end)
end)

describe("ParkourUI", function()
	local server = Runtime.new()
	server:require("ServerScriptService.Server.Services.ParkourService").Start()
	local client = Runtime.new({ client = true })
	client:replicateFrom(server)
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local text = Config.Parkour.Text
	local Client = client:find("StarterPlayer.StarterPlayerScripts.Client")
	local player = client.game:GetService("Players").LocalPlayer
	local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
	client:require(Client.Layout).Mount(gui)
	client:require(Client.PanelManager).Mount(gui)
	local MenuUI = client:require(Client.MenuUI)
	MenuUI.Mount(gui)
	client:require(Client.MenuTiles).Mount(gui)
	client:require(Client.ParkourUI).Mount(gui)
	client:advance(0.5)

	it("puts one Parkour tile in the Menu that opens the panel", function()
		local tiles = {}
		for _, child in gui.Menu.Tiles:GetChildren() do
			if child:GetAttribute("MenuTile") == "Parkour" then
				table.insert(tiles, child)
			end
		end
		expect(#tiles).toBe(1)
		client:fire(tiles[1], "Activated")
		expect(gui.ParkourPanel.Visible).toBe(true)
		expect(gui.ParkourPanel.Best.Text).toBe(text.NoBest)
		player:SetAttribute("ParkourBest", 65.32)
		client:advance(0.1)
		expect(gui.ParkourPanel.Best.Text).toBe(text.Best:format("1:05.32"))
		client:fire(gui.ParkourPanel.CloseButton, "Activated")
		expect(gui.ParkourPanel.Visible).toBe(false)
	end)

	it("shows the timer while you climb", function()
		expect(gui.ParkourTimer.Visible).toBe(false)
		player:SetAttribute("ParkourRun", "Ready")
		client:advance(0.1)
		expect(gui.ParkourTimer.Visible).toBe(true)
		expect(gui.ParkourTimer.Time.Text).toBe(text.Ready)
		player:SetAttribute("ParkourStarted", client.workspace:GetServerTimeNow() - 42.5)
		player:SetAttribute("ParkourRun", "Running")
		client:advance(0.1)
		expect(gui.ParkourTimer.Time.Text).toMatch("^0:42%.")
		player:SetAttribute("ParkourRun", "")
		client:advance(0.1)
		expect(gui.ParkourTimer.Visible).toBe(false)
	end)

	it("pops up checkpoints and the finish", function()
		local event = client:find("ReplicatedStorage.Remotes.ParkourEvent")
		client:fire(event, "OnClientEvent", "Checkpoint", { Index = 2, Count = 3 })
		expect(gui.ParkourPop.Visible).toBe(true)
		expect(gui.ParkourPop.Text).toBe(text.Checkpoint:format(2, 3))
		client:fire(event, "OnClientEvent", "Back", { Reason = "Hazard", Checkpoint = 0 })
		expect(gui.ParkourPop.Text).toBe(text.SlimedStart)
		client:fire(event, "OnClientEvent", "Finish", {
			Time = 61.5,
			Best = 61.5,
			NewBest = true,
			Coins = Config.Parkour.Reward.Coins,
			Wait = 72000,
		})
		expect(gui.ParkourFinish.Visible).toBe(true)
		expect(gui.ParkourFinish.Time.Text).toBe(text.FinishTime:format("1:01.50"))
		expect(gui.ParkourFinish.Best.Text).toBe(text.NewBest)
		client:fire(event, "OnClientEvent", "Nonsense", 42) -- ignored, no error
		client:advance(Config.Parkour.Screen.FinishSeconds + 1)
		expect(gui.ParkourFinish.Visible).toBe(false)
	end)

	it("keeps one refresh loop when the panel is closed and opened again quickly", function()
		local tile
		for _, child in gui.Menu.Tiles:GetChildren() do
			if child:GetAttribute("MenuTile") == "Parkour" then
				tile = child
			end
		end
		client:fire(tile, "Activated")
		client:advance(10) -- (the other tests' timers run out first)
		local waiting = client.scheduler:pending()
		for _ = 1, 3 do
			client:fire(gui.ParkourPanel.CloseButton, "Activated")
			client:advance(0.2)
			client:fire(tile, "Activated")
			client:advance(0.2)
		end
		client:advance(Config.UI.Motion.PopInSeconds) -- (the panel's pop-in tween ends)
		expect(gui.ParkourPanel.Visible).toBe(true)
		expect(client.scheduler:pending()).toBe(waiting) -- (a loop each time before the fix)
		-- Closed for longer than a second: the loop stops, and opening starts it again.
		client:fire(gui.ParkourPanel.CloseButton, "Activated")
		client:advance(1.5)
		expect(client.scheduler:pending()).toBe(waiting - 1)
		client:fire(tile, "Activated")
		client:advance(0.2 + Config.UI.Motion.PopInSeconds)
		expect(client.scheduler:pending()).toBe(waiting)
		client:fire(gui.ParkourPanel.CloseButton, "Activated")
		client:advance(1.5)
	end)
end)

describe("ParkourUI celebrations", function()
	local Dom = require("../harness/Dom")
	local server = Runtime.new()
	server:require("ServerScriptService.Server.Services.HubService").Start()
	server:require("ServerScriptService.Server.Services.ParkourService").Start()

	-- A client with the course, on a PC (1600 x 900) or a phone (640 x 302 touch).
	-- off = "Game" | "All" switches the effects off.
	local function climber(opts: { phone: boolean?, off: string? }?)
		local o = opts or {}
		local client = Runtime.new({ client = true })
		client:replicateFrom(server)
		local env = client.env
		local Config = client:require("ReplicatedStorage.Shared.Config")
		if o.off == "Game" then
			Config.Parkour.Effects.On = false
		elseif o.off == "All" then
			Config.Minigames.Effects.On = false
		end
		local Client = client:find("StarterPlayer.StarterPlayerScripts.Client")
		local player = client.game:GetService("Players").LocalPlayer
		local gui = client:create("ScreenGui", { Name = "GameUI" }, player.PlayerGui)
		if o.phone then
			gui:SetAttribute("ForceTouch", true)
			Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(640, 302))
		else
			Dom.rawSet(gui, "AbsoluteSize", env.Vector2.new(1600, 900))
		end
		client:require(Client.Layout).Mount(gui)
		client:require(Client.PanelManager).Mount(gui)
		client:require(Client.MenuUI).Mount(gui)
		client:require(Client.ParkourUI).Mount(gui)
		client:advance(0.5)
		local CS = client.game:GetService("CollectionService")
		local function pad(tag: string, index: number?): any
			for _, p in CS:GetTagged(tag) do
				if p:IsA("BasePart") and (index == nil or p:GetAttribute("Index") == index) then
					return p
				end
			end
			return nil
		end
		local function standOn(p: any)
			player.Character:PivotTo(
				env.CFrame.new(p.Position + env.Vector3.new(0, p.Size.Y / 2 + 3, 0))
			)
		end
		local function fxParts(): { any }
			local folder = client.workspace:FindFirstChild("MinigameFx")
			return if folder then folder:GetChildren() else {}
		end
		return {
			client = client,
			Config = Config,
			fx = Config.Parkour.Effects,
			text = Config.Parkour.Text,
			gui = gui,
			player = player,
			event = client:find("ReplicatedStorage.Remotes.ParkourEvent"),
			pad = pad,
			standOn = standOn,
			fxParts = fxParts,
		}
	end

	it("bursts sparkles from the checkpoint you reach and punches its message in", function()
		local c = climber()
		local checkpoint = c.pad("ParkourCheckpoint", 1)
		expect(checkpoint).toBeTruthy()
		c.standOn(checkpoint)
		c.client:fire(c.event, "OnClientEvent", "Checkpoint", { Index = 1, Count = 3 })
		expect(c.gui.ParkourPop.Text).toBe(c.text.Checkpoint:format(1, 3)) -- at once
		expect(c.gui.ParkourPop.FxPunch.Scale).toBeGreaterThan(1)
		local parts = c.fxParts()
		expect(#parts).toBe(1)
		local top = checkpoint.Position + c.client.env.Vector3.new(0, checkpoint.Size.Y / 2, 0)
		expect((parts[1].Position - top).Magnitude).toBeLessThan(1)
		expect(parts[1].CanCollide).toBe(false)
		expect(parts[1].Anchored).toBe(true)
		local emits = c.client:calls("ParticleEmitter", "Emit")
		expect(emits[#emits].args[1]).toBe(c.fx.CheckpointSparkles)
		c.client:advance(2)
		expect(#c.fxParts()).toBe(0)
		expect(c.gui.ParkourPop.FxPunch.Scale).toBe(1)
		expect(#c.client.errors).toBe(0)
	end)

	it("sets off fireworks and confetti at the finish, and a big NEW BEST!", function()
		local c = climber()
		local finish = c.pad("ParkourFinish")
		expect(finish).toBeTruthy()
		c.standOn(finish)
		c.client:fire(c.event, "OnClientEvent", "Finish", {
			Time = 61.5,
			Best = 61.5,
			NewBest = true,
			Coins = c.Config.Parkour.Reward.Coins,
			Wait = 72000,
		})
		local gui = c.gui
		-- The real numbers straight away.
		expect(gui.ParkourFinish.Time.Text).toBe(c.text.FinishTime:format("1:01.50"))
		expect(gui.ParkourFinish.Best.Text).toBe(c.text.NewBest)
		expect(gui.ParkourFinish.Time.FxPunch.Scale).toBeGreaterThan(1)
		expect(#gui.FxConfetti:GetChildren()).toBe(c.fx.NewBestConfetti)
		local words = gui:FindFirstChild("ParkourNewBest")
		expect(words).toBeTruthy()
		expect(words.Text).toBe(c.fx.NewBestText)
		-- Fireworks one after another over the finish.
		c.client:advance(c.fx.FireworkGap * (c.fx.Fireworks - 1) + 0.05)
		local fireworks = c.fxParts()
		expect(#fireworks).toBe(c.fx.Fireworks)
		for _, f in fireworks do
			expect(f.Position.Y).toBeGreaterThan(finish.Position.Y + c.fx.FireworkHeight - 3)
		end
		c.client:advance(c.fx.NewBestSeconds + 1)
		expect(gui:FindFirstChild("ParkourNewBest")).toBeNil()
		expect(gui:FindFirstChild("FxConfetti")).toBeNil()
		expect(#c.fxParts()).toBe(0)
		expect(gui.ParkourFinish:GetAttribute("MotionScale")).toBe(1)
		-- A finish that isn't a new best: the normal confetti, no big words.
		c.client:fire(c.event, "OnClientEvent", "Finish", {
			Time = 70,
			Best = 61.5,
			NewBest = false,
			Coins = 0,
			Wait = 100,
		})
		expect(#gui.FxConfetti:GetChildren()).toBe(c.fx.FinishConfetti)
		expect(gui:FindFirstChild("ParkourNewBest")).toBeNil()
		expect(gui.ParkourFinish.Time.Text).toBe(c.text.FinishTime:format("1:10.00"))
		c.client:advance(c.Config.Parkour.Screen.FinishSeconds + 1)
		expect(gui:FindFirstChild("FxConfetti")).toBeNil()
		expect(#c.client.errors).toBe(0)
	end)

	it("swells the running timer a little on each whole second", function()
		local c = climber()
		local start = c.client.workspace:GetServerTimeNow() - 4.5
		c.player:SetAttribute("ParkourStarted", start)
		c.player:SetAttribute("ParkourRun", "Running")
		c.client:advance(0.1)
		local time = c.gui.ParkourTimer.Time
		expect(time:FindFirstChild("FxPunch")).toBeNil() -- (not on the first frame)
		c.client:advance(0.45) -- 5 s ticks over
		expect(time.FxPunch.Scale).toBe(c.fx.TickBump)
		expect(time.Text).toMatch("^0:05%.")
		c.client:advance(0.4)
		expect(time.FxPunch.Scale).toBe(1)
		c.player:SetAttribute("ParkourRun", "")
	end)

	it("makes fewer sparkles and confetti on phones", function()
		local c = climber({ phone = true })
		local share = c.Config.Minigames.Effects.PhoneShare
		c.standOn(c.pad("ParkourCheckpoint", 1))
		c.client:fire(c.event, "OnClientEvent", "Checkpoint", { Index = 1, Count = 3 })
		local emits = c.client:calls("ParticleEmitter", "Emit")
		expect(emits[#emits].args[1]).toBe(math.floor(c.fx.CheckpointSparkles * share + 0.5))
		expect(emits[#emits].args[1]).toBeLessThan(c.fx.CheckpointSparkles)
		c.client:fire(c.event, "OnClientEvent", "Finish", { Time = 80, Best = 80, NewBest = true })
		expect(#c.gui.FxConfetti:GetChildren()).toBe(math.floor(c.fx.NewBestConfetti * share + 0.5))
		expect(#c.client.errors).toBe(0)
	end)

	it("shows only the plain messages when effects are off", function()
		for _, off in { "Game", "All" } do
			local c = climber({ off = off })
			c.standOn(c.pad("ParkourCheckpoint", 1))
			c.client:fire(c.event, "OnClientEvent", "Checkpoint", { Index = 1, Count = 3 })
			expect(c.gui.ParkourPop.Text).toBe(c.text.Checkpoint:format(1, 3))
			c.client:fire(
				c.event,
				"OnClientEvent",
				"Finish",
				{ Time = 80, Best = 80, NewBest = true }
			)
			expect(c.gui.ParkourFinish.Visible).toBe(true)
			expect(c.gui.ParkourFinish.Time.Text).toBe(c.text.FinishTime:format("1:20.00"))
			expect(c.gui:FindFirstChild("FxConfetti")).toBeNil()
			expect(c.gui:FindFirstChild("ParkourNewBest")).toBeNil()
			c.client:advance(2)
			expect(c.client.workspace:FindFirstChild("MinigameFx")).toBeNil()
			expect(#c.client:calls("ParticleEmitter", "Emit")).toBe(0)
			expect(#c.client.errors).toBe(0)
		end
	end)
end)
