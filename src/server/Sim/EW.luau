--!strict
-- Missile guidance and electronic warfare (guide 11.5–11.6).
--
-- HOMING weapons have a guidance type with its own rules:
--
--   IR       lock: target VISIBLE and within lockRange. Jamming and stealth
--            don't matter. Defeated by DIRCM and flares.
--   RADAR    lock: target VISIBLE or a RADAR contact, within lockRange ×
--            radarSignature, and not inside its own team's jam field unless
--            closer than burnThrough × lockRange. Midcourse: a target that
--            enters a jam field beyond burn-through breaks the lock.
--            Defeated by chaff.
--   COMMAND  lock: target VISIBLE to the launcher's team and within lock
--            range. For the whole flight (checked every tick) the launcher
--            must be alive and its team must still see the target; losing
--            either breaks guidance. Jamming, chaff, flares and DIRCM have
--            no effect.
--   ACOUSTIC torpedoes: sonar contacts (Targeting); no EW checks.
--
-- Flight checks are cheap and event-based:
--   1. launch (Weapons): no lock, no launch;
--   2. midcourse, every MIDCOURSE_PERIOD ticks: LOST_LOCK clears the target,
--      so the missile flies straight until its lifetime runs out;
--   3. terminal, once, when the missile could reach terminalRange this tick:
--      the target rolls its countermeasures; on success a DECOYED event and
--      the missile veers off DECOY_TURN with no target.
--
-- Countermeasures: flares (vs IR) and chaff (vs RADAR) spend a charge per
-- roll and are refilled when an aircraft finishes rearming. DIRCM (vs IR)
-- has no charges: it engages at most one missile per cooldown, recharging at
-- the team's power stall ratio while draining power continuously. A salvo
-- that arrives within one cooldown overwhelms it.
--
-- Every roll draws from sim.rng in fixed system order, so replays are exact.

