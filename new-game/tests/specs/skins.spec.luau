-- Crate skins (src/shared/Config/Skins/): the catalogue rules (6 themes x 20 skins with
-- 12/5/2/1 rarities, ids, crates, prices), every Style option points at something real, the
-- rarity looks (Common < Uncommon < Rare < CRAZY), and every skin previews, goes on R15 and
-- R6 characters and comes off leaving the avatar exactly as it was. Also the shop dressing a
-- respawned character, the client SkinFx effects and the paged Skins tab of ShopUI.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect
local typeof = Runtime.typeof

local rt = Runtime.new()
local env = rt.env
local CFrame, Vector3, Color3, Enum = env.CFrame, env.Vector3, env.Color3, env.Enum
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Items = rt:require("ReplicatedStorage.Shared.Items")
local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
local HeadPieces = rt:require("ReplicatedStorage.Shared.HeadPieces")
local Tags = rt:require("ReplicatedStorage.Shared.Tags")
local SkinAnimate = rt:require("ReplicatedStorage.Shared.SkinAnimate")
local SkinMotion = rt:require("ReplicatedStorage.Shared.SkinMotion")
local CollectionService = rt.game:GetService("CollectionService")

local THEMES = { "Pumpkin", "Candy", "Spooky", "Graveyard", "Monster", "Moonlight" }
local COUNTS = { Common = 12, Uncommon = 5, Rare = 2, Crazy = 1 } -- the six classic themes
local NEWER_COUNTS = { Common = 13, Uncommon = 5, Rare = 3, Crazy = 0 } -- the 24 newer themes (+ one in a million in 3)
local CLASSIC = { "Skeleton", "PumpkinHead", "Zombie", "Ghost", "Mummy", "KingSkin" }

-- Every Style key a skin may use (a typo here would silently do nothing in game).
local STYLE_KEYS = {
	Kind = "string",
	BodyColor = "Color3",
	HeadColor = "Color3",
	TorsoColor = "Color3",
	ArmsColor = "Color3",
	LegsColor = "Color3",
	HeadColor2 = "Color3",
	HeadColor3 = "Color3",
	GlowColor = "Color3",
	Material = "EnumItem",
	HeadMaterial = "EnumItem",
	TorsoMaterial = "EnumItem",
	ArmsMaterial = "EnumItem",
	LegsMaterial = "EnumItem",
	Transparency = "number",
	HideClothes = "boolean",
	Accent = "table",
	Head = "string",
	Face = "string",
	Glow = "table",
	Aura = "table",
	Crazy = "table",
	Animate = "table", -- moving pieces and colour effects (src/shared/SkinAnimate.luau)
	Motion = { "string", "table" }, -- a walk style (src/shared/SkinMotion.luau)
}

local function crateSkins(): { any }
	local list = {}
	for _, item in Config.Shop.Items do
		if item.Slot == "Skin" and item.Theme ~= nil and not item.Exclusive then
			table.insert(list, item)
		end
	end
	return list
end

-- Every skin sold or in a crate (an Exclusive one, like the Tormented Tower's, is checked in
-- towerrun.spec).
local function skins(): { any }
	local list = {}
	for _, item in Items.ForSlot("Skin") do
		if not item.Exclusive then
			table.insert(list, item)
		end
	end
	return list
end

-- Fails if game code warned while running fn.
local function noWarnings(fn: () -> ())
	local before = #rt.warnings
	fn()
	if #rt.warnings > before then
		error("game code warned: " .. table.concat(rt.warnings, " | ", before + 1))
	end
end

