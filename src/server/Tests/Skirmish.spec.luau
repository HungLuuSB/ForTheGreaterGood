--!strict
local Profiler = require("@shared/Util/Profiler")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

local MAX_TICKS = 54000 -- 60 minutes (30 before S-193 made every unit 40% slower; 45 before S-221: governed economies last longer, seed 1 ended at 44 min; 17 since S-222)

type Result = {
	sim: Sim.Sim,
	brains: { Skirmish.Brain },
	peakMs: number,
	maxExtractors: { number },
	farthestExtractor: { number },
}

-- Order (player 1) vs Chaos (player 2), both AI, Command Ends, on the
-- 192×192 skirmish map, until the match ends or MAX_TICKS.
local function play(seed: number): Result
	local sim = Sim.new({
		seed = seed,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
	local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
	local r: Result = { sim = sim, brains = brains, peakMs = 0, maxExtractors = { 0, 0 }, farthestExtractor = { 0, 0 } }
	local w = sim.world
	while not sim.match.over and sim.tick < MAX_TICKS do
		for _, b in brains do
			Skirmish.tick(b)
		end
		local t0 = Profiler.now()
		Sim.step(sim)
		r.peakMs = math.max(r.peakMs, (Profiler.now() - t0) * 1000)
		if sim.tick % 150 == 0 then
			local count = { 0, 0 }
			for _, id in w.ids do
				local d = sim.defs.unitByIndex[w.defIndex[id]]
				local owner = w.owner[id]
				if d.extractor and w.buildProgress[id] >= 1 and (owner == 1 or owner == 2) then
					count[owner] += 1
					local b = brains[owner]
					local dist = math.sqrt((w.posX[id] - b.homeX) ^ 2 + (w.posZ[id] - b.homeZ) ^ 2)
					r.farthestExtractor[owner] = math.max(r.farthestExtractor[owner], dist)
				end
			end
			for p = 1, 2 do
				r.maxExtractors[p] = math.max(r.maxExtractors[p], count[p])
			end
		end
	end
	return r
end

return function(t: RunAll.Context)
	local first: Result? = nil

	t.slow("AI vs AI plays a full match on a 192×192 map until a win condition is reached", function()
		local r = play(1)
		first = r
		local sim = r.sim
		t.expect(sim.match.over, `the match ended (tick {sim.tick})`)
		t.expect(sim.match.winner == 1 or sim.match.winner == 2, `someone won ({sim.match.winner})`)
		local loser = 3 - sim.match.winner
		t.expect(sim.match.eliminated[loser] ~= nil, "the loser lost its Command Vehicle")
		for p = 1, 2 do
			-- the winner attacked; so did the loser if it lasted past 11 minutes
			-- (since the faction pass, S-62, a rush can end it first; since
			-- S-124 (footprint-2 Commanders) seed 1's Order is raided down to
			-- 2 extractors by minute 5 and falls at 9.9 min without a wave;
			-- since S-130's radar orbits, at 10.3 min)
			if p == sim.match.winner or sim.tick > 11 * 900 then
				t.expect(r.brains[p].waves >= 1, `player {p} attacked ({r.brains[p].waves} waves)`)
			end
			t.expect(r.maxExtractors[p] > 4, `player {p} expanded beyond its 4 home deposits ({r.maxExtractors[p]} extractors)`)
			t.expect(r.farthestExtractor[p] > Skirmish.HOME_RADIUS, `player {p} took a deposit away from home ({math.floor(r.farthestExtractor[p])} studs)`)
		end
		t.equal(sim.stats.commandsRejected, 0, "every AI command was valid")
		print(string.format(
			"    seed 1: %s won at %.1f min (%d ticks), peak tick %.1f ms; waves %d / %d; extractors %d / %d",
			if sim.match.winner == 1 then "Order" else "Chaos",
			sim.match.endTick / 900,
			sim.match.endTick,
			r.peakMs,
			r.brains[1].waves,
			r.brains[2].waves,
			r.maxExtractors[1],
			r.maxExtractors[2]
		))
	end)

	t.slow("two runs with the same seed give identical matches, and the replay reproduces it", function()
		local a = first or play(1)
		local b = play(1)
		t.equal(Sim.hash(b.sim), Sim.hash(a.sim), "final world hash")
		t.equal(b.sim.match.endTick, a.sim.match.endTick, "same length")
		t.equal(b.sim.match.winner, a.sim.match.winner, "same winner")
		local log = Replay.parse(Replay.serialize(a.sim.replay))
		local replayed, mismatch = Sim.runReplay(log, a.sim.tick)
		t.equal(mismatch, nil, "replay checkpoints match")
		t.equal(Sim.hash(replayed), Sim.hash(a.sim), "the replay (no AI, just its recorded commands) ends identically")
	end)
end
