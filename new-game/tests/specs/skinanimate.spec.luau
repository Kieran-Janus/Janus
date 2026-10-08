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

	it("says in plain words why a custom model's mark does nothing", function()
		local model = rt:create("Model", { Name = "Bat" })
		local good = rt:create("Part", { Name = "Body" }, model)
		good:SetAttribute("Animate", "Bob")
		local wing = rt:create("Part", { Name = "Wing" }, model)
		local _, none = SkinAnimate.CheckAttributes(wing)
		expect(#none).toBe(0) -- no Animate: nothing to say
		wing:SetAttribute("Animate", "spin") -- capital letters count
		local effect, problems = SkinAnimate.CheckAttributes(wing)
		expect(effect).toBeNil()
		expect(problems[1]).toMatch('^Wing: Animate = "spin" isn\'t an effect')
		expect(problems[1]).toMatch("capital letters count: Spin")
		wing:SetAttribute("Animate", "Spin")
		wing:SetAttribute("Speed", "2") -- Studio's Add Attribute starts on "string"
		_, problems = SkinAnimate.CheckAttributes(wing)
		expect(problems[1]).toMatch("Speed should be a number")
		expect(problems[1]).toMatch("not a string")
		expect(problems[1]).toMatch("doesn't move at all")
		wing:SetAttribute("Speed", 6) -- over the 5 maximum
		_, problems = SkinAnimate.CheckAttributes(wing)
		expect(problems[1]).toMatch("^Wing: Spin: Speed should be between")
		local all = SkinAnimate.ModelProblems(model)
		expect(#all).toBe(1) -- (the Body is fine)
		expect(all[1]).toBe(problems[1])
		wing:SetAttribute("Speed", 2)
		expect(#SkinAnimate.ModelProblems(model)).toBe(0)
		expect(SkinAnimate.FromAttributes(wing).Speed).toBe(2)
	end)
end)

-- Server build (src/shared/Cosmetics.luau) ----------------------------------------------------------

local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
local Tags = rt:require("ReplicatedStorage.Shared.Tags")
local CollectionService = rt.game:GetService("CollectionService")
local Vector3 = env.Vector3

-- A skin made up for a test (not in the catalogue, so it is worn like a Skin Studio draft).
local function testSkin(id: string, style: { [string]: any }, extra: { [string]: any }?): any
	style.Kind = "Skin"
	style.HideClothes = true
	local item = { Id = id, Name = id, Slot = "Skin", Rarity = "Crazy", Style = style }
	for key, value in extra or {} do
		item[key] = value
	end
	return item
end

local function pivots(model: any): { [string]: any }
	local found = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("AnimGroup") then
			found[d:GetAttribute("AnimGroup")] = d
		end
	end
	return found
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- An R6 character (Torso, Left Arm, ...).
local function r6(name: string): any
	local m = rt:create("Model", { Name = name }, rt.workspace)
	local function limb(partName: string, size: any, at: any): any
		return rt:create("Part", { Name = partName, Size = size, CFrame = CFrame.new(at) }, m)
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(40, 3, 0))
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(40, 3, 0))
	local head = limb("Head", Vector3.new(2, 1, 1), Vector3.new(40, 4.5, 0))
	rt:create("Decal", { Name = "face" }, head)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		limb(prefix .. " Arm", Vector3.new(1, 2, 1), Vector3.new(40 + side * 1.5, 3, 0))
		limb(prefix .. " Leg", Vector3.new(1, 2, 1), Vector3.new(40 + side * 0.5, 1, 0))
	end
	local humanoid = rt:create("Humanoid", {}, m)
	humanoid.RigType = env.Enum.HumanoidRigType.R6
	m.PrimaryPart = root
	return m
end

-- Everything about a character a skin may change, to compare before and after.
local function snapshot(character: any): { [string]: any }
	local shot = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			shot[d:GetFullName()] = tostring(d.Color) .. tostring(d.Material) .. d.Transparency
		elseif d:IsA("Decal") then
			shot[d:GetFullName()] = d.Transparency
		elseif d:IsA("WeldConstraint") or d:IsA("Weld") then
			shot[d:GetFullName() .. "#joint"] = tostring(d.Part0) .. ">" .. tostring(d.Part1)
		end
	end
	for key, value in character:GetAttributes() do
		shot["@" .. key] = tostring(value)
	end
	return shot
end

local player = rt:addPlayer({ Name = "Animated" })
local r15 = player.Character
local r6Body = r6("R6Animated")

