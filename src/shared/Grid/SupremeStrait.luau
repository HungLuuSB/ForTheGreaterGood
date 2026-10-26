--!strict
-- "map:supreme_strait", Supreme Strait (S-195, the user's G6): a hand-made
-- 320 × 320-cell (2560 × 2560-stud) map for ground, air and naval play,
-- after BAR's "Supreme Strait" (24 × 24; the user's references: its height
-- map, dry texture, 3D view and screenshots). Centre (0, 0), north = +z.
-- Point-symmetric about the centre: every feature, deposit and start at
-- (x, z) has a twin at (-x, -z).
--
--   seas       two bays biting in from opposite corners (the north-west and
--              the south-east), 16 studs deep at most, with a sand beach
--              round them. Between their tips a land corridor (the strait)
--              joins the two halves through the middle.
--   plateaus   the green ground of each half: the south-west (side 1) and
--              the north-east (side 2), about 10 studs above the sea.
--   mountains  rocky high ground (impassable cliffs) in the north-east and
--              south-west corners and along the edges.
--   craters    a ring of rock round a small pond in each plateau.
--   mesas      small flat-topped rock buttes on the plateaus.
--   starts     16 start hints, 1-8 in the south-west half, 9-16 their
--              twins in the north-east; both seas lie between the sides.
--   deposits   three value-3 deposits round every hint, value-2 deposits on
--              a jittered grid over the open ground.
--
-- Shapes are written in the reference image's coordinates: u from the west
-- edge (0) to the east (1), v from the north edge (0) to the south (1), so
-- x = (u - 0.5) × size and z = (0.5 - v) × size. `SupremeStrait.feature`
-- names what a cell is (for drawing): "sea", "beach", "grass", "mountain",
-- "crater", "pond" or "mesa".

local Grid = require("./Grid")
local Layers = require("./Layers")
local Passability = require("./Passability")
local TestMap = require("./TestMap")
local Prng = require("../Util/Prng")

local SupremeStrait = {}

SupremeStrait.CELLS = 320
SupremeStrait.WATER_LEVEL = 8 -- studs (MapGen.WATER_LEVEL)
SupremeStrait.PLATEAU = 18 -- studs: the green ground
SupremeStrait.BEACH = 10 -- studs: the sand at the water's edge
SupremeStrait.MAX_DEPTH = 16 -- studs of water at the seas' deepest
SupremeStrait.SHORE = 0.09 -- of the map's width: the ground rises from the beach over this
SupremeStrait.MOUNTAIN = 52 -- studs: the high ground's top
SupremeStrait.RIM = 30 -- studs: a crater's rim
SupremeStrait.MESA = 30 -- studs: a mesa's top
SupremeStrait.HOME_VALUE = 3
SupremeStrait.FIELD_VALUE = 2
SupremeStrait.FIELD_SPACING = 210 -- studs between field deposits (jittered ±50)
SupremeStrait.HINT_CLEAR = 120 -- studs: no field deposit this near a hint
SupremeStrait.SEED = 195

