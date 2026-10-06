--[[
	Skin catwalk (from new-game/): dresses mannequins in skins inside the test harness and writes a
	scene JSON for the offline previewer (cloud tooling, outside the repo), like tests/preview.luau.

	  lune run tests/catwalk                       -- every theme: 3 Commons, an Uncommon, both
	                                                  Rares and the CRAZY skin, one row per theme
	  lune run tests/catwalk -- theme Pumpkin      -- all 20 skins of one theme (two rows)
	  lune run tests/catwalk -- ids A,B,C          -- these skin ids in one row
	  lune run tests/catwalk -- ... --look preview  -- the shop/crate stand-in (Cosmetics.Preview)
	                                                  instead of real R15 + R6 characters (Wear)
	  lune run tests/catwalk -- ... --out tests/out/x.json

	Default output tests/out/catwalk.json. It prints the render command; characters face -Z, so
	the printed camera looks at them from the front. With --look wear (the default) each skin is
	worn by an R15 mannequin, and the row behind it shows the same skin on an R6 mannequin.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Runtime = require("./harness/Runtime")

local DEFAULT_EXPORTER = "/tmp/claude-0/render/export.luau"
local SPACING = 8 -- studs between mannequins
local ROW_GAP = 40 -- studs between rows (far apart, so one row's camera sees only that row)

local function fail(message: string)
	print("catwalk: " .. message)
	process.exit(1)
	error(message)
end

-- Arguments -------------------------------------------------------------------------------------

local mode, value = "sample", nil
local look = "wear"
local rig = "r15"
local fx = true
local output = "tests/out/catwalk.json"
local exporterPath = process.env.ROBLOX_PREVIEW_EXPORTER or DEFAULT_EXPORTER
do
	local args = process.args
	local i = 1
	while i <= #args do
		local arg = args[i]
		if arg == "--" then
			-- Lune 0.10 passes the "--" separator through: skip it.
		elseif arg == "--look" then
			look = args[i + 1] or fail("--look needs wear or preview")
			i += 1
		elseif arg == "--rig" then
			rig = args[i + 1] or fail("--rig needs r15 or r6")
			i += 1
		elseif arg == "--no-fx" then
			fx = false
		elseif arg == "--out" then
			output = args[i + 1] or fail("--out needs a path")
			i += 1
		elseif arg == "--exporter" then
			exporterPath = args[i + 1] or fail("--exporter needs a path")
			i += 1
		elseif arg == "theme" or arg == "ids" or arg == "sample" then
			mode, value = arg, args[i + 1] or fail(arg .. " needs a value")
			i += 1
		else
			fail("unknown argument " .. arg)
		end
		i += 1
	end
end
if not fs.isFile(exporterPath) then
	fail("can't find the scene exporter at " .. exporterPath .. " (cloud preview tooling)")
end
local Export = luau.load(fs.readFile(exporterPath), { debugName = exporterPath })()

local rt = Runtime.new({ echo = "warn" })
local env = rt.env
local CFrame, Vector3, Color3, Enum = env.CFrame, env.Vector3, env.Color3, env.Enum
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
local HeadPieces = rt:require("ReplicatedStorage.Shared.HeadPieces")
local Items = rt:require("ReplicatedStorage.Shared.Items")

-- Which skins ------------------------------------------------------------------------------------

local function themeSkins(theme: string): { any }
	local list = {}
	for _, item in Config.Shop.Items do
		if item.Slot == "Skin" and item.Theme == theme then
			table.insert(list, item)
		end
	end
	return list
end

local function byRarity(list: { any }, rarity: string): { any }
	local out = {}
	for _, item in list do
		if Items.Rarity(item) == rarity then
			table.insert(out, item)
		end
	end
	return out
end

local rows: { { any } } = {}
if mode == "sample" then
	for _, theme in Config.Skins.Themes do
		if value and theme.Id ~= value then
			continue
		end
		local all = themeSkins(theme.Id)
		local row = {}
		local commons = byRarity(all, "Common")
		for i = 1, math.min(3, #commons) do
			table.insert(row, commons[i])
		end
		local uncommon = byRarity(all, "Uncommon")[1]
		if uncommon then
			table.insert(row, uncommon)
		end
		for _, item in byRarity(all, "Rare") do
			table.insert(row, item)
		end
		for _, item in byRarity(all, "Crazy") do
			table.insert(row, item)
		end
		if #row > 0 then
			table.insert(rows, row)
		end
	end
elseif mode == "theme" then
	local all = themeSkins(value)
	if #all == 0 then
		fail("no skins in theme " .. tostring(value))
	end
	table.insert(rows, {})
	for i, item in all do
		if i > 10 and #rows == 1 then
			table.insert(rows, {})
		end
		table.insert(rows[#rows], item)
	end
else
	local row = {}
	for id in string.gmatch(value, "[^,]+") do
		local item = Items.Get(id) or fail("no item " .. id)
		table.insert(row, item)
	end
	table.insert(rows, row)
end

-- Mannequins -------------------------------------------------------------------------------------

local SKIN = Color3.fromRGB(255, 205, 160)
local SHIRT = Color3.fromRGB(90, 110, 160)
local PANTS = Color3.fromRGB(60, 60, 80)

local function rigPart(model: any, name: string, size: any, at: any, color: any): any
	return rt:create("Part", {
		Name = name,
		Size = size,
		CFrame = at,
		Color = color,
		Anchored = true,
	}, model)
end

-- An R15 character standing on y = 0 at `x, z` (default block body proportions).
local function r15(name: string, x: number, z: number): any
	local m = rt:create("Model", { Name = name })
	local function at(px: number, py: number): any
		return CFrame.new(x + px, py, z)
	end
	local root = rigPart(m, "HumanoidRootPart", Vector3.new(2, 2, 1), at(0, 3.4), SKIN)
	root.Transparency = 1
	rigPart(m, "LowerTorso", Vector3.new(2, 0.4, 1), at(0, 2.8), PANTS)
	rigPart(m, "UpperTorso", Vector3.new(2, 1.6, 1), at(0, 3.8), SHIRT)
	local head = rigPart(m, "Head", Vector3.new(1.2, 1.2, 1.2), at(0, 5.2), SKIN)
	rt:create(
		"SpecialMesh",
		{ MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25) },
		head
	)
	rt:create("Decal", { Name = "face" }, head)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		rigPart(m, prefix .. "UpperArm", Vector3.new(1, 1.1, 1), at(side * 1.5, 4.05), SHIRT)
		rigPart(m, prefix .. "LowerArm", Vector3.new(1, 1.0, 1), at(side * 1.5, 3.0), SKIN)
		rigPart(m, prefix .. "Hand", Vector3.new(1, 0.3, 1), at(side * 1.5, 2.35), SKIN)
		rigPart(m, prefix .. "UpperLeg", Vector3.new(1, 1.2, 1), at(side * 0.5, 2.0), PANTS)
		rigPart(m, prefix .. "LowerLeg", Vector3.new(1, 1.1, 1), at(side * 0.5, 0.85), PANTS)
		rigPart(
			m,
			prefix .. "Foot",
			Vector3.new(1, 0.3, 1),
			at(side * 0.5, 0.15),
			Color3.fromRGB(40, 35, 45)
		)
	end
	rt:create("Humanoid", {}, m)
	rt:create("Shirt", {}, m)
	rt:create("Pants", {}, m)
	m.PrimaryPart = root
	return m
end

-- An R6 character standing on y = 0.
local function r6(name: string, x: number, z: number): any
	local m = rt:create("Model", { Name = name })
	local function at(px: number, py: number): any
		return CFrame.new(x + px, py, z)
	end
	local root = rigPart(m, "HumanoidRootPart", Vector3.new(2, 2, 1), at(0, 3), SKIN)
	root.Transparency = 1
	rigPart(m, "Torso", Vector3.new(2, 2, 1), at(0, 3), SHIRT)
	local head = rigPart(m, "Head", Vector3.new(2, 1, 1), at(0, 4.5), SKIN)
	rt:create(
		"SpecialMesh",
		{ MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25) },
		head
	)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		rigPart(m, prefix .. " Arm", Vector3.new(1, 2, 1), at(side * 1.5, 3), SKIN)
		rigPart(m, prefix .. " Leg", Vector3.new(1, 2, 1), at(side * 0.5, 1), PANTS)
	end
	rt:create("Humanoid", {}, m)
	m.PrimaryPart = root
	return m
end

-- Scene --------------------------------------------------------------------------------------------

local scene = rt:create("Model", { Name = "Catwalk" }, rt.workspace)
local widest = 0
for _, row in rows do
	widest = math.max(widest, #row)
end
local width = widest * SPACING
local depth = #rows * ROW_GAP
rt:create("Part", {
	Name = "Floor",
	Size = Vector3.new(width + 16, 1, depth + 16),
	CFrame = CFrame.new(-(width / 2 - SPACING / 2), -0.5, depth / 2 - ROW_GAP / 2),
	Color = Color3.fromRGB(70, 62, 80),
	Material = Enum.Material.Slate,
	Anchored = true,
}, scene)

local count = 0
for r, row in rows do
	for i, item in row do
		local x = -(i - 1) * SPACING -- the camera looks from -Z, so left to right is -X
		local z = (r - 1) * ROW_GAP
		if look == "preview" then
			local model = Cosmetics.Preview(item)
			-- the stand-in's feet are 3 studs below its torso centre
			model:PivotTo(CFrame.new(x, 3, z))
			model.Parent = scene
		else
			local character = if rig == "r6" then r6(item.Id, x, z) else r15(item.Id, x, z)
			character.Parent = scene
			assert(Cosmetics.Wear(character, item), "Wear failed for " .. item.Id)
			local crazy = item.Style.Crazy
			if fx and type(crazy) == "table" and type(crazy.Orbit) == "string" then
				-- what src/client/SkinFx.luau adds on players' screens (one frame of it)
				local settings = Config.Skins.Effects
				local count = crazy.Count or 3
				for k = 1, count do
					local a = math.pi * 0.8 + (k - 1) / count * math.pi * 2
					local piece = HeadPieces.Orbit(crazy.Orbit, nil, settings.OrbitScale)
					piece:PivotTo(
						CFrame.new(
							x + math.cos(a) * settings.OrbitRadius,
							3.4 + settings.OrbitHeight + math.sin(k * 2) * settings.OrbitBob,
							z + math.sin(a) * settings.OrbitRadius
						) * CFrame.Angles(0, -a, 0)
					)
					piece.Parent = scene
				end
			end
		end
		-- the skin's name on a little sign at its feet
		local sign = rt:create("Part", {
			Name = "Sign",
			Size = Vector3.new(SPACING - 1.5, 0.2, 1.2),
			CFrame = CFrame.new(x, 0.1, (r - 1) * ROW_GAP - 2.2),
			Color = Items.RarityInfo(item).Color,
			Anchored = true,
		}, scene)
		local gui = rt:create("SurfaceGui", { Face = Enum.NormalId.Top }, sign)
		rt:create(
			"TextLabel",
			{ Text = item.Name .. " (" .. Items.RarityInfo(item).Name .. ")" },
			gui
		)
		count += 1
	end
end
rt:flush()

local dir = output:match("^(.*)[/\\][^/\\]+$")
if dir and dir ~= "" and not fs.isDir(dir) then
	fs.writeDir(dir)
end
local stats = Export.write(output, { scene }, {
	lighting = Config.Hub.Lighting,
	meta = { source = "new-game/tests/catwalk.luau", kind = "catwalk", name = mode },
})
print(
	("wrote %s: %d skins, %d parts, %d lights, %d effects"):format(
		output,
		count,
		stats.parts,
		stats.lights,
		stats.effects
	)
)
local renderer = exporterPath:gsub("export%.luau$", "render.mjs")
local cameras = {}
for r, row in rows do
	local cx = -(#row - 1) * SPACING / 2
	local z = (r - 1) * ROW_GAP
	local back = 4 + #row * SPACING * 0.42 -- far enough to fit the row (fov 50, 2000x800)
	table.insert(cameras, ('--camera "%g,7,%g->%g,3.2,%g"'):format(cx, z - back, cx, z))
end
print(
	("render: node %s %s %s --views custom %s --fov 50 --size 2000x800 --min-ambient 0.4"):format(
		renderer,
		output,
		(output:gsub("%.json$", "")),
		table.concat(cameras, " ")
	)
)
