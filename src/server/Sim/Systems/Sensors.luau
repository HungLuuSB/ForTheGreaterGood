--!strict
-- System 3 (every 2nd tick): re-stamp sensor maps for emitters that changed
-- sensor cell, then recompute visibility per team (guide 11). See Sim/Sensors.luau.

local Sensors = require("../Sensors")
local Types = require("../Types")

return function(sim: Types.Sim)
	Sensors.step(sim)
end
