--!strict
-- System 10: construction, factory production and reclaim (guide 9).
-- See Sim/Build.luau.

local Build = require("../Build")
local Types = require("../Types")

return function(sim: Types.Sim)
	Build.step(sim)
end
