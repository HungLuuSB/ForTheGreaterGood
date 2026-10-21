--!strict
-- Terrain speed modifiers (guide 5.2, 6.3, 12.1; S-37). "terrain:64": grass
-- west of x = 0, sand east of it, a road along the middle row (z 0..8).
local FlowField = require("../Sim/Path/FlowField")
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Nav = require("../Sim/Nav")
local Packer = require("@shared/Net/Packer")
local Route = require("../Sim/Path/Route")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Terrain = require("@shared/Grid/Terrain")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- The top speed `defId` reaches driving east along z from x = x0 (20).
local function topSpeed(defId: string, z: number, x0: number?): number
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "terrain:64" })
	local w = sim.world
	local id = Spawn.unit(sim, defId, 1, x0 or 20, z, math.pi / 2)
	local cell, ox, oz = (sim.map :: any).grid:encode(240, z)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { id }, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, 1, wr:finish()))
	local top = 0
	for _ = 1, 15 * 6 do
		Sim.step(sim)
		top = math.max(top, w.speed[id])
	end
	return top
end

return function(t: RunAll.Context)
	t.test("top speed follows the ground: heavies crawl on sand, wheels race on roads", function()
		local defs = require("@shared/Defs/Defs").load()
		local heavyMax = defs.units.ord_paladin.movement.maxSpeed
		local sandHeavy = topSpeed("ord_paladin", 100)
		t.expect(math.abs(sandHeavy - heavyMax * Terrain.SPEED.HEAVY_TRACKED[Layers.Terrain.SAND]) < 0.01, `a heavy tank on sand: {sandHeavy} of {heavyMax}`)
		local wheelMax = defs.units.chs_jackal.movement.maxSpeed
		local road = topSpeed("chs_jackal", 4, -200) -- the whole road: room to reach 95 studs/s (S-62)
		t.expect(math.abs(road - wheelMax * Terrain.SPEED.WHEELED[Layers.Terrain.ROAD]) < 0.01, `a scout on the road: {road} of {wheelMax}`)
		local sand = topSpeed("chs_jackal", 100)
		t.expect(sand < road * 0.6, `and much slower on sand ({sand})`)
	end)

	t.test("flow fields prefer good ground: sand costs more to cross", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "terrain:64" })
		local nav = sim.nav :: Nav.Nav
		local g = nav.grid
		local tree = Nav.tree(nav, "HEAVY_TRACKED", 1)
		t.expect(tree.stepCost ~= nil, "the map has terrain, so the tree has step costs")
		-- from a goal on the road at the boundary, 10 cells into grass and into sand
		local goal = g:index(32, 32)
		local corridor = Route.corridor(tree, (function()
			local all = {}
			for i = 1, tree.leafCount do
				if tree.leafOpen[i] then
					table.insert(all, i)
				end
			end
			return all
		end)())
		local field = FlowField.build(tree, corridor, goal, true)
		local cost = field.cost :: { number }
		local grass = cost[g:index(22, 20) + 1]
		local sand = cost[g:index(42, 20) + 1]
		t.expect(sand > grass * 1.4, `crossing sand costs more: {sand} against {grass} on grass`)
		-- an all-grass map has none
		local flat = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:32" })
		t.equal(Nav.tree(flat.nav :: Nav.Nav, "HEAVY_TRACKED", 1).stepCost, nil, "all grass: plain costs")
	end)

	t.test("generated maps: sand on shores, rock on steep ground, symmetric", function()
		local layers = MapRegistry.load("map:coastline") :: Layers.Layers
		local n = layers.grid.cellsX
		local sand, rock, asym = 0, 0, 0
		for cz = 0, n - 1 do
			for cx = 0, n - 1 do
				local i = cz * n + cx
				local ty = Layers.getTerrain(layers, i)
				if ty == Layers.Terrain.SAND then
					sand += 1
					t.expect(Layers.getWater(layers, i) == 0, "sand is land")
				elseif ty == Layers.Terrain.ROCK then
					rock += 1
				end
				if ty ~= Layers.getTerrain(layers, cz * n + (n - 1 - cx)) then
					asym += 1 -- Coastline is mirrored west / east
				end
			end
		end
		t.expect(sand > 0 and rock > 0, `sand {sand} and rock {rock} cells`)
		t.equal(asym, 0, "the terrain is as symmetric as the map")
	end)
end
