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

local Ballistics = require("../../Sim/Combat/Ballistics")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
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
}

export type Projectile = {
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	weaponIndex: number,
	target: number, -- 0 = none
	ttl: number, -- seconds left
}

-- A visual effect: a tracer (fire: from the shooter to the end point), an
-- explosion (impact), a decoyed missile (decoy) or a unit's death (death).
export type Effect = { kind: "fire" | "impact" | "decoy" | "lost" | "death", x: number, y: number, z: number, fromX: number?, fromZ: number? }

export type View = {
	grid: Grid.Grid,
	defs: Defs.DefSet,
	units: { [number]: Unit },
	projectiles: { [number]: Projectile },
	effects: { Effect },
	strategicTick: number, -- wire tick of the current strategic snapshot
	received: { [number]: boolean }, -- every unit ID ever mentioned
	log: { { channel: string, ids: { number } } }, -- this tick's mentions, for checks
}

function Client.new(grid: Grid.Grid, defs: Defs.DefSet?): View
	return {
		grid = grid,
		defs = defs or Defs.load(),
		units = {},
		projectiles = {},
		effects = {},
		strategicTick = -1,
		received = {},
		log = {},
	}
end

-- The server's time to live, plus a tick: the server's own expiry sends an
-- IMPACT, so this is only a fallback.
local function ttlOf(weapon: Defs.WeaponDef): number
	if weapon.type == "BOMB" then
		return 8 + DT
	end
	return 2 * weapon.range / math.max(weapon.projectileSpeed or 1, 1) + 1 + DT
end

-- One tick of every known projectile: steer (homing, toward the target's
-- last known position: its altitude when the client has it, else level),
-- then the server's ballistic step. The server leads the target and knows
-- its true position, so homing missiles drift; IMPACT always wins.
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
			local dx, dy, dz = target.x - p.x, (if target.alt then target.alt - p.y else 0), target.z - p.z
			local speed = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz)
			local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
			if speed > 1e-6 and dl > 1e-6 then
				-- turn the velocity toward the target by at most turnRate (as the server)
				local ax, ay, az = p.vx / speed, p.vy / speed, p.vz / speed
				local bx, by, bz = dx / dl, dy / dl, dz / dl
				local angle = math.acos(math.clamp(ax * bx + ay * by + az * bz, -1, 1))
				local maxAngle = math.rad(weapon.turnRate) * DT
				local k = if angle <= maxAngle then 1 else maxAngle / angle
				local nx, ny, nz = ax + (bx - ax) * k, ay + (by - ay) * k, az + (bz - az) * k
				local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
				if nl > 1e-9 then
					p.vx, p.vy, p.vz = nx / nl * speed, ny / nl * speed, nz / nl * speed
				end
			end
		end
		p.x, p.y, p.z, p.vx, p.vy, p.vz = Ballistics.step(p.x, p.y, p.z, p.vx, p.vy, p.vz, weapon.gravity or 0, DT)
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
	advance(view)
	local g = view.grid
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
			if kind == EK.SPAWN_PROJ then
				local x, y, z = pos(e)
				local vx, vy, vz = vel(e)
				local weapon = view.defs.weaponByIndex[e.weaponIndex :: number]
				assert(weapon, `SPAWN_PROJ with unknown weapon {e.weaponIndex}`)
				local target = e.targetId :: number -- a unit the ally team knows; its strategic record may come later
				view.projectiles[e.projId :: number] = { x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, weaponIndex = weapon.index, target = target, ttl = ttlOf(weapon) }
				continue
			elseif kind == EK.IMPACT then
				local x, y, z = pos(e)
				view.projectiles[e.projId :: number] = nil
				table.insert(view.effects, { kind = "impact", x = x, y = y, z = z })
				continue
			elseif kind == EK.DECOYED or kind == EK.LOST_LOCK then
				local p = view.projectiles[e.projId :: number]
				assert(p, `DECOYED / LOST_LOCK for projectile {e.projId} the client doesn't have`)
				p.x, p.y, p.z = pos(e)
				p.vx, p.vy, p.vz = vel(e)
				p.target = 0
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
	for _, msg in outbox.Tactical do
		local records = Packer.readAll(msg, Schema.decodeTactical, Schema.decodeTickHeader)
		local ids = {}
		for _, r in records do
			table.insert(ids, r.unitId)
			local u = view.units[r.unitId]
			assert(u and u.tier == "tactical", `tactical record for unit {r.unitId} that never entered`)
			u.x, u.z = g:decode(r.cell, r.offX, r.offZ)
			u.alt = r.alt or 0
			u.heading = r.heading
		end
		mention(view, "Tactical", ids)
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
