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

	Each one prints what it did and returns how many it changed (and that message).
	Step by step: docs/CUSTOMIZE.md > "Swap every copy of something at once".
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
						and not CustomAssets.Has("Props", m:GetAttribute("PropName") :: string)
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
				if not CustomAssets.Has("Props", m:GetAttribute("PropName") :: string) then
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
				local new = Kit.swapProp(old)
				if not new then
					continue
				end
				-- Keep the built look as a backup (Revert); a custom one is just replaced.
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

return Swap
