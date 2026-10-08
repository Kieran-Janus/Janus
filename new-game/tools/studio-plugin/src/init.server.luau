--!strict
--[[
	PUMPKIN TOOLS: a Studio plugin for Pumpkin Panic (Plugins tab > Pumpkin Tools).

	  Looks   click anything in the game view, paste a Toolbox code: only that one, or every
	          copy of it, gets that look. Or use your own model (build or insert it, select it,
	          "Remember as my look"), for one thing, every copy, or a character in the rounds
	          (the King, skeletons, bats, ghost cats, the shopkeeper, the pumpkins you collect
	          or hide as). Uses src/server/Tools/Swap.luau, so Ctrl+Z undoes it.
	  Words   click a sign and type new words: for that sign only, or everywhere those words
	          show. In a playtest, "Pick text" then click any words on the screen; those
	          changes are kept for when you stop the game. Stored in the place's
	          ReplicatedStorage.TextOverrides (src/client/TextOverrides.luau shows them).

	Save the place (Ctrl+S) afterwards to keep your changes.
	Install: rojo build tools/studio-plugin --plugin PumpkinTools.rbxm (then restart Studio, or
	Plugins > Manage Plugins). Source: tools/studio-plugin/ in the game's repo.
]]
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerScriptService = game:GetService("ServerScriptService")

local Texts = require(script.Texts)
local Ui = require(script.Ui)

local playing = RunService:IsRunning()
local isClient = RunService:IsClient() and playing
-- In a playtest only the client view (the one you see) shows the panel's word tools.
if playing and not isClient then
	return
end

local toolbar = plugin:CreateToolbar("Pumpkin Tools")
local button = toolbar:CreateButton(
	"PumpkinTools",
	"Change looks and words: click a thing, paste a Toolbox code or type new words",
	"", -- (no icon: the button shows its name)
	"Pumpkin Tools"
)
button.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"PumpkinTools" .. (if isClient then "Play" else ""),
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 600, 280, 320)
)
widget.Title = "Pumpkin Tools"
widget.Name = "PumpkinTools"
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
end)

local page = Ui.Page(widget)

-- Status line at the top: what the last button did.
local status = Ui.Label(page, "Click something in the game view to start.", 13)
status.TextColor3 = Ui.Colors.Good

local function say(text: string, bad: boolean?)
	status.Text = text
	status.TextColor3 = if bad then Ui.Colors.Bad else Ui.Colors.Good
end

-- The game's Swap tool (edit mode only).
local function swap(): any
	local tools = ServerScriptService:FindFirstChild("Server")
	local module = tools and tools:FindFirstChild("Tools") and tools.Tools:FindFirstChild("Swap")
	if not module or not module:IsA("ModuleScript") then
		say(
			"Couldn't find ServerScriptService.Server.Tools.Swap: is this the Pumpkin Panic place?",
			true
		)
		return nil
	end
	return (require :: any)(module)
end

local function run(label: string, fn: (any) -> (number, string))
	if playing then
		say("Stop the game first (looks are changed in edit mode).", true)
		return
	end
	local Swap = swap()
	if not Swap then
		return
	end
	local ok, n, message = pcall(fn, Swap)
	if not ok then
		say(label .. " failed: " .. tostring(n), true)
	else
		say(message or ("Done (" .. tostring(n) .. ")."), (n or 0) == 0)
	end
end

-- What is selected, in plain words, and the prop name every copy shares (if any).
local function selectedInfo(): (string, string?)
	local selected = Selection:Get()
	if #selected == 0 then
		return "Nothing selected: click something in the game view.", nil
	end
	local first = selected[1]
	local node: Instance? = first
	while node and node ~= workspace do
		local prop = node:GetAttribute("PropName")
		if node:IsA("Model") and type(prop) == "string" then
			local extra = if #selected > 1 then (" (+%d more)"):format(#selected - 1) else ""
			return ("Selected: <b>%s</b>%s. Every copy is called <b>%s</b>."):format(
				node.Name,
				extra,
				prop
			),
				prop
		end
		node = node.Parent
	end
	return ("Selected: <b>%s</b> (%s)"):format(first.Name, first.ClassName), nil
