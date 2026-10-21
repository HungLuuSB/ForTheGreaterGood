--!strict
-- A headless "client" for tests: decodes one player's messages and rebuilds
-- its view of the world, the way the Roblox client will (guide 7.4, 15.1).
-- It only ever learns what the server sent.
--
-- Projectiles (D99): SPAWN_PROJ gives a position and velocity; the client
-- steps each projectile itself every tick (the server's ballistic step,
-- steering toward its homing target while the client has that unit, at
-- its tactical or strategic position) and drops it on IMPACT (or after its
-- time to live, as a fallback). FIRE, IMPACT, DECOYED, LOST_LOCK and
-- DEATH also leave visual effects in `effects` until the caller clears
-- them.

local Ballistics = require("@shared/Combat/Ballistics")
local Guidance = require("@shared/Combat/Guidance")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local EK = Schema.EventKind

local Client = {}

export type Unit = {
	tier: "tactical" | "strategic",
	team: number,
	defIndex: number?, -- tactical units only
	icon: number?, -- strategic records
	flags: number?, -- strategic records
	x: number,
	z: number,
	alt: number?, -- tactical units: altitude above the ground (studs)
	heading: number?,
	health: number?,
	build: number?,
	state: number?,
	targets: { [number]: number }?, -- own units: weapon slot → target ID (0 = none; S-16)
	stock: { [number]: number }?, -- own units: weapon slot → missiles in stock (S-47)
	vx: number?, -- tactical units: velocity estimated from the last two Tactical records (studs/s; S-27)
	vz: number?,
	movedAt: number?, -- view.tick of the last Tactical record
}

export type Projectile = {
	x: number, -- the client's own prediction (snapped to corrections)
	y: number,
	z: number,
	ox: number, -- drawn position = prediction + offset; the offset decays
	oy: number, -- to 0 over BLEND_TICKS after a correction (D102)
	oz: number,
	blend: number, -- ticks of blending left
	vx: number,
	vy: number,
	vz: number,
	weaponIndex: number,
	target: number, -- 0 = none
	targetProj: number?, -- interceptors: the strategic missile (projectile ID) they chase (S-48)
	ttl: number, -- seconds left
	decoy: { number }?, -- decoyed: { x, y, z, ticks left } of the point it follows (S-28)
	countermeasure: number?, -- decoyed: what defeated it (Schema.Countermeasure, S-38)
	turned: boolean?, -- vertical launches: pitched over yet (Guidance.vertical, S-42)
}

-- A visual effect: a tracer (fire: from the shooter to the end point), an
-- explosion (impact), a decoyed missile (decoy) or a unit's death (death).
export type Effect = { kind: "fire" | "impact" | "decoy" | "lost" | "death" | "intercepted", x: number, y: number, z: number, fromX: number?, fromZ: number? }

export type View = {
	grid: Grid.Grid,
	layers: Layers.Layers?, -- the map's layers when the caller gives them: the vertical-launch climb needs the ground height (S-44)
	defs: Defs.DefSet,
	units: { [number]: Unit },
	projectiles: { [number]: Projectile },
	effects: { Effect },
	warnings: { { projId: number, x: number, z: number } }, -- LAUNCH_WARNING records (S-48)
	economy: Schema.Eco?, -- own team's account, from the Eco channel (S-2)
	economies: { [number]: Schema.Eco }, -- every team's account the client got: a spectator's are all teams (S-21)
	welcome: Schema.SnapshotRecord?, -- the last WELCOME (who we are, the map, the full tick)
	rejected: Schema.SnapshotRecord?, -- a REJECT: the server's versions
	strategicTick: number, -- wire tick of the current strategic snapshot
	received: { [number]: boolean }, -- every unit ID ever mentioned
	log: { { channel: string, ids: { number } } }, -- this tick's mentions, for checks
	wrecks: { [number]: Wreck }, -- wrecks the team knows (S-26)
	sight: buffer?, -- the ally team's sight, one byte (0 / 1) per sensor cell; nil until the first SIGHT_ROWS (S-26)
	tick: number, -- receive calls so far
}

