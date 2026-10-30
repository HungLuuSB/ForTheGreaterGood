--!strict
--!native
-- System 6: steering, local avoidance and position update (guide 6.5–6.6).
--
-- Per tick, in four passes over world.ids (deterministic order):
--   1. Steer: each unit with an order picks a direction (straight to its own
--      goal when the line is clear, else the shared flow field, else straight),
--      adds separation from nearby units (spatial hash), turns its heading at
--      its turn rate and accelerates/brakes toward a speed that slows to a
--      stop at the goal. Reads only start-of-tick positions.
--   2. Move along the heading; blocked cells make the unit slide along the
--      free axis, or stop.
--   3. Resolve overlaps: push overlapping pairs apart. Idle units yield to
--      moving ones (push priority, guide 6.5). Pushes never enter blocked cells.
--   4. Write changed positions/headings through World setters (dirty bits).
-- Idle units that aren't touched cost nothing and replicate nothing.
--
-- Terrain (S-37): a unit's top speed is scaled by its move class's factor
-- for the cell it is on (Shared/Grid/Terrain).
--
-- Arrival: within ARRIVE_RADIUS of its own goal, or no progress for
-- STUCK_TICKS while within GIVE_UP_RANGE (crowded goal) → the order ends.
-- Units outside their order's corridor, or without progress for REPATH_TICKS,
-- are collected and the order's field is extended to cover them.
-- Idle units hold their spot: one pushed more than its radius from its goal
-- (last move target, or spawn point) steers straight back to it.
-- The MOVING state bit (client request 14): ground and naval units with a
-- movement order or speed, aircraft unless landed (loitering included);
-- written only when it changes, so idle units still cost nothing.
-- SUBMERGED for amphibious units (S-39): set in water at least as deep as
-- the hull is tall (they drive on the sea floor), cleared on land and in
-- the shallows.

local Air = require("../Air")
local Deploy = require("../Deploy")
local FlowField = require("../Path/FlowField")
local Layers = require("@shared/Grid/Layers")
local MoveClasses = require("@shared/Defs/MoveClasses")
local Nav = require("../Nav")
local Quadtree = require("../Path/Quadtree")
local Terrain = require("@shared/Grid/Terrain")
local Transport = require("../Transport")
local Types = require("../Types")
local World = require("../World")

local DT = 1 / 15
local MOVING, LANDED, SUBMERGED = World.State.MOVING, World.State.LANDED, World.State.SUBMERGED
local HASH_CELL = 16 -- studs per spatial hash bucket
local SLIDE_MIN = 0.5 -- a unit sliding along a blocked cell keeps at least this share of its top speed (S-135)
local EXIT_SLACK = 24 -- a unit driving out of its factory stops passing through blocked cells this far past it (S-133)
local SEPARATION_MARGIN = 2 -- studs beyond touching where separation starts
local SEPARATION_WEIGHT = 1.5
local OVERLAP_PASSES = 2
local STUCK_TICKS = 45
local GIVE_UP_RANGE = 24 -- studs
local REPATH_TICKS = 90 -- no progress for this long anywhere → extend the field
local RETURN_SPEED = 0.6 -- fraction of max speed for idle units returning to their spot
local DIRECT_STAGGER = 4 -- re-check the straight line every N ticks per unit

local sqrt, sin, cos, atan2 = math.sqrt, math.sin, math.cos, math.atan2
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local PI, TAU = math.pi, 2 * math.pi

-- Scratch arrays indexed by position k in world.ids; reused every tick.
local nx: { number } = {}
local nz: { number } = {}
local nheading: { number } = {}
local nspeed: { number } = {}
local moving: { boolean } = {}
local anchored: { boolean } = {} -- deploying / deployed / packing: no movement, no push (S-64)
local prof: { Nav.Profile? } = {}
local exitOf: { { number } | false } = {} -- driving out of its factory (S-133)

-- Spatial hash as bucket heads + per-k links (no per-tick allocation once warm).
local bucketHead: { [number]: number } = {}
local bucketUsed: { number } = {}
local nextInBucket: { number } = {}
local bucketOf: { number } = {}

-- Cells needing field coverage this tick, per order (order IDs in first-seen order).
local coverOrders: { number } = {}
local coverCells: { [number]: { number } } = {}

local function wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
end

