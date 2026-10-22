--!strict
-- Shield domes on the wire (protocol 24, S-79; C-91): the client's view of a
-- generator's charge and up flag follows the server's, and every shell
-- reaching an up dome is destroyed at its surface (S-93: no field, no
-- turning back), drawn up to there and lit there for the dome renderer.

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

	t.test("heavy shells too (S-93): every shell is destroyed at the surface, none turned back or breaking through", function()
		local sim, _, fx, gen, step = scene()
		Spawn.unit(sim, "chs_ravager", 2, 0, 120, math.pi) -- a heavy cannon: turned back before S-93
		local absorbs, other, inside = 0, 0, 0
		local cx, cy, cz = require("../../src/server/Sim/Shield").center(sim, gen) -- the dome's centre: the generator's base
		step(15 * 12, function()
			for _, h in fx.shieldHits do
				if h.kind == "absorb" then
					absorbs += 1
					local r = math.sqrt((h.x - cx) ^ 2 + (h.z - cz) ^ 2 + (h.y - cy) ^ 2)
					t.expect(math.abs(r - 120) < 0.5, `at the surface (r {r})`)
				else
					other += 1
				end
			end
			table.clear(fx.shieldHits)
			for _, p in fx.projectiles do
				local r = math.sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2 + (p.y - cy) ^ 2)
				if r < 110 then
					inside += 1
				end
			end
		end)
		t.expect(absorbs >= 3, `heavy shells destroyed at the dome ({absorbs})`)
		t.equal(other, 0, "no turn, breach or field entry hits")
		t.equal(inside, 0, "none drawn well inside the dome")
	end)

	-- every frame of `seconds` at 4 frames a tick, `frame(renderTick)` after
	-- Effects.update; drawn a tick behind the newest, as the game is (Interp's
	-- delay), so a hit due next tick is already known: a fast shell the server
	-- lets sit a tick inside the dome before absorbing it is stopped at the
	-- surface (it showed once S-104 moved the dome half a cell)
	local function subTicks(sim: any, world: any, fx: any, seconds: number, frame: (number) -> ())
		for tick = 1, math.floor(15 * seconds) do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for q = 1, 4 do
				local t = tick - 2 + q / 4
				Effects.update(fx, world, t, t * DT, 0, 0)
				frame(t)
			end
			table.clear(world.died)
		end
	end

	t.test("a light shell vanishes where its drawn path meets the dome (C-99)", function()
		local sim, world, fx = scene()
		Spawn.unit(sim, "chs_locust", 2, 0, 40, math.pi)
		-- the dome's real centre: the generator snaps to its footprint (fp 3 since S-104)
		local dx, dz = 0, -100
		for _, id in sim.world.ids do
			local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
			if def.shield then
				dx, dz = sim.world.posX[id], sim.world.posZ[id]
			end
		end
		local gy = World.groundY(world, dx, dz)
		local deepest, absorbs = 0, 0
		subTicks(sim, world, fx, 8, function(t: number)
			for _, h in fx.shieldHits do
				if h.kind == "absorb" then
					absorbs += 1
				end
			end
			table.clear(fx.shieldHits)
			for _, e in Effects.visible(fx, t) do
				local r = math.sqrt((e[2] - dx) ^ 2 + (e[3] - gy) ^ 2 + (e[4] - dz) ^ 2)
				deepest = math.max(deepest, 120 - r)
			end
		end)
		t.expect(absorbs >= 3, `rounds destroyed ({absorbs})`)
		t.expect(deepest < 4, `never drawn more than a few studs inside ({deepest})`)
	end)

	t.test("light shells (S-85): destroyed at the surface, dropped with no burst, the dome lit there", function()
		local sim, world, fx, _, step = scene()
		Spawn.unit(sim, "chs_locust", 2, 0, 40, math.pi) -- autocannon, mass ~0.23
		local absorbs, inside, bursts = 0, 0, 0
		local seen: { [any]: boolean } = {}
		step(15 * 8, function()
			for _, h in fx.shieldHits do
				if h.kind == "absorb" then
					absorbs += 1
					local r = math.sqrt(h.x ^ 2 + (h.z + 100) ^ 2 + (h.y - World.groundY(world, 0, -100)) ^ 2)
					t.expect(math.abs(r - 120) < 4, `at the surface (r {r})`)
				end
			end
			table.clear(fx.shieldHits)
			for _, p in fx.projectiles do
				local r = math.sqrt(p.x ^ 2 + (p.z + 100) ^ 2 + (p.y - World.groundY(world, 0, -100)) ^ 2)
				if r < 110 then
					inside += 1
				end
			end
			for _, b in fx.bursts do
				if not seen[b] then
					seen[b] = true
					local r = math.sqrt(b.x ^ 2 + (b.z + 100) ^ 2)
					if r < 110 then
						bursts += 1
					end
				end
			end
		end)
		t.expect(absorbs >= 3, `autocannon rounds destroyed at the dome ({absorbs})`)
		t.equal(inside, 0, "none drawn well inside the dome")
		t.equal(bursts, 0, "no bursts inside the dome")
	end)
end
