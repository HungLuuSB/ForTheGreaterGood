--!strict
-- Skirmish AI behaviors (S-7): radar, fire-control radar, kiting artillery,
-- anti-air against aircraft; difficulty levels (S-17). Full matches are in
-- Skirmish.spec; level matchups in `lune run ailevels` (docs/AI_LEVELS.md).
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function start(seed: number): Sim.Sim
	return Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

-- Steps with only `brains` thinking; `rich` keeps their accounts full.
local function run(sim: Sim.Sim, brains: { Skirmish.Brain }, ticks: number, rich: boolean, stop: (() -> boolean)?)
	for _ = 1, ticks do
		if rich then
			for _, b in brains do
				local acc = sim.eco.accounts[b.team]
				acc.supply.stored = acc.supply.storage
				acc.power.stored = acc.power.storage
			end
		end
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if stop and stop() then
			return
		end
	end
end

local function owned(sim: Sim.Sim, player: number, defId: string): { number }
	local w = sim.world
	local out = {}
	for _, id in w.ids do
		if w.owner[id] == player and sim.defs.unitByIndex[w.defIndex[id]].id == defId then
			table.insert(out, id)
		end
	end
	return out
end

-- The player's armed mobile units, Commander and scouts aside: tanks, bots
-- and aircraft (S-216: bots and helicopters are in the army too).
local function armyOf(sim: Sim.Sim, player: number): number
	local w = sim.world
	local n = 0
	for _, id in w.ids do
		local d = sim.defs.unitByIndex[w.defIndex[id]]
		if w.owner[id] == player and d.domain ~= "structure" and #d.weapons > 0 and not table.find(d.categories, "COMMANDER") and d.id ~= "ord_herald" and d.id ~= "chs_jackal" then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("the AI builds a radar tower early", function()
		local sim = start(21)
		local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
		run(sim, brains, 5400, false, function()
			return #owned(sim, 1, "ord_watchtower") > 0 and #owned(sim, 2, "chs_eye") > 0
		end)
		t.expect(#owned(sim, 1, "ord_watchtower") > 0, "Order built a Watchtower")
		t.expect(#owned(sim, 2, "chs_eye") > 0, "Chaos built an Eye")
		print(string.format("    radar towers by tick %d (%.1f min)", sim.tick, sim.tick / 900))
	end)

	t.test("faction styles: Order fields Wardens, Chaos Locusts and a jammer (S-76)", function()
		local o = Skirmish.styled(Skirmish.LEVELS.normal, "ord_", "normal")
		local c = Skirmish.styled(Skirmish.LEVELS.normal, "chs_", "normal")
		t.expect(o.artyChance > Skirmish.LEVELS.normal.artyChance and o.recall, "Order: more artillery, recalls")
		t.expect(c.workers > Skirmish.LEVELS.normal.workers and c.lanes == 2 and c.jammer, "Chaos: wider, two lanes, a jammer")
		local easy = Skirmish.styled(Skirmish.LEVELS.easy, "chs_", "easy")
		t.equal(easy.firstWave, Skirmish.LEVELS.easy.firstWave, "easy keeps its strength")
		-- waves are counted by value (S-92): no count bonus for Chaos
		t.equal(c.firstWave, o.firstWave, "the same wave value for both factions")
		t.equal(c.waveGrowth, o.waveGrowth)
		t.expect(Skirmish.styled(Skirmish.LEVELS.hard, "ord_", "hard").defenses > Skirmish.LEVELS.hard.defenses, "Order hard: a turret more")
		-- rich economies, so both reach their advanced plants within the run
		local sim = start(24)
		local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
		-- (fielded at any point: a side may lose them, or the match, later)
		local seen: { [string]: boolean } = {}
		run(sim, brains, 20000, true, function() -- (S-185: was 13,500; the AI rework, F41, revisits these timings)
			for _, pair in { { 1, "ord_warden" }, { 2, "chs_locust" }, { 2, "chs_shroud" } } do
				if #owned(sim, pair[1] :: number, pair[2] :: string) > 0 then
					seen[pair[2] :: string] = true
				end
			end
			return seen.ord_warden and seen.chs_locust and seen.chs_shroud or false
		end)
		t.expect(seen.ord_warden, `Order fielded a Warden (tick {sim.tick})`)
		t.expect(seen.chs_locust, "Chaos fielded Locusts")
		t.expect(seen.chs_shroud, "and a Shroud jammer")
	end)

	t.test("with supply to spare the AI techs up to a fire-control radar escorting its waves", function()
		local sim = start(22)
		local brain = Skirmish.new(sim, 1)
		run(sim, { brain }, 9000, true, function()
			return #owned(sim, 1, "ord_arbiter") > 0
		end)
		local arbiters = owned(sim, 1, "ord_arbiter")
		t.expect(#owned(sim, 1, "ord_advvehplant") > 0, "built an Advanced Vehicle Plant")
		t.expect(#arbiters > 0, `and an Arbiter (tick {sim.tick})`)
		print(string.format("    Arbiter by tick %d (%.1f min)", sim.tick, sim.tick / 900))
	end)

	t.test("the AI answers known enemy aircraft with IR SAM trucks and a SAM site", function()
		local sim = start(23)
		local brain = Skirmish.new(sim, 1)
		local w = sim.world
		run(sim, { brain }, 1800, true) -- a plant and workers first
		-- Chaos helicopters hover over Order's base, holding fire
		for i = 1, 4 do
			local heli = Spawn.unit(sim, "chs_wasp", 2, brain.homeX + (i - 2) * 30, brain.homeZ - 80)
			World.setFireState(w, heli, World.FireState.HOLD_FIRE)
			World.setHealth(w, heli, 1e6)
		end
		run(sim, { brain }, 2700, true, function()
			return #owned(sim, 1, "ord_halo") >= 2 and #owned(sim, 1, "ord_vigil") > 0
		end)
		t.expect(#owned(sim, 1, "ord_halo") >= 2, `IR SAM trucks ({#owned(sim, 1, "ord_halo")})`)
		t.expect(#owned(sim, 1, "ord_vigil") > 0, "an IR SAM site at home")
	end)

	-- An AI Verdict howitzer with a Chaos tank closing in: it backs off; a
	-- Lancer in the same spot doesn't.
	local function closing(defId: string): (number, boolean)
		local sim = start(24)
		local brain = Skirmish.new(sim, 1)
		local w = sim.world
		local x, z = brain.homeX + brain.toward * 200, brain.homeZ + 150
		local gun = Spawn.unit(sim, defId, 1, x, z)
		World.setFireState(w, gun, World.FireState.HOLD_FIRE)
		-- well inside the Verdict's kite radius (same spot for the Lancer)
		local near = sim.defs.weapons.ord_howitzer.range * Skirmish.KITE_RANGE * 0.6
		local tank = Spawn.unit(sim, "chs_ravager", 2, x + brain.toward * near, z)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local spotter = Spawn.unit(sim, "ord_herald", 1, x + brain.toward * near * 0.8, z + 40)
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		run(sim, { brain }, 4, false)
		t.equal(Sensors.level(sim, 1, tank), Sensors.Level.VISIBLE, "the tank is seen")
		local d0 = math.sqrt((w.posX[gun] - w.posX[tank]) ^ 2 + (w.posZ[gun] - w.posZ[tank]) ^ 2)
		local kited = false
		run(sim, { brain }, 90, false, function()
			kited = kited or brain.kiting[gun] ~= nil
			return false
		end)
		return math.sqrt((w.posX[gun] - w.posX[tank]) ^ 2 + (w.posZ[gun] - w.posZ[tank]) ^ 2) - d0, kited
	end

	-- S-17: difficulty levels
	local function levelSim(mapId: string, seed: number, ai: { [number]: string }?): Sim.Sim
		return Sim.new({
			seed = seed,
			players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } },
			mapId = mapId,
			scenario = "standard_start",
			match = { mode = "FFA", win = "COMMAND_ENDS", ai = ai :: any },
		})
	end

	t.test("AI levels are a match option; bad levels and players are refused", function()
		local sim = levelSim("map:ridgeline", 31, { [1] = "hard", [2] = "easy" })
		local brains = Skirmish.forMatch(sim)
		t.equal(#brains, 2)
		t.equal(brains[1].level, "hard")
		t.equal(brains[2].level, "easy")
		t.equal(Skirmish.new(levelSim("map:ridgeline", 31), 1).level, "normal", "the default level")
		t.throws(function()
			levelSim("map:ridgeline", 31, { [1] = "insane" })
		end, "ai level must be")
		t.throws(function()
			levelSim("map:ridgeline", 31, { [7] = "hard" })
		end, "unknown player")
	end)

	t.test("easy: one plant, at most 6 extractors, no radar, anti-air or tech-up", function()
		local sim = levelSim("map:ridgeline", 32)
		local brain = Skirmish.new(sim, 1, "easy")
		run(sim, { brain }, 900 * 8, true)
		t.equal(#owned(sim, 1, "ord_vehplant"), 1, "one Vehicle Plant")
		t.expect(#owned(sim, 1, "ord_extractor") <= 6, `at most 6 extractors ({#owned(sim, 1, "ord_extractor")})`)
		t.expect(#owned(sim, 1, "ord_extractor") >= 4, "but it does build them")
		t.equal(#owned(sim, 1, "ord_advvehplant") + #owned(sim, 1, "ord_watchtower") + #owned(sim, 1, "ord_oracle"), 0, "no tech-up, radar tower or mobile radar")
		-- gentle for a new player (S-57): no attack in the first 8 minutes,
		-- then small waves, an army of at most 12
		t.equal(brain.waves, 0, "no attack before 8 minutes")
		run(sim, { brain }, 900 * 3, true, function()
			return brain.waves >= 1
		end)
		t.expect(brain.waves >= 1, `then it attacks ({brain.waves} waves)`)
		local sent = 0
		for _ in brain.attacking do
			sent += 1
		end
		t.expect(sent <= 4, `a small first wave ({sent} units)`)
		t.expect(#owned(sim, 1, "ord_lancer") + #owned(sim, 1, "ord_verdict") <= Skirmish.LEVELS.easy.maxArmy + 1, "a small army")
	end)

	t.test("normal: its economy keeps up with the plant, and the army comes home against an enemy wave", function()
		local sim = levelSim("map:ridgeline", 34)
		local brain = Skirmish.new(sim, 1, "normal")
		-- (S-94: the plant draws about 3 generators' power at full speed, so
		-- the tanks-first rule gives way to generators while power stalls;
		-- the economy grows and the army follows)
		run(sim, { brain }, 900 * 8, false)
		local army = armyOf(sim, 1)
		t.expect(#owned(sim, 1, "ord_solar") >= 4, `generators keep up with the plant ({#owned(sim, 1, "ord_solar")})`)
		-- (S-230: what it fielded, the units its waves lost included; batch
		-- 1's picks moved seed 34's first wave into the enemy Commander)
		local fielded = army + sim.playerStats[1].unitsLost
		t.expect(fielded >= 8, `an army by 8 minutes ({army} standing, {fielded} fielded)`)
		-- (0.5 since S-114: extractors alternate with generators from the
		-- start, so more is built on about the same power)
		t.expect(sim.eco.accounts[1].power.ratio >= 0.5, `power no longer badly stalled ({sim.eco.accounts[1].power.ratio})`)
		-- send a wave out, then bring an enemy wave to the base
		run(sim, { brain }, 900 * 4, true, function()
			return next(brain.attacking) ~= nil
		end)
		t.expect(next(brain.attacking) ~= nil, "a wave went out")
		local w = sim.world
		local enemies = {}
		for i = 1, 4 do
			-- 220 studs out toward the enemy (inside the recall radius, 45% of the way), side by side
			local id = Spawn.unit(sim, "chs_ravager", 2, brain.homeX + brain.dirX * 220 - brain.dirZ * i * 12, brain.homeZ + brain.dirZ * 220 + brain.dirX * i * 12, 0)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			w.fireState[id] = World.FireState.HOLD_FIRE
			table.insert(enemies, id)
		end
		run(sim, { brain }, 60, true)
		t.equal(next(brain.attacking), nil, "the wave was called home")
		t.expect(brain.recallUntil > sim.tick, "and no new wave leaves while it defends")
	end)

	t.test("hard: turrets, escorted expansions, an airfield with aircraft", function()
		local sim = levelSim("map:ridgeline", 33)
		local brain = Skirmish.new(sim, 1, "hard")
		for i = 1, 4 do -- a few tanks at home, so the first expansion can be escorted
			Spawn.unit(sim, "ord_lancer", 1, brain.homeX + 30, brain.homeZ + (i - 2.5) * 20)
		end
		local escorted = false
		local aircraft = 0
		run(sim, { brain }, 900 * 12, true, function()
			escorted = escorted or next(brain.escorts) ~= nil
			aircraft = #owned(sim, 1, "ord_guardian") + #owned(sim, 1, "ord_absolution") + #owned(sim, 1, "ord_falcon")
			return escorted and aircraft > 0 and #owned(sim, 1, "ord_sentry_tower") >= 2
		end)
		t.expect(#owned(sim, 1, "ord_sentry_tower") >= 2, `laser towers ({#owned(sim, 1, "ord_sentry_tower")})`)
		t.expect(escorted, "army units escorted a worker to a far deposit")
		t.expect(#owned(sim, 1, "ord_airfield") > 0, "an airfield")
		t.expect(aircraft > 0, `and aircraft from it ({aircraft})`)
		print(string.format("    hard: turrets, escort and aircraft by %.1f min", sim.tick / 900))
	end)

	t.test("hard on a naval map: a shipyard and a fleet", function()
		local sim = levelSim("map:coastline", 34)
		local brain = Skirmish.new(sim, 1, "hard")
		t.expect(brain.seaX ~= nil, "it found the sea")
		run(sim, { brain }, 900 * 12, true, function()
			return #owned(sim, 1, "ord_sentry") + #owned(sim, 1, "ord_silence") >= 2
		end)
		t.expect(#owned(sim, 1, "ord_shipyard") > 0, "a shipyard")
		t.expect(#owned(sim, 1, "ord_sentry") + #owned(sim, 1, "ord_silence") >= 2, "ships")
		print(string.format("    hard: a fleet by %.1f min", sim.tick / 900))
	end)

	t.slow("hard beats easy", function()
		local sim = levelSim("map:ridgeline", 9, { [1] = "hard", [2] = "easy" })
		local brains = Skirmish.forMatch(sim)
		run(sim, brains, 900 * 20, false, function()
			return sim.match.over
		end)
		t.expect(sim.match.over and sim.match.winner == 1, `hard won (over {sim.match.over}, winner {sim.match.winner}, {sim.tick / 900} min)`)
	end)

	t.test("AI artillery kites away from a close enemy; tanks don't", function()
		local gained, kited = closing("ord_verdict")
		t.expect(kited, "the Verdict backed off")
		t.expect(gained > 40, `and opened the distance by {gained} studs`)
		local _, tankKited = closing("ord_lancer")
		t.expect(not tankKited, "a Lancer never kites (it moves only with the army)")
	end)

	t.test("a wave outnumbered in the field falls back to the rally point; one that isn't presses on (S-92)", function()
		local function trial(enemies: number): (Skirmish.Brain, { number }, Sim.Sim)
			local sim = start(31)
			local w = sim.world
			local brain = Skirmish.new(sim, 1, "normal")
			-- a wave of 4 Lancers halfway across, 4-plus Ravagers just ahead of it
			local mx, mz = (brain.homeX + brain.enemyX) / 2, (brain.homeZ + brain.enemyZ) / 2
			local wave = {}
			for i = 1, 4 do
				local id = Spawn.unit(sim, "ord_lancer", 1, mx + (i - 2.5) * 14, mz, 0)
				World.setFireState(w, id, World.FireState.HOLD_FIRE)
				brain.attacking[id] = true
				table.insert(wave, id)
			end
			for i = 1, enemies do
				local id = Spawn.unit(sim, "chs_ravager", 2, mx + brain.toward * 150, mz + (i - (enemies + 1) / 2) * 14, 0)
				World.setFireState(w, id, World.FireState.HOLD_FIRE)
			end
			brain.lastWaveAt = sim.tick
			run(sim, { brain }, 60, true)
			return brain, wave, sim
		end
		local brain, wave, sim = trial(10) -- 10 Ravagers (2,600) against 4 Lancers (1,360)
		t.equal(brain.retreats, 1, "the wave fell back")
		for _, id in wave do
			t.equal(brain.attacking[id], nil, "no longer in a wave")
		end
		t.expect(brain.waveValue >= 10 * Skirmish.value(sim.defs.units.chs_ravager) * Skirmish.RETREAT_MARGIN - 1e-6, `the next wave must outweigh what it fled ({brain.waveValue})`)
		local held = trial(3) -- 3 Ravagers (780): it presses on
		t.equal(held.retreats, 0, "a wave that isn't outnumbered keeps going")
	end)

	t.test("T2: the AI builds a T2 builder, a shield and Pinpointers; Order hard a Barrier wall and a Citadel; normal an airfield (S-101)", function()
		local sim = start(41)
		local brains = { Skirmish.new(sim, 1, "hard"), Skirmish.new(sim, 2, "normal") }
		for _, b in brains do
			b.lastRetreatAt = math.huge -- no waves: building, not fighting (Order hard would end Chaos first)
		end
		local seen: { [string]: boolean } = {}
		local want = { { 1, "ord_architect" }, { 1, "ord_phalanx" }, { 1, "ord_witness" }, { 1, "ord_barrier" }, { 1, "ord_citadel" }, { 2, "chs_forgemaster" }, { 2, "chs_carapace" }, { 2, "chs_augur" }, { 2, "chs_airfield" } }
		-- (30 min: since S-108 the T2 builder upgrades its extractors first)
		run(sim, brains, 900 * 30, true, function()
			local all = true
			for _, pair in want do
				local id = pair[2] :: string
				if not seen[id] and #owned(sim, pair[1] :: number, id) > 0 then
					seen[id] = true
				end
				all = all and seen[id] == true
			end
			return all
		end)
		for _, pair in want do
			t.expect(seen[pair[2] :: string], `{pair[2]} built (tick {sim.tick})`)
		end
		print(string.format("    T2 structures by tick %d (%.1f min)", sim.tick, sim.tick / 900))
	end)

	t.slow("T2 extras: extractor upgrades, T2 defences, the anti-nuke umbrella; hard a silo that launches (S-106, S-108, S-110)", function()
		local sim = start(43)
		local brains = { Skirmish.new(sim, 1, "hard"), Skirmish.new(sim, 2, "normal") }
		for _, b in brains do
			b.lastRetreatAt = math.huge -- no waves: building, not fighting (Order hard would end Chaos first)
		end
		local seen: { [string]: boolean } = {}
		local want = {
			{ 1, "ord_advextractor" }, { 1, "ord_bastion" }, { 1, "ord_sanction" }, { 1, "ord_providence" }, { 1, "ord_reckoning" },
			{ 2, "chs_advextractor" }, { 2, "chs_maw" }, { 2, "chs_scourge" }, { 2, "chs_cerberus" },
		}
		-- (40 min since S-216: Hard builds fusion while power stalls and its
		-- gantry before the silo)
		run(sim, brains, 900 * 40, true, function()
			local all = brains[1].nukes > 0
			for _, pair in want do
				local id = pair[2] :: string
				if not seen[id] and #owned(sim, pair[1] :: number, id) > 0 then
					seen[id] = true
				end
				all = all and seen[id] == true
			end
			return all
		end)
		for _, pair in want do
			t.expect(seen[pair[2] :: string], `{pair[2]} built (tick {sim.tick})`)
		end
		t.expect(brains[1].nukes > 0, "Order hard launched a nuke")
		print(string.format("    T2 extras by tick %d (%.1f min); nukes %d", sim.tick, sim.tick / 900, brains[1].nukes))
	end)

	t.slow("the economy governor keeps hard's supply flowing on Supreme Strait (S-221)", function()
		-- Without it, from minute 7 its factories and turrets drew three
		-- times its supply income and everything built at ~3% speed.
		local sim = Sim.new({
			seed = 1,
			players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 3, allyTeam = 2 } },
			mapId = "map:supreme_strait",
			scenario = "standard_start",
			match = { mode = "FFA", win = "COMMAND_ENDS", startMode = "choose", ai = { [1] = "hard", [2] = "hard" } } :: any,
		})
		local brains = Skirmish.forMatch(sim)
		local sum, n, lowSeen = 0, 0, false
		for tick = 1, 14 * 900 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			if tick > 8 * 900 and tick % 5 == 0 then
				sum += sim.eco.accounts[1].supply.ratio
				n += 1
			end
			lowSeen = lowSeen or next(brains[1].lowPriority or {}) ~= nil -- (a stand-in brain until the pre-game ends)
		end
		local avg = sum / n
		print(string.format("    supply ratio, minutes 8-14: %.2f; incomes %.1f supply, %.0f power", avg, brains[1].incS or 0, brains[1].incP or 0))
		t.expect(avg >= 0.3, "supply ratio held at " .. string.format("%.2f", avg)) -- (0.55 with it, about 0.03 without)
		t.expect(lowSeen, "the governor set something to low priority")
	end)
end
