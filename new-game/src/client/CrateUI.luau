--!strict
--[[
	Crate shop and opening animation (Config.Crates). The preview lists every item in a
	crate with its % chance before you buy. Rolls happen on the server (CrateService).
	On/off: Config.Features.Crates (off = Mount and Open do nothing).

	CrateUI.Mount(gui)
	CrateUI.Open(crateId?)   opens the crate panel, on that crate if given. Safe to call
	                         before Mount (does nothing until then).

	TODO(crates agent): this is a placeholder so other modules (the Menu, the shop) can
	already call it; the real UI goes here. Only call a remote the server creates even when
	the feature is off, or check Config.Features first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CrateUI = {}

function CrateUI.Mount(_gui: ScreenGui)
	if not Config.Features.Crates then
		return
	end
end

function CrateUI.Open(_crateId: string?)
	if not Config.Features.Crates then
		return
	end
	-- TODO(crates agent): show the crate panel.
end

return CrateUI
