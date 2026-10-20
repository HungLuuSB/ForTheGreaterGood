--!strict
-- System 4: target acquisition (guide 10.2).
--
-- Each weapon keeps its current target while it stays valid: alive, an
-- enemy the team knows about (VISIBLE; RADAR contacts and structure ghosts
-- only for canTargetRadar weapons, guide 11.4), a category it can hit, within
-- range (+10% hysteresis, measured to the known position) and arc, and
-- allowed by the unit's fire state. An invalid target is dropped at once. A
-- weapon without a target searches only on its unit's stagger tick
-- ((id + tick) % STAGGER == 0), so 1/STAGGER of units search per tick.
--
-- Search: enemies from the contact grid within range; score = priority
-- weight / distance, where the weight is 1 plus how early the target's
-- categories appear in the weapon's priority list. Ties go to the lower ID.

local Combat = require("../Combat/Combat")
local ContactGrid = require("../Combat/ContactGrid")
local Sensors = require("../Sensors")
local Defs = require("@shared/Defs/Defs")
local Types = require("../Types")
local World = require("../World")

local STAGGER = 6
local RANGE_HYSTERESIS = 1.1

local band = bit32.band
local sqrt, atan2, abs, rad = math.sqrt, math.atan2, math.abs, math.rad
local PI, TAU = math.pi, 2 * math.pi
local HOLD_FIRE, RETURN_FIRE = World.FireState.HOLD_FIRE, World.FireState.RETURN_FIRE

local candidates: { number } = {}

local function wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
end

local function priorityWeight(masks: { number }, category: number): number
	local n = #masks
	for i = 1, n do
		if band(masks[i], category) ~= 0 then
			return 1 + (n - i + 1)
		end
	end
	return 1
end

-- Can `weapon` on unit `id` engage `t`? Returns the center distance when yes.
local VISIBLE, RADAR, GHOST, SONAR = Sensors.Level.VISIBLE, Sensors.Level.RADAR, Sensors.Level.GHOST, Sensors.Level.SONAR

local function acceptable(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, hysteresis: number): number?
	local c = sim.combat
	local w = sim.world
	if w.slot[t] == nil or w.team[t] == w.team[id] then
		return nil
	end
	local tp = c.profiles[w.defIndex[t]]
	if band(weapon.targetMask, tp.categoryMask) == 0 then
		return nil
	end
	local kx, kz, level = Sensors.knownPosition(sim, w.team[id], t)
	local allowed = level == VISIBLE
		or ((level == RADAR or level == GHOST) and weapon.canTargetRadar)
		or (level == SONAR and weapon.type == "TORPEDO") -- torpedoes hunt sonar contacts
	if kx == nil or not allowed then
		return nil
	end
	local dx, dz = (kx :: number) - w.posX[id], (kz :: number) - w.posZ[id]
	local dist = sqrt(dx * dx + dz * dz)
	if dist > weapon.range * hysteresis + tp.radius then
		return nil
	end
	local turret = weapon.turret
	local maneuvers = sim.defs.unitByIndex[w.defIndex[id]].moveClass == "JET" -- a jet turns to bring its guns to bear
	if turret and turret.arc < 360 and not maneuvers and abs(wrapAngle(atan2(dx, dz) - w.heading[id])) > rad(turret.arc) / 2 then
		return nil
	end
	return dist
end

return function(sim: Types.Sim)
	local c = sim.combat
	local w = sim.world
	ContactGrid.rebuild(c.contacts, w)
	local tick = sim.tick
	local profiles = c.profiles

	for _, id in w.ids do
		local count = w.weaponCount[id]
		if count == 0 then
			continue
		end
		local p = profiles[w.defIndex[id]]
		local fs = w.fireState[id]
		local searchNow = (id + tick) % STAGGER == 0
		local attacker = w.lastAttacker[id]

		for slot = 1, count do
			local key = id * 8 + slot - 1
			local weapon = p.weapons[slot]

			local cur = w.wTarget[key]
			if cur ~= 0 then
				local keep = fs ~= HOLD_FIRE
					and (fs ~= RETURN_FIRE or cur == attacker)
					and acceptable(sim, id, weapon, cur, RANGE_HYSTERESIS) ~= nil
				if not keep then
					cur = 0
					w.wTarget[key] = 0
				end
			end

			if cur == 0 and searchNow and fs ~= HOLD_FIRE then
				local best, bestScore = 0, 0
				if fs == RETURN_FIRE then
					if attacker ~= 0 and acceptable(sim, id, weapon, attacker, 1) ~= nil then
						best = attacker
					end
				else
					local n = ContactGrid.query(c.contacts, w, w.posX[id], w.posZ[id], weapon.range + c.maxRadius, w.team[id], candidates)
					for i = 1, n do
						local t = candidates[i]
						local dist = acceptable(sim, id, weapon, t, 1)
						if dist ~= nil then
							local score = priorityWeight(weapon.priorityMasks, profiles[w.defIndex[t]].categoryMask) / math.max(dist, 1)
							if score > bestScore or (score == bestScore and t < best) then
								best, bestScore = t, score
							end
						end
					end
				end
				w.wTarget[key] = best
			end
		end
	end
end
