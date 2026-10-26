--!strict
--!native
-- System 4: target acquisition (guide 10.2).
--
-- Targeting follows team knowledge, never server truth (D100). Each weapon
-- keeps its current target while it stays valid: an enemy the team knows
-- about (VISIBLE, or a RADAR contact: every weapon takes blips unless its
-- canTargetRadar is false, S-202, the user; guide 11.4), a category it can hit, within range (+10% hysteresis, measured to
-- the known position) and arc, and allowed by the unit's fire state.
-- Structure ghosts (remembered, not in sight) are targets only on an attack
-- order or as a manual target (S-127, the user: never picked by the search),
-- unless the team's radar covers the live structure now: then it is a blip
-- like any other (S-202);
-- one stays a target even if its structure died unseen (the team can't
-- tell). Bombers with an attack-ground order (Air) don't auto-target.
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

local Categories = require("@shared/Defs/Categories")
local Combat = require("../Combat/Combat")
local Hash = require("@shared/Util/Hash")
local ContactGrid = require("../Combat/ContactGrid")
local EW = require("../EW")
local Sensors = require("../Sensors")
local Orders = require("../Orders")
local Defs = require("@shared/Defs/Defs")
local Types = require("../Types")
local World = require("../World")

local STAGGER = 6
local SENSOR_EVERY = 2 -- Sensors' cadence (Sim's system table): visibility changes on these ticks

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
local INTERCEPT_REACH = 1.5 -- anti-nukes: engage a missile aimed inside the cover this far out, × the radius (S-111)
-- missiles a loaded interceptor of the ally team took this tick (S-201):
-- ally → { [proj] = true }, cleared each tick
local claims: { [number]: { [number]: boolean } } = {}

-- An interceptor's strategic missile (S-48): the current one while it stays
-- an enemy missile the team detects within range (+10%), else the nearest
-- such missile in range, else 0. Interceptors take turns (S-201, the user):
-- a missile that an interceptor already flies at, or that another
-- interceptor of the team ready to fire took this tick, is left to it; the others take
-- the next missile, and with none left they wait (if that interceptor
-- misses or is shot down, the missile is free again).
local function interceptTarget(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, key: number): number
	local c = sim.combat
	local w = sim.world
	local ally = w.ally[id]
	local x, z = w.posX[id], w.posZ[id]
	local tactical = (weapon.intercepts :: { chance: number, tactical: boolean? }).tactical == true
	local weapons = sim.defs.weaponByIndex
	local function valid(p: number, reach: number): number?
		if c.pTeam[p] == ally then
			return nil
		end
		if tactical then
			-- point defence (S-149): enemy missiles and rockets, not strategic
			-- missiles (anti-nukes take those) or other interceptors
			local pw = weapons[c.pWeapon[p]]
			if pw.strategic or pw.intercepts or not (pw.type == "HOMING" or pw.rocket) then
				return nil
			end
		end
		-- anti-nukes (S-111, client request 46): a missile whose aim point is
		-- inside the cover radius, engaged on its way in (within
		-- INTERCEPT_REACH × the radius)
		local goal = c.pGoal[p]
		if weapon.interceptOnly and not tactical then
			if goal == nil or (goal[1] - x) ^ 2 + (goal[3] - z) ^ 2 > weapon.range * weapon.range then
				return nil
			end
			reach *= INTERCEPT_REACH
		end
		local px, pz = c.px[p], c.pz[p]
		local d2 = (px - x) ^ 2 + (pz - z) ^ 2
		-- (anti-nukes spot strategic missiles anywhere, whatever the team's
		-- sensors: the user, S-111; point defence needs to detect them)
		if d2 > reach * reach or ((tactical or not weapon.interceptOnly) and not Sensors.detectsPoint(sim, ally, px, pz)) then
			return nil
		end
		return d2
	end
	-- one interceptor per missile (S-111): skip a missile one of the team's
	-- interceptors already chases
	local chased: { [number]: boolean } = {}
	for _, q in c.proj do
		local tp = c.pTargetProj[q]
		if tp ~= nil and tp ~= 0 and c.pTeam[q] == ally then
			chased[tp] = true
		end
	end
	local taken = claims[ally]
	if taken == nil then
		taken = {}
		claims[ally] = taken
	end
	-- only an interceptor ready to fire (loaded, reloaded) claims its
	-- missile: an empty or reloading one tracks it without keeping the
	-- others off (one that just fired must not take the next missile from
	-- a site that can shoot it now)
	local loaded = (w.wStock[key] or 1) > 0 and w.wReload[key] <= 0
	local cur = w.wTargetProj[key]
	if cur ~= 0 and not chased[cur] and not taken[cur] and Combat.isProjRef(c, cur, w.wTargetProjSerial[key]) and valid(cur, weapon.range * INTERCEPT_HYSTERESIS) then
		if loaded then
			taken[cur] = true
		end
		return cur
	end
	local best, bestD2 = 0, math.huge
	for _, p in (if tactical then c.proj else c.strategic) do
		local d2 = if chased[p] or taken[p] then nil else valid(p, weapon.range)
		if d2 and d2 < bestD2 then
			best, bestD2 = p, d2
		end
	end
	if best ~= 0 and loaded then
		taken[best] = true
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

