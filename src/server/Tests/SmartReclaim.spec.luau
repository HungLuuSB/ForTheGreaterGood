--!strict
-- Smart Reclaim (S-183, the user): an AREA order reclaims, resurrects or
-- repairs everything in a circle, nearest first, then ends; with REPEAT the
-- worker stays for new wrecks. Reclaim shows in the sent income.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType
local OP = Schema.AreaOp

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function area(sim: Sim.Sim, ids: { number }, op: number, x: number, z: number, radius: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, 1, { cmdType = CT.AREA, flags = 0, unitIds = ids, areaOp = op, cell = cell, offX = ox, offZ = oz, radius = radius })
end

local function wreck(sim: Sim.Sim, defId: string, x: number, z: number): number
	return Combat.addWreck(sim.combat, x, z, sim.defs.units[defId], 0)
end

return function(t: RunAll.Context)
	t.test("area reclaim takes every wreck in the circle, nearest first, and ends; one outside stays", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, -150)
		local inside = { wreck(sim, "chs_ravager", -40, 40), wreck(sim, "chs_ravager", 40, 40), wreck(sim, "chs_ravager", 0, -20) }
		local outside = wreck(sim, "chs_ravager", 0, 200)
		area(sim, { mason }, OP.RECLAIM, 0, 20, 100)
		local order: { number } = {}
		for _ = 1, 15 * 120 do
			Sim.step(sim)
			for _, wid in inside do
				if sim.combat.wreckX[wid] == nil and not table.find(order, wid) then
					table.insert(order, wid)
				end
			end
			if #order == #inside and (sim.orders.queue[mason] == nil or #sim.orders.queue[mason] == 0) then
				break
			end
		end
		t.equal(#order, 3, "all three reclaimed")
		t.equal(order[1], inside[3], "the nearest first")
		t.expect(sim.combat.wreckX[outside] ~= nil, "the one outside the circle is left")
		t.equal(#(sim.orders.queue[mason] or {}), 0, "the order ended")
	end)

	t.test("with REPEAT the worker stays and takes each new wreck", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, -100)
		submit(sim, 1, { cmdType = CT.REPEAT, flags = 0, unitIds = { mason }, value = 1 })
		area(sim, { mason }, OP.RECLAIM, 0, 0, 80)
		for _ = 1, 15 * 10 do
			Sim.step(sim)
		end
		t.expect(#(sim.orders.queue[mason] or {}) == 1, "nothing to reclaim yet: it stays")
		local late = wreck(sim, "chs_ravager", 30, 30)
		for _ = 1, 15 * 60 do
			Sim.step(sim)
			if sim.combat.wreckX[late] == nil then
				break
			end
		end
		t.equal(sim.combat.wreckX[late], nil, "the new wreck was reclaimed")
		t.expect(#(sim.orders.queue[mason] or {}) == 1, "and it still stays")
	end)

	t.test("area resurrect brings wrecks back (only with workers that can); area repair heals the team's damaged units", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, -60)
		local sim2wreck = wreck(sim, "ord_lancer", 20, 20)
		local acc = sim.eco.accounts[1]
		acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
		area(sim, { mason }, OP.RESURRECT, 0, 0, 80)
		local back = false
		for _ = 1, 15 * 120 do
			acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
			Sim.step(sim)
			for _, id in w.ids do
				if w.owner[id] == 1 and sim.defs.unitByIndex[w.defIndex[id]].id == "ord_lancer" then
					back = true
				end
			end
			if back then
				break
			end
		end
		local _ = sim2wreck
		t.expect(back, "the Lancer is back")
		local tanks = {}
		for _, x in { -30, 30 } do
			local id = Spawn.unit(sim, "ord_lancer", 1, x, 100)
			World.setHealth(w, id, 300)
			table.insert(tanks, id)
		end
		area(sim, { mason }, OP.REPAIR, 0, 100, 80)
		for _ = 1, 15 * 120 do
			Sim.step(sim)
		end
		for _, id in tanks do
			t.equal(w.health[id], sim.defs.units.ord_lancer.health, "repaired to full")
		end
	end)

	t.test("reclaimed supply counts in the income sent to the client", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, -20)
		for i = 1, 4 do
			wreck(sim, "chs_juggernaut", -30 + i * 15, 10)
		end
		area(sim, { mason }, OP.RECLAIM, 0, 10, 60)
		local peak = 0
		for _ = 1, 15 * 30 do
			Sim.step(sim)
			peak = math.max(peak, sim.eco.accounts[1].supply.reclaimRate or 0)
		end
		t.expect(peak > 0, `reclaim shows as a rate ({peak} supply/s)`)
	end)

	t.test("AREA records round-trip; bad radii are refused", function()
		local cmd: Schema.Command = { cmdType = CT.AREA, flags = 0, unitIds = { 5 }, areaOp = OP.REPAIR, cell = 0x0102, offX = 3, offZ = 4, radius = 300 }
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, cmd)
		t.deepEqual(Packer.readAll(w:finish(), Schema.decodeCommand)[1], cmd)
		t.throws(function()
			local x = Packer.Writer.new()
			Schema.encodeCommand(x, { cmdType = CT.AREA, flags = 0, unitIds = { 5 }, areaOp = OP.REPAIR, cell = 1, offX = 0, offZ = 0, radius = 0 })
		end, "area op")
	end)
end
