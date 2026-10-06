--[[
	Test runner: lune run tests/run [-- options] (from new-game/)

	  lune run tests/run                    every tests/specs/*.spec.luau
	  lune run tests/run -- builders        only spec files whose name contains "builders"
	  lune run tests/run -- --verbose       also print the game's print() output
	  lune run tests/run -- --quiet         hide the game's warnings too

	A test fails when it throws, or when game code it ran threw inside a task thread
	(task.spawn, an event handler, a Script). Exits with code 1 when anything failed.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("./harness/Test")
local Runtime = require("./harness/Runtime")

local filters = {}
for _, arg in process.args do
	if arg == "--" then
		continue -- Lune 0.10 passes the "--" separator through
	elseif arg == "--verbose" or arg == "-v" then
		Runtime.defaults.echo = "all"
	elseif arg == "--quiet" or arg == "-q" then
		Runtime.defaults.echo = "none"
	else
		table.insert(filters, arg)
	end
end

local specDir = "tests/specs"
if not fs.isDir(specDir) and fs.isDir("new-game/tests/specs") then
	specDir = "new-game/tests/specs"
end

local files = {}
for _, name in fs.readDir(specDir) do
	if name:match("%.spec%.luau$") then
		local matches = #filters == 0
		for _, f in filters do
			if name:find(f, 1, true) then
				matches = true
			end
		end
		if matches then
			table.insert(files, name)
		end
	end
end
table.sort(files)

local passed, failed, skipped = 0, 0, 0
local failures: { string } = {}
local started = os.clock()

-- Error text with Lune's noise removed: no "runtime error:" prefix, `[string "x"]` shown as
-- x, and traceback lines from the harness itself dropped so game code and specs stand out.
local function message(err: any): string
	local text = tostring(err):gsub("^runtime error: ", "")
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		line = line:gsub('%[string "([^"]+)"%]', "%1")
		local internal = line:find("tests/harness/", 1, true)
			or line:find("tests/run", 1, true)
			or line:find("__mlua", 1, true)
			or line:match("^%s*%[C%]")
			or line:match("^%s*require:")
		if #out == 0 or not internal then
			table.insert(out, line)
		end
	end
	while #out > 0 and out[#out]:match("^%s*$") do
		table.remove(out)
	end
	return table.concat(out, "\n")
end

for _, file in files do
	print(("%s"):format(file))
	Test.reset()
	local module = "./specs/" .. file:gsub("%.luau$", "")
	-- (Lune's require yields, so it can't run under xpcall with a message handler; the
	-- closure keeps the path relative to this file.)
	local ok, err = pcall(function()
		return require(module)
	end)
	if not ok then
		failed += 1
		print("  FAIL  (spec file failed to load)")
		print("        " .. message(err):gsub("\n", "\n        "))
		table.insert(failures, file .. ": failed to load")
		continue
	end
	local loadErrors = Runtime.takeUncaught()
	if #loadErrors > 0 then
		failed += 1
		print("  FAIL  (game code threw inside a task thread while the spec file loaded)")
		print("        " .. message(loadErrors[1]):gsub("\n", "\n        "))
		table.insert(failures, file .. ": task error while loading")
	end
	for _, case in Test.cases() do
		if case.skip then
			skipped += 1
			print(("  skip  %s"):format(case.name))
			continue
		end
		local notes = {}
		Test._setNotes(notes)
		local t0 = os.clock()
		local good, problem = xpcall(function()
			for _, fn in case.before do
				fn()
			end
			case.fn()
			for _, fn in case.after do
				fn()
			end
		end, function(e)
			local text = tostring(e)
			if not text:find("stack traceback", 1, true) then
				text = debug.traceback(text, 2)
			end
			return message(text)
		end)
		Test._setNotes(nil)
		local uncaught = Runtime.takeUncaught()
		if good and #uncaught > 0 then
			good = false
			-- The same error from a loop is listed once, with a count.
			local texts, counts = {}, {}
			for _, e in uncaught do
				local text = message(e)
				if counts[text] then
					counts[text] += 1
				else
					counts[text] = 1
					table.insert(texts, text)
				end
			end
			for i, text in texts do
				if counts[text] > 1 then
					texts[i] = ("(%d times) %s"):format(counts[text], text)
				end
			end
			problem = ("game code threw inside a task thread:\n%s"):format(
				table.concat(texts, "\n")
			)
		end
		local ms = (os.clock() - t0) * 1000
		if good then
			passed += 1
			print(("  ok    %s (%.0f ms)"):format(case.name, ms))
		else
			failed += 1
			print(("  FAIL  %s (%.0f ms)"):format(case.name, ms))
			print("        " .. tostring(problem):gsub("\n", "\n        "))
			table.insert(failures, file .. ": " .. case.name)
		end
		for _, note in notes do
			print("        - " .. note)
		end
	end
end

print("")
if #failures > 0 then
	print("Failed:")
	for _, f in failures do
		print("  " .. f)
	end
	print("")
end
print(
	("%d passed, %d failed, %d skipped (%d spec files) in %.1f s"):format(
		passed,
		failed,
		skipped,
		#files,
		os.clock() - started
	)
)
if #files == 0 then
	print("no spec files matched")
	process.exit(1)
end
process.exit(if failed > 0 then 1 else 0)
