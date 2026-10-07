--[[
	Thumbnail scene builder (used by thumbnails/v2.mjs, run from the repo root):

	  lune run thumbnails/v2-scene -- <spec.json>

	Builds a real game scene inside the new-game test harness (the same code that builds the game:
	HubBuilder for the lobby, MapService for a round map) and adds posed mannequins wearing real
	skins (Cosmetics.Wear, like new-game/tests/catwalk.luau), a Hide & Seek pumpkin or the seekers'
	candy gun, then writes a scene JSON for the offline previewer (/tmp/claude-0/render, cloud
	tooling outside this repo).

	spec.json:
	  {
	    "out": "path/scene.json",
	    "base": "hub" | "map:PumpkinFarm" | "none",
	    "exporter": "/tmp/claude-0/render/export.luau",          (optional)
	    "characters": [{
	      "skin": "Pumpkin_MegaGourdSupreme",   a Config.Shop.Items id (Slot = "Skin")
	      "at": [x, y, z],                      where the feet stand (the lobby plaza is y = 1)
	      "yaw": 180,                           degrees; 0 faces -Z (north), 180 faces +Z (south)
	      "face": [x, z],                       or turn to look at this point (yaw is then added)
	      "lean": 0,                            degrees forward
	      "scale": 1,
	      "pose": { "armL": [forward, out], "armR": [forward, out], "legL": forward, "legR": forward },
	      "orbit": true,                        the CRAZY orbiting pieces (one frame of SkinFx)
	      "tool": "CandyGun"                    held in the right hand
	    }],
	    "props": [
	      { "kind": "HidingPumpkin", "at": [x, y, z], "yaw": 0, "seed": 7 },    a Hide & Seek pumpkin
	      { "kind": "Ghost", "at": [x, y, z], "yaw": 0 },          ScareMaze actor: Scarecrow, Zombie, Bat, Ghost
	      { "kind": "Candy", "candy": "Lollipop", "color": 2, "at": [x, y, z], "yaw": 270 }
	                                                    a Candy Rush candy (Wrapped, Lollipop, CandyCorn;
	                                                    color = index in Config.Minigames.CandyRush.Candy.Colors)
	    ]
	  }
	or { "facts": "path/facts.json" } to write what the thumbnails may claim (counted from Config).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Runtime = require("../new-game/tests/harness/Runtime")

local function fail(message: string)
	print("v2-scene: " .. message)
	process.exit(1)
	error(message)
end

local specPath: string? = nil
for _, arg in process.args do
	if arg ~= "--" then
		specPath = arg
	end
end
if not specPath then
	fail("usage: lune run thumbnails/v2-scene -- <spec.json>")
end
local spec = serde.decode("json", fs.readFile(specPath :: string))

local exporterPath = spec.exporter
	or process.env.ROBLOX_PREVIEW_EXPORTER
	or "/tmp/claude-0/render/export.luau"
if not fs.isFile(exporterPath) then
	fail("can't find the scene exporter at " .. exporterPath .. " (cloud preview tooling)")
end
local Export = luau.load(fs.readFile(exporterPath), { debugName = exporterPath })()

local rt = Runtime.new({ echo = "warn" })
local env = rt.env
local CFrame, Vector3, Color3 = env.CFrame, env.Vector3, env.Color3
local Config = rt:require("ReplicatedStorage.Shared.Config")
local Cosmetics = rt:require("ReplicatedStorage.Shared.Cosmetics")
local HeadPieces = rt:require("ReplicatedStorage.Shared.HeadPieces")
local Items = rt:require("ReplicatedStorage.Shared.Items")

-- Facts the thumbnails may claim, counted from Config (so the text stays true).
if spec.facts then
	local skins, themed, crazy, million = 0, 0, {}, {}
	for _, item in Config.Shop.Items do
		if item.Slot == "Skin" then
			skins += 1
			if item.Theme then
				themed += 1
			end
			if Items.Rarity(item) == "Crazy" then
				table.insert(
					crazy,
					{ id = item.Id, name = item.Name, oneInAMillion = item.OneInAMillion == true }
				)
				if item.OneInAMillion then
					table.insert(million, item.Id)
				end
			end
		end
	end
	local crates = 0
	for _ in Config.Crates.List do
		crates += 1
	end
	fs.writeFile(
		spec.facts,
		serde.encode("json", {
			skins = skins,
			themedSkins = themed,
			themes = #Config.Skins.Themes,
			crates = crates,
			crazy = crazy,
			oneInAMillion = million,
			towerSkin = Config.TowerParkour.Skin.Name,
			towerRarity = Config.TowerParkour.Skin.Rarity,
		}, true)
	)
	print(
		("v2-scene: wrote %s (%d skins, %d CRAZY, %d one in a million)"):format(
			spec.facts,
			skins,
			#crazy,
			#million
		)
	)
	process.exit(0)
end

-- Base scene ------------------------------------------------------------------------------------

local roots: { any } = {}
local lighting: any = Config.Hub.Lighting
local base = spec.base or "hub"
if base == "hub" then
	local HubBuilder = rt:require("ServerScriptService.Server.Hub.HubBuilder")
	table.insert(roots, HubBuilder.Build())
elseif string.sub(base, 1, 4) == "map:" then
	local id = string.sub(base, 5)
	local MapService = rt:require("ServerScriptService.Server.Services.MapService")
	local def = MapService.Get(id) or fail("unknown map " .. id)
	table.insert(roots, MapService.Load(id).Model)
	lighting = def.Lighting
elseif base ~= "none" then
	fail("unknown base " .. tostring(base))
end
rt:flush()

-- Mannequins ------------------------------------------------------------------------------------

local SKIN = Color3.fromRGB(255, 205, 160)
local SHIRT = Color3.fromRGB(90, 110, 160)
local PANTS = Color3.fromRGB(60, 60, 80)

local scene = rt:create("Model", { Name = "Thumbnail" }, rt.workspace)
table.insert(roots, scene)

local function num(v: any, default: number): number
	return if type(v) == "number" then v else default
end

-- Rotation of a limb about its joint: `forward` swings it toward the facing direction (-Z),
-- `out` lifts it sideways away from the body (side = -1 left, 1 right).
local function limbRotation(forward: number, out: number, side: number): any
	return CFrame.Angles(math.rad(forward), 0, 0) * CFrame.Angles(0, 0, math.rad(out * side))
end

-- An R15 mannequin (block body proportions, as in tests/catwalk.luau), posed and placed.
local function mannequin(c: any, index: number): any
	local m = rt:create("Model", { Name = "Player" .. index })
	local pose = c.pose or {}
	local at = c.at or { 0, 0, 0 }
	local s = num(c.scale, 1)
	local yaw = math.rad(num(c.yaw, 0))
	if type(c.face) == "table" then
		-- turn to look at a point (x, z): LookVector = (-sin yaw, 0, -cos yaw)
		yaw = math.atan2(-(c.face[1] - at[1]), -(c.face[2] - at[3])) + math.rad(num(c.yaw, 0))
	end
	local place = CFrame.new(at[1], at[2], at[3])
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(math.rad(-num(c.lean, 0)), 0, 0)
	-- Local positions: feet at y = 0, facing -Z.
	local function put(name: string, size: any, cf: any, color: any): any
		local p = rt:create("Part", {
			Name = name,
			Size = size * s,
			CFrame = place * CFrame.new(cf.Position * s) * cf.Rotation,
			Color = color,
			Anchored = true,
		}, m)
		return p
	end
	local root = put("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3.4, 0), SKIN)
	root.Transparency = 1
	put("LowerTorso", Vector3.new(2, 0.4, 1), CFrame.new(0, 2.8, 0), PANTS)
	put("UpperTorso", Vector3.new(2, 1.6, 1), CFrame.new(0, 3.8, 0), SHIRT)
	local head = put("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.2, 0), SKIN)
	rt:create(
		"SpecialMesh",
		{ MeshType = env.Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25) },
		head
	)
	rt:create("Decal", { Name = "face" }, head)
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		local arm = pose[if side < 0 then "armL" else "armR"] or { 0, 0 }
		local shoulder = CFrame.new(side * 1.5, 4.6, 0)
			* limbRotation(num(arm[1], 0), num(arm[2], 0), side)
		put(prefix .. "UpperArm", Vector3.new(1, 1.1, 1), shoulder * CFrame.new(0, -0.55, 0), SHIRT)
		put(prefix .. "LowerArm", Vector3.new(1, 1.0, 1), shoulder * CFrame.new(0, -1.6, 0), SKIN)
		put(prefix .. "Hand", Vector3.new(1, 0.3, 1), shoulder * CFrame.new(0, -2.25, 0), SKIN)
		local leg = num(pose[if side < 0 then "legL" else "legR"], 0)
		local hip = CFrame.new(side * 0.5, 2.6, 0) * CFrame.Angles(math.rad(leg), 0, 0)
		put(prefix .. "UpperLeg", Vector3.new(1, 1.2, 1), hip * CFrame.new(0, -0.6, 0), PANTS)
		put(prefix .. "LowerLeg", Vector3.new(1, 1.1, 1), hip * CFrame.new(0, -1.75, 0), PANTS)
		put(
			prefix .. "Foot",
			Vector3.new(1, 0.3, 1),
			hip * CFrame.new(0, -2.45, -0.05),
			Color3.fromRGB(40, 35, 45)
		)
	end
	rt:create("Humanoid", {}, m)
	rt:create("Shirt", {}, m)
	rt:create("Pants", {}, m)
	m.PrimaryPart = root
	return m
end

-- Moves every part of `tool` so its Handle sits at `cf`.
local function holdTool(tool: any, cf: any)
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		return
	end
	local from = handle.CFrame
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * from:ToObjectSpace(d.CFrame)
			d.Anchored = true
		end
	end
end

local count = 0
for i, c in spec.characters or {} do
	local item = Items.Get(c.skin) or fail("no skin " .. tostring(c.skin))
	local character = mannequin(c, i)
	character.Parent = scene
	if not Cosmetics.Wear(character, item) then
		fail("Wear failed for " .. c.skin)
	end
	local crazy = item.Style and item.Style.Crazy
	if c.orbit ~= false and type(crazy) == "table" and type(crazy.Orbit) == "string" then
		-- one frame of what src/client/SkinFx.luau orbits round CRAZY skins
		local settings = Config.Skins.Effects
		local k = num(c.scale, 1)
		local root = character.PrimaryPart.CFrame
		local n = crazy.Count or 3
		for j = 1, n do
			local a = math.pi * 0.8 + (j - 1) / n * math.pi * 2 + num(c.orbitPhase, 0)
			local piece = HeadPieces.Orbit(crazy.Orbit, nil, settings.OrbitScale * k)
			piece:PivotTo(
				root
					* CFrame.new(
						math.cos(a) * settings.OrbitRadius * k,
						(settings.OrbitHeight + math.sin(j * 2) * settings.OrbitBob) * k,
						math.sin(a) * settings.OrbitRadius * k
					)
					* CFrame.Angles(0, -a, 0)
			)
			piece.Parent = scene
		end
	end
	if c.tool == "CandyGun" then
		local CandyGun = rt:require("ServerScriptService.Server.Modes.CandyGun")
		local tool = CandyGun.Make()
		tool.Parent = scene
		local hand = character:FindFirstChild("RightHand")
		-- as Roblox holds a tool: RightHand * RightGripAttachment * Grip:Inverse() (the barrel
		-- points forward when the arm is raised 90 degrees, like the default tool pose)
		holdTool(
			tool,
			hand.CFrame
				* CFrame.new(0, -0.15, 0)
				* CFrame.Angles(math.rad(-90), 0, 0)
				* tool.Grip:Inverse()
		)
	end
	count += 1
end

for _, p in spec.props or {} do
	if p.kind == "HidingPumpkin" then
		local HidingPumpkin = rt:require("ServerScriptService.Server.Build.HidingPumpkin")
		local at = p.at
		HidingPumpkin.Build(
			CFrame.new(at[1], at[2], at[3]) * CFrame.Angles(0, math.rad(num(p.yaw, 0)), 0),
			env.Random.new(num(p.seed, 1)),
			scene
		)
	elseif p.kind == "Candy" then
		-- a Candy Rush candy as it pops up on the board during a race (its front faces `yaw`)
		local CandyRushCandy = rt:require("ServerScriptService.Server.Minigames.CandyRushCandy")
		local at = p.at
		local colors = Config.Minigames.CandyRush.Candy.Colors
		local candy = CandyRushCandy.Build(
			p.candy or "Wrapped",
			colors[math.clamp(num(p.color, 1), 1, #colors)],
			CFrame.new(at[1], at[2], at[3])
				* CFrame.Angles(0, math.rad(num(p.yaw, 0)), math.rad(num(p.roll, 0)))
		)
		candy.Parent = scene
	elseif p.kind == "Scarecrow" or p.kind == "Zombie" or p.kind == "Bat" or p.kind == "Ghost" then
		-- the ScareMaze's scare characters, as they look when a trap makes them jump out
		local ScareActors = rt:require("ServerScriptService.Server.Build.ScareActors")
		local at = p.at
		ScareActors[p.kind](
			CFrame.new(at[1], at[2], at[3])
				* CFrame.Angles(0, math.rad(num(p.yaw, 0)), 0)
				* CFrame.Angles(math.rad(num(p.pitch, 0)), 0, math.rad(num(p.roll, 0))),
			scene
		)
	else
		fail("unknown prop kind " .. tostring(p.kind))
	end
end
rt:flush()

-- Terrain: the recorded Terrain:Fill* calls (as in new-game/tests/preview.luau) -----------------

local terrain = {}
for _, call in
	rt:calls("Terrain", { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "FillRegion" })
do
	local a = call.args
	local entry
	if call.method == "FillBlock" then
		entry = { kind = "Block", cframe = a[1], size = a[2], material = a[3] }
	elseif call.method == "FillBall" then
		entry = { kind = "Ball", cframe = CFrame.new(a[1]), radius = a[2], material = a[3] }
	elseif call.method == "FillCylinder" then
		entry = { kind = "Cylinder", cframe = a[1], height = a[2], radius = a[3], material = a[4] }
	elseif call.method == "FillWedge" then
		entry = { kind = "Wedge", cframe = a[1], size = a[2], material = a[3] }
	else
		local region = a[1]
		entry = {
			min = region.CFrame.Position - region.Size / 2,
			max = region.CFrame.Position + region.Size / 2,
			material = a[3],
		}
	end
	table.insert(terrain, entry)
end

local out = spec.out or fail("spec has no out path")
local dir = out:match("^(.*)[/\\][^/\\]+$")
if dir and dir ~= "" and not fs.isDir(dir) then
	fs.writeDir(dir)
end
local stats = Export.write(out, roots, {
	lighting = lighting,
	terrain = terrain,
	meta = { source = "thumbnails/v2-scene.luau", kind = base },
})
print(
	("v2-scene: wrote %s (%s, %d characters, %d parts, %d lights)"):format(
		out,
		base,
		count,
		stats.parts,
		stats.lights
	)
)
