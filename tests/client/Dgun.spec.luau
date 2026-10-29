--!strict
-- The D-Gun (S-194, the user's G5): a Commander fires it from the client
-- API (D, then a left click), and the client draws its bolt with the
-- server's to the end of its range (its one IMPACT), riding 5 studs over
-- the ground; the units it burns through die on its way (their DEATHs).

local Api = require("../../src/client/Api")
local AttackPreview = require("../../src/client/Core/AttackPreview")
local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("a D-Gun bolt burns through a row of tanks, drawn with the server's to the end of its range", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local cmd = Spawn.unit(sim, "ord_sovereign", 1, -60, 0, math.pi / 2)
		local tanks = {}
		for i = 0, 2 do
			table.insert(tanks, Spawn.unit(sim, "chs_ravager", 2, -42 + i * 18, 0, 0)) -- 18, 36, 54 studs out: inside the D-Gun's 80 (H5, S-203)
		end
		local burned: { [number]: boolean } = {}
		for _, id in tanks do
			burned[id] = false
		end
		local fx = Effects.new()
		local tick = 0
		local bursts: { [any]: string } = {}
		local function step()
			tick += 1
			local acc = sim.eco.accounts[1] -- (a shot costs 500 power)
			acc.power.storage, acc.power.stored = 1e6, 1e6
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				bursts[b] = b.kind
			end
			for _, d in world.died do
				if burned[d.id] == false then
					burned[d.id] = true
				end
			end
			table.clear(world.died)
		end
		for _ = 1, 3 do
			step()
		end
		api.actions.select({ cmd })
		t.expect(api.actions.setCommandMode("dgun"))
		t.expect(api.actions.commandAt(15, 0, nil, false, false), "the D-Gun order went out") -- 75 studs: in range, the bolt runs on to its end
		local bolt, impacts, flights, worst, heightOff = nil, 0, 0, 0, 0
		for _ = 1, 15 * 6 do
			step()
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and bolt and e.other == bolt then
					impacts += 1
				end
				if e.kind == "SPAWN_PROJ" and e.unit == cmd then
					bolt = e.other
				end
			end
			local c = sim.combat
			local p = bolt and fx.projectiles[bolt]
			if p and c.projSlot[bolt] then
				flights += 1
				worst = math.max(worst, math.sqrt((p.x - c.px[bolt]) ^ 2 + (p.z - c.pz[bolt]) ^ 2))
				heightOff = math.max(heightOff, math.abs(p.y - (World.simGroundY(world, p.x, p.z) + Effects.BOLT_HEIGHT)))
			end
		end
		local alive, deaths = 0, 0
		for _, id in tanks do
			if sim.world.slot[id] then
				alive += 1
			end
			if burned[id] then
				deaths += 1
			end
		end
		print(string.format("    bolt drawn %d ticks with the server's, at most %.2f studs off, %.2f off its riding height; %d IMPACT; %d of 3 tanks left, %d DEATHs on the client", flights, worst, heightOff, impacts, alive, deaths))
		t.expect(bolt ~= nil, "the Sovereign fired its D-Gun")
		t.equal(alive, 0, "every tank on its path burned")
		t.equal(deaths, 3, "the client saw each tank die on the bolt's path")
		t.equal(impacts, 1, "the bolt's one IMPACT, at the end of its range")
		local gun = sim.defs.weapons.ord_sovereign_dgun
		local full = gun.range / gun.projectileSpeed * 15 -- ticks to the end of its range (34 at 160, 17 at 80)
		t.expect(flights >= full * 0.7, `drawn on through the tanks to the end of its range ({flights} of {full} ticks)`)
		t.expect(worst < 1, `with the server's bolt ({worst})`)
		t.expect(heightOff < 1e-6, "riding 5 studs over the ground")
		t.equal(fx.projectiles[bolt :: number], nil, "gone at the end")
		-- its own effects (models-C's templates, C-266)
		local kinds: { [string]: number } = {}
		for _, k in bursts do
			kinds[k] = (kinds[k] or 0) + 1
		end
		t.equal(kinds.dgunMuzzle, 1, "the D-Gun's muzzle flash")
		t.equal(kinds.dgunEnd, 1, "its end of range")
		t.equal(kinds.dgunHit, 3, "a hit on each tank it burned")
	end)
	t.test("the D-Gun preview's path and hitbox are the bolt's (C-264)", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local cmd = Spawn.unit(sim, "ord_sovereign", 1, -60, 0, math.pi / 2)
		-- in its way: an enemy on the line, one at its edge, an own tank; out of it: one wide, one past the end
		local inWay = {
			Spawn.unit(sim, "chs_ravager", 2, -40, 0, 0),
			Spawn.unit(sim, "chs_ravager", 2, -20, 10, 0),
			Spawn.unit(sim, "ord_lancer", 1, 0, -3, 0),
		}
		local clear = { Spawn.unit(sim, "chs_ravager", 2, -30, 16, 0), Spawn.unit(sim, "chs_ravager", 2, 40, 0, 0) }
		local tick = 0
		local died: { [number]: boolean } = {}
		local function step()
			tick += 1
			local acc = sim.eco.accounts[1]
			acc.power.storage, acc.power.stored = 1e6, 1e6
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			for _, d in world.died do
				died[d.id] = true
			end
			table.clear(world.died)
		end
		for _ = 1, 3 do
			step()
		end
		local far = AttackPreview.bolts(world, { cmd }, 60, 0)[1]
		t.expect(far.x0 == -60 and math.abs(far.x1 - 20) < 1e-6, `a point out of range: the path stays inside its range, from the Commander ({far.x0} to {far.x1})`)
		local px = AttackPreview.boltPoint(world.units[cmd], far.weapon, 60, 0)
		t.expect(math.abs(px - (-60 + 80 * AttackPreview.BOLT_REACH)) < 1e-6, `and the order's point is pulled into range ({px})`)
		t.equal(#AttackPreview.bolts(world, { cmd }, 0, 0, clear[2]), 0, "an enemy out of range: no path (it walks to it first)")
		t.equal(#AttackPreview.bolts(world, { inWay[1] }, 15, 0), 0, "no D-Gun: no preview")
		local b = AttackPreview.bolts(world, { cmd }, 10, 0)[1]
		t.expect(not b.walk and b.x0 == -60 and math.abs(b.x1 - 20) < 1e-6, `in range: from the Commander for the whole 80 ({b.x0} to {b.x1})`)
		local onEnemy = AttackPreview.bolts(world, { cmd }, 0, 0, inWay[1])[1]
		t.expect(onEnemy and math.abs(onEnemy.x1 - 20) < 1e-6, "an enemy in range: the path toward it")
		local previewed: { [number]: boolean } = {}
		for _, id in b.hits do
			previewed[id] = true
		end
		api.actions.select({ cmd })
		t.expect(api.actions.setCommandMode("dgun"))
		t.expect(api.actions.commandAt(10, 0, nil, false, false))
		for _ = 1, 15 * 4 do
			step()
		end
		for _, id in inWay do
			t.expect(previewed[id], `unit {id} marked in the bolt's way`)
			t.expect(died[id], `unit {id} burned`)
		end
		for _, id in clear do
			t.expect(not previewed[id], `unit {id} not marked`)
			t.expect(not died[id], `unit {id} spared`)
		end
	end)

	t.test("D-Gun orders: a far point fires from where the Commander stands; a far enemy is walked to (C-264)", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local cmd = Spawn.unit(sim, "ord_sovereign", 1, -150, 0, math.pi / 2)
		local tick = 0
		local fired = 0
		local tank: number? = nil
		local function step()
			tick += 1
			local acc = sim.eco.accounts[1]
			acc.power.storage, acc.power.stored = 1e6, 1e6
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == cmd then
					fired += 1
				end
			end
		end
		for _ = 1, 3 do
			step()
		end
		api.actions.select({ cmd })
		t.expect(api.actions.setCommandMode("dgun"))
		t.expect(api.actions.commandAt(100, 0, nil, false, false), "a point 250 studs out")
		for _ = 1, 15 * 3 do
			step()
		end
		t.equal(fired, 1, "fired")
		t.expect(math.abs(sim.world.posX[cmd] + 150) < 1, `from where it stood ({sim.world.posX[cmd]})`)
		tank = Spawn.unit(sim, "chs_ravager", 2, 0, 0, 0) -- 150 studs out
		for _ = 1, 15 * 3 do -- (the reload)
			step()
		end
		t.expect(api.actions.setCommandMode("dgun"))
		t.expect(api.actions.commandAt(0, 0, tank, false, false), "at the tank, out of range")
		for _ = 1, 15 * 12 do
			step()
		end
		t.equal(fired, 2, "walked into range and fired")
		t.expect(sim.world.posX[cmd] > -140, `it walked toward the tank ({sim.world.posX[cmd]}; the tank drives in to fight too)`)
		t.equal(sim.world.slot[tank], nil, "the tank burned")
	end)
end
