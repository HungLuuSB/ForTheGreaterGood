--!strict
-- Interest management and packet building (guide 7.2–7.6), headless.
--
-- Per player, every tick, fog first:
--   * Known units: the player's ally team's units, plus enemies the ally
--     team has at RADAR / SONAR / VISIBLE / GHOST (Sensors: sight is shared
--     by allies, guide 16.1). Nothing else is ever sent.
--   * Tactical tier: own or VISIBLE units within the camera rectangle; enter
--     at +2 cells, leave beyond +5 cells (hysteresis). Entering sends a
--     reliable ENTER event with the full state; leaving sends LEAVE.
--   * Tactical records (unreliable): tactical units whose position, heading
--     or altitude changed this tick.
--   * State records (reliable): tactical units whose health, state, aim or
--     build progress changed (dirty bits).
--   * Strategic records (unreliable, every 5th tick = 3 Hz): every other known
--     unit. Radar / sonar contacts carry their wobbled cell and icon 0
--     (tracked radar contacts: the TRACKED flag and the real icon, D104);
--     remembered structures carry the GHOST flag and their last position.
--   * DEATH events for dead units the player had in its tactical tier.
--   * Combat events (D99), only what the ally team may know:
--       FIRE        hitscan / beam shots of units in the tactical tier, with
--                   the shot's end point (no target ID: it may be hidden);
--       SPAWN_PROJ  a projectile the client doesn't have yet, once it is in
--                   the ally team's sight and in the camera rectangle (+2
--                   cells): at launch, or when it flies into view. It carries
--                   the current position and velocity, and the homing
--                   target if the ally team knows that unit (tactical or a
--                   strategic record: its ID is no secret then);
--       DECOYED,    for projectiles the client has: position and the new
--       LOST_LOCK   velocity (after the decoy turn; or flying on unguided);
--       IMPACT      for projectiles the client has, or anywhere in sight and
--                   in the camera rectangle (projectiles at the end of their
--                   life burst with an IMPACT too).
--     The client steps known projectiles itself and drops them on IMPACT or
--     at their time to live. All of a tick's events form one batch.
--   * Homing corrections (Projectiles channel, unreliable, D102): every
--     HOMING_SYNC_EVERY ticks (staggered by projectile ID), the position and
--     velocity of each homing projectile the client has that is in the
--     tactical area (camera + LEAVE_MARGIN) and in the ally team's sight;
--     also on the tick one comes (back) into that view.
--   * Economy (Eco channel, S-2): the player's team account, on economy
--     ticks when it changed.
--   * Join / reconnect (Snapshot channel, S-2): NetOut.hello checks the
--     client's versions; NetOut.join resets the player's replication state
--     and queues a WELCOME, so the next outbox is a complete picture (full
--     strategic snapshot, ENTERs for the camera area, SPAWN_PROJ for
--     projectiles in view, the Eco record).
-- Every channel is packed through Packer.chunk (≤ 900 bytes per message)
-- after a u16 tick header. Dirty bits are cleared once all players are done.

local Grid = require("@shared/Grid/Grid")
local Economy = require("./Economy")
local Packer = require("@shared/Net/Packer")
local Icons = require("@shared/Net/Icons")
local Schema = require("@shared/Net/Schema")
local Tick = require("@shared/Net/Tick")
local NetState = require("./NetState")
local Sensors = require("./Sensors")
local Types = require("./Types")
local World = require("./World")

local NetOut = {}

local combatEvents: (Types.Sim, Grid.Grid, NetState.PlayerNet, number, { number }, { Schema.Event }) -> ()

NetOut.ENTER_MARGIN = 2 -- cells
NetOut.LEAVE_MARGIN = 5
NetOut.STRATEGIC_EVERY = 5 -- ticks (3 Hz)
NetOut.HOMING_SYNC_EVERY = 5 -- ticks (3 Hz); 0 turns corrections off (measurements)

local D = World.Dirty
local band, bor = bit32.band, bit32.bor
local TAU = 2 * math.pi
local MOVED = bor(D.POSITION, D.HEADING, D.ALTITUDE)
local CHANGED = bor(D.HEALTH, D.STATE, D.BUILD)
local L = Sensors.Level

