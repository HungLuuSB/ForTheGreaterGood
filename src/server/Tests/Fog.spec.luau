--!strict
local Defs = require("@shared/Defs/Defs")
local Packer = require("@shared/Net/Packer")
local Registry = require("@shared/Defs/Registry")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- Registered defs plus neutral test units derived from ord_lancer.
local function testDefs(extra: { [string]: { [string]: any } }): Defs.DefSet
	local raw = deepCopy(Registry)
	for name, overrides in extra do
		local u = Defs.extend(raw.units.ord_lancer, overrides)
		u.id = `neu_{name}`
		u.faction = "neutral"
		u.model = u.id
		raw.units[u.id] = u
	end
	return Defs.build(raw)
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function step(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

local function quiet(sim: Sim.Sim, ids: { number })
	for _, id in ids do
		World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
	end
end

return function(t: RunAll.Context)
	t.test("radar wobble: bounded, deterministic, smooth, per observer", function()
		local s = Sensors.new(nil, { 1, 2 })
		s.radarError[1] = 20
		s.radarError[2] = 45
		local prevX = Sensors.wobble(s, 1, 7, 0)
		local moved = false
		for tick = 1, 300 do
			local x, z = Sensors.wobble(s, 1, 7, tick)
			t.expect(math.sqrt(x * x + z * z) <= 20 + 1e-9, "within the observer's radar error")
			t.expect(math.abs(x - prevX) <= 2 * 20 / 30 + 1e-9, "moves smoothly between periods")
			moved = moved or x ~= prevX
			prevX = x
		end
		t.expect(moved, "the wobble changes over time")
		local a1, a2 = Sensors.wobble(s, 1, 7, 123)
		local b1, b2 = Sensors.wobble(s, 1, 7, 123)
		t.expect(a1 == b1 and a2 == b2, "same unit and tick, same offset")
		local c1 = Sensors.wobble(s, 2, 7, 123)
		t.notEqual(c1, a1, "each observing team sees its own error")
	end)

	t.test("a jammed unit disappears from enemy radar but not from sight", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		local jammer = Spawn.unit(sim, "ord_veil", 1, 40, 0)
		local radar = Spawn.unit(sim, "chs_watcher", 2, -450, 0)
		quiet(sim, { tank, radar })
		-- jamming, not its upkeep (D108), is tested here: keep the Veil powered
		local acc = sim.eco.accounts[1]
		local function step(s: Sim.Sim, n: number)
			for _ = 1, n do
				acc.power.stored = acc.power.storage
				Sim.step(s)
			end
		end
		step(sim, 2)
		t.equal(Sensors.level(sim, 2, tank), L.HIDDEN, "inside the Veil's 300-stud jam: off radar")
		moveTo(sim, 1, { jammer }, 450, 300)
		step(sim, 400)
		t.equal(Sensors.level(sim, 2, tank), L.RADAR, "jammer gone: radar contact again")
		moveTo(sim, 1, { jammer }, 40, 0)
		step(sim, 400)
		t.equal(Sensors.level(sim, 2, tank), L.HIDDEN, "jammed again")
		local spotter = Spawn.unit(sim, "chs_ravager", 2, -100, 0)
		quiet(sim, { spotter })
		step(sim, 2)
		t.equal(Sensors.level(sim, 2, tank), L.VISIBLE, "jamming never hides from sight")
	end)

	-- S-72: plain radars drain power too; in a stall their radius shrinks.
	t.test("a radar tower costs power upkeep and loses reach in a power stall", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:128" })
		local tower = Spawn.unit(sim, "chs_eye", 2, -300, 0) -- radar 560
		local tank = Spawn.unit(sim, "ord_lancer", 1, 230, 0) -- 530 studs off: near the edge
		quiet(sim, { tower, tank })
		local acc = sim.eco.accounts[2]
		local function run(n: number, power: boolean)
			for _ = 1, n do
				acc.power.stored = if power then acc.power.storage else 0
				Sim.step(sim)
			end
		end
		run(10, true)
		t.equal(Sensors.level(sim, 2, tank), L.RADAR, "powered: on radar")
		t.expect(acc.power.demand >= sim.defs.units.chs_eye.sensors.radarDrain :: number, `the tower's upkeep is power demand ({acc.power.demand})`)
		run(150, false)
		t.equal(Sensors.level(sim, 2, tank), L.HIDDEN, "no power: the radius shrank below 530 studs")
		run(30, true)
		t.equal(Sensors.level(sim, 2, tank), L.RADAR, "power back: on radar again")
	end)

	-- D108: jammers drain power; in a stall their jam radius shrinks.
	t.test("a power stall shrinks a jammer's radius until its unit shows on radar", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local jammer = Spawn.unit(sim, "ord_veil", 1, 0, 0) -- jam 300
		local tank = Spawn.unit(sim, "ord_lancer", 1, 250, 0) -- inside the jam, near its edge
		local radar = Spawn.unit(sim, "chs_watcher", 2, -300, 0) -- radar 600 reaches the tank
		quiet(sim, { jammer, tank, radar })
		local acc = sim.eco.accounts[1]
		local function run(n: number, power: boolean)
			for _ = 1, n do
				acc.power.stored = if power then acc.power.storage else 0
				Sim.step(sim)
			end
		end
		run(10, true)
		t.equal(Sensors.level(sim, 2, tank), L.HIDDEN, "powered: the tank is jammed")
		t.expect(acc.power.demand >= sim.defs.units.ord_veil.sensors.jamDrain :: number, `the Veil's upkeep is power demand ({acc.power.demand})`)
		run(150, false)
		t.expect((sim.sensors.powerScale[jammer] or 1) < 0.5, `the jammer gets little power ({sim.sensors.powerScale[jammer]})`)
		t.equal(Sensors.level(sim, 2, tank), L.RADAR, "the shrunken jam no longer covers the tank")
		run(30, true)
		t.equal(Sensors.level(sim, 2, tank), L.HIDDEN, "power back: jammed again")
	end)

	t.test("a stealth unit shows on radar only within range × signature", function()
		local defs = testDefs({ shade = { sensors = { radarSignature = 0.3, sight = 60 } } })
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128", defs = defs })
		local w = sim.world
		local radar = Spawn.unit(sim, "ord_oracle", 1, -400, 0) -- radar 760, sight 120
		local shade = Spawn.unit(sim, "neu_shade", 2, 300, 20, -math.pi / 2)
		quiet(sim, { shade })
		moveTo(sim, 2, { shade }, -470, 20)
		local reach = (sim.defs.units.ord_oracle.sensors.radar :: number) * 0.3
		local s = sim.sensors
		local seen = {}
		for _ = 1, 1200 do
			-- Sensors runs before Movement: it judges where the shade was at the start of the tick
			local sx, sz = w.posX[shade], w.posZ[shade]
			Sim.step(sim)
			if sim.tick % 2 == 0 then
				local d = math.sqrt((sx - w.posX[radar]) ^ 2 + (sz - w.posZ[radar]) ^ 2)
				local _, _, cell = Sensors.cellOf(s, sx, sz)
				local want = if Sensors.count(s, 1, "los", cell) > 0 then L.VISIBLE elseif d <= reach then L.RADAR else L.HIDDEN
				t.equal(Sensors.level(sim, 1, shade), want, `at {d} studs from the radar`)
				seen[want] = true
			end
		end
		t.expect(seen[L.HIDDEN] and seen[L.RADAR] and seen[L.VISIBLE], "the walk crossed all three bands")
	end)

	t.test("units only shoot what their team knows", function()
		local defs = testDefs({ blind = { sensors = { sight = 40 } } })
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64", defs = defs })
		local shooter = Spawn.unit(sim, "neu_blind", 1, -75, 0, math.pi / 2)
		local enemy = Spawn.unit(sim, "chs_ravager", 2, 75, 0, -math.pi / 2)
		quiet(sim, { enemy })
		local shots = 0
		local function count()
			for _, e in sim.combat.events do
				if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit == shooter then
					shots += 1
				end
			end
		end
		for _ = 1, 120 do
			Sim.step(sim)
			count()
		end
		t.equal(shots, 0, "150 studs: in range but unseen, so no shots")
		local spotter = Spawn.unit(sim, "ord_oracle", 1, 20, 60) -- sight 120 covers the enemy
		quiet(sim, { spotter })
		for _ = 1, 120 do
			Sim.step(sim)
			count()
		end
		t.expect(shots > 0, "a friendly spotter shares vision")
	end)

	t.test("radar-targeted artillery misses more than sight-targeted", function()
		local function shell(spotted: boolean): (number, number)
			local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local gun = Spawn.unit(sim, "ord_verdict", 1, -200, 0, math.pi / 2)
			local target = Spawn.unit(sim, "chs_ravager", 2, 200, 0)
			quiet(sim, { target })
			World.setHealth(w, target, 1e9)
			if spotted then
				local scout = Spawn.unit(sim, "ord_lancer", 1, 60, 0) -- sight 200 covers the target
				quiet(sim, { scout })
			else
				Spawn.unit(sim, "ord_oracle", 1, -220, 60) -- radar only
			end
			local shots, hits = 0, 0
			for _ = 1, 15 * 120 do
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "SPAWN_PROJ" and e.unit == gun then
						shots += 1
					elseif e.kind == "IMPACT" and e.unit == target then
						hits += 1
					end
				end
				if sim.tick == 4 then
					t.equal(Sensors.level(sim, 1, target), if spotted then L.VISIBLE else L.RADAR)
				end
			end
			return shots, hits
		end
		local seenShots, seenHits = shell(true)
		local radarShots, radarHits = shell(false)
		t.expect(seenShots >= 20 and radarShots >= 20, `both fired ({seenShots} / {radarShots} shots)`)
		local seenRate, radarRate = seenHits / seenShots, radarHits / radarShots
		t.expect(seenRate > radarRate + 0.3, `direct-hit rate: sighted {seenRate}, radar {radarRate}`)
		print(string.format("    direct-hit rate: sighted %.2f (%d/%d), radar %.2f (%d/%d)", seenRate, seenHits, seenShots, radarRate, radarHits, radarShots))
	end)
end
