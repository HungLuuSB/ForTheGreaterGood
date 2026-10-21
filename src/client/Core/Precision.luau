--!strict
-- The team's radar precision (S-59, C-72): its finished Pinpointers
-- weighed the way the server does (Sensors: units of a def with
-- `pinpointer = true`, built; each counts `Pinpoint.weight`, since S-62 a
-- Witness needs 5 for full precision and an Augur 7), through
-- Shared/Combat/Pinpoint. Own team's
-- only: the wire doesn't say which players are allies, while the server
-- counts the whole ally team. Units outside the camera are identified by
-- their icon (the def index since S-58); their build state isn't known, so
-- they count as finished. Pure Luau (C-7).

local Pinpoint = require("@shared/Combat/Pinpoint")
local World = require("./World")

local Precision = {}

-- Finished own Pinpointers: their number and the sum of their weights.
function Precision.count(world: World.World): (number, number)
	local n, weight = 0, 0
	for _, u in world.units do
		if u.team ~= world.me.team then
			continue
		end
		local index = u.defIndex or (if u.icon and u.icon > 0 then u.icon else nil)
		local def = if index then world.defs.unitByIndex[index] else nil
		if def and def.pinpointer and (u.build == nil or u.build >= 1) then
			n += 1
			weight += Pinpoint.weight(def)
		end
	end
	return n, weight
end

-- Precision 0..1 and the Pinpointer count.
function Precision.of(world: World.World): (number, number)
	local n, weight = Precision.count(world)
	return Pinpoint.precision(weight), n
end

-- Does this def's panel show the team's radar precision (radars, radar SAMs,
-- fire control, Pinpointers)?
function Precision.relevant(def: any): boolean
	local s = def.sensors or {}
	if def.pinpointer or (s.radar or 0) > 0 or (s.track or 0) > 0 then
		return true
	end
	return false
end

Precision.FULL = Pinpoint.FULL

return Precision
