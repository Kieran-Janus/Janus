-- The themed crate head pieces (src/shared/HeadPieces.luau): each builds without warnings, has a
-- "Handle", sensible part sizes and counts, fits round the head, changes with the skin's colours,
-- and looks different from the others. The three CRAZY ones shimmer (Rainbow parts).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local rt = Runtime.new()
local env = rt.env
local Vector3, Color3, Instance = env.Vector3, env.Color3, env.Instance
local HeadPieces = rt:require("ReplicatedStorage.Shared.HeadPieces")

local NORMAL = {
	"ClownHead",
	"PharaohHead",
	"MadHair",
	"CaptainHat",
	"TeddyHead",
	"BellhopHat",
	"DiscoAfro",
	"GoblinHead",
	"FrogHead",
	"AlienHead",
	"SnowmanHead",
	"PhantomMask",
	"AcornHead",
	"PartyHat",
	"GumballHead",
}
local CRAZY = { "NightLord", "DiscoDemon", "StarVoyager" }
local ALL = table.clone(NORMAL)
for _, name in CRAZY do
	table.insert(ALL, name)
end
local IS_CRAZY = {}
for _, name in CRAZY do
	IS_CRAZY[name] = true
end

local STYLE_A = {
	HeadColor = Color3.fromRGB(240, 90, 40),
	HeadColor2 = Color3.fromRGB(60, 40, 160),
	GlowColor = Color3.fromRGB(90, 255, 120),
}
local STYLE_B = {
	HeadColor = Color3.fromRGB(70, 200, 230),
	HeadColor2 = Color3.fromRGB(250, 220, 60),
	GlowColor = Color3.fromRGB(255, 60, 200),
}

-- Fails the test if game code warned while running fn.
local function noWarnings(fn: () -> ())
	local before = #rt.warnings
	fn()
	if #rt.warnings > before then
		error("game code warned: " .. table.concat(rt.warnings, " | ", before + 1))
	end
end

local function build(name: string, style: any): (any, any)
	local m = Instance.new("Model")
	local handle = HeadPieces.Builders[name](m, style)
	return m, handle
end

local function partsOf(m: any): { any }
	local list = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- The box (min, max corners) round every part's corners.
local function bounds(m: any): (any, any)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, p in partsOf(m) do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local c = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					for i, v in { c.X, c.Y, c.Z } do
						lo[i] = math.min(lo[i], v)
						hi[i] = math.max(hi[i], v)
					end
				end
			end
		end
	end
	return Vector3.new(lo[1], lo[2], lo[3]), Vector3.new(hi[1], hi[2], hi[3])
end

local function colours(m: any): string
	local list = {}
	for _, p in partsOf(m) do
		local c = p.Color
		table.insert(
			list,
			("%d,%d,%d"):format(math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
		)
	end
	return table.concat(list, ";")
end

describe("Themed head pieces", function()
	for _, name in ALL do
		describe(name, function()
			it("is a known head", function()
				expect(HeadPieces.Has(name)).toBe(true)
			end)

			it("builds with an empty style and with colours, without warnings", function()
				noWarnings(function()
					for _, style in { {}, STYLE_A } do
						local m, handle = build(name, style)
						expect(handle).toBeInstanceOf("BasePart")
						expect(handle.Name).toBe("Handle")
						expect(handle.Parent).toBe(m)
						m:Destroy()
					end
				end)
			end)

			it("has a sensible number of parts with real sizes", function()
				local m = build(name, {})
				local parts = partsOf(m)
				expect(#parts).toBeGreaterThanOrEqual(8)
				expect(#parts).toBeLessThanOrEqual(50)
				for _, p in parts do
					expect(p.Size).toBeFinite()
					expect(p.Size.X).toBeGreaterThan(0)
					expect(p.Size.Y).toBeGreaterThan(0)
					expect(p.Size.Z).toBeGreaterThan(0)
					expect(p.CFrame.Position).toBeFinite()
				end
				m:Destroy()
			end)

			it("fits in a 4 x 4.5 x 4 box round the head", function()
				local m = build(name, STYLE_B)
				local lo, hi = bounds(m)
				expect(lo.X).toBeGreaterThanOrEqual(-2)
				expect(hi.X).toBeLessThanOrEqual(2)
				expect(lo.Y).toBeGreaterThanOrEqual(-2.25)
				expect(hi.Y).toBeLessThanOrEqual(2.25)
				expect(lo.Z).toBeGreaterThanOrEqual(-2)
				expect(hi.Z).toBeLessThanOrEqual(2)
				m:Destroy()
			end)

			it("changes with the skin's colours", function()
				local a = build(name, STYLE_A)
				local b = build(name, STYLE_B)
				expect(colours(a)).never.toBe(colours(b))
				a:Destroy()
				b:Destroy()
			end)

			if IS_CRAZY[name] then
				it("has at least 3 rainbow parts", function()
					local m = build(name, {})
					local rainbow = 0
					for _, p in partsOf(m) do
						if p:GetAttribute("Rainbow") then
							rainbow += 1
						end
					end
					expect(rainbow).toBeGreaterThanOrEqual(3)
					m:Destroy()
				end)
			end
		end)
	end

	it("no two new heads share a part count and box size", function()
		local seen = {}
		for _, name in ALL do
			local m = build(name, {})
			local lo, hi = bounds(m)
			local size = hi - lo
			local key = ("%d|%.2f|%.2f|%.2f"):format(#partsOf(m), size.X, size.Y, size.Z)
			if seen[key] then
				error(("%s and %s look alike (%s)"):format(seen[key], name, key))
			end
			seen[key] = name
			m:Destroy()
		end
	end)
end)
