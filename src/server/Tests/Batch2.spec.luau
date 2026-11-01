--!strict
-- The BAR roster program's batch 2 (S-233): 43 bots. Every one is on a build
-- list a Commander reaches and every armed one damages a target in its
-- reach; spiders climb what walkers can't; crawling bombs detonate on
-- contact; spies burst into an EMP; decoy Commanders pass for the real one
-- with enemies and leave no wreck.
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local TestMap = require("@shared/Grid/TestMap")
local Combat = require("../Sim/Combat/Combat")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local BATCH2 = {
	"ord_picket", "ord_squire", "ord_petard", "ord_draftsman", "ord_skyguard", "ord_steward", "ord_effigy", "ord_sextant",
	"ord_informant", "ord_marshal", "ord_culverin", "ord_mariner", "ord_scaler", "ord_marksman", "ord_hush", "ord_outrider",
	"ord_martyr", "ord_snare", "ord_stormcaller", "ord_paragon", "ord_champion", "ord_monolith",
	"chs_firebrand", "chs_taskmaster", "chs_wrath", "chs_portent", "chs_blister", "chs_changeling", "chs_cutpurse", "chs_gloom",
	"chs_newt", "chs_pyre", "chs_gargoyle", "chs_spitter", "chs_pustule", "chs_snitch", "chs_ravener", "chs_scrounger",
	"chs_colossus", "chs_pandemonium", "chs_infernal", "chs_widowmaker", "chs_abyssal",
}
local SPIDERS = { "ord_scaler", "ord_snare", "ord_monolith", "chs_ravener", "chs_widowmaker" }

local function command(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, cmd)
	assert(Sim.submit(sim, player, wr:finish()))
end

local function wreckCount(sim: Sim.Sim): number
	return #(sim.combat :: any).wreckIds
end

