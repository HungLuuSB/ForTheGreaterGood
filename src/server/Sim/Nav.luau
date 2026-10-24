--!strict
-- Navigation state shared by the Commands, Pathing and Movement systems
-- (guide 6.3–6.6): per-def movement profiles, quadtrees (built when the map
-- loads, updated locally when terrain changes), the flow field cache and job
-- queue, and move orders.
--
-- A move order covers the units of one (move class, clearance need) group.
-- The group shares one flow field to the group goal; each unit also gets its
-- own goal (a formation slot, or a point on the line for line moves) and
-- steers straight to it once the line there is clear.
--
-- Issuing an order (Commands) only groups the units, snaps the goal and
-- assigns slots. The rest is a plan job in the Pathing queue, sliced by work
-- units like flow fields (DECISIONS D83): each unit's direct-line check, then
-- the coarse route and corridor, then the flow field job. Until the plan is
-- done the order is pending and its units steer straight at their slots.
-- An order for SLICED_ASSIGN_MIN units or more (a select-all order) gets its
-- ground groups' slots in the plan job too (S-67): sorted and assigned from
-- a snapshot of positions taken when issued, so the picks are those of an
-- immediate assignment, but the units head for the formation's center until
-- their slots arrive.

local Formation = require("@shared/Grid/Formation")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")
local FieldCache = require("./Path/FieldCache")
local FlowField = require("./Path/FlowField")
local Quadtree = require("./Path/Quadtree")
local Terrain = require("@shared/Grid/Terrain")
local Route = require("./Path/Route")
local World = require("./World")

local Nav = {}

Nav.ARRIVE_RADIUS = 1.5 -- studs: a unit this close to its own goal has arrived
Nav.DIRECT_RANGE = 96 -- studs: line-of-sight checks for direct steering only this close
Nav.LINE_STEP = 2 -- studs between line-of-sight samples
Nav.SLOT_SPACING = Formation.SLOT_SPACING -- formation spacing, in unit diameters (shared, S-12)
Nav.RADIUS_PER_FOOTPRINT = PlacementRules.RADIUS_PER_FOOTPRINT -- collision radius per footprint cell (studs; shared, S-9)
Nav.PATHING_BUDGET = 36000 -- flow field work units per tick (DECISIONS D33, D53)
Nav.NEAREST_SEARCH_LIMIT = 4096 -- cells examined when snapping a goal to open ground
Nav.EXTEND_COOLDOWN = 15 -- ticks between field extensions for one order

export type Profile = {
	defIndex: number,
	maxSpeed: number,
	accel: number,
	brake: number,
	turnRate: number, -- radians per second
	radius: number, -- collision radius, studs
	footprint: number,
	need: number, -- required clearance
	moveClass: string,
	air: boolean,
	jet: boolean, -- JET steering (Air.steerJet): minimum speed, no hovering
	minSpeed: number?,
	treeKey: string, -- "moveClass:need", precomputed so hot paths don't build strings
}

