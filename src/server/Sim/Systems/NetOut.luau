--!strict
-- System 11: interest management and packet building per player (guide 7).
-- See Sim/NetOut.luau. Messages land in sim.net.players[id].outbox; the
-- Roblox entry script will fire them on the remotes.

local NetOut = require("../NetOut")
local Types = require("../Types")

return function(sim: Types.Sim)
	NetOut.step(sim)
end
