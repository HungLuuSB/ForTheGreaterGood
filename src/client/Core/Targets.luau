--!strict
-- A unit's current target, for the target line when one unit is selected
-- (C-20, C-25). Own units' targets come from the server (State TARGET
-- field, S-16): the first weapon slot with a target wins. Units whose
-- targets the server doesn't send (an ally's) fall back to a guess:
--   1. the attack order this client sent;
--   2. else, while the first weapon is AIMING or READY, the known enemy
--      within that weapon's range closest to the turret's aim line.
-- Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local Targets = {}

Targets.MAX_AIM_ERROR = math.rad(12) -- off the aim line: not that target
Targets.RANGE_SLACK = 1.1 -- the enemy may have just stepped out of range

local CT = Schema.CmdType
local WS = Schema.WeaponState

-- `orders` = Waypoints.byUnit (what this client sent), optional.
function Targets.of(world: World.World, id: number, orders: { [number]: { any } }?): number?
	local u = world.units[id]
	if u == nil then
		return nil
	end
	if u.targets then
		for slot = 1, Schema.MAX_WEAPONS do
			local t = u.targets[slot]
			if t and t ~= 0 then
				return if world.units[t] then t else nil
			end
		end
		return nil
	end
	local first = orders and orders[id] and orders[id][1]
	if first and first.kind == CT.ATTACK and first.targetId and world.units[first.targetId] then
		return first.targetId
	end
	local def = World.def(world, u)
	if def == nil or #def.weapons == 0 then
		return nil
	end
	local state = Schema.weaponStateAt(u.weapon, 1)
	if state ~= WS.AIMING and state ~= WS.READY then
		return nil
	end
	local aim = u.aim[1]
	local weapon = world.defs.weaponByIndex[def.weapons[1].weaponIndex]
	local range = (weapon and weapon.range or 0) * Targets.RANGE_SLACK
	-- turret yaw is relative to the hull; forward = (sin h, cos h)
	local dir = u.heading + (if aim then aim.yaw else 0)
	local fx, fz = math.sin(dir), math.cos(dir)
	local x, z = u.rx or u.x, u.rz or u.z
	local best, bestScore = nil, math.huge
	for oid, o in world.units do
		if o.team == world.me.team then
			continue
		end
		local dx, dz = (o.rx or o.x) - x, (o.rz or o.z) - z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1e-6 or d > range then
			continue
		end
		local err = math.acos(math.clamp((dx * fx + dz * fz) / d, -1, 1))
		if err <= Targets.MAX_AIM_ERROR then
			local score = err + d / range * 0.05 -- the nearer of two on the line
			if score < bestScore then
				best, bestScore = oid, score
			end
		end
	end
	return best
end

return Targets
