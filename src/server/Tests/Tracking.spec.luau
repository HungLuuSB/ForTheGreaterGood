--!strict
-- Fire-control (tracking) radar (guide 11.2, 11.4; DECISIONS D104, D105).
local EW = require("../Sim/EW")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local NetOut = require("../Sim/NetOut")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

-- Keeps both teams' power full: these tests are about tracking, not upkeep.
local function powered(sim: Sim.Sim)
	for _, team in { 1, 2 } do
		local acc = sim.eco.accounts[team]
		acc.power.stored = acc.power.storage
	end
end

local function dist(w: World.World, a: number, x: number, z: number): number
	return math.sqrt((w.posX[a] - x) ^ 2 + (w.posZ[a] - z) ^ 2)
end

return function(t: RunAll.Context)
	-- A Verdict howitzer shells a parked Ravager at 0.9 × its range, beyond
	-- its sight, on Order's early-warning radar; with or without a Tribunal.
	-- Counted: direct hits.
	local function shelling(tracking: boolean): (number, number)
		local sim = Sim.new({ seed = 41, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gun = Spawn.unit(sim, "ord_verdict", 1, -200, 0, math.pi / 2)
		Spawn.unit(sim, "ord_watchtower", 1, -250, 120)
		if tracking then
			Spawn.unit(sim, "ord_tribunal", 1, -250, -120)
		end
		-- ~290 studs from the Watchtower and the Tribunal: inside the radar, beyond both sights
		local target = Spawn.unit(sim, "chs_ravager", 2, -200 + sim.defs.weapons.ord_howitzer.range * 0.9, 0, -math.pi / 2)
		w.fireState[target] = World.FireState.HOLD_FIRE
		World.setHealth(w, target, 1e6)
		local shots, hits = 0, 0
		local mine: { [number]: boolean } = {}
		for _ = 1, 900 do
			powered(sim)
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == gun then
					shots += 1
					mine[e.other] = true
				elseif e.kind == "IMPACT" and mine[e.other] then
					mine[e.other] = nil
					if e.unit == target then
						hits += 1
					end
				end
			end
			if sim.tick > 4 then
				t.equal(Sensors.level(sim, 1, target), L.RADAR, "the target is only a radar contact")
				t.equal(Sensors.isTracked(sim, 1, target), tracking, "tracked only with the Tribunal")
			end
		end
		return shots, hits
	end

	t.test("artillery hits a radar contact far more often inside tracking coverage", function()
		local s0, h0 = shelling(false)
		local s1, h1 = shelling(true)
		t.expect(s0 >= 10 and s1 >= 10, `both fired ({s0}, {s1} shells)`)
		local r0, r1 = h0 / s0, h1 / s1
		t.expect(r1 >= 0.5, `tracked: {h1} of {s1} shells hit directly`)
		t.expect(r1 >= 2 * r0, `at least twice the untracked rate ({h0} of {s0})`)
		print(string.format("    howitzer on a radar contact: %d of %d direct hits untracked, %d of %d tracked", h0, s0, h1, s1))
	end)

	-- An Absolution bombs a Ravager that keeps driving back and forth, 600
	-- studs off; Order sees it on its Beacon only, with or without a
	-- Tribunal's track. Counted: bombs that damage it.
	local function bombing(tracking: boolean): (number, number)
		local sim = Sim.new({ seed = 42, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -450, -300, math.pi / 2)
		Spawn.unit(sim, "ord_beacon", 1, -450, 300)
		if tracking then
			Spawn.unit(sim, "ord_tribunal", 1, -300, 0)
		end
		Spawn.unit(sim, "ord_airpad", 1, -450, -420)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 150, -300, 0)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		World.setHealth(w, tank, 1e6)
		moveTo(sim, 1, { bomber }, 150, 0)
		local drops, hits = 0, 0
		local mine: { [number]: boolean } = {}
		for i = 1, 2400 do
			powered(sim)
			if i % 300 == 1 then
				moveTo(sim, 2, { tank }, 150, if (i // 300) % 2 == 0 then 350 else -350) -- keeps moving
			end
			local hp = w.health[tank]
			Sim.step(sim)
			local landed = false
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == bomber then
					drops += 1
					mine[e.other] = true
				elseif e.kind == "IMPACT" and mine[e.other] then
					mine[e.other] = nil
					landed = true
				end
			end
			if landed and w.health[tank] < hp then
				hits += 1
			end
		end
		return drops, hits
	end

	t.test("bombers hit moving tracked contacts much more often than untracked ones", function()
		local d0, h0 = bombing(false)
		local d1, h1 = bombing(true)
		t.expect(d1 >= 3, `bombs dropped on the tracked column ({d1})`)
		t.expect(h1 >= 3 and h1 >= 2 * math.max(h0, 1), `tracked hits {h1} of {d1}, untracked {h0} of {d0}`)
		print(string.format("    bomber on a moving tank: %d of %d hit untracked, %d of %d tracked", h0, d0, h1, d1))
	end)

	t.test("tracked contacts wobble by the track error, smaller for Order than Chaos", function()
		local sim = Sim.new({ seed = 43, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		Spawn.unit(sim, "ord_watchtower", 1, -300, 0)
		Spawn.unit(sim, "ord_tribunal", 1, -300, 100)
		Spawn.unit(sim, "chs_eye", 2, 300, 0)
		Spawn.unit(sim, "chs_seekerspire", 2, 300, 100)
		-- each inside the other team's radar, beyond every enemy sight; ~315 studs apart: neither sees the other
		local ro, rc = sim.defs.units.ord_watchtower.sensors.radar :: number, sim.defs.units.chs_eye.sensors.radar :: number
		local red = Spawn.unit(sim, "chs_ravager", 2, -300 + ro * 0.7, -ro * 0.4) -- 0.81 × the Watchtower's radar
		local blue = Spawn.unit(sim, "ord_lancer", 1, 300 - rc * 0.75, rc * 0.5) -- 0.9 × the Eye's radar
		w.fireState[red] = World.FireState.HOLD_FIRE
		w.fireState[blue] = World.FireState.HOLD_FIRE
		local worstO, worstC = 0, 0
		for _ = 1, 300 do
			powered(sim)
			Sim.step(sim)
			if sim.tick > 4 then
				t.expect(Sensors.level(sim, 1, red) == L.RADAR and Sensors.level(sim, 2, blue) == L.RADAR, "both radar contacts")
				t.expect(Sensors.isTracked(sim, 1, red) and Sensors.isTracked(sim, 2, blue), "both tracked")
				local ox, oz = Sensors.knownPosition(sim, 1, red, true)
				local cx, cz = Sensors.knownPosition(sim, 2, blue, true)
				worstO = math.max(worstO, dist(w, red, ox :: number, oz :: number))
				worstC = math.max(worstC, dist(w, blue, cx :: number, cz :: number))
			end
		end
		t.expect(worstO <= sim.defs.units.ord_tribunal.sensors.trackError :: number + 1e-6, `Order's error within the Tribunal's {worstO}`)
		t.expect(worstC <= sim.defs.units.chs_seekerspire.sensors.trackError :: number + 1e-6, `Chaos's error within the Seeker Spire's {worstC}`)
		t.expect(worstO < worstC, "Order tracks more precisely")
	end)

	t.test("a jammer hides its team from tracking radar (no burn-through)", function()
		local sim = Sim.new({ seed = 44, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		Spawn.unit(sim, "ord_watchtower", 1, -250, 0)
		Spawn.unit(sim, "ord_tribunal", 1, -200, 0) -- deep inside its track
		-- inside the Watchtower's radar, beyond its sight
		local tank = Spawn.unit(sim, "chs_ravager", 2, -250 + (sim.defs.units.ord_watchtower.sensors.radar :: number) * 0.8, 0)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(Sensors.isTracked(sim, 1, tank), "tracked without the jammer")
		local jammer = Spawn.unit(sim, "chs_shroud", 2, w.posX[tank] + 40, 40)
		w.fireState[jammer] = World.FireState.HOLD_FIRE
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(not Sensors.isTracked(sim, 1, tank), "the jammer cancels the track")
		t.equal(Sensors.level(sim, 1, tank), L.HIDDEN, "and the radar contact")
	end)

	t.test("the client gets a radar contact's real icon only while it is tracked", function()
		local sim = Sim.new({ seed = 45, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		Spawn.unit(sim, "ord_beacon", 1, -400, 0)
		local tribunal = Spawn.unit(sim, "ord_tribunal", 1, -400, 300)
		local near = Spawn.unit(sim, "chs_ravager", 2, -100, 250) -- inside the Tribunal's 700
		local far = Spawn.unit(sim, "chs_goliath", 2, 400, -350) -- radar only
		w.fireState[near] = World.FireState.HOLD_FIRE
		w.fireState[far] = World.FireState.HOLD_FIRE
		NetOut.setCamera(sim, 1, 0, 0, 0, 0) -- everything else strategic
		local seen: { [number]: Schema.Strategic } = {}
		for _ = 1, 10 do
			powered(sim)
			Sim.step(sim)
			for _, msg in sim.net.players[1].outbox.Strategic do
				for _, r in (Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeStrategicHeader)) do
					seen[r.unitId] = r
				end
			end
		end
		local SF = Schema.StrategicFlag
		local nr, fr = seen[near], seen[far]
		t.expect(nr ~= nil and fr ~= nil, "both are on the minimap")
		t.equal(nr.flags, SF.RADAR_ONLY + SF.TRACKED, "the tracked contact carries TRACKED")
		t.equal(nr.icon, sim.net.iconIndex[w.defIndex[near]], "and its real icon")
		t.equal(fr.flags, SF.RADAR_ONLY, "the untracked one is a plain blip")
		t.equal(fr.icon, 0, "with no icon")
		local _ = tribunal
	end)

	t.test("a power stall shrinks the tracking radius until nothing is tracked", function()
		local sim = Sim.new({ seed = 46, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		Spawn.unit(sim, "ord_aegis", 1, -250, 0) -- a radar without upkeep: towers shrink in a stall too (S-72)
		local tribunal = Spawn.unit(sim, "ord_tribunal", 1, -250, 100)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 300, 100) -- 550 from the Tribunal (track 700)
		w.fireState[tank] = World.FireState.HOLD_FIRE
		for _ = 1, 10 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(Sensors.isTracked(sim, 1, tank), "tracked while powered")
		local acc = sim.eco.accounts[1]
		for _ = 1, 150 do
			acc.power.stored = 0 -- no power at all
			Sim.step(sim)
		end
		t.expect((sim.sensors.powerScale[tribunal] or 1) < 0.5, `the radar gets little power ({sim.sensors.powerScale[tribunal]})`)
		t.expect(not Sensors.isTracked(sim, 1, tank), "the shrunken radius no longer reaches the tank")
		t.equal(Sensors.level(sim, 1, tank), L.RADAR, "it is still a radar contact")
		for _ = 1, 30 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(Sensors.isTracked(sim, 1, tank), "power back: tracked again")
	end)

	-- D105: radar-guided lock range +10% against tracked targets.
	t.test("radar-guided missiles lock 10% farther on tracked targets", function()
		local sim = Sim.new({ seed = 47, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local sam = Spawn.unit(sim, "ord_seraph", 1, -300, 0)
		Spawn.unit(sim, "ord_beacon", 1, -400, 200)
		local weapon = sim.defs.weapons.ord_radar_sam
		local range = EW.lockRange(weapon)
		local heli = Spawn.unit(sim, "chs_wasp", 2, -300 + range * 1.05, 0)
		w.fireState[heli] = World.FireState.HOLD_FIRE
		w.fireState[sam] = World.FireState.HOLD_FIRE
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		local d = dist(w, sam, w.posX[heli], w.posZ[heli])
		t.equal(Sensors.level(sim, 1, heli), L.RADAR, "a radar contact")
		t.expect(not EW.canLock(sim, sam, weapon, heli, d), "untracked: beyond lock range")
		Spawn.unit(sim, "ord_tribunal", 1, -100, 100)
		for _ = 1, 4 do
			powered(sim)
			Sim.step(sim)
		end
		t.expect(Sensors.isTracked(sim, 1, heli), "tracked")
		d = dist(w, sam, w.posX[heli], w.posZ[heli])
		t.expect(d > range and d <= range * EW.TRACK_LOCK_BONUS, "still between the base and the extended range")
		t.expect(EW.canLock(sim, sam, weapon, heli, d), "tracked: locks at 105% of the lock range")
	end)
end
