--!strict
local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")
local Combat = require("../Sim/Combat/Combat")
local Nav = require("../Sim/Nav")
local Placement = require("../Sim/Placement")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Prng = require("@shared/Util/Prng")
local Quadtree = require("../Sim/Path/Quadtree")
local Route = require("../Sim/Path/Route")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CLASSES = { "WHEELED", "TRACKED", "HEAVY_TRACKED", "HOVER", "AMPHIB", "SHIP", "SUB", "HELI", "JET" }

-- A tree's structure without leaf IDs: leaves as "x,z,size,open", the
-- neighbor set of each open leaf, and the component of each open leaf.
type Canon = { leaves: { string }, neighbors: { [string]: string }, comp: { [string]: number }, count: number }
local function canon(tree: Quadtree.Tree): (Canon?, string?)
	local key: { [number]: string } = {}
	local c: Canon = { leaves = {}, neighbors = {}, comp = {}, count = tree.componentCount }
	local g = tree.grid
	local opens = 0
	for id = 1, tree.leafCount do
		local size = tree.leafSize[id]
		if size > 0 then
			local k = `{tree.leafX[id]},{tree.leafZ[id]},{size},{tree.leafOpen[id]}`
			key[id] = k
			table.insert(c.leaves, k)
			if tree.leafOpen[id] then
				opens += 1
			end
			-- every cell of the leaf points back to it
			for cz = tree.leafZ[id], math.min(tree.leafZ[id] + size, g.cellsZ) - 1 do
				for cx = tree.leafX[id], math.min(tree.leafX[id] + size, g.cellsX) - 1 do
					if Quadtree.leafAt(tree, cz * g.cellsX + cx) ~= id then
						return nil, `cell ({cx}, {cz}) doesn't point to leaf {k}`
					end
				end
			end
		end
	end
	if opens ~= tree.openLeafCount then
		return nil, `openLeafCount {tree.openLeafCount} vs {opens}`
	end
	table.sort(c.leaves)
	for id = 1, tree.leafCount do
		if tree.leafSize[id] > 0 and tree.leafOpen[id] then
			local ns = {}
			for _, n in tree.neighbors[id] do
				if key[n] == nil then
					return nil, `leaf {key[id]} links to dead leaf {n}`
				end
				table.insert(ns, key[n])
			end
			table.sort(ns)
			c.neighbors[key[id]] = table.concat(ns, " ")
			c.comp[key[id]] = tree.leafComponent[id]
		end
	end
	return c, nil
end

-- nil if `a` (updated) has the same structure as `b` (fresh build).
local function sameTree(a: Quadtree.Tree, b: Quadtree.Tree): string?
	local ca, errA = canon(a)
	if ca == nil then
		return errA
	end
	local cb = canon(b) :: Canon
	if table.concat(ca.leaves, ";") ~= table.concat(cb.leaves, ";") then
		return `leaf sets differ ({#ca.leaves} vs {#cb.leaves} leaves)`
	end
	if ca.count ~= cb.count then
		return `component count {ca.count} vs {cb.count}`
	end
	local ab, ba = {}, {}
	for k, nb in cb.neighbors do
		if ca.neighbors[k] ~= nb then
			return `neighbors of {k} differ`
		end
		local x, y = ca.comp[k], cb.comp[k]
		if (ab[x] or y) ~= y or (ba[y] or x) ~= x then
			return `component partition differs at {k}`
		end
		ab[x], ba[y] = y, x
	end
	return nil
end

-- Brute-force capped Chebyshev clearance for one class.
local function bruteClearance(pm: Passability.PassMap, mc: string, cell: number): number
	local g = pm.grid
	local cx, cz = g:coords(cell)
	if not Passability.canEnter(pm, mc, cell) then
		return 0
	end
	local best = math.min(cx + 1, cz + 1, g.cellsX - cx, g.cellsZ - cz) -- map edge
	for r = 1, Passability.CLEARANCE_CAP do
		if r >= best then
			break
		end
		for z = cz - r, cz + r do
			for x = cx - r, cx + r do
				if (math.abs(x - cx) == r or math.abs(z - cz) == r) and g:inBounds(x, z) and not Passability.canEnter(pm, mc, g:index(x, z)) then
					best = math.min(best, r)
				end
			end
		end
	end
	return math.min(best, Passability.CLEARANCE_CAP)
end

local function checkClearance(t: RunAll.Context, pm: Passability.PassMap, label: string)
	for _, mc in CLASSES do
		for cell = 0, pm.grid.cellCount - 1 do
			local want = bruteClearance(pm, mc, cell)
			local got = Passability.clearance(pm, mc, cell)
			if got ~= want then
				t.equal(got, want, `{label}: {mc} clearance at cell {cell}`)
				return
			end
		end
	end