describe("Skin catalogue", function()
	it("has every theme (the six classic ones too), each with its crate", function()
		local ids = {}
		for _, theme in Config.Skins.Themes do
			table.insert(ids, theme.Id)
			expect(theme.Crate).toBe(theme.Id .. "Crate")
			expect(theme.Name).toBeA("string")
			expect(typeof(theme.Color)).toBe("Color3")
		end
		for _, id in THEMES do
			expect(ids).toContain(id)
		end
	end)

	it(
		"has about 630 skins: 6 classic themes of 20, 24 newer themes of 21 (+3 one in a million)",
		function()
			expect(#Config.Skins.Themes).toBe(30)
			local million = 0
			for _, theme in Config.Skins.Themes do
				local classic = table.find(THEMES, theme.Id) ~= nil
				local counts = { Common = 0, Uncommon = 0, Rare = 0, Crazy = 0 }
				local hasMillion = false
				for _, item in crateSkins() do
					if item.Theme == theme.Id then
						if item.OneInAMillion then
							hasMillion = true
							million += 1
						else
							counts[item.Rarity] += 1
						end
					end
				end
				local want = if classic then COUNTS else NEWER_COUNTS
				for rarity, n in want do
					if counts[rarity] ~= n then
						error(
							("%s has %d %s skins, wants %d"):format(
								theme.Id,
								counts[rarity],
								rarity,
								n
							)
						)
					end
				end
				expect(#Items.ByCrate(theme.Crate)).toBe(
					(if classic then 20 else 21) + (if hasMillion then 1 else 0)
				)
			end
			expect(million).toBe(3)
			local total = #skins() + 1 -- (+ the Tormented Tower's own skin)
			expect(total).toBeGreaterThanOrEqual(600)
			expect(total).toBeLessThanOrEqual(660)
			T.note(total, "skins in the game")
		end
	)

	it("has exactly 10 CRAZY skins, 3 of them ONE IN A MILLION", function()
		local crazy, million = 0, 0
		for _, item in Config.Shop.Items do
			if Items.Rarity(item) == "Crazy" then
				crazy += 1
				if item.OneInAMillion then
					million += 1
					expect(item.Odds).toBe(0.0001)
					expect(type(item.Style.Crazy.Effect)).toBe("string") -- its own animated effect
				end
			end
		end
		expect(crazy).toBe(10)
		expect(million).toBe(3)
	end)

	it("makes every skin look clearly different (no two share a look)", function()
		local function c(v: any): string
			return if typeof(v) == "Color3"
				then ("%d,%d,%d"):format(v.R * 255 + 0.5, v.G * 255 + 0.5, v.B * 255 + 0.5)
				else tostring(v)
		end
		local seen: { [string]: string } = {}
		for _, item in Config.Shop.Items do
			if item.Slot ~= "Skin" then
				continue
			end
			local s = item.Style
			local accent = s.Accent or {}
			local pattern = accent.Pattern
			if type(pattern) == "table" then
				pattern = table.concat(pattern, "+")
			end
			local key = table.concat({
				tostring(s.Head),
				c(s.HeadColor),
				c(s.HeadColor2),
				c(s.BodyColor),
				c(s.TorsoColor),
				c(s.ArmsColor),
				c(s.LegsColor),
				tostring(s.Material),
				c(accent.Color),
				tostring(pattern),
			}, "|")
			if seen[key] then
				error(("%s and %s look the same"):format(seen[key], item.Id))
			end
			seen[key] = item.Id
		end
	end)

	it("gives every crate skin a unique theme-prefixed PascalCase Id and a unique Name", function()
		local ids, names = {}, {}
		for _, item in skins() do
			if ids[item.Id] then
				error("duplicate skin Id " .. item.Id)
			end
			ids[item.Id] = true
		end
		for _, item in crateSkins() do
			local prefix, rest = string.match(item.Id, "^(%u%a+)_(%u%w+)$")
			if prefix ~= item.Theme or not rest then
				error(("%s should look like %s_SomeName"):format(item.Id, item.Theme))
			end
			expect(item.Name).toBeA("string")
			if names[item.Name] then
				error(("%s and %s are both called %q"):format(names[item.Name], item.Id, item.Name))
			end
			names[item.Name] = item.Id
		end
	end)

	it(
		"fills Slot, Crate, Kind and HideClothes, and sells every skin at its rarity price",
		function()
			for _, item in crateSkins() do
				expect(item.Slot).toBe("Skin")
				expect(item.Crate).toBe(item.Theme .. "Crate")
				expect(item.Style.Kind).toBe("Skin")
				expect(item.Style.HideClothes).toBe(true)
				expect(item.Price).toBeNil()
				expect(Items.Price(item)).toBe(Config.Rarity.Levels[item.Rarity].Price)
				expect(Items.CanBuyDirect(item)).toBe(true)
			end
		end
	)

	it("keeps the six classic skins, with rarities and outside the crates", function()
		for _, id in CLASSIC do
			local item = Items.Get(id)
			expect(item).toBeTruthy()
			expect(item.Slot).toBe("Skin")
			expect(Config.Rarity.Levels[item.Rarity]).toBeTruthy()
			expect(item.Crate).toBeNil()
		end
	end)
end)

describe("Skin styles", function()
	it("only uses known Style keys of the right type", function()
		for _, item in skins() do
			for key, value in item.Style do
				local want = STYLE_KEYS[key]
				if not want then
					error(("%s: unknown Style key %s (typo?)"):format(item.Id, key))
				end
				local wants = if type(want) == "table" then want else { want }
				if not table.find(wants, typeof(value)) then
					error(
						("%s: Style.%s should be a %s"):format(
							item.Id,
							key,
							table.concat(wants, " or ")
						)
					)
				end
				local isMaterial = want ~= "EnumItem"
					or pcall(function()
						assert(Enum.Material[value.Name] == value)
					end)
				if not isMaterial then
					error(("%s: Style.%s should be an Enum.Material"):format(item.Id, key))
				end
			end
		end
	end)

	it("gives every skin valid animations and walk styles (no errors, no warnings)", function()
		for _, item in skins() do
			local style = item.Style
			local _, errors, warnings = SkinAnimate.Normalize(style.Animate, style)
			local _, motionErrors = SkinMotion.Normalize(style.Motion)
			for _, list in { errors, warnings, motionErrors } do
				if #list > 0 then
					error(("%s: %s"):format(item.Id, table.concat(list, "; ")))
				end
			end
		end
	end)

	it("points every Head, Face, Accent, Aura and Orbit at something that exists", function()
		for _, item in skins() do
			local style = item.Style
			if style.Head then
				expect(HeadPieces.Has(style.Head)).toBe(true)
				expect(Cosmetics.HasLook(style.Head)).toBe(true)
			end
			if style.Face then
				expect(HeadPieces.Faces).toContain(style.Face)
			end
			if style.Accent then
				local pattern = style.Accent.Pattern
				local list = if type(pattern) == "table" then pattern else { pattern }
				expect(#list).toBeGreaterThan(0)
				for _, name in list do
					if not Cosmetics.HasPattern(name) then
						error(("%s: no accent pattern %s"):format(item.Id, tostring(name)))
					end
				end
				if style.Accent.Color ~= nil then
					expect(typeof(style.Accent.Color)).toBe("Color3")
				end
			end
			if style.Aura then
				expect(Config.Skins.Auras[style.Aura.Kind]).toBeTruthy()
			end
			if style.Glow then
				expect(typeof(style.Glow.Color)).toBe("Color3")
			end
			if style.Crazy then
				expect(HeadPieces.OrbitKinds).toContain(style.Crazy.Orbit)
			end
		end
	end)

	it("makes each rarity look better than the one below", function()
		local crazyHeads = {}
		for _, item in crateSkins() do
			local s = item.Style
			local id = item.Id
			if item.Rarity == "Common" then
				if s.Head or s.Glow or s.Aura or s.Crazy then
					error(id .. ": Commons are colours, materials and accents only")
				end
				expect(s.BodyColor or s.TorsoColor).toBeTruthy()
			elseif item.Rarity == "Uncommon" then
				if not s.Head or s.Glow or s.Aura or s.Crazy then
					error(
						id .. ": Uncommons add a head piece (no glow, particles or CRAZY effects)"
					)
				end
			elseif item.Rarity == "Rare" then
				if not (s.Head and s.Glow and s.Aura) or s.Crazy then
					error(id .. ": Rares have a head piece, a glow and particles")
				end
			else
				if not (s.Head and s.Glow and s.Aura and s.Crazy) then
					error(id .. ": CRAZY skins have everything")
				end
				expect(s.Crazy.Rainbow).toBe(true)
				expect(s.Crazy.Orbit).toBeA("string")
				crazyHeads[s.Head] = id
			end
		end
		-- A CRAZY head belongs to that skin only.
		for _, item in skins() do
			local owner = crazyHeads[item.Style.Head]
			if owner and owner ~= item.Id then
				error(("%s uses %s, the CRAZY head of %s"):format(item.Id, item.Style.Head, owner))
			end
		end
	end)
end)

describe("Skin previews", function()
	for _, item in skins() do
		it("previews " .. item.Id, function()
			noWarnings(function()
				local model = Cosmetics.Preview(item)
				expect(model.PrimaryPart).toBeInstanceOf("BasePart")
				local _, size = model:GetBoundingBox()
				expect(size).toBeFinite()
				local style = item.Style
				local torso = model:FindFirstChild("Torso")
				if style.HideClothes then
					local want = style.TorsoColor or style.BodyColor
					if want then
						expect(torso.Color).toBeNear(want)
					end
				end
				if style.Head then
					expect(model:FindFirstChild("Cosmetic_Skin")).toBeInstanceOf("Model")
					expect(model.Head.Transparency).toBe(1)
				end
				if style.Glow then
					expect(model:FindFirstChild("GlowHalo", true)).toBeInstanceOf("BasePart")
				end
				if style.Aura then
					expect(model:FindFirstChild("AuraBit", true)).toBeInstanceOf("BasePart")
				end
				if style.Crazy then
					expect(model:FindFirstChild("Orbit_" .. style.Crazy.Orbit, true)).toBeInstanceOf(
						"Model"
					)
					local rainbow = 0
					for _, d in model:GetDescendants() do
						if d:GetAttribute("Rainbow") then
							rainbow += 1
						end
					end
					expect(rainbow).toBeGreaterThan(0)
				end
				model:Destroy()
			end)
		end)
	end
end)

-- What a character looks like: every part's colour, material and transparency, decal
-- transparency, the direct children's names, and the character's attributes.
local function snapshot(character: any): { [string]: any }
	local shot = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			shot[d:GetFullName()] = { d.Color, d.Material, d.Transparency }
		elseif d:IsA("Decal") then
			shot[d:GetFullName()] = d.Transparency
		end
	end
	local children = {}
	for _, child in character:GetChildren() do
		table.insert(children, child.ClassName .. ":" .. child.Name)
	end
	table.sort(children)
	shot.Children = table.concat(children, ",")
	shot.HatLift = tostring(character:GetAttribute("HatLift"))
	shot.SkinMotion = tostring(character:GetAttribute("SkinMotion"))
	shot.SkinMotionIds = tostring(character:GetAttribute("SkinMotionIds"))
	return shot
end

local function sameLook(before: { [string]: any }, after: { [string]: any }, what: string)
	for key, value in before do
		local now = after[key]
		if type(value) == "table" then
			if not now then
				error(what .. ": " .. key .. " is gone")
			end
			expect(now[1]).toBeNear(value[1], 1e-4)
			if now[2] ~= value[2] or math.abs(now[3] - value[3]) > 1e-6 then
				error(
					("%s: %s is %s %s, was %s %s"):format(
						what,
						key,
						tostring(now[2]),
						now[3],
						tostring(value[2]),
						value[3]
					)
				)
			end
		elseif now ~= value then
			error(("%s: %s is %s, was %s"):format(what, key, tostring(now), tostring(value)))
		end
	end
	for key in after do
		if before[key] == nil then
			error(what .. ": " .. key .. " was left behind")
		end
	end
end

-- An R6 character (Torso, Left Arm, ...) with a face, a hair accessory and clothes.
local function r6Character(name: string): any
	local m = rt:create("Model", { Name = name }, rt.workspace)
	local skin = Color3.fromRGB(250, 200, 160)
	local function limb(partName: string, size: any, at: any): any
		return rt:create(
			"Part",
			{ Name = partName, Size = size, CFrame = CFrame.new(at), Color = skin },
			m
		)
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(30, 3, 0))
	root.Transparency = 1
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(30, 3, 0))
	local head = limb("Head", Vector3.new(2, 1, 1), Vector3.new(30, 4.5, 0))
	rt:create("Decal", { Name = "face" }, head)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		limb(prefix .. " Arm", Vector3.new(1, 2, 1), Vector3.new(30 + side * 1.5, 3, 0))
		limb(prefix .. " Leg", Vector3.new(1, 2, 1), Vector3.new(30 + side * 0.5, 1, 0))
	end
	local hair = rt:create("Accessory", { Name = "Hair" }, m)
	local handle = rt:create("Part", { Name = "Handle", Size = Vector3.new(2, 0.5, 1) }, hair)
	rt:create("Weld", { Part0 = handle, Part1 = head }, handle)
	-- a layered-clothing jacket (an accessory whose handle has a WrapLayer)
	local jacket = rt:create("Accessory", { Name = "Jacket" }, m)
	local jacketHandle =
		rt:create("Part", { Name = "Handle", Size = Vector3.new(2.2, 2.2, 1.2) }, jacket)
	rt:create("WrapLayer", {}, jacketHandle)
	for _, className in { "BodyColors", "Shirt", "Pants" } do
		rt:create(className, {}, m)
	end
	rt:create("Humanoid", {}, m)
	m.PrimaryPart = root
	return m
