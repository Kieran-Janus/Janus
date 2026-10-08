-- Catalog items in skins (Style.Catalog, src/shared/SkinCatalog.luau): Normalize (good and
-- ~25 bad catalogs, the warnings), Key, Ids, the FaceAccessory / ClassicFace names, creators
-- and approved ids from Config; the Cosmetics hooks (OnSkinChanged, catalog accessories never
-- hidden by a head piece, no doubled BodyColors or clothes on restore); SkinCatalogService with
-- stubbed Humanoid descriptions (waits for the avatar, players dressed before Start, the
-- accessories it asks for, once per change, newest wins, never for hiders, restores the avatar,
-- failures keep the Part skin, respawns, switched off); CatalogBadge and the shop / crate cards.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local NAN = 0 / 0
local INF = math.huge

-- Stubs for the avatar description calls the harness doesn't implement. A runtime with
-- rt.catalog set uses them; any other runtime gets exactly the harness's default answers.
-- rt.catalog = { applies = {}, snapshots = 0, notLoaded = { [player] = true }, fail = { [id] = true },
--   delay = seconds, own = { { AssetId, Type } }, inFlight = 0, maxInFlight = 0 }

local function stubOf(self: any): (any, any)
	local w = Dom.data(self).world
	return if w then w.catalog else nil, w
end

-- A description's accessories live in an attribute, so Clone copies them.
local function encodeAccessories(list: { any }): string
	local parts = {}
	for _, a in list do
		local kind = a.AccessoryType
		local name = if typeof(kind) == "EnumItem" then kind.Name else tostring(kind)
		table.insert(parts, ("%d:%s:%s"):format(a.AssetId, name, if a.IsLayered then "1" else "0"))
	end
	return table.concat(parts, ";")
end

local function decodeAccessories(w: any, text: any): { any }
	local out = {}
	if type(text) ~= "string" then
		return out
	end
	for id, name, layered in string.gmatch(text, "(%d+):(%a+):(%d)") do
		table.insert(out, {
			AssetId = tonumber(id),
			AccessoryType = w.env.Enum.AccessoryType[name],
			IsLayered = layered == "1",
		})
	end
	return out
end

Dom.define("HumanoidDescription", {
	GetAccessories = function(self, includeRigid)
		local w = Dom.data(self).world
		local text = self:GetAttribute("StubAccessories")
		if text == nil then
			w:recordCall("HumanoidDescription", "GetAccessories", self, includeRigid)
			return {}
		end
		return decodeAccessories(w, text)
	end,
	SetAccessories = function(self, list, includeRigid)
		local w = Dom.data(self).world
		w:recordCall("HumanoidDescription", "SetAccessories", self, list, includeRigid)
		self:SetAttribute("StubAccessories", encodeAccessories(list))
	end,
})

Dom.define("Player", {
	HasAppearanceLoaded = function(self)
		local stub = stubOf(self)
		return not (stub and stub.notLoaded[self])
	end,
})

-- Like the engine: accessories follow the description (only the ones it made itself), and
-- clothes / BodyColors it can't see (put away by a skin) are made again.
local function engineApply(w: any, humanoid: any, desc: any)
	local env = w.env
	local character = humanoid.Parent
	local want: { [number]: any } = {}
	for _, a in desc:GetAccessories(true) do
		want[a.AssetId] = a
	end
	for _, a in w.catalog.own do
		want[a.AssetId] = nil -- the player's own accessories are already on
	end
	for _, child in character:GetChildren() do
		local id = child:GetAttribute("StubAssetId")
		if child.ClassName == "Accessory" and id then
			if want[id] then
				want[id] = nil
			else
				child:Destroy()
			end
		end
	end
	local head = character:FindFirstChild("Head")
	for id in want do
		local accessory = env.Instance.new("Accessory")
		accessory.Name = "CatalogItem" .. id
		accessory:SetAttribute("StubAssetId", id)
		local handle = env.Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = env.Vector3.new(1, 1, 1)
		handle.Parent = accessory
		if head then
			local weld = env.Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = head
			weld.Parent = handle
		end
		accessory.Parent = character
	end
	for _, pair in { { "Shirt", "Shirt" }, { "Pants", "Pants" } } do
		local id = desc[pair[1]]
		if id ~= 0 and not character:FindFirstChildOfClass(pair[2]) then
			local made = env.Instance.new(pair[2])
			made.Parent = character
		end
	end
	if not character:FindFirstChildOfClass("BodyColors") then
		env.Instance.new("BodyColors").Parent = character
	end
end

Dom.define("Humanoid", {
	GetAppliedDescription = function(self)
		local stub, w = stubOf(self)
		if not stub then
			w:recordCall("Humanoid", "GetAppliedDescription", self)
			return nil
		end
		stub.snapshots += 1
		local desc = w.env.Instance.new("HumanoidDescription")
		local own = {}
		for _, a in stub.own do
			table.insert(own, {
				AssetId = a.AssetId,
				AccessoryType = w.env.Enum.AccessoryType[a.Type],
				IsLayered = false,
			})
		end
		desc:SetAttribute("StubAccessories", encodeAccessories(own))
		desc.Shirt = 3000
		desc.Pants = 3001
		return desc
	end,
	ApplyDescriptionAsync = function(self, desc, verification)
		local stub, w = stubOf(self)
		if not stub then
			w:recordCall("Humanoid", "ApplyDescriptionAsync", self, desc, verification)
			return
		end
		local ids = {}
		local accessories = desc:GetAccessories(true)
		for _, a in accessories do
			table.insert(ids, a.AssetId)
		end
		for _, key in { "Shirt", "Pants", "GraphicTShirt", "Face" } do
			if desc[key] ~= 0 then
				table.insert(ids, desc[key])
			end
		end
		local entry = {
			Humanoid = self,
			At = w:now(),
			Ids = ids,
			Accessories = accessories,
			Verification = verification,
		}
		table.insert(stub.applies, entry)
		stub.inFlight += 1
		stub.maxInFlight = math.max(stub.maxInFlight, stub.inFlight)
		if stub.delay > 0 then
			w.env.task.wait(stub.delay)
		end
		stub.inFlight -= 1
		for _, id in ids do
			if stub.fail[id] then
				error(("Failed to load asset %d: it may be moderated"):format(id), 0)
			end
		end
		engineApply(w, self, desc)
	end,
})

