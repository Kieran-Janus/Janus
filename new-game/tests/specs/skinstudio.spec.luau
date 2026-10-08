-- Skin Studio: the skin schema (src/shared/SkinSchema.luau: encode/decode, strict validation,
-- the rarity rules, Luau output), the server (src/server/Services/SkinStudioService.luau: who
-- may use it, the check order, cooldowns, wearing drafts, saving them in memory, the mirror
-- and the optional DataStore), SkinExport (src/server/Tools/SkinExport.luau), the editor's
-- undo state (src/client/SkinStudioState.luau) and the panel (src/client/SkinStudioUI.luau).

local luau = require("@lune/luau")

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

-- MarketplaceService:GetProductInfoAsync for these tests: answers from rt.productInfo[id]
-- (after rt.productInfoDelay virtual seconds), else the harness default (an empty table).
Dom.define("MarketplaceService", {
	GetProductInfoAsync = function(self, id)
		local w = Dom.data(self).world
		local delay = w.productInfoDelay
		if delay and delay > 0 then
			w.env.task.wait(delay)
		end
		local info = w.productInfo and w.productInfo[id]
		return info or {}
	end,
})

local rt = Runtime.new()
local env = rt.env
local Color3, Enum = env.Color3, env.Enum
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Items = rt:require("ReplicatedStorage.Shared.Items")
local Schema = rt:require("ReplicatedStorage.Shared.SkinSchema")
local HttpService = rt.game:GetService("HttpService")

local function skins(): { any }
	local list = {}
	for _, item in Config.Shop.Items do
		if item.Slot == "Skin" then
			table.insert(list, item)
		end
	end
	return list
end

-- Deep equality that says where two values differ.
local function same(a: any, b: any, path: string)
	if type(a) == "table" and type(b) == "table" then
		for k, v in a do
			same(v, b[k], path .. "." .. tostring(k))
		end
		for k in b do
			if a[k] == nil then
				error(path .. "." .. tostring(k) .. " appeared")
			end
		end
		return
	end
	if a ~= b then
		error(("%s: %s ~= %s"):format(path, tostring(a), tostring(b)))
	end
end

-- Runs ToLuau's text and fills in what Skins/init.luau would.
local function evalLuau(item: any): any
	local code = Schema.ToLuau(item)
	local source = "return " .. code:gsub(",%s*$", "")
	local fn = luau.load(source, {
		environment = { rgb = Color3.fromRGB, M = Enum.Material, Color3 = Color3, Enum = Enum },
	})
	local back = fn()
	if Schema.IsCrateTheme(item.Theme) then
		back.Slot = back.Slot or "Skin"
		back.Theme = back.Theme or item.Theme
		back.Crate = back.Crate or Schema.ThemeCrate(item.Theme)
		back.Style.Kind = back.Style.Kind or "Skin"
		if back.Style.HideClothes == nil then
			back.Style.HideClothes = true
		end
	end
	return back
end

-- A valid Rare crate skin to break in many ways.
local function rare(): any
	return Schema.Copy(Items.Get("Pumpkin_SirGourdington"))
end

