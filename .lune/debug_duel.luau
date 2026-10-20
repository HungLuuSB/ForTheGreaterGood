--!strict
-- Runs the 10 v 10 duel (Lancers vs Ravagers) for a few seeds and prints the
-- outcome, length, shots/hits/kills and simulation cost.
--   lune run debug_duel [seeds]

local process = require("@lune/process")

local Sim = require("../src/server/Sim/Sim")

local seeds = tonumber(process.args[1]) or 10
local wins = { 0, 0 }
for seed = 1, seeds do
	local sim = Sim.new({ seed = seed, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "duel_test" })
	local t0 = os.clock()
	local left = { 10, 10 }
	while sim.tick < 3000 do
		Sim.step(sim)
		left = { 0, 0 }
		for _, id in sim.world.ids do
			left[sim.world.team[id]] += 1
		end
		if left[1] == 0 or left[2] == 0 then
			break
		end
	end
	local elapsed = os.clock() - t0
	local winner = if left[1] > 0 then 1 else 2
	wins[winner] += 1
	local s = sim.combat.stats
	print(string.format(
		"seed %2d: %s wins with %d left after %d ticks (%.1f s game time); shots %d, hits %d (%.0f%%), kills %d, wrecks %d; %.3f ms/tick",
		seed,
		if winner == 1 then "Order (Lancers)" else "Chaos (Ravagers)",
		left[winner],
		sim.tick,
		sim.tick / 15,
		s.shots,
		s.hits,
		100 * s.hits / math.max(s.shots, 1),
		s.kills,
		#sim.combat.wreckIds,
		elapsed * 1000 / sim.tick
	))
end
print(string.format("Order %d - %d Chaos over %d seeds", wins[1], wins[2], seeds))
