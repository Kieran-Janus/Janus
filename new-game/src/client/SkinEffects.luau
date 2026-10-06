--!strict
--[[
	Special animated skin effects, drawn by each player's own screen for the CRAZY players SkinFx
	picks (the closest few). A skin names one with Style.Crazy.Effect; its numbers are in
	Config.Skins.Effects.Special[<name>].

	  Torment   two ghostly chains swirling round you, and red lightning crackling now and then
	            (the Tormented Tower's skin)

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
