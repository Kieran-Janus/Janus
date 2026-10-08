--!strict
--[[
	SWAP: replace every copy of something at once, also in a lobby or map saved in your place
	(a Locked hub, a map baked into ServerStorage.Maps), where the builders don't run any more.
	Run these in Studio's command bar (View > Command Bar) while the game is NOT running (edit
	mode), then save the place (Ctrl+S). Ctrl+Z undoes them. In a playtest, F8 > "Apply custom
	props" runs Swap.Props() for that playtest only (it leaves the round map being played and
	the hiders' pumpkins alone: the next map loads with your models by itself).

	  require(game.ServerScriptService.Server.Tools.Swap).Props()
	      Every prop (a Model with a PropName attribute: JackOLantern, Pumpkin, HayBale...) in
	      Workspace (the hub too, even Locked) and ServerStorage.Maps is replaced by the model
	      of that name in ReplicatedStorage.Custom.Props: same spot, size and facing, and it
	      keeps the tags and attributes the game needs (decoys stay decoys, working parts stay).
	      Props that already are your model get a fresh copy (so changes to your model show).
	      Props with no custom model are left alone. The ones it replaced are kept in
	      ServerStorage.PropBackups so Revert can bring them back.
	  require(game.ServerScriptService.Server.Tools.Swap).Props({ Revert = true })
	      The same, and first puts the built look back on props whose custom model you removed
	      from Custom.Props (only ones Swap replaced: those have a backup).
	  require(game.ServerScriptService.Server.Tools.Swap).Replace("Rock", workspace.MyRock)
	      For things that aren't props (ones you placed by hand): every Model or Part NAMED
	      "Rock" in Workspace and ServerStorage.Maps is replaced by a copy of workspace.MyRock,
	      at the same spot and facing, scaled to the old one's height. A third argument limits
	      it to one place, e.g. Replace("Rock", workspace.MyRock, workspace.Hub). Prints how
	      many it changed. Props, and the parts inside them (a jack-o'-lantern's core is
	      called "Pumpkin", a gravestone's slab "Tombstone"), are left alone: a prop name
	      (Pumpkin, Gravestone...) goes in Custom.Props and Swap.Props() instead.

	  require(game.ServerScriptService.Server.Tools.Swap).Toolbox("Pumpkin", 11600489662)
	      Downloads that Toolbox (Creator Store) model (scripts removed), puts it in
	      Custom.Props as "Pumpkin" and runs Props(): every pumpkin gets that look. A list of
	      names works too. The code can be the number or the Creator Store link.
	  require(game.ServerScriptService.Server.Tools.Swap).Selected(11600489662)
	      Only what you selected in Studio gets that look; every other copy stays as it is.
	  require(game.ServerScriptService.Server.Tools.Swap).Egg("ForestGhost", 15145049241)
	      One secret pumpkin (Easter egg, by its Id) gets that look.
	A Toolbox pack (a folder of several trees) is spread over the copies: every kind is used.

	Each one prints what it did and returns how many it changed (and that message).
	Step by step: docs/CUSTOMIZE.md > "Swap every copy of something at once".
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local CustomAssets = require(ReplicatedStorage.Shared.CustomAssets)
local Kit = require(script.Parent.Parent.Build.Kit)
local MapService = require(script.Parent.Parent.Services.MapService)

local Swap = {}

export type PropsOptions = {
	Revert: boolean?, -- put the built look back where the custom model was removed
}

local BACKUP_FOLDER = "PropBackups" -- ServerStorage.PropBackups: props Swap replaced
local ORIGINAL = "OriginalProp" -- ObjectValue in a swapped prop: its backup

local function say(text: string)
	print("[Swap] " .. text)
end

-- Studio edit mode (not a playtest): the only time Ctrl+Z can undo it.
local function editing(): boolean
	return RunService:IsStudio() and not RunService:IsRunning()
end

--[[
	Runs `change` as one step Ctrl+Z can undo (in Studio edit mode, run from the command bar).
	If it fails half way, the half-made change is undone too.
]]
local function undoable(name: string, change: () -> ())
	local history: any = nil
	local recording: string? = nil
	if editing() then
		pcall(function()
			history = game:GetService("ChangeHistoryService")
		end)
		if history then
			local ok, id = pcall(function()
				return history:TryBeginRecording(name, name)
			end)
			recording = if ok and type(id) == "string" then id else nil
			if not recording then
				pcall(function()
					history:SetWaypoint("Before " .. name)
				end)
			end
		end
	end
	local ok, err = pcall(change :: any) -- (cast: the old type checker misreads pcall of a function returning nothing)
	if history then
		if recording then
			local finish = if ok
				then Enum.FinishRecordingOperation.Commit
				else Enum.FinishRecordingOperation.Cancel
			pcall(function()
				history:FinishRecording(recording, finish)
			end)
		elseif ok then
			pcall(function()
				history:SetWaypoint(name)
			end)
		end
	end
	if not ok then
		error(err, 0)
	end
end

-- Where to look: Workspace and ServerStorage.Maps (or just `root`).
local function rootsOf(root: Instance?): { Instance }
	if root then
		return { root }
	end
	local roots: { Instance } = { workspace }
	local maps = ServerStorage:FindFirstChild("Maps")
	if maps then
		table.insert(roots, maps)
	end
	return roots
end

--[[
	During a playtest: true for things a round is using right now, which Swap.Props leaves
	alone. That is the round map being played (its pickups, decoys and hiding spots are in
	use; the next map loads with your models by itself) and a Hide & Seek hider's pumpkin
	(welded to the hider: a swapped copy would stand still and couldn't be tagged).
]]
local function inUse(m: Model): boolean
	if not RunService:IsRunning() then
		return false
	end
	local node: Instance? = m
	while node do
		if node:GetAttribute("HiderUserId") ~= nil then
			return true
		end
		node = node.Parent
	end
	local map = MapService.Current()
	return map ~= nil and m:IsDescendantOf(map.Model)
end

local function backupFolder(): Folder
	local existing = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = BACKUP_FOLDER
	folder.Parent = ServerStorage
	return folder
end

-- The backup a swapped prop points at (its built look), or nil.
local function originalOf(m: Model): Model?
	local link = m:FindFirstChild(ORIGINAL)
	if link and link:IsA("ObjectValue") and link.Value and link.Value:IsA("Model") then
		return link.Value
	end
	return nil
end

-- "JackOLantern x29, Pumpkin x45" from a count per name.
local function summary(counts: { [string]: number }): string
	local names = {}
	for name in counts do
		table.insert(names, name)
	end
	table.sort(names)
	local parts = {}
	for _, name in names do
		table.insert(parts, ("%s x%d"):format(name, counts[name]))
	end
	return table.concat(parts, ", ")
end

-- Puts a backed-up built prop back in place of the custom one `custom` (Revert).
local function restore(custom: Model, original: Model)
	local parent = custom.Parent
	if not parent then
		return
	end
	local link = original:FindFirstChild(ORIGINAL)
	if link then
		link:Destroy()
	end
	original:PivotTo(custom:GetPivot()) -- where the custom one is now (it may have been moved)
	original.Parent = parent
	for _, tag in CollectionService:GetTags(custom) do
		CollectionService:AddTag(original, tag)
	end
	for key, value in custom:GetAttributes() do
		if key ~= "CustomProp" and original:GetAttribute(key) == nil then
			original:SetAttribute(key, value)
		end
	end
	-- Working parts that were moved into the custom prop go back too.
	for _, child in custom:GetChildren() do
		if child:IsA("BasePart") and Kit.isWorking(child) then
			child.Parent = original
		end
	end
	if original:GetAttribute("PropLook") == true and parent:IsA("BasePart") then
		Kit.showWorkingPart(parent)
	end
	custom:Destroy()
end

-- Swaps one prop for its custom model (or `model`, another Custom.Props name), keeping the
-- built look as a backup (Revert); a custom one is just replaced. Returns the new one.
local function swapOne(old: Model, model: string?): Model?
	local new = Kit.swapProp(old, model)
	if not new then
		return nil
	end
	local original = originalOf(old)
	if not original and old:GetAttribute("CustomProp") ~= true then
		original = old
	end
	if original then
		local link = Instance.new("ObjectValue")
		link.Name = ORIGINAL
		link.Value = original
		link.Parent = new
	end
	if original == old then
		for _, tag in CollectionService:GetTags(old) do
			-- (a backup must never count as a working piece)
			CollectionService:RemoveTag(old, tag)
		end
		old.Parent = backupFolder()
	else
		old:Destroy()
	end
	return new
end

--[[
	Swaps every prop (Model with a PropName attribute) in Workspace and ServerStorage.Maps for
	its model in ReplicatedStorage.Custom.Props. Returns how many props it changed and the
	message it printed. options.Revert (or "Revert") also puts the built look back where you
	removed the custom model.
]]
function Swap.Props(options: (PropsOptions | string)?): (number, string)
	local revert = options == "Revert"
		or (type(options) == "table" and (options :: PropsOptions).Revert == true)
	local swapped: { [string]: number } = {}
	local reverted: { [string]: number } = {}
	local stuck: { [string]: number } = {}
	local busy = 0 -- props left alone because a round is using them (inUse)
	local total = 0
	undoable("Swap props", function()
		for _, root in rootsOf(nil) do
			if revert then
				-- Custom props whose model is no longer in Custom.Props: back to the built look.
				local gone = Kit.findProps(root, function(m: Model): boolean
					return m:GetAttribute("CustomProp") == true
						and not CustomAssets.Has("Props", Kit.customName(m) or "")
						and not inUse(m)
				end)
				for _, custom in gone do
					local name = custom:GetAttribute("PropName") :: string
					local original = originalOf(custom)
					if original then
						restore(custom, original)
						reverted[name] = (reverted[name] or 0) + 1
						total += 1
					else
						stuck[name] = (stuck[name] or 0) + 1
					end
				end
			end
			local list = Kit.findProps(root, function(m: Model): boolean
				if not CustomAssets.Has("Props", Kit.customName(m) or "") then
					return false
				end
				if inUse(m) then
					busy += 1
					return false
				end
				return true
			end)
			for _, old in list do
				local name = old:GetAttribute("PropName") :: string
				if not swapOne(old) then
					continue
				end
				swapped[name] = (swapped[name] or 0) + 1
				total += 1
			end
		end
	end)
	local lines = {}
	if next(swapped) then
		table.insert(lines, "Swapped " .. summary(swapped) .. ".")
	end
	if next(reverted) then
		table.insert(lines, "Put the built look back: " .. summary(reverted) .. ".")
	end
	if next(stuck) then
		table.insert(
			lines,
			"Couldn't put back (no backup, they were built with your model): "
				.. summary(stuck)
				.. ". Bake the hub or map again to rebuild them."
		)
	end
	if #lines == 0 and busy == 0 then
		local custom = ReplicatedStorage:FindFirstChild("Custom")
		local props = custom and custom:FindFirstChild("Props")
		local mine = 0
		for _, child in if props then props:GetChildren() else {} do
			if child:IsA("Model") or child:IsA("BasePart") then
				mine += 1
			end
		end
		table.insert(
			lines,
			if mine == 0
				then "Nothing to swap: put a model named like a prop (its PropName, e.g. JackOLantern) in ReplicatedStorage > Custom > Props first."
				else "Nothing to swap: no lobby or map saved in your place has those props (the lobby and maps built when the game starts use your models by themselves; Swap.Props() is for a lobby or map you baked). Check your model's name matches a PropName exactly."
		)
	end
	if busy > 0 then
		table.insert(
			lines,
			("Left %d alone that a round is using (the map being played, hiders' pumpkins): the next map loads with your models by itself."):format(
				busy
			)
		)
	end
	if RunService:IsRunning() then
		table.insert(
			lines,
			"(This playtest only: stop the game and run Swap.Props() in the command bar to keep it.)"
		)
	elseif total > 0 then
		table.insert(lines, "Save the place (Ctrl+S) to keep it. Ctrl+Z undoes it.")
	end
	local message = table.concat(lines, " ")
	say(message)
	return total, message
end

-- The height of the parts you can see in `instance` (world up), or 0.
local function heightOf(instance: Instance): number
	local low, high, found = CustomAssets.VisibleBox(instance)
	return if found then high.Y - low.Y else 0
end

-- The middle of the bottom of the parts you can see in `instance` (world space).
local function feetOf(instance: Instance): Vector3?
	local low, high, found = CustomAssets.VisibleBox(instance)
	if not found then
		return nil
	end
	return Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
end

-- A ready copy of `model` (a Model, or a part wrapped in one), scripts removed, anchored.
local function freshCopy(model: Instance, name: string): Model?
	local copy = model:Clone()
	local m: Model
	if copy:IsA("Model") then
		m = copy
	elseif copy:IsA("BasePart") then
		m = Instance.new("Model")
		copy.Parent = m
		m.PrimaryPart = copy
	else
		copy:Destroy()
		return nil
	end
	m.Name = name
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") and Config.Custom.StripScripts then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m
end

-- The prop `d` is, or is a piece of (the nearest Model with a PropName attribute), or nil.
local function propOf(d: Instance): Model?
	local node: Instance? = d
	while node do
		if node:IsA("Model") and node:GetAttribute("PropName") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Is `name` the PropName of a prop in Workspace / ServerStorage.Maps (or under `root`)?
local function isPropName(name: string, root: Instance?): boolean
	for _, where in rootsOf(root) do
		for _, d in where:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") == name then
				return true
			end
		end
	end
	return false
end

--[[
	Replaces every Model or Part named `name` (in Workspace and ServerStorage.Maps, or only
	under `root`) with a copy of `model`: at the same spot (bottoms lined up) and facing, scaled
	to the old one's height (unless `model` has KeepSize = true). The copy keeps the old one's
	name, tags and attributes, and working (tagged) parts inside the old one are moved into it.
	`model` itself and anything inside it are never replaced. Props and the parts inside them
	are left alone (a jack-o'-lantern's core part is called "Pumpkin"): when `name` is a prop
	name it stops and says to use Custom.Props and Swap.Props() instead, which keeps what the
	game needs (hitboxes, lights, sizes). Returns how many it replaced and the message it
	printed.
]]
function Swap.Replace(name: string, model: Instance, root: Instance?): (number, string)
	if type(name) ~= "string" or name == "" then
		error(
			'Swap.Replace: give the name to look for, e.g. Swap.Replace("Rock", workspace.MyRock)',
			0
		)
	end
	if typeof(model) ~= "Instance" or not (model:IsA("Model") or model:IsA("BasePart")) then
		error("Swap.Replace: the second thing must be a Model or a Part, e.g. workspace.MyRock", 0)
	end
	if isPropName(name, root) then
		local message = ("%s is a prop name, so Replace leaves it alone (it would lose what the game needs, like hitboxes and lights). Instead: name your model %s, put it in ReplicatedStorage > Custom > Props and run Swap.Props(). Nothing was replaced."):format(
			name,
			name
		)
		warn("[Swap] " .. message)
		return 0, message
	end
	local count, skipped = 0, 0
	local inProps: { [string]: number } = {} -- matches that are (part of) a prop, by PropName
	undoable("Replace " .. name, function()
		for _, where in rootsOf(root) do
			-- Matches, outermost only (a Model named Rock may hold a part named Rock).
			local matches: { PVInstance } = {}
			local chosen: { [Instance]: boolean } = {}
			for _, d in where:GetDescendants() do
				if
					d.Name == name
					and (d:IsA("Model") or d:IsA("BasePart"))
					and d ~= model
					and not d:IsDescendantOf(model)
					and not model:IsDescendantOf(d)
				then
					local ancestor = d.Parent
					local inside = false
					while ancestor and ancestor ~= where do
						if chosen[ancestor] then
							inside = true
							break
						end
						ancestor = ancestor.Parent
					end
					if inside then
						continue
					end
					-- A prop, or a piece of one: left alone (swap the whole prop in Custom.Props).
					local prop = propOf(d)
					if prop then
						local propName = tostring(prop:GetAttribute("PropName"))
						inProps[propName] = (inProps[propName] or 0) + 1
						continue
					end
					chosen[d] = true
					table.insert(matches, d :: PVInstance)
				end
			end
			for _, old in matches do
				local parent = old.Parent
				if old:IsA("BasePart") and Kit.isWorking(old) then
					skipped += 1 -- a part that does something (a pad, a door...): never replaced
					continue
				end
				local copy = freshCopy(model, old.Name)
				if not parent or not copy then
					continue
				end
				local height = heightOf(old)
				if height > 0.05 then
					CustomAssets.Fit(copy, height)
				end
				-- Face the same way: a Model's pivot is its front; a Part's frame also says
				-- which way its shape lies, so only its left/right turn counts.
				local pivot = old:GetPivot()
				local turn = if old:IsA("BasePart") then CustomAssets.Yaw(pivot) else pivot.Rotation
				copy:PivotTo(CFrame.new(pivot.Position) * turn)
				local oldFeet, newFeet = feetOf(old), feetOf(copy)
				if oldFeet and newFeet then
					copy:PivotTo(copy:GetPivot() + (oldFeet - newFeet))
				end
				for _, tag in CollectionService:GetTags(old) do
					CollectionService:AddTag(copy, tag)
				end
				for key, value in old:GetAttributes() do
					if copy:GetAttribute(key) == nil then
						copy:SetAttribute(key, value)
					end
				end
				for _, part in Kit.workingParts(old) do
					part.Parent = copy -- (working parts inside it keep working)
				end
				copy.Parent = parent
				old:Destroy()
				count += 1
			end
		end
	end)
	local message = if count > 0
		then ("Replaced %d %s with a copy of %s."):format(count, name, model.Name)
		elseif skipped > 0 or next(inProps) then ("Replaced nothing named %q."):format(name)
		else ("Found nothing named %q to replace (names must match exactly, capitals too)."):format(
			name
		)
	if next(inProps) then
		message ..= (" Left alone the ones that are props or part of one (%s): to change those, put your model in ReplicatedStorage > Custom > Props named like the prop and run Swap.Props()."):format(
			summary(inProps)
		)
	end
	if skipped > 0 then
		message ..= (" Left %d part(s) named %s alone: they do something in the game (they have a tag). Swap their look with a prop in Custom.Props instead."):format(
			skipped,
			name
		)
	end
	if count > 0 then
		message ..= if RunService:IsRunning()
			then " (This playtest only: run it in edit mode to keep it.)"
			else " Save the place (Ctrl+S) to keep it. Ctrl+Z undoes it."
	end
	say(message)
	return count, message
end

-- Toolbox models -----------------------------------------------------------------------------

local CUSTOM_BACKUPS = "CustomBackups" -- ServerStorage.CustomBackups: custom models replaced

-- The asset id in a Toolbox code: a number, "12345678" or a Creator Store link.
local function assetId(code: unknown): number?
	if type(code) == "number" then
		return if code > 0 then math.floor(code) else nil
	end
	if type(code) == "string" then
		local digits = code:match("(%d%d%d%d%d+)")
		return if digits then tonumber(digits) else nil
	end
	return nil
end

--[[
	Downloads a Toolbox (Creator Store) model as one Model with every script removed (free
	models can hide bad ones). Only works in Studio (the command bar). Returns the model, or nil
	and why not.
]]
local function loadToolbox(id: number): (Model?, string?)
	local items: { Instance } = {}
	local ok, result = pcall(function()
		return (game :: any):GetObjects("rbxassetid://" .. id)
	end)
	if ok and type(result) == "table" then
		items = result
	end
	if #items == 0 then
		local loaded, container = pcall(function()
			return game:GetService("InsertService"):LoadAsset(id)
		end)
		if loaded and container then
			items = container:GetChildren()
		end
	end
	if #items == 0 then
		return nil,
			("Couldn't load Toolbox code %d. Check it is a free Model (not a decal, mesh or sound), and run this in the command bar while the game is NOT running."):format(
				id
			)
	end
	local model: Model
	if #items == 1 and items[1].ClassName == "Model" then -- (a Tool is a kind of Model too)
		model = items[1] :: Model
	else
		model = Instance.new("Model")
		for _, item in items do
			if item:IsA("Accessory") or item:IsA("Tool") then
				-- A hat or a tool (a torch) from the Toolbox: keep its parts, not the hat or tool
				-- itself (a Tool lying in the lobby could be picked up).
				for _, child in item:GetChildren() do
					child.Parent = model
				end
				item:Destroy()
			else
				item.Parent = model
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Tool") or d:IsA("Accessory") then
			-- (one inside a model: same as above)
			for _, child in d:GetChildren() do
				child.Parent = d.Parent
			end
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("TouchTransmitter")
			or (d:IsA("JointInstance") and d.Name == "AccessoryWeld")
		then
			d:Destroy()
		end
	end
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		model:Destroy()
		return nil, ("Toolbox code %d has nothing you can see in it (no parts)."):format(id)
	end
	return model, nil
end

-- (Tests swap this for a fake download.)
Swap.LoadToolbox = loadToolbox

-- ReplicatedStorage.Custom.Props (made if missing).
local function customProps(): Instance
	local custom = ReplicatedStorage:FindFirstChild("Custom")
	if not custom then
		custom = Instance.new("Folder")
		custom.Name = "Custom"
		custom.Parent = ReplicatedStorage
	end
	local props = (custom :: Instance):FindFirstChild("Props")
	if not props then
		props = Instance.new("Folder")
		props.Name = "Props"
		props.Parent = custom
	end
	return props :: Instance
end

-- Puts `model` in Custom.Props as `name`; a model already there moves to
-- ServerStorage.CustomBackups (so you can drag it back).
local function storeCustom(name: string, model: Model, id: number)
	local props = customProps()
	local existing = props:FindFirstChild(name)
	if existing then
		local backups = ServerStorage:FindFirstChild(CUSTOM_BACKUPS)
		if not backups then
			backups = Instance.new("Folder")
			backups.Name = CUSTOM_BACKUPS
			backups.Parent = ServerStorage
		end
		local older = (backups :: Instance):FindFirstChild(name)
		if older then
			older:Destroy()
		end
		existing.Parent = backups
	end
	model.Name = name
	model:SetAttribute("ToolboxId", id)
	model.Parent = props
end

--[[
	A Toolbox pack (a folder of 7 trees, 2 mushrooms...): its separate models, each as a Model,
	in order. A single model is a pack of one: { model }. Packs are spread over the copies (the
	1st copy gets the 1st model, the 2nd the 2nd...), so a forest gets every kind of tree.
]]
local function variantsOf(model: Model): { Model }
	local node: Instance = model
	while true do
		local holders: { Instance } = {}
		for _, child in node:GetChildren() do
			if child:IsA("BasePart") then
				return { model } -- loose parts: it is one thing
			elseif
				(child:IsA("Model") or child:IsA("Folder"))
				and child:FindFirstChildWhichIsA("BasePart", true)
			then
				table.insert(holders, child)
			end
		end
		if #holders == 1 then
			node = holders[1]
			continue
		end
		if #holders < 2 then
			return { model }
		end
		local list: { Model } = {}
		for _, holder in holders do
			if holder:IsA("Model") then
				holder.Parent = nil
				table.insert(list, holder)
			else
				local wrap = Instance.new("Model")
				wrap.Name = holder.Name
				for _, child in holder:GetChildren() do
					child.Parent = wrap
				end
				table.insert(list, wrap)
			end
		end
		model:Destroy()
		return list
	end
end

-- The Custom.Props names for a pack stored as `base`: base, base_2, base_3...
local function variantNames(base: string, count: number): { string }
	local names = { base }
	for k = 2, count do
		table.insert(names, ("%s_%d"):format(base, k))
	end
	return names
end

local function notCode(example: string): (number, string)
	local message = ("That isn't a Toolbox code: use the number from the model's page, e.g. %s."):format(
		example
	)
	say(message)
	return 0, message
end

--[[
	Every copy of a prop gets the look of a Toolbox model:
	  require(game.ServerScriptService.Server.Tools.Swap).Toolbox("Pumpkin", 12345678)
	  require(game.ServerScriptService.Server.Tools.Swap).Toolbox({ "Pumpkin", "ParkourPumpkin" }, 12345678)
	The code can also be the Creator Store link. It downloads the model (scripts removed), puts
	it in ReplicatedStorage.Custom.Props under each name, then runs Swap.Props(): every copy in
	the lobby and baked maps changes now, and everything built later (round maps, a rebuilt
	lobby) uses it too. Things given a look of their own (Swap.Selected) keep theirs. Run it in
	edit mode, then save (Ctrl+S).
]]
function Swap.Toolbox(names: string | { string }, code: number | string): (number, string)
	local list: { string } = if type(names) == "table" then names else { names :: string }
	local id = assetId(code)
	if not id then
		return notCode('Toolbox("Pumpkin", 12345678)')
	end
	local model, problem = Swap.LoadToolbox(id)
	if not model then
		say(problem :: string)
		return 0, problem :: string
	end
	local variants = variantsOf(model)
	undoable("Toolbox model", function()
		for _, name in list do
			for k, variantName in variantNames(name, #variants) do
				storeCustom(variantName, variants[k]:Clone(), id)
			end
		end
	end)
	for _, variant in variants do
		variant:Destroy()
	end
	say(
		("Toolbox model %d is now Custom.Props.%s%s."):format(
			id,
			table.concat(list, ", Custom.Props."),
			if #variants > 1
				then (" (a pack of %d, spread over the copies)"):format(#variants)
				else ""
		)
	)
	local total, message = Swap.Props()
	if #variants > 1 then
		-- Copy 1 keeps the first model (its PropName), copy 2 gets the second, and so on.
		undoable("Spread the Toolbox pack", function()
			for _, name in list do
				local packNames = variantNames(name, #variants)
				for _, root in rootsOf(nil) do
					local copies = Kit.findProps(root, function(m: Model): boolean
						return m:GetAttribute("PropName") == name
							and m:GetAttribute("CustomModel") == nil
							and m:GetAttribute("CustomProp") == true
							and not inUse(m)
					end)
					for i, old in copies do
						local k = (i - 1) % #variants + 1
						if k > 1 then
							swapOne(old, packNames[k])
						end
					end
				end
			end
		end)
	end
	return total, message
end

-- The prop to give a new look when you selected `thing` (itself, the one it is inside, or the
-- only one inside it), or nil and why not.
local function selectedProp(thing: Instance): (Model?, string?)
	local node: Instance? = thing
	while node and node ~= workspace do
		if node:IsA("Model") and typeof(node:GetAttribute("PropName")) == "string" then
			return node, nil
		end
		node = node.Parent
	end
	local inside = Kit.findProps(thing, function(): boolean
		return true
	end)
	if #inside == 1 then
		return inside[1], nil
	end
	if #inside > 1 then
		local names = {}
		for _, m in inside do
			table.insert(names, m:GetAttribute("PropName") :: string)
		end
		return nil,
			("%s has several things in it (%s): Alt+click the one you want and run it again."):format(
				thing.Name,
				table.concat(names, ", ")
			)
	end
	return nil,
		("%s can't change its look this way (it isn't a prop). Swap.Replace can replace hand-placed things by name."):format(
			thing.Name
		)
end

--[[
	Only the thing(s) you selected in Studio get the look of a Toolbox model; every other copy
	stays as it is:
	  require(game.ServerScriptService.Server.Tools.Swap).Selected(12345678)
	Click one thing (or several with Ctrl+click), then run it in the command bar. The model is
	kept in Custom.Props as "<name>_<code>" (e.g. Pumpkin_12345678) and the thing remembers it
	(attribute CustomModel), so Swap.Toolbox and Swap.Props never change it back. Ctrl+Z undoes
	it. To give it the normal look again: delete that model from Custom.Props and run
	Swap.Props({ Revert = true }).
	`things` (optional) is a list to use instead of the Studio selection.
]]
function Swap.Selected(code: number | string, things: { Instance }?): (number, string)
	local id = assetId(code)
	if not id then
		return notCode("Selected(12345678)")
	end
	local selected: { Instance } = things or {}
	if not things then
		pcall(function()
			selected = game:GetService("Selection"):Get()
		end)
	end
	if #selected == 0 then
		local message = "Nothing is selected: click the thing you want to change in Studio first."
		say(message)
		return 0, message
	end
	local targets: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local lines: { string } = {}
	for _, thing in selected do
		local prop, why = selectedProp(thing)
		if prop and not seen[prop] then
			seen[prop] = true
			table.insert(targets, prop)
		elseif why then
			table.insert(lines, why)
		end
	end
	local changed = 0
	if #targets > 0 then
		local model, problem = Swap.LoadToolbox(id)
		if not model then
			say(problem :: string)
			return 0, problem :: string
		end
		local variants = variantsOf(model)
		local news: { Instance } = {}
		local used: { [string]: number } = {} -- how many of each prop name so far (packs take turns)
		undoable("Toolbox look for the selection", function()
			local stored: { [string]: boolean } = {}
			for _, prop in targets do
				local propName = prop:GetAttribute("PropName") :: string
				local names = variantNames(("%s_%d"):format(propName, id), #variants)
				local k = (used[propName] or 0) % #variants + 1
				used[propName] = (used[propName] or 0) + 1
				local custom = names[k]
				if not stored[custom] then
					stored[custom] = true
					storeCustom(custom, variants[k]:Clone(), id)
				end
				local new = swapOne(prop, custom)
				if new then
					changed += 1
					table.insert(news, new)
				end
			end
		end)
		for _, variant in variants do
			variant:Destroy()
		end
		if not things then
			pcall(function()
				game:GetService("Selection"):Set(news)
			end)
		end
		table.insert(
			lines,
			1,
			("Gave %d selected thing(s) the look of Toolbox model %d; every other copy is unchanged."):format(
				changed,
				id
			)
		)
		table.insert(
			lines,
			if RunService:IsRunning()
				then "(This playtest only: stop the game and run it in the command bar to keep it.)"
				else "Save the place (Ctrl+S) to keep it. Ctrl+Z undoes it."
		)
	end
	local message = table.concat(lines, " ")
	say(message)
	return changed, message
end

--[[
	One secret pumpkin (Easter egg) gets the look of a Toolbox model:
	  require(game.ServerScriptService.Server.Tools.Swap).Egg("ForestGhost", 15145049241)
	The first word is the egg's Id (Config.EasterEggs.List, or the EggId attribute on its Egg
	part). The model is kept as Custom.Props.Egg<Id> (only that egg; Egg<Look>, e.g. EggGhost,
	changes every egg with that look) and the egg in Workspace.Hub is rebuilt in its spot.
]]
function Swap.Egg(eggId: string, code: number | string): (number, string)
	local id = assetId(code)
	if not id then
		return notCode('Egg("ForestGhost", 12345678)')
	end
	local known = false
	for _, egg in Config.EasterEggs.List do
		if egg.Id == eggId then
			known = true
		end
	end
	if not known then
		local message = ("There is no egg with the Id %q (see Config.EasterEggs.List)."):format(
			tostring(eggId)
		)
		say(message)
		return 0, message
	end
	local model, problem = Swap.LoadToolbox(id)
	if not model then
		say(problem :: string)
		return 0, problem :: string
	end
	local hub = workspace:FindFirstChild("Hub")
	local rebuilt = 0
	undoable("Toolbox look for an egg", function()
		storeCustom("Egg" .. eggId, model, id)
		if not hub then
			return
		end
		for _, part in CollectionService:GetTagged(Tags.EasterEgg) do
			if part:IsDescendantOf(hub) and part:GetAttribute("EggId") == eggId then
				-- The whole egg: the outermost Model it is in below the EasterEggs group (a Toolbox
				-- look may nest it; in an older saved hub the group and the hub are Models too).
				local holder: Instance = part
				while
					holder.Parent
					and holder.Parent:IsA("Model")
					and holder.Parent ~= hub
					and holder.Parent.Name ~= "EasterEggs"
				do
					holder = holder.Parent
				end
				holder:Destroy()
			end
		end
		local EggSection = (require :: any)(script.Parent.Parent.Hub.Sections.EasterEggs)
		for _, placed in EggSection.PlaceMissing(hub) do
			if placed == eggId then
				rebuilt += 1
			end
		end
	end)
	local message = ("The egg %s now looks like Toolbox model %d (Custom.Props.Egg%s)%s."):format(
		eggId,
		id,
		eggId,
		if rebuilt > 0 then " and was rebuilt in the lobby" else ""
	) .. (if RunService:IsRunning()
		then " (This playtest only: stop the game and run it in the command bar to keep it.)"
		else " Save the place (Ctrl+S) to keep it. Ctrl+Z undoes it.")
	say(message)
	return rebuilt, message
end

-- A copy of your own model to use as a look: always one Model, with scripts, tools and hats
-- taken out like a Toolbox download. nil and why when it has nothing to see.
local function ownCopy(look: Instance): (Model?, string?)
	local model: Model
	if look:IsA("Model") then
		model = look:Clone()
	elseif look:IsA("BasePart") or look:IsA("Folder") then
		model = Instance.new("Model")
		model.Name = look.Name
		look:Clone().Parent = model
	else
		return nil, ("%s isn't a model or a part."):format(look.Name)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("TouchTransmitter") then
			d:Destroy()
		end
	end
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		model:Destroy()
		return nil, ("%s has nothing you can see in it (no parts)."):format(look.Name)
	end
	return model, nil
end

-- A Toolbox code, or your own model/part: the look as one clean Model (nil and why if not).
local function lookOf(look: number | string | Instance): (Model?, string?, number)
	if typeof(look) == "Instance" then
		local model, problem = ownCopy(look)
		return model, problem, 0
	end
	local id = assetId(look)
	if not id then
		return nil, "That isn't a Toolbox code: use the number from the model's page.", 0
	end
	local model, problem = Swap.LoadToolbox(id)
	return model, problem, id
end

--[[
	Your own model as the look of every copy of a prop (it goes in Custom.Props under that
	name, then Swap.Props() runs):
	  require(game.ServerScriptService.Server.Tools.Swap).UseModel("Pumpkin", workspace.MyPumpkin)
	Build or edit the model anywhere in Workspace first; your original stays where it is.
]]
function Swap.UseModel(name: string, look: Instance): (number, string)
	local model, problem = ownCopy(look)
	if not model then
		say(problem :: string)
		return 0, problem :: string
	end
	undoable("Own model for " .. name, function()
		storeCustom(name, model :: Model, 0)
	end)
	say(("%s is now Custom.Props.%s."):format(look.Name, name))
	return Swap.Props()
end

--[[
	Only the selected thing(s) get the look of your own model (like Swap.Selected with a Toolbox
	code): Swap.SelectedModel(workspace.MyPumpkin)
]]
function Swap.SelectedModel(look: Instance, things: { Instance }?): (number, string)
	local selected: { Instance } = things or {}
	if not things then
		pcall(function()
			selected = game:GetService("Selection"):Get()
		end)
	end
	local targets: { Model } = {}
	local lines: { string } = {}
	for _, thing in selected do
		if thing ~= look and not thing:IsDescendantOf(look) then
			local prop, why = selectedProp(thing)
			if prop and not table.find(targets, prop) then
				table.insert(targets, prop)
			elseif why then
				table.insert(lines, why)
			end
		end
	end
	if #targets == 0 then
		local message = if #lines > 0
			then table.concat(lines, " ")
			else "Nothing is selected: click the thing you want to change in Studio first."
		say(message)
		return 0, message
	end
	local model, problem = ownCopy(look)
	if not model then
		say(problem :: string)
		return 0, problem :: string
	end
	local changed = 0
	undoable("Own model for the selection", function()
		local stored: { [string]: boolean } = {}
		for _, prop in targets do
			local custom = ("%s_%s"):format(prop:GetAttribute("PropName") :: string, look.Name)
			if not stored[custom] then
				stored[custom] = true
				storeCustom(custom, (model :: Model):Clone(), 0)
			end
			if swapOne(prop, custom) then
				changed += 1
			end
		end
	end)
	model:Destroy()
	local message = ("Gave %d selected thing(s) the look of %s; every other copy is unchanged. Save the place (Ctrl+S) to keep it."):format(
		changed,
		look.Name
	)
	say(message)
	return changed, message
end

-- ReplicatedStorage.Custom.Characters (made if missing).
local function customCharacters(): Instance
	local custom = customProps().Parent :: Instance
	local characters = custom:FindFirstChild("Characters")
	if not characters then
		characters = Instance.new("Folder")
		characters.Name = "Characters"
		characters.Parent = custom
	end
	return characters :: Instance
end

--[[
	A character's look (the King, skeletons, bats, ghost cats, the shopkeeper: the names in
	Config.Custom.Heights) from a Toolbox code or your own model:
	  require(game.ServerScriptService.Server.Tools.Swap).Character("Bat", 12345678)
	  require(game.ServerScriptService.Server.Tools.Swap).Character("SkeletonPatrol", workspace.MySkeleton)
	It goes in Custom.Characters under that name (the old one moves to
	ServerStorage.CustomBackups). The game uses it from the next round (the shopkeeper: the
	next time the game starts). Delete it from Custom.Characters to get the built look back.
]]
function Swap.Character(name: string, look: number | string | Instance): (number, string)
	if not Config.Custom.Heights[name] then
		local names = {}
		for known in Config.Custom.Heights do
			table.insert(names, known)
		end
		table.sort(names)
		local message = ("%s isn't a character. Use one of: %s."):format(
			name,
			table.concat(names, ", ")
		)
		say(message)
		return 0, message
	end
	local model, problem, id = lookOf(look)
	if not model then
		say(problem :: string)
		return 0, problem :: string
	end
	undoable("Look for " .. name, function()
		local characters = customCharacters()
		local existing = characters:FindFirstChild(name)
		if existing then
			local backups = ServerStorage:FindFirstChild(CUSTOM_BACKUPS)
			if not backups then
				backups = Instance.new("Folder")
				backups.Name = CUSTOM_BACKUPS
				backups.Parent = ServerStorage
			end
			local older = (backups :: Instance):FindFirstChild(name)
			if older then
				older:Destroy()
			end
			existing.Parent = backups
		end
		local m = model :: Model
		m.Name = name
		if id > 0 then
			m:SetAttribute("ToolboxId", id)
		end
		m.Parent = characters
	end)
	local message = ("Custom.Characters.%s is your new look: press Play and it shows from the next round. Save the place (Ctrl+S) to keep it."):format(
		name
	)
	say(message)
	return 1, message
end

return Swap