-- Spectators (S-18) see through the eyes of "ally 0": everything alive is
-- visible and every point in sight. Ally teams are 1..8, so 0 is free.
local SPECTATOR = 0
local function levelFor(sim: Types.Sim, ally: number, id: number): number
	if ally == SPECTATOR then
		return if sim.world.slot[id] ~= nil then L.VISIBLE else L.HIDDEN
	end
	return Sensors.level(sim, ally, id)
end
local function inSightFor(sim: Types.Sim, ally: number, x: number, z: number): boolean
	return ally == SPECTATOR or Sensors.inSight(sim, ally, x, z)
end
local SF = Schema.StrategicFlag

-- Strategic icon per def: the shared numbering (Shared/Net/Icons, S-10).
NetOut.iconIndex = Icons.byDef

function NetOut.new(sim: Types.Sim): NetState.NetState
	return NetState.new(sim.playerOrder, NetOut.iconIndex(sim.defs))
end

-- A client's HELLO (the first Snapshot message after connecting): nil when
-- its protocol and defs match, else the REJECT message to send it before
-- closing (docs/contracts/net.md 10). Malformed input errors (pcall it).
function NetOut.hello(sim: Types.Sim, msg: buffer): buffer?
	local rec = Packer.readAll(msg, Schema.decodeSnapshot)[1]
	if rec == nil or rec.kind ~= Schema.SnapshotKind.HELLO then
		error("NetOut.hello: expected a HELLO record", 2)
	end
	local reason = if rec.protocol ~= Schema.PROTOCOL_VERSION then Schema.RejectReason.PROTOCOL
		elseif rec.defsHash ~= sim.defs.hash then Schema.RejectReason.DEFS
		else nil
	if reason == nil then
		return nil
	end
	local w = Packer.Writer.new(8)
	Schema.encodeSnapshot(w, { kind = Schema.SnapshotKind.REJECT, protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, reason = reason })
	return w:finish()
end

-- Adds a spectator (S-18): it sees every unit (no fog), its camera covers
-- the whole map, so every unit is in its tactical tier, and it gets every
-- combat event; no Eco records (they have no team field) and no weapon
-- targets. Its first outbox starts with a WELCOME whose player, team and
-- ally team are 0. Returns its index in `sim.net.spectators`.
function NetOut.addSpectator(sim: Types.Sim): number
	local pn = NetState.viewer(true)
	local map = sim.map
	if map then
		pn.camera = { 0, 0, math.min(map.grid.cellsX - 1, 255), math.min(map.grid.cellsZ - 1, 255) }
	end
	pn.forceFull = true
	local w = Packer.Writer.new(32)
	Schema.encodeSnapshot(w, { kind = Schema.SnapshotKind.WELCOME, tick = sim.tick, player = 0, team = 0, allyTeam = 0, mapId = sim.mapId })
	pn.welcome = w:finish()
	table.insert(sim.net.spectators, pn)
	return #sim.net.spectators
end

-- (Re)joins `player`: forgets what its client had and queues a WELCOME, so
-- the next outbox rebuilds the whole view. A reconnect keeps the camera
-- unless `clearCamera`; a first join has none until a CAMERA command.
function NetOut.join(sim: Types.Sim, player: number, clearCamera: boolean?)
	local pn = sim.net.players[player]
	assert(pn, `NetOut.join: unknown player {player}`)
	table.clear(pn.tactical)
	table.clear(pn.tacticalList)
	table.clear(pn.projKnown)
	table.clear(pn.projInView)
	if clearCamera then
		pn.camera = nil
	end
	pn.forceFull = true
	pn.lastEco = nil
	table.clear(pn.sentTargets)
	local p = sim.players[player]
	local w = Packer.Writer.new(32)
	Schema.encodeSnapshot(w, {
		kind = Schema.SnapshotKind.WELCOME,
		tick = sim.tick,
		player = player,
		team = p.team,
		allyTeam = sim.allyOf[p.team],
		mapId = sim.mapId,
	})
	pn.welcome = w:finish()
end

