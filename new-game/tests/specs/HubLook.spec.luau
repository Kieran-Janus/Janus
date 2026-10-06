-- The lobby's look: real ovals instead of squashed balls, faces on the pumpkin surface, the
-- phone budget (parts, lights), decorations that never trip or block players, paths to every
-- area that stay out of the other zones and are free of obstacles, and the view from the spawn.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Vector3, CFrame = rt.env.Vector3, rt.env.CFrame
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Kit = rt:require("ServerScriptService.Server.Build.Kit")
local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
local HubLayout = rt:require("ServerScriptService.Server.Hub.HubLayout")
local HubPaths = rt:require("ServerScriptService.Server.Hub.HubPaths")
local CollectionService = rt.game:GetService("CollectionService")

-- The minigame and parkour switches, all on (to check their paths and signs).
local ALL_AREAS =
	{ Parkour = true, CandyRush = true, WebScour = true, Crates = true, ReadyPad = true }

local function withFeatures(changes: { [string]: boolean }, fn: () -> ())
	local saved = {}
	for name, value in changes do
		saved[name] = Config.Features[name]
		Config.Features[name] = value
	end
	local ok, err = pcall(fn)
	for name, value in saved do
		Config.Features[name] = value
	end
	if not ok then
		error(err, 0)
	end
end

local function isBall(part: any): boolean
	return part:IsA("Part") and part.Shape.Name == "Ball"
end

