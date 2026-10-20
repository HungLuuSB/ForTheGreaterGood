--!strict
-- System 11: match rules (guide 16.2): eliminations and the match result.
-- See Sim/Match.luau.

local Match = require("../Match")
local Types = require("../Types")

return function(sim: Types.Sim)
	Match.step(sim)
end
