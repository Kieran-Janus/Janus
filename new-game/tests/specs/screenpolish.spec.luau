-- Screen polish (Config.ScreenMotion, src/client/ScreenFx.luau): the Hide & Seek, ScareMaze,
-- jumpscare, ghost, spectate, rewards, NPC dialogue, announcement and Voting Board screens
-- animate, but every animation ends on the real final state (shown, full size, straight, the
-- exact words and numbers), actions (BOO, votes, Next, skip) register at once, nothing is
-- left behind afterwards, and with the switch off everything is instant.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")
local Dom = require("../harness/Dom")

local describe, it, expect = T.describe, T.it, T.expect

local REMOTE_EVENTS = {
	"SetGhostMode",
	"DailyReward",
	"PromptFavorite",
	"Announce",
	"CastVote",
	"VoteUpdate",
	"HideSeekEvent",
	"HideSeekShoot",
	"ScareMazeBoo",
	"ScareMazeScare",
	"SpectateFocus",
}
local REMOTE_FUNCTIONS = { "Haunt", "RedeemCode" }

-- A client with the remotes the server would make, a 1280 x 760 screen (or a phone).
local function client(options: { phone: boolean?, motion: boolean? }?)
	local o = options or {}
	local rt = Runtime.new({ client = true })
	local remotes = rt:create("Folder", { Name = "Remotes" }, rt:find("ReplicatedStorage"))
	for _, name in REMOTE_EVENTS do
		rt:create("RemoteEvent", { Name = name }, remotes)
	end
	for _, name in REMOTE_FUNCTIONS do
		rt:create("RemoteFunction", { Name = name }, remotes)
	end
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	local Vector2 = rt.env.Vector2
	if o.phone then
		gui:SetAttribute("ForceTouch", true)
		Dom.rawSet(gui, "AbsoluteSize", Vector2.new(640, 302))
	else
		Dom.rawSet(gui, "AbsoluteSize", Vector2.new(1280, 760))
	end
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	if o.motion == false then
		Config.ScreenMotion.On = false
	end
	local Client = rt:find("StarterPlayer.StarterPlayerScripts.Client")
	rt:require(Client.Layout).Mount(gui)
	return {
		rt = rt,
		gui = gui,
		player = player,
		remotes = remotes,
		Client = Client,
		Config = Config,
		motion = Config.ScreenMotion,
		storage = rt:find("ReplicatedStorage"),
	}
end

local function fxScale(gui: any): number
	local scale = gui:FindFirstChild("FxScale")
	return if scale then scale.Scale else 1
end