export type Order = {
	id: number,
	moveClass: string,
	need: number,
	goalCell: number, -- group goal (the shared field's goal)
	field: FlowField.Field?,
	pending: boolean, -- a field job is queued or running
	unreachable: boolean,
	remaining: number, -- units still following this order
	lastExtendTick: number, -- last time the field was extended (-inf if never)
}

-- Planning phase of an order (see the header).
type Plan = {
	tree: Quadtree.Tree,
	-- big orders (S-67): slot sorting and assignment still to run, from the
	-- positions when issued
	slots: { { number } }?,
	sort: { number }?, -- deepestFirst's cx, cz, backX, backZ, spacing
	snapX: { [number]: number }?,
	snapZ: { [number]: number }?,
	assign: Formation.Assigner?,
	members: { number }, -- unit IDs given the order, ascending
	nextMember: number, -- next unit to line-check
	cells: { number }, -- start cells of units that need the field
	search: Route.Search?, -- coarse route, once every unit is checked
	extend: boolean?, -- a field extension (S-5): merge into the order's corridor, no cache lookup
}

-- A queued job: an order's plan, then (same entry) its flow field.
type JobEntry = { order: Order, plan: Plan?, key: string?, job: FlowField.Job? }

export type Nav = {
	pm: Passability.PassMap,
	grid: Grid.Grid,
	profiles: { [number]: Profile }, -- by unit def index; mobile units only
	trees: { [string]: Quadtree.Tree },
	treeKey: { [Quadtree.Tree]: string },
	dirty: { [string]: { { number } } }, -- per tree: terrain changes not applied yet (S-67)
	cache: FieldCache.Cache,
	jobs: { JobEntry }, -- FIFO: entries jobHead .. jobTail - 1
	jobHead: number,
	jobTail: number,
	orders: { [number]: Order },
	nextOrderId: number,
	maxRadius: number,
	issueWork: number, -- work units spent issuing orders since the last Pathing tick
	stats: { fieldsBuilt: number, cacheHits: number, workUnits: number, directOrders: number },
}

function Nav.new(pm: Passability.PassMap, defs: Defs.DefSet): Nav
	local profiles = {}
	local maxRadius = 0
	for index, def in defs.unitByIndex do
		local m = def.movement
		if m == nil or def.moveClass == nil then
			continue -- structures
		end
		local radius = def.footprint * Nav.RADIUS_PER_FOOTPRINT
		maxRadius = math.max(maxRadius, radius)
		profiles[index] = {
			defIndex = index,
			maxSpeed = m.maxSpeed,
			accel = m.accel,
			brake = m.brake,
			turnRate = math.rad(m.turnRate),
			radius = radius,
			footprint = def.footprint,
			need = Passability.requiredClearance(def.footprint),
			moveClass = def.moveClass :: string,
			air = def.domain == "air",
			jet = def.moveClass == "JET",
			minSpeed = m.minSpeed,
			treeKey = `{def.moveClass}:{Passability.requiredClearance(def.footprint)}`,
		}
	end
	local nav: Nav = {
		pm = pm,
		grid = pm.grid,
		profiles = profiles,
		trees = {},
		treeKey = {},
		dirty = {},
		cache = FieldCache.new(),
		jobs = {},
		jobHead = 1,
		jobTail = 1,
		orders = {},
		nextOrderId = 1,
		maxRadius = maxRadius,
		issueWork = 0,
		stats = { fieldsBuilt = 0, cacheHits = 0, workUnits = 0, directOrders = 0 },
	}
	-- Quadtrees for every ground profile now, at map load, not in the tick
	-- of the first order that needs one.
	for index = 1, #defs.unitByIndex do
		local p = profiles[index]
		if p and not p.air then
			Nav.tree(nav, p.moveClass, p.need, p.treeKey)
		end
	end
	return nav
end

-- Applies a tree's pending terrain changes (S-67), in the order they came.
-- A plan's route search over the tree restarts if the leaves changed.
local function flush(nav: Nav, k: string, tree: Quadtree.Tree)
	local rects = nav.dirty[k]
	nav.dirty[k] = nil
	local changed = false
	for _, r in rects do
		if Quadtree.update(tree, nav.pm, r[1], r[2], r[3], r[4], true) then
			changed = true
		end
	end
	if changed then
		Quadtree.computeComponents(tree) -- once for the batch
		for i = nav.jobHead, nav.jobTail - 1 do
			local plan = nav.jobs[i].plan
			if plan and plan.tree == tree and plan.search then
				plan.search = nil -- its leaf IDs are stale: search again
			end
		end
	end
end

function Nav.tree(nav: Nav, moveClass: string, need: number, key: string?): Quadtree.Tree
	local k = key or `{moveClass}:{need}`
	local tree = nav.trees[k]
	if tree == nil then
		tree = Quadtree.build(nav.pm, moveClass, need)
		tree.stepCost = Terrain.stepCosts(nav.pm.layers, moveClass) -- S-37
		nav.trees[k] = tree
		nav.treeKey[tree] = k
	elseif nav.dirty[k] then
		flush(nav, k, tree)
	end
	return tree
end

-- Can a unit with this profile stand at world (x, z)?
function Nav.fits(nav: Nav, p: Profile, x: number, z: number): boolean
	if p.air then
		return true
	end
	local g = nav.grid
	local cx, cz = g:cellAt(x, z)
	if not g:inBounds(cx, cz) then
		return false
	end
	return buffer.readu8(nav.pm.clearance[p.moveClass], cz * g.cellsX + cx) >= p.need
end

-- Is the straight segment clear for this profile? Samples every LINE_STEP studs.
function Nav.clearLine(nav: Nav, p: Profile, x0: number, z0: number, x1: number, z1: number): boolean
	if p.air then
		return true
	end
	local dx, dz = x1 - x0, z1 - z0
	local steps = math.ceil(math.sqrt(dx * dx + dz * dz) / Nav.LINE_STEP)
	for k = 1, steps do
		local t = k / steps
		if not Nav.fits(nav, p, x0 + dx * t, z0 + dz * t) then
			return false
		end
	end
	return true
end

-- Nearest open cell (4-connected BFS) in `component` (0 = any), or nil.
-- Scratch for nearestOpen (S-164: it built a direction table per cell
-- and a fresh `seen` set per call, 3–5 ms an order on B's Studio run):
-- cells seen in this search carry the search's stamp.
local seenStamp: buffer? = nil
local stamp = 0
local queue: { number } = {}
local function nearestOpen(tree: Quadtree.Tree, cell: number, component: number): number?
	local g = tree.grid
	local w, h = g.cellsX, g.cellsZ
	local seen = seenStamp
	if seen == nil or buffer.len(seen) < g.cellCount * 4 or stamp >= 4294967295 then
		seen = buffer.create(g.cellCount * 4)
		seenStamp = seen
		stamp = 0
	end
	local s = seen :: buffer
	stamp += 1
	local mark = stamp
	local readu32, writeu32 = buffer.readu32, buffer.writeu32
	writeu32(s, cell * 4, mark)
	queue[1] = cell
	local head, tail = 1, 1
	local limit = Nav.NEAREST_SEARCH_LIMIT
	while head <= tail and head <= limit do
		local c = queue[head]
		head += 1
		if Quadtree.isOpen(tree, c) and (component == 0 or Quadtree.component(tree, c) == component) then
			return c
		end
		local cx, cz = c % w, c // w
		-- the same neighbour order as before: +x, +z, -x, -z
		if cx + 1 < w and readu32(s, (c + 1) * 4) ~= mark then
			writeu32(s, (c + 1) * 4, mark)
			tail += 1
			queue[tail] = c + 1
		end
		if cz + 1 < h and readu32(s, (c + w) * 4) ~= mark then
			writeu32(s, (c + w) * 4, mark)
			tail += 1
			queue[tail] = c + w
		end
		if cx > 0 and readu32(s, (c - 1) * 4) ~= mark then
			writeu32(s, (c - 1) * 4, mark)
			tail += 1
			queue[tail] = c - 1
		end
		if cz > 0 and readu32(s, (c - w) * 4) ~= mark then
			writeu32(s, (c - w) * 4, mark)
			tail += 1
			queue[tail] = c - w
		end
	end
	return nil
end
Nav.nearestOpen = nearestOpen

-- The open cell (any component) on the smallest square ring around cell
-- (cx, cz) that has one, nearest the point (x, z); exact ties go to the
-- lower index. Mirror-symmetric, unlike nearestOpen's fixed search order
-- (S-161). Nil within CLEARANCE_CAP rings.
local function openNearPoint(tree: Quadtree.Tree, cx: number, cz: number, x: number, z: number): number?
	local g = tree.grid
	for r = 1, Passability.CLEARANCE_CAP do
		local best, bestD = nil :: number?, math.huge
		for dz = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dz)) == r then
					local nx, nz = cx + dx, cz + dz
					if g:inBounds(nx, nz) then
						local c = g:index(nx, nz)
						if Quadtree.isOpen(tree, c) then
							local px, pz = g:cellCenter(nx, nz)
							local d = (px - x) ^ 2 + (pz - z) ^ 2
							if d < bestD or (d == bestD and c < (best :: number)) then
								best, bestD = c, d
							end
						end
					end
				end
			end
		end
		if best then
			return best
		end
	end
	return nil
