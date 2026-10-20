--!strict
-- Navigation state shared by the Commands, Pathing and Movement systems
-- (guide 6.3–6.6): per-def movement profiles, lazily built quadtrees, the
-- flow field cache and job queue, and move orders.
--
-- A move order covers the units of one (move class, clearance need) group.
-- The group shares one flow field to the group goal; each unit also gets its
-- own goal (a formation slot, or a point on the line for line moves) and
-- steers straight to it once the line there is clear.

local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")
local FieldCache = require("./Path/FieldCache")
local FlowField = require("./Path/FlowField")
local Quadtree = require("./Path/Quadtree")
local Route = require("./Path/Route")
local World = require("./World")

local Nav = {}

Nav.ARRIVE_RADIUS = 1.5 -- studs: a unit this close to its own goal has arrived
Nav.DIRECT_RANGE = 96 -- studs: line-of-sight checks for direct steering only this close
Nav.LINE_STEP = 2 -- studs between line-of-sight samples
Nav.SLOT_SPACING = 1.3 -- formation spacing, in unit diameters
Nav.RADIUS_PER_FOOTPRINT = 8 * 0.45 -- collision radius per footprint cell (studs)
Nav.PATHING_BUDGET = 12000 -- flow field work units per tick (DECISIONS D33)
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

type JobEntry = { key: string, order: Order, job: FlowField.Job }

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
	stats: { fieldsBuilt: number, cacheHits: number, workUnits: number },
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
			treeKey = `{def.moveClass}:{Passability.requiredClearance(def.footprint)}`,
		}
	end
	return {
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
		stats = { fieldsBuilt = 0, cacheHits = 0, workUnits = 0 },
	}
end

function Nav.tree(nav: Nav, moveClass: string, need: number, key: string?): Quadtree.Tree
	local k = key or `{moveClass}:{need}`
	local tree = nav.trees[k]
	if tree == nil then
		tree = Quadtree.build(nav.pm, moveClass, need)
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

-- Lattice offsets sorted by distance from the center (then z, then x):
-- the formation slots around a goal, nearest first.
local spiralCache: { { number } } = {}
local function spiral(count: number): { { number } }
	if #spiralCache < count then
		local k = math.ceil(math.sqrt(count)) + 1
		local pts = {}
		for j = -k, k do
			for i = -k, k do
				table.insert(pts, { i, j })
			end
		end
		table.sort(pts, function(a, b)
			local da, db = a[1] * a[1] + a[2] * a[2], b[1] * b[1] + b[2] * b[2]
			if da ~= db then
				return da < db
			end
			if a[2] ~= b[2] then
				return a[2] < b[2]
			end
			return a[1] < b[1]
		end)
		spiralCache = pts
	end
	return spiralCache
end

-- Candidate goal positions for `n` units: a formation around (cx, cz), or
-- evenly spaced along the line to (lx, lz) (extra rows step back toward
-- `back` when the line is too short). Only positions on open cells of the
-- group's component are kept.
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
	local function ok(x: number, z: number): boolean
		local gx, gz = g:cellAt(x, z)
		if not g:inBounds(gx, gz) then
			return false
		end
		local c = g:index(gx, gz)
		return Quadtree.isOpen(tree, c) and Quadtree.component(tree, c) == component
	end

	local slots: { { number } } = {}
	if lx ~= nil and lz ~= nil then
		local dx, dz = lx - cx, lz - cz
		local len = math.sqrt(dx * dx + dz * dz)
		local perRow = math.max(1, math.min(n, math.floor(len / spacing) + 1))
		local rows = math.ceil(n / perRow)
		-- unit vector from the line toward `back`, perpendicular to the line
		local ux, uz = if len > 0 then dx / len else 1, if len > 0 then dz / len else 0
		local px, pz = -uz, ux
		local mx, mz = (cx + lx) / 2, (cz + lz) / 2
		if (backX - mx) * px + (backZ - mz) * pz < 0 then
			px, pz = -px, -pz
		end
		local placed = 0
		for row = 0, rows - 1 do
			for i = 0, perRow - 1 do
				if placed >= n then
					break
				end
				local t = if perRow == 1 then 0.5 else i / (perRow - 1)
				local x = cx + dx * t + px * spacing * row
				local z = cz + dz * t + pz * spacing * row
				if ok(x, z) then
					table.insert(slots, { x, z })
				else
					-- snap to the nearest open cell center
					local gx, gz = g:cellAt(x, z)
					gx, gz = math.clamp(gx, 0, g.cellsX - 1), math.clamp(gz, 0, g.cellsZ - 1)
					local snapped = nearestOpen(tree, g:index(gx, gz), component)
					if snapped then
						local sx, sz = g:coords(snapped)
						table.insert(slots, { g:cellCenter(sx, sz) })
					end
				end
				placed += 1
			end
		end
		return slots
	end

	for _, off in spiral(n * 4) do
		if #slots >= n then
			break
		end
		local x, z = cx + off[1] * spacing, cz + off[2] * spacing
		if ok(x, z) then
			table.insert(slots, { x, z })
		end
	end
	return slots
