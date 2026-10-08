-- Haunted portraits (src/server/Build/Portrait.luau, client src/client/PortraitEyes.luau): the
-- Spooky Mansion hangs painted portraits whose eyes follow the camera, or your own pictures
-- (Paintings.Images), and the pupils slide the right way.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

describe("Haunted portraits", function()
	it("hangs painted portraits with following eyes round the Spooky Mansion", function()
		local rt = Runtime.new()
		local MapService = rt:require("ServerScriptService.Server.Services.MapService")
		local map = MapService.Load("SpookyMansion")
		local portraits, canvases, pupils = 0, 0, 0
		for _, d in map.Model:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropName") == "Portrait" then
				portraits += 1
			end
			if d:IsA("Frame") and d.Name == "Pupil" then
				pupils += 1
			end
		end
		local CS = rt.game:GetService("CollectionService")
		for _, canvas in CS:GetTagged("PortraitEyes") do
			if canvas:IsDescendantOf(map.Model) then
				canvases += 1
				expect(canvas:FindFirstChildOfClass("SurfaceGui")).toBeTruthy()
				expect(canvas.CanCollide).toBe(false)
			end
		end
		T.note(("%d portraits"):format(portraits))
		expect(portraits).toBeGreaterThanOrEqual(12)
		expect(canvases).toBe(portraits)
		expect(pupils).toBe(portraits * 2)
		MapService.Unload()
	end)

	it("paints your own pictures instead when the map lists some", function()
		local rt = Runtime.new()
		local Config = rt:require("ReplicatedStorage.Shared.Config")
		for _, def in Config.Maps.List do
			if def.Id == "SpookyMansion" then
				def.Paintings.Images = { "rbxassetid://1234567" }
			end
		end
		local MapService = rt:require("ServerScriptService.Server.Services.MapService")
		local map = MapService.Load("SpookyMansion")
		local pictures = 0
		for _, d in map.Model:GetDescendants() do
			if d:IsA("ImageLabel") and d.Name == "Picture" then
				expect(d.Image).toBe("rbxassetid://1234567")
				pictures += 1
			end
		end
		expect(pictures).toBeGreaterThanOrEqual(12)
		MapService.Unload()
	end)

	it("moves the pupils towards the camera", function()
		local rt = Runtime.new({ client = true })
		local PortraitEyes = rt:require("StarterPlayer.StarterPlayerScripts.Client.PortraitEyes")
		local V3 = rt.env.Vector3
		-- Straight in front (-Z is in front of the canvas): looking straight out.
		local ahead = PortraitEyes.Aim(V3.new(0, 0, -10))
		expect(ahead.X).toBeNear(0.5, 1e-6)
		expect(ahead.Y).toBeNear(0.5, 1e-6)
		-- The camera off to the canvas's -X side is on the viewer's right: pupils go right.
		local right = PortraitEyes.Aim(V3.new(-10, 0, -10))
		expect(right.X > 0.5).toBe(true)
		-- Above: pupils go up (smaller Y on the screen).
		local up = PortraitEyes.Aim(V3.new(0, 10, -10))
		expect(up.Y < 0.5).toBe(true)
		-- Never out of the eye.
		local far = PortraitEyes.Aim(V3.new(1000, -1000, -1))
		expect(far.X >= 0 and far.X <= 1 and far.Y >= 0 and far.Y <= 1).toBe(true)
	end)
end)