end

describe("Wearing skins", function()
	local player = rt:addPlayer({ Name = "SkinTester" })
	local r15 = player.Character
	local r6 = r6Character("R6Tester")

	local function check(character: any, item: any, rig: string)
		local before = snapshot(character)
		noWarnings(function()
			expect(Cosmetics.Wear(character, item)).toBe(true)
		end)
		local style = item.Style
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		local arm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
		local want = style.TorsoColor or style.BodyColor
		if want then
			expect(torso.Color).toBeNear(want)
		end
		want = style.ArmsColor or style.BodyColor
		if want then
			expect(arm.Color).toBeNear(want)
		end
		if style.HideClothes then
			expect(character:FindFirstChildOfClass("Shirt")).toBeNil()
			local jacket = character:FindFirstChild("Jacket")
			if jacket then
				expect(jacket.Handle.Transparency).toBe(1)
			end
		end
		local model = character:FindFirstChild("Cosmetic_Skin")
		if style.Head or style.Accent or style.Glow or style.Aura or style.Crazy then
			expect(model).toBeInstanceOf("Model")
			expect(model:GetAttribute("ItemId")).toBe(item.Id)
			-- everything is joined on and nothing collides: each piece is welded to a body part
			-- or to a moving group's AnimPivot, and each AnimPivot's SkinMotor joins it to a body
			-- part or another pivot, so the chain always ends at a body part
			local function joinedTo(d: any): any
				if d:GetAttribute("AnimGroup") ~= nil then
					local motor = d:FindFirstChild("SkinMotor")
					expect(motor).toBeInstanceOf("Motor6D")
					expect(motor.Part1).toBe(d)
					return motor.Part0
				end
				local weld = d:FindFirstChildOfClass("WeldConstraint")
				expect(weld).toBeTruthy()
				local to = weld.Part0
				if to:IsDescendantOf(model) then
					expect(to:GetAttribute("AnimGroup")).toBeA("string") -- only pivots, in the model
				end
				return to
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.Anchored).toBe(false)
					expect(d.CanCollide).toBe(false)
					local at, steps = d, 0
					while at:IsDescendantOf(model) do
						at = joinedTo(at)
						steps += 1
						expect(steps).toBeLessThan(5)
					end
					expect(at:IsDescendantOf(character)).toBe(true)
				end
			end
		end
		if style.Head then
			expect(character.Head.Transparency).toBe(1)
			expect(character:GetAttribute("HatLift")).toBeA("number")
		end
		if style.Glow then
			local light = model:FindFirstChild("SkinGlow", true)
			expect(light).toBeInstanceOf("PointLight")
			expect(light.Color).toBeNear(style.Glow.Color)
		end
		if style.Aura then
			expect(model:FindFirstChild("SkinAura", true)).toBeTruthy()
			local emitter = model:FindFirstChildOfClass("Part")
				and model:FindFirstChild("SkinAura", true)
			expect(emitter).toBeTruthy()
		end
		if style.Accent then
			local accents = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and Cosmetics.HasPattern(d:GetAttribute("SkinPart")) then
					accents += 1
				end
			end
			if accents == 0 then
				error(("%s on %s: no accent pieces"):format(item.Id, rig))
			end
		end
		expect(CollectionService:HasTag(model or character, Tags.SkinFx)).toBe(style.Crazy ~= nil)
		Cosmetics.TakeOff(character, "Skin")
		sameLook(before, snapshot(character), item.Id .. " on " .. rig)
	end

	for _, item in skins() do
		it("puts on and takes off " .. item.Id .. " (R15 and R6)", function()
			check(r15, item, "R15")
			check(r6, item, "R6")
		end)
	end

	it("keeps every skin light enough for 20 players (parts added to a character)", function()
		local most, who = 0, ""
		for _, item in skins() do
			Cosmetics.Wear(r15, item)
			local model = r15:FindFirstChild("Cosmetic_Skin")
			local count = 0
			if model then
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						count += 1
					end
				end
			end
			if count > most then
				most, who = count, item.Id
			end
			Cosmetics.TakeOff(r15, "Skin")
		end
		T.note(("most parts: %d (%s)"):format(most, who))
		expect(most).toBeLessThanOrEqual(120)
	end)

	it("swaps one skin for another and still restores the avatar", function()
		local before = snapshot(r15)
		local list = crateSkins()
		for i = 1, #list, 7 do
			Cosmetics.Wear(r15, list[i])
		end
		Cosmetics.Wear(r15, Items.Get("Moonlight_LunarLegend"))
		Cosmetics.Wear(r15, Items.Get("Graveyard_SkellySuit"))
		Cosmetics.TakeOff(r15, "Skin")
		sameLook(before, snapshot(r15), "after swapping skins")
	end)

	it("puts a hat on top of a skin's head piece", function()
		local hat = Items.Get("PumpkinCap")
		Cosmetics.Wear(r15, Items.Get("Pumpkin_SirGourdington"))
		Cosmetics.Wear(r15, hat)
		local lift = r15:GetAttribute("HatLift")
		expect(lift).toBeGreaterThan(0.5)
		local head = r15.Head
		expect(r15.Cosmetic_Hat:GetPivot()).toBeNear(
			head.CFrame * CFrame.new(0, head.Size.Y / 2 + lift, 0),
			1e-3
		)
		Cosmetics.TakeOff(r15, "Hat")
		Cosmetics.TakeOff(r15, "Skin")
	end)
