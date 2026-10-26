--!strict
-- Unit panel stats (C-76): DPS and the other formulas from the shared defs,
-- what the player may know of enemies, and live own-unit state from the
-- server (ammo, fire / move state, stockpiles).

local NetIn = require("../../src/client/Core/NetIn")
local Commands = require("../../src/client/Core/Commands")
local UnitStats = require("../../src/client/Core/UnitStats")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function weaponOf(defs: any, unitId: string, slot: number?): any
	local ws = defs.units[unitId].weapons[slot or 1]
	return defs.weaponByIndex[ws.weaponIndex]
end

local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: any)
	t.test("DPS: a Lancer against armored, its main class; per-class and salvo formulas", function()
		local defs = Defs.load()
		local cannon = weaponOf(defs, "ord_lancer")
		-- damage to ARMORED per shot × shots ÷ reload, from its def (S-62: 141 per 1.75 s)
		local dps, class = UnitStats.dps(cannon, "ARMORED")
		t.expect(close(dps, cannon.damage.ARMORED * UnitStats.shots(cannon) / cannon.reload), `Lancer vs armored {dps}`)
		print(string.format("    Lancer vs armored: %.1f DPS (%d per shot, every %.2f s)", dps, cannon.damage.ARMORED, cannon.reload))
		t.equal(class, "ARMORED")
		t.equal(UnitStats.mainClass(cannon), "ARMORED", "its target priority starts with ARMORED")
		t.expect(close((UnitStats.dps(cannon, "LIGHT")), cannon.damage.LIGHT / cannon.reload), "vs light")
		t.equal((UnitStats.dps(cannon, "AIR")), 0, "can't hurt aircraft")
		-- a radar SAM: the first armor class in its priority is AIR
		local sam = weaponOf(defs, "ord_aegis")
		t.equal(UnitStats.mainClass(sam), "AIR")
		t.expect(close((UnitStats.dps(sam)), sam.damage.AIR / sam.reload), "radar SAM vs air")
		-- salvos multiply
		t.equal(UnitStats.shots({ salvo = { count = 3, delay = 0.1 } }), 3)
		t.equal(UnitStats.shots({ salvo = 2, projectiles = 4 }), 8)
		t.expect(close((UnitStats.dps({ reload = 2, salvo = { count = 3 }, damage = { LIGHT = 10 } }, "LIGHT")), 15), "3 × 10 / 2")
		-- with no armor class in the priority, the class it hurts most
		t.equal(UnitStats.mainClass({ priority = { "GROUND" }, damage = { LIGHT = 5, STRUCTURE = 50 } }), "STRUCTURE")
	end)

	t.test("missiles: guidance, lock range, stockpile and refill", function()
		local defs = Defs.load()
		local aegis = defs.units.ord_aegis
		local w = assert(UnitStats.weapon(defs, 1, aegis.weapons[1], nil))
		t.equal(w.guidance, "RADAR")
		t.equal(w.lockRange, weaponOf(defs, "ord_aegis").lockRange)
		t.equal(w.stockCap, aegis.weapons[1].stockCapacity)
		t.equal(w.refill, weaponOf(defs, "ord_aegis").stockpile.buildTime)
		t.equal(w.stock, nil, "no count without the owner's record")
		local lancerGun = assert(UnitStats.weapon(defs, 1, defs.units.ord_lancer.weapons[1], nil))
		t.equal(lancerGun.guidance, nil, "a cannon isn't guided")
		t.equal(lancerGun.spread, weaponOf(defs, "ord_lancer").accuracy)
	end)

	t.test("what the player may know: own, in sight, tracked, ghost, contact", function()
		local defs = Defs.load()
		local world = World.new(defs)
		world.me = { team = 1, player = 1, allyTeam = 1 } :: any
		local SF = Schema.StrategicFlag
		local function unit(team: number, tier: string, flags: number, defId: string?): any
			local d = if defId then defs.units[defId] else nil
			return { id = 1, team = team, tier = tier, flags = flags, defIndex = if tier == "tactical" and d then d.index else nil, icon = if d then d.index else 0, health = 0.5, x = 0, z = 0, alt = 0, state = 0, weapon = 0, aim = {} }
		end
		local seen = UnitStats.of(world, unit(2, "tactical", 0, "chs_ravager"))
		t.equal(seen.access, "full")
		t.equal(seen.name, "Ravager")
		t.expect(close(seen.health :: number, 0.5 * defs.units.chs_ravager.health), "an enemy in sight shows its health")
		t.equal(seen.fireState, nil, "but not its owner-only state")
		local tracked = UnitStats.of(world, unit(2, "strategic", SF.RADAR_ONLY + SF.TRACKED, "chs_ravager"))
		t.equal(tracked.access, "full", "tracked by fire control")
		t.expect(#tracked.weapons == 1, "with its weapons")
		local contact = UnitStats.of(world, unit(2, "strategic", SF.RADAR_ONLY, "chs_harpy"))
		t.equal(contact.access, "contact")
		t.equal(contact.name, "Unknown contact", "the type stays hidden even when the icon names it")
		t.equal(contact.domain, "air")
		t.equal(#contact.weapons, 0)
		t.deepEqual(UnitStats.lines(contact), { "Radar contact: air" })
		local blip = UnitStats.of(world, unit(2, "strategic", SF.RADAR_ONLY, nil))
		t.equal(blip.domain, "ground", "an unknown contact on the ground")
		t.equal(UnitStats.of(world, unit(2, "strategic", SF.SONAR_ONLY, nil)).domain, "naval")
		local ghost = UnitStats.of(world, unit(2, "strategic", SF.GHOST, "chs_thorn"))
		t.equal(ghost.access, "type")
		t.equal(ghost.health, nil, "a ghost's health isn't known")
		t.expect(#ghost.weapons == 1, "its type's weapons are")
		t.equal(UnitStats.of(world, unit(1, "tactical", 0, "ord_lancer")).access, "own")
	end)

	t.test("economy and sensors from the defs: income, upkeep, builders, storage", function()
		local defs = Defs.load()
		local world = World.new(defs)
		world.me = { team = 1, player = 1, allyTeam = 1 } :: any
		local function own(defId: string): UnitStats.Sheet
			return UnitStats.of(world, { id = 1, team = 1, tier = "tactical", defIndex = defs.units[defId].index, health = 1, x = 0, z = 0, alt = 0, state = 0, weapon = 0, aim = {} } :: any)
		end
		local gen = own("ord_generator")
		t.equal((gen.income :: any).power, defs.units.ord_generator.production.power)
		local tribunal = own("ord_tribunal")
		local ts = defs.units.ord_tribunal.sensors
		t.equal(tribunal.upkeep, (ts.trackDrain or 0) + (ts.radarDrain or 0), "tracking (and radar, S-72) drain power")
		local beacon = defs.units.ord_beacon.sensors
		if (beacon.radarDrain or 0) > 0 then
			t.equal(own("ord_beacon").upkeep, beacon.radarDrain, "a radar tower drains power")
		end
		t.equal(tribunal.track, defs.units.ord_tribunal.sensors.track)
		local mason = own("ord_mason")
		t.equal(mason.buildPower, defs.units.ord_mason.buildPower)
		t.equal(mason.buildOptions, #defs.units.ord_mason.buildOptions)
		t.equal(own("ord_converter").converter and (own("ord_converter").converter :: any).supply, defs.units.ord_converter.converter.supply)
		t.equal(own("ord_extractor").extractRate, defs.units.ord_extractor.extractor.rate)
		local falcon = own("ord_falcon")
		t.equal(falcon.airSight, defs.units.ord_falcon.sensors.airSight)
		t.expect(table.find(falcon.countermeasures, "Chaff max 2") ~= nil and table.find(falcon.countermeasures, "DIRCM") ~= nil, "countermeasures listed")
		local lines = UnitStats.lines(own("ord_lancer"))
		local gun = defs.weaponByIndex[defs.units.ord_lancer.weapons[1].weaponIndex]
		t.expect(string.find(lines[1], "vs armored", 1, true) ~= nil and string.sub(lines[1], 1, 4) == "DPS ", `first line: {lines[1]}`)
		t.expect(string.find(lines[1], `Range {gun.range}`, 1, true) ~= nil, lines[1])
	end)

	t.test("live own state from the server: retreat setting, fire / move state, stockpile", function()
		local sim = Sim.new({ seed = 9, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local falcon = Spawn.unit(sim, "ord_falcon", 1, 0, 0, 0)
		local aegis = Spawn.unit(sim, "ord_aegis", 1, 60, 60, 0)
		for tick = 1, 4 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		end
		local f = UnitStats.of(world, assert(world.units[falcon]))
		t.equal(f.retreat, require("@shared/Net/Schema").RetreatAt.AT_30, "aircraft retreat at 30% by default (no ammo since S-194)")
		t.equal(f.fireState, sim.world.fireState[falcon])
		t.equal(f.moveState, sim.world.moveState[falcon])
		local a = UnitStats.of(world, assert(world.units[aegis]))
		local stock = sim.defs.units.ord_aegis.weapons[1].stockCapacity
		t.expect(a.weapons[1].stock ~= nil and a.weapons[1].stock <= stock, `stock {a.weapons[1].stock} of {stock}`)
		for _, l in UnitStats.lines(f) do
			print("    " .. l)
		end
	end)

	t.test("lasers show their power per shot (S-187)", function()
		local Sim = require("../../src/server/Sim/Sim")
		local World = require("../../src/client/Core/World")
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local lines = UnitStats.lines(UnitStats.ofDef(world, sim.defs.units.ord_sentry_tower))
		local found = false
		for _, l in lines do
			found = found or string.find(l, "20 power/shot", 1, true) ~= nil
		end
		t.expect(found, "the Sentry's 20 power a shot: " .. table.concat(lines, " | "))
	end)
end