-- The north-west bay as discs { u, v, radius } (the south-east bay is their twin).
local SEA = {
	{ 0.30, 0.06, 0.20 }, { 0.22, 0.24, 0.17 }, { 0.33, 0.39, 0.13 },
	{ 0.46, 0.10, 0.12 }, { 0.06, 0.31, 0.10 }, { 0.13, 0.29, 0.12 },
}
-- High ground { u, v, radius }: the north-east corner and the edges.
local MOUNTAINS = { { 0.88, 0.03, 0.14 }, { 0.00, 0.12, 0.08 }, { 0.99, 0.37, 0.06 } }
-- Craters { u, v, radius }: a rock rim round a pond.
local CRATERS = { { 0.79, 0.22, 0.06 } }
-- Mesas { u, v, radius }.
local MESAS = { { 0.15, 0.47, 0.045 }, { 0.60, 0.35, 0.035 } }
-- Side 1's hints (the south-west half), north first; side 2's are their twins.
local HINTS = {
	{ 0.08, 0.48 }, { 0.20, 0.58 }, { 0.08, 0.70 }, { 0.32, 0.66 },
	{ 0.30, 0.78 }, { 0.50, 0.70 }, { 0.42, 0.80 }, { 0.30, 0.92 },
}
-- Round a hint: two toward the middle, one behind (studs, in the side's own frame).
local HOME_OFFSETS = { { 44, 32 }, { 44, -32 }, { -46, 0 } }

local T = Layers.Terrain
local CELL = Grid.CELL_SIZE
local SIZE = SupremeStrait.CELLS * CELL

-- Every shape and its twin, in (u, v).
local function withTwins(list: { { number } }): { { number } }
	local out = {}
	for _, s in list do
		table.insert(out, { s[1], s[2], s[3] })
		table.insert(out, { 1 - s[1], 1 - s[2], s[3] })
	end
	return out
end
local SEAS, PEAKS, RIMS, TOPS = withTwins(SEA), withTwins(MOUNTAINS), withTwins(CRATERS), withTwins(MESAS)

-- How far inside a set of discs (u, v) is: > 0 inside (1 at a centre), < 0
-- outside (minus the distance to the nearest edge, in radii).
local function inside(discs: { { number } }, u: number, v: number): number
	local best = -math.huge
	for _, d in discs do
		local k = 1 - math.sqrt((u - d[1]) ^ 2 + (v - d[2]) ^ 2) / d[3]
		if k > best then
			best = k
		end
	end
	return best
end

-- The distance (map widths) from (u, v) to the nearest sea, 0 in it.
local function shoreDistance(u: number, v: number): number
	local best = math.huge
	for _, d in SEAS do
		best = math.min(best, math.sqrt((u - d[1]) ^ 2 + (v - d[2]) ^ 2) - d[3])
	end
	return math.max(best, 0)
end

-- A small wobble for rocky edges, -1..1 (twins match: build() takes each
-- pair's values from one of its cells).
local function wobble(u: number, v: number): number
	return math.sin(u * 47 + v * 13) * math.cos(v * 41 - u * 19)
end

-- (height, water depth, terrain, feature) at (u, v).
local function classify(u: number, v: number): (number, number, number, string)
	local wl = SupremeStrait.WATER_LEVEL
	local sea = inside(SEAS, u, v)
	if sea > 0 then
		local depth = math.min(SupremeStrait.MAX_DEPTH, 2 + sea * 40)
		return wl - depth, depth, T.SAND, "sea"
	end
	local jag = 0.92 + 0.08 * wobble(u, v) ^ 2
	if inside(PEAKS, u, v) > 1 - jag then
		return SupremeStrait.MOUNTAIN, 0, T.ROCK, "mountain"
	end
	local rim = inside(RIMS, u, v)
	if rim > 0.55 then
		return wl - 3, 3, T.SAND, "pond" -- a pond in the crater
	elseif rim > 0 then
		return SupremeStrait.RIM, 0, T.ROCK, "crater"
	end
	if inside(TOPS, u, v) > 1 - jag then
		return SupremeStrait.MESA, 0, T.ROCK, "mesa"
	end
	local shore = shoreDistance(u, v)
	local t = math.clamp(shore / SupremeStrait.SHORE, 0, 1)
	local h = SupremeStrait.BEACH + (SupremeStrait.PLATEAU - SupremeStrait.BEACH) * t * t * (3 - 2 * t)
	if shore < 0.025 then
		return h, 0, T.SAND, "beach"
	end
	return h + 1.5 * math.cos(u * 23) * math.cos(v * 23), 0, T.GRASS, "grass" -- gently rolling
end

local function toUV(x: number, z: number): (number, number)
	return x / SIZE + 0.5, 0.5 - z / SIZE
end

-- What cell (cx, cz) is, for drawing.
function SupremeStrait.feature(cx: number, cz: number): string
	local half = SIZE / 2
	local u, v = toUV((cx + 0.5) * CELL - half, (cz + 0.5) * CELL - half)
	local _, _, _, f = classify(u, v)
	return f
end

function SupremeStrait.build(): Layers.Layers
	local n = SupremeStrait.CELLS
	local half = SIZE / 2
	local layers = TestMap.build(n, n, function(cx, cz)
		-- the twin cell (n-1-cx, n-1-cz) must match exactly: build each from
		-- the cell of the pair whose (cx, cz) comes first
		local tx, tz = n - 1 - cx, n - 1 - cz
		local sx, sz = cx, cz
		if tz < cz or (tz == cz and tx < cx) then
			sx, sz = tx, tz
		end
		local u, v = toUV((sx + 0.5) * CELL - half, (sz + 0.5) * CELL - half)
		local h, water, terrain = classify(u, v)
		return h, water, terrain
	end)
	local g = layers.grid
	-- the hints: side 1 as listed, side 2 their twins, on cell centres
	local starts = {}
	for _, s in HINTS do
		table.insert(starts, { g:cellCenter(g:cellAt((s[1] - 0.5) * SIZE, (0.5 - s[2]) * SIZE)) })
	end
	for i = 1, #HINTS do
		table.insert(starts, { -starts[i][1], -starts[i][2] })
	end
	layers.starts = starts
	-- the ground wheeled units reach from hint 1 (the twin turn gives the same
	-- from hint 9): deposits go only there, never in a pocket walled by rock
	local pm = Passability.build(layers)
	local reached = { [g:index(g:cellAt(starts[1][1], starts[1][2]))] = true }
	local queue, head = { g:index(g:cellAt(starts[1][1], starts[1][2])) }, 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		local cx, cz = i % n, i // n
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ax, az = cx + d[1], cz + d[2]
			if ax >= 0 and ax < n and az >= 0 and az < n then
				local j = g:index(ax, az)
				if not reached[j] and Passability.canEnter(pm, "WHEELED", j) then
					reached[j] = true
					table.insert(queue, j)
				end
			end
		end
	end
	-- deposits: a cell and its twin, on open ground wheeled units reach, 3+
	-- cells from any other deposit and `hintGap` studs from every hint
	local function open(cx: number, cz: number): boolean
		local i = g:index(cx, cz)
		return reached[i] == true and Layers.getTerrain(layers, i) ~= T.ROCK
	end
	local function free(cx: number, cz: number, hintGap: number): boolean
		if cx < 3 or cz < 3 or cx > n - 4 or cz > n - 4 then
			return false
		end
		for dz = -3, 3 do
			for dx = -3, 3 do
				if Layers.getSupply(layers, g:index(cx + dx, cz + dz)) > 0 then
					return false
				end
				if math.abs(dx) <= 1 and math.abs(dz) <= 1 and not open(cx + dx, cz + dz) then
					return false
				end
			end
		end
		local x, z = g:cellCenter(cx, cz)
		for _, s in starts do
			if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < hintGap ^ 2 then
				return false
			end
		end
		return true
	end
	local function place(x: number, z: number, value: number, hintGap: number): boolean
		local cx0, cz0 = g:cellAt(x, z)
		for r = 0, 4 do
			for dz = -r, r do
				for dx = -r, r do
					if math.max(math.abs(dx), math.abs(dz)) == r then
						local cx, cz = cx0 + dx, cz0 + dz
						local tx, tz = n - 1 - cx, n - 1 - cz
						if (tx ~= cx or tz ~= cz) and free(cx, cz, hintGap) and free(tx, tz, hintGap) then
							Layers.setSupply(layers, g:index(cx, cz), value)
							Layers.setSupply(layers, g:index(tx, tz), value)
							return true
						end
					end
				end
			end
		end
		return false
	end
	for i = 1, #HINTS do
		local s = starts[i]
		-- toward the middle: from the hint to the centre
		local d = math.sqrt(s[1] ^ 2 + s[2] ^ 2)
		local fx, fz = -s[1] / d, -s[2] / d
		for _, o in HOME_OFFSETS do
			local x = s[1] + fx * o[1] - fz * o[2]
			local z = s[2] + fz * o[1] + fx * o[2]
			if not place(x, z, SupremeStrait.HOME_VALUE, 5 * CELL) then
				error(`SupremeStrait: no room for a home deposit near hint {i}`)
			end
		end
	end
	-- the fields: side 1's half (x + z < 0, the south-west), jittered; each
	-- placed with its twin in side 2's
	local rng = Prng.new(SupremeStrait.SEED)
	local step = SupremeStrait.FIELD_SPACING
	local x = -half + step / 2
	while x < half do
		local z = -half + step / 2
		while z < half do
			local jx, jz = rng:nextNumber(-50, 50), rng:nextNumber(-50, 50)
			if x + jx + z + jz < -2 * CELL then
				place(x + jx, z + jz, SupremeStrait.FIELD_VALUE, SupremeStrait.HINT_CLEAR)
			end
			z += step
		end
		x += step
	end
	return layers
end

return SupremeStrait
