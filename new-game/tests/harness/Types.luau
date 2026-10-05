--[[
	typeof() that knows the harness's fake types. A fake declares its Roblox type name with a
	`__type` field on its metatable (instances report "Instance", signals "RBXScriptSignal",
	Random "Random", ...). Everything else falls through to Lune's typeof.
]]

local luneTypeof = typeof

local Types = {}

function Types.typeof(value: any): string
	local t = type(value)
	if t == "table" or t == "userdata" then
		local mt = getmetatable(value)
		if type(mt) == "table" then
			local name = rawget(mt, "__type")
			if name then
				return name
			end
		end
	end
	return luneTypeof(value)
end

-- A table class with a Roblox-like type name: Types.class("Random") -> metatable.
function Types.class(name: string, methods: { [string]: any }?): { [string]: any }
	local mt = { __type = name }
	mt.__index = methods or {}
	mt.__tostring = function()
		return name
	end
	return mt
end

return Types