-- Instances anywhere under `root` with this name.
local function count(root: any, name: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

local function fired(c, remoteName: string): { { any } }
	local list = {}
	for _, call in c.rt:calls("RemoteEvent", "FireServer") do
		if call.instance.Name == remoteName then
			table.insert(list, call.args)
		end
	end
	return list
end

describe("ScreenFx", function()
	it("ends every animation on the final state and cleans up its sparkles", function()
		local c = client()
		local ScreenFx = c.rt:require(c.Client.ScreenFx)
		local label = c.rt:create("TextLabel", { Name = "L" }, c.gui)
		ScreenFx.Punch(label, 1.6, 0.3, 8)
		expect(fxScale(label)).toBe(1.6)
		expect(label.Rotation).toBe(8)
		local home = c.rt.env.UDim2.new(0.5, 0, 1, -24)
		ScreenFx.Slide(label, home, c.rt.env.Vector2.new(0, 60), 0.3)
		expect(label.Position.Y.Offset).toBe(36)
		ScreenFx.FadeText(label, 0.7, 0.2)
		expect(label.TextTransparency).toBe(0.7)
		local burst = ScreenFx.Burst(c.gui, home, { c.rt.env.Color3.new(1, 1, 1) }, 10)
		expect(burst).toBeTruthy()
		c.rt:advance(1.5)
		expect(fxScale(label)).toBe(1)
		expect(label.Rotation).toBe(0)
		expect(label.Position).toEqual(home)
		expect(label.TextTransparency).toBe(0)
		expect(c.gui:FindFirstChild("FxBurst")).toBeNil()
		ScreenFx.Pulse(label, 3, 0.2, 0.5)
		c.rt:advance(2)
		expect(label.TextTransparency).toBe(0)
	end)

	it("is instant with ScreenMotion.On or UI.Motion.On off", function()
		for _, which in { "ScreenMotion", "UI" } do
			local c = client()
			if which == "ScreenMotion" then
				c.Config.ScreenMotion.On = false
			else
				c.Config.UI.Motion.On = false
			end
			local ScreenFx = c.rt:require(c.Client.ScreenFx)
			expect(ScreenFx.On()).toBe(false)
			local label = c.rt:create("TextLabel", { Name = "L" }, c.gui)
			ScreenFx.Punch(label, 1.6, 0.3, 8)
			expect(fxScale(label)).toBe(1)
			expect(label.Rotation).toBe(0)
			ScreenFx.FadeText(label, 0.7, 0.2)
			expect(label.TextTransparency).toBe(0)
			expect(ScreenFx.Burst(c.gui, c.rt.env.UDim2.new(), {}, 10)).toBeNil()
		end
	end)

	it("gives phones fewer sparkles", function()
		local pc = client()
		local phone = client({ phone = true })
		local a = pc.rt:require(pc.Client.ScreenFx).Count(20)
		local b = phone.rt:require(phone.Client.ScreenFx).Count(20)
		expect(a).toBe(20)
		expect(b).toBeLessThan(a)
		expect(b).toBeGreaterThan(0)
	end)
end)

describe("Hide & Seek screen motion", function()
	local function mount(motion: boolean?)
		local c = client({ motion = motion })
		c.rt:require(c.Client.HideSeekUI).Mount(c.gui)
		c.storage:SetAttribute("Mode", "HideSeek")
		c.storage:SetAttribute("State", "Hiding")
		c.player:SetAttribute("InRound", true)
		c.rt:advance(0.2)
		return c
	end

	it("pops the role banner in with a shake and settles straight, full size", function()
		local c = mount()
		local m = c.motion.HideSeek
		c.player:SetAttribute("HideSeekRole", "Hider")
		local banner = c.gui.HideSeekBanner
		expect(banner.Visible).toBe(true)
		expect(banner.Text).toBe(c.Config.HideSeek.Text.HiderRole)
		expect(fxScale(banner)).toBe(m.RolePopScale)
		expect(math.abs(banner.Rotation)).toBe(m.RoleShakeDegrees)
		c.rt:advance(1)
		expect(fxScale(banner)).toBe(1)
		expect(banner.Rotation).toBe(0)
		expect(c.gui.HideSeekTip.TextTransparency).toBe(0)
		c.rt:advance(m.BannerSeconds + 1)
		expect(banner.Visible).toBe(false)
	end)

	it("punches TAGGED! in with a burst that cleans itself up", function()
		local c = mount()
		local m = c.motion.HideSeek
		c.player:SetAttribute("HideSeekRole", "Seeker")
		c.storage:SetAttribute("State", "Playing")
		c.rt:advance(0.5)
		local hider = c.rt:addPlayer({ Name = "Pumpkin", character = false })
		c.rt:fire(
			c.remotes.HideSeekEvent,
			"OnClientEvent",
			"Tagged",
			{ Seeker = c.player, Hider = hider }
		)
		local banner = c.gui.HideSeekBanner
		expect(banner.Text).toBe(c.Config.HideSeek.Text.Tagged)
		expect(fxScale(banner)).toBe(m.TaggedPopScale)
		expect(c.gui:FindFirstChild("FxBurst")).toBeTruthy()
		local feed = c.gui.HideSeekFeed
		expect(feed.Visible).toBe(true) -- the message line at once too
		c.rt:advance(1)
		expect(fxScale(banner)).toBe(1)
		expect(banner.Rotation).toBe(0)
		expect(c.gui:FindFirstChild("FxBurst")).toBeNil()
		expect(feed:GetAttribute("MotionScale")).toBeNil() -- the pop ended at full size
	end)

	it("shows a second TAGGED! that arrives while the first one is fading", function()
		local c = mount()
		local m = c.motion.HideSeek
		c.player:SetAttribute("HideSeekRole", "Seeker")
		c.storage:SetAttribute("State", "Playing")
		c.rt:advance(m.BannerSeconds + 1)
		local function tag(name: string)
			local hider = c.rt:addPlayer({ Name = name, character = false })
			c.rt:fire(
				c.remotes.HideSeekEvent,
				"OnClientEvent",
				"Tagged",
				{ Seeker = c.player, Hider = hider }
			)
		end
		tag("First")
		c.rt:advance(1.5 + m.FadeSeconds / 2) -- the first banner is half faded
		tag("Second")
		c.rt:advance(m.FadeSeconds) -- the old fade would have finished by now
		local banner = c.gui.HideSeekBanner
		expect(banner.Visible).toBe(true)
		expect(banner.TextTransparency).toBe(0)
	end)

	it("counts the head start calmly and lets the glow warning breathe, ending solid", function()
		local c = mount()
		local m = c.motion.HideSeek
		c.player:SetAttribute("HideSeekRole", "Seeker")
		c.storage:SetAttribute("TimeLeft", 9)
		local blind = c.player.PlayerGui.HideSeekBlindfold
		expect(blind.Enabled).toBe(true)
		local counting = blind.Blindfold.Counting
		expect(counting.Text).toBe(c.Config.HideSeek.Text.Counting:format(9))
		expect(fxScale(counting)).toBe(m.CountPulseScale)
		expect(counting.Rotation).toBe(0) -- calm: no shake
		c.rt:advance(1)
		expect(fxScale(counting)).toBe(1)
		c.storage:SetAttribute("State", "Playing")
		c.rt:advance(0.2)
		c.rt:fire(c.remotes.HideSeekEvent, "OnClientEvent", "Glow", {})
		local feed = c.gui.HideSeekFeed
		expect(feed.Text).toBe(c.Config.HideSeek.Text.Glow)
		expect(feed.Visible).toBe(true)
		-- (The harness jumps a tween to its end, so only the final state can be checked.)
		c.rt:advance(m.GlowPulses * m.GlowPulseSeconds * 2 + 0.2)
		expect(feed.TextTransparency).toBe(0)
	end)

	it("shows everything at once with the motion off", function()
		local c = mount(false)
		c.player:SetAttribute("HideSeekRole", "Hider")
		local banner = c.gui.HideSeekBanner
		expect(banner.Visible).toBe(true)
		expect(fxScale(banner)).toBe(1)
		expect(banner.Rotation).toBe(0)
		local hider = c.rt:addPlayer({ Name = "Pumpkin", character = false })
		c.player:SetAttribute("HideSeekRole", "Seeker")
		c.rt:fire(
			c.remotes.HideSeekEvent,
			"OnClientEvent",
			"Tagged",
			{ Seeker = c.player, Hider = hider }
		)
		expect(fxScale(banner)).toBe(1)
		expect(c.gui:FindFirstChild("FxBurst")).toBeNil()
		c.rt:advance(c.motion.HideSeek.BannerSeconds + 0.1)
		expect(banner.Visible).toBe(false) -- gone on time, no fade
	end)
end)

describe("ScareMaze screen motion", function()
	local function mount(motion: boolean?)
		local c = client({ motion = motion })
		c.rt:require(c.Client.ScareMazeUI).Mount(c.gui)
		c.storage:SetAttribute("Mode", "ScareMaze")
		c.storage:SetAttribute("State", "Playing")
		c.storage:SetAttribute("Alive", 2)
		c.player:SetAttribute("InRound", true)
		return c
	end

	it("pops the team banner in with a shake and fades the hint in", function()
		local c = mount()
		local m = c.motion.ScareMaze
		c.player:SetAttribute("ScareTeam", "Survivors")
		c.player:SetAttribute("ScareState", "Running")
		local title = c.gui.ScareMaze.TeamTitle
		expect(title.Visible).toBe(true)
		expect(title.Text).toBe(c.Config.ScareMaze.Text.YouAreSurvivor)
		expect(fxScale(title)).toBe(m.TeamPopScale)
		expect(title.Rotation).toBe(m.TeamShakeDegrees)
		expect(c.gui.ScareMaze.TeamHint.TextTransparency).toBe(1)
		c.rt:advance(1)
		expect(fxScale(title)).toBe(1)
		expect(title.Rotation).toBe(0)
		expect(c.gui.ScareMaze.TeamHint.TextTransparency).toBe(0)
	end)

	it("sends BOO at once, then fills the cooldown ring smoothly and bumps when ready", function()
		local c = mount()
		c.player:SetAttribute("ScareTeam", "Haunters")
		c.player:SetAttribute("BooReadyAt", 0)
		c.rt:advance(0.3)
		local boo = c.gui.ScareMaze.BooButton
		expect(boo.Visible).toBe(true)
		c.rt:fire(boo, "Activated")
		expect(#fired(c, "ScareMazeBoo")).toBe(1) -- no waiting for the bump
		local cooldown = c.Config.ScareMaze.Boo.Cooldown
		c.player:SetAttribute("BooReadyAt", c.rt.workspace:GetServerTimeNow() + cooldown)
		c.rt:advance(0.1)
		local ring = boo.CooldownRing
		expect(ring.Visible).toBe(true)
		expect(boo.Cooldown.Visible).toBe(true)
		local early = ring:GetAttribute("Progress")
		expect(early).toBeLessThan(0.1)
		c.rt:advance(cooldown / 2)
		local middle = ring:GetAttribute("Progress")
		expect(middle).toBeNear(0.5, 0.05)
		expect(ring.Right.Circle.UIStroke.UIGradient.Rotation).toBeNear(180, 1)
		expect(ring.Left.Circle.UIStroke.UIGradient.Rotation).toBeNear(0, 18)
		c.rt:advance(cooldown / 2 + 0.2)
		expect(ring.Visible).toBe(false)
		expect(boo.Cooldown.Visible).toBe(false)
		c.rt:advance(1)
		expect(boo:GetAttribute("MotionScale")).toBeNil()
		local scale = boo:FindFirstChild("MotionScale")
		expect(if scale then scale.Scale else 1).toBe(1) -- the bump ended at full size
	end)

	it("punches the 3-2-1 in but keeps it readable", function()
		local c = mount()
		local m = c.motion.ScareMaze
		c.player:SetAttribute("ScareTeam", "Survivors")
		c.player:SetAttribute("ScareState", "Running")
		c.rt:advance(1.5) -- standing still
		local countdown = c.gui.ScareMaze.Countdown
		expect(countdown.Visible).toBe(true)
		expect(fxScale(countdown)).toBeLessThanOrEqual(m.CountdownPopScale)
		expect(math.abs(countdown.Rotation)).toBeLessThanOrEqual(m.CountdownTilt)
		expect(countdown.Text).toMatch("^%d$")
	end)

	it("celebrates escaping with confetti and sparkles that clean up", function()
		local c = mount()
		c.player:SetAttribute("ScareTeam", "Survivors")
		c.player:SetAttribute("ScareState", "Running")
		c.rt:advance(0.2)
		c.player:SetAttribute("ScareState", "Escaped")
		local message = c.gui.ScareMaze.Message
		expect(message.Visible).toBe(true)
		expect(message.Text).toBe(c.Config.ScareMaze.Text.Escaped)
		expect(c.gui:FindFirstChild("FxConfetti")).toBeTruthy()
		expect(c.gui:FindFirstChild("FxBurst")).toBeTruthy()
		c.rt:advance(5)
		expect(fxScale(message)).toBe(1)
		expect(c.gui:FindFirstChild("FxConfetti")).toBeNil()
		expect(c.gui:FindFirstChild("FxBurst")).toBeNil()
		expect(message.Visible).toBe(false)
	end)

	it("shows still messages and no confetti with the motion off", function()
		local c = mount(false)
		c.player:SetAttribute("ScareTeam", "Survivors")
		c.player:SetAttribute("ScareState", "Running")
		expect(fxScale(c.gui.ScareMaze.TeamTitle)).toBe(1)
		c.player:SetAttribute("ScareState", "Escaped")
		expect(fxScale(c.gui.ScareMaze.Message)).toBe(1)
		expect(c.gui:FindFirstChild("FxConfetti")).toBeNil()
	end)
end)

describe("Jumpscare", function()
	it("zooms and wobbles, then is gone on time with nothing left", function()
		local c = client()
		local Jumpscare = c.rt:require(c.Client.ScareMazeJumpscare)
		Jumpscare.Play("Ghost")
		local screen = c.player.PlayerGui.ScareMazeJumpscare
		expect(screen.Enabled).toBe(true)
		expect(screen.Face.UIScale.Scale).toBe(c.motion.Jumpscare.ZoomFrom)
		c.rt:advance(c.Config.ScareMaze.Jumpscare.Seconds + 0.1)
		expect(screen.Enabled).toBe(false)
		expect(#screen:GetChildren()).toBe(0)
	end)

	it("just shows the face (full size, still) with the motion off", function()
		local c = client({ motion = false })
		local Jumpscare = c.rt:require(c.Client.ScareMazeJumpscare)
		Jumpscare.Play("Boo")
		local screen = c.player.PlayerGui.ScareMazeJumpscare
		expect(screen.Face.UIScale.Scale).toBe(1)
		expect(screen.Face.Rotation).toBe(0)
		expect(screen.Flash.BackgroundTransparency).toBe(1)
		c.rt:advance(c.Config.ScareMaze.Jumpscare.Seconds + 0.1)
		expect(screen.Enabled).toBe(false)
		expect(#screen:GetChildren()).toBe(0)
	end)
end)

describe("Ghost panel and spectate bar", function()
	it("slides the ghost panel up and fades a new name in", function()
		local c = client()
		local m = c.motion.Ghost
		c.rt:require(c.Client.GhostUI).Mount(c.gui)
		local panel = c.gui.Ghost
		local home = panel.Position
		expect(panel.Visible).toBe(false)
		c.player:SetAttribute("GhostMode", "Spectate")
		c.player:SetAttribute("Out", true)
		expect(panel.Visible).toBe(true)
		expect(panel.Position.Y.Offset).toBe(home.Y.Offset + m.SlideDistance)
		c.rt:advance(1)
		expect(panel.Position).toEqual(home)
		-- A mode button press goes to the server at once.
		local spectate = nil
		for _, d in panel:GetDescendants() do
			if d:IsA("TextButton") and d.Text == c.Config.Ghost.ModeNames.Haunt then
				spectate = d
			end
		end
		c.rt:fire(spectate, "Activated")
		expect(fired(c, "SetGhostMode")[1][1]).toBe("Haunt")
	end)

	it("slides the spectate bar up with the exact words, instant with the motion off", function()
		for _, on in { true, false } do
			local c = client({ motion = on })
			c.Config.Features.LobbySpectate = true
			local Spectate = c.rt:require(c.Client.Spectate)
			Spectate.Mount(c.gui)
			local bar = c.gui.SpectateBar
			local home = bar.Position
			Spectate.Toggle() -- nobody playing: a short message
			expect(bar.Visible).toBe(true)
			expect(bar.Watching.Text).toBe(c.Config.Lobby.Spectate.Text.Nobody)
			if on then
				expect(bar.Position.Y.Offset).toBe(home.Y.Offset + c.motion.Spectate.SlideDistance)
				expect(bar.Watching.TextTransparency).toBe(c.motion.Spectate.NameFadeFrom)
			else
				expect(bar.Position).toEqual(home)
				expect(bar.Watching.TextTransparency).toBe(0)
			end
			c.rt:advance(1)
			expect(bar.Position).toEqual(home)
			expect(bar.Watching.TextTransparency).toBe(0)
		end
	end)
end)

describe("Rewards toasts", function()
	it(
		"slides the daily toast in, counts the coins up to the exact number and cleans up",
		function()
			local c = client()
			c.rt:require(c.Client.RewardsUI).Mount(c.gui)
			c.rt:fire(c.remotes.DailyReward, "OnClientEvent", 3, 150)
			local toast = c.gui:FindFirstChild("Toast")
			expect(toast).toBeTruthy()
			local label = toast:FindFirstChildOfClass("TextLabel")
			local final = ("Day 3 streak! +150 %s"):format(c.Config.Economy.CurrencyName)
			expect(label.Text).never.toBe(final) -- still counting
			expect(c.gui:FindFirstChild("FxConfetti")).toBeTruthy()
			c.rt:advance(2)
			expect(label.Text).toBe(final)
			expect(toast.Position).toEqual(c.rt.env.UDim2.new(0.5, 0, 0.14, 0))
			c.rt:advance(6)
			expect(c.gui:FindFirstChild("Toast")).toBeNil()
			expect(c.gui:FindFirstChild("FxConfetti")).toBeNil()
			expect(c.gui:FindFirstChild("FxBurst")).toBeNil()
		end
	)

	it("stacks two toasts and moves the second up when the first goes", function()
		local c = client()
		c.rt:require(c.Client.RewardsUI).Mount(c.gui)
		c.rt:fire(c.remotes.DailyReward, "OnClientEvent", 1, 50)
		c.rt:advance(2)
		c.rt:fire(c.remotes.DailyReward, "OnClientEvent", 2, 60)
		c.rt:advance(1)
		local list = {}
		for _, child in c.gui:GetChildren() do
			if child.Name == "Toast" then
				table.insert(list, child)
			end
		end
		expect(#list).toBe(2)
		expect(list[2].Position.Y.Offset).toBeGreaterThan(list[1].Position.Y.Offset)
		c.rt:advance(2.5) -- the first one goes
		local left = c.gui:FindFirstChild("Toast")
		expect(left.Position.Y.Offset).toBe(0)
	end)

	it("shows the exact words at once with the motion off", function()
		local c = client({ motion = false })
		c.rt:require(c.Client.RewardsUI).Mount(c.gui)
		c.rt:fire(c.remotes.DailyReward, "OnClientEvent", 3, 150)
		local toast = c.gui.Toast
		expect(toast:FindFirstChildOfClass("TextLabel").Text).toBe(
			("Day 3 streak! +150 %s"):format(c.Config.Economy.CurrencyName)
		)
		expect(toast.Position).toEqual(c.rt.env.UDim2.new(0.5, 0, 0.14, 0))
		expect(c.gui:FindFirstChild("FxConfetti")).toBeNil()
		c.rt:advance(5.1)
		expect(c.gui:FindFirstChild("Toast")).toBeNil()
	end)
end)

describe("NPC dialogue", function()
	local function open(c)
		local prompt = c.rt:create("ProximityPrompt", {}, c.rt.workspace)
		prompt:SetAttribute("NpcId", "Leaderboard")
		c.rt:fire(
			c.rt.game:GetService("ProximityPromptService"),
			"PromptTriggered",
			prompt,
			c.player
		)
	end

	it("pops in and types the exact words out; a tap shows them all, Next works at once", function()
		local c = client()
		c.rt:require(c.Client.NpcDialogUI).Mount(c.gui)
		c.rt:advance(1)
		open(c)
		local dialog = c.gui.NpcDialog
		expect(dialog.Visible).toBe(true)
		local lines
		for _, def in c.Config.Npcs.List do
			if def.Id == "Leaderboard" then
				lines = def.Lines
			end
		end
		local body = nil
		for _, child in dialog:GetChildren() do
			if child:IsA("TextLabel") and child.Text == lines[1] then
				body = child
			end
		end
		expect(body).toBeTruthy() -- the whole page is there at once...
		expect(body.MaxVisibleGraphemes).toBe(0) -- ...and types out
		c.rt:advance(0.05)
		c.rt:fire(dialog.Skip, "Activated")
		expect(body.MaxVisibleGraphemes).toBe(-1) -- tap: all of it
		c.rt:advance(c.motion.NpcDialog.MaxTypeSeconds + 0.5)
		expect(body.MaxVisibleGraphemes).toBe(-1)
		expect(dialog:GetAttribute("MotionScale")).toBeNil() -- popped in to full size
		if #lines > 1 then
			local nextButton = nil
			for _, child in dialog:GetChildren() do
				if child:IsA("TextButton") and child.Text == "Next" then
					nextButton = child
				end
			end
			c.rt:fire(nextButton, "Activated")
			expect(body.Text).toBe(lines[2]) -- at once
			c.rt:advance(c.motion.NpcDialog.MaxTypeSeconds + 0.2)
			expect(body.MaxVisibleGraphemes).toBe(-1)
		end
	end)

	it("shows the whole page at once with the motion off", function()
		local c = client({ motion = false })
		c.rt:require(c.Client.NpcDialogUI).Mount(c.gui)
		c.rt:advance(1)
		open(c)
		for _, child in c.gui.NpcDialog:GetChildren() do
			if child:IsA("TextLabel") then
				expect(child.MaxVisibleGraphemes).toBe(-1)
			end
		end
	end)
end)

describe("Announcements", function()
	local function cards(c): { any }
		local list = {}
		for _, child in c.gui.Announcements:GetChildren() do
			if child.Name == "Announcement" then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.Position.Y.Offset < b.Position.Y.Offset
		end)
		return list
	end

	it("stacks several, slides each in with a shine and leaves nothing behind", function()
		local c = client()
		local Announce = c.rt:require(c.Client.AnnounceUI)
		Announce.Mount(c.gui)
		for i = 1, 5 do
			c.rt:fire(c.remotes.Announce, "OnClientEvent", { Text = "News " .. i, Style = "Big" })
		end
		expect(#cards(c)).toBe(c.Config.Announce.MaxShown) -- the rest wait
		expect(count(c.gui, "FxShine")).toBe(3)
		c.rt:advance(1)
		local shown = cards(c)
		expect(shown[1].Text.Text).toBe("News 1")
		expect(shown[1].Position.Y.Offset).toBe(0)
		local step = c.Config.Announce.Styles.Big.Height + c.Config.Announce.Gap
		expect(shown[2].Position.Y.Offset).toBe(step)
		expect(shown[3].Position.Y.Offset).toBe(step * 2)
		c.rt:advance(c.Config.Announce.Styles.Big.Seconds)
		-- The first three went; the last two moved up into place.
		shown = cards(c)
		expect(#shown).toBe(2)
		expect(shown[1].Text.Text).toBe("News 4")
		expect(shown[1].Position.Y.Offset).toBe(0)
		c.rt:advance(c.Config.Announce.Styles.Big.Seconds + 1)
		expect(#cards(c)).toBe(0)
		expect(c.gui.Announcements.Visible).toBe(false)
		expect(count(c.gui, "FxShine")).toBe(0)
	end)

	it("shows one at a time on phones, briefly", function()
		local c = client({ phone = true })
		local Announce = c.rt:require(c.Client.AnnounceUI)
		Announce.Mount(c.gui)
		Announce.Show("Big news", "Huge")
		Announce.Show("More news", "Big")
		expect(#cards(c)).toBe(1)
		c.rt:advance(c.Config.Announce.PhoneMaxSeconds + 0.5)
		local shown = cards(c)
		expect(#shown).toBe(1)
		expect(shown[1].Text.Text).toBe("More news")
	end)

	it("shows them still and in place with the motion off", function()
		local c = client({ motion = false })
		local Announce = c.rt:require(c.Client.AnnounceUI)
		Announce.Mount(c.gui)
		Announce.Show("One", "Big")
		Announce.Show("Two", "Big")
		local shown = cards(c)
		expect(shown[1].Position.Y.Offset).toBe(0)
		expect(shown[2].Position.Y.Offset).toBe(
			c.Config.Announce.Styles.Big.Height + c.Config.Announce.Gap
		)
		expect(count(c.gui, "FxShine")).toBe(0)
		c.rt:advance(c.Config.Announce.Styles.Big.Seconds + 0.1)
		expect(#cards(c)).toBe(0)
	end)
end)

describe("Voting Board", function()
	local function state(a: number, b: number)
		return {
			Open = true,
			ReadyOnly = false,
			Maps = {
				{ Id = "KingHuntPatch", Name = "King Hunt", Votes = a },
				{ Id = "ScareMaze", Name = "ScareMaze", Votes = b },
			},
			Difficulties = {},
		}
	end

	local function board(c): any
		return c.player.PlayerGui.VotingBoard
	end

	local function buttonFor(c, name: string): any
		for _, d in board(c):GetDescendants() do
			if d:IsA("TextButton") and d.Text:sub(1, #name) == name then
				return d
			end
		end
		return nil
	end

	it(
		"pops the choices in, votes at once, and pulses the same button when its count changes",
		function()
			local c = client()
			c.rt:require(c.Client.VoteBoardUI).Mount()
			c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(0, 0))
			local king = buttonFor(c, "King Hunt")
			expect(fxScale(king)).toBe(0) -- popping in
			c.rt:fire(king, "Activated")
			local sent = fired(c, "CastVote")
			expect(#sent).toBe(1) -- at once
			expect(sent[1][1]).toBe("Map")
			expect(sent[1][2]).toBe("KingHuntPatch")
			c.rt:advance(1)
			expect(fxScale(king)).toBe(1)
			c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(2, 0))
			expect(buttonFor(c, "King Hunt")).toBe(king) -- updated in place
			expect(king.Text).toBe("King Hunt\n2")
			expect(fxScale(king)).toBe(c.motion.VoteBoard.PulseScale)
			expect(fxScale(buttonFor(c, "ScareMaze"))).toBe(1) -- unchanged: no pulse
			c.rt:advance(1)
			expect(fxScale(king)).toBe(1)
			expect(king.BackgroundColor3).toEqual(c.rt:require(c.Client.Theme).Button)
		end
	)

	it("changes counts at once with the motion off", function()
		local c = client({ motion = false })
		c.rt:require(c.Client.VoteBoardUI).Mount()
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(0, 0))
		local king = buttonFor(c, "King Hunt")
		expect(fxScale(king)).toBe(1)
		c.rt:fire(c.remotes.VoteUpdate, "OnClientEvent", state(4, 1))
		expect(king.Text).toBe("King Hunt\n4")
		expect(fxScale(king)).toBe(1)
	end)
end)

-- The candy gun (CandyGunClient, Config.ScreenMotion.CandyGun): the shot is sent at once and
-- the crosshair kicks; where the SERVER says the candy landed, a burst shows what it hit.
describe("Candy gun feedback", function()
	-- A client holding the candy gun, with the gun's screen mounted.
	local function gun(options: { phone: boolean?, motion: boolean? }?)
		local c = client(options)
		local env = c.rt.env
		local character = c.player.Character
		local tool = c.rt:create("Tool", { Name = "Candy Gun" }, character)
		tool:SetAttribute("CandyGun", true)
		local camera = c.rt.workspace.CurrentCamera
		camera.CFrame = env.CFrame.new(0, 10, 0)
		local CandyGun = c.rt:require(c.Client.CandyGunClient)
		CandyGun.Mount(c.remotes.HideSeekShoot)
		c.rt:advance(0.1)
		c.CandyGun = CandyGun
		c.cross = c.player.PlayerGui.CandyGunAim.Crosshair
		return c
	end

	local function shot(c, result: string, to: any)
		local env = c.rt.env
		c.CandyGun.OnEvent("Shot", {
			Shooter = c.player,
			From = env.Vector3.new(0, 10, 0),
			To = to,
			Normal = env.Vector3.new(0, 1, 0),
			Result = result,
			Candy = 2,
			Cooldown = 0.6,
		})
	end

	local function hits(c): { any }
		local list = {}
		local folder = c.rt.workspace:FindFirstChild("CandyEffects")
		if folder then
			for _, d in folder:GetChildren() do
				if d.Name == "CandyHitFx" then
					table.insert(list, d)
				end
			end
		end
		return list
	end

	it("sends the shot at once and kicks the crosshair back to normal", function()
		local c = gun()
		local m = c.motion.CandyGun
		c.rt:fire(
			c.rt.game:GetService("UserInputService").TouchTapInWorld,
			c.rt.env.Vector2.new(400, 300),
			false
		)
		expect(#fired(c, "HideSeekShoot")).toBe(1)
		expect(typeof(fired(c, "HideSeekShoot")[1][1])).toBe("Vector3")
		local scale = c.cross:FindFirstChildOfClass("UIScale")
		expect(scale.Scale).toBe(m.KickScale)
		expect(c.cross.Rotation).toBe(m.KickDegrees)
		c.rt:advance(0.5)
		expect(scale.Scale).toBe(1)
		expect(c.cross.Rotation).toBe(0)
	end)

	it("shows each result's burst at the server's hit point, then cleans up", function()
		local c = gun()
		local env = c.rt.env
		for i, result in { "Decoy", "Hider", "Miss" } do
			local to = env.Vector3.new(i * 6, 2, -20)
			shot(c, result, to)
			expect(#hits(c)).toBe(0) -- nothing until the candy gets there
			c.rt:advance(0.25)
			local list = hits(c)
			expect(#list).toBe(1)
			local fx = list[1]
			expect(fx:GetAttribute("Result")).toBe(result)
			expect((fx.Position - to).Magnitude).toBeLessThan(1)
			expect(fx.CanCollide).toBe(false)
			expect(fx.CanQuery).toBe(false)
			expect(fx.CanTouch).toBe(false)
			local bits = #fx.Burst:GetChildren()
			expect(bits).toBe(c.motion.CandyGun[result].Bits)
			T.note(("%s: %d pieces"):format(result, bits))
			if result == "Hider" then
				local pop = nil
				for _, d in c.rt.workspace.CandyEffects:GetDescendants() do
					if d.Name == "TaggedPop" then
						pop = d
					end
				end
				expect(pop.Size.X.Offset).toBeGreaterThan(220)
				c.rt:advance(0.5)
				expect(pop.Size.X.Offset).toBe(220)
			end
			c.rt:advance(1.5)
			expect(#hits(c)).toBe(0)
		end
		c.rt:advance(10)
		expect(#c.rt.workspace.CandyEffects:GetChildren()).toBe(0)
	end)

	it("gives phones fewer pieces", function()
		local c = gun({ phone = true })
		shot(c, "Hider", c.rt.env.Vector3.new(0, 2, -20))
		c.rt:advance(0.25)
		local bits = #hits(c)[1].Burst:GetChildren()
		expect(bits).toBeLessThan(c.motion.CandyGun.Hider.Bits)
		expect(bits).toBeGreaterThan(0)
	end)

	it("still sends at once but shows no extra effects with the motion off", function()
		for _, which in { "ScreenMotion", "UI" } do
			local c = gun()
			if which == "ScreenMotion" then
				c.Config.ScreenMotion.On = false
			else
				c.Config.UI.Motion.On = false
			end
			c.rt:fire(
				c.rt.game:GetService("UserInputService").TouchTapInWorld,
				c.rt.env.Vector2.new(400, 300),
				false
			)
			expect(#fired(c, "HideSeekShoot")).toBe(1)
			expect(c.cross:FindFirstChildOfClass("UIScale").Scale).toBe(1)
			expect(c.cross.Rotation).toBe(0)
			shot(c, "Decoy", c.rt.env.Vector3.new(0, 2, -20))
			c.rt:advance(0.25)
			expect(#hits(c)).toBe(0)
		end
	end)
end)

-- The spectating camera (SpectateTargets, Config.ScreenMotion.SpectateCamera): a new target
-- glides over, then the normal camera (Custom) follows the new subject.
describe("Spectate camera glide", function()
	local function setup(options: { motion: boolean? }?)
		local c = client(options)
		local env = c.rt.env
		local camera = c.rt.workspace.CurrentCamera
		local others = {}
		for i = 1, 3 do
			local p = c.rt:addPlayer({ Name = "Runner" .. i, character = false })
			c.rt:spawnCharacter(p, env.CFrame.new(i * 40, 5, 0))
			table.insert(others, p)
		end
		c.rt:spawnCharacter(c.player, env.CFrame.new(0, 5, 0))
		local mine = c.player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = env.Enum.CameraType.Custom
		camera.CameraSubject = mine
		camera.CFrame = env.CFrame.lookAt(env.Vector3.new(0, 12, 14), env.Vector3.new(0, 6.5, 0))
		c.camera = camera
		c.mine = mine
		c.others = others
		c.Spectate = c.rt:require(c.Client.SpectateTargets)
		return c
	end

	local function humanoidOf(p): any
		return p.Character:FindFirstChildOfClass("Humanoid")
	end

	it("glides to a new target and ends on the Custom camera following it", function()
		local c = setup()
		local Custom = c.rt.env.Enum.CameraType.Custom
		local start = c.camera.CFrame.Position
		c.Spectate.Follow(c.others[1])
		expect(c.Spectate.Gliding()).toBe(true)
		c.rt:advance(0.15)
		local mid = c.camera.CFrame.Position
		expect((mid - start).Magnitude).toBeGreaterThan(1) -- on its way...
		local goal = c.others[1].Character.HumanoidRootPart.Position
		expect((mid - goal).Magnitude).toBeGreaterThan(5) -- ...not there yet
		c.rt:advance(0.4)
		expect(c.Spectate.Gliding()).toBe(false)
		expect(c.camera.CameraType).toBe(Custom)
		expect(c.camera.CameraSubject).toBe(humanoidOf(c.others[1]))
		-- Same angle and distance as before, behind the new subject.
		local offset = c.camera.CFrame.Position - (goal + c.rt.env.Vector3.new(0, 1.5, 0))
		expect(offset).toBeNear(start - c.rt.env.Vector3.new(0, 6.5, 0), 0.01)
		-- Restoring glides back and ends on your own humanoid, Custom.
		c.Spectate.RestoreCamera()
		c.rt:advance(0.6)
		expect(c.Spectate.Gliding()).toBe(false)
		expect(c.camera.CameraType).toBe(Custom)
		expect(c.camera.CameraSubject).toBe(c.mine)
	end)

	it("ends on the last of three quick switches with nothing left running", function()
		local c = setup()
		for i = 1, 3 do
			c.Spectate.Follow(c.others[i])
			c.rt:advance(0.2 / 3)
		end
		c.rt:advance(0.5)
		expect(c.Spectate.Gliding()).toBe(false)
		expect(c.camera.CameraType).toBe(c.rt.env.Enum.CameraType.Custom)
		expect(c.camera.CameraSubject).toBe(humanoidOf(c.others[3]))
		-- Nothing moves the camera any more.
		local still = c.camera.CFrame
		c.rt:advance(0.5)
		expect(c.camera.CFrame).toEqual(still)
		-- Stopping spectating half-way through a glide still ends on your own humanoid.
		c.Spectate.Follow(c.others[1])
		c.rt:advance(0.1)
		c.Spectate.RestoreCamera()
		c.rt:advance(0.6)
		expect(c.camera.CameraType).toBe(c.rt.env.Enum.CameraType.Custom)
		expect(c.camera.CameraSubject).toBe(c.mine)
	end)

	it("switches at once with smoothing off", function()
		for _, how in { "SpectateCamera", "ScreenMotion" } do
			local c = setup()
			if how == "SpectateCamera" then
				c.Config.ScreenMotion.SpectateCamera.On = false
			else
				c.Config.ScreenMotion.On = false
			end
			c.Spectate.Follow(c.others[2])
			expect(c.Spectate.Gliding()).toBe(false)
			expect(c.camera.CameraType).toBe(c.rt.env.Enum.CameraType.Custom)
			expect(c.camera.CameraSubject).toBe(humanoidOf(c.others[2]))
			c.Spectate.RestoreCamera()
			expect(c.camera.CameraSubject).toBe(c.mine)
		end
	end)

	it("ends on your new character when you respawn during the glide back", function()
		-- The round ends while a ghost spectates: the camera glides back to your character, which
		-- is replaced half-way. A removed character keeps its Humanoid, so the glide must not
		-- hand the camera to the old one (it would stay on the unloaded map).
		local c = setup()
		c.Spectate.Follow(c.others[1])
		c.rt:advance(0.6)
		c.Spectate.RestoreCamera()
		c.rt:advance(0.1)
		local old = c.player.Character
		old.Parent = nil
		c.player.Character = nil
		local fresh = c.rt:spawnCharacter(c.player, c.rt.env.CFrame.new(0, 5, 80))
		expect(c.mine.Parent).toBe(old) -- (the old Humanoid still has its Parent)
		c.rt:advance(0.6)
		expect(c.Spectate.Gliding()).toBe(false)
		expect(c.camera.CameraType).toBe(c.rt.env.Enum.CameraType.Custom)
		expect(c.camera.CameraSubject).toBe(fresh:FindFirstChildOfClass("Humanoid"))
	end)

	it("lets the ghost's haunt cam take the camera from a glide", function()
		local c = setup()
		c.Spectate.Follow(c.others[1])
		c.rt:advance(0.1)
		c.Spectate.StopGlide()
		c.camera.CameraType = c.rt.env.Enum.CameraType.Scriptable
		local held = c.rt.env.CFrame.new(5, 50, 5)
		c.camera.CFrame = held
		c.rt:advance(0.5)
		expect(c.camera.CFrame).toEqual(held) -- the glide no longer writes the camera
		expect(c.camera.CameraType).toBe(c.rt.env.Enum.CameraType.Scriptable)
	end)
end)