end

-- Appends to the job FIFO. (table.insert would misplace entries once the
-- consumed head slots are nil.)
local function enqueue(nav: Nav, entry: JobEntry)
	nav.jobs[nav.jobTail] = entry
	nav.jobTail += 1
end

-- Queues (or reuses) the shared field for an order covering `cells`.
local function requestField(nav: Nav, order: Order, tree: Quadtree.Tree, cells: { number })
	local key = FieldCache.key(order.moveClass, order.need, order.goalCell)
	local cached = FieldCache.get(nav.cache, key)
	if cached then
		local coversAll = true
		for _, c in cells do
			if not Route.inCorridor(cached.corridor, c) then
				coversAll = false
				break
			end
		end
		if coversAll then
			order.field = cached
			nav.stats.cacheHits += 1
			return
		end
	end
	local leaves = Route.findMany(tree, cells, order.goalCell)
	if #leaves == 0 then
		order.unreachable = true
		return
	end
	local corridor = Route.corridor(tree, leaves)
	order.pending = true
	enqueue(nav, { key = key, order = order, job = FlowField.newJob(tree, corridor, order.goalCell) })
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
		local spacing = 2 * maxRadius * Nav.SLOT_SPACING

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
			slots = {}
			for _, off in spiral(#members) do
				if #slots >= #members then
					break
				end
				table.insert(slots, { cx + off[1] * spacing, cz + off[2] * spacing })
			end
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

		-- Greedy assignment, far side of the formation first (along the
		-- approach direction from the group's centroid): the units that
		-- arrive first take the deepest slots, so later arrivals never have to
		-- squeeze past units already standing still. Each slot takes the
		-- closest unassigned unit; ties go to the lower ID.
		local ax, az = cx - backX, cz - backZ
		local alen = math.sqrt(ax * ax + az * az)
		if alen > 1e-9 then
			ax, az = ax / alen, az / alen
		end
		local depth: { [{ number }]: number } = {}
		local rank: { [{ number }]: number } = {}
		for i, slot in slots do
			depth[slot] = math.floor(((slot[1] - cx) * ax + (slot[2] - cz) * az) / spacing + 0.5)
			rank[slot] = i
		end
		table.sort(slots, function(a, b)
			if depth[a] ~= depth[b] then
				return depth[a] > depth[b]
			end
			return rank[a] < rank[b]
		end)
		local assigned: { [number]: boolean } = {}
		for _, slot in slots do
			local best, bestD = nil, math.huge
			for _, id in members do
				if not assigned[id] then
					local d = (w.posX[id] - slot[1]) ^ 2 + (w.posZ[id] - slot[2]) ^ 2
					if d < bestD then
						best, bestD = id, d
					end
				end
			end
			if best == nil then
				break
			end
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
			local cells = {}
			for _, id in members do
				local ux, uz = g:cellAt(w.posX[id], w.posZ[id])
				if g:inBounds(ux, uz) then
					table.insert(cells, g:index(ux, uz))
				end
			end
			requestField(nav, order, tree, cells)
		end
	end
end

-- Rebuilds an order's field so it also covers `cells` (units pushed out of
-- the corridor, or stuck): routes from those cells are merged into the
-- current corridor. Rate-limited per order; ignored while a job is pending.
function Nav.extendField(nav: Nav, order: Order, cells: { number }, tick: number)
	local field = order.field
	if order.pending or field == nil or order.unreachable or tick - order.lastExtendTick < Nav.EXTEND_COOLDOWN then
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
	local leaves = Route.findMany(tree, open, order.goalCell)
	if #leaves == 0 then
		return
	end
	local corridor = Route.mergeCorridors(field.corridor, Route.corridor(tree, leaves))
	order.pending = true
	local key = FieldCache.key(order.moveClass, order.need, order.goalCell)
	enqueue(nav, { key = key, order = order, job = FlowField.newJob(tree, corridor, order.goalCell) })
end

-- Pathing system body: advances queued field jobs, oldest first, within
-- `budget` work units.
function Nav.runJobs(nav: Nav, budget: number)
	local left = budget
	while left > 0 and nav.jobs[nav.jobHead] do
		local entry = nav.jobs[nav.jobHead]
		local before = entry.job.workDone
		local done = FlowField.run(entry.job, left)
		local spent = entry.job.workDone - before
		left -= spent
		nav.stats.workUnits += spent
		if done then
			local field = entry.job.field
			FieldCache.put(nav.cache, entry.key, field)
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