-- The player's team account in wire units (Eco record).
local function ecoRecord(sim: Types.Sim, team: number): Schema.Eco?
	local acc = sim.eco.accounts[team]
	if acc == nil then
		return nil
	end
	local function res(r: Economy.Resource): Schema.EcoResource
		local function u32(x: number): number
			return math.clamp(math.floor(x), 0, 4294967295)
		end
		return {
			stored = u32(r.stored),
			storage = u32(r.storage),
			income = u32(r.income * 10 + 0.5),
			demand = u32(r.demand * 10 + 0.5),
			ratio = math.clamp(math.floor(r.ratio * 255), 0, 255),
		}
	end
	return { supply = res(acc.supply), power = res(acc.power), wind = math.clamp(math.floor(sim.eco.wind * 255), 0, 255) }
end

function NetOut.setCamera(sim: Types.Sim, player: number, minX: number, minZ: number, maxX: number, maxZ: number)
	local pn = sim.net.players[player]
	if pn then
		pn.camera = { minX, minZ, maxX, maxZ }
	end
end

-- Quantization (wire units)
function NetOut.headingU8(h: number): number
	return math.floor((h % TAU) / TAU * 256 + 0.5) % 256
end

local function healthU8(health: number, max: number): number
	return math.clamp(math.ceil(health / max * 255), 0, 255)
end

local function angleU8(a: number): number -- radians in [-π, π] → 0..255
	return math.clamp(math.floor((a + math.pi) / TAU * 255 + 0.5), 0, 255)
end

local function inRect(g: Grid.Grid, cam: { number }, x: number, z: number, margin: number): boolean
	local cx, cz = g:cellAt(x, z)
	return cx >= cam[1] - margin and cx <= cam[3] + margin and cz >= cam[2] - margin and cz <= cam[4] + margin
end

local function enterEvent(sim: Types.Sim, g: Grid.Grid, id: number): Schema.Event
	local w = sim.world
	local def = sim.defs.unitByIndex[w.defIndex[id]]
	local cell, ox, oz = g:encode(w.posX[id], w.posZ[id])
	return {
		kind = Schema.EventKind.ENTER,
		unitId = id,
		defIndex = w.defIndex[id],
		team = w.team[id],
		cell = cell,
		offX = ox,
		offZ = oz,
		heading = NetOut.headingU8(w.heading[id]),
		alt = math.clamp(math.floor(w.alt[id] + 0.5), 0, 255),
		health = healthU8(w.health[id], def.health),
		build = math.floor(w.buildProgress[id] * 255),
		state = band(w.state[id], 0xFFFF),
	}
end

local function stateRecord(sim: Types.Sim, id: number, dirty: number): Schema.State
	local w = sim.world
	local rec: Schema.State = { unitId = id }
	if band(dirty, D.HEALTH) ~= 0 then
		rec.health = healthU8(w.health[id], sim.defs.unitByIndex[w.defIndex[id]].health)
	end
	if band(dirty, D.BUILD) ~= 0 then
		rec.build = math.floor(w.buildProgress[id] * 255)
	end
	if band(dirty, D.STATE) ~= 0 then
		rec.state = band(w.state[id], 0xFFFF)
		local count = w.weaponCount[id]
		if count > 0 then
			local aim, states = {}, {}
			for slot = 1, count do
				local key = World.slotKey(id, slot)
				table.insert(aim, { slot = slot, yaw = angleU8(w.wYaw[key]), pitch = angleU8(w.wPitch[key]) })
				states[slot] = if w.wTarget[key] == 0
					then Schema.WeaponState.IDLE
					elseif w.wReload[key] <= 0 then Schema.WeaponState.READY
					else Schema.WeaponState.AIMING
			end
			rec.aim = aim
			rec.weapon = Schema.packWeaponStates(states)
		end
	end
	return rec
end

local function pack<T>(records: { T }, encode: (Packer.Writer, T) -> (), wireTick: number): { buffer }
	if #records == 0 then
		return {}
	end
	return Packer.chunk(records, encode, Packer.MAX_MESSAGE_BYTES, function(wr)
		Schema.encodeTickHeader(wr, wireTick)
	end)
end

local function withPos(e: Schema.Event, g: Grid.Grid, x: number, y: number, z: number): Schema.Event
	e.cell, e.offX, e.offZ = g:encode(x, z)
	e.y = Schema.toI16(y)
	return e
end

