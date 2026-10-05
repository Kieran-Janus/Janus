--!strict
--[[
	Watching the round from the lobby (Config.Lobby.Spectate): Menu > Spectate moves your
	camera to players in the round (and the Pumpkin King); Next/Back keys cycle through them.
	On/off: Config.Features.LobbySpectate (off = nothing happens).

	Spectate.Mount(gui)
	Spectate.Toggle()             start watching, or stop if already watching
	Spectate.Stop()               camera back to your own character
	Spectate.IsActive() -> boolean

	TODO(rounds agent): this is a placeholder so other modules (the Menu) can already call
	it; the real camera code goes here. GhostUI's spectate code shows how to pick targets
	(InRound and not Out, plus Kings) and restore the camera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Spectate = {}

local active = false

function Spectate.Mount(_gui: ScreenGui)
	if not Config.Features.LobbySpectate then
		return
	end
end

function Spectate.Toggle()
	if not Config.Features.LobbySpectate then
		return
	end
	-- TODO(rounds agent): start or stop watching.
end

function Spectate.Stop()
	active = false
end

function Spectate.IsActive(): boolean
	return active
end

return Spectate
