--!strict
-- Shield dome generators (S-79, client request 40; the user's rules, first
-- tried in the client's C-87 prototype). A structure whose def has
-- `shield = { radius, capacity, recharge, power }` holds a dome of `radius`
-- round its base against enemy shells (Shared/Combat/ShieldField has the
-- field itself):
--   * enemy projectiles (shells, rockets, bombs, missiles; not torpedoes,
--     strategic missiles, or interceptors chasing one) that pass through the
--     dome's surface are slowed and turned in the field inside it (S-83):
--     head-on ones back out, off-centre ones round the dome and on (S-82). A
--     turned shell stays live: it flies on and explodes where it lands (a
--     missile loses its lock); one that comes back is caught again. One that
--     reaches the dome's core still moving in breaks through, slowed, and
--     carries on. Shots fired from inside pass out freely; allies' shells are
--     never touched. A hitscan or beam shot (or a shell resolved like one at
--     the projectile cap) from outside a dome is stopped at its surface like
--     a light shell (S-89): no damage, its mass in charge;
--   * a shell lighter than ShieldField.ABSORB_MASS is destroyed where it
--     crosses the surface (S-85): no burst, no damage;
--   * charge is counted in shell masses (ShieldField.mass): a turned or
--     destroyed shell costs HIT_COST × its mass, a breach BREACH_COST × it. The field's
--     force follows the charge (full at 50% and above);
--   * at 0 the dome collapses; it rises again at RAISE_AT of capacity;
--   * recharging draws `power` power per second (called by Build.step with
--     the other economy consumers): `recharge` charge per second at the
--     team's power stall ratio. Full, it draws nothing.
-- A generator spawned complete starts full; one built starts empty, down.
-- Generators are kept in Combat.shieldIds in the order they entered.

local ShieldField = require("@shared/Combat/ShieldField")
local Combat = require("./Combat/Combat")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local Types = require("./Types")
local World = require("./World")

local TOGGLED_ON = World.State.TOGGLED_ON

local Shield = {}

Shield.DT = 1 / 15
Shield.HIT_COST = 1 -- charge per unit of mass turned back
Shield.BREACH_COST = 0.5 -- charge per unit of mass that broke through
Shield.RAISE_AT = 0.25 -- of capacity: a collapsed dome rises again
Shield.REPEL_TTL = 6 -- seconds a turned shell flies on at least before it bursts

local sqrt = math.sqrt
local FREE, DONE = ShieldField.FREE, ShieldField.DONE

local function shieldOf(sim: Types.Sim, id: number): any
	return sim.defs.unitByIndex[sim.world.defIndex[id]].shield
end

-- Lifecycle hooks.
function Shield.added(sim: Types.Sim, id: number)
	local s = shieldOf(sim, id)
	if s then
		local c = sim.combat
		local built = sim.world.buildProgress[id] >= 1
		table.insert(c.shieldIds, id)
		c.shieldCharge[id] = if built then s.capacity else 0
		c.shieldUp[id] = built
		c.shieldPower[id] = 1
	end
end

function Shield.removed(sim: Types.Sim, id: number)
	local c = sim.combat
	if c.shieldCharge[id] ~= nil then
		c.shieldCharge[id], c.shieldUp[id], c.shieldPower[id] = nil, nil, nil
		local i = table.find(c.shieldIds, id)
		if i then
			table.remove(c.shieldIds, i)
		end
	end
end

-- The dome's charge as a fraction of capacity (0..1); nil for no generator.
function Shield.fraction(sim: Types.Sim, id: number): number?
	local charge = sim.combat.shieldCharge[id]
	if charge == nil then
		return nil
	end
	return charge / shieldOf(sim, id).capacity
end

-- Is the dome recharging: below capacity, built, and getting power?
function Shield.recharging(sim: Types.Sim, id: number): boolean
	local c = sim.combat
	local charge = c.shieldCharge[id]
	return charge ~= nil
		and sim.world.buildProgress[id] >= 1
		and charge < shieldOf(sim, id).capacity
		and (c.shieldPower[id] or 0) > 0
end

-- The dome's centre: the generator's base.
function Shield.center(sim: Types.Sim, id: number): (number, number, number)
	local w = sim.world
	return w.posX[id], Combat.unitBase(sim.combat, w, id), w.posZ[id]
end

-- The field's force now (0..1; 0 while the dome is down).
function Shield.force(sim: Types.Sim, id: number): number
	local c = sim.combat
	if not c.shieldUp[id] then
		return 0
	end
	return ShieldField.force(c.shieldCharge[id] / shieldOf(sim, id).capacity)
end

-- A lingering beam stopped by a dome (S-117, client request 51) drains it
-- over the beam's duration: its best damage / 150 (the shell-mass unit,
-- uncapped) × BEAM_DRAIN in all. A Radiance beam takes 250 (42% of a
-- Phalanx, 62% of a Carapace), an Inferno beam about 142.
Shield.BEAM_DRAIN = 2.5 -- (12.5 until S-150 cut capacities 5×: the same share of a dome)

