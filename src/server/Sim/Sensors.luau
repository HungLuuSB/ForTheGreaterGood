--!strict
-- Sensor maps and visibility (guide 11.1–11.3).
--
-- Per ally team, on the 16-stud sensor grid, five count maps (u16 per cell):
--   los     sight of every unit                    airLos  sight against aircraft
--   radar   radar emitters                         sonar   sonar emitters
--   jam     this team's jammers (hide this team from enemy radar)
-- An emitter stamps +1 on every sensor cell whose center lies within its
-- radius of the emitter's cell center (precomputed circle offsets per
-- radius), and only re-stamps when it changes sensor cell. Unfinished
-- structures don't emit. Counts are u16 (not the guide's u8): a dense blob
-- of units can put more than 255 emitters on one cell.
--
-- Visibility of each enemy unit for each team is recomputed on every
-- sensor tick (every 2nd tick) from the maps: O(units × teams) buffer reads.
-- Levels: VISIBLE (in los, or airLos for aircraft) > GHOST (a structure seen
-- before, now out of sight) > RADAR / SONAR > HIDDEN. Submerged units are
-- only ever SONAR or HIDDEN. Jamming and stealth refine RADAR (guide 11.4).

local Grid = require("@shared/Grid/Grid")
local Hash = require("@shared/Util/Hash")
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

local function stampCircle(s: State, map: buffer, cx: number, cz: number, radius: number, delta: number)
	if radius <= 0 then
		return
	end
	local c = Sensors.circle(radius)
	local w, d = s.width, s.depth
	for i = 1, #c, 2 do
		local x, z = cx + c[i], cz + c[i + 1]
		if x >= 0 and z >= 0 and x < w and z < d then
			local o = (z * w + x) * 2
			writeu16(map, o, readu16(map, o) + delta)
		end
	end
end

-- Radii per def (KINDS order), built once per def and shared: re-stamping a
-- moving unit allocates nothing.
local radiiCache: { [any]: { number } } = setmetatable({}, { __mode = "k" }) :: any
local function radiiOf(sim: Types.Sim, id: number): { number }
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	local radii = radiiCache[def]
	if radii == nil then
		local sensors = def.sensors
		radii = table.freeze({
			sensors.sight,
			sensors.airSight or sensors.sight * Sensors.AIR_SIGHT_FACTOR,
			sensors.radar,
			sensors.sonar,
			sensors.jam or 0,
		})
		radiiCache[def] = radii
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

-- Radar detection of unit `id` by `observer`, given the observer's radar
-- map already covers the unit's cell (guide 11.4):
--   * jamming: units inside their own team's jam map are invisible to radar;
--   * stealth: with radarSignature < 1, the unit must be within
--     radar range × signature of one of the observer's radar emitters.
function Sensors.radarDetects(sim: Types.Sim, s: State, observer: number, id: number, cell: number): boolean
	local w = sim.world
	local ownJam = s.maps[w.team[id]]
	if ownJam and readu16(ownJam.jam, cell * 2) > 0 then
		return false
	end
	local signature = sim.defs.unitByIndex[w.defIndex[id]].sensors.radarSignature
	if signature >= 1 then
		return true
	end
	local x, z = w.posX[id], w.posZ[id]
	for _, r in s.radars[observer] do
		local reach = sim.defs.unitByIndex[w.defIndex[r]].sensors.radar * signature
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
-- point to the next every WOBBLE_PERIOD ticks (guide 11.4).
function Sensors.wobble(s: State, observer: number, id: number, tick: number): (number, number)
	local err = s.radarError[observer] or Sensors.DEFAULT_RADAR_ERROR
	local k = tick // Sensors.WOBBLE_PERIOD
	local f = (tick % Sensors.WOBBLE_PERIOD) / Sensors.WOBBLE_PERIOD
	local ax, az = wobblePoint(id, k, observer)
	local bx, bz = wobblePoint(id, k + 1, observer)
	return (ax + (bx - ax) * f) * err, (az + (bz - az) * f) * err
end

local function levelFor(sim: Types.Sim, s: State, team: number, id: number, cell: number): number
	local w = sim.world
	local m = s.maps[team]
	local domain = domainOf(sim, id)
	if bit32.band(w.state[id], World.State.SUBMERGED) ~= 0 then
		return if readu16(m.sonar, cell * 2) > 0 then L.SONAR else L.HIDDEN
	end
	if readu16(m.los, cell * 2) > 0 or (domain == "air" and readu16(m.airLos, cell * 2) > 0) then
		return L.VISIBLE
	end
	if readu16(m.radar, cell * 2) > 0 and Sensors.radarDetects(sim, s, team, id, cell) then
		return L.RADAR
	end
	if domain == "naval" and readu16(m.sonar, cell * 2) > 0 then
		return L.SONAR
	end
	return L.HIDDEN
end

-- Sensors system body: re-stamp moved emitters, then recompute visibility.
function Sensors.step(sim: Types.Sim)
	local s = sim.sensors
	local w = sim.world
	for _, team in s.teams do
		table.clear(s.radars[team])
		s.radarError[team] = nil
	end
	for _, id in w.ids do
		if w.buildProgress[id] < 1 then
			Sensors.unstamp(s, id)
			continue
		end
		local sensors = sim.defs.unitByIndex[w.defIndex[id]].sensors
		local radars = s.radars[w.team[id]]
		if sensors.radar > 0 and radars then
			table.insert(radars, id)
			local err = sensors.radarError or Sensors.DEFAULT_RADAR_ERROR
			local team = w.team[id]
			s.radarError[team] = math.min(s.radarError[team] or math.huge, err)
		end
		local _, _, cell = Sensors.cellOf(s, w.posX[id], w.posZ[id])
		if s.stampCell[id] ~= cell then
			Sensors.unstamp(s, id)
			local radii = radiiOf(sim, id)
			local team = w.team[id]
			stampUnit(s, team, cell, radii, 1)
			s.stampCell[id] = cell
			s.stampTeam[id] = team
			s.stampRadius[id] = radii
		end
	end

	for _, team in s.teams do
		local vis = s.vis[team]
		local ghosts = s.ghosts[team]
		local ghostIds = s.ghostIds[team]
		for _, id in w.ids do
			if w.team[id] == team then
				continue
			end
			local _, _, cell = Sensors.cellOf(s, w.posX[id], w.posZ[id])
			local level = levelFor(sim, s, team, id, cell)
			if domainOf(sim, id) == "structure" then
				if level == L.VISIBLE then
					local g = ghosts[id]
					if g == nil then
						ghosts[id] = { defIndex = w.defIndex[id], team = w.team[id], x = w.posX[id], z = w.posZ[id] }
						table.insert(ghostIds, id)
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
			if w.slot[gid] == nil and readu16(s.maps[team].los, cell * 2) > 0 then
				ghosts[gid] = nil
				table.remove(ghostIds, i)
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
		local dx, dz = Sensors.wobble(sim.sensors, team, id, sim.tick)
		return w.posX[id] + dx, w.posZ[id] + dz, level
	end
	return nil, nil, level
end

-- What `team` knows about unit `id`: VISIBLE for its own units; GHOST for a
-- dead structure it still remembers; HIDDEN when nothing is known.
function Sensors.level(sim: Types.Sim, team: number, id: number): number
	local w = sim.world
	if w.slot[id] ~= nil and w.team[id] == team then
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
	end
end)

return Sensors
