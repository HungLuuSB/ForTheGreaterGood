--!strict
-- The shield dome prototype's hit effect (C-87): hexagon plates wrap the
-- dome round the hit, heat ripples outward and fades, nearby hits merge,
-- and a deflected shell brakes, touches and bounces off.

local Shield = require("../../src/client/Core/Shield")

local function v(x: number, y: number, z: number): Shield.V3
	return { x = x, y = y, z = z }
end

return function(t: any)
	t.test("layout: hex rings on the sphere, centred on the hit, plates evenly spaced", function()
		local c, R = v(10, 0, -20), 60
		local hit = v(10 + 40, 30, -20 + 20) -- off the surface: projected onto it
		for rings = 1, 3 do
			local plates = Shield.layout(c, R, hit, rings)
			t.equal(#plates, 1 + 3 * rings * (rings + 1))
			for _, p in plates do
				t.expect(math.abs(Shield.len(Shield.sub(p.pos, c)) - R) < 1e-6, "on the sphere")
				t.expect(math.abs(Shield.len(p.normal) - 1) < 1e-9, "unit normal")
				t.expect(math.abs(Shield.dot(p.right, p.normal)) < 1e-9, "the plate's axis lies in its plane")
			end
		end
		local plates = Shield.layout(c, R, hit, 2)
		local centre = plates[1]
		for _, p in plates do
			if p.ring == 0 then
				centre = p
			end
		end
		t.equal(centre.ring, 0)
		local n = Shield.unit(Shield.sub(hit, c))
		t.expect(Shield.dot(centre.normal, n) > 0.999999, "the centre plate is at the hit")
		-- the six ring-1 plates are one plate pitch from the centre (as a chord)
		local step = Shield.PLATE + Shield.GAP
		local ring1 = 0
		for _, p in plates do
			if p.ring == 1 then
				ring1 += 1
				local d = Shield.len(Shield.sub(p.pos, centre.pos))
				t.expect(math.abs(d - step) < 0.01, `ring 1 at {d}`)
			end
		end
		t.equal(ring1, 6)
	end)

	t.test("plates: the centre lights first, outer rings later and cooler; all fade; dents spring back", function()
		local h0 = Shield.plateAt(0.02, 0, 1)
		local h2 = Shield.plateAt(0.02, 2, 1)
		t.expect(h0 > 0.5 and h2 == 0, "ring 2 isn't lit yet")
		local _, a2 = Shield.plateAt(2 * Shield.RING_DELAY + 0.05, 2, 1)
		t.expect(a2 > 0, "ring 2 lights after its delay")
		local early = Shield.plateAt(0.05, 0, 1)
		local late = Shield.plateAt(0.4, 0, 1)
		t.expect(early > late, "it cools")
		t.expect(Shield.plateAt(0.05, 0, 1) > Shield.plateAt(0.05 + Shield.RING_DELAY, 1, 1), "rings further out run cooler")
		local _, centre = Shield.plateAt(0.05, 0, 1)
		local _, ring1 = Shield.plateAt(0.05 + Shield.RING_DELAY, 1, 1)
		t.expect(ring1 < centre * 0.5, `one bright centre, a faint ring ({centre} vs {ring1}): equal rings read as several shots`)
		t.expect(Shield.plateAt(0.05, 0, 3) > Shield.plateAt(0.05, 0, 0.5), "a heavier hit is hotter")
		local h, a, d = Shield.plateAt(5, 0, 3)
		t.equal(h + a + d, 0)
		local _, _, dentPeak = Shield.plateAt(0.07, 0, 1)
		local _, _, dentLate = Shield.plateAt(0.3, 0, 1)
		t.expect(dentPeak > 0.5 and dentLate < 0.05, `dent {dentPeak} then {dentLate}`)
	end)

	t.test("colour: white at its hottest, fading to grey; never red or orange", function()
		local r, g, b = Shield.color(1)
		t.expect(r == 255 and g == 255 and b == 255, "white")
		for _, h in { 0, 0.3, 0.55, 0.8 } do
			local r2, g2, b2 = Shield.color(h)
			t.expect(math.abs(r2 - g2) < 8 and b2 >= r2, `grey at {h} ({r2}, {g2}, {b2})`)
		end
		t.expect(Shield.color(0.2) < Shield.color(0.8), "cooler is darker")
	end)

	t.test("hits: close young hits merge into a hotter patch; at most MAX_PATCHES; old ones expire", function()
		local dome = Shield.newDome(v(0, 0, 0), 50)
		local p1 = Shield.hit(dome, v(0, 0, 60), 1, 0)
		local p2 = Shield.hit(dome, v(1, 1, 60), 1, 0.1)
		t.equal(p1, p2)
		t.expect(p1.strength > 1, "the merged patch is hotter")
		t.equal(#dome.patches, 1)
		Shield.hit(dome, v(1, 1, 60), 1, 0.9) -- the same spot, later: a new patch
		t.equal(#dome.patches, 2)
		for i = 1, 10 do
			local a = i * 0.6
			Shield.hit(dome, v(60 * math.cos(a), 10, 60 * math.sin(a)), 1, 1)
		end
		t.equal(#dome.patches, Shield.MAX_PATCHES)
		Shield.expire(dome, 10)
		t.equal(#dome.patches, 0)
	end)

	-- one shot straight at a dome held at `charge`: what happened, the
	-- closest it got to the surface, seconds from the field's edge to the
	-- turn (or breach), and the shell
	local function shoot(mass: number, charge: number, hold: boolean?)
		local dome = Shield.newDome(v(0, 0, 0), 60)
		dome.charge = charge
		dome.up = charge > 0 -- an empty dome has collapsed
		local s = Shield.newShell(v(-250, 0, 0), v(260, 0, 0), mass)
		local closest, clock, tIn, tEvent, result = math.huge, 0, nil, nil, nil
		local speeds = {}
		for _ = 1, 600 do
			if hold ~= false then
				dome.charge = charge
			end
			local e = Shield.stepShell(s, dome, 1 / 60)
			clock += 1 / 60
			if s.state == "braking" and tIn == nil then
				tIn = clock
			end
			if s.state == "repelled" then
				table.insert(speeds, Shield.len(s.vel))
			end
			closest = math.min(closest, Shield.len(s.pos) - 60)
			if e then
				t.expect(result == nil, "one event per shot")
				result, tEvent = e, clock
			end
			if s.state == "spent" or e == "breach" then
				break
			end
		end
		return result, closest, (tEvent or clock) - (tIn or 0), s, speeds, dome
	end

	t.test("a shell slows to a stop in the field, turns above the surface and is thrown back out faster", function()
		local result, closest, _, s, speeds = shoot(1, 1)
		t.equal(result, "turn")
		t.expect(closest > 5, `turned {closest} studs above the surface`)
		t.expect(math.abs(Shield.len(assert(s.hitAt)) - 60) < 1e-6, "the hit is on the surface under the turn")
		t.expect(#speeds > 3 and speeds[#speeds] > speeds[1] * 3, "it speeds up outward after the turn")
		t.equal(s.state, "spent")
		t.expect(Shield.dot(s.vel, Shield.unit(s.pos)) > 0, "leaving outward")
	end)

	t.test("heavier shells take longer to stop and get closer", function()
		local _, c1, t1 = shoot(1, 1)
		local _, c4, t4 = shoot(4, 1)
		t.expect(t4 > t1 * 1.5, `mass 4 takes {t4} s, mass 1 {t1} s`)
		t.expect(c4 < c1, "and gets closer")
	end)

	t.test("full force from 50% charge; below it the field weakens and a heavy shell breaks through, slowed", function()
		local r1, c1, t1 = shoot(2.5, 1)
		local r5, c5, t5 = shoot(2.5, Shield.FULL_FORCE)
		t.equal(r1, "turn")
		t.equal(r5, "turn")
		t.equal(c1, c5)
		t.equal(t1, t5)
		local rWeak, cWeak = shoot(2.5, 0.35)
		t.equal(rWeak, "turn")
		t.expect(cWeak < c5, "a weaker field lets it closer")
		local rBreach, _, _, s = shoot(4, 0.3)
		t.equal(rBreach, "breach")
		t.expect(Shield.len(s.vel) < 260 * 0.8, `slowed but through ({Shield.len(s.vel)})`)
		local rLight = shoot(1, 0.3)
		t.equal(rLight, "turn") -- the same weak dome still turns a light shell
		local rEmpty, _, _, sEmpty = shoot(1, 0)
		t.equal(rEmpty, nil) -- a collapsed dome: no field, no hit
		t.expect(Shield.len(sEmpty.vel) > 255, "it isn't slowed at all")
	end)

	t.test("turning a shell drains charge by its mass; charge recharges", function()
		local _, _, _, _, _, dome = shoot(2.5, 1, false)
		t.expect(math.abs(dome.charge - (1 - Shield.HIT_COST * 2.5)) < 1e-9, `charge {dome.charge}`)
		dome.charge = 0.2
		Shield.recharge(dome, 2)
		t.expect(math.abs(dome.charge - (0.2 + 2 * Shield.RECHARGE)) < 1e-9, "recharged")
		Shield.recharge(dome, 1000)
		t.equal(dome.charge, 1)
	end)

	t.test("at 0% the dome collapses and stays down until it recharges to 25%", function()
		local dome = Shield.newDome(v(0, 0, 0), 60)
		dome.charge = 0.05
		Shield.drain(dome, 0.02)
		t.expect(dome.up, "still up at 3%")
		Shield.drain(dome, 0.5)
		t.equal(dome.charge, 0)
		t.expect(not dome.up, "collapsed")
		t.equal(Shield.domeForce(dome), 0)
		Shield.recharge(dome, (Shield.RAISE_AT - 0.01) / Shield.RECHARGE)
		t.expect(not dome.up, "still down just under 25%")
		Shield.recharge(dome, 0.5)
		t.expect(dome.up, "up again at 25%")
		t.expect(Shield.domeForce(dome) > 0.4, "at half force (25% of the 50% for full)")
	end)

	t.test("a shell in the field when the dome collapses carries on with no hit", function()
		local dome = Shield.newDome(v(0, 0, 0), 60)
		local s = Shield.newShell(v(-115, 0, 0), v(260, 0, 0), 1)
		for _ = 1, 10 do
			Shield.stepShell(s, dome, 1 / 60)
		end
		t.equal(s.state, "braking")
		Shield.drain(dome, 1)
		local events, closest = 0, math.huge
		for _ = 1, 120 do
			if Shield.stepShell(s, dome, 1 / 60) then
				events += 1
			end
			closest = math.min(closest, Shield.len(s.pos))
		end
		t.equal(events, 0)
		t.expect(closest < 60, "it went through where the dome was")
	end)

	t.test("idle flickers keep clear of live hit patches", function()
		local dome = Shield.newDome(v(0, 0, 0), 60)
		Shield.hit(dome, v(0, 60, 0), 2.5, 0)
		t.equal(Shield.idle(dome, v(3, 60, 2), 0.1), nil)
		t.expect(Shield.idle(dome, v(60, 5, 0), 0.1) ~= nil, "away from it")
		Shield.expire(dome, 5)
		t.expect(Shield.idle(dome, v(3, 60, 2), 5) ~= nil, "and over the spot once it has faded")
		-- a hit next to a running flicker clears it
		Shield.idle(dome, v(60, 5, 0), 5)
		Shield.hit(dome, v(0, 60, 0), 1, 5.1)
		for _, idle in dome.idle do
			t.expect(Shield.len(Shield.sub(idle.hit, v(0, 60, 0))) > Shield.IDLE_CLEAR, "no flicker left by the new hit")
		end
		t.expect(#dome.idle >= 1, "the far one stays")
	end)

	t.test("core colour: green full, orange low, red empty", function()
		local r, g, b = Shield.coreColor(1)
		t.expect(g > 240 and r < 100 and b > 100, "green")
		local r2, g2 = Shield.coreColor(0.4)
		t.expect(r2 == 255 and g2 == 150, "orange")
		local r3, g3 = Shield.coreColor(0)
		t.expect(r3 > 200 and g3 < 60, "red")
	end)

	t.test("a hit on a lit patch sends a new wave through it; the patch never snaps back solid (C-117)", function()
		local dome = Shield.newDome({ x = 0, y = 0, z = 0 }, 100)
		local p = Shield.hit(dome, { x = 0, y = 0, z = 100 }, 1, 0)
		-- the wave travels out: ring 2 is dark at first, lit two ring delays later
		local _, ring2First = Shield.plateLook(p, 2, 0.01)
		local _, ring2Later = Shield.plateLook(p, 2, 2 * Shield.RING_DELAY + 0.03)
		t.equal(ring2First, 0)
		t.expect(ring2Later > 0, "the wave reached ring 2")
		local _, centreFading = Shield.plateLook(p, 0, 0.5)
		local same = Shield.hit(dome, { x = 0, y = 0, z = 100 }, 1, 0.5)
		t.equal(same, p, "the same patch")
		t.equal(#p.waves, 2, "two waves, the first one kept (not restarted)")
		t.equal(p.waves[1], 0)
		local _, centreNew = Shield.plateLook(p, 0, 0.53)
		t.expect(centreNew > centreFading, `the new wave relights the centre ({centreFading} -> {centreNew})`)
	end)
end
