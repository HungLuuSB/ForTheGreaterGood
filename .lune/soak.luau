--!strict
-- 40-minute AI-vs-AI soak test (S-8):
--   lune run soak [seed] [minutes]
-- Order AI vs Chaos AI on skirmish:256, Annihilation, for up to `minutes`
-- of game time (default 40) or until the match ends. Reports peak and p99
-- tick times, the slowest systems, unit counts and Lua heap size over time,
-- then replays the command log and checks the final hash. Fails (exit 1)
-- when a tick errors, the peak tick exceeds the 66.7 ms budget, the heap
-- keeps growing after the opening (a leak), or the replay differs.
-- A spectator (S-18) watches the whole match; its stream is saved as a
-- player replay, debug_out/soak.ftgp, and its size reported.
-- Results go to debug_out/soak.txt; copy the summary into
-- docs/progress/sim.md.

local fs = require("@lune/fs")
local process = require("@lune/process")

local NetOut = require("../src/server/Sim/NetOut")
local PlayerReplay = require("../src/shared/Net/PlayerReplay")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")
local Skirmish = require("../src/server/Sim/AI/Skirmish")
local Replay = require("../src/server/Sim/Replay")

local SEED = tonumber(process.args[1]) or 2 -- seed 2 plays the full 40 minutes (S-25 AI; seeds 1 and 3–13 end at 8–26 min)
local MINUTES = tonumber(process.args[2]) or 40
local TICKS = MINUTES * 60 * 15
local BUDGET_MS = 1000 / 15

local lines = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

local sim = Sim.new({
	seed = SEED,
	players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
	mapId = "skirmish:256",
	scenario = "standard_start",
	match = { mode = "FFA", win = "ANNIHILATION" },
})
local timing = Sim.enableTiming(sim)
local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
local spectator = NetOut.addSpectator(sim)
local recording = PlayerReplay.new({
	protocol = Schema.PROTOCOL_VERSION,
	defsHash = sim.defs.hash,
	mapId = sim.mapId,
	viewer = 0,
	players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 } },
}, sim.tick + 1)

local tickMs: { number } = {}
local peak, peakTick = 0, 0
local samples = {} -- per minute: { minute, units, heapKB, avgMs }
local minuteSum = 0
local maxUnits = 0
local t0 = os.clock()
for tick = 1, TICKS do
	local s = os.clock()
	for _, b in brains do
		Skirmish.tick(b)
	end
	Sim.step(sim)
	local ms = (os.clock() - s) * 1000
	PlayerReplay.record(recording, sim.tick, sim.net.spectators[spectator].outbox)
	table.insert(tickMs, ms)
	minuteSum += ms
	if ms > peak then
		peak, peakTick = ms, sim.tick
	end
	maxUnits = math.max(maxUnits, #sim.world.ids)
	if tick % 900 == 0 then
		table.insert(samples, { minute = tick // 900, units = #sim.world.ids, heap = collectgarbage("count"), avg = minuteSum / 900 })
		minuteSum = 0
	end
	if sim.match.over then
		break
	end
end
local wall = os.clock() - t0
local played = sim.tick

table.sort(tickMs)
local function pct(p: number): number
	return tickMs[math.max(1, math.ceil(#tickMs * p))]
end
out(string.format("Soak: seed %d, skirmish:256, Annihilation, %.1f min of game time (%d ticks) in %.0f s on the dev PC", SEED, played / 900, played, wall))
if sim.match.over then
	out(string.format("match over at %.1f min: winner ally team %s", played / 900, tostring(sim.match.winner)))
else
	out("match still running at the time limit")
end
out(string.format("tick: avg %.2f ms, p95 %.2f, p99 %.2f, max %.2f ms at tick %d (budget %.1f)", wall * 1000 / played, pct(0.95), pct(0.99), peak, peakTick, BUDGET_MS))
local names = {}
for name in timing.peak do
	table.insert(names, name)
end
table.sort(names, function(a, b)
	return timing.peak[a] > timing.peak[b]
end)
local parts = {}
for i = 1, math.min(5, #names) do
	local n = names[i]
	table.insert(parts, string.format("%s %.1f (avg %.2f)", n, timing.peak[n] * 1000, timing.total[n] * 1000 / played))
end
out("slowest systems, peak ms: " .. table.concat(parts, ", "))
out(string.format("units: at most %d alive", maxUnits))
out("minute | units | heap MB | avg tick ms")
for _, smp in samples do
	if smp.minute % 5 == 0 or smp.minute == 1 then
		out(string.format("%6d | %5d | %7.1f | %.2f", smp.minute, smp.units, smp.heap / 1024, smp.avg))
	end
end

-- heap: after the opening (minute 5), growth beyond what the unit count
-- explains points at a leak
local failures = {}
if peak > BUDGET_MS then
	table.insert(failures, string.format("peak tick %.1f ms over the %.1f ms budget", peak, BUDGET_MS))
end
local early, late = samples[5], samples[#samples]
if early and late and late.minute >= 10 then
	local perUnitEarly = early.heap / math.max(early.units, 1)
	local perUnitLate = late.heap / math.max(late.units, 1)
	out(string.format("heap per unit: %.1f KB at minute %d, %.1f KB at minute %d", perUnitEarly, early.minute, perUnitLate, late.minute))
	if late.heap > early.heap * 2 and perUnitLate > perUnitEarly * 2 then
		table.insert(failures, "the heap more than doubled per unit after minute 5 (leak?)")
	end
end

-- the spectator's player replay
local file = PlayerReplay.serialize(recording)
out(string.format("spectator replay: %.0f KB (%.1f KB per minute of game time), %d frames", buffer.len(file) / 1024, buffer.len(file) / 1024 / (played / 900), #recording.frames))

-- replay: the command log reproduces the final hash
local r0 = os.clock()
local log = Replay.parse(Replay.serialize(sim.replay))
local replayed, mismatch = Sim.runReplay(log, played)
local ok = mismatch == nil and Sim.hash(replayed) == Sim.hash(sim)
out(string.format("replay of %d ticks: %s (%.0f s)", played, if ok then "identical" else `DIFFERS (first bad checkpoint at tick {mismatch})`, os.clock() - r0))
if not ok then
	table.insert(failures, "replay differs")
end

if not fs.isDir("debug_out") then
	fs.writeDir("debug_out")
end
fs.writeFile("debug_out/soak.txt", table.concat(lines, "\n") .. "\n")
fs.writeFile("debug_out/soak.ftgp", file)
if #failures > 0 then
	out("FAIL: " .. table.concat(failures, "; "))
	process.exit(1)
end
out("PASS")
