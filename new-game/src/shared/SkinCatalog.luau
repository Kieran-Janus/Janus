--!strict
--[[
	Catalog items in skins (a skin's Style.Catalog): checking them and the small helpers the
	server, the cards and Skin Studio share. Pure and shared: the server puts the items on
	(src/server/Services/SkinCatalogService.luau), shop and crate cards show their pictures
	(src/client/CatalogBadge.luau) and the tests check every skin with Normalize. The rules and
	numbers are in Config.SkinCatalog (src/shared/Config/SkinCatalog.luau).

	    Catalog = {
	        Accessories = { { Id = 1234567890, Type = "Hat" } },          -- up to MaxAccessories
	        Shirt = 3456789012, Pants = 4567890123, TShirt = 5678901234,  -- classic clothes
	        ClassicFace = 6789012345,                                      -- a flat face decal
	    }
	Ids are whole numbers above 0. Type is one of SkinCatalog.Types: "FaceAccessory" is a 3D
	thing worn on the face (glasses, a mask), "ClassicFace" the flat face picture.

	SkinCatalog.Types                      the accessory Types a skin may use (Config)
	SkinCatalog.Normalize(value, style?) -> (Catalog?, errors, warnings)
	                                       checks a Style.Catalog; bad parts are left out (and
	                                       explained in errors). With the skin's style it also
	                                       warns about things that won't show.
	SkinCatalog.Key(catalog) -> string     "" for none; the same text for the same items in any
	                                       order (the server compares keys to skip work)
	SkinCatalog.Ids(catalog) -> { number } every id in it (accessories, clothes, face)
	SkinCatalog.TypeFromAssetType(name) -> string?   an Enum.AssetType name to a Type:
	                                       "Hat" -> "Hat", "HairAccessory" -> "Hair",
	                                       "FaceAccessory" -> "FaceAccessory", "Shirt" -> "Shirt",
	                                       "TShirt" -> "TShirt", "Face" -> "ClassicFace"...
	SkinCatalog.TypeFromAssetTypeId(id) -> string?   the same from GetProductInfo's AssetTypeId
	SkinCatalog.AccessoryType(type) -> Enum.AccessoryType?   "FaceAccessory" -> Face...
	SkinCatalog.CreatorAllowed(creatorType, creatorId) -> boolean
	                                       Roblox ("User" 1), or a user / group listed in
	                                       Config.SkinCatalog.AllowedCreators
	SkinCatalog.Approved(id) -> boolean    listed in Config.SkinCatalog.ApprovedIds
	SkinCatalog.Thumbnail(id) -> string    the rbxthumb:// picture of an item
]]

local Config = require(script.Parent.Config)

local SkinCatalog = {}

export type Accessory = { Id: number, Type: string }
export type Catalog = {
	Accessories: { Accessory },
	Shirt: number?,
	Pants: number?,
	TShirt: number?,
	ClassicFace: number?,
}

local function settings()
	return Config.SkinCatalog
end

SkinCatalog.Types = Config.SkinCatalog.Types

-- The classic (flat) clothes, in the order they are listed and applied.
local CLOTHES = { "Shirt", "Pants", "TShirt" }
local KEYS = { Accessories = true, Shirt = true, Pants = true, TShirt = true, ClassicFace = true }

-- Our accessory Type -> the Enum.AccessoryType item's name (looked up by name, never number).
local ACCESSORY_ENUM = {
	Hat = "Hat",
	Hair = "Hair",
	FaceAccessory = "Face",
	Neck = "Neck",
	Shoulder = "Shoulder",
	Front = "Front",
	Back = "Back",
	Waist = "Waist",
}

-- Enum.AssetType names -> our Types (anything else can't go in a skin).
local ASSET_TYPES = {
	Hat = "Hat",
	HairAccessory = "Hair",
	FaceAccessory = "FaceAccessory",
	NeckAccessory = "Neck",
	ShoulderAccessory = "Shoulder",
	FrontAccessory = "Front",
	BackAccessory = "Back",
	WaistAccessory = "Waist",
	Shirt = "Shirt",
	Pants = "Pants",
	TShirt = "TShirt",
	Face = "ClassicFace",
}

-- Types people might write that are layered (3D) clothing, body parts or the wrong name.
local LAYERED = {
	Shirt = true,
	Pants = true,
	TShirt = true,
	Jacket = true,
	Sweater = true,
	Shorts = true,
	DressSkirt = true,
	LeftShoe = true,
	RightShoe = true,
	Eyebrow = true,
	Eyelash = true,
	ShirtAccessory = true,
	PantsAccessory = true,
	TShirtAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShortsAccessory = true,
	DressSkirtAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
	EyebrowAccessory = true,
	EyelashAccessory = true,
}

-- Head-slot accessories: they sit on the real head, inside or on top of a head piece.
local HEAD_SLOT = { Hat = true, Hair = true, FaceAccessory = true }

local function isFinite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function isId(x: any): boolean
	return isFinite(x) and x > 0 and x < 2 ^ 53 and x % 1 == 0
end

local function isSequence(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	local n = #t
	local count = 0
	for key in t do
		count += 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > n then
			return false
		end
	end
	return count == n
end

local function idText(id: number): string
	return ("%d"):format(id)
end

local function typeList(): string
	return table.concat(settings().Types, ", ")
end

function SkinCatalog.Approved(id: unknown): boolean
	return isId(id) and settings().ApprovedIds[id :: number] ~= nil
end

function SkinCatalog.Normalize(value: any, style: any?): (Catalog?, { string }, { string })
	local errors: { string }, warnings: { string } = {}, {}
	if value == nil then
		return nil, errors, warnings
	end
	if type(value) ~= "table" then
		table.insert(
			errors,
			'Catalog should be a table: Catalog = { Accessories = { { Id = 123, Type = "Hat" } } }'
		)
		return nil, errors, warnings
	end
	for key in value do
		if type(key) ~= "string" or not KEYS[key] then
			table.insert(
				errors,
				("Catalog: %s doesn't go here (Accessories, Shirt, Pants, TShirt or ClassicFace)"):format(
					tostring(key)
				)
			)
		end
	end
	local out: Catalog = { Accessories = {} }
	local used: { [number]: boolean } = {}
	local function claim(id: number, what: string): boolean
		if used[id] then
			table.insert(errors, ("Catalog: id %s is used twice (%s)"):format(idText(id), what))
			return false
		end
		used[id] = true
		return true
	end

	local list = value.Accessories
	if list ~= nil then
		local max = settings().MaxAccessories
		if not isSequence(list) then
			table.insert(
				errors,
				'Catalog: Accessories should be a list: Accessories = { { Id = 123, Type = "Hat" } }'
			)
		else
			if #list > max then
				table.insert(
					errors,
					("Catalog: %d accessories; a skin can have at most %d"):format(#list, max)
				)
			end
			for i, entry in list do
				if i > max then
					break
				end
				local prefix = ("Catalog: accessory %d "):format(i)
				if type(entry) ~= "table" then
					table.insert(
						errors,
						prefix .. 'should be a table like { Id = 123, Type = "Hat" }'
					)
					continue
				end
				local fine = true
				for key in entry do
					if key ~= "Id" and key ~= "Type" then
						table.insert(
							errors,
							prefix
								.. ("has %s, which doesn't go here (Id and Type)"):format(
									tostring(key)
								)
						)
						fine = false
					end
				end
				local id, kind = entry.Id, entry.Type
				if not isId(id) then
					table.insert(
						errors,
						prefix .. "needs Id = a catalog id (a whole number above 0)"
					)
					fine = false
				end
				if type(kind) ~= "string" then
					table.insert(errors, prefix .. ("needs a Type (%s)"):format(typeList()))
					fine = false
				elseif not table.find(settings().Types, kind) then
					if kind == "Face" then
						table.insert(
							errors,
							prefix
								.. "Type Face: use FaceAccessory for glasses or a mask, or ClassicFace = <id> for a flat face"
						)
					elseif LAYERED[kind] then
						table.insert(
							errors,
							prefix
								.. ("Type %s is layered (3D) clothing, which can't go in a skin: use Shirt = <id> or Pants = <id> for classic clothes"):format(
									kind
								)
						)
					else
						table.insert(
							errors,
							prefix .. ("Type %s isn't allowed (%s)"):format(kind, typeList())
						)
					end
					fine = false
				end
				if fine and claim(id, "accessory " .. i) then
					table.insert(out.Accessories, { Id = id, Type = kind })
				end
			end
		end
	end

	for _, key in { "Shirt", "Pants", "TShirt", "ClassicFace" } do
		local id = value[key]
		if id == nil then
			continue
		end
		if not isId(id) then
			table.insert(
				errors,
				("Catalog: %s should be a catalog id (a whole number above 0)"):format(key)
			)
		elseif claim(id, key) then
			(out :: any)[key] = id
		end
	end

	if
		#out.Accessories == 0
		and out.Shirt == nil
		and out.Pants == nil
		and out.TShirt == nil
		and out.ClassicFace == nil
	then
		if #errors == 0 then
			table.insert(warnings, "Catalog has no items in it")
		end
		return nil, errors, warnings
	end

	-- Things that won't show, given the rest of the skin.
	if type(style) == "table" then
		for _, key in CLOTHES do
			if (out :: any)[key] ~= nil and style.HideClothes ~= false then
				table.insert(
					warnings,
					("Catalog: the %s won't show because this skin hides clothes: add HideClothes = false"):format(
						key
					)
				)
			end
		end
		if style.Head ~= nil then
			if out.ClassicFace ~= nil then
				table.insert(
					warnings,
					"Catalog: the ClassicFace won't show, the head piece covers the face"
				)
			end
			for _, accessory in out.Accessories do
				if HEAD_SLOT[accessory.Type] then
					table.insert(
						warnings,
						("Catalog: the %s %s sits on your real head, inside or on top of the head piece: check how it looks in Studio"):format(
							accessory.Type,
							idText(accessory.Id)
						)
					)
				end
			end
		end
	end
	for _, id in SkinCatalog.Ids(out) do
		if not SkinCatalog.Approved(id) then
			table.insert(
				warnings,
				("Catalog: id %s isn't in Config.SkinCatalog.ApprovedIds yet (check the item first)"):format(
					idText(id)
				)
			)
		end
	end
	return out, errors, warnings
end

-- Every id in a catalog (raw or normalized), accessories first. Bad ones are left out.
function SkinCatalog.Ids(catalog: any): { number }
	local ids: { number } = {}
	if type(catalog) ~= "table" then
		return ids
	end
	if type(catalog.Accessories) == "table" then
		for _, accessory in catalog.Accessories do
			if type(accessory) == "table" and isId(accessory.Id) then
				table.insert(ids, accessory.Id)
			end
		end
	end
	for _, key in { "Shirt", "Pants", "TShirt", "ClassicFace" } do
		if isId(catalog[key]) then
			table.insert(ids, catalog[key])
		end
	end
	return ids
end

function SkinCatalog.Key(catalog: any): string
	local normal = SkinCatalog.Normalize(catalog)
	if not normal then
		return ""
	end
	local accessories = table.clone(normal.Accessories)
	table.sort(accessories, function(a, b)
		return a.Id < b.Id
	end)
	local parts = {}
	for _, accessory in accessories do
		table.insert(parts, accessory.Type .. ":" .. idText(accessory.Id))
	end
	local text = "A=" .. table.concat(parts, ",")
	for _, key in { "Shirt", "Pants", "TShirt", "ClassicFace" } do
		local id = (normal :: any)[key]
		if id ~= nil then
			text ..= ";" .. key .. "=" .. idText(id)
		end
	end
	return text
end

function SkinCatalog.TypeFromAssetType(assetTypeName: unknown): string?
	if type(assetTypeName) ~= "string" then
		return nil
	end
	return (ASSET_TYPES :: { [string]: string })[assetTypeName]
end

function SkinCatalog.TypeFromAssetTypeId(assetTypeId: unknown): string?
	if not isFinite(assetTypeId) then
		return nil
	end
	for _, item in Enum.AssetType:GetEnumItems() do
		if item.Value == assetTypeId then
			return SkinCatalog.TypeFromAssetType(item.Name)
		end
	end
	return nil
end

function SkinCatalog.AccessoryType(kind: unknown): Enum.AccessoryType?
	local name = if type(kind) == "string"
		then (ACCESSORY_ENUM :: { [string]: string })[kind]
		else nil
	if not name then
		return nil
	end
	local ok, item = pcall(function()
		return (Enum.AccessoryType :: any)[name]
	end)
	return if ok then item else nil
end

function SkinCatalog.CreatorAllowed(creatorType: unknown, creatorId: unknown): boolean
	if type(creatorType) ~= "string" or not isId(creatorId) then
		return false
	end
	local allowed = settings().AllowedCreators
	if creatorType == "User" then
		-- Roblox's own items are made by the user Roblox (UserId 1).
		if creatorId == 1 and allowed.Roblox then
			return true
		end
		return table.find(allowed.UserIds, creatorId :: number) ~= nil
	elseif creatorType == "Group" then
		return table.find(allowed.GroupIds, creatorId :: number) ~= nil
	end
	return false
end

function SkinCatalog.Thumbnail(id: number): string
	local size = if settings().ThumbnailSize == 420 then 420 else 150
	return ("rbxthumb://type=Asset&id=%s&w=%d&h=%d"):format(idText(id), size, size)
end

return SkinCatalog