-- Test skins with catalog items (made-up ids: nothing here reaches Roblox).
local function addTestSkins(Config: any, env: any)
	local rgb = env.Color3.fromRGB
	local function skin(id: string, style: { [string]: any })
		style.Kind = "Skin"
		if style.HideClothes == nil then
			style.HideClothes = true
		end
		table.insert(Config.Shop.Items, {
			Id = id,
			Name = id,
			Slot = "Skin",
			Rarity = "Rare",
			Style = style,
		})
	end
	skin("Test_CatalogHat", {
		BodyColor = rgb(200, 100, 40),
		Head = "SkinPumpkin",
		Catalog = { Accessories = { { Id = 1001, Type = "Hat" }, { Id = 1002, Type = "Back" } } },
	})
	skin("Test_CatalogShirt", {
		BodyColor = rgb(60, 160, 90),
		Accent = { Color = rgb(250, 250, 250), Pattern = "Belt" },
		HideClothes = false,
		Catalog = { Shirt = 2001, Pants = 2002 },
	})
	skin("Test_CatalogBack", {
		BodyColor = rgb(90, 60, 160),
		Catalog = { Accessories = { { Id = 1003, Type = "Back" } } },
	})
	skin("Test_CatalogBroken", {
		BodyColor = rgb(160, 60, 60),
		Accent = { Color = rgb(20, 20, 20), Pattern = "Belt" },
		Catalog = { Accessories = { { Id = 9999, Type = "Hat" } } },
	})
	skin("Test_CatalogMany", {
		BodyColor = rgb(60, 60, 60),
		HideClothes = false,
		Catalog = {
			Accessories = {
				{ Id = 1101, Type = "Hat" },
				{ Id = 1102, Type = "Back" },
				{ Id = 1103, Type = "Waist" },
				{ Id = 1104, Type = "Neck" },
			},
			Shirt = 1105,
			Pants = 1106,
		},
	})
end

local function newStub(): any
	return {
		applies = {},
		snapshots = 0,
		notLoaded = {},
		fail = {},
		delay = 0,
		own = { { AssetId = 5000, Type = "Hair" } },
		inFlight = 0,
		maxInFlight = 0,
	}
end

local SERVICES = "ServerScriptService.Server.Services."

-- A server with DataService, ShopService and (unless start = false) SkinCatalogService.
local function world(opts: { [string]: any }?): any
	local o = opts or {}
	local rt = Runtime.new({ studio = o.studio == true })
	rt.catalog = newStub()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	Config.Features.SkinCatalog = o.feature ~= false
	addTestSkins(Config, rt.env)
	local DataService = rt:require(SERVICES .. "DataService")
	local ShopService = rt:require(SERVICES .. "ShopService")
	local Service = rt:require(SERVICES .. "SkinCatalogService")
	DataService.Start()
	ShopService.Start()
	if o.start ~= false then
		Service.Start()
	end
	local w = {
		rt = rt,
		stub = rt.catalog,
		Config = Config,
		DataService = DataService,
		ShopService = ShopService,
		Service = Service,
		Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics"),
	}
	function w.join(name: string): any
		local player = rt:addPlayer({ Name = name })
		rt:advance(3)
		return player
	end
	-- Equips a skin the way the shop does ("" = none) and dresses the player.
	function w.wear(player: any, id: string)
		local data = DataService.Get(player)
		assert(data, "no save for " .. player.Name)
		if id ~= "" then
			data.Owned[id] = true
		end
		data.Equipped.Skin = id
		ShopService.Dress(player)
	end
	return w
end

-- The catalog accessories the (stub) engine put on a character, by id.
local function catalogItems(character: any): { [number]: any }
	local out = {}
	for _, child in character:GetChildren() do
		local id = child:GetAttribute("StubAssetId")
		if child.ClassName == "Accessory" and id then
			out[id] = child
		end
	end
	return out
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- How many `className` instances a character has, also inside the skin's stash.
local function deepCount(character: any, className: string): number
	local n = 0
	for _, d in character:GetDescendants() do
		if d.ClassName == className then
			n += 1
		end
	end
	return n
end

local function idsHave(entry: any, id: number): boolean
	return table.find(entry.Ids, id) ~= nil
end

-- What a character looks like (as in skins.spec): parts, decals, direct children, attributes.
local function snapshot(character: any): { [string]: any }
	local shot = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			shot[d:GetFullName()] = ("%s %s %.4f"):format(
				tostring(d.Color),
				tostring(d.Material),
				d.Transparency
			)
		elseif d:IsA("Decal") then
			shot[d:GetFullName()] = ("%.4f"):format(d.Transparency)
		end
	end
	local children = {}
	for _, child in character:GetChildren() do
		table.insert(children, child.ClassName .. ":" .. child.Name)
	end
	table.sort(children)
	shot.Children = table.concat(children, ",")
	shot.Status = tostring(character:GetAttribute("SkinCatalogStatus"))
	shot.HatLift = tostring(character:GetAttribute("HatLift"))
	return shot
end

