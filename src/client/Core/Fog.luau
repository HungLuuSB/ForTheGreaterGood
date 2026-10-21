--!strict
-- Fog of war in 3D (guide 11, C-32), from Core/Vision's sight map:
--   * light cells (LIGHT_CELL studs, 2 × 2 sensor cells): how lit each one
--     is, the share of its sensor cells in sight (the light-point fog, after
--     Astra Force's write-up: a darkened scene with a point light per cell);
--   * overlay plates: dark translucent plates over the sensor cells out of
--     sight, laid on the drawn terrain (a plane through the cell's corners,
--     lifted over its highest point), runs of flat cells at one height
--     merged per row. Used when the camera is too far for Roblox to render
--     point lights. Neighbors in a row whose planes nearly match share a
--     plate (raised where a cell is higher, so ground never shows through).
--     Plates are worked out per block of BLOCK × BLOCK sensor
--     cells, so a vision change only rebuilds the blocks it touches.
-- Pure Luau (C-7); Render/FogOfWar draws both.

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Terrain = require("./Terrain")
local Vision = require("./Vision")

local Fog = {}

local SENSOR = Grid.SENSOR_CELL_SIZE
Fog.LIGHT_CELL = 32 -- studs
Fog.BLOCK = 8 -- sensor cells per block side
Fog.LIFT = 0.6 -- studs between a plate and the highest ground under it
Fog.MERGE_SLOPE = 0.03 -- rise per stud: cells this close in slope share a plate
Fog.MERGE_RISE = 0.5 -- studs a merged plate may float over a cell's own plane

-- Light cells per side for a vision map.
function Fog.lightSize(v: Vision.Vision): (number, number)
	local k = Fog.LIGHT_CELL // SENSOR
	return math.ceil(v.width / k), math.ceil(v.depth / k)
end

-- Share (0..1) of light cell (lx, lz)'s sensor cells in sight.
function Fog.lightLevel(v: Vision.Vision, lx: number, lz: number): number
	local k = Fog.LIGHT_CELL // SENSOR
	local seen, total = 0, 0
	for sz = lz * k, math.min(lz * k + k, v.depth) - 1 do
		for sx = lx * k, math.min(lx * k + k, v.width) - 1 do
			total += 1
			if buffer.readu16(v.seen, (sz * v.width + sx) * 2) > 0 then
				seen += 1
			end
		end
	end
	return if total > 0 then seen / total else 0
end

-- Center of light cell (lx, lz) in world studs.
function Fog.lightCenter(v: Vision.Vision, lx: number, lz: number): (number, number)
	return v.originX + (lx + 0.5) * Fog.LIGHT_CELL, v.originZ + (lz + 0.5) * Fog.LIGHT_CELL
end

-- A plate: center (x, z), size (sx, sz) in studs, height y at its center,
-- and slopes (rise per stud along x and along z).
export type Plate = { x: number, z: number, sx: number, sz: number, y: number, slopeX: number, slopeZ: number }

-- The plane of sensor cell (cx, cz): height at its center, slopes, lifted
-- over the drawn ground (water surface included). The ground is bilinear
-- between grid-cell centers, so its highest points over the cell are at
-- those centers (1/4 and 3/4 across) or on the cell's edges: a 5 × 5 grid
-- of samples catches them.
local function cellPlane(v: Vision.Vision, layers: Layers.Layers, cx: number, cz: number): (number, number, number)
	local x0, z0 = v.originX + cx * SENSOR, v.originZ + cz * SENSOR
	local function h(fx: number, fz: number): number
		return Terrain.surfaceY(layers, x0 + fx * SENSOR, z0 + fz * SENSOR)
	end
	local h00, h10, h01, h11 = h(0, 0), h(1, 0), h(0, 1), h(1, 1)
	local center = (h00 + h10 + h01 + h11) / 4
	local slopeX = ((h10 + h11) - (h00 + h01)) / (2 * SENSOR)
	local slopeZ = ((h01 + h11) - (h00 + h10)) / (2 * SENSOR)
	local over = 0
	for i = 0, 4 do
		for j = 0, 4 do
			local fx, fz = i / 4, j / 4
			local plane = center + (fx - 0.5) * SENSOR * slopeX + (fz - 0.5) * SENSOR * slopeZ
			over = math.max(over, h(fx, fz) - plane)
		end
	end
	return center + over + Fog.LIFT, slopeX, slopeZ
end

-- Plates covering the unseen sensor cells of block (bx, bz).
function Fog.blockPlates(v: Vision.Vision, layers: Layers.Layers, bx: number, bz: number): { Plate }
	local out: { Plate } = {}
	local x1 = math.min((bx + 1) * Fog.BLOCK, v.width) - 1
	local z1 = math.min((bz + 1) * Fog.BLOCK, v.depth) - 1
	for cz = bz * Fog.BLOCK, z1 do
		local run: Plate? = nil
		for cx = bx * Fog.BLOCK, x1 do
			if buffer.readu16(v.seen, (cz * v.width + cx) * 2) > 0 then
				run = nil
				continue
			end
			local y, slopeX, slopeZ = cellPlane(v, layers, cx, cz)
			local x = v.originX + (cx + 0.5) * SENSOR
			local z = v.originZ + (cz + 0.5) * SENSOR
			local r = run
			if r then
				-- the run's plane at this cell's center, against the cell's own
				local there = r.y + (x - r.x) * r.slopeX
				local rise = y - there
				if math.abs(slopeX - r.slopeX) <= Fog.MERGE_SLOPE and math.abs(slopeZ - r.slopeZ) <= Fog.MERGE_SLOPE and math.abs(rise) <= Fog.MERGE_RISE then
					-- extend the run east; raise it if this cell sits higher (plus the slope gap over half a cell)
					local gap = (math.abs(slopeX - r.slopeX) + math.abs(slopeZ - r.slopeZ)) * SENSOR / 2
					local lift = math.max(rise + gap, 0)
					r.y += lift + r.slopeX * SENSOR / 2
					r.x += SENSOR / 2
					r.sx += SENSOR
					continue
				end
			end
			local plate: Plate = { x = x, z = z, sx = SENSOR, sz = SENSOR, y = y, slopeX = slopeX, slopeZ = slopeZ }
			table.insert(out, plate)
			run = plate
		end
	end
	return out
end

-- Blocks per side, and the block of a sensor cell index.
function Fog.blocks(v: Vision.Vision): (number, number)
	return math.ceil(v.width / Fog.BLOCK), math.ceil(v.depth / Fog.BLOCK)
end

function Fog.blockOf(v: Vision.Vision, cell: number): (number, number)
	return (cell % v.width) // Fog.BLOCK, (cell // v.width) // Fog.BLOCK
end

return Fog
