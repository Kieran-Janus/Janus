--!strict
--[[
	SkinStudioState: the skin you are editing in Skin Studio, with Undo, Redo and Reset. No UI
	and no remotes, so tests can drive it directly. src/client/SkinStudioUI.luau keeps these in
	module variables, so closing the panel never loses your work or your Undo history.

	State.new(item, source?) -> State        source = the catalogue Id this edits (nil = a new skin)
	state:Get() -> item                       a deep copy of the skin now
	state:Peek() -> item                      the skin now, NOT a copy (read it, don't change it)
	state:Set(path, value)                    one Undo step (value nil = clear the key),
	                                          e.g. state:Set({ "Style", "Glow", "Brightness" }, 2)
	state:Replace(item)                       the whole skin at once (one Undo step)
	state:Begin() / state:Commit()            group many Sets (a slider drag) into one step
	state:Undo() / state:Redo() / state:CanUndo() / state:CanRedo()
	state:Reset()                             back to how it was when opened (can be undone)
	state:Dirty() -> boolean                  changed since it was opened or last saved
	state:MarkSaved()                         after a Save: what's there now counts as saved
	state.Changed:Connect(fn)                 fn(reason) after every change ("Set", "Undo"...)
	Fields the panel keeps with it: state.Source, state.DraftId, state.UnlockEconomy, state.Note.
	History is capped at Config.SkinStudio.UndoSteps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SkinSchema = require(ReplicatedStorage.Shared.SkinSchema)

local SkinStudioState = {}
SkinStudioState.__index = SkinStudioState

export type Signal = {
	Connect: (self: Signal, fn: (string) -> ()) -> { Disconnect: () -> () },
	Fire: (self: Signal, reason: string) -> (),
}

-- A tiny signal: each listener runs in its own thread, so one that errors can't stop a change.
local function newSignal(): Signal
	local listeners: { (string) -> () } = {}
	local signal = {}
	function signal.Connect(_self: any, fn: (string) -> ())
		table.insert(listeners, fn)
		return {
			Disconnect = function()
				local index = table.find(listeners, fn)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
	end
	function signal.Fire(_self: any, reason: string)
		for _, fn in table.clone(listeners) do
			task.spawn(fn, reason)
		end
	end
	return signal :: any
end

export type State = typeof(setmetatable(
	{} :: {
		Item: any,
		Original: any,
		Saved: any,
		History: { any },
		Future: { any },
		Grouped: any?, -- the skin before Begin(), while a group is open
		Changed: Signal,
		Source: string?,
		DraftId: string?,
		UnlockEconomy: boolean,
		Note: string?,
	},
	SkinStudioState
))

function SkinStudioState.new(item: any, source: string?): State
	local self = setmetatable({
		Item = SkinSchema.Copy(item),
		Original = SkinSchema.Copy(item),
		Saved = SkinSchema.Copy(item),
		History = {},
		Future = {},
		Grouped = nil,
		Changed = newSignal(),
		Source = source,
		DraftId = nil,
		UnlockEconomy = false,
		Note = nil,
	}, SkinStudioState)
	return self
end

local function push(self: State, before: any)
	table.insert(self.History, before)
	local limit = math.max(1, Config.SkinStudio.UndoSteps)
	while #self.History > limit do
		table.remove(self.History, 1)
	end
	table.clear(self.Future)
end

function SkinStudioState.Get(self: State): any
	return SkinSchema.Copy(self.Item)
end

function SkinStudioState.Peek(self: State): any
	return self.Item
end

function SkinStudioState.Set(self: State, path: { string | number }, value: any)
	local now = SkinSchema.Get(self.Item, path)
	if SkinSchema.Same(now, value) and (now ~= nil) == (value ~= nil) then
		return
	end
	local before = SkinSchema.Copy(self.Item)
	SkinSchema.Set(self.Item, path, SkinSchema.Copy(value))
	if self.Grouped == nil then
		push(self, before)
	end
	self.Changed:Fire("Set")
end

function SkinStudioState.Replace(self: State, item: any)
	if SkinSchema.Same(self.Item, item) then
		return
	end
	local before = SkinSchema.Copy(self.Item)
	self.Item = SkinSchema.Copy(item)
	if self.Grouped == nil then
		push(self, before)
	end
	self.Changed:Fire("Set")
end

function SkinStudioState.Begin(self: State)
	if self.Grouped == nil then
		self.Grouped = SkinSchema.Copy(self.Item)
	end
end

function SkinStudioState.Commit(self: State)
	local before = self.Grouped
	self.Grouped = nil
	if before ~= nil and not SkinSchema.Same(before, self.Item) then
		push(self, before)
		self.Changed:Fire("Commit")
	end
end

function SkinStudioState.CanUndo(self: State): boolean
	return #self.History > 0
end

function SkinStudioState.CanRedo(self: State): boolean
	return #self.Future > 0
end

function SkinStudioState.Undo(self: State)
	self:Commit()
	local before = table.remove(self.History)
	if before == nil then
		return
	end
	table.insert(self.Future, self.Item)
	self.Item = before
	self.Changed:Fire("Undo")
end

function SkinStudioState.Redo(self: State)
	self:Commit()
	local after = table.remove(self.Future)
	if after == nil then
		return
	end
	table.insert(self.History, self.Item)
	self.Item = after
	self.Changed:Fire("Redo")
end

function SkinStudioState.Reset(self: State)
	self:Commit()
	if SkinSchema.Same(self.Item, self.Original) then
		return
	end
	push(self, self.Item)
	self.Item = SkinSchema.Copy(self.Original)
	self.Changed:Fire("Reset")
end

function SkinStudioState.Dirty(self: State): boolean
	return not SkinSchema.Same(self.Item, self.Saved)
end

function SkinStudioState.MarkSaved(self: State)
	self.Saved = SkinSchema.Copy(self.Item)
	self.Changed:Fire("Saved")
end

return SkinStudioState
