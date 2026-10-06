--!strict
--[[
	TORMENTED TOWER: the really hard climb inside the clock tower (settings:
	Config.TowerParkour; on/off: Config.Features.TowerParkour; built by
	src/server/Hub/Sections/TowerParkour.luau).

	The run is checked by the server exactly like the lobby parkour (src/server/Parkour/
	CourseRunner.luau): the START pad starts the clock, checkpoints (tag TowerCheckpoint, Index
	1, 2, 3) in order, falling or slime sends you back to your last checkpoint, teleporting or
	flying stops the run (the speed check allows sprinting), and a finish faster than
	MinSeconds doesn't count. Your best time and finishes are saved in data.TowerParkour.

	The first finish ever wins the tower's exclusive skin (Config.TowerParkour.Reward.SkinId,
	never sold, in no crate) and the Roblox badge Reward.BadgeId (0 = none). Every finish tells
	the whole server: "<name> conquered the Tormented Tower!" (AnnounceService).

	Moving pieces: platforms tagged TowerVanish fade, flicker and vanish on a timer (attribute
	Phase, Config.TowerParkour.Vanish); spinning bars (TowerSpinner) and cogs (TowerGear) turn on
	their motors, owned by the server so no player's computer moves them.

	Remotes (made in Start even when the feature is off): TowerEvent, TowerRequest (like the
	lobby parkour's ParkourEvent / ParkourRequest). Player attributes: TowerRun, TowerStarted,
	TowerReached, TowerBest, TowerRuns, TowerConquered. ReplicatedStorage: TowerCheckpoints.
	Admin (F8): "Tower: teleport to start", "Tower: teleport to checkpoint 1/2/3", "Tower: reset
	my progress" (best time, finishes and the skin, so the prize can be won again).

	TowerService.GoToStart(player) -> (ok, message)
	TowerService.Course() / Check() / Run(player)   (for tests, like ParkourService)
	TowerService.UpdateVanish(now)                    one step of the vanishing platforms
]]

local BadgeService = game:GetService("BadgeService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Tags = require(ReplicatedStorage.Shared.Tags)
local AdminService = require(script.Parent.AdminService)
local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local HubService = require(script.Parent.HubService)
local ShopService = require(script.Parent.ShopService)
local HubBuilder = require(script.Parent.Parent.Hub.HubBuilder)
local CourseRunner = require(script.Parent.Parent.Parkour.CourseRunner)

local TowerService = {}

local cfg = Config.TowerParkour
local started = false

-- The lobby parkour's run settings, with the tower's own times and words.
local function settings(): CourseRunner.Settings
	local merged = table.clone(Config.Parkour :: any)
	merged.MinSeconds = cfg.MinSeconds
	-- The start pad sits on the tower's floor: landing on that floor counts as a fall.
	merged.FallMargin = 0.3
	merged.MaxRunSeconds = cfg.MaxRunSeconds
	merged.Text = cfg.Text
	return merged
end

local function awardBadge(player: Player)
	local id = cfg.Reward.BadgeId
	if type(id) ~= "number" or id <= 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, id)
		end)
		if ok and not has then
			local awarded, err = pcall(function()
				BadgeService:AwardBadge(player.UserId, id)
			end)
			if not awarded then
				warn(("[TowerService] Couldn't award badge %d: %s"):format(id, tostring(err)))
			end
		end
	end)
end

-- The prize: the skin (first finish only), the badge and the announcement.
local function reward(player: Player, _time: number, saved: { [string]: any }): { [string]: any }
	local info: { [string]: any } = {}
	if saved.Conquered ~= true then
		saved.Conquered = true
		local data = DataService.Get(player)
		local skin = Items.Get(cfg.Reward.SkinId)
		if data and skin then
			data.Owned[skin.Id] = true
			info.Skin = skin.Name
			pcall(ShopService.Push, player)
		end
	end
	awardBadge(player)
	AnnounceService.All(cfg.Text.Announce:format(player.DisplayName), "Big")
	return info
end

local runner = CourseRunner.new({
	Name = "TowerService",
	Feature = "TowerParkour",
	Settings = settings,
	Tags = {
		Start = Tags.TowerStart,
		Checkpoint = Tags.TowerCheckpoint,
		Finish = Tags.TowerFinish,
		Hazard = Tags.TowerHazard,
	},
	Prefix = "Tower",
	SaveKey = "TowerParkour",
	SaveNumbers = { "Best", "Runs" },
	CountAttribute = "TowerCheckpoints",
	Event = "TowerEvent",
	Request = "TowerRequest",
	OnFinish = reward,
	Publish = function(player: Player, saved: { [string]: any })
		player:SetAttribute("TowerConquered", saved.Conquered == true)
	end,
})

