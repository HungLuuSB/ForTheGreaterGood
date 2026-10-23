--!strict
-- "map:canyon", The Canyon (S-132, the user): a hand-made 154 × 256-cell
-- (1232 × 2048-stud) desert map after BAR's "Classic Glitters" (12 × 20).
-- Centre (0, 0), north = +z. Two sides, north (player 1) and south
-- (player 2). Point-symmetric about the centre: every feature and deposit
-- at (x, z) has a twin at (-x, -z), so neither side has better ground.
--
--   mesas      ~36 flat-topped buttes, 48 studs high, traced from the
--              reference heightmap's north half (MESAS, in its pixels) and
--              turned 180° for the south. Terraced cliffs (a ledge partway
--              down) that nothing on land climbs; a low rocky apron round
--              each foot. Their tops are for aircraft and air-built defences.
--   corners    high plateaus with jagged cliff edges in the north-west and
--              south-east corners.
--   badlands   rough ground (ROCK, slower) round the mesa belts: the
--              north-west belt, the south-east belt and every mesa's apron.
--   the canyon the open floor between the belts, running from the north-east
--              to the south-west: hard-packed ground (GRASS, drawn as
--              desert), slightly lower than the belts.
--   boulders   small rock outcrops (1-3 cells, impassable) scattered over
--              the floor.
--   deposits   "glitter": value-2 deposits on a jittered grid every ~20
--              cells over all open ground, plus four value-4 home deposits
--              round each start.
--
-- `Canyon.feature(cx, cz)` names what a cell is (for drawing): "mesa",
-- "cliff", "apron", "badlands", "boulder" or "floor".

local Grid = require("./Grid")
local Layers = require("./Layers")
local TestMap = require("./TestMap")
local Prng = require("../Util/Prng")

local Canyon = {}

Canyon.CELLS_X = 154
Canyon.CELLS_Z = 256
Canyon.MESA_HEIGHT = 48
Canyon.FLOOR = 10
Canyon.BELT_RISE = 3 -- the belts' ground sits this much above the canyon floor
Canyon.STARTS = table.freeze({ { 332, 908 }, { -332, -908 } }) -- cell centres, twins
Canyon.DEPOSIT_SPACING = 160 -- studs between glitter deposits (jittered ±40)
Canyon.DEPOSIT_VALUE = 2
Canyon.HOME_VALUE = 4
Canyon.SEED = 132

-- Mesas of the north half in the reference heightmap's pixels (769 × 1281,
-- 1.6 studs a pixel): { centre x, centre y (down = south), radius x, radius y }.
Canyon.MESAS = table.freeze({
	{ 370, 15, 50, 35 }, { 720, 8, 32, 18 }, { 292, 115, 38, 36 }, { 235, 190, 21, 25 },
	{ 305, 222, 40, 33 }, { 540, 163, 20, 33 }, { 8, 262, 18, 26 }, { 77, 300, 30, 28 },
	{ 242, 308, 56, 38 }, { 178, 433, 22, 20 }, { 256, 427, 31, 33 }, { 8, 468, 16, 26 },
	{ 85, 505, 32, 33 }, { 195, 520, 42, 30 }, { 38, 600, 40, 40 }, { 150, 610, 22, 30 },
	{ 680, 368, 26, 24 }, { 507, 506, 27, 21 },
})

local CELL = Grid.CELL_SIZE
local HALF_X = Canyon.CELLS_X * CELL / 2
local HALF_Z = Canyon.CELLS_Z * CELL / 2
local PX = 1.6
local T = Layers.Terrain
local abs, cos, sin, sqrt, atan2, pi = math.abs, math.cos, math.sin, math.sqrt, math.atan2, math.pi

-- Profile of a cliff by s, the distance (studs) outside the flat top:
-- terraced cliff, then the apron. TOP_IN: how far the top sits inside the
-- traced outline.
local TOP_IN = 18
local LEDGE_FROM, LEDGE_TO, CLIFF_END, APRON_END = 6, 10, 18, 48

type Mesa = { x: number, z: number, rx: number, rz: number, phase: number }

local mesas: { Mesa } = {}
for i, m in Canyon.MESAS do
	local x, z = m[1] * PX - HALF_X, HALF_Z - m[2] * PX
	table.insert(mesas, { x = x, z = z, rx = m[3] * PX, rz = m[4] * PX, phase = i * 1.7 })
	table.insert(mesas, { x = -x, z = -z, rx = m[3] * PX, rz = m[4] * PX, phase = i * 1.7 })
end
Canyon.mesaCount = #mesas

