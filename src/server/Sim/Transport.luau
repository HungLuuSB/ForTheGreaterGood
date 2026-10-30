--!strict
-- Air transports (S-219, the user; docs/design/transports.md): LOAD picks
-- up an allied ground unit, UNLOAD sets the cargo down around a point, one
-- unit after another. A carried unit is parked (World.park): out of `ids`,
-- so it doesn't move, fire, build, see or get seen or hit, and it leaves
-- every player's view; it keeps its health, ammo and stockpile. When a
-- loaded transport dies, its cargo dies with it, with no wrecks.
--
-- Who fits: a light transport takes one light unit (tier 1 or a Commander,
-- footprint up to 2); a heavy one up to four units of tier up to 2 and
-- footprint up to 3, by slots (footprint 1 = 1, 2 = 2, 3 = 4). Never
-- structures, aircraft, ships, T3, other transports, deployed units or
-- shield carriers.

local Combat = require("./Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local EWState = require("./EWState")
local Lifecycle = require("./Lifecycle")
local Nav = require("./Nav")
local OrdersState = require("./OrdersState")
local BuildState = require("./BuildState")
local Sensors = require("./Sensors")
local Types = require("./Types")
local World = require("./World")

local Transport = {}

Transport.LOAD_TICKS = 15 -- ticks to pick up or set down one unit (1 s)
Transport.LOAD_REACH = 10 -- studs, plus the unit's radius: how close (flat) a transport must be to pick it up
Transport.UNLOAD_REACH = 12 -- studs from the unload point before it starts setting down
Transport.SLOW_PER_SLOT = 0.1 -- top speed lost per slot used
Transport.DROP_RING = 6 -- studs between the rings searched for a spot to set a unit down
Transport.DROP_RINGS = 10

local SLOTS = { 1, 2, 4 } -- by footprint

local function def(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- Slots unit def `d` takes in a transport, or nil when it never fits one.
function Transport.slotsOf(d: Defs.UnitDef): number?
	return SLOTS[math.max(1, d.footprint or 1)]
end

-- Slots used on transport `t`.
function Transport.used(sim: Types.Sim, t: number): number
	local n = 0
	for _, u in sim.transport.cargo[t] or {} do
		n += Transport.slotsOf(def(sim, u)) or 0
	end
	return n
end

-- Can transport `t` take unit `u` now (room included)?
function Transport.canCarry(sim: Types.Sim, t: number, u: number): boolean
	local w = sim.world
	if t == u or w.slot[t] == nil or w.slot[u] == nil or World.isParked(w, t) or World.isParked(w, u) then
		return false
	end
	local td = def(sim, t)
	local spec = td.transport
	if spec == nil or w.buildProgress[t] < 1 or w.ally[u] ~= w.ally[t] or w.buildProgress[u] < 1 then
		return false
	end
	local ud = def(sim, u)
	if ud.domain ~= "ground" or ud.transport ~= nil or ud.shield ~= nil then
		return false
	end
	if (ud.tier or 1) > spec.maxTier or (ud.footprint or 1) > spec.maxFootprint then
		return false
	end
	if (w.deploy[u] or 0) > 0 or bit32.band(w.state[u], bit32.bor(World.State.DEPLOYING, World.State.SUBMERGED)) ~= 0 then
		return false -- a deployed Warden, a submerged unit
	end
	local cargo = sim.transport.cargo[t]
	if cargo and #cargo >= spec.maxUnits then
		return false
	end
	return Transport.used(sim, t) + (Transport.slotsOf(ud) :: number) <= spec.slots
end

local function setSlow(sim: Types.Sim, t: number)
	local used = Transport.used(sim, t)
	sim.transport.slow[t] = if used > 0 then 1 - Transport.SLOW_PER_SLOT * used else nil
end

-- Its sensor stamps and what each team sees of it go (Sensors' removal hook,
-- less the ghosts' bookkeeping a live unit doesn't have).
local function forgetSight(sim: Types.Sim, u: number)
	local s = sim.sensors
	Sensors.unstamp(s, u)
	for _, team in s.teams do
		s.vis[team][u] = nil
		s.tracked[team][u] = nil
		s.radarGhosts[team][u] = nil
	end
end

-- Takes unit `u` on board transport `t` (checked with canCarry).
function Transport.pickUp(sim: Types.Sim, t: number, u: number)
	local w = sim.world
	if sim.nav then
		Nav.clearOrder(sim.nav, w, u)
	end
	OrdersState.clearUnit(sim.orders, u)
	BuildState.clearUnit(sim.build, u)
	EWState.clearUnit(sim.ew, u)
	forgetSight(sim, u)
	w.speed[u] = 0
	World.park(w, u)
	local cargo = sim.transport.cargo[t]
	if cargo == nil then
		cargo = {}
		sim.transport.cargo[t] = cargo
	end
	table.insert(cargo, u)
	sim.transport.carrier[u] = t
	World.setPosition(w, u, w.posX[t], w.posZ[t])
	setSlow(sim, t)
end

-- One tick of transport `t` picking up `u` (in reach, hovering): true while
-- it is still at it, false once `u` is on board.
function Transport.loadTick(sim: Types.Sim, t: number, u: number): boolean
	local n = (sim.transport.loading[t] or 0) + 1
	if n < Transport.LOAD_TICKS then
		sim.transport.loading[t] = n
		return true
	end
	sim.transport.loading[t] = nil
	Transport.pickUp(sim, t, u)
	return false
end

-- Free ground for unit def `d` near (x, z): rings out from the point, the
-- first open cell its move class stands on with no structure on it.
local function dropSpot(sim: Types.Sim, d: Defs.UnitDef, x: number, z: number): (number?, number?)
	local nav = sim.nav
	if nav == nil then
		return x, z
	end
	local p = nav.profiles[d.index]
	if p == nil then
		return nil, nil
	end
	local pm = nav.pm
	local g = nav.grid
	local function open(px: number, pz: number): boolean
		if not Nav.fits(nav, p, px, pz) then
			return false
		end
		local cx, cz = g:cellAt(px, pz)
		return buffer.readu16(pm.occupancy, g:index(cx, cz) * 2) == 0
	end
	if open(x, z) then
		return x, z
	end
	for ring = 1, Transport.DROP_RINGS do
		local r = ring * Transport.DROP_RING
		local n = 6 * ring
		for i = 0, n - 1 do
			local a = i / n * 2 * math.pi
			local px, pz = x + math.sin(a) * r, z + math.cos(a) * r
			if open(px, pz) then
				return px, pz
			end
		end
	end
	return nil, nil
end

-- Sets unit `u` down from transport `t` at (x, z), idle.
local function setDown(sim: Types.Sim, t: number, u: number, x: number, z: number)
	local w = sim.world
	local tr = sim.transport
	World.unpark(w, u)
	World.setPosition(w, u, x, z)
	World.setHeading(w, u, w.heading[t])
	w.goalX[u], w.goalZ[u] = x, z
	w.speed[u] = 0
	w.orderId[u] = 0
	w.progressTick[u] = sim.tick
	local cargo = tr.cargo[t] :: { number }
	table.remove(cargo, table.find(cargo, u) :: number)
	if #cargo == 0 then
		tr.cargo[t] = nil
	end
	tr.carrier[u] = nil
	setSlow(sim, t)
end

-- One tick of transport `t` setting its cargo down (at its unload point,
-- hovering): one unit each LOAD_TICKS, nearest open ground first; with no
-- room it waits. True while units are left on board.
function Transport.unloadTick(sim: Types.Sim, t: number): boolean
	local tr = sim.transport
	local cargo = tr.cargo[t]
	if cargo == nil or #cargo == 0 then
		tr.loading[t] = nil
		return false
	end
	local n = (tr.loading[t] or 0) + 1
	if n < Transport.LOAD_TICKS then
		tr.loading[t] = n
		return true
	end
	tr.loading[t] = Transport.LOAD_TICKS -- (waits here while there's no room)
	local w = sim.world
	local u = cargo[1]
	local x, z = dropSpot(sim, def(sim, u), w.posX[t], w.posZ[t])
	if x == nil or z == nil then
		return true
	end
	tr.loading[t] = nil
	setDown(sim, t, u, x, z)
	return tr.cargo[t] ~= nil
end

-- Stops loading / unloading (the transport's order ended or changed).
function Transport.idle(sim: Types.Sim, t: number)
	sim.transport.loading[t] = nil
end

-- Each tick: carried units ride along (their position is the transport's,
-- for whoever reads it: the AI, a death on board).
function Transport.step(sim: Types.Sim)
	local w = sim.world
	for t, cargo in sim.transport.cargo do
		if w.slot[t] == nil then
			continue
		end
		local x, z = w.posX[t], w.posZ[t]
		for _, u in cargo do
			if w.posX[u] ~= x or w.posZ[u] ~= z then
				World.setPosition(w, u, x, z)
			end
		end
	end
end

-- A unit leaves the world: a transport takes its cargo with it (the units
-- die next tick, no wrecks, no death blasts, through god mode); a carried
-- unit leaves its transport's cargo.
table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	local tr = sim.transport
	local cargo = tr.cargo[id]
	if cargo then
		local w = sim.world
		local c = sim.combat
		for _, u in cargo do
			tr.carrier[u] = 0 -- (Damage: no wreck, no blast)
			sim.cheats.killing[u] = true
			Combat.queueDamage(c, u, w.health[u] * 100 + 1, 0, 0)
		end
		tr.cargo[id] = nil
	end
	tr.loading[id] = nil
	tr.slow[id] = nil
	local t = tr.carrier[id]
	if t ~= nil then
		tr.carrier[id] = nil
		local list = tr.cargo[t]
		local i = list and table.find(list, id)
		if list and i then
			table.remove(list, i)
			if #list == 0 then
				tr.cargo[t] = nil
			end
			setSlow(sim, t)
		end
	end
end)

return Transport
