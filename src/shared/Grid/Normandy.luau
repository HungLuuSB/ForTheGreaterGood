--!strict
-- "map:normandy" (S-53, client request 31): a hand-made 256 × 256-cell
-- (2048-stud) battle map, centre (0, 0), north = +z. Zones by world z:
--
--   z > 760          sea: surface 10, ~25 deep (scenery; the beach shelves
--                    into it over 48 studs)
--   640 .. 760       beach (sand), rising gently from 10 to 14
--   560 .. 640       bluffs: a 3-cell cliff up to the plateau (34), too steep
--                    to drive, cut by three draws (6 cells, 48 studs, wide;
--                    a 2-studs-per-cell ramp from the beach to the plateau)
--                    at x = -560, 0, 560, each carrying a road
--   -360 .. 560      plateau (grass, ±2 studs of undulation). Open fields at
--                    z 280 .. 560 (Order's staging) and -360 .. -200
--                    (Chaos's); between them the bocage: fields of 176 studs
--                    bounded by hedgerows, 1-cell banks 6 studs high (rock)
--                    that stop every land unit and low direct fire, with
--                    40-stud gaps every 96 studs (24 studs passable: the bank
--                    ends are too steep too); two villages (2 × 2-cell
--                    houses, 8 studs high, rock, 4-cell streets) at the
--                    crossroads (-300, 150) and (400, -100)
--   z ≈ -380         a river, 3 cells (24 studs) wide and 4 deep, east–west;
--                    bridges (5 cells, 40 studs, wide; roads) at x = -500,
--                    100, 650
--   -1024 .. -420    open fields south of the river
--
-- Roads (ROAD terrain, 2 cells wide) run up the draws, through the villages
-- and over the bridges. Starts: player 1 on the beach (0, 700), player 2
-- south of the river (0, -700). No supply deposits.
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
Normandy.BRIDGES = table.freeze({ -500, 100, 650 })
Normandy.VILLAGES = table.freeze({ { -300, 150 }, { 400, -100 } })
Normandy.STARTS = table.freeze({ { 0, 700 }, { 0, -700 } })

local CELL = Grid.CELL_SIZE
local HALF = Normandy.CELLS * CELL / 2
local T = Layers.Terrain
local floor, abs, sin, cos = math.floor, math.abs, math.sin, math.cos

-- The bocage's cell rows: z -200 .. 280 (between the staging fields).
local BOCAGE_FIRST = math.ceil((-200 + HALF) / CELL)
local BOCAGE_LAST = floor((280 + HALF) / CELL) - 1

-- Road polylines (world x, z), 2 cells wide.
local ROADS = {
	{ { -560, 720 }, { -560, 150 } },
	{ { 0, 720 }, { 0, -100 } },
	{ { 560, 720 }, { 560, -100 } },
	{ { -900, 150 }, { 0, 150 } },
	{ { 0, -100 }, { 900, -100 } },
	{ { -300, 150 }, { -300, -250 }, { -500, -320 }, { -500, -1000 } },
	{ { 0, -100 }, { 100, -200 }, { 100, -1000 } },
	{ { 400, -100 }, { 650, -250 }, { 650, -1000 } },
}

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
			local f = "field"
			local road = roadDist(x, z) <= CELL -- 2 cells wide
			local nearRoad = roadDist(x, z) <= CELL * 2.5 -- no banks against a road
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
				f = if draw then (if road then "road" else "draw") elseif z > 616 then "bluff" else "field"
				if f == "field" and road then
					f = "road"
				end
			end
			if z >= -392 and z <= -368 then
				f = "river"
				for _, bx in Normandy.BRIDGES do
					if abs(x - bx) <= 20 then
						f = "bridge"
					end
				end
			elseif z > -1024 and z <= 560 and f == "field" then
				if road then
					f = "road"
				else
					-- villages: 2 × 2-cell houses every 6 cells around the crossroads,
					-- off the roads (4-cell streets between them)
					local village = false
					for _, v in Normandy.VILLAGES do
						local vx, vz = x - v[1], z - v[2]
						if abs(vx) <= 72 and abs(vz) <= 72 then
							village = true
							local hx, hz = floor((vx + 72) / CELL), floor((vz + 72) / CELL)
							if not nearRoad and hx % 6 < 2 and hz % 6 < 2 then
								f = "house"
							end
						end
					end
					-- hedgerows: the bocage between the two open staging fields
					-- (z -340 .. -200 and 280 .. 540); the thin strips beyond
					-- them stay open
					local bocage = cz >= BOCAGE_FIRST and cz <= BOCAGE_LAST
					if bocage and not village and not nearRoad then
						-- field lines every 22 cells (176 studs), offset per band
						local row = cz - BOCAGE_FIRST -- the first row is a hedge line: no loose ends
						local lx = (cx + (if floor(row / 22) % 2 == 0 then 0 else 11)) % 22 == 0
						local lz = row % 22 == 0
						-- 5-cell gaps every 12 cells (96 studs) along a line
						local gapX = (cz + 3) % 12 < 5
						local gapZ = (cx + 3) % 12 < 5
						if (lx and not gapX) or (lz and not gapZ) then
							f = "hedge"
						end
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

-- Gentle undulation of the plateau and the southern fields (±2 studs).
local function undulation(x: number, z: number): number
	return 2 * sin(x / 170) * cos(z / 230)
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
	for _, s in Normandy.STARTS do
		local cx, cz = g:cellAt(s[1], s[2])
		table.insert(layers.starts, { g:cellCenter(cx, cz) })
	end
	return layers
end

return Normandy
