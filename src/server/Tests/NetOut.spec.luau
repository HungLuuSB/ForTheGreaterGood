--!strict
local NetOut = require("../Sim/NetOut")
local Packer = require("@shared/Net/Packer")
local Scenes = require("./Support/Scenes")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local L = Sensors.Level
local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function camera(sim: Sim.Sim, player: number, minX: number, minZ: number, maxX: number, maxZ: number)
	submit(sim, player, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ })
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = CT.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

-- Two armies with radars, a jammer and a structure, wandering and fighting.
local function battle(seed: number): (Sim.Sim, { number }, { number })
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:96" })
	local rng = Prng.new(seed)
	local mine, theirs = {}, {}
	for i = 1, 10 do
		table.insert(mine, Spawn.unit(sim, "ord_lancer", 1, -300 + rng:nextNumber(-40, 40), (i - 5) * 20, math.pi / 2))
		table.insert(theirs, Spawn.unit(sim, "chs_ravager", 2, 300 + rng:nextNumber(-40, 40), (i - 5) * 20, -math.pi / 2))
	end
	table.insert(mine, Spawn.unit(sim, "ord_oracle", 1, -340, 0))
	table.insert(mine, Spawn.unit(sim, "ord_veil", 1, -320, 60))
	table.insert(theirs, Spawn.unit(sim, "chs_watcher", 2, 340, 0))
	Spawn.unit(sim, "chs_generator", 2, 200, -200)
	Spawn.unit(sim, "ord_generator", 1, -200, 200)
	camera(sim, 1, 0, 20, 50, 70) -- west half
	camera(sim, 2, 45, 20, 95, 70) -- east half
	return sim, mine, theirs
end

-- What the server says `team` may know about `id` right now.
local function knows(sim: Sim.Sim, team: number, id: number): boolean
	return Sensors.level(sim, team, id) ~= L.HIDDEN
end

