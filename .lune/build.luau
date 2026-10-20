--!strict
-- Builds a Roblox place from src with requires converted for Roblox
-- (STUDIO_HANDOFF step 1), then checks it. From the project root:
--   lune run build
--
--   1. rojo sourcemap default.project.json -o sourcemap.json
--   2. darklua process src build/ci/src   (.darklua.json: convert_require
--      turns "@shared/..." and relative string requires into Instance paths
--      using the sourcemap)
--   3. rojo build build.project.json -o build/ci/place.rbxl   (the same tree,
--      read from build/ci/src)
--   4. lune run check_build   (every script compiles, every require
--      resolves to a ModuleScript in the place)
-- Exits with code 1 if any step fails. Tools come from rokit.toml.
--
-- Only build/ci is wiped. The live sync (lune run serve + rojo serve
-- serve.project.json) uses build/serve, so this is safe while it runs.

local fs = require("@lune/fs")
local process = require("@lune/process")

local function run(program: string, args: { string })
	print(`> {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit", shell = true })
	if not result.ok then
		print(`{program} failed (exit code {result.code})`)
		process.exit(1)
	end
end

if not fs.isFile("default.project.json") then
	print('default.project.json not found: run "lune run build" from the project root')
	process.exit(1)
end

run("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
local OUT = "build/ci"
if fs.isDir(OUT) then
	fs.removeDir(OUT)
end
run("darklua", { "process", "src", `{OUT}/src` })
-- empty source folders produce no output folder; Rojo needs every mapped path
for _, dir in { "shared", "server/Sim", "server/Tests", "client", "roblox" } do
	if not fs.isDir(`{OUT}/src/{dir}`) then
		fs.writeDir(`{OUT}/src/{dir}`)
	end
end
run("rojo", { "build", "build.project.json", "-o", `{OUT}/place.rbxl` })
run("lune", { "run", "check_build", `{OUT}/place.rbxl` })
