--!strict
-- Procedural maps (S-15, guide 5.5): exact symmetry, land paths between all
-- starts for the biggest land units, the sea reachable on naval maps, gaps
-- at least 3 cells wide, fair deposits. Connectivity is checked with the
-- server's own pathing (Nav quadtrees), not MapGen's checker.
local Layers = require("@shared/Grid/Layers")
local MapGen = require("@shared/Grid/MapGen")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local TestMap = require("@shared/Grid/TestMap")
local Nav = require("../Sim/Nav")
local Quadtree = require("../Sim/Path/Quadtree")
local Sim = require("../Sim/Sim")
local RunAll = require("./RunAll")

local MAPS = {
	"map:ridgeline",
	"map:coastline",
	"map:twin_lakes",
	"map:crossroads",
	"mapgen:1v1:5:128:lakes:rotate2",
	"mapgen:ffa4:6:192",
}

-- One player per start; on 2v2 maps players 1-2 and 3-4 are the teams
-- (the map's start order), otherwise everyone for themselves.
local function players(info: MapGen.Info): { { id: number, team: number } }
	local out = {}
	for i = 1, info.players do
		table.insert(out, { id = i, team = if info.layout == "2v2" then (i + 1) // 2 else i })
	end
	return out
end

local function startCells(layers: Layers.Layers): { number }
	local g = layers.grid
	local out = {}
	for _, s in layers.starts do
		table.insert(out, g:index(g:cellAt(s[1], s[2])))
	end
	return out
end

return function(t: RunAll.Context)
	t.test("maps are exactly symmetric and deterministic", function()
		for _, mapId in MAPS do
			local layers = MapRegistry.load(mapId) :: Layers.Layers
			local info = MapRegistry.info(mapId) :: MapGen.Info
			local g = layers.grid
			local n = g.cellsX
			local group = MapGen.GROUPS[info.symmetry]
			t.equal(#layers.starts, info.players, `{mapId}: a start per player`)
			for k, tf in group do
				local bad = 0
				for cz = 0, n - 1 do
					for cx = 0, n - 1 do
						local tx, tz = tf(cx + 0.5, cz + 0.5, n)
						local i, j = g:index(cx, cz), g:index(math.floor(tx), math.floor(tz))
						if Layers.getHeight(layers, i) ~= Layers.getHeight(layers, j) or Layers.getWater(layers, i) ~= Layers.getWater(layers, j) or Layers.getSupply(layers, i) ~= Layers.getSupply(layers, j) then
							bad += 1
						end
					end
				end
				t.equal(bad, 0, `{mapId}: cells differing from their image under {info.symmetry} transform {k}`)
				-- start k is the image of start 1
				local sx, sz = g:cellAt(layers.starts[1][1], layers.starts[1][2])
				local tx, tz = tf(sx + 0.5, sz + 0.5, n)
				t.deepEqual({ g:cellAt(layers.starts[k][1], layers.starts[k][2]) }, { math.floor(tx), math.floor(tz) }, `{mapId}: start {k}`)
			end
			local again = MapGen.generate(MapRegistry.genOptions(mapId) :: MapGen.Options)
			t.expect(
				buffer.tostring(again.height) == buffer.tostring(layers.height) and buffer.tostring(again.waterDepth) == buffer.tostring(layers.waterDepth) and buffer.tostring(again.supply) == buffer.tostring(layers.supply),
				`{mapId}: the same options give byte-identical layers`
			)
		end
	end)

	t.test("every start reaches every other by land, for footprint-3 units (server pathing)", function()
		for _, mapId in MAPS do
			local info = MapRegistry.info(mapId) :: MapGen.Info
			local sim = Sim.new({ seed = 1, players = players(info), mapId = mapId })
			local layers = (sim.map :: any).layers :: Layers.Layers
			local cells = startCells(layers)
			for _, mc in { "TRACKED", "HEAVY_TRACKED", "WHEELED" } do
				local need = if mc == "WHEELED" then 1 else Passability.requiredClearance(3)
				local tree = Nav.tree(sim.nav, mc, need)
				local home = Quadtree.component(tree, cells[1])
				t.expect(home ~= 0, `{mapId}: start 1 is open for {mc}`)
				for i, c in cells do
					t.equal(Quadtree.component(tree, c), home, `{mapId}: {mc} from start 1 to start {i}`)
				end
			end
		end
	end)

	t.test("naval maps: one sea that ships reach from the coast near several starts", function()
		for _, mapId in MAPS do
			local info = MapRegistry.info(mapId) :: MapGen.Info
			if info.water ~= "sea" then
				continue
			end
			t.expect(table.find(info.modes, "Naval") ~= nil, `{mapId} is tagged Naval`)
			local sim = Sim.new({ seed = 1, players = players(info), mapId = mapId })
			local layers = (sim.map :: any).layers :: Layers.Layers
			local g = layers.grid
			local tree = Nav.tree(sim.nav, "SHIP", Passability.requiredClearance(3))
			local seas: { [number]: number } = {}
			for _, s in layers.starts do
				local sx, sz = g:cellAt(s[1], s[2])
				local nearest, best = 0, math.huge
				for cz = math.max(0, sz - 48), math.min(g.cellsZ - 1, sz + 48) do
					for cx = math.max(0, sx - 48), math.min(g.cellsX - 1, sx + 48) do
						local d = (cx - sx) ^ 2 + (cz - sz) ^ 2
						local c = Quadtree.component(tree, g:index(cx, cz))
						if c ~= 0 and d < best then
							nearest, best = c, d
						end
					end
				end
				if nearest ~= 0 then
					seas[nearest] = (seas[nearest] or 0) + 1
				end
			end
			local most = 0
			local count = 0
			for _, k in seas do
				most = math.max(most, k)
				count += 1
			end
			t.equal(count, 1, `{mapId}: the coasts near the starts are on one sea`)
			t.expect(most >= 2, `{mapId}: ships from {most} starts meet on it`)
		end
	end)

	t.test("the checker finds gaps narrower than 3 cells; generated maps have none", function()
		-- a north-south cliff with one gap, 2 or 3 cells wide
		local function walled(gap: number): Layers.Layers
			local layers = TestMap.build(64, 64, function(cx, cz)
				local wall = cx >= 30 and cx <= 33 and not (cz >= 20 and cz < 20 + gap)
				return if wall then 60 else 10, 0
			end)
			table.insert(layers.starts, { layers.grid:cellCenter(10, 32) })
			table.insert(layers.starts, { layers.grid:cellCenter(53, 32) })
			return layers
		end
		-- the cliff's own slope blocks one more cell on each side of the
		-- wall, so a terrain gap of g + 2 cells leaves g passable cells
		local narrow = MapGen.check(walled(4), "none")
		t.expect(#narrow > 0, "a 2-cell pass is reported")
		local found = false
		for _, p in narrow do
			found = found or string.find(p, "narrower") ~= nil
		end
		t.expect(found, `as a narrow gap ({narrow[1]})`)
		t.deepEqual(MapGen.check(walled(5), "none"), {}, "a 3-cell pass is fine")
		for _, mapId in MAPS do
			local layers = MapRegistry.load(mapId) :: Layers.Layers
			local info = MapRegistry.info(mapId) :: MapGen.Info
			t.deepEqual(MapGen.check(layers, info.water), {}, `{mapId} passes every check`)
		end
	end)

	t.test("deposits: safe ones at each start, contested ones between, equal totals per start", function()
		for _, mapId in MAPS do
			local layers = MapRegistry.load(mapId) :: Layers.Layers
			local g = layers.grid
			local cells = startCells(layers)
			local totals, safe = table.create(#cells, 0), table.create(#cells, 0)
			local contested = 0
			for i = 0, g.cellCount - 1 do
				local v = Layers.getSupply(layers, i)
				if v > 0 then
					local x, z = g:cellCenter(g:coords(i))
					local best, nearest = math.huge, {}
					for k, s in layers.starts do
						local d = math.floor(((x - s[1]) ^ 2 + (z - s[2]) ^ 2) * 1000 + 0.5) -- exact ties
						if d < best then
							best, nearest = d, { k }
						elseif d == best then
							table.insert(nearest, k)
						end
					end
					for _, k in nearest do
						totals[k] += v / #nearest
						if best <= (8 * 8) ^ 2 * 1000 then
							safe[k] += 1
						end
					end
					if math.sqrt(best / 1000) > 0.4 * g.sizeX / 2 then
						contested += 1
					end
				end
			end
			for k = 2, #cells do
				t.equal(totals[k], totals[1], `{mapId}: start {k}'s deposit total equals start 1's`)
			end
			for k = 1, #cells do
				t.expect(safe[k] >= 4, `{mapId}: start {k} has {safe[k]} safe deposits`)
			end
			t.expect(contested >= #cells, `{mapId}: contested deposits away from the starts ({contested})`)
		end
	end)

	t.test("a named map runs a skirmish start for its player count", function()
		for _, mapId in { "map:coastline", "map:twin_lakes", "map:crossroads" } do
			local info = MapRegistry.info(mapId) :: MapGen.Info
			local sim = Sim.new({ seed = 1, players = players(info), mapId = mapId, scenario = "standard_start" })
			for _ = 1, 30 do
				Sim.step(sim)
			end
			t.equal(#sim.world.ids, info.players, `{mapId}: a commander per player`)
		end
	end)
end
