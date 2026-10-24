--!strict
-- Point defence on the client (S-149, C-182): a Sanctum's interceptors
-- chase the MLRS rockets they were fired at on the server's path, a rocket
-- shot down is dropped with a small puff, and the four units have icons.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local IconAtlas = require("../../src/client/UI/IconAtlas")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")
local Schema = require("@shared/Net/Schema")
local Packer = require("@shared/Net/Packer")

local DT = 1 / 15

return function(t: any)
	t.test("a Sanctum's interceptors chase rockets on the server's path; shot-down rockets end in a puff", function()
		local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		ServerWorld.setHealth(w, tank, 1e7)
		ServerWorld.setFireState(w, tank, ServerWorld.FireState.HOLD_FIRE)
		local hydra = Spawn.unit(sim, "chs_hydra", 2, 380, 0, -math.pi / 2)
		local spotter = Spawn.unit(sim, "chs_jackal", 2, 90, -60)
		ServerWorld.setHealth(w, spotter, 1e7)
		ServerWorld.setFireState(w, spotter, ServerWorld.FireState.HOLD_FIRE)
		local sanctum = Spawn.unit(sim, "ord_sanctum", 1, -30, 30)
		ServerWorld.setHealth(w, sanctum, 1e7)
		local cw = Packer.Writer.new()
		Schema.encodeCommand(cw, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { hydra }, targetId = tank })
		assert(Sim.submit(sim, 2, cw:finish()))
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local fx = Effects.new()
		local c = sim.combat
		local intercepted, chasers, puffs, worst, compared = 0, 0, 0, 0, 0
		local seenChaser: { [any]: boolean } = {} -- by projectile (IDs are reused)
		for tick = 1, 450 do
			sim.eco.accounts[1].supply.stored = 1000
			sim.eco.accounts[1].power.stored = 1000
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "INTERCEPTED" then
					intercepted += 1
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			for _, b in fx.bursts do
				if b.born == tick * DT and b.kind == "impact" and b.size == Effects.INTERCEPT_PUFF then
					puffs += 1
				end
			end
			for id, p in fx.projectiles do
				if p.chase and not seenChaser[p] then
					seenChaser[p] = true
					chasers += 1
				end
				if p.chase and c.projSlot[id] then
					local d = math.sqrt((p.x - c.px[id]) ^ 2 + (p.y - c.py[id]) ^ 2 + (p.z - c.pz[id]) ^ 2)
					worst = math.max(worst, d)
					compared += 1
				end
			end
		end
		print(string.format("    Sanctum vs MLRS on the client: %d interceptors drawn, %d shot down (%d puffs), worst %.2f studs off the server over %d ticks", chasers, intercepted, puffs, worst, compared))
		t.expect(intercepted >= 2, `rockets shot down ({intercepted})`)
		t.expect(chasers >= intercepted, `each interceptor drawn chasing its rocket ({chasers})`)
		t.expect(puffs >= intercepted, `a small puff per rocket shot down ({puffs})`)
		-- (the server steers at its target's start-of-tick state since S-151,
		-- as the client does: wire quantization only)
		t.expect(compared > 20 and worst < 0.5, `interceptors on the server's path (worst {worst} studs)`)
	end)

	t.test("the four point-defence units have icons", function()
		for _, id in { "ord_sanctum", "chs_basilisk", "ord_shepherd", "chs_griffin" } do
			local e = IconAtlas.byDef[id]
			t.expect(e ~= nil and IconAtlas.tiles[e.tile] ~= nil, `{id} has a tile`)
		end
	end)
end