local function sameLook(before: { [string]: any }, after: { [string]: any }, what: string)
	for key, value in before do
		if after[key] ~= value then
			error(("%s: %s is %s, was %s"):format(what, key, tostring(after[key]), tostring(value)))
		end
	end
	for key in after do
		if before[key] == nil then
			error(what .. ": " .. key .. " was left behind")
		end
	end
end

describe("SkinCatalog: checking", function()
	local rt = Runtime.new()
	local Enum = rt.env.Enum
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local SkinCatalog = rt:require("ReplicatedStorage.Shared.SkinCatalog")

	it("reads a good catalog and keeps every item", function()
		local catalog, errors = SkinCatalog.Normalize({
			Accessories = { { Id = 1001, Type = "Hat" }, { Id = 1002, Type = "FaceAccessory" } },
			Shirt = 2001,
			Pants = 2002,
			TShirt = 2003,
			ClassicFace = 2004,
		})
		expect(#errors).toBe(0)
		expect(catalog).toBeTruthy()
		expect(#catalog.Accessories).toBe(2)
		expect(catalog.Accessories[2].Type).toBe("FaceAccessory")
		expect(catalog.Shirt).toBe(2001)
		expect(catalog.ClassicFace).toBe(2004)
		expect(SkinCatalog.Ids(catalog)).toEqual({ 1001, 1002, 2001, 2002, 2003, 2004 })
		expect(SkinCatalog.Normalize(nil)).toBeNil()
		-- the Types come from Config
		expect(SkinCatalog.Types).toBe(Config.SkinCatalog.Types)
		for _, kind in SkinCatalog.Types do
			expect(SkinCatalog.AccessoryType(kind)).toBeTruthy()
		end
	end)

	it("refuses every bad catalog with a message", function()
		local cases: { { any } } = {
			{ "not a table", "Hats please", "should be a table" },
			{ "unknown key", { Hats = {} }, "doesn't go here" },
			{
				"Accessories with a hole",
				{
					Accessories = { [1] = { Id = 1, Type = "Hat" }, [3] = { Id = 2, Type = "Hat" } },
				},
				"should be a list",
			},
			{ "Accessories not a list", { Accessories = { Hat = 1 } }, "should be a list" },
			{
				"too many accessories",
				{
					Accessories = {
						{ Id = 1, Type = "Hat" },
						{ Id = 2, Type = "Hat" },
						{ Id = 3, Type = "Hat" },
						{ Id = 4, Type = "Hat" },
						{ Id = 5, Type = "Hat" },
					},
				},
				"at most",
			},
			{
				"the same id twice",
				{ Accessories = { { Id = 7, Type = "Hat" }, { Id = 7, Type = "Back" } } },
				"used twice",
			},
			{
				"an accessory id as the shirt",
				{ Accessories = { { Id = 7, Type = "Hat" } }, Shirt = 7 },
				"used twice",
			},
			{
				"an unknown Type",
				{ Accessories = { { Id = 1, Type = "Wings" } } },
				"isn't allowed",
			},
			{ "a layered jacket", { Accessories = { { Id = 1, Type = "Jacket" } } }, "layered" },
			{
				"a layered shirt accessory",
				{ Accessories = { { Id = 1, Type = "ShirtAccessory" } } },
				"layered",
			},
			{
				"Shirt as an accessory",
				{ Accessories = { { Id = 1, Type = "Shirt" } } },
				"layered",
			},
			{
				"Face (not FaceAccessory)",
				{ Accessories = { { Id = 1, Type = "Face" } } },
				"FaceAccessory",
			},
			{ "no Type", { Accessories = { { Id = 1 } } }, "needs a Type" },
			{ "an accessory that isn't a table", { Accessories = { 1234 } }, "should be a table" },
			{
				"an extra key",
				{ Accessories = { { Id = 1, Type = "Hat", Color = 1 } } },
				"doesn't go here",
			},
			{ "id 1.5", { Accessories = { { Id = 1.5, Type = "Hat" } } }, "needs Id" },
			{ "id NaN", { Accessories = { { Id = NAN, Type = "Hat" } } }, "needs Id" },
			{ "id +inf", { Accessories = { { Id = INF, Type = "Hat" } } }, "needs Id" },
			{ "id -inf", { Accessories = { { Id = -INF, Type = "Hat" } } }, "needs Id" },
			{ "id 0", { Accessories = { { Id = 0, Type = "Hat" } } }, "needs Id" },
			{ "id below 0", { Accessories = { { Id = -5, Type = "Hat" } } }, "needs Id" },
			{ "id 2^53", { Accessories = { { Id = 2 ^ 53, Type = "Hat" } } }, "needs Id" },
			{ "id as text", { Accessories = { { Id = "123", Type = "Hat" } } }, "needs Id" },
			{ "Shirt NaN", { Shirt = NAN }, "Shirt should be" },
			{ "Pants text", { Pants = "123" }, "Pants should be" },
			{ "TShirt inf", { TShirt = INF }, "TShirt should be" },
			{ "ClassicFace 1.5", { ClassicFace = 1.5 }, "ClassicFace should be" },
		}
		for _, case in cases do
			local name, value, words = case[1], case[2], case[3]
			local _, errors = SkinCatalog.Normalize(value)
			if #errors == 0 then
				error(name .. ": no error")
			end
			local text = table.concat(errors, " | ")
			if not string.find(text, words, 1, true) then
				error(("%s: expected %q in %s"):format(name, words, text))
			end
		end
		-- bad parts are left out, good ones kept
		local kept = SkinCatalog.Normalize({
			Accessories = { { Id = 1, Type = "Hat" }, { Id = 2, Type = "Jacket" } },
			Shirt = NAN,
			Pants = 9,
		})
		expect(kept).toBeTruthy()
		expect(SkinCatalog.Ids(kept)).toEqual({ 1, 9 })
	end)

	it("warns about items that won't show, and ids not approved yet", function()
		local saved = Config.SkinCatalog.ApprovedIds
		Config.SkinCatalog.ApprovedIds = { [1001] = "test", [2001] = "test", [2004] = "test" }
		local function warningsFor(catalog: any, style: any): string
			local _, errors, warnings = SkinCatalog.Normalize(catalog, style)
			expect(#errors).toBe(0)
			return table.concat(warnings, " | ")
		end
		-- clothes on a skin that hides clothes (HideClothes true or not set)
		expect(warningsFor({ Shirt = 2001 }, { HideClothes = true })).toMatch("HideClothes = false")
		expect(warningsFor({ Shirt = 2001 }, {})).toMatch("HideClothes = false")
		expect(warningsFor({ Shirt = 2001 }, { HideClothes = false })).toBe("")
		-- a flat face and head-slot accessories under a head piece
		expect(warningsFor({ ClassicFace = 2004 }, { Head = "SkinPumpkin" })).toMatch(
			"ClassicFace won't show"
		)
		expect(
			warningsFor({ Accessories = { { Id = 1001, Type = "Hat" } } }, { Head = "SkinPumpkin" })
		).toMatch("real head")
		expect(warningsFor({ Accessories = { { Id = 1001, Type = "Hat" } } }, {})).toBe("")
		-- not approved
		expect(warningsFor({ Accessories = { { Id = 1002, Type = "Back" } } }, {})).toMatch(
			"ApprovedIds"
		)
		expect(SkinCatalog.Approved(1001)).toBe(true)
		expect(SkinCatalog.Approved(1002)).toBe(false)
		expect(SkinCatalog.Approved("1001")).toBe(false)
		expect(SkinCatalog.Approved(NAN)).toBe(false)
		-- an empty catalog
		local empty, errors, warnings = SkinCatalog.Normalize({})
		expect(empty).toBeNil()
		expect(#errors).toBe(0)
		expect(#warnings).toBe(1)
		Config.SkinCatalog.ApprovedIds = saved
	end)

	it('makes the same Key for the same items in any order, "" for none', function()
		local a = SkinCatalog.Key({
			Accessories = { { Id = 1001, Type = "Hat" }, { Id = 1002, Type = "Back" } },
			Shirt = 5,
		})
		local b = SkinCatalog.Key({
			Shirt = 5,
			Accessories = { { Id = 1002, Type = "Back" }, { Id = 1001, Type = "Hat" } },
		})
		expect(a).toBe(b)
		expect(a).never.toBe("")
		expect(SkinCatalog.Key(nil)).toBe("")
		expect(SkinCatalog.Key({})).toBe("")
		expect(SkinCatalog.Key("junk")).toBe("")
		expect(SkinCatalog.Key({ Accessories = { { Id = 1001, Type = "Hat" } } })).never.toBe(
			SkinCatalog.Key({ Accessories = { { Id = 1001, Type = "Hair" } } })
		)
		expect(SkinCatalog.Key({ Shirt = 5 })).never.toBe(SkinCatalog.Key({ Pants = 5 }))
	end)

	it("keeps FaceAccessory (glasses, masks) and ClassicFace (a flat face) apart", function()
		expect(SkinCatalog.TypeFromAssetType("FaceAccessory")).toBe("FaceAccessory")
		expect(SkinCatalog.TypeFromAssetType("Face")).toBe("ClassicFace")
		expect(SkinCatalog.TypeFromAssetType("Hat")).toBe("Hat")
		expect(SkinCatalog.TypeFromAssetType("HairAccessory")).toBe("Hair")
		expect(SkinCatalog.TypeFromAssetType("BackAccessory")).toBe("Back")
		expect(SkinCatalog.TypeFromAssetType("Shirt")).toBe("Shirt")
		expect(SkinCatalog.TypeFromAssetType("TShirt")).toBe("TShirt")
		-- what can't go in a skin
		for _, name in
			{ "JacketAccessory", "Head", "Torso", "DynamicHead", "WalkAnimation", "Model" }
		do
			expect(SkinCatalog.TypeFromAssetType(name)).toBeNil()
		end
		expect(SkinCatalog.TypeFromAssetType(nil)).toBeNil()
		-- by AssetTypeId (GetProductInfo), through Enum.AssetType's names
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.Hat.Value)).toBe("Hat")
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.HairAccessory.Value)).toBe("Hair")
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.Face.Value)).toBe("ClassicFace")
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.FaceAccessory.Value)).toBe(
			"FaceAccessory"
		)
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.Shirt.Value)).toBe("Shirt")
		expect(SkinCatalog.TypeFromAssetTypeId(Enum.AssetType.Animation.Value)).toBeNil()
		expect(SkinCatalog.TypeFromAssetTypeId(NAN)).toBeNil()
		-- to the accessory enum
		expect(SkinCatalog.AccessoryType("FaceAccessory").Name).toBe("Face")
		expect(SkinCatalog.AccessoryType("Hair").Name).toBe("Hair")
		expect(SkinCatalog.AccessoryType("Waist").Name).toBe("Waist")
		expect(SkinCatalog.AccessoryType("ClassicFace")).toBeNil()
		expect(SkinCatalog.AccessoryType("Nope")).toBeNil()
	end)

	it("allows only Roblox and the creators listed in Config", function()
		local allowed = Config.SkinCatalog.AllowedCreators
		expect(SkinCatalog.CreatorAllowed("User", 1)).toBe(true) -- Roblox
		expect(SkinCatalog.CreatorAllowed("User", 555)).toBe(false)
		expect(SkinCatalog.CreatorAllowed("Group", 1)).toBe(false)
		expect(SkinCatalog.CreatorAllowed("Group", 77)).toBe(false)
		allowed.UserIds = { 555 }
		allowed.GroupIds = { 77 }
		expect(SkinCatalog.CreatorAllowed("User", 555)).toBe(true)
		expect(SkinCatalog.CreatorAllowed("Group", 77)).toBe(true)
		expect(SkinCatalog.CreatorAllowed("Group", 555)).toBe(false)
		allowed.Roblox = false
		expect(SkinCatalog.CreatorAllowed("User", 1)).toBe(false)
		allowed.Roblox = true
		allowed.UserIds = {}
		allowed.GroupIds = {}
		for _, junk in { { "User", NAN }, { "User", "1" }, { nil, 1 }, { "Bot", 1 } } do
			expect(SkinCatalog.CreatorAllowed(junk[1], junk[2])).toBe(false)
		end
	end)

	it("points pictures at Roblox's thumbnails", function()
		expect(SkinCatalog.Thumbnail(1234567890)).toBe(
			"rbxthumb://type=Asset&id=1234567890&w=150&h=150"
		)
	end)
