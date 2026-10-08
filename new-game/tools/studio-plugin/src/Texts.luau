--!strict
--[[
	The words part of Pumpkin Tools: find the texts in what you clicked, and keep your word
	changes in the place's ReplicatedStorage.TextOverrides folder (StringValues: attribute
	From = the game's words, Value = yours). The game's client (src/client/TextOverrides.luau)
	swaps them on every screen and sign.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = {}

local FOLDER = "TextOverrides"

export type Change = { Value: StringValue, From: string, To: string }

function Texts.Folder(create: boolean): Instance?
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ReplicatedStorage
	end
	return folder
end

function Texts.List(): { Change }
	local out: { Change } = {}
	local folder = Texts.Folder(false)
	if folder then
		for _, v in folder:GetChildren() do
			local from = v:GetAttribute("From")
			if v:IsA("StringValue") and type(from) == "string" then
				table.insert(out, { Value = v, From = from, To = v.Value })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.From:lower() < b.From:lower()
	end)
	return out
end

-- Adds (or updates) one change: everywhere `from` shows, `to` shows instead.
function Texts.Set(from: string, to: string): StringValue
	local folder = Texts.Folder(true) :: Instance
	for _, change in Texts.List() do
		if change.From == from then
			change.Value.Value = to
			return change.Value
		end
	end
	local value = Instance.new("StringValue")
	value.Name = "Text" .. (#folder:GetChildren() + 1)
	value:SetAttribute("From", from)
	value.Value = to
	value.Parent = folder
	return value
end

local function isText(instance: Instance): boolean
	return (instance:IsA("TextLabel") or instance:IsA("TextButton"))
		and (instance :: TextLabel).Text ~= ""
end

-- The texts in what you clicked: itself, everything inside it, and (for a part of a sign
-- or a model) everything in the model it belongs to. At most `limit`.
function Texts.InThing(thing: Instance, limit: number): { TextLabel }
	local found: { TextLabel } = {}
	local seen: { [Instance]: boolean } = {}
	local function add(instance: Instance)
		if #found < limit and not seen[instance] and isText(instance) then
			seen[instance] = true
			table.insert(found, instance :: TextLabel)
		end
	end
	add(thing)
	for _, d in thing:GetDescendants() do
		add(d)
	end
	if #found == 0 then
		local model = thing:FindFirstAncestorWhichIsA("Model")
		if model and model ~= workspace then
			for _, d in model:GetDescendants() do
				add(d)
			end
		end
	end
	return found
end

-- Where a text sits, in words: "Signpost > Arm3 > SurfaceGui > Label".
function Texts.Where(label: Instance): string
	local parts = {}
	local node: Instance? = label
	while node and node ~= game and #parts < 4 do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, " > ")
end

return Texts
