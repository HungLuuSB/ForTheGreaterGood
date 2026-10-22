--!strict
-- The Wraith decoy drone (S-109, next.md item 4; design S-75): on enemy
-- radar it passes for a Behemoth bomber until sight or a fire-control radar
-- identifies it, so radar SAMs spend missiles on it.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function camera(sim: Sim.Sim, player: number)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 4, maxZ = 4 })
	assert(Sim.submit(sim, player, w:finish()))
end

-- An Order radar tower and Aegis radar SAM at the west edge, Wraiths of
-- Chaos circling 900 studs east: out of sight, inside radar. With
-- `tracking`, a Tribunal fire-control radar tracks them.
local function scene(tracking: boolean): (Sim.Sim, number, { number })
	local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:256" })
	Spawn.unit(sim, "ord_watchtower", 1, -700, 40)
	local sam = Spawn.unit(sim, "ord_aegis", 1, -700, 0)
	if tracking then
		Spawn.unit(sim, "ord_tribunal", 1, -300, -40) -- track 700: reaches the decoys
	end
	local wraiths = {}
	for i = 1, 3 do
		local id = Spawn.unit(sim, "chs_wraith", 2, 150, (i - 2) * 60, -math.pi / 2)
		table.insert(wraiths, id)
	end
	camera(sim, 1)
	return sim, sam, wraiths
end

return function(t: RunAll.Context)
	t.test("on radar a Wraith passes for a Behemoth: Behemoth icon, bomber categories, a SAM target", function()
		local sim, sam, wraiths = scene(false)
		local w = sim.world
		local view = Client.new((sim.map :: any).grid)
		local fired = 0
		for _ = 1, 15 * 20 do
			sim.eco.accounts[1].power.stored = 1000
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == sam then
					fired += 1
				end
			end
		end
		local alive = nil
		for _, id in wraiths do
			if World.isAlive(w, id) then
				alive = id
			end
		end
		t.expect(fired > 0, `the Aegis fired at the decoys ({fired} missiles)`)
		if alive then
			local level = Sensors.level(sim, 1, alive)
			t.equal(level, Sensors.Level.RADAR, "a radar contact, not seen")
			t.equal(Sensors.shownDef(sim, 1, alive, level, w.defIndex[alive]), sim.defs.units.chs_behemoth.index, "taken for a Behemoth")
			local u = view.units[alive]
			t.expect(u ~= nil and u.tier == "strategic", "on the minimap")
			t.equal(u and u.icon, sim.net.iconIndex[sim.defs.units.chs_behemoth.index], "with the Behemoth's icon")
		end
	end)

	t.test("a fire-control radar identifies it: the real icon", function()
		local sim, _, wraiths = scene(true)
		local w = sim.world
		local view = Client.new((sim.map :: any).grid)
		for _ = 1, 15 * 4 do
			sim.eco.accounts[1].power.stored = 1000
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
		end
		local id = wraiths[1]
		t.equal(Sensors.isTracked(sim, 1, id), true, "tracked")
		t.equal(Sensors.shownDef(sim, 1, id, Sensors.level(sim, 1, id), w.defIndex[id]), w.defIndex[id], "known for what it is")
		t.equal(view.units[id] and view.units[id].icon, sim.net.iconIndex[w.defIndex[id]], "its own icon")
	end)
end
