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
-- dome's centre (straight at it without gravity), for `team`'s side.
local function fire(sim: Sim.Sim, weaponId: string, x: number, z: number, side: number?): number
	local weapon = sim.defs.weapons[weaponId]
	local g = weapon.gravity or 0
	local speed = weapon.projectileSpeed or 300
	local dx, dz = CX - x, CZ - z
	local d = math.sqrt(dx * dx + dz * dz)
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

return function(t: RunAll.Context)
	t.test("a charged dome turns every shell weight back; the shells burst outside, live", function()
		for _, weaponId in ALL_WEIGHTS do
			local sim, gen = dome(1)
			local w = sim.world
			local health = w.health[gen]
			local p = fire(sim, weaponId, 0, 250)
			local hit, burst = follow(sim, p)
			t.expect(hit ~= nil and hit.breach == false and hit.unit == gen, `{weaponId}: turned back`)
			t.expect(burst ~= nil and distance(burst[1], burst[3]) > sim.defs.units.ord_phalanx.shield.radius, `{weaponId}: burst outside the dome`)
			t.equal(w.health[gen], health, `{weaponId}: the generator took nothing`)
			if hit then
				local gx, gy, gz = Shield.center(sim, gen) -- the generator snaps to its footprint
				near(t, math.sqrt((hit.x - gx) ^ 2 + (hit.y - gy) ^ 2 + (hit.z - gz) ^ 2), 120, 0.01, `{weaponId}: the hit point is on the dome`)
			end
		end
	end)

	t.test("a turned shell explodes where it lands and hurts what it lands on", function()
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
	end)

	t.test("heavier shells take longer to stop: they turn deeper in the field", function()
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
		local light, medium, heavy = turnAt(0.25), turnAt(1), turnAt(6)
		t.expect(light > medium and medium > heavy and heavy > 120, `turn heights {light}, {medium}, {heavy} (dome top 120, band to 170)`)
	end)

	t.test("the bounce is close to a mirror off the dome where the shell turned (S-80)", function()
		-- shells from 200 studs out at the dome's top, at angles to its normal
		local function bounce(angle: number, mass: number): (number, number, number)
			local a = math.rad(angle)
			local dx, dy = math.sin(a), -math.cos(a)
			local x, y, z, vx, vy, vz = -dx * 200, 120 - dy * 200, 0, dx * 300, dy * 300, 0
			local phase, nx, ny, inAngle = ShieldField.FREE, 0, 1, 0
			for _ = 1, 300 do
				local event
				x, y, z, vx, vy, vz, phase, event = ShieldField.step(x, y, z, vx, vy, vz, 0, 0, 0, 0, 120, 1, mass, phase, 1 / 15)
				if event == ShieldField.TURN then
					local r = math.sqrt(x * x + y * y)
					nx, ny = x / r, y / r
					inAngle = math.deg(math.acos(-(dx * nx + dy * ny)))
				end
				if phase == ShieldField.DONE then
					break
				end
			end
			local speed = math.sqrt(vx * vx + vy * vy)
			return inAngle, math.deg(math.acos((vx * nx + vy * ny) / speed)), speed / 300
		end
		for _, mass in { 0.3, 1, 4 } do
			local i0, o0, keep0 = bounce(0, mass)
			t.expect(i0 < 0.5 and o0 < 0.5, `mass {mass}: head-on goes straight back ({o0}°)`)
			t.expect(keep0 > 0.5 and keep0 < 0.7, `mass {mass}: at {keep0 * 100}% of its speed`)
			for _, angle in { 30, 50, 70 } do
				local i, o, keep = bounce(angle, mass)
				t.expect(math.abs(o - i) <= 10, `mass {mass}, {angle}°: in {i}° → out {o}° (a mirror within 10°)`)
				t.expect(keep > 0.6 and keep < 1, `mass {mass}, {angle}°: keeps {keep * 100}% of its speed`)
			end
		end
	end)

	t.test("below half charge heavy shells break through, slowed; light ones still turn", function()
		local sim, gen = dome(3, 0.06)
		local light = fire(sim, "chs_autocannon", 0, 250)
		local hitLight = follow(sim, light)
		t.expect(hitLight ~= nil and not hitLight.breach, "the autocannon round turned")
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
		t.expect(through ~= nil and through < entry * 0.8, `slowed ({entry} → {through})`)
		local def = sim.defs.units.ord_phalanx.shield
		near(t, drop, Shield.BREACH_COST * Shield.mass(sim.defs.weapons.chs_siege_mortar) - def.recharge / 15, 0.01, "a breach costs half the shell's mass (less a tick's recharge)")
		t.equal(ShieldField.force(0.5), 1, "full force at 50%")
		t.equal(ShieldField.force(0.25), 0.5, "half force at 25%")
	end)

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

	t.test("the wire: SHIELD after ENTER and on change, SHIELD_FIELD and SHIELD_HIT; the client's field matches", function()
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
		t.expect(view.shields[gen].charge > half + 8, `SHIELD records follow the recharge ({half} → {view.shields[gen].charge})`)
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

	t.test("the shield profile: every attacker row fires, nothing under the dome is hurt while it stands", function()
		local sim = Sim.new({ seed = 11, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_phalanx", 1, CX, CZ)
		local inside = { Spawn.unit(sim, "ord_vehplant", 1, 0, -150 + 40), Spawn.unit(sim, "ord_oracle", 1, -30, -60), Spawn.unit(sim, "ord_mason", 1, 30, -60) }
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
		t.equal(hurtWhileUp, 0, "nothing under the dome hurt while it stood and nothing broke through")
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
end