return function(t: RunAll.Context)
	t.test("1,000 ticks: fog holds, radar is wobbled, messages fit, the client view matches", function()
		local sim, mine, theirs = battle(11)
		local g = (sim.map :: any).grid
		local rng = Prng.new(99)
		local views = { Client.new(g), Client.new(g) }
		local largest = 0
		for _ = 1, 1000 do
			if sim.tick % 120 == 0 then
				moveTo(sim, 1, mine, rng:nextNumber(-300, 100), rng:nextNumber(-200, 200))
				moveTo(sim, 2, theirs, rng:nextNumber(-100, 300), rng:nextNumber(-200, 200))
			end
			Sim.step(sim)
			for pid = 1, 2 do
				local team = sim.players[pid].team
				local outbox = sim.net.players[pid].outbox
				for _, msgs in outbox do
					for _, msg in msgs do
						largest = math.max(largest, buffer.len(msg))
						t.expect(buffer.len(msg) <= Packer.MAX_MESSAGE_BYTES, `message of {buffer.len(msg)} bytes`)
					end
				end
				local view = views[pid]
				Client.receive(view, outbox)
				for _, entry in view.log do
					for _, id in entry.ids do
						if entry.channel == "Leave" or (entry.channel == "Events" and sim.world.slot[id] == nil) then
							continue -- dropping a unit the client already had, or its DEATH
						end
						t.expect(knows(sim, team, id), `player {pid} got {entry.channel} for unit {id} it can't know (tick {sim.tick})`)
						if entry.channel == "Tactical" or entry.channel == "State" then
							t.equal(Sensors.level(sim, team, id), L.VISIBLE, `{entry.channel} only for seen units`)
						end
					end
				end
				-- radar contacts: wobbled cell only
				for _, msg in outbox.Strategic do
					for _, r in (Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeTickHeader)) do
						if bit32.band(r.flags, Schema.StrategicFlag.RADAR_ONLY) ~= 0 then
							local kx, kz = Sensors.knownPosition(sim, team, r.unitId)
							t.equal(r.cell, (g:encode(kx :: number, kz :: number)), "radar cell is the wobbled one")
							t.equal(r.icon, 0, "radar blips carry no type")
						end
					end
				end
			end
		end
		t.expect(sim.combat.stats.kills > 0, "the armies fought")

		-- after the run, each client's view equals the server's knowledge
		for pid = 1, 2 do
			local team = sim.players[pid].team
			local view = views[pid]
			local w = sim.world
			local expected = {}
			for _, id in w.ids do
				if knows(sim, team, id) then
					expected[id] = true
				end
			end
			for _, gid in sim.sensors.ghostIds[team] do
				expected[gid] = true
			end
			for id in expected do
				t.expect(view.units[id] ~= nil, `player {pid} is missing unit {id}`)
			end
			for id, u in view.units do
				t.expect(expected[id] == true, `player {pid} still shows unit {id}`)
				if u.tier == "tactical" then
					t.expect(math.abs(u.x - w.posX[id]) < 1 / 32 and math.abs(u.z - w.posZ[id]) < 1 / 32, `tactical unit {id} position`)
					local def = sim.defs.unitByIndex[w.defIndex[id]]
					t.equal(u.health, math.clamp(math.ceil(w.health[id] / def.health * 255), 0, 255), `tactical unit {id} health`)
				elseif w.slot[id] then
					local kx, kz = Sensors.knownPosition(sim, team, id)
					local cx, cz = g:cellAt(u.x, u.z)
					t.equal(g:index(cx, cz), (g:encode(kx :: number, kz :: number)), `strategic unit {id} cell`)
				end
			end
		end
		print(string.format("    largest message: %d bytes", largest))
	end)

	-- Combat events (D99): every FIRE, SPAWN_PROJ, IMPACT and DECOYED a player
	-- gets is something its ally team may know, and the client's own
	-- projectile stepping follows the server's.
	t.test("combat events: only what the ally team may see, and the client tracks projectiles", function()
		local sim, mine, theirs = battle(12)
		local g = (sim.map :: any).grid
		local c = sim.combat
		local rng = Prng.new(98)
		local views = { Client.new(g), Client.new(g) }
		local counts = { FIRE = 0, SPAWN_PROJ = 0, IMPACT = 0, DECOYED = 0, LOST_LOCK = 0 }
		local known = { {}, {} } -- projectile IDs each client was sent
		local drift = 0
		local EK = Schema.EventKind
		for _ = 1, 600 do
			if sim.tick % 120 == 0 then
				moveTo(sim, 1, mine, rng:nextNumber(-200, 100), rng:nextNumber(-150, 150))
				moveTo(sim, 2, theirs, rng:nextNumber(-100, 200), rng:nextNumber(-150, 150))
			end
			Sim.step(sim)
			for pid = 1, 2 do
				local pn = sim.net.players[pid]
				local ally = sim.players[pid].allyTeam :: number
				local cam = pn.camera :: { number }
				local function inCamera(x: number, z: number): boolean
					local cx, cz = g:cellAt(x, z)
					return cx >= cam[1] - 2 and cx <= cam[3] + 2 and cz >= cam[2] - 2 and cz <= cam[4] + 2
				end
				for _, msg in pn.outbox.Events do
					for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
						if e.kind == EK.FIRE then
							counts.FIRE += 1
							t.expect(pn.tactical[e.unitId :: number] == true, `FIRE from unit {e.unitId}, not tactical for player {pid}`)
						elseif e.kind == EK.SPAWN_PROJ then
							counts.SPAWN_PROJ += 1
							local id = e.projId :: number
							known[pid][id] = true
							t.expect(c.projSlot[id] ~= nil, "SPAWN_PROJ for a live projectile")
							local x, z = c.px[id], c.pz[id]
							t.expect(Sensors.inSight(sim, ally, x, z) and inCamera(x, z), `projectile {id} sent to player {pid} outside its sight or camera`)
							local target = e.targetId :: number
							t.expect(target == 0 or knows(sim, ally, target), "a homing target only when the ally team knows it")
						elseif e.kind == EK.IMPACT then
							counts.IMPACT += 1
							local id = e.projId :: number
							local gx, gz = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
							t.expect(known[pid][id] or (Sensors.inSight(sim, ally, gx, gz) and inCamera(gx, gz)), `IMPACT of projectile {id} the player may not see`)
							known[pid][id] = nil
						elseif e.kind == EK.DECOYED or e.kind == EK.LOST_LOCK then
							counts[if e.kind == EK.DECOYED then "DECOYED" else "LOST_LOCK"] += 1
							t.expect(known[pid][e.projId :: number] == true, "DECOYED / LOST_LOCK only for projectiles the client has")
						end
					end
				end
				local view = views[pid]
				Client.receive(view, pn.outbox)
				-- non-homing projectiles the client has: same flight as the server's
				for id, p in view.projectiles do
					local weapon = sim.defs.weaponByIndex[p.weaponIndex]
					if c.projSlot[id] ~= nil and c.pWeapon[id] == p.weaponIndex and weapon.turnRate == nil then
						drift = math.max(drift, math.abs(p.x - c.px[id]), math.abs(p.y - c.py[id]), math.abs(p.z - c.pz[id]))
					end
				end
			end
		end
		t.expect(counts.SPAWN_PROJ > 0 and counts.IMPACT > 0, `projectile events were sent ({counts.SPAWN_PROJ} spawns, {counts.IMPACT} impacts)`)
		t.expect(drift < 0.5, `client projectiles follow the server's (worst drift {drift} studs)`)
		print(string.format("    events: %d SPAWN_PROJ, %d IMPACT, %d DECOYED, %d LOST_LOCK; worst projectile drift %.3f studs", counts.SPAWN_PROJ, counts.IMPACT, counts.DECOYED, counts.LOST_LOCK, drift))
	end)

	-- A Hellmouth mortar outside Order's sight shells an Order generator it
	-- sees on its own radar. Order gets the shells only once they fly into
	-- its sight, never at the muzzle, and never learns the mortar's ID.
	t.test("a hidden shooter's shells appear only once they fly into sight", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local c = sim.combat
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_generator", 1, -150, 0)
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -150, 40)
		w.fireState[lancer] = World.FireState.HOLD_FIRE
		local mortar = Spawn.unit(sim, "chs_hellmouth", 2, 200, 0, -math.pi / 2)
		Spawn.unit(sim, "chs_watcher", 2, 250, 100)
		camera(sim, 1, 0, 0, 95, 95)
		camera(sim, 2, 0, 0, 95, 95)
		local view = Client.new(g)
		local shells, impacts, nearest = 0, 0, math.huge
		for _ = 1, 600 do
			Sim.step(sim)
			local pn = sim.net.players[1]
			for _, msg in pn.outbox.Events do
				for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
					if e.kind == Schema.EventKind.SPAWN_PROJ and e.weaponIndex == sim.defs.weapons.chs_mortar.index then
						shells += 1
						local id = e.projId :: number
						t.expect(Sensors.inSight(sim, 1, c.px[id], c.pz[id]), "the shell is in Order's sight when it is sent")
						nearest = math.min(nearest, math.sqrt((c.px[id] - w.posX[mortar]) ^ 2 + (c.pz[id] - w.posZ[mortar]) ^ 2))
					elseif e.kind == Schema.EventKind.IMPACT then
						impacts += 1
					end
				end
			end
			Client.receive(view, pn.outbox)
			t.expect(Sensors.level(sim, 1, mortar) == L.HIDDEN, "the mortar stays hidden from Order")
		end
		t.expect(shells >= 3, `Order saw the shells coming ({shells})`)
		t.expect(impacts >= 1, `and their impacts ({impacts})`)
		t.expect(nearest > 150, `never at the muzzle: closest {nearest} studs from the mortar`)
		t.expect(view.received[mortar] == nil, "Order's client never learned the mortar's ID")
		t.expect(w.slot[gen] == nil or w.health[gen] < sim.defs.units.ord_generator.health, "the generator was shelled")
		print(string.format("    hidden mortar: %d shells shown, first seen %.0f studs from the muzzle", shells, nearest))
	end)

	-- Hitscan flak (FIRE): a Dominion shoots at a Wasp hovering over it.
	-- Chaos's camera covers the fight, Order's is elsewhere, so only Chaos
	-- (which sees the ship) gets the shots, with their end points.
	t.test("FIRE goes to players that have the shooter in their tactical tier", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "sea:128" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local ship = Spawn.unit(sim, "ord_dominion", 1, 100, 0)
		local wasp = Spawn.unit(sim, "chs_wasp", 2, 160, 0)
		World.setHealth(w, wasp, 1e6)
		w.fireState[wasp] = World.FireState.HOLD_FIRE
		camera(sim, 1, 0, 0, 20, 20) -- far from the fight
		camera(sim, 2, 0, 0, 127, 127)
		local view = Client.new(g)
		local fires = { 0, 0 }
		local hits, worst = 0, 0
		for _ = 1, 300 do
			Sim.step(sim)
			for pid = 1, 2 do
				for _, msg in sim.net.players[pid].outbox.Events do
					for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
						if e.kind == Schema.EventKind.FIRE then
							fires[pid] += 1
							t.equal(e.unitId, ship, "the shooter is the ship")
							if e.hit then
								hits += 1
								local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
								worst = math.max(worst, math.sqrt((x - w.posX[wasp]) ^ 2 + (z - w.posZ[wasp]) ^ 2))
							end
						end
					end
				end
			end
			Client.receive(view, sim.net.players[2].outbox)
		end
		t.equal(fires[1], 0, "Order's camera is elsewhere: no FIRE")
		t.expect(fires[2] >= 5, `Chaos sees the flak ({fires[2]} shots)`)
		t.expect(hits >= 1 and worst < 1, `hits end at the target ({hits} hits, worst {worst} studs off)`)
		local tracers = 0
		for _, fx in view.effects do
			if fx.kind == "fire" then
				tracers += 1
			end
		end
		t.equal(tracers, fires[2], "the client draws a tracer per shot")
	end)

	-- Homing corrections (D102). A Crusader torpedoes a Lamprey: Order's
	-- client draws torpedoes from SPAWN_PROJ and the corrections. Visible
	-- drift = drawn position vs the server's, while in the player's view.
	type DriftRun = { worst: number, corrections: number, unguided: number, outOfView: number, bytes: number, ticks: number }
	local function homingRun(every: number, dropEveryOther: boolean): DriftRun
		local saved = NetOut.HOMING_SYNC_EVERY
		NetOut.HOMING_SYNC_EVERY = every
		local scene = Scenes.matchup("ord_crusader", "chs_lamprey", "close", 1)
		local sim = scene.sim
		local g = (sim.map :: any).grid
		local c = sim.combat
		NetOut.setCamera(sim, 1, 0, 0, math.min(g.cellsX - 1, 255), math.min(g.cellsZ - 1, 255))
		local view = Client.new(g)
		local r: DriftRun = { worst = 0, corrections = 0, unguided = 0, outOfView = 0, bytes = 0, ticks = 0 }
		local lastSync: { [number]: number } = {}
		local n = 0
		for _ = 1, 900 do
			scene.drive(sim)
			Sim.step(sim)
			local pn = sim.net.players[1]
			for _, msg in pn.outbox.Projectiles do
				for _, rec in (Packer.readAll(msg, Schema.decodeProjSync, Schema.decodeTickHeader)) do
					local p = rec.projId
					r.corrections += 1
					t.expect(pn.projKnown[p] == true, "corrections only for projectiles the client has")
					if sim.defs.weaponByIndex[c.pWeapon[p]].turnRate == nil then
						r.unguided += 1
					end
					local cx, cz = g:cellAt(c.px[p], c.pz[p])
					if not (g:inBounds(cx, cz) and Sensors.inSight(sim, 1, c.px[p], c.pz[p])) then
						r.outOfView += 1
					end
					lastSync[p] = sim.tick
				end
			end
			local outbox = pn.outbox
			if dropEveryOther then
				n += 1
				if n % 2 == 0 then
					outbox = table.clone(outbox)
					outbox.Projectiles = {} -- lost: the channel is unreliable
				end
			end
			Client.receive(view, outbox)
			for id, p in view.projectiles do
				if c.projSlot[id] ~= nil and c.pWeapon[id] == p.weaponIndex and sim.defs.weaponByIndex[p.weaponIndex].turnRate then
					local cx, cz = g:cellAt(c.px[id], c.pz[id])
					if g:inBounds(cx, cz) and Sensors.inSight(sim, 1, c.px[id], c.pz[id]) then
						local x, y, z = Client.drawn(p)
						r.worst = math.max(r.worst, math.sqrt((x - c.px[id]) ^ 2 + (y - c.py[id]) ^ 2 + (z - c.pz[id]) ^ 2))
					end
				end
			end
		end
		r.bytes = sim.net.players[1].bytes.Projectiles
		r.ticks = sim.tick
		NetOut.HOMING_SYNC_EVERY = saved
		return r
	end

	t.test("homing corrections: only known homing projectiles in view, and the client's drift stays small", function()
		local off = homingRun(0, false)
		local on = homingRun(5, false)
		local lossy = homingRun(5, true)
		t.equal(off.corrections, 0, "no corrections when turned off")
		t.expect(on.corrections > 0, `corrections were sent ({on.corrections})`)
		t.equal(on.unguided, 0, "never for unguided projectiles")
		t.equal(on.outOfView, 0, "never for projectiles out of the player's view")
		-- since attack-move holds to engage (S-4) the torpedo flights are shorter: the
		-- drift without corrections is smaller than it was (618 studs in D102)
		t.expect(off.worst > 40, `without corrections torpedoes drift visibly ({off.worst} studs)`)
		t.expect(off.worst > 3 * math.max(on.worst, 1), `corrections cut the drift at least 3× ({off.worst} → {on.worst} studs)`)
		t.expect(on.worst < 40, `with corrections the visible drift stays small ({on.worst} studs)`)
		t.expect(lossy.worst < 80, `half the corrections lost: still bounded ({lossy.worst} studs)`)
		print(string.format("    visible drift: %.1f studs without, %.1f with, %.1f with half lost; %d corrections, %.2f KB/s",
			off.worst, on.worst, lossy.worst, on.corrections, on.bytes / (on.ticks / 15) / 1000))
	end)

	-- Join / reconnect (S-2): two identical runs of the battle (NetOut never
	-- changes the sim). In the first, player 1's client is connected from
	-- the start; in the second, a client joins at tick 300. Five ticks
	-- later the late client's view equals the first one's.
	local function sameView(a: Client.View, b: Client.View): (boolean, string)
		for id, u in a.units do
			local v = b.units[id]
			if v == nil then
				return false, `unit {id} missing`
			elseif v.tier ~= u.tier or v.team ~= u.team or v.defIndex ~= u.defIndex or v.icon ~= u.icon or v.flags ~= u.flags then
				return false, `unit {id} differs ({u.tier} / {v.tier})`
			elseif math.abs(v.x - u.x) > 1e-9 or math.abs(v.z - u.z) > 1e-9 or v.health ~= u.health or v.state ~= u.state then
				return false, `unit {id} position or state differs`
			end
		end
		for id in b.units do
			if a.units[id] == nil then
				return false, `unit {id} extra`
			end
		end
		for id, p in a.projectiles do
			local q = b.projectiles[id]
			local weapon = a.defs.weaponByIndex[p.weaponIndex]
			if weapon.turnRate == nil and (q == nil or math.abs(q.x - p.x) > 0.5 or math.abs(q.z - p.z) > 0.5) then
				return false, `projectile {id} differs`
			end
		end
		return true, ""
	end

	t.test("a client joining late rebuilds the same view as one connected from the start", function()
		local function run(joinAt: number?): (Client.View, Sim.Sim)
			local sim, mine, theirs = battle(13)
			local g = (sim.map :: any).grid
			local rng = Prng.new(97)
			local view = Client.new(g)
			for _ = 1, 320 do
				if sim.tick % 120 == 0 then
					moveTo(sim, 1, mine, rng:nextNumber(-200, 100), rng:nextNumber(-150, 150))
					moveTo(sim, 2, theirs, rng:nextNumber(-100, 200), rng:nextNumber(-150, 150))
				end
				if joinAt and sim.tick == joinAt then
					NetOut.join(sim, 1) -- reconnect: keeps the camera
					view = Client.new(g) -- a brand-new client
				end
				Sim.step(sim)
				if joinAt == nil or sim.tick > joinAt then
					Client.receive(view, sim.net.players[1].outbox)
				end
			end
			return view, sim
		end
		local always, simA = run(nil)
		local late, simB = run(300)
		t.equal(Sim.hash(simA), Sim.hash(simB), "joining never changes the simulation")
		t.expect(late.welcome ~= nil and late.welcome.player == 1 and late.welcome.mapId == simB.mapId, "WELCOME names the player and the map")
		t.equal(late.welcome and late.welcome.tick, 300, "and the full tick")
		local ok, why = sameView(always, late)
		t.expect(ok, `same view after the join: {why}`)
		local tactical = 0
		for _, u in late.units do
			if u.tier == "tactical" then
				tactical += 1
			end
		end
		t.expect(tactical > 0, `tactical units were re-entered ({tactical})`)
		t.expect(late.economy ~= nil, "the economy came with the join")
		t.deepEqual(late.economy, always.economy, "and equals the connected client's")
	end)

	t.test("HELLO: matching versions are accepted, stale ones get REJECT with the reason", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local function hello(protocol: number, defsHash: number): buffer
			local w = Packer.Writer.new()
			Schema.encodeSnapshot(w, { kind = Schema.SnapshotKind.HELLO, protocol = protocol, defsHash = defsHash })
			return w:finish()
		end
		t.equal(NetOut.hello(sim, hello(Schema.PROTOCOL_VERSION, sim.defs.hash)), nil, "accepted")
		local function reason(msg: buffer?): number?
			return msg and (Packer.readAll(msg, Schema.decodeSnapshot))[1].reason
		end
		t.equal(reason(NetOut.hello(sim, hello(Schema.PROTOCOL_VERSION - 1, sim.defs.hash))), Schema.RejectReason.PROTOCOL, "old protocol")
		t.equal(reason(NetOut.hello(sim, hello(Schema.PROTOCOL_VERSION, (sim.defs.hash + 1) % 4294967296))), Schema.RejectReason.DEFS, "other defs")
		t.expect(not pcall(NetOut.hello, sim, buffer.fromstring("\9")), "garbage errors (callers pcall it)")
	end)

	t.test("the Eco channel carries the team's account when it changes", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		Spawn.unit(sim, "ord_generator", 1, 0, 0)
		local view = Client.new((sim.map :: any).grid)
		local sent = 0
		for _ = 1, 60 do
			Sim.step(sim)
			sent += #sim.net.players[1].outbox.Eco
			Client.receive(view, sim.net.players[1].outbox)
		end
		t.expect(sent >= 1 and sent <= 12, `sent on economy ticks when changed ({sent} of 12)`)
		local acc = sim.eco.accounts[1]
		local e = view.economy :: Schema.Eco
		t.equal(e.supply.stored, math.floor(acc.supply.stored), "supply stored")
		t.equal(e.power.income, math.floor(acc.power.income * 10 + 0.5), "power income in tenths per second")
		t.equal(e.power.ratio, math.clamp(math.floor(acc.power.ratio * 255), 0, 255), "power ratio")
	end)

	t.test("tactical tier hysteresis: enter at +2 cells, leave beyond +5", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local tank = Spawn.unit(sim, "ord_lancer", 1, g:cellCenter(10, 32))
		camera(sim, 1, 20, 0, 40, 63)
		local function moveCell(cx: number)
			local x, z = g:cellCenter(cx, 32)
			World.setPosition(sim.world, tank, x, z)
			Sim.step(sim)
		end
		Sim.step(sim)
		t.expect(not sim.net.players[1].tactical[tank], "10 cells outside: strategic")
		moveCell(17)
		t.expect(not sim.net.players[1].tactical[tank], "3 cells outside: still strategic")
		moveCell(18)
		t.expect(sim.net.players[1].tactical[tank], "2 cells outside: enters")
		moveCell(15)
		t.expect(sim.net.players[1].tactical[tank], "5 cells outside: stays")
		moveCell(14)
		t.expect(not sim.net.players[1].tactical[tank], "6 cells outside: leaves")
	end)

	t.test("many movers are split into messages of at most 900 bytes", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:128" })
		local ids = {}
		for i = 0, 399 do
			table.insert(ids, Spawn.unit(sim, "ord_lancer", 1, -400 + (i % 20) * 30, -300 + (i // 20) * 30))
		end
		camera(sim, 1, 0, 0, 127, 127)
		Sim.step(sim)
		for _, id in ids do
			World.setHeading(sim.world, id, 1) -- every unit "moved" this tick
		end
		Sim.step(sim)
		local msgs = sim.net.players[1].outbox.Tactical
		local records = 0
		for _, m in msgs do
			t.expect(buffer.len(m) <= 900, `{buffer.len(m)} bytes`)
			records += #(Packer.readAll(m, Schema.decodeTactical, Schema.decodeTickHeader))
		end
		t.equal(records, 400, "every mover is sent exactly once")
		t.expect(#msgs >= 4, `400 × 8 bytes needs several messages, got {#msgs}`)
	end)
end