describe("Cosmetics: animated skins on characters", function()
	it("marks every piece with SkinPart and a unique SkinIndex, the same in previews", function()
		local checked = 0
		for i, item in skins() do
			if i % 9 ~= 0 then
				continue
			end
			checked += 1
			Cosmetics.Wear(r15, item)
			local model = r15:FindFirstChild("Cosmetic_Skin")
			if not model then
				continue
			end
			local seen: { [number]: any } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("AnimGroup") == nil then
					local kind = d:GetAttribute("SkinPart")
					local index = d:GetAttribute("SkinIndex")
					expect(kind == "Head" or kind == "Aura" or Cosmetics.HasPattern(kind)).toBe(
						true
					)
					expect(index).toBeA("number")
					if seen[index] then
						error(("%s: SkinIndex %d used twice"):format(item.Id, index))
					end
					seen[index] = { kind, d.Name }
				end
			end
			-- the preview numbers the head piece and accents the same way
			local preview = Cosmetics.Preview(item)
			for _, d in preview:GetDescendants() do
				local index = d:GetAttribute("SkinIndex")
				if d:IsA("BasePart") and index then
					local worn = seen[index]
					expect(worn).toBeTruthy()
					expect(worn[1]).toBe(d:GetAttribute("SkinPart"))
					expect(worn[2]).toBe(d.Name)
				end
			end
			preview:Destroy()
			Cosmetics.TakeOff(r15, "Skin")
		end
		T.note(checked, "skins checked")
	end)

	it(
		"keeps a head piece's Wing, Stripe or Wrap apart from the Wings, Stripes and Wraps patterns",
		function()
			for _, case in
				{
					{ "BatHead", { "Wings", "Stripes" }, "Wing", "Wings" },
					{ "ToadstoolHead", { "Spots" }, "Spot", "Spots" },
					{ "WitchHood", { "Belt" }, "Buckle", "Belt" }, -- the Belt pattern has a Buckle too
					{ "PharaohHead", { "Stripes", "Wraps" }, "Stripe", "Stripes" },
					{ "MummyHead", { "Wraps" }, "Wrap", "Wraps" },
					{ "FrankenHead", { "Stitches" }, "Stitch", "Stitches" },
					{ "NightLord", { "Collar", "Cape" }, "Collar", "Collar" },
				}
			do
				local head, patterns, partName, pattern = case[1], case[2], case[3], case[4]
				local item =
					testSkin("Test_" .. head, { Head = head, Accent = { Pattern = patterns } })
				Cosmetics.Wear(r15, item)
				local model = r15.Cosmetic_Skin
				local accents = SkinAnimate.PartsFor(model, pattern)
				local pieces = SkinAnimate.PartsFor(model, "Part:" .. partName)
				if #accents == 0 or #pieces == 0 then
					error(
						("%s: %d %s pieces, %d parts called %s"):format(
							head,
							#accents,
							pattern,
							#pieces,
							partName
						)
					)
				end
				for _, p in accents do
					expect(p:GetAttribute("SkinPart")).toBe(pattern)
				end
				for _, p in pieces do
					expect(p:GetAttribute("SkinPart")).toBe("Head")
					expect(p.Name).toBe(partName)
				end
				-- "Accents" never takes head-piece parts, "Head" never takes accent pieces
				for _, p in SkinAnimate.PartsFor(model, "Accents") do
					expect(p:GetAttribute("SkinPart")).never.toBe("Head")
				end
				for _, p in SkinAnimate.PartsFor(model, "Head") do
					expect(p:GetAttribute("SkinPart")).toBe("Head")
				end
				Cosmetics.TakeOff(r15, "Skin")
			end
		end
	)

	it("builds pivots only for the groups an effect moves", function()
		local style = {
			Head = "BatHead",
			Accent = { Pattern = { "Wings", "Tail", "Cape", "Belt" } },
			Animate = { { Effect = "Flap", Target = "Wings" } },
		}
		Cosmetics.Wear(r15, testSkin("Test_Flapper", style))
		local model = r15.Cosmetic_Skin
		local found = pivots(model)
		expect(count(found)).toBe(2)
		local top = r15.UpperTorso
		for name, side in { WingL = -1, WingR = 1 } do
			local pivot = found[name]
			expect(pivot:GetAttribute("AnimSide")).toBe(side)
			local motor = pivot.SkinMotor
			expect(motor.Part0).toBe(top)
			expect(motor.C0).toBeNear(
				CFrame.new(side * 0.3, top.Size.Y * 0.3, top.Size.Z / 2 + 0.12)
					* CFrame.Angles(0, math.rad(side * -20), 0),
				1e-5
			)
			expect(pivot.Transparency).toBe(1)
			expect(pivot.CanCollide or pivot.CanTouch or pivot.CanQuery).toBe(false)
			expect(pivot.Massless).toBe(true)
		end
		-- every wing piece hangs on a wing pivot; the tail and cape stay welded to the body
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("SkinPart") then
				local to = p:FindFirstChildOfClass("WeldConstraint").Part0
				if p:GetAttribute("SkinPart") == "Wings" then
					local group = to:GetAttribute("AnimGroup")
					expect(group == "WingL" or group == "WingR").toBe(true)
				else
					expect(to:GetAttribute("AnimGroup")).toBeNil()
				end
			end
		end
		expect(CollectionService:HasTag(model, Tags.SkinAnim)).toBe(true)
		-- head, tail, cape and one part of the head piece: Part: hangs on the moving head
		style.Animate = {
			{ Effect = "Bob", Target = "Head" },
			{ Effect = "Wag", Target = "Tail" },
			{ Effect = "Breathe", Target = "Cape" },
			{ Effect = "Spin", Target = "Part:Wing" },
		}
		Cosmetics.Wear(r15, testSkin("Test_Flapper", style))
		model = r15.Cosmetic_Skin
		found = pivots(model)
		expect(count(found)).toBe(4)
		expect(found.Head.SkinMotor.Part0).toBe(r15.Head)
		expect(found.Head.SkinMotor.C0).toBeNear(CFrame.identity, 1e-6)
		expect(found.Tail.SkinMotor.Part0).toBe(r15.LowerTorso)
		expect(found.Cape.SkinMotor.Part0).toBe(r15.UpperTorso)
		expect(found["Part:Wing"].SkinMotor.Part0).toBe(found.Head)
		for _, p in SkinAnimate.PartsFor(model, "Part:Wing") do
			expect(p:FindFirstChildOfClass("WeldConstraint").Part0).toBe(found["Part:Wing"])
		end
		-- the rest of the head piece rides the Head pivot
		for _, p in SkinAnimate.PartsFor(model, "Head") do
			if p.Name ~= "Wing" then
				expect(p:FindFirstChildOfClass("WeldConstraint").Part0).toBe(found.Head)
			end
		end
		Cosmetics.TakeOff(r15, "Skin")
	end)

	it("stops at MaxPivots moving groups", function()
		local item = testSkin("Test_Many", {
			Head = "BatHead",
			Accent = { Pattern = { "Wings", "Tail", "Cape" } },
			Animate = {
				{ Effect = "Bob", Target = "Head" },
				{ Effect = "Flap", Target = "Wings" },
				{ Effect = "Wag", Target = "Tail" },
				{ Effect = "Breathe", Target = "Cape" },
				{ Effect = "Spin", Target = "Part:Wing" },
				{ Effect = "Spin", Target = "Part:Ear" },
			},
		})
		Cosmetics.Wear(r15, item)
		expect(count(pivots(r15.Cosmetic_Skin))).toBe(Config.SkinAnimate.MaxPivots)
		Cosmetics.TakeOff(r15, "Skin")
	end)

	it("builds exactly what it built before for a skin without moving effects", function()
		local function shape(model: any): string
			local lines = {}
			for _, d in model:GetDescendants() do
				local line = d.ClassName .. ":" .. d.Name
				if d:IsA("WeldConstraint") then
					line ..= ">" .. d.Part0.Name
				end
				table.insert(lines, line)
			end
			return table.concat(lines, "|")
		end
		for _, id in { "Pumpkin_SirGourdington", "Moonlight_LunarLegend", "Candy_SugarRushSupreme" } do
			local item = Items.Get(id)
			local plain = table.clone(item)
			plain.Style = table.clone(item.Style)
			plain.Style.Animate = nil
			Cosmetics.Wear(r15, plain)
			local on = shape(r15.Cosmetic_Skin)
			Config.Features.SkinAnimations = false
			Cosmetics.Wear(r15, item)
			local off = shape(r15.Cosmetic_Skin)
			expect(count(pivots(r15.Cosmetic_Skin))).toBe(0)
			expect(CollectionService:HasTag(r15.Cosmetic_Skin, Tags.SkinAnim)).toBe(false)
			expect(r15.Cosmetic_Skin:GetAttribute("LiveStyle")).toBeNil()
			Config.Features.SkinAnimations = true
			expect(off).toBe(on)
			Cosmetics.TakeOff(r15, "Skin")
		end
	end)

	it("sets every attribute and tag before the skin goes on the character", function()
		local item = testSkin("StudioDraft_Test", {
			Head = "SkinPumpkin",
			Accent = { Pattern = "Belt" },
			Crazy = { Pulse = true, Orbit = "Pumpkins" },
			Animate = {
				{ Effect = "Float", Target = "Head" },
				{ Effect = "Shimmer", Target = "Belt" },
			},
		})
		local seen = nil
		local connection = r15.ChildAdded:Connect(function(child)
			if child.Name == "Cosmetic_Skin" then
				seen = {
					ItemId = child:GetAttribute("ItemId"),
					LiveStyle = child:GetAttribute("LiveStyle"),
					SkinFx = CollectionService:HasTag(child, Tags.SkinFx),
					SkinAnim = CollectionService:HasTag(child, Tags.SkinAnim),
					Pivot = pivots(child).Head ~= nil,
				}
			end
		end)
		Cosmetics.Wear(r15, item)
		connection:Disconnect()
		expect(seen).toBeTruthy()
		expect(seen.ItemId).toBe("StudioDraft_Test")
		expect(seen.LiveStyle).toBeA("string")
		expect(seen.SkinFx).toBe(true)
		expect(seen.SkinAnim).toBe(true)
		expect(seen.Pivot).toBe(true)
		local style = SkinAnimate.StyleOf(r15.Cosmetic_Skin)
		expect(style.Crazy.Orbit).toBe("Pumpkins")
		expect(#style.Animate).toBe(2)
		-- a catalogue skin needs no LiveStyle: every screen looks it up by its ItemId
		Cosmetics.Wear(r15, Items.Get("Pumpkin_SirGourdington"))
		expect(r15.Cosmetic_Skin:GetAttribute("LiveStyle")).toBeNil()
		Cosmetics.TakeOff(r15, "Skin")
	end)

	it(
		"puts a hat on the moving head piece, and back on the head when the skin comes off",
		function()
			local hat = Items.Get("PumpkinCap")
			local item = testSkin("Test_Floaty", {
				Head = "SkinPumpkin",
				Animate = { { Effect = "Float", Target = "Head" } },
			})
			Cosmetics.Wear(r15, item)
			Cosmetics.Wear(r15, hat)
			local pivot = pivots(r15.Cosmetic_Skin).Head
			for _, p in r15.Cosmetic_Hat:GetDescendants() do
				if p:IsA("BasePart") then
					expect(p:FindFirstChildOfClass("WeldConstraint").Part0).toBe(pivot)
				end
			end
			local before = r15.Cosmetic_Hat:GetPivot()
			Cosmetics.TakeOff(r15, "Skin")
			expect(r15:FindFirstChild("Cosmetic_Hat")).toBeTruthy()
			for _, p in r15.Cosmetic_Hat:GetDescendants() do
				if p:IsA("BasePart") then
					expect(p:FindFirstChildOfClass("WeldConstraint").Part0).toBe(r15.Head)
				end
			end
			expect(r15.Cosmetic_Hat:GetPivot()).toBeNear(before, 1e-4)
			Cosmetics.TakeOff(r15, "Hat")
		end
	)

	it(
		"puts animated skins on R15 and R6 and takes them off leaving the avatar as it was",
		function()
			local item = testSkin("Test_Everything", {
				BodyColor = rgb(40, 200, 90),
				Head = "BatHead",
				Accent = { Pattern = { "Wings", "Tail", "Cape" }, Color = rgb(200, 40, 40) },
				Glow = { Color = rgb(255, 200, 0) },
				Aura = { Kind = "Sparkles", Color = rgb(255, 255, 255) },
				Animate = {
					{ Effect = "Wobble", Target = "Head" },
					{ Effect = "Flap", Target = "Wings" },
					{ Effect = "Wag", Target = "Tail" },
					{ Effect = "Breathe", Target = "Cape" },
					{ Effect = "Pulse", Target = "Glow" },
					{ Effect = "SparkleBurst" },
				},
				Motion = { Preset = "Bat", Walk = 1234 },
			})
			for _, character in { r15, r6Body } do
				local before = snapshot(character)
				Cosmetics.Wear(character, item)
				expect(character:GetAttribute("SkinMotion")).toBe("Bat")
				expect(character:GetAttribute("SkinMotionIds")).toBe("Walk=1234")
				expect(count(pivots(character.Cosmetic_Skin))).toBe(5)
				Cosmetics.TakeOff(character, "Skin")
				local after = snapshot(character)
				for key, value in before do
					if after[key] ~= value then
						error(
							("%s: %s is %s, was %s"):format(
								character.Name,
								key,
								tostring(after[key]),
								tostring(value)
							)
						)
					end
				end
				for key in after do
					if before[key] == nil then
						error(("%s: %s was left behind"):format(character.Name, key))
					end
				end
			end
		end
	)

	it("sets walk styles only when switched on, and uploaded ids only when allowed", function()
		local item = testSkin(
			"Test_Walker",
			{ BodyColor = rgb(1, 2, 3), Motion = { Preset = "Robot", Idle = 55 } }
		)
		Config.SkinMotion.AllowUploaded = false
		Cosmetics.Wear(r15, item)
		Config.SkinMotion.AllowUploaded = true
		expect(r15:GetAttribute("SkinMotion")).toBe("Robot")
		expect(r15:GetAttribute("SkinMotionIds")).toBeNil()
		Config.Features.WalkStyles = false
		Cosmetics.Wear(r15, item)
		Config.Features.WalkStyles = true
		expect(r15:GetAttribute("SkinMotion")).toBeNil()
		Cosmetics.Wear(
			r15,
			testSkin("Test_Walker", { BodyColor = rgb(1, 2, 3), Motion = "Moonwalk" })
		)
		expect(r15:GetAttribute("SkinMotion")).toBeNil() -- a bad Motion is left out, quietly
		Cosmetics.TakeOff(r15, "Skin")
	end)

	it("builds nothing extra and tags nothing with animations switched off", function()
		local item = testSkin("Test_Off", {
			Head = "SkinPumpkin",
			Accent = { Pattern = "Wings" },
			Animate = { { Effect = "Flap" }, { Effect = "Shimmer", Target = "Head" } },
		})
		Config.Features.SkinAnimations = false
		Cosmetics.Wear(r15, item)
		local preview = Cosmetics.Preview(item)
		Config.Features.SkinAnimations = true
		local model = r15.Cosmetic_Skin
		expect(count(pivots(model))).toBe(0)
		expect(CollectionService:HasTag(model, Tags.SkinAnim)).toBe(false)
		expect(model:GetAttribute("LiveStyle")).toBeNil()
		expect(preview:FindFirstChild("AnimGroup", true)).toBeNil()
		-- the piece attributes are plain data: always there
		expect(model:FindFirstChildWhichIsA("BasePart"):GetAttribute("SkinPart")).toBeA("string")
		preview:Destroy()
		Cosmetics.TakeOff(r15, "Skin")
		-- an Animate-only skin with the feature off is just colours (no empty model)
		Config.Features.SkinAnimations = false
		Cosmetics.Wear(
			r15,
			testSkin(
				"Test_Off2",
				{ BodyColor = rgb(1, 2, 3), Animate = { { Effect = "Pulse", Target = "Body" } } }
			)
		)
		Config.Features.SkinAnimations = true
		expect(r15:FindFirstChild("Cosmetic_Skin")).toBeNil()
		Cosmetics.TakeOff(r15, "Skin")
	end)

	it("finds every target of every animated catalogue skin (no typo'd Part: names)", function()
		local checked = 0
		for _, item in skins() do
			local effects = SkinAnimate.Normalize(item.Style.Animate, item.Style)
			if not effects or #effects == 0 then
				continue
			end
			checked += 1
			for _, character in { r15, r6Body } do
				Cosmetics.Wear(character, item)
				local model = character.Cosmetic_Skin
				local found = pivots(model)
				for _, effect in effects do
					local target = effect.Target
					local ok
					if SkinAnimate.IsMotion(effect.Effect) then
						ok = if target == "Wings"
							then found.WingL ~= nil and found.WingR ~= nil
							else found[target] ~= nil
					elseif target == "Glow" then
						ok = model:FindFirstChild("SkinGlow", true) ~= nil
					elseif target == "Aura" then
						ok = model:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
					elseif target == "Body" then
						ok = true
					else
						ok = #SkinAnimate.PartsFor(model, target) > 0
					end
					if not ok then
						error(
							("%s on %s: %s finds nothing on %s"):format(
								item.Id,
								character.Name,
								effect.Effect,
								target
							)
						)
					end
				end
				Cosmetics.TakeOff(character, "Skin")
			end
		end
		T.note(checked, "animated catalogue skins checked on R15 and R6")
		expect(checked).toBeGreaterThan(10)
	end)

	it("turns a custom model's Animate attributes into moving groups (found by ModelId)", function()
		local folder = rt:find("ReplicatedStorage.Custom.Cosmetics")
		local custom = rt:create("Model", { Name = "Test_Robo" })
		local function block(name: string, size: any, at: any, parent: any): any
			return rt:create(
				"Part",
				{ Name = name, Size = size, CFrame = CFrame.new(at) },
				parent or custom
			)
		end
		local body = block("Body", Vector3.new(4, 4, 4), Vector3.new(0, 0, 0))
		local prop = block("Propeller", Vector3.new(3, 0.2, 0.5), Vector3.new(0, 2.5, 0))
		prop:SetAttribute("Animate", "Spin")
		prop:SetAttribute("Speed", 3)
		local antenna = rt:create("Model", { Name = "Antenna" }, custom)
		block("Rod", Vector3.new(0.2, 1.5, 0.2), Vector3.new(1.5, 2.5, 0), antenna)
		block("Tip", Vector3.new(0.4, 0.4, 0.4), Vector3.new(1.5, 3.3, 0), antenna)
		antenna:SetAttribute("Animate", "Wobble")
		local gem = block("Gem", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 0, -2))
		gem:SetAttribute("Animate", "ColorCycle") -- a colour mark: no pivot
		gem:SetAttribute("Color2", rgb(0, 0, 255))
		local junk = block("Junk", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, -1, -2))
		junk:SetAttribute("Animate", "Explode") -- not an effect: ignored
		custom.PrimaryPart = body
		custom.Parent = folder

		-- a Skin Studio draft of "Test_Robo": worn under its own Id, the model found by ModelId
		local item = testSkin(
			"StudioDraft_Robo",
			{ HeadColor = rgb(1, 2, 3) },
			{ ModelId = "Test_Robo" }
		)
		Cosmetics.Wear(r15, item)
		local model = r15.Cosmetic_Skin
		expect(model:GetAttribute("ItemId")).toBe("StudioDraft_Robo")
		expect(model:FindFirstChild("Propeller", true)).toBeTruthy()
		expect(CollectionService:HasTag(model, Tags.SkinAnim)).toBe(true)
		local found = pivots(model)
		expect(count(found)).toBe(2)
		expect(found["Custom:1"]:GetAttribute("Animate")).toBe("Spin")
		expect(found["Custom:1"]:GetAttribute("Speed")).toBe(3)
		expect(found["Custom:2"]:GetAttribute("Animate")).toBe("Wobble")
		expect(found["Custom:1"].SkinMotor.Part0).toBe(r15.Head)
		local function weldedTo(name: string): any
			return model:FindFirstChild(name, true):FindFirstChildOfClass("WeldConstraint").Part0
		end
		expect(weldedTo("Propeller")).toBe(found["Custom:1"])
		expect(weldedTo("Tip")).toBe(found["Custom:2"])
		expect(weldedTo("Gem")).toBe(r15.Head)
		-- with a moving head piece the custom groups hang on it
		item.Style.Animate = { { Effect = "Float", Target = "Head" } }
		Cosmetics.Wear(r15, item)
		found = pivots(r15.Cosmetic_Skin)
		expect(found["Custom:1"].SkinMotor.Part0).toBe(found.Head)
		expect(found["Custom:2"].SkinMotor.Part0).toBe(found.Head)
		Cosmetics.TakeOff(r15, "Skin")
		-- the preview groups them the same way (a Model per group, inside the Head group)
		local preview = Cosmetics.Preview(item)
		local groups = {}
		for _, d in preview:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("AnimGroup") then
				groups[d:GetAttribute("AnimGroup")] = d
			end
		end
		expect(groups.Head).toBeTruthy()
		expect(groups["Custom:1"].Parent).toBe(groups.Head)
		expect(groups["Custom:1"]:GetAttribute("Animate")).toBe("Spin")
		expect(groups["Custom:2"]:FindFirstChild("Antenna")).toBeTruthy()
		expect(preview.PrimaryPart:IsDescendantOf(groups.Head)).toBe(false)
		preview:Destroy()
		custom:Destroy()
	end)
