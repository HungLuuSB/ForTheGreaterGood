--!strict
-- Client-side placement check for the build ghost (guide 9.3, 15.6): the
-- server's rules applied to what this client knows. Snapping, the terrain
-- rule and the unit radius come from Shared/Grid/PlacementRules (S-9), the
-- same functions the server uses; occupancy and units in the way use known
-- units only, as the server's planning check (D101) does. The server
-- re-checks when the builder starts the frame. Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local Upgrades = require("./Upgrades")
local World = require("./World")

local Placement = {}


export type Result = {
	ok: boolean,
	reason: string?, -- "out of bounds" | "terrain" | "occupied" | "no deposit" | "units in the way"
	x0: number, -- min-corner cell
	z0: number,
	x: number, -- snapped center (studs)
	z: number,
	replaces: number, -- extractor upgrade: the extractor it replaces, else 0
}

-- Min-corner cell and snapped center (odd footprints center on a cell, even
-- on a corner): the server's own function.
Placement.snap = PlacementRules.snap

-- The client's passability map for its world (built once per map).
local passCache: { [any]: Passability.PassMap } = setmetatable({}, { __mode = "k" }) :: any

local function passMap(world: World.World): Passability.PassMap?
	local layers = world.layers
	if layers == nil then
		return nil
	end
	local pm = passCache[layers]
	if pm == nil then
		pm = Passability.build(layers)
		passCache[layers] = pm
	end
	return pm
end

-- Known structures' footprints: (x0, z0, size, id, def?) per structure.
local function structures(world: World.World): { { any } }
	local out = {}
	for id, u in world.units do
		local def = World.def(world, u)
		if def and def.domain == "structure" then
			local x0, z0 = Placement.snap(world.grid, def.footprint, u.x, u.z)
			table.insert(out, { x0, z0, def.footprint, id, def })
		elseif def == nil and u.flags and bit32.band(u.flags, Schema.StrategicFlag.GHOST) ~= 0 then
			-- a ghost (strategic record): its cell only, its size is unknown
			local cx, cz = world.grid:cellAt(u.x, u.z)
			table.insert(out, { cx, cz, 1, id, nil })
		end
	end
	return out
end

Placement.DEPOSIT_SNAP = 16 -- studs: an extractor ghost this close to a deposit patch's centre jumps onto it