-- A remembered structure (GHOST) that is alive and under the team's radar
-- now: the search takes it like a blip (S-202).
local function radarGhost(sim: Types.Sim, ally: number, t: number, gen: number?): boolean
	local onRadar = sim.sensors.radarGhosts[ally]
	return onRadar ~= nil and onRadar[t] == true and sim.world.slot[t] ~= nil and (gen == nil or sim.world.gen[t] == gen)
end

-- `gen` is the remembered target's generation (D109); nil = the live unit.
-- Also returns what it looked up (level, def index, type known, known
-- categories), so a search scores the target without asking again (S-74).
-- `manual`: an attack order's or manual target, which may be a ghost (a
-- remembered structure not in sight); the automatic search never takes one
-- (S-127, the user).
local function acceptable(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, hysteresis: number, gen: number?, manual: boolean?): (number?, number, number, boolean, number)
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
	local known = Sensors.typeKnown(sim, w.ally[id], t, level) or (level == Sensors.Level.RADAR and sim.defs.unitByIndex[w.defIndex[t]].spoof ~= nil) -- a decoy passes for its spoof (S-109)
	local cats = Sensors.knownCategories(sim, w.ally[id], t, level, defIndex :: number)
	if band(weapon.targetMask, cats) == 0 then
		return nil
	end
	local radius = if known then tp.radius else 0
	local allowed = level == VISIBLE
		or (level == RADAR and weapon.canTargetRadar)
		or (level == GHOST and weapon.canTargetRadar and (manual == true or radarGhost(sim, w.ally[id], t, gen)))
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
	return dist, level, defIndex :: number, known, cats
end

-- Every category bit Sensors.knownCategories can ever report for a live unit
-- of this def: its own, its domain's (an unidentified contact, D107) and,
-- for aircraft, GROUND (landed, S-71). A weapon whose targets share none
-- can't accept it, whatever the team knows (S-74: skips the sensor lookups).
local CB = Categories.Bit
local possibleCache: { [any]: { [number]: number } } = setmetatable({}, { __mode = "k" }) :: any
local function possibleMask(sim: Types.Sim, defIndex: number): number
	local byDef = possibleCache[sim.defs]
	if byDef == nil then
		byDef = {}
		possibleCache[sim.defs] = byDef
	end
	local m = byDef[defIndex]
	if m == nil then
		local def = sim.defs.unitByIndex[defIndex]
		m = def.categoryMask
		if def.domain == "air" then
			m = bit32.bor(m, Sensors.DOMAIN_MASK.air, CB.GROUND)
		else
			m = bit32.bor(m, Sensors.DOMAIN_MASK.surface, Sensors.DOMAIN_MASK.submerged)
		end
		byDef[defIndex] = m
	end
	return m
end

local function isGuided(weapon: Defs.WeaponDef): boolean
	return weapon.guidance ~= nil and weapon.type == "HOMING"
end

