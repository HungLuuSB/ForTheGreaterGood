--!strict
-- System 2 (every 5th tick, 3 Hz): settle team accounts and compute the
-- stall ratios for the next window (guide 8.4). See Sim/Economy.luau.

local Economy = require("../Economy")
local Types = require("../Types")

return function(sim: Types.Sim)
	Economy.step(sim.eco, sim.world, sim.defs, if sim.map then sim.map.layers else nil, sim.tick)
end
