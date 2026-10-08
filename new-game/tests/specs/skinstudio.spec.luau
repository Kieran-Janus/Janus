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
		-- animation lists are written one effect per line, marked like the theme files do
		local animated = rare()
		animated.Style.Animate =
			{ { Effect = "Bob", Target = "Head" }, { Effect = "Wobble", Speed = 2 } }
		expect(Schema.ToLuau(animated)).toMatch(
			"\n\t\t\t} :: { any }, %-%- %(effects differ in shape%)"
		)
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
		item.Style.Motion = "Robot"
		local answer = invoke(w, player, "Wear", payload(w, item))
		expect(answer.Ok).toBe(true)
		expect(answer.Data.WornId).toBe("StudioDraft_U" .. player.UserId)
		local model = player.Character:FindFirstChild("Cosmetic_Skin")
		expect(model).toBeInstanceOf("Model")
		expect(model:GetAttribute("ItemId")).toBe(answer.Data.WornId)
		-- every screen animates the draft's own effects (LiveStyle) and walks its walk style
		local SkinAnimate = w.rt:require("ReplicatedStorage.Shared.SkinAnimate")
		local live = SkinAnimate.DecodeLive(model:GetAttribute("LiveStyle"))
		expect(#live.Animate).toBe(#item.Style.Animate)
		expect(live.Animate[1].Effect).toBe(item.Style.Animate[1].Effect)
		expect(w.rt.game:GetService("CollectionService"):HasTag(model, "SkinAnim")).toBe(true)
		expect(player.Character:GetAttribute("SkinMotion")).toBe("Robot")
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
			[444] = {
				Name = "Group Wings",
				AssetTypeId = 46, -- BackAccessory
				Creator = { Name = "Our Group", CreatorType = "Group", CreatorTargetId = 77 },
			},
		}
		local roblox = invoke(w, player, "LookupAsset", 111)
		expect(roblox.Ok).toBe(true)
		expect(roblox.Data.Name).toBe("Pumpkin Hat")
		expect(roblox.Data.AssetType).toBe("Hat")
		expect(roblox.Data.Type).toBe("Hat") -- SkinCatalog.TypeFromAssetType
		expect(roblox.Data.RobloxMade).toBe(true)
		expect(roblox.Data.Allowed).toBe(true)
		rest(w)
		local other = invoke(w, player, "LookupAsset", 222)
		expect(other.Data.Allowed).toBe(false)
		expect(other.Data.Problem).toBeA("string")
		-- a group listed in Config.SkinCatalog.AllowedCreators is allowed (SkinCatalog.CreatorAllowed)
		rest(w)
		local groups = (w.Config :: any).SkinCatalog.AllowedCreators.GroupIds
		table.insert(groups, 77)
		local group = invoke(w, player, "LookupAsset", 444)
		table.remove(groups, table.find(groups, 77))
		expect(group.Data.Allowed).toBe(true)
		expect(group.Data.Type).toBe("Back")
		expect(group.Data.RobloxMade).toBe(false)
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
		seed(w.rt, w.Config, {
			Version = 2,
			Drafts = { KEEP = older, OLD = { DraftId = "OLD", Deleted = true, Updated = 0 } },
		})
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

-- Client ------------------------------------------------------------------------------------------

