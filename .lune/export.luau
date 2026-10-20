--!strict
-- Records a match for the match viewer (tools/viewer/index.html).
--   lune run export <scene> [--player N] [--seed S] [--map M] [--ticks T] [--every K] [--out file]
--
-- <scene>: ai | matchup:<order unit>:<chaos unit>[:close|long] | a Sim scenario
-- (see src/server/Tests/Support/Scenes.luau). Without --player the file is
-- the spectator view (server truth); with --player N it is player N's
-- fog-filtered view rebuilt from the real NetOut packets.
-- Writes debug_out/match_<scene>_<view>.json unless --out is given.
-- Examples:
--   lune run export ai
--   lune run export ai --player 1
--   lune run export matchup:ord_absolution:chs_ravager:long

local fs = require("@lune/fs")
local process = require("@lune/process")

local MatchExport = require("../src/server/Tests/Support/MatchExport")
local Scenes = require("../src/server/Tests/Support/Scenes")

local args = process.args
local scene = args[1]
if scene == nil or string.sub(scene, 1, 2) == "--" then
	print("usage: lune run export <scene> [--player N] [--seed S] [--map M] [--ticks T] [--every K] [--out file]")
	print("  scenes: ai | matchup:<order unit>:<chaos unit>[:close|long] | a Sim scenario (duel_test, ew_test, match_test, ...)")
	process.exit(1)
end
local opts: { [string]: string } = {}
local i = 2
while i <= #args do
	local key = string.match(args[i], "^%-%-(%w+)$")
	if key == nil or args[i + 1] == nil then
		print(`bad argument "{args[i]}"`)
		process.exit(1)
	end
	opts[key :: string] = args[i + 1]
	i += 2
end

local seed = tonumber(opts.seed) or 1
local t0 = os.clock()
local s = Scenes.byName(scene :: string, seed, opts.map)
local player = tonumber(opts.player)
local data = MatchExport.record(s, scene :: string, {
	view = if player then "player" else "spectator",
	player = player,
	every = tonumber(opts.every),
	maxTicks = tonumber(opts.ticks),
})
local json = MatchExport.encode(data)
local out = opts.out
if out == nil then
	if not fs.isDir("debug_out") then
		fs.writeDir("debug_out")
	end
	local safe = string.gsub(scene :: string, "[^%w_%-]", "_")
	out = `debug_out/match_{safe}_{if player then "p" .. player else "spectator"}.json`
end
fs.writeFile(out :: string, json)
print(string.format(
	"wrote %s: %d frames, %d ticks (%.1f min)%s, %.1f MB, %.1f s",
	out :: string,
	#data.frames,
	data.meta.endTick,
	data.meta.endTick / 900,
	if data.meta.over then `, winner ally {data.meta.winner}` else "",
	#json / 1e6,
	os.clock() - t0
))
print("open tools/viewer/index.html and pick the file")
