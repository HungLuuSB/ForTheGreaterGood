--!strict
-- Formation slots for group moves (S-12, client request): where each unit
-- of a group order goes. The sim's Nav issues moves with these, and clients
-- draw the same goals (waypoints, line-move previews) with the same
-- functions. Pure: positions come in as arrays by unit ID, and the
-- open-ground test is a callback (the server passes its quadtree's; a client
-- may pass none).
--
-- Order of use: `layout` places the slots, `deepestFirst` sorts them so the
-- far side of the formation fills first, `assign` gives each slot a unit.

local Formation = {}

Formation.SLOT_SPACING = 1.3 -- formation spacing, in unit diameters
Formation.ASSIGN_BUCKET = 32 -- studs; bucket size of `assign`'s search grid

-- Distance between neighboring slots for a group whose largest collision
-- radius is `maxRadius`.
function Formation.spacing(maxRadius: number): number
	return 2 * maxRadius * Formation.SLOT_SPACING
end

-- Lattice offsets sorted by distance from the center (then z, then x): the
-- formation slots around a goal, nearest first. Cached and shared; don't
-- modify the result.
local spiralCache: { { number } } = {}
function Formation.spiral(count: number): { { number } }
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

export type Ground = {
	-- may a unit stand at (x, z)?
	open: (x: number, z: number) -> boolean,
	-- for a line slot that isn't open: the nearest open spot, or nil to drop it
	snap: (x: number, z: number) -> (number?, number?),
}

