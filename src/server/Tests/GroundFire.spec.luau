--!strict
-- ATTACK_GROUND for ballistic weapons (S-68, audit item 18): artillery,
-- tanks and gun turrets shell an ordered spot until another order.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function command(sim: Sim.Sim, cmdType: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = cmdType, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, 1, w:finish()))
end

-- Steps `ticks`; returns shots by `shooter` and how many burst within `r` of (x, z).
local function shells(sim: Sim.Sim, shooter: number, ticks: number, x: number, z: number, r: number): (number, number)
	local fired, near = 0, 0
	local mine: { [number]: boolean } = {}
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and e.unit == shooter then
				fired += 1
				mine[e.other] = true
			elseif e.kind == "IMPACT" and mine[e.other] and e.x then
				mine[e.other] = nil
				if math.sqrt((e.x - x) ^ 2 + ((e.z :: number) - z) ^ 2) <= r then
					near += 1
				end
			end
		end
	end
	return fired, near
end

return function(t: RunAll.Context)
	t.test("artillery shells an empty spot in range, whatever its fire state", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local gun = Spawn.unit(sim, "ord_verdict", 1, -200, 0, math.pi / 2)
		World.setFireState(sim.world, gun, World.FireState.HOLD_FIRE)
		command(sim, Schema.CmdType.ATTACK_GROUND, { gun }, 200, 40)
		local fired, near = shells(sim, gun, 450, 200, 40, 16)
		t.expect(fired >= 5, `it fired ({fired} shells in 30 s)`)
		t.expect(near >= fired - 2, `{near} of {fired} burst within 16 studs of the spot`)
	end)

	t.test("out of range it drives closer first; a move order ends it", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gun = Spawn.unit(sim, "chs_hellmouth", 1, -400, 0, math.pi / 2)
		command(sim, Schema.CmdType.ATTACK_GROUND, { gun }, 300, 0)
		local fired = shells(sim, gun, 900, 300, 0, 30)
		local d = 300 - w.posX[gun]
		t.expect(fired >= 3, `it fired once in range ({fired})`)
		t.expect(d <= sim.defs.units.chs_hellmouth.maxRange, `it stopped in range ({d} studs off)`)
		command(sim, Schema.CmdType.MOVE, { gun }, -300, 0)
		Sim.step(sim)
		t.equal(sim.air.groundX[gun], nil, "a move order ends it")
		local after = shells(sim, gun, 150, 300, 0, 30)
		t.equal(after, 0, "no more shells")
	end)

	t.test("gun turrets and emplacements take it; missile units don't", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local edict = Spawn.unit(sim, "ord_edict", 1, -200, 0)
		local halo = Spawn.unit(sim, "ord_halo", 1, -200, 80)
		command(sim, Schema.CmdType.ATTACK_GROUND, { edict, halo }, 250, 0)
		local fired, near = shells(sim, edict, 300, 250, 0, 16)
		t.expect(fired >= 2 and near >= fired - 1, `the Edict shelled the spot ({near} of {fired} near)`)
		t.equal(sim.air.groundX[halo], nil, "the Halo (missiles only) ignores it")
	end)
end
