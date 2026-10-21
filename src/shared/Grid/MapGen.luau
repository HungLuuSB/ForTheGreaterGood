--!strict
-- Procedural skirmish maps (guide 5.5, S-15): pure Luau, deterministic, in
-- the same layer format as every other map (Layers: height, water, supply,
-- starts), so the server and the client build the same map from its ID.
--
-- A map is made for a layout:
--   "1v1"   2 starts, mirror (west / east) or rotate2 (180°) symmetry
--   "2v2"   4 starts, mirror4 (west / east and north / south): starts 1, 2
--           are the west pair (team 1), 3, 4 the east pair (team 2)
--   "ffa4"  4 starts, rotate4 (90°) symmetry, one per corner
-- Water: "none", "lakes" (landlocked, no navy) or "sea" (one connected sea
-- that ships reach from the coasts: a northern sea for mirror maps, a
-- central sea otherwise).
--
-- Exact symmetry: every cell belongs to an orbit under the symmetry's
-- transforms; only the orbit's first cell (lowest index) is computed and
-- the others are copies. Features (hills, mountain ridges, lakes, deposits)
-- are drawn once and replicated by the same transforms.
--
-- Fair play (guide 5.5): each start sits on a flat plateau with 4 safe
-- deposits, two expansion pairs toward the middle and rich deposits in the
-- exposed middle. Mountain ridges make chokepoints; every gap is at least
-- 3 cells wide. MapGen.check verifies a candidate (land path between all
-- starts, no gap narrower than 3 cells for footprint-3 units, deposits
-- buildable and reachable, the sea reachable on naval maps); generate
-- draws new features until a candidate passes (deterministically).

local Grid = require("./Grid")
local Layers = require("./Layers")
local Passability = require("./Passability")
local Prng = require("../Util/Prng")

local MapGen = {}

export type Layout = "1v1" | "2v2" | "ffa4"
export type Symmetry = "mirror" | "rotate2" | "mirror4" | "rotate4"
export type Water = "none" | "lakes" | "sea"

export type Options = {
	seed: number,
	cells: number, -- per side (square maps); guide 5.1: 128 for 1v1, 192 for 2v2 / 4 FFA
	layout: Layout,
	symmetry: Symmetry?, -- default: mirror for 1v1 and 2v2 (mirror4), rotate4 for ffa4
	water: Water?, -- default "none"
}

export type Info = {
	layout: Layout,
	symmetry: Symmetry,
	water: Water,
	players: number,
	modes: { string }, -- guide 5.5 tags: "Team", "FFA", "Naval"
	attempts: number, -- candidates drawn until one passed the checks
}

