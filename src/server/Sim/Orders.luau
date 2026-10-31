--!strict
-- Unit order queues and behaviors (guide 15.6 "shift queues commands";
-- docs/contracts/net.md 9; S-4).
--
-- Each mobile unit has a queue of orders, head first. A command replaces the
-- queue, or with the queue flag (shift) is appended to it; with the front
-- flag (space, S-199) it goes in at the head: the order under way stops (a
-- frame keeps standing) and starts again once the new one is done. Every tick (at the
-- end of the Commands system) the head order is started or checked:
--   move     a Nav move; done on arrival (the Nav order ends).
--   fight    attack-move: a move that holds (brakes, keeps the order) while
--            an enemy is within a weapon's firing range, then goes on
--            (S-14, BAR). Jets don't hold.
--   patrol   fight back and forth between the unit's start and the point,
--            forever (orders queued behind it never start).
--   attack   force-fire a unit the team knows (VISIBLE, radar, ghost): its
--            weapons that can engage it pick it (Targeting) even on hold
--            fire; the unit chases to 90% of its longest range. Done when
--            the team no longer knows the target.
--   guard    stay within GUARD_RADIUS of an allied unit (builders assist it
--            when it is a frame or a factory). Done when it is gone.
--   repair / reclaim / resurrect / build
--            the Build commands; done when the builder is idle again.
--            Repair also heals damaged finished units (Build, S-4).
--   attackGround  bombers' attack-ground (D100); kept until replaced.
-- Idle units act on their move state (guide 10.1, S-34; Orders.autoStep):
-- Hold Position never moves on its own; Maneuver (default) attack-moves
-- toward the nearest visible enemy it can damage (Fire at Will units only)
-- when no weapon has a shot
-- (none in range, or terrain in the way), as far as MANEUVER_LEASH studs
-- from its anchor (where it was last sent), and walks back when done;
-- Roam chases up to ROAM_CHASE studs beyond its range and stays there.
-- These orders are marked `auto`; any command replaces them and re-anchors.
-- Units leaving a move together (same command, same tick) move as a group
-- (one Nav order, formation slots). Aircraft away rearming pause their
-- queue and restart the head order when they fly again.
--
-- Factories keep an order list for the units they produce (S-95, client
-- request 44): MOVE, FIGHT, PATROL, GUARD, REPAIR and ATTACK given to a
-- factory go on its list (queued: appended; else the list is replaced),
-- and STOP clears it. Each unit it produces rolls out of the exit, then
-- takes a copy of the list, in order. REPEAT on a factory turns repeat on
-- or off: a finished item goes back to the end of the queue (S-13; the
-- REPEAT state bit shows it).

local Air = require("./Air")
local Build = require("./Build")
local BuildState = require("./BuildState")
local Combat = require("./Combat/Combat")
local ContactGrid = require("./Combat/ContactGrid")
local Defs = require("@shared/Defs/Defs")
local Hash = require("@shared/Util/Hash")
local Lifecycle = require("./Lifecycle")
local Nav = require("./Nav")
local OrdersState = require("./OrdersState")
local Schema = require("@shared/Net/Schema")
local Sensors = require("./Sensors")
local Transport = require("./Transport")
local Types = require("./Types")
local World = require("./World")

local Orders = {}

local REPEAT = World.State.REPEAT

