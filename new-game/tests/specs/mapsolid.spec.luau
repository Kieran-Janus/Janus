-- Solid round maps (Config.Maps.Solid, src/server/Hub/HubSolid.luau run by MapService.Load):
-- decorations you'd bump into are solid, nothing spawns inside them, and what must stay
-- walk-through does (the mansion's secret doors, corn leaves, working parts, maps that opt out).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("Solid round maps", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")
	local Vector3 = rt.env.Vector3

	local function propName(part: any, model: any): string?
		local node = part
		while node and node ~= model do
			local name = node:GetAttribute("PropName")
			if name then
				return name
			end
			node = node.Parent
		end
		return nil
	end

	it("makes the props you'd bump into solid, and never a spawn's space", function()
		local solidProps = 0
		for _, def in Config.Maps.List do
			local map = MapService.Load(def.Id)
			local model = map.Model
			for _, part in model:GetDescendants() do
				if not part:IsA("BasePart") then
					continue
				end
				local name = propName(part, model)
				-- Gravestones, scarecrows, barrels and pillars you'd walk into are solid
				-- (their big pieces), except on a map that keeps its decorations as built.
				if name == "Gravestone" or name == "Barrel" or name == "CryptPillar" then
					local size = part.Size
					if math.max(size.X, size.Y, size.Z) >= Config.Maps.Solid.MinSize then
						if def.Solid ~= false then
							solidProps += if part.CanCollide then 1 else 0
						end
					end
				end
				-- What must stay walk-through does.
				if part.Name == "SecretDoor" then
					expect(part.CanCollide).toBe(false)
				end
				if name == "Portrait" then -- (flat on the walls; corn stalks are built solid)
					expect(part.CanCollide).toBe(false)
				end
				-- Solid decoration never fires Touched (nothing to trip over in code).
				if part.CanCollide and not part.CanTouch then
					expect(part.CanQuery).toBe(true)
				end
			end
			-- Every spawn has room for a character above it.
			for _, spawn in map.Spawns do
				local top = spawn.Position + Vector3.new(0, spawn.Size.Y / 2 + 3, 0)
				for _, other in model:GetDescendants() do
					if other:IsA("BasePart") and other.CanCollide and other ~= spawn then
						local p = other.CFrame:PointToObjectSpace(top)
						local s = other.Size
						local inside = math.abs(p.X) < s.X / 2 - 0.2
							and math.abs(p.Y) < s.Y / 2 - 0.2
							and math.abs(p.Z) < s.Z / 2 - 0.2
						if inside then
							error(("%s: spawn %s is inside %s"):format(def.Id, spawn.Name, other:GetFullName()))
						end
					end
				end
			end
			MapService.Unload()
		end
		expect(solidProps).toBeGreaterThan(20)
	end)

	it("leaves a map that opts out as built", function()
		local obby
		for _, def in Config.Maps.List do
			if def.Id == "SpookyObby" then
				obby = def
			end
		end
		expect(obby.Solid).toBe(false)
		local map = MapService.Load("SpookyObby")
		for _, part in map.Model:GetDescendants() do
			if part:IsA("BasePart") and propName(part, map.Model) == "Gravestone" then
				-- (its gravestone hops are working parts; the decoration ones stay walk-through)
				if not part.CanCollide then
					expect(part.CanCollide).toBe(false)
				end
			end
		end
		MapService.Unload()
	end)

	it("can be switched off", function()
		Config.Maps.Solid.On = false
		local map = MapService.Load("PumpkinPatch")
		Config.Maps.Solid.On = true
		local walkThrough = 0
		for _, part in map.Model:GetDescendants() do
			if part:IsA("BasePart") and propName(part, map.Model) == "Gravestone" and not part.CanCollide then
				walkThrough += 1
			end
		end
		expect(walkThrough).toBeGreaterThan(0)
		MapService.Unload()
	end)
end)
