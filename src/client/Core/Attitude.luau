--!strict
-- How a unit's model sits beyond its position and heading (C-31): banking
-- and pitch for aircraft, and the depth of ships and submarines in the
-- water. Visual only; the server knows none of it. Pure Luau (C-7).
--   Jets roll into their turns (from the turn rate of the drawn heading).
--   Helicopters roll a little and dip their nose with speed.
--   Ships sit SHIP_DRAFT deep at the water surface; own (and allied)
--   submarines are drawn just under it (SUB_VISIBLE_DEPTH), not at the
--   server's depth, so their owner sees them through the water. Enemy
--   submarines are never drawn: the server sends them only as sonar
--   contacts (strategic records).

local Schema = require("@shared/Net/Schema")

local Attitude = {}

Attitude.JET_BANK = 0.7 -- radians of roll per radian/second of turn
Attitude.JET_MAX_ROLL = math.rad(60)
Attitude.HELI_BANK = 0.25
Attitude.HELI_MAX_ROLL = math.rad(20)
Attitude.HELI_MAX_PITCH = math.rad(12) -- nose down at full speed
Attitude.RESPONSE = 5 -- 1/s: how fast roll and pitch close on their targets
Attitude.SHIP_DRAFT = 0.8 -- studs a ship's model sits below the surface
Attitude.SUB_VISIBLE_DEPTH = 2.5 -- studs from the surface to a drawn submarine's top

local SUBMERGED = Schema.UnitState.SUBMERGED

export type State = { roll: number, pitch: number, heading: number?, x: number?, z: number? }

function Attitude.new(): State
	return { roll = 0, pitch = 0, heading = nil, x = nil, z = nil }
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Advances `s` for a unit drawn at (x, z) with `heading` this frame and
-- returns its roll and pitch (radians; roll > 0 lifts the right side, pitch
-- > 0 lifts the nose). `def` gives the domain, move class and top speed.
function Attitude.step(s: State, def: any, x: number, z: number, heading: number, dt: number): (number, number)
	local rollGoal, pitchGoal = 0, 0
	if def.domain == "air" and dt > 0 and s.heading ~= nil then
		-- a rising heading turns left (toward +x from +z): the left side dips
		local rate = wrap(heading - s.heading) / dt
		local speed = math.sqrt((x - (s.x :: number)) ^ 2 + (z - (s.z :: number)) ^ 2) / dt
		if def.moveClass == "HELI" then
			rollGoal = math.clamp(rate * Attitude.HELI_BANK, -Attitude.HELI_MAX_ROLL, Attitude.HELI_MAX_ROLL)
			local top = (def.movement and def.movement.maxSpeed) or 1
			pitchGoal = -Attitude.HELI_MAX_PITCH * math.clamp(speed / top, 0, 1)
		else
			rollGoal = math.clamp(rate * Attitude.JET_BANK, -Attitude.JET_MAX_ROLL, Attitude.JET_MAX_ROLL)
		end
	end
	s.heading, s.x, s.z = heading, x, z
	local k = math.min(1, dt * Attitude.RESPONSE)
	s.roll += (rollGoal - s.roll) * k
	s.pitch += (pitchGoal - s.pitch) * k
	return s.roll, s.pitch
end

-- Where a naval unit's model origin goes relative to the water surface
-- (studs, negative = below); 0 for everything else. `hullHeight` is the
-- model's height (submarines are drawn fully under the surface).
function Attitude.waterOffset(def: any, state: number, hullHeight: number): number
	if def.domain ~= "naval" then
		return 0
	end
	if bit32.band(state, SUBMERGED) ~= 0 then
		return -Attitude.SUB_VISIBLE_DEPTH - hullHeight
	end
	return -Attitude.SHIP_DRAFT
end

return Attitude