end)

-- Client (src/client/SkinAnim.luau) ----------------------------------------------------------------

local Dom = require("../harness/Dom")

type Client = {
	rt: any,
	env: any,
	Config: any,
	Cosmetics: any,
	SkinAnimate: any,
	SkinAnim: any,
	SkinFx: any,
	gui: any,
}

-- A client screen with its camera at (0, 5, -30) looking along +Z. `phone` = a 640 x 302 touch
-- screen (Layout.IsPhone).
local function client(opts: { phone: boolean?, mount: boolean? }?): Client
	local o = opts or {}
	local c = Runtime.new({ client = true })
	local cenv = c.env
	local player = c.game:GetService("Players").LocalPlayer
	local gui = c:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	local Client = c:find("StarterPlayer.StarterPlayerScripts.Client")
	if o.phone then
		gui:SetAttribute("ForceTouch", true)
		Dom.rawSet(gui, "AbsoluteSize", cenv.Vector2.new(640, 302))
	else
		Dom.rawSet(gui, "AbsoluteSize", cenv.Vector2.new(1280, 720))
	end
	c:require(Client.Layout).Mount(gui)
	c.workspace.CurrentCamera.CFrame =
		cenv.CFrame.lookAt(cenv.Vector3.new(0, 5, -30), cenv.Vector3.new(0, 3, 0))
	local SkinAnim = c:require(Client.SkinAnim)
	if o.mount ~= false then
		SkinAnim.Mount(gui)
	end
	return {
		rt = c,
		env = cenv,
		Config = c:require("ReplicatedStorage.Shared.Config"),
		Cosmetics = c:require("ReplicatedStorage.Shared.Cosmetics"),
		SkinAnimate = c:require("ReplicatedStorage.Shared.SkinAnimate"),
		SkinAnim = SkinAnim,
		SkinFx = c:require(Client.SkinFx),
		gui = gui,
	}
