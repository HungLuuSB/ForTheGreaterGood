--!strict
local Ballistics = require("../Sim/Combat/Ballistics")
local RunAll = require("./RunAll")

local function near(t: RunAll.Context, actual: number, expected: number, eps: number, what: string)
	t.expect(math.abs(actual - expected) <= eps, `{what}: expected {expected}, got {actual}`)
end

return function(t: RunAll.Context)
	t.test("launch pitch lands the shell on the target point", function()
		local cases = { { 380, 60, 180, 0 }, { 340, 60, 160, -5 }, { 200, 60, 300, 20 }, { 400, 0, 100, 10 } }
		for _, case in cases do
			local speed, g, dist, dh = case[1], case[2], case[3], case[4]
			local pitch = Ballistics.launchPitch(speed, g, dist, dh) :: number
			t.expect(pitch ~= nil, "reachable")
			-- fly it in small exact steps until it passes the target distance
			local x, y, vx, vy = 0, 0, math.cos(pitch) * speed, math.sin(pitch) * speed
			local dt = 1 / 600
			while x < dist do
				local nx, ny, _, _, nvy = Ballistics.step(x, y, 0, vx, vy, 0, g, dt)
				x, y, vy = nx, ny, nvy
			end
			near(t, y, dh, 0.5, `height at {dist} studs (speed {speed})`)
		end
	end)

	t.test("out of ballistic reach gives nil; zero gravity aims straight", function()
		t.equal(Ballistics.launchPitch(100, 60, 1000, 0), nil)
		near(t, Ballistics.launchPitch(100, 0, 10, 10) :: number, math.pi / 4, 1e-12, "straight line")
		near(t, Ballistics.launchPitch(100, 60, 0, 5) :: number, math.pi / 2, 1e-12, "straight up")
	end)

	t.test("exact step matches the closed form", function()
		local x, y, z, vx, vy, vz = 0, 0, 0, 3, 40, -2
		for _ = 1, 15 do
			x, y, z, vx, vy, vz = Ballistics.step(x, y, z, vx, vy, vz, 60, 1 / 15)
		end
		near(t, x, 3, 1e-9, "x after 1 s")
		near(t, y, 40 - 30, 1e-9, "y after 1 s")
		near(t, z, -2, 1e-9, "z after 1 s")
		near(t, vy, 40 - 60, 1e-9, "vy after 1 s")
	end)

	t.test("segment vs cylinder", function()
		local seg = Ballistics.segmentCylinder
		-- straight through the middle: enters at x = 7 of a 0..20 segment
		near(t, seg(0, 1, 0, 20, 1, 0, 10, 0, 3, 0, 6) :: number, 7 / 20, 1e-12, "entry t")
		t.equal(seg(0, 1, 5, 20, 1, 5, 10, 0, 3, 0, 6), nil, "passes beside")
		t.equal(seg(0, 8, 0, 20, 8, 0, 10, 0, 3, 0, 6), nil, "passes over the top")
		near(t, seg(0, 9, 0, 20, -1, 0, 10, 0, 3, 0, 6) :: number, 0.35, 1e-12, "descending into the side")
		near(t, seg(10, 10, 0, 10, 0, 0, 10, 0, 3, 0, 6) :: number, 0.4, 1e-12, "falling onto the top")
		t.equal(seg(0, 0, 0, 6, 0, 0, 10, 0, 3, 0, 6), nil, "stops short")
		near(t, seg(10, 2, 0, 30, 2, 0, 10, 0, 3, 0, 6) :: number, 0, 1e-12, "starts inside")
		-- a fast round crossing a thin unit within one tick is still caught
		t.expect(seg(-100, 3, 0, 100, 3, 0, 0, 0, 1, 0, 6) ~= nil, "no tunneling")
	end)

	t.test("distance to cylinder and AoE falloff", function()
		near(t, Ballistics.distanceToCylinder(10, 3, 0, 0, 0, 4, 0, 6), 6, 1e-12, "side")
		near(t, Ballistics.distanceToCylinder(0, 10, 0, 0, 0, 4, 0, 6), 4, 1e-12, "above")
		near(t, Ballistics.distanceToCylinder(1, 3, 1, 0, 0, 4, 0, 6), 0, 1e-12, "inside")
		near(t, Ballistics.distanceToCylinder(6, 9, 0, 0, 0, 3, 0, 5), 5, 1e-12, "corner (3-4-5)")
		near(t, Ballistics.falloff(0, 20, 0.25), 1, 1e-12, "center")
		near(t, Ballistics.falloff(10, 20, 0.25), 1 - 0.5 * 0.75, 1e-12, "half radius")
		near(t, Ballistics.falloff(19.999, 20, 0.25), 0.25, 1e-3, "edge")
		t.equal(Ballistics.falloff(20, 20, 0.25), 0, "outside")
		t.equal(Ballistics.falloff(0, 0, 0.5), 1, "no aoe: direct only")
		t.equal(Ballistics.falloff(1, 0, 0.5), 0)
	end)
end
