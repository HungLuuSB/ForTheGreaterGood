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
		elseif kind == EK.LEAVE then
			world.shields[e.unitId :: number] = nil -- its dome is sent again on the next ENTER
			local u = world.units[e.unitId :: number]
			if u and u.tier == "tactical" then
				u.tier = "strategic" -- refreshed or dropped by the next strategic snapshot
				table.clear(u.snaps)
				u.rx, u.ry, u.rz = nil, nil, nil -- no longer drawn
				table.insert(world.left, u.id)
			end
		elseif kind == EK.DEATH then
			local id = e.unitId :: number
			world.shields[id] = nil
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
				local index = bit32.band(c, 0x7FFF)
				if index < n then
					buffer.writeu8(s.cells, index, if bit32.band(c, Schema.SIGHT_SEEN) ~= 0 then 1 else 0)
					table.insert(s.changed, index)
				end
			end
			s.version += 1
		elseif kind == EK.WRECK then
			local x, z = world.grid:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
			local id = e.wreckId :: number
			world.wrecks[id] = { id = id, defIndex = e.defIndex :: number, x = x, z = z, heading = World.heading(e.heading or 0) }
			table.insert(world.wreckAdded, id)
		elseif kind == EK.ALERT then
			-- the owner's alerts (protocol 23, S-68); stalls carry cell 0
			local x, z = g:decode(e.cell :: number, 128, 128)
			table.insert(world.alertQueue, { kind = e.alert :: number, x = x, z = z, defIndex = e.defIndex or 0, tick = tick })
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
		-- own units' factory queue, fire / move state and ammo (protocol 20,
		-- S-61): each part on change, all with the ENTER
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
		end
		if r.ammo then
			u.ammo, u.maxAmmo = r.ammo, r.maxAmmo
		end
		if r.flares ~= nil or r.chaff ~= nil then
			u.flares, u.chaff = r.flares, r.chaff -- countermeasure charges left (protocol 21, S-63)
		end
	end
end

local function applyStrategic(world: World.World, records: { Schema.Strategic }, wireTick: number, tick: number)
	if world.strategicTick >= 0 and wireTick ~= world.strategicTick then
		if not Tick.isNewer(wireTick, world.strategicTick) then
			return -- an older snapshot arrived late
		end
	end
	local before: { [number]: World.Unit } = {}
	if wireTick ~= world.strategicTick then
		-- a new snapshot replaces every non-tactical unit
		world.strategicTick = wireTick
		for id, u in world.units do
			if u.tier ~= "tactical" then
				before[id] = u
				world.units[id] = nil
			end
		end
	end
	local g = world.grid
	for _, r in records do
		local u = world.units[r.unitId]
		if u and u.tier == "tactical" then
			continue -- tactical detail wins over a snapshot computed around a LEAVE / ENTER
		end
		local x, z = g:decode(r.cell, 128, 128)
		local old = before[r.unitId] or u
		local movedTick = if old == nil then nil elseif old.x ~= x or old.z ~= z then tick else old.movedTick
		world.units[r.unitId] = {
			id = r.unitId,
			tier = "strategic",
			team = r.team,
			defIndex = nil,
			icon = r.icon,
			flags = r.flags,
			x = x,
			z = z,
			sx = if old and old.tier ~= "tactical" then old.sx else nil, -- the drawn spot carries over (C-151)
			sz = if old and old.tier ~= "tactical" then old.sz else nil,
			alt = 0,
			heading = 0,
			snaps = {},
			lastTick = tick,
			movedTick = movedTick,
			health = nil,
			build = nil,
			state = 0,
			weapon = 0,
			aim = {},
		}
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
	local ok, records, wireTick = pcall(Packer.readAll, msg, decode, Schema.decodeTickHeader)
	if not ok or wireTick == nil then
		world.dropped += 1
		return false
	end
	local tick = stamp(world, wireTick :: number, now)
	if channel == "Events" then
		applyEvents(world, records :: any, tick)
	elseif channel == "Eco" then
		-- protocol 9 (S-21): records carry their team; a player gets only its
		-- own, a spectator every team's: keep the own team's
		local own = (records :: any)[1]
		for _, r in records :: any do
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
		applyStrategic(world, records :: any, wireTick :: number, tick)
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
