--!strict
-- System 5: advance queued plan and flow field jobs within the per-tick
-- work budget (guide 6.4; budget in deterministic work units, DECISIONS
-- D29/D33/D83). Jobs are created by move orders (Nav.issueMove, from
-- Commands); the work spent issuing them comes out of the same budget.

local Nav = require("../Nav")
local Types = require("../Types")

return function(sim: Types.Sim)
	local nav = sim.nav
	if nav then
		-- orders issued since the last Pathing tick already used part of the budget
		local budget = math.max(Nav.PATHING_BUDGET - nav.issueWork, 0)
		nav.issueWork = 0
		Nav.runJobs(nav, sim.world, budget)
	end
end
