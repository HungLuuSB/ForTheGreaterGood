--!strict
-- Lune entry for the headless tests. From the project root:
--   lune run test            runs every *.spec.luau under src/server/Tests
--   lune run test <filter>   runs only specs whose path contains <filter>
-- Exits with code 1 if anything failed.

local fs = require("@lune/fs")
local process = require("@lune/process")

local RunAll = require("../src/server/Tests/RunAll")

local TESTS_DIR = "src/server/Tests"
local SPEC_SUFFIX = ".spec.luau"

if not fs.isDir(TESTS_DIR) then
	print(`{TESTS_DIR} not found: run "lune run test" from the project root`)
	process.exit(1)
end

-- Sorted, so specs always run in the same order.
local function collect(dir: string, rel: string, out: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		local relPath = if rel == "" then name else `{rel}/{name}`
		if fs.isDir(path) then
			collect(path, relPath, out)
		elseif string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
			table.insert(out, relPath)
		end
	end
end

local filter = process.args[1]
local paths: { string } = {}
collect(TESTS_DIR, "", paths)

local specs: { RunAll.Spec } = {}
for _, relPath in paths do
	if filter == nil or string.find(relPath, filter, 1, true) then
		local modulePath = string.sub(relPath, 1, -#".luau" - 1)
		-- Wrapped in a closure: require resolves relative to its calling script.
		local ok, result = pcall(function()
			return (require :: any)(`../{TESTS_DIR}/{modulePath}`)
		end)
		table.insert(specs, {
			name = modulePath,
			module = if ok then result else function()
				error(`failed to load: {result}`, 0)
			end,
		})
	end
end

if #specs == 0 then
	print(if filter then `no specs match "{filter}"` else `no *{SPEC_SUFFIX} files in {TESTS_DIR}`)
	process.exit(1)
end

local summary = RunAll.run(specs)
process.exit(if summary.failed > 0 then 1 else 0)