end

Nav.MAX_COMMAND_UNITS = 200 -- guide 22.3
Formation.spiral(Nav.MAX_COMMAND_UNITS * 4) -- built at load, not in the first order's tick

-- Greedy slot assignment (Shared/Grid/Formation, S-12): slot by slot, the
-- closest unassigned unit; ties go to the lower ID. Returns the unit per
-- slot (0 once units run out) and the number of distance checks made.
Nav.ASSIGN_BUCKET = Formation.ASSIGN_BUCKET
Nav.SLICED_ASSIGN_MIN = 64 -- orders this big assign their ground groups' slots in the Pathing job (S-67)
Nav.MAX_PENDING = 8 -- terrain changes a quadtree may defer before they're applied at once (S-67)
Nav.ISSUE_UNIT_COST = 10 -- work units per unit given an order (plus 1 per 4 assignment distance checks)
function Nav.assignSlots(w: World.World, members: { number }, slots: { { number } }): ({ number }, number)
	return Formation.assign(w.posX, w.posZ, members, slots)
end

-- Candidate goal positions for `n` units (Formation.layout): only
-- positions on open cells of the group's component are kept, and line
-- slots on blocked cells snap to the nearest open cell center.
local function slotsFor(
	nav: Nav,
	tree: Quadtree.Tree,
	component: number,
	n: number,
	spacing: number,
	cx: number,
	cz: number,
	lx: number?,
	lz: number?,
	backX: number,
	backZ: number
): { { number } }
	local g = nav.grid
	local ground: Formation.Ground = {
		open = function(x: number, z: number): boolean
			local gx, gz = g:cellAt(x, z)
			if not g:inBounds(gx, gz) then
				return false
			end
			local c = g:index(gx, gz)
			return Quadtree.isOpen(tree, c) and Quadtree.component(tree, c) == component
		end,
		snap = function(x: number, z: number): (number?, number?)
			local gx, gz = g:cellAt(x, z)
			gx, gz = math.clamp(gx, 0, g.cellsX - 1), math.clamp(gz, 0, g.cellsZ - 1)
			local snapped = nearestOpen(tree, g:index(gx, gz), component)
			if snapped == nil then
				return nil, nil
			end
			return g:cellCenter(g:coords(snapped))
		end,
	}
	return Formation.layout(n, spacing, cx, cz, lx, lz, backX, backZ, ground)
