--!strict
-- Structure footprints on the grid (guide 9.3): snapping, placement checks,
-- and occupying / releasing cells (which updates passability and Nav).
--
-- A footprint of size F covers F × F cells. Odd footprints are centered on a
-- cell; even ones on a cell corner. Facing doesn't change square footprints
-- (non-square footprints would swap their sides at 90°/270°, guide 9.3).

local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Passability = require("@shared/Grid/Passability")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Lifecycle = require("./Lifecycle")
local Sensors = require("./Sensors")
local Nav = require("./Nav")
local Types = require("./Types")
local World = require("./World")

local Placement = {}

local L = Sensors.Level

-- The snap and terrain rule are shared with clients (Shared/Grid/PlacementRules, S-9).
Placement.LAND_MAX_SLOPE = PlacementRules.LAND_MAX_SLOPE
Placement.WATER_MIN_DEPTH = PlacementRules.WATER_MIN_DEPTH
Placement.snap = PlacementRules.snap

-- Can `def` be placed centered near (x, z)? Returns ok, a reason when not,
-- the snapped min corner and center, and the unit the placement replaces
-- (0 if none). With `owner` (a player), a def with `upgradesFrom` may go
-- onto that player's own complete structure of a listed def (S-108; guide
-- 9.3): the in-place upgrade. Allies' and enemies' structures block it;
-- the old one works on until the new one is finished (Build).
-- `knower` (an ally team) makes it a planning check that uses only that
-- team's knowledge (D101): enemy structures and units it doesn't see don't
-- block, structures it remembers (ghosts, alive or not) do. Without it the
-- check is the physical one, done when a builder starts the frame.
function Placement.check(sim: Types.Sim, def: Defs.UnitDef, x: number, z: number, owner: number?, knower: number?): (boolean, string?, number, number, number, number, number)
	local pm = sim.map
	if pm == nil then
		return false, "no map", 0, 0, x, z, 0
	end
	local g = pm.grid
	local size = def.footprint
	local x0, z0, cx, cz = Placement.snap(g, size, x, z)
	local layers = pm.layers
	local w = sim.world
	local replaces = 0
	local placement = def.placement or "land"
	for cellZ = z0, z0 + size - 1 do
		for cellX = x0, x0 + size - 1 do
			if not g:inBounds(cellX, cellZ) then
				return false, "out of bounds", x0, z0, cx, cz, 0
			end
			local i = g:index(cellX, cellZ)
			local occupant = Passability.occupant(pm, i)
			if occupant ~= 0 and knower ~= nil and w.ally[occupant] ~= knower then
				local level = Sensors.level(sim, knower, occupant)
				if level ~= L.VISIBLE and level ~= L.GHOST then
					occupant = 0 -- the planner doesn't know it is there
				end
			end
			if occupant ~= 0 then
				local od = if w.slot[occupant] then sim.defs.unitByIndex[w.defIndex[occupant]] else nil
				local upgrade = def.upgradesFrom ~= nil
					and owner ~= nil
					and od ~= nil
					and table.find(def.upgradesFrom, od.id) ~= nil
					and w.owner[occupant] == owner
					and w.buildProgress[occupant] >= 1
					and (replaces == 0 or replaces == occupant)
				if not upgrade then
					return false, "occupied", x0, z0, cx, cz, 0
				end
				replaces = occupant
			end
			if not PlacementRules.terrainOk(pm, i, placement) then
				return false, "terrain", x0, z0, cx, cz, 0
			end
		end
	end
	if knower ~= nil then
		-- remembered structures that are gone: the planner believes they stand
		for _, gid in sim.sensors.ghostIds[knower] or {} do
			local ghost = sim.sensors.ghosts[knower][gid]
			if not World.isRef(w, gid, ghost.gen) then
				local gsize = sim.defs.unitByIndex[ghost.defIndex].footprint
				local gx0, gz0 = Placement.snap(g, gsize, ghost.x, ghost.z)
				if gx0 < x0 + size and x0 < gx0 + gsize and gz0 < z0 + size and z0 < gz0 + gsize then
					return false, "occupied", x0, z0, cx, cz, 0
				end
			end
		end
	end
	if def.extractor then
		if PlacementRules.supplyUnder(layers, size, cx, cz) == 0 then -- any covered cell (S-104)
			return false, "no deposit", x0, z0, cx, cz, 0
		end
	end
	-- no ground unit may stand on the footprint, except, when a frame starts
	-- (`owner` without `knower`), the builder's own and allied units: they
	-- walk out (Placement.occupy, S-155, the user). Planning checks (the AI,
	-- with `knower`) still steer round them
	local friendly = if owner ~= nil and knower == nil and sim.players[owner] then sim.players[owner].allyTeam else nil
	local minX, minZ = x0 * Grid.CELL_SIZE + g.originX, z0 * Grid.CELL_SIZE + g.originZ
	local maxX, maxZ = minX + size * Grid.CELL_SIZE, minZ + size * Grid.CELL_SIZE
	for _, id in w.ids do
		local udef = sim.defs.unitByIndex[w.defIndex[id]]
		local hidden = knower ~= nil and w.ally[id] ~= knower and Sensors.level(sim, knower, id) ~= L.VISIBLE
		local ours = friendly ~= nil and w.ally[id] == friendly and udef.domain ~= "structure"
		if udef.domain ~= "air" and id ~= replaces and not hidden and not ours then
			local r = sim.combat.profiles[w.defIndex[id]].radius
			local px, pz = w.posX[id], w.posZ[id]
			if px + r > minX and px - r < maxX and pz + r > minZ and pz - r < maxZ then
				return false, "units in the way", x0, z0, cx, cz, 0
			end
		end
	end
	return true, nil, x0, z0, cx, cz, replaces
