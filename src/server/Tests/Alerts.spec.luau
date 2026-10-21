--!strict
-- Player alerts and the UNDER_ATTACK flag (S-68, client request 39; guide
-- 7.2, 7.3): ALERT records reach the player they concern, rate-limited.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local AK = Schema.AlertKind
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function run(sim: Sim.Sim, views: { Client.View }, ticks: number)
	for _ = 1, ticks do
		Sim.step(sim)
		for pid, v in views do
			Client.receive(v, sim.net.players[pid].outbox)
		end
	end
end

local function count(v: Client.View, kind: number): number
	local n = 0
	for _, a in v.alerts do
		if a.alert == kind then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("attacks alert the owner once per zone per 20 s; a loss alerts it; the enemy hears nothing", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local g = (sim.map :: any).grid
		local views = { Client.new(g), Client.new(g) }
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local guns = {}
		for i = 1, 3 do
			table.insert(guns, Spawn.unit(sim, "chs_ravager", 2, 100, (i - 2) * 20, -math.pi / 2))
		end
		World.setHealth(w, tank, 1e5)
		run(sim, views, 450) -- 30 s of fire
		t.equal(count(views[1], AK.UNIT_ATTACKED), 2, "one at the first hit, one 20 s later")
		t.equal(#views[2].alerts, 0, "the attacker gets no alert")
		World.setHealth(w, tank, 1)
		run(sim, views, 60)
		t.expect(not World.isAlive(w, tank), "the tank died")
		t.equal(count(views[1], AK.UNIT_LOST), 1, "UNIT_LOST")
		local lost = views[1].alerts[#views[1].alerts]
		t.equal(lost.defIndex, sim.defs.units.ord_lancer.index, "with the unit's type")
		t.expect(math.abs(lost.x) < 12 and math.abs(lost.z) < 12, `where it died ({lost.x}, {lost.z})`)
	end)

	t.test("the owner's strategic record of a unit hit in the last 3 s is UNDER_ATTACK", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local g = (sim.map :: any).grid
		local views = { Client.new(g), Client.new(g) }
		local gen = Spawn.unit(sim, "ord_generator", 1, -300, 0)
		submit(sim, 1, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 100, minZ = 100, maxX = 120, maxZ = 120 }) -- elsewhere
		run(sim, views, 30)
		t.equal(bit32.band(views[1].units[gen].flags or 0, Schema.StrategicFlag.UNDER_ATTACK), 0, "not before")
		local enemy = Spawn.unit(sim, "chs_jackal", 2, 300, 0)
		Combat.queueDamage(sim.combat, gen, 10, enemy)
		run(sim, views, 10)
		t.expect(bit32.band(views[1].units[gen].flags or 0, Schema.StrategicFlag.UNDER_ATTACK) ~= 0, "flagged after an enemy hit")
		t.equal(count(views[1], AK.STRUCTURE_ATTACKED), 1, "and STRUCTURE_ATTACKED")
		run(sim, views, 60)
		t.equal(bit32.band(views[1].units[gen].flags or 0, Schema.StrategicFlag.UNDER_ATTACK), 0, "cleared 3 s later")
	end)

	t.test("BUILD_DONE for each factory unit; a power stall alerts once; a launch alerts everyone", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local g = (sim.map :: any).grid
		local views = { Client.new(g), Client.new(g) }
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
		-- the starting 1,000 power pays for a Herald, not for the Lancer after it
		for _, defId in { "ord_herald", "ord_lancer" } do
			submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units[defId].index, cell = 0, offX = 0, offZ = 0, facing = 0 })
		end
		run(sim, views, 900)
		t.equal(count(views[1], AK.BUILD_DONE), 1, "the Herald")
		t.equal(count(views[1], AK.STALL_POWER), 1, "no income: the power ran out, once")
		t.equal(count(views[2], AK.BUILD_DONE), 0, "not the other player's")
		local silo = Spawn.unit(sim, "chs_ragnarok", 2, 300, 300, 0)
		sim.world.wStock[World.slotKey(silo, 1)] = 1
		local cell, ox, oz = g:encode(-300, -300)
		submit(sim, 2, { cmdType = CT.ATTACK_GROUND, flags = 0, unitIds = { silo }, cell = cell, offX = ox, offZ = oz })
		run(sim, views, 30)
		t.equal(count(views[1], AK.NUKE_LAUNCH), 1, "the target's owner is warned")
		t.equal(count(views[2], AK.NUKE_LAUNCH), 1, "and the launcher")
	end)
end