describe("SkinStudioState", function()
	local client = Runtime.new({ client = true })
	local State = client:require("StarterPlayer.StarterPlayerScripts.Client.SkinStudioState")
	local CItems = client:require("ReplicatedStorage.Shared.Items")
	local CConfig = client:require("ReplicatedStorage.Shared.Config")

	it("undoes, redoes, resets and groups a drag into one step", function()
		local state = State.new(CItems.Get("Pumpkin_BlazeJack"), "Pumpkin_BlazeJack")
		local changes = 0
		state.Changed:Connect(function()
			changes += 1
		end)
		expect(state:Dirty()).toBe(false)
		expect(state:CanUndo()).toBe(false)
		state:Set({ "Name" }, "Blaze Jack Two")
		state:Set({ "Style", "Glow", "Brightness" }, 4)
		expect(state:Peek().Style.Glow.Brightness).toBe(4)
		expect(state:Dirty()).toBe(true)
		-- a slider drag: many Sets, one step
		state:Begin()
		for x = 1, 10 do
			state:Set({ "Style", "Glow", "Range" }, x)
		end
		state:Commit()
		expect(#state.History).toBe(3)
		state:Undo()
		expect(state:Peek().Style.Glow.Range).toBe(nil)
		state:Undo()
		expect(state:Peek().Style.Glow.Brightness).toBe(2)
		state:Redo()
		expect(state:Peek().Style.Glow.Brightness).toBe(4)
		state:Reset()
		expect(state:Peek().Name).toBe("Blaze Jack")
		expect(state:Dirty()).toBe(false)
		state:Undo() -- Reset can be undone too
		expect(state:Peek().Name).toBe("Blaze Jack Two")
		state:MarkSaved()
		expect(state:Dirty()).toBe(false)
		expect(changes).toBeGreaterThan(5)
		-- setting the same value is not a step
		local before = #state.History
		state:Set({ "Name" }, "Blaze Jack Two")
		expect(#state.History).toBe(before)
		-- Get is a copy
		state:Get().Name = "Changed"
		expect(state:Peek().Name).toBe("Blaze Jack Two")
	end)

	it("remembers at most UndoSteps changes", function()
		local state = State.new(CItems.Get("Pumpkin_BlazeJack"), nil)
		for i = 1, CConfig.SkinStudio.UndoSteps + 10 do
			state:Set({ "Style", "Glow", "Brightness" }, i / 100)
		end
		expect(#state.History).toBe(CConfig.SkinStudio.UndoSteps)
	end)
end)

-- A client with a stand-in server (the remote's OnServerInvoke) and the Menu mounted.
type ClientWorld = {
	rt: any,
	Config: any,
	UI: any,
	Menu: any,
	Panels: any,
	Schema: any,
	gui: any,
	calls: { string },
	drafts: { any },
	reply: { [string]: any },
}

local function clientWorld(options: {
	admin: boolean?,
	remote: boolean?,
	phone: boolean?,
	off: boolean?,
	size: any?,
}): ClientWorld
	local c = Runtime.new({ client = true, studio = true })
	local C = c:require("ReplicatedStorage.Shared.Config")
	if options.off then
		C.Features.SkinStudio = false
	end
	local world: ClientWorld = {
		rt = c,
		Config = C,
		UI = nil,
		Menu = nil,
		Panels = nil,
		Schema = c:require("ReplicatedStorage.Shared.SkinSchema"),
		gui = nil,
		calls = {},
		drafts = {},
		reply = {},
	}
	if options.remote ~= false then
		local folder = c:create("Folder", { Name = "Remotes" }, c:find("ReplicatedStorage"))
		local remote = c:create("RemoteFunction", { Name = "SkinStudio" }, folder)
		remote.OnServerInvoke = function(_player, action, payload)
			table.insert(world.calls, action)
			local custom = world.reply[action]
			if custom then
				return custom(payload)
			end
			if action == "Hello" then
				return {
					Ok = true,
					Message = "",
					Data = { DataStore = "Off", Drafts = world.drafts },
				}
			elseif action == "Save" then
				local body = c.game:GetService("HttpService"):JSONDecode(payload)
				local record = {
					DraftId = "D" .. #world.calls,
					Item = body.Item,
					Source = body.Source,
					Updated = 1,
					Author = 1,
				}
				return { Ok = true, Message = C.SkinStudio.Text.Saved, Data = record }
			end
			return { Ok = true, Message = "ok", Data = {} }
		end
	end
	if options.admin ~= false then
		c.localPlayer:SetAttribute("Admin", true)
	end
	local gui =
		c:create("ScreenGui", { Name = "GameUI" }, c.localPlayer:FindFirstChildOfClass("PlayerGui"))
	if options.phone then
		gui:SetAttribute("ForceTouch", true)
	end
	if options.size then
		Dom.rawSet(gui, "AbsoluteSize", options.size)
	end
	local folder = c:find("StarterPlayer.StarterPlayerScripts.Client")
	c:require(folder.Layout).Mount(gui)
	world.Panels = c:require(folder.PanelManager)
	world.Panels.Mount(gui)
	world.Menu = c:require(folder.MenuUI)
	world.Menu.Mount(gui)
	world.UI = c:require(folder.SkinStudioUI)
	world.gui = gui
	local co = coroutine.create(function()
		world.UI.Mount(gui)
	end)
	assert(coroutine.resume(co))
	expect(coroutine.status(co)).toBe("dead") -- Mount never waits
	c:advance(0.5)
	return world
end

local function count(list: { string }, what: string): number
	local n = 0
	for _, v in list do
		if v == what then
			n += 1
		end
	end
	return n
end

local function panelOf(w: ClientWorld): any
	return w.gui:FindFirstChild("SkinStudio")
end

local function rows(w: ClientWorld): { any }
	local out = {}
	local list = panelOf(w).Content:FindFirstChild("List")
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") and child.Name:sub(1, 4) == "Row_" then
			table.insert(out, child)
		end
	end
	return out
end

local function liveConnections(c: any): number
	local n = 0
	for _, value in c.listening do
		n += value
	end
	return n
end

describe("SkinStudioUI", function()
	it("shows nothing when switched off, and never waits on a missing remote", function()
		local off = clientWorld({ off = true })
		off.Menu.Open()
		expect(off.gui.Menu.Tiles:FindFirstChild("SkinStudioTile")).toBeNil()
		off.UI.Open()
		expect(panelOf(off)).toBeNil()
		-- on, but the server never made the remote: the panel opens and says so
		local lonely = clientWorld({ remote = false })
		lonely.UI.Open()
		expect(panelOf(lonely).Visible).toBe(true)
		lonely.rt:advance(25)
		expect(panelOf(lonely).Footer.Status.Text).toBe(lonely.Config.SkinStudio.Text.NoRemote)
		expect(#lonely.rt.errors).toBe(0)
	end)

	it("shows the Menu tile to admins only", function()
		local admin = clientWorld({})
		admin.Menu.Open()
		expect(admin.gui.Menu.Tiles.SkinStudioTile.Visible).toBe(true)
		local player = clientWorld({ admin = false })
		player.Menu.Open()
		expect(player.gui.Menu.Tiles.SkinStudioTile.Visible).toBe(false)
		player.UI.Open()
		expect(panelOf(player)).toBeNil()
	end)

	it("opens on the first F8 press (the SkinStudioOpenAt attribute)", function()
		local w = clientWorld({})
		w.rt.localPlayer:SetAttribute("SkinStudioOpenAt", 12)
		w.rt:advance(0.2)
		expect(panelOf(w).Visible).toBe(true)
	end)

	local w = clientWorld({})
	w.drafts = {
		{
			DraftId = "A1",
			SkinId = "Pumpkin_DraftOne",
			Name = "Draft One",
			Theme = "Pumpkin",
			Rarity = "Common",
			Updated = 2,
			InGameFiles = false,
		},
		{
			DraftId = "B2",
			SkinId = "Candy_DraftTwo",
			Name = "Draft Two",
			Theme = "Candy",
			Rarity = "Rare",
			Updated = 1,
			InGameFiles = false,
		},
		{
			DraftId = "C3",
			SkinId = "Pumpkin_Gourdy",
			Name = "Gourdy",
			Theme = "Pumpkin",
			Rarity = "Common",
			Source = "Pumpkin_Gourdy",
			Updated = 0,
			InGameFiles = true,
		},
	}

	it("searches and filters the skin list", function()
		w.UI.Open()
		w.rt:advance(0.5)
		local panel = panelOf(w)
		expect(panel.Visible).toBe(true)
		expect(#rows(w)).toBe(w.Config.SkinStudio.ListPageSize)
		panel.Content.SearchLine.Search.Text = "gourd"
		w.rt:advance(0.1)
		local found = rows(w)
		expect(#found).toBeGreaterThan(1)
		for _, r in found do
			expect(r.Text:lower()).toMatch("gourd")
		end
		panel.Content.SearchLine.Search.Text = ""
		w.rt:fire(panel.Content.RarityLine.Rarity_Crazy, "Activated")
		local crazy = rows(w)
		expect(#crazy).toBeGreaterThan(5)
		w.rt:fire(panel.Content.RarityLine.Rarity_Any, "Activated")
		w.rt:fire(panel.Content.ToggleLine.DraftsFilter, "Activated")
		expect(#rows(w)).toBe(3) -- the three drafts
		w.rt:fire(panel.Content.ToggleLine.DraftsFilter, "Activated")
		-- the theme dropdown
		w.rt:fire(panel.Content.ThemeLine.ThemeFilter, "Activated")
		w.rt:fire(panel.Popover.Body.Items.Theme_Candy, "Activated")
		expect(panel:FindFirstChild("Popover")).toBeNil()
		for _, r in rows(w) do
			expect(r.Text).toMatch("Candy")
		end
		w.rt:fire(panel.Content.ThemeLine.ThemeFilter, "Activated")
		w.rt:fire(panel.Popover.Body.Items.Theme_All, "Activated")
		-- the banner counts the two drafts not in the game files
		expect(panel.Footer.Banner.Text).toMatch("2 drafts")
	end)

	it("wears once after a burst of edits", function()
		w.UI.SelectSkin("Pumpkin_BlazeJack")
		w.rt:advance(1)
		local before = count(w.calls, "Wear")
		expect(before).toBe(1) -- picking a skin wears it (Wear on me is on)
		local state = w.UI.Current()
		for i = 1, 6 do
			state:Set({ "Style", "Glow", "Brightness" }, 1 + i / 10)
			w.rt:advance(0.05)
		end
		w.rt:advance(1)
		expect(count(w.calls, "Wear") - before).toBe(1)
	end)

	it("undoes, redoes and resets from the footer", function()
		local panel = panelOf(w)
		local state = w.UI.Current()
		state:Set({ "Name" }, "Blaze Jack Remix")
		w.rt:fire(panel.Footer.Buttons.Undo, "Activated")
		expect(state:Peek().Name).toBe("Blaze Jack")
		w.rt:fire(panel.Footer.Buttons.Redo, "Activated")
		expect(state:Peek().Name).toBe("Blaze Jack Remix")
		w.rt:fire(panel.Footer.Buttons.Reset, "Activated")
		expect(state:Peek().Name).toBe("Blaze Jack")
		expect(state:Peek().Style.Glow.Brightness).toBe(2)
	end)

	it("keeps the work, the history and the tab when closed by accident", function()
		local state = w.UI.Current()
		state:Set({ "Name" }, "Blaze Jack Keeper")
		w.UI.ShowTab("Look")
		w.rt:advance(1)
		local steps = #state.History
		local stops = count(w.calls, "StopWearing")
		expect(w.Panels.CloseTop()).toBe(true) -- Escape
		w.rt:advance(0.5)
		expect(panelOf(w).Visible).toBe(false)
		expect(w.gui:FindFirstChild("SkinStudioToast")).toBeTruthy()
		expect(count(w.calls, "StopWearing")).toBe(stops) -- still wearing it
		w.UI.Open()
		w.rt:advance(0.5)
		expect(w.UI.Current()).toBe(state)
		expect(#state.History).toBe(steps)
		expect(state:Peek().Name).toBe("Blaze Jack Keeper")
		expect(panelOf(w).Content:FindFirstChild("Section_Basics")).toBeTruthy() -- the Look tab
		expect(panelOf(w).Footer.Banner.Text).toMatch(w.Config.SkinStudio.Text.Unsaved)
	end)

	it("locks the rarity of a skin players own until unlocked", function()
		local panel = panelOf(w)
		w.UI.ShowTab("Look")
		local rarity = panel.Content:FindFirstChild("Field_Rarity")
		expect(rarity.Control:FindFirstChild("Lock")).toBeTruthy()
		expect(panel.Content:FindFirstChild("Field_Id")).toBeNil() -- the Id is fixed
		w.rt:fire(panel.Content.Unlock, "Activated")
		w.rt:fire(panel.Popover.Body.Items.Yes, "Activated")
		w.rt:advance(0.2)
		rarity = panel.Content:FindFirstChild("Field_Rarity")
		expect(rarity.Control:FindFirstChild("Lock")).toBeNil()
		expect(w.UI.Current().UnlockEconomy).toBe(true)
		-- a new skin has its Id and economy free
		w.UI.New()
		w.rt:advance(0.2)
		expect(panel.Content:FindFirstChild("Field_Id")).toBeTruthy()
		expect(panel.Content.Field_Rarity.Control:FindFirstChild("Lock")).toBeNil()
	end)

	it("copies exactly the code ToLuau writes, and saves", function()
		local panel = panelOf(w)
		w.UI.SelectSkin("Pumpkin_SirGourdington")
		w.UI.ShowTab("Save")
		w.rt:fire(panel.Content.SaveButtons.CopyCode, "Activated")
		local box = panel.Popover.Body.Items.CopyCode
		expect(box.Text).toBe(w.Schema.ToLuau(w.UI.Current():Get()))
		box.Text = "typed over"
		w.rt:fire(box, "FocusLost")
		expect(box.Text).toBe(w.Schema.ToLuau(w.UI.Current():Get()))
		w.UI.Current():Set({ "Name" }, "Sir Saved")
		w.rt:fire(panel.Content.SaveButtons.Save, "Activated")
		w.rt:advance(0.5)
		expect(count(w.calls, "Save")).toBe(1)
		expect(w.UI.Current().DraftId).toBeA("string")
		expect(w.UI.Current():Dirty()).toBe(false)
	end)

	it("builds every tab", function()
		w.UI.SelectSkin("Pumpkin_MegaGourdSupreme")
		for _, name in { "Skins", "Look", "Animate", "Catalog", "Save" } do
			w.UI.ShowTab(name)
			w.rt:advance(0.3)
			expect(#panelOf(w).Content:GetChildren()).toBeGreaterThan(2)
		end
		expect(#w.rt.errors).toBe(0)
	end)

	it("edits animations, walk styles and catalog items", function()
		local panel = panelOf(w)
		w.UI.SelectSkin("Pumpkin_BlazeJack") -- Rare: up to 3 animations
		w.UI.ShowTab("Animate")
		w.rt:advance(0.3)
		local state = w.UI.Current()
		state:Set({ "Style", "Animate" }, nil)
		w.rt:advance(0.1)
		w.rt:fire(panel.Content.Effects.AddAnimation, "Activated")
		w.rt:advance(0.3)
		expect(#state:Peek().Style.Animate).toBe(1)
		local card = panel.Content.Effects.Effect1
		w.rt:fire(card.Effect.Control.Pick, "Activated")
		w.rt:fire(panel.Popover.Body.Items.Option_Wobble, "Activated")
		w.rt:advance(0.1)
		expect(state:Peek().Style.Animate[1].Effect).toBe("Wobble")
		expect((w.Schema.Validate(state:Get()))).toBe(true)
		w.rt:fire(panel.Content.Effects.Effect1.Title.RemoveEffect, "Activated")
		w.rt:advance(0.1)
		expect(state:Peek().Style.Animate).toBeNil()
		-- the walk style
		w.rt:fire(panel.Content.Motion.Preset.Control.Pick, "Activated")
		w.rt:fire(panel.Popover.Body.Items.Option_Zombie, "Activated")
		w.rt:advance(0.1)
		expect(state:Peek().Style.Motion).toBe("Zombie")
		-- a CRAZY skin can't colour its rainbow accents: the target is greyed with the reason
		w.UI.SelectSkin("Pumpkin_MegaGourdSupreme")
		w.UI.ShowTab("Animate")
		local crazy = w.UI.Current()
		crazy:Set({ "Style", "Animate" }, { { Effect = "Shimmer", Target = "Head" } })
		w.rt:advance(0.3)
		w.rt:fire(panel.Content.Effects.Effect1.Target.Control.Pick, "Activated")
		local accents = panel.Popover.Body.Items.Option_Accents
		expect(accents.Text).toMatch("CRAZY Rainbow")
		w.rt:fire(accents, "Activated")
		expect(crazy:Peek().Style.Animate[1].Target).toBe("Head")
		-- a Common skin can't animate: the button says why
		w.UI.SelectSkin("Pumpkin_CandleKid")
		w.UI.ShowTab("Animate")
		w.rt:advance(0.2)
		w.rt:fire(panel.Content.Effects.AddAnimation, "Activated")
		expect(w.UI.Current():Peek().Style.Animate).toBeNil()
		expect(panel.Footer.Status.Text).toMatch("Common")
		-- catalog items: looked up on the server, refused when the creator isn't allowed
		w.UI.SelectSkin("Pumpkin_BlazeJack")
		w.UI.ShowTab("Catalog")
		w.rt:advance(0.2)
		w.reply.LookupAsset = function(id)
			local allowed = id == 111
			return {
				Ok = true,
				Message = "",
				Data = {
					Name = if allowed then "Pumpkin Hat" else "Someone's Hat",
					Type = "Hat",
					AssetType = "Hat",
					Creator = if allowed then "Roblox" else "Someone",
					CreatorType = "User",
					CreatorId = if allowed then 1 else 999,
					RobloxMade = allowed,
					Allowed = allowed,
					Problem = if allowed then nil else w.Config.SkinStudio.Text.NotAllowedCreator,
				},
			}
		end
		panel.Content.Catalog.AddItem.IdBox.Text = "111"
		w.rt:fire(panel.Content.Catalog.AddItem.LookUp, "Activated")
		w.rt:advance(0.3)
		local catalog = w.UI.Current():Peek().Style.Catalog
		expect(catalog.Accessories[1].Id).toBe(111)
		expect(catalog.Accessories[1].Type).toBe("Hat")
		panel.Content.Catalog.AddItem.IdBox.Text = "222"
		w.rt:fire(panel.Content.Catalog.AddItem.LookUp, "Activated")
		w.rt:advance(0.3)
		expect(#w.UI.Current():Peek().Style.Catalog.Accessories).toBe(1)
		expect(panel.Footer.Status.Text).toBe(w.Config.SkinStudio.Text.NotAllowedCreator)
		w.reply.LookupAsset = nil
		w.UI.Current():Reset()
	end)

	it("animates the header preview like a worn skin (SkinFx / SkinAnim)", function()
		w.UI.Open()
		w.UI.SelectSkin("Candy_BubblegumBat") -- Flap on its wings
		w.rt:advance(0.5)
		local viewport = panelOf(w).Header.Preview
		local model = viewport:FindFirstChildOfClass("Model")
		expect(model).toBeTruthy()
		local wing: Model? = nil
		for _, d in model:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("AnimGroup") == "WingL" then
				wing = d
			end
		end
		assert(wing, "the preview has a moving left wing")
		local function angle(): number
			local rel = model:GetPivot():ToObjectSpace(wing:GetPivot())
			local x, y, z = rel:ToEulerAnglesXYZ()
			return x + y + z
		end
		local seen: { [number]: boolean } = {}
		local count = 0
		for _ = 1, 12 do
			w.rt:advance(0.07)
			local a = math.floor(angle() * 100 + 0.5)
			if not seen[a] then
				seen[a] = true
				count += 1
			end
		end
		expect(count >= 3).toBe(true)
		-- a change rebuilds it: the old model is gone and the new one is animated
		w.UI.Current():Set({ "Style", "Animate" }, nil)
		w.rt:advance(0.5)
		expect(model.Parent).toBeNil()
		expect(viewport:FindFirstChildOfClass("Model")).toBeTruthy()
		w.UI.Current():Reset()
		w.rt:advance(0.5)
	end)

	it("circles your character with the turntable and gives the camera back", function()
		local panel = panelOf(w)
		local camera = w.rt.workspace.CurrentCamera
		w.rt:fire(panel.Footer.Buttons.Turntable, "Activated")
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		w.rt:advance(0.1)
		local first = camera.CFrame
		w.rt:advance(1)
		expect((camera.CFrame.Position - first.Position).Magnitude).toBeGreaterThan(0.1)
		w.rt:fire(panel.Footer.Buttons.Turntable, "Activated")
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
		expect(camera.CameraSubject).toBe(
			w.rt.localPlayer.Character:FindFirstChildOfClass("Humanoid")
		)
		-- closing stops it too
		w.rt:fire(panel.Footer.Buttons.Turntable, "Activated")
		w.UI.Close()
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
	end)

	it("can open and close many times without leaking", function()
		w.UI.Open()
		w.rt:advance(1)
		w.UI.Close()
		w.rt:advance(8)
		local instances = #w.rt.game:GetDescendants()
		local connections = liveConnections(w.rt)
		for _ = 1, 20 do
			w.UI.Open()
			w.rt:advance(0.3)
			w.UI.Close()
			w.rt:advance(0.3)
		end
		w.rt:advance(8)
		expect(#w.rt.game:GetDescendants()).toBe(instances)
		expect(liveConnections(w.rt)).toBe(connections)
	end)

	for _, size in { "upright", "on its side" } do
		it("is a bottom sheet with big buttons on phones (no shrinking), " .. size, function()
			local phone = clientWorld({
				phone = true,
				size = if size == "upright" then nil else env.Vector2.new(844, 390),
			})
			phone.UI.Open()
			phone.UI.SelectSkin("Pumpkin_MegaGourdSupreme")
			phone.rt:advance(0.5)
			local panel = panelOf(phone)
			expect(panel.AnchorPoint.Y).toBe(1)
			expect(panel.Size.Y.Scale).toBeNear(
				phone.Config.SkinStudio.Panel.PhoneHeightScale,
				1e-4
			)
			expect(panel:FindFirstChild("FitScale")).toBeNil()
			expect(panel.Header:FindFirstChild("Preview")).toBeNil() -- your real character is above
			-- on its side: tabs in one row on top, the buttons and Wear on me in one row below
			local wide = size ~= "upright"
			expect(panel.Footer.Buttons:FindFirstChild("WearOnMe") ~= nil).toBe(wide)
			expect(panel:FindFirstChildOfClass("UISizeConstraint").MinSize.Y).toBe(
				phone.Config.SkinStudio.Panel.PhoneMinHeight
			)
			for _, tabName in { "Skins", "Look", "Animate", "Catalog", "Save" } do
				expect(panel.Tabs:FindFirstChild("Tab_" .. tabName)).toBeTruthy()
				phone.UI.ShowTab(tabName)
				phone.rt:advance(0.2)
				for _, d in panel:GetDescendants() do
					if not (d:IsA("TextButton") or d:IsA("TextBox")) then
						continue
					end
					local size = d.Size
					local tall = size.Y.Offset >= 44
					local parent = d.Parent
					if not tall and size.Y.Scale >= 1 and parent:IsA("GuiObject") then
						tall = parent.Size.Y.Offset >= 44
					end
					local grid = parent:FindFirstChildOfClass("UIGridLayout")
					if not tall and grid then
						tall = grid.CellSize.Y.Offset >= 44
					end
					if not tall and d.Name == "CopyCode" then
						tall = true -- the code box grows with its text
					end
					if not tall then
						error(
							("%s on the %s tab is under 44 px tall"):format(
								d:GetFullName(),
								tabName
							)
						)
					end
				end
			end
			-- no header preview on phones, yet the head piece's own parts are still targets
			phone.UI.ShowTab("Animate")
			phone.UI.Current():Set({ "Style", "Animate" }, { { Effect = "Spin", Target = "Head" } })
			phone.rt:advance(0.3)
			phone.rt:fire(panel.Content.Effects.Effect1.Target.Control.Pick, "Activated")
			local items = panel.Popover.Body.Items
			expect(items:FindFirstChild("Option_Part:Crown")).toBeTruthy()
			expect(items:FindFirstChild("Option_Part:MiniPumpkin")).toBeTruthy()
			phone.UI.Current():Reset()
		end)
	end
end)

-- The save-skins tool ---------------------------------------------------------------------------------

describe("save-skins (tests/tools/SkinFile.luau)", function()
	local fs = require("@lune/fs")
	local serde = require("@lune/serde")
	local SkinFile = require("../tools/SkinFile")
	local root = if fs.isDir("src") then "" else "new-game/"

	local w = server({ studio = true }, function(C)
		C.SkinStudio.SaveCooldown = 0
	end)
	local player = w.rt:addPlayer({ Name = "Kieran" })
	w.rt:advance(3)
	local Export = w.rt:require("ServerScriptService.Server.Tools.SkinExport")
	local WItems = w.rt:require("ReplicatedStorage.Shared.Items")

	local function readTheme(theme: string): string
		return fs.readFile(root .. "src/shared/Config/Skins/" .. theme .. ".luau")
	end

	local function deps(): any
		return {
			Schema = w.Schema,
			Export = Export,
			Config = w.Config,
			Items = WItems,
			Decode = function(text: string): any
				return serde.decode("json", text)
			end,
			ReadTheme = readTheme,
		}
	end

	-- The server's export pages, as /save-skins would read them.
	local function exported(): { any }
		local count = serde.decode("json", Export.Count())
		local out = {}
		for p = 1, count.Pages do
			table.insert(out, serde.decode("json", Export.Json(p)))
		end
		return out
	end

	-- A page made by hand from records (checksums worked out the same way).
	local function page(records: { any }): any
		local drafts = {}
		for _, record in records do
			local text = serde.encode("json", record)
			table.insert(drafts, { Sum = Export.Sum(text), Text = text })
		end
		return { Version = 2, From = "Playtest", Page = 1, Pages = 1, Drafts = drafts }
	end

	-- The file's lines without the header line and without these entries.
	local function rest(text: string, ids: { string }): string
		local lines = {}
		for line in (text .. "\n"):gmatch("(.-)\n") do
			table.insert(lines, line)
		end
		local skip: { [number]: boolean } = { [3] = true }
		for _, id in ids do
			local first, last = SkinFile.Find(text, id)
			if first then
				for i = first :: number, last :: number do
					skip[i] = true
				end
			end
		end
		local out = {}
		for i, line in lines do
			if not skip[i] then
				table.insert(out, line)
			end
		end
		return table.concat(out, "\n")
	end

	it("counts a theme file's skins", function()
		local counts = SkinFile.Counts(readTheme("Pumpkin"))
		expect(counts.Total).toBe(20)
		expect(counts.Common).toBe(12)
		expect(counts.Uncommon).toBe(5)
		expect(counts.Rare).toBe(2)
		expect(counts.Crazy).toBe(1)
		local million = SkinFile.Counts(readTheme("AlienAbduction"))
		expect(million.Million).toBe(1)
		expect(million.Crazy).toBe(0)
		expect(million.Total).toBe(22)
		expect(SkinFile.HasLocals(readTheme("Pumpkin"))).toBe(true)
	end)

	it("replaces an entry and adds one after its rarity, leaving every other byte alone", function()
		local edited = itemOf(w, "Pumpkin_BlazeJack")
		edited.Style.BodyColor = Color3.fromRGB(12, 34, 56)
		edited.Name = "Blaze Jack Deluxe"
		expect(invoke(w, player, "Save", payload(w, edited, { Source = "Pumpkin_BlazeJack" })).Ok).toBe(
			true
		)
		local new = itemOf(w, "Pumpkin_SirGourdington")
		new.Id = "Pumpkin_SirTestalot"
		new.Name = "Sir Testalot"
		new.Style.TorsoColor = Color3.fromRGB(200, 100, 50)
		local saved = invoke(w, player, "Save", payload(w, new))
		if not saved.Ok then
			error(saved.Message)
		end
		local plan = SkinFile.Plan(exported(), deps())
		expect(plan.Damaged).toBeNil()
		if #plan.Refused > 0 then
			error(plan.Refused[1].Id .. ": " .. plan.Refused[1].Why)
		end
		local file = plan.Files.Pumpkin
		expect(#file.Changes).toBe(2)
		local before, after = file.Before, file.After
		-- the new Rare comes straight after the last Rare
		local _, lastRare = SkinFile.Find(after, "Pumpkin_BlazeJack")
		local newFirst = SkinFile.Find(after, "Pumpkin_SirTestalot")
		expect(newFirst).toBe((lastRare :: number) + 1)
		-- nothing else changed
		expect(rest(after, { "Pumpkin_BlazeJack", "Pumpkin_SirTestalot" })).toBe(
			rest(before, { "Pumpkin_BlazeJack" })
		)
		expect(after).toMatch(
			"PUMPKIN CRATE SKINS %(21%): 12 Common, 5 Uncommon, 3 Rare, 1 CRAZY%."
		)
		expect(file.CountsAfter.Rare).toBe(3)
		-- and the file still loads, with both skins exactly as drafted
		local fn = luau.load(after, {
			environment = { rgb = Color3.fromRGB, M = Enum.Material, Color3 = Color3, Enum = Enum },
		})
		local list = fn()
		local found = 0
		for _, entry in list do
			local want = if entry.Id == "Pumpkin_BlazeJack"
				then edited
				elseif entry.Id == "Pumpkin_SirTestalot" then new
				else nil
			if want then
				found += 1
				entry.Slot = "Skin"
				entry.Theme = "Pumpkin"
				entry.Crate = entry.Crate or "PumpkinCrate"
				entry.Style.Kind = "Skin"
				if entry.Style.HideClothes == nil then
					entry.Style.HideClothes = true
				end
				expect(w.Schema.Same(entry, want)).toBe(true)
			end
		end
		expect(found).toBe(2)
		-- a Windows (CRLF) file keeps its line endings
		local crlf = before:gsub("\n", "\r\n")
		local replaced =
			SkinFile.Replace(crlf, "Pumpkin_Gourdy", '\t{\n\t\tId = "Pumpkin_Gourdy",\n\t},')
		expect((replaced :: string):find("[^\r]\n")).toBeNil()
	end)

	it("refuses renamed Ids, taken Ids, twins, Classic skins and unapproved catalog ids", function()
		local function record(item: any, extra: { [string]: any }?): any
			local r: { [string]: any } = {
				DraftId = tostring(math.random(1, 1e9)),
				Item = w.Schema.Encode(item),
				Updated = 1,
				Author = 1,
			}
			for k, v in extra or {} do
				r[k] = v
			end
			return r
		end
		local renamed = itemOf(w, "Pumpkin_BlazeJack")
		renamed.Id = "Pumpkin_BlazeJackier"
		local taken = w.Schema.NewItem("Pumpkin")
		taken.Id = "Pumpkin_Gourdy" -- already a skin, and this draft doesn't edit it
		taken.Name = "Not Gourdy"
		local twin = w.Schema.NewItem("Candy")
		twin.Id = "Candy_Twin"
		twin.Name = "Twin"
		local classic = itemOf(w, "Zombie")
		local hat = itemOf(w, "Pumpkin_SirGourdington")
		hat.Id = "Pumpkin_HatTrick"
		hat.Name = "Hat Trick"
		hat.Style.TorsoColor = Color3.fromRGB(9, 9, 9)
		hat.Style.Catalog = { Accessories = { { Id = 1234567890, Type = "Hat" } } }
		local lookups = {
			["1234567890"] = {
				Name = "Top Hat",
				Creator = "Someone",
				CreatorType = "User",
				CreatorId = 999,
			},
		}
		local plan = SkinFile.Plan({
			page({
				record(renamed, { Source = "Pumpkin_BlazeJack" }),
				record(taken),
				record(twin),
				record(twin),
				record(classic, { Source = "Zombie" }),
				record(hat, { Lookups = lookups }),
			}),
		}, deps())
		local why: { [string]: string } = {}
		for _, refused in plan.Refused do
			why[refused.Id] = (why[refused.Id] or "") .. refused.Why
		end
		expect(why.Pumpkin_BlazeJackier).toMatch("Ids never change")
		expect(why.Pumpkin_Gourdy).toMatch("already in the game")
		expect(why.Candy_Twin).toMatch("two drafts")
		expect(why.Zombie).toMatch("Classic")
		expect(why.Pumpkin_HatTrick).toMatch("ApprovedIds")
		expect(why.Pumpkin_HatTrick).toMatch("Someone")
		expect(next(plan.Files)).toBeNil() -- nothing written
		-- an approved id goes through
		local approved = (w.Config :: any).SkinCatalog.ApprovedIds
		approved[1234567890] = "Top Hat, test"
		local ok = SkinFile.Plan({ page({ record(hat, { Lookups = lookups }) }) }, deps())
		approved[1234567890] = nil
		expect(#ok.Refused).toBe(0)
		-- economy changes: refused unless unlocked, then listed loudly
		local pricier = itemOf(w, "Pumpkin_Gourdy")
		pricier.Rarity = "Uncommon"
		pricier.Style.Head = "SkinPumpkin"
		local locked =
			SkinFile.Plan({ page({ record(pricier, { Source = "Pumpkin_Gourdy" }) }) }, deps())
		expect(#locked.Refused).toBe(1)
		local unlocked = SkinFile.Plan({
			page({ record(pricier, { Source = "Pumpkin_Gourdy", UnlockEconomy = true }) }),
		}, deps())
		expect(#unlocked.Refused).toBe(0)
		expect(unlocked.Economy[1]).toMatch("Rarity Common %-> Uncommon")
		expect(unlocked.Files.Pumpkin.CountsAfter.Uncommon).toBe(6)
	end)

	it("stops when a page was damaged in copying", function()
		local good = page({
			{ DraftId = "X", Item = w.Schema.Encode(itemOf(w, "Pumpkin_Gourdy")), Updated = 1 },
		})
		local text = good.Drafts[1].Text
		good.Drafts[1].Text = text:sub(1, 20)
			.. (if text:sub(21, 21) == "a" then "b" else "a")
			.. text:sub(22)
		local plan = SkinFile.Plan({ good }, deps())
		expect(plan.Damaged).toMatch("page 1, draft 1 was damaged in copying")
		expect(SkinFile.Plan({ { Version = 1 } }, deps()).Damaged).toBeA("string")
	end)

	it("keeps the header line right for every shape it has", function()
		local function header(line: string, counts: any): string
			local text = "--!strict\n--[[\n" .. line .. "\n]]\n"
			return (SkinFile.UpdateHeader(text, counts):match("\n([^\n]*CRATE SKINS[^\n]*)\n"))
		end
		local c = { Total = 22, Common = 13, Uncommon = 6, Rare = 3, Crazy = 0, Million = 0 }
		expect(header("\tZOMBIE TOWN CRATE SKINS (21): 13 Common, 5 Uncommon, 3 Rare.", c)).toBe(
			"\tZOMBIE TOWN CRATE SKINS (22): 13 Common, 6 Uncommon, 3 Rare."
		)
		c = { Total = 21, Common = 12, Uncommon = 5, Rare = 2, Crazy = 2, Million = 0 }
		expect(header("\tCANDY CRATE SKINS (20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY.", c)).toBe(
			"\tCANDY CRATE SKINS (21): 12 Common, 5 Uncommon, 2 Rare, 2 CRAZY."
		)
		c = { Total = 23, Common = 14, Uncommon = 5, Rare = 3, Crazy = 0, Million = 1 }
		expect(
			header(
				"\tALIEN ABDUCTION CRATE SKINS (22): 13 Common, 5 Uncommon, 3 Rare, and 1 CRAZY that is ONE IN A MILLION (Odds).",
				c
			)
		).toBe(
			"\tALIEN ABDUCTION CRATE SKINS (23): 14 Common, 5 Uncommon, 3 Rare, and 1 CRAZY that is ONE IN A MILLION (Odds)."
		)
	end)
end)
