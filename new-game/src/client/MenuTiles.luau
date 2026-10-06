--!strict
--[[
	The Menu's own tiles (Config.Menu.Tiles sets their words, icons, colours and order):
	  Skins        the shop on its Skins tab
	  Crates       the crate panel (only while Config.Features.Crates is on)
	  Vote         the vote panel, or a short note saying when voting starts
	  Spectate     watch the round from the lobby (during a round, if you're not in it)
	  VIP & Packs  the shop on its Packs & VIP tab
	  Parkour      a progress note (only while the parkour is on)
	  Secret Pumpkins   the Easter egg list (EasterEggUI.Open; only while the eggs are on)
	Shop, Settings, Codes and Invite come from their own panels (Layout.SideButton).
	Kept apart from MenuUI so feature screens can require MenuUI to add their own tiles
	without a require loop. Main.client.luau mounts it right after MenuUI.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateUI = require(script.Parent.CrateUI)
local EasterEggUI = require(script.Parent.EasterEggUI)
local MenuUI = require(script.Parent.MenuUI)
local ShopUI = require(script.Parent.ShopUI)
local Spectate = require(script.Parent.Spectate)
local VoteUI = require(script.Parent.VoteUI)

local MenuTiles = {}

-- Is the round state (ReplicatedStorage attribute State) one of `states`?
local function stateIsOneOf(states: { string }): boolean
	local state = ReplicatedStorage:GetAttribute("State")
	return type(state) == "string" and table.find(states, state) ~= nil
end

function MenuTiles.Mount(_gui: ScreenGui)
	if not Config.Features.Menu then
		return
	end
	local player = Players.LocalPlayer
	local text = Config.Menu.Text
	MenuUI.AddTile({
		Id = "Skins",
		Label = "Skins",
		Order = 1,
		OnClick = function()
			ShopUI.Open("Skin")
		end,
	})
	MenuUI.AddTile({
		Id = "Crates",
		Label = "Crates",
		Order = 3,
		Visible = function()
			return Config.Features.Crates
		end,
		OnClick = function()
			CrateUI.Open()
		end,
	})
	MenuUI.AddTile({
		Id = "Vote",
		Label = "Vote",
		Order = 4,
		KeepOpen = true,
		OnClick = function()
			if VoteUI.Open() then
				MenuUI.Close()
			elseif stateIsOneOf(Config.Menu.RoundStates) then
				MenuUI.ShowMessage(text.RoundRunning)
			elseif Config.Features.ReadyPad then
				MenuUI.ShowMessage(text.NoVote)
			else
				MenuUI.ShowMessage(text.NoVoteNoPad)
			end
		end,
	})
	MenuUI.AddTile({
		Id = "Spectate",
		Label = "Spectate",
		Order = 5,
		-- During a round, for players who aren't in it (and to stop watching).
		Visible = function()
			if not Config.Features.LobbySpectate then
				return false
			end
			return Spectate.IsActive()
				or (
					stateIsOneOf(Config.Menu.SpectateStates)
					and player:GetAttribute("InRound") ~= true
				)
		end,
		DynamicLabel = function(): string?
			return if Spectate.IsActive() then Config.Lobby.Spectate.Text.Stop else nil
		end,
		OnClick = function()
			Spectate.Toggle()
		end,
	})
	MenuUI.AddTile({
		Id = "Vip",
		Label = "VIP & Packs",
		Order = 9,
		OnClick = function()
			ShopUI.Open("Packs")
		end,
	})
	MenuUI.AddTile({
		Id = "Parkour",
		Label = "Parkour",
		Order = 10,
		KeepOpen = true,
		Visible = function()
			return Config.Features.Parkour
		end,
		OnClick = function()
			MenuUI.ShowMessage(
				text.Parkour:format(Config.Parkour.Reward.Coins, Config.Economy.CurrencyName)
			)
		end,
	})
	MenuUI.AddTile({
		Id = "EasterEggs",
		Label = "Secret Pumpkins",
		Order = 11,
		Visible = function()
			return Config.Features.EasterEggs
		end,
		Status = function(): string?
			local found, total = EasterEggUI.Progress()
			return if total > 0 then ("%d/%d"):format(found, total) else nil
		end,
		OnClick = function()
			EasterEggUI.Open() -- the list of found eggs and riddles (src/client/EasterEggUI.luau)
		end,
	})
end

return MenuTiles
