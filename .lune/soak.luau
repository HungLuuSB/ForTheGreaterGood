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
-- player replay, debug_out/soak.ftgp, and its size reported. It is recorded
-- in a second run of the same match, so the heap check doesn't count it.
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

local SEED = tonumber(process.args[1]) or 11 -- the longest of seeds 1–13 with the S-31..S-39 AI and combat (32.6 min; none reaches 40 now)
local MINUTES = tonumber(process.args[2]) or 40
local TICKS = MINUTES * 60 * 15
local BUDGET_MS = 1000 / 15

local lines = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

-- Plays the match. The heap is measured in a run without the spectator
-- recording: the recording keeps every message, grows with time rather than
-- with units, and with small armies it made the per-unit heap look like a
-- leak. The recording comes from a second run of the same (deterministic)
-- match.
type Run = {
	sim: Sim.Sim,
	timing: any,
	recording: PlayerReplay.Replay?,
	tickMs: { number },
	peak: number,
	peakTick: number,
	samples: { { minute: number, units: number, heap: number, avg: number } },
	maxUnits: number,
	wall: number,
}
local function play(record: boolean): Run
	local sim = Sim.new({
		seed = SEED,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:256",
		scenario = "standard_start",
		match = { mode = "FFA", win = "ANNIHILATION" },
	})
	local r: Run = { sim = sim, timing = Sim.enableTiming(sim), recording = nil, tickMs = {}, peak = 0, peakTick = 0, samples = {}, maxUnits = 0, wall = 0 }
	local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
	local spectator = NetOut.addSpectator(sim)
	if record then
		r.recording = PlayerReplay.new({
			protocol = Schema.PROTOCOL_VERSION,
			defsHash = sim.defs.hash,
			mapId = sim.mapId,
			viewer = 0,
			players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 } },
		}, sim.tick + 1)
	end
	local minuteSum = 0
	local t0 = os.clock()
	for tick = 1, TICKS do
		local s = os.clock()
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		local ms = (os.clock() - s) * 1000
		if r.recording then
			PlayerReplay.record(r.recording, sim.tick, sim.net.spectators[spectator].outbox)
		end
		table.insert(r.tickMs, ms)
		minuteSum += ms
		if ms > r.peak then
			r.peak, r.peakTick = ms, sim.tick
		end
		r.maxUnits = math.max(r.maxUnits, #sim.world.ids)
		if tick % 900 == 0 then
			table.insert(r.samples, { minute = tick // 900, units = #sim.world.ids, heap = collectgarbage("count"), avg = minuteSum / 900 })
			minuteSum = 0
		end
		if sim.match.over then
			break
		end
	end
	r.wall = os.clock() - t0
	return r
end

local run = play(false)
local sim, timing, tickMs, peak, peakTick, samples, maxUnits = run.sim, run.timing, run.tickMs, run.peak, run.peakTick, run.samples, run.maxUnits
local wall = run.wall
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

-- the spectator's player replay, from a second run of the same match
local recorded = play(true)
local recording = recorded.recording :: PlayerReplay.Replay
local file = PlayerReplay.serialize(recording)
out(string.format("spectator replay (second run): %.0f KB (%.1f KB per minute of game time), %d frames", buffer.len(file) / 1024, buffer.len(file) / 1024 / (played / 900), #recording.frames))
if Sim.hash(recorded.sim) ~= Sim.hash(sim) then
	table.insert(failures, "the recorded run differs from the first")
end

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
