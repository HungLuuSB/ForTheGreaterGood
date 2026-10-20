--!strict
local Combat = require("../Sim/Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local EW = require("../Sim/EW")
local Packer = require("@shared/Net/Packer")
local Registry = require("@shared/Defs/Registry")
local Replay = require("../Sim/Replay")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local L = Sensors.Level
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local MAP = "flat:128"
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

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

-- Registered defs plus neutral test units / weapons derived from existing ones.
local function testDefs(units: { [string]: { from: string, with: { [string]: any } } }, weapons: { [string]: { from: string, with: { [string]: any } } }): Defs.DefSet
	local raw = deepCopy(Registry)
	for name, spec in units do
		local u = Defs.extend(raw.units[spec.from], spec.with)
		u.id = `neu_{name}`
		u.faction = "neutral"
		u.model = u.id
		raw.units[u.id] = u
	end
	for name, spec in weapons do
		local wd = Defs.extend(raw.weapons[spec.from], spec.with)
		wd.id = `neu_{name}`
		raw.weapons[wd.id] = wd
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

local function hold(sim: Sim.Sim, ids: { number })
	for _, id in ids do
		sim.world.fireState[id] = World.FireState.HOLD_FIRE
	end
end

-- An Order Aegis radar SAM site at (-450, 0); a Chaos Wasp hovering at
-- (waspX, 0), seen by an Order spotter 150 studs away (so it is VISIBLE
-- whatever the jammer does to radar); optionally a Chaos Shroud jammer next
-- to the Wasp. Only the SAM may shoot.
local function samScene(seed: number, waspX: number, jammer: boolean, defs: Defs.DefSet?): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = MAP, defs = defs })
	local aegis = Spawn.unit(sim, "ord_aegis", 1, -450, 0)
	local wasp = Spawn.unit(sim, "chs_wasp", 2, waspX, 0)
	hold(sim, { wasp, Spawn.unit(sim, "ord_lancer", 1, waspX, 150) })
	if jammer then
		hold(sim, { Spawn.unit(sim, "chs_shroud", 2, waspX + 20, -40) })
	end
	return sim, aegis, wasp
end

type Tally = { launches: number, hits: number, decoyed: number, lost: number, visible: number }

local function tally(sim: Sim.Sim, shooter: number, target: number, ticks: number): Tally
	local r = { launches = 0, hits = 0, decoyed = 0, lost = 0, visible = 0 }
	for _ = 1, ticks do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.kind == "SPAWN_PROJ" and e.unit == shooter then
				r.launches += 1
			elseif e.kind == "IMPACT" and e.unit == target then
				r.hits += 1
			elseif e.kind == "DECOYED" and e.unit == target then
				r.decoyed += 1
			elseif e.kind == "LOST_LOCK" and e.unit == target then
				r.lost += 1
			end
		end
		if sim.world.slot[target] and Sensors.level(sim, sim.world.team[shooter], target) == L.VISIBLE then
			r.visible += 1
		end
	end
	return r
end

-- Fires weapon `weaponId` straight at `target` from `range` studs away in
-- direction `angle`, owned by `owner` (a team-2 launcher).
local function launchAt(sim: Sim.Sim, owner: number, target: number, weaponId: string, angle: number, range: number): number
	local c, w = sim.combat, sim.world
	local x, z = w.posX[target] + range * sin(angle), w.posZ[target] + range * cos(angle)
	local y = Combat.groundHeight(c, x, z) + 5
	local ty = Combat.unitBase(c, w, target) + c.profiles[w.defIndex[target]].height / 2
	local dx, dy, dz = w.posX[target] - x, ty - y, w.posZ[target] - z
	local d = sqrt(dx * dx + dy * dy + dz * dz)
	local weapon = sim.defs.weapons[weaponId]
	local s = weapon.projectileSpeed :: number
	local ttl = 2 * weapon.range / s + 1
	return Combat.spawnProjectile(c, x, y, z, dx / d * s, dy / d * s, dz / d * s, weapon.index, owner, w.team[owner], ttl, target) :: number
end

