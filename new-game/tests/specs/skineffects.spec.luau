-- Special skin effects (src/client/SkinEffects.luau): every effect a skin names exists, builds
-- its pieces, moves them round a character and cleans up.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("SkinEffects", function()
	local client = Runtime.new({ client = true })
	local Config = client:require("ReplicatedStorage.Shared.Config")
	local SkinEffects = client:require("StarterPlayer.StarterPlayerScripts.Client.SkinEffects")

	it("has every effect a skin names", function()
		local names = {}
		for _, item in Config.Shop.Items do
			local crazy = item.Style and item.Style.Crazy
			if crazy and crazy.Effect then
				names[crazy.Effect] = true
				expect(SkinEffects.Has(crazy.Effect)).toBe(true)
				expect(Config.Skins.Effects.Special[crazy.Effect]).toBeTruthy()
			end
		end
		for _, name in { "Torment", "BloodMoon", "DiscoInferno", "UfoBeam" } do
			expect(names[name]).toBe(true)
		end
		expect(SkinEffects.Has("NoSuchEffect")).toBe(false)
	end)

	it("builds, moves and removes each effect", function()
		local folder = client:create("Folder", { Name = "Fx" }, client.workspace)
		local root = client:create("Part", {
			Name = "HumanoidRootPart",
			CFrame = client.env.CFrame.new(10, 5, -3),
		}, client.workspace)
		for _, name in { "Torment", "BloodMoon", "DiscoInferno", "UfoBeam" } do
			local state = SkinEffects.Create(name, folder)
			expect(state).toBeTruthy()
			expect(#folder:GetChildren()).toBeGreaterThan(4)
			for _, t in { 0.1, 1.3, 2.7 } do
				SkinEffects.Step(state, root, t)
			end
			for _, p in folder:GetChildren() do
				local pos = p.Position
				expect(pos.X).toBeFinite()
				expect((pos - root.Position).Magnitude).toBeLessThan(12) -- stays round you
			end
			SkinEffects.Destroy(state)
			expect(#folder:GetChildren()).toBe(0)
		end
	end)
end)