end)

describe("Cosmetics: catalog hooks", function()
	local rt = Runtime.new()
	local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
	local Items = rt:require("ReplicatedStorage.Shared.Items")
	local player = rt:addPlayer({ Name = "Hooks" })
	local character = player.Character
	local plain = Items.Get("Pumpkin_PumpkinSpice")
	local headed = Items.Get("Pumpkin_SirGourdington")
	local hat = Items.Get("WitchHat")

	it("tells listeners once per Wear, and once per TakeOff called on its own", function()
		local calls = {}
		local stop = Cosmetics.OnSkinChanged(function(c, item)
			table.insert(calls, { c, if item then item.Id else "nil" })
		end)
		Cosmetics.Wear(character, plain)
		expect(#calls).toBe(1)
		expect(calls[1][1]).toBe(character)
		expect(calls[1][2]).toBe(plain.Id)
		Cosmetics.Wear(character, headed) -- (its own TakeOff first doesn't count)
		expect(#calls).toBe(2)
		expect(calls[2][2]).toBe(headed.Id)
		if hat then
			Cosmetics.Wear(character, hat)
			Cosmetics.TakeOff(character, "Hat")
		end
		expect(#calls).toBe(2)
		Cosmetics.TakeOff(character, "Skin")
		expect(#calls).toBe(3)
		expect(calls[3][2]).toBe("nil")
		stop()
		Cosmetics.Wear(character, plain)
		Cosmetics.TakeOff(character, "Skin")
		expect(#calls).toBe(3)
	end)

	it("keeps telling the others when one listener breaks", function()
		local heard = 0
		local stopBad = Cosmetics.OnSkinChanged(function()
			error("oops")
		end)
		local stopGood = Cosmetics.OnSkinChanged(function()
			heard += 1
		end)
		local warnings = #rt.warnings
		Cosmetics.Wear(character, plain)
		expect(heard).toBe(1)
		expect(#rt.warnings).toBe(warnings + 1)
		stopBad()
		stopGood()
		Cosmetics.TakeOff(character, "Skin")
	end)

	it("never hides the skin's own catalog accessories under a head piece", function()
		local accessory = rt:create("Accessory", { Name = "CatalogHat" }, character)
		accessory:SetAttribute("SkinCatalog", true)
		local handle = rt:create("Part", { Name = "Handle" }, accessory)
		rt:create("Weld", { Part0 = handle, Part1 = character.Head }, handle)
		Cosmetics.Wear(character, headed)
		expect(handle.Transparency).toBe(0)
		expect(character.Hair.Handle.Transparency).toBe(1) -- the avatar's own hair is hidden
		Cosmetics.TakeOff(character, "Skin")
		expect(character.Hair.Handle.Transparency).toBe(0)
		accessory:Destroy()
	end)

	it("puts back no doubled BodyColors or clothes when newer ones appeared meanwhile", function()
		local before = snapshot(character)
		Cosmetics.Wear(character, plain) -- (puts the avatar's BodyColors, Shirt and Pants away)
		expect(character:FindFirstChildOfClass("BodyColors")).toBeNil()
		local newer = {}
		for _, className in { "BodyColors", "Shirt", "Pants" } do
			newer[className] = rt:create(className, { Name = className }, character)
		end
		Cosmetics.TakeOff(character, "Skin")
		for className, made in newer do
			expect(deepCount(character, className)).toBe(1)
			expect(character:FindFirstChildOfClass(className)).toBe(made)
		end
		sameLook(before, snapshot(character), "after the newer ones won")
	end)
end)

describe("SkinCatalogService (server)", function()
	it("does nothing at all when switched off, and never waits", function()
		local w = world({ feature = false, start = false })
		local co = coroutine.create(w.Service.Start)
		coroutine.resume(co)
		expect(coroutine.status(co)).toBe("dead")
		local player = w.join("Off")
		w.wear(player, "Test_CatalogHat")
		w.rt:advance(5)
		expect(#w.stub.applies).toBe(0)
		expect(w.stub.snapshots).toBe(0)
		expect(player.Character:GetAttribute("SkinCatalogStatus")).toBeNil()
		expect(player.Character:FindFirstChild("Cosmetic_Skin")).toBeTruthy()
	end)

	it("puts the skin's items on the player's own avatar, once, and marks them", function()
		local w = world()
		local player = w.join("Wearer")
		local character = player.Character
		w.wear(player, "Test_CatalogHat")
		expect(#w.stub.applies).toBe(0) -- (later, never during Wear)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		local entry = w.stub.applies[1]
		expect(entry.Verification.Name).toBe("Always")
		-- the player's own hair, plus the skin's hat and back item, as rigid accessories
		local byId = {}
		for _, a in entry.Accessories do
			byId[a.AssetId] = a
		end
		expect(byId[5000]).toBeTruthy()
		expect(byId[1001].AccessoryType.Name).toBe("Hat")
		expect(byId[1001].IsLayered).toBe(false)
		expect(byId[1002].AccessoryType.Name).toBe("Back")
		local items = catalogItems(character)
		expect(count(items)).toBe(2)
		for _, accessory in items do
			expect(accessory:GetAttribute("SkinCatalog")).toBe(true)
			-- the head piece hides the avatar's own hair, never the skin's catalog hat
			expect(accessory.Handle.Transparency).toBe(0)
		end
		expect(character.Hair.Handle.Transparency).toBe(1)
		expect(w.Service.Status(character)).toBe("On")
		-- the Part skin is still on (dressed again after the apply)
		local skin = character:FindFirstChild("Cosmetic_Skin")
		expect(skin).toBeTruthy()
		expect(skin:GetAttribute("ItemId")).toBe("Test_CatalogHat")
		-- nothing more happens: the re-dress fires OnSkinChanged with the same items
		w.rt:advance(10)
		expect(#w.stub.applies).toBe(1)
		expect(w.stub.snapshots).toBe(1)
		w.ShopService.Dress(player)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
	end)

	it("restores the avatar exactly when the skin comes off (no doubled BodyColors)", function()
		local w = world()
		local player = w.join("Restore")
		local character = player.Character
		local before = snapshot(character)
		w.wear(player, "Test_CatalogHat")
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		-- the apply made a new BodyColors, Shirt and Pants (the old ones were put away):
		-- after the re-dress there is still one of each
		for _, className in { "BodyColors", "Shirt", "Pants" } do
			expect(deepCount(character, className)).toBe(1)
		end
		w.wear(player, "")
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(2)
		expect(idsHave(w.stub.applies[2], 1001)).toBe(false)
		expect(idsHave(w.stub.applies[2], 5000)).toBe(true) -- the player's own hair stays
		expect(count(catalogItems(character))).toBe(0)
		for _, className in { "BodyColors", "Shirt", "Pants" } do
			expect(deepCount(character, className)).toBe(1)
		end
		sameLook(before, snapshot(character), "after taking the catalog skin off")
		-- a skin without catalog items afterwards changes nothing more
		w.wear(player, "Pumpkin_PumpkinSpice")
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(2)
	end)

	it("applies a burst of changes once, keeps one in flight, and the newest wins", function()
		local w = world()
		local cfg = w.Config.SkinCatalog
		local player = w.join("Burst")
		local character = player.Character
		w.wear(player, "Test_CatalogHat")
		w.wear(player, "Test_CatalogShirt")
		w.wear(player, "Test_CatalogBack")
		w.rt:advance(1)
		expect(#w.stub.applies).toBe(1)
		expect(idsHave(w.stub.applies[1], 1003)).toBe(true)
		expect(idsHave(w.stub.applies[1], 1001)).toBe(false)
		-- slow loads: a change while one loads goes on after it, SecondsBetweenApplies apart
		w.stub.delay = 1
		w.wear(player, "Test_CatalogHat")
		w.rt:advance(cfg.SecondsBetweenApplies + 0.5 - 1) -- the Hat apply is loading now
		expect(#w.stub.applies).toBe(2)
		w.wear(player, "Test_CatalogShirt")
		w.wear(player, "Test_CatalogMany")
		w.wear(player, "Test_CatalogShirt")
		w.rt:advance(6)
		expect(#w.stub.applies).toBe(3)
		expect(w.stub.maxInFlight).toBe(1)
		local last = w.stub.applies[3]
		expect(idsHave(last, 2001)).toBe(true)
		expect(idsHave(last, 1001)).toBe(false)
		for i = 2, #w.stub.applies do
			expect(w.stub.applies[i].At - w.stub.applies[i - 1].At).toBeGreaterThanOrEqual(
				cfg.SecondsBetweenApplies - 1e-6
			)
		end
		expect(count(catalogItems(character))).toBe(0) -- the Hat's items went with it
		expect(w.Service.Status(character)).toBe("On")
		expect(character:FindFirstChild("Cosmetic_Skin"):GetAttribute("ItemId")).toBe(
			"Test_CatalogShirt"
		)
	end)

	it("waits for the avatar to load before the first apply (or the timeout)", function()
		local w = world()
		local player = w.join("Slow")
		w.wear(player, "Test_CatalogBack")
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		-- respawn with an avatar that is still loading
		w.stub.notLoaded[player] = true
		w.rt:spawnCharacter(player)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		w.stub.notLoaded[player] = nil
		w.rt:fire(player, "CharacterAppearanceLoaded", player.Character)
		w.rt:advance(1)
		expect(#w.stub.applies).toBe(2)
		expect(w.stub.snapshots).toBe(2) -- a new snapshot for the new character
		expect(count(catalogItems(player.Character))).toBe(1)
		-- an avatar that never says it loaded: applied after AppearanceWaitSeconds anyway
		w.stub.notLoaded[player] = true
		w.rt:spawnCharacter(player)
		w.rt:advance(w.Config.SkinCatalog.AppearanceWaitSeconds - 1)
		expect(#w.stub.applies).toBe(2)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(3)
	end)

	it("dresses players who were already in the game before it started (Play Solo)", function()
		local w = world({ start = false })
		local player = w.join("Early")
		w.wear(player, "Test_CatalogHat")
		w.rt:advance(2)
		expect(#w.stub.applies).toBe(0)
		local remotes = w.rt:find("ReplicatedStorage.Remotes")
		local before = #remotes:GetChildren()
		local co = coroutine.create(w.Service.Start)
		coroutine.resume(co)
		expect(coroutine.status(co)).toBe("dead") -- Start never waits
		expect(#remotes:GetChildren()).toBe(before) -- and makes no remotes
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		expect(w.Service.Status(player.Character)).toBe("On")
	end)

	it("never dresses a Hide & Seek hider, also one who becomes a hider while it loads", function()
		local w = world()
		local player = w.join("Hider")
		local character = player.Character
		player:SetAttribute("HideSeekRole", "Hider")
		-- (the shop never dresses hiders; something else putting the skin on still applies nothing)
		w.Cosmetics.Wear(character, w.Cosmetics.Find("Test_CatalogHat"))
		w.rt:advance(4)
		expect(#w.stub.applies).toBe(0)
		player:SetAttribute("HideSeekRole", nil)
		local data = w.DataService.Get(player)
		data.Owned.Test_CatalogHat = true
		data.Equipped.Skin = "Test_CatalogHat"
		w.ShopService.Dress(player)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		-- becomes a hider during a slow load: the player's own avatar goes back on
		w.stub.delay = 2
		w.wear(player, "Test_CatalogBack")
		w.rt:advance(1) -- (loading)
		expect(#w.stub.applies).toBe(2)
		player:SetAttribute("HideSeekRole", "Hider")
		w.rt:advance(5)
		expect(#w.stub.applies).toBe(3)
		local last = w.stub.applies[3]
		expect(idsHave(last, 1003)).toBe(false)
		expect(idsHave(last, 1001)).toBe(false)
		expect(count(catalogItems(character))).toBe(0)
		expect(w.Service.Status(character)).toBeNil()
		-- found: the round dresses them again
		player:SetAttribute("HideSeekRole", nil)
		w.stub.delay = 0
		w.ShopService.Dress(player)
		w.rt:advance(4)
		expect(#w.stub.applies).toBe(4)
		expect(count(catalogItems(character))).toBe(1)
	end)

	it(
		"keeps the Part skin and says why when an item won't load (warns once, Studio only)",
		function()
			local w = world({ studio = true })
			w.stub.fail[9999] = true
			local player = w.join("Broken")
			local character = player.Character
			local warnings = #w.rt.warnings
			w.wear(player, "Test_CatalogBroken")
			expect(#w.rt.warnings).toBe(warnings) -- never during Wear
			w.rt:advance(3)
			expect(#w.stub.applies).toBe(1)
			local status = w.Service.Status(character)
			expect(status).toMatch("^Failed: ")
			expect(character:FindFirstChild("Cosmetic_Skin"):GetAttribute("ItemId")).toBe(
				"Test_CatalogBroken"
			)
			expect(#w.rt.warnings).toBe(warnings + 1)
			expect(w.rt.warnings[#w.rt.warnings]).toMatch("9999")
			-- not tried again until the skin changes
			w.rt:advance(10)
			w.ShopService.Dress(player)
			w.rt:advance(3)
			expect(#w.stub.applies).toBe(1)
			w.wear(player, "Test_CatalogBack")
			w.rt:advance(3)
			expect(#w.stub.applies).toBe(2)
			expect(w.Service.Status(character)).toBe("On")
			w.wear(player, "Test_CatalogBroken")
			w.rt:advance(3)
			expect(#w.stub.applies).toBe(3)
			expect(#w.rt.warnings).toBe(warnings + 1) -- one warning per id per server
			-- outside Studio: the status only
			local live = world()
			live.stub.fail[9999] = true
			local other = live.join("Live")
			local before = #live.rt.warnings
			live.wear(other, "Test_CatalogBroken")
			live.rt:advance(3)
			expect(live.Service.Status(other.Character)).toMatch("^Failed: ")
			expect(#live.rt.warnings).toBe(before)
		end
	)

	it("starts again from the player's own avatar after a respawn, and forgets leavers", function()
		local w = world()
		local player = w.join("Respawn")
		w.wear(player, "Test_CatalogHat")
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(1)
		w.rt:spawnCharacter(player)
		w.rt:advance(3)
		expect(#w.stub.applies).toBe(2)
		expect(w.stub.snapshots).toBe(2)
		local items = catalogItems(player.Character)
		expect(count(items)).toBe(2)
		for _, accessory in items do
			expect(accessory:GetAttribute("SkinCatalog")).toBe(true)
		end
		-- leaving while an apply loads: no errors, nothing more
		w.stub.delay = 2
		w.wear(player, "Test_CatalogBack")
		w.rt:advance(2.5)
		local applies = #w.stub.applies
		w.rt:removePlayer(player)
		w.rt:advance(6)
		expect(#w.stub.applies).toBe(applies)
		expect(#w.rt.errors).toBe(0)
	end)
end)

describe("CatalogBadge (client)", function()
	local client = Runtime.new({ client = true })
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	addTestSkins(CConfig, client.env)
	local Items = client:require("ReplicatedStorage.Shared.Items")
	local CatalogBadge = client:require("StarterPlayer.StarterPlayerScripts.Client.CatalogBadge")
	local holder = client:create("Frame", { Name = "Card" })

	it("shows nothing while switched off, or for a skin without catalog items", function()
		CConfig.Features.SkinCatalog = false
		expect(CatalogBadge.Add(holder, Items.Get("Test_CatalogHat"))).toBeNil()
		CConfig.Features.SkinCatalog = true
		expect(CatalogBadge.Add(holder, Items.Get("Pumpkin_PumpkinSpice"))).toBeNil()
		expect(CatalogBadge.Add(holder, nil)).toBeNil()
		CConfig.SkinCatalog.ShowThumbnails = false
		expect(CatalogBadge.Add(holder, Items.Get("Test_CatalogHat"))).toBeNil()
		CConfig.SkinCatalog.ShowThumbnails = true
		expect(#holder:GetChildren()).toBe(0)
	end)

	it("shows up to MaxThumbnails pictures, says what they are, and no Buy buttons", function()
		CConfig.Features.SkinCatalog = true
		local badge = CatalogBadge.Add(holder, Items.Get("Test_CatalogMany"))
		expect(badge).toBeTruthy()
		expect(badge.Parent).toBe(holder)
		local pictures = {}
		for _, d in badge:GetDescendants() do
			if d:IsA("ImageLabel") then
				table.insert(pictures, d)
			end
		end
		expect(#pictures).toBe(CConfig.SkinCatalog.MaxThumbnails)
		expect(pictures[1].Image).toBe("rbxthumb://type=Asset&id=1101&w=150&h=150")
		expect(badge:FindFirstChild("Buy", true)).toBeNil()
		expect(badge.Hover.Visible).toBe(false)
		client:fire(pictures[1], "MouseEnter")
		expect(badge.Hover.Visible).toBe(true)
		expect(badge.Hover.Text).toBe(CConfig.SkinCatalog.Text.Hover)
		client:fire(pictures[1], "MouseLeave")
		expect(badge.Hover.Visible).toBe(false)
		badge:Destroy()
	end)

	it("opens Roblox's own buy window only when ShowBuyButtons is on", function()
		CConfig.SkinCatalog.ShowBuyButtons = true
		local badge = CatalogBadge.Add(holder, Items.Get("Test_CatalogBack"))
		local buy = badge:FindFirstChild("Buy", true)
		expect(buy).toBeInstanceOf("TextButton")
		client:fire(buy, "Activated")
		local calls = client:calls("MarketplaceService", "PromptPurchase")
		expect(#calls).toBe(1)
		expect(calls[1].args[2]).toBe(1003)
		CConfig.SkinCatalog.ShowBuyButtons = false
		badge:Destroy()
	end)
end)

describe("Shop and crate cards show catalog items", function()
	it("puts the pictures on a shop card", function()
		local client = Runtime.new({ client = true })
		local CConfig = client:require("ReplicatedStorage.Shared.Config")
		CConfig.Features.SkinCatalog = true
		addTestSkins(CConfig, client.env)
		-- (first in the list, so it is on the first page)
		local test = table.remove(CConfig.Shop.Items, #CConfig.Shop.Items - 1) -- Test_CatalogBroken
		table.insert(CConfig.Shop.Items, 1, test)
		local Shared = client:find("ReplicatedStorage")
		local remotes = client:create("Folder", { Name = "Remotes" }, Shared)
		for _, name in { "GetShopState", "BuyItem", "EquipItem" } do
			client:create("RemoteFunction", { Name = name }, remotes)
		end
		local shopState = client:create("RemoteEvent", { Name = "ShopState" }, remotes)
		local Client = client:find("StarterPlayer.StarterPlayerScripts.Client")
		local gui = client:create("ScreenGui", { Name = "GameUI" })
		client:require(Client.Layout).Mount(gui)
		client:require(Client.PanelManager).Mount(gui)
		local ShopUI = client:require(Client.ShopUI)
		ShopUI.Mount(gui)
		client:advance(1)
		client:fire(shopState, "OnClientEvent", {
			Ready = true,
			Coins = 500,
			Owned = {},
			Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" },
			Vip = false,
		})
		ShopUI.Open("Skin")
		client:advance(0.5)
		local badges = {}
		for _, d in gui.Shop:GetDescendants() do
			if d.Name == "CatalogBadge" then
				table.insert(badges, d)
			end
		end
		expect(#badges).toBe(1)
		expect(badges[1].Parent:IsA("ViewportFrame")).toBe(true)
	end)

	it("puts the pictures on the crate reveal card", function()
		local server = Runtime.new()
		local SConfig = server:require("ReplicatedStorage.Shared.Config")
		SConfig.Features.Crates = true
		for _, name in { "DataService", "ShopService", "MonetizationService", "CrateService" } do
			server:require(SERVICES .. name).Start()
		end
		server:addPlayer({ Name = "Opener" })
		server:advance(3)
		local client = Runtime.new({ client = true })
		client:replicateFrom(server)
		local CConfig = client:require("ReplicatedStorage.Shared.Config")
		CConfig.Features.Crates = true
		CConfig.Features.SkinCatalog = true
		CConfig.Crates.Opening.Style = "Reel"
		addTestSkins(CConfig, client.env)
		local CrateUI = client:require("StarterPlayer.StarterPlayerScripts.Client.CrateUI")
		local me = client.game:GetService("Players").LocalPlayer
		local gui = client:create("ScreenGui", { Name = "GameUI" }, me.PlayerGui)
		CrateUI.Mount(gui)
		client:advance(1)
		CrateUI.Open("PumpkinCrate")
		local reel = {}
		for i = 1, 32 do
			reel[i] = "Pumpkin_PumpkinSpice"
		end
		reel[28] = "Test_CatalogBack"
		client:fire(client:find("ReplicatedStorage.Remotes.CrateResult"), "OnClientEvent", {
			Ok = true,
			Message = "",
			CrateId = "PumpkinCrate",
			ItemId = "Test_CatalogBack",
			ItemName = "Test_CatalogBack",
			Rarity = "Rare",
			Duplicate = false,
			Refund = 0,
			Reel = reel,
			WinIndex = 28,
			Paid = "Coins",
		})
		client:advance(CConfig.Crates.Reel.SpinSeconds + CConfig.Crates.Reel.RevealDelay + 1)
		local card = gui.Crates.Body.Opening.Reveal.Card
		local badge = card:FindFirstChild("CatalogBadge", true)
		expect(badge).toBeTruthy()
		expect(badge:FindFirstChild("Picture", true).Image).toMatch("id=1003")
	end)
end)