end)

describe("Skins on respawn (ShopService)", function()
	local server = Runtime.new()
	local DataService = server:require("ServerScriptService.Server.Services.DataService")
	local ShopService = server:require("ServerScriptService.Server.Services.ShopService")
	DataService.Start()
	ShopService.Start()
	local player = server:addPlayer({ Name = "Respawner" })
	server:advance(3)

	it("dresses every new character in the equipped CRAZY skin", function()
		local data = DataService.Get(player)
		expect(data).toBeTruthy()
		data.Owned.Candy_SugarRushSupreme = true
		local equip = server:find("ReplicatedStorage.Remotes.EquipItem")
		server:invokeServer(equip, player, "Skin", "Candy_SugarRushSupreme")
		local model = player.Character:FindFirstChild("Cosmetic_Skin")
		expect(model).toBeInstanceOf("Model")
		local CS = server.game:GetService("CollectionService")
		expect(CS:HasTag(model, Tags.SkinFx)).toBe(true)
		server:spawnCharacter(player)
		server:advance(1)
		local again = player.Character:FindFirstChild("Cosmetic_Skin")
		expect(again).toBeInstanceOf("Model")
		expect(again:GetAttribute("ItemId")).toBe("Candy_SugarRushSupreme")
		expect(CS:HasTag(again, Tags.SkinFx)).toBe(true)
	end)

	it("refuses a skin the player doesn't own, and unequips cleanly", function()
		local equip = server:find("ReplicatedStorage.Remotes.EquipItem")
		server:advance(1) -- past the request cooldown
		local state = server:invokeServer(equip, player, "Skin", "Moonlight_LunarLegend")
		expect(state.Equipped.Skin).toBe("Candy_SugarRushSupreme")
		server:advance(1)
		state = server:invokeServer(equip, player, "Skin", "")
		expect(state.Equipped.Skin).toBe("")
		expect(player.Character:FindFirstChild("Cosmetic_Skin")).toBeNil()
	end)
end)

