--!strict
-- The playable UI's contract pieces (C-68): the build menu's tabs, factory
-- builds through the API with the server's queue (S-61) following production,
-- CANCEL, command modes, and alerts.

local Api = require("../../src/client/Api")
local BuildMenu = require("../../src/client/Core/BuildMenu")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Combat = require("../../src/server/Sim/Combat/Combat")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function scene()
	local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
	local world = World.new(sim.defs)
	local api = Api.new(world, function(p: buffer)
		assert(Sim.submit(sim, 1, p))
	end)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local tick = 0
	local function step(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			table.clear(world.died)
		end
	end
	return sim, world, api, step
end

return function(t: any)
	t.test("build menu tabs: a builder's structures by category, a factory's units", function()
		local sim, world, api, step = scene()
		local mason = Spawn.unit(sim, "ord_mason", 1, -100, 0, 0)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		step(3)
		local m = BuildMenu.of(world, { mason })
		t.expect(#m.tabs >= 3, "a Mason has several tabs")
		t.expect(m.items.Economy and table.find(m.items.Economy, "ord_solar") ~= nil, "solar under Economy")
		t.expect(m.items.Factories and table.find(m.items.Factories, "ord_vehplant") ~= nil, "the plant under Factories")
		local f = BuildMenu.of(world, { plant })
		t.equal(#f.tabs, 1)
		t.equal(f.tabs[1], "Units")
		t.equal(#f.factories, 1)
		local _ = api
	end)

	t.test("queueBuild: the factory produces; the server's queue follows; CANCEL clears it", function()
		local sim, world, api, step = scene()
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -150, -150, 0) -- power for production
		step(3)
		api.actions.select({ plant })
		local ok = api.actions.queueBuild("ord_lancer", 2)
		t.expect(ok, "queued")
		step(2)
		t.equal(#api.state.factoryQueues[plant], 2)
		local lancers = 0
		for _ = 1, 15 * 120 do
			step(1)
			lancers = 0
			for _, id in sim.world.ids do
				if sim.world.team[id] == 1 and sim.defs.unitByIndex[sim.world.defIndex[id]].id == "ord_lancer" then
					lancers += 1
				end
			end
			if lancers >= 1 then
				break
			end
		end
		step(5)
		t.expect(lancers >= 1, "the plant built a Lancer")
		t.equal(#api.state.factoryQueues[plant], 1) -- one left
		api.actions.cancel(0)
		step(2)
		t.equal(#api.state.factoryQueues[plant], 0)
		local _ = world
	end)

	t.test("command modes: fight, patrol and guard go out as their orders", function()
		local sim, world, api, step = scene()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local other = Spawn.unit(sim, "ord_lancer", 1, 30, 0, 0)
		step(3)
		api.actions.select({ lancer })
		local sent = {}
		api.changed.orders:Connect(function(intent: any)
			table.insert(sent, intent.cmdType)
		end)
		api.actions.setCommandMode("fight")
		t.equal(api.state.commandMode, "fight")
		api.actions.commandAt(100, 0, nil, false)
		t.equal(api.state.commandMode, nil) -- one click, mode done
		api.actions.setCommandMode("patrol")
		api.actions.commandAt(0, 100, nil, false, true)
		t.equal(api.state.commandMode, "patrol") -- Shift keeps it
		api.actions.setCommandMode("guard")
		local ok = api.actions.commandAt(0, 0, nil, false)
		t.expect(not ok, "guard needs a unit")
		api.actions.setCommandMode("guard")
		api.actions.commandAt(30, 0, other, false)
		t.equal(#sent, 3)
		t.equal(sent[1], 2) -- FIGHT
		t.equal(sent[2], 5) -- PATROL
		t.equal(sent[3], 6) -- GUARD
		local _ = world
	end)

	t.test("alerts from the server (S-68): under attack, lost, stall, built; nuke mapping", function()
		local sim, world, api, step = scene()
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local solar = Spawn.unit(sim, "ord_solar", 1, -60, 0, 0)
		step(3)
		local kinds: { [string]: number } = {}
		local texts: { string } = {}
		api.changed.alert:Connect(function(a: any)
			kinds[a.kind] = (kinds[a.kind] or 0) + 1
			table.insert(texts, a.text)
		end)
		-- an enemy opens fire: one alert per zone per 20 s on the server
		Spawn.unit(sim, "chs_ravager", 2, 120, 0, -math.pi / 2)
		step(15 * 6)
		t.equal(kinds.attack, 1, "one 'under attack' for the zone")
		sim.world.health[solar] = 1
		Combat.queueDamage(sim.combat, solar, 5000, 0)
		step(4)
		t.expect((kinds.lost or 0) >= 1, "structure lost")
		-- a stall: a factory building with no power at all
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150, 0)
		step(3)
		sim.eco.accounts[1].power.stored = 0
		api.actions.select({ plant })
		api.actions.queueBuild("ord_herald", 1)
		step(30)
		t.expect((kinds.stall or 0) >= 1, `a power stall alert ({kinds.stall})`)
		-- power back: the scout is built
		Spawn.unit(sim, "ord_fusion", 1, -200, 150, 0)
		for _ = 1, 15 * 60 do
			step(1)
			if (kinds.built or 0) > 0 then
				break
			end
		end
		t.expect((kinds.built or 0) >= 1, "construction complete")
		t.expect(#api.state.alerts >= 4, `alerts listed ({#api.state.alerts})`)
		-- the nuke's alert as the server sends it
		table.insert(world.alertQueue, { kind = Schema.AlertKind.NUKE_LAUNCH, x = 10, z = 20, defIndex = 0, tick = 0 })
		step(1)
		local last = assert(api.state.alerts[#api.state.alerts])
		t.equal(last.kind, "nuke")
		t.equal(last.text, "Nuclear launch detected")
		t.expect(last.at, "it has a place to jump to")
		print("    " .. table.concat(texts, " | "))
		local _ = lancer
	end)
end
