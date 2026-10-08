-- Studio looking tools (F8): "Visit map: ..." (MapVisitService), the name finder
-- (src/client/NameFinder.luau), and the scenery round every map (MapScenery).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local SERVICES = "ServerScriptService.Server.Services."

local function server(options: any?)
	local rt = Runtime.new(options or { studio = true })
	for _, name in
		{
			"HubService",
			"DataService",
			"ShopService",
			"AdminService",
			"MapService",
			"MapVisitService",
		}
	do
		rt:require(SERVICES .. name).Start()
	end
	rt:flush()
	return rt
end

local function admin(rt: any, player: any, name: string): (boolean, string)
	return rt:invokeServer(rt:find("ReplicatedStorage.Remotes.AdminCommand"), player, name)
end

describe("MapVisitService (Studio only)", function()
	it("walks you round any map between rounds and brings you back", function()
		local rt = server()
		local Config = rt:require("ReplicatedStorage.Shared.Config")
		local MapService = rt:require(SERVICES .. "MapService")
		local player = rt:addPlayer({ Name = "Builder" })
		rt:advance(1)
		local attribute = Config.Admin.Tools.VisitAttribute
		for _, def in Config.Maps.List do
			rt:advance(1) -- (the panel's click cooldown)
			local ok, message = admin(rt, player, "VisitMap" .. def.Id)
			expect(ok).toBe(true)
			expect(message).toMatch(def.Name)
			local map = MapService.Current()
			expect(map.Id).toBe(def.Id)
			expect(player:GetAttribute(attribute)).toBe(def.Id)
			-- Standing on the map: within its floor.
			local p = map.Floor.CFrame:PointToObjectSpace(player.Character:GetPivot().Position)
			expect(math.abs(p.X) <= map.Floor.Size.X / 2).toBe(true)
			expect(math.abs(p.Z) <= map.Floor.Size.Z / 2).toBe(true)
		end
		rt:advance(1)
		local ok = admin(rt, player, "LeaveMap")
		expect(ok).toBe(true)
		expect(MapService.Current()).toBeNil() -- nobody looking: the map goes away
		expect(player:GetAttribute(attribute)).toBeNil()
		local lobby = MapService.LobbyCFrame().Position
		expect((player.Character:GetPivot().Position - lobby).Magnitude).toBeLessThan(5)
		expect(#rt.errors).toBe(0)
	end)

	it("refuses during a round, and a starting round sends visitors back first", function()
		local rt = server()
		local Visit = rt:require(SERVICES .. "MapVisitService")
		local MapService = rt:require(SERVICES .. "MapService")
		local player = rt:addPlayer({ Name = "Builder" })
		rt:advance(1)
		local round = true
		Visit.SetRoundCheck(function()
			return round
		end)
		local _, message = admin(rt, player, "VisitMapPumpkinPatch")
		expect(message).toMatch("round")
		expect(MapService.Current()).toBeNil()
		round = false
		rt:advance(1)
		admin(rt, player, "VisitMapPumpkinPatch")
		expect(MapService.Current()).toBeTruthy()
		-- GameService calls EndAll just before loading the round's map.
		Visit.EndAll()
		MapService.Load("SpookyMansion")
		local lobby = MapService.LobbyCFrame().Position
		expect((player.Character:GetPivot().Position - lobby).Magnitude).toBeLessThan(5)
		expect(MapService.Current().Id).toBe("SpookyMansion") -- the round's map stays
		expect(#rt.errors).toBe(0)
	end)

	it("toggles the name finder", function()
		local rt = server()
		local Config = rt:require("ReplicatedStorage.Shared.Config")
		local player = rt:addPlayer({ Name = "Builder" })
		rt:advance(1)
		admin(rt, player, "NameFinder")
		expect(player:GetAttribute(Config.Admin.Tools.NameFinderAttribute)).toBe(true)
		rt:advance(1)
		admin(rt, player, "NameFinder")
		expect(player:GetAttribute(Config.Admin.Tools.NameFinderAttribute)).toBeNil()
	end)

	it("adds nothing to a live server", function()
		local rt = server({ studio = false })
		local AdminService = rt:require(SERVICES .. "AdminService")
		local player = rt:addPlayer({ Name = "Owner" })
		rt:advance(1)
		local list = rt:invokeServer(rt:find("ReplicatedStorage.Remotes.GetAdminCommands"), player)
		for _, command in list do
			expect(command.Name:find("VisitMap") == nil).toBe(true)
		end
		expect(AdminService).toBeTruthy()
	end)
end)

describe("NameFinder (client)", function()
	it("shows nothing until switched on, then names what you click", function()
		local client = Runtime.new({ client = true, studio = true })
		local Config = client:require("ReplicatedStorage.Shared.Config")
		local me = client.localPlayer
		local gui = client:create("ScreenGui", { Name = "GameUI" }, me:FindFirstChild("PlayerGui"))
		client:require("StarterPlayer.StarterPlayerScripts.Client.NameFinder").Mount(gui)
		local panel = gui:FindFirstChild("NameFinder")
		expect(panel).toBeTruthy()
		expect(panel.Visible).toBe(false)
		me:SetAttribute(Config.Admin.Tools.NameFinderAttribute, true)
		client:advance(0.1)
		expect(panel.Visible).toBe(true)
		expect(panel:FindFirstChild("Code").Text).toMatch("nothing")
		me:SetAttribute(Config.Admin.Tools.NameFinderAttribute, nil)
		client:advance(0.1)
		expect(panel.Visible).toBe(false)
	end)
end)

describe("MapScenery", function()
	it("is decoration only, outside every map's floor, and can be switched off", function()
		local rt = Runtime.new()
		local Config = rt:require("ReplicatedStorage.Shared.Config")
		local maps = rt:find("ServerScriptService.Server.Maps")
		for _, def in Config.Maps.List do
			local model = rt:require(maps:FindFirstChild(def.Builder)).Build(def)
			local scenery = model:FindFirstChild("Scenery")
			expect(scenery).toBeTruthy()
			local floor = model:FindFirstChild("Floor")
			local count = 0
			for _, d in scenery:GetDescendants() do
				if d:IsA("BasePart") then
					count += 1
					expect(d.CanCollide).toBe(false)
					expect(d.CanQuery).toBe(false)
					expect(d.CanTouch).toBe(false)
					-- Never on the play area: outside the floor, or above the walls (post tops).
					local p = floor.CFrame:PointToObjectSpace(d.Position)
					local inside = math.abs(p.X) < floor.Size.X / 2 - 1
						and math.abs(p.Z) < floor.Size.Z / 2 - 1
					expect(inside).toBe(false)
				end
			end
			expect(count).toBeGreaterThan(20)
			model:Destroy()
			-- Scenery = false: none at all.
			local copy = table.clone(def)
			copy.Scenery = false
			local plain = rt:require(maps:FindFirstChild(def.Builder)).Build(copy)
			expect(plain:FindFirstChild("Scenery")).toBeNil()
			plain:Destroy()
		end
	end)
end)