describe("SkinFx (client)", function()
	local client = Runtime.new({ client = true })
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	local CTags = client:require("ReplicatedStorage.Shared.Tags")
	local SkinFx = client:require("StarterPlayer.StarterPlayerScripts.Client.SkinFx")
	local CS = client.game:GetService("CollectionService")
	local cenv = client.env

	-- A character with a tagged CRAZY skin model, like the server makes.
	local function crazyCharacter(name: string, x: number, id: string): any
		local m = client:create("Model", { Name = name }, client.workspace)
		local root = client:create("Part", {
			Name = "HumanoidRootPart",
			Size = cenv.Vector3.new(2, 2, 1),
			CFrame = cenv.CFrame.new(x, 3, 0),
		}, m)
		m.PrimaryPart = root
		local skin = client:create("Model", { Name = "Cosmetic_Skin" }, m)
		skin:SetAttribute("ItemId", id)
		local gem = client:create("Part", { Name = "Gem", Color = cenv.Color3.new(1, 0, 0) }, skin)
		gem:SetAttribute("Rainbow", true)
		local holder = client:create("Part", { Name = "SkinAura" }, skin)
		client:create("PointLight", { Name = "SkinGlow", Brightness = 2 }, holder)
		CS:AddTag(skin, CTags.SkinFx)
		return m
	end

	it("animates the closest CRAZY players, up to MaxAnimated, and cleans up", function()
		SkinFx.Start()
		local fx = CConfig.Skins.Effects
		local characters = {}
		for i = 1, fx.MaxAnimated + 2 do
			table.insert(
				characters,
				crazyCharacter("Crazy" .. i, i * 5, "Pumpkin_MegaGourdSupreme")
			)
		end
		client:advance(1)
		local tints = 0
		for _, c in characters do
			if c.Cosmetic_Skin:FindFirstChild("SkinFxTint") then
				tints += 1
			end
		end
		expect(tints).toBe(fx.MaxAnimated)
		local folder = client.workspace:FindFirstChild("LocalSkinFx")
		expect(folder).toBeTruthy()
		expect(#folder:GetChildren()).toBe(fx.MaxAnimated * 3) -- 3 pumpkins each
		-- the gem cycles through the rainbow, the glow pulses
		local gem = characters[1].Cosmetic_Skin.Gem
		local first = gem.Color
		client:advance(0.5)
		expect(
			(gem.Color.R - first.R) ^ 2 + (gem.Color.G - first.G) ^ 2 + (gem.Color.B - first.B) ^ 2
		).toBeGreaterThan(0)
		-- a skin coming off removes its effects
		for _, c in characters do
			c.Cosmetic_Skin:Destroy()
		end
		client:advance(1)
		expect(#folder:GetChildren()).toBe(0)
	end)

	it("never animates a Hide & Seek hider in disguise", function()
		local player = client:addPlayer({ Name = "Hider", character = false })
		local character = crazyCharacter("HiderBody", 4, "Pumpkin_MegaGourdSupreme")
		player.Character = character
		client:advance(1)
		expect(character.Cosmetic_Skin:FindFirstChild("SkinFxTint")).toBeTruthy()
		player:SetAttribute("HideSeekRole", "Hider")
		client:advance(1)
		expect(character.Cosmetic_Skin:FindFirstChild("SkinFxTint")).toBeNil()
		expect(#client.workspace.LocalSkinFx:GetChildren()).toBe(0)
		player:SetAttribute("HideSeekRole", nil) -- the round is over
		client:advance(1)
		expect(character.Cosmetic_Skin:FindFirstChild("SkinFxTint")).toBeTruthy()
		character:Destroy()
		client:removePlayer(player)
		client:advance(1)
	end)

	it("cycles a preview's rainbow parts and stops when asked", function()
		local model = client:create("Model", { Name = "Preview" })
		local p = client:create("Part", { Name = "Gem" }, model)
		p:SetAttribute("Rainbow", true)
		local stop = SkinFx.AnimatePreview(model)
		expect(stop).toBeA("function")
		stop()
	end)
end)

describe("ShopUI Skins tab", function()
	local client = Runtime.new({ client = true })
	local Shared = client:find("ReplicatedStorage")
	local remotes = client:create("Folder", { Name = "Remotes" }, Shared)
	for _, name in { "GetShopState", "BuyItem", "EquipItem" } do
		client:create("RemoteFunction", { Name = name }, remotes)
	end
	local shopState = client:create("RemoteEvent", { Name = "ShopState" }, remotes)
	local Client = client:find("StarterPlayer.StarterPlayerScripts.Client")
	local CConfig = client:require("ReplicatedStorage.Shared.Config")
	local gui = client:create("ScreenGui", { Name = "GameUI" })
	client:require(Client.Layout).Mount(gui)
	client:require(Client.PanelManager).Mount(gui)
	local ShopUI = client:require(Client.ShopUI)
	ShopUI.Mount(gui)
	client:advance(1)
	local owned = { "Pumpkin_PumpkinSpice", "Candy_SugarRushSupreme", "Zombie" }
	client:fire(shopState, "OnClientEvent", {
		Ready = true,
		Coins = 500,
		Owned = owned,
		Equipped = { Skin = "Zombie", Hat = "", Trail = "", Pet = "" },
		Vip = false,
	})
	local panel = gui.Shop
	local list = panel:FindFirstChildOfClass("ScrollingFrame") and nil

	local function cards(): { any }
		local out = {}
		for _, frame in panel:GetDescendants() do
			if frame:IsA("Frame") and frame:FindFirstChild("RarityBorder") then
				table.insert(out, frame)
			end
		end
		return out
	end

	local function viewports(): { any }
		local out = {}
		for _, d in panel:GetDescendants() do
			if d:IsA("ViewportFrame") then
				table.insert(out, d)
			end
		end
		return out
	end

	it("shows one page of skin cards with rarity borders and a pager", function()
		ShopUI.Open("Skin")
		client:advance(0.5)
		expect(panel.Visible).toBe(true)
		local page = CConfig.Skins.Shop.PageSize
		expect(#cards()).toBe(page)
		expect(panel.Pager.Visible).toBe(true)
		local total = #Items.ForSlot("Skin")
		local label = panel.Pager:FindFirstChildOfClass("TextLabel")
		expect(label.Text).toBe(("Page 1 / %d"):format(math.ceil(total / page)))
		client:fire(panel.Pager.Next, "Activated")
		expect(label.Text).toBe(("Page 2 / %d"):format(math.ceil(total / page)))
		local _ = list
	end)

	it("keeps the previews when only coins or ownership change", function()
		local before = viewports()
		client:fire(shopState, "OnClientEvent", {
			Ready = true,
			Coins = 99999,
			Owned = owned,
			Equipped = { Skin = "", Hat = "", Trail = "", Pet = "" },
			Vip = false,
		})
		client:advance(0.2)
		local after = viewports()
		expect(#after).toBe(#before)
		for i, v in before do
			expect(after[i]).toBe(v)
		end
	end)

	it("filters by rarity, theme and Owned", function()
		client:fire(panel.Filters.RarityCrazyFilter, "Activated")
		expect(#cards()).toBe(9) -- the CRAZY skins on sale (the tower's is hidden until won)
		client:fire(panel.Filters.RarityAnyFilter, "Activated")
		-- The theme chip opens a dropdown of every theme.
		client:fire(panel.Filters.ThemeFilter, "Activated")
		expect(panel.ThemeMenu.Visible).toBe(true)
		client:fire(panel.ThemeMenu.Theme_Pumpkin, "Activated")
		expect(panel.ThemeMenu.Visible).toBe(false)
		local shown = cards()
		expect(#shown).toBe(math.min(20, CConfig.Skins.Shop.PageSize))
		client:fire(panel.Filters.OwnedFilter, "Activated")
		expect(#cards()).toBe(1) -- Pumpkin Spice
		ShopUI.Open("Skin", { Owned = true })
		expect(#cards()).toBe(3)
		ShopUI.Open("Skin", { Rarity = "Crazy", Theme = "Candy" })
		expect(#cards()).toBe(1)
	end)

	it("frees the previews when the shop closes", function()
		panel.Visible = false
		client:advance(0.1)
		expect(#viewports()).toBe(0)
	end)
end)
