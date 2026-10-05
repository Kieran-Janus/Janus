--!strict
--[[
	Easter egg pop-ups and progress (Config.EasterEggs): "You found ...! +50 coins" and
	how many eggs you have found.
	On/off: Config.Features.EasterEggs (off = Mount does nothing).

	EasterEggUI.Mount(gui)
	EasterEggUI.Progress() -> (found, total)   for the Menu's progress tile

	TODO(easter eggs agent): this is a placeholder so other modules (the Menu) can already
	call it; the real UI goes here. Only call a remote the server creates even when the
	feature is off, or check Config.Features first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local EasterEggUI = {}

function EasterEggUI.Mount(_gui: ScreenGui)
	if not Config.Features.EasterEggs then
		return
	end
end

function EasterEggUI.Progress(): (number, number)
	-- TODO(easter eggs agent): count the eggs this player has found.
	return 0, #Config.EasterEggs.List
end

return EasterEggUI