-- Goal positions for `n` units: a filled spiral around (cx, cz), or, with
-- (lx, lz), evenly spaced along the line from (cx, cz) to (lx, lz), with
-- extra rows stepping back toward (backX, backZ) (the group's centroid) when
-- the line is too short. With `ground`, spiral slots that aren't open are
-- skipped and line slots are snapped (or dropped), so fewer than `n` slots
-- may come back. Without it every slot is kept. Aircraft groups take the
-- spiral around the center even for a line move (the server passes no line
-- and no ground for them).
function Formation.layout(
	n: number,
	spacing: number,
	cx: number,
	cz: number,
	lx: number?,
	lz: number?,
	backX: number,
	backZ: number,
	ground: Ground?
): { { number } }
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
				if ground == nil or ground.open(x, z) then
					table.insert(slots, { x, z })
				else
					local sx, sz = ground.snap(x, z)
					if sx ~= nil and sz ~= nil then
						table.insert(slots, { sx, sz })
					end
				end
				placed += 1
			end
		end
		return slots
	end

	for _, off in Formation.spiral(if ground then n * 4 else n) do
		if #slots >= n then
			break
		end
		local x, z = cx + off[1] * spacing, cz + off[2] * spacing
		if ground == nil or ground.open(x, z) then
			table.insert(slots, { x, z })
		end
	end
	return slots
end

-- Sorts `slots` in place, far side of the formation first (along the
-- approach from the centroid (backX, backZ) to the center (cx, cz)), keeping
-- the layout order within a row: the units that arrive first take the
-- deepest slots, so later arrivals never squeeze past units already
-- standing still.
function Formation.deepestFirst(slots: { { number } }, cx: number, cz: number, backX: number, backZ: number, spacing: number)
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
end

-- Greedy slot assignment: slot by slot (in order), the closest unassigned
-- unit takes it; ties go to the lower ID. `posX` / `posZ` are positions by
-- unit ID. Returns the unit per slot (0 once units run out) and the number
-- of distance checks made. Same result as scanning every unit for every
-- slot, but the units sit in a bucket grid over their bounding box, and each
-- search scans rings of buckets outward from the bucket nearest the slot,
-- stopping once no unscanned bucket can hold a unit as close as the best so
-- far. (For a point p in the box and q the slot clamped into it,
-- |p - slot|² ≥ |p - q|² + |q - slot|², and buckets r + 1 rings out are
-- ≥ r × size from q.)
--
-- Resumable (S-67): `newAssigner` snapshots the members' positions and
-- buckets them; `assignStep` assigns slots until it has made `maxChecks`
-- checks (at least one slot per call), so a big order's assignment can be
-- spread over ticks with exactly the picks of one call (Nav).
export type Assigner = {
	pick: { number }, -- unit per slot so far
	checks: number, -- distance checks made so far
	nextSlot: number,
	slots: { { number } },
	px: { [number]: number }, -- positions at the snapshot
	pz: { [number]: number },
	left: number,
	buckets: { { number } },
	where: { [number]: number },
	rowCount: { number },
	colCount: { number },
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	nbx: number,
	nbz: number,
}

function Formation.newAssigner(posX: { [number]: number }, posZ: { [number]: number }, members: { number }, slots: { { number } }): Assigner
	local B = Formation.ASSIGN_BUCKET
	local px, pz = {}, {}
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, id in members do
		local x, z = posX[id], posZ[id]
		px[id], pz[id] = x, z
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end
	local n = #members
	local nbx, nbz = 1, 1
	if n > 0 then
		nbx, nbz = (maxX - minX) // B + 1, (maxZ - minZ) // B + 1
	end
	local buckets: { { number } } = {}
	for i = 1, nbx * nbz do
		buckets[i] = {}
	end
	local where: { [number]: number } = {} -- unit → bucket index
	-- units left per bucket row and column (S-60): a ring's empty rows and
	-- columns are skipped whole. The buckets that hold units are still all
	-- examined, so picks and `checks` are the same as scanning every bucket
	-- of the ring; with units spread thin (scouts, a long formation) most
	-- of a ring is empty, which made big orders cost milliseconds.
	local rowCount = table.create(nbz, 0)
	local colCount = table.create(nbx, 0)
	for _, id in members do
		local bxi, bzi = (px[id] - minX) // B, (pz[id] - minZ) // B
		local b = bzi * nbx + bxi + 1
		table.insert(buckets[b], id)
		where[id] = b
		rowCount[bzi + 1] += 1
		colCount[bxi + 1] += 1
	end
	return {
		pick = {},
		checks = 0,
		nextSlot = 1,
		slots = slots,
		px = px,
		pz = pz,
		left = n,
		buckets = buckets,
		where = where,
		rowCount = rowCount,
		colCount = colCount,
		minX = minX,
		minZ = minZ,
		maxX = maxX,
		maxZ = maxZ,
		nbx = nbx,
		nbz = nbz,
	}
end

-- Assigns slots until `maxChecks` checks were made by this call (at least
-- one slot); true once every slot has its pick.
function Formation.assignStep(a: Assigner, maxChecks: number): boolean
	local B = Formation.ASSIGN_BUCKET
	local px, pz, buckets, rowCount, colCount = a.px, a.pz, a.buckets, a.rowCount, a.colCount
	local nbx, nbz = a.nbx, a.nbz
	local minX, minZ, maxX, maxZ = a.minX, a.minZ, a.maxX, a.maxZ
	local maxRing = math.max(nbx, nbz)
	local slots, pick = a.slots, a.pick
	local checks = a.checks
	local stopAt = checks + maxChecks
	local sx, sz = 0, 0
	local best, bestD = 0, math.huge
	local function scanBucket(b: number)
		for _, id in buckets[b] do
			local d = (px[id] - sx) ^ 2 + (pz[id] - sz) ^ 2
			checks += 1
			if d < bestD or (d == bestD and id < best) then
				best, bestD = id, d
			end
		end
	end
	local function scanRow(oz: number, xa: number, xb: number)
		if oz < 0 or oz >= nbz or rowCount[oz + 1] == 0 then
			return
		end
		for ox = math.max(xa, 0), math.min(xb, nbx - 1) do
			scanBucket(oz * nbx + ox + 1)
		end
	end
	local function scanCol(ox: number, za: number, zb: number)
		if ox < 0 or ox >= nbx or colCount[ox + 1] == 0 then
			return
		end
		for oz = math.max(za, 0), math.min(zb, nbz - 1) do
			scanBucket(oz * nbx + ox + 1)
		end
	end
	local i = a.nextSlot
	while i <= #slots do
		if i > a.nextSlot and checks >= stopAt then
			break
		end
		if a.left == 0 then
			pick[i] = 0
			i += 1
			continue
		end
		local slot = slots[i]
		sx, sz = slot[1], slot[2]
		local qx, qz = math.clamp(sx, minX, maxX), math.clamp(sz, minZ, maxZ)
		local base = (qx - sx) ^ 2 + (qz - sz) ^ 2
		local bx, bz = (qx - minX) // B, (qz - minZ) // B
		best, bestD = 0, math.huge
		for ring = 0, maxRing do
			-- the ring's perimeter: its top and bottom rows, then the rest of
			-- its left and right columns
			if ring == 0 then
				scanRow(bz, bx, bx)
			else
				scanRow(bz - ring, bx - ring, bx + ring)
				scanRow(bz + ring, bx - ring, bx + ring)
				scanCol(bx - ring, bz - ring + 1, bz + ring - 1)
				scanCol(bx + ring, bz - ring + 1, bz + ring - 1)
			end
			-- anything further out is at least base + (ring × B)² away
			if best ~= 0 and bestD < base + (ring * B) ^ 2 then
				break
			end
		end
		pick[i] = best
		-- take the unit out of its bucket
		local b = a.where[best]
		local list = buckets[b]
		local k = table.find(list, best) :: number
		list[k] = list[#list]
		list[#list] = nil
		rowCount[(b - 1) // nbx + 1] -= 1
		colCount[(b - 1) % nbx + 1] -= 1
		a.left -= 1
		i += 1
	end
	a.nextSlot = i
	a.checks = checks
	return i > #slots
end

function Formation.assign(posX: { [number]: number }, posZ: { [number]: number }, members: { number }, slots: { { number } }): ({ number }, number)
	local a = Formation.newAssigner(posX, posZ, members, slots)
	Formation.assignStep(a, math.huge)
	return a.pick, a.checks
end

return Formation