end

-- A player whose character stands at (x, 3, z) wearing `item` (as the server would dress it).
local function wearer(c: Client, name: string, x: number, z: number, item: any): (any, any)
	local p = c.rt:addPlayer({ Name = name })
	p.Character:PivotTo(c.env.CFrame.new(x, 3, z))
	if item then
		c.Cosmetics.Wear(p.Character, item)
	end
	return p, p.Character
end

local function motors(character: any): { any }
	local list = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "SkinMotor" then
			table.insert(list, d)
		end
	end
	return list
end

local function moved(character: any): boolean
	for _, m in motors(character) do
		if m.Transform ~= CFrame.identity then
			return true
		end
	end
	return false
end

-- Records every property change on everything under `root` ("<full name>.<property>").
local function watchChanges(root: any, into: { [string]: number }): () -> ()
	local connections = {}
	local function watch(d: any)
		table.insert(
			connections,
			d.Changed:Connect(function(property: string)
				local key = d:GetFullName() .. "." .. property
				into[key] = (into[key] or 0) + 1
			end)
		)
	end
	watch(root)
	for _, d in root:GetDescendants() do
		watch(d)
	end
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

local FLOATY = {
	Head = "SkinPumpkin",
	Animate = { { Effect = "Float", Target = "Head" }, { Effect = "Pulse", Target = "Body" } },
}