end

local function footprintRect(sim: Types.Sim, id: number): (number, number, number)
	local pm = sim.map :: Passability.PassMap
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	local x0, z0 = Placement.snap(pm.grid, def.footprint, sim.world.posX[id], sim.world.posZ[id])
	return x0, z0, def.footprint
end

-- Marks structure `id`'s footprint as occupied (blocking ground movement).
function Placement.occupy(sim: Types.Sim, id: number)
	local pm = sim.map
	if pm == nil then
		return
	end
	local x0, z0, size = footprintRect(sim, id)
	Passability.setOccupied(pm, x0, z0, size, id)
	if sim.nav then
		Nav.terrainChanged(sim.nav, x0, z0, x0 + size - 1, z0 + size - 1)
		Placement.clearUnits(sim, id, x0, z0, size)
	end
end

-- Ground units standing on structure `id`'s new footprint walk straight out
-- of it, on the side they stand (S-155, the user: build over your own
-- units and they move out of the way), through its blocked cells like a
-- unit leaving its factory's pad (BuildState.exiting, Movement; S-133).
function Placement.clearUnits(sim: Types.Sim, id: number, x0: number, z0: number, size: number)
	local w = sim.world
	local g = (sim.map :: Passability.PassMap).grid
	local half = size * Grid.CELL_SIZE / 2
	local cx, cz = (x0 + size / 2) * Grid.CELL_SIZE + g.originX, (z0 + size / 2) * Grid.CELL_SIZE + g.originZ
	local profiles = (sim.nav :: Nav.Nav).profiles
	for _, u in w.ids do
		local p = profiles[w.defIndex[u]]
		if u == id or p == nil or p.air or sim.build.exiting[u] then
			continue
		end
		local dx, dz = w.posX[u] - cx, w.posZ[u] - cz
		if math.abs(dx) < half + p.radius and math.abs(dz) < half + p.radius then
			-- out across the nearer pair of edges, straight away from the centre
			local len = math.sqrt(dx * dx + dz * dz)
			local ux, uz = if len > 1e-6 then dx / len else 1, if len > 1e-6 then dz / len else 0
			local reach = (half + p.radius + Grid.CELL_SIZE) / math.max(math.abs(ux), math.abs(uz))
			sim.build.exiting[u] = { cx, cz, half, cx + ux * reach, cz + uz * reach, id }
		end
	end
end

-- Frees structure `id`'s footprint (destroyed, reclaimed or cancelled).
function Placement.release(sim: Types.Sim, id: number)
	local pm = sim.map
	if pm == nil then
		return
	end
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	if def.domain ~= "structure" then
		return
	end
	local x0, z0, size = footprintRect(sim, id)
	Passability.clearOccupied(pm, x0, z0, size, id)
	if sim.nav then
		Nav.terrainChanged(sim.nav, x0, z0, x0 + size - 1, z0 + size - 1)
	end
end

table.insert(Lifecycle.removalHooks, Placement.release)

return Placement