end

----------------------------------------------------------------------------------------
-- Looks
----------------------------------------------------------------------------------------
local myLook: Instance? = nil
local everyButton: TextButton
local selectedLabel: TextLabel
local myLookLabel: TextLabel

if not playing then
	local looks = Ui.Section(page, "Looks: a Toolbox model")
	selectedLabel = Ui.Label(looks, "")
	local code = Ui.Input(looks, "Toolbox code or link (e.g. 11600489662)")
	Ui.Hint(
		looks,
		"In the Toolbox, right-click a model > Copy Asset ID, then paste it here. Click the thing to change in the game view first."
	)
	Ui.Button(looks, "Only the selected one(s)", function()
		run("Toolbox look", function(Swap)
			return Swap.Selected(code.Text)
		end)
	end)
	everyButton = Ui.Button(looks, "Every copy", function()
		local _, prop = selectedInfo()
		if not prop then
			say("That one has no copies to change: try Only the selected one(s).", true)
			return
		end
		run("Toolbox look", function(Swap)
			return Swap.Toolbox(prop, code.Text)
		end)
	end)

	local own = Ui.Section(page, "Looks: your own model (make your own skin)")
	Ui.Hint(
		own,
		"Build a model (or insert and edit one), select it and press Remember. Then click what it should replace."
	)
	myLookLabel = Ui.Label(own, "Your look: none yet")
	Ui.Button(own, "Remember the selected model as my look", function()
		local selected = Selection:Get()
		local pick = selected[1]
		if pick and (pick:IsA("Model") or pick:IsA("BasePart")) then
			myLook = pick
			myLookLabel.Text = ("Your look: <b>%s</b>"):format(pick.Name)
			say("Remembered " .. pick.Name .. ". Now click what it should replace.")
		else
			say("Select a model or a part first.", true)
		end
	end, true)
	Ui.Button(own, "Give the selected one(s) my look", function()
		local look = myLook
		if not look or not look.Parent then
			say("Remember a model first.", true)
			return
		end
		run("Own look", function(Swap)
			return Swap.SelectedModel(look)
		end)
	end)
	Ui.Button(own, "Give every copy my look", function()
		local look = myLook
		local _, prop = selectedInfo()
		if not look or not look.Parent then
			say("Remember a model first.", true)
			return
		end
		if not prop then
			say("Click one of the things to change first.", true)
			return
		end
		run("Own look", function(Swap)
			return Swap.UseModel(prop, look)
		end)
	end)

	-- The characters and pickups of the rounds (not in the lobby to click on).
	local rounds = Ui.Section(page, "Looks: things in the rounds")
	Ui.Hint(
		rounds,
		"Uses the Toolbox code above, or your remembered look. Shows from the next round."
	)
	local things = {
		{ Name = "PumpkinKing", Label = "The Pumpkin King", Character = true },
		{ Name = "SkeletonPatrol", Label = "Skeletons", Character = true },
		{ Name = "Bat", Label = "Bats", Character = true },
		{ Name = "GhostCat", Label = "Ghost cats", Character = true },
		{ Name = "PumpkinVendor", Label = "The shopkeeper", Character = true },
		{ Name = "CollectPumpkin", Label = "King Hunt pumpkins", Character = false },
		{ Name = "HidingPumpkin", Label = "Hide & Seek pumpkins", Character = false },
		{ Name = "KingStatue", Label = "The King statue", Character = false },
	}
	for _, thing in things do
		local row = Ui.Row(rounds, 26)
		local name = Ui.Label(row, thing.Label, 12)
		name.AutomaticSize = Enum.AutomaticSize.None
		Ui.Button(row, "Toolbox code", function()
			run(thing.Label, function(Swap)
				if thing.Character then
					return Swap.Character(thing.Name, code.Text)
				end
				return Swap.Toolbox(thing.Name, code.Text)
			end)
		end)
		Ui.Button(row, "My look", function()
			local look = myLook
			if not look or not look.Parent then
				say("Remember a model first (Looks: your own model).", true)
				return
			end
			run(thing.Label, function(Swap)
				if thing.Character then
					return Swap.Character(thing.Name, look)
				end
				return Swap.UseModel(thing.Name, look)
			end)
		end, true)
		Ui.Share(row, { 1.3, 1, 0.8 })
	end
