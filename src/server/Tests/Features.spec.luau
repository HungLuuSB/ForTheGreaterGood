--!strict
-- Map features (S-197): trees reclaimed for power, rocks for supply; rocks
-- block their cell until reclaimed; every team knows them from the start.
local FeatureDefs = require("@shared/Defs/Features")
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Placement = require("../Sim/Placement")
local Sim = require("../Sim/Sim")
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

local function newSim(): Sim.Sim
	return Sim.new({ seed = 1, players = PLAYERS, mapId = "map:supreme_strait" })
end

-- the feature of `kind` nearest (x, z)
local function nearest(sim: Sim.Sim, kind: number, x: number, z: number): number
	local c = sim.combat
	local best, bestD = 0, math.huge
	for _, wid in c.wreckIds do
		if c.wreckKind[wid] == kind then
			local d = (c.wreckX[wid] - x) ^ 2 + (c.wreckZ[wid] - z) ^ 2
			if d < bestD then
				best, bestD = wid, d
			end
		end
	end
	return best
end

return function(t: RunAll.Context)
	t.test("Supreme Strait's trees and rocks are on the map from the start; rocks block their cell", function()
		local sim = newSim()
		local c = sim.combat
		local trees, rocks = 0, 0
		local pm = sim.map :: Passability.PassMap
		for _, wid in c.wreckIds do
			if c.wreckKind[wid] == FeatureDefs.TREE then
				trees += 1
				t.equal(c.wreckSupply[wid], FeatureDefs.KINDS.tree.value)
			elseif c.wreckKind[wid] == FeatureDefs.ROCK then
				rocks += 1
				local i = pm.grid:index(pm.grid:cellAt(c.wreckX[wid], c.wreckZ[wid]))
				t.equal(Passability.occupant(pm, i), Passability.ROCK, "a rock occupies its cell")
				t.expect(not Passability.canEnter(pm, "TRACKED", i), "no tank drives into it")
			end
		end
		t.expect(trees >= 300, `{trees} trees`)
		t.expect(rocks >= 100, `{rocks} rocks`)
		-- nothing is built on a rock
		local rock = nearest(sim, FeatureDefs.ROCK, 0, 0)
		local ok = Placement.check(sim, sim.defs.units.ord_generator, c.wreckX[rock], c.wreckZ[rock], nil, 1)
		t.expect(not ok, "a generator can't go on a rock")
	end)

	t.test("reclaiming a tree pays power, a rock supply; the rock's cell opens", function()
		local sim = newSim()
		local c = sim.combat
		local w = sim.world
		local pm = sim.map :: Passability.PassMap
		for _, case in { { FeatureDefs.TREE, "power" }, { FeatureDefs.ROCK, "supply" } } do
			local wid = nearest(sim, case[1], -700, -700)
			local x, z = c.wreckX[wid], c.wreckZ[wid]
			local builder = Spawn.unit(sim, "ord_mason", 1, x + 30, z)
			local acc = sim.eco.accounts[1]
			acc[case[2]].stored = 0 -- (room for what it brings in)
			local before = 0
			submit(sim, 1, { cmdType = CT.RECLAIM, flags = 0, unitIds = { builder }, targetId = wid })
			for _ = 1, 15 * 40 do
				Sim.step(sim)
				if c.wreckX[wid] == nil then
					break
				end
			end
			t.equal(c.wreckX[wid], nil, `the {case[2]} feature is reclaimed`)
			Sim.step(sim)
			t.expect(acc[case[2]].stored > before, `{case[2]} rose`)
			if case[1] == FeatureDefs.ROCK then
				local i = pm.grid:index(pm.grid:cellAt(x, z))
				t.equal(Passability.occupant(pm, i), 0, "the rock's cell is free")
			end
			local _ = w
		end
	end)

	t.test("every team knows the map's features from the start, as WRECK records with their kind", function()
		local sim = newSim()
		local g = (sim.map :: any).grid
		local view = Client.new(g)
		for _ = 1, 3 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
		end
		local trees, rocks = 0, 0
		for _, wr in view.wrecks do
			if wr.featureKind == FeatureDefs.TREE then
				trees += 1
			elseif wr.featureKind == FeatureDefs.ROCK then
				rocks += 1
			end
		end
		t.expect(trees >= 300 and rocks >= 100, `the client has {trees} trees and {rocks} rocks without seeing them`)
	end)
end
