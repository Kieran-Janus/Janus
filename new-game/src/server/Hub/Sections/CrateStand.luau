--!strict
--[[
	Lobby section: the crate stand next to the Pumpkin Shop (Config.Lobby.Zones.Crates).
	Every crate in Config.Crates.List sits on its own plinth: themed crates on the low front
	row, rarity crates raised up on the back row. Walking up to one shows "Open <crate>", which
	opens the crate panel on that crate (src/client/CrateUI.luau) with every skin and its chance.

	Workspace.Hub.CrateStand
	  Mat              the boards under the stand (only for looks)
	  SignBoard        the "MYSTERY CRATES" sign on two posts at the back
	  <CrateId>Display one per crate:
	    Plinth, PlinthTop, GlowRing   the stand it sits on (GlowRing glows in the crate's colour)
	    <CrateId>      the crate itself (prop: drop your own model called e.g. "PumpkinCrate"
	                   into ReplicatedStorage.Custom.Props to replace it)
	    CratePrompt    invisible part (tag CrateDisplay, attribute CrateId) holding the
	                   ProximityPrompt. Move or copy the whole Display model in Studio and it
	                   keeps working; any part you tag CrateDisplay and give a CrateId opens
	                   that crate.
	  Lanterns         jack-o-lanterns at the front corners

	Look and words: Config.Crates.Stand and Config.Crates.Text (src/shared/Config/Crates.luau).
	Switched off (Config.Features.Crates = false): only an empty CrateStand model is made.

	CrateStand.Build(hub, zone) -> Model   (zone is ignored: the stand always uses the Crates zone)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CrateArt = require(ReplicatedStorage.Shared.CrateArt)
local CrateOdds = require(ReplicatedStorage.Shared.CrateOdds)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local HubLayout = require(script.Parent.Parent.HubLayout)

type Zone = HubLayout.Zone

local CrateStand = {}

local ZONE = "Crates" -- Config.Lobby.Zones.Crates
local paint = Kit.painter(Config.Hub.Palette)
local part = paint.part
local decor = paint.decor
local color = paint.color

local function jackOLantern(cf: CFrame, size: number, parent: Instance): Model
	return Kit.jackOLantern(cf, size, Config.Hub.Palette :: any, parent)
end

-- One crate on its plinth, with the prompt that opens it.
local function display(
	parent: Instance,
	crate: CrateOdds.Crate,
	base: CFrame,
	plinthHeight: number,
	size: number,
	rng: Random
): Model
	local m = Kit.model(crate.Id .. "Display", parent)
	local width = size + 0.7
	part({
		Name = "Plinth",
		Size = Vector3.new(width, plinthHeight, width),
		CFrame = base * CFrame.new(0, plinthHeight / 2, 0),
		PaletteRole = "Stone",
		PaletteShade = 0.25,
		Material = Enum.Material.Slate,
	}, m)
	part({
		Name = "PlinthFoot",
		Size = Vector3.new(width + 0.5, 0.4, width + 0.5),
		CFrame = base * CFrame.new(0, 0.2, 0),
		PaletteRole = "Stone",
		PaletteShade = 0.4,
		Material = Enum.Material.Slate,
	}, m)
	local top = part({
		Name = "PlinthTop",
		Size = Vector3.new(width + 0.3, 0.3, width + 0.3),
		CFrame = base * CFrame.new(0, plinthHeight + 0.15, 0),
		PaletteRole = "Wood",
		Material = Enum.Material.WoodPlanks,
	}, m)
	-- A glowing band in the crate's colour around the top of the plinth.
	local ring = Kit.decor({
		Name = "GlowRing",
		Size = Vector3.new(width + 0.06, 0.18, width + 0.06),
		CFrame = base * CFrame.new(0, plinthHeight - 0.35, 0),
		Color = crate.Glow,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, m)
	Kit.light(ring, crate.Color:Lerp(Color3.new(1, 1, 1), 0.3), size * 3.2, 1.3, false)

	-- The crate floats a little above the plinth and bobs (client HubAmbience).
	local stand = top.CFrame * CFrame.new(0, 0.15 + 0.25, 0)
	-- (only for looks: the prompt is on its own part below)
	local crateModel = Kit.prop(crate.Id, stand, m, CrateArt.Height(size), function()
		local built = CrateArt.Build(crate, size)
		built:PivotTo(stand)
		return built
	end, { Visual = true })
	crateModel.Name = crate.Id
	local bob = Config.Crates.Stand.Bob
	if bob > 0 and crateModel.PrimaryPart then
		Kit.float(crateModel, bob, rng)
	end

	-- The prompt lives on its own invisible part, so swapping the crate's look never loses it.
	local holder = Kit.holder(
		"CratePrompt",
		stand * CFrame.new(0, size * 0.5, 0),
		Vector3.new(size, size, size),
		m
	)
	holder:SetAttribute("CrateId", crate.Id)
	CollectionService:AddTag(holder, Tags.CrateDisplay)
	CrateArt.AddPrompt(holder, crate)
	return m
end

-- The "MYSTERY CRATES" sign on two posts behind the back row.
local function sign(parent: Instance, cf: CFrame, width: number)
	local m = Kit.model("SignBoard", parent)
	local postHeight = 11.5
	for _, side in { -1, 1 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.8, postHeight, 0.8),
			CFrame = cf * CFrame.new(side * (width / 2 + 0.2), postHeight / 2, 0),
			PaletteRole = "Wood",
			PaletteShade = 0.2,
			Material = Enum.Material.Wood,
		}, m)
		-- A glowing "?" ball on top of each post.
		local orb = decor({
			Name = "PostOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.3,
			CFrame = cf * CFrame.new(side * (width / 2 + 0.2), postHeight + 0.6, 0),
			PaletteRole = "Purple",
			PaletteShade = -0.2,
			Material = Enum.Material.Neon,
		}, m)
		Kit.setRole(Kit.light(orb, color("Purple", -0.3), 14, 1.2, true), "Purple", -0.3)
	end
	local boardHeight = 2.6
	local boardY = postHeight - boardHeight / 2 - 0.4
	local board = part({
		Name = "Board",
		Size = Vector3.new(width, boardHeight, 0.4),
		CFrame = cf * CFrame.new(0, boardY, 0),
		PaletteRole = "Dark",
		Material = Enum.Material.Wood,
	}, m)
	Kit.surfaceText(
		board,
		Config.Crates.Stand.SignText,
		color("Orange", -0.15),
		Enum.NormalId.Front
	)
	-- Glowing frame around the board.
	for _, y in { -1, 1 } do
		decor({
			Name = "Frame",
			Size = Vector3.new(width + 0.3, 0.22, 0.5),
			CFrame = cf * CFrame.new(0, boardY + y * (boardHeight / 2 + 0.05), 0),
			PaletteRole = "Orange",
			Material = Enum.Material.Neon,
		}, m)
	end
	-- Little hanging lanterns under the board.
	for i = -2, 2 do
		local x = i * width / 5
		decor({
			Name = "LanternString",
			Size = Vector3.new(0.06, 0.8, 0.06),
			CFrame = cf * CFrame.new(x, boardY - boardHeight / 2 - 0.45, -0.1),
			PaletteRole = "Iron",
		}, m)
		local bulb = decor({
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.55,
			CFrame = cf * CFrame.new(x, boardY - boardHeight / 2 - 1, -0.1),
			PaletteRole = "Glow",
			Material = Enum.Material.Neon,
		}, m)
		if i == 0 then
			Kit.light(bulb, color("Glow"), 16, 1.1, true):SetAttribute("PaletteRole", "Glow")
		end
	end
end

function CrateStand.Build(hub: Model, _zone: Zone): Model
	local area = Kit.model("CrateStand", hub)
	if not Config.Features.Crates then
		return area
	end
	local zone = HubLayout.Zone(ZONE)
	local cf = zone.CFrame
	local width = math.max(zone.Size.X - 1, 8)
	local depth = math.max(zone.Size.Z - 1, 6)
	local rng = Random.new(Config.Hub.Seed + 7)
	local cfg = Config.Crates.Stand

	decor({
		Name = "Mat",
		Size = Vector3.new(width, 0.1, depth),
		CFrame = cf * CFrame.new(0, 0.05, 0),
		PaletteRole = "Wood",
		PaletteShade = 0.35,
		Material = Enum.Material.WoodPlanks,
	}, area)
	decor({
		Name = "MatEdge",
		Size = Vector3.new(width + 0.4, 0.08, depth + 0.4),
		CFrame = cf * CFrame.new(0, 0.03, 0),
		PaletteRole = "Purple",
		PaletteShade = 0.3,
	}, area)

	-- Themed crates on the low front row, rarity crates raised up behind them (like seats in
	-- a stadium), so every crate can be seen from the plaza.
	local front: { CrateOdds.Crate } = {}
	local back: { CrateOdds.Crate } = {}
	for _, crate in CrateOdds.List() do
		table.insert(if crate.Rarity then back else front, crate)
	end
	local size = cfg.CrateSize
	local function row(
		list: { CrateOdds.Crate },
		z: number,
		plinthHeight: number,
		crateSize: number
	)
		if #list == 0 then
			return
		end
		local spacing = math.min(crateSize + 1.6, (width - crateSize - 1) / math.max(#list - 1, 1))
		for i, crate in list do
			-- The crate's -X is the viewer's right, so the list reads left to right.
			local x = ((#list + 1) / 2 - i) * spacing
			display(area, crate, cf * CFrame.new(x, 0, z), plinthHeight, crateSize, rng)
		end
	end
	row(front, -depth / 2 + 2.2, 1.2, size * 0.85)
	row(back, depth / 2 - 2.8, 3.8, size)

	sign(area, cf * CFrame.new(0, 0, depth / 2 - 0.6), math.min(width - 2, 16))

	-- Jack-o-lanterns beside the raised back row.
	local lanterns = Kit.model("Lanterns", area)
	for _, side in { -1, 1 } do
		local spot = cf * CFrame.new(side * (width / 2 - 0.9), 0, depth / 2 - 2.6)
		jackOLantern(spot * CFrame.Angles(0, math.rad(side * 25), 0), 1.6, lanterns)
	end
	return area
end

return CrateStand
