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

function Nav.tree(nav: Nav, moveClass: string, need: number, key: string?): Quadtree.Tree
	local k = key or `{moveClass}:{need}`
	local tree = nav.trees[k]
	if tree == nil then
		tree = Quadtree.build(nav.pm, moveClass, need)
		tree.stepCost = Terrain.stepCosts(nav.pm.layers, moveClass) -- S-37
		nav.trees[k] = tree
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
local function nearestOpen(tree: Quadtree.Tree, cell: number, component: number): number?
	local g = tree.grid
	local seen = { [cell] = true }
	local queue, head = { cell }, 1
	while queue[head] and head <= Nav.NEAREST_SEARCH_LIMIT do
		local c = queue[head]
		head += 1
		if Quadtree.isOpen(tree, c) and (component == 0 or Quadtree.component(tree, c) == component) then
			return c
		end
		local cx, cz = g:coords(c)
		for _, d in { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } do
			local nx, nz = cx + d[1], cz + d[2]
			if g:inBounds(nx, nz) then
				local n = g:index(nx, nz)
				if not seen[n] then
					seen[n] = true
					table.insert(queue, n)
				end
			end
		end
	end
	return nil
end
Nav.nearestOpen = nearestOpen

Nav.MAX_COMMAND_UNITS = 200 -- guide 22.3
Formation.spiral(Nav.MAX_COMMAND_UNITS * 4) -- built at load, not in the first order's tick

-- Greedy slot assignment (Shared/Grid/Formation, S-12): slot by slot, the
-- closest unassigned unit; ties go to the lower ID. Returns the unit per
-- slot (0 once units run out) and the number of distance checks made.
Nav.ASSIGN_BUCKET = Formation.ASSIGN_BUCKET
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
		Formation.deepestFirst(slots, cx, cz, backX, backZ, spacing)
		local assigned: { [number]: boolean } = {}
		local pick, checks = Nav.assignSlots(w, members, slots)
		-- issuing shares the tick's pathing budget (Pathing gets what's left)
		nav.issueWork += Nav.ISSUE_UNIT_COST * #members + checks // 4
		for i, slot in slots do
			local best = pick[i]
			if best == 0 then
				break
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
				plan = { tree = tree, members = table.clone(members), nextMember = 1, cells = {}, search = nil },
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
	local spent = 0
	if nav.orders[order.id] == nil then
		order.pending = false
		return 0, true -- every unit left the order: nothing to plan
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
			table.insert(plan.cells, g:index(ux, uz))
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
	local pad = Passability.CLEARANCE_CAP
	local keys: { string } = {}
	for key in nav.trees do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local tree = nav.trees[key]
		if Quadtree.update(tree, nav.pm, x0 - pad, z0 - pad, x1 + pad, z1 + pad) then
			for i = nav.jobHead, nav.jobTail - 1 do
				local plan = nav.jobs[i].plan
				if plan and plan.tree == tree and plan.search then
					plan.search = nil -- its leaf IDs are stale: search again
				end
			end
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
			nav.jobs[nav.jobHead] = nil
			nav.jobHead += 1
		elseif spent == 0 then
			break
		end
	end
end

return Nav
