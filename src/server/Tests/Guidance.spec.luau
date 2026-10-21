--!strict
-- Missile guidance (S-27, client request 13): proportional navigation, the
-- step-start alignment against targets that already moved this tick, and
-- the seeker cone.
local Combat = require("../Sim/Combat/Combat")
local Guidance = require("@shared/Combat/Guidance")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local NetOut = require("../Sim/NetOut")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local DT = 1 / 15

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, wr:finish()))
end

type Salvo = {
	launched: number,
	hits: number,
	decoyed: number,
	lost: number,
	worstTurn: number, -- largest turn in one tick of a decoyed missile (degrees)
	decoyTicks: number, -- ticks decoyed missiles spent following their decoy
	clientDrift: number, -- worst gap between a spectator client's decoyed missile and the server's
	countermeasures: { [number]: number }, -- DECOYED events the client got, by countermeasure (S-38)
}

-- The client's `sam` scene (request 13): four Thorn IR SAM sites, one
-- aircraft that can't die flying over them to (gx, 0) and staying there (a
-- jet circles its goal, a helicopter hovers).
local function salvo(defId: string, gx: number, ticks: number): Salvo
	local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
	local w, c = sim.world, sim.combat
	local target = Spawn.unit(sim, defId, 1, -540, 0, math.pi / 2)
	World.setHealth(w, target, 1e9)
	for _, p in { { 340, -120 }, { 500, -120 }, { 340, 120 }, { 500, 120 } } do
		Spawn.unit(sim, "chs_thorn", 2, p[1], p[2], 0)
	end
	moveTo(sim, 1, { target }, gx, 0)
	local r: Salvo = { launched = 0, hits = 0, decoyed = 0, lost = 0, worstTurn = 0, decoyTicks = 0, clientDrift = 0, countermeasures = {} }
	local sam: { [number]: boolean } = {}
	local decoyed: { [number]: { number } } = {} -- projectile → its velocity last tick
	local spec = NetOut.addSpectator(sim)
	local view = Client.new((sim.map :: any).grid)
	for _ = 1, ticks do
		Sim.step(sim)
		for _, msg in sim.net.spectators[spec].outbox.Events do
			for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
				if e.kind == Schema.EventKind.DECOYED then
					local cm = e.countermeasure :: number
					r.countermeasures[cm] = (r.countermeasures[cm] or 0) + 1
				end
			end
		end
		Client.receive(view, sim.net.spectators[spec].outbox)
		for _, e in c.events do
			if e.kind == "SPAWN_PROJ" or e.kind == "IMPACT" then
				decoyed[e.other] = nil -- gone, or its ID now belongs to a new projectile
			end
		end
		for p, v in decoyed do
			if c.projSlot[p] == nil then
				decoyed[p] = nil
				continue
			end
			local a, b = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2), math.sqrt(c.pvx[p] ^ 2 + c.pvy[p] ^ 2 + c.pvz[p] ^ 2)
			local cosTurn = math.clamp((v[1] * c.pvx[p] + v[2] * c.pvy[p] + v[3] * c.pvz[p]) / (a * b), -1, 1)
			r.worstTurn = math.max(r.worstTurn, math.deg(math.acos(cosTurn)))
			if c.pDecoy[p] then
				r.decoyTicks += 1
			end
			local cp = view.projectiles[p]
			if cp and math.abs(c.px[p]) < 620 and math.abs(c.pz[p]) < 620 then -- the wire clamps positions to the map
				r.clientDrift = math.max(r.clientDrift, math.sqrt((cp.x - c.px[p]) ^ 2 + (cp.y - c.py[p]) ^ 2 + (cp.z - c.pz[p]) ^ 2))
			end
			decoyed[p] = { c.pvx[p], c.pvy[p], c.pvz[p] }
		end
		for _, e in c.events do
			if e.kind == "SPAWN_PROJ" and c.pTeam[e.other] == 2 then
				r.launched += 1
				sam[e.other] = true
			elseif sam[e.other] then
				if e.kind == "IMPACT" then
					sam[e.other] = nil
					if e.unit == target then
						r.hits += 1
					end
				elseif e.kind == "DECOYED" then
					r.decoyed += 1
					decoyed[e.other] = { c.pvx[e.other], c.pvy[e.other], c.pvz[e.other] }
				elseif e.kind == "LOST_LOCK" then
					r.lost += 1
				end
			end
		end
	end
	-- missiles still flying at the end are neither hits nor misses yet
	for p in sam do
		if c.projSlot[p] ~= nil then
			r.launched -= 1
		end
	end
	return r
end