export type Wreck = { defIndex: number, x: number, z: number, heading: number }

Client.BLEND_TICKS = 5 -- a correction is blended in over this many ticks
Client.SNAP_STUDS = 60 -- larger errors snap: they only happen when a projectile comes back into view

-- Where the client draws projectile `p`.
function Client.drawn(p: Projectile): (number, number, number)
	return p.x + p.ox, p.y + p.oy, p.z + p.oz
end

function Client.new(grid: Grid.Grid, defs: Defs.DefSet?, layers: Layers.Layers?): View
	return {
		grid = grid,
		layers = layers,
		defs = defs or Defs.load(),
		units = {},
		projectiles = {},
		effects = {},
		warnings = {},
		strategicTick = -1,
		received = {},
		log = {},
		economies = {},
		wrecks = {},
		sight = nil,
		tick = 0,
	}
end

-- Whether the client's team sees world point x, z (from the sight records).
function Client.inSight(view: View, x: number, z: number): boolean
	local sight = view.sight
	if sight == nil then
		return false
	end
	local sx, sz = view.grid:sensorCellAt(x, z)
	return buffer.readu8(sight, sz * view.grid.sensorX + sx) == 1
end

-- The server's time to live, plus a tick: the server's own expiry sends an
-- IMPACT, so this is only a fallback.
local function ttlOf(weapon: Defs.WeaponDef): number
	if weapon.type == "BOMB" then
		return 8 + DT
	end
	return 2 * weapon.range / math.max(weapon.projectileSpeed or 1, 1) + 1 + DT
end

-- One tick of every known projectile: steer with the server's guidance
-- (Shared/Combat/Guidance: missiles proportional navigation, torpedoes lead
-- pursuit; S-27) against the target's last known position, which is where
-- it was when this tick's step starts, and its estimated velocity (its
-- altitude when the client has it, else level), then the server's
-- ballistic step. The client doesn't know a contact's true position, so
-- homing missiles still drift; corrections and IMPACT fix it.
local function advance(view: View)
	for id, p in view.projectiles do
		p.ttl -= DT
		if p.ttl <= 0 then
			view.projectiles[id] = nil
			continue
		end
		local weapon = view.defs.weaponByIndex[p.weaponIndex]
		local target = view.units[p.target]
		if weapon.turnRate and target then
			local ty = target.alt or p.y
			local tvx, tvz = target.vx or 0, target.vz or 0
			local maxTurn = math.rad(weapon.turnRate) * DT
			if weapon.type == "HOMING" and weapon.launch == "vertical" then
				local turned
				local layers = view.layers
				local climbLeft = if layers then Guidance.climbLeft(weapon, p.y, Layers.heightAt(layers, p.x, p.z)) else nil
				p.vx, p.vy, p.vz, turned = Guidance.vertical(p.x, p.y, p.z, p.vx, p.vy, p.vz, target.x, ty, target.z, tvx, 0, tvz, maxTurn, DT, p.turned == true, climbLeft)
				p.turned = turned
			elseif weapon.type == "HOMING" then
				p.vx, p.vy, p.vz = Guidance.pn(p.x, p.y, p.z, p.vx, p.vy, p.vz, target.x, ty, target.z, tvx, 0, tvz, maxTurn, DT)
			else
				p.vx, p.vy, p.vz = Guidance.lead(p.x, p.y, p.z, p.vx, p.vy, p.vz, target.x, ty, target.z, tvx, tvz, maxTurn)
			end
		elseif p.decoy and weapon.turnRate then
			-- decoyed: follow the flare or chaff like the server (S-28)
			local d = p.decoy :: { number }
			local follow
			p.vx, p.vy, p.vz, follow = Guidance.decoy(p.x, p.y, p.z, p.vx, p.vy, p.vz, d[1], d[2], d[3], math.rad(weapon.turnRate) * DT, Guidance.seekerAngle(weapon) :: number)
			d[4] -= 1
			if not follow or d[4] <= 0 then
				p.decoy = nil
			end
		end
		p.x, p.y, p.z, p.vx, p.vy, p.vz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, weapon.gravity or 0, DT)
		if p.blend > 0 then
			local k = 1 / p.blend
			p.ox, p.oy, p.oz = p.ox * (1 - k), p.oy * (1 - k), p.oz * (1 - k)
			p.blend -= 1
		end
	end
