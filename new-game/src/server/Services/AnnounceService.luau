--!strict
--[[
	Server-wide announcements (looks: Config.Announce). Every player in the server gets a big
	banner at the top of the screen (client AnnounceUI). The words come from the feature that
	announces (they are built on the server from Config text and a player's display name, so
	no player-typed text is ever shown).

	AnnounceService.All(text, style?)   style: "Big" (default) or "Huge"
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AnnounceService = {}

local remote: RemoteEvent? = nil

function AnnounceService.All(text: string, style: string?)
	local event = remote or Remotes.Event("Announce")
	remote = event
	local chosen = if style and (Config.Announce.Styles :: any)[style] then style else "Big"
	event:FireAllClients({ Text = text, Style = chosen })
end

function AnnounceService.Start()
	remote = Remotes.Event("Announce")
end

return AnnounceService
