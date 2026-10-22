--!strict
-- Shield domes on the wire (protocol 24, S-79; C-91): the client's view of a
-- generator's charge and up flag follows the server's, shells in a dome's
-- field are stepped like the server's and drawn where the server has them,
-- and turned-back shells arrive as hits for the dome renderer.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function scene()
	local sim = Sim.new({ seed = 9, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local gen = Spawn.unit(sim, "ord_phalanx", 1, 0, -100, 0)
	Spawn.unit(sim, "ord_fusion", 1, 0, -170, 0)
	sim.combat.shieldCharge[gen] = sim.defs.units.ord_phalanx.shield.capacity -- full
	sim.combat.shieldUp[gen] = true
	Spawn.unit(sim, "ord_mason", 1, 0, -40, 0) -- under the dome, near its edge
	local fx = Effects.new()
	local tick = 0
	local function step(n: number, each: (() -> ())?)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			if each then
				each()
			end
			table.clear(world.died)
		end
	end
	return sim, world, fx, gen, step
end

return function(t: any)
	t.test("SHIELD: the client's charge and up flag follow the server's", function()
		local sim, world, _, gen, step = scene()
		step(3)
		local sh = world.shields[gen]
		t.expect(sh ~= nil, "the generator's dome is known")
		t.expect(bit32.band(sh.flags, Schema.ShieldFlag.UP) ~= 0, "up")
		t.expect(math.abs(sh.charge - 1) < 0.02, `full ({sh.charge})`)
		-- drain it below 0: it collapses on both sides
		local cap = sim.defs.units.ord_phalanx.shield.capacity
		sim.combat.shieldCharge[gen] = cap * 0.4
		step(2)
		t.expect(math.abs(world.shields[gen].charge - 0.4) < 0.02, `40% ({world.shields[gen].charge})`)
		require("../../src/server/Sim/Shield").drain(sim, gen, cap)
		step(2)
		t.equal(bit32.band(world.shields[gen].flags, Schema.ShieldFlag.UP), 0)
		t.equal(sim.combat.shieldUp[gen], false)
	end)

	t.test("shells in the field: stepped like the server's, turned back, hits for the renderer", function()
		local sim, world, fx, gen, step = scene()
		Spawn.unit(sim, "chs_ravager", 2, 0, 120, math.pi)
		local inField, worst, hits, breaches, enters = 0, 0, 0, 0, 0
		local firstEnter, firstTurn = math.huge, math.huge
		step(15 * 12, function()
			for id, p in fx.projectiles do
				if p.field and sim.combat.px[id] then
					inField += 1
					-- the client steps to fx.tick; compare at the same tick
					local d = math.sqrt((p.x - sim.combat.px[id]) ^ 2 + (p.y - sim.combat.py[id]) ^ 2 + (p.z - sim.combat.pz[id]) ^ 2)
					if fx.tick == sim.tick then
						worst = math.max(worst, d)
					end
				end
			end
			for _, h in fx.shieldHits do
				if h.kind == "enter" then
					enters += 1
					firstEnter = math.min(firstEnter, fx.tick)
				else
					hits += 1
					firstTurn = math.min(firstTurn, fx.tick)
					t.equal(h.unitId, gen)
				end
				if h.breach then
					breaches += 1
				end
				local r = math.sqrt(h.x ^ 2 + (h.z + 100) ^ 2 + (h.y - World.groundY(world, 0, -100)) ^ 2)
				t.expect(math.abs(r - 120) < 4, `the hit is on the dome (r {r})`)
			end
			table.clear(fx.shieldHits)
		end)
		t.expect(inField > 0, "shells came into the field")
		t.expect(hits >= 2, `shells turned back ({hits})`)
		t.expect(enters >= hits, `every shell lights the dome as it enters ({enters} entries, {hits} turns)`)
		t.expect(firstEnter < firstTurn, `the entry shows before the turn (ticks {firstEnter}, {firstTurn})`)
		t.equal(breaches, 0, "a full dome lets no Ravager shell through")
		t.expect(worst < 3, `client and server agree on shells in the field (worst {worst} studs)`)
		print(string.format("    %d shell-ticks in the field, %d hits, worst %.2f studs off", inField, hits, worst))
	end)
end
