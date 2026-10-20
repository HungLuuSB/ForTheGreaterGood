--!strict
-- Prints the scripted T1 build order timeline (both factions) with the
-- economy at each event.
--   lune run report_buildorder [mapId]

local process = require("@lune/process")

local BuildOrder = require("../src/server/Tests/Support/BuildOrder")
local Sim = require("../src/server/Sim/Sim")

local mapId = process.args[1] or "start:96"
local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = mapId, scenario = "standard_start" })
local t0 = os.clock()
local driver = BuildOrder.new(sim)
local printed = 0
local stalls = { 0, 0 }
while sim.tick < 15 * 60 * 10 do
	BuildOrder.tick(driver)
	for team = 1, 2 do
		local acc = sim.eco.accounts[team]
		if acc.supply.ratio < 1 or acc.power.ratio < 1 then
			stalls[team] += 1
		end
	end
	while printed < #driver.timeline do
		printed += 1
		local e = driver.timeline[printed]
		local acc = sim.eco.accounts[sim.players[e.player].team]
		print(string.format(
			"%6.1f s  P%d %-26s supply %6.0f (+%4.1f/s, ratio %.2f)  power %6.0f (+%4.0f/s, ratio %.2f)",
			e.tick / 15,
			e.player,
			e.what,
			acc.supply.stored,
			acc.supply.income,
			acc.supply.ratio,
			acc.power.stored,
			acc.power.income,
			acc.power.ratio
		))
	end
	if driver.players[1].produced >= 3 and driver.players[2].produced >= 3 then
		break
	end
end
print(string.format("done at %.1f s game time (%d ticks); stalled ticks P1 %d, P2 %d; %.3f ms/tick", sim.tick / 15, sim.tick, stalls[1], stalls[2], (os.clock() - t0) * 1000 / sim.tick))
