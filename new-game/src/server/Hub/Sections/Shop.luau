--!strict
--[[
	Lobby section: the Pumpkin Shop corner (Config.Lobby.Zones.Shop).

	Workspace.Hub.Shop
	  Deck           wooden boards under the stall (only for looks)
	  Dressing       pumpkin piles, crates, a barrel, a hay bale and the chalkboard out front
	  PumpkinVendor  the shopkeeper and the stall (tag ShopKeeper): the big striped awning,
	                 the "PUMPKIN SHOP" sign, shelves and lanterns. Built by
	                 src/server/Hub/Npcs.luau right after this section (its look is in
	                 src/server/Hub/NpcLooks.luau), because its Config.Npcs entry has
	                 Zone = "Shop": move the Shop zone in Config.Lobby and the shop moves with it.
	Look: Config.Hub.ShopStall. Decorations from elsewhere never go inside the zone.

	Shop.Build(hub, zone) -> Model
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local Props = require(script.Parent.Parent.Parent.Build.Props)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local Shop = {}

local cfg = Config.Hub.ShopStall
local paint = Kit.painter(Config.Hub.Palette)

-- A chalkboard on a little easel, standing on cf and facing cf.LookVector.
local function chalkboard(cf: CFrame, text: string, parent: Instance)
	local m = Kit.model("Chalkboard", parent)
	local tilt = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	paint.decor({
		Name = "Frame",
		Size = Vector3.new(2.8, 3.4, 0.2),
		CFrame = tilt,
		PaletteRole = "Wood",
		Material = Enum.Material.Wood,
	}, m)
	local board = paint.decor({
		Name = "Board",
		Size = Vector3.new(2.4, 2.6, 0.1),
		CFrame = tilt * CFrame.new(0, 0.1, -0.12),
		PaletteRole = "Dark",
		PaletteShade = -0.1,
	}, m)
	paint.decor({
		Name = "Leg",
		Size = Vector3.new(0.2, 3.2, 0.2),
		CFrame = cf * CFrame.new(0, 1.5, 0.75) * CFrame.Angles(math.rad(14), 0, 0),
		PaletteRole = "Wood",
		Material = Enum.Material.Wood,
	}, m)
	local gui = Kit.surfaceText(board, text, paint.color("Bone"))
	local label = gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Font = Enum.Font.FredokaOne
	end
end

function Shop.Build(hub: Instance, zone: Zone): Instance
	local area = Kit.group("Shop", hub)
	local width = math.max(zone.Size.X - 2, 4)
	local depth = math.max(zone.Size.Z - 2, 4)
	local base = zone.CFrame
	paint.decor({
		Name = "Deck",
		Size = Vector3.new(width, 0.2, depth),
		CFrame = base * CFrame.new(0, 0.08, 0),
		PaletteRole = "Wood",
		PaletteShade = 0.15,
		Material = Enum.Material.WoodPlanks,
	}, area)
	local dressing = Kit.group("Dressing", area)
	local edge = width / 2 - 1.6
	-- Pumpkin piles on both sides of the counter.
	for _, side in { -1, 1 } do
		local spot = base * CFrame.new(side * edge, 0.18, -3.6)
		for i = 1, cfg.Pumpkins do
			local size = if i == 1 then 2.4 else 1.6 - i * 0.12
			local offset = if i == 1
				then CFrame.identity
				else CFrame.new(
					side * -1.4 * ((i - 1) % 2) - side * 0.4,
					0,
					-1.5 - (i - 2) * 0.6
				)
			Props.Pumpkin(paint, spot * offset * CFrame.Angles(0, i * 1.3, 0), size, dressing, {
				Role = if i == 3 then "Bone" else "Orange",
			})
		end
	end
	-- Crates, a barrel and a hay bale at the back corners.
	local left = base * CFrame.new(-edge, 0.18, 3.6)
	Props.Crate(paint, left * CFrame.Angles(0, 0.2, 0), 2.2, dressing)
	Props.Crate(paint, left * CFrame.new(0.2, 2.2, 0.1) * CFrame.Angles(0, 0.6, 0), 1.6, dressing)
	local right = base * CFrame.new(edge, 0.18, 3.4)
	Props.Barrel(paint, right, 2.8, dressing)
	Props.HayRoll(
		paint,
		base * CFrame.new(edge - 0.4, 0.18, 0.4) * CFrame.Angles(0, math.rad(90), 0),
		2,
		dressing
	)
	if cfg.Chalkboard ~= "" then
		chalkboard(
			base
				* CFrame.new(edge - 0.6, 0.18, -depth / 2 + 1.2)
				* CFrame.Angles(0, math.rad(-20), 0),
			cfg.Chalkboard,
			dressing
		)
	end
	return area
end

return Shop