describe("Kit shapes", function()
	it("turns a Ball with unequal sides into a real oval (Block + SpecialMesh Sphere)", function()
		local folder = rt:create("Folder", { Name = "Shapes" })
		local oval =
			Kit.part({ Shape = rt.env.Enum.PartType.Ball, Size = Vector3.new(3, 2, 3) }, folder)
		expect(oval.Shape.Name).toBe("Block")
		expect(oval.Size).toBeNear(Vector3.new(3, 2, 3), 1e-6)
		local mesh = oval:FindFirstChildOfClass("SpecialMesh")
		expect(mesh).toBeInstanceOf("SpecialMesh")
		expect(mesh.MeshType.Name).toBe("Sphere")
		local ball = Kit.part({ Shape = rt.env.Enum.PartType.Ball, Size = Vector3.one * 2 }, folder)
		expect(ball.Shape.Name).toBe("Ball") -- a true sphere stays a Ball (round collisions)
		expect(ball:FindFirstChildOfClass("SpecialMesh")).toBeNil()
		folder:Destroy()
	end)

	it("measures how far the front of a body is (for carved faces)", function()
		local sphere = { { CFrame = CFrame.identity, Semi = Vector3.one * 2 } }
		expect(Kit.frontDepth(sphere, 0, 0)).toBeNear(2, 1e-4)
		expect(Kit.frontDepth(sphere, 1, 0)).toBeNear(math.sqrt(3), 1e-4)
		expect(Kit.frontDepth(sphere, 3, 0)).toBe(0) -- beside it
		-- A ribbed body sticks out at least as far as its core.
		local folder = rt:create("Folder", { Name = "Ribbed" })
		local _, ovals = Kit.pumpkinBody(CFrame.identity, Vector3.new(4, 3, 4), 4, {}, folder)
		expect(#ovals).toBe(5)
		expect(Kit.frontDepth(ovals, 0.5, 0.2)).toBeGreaterThanOrEqual(
			Kit.frontDepth({ ovals[1] }, 0.5, 0.2)
		)
		folder:Destroy()
	end)

	it("puts a jack-o-lantern's face on its surface, not inside it", function()
		local folder = rt:create("Folder", { Name = "Lanterns" })
		local size = 3
		local lantern = Kit.jackOLantern(CFrame.identity, size, {
			Orange = Config.Hub.Palette.Orange,
			Green = Config.Hub.Palette.Green,
			Glow = Config.Hub.Palette.Glow,
		}, folder)
		local centre = lantern.PrimaryPart.Position
		local ovals = {}
		for _, d in lantern:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Rib" or d.Name == "Pumpkin") then
				table.insert(
					ovals,
					{ CFrame = CFrame.new(centre):ToObjectSpace(d.CFrame), Semi = d.Size / 2 }
				)
			end
		end
		local pieces = 0
		for _, d in lantern:GetChildren() do
			if d.Name == "Eye" or d.Name == "Mouth" or d.Name == "Nose" then
				pieces += 1
				local p = d.Position - centre
				expect(p.Z).toBeLessThan(0) -- on the front
				local surface = Kit.frontDepth(ovals, p.X, p.Y)
				-- Within its own thickness of the surface.
				expect(math.abs(-p.Z - surface)).toBeLessThan(math.max(d.Size.X, d.Size.Z) + 0.05)
			end
		end
		expect(pieces).toBeGreaterThanOrEqual(5)
		folder:Destroy()
	end)
end)

describe("The lobby", function()
	local hub

	it("builds with no squashed balls", function()
		hub = HubBuilder.Build()
		local squashed = 0
		for _, d in hub:GetDescendants() do
			if d:IsA("BasePart") and isBall(d) then
				local s = d.Size
				if math.abs(s.X - s.Y) > 1e-3 or math.abs(s.Y - s.Z) > 1e-3 then
					squashed += 1
				end
			end
		end
		expect(squashed).toBe(0)
	end)

	it("stays within the phone budget (parts and lights, Config.Hub.Budget)", function()
		local parts, lights = 0, 0
		for _, d in hub:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("Light") then
				lights += 1
			end
		end
		T.note(
			("%d parts (budget %d), %d lights (budget %d)"):format(
				parts,
				Config.Hub.Budget.MaxParts,
				lights,
				Config.Hub.Budget.MaxLights
			)
		)
		expect(parts).toBeLessThanOrEqual(Config.Hub.Budget.MaxParts)
		expect(lights).toBeLessThanOrEqual(Config.Hub.Budget.MaxLights)
	end)

	it("keeps decorations from blocking raycasts and casting needless shadows", function()
		for _, d in hub.Decor:GetDescendants() do
			if d:IsA("BasePart") and not d.CanCollide then
				if d.CanQuery or d.CanTouch then
					error(
						d:GetFullName() .. " doesn't collide but still blocks raycasts or touches"
					)
				end
				local s = d.Size
				if math.max(s.X, s.Y, s.Z) <= 4 and d.CastShadow then
					error(d:GetFullName() .. " is a small decoration that casts a shadow")
				end
			end
		end
	end)

	it(
		"faces the spawn north at the Ready arch, with a clear view of the pad and the shop",
		function()
			local spawn = CollectionService:GetTagged("HubSpawn")[1]
			local pad = CollectionService:GetTagged("ReadyPad")[1]
			expect(spawn).toBeTruthy()
			expect(pad).toBeTruthy()
			local toPad = pad.Position - spawn.Position
			local flat = Vector3.new(toPad.X, 0, toPad.Z)
			expect(flat.Magnitude).toBeLessThan(40) -- right next to the spawn
			expect(spawn.CFrame.LookVector:Dot(flat.Unit)).toBeGreaterThan(0.9) -- straight ahead
			-- Where the camera starts: a little behind and above a player who just appeared.
			local eye = spawn.Position - spawn.CFrame.LookVector * 12 + Vector3.new(0, 8, 0)
			local function clear(target: Vector3, allowed: any): boolean
				local hit = rt.workspace:Raycast(eye, target - eye)
				return hit == nil
					or hit.Instance:IsDescendantOf(allowed)
					or hit.Instance == spawn
					or hit.Instance:IsDescendantOf(spawn)
			end
			expect(clear(pad.Position + Vector3.new(0, 1, 0), pad)).toBe(true)
			local shop = hub:FindFirstChild("Shop")
			local shopZone = HubLayout.Zone("Shop")
			expect(clear(shopZone.CFrame.Position + Vector3.new(0, 14, 0), shop)).toBe(true)
		end
	)

	it("keeps the walkways clear: nothing solid stands on a path", function()
		local blocked = {}
		for _, path in HubPaths.Network() do
			for i = 1, #path.Points - 1 do
				local a, b = path.Points[i], path.Points[i + 1]
				local steps = math.max(math.floor((b - a).Magnitude / 2), 1)
				for s = 0, steps do
					local p = a:Lerp(b, s / steps)
					local hit =
						rt.workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -40, 0))
					-- Only the ground, the cauldron's step or the area the path leads into.
					if hit and hit.Position.Y > Config.Hub.Center.Y + 2.2 then
						local zoneModel = path.Zone and hub:FindFirstChild(path.Zone)
						if not (zoneModel and hit.Instance:IsDescendantOf(zoneModel)) then
							table.insert(
								blocked,
								("%s at (%.0f, %.0f): %s"):format(
									path.Name,
									p.X,
									p.Z,
									hit.Instance:GetFullName()
								)
							)
						end
					end
				end
			end
		end
		if #blocked > 0 then
			error("something stands on a path:\n" .. table.concat(blocked, "\n"))
		end
	end)
