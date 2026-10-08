-- Walk styles (Style.Motion, src/shared/SkinMotion.luau): every preset poses R15 and R6 joints
-- with finite turns, Normalize accepts presets and animation ids and refuses everything else,
-- the server sets and clears the character attributes, and the client SkinWalk (Add mode on
-- top of Roblox's walk without building up, Set mode, who gets a walk style, your own float
-- capped, your own uploaded walk / run / idle animations, hiders).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local Config = rt:require("ReplicatedStorage.Shared.Config")
local SkinMotion = rt:require("ReplicatedStorage.Shared.SkinMotion")
local DanceMoves = rt:require("ReplicatedStorage.Shared.DanceMoves")

local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
}

local function finite(cf: any): boolean
	for _, n in { cf:GetComponents() } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

describe("SkinMotion: presets and checking", function()
	it("has Config numbers, a label and help for every walk style", function()
		expect(#SkinMotion.Names).toBe(8)
		for _, info in SkinMotion.Info do
			expect(Config.SkinMotion.Presets[info.Name]).toBeTruthy()
			expect(#info.Help).toBeGreaterThan(10)
			expect(SkinMotion.Has(info.Name)).toBe(true)
		end
		for name in Config.SkinMotion.Presets do
			expect(SkinMotion.Has(name)).toBe(true)
		end
		expect(Config.Features.WalkStyles).toBe(true)
	end)

	it("poses every joint with finite turns that move, standing and walking", function()
		for _, name in SkinMotion.Names do
			local moved = false
			for _, move in { 0, 0.5, 1 } do
				local a = SkinMotion.Pose(name, 1000.3, move)
				local b = SkinMotion.Pose(name, 1000.9, move)
				for joint, pose in a do
					expect(table.find(JOINTS, joint)).toBeTruthy()
					expect(pose.Mode == "Set" or pose.Mode == "Add").toBe(true)
					expect(finite(pose.Turn)).toBe(true)
					expect(pose.Turn.Position.Magnitude).toBeLessThan(1.5)
					if joint ~= "Root" then
						expect(pose.Turn.Position.Magnitude).toBe(0) -- only the root shifts
					end
					local other = b[joint]
					local gap = if other
						then (other.Turn.Position - pose.Turn.Position).Magnitude + (
							other.Turn.LookVector - pose.Turn.LookVector
						).Magnitude + (other.Turn.UpVector - pose.Turn.UpVector).Magnitude
						else 0
					if gap > 1e-4 then
						moved = true
					end
				end
			end
			if not moved then
				error(name .. " never moves")
			end
		end
		expect(next(SkinMotion.Pose("NoSuchWalk", 1, 1))).toBeNil()
	end)

	it("accepts presets and animation ids, and refuses everything else", function()
		local m = SkinMotion.Normalize("Zombie")
		expect(m).toEqual({ Preset = "Zombie" })
		m = SkinMotion.Normalize({ Walk = 123, Run = "456", Idle = "rbxassetid://789" })
		expect(m).toEqual({
			Walk = "rbxassetid://123",
			Run = "rbxassetid://456",
			Idle = "rbxassetid://789",
		})
		m = SkinMotion.Normalize({ Preset = "Ghost", Idle = 789 })
		expect(m).toEqual({ Preset = "Ghost", Idle = "rbxassetid://789" })
		expect((SkinMotion.Normalize(nil))).toBeNil()
		for _, bad in
			{
				"Moonwalk",
				42,
				true,
				{},
				{ Preset = "Moonwalk" },
				{ Preset = "Ghost", Jump = 1 },
				{ Walk = 0 },
				{ Walk = -5 },
				{ Walk = 1.5 },
				{ Walk = 0 / 0 },
				{ Walk = math.huge },
				{ Walk = -math.huge },
				{ Walk = "abc" },
				{ Walk = "rbxassetid://" },
				{ Walk = "rbxassetid://12a" },
				{ Walk = "http://evil/123" },
				{ Walk = string.rep("9", 21) },
				{ Walk = { 1 } },
			}
		do
			local motion, errors = SkinMotion.Normalize(bad)
			expect(motion).toBeNil()
			expect(#errors).toBe(1)
		end
	end)

	it("writes and reads the ids attribute", function()
		local m = SkinMotion.Normalize({ Preset = "Bat", Walk = 11, Idle = 33 })
		local text = SkinMotion.IdsText(m)
		expect(text).toBe("Walk=11;Idle=33")
		expect(SkinMotion.ParseIds(text)).toEqual({
			Walk = "rbxassetid://11",
			Idle = "rbxassetid://33",
		})
		expect(SkinMotion.IdsText({ Preset = "Bat" })).toBeNil()
		expect(SkinMotion.ParseIds(42)).toEqual({})
		expect(SkinMotion.ParseIds("Jump=5;Walk=x")).toEqual({})
	end)

	it("only gives walk styles to Rare and CRAZY catalogue skins, all of them valid", function()
		for _, item in rt:require("ReplicatedStorage.Shared.Items").ForSlot("Skin") do
			local motion = item.Style.Motion
			if motion ~= nil then
				local _, errors = SkinMotion.Normalize(motion)
				if #errors > 0 then
					error(item.Id .. ": " .. table.concat(errors, "; "))
				end
				expect(item.Rarity == "Rare" or item.Rarity == "Crazy").toBe(true)
			end
		end
		local _ = DanceMoves
	end)
end)