-- Placement help for extractors: a deposit is a 2 x 2 patch (S-184) and
-- an extractor goes centred on it (the T1's footprint 2 exactly over it,
-- the advanced one's 4 around it), so the ghost snaps to the nearest patch
-- centre within DEPOSIT_SNAP of the cursor (PlacementRules.depositNear, the
-- server's and the AI's rule), or (x, z) unchanged. An own extractor this
-- one upgrades (Core/Upgrades) within Upgrades.SNAP wins: the ghost sits on
-- it (C-121).
function Placement.assist(world: World.World, def: any, x: number, z: number): (number, number)
	local layers = world.layers
	if def.extractor == nil or layers == nil then
		return x, z
	end
	local old = Upgrades.nearest(world, def, x, z, Upgrades.SNAP)
	if old then
		return Upgrades.site(world, def, old)
	end
	local px, pz = PlacementRules.depositNear(layers, x, z, Placement.DEPOSIT_SNAP)
	if px == nil or pz == nil then
		return x, z
	end
	return px, pz
end

-- A footprint in cells: its corner cell and size.
export type Footprint = { x0: number, z0: number, size: number }

-- The footprints of builds the player has queued but not started (the
-- BUILD points Core/Waypoints keeps for every own unit), so a new ghost
-- can't overlap one (C-165, the user: two queued ghosts overlapped).
function Placement.planned(world: World.World, byUnit: { [number]: { any } }): { Footprint }
	local out: { Footprint } = {}
	local seen: { [string]: boolean } = {}
	local g = world.grid
	for _, list in byUnit do
		for _, p in list do
			local d = p.defIndex and world.defs.unitByIndex[p.defIndex]
			if d and d.footprint then
				local x0, z0 = Placement.snap(g, d.footprint, p.x, p.z)
				local key = `{x0},{z0},{d.footprint}`
				if not seen[key] then
					seen[key] = true
					table.insert(out, { x0 = x0, z0 = z0, size = d.footprint })
				end
			end
		end
	end
	return out
end

-- `planned` (optional): queued builds' footprints, which count as occupied.
function Placement.check(world: World.World, def: any, x: number, z: number, planned: { Footprint }?): Result
	local g = world.grid
	local size = def.footprint
	local x0, z0, cx, cz = Placement.snap(g, size, x, z)
	local function fail(reason: string): Result
		return { ok = false, reason = reason, x0 = x0, z0 = z0, x = cx, z = cz, replaces = 0 }
	end
	local layers = world.layers
	local pm = passMap(world)
	if layers == nil or pm == nil then
		return fail("out of bounds")
	end
	-- occupant per covered cell, from the known structures
	local occupant: { [number]: { any } } = {}
	for _, s in structures(world) do
		local sx0, sz0, ssize = s[1], s[2], s[3]
		if sx0 < x0 + size and x0 < sx0 + ssize and sz0 < z0 + size and z0 < sz0 + ssize then
			for cz2 = math.max(sz0, z0), math.min(sz0 + ssize, z0 + size) - 1 do
				for cx2 = math.max(sx0, x0), math.min(sx0 + ssize, x0 + size) - 1 do
					occupant[cz2 * g.cellsX + cx2] = s
				end
			end
		end
	end
	for _, f in planned or {} do
		if f.x0 < x0 + size and x0 < f.x0 + f.size and f.z0 < z0 + size and z0 < f.z0 + f.size then
			return fail("occupied") -- a queued build is going there
		end
	end
	-- cell by cell, in the server's order: bounds, occupant, terrain
	local placement = def.placement or "land"
	local replaces = 0
	for cellZ = z0, z0 + size - 1 do
		for cellX = x0, x0 + size - 1 do
			if not g:inBounds(cellX, cellZ) then
				return fail("out of bounds")
			end
			local i = g:index(cellX, cellZ)
			local s = occupant[i]
			if s then
				local id, sdef = s[4], s[5]
				-- an upgrade in place (Core/Upgrades: S-108's upgradesFrom, else D92's rate rule)
				local upgrade = sdef ~= nil and Upgrades.canUpgrade(world, def, world.units[id]) and (replaces == 0 or replaces == id)
				if not upgrade then
					return fail("occupied")
				end
				replaces = id
			end
			if not PlacementRules.terrainOk(pm, i, placement) then
				return fail("terrain")
			end
		end
	end
	if def.extractor and PlacementRules.supplyUnder(layers, size, cx, cz) == 0 then
		return fail("no deposit") -- any covered cell (S-104), the server's own rule
	end
	local minX, minZ = x0 * Grid.CELL_SIZE + g.originX, z0 * Grid.CELL_SIZE + g.originZ
	local maxX, maxZ = minX + size * Grid.CELL_SIZE, minZ + size * Grid.CELL_SIZE
	-- enemy ground units block a frame; own and allied ones walk out of the
	-- footprint when it starts (S-155, C-195)
	for id, u in world.units do
		local udef = World.def(world, u)
		if udef and udef.domain ~= "air" and udef.domain ~= "structure" and id ~= replaces and World.relation(world, u) == "enemy" then
			local r = udef.footprint * PlacementRules.RADIUS_PER_FOOTPRINT
			local px, pz = u.rx or u.x, u.rz or u.z
			if px + r > minX and px - r < maxX and pz + r > minZ and pz - r < maxZ then
				return fail("units in the way")
			end
		end
	end
	return { ok = true, reason = nil, x0 = x0, z0 = z0, x = cx, z = cz, replaces = replaces }
end

-- Extractor spots within `radius` of (cx, cz) that pass the check (free
-- deposits, and own extractors `def` upgrades), each once, nearest to
-- (fromX, fromZ) first and then each next nearest to the last: an extractor
-- drag (BAR's area extractor, C-121). Returns check results.
function Placement.area(world: World.World, def: any, cx: number, cz: number, radius: number, fromX: number, fromZ: number, planned: { Footprint }?): { Result }
	local layers = world.layers
	local spots: { Result } = {}
	if def.extractor == nil or layers == nil then
		return spots
	end
	local seen: { [string]: boolean } = {}
	for _, d in layers.deposits or {} do
		-- every patch (S-184) whose centre is in the circle
		if (d[1] - cx) ^ 2 + (d[2] - cz) ^ 2 <= radius * radius then
			local px, pz = Placement.assist(world, def, d[1], d[2])
			local r = Placement.check(world, def, px, pz, planned)
			local key = `{r.x},{r.z}`
			if r.ok and not seen[key] then
				seen[key] = true
				table.insert(spots, r)
			end
		end
	end
	local out: { Result } = {}
	local x, z = fromX, fromZ
	while #spots > 0 do
		local bi, bd = 1, math.huge
		for i, r in spots do
			local d = (r.x - x) ^ 2 + (r.z - z) ^ 2
			if d < bd then
				bi, bd = i, d
			end
		end
		local r = table.remove(spots, bi) :: Result
		-- spots on neighbouring deposits can share cells: keep the first (C-165)
		local clash = false
		for _, o in out do
			if o.x0 < r.x0 + def.footprint and r.x0 < o.x0 + def.footprint and o.z0 < r.z0 + def.footprint and r.z0 < o.z0 + def.footprint then
				clash = true
				break
			end
		end
		if not clash then
			table.insert(out, r)
			x, z = r.x, r.z
		end
	end
	return out
end

-- Centers for a row of `def` dragged from (x1, z1) to (x2, z2): one per
-- footprint along the drag, snapped (guide 15.6 "drag for rows"). Each
-- spot is one footprint further along the drag's longer axis from the
-- snapped first one (BAR's line), so a longer drag only adds spots: the
-- ones laid never move (H2: they used to spread over the whole drag and
-- jump as it grew, leaving gaps), and a diagonal never overlaps.
function Placement.row(world: World.World, def: any, x1: number, z1: number, x2: number, z2: number): { { number } }
	local step = def.footprint * Grid.CELL_SIZE
	local _, _, sx, sz = Placement.snap(world.grid, def.footprint, x1, z1)
	-- (the slope from the drag itself: the snapped start would tilt it as the drag grows)
	local dx, dz = x2 - x1, z2 - z1
	local major = math.max(math.abs(dx), math.abs(dz))
	local n = math.floor(major / step + 0.5) + 1
	local out = {}
	local seen: { [string]: boolean } = {}
	for i = 0, n - 1 do
		local t = if major < 1e-6 then 0 else i * step / major
		local _, _, cx, cz = Placement.snap(world.grid, def.footprint, sx + dx * t, sz + dz * t)
		local key = `{cx},{cz}`
		if not seen[key] then
			seen[key] = true
			table.insert(out, { cx, cz })
		end
	end
	return out
end

-- Centers for a grid of `def` over the box dragged from (x1, z1) to
-- (x2, z2) (Alt + drag, H4): rows and columns one footprint apart from the
-- snapped first spot, so a bigger box only adds spots, as a row does. Rows
-- run along the box's longer side, in a serpentine, so a builder walks
-- them end to end.
function Placement.grid(world: World.World, def: any, x1: number, z1: number, x2: number, z2: number): { { number } }
	local step = def.footprint * Grid.CELL_SIZE
	local _, _, sx, sz = Placement.snap(world.grid, def.footprint, x1, z1)
	local dx, dz = x2 - x1, z2 - z1
	local nx = math.floor(math.abs(dx) / step + 0.5) + 1
	local nz = math.floor(math.abs(dz) / step + 0.5) + 1
	local ux, uz = if dx < 0 then -step else step, if dz < 0 then -step else step
	local alongX = nx >= nz
	local rows, cols = if alongX then nz else nx, if alongX then nx else nz
	local out = {}
	local seen: { [string]: boolean } = {}
	for r = 0, rows - 1 do
		for k = 0, cols - 1 do
			local c = if r % 2 == 0 then k else cols - 1 - k
			local i, j = if alongX then c else r, if alongX then r else c
			local _, _, cx, cz = Placement.snap(world.grid, def.footprint, sx + ux * i, sz + uz * j)
			local key = `{cx},{cz}`
			if not seen[key] then
				seen[key] = true
				table.insert(out, { cx, cz })
			end
		end
	end
	return out
end

-- A drag's spots: a grid (Alt) or a row.
function Placement.drag(world: World.World, def: any, x1: number, z1: number, x2: number, z2: number, grid: boolean?): { { number } }
	if grid then
		return Placement.grid(world, def, x1, z1, x2, z2)
	end
	return Placement.row(world, def, x1, z1, x2, z2)
end

return Placement
