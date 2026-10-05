--!strict
--[[
	The top-left Menu button and its tile grid (Config.Menu): Skins, Shop, Crates, Vote,
	Spectate, Invite, Codes, Settings, VIP and Parkour/Easter egg progress.
	On/off: Config.Features.Menu (off = Mount does nothing and nothing shows).
	TODO(menu agent): this is a placeholder so Main.client.luau can already mount it; the
	real UI goes here. Only call a remote the server creates even when the feature is off,
	or check Config.Features first: Remotes.Event/Function wait forever for a missing one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MenuUI = {}

function MenuUI.Mount(_gui: ScreenGui)
	if not Config.Features.Menu then
		return
	end
end

return MenuUI