local function buildHash(n: number, xs: { number }, zs: { number }, originX: number, originZ: number, bw: number, bh: number)
	for i = 1, #bucketUsed do
		bucketHead[bucketUsed[i]] = nil
		bucketUsed[i] = nil
	end
	for k = 1, n do
		local bx = min(max(floor((xs[k] - originX) / HASH_CELL), 0), bw - 1)
		local bz = min(max(floor((zs[k] - originZ) / HASH_CELL), 0), bh - 1)
		local b = bz * bw + bx
		local head = bucketHead[b]
		if head == nil then
			table.insert(bucketUsed, b)
			nextInBucket[k] = 0
		else
			nextInBucket[k] = head
		end
		bucketHead[b] = k
		bucketOf[k] = b
	end
end

-- Sets or clears every unit's MOVING bit to match what it is doing now, and
-- amphibious units' SUBMERGED bit to the water they are in.
local function updateMoving(sim: Types.Sim, profiles: { [number]: any })
	local w = sim.world
	local nav = sim.nav :: Nav.Nav
	local layers, g = nav.pm.layers, nav.grid
	local hulls = sim.combat.profiles
	local band, bor, bnot = bit32.band, bit32.bor, bit32.bnot
	for _, id in w.ids do
		local p = profiles[w.defIndex[id]]
		local state = w.state[id]
		local now = false
		if p ~= nil then
			if p.air then
				now = band(state, LANDED) == 0
			else
				now = w.orderId[id] ~= 0 or w.speed[id] > 0
			end
		end
		local next = if now then bor(state, MOVING) else band(state, bnot(MOVING))
		if p ~= nil and MoveClasses[p.moveClass] ~= nil and MoveClasses[p.moveClass].surface == "amphib" then -- AMPHIB, AMPHIB_WALKER (S-210)
			local cx, cz = g:cellAt(w.posX[id], w.posZ[id])
			local under = Layers.getWater(layers, cz * g.cellsX + cx) >= hulls[w.defIndex[id]].height
			next = if under then bor(next, SUBMERGED) else band(next, bnot(SUBMERGED))
		end
		if next ~= state then
			World.setState(w, id, next)
		end
	end
end

