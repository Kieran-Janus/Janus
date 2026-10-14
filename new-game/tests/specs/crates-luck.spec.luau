-- Crate luck, pack guarantees and Deluxe crates (docs/CRATE-LUCK-SPEC.md, section 10):
-- Config (K1), the odds maths (O1-O5), the economy rules (E1, E2), the server (S1-S8),
-- Robux receipts (R1-R4), the crate page against the real server (C8) and the crate page with
-- pretend server answers (C1-C7, C9-C11: the luck strip, Every chance, the pack window, the
-- in-flight and version rules, Open again, GUARANTEED, the R$ check and the Robux waits). The
-- phone layout (LuckLine above the pinned buttons) is in phoneui.spec.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

-- PolicyService for these tests (as in crates.spec): players called "Restricted..." live where
-- paid random items aren't allowed; everyone else may open crates.
Dom.define("PolicyService", {
	GetPolicyInfoForPlayerAsync = function(_self, player)
		local name = Dom.get(player, "Name")
		return {
			AreAdsAllowed = true,
			ArePaidRandomItemsRestricted = type(name) == "string"
				and name:sub(1, 10) == "Restricted",
			AllowedExternalLinkReferences = {},
			IsContentSharingAllowed = true,
			IsEligibleToPurchaseSubscription = true,
			IsPaidItemTradingAllowed = true,
			IsSubjectToChinaPolicies = false,
		}
	end,
})

-- Runs `fn`, then `cleanup` even if `fn` failed (for tests that change Config for a moment).
local function try(fn: () -> (), cleanup: () -> ())
	local ok, err = pcall(fn)
	cleanup()
	if not ok then
		error(err, 0)
	end
end

-- The total chance of `rarity` or better in a list of chances.
local function atOrAbove(CrateOdds: any, chances: { any }, rarity: string): number
	local total = 0
	for _, c in chances do
		if CrateOdds.RarityIndex(c.Rarity) >= CrateOdds.RarityIndex(rarity) then
			total += c.Chance
		end
	end
	return total
end

-- The chance of each item, by item id.
local function byId(chances: { any }): { [string]: number }
	local out = {}
	for _, c in chances do
		out[c.Item.Id] = c.Chance
	end
	return out
end

