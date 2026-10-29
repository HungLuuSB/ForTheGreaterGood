--!strict
local Defs = require("@shared/Defs/Defs")
local Icons = require("@shared/Net/Icons")
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
local Combat = require("../Sim/Combat/Combat")
local Skirmish = require("../Sim/AI/Skirmish")
local AmmoDefs = require("./Support/AmmoDefs") -- the aircraft with ammo, as before S-194
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
	Spawn.unit(sim, "chs_solar", 2, 200, -200)
	Spawn.unit(sim, "ord_solar", 1, -200, 200)
	camera(sim, 1, 0, 20, 50, 70) -- west half
	camera(sim, 2, 45, 20, 95, 70) -- east half
	return sim, mine, theirs
end

-- What the server says `team` may know about `id` right now.
local function knows(sim: Sim.Sim, team: number, id: number): boolean
	return Sensors.level(sim, team, id) ~= L.HIDDEN
end

return function(t: RunAll.Context)
	-- S-10: clients number icons with Shared/Net/Icons; the server must too.
	t.test("strategic icons use the shared numbering: one per unit type, the def index (S-58)", function()
		local defs = Defs.load()
		local names = Icons.names(defs)
		for i = 2, #names do
			t.expect(names[i - 1] < names[i], `family names sorted and distinct ({names[i - 1]}, {names[i]})`)
		end
		local byDef = Icons.byDef(defs)
		local seen = {}
		for index, def in defs.unitByIndex do
			local n = byDef[index]
			t.expect(n >= 1 and n <= Icons.MAX, `{def.id}: icon {n} in 1..{Icons.MAX}`)
			t.equal(n, def.index, `{def.id}: its icon is its def index`)
			t.expect(not seen[n], `{def.id}: no other unit type has icon {n}`)
			seen[n] = true
		end
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		t.deepEqual(sim.net.iconIndex, byDef, "the server sends exactly these numbers")
	end)

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
					t.expect(math.abs(u.x - w.posX[id]) <= 1 / 8 and math.abs(u.z - w.posZ[id]) <= 1 / 8, `tactical unit {id} position`) -- quarter studs (S-189)
					local def = sim.defs.unitByIndex[w.defIndex[id]]
					t.equal(u.health, math.clamp(math.ceil(w.health[id] / def.health * 255), 0, 255), `tactical unit {id} health`)
				elseif w.slot[id] then
					local kx, kz = Sensors.knownPosition(sim, team, id)
					-- the 8-stud square of its known position (S-189)
					t.expect(math.abs(u.x - (kx :: number)) <= 4.125 and math.abs(u.z - (kz :: number)) <= 4.125, `strategic unit {id} position`)
				end
			end
		end
		print(string.format("    largest message: %d bytes", largest))
	end)

	-- Combat events (D99): every FIRE, SPAWN_PROJ, IMPACT and DECOYED a player
	-- gets is something its ally team may know, and the client's own
	-- projectile stepping follows the server's.
	t.test("combat events: projectiles in the camera area, shooters only when known, and the client tracks projectiles", function()
		local sim, mine, theirs = battle(12)
		local g = (sim.map :: any).grid
		local c = sim.combat
		local rng = Prng.new(98)
		local views = { Client.new(g), Client.new(g) }
		local counts = { FIRE = 0, SHOT = 0, SPAWN_PROJ = 0, IMPACT = 0, DECOYED = 0, LOST_LOCK = 0 }
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
						elseif e.kind == EK.SHOT then
							counts.SHOT += 1 -- no shooter on the wire (S-43)
							local ex, ez = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
							local sx, sz = g:decode(e.fromCell :: number, e.fromOffX :: number, e.fromOffZ :: number)
							t.expect(inCamera(ex, ez) or inCamera(sx, sz), "a SHOT touches the camera area")
						elseif e.kind == EK.SPAWN_PROJ then
							counts.SPAWN_PROJ += 1
							local id = e.projId :: number
							known[pid][id] = true
							t.expect(c.projSlot[id] ~= nil, "SPAWN_PROJ for a live projectile")
							local x, z = c.px[id], c.pz[id]
							t.expect(inCamera(x, z), `projectile {id} sent to player {pid} outside its camera area`) -- seen or not (S-43)
							local target = e.targetId :: number
							t.expect(target == 0 or knows(sim, ally, target), "a homing target only when the ally team knows it")
						elseif e.kind == EK.IMPACT then
							counts.IMPACT += 1
							local id = e.projId :: number
							local gx, gz = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
							t.expect(known[pid][id] or inCamera(gx, gz), `IMPACT of projectile {id} outside the camera area`)
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

	-- A Hellmouth mortar outside Order's sight shells an Order generator a
	-- Chaos Watcher sees from beyond the generator's own sight. Order's
	-- camera covers the map: it gets the shells from the muzzle (S-43, client
	-- request 21: projectiles regardless of sight; before, only once they
	-- flew into its sight), and never learns the mortar's ID.
	-- (S-179 halved the mortar's range to 190: it stands at 0.9 × its range
	-- from the generator. Shells at a radar blip land a radar error (50
	-- studs, S-131) off it, so the Watcher's eyes, not its radar, give the
	-- aim, and Order's Lancer, whose 200-stud sight now outreaches the
	-- mortar, stays back out of sight of both, beyond the mortar's reach.)
	t.test("a hidden shooter's shells show from the muzzle, but never the shooter", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local c = sim.combat
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_solar", 1, -150, 0)
		World.setHealth(w, gen, 1e6) -- outlasts the shelling: shells keep coming
		local lancer = Spawn.unit(sim, "ord_lancer", 1, -360, 0)
		w.fireState[lancer] = World.FireState.HOLD_FIRE
		local mortar = Spawn.unit(sim, "chs_hellmouth", 2, -150 + math.floor(sim.defs.weapons.chs_mortar.range * 0.9), 0, -math.pi / 2)
		local watcher = Spawn.unit(sim, "chs_watcher", 2, -80, 70) -- 99 studs from the generator: inside its 110 sight, outside the generator's 60
		World.setFireState(w, watcher, World.FireState.HOLD_FIRE)
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
		t.expect(nearest < 40, `from the muzzle: first seen {nearest} studs from the mortar`)
		t.expect(view.received[mortar] == nil, "Order's client never learned the mortar's ID")
		t.expect(w.health[gen] < 1e6, "the generator was shelled")
		t.expect(Sensors.level(sim, 1, watcher) == L.HIDDEN, "and the Watcher stayed hidden too")
		print(string.format("    hidden mortar: %d shells shown, first seen %.0f studs from the muzzle", shells, nearest))
	end)

	-- S-16: the owner's client knows each weapon's target exactly, from the
	-- tick Targeting picks it (before the turret has turned); nobody else
	-- gets it.
	t.test("own units' weapon targets reach their owner only, exactly", function()
		local sim = Sim.new({ seed = 6, players = PLAYERS, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local mine = { Spawn.unit(sim, "ord_lancer", 1, -60, 0, 0), Spawn.unit(sim, "ord_lancer", 1, -60, 30, 0) } -- facing north: the turrets turn 90°
		-- the Ravagers at 0.8 × the Lancer's range (95 since S-179), holding
		-- fire: inside their own range now, and the Lancers must live
		local x = -60 + math.floor(sim.defs.weapons[sim.defs.units.ord_lancer.weapons[1].def].range * 0.8)
		local theirs = { Spawn.unit(sim, "chs_ravager", 2, x, 0, -math.pi / 2), Spawn.unit(sim, "chs_ravager", 2, x, 40, -math.pi / 2) }
		camera(sim, 1, 0, 0, 63, 63)
		camera(sim, 2, 0, 0, 63, 63)
		for _, id in theirs do
			World.setHealth(w, id, 1e6)
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		for _, id in { mine[1], mine[2], theirs[1], theirs[2] } do
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION) -- a static scene (move states, S-34)
		end
		local views = { Client.new(g), Client.new(g) }
		local exact, targeted, beforeTurned, leaked = 0, 0, 0, 0
		for _ = 1, 240 do
			Sim.step(sim)
			for pid = 1, 2 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
			for _, id in mine do
				if w.slot[id] then
					local want = w.wTarget[World.slotKey(id, 1)]
					local u = views[1].units[id]
					local got = if u and u.targets then u.targets[1] else 0
					if got == want then
						exact += 1
					end
					if want ~= 0 then
						targeted += 1
						local yaw = math.abs(w.wYaw[World.slotKey(id, 1)])
						if got == want and yaw < 0.2 and math.abs(math.atan2(w.posX[want] - w.posX[id], w.posZ[want] - w.posZ[id]) - w.heading[id]) > 0.3 then
							beforeTurned += 1
						end
					end
				end
			end
			for _, u in views[2].units do
				if u.targets then
					leaked += 1
				end
			end
		end
		t.equal(exact, 2 * 240, "the owner's view has every weapon target every tick")
		t.expect(targeted > 100, `the tanks had targets ({targeted} unit-ticks)`)
		t.equal(leaked, 0, "the other player never gets targets")
		print(string.format("    targets: %d unit-ticks with a target, %d of them before the turret turned", targeted, beforeTurned))
	end)

	t.test("own units' factory queue, fire / move state, ammo and countermeasure charges reach their owner only, exactly (S-61, S-63)", function()
		local sim = Sim.new({ defs = AmmoDefs.load(), seed = 8, players = PLAYERS, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -60, 0, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 40, 60, 0)
		local jet = Spawn.unit(sim, "ord_falcon", 1, 40, -60, 0)
		Spawn.unit(sim, "chs_ravager", 2, 120, 0, 0) -- near enough to be seen
		camera(sim, 1, 0, 0, 63, 63)
		camera(sim, 2, 0, 0, 63, 63)
		local defs = sim.defs.units
		local cell = g:encode(0, 0)
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = defs.ord_lancer.index, cell = cell, offX = 0, offZ = 0, facing = 0 })
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = defs.ord_mason.index, cell = cell, offX = 0, offZ = 0, facing = 0 })
		local views = { Client.new(g), Client.new(g) }
		local exact, leaked, jetSeen = 0, 0, 0
		for tick = 1, 120 do
			if tick == 40 then
				w.fireState[tank] = World.FireState.HOLD_FIRE
				World.setMoveState(w, tank, World.MoveState.ROAM)
				sim.air.ammo[jet] = 1
				sim.ew.chaff[jet] = 1 -- one of the Falcon's 2 chaff charges spent
			end
			Sim.step(sim)
			for pid = 1, 2 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
			local p, tk, j = views[1].units[plant], views[1].units[tank], views[1].units[jet]
			local q = sim.build.queue[plant] or {}
			local okQueue = p and p.queue and #p.queue == #q and (#q == 0 or p.queue[1] == q[1])
			local okStates = tk and tk.fireState == w.fireState[tank] and tk.moveState == w.moveState[tank]
			-- (the jet flies in and out of the tactical tier: checked while in it)
			local okAmmo = j and j.ammo == sim.air.ammo[jet] and j.maxAmmo == defs.ord_falcon.ammo
				and j.chaff == sim.ew.chaff[jet] and j.flares == 0 -- the Falcon carries no flares
			local jetTactical = j ~= nil and j.tier == "tactical"
			if okQueue and okStates and (okAmmo or not jetTactical) then
				exact += 1
			end
			if jetTactical then
				jetSeen += 1
			end
			for id, u in views[2].units do
				if w.owner[id] == 1 and (u.queue or u.fireState or u.ammo or u.chaff) then
					leaked += 1
				end
			end
		end
		t.expect(exact >= 118, `the owner's view matches every tick after entering ({exact} of 120)`)
		t.expect(jetSeen > 60, `the jet's ammo was checked while it was in view ({jetSeen} ticks)`)
		t.equal(leaked, 0, "the other player never gets them")
		local p = views[1].units[plant]
		t.expect(p.queueProgress ~= nil and math.abs(p.queueProgress / 255 - (sim.build.progress[plant] or 0)) <= 1 / 16 + 1 / 255, "queue progress within a sixteenth")
	end)

	t.test("allied factories' item in production and its progress reach allies, not enemies (S-103, client request 45)", function()
		local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 }, { id = 3, team = 3, allyTeam = 1 } }
		local sim = Sim.new({ seed = 9, players = players, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local plant = Spawn.unit(sim, "ord_vehplant", 3, -60, 0, 0)
		Spawn.unit(sim, "ord_sovereign", 3, -150, -150)
		Spawn.unit(sim, "chs_ravager", 2, 60, 0, 0)
		for pid = 1, 3 do
			camera(sim, pid, 0, 0, 63, 63)
		end
		local defs = sim.defs.units
		local cell = g:encode(0, 0)
		submit(sim, 3, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = defs.ord_lancer.index, cell = cell, offX = 0, offZ = 0, facing = 0 })
		local views = { Client.new(g), Client.new(g), Client.new(g) }
		local exact, leaked, ownerGot = 0, 0, 0
		for _ = 1, 400 do
			Sim.step(sim)
			for pid = 1, 3 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
			local q = sim.build.queue[plant] or {}
			local u = views[1].units[plant]
			local head = q[1] or 0
			local p = if head ~= 0 then sim.build.progress[plant] or 0 else 0
			if u and u.producing == head and math.abs((u.producingProgress or 0) / 255 - p) <= 1 / 16 + 1 / 255 then
				exact += 1
			end
			if views[2].units[plant] and views[2].units[plant].producing then
				leaked += 1
			end
			if views[3].units[plant] and views[3].units[plant].producing then
				ownerGot += 1
			end
		end
		t.expect(exact >= 398, `the ally's view matches every tick ({exact} of 400)`)
		t.equal(views[1].units[plant].producing, (sim.build.queue[plant] or {})[1] or 0, "the last tick too")
		t.equal(leaked, 0, "the enemy never gets it")
		t.equal(ownerGot, 0, "the owner has its queue instead")
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
					-- the camera covers the map: in view = on the map (sight doesn't matter, S-43)
					local cx, cz = g:cellAt(c.px[p], c.pz[p])
					if not g:inBounds(cx, cz) then
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
		-- drift without corrections is smaller than it was (618 studs in D102);
		-- since S-131 the drawn sonar blips sit within 1.5 studs of the subs,
		-- and the uncorrected worst case fell from over 40 to 36.6 studs;
		-- S-179 halved the Lamprey's torpedo range (280 → 140), so its
		-- torpedoes fly half as far: 20.1 studs (the 3× cut below still holds)
		t.expect(off.worst > 15, `without corrections torpedoes drift visibly ({off.worst} studs)`)
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

	t.test("Eco records carry the team's radar accuracy, scaled by its Pinpointers (S-147)", function()
		local Pinpoint = require("@shared/Combat/Pinpoint")
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local view = Client.new(g)
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
			end
		end
		step(10)
		t.equal((view.economy :: any).radarError, 0, "no radar: 0")
		Spawn.unit(sim, "ord_oracle", 1, -200, -200)
		step(10)
		local err = sim.defs.units.ord_oracle.sensors.radarError :: number
		t.equal((view.economy :: any).radarError, math.floor(err * 10 + 0.5), `a radar: its radarError in tenths ({err} studs)`)
		t.equal((view.economy :: any).precision, 0)
		for i = 1, 3 do
			Spawn.unit(sim, "ord_witness", 1, -250 + i * 20, -250)
		end
		step(10)
		local p = Pinpoint.precision(3 * Pinpoint.weight(sim.defs.units.ord_witness))
		t.equal((view.economy :: any).radarError, math.floor(err * Pinpoint.errorScale(p) * 10 + 0.5), "scaled down by the Pinpointers")
		t.equal((view.economy :: any).precision, math.floor(p * 255 + 0.5))
		t.expect((view.economy :: any).radarError < err * 10, "smaller")
	end)

	t.test("IDLE: the owner hears when a builder or factory goes idle or busy, on camera or not (S-136, request 62)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local mason = Spawn.unit(sim, "ord_mason", 1, -300, -300)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 300, 300, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		local enemy = Spawn.unit(sim, "chs_scrapper", 2, 200, -200)
		camera(sim, 1, 0, 0, 2, 2) -- a corner: none of them on camera
		local view = Client.new(g)
		local otherView = Client.new(g)
		local function step(n: number)
			for _ = 1, n do
				sim.eco.accounts[1].supply.stored = 1000
				sim.eco.accounts[1].power.stored = 1000
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
				Client.receive(otherView, sim.net.players[2].outbox)
			end
		end
		step(10)
		t.equal(view.idle[mason], true, "an idle builder off camera is reported")
		t.equal(view.idle[plant], true, "a factory with an empty queue too")
		t.equal(view.idle[tank], nil, "not a unit that can't build")
		t.equal(otherView.idle[mason], nil, "owner only")
		t.equal(otherView.idle[enemy], true, "each player hears of its own")
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_lancer.index, cell = 0, offX = 0, offZ = 0, facing = 0 })
		local cell, ox, oz = g:encode(-200, -300)
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { mason }, defIndex = sim.defs.units.ord_solar.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
		step(10)
		t.equal(view.idle[mason], nil, "building: busy")
		t.equal(view.idle[plant], nil, "producing: busy")
		step(900 * 2)
		t.equal(view.idle[plant], true, "its queue done, idle again")
		t.equal(view.idle[mason], true, "the generator built, idle again")
		-- a client joining later hears of every idle one
		local late = Client.new(g)
		NetOut.join(sim, 1)
		step(1)
		Client.receive(late, sim.net.players[1].outbox)
		t.equal(late.idle[mason], true, "on join: the idle builder")
		t.equal(late.idle[plant], true, "and factory")
		local _ = w
	end)

	t.test("OWN_STATUS: the owner's units off camera send health, build and queue on change, capped per tick (S-158)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 300, 300, 0)
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0)
		local enemy = Spawn.unit(sim, "chs_scrapper", 2, 200, -200)
		camera(sim, 1, 0, 0, 2, 2) -- a corner: none of them on camera
		local view = Client.new(g)
		local otherView = Client.new(g)
		local function step(n: number)
			for _ = 1, n do
				sim.eco.accounts[1].supply.stored = 1000
				sim.eco.accounts[1].power.stored = 1000
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
				Client.receive(otherView, sim.net.players[2].outbox)
			end
		end
		step(2)
		t.equal(view.ownStatus[tank] and view.ownStatus[tank].health, 255, "an own unit off camera: full health")
		t.equal(view.ownStatus[plant] and view.ownStatus[plant].queueHead, 0, "an idle factory: no queue")
		t.equal(view.ownStatus[enemy], nil, "owner only")
		t.equal(otherView.ownStatus[tank], nil, "not to the other player")
		local counts = sim.net.players[1].eventCounts
		local before = counts[Schema.EventKind.OWN_STATUS] or 0
		step(5)
		t.equal(counts[Schema.EventKind.OWN_STATUS] or 0, before, "nothing changed: nothing sent")
		w.health[tank] *= 0.5
		step(1)
		t.equal(view.ownStatus[tank].health, math.ceil(0.5 * 255), "health change sent")
		local lancer = sim.defs.units.ord_lancer.index
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = lancer, cell = 0, offX = 0, offZ = 0, facing = 0 })
		submit(sim, 1, { cmdType = CT.BUILD, flags = Schema.CmdFlag.QUEUE, unitIds = { plant }, defIndex = lancer, cell = 0, offX = 0, offZ = 0, facing = 0 })
		step(60)
		local st = view.ownStatus[plant]
		t.equal(st.queueHead, lancer, "the queue's head")
		t.equal(st.queueCount, 2, "and its length")
		t.expect(st.queueProgress > 0, `and the head's progress ({st.queueProgress})`)
		-- on camera the unit's status rides ENTER / State; leaving, no repeat
		camera(sim, 1, 0, 0, 95, 95)
		step(2)
		before = counts[Schema.EventKind.OWN_STATUS] or 0
		camera(sim, 1, 0, 0, 2, 2)
		w.health[tank] = w.health[tank] -- unchanged
		step(1)
		t.expect((counts[Schema.EventKind.OWN_STATUS] or 0) - before <= 1, "leaving the tier doesn't resend what the client has (the factory's progress may step)")
		-- the cap: many changes at once spread over ticks
		local many = {}
		for i = 1, 60 do
			table.insert(many, Spawn.unit(sim, "ord_herald", 1, -300 + (i % 10) * 12, -300 + (i // 10) * 12))
		end
		step(1)
		before = counts[Schema.EventKind.OWN_STATUS] or 0
		for _, id in many do
			w.health[id] *= 0.5
		end
		step(1)
		t.equal((counts[Schema.EventKind.OWN_STATUS] or 0) - before, NetOut.OWN_STATUS_MAX, "capped per tick")
		step(2)
		for _, id in many do
			t.equal(view.ownStatus[id].health, math.ceil(0.5 * 255), "every one arrives on the next ticks")
		end
		-- a client joining later gets every own unit off camera
		local late = Client.new(g)
		NetOut.join(sim, 1)
		for _ = 1, 4 do
			Sim.step(sim)
			Client.receive(late, sim.net.players[1].outbox)
		end
		t.equal(late.ownStatus[tank] and late.ownStatus[tank].health, math.ceil(0.5 * 255), "on join")
		t.equal(late.ownStatus[many[60]] and late.ownStatus[many[60]].health, math.ceil(0.5 * 255), "all of them, over the cap's ticks")
	end)

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
		t.expect(late.sight ~= nil and buffer.tostring(late.sight :: buffer) == buffer.tostring(always.sight :: buffer), "the team's sight came with the join, equal (S-26)")
		t.deepEqual(late.wrecks, always.wrecks, "and the known wrecks")
	end)

	-- S-26 (client requests 9 and 10): the ally team's sight map and the
	-- wrecks it knows, so the client's fog and wrecks match the server's.
	t.test("the sight diff reads only marked rows (S-191) and still equals the team's sight: two AIs, the reveal cheat on and off", function()
		local sim = Sim.new({ seed = 8, players = PLAYERS, mapId = "map:coastline", scenario = "standard_start" })
		local brains = { Skirmish.new(sim, 1, "hard"), Skirmish.new(sim, 2, "hard") }
		local s = sim.sensors
		local mismatches, checks = 0, 0
		for tick = 1, 15 * 90 do
			if tick == 15 * 40 then
				Sensors.reveal(sim, 1, 1)
			elseif tick == 15 * 45 then
				Sensors.reveal(sim, 1, -1)
			end
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			if sim.tick % NetOut.SIGHT_EVERY == 0 then
				for _, ally in s.teams do
					local los, mine = s.maps[ally].los, (sim.net.sight[ally] :: any).cells
					for i = 0, s.width * s.depth - 1 do
						if (buffer.readu16(los, i * 2) > 0) ~= (buffer.readu8(mine, i) == 1) then
							mismatches += 1
						end
					end
				end
				checks += 1
			end
		end
		t.expect(checks > 600, `{checks} sensor ticks checked`)
		t.equal(mismatches, 0, "every sensor tick, every cell")
		local units = 0
		for _, id in sim.world.ids do
			if sim.world.owner[id] ~= 0 then
				units += 1
			end
		end
		t.expect(units > 15, `the AIs built and moved ({units} units)`)
	end)

	t.test("sight and wrecks: the client's fog equals the ally team's sight, wrecks come and go as the team sees them", function()
		local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 } }
		local sim = Sim.new({ seed = 5, players = players, mapId = "flat:96" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local c = sim.combat
		local scout = Spawn.unit(sim, "ord_lancer", 1, -300, 0, math.pi / 2)
		Spawn.unit(sim, "ord_lancer", 2, 300, 300, 0) -- the ally's: its sight is ours too
		Spawn.unit(sim, "chs_ravager", 3, 300, -300, 0)
		camera(sim, 1, 0, 0, 95, 95)
		local view = Client.new(g)
		local spectator = Client.new(g)
		local spec = NetOut.addSpectator(sim)
		local mismatches, checks = 0, 0
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
				Client.receive(spectator, sim.net.spectators[spec].outbox)
				if sim.tick % 2 == 0 then
					local los = sim.sensors.maps[1].los
					for i = 0, sim.sensors.width * sim.sensors.depth - 1 do
						local server = buffer.readu16(los, i * 2) > 0
						local client = view.sight ~= nil and buffer.readu8(view.sight :: buffer, i) == 1
						if server ~= client then
							mismatches += 1
						end
					end
					checks += 1
				end
			end
		end
		local function stepUntil(cond: () -> boolean, limit: number): boolean
			for _ = 1, limit do
				if cond() then
					return true
				end
				step(1)
			end
			return cond()
		end
		step(4)
		t.expect(Client.inSight(view, 300, 300), "the ally's unit's surroundings are in our sight")
		t.expect(Client.inSight(view, -300, 0), "and our own unit's")
		t.expect(not Client.inSight(view, 0, -300), "the middle of the south edge isn't")
		t.equal(spectator.sight, nil, "spectators get no sight (they see everything)")

		-- a wreck in fog: unknown to the team, known to spectators at once
		local ravager = sim.defs.units.chs_ravager
		local hidden = Combat.addWreck(c, 0, -300, ravager, math.pi / 2)
		local near = Combat.addWreck(c, -300, 20, ravager, 1.0)
		step(2)
		t.equal(view.wrecks[hidden], nil, "a wreck in fog isn't sent")
		t.expect(spectator.wrecks[hidden] ~= nil, "spectators get every wreck")
		local nw = view.wrecks[near]
		t.expect(nw ~= nil, "a wreck in sight is")
		if nw then
			t.equal(nw.defIndex, ravager.index, "with its def")
			t.expect(math.abs(nw.x - -300) < 0.1 and math.abs(nw.z - 20) < 0.1, "position")
			t.equal(nw.heading, NetOut.headingU8(1.0), "and heading")
		end

		-- scouting the hidden one, then it disappears while out of sight
		moveTo(sim, 1, { scout }, 0, -270)
		t.expect(stepUntil(function()
			return view.wrecks[hidden] ~= nil
		end, 400), "the wreck appears once the scout sees its spot")
		moveTo(sim, 1, { scout }, -300, 0)
		t.expect(stepUntil(function()
			return not Client.inSight(view, 0, -300)
		end, 400), "the scout left")
		Combat.removeWreck(c, hidden)
		step(10)
		t.expect(view.wrecks[hidden] ~= nil, "a wreck reclaimed out of sight stays on the client's map (the team can't know)")
		t.equal(spectator.wrecks[hidden], nil, "spectators see it go at once")
		moveTo(sim, 1, { scout }, 0, -270)
		t.expect(stepUntil(function()
			return view.wrecks[hidden] == nil
		end, 400), "WRECK_GONE once the team sees the empty spot")
		moveTo(sim, 1, { scout }, -300, 0)
		step(200)

		-- a wreck removed in sight goes at once (by the next sensor tick)
		Combat.removeWreck(c, near)
		step(2)
		t.equal(view.wrecks[near], nil, "a wreck removed in sight is gone")

		-- a real kill in sight: the DEATH's wreck arrives in the same tick
		local victim = Spawn.unit(sim, "chs_ravager", 3, w.posX[scout] + 60, w.posZ[scout], 0)
		World.setHealth(w, victim, 1)
		local sameTick = nil
		for _ = 1, 300 do
			step(1)
			for _, msg in sim.net.players[1].outbox.Events do
				for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
					if e.kind == Schema.EventKind.DEATH and e.unitId == victim and (e.wreckId :: number) ~= 0 then
						sameTick = view.wrecks[e.wreckId :: number] ~= nil
					end
				end
			end
			if sameTick ~= nil then
				break
			end
		end
		t.equal(sameTick, true, "DEATH and its WRECK in the same tick")
		t.equal(mismatches, 0, `sensor cells where the client's sight differs from the server's ({checks} sensor ticks)`)
	end)

	-- S-43 (client request 21): a hitscan shot from a shooter the player
	-- doesn't have arrives as SHOT, with both ends and no shooter ID
	t.test("a hidden shooter's gun shot: SHOT with both ends to others, FIRE to its owner", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		local w, c = sim.world, sim.combat
		local g = (sim.map :: any).grid
		local victim = Spawn.unit(sim, "ord_lancer", 1, -100, 0, 0)
		local gunner = Spawn.unit(sim, "chs_jackal", 2, 200, 150, 0) -- far outside Order's sight
		for _, id in { victim, gunner } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
			World.setMoveState(w, id, World.MoveState.HOLD_POSITION)
		end
		camera(sim, 1, 0, 0, 63, 63)
		camera(sim, 2, 0, 0, 63, 63)
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(Sensors.level(sim, 1, gunner), L.HIDDEN, "Order doesn't see the gunner")
		-- the gunner's shot this tick, as Weapons records it
		local weaponIndex = c.profiles[sim.world.defIndex[gunner]].weapons[1].index
		Combat.addEvent(c, { kind = "FIRE", tick = sim.tick, unit = gunner, other = victim, slot = 1, weaponIndex = weaponIndex, hit = true, x = -100, y = 13, z = 0, sx = 200, sy = 14, sz = 150 })
		NetOut.step(sim)
		local function events(pid: number): { Schema.Event }
			local all = {}
			for _, msg in sim.net.players[pid].outbox.Events do
				for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
					table.insert(all, e)
				end
			end
			return all
		end
		local shot, fire, mentions = nil, 0, 0
		for _, e in events(1) do
			if e.kind == Schema.EventKind.SHOT then
				shot = e
			elseif e.kind == Schema.EventKind.FIRE then
				fire += 1
			end
			if e.unitId == gunner then
				mentions += 1
			end
		end
		t.expect(shot ~= nil, "Order gets a SHOT")
		t.equal(fire, 0, "no FIRE (it would name the shooter)")
		t.equal(mentions, 0, "nothing names the gunner")
		if shot then
			local ex, ez = g:decode(shot.cell :: number, shot.offX :: number, shot.offZ :: number)
			local sx, sz = g:decode(shot.fromCell :: number, shot.fromOffX :: number, shot.fromOffZ :: number)
			t.expect(math.abs(ex + 100) < 0.1 and math.abs(ez) < 0.1, "with the end point")
			t.expect(math.abs(sx - 200) < 0.1 and math.abs(sz - 150) < 0.1, "and the start point")
			t.equal(shot.hit, true)
			t.equal(shot.weaponIndex, weaponIndex, "and the weapon (protocol 28, S-118)")
		end
		local owner = 0
		for _, e in events(2) do
			if e.kind == Schema.EventKind.FIRE and e.unitId == gunner then
				owner += 1
			end
		end
		t.equal(owner, 1, "the gunner's owner gets the usual FIRE")
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
		Spawn.unit(sim, "ord_solar", 1, 0, 0)
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

	t.test("an armed unit entering the view comes with its turrets' aim (S-119, client request 53)", function()
		local sim = Sim.new({ seed = 12, players = PLAYERS, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local tank = Spawn.unit(sim, "ord_lancer", 1, -150, -150, 0)
		-- in the Lancer's range (95 since S-179), at 0.8 × it
		local still = Spawn.unit(sim, "chs_ravager", 2, -150, -150 + math.floor(sim.defs.weapons[sim.defs.units.ord_lancer.weapons[1].def].range * 0.8), 0)
		World.setFireState(w, still, World.FireState.HOLD_FIRE)
		World.setMoveState(w, still, World.MoveState.HOLD_POSITION)
		World.setHealth(w, still, 1e6)
		World.setMoveState(w, tank, World.MoveState.HOLD_POSITION)
		camera(sim, 2, 40, 40, 63, 63) -- player 2 looks elsewhere
		for _ = 1, 60 do
			Sim.step(sim)
		end
		local key = World.slotKey(tank, 1)
		t.equal(w.wTarget[key], still, "the Lancer is on the Ravager")
		local yaw = w.wYaw[key]
		local view = Client.new(g)
		camera(sim, 2, 0, 0, 40, 40) -- now over both
		for _ = 1, 3 do
			Sim.step(sim)
			Client.receive(view, sim.net.players[2].outbox)
		end
		t.equal(w.wYaw[key], yaw, "the turret didn't move")
		local u = view.units[tank]
		t.expect(u ~= nil and u.aim ~= nil and u.aim[1] ~= nil, "the aim came with the unit")
	end)

	t.test("a dome in the camera area goes to the player whatever the team sees; DOME_GONE when its generator dies (S-122, client request 55)", function()
		local sim = Sim.new({ seed = 13, players = PLAYERS, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local w = sim.world
		local gen = Spawn.unit(sim, "chs_carapace", 2, 150, 150)
		sim.combat.shieldCharge[gen] = sim.defs.units.chs_carapace.shield.capacity
		Spawn.unit(sim, "ord_lancer", 1, -200, -200, 0) -- Order sees nothing near the generator
		camera(sim, 1, 0, 0, 63, 63)
		local function received(pid: number): { Schema.Event }
			local out = {}
			for _, msg in sim.net.players[pid].outbox.Events do
				for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
					table.insert(out, e)
				end
			end
			return out
		end
		local dome, entered, gone = nil, false, false
		for _ = 1, 6 do
			Sim.step(sim)
			for _, e in received(1) do
				if e.kind == Schema.EventKind.DOME and e.unitId == gen then
					dome = e
				elseif e.kind == Schema.EventKind.ENTER and e.unitId == gen then
					entered = true
				end
			end
		end
		t.expect(dome ~= nil, "Order gets the Carapace's dome")
		t.equal(entered, false, "but not the generator")
		if dome then
			local x, z = g:decode(dome.cell :: number, dome.offX :: number, dome.offZ :: number)
			t.expect(math.abs(x - 150) < 8 and math.abs(z - 150) < 8, "at the dome's centre")
			t.equal(dome.radius, sim.defs.units.chs_carapace.shield.radius)
		end
		Combat.queueDamage(sim.combat, gen, 1e6, 0)
		for _ = 1, 3 do
			Sim.step(sim)
			for _, e in received(1) do
				if e.kind == Schema.EventKind.DOME_GONE and e.unitId == gen then
					gone = true
				end
			end
		end
		t.equal(gone, true, "DOME_GONE when the generator died")
	end)

	t.test("WELCOME lists every team's ally team (S-129, client request)", function()
		local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 }, { id = 3, team = 3, allyTeam = 1 }, { id = 4, team = 4, allyTeam = 2 } }
		local sim = Sim.new({ seed = 15, players = players, mapId = "flat:64" })
		NetOut.join(sim, 3)
		local rec = Schema.decodeSnapshot(Packer.Reader.new(sim.net.players[3].welcome :: buffer))
		t.equal(rec.allyTeam, 1)
		t.deepEqual(rec.teamAllies, { 1, 2, 1, 2 }, "teams 1..4 and their ally teams")
	end)
end
