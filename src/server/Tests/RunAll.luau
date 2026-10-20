--!strict
-- Headless test runner. Runs in Lune and Roblox; the entry point finds the
-- specs (Lune: .lune/test.luau scans the file system) and passes them in.
--
-- A spec is a module named *.spec.luau that returns a function registering tests:
--
--   return function(t: RunAll.Context)
--   	t.test("adds", function()
--   		t.equal(1 + 1, 2)
--   	end)
--   end

local Profiler = require("@shared/Util/Profiler")

export type Context = {
	test: (name: string, fn: () -> ()) -> (),
	expect: (condition: any, message: string?) -> (),
	equal: (actual: any, expected: any, message: string?) -> (),
	notEqual: (actual: any, unexpected: any, message: string?) -> (),
	deepEqual: (actual: any, expected: any, message: string?) -> (),
	throws: (fn: () -> (), pattern: string?) -> (),
}

export type SpecFn = (t: Context) -> ()

-- `module` is whatever the spec module returned; RunAll checks it is a SpecFn.
export type Spec = { name: string, module: any }

export type Summary = {
	specs: number,
	passed: number,
	failed: number,
	failures: { string },
	seconds: number,
}

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function prefix(message: string?): string
	return if message then message .. ": " else ""
end

-- Returns nil when equal, otherwise a description of the first difference.
local function diff(actual: any, expected: any, path: string): string?
	if type(actual) ~= "table" or type(expected) ~= "table" then
		if actual == expected then
			return nil
		end
		return `{path}: expected {show(expected)}, got {show(actual)}`
	end
	for key, value in expected do
		local d = diff(actual[key], value, `{path}[{show(key)}]`)
		if d then
			return d
		end
	end
	for key in actual do
		if expected[key] == nil then
			return `{path}[{show(key)}]: unexpected value {show(actual[key])}`
		end
	end
	return nil
end

-- Level 3 points the error at the spec line that called the assertion.
local function fail(message: string): never
	error(message, 3)
end

local function newContext(register: (name: string, fn: () -> ()) -> ()): Context
	return {
		test = register,
		expect = function(condition: any, message: string?)
			if not condition then
				fail(message or "expectation failed")
			end
		end,
		equal = function(actual: any, expected: any, message: string?)
			if actual ~= expected then
				fail(`{prefix(message)}expected {show(expected)}, got {show(actual)}`)
			end
		end,
		notEqual = function(actual: any, unexpected: any, message: string?)
			if actual == unexpected then
				fail(`{prefix(message)}expected anything but {show(unexpected)}`)
			end
		end,
		deepEqual = function(actual: any, expected: any, message: string?)
			local d = diff(actual, expected, "value")
			if d then
				fail(prefix(message) .. d)
			end
		end,
		throws = function(fn: () -> (), pattern: string?)
			local ok, err = pcall(fn)
			if ok then
				fail("expected an error, none was thrown")
			end
			if pattern and not string.find(tostring(err), pattern) then
				fail(`expected an error matching {show(pattern)}, got {show(tostring(err))}`)
			end
		end,
	}
end

local RunAll = {}

-- Runs the specs in the given order and prints a report. Never throws.
function RunAll.run(specs: { Spec }): Summary
	local started = Profiler.now()
	local summary: Summary = { specs = #specs, passed = 0, failed = 0, failures = {}, seconds = 0 }

	local function recordFailure(specName: string, label: string, message: string)
		summary.failed += 1
		table.insert(summary.failures, `{specName} > {label}: {message}`)
		print(`  FAIL {label}`)
		print(`       {message}`)
	end

	for _, spec in specs do
		print(spec.name)

		local tests: { { name: string, fn: () -> () } } = {}
		local ctx = newContext(function(name: string, fn: () -> ())
			table.insert(tests, { name = name, fn = fn })
		end)

		if type(spec.module) ~= "function" then
			recordFailure(spec.name, "(load)", `spec must return a function, got {typeof(spec.module)}`)
			continue
		end
		local ok, err = pcall(spec.module, ctx)
		if not ok then
			recordFailure(spec.name, "(load)", tostring(err))
			continue
		end
		if #tests == 0 then
			recordFailure(spec.name, "(load)", "spec registered no tests")
			continue
		end

		for _, test in tests do
			local passed, testErr = pcall(test.fn)
			if passed then
				summary.passed += 1
				print(`  PASS {test.name}`)
			else
				recordFailure(spec.name, test.name, tostring(testErr))
			end
		end
	end

	summary.seconds = Profiler.now() - started
	print(
		string.format(
			"\n%d spec(s): %d passed, %d failed (%.1f ms)",
			summary.specs,
			summary.passed,
			summary.failed,
			summary.seconds * 1000
		)
	)
	return summary
end

return RunAll
