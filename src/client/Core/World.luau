--!strict
-- The client's table of known units (guide 15.1): every unit the server told
-- this player about, in both tiers. Pure data, no Instances (C-7): NetIn
-- fills it from packets, Interp samples it, the renderer drains its queues.
--
-- Wire conventions: docs/contracts/net.md (protocol 5).

local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Schema = require("@shared/Net/Schema")

local World = {}

World.MAX_SNAPS = 4 -- per unit (guide 7.4: 3–4)
World.MAX_QUEUED_EVENTS = 1024 -- combat events kept until the renderer drains them

-- Unit state bits (net.md section 3), shared with the sim (S-6).
World.State = Schema.UnitState

export type Snap = { tick: number, x: number, z: number, alt: number, heading: number }

export type Aim = { yaw: number, pitch: number } -- radians; yaw relative to the hull

export type Unit = {
	id: number,
	tier: "tactical" | "strategic",
	team: number,
	defIndex: number?, -- tactical units (and strategic ones once the icon maps to a def later)
	icon: number?, -- strategic records: 0 = unknown blip
	flags: number?, -- strategic records: Schema.StrategicFlag
	-- latest known values
	x: number,
	z: number,
	alt: number,
	heading: number, -- radians, (sin h, cos h) forward
	snaps: { Snap }, -- tactical: ascending sim ticks
	lastTick: number, -- sim tick of the last position applied (drops reordered unreliable records)
	health: number?, -- 0..1
	build: number?, -- 0..1
	state: number,
	weapon: number, -- Schema weapon state field
	aim: { [number]: Aim }, -- by weapon slot
	-- where the renderer drew it this frame (ground + altitude for ry); nil when not drawn
	rx: number?,
	ry: number?,
	rz: number?,
}

-- A tactical unit that died: the renderer plays its death and drops the model.
export type Death = { id: number, defIndex: number?, team: number, x: number, z: number, heading: number, severity: number, wreckId: number }

export type Me = { player: number, team: number, allyTeam: number }

export type World = {
	grid: Grid.Grid,
	layers: Layers.Layers?,
	mapId: string?,
	mapVersion: number, -- bumps when WELCOME brings another map (the renderer rebuilds the ground)
	defs: Defs.DefSet,
	me: Me,
	joined: boolean, -- a WELCOME arrived; everything else is dropped before it
	joins: number, -- WELCOMEs received (the renderer starts over on a change)
	rejected: Schema.SnapshotRecord?, -- the server's REJECT: stale client
	economy: Schema.Eco?, -- own team's account (Eco channel)
	units: { [number]: Unit },
	latestTick: number, -- newest sim tick seen on any channel, -1 before the first
	latestAt: number, -- local time (seconds) when latestTick arrived
	strategicTick: number, -- wire tick of the current strategic snapshot, -1 none
	-- queues the renderer drains each frame
	entered: { number }, -- became tactical (ENTER)
	left: { number }, -- stopped being tactical without dying (LEAVE)
	died: { Death },
	events: { Schema.Event }, -- combat events (FIRE, SPAWN_PROJ, IMPACT, DECOYED, LOST_LOCK) with `tick`
	dropped: number, -- records dropped as out of sync or malformed (diagnostics)
}

-- An empty world waiting for the server's WELCOME (net.md section 10).
function World.new(defs: Defs.DefSet): World
	return {
		grid = Grid.new(1, 1), -- replaced by the WELCOME's map
		layers = nil,
		mapId = nil,
		mapVersion = 0,
		defs = defs,
		me = { player = 0, team = 0, allyTeam = 0 },
		joined = false,
		joins = 0,
		rejected = nil,
		economy = nil,
		units = {},
		latestTick = -1,
		latestAt = 0,
		strategicTick = -1,
		entered = {},
		left = {},
		died = {},
		events = {},
		dropped = 0,
	}
end

-- Applies a WELCOME: who we are, the map, the full sim tick. Drops
-- everything known before (a join or reconnect rebuilds the whole view).
function World.welcome(world: World, rec: Schema.SnapshotRecord, now: number)
	local mapId = rec.mapId :: string
	if mapId ~= world.mapId then
		local layers = MapRegistry.load(mapId)
		world.layers = layers
		world.grid = if layers then layers.grid else Grid.new(1, 1)
		world.mapId = mapId
		world.mapVersion += 1
	end
	world.me = { player = rec.player :: number, team = rec.team :: number, allyTeam = rec.allyTeam :: number }
	table.clear(world.units)
	table.clear(world.entered)
	table.clear(world.left)
	table.clear(world.died)
	table.clear(world.events)
	world.strategicTick = -1
	world.economy = nil
	world.latestTick = rec.tick :: number -- unwraps wire ticks from here on
	world.latestAt = now
	world.joined = true
	world.joins += 1
end

-- Wire heading u8 → radians.
function World.heading(v: number): number
	return v / 256 * 2 * math.pi
end

-- Wire aim angle u8 → radians in [-π, π].
function World.angle(v: number): number
	return v / 255 * 2 * math.pi - math.pi
end

function World.relation(world: World, unit: Unit): "own" | "ally" | "enemy"
	if unit.team == world.me.team then
		return "own"
	end
	-- ally teams aren't on the wire yet (protocol 6 WELCOME); only own team counts as allied
	return "enemy"
end

-- Ground height (studs) under a world position: the cell's height, plus its
-- water depth for units that float.
function World.groundY(world: World, x: number, z: number, floats: boolean?): number
	local layers = world.layers
	if layers == nil then
		return 0
	end
	local g = world.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	local index = g:index(cx, cz)
	local y = Layers.getHeight(layers, index)
	if floats then
		y += Layers.getWater(layers, index)
	end
	return y
end

function World.def(world: World, unit: Unit): Defs.UnitDef?
	return if unit.defIndex then world.defs.unitByIndex[unit.defIndex] else nil
end

-- Units the local player owns, sorted by ID.
function World.ownIds(world: World): { number }
	local out = {}
	for id, u in world.units do
		if u.team == world.me.team and u.tier == "tactical" then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

return World
