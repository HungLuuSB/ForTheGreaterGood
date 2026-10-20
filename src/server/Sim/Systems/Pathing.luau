--!strict
-- System 5: advance queued flow field jobs within the per-tick work budget
-- (guide 6.4; budget in deterministic work units, DECISIONS D29/D33).
-- Requests are created by move orders (Nav.issueMove, from Commands).

local Nav = require("../Nav")
local Types = require("../Types")

return function(sim: Types.Sim)
	local nav = sim.nav
	if nav then
		Nav.runJobs(nav, Nav.PATHING_BUDGET)
	end
end
