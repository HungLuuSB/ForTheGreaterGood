--!strict
-- The shield's energy look v4 (C-187): the pure frame logic ported from
-- models-C's ShieldPreview matches fx.md "Shield energy" with the
-- manifest's values.

local ShieldEnergyLook = require("../../src/client/Core/ShieldEnergyLook")
local Meshes = require("@shared/Defs/Meshes/Registry")

local energy = (Meshes :: any).shieldEnergy
local T = energy.timing

return function(t: any)
	t.test("the manifest has the v4 entry the client reads", function()
		t.expect(energy ~= nil and energy.status == "approved", "shieldEnergy, approved")
		t.equal(#energy.bands, energy.counts.bands)
		t.equal(#energy.textures.hit, energy.counts.hitFrames)
		t.equal(#energy.textures.waveGlow, 3)
		t.expect(energy.hexGrid.mesh ~= nil and energy.hitCap.mesh ~= nil)
		for _, k in { "pre", "raise", "collapse", "off", "pulsePeriod", "waveCycle", "jitterStep", "hitLife" } do
			t.expect(type(T[k]) == "number", `timing.{k}`)
		end
	end)

	t.test("states: deploying is pre then raise; up is idle; collapsing is collapse; down fades the beam", function()
		t.equal((ShieldEnergyLook.stateOf("deploying", 0.1, T)), "pre")
		local s, ts = ShieldEnergyLook.stateOf("deploying", T.pre + 0.3, T)
		t.equal(s, "raise")
		t.expect(math.abs(ts - 0.3) < 1e-9)
		t.equal((ShieldEnergyLook.stateOf("up", 4, T)), "idle")
		t.equal((ShieldEnergyLook.stateOf("collapsing", 0.2, T)), "collapse")
		t.equal((ShieldEnergyLook.stateOf("down", 0.1, T)), "off")
		local deploy, collapse = ShieldEnergyLook.durations(T)
		t.equal(deploy, T.pre + T.raise)
		t.equal(collapse, T.collapse)
	end)

	t.test("envelope: the front sweeps down in a raise and back up in a collapse; the beam fades after", function()
		local _, f0 = ShieldEnergyLook.envelope("raise", 0, T)
		local _, f1 = ShieldEnergyLook.envelope("raise", T.raise / 2, T)
		local _, f2, edge2 = ShieldEnergyLook.envelope("raise", T.raise, T)
		t.equal(f0, 0)
		t.expect(math.abs(f1 - 0.525) < 1e-9, `half way: 1.05 x ease(0.5) ({f1})`)
		t.expect(math.abs(f2 - 1.05) < 1e-9 and edge2 == 0, "formed, the edge crackle faded")
		local _, c1 = ShieldEnergyLook.envelope("collapse", T.collapse, T)
		t.expect(math.abs(c1) < 1e-9, "drained into the apex")
		local _, _, _, flash = ShieldEnergyLook.envelope("collapse", T.collapse, T)
		t.expect(flash > 2, `a last flash ({flash})`)
		local beam = ShieldEnergyLook.envelope("off", T.off / 2, T)
		t.expect(math.abs(beam - 0.5) < 1e-9, "the beam half faded")
		t.equal((ShieldEnergyLook.envelope("off", T.off, T)), 0)
	end)

	t.test("bands: revealed from the apex down; the bottom one only near the end", function()
		local n = energy.counts.bands
		t.equal(ShieldEnergyLook.bandReveal(0.5, 1, n), 1)
		t.equal(ShieldEnergyLook.bandReveal(0.5, n, n), 0)
		t.expect(ShieldEnergyLook.bandReveal(1.05, n, n) > 0.9, "all shown once formed")
	end)

	t.test("waves: three in flight, a new one every cycle / 3, accelerating down, fading near the ground", function()
		local count, cycle = energy.counts.waves, T.waveCycle
		local _, p0 = ShieldEnergyLook.wave(0, count, 0, cycle)
		local _, p1 = ShieldEnergyLook.wave(1, count, 0, cycle)
		local _, p2 = ShieldEnergyLook.wave(2, count, 0, cycle)
		t.expect(p0 < p1 and p1 < p2, "spread down the dome")
		local _, later = ShieldEnergyLook.wave(0, count, cycle / count, cycle)
		t.expect(math.abs(later - p1) < 1e-9, "wave 0 is where wave 1 was a third of a cycle on")
		local _, a = ShieldEnergyLook.wave(0, count, 0.2, cycle)
		local _, b = ShieldEnergyLook.wave(0, count, 0.4, cycle)
		local _, c = ShieldEnergyLook.wave(0, count, 1.6, cycle)
		local _, d = ShieldEnergyLook.wave(0, count, 1.8, cycle)
		t.expect(d - c > b - a, "faster lower down")
		local _, _, fadeLow = ShieldEnergyLook.wave(0, count, cycle * 0.99, cycle)
		t.expect(fadeLow < 0.1, `gone just above the ground ({fadeLow})`)
		-- never a level circle
		local th1 = ShieldEnergyLook.waveTheta(0.5, 0, 0, 1, 0)
		local th2 = ShieldEnergyLook.waveTheta(0.5, 1.3, 0, 1, 0)
		t.expect(math.abs(th1 - th2) > 0.005, "the ring wobbles")
	end)

	t.test("a packet arrives at the apex once a period; curve handles make circular arcs", function()
		t.expect(ShieldEnergyLook.arrive(0, T.pulsePeriod) > 0.99, "arriving")
		t.expect(ShieldEnergyLook.arrive(T.pulsePeriod / 2, T.pulsePeriod) < 0.01, "between packets")
		t.expect(math.abs(ShieldEnergyLook.handle(math.pi / 2, 1) - 4 / 3 * math.tan(math.pi / 8)) < 1e-12)
	end)
end