end

local function snapshot(pm: Passability.PassMap): string
	local parts = { buffer.tostring(pm.passMask), buffer.tostring(pm.occupancy) }
	for _, mc in CLASSES do
		table.insert(parts, buffer.tostring(pm.clearance[mc]))
	end
	return table.concat(parts)
end

return function(t: RunAll.Context)
	t.test("snap centers odd footprints on a cell", function()
		local g = Grid.new(16, 16) -- origin -64
		local x0, z0, cx, cz = Placement.snap(g, 1, -61, -57)
		t.deepEqual({ x0, z0, cx, cz }, { 0, 0, -60, -60 })
		x0, z0, cx, cz = Placement.snap(g, 3, 1, 2)
		t.deepEqual({ x0, z0, cx, cz }, { 7, 7, 4, 4 }, "3 × 3 centered on cell (8, 8)")
	end)

	t.test("placement checks: bounds, terrain, deposits, occupancy, units", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local defs = sim.defs.units
		local layers = (sim.map :: any).layers
		local g = layers.grid
		t.expect((Placement.check(sim, defs.ord_vehplant, 0, 0)), "open ground is fine")
		local _, why = Placement.check(sim, defs.ord_vehplant, g.originX + 4, 0)
		t.equal(why, "out of bounds", "3 × 3 hanging off the west edge")
		_, why = Placement.check(sim, defs.ord_extractor, 0, 0)
		t.equal(why, "no deposit")
		local sx, sz = g:cellAt(layers.starts[1][1], layers.starts[1][2])
		local dx, dz = g:cellCenter(sx + 4, sz + 4)
		t.expect((Placement.check(sim, defs.ord_extractor, dx, dz)), "extractor on a deposit")
		Spawn.unit(sim, "ord_extractor", 1, dx, dz)
		_, why = Placement.check(sim, defs.ord_extractor, dx, dz)
		t.equal(why, "occupied")
		Spawn.unit(sim, "ord_lancer", 1, 40, 40)
		_, why = Placement.check(sim, defs.ord_generator, 40, 40)
		t.equal(why, "units in the way")

		local wall = Sim.new({ seed = 1, players = PLAYERS, mapId = "wall:64" })
		local wg = (wall.map :: any).grid
		local wx, wz = wg:cellCenter(32, 40)
		_, why = Placement.check(wall, wall.defs.units.ord_generator, wx, wz)
		t.equal(why, "terrain", "no land structures on water")
	end)

	-- S-9: clients draw the build ghost with Shared/Grid/PlacementRules, so
	-- the server must decide terrain with exactly the same rule.
	t.test("the shared placement rules are the ones the server uses", function()
		t.expect(Placement.snap == PlacementRules.snap, "one snap")
		t.equal(Placement.LAND_MAX_SLOPE, PlacementRules.LAND_MAX_SLOPE)
		t.equal(Placement.WATER_MIN_DEPTH, PlacementRules.WATER_MIN_DEPTH)
		t.equal(Nav.RADIUS_PER_FOOTPRINT, PlacementRules.RADIUS_PER_FOOTPRINT)
		t.equal(Combat.RADIUS_PER_FOOTPRINT, PlacementRules.RADIUS_PER_FOOTPRINT)
		local waterOk = 0
		for _, mapId in { "wall:64", "gen:3:48" } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = mapId })
			local pm = sim.map :: Passability.PassMap
			local g = pm.grid
			local checked = { land = 0, water = 0, terrain = 0 }
			for _, defId in { "ord_generator", "ord_tidal" } do
				local def = sim.defs.units[defId]
				local placement = def.placement or "land"
				for cz = 0, g.cellsZ - 1, 2 do -- (every other cell: footprint-2 tidals fit wall:64's small lake, S-104)
					for cx = 0, g.cellsX - 1, 2 do
						local x, z = g:cellCenter(cx, cz)
						local ok, why, x0, z0 = Placement.check(sim, def, x, z)
						if ok or why == "terrain" then
							local shared = true
							for fz = z0, z0 + def.footprint - 1 do
								for fx = x0, x0 + def.footprint - 1 do
									shared = shared and PlacementRules.terrainOk(pm, g:index(fx, fz), placement)
								end
							end
							if shared ~= ok then
								t.equal(shared, ok, `{mapId} {defId} at cell ({cx}, {cz})`)
								return
							end
							checked[if ok then placement else "terrain"] += 1
						end
					end
				end
			end
			t.expect(checked.terrain > 0 and checked.land > 0, `{mapId}: both outcomes seen ({checked.land} land, {checked.water} water ok, {checked.terrain} terrain)`)
			waterOk += checked.water
		end
		t.expect(waterOk > 0, "some water placements allowed (wall:64's lake)")
	end)

	t.test("structures block ground classes; clearance updates exactly; release restores", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "gen:3:48" })
		local pm = sim.map :: Passability.PassMap
		local before = snapshot(pm)
		checkClearance(t, pm, "fresh map")
		local g = pm.grid
		local ids = {}
		for _, c in { { 10, 10 }, { 12, 11 }, { 30, 20 } } do
			local x, z = g:cellCenter(c[1], c[2])
			table.insert(ids, Spawn.unit(sim, "ord_vehplant", 1, x, z))
		end
		local center = g:index(10, 10)
		t.equal(Passability.occupant(pm, center), ids[1])
		t.expect(not Passability.canEnter(pm, "TRACKED", center), "tanks are blocked")
		t.expect(not Passability.canEnter(pm, "HOVER", center), "hovercraft are blocked")
		t.expect(Passability.canEnter(pm, "HELI", center), "aircraft fly over")
		checkClearance(t, pm, "after placing")
		for _, id in ids do
			Combat.queueDamage(sim.combat, id, 1e6, 0)
		end
		Sim.step(sim)
		t.equal(#sim.world.ids, 0, "all three destroyed")
		t.expect(snapshot(pm) == before, "destroying them restores every layer byte for byte")
	end)

	t.test("local quadtree updates equal a full rebuild as structures come and go", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "gen:3:128" })
		local nav = sim.nav :: Nav.Nav
		local pm = sim.map :: Passability.PassMap
		local rng = Prng.new(19)
		-- also a footprint-3 ground tree (need 2): clearance changes reach
		-- beyond the footprint, so the update must cover the padded rectangle
		Nav.tree(nav, "TRACKED", 2)
		local keys = {}
		for k in nav.trees do
			table.insert(keys, k)
		end
		table.sort(keys)
		t.expect(#keys >= 4, `trees for every ground profile ({#keys})`)
		local structures = {}
		local checks = 0
		for op = 1, 40 do
			if #structures > 0 and rng:chance(0.35) then
				local i = rng:nextInteger(1, #structures)
				Combat.queueDamage(sim.combat, structures[i], 1e9, 0)
				table.remove(structures, i)
				Sim.step(sim)
			else
				local def = if rng:chance(0.5) then "ord_vehplant" else "ord_generator"
				local id = Spawn.unit(sim, def, 1, rng:nextNumber(-480, 480), rng:nextNumber(-480, 480))
				table.insert(structures, id)
			end
			for _, k in keys do
				local old = nav.trees[k]
				local tree = Nav.tree(nav, old.moveClass, old.need, k) -- applies pending changes (lazy since S-67)
				local diff = sameTree(tree, Quadtree.build(pm, tree.moveClass, tree.need))
				t.equal(diff, nil, `op {op}, tree {k}`)
				checks += 1
				if diff then
					return
				end
			end
		end
		print(`    {checks} tree comparisons after 40 placements and removals`)
	end)

	t.test("routes go around a new structure", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:32" })
		local nav = sim.nav :: Nav.Nav
		local g = nav.grid
		local before = Nav.tree(nav, "TRACKED", 1)
		t.expect(Quadtree.isOpen(before, g:index(16, 20)), "open before the plants")
		-- a column of plants across the middle, leaving the top rows open
		for cz = 4, 30, 3 do
			local x, z = g:cellCenter(16, cz)
			Spawn.unit(sim, "ord_vehplant", 1, x, z)
		end
		local after = Nav.tree(nav, "TRACKED", 1)
		-- updated in place (D86): the same tree now blocks the plants' cells
		t.expect(after == before and not Quadtree.isOpen(after, g:index(16, 20)), "the quadtree was updated")
		local route = Route.find(after, g:index(2, 20), g:index(29, 20)) :: { number }
		t.expect(route ~= nil, "still reachable through the open top rows")
		local corridor = Route.corridor(after, route)
		for c = 0, g.cellCount - 1 do
			if Route.inCorridor(corridor, c) then
				t.equal(Passability.occupant(sim.map :: any, c), 0, "the corridor avoids every structure")
			end
		end
		t.expect(not Quadtree.isOpen(after, g:index(16, 20)), "the plant's cells are blocked")
	end)
end
