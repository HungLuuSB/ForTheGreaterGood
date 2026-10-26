--!strict
-- The playtest's new units (S-181): bot labs and bots (WALKER, turning on the
-- spot), the Tzar, the Centurion, the Dragon and the Liche. Each is built by
-- the right factory, moves, and its weapon works.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local NEW = { "ord_botlab", "chs_botlab", "ord_advbotlab", "chs_advbotlab", "ord_artisan", "chs_tinker", "ord_lazarus", "chs_graverobber", "ord_glint", "chs_skitter", "ord_mace", "chs_thug", "ord_kestrel", "chs_needle", "ord_fatboy", "chs_tzar", "chs_centurion", "chs_dragon", "ord_liche" }

return function(t: RunAll.Context)
	t.test("every new unit is buildable from a factory or builder of its faction", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS })
		local builtBy: { [string]: string } = {}
		for id, u in sim.defs.units do
			for _, option in u.buildOptions or {} do
				builtBy[option] = builtBy[option] or id
			end
		end
		for _, id in NEW do
			local by = builtBy[id]
			t.expect(by ~= nil, `{id} has a builder`)
			if by then
				t.equal(string.sub(by, 1, 4), string.sub(id, 1, 4), `{id} is built by its own faction ({by})`)
			end
		end
		t.equal(builtBy.ord_botlab ~= nil and builtBy.chs_botlab ~= nil, true)
		t.expect(table.find(sim.defs.units.ord_sovereign.buildOptions :: { string }, "ord_botlab") ~= nil, "the Commander builds a Bot Lab")
	end)

	t.test("bots are WALKERs that turn on the spot; helpers repair and resurrect but build nothing", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		for _, id in { "ord_artisan", "chs_tinker", "ord_glint", "chs_skitter", "ord_mace", "chs_thug", "ord_kestrel", "chs_needle", "ord_fatboy", "chs_centurion", "ord_lazarus", "chs_graverobber" } do
			local u = defs.units[id]
			t.equal(u.moveClass, "WALKER", id)
			t.expect((u.movement :: any).turnRate >= 300, `{id} turns fast`)
		end
		for _, id in { "ord_lazarus", "chs_graverobber" } do
			local u = defs.units[id]
			t.expect(u.buildOptions == nil and u.canResurrect and (u.buildPower or 0) > 0, id)
		end
		t.expect(defs.weapons.chs_tzar_cannon.range < defs.weapons.ord_fatboy_cannon.range, "the Tzar a little under the Fatboy's range")
		t.expect(defs.weapons.chs_tzar_cannon.damage.ARMORED > defs.weapons.ord_fatboy_cannon.damage.ARMORED and defs.weapons.chs_tzar_cannon.reload < defs.weapons.ord_fatboy_cannon.reload, "but hits harder and reloads faster")
		t.expect((defs.units.ord_liche.movement :: any).turnRate < (defs.units.ord_phantom.movement :: any).turnRate, "the Liche turns slowly")
	end)

	t.test("Thug's and Mace's plasma hits only what it strikes (S-190): the target dies, a friend beside it is untouched", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		for id, wd in defs.weapons do
			if wd.fx and wd.fx.trail == "plasma" then
				t.deepEqual(wd.fx.color, { r = 255, g = 225, b = 120 }, `{id}: the tank shell's colour`)
			end
		end
		for _, id in { "ord_fatboy_cannon", "chs_tzar_cannon" } do
			local fx = defs.weapons[id].fx
			t.expect(fx ~= nil and fx.trail == nil and fx.color == nil, `{id}: drawn as a tank shell (S-193, G10)`)
			t.expect((defs.weapons[id].aoe or 0) > 20, `{id}: keeps its big blast`)
		end
		for _, shooter in { "chs_thug", "ord_mace" } do
			local wd = defs.weapons[defs.units[shooter].weapons[1].def]
			t.expect((wd.aoe or 0) == 0, `{shooter}: no blast`)
			t.equal(wd.fx and wd.fx.impact, defs.weapons.ord_lancer_cannon.fx.impact, `{shooter}: the tank's small hit`)
			local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			Spawn.unit(sim, shooter, 2, -40, 0, math.pi / 2)
			local target = Spawn.unit(sim, "ord_lancer", 1, 20, 0)
			local friend = Spawn.unit(sim, "chs_ravager", 2, 20, 5)
			World.setFireState(w, target, World.FireState.HOLD_FIRE)
			World.setFireState(w, friend, World.FireState.HOLD_FIRE) -- (its own point-blank shells would hurt it)
			local full, hits = w.health[friend], 0
			for _ = 1, 15 * 40 do
				local before = w.health[target]
				Sim.step(sim)
				if w.slot[target] == nil then
					break -- (the tank's death blast then hurts the friend: not the shot's)
				end
				if w.health[target] < before then
					hits += 1
				end
				t.equal(w.health[friend], full, `{shooter}: the friend 5 studs from the tank is untouched by the shots`)
			end
			t.equal(w.slot[target], nil, `{shooter} kills the tank`)
			t.expect(hits >= 2, `{shooter}: hit it {hits} times before the kill`)
		end
	end)

	t.test("a Glint crosses the map and its arm lasers kill a scout", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local glint = Spawn.unit(sim, "ord_glint", 1, -200, 0, math.pi / 2)
		local scout = Spawn.unit(sim, "chs_jackal", 2, 200, 0)
		World.setFireState(w, scout, World.FireState.HOLD_FIRE)
		local cell, ox, oz = (sim.map :: any).grid:encode(200, 0)
		submit(sim, 1, { cmdType = CT.FIGHT, flags = 0, unitIds = { glint }, cell = cell, offX = ox, offZ = oz })
		for _ = 1, 15 * 30 do
			Sim.step(sim)
			if w.slot[scout] == nil then
				break
			end
		end
		t.equal(w.slot[scout], nil, "the scout is dead")
	end)

	t.test("the Centurion's laser cuts through a line of light units; the Dragon burns and lasers the ground", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local cent = Spawn.unit(sim, "chs_centurion", 2, 0, 0, 0)
		local hurt = 0
		local line = {}
		for i = 1, 4 do
			local id = Spawn.unit(sim, "ord_herald", 1, 0, 120 + i * 14, math.pi)
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e5)
			table.insert(line, id)
		end
		for _ = 1, 15 * 8 do
			Sim.step(sim)
		end
		for _, id in line do
			if w.health[id] < 1e5 then
				hurt += 1
			end
		end
		t.expect(hurt >= 3, `the beam hurt {hurt} of the 4 in line`)

		local dragon = Spawn.unit(sim, "chs_dragon", 2, -300, -300)
		local tank = Spawn.unit(sim, "ord_lancer", 1, -300, -260)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setHealth(w, tank, 1e5)
		local fired: { [number]: boolean } = {}
		for _ = 1, 15 * 10 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == dragon then
					fired[e.slot :: number] = true
				end
			end
		end
		t.expect(fired[1] and (fired[2] or fired[3]), "fire and lasers")
		t.expect(w.health[tank] < 1e5, "the tank took damage")
	end)

	t.test("the Liche drops one devastating bomb, then goes home to rearm", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local liche = Spawn.unit(sim, "ord_liche", 1, -450, 0, math.pi / 2)
		Spawn.unit(sim, "ord_lancer", 1, 150, 40) -- a spotter
		local plant = Spawn.unit(sim, "chs_vehplant", 2, 150, -60)
		local hp = w.health[plant]
		local cell, ox, oz = (sim.map :: any).grid:encode(150, -60)
		submit(sim, 1, { cmdType = CT.FIGHT, flags = 0, unitIds = { liche }, cell = cell, offX = ox, offZ = oz })
		local bombs = 0
		for _ = 1, 15 * 40 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == liche then
					bombs += 1
				end
			end
		end
		t.equal(bombs, 1, "one bomb a sortie")
		t.expect(w.slot[plant] == nil or hp - w.health[plant] > 2500, "a devastating hit")
	end)
end
