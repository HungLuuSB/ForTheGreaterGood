--!strict
-- The lobby's Lune specs (L-7). From the project root:
--   lune run src/lobby/tools/test            every *.spec.luau under src/lobby/tests
--   lune run src/lobby/tools/test <filter>   only specs whose path contains <filter>
-- Same runner as `lune run test` (src/server/Tests/RunAll, used read-only).
-- The specs aren't mapped in lobby.project.json, so they never sync into Studio.
-- Exits with code 1 if anything failed.
local fs = require("@lune/fs")
local process = require("@lune/process")

local RunAll = require("../../server/Tests/RunAll")

local TESTS_DIR = "src/lobby/tests"
local SPEC_SUFFIX = ".spec.luau"

if not fs.isDir(TESTS_DIR) then
	print(`{TESTS_DIR} not found: run from the project root`)
	process.exit(1)
end

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
		local ok, result = pcall(function()
			return (require :: any)(`../tests/{modulePath}`)
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
