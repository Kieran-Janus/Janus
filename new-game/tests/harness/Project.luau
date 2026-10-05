--[[
	Builds the DataModel the way `rojo build` would, straight from the files (no rojo needed
	at test time):

	  default.project.json   tree nodes with $className / $path / $properties / $attributes
	  folder/                Folder (or init.luau -> ModuleScript, init.server.luau -> Script,
	                         init.client.luau -> LocalScript; init.meta.json -> className,
	                         properties, attributes)
	  X.luau / X.lua         ModuleScript X
	  X.server.luau          Script X
	  X.client.luau          LocalScript X
	  X.meta.json            properties / attributes for sibling X
	  X.json                 ModuleScript returning the decoded JSON
	  X.model.json           instances described in JSON
	  X.txt                  StringValue
	  X.rbxm / X.rbxmx       model files (read with Lune, converted)
	  anything else          ignored (README.md, .gitkeep, ...)

	Project.loadPlace converts a whole place file (e.g. the output of `rojo build`) instead.
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Dom = require("./Dom")
local Types = require("./Types")

local typeof = Types.typeof

local Project = {}

local function join(a: string, b: string): string
	if a == "" or a == "." then
		return b
	end
	return a .. "/" .. b
end

local function readJson(path: string): any
	if not fs.isFile(path) then
		return nil
	end
	return serde.decode("json", fs.readFile(path))
end

-- Property values ---------------------------------------------------------------------------------

local function enumItem(datatype: string, value: any): any
	local ok, items = pcall(function()
		return roblox.Enum[datatype:sub(6)]:GetEnumItems()
	end)
	if ok then
		for _, item in items do
			if item.Name == value or item.Value == value then
				return item
			end
		end
	end
	error(("can't convert %s to %s"):format(tostring(value), datatype))
end

-- Rojo's implicit ([1, 2, 3]) and explicit ({ "Vector3": [1, 2, 3] }) property values.
local function decodeValue(datatype: string?, value: any): any
	if type(value) == "table" and value[1] == nil and next(value) ~= nil then
		local key, inner = next(value)
		datatype, value = key, inner
	end
	if datatype == nil or type(value) ~= "table" then
		if datatype and datatype:sub(1, 5) == "Enum." then
			return enumItem(datatype, value)
		elseif datatype == "Enum" and type(value) == "number" then
			return value
		end
		return value
	end
	local v = value :: { any }
	if datatype == "Vector3" then
		return roblox.Vector3.new(v[1], v[2], v[3])
	elseif datatype == "Vector2" then
		return roblox.Vector2.new(v[1], v[2])
	elseif datatype == "Color3" then
		return roblox.Color3.new(v[1], v[2], v[3])
	elseif datatype == "Color3uint8" then
		return roblox.Color3.fromRGB(v[1], v[2], v[3])
	elseif datatype == "UDim" then
		return roblox.UDim.new(v[1], v[2])
	elseif datatype == "UDim2" then
		return roblox.UDim2.new(v[1][1], v[1][2], v[2][1], v[2][2])
	elseif datatype == "NumberRange" then
		return roblox.NumberRange.new(v[1], v[2])
	elseif datatype == "Rect" then
		return roblox.Rect.new(v[1][1], v[1][2], v[2][1], v[2][2])
	elseif datatype == "CFrame" then
		local p, o = (value :: any).position, (value :: any).orientation
		if p and o then
			return roblox.CFrame.new(
				p[1],
				p[2],
				p[3],
				o[1][1],
				o[2][1],
				o[3][1],
				o[1][2],
				o[2][2],
				o[3][2],
				o[1][3],
				o[2][3],
				o[3][3]
			)
		end
	elseif datatype == "Tags" then
		return value
	end
	return value
end

local function setProperty(inst: any, name: string, raw: any)
	local member = Dom.member(inst, name)
	if name == "Tags" then
		for _, tag in decodeValue("Tags", raw) do
			inst:AddTag(tag)
		end
		return
	end
	if name == "Attributes" then
		for k, v in raw do
			inst:SetAttribute(k, decodeValue(nil, v))
		end
		return
	end
	local value = decodeValue(member and member.type, raw)
	Dom.set(inst, name, value)
end

local function applyMeta(inst: any, meta: any)
	if not meta then
		return
	end
	for name, value in meta.properties or {} do
		setProperty(inst, name, value)
	end
	for name, value in meta.attributes or {} do
		inst:SetAttribute(name, decodeValue(nil, value))
	end
end

-- Lune instances (rbxm / rbxl) --------------------------------------------------------------------

--[[
	Converts a Lune instance tree into harness instances: every readable property (per the
	reflection database), attributes, tags, script Source and references inside the tree.
]]
function Project.convert(rt: any, luneRoot: any): any
	local pairs_: { { any } } = {}
	local refs: { { any } } = {}
	local function convertOne(li: any): any
		local className = li.ClassName
		local class = Dom.getClass(className)
		local inst = Dom.new(rt, if class then className else "Folder", true);
		(inst :: any).Name = li.Name
		local seen = {}
		local c = class
		while c do
			for propName, info in c.Db.Properties do
				if not seen[propName] and info.Scriptability ~= "None" then
					seen[propName] = true
					local ok, value = pcall(function()
						return li[propName]
					end)
					if ok and value ~= nil then
						if typeof(value) == "Instance" then
							table.insert(refs, { inst, propName, value })
						elseif propName ~= "Parent" and propName ~= "Name" then
							Dom.rawSet(inst, propName, value)
						end
					end
				end
			end
			c = c.Super
		end
		local okSource, source = pcall(function()
			return li.Source
		end)
		if okSource and type(source) == "string" then
			Dom.setSource(inst, source, nil)
		end
		local okAttrs, attrs = pcall(function()
			return li:GetAttributes()
		end)
		if okAttrs then
			for k, v in attrs do
				inst:SetAttribute(k, v)
			end
		end
		local okTags, tags = pcall(function()
			return li:GetTags()
		end)
		if okTags then
			for _, tag in tags do
				inst:AddTag(tag)
			end
		end
		table.insert(pairs_, { li, inst })
		for _, child in li:GetChildren() do
			Dom.setParent(convertOne(child), inst)
		end
		return inst
	end
	local root = convertOne(luneRoot)
	for _, ref in refs do
		for _, pair in pairs_ do
			if pair[1] == ref[3] then
				Dom.rawSet(ref[1], ref[2], pair[2])
				break
			end
		end
	end
	return root
end

local function loadModelFile(rt: any, path: string, name: string): any
	local models = roblox.deserializeModel(fs.readFile(path))
	if #models == 1 then
		local inst = Project.convert(rt, models[1])
		inst.Name = name
		return inst
	end
	local folder = Dom.new(rt, "Folder", true)
	folder.Name = name
	for _, m in models do
		Dom.setParent(Project.convert(rt, m), folder)
	end
	return folder
end

-- Files and folders ---------------------------------------------------------------------------------

local SCRIPT_SUFFIXES = {
	{ ".server.luau", "Script" },
	{ ".server.lua", "Script" },
	{ ".client.luau", "LocalScript" },
	{ ".client.lua", "LocalScript" },
	{ ".luau", "ModuleScript" },
	{ ".lua", "ModuleScript" },
}

local INIT_FILES = {
	{ "init.server.luau", "Script" },
	{ "init.server.lua", "Script" },
	{ "init.client.luau", "LocalScript" },
	{ "init.client.lua", "LocalScript" },
	{ "init.luau", "ModuleScript" },
	{ "init.lua", "ModuleScript" },
}

local function endsWith(s: string, suffix: string): boolean
	return #s >= #suffix and s:sub(-#suffix) == suffix
end

-- Luau source that returns a JSON value (how Rojo turns X.json into a ModuleScript).
local function toLuau(value: any): string
	local t = type(value)
	if t == "table" then
		local parts = {}
		if #value > 0 or next(value) == nil then
			for _, v in value do
				table.insert(parts, toLuau(v))
			end
		else
			for k, v in value do
				table.insert(parts, ("[%q] = %s"):format(tostring(k), toLuau(v)))
			end
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local loadPath: (rt: any, path: string, name: string) -> any

local function buildModelJson(rt: any, node: any, fallbackName: string): any
	local inst = Dom.new(rt, node.ClassName or node.className or "Folder", true)
	inst.Name = node.Name or node.name or fallbackName
	for name, value in node.Properties or node.properties or {} do
		setProperty(inst, name, value)
	end
	for name, value in node.Attributes or node.attributes or {} do
		inst:SetAttribute(name, decodeValue(nil, value))
	end
	for _, child in node.Children or node.children or {} do
		Dom.setParent(buildModelJson(rt, child, "Instance"), inst)
	end
	return inst
end

local function loadFile(rt: any, path: string, fileName: string, dir: string): any
	for _, entry in SCRIPT_SUFFIXES do
		if endsWith(fileName, entry[1]) then
			local name = fileName:sub(1, -#entry[1] - 1)
			local inst = Dom.new(rt, entry[2], true)
			inst.Name = name
			Dom.setSource(inst, fs.readFile(path), rt:relativePath(path))
			applyMeta(inst, readJson(join(dir, name .. ".meta.json")))
			return inst
		end
	end
	if endsWith(fileName, ".meta.json") then
		return nil
	elseif endsWith(fileName, ".model.json") then
		return buildModelJson(rt, readJson(path), fileName:sub(1, -#".model.json" - 1))
	elseif endsWith(fileName, ".project.json") then
		return nil
	elseif endsWith(fileName, ".json") then
		local name = fileName:sub(1, -#".json" - 1)
		local inst = Dom.new(rt, "ModuleScript", true)
		inst.Name = name
		Dom.setSource(inst, "return " .. toLuau(readJson(path)), rt:relativePath(path))
		applyMeta(inst, readJson(join(dir, name .. ".meta.json")))
		return inst
	elseif endsWith(fileName, ".txt") then
		local name = fileName:sub(1, -#".txt" - 1)
		local inst = Dom.new(rt, "StringValue", true)
		inst.Name = name
		Dom.set(inst, "Value", fs.readFile(path))
		applyMeta(inst, readJson(join(dir, name .. ".meta.json")))
		return inst
	elseif endsWith(fileName, ".rbxm") or endsWith(fileName, ".rbxmx") then
		local name = fileName:gsub("%.rbxmx?$", "")
		return loadModelFile(rt, path, name)
	end
	return nil
end

local loadProjectNode: (rt: any, node: any, name: string, root: string) -> any

loadPath = function(rt: any, path: string, name: string): any
	if fs.isFile(path) then
		local dir, file = path:match("^(.*)/([^/]+)$")
		local inst = loadFile(rt, path, file or path, dir or ".")
		if inst then
			inst.Name = name
		end
		return inst
	end
	if not fs.isDir(path) then
		error(("project path %s does not exist"):format(path))
	end
	local nested = join(path, "default.project.json")
	if fs.isFile(nested) then
		local project = readJson(nested)
		return loadProjectNode(rt, project.tree, name, path)
	end
	local inst
	for _, init in INIT_FILES do
		local p = join(path, init[1])
		if fs.isFile(p) then
			inst = Dom.new(rt, init[2], true)
			Dom.setSource(inst, fs.readFile(p), rt:relativePath(p))
			break
		end
	end
	local meta = readJson(join(path, "init.meta.json"))
	if not inst then
		inst = Dom.new(rt, (meta and meta.className) or "Folder", true)
	end
	inst.Name = name
	applyMeta(inst, meta)
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		local childPath = join(path, entry)
		local isInit = false
		for _, init in INIT_FILES do
			if entry == init[1] then
				isInit = true
			end
		end
		if isInit or entry == "init.meta.json" then
			continue
		end
		local child
		if fs.isDir(childPath) then
			child = loadPath(rt, childPath, entry)
		else
			child = loadFile(rt, childPath, entry, path)
		end
		if child then
			Dom.setParent(child, inst)
		end
	end
	return inst
end

--[[
	A project tree node (and its children) as an instance. When `parent` already has a child
	with this name and class (e.g. StarterPlayerScripts, which every place starts with), that
	child is filled in instead of adding a second one.
]]
loadProjectNode = function(rt: any, node: any, name: string, root: string, parent: any?): any
	local className = node["$className"]
	local inst
	if node["$path"] then
		inst = loadPath(rt, join(root, node["$path"]), name)
	else
		local existing = parent and parent:FindFirstChild(name)
		if existing and existing.ClassName == (className or "Folder") then
			inst = existing
		else
			inst = Dom.new(rt, className or "Folder", true)
			inst.Name = name
		end
	end
	applyMeta(inst, { properties = node["$properties"], attributes = node["$attributes"] })
	for key, child in node do
		if key:sub(1, 1) ~= "$" then
			local childInst = loadProjectNode(rt, child, key, root, inst)
			Dom.setParent(childInst, inst)
		end
	end
	return inst
end

function Project.load(rt: any, root: string, projectFile: string)
	local path = join(root, projectFile)
	local project = readJson(path)
	if not project then
		error(
			("can't find %s (run the tests from the project folder, or pass root =)"):format(path)
		)
	end
	local tree = project.tree
	applyMeta(rt.game, { properties = tree["$properties"] })
	for key, node in tree do
		if key:sub(1, 1) == "$" then
			continue
		end
		local className = node["$className"] or key
		local class = Dom.getClass(className)
		if class and class.Tags.Service then
			-- A service: fill the existing one.
			local service = rt:getService(className)
			applyMeta(
				service,
				{ properties = node["$properties"], attributes = node["$attributes"] }
			)
			if node["$path"] then
				local loaded = loadPath(rt, join(root, node["$path"]), key)
				for _, child in loaded:GetChildren() do
					Dom.setParent(child, service)
				end
			end
			for childKey, child in node do
				if childKey:sub(1, 1) ~= "$" then
					Dom.setParent(loadProjectNode(rt, child, childKey, root, service), service)
				end
			end
		else
			Dom.setParent(loadProjectNode(rt, node, key, root, rt.game), rt.game)
		end
	end
end

function Project.loadPlace(rt: any, path: string)
	local place = roblox.deserializePlace(fs.readFile(path))
	for _, service in place:GetChildren() do
		local class = Dom.getClass(service.ClassName)
		if class and class.Tags.Service then
			local target = rt:getService(service.ClassName)
			for _, child in service:GetChildren() do
				if child.ClassName ~= "Terrain" and child.ClassName ~= "Camera" then
					Dom.setParent(Project.convert(rt, child), target)
				end
			end
		else
			Dom.setParent(Project.convert(rt, service), rt.game)
		end
	end
end

return Project