return function(t: RunAll.Context)
	t.test("proportional navigation closes on straight and circling targets well inside the fuse", function()
		for _, circling in { false, true } do
			local worst = 0
			for k = 0, 23 do
				-- launched from a ring 250 studs out, pointing straight at a
				-- 195 studs/s target 100 studs up (the Falcon's cruise)
				local a = k / 24 * 2 * math.pi
				local px, py, pz = math.cos(a) * 250, 0, math.sin(a) * 250
				local tx, ty, tz, th = 0, 100, 0, 0
				local tvx, tvz = 195, 0
				local l = math.sqrt(px * px + 100 * 100 + pz * pz)
				local vx, vy, vz = -px / l * 420, 100 / l * 420, -pz / l * 420
				local best = math.huge
				for _ = 1, 60 do
					vx, vy, vz = Guidance.pn(px, py, pz, vx, vy, vz, tx, ty, tz, tvx, 0, tvz, math.rad(160) * DT, DT)
					if circling then
						th += 195 / 220 * DT -- the loiter circle: 51°/s
						tvx, tvz = math.cos(th) * 195, math.sin(th) * 195
					end
					local nx, ny, nz, ntx, ntz = px + vx * DT, py + vy * DT, pz + vz * DT, tx + tvx * DT, tz + tvz * DT
					for s = 0, 10 do -- closest approach inside the tick
						local f = s / 10
						local dx = px + (nx - px) * f - (tx + (ntx - tx) * f)
						local dy = py + (ny - py) * f - ty
						local dz = pz + (nz - pz) * f - (tz + (ntz - tz) * f)
						best = math.min(best, math.sqrt(dx * dx + dy * dy + dz * dz))
					end
					px, py, pz, tx, tz = nx, ny, nz, ntx, ntz
				end
				worst = math.max(worst, best)
			end
			t.expect(worst < 2.5, `{if circling then "circling" else "straight"} target: worst miss {worst} studs`)
		end
		t.expect(Guidance.inCone(0, 0, 0, 1, 0, 0, 10, 0, 5, math.rad(60)), "27° off the nose is in a 60° cone")
		t.expect(not Guidance.inCone(0, 0, 0, 1, 0, 0, -1, 0, 5, math.rad(60)), "behind is not")
	end)

	t.test("an IR SAM salvo hits a circling jet and a helicopter unless decoyed", function()
		-- before S-27 (lead pursuit against the target's end-of-tick position):
		-- the jet took 33% of the missiles, crossing shots passing 5–9 studs off
		for _, case in { { "ord_falcon", 300, "circling jet" }, { "ord_guardian", 420, "helicopter flying in" }, { "ord_guardian", 200, "hovering helicopter" } } do
			local r = salvo(case[1] :: string, case[2] :: number, 1200)
			print(string.format("    %s: %d launched, %d hits (%.0f%%), %d decoyed (DIRCM), %d lost lock", case[3], r.launched, r.hits, r.hits / math.max(r.launched, 1) * 100, r.decoyed, r.lost))
			t.expect(r.launched >= 20, `{case[3]}: the Thorns fired ({r.launched})`)
			t.equal(r.hits + r.decoyed, r.launched, `{case[3]}: every missile that isn't decoyed hits`)
			-- DIRCM defeats 10–25% (more against a helicopter hovering in range)
			t.expect(r.hits >= r.launched * 0.75, `{case[3]}: at least 75% hit ({r.hits} of {r.launched})`)
			t.equal(r.lost, 0, `{case[3]}: no missile overshoots and loses its lock`)
			-- decoyed missiles bend toward the flares (S-28, request 13d)
			-- Ballistics.steer interpolates directions, which can overshoot the cap by ~0.1%
			t.expect(r.worstTurn <= 160 / 15 * 1.01, `{case[3]}: a decoyed missile turns at most turnRate per tick ({r.worstTurn}°)`)
			-- the Falcon and the Guardian carry DIRCM (and chaff, which only works on radar missiles)
			local dircm = r.countermeasures[Schema.Countermeasure.DIRCM] or 0
			t.equal(dircm, r.decoyed, `{case[3]}: every decoy reported to the client as DIRCM (S-38)`)
			-- the roll comes 20–60 studs out, so a missile passes its decoy within a
			-- tick or two: a short bend instead of the old one-tick 60° kink
			print(string.format("      decoyed: worst turn %.1f° per tick, %d ticks following decoys after the roll", r.worstTurn, r.decoyTicks))
			t.expect(r.clientDrift < 1, `{case[3]}: a client steering decoyed missiles with Guidance.decoy stays on the server's path ({r.clientDrift} studs)`)
		end
	end)

	t.test("a missile that overshoots loses its lock for good: no second pass", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local w, c = sim.world, sim.combat
		local target = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0) -- no countermeasures
		Sim.step(sim)
		local _, ty = Combat.aimPoint(c, w, target)
		-- 30 studs ahead and 30 to the side, flying past at 420 studs/s: a
		-- 160°/s turn (150-stud radius) can't make it
		local weapon = sim.defs.weapons.chs_ir_sam
		local p = Combat.spawnProjectile(c, -30, ty, -30, 420, 0, 0, weapon.index, 0, 2, 3, target, w) :: number
		t.expect(p ~= nil, "spawned")
		local lostAt, closest, after, retargeted = nil, math.huge, {}, false
		for _ = 1, 45 do
			Sim.step(sim)
			if c.projSlot[p] == nil then
				break
			end
			local d = math.sqrt(c.px[p] ^ 2 + (c.pz[p]) ^ 2)
			for _, e in c.events do
				if e.kind == "LOST_LOCK" and e.other == p then
					lostAt = sim.tick
				end
			end
			if lostAt then
				table.insert(after, d)
				retargeted = retargeted or c.pTarget[p] ~= 0
			else
				closest = math.min(closest, d)
			end
		end
		t.expect(lostAt ~= nil, "LOST_LOCK once the target is outside the seeker's 60° cone")
		t.expect(not retargeted, "no target afterwards")
		for i = 2, #after do
			t.expect(after[i] > after[i - 1], `flying away after losing the lock (tick {i}: {after[i]} after {after[i - 1]})`)
		end
		t.expect(#after >= 5, `it flew on ({#after} ticks) instead of turning back`)
	end)
end
