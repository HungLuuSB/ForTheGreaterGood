--!strict
-- Strategic missiles (S-48, client request 26): nuke silos launch on an
-- attack-ground order only; anti-nukes intercept them (S-111: radar SAMs
-- shoot aircraft only).
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
		local full = w.wStock[key]
		t.equal(full, 10, "a placed silo starts with its 10 warheads (S-200)")
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
		t.equal(w.wStock[key], full - 1, "it spent a warhead")
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

	t.test("an anti-nuke shoots the nuke down with one interceptor; a radar SAM site beside it ignores the nuke (S-111)", function()
		local sim, silo, units = range(3)
		local w = sim.world
		local c = sim.combat
		local antinuke = Spawn.unit(sim, "chs_cerberus", 2, TARGET_X - 60, TARGET_Z - 60, 0)
		local sam = Spawn.unit(sim, "chs_wyvern", 2, TARGET_X + 60, TARGET_Z + 60, 0)
		-- an enemy helicopter hovering over the sites: the SAM shoots at it, the anti-nuke never does
		local heli = Spawn.unit(sim, "ord_guardian", 1, TARGET_X, TARGET_Z - 150, 0)
		World.setHealth(w, heli, 1e9)
		World.setMoveState(w, heli, World.MoveState.HOLD_POSITION)
		w.fireState[heli] = World.FireState.HOLD_FIRE
		sim.ew.chaff[heli] = 0
		local g = (sim.map :: any).grid
		camera(sim, 2, TARGET_X, TARGET_Z - 200)
		local view = Client.new(g)
		local antinukeShots = 0
		for _ = 1, 30 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
			antinukeShots += #(function()
				local out = {}
				for _, e in eventsOf(sim, "SPAWN_PROJ") do
					if e.unit == antinuke then
						table.insert(out, e)
					end
				end
				return out
			end)()
		end
		t.equal(antinukeShots, 0, "the anti-nuke doesn't fire at the helicopter")
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local nuke, interceptors, samAtNuke, intercepted, detonated = 0, 0, 0, false, false
		local chased = 0
		for _ = 1, 400 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
			for _, e in c.events do
				if e.kind == "LAUNCH" then
					nuke = e.other
				elseif e.kind == "SPAWN_PROJ" and e.unit == antinuke then
					interceptors += 1
					t.equal(c.pTargetProj[e.other], nuke, "fired at the nuke")
				elseif e.kind == "SPAWN_PROJ" and e.unit == sam and nuke ~= 0 and c.pTargetProj[e.other] == nuke then
					samAtNuke += 1
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
		print(`    interception: {interceptors} interceptor(s), intercepted {intercepted}`)
		t.equal(interceptors, 1, "one interceptor for one nuke")
		t.equal(samAtNuke, 0, "the radar SAM site never fired at the nuke")
		t.expect(intercepted and not detonated, "the nuke was destroyed in flight")
		t.expect(chased > 0, "the client got the interceptor with the nuke as its target")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		t.equal(w.health[antinuke], sim.defs.units.chs_cerberus.health, "no blast: the sites are untouched")
		t.equal(w.health[units.enemy], sim.defs.units.chs_ravager.health, "nor the tank at the target")
	end)

	t.test("radar SAM sites alone can't stop a nuke (S-111)", function()
		local sim, silo = range(4)
		for _, d in { { -60, -60 }, { 60, -60 }, { -60, 60 }, { 60, 60 } } do
			Spawn.unit(sim, "chs_wyvern", 2, TARGET_X + d[1], TARGET_Z + d[2], 0)
		end
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		local detonated, fired = false, 0
		for _ = 1, 400 do
			Sim.step(sim)
			fired += #eventsOf(sim, "SPAWN_PROJ") - #eventsOf(sim, "LAUNCH")
			for _, e in eventsOf(sim, "LAUNCH") do
				local _ = e
			end
			if #eventsOf(sim, "INTERCEPTED") > 0 then
				break
			end
			for _, e in eventsOf(sim, "IMPACT") do
				if sim.combat.pWeapon[e.other] == nil then
					local _ = e
				end
			end
			if #eventsOf(sim, "BLAST") > 0 or #eventsOf(sim, "DEATH") > 0 then
				detonated = true
				break
			end
		end
		t.equal(fired, 0, "four radar SAM sites fire nothing at it")
		t.expect(detonated, "it lands")
	end)

	t.test("a mobile anti-nuke intercepts only while stopped (S-111)", function()
		for _, moving in { false, true } do
			local sim, silo = range(6)
			local w = sim.world
			local truck = Spawn.unit(sim, "chs_chimera", 2, TARGET_X - 80, TARGET_Z - 80, 0)
			if moving then
				-- driving back and forth under the nuke's path
				local cell, ox, oz = (sim.map :: any).grid:encode(TARGET_X - 80, TARGET_Z + 600)
				submit(sim, 2, { cmdType = CT.PATROL, flags = 0, unitIds = { truck }, cell = cell, offX = ox, offZ = oz })
			end
			for _ = 1, 15 do
				Sim.step(sim)
			end
			attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
			local fired, intercepted = 0, false
			for _ = 1, 400 do
				Sim.step(sim)
				for _, e in eventsOf(sim, "SPAWN_PROJ") do
					if e.unit == truck then
						fired += 1
					end
				end
				if #eventsOf(sim, "INTERCEPTED") > 0 then
					intercepted = true
					break
				end
				if w.slot[truck] == nil then
					break
				end
			end
			if moving then
				t.equal(fired, 0, "on the move it can't launch")
				t.equal(intercepted, false)
			else
				t.equal(fired, 1, "stopped, one interceptor")
				t.equal(intercepted, true, "and the nuke is down")
			end
		end
	end)

	t.test("cover is by aim point; two nukes at one spot overwhelm one anti-nuke (client request 46)", function()
		-- the site under the flight path, the aim point 1,100 studs past it: outside the 1,000 cover
		local sim, silo = range(7)
		local site = Spawn.unit(sim, "chs_cerberus", 2, -100, TARGET_Z, 0)
		local stock = World.slotKey(site, 1)
		attackGround(sim, 1, { silo }, 1000, TARGET_Z) -- (flat:256 spans ±1,024)
		local fired = 0
		for _ = 1, 400 do
			Sim.step(sim)
			for _, e in eventsOf(sim, "SPAWN_PROJ") do
				if e.unit == site then
					fired += 1
				end
			end
		end
		t.equal(fired, 0, "a nuke aimed outside the cover isn't engaged")
		-- two silos fire at the site's own spot the same tick
		local sim2, silo2 = range(8)
		local silo3 = Spawn.unit(sim2, "ord_reckoning", 1, -800, 300, 0)
		local site2 = Spawn.unit(sim2, "chs_cerberus", 2, TARGET_X, TARGET_Z, 0)
		attackGround(sim2, 1, { silo2 }, TARGET_X, TARGET_Z)
		attackGround(sim2, 1, { silo3 }, TARGET_X + 10, TARGET_Z)
		local intercepted, landed = 0, 0
		for _ = 1, 400 do
			Sim.step(sim2)
			intercepted += #eventsOf(sim2, "INTERCEPTED")
			landed += #eventsOf(sim2, "BLAST")
			if sim2.world.slot[site2] == nil then
				break
			end
		end
		t.equal(intercepted, 1, "one shot down")
		t.equal(sim2.world.slot[site2], nil, "the other got through during the cooldown")
		local _ = stock
	end)

	t.test("anti-nukes take turns: two sites split two nukes the same tick, one interceptor each (S-201, the user)", function()
		local sim, silo = range(8)
		local silo2 = Spawn.unit(sim, "ord_reckoning", 1, -800, 300, 0)
		local siteA = Spawn.unit(sim, "chs_cerberus", 2, TARGET_X, TARGET_Z - 60, 0)
		local siteB = Spawn.unit(sim, "chs_cerberus", 2, TARGET_X, TARGET_Z + 60, 0)
		attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
		attackGround(sim, 1, { silo2 }, TARGET_X + 10, TARGET_Z)
		local c = sim.combat
		local chased: { number } = {}
		local intercepted, blasts = 0, 0
		for _ = 1, 500 do
			Sim.step(sim)
			for _, e in eventsOf(sim, "SPAWN_PROJ") do
				if e.unit == siteA or e.unit == siteB then
					table.insert(chased, c.pTargetProj[e.other])
				end
			end
			intercepted += #eventsOf(sim, "INTERCEPTED")
			blasts += #eventsOf(sim, "BLAST")
		end
		t.expect(#chased >= 2, `{#chased} interceptors`)
		t.expect(chased[1] ~= chased[2], "the first two went after different warheads")
		t.equal(#chased, 2, "one interceptor per warhead, none wasted")
		t.equal(intercepted, 2, "both shot down")
		t.equal(blasts, 0, "nothing landed")
	end)

	t.test("with an empty stockpile the anti-nuke can't stop it", function()
		local sim, silo = range(3)
		local w = sim.world
		local site = Spawn.unit(sim, "chs_cerberus", 2, TARGET_X - 60, TARGET_Z - 60, 0)
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
			Spawn.unit(sim, "chs_cerberus", 2, TARGET_X - 60, TARGET_Z - 60, 0)
			attackGround(sim, 1, { silo }, TARGET_X, TARGET_Z)
			for _ = 1, 300 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)
end
