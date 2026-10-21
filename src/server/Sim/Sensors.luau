--!strict
-- Sensor maps and visibility (guide 11.1–11.3).
--
-- Per ally team, on the 16-stud sensor grid, six count maps (u16 per cell):
--   los     sight of every unit                    airLos  sight against aircraft
--   radar   radar emitters                         sonar   sonar emitters
--   jam     this team's jammers (hide this team from enemy radar)
--   track   fire-control (tracking) radars (D104)
-- An emitter stamps +1 on every sensor cell whose center lies within its
-- radius of the emitter's cell center (circles cached per radius as row
-- spans), and only re-stamps when it changes sensor cell. Unfinished
-- structures don't emit. Counts are u16 (not the guide's u8): a dense blob
-- of units can put more than 255 emitters on one cell.
--
-- Re-stamping cost (DECISIONS D85):
--   * a unit moving to a neighboring sensor cell shifts its circles: only
--     the cells entering and leaving each circle change, O(radius) instead
--     of O(radius²);
--   * full stamps (new emitters, jumps of more than one cell, team or radius
--     changes) are budgeted at STAMP_BUDGET cells per sensor tick, in ids
--     order. A unit over budget keeps its previous stamp (or none, if new)
--     until a later sensor tick. Removals are never deferred.
--
-- Visibility of each enemy unit for each team is recomputed on every
-- sensor tick (every 2nd tick) from the maps: O(units × teams) buffer reads.
-- Levels: VISIBLE (in los, or airLos for aircraft) > GHOST (a structure seen
-- before, now out of sight) > RADAR / SONAR > HIDDEN. Submerged units are
-- only ever SONAR or HIDDEN: SONAR inside the team's sonar map, or within
-- CLOSE_SONAR studs (exact distance) of one of its naval units or ASW
-- helicopters (helicopters with a weapon that can target SUB). Nothing else
-- finds them. Jamming and stealth refine RADAR (guide 11.4).
--
-- Tracking (D104): an enemy unit the team's radar detects (in its radar
-- map, not jammed, passing the stealth check) inside its track map is
-- TRACKED (`tracked`, Sensors.isTracked): as a radar contact it wobbles by
-- the team's best trackError instead of its radarError, and its type is
-- known. Jamming hides from tracking radar too, with no burn-through.
-- Tracking radars drain trackDrain power per second, jammers jamDrain
-- (Sensors.drainStep, an economy consumer; D104, D108). Their track and jam
-- radii scale with the share of that power they get, in whole sensor cells,
-- and they re-stamp when a radius changes.

local Pinpoint = require("@shared/Combat/Pinpoint")
local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Hash = require("@shared/Util/Hash")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local SensorsState = require("./SensorsState")
local Types = require("./Types")
local World = require("./World")

local Sensors = {}

