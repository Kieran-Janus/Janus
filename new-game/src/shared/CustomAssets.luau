--!strict
--[[
	Custom art ("builder mode"). Every character, hat, pet and skin in the game has a
	Part-built placeholder. Drop a model with the right name into
	ReplicatedStorage.Custom.<Category> and the game uses it instead. No code change needed.

	  Category    Name the model after...                    Used by
	  Characters  PumpkinKing, SkeletonPatrol, Bat,           KingService, MinionService,
	              GhostCat, PumpkinVendor (the Pumpkin        HubBuilder (hub NPCs)
	              Shop keeper)
	  Cosmetics   the shop item Id (Config.Shop.Items),       Cosmetics (hats, pets, skin
	              e.g. WitchHat, MiniPumpkin, Skeleton        head pieces) and shop previews
	  Props       a decoration or pumpkin: Pumpkin,           Kit.prop / Kit.look (the hub, the
	              JackOLantern, CollectPumpkin,               round maps, King Hunt pickups):
	              HidingPumpkin, ParkourPumpkin, Lamppost,    every copy in the lobby AND the
	              Lantern, HayBale, Gravestone, DeadTree...   maps swaps at once (the built
	              (the full list: docs/CUSTOMIZE.md, "Swap    ones have the attribute PropName;
	              every copy of something at once")          src/server/Tools/Swap.luau swaps
	                                                          a saved hub or baked map in Studio)

	Two ways to add one (docs/CUSTOMIZE.md has screenshots-free step by step):
	  1. In Studio: put the Model in ReplicatedStorage > Custom > Characters (etc.) and save.
	     Rojo leaves it alone (the folders are marked ignoreUnknownInstances).
	  2. In git: right-click the model > Save to File... and save it as
	     assets/Characters/PumpkinKing.rbxm. Rojo syncs it in.

	Size: models are scaled to Config.Custom.Heights[name] (characters),
	Config.Custom.CosmeticSize[slot] (cosmetics) or the size of the decoration they replace
	(props), measuring only the parts you can see. Set the attribute KeepSize = true on a model
	to keep the size you built it at.
	Facing: the model's front is its pivot's LookVector (-Z), like any Roblox character. Lobby
	characters and props are only turned left/right, never tipped over.
	Scripts inside custom models are removed (Config.Custom.StripScripts): free models from
	the Creator Store can hide malicious scripts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local CustomAssets = {}

local function folder(category: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Custom")
	return root and root:FindFirstChild(category)
end

-- The original custom asset (not a copy), or nil when there is none.
function CustomAssets.Find(category: string, name: string): Instance?
	local f = folder(category)
	local found = f and f:FindFirstChild(name)
	if found and (found:IsA("Model") or found:IsA("Accessory") or found:IsA("BasePart")) then
		return found
	end
	return nil
end

function CustomAssets.Has(category: string, name: string): boolean
	return CustomAssets.Find(category, name) ~= nil
end

-- A ready-to-use copy as a Model (Accessories and single parts are wrapped), or nil.
function CustomAssets.Clone(category: string, name: string): Model?
	local source = CustomAssets.Find(category, name)
	if not source then
		return nil
	end
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		-- Accessory (e.g. a hat from the Toolbox) or a single MeshPart: wrap its parts.
		model = Instance.new("Model")
		model.Name = name
		if copy:IsA("BasePart") then
			copy.Parent = model
		else
			for _, child in copy:GetChildren() do
				child.Parent = model
			end
			copy:Destroy()
			-- The accessory's own weld points at a character that isn't there any more.
			for _, d in model:GetDescendants() do
				if d:IsA("JointInstance") and d.Name == "AccessoryWeld" then
					d:Destroy()
				end
			end
		end
	end
	if Config.Custom.StripScripts then
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
	end
	if not model.PrimaryPart then
		-- Keep the pivot the author set (its LookVector is the model's front).
		local pivot = model:GetPivot()
		local biggest = CustomAssets.BiggestPart(model)
		model.PrimaryPart = biggest
		if biggest then
			biggest.PivotOffset = biggest.CFrame:ToObjectSpace(pivot)
		end
	end
	return model
end

function CustomAssets.BiggestPart(model: Model): BasePart?
	local best: BasePart? = nil
	local bestVolume = -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best
end

-- The 8 corners of a part's box, in world space.
local function corners(part: BasePart): { Vector3 }
	local half = part.Size / 2
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z))
			end
		end
	end
	return list
end

-- The parts you can see (not fully transparent); all parts if none are visible.
local function visibleParts(root: Instance): { BasePart }
	local visible, all = {}, {}
	local function add(d: Instance)
		if d:IsA("BasePart") then
			table.insert(all, d)
			if d.Transparency < 1 then
				table.insert(visible, d)
			end
		end
	end
	add(root)
	for _, d in root:GetDescendants() do
		add(d)
	end
	return if #visible > 0 then visible else all
end

--[[
	The box around the parts you can see (big invisible hitboxes don't count), lined up with
	`space` (default: the world). Returns its lowest and highest corner in that space, and
	false when there are no parts at all.
]]
function CustomAssets.VisibleBox(root: Instance, space: CFrame?): (Vector3, Vector3, boolean)
	local parts = visibleParts(root)
	if #parts == 0 then
		return Vector3.zero, Vector3.zero, false
	end
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in parts do
		for _, corner in corners(part) do
			local p = if space then space:PointToObjectSpace(corner) else corner
			low = low:Min(p)
			high = high:Max(p)
		end
	end
	return low, high, true
end

-- Size of the visible parts, measured along the model's own axes (its pivot).
function CustomAssets.VisibleSize(model: Model): Vector3
	local low, high, found = CustomAssets.VisibleBox(model, model:GetPivot())
	if not found then
		local _, size = model:GetBoundingBox()
		return size
	end
	return high - low
end

-- Scales `model` so its height (or its biggest side, if `largestSide`) is `target` studs.
function CustomAssets.Fit(model: Model, target: number?, largestSide: boolean?)
	if not target or target <= 0 or model:GetAttribute("KeepSize") == true then
		return
	end
	local size = CustomAssets.VisibleSize(model)
	local current = if largestSide then math.max(size.X, size.Y, size.Z) else size.Y
	if current <= 0.01 then
		return
	end
	local ok, err = pcall(function()
		model:ScaleTo(model:GetScale() * target / current)
	end)
	if not ok then
		warn("[CustomAssets] couldn't scale " .. model.Name .. ": " .. tostring(err))
	end
end

--[[
	The point the game treats as the model's origin, facing the model's front:
	  "Feet"   - bottom centre of the bounding box (characters standing on the floor)
	  "Center" - centre of the bounding box (bats, pets, hats are positioned separately)
	  "Bottom" - same as Feet; reads better for hats (the bottom sits on the head)
]]
function CustomAssets.Origin(model: Model, anchor: string): CFrame
	local box, size = model:GetBoundingBox()
	local facing = model:GetPivot().Rotation
	local centre = box.Position
	if anchor == "Feet" or anchor == "Bottom" then
		-- The box can be rotated; drop along the world Y axis to its lowest point.
		local minY = math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local half = d.Size / 2
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							local p = (d.CFrame * CFrame.new(half.X * x, half.Y * y, half.Z * z)).Position
							minY = math.min(minY, p.Y)
						end
					end
				end
			end
		end
		if minY == math.huge then
			minY = centre.Y - size.Y / 2
		end
		return CFrame.new(centre.X, minY, centre.Z) * facing
	end
	return CFrame.new(centre) * facing
end

-- Just the left/right turn of `cf` (no tilt), at the origin.
function CustomAssets.Yaw(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		-- Facing straight up or down (a model imported lying down): use its top instead.
		local up = cf.UpVector
		flat = Vector3.new(-up.X, 0, -up.Z)
		if flat.Magnitude < 1e-3 then
			return CFrame.identity
		end
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

--[[
	Stands `model` on the ground at `cf`: the bottom centre of its visible parts goes to
	cf.Position and it is turned (left/right only) so its front faces cf's front. A tilted
	model stays tilted, but is never tipped over by a tilted `cf`.
]]
function CustomAssets.PlaceFeet(model: Model, cf: CFrame)
	local low, high = CustomAssets.VisibleBox(model)
	local feet = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	local pivot = model:GetPivot()
	local from = CFrame.new(feet) * CustomAssets.Yaw(pivot)
	local to = CFrame.new(cf.Position) * CustomAssets.Yaw(cf)
	model:PivotTo(to * from:ToObjectSpace(pivot))
end

-- Puts the centre of `model`'s visible parts at `cf`, turned exactly like `cf` (for flat
-- things hung on walls, like cobwebs).
function CustomAssets.PlaceCenter(model: Model, cf: CFrame)
	local pivot = model:GetPivot()
	local low, high = CustomAssets.VisibleBox(model, pivot)
	local centre = pivot * CFrame.new((low + high) / 2)
	model:PivotTo(cf * centre:ToObjectSpace(pivot))
end

-- Anchored, non-colliding decoration (for things the server moves by CFrame).
function CustomAssets.MakeDecor(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
end

-- Sizes for characters and cosmetics, by name or slot.
function CustomAssets.CharacterHeight(name: string): number?
	return Config.Custom.Heights[name]
end

return CustomAssets
