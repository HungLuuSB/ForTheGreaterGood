--!strict
-- Deaths and wrecks (guide 14.6, C-34): a death that leaves a wreck shakes
-- and then shows the wreck; a big overkill (no wreck) flings 1–3 jointed
-- pieces up and away, the same way each time for the same unit; and every
-- death of a real duel gets the plan its DEATH event calls for.

local Commands = require("../../src/client/Core/Commands")
local Deaths = require("../../src/client/Core/Deaths")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Defs = require("@shared/Defs/Defs")

local DT = 1 / 15
local defs = Defs.load()

return function(t: any)
	t.test("a wreck means a shake; no wreck means flung pieces", function()
		local def = defs.units.chs_goliath
		local shake = Deaths.plan(4, def, 60, 17)
		t.equal(shake.kind, "shake")
		t.expect(shake.wreck and #shake.pieces == 0)
		local fling = Deaths.plan(4, def, 230, 0)
		t.equal(fling.kind, "fling")
		t.expect(not fling.wreck, "nothing left")
		t.expect(#fling.pieces >= 1 and #fling.pieces <= Deaths.MAX_PIECES, `1–3 pieces ({#fling.pieces})`)
		local seen = {}
		for _, p in fling.pieces do
			t.expect(table.find(def.pieces, p.name) ~= nil and p.name ~= "base" and p.name ~= "muzzle", `{p.name} is a jointed piece`)
			t.expect(not seen[p.name], "each piece once")
			seen[p.name] = true
			-- up, then back down past where it started within the animation
			local _, yMid = Deaths.pieceAt(p, Deaths.FLING_SECONDS / 2)
			local _, yEnd = Deaths.pieceAt(p, Deaths.FLING_SECONDS)
			t.expect(yMid > 3, "flies up")
			t.expect(yEnd < yMid, "and falls")
		end
		local again = Deaths.plan(4, def, 230, 0)
		t.deepEqual(again, fling, "the same death plays the same way")
		local sx, sz = Deaths.shakeAt(4, 0)
		local ex, ez = Deaths.shakeAt(4, Deaths.SHAKE_SECONDS)
		t.expect(math.abs(sx) + math.abs(sz) > 0 and ex == 0 and ez == 0, "the shake eases out")
	end)

	t.test("muzzles are never flung, prefixed ones included", function()
		-- Bulwark's laser muzzles are attachments too (models-C's Blockout rule)
		local def = { pieces = { "base", "turret", "muzzle", "laser_muzzle1", "laser_muzzle2", "laser_muzzle3", "laser_drum" } }
		for id = 1, 40 do
			for _, p in Deaths.plan(id, def, 230, 0).pieces do
				t.expect(p.name == "turret" or p.name == "laser_drum", `{p.name} is a jointed piece`)
			end
		end
	end)

	t.test("every death in a duel gets the plan its DEATH event calls for", function()
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		local deaths, shakes, flings = 0, 0, 0
		for tick = 1, 400 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, d in world.died do
				deaths += 1
				local def = sim.defs.unitByIndex[d.defIndex :: number]
				local plan = Deaths.plan(d.id, def, d.severity, d.wreckId)
				-- the server leaves a wreck only for an overkill of at most half the max health
				t.equal(plan.wreck, d.wreckId ~= 0)
				if d.wreckId ~= 0 then
					t.expect(d.severity <= 0.5 * 255 + 1, `a wreck only after a small overkill ({d.severity})`)
					shakes += 1
				else
					flings += 1
				end
			end
			table.clear(world.died)
		end
		print(string.format("    duel: %d deaths, %d shakes into wrecks, %d flung apart", deaths, shakes, flings))
		t.expect(deaths > 5, "plenty of deaths")
	end)

	t.test("heavy T3 wrecks lie down: walkers on a side, the rest slumped; others stand (S-234, C-286)", function()
		for id in Deaths.FALLEN do
			t.expect(defs.units[id] ~= nil, `{id} is a unit`)
		end
		local titan = Deaths.fall(5, defs.units.ord_titan) :: Deaths.Fall
		t.expect(titan ~= nil and math.abs(titan.roll) == Deaths.TOPPLE and titan.center, "the Titan topples onto a side")
		local monolith = Deaths.fall(5, defs.units.ord_monolith) :: Deaths.Fall
		t.expect(monolith ~= nil and math.abs(monolith.roll) <= Deaths.SLUMP_TILT and monolith.sinkShare == Deaths.SPIDER_SINK, "a spider slumps, legs folded under")
		local typhon = Deaths.fall(5, defs.units.chs_typhon) :: Deaths.Fall
		t.expect(typhon ~= nil and math.abs(typhon.roll) <= Deaths.SLUMP_TILT and typhon.sinkShare == 0 and not typhon.center, "a hovertank slumps flat")
		t.deepEqual(Deaths.fall(5, defs.units.ord_titan), titan, "the same wreck lies the same way on every client")
		t.expect(Deaths.fall(5, defs.units.ord_lancer) == nil, "a Lancer's wreck stands")
		t.expect(Deaths.fall(5, defs.units.ord_titan, true) == nil, "a fallen-hulk mesh lies down by itself")
		t.deepEqual(Deaths.fall(5, defs.units.ord_titan, false, 26, 12, 20), titan, "a tall, narrow walker topples onto a side")
		local front = Deaths.fall(5, defs.units.ord_titan, false, 26, 26, 20) :: Deaths.Fall
		t.expect(math.abs(front.pitch) == Deaths.TOPPLE and math.abs(front.roll) < Deaths.TOPPLE and front.center, "a broad-shouldered walker falls onto its front or back (20 studs high, not 26)")
		local squat = Deaths.fall(5, defs.units.chs_colossus, false, 9, 28, 29) :: Deaths.Fall
		t.expect(math.abs(squat.roll) <= Deaths.SLUMP_TILT and not squat.center, "a walker wider than tall slumps instead of standing on its edge")
		local sides = {}
		for id = 1, 40 do
			sides[math.sign((Deaths.fall(id, defs.units.chs_colossus) :: Deaths.Fall).roll)] = true
		end
		t.expect(sides[1] and sides[-1], "walkers fall to either side")
		-- the slope under it: a 30° ramp rising toward +x
		local nx, ny, nz = Deaths.groundNormal(function(x: number, _z: number): number
			return x * math.tan(math.rad(30))
		end, 0, 0, 6)
		t.expect(math.abs(math.deg(math.acos(ny)) - 30) < 1e-6 and nx < 0 and math.abs(nz) < 1e-9, `the normal leans 30° away from the rise ({nx}, {ny}, {nz})`)
		local _, cy = Deaths.groundNormal(function(x: number, _z: number): number
			return x * 3
		end, 0, 0, 6)
		t.expect(math.abs(math.acos(cy) - Deaths.MAX_LEAN) < 1e-9, `on a 72° cliff it leans only MAX_LEAN ({math.deg(math.acos(cy))}°)`)
	end)

	local function flat(_x: number, _z: number): number
		return 10
	end

	t.test("aircraft fall out of the sky: jets dive ahead and roll, helicopters spin down, both end on the ground (C-48)", function()
		local jet = Deaths.crash({ id = 7, x = 0, z = 0, heading = math.pi / 2, alt = 110, vx = 200, vz = 0 }, defs.units.ord_falcon, flat) :: Deaths.Crash
		t.expect(jet ~= nil, "a jet in the air falls")
		t.expect(jet.duration > 1 and jet.duration < 4, `it falls for a couple of seconds ({jet.duration})`)
		t.expect(math.abs(jet.ey - 10) < 1e-6 and jet.ex > 100, `it hits the ground well ahead ({jet.ex})`)
		local x0, y0, z0 = Deaths.crashAt(jet, 0)
		t.expect(x0 == 0 and z0 == 0 and math.abs(y0 - 120) < 1e-6, "it starts where it died, at its altitude")
		local _, yEnd, _, _, pitch, roll = Deaths.crashAt(jet, jet.duration)
		t.expect(math.abs(yEnd - 10) < 0.05, "it ends on the ground")
		-- then it sinks out of sight while its smoke fades (C-52)
		local _, yLater = Deaths.crashAt(jet, jet.duration + 1)
		t.expect(yLater < 10 - 5, `it goes on falling under the ground ({yLater})`)
		t.expect(pitch < -0.5 and math.abs(roll) > 1, `nose down and rolling at the end (pitch {pitch}, roll {roll})`)
		local again = Deaths.crash({ id = 7, x = 0, z = 0, heading = math.pi / 2, alt = 110, vx = 200, vz = 0 }, defs.units.ord_falcon, flat) :: Deaths.Crash
		t.equal(again.duration, jet.duration)
		t.equal(again.roll, jet.roll)

		local heli = Deaths.crash({ id = 9, x = 50, z = 50, heading = 0, alt = 40, vx = 0, vz = 20 }, defs.units.chs_wasp, flat) :: Deaths.Crash
		t.expect(heli ~= nil and heli.heli, "a helicopter in the air falls")
		local _, _, _, h0 = Deaths.crashAt(heli, 0)
		local _, _, _, h1 = Deaths.crashAt(heli, heli.duration)
		t.expect(math.abs(h1 - h0) > 3, `it spins on the way down ({h1 - h0} radians)`)
		t.expect(math.sqrt((heli.ex - 50) ^ 2 + (heli.ez - 50) ^ 2) < 20, "it comes down close to where it died")

		t.expect(Deaths.crash({ id = 3, x = 0, z = 0, heading = 0, alt = 0, vx = 0, vz = 0 }, defs.units.ord_lancer, flat) == nil, "ground units don't fall")
		t.expect(Deaths.crash({ id = 4, x = 0, z = 0, heading = 0, alt = 1, vx = 0, vz = 0 }, defs.units.ord_falcon, flat) == nil, "a landed aircraft dies like a ground unit")
	end)

	t.test("a falling aircraft explodes where and when it hits the ground, not where it died (C-48)", function()
		local world = World.new(defs)
		local fx = Effects.new()
		local defIndex = table.find(defs.unitByIndex, defs.units.ord_falcon)
		local death = { id = 12, defIndex = defIndex, team = 1, x = 0, z = 0, heading = 0, severity = 50, wreckId = 3, tick = 1, alt = 110, vx = 0, vz = 180 }
		table.insert(world.died, death :: any)
		Effects.update(fx, world, 2, 0, 0, 0)
		table.clear(world.died)
		local crash = Deaths.crash(death, defs.units.ord_falcon, function(x: number, z: number): number
			return World.groundY(world, x, z)
		end) :: Deaths.Crash
		local function deathBursts(): { any }
			local out = {}
			for _, b in fx.bursts do
				if b.kind == "death" then
					table.insert(out, b)
				end
			end
			return out
		end
		t.equal(#deathBursts(), 0) -- nothing yet: it is still falling
		-- the fall runs on the render clock (render tick 2 when it started)
		Effects.update(fx, world, 2 + crash.duration * 15 * 0.5, 0.1, 0, 0)
		t.equal(#deathBursts(), 0)
		Effects.update(fx, world, 2 + crash.duration * 15 + 0.1, 0.2, 0, 0)
		local bursts = deathBursts()
		t.equal(#bursts, 1)
		t.expect(math.abs(bursts[1].x - crash.ex) < 1e-6 and math.abs(bursts[1].z - crash.ez) < 1e-6, "at the crash point")
		t.expect(bursts[1].ground ~= nil and math.abs(bursts[1].ground - crash.ey) < 1e-6, "on the ground")
	end)
end
