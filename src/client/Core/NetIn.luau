--!strict
-- Applies server messages to the client World (guide 7, docs/contracts/net.md,
-- protocol 6). One call per received message; channels may arrive in any
-- order, unreliable ones may be lost or reordered:
--   * every decode is pcall'ed and a malformed message is dropped whole;
--   * Tactical / Strategic records older than what a unit already has are dropped;
--   * Tactical / State records for a unit that never ENTERed are dropped.
-- Pure Luau (C-7); the reference receiver is src/server/Tests/Support/Client.

local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Tick = require("@shared/Net/Tick")
local World = require("./World")

local NetIn = {}

local EK = Schema.EventKind
local SF = Schema.StrategicFlag

-- Sim tick of a message from its wire tick; also advances world.latestTick.
local function stamp(world: World.World, wireTick: number, now: number): number
	local simTick = if world.latestTick < 0 then wireTick else Tick.unwrap(wireTick, world.latestTick)
	if simTick > world.latestTick then
		world.latestTick = simTick
		world.latestAt = now
	end
	return simTick
end

local function pushSnap(unit: World.Unit, snap: World.Snap)
	local snaps = unit.snaps
	table.insert(snaps, snap)
	if #snaps > World.MAX_SNAPS then
		table.remove(snaps, 1)
	end
end

local function queueEvent(world: World.World, e: Schema.Event, tick: number)
	local events = world.events
	if #events >= World.MAX_QUEUED_EVENTS then
		table.remove(events, 1)
	end
	(e :: any).tick = tick
	table.insert(events, e)
	local kind = (e :: any).kind
	world.eventCounts[kind] = (world.eventCounts[kind] or 0) + 1
end

-- The ally team's sight map, made on its first record for the map's sensor grid.
local function sightOf(world: World.World): World.Sight
	local s = world.sight
	if s == nil then
		local w, d = world.grid.sensorX, world.grid.sensorZ
		s = { width = w, depth = d, cells = buffer.create(w * d), version = 0, changed = {}, full = true }
		world.sight = s
	end
	return s :: World.Sight
end

