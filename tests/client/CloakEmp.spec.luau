--!strict
-- Cloak and EMP on the client (S-228, S-229, protocol 46; C-279): the
-- CLOAKED and PARALYZED state bits reach the client's units (Render/
-- UnitRenderer draws a cloaked unit see-through and crackles over a stunned
-- one), a cloaker's card offers On / Off (its cloak), and units newer than
-- the icon sheet draw their type's placeholder.

local CommandSet = require("../../src/client/Core/CommandSet")
local Commands = require("../../src/client/Core/Commands")
local Icons = require("../../src/client/Core/Icons")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local IconAtlas = require("../../src/client/UI/IconAtlas")
local Combat = require("../../src/server/Sim/Combat/Combat")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local SimWorld = require("../../src/server/Sim/World")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local US = Schema.UnitState

return function(t: any)
	t.test("the CLOAKED and PARALYZED bits reach the client's units; a cloaker's card switches its cloak", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		for _, acc in sim.eco.accounts do
			acc.power.stored = 1e6 -- the cloak's drain
			acc.supply.stored = 1e6
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local whisper = Spawn.unit(sim, "ord_whisper", 1, 0, 0, 0)
		SimWorld.setFireState(sim.world, whisper, SimWorld.FireState.HOLD_FIRE)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 60, 0, 0)
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			end
		end
		step(6)
		local wu = world.units[whisper]
		t.expect(wu ~= nil and bit32.band(wu.state or 0, US.CLOAKED) ~= 0, "the own Whisper shows CLOAKED")
		t.expect(CommandSet.forDef(sim.defs.units.ord_whisper, sim.defs).toggle, "its card switches the cloak")
		local max = sim.defs.units.ord_lancer.health
		Combat.queueDamage(sim.combat, tank, max * 1.5, 0, 2, 6)
		step(3)
		t.expect(bit32.band(world.units[tank].state or 0, US.PARALYZED) ~= 0, "the stunned tank shows PARALYZED")
		step(15 * 12)
		t.equal(bit32.band(world.units[tank].state or 0, US.PARALYZED), 0, "worn off")
	end)

	t.test("a unit the icon sheet doesn't list yet draws its type's placeholder", function()
		local defs = require("@shared/Defs/Defs").load()
		for _, id in { "ord_whisper", "ord_thunderer" } do
			local def = defs.units[id]
			local tile = Icons.ofDef(def, 1).tile
			local e = IconAtlas.byDef[id]
			t.equal(tile, if e then e.tile else IconAtlas.placeholders[Icons.placeholderFrame(def)], id)
			t.expect(IconAtlas.tiles[tile] ~= nil, `{id}: a tile`)
		end
	end)
end