-- The whole drain a lingering beam `weapon` puts on a dome (S-117).
function Shield.beamDrain(weapon: any): number
	local best = 0
	for _, v in weapon.damage do
		best = math.max(best, v)
	end
	return best / 150 * Shield.BEAM_DRAIN
end

-- Takes `amount` of charge; at 0 the dome collapses.
function Shield.drain(sim: Types.Sim, id: number, amount: number)
	local c = sim.combat
	local charge = math.max(0, c.shieldCharge[id] - amount)
	c.shieldCharge[id] = charge
	if charge <= 0 then
		c.shieldUp[id] = false
	end
end

-- Recharge (an economy consumer, called by Build.step).
function Shield.drainStep(sim: Types.Sim, demandP: { [number]: number })
	local c = sim.combat
	local w = sim.world
	local dt = Shield.DT
	for _, id in c.shieldIds do
		if w.buildProgress[id] < 1 then
			continue
		end
		local s = shieldOf(sim, id)
		local charge = c.shieldCharge[id]
		-- switched off (TOGGLE, S-154, the user: "a shield can be turned off to
		-- save power"): the dome is down, no upkeep, no recharge; the charge
		-- it has is kept. Switched on, it rises again at RAISE_AT
		if bit32.band(w.state[id], TOGGLED_ON) == 0 then
			c.shieldUp[id] = false
			c.shieldPower[id] = 0
			continue
		end
		if not c.shieldUp[id] and charge >= Shield.RAISE_AT * s.capacity then
			c.shieldUp[id] = true
		end
		if charge >= s.capacity then
			continue
		end
		local ratio = 1
		if s.power > 0 then
			local team = w.team[id]
			local acc = sim.eco.accounts[team]
			if acc == nil then
				continue
			end
			demandP[team] += s.power
			ratio = math.min(Economy.effective(acc, 0, s.power), Economy.allowance(acc.power) / (s.power * dt))
			ratio = math.clamp(ratio, 0, 1)
			acc.power.spent += s.power * dt * ratio
		end
		c.shieldPower[id] = ratio
		charge = math.min(s.capacity, charge + s.recharge * dt * ratio)
		c.shieldCharge[id] = charge
		if not c.shieldUp[id] and charge >= Shield.RAISE_AT * s.capacity then
			c.shieldUp[id] = true
		end
	end
end

local masses: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

-- A weapon's shell mass (ShieldField.mass), cached.
function Shield.mass(weapon: any): number
	local m = masses[weapon]
	if m == nil then
		m = ShieldField.mass(weapon)
		masses[weapon] = m
	end
	return m
end

-- May a projectile of this weapon meet shield fields at all?
function Shield.affects(weapon: any): boolean
	return weapon.type ~= "TORPEDO" and weapon.type ~= "HITSCAN" and weapon.type ~= "BEAM" and not weapon.strategic
end

-- Steps projectile `id` (state x..vz after guidance, gravity g) through a
-- dome's field when it is in one or about to enter one this tick. Returns
-- the stepped state and true, or false when no dome is involved (the
-- caller steps it plainly), then true when the dome destroyed it (the
-- caller removes it: S-85).
function Shield.deflect(
	sim: Types.Sim,
	id: number,
	weapon: any,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	g: number
): (number, number, number, number, number, number, boolean, boolean)
	local c = sim.combat
	local w = sim.world
	local dt = Shield.DT
	local dome = c.pShield[id]
	if dome ~= nil and c.shieldCharge[dome] == nil then
		-- the generator is gone: no field
		c.pShield[id], c.pShieldPhase[id] = nil, nil
		dome = nil
	end
	if dome == nil then
		local speed = sqrt(vx * vx + vy * vy + vz * vz)
		local side = c.pTeam[id]
		for _, d in c.shieldIds do
			if c.shieldUp[d] and w.ally[d] ~= side then
				local cx, cy, cz = Shield.center(sim, d)
				local radius = shieldOf(sim, d).radius
				if ShieldField.near(x, y, z, speed, cx, cy, cz, radius, dt) and ShieldField.onCourse(x, y, z, vx, vy, vz, cx, cy, cz, radius) then
					dome = d
					break
				end
			end
		end
		if dome == nil then
			return x, y, z, vx, vy, vz, false, false
		end
	end
	local d = dome :: number
	local s = shieldOf(sim, d)
	local cx, cy, cz = Shield.center(sim, d)
	local force = Shield.force(sim, d)
	local mass = Shield.mass(weapon)
	local before = c.pShieldPhase[id] or FREE
	local x1, y1, z1, vx1, vy1, vz1, phase, event, hx, hy, hz =
		ShieldField.step(x, y, z, vx, vy, vz, g, cx, cy, cz, s.radius, force, mass, before, dt)
	if before == FREE and phase ~= FREE and phase ~= DONE then
		Combat.addEvent(c, { kind = "SHIELD_FIELD", tick = sim.tick, unit = d, other = id })
	end
	if phase == FREE or phase == DONE then
		-- (a shell thrown out that comes back is caught again)
		c.pShield[id], c.pShieldPhase[id] = nil, nil
	else
		c.pShield[id], c.pShieldPhase[id] = d, phase
	end
	if event == ShieldField.TURN then
		Shield.drain(sim, d, Shield.HIT_COST * mass)
		-- it won't hit what it was fired at: a missile loses its lock, and the
		-- shooter stops counting its damage as on the way (S-29)
		c.pTarget[id] = 0
		c.pDecoy[id] = nil
		Combat.dropPending(c, id)
		c.pTtl[id] = math.max(c.pTtl[id], Shield.REPEL_TTL)
		Combat.addEvent(c, { kind = "SHIELD_HIT", tick = sim.tick, unit = d, other = id, x = hx, y = hy, z = hz, breach = false, mass = mass })
	elseif event == ShieldField.BREACH then
		Shield.drain(sim, d, Shield.BREACH_COST * mass)
		Combat.addEvent(c, { kind = "SHIELD_HIT", tick = sim.tick, unit = d, other = id, x = hx, y = hy, z = hz, breach = true, mass = mass })
	elseif event == ShieldField.ABSORB then
		Shield.drain(sim, d, Shield.HIT_COST * mass)
		Combat.addEvent(c, { kind = "SHIELD_HIT", tick = sim.tick, unit = d, other = id, x = hx, y = hy, z = hz, absorbed = true, mass = mass })
		return x1, y1, z1, vx1, vy1, vz1, true, true
	end
	return x1, y1, z1, vx1, vy1, vz1, true, false
end

-- The first enemy dome, up, whose surface the segment from (sx, sy, sz)
-- to (ex, ey, ez) of side `side` enters from outside: the generator (0 for
-- none) and the point (S-89; S-123: re-checked every tick for a burning beam).
function Shield.firstDome(sim: Types.Sim, side: number, sx: number, sy: number, sz: number, ex: number, ey: number, ez: number): (number, number, number, number)
	local c = sim.combat
	local w = sim.world
	local dx, dy, dz = ex - sx, ey - sy, ez - sz
	local a = dx * dx + dy * dy + dz * dz
	if a < 1e-9 then
		return 0, 0, 0, 0
	end
	local best, bestT = 0, math.huge
	for _, d in c.shieldIds do
		if c.shieldUp[d] and w.ally[d] ~= side then
			local cx, cy, cz = Shield.center(sim, d)
			local r = shieldOf(sim, d).radius
			local fx, fy, fz = sx - cx, sy - cy, sz - cz
			local cc = fx * fx + fy * fy + fz * fz - r * r
			if cc > 0 then -- the muzzle is outside this dome
				local b = fx * dx + fy * dy + fz * dz
				local disc = b * b - a * cc
				if disc >= 0 then
					local t = (-b - sqrt(disc)) / a -- the first crossing
					if t >= 0 and t <= 1 and (t < bestT or (t == bestT and d < best)) then
						best, bestT = d, t
					end
				end
			end
		end
	end
	if best == 0 then
		return 0, 0, 0, 0
	end
	return best, sx + dx * bestT, sy + dy * bestT, sz + dz * bestT
end

-- A shot stopped at dome `gen`'s surface at (hx, hy, hz): it drains the
-- shot's mass and records a SHIELD_HIT (absorbed, projectile 0).
function Shield.absorbShot(sim: Types.Sim, gen: number, hx: number, hy: number, hz: number, weapon: any)
	local mass = Shield.mass(weapon)
	Shield.drain(sim, gen, Shield.HIT_COST * mass)
	Combat.addEvent(sim.combat, { kind = "SHIELD_HIT", tick = sim.tick, unit = gen, other = 0, x = hx, y = hy, z = hz, absorbed = true, mass = mass })
end

-- A hitscan shot by side `side` from (sx, sy, sz) to (ex, ey, ez): the
-- first enemy dome, up, whose surface the segment enters from outside
-- stops it there (S-89). Returns the generator (0 for none) and the point;
-- drains the shot's mass and records a SHIELD_HIT (absorbed, projectile 0).
function Shield.intercept(sim: Types.Sim, side: number, sx: number, sy: number, sz: number, ex: number, ey: number, ez: number, weapon: any): (number, number, number, number)
	local best, hx, hy, hz = Shield.firstDome(sim, side, sx, sy, sz, ex, ey, ez)
	if best ~= 0 then
		Shield.absorbShot(sim, best, hx, hy, hz, weapon)
	end
	return best, hx, hy, hz
end

table.insert(Lifecycle.addedHooks, Shield.added)
table.insert(Lifecycle.removalHooks, Shield.removed)

return Shield