end

local function mention(view: View, channel: string, ids: { number })
	for _, id in ids do
		view.received[id] = true
	end
	table.insert(view.log, { channel = channel, ids = ids })
end

-- Applies every message the server put in this player's outbox this tick
-- (call it every tick: it also advances the known projectiles one tick).
function Client.receive(view: View, outbox: { [string]: { buffer } })
	table.clear(view.log)
	view.tick += 1
	-- join handshake first: a WELCOME starts over from an empty view (S-2)
	for _, msg in outbox.Snapshot or {} do
		for _, rec in (Packer.readAll(msg, Schema.decodeSnapshot)) do
			if rec.kind == Schema.SnapshotKind.WELCOME then
				view.welcome = rec
				table.clear(view.units)
				table.clear(view.projectiles)
				table.clear(view.effects)
				view.strategicTick = -1
				view.economy = nil
				table.clear(view.economies)
				table.clear(view.wrecks)
				view.sight = nil
			elseif rec.kind == Schema.SnapshotKind.REJECT then
				view.rejected = rec
			end
		end
	end
	advance(view)
	local g = view.grid
	for _, msg in outbox.Eco or {} do
		for _, rec in (Packer.readAll(msg, Schema.decodeEco, Schema.decodeTickHeader)) do
			view.economies[rec.team] = rec
			local wl = view.welcome
			if wl == nil or wl.team == rec.team then
				view.economy = rec -- our own team's
			end
		end
	end
	local function pos(e: Schema.Event): (number, number, number)
		local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
		return x, (e.y :: number) / Schema.Y_SCALE, z
	end
	local function vel(e: Schema.Event): (number, number, number)
		return (e.vx :: number) / Schema.Y_SCALE, (e.vy :: number) / Schema.Y_SCALE, (e.vz :: number) / Schema.Y_SCALE
	end
	for _, msg in outbox.Events do
		local events = Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)
		local ids, leaves = {}, {}
		for _, e in events do
			local kind = e.kind
			if kind == EK.SPAWN_PROJ or kind == EK.INTERCEPTOR then
				local x, y, z = pos(e)
				local vx, vy, vz = vel(e)
				local weapon = view.defs.weaponByIndex[e.weaponIndex :: number]
				assert(weapon, `SPAWN_PROJ with unknown weapon {e.weaponIndex}`)
				-- a unit the ally team knows (its strategic record may come later);
				-- INTERCEPTOR: a projectile (S-48)
				local interceptor = kind == EK.INTERCEPTOR
				local target = if interceptor then 0 else e.targetId :: number
				view.projectiles[e.projId :: number] = {
					x = x,
					y = y,
					z = z,
					ox = 0,
					oy = 0,
					oz = 0,
					blend = 0,
					vx = vx,
					vy = vy,
					vz = vz,
					weaponIndex = weapon.index,
					target = target,
					targetProj = if interceptor then e.targetId :: number else nil,
					ttl = ttlOf(weapon),
				}
				continue
			elseif kind == EK.LAUNCH_WARNING then
				local x, _, z = pos(e)
				table.insert(view.warnings, { projId = e.projId :: number, x = x, z = z })
				continue
			elseif kind == EK.INTERCEPTED then
				local x, y, z = pos(e)
				view.projectiles[e.projId :: number] = nil
				table.insert(view.effects, { kind = "intercepted", x = x, y = y, z = z })
				continue
			elseif kind == EK.IMPACT then
				local x, y, z = pos(e)
				view.projectiles[e.projId :: number] = nil
				table.insert(view.effects, { kind = "impact", x = x, y = y, z = z })
				continue
			elseif kind == EK.SHOT then
				-- a hidden shooter's shot: a tracer between the two ends (S-43)
				local x, y, z = pos(e)
				local fx, fz = g:decode(e.fromCell :: number, e.fromOffX :: number, e.fromOffZ :: number)
				table.insert(view.effects, { kind = "fire", x = x, y = y, z = z, fromX = fx, fromZ = fz })
				continue
			elseif kind == EK.WRECK then
				local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
				assert(view.wrecks[e.wreckId :: number] == nil, `WRECK {e.wreckId} the client already has`)
				view.wrecks[e.wreckId :: number] = { defIndex = e.defIndex :: number, x = x, z = z, heading = e.heading :: number }
				continue
			elseif kind == EK.WRECK_GONE then
				assert(view.wrecks[e.wreckId :: number] ~= nil, `WRECK_GONE for wreck {e.wreckId} the client doesn't have`)
				view.wrecks[e.wreckId :: number] = nil
				continue
			elseif kind == EK.SIGHT_ROWS then
				local width = g.sensorX
				local sight = view.sight or buffer.create(width * g.sensorZ)
				view.sight = sight
				local bits, rowBytes = e.bits :: buffer, e.rowBytes :: number
				for r = 0, (e.rowCount :: number) - 1 do
					local row = (e.firstRow :: number) + r
					for x = 0, width - 1 do
						local b = buffer.readu8(bits, r * rowBytes + x // 8)
						buffer.writeu8(sight, row * width + x, bit32.extract(b, x % 8))
					end
				end
				continue
			elseif kind == EK.SIGHT_CELLS then
				local sight = view.sight
				assert(sight, "SIGHT_CELLS before any SIGHT_ROWS")
				for _, c in e.cells :: { number } do
					buffer.writeu8(sight, c % Schema.SIGHT_SEEN, if c >= Schema.SIGHT_SEEN then 1 else 0)
				end
				continue
			elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
				local p = view.projectiles[e.projId :: number]
				assert(p, `DECOYED / LOST_LOCK for projectile {e.projId} the client doesn't have`)
				p.x, p.y, p.z = pos(e)
				p.vx, p.vy, p.vz = vel(e)
				p.target = 0
				p.countermeasure = e.countermeasure
				if kind == EK.DECOYED and (e.decoyTicks :: number) > 0 then
					local dx, dz = g:decode(e.decoyCell :: number, e.decoyOffX :: number, e.decoyOffZ :: number)
					p.decoy = { dx, (e.decoyY :: number) / Schema.Y_SCALE, dz, e.decoyTicks :: number }
				else
					p.decoy = nil
				end
				table.insert(view.effects, { kind = if kind == EK.DECOYED then "decoy" else "lost", x = p.x, y = p.y, z = p.z })
				continue
			end
			local unitId = e.unitId :: number
			if kind == EK.FIRE then
				local shooter = view.units[unitId]
				assert(shooter and shooter.tier == "tactical", `FIRE from unit {unitId} that isn't tactical`)
				local x, y, z = pos(e)
				table.insert(view.effects, { kind = "fire", x = x, y = y, z = z, fromX = shooter.x, fromZ = shooter.z })
				table.insert(ids, unitId)
				continue
			end
			if kind == EK.LEAVE then
				-- LEAVE carries no information: the client already had the unit
				assert(view.units[unitId] ~= nil, `LEAVE for unit {unitId} the client never had`)
				table.insert(leaves, unitId)
			else
				table.insert(ids, unitId)
			end
			if kind == EK.ENTER then
				local x, z = g:decode(e.cell :: number, e.offX :: number, e.offZ :: number)
				view.units[unitId] = {
					tier = "tactical",
					team = e.team :: number,
					defIndex = e.defIndex,
					x = x,
					z = z,
					alt = e.alt,
					heading = e.heading,
					health = e.health,
					build = e.build,
					state = e.state,
				}
			elseif kind == EK.LEAVE then
				local u = view.units[unitId]
				if u then
					u.tier = "strategic" -- refreshed or dropped by the next strategic snapshot
				end
			else -- DEATH
				local u = view.units[unitId]
				if u then
					table.insert(view.effects, { kind = "death", x = u.x, y = 0, z = u.z })
				end
				view.units[unitId] = nil
			end
		end
		mention(view, "Events", ids)
		mention(view, "Leave", leaves)
	end
	-- homing corrections (unreliable: any of them may be missing): snap the
	-- prediction, keep drawing where it was and blend the gap away
	for _, msg in outbox.Projectiles or {} do
		for _, r in (Packer.readAll(msg, Schema.decodeProjSync, Schema.decodeTickHeader)) do
			local p = view.projectiles[r.projId]
			if p then
				local dx, dy, dz = Client.drawn(p)
				local x, z = g:decode(r.cell, r.offX, r.offZ)
				p.x, p.y, p.z = x, r.y / Schema.Y_SCALE, z
				p.vx, p.vy, p.vz = r.vx / Schema.Y_SCALE, r.vy / Schema.Y_SCALE, r.vz / Schema.Y_SCALE
				p.ox, p.oy, p.oz = dx - p.x, dy - p.y, dz - p.z
				p.blend = Client.BLEND_TICKS
				if p.ox * p.ox + p.oy * p.oy + p.oz * p.oz > Client.SNAP_STUDS ^ 2 then
					p.ox, p.oy, p.oz, p.blend = 0, 0, 0, 0
				end
			end
		end
	end
	for _, msg in outbox.Tactical do
		local records = Packer.readAll(msg, Schema.decodeTactical, Schema.decodeTickHeader)
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local u = view.units[r.unitId]
			assert(u and u.tier == "tactical", `tactical record for unit {r.unitId} that never entered`)
			local x, z = g:decode(r.cell, r.offX, r.offZ)
			local dt = (view.tick - (u.movedAt or view.tick - 1)) * DT
			u.vx, u.vz = (x - u.x) / dt, (z - u.z) / dt
			u.x, u.z, u.movedAt = x, z, view.tick
			u.alt = r.alt or 0
			u.heading = r.heading
		end
		mention(view, "Tactical", ids)
	end
	for _, u in view.units do
		if u.movedAt ~= nil and u.movedAt ~= view.tick then
			u.vx, u.vz = 0, 0 -- no record: it didn't move
		end
	end
	for _, msg in outbox.State do
		local records = Packer.readAll(msg, Schema.decodeState, Schema.decodeTickHeader)
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local u = view.units[r.unitId]
			assert(u and u.tier == "tactical", `state record for unit {r.unitId} that never entered`)
			u.health = r.health or u.health
			u.build = r.build or u.build
			u.state = r.state or u.state
			if r.targets then
				local t = u.targets or {}
				for _, tg in r.targets do
					t[tg.slot] = tg.targetId
				end
				u.targets = t
			end
			if r.stock then
				local st = u.stock or {}
				for _, s in r.stock do
					st[s.slot] = s.count
				end
				u.stock = st
			end
		end
		mention(view, "State", ids)
	end
	for _, msg in outbox.Strategic do
		local records, tick = Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeTickHeader)
		if tick ~= view.strategicTick then
			-- a new snapshot replaces every non-tactical unit
			view.strategicTick = tick :: number
			for id, u in view.units do
				if u.tier ~= "tactical" then
					view.units[id] = nil
				end
			end
		end
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local x, z = g:decode(r.cell, 128, 128) -- cell center
			view.units[r.unitId] = { tier = "strategic", team = r.team, icon = r.icon, flags = r.flags, x = x, z = z }
		end
		mention(view, "Strategic", ids)
	end
end

return Client
