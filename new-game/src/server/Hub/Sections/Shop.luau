--!strict
--[[
	Lobby section: the Pumpkin Shop corner (Config.Lobby.Zones.Shop).

	Workspace.Hub.Shop
	  Mat            wooden boards under the stall (only for looks)
	  PumpkinVendor  the shopkeeper and stall (tag ShopKeeper). Built by src/server/Hub/Npcs.luau
	                 right after this section, because its Config.Npcs entry has Zone = "Shop":
	                 move the Shop zone in Config.Lobby and the shop moves with it.
	Decorations never go inside the zone, so nothing covers the stall.

	Shop.Build(hub, zone) -> Model
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local Shop = {}

local paint = Kit.painter(Config.Hub.Palette)

function Shop.Build(hub: Model, zone: Zone): Model
	local area = Kit.model("Shop", hub)
	local width = math.max(zone.Size.X - 6, 4)
	local depth = math.max(zone.Size.Z - 6, 4)
	paint.decor({
		Name = "Mat",
		Size = Vector3.new(width, 0.1, depth),
		CFrame = zone.CFrame * CFrame.new(0, 0.05, 0),
		PaletteRole = "Wood",
		PaletteShade = 0.3,
		Material = Enum.Material.WoodPlanks,
	}, area)
	return area
end

return Shop
