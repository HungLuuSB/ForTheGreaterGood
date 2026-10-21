--!strict
-- Missile sensor view (C-39): what it shows for the `sam` test scene's
-- missiles, how well its prediction follows the server, and its marks.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local MissileView = require("../../src/client/Core/MissileView")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15

-- the `sam` test scene: 4 Thorn IR SAM sites, 4 Falcons (5x health) over them
local function samScene()
	local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
	for i = 0, 3 do
		local f = Spawn.unit(sim, "ord_falcon", 1, -60, -60 + i * 40, math.pi / 2)
		ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 5)
		Spawn.unit(sim, "chs_thorn", 2, -100 + (i % 2) * 200, -100 + (i // 2) * 200, 0)
	end
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
	return sim, world
end

return function(t: any)
	t.test("the sam scene: each drawn missile has its target, aim point, path, fuse and label", function()
		local sim, world = samScene()
		local fx = Effects.new()
		local entries, locked, maxShown, paths = 0, 0, 0, 0
		local inside, outside = 0, 0
		for tick = 1, 15 * 30 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local rt = tick - 2 + 0.5
			Effects.update(fx, world, rt, rt * DT, 0, 0)
			table.clear(world.died)
			local view = MissileView.build(fx, world, rt, Effects.visible(fx, rt))
			maxShown = math.max(maxShown, #view)
			for _, e in view do
				entries += 1
				local p = fx.projectiles[e.id]
				t.expect(p ~= nil and p.weapon.type == "HOMING", "homing missiles only")
				t.equal(e.fuse, 5) -- chs_ir_sam's aoe
				t.expect(string.find(e.label, "IR", 1, true) == 1, `label starts with the guidance: {e.label}`)
				-- the seeker cone (C-42): Thorn's IR seeker, 60° off the nose, out to its lock range
				t.equal(e.seekerAngle, 60)
				t.equal(e.seekerRange, 280)
				t.expect(math.abs(e.fx * e.fx + e.fy * e.fy + e.fz * e.fz - 1) < 1e-6, "the flight direction is a unit vector")
				if #e.path >= 6 then
					paths += 1
				end
				if e.locked then
					locked += 1
					t.expect(e.cx ~= nil and e.lx ~= nil and e.distance ~= nil, "a locked missile has its target's centre, its aim point and a distance")
					t.expect(string.find(e.label, "LOCK", 1, true) ~= nil and string.find(e.label, "Falcon", 1, true) ~= nil, `label names the lock and the target: {e.label}`)
					t.expect(e.hullRadius ~= nil and (e.hullRadius :: number) > 0, "the target's hull is known")
					local off = e.offNose :: number
					t.expect(off ~= nil and off >= 0 and off <= 180, `the target's angle off the nose is 0..180 ({off})`)
					t.equal(e.inSeeker, off <= 60)
					t.expect(string.find(e.label, `{math.floor(off + 0.5)}° / 60° off`, 1, true) ~= nil, `label shows the angle off the nose: {e.label}`)
					if e.inSeeker then
						inside += 1
					else
						outside += 1
					end
				else
					t.expect(string.find(e.label, "no lock", 1, true) ~= nil, `label says no lock: {e.label}`)
				end
			end
		end
		print(string.format("    sam scene: %d entries (%d locked: %d with the target in the seeker cone, %d outside), up to %d at once, %d with a path", entries, locked, inside, outside, maxShown, paths))
		-- the server breaks the lock when the target leaves the seeker cone
		-- (S-27), so a locked missile's target is inside it (a drawn missile
		-- may lag the server's by a frame at the cone's edge)
		t.expect(inside > 100 and outside <= math.max(2, locked * 0.02), "locked missiles keep their target inside the seeker cone")
		t.expect(entries > 100 and locked > 100, "missiles were shown, locked on")
		t.expect(maxShown <= MissileView.MAX_MISSILES, "at most MAX_MISSILES")
		t.expect(paths >= entries * 0.9, "almost every missile has a predicted path ahead")
	end)

	t.test("the prediction follows the server's missiles, and its HIT / miss call matches the outcome close in", function()
		local sim, world = samScene()
		local fx = Effects.new()
		local AHEAD = 5
		local pending: { [number]: { { any } } } = {} -- tick → { projId, x, y, z, proj }
		local called: { [number]: boolean } = {} -- projId → predicted hit, made at most 2 ticks before the closest approach
		local sum, n, worst = 0, 0, 0
		local errors = {}
		local agree, disagree = 0, 0
		for tick = 1, 15 * 40 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			-- the outcome of every missile that ended this tick
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and called[e.other] ~= nil then
					local hit = e.unit ~= 0
					if hit == called[e.other] then
						agree += 1
					else
						disagree += 1
					end
					called[e.other] = nil
				end
			end
			-- predictions due this tick against the server's positions
			local c = sim.combat
			for _, rec in pending[tick] or {} do
				local id = rec[1]
				if c.projSlot[id] and fx.projectiles[id] == rec[5] then -- not a reused ID
					local d = math.sqrt((rec[2] - c.px[id]) ^ 2 + (rec[3] - c.py[id]) ^ 2 + (rec[4] - c.pz[id]) ^ 2)
					sum += d
					n += 1
					table.insert(errors, d)
					worst = math.max(worst, d)
				end
			end
			pending[tick] = nil
			-- render at the newest tick so fx.tick is the server's tick
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			for id, p in fx.projectiles do
				if p.weapon.type ~= "HOMING" or p.target == 0 then
					continue
				end
				local pred = Effects.predict(fx, world, p, MissileView.PREDICT_TICKS)
				if #pred.path >= AHEAD * 3 then
					pending[tick + AHEAD] = pending[tick + AHEAD] or {}
					table.insert(pending[tick + AHEAD], { id, pred.path[AHEAD * 3 - 2], pred.path[AHEAD * 3 - 1], pred.path[AHEAD * 3], p })
				end
				if pred.at and pred.at <= 2 and called[id] == nil then
					called[id] = pred.hit
				end
			end
		end
		local mean = sum / math.max(n, 1)
		table.sort(errors)
		local median, p90 = errors[math.max(1, n // 2)] or 0, errors[math.max(1, math.floor(n * 0.9))] or 0
		print(string.format("    %d-tick predictions: %d, median %.2f studs off the server, 90th percentile %.2f, mean %.2f, worst %.1f; hit calls %d right, %d wrong", AHEAD, n, median, p90, mean, worst, agree, disagree))
		t.expect(n > 100, "plenty of predictions checked")
		-- the targets circle, and the prediction flies them straight on: most
		-- paths stay close, the turning end game spreads (missiles fly 28 studs a tick)
		t.expect(median < 3, `predicted {AHEAD} ticks ahead: median {median} studs off`)
		t.expect(p90 < 20, `predicted {AHEAD} ticks ahead: 90th percentile {p90} studs off`)
		t.expect(agree > 10 and disagree <= agree * 0.2, `close in, the HIT / miss call matches the outcome ({agree} right, {disagree} wrong)`)
	end)

	t.test("corrections, decoys and lost locks leave marks that expire and are capped", function()
		local sim, world = samScene()
		local fx = Effects.new()
		local most, kinds = 0, {}
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick - 1.5, tick * DT, 0, 0)
			table.clear(world.died)
			most = math.max(most, #fx.marks)
			for _, m in fx.marks do
				kinds[m.kind] = true
				t.expect(tick * DT - m.born < Effects.MARK_SECONDS, "expired marks are gone")
			end
		end
		t.expect(kinds.correction == true, "homing corrections are marked")
		t.expect(most > 0 and most <= Effects.MAX_MARKS, `at most MAX_MARKS ({most})`)
		Effects.clear(fx)
		t.equal(#fx.marks, 0)
	end)
end