end)

describe("Paths and signposts", function()
	it("lead to every area that is switched on, and stay out of the other zones", function()
		withFeatures(ALL_AREAS, function()
			local reached: { [string]: boolean } = {}
			for _, path in HubPaths.Network() do
				if path.Zone then
					reached[path.Zone] = true
				end
				for _, point in path.Points do
					for name in Config.Lobby.Zones do
						if rt:require("ReplicatedStorage.Shared.Lobby").InZone(point, name, 0) then
							error(("path %s goes inside the %s zone"):format(path.Name, name))
						end
					end
				end
			end
			-- Areas right on the promenade need no path of their own.
			local ring = Config.Hub.Plaza.Promenade
			for _, entry in Config.Hub.Signposts.Zones do
				local zone = HubLayout.Zone(entry.Zone)
				local flat = Vector3.new(zone.CFrame.X, 0, zone.CFrame.Z)
					- Vector3.new(Config.Hub.Center.X, 0, Config.Hub.Center.Z)
				local front = flat.Magnitude - zone.Size.Z / 2
				if
					entry.Zone ~= "ReadyArea"
					and front > ring.Radius + ring.Width / 2 + Config.Hub.Polish.Paths.StopShort
				then
					if not reached[entry.Zone] then
						error("no path to " .. entry.Zone)
					end
				end
			end
			expect(reached.ReadyArea).toBe(true) -- from the spawn
		end)
	end)

	it("goes round the clock tower to the parkour course", function()
		withFeatures(ALL_AREAS, function()
			local tower = HubLayout.At(Config.Hub.ClockTower.Offset)
			local half = Config.Hub.ClockTower.Width / 2
			for _, path in HubPaths.Network() do
				for i = 1, #path.Points - 1 do
					local a, b = path.Points[i], path.Points[i + 1]
					for s = 0, 20 do
						local p = a:Lerp(b, s / 20)
						local dx, dz = math.abs(p.X - tower.X), math.abs(p.Z - tower.Z)
						if dx < half and dz < half then
							error(path.Name .. " runs through the clock tower")
						end
					end
				end
			end
		end)
	end)

	it(
		"puts up a signpost for every area that is switched on, and none for areas that are off",
		function()
			local function signTexts(): { [string]: boolean }
				local hub = HubBuilder.Build()
				local texts = {}
				for _, d in hub.Decor.Signposts:GetDescendants() do
					if d:IsA("TextLabel") then
						texts[d.Text] = true
					end
				end
				return texts
			end
			withFeatures(ALL_AREAS, function()
				local texts = signTexts()
				for _, entry in Config.Hub.Signposts.Zones do
					expect(texts[entry.Text]).toBe(true)
				end
			end)
			withFeatures({ CandyRush = false }, function()
				local texts = signTexts()
				local text = nil
				for _, entry in Config.Hub.Signposts.Zones do
					if entry.Zone == "CandyRush" then
						text = entry.Text
					end
				end
				expect(texts[text]).toBeNil()
			end)
		end
	)
end)
