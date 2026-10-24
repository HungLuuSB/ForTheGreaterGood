--!strict
-- WALKER (S-159): the Commanders' move class climbs 40° slopes. On every
-- registry map the Commanders still get from every start to every other
-- and to every deposit a tank can reach, and they reach at least as much
-- ground as tanks (more passable cells only join components).
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local Defs = require("@shared/Defs/Defs")
local Quadtree = require("../Sim/Path/Quadtree")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	t.test("both Commanders walk as WALKER at footprint 2", function()
		local defs = Defs.load()
		for _, id in { "ord_sovereign", "chs_warlord" } do
			t.equal(defs.units[id].moveClass, "WALKER", id)
			t.equal(defs.units[id].footprint, 2, id)
		end
	end)

	local ids = {}
	for name in MapRegistry.NAMED do
		table.insert(ids, name)
	end
	for name in MapRegistry.HANDMADE do
		table.insert(ids, name)
	end
	table.sort(ids)
	for _, name in ids do
		t.test(`map:{name}: every start reaches every other start and every deposit a tank reaches`, function()
			local layers = MapRegistry.load("map:" .. name) :: Layers.Layers
			local g = layers.grid
			local pm = Passability.build(layers)
			local need = Passability.requiredClearance(2)
			local walker = Quadtree.build(pm, "WALKER", need)
			local tank = Quadtree.build(pm, "TRACKED", need)
			local first: number? = nil
			for k, s in layers.starts do
				local cell = g:index(g:cellAt(s[1], s[2]))
				t.expect(Quadtree.isOpen(walker, cell), `start {k} is open to a Commander`)
				local comp = Quadtree.component(walker, cell)
				if first == nil then
					first = comp
				end
				t.equal(comp, first, `start {k} connects to start 1`)
				local tankComp = Quadtree.component(tank, cell)
				local missed = 0
				for i = 0, g.cellCount - 1 do
					if Layers.getSupply(layers, i) > 0 and Quadtree.isOpen(tank, i) and Quadtree.component(tank, i) == tankComp then
						if Quadtree.component(walker, i) ~= comp then
							missed += 1
						end
					end
				end
				t.equal(missed, 0, `start {k}: deposit cells a tank reaches but a Commander doesn't`)
			end
			local extra, lost = 0, 0
			for i = 0, g.cellCount - 1 do
				local w, k = Quadtree.isOpen(walker, i), Quadtree.isOpen(tank, i)
				if k and not w then
					lost += 1
				elseif w and not k then
					extra += 1
				end
			end
			t.equal(lost, 0, "a Commander enters every cell a tank does")
			print(`    {name}: {extra} cells open to Commanders only ({math.floor(extra / g.cellCount * 1000 + 0.5) / 10}% of the map)`)
		end)
	end
end