return function(sim: Types.Sim)
	local nav = sim.nav
	if nav == nil then
		return
	end
	Deploy.step(sim)
	local w = sim.world
	local ids = w.ids
	local n = #ids
	if n == 0 then
		return
	end
	local tick = sim.tick
	local g = nav.grid
	local originX, originZ = g.originX, g.originZ
	local bw, bh = math.ceil(g.sizeX / HASH_CELL), math.ceil(g.sizeZ / HASH_CELL)
	local posX, posZ, heading, speed = w.posX, w.posZ, w.heading, w.speed
	local profiles = nav.profiles
	local layers = nav.pm.layers

	-- Start-of-tick positions into the scratch arrays and hash.
	local anyActive = false
	local maxRadius = 0 -- of the units present: a big def elsewhere in the roster mustn't widen every search
	for k = 1, n do
		local id = ids[k]
		nx[k] = posX[id]
		nz[k] = posZ[id]
		nheading[k] = heading[id]
		nspeed[k] = speed[id]
		local p = profiles[w.defIndex[id]]
		prof[k] = p
		if p and p.radius > maxRadius then
			maxRadius = p.radius
		end
		moving[k] = w.orderId[id] ~= 0
		anchored[k] = Deploy.anchored(w, id)
		local exit = sim.build.exiting[id]
		if exit then
			-- out of the footprint on open ground (or stopped past its edge):
			-- done, checked every tick, not only while moving (S-155: a unit
			-- that stopped at its exit point kept the flag for good)
			local out = max(abs(posX[id] - exit[1]), abs(posZ[id] - exit[2])) - exit[3] - (if p then p.radius else 0)
			if out > 0 and (p == nil or speed[id] <= 0 or Nav.fits(nav, p, posX[id], posZ[id])) then
				sim.build.exiting[id] = nil
				exit = nil
			end
		end
		exitOf[k] = exit or false
		anyActive = anyActive or moving[k] or speed[id] > 0 or exitOf[k] ~= false -- (walking out of a footprint: S-133, S-155)
			or nav.face[id] ~= nil -- (turning to a line's front: S-188)
	end
	if not anyActive then
		-- Nothing is moving: nothing can start overlapping either. Aircraft
		-- still climb or settle onto their pads (S-71: a jet landing while
		-- nothing else moved stayed at cruise height).
		for k = 1, n do
			local p = prof[k]
			if p and p.air then
				Air.updateAltitude(sim, ids[k])
			end
		end
		updateMoving(sim, profiles)
		return
	end
	buildHash(n, nx, nz, originX, originZ, bw, bh)
	local rings = math.ceil((2 * maxRadius + SEPARATION_MARGIN) / HASH_CELL)

	-- 1. Steer
	local holdOf = sim.orders.hold
	for k = 1, n do
		local id = ids[k]
		local p = prof[k]
		if p == nil then
			continue -- immobile
		end
		if p.jet then
			nheading[k], nspeed[k] = Air.steerJet(sim, id, p, nx[k], nz[k], nheading[k], nspeed[k])
			continue
		end
		if anchored[k] then
			nspeed[k] = 0 -- unpacked or (un)packing: it holds its spot (Deploy)
			w.progressTick[id] = tick
			continue
		end
		local x, z = nx[k], nz[k]
		local gx, gz = w.goalX[id], w.goalZ[id]
		local dx, dz = gx - x, gz - z
		local dist = sqrt(dx * dx + dz * dz)
		local returning = false
		local exit = exitOf[k]
		if exit and not moving[k] then
			-- stopped inside its factory: it still drives out (S-133)
			gx, gz = exit[4], exit[5]
			w.goalX[id], w.goalZ[id] = gx, gz
			dx, dz = gx - x, gz - z
			dist = sqrt(dx * dx + dz * dz)
		end
		if not moving[k] then
			-- (a unit walking out of a footprint never counts as settled: S-155)
			if not exit and (dist <= p.radius or (dist <= Nav.ARRIVE_RADIUS * 4 and nspeed[k] <= 0)) then
				-- at its spot (or close enough and settled): brake to a stop
				if nspeed[k] > 0 then
					nspeed[k] = max(0, nspeed[k] - p.brake * DT)
				else
					-- stopped on a line move's slot: turn in place to face the
					-- line's front (S-188, F34)
					local face = nav.face[id]
					if face ~= nil then
						if tick > (nav.faceUntil[id] or 0) then
							nav.face[id], nav.faceUntil[id] = nil, nil
						else
							local diff = (face - nheading[k] + math.pi) % (2 * math.pi) - math.pi
							local turn = p.turnRate * DT
							if math.abs(diff) <= turn then
								nheading[k] = face
								nav.face[id], nav.faceUntil[id] = nil, nil
							else
								nheading[k] += if diff > 0 then turn else -turn
							end
						end
					end
				end
				continue
			end
			returning = true -- pushed off its spot: walk back
		end

		-- engaged on a fight / patrol move (Orders): keep the order, brake, hold
		if not returning and holdOf[id] then
			w.progressTick[id] = tick
			nspeed[k] = max(0, nspeed[k] - p.brake * DT)
			continue
		end

		-- progress tracking and arrival
		if dist < w.bestDist[id] - 0.5 then
			w.bestDist[id] = dist
			w.progressTick[id] = tick
		end
		local gaveUp = not returning and dist > Nav.ARRIVE_RADIUS and dist < GIVE_UP_RANGE and tick - w.progressTick[id] > STUCK_TICKS
		if dist <= Nav.ARRIVE_RADIUS or gaveUp then
			if not returning then
				Nav.clearOrder(nav, w, id)
				moving[k] = false
			end
			if gaveUp then
				-- crowded goal: this spot becomes the unit's spot to hold
				w.goalX[id], w.goalZ[id] = x, z
			end
			nspeed[k] = max(0, nspeed[k] - p.brake * DT)
			continue
		end

		local order = if returning then nil else nav.orders[w.orderId[id]]
		local cx, cz = g:cellAt(x, z)
		local cell = if g:inBounds(cx, cz) then cz * g.cellsX + cx else -1

		-- Is the straight line to our own goal clear? Re-checked every few ticks,
		-- except for orders that took the direct-path shortcut (no field): their
		-- lines were checked in full when the order was issued, and a unit that
		-- stalls asks for a field below.
		local shortcut = order ~= nil and order.field == nil and not order.pending
		if returning then
			w.direct[id] = true
		elseif not shortcut and (id + tick) % DIRECT_STAGGER == 0 then
			local direct = p.air
			if not direct and order and cell >= 0 then
				local tree = Nav.tree(nav, p.moveClass, p.need, p.treeKey)
				local gcx, gcz = g:cellAt(gx, gz)
				if g:inBounds(gcx, gcz) and Quadtree.leafAt(tree, cell) == Quadtree.leafAt(tree, gcz * g.cellsX + gcx) and Quadtree.isOpen(tree, cell) then
					direct = true -- same open leaf: a free square, so the line is clear
				elseif dist <= Nav.DIRECT_RANGE then
					direct = Nav.clearLine(nav, p, x, z, gx, gz)
				end
			end
			w.direct[id] = direct
		end

		local dirX, dirZ = dx / dist, dz / dist
		if exit then
			-- out of its factory first, whatever the order (S-133)
			local ex, ez = exit[4] - x, exit[5] - z
			local el = sqrt(ex * ex + ez * ez)
			if el > 1e-9 then
				dirX, dirZ = ex / el, ez / el
			end
		end
		local stalled = tick - w.progressTick[id] > REPATH_TICKS
		if order and cell >= 0 and not exit and (order.field or (shortcut and stalled)) and (not w.direct[id] or stalled) then
			local field = order.field
			local d = if field then FlowField.direction(field, cell) else FlowField.NONE
			if field and d ~= FlowField.NONE and not w.direct[id] then
				dirX, dirZ = FlowField.vector(d)
			end
			if field == nil or (d == FlowField.NONE and cell ~= field.goalCell) or stalled then
				local oid = w.orderId[id]
				local list = coverCells[oid]
				if list == nil then
					list = {}
					coverCells[oid] = list
					table.insert(coverOrders, oid)
				end
				table.insert(list, cell)
			end
		end

		-- separation from nearby units of the same layer (ground / air)
		local sepX, sepZ = 0, 0
		local b = bucketOf[k]
		local bx, bz = b % bw, b // bw
		for oz = max(bz - rings, 0), min(bz + rings, bh - 1) do
			for ox = max(bx - rings, 0), min(bx + rings, bw - 1) do
				local j = bucketHead[oz * bw + ox]
				while j ~= nil and j ~= 0 do
					local q = prof[j]
					if j ~= k and q ~= nil and q.air == p.air then
						local ex, ez = x - nx[j], z - nz[j]
						local d2 = ex * ex + ez * ez
						local reach = p.radius + q.radius + SEPARATION_MARGIN
						if d2 < reach * reach and d2 > 1e-12 then
							local d = sqrt(d2)
							local s = (1 - d / reach) / d
							sepX += ex * s
							sepZ += ez * s
						end
					end
					j = nextInBucket[j]
				end
			end
		end

		local desX, desZ = dirX + SEPARATION_WEIGHT * sepX, dirZ + SEPARATION_WEIGHT * sepZ
		local desLen = sqrt(desX * desX + desZ * desZ)
		if exit or desLen < 1e-9 then
			-- (driving out of its factory: straight for the exit, no jostling; S-133)
			desX, desZ = dirX, dirZ
		end

		-- turn toward the desired heading (forward = (sin h, cos h))
		local h = nheading[k]
		local diff = wrapAngle(atan2(desX, desZ) - h)
		local maxTurn = p.turnRate * DT
		h = wrapAngle(h + max(-maxTurn, min(maxTurn, diff)))
		nheading[k] = h

		-- speed: slow down to stop at the goal, and while facing away
		-- terrain: the cell under the unit scales its top speed (S-37)
		local top = p.maxSpeed * (sim.transport.slow[id] or 1) -- a loaded transport (S-219)
		if not p.air then
			local tx, tz = g:cellAt(nx[k], nz[k])
			-- (clamped: a ground unit off the map, e.g. a debug spawn, used to
			-- index past the terrain layer and stop the whole sim; client-B)
			tx, tz = min(max(tx, 0), g.cellsX - 1), min(max(tz, 0), g.cellsZ - 1)
			top *= Terrain.factor(layers, p.moveClass, tz * g.cellsX + tx)
			-- a group move (ctrl): no faster than the group's slowest (S-137)
			local q = sim.orders.queue[id]
			local head = q and q[1]
			if head and head.speedCap and head.started then
				top = min(top, head.speedCap)
			end
		end
		local target = min(if returning then top * RETURN_SPEED else top, sqrt(2 * p.brake * max(dist - Nav.ARRIVE_RADIUS, 0)))
		target *= max(0, cos(diff))
		local v = nspeed[k]
		if v < target then
			v = min(target, v + p.accel * DT)
		else
			v = max(target, v - p.brake * DT)
		end
		nspeed[k] = v
	end

	-- Extend fields for units that fell outside them or stalled.
	for i, oid in coverOrders do
		local order = nav.orders[oid]
		if order then
			Nav.extendField(nav, order, coverCells[oid], tick)
		end
		coverCells[oid] = nil
		coverOrders[i] = nil
	end

	-- 2. Move, sliding along blocked cells
	for k = 1, n do
		local p = prof[k]
		local v = nspeed[k]
		if p == nil or v <= 0 then
			continue
		end
		local h = nheading[k]
		local x, z = nx[k], nz[k]
		local tx, tz = x + sin(h) * v * DT, z + cos(h) * v * DT
		if p.air then
			-- aircraft stay within Air.OVERFLY of the map (S-189; over it
			-- before protocol 38, S-183; jets turn back first, Air.steerJet)
			local g = nav.grid
			tx = math.clamp(tx, g.originX - Air.OVERFLY, g.originX + g.sizeX + Air.OVERFLY)
			tz = math.clamp(tz, g.originZ - Air.OVERFLY, g.originZ + g.sizeZ + Air.OVERFLY)
		end
		local exit = exitOf[k]
		if exit then
			-- out of its factory from the build pad: through the footprint,
			-- until clear of it on open ground (or 3 cells past it) (S-133)
			nx[k], nz[k] = tx, tz
			local out = max(abs(tx - exit[1]), abs(tz - exit[2])) - exit[3] - p.radius
			if (out > 0 and Nav.fits(nav, p, tx, tz)) or out > EXIT_SLACK then
				sim.build.exiting[ids[k]] = nil
				exitOf[k] = false
			end
		elseif Nav.fits(nav, p, tx, tz) then
			nx[k], nz[k] = tx, tz
		elseif Nav.fits(nav, p, tx, z) then
			nx[k] = tx
			nspeed[k] = max(v * 0.5, p.maxSpeed * SLIDE_MIN)
		elseif Nav.fits(nav, p, x, tz) then
			nz[k] = tz
			nspeed[k] = max(v * 0.5, p.maxSpeed * SLIDE_MIN)
		else
			nspeed[k] = 0
		end
	end

	-- 3. Resolve overlaps (pairs once: j after k in ids order)
	for _ = 1, OVERLAP_PASSES do
		buildHash(n, nx, nz, originX, originZ, bw, bh)
		for k = 1, n do
			local p = prof[k]
			if p == nil then
				continue
			end
			local b = bucketOf[k]
			local bx, bz = b % bw, b // bw
			for oz = max(bz - rings, 0), min(bz + rings, bh - 1) do
				for ox = max(bx - rings, 0), min(bx + rings, bw - 1) do
					local j = bucketHead[oz * bw + ox]
					while j ~= nil and j ~= 0 do
						local q = prof[j]
						if j > k and q ~= nil and q.air == p.air and not p.jet and not q.jet then
							local ex, ez = nx[k] - nx[j], nz[k] - nz[j]
							local d2 = ex * ex + ez * ez
							local minD = p.radius + q.radius
							if d2 < minD * minD then
								local d = sqrt(d2)
								local ux, uz
								if d > 1e-9 then
									ux, uz = ex / d, ez / d
								else
									-- exactly on top of each other: split along a fixed axis
									ux, uz, d = 1, 0, 0
								end
								local pen = minD - d
								local shareK, shareJ = 0.5, 0.5
								if moving[k] and not moving[j] then
									shareK, shareJ = 0.2, 0.8
								elseif moving[j] and not moving[k] then
									shareK, shareJ = 0.8, 0.2
								end
								if anchored[k] then
									shareK, shareJ = 0, if anchored[j] then 0 else 1
								elseif anchored[j] then
									shareK, shareJ = 1, 0
								end
								local kx, kz = nx[k] + ux * pen * shareK, nz[k] + uz * pen * shareK
								if Nav.fits(nav, p, kx, kz) then
									nx[k], nz[k] = kx, kz
								end
								local jx, jz = nx[j] - ux * pen * shareJ, nz[j] - uz * pen * shareJ
								if Nav.fits(nav, q, jx, jz) then
									nx[j], nz[j] = jx, jz
								end
							end
						end
						j = nextInBucket[j]
					end
				end
			end
		end
	end

	-- 4. Write back what changed
	for k = 1, n do
		local id = ids[k]
		if nx[k] ~= posX[id] or nz[k] ~= posZ[id] then
			World.setPosition(w, id, nx[k], nz[k])
		end
		if nheading[k] ~= heading[id] then
			World.setHeading(w, id, nheading[k])
		end
		speed[id] = nspeed[k]
		local p = prof[k]
		if p and p.air then
			Air.updateAltitude(sim, id)
		end
	end
	updateMoving(sim, profiles)
	Transport.step(sim) -- carried units ride along (S-219)
end
