--!strict
-- The shield dome's look over time (C-90): deploy and collapse phases,
-- rings on the dome's curve, the low-strength flicker and ring flow, the
-- opacity rule, strategic detail and the off-screen test.

local ShieldLook = require("../../src/client/Core/ShieldLook")

return function(t: any)
	t.test("deploy: the beam reaches the top first, then the dome grows with a ground flash; then up", function()
		local beam, scale, flash = ShieldLook.phase("deploying", 0.2)
		t.expect(beam > 0.4 and beam < 0.6, `beam half way ({beam})`)
		t.equal(scale, 0)
		t.equal(flash, nil)
		local beam2, scale2, flash2 = ShieldLook.phase("deploying", ShieldLook.BEAM_SECONDS + 0.3)
		t.equal(beam2, 1)
		t.expect(scale2 > 0.8 and scale2 < 1, `ease-out: most of the way at half time ({scale2})`)
		t.expect(flash2 ~= nil, "the ground ring flashes while it grows")
		t.equal(ShieldLook.advance("deploying", 0.5), "deploying")
		t.equal(ShieldLook.advance("deploying", ShieldLook.BEAM_SECONDS + ShieldLook.GROW_SECONDS), "up")
		local b, s, f, k = ShieldLook.phase("up", 99)
		t.equal(b + s, 2)
		t.equal(f, nil)
		t.equal(k, 1)
	end)

	t.test("collapse: flickers, shrinks, the beam retracts last; then down; down shows nothing", function()
		local flickers = {}
		for i = 0, 7 do
			local _, _, _, k = ShieldLook.phase("collapsing", i / 48)
			flickers[k] = true
		end
		t.expect(flickers[1] and flickers[0.35], "it flickers")
		local beamMid, scaleMid = ShieldLook.phase("collapsing", ShieldLook.COLLAPSE_SECONDS * 0.5)
		t.equal(beamMid, 1)
		t.expect(scaleMid > 0 and scaleMid < 1, "shrinking")
		local beamEnd, scaleEnd = ShieldLook.phase("collapsing", ShieldLook.COLLAPSE_SECONDS * 0.95)
		t.expect(beamEnd < 0.3 and scaleEnd == 0, "gone, the beam nearly in")
		t.equal(ShieldLook.advance("collapsing", ShieldLook.COLLAPSE_SECONDS), "down")
		local b, s = ShieldLook.phase("down", 1)
		t.equal(b + s, 0)
	end)

	t.test("rings sit on the dome's curve, flow from the top to the ground, fade at both ends", function()
		local n = ShieldLook.RINGS
		for i = 1, n do
			local theta, r, y, a = ShieldLook.ringAt(i, n, 0.37)
			t.expect(math.abs(r * r + y * y - 1) < 1e-9, "on the sphere")
			t.expect(theta >= ShieldLook.RING_TOP and theta <= math.pi / 2, "between the top and the ground")
			t.expect(a >= 0 and a <= 1, "opacity in range")
		end
		-- one ring over a trip: it goes down, then jumps back to the top
		local _, _, y1 = ShieldLook.ringAt(1, n, 0.2)
		local _, _, y2 = ShieldLook.ringAt(1, n, 0.6)
		local _, _, y3 = ShieldLook.ringAt(1, n, 1.05)
		t.expect(y2 < y1 and y3 > y2, "down, then back at the top")
		local _, _, _, nearGround = ShieldLook.ringAt(1, n, 0.98)
		local _, _, _, nearTop = ShieldLook.ringAt(1, n, 0.01)
		local _, _, _, middle = ShieldLook.ringAt(1, n, 0.5)
		t.expect(nearGround < 0.1 and nearTop < 0.1 and middle == 1, "faded at both ends")
	end)

	t.test("low strength: the flicker gets faster and stronger; rings dim and slow", function()
		local function swing(s: number): (number, number)
			local lo, crossings, last = 1, 0, nil
			for i = 0, 600 do
				local k = ShieldLook.flicker(s, i / 600)
				lo = math.min(lo, k)
				local up = k > 1 - (1 - lo) / 2
				if last ~= nil and up ~= last then
					crossings += 1
				end
				last = up
			end
			return 1 - lo, crossings
		end
		t.equal(ShieldLook.flicker(0.5, 0.3), 1)
		t.equal(ShieldLook.flicker(ShieldLook.LOW, 0.3), 1)
		local d1, c1 = swing(0.25)
		local d2, c2 = swing(0.05)
		t.expect(d2 > d1, `deeper ({d1} → {d2})`)
		t.expect(c2 > c1, `faster ({c1} → {c2} crossings a second)`)
		local s1, b1 = ShieldLook.ringFlow(0.8)
		local s2, b2 = ShieldLook.ringFlow(0.1)
		t.equal(s1 + b1, 2)
		t.expect(s2 < 1 and b2 < 1, "slower and dimmer")
	end)

	t.test("opacity: invisible at 0%, full from 50%", function()
		t.equal(ShieldLook.opacity(0), 0)
		t.equal(ShieldLook.opacity(0.25), 0.5)
		t.equal(ShieldLook.opacity(0.5), 1)
		t.equal(ShieldLook.opacity(1), 1)
	end)

	t.test("force on a shell: the field's change of velocity, without its own gravity; plume length", function()
		-- braking a shell flying +z: the force points back along -z
		local dx, dy, dz, size = ShieldLook.force(0, 0, 200, 0, -2, 150, 30)
		t.expect(dz < -0.99 and math.abs(dx) < 1e-9, "against the shot")
		t.expect(math.abs(size - 50) < 1e-6, `size {size}`)
		t.expect(math.abs(dy) < 1e-6, "its own gravity left out")
		local _, _, _, none = ShieldLook.force(0, -2, 200, 0, -4, 200, 30)
		t.equal(none, 0)
		t.equal(ShieldLook.plume(0.1), ShieldLook.PLUME_MIN)
		t.equal(ShieldLook.plume(1e6), ShieldLook.PLUME_MAX)
		t.expect(ShieldLook.plume(40) > ShieldLook.plume(20), "longer for a stronger force")
	end)

	t.test("strategic detail with hysteresis; off-screen domes are skipped", function()
		t.expect(not ShieldLook.strategic(false, 450), "not yet")
		t.expect(ShieldLook.strategic(false, 500), "far: strategic")
		t.expect(ShieldLook.strategic(true, 450), "stays until LOD_LEAVE")
		t.expect(not ShieldLook.strategic(true, 400), "close again")
		t.expect(ShieldLook.onScreen(500, 300, 100, 50, 1000, 600, false), "in view")
		t.expect(ShieldLook.onScreen(-40, 300, 100, 50, 1000, 600, false), "its edge reaches in")
		t.expect(not ShieldLook.onScreen(-60, 300, 100, 50, 1000, 600, false), "fully left of the view")
		t.expect(not ShieldLook.onScreen(500, 300, -10, 50, 1000, 600, false), "behind the camera")
		t.expect(ShieldLook.onScreen(500, 300, -10, 50, 1000, 600, true), "the camera inside it")
	end)

	local COLUMN = { weakest = 0.2, deploy = { shoot = 0.4, thicken = 0.6 }, collapse = { pinch = 0.35, flash = 0.15 } }

	t.test("column (C-186): thins with strength to `weakest`; deploy shoots the core up, then widens the rest", function()
		local reach, core, outer, bright = ShieldLook.column("up", 5, 1, COLUMN)
		t.equal(reach, 1)
		t.equal(core, 1)
		t.equal(outer, 1)
		t.equal(bright, 1)
		local _, weakCore, weakOuter = ShieldLook.column("up", 5, 0, COLUMN)
		t.equal(weakCore, 0.2, "at 0% the column is a fifth as wide")
		t.equal(weakOuter, 0.2)
		local _, halfCore = ShieldLook.column("up", 5, 0.5, COLUMN)
		t.expect(math.abs(halfCore - 0.6) < 1e-9, `half strength: 0.6 ({halfCore})`)
		local r1, _, o1 = ShieldLook.column("deploying", 0.2, 1, COLUMN)
		t.expect(r1 > 0.5 and r1 < 1, `the core is on its way up ({r1})`)
		t.equal(o1, 0, "the swirl and glow wait for the core")
		local r2, _, o2 = ShieldLook.column("deploying", 0.7, 1, COLUMN)
		t.equal(r2, 1, "the core reached the top")
		t.expect(o2 > 0 and o2 < 1, `then the rest widens ({o2})`)
		local _, _, o3 = ShieldLook.column("deploying", 1.0, 1, COLUMN)
		t.equal(o3, 1)
	end)

	t.test("column (C-186): collapse pinches to a thread, flashes once, then hides", function()
		local _, w0 = ShieldLook.column("collapsing", 0, 1, COLUMN)
		local _, w1 = ShieldLook.column("collapsing", 0.349, 1, COLUMN)
		t.equal(w0, 1)
		t.expect(w1 < 0.1, `pinched to a thread ({w1})`)
		local _, wf, of, bf = ShieldLook.column("collapsing", 0.4, 1, COLUMN)
		t.equal(bf, 3, "the flash: three times as bright")
		t.equal(wf, 1.5, "and half again as wide")
		t.equal(of, 1.5)
		local reach, wg, og, bg = ShieldLook.column("collapsing", 0.55, 1, COLUMN)
		t.equal(reach + wg + og + bg, 0, "then gone")
		t.equal((ShieldLook.column("down", 1, 1, COLUMN)), 0)
		t.expect(COLUMN.collapse.pinch + COLUMN.collapse.flash <= ShieldLook.COLLAPSE_SECONDS, "it ends before the dome is down")
	end)

	t.test("waves (C-186): a wave between two band centres splits (1 - f, f); waves add; fade at the top and rim", function()
		local out = {}
		-- one wave a third of the way between bands 5 and 6 (θ = 26°, step 6)
		ShieldLook.waveBands(26 / 90, 1, 16, 6, 10, out)
		t.expect(math.abs(out[5] - 2 / 3) < 1e-9 and math.abs(out[6] - 1 / 3) < 1e-9, `split ({out[5]}, {out[6]})`)
		local sum = 0
		for i = 1, 16 do
			sum += out[i]
		end
		t.expect(math.abs(sum - 1) < 1e-9, "one wave weighs 1 in all")
		-- at the very top and the rim it fades out
		ShieldLook.waveBands(0.01, 1, 16, 6, 10, out)
		t.expect(out[1] + out[2] < 0.1, `fading in under the top ({out[1] + out[2]})`)
		ShieldLook.waveBands(0.995, 1, 16, 6, 10, out)
		t.expect(out[15] + out[16] < 0.1, `fading out at the rim ({out[15] + out[16]})`)
		-- three waves evenly spaced: three lit places, a third of a trip apart
		ShieldLook.waveBands(0.25, 3, 16, 6, 10, out)
		local lit = 0
		for i = 1, 16 do
			if out[i] > 0.05 then
				lit += 1
			end
		end
		t.expect(lit >= 3 and lit <= 6, `three waves on at most six bands ({lit})`)
		-- the motion is smooth: a small phase step moves the weights a little
		local a, b = {}, {}
		ShieldLook.waveBands(0.4, 3, 16, 6, 10, a)
		ShieldLook.waveBands(0.4 + 1 / 600, 3, 16, 6, 10, b)
		local most = 0
		for i = 1, 16 do
			most = math.max(most, math.abs(a[i] - b[i]))
		end
		t.expect(most < 0.05, `no jumps between frames ({most})`)
		t.expect(ShieldLook.waveRate(0.1, 4.5) < ShieldLook.waveRate(1, 4.5), "slower when weak")
	end)

end