local function wrecksOf(sim: Sim.Sim, id: string): number
	local c = sim.combat :: any
	local n = 0
	for _, wid in c.wreckIds do
		if c.wreckDef[wid] == sim.defs.units[id].index then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("all 43 are on a build list a Commander reaches", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local units = sim.defs.units
		local reach: { [string]: boolean } = {}
		local queue = { "ord_sovereign", "chs_warlord" }
		while #queue > 0 do
			local id = table.remove(queue) :: string
			if not reach[id] then
				reach[id] = true
				for _, o in units[id].buildOptions or {} do
					table.insert(queue, o)
				end
			end
		end
		t.equal(#BATCH2, 43)
		for _, id in BATCH2 do
			t.expect(units[id] ~= nil, `{id} is a def`)
			t.expect(reach[id], `{id} can be built`)
		end
		for _, id in SPIDERS do
			t.equal(units[id].moveClass, "SPIDER", id)
		end
	end)

	t.test("every armed one damages (or stuns) an enemy in its reach", function()
		for _, id in BATCH2 do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
			local d = sim.defs.units[id]
			local ground = nil
			for _, slot in d.weapons do
				local wd = sim.defs.weapons[slot.def]
				if (wd.damage.ARMORED or 0) > 0 and not wd.kamikaze then
					ground = wd
					break
				end
			end
			if ground == nil then
				continue -- workers, sensors, spies, bombs and the anti-air bots
			end
			local gap = math.min(ground.range * 0.6, 120)
			local u = Spawn.unit(sim, id, 1, 0, -gap / 2, 0)
			local target = Spawn.unit(sim, "chs_ravager", 2, 0, gap / 2, math.pi)
			World.setFireState(sim.world, target, World.FireState.HOLD_FIRE)
			World.setHealth(sim.world, target, 1e6)
			World.setMoveState(sim.world, u, World.MoveState.HOLD_POSITION)
			for _ = 1, 15 * 25 do
				Sim.step(sim)
				if sim.world.health[target] < 1e6 or (sim.world.paralyze[target] or 0) > 0 then
					break
				end
			end
			t.expect(sim.world.health[target] < 1e6 or (sim.world.paralyze[target] or 0) > 0, `{id} hit it`)
		end
	end)

	t.test("SPIDER climbs a 60° cliff that stops a WALKER", function()
		local cliff = Passability.build(TestMap.build(6, 1, function(cx)
			return cx * 14 -- atan(14 / 8) = 60°
		end))
		t.expect(Passability.slopeDegrees(cliff, 2) > 55, "a cliff")
		t.expect(Passability.canEnter(cliff, "SPIDER", 2), "open to spiders")
		t.expect(not Passability.canEnter(cliff, "WALKER", 2), "closed to walkers")
	end)

	t.test("a crawling bomb detonates on contact: its blast hurts everyone near, and it leaves no wreck", function()
		for _, id in { "ord_martyr", "chs_blister", "chs_pustule" } do
			local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
			local w = sim.world
			local bomb = Spawn.unit(sim, id, 1, 0, 0, 0)
			local target = Spawn.unit(sim, "chs_ravager", 2, 0, 6, math.pi)
			World.setFireState(w, target, World.FireState.HOLD_FIRE)
			local friend = Spawn.unit(sim, "ord_lancer", 1, 4, -4, 0)
			local hp, friendHp = w.health[target], w.health[friend]
			for _ = 1, 15 * 3 do
				Sim.step(sim)
				if w.slot[bomb] == nil then
					break
				end
			end
			t.equal(w.slot[bomb], nil, `{id} detonated`)
			Sim.step(sim) -- (a death blast lands the next tick)
			Sim.step(sim)
			t.expect(w.slot[target] == nil or w.health[target] < hp, `{id}: the target took the blast`)
			t.expect(w.slot[friend] == nil or w.health[friend] < friendHp, `{id}: so did a friend beside it`)
			t.equal(wrecksOf(sim, id), 0, `{id} left no wreck`)
		end
	end)

	t.test("a spy self-destructs at once in an EMP burst: everyone near is stunned, nobody hurt", function()
		for _, id in { "ord_informant", "chs_snitch" } do
			local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:96" })
			local w = sim.world
			local spy = Spawn.unit(sim, id, 1, 0, 0, 0)
			local target = Spawn.unit(sim, "chs_ravager", 2, 0, 15, math.pi)
			World.setFireState(w, target, World.FireState.HOLD_FIRE)
			local hp = w.health[target]
			local wrecks = wreckCount(sim)
			t.equal(sim.defs.units[id].sensors.radarSignature, 0, `{id} is invisible to radar`)
			command(sim, 1, { cmdType = CT.SELF_DESTRUCT, flags = 0, unitIds = { spy }, value = 1 })
			Sim.step(sim)
			t.equal(w.slot[spy], nil, `{id} went at once`)
			Sim.step(sim) -- (a death blast lands the next tick)
			Sim.step(sim)
			t.expect((w.paralyze[target] or 0) > 0, `{id}: the enemy is stunned`)
			t.equal(w.health[target], hp, `{id}: and unhurt`)
			t.equal(wreckCount(sim), wrecks, `{id}: no wreck`)
		end
	end)

	t.test("a decoy Commander passes for the real one with enemies, not its own side, and leaves no wreck", function()
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local decoy = Spawn.unit(sim, "ord_effigy", 1, 0, 0, 0)
		Spawn.unit(sim, "chs_ravager", 2, 0, 60, math.pi) -- its eyes
		command(sim, 1, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 63, maxZ = 63 })
		command(sim, 2, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 63, maxZ = 63 })
		local g = (sim.map :: any).grid
		local views = { Client.new(g), Client.new(g) }
		for _ = 1, 10 do
			Sim.step(sim)
			for pid = 1, 2 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
		end
		local sovereign, effigy = sim.defs.units.ord_sovereign.index, sim.defs.units.ord_effigy.index
		t.equal((views[1].units[decoy] :: any).defIndex, effigy, "its owner sees an Effigy")
		t.equal((views[2].units[decoy] :: any).defIndex, sovereign, "the enemy sees a Sovereign")
		t.equal(Sensors.shownDef(sim, 2, decoy, Sensors.Level.VISIBLE, w.defIndex[decoy]), sovereign, "and so do its sensors and AI")
		local wrecks = wreckCount(sim)
		World.setHealth(w, decoy, 1)
		Combat.queueDamage(sim.combat, decoy, 10, 0, 2)
		Sim.step(sim)
		t.equal(w.slot[decoy], nil, "it died")
		t.equal(wreckCount(sim), wrecks, "no wreck to give it away")
	end)
end
