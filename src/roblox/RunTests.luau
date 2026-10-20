--!strict
-- In-Studio entry for the headless tests (STUDIO_HANDOFF step 2). Finds every
-- *.spec ModuleScript under ServerScriptService.Tests and passes them to
-- RunAll, like .lune/test.luau does from the file system. From execute_luau
-- or the command bar:
--
--   require(game.ServerScriptService.Entry.RunTests).run()          -- all specs
--   require(game.ServerScriptService.Entry.RunTests).run("Fog")     -- path contains "Fog"
--
-- RunAll never yields, and the full suite takes ~30 s in Studio, so each test
-- yields one frame first: Studio stays responsive and no script timeout fires.
-- An execute_luau call gives up long before that, so from MCP use start(),
-- which returns at once, then poll status() until it returns a summary:
--
--   require(game.ServerScriptService.Entry.RunTests).start()
--   require(game.ServerScriptService.Entry.RunTests).status()      -- "running" or Summary

local ServerScriptService = game:GetService("ServerScriptService")

local SPEC_SUFFIX = ".spec"

local RunTests = {}

export type Summary = {
	specs: number,
	passed: number,
	failed: number,
	failures: { string },
	seconds: number,
}

-- Sorted by name at each level, so specs run in the same order as in Lune.
local function collect(parent: Instance, rel: string, out: { { path: string, module: ModuleScript } })
	local children = parent:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		local path = if rel == "" then child.Name else `{rel}/{child.Name}`
		if child:IsA("ModuleScript") and string.sub(child.Name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
			table.insert(out, { path = path, module = child })
		end
		collect(child, path, out)
	end
end

-- Wraps a spec so every registered test yields once before it runs.
local function yielding(specFn: any): any
	if type(specFn) ~= "function" then
		return specFn
	end
	return function(t: any)
		local proxy = setmetatable({
			test = function(name: string, fn: () -> ())
				t.test(name, function()
					task.wait()
					fn()
				end)
			end,
		}, { __index = t })
		return specFn(proxy)
	end
end

function RunTests.run(filter: string?): Summary
	local tests = ServerScriptService:FindFirstChild("Tests")
	assert(tests, "ServerScriptService.Tests not found: is Rojo syncing build.project.json?")
	local runAllModule = tests:FindFirstChild("RunAll")
	assert(runAllModule and runAllModule:IsA("ModuleScript"), "ServerScriptService.Tests.RunAll not found")
	local RunAll = (require :: any)(runAllModule)

	local found = {}
	collect(tests, "", found)

	local specs = {}
	for _, entry in found do
		if filter == nil or string.find(entry.path, filter, 1, true) then
			local ok, result = pcall(require, entry.module)
			table.insert(specs, {
				name = entry.path,
				module = if ok then yielding(result) else function()
					error(`failed to load: {result}`, 0)
				end,
			})
		end
	end

	if #specs == 0 then
		print(if filter then `no specs match "{filter}"` else "no *.spec ModuleScripts under ServerScriptService.Tests")
	end
	return RunAll.run(specs)
end

-- Last background run: nil before the first, "running" while one is going.
local last: Summary | "running" | nil = nil

function RunTests.start(filter: string?): string
	if last == "running" then
		return "already running"
	end
	last = "running"
	task.spawn(function()
		local ok, result = pcall(RunTests.run, filter)
		last = if ok
			then result
			else { specs = 0, passed = 0, failed = 1, failures = { `(entry) {result}` }, seconds = 0 }
	end)
	return "started"
end

function RunTests.status(): Summary | "running" | nil
	return last
end

return RunTests
