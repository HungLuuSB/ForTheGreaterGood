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
			local u = world.units[e.unitId :: number]
			if u and u.tier == "tactical" then
				u.tier = "strategic" -- refreshed or dropped by the next strategic snapshot
				table.clear(u.snaps)
				u.rx, u.ry, u.rz = nil, nil, nil -- no longer drawn
				table.insert(world.left, u.id)
			end
		elseif kind == EK.DEATH then
			local id = e.unitId :: number
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