local function floaty(c: Client, id: string?): any
	local style = table.clone(FLOATY)
	style.Animate = table.clone(FLOATY.Animate)
	return testSkin(id or "StudioDraft_Floaty", style)
end

describe("SkinAnim (client)", function()
	it("does nothing with the feature off, and never waits", function()
		local c = client({ mount = false })
		c.Config.Features.SkinAnimations = false
		c.SkinAnim.Mount(c.gui) -- (returns at once: it never waits for anything)
		local _, character = wearer(c, "Off", 0, 10, floaty(c))
		c.rt:advance(1)
		expect(c.SkinAnim.Active()).toBe(0)
		expect(moved(character)).toBe(false)
		expect(c.rt.listening.PreSimulation or 0).toBe(0)
		-- previews too
		local stop = c.SkinAnim.AnimatePreview(c.Cosmetics.Preview(floaty(c)))
		stop()
		expect(c.rt.listening.PreSimulation or 0).toBe(0)
	end)

	it(
		"animates the closest characters, yours first, up to MaxCharacters (PC 8, phone 4)",
		function()
			for _, onPhone in { false, true } do
				local c = client({ phone = onPhone })
				local cfg = c.Config.SkinAnimate
				local characters = {}
				for i = 1, 10 do
					local _, character = wearer(c, "Near" .. i, 0, i * 8, floaty(c))
					table.insert(characters, character)
				end
				local _, far = wearer(c, "TooFar", 0, cfg.MaxDistance + 20, floaty(c))
				-- your own character, behind everyone else, still comes first
				local me = c.rt.game:GetService("Players").LocalPlayer.Character
				me:PivotTo(c.env.CFrame.new(0, 3, 100))
				c.Cosmetics.Wear(me, floaty(c))
				c.rt:advance(1)
				local limit = if onPhone then cfg.PhoneMaxCharacters else cfg.MaxCharacters
				expect(c.SkinAnim.Active()).toBe(limit)
				expect(moved(me)).toBe(true)
				for i, character in characters do
					expect(moved(character)).toBe(i <= limit - 1)
				end
				expect(moved(far)).toBe(false)
			end
		end
	)

	it("stops a Hide & Seek hider at once and starts again after the round", function()
		local c = client()
		local player, character = wearer(c, "Hider", 0, 10, floaty(c))
		c.rt:advance(1)
		expect(moved(character)).toBe(true)
		player:SetAttribute("HideSeekRole", "Hider")
		c.rt:flush()
		expect(moved(character)).toBe(false) -- straight away, not at the next pick
		c.rt:advance(1)
		expect(moved(character)).toBe(false)
		player:SetAttribute("HideSeekRole", nil)
		c.rt:advance(1)
		expect(moved(character)).toBe(true)
	end)

	it("only puts a colour back when nothing else changed it meanwhile", function()
		local c = client()
		local player, character = wearer(c, "Recolour", 0, 10, floaty(c))
		local arm, leg = character.LeftUpperArm, character.RightUpperLeg
		local armBase, legBase = arm.Color, leg.Color
		c.rt:advance(0.8)
		expect(colourGap(arm.Color, armBase) + colourGap(leg.Color, legBase)).toBeGreaterThan(0)
		-- the server paints the arm green (a new colour replicates in) while the effect runs
		local green = c.env.Color3.new(0, 1, 0)
		arm.Color = green
		player:SetAttribute("HideSeekRole", "Hider") -- the effect stops
		c.rt:flush()
		expect(arm.Color).toBeNear(green, 1e-6)
		expect(leg.Color).toBeNear(legBase, 1e-6)
	end)

	it("never writes what CRAZY already animates (SkinFx + SkinAnim on a CRAZY draft)", function()
		local style = {
			Head = "MegaGourd",
			BodyColor = rgb(240, 120, 30),
			Accent = { Pattern = { "Belt", "Cape" }, Material = env.Enum.Material.Neon },
			Glow = { Color = rgb(255, 170, 60), Brightness = 2 },
			Aura = { Kind = "Embers", Color = rgb(255, 210, 90) },
			Crazy = { Rainbow = true, Pulse = true, Orbit = "Pumpkins" },
			Animate = {
				{ Effect = "Float", Target = "Head" },
				{ Effect = "Shimmer", Target = "Head" },
				{
					Effect = "ColorCycle",
					Target = "Glow",
					Colors = { rgb(255, 0, 0), rgb(0, 0, 255) },
				},
				{ Effect = "Pulse", Target = "Body" },
				{ Effect = "Breathe", Target = "Cape" },
				{ Effect = "SparkleBurst" },
			},
		}
		local _, errors = SkinAnimate.Normalize(style.Animate, style)
		expect(#errors).toBe(0)
		local function run(which: string): { [string]: number }
			local c = client({ mount = false })
			local _, character = wearer(c, "Crazy", 0, 10, nil)
			if which == "SkinFx" then
				c.SkinFx.Start()
			else
				c.SkinAnim.Mount(c.gui)
			end
			c.Cosmetics.Wear(character, testSkin("StudioDraft_Crazy", table.clone(style)))
			c.rt:advance(0.1)
			local changes = {}
			local stop = watchChanges(character, changes)
			c.rt:advance(3)
			stop()
			return changes
		end
		local fx, anim = run("SkinFx"), run("SkinAnim")
		local colours, both = 0, {}
		for key in anim do
			if string.find(key, "%.Color$") or string.find(key, "%.Brightness$") then
				colours += 1
				if fx[key] then
					table.insert(both, key)
				end
			end
		end
		expect(next(fx)).toBeTruthy() -- the draft's CRAZY effects ran (from its LiveStyle)
		expect(colours).toBeGreaterThan(5)
		if #both > 0 then
			error("written by both SkinFx and SkinAnim: " .. table.concat(both, ", "))
		end
	end)

	it("writes moving joints every frame, also at half rate far away", function()
		local c = client()
		local cfg = c.Config.SkinAnimate
		local item = testSkin("StudioDraft_Spinner", {
			Head = "SkinPumpkin",
			Animate = { { Effect = "Spin", Target = "Head" } },
		})
		-- further than HalfRateDistance from the camera, still in range and on screen
		local _, character = wearer(c, "Far", 0, cfg.HalfRateDistance + 10, item)
		c.rt:advance(1)
		local motor = motors(character)[1]
		expect(motor).toBeTruthy()
		for _ = 1, 12 do
			motor.Transform = CFrame.identity -- like Roblox's Animator resetting the joint
			c.rt:advance(1 / 60)
			expect(motor.Transform ~= CFrame.identity).toBe(true)
		end
		-- off screen (behind the camera): no writes at all
		character:PivotTo(c.env.CFrame.new(0, 3, -60))
		c.rt:advance(1)
		motor.Transform = CFrame.identity
		c.rt:advance(0.2)
		expect(motor.Transform == CFrame.identity).toBe(true)
	end)

	it("changes colours ColorHz times a second and skips colours that don't change", function()
		local c = client()
		local cfg = c.Config.SkinAnimate
		local item = testSkin("StudioDraft_Colours", {
			Head = "SkinPumpkin",
			Animate = {
				{
					Effect = "ColorCycle",
					Target = "Head",
					Colors = { rgb(255, 0, 0), rgb(0, 0, 255) },
				},
				{ Effect = "Pulse", Target = "Body", Amount = 0 }, -- never changes anything
			},
		})
		local _, character = wearer(c, "Colours", 0, 10, item)
		c.rt:advance(1)
		local changes = {}
		local stop = watchChanges(character, changes)
		c.rt:advance(1)
		stop()
		local head = SkinAnimate.PartsFor(character.Cosmetic_Skin, "Head")[1]
		local n = changes[head:GetFullName() .. ".Color"] or 0
		expect(n).toBeGreaterThan(cfg.ColorHz * 0.5)
		expect(n).toBeLessThanOrEqual(cfg.ColorHz + 1)
		expect(changes[character.LeftUpperArm:GetFullName() .. ".Color"]).toBeNil()
	end)

	it("bursts sparkles only from a switched-on aura, half as many on phones", function()
		for _, onPhone in { false, true } do
			local c = client({ phone = onPhone })
			local item = testSkin("StudioDraft_Sparkly", {
				Head = "SkinPumpkin",
				Aura = { Kind = "Stars", Color = rgb(255, 255, 200) },
				Animate = { { Effect = "SparkleBurst", Every = 1, Count = 20 } },
			})
			local _, character = wearer(c, "Sparkly", 0, 10, item)
			c.rt:advance(3.05)
			local calls = c.rt:calls("ParticleEmitter", "Emit")
			expect(#calls).toBeGreaterThanOrEqual(2)
			expect(#calls).toBeLessThanOrEqual(4)
			for _, call in calls do
				expect(call.args[1]).toBe(if onPhone then 10 else 20)
			end
			local emitter = nil
			for _, d in character:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					emitter = d
				end
			end
			emitter.Enabled = false -- a disguised hider's aura, say
			local before = #calls
			c.rt:advance(3)
			expect(#c.rt:calls("ParticleEmitter", "Emit")).toBe(before)
		end
	end)

	it("never touches Transparency or Enabled, with every effect running", function()
		local c = client()
		local first = testSkin("StudioDraft_All1", {
			Head = "BatHead",
			Accent = { Pattern = { "Wings", "Tail", "Cape", "Belt" } },
			Glow = { Color = rgb(255, 0, 0) },
			Aura = { Kind = "Sparkles", Color = rgb(255, 255, 255) },
			Animate = {
				{ Effect = "Spin", Target = "Part:Wing" },
				{ Effect = "Flap", Target = "Wings" },
				{ Effect = "Wag", Target = "Tail" },
				{ Effect = "Breathe", Target = "Cape" },
				{ Effect = "Flicker", Target = "Glow" },
				{ Effect = "SparkleBurst", Every = 0.5 },
			},
		})
		local second = testSkin("StudioDraft_All2", {
			Head = "SkinPumpkin",
			Accent = { Pattern = { "Belt", "Stripes" } },
			Glow = { Color = rgb(0, 255, 0) },
			Animate = {
				{ Effect = "Bob", Target = "Head" },
				{ Effect = "Wobble", Target = "Head" },
				{ Effect = "Pulse", Target = "Glow" },
				{
					Effect = "ColorCycle",
					Target = "Belt",
					Colors = { rgb(1, 2, 3), rgb(200, 100, 0) },
				},
				{ Effect = "Shimmer", Target = "Stripes" },
				{ Effect = "Flicker", Target = "Body" },
			},
		})
		local _, a = wearer(c, "AllA", -3, 10, first)
		local _, b = wearer(c, "AllB", 3, 10, second)
		c.rt:advance(0.5)
		local changes = {}
		local stopA, stopB = watchChanges(a, changes), watchChanges(b, changes)
		c.rt:advance(5)
		stopA()
		stopB()
		local seen = {}
		for key in changes do
			local property = string.match(key, "%.(%w+)$")
			seen[property] = true
			for _, banned in { "Transparency", "Enabled", "LocalTransparencyModifier" } do
				if property == banned then
					error("changed " .. key)
				end
			end
		end
		-- (while the effects really ran)
		expect(seen.Transform and seen.Color and seen.Brightness).toBe(true)
	end)

	it("runs nothing per frame once no animated skin is about", function()
		local c = client()
		local _, character = wearer(c, "Leaver", 0, 10, floaty(c))
		c.rt:advance(1)
		expect(c.rt.listening.PreSimulation).toBeGreaterThan(0)
		character.Cosmetic_Skin:Destroy()
		c.rt:advance(1)
		expect(c.rt.listening.PreSimulation or 0).toBe(0)
		expect(c.SkinAnim.Active()).toBe(0)
	end)

	it("keeps 32 animated characters inside the colour budget, on PC and phones", function()
		for _, onPhone in { false, true } do
			local c = client({ phone = onPhone })
			local cfg = c.Config.SkinAnimate
			local all = { rgb(255, 0, 0), rgb(0, 255, 0), rgb(0, 0, 255) }
			local item = testSkin("StudioDraft_Busy", {
				Head = "BatHead",
				Accent = { Pattern = { "Stripes", "Bones", "Wraps" } },
				Animate = {
					{ Effect = "ColorCycle", Target = "All", Colors = all },
					{ Effect = "Shimmer", Target = "All" },
					{ Effect = "Pulse", Target = "All" },
					{ Effect = "Flicker", Target = "All" },
					{ Effect = "ColorCycle", Target = "All", Colors = all, Speed = 2 },
					{ Effect = "Spin", Target = "Head" },
				},
			})
			local characters = {}
			for i = 1, 32 do
				local _, character =
					wearer(c, "Busy" .. i, (i % 8) * 3 - 12, 10 + math.floor(i / 8) * 6, item)
				table.insert(characters, character)
			end
			local paints = #SkinAnimate.PartsFor(characters[1].Cosmetic_Skin, "All")
			expect(paints).toBeGreaterThanOrEqual(cfg.MaxColorParts)
			c.rt:advance(1)
			local limit = if onPhone then cfg.PhoneMaxColorWrites else cfg.MaxColorWrites
			local most, events = 0, 0
			local changes = {}
			local stops = {}
			for _, character in characters do
				table.insert(stops, watchChanges(character, changes))
			end
			for _ = 1, 180 do
				table.clear(changes)
				c.rt:advance(1 / 60)
				local n = 0
				for key, count in changes do
					if string.find(key, "%.Color$") then
						n += count
					end
				end
				most = math.max(most, c.SkinAnim.ColorWrites())
				events = math.max(events, n)
				expect(n).toBeLessThanOrEqual(c.SkinAnim.ColorWrites())
			end
			for _, stop in stops do
				stop()
			end
			local turning = 0
			for _, character in characters do
				if moved(character) then
					turning += 1
				end
			end
			T.note(
				("%s: at most %d colour writes a frame (%d change events), %d of 32 moving"):format(
					if onPhone then "phone" else "PC",
					most,
					events,
					turning
				)
			)
			expect(most).toBeLessThanOrEqual(limit)
			expect(most).toBeGreaterThan(0)
			expect(turning).toBeLessThanOrEqual(
				if onPhone then cfg.PhoneMaxCharacters else cfg.MaxCharacters
			)
			expect(turning).toBeGreaterThan(0)
		end
	end)
end)

describe("SkinAnim previews", function()
	-- A preview in a ViewportFrame on screen, like a shop card.
	local function showPreview(c: Client, item: any, parent: any?): (any, any)
		local model = c.Cosmetics.Preview(item)
		local viewport = c.rt:create("ViewportFrame", { Name = "View" }, parent or c.gui)
		model.Parent = viewport
		return model, viewport
	end

	local function groupsOf(model: any): { [string]: any }
		local found = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("AnimGroup") then
				found[d:GetAttribute("AnimGroup")] = d
			end
		end
		return found
	end

	it(
		"starts with SkinFx.AnimatePreview, even with SkinEffects off or no rainbow, and stops with it",
		function()
			local c = client()
			c.Config.Features.SkinEffects = false
			local item = testSkin("StudioDraft_Preview", {
				Head = "SkinPumpkin",
				BodyColor = rgb(100, 100, 100),
				Animate = {
					{ Effect = "Spin", Target = "Head" },
					{
						Effect = "ColorCycle",
						Target = "Body",
						Colors = { rgb(255, 0, 0), rgb(0, 0, 255) },
					},
				},
			})
			local model = showPreview(c, item)
			local head = groupsOf(model).Head
			local rest = head:GetPivot()
			local torso = model.Torso
			local stop = c.SkinFx.AnimatePreview(model)
			c.rt:advance(0.5)
			expect(cfGap(head:GetPivot(), rest)).toBeGreaterThan(1e-3)
			expect(colourGap(torso.Color, rgb(100, 100, 100))).toBeGreaterThan(0.01)
			stop()
			expect(head:GetPivot()).toBeNear(rest, 1e-4)
			expect(torso.Color).toBeNear(rgb(100, 100, 100), 1e-3)
			c.rt:advance(0.5)
			expect(head:GetPivot()).toBeNear(rest, 1e-4)
			c.Config.Features.SkinEffects = true
			-- a CRAZY draft: the one stop function stops the rainbow too
			local crazy = testSkin("StudioDraft_PreviewCrazy", {
				Head = "MegaGourd",
				Accent = { Pattern = "Belt" },
				Crazy = { Rainbow = true, Orbit = "Pumpkins" },
				Animate = { { Effect = "Bob", Target = "Head" } },
			})
			local model2 = showPreview(c, crazy)
			local stop2 = c.SkinFx.AnimatePreview(model2)
			local belt = SkinAnimate.PartsFor(model2, "Belt")[1]
			c.rt:advance(0.3)
			stop2()
			local colour = belt.Color
			local pivot = groupsOf(model2).Head:GetPivot()
			c.rt:advance(0.5)
			expect(belt.Color).toBeNear(colour, 1e-6)
			expect(groupsOf(model2).Head:GetPivot()).toBeNear(pivot, 1e-6)
		end
	)

	it("animates only while shown and inside the scrolling list", function()
		local c = client()
		local Vector2 = c.env.Vector2
		local list = c.rt:create("ScrollingFrame", { Name = "List" }, c.gui)
		Dom.rawSet(list, "AbsolutePosition", Vector2.new(0, 0))
		Dom.rawSet(list, "AbsoluteSize", Vector2.new(400, 300))
		local item = floaty(c)
		local inside, insideView = showPreview(c, item, list)
		Dom.rawSet(insideView, "AbsolutePosition", Vector2.new(10, 10))
		Dom.rawSet(insideView, "AbsoluteSize", Vector2.new(100, 100))
		local outside, outsideView = showPreview(c, item, list)
		Dom.rawSet(outsideView, "AbsolutePosition", Vector2.new(10, 900)) -- scrolled out of view
		Dom.rawSet(outsideView, "AbsoluteSize", Vector2.new(100, 100))
		expect(c.SkinAnim.PreviewVisible(insideView)).toBe(true)
		expect(c.SkinAnim.PreviewVisible(outsideView)).toBe(false)
		local restIn, restOut = groupsOf(inside).Head:GetPivot(), groupsOf(outside).Head:GetPivot()
		c.SkinAnim.AnimatePreview(inside)
		c.SkinAnim.AnimatePreview(outside)
		local changes = {}
		local stop = watchChanges(outside, changes)
		c.rt:advance(0.5)
		stop()
		expect(cfGap(groupsOf(inside).Head:GetPivot(), restIn)).toBeGreaterThan(1e-3)
		expect(groupsOf(outside).Head:GetPivot()).toBeNear(restOut, 1e-6)
		expect(next(changes)).toBeNil()
		-- a hidden card stops too
		insideView.Visible = false
		expect(c.SkinAnim.PreviewVisible(insideView)).toBe(false)
	end)

	it("moves pieces with the preview while CrateUI spins and scales it", function()
		local c = client()
		local item = testSkin("StudioDraft_Spun", {
			Head = "BatHead",
			Accent = { Pattern = "Wings" },
			Animate = {
				{ Effect = "Float", Target = "Head" },
				{ Effect = "Flap", Target = "Wings" },
				{ Effect = "Wobble", Target = "Part:Wing" },
			},
		})
		local model = showPreview(c, item)
		local groups = groupsOf(model)
		expect(groups["Part:Wing"].Parent).toBe(groups.Head)
		-- rest places relative to the parent group (or the model), at scale 1
		local rest = {}
		for name, g in groups do
			local parent = if g.Parent:GetAttribute("AnimGroup")
				then g.Parent:GetPivot()
				else model:GetPivot()
			rest[name] = parent:ToObjectSpace(g:GetPivot())
		end
		local base = model:GetPivot()
		c.SkinAnim.AnimatePreview(model)
		local run = c.rt.game:GetService("RunService")
		local spin = run.RenderStepped:Connect(function()
			local now = c.rt:now()
			model:PivotTo(base * CFrame.Angles(0, now * 2, 0))
			model:ScaleTo(1 + 0.5 * math.sin(now * 3))
		end)
		local checked = 0
		for _ = 1, 40 do
			c.rt:advance(1 / 60)
			local t = c.rt.workspace:GetServerTimeNow()
			local s = model:GetScale()
			for _, name in { "Head", "WingL", "WingR", "Part:Wing" } do
				local g = groups[name]
				local effects = {
					Head = { "Float" },
					WingL = { "Flap" },
					WingR = { "Flap" },
					["Part:Wing"] = { "Wobble" },
				}
				local o = CFrame.identity
				for _, effectName in effects[name] do
					local list = SkinAnimate.Normalize(item.Style.Animate)
					for _, e in list do
						if e.Effect == effectName then
							o *= SkinAnimate.Offset(e, t, g:GetAttribute("AnimSide") or 1)
						end
					end
				end
				local parent = if g.Parent:GetAttribute("AnimGroup")
					then g.Parent:GetPivot()
					else model:GetPivot()
				local r = rest[name]
				local want = parent
					* CFrame.new(r.Position * s)
					* r.Rotation
					* CFrame.new(o.Position * s)
					* o.Rotation
				expect(g:GetPivot()).toBeNear(want, 1e-3)
				checked += 1
			end
		end
		spin:Disconnect()
		T.note(checked, "group positions checked under spin and scale")
	end)

	it("moves at most MaxPreviewMotion previews at once, and none on phones", function()
		for _, onPhone in { false, true } do
			local c = client({ phone = onPhone })
			local cfg = c.Config.SkinAnimate
			local models = {}
			for i = 1, cfg.MaxPreviewMotion + 3 do
				local model = showPreview(c, floaty(c, "StudioDraft_Many" .. i))
				c.SkinAnim.AnimatePreview(model)
				table.insert(models, { Model = model, Rest = groupsOf(model).Head:GetPivot() })
			end
			c.rt:advance(0.5)
			local moving = 0
			for _, m in models do
				if cfGap(groupsOf(m.Model).Head:GetPivot(), m.Rest) > 1e-3 then
					moving += 1
				end
			end
			expect(moving).toBe(if onPhone then 0 else cfg.MaxPreviewMotion)
		end
	end)
end)
