--!strict
--[[
	BAKE: turn the code-built lobby and maps into real parts in your place, so you can edit
	them by hand in Studio. Run these in Studio's command bar (View > Command Bar) while the
	game is NOT running (edit mode), then save the place (Ctrl+S):

	  require(game.ServerScriptService.Server.Tools.Bake).Hub()
	      Builds the lobby into Workspace.Hub (replacing the old one) with the current
	      BuildVersion, unlocked. A Locked hub is left alone; Hub(true) replaces it anyway
	      (the old one is kept as ServerStorage.HubBackup).
	  require(game.ServerScriptService.Server.Tools.Bake).Lock()
	      Sets Locked = true on Workspace.Hub: from now on the game never rebuilds it, even when
	      the code's BuildVersion goes up. Do this once you start editing the hub by hand.
	      Unlock() undoes it.
	  require(game.ServerScriptService.Server.Tools.Bake).Repair()
	      Puts back a missing spawn, Ready pad or shopkeeper and removes retired NPCs.
	  require(game.ServerScriptService.Server.Tools.Bake).Repaint()
	      Paints every part with a PaletteRole from Config.Hub.Palette.
	  require(game.ServerScriptService.Server.Tools.Bake).Map("PumpkinPatch")
	      Builds that round map into ServerStorage.Maps.PumpkinPatch. The game then loads
	      that copy instead of building the map from code, so your edits show up in rounds.
	      To edit it: drag it into Workspace (it sits far from the lobby; select it and
	      press F to fly there), edit, then drag it back into ServerStorage > Maps.
	      An older copy is kept as PumpkinPatch_Backup. AllMaps() bakes every map.

	Every function returns what it made and prints what it did. Ctrl+Z undoes it.
	Step by step: docs/CUSTOMIZE.md > "Editing the lobby and maps by hand".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Server = script.Parent.Parent
local HubBuilder = require(Server.Hub.HubBuilder)
local HubPalette = require(Server.Hub.HubPalette)

local Bake = {}

local function say(text: string)
	print("[Bake] " .. text)
end

-- An undo point in Studio (only works from the command bar or a plugin; ignored otherwise).
local function waypoint(name: string)
	pcall(function()
		(game:GetService("ChangeHistoryService") :: any):SetWaypoint(name)
	end)
end

local function playtestNote()
	if RunService:IsRunning() then
		say(
			"The game is running, so this only changes this playtest. Stop the game and run it again in edit mode to keep it."
		)
	end
end

local function currentHub(): Instance?
	local hub = workspace:FindFirstChild("Hub")
	return if hub and (hub:IsA("Folder") or hub:IsA("Model")) then hub else nil
end

local function hubService(): any
	return (require :: any)(Server.Services.HubService)
end

function Bake.Hub(force: boolean?): Instance?
	playtestNote()
	local old = currentHub()
	if old and old:GetAttribute("Locked") == true then
		if not force then
			say(
				"Workspace.Hub is Locked (you edited it by hand), so it was NOT replaced. To replace it anyway run Bake.Hub(true): your old hub is kept as ServerStorage.HubBackup."
			)
			return nil
		end
		local previous = ServerStorage:FindFirstChild("HubBackup")
		if previous then
			previous:Destroy()
		end
		old.Name = "HubBackup"
		old.Parent = ServerStorage
	end
	waypoint("Before baking the hub")
	local hub = HubBuilder.Build()
	hubService().EnsureRequired(hub)
	waypoint("Baked the hub")
	say(
		("Built Workspace.Hub (BuildVersion %d, not Locked). Save the place to keep it. Once you edit it by hand, run Bake.Lock()."):format(
			Config.Hub.BuildVersion
		)
	)
	return hub
end

function Bake.Lock(): Instance?
	local hub = currentHub()
	if not hub then
		say("There is no Workspace.Hub to lock. Run Bake.Hub() first.")
		return nil
	end
	hub:SetAttribute("Locked", true)
	say("Workspace.Hub is now Locked: the game will never rebuild it. Save the place.")
	return hub
end

function Bake.Unlock(): Instance?
	local hub = currentHub()
	if not hub then
		say("There is no Workspace.Hub.")
		return nil
	end
	hub:SetAttribute("Locked", nil)
	say(
		"Workspace.Hub is unlocked: it is rebuilt from code whenever Config.Hub.BuildVersion goes up. Save the place."
	)
	return hub
end

function Bake.Repair(): { string }
	playtestNote()
	local hub = currentHub()
	if not hub then
		say("There is no Workspace.Hub. Run Bake.Hub() to build one.")
		return {}
	end
	waypoint("Before repairing the hub")
	local service = hubService()
	local retired = service.RemoveRetired(hub)
	local added = service.EnsureRequired(hub)
	waypoint("Repaired the hub")
	if #added == 0 and retired == 0 then
		say("Nothing to repair: the spawn, Ready pad and shopkeeper are all there.")
	else
		say(
			("Removed %d retired NPC(s); added: %s. Save the place."):format(
				retired,
				if #added > 0 then table.concat(added, ", ") else "nothing"
			)
		)
	end
	return added
end

function Bake.Repaint(): number
	playtestNote()
	local hub = currentHub()
	if not hub then
		say("There is no Workspace.Hub.")
		return 0
	end
	waypoint("Before repainting the hub")
	local changed = HubPalette.Repaint(hub)
	HubPalette.Stamp(hub)
	waypoint("Repainted the hub")
	say(("Repainted %d part(s) from Config.Hub.Palette. Save the place."):format(changed))
	return changed
end

local function mapsFolder(): Instance
	local folder = ServerStorage:FindFirstChild("Maps")
	if folder then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "Maps"
	created.Parent = ServerStorage
	return created
end

function Bake.Map(id: string): Model?
	playtestNote()
	local def
	for _, entry in Config.Maps.List do
		if entry.Id == id then
			def = entry
		end
	end
	if not def then
		local ids = {}
		for _, entry in Config.Maps.List do
			table.insert(ids, entry.Id)
		end
		say(("There is no map %q. Maps: %s"):format(tostring(id), table.concat(ids, ", ")))
		return nil
	end
	local builder = Server.Maps:FindFirstChild(def.Builder or "")
	if not (builder and builder:IsA("ModuleScript")) then
		say(("%s has no builder (src/server/Maps/%s.luau)."):format(id, tostring(def.Builder)))
		return nil
	end
	waypoint("Before baking map " .. id)
	local model: Model = (require :: any)(builder).Build(def)
	model.Name = id
	-- MapService moves a stored map so its pivot is at Config.Maps.Origin: put the pivot there
	-- (the middle of the floor), so the baked map loads exactly where the built one would.
	if model.PrimaryPart then
		model.PrimaryPart = nil
	end
	model.WorldPivot = CFrame.new(Config.Maps.Origin)
	model:SetAttribute("BakedFrom", def.Builder)

	local folder = mapsFolder()
	local existing = folder:FindFirstChild(id)
	if existing then
		local backupName = id .. "_Backup"
		local oldBackup = folder:FindFirstChild(backupName)
		if oldBackup then
			oldBackup:Destroy()
		end
		existing.Name = backupName
		say(("Your previous %s is kept as ServerStorage.Maps.%s."):format(id, backupName))
	end
	model.Parent = folder
	waypoint("Baked map " .. id)
	say(
		("Built ServerStorage.Maps.%s: rounds on this map now use it. Save the place to keep it."):format(
			id
		)
	)
	return model
end

function Bake.AllMaps(): number
	local count = 0
	for _, def in Config.Maps.List do
		if Bake.Map(def.Id) then
			count += 1
		end
	end
	return count
end

return Bake
