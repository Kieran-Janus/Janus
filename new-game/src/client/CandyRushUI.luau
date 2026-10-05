--!strict
--[[
	Candy Rush minigame screen (Config.Minigames.CandyRush): your candies to click and who wins.
	On/off: Config.Features.CandyRush (off = Mount does nothing and nothing shows).
	TODO(minigames agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CandyRushUI = {}

function CandyRushUI.Mount(_gui: ScreenGui)
	if not Config.Features.CandyRush then
		return
	end
end

return CandyRushUI
