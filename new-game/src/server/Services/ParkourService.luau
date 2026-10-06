--!strict
--[[
	PARKOUR: "Spooky Sky Climb" in the lobby (settings: Config.Parkour; on/off:
	Config.Features.Parkour; the course is built by src/server/Hub/Sections/Parkour.luau).

	The server decides everything from where characters really are (checked every
	Config.Parkour.CheckSeconds), never from what a player's computer says:
	  - standing on a part tagged ParkourStart gets you ready; leaving it starts the clock
	  - parts tagged ParkourCheckpoint (attribute Index) must be touched in Index order
	  - falling below the lowest pad (minus FallMargin), or touching a part tagged
	    ParkourHazard (green slime), sends you back to your last checkpoint (or the start)
	  - reaching a part tagged ParkourFinish after every checkpoint, and no faster than
	    MinSeconds, finishes: best time and finishes are saved (data.Parkour) and
	    Reward.Coins are given once every Reward.CooldownHours
	  - moving sideways or upwards faster than anyone can run, jump or climb stops the run
	    ("TooFast": a teleport or fly cheat; limits SpeedTolerance, MaxRiseSpeed... in Config,
	    the maths in src/shared/SpeedCheck.luau)
	Players in a round (attribute InRound) are left alone; a run stops when you respawn,
	leave the course, join a round or leave the game. Parts are found by tag only, so pieces
	can be moved, resized or copied in Studio. A saved hub with no course gets one built.

	Remotes (made in Start even when the feature is off):
	  ParkourEvent    server -> client (kind, info): Start, Checkpoint {Index, Count},
	                  Back {Reason = "Fall" | "Hazard", Checkpoint}, Missed {Next},
	                  NeedCheckpoints, NeedStart (on a checkpoint without a run),
	                  Finish {Time, Best, NewBest, Coins, Wait},
	                  Cancel {Reason = "Stopped" | "TooFast" | "Left" | "TimeUp" | "Cheat"}
	  ParkourRequest  client -> server ("GoToStart" | "Stop") -> (ok, message)
	Player attributes: ParkourRun ("" | "Ready" | "Running"), ParkourStarted (server time),
	  ParkourReached, ParkourBest (seconds, 0 = never), ParkourRuns, ParkourRewardAt
	  (server time when coins can be won again, 0 = now).
	ReplicatedStorage attribute: ParkourCheckpoints (how many checkpoints the course has).
	Admin (F8): "Parkour: teleport to start", "Parkour: reset my best/cooldown".

	ParkourService.GoToStart(player) -> (boolean, string)
	ParkourService.Course() -> CourseParts    the tagged parts right now
	ParkourService.Run(player) -> Run?        the player's run (for tests)
	ParkourService.Check()                    one round of position checks (the loop calls it)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkourLogic = require(ReplicatedStorage.Shared.ParkourLogic)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local HubService = require(script.Parent.HubService)
local ShopService = require(script.Parent.ShopService)
local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)
local ParkourSection = require(script.Parent.Parent.Hub.Sections.Parkour)
local CourseRunner = require(script.Parent.Parent.Parkour.CourseRunner)

local ParkourService = {}

local cfg = Config.Parkour
local started = false

export type CourseParts = CourseRunner.CourseParts
export type Run = CourseRunner.Run

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local runner = CourseRunner.new({
	Name = "ParkourService",
	Feature = "Parkour",
	Settings = function()
		return Config.Parkour :: any
	end,
	Tags = {
		Start = Tags.ParkourStart,
		Checkpoint = Tags.ParkourCheckpoint,
		Finish = Tags.ParkourFinish,
		Hazard = Tags.ParkourHazard,
		Board = Tags.ParkourBoard,
	},
	Prefix = "Parkour",
	SaveKey = "Parkour",
	SaveNumbers = { "Best", "LastReward", "Runs" },
	CountAttribute = "ParkourCheckpoints",
	Event = "ParkourEvent",
	Request = "ParkourRequest",
	-- Coins once every Reward.CooldownHours.
	OnFinish = function(player: Player, _time: number, saved: { [string]: any })
		local now = os.time()
		local wait = ParkourLogic.RewardWait(saved.LastReward, now, cfg.Reward.CooldownHours)
		local coins = 0
		if wait <= 0 and cfg.Reward.Coins > 0 then
			coins = cfg.Reward.Coins
			DataService.Add(player, "Coins", coins)
			saved.LastReward = now
			wait = cfg.Reward.CooldownHours * 3600
			pcall(ShopService.Push, player)
		end
		return { Coins = coins, Wait = wait }
	end,
	-- When coins can be won again (the menu tile shows it).
	Publish = function(player: Player, saved: { [string]: any })
		local wait = ParkourLogic.RewardWait(saved.LastReward, os.time(), cfg.Reward.CooldownHours)
		player:SetAttribute("ParkourRewardAt", if wait > 0 then serverNow() + wait else 0)
	end,
	BoardGui = ParkourSection.BoardGui,
})

function ParkourService.Course(): CourseParts
	return runner.Course()
end

function ParkourService.Check()
	runner.Check()
end

function ParkourService.Run(player: Player): Run?
	return runner.Run(player)
end

-- Teleports a player in the lobby to the start pad. Returns (ok, message for the player).
function ParkourService.GoToStart(player: Player): (boolean, string)
	return runner.GoToStart(player)
end

-- A saved hub from before the course existed (or baked with the feature off) gets one.
local function ensureCourse()
	for _, instance in CollectionService:GetTagged(Tags.ParkourStart) do
		if instance:IsDescendantOf(workspace) then
			return
		end
	end
	local hub = HubService.Get()
	if not hub then
		return
	end
	HubBuilder.RepairSection(hub, "Parkour")
	warn(
		"[ParkourService] The lobby had no parkour start pad, so the course was built for this server. To keep it, F8 > Rebuild hub or run require(game.ServerScriptService.Server.Tools.Bake).Hub() in edit mode, then save."
	)
end

function ParkourService.Start()
	runner.Start() -- remotes first, even when switched off
	if not Config.Features.Parkour or started then
		return
	end
	started = true

	local ok, err = pcall(ensureCourse :: any)
	if not ok then
		warn("[ParkourService] Couldn't build the course: " .. tostring(err))
	end

	AdminService.Register("ParkourToStart", "Parkour: teleport to start", function(player, _data)
		local done, message = ParkourService.GoToStart(player)
		return if done then "Teleported to the parkour start." else message
	end)
	AdminService.Register("ParkourReset", "Parkour: reset my best/cooldown", function(player, data)
		data.Parkour = { Best = 0, LastReward = 0, Runs = 0 }
		runner.Publish(player)
		runner.UpdateBoards()
		return "Parkour best time, finishes and coin cooldown reset."
	end)
	-- F8 > Reset my save cleared data.Parkour: show the fresh best time and cooldown.
	AdminService.OnSaveReset(function(player)
		runner.Publish(player)
		runner.UpdateBoards()
	end)
end

return ParkourService
