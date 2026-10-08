-- Your own words instead of the game's (src/client/TextOverrides.luau): exact and partial
-- swaps, longest first, labels made later and text the code changes later, pairs added in the
-- place's ReplicatedStorage.TextOverrides folder, typed text left alone, and no loops.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local function world(pairs: { [string]: string }?): any
	local rt = Runtime.new({ client = true })
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	for from, to in pairs or {} do
		Config.TextOverrides.Pairs[from] = to
	end
	local player = rt.game:GetService("Players").LocalPlayer
	local gui = rt:create("ScreenGui", { Name = "GameUI" }, player:WaitForChild("PlayerGui"))
	local TextOverrides = rt:require("StarterPlayer.StarterPlayerScripts.Client.TextOverrides")
	return { rt = rt, Config = Config, gui = gui, TextOverrides = TextOverrides }
end

describe("TextOverrides.Apply", function()
	it("swaps whole texts and pieces of longer ones, the longest match first", function()
		local w = world()
		local pairs = {
			{ From = "Pumpkin Shop", To = "Pumpkin Store" },
			{ From = "Pumpkin", To = "Gourd" },
		}
		table.sort(pairs, function(a, b)
			return #a.From > #b.From
		end)
		expect(w.TextOverrides.Apply("Pumpkin Shop", pairs)).toBe("Pumpkin Store")
		expect(w.TextOverrides.Apply("Ready: 0/1 | Pumpkin time", pairs)).toBe(
			"Ready: 0/1 | Gourd time"
		)
		expect(w.TextOverrides.Apply("Nothing here", pairs)).toBe("Nothing here")
		-- Special characters are plain text, not patterns.
		expect(w.TextOverrides.Apply("50% off!", { { From = "50%", To = "Half" } })).toBe(
			"Half off!"
		)
	end)

	it("skips a pair whose new text holds the old one (it would grow forever)", function()
		local w = world({ ["Play"] = "Play now", ["Shop"] = "Store" })
		local list = w.TextOverrides.Pairs()
		expect(#list).toBe(1)
		expect(list[1].From).toBe("Shop")
	end)
end)

describe("TextOverrides on screen", function()
	it("changes labels now, labels made later and text the code sets later", function()
		local w = world({ ["Stand here to play!"] = "Step in!" })
		local before = w.rt:create("TextLabel", { Text = "Stand here to play!" }, w.gui)
		w.TextOverrides.Mount(w.gui)
		w.rt:advance(0.1)
		expect(before.Text).toBe("Step in!")
		local later = w.rt:create("TextButton", { Text = "Hi" }, w.gui)
		w.rt:advance(0.1)
		later.Text = "Stand here to play!"
		expect(later.Text).toBe("Step in!")
		-- What players type is theirs.
		local box = w.rt:create("TextBox", { Text = "Stand here to play!" }, w.gui)
		w.rt:advance(0.1)
		expect(box.Text).toBe("Stand here to play!")
	end)

	it("picks up pairs saved in the place (ReplicatedStorage.TextOverrides)", function()
		local w = world()
		local label = w.rt:create("TextLabel", { Text = "PLAY!" }, w.gui)
		w.TextOverrides.Mount(w.gui)
		w.rt:advance(0.1)
		expect(label.Text).toBe("PLAY!")
		local RS = w.rt.game:GetService("ReplicatedStorage")
		local folder = w.rt:create("Folder", { Name = "TextOverrides" }, RS)
		local value = w.rt:create("StringValue", { Name = "1", Value = "GO!" }, nil)
		value:SetAttribute("From", "PLAY!")
		value.Parent = folder
		w.rt:advance(0.1)
		expect(label.Text).toBe("GO!")
	end)

	it("does nothing at all with no pairs", function()
		local w = world()
		local label = w.rt:create("TextLabel", { Text = "Stand here to play!" }, w.gui)
		w.TextOverrides.Mount(w.gui)
		w.rt:advance(0.1)
		expect(label.Text).toBe("Stand here to play!")
		expect(#w.rt.errors).toBe(0)
	end)
end)
