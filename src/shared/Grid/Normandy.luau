--!strict
-- "map:normandy" (S-53, client request 31; re-oriented in S-54): a hand-made
-- 256 × 256-cell (2048-stud) battle map, centre (0, 0), north = +z. The two
-- armies face each other west (player 1) against east (player 2): the user
-- wants the fight from side to side, not from the sea inland. The coast is
-- a flank both share along the north edge. Mirrored about x = 0, so neither
-- side has better ground.
--
-- North strip, by z (both sides):
--   z > 760          sea: surface 10, ~25 deep (scenery; the beach shelves
--                    into it over 48 studs)
--   640 .. 760       beach (sand), rising gently from 10 to 14
--   560 .. 640       bluffs: a 3-cell cliff up to the plateau (34), too steep
--                    to drive, cut by three draws (6 cells, 48 studs, wide;
--                    a 2-studs-per-cell ramp) at x = -560, 0, 560, with roads
--
-- South of the bluffs (z < 560), by x, mirrored:
--   |x| > 672        each side's rear: open fields (economy, SAMs, silo)
--   |x| ≈ 660        a river, 3 cells (24 studs) wide and 4 deep, north–south;
--                    bridges (5 cells, 40 studs, wide; roads) at z = -700,
--                    -250, 250
--   420 .. 640       each side's staging: open fields
--   |x| < 400        the bocage: fields of 176 studs bounded by hedgerows,
--                    1-cell banks 6 studs high (rock) that stop every land
--                    unit and low direct fire, with 40-stud gaps every 96
--                    studs (24 studs passable: the bank ends are too steep
--                    too); two villages (2 × 2-cell houses, 8 studs high,
--                    rock, 4-cell streets) at (-220, -150) and (220, -150)
--
-- The plateau undulates ±2 studs. Roads (ROAD terrain, 2 cells wide) run
-- east–west over the bridges at z = -700, -250 and 250, and up the draws.
-- Starts: player 1 (-850, 0), player 2 (850, 0).
-- Supply deposits (S-98, next.md item 5; the user's queue task 5), mirrored,
-- each on the nearest field cell to its spot (DEPOSITS):
--   home     four of value 4 round each start, behind its river;
--   rear     a pair of value 3 north and one south of each start, still
--            behind the river;
--   staging  a pair of value 3 in each side's staging fields;
--   bocage   two pairs of value 3 in each half of the bocage, north and
--            south of its village: contested ground;
--   centre   a rich pair of value 6 south of the middle road.
--
-- `Normandy.feature(cx, cz)` names what a cell is (for drawing): "sea",
-- "beach", "bluff", "draw", "hedge", "house", "road", "bridge", "river" or
-- "field".

local Grid = require("./Grid")
local Layers = require("./Layers")
local TestMap = require("./TestMap")

local Normandy = {}

Normandy.CELLS = 256
Normandy.PLATEAU = 34
Normandy.HEDGE_HEIGHT = 6
Normandy.HOUSE_HEIGHT = 8
Normandy.DRAWS = table.freeze({ -560, 0, 560 })
Normandy.RIVER_X = 660 -- both rivers: x = -660 and 660
Normandy.BRIDGES = table.freeze({ -700, -250, 250 }) -- z of the bridges on each river
Normandy.VILLAGES = table.freeze({ { -220, -150 }, { 220, -150 } })
Normandy.STARTS = table.freeze({ { -850, 0 }, { 850, 0 } })
-- Supply deposits (S-98): { x, z, value } of the west half, mirrored to the
-- east; the centre pair is listed whole. Each lands on the nearest field cell.
Normandy.DEPOSITS = table.freeze({
	-- home: round the start
	{ -890, -40, 4 }, { -810, -40, 4 }, { -890, 40, 4 }, { -810, 40, 4 },
	-- rear: behind the river
	{ -836, 380, 3 }, { -812, 380, 3 }, { -836, -420, 3 }, { -812, -420, 3 },
	-- staging fields
	{ -540, -500, 3 }, { -516, -500, 3 },
	-- bocage, north and south of the village
	{ -300, 120, 3 }, { -276, 120, 3 }, { -320, -420, 3 }, { -296, -420, 3 },
})
Normandy.CENTRE_DEPOSITS = table.freeze({ { -16, -520, 6 }, { 16, -520, 6 } })

local CELL = Grid.CELL_SIZE
local HALF = Normandy.CELLS * CELL / 2
local T = Layers.Terrain
local floor, abs, cos = math.floor, math.abs, math.cos

-- Road polylines (world x, z), 2 cells wide; the west half, mirrored below.
local HALF_ROADS = {
	{ { -1000, -700 }, { -400, -700 } },
	{ { -1000, -250 }, { 0, -250 } },
	{ { -1000, 250 }, { 0, 250 } },
	{ { -560, 720 }, { -560, -700 } },
	{ { 0, 720 }, { 0, -250 } },
	{ { -220, 250 }, { -220, -250 } }, -- through the western village
}
local ROADS = {}
for _, line in HALF_ROADS do
	table.insert(ROADS, line)
	local mirror = {}
	for i, p in line do
		mirror[i] = { -p[1], p[2] }
	end
	table.insert(ROADS, mirror)
end

-- The bocage's cell columns: x -400 .. 400; the outermost is a hedge line.
local BOCAGE_FIRST = math.ceil((-400 + HALF) / CELL)

-- Cell (cx, cz) centre in world studs.
local function centre(cx: number, cz: number): (number, number)
	return (cx + 0.5) * CELL - HALF, (cz + 0.5) * CELL - HALF
end

-- Distance from (x, z) to segment a–b.
local function segDist(x: number, z: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
	local px, pz = ax + dx * t - x, az + dz * t - z
	return math.sqrt(px * px + pz * pz)
end

local function roadDist(x: number, z: number): number
	local best = math.huge
	for _, line in ROADS do
		for i = 1, #line - 1 do
			best = math.min(best, segDist(x, z, line[i][1], line[i][2], line[i + 1][1], line[i + 1][2]))
		end
	end
	return best
end

-- Features per cell, computed once.
local features: { string }? = nil

local function compute(): { string }
	local n = Normandy.CELLS
	local out = table.create(n * n)
	for cz = 0, n - 1 do
		for cx = 0, n - 1 do
			local x, z = centre(cx, cz)
			local d = roadDist(x, z)
			local road = d <= CELL -- 2 cells wide
			local nearRoad = d <= CELL * 2.5 -- no banks or houses against a road
			local f = "field"
			if z > 760 then
				f = "sea"
			elseif z > 640 then
				f = if road then "road" else "beach"
			elseif z > 560 then
				local draw = false
				for _, dx in Normandy.DRAWS do
					if abs(x - dx) <= 24 then
						draw = true
					end
				end
				if draw then
					f = if road then "road" else "draw"
				elseif z > 616 then
					f = "bluff"
				elseif road then
					f = "road"
				end
			elseif abs(abs(x) - Normandy.RIVER_X) <= 12 then
				f = "river"
				for _, bz in Normandy.BRIDGES do
					if abs(z - bz) <= 20 then
						f = "bridge"
					end
				end
			elseif road then
				f = "road"
			else
				-- villages: 2 × 2-cell houses every 6 cells, off the roads
				-- (mirrored, like everything south of the bluffs)
				local village = false
				for _, v in Normandy.VILLAGES do
					if v[1] < 0 then
						local vx, vz = -abs(x) - v[1], z - v[2]
						if abs(vx) <= 72 and abs(vz) <= 72 then
							village = true
							local hx, hz = floor((vx + 72) / CELL), floor((vz + 72) / CELL)
							if not nearRoad and hx % 6 < 2 and hz % 6 < 2 then
								f = "house"
							end
						end
					end
				end
				-- hedgerows in the bocage, mirrored about x = 0
				local mx = math.min(cx, n - 1 - cx)
				if mx >= BOCAGE_FIRST and not village and not nearRoad then
					local col = mx - BOCAGE_FIRST -- the outermost column is a hedge line: no loose ends
					local lz = (cz + (if floor(col / 22) % 2 == 0 then 0 else 11)) % 22 == 0
					local lx = col % 22 == 0
					-- 5-cell gaps every 12 cells (96 studs) along a line
					local gapAlongX = (mx + 3) % 12 < 5
					local gapAlongZ = (cz + 3) % 12 < 5
					if (lx and not gapAlongZ) or (lz and not gapAlongX) then
						f = "hedge"
					end
				end
			end
			out[cz * n + cx + 1] = f
		end
	end
	return out
end

-- What cell (cx, cz) is (see the header).
function Normandy.feature(cx: number, cz: number): string
	local f = features
	if f == nil then
		f = compute()
		features = f
	end
	return f[cz * Normandy.CELLS + cx + 1]
end

-- Gentle undulation of the plateau (±2 studs), mirrored about x = 0.
local function undulation(x: number, z: number): number
	return 2 * cos(x / 170) * cos(z / 230)
end

function Normandy.build(): Layers.Layers
	local n = Normandy.CELLS
	local layers = TestMap.build(n, n, function(cx, cz)
		local x, z = centre(cx, cz)
		local f = Normandy.feature(cx, cz)
		local land = Normandy.PLATEAU + undulation(x, z)
		if f == "sea" then
			local h = math.max(-15, 10 - (z - 760) * 25 / 48)
			return h, 10 - h, T.SAND
		elseif z > 640 then
			-- beach: 14 at the foot of the bluffs down to 10 at the water
			return 14 - (z - 640) * 4 / 120, 0, if f == "road" then T.ROAD else T.SAND
		elseif z > 560 then
			if f == "draw" or f == "road" then
				-- the draw: a ramp from the beach (14) to the plateau
				local t = (640 - z) / 80
				return 14 + (land - 14) * t, 0, if f == "road" then T.ROAD else T.GRASS
			elseif f == "bluff" then
				-- the cliff: 3 cells from 14 up to the plateau
				local t = math.clamp((640 - z) / 24, 0, 1)
				return 14 + (land - 14) * t, 0, T.ROCK
			end
			return land, 0, T.GRASS
		elseif f == "river" then
			return land - 4, 4, T.SAND
		elseif f == "hedge" then
			return land + Normandy.HEDGE_HEIGHT, 0, T.ROCK
		elseif f == "house" then
			return land + Normandy.HOUSE_HEIGHT, 0, T.ROCK
		elseif f == "road" or f == "bridge" then
			return land, 0, T.ROAD
		end
		return land, 0, T.GRASS
	end)
	local g = layers.grid
	-- deposits (S-98): each west one on the nearest free field cell to its
	-- spot, and its mirror image exactly opposite (the map stays symmetric)
	local function place(x: number, z: number, value: number)
		local cx0, cz0 = g:cellAt(x, z)
		for r = 0, 6 do
			for dz = -r, r do
				for dx = -r, r do
					if math.max(abs(dx), abs(dz)) == r then
						local cx, cz = cx0 + dx, cz0 + dz
						local mx = n - 1 - cx
						if cx >= 0 and cz >= 0 and cx < n / 2 and cz < n and Normandy.feature(cx, cz) == "field"
							and Layers.getSupply(layers, g:index(cx, cz)) == 0 and Layers.getSupply(layers, g:index(mx, cz)) == 0 then
							Layers.setSupply(layers, g:index(cx, cz), value)
							Layers.setSupply(layers, g:index(mx, cz), value)
							return
						end
					end
				end
			end
		end
		error(`Normandy: no field cell near the deposit at ({x}, {z})`)
	end
	for _, d in Normandy.DEPOSITS do
		place(d[1], d[2], d[3])
	end
	for _, d in Normandy.CENTRE_DEPOSITS do
		if d[1] < 0 then
			place(d[1], d[2], d[3]) -- (its east twin is the other of the pair)
		end
	end
	for _, s in Normandy.STARTS do
		local cx, cz = g:cellAt(s[1], s[2])
		table.insert(layers.starts, { g:cellCenter(cx, cz) })
	end
	return layers
end

return Normandy