end

----------------------------------------------------------------------------------------
-- Words
----------------------------------------------------------------------------------------
local words = Ui.Section(page, "Words")
Ui.Hint(
	words,
	if playing
		then "Press Pick text, then click any words on the screen or a sign. Changes are kept for when you stop the game."
		else "Click a sign in the game view to change its words. For words on screens: press Play, then Pick text here."
)
local picked = Ui.Holder(words)
local pickButton: TextButton
local picking = false

-- In a playtest, changes are kept in plugin settings and added to the place by the
-- edit-mode plugin when the game stops.
local PENDING = "PendingTextChanges"

local function record(name: string, change: () -> ())
	local id: string? = nil
	if not playing then
		id = ChangeHistoryService:TryBeginRecording(name)
	end
	change()
	if id then
		ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
	end
end

local refreshChanges: () -> ()

local function saveEverywhere(from: string, to: string)
	record("Change words", function()
		Texts.Set(from, to)
	end)
	if playing then
		local pending = plugin:GetSetting(PENDING)
		local list = if type(pending) == "table" then pending else {}
		table.insert(list, { From = from, To = to })
		plugin:SetSetting(PENDING, list)
		say(('Everywhere: "%s" -> "%s" (kept for when you stop the game).'):format(from, to))
	else
		say(('Everywhere: "%s" -> "%s". Save the place (Ctrl+S).'):format(from, to))
	end
	refreshChanges()
end