Sensors.Level = SensorsState.Level
local L = Sensors.Level
Sensors.KINDS = SensorsState.KINDS
Sensors.AIR_SIGHT_FACTOR = 1.5 -- default airSight = 1.5 × sight
Sensors.DEFAULT_RADAR_ERROR = 40 -- studs, when a radar def has no radarError
Sensors.WOBBLE_PERIOD = 30 -- ticks per wobble target (guide 11.4: tick // 30)
Sensors.CLOSE_SONAR = 40 -- studs: naval units and ASW helis detect submerged subs this close
Sensors.STAMP_BUDGET = 200000 -- cells written by full stamps per sensor tick (D85)
Sensors.DEFAULT_TRACK_ERROR = 8 -- studs, when a tracking radar def has no trackError
Sensors.DT = 1 / 15
Sensors.new = SensorsState.new
Sensors.hash = SensorsState.hash
local CELL = Grid.SENSOR_CELL_SIZE

local readu16, writeu16 = buffer.readu16, buffer.writeu16

type State = SensorsState.State

-- Sensor cell (x, z) and index containing world point (x, z), clamped.
function Sensors.cellOf(s: State, x: number, z: number): (number, number, number)
	local sx = math.clamp(math.floor((x - s.originX) / CELL), 0, s.width - 1)
	local sz = math.clamp(math.floor((z - s.originZ) / CELL), 0, s.depth - 1)
	return sx, sz, sz * s.width + sx
end

-- Circle offsets (flat dx, dz pairs) for a radius in studs, cached.
local circles: { [number]: { number } } = {}
function Sensors.circle(radius: number): { number }
	local c = circles[radius]
	if c then
		return c
	end
	c = {}
	local r = math.floor(radius / CELL)
	local r2 = (radius / CELL) ^ 2
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r2 then
				table.insert(c, dx)
				table.insert(c, dz)
			end
		end
	end
	circles[radius] = c
	return c
end

-- The same circle as row spans: half[dz + R + 1] = largest |dx| in row dz
-- (by symmetry also the largest |dz| in column dx); `cells` = its size.
type Spans = { R: number, half: { number }, cells: number }
local spansCache: { [number]: Spans } = {}
local function spansOf(radius: number): Spans
	local sp = spansCache[radius]
	if sp then
		return sp
	end
	local R = math.floor(radius / CELL)
	local r2 = (radius / CELL) ^ 2
	local half, cells = {}, 0
	for dz = -R, R do
		local h = -1
		for dx = 0, R do
			if dx * dx + dz * dz <= r2 then
				h = dx
			end
		end
		half[dz + R + 1] = h
		cells += 2 * h + 1
	end
	sp = { R = R, half = half, cells = cells }
	spansCache[radius] = sp
	return sp
end

local function add(map: buffer, w: number, d: number, x: number, z: number, delta: number)
	if x >= 0 and z >= 0 and x < w and z < d then
		local o = (z * w + x) * 2
		writeu16(map, o, readu16(map, o) + delta)
	end
end

local function stampCircle(s: State, map: buffer, cx: number, cz: number, radius: number, delta: number)
	if radius <= 0 then
		return
	end
	local sp = spansOf(radius)
	local R, half = sp.R, sp.half
	local w, d = s.width, s.depth
	for dz = -R, R do
		local z = cz + dz
		local h = half[dz + R + 1]
		if z < 0 or z >= d or h < 0 then
			continue
		end
		local x0, x1 = math.max(cx - h, 0), math.min(cx + h, w - 1)
		local o = (z * w + x0) * 2
		for _ = x0, x1 do
			writeu16(map, o, readu16(map, o) + delta)
			o += 2
		end
	end
end

-- Moves a stamped circle from (cx, cz) by (ddx, ddz), each -1, 0 or 1: an
-- x shift (each row loses one end cell and gains the next), then a z shift
-- (each column likewise).
local function shiftCircle(s: State, map: buffer, cx: number, cz: number, radius: number, ddx: number, ddz: number)
	if radius <= 0 then
		return
	end
	local sp = spansOf(radius)
	local R, half = sp.R, sp.half
	local w, d = s.width, s.depth
	if ddx ~= 0 then
		for dz = -R, R do
			local h = half[dz + R + 1]
			if h >= 0 then
				local z = cz + dz
				add(map, w, d, cx - ddx * h, z, -1) -- trailing end
				add(map, w, d, cx + ddx * (h + 1), z, 1) -- new leading end
			end
		end
		cx += ddx
	end
	if ddz ~= 0 then
		for dx = -R, R do
			local h = half[dx + R + 1]
			if h >= 0 then
				local x = cx + dx
				add(map, w, d, x, cz - ddz * h, -1)
				add(map, w, d, x, cz + ddz * (h + 1), 1)
			end
		end
	end
end

-- Radii per def (KINDS order), built once per def and shared: re-stamping a
-- moving unit allocates nothing.
-- Powered radii (track, jam) are the def's scaled by the share of their
-- upkeep the unit gets, in whole sensor cells, so the cache holds one table
-- per (def, track radius, jam radius).
local radiiCache: { [any]: { [number]: { number } } } = setmetatable({}, { __mode = "k" }) :: any
local function poweredRadius(sim: Types.Sim, id: number, radius: number?, drain: number?): number
	if radius == nil or radius <= 0 then
		return 0
	end
	local scale = sim.sensors.powerScale[id] or 1
	if drain == nil or drain <= 0 or scale >= 1 then
		return radius -- no upkeep, or fully powered: the def's radius
	end
	return math.floor(radius * scale / CELL) * CELL
end
local function radiiOf(sim: Types.Sim, id: number): { number }
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	local byTrack = radiiCache[def]
	if byTrack == nil then
		byTrack = {}
		radiiCache[def] = byTrack
	end
	local sensors = def.sensors
	local track = poweredRadius(sim, id, sensors.track, sensors.trackDrain)
	local jam = poweredRadius(sim, id, sensors.jam, sensors.jamDrain)
	local radar = poweredRadius(sim, id, sensors.radar, sensors.radarDrain) -- S-72
	local key = (radar * 65536 + track) * 65536 + jam
	local radii = byTrack[key]
	if radii == nil then
		radii = table.freeze({
			sensors.sight,
			sensors.airSight or sensors.sight * Sensors.AIR_SIGHT_FACTOR,
			radar,
			sensors.sonar,
			jam,
			track,
		})
		byTrack[key] = radii
	end
	return radii
end

local function stampUnit(s: State, team: number, cell: number, radii: { number }, delta: number)
	local m = s.maps[team]
	if m == nil then
		return
	end
	local cx, cz = cell % s.width, cell // s.width
	for k, kind in Sensors.KINDS do
		stampCircle(s, m[kind], cx, cz, radii[k], delta)
	end
end
Sensors.stampUnit = stampUnit -- tests recount maps with it

-- Cells written by stamping (or unstamping) these radii once.
local function stampCost(radii: { number }): number
	local n = 0
	for _, radius in radii do
		if radius > 0 then
			n += spansOf(radius).cells
		end
	end
	return n
end

-- Removes a unit's stamps (it moved, died or stopped emitting).
function Sensors.unstamp(s: State, id: number)
	local cell = s.stampCell[id]
	if cell ~= nil then
		stampUnit(s, s.stampTeam[id], cell, s.stampRadius[id], -1)
		s.stampCell[id] = nil
		s.stampTeam[id] = nil
		s.stampRadius[id] = nil
	end
end

-- Count in one team's map at a sensor cell.
function Sensors.count(s: State, team: number, kind: string, cell: number): number
	return readu16(s.maps[team][kind], cell * 2)
end

-- Is `defIndex`'s unit an aircraft / naval / submerged?
local function domainOf(sim: Types.Sim, id: number): string
	return sim.defs.unitByIndex[sim.world.defIndex[id]].domain
end

local SUB_BIT = Categories.Bit.SUB

-- Naval units and ASW helicopters (a HELI with a weapon that can target SUB).
local function isCloseSonar(sim: Types.Sim, def: Defs.UnitDef): boolean
	if def.domain == "naval" then
		return true
	end
	if def.moveClass ~= "HELI" then
		return false
	end
	for _, slot in def.weapons do
		if bit32.band(sim.defs.weaponByIndex[slot.weaponIndex].targetMask, SUB_BIT) ~= 0 then
			return true
		end
	end
	return false
end

-- Is submerged unit `id` within CLOSE_SONAR of one of `team`'s close detectors?
local function closeSonarDetects(sim: Types.Sim, s: State, team: number, id: number): boolean
	local w = sim.world
	local x, z = w.posX[id], w.posZ[id]
	local r2 = Sensors.CLOSE_SONAR * Sensors.CLOSE_SONAR
	for _, d in s.closeSonar[team] do
		local dx, dz = w.posX[d] - x, w.posZ[d] - z
		if dx * dx + dz * dz <= r2 then
			return true
		end
	end
	return false
end

-- Radar detection of unit `id` by `observer`, given the observer's radar
-- map already covers the unit's cell (guide 11.4):
--   * jamming: units inside their own team's jam map are invisible to radar;
--   * stealth: with radarSignature < 1, the unit must be within
--     radar range × signature of one of the observer's radar emitters.
function Sensors.radarDetects(sim: Types.Sim, s: State, observer: number, id: number, cell: number): boolean
	local w = sim.world
	local ownJam = s.maps[w.ally[id]]
	if ownJam and readu16(ownJam.jam, cell * 2) > 0 then
		return false
	end
	local signature = sim.defs.unitByIndex[w.defIndex[id]].sensors.radarSignature
	if signature >= 1 then
		return true
	end
	local x, z = w.posX[id], w.posZ[id]
	for _, r in s.radars[observer] do
		local reach = radiiOf(sim, r)[3] * signature -- the radar's powered radius (S-72)
		local dx, dz = w.posX[r] - x, w.posZ[r] - z
		if dx * dx + dz * dz <= reach * reach then
			return true
		end
	end
	return false
end

-- Pseudo-random point in the unit disc for (unit, period, observer):
-- stateless, so it never touches sim.rng and is the same however often asked.
local function wobblePoint(id: number, period: number, observer: number): (number, number)
	local h = Hash.u32(Hash.u32(Hash.u32(Hash.OFFSET_BASIS, id), period), observer)
	local a = (h % 65536) / 65536 * 2 * math.pi
	local r = math.sqrt((h // 65536) / 65536)
	return math.cos(a) * r, math.sin(a) * r
end

-- Radar error offset `observer` sees on unit `id` at `tick`: a wobble of
-- radius = the observer's best radarError, moving smoothly from one random
-- point to the next every WOBBLE_PERIOD ticks (guide 11.4). Pinpointers
-- shrink it (S-59): the radius is scaled by the team's precision.
function Sensors.wobble(s: State, observer: number, id: number, tick: number, radius: number?): (number, number)
	local err = (radius or s.radarError[observer] or Sensors.DEFAULT_RADAR_ERROR) * Pinpoint.errorScale(Sensors.precision(s, observer))
	local k = tick // Sensors.WOBBLE_PERIOD
	local f = (tick % Sensors.WOBBLE_PERIOD) / Sensors.WOBBLE_PERIOD
	local ax, az = wobblePoint(id, k, observer)
	local bx, bz = wobblePoint(id, k + 1, observer)
	return (ax + (bx - ax) * f) * err, (az + (bz - az) * f) * err
end

-- The ally team's radar precision 0..1 from its finished Pinpointers
-- (Shared/Combat/Pinpoint, S-59).
function Sensors.precision(s: State, team: number): number
	return Pinpoint.precision(s.pinpoints[team] or 0)
end

-- Level of enemy unit `id` for `team`, and whether the team's radar
-- tracks it (radar detectable inside its track map, D104).
local function levelFor(sim: Types.Sim, s: State, team: number, id: number, cell: number): (number, boolean)
	local w = sim.world
	local m = s.maps[team]
	local domain = domainOf(sim, id)
	if bit32.band(w.state[id], World.State.SUBMERGED) ~= 0 then
		if readu16(m.sonar, cell * 2) > 0 or closeSonarDetects(sim, s, team, id) then
			return L.SONAR, false
		end
		return L.HIDDEN, false
	end
	local onRadar = readu16(m.radar, cell * 2) > 0 and Sensors.radarDetects(sim, s, team, id, cell)
	local tracked = onRadar and readu16(m.track, cell * 2) > 0
	if readu16(m.los, cell * 2) > 0 or (domain == "air" and readu16(m.airLos, cell * 2) > 0) then
		return L.VISIBLE, tracked
	end
	if onRadar then
		return L.RADAR, tracked
	end
	if domain == "naval" and readu16(m.sonar, cell * 2) > 0 then
		return L.SONAR, false
	end
	return L.HIDDEN, false
end

-- Sensors system body: re-stamp moved emitters, then recompute visibility.
function Sensors.step(sim: Types.Sim)
	local s = sim.sensors
	local w = sim.world
	local fullSpent = 0
	for _, team in s.teams do
		table.clear(s.radars[team])
		table.clear(s.closeSonar[team])
		s.radarError[team] = nil
		s.trackError[team] = nil
		s.pinpoints[team] = 0
	end
	for _, id in w.ids do
		if w.buildProgress[id] < 1 then
			Sensors.unstamp(s, id)
			continue
		end
		local def = sim.defs.unitByIndex[w.defIndex[id]]
		local sensors = def.sensors
		if def.pinpointer and s.pinpoints[w.ally[id]] then
			s.pinpoints[w.ally[id]] += Pinpoint.weight(def)
		end
		local radars = s.radars[w.ally[id]]
		local close = s.closeSonar[w.ally[id]]
		if close and isCloseSonar(sim, def) then
			table.insert(close, id)
		end
		if sensors.radar > 0 and radars then
			table.insert(radars, id)
			local err = sensors.radarError or Sensors.DEFAULT_RADAR_ERROR
			local team = w.ally[id]
			s.radarError[team] = math.min(s.radarError[team] or math.huge, err)
		end
		local radii = radiiOf(sim, id)
		if radii[6] > 0 then
			local team = w.ally[id]
			s.trackError[team] = math.min(s.trackError[team] or math.huge, sensors.trackError or Sensors.DEFAULT_TRACK_ERROR)
		end
		local _, _, cell = Sensors.cellOf(s, w.posX[id], w.posZ[id])
		local old = s.stampCell[id]
		if old ~= cell or s.stampRadius[id] ~= radii then -- moved, or a tracking radius changed
			local team = w.ally[id]
			local width = s.width
			local ddx, ddz = 2, 2 -- not adjacent unless already stamped
			if old ~= nil then
				ddx, ddz = cell % width - old % width, cell // width - old // width
			end
			local m = s.maps[team]
			if old ~= nil and m and s.stampTeam[id] == team and s.stampRadius[id] == radii and math.abs(ddx) <= 1 and math.abs(ddz) <= 1 then
				-- one cell over: shift the circles
				local ox, oz = old % width, old // width
				for k, kind in Sensors.KINDS do
					shiftCircle(s, m[kind], ox, oz, radii[k], ddx, ddz)
				end
				s.stampCell[id] = cell
			elseif fullSpent < Sensors.STAMP_BUDGET then
				fullSpent += stampCost(radii) + (if old ~= nil then stampCost(s.stampRadius[id]) else 0)
				Sensors.unstamp(s, id)
				stampUnit(s, team, cell, radii, 1)
				s.stampCell[id] = cell
				s.stampTeam[id] = team
				s.stampRadius[id] = radii
			end -- else: over this tick's budget; restamped on a later sensor tick
		end
	end

	for _, team in s.teams do
		local vis = s.vis[team]
		local trackedBy = s.tracked[team]
		table.clear(trackedBy)
		local ghosts = s.ghosts[team]
		local ghostIds = s.ghostIds[team]
		for _, id in w.ids do
			if w.ally[id] == team then
				continue
			end
			local _, _, cell = Sensors.cellOf(s, w.posX[id], w.posZ[id])
			local level, tracked = levelFor(sim, s, team, id, cell)
			if tracked then
				trackedBy[id] = true
			end
			if domainOf(sim, id) == "structure" then
				if level == L.VISIBLE then
					local g = ghosts[id]
					if g == nil then
						ghosts[id] = { defIndex = w.defIndex[id], team = w.team[id], x = w.posX[id], z = w.posZ[id], gen = w.gen[id] }
						table.insert(ghostIds, id)
						World.pin(w, id) -- never reused while remembered (D109)
					end
				elseif ghosts[id] ~= nil then
					level = L.GHOST
				end
			end
			vis[id] = level
		end
		-- Forget ghosts of structures that are gone once their spot is in sight.
		local i = 1
		while i <= #ghostIds do
			local gid = ghostIds[i]
			local g = ghosts[gid]
			local _, _, cell = Sensors.cellOf(s, g.x, g.z)
			if not World.isRef(w, gid, g.gen) and readu16(s.maps[team].los, cell * 2) > 0 then
				ghosts[gid] = nil
				table.remove(ghostIds, i)
				World.unpin(w, gid)
			else
				i += 1
			end
		end
	end
end

-- Where `team` believes unit `id` is, and how it knows: the true position
-- when VISIBLE (or a ghost of a structure, which doesn't move), the wobbled
-- position for RADAR / SONAR contacts, nil when hidden.
function Sensors.knownPosition(sim: Types.Sim, team: number, id: number): (number?, number?, number)
	local level = Sensors.level(sim, team, id)
	local w = sim.world
	if level == L.VISIBLE then
		return w.posX[id], w.posZ[id], level
	elseif level == L.GHOST then
		local g = sim.sensors.ghosts[team][id]
		return g.x, g.z, level
	elseif level == L.RADAR or level == L.SONAR then
		local s = sim.sensors
		local radius = if level == L.RADAR and s.tracked[team] and s.tracked[team][id] then s.trackError[team] else nil
		local dx, dz = Sensors.wobble(s, team, id, sim.tick, radius)
		return w.posX[id] + dx, w.posZ[id] + dz, level
	end
	return nil, nil, level
end

-- What `team` knows about unit `id` for targeting (D100): where it is, how,
-- and its def index. A structure ghost answers from the ghost record, so a
-- structure that died unseen is still a target until its spot is seen
-- again: the team can't tell it from a live one. nil when hidden.
--
-- With `gen` (a remembered reference, D109): if (id, gen) is no longer the
-- live unit, only a ghost of that very unit can answer; else hidden.
function Sensors.knownTarget(sim: Types.Sim, team: number, id: number, gen: number?): (number?, number?, number, number?)
	if gen ~= nil and not World.isRef(sim.world, id, gen) then
		local ghosts = sim.sensors.ghosts[team]
		local g = ghosts and ghosts[id]
		if g and g.gen == gen then
			return g.x, g.z, L.GHOST, g.defIndex
		end
		return nil, nil, L.HIDDEN, nil
	end
	local kx, kz, level = Sensors.knownPosition(sim, team, id)
	if kx == nil then
		return nil, nil, level, nil
	end
	if level == L.GHOST then
		return kx, kz, level, sim.sensors.ghosts[team][id].defIndex
	end
	return kx, kz, level, sim.world.defIndex[id]
end

-- Unit types are known only for VISIBLE units, ghosts (seen before),
-- tracked radar contacts and the team's own units. Any other contact
-- reveals only its domain (D107): air, surface or submerged.
local CB = Categories.Bit
Sensors.DOMAIN_MASK = table.freeze({
	air = bit32.bor(CB.AIR, CB.HELI, CB.JET),
	surface = bit32.bor(CB.GROUND, CB.NAVAL, CB.STRUCTURE),
	submerged = CB.SUB,
})

function Sensors.typeKnown(sim: Types.Sim, team: number, id: number, level: number): boolean
	return level == L.VISIBLE or level == L.GHOST or Sensors.isTracked(sim, team, id)
end

-- The categories `team` knows unit `id` has, given its level and def index
-- (from Sensors.knownTarget): all of them when its type is known, else
-- those of its domain (D107).
-- An aircraft parked on the ground (LANDED) counts as a ground unit: ground
-- guns can hit it, anti-air can't (guide 12.2, S-71).
local AIR_BITS = Sensors.DOMAIN_MASK.air
function Sensors.knownCategories(sim: Types.Sim, team: number, id: number, level: number, defIndex: number): number
	local def = sim.defs.unitByIndex[defIndex]
	local w = sim.world
	local landed = def.domain == "air" and w.slot[id] ~= nil and bit32.band(w.state[id], World.State.LANDED) ~= 0
	if Sensors.typeKnown(sim, team, id, level) then
		if landed then
			return bit32.bor(bit32.band(def.categoryMask, bit32.bnot(AIR_BITS)), CB.GROUND)
		end
		return def.categoryMask
	end
	if def.domain == "air" and not landed then
		return Sensors.DOMAIN_MASK.air
	elseif bit32.band(def.categoryMask, CB.SUB) ~= 0 or (w.slot[id] ~= nil and bit32.band(w.state[id], World.State.SUBMERGED) ~= 0) then
		return Sensors.DOMAIN_MASK.submerged
	end
	return Sensors.DOMAIN_MASK.surface
end

-- Does `team`'s fire-control radar track enemy unit `id` (D104)?
function Sensors.isTracked(sim: Types.Sim, team: number, id: number): boolean
	local t = sim.sensors.tracked[team]
	return t ~= nil and t[id] == true
end

-- Powered-sensor upkeep (called by Build.step with the other economy
-- consumers; D104 tracking radars, D108 jammers, S-72 plain radars): each
-- finished unit drains trackDrain + jamDrain + radarDrain power per second
-- at the team's power stall ratio; the share it gets scales its track, jam
-- and radar radii (applied at the next sensor tick).
function Sensors.drainStep(sim: Types.Sim, demandP: { [number]: number })
	local w = sim.world
	local s = sim.sensors
	local eco = sim.eco
	local dt = Sensors.DT
	for _, id in w.ids do
		local sensors = sim.defs.unitByIndex[w.defIndex[id]].sensors
		local drain = 0
		if (sensors.track or 0) > 0 then
			drain += sensors.trackDrain or 0
		end
		if (sensors.jam or 0) > 0 then
			drain += sensors.jamDrain or 0
		end
		if (sensors.radar or 0) > 0 then
			drain += sensors.radarDrain or 0 -- plain radars (S-72)
		end
		if drain <= 0 or w.buildProgress[id] < 1 then
			continue
		end
		local team = w.team[id]
		local acc = eco.accounts[team]
		if acc == nil then
			continue
		end
		demandP[team] += drain
		local ratio = math.min(Economy.effective(acc, 0, drain), Economy.allowance(acc.power) / (drain * dt))
		ratio = math.clamp(ratio, 0, 1)
		acc.power.spent += drain * dt * ratio
		s.powerScale[id] = ratio
	end
end

-- Is point (x, z) in `team`'s line of sight? NetOut shows projectiles and
-- impacts only where the player's ally team can see (guide 7.2).
function Sensors.inSight(sim: Types.Sim, team: number, x: number, z: number): boolean
	local s = sim.sensors
	local m = s.maps[team]
	if m == nil then
		return false
	end
	local _, _, cell = Sensors.cellOf(s, x, z)
	return readu16(m.los, cell * 2) > 0
end

-- Does `team` detect something airborne at (x, z): in its sight or its radar
-- coverage? Strategic missiles are found this way (S-48): big, hot and high,
-- they show on any radar, and jamming doesn't hide them.
function Sensors.detectsPoint(sim: Types.Sim, team: number, x: number, z: number): boolean
	local s = sim.sensors
	local m = s.maps[team]
	if m == nil then
		return false
	end
	local _, _, cell = Sensors.cellOf(s, x, z)
	return readu16(m.los, cell * 2) > 0 or readu16(m.airLos, cell * 2) > 0 or readu16(m.radar, cell * 2) > 0
end

-- What `team` knows about unit `id`: VISIBLE for its own units; GHOST for a
-- dead structure it still remembers; HIDDEN when nothing is known.
function Sensors.level(sim: Types.Sim, team: number, id: number): number
	local w = sim.world
	if w.slot[id] ~= nil and w.ally[id] == team then
		return L.VISIBLE
	end
	local s = sim.sensors
	if w.slot[id] == nil then
		return if s.ghosts[team] and s.ghosts[team][id] then L.GHOST else L.HIDDEN
	end
	local vis = s.vis[team]
	return if vis then vis[id] or L.HIDDEN else L.HIDDEN
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	local s = sim.sensors
	Sensors.unstamp(s, id)
	for _, team in s.teams do
		s.vis[team][id] = nil -- ghosts (structures) are kept until seen gone
		s.tracked[team][id] = nil
	end
	s.powerScale[id] = nil
end)

return Sensors
