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
--   * Own units off camera (S-158): OWN_STATUS events with health, build
--     progress and the factory queue's head for the player's units outside
--     its tactical tier, when one changed since the client last had it (at
--     its LEAVE, or the last OWN_STATUS); at most OWN_STATUS_MAX a tick, the
--     rest on the next ticks in turn.
--   * DEATH events for dead units the player had in its tactical tier.
--   * Combat events (D99; S-43: projectiles and shots regardless of sight,
--     never revealing a shooter):
--       FIRE        hitscan / beam shots of units in the tactical tier, with
--                   the shot's end point (no target ID: it may be hidden);
--       SHOT        the same for a shooter the player doesn't have: start and
--                   end point, no ID, when either is in the camera rectangle;
--       SPAWN_PROJ  a projectile the client doesn't have yet, once it is in
--                   the camera rectangle (+2 cells), seen or not: at launch,
--                   or when it flies into view. It carries
--                   the current position and velocity, and the homing
--                   target if the ally team knows that unit (tactical or a
--                   strategic record: its ID is no secret then);
--       DECOYED,    for projectiles the client has: position and velocity
--       LOST_LOCK   (DECOYED: also the decoy point it follows and for how many
--                   more ticks, S-28; LOST_LOCK: it flies on unguided);
--       IMPACT      for projectiles the client has, or anywhere in the camera
--                   rectangle (projectiles at the end of their
--                   life burst with an IMPACT too).
--     The client steps known projectiles itself and drops them on IMPACT or
--     at their time to live. All of a tick's events form one batch.
--   * Homing corrections (Projectiles channel, unreliable, D102): every
--     HOMING_SYNC_EVERY ticks (staggered by projectile ID), the position and
--     velocity of each homing projectile the client has that is in the
--     tactical area (camera + LEAVE_MARGIN), seen or not (S-43);
--     also on the tick one comes (back) into that view. Shells in a shield
--     dome's field get the same, plus one on the tick they turn or break
--     through and one on the tick they leave the field (S-79).
--   * Shield domes (S-79, protocol 24): a generator in the tactical tier
--     brings a SHIELD event (charge, up, recharging) after its ENTER and
--     whenever its charge moved SHIELD_STEP/255 or its flags changed. Its
--     tactical margins grow by its dome's radius, so the dome is known
--     wherever it shows. SHIELD_HIT events (a shell turned or through) go
--     with the combat events: for projectiles the client has, or anywhere
--     in the camera rectangle; the generator's ID only when the client has
--     it (else 0).
--   * Economy (Eco channel, S-2): the player's team account, on economy
--     ticks when it changed.
--   * Sight and wrecks (Events, protocol 10, S-26): the ally team's sight
--     map (sensor cells) on sensor ticks when it changed, as SIGHT_CELLS
--     changes or SIGHT_ROWS of the whole map (after a join); WRECK when the
--     team learns of a wreck (its spot in sight) with the supply left in
--     it, WRECK_GONE when it sees the spot without it; WRECK_STATE on
--     sensor ticks for sent wrecks in sight whose supply (whole units) or
--     resurrect progress (of 255) changed (protocol 35, S-168). Spectators get no sight (they see everything) and
--     every wreck.
--   * The pre-game (S-169, startMode "choose"): PREGAME for every player
--     (its pick, ready, AI) when it changes, to everyone; PREBUILD (a
--     player's queue for its Commander) to the player and its allies;
--     COUNTDOWN 5..1 while it runs, 255 when cancelled, 0 on the tick the
--     match starts, in the same outbox as the Commanders' ENTERs. A join
--     resends them.
--   * Join / reconnect (Snapshot channel, S-2): NetOut.hello checks the
--     client's versions; NetOut.join resets the player's replication state
--     and queues a WELCOME, so the next outbox is a complete picture (full
--     strategic snapshot, ENTERs for the camera area, SPAWN_PROJ for
--     projectiles in view, the Eco record).
-- Every channel is packed through Packer.chunk (≤ 900 bytes per message)
-- after a u16 tick header. Dirty bits are cleared once all players are done.

local Grid = require("@shared/Grid/Grid")
local Alerts = require("./Alerts")
local Cheats = require("./Cheats")
local Economy = require("./Economy")
local Packer = require("@shared/Net/Packer")
local Icons = require("@shared/Net/Icons")
local Schema = require("@shared/Net/Schema")
local Combat = require("./Combat/Combat")
local Stockpile = require("./Stockpile")
local Tick = require("@shared/Net/Tick")
local NetState = require("./NetState")
local Pinpoint = require("@shared/Combat/Pinpoint")
local Pregame = require("./Pregame")
local Sensors = require("./Sensors")
local Shield = require("./Shield")
local Types = require("./Types")
local World = require("./World")

local NetOut = {}

local combatEvents: (Types.Sim, Grid.Grid, NetState.PlayerNet, number, { number }, { Schema.Event }) -> ()

-- shield domes this tick (S-79; set at the start of NetOut.step)
local shieldNow: { [number]: number } = {}
local shieldDirty: { [number]: boolean } = {}
local fieldSync: { [number]: boolean } = {}
local domeCells: { [number]: number } = {} -- unit def index → dome radius in cells (shield generators)
local domeCellsOf: { [any]: { [number]: number } } = setmetatable({}, { __mode = "k" }) :: any

NetOut.ENTER_MARGIN = 2 -- cells
NetOut.LEAVE_MARGIN = 5
NetOut.SHIELD_STEP = 4 -- of 255: charge change that sends a SHIELD event (~1.6%)
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

NetOut.IDLE_EVERY = 5 -- ticks between checks of the player's idle builders and factories (S-136)
NetOut.OWN_STATUS_MAX = 24 -- OWN_STATUS events per player per tick (S-158): 216 bytes, ~3.2 KB/s at most

-- Nothing to do (S-136, client request 62): a factory with an empty queue;
-- a builder with no order of its own (automatic reactions don't count) and
-- no build, assist, repair or reclaim work.
function NetOut.isIdle(sim: Types.Sim, id: number): boolean
	local b = sim.build
	local d = sim.defs.unitByIndex[sim.world.defIndex[id]]
	if d.domain == "structure" then
		local q = b.queue[id]
		return q == nil or #q == 0
	end
	local q = sim.orders.queue[id]
	if q then
		for _, order in q do
			if not order.auto then
				return false
			end
		end
	end
	return b.order[id] == nil and (b.target[id] or 0) == 0 and (b.reclaim[id] or 0) == 0 and (b.resurrect[id] or 0) == 0
end

-- IDLE events (S-136): the player's finished builders and factories whose
-- idleness changed since last sent, on camera or not. Units not marked
-- idle are busy; a dead one's mark lapses with its generation.
local function idleEvents(sim: Types.Sim, pid: number, pn: NetState.PlayerNet, events: { Schema.Event })
	local w = sim.world
	local sent = pn.sentIdle
	for _, id in w.ids do
		if w.owner[id] ~= pid or w.buildProgress[id] < 1 then
			continue
		end
		local d = sim.defs.unitByIndex[w.defIndex[id]]
		if d.buildOptions == nil or #d.buildOptions == 0 then
			continue
		end
		local idle = NetOut.isIdle(sim, id)
		local was = sent[id] == w.gen[id]
		if idle ~= was then
			table.insert(events, { kind = Schema.EventKind.IDLE, unitId = id, idle = idle })
			sent[id] = if idle then w.gen[id] else nil
		end
	end
end

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
-- combat event, every team's Eco record (S-21), and no weapon targets. Its first outbox starts with a WELCOME whose player, team and
-- ally team are 0. Returns its index in `sim.net.spectators`.
-- Every team's ally team, team 1 first, 0 for a team not in the match (S-129).
local function teamAllies(sim: Types.Sim): { number }
	local n = 0
	for team in sim.allyOf do
		n = math.max(n, team)
	end
	local out = table.create(n, 0)
	for team = 1, n do
		out[team] = sim.allyOf[team] or 0
	end
	return out
end

function NetOut.addSpectator(sim: Types.Sim): number
	local pn = NetState.viewer(true)
	local map = sim.map
	if map then
		pn.camera = { 0, 0, math.min(map.grid.cellsX - 1, 255), math.min(map.grid.cellsZ - 1, 255) }
	end
	pn.forceFull = true
	local w = Packer.Writer.new(32)
	Schema.encodeSnapshot(w, { kind = Schema.SnapshotKind.WELCOME, tick = sim.tick, player = 0, team = 0, allyTeam = 0, mapId = sim.mapId, teamAllies = teamAllies(sim) })
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
	table.clear(pn.sentStock)
	table.clear(pn.sentOwner)
	table.clear(pn.sentProducing)
	table.clear(pn.sentOwn)
	table.clear(pn.sentOwnGen)
	table.clear(pn.domes)
	local p = sim.players[player]
	local w = Packer.Writer.new(32)
	Schema.encodeSnapshot(w, {
		kind = Schema.SnapshotKind.WELCOME,
		tick = sim.tick,
		player = player,
		team = p.team,
		allyTeam = sim.allyOf[p.team],
		mapId = sim.mapId,
		teamAllies = teamAllies(sim), -- (S-129, client request: allies are friends)
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
	-- the team's radar accuracy (S-147): what its radar-fired weapons miss
	-- by, as Sensors.wobble scales it; 0 without such a radar
	local s = sim.sensors
	local ally = sim.allyOf[team] or team
	local p = Sensors.precision(s, ally)
	local scale = Pinpoint.errorScale(p)
	local function tenths(err: number?): number
		return if err then math.clamp(math.floor(err * scale * 10 + 0.5), 1, 65535) else 0
	end
	return {
		team = team,
		supply = res(acc.supply),
		power = res(acc.power),
		wind = math.clamp(math.floor(sim.eco.wind * 255), 0, 255),
		radarError = tenths(s.radarError[ally]),
		trackError = tenths(s.trackError[ally]),
		precision = math.clamp(math.floor(p * 255 + 0.5), 0, 255),
	}
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

-- An own unit's status as OWN_STATUS sends it (S-158): health and build
-- progress u8, the factory queue's head (0 = none), its length and the
-- head's progress; and as one number that changes when one of them does
-- (the progress by sixteenths, like the owner's queue field).
local function ownStatus(sim: Types.Sim, id: number): (number, number, number, number, number, number)
	local w = sim.world
	local health = healthU8(w.health[id], sim.defs.unitByIndex[w.defIndex[id]].health)
	local build = math.floor(w.buildProgress[id] * 255)
	local q = sim.build.queue[id]
	local head, count, progress = 0, 0, 0
	if q and #q > 0 then
		head, count = q[1], math.min(#q, 63)
		progress = math.clamp(sim.build.progress[id] or 0, 0, 1)
	end
	local step = math.floor(progress * Stockpile.WIRE_STEPS)
	local sig = ((head * 64 + count) * 17 + step) * 65536 + build * 256 + health
	return sig, health, build, head, count, math.floor(progress * 255)
end

-- OWN_STATUS events (S-158): the player's units outside its tactical tier
-- whose status changed since the client last had it, at most OWN_STATUS_MAX;
-- past the cap the next tick starts where this one stopped.
local function ownStatusEvents(sim: Types.Sim, pid: number, pn: NetState.PlayerNet, events: { Schema.Event })
	local w = sim.world
	local ids = w.ids
	local n = #ids
	local sentSig, sentGen = pn.sentOwn, pn.sentOwnGen
	local start = pn.ownCursor % math.max(n, 1)
	local sent = 0
	for k = 0, n - 1 do
		local i = (start + k) % n + 1
		local id = ids[i]
		if w.owner[id] ~= pid or pn.tactical[id] then
			continue
		end
		local sig, health, build, head, count, progress = ownStatus(sim, id)
		if sentGen[id] == w.gen[id] and sentSig[id] == sig then
			continue
		end
		if sent == NetOut.OWN_STATUS_MAX then
			pn.ownCursor = i - 1
			return
		end
		sent += 1
		sentSig[id], sentGen[id] = sig, w.gen[id]
		table.insert(events, { kind = Schema.EventKind.OWN_STATUS, unitId = id, health = health, build = build, queueHead = head, queueProgress = progress, queueCount = count })
	end
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

-- SHIELD_FIELD for projectile `p`, in the field of generator `gen` (S-79).
local function fieldEvent(sim: Types.Sim, g: Grid.Grid, p: number, gen: number): Schema.Event
	local x, y, z = Shield.center(sim, gen)
	local e = withPos({ kind = Schema.EventKind.SHIELD_FIELD, projId = p }, g, x, y, z)
	e.radius = math.floor(sim.defs.unitByIndex[sim.world.defIndex[gen]].shield.radius + 0.5)
	e.force = math.clamp(math.floor(Shield.force(sim, gen) * 255 + 0.5), 0, 255)
	e.phase = sim.combat.pShieldPhase[p]
	return e
end

-- Combat events for one player (see the header): appended to `events`
-- after this tick's ENTER records, so a FIRE's shooter is already known.
function combatEvents(sim: Types.Sim, g: Grid.Grid, pn: NetState.PlayerNet, ally: number, cam: { number }, events: { Schema.Event })
	local c = sim.combat
	local known = pn.projKnown
	-- projectiles: everything in the camera area, whatever the team sees;
	-- they carry no shooter, so they reveal none (S-43, client request 21)
	local function shown(x: number, z: number): boolean
		return inRect(g, cam, x, z, NetOut.ENTER_MARGIN)
	end
	for _, e in c.events do
		if e.kind == "SPAWN_PROJ" then
			known[e.other] = nil -- a new projectile (IDs are reused)
		end
	end
	-- projectiles entering this client's view; strategic missiles go to
	-- every player wherever they fly (a few per match), and interceptors
	-- last, so the missile they chase is always known (S-48)
	local sentNow: { [number]: boolean } = {}
	local strategic = c.strategic
	for pass = 1, 2 do
		for _, p in c.proj do
			local interceptor = c.pTargetProj[p] ~= 0
			if interceptor ~= (pass == 2) or known[p] then
				continue
			end
			if not shown(c.px[p], c.pz[p]) and (#strategic == 0 or table.find(strategic, p) == nil) then
				continue
			end
			known[p] = true
			sentNow[p] = true
			local e
			if interceptor then
				local tp = c.pTargetProj[p]
				local target = if known[tp] and Combat.isProjRef(c, tp, c.pTargetSerial[p]) then tp else 0
				e = withPos({ kind = Schema.EventKind.INTERCEPTOR, projId = p, weaponIndex = c.pWeapon[p], targetId = target }, g, c.px[p], c.py[p], c.pz[p])
			elseif c.pGoal[p] then
				-- a strategic missile and the spot it flies to (S-51)
				local goal = c.pGoal[p]
				e = withPos({ kind = Schema.EventKind.SPAWN_STRATEGIC, projId = p, weaponIndex = c.pWeapon[p], targetId = 0 }, g, c.px[p], c.py[p], c.pz[p])
				e.goalCell, e.goalOffX, e.goalOffZ = g:encode(goal[1], goal[3])
				e.goalY = Schema.toI16(goal[2])
			else
				local target = c.pTarget[p]
				if target ~= 0 and (not World.isRef(sim.world, target, c.pTargetGen[p]) or levelFor(sim, ally, target) == L.HIDDEN) then
					target = 0
				end
				e = withPos({ kind = Schema.EventKind.SPAWN_PROJ, projId = p, weaponIndex = c.pWeapon[p], targetId = target }, g, c.px[p], c.py[p], c.pz[p])
			end
			table.insert(events, withVel(e, c.pvx[p], c.pvy[p], c.pvz[p]))
			if c.pShield[p] then
				table.insert(events, fieldEvent(sim, g, p, c.pShield[p])) -- already in a dome's field (S-79)
			end
		end
	end
	for _, e in c.events do
		local kind = e.kind
		if kind == "FIRE" and pn.tactical[e.unit] and e.x then
			table.insert(events, withPos({ kind = Schema.EventKind.FIRE, unitId = e.unit, slot = e.slot, hit = e.hit == true }, g, e.x, e.y :: number, e.z :: number))
		elseif kind == "FIRE" and e.x and e.sx and (shown(e.x, e.z :: number) or shown(e.sx, e.sz :: number)) then
			-- a shooter the player doesn't have: both ends, no ID (S-43)
			local shot = withPos({ kind = Schema.EventKind.SHOT, hit = e.hit == true, weaponIndex = e.weaponIndex or 0 }, g, e.x, e.y :: number, e.z :: number) -- (the weapon: S-118)
			shot.fromCell, shot.fromOffX, shot.fromOffZ = g:encode(e.sx, e.sz :: number)
			shot.fromY = Schema.toI16(e.sy :: number)
			table.insert(events, shot)
		elseif (kind == "DECOYED" or kind == "LOST_LOCK") and known[e.other] and not sentNow[e.other] then
			local p = e.other
			if c.projSlot[p] ~= nil then -- else its IMPACT follows
				-- the state after this tick's step, like SPAWN_PROJ
				local d = withPos({ kind = if kind == "DECOYED" then Schema.EventKind.DECOYED else Schema.EventKind.LOST_LOCK, projId = p }, g, c.px[p], c.py[p], c.pz[p])
				withVel(d, c.pvx[p], c.pvy[p], c.pvz[p])
				if kind == "DECOYED" then
					-- the point it follows and for how many more ticks (S-28)
					local dp = c.pDecoy[p] or { c.px[p], c.py[p], c.pz[p], 0, 1 }
					d.decoyCell, d.decoyOffX, d.decoyOffZ = g:encode(dp[1], dp[3])
					d.decoyY, d.decoyTicks = Schema.toI16(dp[2]), dp[4]
					d.countermeasure = dp[5] or 1 -- which countermeasure won (S-38)
				end
				table.insert(events, d)
			end
		elseif kind == "IMPACT" and e.x and (known[e.other] or shown(e.x, e.z :: number)) then
			known[e.other] = nil
			table.insert(events, withPos({ kind = Schema.EventKind.IMPACT, projId = e.other }, g, e.x, e.y :: number, e.z :: number))
		elseif kind == "SHIELD_FIELD" and known[e.other] and not sentNow[e.other] and c.pShield[e.other] == e.unit then
			table.insert(events, fieldEvent(sim, g, e.other, e.unit))
		elseif kind == "SHIELD_HIT" and e.x and ((e.other ~= 0 and known[e.other]) or shown(e.x, e.z :: number)) then
			-- the generator's ID only when the client has it (S-79)
			local hit = withPos({ kind = Schema.EventKind.SHIELD_HIT, unitId = if pn.tactical[e.unit] then e.unit else 0, projId = e.other }, g, e.x, e.y :: number, e.z :: number)
			hit.mass = math.clamp(math.floor((e.mass or 1) * Schema.SHIELD_MASS_SCALE + 0.5), 1, 255)
			hit.breach = e.breach == true
			hit.absorbed = e.absorbed == true
			if e.absorbed and e.other ~= 0 then
				known[e.other] = nil -- destroyed: this is its end, no IMPACT follows (S-85)
			end
			table.insert(events, hit)
		elseif kind == "INTERCEPTED" and e.x and (known[e.other] or shown(e.x, e.z :: number)) then
			known[e.other] = nil
			table.insert(events, withPos({ kind = Schema.EventKind.INTERCEPTED, projId = e.other }, g, e.x, e.y :: number, e.z :: number))
		end
	end
end

--------------------------------------------------------------------------------
-- Wrecks and sight on the wire (protocol 10, S-26)
--------------------------------------------------------------------------------

NetOut.SIGHT_EVERY = 2 -- ticks: the Sensors rate, so sight changes only then

-- An ally team's knowledge of wrecks (spectators: every wreck, at once). On
-- sensor ticks every unknown wreck in sight becomes known and every known
-- wreck that is gone is forgotten once its spot is in sight; in between,
-- only this tick's new and reclaimed wrecks are checked, so a DEATH and its
-- WRECK arrive together.
local function updateWrecks(sim: Types.Sim, net: NetState.NetState, ally: number, sensorTick: boolean, fresh: { number }, reclaimed: { number })
	local c = sim.combat
	local k = net.wrecks[ally]
	if k == nil then
		k = { known = {}, list = {}, version = 0 }
		net.wrecks[ally] = k
	end
	local known, list = k.known, k.list
	local changed = false
	local function learn(wid: number)
		local x, z = c.wreckX[wid], c.wreckZ[wid]
		if known[wid] == nil and x ~= nil and inSightFor(sim, ally, x, z) then
			known[wid] = { x, z, c.wreckDef[wid], c.wreckHeading[wid], c.wreckSupply[wid] }
			table.insert(list, wid)
			changed = true
		end
	end
	local function forgetIfSeen(i: number): boolean
		local wid = list[i]
		local p = known[wid]
		if c.wreckX[wid] == nil and inSightFor(sim, ally, p[1], p[2]) then
			known[wid] = nil
			table.remove(list, i)
			changed = true
			return true
		end
		return false
	end
	if sensorTick then
		for _, wid in c.wreckIds do
			learn(wid)
		end
		local i = 1
		while i <= #list do
			if not forgetIfSeen(i) then
				i += 1
			end
		end
	else
		for _, wid in fresh do
			learn(wid)
		end
		for _, wid in reclaimed do
			local i = if known[wid] then table.find(list, wid) else nil
			if i then
				forgetIfSeen(i)
			end
		end
	end
	if changed then
		k.version += 1
	end
end

-- The pre-game's events for one viewer (S-169; see the header).
local function pregameEvents(sim: Types.Sim, g: Grid.Grid, pn: NetState.PlayerNet, ally: number, events: { Schema.Event })
	local pg = sim.pregame
	local PF = Schema.PregameFlag
	if pg then
		for _, pid in sim.playerOrder do
			local p = pg.picks[pid]
			local cell, ox, oz = 0, 0, 0
			if p then
				cell, ox, oz = g:encode(p[1], p[2])
			end
			local flags = (if p then PF.PICKED else 0) + (if pg.ready[pid] then PF.READY else 0) + (if sim.match.ai[pid] then PF.AI else 0)
			local sig = flags * 2 ^ 32 + cell * 65536 + ox * 256 + oz
			if pn.sentPregame[pid] ~= sig then
				pn.sentPregame[pid] = sig
				table.insert(events, { kind = Schema.EventKind.PREGAME, player = pid, pregameFlags = flags, cell = cell, offX = ox, offZ = oz })
			end
			if ally == SPECTATOR or sim.players[pid].allyTeam == ally then
				local builds = {}
				local parts = {}
				for _, b in pg.builds[pid] or {} do
					local bc, bx, bz = g:encode(b.x, b.z)
					table.insert(builds, { defIndex = b.defIndex, cell = bc, offX = bx, offZ = bz, facing = b.facing })
					table.insert(parts, `{b.defIndex}:{bc}:{bx}:{bz}:{b.facing}`)
				end
				local key = table.concat(parts, ",")
				if (pn.sentPrebuild[pid] or "") ~= key then
					pn.sentPrebuild[pid] = key
					table.insert(events, { kind = Schema.EventKind.PREBUILD, player = pid, builds = builds })
				end
			end
		end
	end
	local now = Pregame.secondsLeft(sim)
	if pg == nil and sim.match.startTick == sim.tick and sim.tick > 0 then
		now = Schema.COUNTDOWN_STARTED
	end
	if now ~= nil and now ~= pn.sentCountdown then
		table.insert(events, { kind = Schema.EventKind.COUNTDOWN, seconds = now })
	elseif now == nil and pg ~= nil and pn.sentCountdown ~= nil then
		table.insert(events, { kind = Schema.EventKind.COUNTDOWN, seconds = Schema.COUNTDOWN_CANCELLED })
	end
	pn.sentCountdown = now
end

-- A wreck's supply and resurrect progress as WRECK_STATE sends them (S-168).
local function wreckState(c: any, wid: number): (number, number)
	return math.clamp(math.floor((c.wreckSupply[wid] or 0) + 0.5), 0, 65535), math.clamp(math.floor((c.wreckRez[wid] or 0) * 255), 0, 255)
end

-- WRECK_STATE for the viewer's sent wrecks in its team's sight whose supply
-- or resurrect progress changed (sensor ticks; S-168).
local function wreckStateEvents(sim: Types.Sim, pn: NetState.PlayerNet, ally: number, events: { Schema.Event })
	local c = sim.combat
	local sent = pn.sentWreckState
	for _, wid in pn.wreckList do
		local x = c.wreckX[wid]
		if x ~= nil and inSightFor(sim, ally, x, c.wreckZ[wid]) then
			local supply, rez = wreckState(c, wid)
			local sig = supply * 256 + rez
			if sent[wid] ~= sig then
				sent[wid] = sig
				table.insert(events, { kind = Schema.EventKind.WRECK_STATE, wreckId = wid, supply = supply, rez = rez })
			end
		end
	end
end

-- WRECK / WRECK_GONE for what the viewer's team learned since the last send.
local function wreckEvents(sim: Types.Sim, g: Grid.Grid, pn: NetState.PlayerNet, k: NetState.WreckKnowledge, events: { Schema.Event })
	if pn.wreckVersion == k.version then
		return
	end
	local c = sim.combat
	pn.wreckVersion = k.version
	local sent, sentList = pn.wrecksSent, pn.wreckList
	local i = 1
	while i <= #sentList do
		local wid = sentList[i]
		if k.known[wid] == nil then
			sent[wid] = nil
			pn.sentWreckState[wid] = nil
			table.remove(sentList, i)
			table.insert(events, { kind = Schema.EventKind.WRECK_GONE, wreckId = wid })
		else
			i += 1
		end
	end
	for _, wid in k.list do
		if not sent[wid] then
			sent[wid] = true
			table.insert(sentList, wid)
			local p = k.known[wid]
			local cell, ox, oz = g:encode(p[1], p[2])
			-- its supply now (S-168); a wreck gone since the team saw it: as it was
			local supply, rez = wreckState(c, wid)
			if c.wreckX[wid] == nil then
				supply, rez = math.clamp(math.floor((p[5] or 0) + 0.5), 0, 65535), 0
			end
			pn.sentWreckState[wid] = supply * 256 + rez
			local full = math.floor(Combat.fullWreckSupply(sim.defs.unitByIndex[p[3]]) + 0.5)
			table.insert(events, { kind = Schema.EventKind.WRECK, wreckId = wid, defIndex = p[3], cell = cell, offX = ox, offZ = oz, heading = NetOut.headingU8(p[4]), supply = supply, fullSupply = math.clamp(full, 0, 65535) })
			if rez > 0 then
				table.insert(events, { kind = Schema.EventKind.WRECK_STATE, wreckId = wid, supply = supply, rez = rez })
			end
		end
	end
end

-- The ally team's sight as of this sensor tick (one byte, 0 / 1, per sensor
-- cell), diffed in place against the last one: one pass per ally team, the
-- changes shared by its players.
local function updateSight(sim: Types.Sim, net: NetState.NetState, ally: number)
	local s = sim.sensors
	local n = s.width * s.depth
	local st = net.sight[ally]
	if st == nil then
		st = { cells = buffer.create(n), version = 0, changes = {} }
		net.sight[ally] = st
	end
	local los, cells = s.maps[ally].los, st.cells
	local changes = {}
	local readu16, readu8, writeu8 = buffer.readu16, buffer.readu8, buffer.writeu8
	for i = 0, n - 1 do
		local v = if readu16(los, i * 2) > 0 then 1 else 0
		if v ~= readu8(cells, i) then
			writeu8(cells, i, v)
			table.insert(changes, if v == 1 then i + Schema.SIGHT_SEEN else i)
		end
	end
	if #changes > 0 then
		st.version += 1
		st.changes = changes
	end
end

-- SIGHT_CELLS with the team's latest changes when the client has the version
-- before them and they are small; else SIGHT_ROWS of the whole map.
local function sightEvents(sim: Types.Sim, pn: NetState.PlayerNet, st: NetState.Sight, events: { Schema.Event })
	if pn.sightVersion == st.version then
		return
	end
	local s = sim.sensors
	local width, depth = s.width, s.depth
	local changes = st.changes
	if pn.sightVersion >= 0 and pn.sightVersion == st.version - 1 and #changes <= width * depth // 16 then -- 2 bytes per change against 1/8 per cell
		for first = 1, #changes, Schema.SIGHT_MAX_CELLS do
			table.insert(events, { kind = Schema.EventKind.SIGHT_CELLS, cells = table.move(changes, first, math.min(first + Schema.SIGHT_MAX_CELLS - 1, #changes), 1, {}) })
		end
	else
		local now = st.cells
		local rowBytes = (width + 7) // 8
		local perRecord = math.min(255, Schema.SIGHT_MAX_ROW_BYTES // rowBytes)
		for first = 0, depth - 1, perRecord do
			local rows = math.min(perRecord, depth - first)
			local bits = buffer.create(rows * rowBytes)
			for r = 0, rows - 1 do
				local base = (first + r) * width
				for x = 0, width - 1 do
					if buffer.readu8(now, base + x) == 1 then
						local at = r * rowBytes + x // 8
						buffer.writeu8(bits, at, bit32.bor(buffer.readu8(bits, at), bit32.lshift(1, x % 8)))
					end
				end
			end
			table.insert(events, { kind = Schema.EventKind.SIGHT_ROWS, firstRow = first, rowCount = rows, rowBytes = rowBytes, bits = bits })
		end
	end
	pn.sightVersion = st.version
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

	-- every team, ascending: a spectator's Eco records (S-21)
	local teamOrder: { number } = {}
	for _, pid in sim.playerOrder do
		local t = sim.players[pid].team
		if table.find(teamOrder, t) == nil then
			table.insert(teamOrder, t)
		end
	end
	table.sort(teamOrder)

	-- viewers: the players, then spectators (player, team and ally team 0)
	local viewers: { { pid: number, pn: NetState.PlayerNet, team: number, ally: number } } = {}
	for _, pid in sim.playerOrder do
		local team = sim.players[pid].team
		table.insert(viewers, { pid = pid, pn = net.players[pid], team = team, ally = sim.allyOf[team] })
	end
	for _, spn in net.spectators do
		table.insert(viewers, { pid = 0, pn = spn, team = 0, ally = SPECTATOR })
	end

	-- shield domes (S-79): each generator's wire state (charge × 4 + flags),
	-- dirty when the charge moved SHIELD_STEP or the flags changed; shells
	-- that turned or broke through this tick, or left a field
	local c = sim.combat
	domeCells = domeCellsOf[sim.defs]
	if domeCells == nil then
		domeCells = {}
		for index, def in sim.defs.unitByIndex do
			if def.shield then
				domeCells[index] = math.ceil(def.shield.radius / Grid.CELL_SIZE)
			end
		end
		domeCellsOf[sim.defs] = domeCells
	end
	shieldNow = {}
	shieldDirty = {}
	for _, id in c.shieldIds do
		local frac = Shield.fraction(sim, id) :: number
		local q = math.clamp(math.floor(frac * 255 + 0.5), 0, 255)
		local flags = (if c.shieldUp[id] then Schema.ShieldFlag.UP else 0) + (if Shield.recharging(sim, id) then Schema.ShieldFlag.RECHARGING else 0)
		local last = net.shieldSent[id]
		local lastQ = if last then last // 4 else -1
		if last == nil or last % 4 ~= flags or math.abs(q - lastQ) >= NetOut.SHIELD_STEP or (q ~= lastQ and (q == 0 or q == 255)) then
			shieldDirty[id] = true
			last = q * 4 + flags
		end
		shieldNow[id] = last :: number
	end
	net.shieldSent = shieldNow
	fieldSync = {}
	for _, e in c.events do
		if e.kind == "SHIELD_HIT" or e.kind == "SHIELD_FIELD" then
			fieldSync[e.other] = true
		end
	end
	local inField: { [number]: boolean } = {}
	for p in c.pShield do
		inField[p] = true
	end
	for p in net.inField do
		if not inField[p] and c.projSlot[p] ~= nil then
			fieldSync[p] = true -- it left the field this tick
		end
	end
	net.inField = inField

	-- wreck knowledge per ally team, and the teams' sight on sensor ticks (S-26)
	local sensorTick = tick % NetOut.SIGHT_EVERY == 0
	local fresh, reclaimed = {}, {}
	for _, e in sim.combat.events do
		if e.kind == "DEATH" and (e.other or 0) ~= 0 then
			table.insert(fresh, e.other :: number)
		elseif e.kind == "RECLAIMED" then
			table.insert(reclaimed, e.other :: number)
		end
	end
	local updated: { [number]: boolean } = {}
	for _, viewer in viewers do
		local a = viewer.ally
		if not updated[a] then
			updated[a] = true
			updateWrecks(sim, net, a, sensorTick, fresh, reclaimed)
			if a ~= SPECTATOR and (sensorTick or net.sight[a] == nil) then
				updateSight(sim, net, a)
			end
		end
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

		-- tier membership (fog first: only own or VISIBLE units can be tactical;
		-- shield generators from as far as their dome reaches, S-79)
		for _, id in w.ids do
			local seen = w.ally[id] == ally or levelFor(sim, ally, id) == L.VISIBLE
			local extra = domeCells[w.defIndex[id]] or 0
			if pn.tactical[id] then
				if not seen or cam == nil or not inRect(g, cam, w.posX[id], w.posZ[id], NetOut.LEAVE_MARGIN + extra) then
					pn.tactical[id] = nil
					table.remove(pn.tacticalList, table.find(pn.tacticalList, id) :: number)
					table.insert(events, { kind = Schema.EventKind.LEAVE, unitId = id })
					if w.owner[id] == pid then
						-- the client has its status as of now (S-158)
						pn.sentOwn[id], pn.sentOwnGen[id] = (ownStatus(sim, id)), w.gen[id]
					end
				end
			elseif seen and cam ~= nil and inRect(g, cam, w.posX[id], w.posZ[id], NetOut.ENTER_MARGIN + extra) then
				pn.tactical[id] = w.gen[id]
				table.insert(pn.tacticalList, id)
				entered[id] = true
				table.insert(events, enterEvent(sim, g, id))
			end
		end

		-- shield domes (S-79): after their ENTER, and when they changed
		if #sim.combat.shieldIds > 0 then
			for _, id in pn.tacticalList do
				local sent = shieldNow[id]
				if sent and (entered[id] or shieldDirty[id]) then
					table.insert(events, { kind = Schema.EventKind.SHIELD, unitId = id, charge = sent // 4, shieldFlags = sent % 4 })
				end
			end
		end
		-- domes regardless of vision (S-122, client request 55; as BAR draws
		-- shields): every dome whose circle touches the camera area, when
		-- the player doesn't have its generator; its centre, radius, charge
		-- and flags, never the generator's type
		local domes = pn.domes
		local domesNow: { [number]: boolean } = {}
		if cam ~= nil then
			for _, id in sim.combat.shieldIds do
				if pn.tactical[id] == nil and w.slot[id] ~= nil then
					local cells = domeCells[w.defIndex[id]] or 0
					if inRect(g, cam, w.posX[id], w.posZ[id], cells + NetOut.ENTER_MARGIN) then
						domesNow[id] = true
						local sent = shieldNow[id]
						if sent and (not domes[id] or shieldDirty[id]) then
							local cx, cy, cz = Shield.center(sim, id)
							local ev = withPos({ kind = Schema.EventKind.DOME, unitId = id, charge = sent // 4, shieldFlags = sent % 4 }, g, cx, cy, cz)
							ev.radius = sim.defs.unitByIndex[w.defIndex[id]].shield.radius
							table.insert(events, ev)
						end
					end
				end
			end
		end
		local gone = {}
		for id in domes do
			if not domesNow[id] then
				table.insert(gone, id)
			end
		end
		table.sort(gone) -- (in ID order, not table order)
		for _, id in gone do
			table.insert(events, { kind = Schema.EventKind.DOME_GONE, unitId = id })
		end
		pn.domes = domesNow

		-- changes of tactical units that were already known to the client;
		-- an armed unit entering gets its turrets' aim and weapon states at
		-- once (S-119, client request 53: aim went out only when it changed,
		-- so a turret held steady on a still target showed at rest)
		for _, id in pn.tacticalList do
			if entered[id] then
				if w.weaponCount[id] > 0 then
					local rec = stateRecord(sim, id, D.STATE)
					rec.state = nil -- (ENTER carries it)
					table.insert(states, rec)
				end
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

		-- own units' missile stock (S-47) and the next missile's progress
		-- (S-49): when a count or the progress step (1/WIRE_STEPS) changes,
		-- and on entering
		local sentStock = pn.sentStock
		local stockNow: { [number]: string } = {}
		for _, id in pn.tacticalList do
			local count = w.weaponCount[id]
			if w.owner[id] ~= pid or count == 0 then
				continue
			end
			local stock: { Schema.Stock } = {}
			local parts = {}
			for slot = 1, count do
				local key = World.slotKey(id, slot)
				local n = w.wStock[key]
				if n ~= nil then
					local progress = w.wStockProgress[key]
					table.insert(stock, { slot = slot, count = math.clamp(n, 0, 255), progress = math.clamp(math.floor(progress * 255), 0, 255) })
					table.insert(parts, n)
					table.insert(parts, math.floor(progress * Stockpile.WIRE_STEPS))
				end
			end
			if #stock == 0 then
				continue
			end
			local sig = table.concat(parts, ",")
			stockNow[id] = sig
			if entered[id] or sentStock[id] ~= sig then
				local rec = recordOf[id]
				if rec == nil then
					rec = { unitId = id }
					recordOf[id] = rec
					table.insert(states, rec)
				end
				rec.stock = stock
			end
		end
		pn.sentStock = stockNow

		-- own units' factory queue, fire / move state and ammo (S-61): each
		-- part when it changes (the queue's progress by sixteenths, like
		-- stock), all of them with the ENTER
		local sentOwner = pn.sentOwner
		local ownerNow: { [number]: { string } } = {}
		for _, id in pn.tacticalList do
			if w.owner[id] ~= pid then
				continue
			end
			local d = sim.defs.unitByIndex[w.defIndex[id]]
			local q = sim.build.queue[id]
			local qSig, sSig, aSig, cSig = "", "", "", ""
			local progress = 0
			if q then
				progress = math.clamp(math.floor((sim.build.progress[id] or 0) * 255), 0, 255)
				qSig = table.concat(q, ",") .. "@" .. math.floor((sim.build.progress[id] or 0) * Stockpile.WIRE_STEPS)
			end
			local hasStates = d.domain ~= "structure" or #d.weapons > 0
			if hasStates then
				sSig = tostring(w.fireState[id] * 4 + w.moveState[id])
			end
			local ammo = sim.air.ammo[id]
			if ammo ~= nil then
				aSig = tostring(ammo)
			end
			-- countermeasure charges left (S-63, client request 37)
			local cm = d.countermeasures
			local hasCharges = cm ~= nil and (cm.flares ~= nil or cm.chaff ~= nil)
			local flares, chaff = 0, 0
			if hasCharges then
				flares = if cm and cm.flares then sim.ew.flares[id] or 0 else 0
				chaff = if cm and cm.chaff then sim.ew.chaff[id] or 0 else 0
				cSig = flares .. "/" .. chaff
			end
			local now = { qSig, sSig, aSig, cSig }
			ownerNow[id] = now
			local before = if entered[id] then nil else sentOwner[id]
			local rec: Schema.State? = nil
			local function record(): Schema.State
				if rec == nil then
					rec = recordOf[id]
					if rec == nil then
						rec = { unitId = id }
						recordOf[id] = rec
						table.insert(states, rec :: Schema.State)
					end
				end
				return rec :: Schema.State
			end
			if q and (before == nil or before[1] ~= qSig) then
				local r = record()
				r.queue = table.clone(q)
				r.queueProgress = progress
			end
			if hasStates and (before == nil or before[2] ~= sSig) then
				local r = record()
				r.fireState, r.moveState = w.fireState[id], w.moveState[id]
			end
			if ammo ~= nil and (before == nil or before[3] ~= aSig) then
				local r = record()
				r.ammo, r.maxAmmo = math.clamp(ammo, 0, 255), math.clamp(d.ammo or ammo, 0, 255)
			end
			if hasCharges and (before == nil or before[4] ~= cSig) then
				local r = record()
				r.flares, r.chaff = math.clamp(flares, 0, 255), math.clamp(chaff, 0, 255)
			end
		end
		pn.sentOwner = ownerNow

		-- allied players' factories (S-103, client request 45): the item in
		-- production and its progress (by sixteenths, like the owner's
		-- queue), when it changes and with the ENTER
		local sentProducing = pn.sentProducing
		local producingNow: { [number]: string } = {}
		for _, id in pn.tacticalList do
			local q = sim.build.queue[id]
			if q == nil or w.owner[id] == pid or w.ally[id] ~= ally then
				continue
			end
			local head = q[1] or 0
			local p = if head ~= 0 then sim.build.progress[id] or 0 else 0
			local sig = head .. "@" .. math.floor(p * Stockpile.WIRE_STEPS)
			producingNow[id] = sig
			if entered[id] or sentProducing[id] ~= sig then
				local rec = recordOf[id]
				if rec == nil then
					rec = { unitId = id }
					recordOf[id] = rec
					table.insert(states, rec :: Schema.State)
				end
				local r = rec :: Schema.State
				r.producing = head
				r.producingProgress = math.clamp(math.floor(p * 255), 0, 255)
			end
		end
		pn.sentProducing = producingNow

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
				if own and Alerts.underAttack(sim, id) then
					flags += SF.UNDER_ATTACK -- hit by an enemy in the last 3 s (S-68)
				end
				local cell = g:encode(kx, kz)
				table.insert(strategic, {
					unitId = id,
					cell = cell,
					icon = if own or level == L.VISIBLE or level == L.GHOST or tracked then net.iconIndex[w.defIndex[id]] else (if level == L.RADAR and sim.defs.unitByIndex[w.defIndex[id]].spoof then net.iconIndex[sim.defs.units[sim.defs.unitByIndex[w.defIndex[id]].spoof :: string].index] else 0), -- a decoy shows its spoof's icon (S-109)
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
		-- the player's alerts (S-68): owner only, rate-limited by Sim/Alerts
		if pid ~= 0 then
			local alerts = Alerts.drain(sim, pid)
			if alerts then
				for _, a in alerts do
					local cell = g:encode(a.x, a.z)
					table.insert(events, { kind = Schema.EventKind.ALERT, alert = a.kind, cell = cell, defIndex = a.defIndex })
				end
			end
			local answers = Cheats.drain(sim, pid) -- CHEAT_RESULT (S-102)
			if answers then
				table.move(answers, 1, #answers, #events + 1, events)
			end
			if pn.forceFull then
				table.clear(pn.sentIdle)
			end
			if pn.forceFull or sim.tick % NetOut.IDLE_EVERY == 0 then
				idleEvents(sim, pid, pn, events)
			end
			if pn.forceFull then
				table.clear(pn.sentOwn)
				table.clear(pn.sentOwnGen)
			end
			ownStatusEvents(sim, pid, pn, events)
		end
		-- strategic launches: every player, camera or not (S-48)
		for _, e in sim.combat.events do
			if e.kind == "LAUNCH" and e.x then
				table.insert(events, withPos({ kind = Schema.EventKind.LAUNCH_WARNING, projId = e.other }, g, e.x, e.y :: number, e.z :: number))
			end
		end
		if pn.forceFull then
			pn.sightVersion = -1
			table.clear(pn.wrecksSent)
			table.clear(pn.wreckList)
			table.clear(pn.sentWreckState)
			pn.wreckVersion = -1
			table.clear(pn.sentPregame)
			table.clear(pn.sentPrebuild)
			pn.sentCountdown = nil
		end
		if ally ~= SPECTATOR then
			sightEvents(sim, pn, net.sight[ally], events)
		end
		pregameEvents(sim, g, pn, ally, events)
		wreckEvents(sim, g, pn, net.wrecks[ally], events)
		if sensorTick then
			wreckStateEvents(sim, pn, ally, events)
		end
		for _, e in events do
			pn.eventCounts[e.kind] = (pn.eventCounts[e.kind] or 0) + 1
			pn.eventBytes[e.kind] = (pn.eventBytes[e.kind] or 0) + Schema.eventBytes(e)
		end

		local syncs: { Schema.ProjSync } = {}
		local every = NetOut.HOMING_SYNC_EVERY
		if cam ~= nil and every > 0 then
			local weapons = sim.defs.weaponByIndex
			local inView = pn.projInView
			for _, e in c.events do
				if e.kind == "SPAWN_PROJ" then
					inView[e.other] = nil
				end
			end
			for _, p in c.proj do
				-- homing projectiles, and shells in a shield's field (S-79)
				if pn.projKnown[p] and (weapons[c.pWeapon[p]].turnRate ~= nil or c.pShield[p] ~= nil or fieldSync[p]) then
					local x, z = c.px[p], c.pz[p]
					local seen = inRect(g, cam, x, z, NetOut.LEAVE_MARGIN) -- sight doesn't matter (S-43)
					local entered = seen and not inView[p]
					inView[p] = seen or nil
					if seen and (entered or fieldSync[p] or (p + tick) % every == 0) then
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
		if pn.forceFull or tick % Economy.STEP_TICKS == 0 then
			-- a player: its own team's account; a spectator: every team's (S-21)
			local records: { Schema.Eco } = {}
			for _, t in (if team ~= 0 then { team } else teamOrder) do
				local rec = ecoRecord(sim, t)
				if rec then
					table.insert(records, rec)
				end
			end
			if #records > 0 then
				local wr = Packer.Writer.new(Schema.TICK_HEADER_BYTES + Schema.ECO_BYTES * #records)
				Schema.encodeTickHeader(wr, wireTick)
				for _, rec in records do
					Schema.encodeEco(wr, rec)
				end
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