end

-- Appends to the job FIFO. (table.insert would misplace entries once the
-- consumed head slots are nil.)
local function enqueue(nav: Nav, entry: JobEntry)
	nav.jobs[nav.jobTail] = entry
	nav.jobTail += 1
end

-- A cached field for this order's goal that already covers `cells`, if any.
local function cachedField(nav: Nav, order: Order, cells: { number }): (string, FlowField.Field?)
	local key = FieldCache.key(order.moveClass, order.need, order.goalCell)
	local cached = FieldCache.get(nav.cache, key)
	if cached then
		for _, c in cells do
			if not Route.inCorridor(cached.corridor, c) then
				return key, nil
			end
		end
	end
	return key, cached
end

-- Ends a unit's order (arrived, stopped or replaced).
function Nav.clearOrder(nav: Nav, w: World.World, id: number)
	local oid = w.orderId[id]
	if oid ~= 0 then
		w.orderId[id] = 0
		local order = nav.orders[oid]
		if order then
			order.remaining -= 1
			if order.remaining <= 0 then
				nav.orders[oid] = nil
			end
		end
	end
end

-- Gives `unitIds` (alive, owned, mobile; any order) a move to (tx, tz), or
-- a line move from (tx, tz) to (lx, lz). Units are grouped by move class and
-- clearance need; each group gets one order and one shared field.
function Nav.issueMove(nav: Nav, w: World.World, tick: number, unitIds: { number }, tx: number, tz: number, lx: number?, lz: number?)
	local ids = table.clone(unitIds)
	table.sort(ids)

	-- group by (moveClass, need), deterministic key order
	local groups: { [string]: { number } } = {}
	local keys: { string } = {}
	for _, id in ids do
		local p = nav.profiles[w.defIndex[id]]
		if p == nil then
			continue
		end
		local key = if p.air then "air" else `{p.moveClass}:{p.need}`
		if groups[key] == nil then
			groups[key] = {}
			table.insert(keys, key)
		end
		local list = groups[key]
		if list[#list] ~= id then
			table.insert(list, id)
		end
	end
	table.sort(keys)

	local g = nav.grid
	local bigOrder = #ids >= Nav.SLICED_ASSIGN_MIN
	for _, key in keys do
		local members = groups[key]
		local first = nav.profiles[w.defIndex[members[1]]]
		local maxRadius = 0
		local sumX, sumZ = 0, 0
		for _, id in members do
			maxRadius = math.max(maxRadius, nav.profiles[w.defIndex[id]].radius)
			sumX += w.posX[id]
			sumZ += w.posZ[id]
		end
		local backX, backZ = sumX / #members, sumZ / #members
		local spacing = Formation.spacing(maxRadius)

		local order: Order = {
			id = nav.nextOrderId,
			moveClass = first.moveClass,
			need = first.need,
			goalCell = 0,
			field = nil,
			pending = false,
			unreachable = false,
			remaining = 0,
			lastExtendTick = -math.huge,
		}
		nav.nextOrderId += 1

		-- Center of the formation (the line's midpoint for line moves).
		local cx, cz = tx, tz
		if lx ~= nil and lz ~= nil then
			cx, cz = (tx + lx) / 2, (tz + lz) / 2
		end

		local slots: { { number } }
		local tree: Quadtree.Tree? = nil
		if first.air then
			slots = Formation.layout(#members, spacing, cx, cz, nil, nil, backX, backZ)
			order.moveClass = "air"
		else
			local t = Nav.tree(nav, first.moveClass, first.need)
			tree = t
			-- The group's component: that of the first member standing on open ground.
			local component = 0
			for _, id in members do
				local ux, uz = g:cellAt(w.posX[id], w.posZ[id])
				if g:inBounds(ux, uz) then
					local comp = Quadtree.component(t, g:index(ux, uz))
					if comp ~= 0 then
						component = comp
						break
					end
				end
			end
			local gx, gz = g:cellAt(cx, cz)
			gx, gz = math.clamp(gx, 0, g.cellsX - 1), math.clamp(gz, 0, g.cellsZ - 1)
			local goalCell = nearestOpen(t, g:index(gx, gz), component)
			if goalCell == nil then
				order.unreachable = true
				goalCell = g:index(gx, gz)
			elseif goalCell ~= g:index(gx, gz) then
				local sx, sz = g:coords(goalCell)
				cx, cz = g:cellCenter(sx, sz)
				if lx ~= nil and lz ~= nil then
					-- keep the line's shape around the snapped center
					local hx, hz = (lx - tx) / 2, (lz - tz) / 2
					tx, tz, lx, lz = cx - hx, cz - hz, cx + hx, cz + hz
				end
			end
			order.goalCell = goalCell :: number
			slots = slotsFor(nav, t, component, #members, spacing, if lx then tx else cx, if lx then tz else cz, lx, lz, backX, backZ)
		end

		-- Far side of the formation first, then each slot takes the closest
		-- unassigned unit; ties go to the lower ID (Shared/Grid/Formation).
		local assigned: { [number]: boolean } = {}
		local sliced = bigOrder and tree ~= nil and not order.unreachable
		local pick, checks = {}, 0
		local snapX, snapZ = nil, nil
		if sliced then
			-- a select-all order (S-67): the plan job sorts and assigns the
			-- slots, from where the units are now
			snapX, snapZ = {}, {}
			for _, id in members do
				snapX[id], snapZ[id] = w.posX[id], w.posZ[id]
			end
		else
			Formation.deepestFirst(slots, cx, cz, backX, backZ, spacing)
			pick, checks = Nav.assignSlots(w, members, slots)
		end
		-- issuing shares the tick's pathing budget (Pathing gets what's left)
		nav.issueWork += Nav.ISSUE_UNIT_COST * #members + checks // 4
		for i, slot in slots do
			local best = pick[i]
			if best == nil or best == 0 then
				break -- (sliced: no picks yet, every unit goes to the center below)
			end
			local bestD = (w.posX[best] - slot[1]) ^ 2 + (w.posZ[best] - slot[2]) ^ 2
			assigned[best] = true
			Nav.clearOrder(nav, w, best)
			w.orderId[best] = order.id
			w.goalX[best] = slot[1]
			w.goalZ[best] = slot[2]
			w.bestDist[best] = math.sqrt(bestD)
			w.progressTick[best] = tick
			w.direct[best] = false
			order.remaining += 1
		end
		-- Units without a slot (no open ground near the goal) go to the center.
		for _, id in members do
			if not assigned[id] then
				Nav.clearOrder(nav, w, id)
				w.orderId[id] = order.id
				w.goalX[id] = cx
				w.goalZ[id] = cz
				w.bestDist[id] = math.sqrt((w.posX[id] - cx) ^ 2 + (w.posZ[id] - cz) ^ 2)
				w.progressTick[id] = tick
				w.direct[id] = false
				order.remaining += 1
			end
		end
		nav.orders[order.id] = order

		if tree ~= nil and not order.unreachable then
			-- the direct-line checks, route and field run as a sliced job
			order.pending = true
			enqueue(nav, {
				order = order,
				plan = {
					tree = tree,
					slots = if sliced then slots else nil,
					sort = if sliced then { cx, cz, backX, backZ, spacing } else nil,
					snapX = snapX,
					snapZ = snapZ,
					members = table.clone(members),
					nextMember = 1,
					cells = {},
					search = nil,
				},
			})
		end
	end
end

-- Advances an order's plan within `budget` work units: returns the units
-- spent and whether the entry is finished (true when no field is needed;
-- false when it has turned into a field job or ran out of budget).
--   1. Direct-path shortcut: units whose straight line to their slot is
--      passable steer directly; only the others need the shared field (cost:
--      1 per unit, plus 1 per line sample). If every line is clear, no field.
--   2. Coarse route from the remaining units' cells (Route search units).
--   3. Corridor (1 per 8 corridor cells) and the flow field job.
local function runPlan(nav: Nav, w: World.World, entry: JobEntry, budget: number): (number, boolean)
	local order = entry.order
	local plan = entry.plan :: Plan
	local g = nav.grid
	local t = plan.tree
	local tk = nav.treeKey[t]
	if nav.dirty[tk] then
		flush(nav, tk, t) -- terrain changed since the last call (S-67)
	end
	local spent = 0
	if nav.orders[order.id] == nil then
		order.pending = false
		return 0, true -- every unit left the order: nothing to plan
	end

	-- 0. a big order's slot assignment (S-67): 4 distance checks per work
	-- unit, as when issuing; then each unit still in the order gets its slot
	if plan.slots then
		local slots = plan.slots :: { { number } }
		local sort = plan.sort :: { number }
		Formation.deepestFirst(slots, sort[1], sort[2], sort[3], sort[4], sort[5])
		plan.assign = Formation.newAssigner(plan.snapX :: any, plan.snapZ :: any, plan.members, slots)
		spent += #slots // 4 + #plan.members // 4
		plan.slots, plan.sort, plan.snapX, plan.snapZ = nil, nil, nil, nil
	end
	local a = plan.assign
	if a then
		local before = a.checks
		local done = Formation.assignStep(a, math.max(budget - spent, 1) * 4)
		spent += (a.checks - before) // 4 + 1
		if not done then
			return spent, false
		end
		for i, slot in a.slots do
			local id = a.pick[i]
			if id == 0 then
				break
			end
			if w.slot[id] ~= nil and w.orderId[id] == order.id then
				w.goalX[id], w.goalZ[id] = slot[1], slot[2]
				w.bestDist[id] = math.sqrt((w.posX[id] - slot[1]) ^ 2 + (w.posZ[id] - slot[2]) ^ 2)
				w.direct[id] = false
			end
		end
		plan.assign = nil
		if spent >= budget then
			return spent, false
		end
	end

	local members = plan.members
	while plan.nextMember <= #members and spent < budget do
		local id = members[plan.nextMember]
		plan.nextMember += 1
		spent += 1
		if w.slot[id] == nil or w.orderId[id] ~= order.id then
			continue
		end
		local p = nav.profiles[w.defIndex[id]]
		local x, z, gx, gz = w.posX[id], w.posZ[id], w.goalX[id], w.goalZ[id]
		local ux, uz = g:cellAt(x, z)
		local sx, sz = g:cellAt(gx, gz)
		-- Same open leaf (a free square) needs no sampling; otherwise sample.
		local sameLeaf = g:inBounds(ux, uz)
			and g:inBounds(sx, sz)
			and Quadtree.isOpen(t, g:index(ux, uz))
			and Quadtree.leafAt(t, g:index(ux, uz)) == Quadtree.leafAt(t, g:index(sx, sz))
		local direct = sameLeaf
		if not direct then
			spent += math.ceil(math.sqrt((gx - x) ^ 2 + (gz - z) ^ 2) / Nav.LINE_STEP)
			direct = Nav.clearLine(nav, p, x, z, gx, gz)
		end
		if direct then
			w.direct[id] = true
		elseif g:inBounds(ux, uz) then
			-- a unit inside a footprint (driving out of its factory, S-133, or
			-- walking off a new frame, S-155) routes from the open cell it
			-- comes out on: from its own blocked cell the search found
			-- nothing and the order was unreachable for good (S-161: a Mason
			-- given a site behind its plant pushed into the plant for 20 s).
			-- The open cell nearest the unit itself, not nearestOpen's first
			-- find: its +x-first order sent the east player's units out of
			-- the back of their plants and tilted mirror fairness east
			local cell = g:index(ux, uz)
			if not Quadtree.isOpen(t, cell) then
				cell = openNearPoint(t, ux, uz, x, z) or cell
			end
			table.insert(plan.cells, cell)
		end
	end
	if plan.nextMember <= #members then
		return spent, false
	end

	if plan.search == nil then
		if #plan.cells == 0 then
			nav.stats.directOrders += 1
			order.pending = false
			return spent, true
		end
		local key, cached = cachedField(nav, order, plan.cells)
		if cached then
			order.field = cached
			order.pending = false
			nav.stats.cacheHits += 1
			return spent, true
		end
		entry.key = key
		plan.search = Route.newSearch(t, plan.cells, order.goalCell)
		spent += #plan.cells
	end
	local search = plan.search :: Route.Search
	local before = search.workDone
	local done = Route.runSearch(search, math.max(budget - spent, 0))
	spent += search.workDone - before
	if not done then
		return spent, false
	end
	local leaves = Route.searchResult(search)
	if #leaves == 0 then
		if not plan.extend then
			order.unreachable = true -- (an extension that finds nothing leaves the order as it is)
		end
		order.pending = false
		Route.releaseSearch(search)
		return spent, true
	end
	-- corridor (and merge) cost about one unit per 8 cells of the area they
	-- touch: if this tick's budget can't cover it, finish next tick (S-5)
	local old = if plan.extend then order.field else nil
	local area = 0
	if old then
		local c = old.corridor
		area = ((c.maxX - c.minX + 1) * (c.maxZ - c.minZ + 1)) // 4
	end
	if old and spent > 0 and spent + area > budget then
		return spent, false -- the search is done; the next call goes straight here
	end
	local corridor = Route.corridor(t, leaves)
	spent += corridor.cellCount // 8
	if old then
		corridor = Route.mergeCorridors(old.corridor, corridor, g.cellsX)
		spent += corridor.cellCount // 8
	end
	entry.plan = nil
	Route.releaseSearch(search) -- its arrays serve the next search (S-60)
	entry.job = FlowField.newJob(t, corridor, order.goalCell)
	return spent, false
end

-- Rebuilds an order's field so it also covers `cells` (units pushed out of
-- the corridor, or stuck): routes from those cells are merged into the
-- current corridor. Orders that took the direct-path shortcut get their first
-- field this way. Rate-limited per order; ignored while a job is pending.
-- The route search, corridor and field all run as a sliced Pathing job
-- (S-5): Movement only queues it, and units steer straight meanwhile.
function Nav.extendField(nav: Nav, order: Order, cells: { number }, tick: number)
	local field = order.field
	if order.pending or order.unreachable or order.moveClass == "air" or tick - order.lastExtendTick < Nav.EXTEND_COOLDOWN then
		return
	end
	order.lastExtendTick = tick
	local tree = Nav.tree(nav, order.moveClass, order.need)
	local open: { number } = {}
	for _, c in cells do
		if Quadtree.isOpen(tree, c) then
			table.insert(open, c)
		end
	end
	if #open == 0 then
		return
	end
	local _ = field
	order.pending = true
	enqueue(nav, {
		key = FieldCache.key(order.moveClass, order.need, order.goalCell),
		order = order,
		plan = { tree = tree, members = {}, nextMember = 1, cells = open, search = Route.newSearch(tree, open, order.goalCell), extend = true },
	})
end

-- Passability changed inside the cell rectangle (a structure was placed or
-- removed): update each quadtree locally (D86; the rectangle is padded by
-- the clearance cap, the farthest clearance can change) and drop every
-- cached field whose corridor touches the rectangle. Route searches in
-- flight over a changed tree restart. Orders keep their current field;
-- units it now leads into the structure stall and get an extended field
-- (D39).
function Nav.terrainChanged(nav: Nav, x0: number, z0: number, x1: number, z1: number)
	-- each tree applies the change the next time it is used (S-67): a
	-- structure's death used to update every tree in the Damage system's tick
	-- (a backlog past MAX_PENDING changes, e.g. a map's structures placed
	-- at setup, is applied at once, so no single tick pays for it)
	local pad = Passability.CLEARANCE_CAP
	local keys: { string } = {}
	for key in nav.trees do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local rects = nav.dirty[key]
		if rects == nil then
			rects = {}
			nav.dirty[key] = rects
		end
		table.insert(rects, { x0 - pad, z0 - pad, x1 + pad, z1 + pad })
		if #rects > Nav.MAX_PENDING then
			flush(nav, key, nav.trees[key])
		end
	end
	local g = nav.grid
	for z = math.max(z0, 0), math.min(z1, g.cellsZ - 1) do
		for x = math.max(x0, 0), math.min(x1, g.cellsX - 1) do
			FieldCache.invalidateCell(nav.cache, z * g.cellsX + x)
		end
	end
end

-- Pathing system body: advances queued plan and field jobs, oldest first,
-- within `budget` work units.
function Nav.runJobs(nav: Nav, w: World.World, budget: number)
	local idle = nav.jobs[nav.jobHead] == nil
	local left = budget
	while left > 0 and nav.jobs[nav.jobHead] do
		local entry = nav.jobs[nav.jobHead]
		if entry.plan then
			local spent, finished = runPlan(nav, w, entry, left)
			left -= spent
			nav.stats.workUnits += spent
			if finished then
				nav.jobs[nav.jobHead] = nil
				nav.jobHead += 1
			elseif entry.plan and spent == 0 then
				break
			end
			continue
		end
		local job = entry.job :: FlowField.Job
		local before = job.workDone
		local done = FlowField.run(job, left)
		local spent = job.workDone - before
		left -= spent
		nav.stats.workUnits += spent
		if done then
			local field = job.field
			FieldCache.put(nav.cache, entry.key :: string, field)
			entry.order.field = field
			entry.order.pending = false
			nav.stats.fieldsBuilt += 1
			FlowField.release(job) -- its scratch serves the next field (S-60)
			nav.jobs[nav.jobHead] = nil
			nav.jobHead += 1
		elseif spent == 0 then
			break
		end
	end
	-- an idle Pathing tick (no job queued) applies one tree's pending
	-- terrain changes (S-67), so the next order rarely finds any; one, not
	-- all (S-164: five trees' updates and component passes in one idle
	-- tick cost Pathing 10–14 ms)
	if idle and next(nav.dirty) ~= nil then
		local first: string? = nil
		for key in nav.dirty do
			if first == nil or key < first then
				first = key
			end
		end
		flush(nav, first :: string, nav.trees[first :: string])
	end
end

return Nav