MapGen.WATER_LEVEL = 8 -- studs: the surface of every lake and sea
MapGen.MAX_ATTEMPTS = 60
MapGen.MIN_GAP = 3 -- cells (guide 5.5)
local PLATEAU = 9 -- cells: flat building ground around a start
local CHECK_CLASSES = { "TRACKED", "HEAVY_TRACKED" } -- land classes with footprint-2 and -3 units

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Transforms on continuous cell coordinates (a cell's center is cx + 0.5),
-- for an n-cell square map. They map cell centers to cell centers.
type Transform = (x: number, z: number, n: number) -> (number, number)
local function id(x: number, z: number, _n: number): (number, number)
	return x, z
end
local function mx(x: number, z: number, n: number): (number, number)
	return n - x, z
end
local function mz(x: number, z: number, n: number): (number, number)
	return x, n - z
end
local function r180(x: number, z: number, n: number): (number, number)
	return n - x, n - z
end
local function r90(x: number, z: number, n: number): (number, number)
	return n - z, x
end
local function r270(x: number, z: number, n: number): (number, number)
	return z, n - x
end

-- Transforms per symmetry, in start order (start i = transform i of start 1).
local GROUPS: { [Symmetry]: { Transform } } = {
	mirror = { id, mx },
	rotate2 = { id, r180 },
	mirror4 = { id, mz, mx, r180 }, -- west pair, then east pair
	rotate4 = { id, r90, r180, r270 },
}
MapGen.GROUPS = GROUPS

local DEFAULT_SYMMETRY: { [Layout]: Symmetry } = { ["1v1"] = "mirror", ["2v2"] = "mirror4", ffa4 = "rotate4" }
local ALLOWED: { [Layout]: { [Symmetry]: boolean } } = {
	["1v1"] = { mirror = true, rotate2 = true },
	["2v2"] = { mirror4 = true },
	ffa4 = { rotate4 = true },
}

-- Value noise (as TestMap) in [0, 1].
type Lattice = { values: { number }, width: number, spacing: number }
local OCTAVES = { { spacing = 32, weight = 0.6 }, { spacing = 8, weight = 0.3 }, { spacing = 4, weight = 0.1 } }
local function makeLattice(rng: Prng.Prng, n: number, spacing: number): Lattice
	local width = n // spacing + 2
	local values = table.create(width * width)
	for i = 1, width * width do
		values[i] = rng:nextNumber()
	end
	return { values = values, width = width, spacing = spacing }
end
local function sample(l: Lattice, cx: number, cz: number): number
	local u, v = cx / l.spacing, cz / l.spacing
	local x0, z0 = math.floor(u), math.floor(v)
	local tx, tz = smoothstep(u - x0), smoothstep(v - z0)
	local vals, w = l.values, l.width
	local i = z0 * w + x0 + 1
	local top = vals[i] + (vals[i + 1] - vals[i]) * tx
	local bottom = vals[i + w] + (vals[i + w + 1] - vals[i + w]) * tx
	return top + (bottom - top) * tz
end

-- Features, in cell coordinates, already replicated by the symmetry.
type Hill = { x: number, z: number, r: number, h: number }
type Ridge = { ax: number, az: number, bx: number, bz: number, w: number }
type Lake = { x: number, z: number, r: number }
type Deposit = { x: number, z: number, value: number }

type Plan = {
	n: number,
	symmetry: Symmetry,
	water: Water,
	starts: { { number } }, -- cell coordinates
	hills: { Hill },
	ridges: { Ridge },
	lakes: { Lake },
	deposits: { Deposit },
	lattices: { Lattice },
	seaWiggle: Lattice,
}

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function segmentDist(px: number, pz: number, r: Ridge): number
	local dx, dz = r.bx - r.ax, r.bz - r.az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - r.ax) * dx + (pz - r.az) * dz) / len2, 0, 1) else 0
	return dist(px, pz, r.ax + dx * t, r.az + dz * t)
end

-- Start 1 (cell coordinates) per symmetry and water.
local function firstStart(symmetry: Symmetry, water: Water, n: number): (number, number)
	local h = n / 2
	if symmetry == "mirror" then
		return h - 0.68 * h, h - (if water == "sea" then 0.25 * h else 0) -- near the northern sea
	elseif symmetry == "rotate2" then
		return h - 0.62 * h, h - 0.42 * h
	elseif symmetry == "mirror4" then
		return h - 0.66 * h, h - 0.48 * h
	end
	local corner = if water == "sea" then 0.56 else 0.64 -- closer to the central sea
	return h - corner * h, h - corner * h
end

-- Noise averaged over the symmetry's images: symmetric and continuous
-- (sampling raw noise on the orbit's computed cell would leave seams where
-- the computed region ends).
local function symmetricNoise(plan: Plan, l: Lattice, x: number, z: number): number
	local group = GROUPS[plan.symmetry]
	local sum = 0
	for _, tf in group do
		local tx, tz = tf(x, z, plan.n)
		sum += sample(l, tx, tz)
	end
	return sum / #group
end

-- Signed distance in cells from the sea's shore (> 0 inside the sea), nil
-- for maps without a sea.
local function seaDepthCells(plan: Plan, x: number, z: number): number?
	if plan.water ~= "sea" then
		return nil
	end
	local n = plan.n
	local h = n / 2
	local wig = (symmetricNoise(plan, plan.seaWiggle, x, z) - 0.5) * 12
	if plan.symmetry == "mirror" then
		return 0.36 * h - z + wig -- a sea along the north edge
	end
	return 0.4 * h - dist(x, z, h, h) + wig -- a central sea
end

