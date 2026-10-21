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
-- ((phase(id) + tick) % STAGGER == 0), so 1/STAGGER of units search per
-- tick. The phase is a mixed hash of the ID (S-23): with `id` itself, a unit's
-- search ticks had its ID's parity, and Sensors updates on even ticks, so
-- even-ID units reacted to new enemies a tick sooner on average; in
-- mirrored matches player 2's units get the even IDs (a start bias).
--
-- Search: enemies from the contact grid within range; score = priority
-- weight / distance, where the weight is 1 plus how early the target's
-- categories appear in the weapon's priority list. Ties go to the lower ID.
-- Overkill (S-29, guide 10.2): visible targets that damage already on its way
-- will kill (Combat.doomed) are skipped; the best of them is taken only when
-- nothing else is acceptable, and then marked ALLOWED so Weapons fires. A
-- weapon that just left a doomed target (RETARGET) searches at once.
-- Line of fire (S-32, guide 10.8): direct-fire weapons (hitscan, beams,
-- ballistic shells) prefer, among their best few candidates, one they have
-- a clear shot at; a weapon Weapons found blocked looks for one on its
-- stagger tick.
--
-- Guided missiles (HOMING with a guidance type) prefer targets they can lock
-- (EW.canLock): a lockable target's score is multiplied by LOCK_PREFERENCE,
-- so it outranks every unlockable one. They also re-search on their stagger
-- tick while holding a target, and switch only to a target scoring at least
-- SWITCH_MARGIN times the current one (hysteresis against flip-flopping).
-- With nothing lockable they keep tracking the best target and hold fire
-- (Weapons won't launch without a lock).

local Combat = require("../Combat/Combat")
local Hash = require("@shared/Util/Hash")
local ContactGrid = require("../Combat/ContactGrid")
local EW = require("../EW")
local Sensors = require("../Sensors")
local Defs = require("@shared/Defs/Defs")
local Types = require("../Types")
local World = require("../World")

local STAGGER = 6

-- Search phase per unit ID: hashed, so its parity doesn't follow the ID's
-- (S-23). Cached: it depends only on the ID.
local phases: { [number]: number } = {}
local function phaseOf(id: number): number
	local p = phases[id]
	if p == nil then
		p = Hash.mix32(id) % STAGGER
		phases[id] = p
	end
	return p
end
local RANGE_HYSTERESIS = 1.1
local LOCK_PREFERENCE = 1000
local SWITCH_MARGIN = 1.25

local band = bit32.band
local sqrt, atan2, abs, rad = math.sqrt, math.atan2, math.abs, math.rad
local PI, TAU = math.pi, 2 * math.pi
local HOLD_FIRE, RETURN_FIRE = World.FireState.HOLD_FIRE, World.FireState.RETURN_FIRE

local candidates: { number } = {}
local INTERCEPT_HYSTERESIS = 1.1

-- An interceptor's strategic missile (S-48): the current one while it stays
-- an enemy missile the team detects within range (+10%), else the nearest
-- such missile in range, else 0.
local function interceptTarget(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, key: number): number
	local c = sim.combat
	local w = sim.world
	local ally = w.ally[id]
	local x, z = w.posX[id], w.posZ[id]
	local function valid(p: number, reach: number): number?
		if c.pTeam[p] == ally then
			return nil
		end
		local px, pz = c.px[p], c.pz[p]
		local d2 = (px - x) ^ 2 + (pz - z) ^ 2
		if d2 > reach * reach or not Sensors.detectsPoint(sim, ally, px, pz) then
			return nil
		end
		return d2
	end
	local cur = w.wTargetProj[key]
	if cur ~= 0 and Combat.isProjRef(c, cur, w.wTargetProjSerial[key]) and valid(cur, weapon.range * INTERCEPT_HYSTERESIS) then
		return cur
	end
	local best, bestD2 = 0, math.huge
	for _, p in c.strategic do
		local d2 = valid(p, weapon.range)
		if d2 and d2 < bestD2 then
			best, bestD2 = p, d2
		end
	end
	return best
end

local OK_NONE, OK_RETARGET, OK_ALLOWED = World.Overkill.NONE, World.Overkill.RETARGET, World.Overkill.ALLOWED

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

-- `gen` is the remembered target's generation (D109); nil = the live unit.
local function acceptable(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, hysteresis: number, gen: number?): number?
	local c = sim.combat
	local w = sim.world
	if w.slot[t] ~= nil and w.ally[t] == w.ally[id] and (gen == nil or w.gen[t] == gen) then
		return nil
	end
	local kx, kz, level, defIndex = Sensors.knownTarget(sim, w.ally[id], t, gen)
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

local function score(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, dist: number, gen: number?): number
	local team = sim.world.ally[id]
	local _, _, level, defIndex = Sensors.knownTarget(sim, team, t, gen)
	-- type priorities only for targets whose type the team knows (D107)
	-- (a landed aircraft ranks as the ground unit it is for now, S-71)
	local weight = if Sensors.typeKnown(sim, team, t, level) then priorityWeight(weapon.priorityMasks, Sensors.knownCategories(sim, team, t, level, defIndex :: number)) else 1
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

-- Best acceptable enemy within range: (target, its generation, score);
-- (0, 0, 0) when none.
-- Candidates come from the contact grid (true positions), gathered wide
-- enough that every enemy whose believed position is in range is among
-- them: acceptance is decided on the believed position (D101).
-- Candidates of one search (scratch, reused): target, generation, score,
-- doomed (S-29).
local cT, cGen, cScore, cDoomed = {} :: { number }, {} :: { number }, {} :: { number }, {} :: { boolean }
local LOF_TRIES = 2 -- candidates checked for a clear shot, best first (S-32; 4 cost 1.5 ms more at peak)

local function directFire(weapon: Defs.WeaponDef): boolean
	local t = weapon.type
	return t == "HITSCAN" or t == "BEAM" or t == "BALLISTIC"
end

-- Whether unit `id`'s weapon has a line of fire to target `t` where its
-- team believes it is (S-32).
local function clearShot(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, gen: number): boolean
	local w = sim.world
	local kx, kz, level, defIndex = Sensors.knownTarget(sim, w.ally[id], t, gen)
	if kx == nil or kz == nil then
		return false
	end
	if not Sensors.typeKnown(sim, w.ally[id], t, level) then
		defIndex = nil
	end
	return Combat.unitLineOfFire(sim.combat, w, id, weapon, t, defIndex, kx :: number, kz :: number)
end

-- The best acceptable target: (target, generation, score, doomed, clear).
-- Preference: not doomed before doomed (S-29), then score, then the lower
-- ID. Direct-fire weapons take the first of the best LOF_TRIES with a line
-- of fire; with none, the best one anyway (aimed at but not fired at:
-- Weapons marks it blocked, attack-moves go on). (0, 0, 0, false, false)
-- when nothing is acceptable.
local function search(sim: Types.Sim, id: number, weapon: Defs.WeaponDef): (number, number, number, boolean, boolean)
	local c = sim.combat
	local w = sim.world
	local m = 0
	local reach = weapon.range + c.maxRadius + (if weapon.canTargetRadar or weapon.type == "TORPEDO" then maxRadarError(sim) else 0)
	local n = ContactGrid.query(c.contacts, w, w.posX[id], w.posZ[id], reach, w.ally[id], candidates)
	for i = 1, n do
		local t = candidates[i]
		local dist = acceptable(sim, id, weapon, t, 1)
		if dist ~= nil then
			m += 1
			cT[m], cGen[m], cScore[m] = t, w.gen[t], score(sim, id, weapon, t, dist)
			cDoomed[m] = Combat.doomed(c, w, t) and Sensors.level(sim, w.ally[id], t) == VISIBLE
		end
	end
	-- remembered structures that are no longer there: the team doesn't know
	if weapon.canTargetRadar then
		local ally = w.ally[id]
		for _, gid in sim.sensors.ghostIds[ally] or {} do
			local ghost = sim.sensors.ghosts[ally][gid]
			if not World.isRef(w, gid, ghost.gen) then
				local dist = acceptable(sim, id, weapon, gid, 1, ghost.gen)
				if dist ~= nil then
					m += 1
					cT[m], cGen[m], cScore[m], cDoomed[m] = gid, ghost.gen, score(sim, id, weapon, gid, dist, ghost.gen), false
				end
			end
		end
	end
	local checkLof = sim.map ~= nil and directFire(weapon)
	local first = 0
	local fT, fGen, fScore, fDoomed = 0, 0, 0, false -- the best one, for the fallback
	for try = 1, if checkLof then LOF_TRIES else 1 do
		local bi = 0
		for i = 1, m do
			if cT[i] == 0 then
				continue -- tried
			end
			if bi == 0 then
				bi = i
			else
				local a, b = cDoomed[i], cDoomed[bi]
				if (a ~= b and not a) or (a == b and (cScore[i] > cScore[bi] or (cScore[i] == cScore[bi] and cT[i] < cT[bi]))) then
					bi = i
				end
			end
		end
		if bi == 0 then
			break
		end
		if first == 0 then
			first = bi
			fT, fGen, fScore, fDoomed = cT[bi], cGen[bi], cScore[bi], cDoomed[bi]
		end
		if not checkLof or clearShot(sim, id, weapon, cT[bi], cGen[bi]) then
			return cT[bi], cGen[bi], cScore[bi], cDoomed[bi], true
		end
		if bi ~= first then
			cT[bi] = 0 -- tried and blocked (the first is kept for the fallback)
		else
			cScore[bi], cDoomed[bi] = -1, true -- rank it last from now on
		end
	end
	return fT, fGen, fScore, fDoomed, false
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
		local staggerTick = (phaseOf(id) + tick) % STAGGER == 0
		local attacker = w.lastAttacker[id]
		if not World.isRef(w, attacker, w.lastAttackerGen[id]) then
			attacker = 0 -- gone, or its ID now belongs to another unit (D109)
		end

		local groundOrder = sim.air.groundX[id] ~= nil
		local forced = sim.orders.forced[id] -- an attack order's target (Orders, S-4)
		local forcedGen = sim.orders.forcedGen[id]
		for slot = 1, count do
			local key = id * 8 + slot - 1
			local weapon = p.weapons[slot]
			local searchNow = staggerTick or w.wOverkill[key] == OK_RETARGET
			if groundOrder and (weapon.type == "BOMB" or weapon.type == "BALLISTIC") then
				World.setTarget(w, key, 0) -- bombing / shelling the ordered spot (Air.bombAim, S-68)
				continue
			end
			if weapon.manualFire then
				World.setTarget(w, key, 0) -- fires only at an attack-ground point (S-48)
				continue
			end
			-- interceptors: enemy strategic missiles before anything else (S-48)
			if weapon.intercepts then
				local p = if fs ~= HOLD_FIRE and #sim.combat.strategic > 0 then interceptTarget(sim, id, weapon, key) else 0
				w.wTargetProj[key] = p
				w.wTargetProjSerial[key] = if p ~= 0 then sim.combat.pSerial[p] else 0
				if p ~= 0 then
					World.setTarget(w, key, 0)
					continue
				end
			end

			if forced and acceptable(sim, id, weapon, forced, 1, forcedGen) ~= nil then
				World.setTarget(w, key, forced, forcedGen) -- ordered: overrides fire states and search
				continue
			end
			local cur = w.wTarget[key]
			local curGen = w.wTargetGen[key]
			local curDist: number? = nil
			if cur ~= 0 then
				curDist = acceptable(sim, id, weapon, cur, RANGE_HYSTERESIS, curGen)
				local keep = fs ~= HOLD_FIRE and (fs ~= RETURN_FIRE or cur == attacker) and curDist ~= nil
				if not keep then
					cur = 0
					World.setTarget(w, key, 0)
				end
			end

			-- terrain blocks the shot at the current target (Weapons, S-32):
			-- on the stagger tick, switch to a target with a clear shot if any
			if cur ~= 0 and searchNow and fs ~= RETURN_FIRE and w.wBlocked[key] == 1 then
				local best, bestGen, _, doomed, clear = search(sim, id, weapon)
				if clear and best ~= cur then
					World.setTarget(w, key, best, bestGen)
					w.wOverkill[key] = if doomed then OK_ALLOWED else OK_NONE
				end
				continue
			end

			-- guided missiles: switch to a clearly better (e.g. lockable) target
			if cur ~= 0 and searchNow and fs ~= RETURN_FIRE and isGuided(weapon) then
				local best, bestGen, bestScore, doomed = search(sim, id, weapon)
				if best ~= 0 and best ~= cur and not doomed and bestScore > score(sim, id, weapon, cur, curDist :: number, curGen) * SWITCH_MARGIN then
					World.setTarget(w, key, best, bestGen)
				end
				continue
			end

			if cur == 0 and searchNow and fs ~= HOLD_FIRE then
				local best, bestGen, doomed = 0, 0, false
				if fs == RETURN_FIRE then
					if attacker ~= 0 and acceptable(sim, id, weapon, attacker, 1) ~= nil then
						best, bestGen = attacker, w.gen[attacker]
					end
				else
					best, bestGen, _, doomed = search(sim, id, weapon)
				end
				World.setTarget(w, key, best, bestGen)
				w.wOverkill[key] = if doomed then OK_ALLOWED else OK_NONE
			elseif w.wOverkill[key] == OK_RETARGET then
				w.wOverkill[key] = OK_NONE -- held fire or kept a target: back to the stagger
			end
		end
	end
end
