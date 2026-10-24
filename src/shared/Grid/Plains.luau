--!strict
-- "map:plains", The Plains (S-173, the user): a flat, open 256 × 256-cell
-- (2048 × 2048-stud, the wire's largest) map for 8v8, bigger than The
-- Canyon. Centre (0, 0), north = +z. Mirror-symmetric west ↔ east: every
-- height, road and deposit at (x, z) has a twin at (-x, z).
--
--   ground     grass, gently rolling (a few studs over hundreds of studs:
--              every move class drives everywhere), no water, no cliffs
--   roads      one east–west road through the middle, two north–south ones
--              at x = ±ROAD_X
--   starts     16 start hints (S-171): 1–8 west, 9–16 east, in four groups
--              of four (north-west, south-west, north-east, south-east), so
--              two sides get a half each, four sides a quarter each
--   deposits   three value-3 deposits round every hint (a player spawning
--              there has three to build on), plus value-2 deposits on a
--              jittered grid over the middle and the flanks

local Grid = require("./Grid")
local Layers = require("./Layers")
local TestMap = require("./TestMap")
local Prng = require("../Util/Prng")

local Plains = {}

Plains.CELLS = 256
Plains.BASE = 10 -- studs
Plains.ROAD_X = 520 -- studs: the north–south roads
Plains.ROAD_HALF = 12 -- studs: half a road's width
Plains.HOME_VALUE = 3
Plains.FIELD_VALUE = 2
Plains.FIELD_SPACING = 200 -- studs between field deposits (jittered ±50)
Plains.SEED = 173
Plains.HINT_CLEAR = 120 -- studs: no field deposit this near a hint

-- The west half's hints, north group first; the east's are their mirror.
local WEST = {
	{ -880, 750 }, { -640, 750 }, { -880, 300 }, { -640, 300 }, -- north-west
	{ -880, -300 }, { -640, -300 }, { -880, -750 }, { -640, -750 }, -- south-west
}
-- Round a west hint: two in front (toward the middle) and one behind.
local HOME_OFFSETS = { { 44, 32 }, { 44, -32 }, { -46, 0 } }

local T = Layers.Terrain
local CELL = Grid.CELL_SIZE

local function heightAt(x: number, z: number): number
	-- even in x, so the halves are mirror images
	return Plains.BASE + 2.5 * math.cos(x / 190) * math.cos(z / 230) + 1.5 * math.cos(x / 120) * math.sin(z / 160)
end

local function onRoad(x: number, z: number): boolean
	return math.abs(z) <= Plains.ROAD_HALF or math.abs(math.abs(x) - Plains.ROAD_X) <= Plains.ROAD_HALF
end

function Plains.build(): Layers.Layers
	local n = Plains.CELLS
	local half = n * CELL / 2
	local layers = TestMap.build(n, n, function(cx, cz)
		local x, z = (cx + 0.5) * CELL - half, (cz + 0.5) * CELL - half
		return heightAt(x, z), 0, if onRoad(x, z) then T.ROAD else T.GRASS
	end)
	local g = layers.grid
	-- the hints: west 1-8 as listed, east 9-16 their mirrors, on cell centres
	local starts = {}
	for _, s in WEST do
		table.insert(starts, { g:cellCenter(g:cellAt(s[1], s[2])) })
	end
	for i = 1, #WEST do
		table.insert(starts, { -starts[i][1], starts[i][2] }) -- the mirror of the west cell centre
	end
	layers.starts = starts
	-- deposits: a cell and its mirror twin, 3+ cells from any other deposit
	-- and `hintGap` studs from every hint (5 cells for a home deposit: a
	-- Commander stands there; HINT_CLEAR for the fields, so each hint keeps
	-- exactly its three)
	local function free(cx: number, cz: number, hintGap: number): boolean
		if cx < 2 or cz < 2 or cx > n - 3 or cz > n - 3 then
			return false
		end
		for dz = -3, 3 do
			for dx = -3, 3 do
				if Layers.getSupply(layers, g:index(cx + dx, cz + dz)) > 0 then
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
		for r = 0, 3 do
			for dz = -r, r do
				for dx = -r, r do
					if math.max(math.abs(dx), math.abs(dz)) == r then
						local cx, cz = cx0 + dx, cz0 + dz
						local mx = n - 1 - cx -- the mirror cell
						if mx ~= cx and free(cx, cz, hintGap) and free(mx, cz, hintGap) then
							Layers.setSupply(layers, g:index(cx, cz), value)
							Layers.setSupply(layers, g:index(mx, cz), value)
							return true
						end
					end
				end
			end
		end
		return false
	end
	for _, s in WEST do
		for _, o in HOME_OFFSETS do
			if not place(s[1] + o[1], s[2] + o[2], Plains.HOME_VALUE, 5 * CELL) then
				error(`Plains: no room for a home deposit near ({s[1]}, {s[2]})`)
			end
		end
	end
	-- the fields: the west half's jittered grid (the middle column too), mirrored
	local rng = Prng.new(Plains.SEED)
	local step = Plains.FIELD_SPACING
	local x = -half + step / 2
	while x < 0 do
		local z = -half + step / 2
		while z < half do
			local jx, jz = rng:nextNumber(-50, 50), rng:nextNumber(-50, 50)
			place(math.min(x + jx, -2 * CELL), z + jz, Plains.FIELD_VALUE, Plains.HINT_CLEAR)
			z += step
		end
		x += step
	end
	return layers
end

return Plains