local function drawPlan(rng: Prng.Prng, n: number, symmetry: Symmetry, water: Water): Plan
	local group = GROUPS[symmetry]
	local function replicate<T>(list: { T }, x: number, z: number, make: (x: number, z: number, k: number) -> T)
		for k, tf in group do
			local tx, tz = tf(x, z, n)
			table.insert(list, make(tx, tz, k))
		end
	end
	local plan: Plan = {
		n = n,
		symmetry = symmetry,
		water = water,
		starts = {},
		hills = {},
		ridges = {},
		lakes = {},
		deposits = {},
		lattices = {},
		seaWiggle = makeLattice(rng, n, 16),
	}
	for i, octave in OCTAVES do
		plan.lattices[i] = makeLattice(rng, n, octave.spacing)
	end
	local h = n / 2
	local sx, sz = firstStart(symmetry, water, n)
	sx, sz = math.floor(sx) + 0.5, math.floor(sz) + 0.5 -- a cell center maps to cell centers
	replicate(plan.starts, sx, sz, function(x, z)
		return { x, z }
	end)

	-- deposits: 4 safe ones on the plateau, two expansion pairs toward the
	-- middle, one rich one in the exposed middle (per start, replicated)
	local function deposit(x: number, z: number, value: number)
		-- keep it on dry ground: walk back toward the start out of the sea
		for _ = 1, n do
			local sea = seaDepthCells(plan, x, z)
			if sea == nil or sea < -7 then
				break
			end
			local dx, dz = sx - x, sz - z
			local l = math.sqrt(dx * dx + dz * dz)
			if l < 1 then
				break
			end
			x, z = x + dx / l, z + dz / l
		end
		replicate(plan.deposits, math.floor(x) + 0.5, math.floor(z) + 0.5, function(tx, tz)
			return { x = tx, z = tz, value = value }
		end)
	end
	for _, d in { { 5, 5 }, { 5, -5 }, { -5, 5 }, { -5, -5 } } do
		deposit(sx + d[1], sz + d[2], 4)
	end
	local tx, tz = h - sx, h - sz
	local len = math.sqrt(tx * tx + tz * tz)
	local ux, uz = tx / len, tz / len
	local px, pz = -uz, ux
	for _, side in { -1, 1 } do
		local along = len * rng:nextNumber(0.26, 0.36)
		local off = side * rng:nextNumber(9, 14)
		local ex, ez = sx + ux * along + px * off, sz + uz * along + pz * off
		deposit(ex, ez, 3)
		deposit(ex + ux * 3, ez + uz * 3, 3)
	end
	-- rich deposits are contested: halfway between this start and the
	-- nearest enemy start (the east twin on 2v2 maps), moved part of the
	-- way toward the middle
	local ex, ez = group[if symmetry == "mirror4" then 3 else 2](sx, sz, n)
	local mxp, mzp = (sx + ex) / 2, (sz + ez) / 2
	local toward = rng:nextNumber(0, 0.35)
	local rx, rz = mxp + (h - mxp) * toward, mzp + (h - mzp) * toward
	if dist(mxp, mzp, h, h) < 1 then -- rotate2: the midpoint is the middle
		local side = rng:nextNumber(4, 10)
		rx, rz = h + px * side, h + pz * side
	end
	deposit(rx, rz, 6)

	local function farFrom(x: number, z: number, fromStarts: number, fromDeposits: number): boolean
		if x < 3 or z < 3 or x > n - 3 or z > n - 3 then
			return false
		end
		for _, s in plan.starts do
			if dist(x, z, s[1], s[2]) < fromStarts then
				return false
			end
		end
		for _, d in plan.deposits do
			if dist(x, z, d.x, d.z) < fromDeposits then
				return false
			end
		end
		local sea = seaDepthCells(plan, x, z)
		return sea == nil or sea < -6
	end

	-- gentle hills (passable for every land class)
	for _ = 1, rng:nextInteger(3, 5) do
		local x, z = rng:nextNumber(0, n), rng:nextNumber(0, n)
		local r, height = rng:nextNumber(12, 20), rng:nextNumber(6, 12)
		replicate(plan.hills, x, z, function(hx, hz)
			return { x = hx, z = hz, r = r, h = height }
		end)
	end
	local function addRidge(ax: number, az: number, bx: number, bz: number, w: number)
		local list: { { number } } = {}
		replicate(list, ax, az, function(x, z)
			return { x, z }
		end)
		local ends: { { number } } = {}
		replicate(ends, bx, bz, function(x, z)
			return { x, z }
		end)
		for k = 1, #list do
			table.insert(plan.ridges, { ax = list[k][1], az = list[k][2], bx = ends[k][1], bz = ends[k][2], w = w })
		end
	end
	-- a pass on each start's way to the middle: two ridge arms across the
	-- approach, leaving a gap of 5-8 passable cells (a ridge blocks its
	-- half-width w plus a one-cell rim on each side)
	local passed = false
	for _ = 1, 20 do
		local w = rng:nextNumber(1.5, 2.5)
		local gap = rng:nextNumber(5, 8) + 2 * (w + 1)
		local along = len * rng:nextNumber(0.52, 0.64)
		local qx, qz = sx + ux * along, sz + uz * along
		local arm = rng:nextNumber(10, 18)
		local ok = true
		local arms = {}
		for _, side in { -1, 1 } do
			local ax, az = qx + side * px * gap / 2, qz + side * pz * gap / 2
			local bx, bz = ax + side * px * arm, az + side * pz * arm
			for t = 0, 1, 0.25 do
				if not farFrom(ax + (bx - ax) * t, az + (bz - az) * t, PLATEAU + 12, 6 + w) then
					ok = false
				end
			end
			table.insert(arms, { ax, az, bx, bz })
		end
		if ok then
			for _, a in arms do
				addRidge(a[1], a[2], a[3], a[4], w)
			end
			passed = true
			break
		end
	end
	-- more mountain ridges elsewhere (more when no pass fit, e.g. on a
	-- central sea): impassable; their gaps are chokepoints too
	for _ = 1, rng:nextInteger(1, 2) + (if passed then 0 else 1) do
		for _ = 1, 20 do
			local ax, az = rng:nextNumber(0, n), rng:nextNumber(0, n)
			local angle = rng:nextNumber(0, 2 * math.pi)
			local l = rng:nextNumber(10, n * 0.22)
			local bx, bz = ax + math.cos(angle) * l, az + math.sin(angle) * l
			local w = rng:nextNumber(1.5, 3)
			if farFrom(ax, az, PLATEAU + 14, 7 + w) and farFrom(bx, bz, PLATEAU + 14, 7 + w) and farFrom((ax + bx) / 2, (az + bz) / 2, PLATEAU + 14, 7 + w) then
				addRidge(ax, az, bx, bz, w)
				break
			end
		end
	end
	-- landlocked lakes
	if water == "lakes" then
		for _ = 1, rng:nextInteger(2, 3) do
			for _ = 1, 20 do
				local x, z, r = rng:nextNumber(0, n), rng:nextNumber(0, n), rng:nextNumber(5, 9)
				if farFrom(x, z, PLATEAU + r + 8, r + 6) then
					replicate(plan.lakes, x, z, function(lx, lz)
						return { x = lx, z = lz, r = r }
					end)
					break
				end
			end
		end
	end
	return plan
