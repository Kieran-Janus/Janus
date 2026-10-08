--!strict
--[[
	The world around a round map, so it doesn't float in the sky (MapBase calls this):
	  Skirt     ground carrying on past the walls to the horizon
	  Hills     a ring of dark rolling hills further out, fading into the map's fog
	  TreeLine  bare trees (prop "DeadTree", swappable) standing between the walls and the hills
	  WallPosts posts along the top of the walls, each with a small glowing cap (no lights, so
	            phones stay fast)
	All of it is decoration only: walk-through, never hit by raycasts (pumpkin spawns, the
	King's sight), and outside the walls, so it never changes how a round plays.
	Settings: each map's `Scenery` block (src/shared/Config/Maps/<Id>.luau); missing values
	fall back to shades of the map's floor and wall colours. Scenery = false turns it off.
]]

local Kit = require(script.Parent.Parent.Build.Kit)

local MapScenery = {}

export type Style = {
	FloorColor: Color3,
	WallColor: Color3,
}

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- `origin` = centre of the floor's top, `size` = the floor's size, `wallHeight` = the walls.
function MapScenery.Build(def: any, style: Style, origin: Vector3, size: Vector3, parent: Instance)
	local cfg = def.Scenery
	if cfg == false then
		return
	end
	cfg = if type(cfg) == "table" then cfg else {}
	local rng = Random.new((def.Seed or 1) * 7919 + 13) -- its own numbers: the map's stay the same
	local ground: Color3 = cfg.Ground or shade(style.FloorColor, 0.25)
	local hill: Color3 = cfg.Hill or shade(style.FloorColor, 0.6)
	local treeColor: Color3 = cfg.Tree or Color3.fromRGB(28, 22, 30)
	local post: Color3 = cfg.Post or shade(style.WallColor, 0.15)
	local glow: Color3 = cfg.Glow or Color3.fromRGB(255, 160, 60)
	local reach: number = cfg.Reach or 160 -- studs of ground past the walls
	local wallHeight: number = def.WallHeight or 12

	local folder = Kit.group("Scenery", parent)
	local halfX, halfZ = size.X / 2, size.Z / 2
	local y = origin.Y

	-- Skirt: four strips round the walls, a hair under the floor so the edge doesn't flicker.
	local skirt = Kit.group("Skirt", folder)
	local outerX, outerZ = halfX + 2 + reach, halfZ + 2 + reach
	for _, s in
		{
			{ Vector3.new(outerX * 2, 1, reach), Vector3.new(0, 0, halfZ + 2 + reach / 2) },
			{ Vector3.new(outerX * 2, 1, reach), Vector3.new(0, 0, -(halfZ + 2 + reach / 2)) },
			{ Vector3.new(reach, 1, halfZ * 2 + 4), Vector3.new(halfX + 2 + reach / 2, 0, 0) },
			{ Vector3.new(reach, 1, halfZ * 2 + 4), Vector3.new(-(halfX + 2 + reach / 2), 0, 0) },
		}
	do
		Kit.decor({
			Name = "Ground",
			Size = s[1],
			Position = Vector3.new(origin.X, y - 0.55, origin.Z) + s[2],
			Color = ground,
			Material = cfg.GroundMaterial or Enum.Material.Grass,
		}, skirt).CastShadow =
			false
	end

	-- Hills: big squashed balls on a ring near the far edge of the skirt.
	local hills = Kit.group("Hills", folder)
	local hillCount: number = cfg.Hills or 22
	for i = 1, hillCount do
		local angle = (i / hillCount) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(0.8, 0.98)
		local width = rng:NextNumber(70, 120)
		local height = rng:NextNumber(70, 130) -- tall enough to show over the walls
		local at = Vector3.new(math.cos(angle) * outerX * dist, 0, math.sin(angle) * outerZ * dist)
		Kit.decor({
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(width, height, width * rng:NextNumber(0.6, 0.9)),
			CFrame = CFrame.new(Vector3.new(origin.X, y - height * 0.3, origin.Z) + at)
				* CFrame.Angles(0, -angle, 0),
			Color = hill:Lerp(ground, rng:NextNumber(0, 0.25)),
			Material = Enum.Material.Grass,
		}, hills).CastShadow =
			false
	end

	-- Tree line: bare trees between the walls and the hills (numbers drawn before Kit.prop).
	local trees = Kit.group("TreeLine", folder)
	local treeCount: number = cfg.Trees or 26
	for i = 1, treeCount do
		local angle = (i / treeCount) * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local dist = rng:NextNumber(0.25, 0.6)
		local height = rng:NextNumber(14, 26)
		local branchSeed = rng:NextInteger(1, 1e6)
		local spinYaw = rng:NextNumber(0, math.pi * 2)
		local rx = math.cos(angle) * (halfX + 6 + reach * dist)
		local rz = math.sin(angle) * (halfZ + 6 + reach * dist)
		local base = CFrame.new(origin.X + rx, y, origin.Z + rz) * CFrame.Angles(0, spinYaw, 0)
		Kit.prop("DeadTree", base, trees, height, function()
			local m = Kit.model("DeadTree", trees)
			local r = Random.new(branchSeed)
			local trunk = Kit.decor({
				Name = "Trunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 1.8, 1.8),
				CFrame = Kit.upright(base * CFrame.new(0, height / 2, 0)),
				Color = treeColor,
				Material = Enum.Material.Wood,
			}, m)
			for b = 1, 2 do
				local length = r:NextNumber(4, 8)
				Kit.decor({
					Name = "Branch",
					Size = Vector3.new(0.6, 0.6, length),
					CFrame = base
						* CFrame.new(0, height * r:NextNumber(0.5, 0.9), 0)
						* CFrame.Angles(0, (b / 2) * math.pi * 2 + r:NextNumber(-0.4, 0.4), 0)
						* CFrame.Angles(math.rad(r:NextNumber(30, 55)), 0, 0)
						* CFrame.new(0, 0, -length / 2),
					Color = treeColor,
					Material = Enum.Material.Wood,
				}, m)
			end
			m.PrimaryPart = trunk
			return m
		end, { Visual = true })
	end

	-- Posts along the walls with a glowing cap: the walls stop looking like flat boxes.
	if cfg.WallPosts ~= false then
		local posts = Kit.group("WallPosts", folder)
		local spacing: number = cfg.PostSpacing or 22
		local function postAt(x: number, z: number)
			local m = Kit.model("WallPost", posts)
			local h = wallHeight + 2
			Kit.decor({
				Name = "Post",
				Size = Vector3.new(3, h, 3),
				Position = Vector3.new(origin.X + x, y + h / 2, origin.Z + z),
				Color = post,
				Material = cfg.PostMaterial or Enum.Material.Slate,
			}, m).CastShadow =
				false
			Kit.decor({
				Name = "Glow",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = Vector3.new(origin.X + x, y + h + 0.5, origin.Z + z), -- sits on the post
				Color = glow,
				Material = Enum.Material.Neon,
			}, m)
		end
		local nx = math.max(1, math.floor(size.X / spacing))
		local nz = math.max(1, math.floor(size.Z / spacing))
		for i = 0, nx do
			local x = -halfX - 1 + (size.X + 2) * i / nx
			postAt(x, halfZ + 1)
			postAt(x, -halfZ - 1)
		end
		for i = 1, nz - 1 do
			local z = -halfZ - 1 + (size.Z + 2) * i / nz
			postAt(halfX + 1, z)
			postAt(-halfX - 1, z)
		end
	end
end

return MapScenery
