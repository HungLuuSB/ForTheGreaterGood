--!strict
-- The S-157 towers on the client (C-198): lasers draw in their weapon's
-- colour; the Beamer's beam grows with time on one target, as the server
-- ramps its damage; multi-barrel slots fire from each muzzle in turn and a
-- drum turns one barrel per shot. Through the real server.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local PieceAnim = require("../../src/client/Core/PieceAnim")
local Default = require("../../src/client/Core/PieceScripts/Default")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15

local function duel(towerDef: string, team: number, enemyDef: string): (any, any, any, number)
	local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
	local tower = Spawn.unit(sim, towerDef, team, 0, 0, 0)
	local enemy = Spawn.unit(sim, enemyDef, 3 - team, 70, 0, 0)
	ServerWorld.setHealth(sim.world, enemy, sim.world.health[enemy] * 50)
	sim.world.fireState[enemy] = ServerWorld.FireState.HOLD_FIRE
	local world = World.new(sim.defs)
	NetOut.join(sim, team)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, team, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	return sim, world, Effects.new(), tower
end

return function(t: any)
	t.test("a Sentry's and a Guard's lasers are red, an Overwatch's green, whole lines", function()
		for _, case in { { "ord_sentry_tower", 1, "chs_ravager", { 255, 40, 40 } }, { "chs_guard", 2, "ord_lancer", { 255, 40, 40 } }, { "ord_overwatch", 1, "chs_ravager", { 60, 255, 90 } } } do
			local sim, world, fx = duel(case[1], case[2], case[3])
			local seen = nil
			for tick = 1, 15 * 6 do
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[case[2]].outbox, tick * DT)
				Effects.update(fx, world, tick, tick * DT, 0, 0)
				table.clear(world.died)
				for _, tr in fx.tracers do
					if tr.laser then
						seen = tr.laser
					end
				end
				if seen then
					break
				end
			end
			t.expect(seen ~= nil, `{case[1]} fired a laser`)
			t.deepEqual(seen, case[4], `{case[1]}'s colour`)
		end
	end)

	t.test("the Beamer's beam grows over its ramp on one target", function()
		local sim, world, fx = duel("ord_beamer", 1, "chs_ravager")
		local first, last = nil, nil
		for tick = 1, 15 * 6 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			for _, tr in fx.tracers do
				if tr.ramp then
					first = first or tr.ramp
					last = tr.ramp
				end
			end
		end
		print(`    Beamer intensity {first} → {last}`)
		t.expect(first ~= nil and first < 0.2, "starts low")
		t.expect(last ~= nil and last > 0.9, "reaches full after its ramp")
		-- a pause longer than a shot's gap starts it over
		local weapon = sim.defs.weapons.ord_beamer_beam
		local f = Effects.new()
		local k = 0
		for i = 0, 10 do
			k = Effects.ramp(f, 1, weapon, i * 0.2) -- a shot every 0.2 s for 2 s
		end
		t.expect(k > 0.45 and k < 0.55, `two seconds on one target: half way ({k})`)
		t.expect(Effects.ramp(f, 1, weapon, 3) < 0.05, "after a second's pause: from the start")
	end)

	t.test("a triple barrel fires each barrel in turn and the drum turns a barrel per shot", function()
		local defs = (Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:32", scenario = "empty" })).defs
		local def = defs.units.chs_geryon
		local s = PieceAnim.new(defs.weaponByIndex)
		local u = PieceAnim.add(s, 1, def, Default)
		for _ = 1, 3 do
			PieceAnim.call(u, "FireWeapon", 1)
			for _ = 1, 30 do
				PieceAnim.step(s, 1 / 60)
			end
		end
		local drum = u.pieces[def.weapons[1].drumPiece]
		t.expect(drum ~= nil, "the drum piece turned")
		local z = drum.rot[3]
		t.expect(math.abs(((z + math.pi) % (2 * math.pi)) - math.pi) < 0.05, `three shots: a full turn ({math.deg(z)}°)`)
		t.equal(u.shotsFired[1], 3)
		for i = 1, 3 do
			t.expect(u.pieces["barrel" .. i] ~= nil, `barrel{i} recoiled`)
		end
	end)
end