local function applyEvents(world: World.World, events: { Schema.Event }, tick: number)
	local g = world.grid
	for _, e in events do
		local kind = e.kind
		if kind == EK.ENTER then
			local id = e.unitId :: number
			local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
			local heading = World.heading(e.heading :: number)
			local alt = e.alt or 0
			local was = world.units[id] -- a strategic record of it keeps its movement (C-45)
			world.units[id] = {
				id = id,
				tier = "tactical",
				team = e.team :: number,
				defIndex = e.defIndex,
				x = x,
				z = z,
				alt = alt,
				heading = heading,
				snaps = { { tick = tick, x = x, z = z, alt = alt, heading = heading } },
				lastTick = tick,
				movedTick = was and was.movedTick,
				health = (e.health :: number) / 255,
				shownHealth = (e.health :: number) / 255,
				build = (e.build :: number) / 255,
				state = e.state or 0,
				weapon = 0,
				aim = {},
			}
			table.insert(world.entered, id)
			world.ownStatus[id] = nil -- ENTER and State carry it now (S-158)
			world.carriedDefs[id] = nil
		elseif kind == EK.LEAVE then
			world.shields[e.unitId :: number] = nil -- its dome is sent again on the next ENTER
			world.carry[e.unitId :: number] = nil -- sent again with the next ENTER (S-220)
			local u = world.units[e.unitId :: number]
			if u and u.team == world.me.team then
				world.carriedDefs[u.id] = u.defIndex -- maybe boarding a transport: its CARGO names it (C-272)
			end
			if u and u.tier == "tactical" then
				u.tier = "strategic" -- refreshed or dropped by the next strategic snapshot
				table.clear(u.snaps)
				u.rx, u.ry, u.rz = nil, nil, nil -- no longer drawn
				table.insert(world.left, u.id)
			end
		elseif kind == EK.DEATH then
			local id = e.unitId :: number
			world.shields[id] = nil
			world.idle[id] = nil
			world.ownStatus[id] = nil
			world.carriedDefs[id] = nil
			world.carry[id] = nil -- (its cargo dies with it, S-219)
			world.lastShot[id] = nil
			local u = world.units[id]
			if u then
				local vx, vz = 0, 0
				local snaps = u.snaps
				if #snaps >= 2 then
					local a, b = snaps[#snaps - 1], snaps[#snaps]
					local dt = math.max(b.tick - a.tick, 1) / 15
					vx, vz = (b.x - a.x) / dt, (b.z - a.z) / dt
				end
				table.insert(world.died, {
					id = id,
					defIndex = u.defIndex,
					team = u.team,
					x = u.x,
					z = u.z,
					heading = u.heading,
					severity = e.severity or 0,
					wreckId = e.wreckId or 0,
					tick = tick,
					alt = u.alt,
					vx = vx,
					vz = vz,
				})
				world.dying[id] = { unit = u, tick = tick } -- still a missile's target until the death is drawn (C-50)
				world.units[id] = nil
			end
			if (e.wreckId or 0) ~= 0 then
				world.deathWrecks[e.wreckId :: number] = tick
			end
		elseif kind == EK.SIGHT_ROWS then
			-- the ally team's sight, rows wholesale (protocol 10, C-65)
			local s = sightOf(world)
			local first, rows, rowBytes = e.firstRow :: number, e.rowCount :: number, e.rowBytes :: number
			local bits = e.bits :: buffer
			for r = 0, rows - 1 do
				local z = first + r
				if z >= s.depth then
					break
				end
				for x = 0, s.width - 1 do
					local byte = buffer.readu8(bits, r * rowBytes + x // 8)
					buffer.writeu8(s.cells, z * s.width + x, bit32.extract(byte, x % 8, 1))
				end
			end
			s.full = true
			s.version += 1
		elseif kind == EK.SIGHT_CELLS then
			-- cells that turned seen / unseen since the last sensor tick
			local s = sightOf(world)
			local n = s.width * s.depth
			for _, c in e.cells :: { number } do
				local index = c % Schema.SIGHT_SEEN -- the low 23 bits (protocol 38: u24 entries)
				if index < n then
					buffer.writeu8(s.cells, index, if bit32.band(c, Schema.SIGHT_SEEN) ~= 0 then 1 else 0)
					table.insert(s.changed, index)
				end
			end
			s.version += 1
		elseif kind == EK.WRECK then
			local x, z = world.grid:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
			local id = e.wreckId :: number
			world.wrecks[id] = { id = id, defIndex = e.defIndex :: number, x = x, z = z, heading = World.heading(e.heading or 0), supply = e.supply or 0, fullSupply = e.fullSupply or 0, rez = 0, feature = if (e.featureKind or 0) > 0 then e.featureKind else nil }
			table.insert(world.wreckAdded, id)
		elseif kind == EK.ALERT then
			-- the owner's alerts (protocol 23, S-68); stalls carry cell 0; a full
			-- wire position since protocol 38 (S-189)
			local x, z = g:decode(e.cell :: number, e.offX or 128, e.offZ or 128)
			table.insert(world.alertQueue, { kind = e.alert :: number, x = x, z = z, defIndex = e.defIndex or 0, tick = tick })
		elseif EK.OWN_STATUS ~= nil and kind == EK.OWN_STATUS then
			-- an own unit off camera: health, build and factory queue (protocol 34,
			-- S-158); kept by ID, as it can come before the unit's strategic record
			local id = e.unitId :: number
			local status: World.OwnStatus = {
				health = (e.health :: number) / 255,
				build = (e.build :: number) / 255,
				queueHead = e.queueHead or 0,
				queueProgress = (e.queueProgress or 0) / 255,
				queueCount = e.queueCount or 0,
			}
			world.ownStatus[id] = status
			local u = world.units[id]
			if u and u.tier ~= "tactical" then
				World.applyStatus(u, status)
			end
		elseif EK.IDLE ~= nil and kind == EK.IDLE then
			-- one of this player's builders or factories became idle or busy (S-136)
			world.idle[e.unitId :: number] = if e.idle then true else nil
		elseif kind == EK.CHEAT_RESULT then
			-- the answer to this player's cheat command (protocol 27, S-102)
			table.insert(world.cheatResults, e)
		elseif EK.DOME ~= nil and kind == EK.DOME then
			-- a dome whose generator this player doesn't have (protocol 29, S-122):
			-- its centre, radius and state, whatever the team sees (C-145)
			local x, z = world.grid:decode(e.cell, e.offX, e.offZ)
			world.remoteDomes[e.unitId :: number] = { x = x, y = (e.y :: number) / Schema.Y_SCALE, z = z, radius = e.radius :: number, charge = (e.charge :: number) / 255, flags = e.shieldFlags or 0 }
		elseif EK.DOME_GONE ~= nil and kind == EK.DOME_GONE then
			-- (when the generator came into view, its ENTER and SHIELD take over)
			world.remoteDomes[e.unitId :: number] = nil
		elseif kind == EK.SHIELD then
			-- a generator's dome (protocol 24, S-79): charge and up / recharging
			world.shields[e.unitId :: number] = { charge = (e.charge :: number) / 255, flags = e.shieldFlags :: number }
		elseif EK.WRECK_STATE ~= nil and kind == EK.WRECK_STATE then
			-- a known wreck's supply and resurrect progress (protocol 35, S-168)
			local w = world.wrecks[e.wreckId :: number]
			if w then
				w.supply = e.supply or w.supply
				w.rez = (e.rez or 0) / 255
			end
		elseif EK.PREGAME ~= nil and kind == EK.PREGAME then
			-- one player's pick, ready and AI flags (protocol 36, S-169; C-218)
			local pg = world.pregame
			local flags = e.pregameFlags :: number
			local x, z = nil, nil
			if bit32.band(flags, Schema.PregameFlag.PICKED) ~= 0 then
				x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
			end
			pg.picks[e.player :: number] = { flags = flags, x = x, z = z }
			pg.active = not pg.started
			pg.version += 1
		elseif EK.COUNTDOWN ~= nil and kind == EK.COUNTDOWN then
			-- 3..1, then 0 as the match starts (the Commanders' ENTERs follow); 255 cancelled
			local pg = world.pregame
			local seconds = e.seconds :: number
			if seconds == Schema.COUNTDOWN_STARTED then
				pg.active, pg.started, pg.countdown = false, true, nil
				pg.startedTick = tick
			elseif seconds == Schema.COUNTDOWN_CANCELLED then
				pg.countdown = nil
			else
				pg.countdown = seconds
			end
			pg.version += 1
		elseif EK.PICK_CLOCK ~= nil and kind == EK.PICK_CLOCK then
			-- the pick time left, or the forced start's (protocol 37, S-174)
			world.pregame.clock = { seconds = e.seconds :: number, flags = e.clockFlags or 0 }
			world.pregame.version += 1
		elseif EK.START_BOXES ~= nil and kind == EK.START_BOXES then
			-- every side's spawn box, as the host drew it or the map's (protocol 37)
			local boxes = {}
			for _, b in e.boxes or {} do
				boxes[b.allyTeam] = { b.x0, b.z0, b.x1, b.z1 }
			end
			world.pregame.boxes = boxes
			world.pregame.version += 1
		elseif EK.TRANSPORT ~= nil and kind == EK.TRANSPORT then
			-- a pick-up or set-down starts or stops (protocol 44, S-220; C-274)
			local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
			table.insert(world.transportFx, { tick = tick, transport = e.unitId :: number, unit = e.targetId :: number, defIndex = e.defIndex :: number, action = e.action :: number, ticks = e.actionTicks or 15, x = x, z = z })
		elseif EK.CARRY ~= nil and kind == EK.CARRY then
			-- what a transport carries now, for every viewer (protocol 44)
			local id, index = e.unitId :: number, e.defIndex :: number
			world.carry[id] = if index ~= 0 then index else nil
			table.insert(world.transportFx, { tick = tick, transport = id, unit = 0, defIndex = index, action = 0, ticks = 0, x = 0, z = 0 })
		elseif EK.SHARE ~= nil and kind == EK.SHARE then
			-- a gift or a request for help in the ally team (protocol 37, S-176)
			table.insert(world.shares, e)
			if #world.shares > 20 then
				table.remove(world.shares, 1)
			end
		elseif EK.PREBUILD ~= nil and kind == EK.PREBUILD then
			-- a player's queued builds for its Commander, the whole list
			local list = {}
			for _, b in e.builds or {} do
				local x, z = g:decode(b.cell, b.offX, b.offZ)
				table.insert(list, { defIndex = b.defIndex, x = x, z = z, facing = b.facing })
			end
			world.pregame.builds[e.player :: number] = list
			world.pregame.version += 1
		elseif kind == EK.WRECK_GONE then
			local id = e.wreckId :: number
			world.wrecks[id] = nil
			world.deathWrecks[id] = nil
			table.insert(world.wreckGone, id)
		else
			queueEvent(world, e, tick)
		end
	end
end

local function applyTactical(world: World.World, records: { Schema.Tactical }, tick: number)
	local g = world.grid
	for _, r in records do
		local u = world.units[r.unitId]
		if u == nil or u.tier ~= "tactical" then
			world.dropped += 1
			continue
		end
		if tick <= u.lastTick then
			continue -- reordered: we already have something newer
		end
		local x, z = g:decode(r.cell, r.offX, r.offZ)
		local heading = World.heading(r.heading)
		local alt = r.alt or 0
		if x ~= u.x or z ~= u.z or alt ~= u.alt or heading ~= u.heading then
			u.movedTick = tick -- C-45: the server doesn't set MOVING
		end
		u.x, u.z, u.alt, u.heading, u.lastTick = x, z, alt, heading, tick
		pushSnap(u, { tick = tick, x = x, z = z, alt = alt, heading = heading })
	end
end

local function applyState(world: World.World, records: { Schema.State }, tick: number)
	for _, r in records do
		local u = world.units[r.unitId]
		if u == nil or u.tier ~= "tactical" then
			world.dropped += 1
			continue
		end
		if r.health then
			u.health = r.health / 255
			-- shown when the render clock reaches it (C-49)
			local log = u.healthLog or {}
			table.insert(log, { tick, u.health :: number })
			u.healthLog = log
		end
		if r.build then
			u.build = r.build / 255
		end
		if r.state then
			u.state = r.state
		end
		if r.weapon then
			u.weapon = r.weapon
		end
		for _, a in r.aim or {} do
			u.aim[a.slot] = { yaw = World.angle(a.yaw), pitch = World.angle(a.pitch) }
		end
		if r.targets then
			local targets = u.targets or {}
			for _, tg in r.targets do
				targets[tg.slot] = tg.targetId
			end
			u.targets = targets
		end
		if r.stock then
			-- own units' missile stockpiles (protocol 15, S-47) and the next
			-- missile's build progress (protocol 17, S-49)
			local stock = u.stock or {}
			local progress = u.stockProgress or {}
			for _, st in r.stock do
				stock[st.slot] = st.count
				progress[st.slot] = { st.progress / 255, tick }
			end
			u.stock = stock
			u.stockProgress = progress
		end
		-- own units' factory queue, fire / move / retreat state (protocol 20,
		-- S-61; retreat 39), self-destruct countdown and work (protocol 39,
		-- S-194): each part on change, all with the ENTER
		if r.queue then
			u.queue = r.queue
			u.queueProgress = (r.queueProgress or 0) / 255
		end
		if r.producing ~= nil then
			-- an allied factory's current item (protocol 27, S-103)
			u.producing = r.producing
			u.producingProgress = (r.producingProgress or 0) / 255
		end
		if r.fireState then
			u.fireState, u.moveState = r.fireState, r.moveState
			u.retreat = r.retreat
		end
		if r.selfDestruct ~= nil then
			u.selfDestruct = r.selfDestruct
			u.selfDestructAt = tick
		end
		if r.workKind ~= nil then
			u.workKind, u.workTarget = r.workKind, r.workTarget
		end
		if r.cargo ~= nil then
			-- a transport's units on board (protocol 43, S-219; C-272): each
			-- one's def as last seen; they're out of the world (a LEAVE each),
			-- so drop them now rather than at the next strategic snapshot
			local defs = table.create(#r.cargo, 0)
			for i, id in r.cargo do
				local c = world.units[id]
				defs[i] = if c then c.defIndex else world.carriedDefs[id] or 0
				if c and c.team == world.me.team and c.id ~= u.id then
					world.carriedDefs[id] = c.defIndex
					world.units[id] = nil
				end
			end
			u.cargo, u.cargoDefs = r.cargo, defs
		end
		if r.flares ~= nil or r.chaff ~= nil then
			u.flares, u.chaff = r.flares, r.chaff -- countermeasure charges left (protocol 21, S-63)
		end
	end
end

local function applyStrategic(world: World.World, records: { Schema.Strategic }, h: Schema.StrategicHeader, tick: number)
	local wireTick = h.tick
	if world.strategicTick >= 0 and wireTick ~= world.strategicTick then
		if not Tick.isNewer(wireTick, world.strategicTick) then
			return -- an older snapshot arrived late
		end
	end
	if wireTick ~= world.strategicTick then
		-- a new snapshot: its records update units as they come (S-212)
		world.strategicTick = wireTick
		table.clear(world.strategicParts)
		table.clear(world.strategicSeen)
		world.strategicGot = 0
	end
	if world.strategicParts[h.part] then
		return -- the same part twice
	end
	world.strategicParts[h.part] = true
	world.strategicGot += 1
	for _, r in records do
		world.strategicSeen[r.unitId] = true
	end
	local g = world.grid
	for _, r in records do
		local u = world.units[r.unitId]
		if u and u.tier == "tactical" then
			continue -- tactical detail wins over a snapshot computed around a LEAVE / ENTER
		end
		-- a wire cell and its offsets' top bits: the 8-stud square's centre (S-189)
		local x, z = g:decode(r.cell, r.offX or 128, r.offZ or 128)
		local old = u
		-- own, allied and seen units keep their type and their last tactical
		-- detail out of the camera area (C-161): still drawn, selectable and
		-- buildable from; and their exact spot while they stay in its 8-stud
		-- square (a strategic record carries only that)
		local typed = r.icon > 0 and bit32.band(r.flags, SF.RADAR_ONLY + SF.SONAR_ONLY + SF.GHOST) == 0
		local keep = if typed and old and old.defIndex == r.icon then old else nil
		if keep then
			-- still in the record's 8-stud square (protocol 38: a wire cell and
			-- its offsets' top 3 bits; a map cell before)
			local kc, kx, kz = g:encode(keep.x, keep.z)
			if kc == r.cell and kx // 32 == (r.offX or 128) // 32 and kz // 32 == (r.offZ or 128) // 32 then
				x, z = keep.x, keep.z
			end
		end
		local movedTick = if old == nil then nil elseif old.x ~= x or old.z ~= z then tick else old.movedTick
		world.units[r.unitId] = {
			id = r.unitId,
			tier = "strategic",
			team = r.team,
			defIndex = if typed then r.icon else nil,
			icon = r.icon,
			flags = r.flags,
			x = x,
			z = z,
			sx = if old and old.tier ~= "tactical" then old.sx else nil, -- the drawn spot carries over (C-151)
			sz = if old and old.tier ~= "tactical" then old.sz else nil,
			gx = if old and old.tier ~= "tactical" then old.gx else nil,
			gz = if old and old.tier ~= "tactical" then old.gz else nil,
			alt = if keep then keep.alt else 0,
			heading = if keep then keep.heading else 0,
			snaps = {},
			lastTick = tick,
			movedTick = movedTick,
			health = if keep then keep.health else nil,
			shownHealth = if keep then keep.shownHealth else nil,
			build = if keep then keep.build else nil,
			state = if keep then keep.state else 0,
			weapon = 0,
			aim = if keep then keep.aim else {},
			queue = if keep then keep.queue else nil,
			queueProgress = if keep then keep.queueProgress else nil,
			fireState = if keep then keep.fireState else nil,
			moveState = if keep then keep.moveState else nil,
			retreat = if keep then keep.retreat else nil,
			selfDestruct = if keep then keep.selfDestruct else nil,
			selfDestructAt = if keep then keep.selfDestructAt else nil,
			workKind = if keep then keep.workKind else nil,
			workTarget = if keep then keep.workTarget else nil,
			cargo = if keep then keep.cargo else nil,
			cargoDefs = if keep then keep.cargoDefs else nil,
			stock = if keep then keep.stock else nil,
		}
		local status = world.ownStatus[r.unitId]
		if status and r.team == world.me.team then
			World.applyStatus(world.units[r.unitId], status) -- what OWN_STATUS said last (S-158)
		end
	end
	if world.strategicGot == h.parts then
		-- every part of it here: the non-tactical units it doesn't list are
		-- gone (S-212). A big snapshot comes in several unreliable parts; with
		-- one lost they stay till the next whole one, so a lost part no longer
		-- makes blips vanish and jump (H36) or drops a far selected unit from
		-- the selection (the user's nuke silo, C-249).
		for id, u in world.units do
			if u.tier ~= "tactical" and not world.strategicSeen[id] then
				world.units[id] = nil
			end
		end
	end
end

local DECODERS: { [string]: any } = {
	Eco = Schema.decodeEco,
	Events = Schema.decodeEvent,
	Tactical = Schema.decodeTactical,
	State = Schema.decodeState,
	Strategic = Schema.decodeStrategic,
	Projectiles = Schema.decodeProjSync,
}

-- Applies one message. `now` is the local clock in seconds (for Interp).
-- Returns false (and drops the message) if it doesn't decode.
function NetIn.apply(world: World.World, channel: string, msg: buffer, now: number): boolean
	if channel == "Snapshot" then
		-- the join handshake: bare records, no tick header
		local ok, records = pcall(Packer.readAll, msg, Schema.decodeSnapshot)
		if not ok then
			world.dropped += 1
			return false
		end
		for _, rec in records :: { Schema.SnapshotRecord } do
			if rec.kind == Schema.SnapshotKind.WELCOME then
				World.welcome(world, rec, now)
			elseif rec.kind == Schema.SnapshotKind.REJECT then
				world.rejected = rec
			end
		end
		return true
	end
	if not world.joined then
		return false -- nothing counts before the WELCOME
	end
	local decode = DECODERS[channel]
	if decode == nil then
		return false
	end
	-- Strategic's header also says which part of its snapshot it is (S-212)
	local ok, records, header = pcall(Packer.readAll, msg, decode, if channel == "Strategic" then Schema.decodeStrategicHeader else Schema.decodeTickHeader)
	if not ok or header == nil then
		world.dropped += 1
		return false
	end
	local wireTick = if channel == "Strategic" then (header :: any).tick else header
	local tick = stamp(world, wireTick :: number, now)
	if channel == "Events" then
		applyEvents(world, records :: any, tick)
	elseif channel == "Eco" then
		-- protocol 9 (S-21): records carry their team; a player gets only its
		-- own, a spectator every team's: keep the own team's
		local own = (records :: any)[1]
		for _, r in records :: any do
			world.teamEco[r.team] = r -- allies' too, when sent (F23)
			if r.team == world.me.team then
				own = r
			end
		end
		world.economy = own
	elseif channel == "Tactical" then
		applyTactical(world, records :: any, tick)
	elseif channel == "State" then
		applyState(world, records :: any, tick)
	elseif channel == "Strategic" then
		applyStrategic(world, records :: any, header :: any, tick)
	elseif channel == "Projectiles" then
		for _, r in records :: any do
			(r :: any).kind = 0 -- homing correction, handled with the combat events
			queueEvent(world, r, tick)
		end
	end
	return true
end

-- Applies a whole outbox (channel → messages) in the server's send order.
-- Lune specs use this; the Roblox client gets the same messages one by one.
NetIn.ORDER = table.freeze({ "Snapshot", "Events", "Tactical", "State", "Projectiles", "Strategic", "Eco" })

-- The HELLO a client sends first (net.md section 10).
function NetIn.hello(defsHash: number): buffer
	local w = Packer.Writer.new(8)
	Schema.encodeSnapshot(w, { kind = Schema.SnapshotKind.HELLO, protocol = Schema.PROTOCOL_VERSION, defsHash = defsHash })
	return w:finish()
end

function NetIn.applyOutbox(world: World.World, outbox: { [string]: { buffer } }, now: number)
	for _, channel in NetIn.ORDER do
		for _, msg in outbox[channel] or {} do
			NetIn.apply(world, channel, msg, now)
		end
	end
end

-- Is a weapon slot's state READY (net.md section 3)?
function NetIn.weaponReady(unit: World.Unit, slot: number): boolean
	return Schema.weaponStateAt(unit.weapon, slot) == Schema.WeaponState.READY
end

return NetIn