function TowerService.Course(): CourseRunner.CourseParts
	return runner.Course()
end

function TowerService.Check()
	runner.Check()
end

function TowerService.Run(player: Player): CourseRunner.Run?
	return runner.Run(player)
end

function TowerService.GoToStart(player: Player): (boolean, string)
	return runner.GoToStart(player)
end

-- Moving pieces ------------------------------------------------------------------------------

-- Vanishing platforms: there for Visible seconds (flickering for the last Warn of them), then
-- gone for Gone seconds. Each one's Phase shifts its timer.
function TowerService.UpdateVanish(now: number)
	local v = cfg.Vanish
	local cycle = v.Visible + v.Gone
	for _, instance in CollectionService:GetTagged(Tags.TowerVanish) do
		if not (instance:IsA("BasePart") and instance:IsDescendantOf(workspace)) then
			continue
		end
		local phase = instance:GetAttribute("Phase")
		local t = (now + (if type(phase) == "number" then phase else 0)) % cycle
		if t < v.Visible - v.Warn then
			instance.CanCollide = true
			instance.Transparency = 0.15
			instance.Color = cfg.Look.Colors.Vanish
		elseif t < v.Visible then
			instance.CanCollide = true
			local blink = math.floor(t * 10) % 2 == 0
			instance.Transparency = if blink then 0.6 else 0.15
			instance.Color = cfg.Look.Colors.VanishWarn
		else
			instance.CanCollide = false
			instance.Transparency = 1
		end
	end
end

-- Spinning bars and cogs: the server owns their physics (no player's computer moves them).
local function ownByServer(instance: Instance)
	if
		instance:IsA("BasePart")
		and instance:IsDescendantOf(workspace)
		and not instance.Anchored
	then
		pcall(function()
			instance:SetNetworkOwner(nil)
		end)
	end
end

-- A saved hub from before the tower existed gets one for this server.
local function ensureCourse()
	for _, instance in CollectionService:GetTagged(Tags.TowerStart) do
		if instance:IsDescendantOf(workspace) then
			return
		end
	end
	local hub = HubService.Get()
	if not hub then
		return
	end
	local existing = hub:FindFirstChild("TowerParkour")
	if existing then
		existing:Destroy()
	end
	HubBuilder.BuildSection(hub, "TowerParkour")
	warn(
		"[TowerService] The lobby had no Tormented Tower, so it was built for this server. To keep it, F8 > Rebuild hub or run require(game.ServerScriptService.Server.Tools.Bake).Hub() in edit mode, then save."
	)
end

local function checkpointCount(): number
	local n = 0
	for _, step in cfg.Course do
		if step.Kind == "Checkpoint" then
			n += 1
		end
	end
	return n
end

function TowerService.Start()
	runner.Start() -- remotes first, even when switched off
	if not Config.Features.TowerParkour or started then
		return
	end
	started = true

	local ok, err = pcall(ensureCourse :: any)
	if not ok then
		warn("[TowerService] Couldn't build the tower: " .. tostring(err))
	end

	for _, tag in { Tags.TowerSpinner, Tags.TowerGear } do
		for _, instance in CollectionService:GetTagged(tag) do
			ownByServer(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			task.defer(ownByServer, instance)
		end)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			TowerService.UpdateVanish(os.clock())
		end
	end)

	AdminService.Register("TowerToStart", "Tower: teleport to start", function(player, _data)
		local done, message = runner.GoToStart(player)
		return if done then "Teleported to the Tormented Tower's start." else message
	end)
	for n = 1, checkpointCount() do
		AdminService.Register(
			"TowerCheckpoint" .. n,
			("Tower: teleport to checkpoint %d"):format(n),
			function(player, _data)
				local done, message = runner.ToCheckpoint(player, n)
				return if done
					then ("On tower checkpoint %d (the clock is running)."):format(n)
					else message
			end
		)
	end
	AdminService.Register("TowerReset", "Tower: reset my progress", function(player, data)
		data.TowerParkour = { Best = 0, Runs = 0, Conquered = false }
		local skinId = cfg.Reward.SkinId
		data.Owned[skinId] = nil
		if data.Equipped and data.Equipped.Skin == skinId then
			data.Equipped.Skin = ""
			pcall(ShopService.Dress, player)
		end
		pcall(ShopService.Push, player)
		runner.Publish(player)
		return "Tower best time, finishes and the Tormented Soul skin reset."
	end, true)
	AdminService.OnSaveReset(function(player)
		runner.Publish(player)
	end)
end

return TowerService
