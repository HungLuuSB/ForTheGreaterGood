--!strict
-- The BAR roster program's batch 1 (S-230): 29 vehicles and hovercraft and
-- the two hover factories. Every one is on a build list a Commander
-- reaches, every armed one damages a target in its reach, hovercraft cross
-- land and water, and the hover factories stand on either.
local Packer = require("@shared/Net/Packer")
local Placement = require("../Sim/Placement")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local BATCH1 = {
	"ord_courser", "ord_gemini", "ord_wader", "ord_pontifex", "ord_magistrate", "ord_whisper", "ord_fulgur", "ord_mandate",
	"ord_luminary", "ord_thunderer", "ord_skimwright", "ord_skimmer", "ord_volley", "ord_dart", "ord_halcyon", "ord_tempest",
	"ord_hoverdock",
	"chs_cleaver", "chs_mudskipper", "chs_dredger", "chs_hellfire", "chs_grendel", "chs_hurler", "chs_drifter", "chs_snapjaw",
	"chs_sling", "chs_gnat", "chs_skua", "chs_glaive", "chs_typhon", "chs_skimyard",
}

local function move(sim: Sim.Sim, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, 1, wr:finish()))
end

return function(t: RunAll.Context)
	t.test("all 31 are on a build list a Commander reaches", function()
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
		t.equal(#BATCH1, 31)
		for _, id in BATCH1 do
			t.expect(units[id] ~= nil, `{id} is a def`)
			t.expect(reach[id], `{id} can be built`)
		end
	end)

	t.test("every armed one damages an enemy tank in its reach", function()
		for _, id in BATCH1 do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
			local d = sim.defs.units[id]
			local ground = nil
			for _, slot in d.weapons do
				local wd = sim.defs.weapons[slot.def]
				if (wd.damage.ARMORED or 0) > 0 then
					ground = wd
					break
				end
			end
			if ground == nil then
				continue -- workers, factories and the anti-air hovers
			end
			local gap = math.min(ground.range * 0.6, 120)
			local u = Spawn.unit(sim, id, 1, 0, -gap / 2, 0)
			local target = Spawn.unit(sim, "chs_ravager", 2, 0, gap / 2, math.pi)
			World.setFireState(sim.world, target, World.FireState.HOLD_FIRE)
			World.setHealth(sim.world, target, 1e6)
			World.setMoveState(sim.world, u, World.MoveState.HOLD_POSITION)
			for _ = 1, 15 * 20 do
				Sim.step(sim)
				if sim.world.health[target] < 1e6 or (sim.world.paralyze[target] or 0) > 0 then
					break
				end
			end
			t.expect(sim.world.health[target] < 1e6 or (sim.world.paralyze[target] or 0) > 0, `{id} hit it`)
		end
	end)

	t.test("hovercraft cross from land onto the sea and back; the hover factories stand on land or water", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "beach:96" })
		local w = sim.world
		local hover = Spawn.unit(sim, "ord_skimmer", 1, -100, 0, math.pi / 2)
		move(sim, { hover }, 200, 0) -- 30 studs deep out there
		for _ = 1, 15 * 40 do
			Sim.step(sim)
			if w.orderId[hover] == 0 then
				break
			end
		end
		t.expect(w.posX[hover] > 150, `out on the sea ({w.posX[hover]})`)
		t.equal(bit32.band(w.state[hover], World.State.SUBMERGED), 0, "on the surface, not under it")
		move(sim, { hover }, -100, 0)
		for _ = 1, 15 * 40 do
			Sim.step(sim)
			if w.orderId[hover] == 0 then
				break
			end
		end
		t.expect(w.posX[hover] < -50, `back on land ({w.posX[hover]})`)
		for _, id in { "ord_hoverdock", "chs_skimyard" } do
			local d = sim.defs.units[id]
			t.expect(Placement.check(sim, d, -200, 0, 1), `{id} on land`)
			t.expect(Placement.check(sim, d, 250, 0, 1), `{id} on the sea`)
		end
	end)
end