Orders.GUARD_RADIUS = 80 -- studs
Orders.CHASE_STEP = 24 -- studs: re-aim a chase move when the target moved this far
Orders.CHASE_EVERY = 15 -- ticks between chase moves
Orders.ATTACK_REACH = 0.9 -- of the unit's longest weapon range
Orders.AUTO_PERIOD = 15 -- ticks between an idle unit's move-state checks (staggered by ID)
Orders.MANEUVER_LEASH = 150 -- studs a Maneuver unit goes from its anchor to get a shot, at most
Orders.MANEUVER_LEASH_RANGE = 1 -- × its range, at least MANEUVER_LEASH_MIN (S-185, the playtest's F5: with T1 ranges halved, 150 studs let units wander off)
Orders.MANEUVER_LEASH_MIN = 60

-- How far a Maneuver unit leaves its anchor for a shot (S-185).
function Orders.leash(d: Defs.UnitDef): number
	return math.clamp(d.maxRange * Orders.MANEUVER_LEASH_RANGE, Orders.MANEUVER_LEASH_MIN, Orders.MANEUVER_LEASH)
end
Orders.ROAM_CHASE = 500 -- studs beyond its range a Roam unit looks for something to chase
Orders.ANCHOR_SLACK = 24 -- studs: a Maneuver unit farther than this from its anchor walks back
Orders.HOLD_EVERY = 2 -- ticks between a unit's attack-move / patrol hold checks, spread by ID (S-107)

export type OrderSpec = {
	kind: OrdersState.Kind,
	x: number?,
	z: number?,
	lx: number?,
	lz: number?,
	target: number?,
	gen: number?,
	defIndex: number?,
	facing: number?,
	group: boolean?, -- move-like: keep together at the slowest unit's speed (S-137)
	areaOp: number?, -- area (S-183)
	radius: number?,
}

local AREA = Schema.AreaOp

local function def(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

local function isFactory(d: Defs.UnitDef): boolean
	return d.domain == "structure" and d.buildOptions ~= nil
end

local MOVE_LIKE: { [string]: boolean } = { move = true, fight = true, patrol = true }
local FACTORY_ORDERS: { [string]: boolean } = { move = true, fight = true, patrol = true, guard = true, repair = true, attack = true } -- (S-95)
local function isMoveLike(kind: string): boolean
	return MOVE_LIKE[kind] == true
end

-- Ends whatever the unit is doing for its current order (not its Nav move:
-- the next order replaces that, or `stop` halts it).
local function cancelCurrent(sim: Types.Sim, id: number)
	local o = sim.orders
	o.hold[id] = nil
	o.forced[id] = nil
	o.forcedGen[id] = nil
	Air.clearGround(sim, id)
	Build.commandIdle(sim, { id })
	Transport.idle(sim, id)
end

-- Halts a unit where it stands.
local function halt(sim: Types.Sim, id: number)
	local w = sim.world
	if sim.nav and w.orderId[id] ~= 0 then
		Nav.clearOrder(sim.nav, w, id)
		w.goalX[id], w.goalZ[id] = w.posX[id], w.posZ[id]
	end
end

-- Gives `spec` to units `ids` (already checked as the sender's own). With
-- `queued`, appends; with `front`, puts it first (S-199); else replaces
-- their queues. Factories keep the orders for the units they produce
-- instead (S-95).
function Orders.give(sim: Types.Sim, ids: { number }, spec: OrderSpec, queued: boolean, front: boolean?)
	local o = sim.orders
	queued = queued or front == true
	local batch = o.nextBatch
	o.nextBatch += 1
	if not queued then
		for _, id in ids do
			o.dgunX[id], o.dgunZ[id], o.dgunWalk[id] = nil, nil, nil -- a new order drops a D-Gun shot not fired yet (S-194)
		end
	end
	-- a group move (ctrl, S-137): every ground unit goes at the slowest one's
	-- top speed, so the group keeps together (aircraft fly as usual)
	local speedCap: number? = nil
	if spec.group and sim.nav and isMoveLike(spec.kind) then
		for _, id in ids do
			local p = sim.nav.profiles[sim.world.defIndex[id]]
			if p and not p.air and def(sim, id).domain ~= "structure" then
				speedCap = math.min(speedCap or math.huge, p.maxSpeed)
			end
		end
	end
	for _, id in ids do
		o.anchorX[id], o.anchorZ[id] = nil, nil -- re-anchored where this leaves it (S-34)
		Air.release(sim, id) -- a docked aircraft launches (S-36)
		local d = def(sim, id)
		-- structures take no orders, except a silo's attack-ground (S-48)
		if d.domain == "structure" and not (spec.kind == "attackGround" and (Air.isManualFire(sim, d) or Air.groundFires(sim, d))) then
			if isFactory(d) and FACTORY_ORDERS[spec.kind] and (spec.x or spec.target) then
				local list = if queued then o.rally[id] or {} else {}
				table.insert(list, if front then 1 else #list + 1, { kind = spec.kind, x = spec.x, z = spec.z, lx = spec.lx, lz = spec.lz, target = spec.target, gen = spec.gen })
				o.rally[id] = list
			elseif spec.kind == "attack" and #d.weapons > 0 and spec.target then
				-- an armed structure (a beam tower, a turret) takes an attack
				-- as its manual target: it can't chase, it fires whenever the
				-- target is in range (S-121, client request 54)
				o.manual[id], o.manualGen[id] = spec.target, spec.gen or 0
				o.manualX[id], o.manualZ[id], o.manualBlind[id] = nil, nil, nil
			end
			continue
		end
		local q = o.queue[id]
		if q == nil or not queued or (front and q[1] ~= nil and q[1].auto) then
			if q ~= nil and #q > 0 then
				cancelCurrent(sim, id)
			end
			q = {}
			o.queue[id] = q
		end
		if front and q[1] ~= nil then
			-- the order under way stops, to start over after the new one
			local h = q[1]
			if h.started then
				cancelCurrent(sim, id)
				if isMoveLike(h.kind) then
					halt(sim, id)
				end
				h.started, h.nav, h.held, h.gx, h.gz, h.issued = false, 0, nil, nil, nil, -math.huge
			end
		end
		table.insert(q, if front then 1 else #q + 1, {
			kind = spec.kind,
			batch = batch,
			x = spec.x,
			z = spec.z,
			lx = spec.lx,
			lz = spec.lz,
			target = spec.target,
			gen = spec.gen,
			defIndex = spec.defIndex,
			facing = spec.facing,
			areaOp = spec.areaOp,
			radius = spec.radius,
			started = false,
			nav = 0,
			issued = -math.huge,
			speedCap = speedCap,
		})
	end
end

-- The player's STOP command: Orders.stop, and the manual target goes too
-- (S-115; automatic orders stop units without touching it).
function Orders.stopCommand(sim: Types.Sim, id: number)
	Orders.stop(sim, id)
	Orders.dropManual(sim, id)
end

-- Forgets unit `id`'s manual target (S-115, S-125).
function Orders.dropManual(sim: Types.Sim, id: number)
	local o = sim.orders
	o.manual[id], o.manualGen[id] = nil, nil
	o.manualX[id], o.manualZ[id], o.manualBlind[id] = nil, nil, nil
end

-- STOP: clears the queue and halts.
function Orders.stop(sim: Types.Sim, id: number)
	local o = sim.orders
	if o.queue[id] then
		o.queue[id] = nil
	end
	o.rally[id] = nil -- a factory's order list (S-95)
	o.anchorX[id], o.anchorZ[id] = nil, nil
	cancelCurrent(sim, id)
	halt(sim, id)
end

-- REPEAT on a factory: repeat on / off. Other units ignore it.
function Orders.setRepeat(sim: Types.Sim, factory: number, on: boolean)
	local d = def(sim, factory)
	-- factories, and mobile builders: an area order with REPEAT stays (S-183)
	if not isFactory(d) and (d.buildPower == nil or d.domain == "structure") then
		return
	end
	sim.orders.repeatOn[factory] = if on then true else nil
	local w = sim.world
	local state = w.state[factory]
	World.setState(w, factory, if on then bit32.bor(state, REPEAT) else bit32.band(state, bit32.bnot(REPEAT)))
end

-- A factory produced `id` (Build): roll out of the exit, then the
-- factory's orders, in order (S-95).
local function onProduced(sim: Types.Sim, factory: number, id: number, exitX: number, exitZ: number)
	local o = sim.orders
	Orders.give(sim, { id }, { kind = "move", x = exitX, z = exitZ }, false)
	for _, r in o.rally[factory] or {} do
		Orders.give(sim, { id }, { kind = r.kind, x = r.x, z = r.z, lx = r.lx, lz = r.lz, target = r.target, gen = r.gen }, true)
	end
end
Build.producedHook = onProduced

local function pop(sim: Types.Sim, id: number, q: { Order })
	table.remove(q, 1)
	cancelCurrent(sim, id)
	if #q == 0 then
		sim.orders.queue[id] = nil
	end
end
type Order = OrdersState.Order

-- A D-Gun walk got in range and fired (S-194): the walk ends. With orders
-- behind it (a FRONT D-Gun, S-199) they go on; else the unit stops there.
function Orders.endWalk(sim: Types.Sim, id: number)
	local q = sim.orders.queue[id]
	if q ~= nil and #q > 1 and q[1].kind == "move" then
		halt(sim, id)
		pop(sim, id, q)
	else
		Orders.stopCommand(sim, id)
	end
end

-- Attack-move holds (S-14, BAR): while some weapon has a target within
-- the range it fires at (Weapons: center distance to the target's believed
-- position ≤ range + the target's radius when its type is known). Targeting
-- keeps a target out to 110% of range (hysteresis); that alone doesn't
-- stop the unit, it closes in. Seeing an enemy never does.
local SEEN = Sensors.Level.VISIBLE
local function engaged(sim: Types.Sim, id: number): boolean
	local w = sim.world
	local profiles = sim.combat.profiles
	local weapons = profiles[w.defIndex[id]].weapons
	local ally = w.ally[id]
	local vis = sim.sensors.vis[ally]
	for slot = 1, w.weaponCount[id] do
		local key = World.slotKey(id, slot)
		local t = w.wTarget[key]
		if t ~= 0 and w.wBlocked[key] == 0 then -- terrain in the way: not engaged, move on (S-32)
			local kx, kz, radius
			if World.isRef(w, t, w.wTargetGen[key]) and vis and vis[t] == SEEN and w.ally[t] ~= ally then
				-- a live enemy in sight (most cases): what knownTarget would say (S-74)
				kx, kz, radius = w.posX[t], w.posZ[t], profiles[w.defIndex[t]].radius
			else
				local level, defIndex
				kx, kz, level, defIndex = Sensors.knownTarget(sim, ally, t, w.wTargetGen[key])
				radius = if defIndex and Sensors.typeKnown(sim, ally, t, level) then profiles[defIndex].radius else 0
			end
			if kx ~= nil and kz ~= nil then
				local dx, dz = kx - w.posX[id], kz - w.posZ[id]
				if dx * dx + dz * dz <= (weapons[slot].range + radius) ^ 2 then
					return true
				end
			end
		end
	end
	return false
end

local function builderIdle(sim: Types.Sim, id: number): boolean
	local b = sim.build
	return b.order[id] == nil and (b.target[id] or 0) == 0 and (b.reclaim[id] or 0) == 0 and (b.resurrect[id] or 0) == 0
end

-- Moves `id` toward (x, z) unless a recent chase move already aims close by.
local function chase(sim: Types.Sim, id: number, h: Order, x: number, z: number)
	local w = sim.world
	local nav = sim.nav
	if nav == nil then
		return
	end
	local moving = w.orderId[id] ~= 0
	local far = h.gx == nil or (h.gx - x) ^ 2 + ((h.gz :: number) - z) ^ 2 > Orders.CHASE_STEP ^ 2
	if (not moving or far) and sim.tick - h.issued >= Orders.CHASE_EVERY then
		Nav.issueMove(nav, w, sim.tick, { id }, x, z)
		h.gx, h.gz, h.issued = x, z, sim.tick
	end
end

-- Starts the head order (not move-like ones: those start in groups).
local function start(sim: Types.Sim, id: number, h: Order): boolean
	local w = sim.world
	local kind = h.kind
	if kind == "repair" then
		Build.commandAssist(sim, { id }, h.target :: number)
	elseif kind == "reclaim" then
		Build.commandReclaim(sim, { id }, h.target :: number)
	elseif kind == "resurrect" then
		Build.commandResurrect(sim, { id }, h.target :: number)
	elseif kind == "build" then
		Build.commandBuild(sim, { id }, h.defIndex :: number, h.x :: number, h.z :: number, h.facing or 0)
	elseif kind == "attackGround" then
		local d = def(sim, id)
		if not Air.isBomber(sim, d) and not Air.isManualFire(sim, d) and not Air.groundFires(sim, d) then
			return false -- only bombers, silos and ballistic weapons take it: done
		end
		Air.attackGround(sim, id, h.x :: number, h.z :: number)
	elseif kind == "guard" then
		local t = h.target :: number
		if w.slot[t] == nil or (h.gen ~= nil and w.gen[t] ~= h.gen) then
			return false -- the guarded unit is gone (an order queued behind others, S-95): done
		end
		local td = def(sim, t)
		if def(sim, id).domain == "air" and td.rearmPads and Air.recover(sim, id, t) then
			return false -- guarding a carrier or airfield: land there, it is home (S-36)
		end
		if def(sim, id).buildPower and (w.buildProgress[t] < 1 or isFactory(td)) then
			Build.commandAssist(sim, { id }, t)
		end
	end
	h.started = true
	return true
end

-- Smart Reclaim (S-183, the user): an area order works the circle target by
-- target, nearest to the unit first: wrecks to reclaim, wrecks to bring back
-- (resurrect; never a Commander's), or the team's damaged or unfinished
-- units and structures (repair). Done when nothing is left, unless the
-- unit's REPEAT is on: then it stays (back inside the circle) and takes
-- each new wreck as it appears.
function Orders.areaTarget(sim: Types.Sim, id: number, op: number, cx: number, cz: number, radius: number): number?
	local w = sim.world
	local c = sim.combat
	local r2 = radius * radius
	local ux, uz = w.posX[id], w.posZ[id]
	local best, bestD = nil, math.huge
	if op == AREA.REPAIR then
		-- (the world, not the contact grid: units made this tick count too;
		-- this runs only while a worker is between targets)
		for _, t in w.ids do
			if t ~= id and w.team[t] == w.team[id] and (w.posX[t] - cx) ^ 2 + (w.posZ[t] - cz) ^ 2 <= r2 then
				local td = def(sim, t)
				if w.buildProgress[t] < 1 or w.health[t] < td.health then
					local d = (w.posX[t] - ux) ^ 2 + (w.posZ[t] - uz) ^ 2
					if d < bestD or (d == bestD and t < (best :: number)) then
						best, bestD = t, d
					end
				end
			end
		end
		return best
	end
	for _, wid in c.wreckIds do
		local wx, wz = c.wreckX[wid], c.wreckZ[wid]
		if (wx - cx) ^ 2 + (wz - cz) ^ 2 <= r2 then
			local ok = true
			if op == AREA.RESURRECT then
				ok = c.wreckKind[wid] == nil and not Combat.isHeap(c, wid) and not table.find(sim.defs.unitByIndex[c.wreckDef[wid]].categories, "COMMANDER") -- (no map features, S-197)
			end
			if ok then
				local d = (wx - ux) ^ 2 + (wz - uz) ^ 2
				if op == AREA.RECLAIM and Combat.isHeap(c, wid) then
					d /= 4 -- a scrap heap first, up to twice as far: it's going (S-227)
				end
				if d < bestD or (d == bestD and wid < (best :: number)) then
					best, bestD = wid, d
				end
			end
		end
	end
	return best
end

local function areaStep(sim: Types.Sim, id: number, h: Order): boolean
	if not builderIdle(sim, id) then
		return true -- on a target: Build walks it there and works
	end
	local op = h.areaOp :: number
	local cx, cz, radius = h.x :: number, h.z :: number, h.radius :: number
	local t = Orders.areaTarget(sim, id, op, cx, cz, radius)
	if t then
		if op == AREA.RECLAIM then
			Build.commandReclaim(sim, { id }, t)
		elseif op == AREA.RESURRECT then
			Build.commandResurrect(sim, { id }, t)
		else
			Build.commandAssist(sim, { id }, t)
		end
		if not builderIdle(sim, id) then
			return true
		end
	end
	if sim.orders.repeatOn[id] then
		-- REPEAT: stay, inside the circle, for the next wreck
		local w = sim.world
		local dx, dz = cx - w.posX[id], cz - w.posZ[id]
		if dx * dx + dz * dz > radius * radius then
			chase(sim, id, h, cx, cz)
		end
		return true
	end
	return false
end

-- Per-tick work on one unit's head order; returns false when it is done.
local function run(sim: Types.Sim, id: number, h: Order): boolean
	local w = sim.world
	local o = sim.orders
	local kind = h.kind
	if MOVE_LIKE[kind] then
		if w.orderId[id] ~= h.nav then
			-- arrived (or the move was replaced)
			if kind == "patrol" then
				h.x, h.z, h.ox, h.oz = h.ox, h.oz, h.x, h.z
				h.started = false
				o.hold[id] = nil
				return true
			end
			return false
		end
		-- the hold check (attack-move, patrol) runs for each unit every
		-- HOLD_EVERY ticks, spread by ID, and on the order's first tick
		-- (S-107, next.md item 3 option (a)): half the units each tick
		if kind ~= "move" and (h.held == nil or (id + sim.tick) % Orders.HOLD_EVERY == 0) then
			o.hold[id] = engaged(sim, id) and def(sim, id).moveClass ~= "JET" or nil
			h.held = true
		end
		return true
	elseif kind == "attack" then
		local t, gen = h.target :: number, h.gen
		local kx, kz = Sensors.knownTarget(sim, w.ally[id], t, gen)
		local d = def(sim, id)
		if kx == nil or kz == nil or #d.weapons == 0 then
			return false -- the team lost it (or nothing to shoot with)
		end
		o.forced[id], o.forcedGen[id] = t, gen :: number
		o.manual[id], o.manualGen[id] = t, gen :: number -- kept after the order ends, until STOP (S-115)
		o.manualX[id], o.manualZ[id], o.manualBlind[id] = nil, nil, nil
		if d.domain == "air" then
			return true -- aircraft chase their target themselves
		end
		-- a unit standing with its target in range stays put (S-153, the
		-- user); one already closing in goes on to ATTACK_REACH of its
		-- range, so it doesn't stop right at the edge
		local chasing = w.orderId[id] ~= 0 and h.gx ~= nil
		local reach = if chasing then d.maxRange * Orders.ATTACK_REACH else d.maxRange
		local dx, dz = kx - w.posX[id], kz - w.posZ[id]
		if dx * dx + dz * dz > reach * reach then
			chase(sim, id, h, kx, kz)
		else
			halt(sim, id)
		end
		return true
	elseif kind == "guard" then
		local t = h.target :: number
		if not World.isRef(w, t, h.gen) or w.ally[t] ~= w.ally[id] then
			return false
		end
		-- a builder guarding (ASSIST) another builder helps with what that one
		-- builds: its frame, or the factory production it assists (S-128, the
		-- user; never repairs or stockpiles); otherwise it follows it
		local b = sim.build
		if def(sim, id).buildPower and def(sim, t).buildOptions and def(sim, t).domain ~= "structure" then
			local lt = b.target[t] or 0
			local helping = lt ~= 0 and World.isRef(w, lt, b.targetGen[t]) and not b.repair[t]
				and (w.buildProgress[lt] < 1 or b.assist[t] == true)
			if helping then
				if (b.target[id] or 0) ~= lt then
					Build.commandAssist(sim, { id }, lt)
				end
				return true -- Build walks it into range and builds
			elseif (b.target[id] or 0) ~= 0 and not b.repair[id] then
				BuildState.idle(b, id) -- the leader's job is done: follow again
			end
		end
		local dx, dz = w.posX[t] - w.posX[id], w.posZ[t] - w.posZ[id]
		local d2 = dx * dx + dz * dz
		if d2 > Orders.GUARD_RADIUS ^ 2 then
			chase(sim, id, h, w.posX[t], w.posZ[t])
		elseif d2 < (Orders.GUARD_RADIUS / 2) ^ 2 and w.orderId[id] ~= 0 then
			halt(sim, id)
		end
		return true
	elseif kind == "area" then
		return areaStep(sim, id, h)
	elseif kind == "load" then
		-- (S-219) fly over the unit, hover, pick it up
		local u = h.target :: number
		if not World.isRef(w, u, h.gen) or not Transport.canCarry(sim, id, u) then
			return false
		end
		local reach = Transport.LOAD_REACH + sim.combat.profiles[w.defIndex[u]].radius
		local dx, dz = w.posX[u] - w.posX[id], w.posZ[u] - w.posZ[id]
		if dx * dx + dz * dz > reach * reach then
			Transport.idle(sim, id)
			chase(sim, id, h, w.posX[u], w.posZ[u])
			return true
		end
		halt(sim, id)
		if (sim.transport.loading[id] or 0) == 0 then
			Orders.stop(sim, u) -- it waits to be picked up
		end
		return Transport.loadTick(sim, id, u)
	elseif kind == "unload" then
		-- (S-219) fly to the point, hover, set the cargo down
		if sim.transport.cargo[id] == nil then
			return false
		end
		local dx, dz = (h.x :: number) - w.posX[id], (h.z :: number) - w.posZ[id]
		if dx * dx + dz * dz > Transport.UNLOAD_REACH ^ 2 then
			Transport.idle(sim, id)
			chase(sim, id, h, h.x :: number, h.z :: number)
			return true
		end
		halt(sim, id)
		return Transport.unloadTick(sim, id)
	elseif kind == "attackGround" then
		-- bombers: until replaced; a silo: until it launched (S-48)
		local d = def(sim, id)
		if Air.isBomber(sim, d) or Air.isManualFire(sim, d) then
			return Air.isBomber(sim, d) or sim.air.groundX[id] ~= nil
		end
		-- ballistic weapons (S-68): close to range, then fire until replaced
		local gx, gz = sim.air.groundX[id], sim.air.groundZ[id]
		if gx == nil or gz == nil then
			return false
		end
		if d.domain ~= "structure" then
			local reach = d.maxRange * Orders.ATTACK_REACH
			local dx, dz = (gx :: number) - w.posX[id], (gz :: number) - w.posZ[id]
			if dx * dx + dz * dz > reach * reach then
				chase(sim, id, h, gx :: number, gz :: number)
			else
				halt(sim, id)
			end
		end
		return true
	end
	-- repair / reclaim / resurrect / build
	return not builderIdle(sim, id)
end

--------------------------------------------------------------------------------
-- Move states (guide 10.1, S-34)
--------------------------------------------------------------------------------

local VISIBLE = Sensors.Level.VISIBLE
local MANEUVER, ROAM = World.MoveState.MANEUVER, World.MoveState.ROAM
local candidates: { number } = {}
local rebuiltAt: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any -- contact grid → tick rebuilt for chases

-- Replaces the unit's queue with one automatic order.
local function giveAuto(sim: Types.Sim, id: number, kind: OrdersState.Kind, x: number, z: number)
	local o = sim.orders
	local q = o.queue[id]
	if q ~= nil and #q > 0 then
		cancelCurrent(sim, id)
	end
	o.queue[id] = { { kind = kind, batch = o.nextBatch, x = x, z = z, started = false, nav = 0, issued = -math.huge, auto = true } }
	o.nextBatch += 1
end

-- The nearest visible enemy unit `id` can damage and reach, within `radius`
-- of (cx, cz); its believed position, or nil.
local function chaseTarget(sim: Types.Sim, id: number, cx: number, cz: number, radius: number): (number?, number?)
	local w = sim.world
	local c = sim.combat
	local nav = sim.nav :: Nav.Nav
	local ally = w.ally[id]
	local weapons = c.profiles[w.defIndex[id]].weapons
	local np = nav.profiles[w.defIndex[id]]
	if rebuiltAt[c.contacts] ~= sim.tick then
		ContactGrid.rebuild(c.contacts, w) -- Orders runs before Targeting rebuilds it this tick
		rebuiltAt[c.contacts] = sim.tick
	end
	local n = ContactGrid.query(c.contacts, w, cx, cz, radius + c.maxRadius, ally, candidates)
	local bestX, bestZ, bestD, bestT = nil, nil, math.huge, 0
	for i = 1, n do
		local t = candidates[i]
		if Sensors.level(sim, ally, t) ~= VISIBLE then
			continue
		end
		local mask = c.profiles[w.defIndex[t]].categoryMask
		local can = false
		for _, wd in weapons do
			if bit32.band(wd.targetMask, mask) ~= 0 then
				can = true
				break
			end
		end
		local tx, tz = w.posX[t], w.posZ[t]
		if not can or (tx - cx) ^ 2 + (tz - cz) ^ 2 > radius * radius or (np and not Nav.fits(nav, np, tx, tz)) then
			continue
		end
		local d = (tx - w.posX[id]) ^ 2 + (tz - w.posZ[id]) ^ 2
		if d < bestD or (d == bestD and t < bestT) then
			bestX, bestZ, bestD, bestT = tx, tz, d, t
		end
	end
	return bestX, bestZ
end

-- One idle unit's move-state check (every AUTO_PERIOD ticks).
local function autoUnit(sim: Types.Sim, id: number)
	local w = sim.world
	local o = sim.orders
	local q = o.queue[id]
	local head = q and q[1]
	if head ~= nil and not head.auto then
		return -- busy with a player's order
	end
	local d = def(sim, id)
	local state = w.moveState[id]
	if d.domain == "structure" or d.domain == "air" or #d.weapons == 0 or d.buildPower ~= nil or w.fireState[id] ~= World.FireState.FIRE_AT_WILL or state < MANEUVER then
		if head ~= nil then
			Orders.stop(sim, id) -- the state changed under an automatic order
		end
		return
	end
	if o.anchorX[id] == nil then
		o.anchorX[id], o.anchorZ[id] = w.goalX[id] or w.posX[id], w.goalZ[id] or w.posZ[id]
	end
	local ax, az = o.anchorX[id], o.anchorZ[id]
	local x, z = w.posX[id], w.posZ[id]
	local away2 = (x - ax) ^ 2 + (z - az) ^ 2
	local leash = Orders.leash(d)
	if state == MANEUVER and away2 > (leash + Orders.ANCHOR_SLACK) ^ 2 then
		if not (head and head.kind == "move") then
			giveAuto(sim, id, "move", ax, az) -- too far: back to the anchor
		end
		return
	end
	if engaged(sim, id) then
		return -- a weapon has a shot: stay (an automatic fight order holds)
	end
	local tx, tz
	if state == ROAM then
		tx, tz = chaseTarget(sim, id, x, z, d.maxRange + Orders.ROAM_CHASE)
	else
		tx, tz = chaseTarget(sim, id, ax, az, d.maxRange + leash)
	end
	if tx and tz then
		if not (head and head.kind == "fight" and head.x == tx and head.z == tz) then
			giveAuto(sim, id, "fight", tx :: number, tz :: number)
		end
	elseif head == nil or head.kind == "fight" then
		-- nothing (left) to chase
		if state == ROAM then
			if head ~= nil then
				Orders.stop(sim, id)
			end
			o.anchorX[id], o.anchorZ[id] = x, z -- roaming units stay where they end up
		elseif away2 > Orders.ANCHOR_SLACK ^ 2 then
			giveAuto(sim, id, "move", ax, az)
		elseif head ~= nil then
			Orders.stop(sim, id)
			o.anchorX[id], o.anchorZ[id] = ax, az
		end
	end
end

-- Move-state behavior of idle units (start of the Orders step).
function Orders.autoStep(sim: Types.Sim)
	if sim.nav == nil then
		return
	end
	local tick = sim.tick
	for _, id in sim.world.ids do
		if (Hash.mix32(id) + tick) % Orders.AUTO_PERIOD == 0 then
			autoUnit(sim, id)
		end
	end
end

local starters: { number } = {}
local startBatches: { [number]: { number } } = {}
local batchOrder: { number } = {}

-- Orders system body: start and check every head order (after Commands).
function Orders.step(sim: Types.Sim)
	local w = sim.world
	local o = sim.orders
	local air = sim.air
	Orders.autoStep(sim)
	table.clear(starters)
	for _, id in w.ids do
		local q = o.queue[id]
		if q == nil then
			continue
		end
		local phase = air.phase[id]
		if phase ~= nil and phase ~= "fly" then
			-- away rearming: restart the head order when flying again
			local h = q[1]
			if h and isMoveLike(h.kind) then
				h.started = false
			end
			continue
		end
		-- several finished orders can pop in one tick (e.g. invalid targets)
		for _ = 1, #q do
			local h = q[1]
			if h == nil then
				break
			end
			if not h.started then
				if isMoveLike(h.kind) then
					table.insert(starters, id)
					break
				end
				if not start(sim, id, h) then
					pop(sim, id, q)
					continue
				end
			end
			if run(sim, id, h) then
				break
			end
			pop(sim, id, q)
		end
	end
	-- move-like heads start together per command: one Nav order each batch
	if #starters == 0 or sim.nav == nil then
		return
	end
	table.clear(startBatches)
	table.clear(batchOrder)
	for _, id in starters do
		local h = (o.queue[id] :: { Order })[1]
		local key = h.batch
		local list = startBatches[key]
		if list == nil then
			list = {}
			startBatches[key] = list
			table.insert(batchOrder, key)
		end
		table.insert(list, id)
	end
	table.sort(batchOrder)
	for _, key in batchOrder do
		local list = startBatches[key]
		local h0 = (o.queue[list[1]] :: { Order })[1]
		local tx, tz = h0.x :: number, h0.z :: number
		-- members whose head already points elsewhere (a patrol's way back) go alone
		local together = {}
		for _, id in list do
			local h = (o.queue[id] :: { Order })[1]
			if h.x == tx and h.z == tz then
				table.insert(together, id)
			else
				Nav.issueMove(sim.nav :: Nav.Nav, w, sim.tick, { id }, h.x :: number, h.z :: number)
				h.started, h.nav = true, w.orderId[id]
			end
		end
		if #together > 0 then
			Nav.issueMove(sim.nav :: Nav.Nav, w, sim.tick, together, tx, tz, h0.lx, h0.lz)
			for _, id in together do
				local h = (o.queue[id] :: { Order })[1]
				if h.kind == "patrol" and h.ox == nil then
					h.ox, h.oz = w.posX[id], w.posZ[id] -- the other end: where it started
				end
				h.started, h.nav = true, w.orderId[id]
			end
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	OrdersState.clearUnit(sim.orders, id)
end)

return Orders
