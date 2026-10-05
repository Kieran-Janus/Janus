--!strict
--[[
	Web Scour minigame screen (Config.Minigames.WebScour): what to find and the timer.
	On/off: Config.Features.WebScour (off = Mount does nothing and nothing shows).
	TODO(minigames agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WebScourUI = {}

function WebScourUI.Mount(_gui: ScreenGui)
	if not Config.Features.WebScour then
		return
	end
end

return WebScourUI
