--!strict
-- Air and naval rendering (C-31): jets bank into turns, helicopters dip
-- their nose and spin their rotors, ships sit in the water and own
-- submarines under it, and an enemy submarine reaches the client only as a
-- sonar contact (the real sim and NetOut).

local Attitude = require("../../src/client/Core/Attitude")
local Commands = require("../../src/client/Core/Commands")
local Icons = require("../../src/client/Core/Icons")
local NetIn = require("../../src/client/Core/NetIn")
local PieceAnim = require("../../src/client/Core/PieceAnim")
local Registry = require("../../src/client/Core/PieceScripts/Registry")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Blockout = require("@shared/Defs/Blockouts/Blockout")
local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local defs = Defs.load()

local function run(sim: any, world: any, from: number, n: number)
	for tick = from, from + n - 1 do
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		table.clear(world.died)
	end
end

return function(t: any)
	t.test("jets roll into their turns and level out; helicopters dip their nose with speed", function()
		local jet = defs.units.ord_falcon
		local s = Attitude.new()
		local roll = 0
		-- a left turn at the jet's full turn rate (heading rising), 2 s at 60 fps
		local h, x, z = 0, 0, 0
		for _ = 1, 120 do
			h += math.rad(jet.movement.turnRate) / 60
			x += math.sin(h) * jet.movement.maxSpeed / 60
			z += math.cos(h) * jet.movement.maxSpeed / 60
			roll = Attitude.step(s, jet, x, z, h, 1 / 60)
		end
		t.expect(roll > math.rad(40) and roll <= Attitude.JET_MAX_ROLL + 1e-9, `left turn: right side up ({math.deg(roll)}°)`)
		for _ = 1, 120 do
			x += math.sin(h) * jet.movement.maxSpeed / 60
			z += math.cos(h) * jet.movement.maxSpeed / 60
			roll = Attitude.step(s, jet, x, z, h, 1 / 60)
		end
		t.expect(math.abs(roll) < math.rad(1), "straight again: level")

		local heli = defs.units.chs_wasp
		local hs = Attitude.new()
		local hroll, hpitch = 0, 0
		x = 0
		for _ = 1, 120 do
			x += heli.movement.maxSpeed / 60
			hroll, hpitch = Attitude.step(hs, heli, x, 0, math.pi / 2, 1 / 60)
		end
		t.expect(math.abs(hpitch + Attitude.HELI_MAX_PITCH) < math.rad(0.5), `full speed: nose down {math.deg(hpitch)}°`)
		t.expect(math.abs(hroll) < 1e-6, "flying straight: no roll")
		local gs = Attitude.new()
		Attitude.step(gs, defs.units.ord_lancer, 0, 0, 0, 1 / 60)
		local groll, gpitch = Attitude.step(gs, defs.units.ord_lancer, 1, 0, 1, 1 / 60)
		t.expect(groll == 0 and gpitch == 0, "ground units stay upright")
	end)

	t.test("ships sit in the water; own submarines are drawn under it", function()
		local ship = defs.units.ord_crusader
		local sub = defs.units.ord_silence
		t.equal(Attitude.waterOffset(ship, 0, 3), -Attitude.SHIP_DRAFT)
		t.equal(Attitude.waterOffset(sub, Schema.UnitState.SUBMERGED, 3), -Attitude.SUB_VISIBLE_DEPTH - 3)
		t.equal(Attitude.waterOffset(defs.units.ord_lancer, 0, 3), 0)
	end)

	t.test("helicopter blockouts have a rotor that spins, and stops when landed", function()
		local heli = defs.units.chs_wasp
		local bp = Blockout.forDef(heli)
		t.deepEqual(Blockout.validate(bp, heli), {})
		t.expect(bp.visualPieces and table.find(bp.visualPieces, "rotor") ~= nil, "a rotor piece")
		local s = PieceAnim.new(defs.weaponByIndex)
		local world: any = World.new(defs)
		world.units[3] = { id = 3, tier = "tactical", team = 1, x = 0, z = 0, alt = 40, heading = 0, state = 0, weapon = 0, aim = {} }
		PieceAnim.add(s, 3, heli, Registry.forDef(heli))
		local function angleAfter(seconds: number): number
			local a0 = s.units[3].pieces.rotor.rot[2]
			local turned = 0
			for _ = 1, math.floor(seconds * 60) do
				PieceAnim.drive(s, world, {})
				PieceAnim.step(s, 1 / 60)
				local a1 = s.units[3].pieces.rotor.rot[2]
				turned += (a1 - a0) % (2 * math.pi)
				a0 = a1
			end
			return turned
		end
		local flying = angleAfter(1)
		t.expect(math.abs(math.deg(flying) - 1440) < 1, `flying: 4 turns a second ({math.deg(flying)}°)`)
		world.units[3].state = Schema.UnitState.LANDED
		angleAfter(5)
		t.expect(angleAfter(1) == 0, "landed: the rotor has stopped")
		world.units[3].state = 0
		angleAfter(3)
		t.expect(math.abs(math.deg(angleAfter(1)) - 1440) < 1, "took off: back to full speed")
	end)

	t.test("ew_test: helicopters fly at their replicated altitude", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "ew_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		run(sim, world, 1, 60)
		local flying = 0
		for _, u in world.units do
			local def = World.def(world, u)
			if u.tier == "tactical" and def and def.domain == "air" then
				t.expect(u.alt > 0, `{def.id} is in the air ({u.alt})`)
				flying += 1
			end
		end
		t.expect(flying >= 1, "the own helicopter is drawn")
	end)

	t.test("an enemy submarine is only ever a sonar contact; an own one arrives submerged", function()
		local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "sea:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 63, 63)))
		local ownSub = Spawn.unit(sim, "ord_silence", 1, 40, 0, 0)
		Spawn.unit(sim, "ord_crusader", 1, 0, 40, 0) -- a ship with sonar
		local enemySub = Spawn.unit(sim, "chs_lamprey", 2, 60, 60, 0)
		local sawContact, sawModel = false, false
		for tick = 1, 90 do
			run(sim, world, tick, 1)
			local e = world.units[enemySub]
			if e then
				if e.tier == "tactical" then
					sawModel = true
				elseif bit32.band(e.flags or 0, Schema.StrategicFlag.SONAR_ONLY) ~= 0 then
					sawContact = true
					t.equal(Icons.style(Icons.table(sim.defs), world, e, false).shape, "sonar", "drawn as a sonar ring")
				end
			end
		end
		t.expect(sawContact, "the enemy submarine was heard")
		t.expect(not sawModel, "and never drawn as a model")
		local own = world.units[ownSub]
		t.expect(own and own.tier == "tactical" and bit32.band(own.state, Schema.UnitState.SUBMERGED) ~= 0, "the own submarine is tactical and submerged")
	end)
end
