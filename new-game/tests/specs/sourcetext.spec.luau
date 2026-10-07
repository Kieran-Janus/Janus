-- Source text: every Luau file is clean UTF-8 text. A file saved with the wrong encoding turns
-- symbols like "▼" or "•" into long runs of junk such as "Ã¢â‚¬" (it happened once, after
-- several edits, and the Shop's theme menu filled with garbage), so this looks for that.

local fs = require("@lune/fs")

local T = require("../harness/Test")

local describe, it, expect = T.describe, T.it, T.expect

local root = if fs.isDir("src") then "src" else "new-game/src"

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

describe("Source text", function()
	it("has no garbled characters from a wrong text encoding", function()
		local files = luauFiles(root, {})
		expect(#files).toBeGreaterThan(50)
		for _, path in files do
			local text = fs.readFile(path)
			-- "Ã" followed by another non-ASCII byte: UTF-8 read as Windows-1252 and saved again.
			local bad = text:find("\195[\128-\191][\128-\255]")
			if bad then
				local lineNo = select(2, text:sub(1, bad):gsub("\n", "")) + 1
				error(("%s:%d has garbled text (wrong encoding)"):format(path, lineNo))
			end
			expect(utf8.len(text)).toBeTruthy() -- valid UTF-8
		end
	end)
end)
