--!strict
-- Parallel report runs (S-99, next.md item 9): a report script plays its
-- independent matches in N Lune processes at once and gathers the results.
--   Parallel.args(argv)        positional arguments and --name=value flags
--   Parallel.worker(flags)     this process's share (k, N) when it is a
--                              worker (--worker=k/N), else nil
--   Parallel.run(script, argv, jobs)
--                              starts `jobs` workers of `.lune/<script>`
--                              with the same arguments and gathers the
--                              lines they print as `RESULT <index> <field> ...`
--                              into { [index] = { field, ... } }. Errors if a
--                              worker fails.
-- Workers take every N-th item, so a slow map spreads over all of them.

local process = require("@lune/process")
local task = require("@lune/task")

local Parallel = {}

function Parallel.args(argv: { string }): ({ string }, { [string]: string })
	local positional, flags = {}, {}
	for _, a in argv do
		local name, value = string.match(a, "^%-%-([%w_]+)=(.*)$")
		if name then
			flags[name] = value
		else
			table.insert(positional, a)
		end
	end
	return positional, flags
end

function Parallel.worker(flags: { [string]: string }): (number?, number)
	local k, n = string.match(flags.worker or "", "^(%d+)/(%d+)$")
	if k and n then
		return tonumber(k) :: number, tonumber(n) :: number
	end
	return nil, 1
end

function Parallel.run(script: string, argv: { string }, jobs: number): { [number]: { string } }
	local base = {}
	for _, a in argv do
		if not string.match(a, "^%-%-jobs=") then
			table.insert(base, a)
		end
	end
	local results: { [number]: { string } } = {}
	local done, failure = 0, nil :: string?
	for k = 0, jobs - 1 do
		task.spawn(function()
			local args = { "run", script }
			table.move(base, 1, #base, #args + 1, args)
			table.insert(args, `--worker={k}/{jobs}`)
			local r = process.exec("lune", args)
			if not r.ok then
				failure = `worker {k}/{jobs} failed: {r.stderr}`
			else
				for line in string.gmatch(r.stdout, "[^\n]+") do
					local fields = string.split(string.gsub(line, "\r", ""), " ")
					if fields[1] == "RESULT" then
						local index = tonumber(fields[2]) :: number
						results[index] = table.move(fields, 3, #fields, 1, {})
					end
				end
			end
			done += 1
		end)
	end
	while done < jobs do
		task.wait(0.2)
	end
	if failure then
		error(failure)
	end
	return results
end

return Parallel