local function showTexts(labels: { TextLabel })
	Ui.Clear(picked)
	if #labels == 0 then
		Ui.Hint(picked, "No words in what you clicked.")
		return
	end
	-- The same words twice (both faces of a sign board) show once and change together.
	local groups: { { Text: string, Labels: { TextLabel } } } = {}
	local byText: { [string]: { Text: string, Labels: { TextLabel } } } = {}
	for _, label in labels do
		local group = byText[label.Text]
		if not group then
			group = { Text = label.Text, Labels = {} }
			byText[label.Text] = group
			table.insert(groups, group)
		end
		table.insert(group.Labels, label)
	end
	for _, group in groups do
		local original = group.Text
		local label = group.Labels[1]
		Ui.Hint(
			picked,
			Texts.Where(label)
				.. (if #group.Labels > 1 then (" (x%d)"):format(#group.Labels) else "")
		)
		local box = Ui.Input(picked, "New words", true)
		box.Text = original
		local row = Ui.Row(picked, 26)
		Ui.Button(row, "Only here", function()
			if playing then
				say("In a playtest, use Everywhere (only-here changes need edit mode).", true)
				return
			end
			record("Change sign words", function()
				for _, each in group.Labels do
					each.Text = box.Text
				end
			end)
			say("Changed this one. Save the place (Ctrl+S).")
		end, true)
		Ui.Button(row, "Everywhere", function()
			if box.Text == original then
				say("Type the new words first.", true)
				return
			end
			if not playing then
				record("Change sign words", function()
					for _, each in group.Labels do
						each.Text = box.Text
					end
				end)
			end
			saveEverywhere(original, box.Text)
		end)
		Ui.Share(row, { 1, 1 })
	end
end

if isClient then
	local mouse = plugin:GetMouse()
	pickButton = Ui.Button(words, "Pick text", function()
		picking = not picking
		if picking then
			plugin:Activate(true)
			pickButton.Text = "Picking... click any words (press again to stop)"
		else
			plugin:Deactivate()
			pickButton.Text = "Pick text"
		end
	end)
	plugin.Deactivation:Connect(function()
		picking = false
		pickButton.Text = "Pick text"
	end)
	mouse.Button1Down:Connect(function()
		if not picking then
			return
		end
		local found: { TextLabel } = {}
		local playerGui = Players.LocalPlayer
			and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			local inset = GuiService:GetGuiInset()
			for _, y in { mouse.Y, mouse.Y - inset.Y } do
				for _, gui in playerGui:GetGuiObjectsAtPosition(mouse.X, y) do
					if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text ~= "" then
						table.insert(found, gui :: TextLabel)
						break
					end
				end
				if #found > 0 then
					break
				end
			end
		end
		if #found == 0 and mouse.Target then
			found = Texts.InThing(mouse.Target, 6)
		end
		showTexts(found)
	end)
end

-- Any words, typed in.
Ui.Label(words, "<b>Change any words</b> (exactly as the game shows them):")
local fromBox = Ui.Input(words, "The game's words, e.g. Stand here to play!")
local toBox = Ui.Input(words, "Your words, e.g. Step in to play!")
Ui.Button(words, "Change everywhere", function()
	if fromBox.Text == "" or fromBox.Text == toBox.Text then
		say("Type the game's words and your new words.", true)
		return
	end
	saveEverywhere(fromBox.Text, toBox.Text)
	fromBox.Text = ""
	toBox.Text = ""
end)

Ui.Label(words, "<b>Your word changes</b>")
local changesHolder = Ui.Holder(words)
refreshChanges = function()
	Ui.Clear(changesHolder)
	local list = Texts.List()
	if #list == 0 then
		Ui.Hint(changesHolder, "None yet.")
		return
	end
	for _, change in list do
		local row = Ui.Row(changesHolder, 26)
		local text = Ui.Label(row, ('"%s" -> "%s"'):format(change.From, change.To), 12)
		text.AutomaticSize = Enum.AutomaticSize.None
		text.TextTruncate = Enum.TextTruncate.AtEnd
		Ui.Button(row, "Undo", function()
			if playing then
				say("Stop the game to remove a change.", true)
				return
			end
			record("Remove word change", function()
				change.Value:Destroy()
			end)
			say(
				('"%s" shows the game\'s words again. Save the place (Ctrl+S).'):format(change.From)
			)
			refreshChanges()
		end, true)
		Ui.Share(row, { 3, 1 })
	end
end
refreshChanges()

----------------------------------------------------------------------------------------
-- Following the selection (edit mode) and bringing playtest word changes in
----------------------------------------------------------------------------------------
local function onSelection()
	if playing then
		return
	end
	local text, prop = selectedInfo()
	selectedLabel.Text = text
	everyButton.Text = if prop then "Every " .. prop else "Every copy"
	local selected = Selection:Get()
	if #selected > 0 then
		showTexts(Texts.InThing(selected[1], 6))
	else
		Ui.Clear(picked)
	end
end

if not playing then
	Selection.SelectionChanged:Connect(onSelection)
	onSelection()
	-- Word changes made in a playtest arrive here once the game stops.
	task.spawn(function()
		while true do
			task.wait(2)
			local pending = plugin:GetSetting(PENDING)
			if type(pending) == "table" and #pending > 0 then
				plugin:SetSetting(PENDING, {})
				record("Word changes from the playtest", function()
					for _, change in pending do
						if
							type(change) == "table"
							and type(change.From) == "string"
							and type(change.To) == "string"
						then
							Texts.Set(change.From, change.To)
						end
					end
				end)
				say(
					("Added %d word change(s) from your playtest. Save the place (Ctrl+S)."):format(
						#pending
					)
				)
				refreshChanges()
			end
		end
	end)
end
