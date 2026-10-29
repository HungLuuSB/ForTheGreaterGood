--!strict
-- The evening playtest's feedback (S-194): self-destruct (G13), aircraft
-- that retreat to a rearm pad to heal instead of rearming ammo (G17), and
-- the Commanders' laser and D-Gun (G5).
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Air = require("../Sim/Air")
local Combat = require("../Sim/Combat/Combat")
local SelfDestruct = require("../Sim/SelfDestruct")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

local function wrecks(sim: Sim.Sim): number
	return #sim.combat.wreckIds
end

return function(t: RunAll.Context)
	t.test("self-destruct: a 6 s countdown, then no wreck and a bigger blast than a normal death; 0 stops it (G13)", function()
		-- the damage a death blast does to a tank 20 studs away
		local function blastDamage(selfDestruct: boolean): (number, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
			local w = sim.world
			local tank = Spawn.unit(sim, "ord_paladin", 1, 0, 0)
			local near = Spawn.unit(sim, "chs_goliath", 2, 20, 0)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			World.setFireState(w, near, World.FireState.HOLD_FIRE)
			local before = w.health[near]
			if selfDestruct then
				submit(sim, 1, { cmdType = CT.SELF_DESTRUCT, flags = 0, unitIds = { tank }, value = 1 })
				steps(sim, 2)
				t.equal(SelfDestruct.secondsLeft(sim, tank), 6, "6 seconds left")
				steps(sim, 15 * 6 - 3)
				t.expect(w.slot[tank] ~= nil, "still there just before")
				steps(sim, 3)
			else
				Combat.queueDamage(sim.combat, tank, w.health[tank] * 1.2, 0) -- a normal kill (overkill 0.2: a wreck)
				steps(sim, 1)
			end
			t.equal(w.slot[tank], nil, "it died")
			steps(sim, 2) -- (the blast lands the next tick)
			return before - (w.health[near] or 0), wrecks(sim)
		end
		local normal, normalWrecks = blastDamage(false)
		local sd, sdWrecks = blastDamage(true)
		t.expect(normalWrecks == 1, `a normal death leaves a wreck ({normalWrecks})`)
		t.equal(sdWrecks, 0, "a self-destruct leaves none")
		t.expect(sd > normal * 1.2, `the self-destruct's blast did more ({sd} against {normal})`)

		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		submit(sim, 1, { cmdType = CT.SELF_DESTRUCT, flags = 0, unitIds = { tank }, value = 1 })
		steps(sim, 30)
		submit(sim, 1, { cmdType = CT.SELF_DESTRUCT, flags = 0, unitIds = { tank }, value = 0 })
		steps(sim, 15 * 8)
		t.expect(sim.world.slot[tank] ~= nil, "a stopped countdown doesn't go off")
		t.equal(SelfDestruct.secondsLeft(sim, tank), nil)
	end)

	t.test("aircraft carry no ammo; hurt below their retreat setting they heal on a rearm pad, then fly back (G17)", function()
		for _, d in Sim.new({ seed = 1, players = PLAYERS }).defs.unitByIndex do
			t.equal(d.ammo, nil, `{d.id}: no ammo`)
		end
		local function run(retreat: number): (boolean, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			Spawn.unit(sim, "ord_airpad", 1, -200, 0)
			local jet = Spawn.unit(sim, "ord_falcon", 1, 200, 0)
			w.fireState[jet] = World.FireState.HOLD_FIRE
			submit(sim, 1, { cmdType = CT.SET_RETREAT, flags = 0, unitIds = { jet }, value = retreat })
			steps(sim, 2)
			World.setHealth(w, jet, sim.defs.units.ord_falcon.health * 0.25)
			local landed, healed = false, 0
			for i = 1, 15 * 60 do
				Sim.step(sim)
				if sim.air.phase[jet] == "rearm" then
					landed = true
				end
				if landed and sim.air.phase[jet] == "fly" and healed == 0 then
					healed = i
				end
			end
			t.expect(not landed or w.health[jet] >= sim.defs.units.ord_falcon.health - 1e-6, "healed to full before taking off")
			return landed, healed
		end
		local landed, healedAt = run(Schema.RetreatAt.AT_30)
		t.expect(landed and healedAt > 0, "at 25% health with a 30% setting it landed, healed and took off again")
		t.expect(not (run(Schema.RetreatAt.NEVER)), "set to never, it stays out")
		t.equal(Air.RETREAT_DEFAULT, Schema.RetreatAt.AT_30, "new aircraft retreat at 30%")
	end)

	t.test("the D-Gun fires at a point up a slope; only the bolt's end is an IMPACT with its ID (client-B's findings)", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "map:supreme_strait" })
		local w = sim.world
		local com = Spawn.unit(sim, "ord_sovereign", 1, -1076, 52, math.pi / 2)
		local tank = Spawn.unit(sim, "chs_goliath", 2, -1020, 52)
		World.setFireState(w, com, World.FireState.HOLD_FIRE)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local acc = sim.eco.accounts[1]
		acc.power.stored = acc.power.storage
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(-980, 52)
		submit(sim, 1, { cmdType = CT.DGUN, flags = 0, unitIds = { com }, cell = cell, offX = ox, offZ = oz })
		local bolt, ends = nil, 0
		for _ = 1, 15 * 6 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == com then
					bolt = e.other
				elseif e.kind == "IMPACT" and bolt ~= nil and e.other == bolt then
					ends += 1
				end
			end
		end
		t.expect(bolt ~= nil or sim.orders.dgunX[com] == nil, "it fired")
		t.equal(sim.orders.dgunX[com], nil, "the order is done")
		t.equal(w.slot[tank], nil, "the tank on its path is gone")
		t.expect(ends <= 1, `one ending IMPACT for the bolt ({ends})`)
	end)

	t.test("a turret locked on its target holds its aim while the hull turns (G9)", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local target = Spawn.unit(sim, "chs_ravager", 2, 60, 0)
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE) -- (aims, doesn't kill it)
		local o = sim.orders
		o.manual[tank], o.manualGen[tank] = target, w.gen[target] -- a manual target: aimed at even on hold fire
		steps(sim, 45) -- on target
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(-60, -80) -- a hard turn away
		submit(sim, 1, { cmdType = CT.MOVE, flags = 0, unitIds = { tank }, cell = cell, offX = ox, offZ = oz })
		local worst, turned = 0, 0
		local h0 = w.heading[tank]
		for _ = 1, 30 do
			Sim.step(sim)
			if w.slot[target] == nil then
				break
			end
			local want = math.atan2(w.posX[target] - w.posX[tank], w.posZ[target] - w.posZ[tank])
			local err = math.abs((w.heading[tank] + w.wYaw[tank * 8] - want + math.pi) % (2 * math.pi) - math.pi)
			worst = math.max(worst, err)
			turned = math.max(turned, math.abs((w.heading[tank] - h0 + math.pi) % (2 * math.pi) - math.pi))
		end
		t.expect(turned > math.rad(60), `the hull turned ({math.deg(turned)}°)`)
		t.expect(worst < math.rad(6), `the turret stayed on target ({math.deg(worst)}° off at worst)`)
	end)

	t.test("the D-Gun fires only on a DGUN order: a bolt that destroys a line of tanks with no wrecks and halves a Commander (G5)", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local com = Spawn.unit(sim, "ord_sovereign", 1, -100, 0, math.pi / 2)
		local tanks = {}
		for i = 1, 3 do
			local id = Spawn.unit(sim, "chs_goliath", 2, -100 + i * 18, (i - 2) * 3) -- inside the bolt's 80 studs (S-203)
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			table.insert(tanks, id)
		end
		local enemyCom = Spawn.unit(sim, "chs_warlord", 2, -30, 0)
		local beside = Spawn.unit(sim, "chs_goliath", 2, -50, 60) -- off the bolt's path
		World.setFireState(w, enemyCom, World.FireState.HOLD_FIRE)
		World.setFireState(w, beside, World.FireState.HOLD_FIRE)
		World.setFireState(w, com, World.FireState.HOLD_FIRE) -- (the laser holds; the D-Gun is ordered)
		local acc = sim.eco.accounts[1]
		acc.power.stored = acc.power.storage
		steps(sim, 30)
		t.equal(#sim.combat.proj, 0, "no bolt without an order")
		local g = (sim.map :: any).grid
		-- both players watch, so NetOut encodes the bolt's events (a
		-- pass-through IMPACT with projId 0 once broke the encoder)
		for p = 1, 2 do
			submit(sim, p, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 95, maxZ = 95 })
		end
		local cell, ox, oz = g:encode(-25, 0)
		submit(sim, 1, { cmdType = CT.DGUN, flags = 0, unitIds = { com }, cell = cell, offX = ox, offZ = oz })
		local comHealth = w.health[enemyCom]
		steps(sim, 15 * 5)
		for _, id in tanks do
			t.equal(w.slot[id], nil, `tank {id} destroyed`)
		end
		t.equal(wrecks(sim), 0, "no wrecks")
		t.expect(w.slot[enemyCom] ~= nil, "the enemy Commander survives")
		local lost = comHealth - w.health[enemyCom]
		-- (half from the bolt; the tanks' death blasts beside it add some)
		t.expect(lost >= sim.defs.units.chs_warlord.health * Combat.BOLT_COMMANDER - 1, `the Commander lost half its health or more ({lost})`)
		t.expect(w.slot[beside] ~= nil and w.health[beside] == sim.defs.units.chs_goliath.health, "a tank off its path is untouched")
		t.equal(sim.orders.dgunX[com], nil, "one bolt per order")
	end)
end
