--!strict
-- Unit order queues and behaviors (guide 15.6 "shift queues commands";
-- docs/contracts/net.md 9; S-4).
--
-- Each mobile unit has a queue of orders, head first. A command replaces the
-- queue, or with the queue flag (shift) is appended to it. Every tick (at the
-- end of the Commands system) the head order is started or checked:
--   move     a Nav move; done on arrival (the Nav order ends).
--   fight    attack-move: a move that holds (brakes, keeps the order) while
--            the unit has a weapon target, then goes on. Jets don't hold.
--   patrol   fight back and forth between the unit's start and the point,
--            forever (orders queued behind it never start).
--   attack   force-fire a unit the team knows (VISIBLE, radar, ghost): its
--            weapons that can engage it pick it (Targeting) even on hold
--            fire; the unit chases to 90% of its longest range. Done when
--            the team no longer knows the target.
--   guard    stay within GUARD_RADIUS of an allied unit (builders assist it
--            when it is a frame or a factory). Done when it is gone.
--   repair / reclaim / build
--            the Build commands; done when the builder is idle again.
--            Repair also heals damaged finished units (Build, S-4).
--   attackGround  bombers' attack-ground (D100); kept until replaced.
-- Units leaving a move together (same command, same tick) move as a group
-- (one Nav order, formation slots). Aircraft away rearming pause their
-- queue and restart the head order when they fly again.
--
-- Factories: a MOVE / FIGHT / PATROL given to a factory sets its rally
-- point; each unit it produces rolls out of the exit, then takes the rally
-- order. REPEAT on a factory turns repeat on or off: a finished item goes
-- back to the end of the queue (S-13; the REPEAT state bit shows it).

local Air = require("./Air")
local Build = require("./Build")
local Defs = require("@shared/Defs/Defs")
local Lifecycle = require("./Lifecycle")
local Nav = require("./Nav")
local OrdersState = require("./OrdersState")
local Sensors = require("./Sensors")
local Types = require("./Types")
local World = require("./World")

local Orders = {}

local REPEAT = World.State.REPEAT

Orders.GUARD_RADIUS = 80 -- studs
Orders.CHASE_STEP = 24 -- studs: re-aim a chase move when the target moved this far
Orders.CHASE_EVERY = 15 -- ticks between chase moves
Orders.ATTACK_REACH = 0.9 -- of the unit's longest weapon range

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
}

local function def(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

local function isFactory(d: Defs.UnitDef): boolean
	return d.domain == "structure" and d.buildOptions ~= nil
end

local function isMoveLike(kind: string): boolean
	return kind == "move" or kind == "fight" or kind == "patrol"
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
-- `queued`, appends; else replaces their queues. Factories take move-like
-- orders as their rally point instead.
function Orders.give(sim: Types.Sim, ids: { number }, spec: OrderSpec, queued: boolean)
	local o = sim.orders
	local batch = o.nextBatch
	o.nextBatch += 1
	for _, id in ids do
		local d = def(sim, id)
		if d.domain == "structure" then
			if isFactory(d) and isMoveLike(spec.kind) and spec.x then
				o.rallyKind[id] = if spec.kind == "move" then "move" else "fight"
				o.rallyX[id], o.rallyZ[id] = spec.x :: number, spec.z :: number
			end
			continue
		end
		local q = o.queue[id]
		if q == nil or not queued then
			if q ~= nil and #q > 0 then
				cancelCurrent(sim, id)
			end
			q = {}
			o.queue[id] = q
		end
		table.insert(q, {
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
			started = false,
			nav = 0,
			issued = -math.huge,
		})
	end
end

-- STOP: clears the queue and halts.
function Orders.stop(sim: Types.Sim, id: number)
	local o = sim.orders
	if o.queue[id] then
		o.queue[id] = nil
	end
	cancelCurrent(sim, id)
	halt(sim, id)
end

-- REPEAT on a factory: repeat on / off. Other units ignore it.
function Orders.setRepeat(sim: Types.Sim, factory: number, on: boolean)
	if not isFactory(def(sim, factory)) then
		return
	end
	sim.orders.repeatOn[factory] = if on then true else nil
	local w = sim.world
	local state = w.state[factory]
	World.setState(w, factory, if on then bit32.bor(state, REPEAT) else bit32.band(state, bit32.bnot(REPEAT)))
end

-- A factory produced `id` (Build): roll out of the exit, then the rally order.
local function onProduced(sim: Types.Sim, factory: number, id: number, exitX: number, exitZ: number)
	local o = sim.orders
	Orders.give(sim, { id }, { kind = "move", x = exitX, z = exitZ }, false)
	local rally = o.rallyKind[factory]
	if rally then
		Orders.give(sim, { id }, { kind = rally, x = o.rallyX[factory], z = o.rallyZ[factory] }, true)
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

local function engaged(sim: Types.Sim, id: number): boolean
	local w = sim.world
	for slot = 1, w.weaponCount[id] do
		if w.wTarget[World.slotKey(id, slot)] ~= 0 then
			return true
		end
	end
	return false
end

local function builderIdle(sim: Types.Sim, id: number): boolean
	local b = sim.build
	return b.order[id] == nil and (b.target[id] or 0) == 0 and (b.reclaim[id] or 0) == 0
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
	elseif kind == "build" then
		Build.commandBuild(sim, { id }, h.defIndex :: number, h.x :: number, h.z :: number, h.facing or 0)
	elseif kind == "attackGround" then
		if not Air.isBomber(sim, def(sim, id)) then
			return false -- only bombers take it: done
		end
		Air.attackGround(sim, id, h.x :: number, h.z :: number)
	elseif kind == "guard" then
		local t = h.target :: number
		local td = def(sim, t)
		if def(sim, id).buildPower and (w.buildProgress[t] < 1 or isFactory(td)) then
			Build.commandAssist(sim, { id }, t)
		end
	end
	h.started = true
	return true
end

-- Per-tick work on one unit's head order; returns false when it is done.
local function run(sim: Types.Sim, id: number, h: Order): boolean
	local w = sim.world
	local o = sim.orders
	local kind = h.kind
	if isMoveLike(kind) then
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
		if kind ~= "move" then
			o.hold[id] = engaged(sim, id) and def(sim, id).moveClass ~= "JET" or nil
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
		if d.domain == "air" then
			return true -- aircraft chase their target themselves
		end
		local reach = d.maxRange * Orders.ATTACK_REACH
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
		local dx, dz = w.posX[t] - w.posX[id], w.posZ[t] - w.posZ[id]
		local d2 = dx * dx + dz * dz
		if d2 > Orders.GUARD_RADIUS ^ 2 then
			chase(sim, id, h, w.posX[t], w.posZ[t])
		elseif d2 < (Orders.GUARD_RADIUS / 2) ^ 2 and w.orderId[id] ~= 0 then
			halt(sim, id)
		end
		return true
	elseif kind == "attackGround" then
		return true -- until replaced
	end
	-- repair / reclaim / build
	return not builderIdle(sim, id)
end

local starters: { number } = {}
local startBatches: { [number]: { number } } = {}
local batchOrder: { number } = {}

-- Orders system body: start and check every head order (after Commands).
function Orders.step(sim: Types.Sim)
	local w = sim.world
	local o = sim.orders
	local air = sim.air
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