end

-- The orbit's first cell (lowest index) of cell (cx, cz): the cell that is
-- computed; the others copy it.
local function canonical(n: number, group: { Transform }, cx: number, cz: number): (number, number, number)
	local rep, rx, rz = math.huge, cx, cz
	for _, tf in group do
		local tx, tz = tf(cx + 0.5, cz + 0.5, n)
		local ix, iz = math.floor(tx), math.floor(tz)
		local idx = iz * n + ix
		if idx < rep then
			rep, rx, rz = idx, ix, iz
		end
	end
	return rep, rx, rz
end

-- Ground height before features (studs) at cell (cx, cz).
local function baseHeight(plan: Plan, cx: number, cz: number): number
	local noise = 0
	for i, octave in OCTAVES do
		noise += octave.weight * symmetricNoise(plan, plan.lattices[i], cx + 0.5, cz + 0.5)
	end
	return 14 + 10 * noise
end

-- Height and water depth for the cell (cx, cz) (the orbit's computed cell).
local function cellTerrain(plan: Plan, cx: number, cz: number): (number, number)
	local x, z = cx + 0.5, cz + 0.5
	local hgt = baseHeight(plan, cx, cz)
	for _, hill in plan.hills do
		local d = dist(x, z, hill.x, hill.z)
		if d < hill.r then
			hgt += hill.h * (1 - smoothstep(d / hill.r))
		end
	end
	local mountain = 0
	for _, r in plan.ridges do
		local d = segmentDist(x, z, r)
		if d < r.w then
			mountain = math.max(mountain, 30 + (r.w - d) * 12)
		end
	end
	hgt += mountain
	-- flat ground: plateaus around starts, pads under deposits
	for _, s in plan.starts do
		local d = dist(x, z, s[1], s[2])
		if d < PLATEAU + 6 then
			local target = baseHeight(plan, math.floor(s[1]), math.floor(s[2]))
			hgt = target + (hgt - target) * smoothstep((d - PLATEAU) / 6)
		end
	end
	for _, dep in plan.deposits do
		local d = dist(x, z, dep.x, dep.z)
		if d < 5 then
			local target = baseHeight(plan, math.floor(dep.x), math.floor(dep.z))
			hgt = target + (hgt - target) * smoothstep((d - 2.5) / 2.5)
		end
	end
	-- water: depth ramps 2 studs per cell from 1 at the shore (ships from
	-- 2.5 cells out, submarines from 5.5); land within 4 cells of the shore
	-- slopes down to a beach every land class can drive onto
	local inside = -math.huge -- cells inside the nearest water body (< 0: outside)
	for _, lake in plan.lakes do
		inside = math.max(inside, lake.r - dist(x, z, lake.x, lake.z))
	end
	local sea = seaDepthCells(plan, x, z)
	if sea then
		inside = math.max(inside, sea)
	end
	local level = MapGen.WATER_LEVEL
	if inside > 0 then
		local depth = math.min(20, 1 + 2 * inside)
		return level - depth, depth
	elseif inside > -4 then
		hgt = level + 0.5 + (hgt - level - 0.5) * smoothstep(-inside / 4)
	end
	return hgt, 0
end

local function buildLayers(plan: Plan): Layers.Layers
	local n = plan.n
	local grid = Grid.new(n, n)
	local layers = Layers.new(grid)
	local group = GROUPS[plan.symmetry]
	for cz = 0, n - 1 do
		for cx = 0, n - 1 do
			-- the orbit's first cell is computed; the rest copy it
			local rep = canonical(n, group, cx, cz)
			local i = cz * n + cx
			if rep == i then
				local h, water = cellTerrain(plan, cx, cz)
				Layers.setHeight(layers, i, h)
				Layers.setWater(layers, i, water)
			else
				Layers.setHeight(layers, i, Layers.getHeight(layers, rep))
				Layers.setWater(layers, i, Layers.getWater(layers, rep))
			end
		end
	end
	for _, d in plan.deposits do
		Layers.setSupply(layers, grid:index(math.floor(d.x), math.floor(d.z)), d.value)
	end
	for _, s in plan.starts do
		table.insert(layers.starts, { grid:cellCenter(math.floor(s[1]), math.floor(s[2])) })
	end
	return layers
end

local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- 4-connected components of the cells with clearance >= need for `mc`.
-- Returns the component per cell (0 = not open) and the component sizes.
function MapGen.components(pm: Passability.PassMap, mc: string, need: number): ({ number }, { number })
	local g = pm.grid
	local clearance = pm.clearance[mc]
	local comp = table.create(g.cellCount, 0)
	local sizes = {}
	local stack = {}
	for start = 0, g.cellCount - 1 do
		if comp[start + 1] == 0 and buffer.readu8(clearance, start) >= need then
			local c = #sizes + 1
			local size = 0
			comp[start + 1] = c
			table.insert(stack, start)
			while #stack > 0 do
				local i = table.remove(stack) :: number
				size += 1
				local cx, cz = i % g.cellsX, i // g.cellsX
				for _, d in NEIGHBORS do
					local nx, nz = cx + d[1], cz + d[2]
					if nx >= 0 and nz >= 0 and nx < g.cellsX and nz < g.cellsZ then
						local j = nz * g.cellsX + nx
						if comp[j + 1] == 0 and buffer.readu8(clearance, j) >= need then
							comp[j + 1] = c
							table.insert(stack, j)
						end
					end
				end
			end
			sizes[c] = size
		end
	end
	return comp, sizes
end

-- Problems with a map (empty when it is playable): every start reaches
-- every other by land for footprint-3 units; no gap narrower than MIN_GAP
-- cells (cells big units can stand on that small units reach are reached by
-- big units too); every deposit is buildable and reachable; on sea maps,
-- ships (footprint 3) reach the coast near at least two starts.
function MapGen.check(layers: Layers.Layers, water: Water): { string }
	local problems = {}
	local pm = Passability.build(layers)
	local g = layers.grid
	local big = Passability.requiredClearance(MapGen.MIN_GAP) -- 2: a 3 × 3 square
	local function startCell(s: { number }): number
		return g:index(g:cellAt(s[1], s[2]))
	end
	for _, mc in CHECK_CLASSES do
		local small = MapGen.components(pm, mc, 1)
		local large = MapGen.components(pm, mc, big)
		local home = large[startCell(layers.starts[1]) + 1]
		for i, s in layers.starts do
			local c = large[startCell(s) + 1]
			if c == 0 or c ~= home then
				table.insert(problems, `{mc}: start {i} has no land path to start 1`)
			end
		end
		-- a gap narrower than MIN_GAP shows as two big-unit areas that only
		-- small units can travel between
		local seen: { [number]: number } = {}
		for i = 1, g.cellCount do
			local c = large[i]
			if c ~= 0 then
				local s = small[i]
				if seen[s] == nil then
					seen[s] = c
				elseif seen[s] ~= c then
					local cx, cz = g:coords(i - 1)
					table.insert(problems, `{mc}: a gap narrower than {MapGen.MIN_GAP} cells (near cell {cx}, {cz})`)
					break
				end
			end
		end
		for i = 0, g.cellCount - 1 do
			if Layers.getSupply(layers, i) > 0 and large[i + 1] ~= home then
				local cx, cz = g:coords(i)
				table.insert(problems, `{mc}: deposit at cell ({cx}, {cz}) isn't buildable or reachable`)
			end
		end
	end
	if water == "sea" then
		local ships, sizes = MapGen.components(pm, "SHIP", big)
		local largest, best = 0, 0
		for c, size in sizes do
			if size > best then
				largest, best = c, size
			end
		end
		local coastal = 0
		for _, s in layers.starts do
			local sx, sz = g:cellAt(s[1], s[2])
			local near = false
			for dz = -48, 48, 2 do
				for dx = -48, 48, 2 do
					local cx, cz = sx + dx, sz + dz
					if not near and g:inBounds(cx, cz) and ships[g:index(cx, cz) + 1] == largest and dx * dx + dz * dz <= 48 * 48 then
						near = true
					end
				end
			end
			if near then
				coastal += 1
			end
		end
		if best < 400 then
			table.insert(problems, `SHIP: the sea is too small ({best} cells)`)
		end
		if coastal < 2 then
			table.insert(problems, `SHIP: the sea is within 48 cells of only {coastal} start(s)`)
		end
	end
	return problems
end

local winning: { [string]: number } = {} -- options key → attempt that passed

-- Layers for `options` and their Info. Deterministic: the same options
-- always give byte-identical layers. Errors if no candidate passes the
-- checks within MAX_ATTEMPTS.
function MapGen.generate(options: Options): (Layers.Layers, Info)
	local n, layout = options.cells, options.layout
	local symmetry = options.symmetry or DEFAULT_SYMMETRY[layout]
	local water = options.water or "none"
	if ALLOWED[layout] == nil or not ALLOWED[layout][symmetry] then
		error(`MapGen: layout {layout} can't use symmetry {symmetry}`, 2)
	end
	if n < 64 or n > Grid.MAX_CELLS or n % 2 ~= 0 then
		error(`MapGen: cells must be even, 64..{Grid.MAX_CELLS}, got {n}`, 2)
	end
	local key = `{options.seed}:{n}:{layout}:{symmetry}:{water}`
	local known = winning[key]
	local info: Info = {
		layout = layout,
		symmetry = symmetry,
		water = water,
		players = #GROUPS[symmetry],
		modes = if layout == "ffa4" then { "FFA" } elseif layout == "2v2" then { "Team" } else { "Team", "FFA" },
		attempts = 0,
	}
	if water == "sea" then
		table.insert(info.modes, "Naval")
	end
	local rng = Prng.new(options.seed)
	local last = {}
	for attempt = 1, MapGen.MAX_ATTEMPTS do
		local plan = drawPlan(rng, n, symmetry, water)
		if known == nil or attempt == known then
			local layers = buildLayers(plan)
			local problems = if known then {} else MapGen.check(layers, water)
			if #problems == 0 then
				winning[key] = attempt
				info.attempts = attempt
				return layers, info
			end
			last = problems
		end
	end
	error(`MapGen: no playable map for {key} in {MapGen.MAX_ATTEMPTS} attempts (last: {last[1]})`, 2)
end

return MapGen
