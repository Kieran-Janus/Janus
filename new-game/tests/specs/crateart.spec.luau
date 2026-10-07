-- CrateArt (src/shared/CrateArt.luau): every crate in Config.Crates.List builds its own cartoon
-- chest (Look.Style), with a part named "Lid" that opens on its hinge (CrateLook.Lid /
-- LidPose) moving only the lid, pure decoration (anchored, no collisions), a part budget, a
-- height close to CrateArt.Height, the Monster's googly eyes, each style's own pieces, the
-- Chest's emblem, and a custom model in ReplicatedStorage.Custom.Props winning in Preview.

local T = require("../harness/Test")
local Runtime = require("../harness/Runtime")

local describe, it, expect = T.describe, T.it, T.expect

local MAX_PARTS = 45 -- per crate (the lobby part budget; the crate panel shows up to 8 at once)

describe("CrateArt", function()
	local rt = Runtime.new()
	local Config = rt:require("ReplicatedStorage.Shared.Config")
	local CrateArt = rt:require("ReplicatedStorage.Shared.CrateArt")
	local CrateLook = rt:require("ReplicatedStorage.Shared.CrateLook")
	local HeadPieces = rt:require("ReplicatedStorage.Shared.HeadPieces")
	local CFrame, Vector3 = rt.env.CFrame, rt.env.Vector3

	local function parts(m: any): { any }
		local list = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		return list
	end

	local function named(m: any, name: string): number
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				n += 1
			end
		end
		return n
	end

	it("builds every crate: CrateId, a Lid, decoration only, within the part budget", function()
		expect(CrateArt.MaxParts).toBe(MAX_PARTS)
		local wrong = {}
		for _, size in { Config.Crates.Stand.CrateSize, 4 } do
			for _, crate in Config.Crates.List do
				local m = CrateArt.Build(crate, size)
				expect(m:GetAttribute("CrateId")).toBe(crate.Id)
				local lidPart = m:FindFirstChild("Lid", true)
				if not (lidPart and lidPart:IsA("BasePart")) then
					error(crate.Id .. " has no part named Lid")
				end
				expect(m:FindFirstChild("Inside", true)).toBeTruthy()
				local list = parts(m)
				if #list > MAX_PARTS then
					error(("%s has %d parts (limit %d)"):format(crate.Id, #list, MAX_PARTS))
				end
				for _, p in list do
					if not p.Anchored or p.CanCollide or p.CanQuery or p.CanTouch then
						error(crate.Id .. "." .. p.Name .. " is not pure decoration")
					end
					local s = p.Size
					expect(s.X > 0 and s.Y > 0 and s.Z > 0).toBe(true)
					if p:IsA("Part") and p.Shape.Name == "Ball" then
						-- (Roblox balls are always round: an oval must be a Block with a mesh)
						expect(s.X).toBeNear(s.Y, 1e-3)
						expect(s.Y).toBeNear(s.Z, 1e-3)
					end
				end
				-- Pivot: the bottom centre of the box.
				expect(m.PrimaryPart).toBeTruthy()
				expect(m:GetPivot().Position).toBeNear(Vector3.new(0, 0, 0), 1e-3)
				local cf, extent = m:GetBoundingBox()
				expect(cf.Position.Y - extent.Y / 2).toBeNear(0, size * 0.03)
				if size == Config.Crates.Stand.CrateSize then
					T.note(
						("%s (%s): %d parts, %.2f tall (Height %.2f)"):format(
							crate.Id,
							CrateLook.Of(crate).Style,
							#list,
							extent.Y,
							CrateArt.Height(size)
						)
					)
				end
				-- Height close to CrateArt.Height (the stand sizes custom crates by it).
				local ratio = extent.Y / CrateArt.Height(size)
				if ratio < 0.88 or ratio > 1.12 then
					table.insert(
						wrong,
						("%s is %.2f tall, CrateArt.Height says %.2f"):format(
							crate.Id,
							extent.Y,
							CrateArt.Height(size)
						)
					)
				end
				m:Destroy()
			end
		end
		if #wrong > 0 then
			error(table.concat(wrong, "; "))
		end
	end)

	it("opens the lid on its hinge, moving only the lid", function()
		for _, crate in Config.Crates.List do
			local m = CrateArt.Build(crate)
			-- Placed somewhere turned, like on the stand.
			m:PivotTo(CFrame.new(10, 3, -4) * CFrame.Angles(0, math.rad(30), 0))
			local lid = CrateLook.Lid(m)
			if not lid then
				error(crate.Id .. ": CrateLook.Lid found no lid")
			end
			local primary = m.PrimaryPart
			expect(primary).toBeTruthy()
			local isLid = {}
			for _, p in lid.Parts do
				isLid[p] = true
			end
			expect(isLid[primary]).toBeFalsy()
			local before = {}
			for _, p in parts(m) do
				before[p] = p.CFrame
			end
			local pivot = m:GetPivot()
			local lidPart = m:FindFirstChild("Lid", true)
			local y0 = lidPart.Position.Y
			CrateLook.LidPose(lid, 60)
			expect(m:GetPivot().Position).toBeNear(pivot.Position, 1e-4)
			expect(lidPart.Position.Y).toBeGreaterThan(y0 + 0.05)
			for p, cf in before do
				local moved = (p.Position - cf.Position).Magnitude > 1e-4
				if moved and not isLid[p] then
					error(crate.Id .. "." .. p.Name .. " moved but is not part of the lid")
				end
				if not moved and isLid[p] then
					error(crate.Id .. "." .. p.Name .. " is part of the lid but did not move")
				end
			end
			-- And shut again.
			CrateLook.LidPose(lid, 0)
			for p, cf in before do
				expect(p.Position).toBeNear(cf.Position, 1e-3)
			end
			m:Destroy()
		end
	end)

	it("gives the Monster two googly eyes whose pupils may roll", function()
		local monsters = 0
		for _, crate in Config.Crates.List do
			if CrateLook.Of(crate).Style == "Monster" then
				monsters += 1
				local m = CrateArt.Build(crate)
				local eyes, pupils = {}, {}
				for _, d in m:GetChildren() do
					if d:IsA("BasePart") and d.Name == "Eye" then
						table.insert(eyes, d)
					elseif d:IsA("BasePart") and d.Name == "Pupil" then
						table.insert(pupils, d)
					end
				end
				expect(#eyes).toBe(2)
				expect(#pupils).toBe(2)
				for _, pupil in pupils do
					local r = pupil:GetAttribute("EyeRadius")
					expect(r).toBeA("number")
					expect(r).toBeGreaterThan(0)
					-- At its own eye's centre-front, and inside its outline even rolled to the edge.
					local nearest, best = nil, math.huge
					for _, eye in eyes do
						local dist = (eye.Position - pupil.Position).Magnitude
						if dist < best then
							nearest, best = eye, dist
						end
					end
					local offset = pupil.Position - nearest.Position
					expect(offset.Z).toBeLessThan(0)
					expect(math.abs(offset.X)).toBeLessThan(1e-3)
					expect(math.abs(offset.Y)).toBeLessThan(1e-3)
					expect(r + pupil.Size.X / 2).toBeLessThan(nearest.Size.X / 2)
				end
			end
		end
		expect(monsters).toBeGreaterThan(0)
	end)

	it("builds each style its own way", function()
		local marks = {
			Pumpkin = { "PumpkinRib", "CarvedEye", "Stem", "Leaf" },
			Candy = { "WrapperEnd", "BowLoop", "Stripe" },
			Coffin = { "Ghost", "GhostEye", "CoffinEnd" },
			Tomb = { "Headstone", "Moss" },
			Monster = { "Eye", "Pupil", "Tooth", "Horn" },
			Moon = { "Moon", "MoonShade", "Star" },
			Chest = { "Box", "Strap", "Badge" },
		}
		local seen = {}
		for _, crate in Config.Crates.List do
			local look = CrateLook.Of(crate)
			local style = look.Style
			seen[style] = true
			local m = CrateArt.Build(crate)
			for _, name in marks[style] do
				if named(m, name) == 0 then
					error(("%s (%s) has no %s"):format(crate.Id, style, name))
				end
			end
			-- Lid pieces really are on the lid: the ghost, the bow, the leaves, the teeth...
			for _, name in { "Ghost", "BowLoop", "Leaf", "Tooth", "Headstone", "Stem" } do
				for _, d in m:GetDescendants() do
					local emblem = m:FindFirstChild("Emblem")
					local own = not (emblem and d:IsDescendantOf(emblem))
					if own and d.Name == name and d:IsA("BasePart") then
						expect(d:GetAttribute("LidPiece")).toBe(true)
					end
				end
			end
			-- The look's colours are used, and something glows.
			local hasBody, hasGlow = false, false
			for _, p in parts(m) do
				if p.Color == look.Body then
					hasBody = true
				end
				if p.Material.Name == "Neon" then
					hasGlow = true
				end
			end
			expect(hasBody).toBe(true)
			expect(hasGlow).toBe(true)
		end
		for style in marks do
			expect(seen[style]).toBe(true)
		end
		-- An unknown style falls back to a chest, an unknown emblem to the "?".
		local odd = CrateArt.Build({
			Id = "OddCrate",
			Color = rt.env.Color3.new(1, 0, 0),
			Trim = rt.env.Color3.new(0, 0, 0),
			Glow = rt.env.Color3.new(1, 1, 1),
			Topper = "Nope",
			Look = { Style = "Spaceship", Emblem = "NoSuchHead" },
		})
		expect(named(odd, "Box")).toBe(1)
		expect(named(odd, "MarkTop")).toBe(1)
	end)

	it("puts the Emblem on the front of a Chest", function()
		local emblems = 0
		for _, crate in Config.Crates.List do
			local look = CrateLook.Of(crate)
			if look.Style == "Chest" then
				local m = CrateArt.Build(crate)
				local emblem = m:FindFirstChild("Emblem")
				local box = m:FindFirstChild("Box")
				if look.Emblem == "Gem" or HeadPieces.Has(look.Emblem) then
					if not (emblem and emblem:IsA("Model")) then
						error(crate.Id .. " has no Emblem model for " .. look.Emblem)
					end
					emblems += 1
					expect(#parts(emblem)).toBeGreaterThan(0)
					-- On the front face, no wider than the box, below the lid.
					local cf, extent = emblem:GetBoundingBox()
					expect(cf.Position.Z).toBeLessThan(-box.Size.Z / 2)
					expect(extent.X).toBeLessThan(box.Size.X * 0.6)
					expect(cf.Position.Y).toBeLessThan(box.Size.Y)
					-- Its own parts never pass for the crate's lid.
					for _, p in parts(emblem) do
						expect(p.Name ~= "Lid" and p.Name ~= "Inside").toBe(true)
						expect(p:GetAttribute("LidPiece")).toBeNil()
					end
				else
					expect(named(m, "MarkTop")).toBe(1)
				end
				-- Rainbow rarity crates: every glowing part cycles the rainbow.
				local level = crate.Rarity and Config.Rarity.Levels[crate.Rarity]
				local rainbow = level ~= nil and level.Rainbow == true
				for _, p in parts(m) do
					local headPiece = emblem ~= nil and not rainbow and p:IsDescendantOf(emblem)
					if p.Material.Name == "Neon" and not headPiece then
						expect(p:GetAttribute("Rainbow") == true).toBe(rainbow)
					end
				end
			end
		end
		expect(emblems).toBeGreaterThan(20)
	end)

	it("prefers your own crate model in Preview", function()
		local crate = Config.Crates.List[1]
		local built = CrateArt.Preview(crate)
		expect(built:FindFirstChild("Lid", true)).toBeTruthy()
		local custom =
			rt:create("Model", { Name = crate.Id }, rt:find("ReplicatedStorage.Custom.Props"))
		rt:create("Part", {
			Name = "Look",
			Size = Vector3.new(2, 3, 6),
			CFrame = CFrame.new(0, 1.5, 0),
		}, custom)
		local preview = CrateArt.Preview(crate)
		expect(preview).never.toBe(custom)
		expect(preview:FindFirstChild("Look")).toBeTruthy()
		expect(preview:GetAttribute("CrateId")).toBe(crate.Id)
		local _, extent = preview:GetBoundingBox()
		expect(math.max(extent.X, extent.Y, extent.Z)).toBeNear(CrateArt.Height(), 0.05)
		custom:Destroy()
	end)
end)
