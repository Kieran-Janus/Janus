--!strict
--[[
	Special animated skin effects, drawn by each player's own screen for the CRAZY players SkinFx
	picks (the closest few). A skin names one with Style.Crazy.Effect; its numbers are in
	Config.Skins.Effects.Special[<name>].

	  Torment       two ghostly chains swirling round you, and red lightning crackling now and
	                then (the Tormented Tower's skin)
	  BloodMoon     a blood moon behind you circled by bats, red mist rising (Night Lord Supreme)
	  DiscoInferno  a mirror ball over your head, sweeping coloured beams, a glowing dance-floor
	                ring (Disco Demon)
	  UfoBeam       a little flying saucer beaming you up (Star Voyager)

	SkinEffects.Has(name) -> boolean
	SkinEffects.Create(name, folder) -> State?   builds the pieces (in `folder`, this screen only)
	SkinEffects.Step(state, root, now)           moves them round the character's root part
	SkinEffects.Destroy(state)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SkinEffects = {}

export type State = {
	Name: string,
	Parts: { BasePart },
	Bolts: { BasePart },
	NextBolt: number,
	BoltUntil: number,
	Folder: Instance,
}

local function piece(folder: Instance, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.Parent = folder
	return p
end

type Effect = {
	Create: (folder: Instance) -> State,
	Step: (state: State, root: BasePart, now: number) -> (),
}

local effects: { [string]: Effect } = {}

effects.Torment = {
	Create = function(folder: Instance): State
		local c = Config.Skins.Effects.Special.Torment
		local state: State = {
			Name = "Torment",
			Parts = {},
			Bolts = {},
			NextBolt = 0,
			BoltUntil = 0,
			Folder = folder,
		}
		for _ = 1, c.Links * 2 do
			local link = piece(folder, Vector3.new(0.22, 0.22, 0.7), c.ChainColor)
			link.Transparency = 0.25
			table.insert(state.Parts, link)
		end
		for _ = 1, 4 do
			local bolt = piece(folder, Vector3.new(0.12, 0.12, 1), c.BoltColor)
			bolt.Transparency = 1
			table.insert(state.Bolts, bolt)
		end
		return state
	end,
	Step = function(state: State, root: BasePart, now: number)
		local c = Config.Skins.Effects.Special.Torment
		local base = root.Position - Vector3.new(0, 2.6, 0)
		local turn = now * math.pi * 2 / c.Seconds
		-- Two chains in a double helix, links turned along the chain.
		for k, link in state.Parts do
			local chain = if k <= c.Links then 0 else 1
			local i = (k - 1) % c.Links
			local t = i / math.max(c.Links - 1, 1)
			local a = turn + t * math.pi * 2.5 + chain * math.pi
			local radius = c.Radius * (1 - 0.25 * math.sin(t * math.pi))
			local position = base
				+ Vector3.new(math.cos(a) * radius, t * c.Height, math.sin(a) * radius)
			local ahead = base
				+ Vector3.new(
					math.cos(a + 0.3) * radius,
					(t + 0.05) * c.Height,
					math.sin(a + 0.3) * radius
				)
			link.CFrame = CFrame.lookAt(position, ahead)
				* CFrame.Angles(0, 0, if i % 2 == 0 then 0 else math.pi / 2)
		end
		-- Lightning: a jagged bolt from above your head down beside you, now and then.
		if now >= state.NextBolt then
			state.NextBolt = now + c.BoltEvery * (0.6 + math.random() * 0.8)
			state.BoltUntil = now + c.BoltSeconds
			local side = math.random() * math.pi * 2
			local from = root.Position + Vector3.new(math.cos(side) * 1.5, 4, math.sin(side) * 1.5)
			local to = root.Position + Vector3.new(math.cos(side) * 3, -2.5, math.sin(side) * 3)
			local points = { from }
			for n = 1, #state.Bolts - 1 do
				local p = from:Lerp(to, n / #state.Bolts)
				table.insert(
					points,
					p + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.4
				)
			end
			table.insert(points, to)
			for n, bolt in state.Bolts do
				local a, b = points[n], points[n + 1]
				bolt.Size = Vector3.new(0.14, 0.14, (b - a).Magnitude)
				bolt.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
		local flashing = now < state.BoltUntil
		for _, bolt in state.Bolts do
			bolt.Transparency = if flashing then 0 else 1
		end
	end,
}

local function ball(folder: Instance, size: number, color: Color3): Part
	local p = piece(folder, Vector3.one * size, color)
	p.Shape = Enum.PartType.Ball
	return p
end

local function disc(folder: Instance, diameter: number, thick: number, color: Color3): Part
	local p = piece(folder, Vector3.new(thick, diameter, diameter), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder lying flat (its axis up)

local function newState(name: string, folder: Instance): State
	return { Name = name, Parts = {}, Bolts = {}, NextBolt = 0, BoltUntil = 0, Folder = folder }
end

-- ONE IN A MILLION: a blood moon behind you, circled by bats, with red mist rising.
-- Parts: [1] moon, [2] halo, then 3 per bat (body, two wings), then the mist puffs.
effects.BloodMoon = {
	Create = function(folder: Instance): State
		local c = Config.Skins.Effects.Special.BloodMoon
		local state = newState("BloodMoon", folder)
		local moon = ball(folder, c.MoonSize, c.MoonColor)
		moon.Transparency = 0.05
		table.insert(state.Parts, moon)
		local halo = disc(folder, c.MoonSize * 1.7, 0.1, c.MoonColor)
		halo.Transparency = 0.7
		table.insert(state.Parts, halo)
		for _ = 1, c.Bats do
			table.insert(state.Parts, ball(folder, 0.45, c.BatColor))
			for _ = 1, 2 do
				local wing = piece(folder, Vector3.new(0.55, 0.06, 0.3), c.BatColor)
				wing.Material = Enum.Material.SmoothPlastic
				table.insert(state.Parts, wing)
			end
		end
		for _ = 1, c.Mist do
			local puff = ball(folder, 0.8, c.MistColor)
			puff.Transparency = 0.6
			table.insert(state.Parts, puff)
		end
		return state
	end,
	Step = function(state: State, root: BasePart, now: number)
		local c = Config.Skins.Effects.Special.BloodMoon
		local back = root.CFrame.LookVector
		local centre = root.Position
			+ Vector3.new(0, c.MoonHeight, 0)
			- Vector3.new(back.X, 0, back.Z) * 1.4
		local parts = state.Parts
		parts[1].CFrame = CFrame.new(centre)
		parts[2].CFrame = CFrame.lookAt(centre, centre + back) * CFrame.Angles(0, math.rad(90), 0)
		local turn = now * math.pi * 2 / c.Seconds
		for b = 1, c.Bats do
			local a = turn + (b - 1) / c.Bats * math.pi * 2
			local at = centre
				+ Vector3.new(
					math.cos(a) * c.MoonSize * 0.95,
					math.sin(a * 2) * 0.5,
					math.sin(a) * c.MoonSize * 0.95
				)
			local heading = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
			local i = 2 + (b - 1) * 3
			parts[i + 1].CFrame = heading
			local flap = math.sin(now * 22 + b) * 0.7
			parts[i + 2].CFrame = heading * CFrame.new(-0.35, 0, 0) * CFrame.Angles(0, 0, flap)
			parts[i + 3].CFrame = heading * CFrame.new(0.35, 0, 0) * CFrame.Angles(0, 0, -flap)
		end
		local first = 2 + c.Bats * 3
		for k = 1, c.Mist do
			local t = (now * 0.5 + k / c.Mist) % 1
			local a = k / c.Mist * math.pi * 2 + now * 0.3
			local puff = parts[first + k]
			puff.Size = Vector3.one * (0.6 + t * 1.4)
			puff.Transparency = 0.45 + t * 0.55
			puff.CFrame = CFrame.new(
				root.Position + Vector3.new(math.cos(a) * 1.7, -2.6 + t * 3.5, math.sin(a) * 1.7)
			)
		end
	end,
}

-- ONE IN A MILLION: a spinning mirror ball over your head, sweeping coloured beams and a
-- glowing dance-floor ring at your feet. Parts: [1] ball, [2] ring, then the beams.
effects.DiscoInferno = {
	Create = function(folder: Instance): State
		local c = Config.Skins.Effects.Special.DiscoInferno
		local state = newState("DiscoInferno", folder)
		local mirror = ball(folder, c.BallSize, Color3.fromRGB(220, 220, 235))
		mirror.Material = Enum.Material.Foil
		table.insert(state.Parts, mirror)
		local ring = disc(folder, c.FloorRing * 2, 0.08, Color3.new(1, 1, 1))
		ring.Transparency = 0.55
		table.insert(state.Parts, ring)
		for _ = 1, c.Beams do
			local beam = piece(folder, Vector3.new(0.18, 0.18, c.BeamLength), Color3.new(1, 1, 1))
			beam.Transparency = 0.45
			table.insert(state.Parts, beam)
		end
		return state
	end,
	Step = function(state: State, root: BasePart, now: number)
		local c = Config.Skins.Effects.Special.DiscoInferno
		local parts = state.Parts
		local top = root.Position + Vector3.new(0, c.BallHeight, 0)
		parts[1].CFrame = CFrame.new(top) * CFrame.Angles(0, now * 3, 0)
		parts[2].CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * UPRIGHT
		parts[2].Color = Color3.fromHSV((now * 0.4) % 1, 0.8, 1)
		local turn = now * math.pi * 2 / c.Seconds
		for k = 1, c.Beams do
			local a = turn + (k - 1) / c.Beams * math.pi * 2
			local dir = Vector3.new(math.cos(a), -0.75, math.sin(a)).Unit
			local beam = parts[2 + k]
			beam.CFrame = CFrame.lookAt(top + dir * c.BeamLength / 2, top + dir * c.BeamLength)
			beam.Color = Color3.fromHSV(((k - 1) / c.Beams + now * 0.25) % 1, 0.85, 1)
		end
	end,
}

-- ONE IN A MILLION: a little flying saucer beaming you up. Parts: [1] saucer, [2] dome,
-- [3..8] rim lights, then 4 layers of the light cone, then the sparks.
effects.UfoBeam = {
	Create = function(folder: Instance): State
		local c = Config.Skins.Effects.Special.UfoBeam
		local state = newState("UfoBeam", folder)
		local saucer = disc(folder, c.SaucerWidth, 0.5, Color3.fromRGB(200, 205, 215))
		saucer.Material = Enum.Material.Metal
		table.insert(state.Parts, saucer)
		local dome = ball(folder, c.SaucerWidth * 0.45, Color3.fromRGB(150, 255, 230))
		dome.Material = Enum.Material.Glass
		dome.Transparency = 0.35
		table.insert(state.Parts, dome)
		for _ = 1, 6 do
			table.insert(state.Parts, ball(folder, 0.35, Color3.fromRGB(255, 240, 120)))
		end
		for layer = 1, 4 do
			local cone = disc(folder, c.SaucerWidth * (0.35 + layer * 0.18), 1.3, c.BeamColor)
			cone.Transparency = 0.82
			table.insert(state.Parts, cone)
		end
		for _ = 1, c.Sparks do
			table.insert(state.Parts, ball(folder, 0.22, Color3.new(1, 1, 1)))
		end
		return state
	end,
	Step = function(state: State, root: BasePart, now: number)
		local c = Config.Skins.Effects.Special.UfoBeam
		local parts = state.Parts
		local bob = math.sin(now * 2) * 0.25
		local spin = now * math.pi * 2 / c.Seconds
		local hover = root.Position + Vector3.new(0, c.SaucerHeight + bob, 0)
		parts[1].CFrame = CFrame.new(hover) * CFrame.Angles(0, spin, 0) * UPRIGHT
		parts[2].CFrame = CFrame.new(hover + Vector3.new(0, 0.45, 0))
		for k = 1, 6 do
			local a = spin + (k - 1) / 6 * math.pi * 2
			local light = parts[2 + k]
			light.CFrame = CFrame.new(
				hover + Vector3.new(math.cos(a), 0, math.sin(a)) * (c.SaucerWidth / 2 - 0.1)
			)
			light.Color = if (k + math.floor(now * 6)) % 2 == 0
				then Color3.fromRGB(255, 240, 120)
				else Color3.fromRGB(255, 90, 200)
		end
		local feet = root.Position - Vector3.new(0, 2.9, 0)
		for layer = 1, 4 do
			local y = hover.Y - 0.6 - (hover.Y - 0.6 - feet.Y) * (layer - 0.5) / 4
			parts[8 + layer].CFrame = CFrame.new(Vector3.new(hover.X, y, hover.Z)) * UPRIGHT
		end
		for s = 1, c.Sparks do
			local t = (now * 0.45 + s / c.Sparks) % 1
			local a = s * 2.4 + now * 3
			local radius = 0.5 + t * 0.9
			parts[12 + s].CFrame = CFrame.new(
				feet
					+ Vector3.new(
						math.cos(a) * radius,
						t * (hover.Y - feet.Y - 0.8),
						math.sin(a) * radius
					)
			)
			parts[12 + s].Transparency = t * 0.6
		end
	end,
}

function SkinEffects.Has(name: string): boolean
	return effects[name] ~= nil
end

function SkinEffects.Create(name: string, folder: Instance): State?
	local effect = effects[name]
	return if effect then effect.Create(folder) else nil
end

function SkinEffects.Step(state: State, root: BasePart, now: number)
	local effect = effects[state.Name]
	if effect then
		effect.Step(state, root, now)
	end
end

function SkinEffects.Destroy(state: State)
	for _, list in { state.Parts, state.Bolts } do
		for _, p in list do
			p:Destroy()
		end
	end
	state.Parts = {}
	state.Bolts = {}
end

return SkinEffects
