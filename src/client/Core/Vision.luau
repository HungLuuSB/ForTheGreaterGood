--!strict
-- What the player's team can see, on the server's 16-stud sensor grid: the
-- server's own ally-team sight map (SIGHT_ROWS / SIGHT_CELLS, protocol 10,
-- C-65), allied players' units included. Before C-65 the client stamped it
-- from its own units (C-32); that rebuild is gone. Vision keeps the fog's
-- view of it: `seen` (u16 per cell, 1 / 0), `changed` (cells that flipped in
-- the last update) and `version`. `Vision.spec` checks it against the
-- server's `los` map. Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local World = require("./World")

local Vision = {}

local CELL = Grid.SENSOR_CELL_SIZE

export type Vision = {
	width: number, -- sensor cells
	depth: number,
	originX: number,
	originZ: number,
	seen: buffer, -- u16 per sensor cell: 1 when the team sees it
	version: number, -- bumps when any cell turns seen or unseen
	changed: { number }, -- sensor cells that flipped in the last update
	sightVersion: number, -- the world.sight version last read
}

function Vision.new(grid: Grid.Grid): Vision
	local w, d = grid.sensorX, grid.sensorZ
	return { width = w, depth = d, originX = grid.originX, originZ = grid.originZ, seen = buffer.create(w * d * 2), version = 0, changed = {}, sightVersion = -1 }
end

function Vision.cellOf(v: Vision, x: number, z: number): (number, number)
	local sx = math.clamp(math.floor((x - v.originX) / CELL), 0, v.width - 1)
	local sz = math.clamp(math.floor((z - v.originZ) / CELL), 0, v.depth - 1)
	return sx, sz
end

-- Is the sensor cell containing (x, z) seen?
function Vision.sees(v: Vision, x: number, z: number): boolean
	local sx, sz = Vision.cellOf(v, x, z)
	return buffer.readu16(v.seen, (sz * v.width + sx) * 2) > 0
end

local function set(v: Vision, i: number, on: boolean)
	if (buffer.readu16(v.seen, i * 2) > 0) ~= on then
		buffer.writeu16(v.seen, i * 2, if on then 1 else 0)
		table.insert(v.changed, i)
	end
end

-- Takes in the server's sight records since the last update. Returns true
-- when a cell flipped (`changed` lists them).
function Vision.update(v: Vision, world: World.World): boolean
	table.clear(v.changed)
	local s = world.sight
	if s == nil or s.version == v.sightVersion or s.width ~= v.width or s.depth ~= v.depth then
		return false
	end
	v.sightVersion = s.version
	if s.full then
		for i = 0, v.width * v.depth - 1 do
			set(v, i, buffer.readu8(s.cells, i) == 1)
		end
	else
		for _, i in s.changed do
			set(v, i, buffer.readu8(s.cells, i) == 1)
		end
	end
	s.full = false
	table.clear(s.changed)
	if #v.changed > 0 then
		v.version += 1
		return true
	end
	return false
end

return Vision
