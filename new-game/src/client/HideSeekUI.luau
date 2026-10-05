--!strict
--[[
	Pumpkin Hide & Seek screen (Config.HideSeek): team, candy gun aim and hiders left. Shows
	only while the ReplicatedStorage attribute Mode is "HideSeek".
	On/off: Config.Features.HideSeek (off = Mount does nothing and nothing shows).
	TODO(hide & seek agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HideSeekUI = {}

function HideSeekUI.Mount(_gui: ScreenGui)
	if not Config.Features.HideSeek then
		return
	end
end

return HideSeekUI
