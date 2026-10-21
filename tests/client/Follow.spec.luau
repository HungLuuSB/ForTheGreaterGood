--!strict
-- Camera follow (C-43): what T picks, where the target is drawn, when it
-- ends, and the focus that keeps an airborne target in the screen's middle.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local Follow = require("../../src/client/Core/Follow")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15
local PITCH = math.rad(55) -- Camera.PITCH

-- the `sam` test scene: 4 Thorn IR SAM sites, 4 Falcons (5x health) over them
local function samScene()
	local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
	local falcons = {}
	for i = 0, 3 do
		local f = Spawn.unit(sim, "ord_falcon", 1, -60, -60 + i * 40, math.pi / 2)
		ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 5)
		table.insert(falcons, f)
		Spawn.unit(sim, "chs_thorn", 2, -100 + (i % 2) * 200, -100 + (i // 2) * 200, 0)
	end
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
	return sim, world, falcons
end

local function near(t: any, actual: number, expected: number)
	t.expect(math.abs(actual - expected) < 1e-9, `expected {expected}, got {actual}`)
end

-- top-down projector: screen x, y = world x, z
local function topDown(x: number, _y: number, z: number): (number, number, boolean)
	return x, z, true
end

-- angle (degrees) between the camera's sight line to its focus and to the point
local function offCentre(px: number, py: number, pz: number, fx: number, fz: number, groundAt: (number, number) -> number, yaw: number): number
	local fy = groundAt(fx, fz)
	local bx, by, bz = -math.sin(yaw) * math.cos(PITCH), math.sin(PITCH), math.cos(yaw) * math.cos(PITCH)
	local cx, cy, cz = fx + bx * 400, fy + by * 400, fz + bz * 400
	local ax, ay, az = fx - cx, fy - cy, fz - cz
	local qx, qy, qz = px - cx, py - cy, pz - cz
	local cos = (ax * qx + ay * qy + az * qz) / math.sqrt((ax * ax + ay * ay + az * az) * (qx * qx + qy * qy + qz * qz))
	return math.deg(math.acos(math.clamp(cos, -1, 1)))
end

return function(t: any)
	t.test("the focus keeps an airborne target on the screen's centre line", function()
		local flat = function(_x: number, _z: number): number
			return 0
		end
		-- a jet 110 studs up, camera north-up (it sits south, +Z): the focus is alt / tan(pitch) north of the jet
		local fx, fz, minDistance = Follow.focus(100, 110, 50, PITCH, 0, flat)
		near(t, fx, 100)
		near(t, fz, 50 - 110 / math.tan(PITCH))
		t.expect(offCentre(100, 110, 50, fx, fz, flat, 0) < 1e-6, "on the centre line")
		-- the least distance keeps it MIN_GAP in front of the camera
		near(t, minDistance, 110 / math.sin(PITCH) + Follow.MIN_GAP)
		-- a missile 560 studs up at zoom 450 would be behind the camera: the least distance is beyond it
		local _, _, far = Follow.focus(0, 560, 0, PITCH, 0, flat)
		t.expect(far > 560 / math.sin(PITCH) and far > 450, `least distance {far} keeps a high missile in front`)
		-- turned 30°, and on a slope: still within a fraction of a degree
		local slope = function(_x: number, z: number): number
			return 20 + 0.15 * z
		end
		for _, yaw in { 0, math.rad(30), -math.rad(45) } do
			local gx, gz = Follow.focus(-200, 140, 80, PITCH, yaw, slope)
			local off = offCentre(-200, 140, 80, gx, gz, slope, yaw)
			t.expect(off < 0.5, `yaw {math.deg(yaw)}°, sloped ground: {off}° off centre`)
		end
		-- a ground unit is its own focus
		local gx, gz, groundMin = Follow.focus(10, 0, 20, PITCH, 0.3, flat)
		near(t, gx, 10)
		near(t, gz, 20)
		near(t, groundMin, Follow.MIN_GAP)
	end)

	t.test("T picks the first selected unit, else the missile nearest the screen centre", function()
		local sim, world, falcons = samScene()
		local fx = Effects.new()
		t.expect(Follow.pick(world, {}, {}, topDown, 0, 0) == nil, "nothing selected, no missiles: nothing to follow")
		local picked = 0
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local rt = tick - 1.5
			Effects.update(fx, world, rt, rt * DT, 0, 0)
			table.clear(world.died)
			local visible = Effects.visible(fx, rt)
			local unit = Follow.pick(world, { 9999, falcons[2], falcons[1] }, visible, topDown, 0, 0)
			if world.units[falcons[2]] then
				t.expect(unit ~= nil and unit.kind == "unit" and unit.id == falcons[2], "the first selected unit the world knows")
			end
			-- nothing selected: the homing missile drawn nearest the centre (here world point 50, -30)
			local best, bestD = nil, math.huge
			for _, v in visible do
				local d = (v[2] - 50) ^ 2 + (v[4] + 30) ^ 2
				if (v[1] :: Effects.Proj).weapon.type == "HOMING" and d < bestD then
					best, bestD = v[1], d
				end
			end
			local m = Follow.pick(world, {}, visible, topDown, 50, -30)
			if best then
				picked += 1
				t.expect(m ~= nil and m.kind == "missile" and m.proj == best and m.id == (best :: Effects.Proj).id, "the nearest homing missile")
			else
				t.expect(m == nil, "no missile, nothing to follow")
			end
		end
		print(string.format("    %d frames with a missile to pick", picked))
		t.expect(picked > 50, `missiles were picked ({picked} frames)`)
	end)

	t.test("a followed missile is drawn where Effects draws it and ends with it; a unit ends when it leaves", function()
		local sim, world, falcons = samScene()
		local fx = Effects.new()
		local target: Follow.Target? = nil
		local frames, ended, units = 0, 0, 0
		for tick = 1, 15 * 30 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local rt = tick - 1.5
			Effects.update(fx, world, rt, rt * DT, 0, 0)
			local visible = Effects.visible(fx, rt)
			if target == nil then
				target = Follow.pick(world, {}, visible, topDown, 0, 0)
			end
			if target then
				local x, y, z = Follow.position(world, fx, visible, target, rt)
				if x then
					frames += 1
					for _, v in visible do
						if v[1] == target.proj then
							t.equal(x, v[2])
							t.equal(y, v[3])
							t.equal(z, v[4])
						end
					end
				else
					t.expect(fx.projectiles[target.id] ~= target.proj, "it ended only when its missile did")
					ended += 1
					target = nil
				end
			end
			-- units: drawn on the ground plus their altitude, until they leave
			for _, id in falcons do
				local u = world.units[id]
				local x, y, z = Follow.position(world, fx, visible, { kind = "unit", id = id }, rt)
				t.expect((u ~= nil) == (x ~= nil), "a unit is followed while the world has it")
				if u and x and u.tier == "tactical" and #u.snaps > 0 then
					units += 1
					t.expect((y :: number) > 60, `a Falcon is drawn in the air ({y})`)
				end
			end
			table.clear(world.died)
		end
		print(string.format("    %d frames following missiles, %d missiles followed to their end, %d Falcon positions", frames, ended, units))
		t.expect(frames > 30 and ended >= 3, "missiles were followed to their end")
		t.expect(units > 100, "Falcon positions checked")
		-- the Falcons (5x health) live through it: a LEAVE or a death takes a unit out of the world
		world.units[falcons[1]] = nil
		t.expect(Follow.position(world, fx, {}, { kind = "unit", id = falcons[1] }, 0) == nil, "a unit gone from the world ends the follow")
		-- a reused projectile ID is a different missile
		local any = next(fx.projectiles)
		if any then
			local x = Follow.position(world, fx, {}, { kind = "missile", id = any, proj = nil }, 0)
			t.expect(x == nil, "a projectile with another Proj table is not the followed missile")
		end
	end)
end
