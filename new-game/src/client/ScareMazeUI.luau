--!strict
--[[
	ScareMaze screen (Config.ScareMaze): team, the stand-still warning and the way out. Shows
	only while the ReplicatedStorage attribute Mode is "ScareMaze".
	On/off: Config.Features.ScareMaze (off = Mount does nothing and nothing shows).
	TODO(scaremaze agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ScareMazeUI = {}

function ScareMazeUI.Mount(_gui: ScreenGui)
	if not Config.Features.ScareMaze then
		return
	end
end

return ScareMazeUI