local Combat = require("./Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local EWState = require("./EWState")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local Sensors = require("./Sensors")
local Types = require("./Types")

local EW = {}

EW.DT = 1 / 15
EW.MIDCOURSE_PERIOD = 5 -- ticks between midcourse checks
EW.BURN_THROUGH = 0.35 -- default fraction of lockRange
EW.TERMINAL_RANGE = 40 -- studs, default
EW.DECOY_TURN = math.rad(60) -- a decoyed missile's sideways veer
EW.Flag = table.freeze({ TERMINAL = 1, LOST = 2 }) -- Combat.pFlags bits

local L = Sensors.Level
local TERMINAL, LOST = EW.Flag.TERMINAL, EW.Flag.LOST
local sin, cos = math.sin, math.cos

local function unitDef(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- Fills flare and chaff charges from the def; DIRCM starts ready.
function EW.onSpawn(sim: Types.Sim, id: number)
	local cm = unitDef(sim, id).countermeasures
	if cm == nil then
		return
	end
	EW.refill(sim, id)
	if cm.dircm then
		sim.ew.dircmCooldown[id] = 0
	end
end

-- Refills flare and chaff charges (aircraft finishing a rearm).
function EW.refill(sim: Types.Sim, id: number)
	local cm = unitDef(sim, id).countermeasures
	if cm == nil then
		return
	end
	if cm.flares then
		sim.ew.flares[id] = cm.flares.charges
	end
	if cm.chaff then
		sim.ew.chaff[id] = cm.chaff.charges
	end
end

-- Is unit `id` inside a jam field of `team`'s?
local function inJamOf(sim: Types.Sim, team: number, id: number): boolean
	local s = sim.sensors
	if s.maps[team] == nil then
		return false
	end
	local w = sim.world
	local _, _, cell = Sensors.cellOf(s, w.posX[id], w.posZ[id])
	return Sensors.count(s, team, "jam", cell) > 0
end

-- Is unit `id` hidden by its own team's jammers (guide 11.4)?
function EW.jammed(sim: Types.Sim, id: number): boolean
	return inJamOf(sim, sim.world.team[id], id)
end

function EW.lockRange(weapon: Defs.WeaponDef): number
	return weapon.lockRange or weapon.range
end

function EW.burnThroughRange(weapon: Defs.WeaponDef): number
	return (weapon.burnThrough or EW.BURN_THROUGH) * EW.lockRange(weapon)
end

-- Launch check (guide 11.5): can `shooter` lock `target` at `dist` studs?
-- Unguided weapons and torpedoes always can.
function EW.canLock(sim: Types.Sim, shooter: number, weapon: Defs.WeaponDef, target: number, dist: number): boolean
	local guidance = weapon.guidance
	if guidance == nil or weapon.type ~= "HOMING" then
		return true
	end
	local level = Sensors.level(sim, sim.world.team[shooter], target)
	local range = EW.lockRange(weapon)
	if guidance == "IR" then
		return level == L.VISIBLE and dist <= range
	elseif guidance == "RADAR" then
		if level ~= L.VISIBLE and level ~= L.RADAR then
			return false
		end
		local signature = math.min(unitDef(sim, target).sensors.radarSignature, 1)
		if dist > range * signature then
			return false
		end
		return dist <= EW.burnThroughRange(weapon) or not EW.jammed(sim, target)
	elseif guidance == "COMMAND" then
		return level == L.VISIBLE and dist <= range
	end
	return true
end

-- Terminal roll: does `target` defeat a missile with this guidance?
local function defeats(sim: Types.Sim, target: number, guidance: string): boolean
	local cm = unitDef(sim, target).countermeasures
	if cm == nil then
		return false
	end
	local e = sim.ew
	local rng = sim.rng
	if guidance == "IR" then
		local dircm = cm.dircm
		if dircm and (e.dircmCooldown[target] or 0) <= 0 then
			e.dircmCooldown[target] = dircm.cooldown -- one engagement per cooldown
			if rng:chance(dircm.chance) then
				return true
			end
		end
		local flares = cm.flares
		if flares and (e.flares[target] or 0) > 0 then
			e.flares[target] -= 1
			return rng:chance(flares.chance)
		end
	elseif guidance == "RADAR" then
		local chaff = cm.chaff
		if chaff and (e.chaff[target] or 0) > 0 then
			e.chaff[target] -= 1
			return rng:chance(chaff.chance)
		end
	end
	return false
end

-- Midcourse and terminal checks for guided missile `p` (called by the
-- Projectiles system before steering). May clear the target and turn the
-- velocity.
function EW.guide(sim: Types.Sim, p: number, weapon: Defs.WeaponDef)
	local guidance = weapon.guidance
	if guidance == nil or weapon.type ~= "HOMING" then
		return
	end
	local c = sim.combat
	local w = sim.world
	local target = c.pTarget[p]
	if target == 0 or w.slot[target] == nil then
		return
	end
	local flags = c.pFlags[p]
	local x, y, z = c.px[p], c.py[p], c.pz[p]

	-- 2. midcourse (COMMAND: every tick, the link must hold all the way)
	if guidance == "COMMAND" or (sim.tick + p) % EW.MIDCOURSE_PERIOD == 0 then
		local lost = false
		if guidance == "RADAR" then
			local dx, dz = w.posX[target] - x, w.posZ[target] - z
			local bt = EW.burnThroughRange(weapon)
			lost = dx * dx + dz * dz > bt * bt and EW.jammed(sim, target)
		elseif guidance == "COMMAND" then
			local launcher = c.pOwner[p]
			lost = w.slot[launcher] == nil or Sensors.level(sim, c.pTeam[p], target) ~= L.VISIBLE
		end
		if lost then
			c.pTarget[p] = 0
			c.pFlags[p] = bit32.bor(flags, LOST)
			Combat.addEvent(c, { kind = "LOST_LOCK", tick = sim.tick, unit = target, other = p, x = x, y = y, z = z })
			return
		end
	end

	-- 3. terminal: once, when the missile could close to terminalRange this tick
	if bit32.band(flags, TERMINAL) ~= 0 then
		return
	end
	local tp = c.profiles[w.defIndex[target]]
	local ty = Combat.unitBase(c, w, target) + tp.height / 2
	local dx, dy, dz = w.posX[target] - x, ty - y, w.posZ[target] - z
	local reach = (weapon.terminalRange or EW.TERMINAL_RANGE) + ((weapon.projectileSpeed or 0) + w.speed[target]) * EW.DT
	if dx * dx + dy * dy + dz * dz > reach * reach then
		return
	end
	c.pFlags[p] = bit32.bor(flags, TERMINAL)
	if defeats(sim, target, guidance) then
		local a = if sim.rng:chance(0.5) then EW.DECOY_TURN else -EW.DECOY_TURN
		local vx, vz = c.pvx[p], c.pvz[p]
		c.pvx[p], c.pvz[p] = vx * cos(a) + vz * sin(a), vz * cos(a) - vx * sin(a)
		c.pTarget[p] = 0
		Combat.addEvent(c, { kind = "DECOYED", tick = sim.tick, unit = target, other = p, x = x, y = y, z = z })
	end
end

-- DIRCM upkeep (called by Build.step with the other economy consumers):
-- drains powerDrain per second and recharges the cooldown, both at the
-- team's power stall ratio.
function EW.drainStep(sim: Types.Sim, demandP: { [number]: number })
	local w = sim.world
	local e = sim.ew
	local eco = sim.eco
	local dt = EW.DT
	for _, id in w.ids do
		local cooldown = e.dircmCooldown[id]
		if cooldown == nil then
			continue
		end
		local dircm = (unitDef(sim, id).countermeasures :: Defs.Countermeasures).dircm :: Defs.Dircm
		local drain = dircm.powerDrain
		local ratio = 1
		if drain > 0 then
			local team = w.team[id]
			local acc = eco.accounts[team]
			demandP[team] += drain
			ratio = math.min(Economy.effective(acc, 0, drain), Economy.allowance(acc.power) / (drain * dt))
			ratio = math.max(ratio, 0)
			acc.power.spent += drain * dt * ratio
		end
		if cooldown > 0 then
			e.dircmCooldown[id] = math.max(0, cooldown - dt * ratio)
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	EWState.clearUnit(sim.ew, id)
end)

return EW
