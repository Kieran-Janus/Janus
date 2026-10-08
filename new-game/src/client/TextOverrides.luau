--!strict
--[[
	Your own words instead of the game's (this screen only): every TextLabel and TextButton on
	the screen and on signs in the world whose text is (or contains) a "From" text shows your
	"To" text instead, also when the code changes the text later.

	The pairs come from Config.TextOverrides.Pairs (in git) and the place's
	ReplicatedStorage.TextOverrides folder (StringValues with the attribute From; the Pumpkin
	Tools plugin makes them, and they win over the Config lines). Nothing runs while there are
	no pairs. Text boxes players type in are never changed.

	TextOverrides.Pairs() -> { { From, To } }       the pairs in use (longest From first)
	TextOverrides.Apply(text, pairs) -> string      the text with the pairs applied
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TextOverrides = {}

export type Pair = { From: string, To: string }

local FOLDER = "TextOverrides"

function TextOverrides.Pairs(): { Pair }
	if not Config.TextOverrides.On then
		return {}
	end
	local merged: { [string]: string } = table.clone(Config.TextOverrides.Pairs)
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if folder then
		for _, value in folder:GetChildren() do
			local from = value:GetAttribute("From")
			if value:IsA("StringValue") and type(from) == "string" and from ~= "" then
				merged[from] = value.Value
			end
		end
	end
	local list: { Pair } = {}
	for from, to in merged do
		-- (a "To" holding its own "From" would grow every time the text is set: skipped)
		if from ~= to and not string.find(to, from, 1, true) then
			table.insert(list, { From = from, To = to })
		end
	end
	-- Longest first: a whole sentence wins over a word inside it.
	table.sort(list, function(a, b)
		return #a.From > #b.From
	end)
	return list
end

local function replacePlain(text: string, from: string, to: string): string
	local out = {}
	local start = 1
	while true do
		local i, j = string.find(text, from, start, true)
		if not i then
			break
		end
		table.insert(out, string.sub(text, start, i - 1))
		table.insert(out, to)
		start = (j :: number) + 1
	end
	table.insert(out, string.sub(text, start))
	return table.concat(out)
end

function TextOverrides.Apply(text: string, pairs: { Pair }): string
	for _, pair in pairs do
		if text == pair.From then
			return pair.To
		end
	end
	for _, pair in pairs do
		if string.find(text, pair.From, 1, true) then
			text = replacePlain(text, pair.From, pair.To)
		end
	end
	return text
end

function TextOverrides.Mount(_gui: ScreenGui?)
	local current: { Pair } = TextOverrides.Pairs()
	local watched: { [Instance]: RBXScriptConnection } = {}
	local busy: { [Instance]: boolean } = {}
	local roots: { RBXScriptConnection } = {}

	local function fix(label: TextLabel | TextButton)
		if busy[label] or #current == 0 then
			return
		end
		local new = TextOverrides.Apply(label.Text, current)
		if new ~= label.Text then
			busy[label] = true
			label.Text = new
			busy[label] = nil
		end
	end

	local function watch(instance: Instance)
		if watched[instance] then
			return
		end
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			local label = instance :: TextLabel
			watched[label] = label:GetPropertyChangedSignal("Text"):Connect(function()
				fix(label)
			end)
			fix(label)
		end
	end

	local function unwatch(instance: Instance)
		local connection = watched[instance]
		if connection then
			connection:Disconnect()
			watched[instance] = nil
		end
	end

	local function start()
		if #roots > 0 then
			return
		end
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		for _, root in { playerGui, workspace } do
			for _, d in root:GetDescendants() do
				watch(d)
			end
			table.insert(roots, root.DescendantAdded:Connect(watch))
			table.insert(roots, root.DescendantRemoving:Connect(unwatch))
		end
	end

	local function stop()
		for _, connection in roots do
			connection:Disconnect()
		end
		table.clear(roots)
		for instance in watched do
			unwatch(instance)
		end
	end

	-- New pairs (the plugin adding one in a playtest, or the folder arriving late): fix what is
	-- on screen now. Texts already swapped by an old pair keep it until the code sets them again.
	local function refresh()
		current = TextOverrides.Pairs()
		if #current == 0 then
			stop()
			return
		end
		start()
		for instance in watched do
			fix(instance :: TextLabel)
		end
	end

	local function watchFolder(folder: Instance)
		folder.ChildAdded:Connect(function(child)
			child:GetPropertyChangedSignal("Value"):Connect(refresh)
			child.AttributeChanged:Connect(refresh)
			refresh()
		end)
		folder.ChildRemoved:Connect(refresh)
		for _, child in folder:GetChildren() do
			child:GetPropertyChangedSignal("Value"):Connect(refresh)
			child.AttributeChanged:Connect(refresh)
		end
	end

	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if folder then
		watchFolder(folder)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == FOLDER then
			watchFolder(child)
			refresh()
		end
	end)
	if #current > 0 then
		task.spawn(start)
	end
end

return TextOverrides
