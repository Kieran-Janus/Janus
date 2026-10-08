-- Animated skins (Style.Animate, src/shared/SkinAnimate.luau): the effect list and its Config
-- numbers, Normalize (defaults, ~30 bad inputs, the CRAZY ownership rules), the maths (finite,
-- smooth, the same on every screen), Skin Studio drafts' LiveStyle, the rarity rules; then the
-- server build in Cosmetics (SkinPart / SkinIndex, pivots, attributes before parenting, hats,
-- custom models) and the client SkinAnim (budget, hiders, last-written guard, CRAZY + Animate,
-- every frame at half rate, colour rate and budget, bursts, previews).

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect
local typeof = Runtime.typeof

local rt = Runtime.new()
local env = rt.env
local CFrame, Color3 = env.CFrame, env.Color3
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Items = rt:require("ReplicatedStorage.Shared.Items")
local SkinAnimate = rt:require("ReplicatedStorage.Shared.SkinAnimate")

local NAN = 0 / 0
local INF = math.huge

local function rgb(r: number, g: number, b: number): any
	return Color3.fromRGB(r, g, b)
end

local function finiteCFrame(cf: any): boolean
	for _, n in { cf:GetComponents() } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

local function colourGap(a: any, b: any): number
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

local function cfGap(a: any, b: any): number
	return (a.Position - b.Position).Magnitude
		+ (a.LookVector - b.LookVector).Magnitude
		+ (a.UpVector - b.UpVector).Magnitude
end

-- Every skin in Config.Shop.Items.
local function skins(): { any }
	return Items.ForSlot("Skin")
end

