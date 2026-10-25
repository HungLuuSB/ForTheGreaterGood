--!strict
-- Shield dome generators (S-79, client request 40): Sim/Shield and
-- Shared/Combat/ShieldField, and the dome on the wire (protocol 24).
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local ShieldField = require("@shared/Combat/ShieldField")
local Combat = require("../Sim/Combat/Combat")
local Shield = require("../Sim/Shield")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CX, CZ = 0, -150 -- the dome's spot, as in the client's "shield" profile (C-89)

-- An Order Phalanx at (CX, CZ) on flat:128, at `fraction` charge.
local function dome(seed: number, fraction: number?): (Sim.Sim, number)
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local gen = Spawn.unit(sim, "ord_phalanx", 1, CX, CZ)
	if fraction then
		sim.combat.shieldCharge[gen] = sim.defs.units.ord_phalanx.shield.capacity * fraction
	end
	return sim, gen
end

-- A shell of `weaponId` from (x, 20, z), on the low arc that lands on the
-- dome's centre (straight at it without gravity), for `team`'s side. A
-- shell that can't carry that far (the S-179 mortar: 112 studs/s, about 209
-- studs at most) starts closer on the same bearing, at 0.9 × its reach.
local function fire(sim: Sim.Sim, weaponId: string, x: number, z: number, side: number?): number
	local weapon = sim.defs.weapons[weaponId]
	local g = weapon.gravity or 0
	if weapon.type == "BOMB" then
		-- dropped 200 studs above the dome's top, drifting at 8 studs/s
		return Combat.spawnProjectile(sim.combat, CX + 20, 320, CZ + 40, 0, 0, -8, weapon.index, 0, side or 2, 10) :: number
	end
	local speed = weapon.projectileSpeed or 300
	local dx, dz = CX - x, CZ - z
	local d = math.sqrt(dx * dx + dz * dz)
	local reach = if g > 0 then 0.9 * speed ^ 2 / g else math.huge
	if d > reach then
		dx, dz = dx / d * reach, dz / d * reach
		x, z, d = CX - dx, CZ - dz, reach
	end
	local a = if g > 0 then 0.5 * math.asin(math.min(1, g * d / speed ^ 2)) else 0
	local vh = speed * math.cos(a)
	return Combat.spawnProjectile(sim.combat, x, 20, z, dx / d * vh, speed * math.sin(a), dz / d * vh, weapon.index, 0, side or 2, 10) :: number
end

-- Steps until projectile `p` is gone (at most `ticks`); returns its
-- SHIELD_HIT event (or nil) and where it burst.
local function follow(sim: Sim.Sim, p: number, ticks: number?): (any, { number }?)
	local hit, burst = nil, nil
	for _ = 1, ticks or 200 do
		Sim.step(sim)
		for _, e in sim.combat.events do
			if e.other == p and e.kind == "SHIELD_HIT" then
				hit = e
			elseif e.other == p and e.kind == "IMPACT" then
				burst = { e.x :: number, e.y :: number, e.z :: number }
			end
		end
		if sim.combat.projSlot[p] == nil then
			break
		end
	end
	return hit, burst
end

local function near(t: RunAll.Context, actual: number, expected: number, tolerance: number, message: string)
	t.expect(math.abs(actual - expected) <= tolerance, `{message}: {actual}, expected {expected} ± {tolerance}`)
end

local function distance(x: number, z: number): number
	return math.sqrt((x - CX) ^ 2 + (z - CZ) ^ 2)
end

local ALL_WEIGHTS = { "chs_mg", "chs_autocannon", "chs_mlrs", "chs_light_cannon", "chs_rockets", "chs_heavy_cannon", "chs_mortar", "chs_heavy_bomb", "chs_siege_mortar", "chs_radar_sam" }

-- Runs `fn` with the braking field on (S-93 destroys every projectile at
-- the surface; the field of S-79..S-85 stays behind ShieldField.ABSORB_MASS
-- and these tests keep it working).
local function fieldOn(fn: () -> ()): () -> ()
	return function()
		local saved = ShieldField.ABSORB_MASS
		ShieldField.ABSORB_MASS = 0.5
		local ok, err = pcall(fn)
		ShieldField.ABSORB_MASS = saved
		if not ok then
			error(err, 0)
		end
	end
end

