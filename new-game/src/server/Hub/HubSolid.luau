--!strict
--[[
	A solid lobby (Config.Lobby.Solid). Most lobby decorations are built walk-through (Kit.decor),
	with only a trunk or a post solid. HubSolid.Apply(hub) runs when the game starts (on a fresh,
	saved or Locked hub, and on custom models from ReplicatedStorage.Custom.Props) and makes
	every visible piece you would bump into or stand on solid, except:
	  - tiny pieces (longest side under MinSize) and low ones you'd step over (StepHeight)
	  - see-through pieces (mist, glow, light beams: more than MaxTransparency)
	  - decorations in KeepWalkThrough (by PropName) and groups (Folders or Models) named in KeepAreas
	  - parts that DO something (a tag from Tags.luau on the part itself, e.g. a secret pumpkin
	    you walk into) and the looks of such parts (Kit.look, attribute PropLook): a parkour
	    step's look must not change the jump, the working part already collides
	Solid pieces are hit by raycasts too (CanQuery) but never fire Touched.

	HubSolid.Apply(hub, settings?) -> number   how many parts were made solid (settings: a round
	                                           map's Config.Maps.Solid; nil = Config.Lobby.Solid)
	HubSolid.ShouldBeSolid(part, hub)  -> boolean   (used by the spec)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local HubSolid = {}

export type Settings = {
	On: boolean,
	MinSize: number,
	StepHeight: number,
	MaxTransparency: number,
	KeepWalkThrough: { string },
	KeepAreas: { string },
	KeepParts: { string }?,
	KeepVisualProps: boolean?,
}

local override: Settings? = nil -- (set while Apply runs with a round map's settings)

local function cfg(): Settings
	if override then
		return override
	end
	return Config.Lobby.Solid
end

-- True when `part` is inside something that must stay walk-through or is a look/working part.
local function excludedByAncestors(part: BasePart, hub: Instance): boolean
	local settings = cfg()
	local keepParts = settings.KeepParts
	if keepParts and table.find(keepParts, part.Name) then
		return true -- a piece kept walk-through by its own name (a map's corn leaves, wires)
	end
	local node: Instance? = part
	while node and node ~= hub do
		if settings.KeepVisualProps and node:GetAttribute("PropVisual") == true then
			return true -- built as decoration only (Kit.prop Visual): never something to hide behind
		end
		if node:GetAttribute("PropLook") ~= nil then
			return true -- the look of a working part
		end
		local propName = node:GetAttribute("PropName")
		if typeof(propName) == "string" and table.find(settings.KeepWalkThrough, propName) then
			return true
		end
		if node ~= part and table.find(settings.KeepAreas, node.Name) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- How far the top of `part` is above the solid ground (or solid piece) under it.
local function heightAboveGround(part: BasePart, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local cf, size = part.CFrame, part.Size
	-- The lowest and highest corners of the part's box.
	local lowest, top = math.huge, -math.huge
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local corner = (cf * Vector3.new(x * size.X, y * size.Y, z * size.Z)).Y
				lowest = math.min(lowest, corner)
				top = math.max(top, corner)
			end
		end
	end
	local origin = Vector3.new(cf.Position.X, top + 0.05, cf.Position.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else lowest
	return top - ground
end

function HubSolid.ShouldBeSolid(part: BasePart, hub: Instance, ignore: { Instance }?): boolean
	local settings = cfg()
	if part.CanCollide or part.Transparency > settings.MaxTransparency then
		return false
	end
	local size = part.Size
	if math.max(size.X, size.Y, size.Z) < settings.MinSize then
		return false
	end
	if Kit.isWorking(part) or excludedByAncestors(part, hub) then
		return false
	end
	-- Low pieces you'd step over (path stones, curbs, glowing floor text, rugs).
	return heightAboveGround(part, ignore or { part }) > settings.StepHeight
end

local function applyNow(hub: Instance): number
	if not cfg().On then
		return 0
	end
	-- Decide everything first (the ground under a piece is the solid ground as built), then
	-- switch them on together.
	local chosen: { BasePart } = {}
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and HubSolid.ShouldBeSolid(d, hub, { d }) then
			table.insert(chosen, d)
		end
	end
	for _, part in chosen do
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
	end
	return #chosen
end

-- `settings`: a round map's rules (Config.Maps.Solid); the lobby's (Config.Lobby.Solid) if nil.
function HubSolid.Apply(hub: Instance, settings: Settings?): number
	override = settings
	local ok, result = pcall(applyNow, hub)
	override = nil
	if not ok then
		error(result, 0)
	end
	return result
end

return HubSolid
