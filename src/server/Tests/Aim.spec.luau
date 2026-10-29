--!strict
-- The aim model's rest pose and restore delay (S-20, guide 10.3, 14.4):
-- the Juggernaut's arms rest lowered, must rise before it can fire, stay up
-- for the restore delay after the last target, then lower again; and a
-- client running Shared/Combat/Aim gets the server's angles exactly.
local Aim = require("@shared/Combat/Aim")
local Lifecycle = require("../Sim/Lifecycle")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

type Trace = {
	sim: Sim.Sim,
	gun: number,
	key: number,
	turret: any,
	pitch: { number }, -- server pitch (radians) per tick
	yaw: { number },
	wants: { { number }? }, -- the aim the server turned toward per tick (nil: no target)
	acquired: number?, -- tick the weapon got its target
	fired: number?, -- tick of its first shot
	gone: number?, -- tick the target was removed
}

-- A Juggernaut (or another Chaos unit) facing an enemy tank in range (no
-- turret turn needed, so the arm raise sets the timing); the target is
-- removed `removeAt` ticks after the first shot.
local function duel(defId: string, removeAt: number, ticks: number): Trace
	local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
	local w = sim.world
	local gun = Spawn.unit(sim, defId, 2, 0, 0, math.pi / 2)
	local target = Spawn.unit(sim, "ord_lancer", 1, 150, 0, 0)
	World.setFireState(w, target, World.FireState.HOLD_FIRE)
	World.setHealth(w, target, 1e7)
	local key = World.slotKey(gun, 1)
	local tr: Trace = {
		sim = sim,
		gun = gun,
		key = key,
		turret = sim.combat.profiles[w.defIndex[gun]].weapons[1].turret,
		pitch = {},
		yaw = {},
		wants = {},
	}
	Aim.observer = function(k, wy, wp)
		if k == key then
			tr.wants[sim.tick] = if wy and wp then { wy, wp } else nil
		end
	end
	tr.pitch[0], tr.yaw[0] = w.wPitch[key], w.wYaw[key]
	for _ = 1, ticks do
		Sim.step(sim)
		local t = sim.tick
		tr.pitch[t], tr.yaw[t] = w.wPitch[key], w.wYaw[key]
		if tr.acquired == nil and w.wTarget[key] ~= 0 then
			tr.acquired = t
		end
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and e.unit == gun and tr.fired == nil then
				tr.fired = t
			end
		end
		if tr.fired and tr.gone == nil and t >= tr.fired + removeAt then
			Lifecycle.remove(sim, target)
			tr.gone = t
		end
	end
	Aim.observer = nil
	return tr
end

return function(t: RunAll.Context)
	t.test("a Juggernaut can't fire before its arms rise from rest to firing pitch", function()
		local tr = duel("chs_goliath", 30, 120)
		local turret = tr.turret
		t.equal(turret.restPitch, -65, "its arms rest at -65°")
		t.equal(tr.pitch[0], math.rad(-65), "a new Juggernaut starts with its arms down")
		t.expect(tr.acquired ~= nil and tr.fired ~= nil, "it found its target and fired")
		local acquired, fired = tr.acquired :: number, tr.fired :: number
		local want = (tr.wants[fired] :: { number })[2]
		local raise = math.ceil((math.deg(want) + 65 - turret.tolerance) / turret.pitchRate / Aim.DT - 1e-9)
		-- the arms already turn in the tick the target is acquired
		t.expect(fired - acquired + 1 >= raise, `fired after {fired - acquired + 1} ticks of turning; raising the arms takes {raise}`)
		t.expect(math.abs(tr.pitch[fired] - want) <= math.rad(turret.tolerance) + 1e-9, "it fired at firing pitch")
		for tick = acquired, fired - 1 do
			t.expect(tr.pitch[tick] < want - math.rad(turret.tolerance) + 1e-9 or math.abs(tr.yaw[tick] - (tr.wants[tick] :: { number })[1]) > math.rad(turret.tolerance), `not yet aimed at tick {tick}`)
		end
		-- the same gun without the arms (the Maw's heavy cannon rests level) fires much sooner
		local level = duel("chs_maw", 30, 120)
		t.expect(level.fired ~= nil and (level.fired :: number) - (level.acquired :: number) < fired - acquired, `the level gun fired after {(level.fired :: number) - (level.acquired :: number)} ticks`)
		print(string.format("    Juggernaut: first shot %d ticks after acquiring (arms %d ticks); level heavy cannon %d", fired - acquired, raise, (level.fired :: number) - (level.acquired :: number)))
	end)

	t.test("with no target the arms stay up for the restore delay, then lower to rest", function()
		local tr = duel("chs_goliath", 10, 260)
		local turret = tr.turret
		local gone = tr.gone :: number
		-- the last tick the weapon still aimed at it
		local last = gone
		while tr.wants[last + 1] ~= nil do
			last += 1
		end
		local hold = Aim.holdTicks(turret)
		t.equal(hold, 45, "3 s at 15 Hz")
		local up = tr.pitch[last]
		for tick = last + 1, last + hold do
			t.equal(tr.pitch[tick], up, `still raised {tick - last} ticks after the target was lost`)
		end
		t.expect(tr.pitch[last + hold + 1] < up, "then the arms lower")
		local down = math.ceil((math.deg(up) + 65) / turret.pitchRate / Aim.DT - 1e-9)
		t.equal(tr.pitch[last + hold + down], math.rad(-65), `at rest {down} ticks later`)
		t.equal(tr.pitch[260], math.rad(-65), "and stay there")
	end)

	t.test("a client running the shared aim model matches the server exactly", function()
		local tr = duel("chs_goliath", 20, 200)
		-- the client starts at the rest pose and steps with the same wanted
		-- aims (from the target it knows, or the aim updates it gets)
		local restYaw, restPitch = Aim.rest(tr.turret)
		local state: Aim.State = { yaw = restYaw, pitch = restPitch, hold = 0 }
		local differ = 0
		for tick = 1, 200 do
			local want = tr.wants[tick]
			Aim.update(tr.turret, state, if want then want[1] else nil, if want then want[2] else nil)
			if state.pitch ~= tr.pitch[tick] or state.yaw ~= tr.yaw[tick] then
				differ += 1
			end
		end
		t.equal(differ, 0, "ticks where the client's angles differ from the server's (raise, fire, hold, lower)")
		t.expect(Aim.pitchTime(tr.turret, -65, 0) > 0.8, "raising to level takes over 0.8 s")
	end)

	t.test("weapons without a rest pose or delay behave as before", function()
		local tr = duel("chs_maw", 5, 80)
		t.equal(tr.pitch[0], 0, "rest is level")
		t.equal(Aim.holdTicks(tr.turret), 0)
		local last = tr.gone :: number
		while tr.wants[last + 1] ~= nil do
			last += 1
		end
		t.expect(math.abs(tr.pitch[last + 1]) < math.abs(tr.pitch[last]) or tr.pitch[last] == 0, "turns back to rest at once")
	end)
end