return function(t: RunAll.Context)
	t.test("a charged dome turns every shell weight back, or destroys light ones; turned shells burst outside, live", fieldOn(function()
		for _, weaponId in ALL_WEIGHTS do
			local sim, gen = dome(1)
			local w = sim.world
			local health = w.health[gen]
			local p = fire(sim, weaponId, 0, 250)
			local hit, burst = follow(sim, p)
			if Shield.mass(sim.defs.weapons[weaponId]) < ShieldField.ABSORB_MASS then
				-- light: destroyed at the surface, no burst (S-85)
				t.expect(hit ~= nil and hit.absorbed == true and hit.unit == gen, `{weaponId}: destroyed at the surface`)
				t.equal(burst, nil, `{weaponId}: no burst`)
				t.equal(sim.combat.projSlot[p], nil, `{weaponId}: gone`)
				continue
			end
			t.expect(hit ~= nil and hit.breach == false and not hit.absorbed and hit.unit == gen, `{weaponId}: turned back`)
			-- outside the core: the field's pull down (S-84) may land it in the band
			local gx, _, gz = Shield.center(sim, gen)
			local core = sim.defs.units.ord_phalanx.shield.radius * (1 - ShieldField.BAND_SHARE)
			t.expect(burst ~= nil and math.sqrt((burst[1] - gx) ^ 2 + (burst[3] - gz) ^ 2) > core, `{weaponId}: burst outside the dome's core`)
			t.equal(w.health[gen], health, `{weaponId}: the generator took nothing`)
			if hit then
				local gx, gy, gz = Shield.center(sim, gen) -- the generator snaps to its footprint
				near(t, math.sqrt((hit.x - gx) ^ 2 + (hit.y - gy) ^ 2 + (hit.z - gz) ^ 2), 120, 0.01, `{weaponId}: the hit point is on the dome`)
			end
		end
	end))

	t.test("a turned shell explodes where it lands and hurts what it lands on", fieldOn(function()
		local sim = dome(2)
		local w = sim.world
		-- a mortar shell from the north turns back north: a Chaos tank waits there
		local p = fire(sim, "chs_mortar", 0, 250)
		local _, burst = follow(sim, p)
		assert(burst, "it burst")
		local sim2 = dome(2)
		local tank = Spawn.unit(sim2, "chs_ravager", 2, burst[1], burst[3])
		World.setFireState(sim2.world, tank, World.FireState.HOLD_FIRE)
		local full = sim2.world.health[tank]
		local p2 = fire(sim2, "chs_mortar", 0, 250)
		follow(sim2, p2)
		t.expect(sim2.world.health[tank] < full, `the shell came down on its own side's tank ({full} → {sim2.world.health[tank]})`)
		local _ = w
	end))

	t.test("heavier shells take longer to stop: they turn deeper in the field", fieldOn(function()
		local function turnAt(mass: number): number
			-- straight down onto the top of a dome of radius 120 at 240 studs/s
			local x, y, z, vx, vy, vz = 0, 175, 0, 0, -240, 0
			local phase = ShieldField.FREE
			for _ = 1, 60 do
				local event
				x, y, z, vx, vy, vz, phase, event = ShieldField.step(x, y, z, vx, vy, vz, 0, 0, 0, 0, 120, 1, mass, phase, 1 / 15)
				if event == ShieldField.TURN then
					return y
				end
			end
			return 0
		end
		local light, medium, heavy = turnAt(0.6), turnAt(1), turnAt(6)
		local core = 120 * (1 - ShieldField.BAND_SHARE)
		t.expect(light < 120 and light > medium and medium > heavy and heavy > core, `turn heights {light}, {medium}, {heavy} (inside the dome: surface 120, core {core})`)
	end))

	t.test("head-on shells stop and come back; off-centre ones bend round the dome and carry on (S-82)", fieldOn(function()
		-- parallel shots up at a dome of radius 120, offset from its centre;
		-- returns the angle between the way out and the way in, the speed kept
		-- and whether it broke through
		local function shot(offset: number, mass: number, speed: number): (number, number, boolean)
			local x, y, z, vx, vy, vz = offset * 120, -200, 0, 0, speed, 0
			local phase, breach = ShieldField.FREE, false
			for _ = 1, 400 do
				local event
				x, y, z, vx, vy, vz, phase, event = ShieldField.step(x, y, z, vx, vy, vz, 0, 0, 0, 0, 120, 1, mass, phase, 1 / 15)
				breach = breach or event == ShieldField.BREACH
				if phase == ShieldField.DONE then
					break
				end
			end
			local s = math.sqrt(vx * vx + vy * vy)
			return math.deg(math.acos(math.clamp(vy / s, -1, 1))), s / speed, breach
		end
		local last = 181
		for _, offset in { 0, 0.3, 0.5, 0.7, 0.85, 0.95 } do
			local angle, keep, breach = shot(offset, 1, 260)
			t.equal(breach, false, `offset {offset}: turned`)
			t.expect(angle < last, `offset {offset}: bent less than a shot nearer the centre ({angle}° after {last}°)`)
			t.expect(keep > 0.25 and keep < 0.97, `offset {offset}: slowed, keeping {keep * 100}%`)
			last = angle
		end
		t.expect(shot(0, 1, 260) > 179, "head-on: straight back")
		t.expect(shot(0.7, 1, 260) < 60 and shot(0.95, 1, 260) < 30, "glancing: steered off, carrying on forward")
		for _, mass in { 0.6, 2.4, 8 } do
			local headOn, _, through = shot(0, mass, 240)
			t.expect(headOn > 179 and not through, `mass {mass} at 240 studs/s head-on: straight back`)
			t.expect(shot(0.85, mass, 420) < 40, `mass {mass} at 420 studs/s, glancing: carries on`)
		end
		-- a shot whose line misses the dome is left alone
		local angle, keep = shot(1.2, 1, 260)
		t.expect(angle < 1e-6 and math.abs(keep - 1) < 1e-9, "a line past the dome: untouched")
	end))

	t.test("flat head-on shots near the ground turn and fly back (the client's ShieldWire case)", fieldOn(function()
		-- a Ravager firing straight at a Mason under the dome, low over flat
		-- ground: slowed almost to a stop, gravity bends them down, and they
		-- used to sink through the band without ever turning
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_phalanx", 1, 0, -100)
		local mason = Spawn.unit(sim, "ord_mason", 1, 0, -40)
		World.setHealth(w, mason, 1e6)
		-- in range of the Mason from outside the dome (S-185: a Maneuver unit
		-- no longer drives 80 studs on its own to get a shot)
		local reach = sim.defs.weapons[sim.defs.units.chs_ravager.weapons[1].def].range
		Spawn.unit(sim, "chs_ravager", 2, 0, -40 + reach * 0.9, math.pi)
		local c = sim.combat
		local turned, through, back, landed, inCore = 0, 0, 0, 0, 0
		local watch: { [number]: boolean } = {}
		local gx, _, gz = Shield.center(sim, gen)
		local core = sim.defs.units.ord_phalanx.shield.radius * (1 - ShieldField.BAND_SHARE)
		for _ = 1, 180 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "SHIELD_HIT" and e.unit == gen then
					if e.breach then
						through += 1
					else
						turned += 1
						watch[e.other] = true
					end
				elseif e.kind == "IMPACT" and watch[e.other] then
					-- pulled down in the field (S-84), some land in the band
					landed += 1
					watch[e.other] = nil
					if math.sqrt((e.x :: number - gx) ^ 2 + (e.z :: number - gz) ^ 2) <= core then
						inCore += 1
					end
				end
			end
			for p in watch do
				if c.projSlot[p] and c.pShieldPhase[p] == nil and c.pvz[p] > 50 then
					back += 1 -- out of the field, flying back north toward the Ravager
					watch[p] = nil
				end
			end
		end
		t.expect(turned >= 2, `shells turned ({turned})`)
		t.equal(through, 0, "none broke through")
		t.expect(back + landed >= turned - 1, `turned shells fly back or land, none hang ({back} back, {landed} landed of {turned})`)
		t.equal(inCore, 0, "none landed in the core")
	end))

	t.test("every shell weight is destroyed where it reaches the dome: no burst, its mass in charge (S-93)", function()
		for _, weaponId in ALL_WEIGHTS do
			local sim, gen = dome(15, 0.5)
			local c = sim.combat
			local p = fire(sim, weaponId, 0, 250)
			local hit, drop, impacts = nil, 0, 0
			for _ = 1, 200 do
				local prev = c.shieldCharge[gen]
				Sim.step(sim)
				for _, e in c.events do
					if e.other == p and e.kind == "SHIELD_HIT" then
						hit = e
						drop = prev - c.shieldCharge[gen]
					elseif e.other == p and e.kind == "IMPACT" then
						impacts += 1
					end
				end
				if c.projSlot[p] == nil then
					break
				end
			end
			local mass = Shield.mass(sim.defs.weapons[weaponId])
			t.expect(hit ~= nil and hit.absorbed == true and not hit.breach, `{weaponId}: destroyed at the surface`)
			t.equal(impacts, 0, `{weaponId}: no burst`)
			near(t, drop, Shield.HIT_COST * mass - sim.defs.units.ord_phalanx.shield.recharge / 15, 0.01, `{weaponId}: its mass in charge`)
			if hit then
				local gx, gy, gz = Shield.center(sim, gen)
				near(t, math.sqrt((hit.x - gx) ^ 2 + (hit.y - gy) ^ 2 + (hit.z - gz) ^ 2), 120, 0.01, `{weaponId}: on the surface`)
			end
		end
	end)

	t.test("light shells are destroyed at the surface: charge by mass, no burst, the client drops them (S-85)", function()
		local sim, gen = dome(13, 0.5)
		local c = sim.combat
		local g = (sim.map :: any).grid
		local cx, cz = g:cellAt(0, 50)
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = cx - 20, minZ = cz - 20, maxX = cx + 20, maxZ = cz + 20 })
		assert(Sim.submit(sim, 1, w:finish()))
		local view = Client.new(g, sim.defs, (sim.map :: any).layers)
		local weapon = sim.defs.weapons.chs_autocannon
		local mass = Shield.mass(weapon)
		t.expect(mass < ShieldField.ABSORB_MASS, "the autocannon round is light")
		local p = fire(sim, "chs_autocannon", 0, 250)
		local hit, drop, impacts, wireHit = nil, 0, 0, nil
		local recharge = sim.defs.units.ord_phalanx.shield.recharge
		for _ = 1, 60 do
			local prev = c.shieldCharge[gen]
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
			for _, e in c.events do
				if e.other == p and e.kind == "SHIELD_HIT" then
					hit = e
					drop = prev - c.shieldCharge[gen]
				elseif e.other == p and e.kind == "IMPACT" then
					impacts += 1
				end
			end
			for _, e in view.effects do
				if e.kind == "shield" then
					wireHit = e
				end
			end
			table.clear(view.effects)
			if hit then
				break
			end
		end
		t.expect(hit ~= nil and hit.absorbed == true, "SHIELD_HIT, absorbed")
		local gx, gy, gz = Shield.center(sim, gen)
		near(t, math.sqrt((hit.x - gx) ^ 2 + (hit.y - gy) ^ 2 + (hit.z - gz) ^ 2), 120, 0.01, "on the surface")
		near(t, drop, Shield.HIT_COST * mass - recharge / 15, 0.01, "its mass in charge (less a tick's recharge)")
		t.equal(impacts, 0, "no burst")
		t.equal(c.projSlot[p], nil, "the projectile is gone")
		t.expect(wireHit ~= nil and wireHit.absorbed == true, "the client got SHIELD_HIT with ABSORBED")
		t.equal(view.projectiles[p], nil, "and dropped the shell")
	end)

	t.test("hitscan from outside is stopped at the dome's surface; from inside it passes (S-89)", function()
		local sim, gen = dome(14)
		local w = sim.world
		local c = sim.combat
		local gx, gy, gz = Shield.center(sim, gen)
		-- a wall just inside the dome's edge, and a Minotaur just outside with
		-- its demolition charge (hitscan, 30 studs) in reach of it
		local wall = Spawn.unit(sim, "ord_barrier", 1, gx, gz + 108)
		local ram = Spawn.unit(sim, "chs_minotaur", 2, gx, gz + 134, math.pi)
		local stopped, through = 0, 0
		for _ = 1, 450 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "SHIELD_HIT" and e.other == 0 then
					stopped += 1
					t.equal(e.absorbed, true, "a hitscan stop is absorbed")
					near(t, math.sqrt((e.x - gx) ^ 2 + (e.y - gy) ^ 2 + (e.z - gz) ^ 2), 120, 0.01, "on the surface")
				elseif e.kind == "FIRE" and e.unit == ram and e.hit then
					through += 1
				end
			end
		end
		t.expect(stopped >= 1, `the demolition charge was stopped ({stopped})`)
		t.equal(through, 0, "no hitscan hit got through")
		-- (the Minotaur's siege cannon may still reach the wall: it stands in
		-- the field's band, S-83)
		local _ = wall
		-- inside the dome the same charge hits (the shield stops shots from outside only)
		local target = Spawn.unit(sim, "ord_barrier", 1, gx + 40, gz + 60)
		local full = w.health[target]
		local inside = Spawn.unit(sim, "chs_minotaur", 2, gx + 40, gz + 85, math.pi)
		local hits = 0
		for _ = 1, 450 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "FIRE" and e.unit == inside and e.hit then
					hits += 1
				end
			end
		end
		t.expect(hits >= 1 and (w.health[target] or 0) < full, `from inside it hits ({hits})`)
		-- the geometry itself: a shot that misses the dome passes
		t.equal((Shield.intercept(sim, 2, gx + 200, 10, gz, gx + 200, 10, gz + 300, sim.defs.weapons.chs_flak)), 0, "a line clear of the dome")
	end)

	t.test("below half charge heavy shells break through, slowed; light ones still turn", fieldOn(function()
		local sim, gen = dome(3, 0.06)
		local light = fire(sim, "chs_autocannon", 0, 250)
		local hitLight = follow(sim, light)
		t.expect(hitLight ~= nil and not hitLight.breach, "the autocannon round was stopped (destroyed at the surface, S-85)")
		sim.combat.shieldCharge[gen] = 0.06 * sim.defs.units.ord_phalanx.shield.capacity -- it recharged meanwhile
		local heavy = fire(sim, "chs_siege_mortar", 0, 250)
		local entry, through = 0, nil
		local hit, drop = nil, 0
		for _ = 1, 200 do
			local prev = sim.combat.shieldCharge[gen]
			Sim.step(sim)
			local c = sim.combat
			if c.projSlot[heavy] == nil then
				break
			end
			local speed = math.sqrt(c.pvx[heavy] ^ 2 + c.pvy[heavy] ^ 2 + c.pvz[heavy] ^ 2)
			for _, e in c.events do
				if e.kind == "SHIELD_HIT" and e.other == heavy then
					hit = e
					through = speed
					drop = prev - c.shieldCharge[gen]
				end
			end
			if c.pShield[heavy] == nil and hit == nil then
				entry = speed
			end
		end
		t.expect(hit ~= nil and hit.breach == true, "the siege shell broke through")
		t.expect(through ~= nil and through < entry * 0.9, `slowed ({entry} → {through})`) -- 0.80 with the footprint-3 Phalanx (S-104); 0.87 at S-150's capacity (the breach drains the smaller dome as it goes)
		local def = sim.defs.units.ord_phalanx.shield
		near(t, drop, Shield.BREACH_COST * Shield.mass(sim.defs.weapons.chs_siege_mortar) - def.recharge / 15, 0.01, "a breach costs half the shell's mass (less a tick's recharge)")
		t.equal(ShieldField.force(0.5), 1, "full force at 50%")
		t.equal(ShieldField.force(0.25), 0.5, "half force at 25%")
	end))

	t.test("hits drain the charge by mass; at 0 the dome falls and shells pass; it rises at 25% on power", function()
		local sim, gen = dome(4)
		local c = sim.combat
		local cap = sim.defs.units.ord_phalanx.shield.capacity
		local p = fire(sim, "chs_mortar", 0, 250)
		local mass = Shield.mass(sim.defs.weapons.chs_mortar)
		local recharge = sim.defs.units.ord_phalanx.shield.recharge
		c.shieldCharge[gen] = cap / 2 -- below full, so the tick's recharge shows apart from the hit
		local drop = nil
		for _ = 1, 100 do
			local prev = c.shieldCharge[gen]
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "SHIELD_HIT" and e.other == p then
					drop = prev - c.shieldCharge[gen]
				end
			end
		end
		near(t, drop or 0, Shield.HIT_COST * mass - recharge / 15, 0.01, "one mortar shell's mass gone (less a tick's recharge)")
		near(t, c.shieldCharge[gen], cap / 2 + 100 * recharge / 15 - Shield.HIT_COST * mass, 1e-6, "recharging at the full rate since")
		-- run it down: power cut off, a nearly empty dome, shells until it falls
		local acc = sim.eco.accounts[1]
		acc.power.stored = 0
		acc.power.storage = 0
		c.shieldCharge[gen] = 6
		local fell = false
		for i = 1, 200 do
			local q = fire(sim, "chs_heavy_cannon", (i % 7 - 3) * 30, 250)
			follow(sim, q)
			if not c.shieldUp[gen] then
				fell = true
				break
			end
		end
		t.expect(fell, "the dome collapsed")
		t.equal(c.shieldCharge[gen], 0, "at 0")
		local q = fire(sim, "chs_light_cannon", 0, 250)
		local passHit, burst = follow(sim, q)
		t.equal(passHit, nil, "a shell passes a fallen dome untouched")
		t.expect(burst ~= nil and distance(burst[1], burst[3]) < 40, "and lands near the centre")
		for _ = 1, 150 do
			Sim.step(sim)
		end
		t.expect(c.shieldCharge[gen] < 0.05 * cap and not c.shieldUp[gen], "no power: no recharge")
		t.equal(Shield.recharging(sim, gen), false, "not recharging without power")
		acc.power.storage = 1e6
		acc.power.stored = 1e6
		local rose = 0
		for i = 1, 600 do
			Sim.step(sim)
			if c.shieldUp[gen] then
				rose = i
				break
			end
		end
		t.expect(rose > 0, "it rose again")
		near(t, c.shieldCharge[gen] / cap, Shield.RAISE_AT, 0.01, "at 25%")
		t.expect(Shield.recharging(sim, gen), "recharging on power")
	end)

	t.test("recharging draws the def's power only while below capacity", function()
		local sim, gen = dome(5, 0.5)
		local acc = sim.eco.accounts[1]
		acc.power.storage, acc.power.stored = 1e6, 1e6
		for _ = 1, 15 do
			Sim.step(sim)
		end
		local def = sim.defs.units.ord_phalanx.shield
		near(t, acc.power.demand, def.power, 1e-9, "the dome's draw while recharging")
		t.equal(sim.combat.shieldPower[gen], 1, "fully powered")
		sim.combat.shieldCharge[gen] = def.capacity
		for _ = 1, 15 do
			Sim.step(sim)
		end
		near(t, acc.power.demand, 0, 1e-9, "nothing when full")
	end)

	t.test("only enemy shells: allies' pass over, shots from inside pass out", function()
		local sim = dome(6)
		local ally = fire(sim, "chs_mortar", 0, 250, 1) -- side 1: the dome's own
		local hit, burst = follow(sim, ally)
		t.equal(hit, nil, "an allied shell isn't touched")
		t.expect(burst ~= nil and distance(burst[1], burst[3]) < 40, "it lands where aimed")
		-- an enemy gun inside the dome shoots out
		local sim2 = dome(7)
		local weapon = sim2.defs.weapons.chs_heavy_cannon
		local out = Combat.spawnProjectile(sim2.combat, CX, 10, CZ + 30, 0, 20, 420, weapon.index, 0, 2, 3) :: number
		local hit2 = follow(sim2, out)
		t.equal(hit2, nil, "a shell fired from inside passes out freely")
	end)

	t.test("a built generator starts empty and down, then charges up on power", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:128" })
		local gen = Spawn.unit(sim, "ord_phalanx", 1, CX, CZ)
		-- as a construction frame enters (Build's frames start at progress 0)
		Shield.removed(sim, gen)
		World.setBuildProgress(sim.world, gen, 0)
		Shield.added(sim, gen)
		local c = sim.combat
		t.equal(c.shieldCharge[gen], 0, "empty")
		t.equal(c.shieldUp[gen], false, "down")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		t.equal(c.shieldCharge[gen], 0, "no charge while unbuilt")
		World.setBuildProgress(sim.world, gen, 1)
		local acc = sim.eco.accounts[1]
		acc.power.storage, acc.power.stored = 1e6, 1e6
		for _ = 1, 15 do
			Sim.step(sim)
		end
		near(t, c.shieldCharge[gen], sim.defs.units.ord_phalanx.shield.recharge, 0.1, "a second's recharge")
	end)

	t.test("the wire: SHIELD after ENTER and on change, SHIELD_FIELD and SHIELD_HIT; the client's field matches", fieldOn(function()
		local sim, gen = dome(9)
		local g = (sim.map :: any).grid
		local cx, cz = g:cellAt(0, 50)
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = cx - 20, minZ = cz - 20, maxX = cx + 20, maxZ = cz + 20 })
		assert(Sim.submit(sim, 1, w:finish()))
		local view = Client.new(g, sim.defs, (sim.map :: any).layers)
		Sim.step(sim)
		Client.receive(view, sim.net.players[1].outbox)
		t.expect(view.units[gen] ~= nil, "the generator is tactical (its dome reaches the camera)")
		local s = view.shields[gen]
		t.expect(s ~= nil and s.charge == 255 and s.flags == Schema.ShieldFlag.UP, "SHIELD after ENTER: full, up, not recharging")
		-- half drained: a SHIELD with the charge, recharging
		sim.combat.shieldCharge[gen] = sim.defs.units.ord_phalanx.shield.capacity / 2
		local acc = sim.eco.accounts[1]
		acc.power.storage, acc.power.stored = 1e6, 1e6
		Sim.step(sim)
		Client.receive(view, sim.net.players[1].outbox)
		near(t, view.shields[gen].charge, 128, 2, "SHIELD on the change")
		t.equal(view.shields[gen].flags, Schema.ShieldFlag.UP + Schema.ShieldFlag.RECHARGING, "up, recharging")
		local half = view.shields[gen].charge
		local p = fire(sim, "chs_mortar", 0, 250)
		local worst, fieldTicks, hits = 0, 0, 0
		for _ = 1, 120 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[1].outbox)
			local c = sim.combat
			local cp = view.projectiles[p]
			if c.projSlot[p] and cp and cp.field then
				fieldTicks += 1
				worst = math.max(worst, math.sqrt((cp.x - c.px[p]) ^ 2 + (cp.y - c.py[p]) ^ 2 + (cp.z - c.pz[p]) ^ 2))
			end
			for _, e in view.effects do
				if e.kind == "shield" then
					hits += 1
				end
			end
			table.clear(view.effects)
			if c.projSlot[p] == nil then
				break
			end
		end
		t.expect(fieldTicks >= 3, `the client stepped the shell in the field ({fieldTicks} ticks)`)
		t.expect(worst < 1, `the client's field step tracks the server's ({worst} studs at worst)`)
		t.equal(hits, 1, "one SHIELD_HIT")
		t.expect(view.shields[gen].charge > half + 2, `SHIELD records follow the recharge ({half} → {view.shields[gen].charge})`) -- (+8 before S-150's slower recharge)
	end))

	t.test("concentrated fire brings a dome down; light fire only wears it (S-150, the user)", function()
		-- `n` Ravagers shell a tank under a Phalanx for 60 s; the dome's charge
		-- at 30 and 60 s (it held 100% throughout before S-150)
		local function siege(n: number): (number, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
			local w = sim.world
			local gen = Spawn.unit(sim, "ord_phalanx", 1, 0, 0)
			Spawn.unit(sim, "ord_sovereign", 1, -300, -300)
			for i = 1, 4 do
				Spawn.unit(sim, "ord_generator", 1, -330 + i * 20, -330)
			end
			-- the tank near the dome's east edge (radius 120): the Ravagers'
			-- 78-stud guns (S-179) reach it from outside the dome
			local tank = Spawn.unit(sim, "ord_lancer", 1, 90, 0)
			World.setHealth(w, tank, 1e7)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			local ids = {}
			for i = 1, n do
				table.insert(ids, Spawn.unit(sim, "chs_ravager", 2, 190 + (i % 3) * 14, (i - n / 2) * 12, -math.pi / 2))
			end
			local wr = Packer.Writer.new()
			Schema.encodeCommand(wr, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = ids, targetId = tank })
			assert(Sim.submit(sim, 2, wr:finish()))
			local at30 = 0
			for tick = 1, 900 do
				Sim.step(sim)
				if tick == 450 then
					at30 = Shield.fraction(sim, gen) or 0 -- (nil: the generator itself fell)
				end
			end
			return at30, Shield.fraction(sim, gen) or 0
		end
		-- S-179 cut the Ravager's damage (so its shells' mass) × 0.8: 12 and 5
		-- tanks put about the mass on the dome that 10 and 4 did before
		local HEAVY, LIGHT = 12, 5
		local heavy30, heavy60 = siege(HEAVY)
		local light30, light60 = siege(LIGHT)
		t.expect(heavy30 < 0.15 and heavy60 < 0.15, `{HEAVY} tanks bring it down within 30 s (at 30 s {heavy30}, at 60 s {heavy60})`)
		t.expect(light60 < 0.9 and light60 > 0.5, `{LIGHT} tanks wear it down slowly ({light30} at 30 s, {light60} at 60 s)`)
		print(string.format("    Phalanx charge: %d Ravagers %.0f%% / %.0f%%, %d Ravagers %.0f%% / %.0f%% (30 s / 60 s)", HEAVY, heavy30 * 100, heavy60 * 100, LIGHT, light30 * 100, light60 * 100))
	end)

	t.test("TOGGLE switches a dome off and on: off it's down, draws no power, keeps its charge (S-154, the user)", function()
		local sim, gen = dome(1, 0.6)
		local w = sim.world
		t.expect(bit32.band(w.state[gen], World.State.TOGGLED_ON) ~= 0, "a generator starts switched on")
		local function toggle(on: boolean)
			local wr = Packer.Writer.new()
			Schema.encodeCommand(wr, { cmdType = Schema.CmdType.TOGGLE, flags = 0, unitIds = { gen }, value = if on then 1 else 0 })
			assert(Sim.submit(sim, 1, wr:finish()))
		end
		Sim.step(sim)
		t.expect(sim.combat.shieldUp[gen] == true, "up while on")
		toggle(false)
		for _ = 1, 30 do
			Sim.step(sim)
		end
		local held = sim.combat.shieldCharge[gen]
		t.equal(sim.combat.shieldUp[gen], false, "off: the dome is down")
		t.equal(sim.combat.shieldPower[gen], 0, "and draws no power")
		local hitless = fire(sim, "chs_heavy_cannon", 0, 250)
		local hit = follow(sim, hitless)
		t.equal(hit, nil, "a shell passes where the dome was")
		t.expect(math.abs(sim.combat.shieldCharge[gen] - held) < 1e-9, "no recharge while off; the charge is kept")
		toggle(true)
		for _ = 1, 3 do
			Sim.step(sim)
		end
		t.equal(sim.combat.shieldUp[gen], true, "on again: it rises (charge above RAISE_AT)")
	end)

	t.test("a player without the generator gets SHIELD_HIT with generator 0", function()
		local sim, gen = dome(10)
		local g = (sim.map :: any).grid
		-- player 2 looks at the dome but has no sight of it
		local cx, cz = g:cellAt(CX, CZ)
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.CAMERA, flags = 0, unitIds = {}, minX = cx - 30, minZ = cz - 10, maxX = cx + 30, maxZ = cz + 60 })
		assert(Sim.submit(sim, 2, w:finish()))
		local p = fire(sim, "chs_mortar", 0, 250)
		local got = nil
		for _ = 1, 120 do
			Sim.step(sim)
			for _, msg in sim.net.players[2].outbox.Events do
				for _, e in Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader) do
					if e.kind == Schema.EventKind.SHIELD_HIT then
						got = e
					end
					t.expect(e.kind ~= Schema.EventKind.SHIELD or e.unitId ~= gen, "no SHIELD for a generator it can't see")
				end
			end
			if sim.combat.projSlot[p] == nil then
				break
			end
		end
		t.expect(got ~= nil and got.unitId == 0 and got.projId == p, "SHIELD_HIT, generator 0")
	end)

	t.test("the shield profile: every attacker row fires, nothing in the dome's core is hurt while it stands", function()
		local sim = Sim.new({ seed = 11, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_phalanx", 1, CX, CZ)
		-- the plant in the core; the radar and builder near the edge stand in the
		-- field's band (S-83), where shells still slowing can reach them
		local inside = { Spawn.unit(sim, "ord_vehplant", 1, 0, -150 + 40) }
		for _, id in { Spawn.unit(sim, "ord_oracle", 1, -30, -60), Spawn.unit(sim, "ord_mason", 1, 30, -60) } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		local acc = sim.eco.accounts[1]
		acc.power.storage, acc.power.stored = 1e6, 1e6
		local attackers = {}
		for i = 0, 3 do
			table.insert(attackers, Spawn.unit(sim, "chs_locust", 2, -45 + i * 30, 40, math.pi))
		end
		for i = 0, 3 do
			table.insert(attackers, Spawn.unit(sim, "chs_ravager", 2, -60 + i * 40, 90, math.pi))
		end
		table.insert(attackers, Spawn.unit(sim, "chs_juggernaut", 2, -120, 110, math.pi))
		table.insert(attackers, Spawn.unit(sim, "chs_juggernaut", 2, 120, 110, math.pi))
		table.insert(attackers, Spawn.unit(sim, "chs_cyclops", 2, -50, 330, math.pi))
		table.insert(attackers, Spawn.unit(sim, "chs_watcher", 2, 200, 60, math.pi))
		local health = {}
		for _, id in inside do
			health[id] = w.health[id]
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		local turned, through, hurtWhileUp = 0, 0, 0
		for _ = 1, 900 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SHIELD_HIT" then
					if e.breach then
						through += 1
					else
						turned += 1
					end
				end
			end
			for _, id in inside do
				if World.isAlive(w, id) and w.health[id] < health[id] then
					if sim.combat.shieldUp[gen] and through == 0 then
						hurtWhileUp += 1
					end
					health[id] = w.health[id]
				end
			end
		end
		t.expect(turned >= 20, `the dome turned shells ({turned} turned, {through} through)`)
		t.equal(hurtWhileUp, 0, "nothing in the core hurt while the dome stood and nothing broke through")
	end)

	t.test("two runs with domes give the same state hash", function()
		local function run(): number
			local sim = dome(12)
			for i = 1, 30 do
				fire(sim, ALL_WEIGHTS[i % #ALL_WEIGHTS + 1], (i % 5 - 2) * 40, 250)
				Sim.step(sim)
				Sim.step(sim)
			end
			for _ = 1, 60 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run(), "deterministic")
	end)

	t.test("a dome stops a beam at its surface; Radiance's hit-ray hurts only up to it (client request 50, S-116)", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local carapace = Spawn.unit(sim, "chs_carapace", 2, 0, 200)
		local capacity = sim.defs.units.chs_carapace.shield.capacity
		sim.combat.shieldCharge[carapace] = capacity
		local inside = Spawn.unit(sim, "chs_juggernaut", 2, 0, 215, math.pi)
		local outside = Spawn.unit(sim, "chs_scrapper", 2, 0, 110, math.pi) -- (far enough that the Juggernaut is the pick)
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local scout = Spawn.unit(sim, "ord_herald", 1, 60, 100, 0) -- sees the Juggernaut: an exact aim, a straight line
		for _, id in { inside, outside, scout } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e6)
		end
		local fire = nil
		for _ = 1, 15 * 8 do
			local acc = sim.eco.accounts[1]
			acc.power.storage = math.max(acc.power.storage, 5000)
			acc.power.stored = 5000
			sim.combat.shieldCharge[carapace] = math.max(sim.combat.shieldCharge[carapace], capacity * 0.9)
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower and fire == nil then
					fire = e
				end
			end
		end
		t.expect(fire ~= nil, "Radiance fired")
		if fire then
			t.equal(fire.hit, false, "the shot didn't hit")
			local r = math.sqrt((fire.x - 0) ^ 2 + (fire.z - 200) ^ 2)
			t.expect(r > sim.defs.units.chs_carapace.shield.radius * 0.8, `it ended on the dome's surface ({r} studs from its centre)`)
		end
		t.equal(w.health[inside], 1e6, "nothing inside the dome is hurt")
		t.expect(w.health[outside] < 1e6, "the worker on the line outside the dome is")
	end)

	t.test("a lingering beam held on a dome drains a big share of its charge (client request 51, S-117)", function()
		local sim = Sim.new({ seed = 9, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local carapace = Spawn.unit(sim, "chs_carapace", 2, 0, 200)
		local capacity = sim.defs.units.chs_carapace.shield.capacity
		sim.combat.shieldCharge[carapace] = capacity
		local inside = Spawn.unit(sim, "chs_juggernaut", 2, 0, 215, math.pi)
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local scout = Spawn.unit(sim, "ord_herald", 1, 60, 100, 0)
		for _, id in { inside, scout } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
		end
		local firedAt, before, lowest = nil, 0, math.huge
		for _ = 1, 15 * 10 do
			local acc = sim.eco.accounts[1]
			acc.power.storage = math.max(acc.power.storage, 5000)
			acc.power.stored = 5000
			local charge = sim.combat.shieldCharge[carapace]
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower and firedAt == nil then
					firedAt, before = sim.tick, charge
				end
			end
			if firedAt and sim.tick - firedAt <= 15 * 3 + 2 then
				lowest = math.min(lowest, sim.combat.shieldCharge[carapace])
			end
		end
		t.expect(firedAt ~= nil, "Radiance fired at the dome")
		local share = (before - lowest) / capacity
		print(string.format("    one Radiance beam: the Carapace %.0f%% -> %.0f%% (%.0f%% of its capacity)", before / capacity * 100, lowest / capacity * 100, share * 100))
		t.expect(share > 0.4 and share < 0.8, `a big share of the charge ({share * 100}%)`)
	end)

	t.test("an ordered attack on a shield generator sticks; a dome dropping mid-beam lets the beam through (client request 54, S-121)", function()
		local Packer = require("@shared/Net/Packer")
		local Schema = require("@shared/Net/Schema")
		local sim = Sim.new({ seed = 10, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local carapace = Spawn.unit(sim, "chs_carapace", 2, 0, 250)
		local capacity = sim.defs.units.chs_carapace.shield.capacity
		sim.combat.shieldCharge[carapace] = capacity * 0.1 -- a weak dome: the first beam drains it
		local tank = Spawn.unit(sim, "chs_ravager", 2, 150, 0, math.pi) -- nearer the tower than the generator
		local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
		local scout = Spawn.unit(sim, "ord_herald", 1, 60, 120, 0)
		for _, id in { tank, scout } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
			World.setHealth(w, id, 1e6)
		end
		for _ = 1, 4 do
			Sim.step(sim) -- sensors: the team knows the generator
		end
		local wr = Packer.Writer.new()
		Schema.encodeCommand(wr, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { tower }, targetId = carapace })
		assert(Sim.submit(sim, 1, wr:finish()))
		local fires: { any } = {}
		local genHealth = w.health[carapace]
		for _ = 1, 15 * 6 do
			local acc = sim.eco.accounts[1]
			acc.power.storage = math.max(acc.power.storage, 5000)
			acc.power.stored = 5000
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower then
					table.insert(fires, e)
				end
			end
			if #fires >= 2 then
				break
			end
		end
		t.equal(sim.orders.manual[tower], carapace, "the tower took the attack as its manual target")
		t.equal(w.wTarget[World.slotKey(tower, 1)], carapace, "and aims at the generator, not the nearer tank")
		t.expect(#fires >= 2, `the beam stopped on the dome, then a new FIRE when it dropped ({#fires})`)
		if #fires >= 2 then
			t.equal(fires[1].hit, false, "first on the dome")
			t.equal(fires[2].hit, true, "then through to the generator")
		end
		for _ = 1, 30 do
			Sim.step(sim)
		end
		t.expect(w.health[carapace] < genHealth, "the rest of the beam reached the generator")
	end)

	t.test("a burning beam's end follows the domes: through a dropped one to the next, cut by one rising (client request 56, S-123)", function()
		local Packer = require("@shared/Net/Packer")
		local Schema = require("@shared/Net/Schema")
		local capacity = 400
		local function setup(seed: number): (Sim.Sim, number, number)
			local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
			local w = sim.world
			local tower = Spawn.unit(sim, "ord_radiance", 1, 0, -300)
			local target = Spawn.unit(sim, "chs_juggernaut", 2, 0, 280, math.pi)
			local scout = Spawn.unit(sim, "ord_herald", 1, 60, 200, 0)
			for _, id in { target, scout } do
				World.setFireState(w, id, World.FireState.HOLD_FIRE)
				World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
				World.setHealth(w, id, 1e6)
			end
			return sim, tower, target
		end
		local function step(sim: Sim.Sim, tower: number, fires: { any })
			local acc = sim.eco.accounts[1]
			acc.power.storage = math.max(acc.power.storage, 5000)
			acc.power.stored = 5000
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == tower then
					table.insert(fires, e)
				end
			end
		end
		local function attack(sim: Sim.Sim, tower: number, target: number)
			for _ = 1, 4 do
				Sim.step(sim)
			end
			local wr = Packer.Writer.new()
			Schema.encodeCommand(wr, { cmdType = Schema.CmdType.ATTACK, flags = 0, unitIds = { tower }, targetId = target })
			assert(Sim.submit(sim, 1, wr:finish()))
		end
		-- 1. a weak dome in front drops; a full one behind takes the beam
		local sim, tower, target = setup(11)
		local front = Spawn.unit(sim, "chs_carapace", 2, 0, 0)
		local back = Spawn.unit(sim, "chs_carapace", 2, 0, 250)
		sim.combat.shieldCharge[front] = capacity * 0.05
		sim.combat.shieldCharge[back] = capacity
		attack(sim, tower, target)
		local fires = {}
		for _ = 1, 15 * 4 do
			step(sim, tower, fires)
			if #fires >= 2 then
				break
			end
		end
		t.expect(#fires >= 2, `a new FIRE when the front dome dropped ({#fires})`)
		if #fires >= 2 then
			t.expect(fires[1].z < 0 and not fires[1].hit, "first on the front dome")
			t.expect(fires[2].z > 120 and fires[2].z < 250 and not fires[2].hit, `then on the back dome's surface (z {fires[2].z}), not through it`)
		end
		local backBefore = sim.combat.shieldCharge[back]
		for _ = 1, 10 do
			step(sim, tower, fires)
		end
		t.expect(sim.combat.shieldCharge[back] < backBefore, "the back dome is drained now")
		t.equal(sim.world.health[target], 1e6, "the target inside it untouched")
		-- 2. a dome rising across a burning beam cuts it
		local sim2, tower2, target2 = setup(12)
		local rising = Spawn.unit(sim2, "chs_carapace", 2, 0, 0)
		sim2.combat.shieldCharge[rising] = 0
		sim2.combat.shieldUp[rising] = false
		attack(sim2, tower2, target2)
		local fires2 = {}
		local hits = 0
		for _ = 1, 15 * 4 do
			step(sim2, tower2, fires2)
			if #fires2 == 1 and fires2[1].hit and sim2.combat.shieldUp[rising] == false then
				-- the beam burns on the target: raise the dome across it
				sim2.combat.shieldCharge[rising] = capacity
				sim2.combat.shieldUp[rising] = true
			end
			for _, e in sim2.combat.events do
				if e.kind == "SHIELD_HIT" and e.unit == rising then
					hits += 1
				end
			end
			if #fires2 >= 2 then
				break
			end
		end
		t.expect(#fires2 >= 2, `a new FIRE when the dome rose ({#fires2})`)
		if #fires2 >= 2 then
			t.equal(fires2[1].hit, true, "first on the target")
			t.expect(not fires2[2].hit and fires2[2].z < 0, `then cut at the rising dome (z {fires2[2].z})`)
		end
		t.expect(hits >= 1, "the rising dome took the hit")
	end)
end
