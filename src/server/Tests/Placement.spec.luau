--!strict
local Grid = require("@shared/Grid/Grid")
local Passability = require("@shared/Grid/Passability")
local Combat = require("../Sim/Combat/Combat")
local Nav = require("../Sim/Nav")
local Placement = require("../Sim/Placement")
local Quadtree = require("../Sim/Path/Quadtree")
local Route = require("../Sim/Path/Route")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CLASSES = { "WHEELED", "TRACKED", "HEAVY_TRACKED", "HOVER", "AMPHIB", "SHIP", "SUB", "HELI", "JET" }

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

	t.test("routes go around a new structure", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:32" })
		local nav = sim.nav :: Nav.Nav
		local g = nav.grid
		local before = Nav.tree(nav, "TRACKED", 1)
		-- a column of plants across the middle, leaving the top rows open
		for cz = 4, 30, 3 do
			local x, z = g:cellCenter(16, cz)
			Spawn.unit(sim, "ord_vehplant", 1, x, z)
		end
		local after = Nav.tree(nav, "TRACKED", 1)
		t.expect(after ~= before, "the quadtree was rebuilt")
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
