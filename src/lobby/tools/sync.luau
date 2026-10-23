--!strict
-- The lobby place's build and live sync (L-1). From the project root:
--   lune run src/lobby/tools/sync build   one pass into build/lobby, then
--                                         build/lobby/place.rbxl and its check
--   lune run src/lobby/tools/sync serve   the same pass, then watches the
--                                         sources; keep `rojo serve
--                                         lobby.project.json` (port 34874)
--                                         running in another terminal
--
-- lobby.project.json maps converted files under build/lobby/src. Each
-- mapped path's source is the same path without the "build/lobby/" prefix
-- (src/shared, src/lobby/..., and the client's UI kit read-only). Requires
-- are converted by darklua as in the main build (DECISIONS D84), against a
-- sourcemap of the same tree read from the sources. Only build/lobby is
-- written; the main game's build/serve and build/ci are never touched.
-- Like .lune/serve.luau, serve never deletes a directory (Rojo's serve
-- crashes when a watched one disappears) and removes only the output of a
-- deleted source file.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local PROJECT = "lobby.project.json"
local OUT = "build/lobby"
local PREFIX = OUT .. "/"
local POLL_SECONDS = 0.25
local MISSING_POLLS = 3

if not fs.isFile(PROJECT) then
	print(`{PROJECT} not found: run from the project root`)
	process.exit(1)
end

local function stamp(): string
	return os.date("%H:%M:%S")
end

local function exec(program: string, args: { string }, inherit: boolean?): boolean
	local result = process.exec(program, args, { shell = true, stdio = if inherit then "inherit" else nil } :: any)
	if not result.ok then
		print(`[{stamp()}] {program} {table.concat(args, " ")} failed (exit code {result.code})`)
		if not inherit then
			print(if result.stderr ~= "" then result.stderr else result.stdout)
		end
	end
	return result.ok
end

local function parentOf(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local function ensureDir(dir: string)
	if fs.isDir(dir) then
		return
	end
	local parent = parentOf(dir)
	if parent then
		ensureDir(parent)
	end
	fs.writeDir(dir)
end

-- The mapped sources: { source path, output path } for every "$path".
local mapped: { { string } } = {}
local function collect(node: any)
	for key, value in node do
		if key == "$path" then
			local out = value :: string
			if string.sub(out, 1, #PREFIX) ~= PREFIX then
				print(`{PROJECT}: "{out}" is not under {OUT}`)
				process.exit(1)
			end
			table.insert(mapped, { string.sub(out, #PREFIX + 1), out })
		elseif type(value) == "table" then
			collect(value)
		end
	end
end
local project = serde.decode("json", fs.readFile(PROJECT))
collect(project.tree)

-- The same tree read from the sources, for the sourcemap darklua converts
-- against. It lives in build/lobby, so its paths climb two folders.
local function writeSourceProject()
	local function rewrite(node: any): any
		local copy = {}
		for key, value in node do
			if key == "$path" then
				copy[key] = "../../" .. string.sub(value, #PREFIX + 1)
			elseif type(value) == "table" then
				copy[key] = rewrite(value)
			else
				copy[key] = value
			end
		end
		return copy
	end
	ensureDir(OUT)
	fs.writeFile(`{OUT}/source.project.json`, serde.encode("json", { name = project.name, tree = rewrite(project.tree) }, true))
	fs.writeFile(
		`{OUT}/darklua.json`,
		serde.encode("json", {
			process = {
				{
					rule = "convert_require",
					current = { name = "path", sources = { ["@shared"] = "../../src/shared", ["@client"] = "../../src/client" } },
					target = { name = "roblox", rojo_sourcemap = "./sourcemap.json", indexing_style = "find_first_child" },
				},
			},
		}, true)
	)
end

local function sourcemap(): boolean
	writeSourceProject()
	return exec("rojo", { "sourcemap", `{OUT}/source.project.json`, "-o", `{OUT}/sourcemap.json` })
end

local function isLuau(path: string): boolean
	return string.sub(path, -5) == ".luau" or string.sub(path, -4) == ".lua"
end

local function convertFile(src: string, out: string): boolean
	local parent = parentOf(out)
	if parent then
		ensureDir(parent)
	end
	if isLuau(src) then
		return exec("darklua", { "process", src, out, "--config", `{OUT}/darklua.json` })
	end
	local ok, err = pcall(function()
		fs.writeFile(out, fs.readFile(src))
	end)
	if not ok then
		print(`[{stamp()}] copy {src} failed: {err}`)
	end
	return ok
end

-- One full pass over every mapped source.
local function fullPass(): boolean
	local ok = true
	for _, m in mapped do
		if fs.isDir(m[1]) then
			ensureDir(m[2])
			ok = exec("darklua", { "process", m[1], m[2], "--config", `{OUT}/darklua.json` }) and ok
		elseif fs.isFile(m[1]) then
			ok = convertFile(m[1], m[2]) and ok
		else
			print(`[{stamp()}] {m[1]} (mapped in {PROJECT}) doesn't exist`)
			ok = false
		end
	end
	return ok
end

-- Every source file -> { output path, modified time }.
local function scan(): { [string]: { out: string, at: number } }
	local files: { [string]: { out: string, at: number } } = {}
	local function walk(src: string, out: string)
		local okMeta, meta = pcall(fs.metadata, src)
		if not okMeta or not meta.exists then
			return
		end
		if meta.kind == "dir" then
			local ok, names = pcall(fs.readDir, src)
			if ok then
				for _, name in names do
					walk(`{src}/{name}`, `{out}/{name}`)
				end
			end
		elseif meta.kind == "file" then
			files[src] = { out = out, at = if meta.modifiedAt then meta.modifiedAt.unixTimestampMillis else 0 }
		end
	end
	for _, m in mapped do
		walk(m[1], m[2])
	end
	return files
end

local mode = process.args[1]
if mode ~= "build" and mode ~= "serve" then
	print("usage: lune run src/lobby/tools/sync build | serve")
	process.exit(1)
end

if not (sourcemap() and fullPass()) then
	process.exit(1)
end

if mode == "build" then
	-- a place file of the converted tree, checked like the main build
	if not exec("rojo", { "build", PROJECT, "-o", `{OUT}/place.rbxl` }, true) then
		process.exit(1)
	end
	if not exec("lune", { "run", "check_build", `{OUT}/place.rbxl` }, true) then
		process.exit(1)
	end
	process.exit(0)
end

-- serve: drop outputs whose source is gone, then watch
local known = scan()
local count = 0
for _ in known do
	count += 1
end
print(`[{stamp()}] {count} files synced to {OUT}/src`)
print(`Watching. Keep \`rojo serve {PROJECT}\` (port 34874) running in another terminal. Ctrl+C stops.`)

local missing: { [string]: number } = {}
while true do
	task.wait(POLL_SECONDS)
	local now = scan()
	local changed: { string } = {}
	local added = false
	for src, f in now do
		local before = known[src]
		missing[src] = nil
		if before == nil then
			added = true
		elseif before.at ~= f.at then
			table.insert(changed, src)
		end
	end
	local removed: { string } = {}
	for src, f in known do
		if now[src] == nil then
			missing[src] = (missing[src] or 0) + 1
			if missing[src] >= MISSING_POLLS then
				table.insert(removed, src)
			else
				now[src] = f -- not gone yet: maybe saved by rename
			end
		end
	end
	for _, src in removed do
		missing[src] = nil
		local out = known[src].out
		if fs.isFile(out) then
			pcall(fs.removeFile, out)
		end
		print(`[{stamp()}] removed {out}`)
	end
	if added or #removed > 0 then
		-- requires of a new module resolve only with a new sourcemap
		if sourcemap() and fullPass() then
			print(`[{stamp()}] files added or removed: sourcemap and full pass done`)
		end
	else
		for _, src in changed do
			if convertFile(src, now[src].out) then
				print(`[{stamp()}] {src}`)
			end
		end
	end
	known = now
end
