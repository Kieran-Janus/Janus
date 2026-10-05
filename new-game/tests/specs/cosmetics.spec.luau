-- Builds, previews and wears every shop item (src/shared/Cosmetics.luau).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
local CFrame, Vector3 = rt.env.CFrame, rt.env.Vector3

local function partsIn(model: any): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Fails the test if game code warned while running fn (e.g. "no builder for X").
local function noWarnings(fn: () -> ())
	local before = #rt.warnings
	fn()
	if #rt.warnings > before then
		error("game code warned: " .. table.concat(rt.warnings, " | ", before + 1))
	end
end

describe("Cosmetics.Preview", function()
	for _, item in Config.Shop.Items do
		it(("previews %s (%s)"):format(item.Id, item.Slot), function()
			noWarnings(function()
				local model = Cosmetics.Preview(item)
				expect(model).toBeInstanceOf("Model")
				expect(model.PrimaryPart).toBeInstanceOf("BasePart")
				expect(partsIn(model)).toBeGreaterThan(0)
				local _, size = model:GetBoundingBox()
				expect(size).toBeFinite()
				expect(size.Magnitude).toBeGreaterThan(0)
				model:Destroy()
			end)
		end)
	end
end)

describe("Cosmetics.Build", function()
	for _, item in Config.Shop.Items do
		if item.Slot ~= "Trail" then
			it(("builds %s around its design origin"):format(item.Id), function()
				noWarnings(function()
					local model = Cosmetics.Build(item)
					expect(model.Name).toBe("Cosmetic_" .. item.Slot)
					expect(model:GetAttribute("ItemId")).toBe(item.Id)
					expect(model.PrimaryPart).toBeInstanceOf("BasePart")
					-- The pivot is the design origin (top of the head for hats), not the handle.
					expect(model:GetPivot()).toBeNear(CFrame.identity, 1e-4)
					for _, d in model:GetDescendants() do
						if d:IsA("BasePart") then
							expect(d.Anchored).toBe(true)
							expect(d.CanCollide).toBe(false)
						end
					end
				end)
			end)
		end
	end
end)

describe("Cosmetics.Wear", function()
	local player = rt:addPlayer({ Name = "Tester" })
	local character = player.Character
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")

	for _, slot in Config.Shop.Slots do
		for _, item in Config.Shop.Items do
			if item.Slot == slot then
				it(("puts on and takes off %s"):format(item.Id), function()
					noWarnings(function()
						expect(Cosmetics.Wear(character, item)).toBe(true)
						if slot == "Trail" then
							expect(root:FindFirstChild("CosmeticTrail")).toBeInstanceOf("Trail")
						elseif slot == "Hat" then
							local hat = character:FindFirstChild("Cosmetic_Hat")
							expect(hat).toBeInstanceOf("Model")
							local lift = character:GetAttribute("HatLift") or 0
							local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 + lift, 0)
							expect(hat:GetPivot()).toBeNear(top, 1e-3)
						elseif slot == "Pet" then
							local pet = character:FindFirstChild("Cosmetic_Pet")
							expect(pet:GetPivot()).toBeNear(
								root.CFrame * CFrame.new(Config.Shop.PetOffset),
								1e-3
							)
						end
						Cosmetics.TakeOff(character, slot)
						expect(character:FindFirstChild("Cosmetic_" .. slot)).toBeNil()
						expect(root:FindFirstChild("CosmeticTrail")).toBeNil()
					end)
				end)
			end
		end
	end

	it("restores the avatar after a skin comes off", function()
		local skin
		for _, item in Config.Shop.Items do
			if item.Slot == "Skin" and item.Style.BodyColor and item.Style.HideClothes then
				skin = item
				break
			end
		end
		expect(skin).toBeTruthy()
		local torso = character:FindFirstChild("UpperTorso")
		local color = torso.Color
		Cosmetics.Wear(character, skin)
		expect(torso.Color).toBeNear(skin.Style.BodyColor)
		expect(character:FindFirstChildOfClass("Shirt")).toBeNil()
		Cosmetics.TakeOff(character, "Skin")
		expect(torso.Color).toBeNear(color)
		expect(character:FindFirstChildOfClass("Shirt")).toBeInstanceOf("Shirt")
		expect(character:FindFirstChild("SkinStash")).toBeNil()
	end)
end)

describe("Custom cosmetic models (ReplicatedStorage.Custom.Cosmetics)", function()
	it("replaces the Part-built hat and scales it to Config.Custom.CosmeticSize", function()
		local item = Cosmetics.Find("WitchHat")
		expect(item).toBeTruthy()
		local folder = rt:find("ReplicatedStorage.Custom.Cosmetics")
		-- A deliberately huge, off-centre "Creator Store" hat with a script inside.
		local model = rt:create("Model", { Name = "WitchHat" })
		local brim = rt:create("Part", {
			Name = "Brim",
			Size = Vector3.new(30, 2, 30),
			CFrame = CFrame.new(100, 50, 0),
		}, model)
		rt:create(
			"Part",
			{ Name = "Cone", Size = Vector3.new(10, 20, 10), CFrame = CFrame.new(100, 61, 0) },
			model
		)
		rt:create("Script", { Name = "Sneaky" }, brim)
		model.Parent = folder

		local built = Cosmetics.Build(item)
		expect(built:FindFirstChild("Sneaky", true)).toBeNil()
		local _, size = built:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		expect(biggest).toBeNear(Config.Custom.CosmeticSize.Hat, 1e-3)
		-- Hats sit with the bottom of their box on the design origin.
		expect(built:GetPivot()).toBeNear(CFrame.identity, 1e-4)
		local box = built:GetBoundingBox()
		expect(box.Position.Y - size.Y / 2).toBeNear(0, 1e-3)
		model:Destroy()
	end)
end)
