--!strict
--[[
	Lobby colours by role (Config.Hub.Palette). Parts and lights in Workspace.Hub that carry
	the attribute PaletteRole (and optionally PaletteShade) take their colour from it.

	HubPalette.Repaint(root, roles?) -> number
	    paints every part/light under `root` from the palette (only `roles`, if given);
	    returns how many changed. F8 > "Repaint hub", or Bake.Repaint() in edit mode.
	HubPalette.Stamp(hub)
	    remembers the palette the hub was painted with (attribute PaletteColors on the hub)
	HubPalette.Sync(hub) -> number
	    repaints only the roles whose colour changed in Config since the hub was painted
	    (HubService runs this on every start, so a colour change in Config shows up even on a
	    hand-edited, Locked hub, while parts you recoloured by hand in other roles keep theirs)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.Build.Kit)

local HubPalette = {}

local STAMP = "PaletteColors"

local function palette(): { [string]: Color3 }
	return Config.Hub.Palette
end

local function paint(d: Instance, roles: { [string]: boolean }?): boolean
	local role = d:GetAttribute("PaletteRole")
	if typeof(role) ~= "string" or (roles and not roles[role]) then
		return false
	end
	local shade = d:GetAttribute("PaletteShade")
	local color = Kit.roleColor(palette(), role, if typeof(shade) == "number" then shade else nil)
	if not color then
		return false
	end
	if d:IsA("BasePart") then
		if d.Color ~= color then
			d.Color = color
			return true
		end
	elseif d:IsA("Light") then
		local light = d :: any
		if light.Color ~= color then
			light.Color = color
			return true
		end
	end
	return false
end

function HubPalette.Repaint(root: Instance, roles: { [string]: boolean }?): number
	local changed = 0
	for _, d in root:GetDescendants() do
		if paint(d, roles) then
			changed += 1
		end
	end
	return changed
end

-- "R,G,B" in 0-255, so a stamp reads well in Studio's Attributes panel.
local function encode(color: Color3): string
	return ("%d,%d,%d"):format(
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function HubPalette.Stamp(hub: Model)
	local roles = {}
	for role in palette() do
		table.insert(roles, role)
	end
	table.sort(roles)
	local parts = {}
	for _, role in roles do
		table.insert(parts, role .. "=" .. encode(palette()[role]))
	end
	hub:SetAttribute(STAMP, table.concat(parts, ";"))
end

function HubPalette.Sync(hub: Model): number
	local stamp = hub:GetAttribute(STAMP)
	local old: { [string]: string } = {}
	if typeof(stamp) == "string" then
		for entry in stamp:gmatch("[^;]+") do
			local role, rgb = entry:match("^(%w+)=([%d,]+)$")
			if role and rgb then
				old[role] = rgb
			end
		end
	end
	local changedRoles: { [string]: boolean } = {}
	local any = false
	for role, color in palette() do
		if old[role] ~= encode(color) then
			changedRoles[role] = true
			any = true
		end
	end
	local changed = 0
	if any then
		changed = HubPalette.Repaint(hub, changedRoles)
	end
	HubPalette.Stamp(hub)
	return changed
end

return HubPalette