-- Distance (studs, signed) from (x, z) out of mesa m's flat top. Lobes
-- make the outlines irregular; a mesa and its twin share them (turned 180°,
-- which the angle's half-turn keeps: sin(k(θ + π)) = ±sin(kθ) for k = 2, 4).
local function mesaDistance(m: Mesa, x: number, z: number): number
	local dx, dz = x - m.x, z - m.z
	local q = sqrt((dx / m.rx) ^ 2 + (dz / m.rz) ^ 2)
	local a = atan2(dz, dx)
	local lobe = 1 + 0.1 * sin(2 * a + m.phase) + 0.06 * sin(4 * a + 2 * m.phase)
	return (q / lobe - 1) * sqrt(m.rx * m.rz) + TOP_IN
end

-- The north-west corner plateau's signed distance (studs) out of its top,
-- with a zigzag edge; the south-east one is its twin.
local function cornerDistance(x: number, z: number): number
	local ax, az = x + HALF_X, HALF_Z - z -- from the corner, inwards
	local u = ax / 240 + az / 152
	local zig = abs(((atan2(az, ax) * 18 / pi) % 2) - 1) -- 0..1 sawtooth along the edge
	return (u - (1 + 0.16 * zig)) * 128 + TOP_IN
end

-- Signed distance (studs) from the north-west belt's edge: negative inside.
-- The edge runs from (-616, -80) to (152, 1024) with a slow wave.
local function beltDistance(x: number, z: number): number
	local ex, ez = 152 + 616, 1024 + 80
	local len = sqrt(ex * ex + ez * ez)
	local along = ((x + 616) * ex + (z + 80) * ez) / len
	local side = ((x + 616) * ez - (z + 80) * ex) / len -- > 0: south-east of the edge
	return side + 40 * sin(along / 90) -- inside (north-west) is negative
end

local function profile(s: number): number
	local H = Canyon.MESA_HEIGHT
	if s <= 0 then
		return H
	elseif s <= LEDGE_FROM then
		return H - (H * 0.4) * s / LEDGE_FROM
	elseif s <= LEDGE_TO then
		return H * 0.6
	elseif s <= CLIFF_END then
		return H * 0.6 - (H * 0.6 - 5) * (s - LEDGE_TO) / (CLIFF_END - LEDGE_TO)
	elseif s <= APRON_END then
		return 5 * (1 + cos(pi * (s - CLIFF_END) / (APRON_END - CLIFF_END))) / 2
	end
	return 0
end

local function centre(cx: number, cz: number): (number, number)
	return (cx + 0.5) * CELL - HALF_X, (cz + 0.5) * CELL - HALF_Z
end

-- Least distance out of any mesa or corner plateau top.
local function rockDistance(x: number, z: number): number
	local s = math.min(cornerDistance(x, z), cornerDistance(-x, -z))
	for _, m in mesas do
		if abs(x - m.x) < m.rx * 1.3 + APRON_END and abs(z - m.z) < m.rz * 1.3 + APRON_END then
			s = math.min(s, mesaDistance(m, x, z))
		end
	end
	return s
end

-- Ground of the open map: the belts a little above the canyon floor, a
-- gentle undulation (even in (x, z), so it keeps the point symmetry).
local function ground(x: number, z: number): number
	local b = math.min(beltDistance(x, z), beltDistance(-x, -z))
	local rise = Canyon.BELT_RISE * math.clamp(0.5 - b / 160, 0, 1)
	return Canyon.FLOOR + rise + 1.5 * cos(x / 150) * cos(z / 210)
end

local features: { string }? = nil
local heights: { number }? = nil
local boulders: { [number]: boolean } = {}

local function compute()
	local nx, nz = Canyon.CELLS_X, Canyon.CELLS_Z
	-- boulders: seeded, each with its twin, kept off the mesas and starts
	local rng = Prng.new(Canyon.SEED)
	local placed = 0
	while placed < 18 do
		local cx, cz = rng:nextInteger(4, nx - 5), rng:nextInteger(4, nz - 5)
		local x, z = centre(cx, cz)
		local clear = rockDistance(x, z) > APRON_END + 24
		for _, s in Canyon.STARTS do
			if (x - s[1]) ^ 2 + (z - s[2]) ^ 2 < 160 * 160 then
				clear = false
			end
		end
		if clear then
			placed += 1
			local size = rng:nextInteger(1, 3)
			for k = 0, size - 1 do
				local bx, bz = cx + (if k == 1 then 1 else 0), cz + (if k == 2 then 1 else 0)
				boulders[bz * nx + bx] = true
				boulders[(nz - 1 - bz) * nx + (nx - 1 - bx)] = true
			end
		end
	end
	local n = nx * nz
	local f, h = table.create(n), table.create(n)
	for cz = 0, nz - 1 do
		for cx = 0, nx - 1 do
			local i = cz * nx + cx
			if i >= n / 2 then
				-- the twin of an earlier cell: copied, so the halves match exactly
				f[i + 1], h[i + 1] = f[n - i], h[n - i]
				continue
			end
			local x, z = centre(cx, cz)
			local s = rockDistance(x, z)
			local base = ground(x, z)
			local kind
			if s <= 0 then
				kind = "mesa"
			elseif s <= CLIFF_END then
				kind = "cliff"
			elseif s <= APRON_END then
				kind = "apron"
			elseif boulders[i] then
				kind = "boulder"
			elseif math.min(beltDistance(x, z), beltDistance(-x, -z)) < 0 then
				kind = "badlands"
			else
				kind = "floor"
			end
			f[i + 1] = kind
			h[i + 1] = base + profile(s) + (if kind == "boulder" then 7 else 0)
		end
	end
	features, heights = f, h
end

-- What cell (cx, cz) is (see the header).
function Canyon.feature(cx: number, cz: number): string
	if features == nil then
		compute()
	end
	return (features :: { string })[cz * Canyon.CELLS_X + cx + 1]
end

function Canyon.build(): Layers.Layers
	if heights == nil then
		compute()
	end
	local nx, nz = Canyon.CELLS_X, Canyon.CELLS_Z
	local hs = heights :: { number }
	local layers = TestMap.build(nx, nz, function(cx, cz)
		local kind = Canyon.feature(cx, cz)
		return hs[cz * nx + cx + 1], 0, if kind == "floor" then T.GRASS else T.ROCK
	end)
	local g = layers.grid
	local starts = {}
	for _, s in Canyon.STARTS do
		local cx, cz = g:cellAt(s[1], s[2])
		local sx, sz = g:cellCenter(cx, cz)
		table.insert(starts, { sx, sz })
	end
	-- deposits: a cell and its twin, on open ground, 3+ cells from any other
	local function free(cx: number, cz: number): boolean
		if cx < 1 or cz < 1 or cx > nx - 2 or cz > nz - 2 then
			return false
		end
		local kind = Canyon.feature(cx, cz)
		if kind ~= "floor" and kind ~= "badlands" then
			return false
		end
		for dz = -3, 3 do
			for dx = -3, 3 do
				local ax, az = cx + dx, cz + dz
				if ax >= 0 and az >= 0 and ax < nx and az < nz and Layers.getSupply(layers, g:index(ax, az)) > 0 then
					return false
				end
			end
		end
		return true
	end
	local function place(x: number, z: number, value: number): boolean
		local cx0, cz0 = g:cellAt(x, z)
		for r = 0, 3 do
			for dz = -r, r do
				for dx = -r, r do
					if math.max(abs(dx), abs(dz)) == r then
						local cx, cz = cx0 + dx, cz0 + dz
						local mx, mz = nx - 1 - cx, nz - 1 - cz
						if (cx ~= mx or cz ~= mz) and free(cx, cz) and free(mx, mz) then
							Layers.setSupply(layers, g:index(cx, cz), value)
							Layers.setSupply(layers, g:index(mx, mz), value)
							return true
						end
					end
				end
			end
		end
		return false
	end
	local home = starts[1]
	for _, d in { { -40, -40 }, { 40, -40 }, { -40, 40 }, { 40, 40 } } do
		if not place(home[1] + d[1], home[2] + d[2], Canyon.HOME_VALUE) then
			error(`Canyon: no room for a home deposit at ({home[1] + d[1]}, {home[2] + d[2]})`)
		end
	end
	-- glitter: a jittered grid over the north half (z > 0), each with its
	-- twin in the south; none within 120 studs of a start (the home four)
	local rng = Prng.new(Canyon.SEED + 1)
	local S = Canyon.DEPOSIT_SPACING
	for j = 0, math.floor(HALF_Z / S) do
		for i = 0, math.floor(2 * HALF_X / S) do
			local x = -HALF_X + S / 2 + i * S + (if j % 2 == 1 then S / 2 else 0) + rng:nextNumber(-40, 40)
			local z = S / 4 + j * S + rng:nextNumber(-40, 40)
			local nearStart = false
			for _, s in starts do
				if (x - s[1]) ^ 2 + (z - s[2]) ^ 2 < 120 * 120 then
					nearStart = true
				end
			end
			if not nearStart and abs(x) < HALF_X - 8 and abs(z) < HALF_Z - 8 then
				place(x, z, Canyon.DEPOSIT_VALUE)
			end
		end
	end
	for _, s in starts do
		table.insert(layers.starts, s)
	end
	return layers
end

return Canyon
