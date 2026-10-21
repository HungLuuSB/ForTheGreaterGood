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

	t.test("Juggernaut: arms rise to aim, recoil in turn, and come down after the restore delay", function()
		local def = defs.units.chs_juggernaut
		local s = PieceAnim.new(defs.weaponByIndex)
		local world: any = World.new(defs)
		world.units[5] = { id = 5, tier = "tactical", team = 1, x = 0, z = 0, alt = 0, heading = 0, state = 0, weapon = 0, aim = {} }
		local u = PieceAnim.add(s, 5, def, Registry.forDef(def))
		t.expect(Registry.forDef(def) == Jug and Registry.forDef(defs.units.chs_ravager) == Default, "the registry picks the scripts")
		PieceAnim.step(s, 0)
		t.expect(near(rotOf(s, 5, "armL", 1), math.rad(Jug.REST_PITCH)), "arms start hanging down")
		-- engaged: aim at yaw 40°, pitch 3°
		local wu = world.units[5]
		wu.aim[1] = { yaw = math.rad(40), pitch = math.rad(3) }
		wu.weapon = Schema.packWeaponStates({ Schema.WeaponState.AIMING })
		local raisedAt
		for frame = 1, 120 do
			PieceAnim.drive(s, world, {})
			PieceAnim.step(s, 1 / 60)
			if raisedAt == nil and near(rotOf(s, 5, "armL", 1), math.rad(3), 1e-6) then
				raisedAt = frame / 60
			end
		end
		local raise = (3 - Jug.REST_PITCH) / Jug.ARM_SPEED
		t.expect(raisedAt ~= nil and math.abs(raisedAt - raise) <= 1 / 60 + 1e-6, `arms up after {raisedAt} s (expected {raise})`)
		t.expect(near(rotOf(s, 5, "turret", 2), math.rad(40), 1e-6), "torso on the target")
		-- two shots: one arm each
		PieceAnim.drive(s, world, { { 5, 1 } })
		PieceAnim.step(s, 1 / 60)
		t.expect(s.units[5].pieces.armL.pos[3] > 0 and s.units[5].pieces.armR.pos[3] == 0, "first shot: left arm recoils")
		for _ = 1, 60 do
			PieceAnim.step(s, 1 / 60)
		end
		PieceAnim.drive(s, world, { { 5, 1 } })
		PieceAnim.step(s, 1 / 60)
		t.expect(s.units[5].pieces.armR.pos[3] > 0, "second shot: right arm")
		-- stays up while engaged (AimWeapon every REAIM s cancels the restore)
		for _ = 1, 60 * 5 do
			PieceAnim.drive(s, world, {})
			PieceAnim.step(s, 1 / 60)
		end
		t.expect(near(rotOf(s, 5, "armL", 1), math.rad(3)), "still up after 5 s engaged")
		-- target gone: the server's turret goes back, the arms wait, then come down
		wu.weapon = 0
		wu.aim[1] = { yaw = 0, pitch = 0 }
		local loweredAt, startedAt = nil, s.now
		for _ = 1, 60 * 6 do
			PieceAnim.drive(s, world, {})
			PieceAnim.step(s, 1 / 60)
			if loweredAt == nil and rotOf(s, 5, "armL", 1) < math.rad(3) - 1e-6 then
				loweredAt = s.now - startedAt
			end
		end
		t.expect(loweredAt ~= nil and loweredAt >= Jug.RESTORE_DELAY - 0.5 and loweredAt <= Jug.RESTORE_DELAY + 0.1, `arms start down ~{Jug.RESTORE_DELAY} s after the last aim ({loweredAt})`)
		t.expect(near(rotOf(s, 5, "armL", 1), math.rad(Jug.REST_PITCH)) and near(rotOf(s, 5, "turret", 2), 0), "arms down, torso forward")
		local _ = u
	end)
end
