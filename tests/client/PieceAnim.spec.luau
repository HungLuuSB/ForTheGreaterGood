--!strict
-- Piece scripts (guide 14, C-30): the scheduler's helpers behave like BAR's
-- (turn speeds, waits, sleeps, signal masks), turrets drawn by the default
-- script stay within a tick of the server's aim in a real duel, and the
-- Juggernaut raises its arms to aim, recoils, and lowers them after the
-- restore delay.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local PieceAnim = require("../../src/client/Core/PieceAnim")
local Default = require("../../src/client/Core/PieceScripts/Default")
local Jug = require("../../src/client/Core/PieceScripts/chs_juggernaut")
local Registry = require("../../src/client/Core/PieceScripts/Registry")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local ServerWorld = require("../../src/server/Sim/World")
local Spawn = require("../../src/server/Sim/Spawn")
local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local defs = Defs.load()

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local function rotOf(s: any, id: number, piece: string, axis: number): number
	local p = s.units[id].pieces[piece]
	return if p then p.rot[axis] else 0
end

return function(t: any)
	t.test("Turn, WaitForTurn, Sleep, Move", function()
		local s = PieceAnim.new(defs.weaponByIndex)
		local log = {}
		local script = {
			Create = function(u: any)
				u:Turn("turret", "y", 90, 45) -- 2 s
				u:WaitForTurn("turret", "y")
				table.insert(log, { "turned", u.sched.now })
				u:Sleep(0.5)
				table.insert(log, { "slept", u.sched.now })
				u:Move("barrel", "z", 1, 4) -- 0.25 s
				u:WaitForMove("barrel", "z")
				table.insert(log, { "moved", u.sched.now })
			end,
		}
		PieceAnim.add(s, 1, { id = "test", weapons = {} }, script)
		for _ = 1, 200 do
			PieceAnim.step(s, 1 / 60)
		end
		t.equal(#log, 3)
		t.expect(near(log[1][2], 2, 1 / 60 + 1e-9), `turned after 2 s ({log[1][2]})`)
		t.expect(near(log[2][2] - log[1][2], 0.5, 1 / 60 + 1e-9), "slept 0.5 s")
		t.expect(near(log[3][2] - log[2][2], 0.25, 1 / 60 + 1e-9), "moved in 0.25 s")
		t.expect(near(rotOf(s, 1, "turret", 2), math.rad(90)), "the turret ends at 90°")
		t.expect(near(s.units[1].pieces.barrel.pos[3], 1), "the barrel ends 1 stud back")
		local dirty = PieceAnim.take(s)
		t.expect(#dirty == 2, "both pieces were written")
		t.equal(#PieceAnim.take(s), 0, "and only once")
	end)

	t.test("a turn takes the short way round (170° to -170° is 20°, not 340°)", function()
		local s = PieceAnim.new(defs.weaponByIndex)
		local log = {}
		local script = {
			Create = function(u: any)
				u:Turn("turret", "y", 170) -- snap
				u:Turn("turret", "y", -170, 20) -- 1 s the short way, 17 s the long way
				u:WaitForTurn("turret", "y")
				table.insert(log, u.sched.now)
			end,
		}
		PieceAnim.add(s, 1, { id = "test", weapons = {} }, script)
		for _ = 1, 120 do
			PieceAnim.step(s, 1 / 60)
		end
		t.expect(log[1] ~= nil and log[1] <= 1 + 1 / 60 + 1e-9, `done in about 1 s ({log[1]})`)
		local r = rotOf(s, 1, "turret", 2)
		local wrapped = (r + math.pi) % (2 * math.pi) - math.pi
		t.expect(near(wrapped, math.rad(-170), 1e-6), `ends at -170° ({math.deg(wrapped)})`)
	end)

	t.test("Signal kills the older threads of its mask; StartThread inherits the mask", function()
		local s = PieceAnim.new(defs.weaponByIndex)
		local finished = {}
		local function later(u: any, tag: string)
			u:Sleep(1)
			table.insert(finished, tag)
		end
		local script = {
			AimWeapon = function(u: any, _slot: number, tag: string)
				u:Signal(1)
				u:SetSignalMask(1)
				u:StartThread(later, tag)
			end,
			FireWeapon = function(u: any)
				u:StartThread(later, "fire") -- mask 0: never signalled
			end,
		}
		local u = PieceAnim.add(s, 1, { id = "test", weapons = {} }, script)
		PieceAnim.call(u, "AimWeapon", 1, "first")
		PieceAnim.step(s, 0.5)
		PieceAnim.call(u, "FireWeapon", 1)
		PieceAnim.call(u, "AimWeapon", 1, "second") -- cancels "first" (and only it)
		for _ = 1, 30 do
			PieceAnim.step(s, 0.1)
		end
		table.sort(finished)
		t.deepEqual(finished, { "fire", "second" })
	end)

	t.test("far LOD snaps turns; removing a unit ends its threads", function()
		local s = PieceAnim.new(defs.weaponByIndex)
		local reached = false
		local u = PieceAnim.add(s, 1, { id = "test", weapons = {} }, {
			Create = function(u: any)
				u:Sleep(10)
				reached = true
			end,
		})
		u.lod = "far"
		u:Turn("turret", "y", 45, 1)
		t.expect(near(rotOf(s, 1, "turret", 2), math.rad(45)), "far: snapped at once")
		PieceAnim.remove(s, 1)
		for _ = 1, 20 do
			PieceAnim.step(s, 1)
		end
		t.expect(not reached, "its sleeping thread never woke")
		t.equal(#s.threads, 0)
	end)

	t.test("the default script keeps turrets within a tick of the server's aim in a duel", function()
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		local s = PieceAnim.new(sim.defs.weaponByIndex)
		local SUBS = 4
		local worst, compared, turning = 0, 0, 0
		for tick = 1, 200 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, id in world.entered do
				local def = World.def(world, world.units[id])
				PieceAnim.add(s, id, def, Registry.forDef(def))
			end
			table.clear(world.entered)
			for _, d in world.died do
				PieceAnim.remove(s, d.id)
			end
			table.clear(world.died)
			for _ = 1, SUBS do
				PieceAnim.drive(s, world, {})
				PieceAnim.step(s, DT / SUBS)
			end
			-- after a tick's worth of frames: compare with the server now
			for id, u in s.units do
				local def = u.def
				if sim.world.slot[id] == nil or def.weapons[1] == nil then
					continue
				end
				local weapon = sim.defs.weaponByIndex[def.weapons[1].weaponIndex]
				local server = sim.world.wYaw[ServerWorld.slotKey(id, 1)]
				local drawn = rotOf(s, id, def.weapons[1].turretPiece, 2)
				local diff = math.abs((server - drawn + math.pi) % (2 * math.pi) - math.pi)
				-- one tick of the server's own turret travel (plus the wire's 8-bit angle step)
				local allowed = math.rad(weapon.turret.yawRate) * DT + 2 * math.pi / 256
				worst = math.max(worst, diff / allowed)
				compared += 1
				if diff > 1e-3 then
					turning += 1
				end
			end
		end
		print(string.format("    %d turret samples, worst %.2f of a tick's travel behind", compared, worst))
		t.expect(compared > 1000 and turning > 0, "plenty of samples, some turning")
		t.expect(worst <= 1, "never more than a tick behind the server")
	end)

	t.test("Juggernaut: the arms follow the server's raise, hold and lowering (S-20), and recoil in turn", function()
		local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		local jug = Spawn.unit(sim, "chs_juggernaut", 1, -60, 0, math.pi / 2)
		local s = PieceAnim.new(sim.defs.weaponByIndex)
		local def = sim.defs.units.chs_juggernaut
		local turret = sim.defs.weaponByIndex[def.weapons[1].weaponIndex].turret
		t.expect(Registry.forDef(def) == Jug and Registry.forDef(sim.defs.units.chs_ravager) == Default, "the registry picks the scripts")
		local SUBS = 4
		local worst, compared, shots, upAtShot = 0, 0, 0, true
		local enemy
		local restSeen, raisedSeen, loweredAgain = false, false, false
		for tick = 1, 15 * 16 do
			if tick == 30 then
				enemy = Spawn.unit(sim, "chs_ravager", 2, 80, 0, -math.pi / 2) -- in range: the arms must rise first
			end
			if tick == 15 * 6 and enemy and sim.world.slot[enemy] then
				-- the target leaves sight: the server holds the aim, then lowers it
				sim.world.posX[enemy] = 2000
			end
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, id in world.entered do
				if id == jug then
					PieceAnim.add(s, id, def, Registry.forDef(def))
				end
			end
			table.clear(world.entered)
			table.clear(world.died)
			local shooting = {}
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == jug then
					table.insert(shooting, { jug, 1 })
					shots += 1
				end
			end
			for _ = 1, SUBS do
				PieceAnim.drive(s, world, shooting)
				table.clear(shooting)
				PieceAnim.step(s, DT / SUBS)
			end
			if s.units[jug] then
				local server = sim.world.wPitch[ServerWorld.slotKey(jug, 1)]
				local drawn = rotOf(s, jug, "armL", 1)
				local allowed = math.rad(turret.pitchRate) * DT + 2 * math.pi / 256
				worst = math.max(worst, math.abs(server - drawn) / allowed)
				compared += 1
				if #sim.combat.events > 0 then
					for _, e in sim.combat.events do
						if e.kind == "SPAWN_PROJ" and e.unit == jug and drawn < math.rad(turret.minPitch + 30) then
							upAtShot = false
						end
					end
				end
				if near(drawn, math.rad(turret.restPitch), 2 * math.pi / 255) then -- within the wire's angle step
					if raisedSeen then
						loweredAgain = true
					else
						restSeen = true
					end
				elseif drawn > math.rad(-10) then
					raisedSeen = true
				end
			end
		end
		print(string.format("    juggernaut: %d samples, arms worst %.2f of a tick's travel off the server, %d shots", compared, worst, shots))
		t.expect(restSeen and raisedSeen and loweredAgain, "arms down, then up, then down again")
		t.expect(shots > 0 and upAtShot, "it fired, and only with its arms up")
		t.expect(worst <= 1, "the arms never more than a tick off the server's pitch")
		local u = s.units[jug]
		PieceAnim.drive(s, world, { { jug, 1 } })
		PieceAnim.step(s, 1 / 60)
		local first = if u.pieces.armL.pos[3] > 0 then "armL" else "armR"
		for _ = 1, 60 do
			PieceAnim.step(s, 1 / 60)
		end
		PieceAnim.drive(s, world, { { jug, 1 } })
		PieceAnim.step(s, 1 / 60)
		local other = if first == "armL" then "armR" else "armL"
		t.expect(u.pieces[other].pos[3] > 0, "the next shot recoils the other arm")
	end)
end
