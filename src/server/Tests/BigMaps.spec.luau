--!strict
-- Bigger maps (S-189, the playtest's F4): protocol 38 puts positions on a
-- fixed wire grid (±8,192 studs), so maps go past 256 cells and aircraft
-- past the edge; the first medium map is The Lakelands (512 cells).
local Grid = require("@shared/Grid/Grid")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

return function(t: RunAll.Context)
	t.test("map sizes: small up to 256 cells, medium up to 512, large above; The Lakelands is medium", function()
		t.equal(MapRegistry.sizeClass(128), "small")
		t.equal(MapRegistry.sizeClass(256), "small")
		t.equal(MapRegistry.sizeClass(512), "medium")
		t.equal(MapRegistry.sizeClass(1024), "large")
		local layers = MapRegistry.load("map:lakelands") :: any
		t.equal(layers.grid.cellsX, 512, "512 cells (4,096 studs) a side")
		t.equal(#layers.starts, 4, "a 2v2")
		t.equal(MapRegistry.sizeClass(layers.grid.cellsX), "medium")
	end)

	t.test("a 512-cell map: a tank in its far corner and a jet past its edge reach the client to 1/8 stud", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:512" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 1980.3, 1990.7, 0)
		local jet = Spawn.unit(sim, "ord_falcon", 1, g.sizeX / 2 + 150, -1500, math.pi / 2) -- 150 studs past the east edge
		submit(sim, 1, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 400, minZ = 0, maxX = 511, maxZ = 511 })
		local view = Client.new(g)
		for _ = 1, 3 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
		end
		for _, id in { tank, jet } do
			local u = view.units[id]
			t.expect(u ~= nil and u.tier == "tactical", `unit {id} is tactical`)
			t.expect(math.abs(u.x - w.posX[id]) <= 1 / 8 and math.abs(u.z - w.posZ[id]) <= 1 / 8, `unit {id} at ({u.x}, {u.z}), sim ({w.posX[id]}, {w.posZ[id]})`)
		end
		t.expect(w.posX[jet] > g.sizeX / 2, "the jet is past the edge")
		-- a move order past the edge goes to the edge (orders stay on the map)
		local cell, ox, oz = g:encode(g.sizeX / 2 + 300, 0)
		submit(sim, 1, { cmdType = CT.MOVE, flags = 0, unitIds = { tank }, cell = cell, offX = ox, offZ = oz })
		Sim.step(sim)
		t.expect(w.goalX[tank] <= g.sizeX / 2, `the tank's goal is on the map ({w.goalX[tank]})`)
	end)

	t.test("the wire reaches past a 1,024-cell map's edge by more than Grid.OVERFLY", function()
		local g = Grid.new(1024, 1024)
		local edge = g.sizeX / 2 + Grid.OVERFLY
		t.expect(edge < Grid.WIRE_EXTENT, "the overfly margin is on the wire")
		local x, z = g:decode(g:encode(edge, -edge))
		t.deepEqual({ x, z }, { edge, -edge })
	end)

	t.slow("four AIs play a 2v2 on The Lakelands for 5 minutes: bases and armies", function()
		local players = {}
		for i = 1, 4 do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 2 then 1 else 2 })
		end
		local sim = Sim.new({ seed = 3, players = players, mapId = "map:lakelands", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", ai = { "normal", "hard", "hard", "hard_aggressive" } } })
		local brains = Skirmish.forMatch(sim)
		for _ = 1, 15 * 60 * 5 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		local w = sim.world
		for pid = 1, 4 do
			local structures, mobile = 0, 0
			for _, id in w.ids do
				if w.owner[id] == pid then
					if sim.defs.unitByIndex[w.defIndex[id]].domain == "structure" then
						structures += 1
					else
						mobile += 1
					end
				end
			end
			t.expect(structures >= 6, `AI {pid}: a base ({structures} structures)`)
			t.expect(mobile >= 3, `AI {pid}: an army ({mobile} mobile units)`)
		end
	end)
end
