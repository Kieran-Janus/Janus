--!strict
--[[
	Noise events the Pumpkin King can hear. Anything that makes noise calls Report;
	the King asks for the loudest recent noise in range with Loudest.
	Sources today: sprinting (SprintService) and pumpkin pickups (PumpkinService).
	M3 adds voice volume as another source.
]]

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Noise = { Position: Vector3, Loudness: number, Time: number, Player: Player? }

local NoiseService = {}

local noises: { Noise } = {}

local function prune(now: number)
	local keep = now - Config.King.Noise.MemorySeconds
	local i = 1
	while i <= #noises do
		if noises[i].Time < keep then
			table.remove(noises, i)
		else
			i += 1
		end
	end
end

function NoiseService.Report(position: Vector3, loudness: number, player: Player?)
	local now = os.clock()
	prune(now)
	table.insert(noises, { Position = position, Loudness = loudness, Time = now, Player = player })
end

--[[
	The noise that sounds loudest from `listener`: loudness fades with distance and age,
	and anything beyond `range` is ignored. Returns nil if nothing is audible.
]]
function NoiseService.Loudest(listener: Vector3, range: number): Noise?
	local now = os.clock()
	prune(now)
	local best: Noise? = nil
	local bestScore = 0
	for _, noise in noises do
		local distance = (noise.Position - listener).Magnitude
		if distance <= range then
			local age = (now - noise.Time) / Config.King.Noise.MemorySeconds
			local score = noise.Loudness * (1 - distance / range) * (1 - age)
			if score > bestScore then
				best, bestScore = noise, score
			end
		end
	end
	return best
end

function NoiseService.Clear()
	table.clear(noises)
end

function NoiseService.Start() end

return NoiseService