local function score(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, t: number, dist: number, gen: number?): number
	local team = sim.world.ally[id]
	local _, _, level, defIndex = Sensors.knownTarget(sim, team, t, gen)
	-- type priorities only for targets whose type the team knows (D107)
	-- (a landed aircraft ranks as the ground unit it is for now, S-71)
	local weight = if Sensors.shownDef(sim, team, t, level, defIndex :: number) ~= nil then priorityWeight(weapon.priorityMasks, Sensors.knownCategories(sim, team, t, level, defIndex :: number)) else 1
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
		if band(weapon.targetMask, possibleMask(sim, w.defIndex[t])) == 0 then
			continue -- (S-74) it can never be this weapon's target
		end
		local dist, level, _, known, cats = acceptable(sim, id, weapon, t, 1)
		if dist ~= nil then
			m += 1
			-- the score as score() gives it, from what acceptable looked up (S-74)
			local s = (if known then priorityWeight(weapon.priorityMasks, cats) else 1) / math.max(dist, 1)
			if isGuided(weapon) and EW.canLock(sim, id, weapon, t, dist) then
				s *= LOCK_PREFERENCE
			end
			cT[m], cGen[m], cScore[m] = t, w.gen[t], s
			cDoomed[m] = Combat.doomed(c, w, t) and level == VISIBLE
		end
	end
	-- (ghosts, remembered structures not in sight, are for manual orders
	-- only: the search never takes one, S-127)
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
	table.clear(claims)

	for _, id in w.ids do
		local count = w.weaponCount[id]
		if count == 0 or w.buildProgress[id] < 1 or Combat.retracted(sim, id) then
			continue -- (S-87) a frame's weapons are inert until it is complete; (S-96) so are a retracted tower's
		end
		local p = profiles[w.defIndex[id]]
		local fs = w.fireState[id]
		local staggerTick = (phaseOf(id) + tick) % STAGGER == 0
		local sensorTick = tick % SENSOR_EVERY == 0
		local attacker = w.lastAttacker[id]
		if not World.isRef(w, attacker, w.lastAttackerGen[id]) then
			attacker = 0 -- gone, or its ID now belongs to another unit (D109)
		end

		local groundOrder = sim.air.groundX[id] ~= nil
		local forced = sim.orders.forced[id] -- an attack order's target (Orders, S-4)
		local forcedGen = sim.orders.forcedGen[id]
		local blind = false
		local retarget = false
		if forced == nil then
			-- the last attack order's target, kept until STOP (S-115, client
			-- request 49): taken whenever it is in range, whatever the fire
			-- state (S-120: manual targeting takes priority); else the search.
			-- While it lives but the team doesn't see it (S-125, client
			-- request 57), the unit keeps to its last known position: weapons
			-- that shoot a point fire there, the others hold, and none takes
			-- another target. When it dies, the search runs at once.
			local o = sim.orders
			local m = o.manual[id]
			-- (a remembered structure's ghost counts while the team remembers
			-- it, even if the structure died unseen: S-127)
			local ghost = if m ~= nil then (sim.sensors.ghosts[w.ally[id]] or {})[m] else nil
			if m ~= nil and not World.isRef(w, m, o.manualGen[id]) and ghost ~= nil and ghost.gen == o.manualGen[id] then
				forced, forcedGen = m, o.manualGen[id]
				o.manualX[id], o.manualZ[id], o.manualBlind[id] = ghost.x, ghost.z, nil
			elseif m ~= nil then
				if World.isRef(w, m, o.manualGen[id]) then
					forced, forcedGen = m, o.manualGen[id]
					local kx, kz = Sensors.knownTarget(sim, w.ally[id], m, o.manualGen[id])
					if kx ~= nil and kz ~= nil then
						o.manualX[id], o.manualZ[id], o.manualBlind[id] = kx, kz, nil
					elseif o.manualX[id] ~= nil then
						blind = true
						o.manualBlind[id] = true
					end
				else
					Orders.dropManual(sim, id) -- gone: back to its own targets now
					retarget = true
				end
			end
		end
		for slot = 1, count do
			local key = id * 8 + slot - 1
			local weapon = p.weapons[slot]
			-- a weapon with no target also searches on every sensor tick, when
			-- what the team sees changes (S-185): the staggered phase made
			-- some IDs react a tick or more later to a new enemy, and in close
			-- mirror fights the first volley decided (odd IDs won 34 of 40)
			local idleNow = sensorTick and w.wTarget[key] == 0
			local searchNow = staggerTick or retarget or idleNow or w.wOverkill[key] == OK_RETARGET
			if groundOrder and (weapon.type == "BOMB" or weapon.type == "BALLISTIC" or weapon.type == "BEAM" or weapon.type == "HITSCAN") then
				World.setTarget(w, key, 0) -- bombing / shelling the ordered spot (Air.bombAim, S-68)
				continue
			end
			if weapon.manualFire then
				World.setTarget(w, key, 0) -- fires only at an attack-ground point (S-48)
				continue
			end
			-- fires only standing still (S-111: the mobile anti-nuke's launcher raises)
			if weapon.stationary and bit32.band(w.state[id], World.State.MOVING) ~= 0 then
				World.setTarget(w, key, 0)
				w.wTargetProj[key] = 0
				continue
			end
			-- interceptors: enemy strategic missiles before anything else (S-48)
			if weapon.intercepts then
				local pool = if weapon.intercepts.tactical then #sim.combat.proj else #sim.combat.strategic
				local p = if fs ~= HOLD_FIRE and pool > 0 then interceptTarget(sim, id, weapon, key) else 0
				w.wTargetProj[key] = p
				w.wTargetProjSerial[key] = if p ~= 0 then sim.combat.pSerial[p] else 0
				if p ~= 0 or weapon.interceptOnly then
					World.setTarget(w, key, 0) -- (anti-nukes never take units, S-111)
					continue
				end
			end

			if forced and acceptable(sim, id, weapon, forced, 1, forcedGen, true) ~= nil then
				World.setTarget(w, key, forced, forcedGen) -- ordered: overrides fire states and search
				continue
			end
			if blind and (sim.orders.manualX[id] - w.posX[id]) ^ 2 + (sim.orders.manualZ[id] - w.posZ[id]) ^ 2 <= weapon.range * weapon.range then
				-- the manual target, unseen, its last known position in range:
				-- Weapons fires there if it can shoot a point, else holds; no
				-- other target (S-125). Out of range, the search as for a seen
				-- target out of range (S-115).
				World.setTarget(w, key, 0)
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