local function withVel(e: Schema.Event, vx: number, vy: number, vz: number): Schema.Event
	e.vx, e.vy, e.vz = Schema.toI16(vx), Schema.toI16(vy), Schema.toI16(vz)
	return e
end

-- Combat events for one player (see the header): appended to `events`
-- after this tick's ENTER records, so a FIRE's shooter is already known.
function combatEvents(sim: Types.Sim, g: Grid.Grid, pn: NetState.PlayerNet, ally: number, cam: { number }, events: { Schema.Event })
	local c = sim.combat
	local known = pn.projKnown
	local function shown(x: number, z: number): boolean
		return inRect(g, cam, x, z, NetOut.ENTER_MARGIN) and inSightFor(sim, ally, x, z)
	end
	for _, e in c.events do
		if e.kind == "SPAWN_PROJ" then
			known[e.other] = nil -- a new projectile (IDs are reused)
		end
	end
	-- projectiles entering this client's view
	local sentNow: { [number]: boolean } = {}
	for _, p in c.proj do
		if not known[p] and shown(c.px[p], c.pz[p]) then
			known[p] = true
			sentNow[p] = true
			local target = c.pTarget[p]
			if target ~= 0 and (not World.isRef(sim.world, target, c.pTargetGen[p]) or levelFor(sim, ally, target) == L.HIDDEN) then
				target = 0
			end
			local e = withPos({ kind = Schema.EventKind.SPAWN_PROJ, projId = p, weaponIndex = c.pWeapon[p], targetId = target }, g, c.px[p], c.py[p], c.pz[p])
			table.insert(events, withVel(e, c.pvx[p], c.pvy[p], c.pvz[p]))
		end
	end
	for _, e in c.events do
		local kind = e.kind
		if kind == "FIRE" and pn.tactical[e.unit] and e.x then
			table.insert(events, withPos({ kind = Schema.EventKind.FIRE, unitId = e.unit, slot = e.slot, hit = e.hit == true }, g, e.x, e.y :: number, e.z :: number))
		elseif (kind == "DECOYED" or kind == "LOST_LOCK") and known[e.other] and not sentNow[e.other] then
			local p = e.other
			if c.projSlot[p] ~= nil then -- else its IMPACT follows
				-- the state after this tick's step, like SPAWN_PROJ
				local d = withPos({ kind = if kind == "DECOYED" then Schema.EventKind.DECOYED else Schema.EventKind.LOST_LOCK, projId = p }, g, c.px[p], c.py[p], c.pz[p])
				table.insert(events, withVel(d, c.pvx[p], c.pvy[p], c.pvz[p]))
			end
		elseif kind == "IMPACT" and e.x and (known[e.other] or shown(e.x, e.z :: number)) then
			known[e.other] = nil
			table.insert(events, withPos({ kind = Schema.EventKind.IMPACT, projId = e.other }, g, e.x, e.y :: number, e.z :: number))
		end
	end
end

