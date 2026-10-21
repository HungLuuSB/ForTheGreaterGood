--!strict
-- What the player's team can see (C-32), on the server's 16-stud sensor
-- grid with the server's rule (Sim/Sensors, guide 11.2): a unit sees every
-- sensor cell whose offset (dx, dz) from its own cell has dx² + dz² ≤
-- (sight / 16)²; unfinished structures see nothing. No terrain blocks
-- sight. The wire doesn't carry the team's sight map, so the client stamps
-- it from its own units (allied players' units aren't known as allies yet).
-- Own units outside the camera are strategic records (3 Hz, cell centers,
-- an icon instead of a def): their def is remembered from when they were
-- last tactical, else the icon's sample def stands in. A unit that drops
-- out of the world without dying (a LEAVE before the next strategic
-- snapshot arrives) keeps its sight for HOLD_TICKS.
-- `Vision.spec` checks it against the server's `los` map. Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Icons = require("./Icons")
local World = require("./World")

local Vision = {}

local CELL = Grid.SENSOR_CELL_SIZE
Vision.HOLD_TICKS = 8

export type Vision = {
	width: number, -- sensor cells
	depth: number,
	originX: number,
	originZ: number,
	seen: buffer, -- u16 per sensor cell: how many own units see it
	version: number, -- bumps when any cell turns seen or unseen
	changed: { number }, -- sensor cells that flipped in the last update
	key: string, -- emitters' cells and radii at the last update (skip unchanged updates)
	lastDef: { [number]: number }, -- own unit → def index from when it was last tactical
	icons: Icons.Table?,
	held: { [number]: { e: { number }, tick: number } }, -- own unit → its last emitter and when it was seen
}

function Vision.new(grid: Grid.Grid): Vision
	local w, d = grid.sensorX, grid.sensorZ
	return { width = w, depth = d, originX = grid.originX, originZ = grid.originZ, seen = buffer.create(w * d * 2), version = 0, changed = {}, key = "", lastDef = {}, icons = nil, held = {} }
end

-- Row half-widths of the server's circle for `radius` studs.
local spansCache: { [number]: { R: number, half: { number } } } = {}
local function spans(radius: number): { R: number, half: { number } }
	local sp = spansCache[radius]
	if sp then
		return sp
	end
	local R = math.floor(radius / CELL)
	local r2 = (radius / CELL) ^ 2
	local half = {}
	for dz = -R, R do
		local h = -1
		for dx = 0, R do
			if dx * dx + dz * dz <= r2 then
				h = dx
			end
		end
		half[dz + R + 1] = h
	end
	sp = { R = R, half = half }
	spansCache[radius] = sp
	return sp
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

-- Restamps from the own units' sensor cells (their latest known positions).
-- Returns true when a cell flipped (`changed` lists them).
function Vision.update(v: Vision, world: World.World): boolean
	local emitters = {}
	local present: { [number]: boolean } = {}
	v.icons = v.icons or Icons.table(world.defs)
	for id, u in world.units do
		if u.team ~= world.me.team then
			continue
		end
		if u.build ~= nil and u.build < 1 then
			continue -- unfinished structures don't see (server rule)
		end
		local def
		if u.defIndex then
			v.lastDef[id] = u.defIndex
			def = World.def(world, u)
		elseif v.lastDef[id] then
			def = world.defs.unitByIndex[v.lastDef[id]]
		elseif u.icon and u.icon > 0 then
			def = (v.icons :: Icons.Table).sample[u.icon]
		end
		local sight = def and def.sensors and def.sensors.sight or 0
		if sight > 0 then
			local sx, sz = Vision.cellOf(v, u.x, u.z)
			local e = { sx, sz, sight }
			table.insert(emitters, e)
			v.held[id] = { e = e, tick = world.latestTick }
			present[id] = true
		end
	end
	for _, d in world.died do
		v.held[d.id] = nil
	end
	for id, h in v.held do
		if not present[id] then
			if world.latestTick - h.tick <= Vision.HOLD_TICKS and world.units[id] == nil then
				table.insert(emitters, h.e)
			else
				v.held[id] = nil
			end
		end
	end
	table.sort(emitters, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		elseif a[2] ~= b[2] then
			return a[2] < b[2]
		end
		return a[3] < b[3]
	end)
	local parts = table.create(#emitters)
	for i, e in emitters do
		parts[i] = `{e[1]},{e[2]},{e[3]}`
	end
	local key = table.concat(parts, ";")
	table.clear(v.changed)
	if key == v.key then
		return false
	end
	v.key = key
	local w, d = v.width, v.depth
	local fresh = buffer.create(w * d * 2)
	for _, e in emitters do
		local sp = spans(e[3])
		local R, half = sp.R, sp.half
		for dz = -R, R do
			local z = e[2] + dz
			local h = half[dz + R + 1]
			if z < 0 or z >= d or h < 0 then
				continue
			end
			for x = math.max(e[1] - h, 0), math.min(e[1] + h, w - 1) do
				local o = (z * w + x) * 2
				buffer.writeu16(fresh, o, buffer.readu16(fresh, o) + 1)
			end
		end
	end
	local old = v.seen
	for i = 0, w * d - 1 do
		if (buffer.readu16(old, i * 2) > 0) ~= (buffer.readu16(fresh, i * 2) > 0) then
			table.insert(v.changed, i)
		end
	end
	v.seen = fresh
	if #v.changed > 0 then
		v.version += 1
		return true
	end
	return false
end

return Vision