describe("Crate luck: Config (K1)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CrateOdds = rt:require("ReplicatedStorage.Shared.CrateOdds")
	local CrateLuck = rt:require("ReplicatedStorage.Shared.CrateLuck")
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	local cfg = Config.Crates

	it(
		"has a sane luck meter (I5: Steps x PerStep never needs more Common than there is)",
		function()
			local luck = cfg.Luck
			expect(luck.PerStep).toBeA("number")
			expect(luck.PerStep).toBeGreaterThan(0)
			expect(luck.Steps).toBeA("number")
			expect(luck.Steps % 1).toBe(0)
			expect(luck.Steps).toBeGreaterThanOrEqual(1)
			expect(luck.FullGuarantee).toBeA("boolean")
			expect(luck.Boost).toBeA("string")
			expect(luck.TakeFrom).toBeA("string")
			if luck.Steps * luck.PerStep > cfg.Odds[luck.TakeFrom] then
				error("I5: Luck.Steps x Luck.PerStep is more than Odds." .. luck.TakeFrom)
			end
			expect(CrateLuck.Steps()).toBe(luck.Steps)
			expect(cfg.Luck).toEqual({
				PerStep = 2,
				Steps = 15,
				FullGuarantee = true,
				Boost = "Rare",
				TakeFrom = "Common",
			})
		end
	)

	it("keeps the rarity order: TakeFrom < Boost < the top rarity, guarantees <= Boost", function()
		local order = Config.Rarity.Order
		local boost = table.find(order, cfg.Luck.Boost)
		local takeFrom = table.find(order, cfg.Luck.TakeFrom)
		expect(boost).toBeTruthy()
		expect(takeFrom).toBeTruthy()
		expect(boost).toBeLessThan(#order) -- below CRAZY
		expect(takeFrom).toBeLessThan(boost)
		expect(CrateLuck.ConfigOk()).toBe(true)
		for count, rarity in cfg.Open.Guarantee do
			expect(table.find(cfg.Open.Counts, count)).toBeTruthy()
			if not (count > 1) then
				error(("Open.Guarantee[%s]: guarantees are for packs (x5, x10) only"):format(count))
			end
			local index = table.find(order, rarity)
			expect(index).toBeTruthy()
			expect(index).toBeLessThanOrEqual(boost)
		end
		expect(cfg.Open.Guarantee[5]).toBe("Uncommon")
		expect(cfg.Open.Guarantee[10]).toBe("Rare")
	end)

	it("enforces the rarity order in code, not only in this test (D15)", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		expect(CrateLuck.Guarantee(pumpkin, 10)).toBe("Rare")
		expect(CrateLuck.Applies(pumpkin)).toBe(true)
		local warnings = #rt.warnings
		-- A single crate always has its page's chances: an Open.Guarantee[1] line is ignored.
		try(function()
			cfg.Open.Guarantee[1] = "Uncommon"
			expect(CrateLuck.Guarantee(pumpkin, 1)).toBeNil()
		end, function()
			cfg.Open.Guarantee[1] = nil
		end)
		-- A guarantee must change something: the crate must be able to give a rarity below it.
		expect(CrateLuck.Guarantee(pumpkin, 5)).toBe("Uncommon")
		expect(CrateLuck.Guarantee(CrateOdds.Get("RareCrate"), 10)).toBeNil() -- always Rare
		expect(CrateLuck.Guarantee(CrateOdds.Get("UncommonCrate"), 5)).toBeNil()
		expect(CrateLuck.Guarantee(CrateOdds.Get("PumpkinDeluxeCrate"), 5)).toBeNil() -- no Commons
		expect(CrateLuck.Guarantee(CrateOdds.Get("PumpkinDeluxeCrate"), 10)).toBe("Rare")
		for _, crate in CrateOdds.List() do
			for _, count in cfg.Open.Counts do
				local g = CrateLuck.Guarantee(crate, count)
				if g then
					local plain = CrateOdds.RarityOdds(crate)
					local boosted = CrateOdds.RarityOdds(crate, { AtLeast = g })
					local changed = false
					for rarity, percent in plain do
						if math.abs((boosted[rarity] or 0) - percent) > 1e-9 then
							changed = true
						end
					end
					if not changed then
						error(
							("%s x%d: the %s guarantee changes nothing"):format(crate.Id, count, g)
						)
					end
				end
			end
		end
		-- A CRAZY pack guarantee would hand out cheap CRAZY skins: ignored, with a warning.
		try(function()
			cfg.Open.Guarantee[10] = "Crazy"
			expect(CrateLuck.Guarantee(pumpkin, 10)).toBeNil()
		end, function()
			cfg.Open.Guarantee[10] = "Rare"
		end)
		for _, wrong in
			{
				{ Boost = "Crazy", TakeFrom = "Common" },
				{ Boost = "Rare", TakeFrom = "Rare" },
				{ Boost = "Rare", TakeFrom = "Crazy" },
				{ Boost = "Nope", TakeFrom = "Common" },
			}
		do
			try(function()
				cfg.Luck.Boost = wrong.Boost
				cfg.Luck.TakeFrom = wrong.TakeFrom
				expect(CrateLuck.ConfigOk()).toBe(false)
				for _, crate in CrateOdds.List() do
					if CrateLuck.Applies(crate) then
						error(
							("%s has a meter with Boost %s, TakeFrom %s"):format(
								crate.Id,
								wrong.Boost,
								wrong.TakeFrom
							)
						)
					end
				end
				-- (and no pack guarantee can rely on a broken Boost)
				expect(CrateLuck.Guarantee(pumpkin, 10)).toBeNil()
			end, function()
				cfg.Luck.Boost = "Rare"
				cfg.Luck.TakeFrom = "Common"
			end)
		end
		expect(#rt.warnings).toBeGreaterThan(warnings) -- Output says why
		expect(CrateLuck.Applies(pumpkin)).toBe(true)
	end)

	it("has positive Robux hold times", function()
		local r = cfg.RobuxOpen
		for _, key in
			{
				"Cooldown",
				"HoldSeconds",
				"MaxHoldSeconds",
				"ClientWaitSeconds",
				"RemoteWaitSeconds",
			}
		do
			expect(r[key]).toBeA("number")
			expect(r[key]).toBeGreaterThan(0)
		end
		expect(r.MaxHoldSeconds).toBeGreaterThanOrEqual(r.HoldSeconds)
	end)

	it("builds the six Deluxe crates from their Base crates", function()
		local premium = cfg.Premium
		local total = 0
		for _, v in premium.Odds do
			total += v
		end
		expect(total).toBeNear(100, 1e-9)
		expect(premium.ShakeTimes).toBeGreaterThanOrEqual(1)
		-- Deluxe crates are only in Menu > Crates and the opening (not on the lobby stand), so
		-- a Look key only the stand uses (Bob, Sway, PeekEvery, PeekAngle, Sparkles, Sounds)
		-- would do nothing, and ShakeTimes sets Shake.
		local shows = { Style = true, Emblem = true, Accent = true }
		for key in premium.Look do
			if not shows[key] then
				error(
					("Premium.Look.%s does nothing: Deluxe crates aren't on the lobby stand"):format(
						tostring(key)
					)
				)
			end
		end
		expect(table.find(cfg.Categories, premium.Category)).toBeTruthy()
		expect(cfg.Admin.LuckSteps).toBe(5)
		local themeCrates: { [string]: boolean } = {}
		for _, theme in Config.Skins.AllThemes do
			themeCrates[theme.Crate] = true
		end
		local ids: { [string]: boolean } = {}
		for _, crate in cfg.List do
			ids[crate.Id] = true
		end
		local seen: { [string]: boolean } = {}
		for _, line in premium.Crates do
			if not themeCrates[line.Base] then
				error(("Premium crate %s: Base %s isn't a themed crate"):format(line.Id, line.Base))
			end
			expect(seen[line.Id]).toBeNil()
			seen[line.Id] = true
			expect(themeCrates[line.Id]).toBeNil() -- not a themed crate's Id
		end
		expect(#premium.Crates).toBe(6)
		local deluxe = 0
		for _, crate in cfg.List do
			if crate.Base then
				deluxe += 1
				local base = CrateOdds.Get(crate.Base)
				expect(base).toBeTruthy()
				expect(crate.Price).toBe(2000)
				expect(crate.Robux.ProductId).toBe(0)
				expect(crate.Robux.SuggestedRobux).toBe(premium.SuggestedRobux)
				expect(crate.Category).toBe("Deluxe")
				expect(crate.New).toBe(true)
				expect(crate.Name).toBe("Deluxe " .. base.Name)
				expect(crate.Trim).toBeNear(premium.Trim)
				expect(crate.Odds).toEqual(premium.Odds)
				expect(crate.Odds).never.toBe(premium.Odds) -- (its own copy)
				for key, value in premium.Look do
					expect(crate.Look[key]).toBe(value)
				end
				local baseShake = base.Look.Shake or cfg.LookDefaults.Shake
				expect(crate.Look.Shake).toBeNear(baseShake * premium.ShakeTimes, 1e-9)
				expect(crate.Look.Style).toBe(base.Look.Style)
				-- The same skins as its base crate.
				local mine, theirs = {}, {}
				for _, item in CrateOdds.Items(crate) do
					table.insert(mine, item.Id)
				end
				for _, item in CrateOdds.Items(base) do
					table.insert(theirs, item.Id)
				end
				expect(mine).toEqual(theirs)
				expect(#mine).toBe(#Items.ByCrate(base.Id))
			end
		end
		expect(deluxe).toBe(6)
		-- The Deluxe Monster shakes harder than the Monster Crate (1.4 x 1.25 = 1.75).
		expect(CrateOdds.Get("MonsterDeluxeCrate").Look.Shake).toBeNear(1.75, 1e-9)
		expect(CrateOdds.Get("MonsterDeluxeCrate").Look.Shake).toBeGreaterThan(
			CrateOdds.Get("MonsterCrate").Look.Shake
		)
		-- Not on the lobby stand.
		for _, id in cfg.Stand.Themed do
			expect(CrateOdds.Get(id).Base).toBeNil()
		end
	end)

	it("takes a Deluxe crate out with its base crate's theme", function()
		local other = Runtime.new()
		local InGame = other:require("ReplicatedStorage.Shared.Config.Skins.InGame")
		InGame.Themes.Pumpkin = false
		local OtherConfig = other:require("ReplicatedStorage.Shared.Config")
		local ids: { [string]: boolean } = {}
		for _, crate in OtherConfig.Crates.List do
			ids[crate.Id] = true
		end
		expect(ids.PumpkinCrate).toBeNil()
		expect(ids.PumpkinDeluxeCrate).toBeNil()
		expect(ids.CandyCrate).toBe(true)
		expect(ids.CandyDeluxeCrate).toBe(true)
	end)

	it("has the three switches and the saved luck table", function()
		for _, name in { "CrateLuck", "CratePacks", "PremiumCrates" } do
			expect(Config.Features[name]).toBe(true)
		end
		expect(Config.Data.Template.Crates).toEqual({ Opened = 0, Luck = {} })
		expect(cfg.SmallOdds).toBeNil() -- chances are always exact now
		expect(cfg.Text.OpenAnother).toBe("Open again")
	end)

	it(
		"keeps Deluxe crates out of Skin Studio's crate list and back in when switched on",
		function()
			local premium = Config.Features.PremiumCrates
			try(function()
				Config.Features.PremiumCrates = false
				for _, crate in CrateOdds.List() do
					expect(crate.Base).toBeNil()
				end
				expect(CrateOdds.Get("PumpkinDeluxeCrate")).toBeNil()
				expect(CrateOdds.Available(cfg.List[#cfg.List])).toBe(
					cfg.List[#cfg.List].Base == nil
				)
				-- (a receipt for one still finds it, to pay its coins)
				local deluxe = nil
				for _, crate in cfg.List do
					if crate.Id == "PumpkinDeluxeCrate" then
						deluxe = crate
					end
				end
				deluxe.Robux.ProductId = 98765
				expect(CrateOdds.ByProductId(98765)).toBe(deluxe)
				deluxe.Robux.ProductId = 0
			end, function()
				Config.Features.PremiumCrates = premium
			end)
			expect(CrateOdds.Get("PumpkinDeluxeCrate")).toBeTruthy()
			local SkinSchema = rt:require("ReplicatedStorage.Shared.SkinSchema")
			local field = nil
			for _, f in SkinSchema.Fields do
				if f.Path and f.Path[1] == "Crate" then
					field = f
				end
			end
			assert(field and type(field.Choices) == "function", "SkinSchema has no Crate choice")
			local choices = field.Choices()
			expect(table.find(choices, "PumpkinCrate")).toBeTruthy()
			for _, id in choices do
				expect(CrateOdds.Get(id).Base).toBeNil()
			end
		end
	)
end)

describe("Crate luck: the odds (O1-O5)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CrateOdds = rt:require("ReplicatedStorage.Shared.CrateOdds")
	local CrateLuck = rt:require("ReplicatedStorage.Shared.CrateLuck")
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	local steps = CrateLuck.Steps()
	local F = CrateOdds.Format

	local guarantees: { string | false } = { false }
	for _, rarity in Config.Crates.Open.Guarantee do
		table.insert(guarantees, rarity)
	end

	it(
		"O1: every crate, every level, every guarantee: chances add up to 100, fixed skins exact",
		function()
			local checked = 0
			for _, crate in CrateOdds.List() do
				for level = 0, steps do
					for _, g in guarantees do
						local atLeast = if g then g else nil
						local boost = CrateLuck.Boost(crate, level, atLeast)
						local chances = CrateOdds.Chances(crate, boost)
						local total = 0
						local byRarity: { [string]: number } = {}
						for _, c in chances do
							if not (c.Chance > 0) then
								error(
									("%s level %d: %s has chance %s"):format(
										crate.Id,
										level,
										c.Item.Id,
										tostring(c.Chance)
									)
								)
							end
							total += c.Chance
							byRarity[c.Rarity] = (byRarity[c.Rarity] or 0) + c.Chance
							if type(c.Item.Odds) == "number" then
								expect(c.Chance).toBe(c.Item.Odds) -- one in a million, exactly
							end
						end
						if math.abs(total - 100) > 1e-9 then
							error(
								("%s level %d %s: chances add up to %.12f"):format(
									crate.Id,
									level,
									tostring(atLeast),
									total
								)
							)
						end
						for rarity, percent in CrateOdds.RarityOdds(crate, boost) do
							expect(byRarity[rarity] or 0).toBeNear(percent, 1e-9)
						end
						-- A guarantee that applies leaves nothing below it.
						if boost and boost.AtLeast then
							expect(atOrAbove(CrateOdds, chances, boost.AtLeast)).toBeNear(100, 1e-9)
						end
						checked += 1
					end
				end
			end
			T.note(checked, "crate states checked")
		end
	)

	it("O1: the Pumpkin Crate at luck 0, 4, 14 and 15 (the table in section 3.5)", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		local spice = "Pumpkin_PumpkinSpice" -- a Common
		local crazy = "Pumpkin_MegaGourdSupreme" -- the CRAZY
		local rare: string? = nil
		local gourd: string? = nil -- an Uncommon
		for _, item in Items.ByCrate("PumpkinCrate") do
			if Items.Rarity(item) == "Rare" then
				rare = item.Id
			elseif Items.Rarity(item) == "Uncommon" then
				gourd = item.Id
			end
		end
		assert(rare and gourd, "no Pumpkin Rare or Uncommon")
		expect(Items.Rarity(Items.Get(spice))).toBe("Common")
		expect(Items.Rarity(Items.Get(crazy))).toBe("Crazy")
		local rows = {
			{ 0, "5.082%", "7.5%", "15.02%" },
			{ 4, "4.415%", "11.5%", "23.02%" },
			{ 9, "3.582%", "16.5%", "33.02%" },
			{ 14, "2.748%", "21.5%", "43.02%" },
		}
		for _, row in rows do
			local level, common, rareEach, rarePlus = row[1], row[2], row[3], row[4]
			local chances = CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, level))
			local c = byId(chances)
			expect(F(c[spice])).toBe(common)
			expect(F(c[gourd])).toBe("4.8%")
			expect(F(c[rare])).toBe(rareEach)
			expect(F(c[crazy])).toBe("0.02%")
			expect(F(atOrAbove(CrateOdds, chances, "Rare"))).toBe(rarePlus)
		end
		-- Every level 0-14: Common loses 2 per step, Rare gains it, the rest stay.
		for level = 0, steps - 1 do
			local c = byId(CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, level)))
			expect(c[spice]).toBeNear((60.98 - 2 * level) / 12, 1e-9)
			expect(c[rare]).toBeNear((15 + 2 * level) / 2, 1e-9)
			expect(c[gourd]).toBeNear(4.8, 1e-9)
			expect(c[crazy]).toBeNear(0.02, 1e-9)
		end
		-- Full meter: Rare or better for sure.
		local full = CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, 15))
		local c = byId(full)
		expect(c[spice]).toBeNil()
		expect(c[gourd]).toBeNil()
		expect(F(c[rare])).toBe("49.978%")
		expect(F(c[crazy])).toBe("0.04442%")
		expect(atOrAbove(CrateOdds, full, "Rare")).toBeNear(100, 1e-9)
		expect(CrateLuck.Boost(pumpkin, 15).AtLeast).toBe("Rare")
		-- Saved levels above Steps read as a full meter.
		expect(CrateLuck.Clamp(40)).toBe(steps)
	end)

	it("O1: the newer crates, the one-in-a-million skins and Deluxe Pumpkin", function()
		-- Zombie Town (13 / 5 / 3, no ordinary CRAZY): scaled over 99.98.
		local zombie = CrateOdds.Get("ZombieTownCrate")
		if zombie then
			local odds = CrateOdds.RarityOdds(zombie, CrateLuck.Boost(zombie, 0))
			expect(F(odds.Common)).toBe("60.992%")
			expect(F(odds.Uncommon)).toBe("24.005%")
			expect(F(odds.Rare)).toBe("15.003%")
			expect(odds.Crazy).toBeNil()
			local full = CrateOdds.RarityOdds(zombie, CrateLuck.Boost(zombie, 15))
			expect(F(full.Rare)).toBe("100%")
			expect(full.Common).toBeNil()
		end
		-- The one-in-a-million skins keep exactly 0.0001% at every level and guarantee.
		for _, item in Config.Shop.Items do
			if item.OneInAMillion then
				local crate = CrateOdds.Get(item.Crate)
				if crate then
					for level = 0, steps do
						for _, g in guarantees do
							local c = byId(
								CrateOdds.Chances(
									crate,
									CrateLuck.Boost(crate, level, if g then g else nil)
								)
							)
							expect(c[item.Id]).toBe(0.0001)
							expect(F(c[item.Id])).toBe("0.0001%")
						end
					end
				end
			end
		end
		local vampire = CrateOdds.Get("VampireCastleCrate")
		if vampire then
			expect(F(CrateOdds.RarityOdds(vampire, CrateLuck.Boost(vampire, 0)).Rare)).toBe(
				"15.003%"
			)
			local full = CrateOdds.RarityOdds(vampire, CrateLuck.Boost(vampire, 15))
			expect(F(full.Rare)).toBe("99.9999%")
		end
		-- Deluxe Pumpkin: each Uncommon 10%, each Rare 24.5%, the CRAZY 1%, Commons 0%.
		local deluxe = CrateOdds.Get("PumpkinDeluxeCrate")
		expect(CrateLuck.Boost(deluxe, 15)).toBeNil() -- no meter
		for _, c in CrateOdds.Chances(deluxe) do
			local want = ({ Uncommon = "10%", Rare = "24.5%", Crazy = "1%" })[c.Rarity]
			expect(F(c.Chance)).toBe(want)
		end
	end)

	it("O1: the guaranteed crates of section 4.5", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		-- x10 from luck 0: the 10th crate is at luck 9 and can only be Rare or better.
		local level10 = CrateLuck.PackLevel(pumpkin, 0, 10)
		expect(level10).toBe(9)
		local x10 = CrateOdds.Chances(
			pumpkin,
			CrateLuck.Boost(pumpkin, level10, CrateLuck.Guarantee(pumpkin, 10))
		)
		local odds10 = CrateOdds.RarityOdds(pumpkin, CrateLuck.Boost(pumpkin, level10, "Rare"))
		expect(F(odds10.Crazy)).toBe("0.06057%")
		expect(F(odds10.Rare)).toBe("99.939%")
		for _, c in x10 do
			if c.Rarity == "Rare" then
				expect(F(c.Chance)).toBe("49.97%")
			end
		end
		-- x5 from luck 0: the 5th crate is at luck 4 and can't be Common.
		local level5 = CrateLuck.PackLevel(pumpkin, 0, 5)
		expect(level5).toBe(4)
		local odds5 = CrateOdds.RarityOdds(
			pumpkin,
			CrateLuck.Boost(pumpkin, level5, CrateLuck.Guarantee(pumpkin, 5))
		)
		expect(F(odds5.Crazy)).toBe("0.04254%")
		expect(F(odds5.Rare)).toBe("48.915%")
		expect(F(odds5.Uncommon)).toBe("51.042%")
		expect(odds5.Common).toBeNil()
		-- A pack that fills the meter on the way: the levels stop at Steps.
		expect(CrateLuck.PackLevel(pumpkin, 11, 5)).toBe(15)
		expect(CrateLuck.PackLevel(pumpkin, 14, 10)).toBe(15)
		expect(CrateLuck.PackLevel(CrateOdds.Get("RareCrate"), 3, 10)).toBe(0)
		-- Deluxe x10: only reached after nine Uncommons; then Rare 98%, CRAZY 2%.
		local deluxe = CrateOdds.Get("PumpkinDeluxeCrate")
		local d10 = CrateOdds.RarityOdds(
			deluxe,
			CrateLuck.Boost(deluxe, 0, CrateLuck.Guarantee(deluxe, 10))
		)
		expect(F(d10.Rare)).toBe("98%")
		expect(F(d10.Crazy)).toBe("2%")
	end)

	it(
		"O2: no meter on rarity or Deluxe crates, or with CrateLuck off; guarantees must be possible",
		function()
			for _, crate in CrateOdds.List() do
				if crate.Rarity or crate.Base then
					expect(CrateLuck.Applies(crate)).toBe(false)
					for level = 0, steps do
						expect(CrateLuck.Boost(crate, level)).toBeNil()
					end
				end
			end
			local features = Config.Features
			try(function()
				features.CrateLuck = false
				for _, crate in CrateOdds.List() do
					expect(CrateLuck.Applies(crate)).toBe(false)
					expect(CrateLuck.Boost(crate, 15)).toBeNil()
					expect(CrateLuck.PackLevel(crate, 5, 10)).toBe(0)
				end
				-- Pack guarantees don't need the meter.
				expect(CrateLuck.Guarantee(CrateOdds.Get("PumpkinCrate"), 10)).toBe("Rare")
			end, function()
				features.CrateLuck = true
			end)
			try(function()
				features.CratePacks = false
				expect(CrateLuck.Guarantee(CrateOdds.Get("PumpkinCrate"), 10)).toBeNil()
			end, function()
				features.CratePacks = true
			end)
			expect(CrateOdds.CanGuarantee(CrateOdds.Get("CommonCrate"), "Rare")).toBe(false)
			expect(CrateOdds.CanGuarantee(CrateOdds.Get("CrazyCrate"), "Rare")).toBe(false)
			expect(CrateOdds.CanGuarantee(CrateOdds.Get("PumpkinCrate"), "Rare")).toBe(true)
			expect(CrateLuck.Guarantee(CrateOdds.Get("CommonCrate"), 10)).toBeNil()
			expect(CrateLuck.Guarantee(CrateOdds.Get("PumpkinCrate"), 1)).toBeNil()
			expect(CrateOdds.Higher("Common", "Rare")).toBe("Rare")
			expect(CrateOdds.Higher("Crazy", "Rare")).toBe("Crazy")
			expect(CrateOdds.Higher(nil, "Uncommon")).toBe("Uncommon")
			expect(CrateOdds.Higher(nil, nil)).toBeNil()
			-- A crate line with Luck = false has no meter.
			local pumpkin = CrateOdds.Get("PumpkinCrate")
			try(function()
				pumpkin.Luck = false
				expect(CrateLuck.Applies(pumpkin)).toBe(false)
			end, function()
				pumpkin.Luck = nil
			end)
		end
	)

	-- Within 5 standard deviations (a correct roll fails this about once in 1.7 million).
	local function simulate(chances: { any }, rolls: number, seed: number): string
		local rng = rt.env.Random.new(seed)
		local hits: { [string]: number } = {}
		for _ = 1, rolls do
			local item = CrateOdds.Pick(chances, rng:NextNumber())
			hits[item.Id] = (hits[item.Id] or 0) + 1
		end
		local rarityHits: { [string]: number } = {}
		local rarityOdds: { [string]: number } = {}
		for _, c in chances do
			local p = c.Chance / 100
			local count = hits[c.Item.Id] or 0
			local sigma = math.sqrt(rolls * p * (1 - p))
			if math.abs(count - rolls * p) > 5 * sigma + 1 then
				error(("%s: %d hits, expected about %.0f"):format(c.Item.Id, count, rolls * p))
			end
			rarityHits[c.Rarity] = (rarityHits[c.Rarity] or 0) + count
			rarityOdds[c.Rarity] = (rarityOdds[c.Rarity] or 0) + c.Chance
		end
		for rarity, percent in rarityOdds do
			local p = percent / 100
			local sigma = math.sqrt(rolls * p * (1 - p))
			if math.abs(rarityHits[rarity] - rolls * p) > 5 * sigma + 1 then
				error(
					("%s: %d hits, expected about %.0f"):format(
						rarity,
						rarityHits[rarity],
						rolls * p
					)
				)
			end
		end
		return ("Common %d, Uncommon %d, Rare %d, CRAZY %d"):format(
			rarityHits.Common or 0,
			rarityHits.Uncommon or 0,
			rarityHits.Rare or 0,
			rarityHits.Crazy or 0
		)
	end

	it(
		"O3: 200,000 simulated rolls match the shown chances (luck 7, full meter, x10 crate)",
		function()
			local pumpkin = CrateOdds.Get("PumpkinCrate")
			T.note(
				"luck 7: "
					.. simulate(CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, 7)), 200000, 7)
			)
			T.note(
				"full: "
					.. simulate(
						CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, 15)),
						200000,
						15
					)
			)
			local x10 = CrateOdds.Chances(pumpkin, CrateLuck.Boost(pumpkin, 9, "Rare"))
			T.note("x10 guaranteed crate: " .. simulate(x10, 200000, 10))
			local deluxe = CrateOdds.Get("PumpkinDeluxeCrate")
			T.note("Deluxe: " .. simulate(CrateOdds.Chances(deluxe), 200000, 99))
		end
	)

	it("O4: with a boost the reel is drawn from the odds rolled, and never teases", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		local guard = Config.Crates.Opening.TeaseGuard
		local cards, win = Config.Crates.Reel.Cards, Config.Crates.Reel.WinIndex
		for _, case in { { 15, nil }, { 9, "Rare" }, { 4, "Uncommon" } } do
			local boost = CrateLuck.Boost(pumpkin, case[1], case[2])
			local possible = byId(CrateOdds.Chances(pumpkin, boost))
			for _, c in CrateOdds.Chances(pumpkin, boost) do
				local level = CrateOdds.RarityIndex(c.Rarity)
				for seed = 1, 60 do
					local reel = CrateOdds.Reel(
						pumpkin,
						c.Item.Id,
						rt.env.Random.new(seed),
						cards,
						win,
						boost
					)
					expect(reel[win]).toBe(c.Item.Id)
					for i, id in reel do
						if not possible[id] then
							error(("card %d (%s) can't drop with this boost"):format(i, id))
						end
						if i ~= win and math.abs(i - win) <= guard then
							if CrateOdds.RarityIndex(Items.Rarity(Items.Get(id))) > level then
								error(
									("seed %d: card %d is rarer than the %s win"):format(
										seed,
										i,
										c.Rarity
									)
								)
							end
						end
					end
				end
			end
		end
	end)

	it("O5: Shown lists every skin, in Chances order, 0 for those that can't drop", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		local boost = CrateLuck.Boost(pumpkin, 15)
		local shown = CrateOdds.Shown(pumpkin, boost)
		expect(#shown).toBe(20)
		local zeros = 0
		local nonZero = {}
		for _, c in shown do
			if c.Chance == 0 then
				zeros += 1
				expect(CrateOdds.RarityIndex(c.Rarity)).toBeLessThan(CrateOdds.RarityIndex("Rare"))
			else
				table.insert(nonZero, c)
			end
		end
		expect(zeros).toBe(17)
		local chances = CrateOdds.Chances(pumpkin, boost)
		expect(#nonZero).toBe(#chances)
		for i, c in chances do
			expect(nonZero[i].Item).toBe(c.Item)
			expect(nonZero[i].Chance).toBe(c.Chance)
		end
		-- Highest rarity first, as on the page.
		for i = 2, #shown do
			expect(CrateOdds.RarityIndex(shown[i].Rarity)).toBeLessThanOrEqual(
				CrateOdds.RarityIndex(shown[i - 1].Rarity)
			)
		end
		local deluxe = CrateOdds.Shown(CrateOdds.Get("PumpkinDeluxeCrate"))
		expect(#deluxe).toBe(20)
		local commonsAtZero = 0
		for _, c in deluxe do
			if c.Rarity == "Common" then
				expect(c.Chance).toBe(0)
				expect(F(c.Chance)).toBe("0%")
				commonsAtZero += 1
			else
				expect(c.Chance).toBeGreaterThan(0)
			end
		end
		expect(commonsAtZero).toBe(12)
		-- Vampire Castle: the one-in-a-million skin first, as in Chances.
		local vampire = CrateOdds.Get("VampireCastleCrate")
		if vampire then
			local v = CrateOdds.Shown(vampire, CrateLuck.Boost(vampire, 15))
			expect(v[1].Item.OneInAMillion).toBe(true)
			expect(v[1].Chance).toBe(0.0001)
		end
	end)

	it("formats every chance exactly (never 0% or 100% unless it is)", function()
		expect(F(60.98 / 12)).toBe("5.082%")
		expect(F(24)).toBe("24%")
		expect(F(4.8)).toBe("4.8%")
		expect(F(15.02)).toBe("15.02%")
		expect(F(0.02)).toBe("0.02%")
		expect(F(0.02 / 45.02 * 100)).toBe("0.04442%")
		expect(F(0.02 / 33.02 * 100)).toBe("0.06057%")
		expect(F(0.02 / 47.02 * 100)).toBe("0.04254%")
		expect(F(0.0001)).toBe("0.0001%")
		expect(F(99.9999)).toBe("99.9999%")
		expect(F(99.99995)).never.toBe("100%")
		expect(F(1e-9)).never.toBe("0%")
		expect(F(0)).toBe("0%")
		expect(F(-1)).toBe("0%")
		expect(F(100)).toBe("100%")
	end)
end)

-- The economy (section 6): exact expectations from Config, with Markov chains over the meter.
local function economy(rt: any)
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CrateOdds = rt:require("ReplicatedStorage.Shared.CrateOdds")
	local CrateLuck = rt:require("ReplicatedStorage.Shared.CrateLuck")
	local order = Config.Rarity.Order
	local levels = Config.Rarity.Levels
	local boostIndex = CrateOdds.RarityIndex(Config.Crates.Luck.Boost)
	local E = {}

	-- Expected numbers for one crate at `level` (with an optional guarantee): Rare or better,
	-- CRAZY, value at shop prices, duplicate refund, and the chance of each rarity.
	function E.one(crate: any, level: number, atLeast: string?): any
		local odds = CrateOdds.RarityOdds(crate, CrateLuck.Boost(crate, level, atLeast))
		local out = { RarePlus = 0, Crazy = 0, Value = 0, Refund = 0, P = {} }
		for _, rarity in order do
			local p = (odds[rarity] or 0) / 100
			out.P[rarity] = p
			if CrateOdds.RarityIndex(rarity) >= boostIndex then
				out.RarePlus += p
			end
			if levels[rarity].Rainbow then
				out.Crazy += p
			end
			out.Value += p * levels[rarity].Price
			out.Refund += p * levels[rarity].DuplicateRefund
		end
		return out
	end

	-- N crates in a row from `start` (a pack with guarantee G, or singles with G = nil):
	-- expected totals and the chance of each level afterwards.
	function E.run(crate: any, start: number, count: number, guarantee: string?): (any, { number })
		local applies = CrateLuck.Applies(crate)
		local steps = CrateLuck.Steps()
		local states: { [string]: number } = { [("%d|0"):format(start)] = 1 }
		local total = { RarePlus = 0, Crazy = 0, Value = 0, Refund = 0 }
		for k = 1, count do
			local nextStates: { [string]: number } = {}
			for key, p in states do
				local level = tonumber(key:match("^(%d+)")) :: number
				local met = key:sub(-1) == "1"
				local atLeast = if guarantee and k == count and not met then guarantee else nil
				local one = E.one(crate, level, atLeast)
				for name in total do
					total[name] += p * one[name]
				end
				for rarity, pr in one.P do
					if pr > 0 then
						local after = if applies then CrateLuck.After(crate, level, rarity) else 0
						local nowMet = met
							or (
								guarantee ~= nil
								and CrateOdds.RarityIndex(rarity)
									>= CrateOdds.RarityIndex(guarantee)
							)
						local nk = ("%d|%d"):format(after, if nowMet then 1 else 0)
						nextStates[nk] = (nextStates[nk] or 0) + p * pr
					end
				end
			end
			states = nextStates
		end
		local ends = table.create(steps + 1, 0)
		for key, p in states do
			local level = tonumber(key:match("^(%d+)")) :: number
			ends[level + 1] += p
		end
		return total, ends
	end

	-- The long-run share of each starting level for someone who always buys `count` at once.
	function E.stationary(crate: any, count: number, guarantee: string?): { number }
		local steps = CrateLuck.Steps()
		local moves = {}
		for start = 0, steps do
			local _, ends = E.run(crate, start, count, guarantee)
			moves[start + 1] = ends
		end
		local pi = table.create(steps + 1, 0)
		pi[1] = 1
		for _ = 1, 3000 do
			local nextPi = table.create(steps + 1, 0)
			for a = 1, steps + 1 do
				for b = 1, steps + 1 do
					nextPi[b] += pi[a] * moves[a][b]
				end
			end
			pi = nextPi
		end
		return pi
	end

	-- Long-run averages per crate for someone who always buys `count` at once.
	function E.longRun(crate: any, count: number, guarantee: string?): any
		local pi = E.stationary(crate, count, guarantee)
		local avg = { RarePlus = 0, Crazy = 0, Value = 0, Refund = 0 }
		for start = 0, CrateLuck.Steps() do
			local total = E.run(crate, start, count, guarantee)
			for name in avg do
				avg[name] += pi[start + 1] * total[name] / count
			end
		end
		return avg, pi
	end

	return E
end

describe("Crate luck: the economy stays sane (E1, E2)", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CrateOdds = rt:require("ReplicatedStorage.Shared.CrateOdds")
	local CrateLuck = rt:require("ReplicatedStorage.Shared.CrateLuck")
	local E = economy(rt)
	local steps = CrateLuck.Steps()
	local crazyPrice = CrateOdds.CoinPrice(CrateOdds.Get("CrazyCrate"))
	local rarePrice = CrateOdds.CoinPrice(CrateOdds.Get("RareCrate"))
	local function rule(ok: boolean, message: string)
		if not ok then
			error(message, 2)
		end
	end
	local function commas(n: number): string
		local s = tostring(math.floor(n + 0.5))
		while true do
			local swapped, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			s = swapped
			if k == 0 then
				return s
			end
		end
	end

	-- I1 and I2 for every state a crate can really be rolled in: any level for a single crate,
	-- and a pack's guaranteed crate at its PackLevel. Returns the cheapest CRAZY (themed, Deluxe).
	local function checkStates(): (number, number)
		local worstThemed, worstDeluxe = math.huge, math.huge
		for _, crate in CrateOdds.List() do
			local price = CrateOdds.CoinPrice(crate)
			local states: { { number | string | false } } = {}
			local top = if CrateLuck.Applies(crate) then steps else 0
			for level = 0, top do
				table.insert(states, { level, false })
				for _, count in Config.Crates.Open.Counts do
					local g = CrateLuck.Guarantee(crate, count)
					if g then
						table.insert(states, { CrateLuck.PackLevel(crate, level, count), g })
					end
				end
			end
			for _, state in states do
				local level = state[1] :: number
				local g = if state[2] then state[2] :: string else nil
				local one = E.one(crate, level, g)
				rule(
					price > one.Refund,
					("I1: %s at luck %d (%s) pays back %.0f of %d coins"):format(
						crate.Id,
						level,
						tostring(g),
						one.Refund,
						price
					)
				)
				if one.Crazy > 0 then
					local perCrazy = price / one.Crazy
					rule(
						perCrazy >= crazyPrice - 1e-6,
						("I2: %s at luck %d (%s) gives a CRAZY for %.0f coins"):format(
							crate.Id,
							level,
							tostring(g),
							perCrazy
						)
					)
					if crate.Base then
						worstDeluxe = math.min(worstDeluxe, perCrazy)
					elseif not crate.Rarity then
						worstThemed = math.min(worstThemed, perCrazy)
					end
				end
			end
		end
		return worstThemed, worstDeluxe
	end

	-- (Only the rules fail here, naming the rule: a fair change to odds, luck or prices passes.
	-- Today's exact numbers are checked in the next test.)
	it("E1: I1 and I2 hold for every crate state (no free coins, no cheap CRAZY)", function()
		local worstThemed, worstDeluxe = checkStates()
		T.note(
			"cheapest CRAZY: themed " .. commas(worstThemed) .. ", Deluxe " .. commas(worstDeluxe)
		)
		-- With the luck meter switched off the pack guarantee alone is still no cheap CRAZY.
		try(function()
			Config.Features.CrateLuck = false
			local offThemed = checkStates()
			T.note("CrateLuck off: cheapest themed CRAZY " .. commas(offThemed))
		end, function()
			Config.Features.CrateLuck = true
		end)
	end)

	-- Today's numbers, quoted in docs/CRATE-LUCK-SPEC.md section 6 and the Config comments.
	-- Not rules: after a fair change to Odds, Luck, Open.Guarantee or Premium these simply
	-- need the new numbers (and the docs too).
	it("E1: today's numbers in section 6 (update them after changing Config)", function()
		local worstThemed, worstDeluxe = checkStates()
		expect(math.floor(worstThemed + 0.5)).toBe(990600) -- the x10 guaranteed crate
		expect(math.floor(worstDeluxe + 0.5)).toBe(100000) -- the Deluxe x10 guaranteed crate
		try(function()
			Config.Features.CrateLuck = false
			local offThemed = checkStates()
			expect(math.floor(offThemed + 0.5)).toBe(450600) -- x10 at plain odds: 600 / (0.02 / 15.02)
		end, function()
			Config.Features.CrateLuck = true
		end)
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		local function row(name: string, one: any, price: number)
			T.note(
				("%s: Rare+ %.2f%%, CRAZY %.5f%%, value %.0f, refund %.0f, coins per CRAZY %s, value per coin %.2f"):format(
					name,
					one.RarePlus * 100,
					one.Crazy * 100,
					one.Value,
					one.Refund,
					commas(price / one.Crazy),
					one.Value / price
				)
			)
		end
		local l0 = E.one(pumpkin, 0)
		expect(l0.RarePlus).toBeNear(0.1502, 1e-9)
		expect(l0.Value).toBeNear(366.225, 1e-6) -- 0.6098 x 125 + 0.24 x 500 + 0.15 x 1000 + 0.0002 x 100000
		row("luck 0", l0, 600)
		local full = E.one(pumpkin, 15)
		expect(600 / full.Crazy).toBeNear(1350600, 1)
		row("full meter", full, 600)
		local x10 = E.one(pumpkin, 9, "Rare")
		expect(600 / x10.Crazy).toBeNear(990600, 1)
		row("x10 guaranteed crate", x10, 600)
		local x5 = E.one(pumpkin, 4, "Uncommon")
		expect(600 / x5.Crazy).toBeNear(1410600, 1)
		expect(x5.RarePlus).toBeNear(0.4896, 1e-4)
		row("x5 guaranteed crate", x5, 600)
		local deluxe = E.one(CrateOdds.Get("PumpkinDeluxeCrate"), 0)
		expect(2000 / deluxe.Crazy).toBeNear(200000, 1)
		expect(deluxe.Value).toBeNear(1740, 1e-6)
		row("Deluxe", deluxe, 2000)
	end)

	it("E1: I3, I4 and I6 over time and from every starting level", function()
		local pumpkin = CrateOdds.Get("PumpkinCrate")
		-- Singles, x5 only and x10 only, in the long run.
		local singles, pi = E.longRun(pumpkin, 1, nil)
		local x5 = E.longRun(pumpkin, 5, CrateLuck.Guarantee(pumpkin, 5))
		local x10 = E.longRun(pumpkin, 10, CrateLuck.Guarantee(pumpkin, 10))
		for name, avg in { singles = singles, x5 = x5, x10 = x10 } do
			local perRare = 600 / avg.RarePlus
			local perCoin = avg.Value / 600
			rule(
				perRare >= rarePrice,
				("I3: %s give a Rare or better for %.0f coins (Rare Crate %d)"):format(
					name,
					perRare,
					rarePrice
				)
			)
			rule(perCoin < 1, ("I4: %s are worth %.2f per coin"):format(name, perCoin))
			T.note(
				("%s over time: Rare+ %.2f%%, CRAZY %.4f%%, value %.0f, refund %.0f, coins per Rare+ %s, per CRAZY %s, value per coin %.2f"):format(
					name,
					avg.RarePlus * 100,
					avg.Crazy * 100,
					avg.Value,
					avg.Refund,
					commas(perRare),
					commas(600 / avg.Crazy),
					perCoin
				)
			)
		end
		-- (section 6: 21.01%, 21.27%, 21.18%; 2,856 coins per Rare; 0.70 per coin)
		expect(singles.RarePlus).toBeNear(0.2101, 1e-4)
		expect(x5.RarePlus).toBeNear(0.2127, 1e-4)
		expect(x10.RarePlus).toBeNear(0.2118, 1e-4)
		expect(600 / singles.RarePlus).toBeNear(2856, 1)
		expect(singles.Value / 600).toBeNear(0.70, 0.005)
		local share = {}
		for i, p in pi do
			table.insert(share, ("%d: %.1f%%"):format(i - 1, p * 100))
		end
		T.note("time at each level (singles): " .. table.concat(share, ", "))

		-- I6: from every starting level a pack is never worse than the same number of singles.
		for _, count in { 5, 10 } do
			local g = CrateLuck.Guarantee(pumpkin, count)
			local spreadPack, spreadSingles = 0, 0
			for start = 0, CrateLuck.Steps() do
				local pack = E.run(pumpkin, start, count, g)
				local single = E.run(pumpkin, start, count, nil)
				rule(
					pack.RarePlus >= single.RarePlus - 1e-12 and pack.Value >= single.Value - 1e-9,
					("I6: x%d from luck %d is worse than %d single opens"):format(
						count,
						start,
						count
					)
				)
				spreadPack += pi[start + 1] * pack.RarePlus
				spreadSingles += pi[start + 1] * single.RarePlus
				if start == 0 then
					T.note(
						("x%d from luck 0: %.3f Rare+ against %.3f from singles"):format(
							count,
							pack.RarePlus,
							single.RarePlus
						)
					)
					if count == 10 then
						expect(pack.RarePlus).toBeNear(1.994, 5e-4)
						expect(single.RarePlus).toBeNear(1.932, 5e-4)
					else
						expect(pack.RarePlus).toBeNear(0.918, 5e-4)
						expect(single.RarePlus).toBeNear(0.889, 5e-4)
					end
				end
			end
			T.note(
				("x%d, the usual spread of luck: %.3f against %.3f"):format(
					count,
					spreadPack,
					spreadSingles
				)
			)
		end

		-- Every themed crate and every Deluxe crate over time (I3, I4).
		for _, crate in CrateOdds.List() do
			if not crate.Rarity then
				local price = CrateOdds.CoinPrice(crate)
				for _, count in Config.Crates.Open.Counts do
					local avg = E.longRun(crate, count, CrateLuck.Guarantee(crate, count))
					rule(
						price / avg.RarePlus >= rarePrice,
						("I3: %s x%d gives a Rare or better for %.0f coins"):format(
							crate.Id,
							count,
							price / avg.RarePlus
						)
					)
					rule(
						avg.Value / price < 1,
						("I4: %s x%d is worth %.2f per coin"):format(
							crate.Id,
							count,
							avg.Value / price
						)
					)
					if avg.Crazy > 0 then
						rule(
							price / avg.Crazy >= crazyPrice,
							("I2: %s x%d gives a CRAZY for %.0f coins over time"):format(
								crate.Id,
								count,
								price / avg.Crazy
							)
						)
					end
				end
			end
		end
	end)

	it(
		"E2: a theme with its Rares hidden gets no meter and no Rare guarantee (no cheap CRAZY)",
		function()
			local items = Config.Shop.Items
			local pumpkin = CrateOdds.Get("PumpkinCrate")
			local removed: { { index: number, item: any } } = {}
			for i = #items, 1, -1 do
				local item = items[i]
				if item.Crate == "PumpkinCrate" and item.Rarity == "Rare" then
					table.insert(removed, { index = i, item = item })
					table.remove(items, i)
				end
			end
			expect(#removed).toBe(2)
			try(function()
				expect(CrateLuck.Applies(pumpkin)).toBe(false)
				expect(CrateOdds.CanGuarantee(pumpkin, "Rare")).toBe(false)
				expect(CrateLuck.Guarantee(pumpkin, 10)).toBeNil()
				expect(CrateLuck.Guarantee(pumpkin, 5)).toBe("Uncommon")
				local worst = math.huge
				for level = 0, steps do
					for _, g in { false, "Uncommon", "Rare" } do
						local atLeast = if g then g else nil
						local one = E.one(pumpkin, level, atLeast)
						expect(one.Crazy).toBeLessThan(0.01) -- (it was 100% with the old rule)
						local perCrazy = 600 / one.Crazy
						rule(
							perCrazy >= crazyPrice,
							("I2: hidden Rares, luck %d (%s): a CRAZY for %.0f"):format(
								level,
								tostring(atLeast),
								perCrazy
							)
						)
						worst = math.min(worst, perCrazy)
					end
				end
				expect(math.floor(worst + 0.5)).toBe(720600) -- the x5 guarantee
				local plain = CrateOdds.RarityOdds(pumpkin, CrateLuck.Boost(pumpkin, 15))
				expect(CrateOdds.Format(plain.Common)).toBe("71.741%")
				expect(CrateOdds.Format(plain.Crazy)).toBe("0.02353%")
				local x5 = CrateOdds.RarityOdds(pumpkin, CrateLuck.Boost(pumpkin, 0, "Uncommon"))
				expect(CrateOdds.Format(x5.Uncommon)).toBe("99.917%")
				expect(CrateOdds.Format(x5.Crazy)).toBe("0.08326%")
			end, function()
				for i = #removed, 1, -1 do
					table.insert(items, removed[i].index, removed[i].item)
				end
			end)
			expect(CrateLuck.Applies(pumpkin)).toBe(true)
		end
	)
end)

-- A server with the services crates need (as in crates.spec), plus helpers.
local function serverWorld(options: { [string]: any }?)
	local server = Runtime.new(options)
	local Config = server:require("ReplicatedStorage.Shared.Config")
	for _, name in { "Crates", "RobuxCrates", "CrateLuck", "CratePacks", "PremiumCrates" } do
		Config.Features[name] = true
	end
	local services = "ServerScriptService.Server.Services."
	local DataService = server:require(services .. "DataService")
	local ShopService = server:require(services .. "ShopService")
	local CrateService = server:require(services .. "CrateService")
	local MonetizationService = server:require(services .. "MonetizationService")
	local AdminService = server:require(services .. "AdminService")
	DataService.Start()
	ShopService.Start()
	MonetizationService.Start()
	CrateService.Start()
	AdminService.Start()
	local CrateOdds = server:require("ReplicatedStorage.Shared.CrateOdds")
	local CrateLuck = server:require("ReplicatedStorage.Shared.CrateLuck")
	local Marketplace = server.game:GetService("MarketplaceService")
	local w = {
		rt = server,
		Config = Config,
		Items = server:require("ReplicatedStorage.Shared.Items"),
		CrateOdds = CrateOdds,
		CrateLuck = CrateLuck,
		DataService = DataService,
		ShopService = ShopService,
		CrateService = CrateService,
		AdminService = AdminService,
	}
	local function remote(name: string): any
		return server:find("ReplicatedStorage.Remotes." .. name)
	end
	-- OpenCrate with exactly these arguments (after the cooldown).
	function w.raw(player: any, ...: any): any
		server:advance(Config.Crates.RequestCooldown + 0.1)
		return server:invokeServer(remote("OpenCrate"), player, ...)
	end
	-- OpenCrate like the crate page: the real level and guarantee unless given.
	function w.open(
		player: any,
		crateId: string,
		count: number?,
		luck: number?,
		guarantee: string?
	): any
		local n = count or 1
		local crate = CrateOdds.Get(crateId)
		local shown = if luck ~= nil then luck else CrateService.Luck(player, crateId)
		local g = guarantee
		if g == nil and crate then
			g = CrateLuck.Guarantee(crate, n)
		end
		return w.raw(player, crateId, n, shown, g)
	end
	function w.prepare(player: any, crateId: string, luck: number?): any
		server:advance(Config.Crates.RobuxOpen.Cooldown + 0.1)
		local shown = if luck ~= nil then luck else CrateService.Luck(player, crateId)
		return server:invokeServer(remote("PrepareCrateRobux"), player, crateId, shown)
	end
	-- Roblox's purchase window closing (server side).
	function w.finished(player: any, productId: number, purchased: boolean)
		server:fire(
			Marketplace,
			"PromptProductPurchaseFinished",
			player.UserId,
			productId,
			purchased
		)
	end
	function w.receipt(player: any, productId: number, purchaseId: string): any
		local callback = Dom.callback(Marketplace, "ProcessReceipt")
		return server:call(callback, {
			PlayerId = player.UserId,
			ProductId = productId,
			PurchaseId = purchaseId,
			CurrencySpent = 0,
		})
	end
	function w.join(name: string): (any, any)
		local player = server:addPlayer({ Name = name })
		server:advance(3)
		return player, DataService.Get(player)
	end
	local function sent(player: any, name: string): { any }
		local out = {}
		for _, call in server:calls("RemoteEvent", "FireClient") do
			if call.instance.Name == name and call.args[1] == player then
				table.insert(out, call.args[2])
			end
		end
		return out
	end
	function w.results(player: any): { any }
		return sent(player, "CrateResult")
	end
	function w.states(player: any): { any }
		return sent(player, "ShopState")
	end
	function w.setLuck(player: any, crateId: string, level: number)
		CrateLuck.Set(DataService.Get(player), CrateOdds.Get(crateId), level)
	end
	function w.saved(player: any, crateId: string): any
		local luck = DataService.Get(player).Crates.Luck
		return if type(luck) == "table" then luck[crateId] else nil
	end
	return w
end

describe("Crate luck: the server (S1-S7)", function()
	local w = serverWorld()
	local Config = w.Config
	local CrateOdds, CrateLuck = w.CrateOdds, w.CrateLuck
	local text = Config.Crates.Text
	local pumpkin = CrateOdds.Get("PumpkinCrate")
	local luckCfg = Config.Crates.Luck

	-- Forces what the Pumpkin Crate gives (its own Odds) with the meter still on: a tiny chance
	-- keeps Rare and Common "in" the crate, and PerStep 0 stops the meter from moving them.
	local function forcing(odds: { [string]: number }, fn: () -> ())
		try(function()
			pumpkin.Odds = odds
			luckCfg.PerStep = 0
			expect(CrateLuck.Applies(pumpkin)).toBe(true)
			fn()
		end, function()
			pumpkin.Odds = nil
			luckCfg.PerStep = 2
			luckCfg.FullGuarantee = true
		end)
	end

	it(
		"S1: below Rare fills a step, Rare or better empties it, a full meter is Rare for sure",
		function()
			local player, data = w.join("Lucky")
			data.Coins = 1000000
			forcing({ Common = 100, Rare = 1e-9 }, function()
				local r = w.open(player, "PumpkinCrate")
				expect(r.Ok).toBe(true)
				expect(r.Rarity).toBe("Common")
				expect(r.Luck).toBe(0)
				expect(r.LuckAfter).toBe(1)
				expect(r.Guaranteed).toBeNil()
				expect(w.saved(player, "PumpkinCrate")).toBe(1)
			end)
			forcing({ Uncommon = 100, Common = 1e-9, Rare = 1e-9 }, function()
				local r = w.open(player, "PumpkinCrate")
				expect(r.Rarity).toBe("Uncommon")
				expect(r.Luck).toBe(1)
				expect(r.LuckAfter).toBe(2)
				expect(w.saved(player, "PumpkinCrate")).toBe(2)
			end)
			forcing({ Rare = 100, Common = 1e-9 }, function()
				local r = w.open(player, "PumpkinCrate")
				expect(r.Rarity).toBe("Rare")
				expect(r.Luck).toBe(2)
				expect(r.LuckAfter).toBe(0)
				expect(w.saved(player, "PumpkinCrate")).toBeNil() -- (0 isn't stored)
			end)
			forcing({ Crazy = 100, Common = 1e-9, Rare = 1e-9 }, function()
				w.setLuck(player, "PumpkinCrate", 6)
				local r = w.open(player, "PumpkinCrate")
				expect(r.Rarity).toBe("Crazy")
				expect(r.LuckAfter).toBe(0)
			end)
			forcing({ Common = 100, Rare = 1e-9 }, function()
				w.setLuck(player, "PumpkinCrate", 13)
				expect(w.open(player, "PumpkinCrate").LuckAfter).toBe(14)
				local r = w.open(player, "PumpkinCrate")
				expect(r.Luck).toBe(14)
				expect(r.LuckAfter).toBe(15)
				expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(15)
				-- Full meter: Rare or better for sure, then empty again.
				local full = w.open(player, "PumpkinCrate")
				expect(full.Luck).toBe(15)
				expect(full.Guaranteed).toBe("Rare")
				expect(CrateOdds.RarityIndex(full.Rarity)).toBeGreaterThanOrEqual(
					CrateOdds.RarityIndex("Rare")
				)
				expect(full.LuckAfter).toBe(0)
				-- Without FullGuarantee the meter just stays full.
				luckCfg.FullGuarantee = false
				w.setLuck(player, "PumpkinCrate", 15)
				local stays = w.open(player, "PumpkinCrate")
				expect(stays.Rarity).toBe("Common")
				expect(stays.Guaranteed).toBeNil()
				expect(stays.LuckAfter).toBe(15)
			end)
			-- Each themed crate has its own meter.
			w.setLuck(player, "PumpkinCrate", 3)
			expect(w.CrateService.Luck(player, "CandyCrate")).toBe(0)
			expect(w.CrateService.Luck(player, "NoSuchCrate")).toBe(0)
		end
	)

	it("S2: the luck shown must be the real one, or nothing is bought", function()
		local player, data = w.join("Shower")
		data.Coins = 10000
		w.setLuck(player, "PumpkinCrate", 3)
		local opened = data.Crates.Opened
		for _, wrong in { { nil }, { "3" }, { 2 }, { 4 }, { 3.5 }, { true } } do
			local r = w.raw(player, "PumpkinCrate", 1, wrong[1])
			expect(r.Ok).toBe(false)
			expect(r.Message).toBe(text.OddsChanged)
			expect(r.Luck).toBe(3) -- the real level, so the page can show it
			expect(r.LuckVersion).toBe(w.ShopService.LuckVersion(player))
			expect(data.Coins).toBe(10000)
			expect(w.saved(player, "PumpkinCrate")).toBe(3)
		end
		-- x1 with a guarantee it doesn't have.
		local g = w.raw(player, "PumpkinCrate", 1, 3, "Rare")
		expect(g.Message).toBe(text.OddsChanged)
		expect(data.Crates.Opened).toBe(opened)
		local ok = w.raw(player, "PumpkinCrate", 1, 3)
		expect(ok.Ok).toBe(true)
		expect(ok.Luck).toBe(3)
		expect(data.Crates.Opened).toBe(opened + 1)
		-- A crate without a meter expects 0 (a missing value is refused too).
		data.Coins = 1000
		expect(w.raw(player, "CommonCrate", 1).Message).toBe(text.OddsChanged)
		expect(w.raw(player, "CommonCrate", 1, 1).Message).toBe(text.OddsChanged)
		local common = w.raw(player, "CommonCrate", 1, 0)
		expect(common.Ok).toBe(true)
		expect(common.Luck).toBeNil()
		-- Not enough coins: that message, with the level (unchanged).
		data.Coins = 0
		local poor = w.open(player, "PumpkinCrate")
		expect(poor.Ok).toBe(false)
		expect(poor.Message).toMatch("more")
		expect(poor.Luck).toBe(w.CrateService.Luck(player, "PumpkinCrate"))
	end)

	it("S3: cleans junk out of a saved luck table and keeps every real level", function()
		local player, data = w.join("Junk")
		local function reads(value: any): number
			data.Crates.Luck = { PumpkinCrate = value }
			return w.CrateService.Luck(player, "PumpkinCrate")
		end
		expect(reads("4")).toBe(0)
		expect(reads(-3)).toBe(0)
		expect(reads(2.5)).toBe(2)
		expect(reads(1e9)).toBe(15)
		expect(reads(0 / 0)).toBe(0)
		expect(reads(math.huge)).toBe(0)
		expect(reads({ 5 })).toBe(0)
		data.Crates.Luck = 5 -- not even a table
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(0)
		w.setLuck(player, "PumpkinCrate", 2)
		expect(data.Crates.Luck).toEqual({ PumpkinCrate = 2 })
		data.Crates = "broken"
		w.setLuck(player, "PumpkinCrate", 1)
		expect(data.Crates.Luck).toEqual({ PumpkinCrate = 1 })
		expect(data.Crates.Opened).toBe(0)
		-- 100 junk keys, junk values and real levels (one of a switched-off theme's crate).
		local offCrate: string? = nil
		local on: { [string]: boolean } = {}
		for _, theme in Config.Skins.Themes do
			on[theme.Id] = true
		end
		for _, theme in Config.Skins.AllThemes do
			if not on[theme.Id] then
				offCrate = theme.Crate
			end
		end
		local luck: { [any]: any } = {}
		for i = 1, 100 do
			luck["Junk" .. i] = 3
		end
		luck[1] = 4
		luck[string.rep("x", 70)] = 4
		luck.Zero = 0
		luck.Bad = "7"
		luck.Nested = { 1 }
		luck.PumpkinCrate = 3
		luck.CandyCrate = 2
		if offCrate then
			luck[offCrate] = 5
		end
		data.Crates.Luck = luck
		w.setLuck(player, "PumpkinCrate", 4)
		local saved = data.Crates.Luck
		local count = 0
		for key, value in saved do
			count += 1
			expect(key).toBeA("string")
			expect(#key).toBeLessThanOrEqual(64)
			expect(value >= 1 and value <= 15 and value % 1 == 0).toBe(true)
		end
		expect(count).toBe(64)
		expect(saved.PumpkinCrate).toBe(4)
		expect(saved.CandyCrate).toBe(2)
		expect(saved.Zero).toBeNil()
		expect(saved.Bad).toBeNil()
		if offCrate then
			expect(saved[offCrate]).toBe(5) -- kept for when the theme comes back
			T.note("kept the switched-off " .. offCrate)
		end
		-- The client only ever sees real, available crates with a meter (no 0s, no junk).
		local state = w.ShopService.State(player)
		expect(state.CrateLuck).toEqual({ PumpkinCrate = 4, CandyCrate = 2 })
	end)

	it("S4: rarity and Deluxe crates never touch luck; switches never erase it", function()
		local player, data = w.join("Plain")
		data.Coins = 100000
		w.setLuck(player, "PumpkinCrate", 4)
		local before = table.clone(data.Crates.Luck)
		for _, id in { "RareCrate", "PumpkinDeluxeCrate", "CommonCrate" } do
			local r = w.open(player, id)
			expect(r.Ok).toBe(true)
			expect(r.Luck).toBeNil()
			expect(r.LuckAfter).toBeNil()
		end
		expect(data.Crates.Luck).toEqual(before)
		-- CrateLuck off: plain odds, 0 expected, and the saved 7 survives an open.
		w.setLuck(player, "PumpkinCrate", 7)
		try(function()
			Config.Features.CrateLuck = false
			expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(0)
			expect(w.open(player, "PumpkinCrate", 1, 7).Message).toBe(text.OddsChanged)
			local r = w.open(player, "PumpkinCrate", 1, 0)
			expect(r.Ok).toBe(true)
			expect(r.Luck).toBeNil()
			expect(r.Guaranteed).toBeNil()
			expect(w.saved(player, "PumpkinCrate")).toBe(7)
			expect(w.ShopService.State(player).CrateLuck).toEqual({})
		end, function()
			Config.Features.CrateLuck = true
		end)
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(7)
		-- A theme's Rares hidden: no meter, and its level stays where it was.
		local items = Config.Shop.Items
		local removed = {}
		for i = #items, 1, -1 do
			if items[i].Crate == "PumpkinCrate" and items[i].Rarity == "Rare" then
				table.insert(removed, { i, items[i] })
				table.remove(items, i)
			end
		end
		try(function()
			expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(0)
			local r = w.open(player, "PumpkinCrate", 1, 0)
			expect(r.Ok).toBe(true)
			expect(w.saved(player, "PumpkinCrate")).toBe(7)
		end, function()
			for i = #removed, 1, -1 do
				table.insert(items, removed[i][1], removed[i][2])
			end
		end)
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(7)
	end)

	it(
		"S5: restricted players can't open or prepare; Deluxe crates go with PremiumCrates",
		function()
			local kid, kidData = w.join("RestrictedKid")
			kidData.Coins = 100000
			expect(w.open(kid, "PumpkinCrate").Message).toBe(text.Restricted)
			local crate = CrateOdds.Get("PumpkinCrate")
			local productId = crate.Robux.ProductId
			expect(productId).never.toBe(0)
			local prep = w.prepare(kid, "PumpkinCrate")
			expect(prep.Ok).toBe(false)
			expect(prep.Message).toBe(text.Restricted)
			expect(kidData.Coins).toBe(100000)

			local player, data = w.join("DeluxeFan")
			data.Coins = 100000
			local deluxe = nil
			for _, c in Config.Crates.List do
				if c.Id == "PumpkinDeluxeCrate" then
					deluxe = c
				end
			end
			try(function()
				Config.Features.PremiumCrates = false
				for _, c in CrateOdds.List() do
					expect(c.Base).toBeNil()
				end
				local r = w.open(player, "PumpkinDeluxeCrate", 1, 0)
				expect(r.Ok).toBe(false)
				expect(r.Message).toBe(text.NoCrate)
				-- A Deluxe receipt pays its coins (a product made later, while switched off).
				deluxe.Robux.ProductId = 4343
				local coins, opened = data.Coins, data.Crates.Opened
				expect(w.receipt(player, 4343, "deluxe-off").Name).toBe("PurchaseGranted")
				expect(data.Coins).toBe(coins + 2000)
				expect(data.Crates.Opened).toBe(opened)
				local results = w.results(player)
				expect(results[#results].Ok).toBe(false)
				expect(results[#results].Message).toMatch("2000")
			end, function()
				Config.Features.PremiumCrates = true
				deluxe.Robux.ProductId = 0
			end)
			local open = w.open(player, "PumpkinDeluxeCrate")
			expect(open.Ok).toBe(true)
			expect(w.Items.Get(open.ItemId).Crate).toBe("PumpkinCrate")
			expect(open.Rarity).never.toBe("Common")
		end
	)

	it("S6: packs open crate by crate, and the guarantee always holds", function()
		local player, data = w.join("Packer")
		data.Coins = 10000000
		local function checkPacks(count: number, guarantee: string, odds: { [string]: number })
			forcing(odds, function()
				local guaranteedLast = 0
				for _ = 1, 200 do
					w.setLuck(player, "PumpkinCrate", 0) -- (so the meter can't fill inside the pack)
					local batch = w.open(player, "PumpkinCrate", count)
					expect(batch.Ok).toBe(true)
					local results = batch.Results
					expect(#results).toBe(count)
					local metBefore = false
					local best = 1
					for k, r in results do
						local index = CrateOdds.RarityIndex(r.Rarity)
						best = math.max(best, index)
						if k < count then
							expect(r.Guaranteed).toBeNil()
							if index >= CrateOdds.RarityIndex(guarantee) then
								metBefore = true
							end
						end
					end
					-- At least one of the guaranteed rarity or better, every time.
					expect(best).toBeGreaterThanOrEqual(CrateOdds.RarityIndex(guarantee))
					-- The last one is guaranteed exactly when the others missed.
					expect(results[count].Guaranteed == guarantee).toBe(not metBefore)
					if not metBefore then
						guaranteedLast += 1
						expect(results[count].Luck).toBe(CrateLuck.PackLevel(pumpkin, 0, count))
					end
				end
				T.note(("x%d: %d of 200 packs needed the guarantee"):format(count, guaranteedLast))
				expect(guaranteedLast).toBeGreaterThan(150)
			end)
		end
		checkPacks(10, "Rare", { Common = 99.98, Rare = 0.02 })
		checkPacks(5, "Uncommon", { Common = 99.98, Uncommon = 0.01, Rare = 0.01 })

		-- Normal odds: each crate starts where the one before left the meter.
		for _ = 1, 30 do
			local start = w.CrateService.Luck(player, "PumpkinCrate")
			local coins = data.Coins
			local batch = w.open(player, "PumpkinCrate", 10)
			local level = start
			local refunds = 0
			for _, r in batch.Results do
				expect(r.Luck).toBe(level)
				expect(r.LuckAfter).toBe(CrateLuck.After(pumpkin, level, r.Rarity))
				level = r.LuckAfter
				refunds += r.Refund or 0
			end
			expect(batch.LuckAfter).toBe(batch.Results[10].LuckAfter)
			expect(batch.LuckVersion).toBe(w.ShopService.LuckVersion(player))
			expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(level)
			expect(data.Coins).toBe(coins - 6000 + refunds) -- one payment
		end

		-- The guarantee the window showed must be the server's.
		local coins = data.Coins
		local level = w.CrateService.Luck(player, "PumpkinCrate")
		for _, wrong in { { nil }, { "Uncommon" }, { "Crazy" }, { 5 } } do
			local r = w.raw(player, "PumpkinCrate", 10, level, wrong[1])
			expect(r.Ok).toBe(false)
			expect(r.Message).toBe(text.OddsChanged)
			expect(data.Coins).toBe(coins)
		end
		-- CratePacks off: no guarantee, and none may be sent.
		try(function()
			Config.Features.CratePacks = false
			expect(w.open(player, "PumpkinCrate", 10, nil, "Rare").Message).toBe(text.OddsChanged)
			w.setLuck(player, "PumpkinCrate", 0)
			for _ = 1, 10 do
				local batch = w.open(player, "PumpkinCrate", 10)
				expect(batch.Ok).toBe(true)
				for _, r in batch.Results do
					expect(r.Guaranteed).toBeNil()
				end
				w.setLuck(player, "PumpkinCrate", 0)
			end
		end, function()
			Config.Features.CratePacks = true
		end)
	end)

	it("S7: every luck change raises LuckVersion, and nothing older ever wins", function()
		local player, data = w.join("Versions")
		data.Coins = 100000
		local v0 = w.ShopService.LuckVersion(player)
		expect(w.ShopService.State(player).LuckVersion).toBe(v0)
		local r = w.open(player, "PumpkinCrate")
		expect(r.LuckVersion).toBeGreaterThan(v0)
		local states = w.states(player)
		local last = states[#states]
		expect(last.LuckVersion).toBe(r.LuckVersion)
		expect(last.CrateLuck.PumpkinCrate).toBe(if r.LuckAfter > 0 then r.LuckAfter else nil)
		-- A crate without a meter: no change, the same version.
		local plain = w.open(player, "CommonCrate")
		expect(plain.LuckVersion).toBe(r.LuckVersion)
		-- Refusals carry the current version.
		local refused = w.open(player, "PumpkinCrate", 1, 99)
		expect(refused.Ok).toBe(false)
		expect(refused.LuckVersion).toBe(w.ShopService.LuckVersion(player))
		expect(w.raw(player, "NoSuchCrate", 1, 0).LuckVersion).toBe(
			w.ShopService.LuckVersion(player)
		)
		-- A pack raises it once per crate.
		local before = w.ShopService.LuckVersion(player)
		local batch = w.open(player, "PumpkinCrate", 5)
		expect(batch.LuckVersion).toBe(before + 5)
		for k, one in batch.Results do
			expect(one.LuckVersion).toBe(before + k)
		end
		-- GetShopState right after an open (inside its cache time) has the new level: Push
		-- refreshed the cache.
		local getState = w.rt:find("ReplicatedStorage.Remotes.GetShopState")
		w.rt:advance(Config.Crates.RequestCooldown + 0.1)
		local cached = w.rt:invokeServer(getState, player)
		local open = w.rt:invokeServer(
			w.rt:find("ReplicatedStorage.Remotes.OpenCrate"),
			player,
			"PumpkinCrate",
			1,
			cached.CrateLuck.PumpkinCrate or 0
		)
		expect(open.Ok).toBe(true)
		local now = w.rt:invokeServer(getState, player)
		expect(now.LuckVersion).toBe(open.LuckVersion)
		expect(now.CrateLuck.PumpkinCrate or 0).toBe(open.LuckAfter)
	end)

	it(
		"S8: the server rolls with exactly the chances the crate page shows (every level, packs)",
		function()
			local player, data = w.join("Honest")
			data.Coins = 10000000
			-- The client's own copy of the shared modules (as the crate page computes them).
			local client = Runtime.new({ client = true })
			client:replicateFrom(w.rt)
			local CConfig = client:require("ReplicatedStorage.Shared.Config")
			for name, value in Config.Features do
				CConfig.Features[name] = value
			end
			local CCrateOdds = client:require("ReplicatedStorage.Shared.CrateOdds")
			local CCrateLuck = client:require("ReplicatedStorage.Shared.CrateLuck")
			-- Record the chances each crate is really rolled with (not the reel's picks).
			local rolled: { { any } } = {}
			local inReel = false
			local pick, reel = CrateOdds.Pick, CrateOdds.Reel
			CrateOdds.Reel = function(...)
				inReel = true
				local out = reel(...)
				inReel = false
				return out
			end
			CrateOdds.Pick = function(chances, roll)
				if not inReel then
					table.insert(rolled, chances)
				end
				return pick(chances, roll)
			end
			local function same(serverChances: { any }, clientChances: { any }, what: string)
				if #serverChances ~= #clientChances then
					error(
						("%s: %d chances rolled, %d shown"):format(
							what,
							#serverChances,
							#clientChances
						)
					)
				end
				for i, c in serverChances do
					local shown = clientChances[i]
					if c.Item.Id ~= shown.Item.Id or c.Chance ~= shown.Chance then
						error(
							("%s: rolled %s at %s, shown %s at %s"):format(
								what,
								c.Item.Id,
								tostring(c.Chance),
								shown.Item.Id,
								tostring(shown.Chance)
							)
						)
					end
				end
			end
			-- What the page shows: every skin that isn't 0%.
			local function page(crateId: string, level: number, atLeast: string?): { any }
				local crate = CCrateOdds.Get(crateId)
				local out = {}
				for _, c in CCrateOdds.Shown(crate, CCrateLuck.Boost(crate, level, atLeast)) do
					if c.Chance > 0 then
						table.insert(out, c)
					end
				end
				return out
			end
			try(function()
				for _, crateId in { "PumpkinCrate", "VampireCastleCrate", "ZombieTownCrate" } do
					if CrateOdds.Get(crateId) then
						for level = 0, CrateLuck.Steps() do
							w.setLuck(player, crateId, level)
							table.clear(rolled)
							local r = w.open(player, crateId, 1, level)
							expect(r.Ok).toBe(true)
							expect(#rolled).toBe(1)
							same(
								rolled[1],
								page(crateId, level, nil),
								("%s luck %d"):format(crateId, level)
							)
						end
					end
				end
				-- Packs from every starting level: each crate uses its own level, the last one the
				-- guarantee the pack window shows (at PackLevel) when the others missed it.
				for _, count in { 5, 10 } do
					for start = 0, CrateLuck.Steps() do
						w.setLuck(player, "PumpkinCrate", start)
						table.clear(rolled)
						local batch = w.open(player, "PumpkinCrate", count)
						expect(#rolled).toBe(count)
						local g = CCrateLuck.Guarantee(CCrateOdds.Get("PumpkinCrate"), count)
						local met = false
						for k, r in batch.Results do
							local atLeast = if k == count and not met then g else nil
							if atLeast then
								expect(r.Luck).toBe(
									CCrateLuck.PackLevel(
										CCrateOdds.Get("PumpkinCrate"),
										start,
										count
									)
								)
							end
							same(
								rolled[k],
								page("PumpkinCrate", r.Luck, atLeast),
								("x%d from %d, crate %d"):format(count, start, k)
							)
							if CrateOdds.RarityIndex(r.Rarity) >= CrateOdds.RarityIndex(g) then
								met = true
							end
						end
					end
				end
				-- Deluxe and rarity crates: the page's plain chances.
				for _, crateId in { "PumpkinDeluxeCrate", "RareCrate" } do
					table.clear(rolled)
					w.open(player, crateId)
					same(rolled[1], page(crateId, 0, nil), crateId)
				end
			end, function()
				CrateOdds.Pick = pick
				CrateOdds.Reel = reel
			end)
		end
	)
end)

describe("Crate luck: F8 commands (S4)", function()
	it("adds, quietly adds and resets luck, in Studio only", function()
		local w = serverWorld({ studio = true })
		local player, data = w.join("Owner")
		local list =
			w.rt:invokeServer(w.rt:find("ReplicatedStorage.Remotes.GetAdminCommands"), player)
		local labels = {}
		for _, info in list do
			labels[info.Name] = info.Label
		end
		expect(labels.CrateLuckUp).toBe("Crates: +5 luck on Pumpkin Crate")
		expect(labels.CrateLuckQuiet).toBe(
			"Crates: +1 luck on Pumpkin Crate, screen not told (tests the odds check)"
		)
		expect(labels.CrateLuckReset).toBe("Crates: reset my luck")
		local run = w.rt:find("ReplicatedStorage.Remotes.AdminCommand")
		local function command(name: string): (boolean, string)
			w.rt:advance(1)
			return w.rt:invokeServer(run, player, name)
		end
		local pushes = #w.states(player)
		local v0 = w.ShopService.LuckVersion(player)
		local ok, message = command("CrateLuckUp")
		expect(ok).toBe(true)
		expect(message).toBe("Pumpkin Crate luck: 5 / 15")
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(5)
		expect(#w.states(player)).toBe(pushes + 1)
		expect(w.ShopService.LuckVersion(player)).toBe(v0 + 1)
		-- Quiet: the level changes but the screen isn't told (the odds check test).
		ok, message = command("CrateLuckQuiet")
		expect(message).toBe("Pumpkin Crate luck: 6 / 15")
		expect(#w.states(player)).toBe(pushes + 1)
		expect(w.ShopService.LuckVersion(player)).toBe(v0 + 2)
		local refused = w.open(player, "PumpkinCrate", 1, 5)
		expect(refused.Message).toBe(w.Config.Crates.Text.OddsChanged)
		expect(refused.Luck).toBe(6)
		command("CrateLuckUp")
		command("CrateLuckUp")
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(15) -- (never past Steps)
		ok, message = command("CrateLuckReset")
		expect(ok).toBe(true)
		expect(data.Crates.Luck).toEqual({})
		expect(#w.states(player)).toBe(pushes + 4)
		-- F8 Reset my save empties it too, with a newer version for the screen.
		w.setLuck(player, "PumpkinCrate", 3)
		local before = w.ShopService.LuckVersion(player)
		command("ResetSave")
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(0)
		expect(w.ShopService.LuckVersion(player)).toBeGreaterThan(before)
		local states = w.states(player)
		expect(states[#states].LuckVersion).toBe(w.ShopService.LuckVersion(player))
		expect(states[#states].CrateLuck).toEqual({})
	end)

	it("doesn't add the luck buttons outside Studio, or with CrateLuck off", function()
		local live = serverWorld()
		local player = live.join("LiveOwner")
		player:SetAttribute("Admin", true) -- (an admin in a live server: Config.Admin.UserIds)
		local list =
			live.rt:invokeServer(live.rt:find("ReplicatedStorage.Remotes.GetAdminCommands"), player)
		local names = {}
		for _, info in list do
			names[info.Name] = true
		end
		expect(names.CrateFree).toBe(true)
		expect(names.CrateLuckUp).toBeNil()
		expect(names.CrateLuckQuiet).toBeNil()
		expect(names.CrateLuckReset).toBeNil()

		local server = Runtime.new({ studio = true })
		local Config = server:require("ReplicatedStorage.Shared.Config")
		Config.Features.Crates = true
		Config.Features.CrateLuck = false
		local services = "ServerScriptService.Server.Services."
		server:require(services .. "DataService").Start()
		server:require(services .. "ShopService").Start()
		server:require(services .. "CrateService").Start()
		local AdminService = server:require(services .. "AdminService")
		AdminService.Start()
		local owner = server:addPlayer({ Name = "Owner" })
		server:advance(3)
		local off =
			server:invokeServer(server:find("ReplicatedStorage.Remotes.GetAdminCommands"), owner)
		for _, info in off do
			expect(info.Name:sub(1, 9)).never.toBe("CrateLuck")
		end
	end)
end)

describe("Crate luck: Robux opens (R1-R4)", function()
	local w = serverWorld()
	local Config = w.Config
	local CrateOdds, CrateLuck = w.CrateOdds, w.CrateLuck
	local text = Config.Crates.Text
	local hold = Config.Crates.RobuxOpen
	local pumpkin = CrateOdds.Get("PumpkinCrate")
	local productId = 7001
	pumpkin.Robux.ProductId = productId
	local nextReceipt = 0
	local function receiptId(): string
		nextReceipt += 1
		return "r" .. nextReceipt
	end
	-- Is a coin open of the Pumpkin Crate refused because a Robux purchase of it is on its way?
	-- (Asked with 0 coins, so it never buys anything: the hold is checked before the price.)
	local function held(player: any): boolean
		local data = w.DataService.Get(player)
		local coins = data.Coins
		data.Coins = 0
		local r = w.open(player, "PumpkinCrate")
		data.Coins = coins
		return r.Ok == false and r.Message == text.RobuxFirst
	end

	it("R1: PrepareCrateRobux checks the luck shown, then holds only that crate", function()
		local player, data = w.join("RobuxKid")
		data.Coins = 1000000
		w.setLuck(player, "PumpkinCrate", 2)
		-- Stale luck: refused, with the real level.
		local stale = w.prepare(player, "PumpkinCrate", 1)
		expect(stale.Ok).toBe(false)
		expect(stale.Message).toBe(text.OddsChanged)
		expect(stale.Luck).toBe(2)
		expect(stale.LuckVersion).toBe(w.ShopService.LuckVersion(player))
		expect(held(player)).toBe(false) -- (no hold from a refusal)
		-- A crate with no product, junk, and Robux crates off.
		expect(w.prepare(player, "PumpkinDeluxeCrate", 0).Message).toBe(text.NoCrate) -- (ProductId 0)
		expect(w.prepare(player, "NoSuchCrate", 0).Message).toBe(text.NoCrate)
		expect(
			w.rt:invokeServer(
				w.rt:find("ReplicatedStorage.Remotes.PrepareCrateRobux"),
				player,
				42,
				0
			).Ok
		).toBe(false)
		try(function()
			Config.Features.RobuxCrates = false
			expect(w.prepare(player, "PumpkinCrate").Message).toBe(text.Closed)
		end, function()
			Config.Features.RobuxCrates = true
		end)
		-- Success: it answers with the level, and holds the Pumpkin Crate (only).
		w.rt:advance(2)
		local ok = w.prepare(player, "PumpkinCrate")
		expect(ok.Ok).toBe(true)
		expect(ok.Luck).toBe(2)
		expect(ok.CrateId).toBe("PumpkinCrate")
		-- R$ pressed again at once: its own cooldown...
		local fast = w.rt:invokeServer(
			w.rt:find("ReplicatedStorage.Remotes.PrepareCrateRobux"),
			player,
			"PumpkinCrate",
			2
		)
		expect(fast.Message).toBe(text.SlowDown)
		-- ...which isn't OpenCrate's: a coin open straight after it isn't "Slow down!".
		local candy = w.rt:invokeServer(
			w.rt:find("ReplicatedStorage.Remotes.OpenCrate"),
			player,
			"CandyCrate",
			1,
			0
		)
		expect(candy.Ok).toBe(true)
		expect(held(player)).toBe(true)
		-- Pressing R$ again (not bought yet) just renews the hold.
		expect(w.prepare(player, "PumpkinCrate").Ok).toBe(true)
		expect(held(player)).toBe(true)
		-- Cancelled: free again at once.
		w.finished(player, productId, false)
		expect(held(player)).toBe(false)
		-- The window left open: the hold ends after HoldSeconds.
		w.prepare(player, "PumpkinCrate")
		expect(held(player)).toBe(true)
		w.rt:advance(hold.HoldSeconds + 1)
		expect(held(player)).toBe(false)
		-- Bought: it waits for the receipt, past HoldSeconds...
		w.prepare(player, "PumpkinCrate")
		w.finished(player, productId, true)
		w.rt:advance(hold.HoldSeconds + 5)
		expect(held(player)).toBe(true)
		-- ...and no second purchase window meanwhile.
		local again = w.prepare(player, "PumpkinCrate")
		expect(again.Ok).toBe(false)
		expect(again.Message).toBe(text.RobuxFirst)
		-- The receipt arrives: rolled, and the hold ends.
		local level = w.CrateService.Luck(player, "PumpkinCrate")
		expect(w.receipt(player, productId, receiptId()).Name).toBe("PurchaseGranted")
		local sent = w.results(player)
		expect(sent[#sent].Ok).toBe(true)
		expect(sent[#sent].Luck).toBe(level)
		expect(held(player)).toBe(false)
		-- Bought but the receipt never comes (in this session): at most MaxHoldSeconds.
		w.prepare(player, "PumpkinCrate")
		w.finished(player, productId, true)
		w.rt:advance(hold.MaxHoldSeconds - 10)
		expect(held(player)).toBe(true)
		w.rt:advance(15)
		expect(held(player)).toBe(false)
		-- A finished event with no window opened here does nothing.
		w.finished(player, productId, true)
		expect(held(player)).toBe(false)
	end)

	it("R2: a Robux crate rolls at the saved level; a failed save puts it back exactly", function()
		local player, data = w.join("RobuxSaver")
		data.Coins = 100000
		w.setLuck(player, "PumpkinCrate", 5)
		local v0 = w.ShopService.LuckVersion(player)
		expect(w.receipt(player, productId, "save-ok").Name).toBe("PurchaseGranted")
		local sent = w.results(player)
		local first = sent[#sent]
		expect(first.Ok).toBe(true)
		expect(first.Paid).toBe("Robux")
		expect(first.Luck).toBe(5)
		expect(first.LuckAfter).toBe(CrateLuck.After(pumpkin, 5, first.Rarity))
		expect(first.LuckVersion).toBeGreaterThan(v0)
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(first.LuckAfter)

		-- The save fails: everything (luck too) goes back, the hold ends, the player is told.
		w.setLuck(player, "PumpkinCrate", 4)
		w.prepare(player, "PumpkinCrate")
		w.finished(player, productId, true)
		local opened = data.Crates.Opened
		local owned = table.clone(data.Owned)
		w.rt.dataStoreFailures = 4 -- every save attempt fails
		local decision = w.receipt(player, productId, "save-fails")
		w.rt.dataStoreFailures = 0
		expect(decision.Name).toBe("NotProcessedYet")
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(4)
		expect(data.Crates.Opened).toBe(opened)
		expect(data.Owned).toEqual(owned)
		sent = w.results(player)
		local later = sent[#sent]
		expect(later.Ok).toBe(false)
		expect(later.Message).toBe(text.RobuxLater)
		expect(later.Paid).toBe("Robux")
		expect(later.CrateId).toBe("PumpkinCrate")
		expect(later.Luck).toBe(4)
		expect(held(player)).toBe(false) -- (the hold ended)

		-- Roblox retries: rolled at that same level, counted once, the normal result.
		expect(w.receipt(player, productId, "save-fails").Name).toBe("PurchaseGranted")
		sent = w.results(player)
		expect(sent[#sent].Ok).toBe(true)
		expect(sent[#sent].Luck).toBe(4)
		expect(data.Crates.Opened).toBe(opened + 1)
		local after = w.CrateService.Luck(player, "PumpkinCrate")
		local count = #sent
		expect(w.receipt(player, productId, "save-fails").Name).toBe("PurchaseGranted")
		expect(data.Crates.Opened).toBe(opened + 1)
		expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(after)
		expect(#w.results(player)).toBe(count) -- (nothing new to play)
	end)

	it("R3: a restricted buyer gets coins and an unchanged meter", function()
		local player, data = w.join("RestrictedBuyer")
		w.setLuck(player, "PumpkinCrate", 3)
		local coins = data.Coins
		expect(w.receipt(player, productId, receiptId()).Name).toBe("PurchaseGranted")
		expect(data.Coins).toBe(coins + 600)
		expect(w.saved(player, "PumpkinCrate")).toBe(3)
		local sent = w.results(player)
		expect(sent[#sent].Ok).toBe(false)
		expect(sent[#sent].Message).toBe(text.RobuxInstead:format(600, Config.Economy.CurrencyName))
	end)

	it("R4: every way out of a receipt ends the hold", function()
		local player, data = w.join("Bookkeeper")
		data.Coins = 1000000
		local DataService = w.DataService
		local function boughtThen(fn: () -> ())
			w.prepare(player, "PumpkinCrate")
			w.finished(player, productId, true)
			expect(held(player)).toBe(true)
			fn()
			expect(held(player)).toBe(false)
		end
		-- The save never loaded.
		boughtThen(function()
			local waitForLoad = DataService.WaitForLoad
			DataService.WaitForLoad = function()
				return false
			end
			local decision = w.receipt(player, productId, receiptId())
			DataService.WaitForLoad = waitForLoad
			expect(decision.Name).toBe("NotProcessedYet")
			local sent = w.results(player)
			expect(sent[#sent].Message).toBe(text.RobuxLater)
		end)
		-- No data.
		boughtThen(function()
			local get = DataService.Get
			local calls = 0
			DataService.Get = function(p)
				calls += 1
				if calls == 1 then
					return nil
				end
				return get(p)
			end
			local decision = w.receipt(player, productId, receiptId())
			DataService.Get = get
			expect(decision.Name).toBe("NotProcessedYet")
		end)
		-- Already granted earlier.
		local done = receiptId()
		table.insert(data.Receipts, done)
		boughtThen(function()
			local opened = data.Crates.Opened
			expect(w.receipt(player, productId, done).Name).toBe("PurchaseGranted")
			expect(data.Crates.Opened).toBe(opened)
		end)
		-- The handler errors.
		boughtThen(function()
			local get = DataService.Get
			local thrown = false
			DataService.Get = function(p)
				if not thrown then
					thrown = true
					error("test: Get failed")
				end
				return get(p)
			end
			local decision = w.receipt(player, productId, receiptId())
			DataService.Get = get
			expect(decision.Name).toBe("NotProcessedYet")
			local sent = w.results(player)
			expect(sent[#sent].Message).toBe(text.RobuxLater)
		end)
	end)

	it(
		"R4: two receipts of one crate keep their own holds and take turns (no luck drift)",
		function()
			local player, data = w.join("TwoReceipts")
			data.Coins = 1000000
			local callback =
				Dom.callback(w.rt.game:GetService("MarketplaceService"), "ProcessReceipt")
			local function start(id: string): { any }
				local box = {}
				w.rt.env.task.spawn(function()
					box.Decision = callback({
						PlayerId = player.UserId,
						ProductId = productId,
						PurchaseId = id,
						CurrencySpent = 0,
					})
				end)
				return box
			end
			w.setLuck(player, "PumpkinCrate", 0)
			local opened = data.Crates.Opened
			local before = #w.results(player)
			-- A's save keeps failing for a while; B arrives meanwhile and waits for its turn.
			w.rt.dataStoreFailures = 100
			local a = start("turn-a")
			w.rt:advance(1)
			local b = start("turn-b")
			w.rt:advance(1)
			expect(a.Decision).toBeNil()
			expect(b.Decision).toBeNil()
			expect(held(player)).toBe(true)
			-- A rolled once (and is saving); B hasn't rolled yet: it waits for A.
			expect(data.Crates.Opened).toBe(opened + 1)
			w.rt:advance(16) -- (past A's last save attempt)
			w.rt.dataStoreFailures = 0
			w.rt:advance(20)
			expect(a.Decision.Name).toBe("NotProcessedYet") -- A failed and was undone...
			expect(b.Decision.Name).toBe("PurchaseGranted") -- ...then B rolled from the same level
			expect(held(player)).toBe(false)
			local sent = w.results(player)
			local mine = {}
			for i = before + 1, #sent do
				table.insert(mine, sent[i])
			end
			expect(#mine).toBe(2)
			expect(mine[1].Message).toBe(text.RobuxLater) -- A first,
			expect(mine[2].Ok).toBe(true) -- then B
			expect(mine[2].Luck).toBe(0) -- (A's undo put the level back before B rolled)
			expect(w.CrateService.Luck(player, "PumpkinCrate")).toBe(mine[2].LuckAfter)
			expect(data.Crates.Opened).toBe(opened + 1)
			-- Both retried: A is granted once, B isn't granted twice.
			expect(w.receipt(player, productId, "turn-a").Name).toBe("PurchaseGranted")
			expect(w.receipt(player, productId, "turn-a").Name).toBe("PurchaseGranted")
			expect(w.receipt(player, productId, "turn-b").Name).toBe("PurchaseGranted")
			expect(data.Crates.Opened).toBe(opened + 2)

			-- Two receipts at once: the first finishing doesn't end the second's hold (a counter).
			w.rt.dataStoreFailures = 100
			local c = start("turn-c")
			w.rt:advance(1)
			local d = start("turn-d")
			w.rt:advance(29.5) -- C has failed by now; D has its turn and is saving
			expect(c.Decision.Name).toBe("NotProcessedYet")
			expect(d.Decision).toBeNil()
			expect(held(player)).toBe(true)
			w.rt.dataStoreFailures = 0
			w.rt:advance(10)
			expect(d.Decision.Name).toBe("PurchaseGranted")
			expect(held(player)).toBe(false)
			expect(w.receipt(player, productId, "turn-c").Name).toBe("PurchaseGranted")
			expect(data.Crates.Opened).toBe(opened + 4)
		end
	)

	it("R5: while a receipt is handled, the crates with the same skins wait too", function()
		local player, data = w.join("SameSkins")
		data.Coins = 1000000
		local callback = Dom.callback(w.rt.game:GetService("MarketplaceService"), "ProcessReceipt")
		-- A receipt (retried on join: no purchase window, so no screen is busy) whose save
		-- keeps failing for a while: it has given its skin and is retrying the save.
		local box = {}
		local owned = table.clone(data.Owned)
		w.rt.dataStoreFailures = 100
		w.rt.env.task.spawn(function()
			box.Decision = callback({
				PlayerId = player.UserId,
				ProductId = productId,
				PurchaseId = "same-skins",
				CurrencySpent = 0,
			})
		end)
		w.rt:advance(1)
		expect(box.Decision).toBeNil()
		-- Its Deluxe crate and the rarity crates can roll that same skin: if one counted it as
		-- a duplicate now, the failed save's undo would take it away anyway. They wait.
		for _, id in { "PumpkinDeluxeCrate", "CommonCrate", "UncommonCrate", "RareCrate" } do
			local r = w.open(player, id)
			expect(r.Ok).toBe(false)
			expect(r.Message).toBe(text.RobuxFirst)
		end
		-- A crate with other skins opens as normal.
		expect(w.open(player, "CandyCrate").Ok).toBe(true)
		w.rt:advance(40)
		w.rt.dataStoreFailures = 0
		expect(box.Decision.Name).toBe("NotProcessedYet") -- undone: Roblox asks again later
		for id in data.Owned do
			if not owned[id] then
				expect(w.Items.Get(id).Crate).toBe("CandyCrate") -- (only the Candy skin stayed)
			end
		end
		-- Handled (here: given up for now): they open again.
		expect(w.open(player, "PumpkinDeluxeCrate").Ok).toBe(true)
		expect(w.open(player, "RareCrate").Ok).toBe(true)
	end)
end)

describe("Crate luck: today's crate page against the real server (C8)", function()
	local w = serverWorld()
	local player, data = w.join("PageUser")
	data.Coins = 1000000
	local client = Runtime.new({ client = true })
	client:replicateFrom(w.rt)
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	for name, value in w.Config.Features do
		CConfig.Features[name] = value
	end
	local CCrateOdds = client:require("ReplicatedStorage.Shared.CrateOdds")
	local CCrateLuck = client:require("ReplicatedStorage.Shared.CrateLuck")
	local CrateUI = client:require("StarterPlayer.StarterPlayerScripts.Client.CrateUI")
	local me = client.game:GetService("Players").LocalPlayer
	me:SetAttribute("CratesRestricted", false)
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me.PlayerGui)
	local text = CConfig.Crates.Text

	-- The network: a copy of each value, like Roblox sends.
	local function copy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = copy(v)
		end
		return out
	end
	-- Passes the server's ShopState / CrateResult events for this player on to the client.
	local replayed = 0
	local function replay()
		local calls = w.rt:calls("RemoteEvent", "FireClient")
		for i = replayed + 1, #calls do
			local call = calls[i]
			if call.args[1] == player then
				local remote = client:find("ReplicatedStorage.Remotes." .. call.instance.Name)
				client:fire(remote, "OnClientEvent", copy(call.args[2]))
			end
		end
		replayed = #calls
	end
	local pushFirst = true -- the real order: a grant's ShopState arrives before its answer
	for _, name in { "OpenCrate", "PrepareCrateRobux", "GetShopState", "EquipItem" } do
		local serverRemote = w.rt:find("ReplicatedStorage.Remotes." .. name)
		client:find("ReplicatedStorage.Remotes." .. name).OnServerInvoke = function(_p, ...)
			local out = table.pack(w.rt:invokeServer(serverRemote, player, ...))
			if pushFirst then
				replay()
			end
			return table.unpack(copy(out), 1, out.n)
		end
	end
	replayed = #w.rt:calls("RemoteEvent", "FireClient")
	CrateUI.Mount(gui)
	client:advance(1)
	local panel = gui:FindFirstChild("Crates")
	local saw: { string } = {}
	panel.Message:GetPropertyChangedSignal("Text"):Connect(function()
		table.insert(saw, panel.Message.Text)
	end)
	local function sawOddsChanged(): boolean
		for _, t in saw do
			if t == text.OddsChanged then
				return true
			end
		end
		return false
	end
	-- The chance the page shows for a Pumpkin Common, and what it should be at `level`.
	local function shownSpice(): string
		return panel.Body.Preview.Items.Pumpkin_PumpkinSpice.Chance.Text
	end
	local function spiceAt(level: number): string
		local pumpkin = CCrateOdds.Get("PumpkinCrate")
		for _, c in CCrateOdds.Shown(pumpkin, CCrateLuck.Boost(pumpkin, level)) do
			if c.Item.Id == "Pumpkin_PumpkinSpice" then
				return CCrateOdds.Format(c.Chance)
			end
		end
		error("no Pumpkin Spice")
	end
	local function serverLevel(): number
		return w.CrateService.Luck(player, "PumpkinCrate")
	end

	it("opens x1 and x10 with the luck it shows, never saying 'your chances changed'", function()
		w.setLuck(player, "PumpkinCrate", 4)
		w.ShopService.LuckChanged(player)
		w.ShopService.Push(player)
		replay()
		CrateUI.Open("PumpkinCrate")
		client:advance(0.2)
		expect(shownSpice()).toBe(spiceAt(4)) -- the boosted chances, before buying
		expect(shownSpice()).toBe("4.415%")
		table.clear(saw)
		local coins = data.Coins
		client:fire(panel.Body.Preview.Side.Buy.OpenCoins, "Activated")
		client:advance(6)
		expect(data.Coins).toBeLessThan(coins) -- bought
		expect(panel.Body.Opening.Reveal.Visible).toBe(true)
		expect(sawOddsChanged()).toBe(false)
		-- "Open again": back to the page, with the new level (never buys by itself).
		coins = data.Coins
		client:fire(panel.Body.Opening.Reveal.Card.Buttons.OpenAnother, "Activated")
		client:advance(0.2)
		expect(panel.Body.Preview.Visible).toBe(true)
		expect(data.Coins).toBe(coins)
		expect(shownSpice()).toBe(spiceAt(serverLevel()))
		-- x10, this time with the ShopState arriving after the answer.
		pushFirst = false
		w.rt:advance(2)
		table.clear(saw)
		client:fire(panel.Body.Preview.Side.Buy.OpenCoins10, "Activated")
		client:advance(0.1)
		expect(data.Coins).toBe(coins) -- (x10 asks first: nothing bought yet)
		client:fire(panel.Body.Preview.PackConfirm.Buttons.Confirm, "Activated")
		client:advance(0.1)
		replay()
		expect(data.Coins).toBeLessThan(coins) -- bought (one payment, less duplicate coins)
		expect(panel.Body.Opening.Visible).toBe(true)
		for _ = 1, 10 do
			client:advance(6)
			client:triggerAction("CrateSkip")
		end
		client:advance(1)
		expect(sawOddsChanged()).toBe(false)
		pushFirst = true
		CrateUI.Open("PumpkinCrate")
		client:advance(0.2)
		expect(shownSpice()).toBe(spiceAt(serverLevel()))
	end)

	it("buys nothing when the chances changed unseen, and redraws with the new ones", function()
		CrateUI.Open("PumpkinCrate")
		client:advance(0.2)
		local before = serverLevel()
		-- The level changes on the server without telling the page (like F8 CrateLuckQuiet).
		local quiet = if before >= 14 then 0 else before + 1
		w.setLuck(player, "PumpkinCrate", quiet)
		w.ShopService.LuckChanged(player)
		w.rt:advance(2)
		local coins, opened = data.Coins, data.Crates.Opened
		table.clear(saw)
		client:fire(panel.Body.Preview.Side.Buy.OpenCoins, "Activated")
		client:advance(0.5)
		expect(data.Coins).toBe(coins)
		expect(data.Crates.Opened).toBe(opened)
		expect(panel.Message.Text).toBe(text.OddsChanged)
		expect(panel.Body.Preview.Visible).toBe(true)
		expect(shownSpice()).toBe(spiceAt(quiet))
		-- Now it opens.
		w.rt:advance(2)
		client:fire(panel.Body.Preview.Side.Buy.OpenCoins, "Activated")
		client:advance(0.5)
		expect(data.Crates.Opened).toBe(opened + 1)
		client:advance(6)
		-- A change that reaches an idle page redraws it and says so.
		CrateUI.Open("PumpkinCrate")
		client:advance(0.2)
		local now = serverLevel()
		local moved = if now >= 10 then 0 else now + 5
		w.setLuck(player, "PumpkinCrate", moved)
		w.ShopService.LuckChanged(player)
		w.ShopService.Push(player)
		replay()
		client:advance(0.2)
		expect(panel.Message.Text).toBe(text.OddsChanged)
		expect(shownSpice()).toBe(spiceAt(moved))
		-- An older State never puts an old level back.
		client:fire(client:find("ReplicatedStorage.Remotes.ShopState"), "OnClientEvent", {
			Ready = true,
			Coins = data.Coins,
			Owned = {},
			Equipped = {},
			Vip = false,
			CrateLuck = { PumpkinCrate = 1 },
			LuckVersion = 0,
		})
		client:advance(0.2)
		expect(shownSpice()).toBe(spiceAt(moved))
	end)

	-- Passes the server's new events on in the opposite order (the result before the push).
	local function replayReversed()
		local calls = w.rt:calls("RemoteEvent", "FireClient")
		local mine = {}
		for i = replayed + 1, #calls do
			if calls[i].args[1] == player then
				table.insert(mine, 1, calls[i])
			end
		end
		replayed = #calls
		for _, call in mine do
			local remote = client:find("ReplicatedStorage.Remotes." .. call.instance.Name)
			client:fire(remote, "OnClientEvent", copy(call.args[2]))
		end
	end

	it("a Robux crate opening never says 'your chances changed' either", function()
		local pumpkin = w.CrateOdds.Get("PumpkinCrate")
		local cPumpkin = CCrateOdds.Get("PumpkinCrate")
		pumpkin.Robux.ProductId = 8008
		cPumpkin.Robux.ProductId = 8008
		local Marketplace = client.game:GetService("MarketplaceService")
		try(function()
			for round, reversed in { false, true } do
				client:advance(12) -- (the last opening's few seconds)
				CrateUI.Open("PumpkinCrate")
				client:advance(0.2)
				table.clear(saw)
				local level = serverLevel()
				-- The R$ press checks the luck shown with the real server first (its hold).
				w.rt:advance(2)
				client:fire(panel.Body.Preview.Side.Extras.OpenRobux, "Activated")
				client:advance(0.2)
				expect(panel.Message.Text).toBe(text.WaitingRobux)
				client:fire(Marketplace, "PromptProductPurchaseFinished", me.UserId, 8008, true)
				w.finished(player, 8008, true)
				-- Roblox hands the receipt over: the push and the result, in either order.
				expect(w.receipt(player, 8008, "page-robux-" .. round).Name).toBe("PurchaseGranted")
				if reversed then
					replayReversed()
				else
					replay()
				end
				client:advance(12) -- (this opening)
				expect(panel.Body.Opening.Reveal.Visible).toBe(true)
				expect(sawOddsChanged()).toBe(false)
				-- It says the luck it used, and "Open again" shows the new level.
				expect(panel.Body.Opening.Reveal.Card.LuckUsed.Text).toBe(
					text.RobuxLuck:format(level, CCrateLuck.Steps())
				)
				client:fire(panel.Body.Opening.Reveal.Card.Buttons.OpenAnother, "Activated")
				client:advance(0.2)
				expect(shownSpice()).toBe(spiceAt(serverLevel()))
				expect(sawOddsChanged()).toBe(false)
			end
		end, function()
			pumpkin.Robux.ProductId = 3717218517
			cPumpkin.Robux.ProductId = 3717218517
		end)
	end)
end)

-- The crate page with pretend server answers (C1-C7, C9-C11) ---------------------------------

-- PromptProductPurchase that throws in a runtime with promptFails = true (any other runtime
-- gets the harness's usual recorded call).
Dom.define("MarketplaceService", {
	PromptProductPurchase = function(self, ...)
		local world = Dom.data(self).world
		if world then
			world:recordCall("MarketplaceService", "PromptProductPurchase", self, ...)
			if world.promptFails then
				error("PromptProductPurchase failed (test)", 2)
			end
		end
	end,
})

-- A copy of a table, like Roblox sends over the network.
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

-- RichText without its tags ("<b>Luck 4</b>" -> "Luck 4").
local function plain(text: string): string
	return (text:gsub("<[^>]+>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

local pageServer: any = nil -- (only for its Remotes folder)

--[[
	A client with the crate panel mounted and pretend server answers:
	  p.state            what GetShopState answers (Ready, CrateLuck, LuckVersion...)
	  p.answer(...)      what OpenCrate answers (default: a NoCoins refusal); p.asked lists
	                     every OpenCrate call { crateId, count, luck, guarantee }
	  p.prepare(...)     what PrepareCrateRobux answers (default: Ok); p.prepared lists calls
	options: { luck = { [crateId] = level }, restricted, noPrepare, notReady, features }
]]
local function pageWorld(options: { [string]: any }?)
	local opts = options or {}
	if not pageServer then
		pageServer = serverWorld()
	end
	local client = Runtime.new({ client = true })
	client:replicateFrom(pageServer.rt)
	local Config = client:require("ReplicatedStorage.Shared.Config")
	for _, name in { "Crates", "RobuxCrates", "CrateLuck", "CratePacks", "PremiumCrates" } do
		Config.Features[name] = true
	end
	for name, value in opts.features or {} do
		Config.Features[name] = value
	end
	local remotes = client:find("ReplicatedStorage.Remotes")
	if opts.noPrepare then
		remotes.PrepareCrateRobux:Destroy()
	end
	local p: any = {
		rt = client,
		Config = Config,
		text = Config.Crates.Text,
		asked = {},
		prepared = {},
		answer = nil,
		prepare = nil,
		state = {
			Ready = not opts.notReady,
			Coins = 1000000,
			Owned = {},
			Equipped = {},
			Vip = false,
			CrateLuck = deepCopy(opts.luck or {}),
			LuckVersion = 1,
		},
		CrateOdds = client:require("ReplicatedStorage.Shared.CrateOdds"),
		CrateLuck = client:require("ReplicatedStorage.Shared.CrateLuck"),
		remotes = remotes,
	}
	remotes.GetShopState.OnServerInvoke = function()
		return deepCopy(p.state)
	end
	remotes.OpenCrate.OnServerInvoke = function(_player, crateId, count, luck, guarantee)
		table.insert(p.asked, { crateId, count, luck, guarantee })
		if p.answer then
			return deepCopy(p.answer(crateId, count, luck, guarantee))
		end
		return {
			Ok = false,
			Message = p.text.NoCoins:format(100, Config.Economy.CurrencyName),
			CrateId = crateId,
			LuckVersion = p.state.LuckVersion,
		}
	end
	if not opts.noPrepare then
		remotes.PrepareCrateRobux.OnServerInvoke = function(_player, crateId, luck)
			table.insert(p.prepared, { crateId, luck })
			if p.prepare then
				return deepCopy(p.prepare(crateId, luck))
			end
			return {
				Ok = true,
				Message = "",
				CrateId = crateId,
				Luck = luck,
				LuckVersion = p.state.LuckVersion,
			}
		end
	end
	local me = client.game:GetService("Players").LocalPlayer
	me:SetAttribute("CratesRestricted", opts.restricted == true)
	local gui = client:create("ScreenGui", { Name = "GameUI" }, me.PlayerGui)
	local CrateUI = client:require("StarterPlayer.StarterPlayerScripts.Client.CrateUI")
	CrateUI.Mount(gui)
	client:advance(1)
	p.CrateUI = CrateUI
	p.me = me
	p.gui = gui
	p.panel = gui:FindFirstChild("Crates")
	p.saw = {}
	p.panel.Message:GetPropertyChangedSignal("Text"):Connect(function()
		table.insert(p.saw, p.panel.Message.Text)
	end)
	function p.open(crateId: string?): any
		CrateUI.Open(crateId)
		client:advance(0.2)
		return p.panel.Body.Preview
	end
	function p.press(b: any)
		client:fire(b, "Activated")
		client:advance(0.2)
	end
	-- The server telling this screen new luck levels (a ShopState push).
	function p.push(luck: { [string]: number }, version: number)
		p.state.CrateLuck = deepCopy(luck)
		p.state.LuckVersion = version
		client:fire(remotes.ShopState, "OnClientEvent", deepCopy(p.state))
		client:advance(0.1)
	end
	function p.sawText(words: string): boolean
		return table.find(p.saw, words) ~= nil
	end
	-- What the server would send for one crate of `crateId` giving `itemId`.
	function p.result(crateId: string, itemId: string, extra: { [string]: any }?): any
		local reel = {}
		for k = 1, 32 do
			reel[k] = itemId
		end
		local item = p.CrateOdds.Get(crateId)
		local r: any = {
			Ok = true,
			Message = "",
			CrateId = crateId,
			ItemId = itemId,
			ItemName = itemId,
			Rarity = "Common",
			Duplicate = false,
			Refund = 0,
			Reel = reel,
			WinIndex = 28,
			Paid = "Coins",
		}
		local _ = item
		for k, v in extra or {} do
			r[k] = v
		end
		return r
	end
	return p
end

-- The Luck strip's parts on the page (nil when there is none).
local function strip(preview: any): any
	return preview:FindFirstChild("Luck", true)
end

describe("Crate luck: the crate page (C1-C7, C9-C11)", function()
	it("C1: the strip, the grid and the odds line show the chances at your level", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 } })
		local preview = p.open("PumpkinCrate")
		local luck = strip(preview)
		expect(luck).toBeTruthy()
		expect(luck:IsDescendantOf(preview.Info)).toBe(true) -- (PC: above the skins)
		expect(luck:FindFirstChild("Title", true).Text).toBe("Luck 4 / 15")
		local filled = 0
		for i = 1, 15 do
			local block = luck:FindFirstChild("Step" .. i, true)
			expect(block).toBeTruthy()
			if block:GetAttribute("Filled") then
				filled += 1
				expect(block.BackgroundColor3).toBeNear(p.Config.Rarity.Levels.Rare.Color)
			end
		end
		expect(filled).toBe(4)
		expect(luck:FindFirstChild("Step16", true)).toBeNil()
		expect(luck:FindFirstChild("Chance", true).Text).toBe("Rare or better, next crate: 23.02%")
		expect(luck:FindFirstChild("Help", true).Text).toBe(
			"Every crate below Rare adds 2% to Rare (taken from Common). A Rare or better starts it again at 0. A full meter = Rare or better for sure."
		)
		expect(luck:FindFirstChild("EveryChance", true)).toBeTruthy()
		-- Every card is the level-4 chance, the same numbers the server rolls with.
		local pumpkin = p.CrateOdds.Get("PumpkinCrate")
		local cards = 0
		for _, c in p.CrateOdds.Shown(pumpkin, p.CrateLuck.Boost(pumpkin, 4)) do
			expect(preview.Items[c.Item.Id].Chance.Text).toBe(p.CrateOdds.Format(c.Chance))
			cards += 1
		end
		expect(cards).toBe(20)
		expect(preview.Items.Pumpkin_PumpkinSpice.Chance.Text).toBe("4.415%")
		local line = plain(preview.Side.Odds.Text)
		for _, part in { "CRAZY 0.02%", "Rare 23%", "Uncommon 24%", "Common 52.98%" } do
			if not line:find(part, 1, true) then
				error("the odds line has no " .. part .. ": " .. line)
			end
		end
		-- The pack line, and the skins start under the strip.
		expect(preview.Info.Packs.Text).toBe(
			"x5: at least one Uncommon or better    x10: at least one Rare or better"
		)
		expect(preview.Items.Position.Y.Offset).toBeGreaterThan(90)
		-- x1 sends the level the page shows (no guarantee for one crate).
		p.press(preview.Side.Buy.OpenCoins)
		expect(p.asked[1]).toEqual({ "PumpkinCrate", 1, 4, nil })
	end)

	it("C2: rarity and Deluxe crates have no strip; the Deluxe tab", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 } })
		for _, id in { "CommonCrate", "RareCrate", "PumpkinDeluxeCrate" } do
			local preview = p.open(id)
			expect(strip(preview)).toBeNil()
			expect(preview:FindFirstChild("LuckLine", true)).toBeNil()
		end
		-- The Rare Crate is always Rare: no pack line at all.
		expect(p.open("RareCrate"):FindFirstChild("Packs", true)).toBeNil()
		local deluxe = p.open("PumpkinDeluxeCrate")
		expect(deluxe.Info.Packs.Text).toMatch("x10: at least one Rare or better")
		-- (no x5 line: a Deluxe crate never gives a Common, so it would promise nothing)
		expect(deluxe.Info.Packs.Text:find("x5", 1, true)).toBeNil()
		expect(deluxe.Side.Buy.OpenCoins.Text).toBe("Open 2,000 Coins")
		expect(deluxe.Side.Buy.OpenCoins5.Text).toMatch("10,000")
		expect(deluxe.Side.Buy.OpenCoins10.Text).toMatch("20,000")
		expect(deluxe.Side.Extras.OpenRobux.Text).toBe(p.text.ComingSoon)
		-- The Deluxe tab: six cards at 2,000 Coins.
		p.open()
		local list = p.panel.Body.List
		for _, tab in list.Categories:GetChildren() do
			if tab:IsA("TextButton") and tab:GetAttribute("Category") == "Deluxe" then
				p.press(tab)
			end
		end
		local cards = 0
		for _, card in p.panel.Body.List.Crates:GetChildren() do
			if card:IsA("TextButton") then
				cards += 1
				expect(card.Price.Text).toBe("2,000 Coins")
				expect(card:FindFirstChild("NewRibbon")).toBeTruthy()
			end
		end
		expect(cards).toBe(6)
	end)

	it("C3: Every chance lists every level, your row marked", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 } })
		local preview = p.open("PumpkinCrate")
		p.press(strip(preview):FindFirstChild("EveryChance", true))
		local view = preview.LuckTable
		expect(view.Title.Text).toBe("Pumpkin Crate: every chance at every luck step")
		expect(view.Help.Text).toMatch("Every crate below Rare adds 2%%")
		local rows = view.Rows
		for level = 0, 15 do
			local row = rows:FindFirstChild("Row" .. level)
			expect(row).toBeTruthy()
			expect(row.RichText).toBe(true)
			expect(row:GetAttribute("You")).toBe(level == 4)
			expect(row.TextSize).toBeGreaterThanOrEqual(p.Config.UI.MinTextSize)
		end
		expect(rows:FindFirstChild("Row16")).toBeNil()
		expect(plain(rows.Row0.Text)).toBe(
			"Luck 0  CRAZY 0.02% · Rare 15% (7.5% each) · Uncommon 24% (4.8% each) · Common 60.98% (5.082% each)"
		)
		expect(plain(rows.Row4.Text)).toBe(
			"Luck 4  CRAZY 0.02% · Rare 23% (11.5% each) · Uncommon 24% (4.8% each) · Common 52.98% (4.415% each)  ◀ you"
		)
		expect(plain(rows.Row15.Text)).toBe(
			"Luck 15 (full)  CRAZY 0.04442% · Rare 99.956% (49.978% each) · Uncommon 0% · Common 0%"
		)
		-- Every row is the maths the server rolls with.
		local pumpkin = p.CrateOdds.Get("PumpkinCrate")
		for level = 0, 15 do
			local odds = p.CrateOdds.RarityOdds(pumpkin, p.CrateLuck.Boost(pumpkin, level))
			local text = plain(rows["Row" .. level].Text)
			for rarity, percent in odds do
				local words = ("%s %s"):format(
					p.Config.Rarity.Levels[rarity].Name,
					p.CrateOdds.Format(percent)
				)
				if not text:find(words, 1, true) then
					error(("Row%d has no %q: %s"):format(level, words, text))
				end
			end
		end
		p.press(view.Back)
		expect(preview:FindFirstChild("LuckTable")).toBeNil()
		expect(preview.Visible).toBe(true)
		-- Vampire Castle: its one-in-a-million skin has its own row.
		local vampire = p.open("VampireCastleCrate")
		p.press(strip(vampire):FindFirstChild("EveryChance", true))
		expect(vampire.LuckTable.Rows.Fixed1.Text).toBe(
			"Night Lord Supreme: 0.0001% at every luck step"
		)
		expect(plain(vampire.LuckTable.Rows.Row0.Text)).toMatch("CRAZY 0.0001%%")
	end)

	it("C4: a change on an idle page redraws it and says so; older news never wins", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 } })
		local preview = p.open("PumpkinCrate")
		-- The pack window is open when the change arrives: it closes with the page.
		p.press(preview.Side.Buy.OpenCoins10)
		expect(preview:FindFirstChild("PackConfirm")).toBeTruthy()
		table.clear(p.saw)
		p.push({ PumpkinCrate = 6 }, 2)
		preview = p.panel.Body.Preview
		expect(preview:FindFirstChild("PackConfirm")).toBeNil()
		expect(strip(preview):FindFirstChild("Title", true).Text).toBe("Luck 6 / 15")
		expect(p.panel.Message.Text).toBe(p.text.OddsChanged)
		-- An older push changes nothing.
		p.push({ PumpkinCrate = 2 }, 1)
		expect(strip(preview):FindFirstChild("Title", true).Text).toBe("Luck 6 / 15")
		-- A refusal with a new level: nothing bought, the page shows the new chances.
		p.answer = function(crateId)
			return {
				Ok = false,
				Message = p.text.OddsChanged,
				CrateId = crateId,
				Luck = 7,
				LuckVersion = 3,
			}
		end
		p.open("PumpkinCrate")
		table.clear(p.saw)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(p.asked[#p.asked]).toEqual({ "PumpkinCrate", 1, 6, nil })
		expect(strip(p.panel.Body.Preview):FindFirstChild("Title", true).Text).toBe("Luck 7 / 15")
		expect(p.panel.Message.Text).toBe(p.text.OddsChanged)
		-- A refusal with the same level shows its own message.
		local noCoins = p.text.NoCoins:format(100, p.Config.Economy.CurrencyName)
		p.answer = function(crateId)
			return { Ok = false, Message = noCoins, CrateId = crateId, Luck = 7, LuckVersion = 4 }
		end
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(p.asked[#p.asked]).toEqual({ "PumpkinCrate", 1, 7, nil })
		expect(p.panel.Message.Text).toBe(noCoins)
		-- Your own open: the server's push arrives before its answer and is only stored.
		p.answer = function(crateId)
			p.state.CrateLuck = { PumpkinCrate = 8 }
			p.state.LuckVersion = 5
			p.rt:fire(p.remotes.ShopState, "OnClientEvent", deepCopy(p.state))
			return p.result(
				crateId,
				"Pumpkin_PumpkinSpice",
				{ Luck = 7, LuckAfter = 8, LuckVersion = 5 }
			)
		end
		table.clear(p.saw)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(p.panel.Body.Opening.Visible).toBe(true)
		expect(p.sawText(p.text.OddsChanged)).toBe(false)
		p.press(p.panel.Body.Opening.Skip)
		p.press(p.panel.Body.Opening.Reveal.Card.Buttons.OpenAnother)
		expect(strip(p.panel.Body.Preview):FindFirstChild("Title", true).Text).toBe("Luck 8 / 15")
		expect(p.sawText(p.text.OddsChanged)).toBe(false)
	end)

	it(
		"C5: x5 / x10 ask first, with the price, the rules and the guaranteed crate's chances",
		function()
			local p = pageWorld()
			local preview = p.open("PumpkinCrate")
			p.press(preview.Side.Buy.OpenCoins10)
			expect(#p.asked).toBe(0)
			local window = preview.PackConfirm
			expect(window.Title.Text).toBe("Open Pumpkin Crate x10?")
			local words = plain(window.Body.Text.Text)
			for _, part in
				{
					"Price: 6,000 Coins",
					"The 10 crates open one after another, just like 10 single opens",
					"Your luck now: 0 / 15 (Rare or better next: 15.02%)",
					"If crates 1 to 9 give nothing Rare or better, crate 10 can only be Rare or better. Its chances: CRAZY 0.06057% · Rare 99.939% (49.97% each)",
				}
			do
				if not words:find(part, 1, true) then
					error("the x10 window has no " .. part .. ": " .. words)
				end
			end
			expect(window.Buttons.Confirm.Text).toBe("Open 10 for 6,000 Coins")
			expect(window.Buttons.EveryChance).toBeTruthy()
			-- Every chance from the window, then Back to the window.
			p.press(window.Buttons.EveryChance)
			expect(preview.LuckTable).toBeTruthy()
			p.press(preview.LuckTable.Back)
			expect(preview:FindFirstChild("PackConfirm")).toBeTruthy()
			-- Cancel buys nothing.
			p.press(window.Buttons.Cancel)
			expect(preview:FindFirstChild("PackConfirm")).toBeNil()
			expect(#p.asked).toBe(0)
			-- x5 from luck 0.
			p.press(preview.Side.Buy.OpenCoins5)
			words = plain(preview.PackConfirm.Body.Text.Text)
			local x5 =
				"If crates 1 to 4 give nothing Uncommon or better, crate 5 can only be Uncommon or better. Its chances: CRAZY 0.04254% · Rare 48.915% (24.458% each) · Uncommon 51.042% (10.208% each)"
			if not words:find(x5, 1, true) then
				error("the x5 window has no " .. x5 .. ": " .. words)
			end
			p.press(preview.PackConfirm.Buttons.Confirm)
			expect(p.asked[1]).toEqual({ "PumpkinCrate", 5, 0, "Uncommon" })
			expect(preview:FindFirstChild("PackConfirm")).toBeNil()
			-- At luck 4, Confirm sends that level and the window's guarantee.
			p.push({ PumpkinCrate = 4 }, 2)
			p.rt:advance(1)
			preview = p.open("PumpkinCrate")
			p.press(preview.Side.Buy.OpenCoins10)
			expect(plain(preview.PackConfirm.Body.Text.Text)).toMatch(
				"Your luck now: 4 / 15 %(Rare or better next: 23.02%%%)"
			)
			p.press(preview.PackConfirm.Buttons.Confirm)
			expect(p.asked[2]).toEqual({ "PumpkinCrate", 10, 4, "Rare" })
			-- At luck 6 the meter fills up inside an x10 anyway: the window says so.
			p.push({ PumpkinCrate = 6 }, 3)
			p.rt:advance(1)
			preview = p.open("PumpkinCrate")
			p.press(preview.Side.Buy.OpenCoins10)
			words = plain(preview.PackConfirm.Body.Text.Text)
			expect(words).toMatch("your luck meter fills up during this pack")
			expect(words:find("Its chances", 1, true)).toBeNil()
			p.press(preview.PackConfirm.Buttons.Cancel)
			-- A crate without a meter: crates 1 to 9 have the page's chances, and so does crate
			-- 10 unless the guarantee kicks in (never "every crate has the page's chances").
			local deluxe = p.open("PumpkinDeluxeCrate")
			p.press(deluxe.Side.Buy.OpenCoins10)
			words = plain(deluxe.PackConfirm.Body.Text.Text)
			expect(words:find(p.text.PackHowFixedLast:format(9, 10), 1, true)).toBeTruthy()
			expect(words:find(p.text.PackHowFixed, 1, true)).toBeNil()
			expect(words).toMatch("Its chances: CRAZY 2%% · Rare 98%% %(49%% each%)")
			expect(words:find("Your luck now", 1, true)).toBeNil()
			expect(deluxe.PackConfirm.Buttons:FindFirstChild("EveryChance")).toBeNil()
			p.press(deluxe.PackConfirm.Buttons.Confirm)
			expect(p.asked[3]).toEqual({ "PumpkinDeluxeCrate", 10, 0, "Rare" })
			-- x5: a Deluxe crate never gives a Common, so "Uncommon or better" would promise
			-- nothing: no guarantee, and every crate really has the page's chances.
			p.rt:advance(1)
			deluxe = p.open("PumpkinDeluxeCrate")
			p.press(deluxe.Side.Buy.OpenCoins5)
			words = plain(deluxe.PackConfirm.Body.Text.Text)
			expect(words:find(p.text.PackHowFixed, 1, true)).toBeTruthy()
			expect(words:find("Its chances", 1, true)).toBeNil()
			expect(deluxe.PackConfirm:GetAttribute("Guarantee")).toBeNil()
			p.press(deluxe.PackConfirm.Buttons.Confirm)
			expect(p.asked[4]).toEqual({ "PumpkinDeluxeCrate", 5, 0 })
		end
	)

	it("C6: Open again shows the page and buys nothing; GUARANTEED crates say so", function()
		local p = pageWorld({ luck = { PumpkinCrate = 9 } })
		p.answer = function(crateId, count)
			local results = {}
			for k = 1, count do
				local last = k == count and count > 1
				results[k] = p.result(crateId, "Pumpkin_PumpkinSpice", {
					Luck = 9,
					LuckAfter = 10,
					LuckVersion = 2,
					Guaranteed = if last then "Rare" else nil,
					Rarity = if last then "Rare" else "Common",
					-- (the guaranteed crate is a duplicate: the longest reveal line)
					Duplicate = if last then true else nil,
					Refund = if last then 500 else nil,
				})
			end
			local batch = table.clone(results[1])
			if count > 1 then
				batch.Results = results
			end
			return batch
		end
		local preview = p.open("PumpkinCrate")
		p.press(preview.Side.Buy.OpenCoins)
		p.press(p.panel.Body.Opening.Skip)
		local asked = #p.asked
		local card = p.panel.Body.Opening.Reveal.Card
		expect(card.News.Text).never.toMatch(p.text.Guaranteed)
		expect(card:FindFirstChild("Tags")).toBeNil()
		p.press(card.Buttons.OpenAnother)
		expect(p.panel.Body.Preview.Visible).toBe(true)
		expect(#p.asked).toBe(asked)
		-- A guaranteed crate (x5 here) says so on its reveal...
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins5)
		p.press(p.panel.Body.Preview.PackConfirm.Buttons.Confirm)
		for _ = 1, 5 do
			p.press(p.panel.Body.Opening.Skip)
			local next = p.panel.Body.Opening.Reveal.Card.Buttons:FindFirstChild("Next")
			if next then
				p.press(next)
			end
		end
		card = p.panel.Body.Opening.Reveal.Card
		-- (on a line of its own: "GUARANTEED  Duplicate! +500 Coins back" is too long for one
		-- line of the card, about 0.6 em a letter in the game's font)
		expect(card.Tags.Text).toBe(p.text.Guaranteed)
		local duplicate = p.text.Duplicate:format(500, p.Config.Economy.CurrencyName)
		expect(card.News.Text).toBe(duplicate)
		expect(card.Tags.LayoutOrder).toBeGreaterThan(card.Rarity.LayoutOrder)
		expect(card.Tags.LayoutOrder).toBeLessThan(card.News.LayoutOrder)
		local inner = card.Size.X.Offset - 20 -- (10 px padding each side)
		for _, line in { card.Tags, card.News } do
			if #line.Text * line.TextSize * 0.6 > inner then
				error(("the reveal line %q doesn't fit on one line of the card"):format(line.Text))
			end
		end
		-- The picture leaves room for every line under it (and the gaps between them).
		local gap = card:FindFirstChildOfClass("UIListLayout").Padding.Offset
		local below = 0
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "Art" then
				below += child.Size.Y.Offset + gap
			end
		end
		expect(-card.Art.Size.Y.Offset).toBe(below)
		-- ...and on its Quick open card. Open again in the footer buys nothing either.
		p.press(card.Buttons.OpenAnother)
		p.press(p.panel.Body.Preview.Side.Extras.QuickOpen)
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins5)
		p.press(p.panel.Body.Preview.PackConfirm.Buttons.Confirm)
		local results = p.panel.Body.Results
		expect(results.Visible).toBe(true)
		expect(results.Items.Result5:FindFirstChild("Guaranteed").Text).toBe(p.text.Guaranteed)
		expect(results.Items.Result1:FindFirstChild("Guaranteed")).toBeNil()
		-- The guaranteed crate is also the BEST! one: the two tags on separate rows (a PC card
		-- is about 130 px wide, too narrow for both words side by side).
		local best, sure = results.Items.Result5.Best, results.Items.Result5.Guaranteed
		local bestTop, sureTop = best.Position.Y.Offset, sure.Position.Y.Offset
		if math.abs(sureTop - bestTop) < best.Size.Y.Offset then
			error("BEST! and GUARANTEED are on the same row of the Quick open card")
		end
		expect(sure.TextWrapped).toBe(false)
		expect(sure.AutomaticSize).toBe(p.rt.env.Enum.AutomaticSize.X)
		asked = #p.asked
		p.press(results.Footer.OpenAnother)
		expect(p.panel.Body.Preview.Visible).toBe(true)
		expect(#p.asked).toBe(asked)
		p.press(p.panel.Body.Preview.Side.Extras.QuickOpen) -- (switch it off again)
	end)

	it("C7: a restricted player sees the chances but no strip, pack line or buy buttons", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 }, restricted = true })
		local preview = p.open("PumpkinCrate")
		expect(strip(preview)).toBeNil()
		expect(preview:FindFirstChild("Packs", true)).toBeNil()
		expect(preview:FindFirstChild("Info")).toBeNil()
		expect(preview.Side.Buy.Visible).toBe(false)
		expect(preview.Side.Extras.Visible).toBe(false)
		expect(preview.Items.Pumpkin_PumpkinSpice.Chance.Text).toBe("4.415%")
		expect(p.panel.Message.Text).toBe(p.text.Restricted)
	end)

	it("C9: after a pack the page shows the luck after its last crate", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 } })
		p.answer = function(crateId, count)
			local results = {}
			for k = 1, count do
				results[k] = p.result(crateId, "Pumpkin_PumpkinSpice", {
					Luck = 4,
					LuckAfter = if k == count then 0 else 5,
					LuckVersion = 1 + k,
				})
			end
			local batch = table.clone(results[1])
			batch.Results = results
			batch.LuckAfter = 0
			batch.LuckVersion = 1 + count
			return batch
		end
		local preview = p.open("PumpkinCrate")
		p.press(preview.Side.Extras.QuickOpen)
		p.press(preview.Side.Buy.OpenCoins10)
		p.press(preview.PackConfirm.Buttons.Confirm)
		p.press(p.panel.Body.Results.Footer.OpenAnother)
		expect(strip(p.panel.Body.Preview):FindFirstChild("Title", true).Text).toBe("Luck 0 / 15")
		p.press(p.panel.Body.Preview.Side.Extras.QuickOpen)
	end)

	it("C10: a full meter still lists every skin, the ones that can't drop at 0%", function()
		local p = pageWorld({ luck = { PumpkinCrate = 15 } })
		local preview = p.open("PumpkinCrate")
		local luck = strip(preview)
		expect(luck:FindFirstChild("Title", true).Text).toBe(
			"Luck full. Your next crate is Rare or better for sure."
		)
		expect(luck:FindFirstChild("Chance", true).Text).toBe("Rare or better, next crate: 100%")
		local cards, zero = 0, 0
		for _, card in preview.Items:GetChildren() do
			if card:IsA("Frame") then
				cards += 1
				if card.Chance.Text == "0%" then
					zero += 1
				end
			end
		end
		expect(cards).toBe(20)
		expect(zero).toBe(17)
		local line = plain(preview.Side.Odds.Text)
		expect(line).toMatch("Common 0%%")
		expect(line).toMatch("CRAZY 0.04442%%")
		-- Deluxe Pumpkin: 20 cards, its 12 Commons at 0%.
		local deluxe = p.open("PumpkinDeluxeCrate")
		cards, zero = 0, 0
		for _, card in deluxe.Items:GetChildren() do
			if card:IsA("Frame") then
				cards += 1
				if card.Chance.Text == "0%" then
					zero += 1
					expect(card.Rarity.Text).toBe("Common")
				end
			end
		end
		expect(cards).toBe(20)
		expect(zero).toBe(12)
		expect(plain(deluxe.Side.Odds.Text)).toMatch("Common 0%%")
	end)

	it(
		"C11: Mount never waits for PrepareCrateRobux, and a missing one only says try again",
		function()
			local p = pageWorld({ luck = { PumpkinCrate = 3 }, noPrepare = true })
			-- CrateResult is connected: a Robux crate's result plays, and says the luck it used.
			p.rt:fire(
				p.remotes.CrateResult,
				"OnClientEvent",
				p.result("PumpkinCrate", "Pumpkin_PumpkinSpice", {
					Paid = "Robux",
					Luck = 3,
					LuckAfter = 4,
					LuckVersion = 2,
				})
			)
			p.rt:advance(0.2)
			expect(p.panel.Visible).toBe(true)
			p.press(p.panel.Body.Opening.Skip)
			local card = p.panel.Body.Opening.Reveal.Card
			expect(card.LuckUsed.Text).toBe("Opened at luck 3 / 15")
			-- The R$ press: the server's check can't be found, so nothing happens but a message.
			local preview = p.open("PumpkinCrate")
			expect(strip(preview):FindFirstChild("Title", true).Text).toBe("Luck 4 / 15")
			p.press(preview.Side.Extras.OpenRobux)
			p.rt:advance(p.Config.Crates.RobuxOpen.RemoteWaitSeconds + 0.5)
			expect(p.panel.Message.Text).toBe(p.text.TryAgain)
			expect(#p.rt:calls("MarketplaceService", "PromptProductPurchase")).toBe(0)
			-- The buttons work again.
			p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
			expect(#p.asked).toBe(1)
			-- A coin crate's reveal never shows the luck line.
			p.answer = function(crateId)
				return p.result(
					crateId,
					"Pumpkin_PumpkinSpice",
					{ Luck = 4, LuckAfter = 5, LuckVersion = 3 }
				)
			end
			p.rt:advance(1)
			p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
			p.press(p.panel.Body.Opening.Skip)
			expect(p.panel.Body.Opening.Reveal.Card:FindFirstChild("LuckUsed")).toBeNil()
		end
	)

	it("C11: the R$ button checks the luck first, then waits for Roblox", function()
		local p = pageWorld({ luck = { PumpkinCrate = 3 } })
		local preview = p.open("PumpkinCrate")
		local productId = p.CrateOdds.ProductId(p.CrateOdds.Get("PumpkinCrate"))
		local Marketplace = p.rt.game:GetService("MarketplaceService")
		local function finished(purchased: boolean)
			p.rt:fire(
				Marketplace,
				"PromptProductPurchaseFinished",
				p.me.UserId,
				productId,
				purchased
			)
			p.rt:advance(0.1)
		end
		-- Refused with a new level: the page redraws, no purchase window.
		p.prepare = function(crateId)
			return {
				Ok = false,
				Message = p.text.OddsChanged,
				CrateId = crateId,
				Luck = 5,
				LuckVersion = 2,
			}
		end
		p.press(preview.Side.Extras.OpenRobux)
		expect(p.prepared[1]).toEqual({ "PumpkinCrate", 3 })
		expect(#p.rt:calls("MarketplaceService", "PromptProductPurchase")).toBe(0)
		expect(p.panel.Message.Text).toBe(p.text.OddsChanged)
		preview = p.panel.Body.Preview
		expect(strip(preview):FindFirstChild("Title", true).Text).toBe("Luck 5 / 15")
		-- Accepted: Roblox's window opens; nothing else opens meanwhile; cancel frees it.
		p.prepare = nil
		p.press(preview.Side.Extras.OpenRobux)
		expect(p.prepared[2]).toEqual({ "PumpkinCrate", 5 })
		expect(#p.rt:calls("MarketplaceService", "PromptProductPurchase")).toBe(1)
		expect(p.panel.Message.Text).toBe(p.text.WaitingRobux)
		p.press(preview.Side.Buy.OpenCoins)
		expect(#p.asked).toBe(0)
		finished(false)
		expect(p.panel.Message.Text).toBe(p.text.Hint)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(#p.asked).toBe(1)
		-- Bought, and Roblox is slow: after ClientWaitSeconds the other crates open again, and
		-- this crate's own luck change isn't "your chances changed".
		p.rt:advance(1)
		preview = p.panel.Body.Preview
		p.press(preview.Side.Extras.OpenRobux)
		finished(true)
		table.clear(p.saw)
		p.push({ PumpkinCrate = 6 }, 5)
		expect(p.sawText(p.text.OddsChanged)).toBe(false)
		p.rt:advance(p.Config.Crates.RobuxOpen.ClientWaitSeconds + 1)
		expect(p.panel.Message.Text).toBe(p.text.RobuxSlow)
		local candy = p.open("CandyCrate")
		p.press(candy.Side.Buy.OpenCoins)
		expect(p.asked[#p.asked][1]).toBe("CandyCrate")
		-- Roblox will hand it over later: the wait ends and says so.
		p.open("PumpkinCrate")
		p.press(p.panel.Body.Preview.Side.Extras.OpenRobux)
		p.rt:fire(p.remotes.CrateResult, "OnClientEvent", {
			Ok = false,
			Message = p.text.RobuxLater,
			CrateId = "PumpkinCrate",
			Paid = "Robux",
			Luck = 6,
			LuckVersion = 6,
		})
		p.rt:advance(0.2)
		expect(p.panel.Message.Text).toBe(p.text.RobuxLater)
		local asked = #p.asked
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(#p.asked).toBe(asked + 1)
		-- Roblox's window failing to open leaves the buttons working.
		p.rt.promptFails = true
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Extras.OpenRobux)
		p.rt.promptFails = nil
		expect(p.panel.Message.Text).toBe(p.text.RobuxFailed)
		p.rt:advance(1)
		p.press(p.panel.Body.Preview.Side.Buy.OpenCoins)
		expect(#p.asked).toBe(asked + 2)
	end)

	it("says Checking... on a crate with a meter until the server has told its luck", function()
		local p = pageWorld({ luck = { PumpkinCrate = 4 }, notReady = true })
		local preview = p.open("PumpkinCrate")
		expect(preview.Side.Buy.OpenCoins.Text).toBe(p.text.Checking)
		expect(preview.Side.Buy.OpenCoins.Active).toBe(false)
		expect(preview.Side.Extras.OpenRobux.Text).toBe(p.text.Checking)
		-- A crate without a meter can be opened already.
		local common = p.open("CommonCrate")
		expect(common.Side.Buy.OpenCoins.Text).toMatch("Open")
		-- The first loaded State: the page draws again, quietly, with its buttons.
		preview = p.open("PumpkinCrate")
		p.state.Ready = true
		table.clear(p.saw)
		p.push({ PumpkinCrate = 4 }, 1)
		preview = p.panel.Body.Preview
		expect(preview.Side.Buy.OpenCoins.Text).toBe("Open 600 Coins")
		expect(strip(preview):FindFirstChild("Title", true).Text).toBe("Luck 4 / 15")
		expect(p.sawText(p.text.OddsChanged)).toBe(false)
	end)

	it("follows the switches: CrateLuck, CratePacks and PremiumCrates off", function()
		local noLuck = pageWorld({ luck = { PumpkinCrate = 4 }, features = { CrateLuck = false } })
		local preview = noLuck.open("PumpkinCrate")
		expect(strip(preview)).toBeNil()
		expect(preview.Items.Pumpkin_PumpkinSpice.Chance.Text).toBe("5.082%")
		noLuck.press(preview.Side.Buy.OpenCoins)
		expect(noLuck.asked[1]).toEqual({ "PumpkinCrate", 1, 0, nil })
		noLuck.rt:advance(1)
		noLuck.press(noLuck.panel.Body.Preview.Side.Buy.OpenCoins10)
		local words = plain(noLuck.panel.Body.Preview.PackConfirm.Body.Text.Text)
		expect(words:find(noLuck.text.PackHowFixedLast:format(9, 10), 1, true)).toBeTruthy()
		expect(words).toMatch("Its chances")

		local noPacks =
			pageWorld({ luck = { PumpkinCrate = 4 }, features = { CratePacks = false } })
		preview = noPacks.open("PumpkinCrate")
		expect(strip(preview)).toBeTruthy()
		expect(preview:FindFirstChild("Packs", true)).toBeNil()
		noPacks.press(preview.Side.Buy.OpenCoins10)
		words = plain(preview.PackConfirm.Body.Text.Text)
		expect(words:find("Its chances", 1, true)).toBeNil()
		noPacks.press(preview.PackConfirm.Buttons.Confirm)
		expect(noPacks.asked[1]).toEqual({ "PumpkinCrate", 10, 4, nil })

		local noDeluxe = pageWorld({ features = { PremiumCrates = false } })
		noDeluxe.open()
		for _, tab in noDeluxe.panel.Body.List.Categories:GetChildren() do
			if tab:IsA("TextButton") then
				expect(tab:GetAttribute("Category")).never.toBe("Deluxe")
			end
		end
	end)
end)
