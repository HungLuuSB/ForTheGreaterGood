--!strict
-- Live sync for Studio: keeps build/serve/src a converted copy of src for
-- `rojo serve serve.project.json`. From the project root:
--   lune run serve
--
-- Replaces `darklua process --watch` and `rojo sourcemap --watch`:
--   * polls src (modified times), so files saved by rename are seen too;
--   * a changed file is converted on its own (darklua, .darklua.json);
--   * an added or removed file regenerates sourcemap.json, then converts
--     everything, so requires of the new module resolve;
--   * it only writes files, and removes the output of a deleted source file.
--     It never deletes a directory: Rojo's serve crashes when a directory it
--     watches disappears.
--
-- Nothing else may wipe build/serve while this and `rojo serve` run.
-- `lune run build` uses build/ci and is safe alongside.

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

local SRC = "src"
local OUT = "build/serve/src"
local POLL_SECONDS = 0.25
-- A file missing for this many polls in a row counts as deleted. Some editors
-- save by removing and renaming, so one missing poll is not a deletion.
local MISSING_POLLS = 3
-- Above this many changed files in one poll (a branch switch), one full pass
-- is quicker than a darklua call per file.
local FULL_PASS_AT = 20
-- Every folder serve.project.json maps; Rojo needs them to exist.
local MAPPED = { "shared", "server/Sim", "server/Tests", "client", "roblox" }

if not fs.isFile("serve.project.json") then
	print('serve.project.json not found: run "lune run serve" from the project root')
	process.exit(1)
end

local function stamp(): string
	return os.date("%H:%M:%S")
end

local function exec(program: string, args: { string }): boolean
	local result = process.exec(program, args, { shell = true })
	if not result.ok then
		print(`[{stamp()}] {program} {table.concat(args, " ")} failed (exit code {result.code})`)
		local err = if result.stderr ~= "" then result.stderr else result.stdout
		print(err)
	end
	return result.ok
end

local function isLuau(path: string): boolean
	return string.sub(path, -5) == ".luau" or string.sub(path, -4) == ".lua"
end

-- Relative path -> modified time (ms) of every file under `root`.
local function scan(root: string): { [string]: number }
	local out: { [string]: number } = {}
	local function walk(dir: string, rel: string)
		local ok, names = pcall(fs.readDir, dir)
		if not ok then
			return
		end
		for _, name in names do
			local path = `{dir}/{name}`
			local relPath = if rel == "" then name else `{rel}/{name}`
			local okMeta, meta = pcall(fs.metadata, path)
			if not okMeta or not meta.exists then
				continue
			end
			if meta.kind == "dir" then
				walk(path, relPath)
			elseif meta.kind == "file" then
				out[relPath] = if meta.modifiedAt then meta.modifiedAt.unixTimestampMillis else 0
			end
		end
	end
	walk(root, "")
	return out
end

local function parentOf(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local function ensureDir(dir: string)
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
end

local function sourcemap(): boolean
	return exec("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
end

local function fullPass(): boolean
	return exec("darklua", { "process", SRC, OUT })
end

local function convert(rel: string): boolean
	local out = `{OUT}/{rel}`
	local parent = parentOf(out)
	if parent then
		ensureDir(parent)
	end
	if isLuau(rel) then
		return exec("darklua", { "process", `{SRC}/{rel}`, out })
	end
	local ok, err = pcall(function()
		fs.writeFile(out, fs.readFile(`{SRC}/{rel}`))
	end)
	if not ok then
		print(`[{stamp()}] copy {rel} failed: {err}`)
	end
	return ok
end

local function removeOutput(rel: string)
	local out = `{OUT}/{rel}`
	if fs.isFile(out) then
		pcall(fs.removeFile, out)
	end
end

-- Start: sourcemap, mapped folders, one full pass, then drop output files
-- whose source is gone (files only, never folders).
for _, dir in MAPPED do
	ensureDir(`{OUT}/{dir}`)
end
if not (sourcemap() and fullPass()) then
	process.exit(1)
end
local known = scan(SRC)
local stale = 0
for rel in scan(OUT) do
	if known[rel] == nil then
		removeOutput(rel)
		stale += 1
	end
end
local count = 0
for _ in known do
	count += 1
end
print(`[{stamp()}] {count} files synced to {OUT}` .. if stale > 0 then `, {stale} stale output files removed` else "")
print("Watching src. Keep `rojo serve serve.project.json` running in another terminal. Ctrl+C stops.")

local missing: { [string]: number } = {}

while true do
	task.wait(POLL_SECONDS)
	local now = scan(SRC)

	local changed: { string } = {}
	local added, removed = 0, 0
	for rel, modified in now do
		local before = known[rel]
		if before == nil then
			added += 1
			table.insert(changed, rel)
		elseif before ~= modified then
			table.insert(changed, rel)
		end
		missing[rel] = nil
	end
	local gone: { string } = {}
	for rel in known do
		if now[rel] == nil then
			missing[rel] = (missing[rel] or 0) + 1
			if missing[rel] >= MISSING_POLLS then
				table.insert(gone, rel)
			else
				-- not deleted yet: keep it known until it comes back or times out
				now[rel] = known[rel]
			end
		end
	end
	removed = #gone

	if #changed == 0 and removed == 0 then
		continue
	end
	table.sort(changed)

	for _, rel in gone do
		missing[rel] = nil
		removeOutput(rel)
	end

	local ok = true
	if added > 0 or removed > 0 or #changed > FULL_PASS_AT then
		ok = sourcemap() and fullPass()
	else
		for _, rel in changed do
			ok = convert(rel) and ok
		end
	end

	local parts: { string } = {}
	if #changed > 0 then
		table.insert(parts, if #changed <= 3 then table.concat(changed, ", ") else `{#changed} files`)
	end
	if removed > 0 then
		table.insert(parts, `removed {table.concat(gone, ", ")}`)
	end
	print(`[{stamp()}] {if ok then "synced" else "FAILED"}: {table.concat(parts, "; ")}`)

	known = now
end
