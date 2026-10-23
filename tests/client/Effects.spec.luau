--!strict
-- Combat effects (client task 7): projectiles follow the server, IMPACT
-- ends them, effects wait for the render clock, and the caps hold.

local Commands = require("../../src/client/Core/Commands")
local Combat = require("../../src/server/Sim/Combat/Combat")
local EW = require("../../src/server/Sim/EW")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function duel()
	local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
	return sim, world
end

return function(t: any)
	t.test("unguided shells match the server's projectiles while they fly; IMPACT ends them", function()
		local sim, world = duel()
		local fx = Effects.new()
		local compared, worst, impacts = 0, 0, 0
		for tick = 1, 240 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			-- render exactly at the newest tick (no delay) so client and server line up
			local before = #fx.bursts
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				if b.kind == "impact" and b.born == tick * DT then
					impacts += 1
				end
			end
			local _ = before
			table.clear(world.died)
			-- every server projectile the client has is where the server has it
			local c = sim.combat
			for id, p in fx.projectiles do
				if c.projSlot[id] then
					local dx = p.x - c.px[id]
					local dy = p.y - c.py[id]
					local dz = p.z - c.pz[id]
					local d = math.sqrt(dx * dx + dy * dy + dz * dz)
					worst = math.max(worst, d)
					compared += 1
				end
			end
		end
		t.expect(compared > 50, `compared {compared} projectile ticks`)
		t.expect(worst < 0.5, `worst drift {worst} studs (wire quantization only)`)
		t.expect(impacts > 10, `impact bursts: {impacts}`)
		local live = 0
		for _ in fx.projectiles do
			live += 1
		end
		t.expect(live < 10, "projectiles end on IMPACT, they don't pile up")
	end)

	t.test("events and deaths wait for the render clock", function()
		local sim, world = duel()
		local fx = Effects.new()
		local firstSpawnTick
		for tick = 1, 120 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, e in world.events do
				if (e :: any).kind == Schema.EventKind.SPAWN_PROJ and firstSpawnTick == nil then
					firstSpawnTick = (e :: any).tick
				end
			end
			if firstSpawnTick then
				break
			end
		end
		t.expect(firstSpawnTick ~= nil, "a shell was fired")
		-- the render clock is two ticks behind: nothing yet
		Effects.update(fx, world, firstSpawnTick - 2, 0, 0, 0)
		t.expect(next(fx.projectiles) == nil, "not before its tick")
		t.expect(#world.events > 0, "still queued")
		Effects.update(fx, world, firstSpawnTick, 0, 0, 0)
		t.expect(next(fx.projectiles) ~= nil, "spawned at its tick")
		-- deaths: queued with their tick
		local deaths = 0
		for tick = sim.tick + 1, sim.tick + 400 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, d in world.died do
				t.expect(d.tick == tick, "a death carries its tick")
				deaths += 1
			end
			Effects.update(fx, world, tick - 2, tick * DT, 0, 0)
			for _, d in fx.pendingDeaths do
				t.expect(d.tick > tick - 2, "only deaths not yet due wait")
			end
			table.clear(world.died)
		end
		t.expect(deaths > 0, "tanks died")
	end)

	t.test("a shell bursts when its drawn path reaches the impact point, not a tick later (C-26)", function()
		local sim, world = duel()
		local fx = Effects.new()
		local SUBS = 8 -- frames per sim tick
		-- Projectile IDs are reused (and since C-27 the next shell with an ID
		-- can launch before the last one has burst), so shells are tracked as
		-- objects and paired with the server's own SPAWN_PROJ / IMPACT events:
		-- a shell's impact is the first IMPACT of its ID at or after its spawn.
		local spawns: { [number]: { number } } = {} -- projId → server spawn ticks
		local impacts: { [number]: { { number } } } = {} -- projId → { tick, x, z }
		local spawnOf: { [any]: number } = {} -- shell → its spawn tick
		local path: { [any]: { { number } } } = {} -- shell → drawn { renderTick, x, z }
		local delays = {}
		for tick = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" then
					spawns[e.other] = spawns[e.other] or {}
					table.insert(spawns[e.other], e.tick)
				elseif e.kind == "IMPACT" then
					impacts[e.other] = impacts[e.other] or {}
					table.insert(impacts[e.other], { e.tick, e.x, e.z })
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for sub = 1, SUBS do
				local rt = tick - 2 + sub / SUBS -- two ticks behind, as Interp
				local live = {}
				for _, shell in fx.projectiles do
					live[shell] = true
				end
				Effects.update(fx, world, rt, rt * DT, 0, 0)
				table.clear(world.died)
				for _, shell in fx.projectiles do
					if spawnOf[shell] == nil then
						-- launched now (a tick early, C-27): its spawn is the first one not before fx.tick
						for _, st in spawns[shell.id] or {} do
							if st >= fx.tick and (spawnOf[shell] == nil or st < spawnOf[shell]) then
								spawnOf[shell] = st
							end
						end
					end
				end
				for shell in live do
					if fx.projectiles[shell.id] == shell then
						continue -- still flying
					end
					local st, drawn = spawnOf[shell], path[shell]
					local hit
					for _, im in impacts[shell.id] or {} do
						if st and im[1] >= st and (hit == nil or im[1] < hit[1]) then
							hit = im
						end
					end
					if hit and drawn then
						-- first frame the drawn shell was as far from its start as the impact point
						local s = drawn[1]
						local need = math.sqrt((hit[2] - s[2]) ^ 2 + (hit[3] - s[3]) ^ 2)
						for _, f in drawn do
							if math.sqrt((f[2] - s[2]) ^ 2 + (f[3] - s[3]) ^ 2) >= need - 1 then
								table.insert(delays, rt - f[1])
								break
							end
						end
					end
					spawnOf[shell], path[shell] = nil, nil
				end
				for _, v in Effects.visible(fx, rt) do
					local shell = v[1]
					path[shell] = path[shell] or {}
					table.insert(path[shell], { rt, v[2], v[4] })
				end
			end
		end
		local worst = 0
		for _, d in delays do
			worst = math.max(worst, d)
		end
		print(string.format("    %d shells; worst delay after reaching the impact point %.1f ms", #delays, worst * DT * 1000))
		t.expect(#delays > 50, "plenty of impacts")
		t.expect(worst <= 1 / SUBS + 1e-9, `the burst comes within a frame of arrival (worst {worst} ticks)`)
	end)

	t.test("a launched shell is first drawn at the shooter's barrel tip, then joins the server's path (C-27)", function()
		local sim, world = duel()
		local fx = Effects.new()
		local SUBS = 8
		-- a stand-in barrel tip: 5 studs ahead of the hull, 3 up
		local muzzles: { { number } } = {}
		local function muzzleOf(id: number, _slot: number)
			local u = world.units[id]
			local mx, my, mz = u.x + math.sin(u.heading) * 5, World.groundY(world, u.x, u.z) + 3, u.z + math.cos(u.heading) * 5
			table.insert(muzzles, { mx, my, mz })
			return mx, my, mz
		end
		local seen: { [number]: boolean } = {}
		local launched, atBarrel, worst = 0, 0, 0
		local joined, checkedJoin = 0, 0
		for tick = 1, 240 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for sub = 1, SUBS do
				local rt = tick - 2 + sub / SUBS
				table.clear(muzzles)
				Effects.update(fx, world, rt, rt * DT, 0, 0, muzzleOf)
				table.clear(world.died)
				for _, v in Effects.visible(fx, rt) do
					local p = v[1]
					if not seen[p.id] then
						seen[p.id] = true
						launched += 1
						local best = math.huge
						for _, m in muzzles do
							best = math.min(best, math.sqrt((v[2] - m[1]) ^ 2 + (v[3] - m[2]) ^ 2 + (v[4] - m[3]) ^ 2))
						end
						worst = math.max(worst, if best < math.huge then best else 0)
						-- at most an eighth of a tick's flight from the tip (the old way: a whole tick's, ~23 studs)
						local speed = math.sqrt(p.vx ^ 2 + p.vy ^ 2 + p.vz ^ 2)
						if best <= speed * DT / SUBS + 1.5 then
							atBarrel += 1
						end
					elseif p.blend == 0 then
						checkedJoin += 1
						if p.ox == 0 and p.oy == 0 and p.oz == 0 then
							joined += 1
						end
					end
				end
				for id in seen do
					if fx.projectiles[id] == nil then
						seen[id] = nil -- IDs are reused
					end
				end
			end
		end
		print(string.format("    %d launches: %d drawn first at the barrel tip (worst %.1f studs off)", launched, atBarrel, worst))
		t.expect(launched > 50, "plenty of shells")
		t.equal(atBarrel, launched, "every shell starts at its barrel")
		t.expect(checkedJoin > 0 and joined == checkedJoin, "after the blend, drawn = the server's path")
	end)

	t.test("drawn missiles fly smooth paths through corrections and decoys (C-36)", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "ew_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local fx = Effects.new()
		local SUBS = 4 -- 60 fps
		local last: { [any]: { any } } = {}
		local worst, frames, decoys = 0, 0, 0
		for tick = 1, 300 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "DECOYED" then
					decoys += 1
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for sub = 1, SUBS do
				local rt = tick - 2 + sub / SUBS
				Effects.update(fx, world, rt, rt * DT, 0, 0)
				table.clear(world.died)
				for _, v in Effects.visible(fx, rt) do
					local p = v[1]
					if p.weapon.turnRate then
						-- how far this frame's point is off the straight continuation of the last two
						local l = last[p]
						if l and l[1] then
							local a, b = l[1], l[2]
							local d = math.sqrt((v[2] - (2 * b[1] - a[1])) ^ 2 + (v[3] - (2 * b[2] - a[2])) ^ 2 + (v[4] - (2 * b[3] - a[3])) ^ 2)
							worst = math.max(worst, d)
							frames += 1
						end
						last[p] = { l and l[2], { v[2], v[3], v[4] } }
					end
				end
			end
		end
		print(string.format("    ew_test: %d missile frames, worst %.2f studs off a straight continuation, %d decoyed", frames, worst, decoys))
		t.expect(frames > 100 and decoys > 0, "missiles flew, and one was decoyed")
		t.expect(worst <= 3, `no jumps or corners (worst {worst} studs; a missile covers ~7 a frame)`)
	end)

	t.test("a radar missile whose target dies spirals down on the server's path (S-146, C-181)", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local aegis = Spawn.unit(sim, "ord_aegis", 1, -200, 0)
		local wasp = Spawn.unit(sim, "chs_wasp", 2, 100, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local fx = Effects.new()
		local c = sim.combat
		local missile, lostAt = 0, nil
		local worst, compared, spun = 0, 0, false
		for tick = 1, 15 * 30 do
			Sim.step(sim)
			for _, e in c.events do
				if missile == 0 and e.kind == "SPAWN_PROJ" and e.unit == aegis then
					missile = e.other
				elseif e.kind == "LOST_LOCK" and e.other == missile then
					lostAt = tick
				end
			end
			-- once it has turned onto the Wasp, the Wasp dies (another weapon)
			if missile ~= 0 and lostAt == nil and sim.world.slot[wasp] and c.projSlot[missile] and bit32.band(c.pFlags[missile], EW.Flag.TURNED) ~= 0 then
				Combat.queueDamage(c, wasp, sim.world.health[wasp] * 10, 0)
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			local p = fx.projectiles[missile]
			if lostAt and p and c.projSlot[missile] and tick > lostAt then
				spun = spun or p.lost ~= nil
				local d = math.sqrt((p.x - c.px[missile]) ^ 2 + (p.y - c.py[missile]) ^ 2 + (p.z - c.pz[missile]) ^ 2)
				worst = math.max(worst, d)
				compared += 1
			end
			if lostAt and c.projSlot[missile] == nil then
				break
			end
		end
		print(string.format("    lost radar missile: %d ticks compared, worst %.2f studs off the server", compared, worst))
		t.expect(missile ~= 0, "the SAM launched")
		t.expect(lostAt ~= nil, "the missile lost its target")
		t.expect(spun, "the client spirals it (Guidance.lost)")
		t.expect(compared >= 10, `it flew on after the loss ({compared} ticks)`)
		t.expect(worst < 0.5, `on the server's path (worst {worst} studs; wire quantization only)`)
	end)

	t.test("bursts carry what the effects need: launch clouds, countermeasures toward the decoy point, ground and direction (C-47, C-48)", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "ew_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local fx = Effects.new()
		local seen: { [any]: boolean } = {}
		local kinds: { [string]: number } = {}
		local decoyPoints = {}
		for tick = 1, 300 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, e in world.events do
				if (e :: any).kind == Schema.EventKind.DECOYED and (e :: any).decoyTicks > 0 then
					local x, z = world.grid:decode((e :: any).decoyCell, (e :: any).decoyOffX, (e :: any).decoyOffZ)
					table.insert(decoyPoints, { x, (e :: any).decoyY / Schema.Y_SCALE, z })
				end
			end
			local rt = tick - 1.5
			Effects.update(fx, world, rt, rt * DT, 0, 0)
			table.clear(world.died)
			for _, b in fx.bursts do
				if seen[b] then
					continue
				end
				seen[b] = true
				kinds[b.kind] = (kinds[b.kind] or 0) + 1
				if b.kind == "launch" or b.kind == "impact" or b.kind == "flare" or b.kind == "chaff" or b.kind == "dircm" then
					t.expect(b.ground ~= nil, `a {b.kind} knows the ground under it`)
				end
				if b.kind == "launch" or b.kind == "flare" or b.kind == "chaff" or b.kind == "dircm" then
					t.expect(b.dx ~= nil and math.abs(b.dx ^ 2 + (b.dy :: number) ^ 2 + (b.dz :: number) ^ 2 - 1) < 1e-6, `a {b.kind} faces a unit direction`)
				end
				if b.kind == "flare" or b.kind == "chaff" then
					-- flares head for the decoy point from the aircraft; chaff blooms there
					local px, py, pz = if b.kind == "flare" then b.tx else b.x, if b.kind == "flare" then b.ty else b.y, if b.kind == "flare" then b.tz else b.z
					local near = false
					for _, d in decoyPoints do
						near = near or (d[1] - (px :: number)) ^ 2 + (d[2] - (py :: number)) ^ 2 + (d[3] - (pz :: number)) ^ 2 < 1
					end
					t.expect(near, "flares head for the decoy point the server sent")
				elseif b.kind == "dircm" then
					t.expect(b.tx ~= nil, "a jammer laser ends on the missile")
				end
			end
		end
		local parts = {}
		for k, n in kinds do
			table.insert(parts, `{k} {n}`)
		end
		table.sort(parts)
		print(`    ew_test bursts: {table.concat(parts, ", ")}`)
		t.expect((kinds.launch or 0) > 0, "missiles leave in a launch cloud")
		t.expect((kinds.flare or 0) + (kinds.chaff or 0) + (kinds.dircm or 0) > 0, "a decoyed missile shows what seduced it")
	end)

	t.test("the countermeasure drawn is the one the server names, else follows the target's equipment (C-48, S-38)", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:32", scenario = "empty" })
		local world = World.new(sim.defs)
		local function unit(defId: string): any
			return { defIndex = table.find(sim.defs.unitByIndex, sim.defs.units[defId]) }
		end
		t.equal(Effects.countermeasure(world, unit("ord_falcon"), "IR"), "dircm") -- chaff and DIRCM, no flares
		t.equal(Effects.countermeasure(world, unit("ord_guardian"), "IR"), "dircm") -- a helicopter with DIRCM only
		t.equal(Effects.countermeasure(world, unit("chs_wasp"), "IR"), "flare") -- a helicopter with flares
		t.equal(Effects.countermeasure(world, unit("ord_falcon"), "RADAR"), "chaff")
		t.equal(Effects.countermeasure(world, nil, "IR"), "flare") -- a contact of unknown type
		-- radar SAMs carry heavy warheads: their explosions are drawn bigger than the IR ones (C-52)
		t.expect(Effects.impactSize(sim.defs.weapons.chs_radar_sam) > Effects.impactSize(sim.defs.weapons.chs_ir_sam), "radar SAM explosions are the bigger ones")
		-- the server says which one won (protocol 13, S-38): that wins over the guess
		t.equal(Effects.countermeasure(world, unit("chs_wasp"), "IR", Schema.Countermeasure.DIRCM), "dircm")
		t.equal(Effects.countermeasure(world, unit("ord_falcon"), "IR", Schema.Countermeasure.FLARES), "flare")
		t.equal(Effects.countermeasure(world, unit("ord_falcon"), "RADAR", Schema.Countermeasure.CHAFF), "chaff")
	end)

	t.test("SAM missiles chasing circling jets bend smoothly, with no corner at tick boundaries (C-38)", function()
		-- the `sam` test scene: 4 Thorn IR SAM sites, 4 Falcons (5x health) over them
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		for i = 0, 3 do
			local f = Spawn.unit(sim, "ord_falcon", 1, -60, -60 + i * 40, math.pi / 2)
			ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 5)
			-- under the jets' 220-stud loiter circle: in reach of the Thorn's 206 (S-56)
		Spawn.unit(sim, "chs_thorn", 2, -130 + (i % 2) * 140, -70 + (i // 2) * 140, 0)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local fx = Effects.new()
		local SUBS = 8
		local last: { [any]: { any } } = {}
		local sum, n, worst, atBoundary, boundaryN = 0, 0, 0, 0, 0
		for tick = 1, 15 * 30 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for sub = 1, SUBS do
				local rt = tick - 2 + sub / SUBS
				Effects.update(fx, world, rt, rt * DT, 0, 0)
				table.clear(world.died)
				for _, v in Effects.visible(fx, rt) do
					local p = v[1]
					if p.weapon.turnRate then
						local l = last[p]
						if l and l[1] then
							local a, b = l[1], l[2]
							local d = math.sqrt((v[2] - (2 * b[1] - a[1])) ^ 2 + (v[3] - (2 * b[2] - a[2])) ^ 2 + (v[4] - (2 * b[3] - a[3])) ^ 2)
							sum += d
							n += 1
							worst = math.max(worst, d)
							if sub == 1 then -- the frame just past a tick boundary
								atBoundary += d
								boundaryN += 1
							end
						end
						last[p] = { l and l[2], { v[2], v[3], v[4] } }
					end
				end
			end
		end
		local mean, boundary = sum / math.max(n, 1), atBoundary / math.max(boundaryN, 1)
		print(string.format("    sam scene: %d missile frames, bend mean %.3f studs (at tick boundaries %.3f), worst %.2f", n, mean, boundary, worst))
		t.expect(n > 1000, "plenty of missile frames")
		t.expect(worst <= 3, `no jumps (worst {worst} studs)`)
		-- C-38's corners were ~1 stud a frame; with proportional navigation
		-- (S-27) paths are so straight that the mean bend halved, and at the
		-- Thorn's 206 studs (S-56) most of a ~6-tick flight is the terminal
		-- turn, so 0.15 stud at the boundary still counts as smooth
		t.expect(boundary <= math.max(mean * 1.5, 0.15), `no corner at tick boundaries ({boundary} vs {mean} on average)`)
	end)

	t.test("caps: at most 150 drawn projectiles, 60 bursts, 100 tracers; the far, small ones go first", function()
		local _sim, world = duel()
		local fx = Effects.new()
		fx.focusX, fx.focusZ = 0, 0
		local weapon = world.defs.weaponByIndex[1]
		for i = 1, 400 do
			-- half near the focus, half far away
			local far = i % 2 == 0
			fx.projectiles[i] = {
				id = i,
				x = if far then 2000 else i * 0.1,
				y = 20,
				z = 0,
				vx = 0,
				vy = 0,
				vz = 0,
				ox = 0,
				oy = 0,
				oz = 0,
				blend = 0,
				weapon = { gravity = 0 },
				target = 0,
				ttl = 100,
				size = 1,
			}
		end
		fx.tick = 10
		local drawn = Effects.visible(fx, 10.5)
		t.equal(#drawn, Effects.MAX_PROJECTILES)
		for _, v in drawn do
			t.expect(v[2] < 1000, "near ones are drawn first")
		end
		-- bursts and tracers through the event path
		local function event(kind: number, x: number): any
			local cell, offX, offZ = world.grid:encode(x, 0)
			return { kind = kind, projId = 9999, unitId = 1, slot = 1, hit = true, cell = cell, offX = offX, offZ = offZ, y = 80, tick = 11 }
		end
		world.joined = true
		for i = 1, 200 do
			table.insert(world.events, event(Schema.EventKind.IMPACT, if i % 2 == 0 then 180 else 0))
		end
		Effects.update(fx, world, 11, 0, 0, 0)
		t.equal(#fx.bursts, Effects.MAX_EXPLOSIONS)
		t.expect(fx.skipped.bursts == 200 - Effects.MAX_EXPLOSIONS, "the rest were skipped")
		local near = 0
		for _, b in fx.bursts do
			if math.abs(b.x) < 10 then
				near += 1
			end
		end
		t.expect(near >= Effects.MAX_EXPLOSIONS / 2 + 10, `near bursts kept first ({near})`)
		local _ = weapon
	end)

	t.test("beam rays: Radiance lingers 3 s, the last second narrowing to nothing (C-128)", function()
		t.equal(Effects.beamSeconds({ id = "ord_radiance_beam" }), 3)
		t.equal(Effects.beamSeconds({ id = "chs_inferno_beam" }), 1.5)
		t.equal(Effects.beamSeconds({ id = "ord_radiance_beam", beamDuration = 2.5 }), 2.5, "the sim's duration wins once it is in the defs")
		local w0, a0 = Effects.beamLook(0, 3)
		local w1, _ = Effects.beamLook(1.9, 3)
		local w2, a2 = Effects.beamLook(2.5, 3)
		local w3, a3 = Effects.beamLook(3, 3)
		t.expect(w0 == 1 and w1 == 1, "full width for the first two seconds")
		t.expect(math.abs(w2 - 0.5) < 1e-9 and a2 > a0, "half way through the last second: half as wide, fainter")
		t.expect(w3 == 0 and a3 == 1, "gone at the end")
		local ws, _ = Effects.beamLook(1.0, 1.5)
		t.expect(ws < 1, "a short ray fades over its last half")
	end)

	t.test("a beam stopped on a shield dome glances off downward (C-129)", function()
		local flat = function(_x: number, _z: number): number
			return 0
		end
		local domes = { { 0, 0, 0, 100 } }
		-- level shot from the south hitting the dome's side 10 up
		local hz = -math.sqrt(100 ^ 2 - 10 ^ 2)
		local gx, gy, gz = Effects.deflection(0, 10, -400, 0, 10, hz, domes, flat)
		t.expect(gx ~= nil, "deflected")
		t.expect((gz :: number) < hz, "back away from the dome, as in the sketch")
		t.expect(math.abs(gy :: number) < 1e-6, "into the ground")
		local reach = math.sqrt(((gx :: number) - 0) ^ 2 + ((gz :: number) - hz) ^ 2 + 10 ^ 2)
		t.expect(reach >= Effects.DEFLECT_MIN - 1e-6 and reach <= Effects.DEFLECT_MAX + 1e-6, "a short leg")
		t.equal((Effects.deflection(0, 10, -400, 0, 10, -250, domes, flat)), nil, "a beam ending away from any dome isn't deflected")
		t.equal((Effects.deflection(0, 10, -50, 0, 10, hz, domes, flat)), nil, "nor one fired from inside")
	end)

	t.test("a beam whose dome drops goes on to its new end (C-144)", function()
		local fx = Effects.new()
		local radiance = { id = "ord_radiance_beam", type = "BEAM" }
		table.insert(fx.tracers, { x0 = 0, y0 = 10, z0 = 0, x1 = 0, y1 = 10, z1 = -100, born = 0, life = 3, hit = false, size = 1, beam = "order", weaponId = radiance.id, deflect = { 5, 0, -90 }, pulseAt = 0.2 })
		t.expect(Effects.continueBeam(fx, radiance, 0.5, 10, 0, 0, 5, -220, true, 1.2), "the burning beam is continued")
		local tr = fx.tracers[1]
		t.expect(tr.z1 == -220 and tr.hit and tr.deflect == nil and tr.pulseAt == nil and tr.born == 0, "to the new end, no glance, same start time")
		t.equal(#fx.tracers, 1, "no second beam")
		t.expect(not Effects.continueBeam(fx, radiance, 0, 10, 0, 0, 5, -220, true, 3.5), "a burnt-out beam is not continued")
		t.expect(not Effects.continueBeam(fx, { id = "chs_inferno_beam", type = "BEAM" }, 0, 10, 0, 0, 5, -220, true, 1), "another weapon's beam isn't")
	end)
end