describe("SkinSchema", function()
	it("knows every key the catalogue uses", function()
		local known = {}
		for _, key in Schema.StyleKeys do
			known[key] = true
		end
		local itemKeys = {}
		for _, key in Schema.ItemKeys do
			itemKeys[key] = true
		end
		for _, key in Schema.ReadOnlyKeys do
			itemKeys[key] = true
		end
		for _, item in skins() do
			for key in item do
				if not itemKeys[key] then
					error(("%s: item key %s is unknown to SkinSchema"):format(item.Id, key))
				end
			end
			for key in item.Style do
				if not known[key] then
					error(("%s: Style.%s is unknown to SkinSchema"):format(item.Id, key))
				end
			end
		end
		-- every field points at a key the shapes know, and every control is a known one
		local controls = {
			Color = true,
			Material = true,
			Choice = true,
			Patterns = true,
			Toggle = true,
			Number = true,
			Text = true,
			Effects = true,
			Motion = true,
			Catalog = true,
		}
		for _, field in Schema.Fields do
			expect(controls[field.Control]).toBe(true)
			expect(field.Help).toBeA("string")
			if field.Choices then
				expect(#field.Choices()).toBeGreaterThan(0)
			end
		end
	end)

	it("turns every skin into JSON and back exactly (~634 skins)", function()
		local count = 0
		for _, item in skins() do
			local json = HttpService:JSONEncode(Schema.Encode(item))
			local back, errors = Schema.Decode(HttpService:JSONDecode(json))
			if not back then
				error(item.Id .. ": " .. table.concat(errors, "; "))
			end
			same(item, back, item.Id)
			count += 1
		end
		expect(count).toBeGreaterThan(600)
		-- the special ones keep their extra keys
		local king = Schema.Decode(Schema.Encode(Items.Get("KingSkin")))
		expect(king.VipOnly).toBe(true)
		local tower = Schema.Decode(Schema.Encode(Items.Get("Tower_TormentedSoul")))
		expect(tower.Exclusive).toBe("TowerParkour")
		expect(tower.Theme).toBe("Tower")
	end)

	it("writes every skin as Luau that gives the same skin back", function()
		for _, item in skins() do
			same(item, evalLuau(item), item.Id)
		end
		local text = Schema.ToLuau(Items.Get("VampireCastle_NightLordSupreme"))
		expect(text).toMatch("OneInAMillion = true, %-%- only in this crate")
		expect(text).toMatch("Odds = 0.0001, %-%- percent: 1 in 1,000,000 opens")
		expect(text).never.toMatch("Slot =")
		expect(text).never.toMatch("\n\t\t\tKind =")
		expect(text:sub(1, 2)).toBe("\t{")
	end)

	it("finds every look unique and every rarity rule kept (the catalogue rules)", function()
		local seen = {}
		for _, item in skins() do
			local key = Schema.LookKey(item.Style)
			if seen[key] then
				error(seen[key] .. " and " .. item.Id .. " look the same")
			end
			seen[key] = item.Id
			local problems = Schema.RarityProblems(item)
			if #problems > 0 then
				error(table.concat(problems, "; "))
			end
		end
		expect(#Schema.CrazyHeadProblems(Config.Shop.Items)).toBe(0)
	end)

	it("accepts every catalogue skin with no errors and no warnings", function()
		for _, item in skins() do
			local ok, errors, warnings = Schema.Validate(item)
			if not ok then
				error(item.Id .. ": " .. table.concat(errors, "; "))
			end
			if #warnings > 0 then
				error(item.Id .. " warns: " .. table.concat(warnings, "; "))
			end
		end
	end)

	it("refuses broken drafts", function()
		local nan = 0 / 0
		local bad: { { string | (any) -> () } } = {
			{
				"unknown item key",
				function(i)
					i.Foo = 1
				end,
			},
			{
				"unknown Style key",
				function(i)
					i.Style.Sparkly = true
				end,
			},
			{
				"unknown Accent key",
				function(i)
					i.Style.Accent.Glitter = true
				end,
			},
			{
				"Name a number",
				function(i)
					i.Name = 5
				end,
			},
			{
				"colour as text",
				function(i)
					i.Style.TorsoColor = "red"
				end,
			},
			{
				"material as text",
				function(i)
					i.Style.Material = "Fabric"
				end,
			},
			{
				"another enum",
				function(i)
					i.Style.Material = Enum.PartType.Ball
				end,
			},
			{
				"toggle as text",
				function(i)
					i.Style.HideClothes = "yes"
				end,
			},
			{
				"Transparency 1",
				function(i)
					i.Style.Transparency = 1
				end,
			},
			{
				"Brightness 11",
				function(i)
					i.Style.Glow.Brightness = 11
				end,
			},
			{
				"Range -1",
				function(i)
					i.Style.Glow.Range = -1
				end,
			},
			{
				"Count 9",
				function(i)
					i.Style.Crazy = { Rainbow = true, Count = 9 }
				end,
			},
			{
				"Count 2.5",
				function(i)
					i.Style.Crazy = { Rainbow = true, Count = 2.5 }
				end,
			},
			{
				"Price -1",
				function(i)
					i.Price = -1
				end,
			},
			{
				"Price 1.5",
				function(i)
					i.Price = 1.5
				end,
			},
			{
				"Price huge",
				function(i)
					i.Price = 1e8
				end,
			},
			{
				"Name 41 letters",
				function(i)
					i.Name = string.rep("a", 41)
				end,
			},
			{
				"Name empty",
				function(i)
					i.Name = ""
				end,
			},
			{
				"a huge string",
				function(i)
					i.Style.Head = string.rep("x", 5000)
				end,
			},
			{
				"7 deep",
				function(i)
					i.Style.Animate = { { Effect = "Bob", Colors = { { { 1 } } } } }
				end,
			},
			{
				"newline in Name",
				function(i)
					i.Name = "Sir\nGourd"
				end,
			},
			{
				"tab in Id",
				function(i)
					i.Id = "Pumpkin_Sir\tGourd"
				end,
			},
			{
				"NUL in Head",
				function(i)
					i.Style.Head = "SkinPumpkin\0"
				end,
			},
			{
				"newline in a pattern",
				function(i)
					i.Style.Accent.Pattern = { "Belt\n" }
				end,
			},
			{
				"a list with a hole",
				function(i)
					i.Style.Accent.Pattern = { [1] = "Belt", [3] = "Boots" }
				end,
			},
			{
				"Kind Hat",
				function(i)
					i.Style.Kind = "Hat"
				end,
			},
			{
				"bad Id",
				function(i)
					i.Id = "pumpkin_lower"
				end,
			},
			{
				"Id from another theme",
				function(i)
					i.Id = "Candy_SirGourdington"
				end,
			},
			{
				"StudioDraft_ Id",
				function(i)
					i.Id = "StudioDraft_X"
				end,
			},
			{
				"unknown head",
				function(i)
					i.Style.Head = "NoSuchHead"
				end,
			},
			{
				"unknown face",
				function(i)
					i.Style.Face = "Grumpy"
				end,
			},
			{
				"unknown pattern",
				function(i)
					i.Style.Accent.Pattern = "Polkadots"
				end,
			},
			{
				"too many patterns",
				function(i)
					i.Style.Accent.Pattern =
						{ "Belt", "Boots", "Cuffs", "Collar", "Gloves", "Stripes", "Spots" }
				end,
			},
			{
				"unknown aura",
				function(i)
					i.Style.Aura.Kind = "Fireworks"
				end,
			},
			{
				"glow without a colour",
				function(i)
					i.Style.Glow.Color = nil
				end,
			},
			{
				"unknown orbit",
				function(i)
					i.Style.Crazy = { Rainbow = true, Orbit = "Cars" }
				end,
			},
			{
				"unknown special effect",
				function(i)
					i.Style.Crazy = { Rainbow = true, Effect = "Fireworks" }
				end,
			},
			{
				"unknown rarity",
				function(i)
					i.Rarity = "Legendary"
				end,
			},
			{
				"unknown theme",
				function(i)
					i.Theme = "Space"
				end,
			},
			{
				"unknown crate",
				function(i)
					i.Crate = "NoCrate"
				end,
			},
			{
				"Slot Hat",
				function(i)
					i.Slot = "Hat"
				end,
			},
			{
				"unknown animation",
				function(i)
					i.Style.Animate = { { Effect = "Explode" } }
				end,
			},
			{
				"rainbow accents coloured twice",
				function(i)
					i.Style.Crazy = { Rainbow = true }
					i.Style.Animate = { { Effect = "Shimmer", Target = "Accents" } }
				end,
			},
			{
				"unknown walk style",
				function(i)
					i.Style.Motion = "Moonwalk"
				end,
			},
			{
				"a Vector3",
				function(i)
					i.Style.BodyColor = env.Vector3.new(1, 2, 3)
				end,
			},
		}
		-- NaN, +inf and -inf in every number field
		local numbers = {
			function(i, x)
				i.Style.Transparency = x
			end,
			function(i, x)
				i.Style.Glow.Brightness = x
			end,
			function(i, x)
				i.Style.Glow.Range = x
			end,
			function(i, x)
				i.Style.Crazy = { Rainbow = true, Count = x }
			end,
			function(i, x)
				i.Price = x
			end,
			function(i, x)
				i.Odds = x
			end,
			function(i, x)
				i.Style.Animate = { { Effect = "Bob", Speed = x } }
			end,
			function(i, x)
				i.Style.Animate = { { Effect = "Spin", Amount = x } }
			end,
			function(i, x)
				i.Style.Animate = { { Effect = "Bob", Delay = x } }
			end,
		}
		for n, set in numbers do
			for _, x in { nan, math.huge, -math.huge } do
				table.insert(bad, {
					("number field %d = %s"):format(n, tostring(x)),
					function(i)
						set(i, x)
					end,
				})
			end
		end
		expect(#bad).toBeGreaterThanOrEqual(40)
		for _, case in bad do
			local name, change = case[1] :: string, case[2] :: (any) -> ()
			local item = rare()
			change(item)
			local ok, errors = Schema.Validate(item)
			if ok then
				error("accepted a draft with " .. name)
			end
			expect(#errors).toBeGreaterThan(0)
		end
		expect((Schema.Validate("not a table"))).toBe(false)
		-- an Id another draft already has
		expect((Schema.IdOk("Pumpkin_Taken", "Pumpkin", { Pumpkin_Taken = true }))).toBe(false)
		expect((Schema.IdOk("Pumpkin_Free", "Pumpkin", { Pumpkin_Taken = true }))).toBe(true)
	end)

	it(
		"allows 5-deep lists (colours, catalog accessories) and the CRAZY glow colour cycle",
		function()
			local item = rare()
			item.Style.Animate = {
				{
					Effect = "ColorCycle",
					Target = "Head",
					Colors = { Color3.new(1, 0, 0), Color3.new(0, 0, 1) },
				},
			}
			item.Style.Catalog = { Accessories = { { Id = 1234567890, Type = "Hat" } } }
			local ok, errors = Schema.Validate(item)
			if not ok then
				error(table.concat(errors, "; "))
			end
			local crazy = Schema.Copy(Items.Get("Pumpkin_MegaGourdSupreme"))
			crazy.Style.Animate = {
				{
					Effect = "ColorCycle",
					Target = "Glow",
					Colors = { Color3.new(1, 0, 0), Color3.new(0, 1, 0) },
				},
			}
			expect((Schema.Validate(crazy))).toBe(true)
			-- and they survive JSON
			local back =
				Schema.Decode(HttpService:JSONDecode(HttpService:JSONEncode(Schema.Encode(item))))
			same(item, back, "item")
		end
	)

	it("refuses a draft too big to send or to wear", function()
		local cfg = Config.SkinStudio
		local saved = cfg.MaxDraftBytes
		cfg.MaxDraftBytes = 200
		local ok = Schema.Validate(rare())
		cfg.MaxDraftBytes = saved
		expect(ok).toBe(false)
		local anim = Config.SkinAnimate
		local savedLive = anim.MaxLiveChars
		anim.MaxLiveChars = 20
		local item = rare()
		item.Style.Animate = { { Effect = "Bob", Target = "Head" } }
		local okLive, errors = Schema.Validate(item)
		anim.MaxLiveChars = savedLive
		expect(okLive).toBe(false)
		expect(table.concat(errors, " ")).toMatch("too long")
	end)

	it("refuses broken JSON-side drafts when decoding", function()
		local encoded = Schema.Encode(rare())
		encoded.Style.TorsoColor = "#GG0000"
		expect((Schema.Decode(encoded))).toBeNil()
		encoded = Schema.Encode(rare())
		encoded.Style.Material = "Cheese"
		expect((Schema.Decode(encoded))).toBeNil()
		encoded = Schema.Encode(rare())
		encoded.Style.TorsoColor = Color3.new(1, 0, 0) -- not JSON
		expect((Schema.Decode(encoded))).toBeNil()
		encoded = Schema.Encode(rare())
		encoded.Style.Glow.Flash = true
		expect((Schema.Decode(encoded))).toBeNil()
		expect((Schema.Decode("text"))).toBeNil()
	end)

	it("warns (but allows) rarity rules, a look someone has and a used CRAZY head", function()
		local function warnsAbout(item: any, pattern: string)
			local ok, errors, warnings = Schema.Validate(item)
			if not ok then
				error(table.concat(errors, "; "))
			end
			for _, text in warnings do
				if text:find(pattern) then
					return
				end
			end
			error(("no warning like %q, got: %s"):format(pattern, table.concat(warnings, " | ")))
		end
		local common = Schema.Copy(Items.Get("Pumpkin_PumpkinSpice"))
		common.Id = "Pumpkin_FancySpice"
		common.Name = "Fancy Spice"
		common.Style.Head = "SkinPumpkin"
		warnsAbout(common, "Commons are colours")
		local uncommon = Schema.Copy(Items.Get("Pumpkin_JackOGrin"))
		uncommon.Style.Glow = { Color = Color3.new(1, 1, 1) }
		warnsAbout(uncommon, "Uncommons add a head piece")
		local rareOne = rare()
		rareOne.Style.Aura = nil
		warnsAbout(rareOne, "Rares have a head piece")
		local crazy = Schema.Copy(Items.Get("Pumpkin_MegaGourdSupreme"))
		crazy.Style.Crazy = nil
		warnsAbout(crazy, "CRAZY skins have everything")
		local copy = Schema.Copy(Items.Get("Pumpkin_BlazeJack"))
		copy.Id = "Pumpkin_BlazeJackTwo"
		copy.Name = "Blaze Jack Two"
		warnsAbout(copy, "look the same")
		local thief = Schema.Copy(Items.Get("Pumpkin_JackOGrin"))
		thief.Style.Head = "SugarStorm"
		warnsAbout(thief, "the CRAZY head of")
		local named = rare()
		named.Id = "Pumpkin_SirGourdingtonTwo"
		named.Style.BodyColor = Color3.fromRGB(1, 2, 3)
		named.Name = "Blaze Jack"
		warnsAbout(named, "also called")
		local sections = Schema.CheckSections(common, Config.Shop.Items)
		expect(#sections).toBeGreaterThan(0)
		expect(sections[1].Section).toBeA("string")
	end)

	it("makes Ids, new skins, copies and the item worn in Studio", function()
		expect(Schema.IdFromName("Pumpkin", "Jack's Jumper")).toBe("Pumpkin_JacksJumper")
		expect(Schema.IdFromName("Candy", "  gum drop 2")).toBe("Candy_GumDrop2")
		expect(Schema.IdFromName("Candy", "3 eyes")).toBe("Candy_Skin3Eyes")
		local new = Schema.NewItem("Moonlight")
		expect(new.Theme).toBe("Moonlight")
		expect(new.Crate).toBe("MoonlightCrate")
		expect(new.Rarity).toBe("Common")
		expect((Schema.Validate(new))).toBe(true)
		local copy = Schema.Duplicate(Items.Get("AlienAbduction_StarVoyager"))
		expect(copy.Id).toBe("AlienAbduction_StarVoyagerCopy")
		expect(copy.Name).toBe("Star Voyager Copy")
		expect(copy.OneInAMillion).toBeNil()
		local worn = Schema.WearItem({ DraftId = "ABC-123", Item = Items.Get("Pumpkin_BlazeJack") })
		expect(worn.Id).toBe("StudioDraft_ABC-123")
		expect(worn.ModelId).toBe("Pumpkin_BlazeJack")
		expect(worn.Slot).toBe("Skin")
		expect(worn.Style.Kind).toBe("Skin")
		local unsaved = Schema.WearItem({ Author = 77, Item = Schema.NewItem("Candy") })
		expect(unsaved.Id).toBe("StudioDraft_U77")
		expect(unsaved.Style.HideClothes).toBe(true)
	end)

	it("changes one key at a time, making and removing groups", function()
		local item = Schema.NewItem("Pumpkin")
		Schema.Set(item, { "Style", "Glow", "Brightness" }, 3)
		expect(item.Style.Glow.Brightness).toBe(3)
		expect(item.Style.Glow.Color).toBeTruthy() -- made with a colour, so it stays valid
		Schema.Set(item, { "Style", "Aura", "Color" }, Color3.new(1, 0, 0))
		expect(item.Style.Aura.Kind).toBe("Sparkles")
		Schema.Set(item, { "Style", "Glow", "Brightness" }, nil)
		Schema.Set(item, { "Style", "Glow", "Color" }, nil)
		expect(item.Style.Glow).toBeNil()
		expect(Schema.Get(item, { "Style", "Aura", "Kind" })).toBe("Sparkles")
		Schema.Set(item, { "Style", "Nothing", "Here" }, nil) -- clearing a missing key is fine
		expect(item.Style.Nothing).toBeNil()
	end)
end)

-- Server ------------------------------------------------------------------------------------------

type World = {
	rt: any,
	Config: any,
	Service: any,
	Shop: any,
	Data: any,
	Admin: any,
	Schema: any,
	Remote: any,
	Http: any,
}

-- A server with Data, Shop, Admin and Skin Studio. `setup(Config)` runs before Start.
local function server(options: { [string]: any }?, setup: ((any, any) -> ())?): World
	local opts = options or { studio = true }
	local s = Runtime.new(opts)
	local C = s:require("ReplicatedStorage.Shared.Config")
	if setup then
		setup(C, s)
	end
	local Data = s:require("ServerScriptService.Server.Services.DataService")
	local Shop = s:require("ServerScriptService.Server.Services.ShopService")
	local Admin = s:require("ServerScriptService.Server.Services.AdminService")
	local Service = s:require("ServerScriptService.Server.Services.SkinStudioService")
	Data.Start()
	Shop.Start()
	Admin.Start()
	Service.Start()
	return {
		rt = s,
		Config = C,
		Service = Service,
		Shop = Shop,
		Data = Data,
		Admin = Admin,
		Schema = s:require("ReplicatedStorage.Shared.SkinSchema"),
		Remote = s:find("ReplicatedStorage.Remotes.SkinStudio"),
		Http = s.game:GetService("HttpService"),
	}
end

local function invoke(w: World, player: any, action: any, payload: any?): any
	return w.rt:invokeServer(w.Remote, player, action, payload)
end

-- The JSON text Wear / Save take.
local function payload(w: World, item: any, extra: { [string]: any }?): string
	local body: { [string]: any } = { Item = w.Schema.Encode(item) }
	for k, v in extra or {} do
		body[k] = v
	end
	return w.Http:JSONEncode(body)
end

local function itemOf(w: World, id: string): any
	return w.Schema.Copy(w.rt:require("ReplicatedStorage.Shared.Items").Get(id))
end

-- Everything printed since log number `from` (rt.logs holds { level, text }).
local function printedSince(w: World, from: number): string
	local lines = {}
	for i = from + 1, #w.rt.logs do
		table.insert(lines, w.rt.logs[i].text)
	end
	return table.concat(lines, "\n")
end

-- Lets every cooldown pass.
local function rest(w: World)
	w.rt:advance(6)
end

describe("SkinStudioService", function()
	local w = server()
	local player = w.rt:addPlayer({ Name = "Kieran" })
	w.rt:advance(3)

	it("lets admins in Studio in, and nobody else", function()
		expect(player:GetAttribute("Admin")).toBe(true)
		expect(w.Service.Allowed(player)).toBe(true)
		local hello = invoke(w, player, "Hello")
		expect(hello.Ok).toBe(true)
		expect(hello.Data.DataStore).toBe("Off")
		-- a live server: admins need AllowInLiveServers
		local live = server({ studio = false })
		local someone = live.rt:addPlayer({ Name = "Someone" })
		live.rt:advance(2)
		expect(live.Service.Allowed(someone)).toBe(false)
		someone:SetAttribute("Admin", true)
		expect(live.Service.Allowed(someone)).toBe(false)
		expect(invoke(live, someone, "Hello").Ok).toBe(false)
		live.Config.SkinStudio.AllowInLiveServers = true
		expect(live.Service.Allowed(someone)).toBe(true)
		live.Config.SkinStudio.AllowInLiveServers = false
		-- switched off: "not allowed", never an error
		local off = server({ studio = true }, function(C)
			C.Features.SkinStudio = false
		end)
		local kid = off.rt:addPlayer({ Name = "Kid" })
		off.rt:advance(2)
		local answer = invoke(off, kid, "Hello")
		expect(answer.Ok).toBe(false)
		expect(answer.Message).toBe(off.Config.SkinStudio.Text.NotAllowed)
		expect(#off.rt.errors).toBe(0)
	end)

	it("checks who you are before reading anything you send", function()
		local live = server({ studio = false })
		local stranger = live.rt:addPlayer({ Name = "Stranger" })
		live.rt:advance(2)
		local decodes = 0
		local real = live.Schema.Decode
		live.Schema.Decode = function(...)
			decodes += 1
			return real(...)
		end
		local huge = string.rep("{", 100000)
		for _, action in { "Wear", "Save", "Get", "Delete", "LookupAsset" } do
			local answer = invoke(live, stranger, action, huge)
			expect(answer.Ok).toBe(false)
			expect(answer.Message).toBe(live.Config.SkinStudio.Text.NotAllowed)
		end
		expect(decodes).toBe(0)
		live.Schema.Decode = real
	end)

	it("answers broken calls with Ok = false", function()
		rest(w)
		for _, case in
			{
				{ 42, nil },
				{ nil, nil },
				{ "Dance", nil },
				{ "Wear", { Item = {} } }, -- a table, not JSON text
				{ "Save", "not json {" },
				{ "Save", string.rep("x", w.Config.SkinStudio.MaxDraftBytes + 1) },
				{ "Wear", w.Http:JSONEncode({ Item = { Id = "Nope" } }) },
				{
					"Save",
					w.Http:JSONEncode({
						Item = w.Schema.Encode(itemOf(w, "Pumpkin_BlazeJack")),
						Hack = 1,
					}),
				},
				{ "Get", 5 },
				{ "Delete", "no-such-draft" },
				{ "LookupAsset", "123" },
				{ "LookupAsset", 0 / 0 },
				{ "LookupAsset", 1.5 },
			}
		do
			rest(w)
			local answer = invoke(w, player, case[1], case[2])
			expect(answer.Ok).toBe(false)
			expect(answer.Message).toBeA("string")
		end
		expect(#w.rt.errors).toBe(0)
	end)

	it("wears a draft without changing the save, again after respawning", function()
		rest(w)
		local data = w.Data.Get(player)
		data.Owned.Zombie = true
		data.Equipped.Skin = "Zombie"
		local item = itemOf(w, "Pumpkin_SirGourdington")
		item.Name = "Sir Testington"
		local answer = invoke(w, player, "Wear", payload(w, item))
		expect(answer.Ok).toBe(true)
		expect(answer.Data.WornId).toBe("StudioDraft_U" .. player.UserId)
		local model = player.Character:FindFirstChild("Cosmetic_Skin")
		expect(model).toBeInstanceOf("Model")
		expect(model:GetAttribute("ItemId")).toBe(answer.Data.WornId)
		expect(w.Shop.SkinOverride(player).ModelId).toBe("Pumpkin_SirGourdington")
		expect(data.Equipped.Skin).toBe("Zombie") -- the save never changes
		expect(data.Owned.Pumpkin_SirGourdington).toBeNil()
		w.rt:spawnCharacter(player)
		w.rt:advance(1)
		local again = player.Character:FindFirstChild("Cosmetic_Skin")
		expect(again).toBeTruthy()
		expect(again:GetAttribute("ItemId")).toBe(answer.Data.WornId)
		expect(invoke(w, player, "Hello").Data.Wearing).toBe("Sir Testington")
		-- back to the equipped skin (Zombie only paints the body: no Cosmetic_Skin)
		rest(w)
		expect(invoke(w, player, "StopWearing").Ok).toBe(true)
		expect(player.Character:FindFirstChild("Cosmetic_Skin")).toBeNil()
		expect(w.Shop.SkinOverride(player)).toBeNil()
		-- never for a Hide & Seek hider
		rest(w)
		player:SetAttribute("HideSeekRole", "Hider")
		expect(invoke(w, player, "Wear", payload(w, item)).Ok).toBe(false)
		player:SetAttribute("HideSeekRole", nil)
	end)

	it("keeps Wear calls to the cooldown", function()
		rest(w)
		local item = itemOf(w, "Pumpkin_BlazeJack")
		expect(invoke(w, player, "Wear", payload(w, item)).Ok).toBe(true)
		local second = invoke(w, player, "Wear", payload(w, item))
		expect(second.Ok).toBe(false)
		expect(second.Message).toBe(w.Config.SkinStudio.Text.SlowDown)
		rest(w)
		invoke(w, player, "StopWearing")
	end)

	local savedId: string? = nil

	it("saves, reads and deletes drafts in memory and the mirror", function()
		rest(w)
		local item = w.Schema.NewItem("Pumpkin")
		item.Id = "Pumpkin_TestPatch"
		item.Name = "Test Patch"
		local answer = invoke(w, player, "Save", payload(w, item, { Note = "for the test" }))
		if not answer.Ok then
			error(answer.Message)
		end
		local record = answer.Data
		expect(record.DraftId).toMatch("^%x+%-%x+%-%x+%-%x+%-%x+$")
		expect(record.Author).toBe(player.UserId)
		expect(record.Note).toBe("for the test")
		expect(answer.Message).toBe(w.Config.SkinStudio.Text.Saved)
		savedId = record.DraftId
		local mirror = w.rt:find("ServerStorage.SkinStudioDrafts")
		local value = mirror:FindFirstChild(record.DraftId)
		expect(value).toBeInstanceOf("StringValue")
		expect(value:GetAttribute("SkinId")).toBe("Pumpkin_TestPatch")
		local stored = w.Http:JSONDecode(value.Value)
		expect(stored.Item.Id).toBe("Pumpkin_TestPatch")
		-- Get gives the whole draft, Hello only summaries
		rest(w)
		local got = invoke(w, player, "Get", record.DraftId)
		expect(got.Ok).toBe(true)
		expect(got.Data.Item.Name).toBe("Test Patch")
		local hello = invoke(w, player, "Hello")
		expect(#hello.Data.Drafts).toBe(1)
		local summary = hello.Data.Drafts[1]
		expect(summary.SkinId).toBe("Pumpkin_TestPatch")
		expect(summary.Item).toBeNil()
		expect(summary.InGameFiles).toBe(false)
		-- saving it again keeps its DraftId
		rest(w)
		item.Name = "Test Patch Two"
		local again = invoke(
			w,
			player,
			"Save",
			payload(w, item, { DraftId = record.DraftId, Updated = 1, Author = 1 })
		)
		expect(again.Ok).toBe(true)
		expect(again.Data.DraftId).toBe(record.DraftId)
		expect(again.Data.Author).toBe(player.UserId) -- the client can't set it
		expect(#mirror:GetChildren()).toBe(1)
	end)

	it("refuses an Id another draft or skin already has", function()
		rest(w)
		local item = w.Schema.NewItem("Pumpkin")
		item.Id = "Pumpkin_TestPatch" -- the draft above
		item.Name = "Another"
		local answer = invoke(w, player, "Save", payload(w, item))
		expect(answer.Ok).toBe(false)
		rest(w)
		item.Id = "Pumpkin_BlazeJack" -- a skin in the game, but this draft doesn't edit it
		expect(invoke(w, player, "Save", payload(w, item)).Ok).toBe(false)
	end)

	it("locks the Id, theme and economy of a skin players own", function()
		rest(w)
		local item = itemOf(w, "Pumpkin_BlazeJack")
		item.Style.BodyColor = Color3.fromRGB(10, 20, 30)
		local ok = invoke(w, player, "Save", payload(w, item, { Source = "Pumpkin_BlazeJack" }))
		expect(ok.Ok).toBe(true)
		local draftId = ok.Data.DraftId
		rest(w)
		item.Rarity = "Crazy"
		local locked = invoke(
			w,
			player,
			"Save",
			payload(w, item, { Source = "Pumpkin_BlazeJack", DraftId = draftId })
		)
		expect(locked.Ok).toBe(false)
		expect(locked.Message).toBe(w.Config.SkinStudio.Text.EconomyLocked)
		rest(w)
		local unlocked = invoke(
			w,
			player,
			"Save",
			payload(
				w,
				item,
				{ Source = "Pumpkin_BlazeJack", DraftId = draftId, UnlockEconomy = true }
			)
		)
		expect(unlocked.Ok).toBe(true)
		expect(unlocked.Data.UnlockEconomy).toBe(true)
		rest(w)
		local renamed = itemOf(w, "Pumpkin_BlazeJack")
		renamed.Id = "Pumpkin_BlazeJackier"
		expect(invoke(w, player, "Save", payload(w, renamed, { Source = "Pumpkin_BlazeJack" })).Ok).toBe(
			false
		)
		rest(w)
		expect(
			invoke(
				w,
				player,
				"Save",
				payload(w, itemOf(w, "Pumpkin_BlazeJack"), { Source = "Nope" })
			).Ok
		).toBe(false)
		rest(w)
		expect(invoke(w, player, "Delete", draftId).Ok).toBe(true)
	end)

	it("marks a draft that is already in the game files", function()
		rest(w)
		local item = itemOf(w, "Pumpkin_Gourdy")
		local answer = invoke(w, player, "Save", payload(w, item, { Source = "Pumpkin_Gourdy" }))
		expect(answer.Ok).toBe(true)
		rest(w)
		local found = false
		for _, summary in invoke(w, player, "Hello").Data.Drafts do
			if summary.SkinId == "Pumpkin_Gourdy" then
				found = true
				expect(summary.InGameFiles).toBe(true)
			end
		end
		expect(found).toBe(true)
		rest(w)
		expect(invoke(w, player, "Delete", answer.Data.DraftId).Ok).toBe(true)
	end)

	it("deletes a draft from memory and the mirror", function()
		rest(w)
		local id = savedId :: string
		expect(invoke(w, player, "Delete", id).Ok).toBe(true)
		expect(w.rt:find("ServerStorage.SkinStudioDrafts"):FindFirstChild(id)).toBeNil()
		rest(w)
		expect(invoke(w, player, "Get", id).Ok).toBe(false)
	end)

	it("keeps to MaxDrafts", function()
		rest(w)
		local cfg = w.Config.SkinStudio
		local savedMax, savedCooldown = cfg.MaxDrafts, cfg.SaveCooldown
		cfg.MaxDrafts = 2
		cfg.SaveCooldown = 0
		local ids = {}
		for i = 1, 3 do
			local item = w.Schema.NewItem("Candy")
			item.Id = "Candy_Limit" .. string.char(64 + i)
			item.Name = "Limit " .. i
			local answer = invoke(w, player, "Save", payload(w, item))
			expect(answer.Ok).toBe(i <= 2)
			if answer.Ok then
				table.insert(ids, answer.Data.DraftId)
			end
		end
		cfg.MaxDrafts, cfg.SaveCooldown = savedMax, savedCooldown
		for _, id in ids do
			rest(w)
			invoke(w, player, "Delete", id)
		end
	end)

	it("looks catalog items up, says who made them and remembers it for Save", function()
		rest(w)
		w.rt.productInfo = {
			[111] = {
				Name = "Pumpkin Hat",
				AssetTypeId = 8,
				Creator = { Name = "Roblox", CreatorType = "User", CreatorTargetId = 1 },
			},
			[222] = {
				Name = "Someone's Hat",
				AssetTypeId = 8,
				Creator = { Name = "Someone", CreatorType = "User", CreatorTargetId = 999 },
			},
		}
		local roblox = invoke(w, player, "LookupAsset", 111)
		expect(roblox.Ok).toBe(true)
		expect(roblox.Data.Name).toBe("Pumpkin Hat")
		expect(roblox.Data.AssetType).toBe("Hat")
		expect(roblox.Data.RobloxMade).toBe(true)
		expect(roblox.Data.Allowed).toBe(true)
		rest(w)
		local other = invoke(w, player, "LookupAsset", 222)
		expect(other.Data.Allowed).toBe(false)
		expect(other.Data.Problem).toBeA("string")
		-- Save records the server's lookups, never the client's
		rest(w)
		local item = itemOf(w, "Pumpkin_SirGourdington")
		item.Id = "Pumpkin_SirHatsalot"
		item.Name = "Sir Hatsalot"
		item.Style.BodyColor = Color3.fromRGB(1, 1, 1)
		item.Style.Catalog = { Accessories = { { Id = 111, Type = "Hat" } } }
		local fake = { ["111"] = { Name = "Fake", Allowed = true, Creator = "Me" } }
		local answer = invoke(w, player, "Save", payload(w, item, { Lookups = fake }))
		if not answer.Ok then
			error(answer.Message)
		end
		expect(answer.Data.Lookups["111"].Name).toBe("Pumpkin Hat")
		expect(answer.Data.Lookups["111"].Creator).toBe("Roblox")
		rest(w)
		invoke(w, player, "Delete", answer.Data.DraftId)
		w.rt.productInfo = nil
	end)

	it("refuses a second lookup started while the first is still waiting", function()
		rest(w)
		w.rt.productInfo = {
			[333] = {
				Name = "Slow Hat",
				AssetTypeId = 8,
				Creator = { Name = "Roblox", CreatorTargetId = 1 },
			},
		}
		w.rt.productInfoDelay = 2
		local first = nil
		local callback = Dom.callback(w.Remote, "OnServerInvoke")
		w.rt.env.task.spawn(function()
			first = callback(player, "LookupAsset", 333)
		end)
		w.rt:advance(0.1)
		expect(first).toBeNil() -- still waiting for Roblox
		local second = invoke(w, player, "LookupAsset", 444)
		expect(second.Ok).toBe(false)
		expect(second.Message).toBe(w.Config.SkinStudio.Text.SlowDown)
		w.rt:advance(3)
		expect(first.Ok).toBe(true)
		w.rt.productInfoDelay = nil
		w.rt.productInfo = nil
	end)

	it("opens the panel from F8 on the first press, only for allowed players", function()
		rest(w)
		local command = w.rt:find("ReplicatedStorage.Remotes.AdminCommand")
		local ok, message = w.rt:invokeServer(command, player, "SkinStudio")
		expect(ok).toBe(true)
		expect(message).toBe(w.Config.SkinStudio.Text.Opened)
		expect(player:GetAttribute("SkinStudioOpenAt")).toBeA("number")
		local off = server({ studio = true }, function(C)
			C.Features.SkinStudio = false
		end)
		local kid = off.rt:addPlayer({ Name = "Kid" })
		off.rt:advance(3)
		local okOff, messageOff = off.rt:invokeServer(
			off.rt:find("ReplicatedStorage.Remotes.AdminCommand"),
			kid,
			"SkinStudio"
		)
		expect(okOff).toBe(true) -- the command ran...
		expect(messageOff).toBe(off.Config.SkinStudio.Text.NotAllowed) -- ...and said no
		expect(kid:GetAttribute("SkinStudioOpenAt")).toBeNil()
	end)

	it("prints every draft for Claude Code (Print for Claude)", function()
		rest(w)
		local item = w.Schema.NewItem("Spooky")
		item.Id = "Spooky_PrintMe"
		item.Name = "Print Me"
		local saved = invoke(w, player, "Save", payload(w, item))
		expect(saved.Ok).toBe(true)
		rest(w)
		local before = #w.rt.logs
		local answer = invoke(w, player, "PrintDrafts")
		expect(answer.Ok).toBe(true)
		expect(answer.Data.Pages).toBe(1)
		local printed = printedSince(w, before)
		expect(printed).toMatch((w.Config.SkinStudio.ExportMarkers.Begin:gsub("%p", "%%%0")))
		expect(printed).toMatch("Spooky_PrintMe")
		local again = invoke(w, player, "PrintDrafts")
		expect(again.Ok).toBe(false) -- PrintCooldown
		rest(w)
		invoke(w, player, "Delete", saved.Data.DraftId)
	end)

	it("forgets a player who leaves", function()
		rest(w)
		local guest = w.rt:addPlayer({ Name = "Guest" })
		w.rt:advance(3)
		invoke(w, guest, "Wear", payload(w, itemOf(w, "Pumpkin_BlazeJack")))
		expect(w.Shop.SkinOverride(guest)).toBeTruthy()
		w.rt:removePlayer(guest)
		w.rt:advance(1)
		expect(w.Shop.SkinOverride(guest)).toBeNil()
	end)
end)

describe("SkinStudioService with the DataStore", function()
	local function key(w: World): string
		return ("DataStore:%s:global"):format(w.Config.SkinStudio.DraftStore)
	end

	-- What the DataStore holds (decoded), or nil.
	local function stored(w: World): any
		local entry = w.rt.dataStores[key(w)]
		local text = entry and entry.data[w.Config.SkinStudio.DraftKey]
		return text and w.Http:JSONDecode(text)
	end

	local function storedText(w: World): string?
		local entry = w.rt.dataStores[key(w)]
		return entry and entry.data[w.Config.SkinStudio.DraftKey]
	end

	-- Puts `value` in the DataStore as another server would.
	local function seed(s: any, C: any, value: any)
		local ds = s.game:GetService("DataStoreService"):GetDataStore(C.SkinStudio.DraftStore)
		ds:SetAsync(C.SkinStudio.DraftKey, value)
	end

	local function record(w: World, id: string, skinId: string, updated: number): any
		local item = w.Schema.NewItem("Pumpkin")
		item.Id = skinId
		item.Name = skinId:sub(9)
		return { DraftId = id, Item = w.Schema.Encode(item), Updated = updated, Author = 1 }
	end

	local function withStore(C: any)
		C.SkinStudio.UseDataStore = true
	end

	it("starts without waiting, and says Loading until the drafts are read", function()
		local s = Runtime.new({ studio = true })
		local C = s:require("ReplicatedStorage.Shared.Config")
		withStore(C)
		s.dataStoreFailures = 2 -- a slow DataStore: two failed tries first
		local Service = s:require("ServerScriptService.Server.Services.SkinStudioService")
		s:require("ServerScriptService.Server.Services.AdminService").Start()
		local co = coroutine.create(function()
			Service.Start()
		end)
		local ok, err = coroutine.resume(co)
		if not ok then
			error(err)
		end
		expect(coroutine.status(co)).toBe("dead") -- Start never waited
		local player = s:addPlayer({ Name = "Kieran" })
		local remote = s:find("ReplicatedStorage.Remotes.SkinStudio")
		expect(s:invokeServer(remote, player, "Hello").Data.DataStore).toBe("Loading")
		s:advance(5)
		local hello = s:invokeServer(remote, player, "Hello")
		expect(hello.Data.DataStore).toBe("On")
	end)

	it("never touches the DataStore outside Studio, or with UseDataStore off", function()
		local live = server({ studio = false }, withStore)
		live.rt:advance(10)
		expect(live.rt.dataStores[key(live)]).toBeNil()
		local off = server({ studio = true })
		off.rt:advance(10)
		expect(off.rt.dataStores[key(off)]).toBeNil()
	end)

	it("writes once for many saves, at most every FlushSeconds", function()
		local w = server({ studio = true }, function(C)
			withStore(C)
			C.SkinStudio.SaveCooldown = 0
		end)
		local player = w.rt:addPlayer({ Name = "Kieran" })
		w.rt:advance(0.5)
		expect(invoke(w, player, "Hello").Data.DataStore).toBe("On")
		local writes, last = 0, storedText(w)
		local function tick(seconds: number)
			local steps = math.floor(seconds / 0.1 + 0.5)
			for _ = 1, steps do
				w.rt:advance(0.1)
				local now = storedText(w)
				if now ~= last then
					writes += 1
					last = now
				end
			end
		end
		local ids = {}
		for i = 1, 10 do
			local item = w.Schema.NewItem("Candy")
			item.Id = "Candy_Batch" .. string.char(64 + i)
			item.Name = "Batch " .. i
			local answer = invoke(w, player, "Save", payload(w, item))
			expect(answer.Ok).toBe(true)
			table.insert(ids, answer.Data.DraftId)
			tick(0.2)
		end
		tick(w.Config.SkinStudio.FlushSeconds)
		expect(writes).toBe(1)
		local seen = {}
		for _, id in ids do
			expect(seen[id]).toBeNil() -- every DraftId is new
			seen[id] = true
			expect(stored(w).Drafts[id]).toBeTruthy()
		end
		-- the next write waits for the next FlushSeconds
		invoke(w, player, "Delete", ids[1])
		tick(1)
		expect(writes).toBe(1)
		tick(w.Config.SkinStudio.FlushSeconds)
		expect(writes).toBe(2)
		expect(stored(w).Drafts[ids[1]].Deleted).toBe(true) -- a tombstone
	end)

	it("keeps a deleted draft deleted when merging, and forgets old tombstones", function()
		local w
		w = server({ studio = true }, function(C, s)
			withStore(C)
			local now = s.env.DateTime.now().UnixTimestampMillis
			local Schema = s:require("ReplicatedStorage.Shared.SkinSchema")
			local item = Schema.NewItem("Pumpkin")
			item.Id = "Pumpkin_Merged"
			item.Name = "Merged"
			seed(s, C, {
				Version = 2,
				Drafts = {
					KEEP = {
						DraftId = "KEEP",
						Item = Schema.Encode(item),
						Updated = now - 5000,
						Author = 1,
					},
					OLD = { DraftId = "OLD", Deleted = true, Updated = 0 },
				},
			})
		end)
		local player = w.rt:addPlayer({ Name = "Kieran" })
		w.rt:advance(0.5)
		local hello = invoke(w, player, "Hello")
		expect(#hello.Data.Drafts).toBe(1) -- loaded from the DataStore into the mirror
		expect(w.rt:find("ServerStorage.SkinStudioDrafts"):FindFirstChild("KEEP")).toBeTruthy()
		rest(w)
		expect(invoke(w, player, "Delete", "KEEP").Ok).toBe(true)
		-- meanwhile another server writes its older copy back
		local older = record(w, "KEEP", "Pumpkin_Merged", 10)
		seed(
			w.rt,
			w.Config,
			{
				Version = 2,
				Drafts = { KEEP = older, OLD = { DraftId = "OLD", Deleted = true, Updated = 0 } },
			}
		)
		w.rt:advance(w.Config.SkinStudio.FlushSeconds + 1)
		local value = stored(w)
		expect(value.Drafts.KEEP.Deleted).toBe(true)
		expect(value.Drafts.OLD).toBeNil()
	end)

	it("doesn't write a store that would be too big, and says so", function()
		local w = server({ studio = true }, function(C, s)
			withStore(C)
			C.SkinStudio.MaxStoreChars = 2500
			local Schema = s:require("ReplicatedStorage.Shared.SkinSchema")
			local drafts = {}
			for i = 1, 6 do
				local item = Schema.Copy(
					s:require("ReplicatedStorage.Shared.Items").Get("Pumpkin_SirGourdington")
				)
				item.Id = "Pumpkin_Other" .. string.char(64 + i)
				drafts["X" .. i] = {
					DraftId = "X" .. i,
					Item = Schema.Encode(item),
					Updated = 1e12 + i,
					Author = 1,
				}
			end
			seed(s, C, { Version = 2, Drafts = drafts })
		end)
		local player = w.rt:addPlayer({ Name = "Kieran" })
		w.rt:advance(0.5)
		-- (memory holds the 6 loaded drafts already, over the limit: Save refuses too)
		local before = storedText(w)
		local item = w.Schema.NewItem("Candy")
		item.Id = "Candy_TooMuch"
		item.Name = "Too Much"
		local answer = invoke(w, player, "Save", payload(w, item))
		expect(answer.Ok).toBe(false)
		expect(answer.Message).toBe(w.Config.SkinStudio.Text.TooManyDrafts)
		-- deleting marks the store dirty; the merged store is still too big for the write
		rest(w)
		invoke(w, player, "Delete", "X1")
		w.rt.dataStores[key(w)].data[w.Config.SkinStudio.DraftKey] = before -- another server again
		w.rt:advance(w.Config.SkinStudio.FlushSeconds + 1)
		expect(storedText(w)).toBe(before)
		expect(invoke(w, player, "Hello").Data.StoreProblem).toBe(
			w.Config.SkinStudio.Text.TooManyDrafts
		)
	end)

	it("still saves for the playtest when the DataStore fails", function()
		for _, broken in { "unpublished", "failing" } do
			local w = server({ studio = true, dataStores = broken ~= "unpublished" }, function(C, s)
				withStore(C)
				if broken == "failing" then
					s.dataStoreFailures = 50
				end
			end)
			local player = w.rt:addPlayer({ Name = "Kieran" })
			w.rt:advance(5)
			local status = invoke(w, player, "Hello").Data.DataStore
			expect(status).toBe(if broken == "unpublished" then "Off" else "Failed")
			rest(w)
			local item = w.Schema.NewItem("Pumpkin")
			item.Id = "Pumpkin_StillSaved"
			item.Name = "Still Saved"
			local answer = invoke(w, player, "Save", payload(w, item))
			expect(answer.Ok).toBe(true)
			expect(answer.Message).toBe(w.Config.SkinStudio.Text.Saved)
			expect(w.rt:find("ServerStorage.SkinStudioDrafts"):FindFirstChild(answer.Data.DraftId)).toBeTruthy()
		end
	end)

	it("writes the last changes when the server closes", function()
		local w = server({ studio = true }, withStore)
		local player = w.rt:addPlayer({ Name = "Kieran" })
		w.rt:advance(0.5)
		local item = w.Schema.NewItem("Pumpkin")
		item.Id = "Pumpkin_LastMinute"
		item.Name = "Last Minute"
		local answer = invoke(w, player, "Save", payload(w, item))
		expect(answer.Ok).toBe(true)
		expect(answer.Message).toBe(w.Config.SkinStudio.Text.SavedDataStore)
		expect(stored(w)).toBeNil() -- not written yet
		local before = #w.rt.logs
		w.rt:close()
		expect(stored(w).Drafts[answer.Data.DraftId]).toBeTruthy()
		-- and the Stop print-out is in Output
		expect(printedSince(w, before)).toMatch("Pumpkin_LastMinute")
	end)
end)

describe("SkinExport", function()
	it("pages drafts from the playtest mirror with checksums", function()
		local w = server({ studio = true }, function(C)
			C.SkinStudio.SaveCooldown = 0
			C.SkinStudio.ExportPageChars = 4000
		end)
		local player = w.rt:addPlayer({ Name = "Kieran" })
		w.rt:advance(3)
		local Export = w.rt:require("ServerScriptService.Server.Tools.SkinExport")
		local none = w.Http:JSONDecode(Export.Count())
		expect(none.From).toBe("None") -- no mirror yet (nothing saved)
		for i = 1, 6 do
			local item = itemOf(w, "Pumpkin_SirGourdington")
			item.Id = "Pumpkin_Page" .. string.char(64 + i)
			item.Name = "Page " .. i
			item.Style.BodyColor = Color3.fromRGB(i, i, i)
			expect(invoke(w, player, "Save", payload(w, item)).Ok).toBe(true)
		end
		local count = w.Http:JSONDecode(Export.Count())
		expect(count.From).toBe("Playtest")
		expect(count.Drafts).toBe(6)
		expect(count.Pages).toBeGreaterThan(1)
		local total = 0
		for page = 1, count.Pages do
			local text = Export.Json(page)
			expect(#text).toBeLessThanOrEqual(4000)
			local data = w.Http:JSONDecode(text)
			expect(data.Version).toBe(2)
			expect(data.Page).toBe(page)
			for _, draft in data.Drafts do
				expect(Export.Sum(draft.Text)).toBe(draft.Sum)
				expect(w.Http:JSONDecode(draft.Text).Item.Id).toMatch("^Pumpkin_Page")
				total += 1
			end
		end
		expect(total).toBe(6)
		expect(Export.Sum("hello")).toBe(1335831723) -- FNV-1a 32-bit of "hello"
		expect(Export.Sum("hellp")).never.toBe(Export.Sum("hello"))
	end)

	it(
		"reads the DataStore in edit mode, never exports deleted drafts, and makes nothing",
		function()
			local s = Runtime.new({ studio = true })
			local C = s:require("ReplicatedStorage.Shared.Config")
			C.SkinStudio.UseDataStore = true
			local Schema = s:require("ReplicatedStorage.Shared.SkinSchema")
			local item = Schema.NewItem("Pumpkin")
			item.Id = "Pumpkin_Kept"
			local ds = s.game:GetService("DataStoreService"):GetDataStore(C.SkinStudio.DraftStore)
			ds:SetAsync(C.SkinStudio.DraftKey, {
				Version = 2,
				Drafts = {
					A = { DraftId = "A", Item = Schema.Encode(item), Updated = 5, Author = 1 },
					B = { DraftId = "B", Deleted = true, Updated = 6 },
				},
			})
			local before = #s.game:GetDescendants()
			local Export = s:require("ServerScriptService.Server.Tools.SkinExport")
			local Http = s.game:GetService("HttpService")
			local count = Http:JSONDecode(Export.Count())
			expect(count.From).toBe("DataStore")
			expect(count.Drafts).toBe(1)
			local page = Http:JSONDecode(Export.Json(1))
			expect(Http:JSONDecode(page.Drafts[1].Text).Item.Id).toBe("Pumpkin_Kept")
			expect(#s.game:GetDescendants()).toBe(before)
			expect(s.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")).toBeNil()
		end
	)
end)