describe("SkinAnimate: effects and Config", function()
	it("has metadata and Config numbers for every effect, and nothing else", function()
		local presets = Config.SkinAnimate.Presets
		local names = {}
		for _, info in SkinAnimate.Effects do
			table.insert(names, info.Name)
			expect(presets[info.Name]).toBeTruthy()
			expect(#info.Label).toBeGreaterThan(0)
			expect(#info.Help).toBeGreaterThan(10)
			expect(#info.Targets).toBeGreaterThan(0)
			expect(table.find({ "Motion", "Colour", "Light", "Particles" }, info.Kind)).toBeTruthy()
			local keys = {}
			for _, param in info.Params do
				keys[param.Key] = true
				expect(#param.Help).toBeGreaterThan(5)
			end
			-- Speed, Amount and Delay go with every effect
			expect(keys.Speed and keys.Amount and keys.Delay).toBe(true)
			expect(SkinAnimate.Has(info.Name)).toBe(true)
		end
		for name in presets do
			if not table.find(names, name) then
				error("Config.SkinAnimate.Presets." .. name .. " has no effect in SkinAnimate")
			end
		end
		-- CRAZY owns the rainbow and the orbiting pieces (Style.Crazy), so Animate has neither
		expect(SkinAnimate.Has("Rainbow")).toBe(false)
		expect(SkinAnimate.Has("Orbit")).toBe(false)
		expect(#names).toBe(12)
		expect(Config.Features.SkinAnimations).toBe(true)
		expect(Config.SkinAnimate.Rarity.Common.Effects).toBe(0)
	end)

	it("fills in defaults", function()
		local list, errors, warnings = SkinAnimate.Normalize({
			{ Effect = "Flap" },
			{ Effect = "Spin", Target = "Head", Speed = 2 },
			{ Effect = "SparkleBurst" },
			{ Effect = "Flicker", Target = "Body" },
		}, { Head = "SkinPumpkin", Accent = { Pattern = "Wings" }, Aura = { Kind = "Stars" } })
		expect(#errors).toBe(0)
		expect(#warnings).toBe(0)
		expect(#list).toBe(4)
		expect(list[1]).toEqual({
			Effect = "Flap",
			Target = "Wings",
			Speed = 1,
			Amount = 1,
			Delay = 0,
			Axis = "Y",
		})
		expect(list[2].Speed).toBe(2)
		expect(list[2].Axis).toBe("Y")
		expect(list[3].Target).toBe("Aura")
		expect(list[3].Every).toBe(Config.SkinAnimate.Presets.SparkleBurst.Every)
		expect(list[3].Count).toBe(Config.SkinAnimate.Presets.SparkleBurst.Count)
		expect(list[4].Every).toBe(Config.SkinAnimate.Presets.Flicker.Every)
		expect((SkinAnimate.Normalize(nil))).toBeNil()
	end)

	it("refuses every bad effect with a message", function()
		local crazy = {
			Head = "MegaGourd",
			Accent = { Pattern = { "Cape", "Belt" } },
			Glow = { Color = rgb(255, 0, 0) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Pumpkins" },
		}
		local cases: { { any } } = {
			{ "not a table", "Spin" },
			{ "unknown effect", { Effect = "Rainbow" } },
			{ "no effect", { Target = "Head" } },
			{ "a typo'd key", { Effect = "Spin", Sped = 2 } },
			{ "a key of another effect", { Effect = "Bob", Axis = "X" } },
			{ "Reverse on Wag", { Effect = "Wag", Reverse = true } },
			{ "Colors on Pulse", { Effect = "Pulse", Colors = { rgb(1, 2, 3), rgb(4, 5, 6) } } },
			{ "Count on Flicker", { Effect = "Flicker", Count = 3 } },
			{ "an unknown target", { Effect = "Spin", Target = "Hat" } },
			{ "Flap on the head", { Effect = "Flap", Target = "Head" } },
			{ "Spin on a still pattern", { Effect = "Spin", Target = "Belt" } },
			{ "Shimmer on the glow", { Effect = "Shimmer", Target = "Glow" } },
			{ "a burst on the head", { Effect = "SparkleBurst", Target = "Head" } },
			{ "an empty Part: name", { Effect = "Spin", Target = "Part:" } },
			{ "a number target", { Effect = "Spin", Target = 5 } },
			{ "Speed too big", { Effect = "Spin", Speed = 9 } },
			{ "Speed too small", { Effect = "Spin", Speed = 0 } },
			{ "Amount below 0", { Effect = "Bob", Amount = -1 } },
			{ "Delay too long", { Effect = "Bob", Delay = 11 } },
			{ "Speed as text", { Effect = "Bob", Speed = "fast" } },
			{ "a bad Axis", { Effect = "Spin", Axis = "W" } },
			{ "Reverse as a number", { Effect = "Spin", Reverse = 1 } },
			{ "ColorCycle without Colors", { Effect = "ColorCycle" } },
			{ "one colour", { Effect = "ColorCycle", Colors = { rgb(1, 2, 3) } } },
			{
				"seven colours",
				{ Effect = "ColorCycle", Colors = table.create(7, rgb(1, 2, 3)) },
			},
			{
				"a colour list with a hole",
				{ Effect = "ColorCycle", Colors = { rgb(1, 2, 3), nil, rgb(4, 5, 6) } },
			},
			{ "a word in Colors", { Effect = "ColorCycle", Colors = { rgb(1, 2, 3), "red" } } },
			{ "a burst too often", { Effect = "SparkleBurst", Every = 0.2 } },
			{ "a burst too big", { Effect = "SparkleBurst", Count = 51 } },
			{ "half a particle", { Effect = "SparkleBurst", Count = 2.5 } },
			{ "Flicker too fast", { Effect = "Flicker", Every = 0.01 } },
		}
		-- NaN, +inf and -inf in every number key
		for _, info in SkinAnimate.Effects do
			for _, param in info.Params do
				if param.Type == "number" then
					for _, bad in { NAN, INF, -INF } do
						table.insert(cases, {
							("%s %s = %s"):format(info.Name, param.Key, tostring(bad)),
							{ Effect = info.Name, [param.Key] = bad },
						})
					end
				end
			end
		end
		for _, case in cases do
			local list, errors = SkinAnimate.Normalize({ case[2] }, nil)
			if #errors ~= 1 or #list ~= 0 then
				error(
					("%s: wanted one error, got %d (%s)"):format(
						case[1],
						#errors,
						table.concat(errors, "; ")
					)
				)
			end
			expect(errors[1]).toMatch("^Animate 1")
		end
		T.note(#cases, "bad effects refused")
		-- whole lists
		local _, errors = SkinAnimate.Normalize("Spin")
		expect(#errors).toBe(1)
		_, errors = SkinAnimate.Normalize({ { Effect = "Spin" }, nil, { Effect = "Bob" } })
		expect(#errors).toBe(1)
		_, errors = SkinAnimate.Normalize({ { Effect = "Spin" }, Extra = { Effect = "Bob" } })
		expect(#errors).toBe(1)
		local tooMany = table.create(Config.SkinAnimate.MaxEffects + 1, { Effect = "Bob" })
		local list
		list, errors = SkinAnimate.Normalize(tooMany)
		expect(#errors).toBe(1)
		expect(#list).toBe(Config.SkinAnimate.MaxEffects)
		-- CRAZY owns the rainbow accents and the glow pulse (section 3.2a)
		for _, case in
			{
				{
					Effect = "ColorCycle",
					Target = "Accents",
					Colors = { rgb(1, 2, 3), rgb(4, 5, 6) },
				},
				{ Effect = "Shimmer", Target = "All" },
				{ Effect = "Pulse", Target = "Cape" },
				{ Effect = "Flicker", Target = "Belt" },
				{ Effect = "Pulse", Target = "Glow" },
				{ Effect = "Flicker", Target = "Glow" },
			}
		do
			list, errors = SkinAnimate.Normalize({ case }, crazy)
			expect(#list).toBe(0)
			expect(#errors).toBe(1)
			expect(errors[1]).toMatch("CRAZY")
		end
		-- ...but not what CRAZY doesn't drive
		list, errors = SkinAnimate.Normalize({
			{ Effect = "ColorCycle", Target = "Glow", Colors = { rgb(255, 0, 0), rgb(0, 0, 255) } },
			{ Effect = "Shimmer", Target = "Head" },
			{ Effect = "Pulse", Target = "Body" },
			{ Effect = "Breathe", Target = "Cape" },
		}, crazy)
		expect(#errors).toBe(0)
		expect(#list).toBe(4)
		expect(SkinAnimate.Forbidden("Pulse", "Glow", crazy)).toMatch("Pulse")
		expect(SkinAnimate.Forbidden("Spin", "Cape", crazy)).toBeNil()
	end)

	it("warns (but allows) a target the skin doesn't have", function()
		local list, errors, warnings = SkinAnimate.Normalize({
			{ Effect = "Flap", Target = "Wings" },
			{ Effect = "Pulse", Target = "Glow" },
			{ Effect = "SparkleBurst" },
			{ Effect = "Spin", Target = "Head" },
		}, { BodyColor = rgb(1, 2, 3) })
		expect(#errors).toBe(0)
		expect(#list).toBe(4)
		expect(#warnings).toBe(4)
	end)

	it("lists the targets a style really has, minus what CRAZY owns", function()
		local style = {
			Head = "MegaGourd",
			Accent = { Pattern = { "Cape", "Belt" } },
			Glow = { Color = rgb(255, 0, 0) },
			Aura = { Kind = "Embers" },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Pumpkins" },
		}
		local all = SkinAnimate.TargetsIn(style, { "Stem" })
		for _, target in
			{ "Head", "Cape", "Accents", "Belt", "All", "Body", "Glow", "Aura", "Part:Stem" }
		do
			expect(all).toContain(target)
		end
		expect(all).never.toContain("Wings")
		local pulse = SkinAnimate.TargetsIn(style, { "Stem" }, "Pulse")
		expect(pulse).toContain("Head")
		expect(pulse).toContain("Body")
		expect(pulse).never.toContain("Glow")
		expect(pulse).never.toContain("Accents")
		expect(pulse).never.toContain("Belt")
		local flap = SkinAnimate.TargetsIn(style, { "Stem" }, "Breathe")
		expect(flap).toContain("Cape")
		expect(flap).toContain("Part:Stem")
		expect(flap).never.toContain("Belt")
	end)
end)

describe("SkinAnimate: the maths", function()
	local base = 1.7e9 -- like Workspace:GetServerTimeNow()
	local function every(): { any }
		local list = {}
		for _, info in SkinAnimate.Effects do
			local raw: any = { Effect = info.Name, Speed = 1.3, Amount = 0.8, Delay = 0.25 }
			if info.Name == "ColorCycle" then
				raw.Colors = { rgb(255, 0, 0), rgb(0, 255, 0), rgb(0, 0, 255) }
			end
			local list1 = SkinAnimate.Normalize({ raw })
			table.insert(list, list1[1])
		end
		return list
	end

	it("is finite, smooth and the same on every screen", function()
		local baseColor = rgb(200, 120, 40)
		for _, effect in every() do
			for i = 0, 400 do
				local t = base + i * 0.037
				local o = SkinAnimate.Offset(effect, t, -1)
				expect(finiteCFrame(o)).toBe(true)
				expect(o.Position.Magnitude).toBeLessThan(1.5)
				local c = SkinAnimate.Tint(effect, baseColor, t, i % 7, (i % 10) / 10, 1234)
				expect(c.R == c.R and c.G == c.G and c.B == c.B).toBe(true)
				local b = SkinAnimate.Brightness(effect, 2, t, 1234)
				expect(b).toBeFinite()
				expect(b).toBeGreaterThanOrEqual(0)
				expect(b).toBeLessThanOrEqual(2)
				-- the same time gives the same answer (every screen agrees)
				expect(SkinAnimate.Offset(effect, t, -1)).toEqual(o)
				expect(SkinAnimate.Tint(effect, baseColor, t, i % 7, (i % 10) / 10, 1234)).toEqual(
					c
				)
				-- smooth: a tiny step in time makes a tiny change (Flicker steps on purpose)
				local dt = 1e-4
				expect(cfGap(SkinAnimate.Offset(effect, t + dt, -1), o)).toBeLessThan(0.01)
				if effect.Effect ~= "Flicker" then
					local c2 =
						SkinAnimate.Tint(effect, baseColor, t + dt, i % 7, (i % 10) / 10, 1234)
					expect(colourGap(c2, c)).toBeLessThan(0.02)
					expect(math.abs(SkinAnimate.Brightness(effect, 2, t + dt, 1234) - b)).toBeLessThan(
						0.02
					)
				end
			end
		end
	end)

	it("moves the motion effects and changes the colour ones", function()
		for _, effect in every() do
			local info = SkinAnimate.Info(effect.Effect)
			local moved, tinted = 0, 0
			local last, lastC = nil, nil
			for i = 0, 60 do
				local t = base + i * 0.13
				local o = SkinAnimate.Offset(effect, t, 1)
				local c = SkinAnimate.Tint(effect, rgb(200, 120, 40), t, 2, 0.5, 99)
				if last and cfGap(o, last) > 1e-4 then
					moved += 1
				end
				if lastC and colourGap(c, lastC) > 1e-4 then
					tinted += 1
				end
				last, lastC = o, c
			end
			if info.Kind == "Motion" then
				expect(moved).toBeGreaterThan(10)
				expect(tinted).toBe(0)
			elseif info.Kind == "Particles" then
				expect(moved).toBe(0)
				expect(tinted).toBe(0)
			else
				expect(moved).toBe(0)
				expect(tinted).toBeGreaterThan(3)
			end
		end
	end)

	it("mirrors the wings and spins either way", function()
		local flap = SkinAnimate.Normalize({ { Effect = "Flap", Amount = 1 } })[1]
		local t = base + 0.15
		local left = SkinAnimate.Offset(flap, t, -1)
		local right = SkinAnimate.Offset(flap, t, 1)
		expect(left.LookVector.X).toBeNear(-right.LookVector.X, 1e-6)
		local spin = SkinAnimate.Normalize({ { Effect = "Spin" } })[1]
		local back = SkinAnimate.Normalize({ { Effect = "Spin", Reverse = true } })[1]
		expect(SkinAnimate.Offset(spin, t).LookVector.X).toBeNear(
			-SkinAnimate.Offset(back, t).LookVector.X,
			1e-6
		)
	end)

	it("bursts on the same moments everywhere, no more than MaxCount", function()
		local burst = SkinAnimate.Normalize({
			{ Effect = "SparkleBurst", Every = 2, Count = 50, Amount = 3 },
		})[1]
		local due = 0
		local last = base
		for i = 1, 100 do
			local t = base + i * 0.1
			if SkinAnimate.BurstDue(burst, last, t) then
				due += 1
			end
			last = t
		end
		expect(due).toBe(5) -- 10 seconds, one burst every 2
		expect(SkinAnimate.BurstCount(burst, 1)).toBe(
			Config.SkinAnimate.Presets.SparkleBurst.MaxCount
		)
		local small = SkinAnimate.Normalize({ { Effect = "SparkleBurst", Count = 20 } })[1]
		expect(SkinAnimate.BurstCount(small, 1)).toBe(20)
		expect(SkinAnimate.BurstCount(small, Config.SkinAnimate.PhoneBurstScale)).toBe(10)
	end)

	it("hashes repeatably between 0 and 1", function()
		local seen = {}
		for i = 1, 200 do
			local h = SkinAnimate.Hash(i * 977 + 2 ^ 40, 123456789012)
			expect(h).toBeGreaterThanOrEqual(0)
			expect(h).toBeLessThan(1)
			expect(SkinAnimate.Hash(i * 977 + 2 ^ 40, 123456789012)).toBe(h)
			seen[math.floor(h * 10)] = true
		end
		local buckets = 0
		for _ in seen do
			buckets += 1
		end
		expect(buckets).toBe(10) -- spread over the whole range
	end)
end)

describe("SkinAnimate: drafts and rarity", function()
	it("round-trips a draft's LiveStyle", function()
		local style = {
			Crazy = {
				Rainbow = true,
				Pulse = true,
				Orbit = "Pumpkins",
				Count = 3,
				OrbitColor = rgb(10, 20, 30),
			},
			Animate = {
				{ Effect = "Flap", Target = "Wings", Speed = 1.5 },
				{
					Effect = "ColorCycle",
					Target = "Head",
					Colors = { rgb(255, 120, 0), rgb(150, 60, 200) },
				},
				{ Effect = "SparkleBurst", Every = 4, Count = 25 },
			},
		}
		local text, problem = SkinAnimate.EncodeLive(style)
		expect(problem).toBeNil()
		expect(text).toBeA("string")
		local back = SkinAnimate.DecodeLive(text)
		expect(back.Crazy.Rainbow).toBe(true)
		expect(back.Crazy.Orbit).toBe("Pumpkins")
		expect(back.Crazy.OrbitColor).toBeNear(rgb(10, 20, 30))
		local want = SkinAnimate.Normalize(style.Animate, style)
		expect(#back.Animate).toBe(3)
		for i, effect in want do
			for key, value in effect do
				if key == "Colors" then
					for k, c in value do
						expect(back.Animate[i].Colors[k]).toBeNear(c, 1e-3)
					end
				else
					expect(back.Animate[i][key]).toBe(value)
				end
			end
		end
		expect((SkinAnimate.EncodeLive({ BodyColor = rgb(1, 2, 3) }))).toBeNil()
	end)

	it("refuses NaN, infinity and junk in LiveStyle, and a LiveStyle that is too long", function()
		for _, text in
			{
				'{"Animate":[{"Effect":"Spin","Speed":1e999}]}',
				'{"Animate":[{"Effect":"Bob","Amount":-1e999}]}',
				'{"Animate":[{"Effect":"Bob","Delay":NaN}]}',
				'{"Animate":"Spin"}',
				"not json",
			}
		do
			local back = SkinAnimate.DecodeLive(text)
			expect(back.Animate).toBeNil()
		end
		expect(SkinAnimate.DecodeLive(42)).toEqual({})
		local long = {}
		for i = 1, 6 do
			local colors = {}
			for k = 1, 6 do
				colors[k] = rgb(i * 10, k * 10, 0)
			end
			long[i] =
				{ Effect = "ColorCycle", Target = "Part:" .. string.rep("x", 60), Colors = colors }
		end
		local huge = { Animate = long, Crazy = { Effect = string.rep("y", 3000) } }
		local text, problem = SkinAnimate.EncodeLive(huge)
		expect(text).toBeNil()
		expect(problem).toBe("too long")
	end)

	it("finds a model's style in the catalogue first, then in its LiveStyle", function()
		local model = rt:create("Model", { Name = "Cosmetic_Skin" })
		model:SetAttribute("ItemId", "Pumpkin_MegaGourdSupreme")
		model:SetAttribute(
			"LiveStyle",
			(SkinAnimate.EncodeLive({ Animate = { { Effect = "Bob" } } }))
		)
		expect(SkinAnimate.StyleOf(model)).toBe(Items.Get("Pumpkin_MegaGourdSupreme").Style)
		model:SetAttribute("ItemId", "StudioDraft_abc")
		local live = SkinAnimate.StyleOf(model)
		expect(live.Animate[1].Effect).toBe("Bob")
		model:SetAttribute("LiveStyle", nil)
		expect(SkinAnimate.StyleOf(model)).toBeNil()
	end)

	it("keeps every catalogue skin inside its rarity's limits", function()
		local animated, walking = 0, 0
		for _, item in skins() do
			local problems = SkinAnimate.RarityProblems(item)
			if #problems > 0 then
				error(table.concat(problems, "; "))
			end
			if item.Style.Animate then
				animated += 1
			end
			if item.Style.Motion then
				walking += 1
			end
		end
		T.note(animated, "animated skins,", walking, "with a walk style")
		local problems = SkinAnimate.RarityProblems({
			Id = "Test_Common",
			Rarity = "Common",
			Style = { Animate = { { Effect = "Bob" } }, Motion = "Zombie" },
		})
		expect(#problems).toBe(2)
		expect(#SkinAnimate.RarityProblems({
			Id = "Test_Uncommon",
			Rarity = "Uncommon",
			Style = { Animate = { { Effect = "Bob" } } },
		})).toBe(0)
	end)

	it("reads a custom model part's attributes", function()
		local p = rt:create("Part", { Name = "Propeller" })
		expect(SkinAnimate.FromAttributes(p)).toBeNil()
		p:SetAttribute("Animate", "Spin")
		p:SetAttribute("Speed", 2)
		p:SetAttribute("Axis", "X")
		p:SetAttribute("Color2", rgb(1, 2, 3)) -- not used by Spin: ignored
		local effect = SkinAnimate.FromAttributes(p)
		expect(effect.Effect).toBe("Spin")
		expect(effect.Speed).toBe(2)
		expect(effect.Axis).toBe("X")
		p:SetAttribute("Speed", 99) -- out of range: the whole mark is ignored
		expect(SkinAnimate.FromAttributes(p)).toBeNil()
		local glow = rt:create("Part", { Name = "Gem", Color = rgb(255, 0, 0) })
		glow:SetAttribute("Animate", "ColorCycle")
		glow:SetAttribute("Color2", rgb(0, 0, 255))
		local cycle = SkinAnimate.FromAttributes(glow)
		expect(#cycle.Colors).toBe(1)
		-- from the part's own colour to Color2 and back
		local seen = {}
		for i = 0, 20 do
			local c = SkinAnimate.Tint(cycle, glow.Color, 1000 + i * 0.1, 0, 0.5, 0)
			seen[math.floor(c.B * 4 + 0.5)] = true
		end
		expect(seen[0] and seen[4]).toBe(true)
		glow:SetAttribute("Animate", "Nonsense")
		expect(SkinAnimate.FromAttributes(glow)).toBeNil()
		local _ = typeof
	end)
end)
