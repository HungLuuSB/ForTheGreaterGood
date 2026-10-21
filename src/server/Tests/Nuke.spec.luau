--!strict
-- Strategic missiles (S-48, client request 26): nuke silos launch on an
-- attack-ground order only; radar SAMs intercept them.
local Layers = require("@shared/Grid/Layers")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local EK = Schema.EventKind
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local TARGET_X, TARGET_Z = 600, 0

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function attackGround(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, player, { cmdType = CT.ATTACK_GROUND, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

local function camera(sim: Sim.Sim, player: number, x: number, z: number)
	local g = (sim.map :: any).grid
	local cx, cz = g:cellAt(x, z)
	submit(sim, player, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = cx - 20, minZ = cz - 20, maxX = cx + 20, maxZ = cz + 20 })
end

local function eventsOf(sim: Sim.Sim, kind: string): { any }
	local out = {}
	for _, e in sim.combat.events do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- An Order silo far west; at the target a Chaos tank, an Order tank and,
-- 400 studs off, a Chaos tank outside the blast.
local function range(seed: number): (Sim.Sim, number, { [string]: number })
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:256" })
	local silo = Spawn.unit(sim, "ord_reckoning", 1, -800, 0, 0)
	local units = {
		enemy = Spawn.unit(sim, "chs_ravager", 2, TARGET_X, TARGET_Z, 0),
		own = Spawn.unit(sim, "ord_lancer", 1, TARGET_X + 30, TARGET_Z + 30, 0),
		far = Spawn.unit(sim, "chs_ravager", 2, TARGET_X, TARGET_Z + 400, 0),
	}
	for _, id in units do
		World.setMoveState(sim.world, id, World.MoveState.HOLD_POSITION)
		sim.world.fireState[id] = World.FireState.HOLD_FIRE
	end
	return sim, silo, units
end

return function(t: RunAll.Context)
	t.test("a silo launches only when ordered, one lofted warhead per order, and the blast hurts every side", function()
		local sim, silo, units = range(1)
		local w = sim.world
		local key = World.slotKey(silo, 1)
		t.equal(w.wStock[key], 2, "a placed silo starts with its 2 warheads")
		for _ = 1, 150 do
			Sim.step(sim)
			t.equal(#eventsOf(sim, "LAUNCH"), 0, "never fires on its own")
		end
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local launchedAt: number? = nil
		local nuke = 0
		local apex, impact = 0, nil :: { number }?
		for _ = 1, 400 do
			Sim.step(sim)
			for _, e in eventsOf(sim, "LAUNCH") do
				t.expect(launchedAt == nil, "one launch per order")
				launchedAt, nuke = sim.tick, e.other
			end
			if nuke ~= 0 and sim.combat.projSlot[nuke] then
				apex = math.max(apex, sim.combat.py[nuke])
			end
			for _, e in eventsOf(sim, "IMPACT") do
				if e.other == nuke and launchedAt then
					impact = { sim.tick, e.x, e.z }
				end
			end
			if impact then
				break
			end
		end
		assert(launchedAt and impact, "launched and landed")
		t.expect(launchedAt <= 2 + 151, `launched at once (tick {launchedAt})`)
		t.equal(w.wStock[key], 1, "it spent a warhead")
		t.equal(sim.air.groundX[silo], nil, "the order is done")
		local flight = (impact[1] - launchedAt) / 15
		print(string.format("    nuke: flight %.1f s, apex %.0f studs, landed %.1f studs from the target", flight, apex, math.sqrt((impact[2] - TARGET_X) ^ 2 + (impact[3] - TARGET_Z) ^ 2)))
		t.expect(apex >= 295 and apex <= 340, `lofted to ~300 studs above the silo (apex {apex})`)
		t.expect(flight > 10 and flight < 16, `slow: {flight} s in the air`)
		t.expect(math.sqrt((impact[2] - TARGET_X) ^ 2 + (impact[3] - TARGET_Z) ^ 2) < 5, "lands on the ordered spot")
		for _ = 1, 3 do
			Sim.step(sim) -- damage applies
		end
		t.equal(w.slot[units.enemy], nil, "the enemy tank at the spot is gone")
		t.equal(w.slot[units.own], nil, "so is the silo owner's own tank")
		t.equal(w.health[units.far], sim.defs.units.chs_ravager.health, "400 studs off is untouched")
		for _ = 1, 300 do
			Sim.step(sim)
			t.equal(#eventsOf(sim, "LAUNCH"), 0, "no second launch without a second order")
		end
	end)

	t.test("the warhead climbs straight up 120 studs, pitches over, and a client flying its own copy stays with it", function()
		local sim, silo = range(4)
		local c = sim.combat
		local g = (sim.map :: any).grid
		camera(sim, 2, 0, -800) -- far from everything: the missile still comes
		local view = Client.new(g, nil, (sim.map :: any).layers)
		local weapon = sim.defs.weapons.ord_nuke
		local ground = 0
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local nuke = 0
		local leanedAt: number? = nil -- height above the ground when it first moved sideways
		local worst, steps = 0, 0
		for _ = 1, 400 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
			for _, e in c.events do
				if e.kind == "LAUNCH" then
					nuke = e.other
					ground = Layers.heightAt((sim.map :: any).layers, e.x :: number, e.z :: number)
				end
			end
			if nuke ~= 0 and c.projSlot[nuke] then
				local vx, vz = c.pvx[nuke], c.pvz[nuke]
				if leanedAt == nil and (vx ~= 0 or vz ~= 0) then
					leanedAt = c.py[nuke] - c.pvy[nuke] / 15 - ground
				end
				local p = view.projectiles[nuke]
				if p then
					steps += 1
					worst = math.max(worst, math.sqrt((p.x - c.px[nuke]) ^ 2 + (p.y - c.py[nuke]) ^ 2 + (p.z - c.pz[nuke]) ^ 2))
				end
			elseif nuke ~= 0 then
				break
			end
		end
		assert(leanedAt, "it leaned over")
		print(string.format("    boost to %.1f studs above the ground, client copy within %.2f studs over %d ticks", leanedAt, worst, steps))
		t.expect(math.abs(leanedAt - weapon.climbHeight :: number) <= (weapon.projectileSpeed :: number) / 15 + 1, `straight up to ~{weapon.climbHeight} studs (leaned at {leanedAt})`)
		t.expect(steps > 100, "the far-away client flew it")
		t.expect(worst < 1, `the client's copy stays within a stud ({worst})`)
	end)

	t.test("every player is warned of a launch and gets the warhead, wherever its camera is", function()
		local sim, silo = range(2)
		local g = (sim.map :: any).grid
		camera(sim, 1, -800, 0) -- over the silo
		camera(sim, 2, 0, -800) -- far from both ends
		local views = { Client.new(g), Client.new(g) }
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		for _ = 1, 30 do
			Sim.step(sim)
			for pid = 1, 2 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
		end
		for pid = 1, 2 do
			t.equal(#views[pid].warnings, 1, `player {pid} got the launch warning`)
			local warn = views[pid].warnings[1]
			t.expect(math.abs(warn.x + 800) < 8 and math.abs(warn.z) < 8, "at the silo")
		end
		for pid = 1, 2 do
			t.expect(views[pid].projectiles[views[pid].warnings[1].projId] ~= nil, `player {pid} has the warhead in flight`)
		end
	end)

	t.test("radar SAM sites shoot down a nuke in their radar range before anything else", function()
		local sim, silo, units = range(3)
		local w = sim.world
		local c = sim.combat
		local sites = { Spawn.unit(sim, "chs_wyvern", 2, TARGET_X - 60, TARGET_Z - 60, 0), Spawn.unit(sim, "chs_wyvern", 2, TARGET_X + 60, TARGET_Z - 60, 0) }
		-- an enemy helicopter hovering over the sites: they shoot at it until the nuke comes
		local heli = Spawn.unit(sim, "ord_guardian", 1, TARGET_X, TARGET_Z - 150, 0)
		World.setHealth(w, heli, 1e9)
		World.setMoveState(w, heli, World.MoveState.HOLD_POSITION)
		w.fireState[heli] = World.FireState.HOLD_FIRE
		sim.ew.chaff[heli] = 0
		local g = (sim.map :: any).grid
		camera(sim, 2, TARGET_X, TARGET_Z - 200)
		local view = Client.new(g)
		for _ = 1, 30 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
		end
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local nuke, interceptors, intercepted, detonated = 0, 0, false, false
		local chased = 0
		for _ = 1, 400 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
			for _, e in c.events do
				if e.kind == "LAUNCH" then
					nuke = e.other
				elseif e.kind == "SPAWN_PROJ" and table.find(sites, e.unit) and nuke ~= 0 then
					interceptors += 1
					t.equal(c.pTargetProj[e.other], nuke, "fired at the nuke, not the helicopter")
				elseif e.kind == "INTERCEPTED" and e.other == nuke then
					intercepted = true
				elseif e.kind == "IMPACT" and e.other == nuke then
					detonated = true
				end
			end
			for _, p in view.projectiles do
				if p.targetProj == nuke and nuke ~= 0 then
					chased += 1
				end
			end
			if intercepted or detonated then
				break
			end
		end
		print(`    interception: {interceptors} interceptors, intercepted {intercepted}`)
		t.expect(interceptors >= 1, "the sites fired interceptors")
		t.expect(intercepted and not detonated, "the nuke was destroyed in flight")
		t.expect(chased > 0, "the client got the interceptors with the nuke as their target")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		for _, id in sites do
			t.equal(w.health[id], sim.defs.units.chs_wyvern.health, "no blast: the sites are untouched")
		end
		t.equal(w.health[units.enemy], sim.defs.units.chs_ravager.health, "nor the tank at the target")
	end)

	t.test("with empty stockpiles the sites can't stop it", function()
		local sim, silo = range(3)
		local w = sim.world
		local site = Spawn.unit(sim, "chs_wyvern", 2, TARGET_X - 60, TARGET_Z - 60, 0)
		w.wStock[World.slotKey(site, 1)] = 0
		local acc = sim.eco.accounts[2]
		acc.supply.stored, acc.power.stored = 0, 0
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local fired = 0
		for _ = 1, 400 do
			Sim.step(sim)
			fired += #eventsOf(sim, "SPAWN_PROJ") - #eventsOf(sim, "LAUNCH")
			if w.slot[site] == nil then
				break
			end
		end
		t.equal(fired, 0, "nothing to fire")
		t.equal(w.slot[site], nil, "the site went with the blast")
	end)

	t.test("nuke matches are deterministic", function()
		local function run(): number
			local sim, silo = range(5)
			Spawn.unit(sim, "chs_wyvern", 2, TARGET_X - 60, TARGET_Z - 60, 0)
			attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
			for _ = 1, 300 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)
end