function NetOut.step(sim: Types.Sim)
	local map = sim.map
	if map == nil then
		return -- no grid to encode positions with
	end
	local g = map.grid
	local w = sim.world
	local net = sim.net
	local tick = sim.tick
	local wireTick = Tick.toWire(tick)
	local strategicTick = tick % NetOut.STRATEGIC_EVERY == 0

	-- viewers: the players, then spectators (player, team and ally team 0)
	local viewers: { { pid: number, pn: NetState.PlayerNet, team: number, ally: number } } = {}
	for _, pid in sim.playerOrder do
		local team = sim.players[pid].team
		table.insert(viewers, { pid = pid, pn = net.players[pid], team = team, ally = sim.allyOf[team] })
	end
	for _, spn in net.spectators do
		table.insert(viewers, { pid = 0, pn = spn, team = 0, ally = SPECTATOR })
	end
	for _, viewer in viewers do
		local pid, pn, team = viewer.pid, viewer.pn, viewer.team
		local ally = viewer.ally -- sight is shared by the ally team (guide 16.1)
		local cam = pn.camera
		local events: { Schema.Event } = {}
		local tactical: { Schema.Tactical } = {}
		local states: { Schema.State } = {}
		local entered: { [number]: boolean } = {}

		-- deaths of tactical units
		for _, e in sim.combat.events do
			if e.kind == "DEATH" and pn.tactical[e.unit] then
				pn.tactical[e.unit] = nil
				table.remove(pn.tacticalList, table.find(pn.tacticalList, e.unit) :: number)
				table.insert(events, {
					kind = Schema.EventKind.DEATH,
					unitId = e.unit,
					severity = e.severity or 0,
					wreckId = e.other,
				})
			end
		end

		-- tactical units removed without a DEATH (reclaimed, cancelled frames)
		local i = 1
		while i <= #pn.tacticalList do
			local id = pn.tacticalList[i]
			if not World.isRef(w, id, pn.tactical[id]) then -- gone (or its ID reused, D109)
				pn.tactical[id] = nil
				table.remove(pn.tacticalList, i)
				table.insert(events, { kind = Schema.EventKind.LEAVE, unitId = id })
			else
				i += 1
			end
		end

		-- tier membership (fog first: only own or VISIBLE units can be tactical)
		for _, id in w.ids do
			local seen = w.ally[id] == ally or levelFor(sim, ally, id) == L.VISIBLE
			if pn.tactical[id] then
				if not seen or cam == nil or not inRect(g, cam, w.posX[id], w.posZ[id], NetOut.LEAVE_MARGIN) then
					pn.tactical[id] = nil
					table.remove(pn.tacticalList, table.find(pn.tacticalList, id) :: number)
					table.insert(events, { kind = Schema.EventKind.LEAVE, unitId = id })
				end
			elseif seen and cam ~= nil and inRect(g, cam, w.posX[id], w.posZ[id], NetOut.ENTER_MARGIN) then
				pn.tactical[id] = w.gen[id]
				table.insert(pn.tacticalList, id)
				entered[id] = true
				table.insert(events, enterEvent(sim, g, id))
			end
		end

		-- changes of tactical units that were already known to the client
		for _, id in pn.tacticalList do
			if entered[id] then
				continue
			end
			local dirty = w.dirty[id]
			if band(dirty, MOVED) ~= 0 then
				local cell, ox, oz = g:encode(w.posX[id], w.posZ[id])
				local alt = w.alt[id]
				table.insert(tactical, {
					unitId = id,
					cell = cell,
					offX = ox,
					offZ = oz,
					heading = NetOut.headingU8(w.heading[id]),
					alt = if alt > 0 then math.clamp(math.floor(alt + 0.5), 0, 255) else nil,
				})
			end
			if band(dirty, CHANGED) ~= 0 then
				table.insert(states, stateRecord(sim, id, dirty))
			end
		end

		-- own units' weapon targets (S-16): when they change, and on entering
		-- with any target
		local sent = pn.sentTargets
		local sentNow: { [number]: string } = {}
		local recordOf: { [number]: Schema.State } = {}
		for _, rec in states do
			recordOf[rec.unitId] = rec
		end
		for _, id in pn.tacticalList do
			local count = w.weaponCount[id]
			if w.owner[id] ~= pid or count == 0 then
				continue
			end
			local targets: { Schema.Target } = {}
			local parts = {}
			local any = false
			for slot = 1, count do
				local t = w.wTarget[World.slotKey(id, slot)]
				targets[slot] = { slot = slot, targetId = t }
				parts[slot] = t
				any = any or t ~= 0
			end
			local sig = table.concat(parts, ",")
			sentNow[id] = sig
			local due = if entered[id] then any else sent[id] ~= sig
			if due then
				local rec = recordOf[id]
				if rec == nil then
					rec = { unitId = id }
					recordOf[id] = rec
					table.insert(states, rec)
				end
				rec.targets = targets
			end
		end
		pn.sentTargets = sentNow

		-- strategic snapshot of every other known unit
		local strategic: { Schema.Strategic } = {}
		local fullNow = strategicTick or pn.forceFull
		if fullNow then
			for _, id in w.ids do
				if pn.tactical[id] then
					continue
				end
				local kx, kz, level = Sensors.knownPosition(sim, ally, id)
				if kx == nil or kz == nil then
					continue
				end
				local own = w.ally[id] == ally
				local tracked = level == L.RADAR and Sensors.isTracked(sim, ally, id) -- D104: type known
				local flags = if level == L.RADAR then (if tracked then SF.RADAR_ONLY + SF.TRACKED else SF.RADAR_ONLY)
					elseif level == L.SONAR then SF.SONAR_ONLY
					elseif level == L.GHOST then SF.GHOST
					else 0
				local cell = g:encode(kx, kz)
				table.insert(strategic, {
					unitId = id,
					cell = cell,
					icon = if own or level == L.VISIBLE or level == L.GHOST or tracked then net.iconIndex[w.defIndex[id]] else 0,
					team = w.team[id],
					flags = flags,
				})
			end
			-- remembered structures that are already gone
			for _, gid in sim.sensors.ghostIds[ally] or {} do
				local ghost = sim.sensors.ghosts[ally][gid]
				if not World.isRef(w, gid, ghost.gen) then
					table.insert(strategic, {
						unitId = gid,
						cell = (g:encode(ghost.x, ghost.z)),
						icon = net.iconIndex[ghost.defIndex],
						team = ghost.team,
						flags = SF.GHOST,
					})
				end
			end
		end

		if cam ~= nil then
			combatEvents(sim, g, pn, ally, cam, events)
		end
		for _, e in events do
			pn.eventCounts[e.kind] = (pn.eventCounts[e.kind] or 0) + 1
		end

		local syncs: { Schema.ProjSync } = {}
		local every = NetOut.HOMING_SYNC_EVERY
		if cam ~= nil and every > 0 then
			local c = sim.combat
			local weapons = sim.defs.weaponByIndex
			local inView = pn.projInView
			for _, e in c.events do
				if e.kind == "SPAWN_PROJ" then
					inView[e.other] = nil
				end
			end
			for _, p in c.proj do
				if pn.projKnown[p] and weapons[c.pWeapon[p]].turnRate ~= nil then
					local x, z = c.px[p], c.pz[p]
					local seen = inRect(g, cam, x, z, NetOut.LEAVE_MARGIN) and inSightFor(sim, ally, x, z)
					local entered = seen and not inView[p]
					inView[p] = seen or nil
					if seen and (entered or (p + tick) % every == 0) then
						local rec: any = withVel(withPos({ kind = 0, projId = p } :: any, g, x, c.py[p], z), c.pvx[p], c.pvy[p], c.pvz[p])
						rec.kind = nil
						table.insert(syncs, rec :: Schema.ProjSync)
					end
				end
			end
		end

		local outbox = pn.outbox
		outbox.Snapshot = {}
		if pn.welcome then
			outbox.Snapshot = { pn.welcome }
			pn.welcome = nil
		end
		outbox.Eco = {}
		if team ~= 0 and (pn.forceFull or tick % Economy.STEP_TICKS == 0) then -- spectators: no team account
			local rec = ecoRecord(sim, team)
			if rec then
				local wr = Packer.Writer.new(Schema.TICK_HEADER_BYTES + Schema.ECO_BYTES)
				Schema.encodeTickHeader(wr, wireTick)
				Schema.encodeEco(wr, rec)
				local msg = wr:finish()
				local bytes = buffer.tostring(msg)
				-- the tick header changes every time: compare the record itself
				local body = string.sub(bytes, Schema.TICK_HEADER_BYTES + 1)
				if pn.forceFull or body ~= pn.lastEco then
					outbox.Eco = { msg }
					pn.lastEco = body
				end
			end
		end
		outbox.Projectiles = pack(syncs, Schema.encodeProjSync, wireTick)
		outbox.Events = pack(events, Schema.encodeEvent, wireTick)
		outbox.Tactical = pack(tactical, Schema.encodeTactical, wireTick)
		outbox.State = pack(states, Schema.encodeState, wireTick)
		outbox.Strategic = pack(strategic, Schema.encodeStrategic, wireTick)
		if fullNow and #outbox.Strategic == 0 then
			-- an empty snapshot still tells the client to drop old strategic units
			local wr = Packer.Writer.new(2)
			Schema.encodeTickHeader(wr, wireTick)
			outbox.Strategic = { wr:finish() }
		end
		pn.forceFull = false
		for _, ch in NetState.CHANNELS do
			for _, msg in outbox[ch] do
				pn.bytes[ch] += buffer.len(msg)
				pn.messages[ch] += 1
			end
		end
	end

	for _, id in w.ids do
		World.clearDirty(w, id)
	end
end

return NetOut