-- An aircraft of `defId` (team 1) hovering at the origin with a power
-- generator, so countermeasure upkeep never stalls; health raised so it
-- survives every missile. Returns the sim, the aircraft and a team-2 owner
-- for launched missiles.
local function targetRange(seed: number, defId: string, defs: Defs.DefSet?): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = MAP, defs = defs })
	local target = Spawn.unit(sim, defId, 1, 0, 0)
	Spawn.unit(sim, "ord_generator", 1, -300, 300)
	local owner = Spawn.unit(sim, "chs_thorn", 2, 450, 450)
	hold(sim, { target, owner })
	World.setHealth(sim.world, target, 1e7)
	for _ = 1, 15 do
		Sim.step(sim) -- climb to the hover band
	end
	return sim, target, owner
end

return function(t: RunAll.Context)
	t.test("a jammer protects aircraft from a radar SAM at long range but not inside burn-through", function()
		-- 550 studs, no jammer: launches and hits
		local sim, aegis, wasp = samScene(1, 100, false)
		local burnThrough = EW.burnThroughRange(sim.defs.weapons.ord_radar_sam)
		t.expect(math.abs(burnThrough - 210) < 1e-9, `burn-through is 35% of 600 ({burnThrough})`)
		local open = tally(sim, aegis, wasp, 300)
		t.expect(open.launches > 0 and open.hits > 0, `unjammed at 550: {open.launches} launches, {open.hits} hits`)

		-- 550 studs, jammed: the Wasp is in plain sight, yet no lock, no launch
		sim, aegis, wasp = samScene(1, 100, true)
		local far = tally(sim, aegis, wasp, 300)
		t.equal(far.launches, 0, "jammed at 550: no launch")
		t.expect(far.visible > 280, `the Wasp was VISIBLE to the SAM's team ({far.visible} / 300 ticks)`)
		t.expect(sim.world.slot[wasp] ~= nil, "and survived")

		-- 250 studs (just outside burn-through), jammed: still no launch
		sim, aegis, wasp = samScene(1, -200, true)
		local edge = tally(sim, aegis, wasp, 300)
		t.equal(edge.launches, 0, "jammed at 250: no launch")

		-- 150 studs (inside burn-through), jammed: launches and hits
		sim, aegis, wasp = samScene(1, -300, true)
		local close = tally(sim, aegis, wasp, 300)
		t.expect(close.launches > 0 and close.hits > 0, `jammed at 150: {close.launches} launches, {close.hits} hits`)
		print(`    radar SAM vs jammed Wasp: 550 open {open.launches}/{open.hits}, 550 jammed {far.launches}, 250 jammed {edge.launches}, 150 jammed {close.launches}/{close.hits} (launches/hits)`)
	end)

	t.test("a radar missile loses lock when its target enters a jam field mid-flight", function()
		local sim, aegis, wasp = samScene(2, 100, false)
		local c = sim.combat
		local missile = 0
		for _ = 1, 300 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "SPAWN_PROJ" and e.unit == aegis then
					missile = e.other
				end
			end
			if missile ~= 0 then
				break
			end
		end
		t.expect(missile ~= 0, "the SAM launched")
		-- a jammer drives up and the Wasp sidesteps
		hold(sim, { Spawn.unit(sim, "chs_shroud", 2, 120, -40) })
		moveTo(sim, 2, { wasp }, 100, 300)
		local lostAt, hit = nil, false
		for _ = 1, 60 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "LOST_LOCK" and e.other == missile then
					lostAt = sim.tick
					t.equal(e.unit, wasp, "event names the target")
					t.equal(c.pTarget[missile], 0, "the missile flies on unguided")
					t.expect(bit32.band(c.pFlags[missile], EW.Flag.LOST) ~= 0, "LOST flag")
				elseif e.kind == "IMPACT" and e.other == missile and e.unit == wasp then
					hit = true
				end
			end
		end
		t.expect(lostAt ~= nil, "LOST_LOCK raised")
		t.expect(not hit, "the missile missed")
	end)

	t.test("DIRCM defeats single IR missiles, but a salvo of 4 overwhelms it", function()
		local sim, guardian, owner = targetRange(3, "ord_guardian")
		local dircm = (sim.defs.units.ord_guardian.countermeasures :: any).dircm
		-- singles, 5 s apart (cooldown 3 s)
		local singles = { launches = 0, hits = 0, decoyed = 0 }
		for i = 1, 40 do
			launchAt(sim, owner, guardian, "chs_ir_sam", i * 1.3, 200)
			local r = tally(sim, owner, guardian, 75)
			singles.hits += r.hits
			singles.decoyed += r.decoyed
		end
		t.equal(singles.hits + singles.decoyed, 40, "every missile was either decoyed or hit")
		local rate = singles.decoyed / 40
		t.expect(rate > 0.5, `DIRCM decoyed {singles.decoyed} / 40 singles (chance {dircm.chance})`)

		-- salvos of 4 from four sides, 5 s apart
		local salvoHits, salvoDecoyed = 0, 0
		for i = 1, 20 do
			for k = 0, 3 do
				launchAt(sim, owner, guardian, "chs_ir_sam", i * 0.7 + k * math.pi / 2, 200)
			end
			local r = tally(sim, owner, guardian, 75)
			t.equal(r.hits + r.decoyed, 4, "every salvo missile resolves")
			t.expect(r.decoyed <= 1, `DIRCM defeats at most one missile per salvo ({r.decoyed})`)
			salvoHits += r.hits
			salvoDecoyed += r.decoyed
		end
		t.expect(salvoHits >= 60, `salvos: {salvoHits} / 80 hit`)
		print(`    DIRCM: singles {singles.decoyed}/40 decoyed; salvos of 4: {salvoDecoyed}/80 decoyed, {salvoHits}/80 hit`)
	end)

	t.test("DIRCM recharges only with power", function()
		local sim, guardian, owner = targetRange(4, "ord_guardian")
		launchAt(sim, owner, guardian, "chs_ir_sam", 0, 200)
		tally(sim, owner, guardian, 20)
		t.expect(sim.ew.dircmCooldown[guardian] > 0, "DIRCM engaged and is cooling down")
		tally(sim, owner, guardian, 60)
		t.equal(sim.ew.dircmCooldown[guardian], 0, "recharged within 4 s with power")

		-- the same with the team's power gone: no recharge, so no DIRCM roll
		local stalled, g2, o2 = targetRange(4, "ord_guardian")
		for _, id in stalled.world.ids do
			if stalled.defs.unitByIndex[stalled.world.defIndex[id]].id == "ord_generator" then
				Combat.queueDamage(stalled.combat, id, 1e9, 0)
			end
		end
		stalled.eco.accounts[1].power.stored = 0
		launchAt(stalled, o2, g2, "chs_ir_sam", 0, 200)
		tally(stalled, o2, g2, 20)
		local before = stalled.ew.dircmCooldown[g2]
		tally(stalled, o2, g2, 60)
		t.expect(before > 0 and stalled.ew.dircmCooldown[g2] == before, `no power, no recharge ({stalled.ew.dircmCooldown[g2]})`)
		local r = { decoyed = 0, hits = 0 }
		for i = 1, 10 do
			launchAt(stalled, o2, g2, "chs_ir_sam", i, 200)
			local x = tally(stalled, o2, g2, 30)
			r.decoyed += x.decoyed
			r.hits += x.hits
		end
		t.equal(r.decoyed, 0, "a stalled DIRCM decoys nothing")
		t.equal(r.hits, 10, "every missile hits")
	end)

	t.test("flares and chaff spend charges, each only against its own guidance", function()
		local defs = testDefs({
			decoy_heli = {
				from = "chs_wasp",
				with = { countermeasures = { flares = { charges = 2, chance = 1 }, chaff = { charges = 2, chance = 1 } } },
			},
		}, {})
		local sim, heli, owner = targetRange(5, "neu_decoy_heli", defs)
		local e = sim.ew
		t.equal(e.flares[heli], 2)
		t.equal(e.chaff[heli], 2)
		local ir = { decoyed = 0, hits = 0 }
		for i = 1, 3 do
			launchAt(sim, owner, heli, "chs_ir_sam", i, 200)
			local r = tally(sim, owner, heli, 45)
			ir.decoyed += r.decoyed
			ir.hits += r.hits
		end
		t.equal(ir.decoyed, 2, "two flares, two IR missiles decoyed")
		t.equal(ir.hits, 1, "the third IR missile hits")
		t.equal(e.flares[heli], 0, "flares used up")
		t.equal(e.chaff[heli], 2, "chaff untouched by IR missiles")
		launchAt(sim, owner, heli, "ord_radar_sam", 0, 300)
		local r = tally(sim, owner, heli, 45)
		t.equal(r.decoyed, 1, "chaff decoys the radar missile")
		t.equal(e.chaff[heli], 1, "one chaff charge spent")
		EW.refill(sim, heli)
		t.equal(e.flares[heli], 2, "rearming refills flares")
		t.equal(e.chaff[heli], 2, "and chaff")
	end)

	t.test("lock rules: IR ignores jamming, stealth shortens radar lock, IR needs sight", function()
		local defs = testDefs({
			stealth_heli = { from = "chs_wasp", with = { sensors = { radarSignature = 0.3 } } },
		}, {})
		-- jammed Wasp at (400, 0) with a Vigil 250 studs south; a plain and a
		-- stealthy Wasp about 300 studs from the Aegis, far from the jammer
		local sim, aegis, wasp = samScene(6, 400, true, defs)
		local vigil = Spawn.unit(sim, "ord_vigil", 1, 400, -250)
		local stealth = Spawn.unit(sim, "neu_stealth_heli", 2, -150, 60)
		local plain = Spawn.unit(sim, "chs_wasp", 2, -150, -40)
		local blip = Spawn.unit(sim, "chs_wasp", 2, -450, -300) -- only on the Aegis's radar
		hold(sim, { aegis, vigil, stealth, plain, blip, Spawn.unit(sim, "ord_lancer", 1, -150, 120) })
		for _ = 1, 10 do
			Sim.step(sim)
		end
		local ws = sim.defs.weapons
		local function dist(a: number, b: number): number
			return sqrt((sim.world.posX[a] - sim.world.posX[b]) ^ 2 + (sim.world.posZ[a] - sim.world.posZ[b]) ^ 2)
		end
		-- IR vs the jammed Wasp 250 studs away: locks; radar from the same spot: jammed beyond 210
		t.equal(Sensors.level(sim, 1, wasp), L.VISIBLE)
		t.expect(EW.canLock(sim, vigil, ws.ord_ir_sam, wasp, dist(vigil, wasp)), "IR locks a jammed target")
		t.expect(not EW.canLock(sim, vigil, ws.ord_radar_sam, wasp, dist(vigil, wasp)), "radar can't lock it at 250")
		-- stealth: 300 studs from the Aegis; lock range 600 × 0.3 = 180
		t.expect(EW.canLock(sim, aegis, ws.ord_radar_sam, plain, dist(aegis, plain)), "radar locks a plain Wasp at 300")
		t.expect(not EW.canLock(sim, aegis, ws.ord_radar_sam, stealth, dist(aegis, stealth)), "but not a stealthy one")
		t.expect(EW.canLock(sim, aegis, ws.ord_radar_sam, stealth, 170), "inside 180 it does")
		t.expect(not EW.canLock(sim, aegis, ws.ord_ir_sam, stealth, 400), "IR needs its own lock range")
		-- a radar-only contact: radar missiles may lock it, IR seekers can't
		t.equal(Sensors.level(sim, 1, blip), L.RADAR)
		t.expect(EW.canLock(sim, aegis, ws.ord_radar_sam, blip, dist(aegis, blip)), "radar locks a radar contact")
		t.expect(not EW.canLock(sim, aegis, ws.ord_ir_sam, blip, 200), "IR needs the target VISIBLE")

	end)

	t.test("COMMAND guidance needs only a live launcher and sight of the target", function()
		local defs = testDefs({
			decoy_heli = {
				from = "chs_wasp",
				with = {
					countermeasures = {
						flares = { charges = 4, chance = 1 },
						chaff = { charges = 4, chance = 1 },
						dircm = { chance = 1, cooldown = 1, powerDrain = 0 },
					},
				},
			},
		}, {
			cmd_sam = { from = "ord_radar_sam", with = { guidance = "COMMAND" } },
		})
		-- target under a Chaos jammer whose field also covers the launcher;
		-- an Order spotter keeps it VISIBLE
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = MAP, defs = defs })
		local c = sim.combat
		local target = Spawn.unit(sim, "neu_decoy_heli", 2, 0, 0)
		World.setHealth(sim.world, target, 1e7)
		hold(sim, { target, Spawn.unit(sim, "chs_shroud", 2, 20, -40) })
		for _ = 1, 15 do
			Sim.step(sim)
		end
		-- kill: "launcher" or "spotter" dies on the first tick of the flight
		local function shot(kill: string?): { lost: boolean, hit: boolean, decoyed: boolean }
			local tx, tz = sim.world.posX[target], sim.world.posZ[target]
			local launcher = Spawn.unit(sim, "ord_aegis", 1, -250, 0)
			local spotter = Spawn.unit(sim, "ord_lancer", 1, tx, tz + 120)
			hold(sim, { launcher, spotter })
			for _ = 1, 4 do
				Sim.step(sim) -- the spotter's sight is stamped
			end
			t.equal(Sensors.level(sim, 1, target), L.VISIBLE, "the target is VISIBLE before launch")
			t.expect(EW.jammed(sim, target) and EW.canLock(sim, launcher, sim.defs.weapons.neu_cmd_sam, target, 250), "jamming doesn't stop a COMMAND lock")
			local m = launchAt(sim, launcher, target, "neu_cmd_sam", -math.pi / 2, 240)
			moveTo(sim, 2, { target }, tx, tz - 100) -- sidestep: only a guided missile still hits
			if kill == "launcher" then
				Combat.queueDamage(c, launcher, 1e9, 0)
			elseif kill == "spotter" then
				Combat.queueDamage(c, spotter, 1e9, 0)
			end
			local r = { lost = false, hit = false, decoyed = false }
			for _ = 1, 45 do
				Sim.step(sim)
				for _, e in c.events do
					if e.other == m then
						r.lost = r.lost or e.kind == "LOST_LOCK"
						r.decoyed = r.decoyed or e.kind == "DECOYED"
						r.hit = r.hit or (e.kind == "IMPACT" and e.unit == target)
					end
				end
			end
			for _, id in { launcher, spotter } do
				if sim.world.slot[id] then
					Combat.queueDamage(c, id, 1e9, 0)
				end
			end
			Sim.step(sim)
			return r
		end
		local ok = shot(nil)
		t.expect(ok.hit and not ok.lost and not ok.decoyed, "guided all the way: hits through jamming and every countermeasure")
		t.equal(sim.ew.flares[target], 4, "no flares used")
		t.equal(sim.ew.chaff[target], 4, "no chaff used")
		local noLauncher = shot("launcher")
		t.expect(noLauncher.lost and not noLauncher.hit, "launcher killed: LOST_LOCK, miss")
		local noSight = shot("spotter")
		t.expect(noSight.lost and not noSight.hit, "sight lost: LOST_LOCK, miss")
	end)

	t.test("EW replays stay deterministic", function()
		local original = Sim.new({ seed = 77, players = PLAYERS, mapId = MAP, scenario = "ew_test" })
		local wasp = 0
		for _, id in original.world.ids do
			if original.defs.unitByIndex[original.world.defIndex[id]].id == "chs_wasp" then
				wasp = id
			end
		end
		local counts = { DECOYED = 0, LOST_LOCK = 0, SPAWN_PROJ = 0 }
		for tick = 1, 600 do
			if tick == 30 then
				moveTo(original, 2, { wasp }, -300, 0) -- into burn-through range
			elseif tick == 300 then
				moveTo(original, 2, { wasp }, 150, 0)
			end
			Sim.step(original)
			for _, e in original.combat.events do
				if counts[e.kind] then
					counts[e.kind] += 1
				end
			end
		end
		t.expect(counts.SPAWN_PROJ > 0 and counts.DECOYED > 0, `the scenario exercised EW ({counts.SPAWN_PROJ} launches, {counts.DECOYED} decoyed, {counts.LOST_LOCK} lost)`)
		local log = Replay.parse(Replay.serialize(original.replay))
		local replayed, mismatch = Sim.runReplay(log, 600)
		t.equal(mismatch, nil, "checkpoint mismatch")
		t.equal(Sim.hash(replayed), Sim.hash(original), "final hash")
	end)
end
