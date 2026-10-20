--!strict
-- System 4: target acquisition (guide 10.2).
--
-- Targeting follows team knowledge, never server truth (D100). Each weapon
-- keeps its current target while it stays valid: an enemy the team knows
-- about (VISIBLE; RADAR contacts and structure ghosts only for
-- canTargetRadar weapons, guide 11.4), a category it can hit, within range
-- (+10% hysteresis, measured to the known position) and arc, and allowed by
-- the unit's fire state. A ghost stays a target even if its structure died
-- unseen (the team can't tell): until the spot is seen again, when Sensors
-- forgets it. Bombers with an attack-ground order (Air) don't auto-target.
-- An untracked radar or sonar contact reveals only its domain (D107): it is
-- filtered by domain, scored without type priorities, and its collision
-- radius doesn't count toward range. An invalid target is dropped at once. A
-- weapon without a target searches only on its unit's stagger tick
-- ((id + tick) % STAGGER == 0), so 1/STAGGER of units search per tick.
--
-- Search: enemies from the contact grid within range; score = priority
-- weight / distance, where the weight is 1 plus how early the target's
-- categories appear in the weapon's priority list. Ties go to the lower ID.
--
-- Guided missiles (HOMING with a guidance type) prefer targets they can lock
-- (EW.canLock): a lockable target's score is multiplied by LOCK_PREFERENCE,
-- so it outranks every unlockable one. They also re-search on their stagger
-- tick while holding a target, and switch only to a target scoring at least
-- SWITCH_MARGIN times the current one (hysteresis against flip-flopping).
-- With nothing lockable they keep tracking the best target and hold fire
-- (Weapons won't launch without a lock).

local Combat = require("../Combat/Combat")
local ContactGrid = require("../Combat/ContactGrid")
local EW = require("../EW")
local Sensors = require("../Sensors")
local Defs = require("@shared/Defs/Defs")
local Types = require("../Types")
local World = require("../World")

local STAGGER = 6
local RANGE_HYSTERESIS = 1.1
local LOCK_PREFERENCE = 1000
local SWITCH_MARGIN = 1.25

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
	if w.slot[t] ~= nil and w.ally[t] == w.ally[id] then
		return nil
	end
	local kx, kz, level, defIndex = Sensors.knownTarget(sim, w.ally[id], t)
	if kx == nil then
		return nil
	end
	local tp = c.profiles[defIndex :: number]
	local known = Sensors.typeKnown(sim, w.ally[id], t, level)
	if band(weapon.targetMask, Sensors.knownCategories(sim, w.ally[id], t, level, defIndex :: number)) == 0 then
		return nil
	end
	local radius = if known then tp.radius else 0
	local allowed = level == VISIBLE
		or ((level == RADAR or level == GHOST) and weapon.canTargetRadar)
		or (level == SONAR and weapon.type == "TORPEDO") -- torpedoes hunt sonar contacts
	if not allowed then
		return nil
	end
	local dx, dz = (kx :: number) - w.posX[id], (kz :: number) - w.posZ[id]
	local dist = sqrt(dx * dx + dz * dz)
	if dist > weapon.range * hysteresis + radius then
		return nil
	end
	local turret = weapon.turret
	local maneuvers = sim.defs.unitByIndex[w.defIndex[id]].moveClass == "JET" -- a jet turns to bring its guns to bear
	if turret and turret.arc < 360 and not maneuvers and abs(wrapAngle(atan2(dx, dz) - w.heading[id])) > rad(turret.arc) / 2 then
		return nil
	end
	return dist
end

local function isGuided(weapon: Defs.WeaponDef): boolean
	return weapon.guidance ~= nil and weapon.type == "HOMING"
end

local function score(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, dist: number): number
	local team = sim.world.ally[id]
	local _, _, level, defIndex = Sensors.knownTarget(sim, team, t)
	-- type priorities only for targets whose type the team knows (D107)
	local weight = if Sensors.typeKnown(sim, team, t, level) then priorityWeight(weapon.priorityMasks, sim.combat.profiles[defIndex :: number].categoryMask) else 1
	local s = weight / math.max(dist, 1)
	if isGuided(weapon) and EW.canLock(sim, id, weapon, t, dist) then
		s *= LOCK_PREFERENCE
	end
	return s
end

-- The largest radar error any def has: a radar contact's believed position
-- can be this far from its true one (cached per def set).
local maxErrorCache: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local function maxRadarError(sim: Types.Sim): number
	local e = maxErrorCache[sim.defs]
	if e == nil then
		e = Sensors.DEFAULT_RADAR_ERROR
		for _, d in sim.defs.unitByIndex do
			e = math.max(e, d.sensors.radarError or 0)
		end
		maxErrorCache[sim.defs] = e
	end
	return e
end

-- Best acceptable enemy within range, and its score (0, 0 when none).
-- Candidates come from the contact grid (true positions), gathered wide
-- enough that every enemy whose believed position is in range is among
-- them: acceptance is decided on the believed position (D101).
local function search(sim: Types.Sim, id: number, weapon: Defs.WeaponDef): (number, number)
	local c = sim.combat
	local w = sim.world
	local best, bestScore = 0, 0
	local reach = weapon.range + c.maxRadius + (if weapon.canTargetRadar or weapon.type == "TORPEDO" then maxRadarError(sim) else 0)
	local n = ContactGrid.query(c.contacts, w, w.posX[id], w.posZ[id], reach, w.ally[id], candidates)
	for i = 1, n do
		local t = candidates[i]
		local dist = acceptable(sim, id, weapon, t, 1)
		if dist ~= nil then
			local s = score(sim, id, weapon, t, dist)
			if s > bestScore or (s == bestScore and t < best) then
				best, bestScore = t, s
			end
		end
	end
	-- remembered structures that are no longer there: the team doesn't know
	if weapon.canTargetRadar then
		for _, gid in sim.sensors.ghostIds[w.ally[id]] or {} do
			if w.slot[gid] == nil then
				local dist = acceptable(sim, id, weapon, gid, 1)
				if dist ~= nil then
					local s = score(sim, id, weapon, gid, dist)
					if s > bestScore or (s == bestScore and gid < best) then
						best, bestScore = gid, s
					end
				end
			end
		end
	end
	return best, bestScore
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

		local groundOrder = sim.air.groundX[id] ~= nil
		for slot = 1, count do
			local key = id * 8 + slot - 1
			local weapon = p.weapons[slot]
			if groundOrder and weapon.type == "BOMB" then
				w.wTarget[key] = 0 -- bombing the ordered spot (Air.bombAim)
				continue
			end

			local cur = w.wTarget[key]
			local curDist: number? = nil
			if cur ~= 0 then
				curDist = acceptable(sim, id, weapon, cur, RANGE_HYSTERESIS)
				local keep = fs ~= HOLD_FIRE and (fs ~= RETURN_FIRE or cur == attacker) and curDist ~= nil
				if not keep then
					cur = 0
					w.wTarget[key] = 0
				end
			end

			-- guided missiles: switch to a clearly better (e.g. lockable) target
			if cur ~= 0 and searchNow and fs ~= RETURN_FIRE and isGuided(weapon) then
				local best, bestScore = search(sim, id, weapon)
				if best ~= 0 and best ~= cur and bestScore > score(sim, id, weapon, cur, curDist :: number) * SWITCH_MARGIN then
					w.wTarget[key] = best
				end
				continue
			end

			if cur == 0 and searchNow and fs ~= HOLD_FIRE then
				local best = 0
				if fs == RETURN_FIRE then
					if attacker ~= 0 and acceptable(sim, id, weapon, attacker, 1) ~= nil then
						best = attacker
					end
				else
					best = search(sim, id, weapon)
				end
				w.wTarget[key] = best
			end
		end
	end
end
